Sub init()
    m.appTimer = CreateObject("roTimeSpan")
    m.appTimer.Mark()
    m.maxThreads = 2
    m.runningThreads = []
    m.threads = []
    'UI Logic/State Variables
    m.loaded = False 'Has the app finished its first load?
    m.searchFailed = False 'Has a search failed?
    m.modelWarning = False 'Are we running on a model of Roku that does not load 1080p video correctly?
    m.focusedItem = 1 'actually, this works better than what I was doing before.
    m.searchType = "channel" 'changed to either video or channel
    m.searchKeyboardItemArray = [5,11,17,23,29,35,38] ' Corresponds to a MiniKeyboard's rightmost items. Used for transition.
    m.lastChatMessage = "" 'Used for chat Tempfix (checks if message = last message)
    m.reinitChat = False
    'UI Items
    m.errorText = m.top.findNode("warningtext")
    m.errorSubtext = m.top.findNode("warningsubtext")
    m.errorButton = m.top.findNode("warningbutton")
    m.loadingText = m.top.findNode("loadingtext")
    m.header = m.top.findNode("headerrectangle")
    m.chatBox = m.top.findNode("ChatBox")
    m.superChatBox = m.top.findNode("SuperChatBox")
    m.ChatBackground = m.top.findNode("ChatBackground")
    m.sidebarTrim = m.top.findNode("sidebartrim")
    m.sidebarBackground = m.top.findNode("sidebarbackground")
    m.odyseeLogo = m.top.findNode("odyseelogo")
    m.video = m.top.findNode("Video")
    m.videoContent = createObject("roSGNode", "ContentNode")
    m.videoGrid = m.top.findNode("vgrid")
    m.categorySelector = m.top.findNode("selector")
    m.searchKeyboard = m.top.findNode("searchKeyboard")
    m.searchKeyboardDialog = m.searchkeyboard.findNode("searchKeyboardDialog")
    m.searchKeyboardDialog.itemSize = [280,65]
    m.searchKeyboardDialog.content = createTextItems(m.searchKeyboardDialog, ["Search Channels", "Search Videos"], m.searchKeyboardDialog.itemSize)
    m.searchHistoryBox = m.top.findNode("searchHistory")
    m.searchHistoryLabel = m.top.findNode("searchHistoryLabel")
    m.searchHistoryItems = []
    m.searchHistoryDialog = m.top.findNode("searchHistoryDialog")
    m.searchHistoryContent = m.searchHistoryBox.findNode("searchHistoryContent")
    m.searchKeyboardGrid = m.searchKeyboard.getChildren(-1, 0)[0].getChildren(-1, 0)[1].getChildren(-1, 0)[0] 'Incredibly hacky VKBGrid access. Thanks Roku!

    'UI Item observers
    m.video.observeField("state", "onVideoStateChanged")
    m.categorySelector.observeField("itemFocused", "categorySelectorFocusChanged")
    m.videoGrid.observeField("rowItemSelected", "resolveVideo")
    m.searchHistoryBox.observeField("itemSelected", "historySearch")
    m.searchHistoryDialog.observeField("itemSelected", "clearHistory")
    m.searchKeyboardDialog.observeField("itemSelected", "search")

    '=========Warnings=========
    m.DeviceInfo=createObject("roDeviceInfo")
    m.ModelNumber = m.DeviceInfo.GetModel()
    m.maxThumbHeight=180
    m.maxThumbWidth=320

  if m.ModelNumber = "2710X" OR m.ModelNumber = "2720X" OR m.ModelNumber = "3700X" OR m.ModelNumber = "3710X" OR m.ModelNumber = "5000X"
      m.errorSubtext.text = "Your Roku may not be supported! Certain models of Roku may not meet the hardware requirements to play 1080p video. You are using one of them. Errors may occur."
      m.modelWarning = True
      m.maxThumbHeight=m.maxThumbHeight/2
      m.maxThumbWidth=m.maxThumbWidth/2
  else if m.ModelNumber = "2700X" OR m.ModelNumber = "3500X"
      m.errorSubtext.text = "Your Roku may not be supported! Certain models of Roku cannot play 1080p video. You are using one of them. Errors will occur."
      m.modelWarning = True
      m.maxThumbHeight=m.maxThumbHeight/2
      m.maxThumbWidth=m.maxThumbWidth/2
  end if
  if m.ModelNumber = "4200X" OR m.ModelNumber = "4210X" OR m.ModelNumber = "4230X"
      m.errorSubtext.text = "Your Roku may not be supported! Certain models of Roku may not meet the hardware requirements to play 1080p video. You are using one of them. Errors may occur."
      m.modelWarning = True
  end if
  
  'Tasks
  m.ws = createObject("roSGNode", "WebSocketClient")
  m.date = CreateObject("roDateTime")
  m.chatArray = []
  m.superChatArray = []
  m.chatRegex = CreateObject("roRegex", "[^\x00-\x7F]","")
  m.chatImageRegex = CreateObject("roRegex", "(?:!\[(.*?)\]\((.*?)\))","") 'incredibly scuffed
  m.channelIDs = {}
  m.mediaIndex = {}
  m.categories = {}
  m.authTask = createObject("roSGNode", "authTask")
  m.urlResolver = createObject("roSGNode", "resolveLBRYURL")
  m.livestreamResolver = createObject("roSGNode", "resolveOdyseeLivestream")
  m.channelResolver = createObject("roSGNode", "getSingleChannel")
  m.videoSearch = createObject("roSGNode", "getVideoSearch")
  m.channelSearch = createObject("roSGNode", "getChannelSearch")
  m.InputTask=createObject("roSgNode","inputTask")
  m.InputTask.observefield("inputData","handleInputEvent")
  m.InputTask.control="RUN"

  m.constantsTask = createObject("roSGNode", "getConstants")
  m.constantsTask.observeField("constants", "gotConstants")
  m.constantsTask.control = "RUN"

  m.cidsTask = createObject("roSGNode", "getChannelIDs")
  m.cidsTask.observeField("channelids", "gotCIDS")

  m.legacyRegistry = CreateObject("roRegistrySection", "Authentication")
  m.authRegistry = CreateObject("roRegistrySection", "authData") 'Authentication Data (UID/Authtoken/etc.)
  m.searchHistoryRegistry = CreateObject("roRegistrySection", "searchHistory") 'Search History

  'Get current auth
  if IsValid(GetRegistry("authRegistry", "uid")) AND IsValid(GetRegistry("authRegistry", "authtoken")) AND IsValid(GetRegistry("authRegistry", "cookies"))
    ? "found current account with UID"+GetRegistry("authRegistry", "uid")
    m.uid = StrToI(GetRegistry("authRegistry", "uid"))
    m.authToken = GetRegistry("authRegistry", "authtoken")
    m.cookies = ParseJSON(GetRegistry("authRegistry", "cookies"))
    m.authTask.setField("uid", m.uid)
    m.authTask.setField("authtoken", m.authToken)
    m.authTask.setField("cookies", m.cookies)  
  end if
  'Get current search history
  if IsValid(GetRegistry("searchHistoryRegistry", "searchHistory"))
    ? "found current search history"
    m.searchHistoryItems = ParseJson(GetRegistry("searchHistoryRegistry", "searchHistory"))
    for each histitem in m.searchHistoryItems 'Not efficient. Research a way to convert between the items and ContentNode directly, without for.
      item = m.searchHistoryContent.createChild("ContentNode")
      item.title = histitem
    end for
    ? m.searchHistoryItems
  end if
  'LEGACY => CURRENT auth migration.
  'This will be removed in the version after this one, we want to seperate USER and AUTHENTICATION data.
  'Migrate Authentication
  if IsValid(GetRegistry("legacyRegistry", "uid"))
    if GetRegistry("legacyRegistry", "uid") <> "legacy" AND IsValid(GetRegistry("legacyRegistry", "authtoken")) AND IsValid(GetRegistry("legacyRegistry", "cookies"))
      ? "found legacy account with UID"+GetRegistry("legacyRegistry", "uid")
      m.uid = StrToI(GetRegistry("legacyRegistry", "uid"))
      m.authToken = GetRegistry("legacyRegistry", "authtoken")
      m.cookies = ParseJSON(GetRegistry("legacyRegistry", "cookies"))
      ? "migrating legacy account"
      SetRegistry("authRegistry", "uid", GetRegistry("legacyRegistry", "uid"))
      SetRegistry("authRegistry", "authtoken", GetRegistry("legacyRegistry", "authtoken"))
      SetRegistry("authRegistry", "cookies", GetRegistry("legacyRegistry", "cookies"))
      SetRegistry("legacyRegistry", "uid", "legacy")
      SetRegistry("legacyRegistry", "authtoken", "")
      SetRegistry("legacyRegistry", "cookies", "")
      m.authTask.setField("uid", m.uid)
      m.authTask.setField("authtoken", m.authToken)
      m.authTask.setField("cookies", m.cookies)  
    end if
  end if
  'Migrate Search History
  if IsValid(GetRegistry("legacyRegistry", "searchHistory"))
    if GetRegistry("legacyRegistry", "searchHistory") <> "legacy"
      ? "found legacy search history"
      m.searchHistoryItems = GetRegistry("legacyRegistry", "searchHistory")
      ? "migrating legacy search history"
      SetRegistry("searchHistoryRegistry", "searchHistory", GetRegistry("legacyRegistry", "searchHistory"))
      SetRegistry("legacyRegistry", "searchHistory", "legacy")
    end if
  end if
  ? "Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s" 
