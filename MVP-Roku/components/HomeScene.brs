' Safe seek helper: clamps to [0, totalLen]
sub safeSeek(newPos as integer)
  if not IsValid(m.video) then return
  totalLen = getCurrentContentLength()
  if newPos < 0 then newPos = 0
  if totalLen > 0 and newPos > totalLen then newPos = totalLen
  try
    m.video.seek = newPos
    m.lastKnownVideoPos = newPos
  catch e
  end try
end sub

function getCurrentContentLength() as integer
  duration = 0
  if IsValid(m.video)
    try: duration = m.video.duration : catch e: duration = 0 : end try
  end if
  if duration <= 0 and IsValid(m.urlResolver)
    if IsValid(m.urlResolver.output)
      try: duration = m.urlResolver.output.length : catch e: duration = 0 : end try
    end if
  end if
  return duration
end function

sub resetProgressUI(totalLen as integer)
  if IsValid(m.videoProgressBar) then m.videoProgressBar.width = 0
  if IsValid(m.videoProgressBarp1) then m.videoProgressBarp1.text = getvideoLength(0)
  if IsValid(m.videoProgressBarp2)
    if totalLen > 0
      m.videoProgressBarp2.text = getvideoLength(totalLen)
    else
      m.videoProgressBarp2.text = "--:--"
    end if
  end if
  m.scrubTarget = 0
end sub


' Skip helpers for fast-forward/rewind buttons
sub skipVideo(delta as integer)
  if not IsValid(m.video) then return
  if not IsValid(m.videoContent) or m.videoContent.Live then return

  cur = 0
  if IsValid(m.scrubTarget) then cur = m.scrubTarget
  if IsValid(m.lastKnownVideoPos) and cur = 0 then cur = m.lastKnownVideoPos
  if cur < 0 then cur = 0
  if cur = 0 then
    try
      cur = m.video.position
    catch e
      cur = 0
    end try
  end if

  target = cur + delta
  totalLen = getCurrentContentLength()
  if totalLen > 0 then
    if target < 0 then target = 0
    if target > totalLen then target = totalLen
  else
    if target < 0 then target = 0
  end if
  if target = cur then return

  safeSeek(target)
  m.scrubTarget = target
  updateScrubUI()
end sub

' Return index of a control-bar item by its itemID; -1 if not found
function findVideoButtonIndexById(targetId as string) as integer
  if not IsValid(m.videoButtons) then return -1
  if not IsValid(m.videoButtons.content) then return -1
  total = m.videoButtons.content.getChildCount()
  for i = 0 to total - 1
    child = m.videoButtons.content.getChild(i)
    if IsValid(child) and IsValid(child.itemID)
      if child.itemID = targetId then return i
    end if
  end for
  return -1
end function

' Compute best index to keep active on control bar
function getPreferredVideoButtonsIndex() as integer
  idx = -1
  ' Prefer last known
  t = Type(m.videoButtonsLastIndex)
  if (t = "roInt" or t = "Integer") and m.videoButtonsLastIndex >= 0 then idx = m.videoButtonsLastIndex
  if idx < 0 then idx = findVideoButtonIndexById("playPause")
  if idx < 0 then idx = findVideoButtonIndexById("restart")
  if idx < 0 then idx = 0
  return idx
end function

' Return true if the control bar currently has focus
function isVideoButtonsFocused() as boolean
  has = false
  if IsValid(m.videoButtons)
    try
      has = m.videoButtons.hasFocus()
    catch e
      has = false
    end try
  end if
  return has
end function

' Select a control bar item index without changing focus ownership
sub selectVideoButtonIndex(index as integer)
  if not IsValid(m.videoButtons) then return
  total = -1
  if IsValid(m.videoButtons.content) then total = m.videoButtons.content.getChildCount()
  if total <= 0 then return
  if index >= total then index = total - 1
  if index < 0 then index = 0
  try: m.videoButtons.jumpToItem = index : catch e: end try
  m.videoButtonsLastIndex = index
  if IsValid(m.videoButtons.content)
    if index >= 0 and index < total
      node = m.videoButtons.content.getChild(index)
      if IsValid(node) and IsValid(node.itemID)
        m.videoButtonSelected = node.itemID
      end if
    end if
  end if
end sub

' Ensure we have a sane default focused index on the control bar
sub ensureDefaultVideoButtonsIndex()
  if not IsValid(m.videoButtons) then return
  if not IsValid(m.videoButtons.content) then return
  idx = findVideoButtonIndexById("playPause")
  if idx < 0 then idx = findVideoButtonIndexById("restart")
  if idx < 0 then idx = 0
  m.videoButtonsLastIndex = idx
end sub

sub updatePlaybackRateButtonLabel(label as string)
  if IsValid(m.standardButtonsLoggedIn)
    for i = 0 to m.standardButtonsLoggedIn.Count() - 1
      if m.standardButtonsLoggedIn[i].itemID = "playbackRate"
        m.standardButtonsLoggedIn[i].item = label
      end if
    end for
  end if
  if IsValid(m.standardButtonsLoggedOut)
    for i = 0 to m.standardButtonsLoggedOut.Count() - 1
      if m.standardButtonsLoggedOut[i].itemID = "playbackRate"
        m.standardButtonsLoggedOut[i].item = label
      end if
    end for
  end if
end sub

sub updatePlaybackRateUI(label as string)
  if IsValid(m.videoButtonsRate)
    m.videoButtonsRate.labelText = label
  end if
  info = captureVideoButtonsFocus()
  if info.hadFocus and info.index >= 0 then
    restoreVideoButtonFocus(info.index)
  end if
end sub

sub setPlaybackRateByIndex(index as integer)
  if not IsValid(m.playbackRateValues) or not IsValid(m.playbackRateLabels) then return
  if index < 0 or index >= m.playbackRateValues.Count() then return
  m.playbackRateIndex = index
  m.playbackRate = m.playbackRateValues[index]
  ? "[RATE] set index=" + m.playbackRateIndex.ToStr() + " speed=" + m.playbackRate.ToStr()
  label = m.playbackRateLabels[index]
  updatePlaybackRateButtonLabel(label)
  updatePlaybackRateUI(label)
  ' Mark that this change came from user action so we can force-apply while playing
  m.rateChangePending = true
  applyPlaybackRate()
end sub

sub cyclePlaybackRate()
  if not IsValid(m.playbackRateValues) then return
  nextIndex = (m.playbackRateIndex + 1) mod m.playbackRateValues.Count()
  info = captureVideoButtonsFocus()
  focusIndex = info.index
  try: ? "[RATE] cycle focus index before=" + Str(focusIndex) : catch e: end try
  setPlaybackRateByIndex(nextIndex)
  if IsValid(m.videoButtons) then
    ' Keep controls selection, but do not force focus away from Video here
    ' m.videoButtons.setFocus(true)
    if focusIndex >= 0 then
      try: m.videoButtons.jumpToItem = focusIndex : catch e: end try
    end if
  end if
  restoreVideoButtonFocus(focusIndex)
end sub

sub restoreVideoButtonFocus(index as integer)
  if not IsValid(m.videoButtons) then return
  if not IsValid(m.videoOverlayGroup) or not m.videoOverlayGroup.visible then return
  if not m.video.visible then return

  ' While forcibly restoring focus, don't allow itemFocused to change selection
  m.blockVideoButtonsFocusEvents = true
  if index < 0 then index = m.videoButtonsLastIndex
  if index < 0 then index = 0
  total = -1
  if IsValid(m.videoButtons.content) then total = m.videoButtons.content.getChildCount()
  if total <= 0 then
    try: m.video.setFocus(true) : catch e: end try
    m.blockVideoButtonsFocusEvents = false
    return
  end if
  if index >= total then index = total - 1
  if index < 0 then index = 0
  ' Set selection and ensure MarkupGrid has focus so arrows work
  try: m.videoButtons.setFocus(true) : catch e: end try
  try: m.videoButtons.jumpToItem = index : catch e: end try
  m.videoButtonsLastIndex = index
  ' Sync selected id so OK works immediately, even with focus events suppressed
  selNode = invalid
  if IsValid(m.videoButtons.content) and index >= 0 and index < total
    selNode = m.videoButtons.content.getChild(index)
    if IsValid(selNode) and IsValid(selNode.itemID)
      m.videoButtonSelected = selNode.itemID
    end if
  end if
  ' Allow subsequent itemFocused events
  m.blockVideoButtonsFocusEvents = false
end sub

sub applyPlaybackRate()
  if not IsValid(m.video) then return
  hasSpeed = false
  try: hasSpeed = m.video.doesExist("playbackSpeed") : catch e: hasSpeed = false : end try
  desired = m.playbackRate
  if desired <= 0 then desired = 1.0
  live = IsValid(m.videoContent) and m.videoContent.Live
  if live then desired = 1.0
  liveStr = "false"
  if live then liveStr = "true"
  availStr = "false"
  if hasSpeed then availStr = "true"
  ? "[RATE] apply request speed=" + desired.ToStr() + " live=" + liveStr
  ? "[RATE] playbackSpeed available? " + availStr
  if not hasSpeed then
    if not m.playbackRateFieldsLogged then
      m.playbackRateFieldsLogged = true
      ? "[RATE] video node lacks playbackSpeed field"
    end if
    return
  end if
  try
    m.video.playbackSpeed = desired
    actual = desired
    try: actual = m.video.playbackSpeed : catch err: actual = desired : end try
    ? "[RATE] playbackSpeed set, current=" + actual.ToStr()

    ' Force the new rate to take effect immediately if we're currently playing
    ' Some Roku builds only apply playbackSpeed changes on a play/resume boundary
    stateNow = ""
    try: stateNow = m.video.state : catch e: stateNow = "" : end try
    if m.rateChangePending = true and stateNow = "playing" then
      try
        m.video.control = "pause"
        m.video.control = "resume"
      catch e
      end try
      m.rateChangePending = false
    end if
  catch err
    ? "[RATE] failed to set playbackSpeed"
  end try
end sub

' Insert a single placeholder row (4 tiles) that will pulse while loading
sub ensureLoadingPlaceholderRow()
  if not IsValid(m.videoGrid) or not IsValid(m.videoGrid.content) then return
  dest = m.videoGrid.content
  ' If last row already a placeholder row, keep it
  if dest.getChildCount() > 0
    last = dest.getChild(dest.getChildCount()-1)
    if IsValid(last) and last.getChildCount() > 0
      firstNode = last.getChild(0)
      if IsValid(firstNode) and IsValid(firstNode.itemType) and LCase(firstNode.itemType) = "placeholder" then return
    end if
  end if
  row = CreateObject("roSGNode","ContentNode")
  for i = 0 to 3
    n = CreateObject("roSGNode","ContentNode")
    n.addFields({ itemType: "placeholder", HDPOSTERURL: "pkg:/images/placeholder1x1.png", TITLE: "", CREATOR: "", RELEASEDATE: "" })
    row.appendChild(n)
  end for
  dest.appendChild(row)
end sub

' Remove a trailing placeholder row if present
sub clearLoadingPlaceholderRow()
  if not IsValid(m.videoGrid) or not IsValid(m.videoGrid.content) then return
  dest = m.videoGrid.content
  if dest.getChildCount() = 0 then return
  last = dest.getChild(dest.getChildCount()-1)
  if not IsValid(last) or last.getChildCount() = 0 then return
  firstNode = last.getChild(0)
  if IsValid(firstNode) and IsValid(firstNode.itemType) and LCase(firstNode.itemType) = "placeholder" then
    ' Remove entire row
    dest.removeChildIndex(dest.getChildCount()-1)
  end if
end sub

' Update progress bar/labels to reflect current scrub target without seeking
sub updateScrubUI()
  if not IsValid(m.videoOverlayGroup) then return
  totalLen = getCurrentContentLength()
  if totalLen <= 0 then return
  if IsValid(m.videoProgressBar)
    if m.scrubTarget > 0
      m.videoProgressBar.width = 1290 * (m.scrubTarget / totalLen)
    else
      m.videoProgressBar.width = 0
    end if
  end if
  if IsValid(m.videoProgressBarp1)
    m.videoProgressBarp1.text = getvideoLength(m.scrubTarget)
  end if
  if IsValid(m.videoProgressBarp2)
    remaining = totalLen - m.scrubTarget
    if remaining < 0 then remaining = 0
    m.videoProgressBarp2.text = getvideoLength(remaining)
  end if
end sub

function captureVideoButtonsFocus() as object
  info = { index: -1, hadFocus: false }
  if not IsValid(m.videoButtons) then return info
  try: info.hadFocus = m.videoButtons.hasFocus() : catch e: info.hadFocus = false : end try
  if info.hadFocus then
    overlayVisible = false
    if IsValid(m.videoOverlayGroup) then overlayVisible = m.videoOverlayGroup.visible
    if not overlayVisible then info.hadFocus = false
  end if
  focusVal = invalid
  try: focusVal = m.videoButtons.itemFocused : catch e: focusVal = invalid : end try
  if Type(focusVal) = "roInt" or Type(focusVal) = "Integer" then
    info.index = focusVal
  else if Type(focusVal) = "roArray" and focusVal.Count() > 1 then
    info.index = focusVal[1]
  end if
  btnType = Type(m.videoButtonsLastIndex)
  if info.index < 0 and (btnType = "roInt" or btnType = "Integer") and m.videoButtonsLastIndex >= 0 then info.index = m.videoButtonsLastIndex
  return info
end function

sub restartCurrentVideo()
  if not IsValid(m.video) then return
  if not m.video.visible then return
  if not IsValid(m.videoContent) or m.videoContent.Live then return
  ' Normalize state around restart to ensure seek is honored across firmware variants
  try: m.video.control = "pause" : catch e: end try
  safeSeek(0)
  m.scrubTarget = 0
  updateScrubUI()
  ' Clear any FF/RW transition state
  m.videoTransitionState = 0
  ' Resume if we were playing before
  stateNow = ""
  try: stateNow = m.video.state : catch e: stateNow = "" : end try
  if stateNow = "paused" or stateNow = "buffering" or stateNow = "playing"
    try: m.video.control = "resume" : catch e: end try
  end if
  showVideoOverlay()
  if isValid(m.currentVideoClaimID)
    resumeKey = "resume-" + m.currentVideoClaimID
    SetRegistry("resumeRegistry", resumeKey, "0")
  end if
end sub

' Skip from control bar without changing selection/focus
function skipFromControlBar(dir as integer) as void
  if not IsValid(m.video) then return
  if not IsValid(m.videoContent) or m.videoContent.Live then return
  info = captureVideoButtonsFocus()
  focusIdx = info.index
  ' Prevent any focus-changed side-effects
  m.blockVideoButtonsFocusEvents = true
  ' Keep overlay visible; preserve button focus
  showVideoOverlay(true)
  if dir > 0 then
    skipVideo(m.skipStep)
  else if dir < 0 then
    skipVideo(-m.skipStep)
  end if
  if focusIdx >= 0 then restoreVideoButtonFocus(focusIdx)
  m.blockVideoButtonsFocusEvents = false
end function

' Find [row, col] of an item in the current grid by its guid; returns invalid if not found
function findGridIndexByGuid(targetGuid as string) as object
  if not IsValid(m.videoGrid) or not IsValid(m.videoGrid.content) then return invalid
  if not IsValid(targetGuid) or targetGuid = "" then return invalid
  rows = m.videoGrid.content.getChildCount()
  for r = 0 to rows - 1
    rowNode = m.videoGrid.content.getChild(r)
    if IsValid(rowNode)
      cols = rowNode.getChildCount()
      for c = 0 to cols - 1
        item = rowNode.getChild(c)
        if IsValid(item) and IsValid(item.guid)
          if item.guid = targetGuid then return [r, c]
        end if
      end for
    end if
  end for
  return invalid
end function
sub init()
  'IF EVERYTHING IS BROKEN:
  'TODO: instr expects 3 arguements instead of 2. API docs change or actual OS change?
  m.appTimer = CreateObject("roTimeSpan")
  m.appTimer.Mark()
  m.maxThreads = 50
  m.runningThreads = []
  m.threads = []
  m.threadsToDelete = []
  m.threaderRunning = false
  'UI Logic/State Variables
  m.loaded = False 'Has the app finished its first load?
  m.favoritesLoaded = false 'Were favorites loaded?(init only)
  m.favoritesUIFlag = true 'Is a post-init favorites transition allowed?
  m.legacyAuthenticated = False 'Has the app passed phase 0 of authentication?
  m.wasLoggedIn = false 'Was the app logged into a valid Odysee account?
  m.taskRunning = False 'Should we avoid UI transitions because of a running search/task?
  m.videoEndingTimeSet = false 'Did we set the ending time in seconds on the video?
  m.videoTransitionState = 0 '0=None, -1=Rewind, 1=FastForward....
  m.videoTransitionStateLimit = 5 'How many times does the user have to press RW/FF before coarse scrubbing?
  m.videoVP = 0 'Virtual Video Position for ff/rw, because video's position doesn't change until the video has buffered.
  m.scrubTarget = 0
  m.skipHoldDirection = 0
  m.skipHoldCount = 0
  m.videoButtonsLastIndex = -1
  ' One-shot suppression of a following LEFT/RIGHT that some remotes emit with FF/RW
  m.swallowNavKey = ""
  ' Prevent control bar focus from jumping on FF/RW (while true, ignore itemFocused events)
  m.blockVideoButtonsFocusEvents = false
  m.videoButtonsIndexBeforeSkip = -1
  m.focusedItem = 1 '[selector]  'actually, this works better than what I was doing before.
  m.searchType = "channel" 'changed to either video or channel
  m.searchKeyboardItemArray = [5, 11, 17, 23, 29, 35, 38] ' Corresponds to a MiniKeyboard's rightmost items. Used for transition.
  m.uiLayer = 0 '0=Base (Channel Grid/Search), 1=First search layer, 2=Second search layer
  m.uiLayers = [] 'directly correlates with m.uiLayer-1. Layer 0 is managed by the sidebar/categorySelector.
  m.reinitialize = true
  m.videoButtonSelected = "none"
  m.searchKeyboardCanTransition = false 'searchKeyboard can transition after confirmation if true
  m.moveAttemptsRow = 0 'searchKeyboard double press confirmation
  m.lastKnownVideoPos = 0
  m.playbackRateFieldsLogged = false
  m.rateChangePending = false

  'UI Items
  m.errorText = m.top.findNode("warningtext")
  m.errorSubtext = m.top.findNode("warningsubtext")
  m.errorButton = m.top.findNode("warningbutton")
  m.loadingText = m.top.findNode("loadingtext")
  m.loadingBackground = m.top.findNode("loadingbackground")
  m.header = m.top.findNode("headerrectangle")
  m.chatBox = m.top.findNode("ChatBox")
  m.superChatBox = m.top.findNode("SuperChatBox")
  m.sidebarTrim = m.top.findNode("sidebartrim")
  m.sidebarBackground = m.top.findNode("sidebarbackground")
  m.channelSidebarThumb = m.top.findNode("channelSidebarThumb")
  m.chatBackground = m.top.findNode("chatBackground")
  m.superChatBackground = m.top.findNode("SuperChatBackground")
  m.odyseeLogo = m.top.findNode("odyseelogo")
  m.video = m.top.findNode("Video")
  try: m.video.seekMode = "accurate" : catch e: end try
  m.videoContent = createObject("roSGNode", "ContentNode")
  m.videoGrid = m.top.findNode("vgrid")
  m.videoGrid.observeField("rowItemFocused", "onRowItemFocused")
  m.currentCategoryPage = {}
  m.loadingNextPage = {}
  ' Channel and search paging state
  m.currentChannelId = ""
  m.currentChannelPage = 1
  m.loadingChannelNext = false
  m.channelReturnRowCol = invalid
  m.channelReturnContext = ""
  m.preChannelSearchActive = false
  m.preChannelSearchContext = { type: "", query: "", from: 0 }
   m.searchActive = false
  m.searchContext = { type: "", query: "", from: 0 }
  m.loadingVideoSearch = false
  m.loadingChannelSearch = false
  m.categorySelector = m.top.findNode("selector")
  m.categorySelectorEndIndicator = m.top.findNode("catselectorendindicator")
  m.searchKeyboard = m.top.findNode("searchKeyboard")
  m.vjschars = { "play": Chr(61697), "play-circle": Chr(61698), "pause": Chr(61699), "volume-mute": Chr(61700), "volume-low": Chr(61701), "volume-mid": Chr(61702), "volume-high": Chr(61703), "fullscreen-enter": Chr(61704), "fullscreen-exit": Chr(61705), "square": Chr(61706), "spinner": Chr(61707), "subtitles": Chr(61708), "captions": Chr(61709), "chapters": Chr(61710), "share": Chr(61711), "cog": Chr(61712), "circle": Chr(61713), "circle-outline": Chr(61714), "circle-inner-circle": Chr(61715), "hd": Chr(61716), "cancel": Chr(61717), "replay": Chr(61718), "facebook": Chr(61719), "gplus": Chr(61720), "linkedin": Chr(61721), "twitter": Chr(61722), "tumblr": Chr(61723), "pinterest": Chr(61724), "audio-description": Chr(61725), "audio": Chr(61726), "next-item": Chr(61727), "previous-item": Chr(61728), "picture-in-picture-enter": Chr(61729), "picture-in-picture-exit": Chr(61730) }
  m.searchKeyboardDialog = m.searchkeyboard.findNode("searchKeyboardDialog")
  m.searchKeyboardDialog.itemSize = [280, 65]
  m.searchKeyboardDialog.content = createBothItems(m.searchKeyboardDialog, ["Search Videos", "Search Channels"], m.searchKeyboardDialog.itemSize)
  m.videoOverlayGroup = m.top.findNode("videoOverlayGroup")
  m.ffrwTimer = m.top.findNode("ffrwTimer")
  m.videoUITimer = m.top.findNode("videoUITimer")
  m.videoProgressBarp1 = m.videoOverlayGroup.findNode("beginningProgress")
  m.videoProgressBarp2 = m.videoOverlayGroup.findNode("endingProgress")
  m.videoProgressBar = m.videoOverlayGroup.findNode("bar")
  m.videoButtons = m.videoOverlayGroup.findNode("videoButtons")
  m.videoButtons.itemSize = [180, 128]
  m.videoButtons.itemSpacing = "[36, 20]"
  m.skipStep = 10 'seconds to skip on single-tap FF/RW and hold increments
  m.playbackRateValues = [1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
  m.playbackRateLabels = ["1.0x", "1.25x", "1.5x", "1.75x", "2.0x", "2.5x", "3.0x"]
  m.playbackRateIndex = 0
  m.playbackRate = m.playbackRateValues[m.playbackRateIndex]
  rateLabel = m.playbackRateLabels[m.playbackRateIndex]
  m.loopEnabled = false
  m.standardButtonsLoggedIn = [{ item: "pkg:/images/generic/bad_icon_requires_usage_rights.png", itemID: "channelButton" }, { item: "pkg://images/png/Heart.png", itemID: "following" }, { item: m.vjschars["previous-item"], itemID: "previousItem" }, { item: m.vjschars["replay"], itemID: "restart" }, { item: m.vjschars["pause"], itemID: "playPause" }, { item: m.vjschars["next-item"], itemID: "nextItem" }, { item: rateLabel, itemID: "playbackRate" }, { item: "Loop", itemID: "loop" }, { item: "pkg:/images/generic/tu64.png", itemID: "like" }, { item: "pkg:/images/generic/td64.png", itemID: "dislike" }]
  m.standardButtonsLoggedOut = [{ item: "pkg:/images/generic/bad_icon_requires_usage_rights.png", itemID: "channelButton" }, { item: m.vjschars["previous-item"], itemID: "previousItem" }, { item: m.vjschars["replay"], itemID: "restart" }, { item: m.vjschars["pause"], itemID: "playPause" }, { item: m.vjschars["next-item"], itemID: "nextItem" }, { item: rateLabel, itemID: "playbackRate" }, { item: "Loop", itemID: "loop" }]
  m.liveButtonsLoggedIn = [{ item: "pkg:/images/generic/bad_icon_requires_usage_rights.png", itemID: "channelButton" }, { item: "pkg://images/png/Heart.png", itemID: "following" }, { item: "pkg:/images/generic/tu64.png", itemID: "like" }, { item: "pkg:/images/generic/td64.png", itemID: "dislike" }, { item: Chr(61729), itemID: "toggleChat" }]
  m.liveButtonsLoggedOut = [{ item: "pkg:/images/generic/bad_icon_requires_usage_rights.png", itemID: "channelButton" }, { item: Chr(61729), itemID: "toggleChat" }]
  m.videoButtons.content = createBothItemsIdentified(m.videoButtons, m.standardButtonsLoggedOut, m.videoButtons.itemSize)
  ensureDefaultVideoButtonsIndex()
  m.videoButtons.observeField("itemFocused", "videoButtonFocused")
  m.standardVideoButtonNameTable = { "channelButton": "videoButtonsChannelIcon", "following": "videoButtonsFollowingIcon", "previousItem": "videoButtonsPrev", "restart": "videoButtonsRestart", "playPause": "videoButtonsPlayIcon", "nextItem": "videoButtonsNext", "playbackRate": "videoButtonsRate", "loop": "videoButtonsLoop", "like": "videoButtonsLikeIcon", "dislike": "videoButtonsDislikeIcon" }
  m.liveVideoButtonNameTable = { "channelButton": "videoButtonsChannelIcon", "following": "videoButtonsFollowingIcon", "like": "videoButtonsLikeIcon", "dislike": "videoButtonsDislikeIcon", "toggleChat": "videoButtonsChatToggle" }
  regenerateNormalButtonRefs()
  setPlaybackRateByIndex(m.playbackRateIndex)
  m.currentVideoChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png" 'Current icon displayed w/video UI
  m.currentVideoChannelID = "" 'Current claim ID for Video's Channel
  m.currentVideoClaimID = "" 'Current claim ID for Video
  m.currentVideoReactions = {}
  m.currentVideoPosition = [0, 0]
  m.pendingResume = -1 'seconds to seek to after playback starts; -1 when none
  m.resumeTimer = CreateObject("roTimeSpan") 'throttle resume saves
  m.searchHistoryBox = m.top.findNode("searchHistory")
  m.searchHistoryLabel = m.top.findNode("searchHistoryLabel")
  m.searchHistoryItems = []
  m.searchHistoryDialog = m.top.findNode("searchHistoryDialog")
  m.searchHistoryContent = m.searchHistoryBox.findNode("searchHistoryContent")
  m.searchKeyboardGrid = m.searchKeyboard.getChildren(-1, 0)[0].getChildren(-1, 0)[1].getChildren(-1, 0)[0] 'Incredibly hacky VKBGrid access. Thanks Roku!
  ' Expose a callable for control buttons/grid to request a skip without changing selection
  m.top.skipFromControlBar = sub(dir as integer)
    skipFromControlBar(dir)
  end sub
  m.oauthHeader = m.top.findNode("oauth-header")
  m.oauthCode = m.top.findNode("oauth-code")
  m.oauthFooter = m.top.findNode("oauth-footer")
  m.oauthLogoutButton = m.top.findNode("logoutButton")

  'UI Item observers
  m.videoObserved = true
  m.video.observeField("state", "onVideoStateChanged")
  m.categorySelector.observeField("itemFocused", "categorySelectorFocusChanged")
  m.videoGrid.observeField("rowItemSelected", "resolveVideo")
  'm.videoGrid.observeField("rowItemFocused", "gotvGridPosition")
  m.searchHistoryBox.observeField("itemSelected", "historySearch")
  m.searchHistoryDialog.observeField("itemSelected", "clearHistory")
  m.searchKeyboardDialog.observeField("itemSelected", "search")
  m.oauthLogoutButton.observeField("buttonSelected", "Logout")

  'Tasks
  if m.global.constants.enableStatistics
    m.vStatsTimer = CreateObject("roTimeSpan")

    m.watchman = createObject("roSGNode", "watchman") 'analytics (video)

    observeFields("watchman", { "output": "watchmanRan",
    "cookies": "gotCookies" })

    m.rokuInstall = createObject("roSGNode", "rokuInstall") 'analytics (install)

    observeFields("rokuInstall", { "output": "didInstall",
    "cookies": "gotCookies" })

  end if
  m.ws = createObject("roSGNode", "WebSocketClient")
  m.wsChat = m.ws.findNode("chat")
  m.date = CreateObject("roDateTime")
  m.chatArray = [] 'legacy: left in for now.
  m.superChatArray = []
  m.chatRegex = CreateObject("roRegex", "[^\x00-\x7F]", "") 'incredibly scuffed
  m.chatImageRegex = CreateObject("roRegex", "(?:!\[(.*?)\]\((.*?)\))", "") 'incredibly scuffed
  m.channelIDs = {}
  m.categories = {}
  m.authTask = createObject("roSGNode", "authTask")
  m.urlResolver = createObject("roSGNode", "resolveLBRYURL")
  m.channelResolver = createObject("roSGNode", "getSingleChannel")
  m.videoSearch = createObject("roSGNode", "getVideoSearch")
  m.channelSearch = createObject("roSGNode", "getChannelSearch")
  m.channelPage = CreateObject("roSGNode", "getChannelPage")
  m.allLiveTask = CreateObject("roSGNode", "getAllLiveItems")
  m.InputTask = createObject("roSgNode", "inputTask")
  m.InputTask.observefield("inputData", "handleInputEvent")
  m.favoritesThread = CreateObject("roSGNode", "getSinglePage")
  'forgot that cookies should be universal throughout application
  m.urlResolver.observeField("cookies", "gotCookies")
  m.channelResolver.observeField("cookies", "gotCookies")
  m.videoSearch.observeField("cookies", "gotCookies")
  m.channelSearch.observeField("cookies", "gotCookies")
  m.constantsTask = createObject("roSGNode", "getConstants")
  m.constantsTask.observeField("constants", "gotConstants")
  m.allLiveTask.observeField("output", "gotAllLive")
  m.authTask = createObject("roSGNode", "authTask")
  m.syncLoop = createObject("roSGNode", "syncLoop")
  observeFields("authTask", { "authPhase": "authPhaseChanged": "userCode": "gotRokuCode": "accessToken": "gotAccessToken": "refreshToken": "gotRefreshToken": "uid": "gotUID": "authtoken": "gotAuth": "cookies": "gotCookies" })
  observeFields("syncLoop", { "inSync": "gotSync": "preferencesChanged": "preferencesChanged": "oldHash": "walletChanged": "walletData": "walletChanged": "error": "syncLoopError" })
  m.getpreferencesTask = createObject("roSGNode", "getpreferencesTask")
  m.setpreferencesTask = createObject("roSGNode", "setpreferencesTask")
  m.preferences = {} ' user preferences (blocked, following, collections)
  m.oldpreferences = { blocked: []: following: []: collections: [] } ' user preferences (blocked, following, collections)
  m.getreactionTask = createObject("roSGNode", "getreactionTask")
  m.setreactionTask = createObject("roSGNode", "setreactionTask")
  m.authTaskChildren = m.authTask.getChildren(-1, 0)
  m.syncLoopChildren = m.syncLoop.getChildren(-1, 0)
  m.authTaskTimer = m.authTaskChildren[0]
  m.syncLoopTimer = m.syncLoopChildren[0]
  m.syncLoopState = 0 'Sync loop state variable
  m.accessToken = ""
  m.accessTokenExpiration = 0
  m.refreshToken = ""
  m.refreshTokenExpiration = 0
  m.uid = 0
  m.authToken = ""

  m.cidsTask = createObject("roSGNode", "getChannelIDs")
  m.cidsTask.observeField("channelids", "gotCIDS")

  m.authRegistry = CreateObject("roRegistrySection", "authData") 'Authentication Data (UID/authToken/etc.)
  m.deviceFlowRegistry = CreateObject("roRegistrySection", "deviceFlowData") 'Device Flow Data (Wallet, Sync Hashes (old/new), Auth Token+Refresh Token)
  m.preferencesRegistry = CreateObject("roRegistrySection", "preferences") 'User preferences (odysee.com/app local)
  m.searchHistoryRegistry = CreateObject("roRegistrySection", "searchHistory") 'Search History
  m.resumeRegistry = CreateObject("roRegistrySection", "resumePoints") 'Per-claim resume positions

  'Get current (older non-token) auth
  if IsValid(GetRegistry("authRegistry", "uid")) and IsValid(GetRegistry("authRegistry", "authtoken"))
    ?"found current account with UID" + GetRegistry("authRegistry", "uid")
    m.uid = StrToI(GetRegistry("authRegistry", "uid"))
    m.authToken = GetRegistry("authRegistry", "authtoken")
    m.authTask.setFields({ uid: m.uid, authtoken: m.authtoken })
  end if
  if IsValid(GetRegistry("preferencesRegistry", "loggedIn")) and IsValid(GetRegistry("preferencesRegistry", "preferences")) 'Get user preferences (if they exist)
    ?"found preferences" + GetRegistry("preferencesRegistry", "preferences")
    ?GetRegistry("preferencesRegistry", "loggedIn")
    if GetRegistry("preferencesRegistry", "loggedIn") = "true"
      m.wasLoggedIn = true
    else
      m.wasLoggedIn = false
    end if
    m.preferences = ParseJSON(GetRegistry("preferencesRegistry", "preferences"))
    m.oldpreferences = ParseJSON(GetRegistry("preferencesRegistry", "preferences"))
  end if

  m.wallet = { "oldHash": "asdf", "walletData": "asdf" } 'create template wallet object
  'begin populating template
  if isValid(GetRegistry("deviceFlowRegistry", "walletOldHash"))
    m.wallet.oldHash = GetRegistry("deviceFlowRegistry", "walletOldHash")
  end if
  if isValid(GetRegistry("deviceFlowRegistry", "walletData"))
    m.wallet.walletData = GetRegistry("deviceFlowRegistry", "walletData")
  end if
  if isValid(GetRegistry("deviceFlowRegistry", "flowUID"))
    m.flowUID = GetRegistry("deviceFlowRegistry", "flowUID")
  end if
  if isValid(GetRegistry("deviceFlowRegistry", "accessToken"))
    m.accessToken = GetRegistry("deviceFlowRegistry", "accessToken")
  end if
  if isValid(GetRegistry("deviceFlowRegistry", "accessTokenExpiration"))
    m.accessTokenExpiration = GetRegistry("deviceFlowRegistry", "accessTokenExpiration")
  end if
  if isValid(GetRegistry("deviceFlowRegistry", "refreshToken"))
    m.refreshToken = GetRegistry("deviceFlowRegistry", "refreshToken")
  end if
  if isValid(GetRegistry("deviceFlowRegistry", "refreshTokenExpiration"))
    m.refreshTokenExpiration = GetRegistry("deviceFlowRegistry", "refreshTokenExpiration")
  end if
  m.authTask.setFields({ "accessToken": m.accessToken: "refreshToken": m.refreshToken: uid: m.flowUID: "accessTokenExpiration": m.accessTokenExpiration: "refreshTokenExpiration": m.refreshTokenExpiration })
  '<field id="oldHash" type="String"/>
  '<field id="walletData" type="String"/>
  m.authTimerObserved = false
  m.syncTimerObserved = false
  'Get current search history
  if IsValid(GetRegistry("searchHistoryRegistry", "searchHistory"))
    ?"found current search history"
    m.searchHistoryItems = ParseJson(GetRegistry("searchHistoryRegistry", "searchHistory"))
    for each histitem in m.searchHistoryItems 'Not efficient. Research a way to convert between the items and ContentNode directly, without for.
      item = m.searchHistoryContent.createChild("ContentNode")
      item.title = histitem
    end for
    ?m.searchHistoryItems
  end if
  ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds() / 1000) + "s"
  m.constantsTask.control = "RUN"
