sub Init()
    m.top.functionName = "master"
end sub

sub master()
    m.top.output = FetchChannelNextPage(m.top.page)
end sub

function FetchChannelNextPage(pageNum as integer)
    date = CreateObject("roDateTime")
    date.Mark()
    curTime = date.AsSeconds()
    queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
    params = { "page": pageNum, "page_size": 48, "fee_amount": "<=0", "claim_type": ["stream"], "has_source": true, "stream_types": ["video"], "no_totals": true, "channel_ids": [m.top.channel], "order_by": ["release_time"], "release_time": "<" + curTime.toStr() }
    q = FormatJson({"jsonrpc":"2.0","method":"claim_search","params":params,"id":m.top.uid})
    resp = postJSON(q, queryURL, invalid)
    items = []
    try
        if IsValid(resp.result.items)
            for each cl in resp.result.items
                pv = parseVideo(cl)
                if pv.Count() > 0 then items.push(pv)
            end for
        end if
    catch e
    end try
    content = createObject("RoSGNode","ContentNode")
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
    return { content: content }
end function


