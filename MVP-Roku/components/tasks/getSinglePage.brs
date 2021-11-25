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
    m.top.output = ChannelsToVideoGrid(m.top.channels)
End Sub

Function ChannelsToVideoGrid(channels)
try
    queryOutput = "placeholder"
    date = CreateObject("roDateTime")
    max = 48
    queryURL = m.top.constants["QUERY_API"]+"/api/v1/proxy?m=claim_search"
    queryJSON = FormatJson({"jsonrpc":"2.0","method":"claim_search","params":{"page_size":max,"claim_type":"stream","media_types":["video/mp4"],"no_totals":true,"any_tags":[],"not_tags":["porn","porno","nsfw","mature","xxx","sex","creampie","blowjob","handjob","vagina","boobs","big boobs","big dick","pussy","cumshot","anal","hard fucking","ass","fuck","hentai"],"channel_ids":channels,"not_channel_ids":[],"order_by":["release_time"],"has_no_source":false,"include_purchase_receipt":false, "has_channel_signature":true,"valid_channel_signature":true, "has_source": true}})
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
            exit while
        end if
    end while
    items = response.result.items
    mediaindex={}
    result=[]
    counter=0
    content=createObject("RoSGNode","ContentNode")
    ? "got "+str(items.Count())+" items from Odysee"
    For i=0 To items.Count()-1 Step 1 'Parse response
        item = {}
        item.Title = items[i].value.title
        item.Creator = items[i].signing_channel.name
        item.Description = ""
        item.Channel = items[i].signing_channel.claim_id
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
            thumbnail = m.top.constants["IMAGE_PROCESSOR"]+items[i].value.thumbnail.url
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
            curitem.addFields({creator: "", thumbnailDimensions: [], itemType: "", Channel: ""})
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
            curitem.addFields({creator: "", thumbnailDimensions: [], itemType: "", Channel: ""})
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
    ? "exported"+Str(content.getChildCount()*4)+" items from Odysee"

    '? "manufacturing finished for key: "+subkey
    m.top.error=false
    return  {contentarray:result:index:mediaindex:content:content} 'Returns the array
catch e
    m.top.error=true
    m.top.numerrors+=1
    return {error: true}
end try
End Function