end sub
sub onRowItemFocused()
  focusPos = m.videoGrid.rowItemFocused
  if not IsValid(focusPos) or Type(focusPos) <> "roArray" then return
  if focusPos.Count() < 2 then return
  row = focusPos[0]: col = focusPos[1]
  content = m.videoGrid.content
  if not IsValid(content) then return
  ' Trigger when focusing near the end of the last row
  lastRow = content.getChildCount() - 1
  visibleRows = 4
  try
    visibleRows = m.videoGrid.numRows
  catch e
    visibleRows = 4
  end try
  ' Prefetch when: content rows fewer than viewport, or user is within one viewport of the end
  shouldPrefetch = false
  if content.getChildCount() < visibleRows then shouldPrefetch = true
  prefetchTriggerRow = lastRow - visibleRows + 1
  if row >= prefetchTriggerRow then shouldPrefetch = true
  ' Also, if user is near end of a row (3rd+ tile), start early
  if col >= 1 and row >= lastRow - 1 then shouldPrefetch = true
  if shouldPrefetch
    ' Safe prefetch debug
    sa$ = "false": if m.searchActive then sa$ = "true"
    ch$ = "": if IsValid(m.currentChannelId) then ch$ = m.currentChannelId
    ? "[Prefetch] row=" + Str(row) + "/" + Str(lastRow) + " col=" + Str(col) + " searchActive=" + sa$ + " channelId=" + ch$
    ' Prefer channel paging when viewing a channel
    if IsValid(m.currentChannelId) and m.currentChannelId <> ""
      if m.loadingChannelNext = true then return
      m.loadingChannelNext = true
      nextChPage = m.currentChannelPage + 1
      ct = CreateObject("roSGNode","getChannelNextPage")
      ct.setFields({ constants: m.constants, channel: m.currentChannelId, page: nextChPage, uid: m.uid })
      ct.observeField("output","onChannelNextPageLoaded")
      ct.control = "RUN"
      m.currentChannelPage = nextChPage
      ? "[Channel] Prefetch dispatch page=" + Str(nextChPage)
      ensureLoadingPlaceholderRow()
      return
    end if
    ' Determine current category name from selector
    if m.categorySelector.visible = true
      catIndex = m.categorySelector.itemFocused
      if catIndex < 0 then return
      catName = m.categorySelectordata[catIndex].trueName
      if not IsValid(catName) then return
      ? "AutoLoad focus row=" + Str(row) + "/" + Str(lastRow) + " col=" + Str(col) + " cat=" + catName
      ' Stop paging if we've reached the end for this category
      if not IsValid(m.noMoreCategoryPages) then m.noMoreCategoryPages = {}
      if IsValid(m.noMoreCategoryPages[catName]) and m.noMoreCategoryPages[catName] = true then return
      if not IsValid(m.currentCategoryPage[catName]) then m.currentCategoryPage[catName] = 1
      nextPage = m.currentCategoryPage[catName] + 1
      ' Special-case FAVORITES: autoload using followed channels even if not in channelIDs map
      if catName = "FAVORITES"
        if m.loadingNextPage.DoesExist(catName) and m.loadingNextPage[catName] = true then return
        m.loadingNextPage[catName] = true
        t = CreateObject("roSGNode","getCategoryNextPage")
        userBlocked = []
        if IsValid(m.preferences) and IsValid(m.preferences.blocked) then userBlocked = m.preferences.blocked
        fieldsAA = { constants: m.constants, page: nextPage, uid: m.uid, blocked: userBlocked, excluded: [], rawname: catName, channels: m.preferences.following }
        t.setFields(fieldsAA)
        t.observeField("output","onNextPageLoaded")
        t.control = "RUN"
        m.currentCategoryPage[catName] = nextPage
        ? "[FAVORITES] Prefetch dispatch page=" + Str(nextPage) + " channels=" + Str(m.preferences.following.Count())
        ensureLoadingPlaceholderRow()
      else if IsValid(m.channelIDs[catName])
        t = CreateObject("roSGNode","getCategoryNextPage")
        catData = m.channelIDs[catName]
        excluded = []
        if catName = "wildwest" and IsValid(catData.excludedChannelIds)
          if Type(catData.excludedChannelIds) = "roArray" or Type(catData.excludedChannelIds) = "Array"
            excluded = catData.excludedChannelIds
          end if
        end if
        userBlocked = []
        if IsValid(m.preferences) and IsValid(m.preferences.blocked) then userBlocked = m.preferences.blocked
        chs = invalid
        if catName = "FAVORITES" and IsValid(m.preferences) and IsValid(m.preferences.following)
          chs = m.preferences.following
        else if IsValid(catData["channelIds"]) and (Type(catData["channelIds"]) = "roArray" or Type(catData["channelIds"]) = "Array")
          chs = catData["channelIds"]
        end if
        if IsValid(m.loadingNextPage[catName]) and m.loadingNextPage[catName] = true then return
        m.loadingNextPage[catName] = true
        ? "AutoLoad dispatch page=" + Str(nextPage) + " cat=" + catName
        ' For Wild West, pass no channels (task handles trending-only claim_search); else pass list
        fieldsAA = { constants: m.constants, page: nextPage, uid: m.uid, blocked: userBlocked, excluded: excluded, rawname: catName }
        if IsValid(chs) and chs.Count() > 0 then fieldsAA["channels"] = chs
        t.setFields(fieldsAA)
        t.observeField("output","onNextPageLoaded")
        t.control = "RUN"
        m.currentCategoryPage[catName] = nextPage
        ensureLoadingPlaceholderRow()
      end if
    else if m.searchActive = true
      if m.searchContext.type = "video"
        if m.loadingVideoSearch = true then return
        m.loadingVideoSearch = true
        nextFrom = m.searchContext.from + 48
        vt = CreateObject("roSGNode","getVideoSearchNextPage")
        vt.setFields({ constants: m.constants, search: m.searchContext.query, from: nextFrom, uid: m.uid })
        vt.observeField("output","onVideoSearchNextPageLoaded")
        vt.control = "RUN"
        m.searchContext.from = nextFrom
        ? "[Search:Video] Prefetch dispatch from=" + Str(nextFrom)
        ensureLoadingPlaceholderRow()
      else if m.searchContext.type = "channel"
        if m.loadingChannelSearch = true then return
        m.loadingChannelSearch = true
        nextFromC = m.searchContext.from + 48
        ct2 = CreateObject("roSGNode","getChannelSearchNextPage")
        if not IsValid(ct2)
          ? "ChannelSearchNextPage component not available; canceling load"
          m.loadingChannelSearch = false
          return
        end if
        ' Ensure search term always present by falling back to lastChannelSearchQuery
        chQuery = m.searchContext.query
        if not IsValid(chQuery) or chQuery = "" then chQuery = m.lastChannelSearchQuery
        ' Pass fallback in constants for task-level fallback too
        cst = m.constants: cst["__lastChannelQuery"] = chQuery
        ct2.setFields({ constants: cst, search: chQuery, from: nextFromC, uid: m.uid, authtoken: m.authtoken, accessToken: m.accessToken })
        ct2.observeField("output","onChannelSearchNextPageLoaded")
        ct2.control = "RUN"
        m.searchContext.from = nextFromC
        ? "[Search:Channel] Prefetch dispatch from=" + Str(nextFromC)
        ensureLoadingPlaceholderRow()
      end if
    end if
  end if
end sub

sub refreshAllLive()
  if not IsValid(m.allLiveTask) then return
  if m.allLiveTask.state = "run" then return ' avoid overlapping
  m.allLiveTask.setField("constants", m.constants)
  m.allLiveTask.control = "RUN"
end sub

function buildLiveRowsForChannels(channelIds as Object, limit as Integer) as Object
  liveNodes = createObject("RoSGNode", "ContentNode")
  if not IsValid(m.allLive) or not IsValid(m.allLive.items) then return liveNodes
  if not (Type(channelIds) = "roArray" or Type(channelIds) = "Array") then return liveNodes
  ? "[Live] buildLiveRowsForChannels channelIds=" + Str(channelIds.Count())
  claimsIndex = {}
  if IsValid(m.allLive.claims) and (Type(m.allLive.claims) = "roArray" or Type(m.allLive.claims) = "Array")
    for each cl in m.allLive.claims
      if IsValid(cl) and IsValid(cl.claim_id) then
        claimsIndex.addReplace(cl.claim_id, cl)
      end if
    end for
  end if
  counter = 0: currow = invalid: pushed = 0
  ' Prefer direct byChannel lookups for followed channel IDs
  if IsValid(m.allLive.byChannel)
    for each cid in channelIds
      if IsValid(cid) and IsValid(m.allLive.byChannel[cid])
        liveMeta = m.allLive.byChannel[cid]
        cId = invalid
        try: cId = liveMeta.ActiveClaim.ClaimID : catch e: cId = invalid : end try
        if IsValid(cId)
          cl = claimsIndex[cId]
          if IsValid(cl)
            lv = parseLiveData(cid, liveMeta, cl)
            if counter < 4
              if IsValid(currow) <> true then currow = createObject("RoSGNode", "ContentNode")
              n = createObject("RoSGNode", "ContentNode")
              n.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", reposted: false, repostedBy: "", rawCreator: "", videoLength: "", viewerDisplay: "", viewers: 0 })
              n.setFields(lv)
              currow.appendChild(n)
              counter += 1
            else
              liveNodes.appendChild(currow)
              currow = createObject("RoSGNode", "ContentNode")
              n = createObject("RoSGNode", "ContentNode")
              n.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", reposted: false, repostedBy: "", rawCreator: "", videoLength: "", viewerDisplay: "", viewers: 0 })
              n.setFields(lv)
              currow.appendChild(n)
              counter = 1
            end if
            pushed += 1
            if limit > 0 and pushed >= limit then exit for
          end if
        end if
      end if
    end for
  end if
  if IsValid(currow) and currow.getChildCount() > 0 then
    liveNodes.appendChild(currow)
  end if
  ? "[Live] buildLiveRowsForChannels done; rows=" + Str(liveNodes.getChildCount())
  return liveNodes
end function

' Build top-N live rows across ALL live items (viewer-sorted by API)
function buildTopLiveRows(limit as Integer) as Object
  liveNodes = createObject("RoSGNode", "ContentNode")
  if not IsValid(m.allLive) or not IsValid(m.allLive.items) then return liveNodes
  ' Index claims by claim_id for fast lookup
  claimsIndex = {}
  if IsValid(m.allLive.claims) and (Type(m.allLive.claims) = "roArray" or Type(m.allLive.claims) = "Array")
    for each cl in m.allLive.claims
      if IsValid(cl) and IsValid(cl.claim_id) then claimsIndex.addReplace(cl.claim_id, cl)
    end for
  end if
  maxItems = 8
  if limit > 0 and limit < 8 then maxItems = limit
  totalAvailable = 0
  try: totalAvailable = m.allLive.items.Count() : catch e: totalAvailable = 0 : end try
  counter = 0: currow = invalid: pushed = 0
  for each liveItem in m.allLive.items
    if pushed >= maxItems then exit for
    if IsValid(liveItem)
      cId = invalid
      validId = false
      try
        cId = liveItem.ActiveClaim.ClaimID
        if IsValid(cId) then validId = true
      catch e
        validId = false
      end try
      if validId
        cl = claimsIndex[cId]
        if IsValid(cl)
          chId = ""
          if IsValid(cl.signing_channel) and IsValid(cl.signing_channel.claim_id) then chId = cl.signing_channel.claim_id
          lv = parseLiveData(chId, liveItem, cl)
          if counter < 4
            if IsValid(currow) <> true then currow = createObject("RoSGNode", "ContentNode")
            n = createObject("RoSGNode", "ContentNode")
            n.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", reposted: false, repostedBy: "", rawCreator: "", videoLength: "", viewerDisplay: "", viewers: 0 })
            n.setFields(lv)
            currow.appendChild(n)
            counter = counter + 1
          else
            liveNodes.appendChild(currow)
            currow = createObject("RoSGNode", "ContentNode")
            n = createObject("RoSGNode", "ContentNode")
            n.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", reposted: false, repostedBy: "", rawCreator: "", videoLength: "", viewerDisplay: "", viewers: 0 })
            n.setFields(lv)
            currow.appendChild(n)
            counter = 1
          end if
          pushed = pushed + 1
        end if
      end if
    end if
  end for
  if IsValid(currow) and currow.getChildCount() > 0 then liveNodes.appendChild(currow)
  ? "[Live] buildTopLiveRows available=" + Str(totalAvailable) + " builtTiles=" + Str(pushed) + " rows=" + Str(liveNodes.getChildCount())
  return liveNodes
end function

function stripLeadingLiveRows(content as Object) as Object
  vod = createObject("RoSGNode", "ContentNode")
  if not IsValid(content) then return vod
  ' Move rows safely: always take index 0 to avoid skipping when moving nodes
  while content.getChildCount() > 0
    r = content.getChild(0)
    keep = true
    if IsValid(r) and r.getChildCount() > 0
      first = r.getChild(0)
      if IsValid(first) and IsValid(first.itemType) and first.itemType = "livestream" then keep = false
    end if
    if keep
      vod.appendChild(r) ' moves from content
    else
      content.removeChildIndex(0) ' drop old live row
    end if
  end while
  return vod
end function

sub mergeLiveIntoCategory(catName as String, channelIds as Object, liveLimit as Integer)
  if not IsValid(m.categories) then return
  if not IsValid(m.categories[catName]) then return
  chCount = 0
  if IsValid(channelIds)
    try
      chCount = channelIds.Count()
    catch e
      chCount = 0
    end try
  end if
  ? "[Live] mergeLiveIntoCategory cat=" + catName + " channels=" + Str(chCount)
  vodOnly = stripLeadingLiveRows(m.categories[catName])
  ' Cap rows for categories if needed
  effLimit = liveLimit
  liveRows = createObject("RoSGNode", "ContentNode")
  if catName = "wildwest"
    ' Always take top 8 across ALL live items for Wild West
    if liveLimit = 0 or liveLimit > 8 then effLimit = 8
    liveRows = buildTopLiveRows(effLimit)
    if liveRows.getChildCount() < 2 and IsValid(m.allLive) and IsValid(m.allLive.items)
      ' Fallback: if fewer than 2 rows, pad from remaining live items skipping ones already included
      included = {}
      for i = 0 to liveRows.getChildCount() - 1
        r = liveRows.getChild(i)
        for j = 0 to r.getChildCount() - 1
          n = r.getChild(j)
          if IsValid(n) and IsValid(n.guid) and n.guid <> "" then included.addReplace(n.guid, true)
        end for
      end for
      ' Index claims for fallback
      claimsIndex = {}
      if IsValid(m.allLive.claims) and (Type(m.allLive.claims) = "roArray" or Type(m.allLive.claims) = "Array")
        for each cl in m.allLive.claims
          if IsValid(cl) and IsValid(cl.claim_id) then claimsIndex.addReplace(cl.claim_id, cl)
        end for
      end if
      counter = 0: currow = invalid
      for each liveItem in m.allLive.items
        cId = invalid
        ok = false
        try: cId = liveItem.ActiveClaim.ClaimID : catch e: cId = invalid : end try
        if IsValid(cId)
          if not IsValid(included[cId])
            cl = claimsIndex[cId]
            if IsValid(cl)
              chId = ""
              if IsValid(cl.signing_channel) and IsValid(cl.signing_channel.claim_id) then chId = cl.signing_channel.claim_id
              lv = parseLiveData(chId, liveItem, cl)
              if counter < 4
                if IsValid(currow) <> true then currow = createObject("RoSGNode", "ContentNode")
                n = createObject("RoSGNode", "ContentNode")
                n.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", reposted: false, repostedBy: "", rawCreator: "", videoLength: "", viewerDisplay: "", viewers: 0 })
                n.setFields(lv)
                currow.appendChild(n)
                counter = counter + 1
              else
                liveRows.appendChild(currow)
                currow = createObject("RoSGNode", "ContentNode")
                n = createObject("RoSGNode", "ContentNode")
                n.addFields({ creator: "", itemType: "", Channel: "", ChannelIcon: "", reposted: false, repostedBy: "", rawCreator: "", videoLength: "", viewerDisplay: "", viewers: 0 })
                n.setFields(lv)
                currow.appendChild(n)
                counter = 1
              end if
              included.addReplace(cId, true)
              ' stop when we have at least 2 rows
              if liveRows.getChildCount() >= 2 then exit for
            end if
          end if
        end if
      end for
      if IsValid(currow) and currow.getChildCount() > 0 then liveRows.appendChild(currow)
    end if
  else
    ' Other categories: per-channel lives, optional cap
    liveRows = buildLiveRowsForChannels(channelIds, effLimit)
  end if
  liveCount = liveRows.getChildCount()
  vodCount = vodOnly.getChildCount()
  ? "[Live] built live rows=" + Str(liveCount)
  if liveCount = 0 then return
  merged = createObject("RoSGNode", "ContentNode")
  ' Move rows safely without skipping by always taking index 0
  while liveRows.getChildCount() > 0
    merged.appendChild(liveRows.getChild(0))
  end while
  while vodOnly.getChildCount() > 0
    merged.appendChild(vodOnly.getChild(0))
  end while
  ? "[Live] merged rows live=" + Str(liveCount) + " vod=" + Str(vodCount) + " totalRows=" + Str(merged.getChildCount()) + " totalTiles=" + Str(countTiles(merged))
  m.categories.addReplace(catName, merged)
  if IsValid(m.categorySelector) and IsValid(m.categorySelectorData)
    if IsValid(m.categorySelector.itemFocused) and m.categorySelector.itemFocused >= 0 and m.categorySelector.itemFocused < m.categorySelectorData.Count()
      cur = m.categorySelectorData[m.categorySelector.itemFocused]
      if IsValid(cur) and IsValid(cur.trueName) and cur.trueName = catName
        if IsValid(m.videoGrid) then m.videoGrid.content = merged
      end if
    end if
  end if
