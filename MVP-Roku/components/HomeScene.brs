Sub init()
    m.appTimer = CreateObject("roTimeSpan")
    m.appTimer.Mark()
    if m.global.constants.enableStatistics
      m.vStatsTimer = CreateObject("roTimeSpan")
      m.watchman = createObject("roSGNode", "watchman") 'analytics (video)
      m.watchman.observeField("output", "watchmanRan")
      m.rokuInstall = createObject("roSGNode", "rokuInstall") 'analytics (install)
      m.watchman.observeField("cookies", "gotCookies")
      m.rokuInstall.observeField("cookies", "gotCookies")
    end if
    m.maxThreads = 2
    m.runningThreads = []
    m.threads = []
    'UI Logic/State Variables
    m.loaded = False 'Has the app finished its first load?
    m.favoritesLoaded = false 'Were favorites loaded?(init only)
    m.favoritesUIFlag = true 'Is a post-init favorites transition allowed?
    m.legacyAuthenticated = False 'Has the app passed phase 0 of authentication?
    m.wasLoggedIn = false 'Was the app logged into a valid Odysee account?
    m.searchFailed = False 'Has a search failed?
    m.taskRunning = False 'Should we avoid UI transitions because of a running search/task?
    m.modelWarning = False 'Are we running on a model of Roku that does not load 1080p video correctly?
    m.videoEndingTimeSet = false 'Did we set the ending time in seconds on the video?
    m.videoTransitionState = 0 '0=None, 1=Rewind, 2=FastForward
    m.videoVP = 0 'Virtual Video Position for ff/rw, because video's position doesn't change until the video has buffered.
    m.focusedItem = 1 '[selector]  'actually, this works better than what I was doing before.
    m.searchType = "channel" 'changed to either video or channel
    m.searchKeyboardItemArray = [5,11,17,23,29,35,38] ' Corresponds to a MiniKeyboard's rightmost items. Used for transition.
    m.uiLayer = 0 '0=Base (Channel Grid/Search), 1=First search layer, 2=Second search layer
    m.uiLayers = [] 'directly correlates with m.uiLayer-1. Layer 0 is managed by the sidebar/categorySelector.
    m.lastChatMessage = ""
    m.reinitChat = False
    m.chatID = ""
    m.totalVideoPings = 0 'analytics
    m.videoButtonSelected = -1
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
    m.vjschars = {"play": Chr(61697), "play-circle": Chr(61698), "pause": Chr(61699), "volume-mute": Chr(61700), "volume-low": Chr(61701), "volume-mid": Chr(61702), "volume-high": Chr(61703), "fullscreen-enter": Chr(61704), "fullscreen-exit": Chr(61705), "square": Chr(61706), "spinner": Chr(61707), "subtitles": Chr(61708), "captions": Chr(61709), "chapters": Chr(61710), "share": Chr(61711), "cog": Chr(61712), "circle": Chr(61713), "circle-outline": Chr(61714), "circle-inner-circle": Chr(61715), "hd": Chr(61716), "cancel": Chr(61717), "replay": Chr(61718), "facebook": Chr(61719), "gplus": Chr(61720), "linkedin": Chr(61721), "twitter": Chr(61722), "tumblr": Chr(61723), "pinterest": Chr(61724), "audio-description": Chr(61725), "audio": Chr(61726), "next-item": Chr(61727), "previous-item": Chr(61728), "picture-in-picture-enter": Chr(61729), "picture-in-picture-exit": Chr(61730)}
    m.searchKeyboardDialog = m.searchkeyboard.findNode("searchKeyboardDialog")
    m.searchKeyboardDialog.itemSize = [280,65]
    m.searchKeyboardDialog.content = createBothItems(m.searchKeyboardDialog, ["Search Channels", "Search Videos"], m.searchKeyboardDialog.itemSize)
    m.videoOverlayGroup = m.top.findNode("videoOverlayGroup")
    m.ffrwTimer = m.top.findNode("ffrwTimer")
    m.videoUITimer = m.top.findNode("videoUITimer")
    m.videoProgressBarp1 = m.videoOverlayGroup.getChildren(-1, 0)[1]
    m.videoProgressBarp2 = m.videoOverlayGroup.getChildren(-1, 0)[2]
    m.videoProgressBar = m.videoOverlayGroup.getChildren(-1, 0)[4]
    m.videoButtons = m.videoOverlayGroup.getChildren(-1, 0)[5]
    m.videoButtons.itemSize = [128,128]
    m.videoButtons.content = createBothItems(m.videoButtons, ["pkg:/images/generic/bad_icon_requires_usage_rights.png","pkg://images/png/Heart.png",m.vjschars["previous-item"],m.vjschars["pause"],m.vjschars["next-item"], "pkg:/images/generic/tu64.png", "pkg:/images/generic/td64.png"], m.videoButtons.itemSize)
    m.videoButtons.observeField("itemFocused", "videoButtonFocused")
    m.videoButtonsLikeIcon = m.videoButtons.content.getChildren(-1, 0)[5]
    m.videoButtonsDislikeIcon = m.videoButtons.content.getChildren(-1, 0)[6]
    m.videoButtonsPlayIcon = m.videoButtons.content.getChildren(-1, 0)[3]
    m.videoButtonsChannelIcon = m.videoButtons.content.getChildren(-1, 0)[0]

    m.currentVideoChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png" 'Current icon displayed w/video UI

    m.currentVideoChannelID = "" 'Current claim ID for Video's Channel
    m.currentVideoClaimID = "" 'Current claim ID for Video
    m.currentVideoReactions = {}

    m.searchHistoryBox = m.top.findNode("searchHistory")
    m.searchHistoryLabel = m.top.findNode("searchHistoryLabel")
    m.searchHistoryItems = []
    m.searchHistoryDialog = m.top.findNode("searchHistoryDialog")
    m.searchHistoryContent = m.searchHistoryBox.findNode("searchHistoryContent")
    m.searchKeyboardGrid = m.searchKeyboard.getChildren(-1, 0)[0].getChildren(-1, 0)[1].getChildren(-1, 0)[0] 'Incredibly hacky VKBGrid access. Thanks Roku!
    m.oauthHeader = m.top.findNode("oauth-header")
    m.oauthCode = m.top.findNode("oauth-code")
    m.oauthFooter = m.top.findNode("oauth-footer")
    m.oauthLogoutButton = m.top.findNode("logoutButton")
    'UI Item observers
    m.video.observeField("state", "onVideoStateChanged")
    m.categorySelector.observeField("itemFocused", "categorySelectorFocusChanged")
    m.videoGrid.observeField("rowItemSelected", "resolveVideo")
    m.searchHistoryBox.observeField("itemSelected", "historySearch")
    m.searchHistoryDialog.observeField("itemSelected", "clearHistory")
    m.searchKeyboardDialog.observeField("itemSelected", "search")
    m.oauthLogoutButton.observeField("buttonSelected", "Logout")

    '=========Warnings=========
    m.DeviceInfo=createObject("roDeviceInfo")
    m.ModelNumber = m.DeviceInfo.GetModel()
    m.maxThumbHeight=220
    m.maxThumbWidth=390
  
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
  m.channelResolver = createObject("roSGNode", "getSingleChannel")
  m.videoSearch = createObject("roSGNode", "getVideoSearch")
  m.channelSearch = createObject("roSGNode", "getChannelSearch")
  m.chatHistory = createObject("roSGNode", "getChatHistory")
  m.InputTask=createObject("roSgNode","inputTask")
  m.InputTask.observefield("inputData","handleInputEvent")
  m.favoritesThread = CreateObject("roSGNode", "getSinglePage")
  'forgot that cookies should be universal throughout application
  m.urlResolver.observeField("cookies", "gotCookies")
  m.channelResolver.observeField("cookies", "gotCookies")
  m.videoSearch.observeField("cookies", "gotCookies")
  m.channelSearch.observeField("cookies", "gotCookies")
  m.chatHistory.observeField("cookies", "gotCookies")
  m.constantsTask = createObject("roSGNode", "getConstants")
  m.constantsTask.observeField("constants", "gotConstants")
  m.authTask = createObject("roSGNode", "authTask")
  m.syncLoop = createObject("roSGNode", "syncLoop")
  observeFields("authTask", { "authPhase": "authPhaseChanged": "userCode": "gotRokuCode": "accessToken": "gotAccessToken": "refreshToken": "gotRefreshToken": "uid": "gotUID" })
  observeFields("syncLoop", { "inSync": "gotSync": "oldHash": "walletChanged": "newHash": "walletChanged": "walletData": "walletChanged" })
  m.getpreferencesTask = createObject("roSGNode", "getpreferencesTask")
  m.setpreferencesTask = createObject("roSGNode", "setpreferencesTask")
  m.preferences = {} ' user preferences (blocked, following, collections)
  m.oldpreferences = {blocked: []: following: []: collections: []} ' user preferences (blocked, following, collections)
  m.getreactionTask = createObject("roSGNode", "getreactionTask")
  m.setreactionTask = createObject("roSGNode", "setreactionTask")
  m.authTaskChildren = m.authTask.getChildren(-1, 0)
  m.syncLoopChildren = m.syncLoop.getChildren(-1, 0)
  m.authTaskTimer = m.authTaskChildren[0]
  m.syncLoopTimer = m.syncLoopChildren[0]
  m.syncLoopState = 0 'Sync loop state variable.
  m.accessToken = ""
  m.accessTokenExpiration = 0
  m.refreshToken = ""
  m.refreshTokenExpiration = 0
  m.uid = 0
  m.authToken = ""

  m.cidsTask = createObject("roSGNode", "getChannelIDs")
  m.cidsTask.observeField("channelids", "gotCIDS")

  m.legacyRegistry = CreateObject("roRegistrySection", "Authentication")
  m.authRegistry = CreateObject("roRegistrySection", "authData") 'Authentication Data (UID/authToken/etc.)
  m.deviceFlowRegistry = CreateObject("roRegistrySection", "deviceFlowData") 'Device Flow Data (Wallet, Sync Hashes (old/new), Auth Token+Refresh Token)
  m.preferencesRegistry = CreateObject("roRegistrySection", "preferences") 'User preferences (odysee.com/app local)
  m.searchHistoryRegistry = CreateObject("roRegistrySection", "searchHistory") 'Search History

  'Get current (older non-token) auth
  if IsValid(GetRegistry("authRegistry", "uid")) and IsValid(GetRegistry("authRegistry", "authtoken")) and IsValid(GetRegistry("authRegistry", "cookies"))
    ?"found current account with UID" + GetRegistry("authRegistry", "uid")
    m.uid = StrToI(GetRegistry("authRegistry", "uid"))
    m.authToken = GetRegistry("authRegistry", "authtoken")
    m.cookies = ParseJSON(GetRegistry("authRegistry", "cookies"))
    m.authTask.setFields({ uid: m.uid, authtoken: m.authtoken, cookies: m.cookies })
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

  m.wallet = { "oldHash": "asdf", "newHash": "asdf", "walletData": "asdf" } 'create template wallet object
  'begin populating template
  if isValid(GetRegistry("deviceFlowRegistry", "walletOldHash"))
    m.wallet.oldHash = GetRegistry("deviceFlowRegistry", "walletOldHash")
  end if
  if isValid(GetRegistry("deviceFlowRegistry", "walletNewHash"))
    m.wallet.newHash = GetRegistry("deviceFlowRegistry", "walletNewHash")
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
    m.accessToken = GetRegistry("deviceFlowRegistry", "accessTokenExpiration")
  end if
  if isValid(GetRegistry("deviceFlowRegistry", "refreshToken"))
    m.refreshToken = GetRegistry("deviceFlowRegistry", "refreshToken")
  end if
  if isValid(GetRegistry("deviceFlowRegistry", "refreshTokenExpiration"))
    m.refreshTokenExpiration = GetRegistry("deviceFlowRegistry", "refreshTokenExpiration")
  end if
  m.authTask.setFields({ "accessToken": m.accessToken: "refreshToken": m.refreshToken: uid: m.flowUID })
  '<field id="oldHash" type="String"/>
  '<field id="newHash" type="String"/>
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
  'LEGACY => CURRENT auth migration.
  'This will be removed in the version after this one, we want to seperate USER and AUTHENTICATION data.
  'Migrate Authentication
  if IsValid(GetRegistry("legacyRegistry", "uid"))
    if GetRegistry("legacyRegistry", "uid") <> "legacy" AND IsValid(GetRegistry("legacyRegistry", "authtoken")) AND IsValid(GetRegistry("legacyRegistry", "cookies"))
      ?"found legacy account with UID"+GetRegistry("legacyRegistry", "uid")
      m.uid = StrToI(GetRegistry("legacyRegistry", "uid"))
      m.authToken = GetRegistry("legacyRegistry", "authtoken")
      m.cookies = ParseJSON(GetRegistry("legacyRegistry", "cookies"))
      ?"migrating legacy account"
      SetRegistry("authRegistry", "uid", GetRegistry("legacyRegistry", "uid"))
      SetRegistry("authRegistry", "authtoken", GetRegistry("legacyRegistry", "authtoken"))
      SetRegistry("authRegistry", "cookies", GetRegistry("legacyRegistry", "cookies"))
      SetRegistry("legacyRegistry", "uid", "legacy")
      SetRegistry("legacyRegistry", "authtoken", "")
      SetRegistry("legacyRegistry", "cookies", "")
      m.authTask.setFields({uid:m.uid,authtoken:m.authtoken,cookies:m.cookies})  
    end if
  end if
  'Migrate Search History
  if IsValid(GetRegistry("legacyRegistry", "searchHistory"))
    if GetRegistry("legacyRegistry", "searchHistory") <> "legacy"
      ?"found legacy search history"
      m.searchHistoryItems = GetRegistry("legacyRegistry", "searchHistory")
      ?"migrating legacy search history"
      SetRegistry("searchHistoryRegistry", "searchHistory", GetRegistry("legacyRegistry", "searchHistory"))
      SetRegistry("legacyRegistry", "searchHistory", "legacy")
    end if
  end if
  ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s" 
  m.constantsTask.control = "RUN"
