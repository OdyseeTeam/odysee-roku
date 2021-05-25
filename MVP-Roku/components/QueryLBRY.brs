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

    ? "Was executed (queryLBRY)."
    if IsValid(m.top.method) AND m.top.method = "startup" 'The app is starting up
            m.top.output = {result: checkAccount()}
    else if m.top.method = "lighthouse_search"
        ? "starting lighthouse"
        ? "DEBUG:"
        ? m.top.input
        if IsValid(m.top.input.claimType) AND m.top.input.claimType <> "channel"
            m.top.output = {result: ManufacturePlaceholderVideoGrid(20, "")}
        else if IsValid(m.top.input.claimType) AND m.top.input.claimType = "channel"
            m.top.output = {result: ManufacturePlaceholderChannelGrid(20)}
        end if
    else if m.top.method = "lighthouse_channel" OR m.top.method = "lighthouse_channel_options"
        if isValid(m.top.input.channelID) AND isValid(m.top.input.expiration)
            m.top.output = {result: ManufacturePlaceholderVideoGrid(20, "")}
        end if
    else if m.top.method = "resolve_video"
        if isValid(m.top.input.contentId) AND isValid(m.top.input.mediaType)
            m.top.output = {result: ManufacturePlaceholderVideoGrid(1, "")}
        end if
    end if
End Sub
