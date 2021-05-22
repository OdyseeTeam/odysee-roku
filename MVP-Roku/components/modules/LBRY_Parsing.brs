'All parsing functions (creating feed, etc)

Function ManufacturePlaceholderChannelGrid(amount) 'Create Placeholder Grid with Amount items.
    mediaindex={}
    result = []
    For i=1 To amount Step 1 
        item = {}
        item.Title = "placeholder channel #"+Str(i)
        item.Creator = ""
        item.Views = ""
        item.Description = "placeholder description"
        item.ReleaseDate = "placeholder following"
        item.guid = i+"GUIDPlaceholder"
        thumbnail = "pkg:/images/odysee_oops.png"
        item.HDPosterURL = thumbnail
        item.HDBackgroundImageUrl = thumbnail
        item.thumbnailDimensions = [360, 240]
        item.url = "placeholder channel"
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

Function ManufacturePlaceholderVideoGrid(amount) 'Create Placeholder Grid with Amount items.
    mediaindex={}
    result = []
    For i=1 To amount Step 1 
        item = {}
        item.Title = "placeholder video #"+Str(i)
        item.Creator = "placeholder creator"
        item.Views = "placeholder views"
        item.Description = "placeholder description"
        item.ReleaseDate = "placeholder following"
        item.guid = i+"GUIDPlaceholder"
        thumbnail = "pkg:/images/odysee_oops.png"
        item.HDPosterURL = thumbnail
        item.HDBackgroundImageUrl = thumbnail
        item.thumbnailDimensions = [360, 240]
        item.url = "https://cdn.lbryplayer.xyz/api/v4/streams/free/gaylegos/7ce07b772749b3e37673ad2c5752e6a010a73efc/00ced8"
        item.stream = {url : item.url}
        item.streamFormat = "mp4"
        item.link = item.url
        item.source = "lbry"
        item.itemType = "video"
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
            'thumbnailDimensions for display, Creator for the creator, itemType for handling Channels VS standard items. Channel for Options Channel Viewing.
            item.addFields({creator: "", thumbnailDimensions: [], itemType: "", views: "", Channel: ""}) 
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