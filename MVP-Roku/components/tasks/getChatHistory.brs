sub Init()
    m.top.functionName = "master"
end sub

sub master()
    '<!--
    'Planned to cache associated information of channels, AKA:
    '- Channel Name
    '- Channel Thumbnail URL
    '
    'This is so that we only resolve channels ONCE, after that we hit the resolveCache.
    '-->
    '<field id="chatCIDS" type="roArray"/>
    '<field id="resolveCache" type="assocArray"/>
    '<field id="fontPath" type="String"/>
    '<field id="fontSize" type="Int"/>
    '<field id="input" type="String"/>
    '<field id="fontWidth" type="Int"/>
    '<field id="maxFontWidth" type="Int"/>
    '<field id="output" type="assocArray"/>

    'A single message in the message Array holds:
    ' message
    ' height of message
    ' username of sender
    ' thumbnail of sender

    ' Our input data is:
    ' channel ID
    ' channel name
    ' channel URL

    'used in both superchat+chat
    ? "getChatHistory: Getting chat history"
    m.fontReg = CreateObject("roFontRegistry")
    m.fontReg.Register("pkg://components/generic/fonts/Inter-Emoji.otf")
    m.timer = CreateObject("roTimespan")
    m.htimer = CreateObject("roTimespan")
    m.htimer.Mark()
    m.timer.Mark()
    m.chatRegex = CreateObject("roRegex", "[^\x00-\x7F]", "")
    m.comments = CreateObject("roSGNode", "ContentNode")
    m.commentsArray = []
    m.thumbnailCache = {}
    m.channelName = ""
    if m.top.streamClaim <> "none"
        m.top.output = getChat(m.top.channel, m.top.streamClaim)
    else
        m.top.output = getChat(m.top.channel)
    end if
end sub

function resolveStreamID(channel)
    try
        lsqueryURL = "https://api.odysee.live/livestream/is_live?channel_claim_id=" + channel
        livestreamClaimQuery = getJSON(lsqueryURL)
        retries = 0
        while true
            if isValid(livestreamClaimQuery.data)
                if IsValid(livestreamClaimQuery.data.ActiveClaim) and IsValid(livestreamClaimQuery.data.live)
                    if isValid(livestreamClaimQuery.data.ActiveClaim.ClaimID) and livestreamClaimQuery.data.live
                        exit while
                    end if
                else
                    livestreamClaimQuery = getJSON(lsqueryURL)
                    retries += 1
                end if
            end if
            if retries > 5
                return false
            end if
        end while
        return livestreamClaimQuery.data.ActiveClaim.ClaimID
    catch e
        return false
    end try
end function

function isLivestreaming(channel)
    try
        lsqueryURL = "https://api.odysee.live/livestream/is_live?channel_claim_id=" + channel
        livestreamClaimQuery = getJSON(lsqueryURL)
        retries = 0
        while true
            if isValid(livestreamClaimQuery.data)
                if IsValid(livestreamClaimQuery.data.ActiveClaim) and IsValid(livestreamClaimQuery.data.live)
                    if isValid(livestreamClaimQuery.data.ActiveClaim.ClaimID) and livestreamClaimQuery.data.live
                        exit while
                    end if
                else
                    livestreamClaimQuery = getJSON(lsqueryURL)
                    retries += 1
                end if
            end if
            if retries > 5
                return false
            end if
        end while
        if livestreamClaimQuery.data.live = true
            return true
        else
            return false
        end if
    catch e
        return false
    end try
end function

