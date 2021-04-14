'All parsing functions (creating feed, etc)
Function ManufactureQueryFeed(query)
    ? "manufacturing started (search)"
    lbryclaims = QueryLBRYAPI(query)
    result = []  'Store all results inside an array.
    mediaindex={}
    for each claim in lbryclaims.result.items
        if IsValid(claim.value.thumbnail.url)
            if Instr(claim.value.thumbnail.url, "spee.ch") > 0
                thumbnail = "https://image-optimizer.vanwanet.com/?address=https://cdn.lbryplayer.xyz/speech/"+claim.value.thumbnail.url.split("/").pop().split(".").getEntry(0)+".jpg&height=180&width=320&quality=80" 'Because the spee.ch redirect is broken.
            else
                thumbnail = "https://image-optimizer.vanwanet.com/?address="+claim.value.thumbnail.url+"&height=180&width=320&quality=80"
            end if
        else
            thumbnail = "pkg:/images/odysee_oops.png"
        end if
        item = {}
        if IsValid(claim.value.title) AND IsValid(claim.normalized_name) AND IsValid(claim.claim_id) AND IsValid(claim.value.source.hash) AND IsValid(claim.signing_channel.value) OR IsValid(claim.value.title) AND IsValid(claim.normalized_name) AND IsValid(claim.claim_id) AND IsValid(claim.value.source.hash) AND IsValid(claim.signing_channel.channel_id)
            item.Title = claim.value.title
            item.ReleaseDate = claim.timestamp
            if not IsValid(claim.value.description)
                claim.value.description = "NODESC"
            end if
            if IsValid(claim.signing_channel.value) AND IsValid(claim.value.description) AND isValid(claim.signing_channel.value.title)
                item.DESCRIPTION = claim.value.description
                item.Creator = claim.signing_channel.value.title
            else if IsValid(claim.signing_channel.name)
                item.DESCRIPTION = claim.value.description
                item.Creator = claim.signing_channel.name.Replace("@", "")
            else if IsValid(claim.signing_channel.claim_id)
                item.DESCRIPTION = claim.value.description
                item.Creator = "ID#"+claim.signing_channel.claim_id
            else
                item.DESCRIPTION = claim.value.description
                item.Creator = "Anonymous"
            end if
            r = CreateObject("roRegex", "[^\x1F-\x7F]+", "") 
            rawname = claim.normalized_name
            if r.IsMatch(rawname) ' The Roku cannnot handle EMOJI.
                ? "Invalid Video"
            else
                item.url = ("https://cdn.lbryplayer.xyz/api/v3/streams/free/"+claim.normalized_name+"/"+claim.claim_id+"/"+claim.value.source.hash.left(6)).EncodeUri()
                item.stream = {url : item.url}
                item.streamFormat = "mp4"
                item.HDPosterURL = thumbnail
                item.HDBackgroundImageUrl = thumbnail 'placeholder; get icon for user soon
                item.link = item.url
                item.source = "lbry"
                item.guid = claim.claim_id
                item.itemType = "video"
                result.push(item)
                mediaindex[item.guid] = item
            end if
            'free memory from temporary operation
            r = Invalid
            rawname = Invalid
            formattedname = Invalid
        end if
     end for
     list = [
        {
            ContentList : SelectTo(result, 4)
        }
    ]
    rowcount = int(result.count()/4)-1
    for row=1 to rowcount step 1
        '? "row "+Str(row+1)
        list.push({ContentList : SelectTo(result, 4, row*4)})
    end for
    content = ParseXMLContent(list)
    ? "manufacturing finished (search)"
    return  {contentarray:result:index:mediaindex:content:content} 'Returns the array
End Function

