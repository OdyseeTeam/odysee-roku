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
    streamStatus = getLivestream(channel)
    ? streamStatus
    ? Type(streamStatus)
    if streamStatus.success = true
        mediaindex = {}
        result = []
        'since the user is livestreaming, we should add it here, before anything else.
        content = createObject("RoSGNode", "ContentNode")
        'This will allow us to insert 1 item at the very beginning, since we use counter+curRow to form the Rows that the user views.
        currow = createObject("RoSGNode", "ContentNode")
        counter = 1
        curitem = createObject("RoSGNode", "ContentNode")
        curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", lbc: "", Channel: "", guid: "" }) 'added GUID so we can pass it to chat
        curitem.setFields(streamStatus.liveItem)
        currow.appendChild(curitem)
    else
        ? channel + " is not livestreaming"
        mediaindex = {}
        result = []
        content = createObject("RoSGNode", "ContentNode")
        counter = 0
    end if
    queryOutput = "placeholder"
    date = CreateObject("roDateTime")
    max = 48
    queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
    queryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": max, "claim_type": "stream", "media_types": ["video/mp4"], "no_totals": true, "any_tags": [], "not_tags": ["porn", "porno", "nsfw", "mature", "xxx", "sex", "creampie", "blowjob", "handjob", "vagina", "boobs", "big boobs", "big dick", "pussy", "cumshot", "anal", "hard fucking", "ass", "fuck", "hentai"], "channel_ids": [channel], "not_channel_ids": [], "order_by": ["release_time"], "has_no_source": false, "include_purchase_receipt": false, "has_channel_signature": true, "valid_channel_signature": true, "has_source": true } })
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
        ? "got " + str(items.Count()) + " items from Odysee"
        for i = 0 to items.Count() - 1 step 1 'Parse response
            item = {}
            item.Title = items[i].value.title
            item.Creator = items[i].signing_channel.name
            item.Description = ""
            item.Channel = items[i].signing_channel.claim_id
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
                curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", lbc: "", Channel: "" })
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
                curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", lbc: "", Channel: "" })
                curitem.setFields(item)
                currow.appendChild(curitem)
                counter = 1
                curitem = invalid
            end if
            mediaindex[item.guid] = item
            item = invalid
        end for
        '? type(content)
        ? "exported" + Str(content.getChildCount() * 4) + " items from Odysee"

        '? "manufacturing finished for key: "+subkey
        return { contentarray: result: index: mediaindex: content: content } 'Returns the array
    else
        return { error: true }
    end if
end function


function getLivestream(channel)
    try
        livestreamStatus = getJSON(m.top.constants["NEW_LIVE_API"] + "/is_live?channel_claim_id=" + channel)
        liveData = livestreamStatus.data
        lsqueryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
        lsqueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "claim_id": liveData["ActiveClaim"]["ClaimID"] } })
        livestreamClaimQuery = postJSON(lsqueryJSON, lsqueryURL, invalid)
        liveClaim = livestreamclaimquery["result"]["items"][0]
        liveItem = parseLiveData(channel, liveData, liveClaim)
        return { liveItem: liveItem : success: true }
    catch e
        'if all else fails, try legacy
        return getLivestreamLegacy(channel)
    end try
end function

function getLivestreamLegacy(channel)
    try
        'This finds if a user is livestreaming. If it is, it gets the livestream data, and then resolves the chat claimId for that individual livestream.
        'Chat is only attached to the latest livestream. If the user streams more than one livestream, we will have a problem.
        livestreamStatus = getJSON(m.top.constants["LIVE_API"] + "/" + channel)
        livestreamData = livestreamStatus["data"]
        if livestreamData.live = false
            return { success: false }
        else
            lsqueryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
            lsqueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": 1, "claim_type": "stream", "no_totals": true, "any_tags": [], "not_tags": ["porn", "porno", "nsfw", "mature", "xxx", "sex", "creampie", "blowjob", "handjob", "vagina", "boobs", "big boobs", "big dick", "pussy", "cumshot", "anal", "hard fucking", "ass", "fuck", "hentai"], "channel_ids": [channel], "not_channel_ids": [], "order_by": ["release_time"], "has_no_source": true, "include_purchase_receipt": false, "has_channel_signature": true, "valid_channel_signature": true, "has_source": false } })
            liveClaim = postJSON(lsqueryJSON, lsqueryURL, invalid).result.items[0]
            'if start=releaseTime, we used legacy
            liveData = { "ActiveClaim": { "ClaimID": liveClaim.claim_id, "ReleaseTime": livestreamstatus["data"]["timestamp"] }, "Start": livestreamstatus["data"]["timestamp"], "VideoURL": livestreamstatus["data"]["url"] }
            liveItem = parseLiveData(channel, liveData, liveClaim)
            return { liveItem: liveItem : success: true }
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
    item.Creator = liveClaim["signing_channel"]["name"].Replace("@", "")
    item.Channel = channel
    item.ReleaseDate = timestr
    item.startUTC = streamStart 'for future use
    item.guid = liveData["ActiveClaim"]["ClaimID"]
    thumbnail = m.top.constants["IMAGE_PROCESSOR"] + liveClaim["value"]["thumbnail"]["url"]
    item.HDPosterURL = thumbnail
    item.thumbnailDimensions = [360, 240]
    item.url = liveData["VideoURL"]
    item.stream = { url: item.url }
    item.link = item.url
    item.streamFormat = "hls"
    item.source = "odysee"
    item.itemType = "livestream"
    return item
end function