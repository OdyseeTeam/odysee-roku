sub Init()
    m.top.functionName = "master"
end sub

sub master()
    globalAPIConstants = getJSON("https://raw.githubusercontent.com/OdyseeTeam/odysee-roku/indev/appConstants.json")
    globalAPIConstants["ROOT_API"] = "https://api.odysee.com" 'API is used for reacting to claims and setting the wallet on Odysee
    globalAPIConstants["ROOT_SSO"] = "https://sso.odysee.com" 'SSO is used for device flow authentication+getting credentials for setting+getting the user's wallet
    globalAPIConstants["ROOT_SDK"] = "https://sdk.odysee.com" 'SDK is used for changing wallet (follow/unfollow/etc.)
    globalAPIConstants["FRONTPAGE_URL"] ="https://odysee.com/$/api/content/v1/get"
    'globalAPIConstants["ROOT_API"] = "http://192.168.30.140:8082"
    'globalAPIConstants["ROOT_SDK"] = "http://192.168.30.140:8081"
    'globalAPIConstants["ROOT_SSO"] = "http://192.168.30.140:8080"
    m.top.constants = globalAPIConstants
end sub
