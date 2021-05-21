' LBRY Lighthouse (Search function)

'lighthouse(m.top.input.claimType, m.top.input.mediaType, m.top.input.size, m.top.input.from, m.top.input.query)
Function lighthouse_videos(claimtype, mediatype, size, from, expiration, query)
  ? "in lighthouse"
  input = GetURLEncoded("https://lighthouse.lbry.com/search", {s: query, claimType: claimtype, mediaType: mediatype, size: Str(size).Trim(), from: Str(from).Trim(), free_only: "true", nsfw: "false"})
  if Type(input) = "roArray"
    if input.Count() < 1
      ? "No results."
      return {noresults: True}
    else
      ids = []
      for each key in input
        ? "getting a claimId"
        ids.Push(key.claimId)
      end for
      ? "creating final output"
      final_output = ManufactureQueryFeed({"jsonrpc":"2.0","method":"claim_search","params":{"page_size":size,"claim_type":["stream","channel"],"no_totals":true,"any_tags":[],"not_tags":["porn","porno","nsfw","mature","xxx","sex","creampie","blowjob","handjob","vagina","boobs","big boobs","big dick","pussy","cumshot","anal","hard fucking","ass","fuck","hentai"],"claim_ids":ids,"not_channel_ids":[],"order_by":["trending_group","trending_mixed"],"stream_types":["video"],"release_time":expiration,"fee_amount":"<=0","limit_claims_per_channel":1,"include_purchase_receipt":true},"id":m.top.uid})
      return final_output
    end if
  else
    ? "The API isn't responding correctly, we must have done something wrong."
    ? input
    'STOP 'stop for debug
  end if
End Function

Function lighthouse_videos_placeholder(amount)
    final_output = ManufacturePlaceholderVideoGrid(amount)
    return final_output
End Function

Function lighthouse_channels_placeholder(amount)
    final_output = ManufacturePlaceholderChannelGrid(amount)
    return final_output
End Function

Function lighthouse_channels(claimtype, size, from, query)
  ? "in lighthouse"
  input = GetURLEncoded("https://lighthouse.lbry.com/search", {s: query, claimType: "channel", size: Str(size).Trim(), from: Str(from).Trim(), sort_by: "effective_amount", nsfw: "false", free_only: "true"})
  if Type(input) = "roArray"
    if input.Count() < 1
      ? "No results."
      return {noresults: True}
    else
      channelusers = []
      claimids = []
      final_output = {}
      for each key in input
        claimids.push(key.claimId)
      end for
      claimids = unique(claimids)
      for each claim in claimids
        '? "getting a channel ID"
        '? "getting channel", claim
        'for some reason, this runs much faster w/o debug
        'if you need it, uncomment what's above.
        meta = getChannelMetadata(claim)
        if meta.invalidchannel = false
          channelusers.Push(meta)
        end if
        channelthumb = invalid
        meta = invalid
        resolvedchannel = invalid
      end for
      ? "creating final output"
      final_output = ManufactureChannelGrid(channelusers)
      return final_output
    end if
  else
    ? "The API isn't responding correctly, we must have done something wrong."
    ? input
    'STOP 'stop for debug
  end if
End Function

Function lighthouse_channel(channel, expiration)
final_output = ManufactureQueryFeed({"jsonrpc":"2.0","method":"claim_search","params":{"channel_ids":[channel],"page_size":20,"claim_type":["stream","channel"],"no_totals":true,"any_tags":[],"not_tags":["porn","porno","nsfw","mature","xxx","sex","creampie","blowjob","handjob","vagina","boobs","big boobs","big dick","pussy","cumshot","anal","hard fucking","ass","fuck","hentai"],"not_channel_ids":[],"order_by":["trending_group","trending_mixed"],"stream_types":["video"],"release_time":expiration,"fee_amount":"<=0","include_purchase_receipt":true},"id":m.top.uid})
return final_output
End Function

function unique(arr as Object) 'https://stackoverflow.com/questions/58183023/remove-duplicate-string-and-display-unique-string-in-roku
  res = []
  table = {}
  for each v in arr
    k = v.toStr()
    if not table.doesExist(k)
      res.push(v)
      table[k] = true
    end if
  end for
  return res
end function