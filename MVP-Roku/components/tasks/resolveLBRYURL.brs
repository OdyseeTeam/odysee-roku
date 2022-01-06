sub Init()
    m.top.functionName = "master"
end sub

sub master()
    '' ?m.top.constants
    '' ?m.top.cookies
    '' ?m.top.uid
    '' ?m.top.authtoken
    '' ?m.top.channels
    '' ?m.top.rawname
    m.top.output = resolve(m.top.url)
end sub

function resolve(lbry_url)
    try
        'get base URL
        ' ?lbry_url
        try
            'Preferred: Single Claim Search Method
            spliturl = lbry_url.split("#")
            friendlyname = spliturl[0].split("/")[2]
            claimid = spliturl[1]
            ' ?spliturl
            ' ?friendlyname
            ' ?claimid
            resQuery = postJSON(FormatJson({ "method": "claim_search", "params": { "claim_ids": [claimid], "has_source": true, "has_no_source": false, "page_size": 1, "no_totals": true, "include_purchase_receipt": false, "include_is_my_output": false } }), m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search", invalid)
            sdHash = resQuery["result"]["items"][0]["value"]["source"]["sd_hash"]
            vurl = resolveRedirect(m.top.constants["VIDEO_API"] + "/api/v4/streams/free/" + friendlyname + "/" + claimid + "/" + Left(sdHash, 6))
            if m.global.constants.enableStatistics
                vLength = resQuery["result"]["items"][0]["value"]["video"]["duration"]
            end if
            vresolvedRedirect = vurl.split(".")
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
                return { videourl: vurl, videotype: vtype, playtype: "normal", title: m.top.title, length: vLength, player: vPlayer, unresolvedURL: m.top.url } 'returns video+statdata
            else
                m.top.error = false
                return { videourl: vurl, videotype: vtype, playtype: "normal", title: m.top.title } 'stat data is not needed for playback w/o statistics
            end if
        catch e
            'Slower: Site Method
            ' ?"Attempting secondary resolution method (slower!)"
            getRequestJSON = FormatJson({ "jsonrpc": "2.0", "method": "get", "params": { "uri": lbry_url, "save_file": false } })
            getRequestURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=get"
            getRequestOutput = postJSON(getRequestJSON, getRequestURL, invalid)
            vurl = getRequestOutput["result"]["streaming_url"]
            if m.global.constants.enableStatistics
                'get video length (needed for meta)
                resolveRequestJSON = FormatJson({ "jsonrpc": "2.0", "method": "resolve", "params": { "urls": [lbry_url], "include_purchase_receipt": false, "include_is_my_output": false } })
                resolveRequestURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=resolve"
                resolveRequestOutput = postJSON(resolveRequestJSON, resolveRequestURL, invalid)
                vLength = resolveRequestOutput["result"][resolveRequestOutput["result"].Keys()[0]]["value"]["video"]["duration"]
            end if

            vresolvedRedirectURL = resolveRedirect(vurl)
            ' ?vresolvedRedirectURL
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
                return { videourl: vresolvedRedirectURL, videotype: vtype, playtype: "normal", title: m.top.title } 'stat data is not needed for playback w/o statistics
            end if
        end try
    catch e
        m.top.error = true
        return { error: true }
    end try
end function