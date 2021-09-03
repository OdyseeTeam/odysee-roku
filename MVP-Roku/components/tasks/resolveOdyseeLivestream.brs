Sub Init()
    m.top.functionName = "master"
End Sub

sub master()
    '? m.top.constants
    '? m.top.cookies
    '? m.top.uid
    '? m.top.authtoken
    '? m.top.channels
    '? m.top.rawname
    m.top.output = resolve(m.top.channel)
    m.top.resolveAttempts = 0
End Sub

Function resolve(channelid)
    if m.top.resolveAttempts < 5
        'https://api.live.odysee.com/v1/odysee/live/
        livestreamStatus = getJSON(m.top.constants["LIVE_API"]+"/"+channelid)
        if isValid(livestreamStatus)
            if isValid(livestreamStatus["data"])
            livestreamData = livestreamStatus["data"]
            if livestreamData.live = false
                success = false
                return {success: success}
            else
                success = true
                mediaindex={}
                result=[]
                '*data
                 '*claimData
                  '*_name (@theghost)
                  '*canonicalUrl (lbry://@TheGhost#6)
                  '*channelLink (https://odysee.com/@TheGhost#6)
                  '*name (@TheGhost)
                  '*shortUrl (lbry://@TheGhost#6)
                 '*claimId (67a9f39ce17e376ff388b676836ee038dbe24a25)
                 '*live (true)
                 '*thumbnail (https://cdn.odysee.live/preview/67a9f39ce17e376ff388b676836ee038dbe24a25.jpg)
                 '*timestamp (2021-08-07T10:23:32.993Z)
                 '*type (application/x-mpegurl)
                 '*url (https://cdn.odysee.live/hls/67a9f39ce17e376ff388b676836ee038dbe24a25/index.m3u8)
                 '*viewCount (0) (deprecated, do not use)
                '*message (success)
                '*success (true)
                item = {}
                queryURL = m.top.constants["QUERY_API"]+"/api/v1/proxy?m=claim_search"
                queryJSON = FormatJson({"jsonrpc":"2.0","method":"claim_search","params":{"page_size":1,"claim_type":"stream","no_totals":true,"any_tags":[],"not_tags":["porn","porno","nsfw","mature","xxx","sex","creampie","blowjob","handjob","vagina","boobs","big boobs","big dick","pussy","cumshot","anal","hard fucking","ass","fuck","hentai"],"channel_ids":[livestreamData["claimId"]],"not_channel_ids":[],"order_by":["release_time"],"has_no_source":true,"include_purchase_receipt":false, "has_channel_signature":true,"valid_channel_signature":true, "has_source": false},"id":m.top.uid})
                livestreamQuery = postJSON(queryJSON, queryURL, invalid)
                if m.global.debug
                    ? "[resolveOdyseeLivestream]: GOT:"
                    ? FormatJson(livestreamQuery)
                    ? "[resolveOdyseeLivestream]"
                end if
                retries = 0
                while true
                    if IsValid(livestreamQuery.error)
                        livestreamQuery = postJSON(queryJSON, queryURL, invalid)
                        retries+=1
                    else
                        exit while
                    end if
                    if retries > 5
                        STOP
                    end if
                end while
                item.Title = livestreamQuery.result.items[0].value.title
                item.Creator = livestreamData["claimData"].name
                item.Description = livestreamQuery.result.items[0].value.title
                item.Channel = livestreamData["claimId"]
                item.lbc = livestreamQuery.result.items[0].meta.effective_amount+" LBC"
                time = CreateObject("roDateTime")
                time.FromISO8601String(livestreamData["timestamp"])
                timestr = time.AsDateString("short-month-short-weekday")+" "
                timestr = timestr.Trim()
                timeint = time.AsSeconds()
                time = Invalid
                item.ReleaseDate = timestr
                item.guid = livestreamQuery.result.items[0].claim_id
                thumbnail = m.global.constants.imageProcessor+livestreamQuery.result.items[0].value.thumbnail.url
                item.HDPosterURL = thumbnail
                item.thumbnailDimensions = [360, 240]
                'unneeded as we directly recieve the URL from the page
                item.url = livestreamData["url"]
                item.stream = {url : item.url}
                item.link = item.url
                item.streamFormat = "hls"
                item.source = "odysee"
                item.itemType = "livestream"

                currow = createObject("RoSGNode","ContentNode")
                curitem = createObject("RoSGNode","ContentNode")
                curitem.addFields({creator: "", thumbnailDimensions: [], itemType: "", lbc: "", Channel: "", guid: ""}) 'added GUID so we can pass it to chat
                curitem.setFields(item)
                currow.appendChild(curitem)

                result.push(item) 
                mediaindex[item.guid] = item
                return {success:success:outputrow:currow}
            end if
        else
            m.top.resolveAttempts+=1
            resolve(m.top.channel)
        end if
    else
        m.top.resolveAttempts+=1
        resolve(m.top.channel)
    end if
else
    success = false
    return {success: success}
end if
End Function