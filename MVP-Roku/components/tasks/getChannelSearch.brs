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
    queryURL = m.top.constants["LIGHTHOUSE_API"]
    queryRAW = { s: m.top.search, size: "48", from: "0", "claimType": "channel", nsfw: "false", free_only: "true" }
    ? "[Search:Channel] Lighthouse request:" + FormatJson(queryRAW)
    claimIds = []
    failcount = 0
    m.errorType = "noResults"
    while true
        queryResult = getURLEncoded(queryRAW, queryURL, [])
        if type(queryResult) = "roArray" OR type(queryResult) = "Array"
            if queryResult.Count() > 0
                ? "[Search:Channel] Lighthouse results: " + Str(queryResult.Count())
                exit while
            else
                failcount += 1
                if failcount > 5
                    m.errorType = "noResults"
                    exit while
                end if
            end if
        else
            failcount += 1
            if failcount > 5
                m.errorType = "lighthouseError"
                exit while
            end if
        end if
    end while
    if type(queryResult) = "roArray" OR type(queryResult) = "Array"
        if queryResult.Count() > 0
            ? "[Search:Channel] Lighthouse results:" + Str(queryResult.Count())
            ?"valid"
            return ClaimsToChannelGrid(queryResult)
        else
            ?"no results"
            return { result: {}, success: false, errortype: m.errorType }
        end if
    else
        ?"no results"
        return { result: {}, success: false, errortype: m.errorType }
    end if
end function

