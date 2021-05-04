Sub init()

    'UI Logic/State Variables
    m.loaded = False 'Has the app finished its first load?
    m.authenticated = False 'Do we have a valid ID and authkey for search?
    m.searchLoading = False 'Has a search been made, and is it still loading?
    m.searchFailed = False 'Has a search failed?
    m.failedSearchText = "" 'The previous, failed search (so the user can try again.)
    m.modelWarning = False 'Are we running on a model of Roku that does not load 1080p video correctly?
    m.focusedItem = 1 'actually, this works better than what I was doing before.
    m.searchType = "channel" 'changed to either video or channel

    m.searchKeyboardItemArray = [5,11,17,23,29,35,38] ' Corresponds to a MiniKeyboard's rightmost items. Used for transition.
    m.switchRow = 0 'Row on History/Keyboard

    'UI Items
    m.errorText = m.top.findNode("warningtext")
    m.errorSubtext = m.top.findNode("warningsubtext")
    m.errorButton = m.top.findNode("warningbutton")
    m.loadingText = m.top.findNode("loadingtext")
    m.header = m.top.findNode("headerrectangle")
    m.sidebarTrim = m.top.findNode("sidebartrim")
    m.sidebarBackground = m.top.findNode("sidebarbackground")
    m.odyseeLogo = m.top.findNode("odyseelogo")
    m.video = m.top.findNode("Video")
    m.videoContent = createObject("roSGNode", "ContentNode")
    m.videoGrid = m.top.findNode("vgrid")
    m.categorySelector = m.top.findNode("selector")
    m.categorySelector.content = getselectorData()
    m.searchKeyboard = m.top.findNode("searchKeyboard")
    m.searchKeyboardDialog = m.searchkeyboard.findNode("searchKeyboardDialog")
    m.searchKeyboardDialog.itemSize = [280,65]
    m.searchKeyboardDialog.content = createTextItems(m.searchKeyboardDialog, ["Search Channels", "Search Videos"], m.searchKeyboardDialog.itemSize)
    m.searchHistoryBox = m.top.findNode("searchHistory")
    m.searchHistoryLabel = m.top.findNode("searchHistoryLabel")
    m.searchHistoryDialog = m.top.findNode("searchHistoryDialog")
    m.searchHistoryContent = m.searchHistoryBox.findNode("searchHistoryContent")
    m.searchKeyboardGrid = m.searchKeyboard.getChildren(-1, 0)[0].getChildren(-1, 0)[1].getChildren(-1, 0)[0] 'Incredibly hacky VKBGrid access. Thanks Roku!

    'UI Item observers
    m.video.observeField("state", "onVideoStateChanged")
    m.categorySelector.observeField("itemFocused", "categorySelectorFocusChanged")
    m.videoGrid.observeField("rowItemSelected", "playVideo")
    m.videoGrid.observeField("rowitemFocused", "vgridFocusChanged")
    m.searchHistoryBox.observeField("itemSelected", "historySearch")
    m.searchHistoryDialog.observeField("itemSelected", "clearHistory")
    m.searchKeyboardDialog.observeField("itemSelected", "search")

    '=========Initialization Phase=========

    '=========Warnings=========
    m.DeviceInfo=createObject("roDeviceInfo")
    m.ModelNumber = m.DeviceInfo.GetModel()
    m.maxThumbHeight=180
    m.maxThumbWidth=320
    'Players that need LoRes Mode (MIPS):
    '2710X
    '2720X
    '3700X
    '3710X
    '5000X
    '? "Roku Model is: "+m.ModelNumber
    if m.ModelNumber = "2710X" OR m.ModelNumber = "2720X" OR m.ModelNumber = "3500X" OR m.ModelNumber = "3700X" OR m.ModelNumber = "3710X" OR m.ModelNumber = "5000X" 'Sugarland (ARM) added due to assumed 20mb limit, correlates with known 720p limit of Tyler
      '? "WARNING: Model may have problems with Video or Texture Memory"
      '? "Attempting to accomodate."
      m.errorSubtext.text = "Your Roku may not be supported! Certain models of Roku may not meet the hardware requirements to play 1080p video. You are using one of them. Errors may occur."
      m.modelWarning = True
      m.maxThumbHeight=m.maxThumbHeight/2
      m.maxThumbWidth=m.maxThumbWidth/2
    end if

    'Players that do not need LoRes, but will have A/V Desync:
    '4200X
    '4210X
    '4230X

    if m.ModelNumber = "4200X" OR m.ModelNumber = "4210X" OR m.ModelNumber = "4230X"
      m.errorSubtext.text = "Your Roku may not be supported! Certain models of Roku may not meet the hardware requirements to play 1080p video. You are using one of them. Errors may occur."
      m.modelWarning = True
    end if
    
    'Roku Players that WILL NOT WORK:
    '2700X
    '3500X
      
    if m.ModelNumber = "2700X" OR m.ModelNumber = "3500X"
      '? "CRITICAL: Model may not work at all."
      m.errorSubtext.text = "Your Roku cannot run Odysee! It cannot play 1080p Video. We are sorry for this inconvenience. Please join us on odysee.com"
      m.modelWarning = True
    end if


    '=========Registry+UID+Account Check=========
    m.registry = CreateObject("roRegistrySection", "Authentication")
    m.QueryLBRY = createObject("roSGNode", "QueryLBRY")
    m.date = CreateObject("roDateTime")
    if IsValid(GetRegistry("uid")) AND IsValid(GetRegistry("authtoken")) AND IsValid(GetRegistry("cookies"))
        ? "found account with UID"+GetRegistry("uid")
        m.uid = StrToI(GetRegistry("uid"))
        m.authToken = GetRegistry("authtoken")
        m.cookies = ParseJSON(GetRegistry("cookies"))
        m.QueryLBRY.setField("uid", m.uid)
        m.QueryLBRY.setField("authtoken", m.authToken)
        m.QueryLBRY.setField("cookies", m.cookies)  
      end if

    '=========Search History=========
    if IsValid(GetRegistry("searchHistory"))
        m.searchHistoryItems = ParseJSON(GetRegistry("searchHistory"))
        ? "History Found"
    else
        ? "No History Found"
        m.searchHistoryItems = []
        SetRegistry("searchHistory", FormatJSON(m.searchHistoryItems))
    end if

    for each histitem in m.searchHistoryItems 'Not efficient. Research a way to convert between the items and ContentNode directly, without for.
      item = m.searchHistoryContent.createChild("ContentNode")
      item.title = histitem
    end for

    'Tasks
    m.QueryLBRY.setField("method", "startup")
    m.QueryLBRY.observeField("uid", "gotUID")
    m.QueryLBRY.observeField("authtoken", "gotAuth")
    m.QueryLBRY.observeField("cookies", "gotCookies")
    m.QueryLBRY.observeField("output", "startupRan")
    m.QueryLBRY.control = "RUN"

    m.JSONTask = createObject("roSGNode", "JSONTask")
    m.JSONTask.setField("thumbnaildims", [m.maxThumbWidth, m.maxThumbHeight])
    m.JSONTask.observeField("output", "AppFinishedFirstLoad")
    m.JSONTask.control = "RUN"

    m.InputTask=createObject("roSgNode","inputTask")
    m.InputTask.observefield("inputData","handleInputEvent")
    m.InputTask.control="RUN"
