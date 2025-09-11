sub Init()
    m.top.functionName = "master"
end sub

sub master()
    '? m.top.constants
    '? m.top.cookies
    '? m.top.uid
    '? m.top.channels
    '? m.top.rawname
    m.top.resolveAttempts = 0
    m.top.output = ChannelToVideoGrid(m.top.channel)
end sub
function ChannelToVideoGrid(channel)
    queryOutput = "placeholder"
    max = 48
    queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
    queryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": max, "fee_amount": "<=0", "claim_type": "stream", "stream_types": ["video"], "no_totals": true, "any_tags": [], "not_tags": ["porn", "porno", "nsfw", "mature", "xxx", "sex", "creampie", "blowjob", "handjob", "boobs", "big boobs", "big dick", "pussy", "cumshot", "anal", "hard fucking", "ass", "fuck", "hentai"], "channel_ids": [channel], "not_channel_ids": [], "order_by": ["release_time"], "has_no_source": false, "include_purchase_receipt": false, "has_channel_signature": true, "valid_channel_signature": true, "has_source": true }, "id": m.top.uid })
    response = postJSON(queryJSON, queryURL, invalid)
    retries = 0
    result = []
    while true
        if (not isValid(response)) or (Type(response) <> "roAssociativeArray") then
            response = postJSON(queryJSON, queryURL, invalid)
            retries += 1
        else if IsValid(response.error)
            response = postJSON(queryJSON, queryURL, invalid)
            retries += 1
        else
            m.top.error = false
            exit while
        end if
        if retries > 5
            m.top.error = true
            return { error: true, errortype: "claimSearchError" }
        end if
    end while
    if m.top.error = false 'Stage 1: Parse content
        try
            ' Safely extract items; response.result may be missing
            items = invalid
            if isValid(response) and Type(response) = "roAssociativeArray"
                res = response["result"]
                if isValid(res) and Type(res) = "roAssociativeArray"
                    it = res["items"]
                    if isValid(it) and (Type(it) = "roArray" or Type(it) = "Array")
                        items = it
                    end if
                end if
            end if
            ' Set channel icon defensively from first item if present
            if isValid(items) and (Type(items) = "roArray" or Type(items) = "Array") and items.Count() > 0
                try
                    m.top.ChannelIcon = m.top.constants["CHANNEL_ICON_PROCESSOR"] + items[0].signing_channel.value.thumbnail.url
                catch e
                    m.top.ChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
                end try
            end if
            defaultChannelIcon = m.top.channelIcon
            ' Try to prepend livestream if active
            streamStatus = getLivestream(channel)
            if isValid(streamStatus) and isValid(streamStatus.success) and streamStatus.success = true
                result.push(streamStatus.liveItem)
            end if
            if not isValid(items) or (Type(items) <> "roArray" and Type(items) <> "Array") or items.Count() = 0
                content = createObject("RoSGNode", "ContentNode")
                if result.Count() > 0
                    ' Build content from just the livestream entry
                    currow = createObject("RoSGNode", "ContentNode")
                    for each ritem in result
                        curitem = createObject("RoSGNode", "ContentNode")
                        curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", Channel: "", ChannelIcon: "", rawCreator: "", videoLength: "" })
                        curitem.setFields(ritem)
                        currow.appendChild(curitem)
                    end for
                    content.appendChild(currow)
                end if
                return { contentarray: result: content: content }
            end if
            ? "got " + str(items.Count()) + " items from Odysee"
            ' Parse claims defensively using parseLib
            for each claim in items
                pv = parseVideo(claim)
                if pv.Count() > 0
                    ' Prefer a consistent channel icon if provided
                    if isValid(defaultChannelIcon) and defaultChannelIcon <> ""
                        pv.ChannelIcon = defaultChannelIcon
                    end if
                    result.push(pv)
                end if
                pv = invalid
            end for
            'Stage 2: Build ContentNode rows
            content = createObject("RoSGNode", "ContentNode")
            rowSize = 4
            counter = 0
            currow = createObject("RoSGNode", "ContentNode")
            for each item in result
                if counter < rowSize
                    curitem = createObject("RoSGNode", "ContentNode")
                    curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", Channel: "", ChannelIcon: "", rawCreator: "", videoLength: "" })
                    curitem.setFields(item)
                    currow.appendChild(curitem)
                    counter += 1
                else
                    content.appendChild(currow)
                    currow = createObject("RoSGNode", "ContentNode")
                    curitem = createObject("RoSGNode", "ContentNode")
                    curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", Channel: "", ChannelIcon: "", rawCreator: "", videoLength: "" })
                    curitem.setFields(item)
                    currow.appendChild(curitem)
                    counter = 1
                end if
            end for
            if IsValid(currow) and currow.getChildCount() > 0
                content.appendChild(currow)
            end if
            if content.getChildCount() = 0
                m.top.error = true
                return { error: true }
            end if
            return { contentarray: result: content: content } 'Returns the array
        catch e
            return { error: true, errortype: "parseError" }
        end try
    else
        return { error: true }
    end if
end function

