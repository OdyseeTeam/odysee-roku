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
    if isValid(m.top.streamClaim)
        if m.top.streamClaim <> "" and m.top.streamClaim <> "none"
            m.parseTimer = CreateObject("roTimespan")
            m.parseTimer.Mark()
            m.fontReg = CreateObject("roFontRegistry")
            m.fontReg.Register("pkg://components/generic/fonts/Inter-Emoji.otf")
            m.chatRegex = CreateObject("roRegex", "[^\x00-\x7F]", "")
            m.totalMesgHeight = 0
            m.comments = m.top.findNode("chat")
            'Time to get chat history.
            chat = []
            messageHeights = []
            m.thumbnailCache = {}
            totalHeight = 0
            allowedHeight = m.top.allowedHeight+1-1
            commentURL = m.top.constants["COMMENT_API"] + "?m=comment.List"
            commentJSON = FormatJson({ "jsonrpc": "2.0", "id": 1, "method": "comment.List", "params": { "page": 1, "claim_id": m.top.streamClaim, "page_size": 20, "top_level": true, "channel_id": m.top.channelid, "sort_by": 0 } })
            chatResponse = postJSON(commentJSON, commentURL, invalid)
            superChatURL = m.top.constants["COMMENT_API"] + "?m=comment.SuperChatList"
            superChatJSON = FormatJson({ "jsonrpc": "2.0", "id": 1, "method": "comment.List", "params": { "page": 1, "claim_id": m.top.streamClaim, "page_size": 70, "top_level": true, "channel_id": m.top.channelID, "sort_by": 0 } })
            superchatResponse = postJSON(superChatJSON, superChatURL, invalid)
            retries = 0
            while true
                if IsValid(superchatResponse.error)
                    superchatResponse = postJSON(superChatJSON, superChatURL, invalid)
                    retries += 1
                else
                    exit while
                end if
                if retries > 5
                    exit while
                end if
            end while
            retries = 0
            while true
                if IsValid(chatResponse.error)
                    chatResponse = postJSON(commentJSON, commentURL, invalid)
                    retries += 1
                else
                    exit while
                end if
                if retries > 5
                    exit while
                end if
            end while
            retries = 0
            superChatLength = 0
            m.superchat = []
            'try
                for each superchatitem in superchatResponse.result.items
                    'try
                        if m.chatRegex.Replace(superchatitem["comment"].Trim(), "") <> "" and superchatitem["comment"].Trim().instr("![") = -1 and superchatitem["comment"].Trim().instr("](") = -1
                            if superChatLength > 4
                                exit for
                            end if
                            m.superchat.Push("[" + m.chatRegex.Replace(superchatitem["channel_name"] + "]: " + superchatitem["comment"].replace("\n", " ").Trim(), ""))
                            m.thumbnailCache = getThumbnail(superchatitem.channel_url, m.thumbnailCache, superchatitem.channel_id)
                            ' ? "pushing to thumbnail cache ID:"
                            ' ? superchat.channel_id
                            if isValid(resolvedThumb)
                                m.thumbnailCache.Append(resolvedThumb)
                            else
                                m.thumbnailCache.addReplace(superchatitem.channel_id, "https://player.odycdn.com/speech/spaceman-png:2.png")
                            end if
                            superChatLength += 1
                        end if
                    'catch e
                    '    ?"WebSocketClient ChatHistory Error (superchat):"
                    '    ?formatJson(e)
                    'end try
                end for
            'catch e
            '    ?"WebSocketClient ChatHistory Error (superchat):"
            '    ?formatJson(e)
            'end try
            ? m.superchat
            chatResponse.result.items.Reverse()
            for each chatitem in chatResponse.result.items
                parsedComment = parseComment(chatitem)
                messageHeights.push(parsedComment.height)
                m.top.messageHeights = messageHeights
                totalHeight+=parsedComment.height
                m.comments.appendChild(parsedComment)
                m.top.chatChanged = true
            end for
            while totalHeight > allowedHeight
                totalHeight=reCalcTotalHeight(m.comments.getChildren(-1,0))
                if totalHeight < allowedHeight
                    m.comments.removeChildIndex(0)
                    m.top.messageHeights = reCalcHeights(m.comments.getChildren(-1,0))
                    m.top.chatChanged = true
                    exit while
                else
                    m.comments.removeChildIndex(0)
                    m.top.messageHeights = reCalcHeights(m.comments.getChildren(-1,0))
                    m.top.chatChanged = true
                end if
            end while

            m.top.superchat = m.superchat
            m.top.thumbnailCache = m.thumbnailCache
            ? m.top.superchat

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
                                            ? "Got a chat message from the websocket."
                                            parsedComment = parseComment(message.data.comment)
                                            messageHeights.push(parsedComment.height)
                                            m.top.messageHeights = messageHeights
                                            totalHeight+=parsedComment.height
                                            m.comments.appendChild(parsedComment)
                                            m.top.chatChanged = true
                                            while totalHeight > allowedHeight
                                                totalHeight=reCalcTotalHeight(m.comments.getChildren(-1,0))
                                                if totalHeight < allowedHeight
                                                    m.comments.removeChildIndex(0)
                                                    m.top.messageHeights = reCalcHeights(m.comments.getChildren(-1,0))
                                                    m.top.chatChanged = true
                                                    exit while
                                                else
                                                    m.comments.removeChildIndex(0)
                                                    m.top.messageHeights = reCalcHeights(m.comments.getChildren(-1,0))
                                                    m.top.chatChanged = true
                                                end if
                                            end while
                                        end if
                                    end if
                                else if message.type = "removed"
                                    
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
        end if
    end if
