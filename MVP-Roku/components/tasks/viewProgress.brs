sub Init()
    m.top.functionName = "sendViewProgress"
end sub

sub sendViewProgress()
    if not IsValid(m.top.constants) or not IsValid(m.top.constants["ROOT_API"]) then return
    if not IsValid(m.top.uri) or m.top.uri = "" then return
    if not IsValid(m.top.claimId) or m.top.claimId = "" then return
    if not IsValid(m.top.lastTimestamp) or m.top.lastTimestamp = 0 then return

    ' Build request data
    reqData = {
        uri: m.top.uri,
        claim_id: m.top.claimId,
        last_timestamp: m.top.lastTimestamp
    }

    ' Add outpoint if available
    if IsValid(m.top.outpoint) and m.top.outpoint <> ""
        reqData.outpoint = m.top.outpoint
    end if

    ' Build API URL
    apiURL = m.top.constants["ROOT_API"] + "/file/view"

    ' Set auth headers/data based on auth type
    reqHeaders = {}
    if IsValid(m.top.accessToken) and m.top.accessToken <> ""
        reqHeaders = { "Authorization": "Bearer " + m.top.accessToken }
    else if IsValid(m.top.authToken) and m.top.authToken <> ""
        reqData.auth_token = m.top.authToken
    else
        ' No auth available
        return
    end if

    ' Send request
    try
        response = getURLEncoded(reqData, apiURL, reqHeaders)
        ?"[ViewProgress] Response received"
    catch e
        ?"[ViewProgress] Error sending view progress: "; e.message
    end try
end sub
