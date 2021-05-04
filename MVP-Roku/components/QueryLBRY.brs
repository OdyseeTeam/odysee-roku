Sub Init()
    m.top.functionName = "master"
End Sub

sub master()

    'FOR REFERENCE, please change when QueryLBRY.xml changes.
    '<!--Universal Output-->
    '<field id="method" type="String"/>
    '<field id="input" type="roAssociativeArray"/>
    '<field id="output" type="roAssociativeArray"/>
    '<!--Account-Specific Vars-->
    '<field id="uid" type="Int"/>
    '<field id="authtoken" type="String"/>
    '<field id="cookies" type="roArray"/>

    'The flow (in general):
    'Startup -> Get Anonymous Account (inside) which is done regardless of user input
    'Application -> User hits "Login", dialog box sequence starts.
    'Exists query executed, data output as true/false into AssociativeArray, querydata returned, UI altered based on input
    'If the user exists:
    ' - Enter password
    ' - Login using credentials
    'If the user does not exist:
    ' - Close Dialog
    ? "Was executed (queryLBRY)."
    if IsValid(m.top.method) AND m.top.method = "startup" 'The app is starting up
            m.top.output = {result: checkAccount()}
    else if m.top.method = "lighthouse_search"
        ? "starting lighthouse"
        if IsValid(m.top.input.claimType) AND IsValid(m.top.input.mediaType) AND IsValid(m.top.input.size) AND IsValid(m.top.input.from) AND IsValid(m.top.input.expiration) AND IsValid(m.top.input.query)
            m.top.output = {result: lighthouse_videos(m.top.input.claimType, m.top.input.mediaType, m.top.input.size, m.top.input.from, m.top.input.expiration, m.top.input.query)}
        else if IsValid(m.top.input.claimType) AND IsValid(m.top.input.from) AND IsValid(m.top.input.size) AND IsValid(m.top.input.query) AND m.top.input.claimType = "channel"
            m.top.output = {result: lighthouse_channels(m.top.input.claimType, m.top.input.size, m.top.input.from, m.top.input.query)}
        end if
    else if m.top.method = "lighthouse_channel" OR m.top.method = "lighthouse_channel_options"
        if isValid(m.top.input.channelID) AND isValid(m.top.input.expiration)
            m.top.output = {result: lighthouse_channel(m.top.input.channelID, m.top.input.expiration)}
        end if
    else if m.top.method = "resolve_video"
        if isValid(m.top.input.contentId) AND isValid(m.top.input.mediaType)
            m.top.output = {result: resolve_video(m.top.input.contentId)}
        end if
    else if m.top.method = "exists" 'Checking if user exists
        if IsValid(m.top.input.email)
            m.top.output = {result: exists(m.top.input.email)}
        end if
    else if m.top.method = "login" 'Log user in
        if IsValid(m.top.input.email) AND IsValid(m.top.input.password)
            result = login(m.top.input.email, m.top.input.password)
            m.top.output = {result: result.success, data: result.data}
        end if
    else if m.top.method = "me"
        result = me()
        m.top.output = {result: result.success, data: result.data}
    else if m.top.method = "balance"
        result = getbal()
        m.top.output = {result: result}
    else if m.top.method = "logout" 'Log user out
        logout()
        m.top.output = {result: True}
    end if
End Sub
