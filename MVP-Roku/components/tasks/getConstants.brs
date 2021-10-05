Sub Init()
    m.top.functionName = "master"
End Sub

sub master()

    'Define variables
    globalAPIConstantsRaw = getRawText(m.global.constants.apiconstantsurl)
    globalLivestreamConstantsRaw = getRawText(m.global.constants.livestreamconstantsurl)
    globalAPIConstants = CreateObject("roAssociativeArray")
    'for future reference:
    '{
    '    CHAT_API: "ws://sockety.odysee.com/ws"
    '    COMMENT_API: "https://comments.odysee.com/api/v2"
    '    IMAGE_PROCESSOR: "https://image-processor.vanwanet.com/optimize/s:390:220/quality:85/plain/"
    '    LIGHTHOUSE_API: "https://lighthouse.odysee.com/search"
    '    LIVE_API: "https://api.live.odysee.com/v1/odysee/live"
    '    LIVE_REPLAY_API: "https://api.live.odysee.com/v1/replays/odysee"
    '    QUERY_API: "https://api.na-backend.odysee.com"
    '    ROOT_API: "https://api.odysee.com"
    '    VIDEO_API: "https://cdn.lbryplayer.xyz"
    '    WATCHMAN: "https://watchman.na-backend.odysee.com"
    '}

    'Grab+Parse
    for each line in globalAPIConstantsRaw.split(Chr(10)) 'Extract 1 (see OdyseeLogicDiagram.dia)
        if instr(line, "API") > 0 OR instr(line, "CDN") > 0
            ? line.split("=")[0]
            if instr(line, "WEB_API") > 0
                globalAPIConstants["QUERY_API"] = line.split("=")[1]
                globalAPIConstants["WATCHMAN"] = "https://watchman.na-backend.odysee.com" 'not added to .env.defaults in place of LBRY_WEB_BUFFER_API
                dotlen = line.split("=")[1].split(".").Count()
                globalAPIConstants["ROOT_API"] = "https://api."+line.split("=")[1].split(".")[dotlen-2]+"."+line.split("=")[1].split(".")[dotlen-1] 'Extract root domain
            end if
            if instr(line, "WEB_STREAMING_API") > 0 
                globalAPIConstants["VIDEO_API"] = line.split("=")[1]
            end if
            if instr(line, "SEARCH_SERVER_API") > 0 
                globalAPIConstants["LIGHTHOUSE_API"] = line.split("=")[1]
            end if
            if instr(line, "COMMENT_SERVER_API") > 0 
                globalAPIConstants["COMMENT_API"] = line.split("=")[1]
            end if
            if instr(line, "SOCKETY_SERVER_API") > 0 
                globalAPIConstants["CHAT_API"] = line.split("=")[1].replace("wss", "ws")
            end if
            if instr(line, "THUMBNAIL_CDN_URL") > 0
                iproc = line.split("=")[1]
                iprocsplit = iproc.split("")
                iprocargs = "s:390:220/quality:85/plain/"
                if iprocsplit[iprocsplit.Count()-1] = "/"
                    globalAPIConstants["IMAGE_PROCESSOR"] = iproc+iprocargs
                else
                    globalAPIConstants["IMAGE_PROCESSOR"] = iproc+"/"+iprocargs
                end if
            end if
        end if
    end for

    line = invalid 'Memory Cleanup

    for each line in globalLivestreamConstantsRaw.split(Chr(10)) 'Extract 2 (see OdyseeLogicDiagram.dia)
        if instr(line, "API") > 0
            if instr(line, "LIVE_API") > 0
                globalAPIConstants["LIVE_API"] = line.split("=")[1].replace(" ","").replace("'","").replace(";","")
            else if instr(line, "REPLAY_API") > 0 
                globalAPIConstants["LIVE_REPLAY_API"] = line.split("=")[1].replace(" ","").replace("'","").replace(";","")
            end if
        end if
    end for

    'Memory Cleanup
    line = invalid
    globalAPIConstantsRaw = invalid
    globalLivestreamConstantsRaw = invalid
    iprocsplit = invalid
    iprocargs = invalid
    dotlen = invalid
    if globalAPIConstants.Count() < 10
        m.top.error = true
    end if
    'Export
    m.top.constants = globalAPIConstants
End Sub
