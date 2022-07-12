sub Init()
    m.top.functionName = "master"
end sub

sub master()
    'globalAPIConstants = getJSON("http://192.168.1.16/appConstants.json") 'used internally for testing appConstants before pushing to Github
    globalAPIConstants = getJSON("https://raw.githubusercontent.com/OdyseeTeam/odysee-roku/device-flow/appConstants.json")
    if isValid(globalAPIConstants["FRONTPAGE_URL"]) = false
        globalAPIConstants["FRONTPAGE_URL"] = "https://odysee.com/$/api/content/v2/get"
    end if
    if isValid(globalAPIConstants["ROOT_API"]) = false
        globalAPIConstants["ROOT_API"] = "https://api.odysee.com" 'API is used for reacting to claims and setting the wallet on Odysee
    end if
    if isValid(globalAPIConstants["ROOT_SSO"]) = false
        globalAPIConstants["ROOT_SSO"] = "https://sso.odysee.com" 'SSO is used for device flow authentication+getting credentials for setting+getting the user's wallet
    end if
    if isValid(globalAPIConstants["SSO_CLIENT"]) = false
        globalAPIConstants["SSO_CLIENT"] = "odysee-roku" 'SSO is used for device flow authentication+getting credentials for setting+getting the user's wallet
    end if
    if isValid(globalAPIConstants["ROOT_SDK"]) = false
        globalAPIConstants["ROOT_SDK"] = "https://api.na-backend.odysee.com" 'SDK is used for changing wallet (follow/unfollow/etc.)
    end if
    if isValid(globalAPIConstants["CHANNEL_ICON_PROCESSOR"]) = false
        globalAPIConstants["CHANNEL_ICON_PROCESSOR"] = "https://thumbnails.odycdn.com/optimize/s:100:0/quality:85/plain/"
    end if
    if isValid(globalAPIConstants["ACCESS_HEADERS"]) = false
        globalAPIConstants["ACCESS_HEADERS"] = { "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.71 Safari/537.36",
            "origin": "https://odysee.com",
            "referer": "https://roku.odysee.com/",
            "Access-Control-Allow-Origin": "https://odysee.com/"
        }
    end if
    if isValid(globalAPIConstants["SSO_ACT_URL"]) = false
        globalAPIConstants["SSO_ACT_URL"] = "activate.odysee.com"
    end if
    m.top.constants = globalAPIConstants
end sub