End Sub

Function onKeyEvent(key as String, press as Boolean) as Boolean  'Maps back button to leave video
    if press
      ? "key", key, "pressed with focus", m.focusedItem
      if key = "back"  'If the back button is pressed
        if m.video.visible
            returnToUIPage()
            return true
        else if m.categorySelector.itemFocused <> 1
          ErrorDismissed()
          m.searchKeyboard.setFocus(false)
          m.searchKeyboardDialog.setFocus(false)
          m.searchHistoryBox.setFocus(false)
          m.searchHistoryDialog.setFocus(false)
          m.categorySelector.setFocus(true)
          m.focusedItem = 1
          return true
        'else if m.videoGrid.visible AND m.QueryLBRY.method = "lighthouse_channel_options"
        '  m.videoGrid.setFocus(false)
        '  m.categorySelector.setFocus(true)
        '  m.videoGrid.setFocus(true)
        '  m.categorySelector.setFocus(false)
        '  return true
        else
          return false
        end if
      end if
      if key = "options"
          if m.focusedItem = 2 'Options Key Channel Transition.
            if isValid(m.videoGrid.content.getChild(m.videoGrid.rowItemFocused[0]).getChild(m.videoGrid.rowItemFocused[1]).CHANNEL) AND m.videoGrid.content.getChild(m.videoGrid.rowItemFocused[0]).getChild(m.videoGrid.rowItemFocused[1]).CHANNEL <> ""
              curChannel = m.videoGrid.content.getChild(m.videoGrid.rowItemFocused[0]).getChild(m.videoGrid.rowItemFocused[1]).CHANNEL
              m.channelResolver.setFields({constants: m.constants, channel: curChannel, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies})
              m.channelResolver.observeField("output", "gotResolvedChannel")
              m.channelResolver.control = "RUN"
            end if
          end if
      end if
      if key = "up"
          if m.focusedItem = 4 'Search -> Keyboard
              m.searchKeyboardDialog.setFocus(false)
              m.searchKeyboard.setFocus(true)
              m.searchKeyboardGrid.jumpToItem = 37
              m.focusedItem = 3
          end if
          if m.focusedItem = 6 'Clear History -> History
              if m.searchHistoryContent.getChildCount() > 0 'check to make sure we have search history
                  m.searchHistoryDialog.setFocus(false)
                  m.searchHistoryBox.jumpToItem = m.searchHistoryContent.getChildCount() - 1
                  m.searchHistoryBox.setFocus(true)
                  m.focusedItem = 5
              end if
          end if
      end if
  
      if key = "down"
          if m.focusedItem = 3
              m.searchKeyboard.setFocus(false)
              m.searchKeyboardDialog.setFocus(true)
              m.focusedItem = 4
          end if
  
          if m.focusedItem = 5 'History -> Clear
              m.searchHistoryBox.setFocus(false)
              m.searchHistoryDialog.setFocus(true)
              m.focusedItem = 6
          end if
  
      end if
      if key = "left"
          if m.focusedItem = 2
            if m.categorySelector.itemFocused = 0
              m.videoGrid.setFocus(false)
              m.videoGrid.visible = false
              m.searchHistoryBox.visible = true
              m.searchHistoryLabel.visible = true
              m.searchHistoryDialog.visible = true
              m.searchKeyboard.visible = true
              m.searchKeyboardDialog.visible = true
              m.categorySelector.setFocus(true)
              m.focusedItem = 1
            else
              m.videoGrid.setFocus(false)
              m.categorySelector.setFocus(true)
              m.focusedItem = 1
            end if
          end if
          
          if m.focusedItem = 3 OR m.focusedItem = 4 'Exit (Keyboard/Search Button -> Bar)
            ErrorDismissed() 'quick fix
            m.searchKeyboard.setFocus(false)
            m.searchKeyboardDialog.setFocus(false)
            m.searchHistoryBox.setFocus(false)
            m.searchHistoryDialog.setFocus(false)
            m.categorySelector.jumpToItem = 0
            m.categorySelector.setFocus(true)
            m.focusedItem = 1
          end if
          if m.focusedItem = 5 AND m.errorText.visible = false 'History - Keyboard
              switchRow = m.searchHistoryBox.itemFocused
              if m.searchHistoryBox.itemFocused > 6
                  switchRow = 6
              end if
              m.searchHistoryBox.setFocus(false)
              ? "itemArray:", m.searchKeyboardItemArray[switchRow-1]
              m.searchKeyboard.setFocus(true)
              m.focusedItem = 3
              m.searchKeyboardGrid.jumpToItem = m.searchKeyboardItemArray[switchRow]
              switchRow = invalid
              m.focusedItem = 3
          else if m.focusedItem = 5 AND m.errorText.visible = true
            ErrorDismissed()
            m.searchKeyboard.setFocus(false)
            m.searchKeyboardDialog.setFocus(false)
            m.searchHistoryBox.setFocus(false)
            m.searchHistoryDialog.setFocus(false)
            m.categorySelector.jumpToItem = 1
            m.categorySelector.setFocus(true)
            m.focusedItem = 1
          end if
          if m.focusedItem = 6 'Clear History -> Search
              m.searchHistoryDialog.setFocus(false)
              m.searchKeyboardDialog.setFocus(true)
              m.focusedItem = 4
          end if
      end if
      if key = "right"
          if m.focusedItem = 1 AND m.categorySelector.itemFocused = 0
            m.focusedItem = 3
            m.categorySelector.setFocus(false)
            m.searchKeyboard.setFocus(true)
            m.focusedItem = 3
          else if m.categorySelector.itemFocused <> 0
            m.categorySelector.setFocus(false)
            m.videoGrid.setFocus(true)
            m.focusedItem = 2
          end if
  
          if m.focusedItem = 4 'Search -> Clear History
              m.searchKeyboardDialog.setFocus(false)
              m.searchHistoryDialog.setFocus(true)
              m.focusedItem = 6
          end if
  
          if m.focusedItem = 3 'Keyboard -> Search History
              column = Int(m.searchKeyboardGrid.currFocusColumn)
              row = Int(m.searchKeyboardGrid.currFocusRow)
              itemFocused = m.searchKeyboardGrid.itemFocused
              ? row, column
              if column = 4 AND row = 6 OR column = 5
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
                      m.focusedItem = 5
                  end if
              end if
              column = Invalid 'free memory
              row = Invalid
              itemFocused = Invalid
          end if
      end if
    end if