End Sub

Function onKeyEvent(key as String, press as Boolean) as Boolean  'Maps back button to leave video
?"task running state is:"
?m.taskRunning
    if m.taskRunning = False
      ?"key", key, "pressed with focus", m.focusedItem, "with press", press
      ?"current ui layer:", m.uiLayer
      ?"current ui array:"
      ?m.uiLayers
      if press = true
        if key = "OK"
          if m.video.visible = true AND m.videoOverlayGroup.visible = true
            if m.videoButtonSelected <> -1
              if m.videoButtonSelected = 0
                ? "Go to channel"
              else if m.videoButtonSelected = 1
                ? "Subscribe"
              else if m.videoButtonSelected = 2
                ? "Rewind"
              else if m.videoButtonSelected = 3
                ? "Play/Pause"
              else if m.videoButtonSelected = 4
                ? "Fast Forward"
              else if m.videoButtonSelected = 5
                if m.wasLoggedIn
                ' Dislike
                  if m.currentVideoReactions.mine.likes > 0
                    setReaction(m.currentVideoClaimID, "negate")
                  else
                    setReaction(m.currentVideoClaimID, "like")
                  end if
                end if
              else if m.videoButtonSelected = 6
                ' Like
                if m.wasLoggedIn
                  if m.currentVideoReactions.mine.dislikes > 0
                    setReaction(m.currentVideoClaimID, "negate")
                  else
                    setReaction(m.currentVideoClaimID, "dislike")
                  end if
                end if
              end if
            end if
          end if
        end if
        if key = "back"  'If the back button is pressed
          if m.video.visible
              returnToUIPage()
              return true
          else if (m.uiLayer = 0 AND m.focusedItem = 1) OR (m.uiLayer=0 AND m.focusedItem = 2)
              'TODO: add "are you sure you want to exit Odysee" screen
              'for now, re-add old behavior
              return false
          else if m.categorySelector.itemFocused <> 0 and m.uiLayer = 0
            'set focus to selector
            ErrorDismissed()
            m.videoButtons.setFocus(false)
            m.searchKeyboard.setFocus(false)
            m.searchKeyboardDialog.setFocus(false)
            m.searchHistoryBox.setFocus(false)
            m.searchHistoryDialog.setFocus(false)
            m.categorySelector.setFocus(true)
            m.focusedItem = 1 '[selector] 
            return true
          else if m.uiLayer > 0
            'go back a UI layer
            ?"popping layer"
            if m.uiLayers.Count() > 0
              if m.categorySelector.itemFocused = 1
                m.uiLayer = 0
                m.uiLayers = []
                m.videoGrid.content = m.categories["FAVORITES"]
              else
                m.uiLayers.pop()
                m.videoGrid.content = m.uiLayers[m.uiLayers.Count()-1]
                if isValid(m.uiLayers[m.uiLayers.Count()-1])
                  if m.videoGrid.content.getChildren(1,0)[0].getChildren(1,0)[0].itemType = "channel" 'if we go back to a Channel search, we should downsize the video grid.
                    downsizeVideoGrid()
                  end if
                end if
                m.uiLayer=m.uiLayer-1
                ?"went back to", m.uiLayer
              end if
            end if
            if m.categorySelector.itemFocused = 0 AND m.uiLayers.Count() = 0
              m.uiLayer=0
              ?"(search) went back to", m.uiLayer
              backToKeyboard()
            end if
            if m.categorySelector.itemFocused > 1 AND m.uiLayers.Count() = 0 'not search, on category.
              'set focus to selector
              m.uiLayer=0
              ?"(catsel) went back to", m.uiLayer
              ErrorDismissed()
              m.searchKeyboard.setFocus(false)
              m.searchKeyboardDialog.setFocus(false)
              m.searchHistoryBox.setFocus(false)
              m.searchHistoryDialog.setFocus(false)
              m.categorySelector.setFocus(true)
              m.focusedItem = 1 '[selector] 
            end if
            return true
          else if m.uiLayer = 0
            'set focus to selector
            ErrorDismissed()
            m.searchKeyboard.setFocus(false)
            m.searchKeyboardDialog.setFocus(false)
            m.searchHistoryBox.setFocus(false)
            m.searchHistoryDialog.setFocus(false)
            m.categorySelector.setFocus(true)
            m.focusedItem = 1 '[selector] 
            return true
          end if
        end if
        if key = "play"
          if m.video.visible
            showVideoOverlay()
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
          ?m.video.visible
          ?m.ffrwTimer.control
          ?m.ffrwTimer.duration
          ?m.videoVP
          if m.video.visible
            showVideoOverlay()
            if m.videoTransitionState <> 1
              m.ffrwTimer.duration = .5
            end if
            m.videoTransitionState = 1
            m.video.control = "stop" 'it's better to stop the video and perform prebuffering after
            ?m.ffrwTimer.control
            if m.ffrwTimer.control = "start"
              m.ffrwTimer.duration = m.ffrwTimer.duration / 2
              m.ffrwTimer.observeField("fire", "changeVideoPosition")
            else
              m.ffrwTimer.observeField("fire", "changeVideoPosition")
              m.ffrwTimer.control = "start"
            end if
          end if
        end if
        if key = "fastforward"
          if m.video.visible
            showVideoOverlay()
            if m.videoTransitionState <> 2
              m.ffrwTimer.duration = .3
            end if
            m.videoTransitionState = 2
            m.video.control = "prebuffer" 'it's better to prebuffer immediately as we are moving forwards in the video
            if m.ffrwTimer.control = "start"
              m.ffrwTimer.duration = m.ffrwTimer.duration / 2
            else
              m.ffrwTimer.observeField("fire", "changeVideoPosition")
              m.ffrwTimer.control = "start"
            end if
          end if
        end if
        if key = "options"
            if m.focusedItem = 2 '[video grid]  'Options Key Channel Transition.
              if isValid(m.videoGrid.content.getChild(m.videoGrid.rowItemFocused[0]).getChild(m.videoGrid.rowItemFocused[1]).CHANNEL) AND m.videoGrid.content.getChild(m.videoGrid.rowItemFocused[0]).getChild(m.videoGrid.rowItemFocused[1]).CHANNEL <> ""
                curChannel = m.videoGrid.content.getChild(m.videoGrid.rowItemFocused[0]).getChild(m.videoGrid.rowItemFocused[1]).CHANNEL
                m.channelResolver.setFields({constants: m.constants, channel: curChannel, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies})
                m.channelResolver.observeField("output", "gotResolvedChannel")
                m.channelResolver.control = "RUN"
                m.taskRunning = True
                m.videoGrid.setFocus(false)
              end if
            end if
        end if
        if key = "up"
            if m.video.visible
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
              if m.categorySelector.itemFocused = 1 AND m.favoritesLoaded AND m.videoGrid.rowItemFocused[0] = 0 AND m.videoGrid.rowItemFocused[1] = 3
                m.videoGrid.setFocus(false)
                m.oauthLogoutButton.setFocus(true)
                m.focusedItem = 8 '[oauth logout button]
              end if
            end if
        end if
        if key = "down"
          if m.video.visible
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
              if m.categorySelector.itemFocused = 1 AND m.favoritesLoaded
                m.oauthLogoutButton.setFocus(false)
                m.videoGrid.setFocus(true)
                m.focusedItem = 2 '[video grid]
              end if
            end if
        end if
        if key = "left"
          if m.video.visible
            showVideoOverlay()
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
              ErrorDismissed() 'quick fix
              m.searchKeyboard.setFocus(false)
              m.searchKeyboardDialog.setFocus(false)
              m.searchHistoryBox.setFocus(false)
              m.searchHistoryDialog.setFocus(false)
              m.categorySelector.jumpToItem = 0
              m.categorySelector.setFocus(true)
              m.focusedItem = 1 '[selector] 
            end if
            if m.focusedItem = 5 AND m.errorText.visible = false 'History - Keyboard '[search history list]
                switchRow = m.searchHistoryBox.itemFocused
                if m.searchHistoryBox.itemFocused > 6
                    switchRow = 6
                end if
                m.searchHistoryBox.setFocus(false)
                ?"itemArray:", m.searchKeyboardItemArray[switchRow-1]
                m.searchKeyboardGrid.jumpToItem = m.searchKeyboardItemArray[switchRow]
                switchRow = invalid
                m.focusedItem = 3 '[search keyboard]
                m.searchKeyboard.setFocus(true)
            else if m.focusedItem = 5 AND m.errorText.visible = true '[search history list]  
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
        end if
        if key = "right"
          if m.video.visible
            showVideoOverlay()
          end if
          if m.focusedItem = 1 and m.categorySelector.itemFocused = 0 '[selector]
            m.focusedItem = 3 '[search keyboard]
            m.categorySelector.setFocus(false)
            m.searchKeyboard.setFocus(true)
            m.focusedItem = 3 '[search keyboard]
          else if m.categorySelector.itemFocused = 1 AND m.favoritesLoaded AND m.favoritesUIFlag AND m.focusedItem <> 7
            m.categorySelector.setFocus(false)
            m.videoGrid.setFocus(true)
            m.focusedItem = 2 '[video grid]
          else if m.categorySelector.itemFocused > 1 AND m.focusedItem <> 7
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
                      m.focusedItem = 5 '[search history list] 
                  end if
              end if
              column = Invalid 'free memory
              row = Invalid
              itemFocused = Invalid
          end if
        end if
      else
        return true
      end if
    else
      ?"task running, denying user input"
      return true
    end if
