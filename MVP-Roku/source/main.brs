sub Main(args)

    screen = CreateObject("roSGScreen")  'Create Screen object
    m.port = CreateObject("roMessagePort")  'Create Message port
    screen.setMessagePort(m.port)  'Set message port to listen to screen

    scene = screen.CreateScene("HomeScene")  'Create HomeScene
    m.global = screen.getGlobalNode()
    
    m.global.addFields( {scene: scene, deeplink: args} ) 'Add the scene so we can pass Roku certification.
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