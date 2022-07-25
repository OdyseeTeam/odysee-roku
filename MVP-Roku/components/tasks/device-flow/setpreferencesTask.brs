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

function prenotify_delete_follow(channelclaim, channelname)
    ?"Prenotifying ROOT API (/subscription/delete)"
    notifyURL = m.top.constants["ROOT_API"] + "/subscription/delete"
    notifyQuery = { claim_id: channelclaim, channel_name: channelname, notifications_disabled: "true" }
    postURLEncoded(notifyQuery, notifyURL, { "Authorization": "Bearer " + m.top.accessToken })
end function

function prenotify_new_follow(channelclaim, channelname)
    ?"Prenotifying ROOT API (/subscription/new)"
    notifyURL = m.top.constants["ROOT_API"] + "/subscription/new"
    notifyQuery = { claim_id: channelclaim, channel_name: channelname, notifications_disabled: "true" }
    postURLEncoded(notifyQuery, notifyURL, { "Authorization": "Bearer " + m.top.accessToken })
end function

function set_prefs()
    try
        '8080 sso
        '8081 sdk
        '8082 api
        m.inSync = true
        ? "RUNNING setPreferencesTask"

        'moving between # and ; in walletfiles (iOS), so replace ; with #
        'save as # by default

        if m.inSync
            ? "Step 1: Preference Get (for modification)"
            'Step 1: Preference Get (for modification)
            ? "Getting preferences(SDK)"
            allPrefs = get_prefs() 'the cool part about this is that invalid datastructures will cause it to throw an error, so we don't need to do any error handling from here except for APIs.
            rawPrefs = allPrefs["raw"]
            blocked = allPrefs["blocked"]
            following = allPrefs["following"]

            'Step 2: Get Data: Part 1
            ? "Step 2: Get Data: Part 1"
            'We need to get additional data before we can gut the existing Datastructure.
            'Search for all (valid) channels here.

            followingData = getBulkPageData(following)
            blockedData = getBulkPageData(blocked)
            'Step 3: Gut raw preferences for alteration
            ? "Step 3: Gut raw preferences for alteration"
            rawprefs["result"]["shared"]["value"]["following"].Clear() 'roArray
            rawprefs["result"]["shared"]["value"]["subscriptions"].Clear() 'roArray
            rawprefs["result"]["shared"]["value"]["blocked"].Clear() 'roArray

            'Step 4: Get additional data (p2)+create base (manipulate data)
            ? "Step 4: Get additional data (p2)+create base (manipulate data)"
            'Depending on what we need to do, we might not need to run queries at all. However, we will still have to parse followingData and blockedData at the end.
            'This ensures we have a stable base to append additional data to preferences.
            change = m.top.preferences
            ? formatJson(change)
            if m.top.changeType = "append"
                if isValid(change) and following.Count() = followingData.result.items.Count() and blocked.Count() = blockedData.result.items.Count()
                    'Append following
                    if isValid(change["following"])
                        if change["following"].Count() > 0
                            'example following JSON:
                            '"following": [
                            '    {
                            '      "notificationsDisabled": "true",
                            '      "uri": "lbry://@FrameWork:39065ea36ccf9789327aab73ea88f182c8b77bd3"
                            '    }
                            '  ]
                            'We need to grab the channels to add here as well since we need to notify Odysee about what we are going to do.
                            'Current implimentation plan is to append all results of blocked/following queries together, parse after.
                            'Optimization will be added in the future after setPreferencesTask is fixed.
                            newfollowingData = getBulkPageData(change["following"])
                            if isValid(newfollowingData.result)
                                if isValid(newfollowingdata["result"]["items"])
                                    if newfollowingdata["result"]["items"].Count() > 0 and newfollowingdata["result"]["items"].Count() <= 2
                                        for each channel in newfollowingdata["result"]["items"]
                                            followingdata["result"]["items"].Push(channel)
                                            prenotify_new_follow(channel["claim_id"], channel["name"])
                                        end for
                                    else if newfollowingdata["result"]["items"].Count() > 2
                                        for each channel in newfollowingdata["result"]["items"] 'do NOT prenotify on MASS FOLLOW.
                                            followingdata["result"]["items"].Push(channel)
                                        end for
                                    end if
                                end if
                            end if
                        end if
                    end if
                    if isValid(change["blocked"])
                        if change["blocked"].Count() > 0
                            'example blocked/subscriptions JSON:
                            '["lbry://@Chronicles_of_Bod:772a859c56a72f12284240b66a3d3bbc6fd9e1d0"]
                            'We need to grab the channels to add here as well since we need to notify Odysee about what we are going to do.
                            newblockedData = getBulkPageData(blocked)
                            ? formatJson(newBlockedData)
                            if isValid(newblockedData.result)
                                if isValid(newblockeddata["result"]["items"])
                                    if newblockeddata["result"]["items"].Count() > 0
                                        for each channel in newblockeddata["result"]["items"]
                                            blockeddata["result"]["items"].Push(channel)
                                            'put prenotification of block here: we have all the data for it already.
                                        end for
                                    end if
                                end if
                            end if
                        end if
                    end if
                end if
            else if m.top.changeType = "remove"
                ? "remove"
                if isValid(change) and following.Count() = followingData.result.items.Count() and blocked.Count() = blockedData.result.items.Count()
                    if isValid(change["following"])
                        if change["following"].Count() > 0
                            followingAA = {} 'Following Reference AA
                            for each changeItem in change["following"]
                                followingaa.addreplace(changeItem, true)
                            end for
                            for i = 0 to followingdata["result"]["items"].Count() - 1
                                if i > followingdata["result"]["items"].Count() - 1
                                    exit for
                                else
                                    if isValid(followingAA[followingdata["result"]["items"][i]["claim_id"]])
                                        channel = followingdata["result"]["items"][i]
                                        prenotify_delete_follow(channel["claim_id"], channel["name"])
                                        followingdata["result"]["items"].Delete(i)
                                        channel = invalid
                                        'put prenotification of unfollow here: we have all the data for it already.
                                    end if
                                end if
                            end for
                        end if
                        followingAA = invalid
                        frange = invalid
                    end if
                    if isValid(change["blocked"])
                        if change["blocked"].Count() > 0
                            blockedAA = {}
                            for each changeItem in change["blocked"]
                                blockedaa.addreplace(changeItem, true)
                            end for
                            for i = 0 to blockeddata["result"]["items"].Count() - 1
                                if i > blockeddata["result"]["items"].Count() - 1
                                    exit for
                                end if
                                if isValid(blockedAA[blockeddata["result"]["items"][i]["claim_id"]])
                                    blockeddata["result"]["items"].Delete(i)
                                    'put prenotification of unblock here: we have all the data for it already.
                                end if
                            end for
                            frange = invalid
                            followingAA = invalid
                        end if
                    end if
                end if
            end if
            ? formatJson(blockeddata)
            ? formatJson(followingdata)
            'rawprefs["result"]["shared"]["value"]["following"].Clear() 'roArray
            'rawprefs["result"]["shared"]["value"]["subscriptions"].Clear() 'roArray
            'rawprefs["result"]["shared"]["value"]["blocked"].Clear() 'roArray

            'example following JSON:
            '"following": [
            '    {
            '      "notificationsDisabled": "true",
            '      "uri": "lbry://@FrameWork:39065ea36ccf9789327aab73ea88f182c8b77bd3"
            '    }
            '  ]
            'example blocked/subscriptions JSON:
            '["lbry://@Chronicles_of_Bod:772a859c56a72f12284240b66a3d3bbc6fd9e1d0"]

            'Step 5: Create preferences from data.
            ?"Step 5: Create preferences from data."
            for each claim in followingdata["result"]["items"]
                rawprefs["result"]["shared"]["value"]["following"].Push({ "notificationsDisabled": "true", "uri": claim["permanent_url"].replace("#", ":") })
                rawprefs["result"]["shared"]["value"]["subscriptions"].Push(claim["permanent_url"].replace("#", ":"))
            end for
            for each claim in blockedData["result"]["items"]
                rawprefs["result"]["shared"]["value"]["blocked"].Push(claim["permanent_url"].replace("#", ":"))
            end for

            sdkSyncHash = postJSON(formatJson({ "jsonrpc": "2.0", "method": "sync_hash", "params": {}, "id": m.top.uid }), m.top.constants["ROOT_SDK"]+"/api/v1/proxy", { "Authorization": "Bearer " + m.top.accessToken })
            ? formatJSON(sdkSyncHash)
            if isValid(sdkSyncHash.result)
                if sdkSyncHash.result <> ""
                    oldHash = sdkSyncHash.result
                    ? "got SDK hash"
                else
                    oldHash = "0"
                    ? "no hash from SDK (NEW!)"
                end if
            end if

            'Step 6: preference_set (set what we altered)
            ?"Step 6: preference_set (set what we altered) TO SDK"
            preferences = postJSON(formatJson({ "jsonrpc": "2.0", "method": "preference_set", "params": { "key": "shared", "value": formatJson(rawprefs["result"]["shared"]) }, "id": m.top.uid }), m.top.constants["ROOT_SDK"] + "/api/v1/proxy", { "Authorization": "Bearer " + m.top.accessToken })
            ?FormatJson(preferences)
            if isValid(preferences.result) = false
                needs_resync = true
            end if
            ? formatJson(preferences)

            'Step 7: Sync Apply (to SDK)
            ?"Step 7: Sync Apply (to SDK)"
            syncapply = postJSON(formatJson({ "jsonrpc": "2.0", "method": "sync_apply", "params": { "password": "": "blocking": true }, "id": m.top.uid }), m.top.constants["ROOT_SDK"] + "/api/v1/proxy", { "Authorization": "Bearer " + m.top.accessToken })
            ?FormatJson(syncapply)
            if isValid(syncapply.data)
                if isValid(syncapply.data.data) and isValid(syncapply.data.hash)
                    m.top.walletData = syncapply.result.data
                end if
            end if
            ? formatJson(syncapply)
            'Step 8: Sync Set (to API)
            ?"Step 8: Sync Set (to API)"
            syncset = postURLEncoded({ old_hash: oldHash, new_hash: "" + syncapply.result.hash: data: "" + syncapply.result.data }, m.top.constants["ROOT_API"] + "/sync/set", { "Authorization": "Bearer " + m.top.accessToken })
            ?formatJson(syncset)
            if syncset.success = true
                ?"Successfully synchronized data"
                m.inSync = true
            else
                ?"Failed to sync data (APIs do NOT MATCH)"
                m.top.error = true
                m.inSync = false
                m.top.syncTimer.control = "stop"
            end if
            if m.top.error = true
                return 2
            else
                return 1
            end if
        end if
    catch e
        m.top.error = true
    end try