end Function

sub videoButtonFocused(msg)
  'TODO: if type(roint)
  m.videoButtonSelected = msg.getData()
  if Type(m.videoButtonSelected) = "roInt"
    showVideoOverlay()
    ? m.videoButtonSelected
  end if
end sub

sub categorySelectorFocusChanged(msg)
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
        if m.favoritesLoaded
          if m.favoritesUIFlag = false
            m.videoGrid.visible = false
            m.loadingText.visible = true
            m.oauthLogoutButton.visible = true
          else
            m.videoGrid.content = m.categories["FAVORITES"]
            m.videoGrid.visible = true
            m.loadingText.visible = false
            m.oauthLogoutButton.visible = true
          end if
        end if
      else if m.authTask.legacyAuthorized and m.authTask.authPhase = 1 or m.authTask.authPhase = 2
        m.videoGrid.visible = false
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
    'base = m.JSONTask.output["PRIMARY_CONTENT"]
    'm.videoGrid.content = base["content"]
    'm.mediaIndex = base["index"]
  end if
end sub

sub showVideoOverlay()
  m.videoUITimer.control = "stop"
  m.videoUITimer.unobserveField("fire")
  m.videoUITimer.duration = 5
  m.videoUITimer.observeField("fire","hideVideoOverlay")
  m.videoUITimer.control = "start"
  m.videoOverlayGroup.visible = true
end sub

sub hideVideoOverlay()
  m.videoUITimer.control = "stop"
  m.videoUITimer.unobserveField("fire")
  m.videoOverlayGroup.visible = false
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
  m.videoGrid.rowitemSize=[[380,250]]
End Sub

sub failedSearch()
  ?"search failed"
  m.videoGrid.visible = false
  m.videoSearch.control = "STOP"
  m.channelSearch.control = "STOP"
  m.taskRunning = False
  ?"task stopped"
  Error("No results.", "Nothing found on Odysee.")
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
  m.videoGrid.setFocus(false)
  m.videoGrid.visible = False
  m.errorText.text = "Error: Could Not Resolve Claim"
  m.errorSubtext.text = "Please e-mail rokusupport@halitesoftware.com."
  m.errorText.visible = true
  m.errorSubtext.visible = true
  m.errorButton.visible = true
  m.errorButton.observeField("buttonSelected", "resolveerrorDismissed")
  m.errorButton.setFocus(true)