End Sub

Sub gotUID()
  SetRegistry("uid", m.QueryLBRY.uid.toStr())
End Sub

Sub gotAuth()
    SetRegistry("authtoken", m.QueryLBRY.authtoken)
End Sub

sub gotCookies()
    SetRegistry("cookies", FormatJSON(m.QueryLBRY.cookies))
End Sub

Sub startupRan()
    ? "got AuthToken "+m.queryLBRY.authtoken+" with ID "+m.queryLBRY.uid.toStr()
    m.QueryLBRY.control = "STOP"
    m.QueryLBRY.unobserveField("output") 'for the next use
    m.authenticated = True
End Sub

function getselectorData() as object
  data = CreateObject("roSGNode", "ContentNode")
  names = ["Search", "Home", "Cheese", "Big Hits", "Gaming", "Lab", "Tech", "News & Politics", "Finance 2.0", "The Universe", "Wild West"]
  for i = 1 to 11
      dataItem = data.CreateChild("catselectordata")
      '? "creating item"
      dataItem.posterUrl = "pkg:/images/odysee/"+i.toStr()+".png"
      dataItem.labelText = names[(i-1)]
  end for
  return data
end function

sub indexloaded(msg as Object)
    if type(msg) = "roSGNodeEvent" and msg.getField() = "mediaIndex"
        m.mediaIndex = msg.getData()
        '? "m.mediaIndex= "; m.mediaIndex
    end if
    handleDeepLink(m.global.deeplink)
    'get run time deeplink updates'
    'm.global.observeField("deeplink", handleRuntimeDeepLink)
    m.LoadTask.control = "STOP"