end function

function getBulkPageData(claimIDs)
    ? "GETTING BULK DATA: STAGE 0: INIT" 
    try
        emptyData = {
            "id": 0,
            "jsonrpc": "2.0",
            "result": {
                "blocked": {
                    "channels": [],
                    "total": 0
                },
                "items": [],
                "page": 1,
                "page_size": 0,
                "total_items": 0,
                "total_pages": 0
            }
        }
        if claimIDs.Count() = 0
            return emptyData
        end if
        claimSearchURL = m.top.constants["QUERY_API"] + "/api/v1/proxy?m=claim_search"
        if claimIDs.Count() > 45
            if claimIDs.Count() <= 2047
                dataQueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": 45, "order_by": "release_time", "fee_amount": "<=0", "claim_type": ["channel"], "any_tags": [], "claim_ids": claimIDs, "include_purchase_receipt": false, "include_is_my_output": false, "include_sent_supports": false, "include_sent_tips": false, "include_received_tips": false }, "id": m.top.uid })
                bulkData = postJSON(dataQueryJSON, claimSearchURL, invalid)
                totalDataPages = bulkData["result"]["total_pages"]
                if totalDataPages > 1
                    for curPage = 2 to totalDataPages
                        dataQueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": 45, "order_by": "release_time", "page": curPage, "fee_amount": "<=0", "claim_type": ["channel"], "any_tags": [], "claim_ids": claimIDs, "include_purchase_receipt": false, "include_is_my_output": false, "include_sent_supports": false, "include_sent_tips": false, "include_received_tips": false }, "id": m.top.uid })
                        dataQueryPage = postJSON(dataQueryJSON, claimSearchURL, invalid)
                        bulkData["result"]["items"].Append(dataQueryPage["result"]["items"])
                    end for
                end if
            else
                'TODO: FIX PREFS >2048
                THROW "over2047" 'FOR NOW: DIE.
            end if
        else
            dataQueryJSON = FormatJson({ "jsonrpc": "2.0", "method": "claim_search", "params": { "page_size": claimIDs.Count(), "fee_amount": "<=0", "claim_type": ["channel"], "no_totals": true, "any_tags": [], "claim_ids": claimIDs, "include_purchase_receipt": false, "include_is_my_output": false, "include_sent_supports": false, "include_sent_tips": false, "include_received_tips": false }, "id": m.top.uid })
            bulkData = postJSON(dataQueryJSON, claimSearchURL, invalid)
        end if
        return bulkData
    catch e
        m.top.error = true
        throw e["message"]
    end try
end function