end sub
sub onNextPageLoaded(evt as object)
  if type(evt) <> "roSGNodeEvent" then return
  data = evt.getData()
  ' Append new rows to the current grid
  if IsValid(data) and IsValid(data.content)
    clearLoadingPlaceholderRow()
    appendRowsFillingPartial(data.content)
  end if
  ' Cleanup
  t = evt.getRoSGNode()
  if IsValid(t)
    t.unobserveField("output")
    t.control = "STOP"
  end if
  ' If no items returned, mark no-more-pages for this category to avoid endless paging
  if IsValid(t) and IsValid(data)
    isEmpty = true
    if IsValid(data.items)
      if data.items.Count() > 0 then isEmpty = false
    end if
    if isEmpty = true and IsValid(t.rawname)
      if not IsValid(m.noMoreCategoryPages) then m.noMoreCategoryPages = {}
      m.noMoreCategoryPages[t.rawname] = true
      clearLoadingPlaceholderRow()
    end if
  end if
  ' Clear in-flight flag for this category
  if IsValid(t) and IsValid(t.rawname)
    m.loadingNextPage[t.rawname] = false
  end if
end sub

sub onChannelNextPageLoaded(evt as object)
  if type(evt) <> "roSGNodeEvent" then return
  data = evt.getData()
  ' If we've navigated away from channel view, ignore this result
  if m.categorySelector.visible = true or m.searchActive = true or (not IsValid(m.currentChannelId) or m.currentChannelId = "")
    t = evt.getRoSGNode()
    if IsValid(t)
      t.unobserveField("output")
      t.control = "STOP"
    end if
    m.loadingChannelNext = false
    return
  end if
  if IsValid(data) and IsValid(data.content)
    clearLoadingPlaceholderRow()
    if IsValid(m.videoGrid) and IsValid(m.videoGrid.content)
      appendRowsFillingPartial(data.content)
    end if
  end if
  t = evt.getRoSGNode()
  if IsValid(t)
    t.unobserveField("output")
    t.control = "STOP"
  end if
  m.loadingChannelNext = false
end sub

sub onVideoSearchNextPageLoaded(evt as object)
  if type(evt) <> "roSGNodeEvent" then return
  data = evt.getData()
  if IsValid(data) and IsValid(data.content)
    clearLoadingPlaceholderRow()
    appendRowsFillingPartial(data.content)
  end if
  t = evt.getRoSGNode()
  if IsValid(t)
    t.unobserveField("output")
    t.control = "STOP"
  end if
  m.loadingVideoSearch = false
end sub

sub onChannelSearchNextPageLoaded(evt as object)
  if type(evt) <> "roSGNodeEvent" then return
  data = evt.getData()
  if IsValid(data) and IsValid(data.content)
    clearLoadingPlaceholderRow()
    appendRowsFillingPartial(data.content)
  end if
  t = evt.getRoSGNode()
  if IsValid(t)
    t.unobserveField("output")
    t.control = "STOP"
  end if
  m.loadingChannelSearch = false
end sub

' Append rows to m.videoGrid.content, filling any partial last row up to 4 items first
sub appendRowsFillingPartial(newContent as object)
  if not IsValid(m.videoGrid) or not IsValid(m.videoGrid.content) then return
  dest = m.videoGrid.content
  rowSize = 4
  ' 1) Flatten all incoming items into a queue by moving nodes out of newContent
  queue = []
  if IsValid(newContent)
    for i = 0 to newContent.getChildCount() - 1
      r = newContent.getChild(i)
      if IsValid(r)
        while r.getChildCount() > 0
          n = r.getChild(0)
          if IsValid(n)
            ' Skip placeholders entirely
            if IsValid(n.itemType) and n.itemType = "placeholder"
              ' drop
            else
              queue.push(n)
            end if
          end if
          ' Remove from source row to avoid infinite loop
          r.removeChildIndex(0)
        end while
      end if
    end for
  end if
  qIndex = 0
  qCount = queue.Count()
  ' 2) Fill existing last row if partial
  if dest.getChildCount() > 0
    last = dest.getChild(dest.getChildCount() - 1)
    if IsValid(last)
      ' Remove any placeholders in last row first
      for i = last.getChildCount() - 1 to 0 step -1
        ch = last.getChild(i)
        if IsValid(ch) and IsValid(ch.itemType) and ch.itemType = "placeholder" then last.removeChildIndex(i)
      end for
      while last.getChildCount() < rowSize and qIndex < qCount
        last.appendChild(queue[qIndex])
        qIndex = qIndex + 1
      end while
    end if
  end if
  ' 3) Append complete new rows built from the remaining queue
  while qIndex < qCount
    row = CreateObject("roSGNode", "ContentNode")
    itemsAdded = 0
    while itemsAdded < rowSize and qIndex < qCount
      row.appendChild(queue[qIndex])
      qIndex = qIndex + 1
      itemsAdded = itemsAdded + 1
    end while
    dest.appendChild(row)
  end while
  lastCount = 0
  if dest.getChildCount() > 0 then
    lastCount = dest.getChild(dest.getChildCount()-1).getChildCount()
  end if
  ? "[Append] dest rows=" + Str(dest.getChildCount()) + " last count=" + Str(lastCount)
end sub

' Utility: count total tiles across all rows in a ContentNode grid
function countTiles(grid as object) as integer
  total = 0
  if not IsValid(grid) then return 0
  for i = 0 to grid.getChildCount() - 1
    r = grid.getChild(i)
    if IsValid(r) then total = total + r.getChildCount()
  end for
  return total
end function

sub gotAllLive(msg as object)
  if type(msg) = "roSGNodeEvent"
    data = msg.getData()
    m.allLiveTask.control = "STOP"
    m.allLive = data ' store: items (all live), claims, byChannel
    ' Update the currently visible page in place (category, wildwest, channel, or FAVORITES)
    if m.focusedItem = 2
      ' Determine active context
      context = ""
      catName = invalid
      if isValid(m.categorySelector) and m.categorySelector.visible = true and m.categorySelector.itemFocused > 1
        catIndex = m.categorySelector.itemFocused
        catName = m.categorySelectordata[catIndex].trueName
        context = catName
      else if IsValid(m.currentChannelId) and m.currentChannelId <> ""
        context = "channel"
      else if isValid(m.categorySelector) and m.categorySelector.visible = true and m.categorySelector.itemFocused = 1
        context = "FAVORITES"
      end if
      ' Rebuild live rows based on context and replace leading live rows only
      if context = "wildwest" and IsValid(m.categories["wildwest"]) then
        vod = stripLeadingLiveRows(m.categories["wildwest"]) ' remove old lives
        liveRows = buildTopLiveRows(8)
        merged = createObject("RoSGNode", "ContentNode")
        while liveRows.getChildCount() > 0: merged.appendChild(liveRows.getChild(0)): end while
        while vod.getChildCount() > 0: merged.appendChild(vod.getChild(0)): end while
        m.categories.addReplace("wildwest", merged)
        if m.videoGrid.visible then m.videoGrid.content = merged
      else if context = "FAVORITES" and IsValid(m.categories["FAVORITES"]) then
        vod = stripLeadingLiveRows(m.categories["FAVORITES"]) ' remove old lives
        liveRows = buildLiveRowsForChannels(m.preferences.following, 0) ' uncapped
        merged = createObject("RoSGNode", "ContentNode")
        while liveRows.getChildCount() > 0: merged.appendChild(liveRows.getChild(0)): end while
        while vod.getChildCount() > 0: merged.appendChild(vod.getChild(0)): end while
        m.categories.addReplace("FAVORITES", merged)
        if m.videoGrid.visible then m.videoGrid.content = merged
      else if context = "channel" and IsValid(m.videoGrid) and IsValid(m.videoGrid.content) then
        ' Channel page: rebuild the first row if currently live/not live changed
        grid = m.videoGrid.content
        rebuilt = createObject("RoSGNode", "ContentNode")
        ' Build new leading live row for this channel if active
        liveRow = buildLiveRowsForChannels([m.currentChannelId], 4)
        for i = 0 to liveRow.getChildCount() - 1: rebuilt.appendChild(liveRow.getChild(i)): end for
        ' Append existing VOD rows stripped of any old live rows
        vodOnly = stripLeadingLiveRows(grid)
        for i = 0 to vodOnly.getChildCount() - 1: rebuilt.appendChild(vodOnly.getChild(i)): end for
        m.videoGrid.content = rebuilt
      else if IsValid(catName) and IsValid(m.categories[catName]) then
        vod = stripLeadingLiveRows(m.categories[catName])
        if IsValid(m.channelIDs[catName]) and IsValid(m.channelIDs[catName]["channelIds"]) then
          liveRows = buildLiveRowsForChannels(m.channelIDs[catName]["channelIds"], 0)
          merged = createObject("RoSGNode", "ContentNode")
          while liveRows.getChildCount() > 0: merged.appendChild(liveRows.getChild(0)): end while
          while vod.getChildCount() > 0: merged.appendChild(vod.getChild(0)): end while
          m.categories.addReplace(catName, merged)
          if m.videoGrid.visible then m.videoGrid.content = merged
        end if
      end if
    end if
    ' Also refresh Following (FAVORITES) live rows if logged in and following exists
    if isValid(m.preferences) and isValid(m.preferences.following)
      if m.preferences.following.Count() > 0
        ? "[Live] gotAllLive: merging into FAVORITES; following=" + Str(m.preferences.following.Count())
        mergeLiveIntoCategory("FAVORITES", m.preferences.following, 0)
      end if
    end if
  end if
end sub

'TODO: order app according to startup[done]/seperate brightscript into seperate scripts for UI/startup/etc.

'STARTUP TASKS
sub gotConstants()
  ?m.constantsTask.constants
  m.constantsTask.unobserveField("constants")
  m.constantsTask.control = "STOP"
  if m.constantsTask.error
    retryError("Error getting constants from Github", "Please e-mail help@odysee.com.", "retryConstants")
  else
    m.constants = m.constantsTask.constants
    m.oauthFooter.text = "at " + m.constants["SSO_ACT_URL"]
    m.authTask.setField("constants", m.constants)
    m.getpreferencesTask.setField("constants", m.constants)
    m.setpreferencesTask.setField("constants", m.constants)
    m.setpreferencesTask.observeField("error", "setPreferencesError")
    m.setreactionTask.setField("constants", m.constants)
    m.syncLoop.setField("constants", m.constants)
    ' Kick off one-shot live fetch for merging across categories
    m.allLiveTask.setField("constants", m.constants)
    m.allLiveTask.control = "RUN"
    ' Schedule background refresh of live data every 5 minutes
    if not IsValid(m.liveRefreshTimer)
      m.liveRefreshTimer = CreateObject("roSGNode", "Timer")
      m.liveRefreshTimer.duration = 300 ' seconds
      m.liveRefreshTimer.repeat = true
      m.liveRefreshTimer.observeField("fire", "refreshAllLive")
      m.top.appendChild(m.liveRefreshTimer)
      m.liveRefreshTimer.control = "start"
    end if
    ?"Constants are done, running auth"
    ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds() / 1000) + "s"
    ' If a refresh token exists from a prior session, skip legacy Phase 0
    if isValid(m.refreshToken) and m.refreshToken <> ""
      m.authTask.authPhase = 1
    end if
    m.authTask.control = "RUN" 'authPhaseChanged is the next sub that will be triggered by the authTask.
  end if
end sub

sub retryConstants()
  m.errorText.visible = false
  m.errorSubtext.visible = false
  m.errorButton.visible = false
  m.errorButton.unobserveField("buttonSelected")
  m.constantsTask.observeField("constants", "gotConstants")
  m.constantsTask.control = "RUN"
end sub

sub authPhaseChanged(msg as object)
  if type(msg) = "roSGNodeEvent"
    m.authTask.control = "STOP"
    data = msg.getData()
    if data = -10
      ?"API is probably down."
      m.authTask.control = "STOP"
      retryError("CRITICAL ERROR: Authentication Broken/API Down.", "The app cannot start without the API. Press OK to attempt again."+Chr(10)+"Please e-mail help@odysee.com.", "retryConstants")
    end if
    if data = 10
      ?"Phase 10 (Logging Out)"
      ? m.authTask
    end if
    if data = 4
      'Forced logout occurs either:
      ' 1. When a user forcefully pulls their permission given to the odysee-roku app
      ' 2. When the token expires due to Odysee reinitializing their servers
      ?"Phase 4 (Forced Logout)"
      Logout()
    end if
    if data = 3
      ?"Phase 3 (Fully authenticated)"
      m.wasLoggedIn = true
      setRegistry("preferencesRegistry", "loggedIn", "true")
      ' Hide OAuth UI if visible
      m.oauthHeader.visible = false
      m.oauthCode.visible = false
      m.oauthFooter.visible = false
      m.loadingText.visible = false
      if m.syncTimerObserved = false
        m.syncLoop.setFields({ "accessToken": m.accessToken, "constants": m.constants })
        m.syncLoop.control = "RUN"
        m.syncLoopTimer.observeField("fire", "getSync")
        m.syncTimerObserved = true
      end if
      ' Kick off immediate preferences load to populate Following without delay
      if m.getpreferencesTask.state <> "run" and m.getpreferencesTask.state <> "init"
        getUserPrefs()
      else
        ' Also trigger a sync iteration now; if not ready, timer will handle
        getSync()
      end if
      if m.authTimerObserved = false
        m.authTaskTimer.observeField("fire", "refreshAuth")
        m.authTimerObserved = true
      end if
      ' If we skipped legacy auth (Phase 0), ensure UI bootstrap proceeds
      if m.legacyAuthenticated = false
        authDone()
      end if
    end if
    if data = 2
      if m.oauthCode.text <> "API-ERR"
        m.oauthHeader.text = "Enter"
      end if
      ?"Phase 2"
      ' Only manipulate OAuth UI when user is on Following view; otherwise wait for focus handler
      if m.categorySelector.itemFocused = 1 and m.uiLayer = 0
        m.videoGrid.visible = false
        m.loadingText.visible = false
        m.oauthLogoutButton.visible = false
        m.oauthHeader.visible = true
        m.oauthCode.visible = true
        m.oauthFooter.visible = true
      end if
      if m.legacyAuthenticated = false
        m.wasLoggedIn = false
        authDone()
      end if
      ? m.wasLoggedin
      if m.authTimerObserved = false
        m.authTaskTimer.observeField("fire", "refreshAuth")
        m.authTimerObserved = true
      end if
    end if
    if data = 1.6 'Bad SSO/Data (in syncLoop)
      ?"Sync Loop Error."
      if m.legacyAuthenticated = false
        m.wasLoggedIn = false
        authDone()
      end if
      ? m.wasLoggedin
      if m.authTimerObserved = false
        m.authTaskTimer.observeField("fire", "refreshAuth")
        m.authTimerObserved = true
      end if
      m.authTask.authPhase = 1.5
    end if
    if data = 1.5 'BAD SSO/Data
      if m.syncTimerObserved = true
        m.syncLoop.control = "STOP"
        m.syncLoopTimer.unobserveField("fire")
        m.syncTimerObserved = false
      end if
      m.oauthHeader.text = "Cannot connect to Accounts"
      m.oauthCode.text = "API-ERR"
      m.oauthFooter.text = "Contact help@odysee.com"
      m.wasLoggedIn = false 'better to pretend we're not logged in.
      m.authTask.control = "RUN"
      ?"Task Restarted"
    end if
    if data = 1.4
      ?"Phase 1.4 (Post forced-logout)"
      ' Trigger task; UI for device-code will be handled by focus change to Following and gotRokuCode
      m.authTask.control = "RUN"
    end if
    if data = 1
      ?"Phase 1 (Legacy Authenticated)"
      if m.syncTimerObserved = true
        m.syncLoop.control = "STOP"
        m.syncLoopTimer.unobserveField("fire")
        m.syncTimerObserved = false
      end if
      ?m.wasLoggedIn
      if isValid(m.authTask.output)
        if m.wasLoggedIn and m.authTask.output.authenticated = false
          authDone()
        end if
      end if
      if m.wasLoggedIn = false
        authDone()
      end if
      if m.constants["EMERG_DISABLE"]["accounts"]
        m.wasLoggedIn = false
        m.authTask.authPhase = 1.5
        m.authTask.control = "RUN"
        ?"Task Restarted (LEGACY AUTHPHASE: ACCTS DISABLED)"
      else
        ' Do not reassign authPhase here; let authTask progress from phase 1
        ' We only need to resume the task after STOP at handler entry
        m.authTask.control = "RUN"
        ?"Task Continued (Legacy -> OAuth)"
      end if
    end if
    if data = 0
      ?"Phase 0"
      m.authTask.control = "RUN"
    end if
  end if
end sub

sub authDone()
  'This wraps up the authentication phase so we have authentication to query Odysee for our videos.
  'We will run authPhaseChanged again if the user logs into Odysee/triggers the device flow phase with Following.
  ?"Running authDone"
  if m.authTask.authPhase = 1
    m.authTask.control = "STOP"
  end if
  m.loadingText.text = "Legacy Auth complete..."
  m.authTask.unobserveField("output")
  if m.authTask.error
    retryError("Error authenticating with Odysee", "Please e-mail help@odysee.com.", "retryAuth")
  else
    m.legacyAuthenticated = True
    ?m.authTask.output
    m.uid = m.authTask.uid
    m.authtoken = m.authTask.authtoken
    m.cookies = m.authTask.cookies
    ?"AUTH IS DONE!"
    ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds() / 1000) + "s"
    m.video.EnableCookies()
    m.video.SetHeaders(m.constants["ACCESS_HEADERS"])
    m.video.AddCookies(m.cookies)
    m.loadingText.text = "Legacy Auth complete..."
    m.cidsTask.setField("constants", m.constants)
    m.cidsTask.control = "RUN"
  end if
end sub

sub retryAuth()
  m.errorText.visible = false
  m.errorSubtext.visible = false
  m.errorButton.visible = false
  m.errorButton.unobserveField("buttonSelected")
  m.authTask.control = "RUN"
end sub

sub gotCIDS()
  ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds() / 1000) + "s"
  m.cidsTask.control = "STOP"
  m.cidsTask.unobserveField("channelids")
  if m.cidsTask.error
    retryError("Error getting frontpage channel IDs", "Please e-mail help@odysee.com.", "retryCIDS")
  else
    m.channelIDs = m.cidsTask.channelids
    m.categorySelectordata = m.cidsTask.categorySelectordata
    ?m.channelIDs
    ?"Got channelIDs+raw category selector data"
    ?"Creating threads"
    ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds() / 1000) + "s"
    blocked = []
    if m.wasLoggedIn and m.preferences.Count() > 0
      if isValid(m.preferences.blocked)
        ?"found blocked users"
        if m.preferences.blocked.Count() > 0
          blocked = m.preferences.blocked
          ?formatJson(blocked)
        end if
      end if
    end if
    if m.wasLoggedIn and m.preferences.Count() > 0
      if isValid(m.preferences.following)
        if m.preferences.following.Count() > 0
          ?"found following"
          ?formatJson(m.preferences["following"])
          thread = CreateObject("roSGNode", "getSinglePage")
          thread.setFields({ constants: m.constants, channels: m.preferences.following, blocked: m.preferences.blocked, rawname: "FAVORITES", uid: m.uid, cookies: m.cookies, resolveLivestreams: false })
          thread.observeField("output", "threadDone")
          m.threads.push(thread)
          ' Also merge any live items for Following (no cap)
          mergeLiveIntoCategory("FAVORITES", m.preferences.following, 0)
          m.favoritesLoaded = false 'Not yet.
        else
          m.favoritesLoaded = false
        end if
      end if
    end if
    for each category in m.channelIDs 'create categories for selector
      catData = m.channelIDs[category]
      catOrder = "new"
      excludedChannelIds = []
      if isValid(catData.order)
        if Type(catData.order) = "roString"
          catOrder = catData.order
        end if
      end if
      if IsValid(catData.excludedChannelIds)
        if Type(catData.excludedChannelIds) = "roArray" or Type(catData.excludedChannelIds) = "Array"
          excludedChannelIds = catData.excludedChannelIds
        end if
      end if
      thread = CreateObject("roSGNode", "getSinglePage")
      userBlocked = []
      if m.wasLoggedIn and m.preferences.Count() > 0
        if IsValid(m.preferences.blocked)
          userBlocked = m.preferences.blocked
        end if
      end if
      categoryExcluded = []
        if category = "wildwest"
        catorder="trending"
        if IsValid(excludedChannelIds)
          categoryExcluded = excludedChannelIds
        end if
      end if
      thread.setFields({ resolveLivestreams: false, sortorder: catOrder, constants: m.constants, channels: catData["channelIds"], rawname: category, uid: m.uid, cookies: m.cookies, blocked: userBlocked, excluded: categoryExcluded })
      thread.observeField("output", "threadDone")
      m.threads.push(thread)
      ' No per-category live fetch; we merge from one-shot all-live later
      catData = invalid 'save memory
      catOrder = invalid
      excludedChannelIds = invalid
    end for
    ?"Done, starting threader."
    ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds() / 1000) + "s"
    ?m.categorySelectordata
    m.threaderRunning = true
    m.runningThreads = m.threads
    m.threads = []
    for each thread in m.runningthreads
      thread.control = "RUN" 'start threading
    end for
    ?"Threader started."
    ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds() / 1000) + "s"
  end if
end sub

sub retryCIDS()
  m.errorText.visible = false
  m.errorSubtext.visible = false
  m.errorButton.visible = false
  m.errorButton.unobserveField("buttonSelected")
  m.cidsTask.observeField("channelids", "gotCIDS")
  m.cidsTask.control = "RUN"
end sub

sub threadDone(msg as object)
  'This stops the thread that is running and then checks if they are all done, if they are, we wrap up and start the code to present the user interface.
  'This had to be done as Odysee queries sometimes take a long time if they are not cached, so having two threads makes things much faster, but returns deminish after that.
  if type(msg) = "roSGNodeEvent"
    thread = msg.getRoSGNode()
    if thread.error
      if thread.numerrors = 2
        ?thread.rawname+" will now be deleted."
        'tried twice (w/likely hundreds of queries), kill it
        thread.control = "STOP"
        thread.unObserveField("output")
        m.channelIDs.Delete(thread.rawname)
        for categoryindex = 1 to m.categorySelectorData.Count()
          if m.categorySelectorData[categoryindex].trueName = thread.rawname
            m.categorySelectorData.delete(categoryindex)
            exit for
          end if
        end for
        for eThread = 0 to m.runningThreads.Count() - 1
          if m.runningThreads[eThread].rawname = thread.rawname
              m.runningThreads.delete(eThread)
              exit for
          end if
        end for
      else
        'retry: thread is not past limit
        ?thread.rawname+" error. Trying again."
        thread.control = "STOP"
        thread.control = "RUN"
      end if
    else
      ?thread.rawname+" completed successfully"
      m.loadingText.text = "Loading." + Str(m.runningThreads.Count()) + " categories remain..."
      ' If all-live exists, prepend live rows (special-case wildwest: top 8 overall)
      mergedContent = thread.output.content
      if IsValid(m.allLive) and IsValid(m.allLive.items)
        liveNodes = invalid
        if thread.rawname = "wildwest"
          ' Wild West: always use top 8 global lives
          liveNodes = buildTopLiveRows(8)
        else if IsValid(m.channelIDs[thread.rawname]) and IsValid(m.channelIDs[thread.rawname]["channelIds"]) and (Type(m.channelIDs[thread.rawname]["channelIds"]) = "roArray" or Type(m.channelIDs[thread.rawname]["channelIds"]) = "Array")
          catChannels = m.channelIDs[thread.rawname]["channelIds"]
          liveNodes = buildLiveRowsForChannels(catChannels, 0)
        end if
        if IsValid(liveNodes) and liveNodes.getChildCount() > 0
          merged = createObject("RoSGNode", "ContentNode")
          while liveNodes.getChildCount() > 0
            merged.appendChild(liveNodes.getChild(0))
          end while
          while mergedContent.getChildCount() > 0
            merged.appendChild(mergedContent.getChild(0))
          end while
          mergedContent = merged
        end if
      end if
      m.categories.addReplace(thread.rawname, mergedContent)
      thread.unObserveField("output")
      thread.control = "STOP"
      for cThread = 0 to m.runningThreads.Count() - 1
        if m.runningThreads[cThread].rawname = thread.rawname
            m.runningThreads.delete(cThread)
            exit for
        end if
      end for
        if m.authTask.authPhase > 0 and m.runningThreads.count() = 0 AND m.categories.count() > 0
          ?m.categories
          ?m.categories[m.categories.Keys()[0]]
          m.categorySelector.content = createObject("roSGNode", "ContentNode")
          for each category in m.categorySelectordata 'create categories for selector
            if isValid(category.trueName)
                if m.categories.DoesExist(category.truename)
                  dataItem = m.categorySelector.content.CreateChild("catselectordata")
                  dataItem.setFields(category)
                  if category.trueName = "FAVORITES"
                    m.favoritesLoaded = true
                  end if
                else if category.trueName = "FAVORITES"
                  dataItem = m.categorySelector.content.CreateChild("catselectordata")
                  dataItem.setFields(category)
                  m.favoritesLoaded = false
                end if
              else 'core/system categories
                dataItem = m.categorySelector.content.CreateChild("catselectordata")
                dataItem.setFields(category)
            end if
          end for
          ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds() / 1000) + "s"
          m.videoGrid.content = m.categories[m.categories.Keys()[0]]
          m.loadingText.visible = false
          m.loadingBackground.visible = false
          m.loadingText.translation = "[800,0]"
          m.loadingText.vertAlign = "center"
          m.loadingText.horizAlign = "left"
          finishInit()
        end if
      end if
    end if
    'Roku compiles variables as static, even ones that seem dynamic for speed.
    ? m.runningThreads.count() 'Force recount/dev debug
    if m.runningThreads.count() = 0
      m.categories.count() 
      if m.categories.count() = 0
        retryError("CRITICAL ERROR: claim_search down/parsing failure", "The app cannot start without categories. Press OK to attempt again."+Chr(10)+"Please e-mail help@odysee.com.", "retryCIDS")
      end if
    end if