end sub

sub resolveErrorDismissed()
  m.errorButton.setFocus(false)
  m.errorButton.unobserveField("buttonSelected")
  m.errorText.visible = false
  m.errorSubtext.visible = false
  m.errorButton.visible = false
  m.videoGrid.visible = True
  m.videoGrid.setFocus(true)
end sub

sub cleanupToUIPage() 'more aggressive returnToUIPage, until I recreate the UI loop
  m.urlResolver.control = "STOP"
  m.channelResolver.control = "STOP"
  m.constantsTask.control = "STOP"
  m.chatHistory.control = "STOP"
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
  resetVideoGrid()
  m.searchKeyboard.visible = True
  m.searchKeyboardDialog.visible = True
  m.searchKeyboardGrid.visible = True
  m.searchHistoryLabel.visible = True
  m.searchHistoryBox.visible = True
  m.searchKeyboardDialog.visible = True
  m.searchHistoryDialog.visible = True
  m.videoGrid.visible = False
  m.loadingText.visible = False
  m.searchFailed = False
  m.loadingText.text = "Loading..."
  m.searchKeyboard.setFocus(true)
  m.focusedItem = 3 '[search keyboard] 
end sub

Sub vgridContentChanged(msg as Object)
    if type(msg) = "roSGNodeEvent" and msg.getField() = "content"
        m.videoGrid.content = msg.getData()
    end if
end Sub

Sub resolveVideo(url = invalid) 
  ?type(url)
  if type(url) = "roSGNodeEvent" 'we might actually pass a URL (string) through to this as well.
    incomingData = url.getData()
    if type(incomingData) = "roArray"
      if incomingData.Count() > 1
        curItem = m.videoGrid.content.getChild(incomingData[0]).getChild(incomingData[1])
        if curItem.itemType = "video"
          ?"Resolving a Video"
          m.currentVideoChannelIcon = curitem.channelicon
          m.currentVideoChannelID = curItem.channel 'Current claim ID for Video's Channel
          m.currentVideoClaimID = curItem.guid 'Current claim ID for Video
          getReactions(curItem.guid)
          m.urlResolver.setFields({constants: m.constants, url: curitem.URL, title: curItem.TITLE, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies})
          m.urlResolver.observeField("output", "playResolvedVideo")
          m.urlResolver.control = "RUN"
          m.taskRunning = True
          m.videoGrid.setFocus(false)
          m.videoGrid.visible = false
          m.loadingText.visible = true
          m.loadingText.text = "Resolving Video..."
        end if
        if curItem.itemType = "channel"
          ?"Resolving a Channel"
          m.channelResolver.setFields({constants: m.constants, channel: curitem.channel, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies})
          m.channelResolver.observeField("output", "gotResolvedChannel")
          m.channelResolver.control = "RUN"
          m.taskRunning = True
          m.videoGrid.setFocus(false)
          m.videoGrid.visible = false
          m.loadingText.visible = true
          m.loadingText.text = "Resolving Channel..."
        end if
        if curItem.itemType = "livestream"
          ?"Playing a livestream"
          m.currentVideoChannelIcon = curitem.channelicon
          m.currentVideoChannelID = curItem.channel 'Current claim ID for Video's Channel
          m.currentVideoClaimID = curItem.guid 'Current claim ID for Video
          getReactions(curItem.guid)
          m.chatID = curItem.guid
          m.videoContent.url = curItem.URL
          m.videoContent.streamFormat = curItem.streamFormat
          m.videoContent.title = curItem.description
          m.videoContent.Live = true
          m.video.content = m.videoContent
          m.video.visible = true
          'TODO: Reposition video dialog
          m.videoProgressBar.visible = false 'its live, we don't need progress updates.
          m.videoProgressBarp1.visible = false
          m.videoProgressBarp2.visible = false
          m.videoButtons.setFocus(true)
          m.focusedItem = 7 '[video player/overlay]
          m.video.control = "play"
          m.refreshes = 0
          m.videoVP = 0
          m.video.observeField("duration", "liveDurationChanged")
          ?m.video.errorStr
          ?m.video.videoFormat
          ?m.video
          m.chatHistory.setFields({channel:curItem.Channel:channelName:curItem.Creator:streamClaim:curItem.guid:constants:m.constants:uid:m.uid:authtoken:m.authtoken:cookies:m.cookies})
          m.chatHistory.observeField("output", "gotChatHistory")
          m.chatHistory.control = "RUN"
          m.taskRunning = True
          m.videoGrid.setFocus(false)
        end if
      end if
    end if
  else if type(url) = "roString"
    ?"Resolving a Video (deeplink direct)"
    m.urlResolver.setFields({constants: m.constants, url: url, title: "deeplink video", uid: m.uid, authtoken: m.authtoken, cookies: m.cookies})
    m.urlResolver.observeField("output", "playResolvedVideo")
    m.urlResolver.control = "RUN"
    m.taskRunning = True
    m.videoGrid.setFocus(false)
  end if
End Sub

sub gotChatHistory(msg as Object)
  if type(msg) = "roSGNodeEvent"
    m.chatHistory.control = "STOP"
    data = msg.getData()
    ?"Got Chat History:"
    try
      m.chatArray = data.chat
      m.ChatBox.text = m.chatArray.join(Chr(10))
    catch e
    end try
    try
      m.superChatArray = data.superchat
      m.superChatBox.text = m.superchatArray.join(" | ")
    catch e
    end try
    m.ws.observeField("on_close", "on_close")
    m.ws.observeField("on_message", "on_message")
    m.ws.observeField("on_error", "on_error")
    m.ws.protocols = []
    m.ws.headers = []
    m.SERVER = m.constants["CHAT_API"]+"/commentron?id="+m.chatID+"&category="+m.chatID
    m.ws.open = m.SERVER
    m.ws.control = "RUN"
  end if
end sub

sub liveDurationChanged() 'ported from salt app, this (mostly) fixes the problem that livestreams do not start at live.
  ?m.video.position
  ?m.video.duration
  if m.refreshes = 0
    m.video.width = 1430
    m.ChatBackground.visible = true
    m.chatBox.visible = true
    m.superChatBox.visible = true
  end if
  m.refreshes += 1
  if m.video.duration > 0 and m.videoContent.Live and m.video.position < m.video.duration and m.refreshes < 4
    m.video.seek = m.video.duration+80
  end if
  if m.refreshes > 4
    m.video.unobserveField("duration")
    m.refreshes = invalid
  end if
end sub

sub videoPositionChanged() 
  if m.global.constants.enableStatistics 'if position/duration changes, report if vStats are turned on.
    if m.vStatsTimer.TotalSeconds() > 5
      m.vStatsTimer.Mark()
      if isValid(m.video.playStartInfo)
        if m.video.playStartInfo.prebuf_dur > 10
          cache = "miss"
        else
          cache = "player"
        end if
        watchmanFields = {constants:m.constants,uid:m.uid,authtoken:m.authtoken,cookies:m.cookies,bandwidth:m.video.streamInfo.measuredBitrate,cache:cache,duration:m.urlResolver.output.length,player:m.urlResolver.output.player,position:m.video.position,protocol:m.urlResolver.output.videotype.replace("mp4", "stb"),rebuf_count:0,rebuf_duration:0,url:m.urlResolver.url,uid:m.uid}
        m.watchman.setFields(watchmanFields)
        m.watchman.control = "RUN"
      end if
    end if
  end if
  'change video UI
  if m.videoProgressBar.visible = true AND m.videoProgressBarp1.visible = true AND m.videoProgressBarp2.visible = true
    m.videoProgressBarp1.text = getvideoLength(m.video.position)
    if m.video.position > 0
      m.videoProgressBar.width = 1290*(m.video.position / m.urlResolver.output.length)
    end if
    m.videoProgressBarp2.text = getvideoLength(m.urlResolver.output.length+1-m.video.position)
  end if
end sub

sub changeVideoPosition()
  if m.videoVP = 0
    m.videoVP = m.video.position
  end if
  if m.videoTransitionState = 2
    if m.videoVP+1 <= m.urlResolver.output.length
      m.video.seek = m.videoVP+1
      m.videoVP+=1
      if m.videoVP > 0
        m.videoProgressBar.width = 1290*(m.videoVP / m.urlResolver.output.length)
      end if
      m.videoProgressBarp1.text = getvideoLength(m.videoVP)
      m.videoProgressBarp2.text = getvideoLength(m.urlResolver.output.length+1-m.videoVP)
    end if
  else if m.videoTransitionState = 1
    if m.videoVP-1 >= 0 
      m.video.seek = m.videoVP-1
      m.videoVP=m.videoVP-1
      if m.videoVP > 0
        m.videoProgressBar.width = 1290*(m.videoVP / m.urlResolver.output.length)
      end if
      m.videoProgressBarp1.text = getvideoLength(m.videoVP)
      m.videoProgressBarp2.text = getvideoLength(m.urlResolver.output.length+1-m.videoVP)
    end if
  end if
