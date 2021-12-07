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
                m.top.status = set_reactions(m.top.action)
            end if
        end if
    end if
end sub

function set_reactions(action)
    '8080 sso
    '8081 sdk
    '8082 api
    success = false
    if action = "like"
        reaction = postURLEncoded({"claim_ids": m.top.claimID, "type": "like", "clear_types": "dislike"},m.top.constants["ROOT_API"]+"/reaction/react", { "Authorization": "Bearer " + m.top.accessToken })
        ? FormatJson(reaction)
        success = reaction.success
    end if
    if action = "dislike"
        reaction = postURLEncoded({"claim_ids": m.top.claimID, "type": "dislike", "clear_types": "like"},m.top.constants["ROOT_API"]+"/reaction/react", { "Authorization": "Bearer " + m.top.accessToken })
        ? FormatJson(reaction)
        success = reaction.success
    end if
    if action = "negate" 'negate: neither like nor dislike
        reaction1 = postURLEncoded({"claim_ids": m.top.claimID, "type": "like", "remove": "true"},m.top.constants["ROOT_API"]+"/reaction/react", { "Authorization": "Bearer " + m.top.accessToken })
        reaction2 = postURLEncoded({"claim_ids": m.top.claimID, "type": "dislike", "remove": "true"},m.top.constants["ROOT_API"]+"/reaction/react", { "Authorization": "Bearer " + m.top.accessToken })
        ? FormatJson(reaction1)
        ? FormatJson(reaction2)
        if reaction1.success OR reaction2.success
            success = true
        end if
    end if
    return {success: success}
end function

function string_deduplicate(array)
    if Type(array) <> "roArray"
        ? "ERROR: must be roArray"
        return ["error"]
    else
        deduper = {}
        deduparray = []
        for each item in array
            if type(item) <> "roString"
                ? "ERROR: must be an array of roStrings"
                return ["error"]
            else
                deduper.addReplace(item, "")
            end if
        end for
        deduparray.append(deduper.Keys())
        deduper = invalid
        return deduparray
    end if
end function