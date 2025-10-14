sub Init()
    m.recentlyActiveGrid = m.top.findNode("recentlyActiveGrid")
    m.allChannelsGrid = m.top.findNode("allChannelsGrid")
    m.loadingText = m.top.findNode("loadingText")
    m.confirmationOverlay = m.top.findNode("confirmationOverlay")
    m.confirmationDialog = m.top.findNode("confirmationDialog")
    m.confirmationMessage = m.top.findNode("confirmationMessage")

    m.recentlyActiveGrid.observeField("rowItemSelected", "onRecentChannelSelected")
    m.recentlyActiveGrid.observeField("rowItemFocused", "onRecentItemFocused")
    m.allChannelsGrid.observeField("rowItemSelected", "onAllChannelSelected")
    m.allChannelsGrid.observeField("rowItemFocused", "onAllChannelsFocused")

    m.currentPage = 1
    m.loadingMore = false
    m.hasMoreChannels = true
    m.loadingStarted = false

    m.focusedSection = "recent" ' "recent" or "all"
    m.showingConfirmation = false
    m.pendingUnfollowChannel = invalid

    m.top.observeField("channels", "loadChannels")
    m.top.observeField("constants", "loadChannels")
    m.top.observeField("uid", "loadChannels")
    m.top.observeField("restoreFocus", "onRestoreFocus")
end sub

sub onChannelsChanged()
    ' Reload when channels array is updated (after unfollow)
    print "[FollowedChannels] onChannelsChanged - loadingStarted: "; m.loadingStarted
    if m.loadingStarted = true
        ' Reset and reload
        print "[FollowedChannels] Reloading channels after unfollow"
        m.loadingStarted = false
        m.currentPage = 1
        m.needsRefocus = true ' Flag to restore focus after reload
        loadChannels()
    end if
end sub

sub onReloadRequested()
    ' Force reload of channels
    m.loadingStarted = false
    m.currentPage = 1
    loadChannels()
end sub

sub loadChannels()
    if not IsValid(m.top.channels) or m.top.channels.Count() = 0
        m.loadingText.text = "You are not following any channels yet."
        m.loadingText.visible = true
        m.recentlyActiveGrid.visible = false
        m.allChannelsGrid.visible = false
        return
    end if

    ' Wait for constants to be set before fetching
    if not IsValid(m.top.constants) or not IsValid(m.top.uid)
        ' Constants not ready yet, they will trigger another load when set
        return
    end if

    ' Reset loading state to allow reload when channels change
    m.loadingStarted = false
    m.currentPage = 1
    m.loadingMore = false

    ' Set loading flag
    m.loadingStarted = true
    m.loadingText.visible = true

    ' Fetch recently active channels
    fetchRecentlyActive()

    ' Fetch first page of all channels
    fetchAllChannels(1)
end sub

sub fetchRecentlyActive()
    task = CreateObject("roSGNode", "getFollowedChannels")
    task.setFields({
        constants: m.top.constants,
        channels: m.top.channels,
        uid: m.top.uid,
        mode: "recent_active"
    })
    task.observeField("output", "onRecentlyActiveLoaded")
    task.control = "RUN"
end sub

sub onRecentlyActiveLoaded(msg as object)
    task = msg.getRoSGNode()
    result = task.output

    print "[FollowedChannels] Recently active loaded, result: "; result

    if IsValid(result) and IsValid(result.channels)
        channelCount = result.channels.Count()
        print "[FollowedChannels] Recently active channel count: "; channelCount

        ' Build content for RowList (2 rows of 4 channels each)
        content = CreateObject("roSGNode", "ContentNode")

        ' Create first row (first 4 channels)
        row1 = content.createChild("ContentNode")
        for i = 0 to 3
            if i < channelCount
                ch = result.channels[i]
                node = row1.createChild("ContentNode")
                node.title = ch.channelTitle
                node.addFields({
                    channelId: ch.channelId,
                    channelName: ch.channelName,
                    channelThumb: ch.channelThumb,
                    videoCount: ch.videoCount
                })
            end if
        end for

        ' Create second row only if there are more than 4 channels
        if channelCount > 4
            row2 = content.createChild("ContentNode")
            for i = 4 to 7
                if i < channelCount
                    ch = result.channels[i]
                    node = row2.createChild("ContentNode")
                    node.title = ch.channelTitle
                    node.addFields({
                        channelId: ch.channelId,
                        channelName: ch.channelName,
                        channelThumb: ch.channelThumb,
                        videoCount: ch.videoCount
                    })
                end if
            end for
        end if

        m.recentlyActiveGrid.content = content
        print "[FollowedChannels] Recently active grid content set with 2 rows"
    else
        print "[FollowedChannels] Recently active: Invalid result or no channels"
    end if

    task.unobserveField("output")
    task.control = "STOP"

    ' Hide loading once both sections are loaded
    checkLoadingComplete()
