'All HTTP query functions for LBRY (getrawtext, querylbry*)

function QueryLBRYAPI(json, cookies) as Object
  http = CreateObject("roUrlTransfer")
  messagePort = CreateObject("roMessagePort")
  http.RetainBodyOnError(true)
  http.SetPort(messagePort)
  http.setCertificatesFile("common:/certs/ca-bundle.crt")
  http.InitClientCertificates()
  http.EnableCookies()
  http.AddCookies(cookies)
  http.SetUrl("https://api.lbry.tv/api/v1/proxy")
  http.AddHeader("Content-Type", "application/json")
  http.AddHeader("Accept", "application/json") 
  postJSON = FormatJson(json)
  response=""
  lastresponsecode = ""
  lastresponsefailurereason = ""
  responseheaders = []
  if http.AsyncPostFromString(postJSON) then
    event = Wait(10000, http.GetPort())
      if Type(event) = "roUrlEvent" Then
        response = event.getString()
        httpcookies = http.getCookies("", "/")
      else if event = invalid then
        http.asynccancel()
      Else
          '? "AsyncPostFromString unknown event"
    end if
  end if
return [parsejson(response), httpcookies]
End Function

function QueryLBRYcom(endpoint, json, cookies) as Object 'we need to vary the following: endpoint, JSON, and cookies. LBRY's public API has no differing endpoints as far as we care, as we only really claim_search
  http = CreateObject("roUrlTransfer")
  messagePort = CreateObject("roMessagePort")
  http.RetainBodyOnError(true)
  http.SetPort(messagePort)
  http.setCertificatesFile("common:/certs/ca-bundle.crt")
  http.InitClientCertificates()
  http.EnableCookies()
  http.AddCookies(cookies)
  http.SetUrl("https://api.lbry.com/"+endpoint) 
  http.AddHeader("Content-Type", "application/json")
  http.AddHeader("Accept", "application/json") 
  postJSON = FormatJson(json)
  response=""
  lastresponsecode = ""
  lastresponsefailurereason = ""
  responseheaders = []
  if http.AsyncPostFromString(postJSON) then
    event = Wait(10000, http.GetPort())
      if Type(event) = "roUrlEvent" Then
        response = event.getString()
        httpcookies = http.getCookies("", "/")
      else if event = invalid then
        http.asynccancel()
      Else
          '? "AsyncPostFromString unknown event"
    end if
  end if
return [parsejson(response), httpcookies]
End Function

function GetRawText(URL) as Object
  http = CreateObject("roUrlTransfer")
  messagePort = CreateObject("roMessagePort")
  http.RetainBodyOnError(true)
  http.SetPort(messagePort)
  http.setCertificatesFile("common:/certs/ca-bundle.crt")
  http.AddHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/56.0.2924.87 Safari/537.36")
  http.InitClientCertificates()
  http.SetUrl(URL)
  response=""
  if http.AsyncGetToString() then
    event = Wait(10000, http.GetPort())
      if Type(event) = "roUrlEvent" Then
        response = event.getString()
      else if event = invalid then
        http.asynccancel()
      Else
        '? "[LBRY_HTTP] AsyncGetToString unknown event"
    end if
  end if
return response
End Function