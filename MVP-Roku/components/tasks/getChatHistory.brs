Sub Init()
    m.top.functionName = "master"
End Sub

sub master()
    '' ?m.top.constants
    '' ?m.top.cookies
    '' ?m.top.uid
    '' ?m.top.authtoken
    '' ?m.top.channel
    '' ?m.top.channelName
    '' ?m.top.streamClaim
    m.top.output = getChatHistory(m.top.channel, m.top.channelName, m.top.streamClaim)
End Sub

Function getChatHistory(channel, channelName, streamClaim)
    'get superchat
    queryURL = m.top.constants["COMMENT_API"]+"?m=comment.SuperChatList"
    queryJSON = FormatJson({"jsonrpc":"2.0","id":1,"method":"comment.List","params":{"page":1,"claim_id":streamClaim,"page_size":75,"top_level":true,"channel_id":channel,"channel_name":channelName,"sort_by":0}})
    superchatResponse = postJSON(queryJSON, queryURL, invalid)
    retries = 0
    while true
        if IsValid(superchatResponse.error)
            superchatResponse = postJSON(queryJSON, queryURL, invalid)
            retries+=1
        else
            exit while
        end if
        if retries > 5
            return {superChat: [], chat: []}
        end if
    end while

    ' ?channel
    ' ?streamClaim

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
                        if superChatLength > 4
                            superchat = invalid
                            exit for
                        end if
                        superChatArray.push("["+chatRegex.Replace(superchat["channel_name"].Replace("@","")+"]: "+superchat["comment"].replace("\n", " ").Trim(),""))
                        superChatLength += 1
                    end if
                end if
                superchat = invalid
            catch e
                ' ?"getChatHistory Error (superchat):"
                ' ?e
            end try
        end for
    catch e
        ' ?"getChatHistory Error (superchat):"
        ' ?e
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
    retries = 0
    while true
        if IsValid(chatResponse.error)
            chatResponse = postJSON(queryJSON, queryURL, invalid)
            retries+=1
        else
            exit while
        end if
        if retries > 5
            return {superChat: [], chat: []}
        end if
    end while
    'parse chat
    try
    for each comment in chatResponse.result.items
        try
        if chatRegex.Replace(comment["comment"].Trim(), "") <> ""
            if chatLength > 19
                comment = invalid
                exit for
            end if
            chatArray.push("["+chatRegex.Replace(comment["channel_name"].Replace("@","")+"]: "+comment["comment"], ""))
            chatLength += 1
        end if
        comment = invalid
        catch e
            ' ?"getChatHistory error (chat):"
            ' ?e
        end try
    end for
    catch e
        ' ?"getChatHistory error (chat):"
        ' ?e
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