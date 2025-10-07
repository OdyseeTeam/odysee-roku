sub Init()
    m.top.functionName = "master"
end sub

sub master()
    if m.top.mode = "recent_active"
        m.top.output = FetchRecentlyActive()
    else if m.top.mode = "all"
        m.top.output = FetchAllChannels()
    end if
end sub

function FetchRecentlyActive()
    ' Fetch recently active channels - first get channel metadata, then get latest video per channel
    if not IsValid(m.top.constants) or not IsValid(m.top.channels)
        print "[getFollowedChannels] FetchRecentlyActive: constants or channels invalid"
        return {"channels": []}
    end if

    print "[getFollowedChannels] FetchRecentlyActive: Starting with "; m.top.channels.Count(); " channels"

    ' Step 1: Use claim_search to find most recently active channels (limit 1 video per channel)
    queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"

    params = {
        "claim_type": ["stream"],
        "stream_types": ["video"],
        "has_source": true,
        "page": 1,
        "page_size": 8,
        "limit_claims_per_channel": 1,
        "no_totals": true,
        "order_by": ["release_time"],
        "channel_ids": m.top.channels
    }

    q = FormatJson({"jsonrpc": "2.0", "method": "claim_search", "params": params, "id": m.top.uid})
    resp = postJSON(q, queryURL, invalid)

    print "[getFollowedChannels] FetchRecentlyActive: API response received"

    channels = []
    if IsValid(resp) and IsValid(resp.result) and IsValid(resp.result.items)
        print "[getFollowedChannels] FetchRecentlyActive: Found "; resp.result.items.Count(); " items"
        for each cl in resp.result.items
            if IsValid(cl.signing_channel)
                channelInfo = {
                    "channelId": cl.signing_channel.claim_id,
                    "channelName": cl.signing_channel.name,
                    "channelTitle": cl.signing_channel.value.title,
                    "channelThumb": "",
                    "videoCount": "",
                    "lastVideoTitle": cl.value.title,
                    "lastVideoDate": cl.value.release_time
                }

                ' Get channel thumbnail
                if IsValid(cl.signing_channel.value) and IsValid(cl.signing_channel.value.thumbnail)
                    if IsValid(cl.signing_channel.value.thumbnail.url)
                        channelInfo.channelThumb = cl.signing_channel.value.thumbnail.url
                    end if
                end if

                ' Get video count from signing_channel meta
                if IsValid(cl.signing_channel.meta) and IsValid(cl.signing_channel.meta.claims_in_channel)
                    channelInfo.videoCount = Str(cl.signing_channel.meta.claims_in_channel) + " uploads"
                end if

                channels.push(channelInfo)
            end if
        end for
    else
        print "[getFollowedChannels] FetchRecentlyActive: Invalid response or no items"
    end if

    print "[getFollowedChannels] FetchRecentlyActive: Returning "; channels.Count(); " channels"
    return {"channels": channels}
end function

function FetchAllChannels()
    ' Fetch all followed channels with pagination (10 per page)
    ' Use resolve API to get channel metadata directly
    if not IsValid(m.top.constants) or not IsValid(m.top.channels)
        return {"channels": [], "hasMore": false}
    end if

    pageNum = m.top.page
    if not IsValid(pageNum) or pageNum < 1 then pageNum = 1

    ' On first page, fetch ALL channels and cache them sorted
    if pageNum = 1 or not IsValid(m.sortedChannelCache)
        allChannels = m.top.channels
        if not IsValid(allChannels) then return {"channels": [], "hasMore": false}

        ' Build lbry:// URLs for ALL channels
        urls = []
        for each channelId in allChannels
            urls.push("lbry://@" + channelId + "#" + channelId)
        end for

        ' Use resolve API to get channel metadata
        queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=resolve"
        params = {"urls": urls}
        q = FormatJson({"jsonrpc": "2.0", "method": "resolve", "params": params, "id": m.top.uid})
        resp = postJSON(q, queryURL, invalid)

        allChannelInfo = []
        if IsValid(resp) and IsValid(resp.result)
            for each url in urls
                if IsValid(resp.result[url])
                    ch = resp.result[url]
                    if IsValid(ch.claim_id)
                        channelInfo = {
                            "channelId": ch.claim_id,
                            "channelName": ch.name,
                            "channelTitle": "",
                            "channelThumb": "",
                            "videoCount": "",
                            "description": ""
                        }

                        ' Get channel title
                        if IsValid(ch.value) and IsValid(ch.value.title)
                            channelInfo.channelTitle = ch.value.title
                        else
                            channelInfo.channelTitle = ch.name
                        end if

                        ' Get channel thumbnail
                        if IsValid(ch.value) and IsValid(ch.value.thumbnail)
                            if IsValid(ch.value.thumbnail.url)
                                channelInfo.channelThumb = ch.value.thumbnail.url
                            end if
                        end if

                        ' Get video count from meta
                        if IsValid(ch.meta) and IsValid(ch.meta.claims_in_channel)
                            channelInfo.videoCount = Str(ch.meta.claims_in_channel) + " uploads"
                        end if

                        allChannelInfo.push(channelInfo)
                    end if
                end if
            end for
        end if

        ' Sort by channel title (case-insensitive)
        for i = 0 to allChannelInfo.Count() - 1
            for j = i + 1 to allChannelInfo.Count() - 1
                if LCase(allChannelInfo[i].channelTitle) > LCase(allChannelInfo[j].channelTitle)
                    temp = allChannelInfo[i]
                    allChannelInfo[i] = allChannelInfo[j]
                    allChannelInfo[j] = temp
                end if
            end for
        end for

        ' Cache sorted channels
        m.sortedChannelCache = allChannelInfo
    end if

    ' Paginate from cache
    pageSize = 10
    startIndex = (pageNum - 1) * pageSize
    endIndex = startIndex + pageSize - 1
    totalChannels = m.sortedChannelCache.Count()

    if startIndex >= totalChannels then return {"channels": [], "hasMore": false}

    channels = []
    for i = startIndex to endIndex
        if i < totalChannels
            channels.push(m.sortedChannelCache[i])
        end if
    end for

    hasMore = (endIndex + 1) < totalChannels

    return {"channels": channels, "hasMore": hasMore}
end function
