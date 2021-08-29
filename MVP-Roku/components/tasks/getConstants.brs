Sub Init()
    m.top.functionName = "master"
End Sub

sub master()

    'Define variables
    globalAPIConstantsRaw = getRawText(m.global.constants.apiconstantsurl)
    globalLivestreamConstantsRaw = getRawText(m.global.constants.livestreamconstantsurl)
    globalAPIConstants = {}

    'Grab+Parse
    for each line in globalAPIConstantsRaw.split(Chr(10)) 'Extract 1 (see OdyseeLogicDiagram.dia)
        if instr(line, "API") > 0
            ? line.split("=")[0]
            if instr(line, "WEB_API") > 0
                globalAPIConstants["QUERY_API"] = line.split("=")[1]
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
    
    'Export
    m.top.constants = globalAPIConstants
End Sub
