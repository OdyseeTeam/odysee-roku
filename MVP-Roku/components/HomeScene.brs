Sub init()

    'UI Logic/State Variables
    m.loaded = False 'Has the app finished its first load?
    m.authenticated = False 'Do we have a valid ID and authkey for search?
    m.searchloading = False 'Has a search been made, and is it still loading?
    m.failedSearchText = "" 'The previous, failed search (so the user can try again.)
    m.modelwarning = False 'Are we running on a model of Roku that does not load 1080p video correctly?
    m.focusedItem = 6 'set to External. This is just a workaround for legacy code here that I am planning on removing.

    m.searchKeyboardItemArray = [5,11,17,23,29,35,38] ' Corresponds to a MiniKeyboard's rightmost items. Used for transition.
    m.switchRow = 0 'Row on History/Keyboard
    
    'Warning UI Items
    m.warningtext = m.top.findNode("warningtext")
    m.warningsubtext = m.top.findNode("warningsubtext")
    m.warningbutton = m.top.findNode("warningbutton")

    'Tasks
    m.InputTask=createObject("roSgNode","inputTask")
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
      m.warningsubtext.text = "Your Roku may not be supported! Certain models of Roku may not meet the hardware requirements to play 1080p video. You are using one of them. Errors may occur."
      m.modelwarning = True
      m.maxThumbHeight=m.maxThumbHeight/2
      m.maxThumbWidth=m.maxThumbWidth/2
    end if

    'Players that do not need LoRes, but will have A/V Desync:
    '4200X
    '4210X
    '4230X

    if m.ModelNumber = "4200X" OR m.ModelNumber = "4210X" OR m.ModelNumber = "4230X"
      m.warningsubtext.text = "Your Roku may not be supported! Certain models of Roku may not meet the hardware requirements to play 1080p video. You are using one of them. Errors may occur."
      m.modelwarning = True
    end if
    
    'Roku Players that WILL NOT WORK:
    '2700X
    '3500X
      
    if m.ModelNumber = "2700X" OR m.ModelNumber = "3500X"
      '? "CRITICAL: Model may not work at all."
      m.warningsubtext.text = "Your Roku cannot run Odysee! It cannot play 1080p Video. We are sorry for this inconvenience. Please join us on odysee.com"
      m.modelwarning = True
    end if
      
    m.InputTask.observefield("inputData","handleInputEvent")
    m.InputTask.control="RUN"
   

    'Registry+UID
    m.registry = CreateObject("roRegistrySection", "Authentication")
    m.QueryLBRY = createObject("roSGNode", "QueryLBRY")
    m.date = CreateObject("roDateTime")
    if IsValid(GetRegistry("uid")) AND IsValid(GetRegistry("authtoken")) AND IsValid(GetRegistry("cookies"))
        ? "found account with UID"+GetRegistry("uid")
        m.uid = StrToI(GetRegistry("uid"))
        m.authtoken = GetRegistry("authtoken")
        m.cookies = ParseJSON(GetRegistry("cookies"))
        m.QueryLBRY.setField("uid", m.uid)
        m.QueryLBRY.setField("authtoken", m.authtoken)
        m.QueryLBRY.setField("cookies", m.cookies)  
      end if
    
    if IsValid(GetRegistry("searchHistory"))
        m.searchHistoryItems = ParseJSON(GetRegistry("searchHistory"))
        ? "History Found"
    else
        ? "No History Found"
        m.searchHistoryItems = []
        SetRegistry("searchHistory", FormatJSON(m.searchHistoryItems))
    end if
    
    m.QueryLBRY.setField("method", "startup")
    m.QueryLBRY.observeField("uid", "gotUID")
    m.QueryLBRY.observeField("authtoken", "gotAuth")
    m.QueryLBRY.observeField("cookies", "gotCookies")
    m.QueryLBRY.observeField("output", "startupRan")
    m.QueryLBRY.control = "RUN"

    'UI items
    m.loadingtext = m.top.findNode("loadingtext")
    m.header = m.top.findNode("headerrectangle")
    m.sidebartrim = m.top.findNode("sidebartrim")
    m.sidebarbackground = m.top.findNode("sidebarbackground")
    m.odyseelogo = m.top.findNode("odyseelogo")
    m.Video = m.top.findNode("Video")
    m.Video.observeField("state", "onVideoStateChanged")
    m.VideoContent = createObject("roSGNode", "ContentNode")
    m.vgrid = m.top.findNode("vgrid")
    m.selector = m.top.findNode("selector")
    m.selector.content = getselectorData()
    m.selector.observeField("itemFocused", "SelectorFocusChanged")
    m.vgrid.observeField("rowItemSelected", "playVideo")
    m.vgrid.observeField("rowitemFocused", "vgridFocusChanged")

    m.searchKeyboard = m.top.findNode("searchKeyboard")
    m.searchKeyboardDialog = m.searchkeyboard.findNode("searchKeyboardDialog")
    m.searchHistoryBox = m.top.findNode("searchHistory")
    m.searchHistoryLabel = m.top.findNode("searchHistoryLabel")
    m.searchHistoryDialog = m.top.findNode("searchHistoryDialog")
    m.searchHistoryContent = m.searchHistoryBox.findNode("searchHistoryContent")
    m.searchKeyboardGrid = m.searchKeyboard.getChildren(-1, 0)[0].getChildren(-1, 0)[1].getChildren(-1, 0)[0] 'Incredibly hacky VKBGrid access. Thanks Roku!

    m.searchHistoryBox.observeField("itemSelected", "historySearch")
    m.searchHistoryDialog.observeField("itemSelected", "clearHistory")
    m.searchKeyboardDialog.observeField("itemSelected", "search")

    for each histitem in m.searchHistoryItems
      item = m.searchHistoryContent.createChild("ContentNode")
      item.title = histitem
    end for

    m.JSONTask = createObject("roSGNode", "JSONTask")
    m.JSONTask.setField("thumbnaildims", [m.maxThumbWidth, m.maxThumbHeight])
    m.JSONTask.observeField("output", "AppFinishedFirstLoad")
    m.JSONTask.control = "RUN"
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
    m.vgrid.content = base["content"]
    m.mediaindex = base["index"]
    handleDeepLink(m.global.deeplink)
    m.loadingtext.visible = false
    m.loadingtext.translation="[800,0]"
    m.loadingtext.vertAlign="center" 
    m.loadingtext.horizAlign="left"
    if m.modelwarning
      modelWarning()
    else
      finishInit()
    end if
