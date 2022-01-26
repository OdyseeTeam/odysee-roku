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
                m.top.reactions = get_reactions()
            end if
        end if
    else if isValid(m.top.authToken)
        if Type(m.top.authToken) = "roString"
            if m.top.authToken <> ""
                m.top.reactions = get_reactions()
            end if
        end if
    end if
end sub

function get_reactions()
    '8080 sso
    '8081 sdk
    '8082 api
    '{
    '    "success": true,
    '    "error": null,
    '    "data": {
    '      "my_reactions": {
    '        "e3a0086ef31ec806169c7c1c51863a57a3647e72": {
    '          "dislike": 0,
    '          "flag": 0,
    '          "investor_like": 0,
    '          "like": 1
    '        }
    '      },
    '      "others_reactions": {
    '        "e3a0086ef31ec806169c7c1c51863a57a3647e72": {
    '          "dislike": 0,
    '          "flag": 0,
    '          "investor_like": 0,
    '          "like": 13
    '        }
    '      }
    '    }
    '  }
    if isValid(m.top.accessToken) ' logged in
        if Type(m.top.accessToken) = "roString"
            if m.top.accessToken <> ""
                rawreactions = postURLEncoded({"claim_ids": m.top.claimID},m.top.constants["ROOT_API"]+"/reaction/list", { "Authorization": "Bearer " + m.top.accessToken })
                mylikes = rawreactions.data.my_reactions[m.top.claimID]["like"]
                mydislikes = rawreactions.data.my_reactions[m.top.claimID]["dislike"]
                otherlikes = rawreactions.data.others_reactions[m.top.claimID]["like"]
                otherdislikes = rawreactions.data.others_reactions[m.top.claimID]["dislike"]
                return {mine: {likes: mylikes, dislikes: mydislikes}, total: {likes: otherlikes, dislikes: otherdislikes}}
            end if
        end if
    else if isValid(m.top.authToken) ' not logged in
        if Type(m.top.authToken) = "roString"
            if m.top.authToken <> ""
                rawreactions = postURLEncoded({"claim_ids": m.top.claimID, "auth_token": m.top.authToken},m.top.constants["ROOT_API"]+"/reaction/list", {})
                otherlikes = rawreactions.data.others_reactions[m.top.claimID]["like"]
                otherdislikes = rawreactions.data.others_reactions[m.top.claimID]["dislike"]
                return {mine: {likes: 0, dislikes: 0}, total: {likes: otherlikes, dislikes: otherdislikes}}
            end if
        end if
    end if
end function

function string_deduplicate(array)
    if Type(array) <> "roArray"
        ?"ERROR: must be roArray"
        return ["error"]
    else
        deduper = {}
        deduparray = []
        for each item in array
            if type(item) <> "roString"
                ?"ERROR: must be an array of roStrings"
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