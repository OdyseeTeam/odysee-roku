sub Init()
    m.historyGrid = m.top.findNode("historyGrid")
    m.statusText = m.top.findNode("statusText")
    m.clearBtn = m.top.findNode("clearHistoryButton")

    m.historyGrid.observeField("rowItemSelected", "onVideoSelected")
    m.historyGrid.observeField("itemFocused", "onItemFocused")
    if IsValid(m.clearBtn) then m.clearBtn.observeField("buttonSelected", "onClearHistorySelected")

    m.top.observeField("restoreFocus", "onRestoreFocus")
    m.top.observeField("visible", "onVisibleChanged")

    ' Create task for fetching metadata
    m.fetchTask = CreateObject("roSGNode", "getWatchHistory")
    m.fetchTask.observeField("output", "onMetadataFetched")

    ' Track last known focus position
    m.lastFocusRow = 0
    m.lastFocusCol = 0
end sub

sub onItemFocused()
    ' Update last known focus position when it changes
    focused = m.historyGrid.itemFocused
    if Type(focused) = "roArray" and focused.Count() >= 2
        m.lastFocusRow = focused[0]
        m.lastFocusCol = focused[1]
    end if
end sub

sub onVisibleChanged()
    ' Reload history when scene becomes visible
    if m.top.visible = true
        loadWatchHistory()
        if IsValid(m.clearBtn) then m.clearBtn.visible = true
    end if
end sub

sub loadWatchHistory()
    print "[WatchHistory] Loading watch history"
    m.statusText.visible = true
    m.statusText.text = "Loading..."

    ' Read all history entries from registry
    reg = CreateObject("roRegistrySection", "watchHistory")
    historyKeys = reg.GetKeyList()

    print "[WatchHistory] Registry keys found: "; historyKeys.Count()

    if historyKeys.Count() = 0
        print "[WatchHistory] No watch history found"
        m.statusText.text = "No watch history yet"
        m.historyGrid.visible = false
        return
    end if

    ' Parse history and collect claim IDs with lastPlayedAt
    historyItems = []
    for each claimId in historyKeys
        jsonStr = reg.Read(claimId)
        if jsonStr <> ""
            try
                historyData = ParseJson(jsonStr)
                if IsValid(historyData) and IsValid(historyData.lastPlayedAt)
                    historyItems.Push({
                        claimId: claimId,
                        lastPlayedAt: historyData.lastPlayedAt,
                        position: historyData.position,
                        duration: historyData.duration
                    })
                end if
            catch e
                print "[WatchHistory] Error parsing history entry: "; claimId
            end try
        end if
    end for

    if historyItems.Count() = 0
        print "[WatchHistory] No valid history items"
        m.statusText.text = "No watch history yet"
        m.historyGrid.visible = false
        return
    end if

    ' Sort by lastPlayedAt (most recent first)
    for i = 0 to historyItems.Count() - 1
        for j = i + 1 to historyItems.Count() - 1
            if historyItems[i].lastPlayedAt < historyItems[j].lastPlayedAt
                temp = historyItems[i]
                historyItems[i] = historyItems[j]
                historyItems[j] = temp
            end if
        end for
    end for

    ' Limit to 100 most recent items
    maxItems = 100
    if historyItems.Count() > maxItems
        ' Trim array to first 100
        trimmed = []
        for i = 0 to maxItems - 1
            trimmed.Push(historyItems[i])
        end for
        historyItems = trimmed
    end if

    print "[WatchHistory] Sorted "; historyItems.Count(); " items, will fetch metadata"

    ' Use task to fetch metadata
    m.fetchTask.constants = m.top.constants
    m.fetchTask.uid = m.top.uid
    m.fetchTask.historyItems = historyItems
    m.fetchTask.control = "RUN"
end sub

sub onMetadataFetched()
    results = m.fetchTask.output

    print "[WatchHistory] Metadata fetched: "; results.Count(); " items"

    if results.Count() = 0
        m.statusText.text = "No watch history available"
        m.historyGrid.visible = false
        return
    end if

    ' Build grid content (4 items per row)
    buildGrid(results)
end sub

sub onClearHistorySelected()
    print "[WatchHistory] Clear History pressed"
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Clear Watch History?"
    dialog.message = "This removes all locally saved watch progress. This cannot be undone."
    dialog.buttons = ["Clear", "Cancel"]
    dialog.observeField("buttonSelected", "onClearHistoryDialogButton")
    scene = m.top.getScene()
    if IsValid(scene) then scene.dialog = dialog
