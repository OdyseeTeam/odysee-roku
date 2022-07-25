sub Init()
    m.top.functionName = "master"
end sub

sub master()
    '?m.top.constants
    '?m.top.cookies
    '?m.top.uid
    '?m.top.authtoken
    '?m.top.channels
    '?m.top.rawname
    m.top.output = resolve(m.top.url)
end sub

function resolve(lbry_url)
    try
        'get base URL
        ?lbry_url
        spliturl = lbry_url.split("#")
        friendlyname = spliturl[0].split("/")[2]
        return siteMethod(lbry_url)
    catch e
        m.top.error = true
        return { error: true }
    end try
end function

function siteMethod(lbry_url)
    getRequestJSON = FormatJson({ "jsonrpc": "2.0", "method": "get", "params": { "uri": lbry_url, "save_file": false } })
    getRequestURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=get"
    getRequestOutput = postJSON(getRequestJSON, getRequestURL, invalid)
    vurl = getRequestOutput["result"]["streaming_url"]
    'Video length is needed for more than just metadata, since our custom UI uses it as well.
    'Disabling statistics still disables sending it.
    resolveRequestJSON = FormatJson({ "jsonrpc": "2.0", "method": "resolve", "params": { "urls": [lbry_url], "include_purchase_receipt": false, "include_is_my_output": false } })
    resolveRequestURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=resolve"
    resolveRequestOutput = postJSON(resolveRequestJSON, resolveRequestURL, invalid)
    if m.global.constants.enableStatistics
        vTXID = resolveRequestOutput["result"][resolveRequestOutput["result"].Keys()[0]]["txid"]
        vNOUT = resolverequestoutput["result"][resolveRequestOutput["result"].Keys()[0]]["nout"]
        vCLAIMID = resolverequestoutput["result"][resolveRequestOutput["result"].Keys()[0]]["claim_id"]
        outpoint = vTXID + ":" + vNOUT.ToStr()
        fileViewURL = m.top.constants["ROOT_API"] + "/file/view"
        'uri: lbryURL
        'outpoint: resolve TXID+":"+resolve NOUT
        'claim_id: claimID
        if isValid(m.top.accessToken) AND m.top.accessToken <> ""
            reqData = {uri: lbry_url, outpoint: outpoint, claim_id: vCLAIMID}
            reqHeaders = { "Authorization": "Bearer " + m.top.accessToken }
        else if isValid(m.top.authToken) AND m.top.authToken <> ""
            reqData = {uri: lbry_url, outpoint: outpoint, claim_id: vCLAIMID, "auth_token": m.top.authToken}
            reqHeaders = {}
        end if
        fileViewRequest = getURLEncoded(reqData, fileViewURL, reqHeaders)
    end if
    vLength = resolveRequestOutput["result"][resolveRequestOutput["result"].Keys()[0]]["value"]["video"]["duration"]
    vresolvedRedirectURL = resolveRedirect(vurl.EncodeUri())
    vresSplit = vresolvedRedirectURL.split("/")
    vresDone = []
    for each suburl in vresSplit
        if suburl <> ""
            if suburl.instr("http:") > -1 and suburl.split("").Count() = 5 or suburl.instr("https:") > -1 and suburl.split("").Count() = 6
                vresDone.push(suburl + "/") 'single slash since we'll be joining with /
            else
                replaced = suburl.EncodeUriComponent()
                vResDone.push(replaced)
                replaced = invalid
            end if
        end if
    end for
    vresolvedRedirectURL = vresDone.join("/")
    ?vresolvedRedirectURL
    vresolvedRedirect = vresolvedRedirectURL.split(".")
    vresolvedRedirectLen = vresolvedRedirect.Count()
    if vresolvedRedirect[vresolvedRedirectLen - 1] = "m3u8"
        vtype = "hls"
        vplayerrawsplit = vresolvedRedirect[0].split("/")
        vplayer = vplayerrawsplit[vplayerrawsplit.Count() - 1]
    else
        vtype = "mp4"
        vplayer = "use-p1" 'default to use-p1 since cdn.lbryplayer.xyz is use-p1
    end if
    if m.global.constants.enableStatistics
        m.top.error = false
        return { videourl: vresolvedRedirectURL, videotype: vtype, playtype: "normal", title: m.top.title, length: vLength, player: vPlayer, unresolvedURL: m.top.url } 'returns video+statdata
    else
        m.top.error = false
        return { videourl: vresolvedRedirectURL, videotype: vtype, playtype: "normal", title: m.top.title, length: vLength } 'stat data is not needed for playback w/o statistics
    end if
end function