end sub

sub fetchAllChannels(page as integer)
    if m.loadingMore then return
    m.loadingMore = true

    task = CreateObject("roSGNode", "getFollowedChannels")
    task.setFields({
        constants: m.top.constants,
        channels: m.top.channels,
        uid: m.top.uid,
        mode: "all",
        page: page
    })
    task.observeField("output", "onAllChannelsLoaded")
    task.control = "RUN"
end sub

sub onAllChannelsLoaded(msg as object)
    task = msg.getRoSGNode()
    result = task.output

    if IsValid(result) and IsValid(result.channels)
        ' Build content for RowList (up to 10 channels, arranged in rows of 4)
        if m.currentPage = 1
            ' First page - create new content
            m.allChannelsContent = CreateObject("roSGNode", "ContentNode")
            m.allChannelsGrid.content = m.allChannelsContent
        end if

        ' Add channels to rows (4 per row)
        currentRow = invalid
        if m.allChannelsContent.getChildCount() > 0
            currentRow = m.allChannelsContent.getChild(m.allChannelsContent.getChildCount() - 1)
        end if

        for each ch in result.channels
            ' Create new row if needed
            if not IsValid(currentRow) or currentRow.getChildCount() >= 4
                currentRow = CreateObject("roSGNode", "ContentNode")
                m.allChannelsContent.appendChild(currentRow)
            end if

            node = CreateObject("roSGNode", "ContentNode")
            node.title = ch.channelTitle
            node.addFields({
                channelId: ch.channelId,
                channelName: ch.channelName,
                channelThumb: ch.channelThumb,
                videoCount: ch.videoCount
            })

            currentRow.appendChild(node)
        end for

        m.hasMoreChannels = result.hasMore
    end if

    m.loadingMore = false
    task.unobserveField("output")
    task.control = "STOP"

    ' Hide loading once both sections are loaded
    checkLoadingComplete()
end sub

sub checkLoadingComplete()
    ' Hide loading text once we have content
    if IsValid(m.recentlyActiveGrid.content) and IsValid(m.allChannelsGrid.content)
        m.loadingText.visible = false

        ' Check which grids have content
        recentHasContent = m.recentlyActiveGrid.content.getChildCount() > 0
        allHasContent = m.allChannelsGrid.content.getChildCount() > 0

        ' Restore focus to appropriate grid, falling back if empty
        if m.focusedSection = "all" and allHasContent
            m.allChannelsGrid.setFocus(true)
            m.allChannelsGrid.jumpToRowItem = [0, 0]
        else if recentHasContent
            m.recentlyActiveGrid.setFocus(true)
            m.recentlyActiveGrid.jumpToRowItem = [0, 0]
            m.focusedSection = "recent"
        else if allHasContent
            m.allChannelsGrid.setFocus(true)
            m.allChannelsGrid.jumpToRowItem = [0, 0]
            m.focusedSection = "all"
        else
            ' Both grids empty - set focus to scene itself
            m.top.setFocus(true)
        end if

        print "[FollowedChannels] Loading complete, focus restored to: "; m.focusedSection
    end if
end sub

sub onAllChannelsFocused()
    ' Track which section has focus
    m.focusedSection = "all"

    focusPos = m.allChannelsGrid.rowItemFocused
    if not IsValid(focusPos) or focusPos.Count() < 2 then return

    row = focusPos[0]
    totalRows = m.allChannelsContent.getChildCount()

    ' Load more when user reaches last 2 rows
    if row >= (totalRows - 2) and m.hasMoreChannels and not m.loadingMore
        m.currentPage = m.currentPage + 1
        fetchAllChannels(m.currentPage)
    end if
end sub

sub onRecentItemFocused()
    ' Track which section has focus
    m.focusedSection = "recent"
end sub

