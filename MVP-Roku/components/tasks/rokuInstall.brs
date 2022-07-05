Sub Init()
    m.top.functionName = "master"
End Sub

sub master()
    '?m.top.constants
    '?m.top.cookies
    '?m.top.uid
    '?m.top.authtoken
    '?m.top.channels
    '?m.top.rawname
    m.top.output = installRoku()
End Sub

Function installRoku()
    '1. Check user (https://api.odysee.com/user/me) (getURLEncoded w/auth_token)
    '1a. if deviceTypes do not contain Roku, continue to 2, else, return installed: True w/o any further API interaction.
    '2. https://api.odysee.com/install/new  (getURLEncoded (see below for the gist of it))
    '
    appInfo = CreateObject("roAppInfo") 'get app version
    appVersion = appInfo.GetVersion()
    deviceInfo = CreateObject("roDeviceInfo")
    deviceVersionArray = deviceInfo.GetOSVersion()
    deviceModel = deviceInfo.GetModel()
    deviceVersion = deviceVersionArray.major+"."+deviceVersionArray.minor+"."+deviceVersionArray.revision+"."+deviceVersionArray.build
    deviceInfo = invalid
    appInfo = invalid
    fullPlatform = "roku-"+deviceVersion+"-"+deviceModel
    userAPI = m.top.constants["ROOT_API"]+"/user/me"
    installAPI = m.top.constants["ROOT_API"]+"/install/new"
    versionAPI = m.top.constants["QUERY_API"]+"/api/v1/proxy?m=version"
    versionRequestJSON = FormatJson({"jsonrpc":"2.0","method":"version","params":{}})

    currentexternalVersion = postJSON(versionRequestJSON,versionAPI, invalid)
    try
        daemon_version = currentexternalVersion["result"]["version"]
        daemon_platform = currentexternalVersion["result"]["platform"]
    catch e
        return {installed: false, error: true}
    end try

    installQuery = {"auth_token": m.top.authToken, "app_version": appVersion, "domain": "odysee.com", "app_id": "rokueecom692EAWhtoqDuAfQ6KHMXxFxt8tkhmt7sfprEMHWKjy5hf6PwZcHDV542V", "node_id": "", "daemon_version": daemon_version, "operating_system": "roku", "platform": fullPlatform}
    ?"[rokuInstall]:"
    ?installQuery
    getInstall = getURLEncoded(installQuery, userAPI, [])
    return {installed: getInstall["success"]}
End Function