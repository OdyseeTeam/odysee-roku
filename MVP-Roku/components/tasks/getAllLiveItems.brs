sub Init()
    m.top.functionName = "master"
end sub

sub master()
    m.top.output = FetchAllLiveItems()
end sub

function FetchAllLiveItems()
    ' One-shot fetch of all live entries; no per-category calls
    try
        liveResp = getJSON(m.top.constants["NEW_LIVE_API"] + "/all")
        if IsValid(liveResp) = false or IsValid(liveResp.data) = false or liveResp.data.Count() = 0
            return { error: false, items: [], claims: [] }
        end if
        liveData = liveResp.data
        ' Build list of active claim IDs, map by ChannelClaimID and by ClaimID
        activeClaimIds = []
        byChannel = {}
        byClaim = {}
        for each item in liveData
            if IsValid(item.ActiveClaim) and IsValid(item.ActiveClaim.ClaimID)
                activeClaimIds.push(item.ActiveClaim.ClaimID)
                byChannel.addReplace(item.ChannelClaimID, item)
                byClaim.addReplace(item.ActiveClaim.ClaimID, item)
            end if
        end for
        if activeClaimIds.Count() = 0
            return { error: false, items: [], claims: [] }
        end if
        ' Single claim_search for all active claim IDs
        queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
        ' Batch claim_search in chunks of 50 to ensure we get all items
        claims = []
        chunkSize = 50
        startIndex = 0
        while startIndex < activeClaimIds.Count()
            endIndex = startIndex + chunkSize
            if endIndex > activeClaimIds.Count() then endIndex = activeClaimIds.Count()
            chunk = []
            for i = startIndex to endIndex - 1: chunk.push(activeClaimIds[i]): end for
            claimReq = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "fee_amount": "<=0", "claim_ids": chunk, "page": 1, "page_size": chunk.Count(), "no_totals": true }, "id": m.top.uid })
            claimResp = postJSON(claimReq, queryURL, invalid)
            if IsValid(claimResp) and IsValid(claimResp.result) and IsValid(claimResp.result.items)
                for each it in claimResp.result.items: claims.push(it): end for
            end if
            startIndex = endIndex
        end while
        return { error: false, items: liveData, claims: claims, byChannel: byChannel, byClaim: byClaim }
    catch e
        return { error: true }
    end try
end function


