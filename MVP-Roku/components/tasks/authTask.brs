sub Init()
    m.top.functionName = "master"
    m.authTimer = m.top.findNode("authTimer") 'refresh timer
end sub

sub master()
    if m.top.authPhase = 0
        '"Legacy" auth flow here
        ?"Phase 0"
        ?"Start 'Legacy'/older authentication"
        ?"Current Constants are:"
        ?m.top.constants
        userAPI = m.top.constants["ROOT_API"] + "/user"
        new = userAPI + "/new"
        existing = userAPI + "/me"
        currentUserStatus = getURLEncoded({ auth_token: m.top.authtoken.Trim() }, existing, [])
        ?currentUserStatus
        if currentUserStatus.success
            ?"SUCCESS."
            m.top.uid = currentUserStatus.data.id
            m.top.legacyAuthorized = true
            m.top.authPhase = 1
        else
            ?"FAILURE!"
            newUserData = parseJSON(getRawText(new))
            currentUserStatus = getURLEncoded({ auth_token: newUserData.data.auth_token.Trim() }, existing, [])
            if currentUserStatus.success = false
                m.top.error = true
                m.top.legacyAuthorized = false
                m.top.output = { authorized: false, state: "CRITICAL", debug: "Failed Phase 0" }
            else
                m.top.uid = newUserData.data.id
                m.top.authtoken = newUserData.data.auth_token
                m.top.legacyAuthorized = true
                m.top.authPhase = 1
            end if
        end if
    end if
    if m.top.authPhase = 1 and m.top.refreshToken = ""
        'So the flow:
        'Make a call here to get a user code from the IDP
        'https://sso.odysee.com/auth/realms/Users/protocol/openid-connect/auth/device
        ' Tell the user to go here to enter that user code in. They go through authentication and approve the roku app.
        'http://odysee.com/$/activate
        ' Then you poll the token endpoint with the returned device_code to get an access token.
        'https://sso.odysee.com/auth/realms/Users/protocol/openid-connect/token
        ?"authphase is 1: begin new auth"
        accountRoot = m.top.constants["ROOT_SSO"]+""
        json = { response_type: "device_code": client_id: "odysee-roku-unofficial" }
        authreq = postURLEncoded(json, accountRoot + "/auth/realms/Users/protocol/openid-connect/auth/device", {})
        m.top.verifyURL = authreq.verification_uri
        m.top.deviceCode = authreq.device_code
        m.top.userCode = authreq.user_code
        ?authreq.expires_in
        ?"Interval is (TIMER/authtask):"
        ?authreq.interval
        m.authTimer.duration = authreq.interval + 1
        m.authTimer.control = "start"
        ?authreq.verification_uri_complete
        m.top.authPhase = 2
    else if m.top.authPhase = 1 and m.top.refreshToken <> ""
        ?"got a valid Refresh Token from Registry"
        m.authTimer.duration = 10
        m.authTimer.control = "start"
        checkRefresh()
    end if
    if m.top.authPhase = 2
        accountRoot = m.top.constants["ROOT_SSO"]+""
        json = { grant_type: "urn:ietf:params:oauth:grant-type:device_code": client_id: "odysee-roku-unofficial": device_code: m.top.deviceCode }
        authreq = postURLEncoded(json, accountRoot + "/auth/realms/Users/protocol/openid-connect/token", {})
        ?FormatJson(authreq)
        if isValid(authreq.error)
            if authreq.error = "slow_down"
                m.authTimer.duration = m.authTimer.duration + 1
            else if authreq.error = "authorization_pending"
                m.top.output = { authorized: false, state: "PENDING", debug: authreq }
            else if authreq.error = "invalid_grant"
                m.top.authPhase = 1
                m.top.output = { authorized: false, state: "INVALID", debug: authreq }
            else
                m.top.output = authreq
            end if
        end if
        if isValid(authreq.access_token)
            m.top.accessToken = authreq.access_token
            m.top.refreshToken = authreq.refresh_token
            'authreq.expires_in
            'authreq.refresh_expires_in
            curUnixTime = CreateObject("roDateTime").AsSeconds()
            m.top.accessTokenExpiration = curUnixTime + authreq.expires_in
            m.top.refreshTokenExpiration = curUnixTime + authreq.refresh_expires_in
            ?"Access Expires At:"
            ?m.top.accessTokenExpiration
            ?"Refresh Expires At:"
            ?m.top.refreshTokenExpiration
            curUnixTime = invalid
            m.authTimer.duration = 10
            m.top.authPhase = 3
            m.top.output = { authorized: true, state: "OK", debug: authreq }
        end if
    end if
    if m.top.authPhase = 3
        'authPhase is 3, so we need to refresh the Authentication Token.
        checkRefresh()
    end if
    if m.top.authPhase = 4
        'authPhase is 4, Forced logout.
        ?"Inside forced logout phase"
        m.top.accessToken = ""
        m.top.refreshToken = ""
        m.top.authPhase = 1
        m.top.output = { authorized: false, state: "INVALID", debug: authreq }
    end if
    if m.top.authPhase = 10 'User wants to log out.
        'https://stackoverflow.com/a/46769801 really helped me out with this
        json = {refresh_token: m.top.refreshToken: client_id: "odysee-roku-unofficial"}
        accountRoot = m.top.constants["ROOT_SSO"]+""
        authreq = postURLEncoded(json, accountRoot + "/auth/realms/Users/protocol/openid-connect/logout", { "Authorization": "Bearer " + m.top.accessToken })
        ? json
        ? accountRoot
        ? formatJson(authreq)
        m.top.accessToken = ""
        m.top.refreshToken = ""
        m.top.authPhase = 1
        m.top.output = { authorized: false, state: "LOGOUT", debug: authreq }
    end if