end sub

sub threadDoneLive(msg as object)
  if type(msg) = "roSGNodeEvent"
    thread = msg.getRoSGNode()
    rawname = thread.rawname
    if not isValid(m.categories[rawname])
      ' If VOD hasn't arrived yet, temporarily store live under categories
      m.categories.addReplace(rawname, thread.output.content)
    else
      ' Prepend live rows before existing content rows
      vodContent = m.categories[rawname]
      liveContent = thread.output.content
      merged = createObject("RoSGNode", "ContentNode")
      ' First add live rows (safe move: pop child 0)
      while liveContent.getChildCount() > 0
        merged.appendChild(liveContent.getChild(0))
      end while
      ' Then add existing vod rows (safe move: pop child 0)
      while vodContent.getChildCount() > 0
        merged.appendChild(vodContent.getChild(0))
      end while
      m.categories.addReplace(rawname, merged)
    end if
    thread.unObserveField("output")
    thread.control = "STOP"
    end if
end sub

sub finishInit()
  m.threaderRunning = false
  if m.global.constants.enableStatistics
    if m.wasLoggedIn
      m.rokuInstall.setFields({ constants: m.constants, uid: m.uid, authtoken: "", cookies: m.cookies, accesstoken: m.accessToken })
      m.rokuInstall.control = "RUN"
    else
      m.rokuInstall.setFields({ constants: m.constants, uid: m.uid, authtoken: m.authTask.authtoken, cookies: m.cookies, accesstoken: "" })
      m.rokuInstall.control = "RUN"
    end if
  end if
  m.loadingText.text = "Loading...."
  m.InputTask.control = "RUN" 'run input task, since user input is now needed (UI)
  ?"init finished."
  m.header.visible = true
  m.sidebarTrim.visible = true
  m.sidebarBackground.visible = true
  m.odyseeLogo.visible = true
  m.videoGrid.visible = true
  m.loadingText.translation = "[150,0]"
  m.loadingText.vertAlign = "center"
  m.loadingText.horizAlign = "center"
  if m.favoritesLoaded
    m.categorySelector.jumpToItem = 1
  else
    m.categorySelector.jumpToItem = 2
  end if
  m.categorySelector.visible = true
  m.loaded = True
  m.taskRunning = false
  m.categorySelector.setFocus(true)
  m.focusedItem = 1
  m.global.scene.signalBeacon("AppLaunchComplete")
  if isValid(m.global.deeplink)
    if isValid(m.global.deeplink.contentId)
      'TODO: create reverse livestream resolver so that livestreams can be deeplinked
      'for now, if you try to play a livestream, this will break.
      if m.global.deeplink.contentId.instr("http") < 1
        resolveVideo(m.global.deeplink.contentId)
      end if
    end if
  end if
  'resolveVideo used in dev
  'stop
  'resolveVideo("lbry://@classical.hi-fi#e/Bach_Mass.B.Minor_Richter.Munich#6")
end sub

'UI BACKBONE
function onKeyEvent(key as string, press as boolean) as boolean 'Literally the backbone of the entire user interface
  'TODO: make more readable
  ?"task running state is:"
  ?m.taskRunning
  if m.taskRunning = False
    ?"key", key, "pressed with focus", m.focusedItem, "with press", press
    ?"current ui layer:", m.uiLayer
    ?"current ui array:"
    ?m.uiLayers
    if press
      if key = "OK"
        if m.video.visible = true and m.videoOverlayGroup.visible = true
          if m.videoButtonSelected <> "none"
            focusVal = invalid
            focusIndex = -1
            try: focusVal = m.videoButtons.itemFocused : catch e: focusVal = invalid : end try
            if Type(focusVal) = "roInt" or Type(focusVal) = "Integer" then
              focusIndex = focusVal
            else if Type(focusVal) = "roArray" and focusVal.Count() > 1 then
              focusIndex = focusVal[1]
            end if
            ? "Current Button:"
            ? m.videoButtonSelected
            if m.videoButtonSelected = "channelButton"
              ? "Go to channel"
              ' remember grid focus to restore after returning from channel
              if IsValid(m.currentVideoPosition) and Type(m.currentVideoPosition) = "roArray" and m.currentVideoPosition.Count() >= 2
                m.channelReturnRowCol = m.currentVideoPosition
                if m.searchActive
                  m.channelReturnContext = "search"
                  m.preChannelSearchActive = m.searchActive
                  m.preChannelSearchContext = m.searchContext
                else
                  m.channelReturnContext = "category"
                end if
              end if
              returnToUIPage()
              curChannel = m.currentVideoChannelID
              if not isValid(m.channelResolver)
                m.channelResolver = createObject("roSGNode", "getSingleChannel")
                m.channelResolver.observeField("cookies", "gotCookies")
              end if
              if isValid(curChannel)
                m.channelResolver.setFields({ constants: m.constants, channel: curChannel, uid: m.uid, cookies: m.cookies })
                m.channelResolver.observeField("output", "gotResolvedChannel")
                m.channelResolver.control = "RUN"
              end if
              m.taskRunning = True
              m.videoGrid.setFocus(false)
              m.videoGrid.visible = false
              m.loadingText.visible = true
              m.loadingText.text = "Resolving Channel..."
            else if m.videoButtonSelected = "following"
              ? "Subscribe/Follow"
              ? m.wasLoggedIn
              if m.wasLoggedIn
                if m.videoButtonsFollowingIcon.posterUrl = "pkg:/images/generic/Heart-selected.png"
                  unFollow(m.currentVideoChannelID)
                else
                  follow(m.currentVideoChannelID)
                end if
              end if
            else if m.videoButtonSelected = "previousItem"
              'Back Button/Previous Video
              ? m.currentVideoPosition
              if m.currentVideoPosition[1] = 0 'First video in row, attempt to go back
                if m.currentVideoPosition[0] > 0
                  if isValid(m.videoGrid.content.getChild(m.currentVideoPosition[0] - 1).getChild(3))
                    curItem = m.videoGrid.content.getChild(m.currentVideoPosition[0] - 1).getChild(3)
                    returnToUIPage()
                    m.videoGrid.jumpToRowItem = [m.currentVideoPosition[0] - 1, 3]
                    m.currentVideoPosition = [m.currentVideoPosition[0] - 1, 3]
                    resolveEvaluatedVideo(curItem)
                  end if
                end if
              else 'Go back by one, not the first video.
                if isValid(m.videoGrid.content.getChild(m.currentVideoPosition[0]).getChild(m.currentVideoPosition[1] - 1))
                  curItem = m.videoGrid.content.getChild(m.currentVideoPosition[0]).getChild(m.currentVideoPosition[1] - 1)
                  returnToUIPage()
                  m.videoGrid.jumpToRowItem = [m.currentVideoPosition[0], m.currentVideoPosition[1] - 1]
                  m.currentVideoPosition = [m.currentVideoPosition[0], m.currentVideoPosition[1] - 1]
                  resolveEvaluatedVideo(curItem)
                end if
              end if
            else if m.videoButtonSelected = "restart"
              restartCurrentVideo()
            else if m.videoButtonSelected = "loop"
              ' Toggle loop for VODs only
              if isValid(m.videoContent) and m.videoContent.Live = false
                m.loopEnabled = not m.loopEnabled
                ' optional UI feedback: briefly bump focus stays on same button
              end if
            else if m.videoButtonSelected = "playPause"
              'Play Button
              if m.video.visible
                showVideoOverlay()
                'Video transition state:
                '0=None, -1=Rewind, 1=FastForward
                if m.videoTransitionState = 0
                  deleteSpinner()
                  if m.video.state = "playing"
                    m.video.control = "pause"
                  else if m.video.state = "paused"
                    m.video.control = "resume"
                  end if
                else
                  m.ffrwTimer.control = "stop"
                  m.ffrwTimer.unobserveField("fire")
                  m.videoTransitionState = 0
                  deleteSpinner()
                  if m.video.control = "stop"
                    m.video.control = "prebuffer"
                    m.video.control = "play"
                  else
                    m.video.control = "pause"
                    m.video.control = "resume"
                  end if
                end if
              end if
            else if m.videoButtonSelected = "nextItem"
              ' Move to the next item in the grid
              if isValid(m.currentVideoPosition)
                if m.currentVideoPosition[1] = 3
                  if isValid(m.videoGrid.content.getChild(m.currentVideoPosition[0] + 1).getChild(0))
                    curItem = m.videoGrid.content.getChild(m.currentVideoPosition[0] + 1).getChild(0)
                    returnToUIPage()
                    m.videoGrid.jumpToRowItem = [m.currentVideoPosition[0] + 1, 0]
                    m.currentVideoPosition = [m.currentVideoPosition[0] + 1, 0]
                    resolveEvaluatedVideo(curItem)
                  end if
                else
                  if isValid(m.videoGrid.content.getChild(m.currentVideoPosition[0]).getChild(m.currentVideoPosition[1] + 1))
                    curItem = m.videoGrid.content.getChild(m.currentVideoPosition[0]).getChild(m.currentVideoPosition[1] + 1)
                    returnToUIPage()
                    m.videoGrid.jumpToRowItem = [m.currentVideoPosition[0], m.currentVideoPosition[1] + 1]
                    m.currentVideoPosition = [m.currentVideoPosition[0], m.currentVideoPosition[1] + 1]
                    resolveEvaluatedVideo(curItem)
                  end if
                end if
              end if
            else if m.videoButtonSelected = "playbackRate"
              ' Keep the focus highlight on the same control when cycling rate
              info = captureVideoButtonsFocus()
              focusIndex = info.index
              cyclePlaybackRate()
              restoreVideoButtonFocus(focusIndex)
            else if m.videoButtonSelected = "like"
              ' Like
              ? "like"
              ? m.wasLoggedIn
              if m.wasLoggedIn
                if m.currentVideoReactions.mine.likes > 0 and m.currentVideoReactions.mine.dislikes = 0
                  setReaction(m.currentVideoClaimID, "negate")
                else
                  setReaction(m.currentVideoClaimID, "negate")
                  setReaction(m.currentVideoClaimID, "like")
                end if
              end if
            else if m.videoButtonSelected = "dislike"
              ? "dislike"
              ? m.wasLoggedIn
              if m.wasLoggedIn
                ' Dislike
                if m.currentVideoReactions.mine.dislikes > 0 and m.currentVideoReactions.mine.likes = 0
                  setReaction(m.currentVideoClaimID, "negate")
                else
                  setReaction(m.currentVideoClaimID, "negate")
                  setReaction(m.currentVideoClaimID, "dislike")
                end if
              end if
            else if m.videoButtonSelected = "toggleChat"
              'TODO: change toggleChat video button's image.
              if m.chatBox.visible
                m.chatBackground.visible = false
                m.chatBox.visible = false
              else
                m.chatBackground.visible = true
                m.chatBox.visible = true
              end if
            end if
            restoreVideoButtonFocus(focusIndex)
          end if
        end if
        ' Enter category from sidebar with OK (same behavior as Right)
        if m.focusedItem = 1 '[selector]
          if m.categorySelector.itemFocused = 0
            m.categorySelector.setFocus(false)
            m.searchKeyboard.setFocus(true)
            m.focusedItem = 3 '[search keyboard]
          else if m.categorySelector.itemFocused = 1 and m.favoritesLoaded and m.favoritesUIFlag and m.focusedItem <> 7
            m.categorySelector.setFocus(false)
            m.videoGrid.setFocus(true)
            m.focusedItem = 2 '[video grid]
          else if m.categorySelector.itemFocused = 1 and m.oauthLogoutButton.visible = true
            m.videoGrid.setFocus(false)
            m.oauthLogoutButton.setFocus(true)
            m.focusedItem = 8 '[oauth logout button]
          else if m.categorySelector.itemFocused > 1 and m.focusedItem <> 7
            m.categorySelector.setFocus(false)
            m.videoGrid.setFocus(true)
            m.focusedItem = 2 '[video grid]
          end if
          return true
        end if
      end if

      if key = "back" 'If the back button is pressed
        if m.video.visible
          returnToUIPage()
          return true
        else if m.itemFocused = 20 '[error button]
          ErrorDismissed()
        else if (m.uiLayer = 0 and m.focusedItem = 1) or (m.uiLayer = 0 and m.focusedItem = 2) 'are favorites or category 1 in focus with no additional UI layers?
          'TODO: add "are you sure you want to exit Odysee" screen
          'for now, re-add old behavior
          'VGM02
          showCategorySelector()
          return false
        else if m.categorySelector.itemFocused <> 0 and m.uiLayer = 0 'is anything but search in focus with no additional UI layers?
          'set focus to selector
          m.uiLayer = 0
          ErrorDismissed()
          m.videoButtons.setFocus(false)
          m.searchKeyboard.setFocus(false)
          m.searchKeyboardDialog.setFocus(false)
          m.searchHistoryBox.setFocus(false)
          m.searchHistoryDialog.setFocus(false)
          m.categorySelector.setFocus(true)
          m.focusedItem = 1 '[selector]
          'VGM02
          showCategorySelector()
          return true
        else if m.uiLayer > 0
          'VGM01
          hideCategorySelector()
          ?"popping layer"
          if m.uiLayers.Count() > 0 'is there more than one UI layer?
            if m.categorySelector.itemFocused = 1 'are favorites in focus?
              m.uiLayer = 0
              m.uiLayers = []
              m.videoGrid.content = m.categories["FAVORITES"]
              showCategorySelector()
            else 'go back a UI layer
              m.uiLayers.pop()
              m.videoGrid.content = m.uiLayers[m.uiLayers.Count() - 1]
              if isValid(m.uiLayers[m.uiLayers.Count() - 1])
                if m.videoGrid.content.getChildren(1, 0)[0].getChildren(1, 0)[0].itemType = "channel" 'if we go back to a Channel search, we should downsize the video grid.
                  downsizeVideoGrid()
                end if
              end if
              m.uiLayer -= 1
              if m.uiLayer = 0
                'VGM02
                showCategorySelector()
              end if
              ?"went back to", m.uiLayer
            end if
          end if
          if m.categorySelector.itemFocused = 0 and m.uiLayers.Count() = 0 'is search in focus, and are there no additional UI layers?
            m.uiLayer = 0
            ?"(search) went back to", m.uiLayer
            backToKeyboard()
          end if
          if m.categorySelector.itemFocused > 1 and m.uiLayers.Count() = 0 'is anything but search in focus, and are there no additional UI layers?
            'this means we have no layers to fall back to, so by default, we should set focus to selector
            m.uiLayer = 0
            ?"(catsel) went back to", m.uiLayer
            ErrorDismissed()
            m.searchKeyboard.setFocus(false)
            m.searchKeyboardDialog.setFocus(false)
            m.searchHistoryBox.setFocus(false)
            m.searchHistoryDialog.setFocus(false)
            m.categorySelector.setFocus(true)
            m.focusedItem = 1 '[selector]
            'VGM02
            showCategorySelector()
          end if
          ' If backing out of a channel page, restore prior grid/search focus and context
          if IsValid(m.currentChannelId) and m.currentChannelId <> ""
            if m.channelReturnContext = "search"
              ' Restore search mode
              m.searchActive = true
              m.searchContext = m.preChannelSearchContext
              ' Re-show search results content if available in uiLayers
              if m.uiLayers.Count() > 0
                m.videoGrid.content = m.uiLayers[m.uiLayers.Count() - 1]
              end if
            else
              ' Ensure category mode
              m.searchActive = false
            end if
            if IsValid(m.channelReturnRowCol) and Type(m.channelReturnRowCol) = "roArray" and m.channelReturnRowCol.Count() >= 2
              m.videoGrid.jumpToRowItem = m.channelReturnRowCol
            end if
            m.videoGrid.setFocus(true)
            m.focusedItem = 2 '[video grid]
            ' Clear channel context and return data
            m.channelReturnRowCol = invalid
            m.channelReturnContext = ""
            m.preChannelSearchActive = false
            m.preChannelSearchContext = { type: "", query: "", from: 0 }
            m.currentChannelId = ""
          end if
          return true
        else if m.uiLayer = 0 'is the first UI layer occupying vgrid? (FALLBACK)
          'this means we have no layers to fall back to, so by default, we should set focus to selector
          'this exists because we still have to fall back to selector even with search.
          ErrorDismissed()
          m.searchKeyboard.setFocus(false)
          m.searchKeyboardDialog.setFocus(false)
          m.searchHistoryBox.setFocus(false)
          m.searchHistoryDialog.setFocus(false)
          m.categorySelector.setFocus(true)
          m.focusedItem = 1 '[selector]
          'VGM02
          showCategorySelector()
          return true
        else
          'default case.
          ErrorDismissed()
          m.searchKeyboard.setFocus(false)
          m.searchKeyboardDialog.setFocus(false)
          m.searchHistoryBox.setFocus(false)
          m.searchHistoryDialog.setFocus(false)
          m.categorySelector.setFocus(true)
          m.focusedItem = 1 '[selector]
          'VGM02
          showCategorySelector()
          return true
        end if
      end if

      if key = "play"
        if isValid(m.video) and isValid(m.videoContent) and m.video.visible and m.videoContent.Live = false
          showVideoOverlay()
          'Video transition state:
          '0=None, -1=Rewind, 1=FastForward
          if m.videoTransitionState = 0
            deleteSpinner()
            if m.video.state = "playing"
              m.video.control = "pause"
            else if m.video.state = "paused"
              m.video.control = "resume"
            end if
                    else
            m.ffrwTimer.control = "stop"
            m.ffrwTimer.unobserveField("fire")
            m.videoTransitionState = 0
            deleteSpinner()
            if m.video.control = "stop"
              m.video.control = "prebuffer"
              m.video.control = "play"
            else
              m.video.control = "pause"
              m.video.control = "resume"
            end if
                    end if
        end if
      end if
      if key = "rewind"
        if m.video.visible and m.videoContent.Live = false
          focusInfo = captureVideoButtonsFocus()
          focusIdx = focusInfo.index
          keepFocus = isVideoButtonsFocused()
          ' Always move focus off the control bar so it cannot react to RW
          m.blockVideoButtonsFocusEvents = true
          m.videoButtonsIndexBeforeSkip = -1
          if keepFocus = true then m.videoButtonsIndexBeforeSkip = focusIdx
          ' Some devices also emit LEFT with RW; swallow the next LEFT if controls were focused
          if keepFocus = true then m.swallowNavKey = "left"
          ' Temporarily disable grid navigation to prevent any internal key handling
          try: m.videoButtons.focusable = false : catch e: end try
          try: m.videoButtons.setFocus(false) : catch e: end try
          try: m.video.setFocus(true) : catch e: end try
          ' Show overlay without changing focus ownership
          showVideoOverlay(false)
          if press = true then
            skipVideo(-m.skipStep)
            if keepFocus and focusIdx >= 0 then restoreVideoButtonFocus(focusIdx)
            ' Re-enable itemFocused events after the skip completes
            m.blockVideoButtonsFocusEvents = false
            try: m.videoButtons.focusable = true : catch e: end try
          else
            ' Key release path: ensure we don't leave events blocked
            m.blockVideoButtonsFocusEvents = false
            try: m.videoButtons.focusable = true : catch e: end try
          end if
          return true
        end if
      end if

      if key = "fastforward"
        if isValid(m.video) and isValid(m.videoContent) and m.video.visible and m.videoContent.Live = false
          focusInfo = captureVideoButtonsFocus()
          focusIdx = focusInfo.index
          keepFocus = isVideoButtonsFocused()
          ' Always move focus off the control bar so it cannot react to FF
          m.blockVideoButtonsFocusEvents = true
          m.videoButtonsIndexBeforeSkip = -1
          if keepFocus = true then m.videoButtonsIndexBeforeSkip = focusIdx
          ' Some devices also emit RIGHT with FF; swallow the next RIGHT if controls were focused
          if keepFocus = true then m.swallowNavKey = "right"
          ' Temporarily disable grid navigation to prevent any internal key handling
          try: m.videoButtons.focusable = false : catch e: end try
          try: m.videoButtons.setFocus(false) : catch e: end try
          try: m.video.setFocus(true) : catch e: end try
          ' Show overlay without changing focus ownership
          showVideoOverlay(false)
          if press = true then
            skipVideo(m.skipStep)
            if keepFocus and focusIdx >= 0 then restoreVideoButtonFocus(focusIdx)
            ' Re-enable itemFocused events after the skip completes
            m.blockVideoButtonsFocusEvents = false
            try: m.videoButtons.focusable = true : catch e: end try
          else
            ' Key release path: ensure we don't leave events blocked
            m.blockVideoButtonsFocusEvents = false
            try: m.videoButtons.focusable = true : catch e: end try
          end if
          return true
        end if
        if press = true and isValid(m.video) and isValid(m.videoContent) and m.video.visible and m.videoContent.Live
          'TODO: change toggleChat video button's image.
          if m.chatBox.visible
            m.chatBackground.visible = false
            m.chatBox.visible = false
          else
            m.chatBackground.visible = true
            m.chatBox.visible = true
          end if
        end if
      end if

      if key = "instantreplay" or key = "instantReplay" then
        if press = true then
          restartCurrentVideo()
        end if
        return true
      end if

      ' Some remotes send "replay" for the physical replay key
      if key = "replay" then
        if isValid(m.video) and m.video.visible
          if press = true then
            restartCurrentVideo()
          end if
          return true
        end if
      end if

      if key = "options"
        if m.focusedItem = 2 '[video grid]  'Options Key Channel Transition.
          'VGM01
          hideCategorySelector()
          row = -1 : col = -1
          if isValid(m.videoGrid) and isValid(m.videoGrid.rowItemFocused) and Type(m.videoGrid.rowItemFocused) = "roArray" and m.videoGrid.rowItemFocused.Count() >= 2
            row = m.videoGrid.rowItemFocused[0]
            col = m.videoGrid.rowItemFocused[1]
          end if
          if row >= 0 and col >= 0
            m.channelReturnRowCol = [row, col]
          else
            m.channelReturnRowCol = invalid
          end if
          if m.searchActive
            m.channelReturnContext = "search"
            m.preChannelSearchActive = m.searchActive
            m.preChannelSearchContext = m.searchContext
          else
            m.channelReturnContext = "category"
          end if
          itemNode = invalid
          if isValid(m.videoGrid) and isValid(m.videoGrid.content) and row >= 0 and col >= 0
            if m.videoGrid.content.getChildCount() > row
              rnode = m.videoGrid.content.getChild(row)
              if isValid(rnode) and rnode.getChildCount() > col
                itemNode = rnode.getChild(col)
              end if
            end if
          end if
          ? "[Options] row="; row; " col="; col
          if isValid(itemNode)
            ' Extract channel claim id from item node (handle field casing variants)
            itemTypeStr = ""
            if isValid(itemNode.ITEMTYPE) and itemNode.ITEMTYPE <> "" then itemTypeStr = itemNode.ITEMTYPE
            if itemTypeStr = "" and isValid(itemNode.itemType) and itemNode.itemType <> "" then itemTypeStr = itemNode.itemType
            ? "[Options] itemType="; itemTypeStr
            ? "[Options] Channel fields => Channel="; itemNode.Channel; " CHANNEL="; itemNode.CHANNEL; " channel="; itemNode.channel
            curChannel = invalid
            if isValid(itemNode.Channel) and itemNode.Channel <> ""
              curChannel = itemNode.Channel
            else if isValid(itemNode.CHANNEL) and itemNode.CHANNEL <> ""
              curChannel = itemNode.CHANNEL
            else if isValid(itemNode.channel) and itemNode.channel <> ""
              curChannel = itemNode.channel
            end if
            ? "[Options] selected curChannel="; curChannel
            if isValid(curChannel) and curChannel <> ""
              m.pendingChannelId = curChannel
              ' Seed channel paging context immediately so autoload can run even before content arrives
              m.currentChannelId = curChannel
              m.currentChannelPage = 1
              m.loadingChannelNext = false
              if not isValid(m.channelResolver)
                m.channelResolver = createObject("roSGNode", "getSingleChannel")
                m.channelResolver.observeField("cookies", "gotCookies")
              end if
              ? "[Options] getSingleChannel.setFields channel="; curChannel
              m.channelResolver.setFields({ constants: m.constants, channel: curChannel, uid: m.uid, cookies: m.cookies })
              m.channelResolver.observeField("output", "gotResolvedChannel")
              m.channelResolver.control = "RUN"
              m.taskRunning = True
              ' Show quick hint while resolving
              m.loadingText.visible = true
              m.loadingText.text = "Opening channel… (press ← to go back)"
              m.videoGrid.setFocus(false)
              m.videoGrid.visible = false
              ' Sidebar thumbnail will be shown in gotResolvedChannel
            end if
          end if
        end if
      end if

      if key = "replay"
        if m.focusedItem = 2 '[video grid]
          if m.categorySelector.itemFocused > 0 and m.uiLayer = 0
            ? "CATEGORY REFRESH"
            if m.categorySelector.itemFocused = 1 and m.wasLoggedIn 'update favorites
              if m.preferences.following.Count() > 0
                m.favoritesThread.setFields({ constants: m.constants, channels: m.preferences.following, blocked: m.preferences.blocked, rawname: "FAVORITES", resolveLivestreams: true, uid: m.uid, cookies: m.cookies })
                m.favoritesThread.observeField("output", "gotFavorites")
                m.favoritesThread.control = "RUN"
              end if
            else
              trueName = m.categorySelector.content.getChild(m.categorySelector.itemFocused).trueName
              ? "would refresh " + trueName
              catData = m.channelIDs[trueName]
              excludedChannelIds = []
              catOrder = "new"
              if isValid(catData.order)
                if Type(catData.order) = "roString"
                  catOrder = catData.order
                end if
              end if
              if isValid(catData.excludedChannelIds)
                if type(catData.excludedChannelId) = "roArray"
                  excludedChannelIds.append(catData.excludedChannelIds)
                end if
              end if
              thread = CreateObject("roSGNode", "getSinglePage")
              if m.wasLoggedIn and m.preferences.Count() > 0
                excludedChannelIds.append(m.preferences.blocked)
                if trueName = "wildwest"
                  catOrder = "trending"
                  ? "is wildwest, resolving livestreams"
                  thread.setFields({ resolveLivestreams: true, sortorder: catOrder, constants: m.constants, channels: catData["channelIds"], rawname: trueName, uid: m.uid, cookies: m.cookies, blocked: excludedChannelIds })
                else
                  thread.setFields({ sortorder: catOrder, constants: m.constants, channels: catData["channelIds"], rawname: trueName, uid: m.uid, cookies: m.cookies, blocked: excludedChannelIds })
                end if
              else
                if trueName = "wildwest"
                  catOrder = "trending"
                  ? "is wildwest, resolving livestreams"
                  thread.setFields({ resolveLivestreams: true, sortorder: catOrder, constants: m.constants, channels: catData["channelIds"], rawname: trueName, uid: m.uid, cookies: m.cookies, blocked: excludedChannelIds })
                else
                  thread.setFields({ sortorder: catOrder, constants: m.constants, channels: catData["channelIds"], rawname: trueName, uid: m.uid, cookies: m.cookies, blocked: excludedChannelIds })
                end if
              end if
              thread.observeField("output", "gotCategoryRefresh")
              thread.control = "RUN"
              'toRefresh = m.categories[trueName]
              'catData = invalid 'save memory
              'catOrder = invalid
              'excludedChannelIds = invalid
            end if

            'This does the same thing as the Back button, so extract the subcomponents for moving up a layer for a regular category and search if this ever needs to be fixed.
          else if m.uiLayer > 0
            ?"popping layer"
            if m.uiLayers.Count() > 0 'is there more than one UI layer?
              if m.categorySelector.itemFocused = 1 'are favorites in focus?
                m.uiLayer = 0
                m.uiLayers = []
                m.videoGrid.content = m.categories["FAVORITES"]
                showCategorySelector()
              else 'go back a UI layer
                m.uiLayers.pop()
                m.videoGrid.content = m.uiLayers[m.uiLayers.Count() - 1]
                if isValid(m.uiLayers[m.uiLayers.Count() - 1])
                  if m.videoGrid.content.getChildren(1, 0)[0].getChildren(1, 0)[0].itemType = "channel" 'if we go back to a Channel search, we should downsize the video grid.
                    downsizeVideoGrid()
                  end if
                end if
                m.uiLayer -= 1
                if m.uiLayer = 0 and m.categorySelector.itemFocused = 0
                  showCategorySelector()
                  backToKeyboard()
                else if m.uiLayer = 0 and m.categorySelector.itemFocused > 0
                  showCategorySelector()
                  trueName = m.categorySelector.content.getChild(m.categorySelector.itemFocused).trueName
                  m.videoGrid.content = m.categories[trueName]
                  m.videoGrid.visible = true
                end if
                ?"went back to", m.uiLayer
              end if
            end if
          end if
        end if
      end if

      if key = "up"
        if m.video.visible
          ' If controls are focused, let grid handle navigation
          if m.focusedItem = 7 and IsValid(m.videoButtons)
            handled = false
            if IsValid(m.videoButtons)
              result = false
              try
                result = m.videoButtons.hasFocus()
              catch e
                result = false
              end try
              if result = true
                return false
              end if
            end if
          end if
          showVideoOverlay()
        end if
        if m.focusedItem = 4 '[confirm search]  'Search -> Keyboard
          m.searchKeyboardDialog.setFocus(false)
          m.searchKeyboard.setFocus(true)
          m.searchKeyboardGrid.jumpToItem = 37
          m.focusedItem = 3 '[search keyboard]
        end if
        if m.focusedItem = 6 '[clear history]  'Clear History -> History
          if m.searchHistoryContent.getChildCount() > 0 'check to make sure we have search history
            m.searchHistoryDialog.setFocus(false)
            m.searchHistoryBox.jumpToItem = m.searchHistoryContent.getChildCount() - 1
            m.searchHistoryBox.setFocus(true)
            m.focusedItem = 5 '[search history list]
          end if
        end if
        if m.focusedItem = 2
          ? m.categorySelector.itemFocused
          ? m.favoritesLoaded
          ? m.videoGrid.rowItemFocused[0]
          ? m.videoGrid.rowItemFocused[1]
          if m.categorySelector.itemFocused = 1 and m.favoritesLoaded and m.videoGrid.rowItemFocused[0] = 0 and m.videoGrid.rowItemFocused[1] = 3
            m.videoGrid.setFocus(false)
            m.oauthLogoutButton.setFocus(true)
            m.focusedItem = 8 '[oauth logout button]
          end if
        end if
      end if

      if key = "down"
        if m.video.visible
          ' If controls are focused, let grid handle navigation
          if m.focusedItem = 7 and IsValid(m.videoButtons)
            handled = false
            if IsValid(m.videoButtons)
              result = false
              try
                result = m.videoButtons.hasFocus()
              catch e
                result = false
              end try
              if result = true
                return false
              end if
            end if
          end if
          hideVideoOverlay()
        end if
        if m.focusedItem = 3 '[search keyboard]
          m.searchKeyboard.setFocus(false)
          m.searchKeyboardDialog.setFocus(true)
          m.focusedItem = 4 '[confirm search]
        end if

        if m.focusedItem = 5 '[search history list]  'History -> Clear
          m.searchHistoryBox.setFocus(false)
          m.searchHistoryDialog.setFocus(true)
          m.focusedItem = 6 '[clear history]
        end if

        if m.focusedItem = 8
          if m.categorySelector.itemFocused = 1 and m.favoritesLoaded
            m.oauthLogoutButton.setFocus(false)
            m.videoGrid.setFocus(true)
            m.focusedItem = 2 '[video grid]
          else if m.categorySelector.itemFocused = 1
            m.oauthLogoutButton.setFocus(false)
            m.categorySelector.setFocus(true)
            m.focusedItem = 1 '[selector]
          end if
        end if
      end if

      if key = "left"
        ' Swallow a synthetic LEFT following RW to prevent selection jump
        if m.swallowNavKey = "left"
          m.swallowNavKey = ""
          return true
        end if
        if m.video.visible
          showVideoOverlay()
        end if
        ' When control bar is active, let MarkupGrid handle left/right navigation
        if m.focusedItem = 7 and IsValid(m.videoButtons) then
          result = false
          try
            result = m.videoButtons.hasFocus()
          catch e
            result = false
          end try
          if result = true
            return false
          end if
        end if
        if m.focusedItem = 2 '[video grid]
          if m.categorySelector.itemFocused = 0
            m.videoGrid.setFocus(false)
            m.videoGrid.visible = false
            m.uiLayer = 0
            m.uiLayers = []
            m.searchHistoryBox.visible = true
            m.searchHistoryLabel.visible = true
            m.searchHistoryDialog.visible = true
            m.searchKeyboard.visible = true
            m.searchKeyboardDialog.visible = true
            m.categorySelector.setFocus(true)
            m.focusedItem = 1 '[selector]
          else if m.uiLayer = 0 'check to make sure we are in UI Layer 0, otherwise, don't bother going back.
            m.videoGrid.setFocus(false)
            m.categorySelector.setFocus(true)
            m.focusedItem = 1 '[selector]
          end if
        end if

        if m.focusedItem = 3 '[search keyboard]  OR m.focusedItem = 4 '[confirm search]  'Exit (Keyboard/Search Button -> Bar)
          row = Int(m.searchKeyboardGrid.currFocusRow) + 1
          if row = m.moveAttemptsRow
            ErrorDismissed()
            m.searchKeyboard.setFocus(false)
            m.searchKeyboardDialog.setFocus(false)
            m.searchHistoryBox.setFocus(false)
            m.searchHistoryDialog.setFocus(false)
            m.categorySelector.jumpToItem = 0
            m.categorySelector.setFocus(true)
            m.focusedItem = 1 '[selector]
          end if
          if m.focusedItem = 1
            m.moveAttemptsRow = 0
          else
            m.moveAttemptsRow = row
          end if
        end if

        if m.focusedItem = 5 and m.errorText.visible = false 'History - Keyboard '[search history list]
          switchRow = m.searchHistoryBox.itemFocused
          if m.searchHistoryBox.itemFocused > 6
            switchRow = 6
          end if
          m.searchHistoryBox.setFocus(false)
          ?"itemArray:", m.searchKeyboardItemArray[switchRow - 1]
          m.searchKeyboardGrid.jumpToItem = m.searchKeyboardItemArray[switchRow]
          switchRow = invalid
          m.focusedItem = 3 '[search keyboard]
          m.searchKeyboard.setFocus(true)
        else if m.focusedItem = 5 and m.errorText.visible = true '[search history list]
          ErrorDismissed()
          m.searchKeyboard.setFocus(false)
          m.searchKeyboardDialog.setFocus(false)
          m.searchHistoryBox.setFocus(false)
          m.searchHistoryDialog.setFocus(false)
          m.categorySelector.jumpToItem = 1
          m.categorySelector.setFocus(true)
          m.focusedItem = 1 '[selector]
        end if
        if m.focusedItem = 6 '[clear history]  'Clear History -> Search
          m.searchHistoryDialog.setFocus(false)
          m.searchKeyboardDialog.setFocus(true)
          m.focusedItem = 4 '[confirm search]
        end if

        if m.focusedItem = 8 and m.favoritesLoaded = false and m.categorySelector.itemFocused = 1
          m.oauthLogoutButton.setFocus(false)
          m.categorySelector.setFocus(true)
          m.focusedItem = 1 '[selector]
        end if
      end if

      if key = "right"
        ' Swallow a synthetic RIGHT following FF to prevent selection jump
        if m.swallowNavKey = "right"
          m.swallowNavKey = ""
          return true
        end if
        if m.video.visible
          showVideoOverlay()
        end if
        ' When control bar is active, let MarkupGrid handle left/right navigation
        if m.focusedItem = 7 and IsValid(m.videoButtons) then
          result = false
          try
            result = m.videoButtons.hasFocus()
          catch e
            result = false
          end try
          if result = true
            return false
          end if
        end if
        if m.focusedItem = 1 and m.categorySelector.itemFocused = 0 '[selector]
          m.focusedItem = 3 '[search keyboard]
          m.categorySelector.setFocus(false)
          m.searchKeyboard.setFocus(true)
          m.focusedItem = 3 '[search keyboard]
        else if m.categorySelector.itemFocused = 1 and m.favoritesLoaded and m.favoritesUIFlag and m.focusedItem <> 7
          m.categorySelector.setFocus(false)
          m.videoGrid.setFocus(true)
          m.focusedItem = 2 '[video grid]
        else if m.categorySelector.itemFocused = 1 and m.oauthLogoutButton.visible = true
          m.videoGrid.setFocus(false)
          m.oauthLogoutButton.setFocus(true)
          m.focusedItem = 8 '[oauth logout button]
        else if m.categorySelector.itemFocused > 1 and m.focusedItem <> 7
          m.categorySelector.setFocus(false)
          m.videoGrid.setFocus(true)
          m.focusedItem = 2 '[video grid]
        end if

        if m.focusedItem = 4 '[confirm search]  'Search -> Clear History
          m.searchKeyboardDialog.setFocus(false)
          m.searchHistoryDialog.setFocus(true)
          m.focusedItem = 6 '[clear history]
        end if

        if m.focusedItem = 3 '[search keyboard]  'Keyboard -> Search History
          column = Int(m.searchKeyboardGrid.currFocusColumn)
          row = Int(m.searchKeyboardGrid.currFocusRow)
          itemFocused = m.searchKeyboardGrid.itemFocused
          ?row, column
          if column = 4 and row = 6 or column = 5
            if m.searchHistoryContent.getChildCount() > 0 'check to make sure we have search history
              if row > m.searchHistoryContent.getChildCount() - 1 'if we are switching to a row above the history count, substitute to the lower value
                m.searchHistoryBox.jumpToItem = m.searchHistoryContent.getChildCount() - 1
              else if row = 6
                m.searchHistoryBox.jumpToItem = m.searchHistoryContent.getChildCount() - 1
              else
                m.searchHistoryBox.jumpToItem = row
              end if
              m.searchKeyboard.setFocus(false)
              m.searchHistoryBox.setFocus(true)
              m.focusedItem = 5 '[search history list]
            end if
          end if
          column = invalid 'free memory
          row = invalid
          itemFocused = invalid
        end if
      end if
    else if key = "A"
      returnToUIPage()
      m.categorySelector.jumpToItem = 0
      m.categorySelector.setFocus(true)
      m.focusedItem = 1 '[selector]
      return true
    else if key = "B"
      returnToUIPage()
      if m.wasLoggedIn
        m.categorySelector.jumpToItem = 1
        m.categorySelector.setFocus(true)
        m.focusedItem = 1 '[selector]
      else
        m.categorySelector.jumpToItem = 2
        m.categorySelector.setFocus(true)
        m.focusedItem = 1 '[selector]
      end if
      return true
      'below used in dev
      '? "oh no."
      'massFollow(return_tremendous_data())
    else
      return true
    end if
  else
    ?"task running, denying user input"
    return true
  end if