sub onRecentChannelSelected()
    ' Ignore selection if confirmation dialog is showing
    if m.showingConfirmation then return

    selected = m.recentlyActiveGrid.rowItemSelected
    if not IsValid(selected) or selected.Count() < 2 then return

    row = selected[0]
    col = selected[1]

    content = m.recentlyActiveGrid.content
    if IsValid(content)
        rowNode = content.getChild(row)
        if IsValid(rowNode)
            channelNode = rowNode.getChild(col)
            if IsValid(channelNode)
                m.top.selectedChannel = {
                    channelId: channelNode.channelId,
                    channelName: channelNode.channelName
                }
            end if
        end if
    end if
end sub

sub onAllChannelSelected()
    ' Ignore selection if confirmation dialog is showing
    if m.showingConfirmation then return

    selected = m.allChannelsGrid.rowItemSelected
    if not IsValid(selected) or selected.Count() < 2 then return

    row = selected[0]
    col = selected[1]

    content = m.allChannelsGrid.content
    if IsValid(content)
        rowNode = content.getChild(row)
        if IsValid(rowNode)
            channelNode = rowNode.getChild(col)
            if IsValid(channelNode)
                m.top.selectedChannel = {
                    channelId: channelNode.channelId,
                    channelName: channelNode.channelName
                }
            end if
        end if
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false

    ' Handle confirmation dialog keys
    if m.showingConfirmation
        if key = "OK"
            ' Confirm unfollow
            print "[FollowedChannels] OK pressed on confirmation, unfollowing: "; m.pendingUnfollowChannel.channelName
            if IsValid(m.pendingUnfollowChannel)
                ' Send unfollow request to parent (HomeScene)
                m.top.unfollowRequest = m.pendingUnfollowChannel
                print "[FollowedChannels] Sent unfollowRequest to HomeScene"
                m.pendingUnfollowChannel = invalid
            end if
            hideConfirmation()
            return true
        else if key = "back"
            ' Cancel unfollow
            hideConfirmation()
            return true
        end if
        return true ' Block all other keys when confirmation is showing
    end if

    if key = "*" or key = "options"
        ' Show unfollow confirmation for currently focused channel
        showUnfollowConfirmation()
        return true
    else if key = "back"
        ' If not at top, jump to top of Recently Active
        if m.focusedSection = "all" or (m.focusedSection = "recent" and m.recentlyActiveGrid.rowItemFocused[0] <> 0) or (m.focusedSection = "recent" and m.recentlyActiveGrid.rowItemFocused[1] <> 0)
            m.recentlyActiveGrid.setFocus(true)
            m.recentlyActiveGrid.jumpToRowItem = [0, 0]
            m.focusedSection = "recent"
            return true
        end if
        ' Already at top, let parent handle exit
        return false
    else if key = "right"
        ' Block right navigation when at last item in row
        if m.focusedSection = "recent"
            focusPos = m.recentlyActiveGrid.rowItemFocused
            if IsValid(focusPos) and focusPos.Count() >= 2
                row = focusPos[0]
                col = focusPos[1]
                ' Check how many items are in this row
                content = m.recentlyActiveGrid.content
                if IsValid(content)
                    rowNode = content.getChild(row)
                    if IsValid(rowNode)
                        itemCount = rowNode.getChildCount()
                        ' Block if at last item in row
                        if col >= itemCount - 1
                            return true
                        end if
                    end if
                end if
            end if
        else if m.focusedSection = "all"
            focusPos = m.allChannelsGrid.rowItemFocused
            if IsValid(focusPos) and focusPos.Count() >= 2
                row = focusPos[0]
                col = focusPos[1]
                ' Check how many items are in this row
                content = m.allChannelsGrid.content
                if IsValid(content)
                    rowNode = content.getChild(row)
                    if IsValid(rowNode)
                        itemCount = rowNode.getChildCount()
                        ' Block if at last item in row
                        if col >= itemCount - 1
                            return true
                        end if
                    end if
                end if
            end if
        end if
    else if key = "left"
        ' Block left navigation when at leftmost column (column 0)
        if m.focusedSection = "recent"
            focusPos = m.recentlyActiveGrid.rowItemFocused
            if IsValid(focusPos) and focusPos.Count() >= 2 and focusPos[1] = 0
                return true
            end if
        else if m.focusedSection = "all"
            focusPos = m.allChannelsGrid.rowItemFocused
            if IsValid(focusPos) and focusPos.Count() >= 2 and focusPos[1] = 0
                return true
            end if
        end if
    else if key = "up"
        if m.focusedSection = "recent"
            ' Block up navigation at top row
            focusPos = m.recentlyActiveGrid.rowItemFocused
            if IsValid(focusPos) and focusPos[0] = 0
                return true
            end if
        else if m.focusedSection = "all"
            ' Always move to Recently Active when pressing up in All Channels
            ' Block backward scrolling within All Channels section
            focusPos = m.allChannelsGrid.rowItemFocused
            if IsValid(focusPos)
                m.allChannelsGrid.setFocus(false)
                m.recentlyActiveGrid.setFocus(true)
                ' Jump to bottom row, same column
                targetCol = focusPos[1]
                if targetCol >= 0 and targetCol < 4
                    m.recentlyActiveGrid.jumpToRowItem = [1, targetCol]
                end if
                m.focusedSection = "recent"
                return true
            end if
        end if
    else if key = "down"
        if m.focusedSection = "recent"
            ' Move to All Channels when at bottom row of Recently Active
            focusPos = m.recentlyActiveGrid.rowItemFocused
            if IsValid(focusPos)
                currentRow = focusPos[0]
                ' Check if at last row
                content = m.recentlyActiveGrid.content
                if IsValid(content)
                    totalRows = content.getChildCount()
                    if currentRow >= totalRows - 1
                        ' At last row, move to All Channels
                        m.recentlyActiveGrid.setFocus(false)
                        m.allChannelsGrid.setFocus(true)
                        ' Jump to top row, same column
                        targetCol = focusPos[1]
                        if targetCol >= 0 and targetCol < 4
                            m.allChannelsGrid.jumpToRowItem = [0, targetCol]
                        end if
                        m.focusedSection = "all"
                        return true
                    end if
                end if
            end if
        end if
    end if

    return false