end Function

sub modelWarning()
  m.global.scene.signalBeacon("AppDialogInitiate")
  m.errorText.visible = true
  m.errorSubtext.visible = true
  m.errorButton.visible = true
  m.errorButton.observeField("buttonSelected", "warningdismissed")
  m.errorButton.setFocus(true)
end sub

sub warningdismissed()
  m.errorText.visible = false
  m.errorSubtext.visible = false
  m.errorButton.visible = false
  m.errorButton.unobserveField("buttonSelected")
  m.errorButton.setFocus(false)
  m.global.scene.signalBeacon("AppDialogComplete")
  finishInit()
end sub

Sub resetVideoGrid()
  m.videoGrid.itemSize= [1920,365]
  m.videoGrid.rowitemSize=[[380,350]]
End Sub

Sub downsizeVideoGrid()
  m.videoGrid.itemSize= [1920,305]
  m.videoGrid.rowitemSize=[[380,290]]
End Sub

sub failedSearch()
  ? "search failed"
  m.videoGrid.visible = false
  m.videoSearch.control = "STOP"
  ? "task stopped"
  Error("No results.", "Nothing found on Odysee.")
end sub

Function handleDeepLink(deeplink as object)
  if isValid(deeplink)
    resolveVideo(deeplink)
  else
    print "deeplink not validated"
  end if
