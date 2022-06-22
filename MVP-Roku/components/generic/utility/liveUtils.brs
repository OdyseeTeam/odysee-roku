function getLivestream(channel)
    try
        'Github seems to be at least one commit behind, making a placeholder commit.
        livestreamStatus = getJSON(m.top.constants["NEW_LIVE_API"] + "/is_live?channel_claim_id=" + channel)
        liveData = livestreamStatus.data
        if liveData["Live"]
            lsqueryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
            lsqueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "fee_amount": "<=0", "claim_id": liveData["ActiveClaim"]["ClaimID"] } })
            livestreamClaimQuery = postJSON(lsqueryJSON, lsqueryURL, invalid)
            liveClaim = livestreamclaimquery["result"]["items"][0]
            if getRawTextAuthenticated(liveData["VideoURL"], m.top.constants["ACCESS_HEADERS"]) = "{error: True}"
                return { success: false }
            end if
            liveItem = parseLiveData(channel, liveData, liveClaim)
            return { liveItem: liveItem : success: true }
        else
            return { success: false }
        end if
    catch e
        return { success: false }
    end try
end function

function getLivestreamChannelList(excluded_cids) 'creates a preformatted+sorted channel IDs list from the livestream endpoint
    cidMap = {}
    if excluded_cids.Count() > 0
        for each channelID in excluded_cids
            cidMap.addReplace(channelID, true)
        end for
    end if
    'https://api.odysee.live/livestream/all
    livestreamData = getJSON(m.top.constants["NEW_LIVE_API"]+"/all")
    livestreamIDs = []
    if isValid(livestreamData["data"])
        if livestreamData["data"].Count() > 0
            livestreamData["data"].sortBy("ViewerCount", "r")
            numLiveItems = 0
            i = 0
            while true
                if isValid(livestreamData["data"][i])
                    CCID = livestreamData["data"][i]["ChannelClaimID"]
                    if isValid(cidMap[CCID]) = false
                        livestreamIDs.push(CCID)
                        numLiveItems+=1
                    end if
                    CCID = invalid
                    if numLiveItems = 8
                        exit while
                    end if
                    i+=1
                else
                    exit while
                end if
            end while
            cidMap = invalid
            livestreamData = invalid
            numLiveItems = invalid
            i = invalid
            return livestreamIDs
        else
            return false
        end if
    else
        return false
    end if
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
    try
        item.Creator = liveClaim["signing_channel"]["value"]["title"]
    catch e
        item.Creator = liveClaim["signing_channel"]["name"]
    end try
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