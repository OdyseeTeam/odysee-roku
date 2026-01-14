function parseVideo(itemIn)
    'check repost/item has source
    'check repost/item source has valid media_type
    item = {reposted:false:"repostedBy":"none":"Creator":"none":"Title":"none":"rawCreator":"none":"Channel":"none":"videoLength":0:"channelIcon":"none":"HDPosterURL":"none":url:"none":source:"none":"itemType":"none"}
    m.timeConverter = CreateObject("roDateTime")
    m.time = CreateObject("roDateTime")
    'Find out if item is repost
    if isValid(itemIn.reposted_claim)
        curItem = itemIn.reposted_claim
        'item.reposted = true
        'try
        '    item.repostedBy = itemIn.signing_channel.value.title
        'catch e
        '    try
        '        item.repostedBy = itemIn.signing_channel.name
        '    catch e
        '        item.repostedBy = "Anonymous"
        '    end try
        'end try
    else
        curItem = itemIn
    end if

    'Find out if item has valid source
    try
        if curItem["value"].source.media_type = "video/mp4"
            item.Title = curItem.value.title
            try
                item.Creator = curItem.signing_channel.value.title
            catch e
                item.Creator = curItem.signing_channel.name
            end try
            item.rawCreator = curItem.signing_channel.name
            item.Channel = curItem.signing_channel.claim_id
            try
                item.videoLength = getvideoLength(curItem["value"]["video"]["duration"])
            catch e
                item.videoLength = "0:00"
            end try
            ' Only assign ChannelIcon when needed; always through optimizer (100x0)
            try
                iconPath = curItem.signing_channel.value.thumbnail.url
                if isValid(iconPath)
                    item.ChannelIcon = m.top.constants["CHANNEL_ICON_PROCESSOR"] + iconPath
                else
                    item.ChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
                end if
            catch e
                item.ChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
            end try
            ' Prefer release_time, fallback to timestamp if not available
            dateSet = false
            dateSource = "none"
            ' Try release_time first (actual publish date)
            try
                if isValid(curItem.value) and isValid(curItem.value.release_time)
                    releaseTimeVal = 0
                    ' Handle both string and numeric release_time
                    if Type(curItem.value.release_time) = "roString" or Type(curItem.value.release_time) = "String"
                        releaseTimeVal = Val(curItem.value.release_time)
                    else
                        releaseTimeVal = curItem.value.release_time
                    end if
                    if releaseTimeVal > 0
                        m.time.FromSeconds(releaseTimeVal)
                        dateSet = true
                        dateSource = "release_time"
                    end if
                end if
            catch e
            end try

            ' Fallback to timestamp
            if not dateSet
                try
                    if isValid(curItem.timestamp)
                        if curItem.timestamp > 0
                            m.time.FromSeconds(curItem.timestamp)
                            dateSet = true
                            dateSource = "timestamp"
                        end if
                    end if
                catch e
                end try
            end if

            ' Last resort: creation_timestamp
            if not dateSet
                try
                    if isValid(curItem.meta) and isValid(curItem.meta.creation_timestamp)
                        if curItem.meta.creation_timestamp > 0
                            m.time.FromSeconds(curItem.meta.creation_timestamp)
                        end if
                    end if
                catch e
                end try
            end if
            timestr = m.time.AsDateString("short-month-short-weekday") + " "
            timestr = timestr.Trim()
            item.ReleaseDate = timestr
            item.guid = curItem.claim_id
            try
                thumbnail = m.top.constants["IMAGE_PROCESSOR"] + curItem.value.thumbnail.url
            catch e
                thumbnail = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
            end try
            item.HDPosterURL = thumbnail
            'all set on watching video due to https://QUERY_API/api/v1/proxy?m=get
            item.url = curItem.permanent_url.Trim() 'to be used to resolve with m?=get
            item.source = "odysee"
            item.itemType = "video"
            return item
        else
            return {} 'item not mp4, invalid!
        end if
    catch e
        return {} 'item has NO source/subitem missing!
    end try
end function

