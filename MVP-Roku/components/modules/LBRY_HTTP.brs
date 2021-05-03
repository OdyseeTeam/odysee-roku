'All HTTP query functions for LBRY (getrawtext, querylbry*)

function QueryLBRYAPI(json) as Object
  http = CreateObject("roUrlTransfer")
  messagePort = CreateObject("roMessagePort")
  http.RetainBodyOnError(true)
  http.SetPort(messagePort)
  http.setCertificatesFile("common:/certs/ca-bundle.crt")
  http.InitClientCertificates()
  http.EnableCookies()
  http.AddCookies(m.top.cookies)
  'https://api.lbry.tv/api/v1/proxy?m=claim_search
  http.SetUrl("https://api.lbry.tv/api/v1/proxy?m="+json.method) 'fix: encode method
  http.AddHeader("Content-Type", "application/json")
  http.AddHeader("Accept", "application/json")
  if IsValid(m.top.authtoken)
    http.AddHeader("x-lbry-auth-token", m.top.authtoken) 'in some cases, this is actually needed!
  end if
  postJSON = FormatJson(json)
  response=""
  lastresponsecode = ""
  lastresponsefailurereason = ""
  responseheaders = []
  if http.AsyncPostFromString(postJSON) then
    event = Wait(10000, http.GetPort())
      if Type(event) = "roUrlEvent" Then
        response = event.getString()
        m.top.cookies = http.getCookies("", "/")
      else if event = invalid then
        http.asynccancel()
      Else
          ? "[LBRY_HTTP] AsyncPostFromString unknown event"
    end if
  end if
return parsejson(response)
End Function

function QueryLBRYcom(endpoint, json) as Object 'we need to vary the following: endpoint, JSON, and cookies. LBRY's public API has no differing endpoints as far as we care, as we only really claim_search
  http = CreateObject("roUrlTransfer")
  messagePort = CreateObject("roMessagePort")
  http.RetainBodyOnError(true)
  http.SetPort(messagePort)
  http.setCertificatesFile("common:/certs/ca-bundle.crt")
  http.InitClientCertificates()
  http.EnableCookies()
  http.AddCookies(m.top.cookies)
  http.SetUrl("https://api.lbry.com"+endpoint) 
  http.AddHeader("Content-Type", "application/json")
  http.AddHeader("Accept", "application/json")
  if IsValid(m.top.authtoken)
    http.AddHeader("x-lbry-auth-token", m.top.authtoken) 'in some cases, this is actually needed!
  end if
  response=""
  lastresponsecode = ""
  lastresponsefailurereason = ""
  responseheaders = []
  if http.AsyncPostFromString(json) then
    event = Wait(10000, http.GetPort())
      if Type(event) = "roUrlEvent" Then
        response = event.getString()
        m.top.cookies = http.getCookies("", "/")
      else if event = invalid then
        http.asynccancel()
      Else
          ? "[LBRY_HTTP] AsyncPostFromString unknown event"
    end if
  end if
return parsejson(response)
End Function

function QueryLBRYComments(json) as Object
  http = CreateObject("roUrlTransfer")
  messagePort = CreateObject("roMessagePort")
  http.RetainBodyOnError(true)
  http.SetPort(messagePort)
  http.setCertificatesFile("common:/certs/ca-bundle.crt")
  http.InitClientCertificates()
  http.EnableCookies()
  http.AddCookies(m.top.cookies)
  http.SetUrl("https://comments.lbry.com/api/v2?m=comment.List") 
  http.AddHeader("Content-Type", "application/json")
  http.AddHeader("Accept", "application/json")
  if IsValid(m.top.authtoken)
    http.AddHeader("x-lbry-auth-token", m.top.authtoken) 'in some cases, this is actually needed!
  end if
  response=""
  lastresponsecode = ""
  lastresponsefailurereason = ""
  responseheaders = []
  if http.AsyncPostFromString(json) then
    event = Wait(10000, http.GetPort())
      if Type(event) = "roUrlEvent" Then
        response = event.getString()
        m.top.cookies = http.getCookies("", "/")
      else if event = invalid then
        http.asynccancel()
      Else
          ? "[LBRY_HTTP] AsyncPostFromString unknown event"
    end if
  end if
  ? response
return parsejson(response)
End Function

function PostURLEncoded(URL, data) as Object
  http = CreateObject("roUrlTransfer")
  messagePort = CreateObject("roMessagePort")
  http.RetainBodyOnError(true)
  http.SetPort(messagePort)
  http.setCertificatesFile("common:/certs/ca-bundle.crt")
  http.InitClientCertificates()
  http.EnableCookies()
  http.AddCookies(m.top.cookies)
  http.SetUrl(URL+urlencode(data))
  http.AddHeader("Accept", "application/json")
  if IsValid(m.top.authtoken)
    http.AddHeader("x-lbry-auth-token", m.top.authtoken) 'in some cases, this is actually needed!
  end if
  response=""
  lastresponsecode = ""
  lastresponsefailurereason = ""
  responseheaders = []
  if http.AsyncPostFromString("") then
    event = Wait(10000, http.GetPort())
      if Type(event) = "roUrlEvent" Then
        response = event.getString()
        m.top.cookies = http.getCookies("", "/")
      else if event = invalid then
        http.asynccancel()
      Else
          ? "[LBRY_HTTP] AsyncPostFromString unknown event"
    end if
  end if
return parsejson(response)
End Function

Function GetURLEncoded(URL, data) as Object
  http = CreateObject("roUrlTransfer")
  messagePort = CreateObject("roMessagePort")
  http.RetainBodyOnError(true)
  http.SetPort(messagePort)
  http.setCertificatesFile("common:/certs/ca-bundle.crt")
  http.InitClientCertificates()
  http.EnableCookies()
  http.AddCookies(m.top.cookies)
  http.SetUrl(URL+urlencode(data).replace("claimtype", "claimType").replace("mediatype", "mediaType"))
  http.AddHeader("Accept", "application/json")
  response=""
  if http.AsyncGetToString() then
    event = Wait(10000, http.GetPort())
      if Type(event) = "roUrlEvent" Then
        response = event.getString()
        m.top.cookies = http.getCookies("", "/")
      else if event = invalid then
        http.asynccancel()
      Else
        ? "[LBRY_HTTP] AsyncGetToString unknown event"
    end if
  end if
  return parsejson(response)
End Function

function urlencode(data)
  encoded = ""
  beginning = True
  for each subitem in data
    if beginning
      encoded+="?"+subitem+"="+(data[subitem].EncodeUriComponent())
      beginning = False
    else
      encoded+="&"+subitem+"="+(data[subitem].EncodeUriComponent())
    end if
  end for
  '? encoded 'debug
  return encoded
end function

function GetRawText(URL) as Object
  http = CreateObject("roUrlTransfer")
  messagePort = CreateObject("roMessagePort")
  http.RetainBodyOnError(true)
  http.SetPort(messagePort)
  http.setCertificatesFile("common:/certs/ca-bundle.crt")
  http.InitClientCertificates()
  http.EnableCookies()
  http.AddCookies(m.top.cookies)
  http.SetUrl(URL)
  response=""
  if http.AsyncGetToString() then
    event = Wait(10000, http.GetPort())
      if Type(event) = "roUrlEvent" Then
        response = event.getString()
        parent = m.top.functionName
        if parent <> "JSONTask"
          m.top.cookies = http.getCookies("", "/")
        end if
      else if event = invalid then
        http.asynccancel()
      Else
        ? "[LBRY_HTTP] AsyncGetToString unknown event"
    end if
  end if
return response
End Function