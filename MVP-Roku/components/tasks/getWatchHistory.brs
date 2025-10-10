sub Init()
    m.top.functionName = "fetchMetadata"
end sub

' Format duration in seconds to HH:MM:SS or MM:SS format (matches parseVideo logic)
function formatDuration(length as dynamic) as string
    if not IsValid(length) or length <= 0 then return "0:00"

    timeConverter = CreateObject("roDateTime")
    timeConverter.FromSeconds(length)

    hours = timeConverter.GetHours()
    minutes = timeConverter.GetMinutes()
    seconds = timeConverter.GetSeconds()

    ' Format with leading zeros
    hoursStr = hours.ToStr()
    if hours < 10 then hoursStr = "0" + hoursStr

    minutesStr = minutes.ToStr()
    if minutes < 10 then minutesStr = "0" + minutesStr

    secondsStr = seconds.ToStr()
    if seconds < 10 then secondsStr = "0" + secondsStr

    ' Return format based on length
    if length < 3600
        ' Under 1 hour: MM:SS
        return minutesStr + ":" + secondsStr
    else if length < 86400
        ' Under 1 day: HH:MM:SS
        return hoursStr + ":" + minutesStr + ":" + secondsStr
    else
        ' Over 1 day: include days
        days = timeConverter.GetDayOfMonth()
        daysStr = days.ToStr()
        if days < 10 then daysStr = "0" + daysStr
        return daysStr + ":" + hoursStr + ":" + minutesStr + ":" + secondsStr
    end if
end function

