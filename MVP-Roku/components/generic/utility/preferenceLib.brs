function get_prefs()
    try
        '8080 sso
        '8081 sdk
        '8082 api
        '8086 OdyGetWalletData Custom API
        'Now we need our Odysee userData so we can sync over

        'Moving between # and : in walletfiles (iOS), so replace # with :
        'Save as : by default

        'We need additional data that cannot be acquired through normal means, so we'll get it after getting preferences.
        date = CreateObject("roDateTime")
        ? date.ToISOString() + " Getting preferences (SDK)"
        date = invalid
        preferences = postJSON(formatJson({ "jsonrpc": "2.0", "method": "preference_get", "params": { "key": "shared" }, "id": m.top.uid }), m.top.constants["ROOT_SDK"] + "/api/v1/proxy", { "Authorization": "Bearer " + m.top.accessToken })
        ?"=============================GETTING USER PREFS.============================="
        '?formatJson(preferences)
        blocked = []
        following = []
        followingaa = {}
        if isValid(preferences.result)
            if IsValid(preferences.result.shared)
                if isValid(preferences.result.shared.value)
                    ?formatJson(preferences)
                    userPreferences = preferences.result.shared.value
                    ?formatJson(userPreferences)
                    if isValid(userPreferences.blocked)
                        for each user in userPreferences.blocked
                            blocked.push(user.replace("#", ":").split(":").Pop())
                        end for
                    end if
                    if isValid(userPreferences.following)
                        for each user in userPreferences.following
                            if Type(user) <> "String"
                                followingaa.addReplace(user.uri.replace("#", ":").split(":").Pop(), "a") '(for Following page)
                            end if
                        end for
                    end if
                    if isValid(userPreferences.subscriptions)
                        for each subscription in userPreferences.subscriptions
                            followingaa.addReplace(subscription.replace("#", ":").split(":").Pop(), "a") '(abuse AssociativeArray addReplace to remove duplicates)
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
                                                curcollection.items.push(builtInCollections[collection].items[i].replace("#", ":"))
                                            end for
                                            collections.push(curcollection)
                                            curcollection = invalid
                                            i = invalid
                                        else
                                            curcollection = { name: builtInCollections[collection].name: items: [] }
                                            for i = 0 to builtInCollections[collection].items.Count() - 1
                                                curcollection.items.push(builtInCollections[collection].items[i].replace("#", ":"))
                                            end for
                                            collections.push(curcollection)
                                            curcollection = invalid
                                            i = invalid
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
                                                curcollection.items.push(unpublishedCollections[collection].items[i].replace("#", ":"))
                                            end for
                                            collections.push(curcollection)
                                            curcollection = invalid
                                            i = invalid
                                        else
                                            curcollection = { name: unpublishedCollections[collection].name: items: [] }
                                            for i = 0 to unpublishedCollections[collection].items.Count() - 1
                                                curcollection.items.push(unpublishedCollections[collection].items[i].replace("#", ":"))
                                            end for
                                            collections.push(curcollection)
                                            curcollection = invalid
                                            i = invalid
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
        ?"User has blocked channelids:"
        ?blocked
        ?"User has followed channelids:"
        ?following
        ?"===================================DONE==================================="
        return { blocked: blocked: following: following: collections: collections, raw: preferences }
    catch e
        m.top.error = "true"
    end try
end function