import requests
import json
import re

def find_subvar(input, varname):
    start = content.find(varname+' =') #https://stackoverflow.com/a/18368449
    end = content.find(';', start)
    print(start, end)
    subvar = content[start:end].strip().replace(varname+' =',"").replace(" ", "").replace("'", "").replace(",","").split("\n") #manipulate our found subvariable by removing all excess chars+definitions and splitting by newline
    subvar.pop() #removes variable definition at beginning
    subvar.pop(0) #removes "]" at end
    return(subvar)

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

cids["PRIMARY_CONTENT_CHANNEL_IDS"] = find_subvar(content, "PRIMARY_CONTENT_CHANNEL_IDS")
cids["CHEESE_CHANNEL_IDS"] = find_subvar(content, "CHEESE_CHANNEL_IDS")
cids["BIG_HITS_CHANNEL_IDS"] = find_subvar(content, "BIG_HITS_CHANNEL_IDS")
cids["GAMING_CHANNEL_IDS"] = find_subvar(content, "GAMING_CHANNEL_IDS")
cids["SCIENCE_CHANNEL_IDS"] = find_subvar(content, "SCIENCE_CHANNEL_IDS")
cids["TECHNOLOGY_CHANNEL_IDS"] = find_subvar(content, "TECHNOLOGY_CHANNEL_IDS")
cids["NEWS_CHANNEL_IDS"] = find_subvar(content, "NEWS_CHANNEL_IDS")
cids["FINANCE_CHANNEL_IDS"] = find_subvar(content, "FINANCE_CHANNEL_IDS")
cids["THE_UNIVERSE_CHANNEL_IDS"] = find_subvar(content, "THE_UNIVERSE_CHANNEL_IDS")
cids["COMMUNITY_CHANNEL_IDS"] = find_subvar(content, "COMMUNITY_CHANNEL_IDS")

print(cids)