end Function

sub categorySelectorFocusChanged(msg)
  '? "[Selector] focus changed from:"
  '? m.categorySelector.itemUnfocused
  '? "to:"
  '? m.categorySelector.itemFocused
  if m.categorySelector.itemFocused <> -1 AND m.loaded = True
      m.videoGrid.visible = true
      m.loadingText.visible = false
      if m.categorySelector.itemFocused = 0
          ? "in search UI"
          m.videoGrid.visible = false
          m.searchHistoryBox.visible = true
          m.searchHistoryLabel.visible = true
          m.searchHistoryDialog.visible = true
          m.searchKeyboard.visible = true
          m.searchKeyboardDialog.visible = true
      end if
      if m.categorySelector.itemFocused <> 0
        m.searchHistoryBox.visible = false
        m.searchHistoryLabel.visible = false
        m.searchHistoryDialog.visible = false
        m.searchKeyboard.visible = false
        m.searchKeyboardDialog.visible = false
        resetVideoGrid()
        m.videoGrid.visible = true
      end if
      if m.categorySelector.itemFocused > 0
        ? m.categorySelector
        ? m.categorySelector.itemFocused
        trueName = m.categorySelector.content.getChild(m.categorySelector.itemFocused).trueName
        m.videoGrid.content = m.categories[trueName]
      end if
      'base = m.JSONTask.output["PRIMARY_CONTENT"]
      'm.videoGrid.content = base["content"]
      'm.mediaIndex = base["index"]
  end if
end sub

