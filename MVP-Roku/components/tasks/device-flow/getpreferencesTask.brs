sub Init()
    m.top.functionName = "master"
    m.authTimer = m.top.findNode("authTimer") 'refresh timer
end sub

sub master()
    '1. sync_get returns hash+data (if init, reverse steps 1/2 and compare external to sync_hash)
    '2. compare to sync_hash (sdk)
    '3. if same: do nothing
    '   if different: sync apply data
    '4. once sync_apply (syncs remote):
    '5. preferences_get
    'THEN:
    '6. preferences_set:
    '7. set w/preferences_get+new data
    '8. call sync_apply
    '9. then call sync_set+new data from sync_apply
    if isValid(m.top.accessToken)
        if Type(m.top.accessToken) = "roString"
            if m.top.accessToken <> ""
                m.top.preferences = get_prefs()
            end if
        end if
    end if
end sub