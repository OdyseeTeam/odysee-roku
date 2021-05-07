import requests
import json
import time
import math
import re
import os.path
import sys
import urllib
from numerize import numerize

#Static Trending Generator
#William Foster/S9260/CaffinatedCoder 2021

numitems = 80
numpages = math.ceil((numitems) / 30)

def writeconfiguration(filename, configuration):
    file = open(filename, 'w')
    file.seek(0)
    file.write(json.dumps(configuration))
    file.truncate()

def readconfiguration(filename):
    try:
        file = open(filename, "r+")
        configuration = json.loads(file.read())
        return(configuration)
    except:
        writeconfiguration(filename, [])
        return([])

def find_subvar(input, varname):
    start = content.find(varname+' =') #https://stackoverflow.com/a/18368449
    end = content.find(';', start)
    subvars = []
    #print(start, end)
    subvar = content[start:end].strip().replace(varname+' =',"").replace(" ", "").replace("'", "").replace(",","").split("\n") #manipulate our found subvariable by removing all excess chars+definitions and splitting by newline
    subvar.pop() #removes variable definition at beginning
    subvar.pop(0) #removes "]" at end
    for var in subvar:
        if "//" in var:
            subvars.append(var.split("//")[0])
        else:
            subvars.append(var)
    return(subvars)

def create_account():
    rawquery = requests.get("https://api.lbry.com/user/new")
    rawjson = rawquery.text
    rawaccount = json.loads(rawjson)
    formattedaccount = [rawaccount["data"]["id"], rawaccount["data"]["auth_token"]]
    return(formattedaccount)

def check_account(authtoken):
    rawaccount = json.loads(requests.get("https://api.lbry.com/user/me?auth_token="+authtoken).text)
    try:
        rawaccount.success
        return True
    except:
        return False

account = readconfiguration("./account.json")
if account == []:
    print("no account, creating")
    account = create_account()
    print(account)
    writeconfiguration("./account.json", account)
else:
    if not check_account(account[1]):
        account = create_account()
        writeconfiguration("./account.json", account)
uid = account[0]
authtoken = account[1]


for s in requests.get("https://odysee.com/").text.split('\n'):
    if "script" in s and "async" in s and "public" in s: #todo: add domain check to make sure only odysee.com is in this string
        for i in s.split('"'):
            if "js" in i:
                mapurl = "https://odysee.com"+i+".map"

sourcesContent = json.loads(requests.get(mapurl).content)['sourcesContent']
content = ""
for line in sourcesContent:
    content = content + line

cids = {}
queries = {}
output = {}
cids["PRIMARY_CONTENT_CHANNEL_IDS"] = find_subvar(content, "PRIMARY_CONTENT_CHANNEL_IDS")
cids["CHEESE_CHANNEL_IDS"] = find_subvar(content, "CHEESE_CHANNEL_IDS")
cids["BIG_HITS_CHANNEL_IDS"] = find_subvar(content, "BIG_HITS_CHANNEL_IDS")
cids["GAMING_CHANNEL_IDS"] = find_subvar(content, "GAMING_CHANNEL_IDS")
cids["SCIENCE_CHANNEL_IDS"] = find_subvar(content, "SCIENCE_CHANNEL_IDS")
cids["TECHNOLOGY_CHANNEL_IDS"] = find_subvar(content, "TECHNOLOGY_CHANNEL_IDS")
cids["NEWS_CHANNEL_IDS"] = find_subvar(content, "NEWS_CHANNEL_IDS")
cids["FINANCE_CHANNEL_IDS"] = find_subvar(content, "FINANCE_CHANNEL_IDS")
cids["THE_UNIVERSE_CHANNEL_IDS"] = find_subvar(content, "THE_UNIVERSE_CHANNEL_IDS")
cids["COMMUNITY_CHANNEL_IDS"] = find_subvar(content, "RABBIT_HOLE_CHANNEL_IDS") #tempfix

print(cids)
qexp = ">"+str(round(time.time())-7776000)
print("number of pages:", numpages)
unfilteredfeed = {}
masterfeed = {}
for key in cids:
    masterfeed[key] = []
    for pagenum in range(numpages):
        print("current page number is", pagenum+1, "for key", key)
        queries[key] = str({"jsonrpc":"2.0","method":"claim_search","params":{"page": pagenum+1,"page_size":numitems,"claim_type":["stream","channel"],"no_totals":True,"any_tags":[],"not_tags":["porn","porno","nsfw","mature","xxx","sex","creampie","blowjob","handjob","vagina","boobs","big boobs","big dick","pussy","cumshot","anal","hard fucking","ass","fuck","hentai"],"channel_ids":cids[key],"not_channel_ids":[],"order_by":["trending_group","trending_mixed"],"stream_types":["video"],"release_time":qexp,"fee_amount":"<=0","limit_claims_per_channel":1,"include_purchase_receipt":True},"id":uid}).replace("True", "true").replace("'",'"')
        subfeed = json.loads(requests.post("https://api.lbry.tv/api/v1/proxy", data = queries[key]).text)
        masterfeed[key].extend(subfeed['result']['items'])
        #print(masterfeed[key])
