sub Main(args)

    screen = CreateObject("roSGScreen")  'Create Screen object
    m.port = CreateObject("roMessagePort")  'Create Message port
    screen.setMessagePort(m.port)  'Set message port to listen to screen
    debug = true
    scene = screen.CreateScene("HomeScene")  'Create HomeScene
    m.global = screen.getGlobalNode()
    constants = {}
    constants.enableStatistics = true 'allows user preference, easy location of related code, and quick debugging if stats cause problems indev. will be added to user settings later.
    constants.APIConstantsURL = "https://raw.githubusercontent.com/OdyseeTeam/odysee-frontend/master/.env.defaults"
    constants.livestreamConstantsURL = "https://raw.githubusercontent.com/OdyseeTeam/odysee-frontend/master/ui/constants/livestream.js"
    constants.userAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36" 'Used in all HTTP/s requests.
    constants.frontpageURL = "https://odysee.com/$/api/content/v1/get" ' Most constants are set by Github (desktop app), but the frontpage endpoint is Roku-Specific.
    m.global.addFields( {debug: debug, scene: scene, constants: constants, deeplink: args} ) 'Add global debug variable
    '?"args= "; formatjson(args)      'pretty print AA'
    screen.show()
    while(true)  'Listens to see if screen is closed
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub