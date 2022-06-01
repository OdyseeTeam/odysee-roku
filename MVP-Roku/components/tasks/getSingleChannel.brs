sub Init()
    m.top.functionName = "master"
end sub

sub master()
    '? m.top.constants
    '? m.top.cookies
    '? m.top.uid
    '? m.top.authtoken
    '? m.top.channels
    '? m.top.rawname
    m.top.resolveAttempts = 0
    m.top.output = ChannelToVideoGrid(m.top.channel)
end sub
function ChannelToVideoGrid(channel)
    queryOutput = "placeholder"
    date = CreateObject("roDateTime")
    max = 48
    queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
    queryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": max, "claim_type": "stream", "media_types": ["video/mp4"], "no_totals": true, "any_tags": [], "not_tags": ["porn", "porno", "nsfw", "mature", "xxx", "sex", "creampie", "blowjob", "handjob", "vagina", "boobs", "big boobs", "big dick", "pussy", "cumshot", "anal", "hard fucking", "ass", "fuck", "hentai"], "channel_ids": [channel], "not_channel_ids": [], "order_by": ["release_time"], "has_no_source": false, "include_purchase_receipt": false, "has_channel_signature": true, "valid_channel_signature": true, "has_source": true } })
    response = postJSON(queryJSON, queryURL, invalid)
    retries = 0
    result = []
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
    if m.top.error = false 'Stage 1: Parse content
        items = response.result.items
        try
            m.top.ChannelIcon = m.top.constants["CHANNEL_ICON_PROCESSOR"] + items[1].signing_channel.value.thumbnail.url
        catch e
            m.top.ChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
        end try
        defaultChannelIcon = m.top.channelIcon
        streamStatus = getLivestream(channel)
        if streamStatus.success = true
            result.push(streamStatus.liveItem)
        else
            ? channel + " is not livestreaming"
        end if
        ? "got " + str(items.Count()) + " items from Odysee"
        for i = 0 to items.Count() - 1 step 1 'Parse response
            item = {}
            item.Title = items[i].value.title
            item.Creator = items[i].signing_channel.name
            item.Description = ""
            item.Channel = items[i].signing_channel.claim_id
            item.ChannelIcon = defaultChannelIcon
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
            result.push(item)
        end for
        'Stage 2: Format Content (content -> row -> item) from "result"/preparsed.
        content = createObject("RoSGNode", "ContentNode")
        counter = 0
        for each item in result
            if counter < 4
                if IsValid(currow) <> true
                    currow = createObject("RoSGNode", "ContentNode")
                end if
                curitem = createObject("RoSGNode", "ContentNode")
                curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", Channel: "", ChannelIcon: "" })
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
                curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", Channel: "", ChannelIcon: "" })
                curitem.setFields(item)
                currow.appendChild(curitem)
                counter = 1
                curitem = invalid
            end if
        end for
        defaultChannelIcon = invalid
        '? type(content)
        ? "exported" + Str(content.getChildCount() * 4) + " items from Odysee"

        '? "manufacturing finished for key: "+subkey
        return { contentarray: result: content: content } 'Returns the array
    else
        return { error: true }
    end if
end function

function getLivestream(channel)
    try
        'Github seems to be at least one commit behind, making a placeholder commit.
        livestreamStatus = getJSON(m.top.constants["NEW_LIVE_API"] + "/is_live?channel_claim_id=" + channel)
        liveData = livestreamStatus.data
        if liveData["Live"]
            lsqueryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
            lsqueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "claim_id": liveData["ActiveClaim"]["ClaimID"] } })
            livestreamClaimQuery = postJSON(lsqueryJSON, lsqueryURL, invalid)
            liveClaim = livestreamclaimquery["result"]["items"][0]
            liveItem = parseLiveData(channel, liveData, liveClaim)
            return { liveItem: liveItem : success: true }
        else
            return { success: false }
        end if
    catch e
        return { success: false }
    end try
end function

function parseLiveData(channel, liveData, liveClaim)
    item = {}
    time = CreateObject("roDateTime")
    time.FromISO8601String(liveData["ActiveClaim"]["ReleaseTime"])
    timestr = time.AsDateString("short-month-short-weekday") + " "
    timestr = timestr.Trim()
    time.FromISO8601String(liveData["Start"])
    streamStart = time.AsSeconds()
    time = invalid
    item.Title = liveClaim["value"]["title"]
    item.Creator = liveClaim["signing_channel"]["name"]
    item.Channel = channel
    item.ReleaseDate = timestr
    item.startUTC = streamStart 'for future use
    item.guid = liveData["ActiveClaim"]["ClaimID"]
    thumbnail = m.top.constants["IMAGE_PROCESSOR"] + liveClaim["value"]["thumbnail"]["url"]
    item.HDPosterURL = thumbnail
    item.thumbnailDimensions = [360, 240]
    item.channelIcon = m.top.channelIcon
    item.url = liveData["VideoURL"]
    item.stream = { url: item.url }
    item.link = item.url
    item.streamFormat = "hls"
    item.source = "odysee"
    item.itemType = "livestream"
    return item
end function