for key in masterfeed:
    numkeyentries = 0
    master = masterfeed[key]
    entries = []
    for item in master:
        validitem = type(re.search('[^\x1F-\x7F]+', item['normalized_name'])).__name__ == "NoneType"
        if numkeyentries < numitems and validitem:
            validvideo = True
            try: item['value']['source']['hash']
            except: validvideo = False
            try: item['value']['source']['sd_hash']
            except: validvideo = False
            if validvideo:
                try: 
                    channelname = item['signing_channel']['value']['title']
                    channelid = item['signing_channel']['claim_id']
                except:
                    try:
                        channelname = item['signing_channel']['value']['channel_id']
                        channelid = item['signing_channel']['claim_id']
                    except:
                        channelname = "Anonymous"
                        channelid = ""
                try: title = item['value']['title']
                except: title = "Unnamed Video"

                #try: description = item['value']['description']
                #except: description = " "
                description = ""
                
                try:
                    if "spee.ch" in item['value']['thumbnail']['url']:
                            thumburl = item['value']['thumbnail']['url']+"?quality=1&height=220&width=390"
                    else:
                            thumburl = "https://image-optimizer.vanwanet.com/?address="+item['value']['thumbnail']['url']+"?quality=1&height=220&width=390"
                except:
                    thumbnail = "pkg:\\images\\odyseeoops.png"
                #https://api.lbry.com/file/view_count?auth_token=TOKEN&claim_id=CID
                viewcount = numerize.numerize(json.loads(requests.get("https://api.lbry.com/file/view_count?auth_token="+authtoken+"&claim_id="+item['claim_id']).text)["data"][0],2)
                entries.append([title, channelname, description, time.strftime('%a %b %e, %Y', time.localtime(item['timestamp'])), item['claim_id'], thumburl, "https://cdn.lbryplayer.xyz/api/v3/streams/free/"+item['normalized_name']+"/"+item['claim_id']+"/"+item['value']['source']['hash'][:6],"https://cdn.lbryplayer.xyz/api/v3/streams/free/"+item['normalized_name']+"/"+item['claim_id']+"/"+item['value']['source']['sd_hash'][:6], viewcount, channelid])
                numkeyentries+=1
        #standard: name, desc, pubdate, id, thumb, url
        #Temporary Redirect Fix: Vanwanet doesn't redirect properly.
    print(key,"key entries:",numkeyentries)
    output[key.replace("_CHANNEL_IDS","")] = entries

    #ROKU:
    ####if isValid(claim.value.title) AND isValid(claim.normalized_name) AND isValid(claim.claim_id) AND isValid(claim.value.source.hash) AND isValid(claim.signing_channel.value) OR isValid(claim.value.title) AND isValid(claim.normalized_name) AND isValid(claim.claim_id) AND isValid(claim.value.source.hash) AND isValid(claim.signing_channel.channel_id)
    ####        item.Title = claim.value.title
    ####        item.ReleaseDate = claim.timestamp
    ####        if not isValid(claim.value.description)
    ####            claim.value.description = "NODESC"
    ####        end if
    ####        if isValid(claim.signing_channel.value) AND isValid(claim.value.description)
    ####            item.DESCRIPTION = claim.value.description+"|ENDSPLITTER|"+claim.signing_channel.value.title
    ####        else if isValid(claim.signing_channel.channel_id)
    ####            item.DESCRIPTION = claim.value.description+"|ENDSPLITTER|ID"+claim.signing_channel.channel_id
    ####        end if
    ####        item.url = "https://cdn.lbryplayer.xyz/api/v3/streams/free/"+claim.normalized_name+"/"+claim.claim_id+"/"+claim.value.source.hash.left(6)
    ####        item.stream = {url : item.url}
    ####        item.streamFormat = "mp4"
    ####        item.HDPosterURL = thumbnail
    ####        item.HDBackgroundImageUrl = thumbnail 'placeholder; get icon for user soon
    ####        item.link = item.url
    ####        item.source = "lbry"
    ####        item.guid = claim.claim_id
    ####        result.push(item)
    ####        mediaindex[item.guid] = item
    ####    end if

#for key in output:
#    print("\n")
#    print(key, "VIDEOS:\n")
#    for video in output[key]:
#        print(video[0])

writeconfiguration('./out/trending.json', output)