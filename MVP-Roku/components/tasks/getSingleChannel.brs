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
    m.top.resolveAttempts = 0
    m.top.output = ChannelToVideoGrid(m.top.channel)
    m.livestreamChannelIcon = ""
end sub
function isLivestreaming(channel)
    'This finds if a user is livestreaming. If it is, it gets the livestream data, and then resolves the chat claimId for that individual livestream.
    'Chat is only attached to the latest livestream. If the user streams more than one livestream, we will have a problem.
    while m.top.resolveAttempts < 5
        'https://api.live.odysee.com/v1/odysee/live/
        try
            livestreamStatus = getJSON(m.top.constants["LIVE_API"] + "/" + channel)
            livestreamData = livestreamStatus["data"]
            if livestreamData.live = false
                success = false
                livestreamData = {}
                livestreamClaimData = {}
                chatClaim = ""
                exit while
            else
                success = true
                'The stream exists, so we need to resolve the stream claim (for chat)
                lsqueryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
                lsqueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": 1, "claim_type": "stream", "no_totals": true, "any_tags": [], "not_tags": ["porn", "porno", "nsfw", "mature", "xxx", "sex", "creampie", "blowjob", "handjob", "vagina", "boobs", "big boobs", "big dick", "pussy", "cumshot", "anal", "hard fucking", "ass", "fuck", "hentai"], "channel_ids": [channel], "not_channel_ids": [], "order_by": ["release_time"], "has_no_source": true, "include_purchase_receipt": false, "has_channel_signature": true, "valid_channel_signature": true, "has_source": false } })
                livestreamClaimQuery = postJSON(lsqueryJSON, lsqueryURL, invalid)
                retries = 0

                while true
                    if IsValid(livestreamClaimQuery.error)
                        livestreamClaimQuery = postJSON(lsqueryJSON, lsqueryURL, invalid)
                        retries += 1
                    else
                        exit while
                    end if
                    if retries > 5
                        exit while
                    end if
                end while
                if IsValid(livestreamClaimQuery.error)
                    'if we can't resolve the chat, we shouldn't play the livestream.
                    livestreamData = {}
                    livestreamClaimData = {}
                    success = false
                    chatClaim = ""
                    exit while
                else
                    try
                        m.livestreamChannelIcon = livestreamclaimquery["result"]["items"][0]["signing_channel"]["value"]["thumbnail"]["url"]
                        livestreamClaimData = livestreamClaimQuery
                        ?"chat claim appears to be: " + livestreamClaimData.result.items[0].claim_id
                    catch e
                        livestreamData = {}
                        livestreamClaimData = {}
                        success = false
                        chatClaim = ""
                        exit while
                    end try
                end if
                exit while
            end if
        catch e
            m.top.resolveAttempts += 1
            if m.top.resolveAttempts >= 5
                success = false
                livestreamData = {} 'live API not responding, assume no livestream.
                livestreamClaimData = {}
                chatClaim = ""
                exit while
            end if
        end try
    end while
    return { data: livestreamData : chatData: livestreamClaimData : success: success }
