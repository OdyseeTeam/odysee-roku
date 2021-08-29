Sub Init()
    m.top.functionName = "master"
End Sub

sub master()
    '? m.top.constants
    '? m.top.cookies
    '? m.top.uid
    '? m.top.authtoken
    '? m.top.channel
    '? m.top.channelName
    '? m.top.streamClaim
    m.top.output = getChatHistory(m.top.channel, m.top.channelName, m.top.streamClaim)
End Sub

Function getChatHistory(channel, channelName, streamClaim)
    'queryOutput = "placeholder"
    'date = CreateObject("roDateTime")
    'max = 48
    'queryURL = m.top.constants["QUERY_API"]+"/api/v1/proxy?m=claim_search"
    'queryJSON = FormatJson({"jsonrpc":"2.0","method":"claim_search","params":{"page_size":max,"claim_type":"stream","media_types":["video/mp4"],"no_totals":true,"any_tags":[],"not_tags":["porn","porno","nsfw","mature","xxx","sex","creampie","blowjob","handjob","vagina","boobs","big boobs","big dick","pussy","cumshot","anal","hard fucking","ass","fuck","hentai"],"channel_ids":channels,"not_channel_ids":[],"order_by":["release_time"],"has_no_source":false,"include_purchase_receipt":false, "has_channel_signature":true,"valid_channel_signature":true, "has_source": true},"id":m.top.uid})
    'response = postJSON(queryJSON, queryURL, invalid)
    'if IsValid(response.error)
    '    STOP
    'end if


    'get superchat
    queryURL = m.top.constants["COMMENT_API"]+"?m=comment.SuperChatList"
    queryJSON = FormatJson({"jsonrpc":"2.0","id":1,"method":"comment.List","params":{"page":1,"claim_id":streamClaim,"page_size":75,"top_level":true,"channel_id":channel,"channel_name":channelName,"sort_by":0}})
    superchatResponse = postJSON(queryJSON, queryURL, invalid)
    if IsValid(superchatResponse.error)
        STOP
    end if
    ? channel
    ? streamClaim

    'used in both superchat+chat
    chatRegex = CreateObject("roRegex", "[^\x00-\x7F]","")

    'parse superchat
    superChatArray = []
    superChatLength = 0
    try
        for each superchat in superchatResponse.result.items
            try
                if chatRegex.Replace(superchat["comment"].Trim(), "") <> ""
                    if superchat["support_amount"] > 0
                        superChatArray.push("["+chatRegex.Replace(superchat["channel_name"].Replace("@","")+"]: "+superchat["comment"].replace("\n", " ").Trim(),""))
                        superChatLength += 1
                        if superChatLength > 5
                            superchat = invalid
                            exit for
                        end if
                    end if
                end if
                superchat = invalid
            catch e
                ? "getChatHistory Error (superchat):"
                ? e
            end try
        end for
    catch e
        ? "getChatHistory Error (superchat):"
        ? e
    end try
    ' free memory
    superChatLength = invalid
    queryURL = invalid
    queryJSON = invalid
    chatArray = []
    'get chat
    chatlength = 0
    queryURL = m.top.constants["COMMENT_API"]+"?m=comment.List"
    queryJSON = FormatJson({"jsonrpc":"2.0","id":1,"method":"comment.List","params":{"page":1,"claim_id":streamClaim,"page_size":75,"top_level":true,"channel_id":channel,"channel_name":channelName,"sort_by":0}})
    chatResponse = postJSON(queryJSON, queryURL, invalid)
    if IsValid(chatResponse.error)
        STOP
    end if
    'parse chat
    try
    for each comment in chatResponse.result.items
        try
        if chatRegex.Replace(comment["comment"].Trim(), "") <> ""
            chatArray.push("["+chatRegex.Replace(comment["channel_name"].Replace("@","")+"]: "+comment["comment"], ""))
            chatLength += 1
            if chatLength > 20
                comment = invalid
                exit for
            end if
        end if
        comment = invalid
        catch e
            ? "getChatHistory error (chat):"
            ? e
        end try
    end for
    catch e
        ? "getChatHistory error (chat):"
        ? e
    end try
    'free memory
    chatlength = invalid
    queryURL = invalid
    queryJSON = invalid
    chatResponse = invalid
    chatRegex = invalid
    'reverse chat messages (wrong order)
    chatArray.Reverse()
    return {superChat: superChatArray, chat: chatArray}
End Function