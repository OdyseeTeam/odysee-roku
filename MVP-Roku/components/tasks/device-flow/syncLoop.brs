sub Init()
    m.top.functionName = "master"
end sub

sub master()
    ? "Running Sync Loop"
    m.syncTimer = m.top.findNode("syncTimer") 'refresh timer
    if m.syncTimer.control <> "start"
        m.syncTimer.control = "start"
    end if
    try
        if isValid(m.top.accessToken)
            if Type(m.top.accessToken) = "roString"
                ? m.top.accessToken
                if m.top.accessToken <> ""
                    sdkHash = ""
                    prodHash = ""
                    sdkWallet = ""
                    prodWalletData = ""
                    inSync = false

                    userData = getJSONAuthenticated(m.top.constants["ROOT_API"] + "/user/me", { "Authorization": "Bearer " + m.top.accessToken })
                    if isValid(userData.error)
                        THROW "USER"
                    end if

                    if isValid(userData.data)
                        m.top.uid = userData.data.id
                    end if

                    sdkSyncHash = postJSON(formatJson({ "jsonrpc": "2.0", "method": "sync_hash", "params": {}, "id": m.top.uid }), m.top.constants["ROOT_SDK"] + "/api/v1/proxy", { "Authorization": "Bearer " + m.top.accessToken })
                    ? formatJSON(sdkSyncHash)
                    if isValid(sdkSyncHash.error)
                        THROW "SYNC_HASH"
                    end if
                    if isValid(sdkSyncHash.result)
                        if sdkSyncHash.result <> ""
                            sdkHash = sdkSyncHash.result
                            ? "got SDK hash"
                        else
                            sdkHash = "0"
                            ? "no hash from SDK (NEW!)"
                        end if
                    end if

                    prodWallet = getJSONAuthenticated(m.top.constants["ROOT_API"] + "/sync/get?hash=" + sdkHash, { "Authorization": "Bearer " + m.top.accessToken })
                    if isValid(prodWallet.error)
                        THROW "SYNC_GET"
                    end if
                    if prodWallet.success = true
                        if isValid(prodWallet.data)
                            if isValid(prodWallet.data.hash) and isValid(prodWallet.data.changed)
                                prodHash = prodWallet.data.hash
                                prodWalletChanged = prodWallet.data.changed
                                if prodWalletChanged = true
                                    ? "Production changed"
                                    ? FormatJson(prodWallet)
                                    inSync = false
                                    m.top.walletData = prodWallet.data.data
                                    prodWalletData = prodWallet.data.data
                                else if prodWalletData = "" and m.top.walletData <> ""
                                    sdkSyncApply = postJSON(formatJson({ "jsonrpc": "2.0", "method": "sync_apply", "params": { "password": "", "blocking": true }, "id": m.top.uid }), m.top.constants["ROOT_SDK"] + "/api/v1/proxy", { "Authorization": "Bearer " + m.top.accessToken })
                                    if isValid(sdkSyncApply.error)
                                        THROW "SYNC_APPLY_SDK_EMPTY_DATA"
                                    end if
                                    prodWalletData = sdksyncapply["result"]["data"]
                                    m.top.walletData = prodWallet.data.data
                                    ? "No change on Production"
                                    inSync = true
                                else
                                    inSync = true
                                end if
                            end if
                        end if
                    end if

                    ? sdkHash
                    ? prodHash

                    if sdkHash <> prodHash or inSync = false
                        sdkSyncApply = postJSON(formatJson({ "jsonrpc": "2.0", "method": "sync_apply", "params": { "password": "", "data": prodWalletData, "blocking": true }, "id": m.top.uid }), m.top.constants["ROOT_SDK"] + "/api/v1/proxy", { "Authorization": "Bearer " + m.top.accessToken })
                        ? formatJson(sdkSyncApply)
                        if isValid(sdkSyncApply.error)
                            THROW "SYNC_APPLY_SDK_NO_SYNC"
                        end if
                        if isValid(sdkSyncApply.result)
                            if isValid(sdkSyncApply.result.data) and isValid(sdkSyncApply.result.hash)
                                sdkHash = sdkSyncApply.result.hash
                                sdkWallet = sdkSyncApply.result.data
                                if sdkSyncApply.result.hash = prodHash
                                    ? "sync apply successful"
                                    inSync = true
                                else
                                    ? "sync apply failed"
                                    inSync = false
                                end if
                            end if
                        end if
                        ? "Sync Loop Sync Set"
                        syncset = postURLEncoded({ old_hash: prodHash: new_hash: sdkHash: data: sdkWallet }, m.top.constants["ROOT_API"] + "/sync/set", { "Authorization": "Bearer " + m.top.accessToken })
                        if isValid(syncset.error)
                            THROW "SYNC_SET_API"
                        end if
                        ?formatJson(syncset)
                        if syncset.success = true
                            m.top.inSync = true
                        end if
                    else
                        ? "currently in sync (wallet-wise)"
                        if m.top.oldHash <> prodHash
                            ? "change between production+current"
                            m.top.preferencesChanged = true
                        else
                            m.top.preferencesChanged = false
                        end if
                    end if
                end if
            end if
        end if
        if isValid(sdkHash) and isValid(prodHash) and isValid(inSync)
            m.top.oldHash = prodHash
            m.top.inSync = inSync
        end if
    catch e
        m.top.error = true
    end try
    sdkHash = invalid
    prodHash = invalid
    sdkWallet = invalid
    prodWalletData = invalid
    ? "Loop done."
end sub