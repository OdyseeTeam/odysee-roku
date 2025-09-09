sub Init()
    m.top.functionName = "master"
end sub

sub master()
    m.top.output = GetCategoryLiveItems(m.top.channels, m.top.blocked)
end sub

function GetCategoryLiveItems(channels, blockedChannels)
    result = []
    ' resolve livestreams using liveUtils but filtered by category channels
    if isValid(channels) and channels.Count() > 0
        liveData = getLiveDataFromCIDS(channels)
        if isValid(liveData) and isValid(liveData.claimIDs)
            allStreams = getLivestreamsBatch(liveData.claimIDs, liveData.liveData, liveData.liveIDs)
            if isValid(allStreams) and allStreams.Count() > 0
                result.Append(allStreams)
            end if
        end if
    end if
    ' Build ContentNode rows of 4
    content = createObject("RoSGNode", "ContentNode")
    counter = 0
    for each item in result
        if counter < 4
            if IsValid(currow) <> true
                currow = createObject("RoSGNode", "ContentNode")
            end if
            curitem = createObject("RoSGNode", "ContentNode")
            curitem.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", reposted: false, repostedBy: "", rawCreator: "", videoLength: "" })
            curitem.setFields(item)
            currow.appendChild(curitem)
            counter += 1
            curitem = invalid
        else
            content.appendChild(currow)
            currow = invalid
            currow = createObject("RoSGNode", "ContentNode")
            curitem = createObject("RoSGNode", "ContentNode")
            curitem.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", reposted: false, repostedBy: "", rawCreator: "", videoLength: "" })
            curitem.setFields(item)
            currow.appendChild(curitem)
            counter = 1
            curitem = invalid
        end if
    end for
    if IsValid(currow) and counter > 0
        content.appendChild(currow)
    end if
    if (content.getChildCount() * 4) = 0
        return { error: false, content: createObject("RoSGNode", "ContentNode") }
    end if
    return { error: false, content: content }
end function


