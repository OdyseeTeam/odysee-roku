sub Init()
    m.top.functionName = "master"
end sub

sub master()
    '?m.top.constants
    '?m.top.cookies
    '?m.top.uid
    '?m.top.authtoken
    '?m.top.channels
    '?m.top.rawname
    m.top.output = getLighthouseResult(m.top.search)
end sub
function getLighthouseResult(search)
    queryURL = m.top.constants["LIGHTHOUSE_API"]
    queryRAW = { s: m.top.search, size: "50", from: "0", "claimType": "channel", nsfw: "false", free_only: "true" }
    claimIds = []
    failcount = 0
    while true
        queryResult = getURLEncoded(queryRAW, queryURL, [])
        if type(queryResult) = "roArray"
            if queryResult.Count() > 0
                ?"got" + Str(queryResult.Count() * 4) + " channels from Odysee (Channel Search)"
                ?"valid"
                exit while
            else
                failcount += 1
                if failcount > 5
                    exit while
                end if
            end if
        else
            failcount += 1
            if failcount > 5
                exit while
            end if
        end if
    end while
    if type(queryResult) = "roArray"
        if queryResult.Count() > 0
            ?"valid"
            return ClaimsToChannelGrid(queryResult)
        else
            ?"no results"
            return { result: {}, success: false }
        end if
    else
        ?"no results"
        return { result: {}, success: false }
    end if
end function

function ClaimsToChannelGrid(claims)
    'passthrough until we rework parsing for this
    urlList = []
    channelList = []
    validChannels = []
    for each claim in claims
        urlList.push("lbry://" + claim.name + "#" + claim.claimId)
        channelList.push(claim.claimId)
    end for
    queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
    queryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": 50, "claim_type": "stream", "stream_types": ["video"], "media_types": ["video/mp4"], "no_totals": true, "any_tags": [], "not_tags": ["porn", "porno", "nsfw", "mature", "xxx", "sex", "creampie", "blowjob", "handjob", "vagina", "boobs", "big boobs", "big dick", "pussy", "cumshot", "anal", "hard fucking", "ass", "fuck", "hentai"], "channel_ids": channelList, "not_channel_ids": [], "order_by": ["release_time"], "has_no_source": false, "include_purchase_receipt": false, "has_channel_signature": true, "valid_channel_signature": true, "has_source": true, "limit_claims_per_channel": 1 } })
    cresponse = postJSON(queryJSON, queryURL, invalid)
    ?cresponse
    retries = 0
    while true
        if IsValid(cresponse.error)
            cresponse = postJSON(queryJSON, queryURL, invalid)
            retries += 1
        else
            exit while
        end if
        if retries > 5
            cresponse = false
            exit while
        end if
    end while
    if Type(cresponse) = "roAssociativeArray"
        if cresponse.result.items.Count() >= 1
            for each channel in cresponse.result.items
                if isValid(channel.signing_channel)
                    if isValid(channel.signing_channel.address)
                        validChannels.push(channel.signing_channel)
                    end if
                end if
            end for
        end if
    else
        return { result: {}, success: false }
    end if
    if validChannels.Count() >= 1
        mediaindex = {}
        result = []
        counter = 0
        i = 0
        content = createObject("RoSGNode", "ContentNode")
        for each channel in validChannels
            item = {}
            item.Title = channel.name
            item.Creator = ""
            item.Description = ""
            item.Channel = channel.claim_id
            item.guid = channel.claim_id
            try
                thumbnail = m.top.constants["IMAGE_PROCESSOR"] + channel.value.thumbnail.url
            catch e
                thumbnail = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
            end try
            item.HDPosterURL = thumbnail
            item.thumbnailDimensions = [360, 240]
            'all set on watching video due to https://QUERY_API/api/v1/proxy?m=get
            item.url = channel.permanent_url.Trim() 'to be used to resolve with m?=get
            item.source = "odysee"
            item.itemType = "channel"
            'Create content (content -> row -> item)
            if counter < 4
                if IsValid(currow) <> true
                    currow = createObject("RoSGNode", "ContentNode")
                end if
                curitem = createObject("RoSGNode", "ContentNode")
                curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", lbc: "", Channel: "" })
                curitem.setFields(item)
                currow.appendChild(curitem)
                if i = validChannels.Count() - 1 'misalignment fix, will need to implement this better later.
                    content.appendChild(currow)
                end if
                counter += 1
                curitem = invalid
            else
                content.appendChild(currow)
                currow = invalid
                currow = createObject("RoSGNode", "ContentNode")
                curitem = createObject("RoSGNode", "ContentNode")
                curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", lbc: "", Channel: "" })
                curitem.setFields(item)
                currow.appendChild(curitem)
                counter = 1
                curitem = invalid
            end if
            result.push(item) 'Unparsed "XMLContent", can be used to cache results later.
            mediaindex[item.guid] = item
            item = invalid
            i += 1
        end for
        ?"exported" + Str(content.getChildCount() * 4) + " channels from Odysee (Channel Search)"
        return { contentarray: result: index: mediaindex: content: content: success: true }
    else
        return { result: {}, success: false }
    end if
end function