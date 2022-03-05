' WebSocketClientTask.brs
' Copyright (C) 2018 Rolando Islas
' Released under the MIT license
'
' BrightScript, SceneGraph Task wrapper for the web socket client

' Entry point
function init() as void
    ' Task init

    'hey wait why for each check all channel IDs on every chat message when we can do this hacky assocArray thing?
    'just addRemove all the IDs from m.blocked and then check if the incoming ID is valid in the array.
    m.blocked = {}
    if isValid(m.top.blocked)
        for each blockedUser in m.top.blocked
            m.blocked.addReplace(blockedUser, true) 'bool in theroy takes the least memory space.
        end for
    end if
    m.top.functionName = "runtask"
    m.top.control = "RUN"
end function

' Main task loop
function runtask() as void
    m.parseTimer = CreateObject("roTimespan")
    m.parseTimer.Mark()
    m.fontReg = CreateObject("roFontRegistry")
    m.fontReg.Register("pkg://components/generic/fonts/Inter-Emoji.otf")
    m.chatRegex = CreateObject("roRegex", "[^\x00-\x7F]", "")
    m.totalMesgHeight = 0
    m.comments = []
    m.messageHeights = []
    if isValid(m.top.superChat) AND isValid(m.superChatArray) = false
        if m.top.superChat.Count() > 0
            m.superChatArray = m.top.superChatArray
        else if isValid(m.superChatArray) = false
            m.superChatArray = []
        end if
    else if isValid(m.superChatArray) = false
        m.superChatArray = []
    end if
    m.commentsContentNode = CreateObject("roSGNode", "ContentNode")
    m.ws = WebSocketClient()
    m.port = createObject("roMessagePort")
    m.ws.set_message_port(m.port)
    ' Fields
    m.top.STATE_CONNECTING = m.ws.STATE.CONNECTING
    m.top.STATE_OPEN = m.ws.STATE.OPEN
    m.top.STATE_CLOSING = m.ws.STATE.CLOSING
    m.top.STATE_CLOSED = m.ws.STATE.CLOSED
    m.top.ready_state = m.ws.get_ready_state()
    m.top.protocols = m.ws.get_protocols()
    m.top.headers = m.ws.get_headers()
    m.top.buffer_size = m.ws.get_buffer_size()
    ' Event listeners
    m.top.observeField("open", m.port)
    m.top.observeField("send", m.port)
    m.top.observeField("close", m.port)
    m.top.observeField("buffer_size", m.port)
    m.top.observeField("protocols", m.port)
    m.top.observeField("headers", m.port)

    if len(m.top.open) > 0
        m.ws.open(m.top.open)
    end if

    while true
        ' Check task messages
        msg = wait(1, m.port)
        ' Field event
        if type(msg) = "roSGNodeEvent"
            if msg.getField() = "open"
                m.ws.open(msg.getData())
            else if msg.getField() = "send"
                m.ws.send(msg.getData())
            else if msg.getField() = "close"
                m.ws.close(msg.getData())
            else if msg.getField() = "buffer_size"
                m.ws.set_buffer_size(msg.getData())
            else if msg.getField() = "protocols"
                m.ws.set_protocols(msg.getData())
            else if msg.getField() = "headers"
                m.ws.set_headers(msg.getData())
            else if msg.getField() = "thumbnailCache"
                m.top.thumbnailCache = msg.getData()
            else if msg.getField() = "m.messageHeights"
                m.top.messageHeights = msg.getData()
            end if
            ' WebSocket event
        else if type(msg) = "roAssociativeArray"
            if msg.id = "on_open"
                m.top.on_open = msg.data
            else if msg.id = "on_close"
                m.top.on_close = msg.data
            else if msg.id = "on_message"
                m.top.on_message = msg.data
                message = msg.data
                'Bake parsing into WebSocketClient.
                ' ? "GOT MESSAGE, TYPE:"
                ' ? type(message)
                if type(message) = "roAssociativeArray"
                    m.parseTimer.Mark()
                    if isValid(message.message)
                        message = ParseJson(message.message)
                        if message.type = "delta"
                            ' ? "GOT DELTA MESSAGE!"
                            if isValid(message.data)
                                if isValid(message.data.comment)
                                    ' ? "Seems to be a comment"
                                    'THE CURRENT ISSUE:
                                    'Comments come in too fast to process.
                                    '
                                    curComment = message.data.comment
                                    for each height in m.top.messageHeights
                                        m.totalMesgHeight += height + 5
                                    end for
                                    'We don't need any fancy transformation, this is in SEQUENTIAL ORDER!
                                    trimmedComment = curcomment.comment.Trim()
                                    if curcomment["is_pinned"] = false and curcomment["is_hidden"] = false and m.chatRegex.Replace(trimmedComment, "") <> "" and trimmedComment.instr("![") = -1 and trimmedComment.instr("](") = -1 and isValid(m.blocked[curComment["channel_id"]]) = false
                                        ' ? "passed checks"
                                        commentHeight = getMessageHeight(curcomment.comment, 30, 420)
                                        currentComments = m.top.on_chat.comments.getChildren(-1, 0)
                                        totalHeight = 0
                                        needToRemove = 0
                                        removalHeight = 0
                                        messageHeights = m.top.messageHeights
                                        for each comment in currentComments
                                            totalHeight += comment.height
                                        end for
                                        if totalHeight + commentHeight > m.top.allowedHeight
                                            for each comment in currentComments
                                                if ((totalHeight + commentHeight) - removalHeight) < m.top.allowedHeight
                                                    exit for
                                                end if
                                                needToRemove += 1
                                                removalHeight += comment.height
                                            end for
                                        end if
                                        ' ? FormatJson(curcomment)
                                        if isValid(curComment["is_fiat"]) and isValid(curComment["support_amount"])
                                            if curcomment["is_fiat"] = true or curcomment["support_amount"] > 0 or isValid(m.top.thumbnailCache[curComment.channel_id]) 'if they have just donated, add them to the cache.
                                                isPremium = true
                                                ' ? "Is premium"
                                                if m.superChatArray.Count() < 5
                                                    m.superChatArray.Unshift("[" + m.chatRegex.Replace(curComment["channel_name"] + "]: " + curComment["comment"].replace("\n", " ").Trim(), ""))
                                                else
                                                    m.superChatArray.Pop()
                                                    m.superChatArray.Unshift("[" + m.chatRegex.Replace(curComment["channel_name"] + "]: " + curComment["comment"].replace("\n", " ").Trim(), ""))
                                                end if
                                            else
                                                if isValid(curcomment["is_moderator"]) = true 'if they are a moderator, add them to the cache.
                                                    isPremium = true
                                                else
                                                    isPremium = false
                                                end if
                                                ' ? "NOT premium"
                                            end if
                                        end if
                                        if needToRemove > 0
                                            for i = 1 to needToRemove step 1
                                                messageHeights.Shift()
                                            end for
                                            m.top.on_chat.comments.removeChildrenIndex(needToRemove, 0)
                                            m.top.on_chat.comments.appendChild(legacyParseComment(curcomment, commentHeight, isPremium))
                                            messageHeights.push(commentHeight)
                                            pastHeights = m.top.messageHeights
                                            m.top.messageHeights = messageHeights
                                        else
                                            m.top.on_chat.comments.appendChild(legacyParseComment(curcomment, commentHeight, isPremium))
                                            messageHeights.push(commentHeight)
                                            pastHeights = m.top.messageHeights
                                            m.top.messageHeights = messageHeights
                                        end if
                                        m.top.superChat = m.superChatArray
                                        ? "WSC: Parsing Chat Took " + (m.parseTimer.TotalMilliseconds() / 1000).ToStr() + "s"
                                    end if
                                end if
                            end if
                        else if message.type = "removed"
                            m.parseTimer.Mark()
                            messageHeights = m.top.messageHeights
                            cid = 0
                            for each comment in m.top.on_chat.comments.getChildren(-1, 0) 'This is a rare case where we need to interact with m.top DIRECTLY.
                                if comment.comment_id = message.data.comment.comment_id
                                    m.top.on_chat.comments.removeChild(comment)
                                    messageHeights.Delete(cid)
                                    exit for
                                end if
                                cid += 1
                            end for
                            cid = invalid
                            ? "WSC: Removing message took " + (m.parseTimer.TotalMilliseconds() / 1000).ToStr() + "s"
                        else if message.type = "viewers"
                            ' ? "GOT VIEWERS MESSAGE!"
                            if isValid(message.data)
                                if isValid(message.data.connected)
                                    m.top.currentViewers = message.data.connected
                                    ' ? str(m.top.currentViewers) + " Watching"
                                end if
                            end if
                        else
                            ' ? message.type
                        end if
                    end if
                end if
            else if msg.id = "on_error"
                m.top.on_error = msg.data
            else if msg.id = "ready_state"
                m.top.ready_state = msg.data
            else if msg.id = "buffer_size"
                m.top.unobserveField("buffer_size")
                m.top.buffer_size = msg.data
                m.top.observeField("buffer_size", m.task_port)
            else if msg.id = "protocols"
                m.top.unobserveField("protocols")
                m.top.protocols = msg.data
                m.top.observeField("protocols", m.task_port)
            else if msg.id = "headers"
                m.top.unobserveField("headers")
                m.top.headers = msg.data
                m.top.observeField("headers", m.task_port)
            end if
        end if
        m.ws.run()
    end while