end function
function ChannelToVideoGrid(channel)
    streamStatus = isLivestreaming(channel)
    ?streamStatus
    ?Type(streamStatus)
    if streamStatus.success = true
        ?channel + " is livestreaming with chat claimid: " + streamStatus.chatData.result.items[0].claim_id
        item = {}
        'since the user is livestreaming, we should add it here, before anything else.
        result = []
        content = createObject("RoSGNode", "ContentNode")
        'This will allow us to insert 1 item at the very beginning, since we use counter+curRow to form the Rows that the user views.
        currow = createObject("RoSGNode", "ContentNode")
        counter = 1
        item.Title = streamStatus.chatData.result.items[0].value.title
        item.Creator = streamStatus.data["claimData"].name
        item.Channel = channel
        item.ChannelIcon = m.livestreamChannelIcon
        item.Description = streamStatus.chatData.result.items[0].value.title
        item.Channel = streamStatus.data["claimId"]
        item.lbc = streamStatus.chatData.result.items[0].meta.effective_amount + " LBC"
        item.ReleaseDate = "LIVE NOW"
        item.guid = streamStatus.chatData.result.items[0].claim_id
        thumbnail = m.top.constants["IMAGE_PROCESSOR"] + streamStatus.chatData.result.items[0].value.thumbnail.url
        item.HDPosterURL = thumbnail
        item.thumbnailDimensions = [360, 240]
        'unneeded as we directly recieve the URL from the page
        item.url = streamStatus.data["url"]
        item.stream = { url: item.url }
        item.link = item.url
        item.streamFormat = "hls"
        item.source = "odysee"
        item.itemType = "livestream"
        curitem = createObject("RoSGNode", "ContentNode")
        curitem.addFields({ creator: "", channelicon: "", thumbnailDimensions: [], itemType: "", lbc: "", Channel: "", guid: "" }) 'added GUID so we can pass it to chat
        curitem.setFields(item)
        currow.appendChild(curitem)
    else
        ?channel + " is not livestreaming"
        result = []
        content = createObject("RoSGNode", "ContentNode")
        counter = 0
    end if
    queryOutput = "placeholder"
    date = CreateObject("roDateTime")
    max = 48
    queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
    queryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": max, "claim_type": "stream", "no_totals": true, "any_tags": [], "not_tags": ["porn", "porno", "nsfw", "mature", "xxx", "sex", "creampie", "blowjob", "handjob", "vagina", "boobs", "big boobs", "big dick", "pussy", "cumshot", "anal", "hard fucking", "ass", "fuck", "hentai"], "channel_ids": [channel], "not_channel_ids": [], "order_by": ["release_time"], "has_no_source": false, "include_purchase_receipt": false, "has_channel_signature": true, "valid_channel_signature": true, "has_source": true } })
    response = postJSON(queryJSON, queryURL, invalid)
    retries = 0
    while true
        if IsValid(response.error)
            response = postJSON(queryJSON, queryURL, invalid)
            retries += 1
        else
            m.top.error = false
            exit while
        end if
        if retries > 5
            m.top.error = true
        end if
    end while

    if m.top.error = false
        items = response.result.items
        ?"got " + str(items.Count()) + " items from Odysee"
        for i = 0 to items.Count() - 1 step 1 'Parse response
            try
                itemValid = isValid(items[i]["value"]["source"]["hash"])
            catch e
                itemValid = false
            end try
            try
                itemValid = isValid(items[i]["value"]["stream_type"])
                if itemValid
                    if items[i]["value"]["stream_type"] = "stream" OR items[i]["value"]["stream_type"] = "video"
                        itemValid = true
                    else
                        itemValid = false
                    end if
                end if
            catch e
                itemValid = false
            end try
            if itemValid
                item = {}
                item.Title = items[i].value.title
                item.Creator = items[i].signing_channel.name
                item.Description = ""
                item.Channel = items[i].signing_channel.claim_id
                try
                    if isValid(items[i].signing_channel.value.thumbnail.url)
                        item.ChannelIcon = m.top.constants["IMAGE_PROCESSOR"] + items[i].signing_channel.value.thumbnail.url
                    else
                        item.ChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
                    end if
                catch e
                    item.ChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
                end try
                item.lbc = items[i].meta.effective_amount + " LBC"
                time = CreateObject("roDateTime")
                try
                    time.FromSeconds(items[i].meta.creation_timestamp)
                catch e
                    time.FromSeconds(items[i].timestamp)
                end try
                timestr = time.AsDateString("short-month-short-weekday") + " "
                timestr = timestr.Trim()
                time = invalid
                item.ReleaseDate = timestr
                item.guid = items[i].claim_id
                try
                    thumbnail = m.top.constants["IMAGE_PROCESSOR"] + items[i].value.thumbnail.url
                catch e
                    thumbnail = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
                end try
                item.HDPosterURL = thumbnail
                item.thumbnailDimensions = [360, 240]
                'all set on watching video due to https://QUERY_API/api/v1/proxy?m=get
                item.url = items[i].permanent_url.Trim() 'to be used to resolve with m?=get
                'item.stream = {url : item.url}
                'item.link = item.url
                'item.streamFormat = ""
                item.source = "odysee"
                item.itemType = "video"
                'Create content (content -> row -> item)
                if counter < 4
                    if IsValid(currow) <> true
                        currow = createObject("RoSGNode", "ContentNode")
                    end if
                    curitem = createObject("RoSGNode", "ContentNode")
                    curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", lbc: "", Channel: "", ChannelIcon: "" })
                    curitem.setFields(item)
                    currow.appendChild(curitem)
                    if i = items.Count() - 1 'misalignment fix, will need to implement this better later.
                        content.appendChild(currow)
                    end if
                    counter += 1
                    curitem = invalid
                else
                    content.appendChild(currow)
                    currow = invalid
                    currow = createObject("RoSGNode", "ContentNode")
                    curitem = createObject("RoSGNode", "ContentNode")
                    curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", lbc: "", Channel: "", ChannelIcon: "" })
                    curitem.setFields(item)
                    currow.appendChild(curitem)
                    counter = 1
                    curitem = invalid
                end if
                result.push(item) 'Unparsed "XMLContent", can be used to cache results later.
                item = invalid
            end if
        end for
        '?type(content)
        ?"exported" + Str(content.getChildCount() * 4) + " items from Odysee"

        '?"manufacturing finished for key: "+subkey
        return { contentarray: result: content: content } 'Returns the array
    else
        return { error: true }
    end if
end function