end sub

Sub watchmanRan(msg as Object)
  if type(msg) = "roSGNodeEvent"
    data = msg.getData()
    ?formatJson(data)
    m.watchman.control = "STOP"
  end if
End Sub

Sub playResolvedVideo(msg as Object)
  if type(msg) = "roSGNodeEvent"
    data = msg.getData()
    if isValid(data.error)
      m.urlResolver.unobserveField("output")
      m.urlResolver.control = "STOP"
      m.taskRunning = False
      resolveError()
    else
      m.videoGrid.visible = true
      m.videoGrid.setFocus(false)
      m.categorySelector.setFocus(false)
      m.video.setFocus(true)
      m.loadingText.visible = false
      ?"VPLAYDEBUG:"
      ?formatJSON(data)
      'preset video length in UI
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
      m.video.width = 1920
      m.videoVP = 0
      m.video.visible = true
      m.videoProgressBar.visible = true
      m.videoProgressBarp1.visible = true
      m.videoProgressBarp2.visible = true
      m.video.setFocus(false)
      m.videoButtons.setFocus(true)
      m.focusedItem = 7 '[video player/overlay] 
      m.video.control = "play"
      m.video.observeField("position", "videoPositionChanged")
      ?m.video.errorStr
      ?m.video.videoFormat
      ?m.video
      m.urlResolver.unobserveField("output")
      m.urlResolver.control = "STOP"
      m.taskRunning = False
    end if
  end if
End Sub

Function getvideoLength(length)
  timeConverter = CreateObject("roDateTime")
  timeConverter.FromSeconds(length)
  days = timeConverter.GetDayOfMonth().ToStr()
  hours = timeConverter.GetHours().ToStr()
  minutes = timeConverter.GetMinutes().ToStr()
  seconds = timeConverter.GetSeconds().ToStr()
  result = ""
  if timeConverter.GetDayOfMonth() < 10
    days = "0"+timeConverter.GetDayOfMonth().ToStr()
  end if
  if timeConverter.GetHours() < 10
    hours = "0"+timeConverter.GetHours().ToStr()
  end if
  if timeConverter.GetMinutes() < 10
    minutes = "0"+timeConverter.GetMinutes().ToStr()
  end if
  if timeConverter.GetSeconds() < 10
    seconds = "0"+timeConverter.GetSeconds().ToStr()
  end if
  if length < 3600
    'use minute format
      result = minutes+":"+seconds
  end if
  if length >= 3600 AND length < 86400
    result = hours+":"+minutes+":"+seconds
  end if
  if length >= 86400 'TODO: make videos above month length display proper length
    result = days+":"+hours+":"+minutes+":"+seconds
  end if
  timeConverter = invalid
  days = invalid
  hours = invalid
  minutes = invalid
  seconds = invalid
  return result
End Function

Function onVideoStateChanged(msg as Object)
  if type(msg) = "roSGNodeEvent" and msg.getField() = "state"
      state = msg.getData()
      ?"==========VIDEO STATE==========="
      ?state
      if state = "finished"
          deleteSpinner()
          if m.global.constants.enableStatistics
            m.video.unobserveField("position")
          end if
          m.video.unobserveField("duration")
          m.currentVideoChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
          m.videoButtonsChannelIcon.posterUrl = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
          m.videoProgressBar.width = 0
          returnToUIPage()
      end if
      if state = "playing" OR state = "buffering"
        m.videoButtonsPlayIcon.labelText = m.vjschars["pause"]
        m.videoButtonsPlayIcon.fontUrl = "pkg:/components/generic/fonts/VideoJS.ttf"
        m.videoButtonsPlayIcon.fontSize = m.videoButtons.content.getChildren(-1, 0)[2]["fontSize"] 'borrow precalculated fontsize from neighbor
        ?m.currentVideoChannelIcon
        ?m.videoButtonsChannelIcon
        if m.videoButtonsChannelIcon.posterUrl = "pkg:/images/generic/bad_icon_requires_usage_rights.png" AND m.currentVideoChannelIcon <> "pkg:/images/generic/bad_icon_requires_usage_rights.png"
          m.videoButtonsChannelIcon.posterUrl = m.currentVideoChannelIcon
        end if
        if state = "playing"
          deleteSpinner()
        else if state = "buffering"
          addSpinner()
        end if
      else if state = "paused"
        m.videoButtonsPlayIcon.labelText = m.vjschars["play"]
        m.videoButtonsPlayIcon.fontUrl = "pkg:/components/generic/fonts/VideoJS.ttf"
        m.videoButtonsPlayIcon.fontSize = m.videoButtons.content.getChildren(-1, 0)[2]["fontSize"] 'borrow precalculated fontsize from neighbor
      end if
  end if
end Function

sub addSpinner()
  m.busySpinner = m.top.createChild("BusySpinner")
  m.busySpinner.poster.uri = "pkg:/images/generic/spaceman.png"
  m.busySpinner.translation = [ 870, 450 ]
  m.busySpinner.visible = true
  centerx = invalid
  centery = invalid
end sub
sub deleteSpinner()
  if isValid(m.busySpinner)
    m.top.removeChild(m.busySpinner)
    m.busySpinner = invalid
  end if
end sub

Function returnToUIPage()
    m.videoButtons.setFocus(false)
    m.currentVideoChannelIcon = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
    m.videoButtonsChannelIcon.posterUrl = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
    m.videoProgressBar.width = 0
    m.ws.unobserveField("on_close")
    m.ws.unobserveField("on_message")
    m.ws.unobserveField("on_error")
    m.superChatBox.visible = false
    m.chatBox.visible = false
    m.ChatBackground.visible = false
    m.superChatArray = []
    m.superChatBox.text = ""
    m.chatArray = []
    m.chatBox.text = ""
    if m.videoContent.streamFormat = "hls"
      m.reinitialize = false
      m.ws.close = [1000, "livestreamStopped"]
      m.ws.control = "STOP"
    end if
    m.videoOverlayGroup.visible = false
    m.videoUITimer.control = "stop"
    m.videoUITimer.unobserveField("fire")
    m.video.visible = false 'Hide video
    m.video.control = "stop"  'Stop video from playing
    deleteSpinner()
    m.videoEndingTimeSet = false
    m.video.unObserveField("position")
    m.videoGrid.setFocus(true)
    m.focusedItem = 2 '[video grid] 
    m.video.width = 1920
end Function

sub search()
  if m.searchKeyboard.text = "" OR Len(m.searchKeyboard.text) < 3
    m.searchFailed = true
    Error("Search too short", "Needs to be more than 2 characters long.")
  else
    ?"======SEARCH======"
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
    ?"======SEARCH======"
    SetRegistry("searchHistoryRegistry", "searchHistory", FormatJSON(m.searchHistoryItems))
    if m.searchKeyboardDialog.itemSelected = 1
      ?"video search"
      m.searchType = "video"
    else if m.searchKeyboardDialog.itemSelected = 0 OR m.searchKeyboardDialog.itemSelected = -1
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
    m.videoSearch.setFields({constants: m.constants, search: search, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies})
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
    m.channelSearch.setFields({constants: m.constants, search: search, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies})
    m.channelSearch.observeField("output", "gotChannelSearch")
    m.channelSearch.control = "RUN"
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