sub handleInputEvent(msg)
    '? "in handleInputEvent()"
    if type(msg) = "roSGNodeEvent" and msg.getField() = "inputData"
        deeplink = msg.getData()
        if deeplink <> invalid
            ? "Got deeplink"
            ? deeplink
            if m.loaded
              handleDeepLink(deeplink)
            else
              m.global.deeplink = deeplink
            end if
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
  else
    m.videoGrid.visible = True
  end if
end sub

sub backToKeyboard()
  resetVideoGrid()
  m.searchKeyboard.visible = True
  m.searchKeyboardDialog.visible = True
  m.searchKeyboardGrid.visible = True
  m.searchHistoryLabel.visible = True
  m.searchHistoryBox.visible = True
  m.searchKeyboardDialog.visible = True
  m.searchHistoryDialog.visible = True
  m.loadingText.visible = False
  m.searchFailed = False
  m.loadingText.text = "Loading..."
  m.searchKeyboard.setFocus(true)
  m.focusedItem = 3
end sub

Sub vgridContentChanged(msg as Object)
    if type(msg) = "roSGNodeEvent" and msg.getField() = "content"
        m.videoGrid.content = msg.getData()
    end if
end Sub

Sub resolveVideo(url = invalid) 
  if type(url) = "roSGNodeEvent" 'we might actually pass a URL (string) through to this as well.
    incomingData = url.getData()
    if type(incomingData) = "roArray"
      if incomingData.Count() > 1
        curItem = m.videoGrid.content.getChild(incomingData[0]).getChild(incomingData[1])
        if curItem.itemType = "video"
          ? "Resolving a Video"
          m.urlResolver.setFields({constants: m.constants, url: curitem.URL, title: curItem.TITLE, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies})
          m.urlResolver.observeField("output", "playResolvedVideo")
          m.urlResolver.control = "RUN"
        end if
        if curItem.itemType = "channel"
          ? "Resolving a Channel"
          m.channelResolver.setFields({constants: m.constants, channel: curitem.channel, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies})
          m.channelResolver.observeField("output", "gotResolvedChannel")
          m.channelResolver.control = "RUN"
        end if
        if curItem.itemType = "livestream"
          ? "Playing a livestream"
          m.videoContent.url = curItem.URL
          m.videoContent.streamFormat = curItem.streamFormat
          m.videoContent.title = curItem.description
          m.videoContent.Live = true
          m.video.content = m.videoContent
          m.video.visible = "true"
          m.video.setFocus(true)
          m.focusedItem = 7
          m.video.control = "play"
          m.refreshes = 0
          m.video.observeField("duration", "durationChanged")
          ? m.video.errorStr
          ? m.video.videoFormat
          ? m.video
          m.ws.observeField("on_close", "on_close")
          m.ws.observeField("on_message", "on_message")
          m.ws.observeField("on_error", "on_error")
          m.ws.protocols = []
          m.ws.headers = []
          m.SERVER = m.constants["CHAT_API"]+"/commentron?id="+curItem.guid+"&category="+curItem.guid
          m.ws.open = m.SERVER
          m.ws.control = "RUN"
        end if
      end if
    end if
  end if
End Sub

sub durationChanged() 'ported from salt app, this (mostly) fixes the problem that livestreams do not start at live.
  ? m.video.position
  ? m.video.duration
  m.refreshes += 1
  if m.video.duration > 0 and m.videoContent.Live and m.video.position < m.video.duration and m.refreshes < 4
    m.video.seek = m.video.duration+80
  end if
  if m.refreshes > 4
    m.video.unobserveField("duration")
    m.refreshes = invalid
  end if
end sub

Sub playResolvedVideo(msg as Object)
  if type(msg) = "roSGNodeEvent"
    data = msg.getData()
    m.videoContent.url = data.videourl
    m.VideoContent.streamFormat = data.videotype
    m.videoContent.title = data.title 'passthrough title
    m.videoContent.Live = false
    m.video.content = m.videoContent
    m.video.visible = "true"
    m.video.setFocus(true)
    m.focusedItem = 7
    m.video.control = "play"
    ? m.video.errorStr
    ? m.video.videoFormat
    ? m.video
  end if
  m.urlResolver.unobserveField("output")
  m.urlResolver.control = "STOP"
End Sub

Function onVideoStateChanged(msg as Object)
  if type(msg) = "roSGNodeEvent" and msg.getField() = "state"
      if msg.getData() = "finished"
          returnToUIPage()
      end if
  end if
end Function