end function

function reCalcTotalHeight(comments)
    height = 0
    for each comment in comments
        height+=comment.height
    end for
    return height
end function

function reCalcHeights(comments)
    heights = []
    for each comment in comments
        heights.push(comment.height)
    end for
    return heights
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

function parseComment(comment)
    newComment = CreateObject("roSGNode", "chatdata")
    'Note that each comment is actually based on chatdata.xml, this is because we are feeding it directly into m.chatBox
    newComment.message = m.chatRegex.Replace(comment.comment, "")
    newComment.height = getMessageHeight(comment.comment, 30, 420)
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
    return newComment
end function

function getThumbnail(channelIdentifier, thumbnailCache, channelClaim)
    'apparently I wrote some of this while braindead, so we'll add a method to resolve channels by URL+ClaimID
    if isValid(thumbnailCache) = false
        thumbnailCache = {}
    end if
    if channelIdentifier.instr("lbry") > -1
        cqueryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=resolve"
        cqueryJSON = FormatJson({ "method": "resolve", "params": { "urls": [channelurl], "include_purchase_receipt": false, "include_is_my_output": false, "include_sent_supports": false, "include_sent_tips": false, "include_received_tips": false } })
        channelQuery = postJSON(cqueryJSON, cqueryURL, invalid)
        try
            cKey = channelQuery.result.Keys()[0]
            thumbnailCache.addReplace(channelsQuery.result[ckey].claim_id, m.top.constants["THUMBNAIL_PROCESSOR"] + channelsQuery.result[ckey].value.thumbnail.url)
        catch e
            thumbnailCache.addReplace(channelClaim, "https://player.odycdn.com/speech/spaceman-png:2.png")
        end try
    else
        try
            cqueryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
            cqueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page": 1, "page_size": 1, "channel_ids": [channelIdentifier], "claim_type": ["stream"], "no_totals": true, "include_purchase_receipt": false, "include_is_my_output": false, "include_sent_supports": false, "include_sent_tips": false, "include_received_tips": false } })
            channelQuery = postJSON(cqueryJSON, cqueryURL, invalid)
            currentChannel = channelQuery.result.items[0]["signing_channel"]
            thumbnailCache.addReplace(channelIdentifier, m.top.constants["THUMBNAIL_PROCESSOR"] + currentChannel.value.thumbnail.url)
        catch e
            thumbnailCache.addReplace(channelIdentifier, "https://player.odycdn.com/speech/spaceman-png:2.png")
        end try
    end if
    return thumbnailCache
end function

function getMessageHeight(inputText, fontSize, maxfontWidth)
    ' ? "RUNNING"
    'm.htimer.Mark()
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

function isLivestreaming(channel)
    isStreaming = false
    try
        lsqueryURL = "https://api.odysee.live/livestream/is_live?channel_claim_id=" + channel
        livestreamClaimQuery = getJSON(lsqueryURL)
        retries = 0
        while true
            if isValid(livestreamClaimQuery.data)
                if IsValid(livestreamClaimQuery.data.ActiveClaim) and IsValid(livestreamClaimQuery.data.live)
                    if isValid(livestreamClaimQuery.data.ActiveClaim.ClaimID) and livestreamClaimQuery.data.live
                        if livestreamClaimQuery.data.live = true
                            isStreaming = true
                            exit while
                        end if
                    end if
                else
                    livestreamClaimQuery = getJSON(lsqueryURL)
                    retries += 1
                end if
            end if
            if retries > 5
                isStreaming = false
                exit while
            end if
        end while
    catch e
        isStreaming = false
    end try
    if isStreaming = false
        return legacyIsLivestreaming(channel) 'if all else fails, attempt the legacy method
    else
        return true
    end if
end function

