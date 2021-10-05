Sub Init()
    m.top.functionName = "master"
End Sub

sub master()
    ? "Current Constants are:"
    ? m.top.constants
    ? "UID/AT/Cookies:"
    ? m.top.uid
    ? m.top.authtoken
    ? m.top.cookies
    userAPI = m.top.constants["ROOT_API"]+"/user"
    new = userAPI+"/new"
    existing = userAPI+"/me"
    currentUserStatus = getURLEncoded({auth_token: m.top.authtoken.Trim()}, existing, [])
    ? currentUserStatus
    if currentUserStatus.success
        ? "SUCCESS."
        m.top.uid = currentUserStatus.data.id
    else
        ? "FAILURE!"
            newUserData = parseJSON(getRawText(new))
            currentUserStatus = getURLEncoded({auth_token: newUserData.data.auth_token.Trim()}, existing, [])
            if currentUserStatus.success = false
                m.top.error = true
            else
                m.top.uid = newUserData.data.id
                m.top.authtoken = newUserData.data.auth_token
            end if
    end if
    if m.top.error
        m.top.output = {result: {error: true}}
    else
        m.top.output = {result: {uid: m.top.uid, authtoken: m.top.authtoken}} 'checkAccount()
    end if
End Sub