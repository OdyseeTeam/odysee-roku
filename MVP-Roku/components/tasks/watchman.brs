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
    resolveRequestJSON = FormatJson({"jsonrpc":"2.0","method":"get","params":{"uri":lbry_url,"save_file":false},"id":m.top.uid})
    resolveRequestURL = m.top.constants["QUERY_API"]+"/api/v1/proxy?m=get"
    resolveRequestOutput = postJSON(resolveRequestJSON,resolveRequestURL,invalid)
    vurl = resolveRequestOutput["result"]["streaming_url"]
    vresolvedRedirectURL = resolveRedirect(vurl)
    vresolvedRedirect = vresolvedRedirectURL.split(".")
    vresolvedRedirectLen = vresolvedRedirect.Count()
    if vresolvedRedirect[vresolvedRedirectLen-1] = "m3u8"
        vtype = "hls"
    else
        vtype = "mp4"
    end if
    return {videourl: vresolvedRedirectURL, videotype: vtype, playtype: "normal", title: m.top.title} 'Returns the array
End Function