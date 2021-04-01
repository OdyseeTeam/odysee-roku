' LBRY Lighthouse (Search function)

'lighthouse(m.top.input.claimType, m.top.input.mediaType, m.top.input.size, m.top.input.from, m.top.input.query)
Function lighthouse(claimtype, mediatype, size, from, expiration, query)
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
      final_output = ManufactureSearchFeed({"jsonrpc":"2.0","method":"claim_search","params":{"page_size":size,"claim_type":["stream","channel"],"no_totals":true,"any_tags":[],"not_tags":["porn","porno","nsfw","mature","xxx","sex","creampie","blowjob","handjob","vagina","boobs","big boobs","big dick","pussy","cumshot","anal","hard fucking","ass","fuck","hentai"],"claim_ids":ids,"not_channel_ids":[],"order_by":["trending_group","trending_mixed"],"stream_types":["video"],"release_time":expiration,"fee_amount":"<=0","limit_claims_per_channel":1,"include_purchase_receipt":true},"id":m.top.uid})
      return final_output
    end if
  else
    ? "The API isn't responding correctly, we must have done something wrong."
    ? input
    STOP 'stop for debug
  end if
End Function