Function returnToUIPage()
    m.video.setFocus(false)
    m.video.width = 1920
    m.ws.unobserveField("on_close")
    m.ws.unobserveField("on_message")
    m.ws.unobserveField("on_error")
    m.superChatBox.visible = false
    m.chatBox.visible = false
    m.ChatBackground.visible = false
    if m.videoContent.streamFormat = "hls"
      m.ws.reinitialize = false
      m.ws.close = [1000, "livestreamStopped"]
      m.ws.control = "STOP"
    end if
    m.video.visible = "false" 'Hide video
    m.video.control = "stop"  'Stop video from playing
    m.videoGrid.setFocus(true)
    m.focusedItem = 2
end Function

sub search()
  if m.searchKeyboard.text = "" OR Len(m.searchKeyboard.text) < 3
    Error("Search too short", "Needs to be more than 2 characters long.")
  else
    ? "======SEARCH======"
    if m.searchHistoryContent.getChildCount() = 0 OR m.searchHistoryContent.getChild(0).title <> m.searchKeyboard.text 'don't re-add items that already exist
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
    ? "======SEARCH======"
    SetRegistry("searchHistoryRegistry", "searchHistory", FormatJSON(m.searchHistoryItems))
    if m.searchKeyboardDialog.itemSelected = 1
      ? "video search"
      m.searchType = "video"
    else if m.searchKeyboardDialog.itemSelected = 0 OR m.searchKeyboardDialog.itemSelected = -1
      ? "channel search"
      m.searchType = "channel"
    end if
    execSearch(m.searchKeyboard.text, m.searchType)
  end if
end sub

sub execSearch(search, searchType)
  ? "Valid Input"
  'search starting
  ? search, searchType
  if searchType = "video"
    ? "will run video search."
    m.videoSearch.setFields({constants: m.constants, search: search, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies})
    m.videoSearch.observeField("output", "gotVideoSearch")
    m.videoSearch.control = "RUN"
    m.searchKeyboard.visible = False
    m.searchHistoryDialog.visible = False
    m.searchKeyboardDialog.visible = false
    m.searchHistoryLabel.visible = false
    m.searchHistoryBox.visible = False
    m.loadingText.visible = true
    m.loadingText.text = "Loading your search results.."
  end if
  if searchType = "channel"
    ? "will run channel search."
    m.channelSearch.setFields({constants: m.constants, search: search, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies})
    m.channelSearch.observeField("output", "gotChannelSearch")
    m.channelSearch.control = "RUN"
    m.searchKeyboard.visible = False
    m.searchHistoryDialog.visible = False
    m.searchKeyboardDialog.visible = false
    m.searchHistoryLabel.visible = false
    m.searchHistoryBox.visible = False
    m.loadingText.visible = true
    m.loadingText.text = "Loading your search results.."
  end if
end sub

sub gotVideoSearch(msg as Object)
  if type(msg) = "roSGNodeEvent" 
    data = msg.getData()
    if data.success = true
      m.videoSearch.unobserveField("output")
      'if msg
      m.videoGrid.content = data.result.content
      m.videoSearch.control = "STOP"
      m.videoGrid.visible = true
      m.loadingText.visible = false
      m.focusedItem = 2
      m.videoGrid.setFocus(true)
    else
      m.searchFailed = true
      failedSearch()
    end if
  end if
end sub

sub gotChannelSearch(msg as Object)
  if type(msg) = "roSGNodeEvent" 
    data = msg.getData()
    ? data
    if data.success = true
      downsizeVideoGrid()
      m.videoSearch.unobserveField("output")
      'if msg
      m.videoGrid.content = data.content
      m.channelSearch.control = "STOP"
      m.videoGrid.visible = true
      m.loadingText.visible = false
      m.focusedItem = 2
      m.videoGrid.setFocus(true)
    else
      m.searchFailed = true
      failedSearch()
    end if
  end if
end sub

sub gotResolvedChannel(msg as Object)
  if type(msg) = "roSGNodeEvent"
    data = msg.getData()
    resetVideoGrid()
    m.videoSearch.unobserveField("output")
    m.videoGrid.content = data.content
    m.channelResolver.control = "STOP"
    m.focusedItem = 2
  end if
end sub

function createTextItems(buttons, items, itemSize) as object
  data = CreateObject("roSGNode", "ContentNode")
  buttons.numColumns = items.Count()
  for each item in items
      dataItem = data.CreateChild("horizontalButtonItemData")
      dataItem.posterUrl = ""
      dataItem.width=itemSize[0]
      dataItem.height=itemSize[1]
      dataItem.backgroundColor="0x00000000"
      dataItem.outlineColor="0xFFFFFFFF"
      dataItem.labelText = item
  end for
  return data
end function

sub historySearch()
  ? "======HISTORY SEARCH======"
  ? m.searchKeyboardDialog.itemFocused
  if m.searchKeyboardDialog.itemFocused = 1
    ? "video search"
    m.searchType = "video"
  else if m.searchKeyboardDialog.itemFocused = 0 OR m.searchKeyboardDialog.itemFocused = -1
    ? "channel search"
    m.searchType = "channel"
  end if
  execSearch(m.searchHistoryContent.getChildren(-1, 0)[m.searchHistoryBox.itemSelected].TITLE, m.searchType)
  ? "======HISTORY SEARCH======"
