function postJSON(json, url, headers) as Object 'json, url, headers: {header: headerdata}
  response = {}
  errorcount = 0
  http = CreateObject("roUrlTransfer")
  http.AddHeader("User-Agent", m.global.constants["userAgent"])
  messagePort = CreateObject("roMessagePort")
  while true
    http.RetainBodyOnError(true)
    http.SetPort(messagePort)
    http.setCertificatesFile("common:/certs/ca-bundle.crt")
    http.InitClientCertificates()
    http.EnableCookies()
    http.AddCookies(m.top.cookies)
    http.SetUrl(url)
    if IsValid(headers)
      http.SetHeaders(headers) 'in some cases, this is actually needed!
    end if
    http.AddHeader("Content-Type", "application/json")
    http.AddHeader("Accept", "application/json")
    response=""
    lastresponsecode = ""
    lastresponsefailurereason = ""
    responseheaders = []
    if http.AsyncPostFromString(json) then
      event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          response = parsejson(event.getString().replace("\n","|||||"))
          m.top.cookies = http.getCookies("", "/")
          if isValid(response)
            exit while
          else
            sleep(3000)
            errorcount+=1
            if errorcount > 5
              exit while
            end if
          end if
        else if event = invalid then
          http.asynccancel()
        Else
            ? "[LBRY_HTTP] AsyncPostFromString unknown event"
      end if
    end if
  end while
  if errorcount > 5
    STOP 'debug
  end if
  return response
end function

function postURLEncoded(data, url, headers) as Object
  response = {}
  http = CreateObject("roUrlTransfer")
  http.AddHeader("User-Agent", m.global.constants["userAgent"])
  errorcount = 0
  messagePort = CreateObject("roMessagePort")
  while true
    http.RetainBodyOnError(true)
    http.SetPort(messagePort)
    http.setCertificatesFile("common:/certs/ca-bundle.crt")
    http.InitClientCertificates()
    http.EnableCookies()
    http.AddCookies(m.top.cookies)
    http.SetUrl(url+urlencode(data))
    if IsValid(headers)
      http.SetHeaders(headers) 'in some cases, this is actually needed!
    end if
    http.AddHeader("Accept", "application/json")
    response=""
    lastresponsecode = ""
    lastresponsefailurereason = ""
    responseheaders = []
    if http.AsyncPostFromString("") then
      event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          response = parsejson(event.getString().replace("\n","|||||"))
          m.top.cookies = http.getCookies("", "/")
          if isValid(response)
            exit while
          else
            sleep(3000)
            errorcount+=1
            if errorcount > 5
              exit while
            end if
          end if
        else if event = invalid then
          http.asynccancel()
        Else
            ? "[LBRY_HTTP] AsyncPostFromString unknown event"
      end if
    end if
  end while
  if errorcount > 5
    STOP 'debug
  end if
return response
end function

function getURLEncoded(data, url, headers) as Object
  response = {}
  http = CreateObject("roUrlTransfer")
  http.AddHeader("User-Agent", m.global.constants["userAgent"])
  errorcount = 0
  messagePort = CreateObject("roMessagePort")
  while true
    http.RetainBodyOnError(true)
    http.SetPort(messagePort)
    http.setCertificatesFile("common:/certs/ca-bundle.crt")
    http.InitClientCertificates()
    http.EnableCookies()
    http.AddCookies(m.top.cookies)
    http.SetUrl(url+urlencode(data)) '.replace("claimtype", "claimType").replace("mediatype", "mediaType")
    http.AddHeader("Accept", "application/json")
    response=""
    if http.AsyncGetToString() then
      event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          response = parsejson(event.getString().replace("\n","|||||"))
          if isValid(response)
            exit while
          else
            sleep(3000)
            errorcount+=1
            if errorcount > 5
              exit while
            end if
          end if
          m.top.cookies = http.getCookies("", "/")
        else if event = invalid then
          http.asynccancel()
        Else
          ? "[LBRY_HTTP] AsyncGetToString unknown event"
      end if
    end if
  end while
  if errorcount > 5
    STOP 'debug
  end if
  return response
end function

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

function getJSON(url) as Object
  errorcount = 0
  while true
    http = CreateObject("roUrlTransfer")
    http.AddHeader("User-Agent", m.global.constants["userAgent"])
    messagePort = CreateObject("roMessagePort")
    http.RetainBodyOnError(true)
    http.SetPort(messagePort)
    http.setCertificatesFile("common:/certs/ca-bundle.crt")
    http.InitClientCertificates()
    http.EnableCookies()
    http.AddCookies(m.top.cookies)
    http.SetUrl(url)
    response=""
    if http.AsyncGetToString() then
      event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          response = event.getString()
          m.top.cookies = http.getCookies("", "/")
          if isValid(response)
            exit while
          else
            sleep(3000)
            ? "[GetJSON] Attempting to load endpoint again."
            errorcount+=1
            if errorcount > 5
              exit while
            end if
          end if
        else if event = invalid then
          http.asynccancel()
        Else
          ? "[LBRY_HTTP] AsyncGetToString unknown event"
      end if
    end if
  end while
  if errorcount > 5
    STOP
  end if
  return parsejson(response.replace("\n", Chr(10))) 'workaround for Roku not correctly parsing newline.
end function

function getRawText(url) as Object
  errorcount = 0
  while true
    http = CreateObject("roUrlTransfer")
    http.AddHeader("User-Agent", m.global.constants["userAgent"])
    messagePort = CreateObject("roMessagePort")
    http.RetainBodyOnError(true)
    http.SetPort(messagePort)
    http.setCertificatesFile("common:/certs/ca-bundle.crt")
    http.InitClientCertificates()
    http.EnableCookies()
    http.AddCookies(m.top.cookies)
    http.SetUrl(url)
    response=""
    if http.AsyncGetToString() then
      event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          response = event.getString()
          m.top.cookies = http.getCookies("", "/")
          if isValid(response)
            exit while
          else
            sleep(3000)
            errorcount+=1
            if errorcount > 5
              exit while
            end if
          end if
        else if event = invalid then
          http.asynccancel()
        Else
          ? "[LBRY_HTTP] AsyncGetToString unknown event"
      end if
    end if
  end while
  if errorcount > 5
    STOP 'debug
  end if
  return response
end function

Function resolveRedirect(url As String) As String
http = CreateObject("roUrlTransfer")
http.AddHeader("User-Agent", m.global.constants["userAgent"])
messagePort = CreateObject("roMessagePort")
http.RetainBodyOnError(true)
http.SetPort(messagePort)
http.setCertificatesFile("common:/certs/ca-bundle.crt")
http.InitClientCertificates()
http.EnableCookies()
http.AddCookies(m.top.cookies)
http.SetUrl(url)
response=""
if http.AsyncHead() then
  event = Wait(30000, http.GetPort())
    if Type(event) = "roUrlEvent" Then
      headers = event.GetResponseHeaders()
      try
        redirect = headers.location
        m.top.cookies = http.getCookies("", "/")
        return redirect
      catch e
        return url
      end try
    else if event = invalid then
      http.asynccancel()
    Else
      ? "[LBRY_HTTP] AsyncGetToString unknown event"
  end if
end if
End Function