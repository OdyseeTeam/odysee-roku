sub Init()
    m.top.functionName = "master"
end sub

sub master()
    '?m.top.constants
    '?m.top.cookies
    '?m.top.uid
    '?m.top.channels
    '?m.top.rawname
    m.top.output = ChannelsToVideoGrid(m.top.channels, m.top.blocked)
end sub

function ChannelsToVideoGrid(channels, blockedChannels)
    'uncomment to test multiple removed categories
    'if m.top.rawname = "rabbithole" OR m.top.rawname = "tech" OR m.top.rawname = "music" or m.top.rawname = "education"
    '    m.top.error = true
    '    m.top.numerrors += 1
    '    return { error: true }
    'end if

    'uncomment to test all categories missing
    'm.top.error = true
    'm.top.numerrors += 1
    'return { error: true }

    m.parseTimer = CreateObject("roTimespan")
    m.parseLibTimer = CreateObject("roTimespan")
    result = [] 'This is an array of associativeArrays that can be used to set a ContentNode
    lastParsedAmount = 0
    currentParsedAmount = 0
    max = 48 ' Amount of items needed
    channels = m.top.channels
    gotEnough = false 'got enough items?

    'start building first query
    date = CreateObject("roDateTime")
    date.Mark()
    curPage = 1 'current query page
    threadName = m.top.rawname
    'Grab 15 items, loop until valid max items reached.
    'If last parsed items = current parsed items, no more items are avaliable
    'If no more items are avalible, and amount of items is 0, error.
    m.parseTimer.Mark()
    'STAGE 1: resolve livestreams
    potentiallyLiveUsers = channels
    if m.top.resolveLivestreams 'we have to resolve livestreams now, apparently.
        if isValid(potentiallyLiveUsers)
            liveData = getLiveDataFromCIDS(potentiallyLiveUsers)
            allStreams = getLivestreamsBatch(liveData.claimIDs, liveData.liveData, liveData.liveIDs)
            if allStreams.Count() > 0
                result.Append(allStreams)
            end if
        else
            liveData = getLivestreamChannelList(blockedChannels)
            allStreams = getLivestreamsBatch(liveData.claimIDs, liveData.liveData, liveData.liveIDs)
            if allStreams.Count() > 0
                result.Append(allStreams)
            end if
        end if
    end if
    ? "GetSinglePage," + threadname + ",livestreams," + (m.parseTimer.TotalMilliseconds() / 1000).ToStr()
    'm.parseTimer.Mark()
    'STAGE 2: mass parse
    m.parseLibTimer.Mark()
    currentPage = getVideoPage(curPage)
    ? "GetSinglePage," + threadname + ",getPage," + (m.parseLibTimer.TotalMilliseconds() / 1000).ToStr()
    while gotEnough = false
        if currentParsedAmount = lastParsedAmount and curPage <> 1 or currentParsedAmount >= max 'got no more/got enough
            gotEnough = true
            exit while
        end if
        lastParsedAmount = currentParsedAmount
        'for each claim in currentPage
        '    ? claim
        'end for
        m.timeConverter = CreateObject("roDateTime")
        m.time = CreateObject("roDateTime")
        m.parseLibTimer.Mark()
        for each claim in currentPage
            pv = parseVideo(claim)
            if pv.Count() > 0
                result.push(pv)
                currentParsedAmount += 1
                if currentParsedAmount >= max
                    exit for
                end if
            end if
            pv = invalid
        end for
        ? "GetSinglePage," + threadname + ",parsing," + (m.parseLibTimer.TotalMilliseconds() / 1000).ToStr()
        if currentParsedAmount >= max
            exit while
        end if
        curPage += 1
        m.parseLibTimer.Mark()
        currentPage = getVideoPage(curPage)
        ? "GetSinglePage," + threadname + ",getPage," + (m.parseLibTimer.TotalMilliseconds() / 1000).ToStr()
    end while
    '? "GetSinglePage,"+threadname+",get," + (m.parseTimer.TotalMilliseconds() / 1000).ToStr()
    m.parseTimer.Mark()
    'Stage 3: Format Content (content -> row -> item) from "result"/preparsed.
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
            'if counter = items.Count() - 1 'misalignment fix, will need to implement this better later.
            '    content.appendChild(currow)
            'end if
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
    ? "GetSinglePage," + threadname + ",reformat," + (m.parseTimer.TotalMilliseconds() / 1000).ToStr()
    m.parseTimer.Mark()
    '?type(content)
    ?"exported" + Str(content.getChildCount() * 4) + " items from Odysee"
    if (content.getChildCount() * 4) = 0
        m.top.error = true
        m.top.numerrors += 1
        return { error: true }
    end if
    '?"manufacturing finished for key: "+subkey
    m.top.error = false
    return { contentarray: result: content: content } 'Returns the array
end function