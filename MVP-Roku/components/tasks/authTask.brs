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
    currentUserStatus = getURLEncoded({auth_token: m.top.authtoken}, existing, [])
    if currentUserStatus.success
        ? "SUCCESS."
        m.top.uid = currentUserStatus.data.id
    else
        ? "FAILURE!"
        creationAttempts = 0
        while creationAttempts < 5
            newUserData = getRawText(new)
            if instr(newUserData, "503") > 0
                creationAttempts+=1
            else
                m.top.uid = parseJSON(newUserData).data.id
                m.top.authtoken = parseJSON(newUserData).data.auth_token
                ? "successfully created new user"
                ? m.top.uid
                ? "with authToken"
                ? m.top.authtoken
                exit while
            end if
        end while
        if creationAttempts >= 5
            STOP 'debug
        end if
    end if
    m.top.output = {result: {uid: m.top.uid, authtoken: m.top.authtoken}} 'checkAccount()
End Sub