function getChat(channelID, streamClaim)
    if m.top.streamClaim = "none" 'fallback to internal resolution if legacy fails
        streamClaim = resolveStreamID(channelID)
    end if
    'streamClaim = "2fe87e0e67a179ee7776286776c316b5df80541d"
    'Before anything begins: Add livestream owner to the Thumbnail Cache.
    resolvedThumb = getThumbnail(channelID)
    m.thumbnailCache.Append(resolvedThumb)
    resolvedThumb = invalid
    'get chat
    'streamClaim = resolveStreamID(channelID)
    m.chatLength = 0
    commentURL = m.top.constants["COMMENT_API"] + "?m=comment.List"
    commentJSON = FormatJson({ "jsonrpc": "2.0", "id": 1, "method": "comment.List", "params": { "page": 1, "claim_id": streamClaim, "page_size": 70, "top_level": true, "channel_id": channelid, "sort_by": 0 } })
    chatResponse = postJSON(commentJSON, commentURL, invalid)
    m.retries = 0
    channelAssocArray = {}

    superChatURL = m.top.constants["COMMENT_API"] + "?m=comment.SuperChatList"
    superChatJSON = FormatJson({ "jsonrpc": "2.0", "id": 1, "method": "comment.List", "params": { "page": 1, "claim_id": streamClaim, "page_size": 70, "top_level": true, "channel_id": channelid, "sort_by": 0 } })
    superchatResponse = postJSON(superChatJSON, superChatURL, invalid)
    retries = 0
    while true
        if IsValid(chatResponse.error)
            chatResponse = postJSON(commentJSON, commentURL, invalid)
            retries += 1
        else
            exit while
        end if
        if retries > 5
            return { superChat: [], chat: [] }
        end if
    end while
    retries = 0
    while true
        if IsValid(superchatResponse.error)
            superchatResponse = postJSON(superChatJSON, superChatURL, invalid)
            retries += 1
        else
            exit while
        end if
        if retries > 5
            return { superChat: [], chat: [] }
        end if
    end while
    retries = 0

    m.superChatArray = []
    superChatLength = 0
    try
        for each superchat in superchatResponse.result.items
            try
                if m.chatRegex.Replace(superchat["comment"].Trim(), "") <> "" and superchat["comment"].Trim().instr("![") = -1 and superchat["comment"].Trim().instr("](") = -1
                        if superChatLength > 4
                            superchat = invalid
                            exit for
                        end if
                        m.superChatArray.Unshift("[" + m.chatRegex.Replace(superchat["channel_name"] + "]: " + superchat["comment"].replace("\n", " ").Trim(), ""))
                        resolvedThumb = getThumbnail(superchat.channel_id)
                       ' ? "pushing to thumbnail cache ID:"
                       ' ? superchat.channel_id
                        if isValid(resolvedThumb)
                            m.thumbnailCache.Append(resolvedThumb)
                        else
                            m.thumbnailCache.addReplace(superchat.channel_id, "https://player.odycdn.com/speech/spaceman-png:2.png")
                        end if
                        superChatLength += 1
                    end if
                superchat = invalid
            catch e
                ?"getChatHistory Error (superchat):"
                ?formatJson(e)
            end try
        end for
    catch e
        ?"getChatHistory Error (superchat):"
        ?formatJson(e)
    end try

    chatchannelurls = []

    for each comment in chatResponse.result.items 'Channel URLs may change during chat, but not channel claim IDs.
        channelAssocArray.addReplace(comment.channel_id, comment.channel_url)
    end for

    for each comment in superChatResponse.result.items 'Channel URLs may change during chat, but not channel claim IDs.
        channelAssocArray.addReplace(comment.channel_id, comment.channel_url)
    end for
    for each channel in channelAssocArray.Keys()
        chatchannelurls.push(channelAssocArray[channel])
    end for

    channelAssocArray = invalid
    'only done for users that have donated, the livestream creator, or moderators, but uncomment below if you want to do it for everyone, but performance will suffer as a result.
    'm.top.thumbnailCache = getThumbnails(chatchannelurls) 'start resolve cache for thumbnails.
    'time to generate our chat array.
    'A single message in the message Array holds:
    ' message
    ' height of message
    ' username of sender
    ' thumbnail of sender
    comments = CreateObject("roSGNode", "ContentNode")
    messageHeights = []
    totalMesgHeight = 0
    chatResponse.result.items.Reverse()
    'STOP
    for i = chatResponse.result.items.Count() - 1 to 0 step -1
        '970px is the max height, we don't need any more messages after.
        curcomment = chatResponse.result.items[i]
        if curcomment["is_pinned"] = false and curcomment["is_hidden"] = false and m.chatRegex.Replace(curcomment.comment.Trim(), "") <> "" and curcomment.comment.Trim().instr("![") = -1 and curcomment.comment.Trim().instr("](") = -1
            if totalMesgHeight < m.top.allowedHeight
                commentHeight = getMessageHeight(curcomment.comment, 30, 420) 'Resolve height to check if we should include the message (saves more time)
                if totalMesgHeight + commentHeight + 5 < m.top.allowedHeight
                    messageHeights.Unshift(commentHeight)
                    parseComment(curcomment, commentHeight)
                    totalMesgHeight += commentHeight + 5
                else
                    if totalMesgHeight + commentHeight < m.top.allowedHeight
                        messageHeights.Unshift(commentHeight)
                        parseComment(curcomment, commentHeight)
                        totalMesgHeight += commentHeight
                    end if
                    exit for
                end if
            end if
        end if
    end for
    m.top.messageHeights = messageHeights
    m.top.thumbnailCache = m.thumbnailCache
    m.comments.appendChildren(m.commentsArray)
  '  ? "getChatHistory: Task took " + (m.timer.TotalMilliseconds() / 1000).ToStr() + "s"
    m.top.superChat = m.superChatArray
    return { comments: m.comments, superchat: m.superChatArray }
