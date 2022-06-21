Sub Init()
    m.top.functionName = "master"
End Sub

sub master()
    '?m.top.constants
    '?m.top.cookies
    '?m.top.uid
    '?m.top.authtoken
    '?m.top.channels
    '?m.top.rawname
    m.top.output = getLighthouseResult(m.top.search)
End Sub
Function getLighthouseResult(search)
    queryURL = m.top.constants["LIGHTHOUSE_API"]
    queryRAW = {s: m.top.search, size: "50", from: "0", "claimType": "file", nsfw: "false", free_only: "true"}
    queryResult = getURLEncoded(queryRAW, queryURL, [])
    claimIds = []
    if type(queryResult) = "roArray"
        if queryResult.Count() > 0
            ?"valid"
            for each claim in queryResult
                claimIds.push(claim.claimId)
            end for
            return {result: ClaimsToVideoGrid(claimIds), success: true}
        else
            ?"no results"
            return {result: {}, success: false}
        end if
    else
        ?"no results"
        return {result: {}, success: false}
    end if
End Function

Function ClaimsToVideoGrid(claims)
    queryOutput = "placeholder"
    date = CreateObject("roDateTime")
    date.Mark()
    curTime = date.AsSeconds()
    max = 48
    queryURL = m.top.constants["QUERY_API"]+"/api/v1/proxy?m=claim_search"
    queryJSON = FormatJson({"jsonrpc":"2.0","method":"claim_search","params":{"page_size":max,"claim_type":"stream","stream_types": ["video"],"no_totals":true,"any_tags":[],"not_tags":["porn","porno","nsfw","mature","xxx","sex","creampie","blowjob","handjob","vagina","boobs","big boobs","big dick","pussy","cumshot","anal","hard fucking","ass","fuck","hentai"],"claim_ids":claims,"not_channel_ids":[],"order_by":["release_time"],"release_time": "<"+curTime.toStr(),"has_no_source":false,"include_purchase_receipt":false, "has_channel_signature":true,"valid_channel_signature":true, "has_source": true}})
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
    result=[]
    counter=0
    content=createObject("RoSGNode","ContentNode")
    ?"got "+str(items.Count())+" items from Odysee (Video Search)"
    For i=0 To items.Count()-1 Step 1 'Parse response
        item = {}
        item.Title = items[i].value.title
        try
            item.Creator = items[i].signing_channel.value.title
        catch e
            item.Creator = items[i].signing_channel.name
        end try
        if isValid(items[i]["value"]["video"]["duration"])
            item.videoLength = getvideoLength(items[i]["value"]["video"]["duration"])
        end if
        item.Description = ""
        item.Channel = items[i].signing_channel.claim_id
        try
            if isValid(items[i].signing_channel.value.thumbnail.url)
                item.ChannelIcon = m.top.constants["IMAGE_PROCESSOR"] + items[i].signing_channel.value.thumbnail.url
            else
                item.ChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
            end if
        catch e
            item.ChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
        end try
        time = CreateObject("roDateTime")
        try
            try
                time.FromSeconds(items[i]["value"]["release_time"])
            catch e
                time.FromSeconds(items[i].meta.creation_timestamp)
            end try
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
            thumbnail = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
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
            curitem.addFields({creator: "", thumbnailDimensions: [], itemType: "", Channel: "", ChannelIcon: "", videoLength: "" })
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
            curitem.addFields({creator: "", thumbnailDimensions: [], itemType: "", Channel: "", ChannelIcon: "", videoLength: "" })
            curitem.setFields(item)
            currow.appendChild(curitem)
            counter = 1
            curitem = invalid
        end if
        result.push(item) 'Unparsed "XMLContent", can be used to cache results later.
        item = invalid
    end for
    '?type(content)
    ?"exported"+Str(content.getChildCount()*4)+" items from Odysee (Video Search)"

    '?"manufacturing finished for key: "+subkey
    return  {contentarray:result:content:content} 'Returns the array
End Function

function getvideoLength(length)
    timeConverter = CreateObject("roDateTime")
    timeConverter.FromSeconds(length)
    days = timeConverter.GetDayOfMonth().ToStr()
    hours = timeConverter.GetHours().ToStr()
    minutes = timeConverter.GetMinutes().ToStr()
    seconds = timeConverter.GetSeconds().ToStr()
    result = ""
    if timeConverter.GetDayOfMonth() < 10
      days = "0" + timeConverter.GetDayOfMonth().ToStr()
    end if
    if timeConverter.GetHours() < 10
      hours = "0" + timeConverter.GetHours().ToStr()
    end if
    if timeConverter.GetMinutes() < 10
      minutes = "0" + timeConverter.GetMinutes().ToStr()
    end if
    if timeConverter.GetSeconds() < 10
      seconds = "0" + timeConverter.GetSeconds().ToStr()
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
    timeConverter = invalid
    days = invalid
    hours = invalid
    minutes = invalid
    seconds = invalid
    return result
  end function