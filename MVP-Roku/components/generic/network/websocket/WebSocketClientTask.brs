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
            'TODO: hide blocked users in chat/superchat
            'if isValid(m.top.blocked)
            '    if m.top.blocked.Count() > 0
            '    end if
            'end if
            m.parseTimer = CreateObject("roTimespan")
            m.parseTimer.Mark()
            m.fontReg = CreateObject("roFontRegistry")
            m.fontReg.Register("pkg://components/generic/fonts/Inter-Emoji.otf")
            m.chatRegex = CreateObject("roRegex", "[^\x00-\x7F]", "")
            m.comments = m.top.findNode("chat")
            'Time to get chat history.
            chat = []
            commentURL = m.top.constants["COMMENT_API"] + "?m=comment.List"
            commentJSON = FormatJson({ "jsonrpc": "2.0", "id": 1, "method": "comment.List", "params": { "page": 1, "claim_id": m.top.streamClaim, "page_size": 20, "top_level": true, "channel_id": m.top.channelid, "sort_by": 0 } })
            chatResponse = postJSON(commentJSON, commentURL, invalid)
            superChatURL = m.top.constants["COMMENT_API"] + "?m=comment.SuperChatList"
            superChatJSON = FormatJson({ "jsonrpc": "2.0", "id": 1, "method": "comment.SuperChatList", "params": { "claim_id": m.top.streamClaim } })
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
            m.parseTimer.Mark()
            retries = 0
            superChatLength = 0
            m.superchat = []
            m.rawChat = []
            m.parsedChat = []
            for each superchatitem in superchatResponse.result.items
                message_supported = false
                try 'check if supported
                    support_amount = superchatitem.support_amount
                    if support_amount > 0
                        message_supported = true
                    end if
                catch e
                    message_supported = false
                end try
                'TODO: fix message support/superchat endpoint
                'stop
                if m.chatRegex.Replace(superchatitem["comment"].Trim(), "") <> "" and superchatitem["comment"].Trim().instr("![") = -1 and superchatitem["comment"].Trim().instr("](") = -1 and message_supported  and isValid(m.blocked[superchatitem["channel_id"]]) = false
                    if superChatLength > 4
                        exit for
                    end if
                    m.superchat.Push("[" + m.chatRegex.Replace(superchatitem["channel_name"] + "]: " + superchatitem["comment"].replace("\n", " ").Trim(), ""))
                    superChatLength += 1
                end if
            end for
            ? "WSC: Superchat History took " + (m.parseTimer.TotalMilliseconds() / 1000).ToStr() + "s"
            ? m.superchat
            m.parseTimer.Mark()
            chatResponse.result.items.Reverse()
            for each chatitem in chatResponse.result.items
                if m.chatRegex.Replace(chatitem["comment"].Trim(), "") <> "" and chatitem["comment"].Trim().instr("![") = -1 and chatitem["comment"].Trim().instr("](") = -1 and isValid(m.blocked[chatitem["channel_id"]]) = false
                    m.parsedChat.push(parseComment(chatitem)) 'so we can add/remove comments quickly later on
                end if
            end for
            for each chatitem in m.parsedChat
                m.rawChat.push(chatitem["username"] + ": " + chatitem["message"].replace("\n", " ").Trim())
            end for
            ? "WSC: Chat History took " + (m.parseTimer.TotalMilliseconds() / 1000).ToStr() + "s"
            m.top.superchat = m.superchat
            m.top.chat = { raw: m.rawChat, parsed: m.parsedChat }
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
                                    ? "GOT DELTA MESSAGE!"
                                    if isValid(message.data)
                                        ? "data valid"
                                        if isValid(message.data.comment)
                                            if isValid(message.data.comment.channel_id)
                                                ? "got a comment"
                                                chatitem = message.data.comment
                                                if m.chatRegex.Replace(chatitem["comment"].Trim(), "") <> "" and chatitem["comment"].Trim().instr("![") = -1 and chatitem["comment"].Trim().instr("](") = -1 AND isValid(m.blocked[chatitem.channel_id]) = false
                                                    m.parsedChat.push(parseComment(chatitem))
                                                end if
                                                chatitem = invalid
                                                if m.parsedChat.Count() > 20
                                                    while m.parsedChat.Count() > 20
                                                        m.parsedChat.Shift()
                                                        if m.parsedChat.Count() <= 20
                                                            exit while
                                                        end if
                                                    end while
                                                end if
                                                for each chatitem in m.parsedChat
                                                    m.rawChat.Shift()
                                                    m.rawChat.push(chatitem["username"] + ": " + chatitem["message"].replace("\n", " ").Trim())
                                                end for
                                                m.top.chat = { raw: m.rawChat, parsed: m.parsedChat }
                                                ? "WSC: Parsing Chat Message took " + (m.parseTimer.TotalMilliseconds() / 1000).ToStr() + "s"
                                            end if
                                        end if
                                    end if
                                else if message.type = "removed"
                                    m.parseTimer.Mark()
                                    cid = 0
                                    for each comment in m.parsedChat
                                        if comment.comment_id = message.data.comment.comment_id
                                            m.parsedChat.Delete(cid)
                                            exit for
                                        end if
                                        cid += 1
                                    end for
                                    cid = invalid
                                    m.rawChat = []
                                    for each chatitem in m.parsedChat
                                        m.rawChat.push(chatitem["username"] + "]: " + chatitem["message"].replace("\n", " ").Trim())
                                    end for
                                    m.top.chat = { raw: m.rawChat, parsed: m.parsedChat }
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
        end if
    end if
end function

function parseComment(comment)
    newComment = { message: "", username: "", comment_id: "" }
    'Note that each comment is actually based on chatdata.xml, this is because we are feeding it directly into m.chatBox
    if isValid(comment.message)
        newComment.message = m.chatRegex.Replace(comment.message, "")
    else
        newComment.message = m.chatRegex.Replace(comment.comment, "")
    end if
    if isValid(comment.username)
        newComment.username = m.chatRegex.Replace(comment["username"], "")
    else
        newComment.username = m.chatRegex.Replace(comment["channel_name"], "")
    end if
    newComment.comment_id = comment["comment_id"]
    if newComment.username.split("").Count() < 1
        newComment.username = "Anonymous"
    end if
    return newComment
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