function postJSON(json, url, headers=invalid) as Object 'json, url, headers: {header: headerdata}
  http = httpPreSetup(url)
  if IsValid(headers)
    http.SetHeaders(headers) 'in some cases, this is actually needed!
  end if
  http.AddHeader("Content-Type", "application/json")
  http.AddHeader("Accept", "application/json")
  response=""
  if http.AsyncPostFromString(json) then
    event = Wait(5000, http.GetPort())
      if Type(event) = "roUrlEvent" Then
        responseCode = event.GetResponseCode()
        if responseCode <= 299 AND responseCode >= 200
          m.top.cookies = http.getCookies("", "/")
          response = parsejson(event.getString().replace("\n","|||||"))
        end if
        if responseCode <= 399 AND responseCode >= 300
          headers = event.GetResponseHeaders()
          redirect = headers.location
          http.asynccancel()
          return postJSON(json, redirect, headers)
        end if
        if responseCode <= 499 AND responseCode >= 400
          try
            m.top.cookies = http.getCookies("", "/")
            response = parsejson(event.getString().replace("\n","|||||"))
          catch e
            return {success: False}
          end try
        end if
        if responseCode <= 599 AND responseCode >= 500
          http.asynccancel()
          return postJSON(json, url, headers)
        end if
      else if event = invalid then
        http.asynccancel()
        return postJSON(json, url, headers)
      Else
          ' ?"[LBRY_HTTP] AsyncPostFromString unknown event"
    end if
  end if
  cleanup()
  return response
end function

function postJSONResponseOut(json, url, headers=invalid) as Object 'json, url, headers: {header: headerdata}
  http = httpPreSetup(url)
  if IsValid(headers)
    http.SetHeaders(headers) 'in some cases, this is actually needed!
  end if
  http.AddHeader("Content-Type", "application/json")
  http.AddHeader("Accept", "application/json")
  if http.AsyncPostFromString(json) then
    event = Wait(5000, http.GetPort())
    if Type(event) = "roUrlEvent" Then
      responseCode = event.GetResponseCode()
    else if event = invalid then
      http.asynccancel()
      return 500
      Else
          ' ?"[LBRY_HTTP] AsyncPostFromString unknown event"
    end if
  end if
  cleanup()
  return responseCode
end function

function postURLEncoded(data, url, headers=invalid) as Object
  http = httpPreSetup(url)
  if IsValid(headers)
    http.SetHeaders(headers) 'in some cases, this is actually needed!
  end if
  http.AddHeader("Accept", "application/json")
  response=""
  lastresponsecode = ""
  lastresponsefailurereason = ""
  responseheaders = []
  if http.AsyncPostFromString(posturlencode(data)) then
    event = Wait(5000, http.GetPort())
      if Type(event) = "roUrlEvent" Then
        responseCode = event.GetResponseCode()
        if responseCode <= 299 AND responseCode >= 200
          m.top.cookies = http.getCookies("", "/")
          response = parsejson(event.getString().replace("\n","|||||"))
        end if
        if responseCode <= 399 AND responseCode >= 300
          headers = event.GetResponseHeaders()
          redirect = headers.location
          http.asynccancel()
          return postURLEncoded(json, redirect, headers)
        end if
        if responseCode <= 499 AND responseCode >= 400
          try
            m.top.cookies = http.getCookies("", "/")
            response = parsejson(event.getString().replace("\n","|||||"))
          catch e
            return {success: False}
          end try
        end if
        if responseCode <= 599 AND responseCode >= 500
          http.asynccancel()
          return postURLEncoded(json, url, headers)
        end if
      else if event = invalid then
        http.asynccancel()
        return postURLEncoded(json, url, headers)
      Else
          ' ?"[LBRY_HTTP] AsyncPostFromString unknown event"
    end if
  end if
cleanup()
return response
end function

function posturlencode(data)
  encoded = ""
  beginning = True
  for each subitem in data
    if beginning
      encoded+=subitem+"="+(data[subitem].EncodeUriComponent())
      beginning = False
    else
      encoded+="&"+subitem+"="+(data[subitem].EncodeUriComponent())
    end if
  end for
  ' ?encoded 'debug
  return encoded
end function