function getVideoPage(pageNum)
    m.time = CreateObject("roDateTime")
    m.time.Mark()
    curTime = m.time.AsSeconds()
    queryBase = invalid
    if isValid(m.top.constants) and isValid(m.top.constants["QUERY_API"])
        queryBase = m.top.constants["QUERY_API"]
    end if
    if not isValid(queryBase) or queryBase = ""
        print "[parseLib] getVideoPage: QUERY_API missing"
        return { items: [], releaseTime: invalid }
    end if
    queryURL = queryBase + "/api/v1/proxy?m=claim_search"
    'orderBy support temporarily removed for this implementation
    rawChannels = []
    if isValid(m.top.channels)
        rawChannels.Append(m.top.channels)
    end if
    if rawChannels.Count() >= 2048
        'would normally split into blocks, but iscroll requires that I rewrite this entirely.
        rawChannels.Reverse()
        channels = []
        numChannels = 0
        for each channel in rawChannels
            if numChannels = 2048 'get most recent 2048
                exit for
            end if
            channels.Push(channel)
            numChannels+=1
        end for
    else
        channels = m.top.channels
    end if
    rawChannels = invalid

    params = { "channel_ids": channels, "fee_amount": "<=0", "claim_type": ["stream"], "stream_types": ["video"], "has_source": true, "page": pageNum, "page_size": 36, "no_totals": true, "order_by": ["release_time"], "release_time": "<"+curTime.toStr() }

    ' For FAVORITES: no per-channel limit and filter to last 6 months
    ' For other categories: limit to 5 per channel to show variety
    if IsValid(m.top.rawname) and LCase(m.top.rawname) = "favorites"
        ' No limit_claims_per_channel for Favorites
        ' Filter to videos from last 6 months
        sixMonthsAgo = curTime - (6 * 30 * 24 * 60 * 60)
        params["release_time"] = ">"+sixMonthsAgo.toStr()
    else
        params["limit_claims_per_channel"] = 5
        params["remove_duplicates"] = true
    end if

    ' Wild West: use trending order instead of release_time
    if IsValid(m.top.rawname)
        if LCase(m.top.rawname) = "wildwest"
            params["order_by"] = ["trending_group", "trending_mixed"]
        end if
    end if
    ' Apply wildwest excludedChannelIds via not_channel_ids if provided on task
    ' Apply user blocked to all claim searches, and merge with category-level
    ' exclusions (e.g., Wild West) when provided.
    notIdsMap = {}
    ' user blocked
    if IsValid(m.top.blocked)
        if Type(m.top.blocked) = "roArray" or Type(m.top.blocked) = "Array"
            for each bid in m.top.blocked
                if IsValid(bid) then notIdsMap.addReplace(bid, true)
            end for
        end if
    end if
    ' category excluded
    if IsValid(m.top.excluded)
        if Type(m.top.excluded) = "roArray" or Type(m.top.excluded) = "Array"
            for each eid in m.top.excluded
                if IsValid(eid) then notIdsMap.addReplace(eid, true)
            end for
        end if
    end if
    if notIdsMap.Keys().Count() > 0
        params["not_channel_ids"] = notIdsMap.Keys()
    end if
    queryJSON = { "jsonrpc": "2.0", "method": "claim_search", "params": params, "id": m.top.uid }
    query = FormatJson(queryJSON)
    response = postJSON(query, queryURL, invalid)
    retries = 0
    while true
        try
            return { items: response.result.items, releaseTime: curTime }
        catch e
            response = postJSON(query, queryURL, invalid)
            retries += 1
        end try
        if retries > 5
            m.top.error = true
            return false
        end if
    end while
end function

function getvideoLength(length)
    m.timeConverter.FromSeconds(length)
    days = m.timeConverter.GetDayOfMonth().ToStr()
    hours = m.timeConverter.GetHours().ToStr()
    minutes = m.timeConverter.GetMinutes().ToStr()
    seconds = m.timeConverter.GetSeconds().ToStr()
    result = ""
    if m.timeConverter.GetDayOfMonth() < 10
      days = "0" + m.timeConverter.GetDayOfMonth().ToStr()
    end if
    if m.timeConverter.GetHours() < 10
      hours = "0" + m.timeConverter.GetHours().ToStr()
    end if
    if m.timeConverter.GetMinutes() < 10
      minutes = "0" + m.timeConverter.GetMinutes().ToStr()
    end if
    if m.timeConverter.GetSeconds() < 10
      seconds = "0" + m.timeConverter.GetSeconds().ToStr()
    end if
    if length < 3600
      'use minute format
      result = minutes + ":" + seconds
    end if
    if length >= 3600 and length < 86400
      result = hours + ":" + minutes + ":" + seconds
    end if
    if length >= 86400 'TODO: make videos above month length display proper length
      result = days + ":" + hours + ":" + minutes + ":" + seconds
    end if
    days = invalid
    hours = invalid
    minutes = invalid
    seconds = invalid
    return result
  end function
