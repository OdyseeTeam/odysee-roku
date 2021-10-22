Sub Init()
    m.top.functionName = "master"
End Sub

sub master()
    '? m.top.constants
    '? m.top.cookies
    '? m.top.uid
    '? m.top.authtoken
    '? m.top.channels
    '? m.top.rawname
    m.top.output = getLighthouseResult(m.top.search)
End Sub
Function getLighthouseResult(search)
    queryURL = m.top.constants["LIGHTHOUSE_API"]
    queryRAW = {s: m.top.search, size: "50", from: "0", "claimType": "file", nsfw: "false", free_only: "true"}
    queryResult = getURLEncoded(queryRAW, queryURL, [])
    claimIds = []
    if type(queryResult) = "roArray"
        if queryResult.Count() > 0
            ? "valid"
            for each claim in queryResult
                claimIds.push(claim.claimId)
            end for
            return {result: ClaimsToVideoGrid(claimIds), success: true}
        else
            ? "no results"
            return {result: {}, success: false}
        end if
    else
        ? "no results"
        return {result: {}, success: false}
    end if
End Function

Function ClaimsToVideoGrid(claims)
    queryOutput = "placeholder"
    date = CreateObject("roDateTime")
    max = 48
    queryURL = m.top.constants["QUERY_API"]+"/api/v1/proxy?m=claim_search"
    queryJSON = FormatJson({"jsonrpc":"2.0","method":"claim_search","params":{"page_size":max,"claim_type":"stream","media_types":["video/mp4"],"no_totals":true,"any_tags":[],"not_tags":["porn","porno","nsfw","mature","xxx","sex","creampie","blowjob","handjob","vagina","boobs","big boobs","big dick","pussy","cumshot","anal","hard fucking","ass","fuck","hentai"],"claim_ids":claims,"not_channel_ids":[],"order_by":["release_time"],"has_no_source":false,"include_purchase_receipt":false, "has_channel_signature":true,"valid_channel_signature":true, "has_source": true}})
    response = postJSON(queryJSON, queryURL, invalid)
    retries = 0
    while true
        if IsValid(response.error)
            response = postJSON(queryJSON, queryURL, invalid)
            retries+=1
        else
            exit while
        end if
        if retries > 5
            return false
        end if
    end while
    items = response.result.items
    mediaindex={}
    result=[]
    counter=0
    content=createObject("RoSGNode","ContentNode")
    ? "got "+str(items.Count())+" items from Odysee (Video Search)"
    For i=0 To items.Count()-1 Step 1 'Parse response
        item = {}
        item.Title = items[i].value.title
        item.Creator = items[i].signing_channel.name
        item.Description = ""
        item.Channel = items[i].signing_channel.claim_id
        item.lbc = items[i].meta.effective_amount+" LBC"
        time = CreateObject("roDateTime")
        try
            time.FromSeconds(items[i].meta.creation_timestamp)
        catch e
            time.FromSeconds(items[i].timestamp)
        end try
        timestr = time.AsDateString("short-month-short-weekday")+" "
        timestr = timestr.Trim()
        time = Invalid
        item.ReleaseDate = timestr
        item.guid = items[i].claim_id
        try
            thumbnail = items[i].value.thumbnail.url
        catch e
            thumbnail = "pkg:/images/frontpage/bad_icon_requires_usage_rights.png"
        end try
        item.HDPosterURL = thumbnail
        item.thumbnailDimensions = [360, 240]
        'all set on watching video due to https://QUERY_API/api/v1/proxy?m=get
        item.url = items[i].permanent_url.Trim() 'to be used to resolve with m?=get
        'item.stream = {url : item.url}
        'item.link = item.url
        'item.streamFormat = ""
        item.source = "odysee"
        item.itemType = "video"
        'Create content (content -> row -> item)
        if counter < 4
            if IsValid(currow) <> true
                currow = createObject("RoSGNode","ContentNode")
            end if
            curitem = createObject("RoSGNode","ContentNode")
            curitem.addFields({creator: "", thumbnailDimensions: [], itemType: "", lbc: "", Channel: ""})
            curitem.setFields(item)
            currow.appendChild(curitem)
            if i = items.Count()-1 'misalignment fix, will need to implement this better later.
                content.appendChild(currow)
            end if
            counter+=1
            curitem = invalid
        else
            content.appendChild(currow)
            currow = invalid
            currow = createObject("RoSGNode","ContentNode")
            curitem = createObject("RoSGNode","ContentNode")
            curitem.addFields({creator: "", thumbnailDimensions: [], itemType: "", lbc: "", Channel: ""})
            curitem.setFields(item)
            currow.appendChild(curitem)
            counter = 1
            curitem = invalid
        end if
        result.push(item) 'Unparsed "XMLContent", can be used to cache results later.
        mediaindex[item.guid] = item
        item = invalid
    end for
    '? type(content)
    ? "exported"+Str(content.getChildCount()*4)+" items from Odysee (Video Search)"

    '? "manufacturing finished for key: "+subkey
    return  {contentarray:result:index:mediaindex:content:content} 'Returns the array
End Function