end function

sub videoButtonFocused(msg)
  mData = msg.getData()
  ' If FF/RW handling is actively managing focus, ignore transient itemFocused events
  if m.blockVideoButtonsFocusEvents = true then return
  if Type(mData) = "roInt"
    total = -1
    if IsValid(m.videoButtons.content) then total = m.videoButtons.content.getChildCount()
    prevIdxType = Type(m.videoButtonsLastIndex)
    prevIdx = -1
    if (prevIdxType = "roInt" or prevIdxType = "Integer") then prevIdx = m.videoButtonsLastIndex
    newIdx = mData
    ' Detect unnatural edge jumps (likely caused by FF/RW at grid level)
    isEdge = false
    if total > 0 then isEdge = (newIdx = 0 or newIdx = total - 1)
    bigJump = false
    if prevIdx >= 0 and total > 0 then
      if Abs(newIdx - prevIdx) > 1 then bigJump = true
    end if
    if isEdge and bigJump
      ' Immediately revert to previous index to neutralize the grid's FF/RW handling
      if prevIdx >= 0 and prevIdx < total
        m.blockVideoButtonsFocusEvents = true
        try: m.videoButtons.jumpToItem = prevIdx : catch e: end try
        ' keep selection stable
        nodePrev = invalid
        try: nodePrev = m.videoButtons.content.getChild(prevIdx) : catch e: nodePrev = invalid : end try
        if IsValid(nodePrev) and IsValid(nodePrev.itemID)
          m.videoButtonSelected = nodePrev.itemID
        end if
        ' Also perform the intended skip immediately based on which edge was hit
        if newIdx = 0 then
          skipVideo(-m.skipStep)
        else if total > 0 and newIdx = total - 1 then
          skipVideo(m.skipStep)
        end if
        m.blockVideoButtonsFocusEvents = false
        return
      end if
    end if
    ' Normal focus update
    if isValid(m.videoButtons.content.getChildren(-1, 0)[mData].itemID)
      m.videoButtonSelected = m.videoButtons.content.getChildren(-1, 0)[mData].itemID
    end if
    m.videoButtonsLastIndex = newIdx
    ' Keep overlay visible but do not force re-focus here
    showVideoOverlay(true)
  end if
end sub

sub categorySelectorFocusChanged(msg)
  'VGM02
  showCategorySelector()
  '?"[Selector] focus changed from:"
  '?m.categorySelector.itemUnfocused
  '?"to:"
  '?m.categorySelector.itemFocused
  if m.categorySelector.itemFocused <> -1 and m.loaded = True
    m.videoGrid.visible = true
    m.loadingText.visible = false
    if m.categorySelector.itemFocused = 0
      if m.authTask.legacyAuthorized and m.authTask.authPhase = 1 or m.authTask.authPhase = 2
        m.authTask.control = "STOP"
        m.authTaskTimer.control = "stop"
      end if
      ?"in search UI"
      m.videoGrid.visible = false
      m.oauthHeader.visible = false
      m.oauthCode.visible = false
      m.oauthFooter.visible = false
      m.oauthLogoutButton.visible = false
      m.searchHistoryBox.visible = true
      m.searchHistoryLabel.visible = true
      m.searchHistoryDialog.visible = true
      m.searchKeyboard.visible = true
      m.searchKeyboardDialog.visible = true
    end if
    if m.categorySelector.itemFocused = 1
      ?"in following UI"
      ?m.authTask.legacyAuthorized
      ?m.authTask.authPhase
      m.searchHistoryBox.visible = false
      m.searchHistoryLabel.visible = false
      m.searchHistoryDialog.visible = false
      m.searchKeyboard.visible = false
      m.searchKeyboardDialog.visible = false
      m.oauthHeader.visible = false
      m.oauthCode.visible = false
      m.oauthFooter.visible = false
      if m.authTask.authPhase = 3
        if isValid(m.preferences.following) and m.preferences.following.Count() = 0 and m.wasLoggedIn
          m.favoritesLoaded = false
        end if
        if m.favoritesLoaded
          if m.favoritesUIFlag = false
            m.videoGrid.visible = false
            m.oauthLogoutButton.visible = true
          else
            m.videoGrid.content = m.categories["FAVORITES"]
            m.videoGrid.visible = true
            m.loadingText.visible = false
            m.oauthLogoutButton.visible = true
            ' Hook: ensure lives appear immediately when entering Following
            if isValid(m.preferences) and isValid(m.preferences.following)
              if m.preferences.following.Count() > 0
                ? "[Live] entering FAVORITES: merging lives now"
                mergeLiveIntoCategory("FAVORITES", m.preferences.following, 0)
              end if
            end if
          end if
        else
          m.videoGrid.visible = false
          m.oauthHeader.text = "Follow some creators here" + Chr(10) + "or on Odysee.com to" + Chr(10) + "enjoy their latest content!"
          m.oauthHeader.visible = true
          m.oauthLogoutButton.visible = true
        end if
      else if m.authTask.legacyAuthorized and m.authTask.authPhase = 1 or m.authTask.authPhase = 2 and m.authTask.badSSO = false
        m.oauthHeader.text = "Enter"
        m.videoGrid.visible = false
        m.loadingText.visible = false
        m.oauthLogoutButton.visible = false
        m.oauthHeader.visible = true
        m.oauthCode.visible = true
        m.oauthFooter.visible = true
        m.authTask.control = "RUN"
        m.authTaskTimer.control = "start"
      else if m.authTask.authPhase = -1
        ?"Would show error status"
        m.authTask.control = "STOP"
        m.authTaskTimer.control = "stop"
      else if m.authTask.badSSO = true
        m.authTask.authPhase = 1.5
        m.videoGrid.visible = false
        m.loadingText.visible = false
        m.oauthLogoutButton.visible = false
        m.oauthHeader.visible = true
        m.oauthCode.visible = true
        m.oauthFooter.visible = true
        m.oauthHeader.text = "Cannot connect to Accounts"
        m.oauthCode.text = "API-ERR"
        m.oauthFooter.text = "Contact help@odysee.com"
      end if
    end if
    if m.categorySelector.itemFocused > 1
      if m.authTask.legacyAuthorized and m.authTask.authPhase = 1 or m.authTask.authPhase = 2
        m.authTask.control = "STOP"
        m.authTaskTimer.control = "stop"
      end if
      m.oauthLogoutButton.visible = false
      m.oauthHeader.visible = false
      m.oauthCode.visible = false
      m.oauthFooter.visible = false
      m.searchHistoryBox.visible = false
      m.searchHistoryLabel.visible = false
      m.searchHistoryDialog.visible = false
      m.searchKeyboard.visible = false
      m.searchKeyboardDialog.visible = false
      resetVideoGrid()
      m.videoGrid.visible = true
    end if
    if m.categorySelector.itemFocused > 1
      ?m.categorySelector
      ?m.categorySelector.itemFocused
      trueName = m.categorySelector.content.getChild(m.categorySelector.itemFocused).trueName
      m.videoGrid.content = m.categories[trueName]
    end if
    if m.categorySelector.itemFocused < (m.categorySelector.content.getChildren(-1, 0).count() - 1)
      m.categorySelectorEndIndicator.visible = true
    else
      m.categorySelectorEndIndicator.visible = false
    end if
    'base = m.JSONTask.output["PRIMARY_CONTENT"]
    'm.videoGrid.content = base["content"]
  end if
end sub

sub showVideoOverlay(keepButtonFocus = true as boolean)
  m.chatBackground.height = "780"
  m.chatBox.height = "780"
  m.videoUITimer.control = "stop"
  m.videoUITimer.unobserveField("fire")
  m.videoUITimer.duration = 5
  m.videoUITimer.observeField("fire", "hideVideoOverlay")
  m.videoUITimer.control = "start"
  restoreIndex = -1
  shouldRestore = false
  if keepButtonFocus then
    info = captureVideoButtonsFocus()
    if info.hadFocus and info.index >= 0 then
      restoreIndex = info.index
      shouldRestore = true
    end if
  end if
  if IsValid(m.videoOverlayGroup) then m.videoOverlayGroup.visible = true
  if shouldRestore then
    restoreVideoButtonFocus(restoreIndex)
    m.focusedItem = 7 '[video player/overlay]
  else if not keepButtonFocus then
    if IsValid(m.videoButtons) then
      try: m.videoButtons.setFocus(false) : catch e: end try
    end if
    try: m.video.setFocus(true) : catch e: end try
  else
    ' No prior focused button but caller wants button focus: move focus to preferred index
    idx = getPreferredVideoButtonsIndex()
    restoreVideoButtonFocus(idx)
    m.focusedItem = 7 '[video player/overlay]
    ' Ensure current selection is set so OK works immediately
    if IsValid(m.videoButtons) and IsValid(m.videoButtons.content)
      if idx >= 0 and idx < m.videoButtons.content.getChildCount()
        node = m.videoButtons.content.getChild(idx)
        if IsValid(node) and IsValid(node.itemID)
          m.videoButtonSelected = node.itemID
        end if
      end if
    end if
  end if
end sub

sub hideVideoOverlay()
  m.chatBackground.height = "980"
  m.chatBox.height = "980"
  m.videoUITimer.control = "stop"
  m.videoUITimer.unobserveField("fire")
  m.videoOverlayGroup.visible = false
end sub

sub resetVideoGrid()
  m.videoGrid.itemSize = [1920, 365]
  m.videoGrid.rowitemSize = [[380, 350]]
end sub

sub downsizeVideoGrid()
  m.videoGrid.itemSize = [1920, 305]
  m.videoGrid.rowitemSize = [[380, 280]]
end sub

sub failedSearch(errortype)
  ?"search failed"
  m.videoGrid.visible = false
  m.videoSearch.control = "STOP"
  m.channelSearch.control = "STOP"
  m.taskRunning = False
  ?"task stopped"
  if errortype = "noResults"
    Error("No results.", "Nothing found on Odysee.")
  else if errortype = "lighthouseError"
    Error("Search server error", "Search may be down at this time.")
  else if errortype = "claimSearchError"
    Error("Claim_search error", "Please e-mail help@odysee.com ASAP.")
  else if errortype = "parseError"
    Error("Parsing error", "Recieved invalid or malformed data from Odysee.")
  end if
end sub

sub handleInputEvent(msg)
  '?"in handleInputEvent()"
  if type(msg) = "roSGNodeEvent" and msg.getField() = "inputData"
    deeplink = msg.getData()
    if deeplink <> invalid
      ?"Got deeplink"
      ?deeplink
      m.global.deeplink = deeplink
    end if
  end if
end sub

sub Error(title, error)
  m.searchKeyboard.visible = False
  m.searchHistoryDialog.visible = False
  m.searchKeyboardDialog.visible = false
  m.searchHistoryLabel.visible = false
  m.searchHistoryBox.visible = False
  m.loadingText.visible = False
  m.errorText.text = title
  m.errorSubtext.text = error
  m.errorText.visible = true
  m.errorSubtext.visible = true
  m.errorButton.visible = true
  m.focusedItem = 20 '[error button]
  m.errorButton.observeField("buttonSelected", "ErrorDismissed")
  m.errorButton.setFocus(true)
