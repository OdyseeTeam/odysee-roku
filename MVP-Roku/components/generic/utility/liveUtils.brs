function getLivestream(channel)
    try
        'Github seems to be at least one commit behind, making a placeholder commit.
        livestreamStatus = getJSON(m.top.constants["NEW_LIVE_API"] + "/is_live?channel_claim_id=" + channel)
        liveData = livestreamStatus.data
        if liveData["Live"]
            lsqueryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
            lsqueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "fee_amount": "<=0", "claim_id": liveData["ActiveClaim"]["ClaimID"], "page": 1, "page_size": 1, "no_totals": true }, "id": m.top.uid })
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

function getLivestreamsBatch(claimIDs, liveData, liveIDs)
    livestreams = []
    try
        if isValid(claimIDs) and isValid(liveData) and isValid(liveIDs)
            if claimIDs.Count() = liveData.Count() and liveIDs.Count() = claimIDs.Count()
                lsqueryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
                pageSize = claimIDs.Count()
                if pageSize <= 0 then pageSize = 50
                lsqueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "fee_amount": "<=0", "claim_ids": claimIDs, "page": 1, "page_size": pageSize, "no_totals": true }, "id": m.top.uid })
                livestreamClaimQuery = postJSON(lsqueryJSON, lsqueryURL, invalid)
                liveClaims = livestreamclaimquery["result"]["items"]
                if liveIDs.Count() = liveClaims.Count()
                    liveClaimsIndexed = {}
                    for each claim in liveclaims
                        liveClaimsIndexed.addReplace(claim.claim_id, claim)
                    end for
                    for each claim in livedata
                        livestreams.push(parseLiveData(claim["ChannelClaimID"],claim,liveClaimsIndexed[claim["ActiveClaim"]["ClaimID"]]))
                    end for
                    liveClaimsIndexed = invalid
                    claim = invalid
                end if
            end if
        end if
    catch e
        return []
    end try
    return livestreams
end function

function getLiveDataFromCIDS(included_cids)
    try
        cidMap = {}
        if included_cids.Count() > 0
            for each channelID in included_cids
                cidMap.addReplace(channelID, true)
            end for
        end if
        'https://api.odysee.live/livestream/all
        livestreamData = getJSON(m.top.constants["NEW_LIVE_API"] + "/all")
        livestreamIDs = []
        livestreamClaims = []
        rawLivestreamData = []
        if isValid(livestreamData["data"])
            if livestreamData["data"].Count() > 0
                livestreamData["data"].sortBy("ViewerCount", "r")
                numLiveItems = 0
                i = 0
                while true
                    if isValid(livestreamData["data"][i])
                        CCID = livestreamData["data"][i]["ChannelClaimID"]
                        if isValid(cidMap[CCID])
                            livestreamIDs.push(CCID)
                            livestreamClaims.push(livestreamData["data"][i]["ActiveClaim"]["ClaimID"])
                            rawLivestreamData.push(livestreamData["data"][i])
                            numLiveItems += 1
                        end if
                        CCID = invalid
                        'if numLiveItems = 8
                        '    exit while
                        'end if
                        i += 1
                    else
                        exit while
                    end if
                end while
                cidMap = invalid
                livestreamData = invalid
                numLiveItems = invalid
                i = invalid
                return { liveIDs: livestreamIDs, liveData: rawLivestreamData, claimIDs: livestreamClaims }
            else
                return false
            end if
        else
            return false
        end if
    catch e
        return false
    end try
end function

function getLivestreamChannelList(excluded_cids) 'creates a preformatted+sorted channel IDs list from the livestream endpoint
    try
        cidMap = {}
        if excluded_cids.Count() > 0
            for each channelID in excluded_cids
                cidMap.addReplace(channelID, true)
            end for
        end if
        'https://api.odysee.live/livestream/all
        livestreamData = getJSON(m.top.constants["NEW_LIVE_API"] + "/all")
        livestreamIDs = []
        livestreamClaims = []
        rawLivestreamData = []
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
                            livestreamClaims.push(livestreamData["data"][i]["ActiveClaim"]["ClaimID"])
                            rawLivestreamData.push(livestreamData["data"][i])
                            numLiveItems += 1
                        end if
                        CCID = invalid
                        if numLiveItems = 8
                            exit while
                        end if
                        i += 1
                    else
                        exit while
                    end if
                end while
                cidMap = invalid
                livestreamData = invalid
                numLiveItems = invalid
                i = invalid
                return { liveIDs: livestreamIDs, liveData: rawLivestreamData, claimIDs: livestreamClaims }
            else
                return false
            end if
        else
            return false
        end if
    catch e
        return false
    end try
