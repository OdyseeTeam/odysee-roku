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
                m.top.setState = set_prefs()
            end if
        end if
    end if
end sub

function set_prefs()
    '8080 sso
    '8081 sdk
    '8082 api
    m.top.oldHash = m.top.newHash
    m.inSync = true
    ? "Step 2: Preference Get (for modification)"
    'Step 2: Preference Get (for modification)
    if m.inSync
        preferences = postJSON(formatJson({ "jsonrpc": "2.0", "method": "preference_get", "params": { "key": "shared" }, "id": m.top.uid }), m.top.constants["ROOT_SDK"] + "/api/v1/proxy", { "Authorization": "Bearer " + m.top.accessToken })
        'Step 3: Modification
        ? "Step 3: Modification"
        if isValid(preferences.result)
            if IsValid(preferences.result.shared)
                if isValid(preferences.result.shared.value)
                    preferences.result.shared.value = preferences.result.shared.value
                    if m.top.changeType = "append"
                        'Code from getpreferencesTask, used only on append to prevent duplication.
                        blocked = []
                        following = []
                        followingaa = {}
                        userPreferences = preferences.result.shared.value
                        ? formatJson(userPreferences)
                        if isValid(userPreferences.blocked)
                            for each user in userPreferences.blocked
                                blocked.push(user.split("#")[1])
                            end for
                        end if
                        if isValid(userPreferences.following)
                            for each user in userPreferences.following
                                if Type(user) <> "roString"
                                    followingaa.addReplace(user.uri.split("#")[1], "a") '(for Following page)
                                end if
                            end for
                        end if
                        if isValid(userPreferences.subscriptions)
                            for each subscription in userPreferences.subscriptions
                                followingaa.addReplace(subscription.split("#")[1], "a") '(abuse AssociativeArray addReplace to remove duplicates)
                            end for
                        end if
                        following.append(followingaa.Keys()) 'get output (no duplicates)
                        followingaa = invalid

                        'm.top.preferences = { blocked: blocked: following: following: collections: collections }
                        if isValid(preferences.result.shared.value.blocked) and isValid(m.top.preferences.blocked)
                            for each subclaim in m.top.preferences.blocked
                                isDuplicate = false
                                if subclaim.split("#").Count() > 1
                                    for each blockeduser in blocked
                                        if subclaim.split("#").Pop() = blockeduser
                                            isDuplicate = true
                                        end if
                                    end for
                                    'assume that we are in non-legacy format inside legacy datastructure
                                    if isDuplicate = false
                                        preferences.result.shared.value.blocked.push(subclaim)
                                    end if
                                else
                                    'legacy: we will need to look up this channel
                                    queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
                                    queryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": 1, "claim_type": ["channel"], "no_totals": true, "any_tags": [], "claim_ids": [subclaim], "include_purchase_receipt": false, "include_is_my_output": false, "include_sent_supports": false, "include_sent_tips": false, "include_received_tips": false }, "id": m.top.uid })
                                    response = postJSON(queryJSON, queryURL, invalid)
                                    try
                                        for each blockeduser in blocked
                                            if response.result.items[0]["permanent_url"].split("#").Pop() = blockeduser
                                                isDuplicate = true
                                            end if
                                        end for
                                        if isDuplicate = false
                                            preferences.result.shared.value.blocked.push(response.result.items[0]["permanent_url"])
                                        end if
                                    catch e
                                        ? e
                                        stop
                                    end try
                                end if
                            end for
                        end if
                        if isValid(preferences.result.shared.value.following) and isValid(m.top.preferences.following)
                            'support both current and raw claim format
                            for each subclaim in m.top.preferences.following
                                isDuplicate = false
                                if Type(subclaim) <> "roString" 'already in non-raw format, no need for additional parsing
                                    if isValid(subclaim.uri) and isValid(subclaim["notificationsDisabled"])
                                        for each followeduser in following
                                            if subclaim.uri.split("#").Pop() = followeduser
                                                isDuplicate = true
                                            end if
                                        end for
                                        if isDuplicate = false
                                            preferences.result.shared.value.following.append([subclaim])
                                            prenotify_new_follow(subclaim.uri.split("#").Pop())
                                        end if
                                    end if
                                else 'in raw claim format: needs additional data
                                    if subclaim.split("#").Count() > 1
                                        for each followeduser in following
                                            if subclaim.split("#").Pop() = followeduser
                                                isDuplicate = true
                                            end if
                                        end for
                                        'assume that we are in non-legacy format inside legacy datastructure
                                        if isDuplicate = false
                                            preferences.result.shared.value.following.append([{ uri: subclaim, "notificationsDisabled": true }])
                                            prenotify_new_follow(subclaim.split("#").Pop())
                                        end if
                                    else
                                        'legacy: we will need to look up this channel
                                        queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
                                        queryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": 1, "claim_type": ["channel"], "no_totals": true, "any_tags": [], "claim_ids": [subclaim], "include_purchase_receipt": false, "include_is_my_output": false, "include_sent_supports": false, "include_sent_tips": false, "include_received_tips": false }, "id": m.top.uid })
                                        response = postJSON(queryJSON, queryURL, invalid)
                                        try
                                            for each followeduser in following
                                                if response.result.items[0]["permanent_url"].split("#").Pop() = followeduser
                                                    isDuplicate = true
                                                end if
                                            end for
                                            if isDuplicate = false
                                                preferences.result.shared.value.following.append([{ uri: response.result.items[0]["permanent_url"], "notificationsDisabled": true }])
                                                prenotify_new_follow(subclaim)
                                            end if
                                        catch e
                                            ? e
                                            stop
                                        end try
                                    end if
                                end if
                            end for
                        end if
                        if isValid(preferences.result.shared.value.subscriptions) and isValid(m.top.preferences.following)
                            subsToPush = []
                            'convert from following format to legacy subscription format (keep consistency for desktop client/other implimentations)
                            for each subclaim in m.top.preferences.following
                                isDuplicate = false
                                if Type(subclaim) <> "roString" 'already in non-raw format, no need for additional parsing
                                    if isValid(subclaim.uri) and isValid(subclaim["notificationsDisabled"])
                                        for each followeduser in following
                                            if subclaim.uri.split("#").Pop() = followeduser
                                                isDuplicate = true
                                            end if
                                        end for
                                        if isDuplicate = false
                                            preferences.result.shared.value.subscriptions.push(subclaim.uri)
                                        end if
                                    end if
                                else 'in raw claim format: needs additional data
                                    if subclaim.split("#").Count() > 1
                                        'assume that we are in non-legacy format inside legacy datastructure
                                        for each followeduser in following
                                            if subclaim.split("#").Pop() = followeduser
                                                isDuplicate = true
                                            end if
                                        end for
                                        if isDuplicate = false
                                            preferences.result.shared.value.subscriptions.push(subclaim)
                                        end if
                                    else
                                        'legacy: we will need to look up this channel
                                        queryURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
                                        queryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": 1, "claim_type": ["channel"], "no_totals": true, "any_tags": [], "claim_ids": [subclaim], "include_purchase_receipt": false, "include_is_my_output": false, "include_sent_supports": false, "include_sent_tips": false, "include_received_tips": false }, "id": m.top.uid })
                                        response = postJSON(queryJSON, queryURL, invalid)
                                        try
                                            for each followeduser in following
                                                if response.result.items[0]["permanent_url"].split("#").Pop() = followeduser
                                                    isDuplicate = true
                                                end if
                                            end for
                                            if isDuplicate = false
                                                preferences.result.shared.value.subscriptions.push(response.result.items[0]["permanent_url"])
                                            end if
                                        catch e
                                            ? e
                                            stop
                                        end try
                                    end if
                                end if
                            end for
                        end if
                        'TODO: Add collections to this (requires timestamp manip.)
                    else if m.top.changeType = "remove"
                        if isValid(preferences.result)
                            if IsValid(preferences.result.shared)
                                if isValid(preferences.result.shared.value)
                                    try
                                        for i = 0 to preferences.result.shared.value.blocked.Count() - 1
                                            ? preferences.result.shared.value.blocked[i]
                                            if isValid(preferences.result.shared.value.blocked[i])
                                                for each change in m.top.preferences.blocked
                                                    if change.split("#").Count() > 1
                                                        if preferences.result.shared.value.blocked[i] = change
                                                            preferences.result.shared.value.blocked.Delete(i)
                                                        end if
                                                    else
                                                        if preferences.result.shared.value.blocked[i].split("#").Pop() = change
                                                            preferences.result.shared.value.blocked.Delete(i)
                                                        end if
                                                    end if
                                                end for
                                            end if
                                        end for
                                        i = invalid
                                    catch e
                                        ? "Modification Error:"
                                        ? e
                                    end try
                                    for i = 0 to preferences.result.shared.value.following.Count() - 1
                                        if isValid(preferences.result.shared.value.following[i])
                                            for each change in m.top.preferences.following
                                                if change.split("#").Count() > 1
                                                    if preferences.result.shared.value.following[i]["uri"] = change
                                                        preferences.result.shared.value.following.Delete(i)
                                                        prenotify_delete_follow(change.split("#").Pop())
                                                    end if
                                                else
                                                    if preferences.result.shared.value.following[i]["uri"].split("#").Pop() = change
                                                        preferences.result.shared.value.following.Delete(i)
                                                        prenotify_delete_follow(change)
                                                    end if
                                                end if
                                            end for
                                        end if
                                    end for
                                    i = invalid
                                    try
                                        for i = 0 to preferences.result.shared.value.subscriptions.Count() - 1
                                            if isValid(preferences.result.shared.value.subscriptions[i])
                                                for each change in m.top.preferences.following
                                                    if change.split("#").Count() > 1
                                                        if preferences.result.shared.value.subscriptions[i] = change
                                                            preferences.result.shared.value.subscriptions.Delete(i)
                                                        end if
                                                    else
                                                        if preferences.result.shared.value.subscriptions[i].split("#").Pop() = change
                                                            preferences.result.shared.value.subscriptions.Delete(i)
                                                        end if
                                                    end if
                                                end for
                                            end if
                                        end for
                                        i = invalid
                                    catch e
                                        ? "Modification Error:"
                                        ? e
                                    end try
                                    'TODO: Add collections to this (requires timestamp manip.)
                                end if
                            end if
                        end if
                    end if
                    ? formatJson(preferences.result.shared.value)
                end if
            end if
        end if
        'Step 4: preference_set (set what we altered)
        ? "Step 4: preference_set (set what we altered)"
        preferences = postJSON(formatJson({ "jsonrpc": "2.0", "method": "preference_set", "params": { "key": "shared", "value": formatJson(preferences.result.shared) }, "id": m.top.uid }), m.top.constants["ROOT_SDK"] + "/api/v1/proxy", { "Authorization": "Bearer " + m.top.accessToken })
        ? FormatJson(preferences)
        if isValid(preferences.result) = false
            needs_resync = true
        end if
        'Step 5: Sync Apply (to SDK)
        ? "Step 5: Sync Apply (to SDK)"
        syncapply = postJSON(formatJson({ "jsonrpc": "2.0", "method": "sync_apply", "params": { "password": "": "blocking": true }, "id": m.top.uid }), m.top.constants["ROOT_SDK"] + "/api/v1/proxy", { "Authorization": "Bearer " + m.top.accessToken })
        ? FormatJson(syncapply)
        if isValid(syncapply.data)
            if isValid(syncapply.data.data) and isValid(syncapply.data.hash)
                m.top.newHash = "" + syncapply.result.hash
                m.top.walletData = syncapply.result.data
            end if
        end if
        'Step 6: Sync Set (to API)
        ? "Step 6: Sync Set (to API)"
        syncset = postURLEncoded({ old_hash: m.top.oldHash, new_hash: "" + syncapply.result.hash: data: "" + syncapply.result.data }, m.top.constants["ROOT_API"] + "/sync/set", { "Authorization": "Bearer " + m.top.accessToken })
        ? formatJson(syncset)
        if syncset.success = true
            ? "Successfully synchronized data"
            m.inSync = true
        else
            ? "Failed to sync data (APIs do NOT MATCH)"
            m.top.error = true
            m.inSync = false
        end if
        if m.top.error = true
            return 2
        else
            return 1
        end if
    end if
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

function prenotify_delete_follow(follow)
    notifyURL = m.top.constants["ROOT_API"] + "/subscription/delete"
    notifyQuery = {claim_id: follow}
    postURLEncoded(notifyQuery, notifyURL, { "Authorization": "Bearer " + m.top.accessToken })
end function

function prenotify_new_follow(follow)
    notifyURL = m.top.constants["ROOT_API"] + "/subscription/new"
    notifyQuery = {claim_id: follow,notifications_disabled:true}
    postURLEncoded(notifyQuery, notifyURL, { "Authorization": "Bearer " + m.top.accessToken })
end function