end sub

sub ErrorDismissed()
  m.errorText.visible = false
  m.errorSubtext.visible = false
  m.errorButton.visible = false
  m.errorButton.unobserveField("buttonSelected")
  m.searchKeyboard.text = ""
  if m.searchFailed = true
    backToKeyboard()
  else if m.UILayers.Count() = 0
    resetVideoGrid()
    showCategorySelector()
    m.videoGrid.visible = true
    m.errorButton.setFocus(false)
    m.focusedItem = 2
    m.videoGrid.setFocus(true)
  else
    m.videoGrid.visible = True
    m.errorButton.setFocus(false)
    m.focusedItem = 2
    m.videoGrid.setFocus(true)
  end if
end sub

sub retryError(title, error, action)
  m.searchKeyboard.visible = False
  m.searchHistoryDialog.visible = False
  m.searchKeyboardDialog.visible = false
  m.searchHistoryLabel.visible = false
  m.searchHistoryBox.visible = False
  m.loadingText.visible = False
  m.errorText.text = title
  m.errorSubtext.text = error
  m.errorText.visible = true
  m.errorSubtext.visible = true
  m.errorButton.visible = true
  m.errorButton.observeField("buttonSelected", action)
  m.errorButton.setFocus(true)
end sub

sub resolveError()
  m.taskRunning = false
  m.loadingText.visible = False
  m.videoGrid.setFocus(false)
  m.videoGrid.visible = False
  m.errorText.text = "Error: Could Not Resolve Claim"
  m.errorSubtext.text = "This video may be newly uploaded or temporarily unavailable. Try again."
  m.errorText.visible = true
  m.errorSubtext.visible = true
  m.errorButton.visible = true
  ' Present a retry option for resolve failures
  m.errorButton.text = "Retry"
  m.errorButton.unobserveField("buttonSelected")
  m.errorButton.observeField("buttonSelected", "retryResolve")
  m.errorButton.setFocus(true)
end sub


sub userPrefsError()
  m.taskRunning = false
  m.getpreferencesTask.unobserveField("preferences")
  m.getpreferencesTask.unobserveField("error")
  m.getpreferencesTask.control = "STOP"
  Logout()
  Error("Cannot get/parse preferences", "Please e-mail help@odysee.com.")
end sub

sub syncLoopError()
  m.wasLoggedIn = false
  m.syncLoop.control = "STOP"
  m.syncLoopTimer.unobserveField("fire")
  m.authTask.authPhase = 1.6
  m.authTask.badSSO = true
end sub

sub setPreferencesError()
  m.taskRunning = false
  m.setpreferencesTask.unobserveField("preferences")
  m.setpreferencesTask.unobserveField("error")
  m.setpreferencesTask.control = "STOP"
  Logout()
  Error("Cannot set/parse preferences", "Please e-mail help@odysee.com.")
end sub

sub malformedVideoError()
  m.taskRunning = false
  m.loadingText.visible = False
  m.videoGrid.setFocus(false)
  m.videoGrid.visible = False
  m.errorText.text = "Error: Video is corrupt/malformed."
  m.errorSubtext.text = "Uploader: https://lbry.com/faq/video-publishing-guide"
  m.errorText.visible = true
  m.errorSubtext.visible = true
  m.errorButton.visible = true
  m.errorButton.observeField("buttonSelected", "resolveerrorDismissed")
  m.errorButton.setFocus(true)
end sub

sub resolveErrorDismissed()
  if m.videoObserved = false
    m.video.observeField("state", "onVideoStateChanged")
  end if
  m.errorButton.setFocus(false)
  m.errorButton.unobserveField("buttonSelected")
  m.errorButton.text = "OK"
  m.errorText.visible = false
  m.errorSubtext.visible = false
  m.errorButton.visible = false
  m.videoGrid.visible = True
  m.videoGrid.setFocus(true)
end sub

' Re-run the video URL resolver after a temporary resolve failure
sub retryResolve()
  ' Hide error UI and restore default button text
  m.errorButton.setFocus(false)
  m.errorButton.unobserveField("buttonSelected")
  m.errorButton.text = "OK"
  m.errorText.visible = false
  m.errorSubtext.visible = false
  m.errorButton.visible = false

  url = ""
  title = ""
  ' Prefer the last resolver URL if available
  if isValid(m.urlResolver) and isValid(m.urlResolver.url)
    url = m.urlResolver.url
  end if
  if (not isValid(url)) or url = ""
    ' Fallback: derive from current grid selection
    if isValid(m.currentVideoPosition) and Type(m.currentVideoPosition) = "roArray" and m.currentVideoPosition.Count() >= 2
      row = m.currentVideoPosition[0]
      col = m.currentVideoPosition[1]
      if isValid(m.videoGrid) and isValid(m.videoGrid.content)
        if m.videoGrid.content.getChildCount() > row
          rnode = m.videoGrid.content.getChild(row)
          if isValid(rnode) and rnode.getChildCount() > col
            itemNode = rnode.getChild(col)
            if isValid(itemNode) and isValid(itemNode.URL)
              url = itemNode.URL
              if isValid(itemNode.TITLE) then title = itemNode.TITLE
            end if
          end if
        end if
      end if
    end if
  end if
  if (not isValid(url)) or url = ""
    ' Nothing to retry; dismiss error
    resolveErrorDismissed()
    return
  end if

  ' Re-run the resolver with appropriate auth
  if m.wasLoggedIn
    m.urlResolver.setFields({ constants: m.constants, url: url, title: title, uid: m.uid, accesstoken: m.accessToken, authToken: "", cookies: m.cookies })
  else
    m.urlResolver.setFields({ constants: m.constants, url: url, title: title, uid: m.uid, accesstoken: "", authToken: m.authToken, cookies: m.cookies })
  end if
  m.urlResolver.observeField("output", "playResolvedVideo")
  m.urlResolver.control = "RUN"
  m.taskRunning = True
  m.loadingText.visible = true
  m.loadingText.text = "Retrying…"
  m.videoGrid.setFocus(false)
end sub

sub cleanupToUIPage() 'more aggressive returnToUIPage, until I recreate the UI loop
  m.urlResolver.control = "STOP"
  m.channelResolver.control = "STOP"
  m.constantsTask.control = "STOP"
  m.ws.control = "STOP"
  m.videoSearch.control = "STOP"
  m.channelSearch.control = "STOP"
  m.authTask.control = "STOP"
  m.cidsTask.control = "STOP"
  if m.video.visible
    returnToUIPage()
    ErrorDismissed()
  else
    ErrorDismissed()
    returnToUIPage()
  end if
  m.taskRunning = false
  m.categorySelector.jumpToItem = 1
  m.categorySelector.setFocus(true)
  m.focusedItem = 1
end sub

sub backToKeyboard()
  'VGM02
  showCategorySelector()
  resetVideoGrid()
  m.taskRunning = false
  m.searchKeyboard.visible = True
  m.searchKeyboardDialog.visible = True
  m.searchKeyboardGrid.visible = True
  m.searchHistoryLabel.visible = True
  m.searchHistoryBox.visible = True
  m.searchKeyboardDialog.visible = True
  m.searchHistoryDialog.visible = True
  m.videoGrid.visible = False
  m.loadingText.visible = False
  m.loadingText.text = "Loading..."
  m.searchKeyboard.setFocus(true)
  m.focusedItem = 3 '[search keyboard]
end sub

sub vgridContentChanged(msg as object)
  if type(msg) = "roSGNodeEvent" and msg.getField() = "content"
    m.videoGrid.content = msg.getData()
  end if
end sub

'sub gotvGridPosition(iEvent)
'  ? "vGrid Position Changed"
'  incomingData = iEvent.getData()
'  if incomingData.Count() > 1
'    m.currentVideoPosition = incomingData
'    ? m.currentVideoPosition
'  end if
'end sub

sub resolveVideo(url = invalid)
  ?type(url)
  if type(url) = "roSGNodeEvent" 'we might actually pass a URL (string) through to this as well.
    incomingData = url.getData()
    if type(incomingData) = "roArray"
      if incomingData.Count() > 1
        m.currentVideoPosition = incomingData
        curItem = m.videoGrid.content.getChild(incomingData[0]).getChild(incomingData[1])
        ' Capture current item guid for robust return
        if IsValid(curItem) and IsValid(curItem.guid) then m.currentVideoGuid = curItem.guid
        if curItem.itemType = "video"
          resolveEvaluatedVideo(curItem) 'used for this AND next video/previous video
        end if
        if curItem.itemType = "channel"
          ?"Resolving a Channel"
          if not isValid(m.channelResolver)
            m.channelResolver = createObject("roSGNode", "getSingleChannel")
            m.channelResolver.observeField("cookies", "gotCookies")
          end if
          if isValid(curitem.channel)
            m.channelResolver.setFields({ constants: m.constants, channel: curitem.channel, uid: m.uid, cookies: m.cookies })
            m.channelResolver.observeField("output", "gotResolvedChannel")
            m.channelResolver.control = "RUN"
          end if
          m.taskRunning = True
          m.videoGrid.setFocus(false)
          m.videoGrid.visible = false
          m.loadingText.visible = true
          m.loadingText.text = "Resolving Channel..."
        end if
        if curItem.itemType = "livestream"
          ?"Playing a livestream"
          m.currentVideoChannelIcon = curItem.channelicon
          ? curItem.channelicon
          m.currentVideoChannelID = curItem.channel 'Current claim ID for Video's Channel
          m.currentVideoClaimID = curItem.guid 'Current claim ID for Video
          isFollowed = false
          if m.wasLoggedIn
            m.videoButtons.content = createBothItemsIdentified(m.videoButtons, m.liveButtonsLoggedIn, m.videoButtons.itemSize)
            m.videoButtons.itemSpacing = "[36, 20]"
            m.videoButtons.animateToItem = 2
            getReactions(curItem.guid)
            m.videoButtons.animateToItem = 3
            if m.preferences.Count() > 0 and isValid(m.preferences.following)
              if m.preferences.following.Count() > 0
                for each claimID in m.preferences.following
                  if claimID = m.currentVideoChannelID
                    ? "This user is being followed."
                    isFollowed = true
                  end if
                end for
              end if
            end if
            regenerateLiveButtonRefs()
            m.videoButtonsRate = invalid
            if isFollowed
              m.videoButtonsFollowingIcon.posterUrl = "pkg:/images/generic/Heart-selected.png"
            else
              m.videoButtonsFollowingIcon.posterUrl = "pkg:/images/png/Heart.png"
            end if
          else
            m.videoButtons.content = createBothItemsIdentified(m.videoButtons, m.liveButtonsLoggedOut, m.videoButtons.itemSize)
            m.videoButtons.itemSpacing = "[36, 20]"
            m.videoButtons.animateToItem = 2
            regenerateLiveButtonRefs()
            m.videoButtonsRate = invalid
          end if
          m.videoButtonsChannelIcon.posterUrl = m.currentVideoChannelIcon
          isFollowed = invalid
          m.videoContent.url = curItem.URL
          m.videoContent.streamFormat = curItem.streamFormat
          m.videoContent.title = curItem.description
          m.videoContent.Live = true
          m.lastKnownVideoPos = 0
          updatePlaybackRateUI("")
          applyPlaybackRate()
          m.video.content = m.videoContent
          m.video.visible = true
          m.videoProgressBar.visible = false 'its live, we don't need progress updates.
          m.videoProgressBarp1.visible = false
          m.videoProgressBarp2.visible = false
          ' Do not force focus here; the Video keeps focus on initial play
          m.focusedItem = 7 '[video player/overlay]
          m.video.control = "play"
          m.refreshes = 0
          m.videoVP = 0
          m.video.observeField("duration", "liveDurationChanged")
          ?m.video.errorStr
          ?m.video.videoFormat
          ?m.video
          m.videoButtons.animateToItem = 3
          observeFields("ws", { "on_close": "on_close",
            "on_error": "on_error",
            "chat": "on_chat",
          "superchat": "on_superchat" })
          if isValid(m.preferences)
            ' Build secure chat URL using canonical handle and short id from signing_channel
            chatBase = m.constants["CHAT_API"]
            catParam = ""
            try
              if isValid(curitem.chatCategory) and curitem.chatCategory <> ""
                catParam = curitem.chatCategory
              else
                ' Fallback to @handle:shortId derived from channel id (first 1 char) if canonical missing
                handle = ""
                if isValid(curitem.rawCreator) and curitem.rawCreator <> "" then handle = curitem.rawCreator
                sid = ""
                if isValid(m.currentVideoChannelID) and m.currentVideoChannelID <> "" then sid = Left(m.currentVideoChannelID, 1)
                if handle <> "" and sid <> "" then catParam = handle + ":" + sid
              end if
            catch e
            end try
            catEnc = catParam
            try: catEnc = catParam.EncodeUriComponent() : catch e: end try
            openUrl = chatBase + "/commentron?id=" + m.currentVideoClaimID + "&category=" + catEnc + "&sub_category=viewer"
            ' Prepare WS headers as array pairs (Origin/Referer)
            wsHeaders = []
            try
              origin$ = "https://odysee.com"
              referer$ = "https://roku.odysee.com/"
              if isValid(m.constants["ACCESS_HEADERS"]) and isValid(m.constants["ACCESS_HEADERS"]["origin"]) then origin$ = m.constants["ACCESS_HEADERS"]["origin"]
              if isValid(m.constants["ACCESS_HEADERS"]) and isValid(m.constants["ACCESS_HEADERS"]["referer"]) then referer$ = m.constants["ACCESS_HEADERS"]["referer"]
              wsHeaders = ["Origin", origin$, "Referer", referer$]
            catch e
              wsHeaders = []
            end try
            if isValid(m.preferences.blocked)
              m.ws.setFields({ "blocked": m.preferences.blocked, "constants": m.constants, "open": openUrl, "streamclaim": m.currentVideoClaimID, "channelid": m.currentVideoChannelID, "protocols": [], "headers": wsHeaders, uid: m.uid })
            else
              m.ws.setFields({ "constants": m.constants, "open": openUrl, "streamclaim": m.currentVideoClaimID, "channelid": m.currentVideoChannelID, "protocols": [], "headers": wsHeaders, "uid": m.uid })
            end if
            ? "[WS] built url="; openUrl
          end if
          ? m.ws.open
          ? "[WS] open="; m.ws.open
          ? "[WS] streamClaim="; m.currentVideoClaimID; " channelId="; m.currentVideoChannelID
          ? "[WS] category param should be @handle:shortId"
          m.ws.control = "RUN"
          m.chatBox.visible = true
          m.chatBackground.visible = true
          m.videoGrid.setFocus(false)
        end if
      end if
    end if
  else if type(url) = "roString" or type(url) = "String"
    ?"Resolving a Video (deeplink direct)"
    if m.wasLoggedIn
      m.videoButtons.content = createBothItemsIdentified(m.videoButtons, m.standardButtonsLoggedIn, m.videoButtons.itemSize)
      m.videoButtons.itemSpacing = "[36, 20]"
      m.videoButtons.animateToItem = 3
      regenerateNormalButtonRefs()
      ensureDefaultVideoButtonsIndex()
  else
    m.videoButtons.content = createBothItemsIdentified(m.videoButtons, m.standardButtonsLoggedOut, m.videoButtons.itemSize)
    m.videoButtons.itemSpacing = "[36, 20]"
    m.videoButtons.animateToItem = 3
    ensureDefaultVideoButtonsIndex()
    regenerateNormalButtonRefs()
  end if
    resetProgressUI(0)
    m.lastKnownVideoPos = 0
    m.scrubTarget = 0
    m.skipHoldCount = 0
    m.skipHoldDirection = 0
    if m.wasLoggedIn
      m.urlResolver.setFields({ constants: m.constants, url: url, title: "deeplink video", uid: m.uid, cookies: m.cookies, accesstoken: m.accessToken, authtoken: "" })
    else
      m.urlResolver.setFields({ constants: m.constants, url: url, title: "deeplink video", uid: m.uid, cookies: m.cookies, accessToken: "", authtoken: m.authToken })
    end if
    m.urlResolver.observeField("output", "playResolvedVideo")
    m.urlResolver.control = "RUN"
    m.taskRunning = True
    m.videoGrid.setFocus(false)
  end if
end sub

sub resolveEvaluatedVideo(curItem)
  ?"Resolving a Video"
  m.currentVideoChannelIcon = curitem.channelicon
  m.currentVideoChannelID = curItem.channel 'Current claim ID for Video's Channel
  m.currentVideoClaimID = curItem.guid 'Current claim ID for Video
  m.currentVideoGuid = curItem.guid ' For grid restoration
  isFollowed = false
  if m.wasLoggedIn
    ' Choose live vs VOD button sets; exclude restart/loop on livestreams
    if isValid(curItem.streamFormat) and LCase(curItem.streamFormat) = "hls"
      m.videoButtons.content = createBothItemsIdentified(m.videoButtons, m.liveButtonsLoggedIn, m.videoButtons.itemSize)
      m.videoButtons.itemSpacing = "[36, 20]"
      m.videoButtons.animateToItem = 2
      regenerateLiveButtonRefs()
    else
      m.videoButtons.content = createBothItemsIdentified(m.videoButtons, m.standardButtonsLoggedIn, m.videoButtons.itemSize)
      m.videoButtons.itemSpacing = "[36, 20]"
      getReactions(curItem.guid)
      m.videoButtons.animateToItem = 4
      regenerateNormalButtonRefs()
      ensureDefaultVideoButtonsIndex()
    end if
    if m.preferences.Count() > 0 and isValid(m.preferences.following)
      if m.preferences.following.Count() > 0
        for each claimID in m.preferences.following
          if claimID = m.currentVideoChannelID
            ? "This user is being followed."
            isFollowed = true
          end if
        end for
      end if
    end if
    regenerateNormalButtonRefs()
    if isFollowed
      m.videoButtonsFollowingIcon.posterUrl = "pkg:/images/generic/Heart-selected.png"
    else
      m.videoButtonsFollowingIcon.posterUrl = "pkg:/images/png/Heart.png"
    end if
  else
    if isValid(curItem.streamFormat) and LCase(curItem.streamFormat) = "hls"
      m.videoButtons.content = createBothItemsIdentified(m.videoButtons, m.liveButtonsLoggedOut, m.videoButtons.itemSize)
      m.videoButtons.itemSpacing = "[36, 20]"
      m.videoButtons.animateToItem = 2
      regenerateLiveButtonRefs()
    else
      m.videoButtons.content = createBothItemsIdentified(m.videoButtons, m.standardButtonsLoggedOut, m.videoButtons.itemSize)
      m.videoButtons.itemSpacing = "[36, 20]"
      m.videoButtons.animateToItem = 3
      regenerateNormalButtonRefs()
      ensureDefaultVideoButtonsIndex()
    end if
  end if
  if m.wasLoggedIn
    m.urlResolver.setFields({ constants: m.constants, url: curitem.URL, title: curItem.TITLE, uid: m.uid, accesstoken: m.accessToken, authToken: "", cookies: m.cookies })
  else
    m.urlResolver.setFields({ constants: m.constants, url: curitem.URL, title: curItem.TITLE, uid: m.uid, accesstoken: "", authToken: m.authToken, cookies: m.cookies })
  end if
  resetProgressUI(0)
  m.lastKnownVideoPos = 0
  m.scrubTarget = 0
  m.skipHoldCount = 0
  m.skipHoldDirection = 0
  m.urlResolver.observeField("output", "playResolvedVideo")
  m.urlResolver.control = "RUN"
  m.taskRunning = True
  m.videoGrid.setFocus(false)
  m.videoGrid.visible = false
  m.loadingText.visible = true
  m.loadingText.text = "Loading Video..."
  ? "made it here"
end sub

sub liveDurationChanged() 'ported from salt app, this (mostly) fixes the problem that livestreams do not start at live.
  ?m.video.position
  ?m.video.duration
  if m.refreshes = 0
    m.chatBox.visible = true
    m.chatBackground.visible = true
    m.superChatBox.visible = true
    m.superChatBackground.visible = true
  end if
  m.refreshes += 1
  if m.video.duration > 0 and m.videoContent.Live and m.video.position < m.video.duration and m.refreshes < 4
    m.video.seek = m.video.duration + 80
  end if
  if m.refreshes > 4
    m.video.unobserveField("duration")
    m.refreshes = invalid
  end if
end sub

sub videoPositionChanged()
  try: m.lastKnownVideoPos = m.video.position : catch e: end try
  m.scrubTarget = m.lastKnownVideoPos
  if m.global.constants.enableStatistics 'if position/duration changes, report if vStats are turned on.
    if m.vStatsTimer.TotalSeconds() > 5
      ' Avoid flooding the watchman task; only run if it is not already running
      if not isValid(m.watchman) or m.watchman.state <> "run"
        m.vStatsTimer.Mark()
        if isValid(m.video) and isValid(m.video.playStartInfo) and isValid(m.urlResolver) and isValid(m.urlResolver.output)
          if m.video.playStartInfo.prebuf_dur > 10
            cache = "miss"
          else
            cache = "player"
          end if
          protocol = "stb"
          if isValid(m.urlResolver.output.videotype)
            protocol = m.urlResolver.output.videotype.replace("mp4", "stb")
          end if
          duration = 0
          if isValid(m.urlResolver.output.length)
            duration = m.urlResolver.output.length
          end if
          player = ""
          if isValid(m.urlResolver.output.player)
            player = m.urlResolver.output.player
          end if
          urlStr = ""
          if isValid(m.urlResolver.url)
            urlStr = m.urlResolver.url
          end if
          bitrate = 0
          if isValid(m.video.streamInfo) and isValid(m.video.streamInfo.measuredBitrate)
            bitrate = m.video.streamInfo.measuredBitrate
          end if
          watchmanFields = { constants: m.constants, uid: m.uid, cookies: m.cookies, bandwidth: bitrate, cache: cache, duration: duration, player: player, position: m.video.position, protocol: protocol, rebuf_count: 0, rebuf_duration: 0, url: urlStr, uid: m.uid }
          m.watchman.setFields(watchmanFields)
          m.watchman.control = "RUN"
        end if
      end if
    end if
  end if
  'change video UI
  if m.videoProgressBar.visible = true and m.videoProgressBarp1.visible = true and m.videoProgressBarp2.visible = true
    totalLen = 0
    if isValid(m.urlResolver) and isValid(m.urlResolver.output) and isValid(m.urlResolver.output.length)
      totalLen = m.urlResolver.output.length
    end if
    m.videoProgressBarp1.text = getvideoLength(m.video.position)
    if m.video.position > 0 and totalLen > 0
      m.videoProgressBar.width = 1290 * (m.video.position / totalLen)
    end if
    if totalLen > 0
      m.videoProgressBarp2.text = getvideoLength(totalLen + 1 - m.video.position)
    end if
  end if
  ' Save resume point every ~10 seconds
  if isValid(m.currentVideoClaimID)
    if not isValid(m.resumeTimer) then m.resumeTimer = CreateObject("roTimeSpan")
    if m.resumeTimer.TotalSeconds() >= 10
      m.resumeTimer.Mark()
      resumeKey = "resume-" + m.currentVideoClaimID
      SetRegistry("resumeRegistry", resumeKey, m.video.position.ToStr())
    end if
  end if
end sub

sub changeVideoPosition()
  totalLen = 0
  if isValid(m.urlResolver) and isValid(m.urlResolver.output) and isValid(m.urlResolver.output.length)
    totalLen = m.urlResolver.output.length
  end if
  if m.videoVP = 0
    m.videoVP = m.video.position
  end if
  if totalLen <= 0
    return
  end if
  if m.videoTransitionState > 0 and abs(m.videoTransitionState) < m.videoTransitionStateLimit
    '1 second only on 1x/finegrain
    if m.videoVP + 1 <= totalLen
      m.video.seek = m.videoVP + 1
      m.videoVP += 1
      if m.videoVP > 0
        m.videoProgressBar.width = 1290 * (m.videoVP / totalLen)
      end if
      m.videoProgressBarp1.text = getvideoLength(m.videoVP)
      m.videoProgressBarp2.text = getvideoLength(totalLen + 1 - m.videoVP)
    end if

  else if m.videoTransitionState > 0 and abs(m.videoTransitionState) >= m.videoTransitionStateLimit

    '2+ seconds on coarser
    videoScrubSpeed = (Abs(m.videoTransitionState) - 4) * 2
    if m.videoVP + videoScrubSpeed <= totalLen
      m.video.seek = m.videoVP + videoScrubSpeed
      m.videoVP += videoScrubSpeed
      if m.videoVP > 0
        m.videoProgressBar.width = 1290 * (m.videoVP / totalLen)
      end if
      m.videoProgressBarp1.text = getvideoLength(m.videoVP)
      m.videoProgressBarp2.text = getvideoLength(totalLen + videoScrubSpeed - m.videoVP)
    end if

  else if m.videoTransitionState < 0 and abs(m.videoTransitionState) < m.videoTransitionStateLimit

    '1 second only on 1x/finegrain

    if m.videoVP - 1 >= 0
      m.video.seek = m.videoVP - 1
      m.videoVP = m.videoVP - 1
      if m.videoVP > 0
        m.videoProgressBar.width = 1290 * (m.videoVP / totalLen)
      end if
      m.videoProgressBarp1.text = getvideoLength(m.videoVP)
      m.videoProgressBarp2.text = getvideoLength(totalLen - 1 - m.videoVP)
    end if

  else if m.videoTransitionState < 0 and abs(m.videoTransitionState) >= m.videoTransitionStateLimit

    '2+ seconds on coarser
    videoScrubSpeed = (Abs(m.videoTransitionState) - 4) * 2
    if m.videoVP - videoScrubSpeed >= 0
      m.video.seek = m.videoVP - videoScrubSpeed
      m.videoVP = m.videoVP - videoScrubSpeed
      if m.videoVP > 0
        m.videoProgressBar.width = 1290 * (m.videoVP / totalLen)
      end if
      m.videoProgressBarp1.text = getvideoLength(m.videoVP)
      m.videoProgressBarp2.text = getvideoLength(totalLen - videoScrubSpeed - m.videoVP)
    end if
    videoScrubSpeed = invalid
  end if
