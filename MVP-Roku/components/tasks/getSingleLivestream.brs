sub Init()
    m.top.functionName = "fetchLivestream"
end sub

sub fetchLivestream()
    ' Fetch livestream data for a specific channel
    if not IsValid(m.top.channel) or m.top.channel = ""
        m.top.output = { success: false }
        return
    end if

    ' Call getLivestream from liveUtils
    result = getLivestream(m.top.channel)

    if IsValid(result)
        m.top.output = result
    else
        m.top.output = { success: false }
    end if
end sub