end sub

sub onClearHistoryDialogButton(e as object)
    idx = e.getData()
    scene = m.top.getScene()
    if IsValid(scene) then scene.dialog = invalid
    if idx = 0
        reg = CreateObject("roRegistrySection", "watchHistory")
        keys = reg.GetKeyList()
        for each k in keys
            reg.Delete(k)
        end for
        reg.Flush()
        clearProgressFromHomeGrid()
        m.statusText.visible = true
        m.statusText.text = "Watch history cleared"
        m.historyGrid.visible = false
        if IsValid(m.clearBtn) then m.clearBtn.setFocus(true)
    else
        if IsValid(m.historyGrid) and m.historyGrid.visible = true
            m.historyGrid.setFocus(true)
        else if IsValid(m.clearBtn)
            m.clearBtn.setFocus(true)
        end if
    end if
end sub

sub clearProgressFromHomeGrid()
    scene = m.top.getScene()
    if not IsValid(scene) then return
    vg = invalid
    try
        vg = scene.findNode("vgrid")
    catch e
        vg = invalid
    end try
    if not IsValid(vg) or not IsValid(vg.content) then return
    rowCount = 0
    try: rowCount = vg.content.getChildCount() : catch e: rowCount = 0 : end try
    for r = 0 to rowCount - 1
        rowNode = vg.content.getChild(r)
        if IsValid(rowNode)
            ic = 0
            try: ic = rowNode.getChildCount() : catch e: ic = 0 : end try
            for c = 0 to ic - 1
                n = rowNode.getChild(c)
                if IsValid(n)
                    n.addFields({ watchProgress: 0 })
                end if
            end for
        end if
    end for
end sub

sub buildGrid(results as object)
    content = CreateObject("roSGNode", "ContentNode")

    ' Use midnight boundaries for clean buckets
    now = CreateObject("roDateTime")
    nowSeconds = now.AsSeconds()
    todayStart = nowSeconds - (nowSeconds mod 86400) ' Start of today (midnight)
    sevenDaysStart = todayStart - (7 * 86400)
    fourteenDaysStart = todayStart - (14 * 86400)

    ' Categorize items by time
    todayItems = []
    recentItems = [] ' From 1 to 7 days ago (excludes today)
    lastWeekItems = [] ' >7 to 14 days ago
    earlierItems = [] ' >14 days ago

    for each result in results
        if IsValid(result.lastPlayedAt)
            if result.lastPlayedAt >= todayStart
                todayItems.Push(result)
            else if result.lastPlayedAt >= sevenDaysStart
                recentItems.Push(result)
            else if result.lastPlayedAt >= fourteenDaysStart
                lastWeekItems.Push(result)
            else
                earlierItems.Push(result)
            end if
        else
            earlierItems.Push(result)
        end if
    end for

    ' Build rows for each non-empty section
    if todayItems.Count() > 0
        addHistorySection(content, "Today", todayItems)
    end if

    if recentItems.Count() > 0
        addHistorySection(content, "Recent", recentItems)
    end if

    if lastWeekItems.Count() > 0
        addHistorySection(content, "Last Week", lastWeekItems)
    end if

    if earlierItems.Count() > 0
        addHistorySection(content, "Earlier", earlierItems)
    end if

    ' Apply content and reserve label column for all rows
    m.historyGrid.content = content
    rowCount = content.getChildCount()
    if rowCount > 0
        reserve = []
        for i = 0 to rowCount - 1
            reserve.Push(true)
        end for
        m.historyGrid.showRowLabel = reserve
    end if

    ' Built-in RowList labels will render; extra row height prevents overlap

    m.historyGrid.visible = true
    m.statusText.visible = false
    m.historyGrid.setFocus(true)
    m.historyGrid.jumpToRowItem = [0, 0]

    print "[WatchHistory] Grid built with "; results.Count(); " items in sections"
end sub