end function

function parseLiveData(channel, liveData, liveClaim)
    item = {}
    time = CreateObject("roDateTime")
    ' Started "X ago" text from Start
    startedAgo = ""
    try
        time.FromISO8601String(liveData["Start"])
        streamStart = time.AsSeconds()
        nowDT = CreateObject("roDateTime")
        nowSecs = nowDT.AsSeconds()
        diff = nowSecs - streamStart
        if diff < 0 then diff = 0
        minutes = Int(diff / 60)
        hours = Int(diff / 3600)
        days = Int(diff / 86400)
        if days > 0
            if days = 1 then startedAgo = "Started 1 day ago" else startedAgo = "Started " + days.ToStr() + " days ago"
        else if hours > 0
            if hours = 1 then startedAgo = "Started 1 hour ago" else startedAgo = "Started " + hours.ToStr() + " hours ago"
        else
            if minutes = 1 then startedAgo = "Started 1 minute ago" else startedAgo = "Started " + minutes.ToStr() + " minutes ago"
        end if
        nowDT = invalid
    catch e
        streamStart = 0
        startedAgo = "Live now"
    end try
    time = invalid
    ' Title from claim (defensive)
    try
        item.Title = liveClaim.value.title
    catch e
        item.Title = ""
    end try
    ' Creator from claim (defensive)
    try
        item.Creator = liveClaim.signing_channel.value.title
    catch e
        try
            item.Creator = liveClaim.signing_channel.name
        catch e2
            item.Creator = ""
        end try
    end try
    item.Channel = channel
    item.ReleaseDate = startedAgo
    item.startUTC = streamStart 'for future use
    item.guid = ""
    try
        item.guid = liveData.ActiveClaim.ClaimID
    catch e
        ' leave blank if not present
    end try
    ' Poster thumbnail with fallbacks (claim → live API → channel)
    hdPoster = invalid
    posterUrl = ""
    ' Try claim thumbnail first
    try
        posterUrl = liveClaim.value.thumbnail.url
    catch e
        posterUrl = ""
    end try
    if posterUrl = ""
        ' Try live API thumbnail
        try
            posterUrl = liveData.ThumbnailURL
        catch e
            posterUrl = ""
        end try
    end if
    if posterUrl = ""
        ' Fallback to channel thumbnail
        try
            posterUrl = liveClaim.signing_channel.value.thumbnail.url
        catch e
            posterUrl = ""
        end try
    end if
    if posterUrl <> ""
        ' If posterUrl already absolute, do not double-prefix
        if Left(posterUrl, 4) = "http"
            hdPoster = posterUrl
        else
            hdPoster = m.top.constants["IMAGE_PROCESSOR"] + posterUrl
        end if
    else
        hdPoster = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
    end if
    item.HDPosterURL = hdPoster
    item.HDPOSTERURL = hdPoster
    item.thumbnailDimensions = [360, 240]
    chThumb = ""
    try
        chThumb = liveClaim.signing_channel.value.thumbnail.url
    catch e
        chThumb = ""
    end try
    if chThumb <> ""
        if Left(chThumb, 4) = "http"
            chIcon = chThumb
        else
            chIcon = m.top.constants["CHANNEL_ICON_PROCESSOR"] + chThumb
        end if
    else
        chIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
    end if
    item.ChannelIcon = chIcon
    item.url = liveData["VideoURL"]
    item.stream = { url: item.url }
    item.link = item.url
    item.streamFormat = "hls"
    item.source = "odysee"
    item.itemType = "livestream"
    ' Ensure both cases for poster URL are set
    item.HDPOSTERURL = item.HDPosterURL
    ' Viewer count (raw and display)
    try
        item.viewers = liveData["ViewerCount"]
        v = item.viewers
        if v >= 1000000
            item.viewerDisplay = Str(Int(v / 1000000)) + "M"
        else if v >= 1000
            item.viewerDisplay = Str(Int(v / 1000)) + "K"
        else
            item.viewerDisplay = v.ToStr()
        end if
    catch e
        item.viewers = 0
        item.viewerDisplay = ""
    end try
    return item
end function