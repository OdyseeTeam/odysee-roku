function parseVideo(itemIn)
    'check repost/item has source
    'check repost/item source has valid media_type
    'TODO: replace all isValid checks with try/catch
    item = {}
    m.timeConverter = CreateObject("roDateTime")
    m.time = CreateObject("roDateTime")
    'Find out if item is repost
    if isValid(itemIn.reposted_claim)
        curItem = itemIn.reposted_claim
        item.reposted = true
        try
            item.reposted_by = itemIn.signing_channel.value.title
        catch e
            try
                item.reposted_by = itemIn.signing_channel.name
            catch e
                item.reposted_by = "Anonymous"
            end try
        end try
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
            if isValid(curItem["value"]["video"]["duration"])
                item.videoLength = getvideoLength(curItem["value"]["video"]["duration"])
            end if
            try
                item.ChannelIcon = m.top.constants["CHANNEL_ICON_PROCESSOR"] + curItem.signing_channel.value.thumbnail.url
            catch e
                item.ChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
            end try
            try
                try
                    m.time.FromSeconds(curItem["value"]["release_time"])
                catch e
                    m.time.FromSeconds(curItem.meta.creation_timestamp)
                end try
            catch e
                m.time.FromSeconds(curItem.timestamp)
            end try
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
    queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
    'orderBy support temporarily removed for this implementation
    queryJSON = { "jsonrpc": "2.0", "method": "claim_search", "params": { "channel_ids": m.top.channels, "fee_amount": "<=0", "claim_type": ["stream", "repost"], "page": pageNum, "page_size": 48, "no_totals": true, "order_by": ["release_time"],"release_time": "<"+curTime.toStr() }, "id": m.top.uid }
    query = FormatJson(queryJSON)
    response = postJSON(query, queryURL, invalid)
    retries = 0
    while true
        try
            return response.result.items
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