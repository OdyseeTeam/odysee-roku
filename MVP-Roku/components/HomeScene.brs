Sub init()

    'UI Logic Variables
    m.loaded = False 'Has the app finished its first load?
    m.canright = False 'Can we move from the video grid (VGRID) to the selector bar (SELECTOR)?
    m.isleft = True 'Are we on the leftmost item of the video grid and ready to transition to the selector?
    m.modelwarning = False 'Are we running on a model of Roku that does not load 1080p video correctly?

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
    m.QueryLBRY=createObject("roSgNode","QueryLBRY")
    m.QueryLBRY.observeField("resp", "gotResponse")
    m.QueryLBRY.observeField("cookies", "cookiesUpdated")

    'Registry
    m.registry = CreateObject("roRegistrySection", "Authentication")

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

    ' LOGIC:
      ' Check if data storage for user used.
      ' If so: Run a query that only an existing account can do.
      ' If it works: we are fine
      ' If it does not work: we need to make an account, so createAccount is called again.
      ' If not: create an account, and add it to the datastore.
      if isValid(GetRegistry("uid")) AND isvalid(GetRegistry("authtoken")) AND isvalid(GetRegistry("cookies"))
        '? "found account with UID"+GetRegistry("uid")
        m.uid = StrToI(GetRegistry("uid"))
        m.authtoken = GetRegistry("authtoken")
        m.cookies = ParseJSON(GetRegistry("cookies"))
      else
        '? "no entries found, creating account."
        m.cookies = [] 'prevent invalid
        createAccount()
      end if

      m.JSONTask = createObject("roSGNode", "JSONTask")
      m.JSONTask.setField("thumbnaildims", [m.maxThumbWidth, m.maxThumbHeight])
      m.JSONTask.observeField("output", "AppFinishedFirstLoad")
      m.JSONTask.control = "RUN"
End Sub

function getselectorData() as object
  data = CreateObject("roSGNode", "ContentNode")
  names = ["Home", "Cheese", "Big Hits", "Gaming", "Lab", "Tech", "News & Politics", "Finance 2.0", "The Universe", "Wild West"]
  for i = 1 to 10
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
  m.vgrid.setFocus(true)
  m.global.scene.signalBeacon("AppLaunchComplete")
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
  '? m.vgrid.rowitemFocused
  if m.vgrid.rowItemFocused[1] = 0
    m.isleft=True
    '? "is left, can transition"
  else
    m.isleft=False
    '? "not left, can't transition"
  end if
  if isValid(m.vgrid.rowItemFocused)
    m.videoContent.url = m.vgrid.content.getChild(m.vgrid.rowItemFocused[0]).getChild(m.vgrid.rowItemFocused[1]).URL
    m.videoContent.streamFormat = "mp4"
    keepPlaying = false
    m.Video.content = m.videoContent
    '? m.videoContent.url
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
      '0 = Primary
      '1 = Cheese
      '2 = Big Hits
      '3 = Gaming
      '4 = Lab/Science
      '5 = Tech/Technology
      '6 = News&Politics
      '7 = Finance 2.0
      '8 = The Universe
      '9 = Wild West

      'if only BrightScript had Case Switch =(

      if m.selector.itemFocused = 0
          base = m.JSONTask.output["PRIMARY_CONTENT"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 1
          base = m.JSONTask.output["CHEESE"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 2
          base = m.JSONTask.output["BIG_HITS"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 3
          base = m.JSONTask.output["GAMING"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 4
          base = m.JSONTask.output["SCIENCE"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 5
          base = m.JSONTask.output["TECHNOLOGY"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 6
          base = m.JSONTask.output["NEWS"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 7
          base = m.JSONTask.output["FINANCE"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 8
          base = m.JSONTask.output["THE_UNIVERSE"]
          m.vgrid.content = base["content"]
          m.mediaindex = base["index"]
      else if m.selector.itemFocused = 9
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
        else if (key = "left") and (m.vgrid.hasFocus()= true) and (m.isleft = true)
          m.canright = True
          m.selector.setFocus(true)
          m.vgrid.setFocus(false)
        end if
    end if
end Function

''LBRY REGISTRY+HTTP CODE BELOW

Function IsValid(value As Dynamic) As Boolean 'TheEndless Roku Development forums
    Return Type(value) <> "<uninitialized>" And value <> invalid
End Function

Function queryLBRY(query, endpoint)
  m.QueryLBRY.setField("query",{"query": query, "endpoint": endpoint})
  m.QueryLBRY.setfield("cookies", [])
  m.QueryLBRY.control = "RUN"
end Function

sub gotResponse(msg as Object)
  if type(msg) = "roSGNodeEvent"
      input = msg.getData()
      if input.success = true
        if IsValid(input.data)
          data = input.data
          if IsValid(data.id) AND IsValid(data.created_at)
            m.uid = data.id
            SetRegistry("uid", m.uid.toStr())
          end if
          if IsValid(data.auth_token)
            m.authtoken = data.auth_token
            SetRegistry("authtoken", m.authtoken)
          end if
        else
          createAccount() 'Our account expired. Create another.
      end if
    end if
  end if
end sub

sub cookiesUpdated(msg as Object)
  if type(msg) = "roSGNodeEvent"
      m.cookies = msg.getData()
      SetRegistry("cookies", FormatJSON(m.cookies))
  end if
  m.QueryLBRY.control = "STOP"
end sub