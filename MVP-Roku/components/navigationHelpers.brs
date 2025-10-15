' ============================================
' Navigation State Management Functions
' These are integrated with HomeScene to manage
' scroll position and sidebar highlighting persistence
' ============================================

' Get a unique key for the current view context
function getCurrentViewKey() as string
  key = ""

  ' Determine the current context
  if m.searchActive = true
    if m.searchContext = "video"
      key = "search_video"
    else if m.searchContext = "channel"
      key = "search_channel"
    else
      key = "search"
    end if
  else if IsValid(m.currentChannelId) and m.currentChannelId <> ""
    key = "channel_" + m.currentChannelId
  else if IsValid(m.categorySelector) and IsValid(m.categorySelector.itemFocused)
    catIndex = m.categorySelector.itemFocused
    if catIndex = 0
      key = "search_ui"
    else if catIndex = 1
      key = "favorites"
    else if catIndex >= 0 and IsValid(m.categorySelectorData) and catIndex < m.categorySelectorData.Count()
      catData = m.categorySelectorData[catIndex]
      if IsValid(catData) and IsValid(catData.trueName)
        key = "category_" + catData.trueName
      else
        key = "category_" + catIndex.ToStr()
      end if
    end if
  end if

  if key = "" then key = "default"
  return key
end function

' Save the current grid position for the current view
sub saveCategoryPosition(row as integer, col as integer)
  if not IsValid(m.categoryPositions) then m.categoryPositions = {}
  key = getCurrentViewKey()
  if key <> ""
    m.categoryPositions[key] = [row, col]
    ?"[NAV] Saved position for " + key + ": [" + row.ToStr() + ", " + col.ToStr() + "]"
  end if
end sub

' Restore the saved grid position for the current view
function restoreCategoryPosition() as object
  if not IsValid(m.categoryPositions) then m.categoryPositions = {}
  key = getCurrentViewKey()

  if IsValid(m.categoryPositions[key])
    posi = m.categoryPositions[key]
    if Type(posi) = "roArray" and posi.Count() >= 2
      ?"[NAV] Restored position for " + key + ": [" + posi[0].ToStr() + ", " + posi[1].ToStr() + "]"
      return posi
    end if
  end if

  ?"[NAV] No saved position for " + key + ", using default [0, 0]"
  return [0, 0]
end function

' Restore focus to the grid at the saved position
sub restoreGridFocus()
  if not IsValid(m.videoGrid) then return

  posi = restoreCategoryPosition()
  if IsValid(posi) and Type(posi) = "roArray" and posi.Count() >= 2
    row = posi[0]
    col = posi[1]

    ' Validate the position is within bounds
    if IsValid(m.videoGrid.content)
      maxRows = m.videoGrid.content.getChildCount()
      if row >= maxRows then row = maxRows - 1
      if row < 0 then row = 0

      if row < maxRows
        rowNode = m.videoGrid.content.getChild(row)
        if IsValid(rowNode)
          maxCols = rowNode.getChildCount()
          if col >= maxCols then col = maxCols - 1
          if col < 0 then col = 0
        end if
      end if
    end if

    ' Set the flag to prevent saving this restored position
    m.isReturningToCategory = true

    ' Jump to the saved position
    try
      m.videoGrid.jumpToRowItem = [row, col]
      ?"[NAV] Jumped to position: [" + row.ToStr() + ", " + col.ToStr() + "]"
    catch e
      ?"[NAV] Error jumping to position"
    end try
  end if
end sub