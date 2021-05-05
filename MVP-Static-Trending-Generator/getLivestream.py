import json
import math
import os.path
import re
import sys
import time
import urllib
import requests


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
channelid = "45e55a50627305311479123e0fec171e16a0cd0f" #24x7 viking radio
channelquery = str({"jsonrpc":"2.0","method":"claim_search","params":{"page": 1,"page_size":20,"no_totals":True,"any_tags":[],"channel_ids":[channelid],"not_channel_ids":[],"order_by":["trending_group","trending_mixed"],"fee_amount":"<=0","include_purchase_receipt":True},"id":uid}).replace("True", "true").replace("'",'"')
livestream = json.loads(requests.post("https://api.lbry.tv/api/v1/proxy", data = channelquery).content)["result"]["items"][1]
try:
    livestream["value"]["source"]
except:
    livestreamID = livestream["claim_id"]
print(livestreamID)