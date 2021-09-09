Sub Init()
    m.top.functionName = "master"
End Sub

sub master()
    'm.top.bandwidth
    'm.top.cache
    'm.top.device
    'm.top.player
    'm.top.position
    'm.top.protocol
    'm.top.rebuf_count
    'm.top.rebuf_duration
    'm.top.url
    m.top.output = report()
End Sub

Function report()
    if m.top.position > 0 AND m.top.duration > 0
        rel_position = Fix((m.top.position/m.top.duration)*100)
    else
        rel_position = Fix((1/m.top.duration)*100)
    end if
    APIQueryJSON = formatJSON({"rebuf_count":m.top.rebuf_count,"rebuf_duration":m.top.rebuf_duration,"url":m.top.url,"device":"web","duration":5000,"protocol":m.top.protocol,"player":m.top.player,"user_id":StrI(m.top.uid),"position":m.top.position,"rel_position":rel_position})
    APIWatchmanURL = m.top.constants["WATCHMAN"]+"/reports/playback"
    watchmanQuery = postJSONResponseOut(APIQueryJSON,APIWatchmanURL, invalid)
    if watchmanQuery <> 201
        return {success: false, error: true}
    else
        return {success: true, error: false}
    end if

End Function