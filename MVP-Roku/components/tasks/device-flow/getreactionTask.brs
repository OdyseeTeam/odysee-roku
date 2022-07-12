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
    m.top.reactions = get_reactions()
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
    reactionHeaders = {}
    reactionQuery = {}
    if m.top.accessToken <> ""
        reactionHeaders = { "Authorization": "Bearer " + m.top.accessToken }
        reactionQuery = { "claim_ids": m.top.claimID }
    else if m.top.authToken <> ""
        rawreactions = postURLEncoded({ "claim_ids": m.top.claimID, "auth_token": m.top.authToken }, m.top.constants["ROOT_API"] + "/reaction/list", {})
        reactionHeaders = {}
        reactionQuery = { "claim_ids": m.top.claimID, "auth_token": m.top.authToken }
    end if
    if reactionHeaders.Count() = 0 and reactionQuery.Count() = 0
        return { mine: { likes: 0, dislikes: 0 }, total: { likes: 0, dislikes: 0 } } 'default to no data instead of crashing
    end if
    rawreactions = postURLEncoded(reactionQuery, m.top.constants["ROOT_API"] + "/reaction/list", reactionHeaders)
    otherlikes = rawreactions.data.others_reactions[m.top.claimID]["like"]
    otherdislikes = rawreactions.data.others_reactions[m.top.claimID]["dislike"]
    if isValid(rawreactions.data.my_reactions)
        mylikes = rawreactions.data.my_reactions[m.top.claimID]["like"]
        mydislikes = rawreactions.data.my_reactions[m.top.claimID]["dislike"]
    else
        mylikes = 0
        mydislikes = 0
    end if
    return { mine: { likes: mylikes, dislikes: mydislikes }, total: { likes: otherlikes, dislikes: otherdislikes } }
end function