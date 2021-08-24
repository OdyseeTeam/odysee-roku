sub Main(args)

    screen = CreateObject("roSGScreen")  'Create Screen object
    m.port = CreateObject("roMessagePort")  'Create Message port
    screen.setMessagePort(m.port)  'Set message port to listen to screen
    debug = true
    scene = screen.CreateScene("HomeScene")  'Create HomeScene
    m.global = screen.getGlobalNode()
    constants = {}
    constants.APIConstantsURL = "https://raw.githubusercontent.com/lbryio/lbry-desktop/master/.env.defaults"
    constants.livestreamConstantsURL = "https://raw.githubusercontent.com/lbryio/lbry-desktop/master/ui/constants/livestream.js"
    constants.userAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36" 'Used in all HTTP/s requests.
    constants.frontpageURL = "https://odysee.com/$/api/content/v1/get" ' Most constants are set by Github (desktop app), but the frontpage endpoint is Roku-Specific.
    constants.imageProcessor = "https://image-processor.vanwanet.com/optimize/s:390:220/quality:85/plain/" 'Image Processor URL
    m.global.addFields( {debug: debug, scene: scene, constants: constants, deeplink: args} ) 'Add global debug variable
    '? "args= "; formatjson(args)      'pretty print AA'
    screen.show()
    while(true)  'Listens to see if screen is closed
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub