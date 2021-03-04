'LBRY Parsing
'William Foster/S9260/CaffinatedCoder 2021

'All parsing functions (creating feed, etc)
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
            item.addFields({creator: "", thumbnailDimensions: []})
            'Don't do item.SetFields(itemAA), as it doesn't cast streamFormat to proper value
            'for each key in itemAA
		    '    ?"key = ", key, itemAA[key]
            '    item[key] = itemAA[key]
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

Function IsValid(value As Dynamic) As Boolean 'TheEndless Roku Development forums
    Return Type(value) <> "<uninitialized>" And value <> invalid
End Function