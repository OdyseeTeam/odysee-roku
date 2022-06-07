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
    'try
        'get base URL
        ?lbry_url
        spliturl = lbry_url.split("#")
        friendlyname = spliturl[0].split("/")[2]
        return siteMethod(lbry_url)
    'catch e
    '    m.top.error = true
    '    return { error: true }
    'end try
end function

function siteMethod(lbry_url)
    ?"Attempting secondary resolution method (slower!)"
    getRequestJSON = FormatJson({ "jsonrpc": "2.0", "method": "get", "params": { "uri": lbry_url, "save_file": false } })
    getRequestURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=get"
    getRequestOutput = postJSON(getRequestJSON, getRequestURL, invalid)
    vurl = getRequestOutput["result"]["streaming_url"]

    'Video length is needed for more than just metadata, since our custom UI uses it as well.
    'Disabling statistics still disables sending it.
    resolveRequestJSON = FormatJson({ "jsonrpc": "2.0", "method": "resolve", "params": { "urls": [lbry_url], "include_purchase_receipt": false, "include_is_my_output": false } })
    resolveRequestURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=resolve"
    resolveRequestOutput = postJSON(resolveRequestJSON, resolveRequestURL, invalid)
    vLength = resolveRequestOutput["result"][resolveRequestOutput["result"].Keys()[0]]["value"]["video"]["duration"]
    vresolvedRedirectURL = resolveRedirect(vurl.EncodeUri())
    vregex = CreateObject("roRegex", "[^a-zA-Z0-9\-\.\,\s]", "")
    vresSplit = vresolvedRedirectURL.split("/")
    vresDone = []
    for each suburl in vresSplit
        if suburl <> ""
            if Instr(0, suburl, "http:") > -1 AND suburl.split("").Count() = 5 OR Instr(0, suburl, "https:") > -1 AND suburl.split("").Count() = 6
                vresDone.push(suburl+"/") 'single slash since we'll be joining with /
            else
                replaced = vregex.ReplaceAll(suburl, "")
                if replaced = ""
                    replaced = "roku"
                end if
                vResDone.push(replaced)
                replaced = invalid
            end if
        end if
    end for
    vregex = invalid
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