Function ManufactureChannelGrid(feed)
    '? "manufacturing started for key: "+subkey
    mediaindex={}
    result = []
    '{id: channel, username: username, realname: title, subs: getSubs(channel), thumbnail: channelthumb}
    for each video in feed
        item = {}
        item.Title = video["realname"]
        item.Creator = Str(video["subs"])+" following"
        item.Description = item.Creator
        item.ReleaseDate = "none"
        item.guid = video["id"]
        thumbnail = video["thumbnail"]
        item.HDPosterURL = thumbnail
        item.HDBackgroundImageUrl = thumbnail
        item.thumbnailDimensions = [360, 240]
        item.url = video["id"]
        item.stream = {url : "none"}
        item.streamFormat = "none"
        item.link = item.url
        item.source = "lbry"
        item.itemType = "channel"
        result.push(item)
        mediaindex[item.guid] = item
    end for
    list = [
        {
            ContentList : SelectTo(result, 4)
        }
    ]
    rowcount = int(result.count()/4)-1
    for row=1 to rowcount step 1
        '? "row "+Str(row+1)
        list.push({ContentList : SelectTo(result, 4, row*4)})
    end for
    content = ParseXMLContent(list)
    '? "manufacturing finished for key: "+subkey
    return  {contentarray:result:index:mediaindex:content:content} 'Returns the array
End Function

Function ManufactureVFeed(feed, subkey, dimensions)
    '? "manufacturing started for key: "+subkey
    mediaindex={}
    result = []
    '? dimensions
    for each video in feed[subkey]
        item = {}
        item.Title = video[0]
        item.Creator = video[1]
        item.Description = video[2]
        item.ReleaseDate = video[3]
        item.guid = video[4]
        thumbnail = video[5]
        item.HDPosterURL = thumbnail
        item.HDBackgroundImageUrl = thumbnail
        item.thumbnailDimensions = dimensions
        item.url = video[6]
        item.stream = {url : item.url}
        item.streamFormat = "mp4"
        item.link = item.url
        item.itemType = "video"
        item.source = "lbry"
        result.push(item)
        mediaindex[item.guid] = item
    end for
    list = [
        {
            ContentList : SelectTo(result, 4)
        }
    ]
    rowcount = int(result.count()/4)-1
    for row=1 to rowcount step 1
        '? "row "+Str(row+1)
        list.push({ContentList : SelectTo(result, 4, row*4)})
    end for
    content = ParseXMLContent(list)
    '? "manufacturing finished for key: "+subkey
    return  {contentarray:result:index:mediaindex:content:content} 'Returns the array
End Function

Function ParseXMLContent(list As Object)  'Formats content into content nodes so they can be passed into the RowList
    RowItems = createObject("RoSGNode","ContentNode")
    'Content node format for RowList: ContentNode(RowList content) --<Children>-> ContentNodes for each row --<Children>-> ContentNodes for each item in the row)
    for each rowAA in list
        row = createObject("RoSGNode","ContentNode")
        row.Title = rowAA.Title
        for each itemAA in rowAA.ContentList
            item = createObject("RoSGNode","ContentNode")
            item.addFields({creator: "", thumbnailDimensions: [], itemType: ""}) 'thumbnailDimensions for display, Creator for the creator, itemType for handling Channels VS standard items
            'Don't do item.SetFields(itemAA), as it doesn't cast streamFormat to proper value
            'for each key in itemAA
		' ?"key = ", key, itemAA[key]
                'item[key] = itemAA[key]
	    'end for
	    item.setFields(itemAA)
            row.appendChild(item)
        end for
        RowItems.appendChild(row)
    end for
    return RowItems
End Function

Function SelectTo(array as Object, num=25 as Integer, start=0 as Integer) as Object  'This method copies an array up to the defined number 'num' (default 25)
    result = []
    for i = start to array.count()-1
        result.push(array[i])
        if result.Count() >= num
            exit for
        end if
    end for
    return result
End Function

Function SelectSource(array as Object, source as string) as Object  'This method copies an array up to the defined number 'num' (default 25)
    result = []
    for each item in array
        if item.source = source
            result.push(item)
        end if
    end for
    return result
End Function
'TODO: Optimization might either be a dedicated trending endpoint or seperating out the right side from split("]")[0] AKA split("]")[1] and outputting that for the next query.
'That is, if we query them in order. Otherwise it is just useless.
function find_subvar(jsmap, subvar) 
    subvar = jsmap.split(subvar+" = [")[1].split("]")[0].Trim().Replace(subvar+" =", "").Replace(" ", "").Replace("'", "").Replace(",","").split("\n")
    out = []
    for each var in subvar
        if Instr(var, "//") > 0
            out.push(var.split("//")[0])
        else
            out.push(var)
        end if
    end for
    out.Pop()
    out.Shift()
    return out
end function