function getURLEncoded(data, url, headers=invalid) as Object
    currenturl = url+urlencode(data)
    ' ?currenturl
    http = httpPreSetup(currenturl)
    if http.AsyncGetToString() then
      event = Wait(5000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          responseCode = event.GetResponseCode()
          if responseCode <= 299 AND responseCode >= 200
            m.top.cookies = http.getCookies("", "/")
            response = parsejson(event.getString().replace("\n","|||||"))
          end if
          if responseCode <= 399 AND responseCode >= 300
            headers = event.GetResponseHeaders()
            redirect = headers.location
            http.asynccancel()
            return getURLEncoded(data, redirect, headers)
          end if
          if responseCode <= 499 AND responseCode >= 400 'todo: fix cookies
            try
              m.top.cookies = http.getCookies("", "/")
              response = parsejson(event.getString().replace("\n","|||||"))
            catch e
              http.asynccancel()
              return {success: False}
            end try
          end if
          if responseCode <= 599 AND responseCode >= 500
            http.asynccancel()
            return getURLEncoded(data, url, headers)
          end if
        else if event = invalid then
          http.asynccancel()
          return getURLEncoded(data, url, headers)
        Else
          ' ?"[LBRY_HTTP] AsyncGetToString unknown event"
      end if
    end if
  cleanup()
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
  '' ?encoded 'debug
  return encoded
end function

function getJSON(url, headers=invalid) as Object
    http = httpPreSetup(url)
    if IsValid(headers)
      http.SetHeaders(headers) 'in some cases, this is actually needed!
    end if
    if http.AsyncGetToString() then
      event = Wait(5000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          responseCode = event.GetResponseCode()
          if responseCode <= 299 AND responseCode >= 200
            m.top.cookies = http.getCookies("", "/")
            response = parsejson(event.getString().replace("\n","|||||"))
          end if
          if responseCode <= 399 AND responseCode >= 300
            headers = event.GetResponseHeaders()
            redirect = headers.location
            http.asynccancel()
            return getJSON(redirect)
          end if
          if responseCode <= 499 AND responseCode >= 400
            try
              m.top.cookies = http.getCookies("", "/")
              response = parsejson(event.getString().replace("\n","|||||"))
            catch e
              return {success: False}
            end try
          end if
          if responseCode <= 599 AND responseCode >= 500
            http.asynccancel()
            return getJSON(url)
          end if
        else if event = invalid then
          http.asynccancel()
          return getJSON(url)
        Else
          ' ?"[LBRY_HTTP] AsyncGetToString unknown event"
      end if
    end if
  cleanup()
  return response
end function

function getRawText(url) as Object
    http = httpPreSetup(url)
    if http.AsyncGetToString() then
      event = Wait(5000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          responseCode = event.GetResponseCode()
          if responseCode <= 299 AND responseCode >= 200
            m.top.cookies = http.getCookies("", "/")
            response = event.getString()
          end if
          if responseCode <= 399 AND responseCode >= 300
            headers = event.GetResponseHeaders()
            redirect = headers.location
            http.asynccancel()
            return getRawText(redirect)
          end if
          if responseCode <= 499 AND responseCode >= 400
            return "{error: True}"
          end if
          if responseCode <= 599 AND responseCode >= 500
            http.asynccancel()
            return getRawText(url)
          end if
        else if event = invalid then
          http.asynccancel()
          return getRawText(url)
        Else
          ' ?"[LBRY_HTTP] AsyncGetToString unknown event"
      end if
    end if
  cleanup()
  return response
end function

function urlExists(url) as Object
  http = httpPreSetup(url)
  if http.AsyncGetToString() then
    event = Wait(5000, http.GetPort())
      if Type(event) = "roUrlEvent" Then
        responseCode = event.GetResponseCode()
        if responseCode <= 299 AND responseCode >= 200
          return true
        end if
        if responseCode <= 399 AND responseCode >= 300
          headers = event.GetResponseHeaders()
          redirect = headers.location
          http.asynccancel()
          return urlExists(redirect)
        end if
        if responseCode <= 499 AND responseCode >= 400
          return false
        end if
        if responseCode <= 599 AND responseCode >= 500
          http.asynccancel()
          return false
        end if
      else if event = invalid then
        http.asynccancel()
        return false
      Else
        ' ?"[LBRY_HTTP] AsyncGetToString unknown event"
    end if
  end if
cleanup()
end function

Function resolveRedirect(url As String) As String
url = url.Unescape()
if instr(url, m.top.constants["VIDEO_API"]) > 0
  'Unicode video fix, because the video API doesn't accept escaped unicode correctly.
  spliturl = url.split("/")
  spliturlcount = spliturl.Count()
  vurlarray = []
  cleanvurlarray = []
  vurlarray[0] = spliturl[spliturlcount-3]
  vurlarray[1] = spliturl[spliturlcount-2]
  vurlarray[2] = spliturl[spliturlcount-1]
  vregex = CreateObject("roRegex", "[^a-zA-Z0-9\-\s]", "")
  for i = 0 to vurlarray.Count()-1
    'cleanurl = vregex.ReplaceAll(vurlarray[i], "")
    'if cleanurl = ""
    '  cleanurl = "roku"
    'end if
    'if instr(cleanurl, " ") > 0
    '  cleanurl = "roku"
    'end if
    cleanurl = vurlarray[i].EncodeUri()
    cleanvurlarray.push(cleanurl)
  end for
  vregex = invalid
  ' ?cleanvurlarray
  url = m.top.constants["VIDEO_API"]+"/api/v4/streams/free/"+cleanvurlarray.Join("/")
end if
http = httpPreSetup(url)
if http.AsyncHead() then
  event = Wait(5000, http.GetPort())
    if Type(event) = "roUrlEvent" Then
      responseCode = event.GetResponseCode()
      headers = event.GetResponseHeaders()
      redirect = headers.location
      if isValid(redirect)
        responseCode = 300
      end if
      if responseCode <= 299 AND responseCode >= 200
        return url
      end if
      if responseCode <= 399 AND responseCode >= 300
        headers = event.GetResponseHeaders()
        redirect = headers.location
        if redirect.split("/")[0] <> "http" OR redirect.split("/")[0] <> "https"
          urlsplit = url.split("/")
          urlsplit.Shift()
          urlsplit.Shift()
          rooturl = urlsplit[0]
          return "https://"+rooturl+redirect
        else
          return redirect
        end if
      end if
      if responseCode <= 499 AND responseCode >= 400
        return url
      end if
      if responseCode <= 599 AND responseCode >= 500
        return url
      end if
    else if event = invalid then
      http.asynccancel()
      return url
    Else
      ' ?"[LBRY_HTTP] AsyncGetToString unknown event"
  end if
end if
End Function

Function httpPreSetup(url)
    http = CreateObject("roUrlTransfer")
    http.AddHeader("User-Agent", m.global.constants["userAgent"])
    messagePort = CreateObject("roMessagePort")
    http.RetainBodyOnError(true)
    http.SetPort(messagePort)
    http.setCertificatesFile("common:/certs/ca-bundle.crt")
    http.InitClientCertificates()
    http.SetUrl(url)
    http.EnableCookies()
    return http
End Function

Sub cleanup()
messagePort = invalid
http = invalid
event = invalid
End Sub