end function

sub onRestoreFocus()
    ' Restore focus to the appropriate grid based on last focused section
    print "[FollowedChannels] Restoring focus to section: "; m.focusedSection
    if m.focusedSection = "all"
        m.allChannelsGrid.setFocus(true)
    else
        m.recentlyActiveGrid.setFocus(true)
    end if
end sub

sub showUnfollowConfirmation()
    ' Get currently focused channel
    channelData = getCurrentFocusedChannel()
    if not IsValid(channelData) then return

    m.pendingUnfollowChannel = channelData

    ' Update confirmation message with channel name
    m.confirmationMessage.text = "Are you sure you want to unfollow " + channelData.channelName + "?"

    ' Remove focus from grids and give focus to the scene itself
    m.recentlyActiveGrid.setFocus(false)
    m.allChannelsGrid.setFocus(false)
    m.top.setFocus(true)

    ' Show confirmation dialog
    m.confirmationOverlay.visible = true
    m.confirmationDialog.visible = true
    m.showingConfirmation = true

    print "[FollowedChannels] Showing unfollow confirmation for: "; channelData.channelName
end sub

sub hideConfirmation()
    m.confirmationOverlay.visible = false
    m.confirmationDialog.visible = false
    m.showingConfirmation = false
    m.pendingUnfollowChannel = invalid

    ' Restore focus to the appropriate grid
    if m.focusedSection = "all"
        m.allChannelsGrid.setFocus(true)
    else
        m.recentlyActiveGrid.setFocus(true)
    end if
end sub

function getCurrentFocusedChannel() as object
    ' Get the currently focused channel from whichever grid has focus
    if m.focusedSection = "recent"
        focusPos = m.recentlyActiveGrid.rowItemFocused
        if IsValid(focusPos) and focusPos.Count() >= 2
            content = m.recentlyActiveGrid.content
            if IsValid(content)
                rowNode = content.getChild(focusPos[0])
                if IsValid(rowNode)
                    channelNode = rowNode.getChild(focusPos[1])
                    if IsValid(channelNode)
                        return {
                            channelId: channelNode.channelId,
                            channelName: channelNode.channelName
                        }
                    end if
                end if
            end if
        end if
    else if m.focusedSection = "all"
        focusPos = m.allChannelsGrid.rowItemFocused
        if IsValid(focusPos) and focusPos.Count() >= 2
            content = m.allChannelsGrid.content
            if IsValid(content)
                rowNode = content.getChild(focusPos[0])
                if IsValid(rowNode)
                    channelNode = rowNode.getChild(focusPos[1])
                    if IsValid(channelNode)
                        return {
                            channelId: channelNode.channelId,
                            channelName: channelNode.channelName
                        }
                    end if
                end if
            end if
        end if
    end if

    return invalid
end function
