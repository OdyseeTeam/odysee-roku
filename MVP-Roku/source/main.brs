sub Main(args)

    screen = CreateObject("roSGScreen")  'Create Screen object
    m.port = CreateObject("roMessagePort")  'Create Message port
    screen.setMessagePort(m.port)  'Set message port to listen to screen
    debug = true
    scene = screen.CreateScene("HomeScene")  'Create HomeScene
    m.global = screen.getGlobalNode()
    constants = {}
    m.di = CreateObject("roDeviceInfo")
    constants.enableStatistics = true 'allows user preference, easy location of related code, and quick debugging if stats cause problems indev
    constants.rokuModel = m.di.GetModel()
    constants.rokuType = m.di.GetModelType()
    constants.APIConstantsURL = "https://raw.githubusercontent.com/OdyseeTeam/odysee-frontend/master/.env.defaults"
    constants.livestreamConstantsURL = "https://raw.githubusercontent.com/OdyseeTeam/odysee-frontend/master/ui/constants/livestream.js"
    constants.userAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.71 Safari/537.36" 'Used in all HTTP/s requests.
    ' Promote sanitized deep link params to scene and globals
    contentId$ = "": mediaType$ = ""
    deeplinkAA = invalid
    if type(args) = "roAssociativeArray"
        if args.DoesExist("contentID") then contentId$ = args.contentID
        if contentId$ = "" and args.DoesExist("contentId") then contentId$ = args.contentId
        if contentId$ = "" and args.DoesExist("content_id") then contentId$ = args.content_id
        if args.DoesExist("mediaType") then mediaType$ = args.mediaType
        if mediaType$ = "" and args.DoesExist("mediatype") then mediaType$ = args.mediatype
        if mediaType$ = "" and args.DoesExist("media_type") then mediaType$ = args.media_type
        if (contentId$ = "" or mediaType$ = "") and args.DoesExist("query")
            q$ = args.query
            parts = q$.split("&")
            for each p in parts
                kv = p.split("=")
                if kv.count() >= 2
                    k$ = LCase(kv[0])
                    v$ = kv[1]
                    if contentId$ = "" and (k$ = "contentid" or k$ = "content_id") then contentId$ = v$
                    if mediaType$ = "" and (k$ = "mediatype" or k$ = "media_type") then mediaType$ = v$
                end if
            end for
        end if
        if contentId$ <> "" and mediaType$ <> ""
            scene.setFields({ contentId: contentId$, mediaType: mediaType$ })
            deeplinkAA = { contentId: contentId$, type: mediaType$ }
        end if
    end if
    m.global.addFields( {debug: debug, constants: constants} )
    if deeplinkAA <> invalid then m.global.addFields({ deeplink: deeplinkAA })
    '"args= "; formatjson(args)      'pretty print AA'
    screen.show()
    while(true)  'Listens to see if screen is closed
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub