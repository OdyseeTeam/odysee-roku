sub Init()
    m.top.functionName = "master"
end sub

sub master()
    m.top.output = FetchNext()
end sub

function FetchNext() as object
    queryURL = m.top.constants["LIGHTHOUSE_API"]
    ' Defensive: ensure non-empty search term; fallback to last query stored in scene if passed via constants
    qstr = ""
    try
        if IsValid(m.top.search) and m.top.search <> "" then
            qstr = m.top.search.ToStr()
        else if IsValid(m.top.constants) and IsValid(m.top.constants["__lastChannelQuery"]) then
            qstr = m.top.constants["__lastChannelQuery"].ToStr()
        end if
    catch e
    end try
    queryRAW = { s: qstr, size: "48", from: m.top.from.toStr(), claimType: "channel", nsfw: "false", free_only: "true" }
    ? "[Search:Channel:Next] Lighthouse request:" + FormatJson(queryRAW)
    queryResult = getURLEncoded(queryRAW, queryURL, [])
    if type(queryResult) = "roArray" or type(queryResult) = "Array"
        ? "[Search:Channel:Next] Lighthouse results:" + Str(queryResult.Count())
    else
        ? "[Search:Channel:Next] Lighthouse returned non-array"
    end if
    if type(queryResult) <> "roArray" and type(queryResult) <> "Array"
        return { content: createObject("RoSGNode","ContentNode") }
    end if
    ' Build channel IDs
    channelList = []
    for each claim in queryResult
        channelList.push(claim.claimId)
    end for
    if channelList.Count() = 0 then return { content: createObject("RoSGNode","ContentNode") }
    ' Fetch channel claims by ID and render those claims directly
    queryURL2 = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
    queryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": 48, "claim_type": ["channel"], "no_totals": true, "claim_ids": channelList }, "id": m.top.uid })
    ? "[Search:Channel:Next] claim_ids count=" + Str(channelList.Count())
    cresponse = postJSON(queryJSON, queryURL2, invalid)
    validChannels = []
    if Type(cresponse) = "roAssociativeArray"
        if isValid(cresponse.result) and isValid(cresponse.result.items)
            for each channel in cresponse.result.items
                if isValid(channel) and isValid(channel.claim_id)
                    validChannels.push(channel)
                end if
            end for
        end if
    end if
    content = createObject("RoSGNode", "ContentNode")
    if validChannels.Count() > 0
        currow = createObject("RoSGNode", "ContentNode")
        counter = 0
        for each channel in validChannels
            item = {}
            try: item.Title = channel.value.title : catch e: item.Title = channel.name : end try
            item.Creator = ""
            item.Description = ""
            item.Channel = channel.claim_id
            item.guid = channel.claim_id
            try: thumbnail = m.top.constants["IMAGE_PROCESSOR"] + channel.value.thumbnail.url : catch e: thumbnail = "pkg:/images/generic/bad_icon_requires_usage_rights.png" : end try
            item.HDPosterURL = thumbnail
            item.thumbnailDimensions = [360, 240]
            item.url = channel.permanent_url.Trim()
            item.source = "odysee"
            item.itemType = "channel"
            node = createObject("RoSGNode","ContentNode")
            node.addFields({ creator: "", thumbnailDimensions: [], itemType: "", Channel: "", Followers: "0 Followers" })
            node.setFields(item)
            if counter < 4
                currow.appendChild(node)
                counter += 1
            else
                content.appendChild(currow)
                currow = createObject("RoSGNode","ContentNode")
                currow.appendChild(node)
                counter = 1
            end if
        end for
        if isValid(currow) and currow.getChildCount() > 0
            content.appendChild(currow)
        end if
    end if
    return { content: content }
end function