end sub

sub modelWarning()
  m.global.scene.signalBeacon("AppDialogInitiate")
  m.warningtext.visible = true
  m.warningsubtext.visible = true
  m.warningbutton.visible = true
  m.warningbutton.observeField("buttonSelected", "warningdismissed")
  m.warningbutton.setFocus(true)
end sub

sub warningdismissed()
  m.warningtext.visible = false
  m.warningsubtext.visible = false
  m.warningbutton.visible = false
  m.warningbutton.unobserveField("buttonSelected")
  m.warningbutton.setFocus(false)
  m.global.scene.signalBeacon("AppDialogComplete")
  finishInit()
end sub

sub finishInit()
  m.header.visible = true
  m.sidebartrim.visible = true
  m.sidebarbackground.visible = true
  m.odyseelogo.visible = true
  m.vgrid.visible = true
  m.selector.jumpToItem = 1
  m.selector.visible = true
  m.loaded = True
  m.vgrid.setFocus(true)
  m.global.scene.signalBeacon("AppLaunchComplete")
end sub

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

sub execSearch(search)
    '? "Valid Input"
    'search starting
    m.issearch = True
    m.canSelector = False
    m.searchKeyboard.visible = False
    m.searchHistoryDialog.visible = False
    m.searchKeyboardDialog.visible = false
    m.searchHistoryLabel.visible = false
    m.searchHistoryBox.visible = False
    m.loadingtext.visible = true
    m.loadingtext.text = "Loading your search results.."
    searchquery = search
    m.failedSearchText = searchquery 'so we don't have to extract it from the Task later on.
    m.QueryLBRY.setField("method", "lighthouse")
    m.no_earlier = ">"+stri(m.date.AsSeconds()-7776000).Replace(" ", "").Trim()
    m.QueryLBRY.setField("input", {claimType: "file", mediaType: "video", size: 80, from: 0, expiration: m.no_earlier, query: searchquery})
    m.QueryLBRY.observeField("output", "gotLighthouse")
    m.QueryLBRY.control = "RUN"
end sub

sub gotLighthouse()
  m.QueryLBRY.control = "STOP"
  m.QueryLBRY.unobserveField("output")
  if isValid(m.QueryLBRY.output.result.noresults) OR m.QueryLBRY.output.result.content.getChildCount() < 2
      ? "got nothing"
      m.searchFailed = True
      failedSearch()
  else
      m.focusedItem = 6 'Use standard UI loop for the search.
      base = m.QueryLBRY.output.result
      m.vgrid.content = base["content"]
      m.mediaindex = base["index"]
      handleDeepLink(m.global.deeplink)
      m.searchloading = False
      m.vgrid.visible = true
      m.loadingtext.visible = false
      'close observeField removed, add in input loop
      m.vgrid.setFocus(true)
  end if