end sub

sub AppFinishedFirstLoad()
    m.JSONTask.control = "STOP"
    base = m.JSONTask.output["PRIMARY_CONTENT"]
    m.videoGrid.content = base["content"]
    m.mediaIndex = base["index"]
    handleDeepLink(m.global.deeplink)
    m.loadingText.visible = false
    m.loadingText.translation="[800,0]"
    m.loadingText.vertAlign="center" 
    m.loadingText.horizAlign="left"
    if m.modelWarning
      modelWarning()
    else
      finishInit()
    end if
end sub

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

sub finishInit()
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
end sub

sub execSearch(search, searchType)
    '? "Valid Input"
    'search starting
    m.searchKeyboard.visible = False
    m.searchHistoryDialog.visible = False
    m.searchKeyboardDialog.visible = false
    m.searchHistoryLabel.visible = false
    m.searchHistoryBox.visible = False
    m.loadingText.visible = true
    m.loadingText.text = "Loading your search results.."
    m.failedSearchText = search 'so we don't have to extract it from the Task later on.
    m.QueryLBRY.setField("method", "lighthouse_search")
    no_earlier = ">"+stri(m.date.AsSeconds()-7776000).Replace(" ", "").Trim()
    if m.searchType = "video"
      m.QueryLBRY.setField("input", {claimType: "file", mediaType: "video", size: 80, from: 0, expiration: no_earlier, query: search})
    else if m.searchType = "channel"
      m.QueryLBRY.setField("input", {claimType: "channel", size: 20, from: 0, query: search})
    end if
    m.QueryLBRY.observeField("output", "gotLighthouse")
    m.QueryLBRY.control = "RUN"
    no_earlier = invalid ' free memory on variable used only once, rather than making an m.
end sub

sub gotLighthouse()
  m.QueryLBRY.control = "STOP"
  m.QueryLBRY.unobserveField("output")
  if isValid(m.QueryLBRY.output.result.noresults) OR m.QueryLBRY.output.result.index.Count() < 2
      ? "got nothing"
      m.searchFailed = True
      failedSearch()
  else
      m.focusedItem = 2
      base = m.QueryLBRY.output.result
      m.videoGrid.content = base["content"]
      m.mediaIndex = base["index"]
      handleDeepLink(m.global.deeplink)
      m.searchLoading = False
      if m.QueryLBRY.method <> "lighthouse_search" or m.searchType = "video"
        resetVideoGrid()
      else
        downsizeVideoGrid()
      end if
      m.videoGrid.visible = true
      m.loadingText.visible = false
      'close observeField removed, add in input loop
      m.videoGrid.setFocus(true)
  end if
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
  m.QueryLBRY.control = "STOP"
  ? "task stopped"
  Error("No results.", "Nothing found on Odysee.")
end sub

sub backToKeyboard()
  m.videoGrid.itemSize= [1920,365]
  m.videoGrid.rowitemSize=[[380,350]]
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

Function handleDeepLink(deeplink as object)
  if validateDeepLink(deeplink)
    playVideo(m.mediaIndex[deeplink.id].url)
  else
    print "deeplink not validated"
  end if
end Function

sub vgridFocusChanged(msg)
  if isValid(m.videoGrid.rowItemFocused)
    '? m.videoContent.url
    '? m.video.contentMetadata
  end if
