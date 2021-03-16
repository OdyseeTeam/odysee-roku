Sub init()

    'UI Logic/State Variables
    m.loaded = False 'Has the app finished its first load?
    m.authenticated = False 'Do we have a valid ID and authkey for search?
    m.searchloading = False 'Has a search been made, and is it still loading?
    m.canright = False 'Can we move from the video grid (VGRID) to the selector bar (SELECTOR)?
    m.canSelector = True 'Are we ready to transition to the selector? (We are either in the video grid on the leftmost item or in search)
    m.issearch = False 'Are we in search mode? (Search mode prevents transition to the selector)
    m.searchFailed = False 'Did the previous search fail? (Indicate to the user that the search failed)
    m.failedSearchText = "" 'The previous, failed search (so the user can try again.)
    m.modelwarning = False 'Are we running on a model of Roku that does not load 1080p video correctly?

    m.lastSelectorItem = 0 'Used to return user to either the last selector or video grid item.
    m.lastVGridItem = [0,0]

    'Legacy UI Variables (to be removed along w/legacy)
    m.useLegacyUI = False 'Use Legacy UI (Temporary Variable)
    m.isup = False 'Are we on the highest item of the video grid and ready to transition to the search button?


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
    m.searchbutton = m.top.findNode("searchbutton")
    m.searchbutton.observeField("buttonSelected", "searchMode")

    'LEGACY UI
    if m.useLegacyUI = False
      m.searchbutton.unobserveField("buttonSelected") ' Disable Search Mode
    end if
    
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
  m.selector.visible = true
  m.loaded = True
  if m.loaded and m.authenticated and m.useLegacyUI
    m.searchbutton.visible = true
  end if
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
    if m.loaded and m.authenticated and m.useLegacyUI
      m.searchbutton.visible = true
    end if
End Sub

sub searchMode()
  ? "in search mode"
  m.issearch = True
  m.keyboarddialog = createObject("roSGNode", "KeyboardDialog")
  m.keyboarddialog.backgroundUri = "pkg:/images/searchbackground.png"
  m.keyboarddialog.title = "Video Search"
  
  m.keyboarddialog.buttons = ["OK", "Cancel"]
  m.keyboarddialog.buttonGroup.observeField("buttonSelected", "searchEntered")
  if m.searchFailed
      m.keyboarddialog.text = m.failedSearchText
      m.keyboarddialog.title = "No results found with previous search"
      m.searchFailed = False
  else
    m.keyboarddialog.keyboard.texteditbox.hintText = "Enter Video Name Here"
  end if
  children = m.keyboarddialog.buttonGroup.getChildren(-1,0)
  for each child in children
    child.iconUri=""
    child.focusedIconUri=""
  end for
  m.top.appendChild(m.keyboarddialog)
  m.vgrid.setFocus(false)
  m.searchbutton.setFocus(false)
  m.keyboarddialog.setFocus(true)
end sub

sub searchEntered()
  if m.keyboarddialog.buttonGroup.buttonSelected = 0
    '? "Selected OK, continue with logic flow"
    if m.keyboarddialog.text <> ""
      '? "Valid Input"
      'search starting
      m.searchbutton.unobserveField("buttonSelected")
      searchquery = m.keyboarddialog.text
      m.failedSearchText = searchquery 'so we don't have to extract it from the Task later on.
      m.keyboarddialog.setFocus(false)
      m.searchbutton.setFocus(false)
      m.top.removeChild(m.keyboarddialog)
      m.vgrid.visible = false
      m.searchloading = True
      m.issearch = True
      m.searchbutton.text = "Loading..."
      m.loadingtext.visible = true
      m.loadingtext.text = "Loading your search results.."
      'm.searchbutton.setFocus(true)
      m.QueryLBRY.setField("method", "lighthouse")
      m.no_earlier = ">"+stri(m.date.AsSeconds()-7776000).Replace(" ", "").Trim()
      m.QueryLBRY.setField("input", {claimType: "file", mediaType: "video", size: 80, from: 0, expiration: m.no_earlier, query: searchquery})
      m.QueryLBRY.observeField("output", "gotLighthouse")
      m.QueryLBRY.control = "RUN"
    else if Len(m.keyboarddialog.text) > 16
      m.keyboarddialog.keyboard.texteditbox.hintText = "Length of search is too long, please either cancel or try again."
    else
      m.keyboarddialog.keyboard.texteditbox.hintText = "No text was entered, please either cancel or try again."
    end if
  else
    ? "Selected cancel, do not continue."
    m.keyboarddialog.setFocus(false)
    m.top.removeChild(m.keyboarddialog)
    m.searchbutton.setFocus(true)
  end if
