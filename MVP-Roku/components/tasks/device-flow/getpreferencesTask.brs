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

function get_prefs()
    '8080 sso
    '8081 sdk
    '8082 api
    '8086 OdyGetWalletData Custom API
    'Now we need our Odysee userData so we can sync over
    date = CreateObject("roDateTime")
    ? date.ToISOString()+" Getting preferences (SDK)"
    date=invalid
    preferences = postJSON(formatJson({ "jsonrpc": "2.0", "method": "preference_get", "params": { "key": "shared" }, "id": m.top.uid }), m.top.constants["ROOT_SDK"]+"/api/v1/proxy", { "Authorization": "Bearer " + m.top.accessToken })
    ' ?"=============================GETTING USER PREFS.============================="
     ?formatJson(preferences)
    blocked = []
    following = []
    followingaa = {}
    if isValid(preferences.result)
        if IsValid(preferences.result.shared)
            if isValid(preferences.result.shared.value)
                ' ?formatJson(preferences)
                userPreferences = preferences.result.shared.value
                ' ?formatJson(userPreferences)
                if isValid(userPreferences.blocked)
                    for each user in userPreferences.blocked
                        blocked.push(user.split("#").Pop())
                    end for
                end if
                if isValid(userPreferences.following)
                    for each user in userPreferences.following
                        if Type(user) <> "String"
                            followingaa.addReplace(user.uri.split("#").Pop(), "a") '(for Following page)
                        end if
                    end for
                end if
                if isValid(userPreferences.subscriptions)
                    for each subscription in userPreferences.subscriptions
                        followingaa.addReplace(subscription.split("#").Pop(), "a") '(abuse AssociativeArray addReplace to remove duplicates)
                    end for
                end if
                following.append(followingaa.Keys()) 'get output (no duplicates)
                followingaa = invalid
                collections = []

                'This code removes all unneeded data from collections so we have the bare minimum to run queries with.
                'Plus, once we're done parsing, we can free memory.
                'TODO: Pagination (allow the user to see > 80 items)

                if isValid(userPreferences.builtInCollections)
                    if userPreferences.builtInCollections.Keys().Count() > 0
                        builtInCollections = userPreferences.builtInCollections
                        for each collection in builtInCollections.Keys()
                            if builtInCollections[collection]["type"] = "playlist"
                                if isValid(builtInCollections[collection].name) and isValid(builtInCollections[collection].items)
                                    if builtInCollections[collection].items.Count() >= 80
                                        curcollection = { name: builtInCollections[collection].name: items: [] }
                                        for i = 0 to 80
                                            curcollection.items.push(builtInCollections[collection].items.Pop())
                                        end for
                                        collections.push(curcollection)
                                        curcollection = invalid
                                        i = invalid
                                    else
                                        collections.push({ name: builtInCollections[collection].name, items: builtInCollections[collection].items })
                                    end if
                                end if
                            end if
                        end for
                        builtInCollections = invalid
                    end if
                end if
                if isValid(userPreferences.unpublishedCollections)
                    if userPreferences.unpublishedCollections.Keys().Count() > 0
                        unpublishedCollections = userPreferences.unpublishedCollections
                        for each collection in unpublishedCollections.Keys()
                            if unpublishedCollections[collection]["type"] = "playlist"
                                if isValid(unpublishedCollections[collection].name) and isValid(unpublishedCollections[collection].items)
                                    if unpublishedCollections[collection].items.Count() >= 80
                                        curcollection = { name: unpublishedCollections[collection].name: items: [] }
                                        for i = 0 to 80
                                            curcollection.items.push(unpublishedCollections[collection].items.Pop())
                                        end for
                                        collections.push(curcollection)
                                        curcollection = invalid
                                        i = invalid
                                    else
                                        collections.push({ name: unpublishedCollections[collection].name, items: unpublishedCollections[collection].items })
                                    end if
                                end if
                            end if
                        end for
                        unpublishedCollections = invalid
                    end if
                end if
                userPreferences = invalid
            end if
        end if
    end if
    ' ?"User has blocked channelids:"
    ' ?blocked
    ' ?"User has followed channelids:"
    ' ?following
    ' ?"===================================DONE==================================="
    return { blocked: blocked: following: following: collections: collections }
end function

function string_deduplicate(array)
    if Type(array) <> "roArray"
        ' ?"ERROR: must be roArray"
        return ["error"]
    else
        deduper = {}
        deduparray = []
        for each item in array
            if type(item) <> "roString"
                ' ?"ERROR: must be an array of roStrings"
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