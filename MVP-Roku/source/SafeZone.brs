' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

Function SafeZone(scene as object)
        dev = createObject("roDeviceInfo")
        poster = createObject("roSGNode", "Poster")
        poster.height = 1080
        poster.width = 1920
        poster.uri = "https://raw.githubusercontent.com/rokudev/safe-zone-channel/master/images/Outline-Safe-Zones-FHD.png"
        scene.appendChild(poster)
End Function