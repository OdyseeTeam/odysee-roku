Sub Init()
    m.top.functionName = "master"
End Sub

sub master()
    '? m.top.constants
    '? m.top.cookies
    '? m.top.uid
    '? m.top.authtoken
    '? m.top.channels
    '? m.top.rawname
    m.top.output = resolve(m.top.url)
End Sub

Function resolve(lbry_url)
    'get base URL
    getRequestJSON = FormatJson({"jsonrpc":"2.0","method":"get","params":{"uri":lbry_url,"save_file":false},"id":m.top.uid})
    getRequestURL = m.top.constants["QUERY_API"]+"/api/v1/proxy?m=get"
    getRequestOutput = postJSON(getRequestJSON,getRequestURL,invalid)
    vurl = getRequestOutput["result"]["streaming_url"]

    if m.global.constants.enableStatistics
        'get video length (needed for meta)
        resolveRequestJSON = FormatJson({"jsonrpc":"2.0","method":"resolve","params":{"urls":[lbry_url],"include_purchase_receipt":false,"include_is_my_output":false},"id":m.top.uid})
        resolveRequestURL = m.top.constants["QUERY_API"]+"/api/v1/proxy?m=resolve"
        resolveRequestOutput = postJSON(resolveRequestJSON,resolveRequestURL,invalid)
        vLength = resolveRequestOutput["result"][resolveRequestOutput["result"].Keys()[0]]["value"]["video"]["duration"]
    end if

    vresolvedRedirectURL = resolveRedirect(vurl)
    ? vresolvedRedirectURL
    vresolvedRedirect = vresolvedRedirectURL.split(".")
    vresolvedRedirectLen = vresolvedRedirect.Count()
    if vresolvedRedirect[vresolvedRedirectLen-1] = "m3u8"
        vtype = "hls"
        vplayerrawsplit = vresolvedRedirect[0].split("/")
        vplayer = vplayerrawsplit[vplayerrawsplit.Count()-1]
    else
        vtype = "mp4"
        vplayer = "use-p1" 'default to use-p1 since cdn.lbryplayer.xyz is use-p1
    end if
    if m.global.constants.enableStatistics
        return {videourl: vresolvedRedirectURL, videotype: vtype, playtype: "normal", title: m.top.title, length: vLength, player: vPlayer, unresolvedURL: m.top.url} 'returns video+statdata
    else
        return {videourl: vresolvedRedirectURL, videotype: vtype, playtype: "normal", title: m.top.title} 'stat data is not needed for playback w/o statistics
    end if
End Function