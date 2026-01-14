sub Init()
    m.top.functionName = "master"
end sub

sub master()
    '?m.top.constants
    '?m.top.cookies
    '?m.top.uid
    '?m.top.authtoken
    '?m.top.channels
    '?m.top.rawname
    m.top.output = getLighthouseResult(m.top.search)
end sub
function getLighthouseResult(search)
    m.errorType = "noResults"
    queryURL = invalid
    if isValid(m.top.constants) and isValid(m.top.constants["LIGHTHOUSE_API"])
        queryURL = m.top.constants["LIGHTHOUSE_API"]
    end if
    if not isValid(queryURL) or queryURL = ""
        ?"lighthouse error: missing LIGHTHOUSE_API"
        return { result: {}, success: false, errortype: "lighthouseError" }
    end if
    ' Request a larger first page to reduce blanks and improve scroll runway
    queryRAW = { s: m.top.search, size: "48", from: "0", "claimType": "file", nsfw: "false", free_only: "true" }
    ? "[Search:Video] Lighthouse request:" + FormatJson(queryRAW)
    queryResult = getURLEncoded(queryRAW, queryURL, [])
    if type(queryResult) = "roArray" or type(queryResult) = "Array"
        ? "[Search:Video] Lighthouse results:" + Str(queryResult.Count())
    else
        ? "[Search:Video] Lighthouse returned non-array"
    end if
    claimIds = []
    if type(queryResult) = "roArray" or type(queryResult) = "Array"
        if queryResult.Count() > 0
            ?"valid"
            for each claim in queryResult
                if isValid(claim) and isValid(claim.claimId)
                    claimIds.push(claim.claimId)
                end if
            end for
            ? "lighthouse success"
            ? "[Search:Video] claim_ids count=" + Str(claimIds.Count())
            CVG = ClaimsToVideoGrid(claimIds)
            if CVG.error
                return { result: {}, success: false, errortype: CVG.errortype }
            else
                return { result: CVG, success: true }
            end if
        else
            ?"no results"
            return { result: {}, success: false, errortype: "noResults" }
        end if
    else
        ?"lighthouse error"
        return { result: {}, success: false, errortype: "lighthouseError" }
    end if
end function

function ClaimsToVideoGrid(claims)
    try
        if not isValid(claims) or (Type(claims) <> "roArray" and Type(claims) <> "Array")
            content = createObject("RoSGNode", "ContentNode")
            return { contentarray: [], content: content, error: false }
        end if
        queryOutput = "placeholder"
        date = CreateObject("roDateTime")
        date.Mark()
        curTime = date.AsSeconds()
        max = 48
        queryBase = invalid
        if isValid(m.top.constants) and isValid(m.top.constants["QUERY_API"])
            queryBase = m.top.constants["QUERY_API"]
        end if
        if not isValid(queryBase) or queryBase = ""
            content = createObject("RoSGNode", "ContentNode")
            return { contentarray: [], content: content, error: false }
        end if
        queryURL = queryBase + "/api/v1/proxy?m=claim_search"
        queryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": max, "fee_amount": "<=0", "claim_type": ["stream"], "stream_types": ["video"], "no_totals": true, "any_tags": [], "not_tags": ["porn", "porno", "nsfw", "mature", "xxx", "sex", "creampie", "blowjob", "handjob", "boobs", "big boobs", "big dick", "pussy", "cumshot", "anal", "hard fucking", "ass", "fuck", "hentai"], "claim_ids": claims, "not_channel_ids": [], "order_by": ["release_time"], "release_time": "<" + curTime.toStr(), "include_purchase_receipt": false, "has_channel_signature": true, "valid_channel_signature": true, "has_source": true }, "id": m.top.uid })
        response = postJSON(queryJSON, queryURL, invalid)
        retries = 0
        while true
            if (not isValid(response)) or (Type(response) <> "roAssociativeArray") then
                response = postJSON(queryJSON, queryURL, invalid)
                retries += 1
            else if IsValid(response.error)
                response = postJSON(queryJSON, queryURL, invalid)
                retries += 1
            else
                exit while
            end if
            if retries > 5
                m.errorType = "claimSearchError"
                return { error: true, errorType: "claimSearchError" }
            end if
        end while
        ' Safely extract items; response.result may be missing
        items = invalid
        if isValid(response) and Type(response) = "roAssociativeArray"
            res = response["result"]
            if isValid(res) and Type(res) = "roAssociativeArray"
                it = res["items"]
                if isValid(it) and (Type(it) = "roArray" or Type(it) = "Array")
                    items = it
                end if
            end if
        end if
        if not isValid(items) or (Type(items) <> "roArray" and Type(items) <> "Array") or items.Count() = 0
            content = createObject("RoSGNode", "ContentNode")
            return { contentarray: [], content: content, error: false }
        end if
        result = []
        counter = 0
        content = createObject("RoSGNode", "ContentNode")
        ?"got " + str(items.Count()) + " items from Odysee (Video Search)"
        currow = createObject("RoSGNode", "ContentNode")
        for each claim in items 'Parse response via parseLib (defensive)
            pv = parseVideo(claim)
            if pv.Count() > 0
                if counter < 4
                    curitem = createObject("RoSGNode", "ContentNode")
                    curitem.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", videoLength: "" })
                    curitem.setFields(pv)
                    currow.appendChild(curitem)
                    counter += 1
                else
                    if IsValid(currow)
                        content.appendChild(currow)
                    end if
                    currow = createObject("RoSGNode", "ContentNode")
                    curitem = createObject("RoSGNode", "ContentNode")
                    curitem.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", videoLength: "" })
                    curitem.setFields(pv)
                    currow.appendChild(curitem)
                    counter = 1
                end if
                result.push(pv)
            end if
            pv = invalid
        end for
        if IsValid(currow) and counter > 0 and currow.getChildCount() > 0
            content.appendChild(currow)
        end if
        return { contentarray: result: content: content: error: false } 'Returns the array
    catch e
        m.errorType = "parseError"
        return { error: true, errorType: "parseError" }
    end try
end function