sub gotVideoSearch(msg as Object)
  if type(msg) = "roSGNodeEvent" 
    data = msg.getData()
    if data.success = true
      m.videoSearch.unobserveField("output")
      'if msg
      m.videoGrid.content = data.result.content
      m.videoSearch.control = "STOP"
      m.taskRunning = False
      m.videoGrid.visible = true
      m.loadingText.visible = false
      m.focusedItem = 2 '[video grid]
      if isValid(m.uiLayers[m.uiLayers.Count()-1])
        previousData = m.uiLayers[m.uiLayers.Count()-1]
        currentData = data.result.content
        previousDataChildTitle = currentData.getChildren(1,0)[0].getChildren(1,0)[0].TITLE
        currentDataChildTitle = previousData.getChildren(1,0)[0].getChildren(1,0)[0].TITLE
        if previousDataChildTitle <> currentDataChildTitle
          m.uiLayers.push(data.result.content) 'so we can go back a layer when someone hits back.
          m.uiLayer = m.uiLayer+1
        end if
      else
        m.uiLayers.push(data.result.content) 'so we can go back a layer when someone hits back.
        m.uiLayer = m.uiLayer+1
      end if
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
    ?data
    if data.success = true
      downsizeVideoGrid()
      m.videoSearch.unobserveField("output")
      'if msg
      m.videoGrid.content = data.content
      m.channelSearch.control = "STOP"
      m.taskRunning = False
      m.videoGrid.visible = true
      m.loadingText.visible = false
      m.focusedItem = 2 '[video grid]
      if isValid(m.uiLayers[m.uiLayers.Count()-1])
        previousData = m.uiLayers[m.uiLayers.Count()-1]
        currentData = data.content
        previousDataChildTitle = currentData.getChildren(1,0)[0].getChildren(1,0)[0].TITLE
        currentDataChildTitle = previousData.getChildren(1,0)[0].getChildren(1,0)[0].TITLE
        if previousDataChildTitle <> currentDataChildTitle
          m.uiLayers.push(data.content) 'so we can go back a layer when someone hits back.
          m.uiLayer = m.uiLayer+1
        end if
      else
        m.uiLayers.push(data.content) 'so we can go back a layer when someone hits back.
        m.uiLayer = m.uiLayer+1
      end if
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
    if isValid(data.error)
      m.channelResolver.control = "STOP"
      m.taskRunning = false
      if m.uiLayers.Count() > 0
        m.videoGrid.content = m.uiLayers[0]
        resolveError()
      else
        failedSearch()
      end if
    else
      m.videoGrid.visible = true
      m.loadingText.visible = false
      resetVideoGrid()
      m.videoSearch.unobserveField("output")
      m.videoGrid.content = data.content
      m.channelResolver.control = "STOP"
      m.taskRunning = False
      m.focusedItem = 2 '[video grid]
      if isValid(m.uiLayers[m.uiLayers.Count()-1])
        previousData = m.uiLayers[m.uiLayers.Count()-1]
        currentData = data.content
        previousDataChildTitle = currentData.getChildren(1,0)[0].getChildren(1,0)[0].TITLE
        currentDataChildTitle = previousData.getChildren(1,0)[0].getChildren(1,0)[0].TITLE
        if previousDataChildTitle <> currentDataChildTitle
          m.uiLayers.push(data.content) 'so we can go back a layer when someone hits back.
          m.uiLayer = m.uiLayer+1
        end if
      else
        m.uiLayers.push(data.content) 'so we can go back a layer when someone hits back.
        m.uiLayer = m.uiLayer+1
      end if
      m.videoGrid.setFocus(true)
    end if
  end if
end sub

function createBothItems(buttons, items, itemSize) as object
  data = CreateObject("roSGNode", "ContentNode")
  buttons.numColumns = items.Count()
  for each item in items
      if item.split(":")[0] = "http" or item.split(":")[0] = "https" or item.split(":")[0] = "pkg"
          dataItem = data.CreateChild("horizontalButtonItemData")
          dataItem.posterUrl = item
          dataItem.width = itemSize[0]
          dataItem.height = itemSize[1]
          dataItem.backgroundColor = "0x00000000"
          dataItem.outlineColor = "0xFFFFFFFF"
          dataItem.labelText = ""
      else
          dataItem = data.CreateChild("horizontalButtonItemData")
          if Asc(item) <> 61728 AND Asc(item) <> 61697 AND Asc(item) <> 61727
              dataItem.fontUrl = "pkg:/components/generic/fonts/Inter-Emoji.otf"
              dataItem.fontSize = (itemSize[1]/64)*35
          else
              dataItem.fontUrl = "pkg:/components/generic/fonts/VideoJS.ttf"
              dataItem.fontSize = (itemSize[1]/64)*60
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

sub historySearch()
  ?"======HISTORY SEARCH======"
  ?m.searchKeyboardDialog.itemFocused
  if m.searchKeyboardDialog.itemFocused = 1
    ?"video search"
    m.searchType = "video"
  else if m.searchKeyboardDialog.itemFocused = 0 OR m.searchKeyboardDialog.itemFocused = -1
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
'========================Task Flow===============================

Sub gotConstants()
  ?m.constantsTask.constants
  m.constantsTask.unobserveField("constants")
  m.constantsTask.control = "STOP"
  if m.constantsTask.error
    retryError("Error getting constants from Github", "If this happens more than once, go here: https://discord.gg/lbry #odysee-roku", "retryConstants")
  else
    m.constants = m.constantsTask.constants
    m.authTask.setField("constants", m.constants)
    m.getpreferencesTask.setField("constants", m.constants)
    m.setpreferencesTask.setField("constants", m.constants)
    m.setreactionTask.setField("constants", m.constants)
    m.syncLoop.setField("constants", m.constants)
    'uid, authtoken, cookies
    m.authTask.observeField("uid", "gotUID")
    m.authTask.observeField("authtoken", "gotAuth")
    m.authTask.observeField("cookies", "gotCookies")
    ?"Constants are done, running auth"
    ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s" 
    m.authTask.control = "RUN"
  end if
End Sub

Sub retryConstants()
  m.errorText.visible = false
  m.errorSubtext.visible = false
  m.errorButton.visible = false
  m.errorButton.unobserveField("buttonSelected")
  m.constantsTask.observeField("constants", "gotConstants")
  m.constantsTask.control = "RUN"
End Sub

Sub authDone()
  ?"Running authDone"
  if m.authTask.authPhase = 1
    m.authTask.control = "STOP"
  end if
  m.authTask.unobserveField("output")
  if m.authTask.error
    retryError("Error authenticating with Odysee", "If this happens more than once, go here: https://discord.gg/lbry #odysee-roku", "retryAuth")
  else
    m.legacyAuthenticated = True
    ?m.authTask.output
    m.uid = m.authTask.uid
    m.authtoken = m.authTask.authtoken
    m.cookies = m.authTask.cookies
    ?"AUTH IS DONE!"
    ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s"
    if m.global.constants.enableStatistics
      m.rokuInstall.setFields({constants:m.constants,uid:m.uid,authtoken:m.authtoken,cookies:m.cookies})
      m.rokuInstall.observeField("output", "didInstall")
      m.rokuInstall.control = "RUN"
    end if
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
  end if
End Sub

Sub retryAuth()
  m.errorText.visible = false
  m.errorSubtext.visible = false
  m.errorButton.visible = false
  m.errorButton.unobserveField("buttonSelected")
  m.authTask.control = "RUN"
End Sub

sub didInstall(msg as Object)
  if type(msg) = "roSGNodeEvent" 
    ?"============================GOT ACCT DATA:======================================="
    ?formatJSON(msg.getData())
    m.rokuInstall.control = "STOP"
    m.rokuInstall.unobserveField("output")
    ?"============================GOT ACCT DATA:======================================="
  end if
end sub

sub indexloaded(msg as Object)
  if type(msg) = "roSGNodeEvent" and msg.getField() = "mediaIndex"
      m.mediaIndex = msg.getData()
      '?"m.mediaIndex= "; m.mediaIndex
  end if
  'get run time deeplink updates'
  'm.global.observeField("deeplink", handleDeepLink)
  m.LoadTask.control = "STOP"
end sub