end sub

sub categorySelectorFocusChanged(msg)
  '? "[Selector] focus changed from:"
  '? m.categorySelector.itemUnfocused
  '? "to:"
  '? m.categorySelector.itemFocused
  if m.categorySelector.itemFocused <> -1 AND m.loaded = True
      m.videoGrid.visible = true
      m.loadingText.visible = false
      '0 = Search
      '1 = Primary
      '2 = Cheese
      '3 = Big Hits
      '4 = Gaming
      '5 = Lab/Science
      '6 = Tech/Technology
      '7 = News&Politics
      '8 = Finance 2.0
      '9 = The Universe
      '10 = Wild West

      'if only BrightScript had Case Switch =(

      if m.categorySelector.itemFocused = 0
          ? "in search UI"
          m.videoGrid.visible = false
          m.searchHistoryBox.visible = true
          m.searchHistoryLabel.visible = true
          m.searchHistoryDialog.visible = true
          m.searchKeyboard.visible = true
          m.searchKeyboardDialog.visible = true
          m.focusedItem = 3
          m.categorySelector.setFocus(true)
          m.videoGrid.setFocus(false)
          m.searchKeyboard.setFocus(true)
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
      if m.categorySelector.itemFocused = 1
          base = m.JSONTask.output["PRIMARY_CONTENT"]
          m.videoGrid.content = base["content"]
          m.mediaIndex = base["index"]
      else if m.categorySelector.itemFocused = 2
          base = m.JSONTask.output["CHEESE"]
          m.videoGrid.content = base["content"]
          m.mediaIndex = base["index"]
      else if m.categorySelector.itemFocused = 3
          base = m.JSONTask.output["BIG_HITS"]
          m.videoGrid.content = base["content"]
          m.mediaIndex = base["index"]
      else if m.categorySelector.itemFocused = 4
          base = m.JSONTask.output["GAMING"]
          m.videoGrid.content = base["content"]
          m.mediaIndex = base["index"]
      else if m.categorySelector.itemFocused = 5
          base = m.JSONTask.output["SCIENCE"]
          m.videoGrid.content = base["content"]
          m.mediaIndex = base["index"]
      else if m.categorySelector.itemFocused = 6
          base = m.JSONTask.output["TECHNOLOGY"]
          m.videoGrid.content = base["content"]
          m.mediaIndex = base["index"]
      else if m.categorySelector.itemFocused = 7
          base = m.JSONTask.output["NEWS"]
          m.videoGrid.content = base["content"]
          m.mediaIndex = base["index"]
      else if m.categorySelector.itemFocused = 8
          base = m.JSONTask.output["FINANCE"]
          m.videoGrid.content = base["content"]
          m.mediaIndex = base["index"]
      else if m.categorySelector.itemFocused = 9
          base = m.JSONTask.output["THE_UNIVERSE"]
          m.videoGrid.content = base["content"]
          m.mediaIndex = base["index"]
      else if m.categorySelector.itemFocused = 10
          base = m.JSONTask.output["COMMUNITY"]
          m.videoGrid.content = base["content"]
          m.mediaIndex = base["index"]
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
            handleDeepLink(deeplink)
        end if
    end if
end sub

function validateDeepLink(deeplink as Object) as Boolean
  mediatypes={movie:"movie",episode:"episode",season:"season",series:"series"}
  if deeplink <> Invalid
      '? "mediaType = "; deeplink.type
      '? "contentId = "; deeplink.id
      '? "content= "; m.mediaIndex[deeplink.id]
      if deeplink.type <> invalid then
        if mediatypes[deeplink.type]<> invalid
          if m.mediaIndex[deeplink.id] <> invalid
            if m.mediaIndex[deeplink.id].url <> invalid
              return true
            else
                print "invalid deep link url"
            end if
          else
            print "bad deep link contentId"
          end if
        else
          print "unknown media type"
        end if
      else
        print "deeplink.type string is invalid"
      end if
  end if
  return false
end function

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