function legacyIsLivestreaming(channel) 'This is a placeholder until the new API is widely used.
    'This finds if a user is livestreaming. If it is, it gets the livestream data, and then resolves the chat claimId for that individual livestream.
    'Chat is only attached to the latest livestream. If the user streams more than one livestream, we will have a problem.
    retries = 0
    while retries < 5
        'https://api.live.odysee.com/v1/odysee/live/
        try
            livestreamStatus = getJSON(m.top.constants["LIVE_API"] + "/" + channel)
            livestreamData = livestreamStatus["data"]
            if livestreamData.live = false
                success = false
                livestreamData = {}
                livestreamClaimData = {}
                chatClaim = ""
                exit while
            else
                success = true
                'The stream exists, so we need to resolve the stream claim (for chat)
                lsqueryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
                lsqueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": 1, "claim_type": "stream", "no_totals": true, "any_tags": [], "not_tags": ["porn", "porno", "nsfw", "mature", "xxx", "sex", "creampie", "blowjob", "handjob", "vagina", "boobs", "big boobs", "big dick", "pussy", "cumshot", "anal", "hard fucking", "ass", "fuck", "hentai"], "channel_ids": [channel], "not_channel_ids": [], "order_by": ["release_time"], "has_no_source": true, "include_purchase_receipt": false, "has_channel_signature": true, "valid_channel_signature": true, "has_source": false } })
                livestreamClaimQuery = postJSON(lsqueryJSON, lsqueryURL, invalid)
                while true
                    if IsValid(livestreamClaimQuery.error)
                        livestreamClaimQuery = postJSON(lsqueryJSON, lsqueryURL, invalid)
                        retries += 1
                    else
                        exit while
                    end if
                    if retries > 5
                        success = false
                        exit while
                    end if
                end while
            end if
        catch e
            retries += 1
            if retries >= 5
                success = false
                exit while
            end if
        end try
    end while
    return success
end function

function resolveStreamID(channel)
    try
        lsqueryURL = "https://api.odysee.live/livestream/is_live?channel_claim_id=" + channel
        livestreamClaimQuery = getJSON(lsqueryURL)
        retries = 0
        while true
            if isValid(livestreamClaimQuery.data)
                if IsValid(livestreamClaimQuery.data.ActiveClaim) and IsValid(livestreamClaimQuery.data.live)
                    if isValid(livestreamClaimQuery.data.ActiveClaim.ClaimID) and livestreamClaimQuery.data.live
                        if livestreamClaimQuery.data.live
                            return livestreamClaimQuery.data.ActiveClaim.ClaimID
                        end if
                        exit while
                    end if
                else
                    livestreamClaimQuery = getJSON(lsqueryURL)
                    retries += 1
                end if
            end if
            if retries > 5
                return resolveStreamIDLegacy(channel)
            end if
        end while
        return livestreamClaimQuery.data.ActiveClaim.ClaimID
    catch e
        return resolveStreamIDLegacy(channel)
    end try
end function

function resolveStreamIDLegacy(channel)
    'This uses the legacy method to resolve a livestream chat claimID.
    while m.top.resolveAttempts < 5
        'https://api.live.odysee.com/v1/odysee/live/
        try
            livestreamStatus = getJSON(m.top.constants["LIVE_API"] + "/" + channel)
            livestreamData = livestreamStatus["data"]
            if livestreamData.live = false
                success = false
                livestreamData = {}
                livestreamClaimData = {}
                chatClaim = ""
                exit while
            else
                success = true
                'The stream exists, so we need to resolve the stream claim (for chat)
                lsqueryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
                lsqueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": 1, "claim_type": "stream", "no_totals": true, "any_tags": [], "not_tags": ["porn", "porno", "nsfw", "mature", "xxx", "sex", "creampie", "blowjob", "handjob", "vagina", "boobs", "big boobs", "big dick", "pussy", "cumshot", "anal", "hard fucking", "ass", "fuck", "hentai"], "channel_ids": [channel], "not_channel_ids": [], "order_by": ["release_time"], "has_no_source": true, "include_purchase_receipt": false, "has_channel_signature": true, "valid_channel_signature": true, "has_source": false } })
                livestreamClaimQuery = postJSON(lsqueryJSON, lsqueryURL, invalid)
                retries = 0

                while true
                    if IsValid(livestreamClaimQuery.error)
                        livestreamClaimQuery = postJSON(lsqueryJSON, lsqueryURL, invalid)
                        retries += 1
                    else
                        exit while
                    end if
                    if retries > 5
                        exit while
                    end if
                end while

                if IsValid(livestreamClaimQuery.error)
                    'if we can't resolve the chat, we shouldn't play the livestream.
                    livestreamData = {}
                    livestreamClaimData = {}
                    success = false
                    chatClaim = ""
                    exit while
                else
                    livestreamClaimData = livestreamClaimQuery
                    ?"chat claim appears to be: " + livestreamClaimData.result.items[0].claim_id
                end if
                exit while
            end if
        catch e
            m.top.resolveAttempts += 1
            if m.top.resolveAttempts >= 5
                success = false
                livestreamData = {} 'live API not responding, assume no livestream.
                livestreamClaimData = {}
                chatClaim = ""
                exit while
            end if
        end try
    end while

    if success = true
        return livestreamClaimData.result.items[0].claim_id
    else
        return false
    end if
end function