'All parsing functions (creating feed, etc)

Function ManufacturePlaceholderVideoGrid(amount, category) 'Create Placeholder Grid with Amount items.
    mediaindex={}
    result=[]
    counter=0
    content=createObject("RoSGNode","ContentNode")

    For i=1 To amount Step 1
        counter+=1
        item = {}
        if Type(category) <> "<uninitialized>" And category <> invalid And category <> ""
            item.Title = category+" placeholder video #"+Str(i)
        else
            category = ""
            item.Title = "placeholder video #"+Str(i)
        end if
        item.Creator = "placeholder creator"
        item.Views = "placeholder views"
        item.ReleaseDate = "placeholder following"
        item.guid = Str(i)+"GUIDPlaceholder"
        thumbnail = "pkg:/images/odysee_oops.png"
        item.HDPosterURL = thumbnail
        item.thumbnailDimensions = [360, 240]
        item.url = "https://cdn.lbryplayer.xyz/api/v3/streams/free/he-died-1000-times...-and-then-this/233ffa6e82b720ae85c910edf59be0b15ff58f8d/d1ce99"
        item.stream = {url : item.url}
        item.streamFormat = "mp4"
        item.link = item.url
        item.source = "lbry"
        item.itemType = "video"
        
        'Create content (content -> row -> item)
        if counter = 1
            currow = createObject("RoSGNode","ContentNode")
            curitem = createObject("RoSGNode","ContentNode")
            curitem.addFields({creator: "", thumbnailDimensions: [], itemType: "", views: "", Channel: ""})
            curitem.setFields(item)
            currow.appendChild(curitem)
        else if counter < 5
            curitem = createObject("RoSGNode","ContentNode")
            curitem.addFields({creator: "", thumbnailDimensions: [], itemType: "", views: "", Channel: ""})
            curitem.setFields(item)
            currow.appendChild(curitem)
        else
            content.appendChild(currow)
            currow = invalid
            currow = createObject("RoSGNode","ContentNode")
            curitem = createObject("RoSGNode","ContentNode")
            curitem.addFields({creator: "", thumbnailDimensions: [], itemType: "", views: "", Channel: ""})
            curitem.setFields(item)
            currow.appendChild(curitem)
            counter = 0
        end if

        result.push(item)
        mediaindex[item.guid] = item
    end for

    '? "manufacturing finished for key: "+subkey
    return  {contentarray:result:index:mediaindex:content:content} 'Returns the array
End Function