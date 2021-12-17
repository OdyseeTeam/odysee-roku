sub Init()
    m.top.functionName = "master"
end sub

sub master()
    ? "Running Sync Loop"
    m.syncTimer = m.top.findNode("syncTimer") 'refresh timer
    if m.syncTimer.control <> "start"
        m.syncTimer.control = "start"
    end if
    if isValid(m.top.accessToken)
        if Type(m.top.accessToken) = "roString"
            if m.top.accessToken <> ""
                '8080 sso
                '8081 sdk
                '8082 api
                '8086 OdyGetWalletData Custom API
                ? m.top.constants
                userData = getJSON(m.top.constants["ROOT_API"]+"/user/me", { "Authorization": "Bearer " + m.top.accessToken })
                if isValid(userData.data)
                    m.top.uid = userData.data.id
                end if
                synchash = postJSON(formatJson({ "jsonrpc": "2.0", "method": "sync_hash", "params": {}, "id": m.top.uid }), m.top.constants["ROOT_SDK"]+"/api/v1/proxy", { "Authorization": "Bearer " + m.top.accessToken })
                ? formatJSON(synchash)
                if isValid(synchash.result)
                    if synchash.result <> ""
                        m.top.newHash = synchash.result
                    end if
                end if
                walletfull = getJSON(m.top.constants["ROOT_API"]+"/sync/get?hash=" + m.top.newHash, { "Authorization": "Bearer " + m.top.accessToken })
                if walletfull.success = true
                    if isValid(walletfull.data)
                        if isValid(walletfull.data.hash) and isValid(walletfull.data.data)
                            if walletfull.data.changed = true
                                m.top.inSync = false
                                m.top.oldHash = walletfull.data.hash
                                m.top.walletData = walletfull.data.data
                                m.top.syncState = 1
                            else
                                m.top.inSync = true
                                m.top.newHash = walletfull.data.hash
                                m.top.walletData = walletfull.data.data
                                if m.top.syncState = 3
                                    m.top.syncState = 4 'wait until second sync call (when we are SURE its already written to SDK)
                                else
                                    m.top.syncState = 2
                                end if
                            end if
                        end if
                    end if
                end if
                if m.top.inSync = false
                    syncapply = postJSON(formatJson({ "jsonrpc": "2.0", "method": "sync_apply", "params": { "password": "", "data": m.top.walletData, "blocking": true }, "id": m.top.uid }), m.top.constants["ROOT_SDK"]+"/api/v1/proxy", { "Authorization": "Bearer " + m.top.accessToken })
                    if isValid(syncapply.data)
                        if isValid(syncapply.data.data) and isValid(syncapply.data.hash)
                            if syncapply.data.hash = m.top.newHash
                                ? "sync apply successful"
                            end if
                        end if
                    end if
                    syncset = postURLEncoded({ old_hash: m.top.oldHash: new_hash: m.top.newHash: data: m.top.walletData }, m.top.constants["ROOT_API"]+"/sync/set", { "Authorization": "Bearer " + m.top.accessToken })
                    ? formatJson(syncset)
                    if syncset.success = true
                        ? "Successfully synchronized data"
                        m.top.syncState = 3
                        m.top.inSync = true
                    end if
                end if
            end if
        end if
    end if
    ? m.top.inSync
    ? "Loop done."
end sub

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