end sub

sub clearHistory()
  searchHistoryItems = []
  SetRegistry("searchHistoryRegistry", "searchHistory", FormatJSON(searchHistoryItems))
  if m.searchHistoryContent.removeChildrenIndex(-1, 0) <> true
      cCount = m.searchHistoryContent.getChildCount()
      for item = 0 to cCount
          m.searchHistoryContent.removeChildIndex(0)
      end for
  end if
end sub
'========================Task Flow===============================

Sub gotConstants()
  ? m.constantsTask.constants
  m.constantsTask.unobserveField("constants")
  m.constantsTask.control = "STOP"
  m.constants = m.constantsTask.constants
  m.authTask.setFields({constants: m.constants})
  m.authTask.observeField("output", "authDone")
  ? "Constants are done, running auth"
  ? "Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s" 
  m.authTask.control = "RUN"
End Sub

Sub authDone()
  m.authTask.control = "STOP"
  m.authTask.unobserveField("output")
  ? m.authTask.output
  m.uid = m.authTask.uid
  m.authtoken = m.authTask.authtoken
  m.cookies = m.authTask.cookies
  ? "AUTH IS DONE!"
  ? "Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s" 
  m.authenticated = True
  m.video.EnableCookies()
  m.video.AddHeader("User-Agent", m.global.constants["userAgent"])
  m.video.AddHeader("origin","https://bitwave.tv")
  m.video.AddHeader("referer","https://bitwave.tv/")
  m.video.AddHeader(":authority","https://cdn.odysee.live")
  m.video.AddHeader("Access-Control-Allow-Origin","https://odysee.com/")
  m.video.AddHeader(":method", "GET")
  m.video.AddHeader(":path", "")
  m.video.AddCookies(m.cookies)
  'm.getSinglePageTask = createObject("roSGNode", "getSinglePage")
  'm.getSinglePageTask.setFields({uid: m.uid, authtoken: m.authtoken, cookies: m.cookies, constants: m.constants, channels: ["ae12172e991e675ed842a0a4412245d8ee1eb398"], rawname: "@SaltyCracker"})
  'm.getSinglePageTask.observeField("output", "gotPage")
  'm.getSinglePageTask.control = "RUN"
  m.cidsTask.control = "RUN"
End Sub

sub indexloaded(msg as Object)
  if type(msg) = "roSGNodeEvent" and msg.getField() = "mediaIndex"
      m.mediaIndex = msg.getData()
      '? "m.mediaIndex= "; m.mediaIndex
  end if
  'get run time deeplink updates'
  'm.global.observeField("deeplink", handleRuntimeDeepLink)
  m.LoadTask.control = "STOP"
end sub

function on_close(event as object) as void
  print "WebSocket closed"
  if m.reinitialize
      m.ws.open = m.SERVER
      m.ws.reinitialize = false
  end if
end function

' Socket message event
function on_message(event as object) as void
  message = event.getData().message
  message_supported = false
  message_valid = true
  if type(message) = "roString"
    jsonMessage = ParseJson(message)
      try
        curComment = jsonMessage.data.comment.comment
        curMessage = "["+m.chatRegex.Replace(jsonMessage.data.comment.channel_name.Replace("@","")+"]: "+curComment, "") 'add newline
        if instr(curComment, "![") > 0 'TODO: find a proper way to parse Markdown on Roku
          if instr(curComment, "](") > 0
            message_valid = false
          end if
        end if
        try
          support_amount = jsonMessage.data.comment.support_amount
          if support_amount > 0
            message_supported = true
          end if
        catch e
        end try
        if curMessage = m.lastMessage and m.reinitChat = False 'Restart webSocket to prevent duplicate connections.
          m.ws.reinitialize = false
          m.ws.close = [1000, "livestreamStopped"]
          m.ws.control = "STOP"
          m.ws.open = m.SERVER
          m.ws.control = "RUN"
          m.reinitChat = True
        else
          if message_supported = true and message_valid = true
            m.superChatBox.visible = true
            m.superChatArray.push(curComment.replace("\n", " ").Trim())
            m.chatArray.Push(curMessage.replace("\n", chr(10)).Trim()+chr(10))
            m.ChatBox.visible = true
            m.superChatBox.visible = true
            m.ChatBackground.visible = true
            m.video.width = 1430 ' Chat's up!
            m.lastMessage = curMessage
            m.reinitChat = False
            m.superChatBox.text = m.superchatArray.join(" | ")
            if m.superChatArray.Count() > 5
              m.superChatArray.shift()
            end if
          else if message_valid = true
            m.chatArray.Push(curMessage.replace("\n", chr(10)).Trim()+chr(10))
            m.ChatBox.visible = true
            m.superChatBox.visible = true
            m.ChatBackground.visible = true
            m.video.width = 1430 ' Chat's up!
            m.lastMessage = curMessage
            m.reinitChat = False
          end if
        end if
      catch e
      end try
  end if
  m.ChatBox.text = m.chatArray.join(Chr(10))
  if m.chatArray.Count() > 20
    m.chatArray.Shift()
  end if
  message_valid = invalid
  message_supported = invalid