function on_close(event as object) as void
  print "WebSocket closed"
  if m.reinitialize
      m.ws.open = m.SERVER
      m.reinitialize = false
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
        curChannel = jsonMessage.data.comment.channel_name
        curMessage = "["+m.chatRegex.Replace(curChannel.Replace("@","")+"]: "+curComment, "") 'add newline
        if instr(curComment, "![") > 0 'TODO: find a proper way to parse Markdown on Roku
          if instr(curComment, "](") > 0
            message_valid = false
          end if
        end if

        try 'validate message not empty
          if m.chatRegex.Replace(curComment) = ""
            message_valid = false
          end if
        catch e
        end try

        try 'check if supported
          support_amount = jsonMessage.data.comment.support_amount
          if support_amount > 0
            message_supported = true
          end if
        catch e
        end try
        if curMessage = m.lastMessage and m.reinitChat = False 'Restart webSocket to prevent duplicate connections.
          m.reinitialize = false
          m.ws.close = [1000, "livestreamStopped"]
          m.ws.control = "STOP"
          m.ws.open = m.SERVER
          m.ws.control = "RUN"
          m.reinitChat = True
        else
          if message_supported = true and message_valid = true
            m.superChatBox.visible = true
            m.superChatArray.push("["+m.chatRegex.Replace(curChannel.Replace("@","")+"]: "+curComment.replace("\n", " ").Trim()))
            m.chatArray.Push(curMessage.replace("\n", chr(10)).Trim()+chr(10))
            m.ChatBox.visible = true
            m.superChatBox.visible = true
            m.ChatBackground.visible = true
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
  ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s"
  m.cidsTask.control = "STOP"
  m.cidsTask.unobserveField("channelids")
  if m.cidsTask.error
    retryError("Error getting frontpage channel IDs", "If this happens more than once, go here: https://discord.gg/lbry #odysee-roku", "retryCIDS")
  else
    m.channelIDs = m.cidsTask.channelids
    m.categorySelectordata = m.cidsTask.categoryselectordata
    ?m.channelIDs
    ?"Got channelIDs+category selector data"
    ?"Creating threads"
    ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s"
    blocked = []
    if m.wasLoggedIn AND m.preferences.Count() > 0
      if isValid(m.preferences.blocked)
        ?"found blocked users"
        if m.preferences.blocked.Count() > 0
          blocked = m.preferences.blocked
          ?formatJson(blocked)
        end if
      end if
    end if
    if m.wasLoggedIn AND m.preferences.Count() > 0
      if isValid(m.preferences.following)
        if m.preferences.following.Count() > 0
          ?"found following"
          ?formatJson(m.preferences["following"])
          thread = CreateObject("roSGNode", "getSinglePage")
          thread.setFields({ constants: m.constants, channels: m.preferences.following, blocked: m.preferences.blocked, rawname: "FAVORITES", uid: m.uid, authtoken: m.authtoken, cookies: m.cookies })
          thread.observeField("output", "threadDone")
          m.threads.push(thread)
          m.favoritesLoaded = true 'favorites were loaded because user is logged in
        end if
      end if
    end if
    for each category in m.channelIDs 'create categories for selector
      catData = m.channelIDs[category]
      thread = CreateObject("roSGNode", "getSinglePage")
      if m.wasLoggedIn AND m.preferences.Count() > 0
        thread.setFields({constants: m.constants, channels: catData["channelIds"], rawname: category, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies, blocked: m.preferences.blocked})
      else
        thread.setFields({constants: m.constants, channels: catData["channelIds"], rawname: category, uid: m.uid, authtoken: m.authtoken, cookies: m.cookies})
      end if
      thread.observeField("output", "threadDone")
      m.threads.push(thread)
      catData = invalid 'save memory
    end for
    ?"Done, starting threader."
    ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s" 
    m.categorySelector.content = m.categorySelectordata
    ?m.categorySelectordata
    ?m.categorySelector.content
    for runvar = 0 to m.maxThreads-1
      m.runningthreads.Push(m.threads[runvar])
      m.threads.delete(runvar)
    end for
    for each thread in m.runningthreads
      thread.control = "RUN" 'start threading
    end for
    ?"Threader started."
    ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s"
  end if
End Sub

Sub retryCIDS()
  m.errorText.visible = false
  m.errorSubtext.visible = false
  m.errorButton.visible = false
  m.errorButton.unobserveField("buttonSelected")
  m.cidsTask.observeField("channelids", "gotCIDS")
  m.cidsTask.control = "RUN"
End Sub

Sub threadDone(msg as Object)
if type(msg) = "roSGNodeEvent"
  thread = msg.getRoSGNode()
  if thread.error
    if thread.errorcount = 2
      'tried twice (w/likely hundreds of queries), kill it
      thread.control = "STOP"
      thread.unObserveField("output")
      for threadindex = 0 to m.runningthreads.Count()
        if IsValid(m.runningthreads[threadindex])
          if m.runningthreads[threadindex].control = "stop"
            if m.runningthreads[threadindex] = thread
              todelete.push(threadindex)
            end if
          end if
        end if
      end for
    else
      'retry: thread is not past limit
      thread.control = "STOP"
      thread.control = "RUN"
    end if
  else
    m.mediaIndex.append(thread.output.index)
    ?thread.rawname
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
      ?m.mediaIndex
      ?m.mediaIndex.Count()
      ?m.categories
      ?m.categories[m.categories.Keys()[0]]
      ?"Current app Time:" + str(m.appTimer.TotalMilliSeconds()/1000)+"s"
      m.videoGrid.content = m.categories[m.categories.Keys()[0]]
      m.loadingText.visible = false
      m.loadingText.translation="[800,0]"
      m.loadingText.vertAlign="center" 
      m.loadingText.horizAlign="left"
      if m.mediaIndex.Count() > 0
        if m.authTask.authPhase > 0
          finishInit()
        end if
      else
        retryError("CRITICAL ERROR: Cannot get/parse ANY frontpage data", "If this happens more than once, go here: https://discord.gg/lbry #odysee-roku", "retryConstants")
      end if
    end if
  end if
end if
End Sub

sub finishInit()
  m.InputTask.control="RUN" 'run input task, since user input is now needed (UI) 
  ?"init finished."
  m.header.visible = true
  m.sidebarTrim.visible = true
  m.sidebarBackground.visible = true
  m.odyseeLogo.visible = true
  m.videoGrid.visible = true
  m.categorySelector.jumpToItem = 2
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
      if instr(m.global.deeplink.contentId, "http") < 1
        resolveVideo(m.global.deeplink.contentId)
      end if
    end if
  end if
end sub

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
  if m.videoGrid.visible = false AND m.loadingText.visible = false AND m.searchKeyboard.visible = false
    m.oauthCode.visible = true
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

sub authPhaseChanged(msg as object)
  if type(msg) = "roSGNodeEvent"
    m.authTask.control = "STOP"
    data = msg.getData()
    if data = 10
      ?"Phase 10 (Logging Out)"
      Logout()
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
      if m.syncTimerObserved = false
        m.syncLoop.setFields({ "accessToken": m.accessToken, "constants": m.constants })
        m.syncLoop.control = "RUN"
        m.syncLoopTimer.observeField("fire", "getSync")
        m.syncTimerObserved = true
      end if
      if m.authTimerObserved = false
        m.authTaskTimer.observeField("fire", "refreshAuth")
        m.authTimerObserved = true
      end if
    end if
    if data = 2
      ?"Phase 2"
      if m.authTimerObserved = false
        m.authTaskTimer.observeField("fire", "refreshAuth")
        m.authTimerObserved = true
      end if
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
        if m.wasLoggedIn AND m.authTask.output.authenticated = false
          authDone()
        end if
      end if
      if m.wasLoggedIn = false
        authDone()
      end if
      m.authTask.authPhase = 1
      m.authTask.control = "RUN"
      ?"Task Restarted"
    end if
    if data = 0
      ?"Phase 0"
      m.authTask.control = "RUN"
    end if
  end if
end sub

sub Logout()
  ?"Running Logout"
  if m.syncTimerObserved = true
    m.syncLoop.control = "STOP"
    m.syncLoopTimer.unobserveField("fire")
    m.syncTimerObserved = false
  end if
  videoFocused = false
  if m.focusedItem = 7
    videoFocused = true
  end if
  m.categorySelector.setFocus(true)
  if m.categorySelector.itemFocused = 1
    m.focusedItem = 1
    m.uiLayer = 0
    m.uiLayers = []
    m.categorySelector.jumpToItem = 1
    if m.video.visible = false
      m.videoGrid.visible = false
      m.oauthLogoutButton.visible = false
      m.oauthHeader.visible = true
      m.oauthCode.text = ""
      m.oauthCode.visible = true
      m.oauthFooter.visible = true
    end if
  end if
  if videoFocused = true
    m.focusedItem = 7
    m.videoButtons.setFocus(true)
    videofocused = invalid
  end if
  m.preferences = {}
  m.favoritesLoaded = false
  m.favoritesUIFlag = false
  m.categories.delete("FAVORITES")
  m.flowUID = ""
  m.accessToken = ""
  m.refreshToken = ""
  m.wallet = { "oldHash": "asdf", "newHash": "asdf", "walletData": "asdf" }
  m.syncLoop.setFields({ "accessToken": m.accessToken, "oldHash": "", "newHash": "", "walletData": "" })
  SetRegistry("deviceFlowRegistry", "flowUID", "")
  setRegistry("preferencesRegistry", "loggedIn", "false")
  SetRegistry("deviceFlowRegistry", "accessToken", "")
  SetRegistry("deviceFlowRegistry", "refreshToken", "")
  setRegistry("preferencesRegistry", "preferences", "{}")
  SetRegistry("deviceFlowRegistry", "walletOldHash", "")
  SetRegistry("deviceFlowRegistry", "walletNewHash", "")
  SetRegistry("deviceFlowRegistry", "walletData", "")
  'if m.authTask.authPhase = 3
  '  m.authTask.authPhase = 10 'logout
  '  m.authTask.control = "RUN"
  '  m.authTaskTimer.control = "start"
  'else
  '  m.authTask.authPhase = 2
  '  m.authTask.control = "RUN"
  '  m.authTaskTimer.control = "start"
  'end if