function addHistorySection(content as object, sectionLabel as string, items as object) as integer
    ' Add items split into rows of 4; set label only on the first row
    itemsPerRow = 4
    totalRows = Int((items.Count() + itemsPerRow - 1) / itemsPerRow) ' Ceiling division

    for rowIdx = 0 to totalRows - 1
        row = content.createChild("ContentNode")
        if rowIdx = 0 then
            row.title = sectionLabel
        else
            row.title = ""
        end if

        ' Add items to this row
        startIdx = rowIdx * itemsPerRow
        endIdx = startIdx + itemsPerRow - 1
        if endIdx >= items.Count() then endIdx = items.Count() - 1

        for itemIdx = startIdx to endIdx
            result = items[itemIdx]

            ' Create content node for video (matching getSinglePage.brs pattern)
            node = row.createChild("ContentNode")

            ' Add custom fields (matching field names that PosterItem expects)
            node.addFields({
                CREATOR: "",
                ITEMTYPE: "",
                Channel: "",
                ChannelIcon: "",
                videolength: "",
                claimId: "",
                guid: "",
                URL: "",
                streamFormat: "",
                rawCreator: "",
                chatCategory: "",
                description: ""
            })

            ' Now set all field values
            node.TITLE = result.title
            if result.title = "" then node.TITLE = "Untitled Video"

            node.HDPOSTERURL = result.thumbnailUrl
            if result.thumbnailUrl = "" then node.HDPOSTERURL = "pkg:/images/generic/bad_icon_requires_usage_rights.png"

            node.Creator = result.channelName
            if result.channelName = "" then node.Creator = "Unknown"

            node.RELEASEDATE = result.releaseDate
            node.ITEMTYPE = result.itemType
            node.ChannelIcon = result.channelIcon
            node.videolength = result.videoLength
            node.claimId = result.claimId
            node.Channel = result.channelId
            node.guid = result.claimId
            ' Use permanent URL if available, fallback to claim ID
            if IsValid(result.permanentUrl) and result.permanentUrl <> ""
                node.URL = result.permanentUrl
            else
                node.URL = "lbry://" + result.claimId
            end if

            ' Calculate watch progress percentage with minimum 1% (skip for livestreams)
            isLivestream = IsValid(result.itemType) and result.itemType = "livestream"
            if not isLivestream
                if IsValid(result.duration) and result.duration > 0 and IsValid(result.position)
                    progress = (result.position / result.duration) * 100
                    if progress > 100 then progress = 100
                    if progress < 0 then progress = 0
                    ' Show minimum 1% for any video in watch history (even if position is 0)
                    ' This indicates the video was opened/viewed, even briefly
                    if progress < 1 then progress = 1
                    node.addFields({ watchProgress: progress })
                else if IsValid(result.lastPlayedAt)
                    ' Fallback: show 1% if we have lastPlayedAt but no duration
                    node.addFields({ watchProgress: 1 })
                end if
            end if
        end for
    end for

    return totalRows
end function