end sub

sub watchmanRan(msg as object)
  if type(msg) = "roSGNodeEvent"
    data = msg.getData()
    ?formatJson(data)
    m.watchman.control = "STOP"
  end if
end sub

sub playResolvedVideo(msg as object)
  if type(msg) = "roSGNodeEvent"
    data = msg.getData()
    if isValid(data.error)
      m.urlResolver.unobserveField("output")
      m.urlResolver.control = "STOP"
      m.taskRunning = False
      resolveError()
    else if isValid(data.length) = false
      malformedVideoError()
    else
      m.videoGrid.visible = true
      m.videoGrid.setFocus(false)
      m.categorySelector.setFocus(false)
      m.video.setFocus(true)
      m.loadingText.visible = false
      ?"VPLAYDEBUG:"
      ?formatJSON(data)
      'preset video length in UI
      resetProgressUI(data.length)
      m.lastKnownVideoPos = 0
      m.scrubTarget = 0
      m.skipHoldCount = 0
      m.skipHoldDirection = 0
      if m.videoEndingTimeSet = false
        m.videoProgressBarp2.text = getvideoLength(data.length)
        m.videoEndingTimeSet = true
      end if
      m.videoContent.url = data.videourl.Unescape()
      ?m.videoContent.url
      m.videoContent.streamFormat = data.videotype
      m.videoContent.title = data.title 'passthrough title
      m.videoContent.Live = false
      m.video.content = m.videoContent
      m.videoVP = 0
      m.video.visible = true
      m.videoProgressBar.visible = true
      m.videoProgressBarp1.visible = true
      m.videoProgressBarp2.visible = true
      ' Keep focus on Video; overlay will show without stealing focus
      ' m.video.setFocus(false)
      ' m.videoButtons.setFocus(true)
      m.focusedItem = 7 '[video player/overlay]
      updatePlaybackRateUI(m.playbackRateLabels[m.playbackRateIndex])
      applyPlaybackRate()
      m.video.control = "play"
      ' Attempt to resume from saved position
      m.pendingResume = -1
      if isValid(m.currentVideoClaimID)
        resumeKey = "resume-" + m.currentVideoClaimID
        saved = GetRegistry("resumeRegistry", resumeKey)
        if isValid(saved)
          seconds = StrToI(saved)
          if seconds > 0 and seconds < data.length - 15
            m.pendingResume = seconds
          end if
        end if
      end if
      if m.pendingResume > 0
        m.video.seek = m.pendingResume
      end if
      m.video.observeField("position", "videoPositionChanged")
      ?m.video.errorStr
      ?m.video.videoFormat
      ?m.video
      m.urlResolver.unobserveField("output")
      m.urlResolver.control = "STOP"
      m.taskRunning = False
    end if
  end if
end sub

function getvideoLength(length)
  timeConverter = CreateObject("roDateTime")
  timeConverter.FromSeconds(length)
  days = timeConverter.GetDayOfMonth().ToStr()
  hours = timeConverter.GetHours().ToStr()
  minutes = timeConverter.GetMinutes().ToStr()
  seconds = timeConverter.GetSeconds().ToStr()
  result = ""
  if timeConverter.GetDayOfMonth() < 10
    days = "0" + timeConverter.GetDayOfMonth().ToStr()
  end if
  if timeConverter.GetHours() < 10
    hours = "0" + timeConverter.GetHours().ToStr()
  end if
  if timeConverter.GetMinutes() < 10
    minutes = "0" + timeConverter.GetMinutes().ToStr()
  end if
  if timeConverter.GetSeconds() < 10
    seconds = "0" + timeConverter.GetSeconds().ToStr()
  end if
  if length < 3600
    'use minute format
    result = minutes + ":" + seconds
  end if
  if length >= 3600 and length < 86400
    result = hours + ":" + minutes + ":" + seconds
  end if
  if length >= 86400 'TODO: make videos above month length display proper length
    result = days + ":" + hours + ":" + minutes + ":" + seconds
  end if
  timeConverter = invalid
  days = invalid
  hours = invalid
  minutes = invalid
  seconds = invalid
  return result
end function

function onVideoStateChanged(msg as object)
  if type(msg) = "roSGNodeEvent" and msg.getField() = "state"
    state = msg.getData()
    ?"==========VIDEO STATE==========="
    ?state
    if state = "error"
      m.video.unobserveField("state")
      m.videoObserved = false
      m.videoButtons.setFocus(false)
      m.currentVideoChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
      m.videoButtonsChannelIcon.posterUrl = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
      m.videoProgressBar.width = 0
      m.videoOverlayGroup.visible = false
      m.videoUITimer.control = "stop"
      m.videoUITimer.unobserveField("fire")
      m.video.unObserveField("position")
      m.video.visible = false 'Hide video
      m.video.control = "stop" 'Stop video from playing
      deleteSpinner()
      malformedVideoError()
    end if
    if state = "finished"
      deleteSpinner()
      if m.global.constants.enableStatistics
        m.video.unobserveField("position")
      end if
      m.video.unobserveField("duration")
      ' Clear resume on completion
      if isValid(m.currentVideoClaimID)
        resumeKey = "resume-" + m.currentVideoClaimID
        SetRegistry("resumeRegistry", resumeKey, "0")
      end if
      if m.loopEnabled = true and isValid(m.videoContent) and m.videoContent.Live = false
        ' Loop current video: seek to 0 and play again
        try: m.video.seek = 0 : catch e: end try
        m.video.control = "play"
        return invalid
      end if
      m.currentVideoChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
      m.videoButtonsChannelIcon.posterUrl = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
      m.videoProgressBar.width = 0
      returnToUIPage()
    end if
    if state = "playing" or state = "buffering"
      if m.videoContent.Live = false
        m.videoButtonsPlayIcon.labelText = m.vjschars["pause"]
        m.videoButtonsPlayIcon.fontUrl = "pkg:/components/generic/fonts/VideoJS.ttf"
        m.videoButtonsPlayIcon.fontSize = m.videoButtons.content.getChildren(-1, 0)[2]["fontSize"] 'borrow precalculated fontsize from neighbor
        ?m.currentVideoChannelIcon
        ?m.videoButtonsChannelIcon
        if m.videoButtonsChannelIcon.posterUrl = "pkg:/images/generic/bad_icon_requires_usage_rights.png" and m.currentVideoChannelIcon <> "pkg:/images/generic/bad_icon_requires_usage_rights.png"
          m.videoButtonsChannelIcon.posterUrl = m.currentVideoChannelIcon
        end if
      end if
      if state = "playing"
        deleteSpinner()
        applyPlaybackRate()
        'm.videoTransitionState = 0
      else if state = "buffering"
        addSpinner()
      end if
    else if state = "paused"
      if m.videoContent.Live = false
        m.videoButtonsPlayIcon.labelText = m.vjschars["play"]
        m.videoButtonsPlayIcon.fontUrl = "pkg:/components/generic/fonts/VideoJS.ttf"
        m.videoButtonsPlayIcon.fontSize = m.videoButtons.content.getChildren(-1, 0)[2]["fontSize"] 'borrow precalculated fontsize from neighbor
      end if
    end if
  else if type(msg) = "roSGNodeEvent"
    ? msg.getData()
  end if
end function

sub addSpinner()
  if isValid(m.busySpinner) = false
    m.busySpinner = m.top.createChild("BusySpinner")
  end if
  m.busySpinner.poster.uri = "pkg:/images/generic/spaceman.png"
  m.busySpinner.translation = [870, 450]
  m.busySpinner.visible = true
end sub

sub deleteSpinner()
  if isValid(m.busySpinner)
    m.busySpinner.visible = false
    m.top.removeChild(m.busySpinner)
    m.busySpinner = invalid
  end if
end sub

sub returnToUIPage()
  m.videoButtons.setFocus(false)
  m.currentVideoChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
  m.videoButtonsChannelIcon.posterUrl = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
  m.videoProgressBar.width = 0
  m.ws.unobserveField("on_close")
  m.ws.unobserveField("on_chat")
  m.ws.unobserveField("on_error")
  m.ws.unobserveField("thumbnailCache")
  m.ws.unobserveField("messageHeights")
  m.ws.unobserveField("superchat")
  if m.videoContent.streamFormat = "hls"
    m.reinitialize = false
    m.ws.close = [1000, "livestreamStopped"]
    m.ws.control = "STOP"
  end if
  m.superChatBox.visible = false
  m.superChatBackground.visible = false
  m.chatBox.visible = false
  m.chatBackground.visible = false
  m.chatBox.text = ""
  m.superChatArray = []
  m.superChatBox.text = ""
  m.videoOverlayGroup.visible = false
  m.videoUITimer.control = "stop"
  m.videoUITimer.unobserveField("fire")
  m.video.visible = false 'Hide video
  m.video.control = "stop" 'Stop video from playing
  resetProgressUI(0)
  m.lastKnownVideoPos = 0
  m.scrubTarget = 0
  m.skipHoldCount = 0
  m.skipHoldDirection = 0
  deleteSpinner()
  if m.focusedItem = 7
    m.videoEndingTimeSet = false
    m.video.unObserveField("position")
    if IsValid(m.videoGrid)
      m.loadingText.visible = false
      m.videoGrid.visible = true
      m.videoGrid.setFocus(true)
      m.focusedItem = 2 '[video grid]
      ' Try to jump back by GUID first (robust to paging/refresh)
      jumpPos = invalid
      if IsValid(m.currentVideoGuid)
        jumpPos = findGridIndexByGuid(m.currentVideoGuid)
      end if
      if not IsValid(jumpPos)
        jumpPos = m.currentVideoPosition
      end if
      if IsValid(jumpPos) and Type(jumpPos) = "roArray" and jumpPos.Count() >= 2
        row = jumpPos[0]
        col = jumpPos[1]
        if row >= 0 and col >= 0 and IsValid(m.videoGrid.content)
          if m.videoGrid.content.getChildCount() > row
            rnode = m.videoGrid.content.getChild(row)
            if IsValid(rnode) and rnode.getChildCount() > col
              m.videoGrid.jumpToRowItem = [row, col]
            end if
          end if
        end if
      end if
    else
      if IsValid(m.categorySelector)
        m.categorySelector.setFocus(true)
        m.focusedItem = 1 '[selector]
      end if
    end if
  end if
end sub

sub search()
  if m.searchKeyboard.text = "" or Len(m.searchKeyboard.text) < 3
    m.searchFailed = true
    Error("Search too short", "Needs to be more than 2 characters long.")
  else
    ?"======SEARCH======"
    if m.searchHistoryContent.getChildCount() = 0 or m.searchHistoryContent.getChild(0).title <> m.searchKeyboard.text 'don't re-add items that already exist
      if m.searchHistoryContent.getChildCount() >= 8
        m.searchHistoryContent.removeChildIndex(8) 'removeChildIndex is basically pop
        m.searchHistoryItems.pop()
        item = createObject("roSGNode", "ContentNode")
        item.title = m.searchKeyboard.text
        m.searchHistoryContent.insertChild(item, 0) 'basically unshift
        m.searchHistoryItems.unshift(m.searchKeyboard.text)
      else
        item = createObject("roSGNode", "ContentNode")
        item.title = m.searchKeyboard.text
        m.searchHistoryContent.insertChild(item, 0) 'basically unshift
        m.searchHistoryItems.unshift(m.searchKeyboard.text)
      end if
    end if
    ?"======SEARCH======"
    SetRegistry("searchHistoryRegistry", "searchHistory", FormatJSON(m.searchHistoryItems))
    if m.searchKeyboardDialog.itemSelected = 0 or m.searchKeyboardDialog.itemSelected = -1
      ?"video search"
      m.searchType = "video"
    else if m.searchKeyboardDialog.itemSelected = 1
      ?"channel search"
      m.searchType = "channel"
    end if
    execSearch(m.searchKeyboard.text, m.searchType)
  end if
end sub

sub execSearch(search, searchType)
  ?"Valid Input"
  'search starting
  ?search, searchType
  if searchType = "video"
    ?"will run video search."
    m.videoSearch.setFields({ constants: m.constants, search: search, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies, rawname: "VSEARCH" })
    m.videoSearch.observeField("output", "gotVideoSearch")
    m.videoSearch.control = "RUN"
    m.taskRunning = True
    m.searchKeyboard.visible = False
    m.searchHistoryDialog.visible = False
    m.searchKeyboardDialog.visible = false
    m.searchHistoryLabel.visible = false
    m.searchHistoryBox.visible = False
    m.loadingText.visible = true
    m.loadingText.text = "Loading your search results.."
  end if
  if searchType = "channel"
    ?"will run channel search."
    ' Persist last channel search term for paging
    m.lastChannelSearchQuery = search
    if m.wasLoggedIn
      m.channelSearch.setFields({ constants: m.constants, search: search, uid: m.uid, authtoken: m.authtoken, accessToken: m.accessToken, authToken: "", cookies: m.cookies, rawname: "CSEARCH" })
    else
      m.channelSearch.setFields({ constants: m.constants, search: search, uid: m.uid, authtoken: m.authtoken, accessToken: "", authToken: m.authToken, cookies: m.cookies, rawname: "CSEARCH" })
    end if
    m.channelSearch.observeField("output", "gotChannelSearch")
    m.channelSearch.control = "RUN"
    ' Make channel rows taller to avoid follower text overlap
    try
      m.videoGrid.rowItemSize = [[410,420]]
      m.videoGrid.itemSize = [1920,440]
    catch e
    end try
    m.taskRunning = True
    m.searchKeyboard.visible = False
    m.searchHistoryDialog.visible = False
    m.searchKeyboardDialog.visible = false
    m.searchHistoryLabel.visible = false
    m.searchHistoryBox.visible = False
    m.loadingText.visible = true
    m.loadingText.text = "Loading your search results.."
  end if
end sub

sub gotVideoSearch(msg as object)
  if type(msg) = "roSGNodeEvent"
    data = msg.getData()
    if data.success = true
      m.videoSearch.unobserveField("output")
      ' Render Lighthouse-backed grid immediately
      if isValid(data.result) and isValid(data.result.content)
      m.videoGrid.content = data.result.content
      end if
      m.videoSearch.control = "STOP"
      m.taskRunning = False
      m.videoGrid.visible = true
      m.loadingText.visible = false
      ' Set search context for autoload
      m.searchActive = true
      m.searchContext = { type: "video": query: m.searchKeyboard.text: from: 0 }
      ' Restore standard row heights for video search
      try
        m.videoGrid.rowItemSize = [[410,380]]
        m.videoGrid.itemSize = [1920,400]
      catch e
      end try
      ' Clear any channel paging context
      m.currentChannelId = ""
      m.currentChannelPage = 1
      m.loadingChannelNext = false
      m.focusedItem = 2 '[video grid]
      if isValid(m.uiLayers[m.uiLayers.Count() - 1])
        previousData = m.uiLayers[m.uiLayers.Count() - 1]
        currentData = data.result.content
        prevTitle = ""
        currTitle = ""
        if isValid(currentData) and currentData.getChildCount() > 0
          row = currentData.getChild(0)
          if isValid(row) and row.getChildCount() > 0
            item0 = row.getChild(0)
            if isValid(item0) and isValid(item0.TITLE)
              currTitle = item0.TITLE
            end if
          end if
        end if
        if isValid(previousData) and previousData.getChildCount() > 0
          prow = previousData.getChild(0)
          if isValid(prow) and prow.getChildCount() > 0
            pitem0 = prow.getChild(0)
            if isValid(pitem0) and isValid(pitem0.TITLE)
              prevTitle = pitem0.TITLE
            end if
          end if
        end if
        if prevTitle <> currTitle
          m.uiLayers.push(currentData) 'so we can go back a layer when someone hits back.
          m.uiLayer += 1
          'VGM01
          hideCategorySelector()
        end if
      else
        m.uiLayers.push(data.result.content) 'so we can go back a layer when someone hits back.
        m.uiLayer += 1
        'VGM01
        hideCategorySelector()
      end if
      m.videoGrid.setFocus(true)
      ' When user enters a category, refresh lives in the background and update in place
      if isValid(m.allLiveTask)
        m.allLiveTask.setField("constants", m.constants)
        m.allLiveTask.control = "RUN"
      end if
    else
      m.searchFailed = true
      failedSearch(m.videoSearch.output.errorType)
    end if
  end if
end sub

sub gotChannelSearch(msg as object)
  if type(msg) = "roSGNodeEvent"
    data = msg.getData()
    ?data
    if data.success = true
      downsizeVideoGrid()
      m.channelSearch.unobserveField("output")
      'if msg
      m.videoGrid.content = data.content
      m.channelSearch.control = "STOP"
      m.taskRunning = False
      m.videoGrid.visible = true
      m.loadingText.visible = false
      ' Set search context for autoload (use last query to support history selection)
      m.searchActive = true
      if not IsValid(m.lastChannelSearchQuery) or m.lastChannelSearchQuery = "" then m.lastChannelSearchQuery = m.searchKeyboard.text
      m.searchContext = { type: "channel": query: m.lastChannelSearchQuery: from: 0 }
      ' Ensure taller rows for channel search tiles
      try
        m.videoGrid.rowItemSize = [[410,420]]
        m.videoGrid.itemSize = [1920,440]
      catch e
      end try
      ' Clear any channel paging context
      m.currentChannelId = ""
      m.currentChannelPage = 1
      m.loadingChannelNext = false
      m.focusedItem = 2 '[video grid]
      if isValid(m.uiLayers[m.uiLayers.Count() - 1])
        previousData = m.uiLayers[m.uiLayers.Count() - 1]
        currentData = data.content
        previousDataChildTitle = currentData.getChildren(1, 0)[0].getChildren(1, 0)[0].TITLE
        currentDataChildTitle = previousData.getChildren(1, 0)[0].getChildren(1, 0)[0].TITLE
        if previousDataChildTitle <> currentDataChildTitle
          m.uiLayers.push(data.content) 'so we can go back a layer when someone hits back.
          m.uiLayer += 1
          'VGM01
          hideCategorySelector()
        end if
      else
        m.uiLayers.push(data.content) 'so we can go back a layer when someone hits back.
        m.uiLayer += 1
        'VGM01
        hideCategorySelector()
      end if
      m.videoGrid.setFocus(true)
    else
      m.channelSearch.unobserveField("output")
      m.searchFailed = true
      failedSearch(m.channelSearch.output.errorType)
    end if
  end if
end sub

sub gotResolvedChannel(msg as object)
  if type(msg) = "roSGNodeEvent"
    data = msg.getData()
    if isValid(data.error)
      m.channelResolver.unobserveField("output")
      m.channelResolver.control = "STOP"
      m.taskRunning = false
      ? "[Channel] resolve error; showing fallback"
      if m.uiLayers.Count() > 0
        m.videoGrid.content = m.uiLayers[0]
        failedSearch(m.channelresolver.output.errorType)
      else
        failedSearch(m.channelresolver.output.errorType)
      end if
    else
      m.videoGrid.visible = true
      m.loadingText.visible = false
      resetVideoGrid()
      m.channelResolver.unobserveField("output")
      ' Seed channel context from pending ID, in case parse yields empty
      if IsValid(m.pendingChannelId) and m.pendingChannelId <> ""
        m.currentChannelId = m.pendingChannelId
      end if
      if isValid(data.content) and data.content.getChildCount() > 0
      m.videoGrid.content = data.content
      else
        ? "[Channel] empty content; showing hint"
        hint = createObject("roSGNode","ContentNode")
        row = createObject("roSGNode","ContentNode")
        item = createObject("roSGNode","ContentNode")
        item.addFields({ TITLE: "No items found", itemType: "channel" })
        row.appendChild(item)
        hint.appendChild(row)
        m.videoGrid.content = hint
        ' If we know the channel ID, proactively prefetch next page to avoid blank grid
        if IsValid(m.currentChannelId) and m.currentChannelId <> ""
          if m.loadingChannelNext = false
            m.loadingChannelNext = true
            nextChPage = 2
            ct = CreateObject("roSGNode","getChannelNextPage")
            ct.setFields({ constants: m.constants, channel: m.currentChannelId, page: nextChPage, uid: m.uid })
            ct.observeField("output","onChannelNextPageLoaded")
            ct.control = "RUN"
            m.currentChannelPage = nextChPage
            ? "[Channel] Prefetch dispatch page=" + Str(nextChPage)
          end if
        end if
      end if
      ' Always start channel pages at the first tile to avoid carrying prior grid position
      try: m.videoGrid.jumpToRowItem = [0, 0] : catch e: end try
      m.channelResolver.control = "STOP"
      m.taskRunning = False
      m.focusedItem = 2 '[video grid]
      ' Record channel context for autoload; prefer pending ID, then parsed content
      if not IsValid(m.currentChannelId) or m.currentChannelId = ""
        if IsValid(m.pendingChannelId) and m.pendingChannelId <> ""
          m.currentChannelId = m.pendingChannelId
        end if
      end if
      try
        if isValid(data.content) and data.content.getChildCount() > 0
          r0 = data.content.getChild(0)
          if isValid(r0) and r0.getChildCount() > 0
            it0 = r0.getChild(0)
            if isValid(it0) and IsValid(it0.Channel) and it0.Channel <> ""
              m.currentChannelId = it0.Channel
            end if
          end if
        end if
      catch e
      end try
      ch$ = "": if IsValid(m.currentChannelId) then ch$ = m.currentChannelId
      ? "[Channel] context channelId=" + ch$
      m.currentChannelPage = 1
      m.loadingChannelNext = false
      ' Exiting any prior search context when entering a channel
      m.searchActive = false
      m.searchContext = { type: "": query: "": from: 0 }
      if isValid(m.uiLayers[m.uiLayers.Count() - 1])
        ? "last layer is valid"
        previousData = m.uiLayers[m.uiLayers.Count() - 1]
        currentData = data.content
        prevTitle = ""
        currTitle = ""
        if isValid(currentData) and currentData.getChildCount() > 0
          row = currentData.getChild(0)
          if isValid(row) and row.getChildCount() > 0
            item0 = row.getChild(0)
            if isValid(item0) and isValid(item0.TITLE)
              currTitle = item0.TITLE
            end if
          end if
        end if
        if isValid(previousData) and previousData.getChildCount() > 0
          prow = previousData.getChild(0)
          if isValid(prow) and prow.getChildCount() > 0
            pitem0 = prow.getChild(0)
            if isValid(pitem0) and isValid(pitem0.TITLE)
              prevTitle = pitem0.TITLE
            end if
          end if
        end if
        if prevTitle <> currTitle
          m.uiLayers.push(currentData) 'so we can go back a layer when someone hits back.
          m.uiLayer += 1
          'VGM01
          hideCategorySelector()
        end if
      else
        ? "default state"
        m.uiLayers.push(data.content) 'so we can go back a layer when someone hits back.
        m.uiLayer += 1
        'VGM01
        hideCategorySelector()
      end if
      m.videoGrid.setFocus(true)
      ' Show channel thumbnail in the sidebar for context
      try
        thumb = m.channelResolver.ChannelIcon
        if isValid(thumb) and thumb <> ""
          if Left(thumb, 4) = "http"
            m.channelSidebarThumb.uri = thumb
          else
            m.channelSidebarThumb.uri = m.constants["CHANNEL_ICON_PROCESSOR"] + thumb
          end if
          m.channelSidebarThumb.visible = true
        else
          m.channelSidebarThumb.visible = false
        end if
      catch e
        m.channelSidebarThumb.visible = false
      end try
    end if
  end if
end sub

function createBothItems(buttons, items, itemSize) as object
  data = CreateObject("roSGNode", "ContentNode")
  buttons.numColumns = items.Count()
  for each item in items
    if item.split(":")[0] = "http" or item.split(":")[0] = "https" or item.split(":")[0] = "pkg"
      dataItem = data.CreateChild("horizontalButtonItemData")
      dataItem.fontUrl = ""
      dataItem.posterUrl = item
      dataItem.width = itemSize[0]
      dataItem.height = itemSize[1]
      dataItem.backgroundColor = "0x00000000"
      dataItem.outlineColor = "0xFFFFFFFF"
      dataItem.labelText = ""
    else
      dataItem = data.CreateChild("horizontalButtonItemData")
      if item.split("").Count() < 2
        dataItem.fontUrl = "pkg:/components/generic/fonts/VideoJS.ttf"
        dataItem.fontSize = (itemSize[1] / 64) * 60
      else
        dataItem.fontUrl = "pkg:/components/generic/fonts/Inter-Emoji.otf"
        dataItem.fontSize = (itemSize[1] / 64) * 35
      end if
      dataItem.posterUrl = ""
      dataItem.width = itemSize[0]
      dataItem.height = itemSize[1]
      dataItem.backgroundColor = "0x00000000"
      dataItem.outlineColor = "0xFFFFFFFF"
      dataItem.labelText = item
    end if
  end for
  return data
end function