end sub

'Sync Task related functions (post auth)
sub getSync()
  ?"GETSYNC DEBUG"
  ?m.syncLoop.inSync
  ?m.wasLoggedIn
  ?m.favoritesLoaded
  ?"GETSYNC DEBUG"
  if m.preferences.Count() = 0 AND m.syncLoop.inSync = true AND m.wasLoggedIn 'update
    gotSync()
    getUserPrefs()
  else 'get in sync first
    ? "NOT IN SYNC"
    m.syncLoop.control = "STOP"
    m.syncLoop.control = "RUN"
  end if
end sub

sub gotSync(msg as object)
  data = msg.getData()
  m.syncLoop.control = "STOP"
  ?"GOTSyncDebug"
  if m.preferences.Count() = 0 OR m.favoritesLoaded = false
    getUserPrefs()
  end if
end sub

'User Preference related tasks
sub getUserPrefs()
  ?"attempting to get user preferences"
  m.getpreferencesTask.setFields({ "accessToken": m.accessToken: uid: m.syncLoop.uid })
  m.getpreferencesTask.observeField("preferences", "gotUserPrefs")
  m.getpreferencesTask.control = "RUN"
end sub

sub gotUserPrefs()
  m.getpreferencesTask.control = "STOP"
  favoritesChanged = false
  oldpreferences = m.preferences
  newpreferences = m.getpreferencesTask.preferences
  if m.focusedItem = 1 AND m.categorySelector.itemFocused = 1 AND m.uiLayer = 0 AND m.wasLoggedIn OR m.focusedItem = 2 AND m.categorySelector.itemFocused = 1 AND m.uiLayer = 0 AND m.wasLoggedIn
    m.videoGrid.setFocus(false)
    m.categorySelector.setFocus(true)
    m.favoritesUIFlag = false 'user shouldn't be allowed to transition during reload
    m.videoGrid.visible = false
    m.loadingText.visible = true
  end if
  setRegistry("preferencesRegistry", "preferences", FormatJson(m.preferences))
  if m.legacyAuthenticated = false
    authDone()
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
  if m.favoritesThread.state = "init" AND favoritesChanged OR m.favoritesThread.state = "stop" AND favoritesChanged
    m.favoritesThread.setFields({ constants: m.constants, channels: m.preferences.following, blocked: m.preferences.blocked, rawname: "FAVORITES", uid: m.uid, authtoken: m.authtoken, cookies: m.cookies })
    m.favoritesThread.observeField("output", "gotFavorites")
    m.favoritesThread.control = "RUN"
  end if
  favoritesChanged = invalid
  oldpreferences = invalid
  newpreferences = invalid
  m.preferences = m.getpreferencesTask.preferences
end sub

sub gotFavorites(msg as object)
  if type(msg) = "roSGNodeEvent"
    thread = msg.getRoSGNode()
    if thread.error
        thread.control = "STOP"
    else
      m.mediaIndex.append(thread.output.index) 'TODO: Remove duplicates from mediaIndex.
      m.categories.addReplace("favorites", thread.output.content)
      thread.unObserveField("output")
      thread.control = "STOP"
      m.favoritesUIFlag = true
      ?m.focusedItem
      ?m.categorySelector.itemFocused
      if m.focusedItem = 1 AND m.categorySelector.itemFocused = 1 AND m.uiLayer = 0 OR m.focusedItem = 2 AND m.categorySelector.itemFocused = 1 AND m.uiLayer = 0
        m.oauthHeader.visible = false
        m.oauthCode.visible = false
        m.oauthFooter.visible = false
        m.loadingText.visible = false
        m.videoGrid.content = m.categories["FAVORITES"]
        m.videoGrid.visible = true
        m.videoGrid.setFocus(true)
        m.focusedItem = 2
        m.oauthLogoutButton.visible = true
      end if
    end if
  end if
end sub

sub getReactions(videoID)
  'accesstoken, uid, cookies, claimid, constants
  m.getreactionTask.setfields({accessToken:m.accessToken:uid:m.uid:cookies:m.cookies:claimid:videoID:constants:m.constants})
  m.getreactionTask.observeField("reactions", "gotReactions")
  m.getreactionTask.control = "RUN"
end sub

sub gotReactions(msg as object)
  data = msg.getData()
  m.currentVideoReactions = data
  '{"mine":{"dislikes":0,"likes":0},"total":{"dislikes":3,"likes":6}}
  if isValid(data.mine) AND isValid(data.total)
    if isValid(data.mine.dislikes) AND isValid(data.mine.likes) AND isValid(data.total.dislikes) AND isValid(data.total.likes)
      if data.mine.likes > 0
        m.videoButtonsLikeIcon.posterUrl = "pkg:/images/generic/tu64-selected.png"
      else if data.mine.likes = 0
        m.videoButtonsLikeIcon.posterUrl = "pkg:/images/generic/tu64.png"
      else if data.mine.dislikes > 0
        if data.total.dislikes >= 100
          m.videoButtonsDislikeIcon.posterUrl = "pkg:/images/generic/fu64-selected.png"
        else
          m.videoButtonsDislikeIcon.posterUrl = "pkg:/images/generic/td64-selected.png"
        end if
      else if data.mine.dislikes = 0 AND data.total.dislikes >= 100
        m.videoButtonsDislikeIcon.posterUrl = "pkg:/images/generic/fu64.png"
      end if
    end if
  end if
  m.getreactionTask.control = "STOP"
end sub
sub setReaction(videoID, reaction)
  m.setreactionTask.setfields({accessToken:m.accessToken:action:reaction:claimid:videoID:constants:m.constants})
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
  m.setpreferencesTask.setFields({accessToken:m.accessToken:uid:m.uid:authtoken:m.authtoken:constants:m.constants:oldHash:m.wallet.oldHash:newHash:m.wallet.newHash:walletData:m.wallet.walletData:uid:m.flowUID:preferences:{"blocked": [channelID]}:changeType:"append"})
  m.setpreferencesTask.observeField("state", "setPrefStateChanged")
  m.setpreferencesTask.control = "RUN"
end sub

sub unBlock(channelID)
  m.setpreferencesTask.setFields({accessToken:m.accessToken:uid:m.uid:authtoken:m.authtoken:constants:m.constants:oldHash:m.wallet.oldHash:newHash:m.wallet.newHash:walletData:m.wallet.walletData:uid:m.flowUID:preferences:{"blocked": [channelID]}:changeType:"remove"})
  m.setpreferencesTask.observeField("state", "setPrefStateChanged")
  m.setpreferencesTask.control = "RUN"
end sub

sub follow(channelID)
  m.setpreferencesTask.setFields({accessToken:m.accessToken:uid:m.uid:authtoken:m.authtoken:constants:m.constants:oldHash:m.wallet.oldHash:newHash:m.wallet.newHash:walletData:m.wallet.walletData:uid:m.flowUID:preferences:{"following": [channelID]}:changeType:"append"})
  m.setpreferencesTask.observeField("state", "setPrefStateChanged")
  m.setpreferencesTask.control = "RUN"
end sub

sub unFollow(channelID)
  m.setpreferencesTask.setFields({accessToken:m.accessToken:uid:m.uid:authtoken:m.authtoken:constants:m.constants:oldHash:m.wallet.oldHash:newHash:m.wallet.newHash:walletData:m.wallet.walletData:uid:m.flowUID:preferences:{"following": [channelID]}:changeType:"remove"})
  m.setpreferencesTask.observeField("state", "setPrefStateChanged")
  m.setpreferencesTask.control = "RUN"
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
  if field = "newHash"
    m.wallet.newHash = data
    SetRegistry("deviceFlowRegistry", "walletNewHash", m.wallet.newHash)
  else if field = "oldHash"
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
sub gotCookies(msg as Object)
    cookies = msg.getData()
    if cookies.Count() > 0
      ?"COOKIE:"
      ?FormatJson(cookies)
      ?"COOKIE_END"
      SetRegistry("authRegistry","cookies", FormatJSON(cookies))
      m.cookies = cookies
    end if
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

Function deleteReg (section = "" As String) As Void 'belltown Roku Development forums (https://community.roku.com/t5/Roku-Developer-Program/Registry-not-Cleared-if-App-is-deleted/m-p/428861/highlight/true#M30587)
    r = CreateObject ("roRegistry")
    If section = ""
        For Each regSection In r.GetSectionList ()
            r.Delete (regSection)
        End For
    Else
        r.Delete (section)
    Endif
    r.Flush ()
End Function