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
            if getRawText(liveData["VideoURL"]) = "{error: True}"
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