end function

' Socket Error event
function on_error(event as object) as void
  print "WebSocket error"
  print event.getData()
end function
'Registry+Utility Functions

Sub gotCIDS()
  ? "Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s" 
  m.channelIDs = m.cidsTask.channelids
  m.categorySelectordata = m.cidsTask.categoryselectordata
  ? m.channelIDs
  ? "Got channelIDs+category selector data"
  m.cidsTask.unObserveField("channelids")

  ? "Creating threads"
  ? "Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s" 
  for each category in m.channelIDs 'create categories for selector
    catData = m.channelIDs[category]
    thread = CreateObject("roSGNode", "getSinglePage")
    thread.setFields({constants: m.constants, channels: catData["channelIds"], rawname: category, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies})
    thread.observeField("output", "threadDone")
    m.threads.push(thread)
    catData = invalid 'save memory
  end for
  ? "Done, starting threader."
  ? "Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s" 
  m.categorySelector.content = m.categorySelectordata
  ? m.categorySelectordata
  ? m.categorySelector.content
  for runvar = 0 to m.maxThreads-1
    m.runningthreads.Push(m.threads[runvar])
    m.threads.delete(runvar)
  end for
  for each thread in m.runningthreads
    thread.control = "RUN" 'start threading
  end for
  ? "Threader started."
  ? "Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s" 
End Sub

Sub threadDone(msg as Object)
if type(msg) = "roSGNodeEvent"
  thread = msg.getRoSGNode()
  m.mediaIndex.append(thread.output.index)
  ? thread.rawname
  m.categories.addReplace(thread.rawname, thread.output.content)
  thread.unObserveField("output")
  thread.control = "STOP"
  todelete = []
  for threadindex = 0 to m.runningthreads.Count()
    if IsValid(m.runningthreads[threadindex])
      if m.runningthreads[threadindex].control = "stop"
        todelete.push(threadindex)
      end if
    end if
  end for
  for each delthread in todelete
    m.runningthreads.delete(delthread)
  end for
  if m.threads.count() > 0
    thread = m.threads.Pop()
    thread.control = "RUN"
    m.runningthreads.Push(thread)
  else
    ? m.mediaIndex
    ? m.mediaIndex.Count()
    ? m.categories
    ? m.categories[m.categories.Keys()[0]]
    ? "Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s"
    m.videoGrid.content = m.categories[m.categories.Keys()[0]]
    m.loadingText.visible = false
    m.loadingText.translation="[800,0]"
    m.loadingText.vertAlign="center" 
    m.loadingText.horizAlign="left"
    if m.modelWarning
      modelWarning()
    else
      finishInit()
    end if
  end if
end if
End Sub

sub finishInit()
  ? "init finished."
  m.header.visible = true
  m.sidebarTrim.visible = true
  m.sidebarBackground.visible = true
  m.odyseeLogo.visible = true
  m.videoGrid.visible = true
  m.categorySelector.jumpToItem = 1
  m.categorySelector.visible = true
  m.loaded = True
  m.categorySelector.setFocus(true)
  m.global.scene.signalBeacon("AppLaunchComplete")
  if isValid(m.global.deeplink)
    if isValid(m.global.deeplink.contentId)
      'STUB: Resolve DeepLink
    end if
  end if
end sub

Sub gotUID()
  SetRegistry("authRegistry","uid", m.authTask.uid.toStr())
End Sub

Sub gotAuth()
    SetRegistry("authRegistry","authtoken", m.authTask.authtoken)
End Sub

sub gotCookies()
    SetRegistry("authRegistry","cookies", FormatJSON(m.authTask.cookies))
End Sub

Function GetRegistry(registry, key) As Dynamic
    try
     if m[registry].Exists(key)
         return m[registry].Read(key)
     endif
    catch e
      return invalid
    end try
End Function

Function SetRegistry(registry, key, value) As boolean
  try
    m[registry].Write(key, value)
    m[registry].Flush()
    return true
  catch e
    return false
  end try
End Function

Function IsValid(value As Dynamic) As Boolean 'TheEndless Roku Development forums
    Return Type(value) <> "<uninitialized>" And value <> invalid
End Function