end sub

sub checkRefresh()
    curUnixTime = CreateObject("roDateTime").AsSeconds()
    if curUnixTime > m.top.accessTokenExpiration
        ?"token expired, renew"
        m.top.output = { authorized: false, state: "PENDING", debug: {} }
        json = { grant_type: "refresh_token": refresh_token: m.top.refreshToken: client_id: "odysee-roku-unofficial" }
        accountRoot = m.top.constants["ROOT_SSO"]+""
        authreq = postURLEncoded(json, accountRoot + "/auth/realms/Users/protocol/openid-connect/token", {})
        if isValid(authreq.error)
            m.top.authPhase = 4
            m.top.accessToken = ""
            m.top.refreshToken = ""
            m.top.authPhase = 1
            m.top.output = { authorized: false, state: "INVALID", debug: authreq }
        end if
        if isValid(authreq.access_token)
            m.top.accessToken = authreq.access_token
            m.top.refreshToken = authreq.refresh_token
            'authreq.expires_in
            'authreq.refresh_expires_in
            curUnixTime = CreateObject("roDateTime").AsSeconds()
            m.top.accessTokenExpiration = curUnixTime + authreq.expires_in
            m.top.refreshTokenExpiration = curUnixTime + authreq.refresh_expires_in
            ?"Access Expires At:"
            ?m.top.accessTokenExpiration
            ?"Refresh Expires At:"
            ?m.top.refreshTokenExpiration
            curUnixTime = invalid
            m.top.output = { authorized: true, state: "OK", debug: authreq }
            m.top.authPhase = 3
        end if
    else
        ?"token still valid"
        ?"current time:"
        ?curUnixTime
        ?"expiration time"
        ?m.top.accessTokenExpiration
        ?"Token is:"
        ?"`" + m.top.accessToken + "`"
        ?"Refresh is:"
        ?"`" + m.top.refreshToken + "`"
        ?"getting user info (TEST)"
        accountRoot = m.top.constants["ROOT_SSO"]+""
        authreq = getJSONAuthenticated(accountRoot + "/auth/realms/Users/protocol/openid-connect/userinfo", { "Authorization": "Bearer " + m.top.accessToken })
        ?FormatJson(authreq)
        if isValid(authreq.error)
            if authreq.error = "invalid_request"
                ?"Session not found, assuming token invalid."
                m.top.authPhase = 4
                m.top.accessToken = ""
                m.top.refreshToken = ""
                m.top.output = { authorized: false, state: "INVALID", debug: authreq }
            end if
        else
            m.top.authPhase = 3
        end if
    end if
    curUnixTime = invalid
end sub