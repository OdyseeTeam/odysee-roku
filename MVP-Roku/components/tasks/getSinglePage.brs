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
    m.top.output = ChannelsToVideoGrid(m.top.channels, m.top.blocked)
end sub

function ChannelsToVideoGrid(channels, blockedChannels)
    result = [] 'This is an array of associativeArrays that can be used to set a ContentNode
    try
        'Incoming channels can be invalid in open queries. (e.g: Universe)
        'Stage 1: Parse content
        channels = m.top.channels
        queryOutput = "placeholder"
        date = CreateObject("roDateTime")
        max = 48
        queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
        date = CreateObject("roDateTime")
        date.Mark()
        curTime = date.AsSeconds()

        if m.top.rawname = "FAVORITES" OR m.top.sortOrder = "new"
            orderBy = ["release_time"]
        else
            orderBy = ["trending_group","trending_mixed"]
        end if

        queryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": max, "claim_type": "stream", "media_types": ["video/mp4"], "no_totals": true, "any_tags": [], "not_tags": ["porn", "porno", "nsfw", "mature", "xxx", "sex", "creampie", "blowjob", "handjob", "vagina", "boobs", "big boobs", "big dick", "pussy", "cumshot", "anal", "hard fucking", "ass", "fuck", "hentai"], "channel_ids": channels, "not_channel_ids": m.top.blocked, "order_by": orderBy, "release_time": "<"+curTime.toStr(), "has_no_source": false, "include_purchase_receipt": false, "has_channel_signature": true, "valid_channel_signature": true, "has_source": true } })

        response = postJSON(queryJSON, queryURL, invalid)
        retries = 0
        while true
            if IsValid(response.error)
                response = postJSON(queryJSON, queryURL, invalid)
                retries += 1
            else
                exit while
            end if
            if retries > 5
                exit while
            end if
        end while
        items = response.result.items
        if m.top.resolveLivestreams 'we have to resolve livestreams now, apparently.
            for each channel in channels
                streamStatus = getLivestream(channel)
                if streamStatus.success = true
                    result.push(streamStatus.liveItem)
                end if
            end for
           'STOP
        end if
        
        ?"got " + str(items.Count()) + " items from Odysee"
        for i = 0 to items.Count() - 1 step 1 'Parse response
            item = {}
            item.Title = items[i].value.title
            item.Creator = items[i].signing_channel.name
            item.Description = ""
            item.Channel = items[i].signing_channel.claim_id

            try
                if isValid(items[i].signing_channel.value.thumbnail.url)
                    item.ChannelIcon = m.top.constants["CHANNEL_ICON_PROCESSOR"] + items[i].signing_channel.value.thumbnail.url
                else
                    item.ChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
                end if
            catch e
                item.ChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
            end try

            time = CreateObject("roDateTime")
            try
                try
                    time.FromSeconds(items[i]["value"]["release_time"])
                catch e
                    time.FromSeconds(items[i].meta.creation_timestamp)
                end try
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
            result.push(item) 'Unparsed "XMLContent", can be used to cache results later.
            item = invalid
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
        '?type(content)
        ?"exported" + Str(content.getChildCount() * 4) + " items from Odysee"

        '?"manufacturing finished for key: "+subkey
        m.top.error = false
        return { contentarray: result: content: content } 'Returns the array
    catch e
        m.top.error = true
        m.top.numerrors += 1
        return { error: true }
    end try
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
    try
        item.HDPosterURL = m.top.constants["IMAGE_PROCESSOR"] + liveClaim["value"]["thumbnail"]["url"]
    catch e
        item.HDPosterURL = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
    end try
    item.thumbnailDimensions = [360, 240]
    try
        item.channelIcon = m.top.constants["IMAGE_PROCESSOR"] + liveClaim["signing_channel"]["value"]["thumbnail"]["url"]
    catch e
        item.channelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
    end try
    item.url = liveData["VideoURL"]
    item.stream = { url: item.url }
    item.link = item.url
    item.streamFormat = "hls"
    item.source = "odysee"
    item.itemType = "livestream"
    'STOP
    return item
end function