function createBothItemsIdentified(buttons, items, itemSize) as object
  'item = {item: "item", id: "itemID"}
  data = CreateObject("roSGNode", "ContentNode")
  buttons.numColumns = items.Count()
  for each item in items
    if item.item.split(":")[0] = "http" or item.item.split(":")[0] = "https" or item.item.split(":")[0] = "pkg"
      dataItem = data.CreateChild("horizontalButtonItemData")
      dataItem.posterUrl = item.item
      dataItem.width = itemSize[0]
      dataItem.height = itemSize[1]
      dataItem.backgroundColor = "0x00000000"
      dataItem.outlineColor = "0xFFFFFFFF"
      dataItem.labelText = ""
      dataItem["itemID"] = item.itemid
    else
      dataItem = data.CreateChild("horizontalButtonItemData")
      fontScale = itemSize[1] / 64
      if fontScale <= 0 then fontScale = 1
      if Len(item.item) = 1
        dataItem.fontUrl = "pkg:/components/generic/fonts/VideoJS.ttf"
        dataItem.fontSize = fontScale * 60
      else
        dataItem.fontUrl = "pkg:/components/generic/fonts/Inter-Emoji.otf"
        if Len(item.item) <= 3
          dataItem.fontSize = fontScale * 42
        else
          dataItem.fontSize = fontScale * 30
        end if
      end if
      dataItem.posterUrl = ""
      dataItem.width = itemSize[0]
      dataItem.height = itemSize[1]
      dataItem.backgroundColor = "0x00000000"
      dataItem.outlineColor = "0xFFFFFFFF"
      dataItem.labelText = item.item
      dataItem["itemID"] = item.itemid
    end if
  end for
  return data
end function

sub historySearch()
  ?"======HISTORY SEARCH======"
  ?m.searchKeyboardDialog.itemFocused
  if m.searchKeyboardDialog.itemFocused = 0 or m.searchKeyboardDialog.itemFocused = -1
    ?"video search"
    m.searchType = "video"
  else if m.searchKeyboardDialog.itemFocused = 1
    ?"channel search"
    m.searchType = "channel"
  end if
  execSearch(m.searchHistoryContent.getChildren(-1, 0)[m.searchHistoryBox.itemSelected].TITLE, m.searchType)
  ?"======HISTORY SEARCH======"
end sub

sub clearHistory()
  m.searchHistoryItems.Clear()
  SetRegistry("searchHistoryRegistry", "searchHistory", FormatJSON(m.searchHistoryItems))
  if m.searchHistoryContent.removeChildrenIndex(-1, 0) <> true
    cCount = m.searchHistoryContent.getChildCount()
    for item = 0 to cCount
      m.searchHistoryContent.removeChildIndex(0)
    end for
  end if
end sub

sub hideCategorySelector()
  m.categorySelector.visible = false
  m.sidebarTrim.visible = false
  m.sidebarBackground.visible = false
  if isValid(m.channelSidebarThumb) then m.channelSidebarThumb.visible = false
  m.categorySelectorEndIndicator.visible = false
  m.videoGrid.translation = [110, 120]
end sub

sub showCategorySelector()
  if isValid(m.categorySelector.content) and m.loadingBackground.visible = false
    m.videoGrid.translation = [210, 120]
    m.categorySelector.visible = true
    m.sidebarTrim.visible = true
    m.sidebarBackground.visible = true
    if isValid(m.channelSidebarThumb) then m.channelSidebarThumb.visible = false
    if m.categorySelector.itemFocused < (m.categorySelector.content.getChildren(-1, 0).count() - 1)
      m.categorySelectorEndIndicator.visible = true
    else
      m.categorySelectorEndIndicator.visible = false
    end if
  end if
end sub

sub didInstall(msg as object)
  if type(msg) = "roSGNodeEvent"
    ?"============================GOT ACCT DATA:======================================="
    ?formatJSON(msg.getData())
    m.rokuInstall.control = "STOP"
    m.rokuInstall.unobserveField("output")
    ?"============================GOT ACCT DATA:======================================="
  end if
end sub

function on_close(event as object) as void
  print "WebSocket closed"
  if m.reinitialize
    m.ws.open = m.SERVER
  end if
end function

function on_chat(event as object) as void
  eData = event.getData()
  if isValid(edata)
    m.chatBox.text = edata.raw.join(Chr(10) + Chr(10))
  end if
end function

function on_superchat(event as object) as void
  if isValid(event.getData())
    ? "superchat changed"
    m.superChatBox.visible = true
    m.superChatBackground.visible = true
    m.superChatArray = event.getData()
    m.superChatBox.text = m.superchatArray.join(" | ")
  end if
end function

' Socket Error event
function on_error(event as object) as void
  print "WebSocket error"
  print event.getData()
  if m.reinitialize
    m.ws.open = m.SERVER
  end if
end function

'Registry+Utility Functions

'AuthTask (deviceflow/reg)-related functions
sub gotUID(msg as object)
  m.flowUID = msg.getData()
  m.uid = msg.getData()
  SetRegistry("deviceFlowRegistry", "flowUID", m.flowUID.toStr().Trim())
  SetRegistry("authRegistry", "uid", m.uid.toStr().Trim())
end sub

sub gotAuth(msg as object)
  auth = msg.getData()
  ?"[gotAuth] Token should be " + auth
  m.authToken = auth
  SetRegistry("authRegistry", "authtoken", m.authtoken)
end sub

sub refreshAuth(msg as object)
  m.authTask.control = "RUN"
  m.authTask.observeField("output", "didRefresh")
end sub

sub didRefresh(msg as object)
  m.authTask.control = "STOP"
  'data = msg.getData()
  '?data
  m.authTask.unObserveField("output")
  m.authTimerObserved = false
end sub

sub gotRokuCode(msg as object)
  m.oauthCode.text = msg.getData()
  ' If user is viewing Following, surface the OAuth UI immediately
  if m.categorySelector.itemFocused = 1 and m.uiLayer = 0
    m.oauthHeader.text = "Enter"
    m.videoGrid.visible = false
    m.loadingText.visible = false
    m.oauthLogoutButton.visible = false
    m.oauthHeader.visible = true
    m.oauthCode.visible = true
    m.oauthFooter.visible = true
  end if
end sub

sub gotAccessToken(msg as object)
  m.accessToken = msg.getData()
  ?"accessToken is", m.accessToken
  SetRegistry("deviceFlowRegistry", "accessToken", m.accessToken)
end sub

sub gotRefreshToken(msg as object)
  m.refreshToken = msg.getData()
  SetRegistry("deviceFlowRegistry", "refreshToken", m.refreshToken)
end sub

sub Logout()
  ?"Running Logout"
  m.wasLoggedIn = false
  m.favoritesUIFlag = false
  m.favoritesLoaded = false
  m.loadingText.visible = false
  m.syncLoop.control = "STOP"
  m.syncLoopTimer.unobserveField("fire")
  m.syncTimerObserved = false
  videoFocused = false
  if m.focusedItem = 7
    videoFocused = true
  end if
  m.categorySelector.setFocus(true)
  ' Force OAuth device-code UI immediately on logout
  m.focusedItem = 1
  m.uiLayer = 0
  m.uiLayers = []
  m.categorySelector.jumpToItem = 1
  if m.video.visible = false
    m.videoGrid.visible = false
    m.oauthLogoutButton.visible = false
    m.oauthHeader.text = "Enter"
    m.oauthHeader.visible = true
    m.oauthCode.text = ""
    m.oauthCode.visible = true
    m.oauthFooter.visible = true
  end if
  if videoFocused = true
    m.focusedItem = 7
    ' Keep any current focus; do not force control-bar focus here
    videofocused = invalid
  end if
  m.preferences = {}
  m.favoritesLoaded = false
  m.favoritesUIFlag = false
  m.categories.delete("FAVORITES")
  m.flowUID = ""
  m.accessToken = ""
  m.refreshToken = ""
  m.wallet = { "oldHash": "asdf", "walletData": "asdf" }
  m.syncLoop.setFields({ "accessToken": m.accessToken, "oldHash": "", "walletData": "" })
  SetRegistry("deviceFlowRegistry", "flowUID", "")
  setRegistry("preferencesRegistry", "loggedIn", "false")
  SetRegistry("deviceFlowRegistry", "accessToken", "")
  SetRegistry("deviceFlowRegistry", "refreshToken", "")
  setRegistry("preferencesRegistry", "preferences", "{}")
  SetRegistry("deviceFlowRegistry", "walletOldHash", "")
  SetRegistry("deviceFlowRegistry", "walletData", "")
  if m.authTask.authPhase = 3
    m.authTask.authPhase = 10 'logout
    m.authTask.control = "RUN"
    m.authTaskTimer.control = "start"
  else
    ' Jump straight to device-code init for fastest UX
    m.authTask.authPhase = 1.4
    m.authTask.control = "RUN"
    m.authTaskTimer.control = "start"
  end if
end sub

'Sync Task related functions (post auth)
sub getSync()
  if m.setpreferencesTask.state <> "run" and m.setpreferencesTask.state <> "init"
    ?"GETSYNC DEBUG"
    ?m.syncLoop.inSync
    ?m.wasLoggedIn
    ?m.favoritesLoaded
    ?"GETSYNC DEBUG"
    if m.preferences.Count() = 0 and m.syncLoop.inSync = true and m.wasLoggedIn and m.syncLoop.accessToken <> ""
      getUserPrefs()
    else if m.syncLoop.accessToken = "" 'logged out, stop loop. (fixes wasLoggedIn race condition)
      m.syncLoop.control = "STOP"
    else 'get in sync first
      ? "NOT IN SYNC"
      m.syncLoop.control = "STOP"
      m.syncLoop.control = "RUN"
    end if
  end if
end sub

'These relink the references to the buttons when switching between Live and VOD

sub regenerateNormalButtonRefs()
  if not IsValid(m.videoButtons) or not IsValid(m.videoButtons.content) then return
  for each key in m.standardVideoButtonNameTable
    name = m.standardVideoButtonNameTable[key]
    m[name] = invalid
  end for
  for each child in m.videoButtons.content.getChildren(-1, 0)
    if isValid(m.standardVideoButtonNameTable[child.itemID])
      m[m.standardVideoButtonNameTable[child.itemID]] = child
    end if
  end for
  if IsValid(m.playbackRateLabels)
    updatePlaybackRateUI(m.playbackRateLabels[m.playbackRateIndex])
  end if
end sub

sub regenerateLiveButtonRefs()
  for each child in m.videoButtons.content.getChildren(-1, 0)
    if isValid(m.liveVideoButtonNameTable[child.itemID])
      m[m.liveVideoButtonNameTable[child.itemID]] = child
    end if
  end for
end sub

sub gotSync(msg as object)
  data = msg.getData()
  m.syncLoop.control = "STOP"
  ?"GOTSyncDebug"
  if m.preferences.Count() = 0 or m.favoritesLoaded = false
    getUserPrefs()
  end if
end sub

sub preferencesChanged()
  if m["syncloop"]["inSync"] and m["syncloop"]["preferencesChanged"]
    getUserPrefs()
    m["syncloop"]["preferencesChanged"] = false
  end if
end sub

'User Preference related tasks
sub getUserPrefs()
  ?"attempting to get user preferences"
  m.getpreferencesTask.setFields({ "accessToken": m.accessToken: uid: m.syncLoop.uid })
  m.getpreferencesTask.observeField("preferences", "gotUserPrefs")
  m.getpreferencesTask.observeField("error", "userPrefsError")
  m.getpreferencesTask.control = "RUN"
end sub

sub gotUserPrefs()
  m.getpreferencesTask.control = "STOP"
  favoritesChanged = false
  oldpreferences = m.preferences
  newpreferences = m.getpreferencesTask.preferences
  if m.focusedItem = 1 and m.categorySelector.itemFocused = 1 and m.uiLayer = 0 and m.wasLoggedIn or m.focusedItem = 2 and m.categorySelector.itemFocused = 1 and m.uiLayer = 0 and m.wasLoggedIn
    m.videoGrid.setFocus(false)
    m.categorySelector.setFocus(true)
    m.favoritesUIFlag = false 'user shouldn't be allowed to transition during reload
    m.videoGrid.visible = false
    m.loadingText.text = "Loading following..."
    m.loadingText.visible = true
    m.oauthHeader.visible = false
  end if
  setRegistry("preferencesRegistry", "preferences", FormatJson(m.getpreferencesTask.preferences))
  if m.legacyAuthenticated = false
    authDone()
  end if
  if isValid(oldpreferences) = false or oldpreferences.Count() = 0
    if isValid(newpreferences) and newpreferences.Count() > 0
      oldpreferences = newpreferences
      favoritesChanged = true
    end if
  end if
  if oldpreferences.following.Count() <> newpreferences.following.Count()
    favoritesChanged = true
  end if
  if favoritesChanged = false
    for i = 0 to oldpreferences.following.Count() - 1
      if oldpreferences.following[i] <> newpreferences.following[i]
        favoritesChanged = true
      end if
    end for
  end if
  if m.favoritesThread.state = "init" and favoritesChanged and m.getpreferencesTask.preferences.following.Count() > 0 or m.favoritesThread.state = "stop" and favoritesChanged and m.getpreferencesTask.preferences.following.Count() > 0 and m.threaderRunning = false
    m.favoritesThread.setFields({ constants: m.constants, channels: m.getpreferencesTask.preferences.following, blocked: m.getpreferencesTask.preferences.blocked, rawname: "FAVORITES", resolveLivestreams: true, uid: m.uid, cookies: m.cookies })
    m.favoritesThread.observeField("output", "gotFavorites")
    m.favoritesThread.control = "RUN"
  end if
  if isValid(m.getpreferencesTask.preferences.following)
    if m.getpreferencesTask.preferences.following.Count() = 0 and m.loadingBackground.visible = false
      m.loadingText.visible = false
      m.oauthHeader.text = "Follow some creators here" + Chr(10) + "or on Odysee.com to" + Chr(10) + "enjoy their latest content!"
      m.oauthHeader.visible = true
    end if
  end if
  favoritesChanged = invalid
  oldpreferences = invalid
  newpreferences = invalid
  m.loadingText.text = "Loading..."
  m.preferences = m.getpreferencesTask.preferences
end sub


sub gotCategoryRefresh(msg as object)
  if type(msg) = "roSGNodeEvent"
    thread = msg.getRoSGNode()
    ? thread
    if thread.error
      thread.control = "STOP"
    else
      m.categories.addReplace(thread.rawname, thread.output.content)
      thread.unObserveField("output")
      thread.control = "STOP"
      m.favoritesUIFlag = true
      if thread.rawname = "FAVORITES"
        m.favoritesLoaded = true
      end if
      ?m.focusedItem
      ?m.categorySelector.itemFocused
      if m.focusedItem = 1 and m.uiLayer = 0 or m.focusedItem = 2 and m.uiLayer = 0
        m.oauthHeader.visible = false
        m.oauthCode.visible = false
        m.oauthFooter.visible = false
        m.loadingText.visible = false
        truename = m.categorySelector.content.getChild(m.categorySelector.itemFocused).trueName
        if thread.rawname = truename
          m.videoGrid.content = m.categories[thread.rawname]
        end if
        truename = invalid
        m.videoGrid.visible = true
        m.videoGrid.setFocus(true)
        m.focusedItem = 2
      else if m.focusedItem = 7 and m.uiLayer = 0 'update under video
        m.videoGrid.content = m.categories[thread.rawname]
      end if
    end if
  end if
end sub

sub gotFavorites(msg as object)
  if type(msg) = "roSGNodeEvent"
    thread = msg.getRoSGNode()
    if thread.error
      thread.control = "STOP"
    else
      m.categories.addReplace("FAVORITES", thread.output.content)
      thread.unObserveField("output")
      thread.control = "STOP"
      m.favoritesUIFlag = true
      m.favoritesLoaded = true
      ?m.focusedItem
      ?m.categorySelector.itemFocused
      if m.focusedItem = 1 and m.categorySelector.itemFocused = 1 and m.uiLayer = 0 or m.focusedItem = 2 and m.categorySelector.itemFocused = 1 and m.uiLayer = 0
        m.oauthHeader.visible = false
        m.oauthCode.visible = false
        m.oauthFooter.visible = false
        m.loadingText.visible = false
        truename = m.categorySelector.content.getChild(m.categorySelector.itemFocused).trueName
        if thread.rawname = truename
          m.videoGrid.content = m.categories[thread.rawname]
        end if
        truename = invalid
        m.videoGrid.visible = true
        m.videoGrid.setFocus(true)
        m.focusedItem = 2
        m.oauthLogoutButton.visible = true
      else if m.focusedItem = 7 and m.categorySelector.itemFocused = 1 and m.uiLayer = 0 'update under video
        m.videoGrid.content = m.categories["FAVORITES"]
      end if
    end if
  end if
end sub

sub getReactions(videoID)
  'accesstoken, uid, cookies, claimid, constants
  if isValid(m.accessToken) and m.accessToken <> ""
    m.getreactionTask.setfields({ accessToken: m.accessToken: uid: m.uid: cookies: m.cookies: claimid: videoID: constants: m.constants })
  else if isValid(m.authToken) and m.authToken <> ""
    m.getreactionTask.setfields({ authToken: m.authToken: uid: m.uid: cookies: m.cookies: claimid: videoID: constants: m.constants })
  end if
  m.getreactionTask.observeField("reactions", "gotReactions")
  m.getreactionTask.control = "RUN"
end sub

sub gotReactions(msg as object)
  data = msg.getData()
  m.currentVideoReactions = data
  ? data.mine
  ? data.total
  ? m.videoButtonsDislikeIcon
  '{"mine":{"dislikes":0,"likes":0},"total":{"dislikes":3,"likes":6}}
  if isValid(data.mine) and isValid(data.total)
    if isValid(data.mine.dislikes) and isValid(data.mine.likes) and isValid(data.total.dislikes) and isValid(data.total.likes)
      ? "likes:"
      ? data.mine.likes + data.total.likes
      ? "dislikes"
      ? data.mine.dislikes + data.total.dislikes
      ratioed = false

      'If 2 times more people dislike the video than like it, it's obviously ratioed.
      if ((data.total.dislikes + data.mine.dislikes + .01) / (data.total.likes + data.mine.likes + .01)) >= 2 'ratioed
        ratioed = true
      end if

      if data.mine.likes > 0
        m.videoButtonsLikeIcon.posterUrl = "pkg:/images/generic/tu64-selected.png"
      else
        m.videoButtonsLikeIcon.posterUrl = "pkg:/images/generic/tu64.png"
      end if

      if ratioed
        m.videoButtonsDislikeIcon.posterUrl = "pkg:/images/generic/fu64.png"
      else
        m.videoButtonsDislikeIcon.posterUrl = "pkg:/images/generic/td64.png"
      end if

      if data.mine.dislikes > 0
        if ratioed
          m.videoButtonsDislikeIcon.posterUrl = "pkg:/images/generic/fu64-selected.png"
        else
          m.videoButtonsDislikeIcon.posterUrl = "pkg:/images/generic/td64-selected.png"
        end if
      end if

    end if
  end if
  ? m.videoButtonsDislikeIcon
  m.getreactionTask.control = "STOP"
end sub
sub setReaction(videoID, reaction)
  m.setreactionTask.setfields({ accessToken: m.accessToken: action: reaction: claimid: videoID: constants: m.constants })
  m.setreactionTask.observeField("status", "setReactionDone")
  m.setreactionTask.control = "RUN"
end sub

sub setReactionDone(msg as object)
  data = msg.getData()
  if data.success
    if isValid(data.claimID)
      getReactions(data.claimID)
    end if
  end if
  m.setreactionTask.control = "STOP"
end sub

sub block(channelID)
  m.setpreferencesTask.setFields({ accessToken: m.accessToken: uid: m.uid: constants: m.constants: oldHash: m.wallet.oldHash: walletData: m.wallet.walletData: uid: m.flowUID: preferences: { "blocked": [channelID] }: changeType: "append" })
  m.setpreferencesTask.observeField("state", "setPrefStateChanged")
  m.setpreferencesTask.control = "RUN"
end sub

sub unBlock(channelID)
  m.setpreferencesTask.setFields({ accessToken: m.accessToken: uid: m.uid: constants: m.constants: oldHash: m.wallet.oldHash: walletData: m.wallet.walletData: uid: m.flowUID: preferences: { "blocked": [channelID] }: changeType: "remove" })
  m.setpreferencesTask.observeField("state", "setPrefStateChanged")
  m.setpreferencesTask.control = "RUN"
end sub

sub massFollow(channelIDs)
  if not isValid(m.preferences) then
    m.preferences = {}
  end if
  if not isValid(m.preferences.following) or Type(m.preferences.following) <> "roArray"
    m.preferences.following = []
  end if
  m.setpreferencesTask.setFields({ accessToken: m.accessToken: uid: m.uid: constants: m.constants: oldHash: m.wallet.oldHash: walletData: m.wallet.walletData: uid: m.flowUID: preferences: { "following": channelIDs }: changeType: "append" })
  m.setpreferencesTask.observeField("state", "setPrefStateChanged")
  m.setpreferencesTask.control = "RUN"
  m.preferences.following.Append(channelIDs)
  m.favoritesThread.setFields({ constants: m.constants, channels: m.preferences.following, blocked: m.preferences.blocked, rawname: "FAVORITES", uid: m.uid, cookies: m.cookies, resolveLivestreams: true })
  m.favoritesThread.observeField("output", "gotFavorites")
  m.favoritesThread.control = "RUN"
end sub

sub follow(channelID)
  if not isValid(m.preferences) then
    m.preferences = {}
  end if
  if not isValid(m.preferences.following) or Type(m.preferences.following) <> "roArray"
    m.preferences.following = []
  end if
  m.setpreferencesTask.setFields({ accessToken: m.accessToken: uid: m.uid: constants: m.constants: oldHash: m.wallet.oldHash: walletData: m.wallet.walletData: uid: m.flowUID: preferences: { "following": [channelID] }: changeType: "append" })
  m.setpreferencesTask.observeField("state", "setPrefStateChanged")
  m.setpreferencesTask.control = "RUN"
  if isValid(m.videoButtonsFollowingIcon)
    m.videoButtonsFollowingIcon.posterUrl = "pkg:/images/generic/Heart-selected.png"
  end if
  m.preferences.following.push(channelID)
  m.favoritesThread.setFields({ constants: m.constants, channels: m.preferences.following, blocked: m.preferences.blocked, rawname: "FAVORITES", uid: m.uid, cookies: m.cookies, resolveLivestreams: true })
  m.favoritesThread.observeField("output", "gotFavorites")
  m.favoritesThread.control = "RUN"
end sub

sub unFollow(channelID)
  ? "attempting to unfollow " + channelID
  if not isValid(m.preferences) then
    m.preferences = {}
  end if
  if not isValid(m.preferences.following) or Type(m.preferences.following) <> "roArray"
    m.preferences.following = []
  end if
  m.setpreferencesTask.setFields({ accessToken: m.accessToken: uid: m.uid: constants: m.constants: oldHash: m.wallet.oldHash: walletData: m.wallet.walletData: uid: m.flowUID: preferences: { "following": [channelID] }: changeType: "remove" })
  m.setpreferencesTask.observeField("state", "setPrefStateChanged")
  m.setpreferencesTask.control = "RUN"
  if isValid(m.videoButtonsFollowingIcon)
    m.videoButtonsFollowingIcon.posterUrl = "pkg:/images/png/Heart.png"
  end if
  if m.preferences.following.Count() > 0
    for i = 0 to m.preferences.following.Count() - 1
      if m.preferences.following[i] = channelID
        m.preferences.following.Delete(i)
      end if
    end for
    m.favoritesThread.setFields({ constants: m.constants, channels: m.preferences.following, blocked: m.preferences.blocked, rawname: "FAVORITES", uid: m.uid, cookies: m.cookies, resolveLivestreams: true })
    m.favoritesThread.observeField("output", "gotFavorites")
    m.favoritesThread.control = "RUN"
  end if
end sub

sub setPrefStateChanged()
  if m.setpreferencesTask.setState = 1
    m.setpreferencesTask.control = "STOP"
    ?"SUCCESS: Set preferences remotely"
  else if m.setpreferencesTask.setState = 2
    m.setpreferencesTask.control = "STOP"
    ?"FAILURE: Failed to set preferences for some reason."
  end if
  'Logout()
end sub

'Wallet
sub walletChanged(msg as object)
  data = msg.getData()
  field = msg.getField()
  if field = "oldHash"
    m.wallet.oldHash = data
    SetRegistry("deviceFlowRegistry", "walletOldHash", m.wallet.oldHash)
  else if field = "walletData"
    m.wallet.walletData = data
    SetRegistry("deviceFlowRegistry", "walletData", m.wallet.walletData)
  end if
end sub

'Generic task utility functions

sub observeFields(task, fieldaarray)
  curTask = task
  fields = fieldaarray
  for each field in fields.Keys()
    m[curTask].observeField(field, fields[field])
  end for
  curTask = invalid
  field = invalid
end sub

'General HTTP/Registry-Related Functions
sub gotCookies(msg as object)
  cookies = msg.getData()
  if cookies.Count() > 0
    ?"COOKIE:"
    ?FormatJson(cookies)
    ?"COOKIE_END"
    SetRegistry("authRegistry", "cookies", FormatJSON(cookies))
    m.cookies = cookies
  end if
end sub

function GetRegistry(registry, key) as dynamic
  try
    if m[registry].Exists(key)
      return m[registry].Read(key)
    end if
  catch e
    return invalid
  end try
end function

function SetRegistry(registry, key, value) as boolean
  try
    m[registry].Write(key, value)
    m[registry].Flush()
    return true
  catch e
    return false
  end try
end function

function IsValid(value as dynamic) as boolean 'TheEndless Roku Development forums
  try
    return Type(value) <> "<uninitialized>" and value <> invalid
  catch e
    return false
  end try
end function

function deleteReg(section = "" as string) as void 'belltown Roku Development forums (https://community.roku.com/t5/Roku-Developer-Program/Registry-not-Cleared-if-App-is-deleted/m-p/428861/highlight/true#M30587)
  r = CreateObject ("roRegistry")
  if section = ""
    For Each regSection In r.GetSectionList ()
      r.Delete (regSection)
    end for
  else
    r.Delete (section)
  end if
  r.Flush ()
end function

'used to beat the hell out of setPreferencesTask
function return_tremendous_data()
  tremendous_data = []
  for each category in m.channelIDs
    catData = m.channelIDs[category]
    if isValid(catData)
      if isValid(catData["channelIds"])
        tremendous_data.Append(catData["channelIds"])
        if tremendous_data.Count() > 1000
          exit for
        end if
      end if
    end if
  end for
  return tremendous_data
end function
