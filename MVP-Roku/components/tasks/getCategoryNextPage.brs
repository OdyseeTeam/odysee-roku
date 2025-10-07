sub Init()
    m.top.functionName = "master"
end sub

sub master()
    m.top.output = FetchNextPage(m.top.page)
    ' Echo rawname back so caller can clear the in-flight flag deterministically
    m.top.output.rawname = m.top.rawname
end sub

function FetchNextPage(pageNum as integer)
    ' reuse parseLib.getVideoPage style but with explicit page
    m.time = CreateObject("roDateTime")
    m.time.Mark()
    curTime = m.time.AsSeconds()
    queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"

    params = { "fee_amount": "<=0", "claim_type": ["stream"], "stream_types": ["video"], "has_source": true, "page": pageNum, "page_size": 48, "no_totals": true, "order_by": ["release_time"], "release_time": "<"+curTime.toStr() }

    ' For FAVORITES: no per-channel limit and filter to last 6 months
    ' For other categories: limit to 2 per channel to show variety
    if IsValid(m.top.rawname) and UCase(m.top.rawname) = "FAVORITES"
        ' No limit_claims_per_channel for Favorites
        ' Filter to videos from last 6 months
        sixMonthsAgo = curTime - (6 * 30 * 24 * 60 * 60)
        params["release_time"] = ">"+sixMonthsAgo.toStr()
    else
        params["limit_claims_per_channel"] = 2
    end if
    ' Only include channel_ids when provided (e.g., most categories). Wild West intentionally omits this.
    if IsValid(m.top.channels)
        if Type(m.top.channels) = "roArray" or Type(m.top.channels) = "Array"
            if m.top.channels.Count() > 0
                params["channel_ids"] = m.top.channels
            end if
        end if
    end if
    if IsValid(m.top.rawname)
        if LCase(m.top.rawname) = "wildwest"
            params["order_by"] = ["trending_group","trending_mixed"]
        end if
    end if
    ' Merge exclusions: user blocked + category excluded
    notIdsMap = {}
    if IsValid(m.top.blocked) and (Type(m.top.blocked) = "roArray" or Type(m.top.blocked) = "Array")
        for each bid in m.top.blocked
            if IsValid(bid)
                notIdsMap.addReplace(bid, true)
            end if
        end for
    end if
    if IsValid(m.top.excluded) and (Type(m.top.excluded) = "roArray" or Type(m.top.excluded) = "Array")
        for each eid in m.top.excluded
            if IsValid(eid)
                notIdsMap.addReplace(eid, true)
            end if
        end for
    end if
    if notIdsMap.Keys().Count() > 0
        params["not_channel_ids"] = notIdsMap.Keys()
    end if
    ' Debug context: counts and release cutoff
    chCount = 0
    if IsValid(params["channel_ids"])
        if Type(params["channel_ids"]) = "roArray" or Type(params["channel_ids"]) = "Array"
            chCount = params["channel_ids"].Count()
        end if
    end if
    ? "[CatNext] limit=" + Str(limitClaims) + " channels=" + Str(chCount) + " release<" + curTime.ToStr()
    q = FormatJson({"jsonrpc":"2.0","method":"claim_search","params":params,"id":m.top.uid})
    ' Defensive: if channel_ids provided but empty, remove to avoid server-side filtering to zero
    if IsValid(params["channel_ids"]) and (Type(params["channel_ids"]) = "roArray" or Type(params["channel_ids"]) = "Array")
        if params["channel_ids"].Count() = 0
            params.delete("channel_ids")
            q = FormatJson({"jsonrpc":"2.0","method":"claim_search","params":params,"id":m.top.uid})
        end if
    end if
    ? "[CatNext] claim_search page=" + pageNum.ToStr() + " rawname=" + m.top.rawname
    resp = postJSON(q, queryURL, invalid)
    if not IsValid(resp) or not IsValid(resp.result)
        ? "[CatNext] no result from claim_search"
    end if
    items = []
    try
        if IsValid(resp) and IsValid(resp.result) and IsValid(resp.result.items)
            ? "[CatNext] resp.items=" + Str(resp.result.items.Count())
            for each cl in resp.result.items
                pv = parseVideo(cl)
                if pv.Count() > 0 then items.push(pv)
            end for
        else
            ? "[CatNext] items missing in response"
        end if
    catch e
        ? "[CatNext] parse error"
    end try
    ' build content rows
    content = createObject("RoSGNode","ContentNode")
    ? "[CatNext] items parsed=" + Str(items.Count())
    counter = 0: currow = invalid
    for each it in items
        if counter < 4
            if IsValid(currow) <> true then currow = createObject("RoSGNode","ContentNode")
            n = createObject("RoSGNode","ContentNode")
            n.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", reposted: false, repostedBy: "", rawCreator: "", videoLength: "" })
            n.setFields(it)
            currow.appendChild(n)
            counter += 1
        else
            content.appendChild(currow)
            currow = createObject("RoSGNode","ContentNode")
            n = createObject("RoSGNode","ContentNode")
            n.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", reposted: false, repostedBy: "", rawCreator: "", videoLength: "" })
            n.setFields(it)
            currow.appendChild(n)
            counter = 1
        end if
    end for
    if IsValid(currow) and currow.getChildCount() > 0 then content.appendChild(currow)
    ? "[CatNext] rows=" + Str(content.getChildCount()) + " tiles=" + Str(items.Count())
    return { content: content, items: items }
end function