Sub vgridContentChanged(msg as Object)
    if type(msg) = "roSGNodeEvent" and msg.getField() = "content"
        m.videoGrid.content = msg.getData()
    end if
end Sub

Sub playVideo(url = invalid)
    if m.videoGrid.content.getChild(m.videoGrid.rowItemFocused[0]).getChild(m.videoGrid.rowItemFocused[1]).itemType = "video"
      m.videoContent.url = m.videoGrid.content.getChild(m.videoGrid.rowItemFocused[0]).getChild(m.videoGrid.rowItemFocused[1]).URL
      m.videoContent.streamFormat = "mp4"
      m.video.content = m.videoContent
      m.video.visible = "true"
      m.video.setFocus(true)
      m.focusedItem = 7
      m.video.control = "play"
      ? m.video.errorStr
      ? m.video.videoFormat
      ? m.video
    else if m.videoGrid.content.getChild(m.videoGrid.rowItemFocused[0]).getChild(m.videoGrid.rowItemFocused[1]).itemType = "channel"
      no_earlier = ">"+stri(m.date.AsSeconds()-7776000).Replace(" ", "").Trim()
      m.QueryLBRY.setField("method", "lighthouse_channel")
      m.QueryLBRY.setField("input", {channelID: m.videoGrid.content.getChild(m.videoGrid.rowItemFocused[0]).getChild(m.videoGrid.rowItemFocused[1]).URL, expiration: no_earlier})
      m.QueryLBRY.observeField("output", "gotLighthouse")
      m.QueryLBRY.control = "RUN"
    end if
End Sub

Function returnToUIPage()
    m.video.setFocus(false)
    m.video.visible = "false" 'Hide video
    m.video.control = "stop"  'Stop video from playing
    m.videoGrid.setFocus(true)
    m.focusedItem = 2
end Function

Function onVideoStateChanged(msg as Object)
  if type(msg) = "roSGNodeEvent" and msg.getField() = "state"
      if msg.getData() = "finished"
          returnToUIPage()
      end if
  end if
end Function

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
          m.categorySelector.jumpToItem = 1
          m.categorySelector.setFocus(true)
          m.focusedItem = 1
          return true
        else
          return false
        end if
      end if
      if key = "options"
          if m.focusedItem = 2 'Options Key Channel Transition.
            if isValid(m.videoGrid.content.getChild(m.videoGrid.rowItemFocused[0]).getChild(m.videoGrid.rowItemFocused[1]).CHANNEL) AND m.videoGrid.content.getChild(m.videoGrid.rowItemFocused[0]).getChild(m.videoGrid.rowItemFocused[1]).CHANNEL <> ""
              no_earlier = ">"+stri(m.date.AsSeconds()-7776000).Replace(" ", "").Trim()
              m.QueryLBRY.setField("method", "lighthouse_channel")
              m.QueryLBRY.setField("input", {channelID: m.videoGrid.content.getChild(m.videoGrid.rowItemFocused[0]).getChild(m.videoGrid.rowItemFocused[1]).CHANNEL, expiration: no_earlier})
              m.QueryLBRY.observeField("output", "gotLighthouse")
              m.QueryLBRY.control = "RUN"
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
              m.categorySelector.jumpToItem = 1
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
            m.categorySelector.jumpToItem = 1
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
    SetRegistry("searchHistory", FormatJSON(searchHistoryItems))
    if m.searchHistoryContent.removeChildrenIndex(-1, 0) <> true
        cCount = m.searchHistoryContent.getChildCount()
        for item = 0 to cCount
            m.searchHistoryContent.removeChildIndex(0)
        end for
    end if
end sub

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
    SetRegistry("searchHistory", FormatJSON(m.searchHistoryItems))
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

'Registry+Utility Functions

Function GetRegistry(key) As Dynamic
     if m.registry.Exists(key)
         return m.registry.Read(key)
     endif
     return invalid
End Function

Function SetRegistry(key, value) As Void
  m.registry.Write(key, value)
  m.registry.Flush()
End Function

Function IsValid(value As Dynamic) As Boolean 'TheEndless Roku Development forums
    Return Type(value) <> "<uninitialized>" And value <> invalid
End Function