end sub

sub failedSearch()
  ? "search failed"
  m.QueryLBRY.control = "STOP"
  ? "task stopped"
  searchError("No results.", "Nothing found on Odysee.")
end sub

sub backToKeyboard()
  m.issearch = False
  m.canSelector = True
  m.searchKeyboard.visible = True
  m.searchKeyboardDialog.visible = True
  m.searchKeyboardGrid.visible = True
  m.searchHistoryLabel.visible = True
  m.searchHistoryBox.visible = True
  m.searchKeyboardDialog.visible = True
  m.searchHistoryDialog.visible = True
  m.loadingtext.visible = False
  m.loadingtext.text = "Loading..."
  m.searchKeyboard.setFocus(true)
  m.focusedItem = 1
  '  m.keyboarddialog = createObject("roSGNode", "KeyboardDialog")
'  m.keyboarddialog.backgroundUri = "pkg:/images/searchbackground.png"
'  m.keyboarddialog.title = "Video Search"
'  m.keyboarddialog.keyboard.texteditbox.hintText = "Enter Video Name Here"
'  m.keyboarddialog.buttons = ["OK", "Cancel"]
'  m.keyboarddialog.buttonGroup.observeField("buttonSelected", "searchEntered")
'  children = m.keyboarddialog.buttonGroup.getChildren(-1,0)
'  for each child in children
'    child.iconUri=""
'    child.focusedIconUri=""
'  end for
'  m.top.appendChild(m.keyboarddialog)
'  m.vgrid.setFocus(false)
'  m.keyboarddialog.setFocus(true)
end sub

Function handleDeepLink(deeplink as object)
  if validateDeepLink(deeplink)
    playVideo(m.mediaIndex[deeplink.id].url)
  else
    print "deeplink not validated"
  end if
end Function

sub vgridFocusChanged(msg)
  '? "focus changed from:"
  '? m.vgrid.rowitemUnfocused
  '? "to:"
  if m.vgrid.rowItemFocused[0] = 0
    m.isup = True
    '? "is up, can transition to search"
  else
    m.isup = False
    '? "not up, can't transition to search"
  end if
  if m.vgrid.rowItemFocused[1] = 0
    m.canSelector=True
    '? "is left, can transition"
  else
    m.canSelector=False
    '? "not left, can't transition"
  end if
  if isValid(m.vgrid.rowItemFocused)
    m.videoContent.url = m.vgrid.content.getChild(m.vgrid.rowItemFocused[0]).getChild(m.vgrid.rowItemFocused[1]).URL
    m.videoContent.streamFormat = "mp4"
    keepPlaying = false
    m.Video.content = m.videoContent
    ? m.videoContent.url
    m.Video.control = "prebuffer"
    '? m.Video.contentMetadata
  end if
end sub

