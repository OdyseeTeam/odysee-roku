sub Init()
    m.top.functionName = "master"
    m.authTimer = m.top.findNode("authTimer") 'refresh timer
end sub

sub master()
    try
        if m.top.authPhase = 0
            '"Legacy" auth flow here
            ?"Phase 0"
            ?"Start 'Legacy'/older authentication"
            ?"Current Constants are:"
            ?m.top.constants
            userAPI = m.top.constants["ROOT_API"] + "/user"
            new = userAPI + "/new"
            existing = userAPI + "/me"
            currentUserStatus = getURLEncoded({ auth_token: m.top.authtoken.Trim() }, existing, { "Authorization": "Bearer " + m.top.accessToken })
            ?FormatJSON(currentUserStatus)
            if isValid(currentUserStatus)
                if currentUserStatus.success
                    ?"SUCCESS."
                    m.top.uid = currentUserStatus.data.id
                    m.top.legacyAuthorized = true
                    m.top.authPhase = 1
                else
                    ?"FAILURE! (accessToken is invalid)"
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
            initOAuthTokenBase()
        else if m.top.authPhase = 1 and m.top.refreshToken <> ""
            ?"got a valid Refresh Token from Registry"
            m.authTimer.duration = 10
            m.authTimer.control = "start"
            checkRefresh()
        end if
        if m.top.authPhase = 1.4 'Post-Logout Token Init
            initOAuthTokenBase()
        end if
        if m.top.authPhase = 1.5 'SSO has denied the application. Continue running anyway.
            m.top.badSSO = true
            m.top.authPhase = 2
        end if
        if m.top.authPhase = 2
            if m.top.badSSO = false
                accountRoot = m.top.constants["ROOT_SSO"] + ""
                json = { grant_type: "urn:ietf:params:oauth:grant-type:device_code": client_id: m.top.constants["SSO_CLIENT"]: device_code: m.top.deviceCode }
                authreq = postURLEncoded(json, accountRoot + "/auth/realms/Users/protocol/openid-connect/token", {})
                ?FormatJson(authreq)
                if isValid(authreq.error)
                    if authreq.error = "slow_down"
                        m.authTimer.duration = m.authTimer.duration + 1
                    else if authreq.error = "authorization_pending"
                        m.top.output = { authorized: false, state: "PENDING", debug: authreq }
                    else if authreq.error = "invalid_grant" or authreq.error = "expired_token" 'https://datatracker.ietf.org/doc/html/draft-ietf-oauth-device-flow-15#section-3.5
                        m.top.authPhase = 1.4
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
            else
                m.top.verifyURL = "none"
                m.top.deviceCode = "NO-AUTH-SERVER"
                m.top.output = { authorized: true, state: "OK", debug: { "bad-sso": true } }
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
            m.top.authPhase = 1.4
            m.top.output = { authorized: false, state: "INVALID", debug: authreq }
        end if
        if m.top.authPhase = 10 'User wants to log out.
            try
                accountRoot = m.top.constants["ROOT_SSO"] + ""
                revokeRefreshReq = postURLEncoded({ token: m.top.refreshToken: token_type_hint: "refresh_token": client_id: m.top.constants["SSO_CLIENT"] }, accountRoot + "/auth/realms/Users/protocol/openid-connect/revoke", { "Authorization": "Bearer " + m.top.accessToken })
                revokeAccessReq = postURLEncoded({ token: m.top.accessToken: token_type_hint: "access_token": client_id: m.top.constants["SSO_CLIENT"] }, accountRoot + "/auth/realms/Users/protocol/openid-connect/revoke", { "Authorization": "Bearer " + m.top.accessToken })
                ? accountRoot
                ? formatJson(revokeRefreshReq)
                ? formatJson(revokeAccessReq)
                logOutSuccess = false
                if isValid(revokeAccessReq.error)
                    if revokeAccessReq.error = "invalid_token"
                        m.top.accessToken = ""
                        m.top.refreshToken = ""
                        m.top.authPhase = 1.4
                        logOutSuccess = true
                        m.top.output = { authorized: false, state: "LOGOUT", debug: { refresh: revokeRefreshReq: access: revokeAccessReq } }
                    end if
                end if
                if logOutSuccess = false
                    'assume SSO is being bad (non-rfc7009 compliant), so don't bother using it anymore.
                    m.top.authPhase = 1.5 'BAD_SSO
                end if
            catch e
                m.top.authPhase = 1.5 'BAD_SSO
            end try
        end if
    catch e
        m.top.authPhase = -10 'CRITICAL: everything is dead.
    end try
end sub

sub initOAuthTokenBase()
    try
        accountRoot = m.top.constants["ROOT_SSO"] + ""
        json = { response_type: "device_code": client_id: m.top.constants["SSO_CLIENT"] }
        authreq = postURLEncoded(json, accountRoot + "/auth/realms/Users/protocol/openid-connect/auth/device", {})
        if isValid(authreq.error)
            'BAD SSO.
            'If we can't grab a device code, don't bother with further authentication.
            m.top.authPhase = 1.5
        else if authreq.user_code <> ""
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
        end if
    catch e
        m.top.authPhase = 1.5
    end try
end sub

sub checkRefresh()
    curUnixTime = CreateObject("roDateTime").AsSeconds()
    if curUnixTime > m.top.accessTokenExpiration
        ?"token expired, renew"
        m.top.output = { authorized: false, state: "PENDING", debug: {} }
        json = { grant_type: "refresh_token": refresh_token: m.top.refreshToken: client_id: m.top.constants["SSO_CLIENT"] }
        accountRoot = m.top.constants["ROOT_SSO"] + ""
        authreq = postURLEncoded(json, accountRoot + "/auth/realms/Users/protocol/openid-connect/token", {})
        try
            if isValid(authreq.error)
                if authreq.error = "invalid_client"
                    'BAD SSO.
                    m.top.authPhase = 1.5
                else
                    m.top.authPhase = 4
                    m.top.accessToken = ""
                    m.top.refreshToken = ""
                    m.top.output = { authorized: false, state: "INVALID", debug: authreq }
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
                m.top.output = { authorized: true, state: "OK", debug: authreq }
                m.top.authPhase = 3
            end if
        catch e
            m.top.authPhase = 1.5
            m.top.accessToken = ""
            m.top.refreshToken = ""
            m.top.output = { authorized: false, state: "INVALID", debug: authreq }
        end try
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
        accountRoot = m.top.constants["ROOT_SSO"] + ""
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