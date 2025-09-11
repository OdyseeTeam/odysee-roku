sub Init()
    m.top.functionName = "master"
end sub

sub master()
    m.top.output = FetchNext()
end sub

function FetchNext() as object
    queryURL = m.top.constants["LIGHTHOUSE_API"]
    ' Continue Lighthouse paging; larger page for better fill
    ' Defensive: ensure search term is preserved as string
    qstr = ""
    try
        if IsValid(m.top.search) then
            qstr = m.top.search.ToStr()
        end if
    catch e
    end try
    queryRAW = { s: qstr, size: "48", from: m.top.from.toStr(), claimType: "file", nsfw: "false", free_only: "true" }
    ? "[Search:Video:Next] Lighthouse request:" + FormatJson(queryRAW)
    queryResult = getURLEncoded(queryRAW, queryURL, [])
    if type(queryResult) = "roArray" or type(queryResult) = "Array"
        ? "[Search:Video:Next] Lighthouse results:" + Str(queryResult.Count())
    else
        ? "[Search:Video:Next] Lighthouse returned non-array"
    end if
    claimIds = []
    if type(queryResult) = "roArray" or type(queryResult) = "Array"
        for each claim in queryResult
            claimIds.push(claim.claimId)
        end for
    end if
    if claimIds.Count() = 0
        ' Return a single placeholder row to keep scrollable layout consistent
        pc = createObject("RoSGNode","ContentNode")
        prow = createObject("RoSGNode","ContentNode")
        for i = 1 to 4
            p = createObject("RoSGNode","ContentNode")
            p.addFields({ itemType: "placeholder" })
            prow.appendChild(p)
        end for
        pc.appendChild(prow)
        return { content: pc }
    end if
    ' Claim search for details
    date = CreateObject("roDateTime"): date.Mark(): curTime = date.AsSeconds()
    csURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
    queryJSON = { "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": 48, "fee_amount": "<=0", "claim_type": ["stream"], "stream_types": ["video"], "no_totals": true, "claim_ids": claimIds, "order_by": ["release_time"], "release_time": "<" + curTime.toStr(), "has_source": true }, "id": m.top.uid }
    q = FormatJson(queryJSON)
    ? "[Search:Video:Next] claim_ids count=" + Str(claimIds.Count())
    resp = postJSON(q, csURL, invalid)
    items = []
    try
        if IsValid(resp.result.items)
            for each it in resp.result.items
                pv = parseVideo(it)
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
            n.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", rawCreator: "", videoLength: "" })
            n.setFields(it)
            currow.appendChild(n)
            counter += 1
        else
            content.appendChild(currow)
            currow = createObject("RoSGNode","ContentNode")
            n = createObject("RoSGNode","ContentNode")
            n.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", rawCreator: "", videoLength: "" })
            n.setFields(it)
            currow.appendChild(n)
            counter = 1
        end if
    end for
    if IsValid(currow) and currow.getChildCount() > 0
        content.appendChild(currow)
    end if
    return { content: content }
end function