sub SelectorFocusChanged(msg)
  '? "[Selector] focus changed from:"
  '? m.selector.itemUnfocused
  '? "to:"
  '? m.selector.itemFocused
  if m.selector.itemFocused <> -1 AND m.loaded = True
      m.canright = True
      m.vgrid.visible = true
      m.loadingtext.visible = false
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

      if m.selector.itemFocused = 0
          ? "in search UI"
          m.vgrid.visible = false
          m.canSelector = true
          m.canRight = true
          m.searchHistoryBox.visible = true
          m.searchHistoryLabel.visible = true
          m.searchHistoryDialog.visible = true
          m.searchKeyboard.visible = true
          m.searchKeyboardDialog.visible = true
          m.focusedItem = 1
          m.selector.setFocus(true)
          m.vgrid.setFocus(false)
          m.searchKeyboard.setFocus(true)
      end if
      if m.selector.itemFocused <> 0
        m.searchHistoryBox.visible = false
        m.searchHistoryLabel.visible = false
        m.searchHistoryDialog.visible = false
        m.searchKeyboard.visible = false
        m.searchKeyboardDialog.visible = false
        m.vgrid.visible = true
        m.canSelector = true
        m.canRight = true
      end if
      if m.selector.itemFocused = 1
          base = m.JSONTask.output["PRIMARY_CONTENT"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 2
          base = m.JSONTask.output["CHEESE"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 3
          base = m.JSONTask.output["BIG_HITS"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 4
          base = m.JSONTask.output["GAMING"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 5
          base = m.JSONTask.output["SCIENCE"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 6
          base = m.JSONTask.output["TECHNOLOGY"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 7
          base = m.JSONTask.output["NEWS"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 8
          base = m.JSONTask.output["FINANCE"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 9
          base = m.JSONTask.output["THE_UNIVERSE"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 10
          base = m.JSONTask.output["COMMUNITY"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      end if
      'base = m.JSONTask.output["PRIMARY_CONTENT"]
      'm.vgrid.content = base["content"]
      'm.mediaindex = base["index"]
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

sub searchError(title, error)
  m.searchKeyboard.visible = False
  m.searchHistoryDialog.visible = False
  m.searchKeyboardDialog.visible = false
  m.searchHistoryLabel.visible = false
  m.searchHistoryBox.visible = False
  m.loadingtext.visible = False
  m.warningtext.text = title
  m.warningsubtext.text = error
  m.warningtext.visible = true
  m.warningsubtext.visible = true
  m.warningbutton.visible = true
  m.warningbutton.observeField("buttonSelected", "searchErrorDismissed")
  m.warningbutton.setFocus(true)
end sub

sub searchErrorDismissed()
  m.warningtext.visible = false
  m.warningsubtext.visible = false
  m.warningbutton.visible = false
  m.warningbutton.unobserveField("buttonSelected")
  m.searchKeyboard.text = ""
  backToKeyboard()
end sub

Sub vgridContentChanged(msg as Object)
    if type(msg) = "roSGNodeEvent" and msg.getField() = "content"
        m.vgrid.content = msg.getData()
    end if
end Sub

Sub playVideo(url = invalid)
    m.Video.visible = "true"
    m.Video.setFocus(true)
    m.Video.control = "play"
    ? m.Video.errorStr
    ? m.Video.videoFormat
    ? m.Video
End Sub

Function returnToUIPage()
    m.Video.visible = "false" 'Hide video
    m.vgrid.setFocus(true)
    m.Video.control = "stop"  'Stop video from playing
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
      changeFocus(m.focusedItem, key)
    end if
end Function

'LEGACY UI CODE BELOW (for reimp.)
          'if key = "back"  'If the back button is pressed
          '    if m.Video.visible
          '        returnToUIPage()
          '        return true
          '    else
          '        return false
          '    end if
          'end if
          'if (key = "right") and (m.selector.hasFocus() = true) and (m.canright = true)
          '  m.vgrid.setFocus(true)
          '  m.selector.setFocus(false)
          'else if (key = "left") and (m.vgrid.hasFocus()= true) and (m.canSelector = true)
          '  m.canright = True
          '  m.selector.setFocus(true)
          '  m.vgrid.setFocus(false)
          'end if

'see and print out MVP-FocusedItem.ods for what the focusedItem number means.   	        
sub changeFocus(focusedItem, key)
    ? "key", key, "pressed with focus", focusedItem
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

        if m.focusedItem = 3 'Keyboard -> Search
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
          m.vgrid.setFocus(false)
          m.selector.setFocus(true)
          m.focusedItem = 1
        end if
        
        if m.focusedItem = 3 OR m.focusedItem = 4 'Exit (Keyboard/Search Button -> Bar)
          m.searchKeyboard.setFocus(false)
          m.searchKeyboardDialog.setFocus(false)
          m.searchHistoryBox.setFocus(false)
          m.searchHistoryDialog.setFocus(false)
          m.selector.jumpToItem = 1
          m.selector.setFocus(true)
          m.focusedItem = 1
        end if
        if m.focusedItem = 5 'History - Keyboard
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
        end if
        if m.focusedItem = 6 'Clear History -> Search
            m.searchHistoryDialog.setFocus(false)
            m.searchKeyboardDialog.setFocus(true)
            m.focusedItem = 4
        end if
    end if
    if key = "right"
        if m.focusedItem = 1 AND m.selector.itemFocused = 0
          m.selector.setFocus(false)
          m.searchKeyboard.setFocus(true)
          m.focusedItem = 3
        else if m.selector.itemFocused <> 0
          m.selector.setFocus(false)
          m.vgrid.setFocus(true)
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
end sub

sub historySearch()
    ? "======HISTORY SEARCH======"
    execSearch(m.searchHistoryContent.getChildren(-1, 0)[m.searchHistoryBox.itemSelected].TITLE)
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
    searchError("Search too short", "Needs to be more than 2 characters long.")
  else
    ? "======SEARCH======"
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
    ? "======SEARCH======"
    SetRegistry("searchHistory", FormatJSON(m.searchHistoryItems))
    execSearch(m.searchKeyboard.text)
  end if
end sub

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