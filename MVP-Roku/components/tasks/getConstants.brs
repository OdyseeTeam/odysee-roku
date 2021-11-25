sub Init()
    m.top.functionName = "master"
end sub

sub master()
    globalAPIConstants = getJSON("https://raw.githubusercontent.com/OdyseeTeam/odysee-roku/indev/appConstants.json")
    m.top.constants = globalAPIConstants
end sub