sub onVideoSelected()
    selected = m.historyGrid.rowItemSelected
    if not IsValid(selected) or selected.Count() < 2 then return

    row = selected[0]
    col = selected[1]

    content = m.historyGrid.content
    if IsValid(content)
        rowNode = content.getChild(row)
        if IsValid(rowNode)
            videoNode = rowNode.getChild(col)
            if IsValid(videoNode)
                m.top.selectedVideo = {
                    claimId: videoNode.claimId,
                    guid: videoNode.guid,
                    title: videoNode.TITLE,
                    Channel: videoNode.Channel,
                    creator: videoNode.creator,
                    HDPOSTERURL: videoNode.HDPOSTERURL,
                    URL: videoNode.URL,
                    itemType: videoNode.ITEMTYPE,
                    streamFormat: videoNode.streamFormat,
                    ChannelIcon: videoNode.ChannelIcon,
                    rawCreator: videoNode.rawCreator,
                    chatCategory: videoNode.chatCategory,
                    description: videoNode.description
                }
            end if
        end if
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    if key = "back"
        ' If clear button has focus, move back to grid instead of bubbling
        if IsValid(m.clearBtn)
            has = false
            try: has = m.clearBtn.hasFocus() : catch e: has = false : end try
            if has = true and IsValid(m.historyGrid)
                m.historyGrid.setFocus(true)
                m.historyGrid.jumpToRowItem = [0, 0]
                return true
            end if
        end if
        ' Let parent handle back button otherwise
        return false
    else if key = "*" or key = "options"
        ' Navigate to channel page for currently focused video
        navigateToChannel()
        return true
    end if

    ' DOWN from clear button -> return focus to grid
    if key = "down"
        if IsValid(m.clearBtn)
            cf = false
            try: cf = m.clearBtn.hasFocus() : catch e: cf = false : end try
            if cf = true and IsValid(m.historyGrid)
                m.historyGrid.setFocus(true)
                return true
            end if
        end if
    end if

    ' LEFT from clear button -> return focus to grid (restore last known)
    if key = "left"
        if IsValid(m.clearBtn)
            cf = false
            try: cf = m.clearBtn.hasFocus() : catch e: cf = false : end try
            if cf = true and IsValid(m.historyGrid)
                m.historyGrid.setFocus(true)
                r = 0: c = 0
                if IsValid(m.lastFocusRow) then r = m.lastFocusRow
                if IsValid(m.lastFocusCol) then c = m.lastFocusCol
                m.historyGrid.jumpToRowItem = [r, c]
                return true
            end if
        end if
    end if


    ' Prevent focus from disappearing by blocking navigation at boundaries
    if not IsValid(m.historyGrid) or not m.historyGrid.visible then return false

    content = m.historyGrid.content
    if not IsValid(content) then return false

    currentItem = m.historyGrid.itemFocused
    ' itemFocused is array [row, col] when grid has focus, but can be integer initially
    row = -1
    col = -1

    itemType = Type(currentItem)
    if itemType = "roArray" and currentItem.Count() >= 2
        row = currentItem[0]
        col = currentItem[1]
    else
        ' Use last known position if itemFocused isn't valid yet
        if IsValid(m.lastFocusRow) and IsValid(m.lastFocusCol)
            row = m.lastFocusRow
            col = m.lastFocusCol
        else
            return false
        end if
    end if

    rowCount = content.getChildCount()

    ' UP from first row -> focus clear history button
    if key = "up" and row = 0
        if IsValid(m.clearBtn)
            m.clearBtn.setFocus(true)
            return true
        else
            return true
        end if
    end if

    ' Guard DOWN - block if at last row
    if key = "down" and row = rowCount - 1
        return true
    end if

    ' Guard LEFT and RIGHT - need to check current row's item count
    if row >= 0 and row < rowCount
        currentRow = content.getChild(row)
        if IsValid(currentRow)
            itemCount = currentRow.getChildCount()

            ' Guard LEFT - block if at first column
            if key = "left" and col = 0
                return true
            end if

            ' Guard RIGHT - block if at last column in this row
            if key = "right" and col = itemCount - 1
                ' If on top row, move to clear button instead of blocking
                if row = 0 and IsValid(m.clearBtn)
                    m.clearBtn.setFocus(true)
                    return true
                end if
                return true
            end if
        end if
    end if

    return false
end function

sub onRestoreFocus()
    ' Restore focus to grid
    print "[WatchHistory] Restoring focus"
    m.historyGrid.setFocus(true)
end sub

sub navigateToChannel()
    ' Get currently focused video and navigate to its channel page
    print "[WatchHistory] Navigate to channel for focused video"

    content = m.historyGrid.content
    if not IsValid(content) then return

    currentItem = m.historyGrid.itemFocused
    row = -1
    col = -1

    ' Get row and col from itemFocused
    itemType = Type(currentItem)
    if itemType = "roArray" and currentItem.Count() >= 2
        row = currentItem[0]
        col = currentItem[1]
    else if IsValid(m.lastFocusRow) and IsValid(m.lastFocusCol)
        row = m.lastFocusRow
        col = m.lastFocusCol
    else
        print "[WatchHistory] Could not determine focused item"
        return
    end if

    ' Get the video node
    if row >= 0 and row < content.getChildCount()
        rowNode = content.getChild(row)
        if IsValid(rowNode) and col >= 0 and col < rowNode.getChildCount()
            videoNode = rowNode.getChild(col)
            if IsValid(videoNode)
                ' Extract channel info from video node
                channelId = videoNode.Channel
                channelName = videoNode.Creator

                if IsValid(channelId) and channelId <> ""
                    print "[WatchHistory] Navigating to channel: "; channelName; " ("; channelId; ")"
                    ' Set selectedChannel field to trigger navigation in HomeScene
                    m.top.selectedChannel = {
                        channelId: channelId,
                        channelName: channelName
                    }
                else
                    print "[WatchHistory] Channel ID not available for this video"
                end if
            end if
        end if
    end if
end sub