end sub

sub gotLighthouse()
  m.QueryLBRY.control = "STOP"
  if isValid(m.QueryLBRY.output.result.noresults)
      ? "got nothing"
      m.searchFailed = True
      failedSearch()
  else
      base = m.QueryLBRY.output.result
      m.vgrid.content = base["content"]
      m.mediaindex = base["index"]
      handleDeepLink(m.global.deeplink)
      m.searchloading = False
      m.vgrid.visible = true
      m.loadingtext.visible = false
      m.searchbutton.text = "Go Back"
      m.searchbutton.observeField("buttonSelected", "closeSearch")
      m.vgrid.setFocus(true)
  end if
end sub

sub closeSearch()
  m.QueryLBRY.control = "STOP"
  m.searchbutton.unobserveField("buttonSelected")
  m.searchbutton.text = "Search Videos"
  base = m.JSONTask.output["PRIMARY_CONTENT"]
  m.vgrid.content = base["content"]
  m.mediaindex = base["index"]
  handleDeepLink(m.global.deeplink)
  m.searchloading = False
  m.issearch = False
  m.loadingtext.visible = False
  m.loadingtext.text = "Loading..."
  m.vgrid.visible = True
  m.vgrid.setFocus(true)
  m.searchbutton.observeField("buttonSelected", "searchMode")
end sub

sub cancelSearch()
  ? "cancelling search"
  m.QueryLBRY.control = "STOP"
  ? "task stopped"
  m.searchbutton.unobserveField("buttonSelected")
  m.searchbutton.text = "Search Videos"
  base = m.JSONTask.output["PRIMARY_CONTENT"]
  m.vgrid.content = base["content"]
  m.mediaindex = base["index"]
  handleDeepLink(m.global.deeplink)
  m.searchloading = False
  m.issearch = False
  m.loadingtext.visible = False
  m.loadingtext.text = "Loading..."
  m.vgrid.visible = True
  m.vgrid.setFocus(true)
  m.searchbutton.observeField("buttonSelected", "searchMode")
end sub

sub failedSearch()
  ? "search failed"
  m.QueryLBRY.control = "STOP"
  ? "task stopped"
  m.searchbutton.unobserveField("buttonSelected")
  m.searchbutton.text = "Search Videos"
  searchMode()
end sub

'sub searchMode()
'  ? "Button was selected."
'  m.issearch = True
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
'  m.searchbutton.setFocus(false)
'  m.keyboarddialog.setFocus(true)
'end sub

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
          m.canSelector = false
          m.canRight = false
      end if
      if m.selector.itemFocused <> 0
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
        if key = "back"  'If the back button is pressed
            if m.Video.visible
                returnToUIPage()
                return true
            else
                return false
            end if
        end if
        if (key = "right") and (m.selector.hasFocus() = true) and (m.canright = true)
          m.vgrid.setFocus(true)
          m.selector.setFocus(false)
        else if (key = "left") and (m.vgrid.hasFocus()= true) and (m.canSelector = true) and (m.issearch = false)
          m.canright = True
          m.selector.setFocus(true)
          m.vgrid.setFocus(false)
        else if (key = "up") and (m.isup = true) and (m.searchbutton.visible = true) and (m.useLegacyUI = true)
          m.vgrid.setFocus(false)
          m.searchbutton.setFocus(true)
        else if (key = "down") and (m.isup = true) and (m.searchbutton.visible = true) and (m.searchloading = false) and (m.useLegacyUI = true)
          m.searchbutton.setFocus(false)
          m.vgrid.setFocus(true)
        end if
    end if
end Function

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