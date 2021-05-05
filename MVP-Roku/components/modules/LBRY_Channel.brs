Function getSubs(channel)
    response = GetURLEncoded("https://api.lbry.com/subscription/sub_count", {auth_token: m.top.authtoken, claim_id: channel})
    if IsValid(response.data)
      return response.data[0]
    else
      ? "The API isn't responding correctly, we must have done something wrong."
      ? response
      ? response.error
      'STOP 'stop for debug
    end if
End Function

'{"jsonrpc":"2.0","method":"resolve","params":{"urls":["lbry://@ItsAGundam#8"],"include_purchase_receipt":true,"include_is_my_output":true},"id":1617909341960}

Function getChannelMetadata(channel)
'? "Resolving claimID", channel
r = CreateObject("roRegex", "[^\x1F-\x7F]+", "")
response = QueryLBRYAPI({jsonrpc:"2.0",method:"claim_search",params:{claim_type:["channel"], claim_ids: [channel]},id: m.top.uid})
if isValid(response)
    if IsValid(response.result) AND IsValid(response.result.items[0])
        if isValid(response.result.items[0].value.thumbnail)
            channelthumb = response.result.items[0].value.thumbnail.url
        else
            channelthumb = "pkg:\images\odysee_oops.png"
        end if
        if isValid(response.result.items[0].name)
            username = response.result.items[0].name
        else
            username = "Anonymous"
        end if
        if isValid(response.result.items[0].value.title)
            title = r.ReplaceAll(response.result.items[0].value.title, "").trim()
        else
            title = username.replace("@", "").trim()
        end if
        ? title
        r = invalid
        return {id: channel, username: username, realname: title, subs: getSubs(channel), thumbnail: channelthumb, invalidchannel: false}
    else if isValid(response.error)
      ? "The API isn't responding correctly, we must have done something wrong."
      ? response
      ? response.error
      STOP 'stop for debug
    else
      ? "Invalid channel. Skipping!"
      return {invalidchannel: true}
    end if
else
    ? "Invalid channel. Skipping!"
    return {invalidchannel: true}
end if
End Function