end function

function commentToSGNode(comment)
    ' ? "parsing a comment"
    newComment = CreateObject("roSGNode", "chatdata")
    newComment.message = comment.message
    newComment.height = comment.height
    newComment.username = comment.username
    newComment.usericon = comment.usericon
    return newComment 'return it instead, we want to set them all at once around the same time.
end function

function legacyParseComment(comment, height, isPremium = false)
    ' ? "parsing a comment"
    newComment = CreateObject("roSGNode", "chatdata")
    'Note that each comment is actually based on chatdata.xml, this is because we are feeding it directly into m.chatBox
    newComment.message = m.chatRegex.Replace(comment.comment, "")
    newComment.height = height
    newComment.username = m.chatRegex.Replace(comment["channel_name"], "")
    newComment.comment_id = comment["comment_id"]
    if newComment.username.split("").Count() < 1
        newComment.username = "Anonymous"
    end if
    if isPremium
        if isValid(m.top.thumbnailCache[comment.channel_id])
            newComment.usericon = m.top.thumbnailCache[comment.channel_id]
        else
            m.top.thumbnailCache.Append(getThumbnail(comment["channel_id"]))
            newComment.usericon = m.top.thumbnailCache[comment.channel_id]
        end if
    else
        newComment.usericon = "none"
    end if
    return newComment 'return it instead, we want to set them all at once around the same time.
end function

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
            channelCache[channelIdentifier] = m.top.constants["THUMBNAIL_PROCESSOR"] + currentChannel.value.thumbnail.url
        catch e
            channelCache.addReplace(channelIdentifier, "https://player.odycdn.com/speech/spaceman-png:2.png")
        end try
    end if
    return channelCache
end function

function getMessageHeight(inputText, fontSize, maxfontWidth)
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
    ' ? calcWidth
    ' ? numLines
    return (font.GetOneLineHeight() * numLines) + 70
end function