sub fetchMetadata()
    if not IsValid(m.top.constants) or not IsValid(m.top.constants["QUERY_API"])
        print "[getWatchHistory] Constants not available"
        m.top.output = []
        return
    end if

    if not IsValid(m.top.historyItems) or m.top.historyItems.Count() = 0
        print "[getWatchHistory] No history items to fetch"
        m.top.output = []
        return
    end if

    ' Process in batches of 50 (claim_search limit)
    batchSize = 50
    allResults = []

    for startIdx = 0 to m.top.historyItems.Count() - 1 step batchSize
        endIdx = startIdx + batchSize - 1
        if endIdx >= m.top.historyItems.Count() then endIdx = m.top.historyItems.Count() - 1

        ' Extract claim IDs for this batch
        batchClaimIds = []
        for i = startIdx to endIdx
            batchClaimIds.Push(m.top.historyItems[i].claimId)
        end for

        print "[getWatchHistory] Fetching batch "; (startIdx / batchSize) + 1; " ("; batchClaimIds.Count(); " claims)"

        ' Call claim_search
        queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
        params = {
            "claim_ids": batchClaimIds,
            "page": 1,
            "page_size": batchSize,
            "no_totals": true
        }

        q = FormatJson({"jsonrpc": "2.0", "method": "claim_search", "params": params, "id": m.top.uid})
        resp = postJSON(q, queryURL, invalid)

        if IsValid(resp) and IsValid(resp.result) and IsValid(resp.result.items)
            print "[getWatchHistory] Received "; resp.result.items.Count(); " results for batch"

            ' Build lookup map of API results by claim_id for O(1) access
            resultsMap = {}
            for each item in resp.result.items
                resultsMap[item.claim_id] = item
            end for

            ' Merge with history data - iterate through historyItems to maintain sort order
            for i = startIdx to endIdx
                claimId = m.top.historyItems[i].claimId
                ' O(1) lookup instead of O(n) search
                if resultsMap.DoesExist(claimId)
                    item = resultsMap[claimId]
                        ' Detect if this is a livestream (no video source or no duration)
                        isLivestream = false
                        if not IsValid(item.value.video) or not IsValid(item.value.video.duration) or item.value.video.duration = 0
                            isLivestream = true
                        end if
                        if IsValid(item.value.source) and IsValid(item.value.source.media_type) and item.value.source.media_type = "video/mp4"
                            isLivestream = false ' Has video source, definitely not livestream
                        end if

                        ' Add metadata to result - all from claim_search
                        result = {
                            claimId: item.claim_id,
                            title: item.value.title,
                            thumbnailUrl: "",
                            channelName: "",
                            channelId: "",
                            channelIcon: "",
                            releaseDate: "",
                            videoLength: "",
                            permanentUrl: "",
                            position: m.top.historyItems[i].position,
                            lastPlayedAt: m.top.historyItems[i].lastPlayedAt,
                            itemType: "video"
                        }

                        ' Set itemType for livestreams
                        if isLivestream then result.itemType = "livestream"

                        ' Get duration from claim_search for progress calculation
                        duration = 0
                        if IsValid(item.value.video) and IsValid(item.value.video.duration)
                            duration = item.value.video.duration
                        end if
                        result.duration = duration

                        ' Add thumbnail if available (use IMAGE_PROCESSOR for optimization)
                        if IsValid(item.value.thumbnail) and IsValid(item.value.thumbnail.url)
                            if IsValid(m.top.constants) and IsValid(m.top.constants["IMAGE_PROCESSOR"])
                                result.thumbnailUrl = m.top.constants["IMAGE_PROCESSOR"] + item.value.thumbnail.url
                            else
                                result.thumbnailUrl = item.value.thumbnail.url
                            end if
                        end if

                        ' Add permanent URL if available (needed for video playback)
                        ' For livestreams, don't use permanent_url as it may be a vanity URL (lbry://shortname#id)
                        ' Instead leave it empty so WatchHistoryScene will use claim_id fallback
                        if IsValid(item.permanent_url) and not isLivestream
                            result.permanentUrl = item.permanent_url
                        end if

                        ' Add channel info if available (matching parseVideo logic)
                        if IsValid(item.signing_channel)
                            print "[getWatchHistory] Processing signing_channel for: "; item.claim_id

                            ' Try value.title first, fallback to name
                            try
                                result.channelName = item.signing_channel.value.title
                                print "[getWatchHistory] Channel title from value.title: "; result.channelName
                            catch e
                                result.channelName = item.signing_channel.name
                                print "[getWatchHistory] Channel name from name: "; result.channelName
                            end try

                            result.channelId = item.signing_channel.claim_id

                            ' Add channel icon with error handling (matching parseVideo logic)
                            try
                                iconPath = item.signing_channel.value.thumbnail.url
                                print "[getWatchHistory] Raw icon path: "; iconPath
                                if IsValid(iconPath)
                                    if IsValid(m.top.constants) and IsValid(m.top.constants["CHANNEL_ICON_PROCESSOR"])
                                        result.channelIcon = m.top.constants["CHANNEL_ICON_PROCESSOR"] + iconPath
                                        print "[getWatchHistory] Processed icon: "; result.channelIcon
                                    else
                                        result.channelIcon = iconPath
                                        print "[getWatchHistory] Raw icon (no processor): "; result.channelIcon
                                    end if
                                else
                                    result.channelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
                                    print "[getWatchHistory] Icon invalid, using fallback"
                                end if
                            catch e
                                result.channelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
                                print "[getWatchHistory] Icon error: "; e.message
                            end try
                        else
                            print "[getWatchHistory] NO signing_channel for: "; item.claim_id
                        end if

                        ' Add release date if available
                        if IsValid(item.value.release_time)
                            releaseDate = CreateObject("roDateTime")
                            releaseTime = item.value.release_time
                            if Type(releaseTime) = "String" or Type(releaseTime) = "roString"
                                releaseTime = Val(releaseTime)
                            end if
                            releaseDate.FromSeconds(releaseTime)
                            result.releaseDate = releaseDate.AsDateString("short-month-no-weekday")
                        end if

                        ' Add video length - use claim_search metadata (matches parseVideo format)
                        try
                            if IsValid(item.value.video) and IsValid(item.value.video.duration)
                                result.videoLength = formatDuration(item.value.video.duration)
                            else
                                result.videoLength = "0:00"
                            end if
                        catch e
                            result.videoLength = "0:00"
                        end try

                        allResults.Push(result)
                end if
            end for
        else
            print "[getWatchHistory] Error fetching batch"
        end if
    end for

    print "[getWatchHistory] Total results: "; allResults.Count()

    ' Filter out inactive livestreams and clean up registry
    filteredResults = filterInactiveLivestreams(allResults)

    print "[getWatchHistory] After filtering inactive livestreams: "; filteredResults.Count()
    m.top.output = filteredResults
end sub

' Filter out inactive livestreams and remove them from registry
function filterInactiveLivestreams(results as object) as object
    if not IsValid(results) or results.Count() = 0 then return results

    ' Collect all livestream items and their channel IDs
    livestreamChannels = {}
    for each result in results
        if IsValid(result.itemType) and result.itemType = "livestream"
            if IsValid(result.channelId) and result.channelId <> ""
                livestreamChannels[result.channelId] = true
            end if
        end if
    end for

    if livestreamChannels.Count() = 0
        print "[getWatchHistory] No livestreams to check"
        return results
    end if

    print "[getWatchHistory] Checking "; livestreamChannels.Count(); " livestream channels"

    ' Check which channels are currently live
    activeChannels = {}
    try
        ' Fetch all currently active livestreams
        liveAPI = m.top.constants["NEW_LIVE_API"] + "/all"
        livestreamData = getJSON(liveAPI)

        if IsValid(livestreamData) and IsValid(livestreamData["data"]) and livestreamData["data"].Count() > 0
            for each liveStream in livestreamData["data"]
                if IsValid(liveStream["ChannelClaimID"])
                    channelId = liveStream["ChannelClaimID"]
                    ' Mark this channel as having an active livestream
                    activeChannels[channelId] = true
                end if
            end for
        end if
        print "[getWatchHistory] Found "; activeChannels.Count(); " active livestream channels"
    catch e
        print "[getWatchHistory] Error checking livestream status: "; e.message
        ' If we can't check, keep all livestreams
        return results
    end try

    ' Filter results and remove inactive livestreams from registry
    filteredResults = []
    reg = CreateObject("roRegistrySection", "watchHistory")

    for each result in results
        if IsValid(result.itemType) and result.itemType = "livestream"
            ' Check if this livestream's channel is currently active
            if IsValid(result.channelId) and activeChannels.DoesExist(result.channelId)
                ' Livestream is still active, keep it
                filteredResults.Push(result)
                print "[getWatchHistory] Keeping active livestream: "; result.title
            else
                ' Livestream is no longer active, remove from history
                print "[getWatchHistory] Removing inactive livestream from history: "; result.title
                if IsValid(result.claimId) and result.claimId <> ""
                    reg.Delete(result.claimId)
                end if
            end if
        else
            ' Not a livestream, keep it
            filteredResults.Push(result)
        end if
    end for

    ' Flush registry changes
    reg.Flush()

    return filteredResults
end function