end function

sub parseComment(comment, height)
    newComment = CreateObject("roSGNode", "chatdata")
    'Note that each comment is actually based on chatdata.xml, this is because we are feeding it directly into m.chatBox
    newComment.message = m.chatRegex.Replace(comment.comment, "")
    newComment.height = height
    newComment.username = m.chatRegex.Replace(comment["channel_name"], "")
    newComment.comment_id = comment["comment_id"]
    if newComment.username.split("").Count() < 1
        newComment.username = "Anonymous"
    end if
    if isValid(m.thumbnailCache[comment.channel_id])
        newComment.usericon = m.thumbnailCache[comment.channel_id]
    else if comment.channel_id = m.top.channelID
        resolvedThumb = getThumbnail(comment.channel_id)
        m.thumbnailCache.Append(resolvedThumb)
        newComment.usericon = m.thumbnailCache[comment.channel_id]
    else
        newComment.usericon = "none"
    end if
    m.commentsArray.unshift(newComment)
end sub

function getThumbnail(channelIdentifier)
    'apparently I wrote some of this while braindead, so we'll add a method to resolve channels by URL+ClaimID
    channelCache = {}
    if channelIdentifier.instr("lbry") > -1
        cqueryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=resolve"
        cqueryJSON = FormatJson({ "method": "resolve", "params": { "urls": [channelurl], "include_purchase_receipt": false, "include_is_my_output": false, "include_sent_supports": false, "include_sent_tips": false, "include_received_tips": false } })
        channelQuery = postJSON(cqueryJSON, cqueryURL, invalid)
        try
            cKey = channelQuery.result.Keys()[0]
            channelCache.addReplace(channelsQuery.result[ckey].claim_id, m.top.constants["THUMBNAIL_PROCESSOR"] + channelsQuery.result[ckey].value.thumbnail.url)
        catch e
            channelCache.addReplace(channelIdentifier, "https://player.odycdn.com/speech/spaceman-png:2.png")
        end try
    else
        try
            cqueryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
            cqueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page": 1, "page_size": 1, "channel_ids": [channelIdentifier], "claim_type": ["stream"], "no_totals": true, "include_purchase_receipt": false, "include_is_my_output": false, "include_sent_supports": false, "include_sent_tips": false, "include_received_tips": false } })
            channelQuery = postJSON(cqueryJSON, cqueryURL, invalid)
            currentChannel = channelQuery.result.items[0]["signing_channel"]
            channelCache[channelIdentifier] = m.top.constants["THUMBNAIL_PROCESSOR"]+currentChannel.value.thumbnail.url
        catch e
            channelCache.addReplace(channelIdentifier, "https://player.odycdn.com/speech/spaceman-png:2.png")
        end try
    end if
    return channelCache
end function

function getMessageHeight(inputText, fontSize, maxfontWidth)
   ' ? "RUNNING"
    m.htimer.Mark()
    fontFamilies = m.fontReg.GetFamilies()
    font = m.fontReg.GetFont(fontFamilies[0], fontSize + 10, false, false)
    fontWidthCalculated = font.GetOneLineWidth(inputText, 8192)
    numLines = 1 '"Scaling factor" technically.
    calcWidth = fontWidthCalculated
    if fontWidthCalculated > maxfontWidth
        while calcWidth > maxfontWidth
            if calcWidth > maxfontWidth
                numLines += 1
            end if
            calcWidth = fontWidthCalculated / numLines
        end while
    end if
   ' ? inputText
   ' ? calcWidth
   ' ? numLines
   ' ? "getChatHistory: HeightCalc took " + (m.htimer.TotalMilliseconds() / 1000).ToStr() + "s"
    return (font.GetOneLineHeight() * numLines) + 70
end function

function generateChatMessageData(usericon, username, message, oldData = invalid) 'this is here to explain how the chatBox data is generated.
    if isValid(oldData)
        chatData = oldData
    else
        chatData = CreateObject("roSGNode", "ContentNode")
    end if
    dataItem = chatData.CreateChild("chatdata")
    dataItem.username = username
    dataItem.usericon = usericon
    dataItem.message = message
    dataItem.height = getMessageHeight(dataItem.message, 30, 420)
    return chatData
end function