function ClaimsToChannelGrid(claims)
    'passthrough until we rework parsing for this
    urlList = []
    channelList = []
    validChannels = []
    subCountsAA = {}
    for each claim in claims
        urlList.push("lbry://" + claim.name + "#" + claim.claimId)
        channelList.push(claim.claimId)
    end for
    queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
    queryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": 48, "claim_type": ["channel"], "no_totals": true, "any_tags": [], "not_tags": ["porn", "porno", "nsfw", "mature", "xxx", "sex", "creampie", "blowjob", "handjob", "boobs", "big boobs", "big dick", "pussy", "cumshot", "anal", "hard fucking", "ass", "fuck", "hentai"], "claim_ids": channelList, "not_channel_ids": [], "order_by": ["trending_group", "trending_mixed"] }, "id": m.top.uid })
    cresponse = postJSON(queryJSON, queryURL, invalid)
    ' Follower counts are optional; skip gracefully if unauthenticated
    if isValid(m.top.accessToken) AND m.top.accessToken <> ""
        subCountsURL = m.top.constants["ROOT_API"] + "/subscription/sub_count?claim_id=" + channelList.Join(",")
        baseHeaders = { "Authorization": "Bearer " + m.top.accessToken }
        subCountsRawData = getRawTextAuthenticated(subCountsURL, baseHeaders).replace(Chr(10), "").replace(" ", "")
        if InStr(1, subCountsRawData, "[") > 0 and InStr(1, subCountsRawData, "]") > 0
            subCountsData = subCountsRawData.split("[")[1].split("]")[0].split(",")
            for i = 0 to channelList.Count()-1
                numFollowers = 0
                if i < subCountsData.Count() then numFollowers = Val(subCountsData[i])
                if numFollowers = 1
                    followers = Left(numFollowers.ToStr(), 3)+" Follower"
                else if numFollowers >= 0 AND numFollowers < 999
                    followers = Left(numFollowers.ToStr(), 3)+" Followers"
                else if numFollowers >= 1000 AND numFollowers < 999999
                    followers = Left((numFollowers/1000).ToStr(), 3)+"K Followers"
                else if numFollowers >= 1000000 AND numFollowers < 999999999
                    followers = Left((numFollowers/1000000).ToStr(), 3)+"M Followers"
                else if numFollowers >= 1000000000 AND numFollowers < 999999999999
                    followers = Left((numFollowers/1000000000).ToStr(), 3)+"B Followers"
                else if numFollowers >= 1000000000000 AND numFollowers < 999999999999
                    followers = Left((numFollowers/1000000000000).ToStr(), 3)+"T Followers"
                else
                    followers = "Followers"
                end if 
                subCountsAA.addReplace(channelList[i], followers)
            end for
        end if
    else if isValid(m.top.authToken) AND m.top.authToken <> ""
        subCountsURL = m.top.constants["ROOT_API"] + "/subscription/sub_count?auth_token=" + m.top.authToken + "&claim_id=" + channelList.Join(",")
        baseHeaders = {}
        subCountsRawData = getRawTextAuthenticated(subCountsURL, baseHeaders).replace(Chr(10), "").replace(" ", "")
        if InStr(1, subCountsRawData, "[") > 0 and InStr(1, subCountsRawData, "]") > 0
            subCountsData = subCountsRawData.split("[")[1].split("]")[0].split(",")
            for i = 0 to channelList.Count()-1
                numFollowers = 0
                if i < subCountsData.Count() then numFollowers = Val(subCountsData[i])
                if numFollowers = 1
                    followers = Left(numFollowers.ToStr(), 3)+" Follower"
                else if numFollowers >= 0 AND numFollowers < 999
                    followers = Left(numFollowers.ToStr(), 3)+" Followers"
                else if numFollowers >= 1000 AND numFollowers < 999999
                    followers = Left((numFollowers/1000).ToStr(), 3)+"K Followers"
                else if numFollowers >= 1000000 AND numFollowers < 999999999
                    followers = Left((numFollowers/1000000).ToStr(), 3)+"M Followers"
                else if numFollowers >= 1000000000 AND numFollowers < 999999999999
                    followers = Left((numFollowers/1000000000).ToStr(), 3)+"B Followers"
                else if numFollowers >= 1000000000000 AND numFollowers < 999999999999
                    followers = Left((numFollowers/1000000000000).ToStr(), 3)+"T Followers"
                else
                    followers = "Followers"
                end if 
                subCountsAA.addReplace(channelList[i], followers)
            end for
        end if
    else
        for i = 0 to channelList.Count()-1
            subCountsAA.addReplace(channelList[i], "Followers")
        end for
    end if
    ' ?cresponse
    retries = 0
    while true
        if IsValid(cresponse.error)
            cresponse = postJSON(queryJSON, queryURL, invalid)
            retries += 1
        else
            exit while
        end if
        if retries > 5
            cresponse = false
            exit while
        end if
    end while
    if Type(cresponse) = "roAssociativeArray"
        if isValid(cresponse.result) and isValid(cresponse.result.items) and cresponse.result.items.Count() >= 1
            for each channel in cresponse.result.items
                ' For channel claims, the claim itself is the channel; do not expect signing_channel
                if isValid(channel) and isValid(channel.claim_id)
                    validChannels.push(channel)
                end if
            end for
        end if
    else
        return { result: {}, success: false }
    end if
    if validChannels.Count() >= 1
        result = []
        counter = 0
        i = 0
        content = createObject("RoSGNode", "ContentNode")
        for each channel in validChannels
            item = {}
            try
                item.Title = channel.value.title
            catch e
                item.Title = channel.name
            end try
            item.Creator = ""
            item.Description = ""
            item.Channel = channel.claim_id
            item.guid = channel.claim_id
            if isValid(subCountsAA[channel.claim_id])
                item.Followers = subCountsAA[channel.claim_id]
            end if
            try
                thumbnail = m.top.constants["IMAGE_PROCESSOR"] + channel.value.thumbnail.url
            catch e
                thumbnail = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
            end try
            item.HDPosterURL = thumbnail
            item.thumbnailDimensions = [360, 240]
            'all set on watching video due to https://QUERY_API/api/v1/proxy?m=get
            item.url = channel.permanent_url.Trim() 'to be used to resolve with m?=get
            item.source = "odysee"
            item.itemType = "channel"
            'Create content (content -> row -> item)
            if counter < 4
                if IsValid(currow) <> true
                    currow = createObject("RoSGNode", "ContentNode")
                end if
                curitem = createObject("RoSGNode", "ContentNode")
                curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", Channel: "", Followers: "0 Followers" })
                curitem.setFields(item)
                currow.appendChild(curitem)
                if i = validChannels.Count() - 1 'misalignment fix, will need to implement this better later.
                    content.appendChild(currow)
                end if
                counter += 1
                curitem = invalid
            else
                content.appendChild(currow)
                currow = invalid
                currow = createObject("RoSGNode", "ContentNode")
                curitem = createObject("RoSGNode", "ContentNode")
                curitem.addFields({ creator: "", thumbnailDimensions: [], itemType: "", Channel: "", Followers: "0 Followers" })
                curitem.setFields(item)
                currow.appendChild(curitem)
                counter = 1
                curitem = invalid
            end if
            result.push(item) 'Unparsed "XMLContent", can be used to cache results later.
            item = invalid
            i += 1
        end for
        ?"exported" + Str(content.getChildCount() * 4) + " channels from Odysee (Channel Search)"
        return { contentarray: result: content: content: success: true }
    else
        return { result: {}, success: false }
    end if
end function