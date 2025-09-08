function postJSON(json, url, headers) as Object 'json, url, headers: {header: headerdata}
  response = ""
  currentUrl = url
  maxRetries = 5
  maxRedirects = 5
  retries = 0
  done = false
  while done = false and retries <= maxRetries
    redirects = 0
    innerUrl = currentUrl
    while redirects <= maxRedirects
      http = httpPreSetup(innerUrl)
      if IsValid(headers)
        if headers.Count() > 0
          http.SetHeaders(headers)
        end if
      end if
      http.AddHeader("Content-Type", "application/json")
      http.AddHeader("Accept", "application/json")
      if http.AsyncPostFromString(json) then
        event = Wait(5000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          responseCode = event.GetResponseCode()
          if responseCode >= 200 and responseCode <= 299
            m.top.cookies = http.getCookies("", "/")
            response = parsejson(event.getString().replace("\n","|||||"))
            done = true
            exit while
          else if responseCode >= 300 and responseCode <= 399
            lheaders = event.GetResponseHeaders()
            redirect = lheaders.location
            http.asynccancel()
            if isValid(redirect)
              innerUrl = redirect
              redirects = redirects + 1
              ' continue inner loop to follow redirect
            else
              done = true
              exit while
            end if
          else if responseCode >= 400 and responseCode <= 499
            try
              m.top.cookies = http.getCookies("", "/")
              response = parsejson(event.getString().replace("\n","|||||"))
            catch e
              response = { success: False }
            end try
            done = true
            exit while
          else if responseCode >= 500 and responseCode <= 599
            http.asynccancel()
            retries = retries + 1
            exit while ' retry outer loop
          else
            http.asynccancel()
            retries = retries + 1
            exit while ' retry outer loop
          end if
        else if event = invalid then
          http.asynccancel()
          retries = retries + 1
          exit while ' retry outer loop
        else
          ' Unknown event; stop trying
          done = true
          exit while
        end if
      else
        ' Failed to start post; stop trying
        done = true
        exit while
      end if
    end while
  end while
  cleanup()
  return response
end function

function postJSONResponseOut(json, url, headers) as Object 'json, url, headers: {header: headerdata}
  http = httpPreSetup(url)
  if IsValid(headers)
    if headers.Count() > 0
      http.SetHeaders(headers) 'in some cases, this is actually needed!
    end if
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
          ? "[LBRY_HTTP] AsyncPostFromString unknown event"
    end if
  end if
  cleanup()
  return responseCode
end function

function postURLEncoded(data, url, headers) as Object
  http = httpPreSetup(url)
  if IsValid(headers)
    if headers.Count() > 0
      http.SetHeaders(headers) 'in some cases, this is actually needed!
    end if
  end if
  http.AddHeader("Accept", "application/json")
  response=""
  lastresponsecode = ""
  lastresponsefailurereason = ""
  ' Guard against invalid data
  body = posturlencode(data)
  if http.AsyncPostFromString(body) then
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
          return postURLEncoded(data, redirect, headers)
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
          return postURLEncoded(data, url, headers)
        end if
        if event <> invalid AND responseCode < 100 OR event <> invalid AND responseCode > 599
          http.asynccancel()
          return postURLEncoded(data, url, headers)
        end if
      else if event = invalid then
        http.asynccancel()
        return postURLEncoded(data, url, headers)
      Else
          ? "[LBRY_HTTP] AsyncPostFromString unknown event"
    end if
  end if
cleanup()
return response
end function

function posturlencode(data)
  encoded = ""
  beginning = True
  if not isValid(data)
    return encoded
  end if
  for each subitem in data
    if beginning
      encoded+=subitem+"="+(data[subitem].EncodeUriComponent())
      beginning = False
    else
      encoded+="&"+subitem+"="+(data[subitem].EncodeUriComponent())
    end if
  end for
  '? encoded 'debug
  return encoded
end function

function getURLEncoded(data, url, headers) as Object
    currenturl = url+urlencode(data)
    ? currenturl
    http = httpPreSetup(currenturl)
    if IsValid(headers)
      if headers.Count() > 0
        http.SetHeaders(headers) 'in some cases, this is actually needed!
      end if
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
          if event <> invalid AND responseCode < 100 OR event <> invalid AND responseCode > 599
            http.asynccancel()
            return getURLEncoded(data, url, headers)
          end if
        else if event = invalid then
          http.asynccancel()
          return getURLEncoded(data, url, headers)
        Else
          ? "[LBRY_HTTP] AsyncGetToString unknown event"
      end if
    end if
  cleanup()
  return response
end function

function urlencode(data)
  encoded = ""
  beginning = True
  if not isValid(data)
    return encoded
  end if
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

function getJSONAuthenticated(url, headers = invalid) as Object
  http = httpPreSetup(url)
  if IsValid(headers)
    if headers.Count() > 0
      http.SetHeaders(headers) 'in some cases, this is actually needed!
    end if
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
        if event <> invalid AND responseCode < 100 OR event <> invalid AND responseCode > 599
          http.asynccancel()
          return getJSON(url)
        end if
      else if event = invalid then
        http.asynccancel()
        return getJSON(url)
      Else
        ? "[LBRY_HTTP] AsyncGetToString unknown event"
    end if
  end if
cleanup()
return response
end function

function getJSON(url) as Object
  response = {}
  currentUrl = url
  maxRetries = 5
  maxRedirects = 5
  retries = 0
  done = false
  while done = false and retries <= maxRetries
    redirects = 0
    innerUrl = currentUrl
    while redirects <= maxRedirects
      http = httpPreSetup(innerUrl)
      if http.AsyncGetToString() then
        event = Wait(5000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          responseCode = event.GetResponseCode()
          if responseCode >= 200 AND responseCode <= 299
            m.top.cookies = http.getCookies("", "/")
            response = parsejson(event.getString().replace("\n","|||||"))
            done = true
            exit while
          else if responseCode >= 300 AND responseCode <= 399
            lheaders = event.GetResponseHeaders()
            redirect = lheaders.location
            http.asynccancel()
            if isValid(redirect)
              innerUrl = redirect
              redirects = redirects + 1
              ' continue inner loop to follow redirect
            else
              done = true
              exit while
            end if
          else if responseCode >= 400 AND responseCode <= 499
            try
              m.top.cookies = http.getCookies("", "/")
              response = parsejson(event.getString().replace("\n","|||||"))
            catch e
              response = { success: False }
            end try
            done = true
            exit while
          else if responseCode >= 500 AND responseCode <= 599
            http.asynccancel()
            retries = retries + 1
            exit while ' retry outer loop
          else
            http.asynccancel()
            retries = retries + 1
            exit while ' retry outer loop
          end if
        else if event = invalid then
          http.asynccancel()
          retries = retries + 1
          exit while ' retry outer loop
        else
          done = true
          exit while
        end if
      else
        done = true
        exit while
      end if
    end while
  end while
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
          if event <> invalid AND responseCode < 100 OR event <> invalid AND responseCode > 599
            http.asynccancel()
            return getRawText(url)
          end if
        else if event = invalid then
          http.asynccancel()
          return getRawText(url)
        Else
          ? "[LBRY_HTTP] AsyncGetToString unknown event"
      end if
    end if
  cleanup()
  return response
end function

function getRawTextAuthenticated(url, headers) as Object
  http = httpPreSetup(url)
  if IsValid(headers)
    if headers.Count() > 0
      http.SetHeaders(headers) 'in some cases, this is actually needed!
    end if
  end if
  if http.AsyncGetToString() then
    event = Wait(5000, http.GetPort())
      if Type(event) = "roUrlEvent" Then
        responseCode = event.GetResponseCode()
        if responseCode <= 299 AND responseCode >= 200
          m.top.cookies = http.getCookies("", "/")
          response = event.getString()
        end if
        if responseCode <= 399 AND responseCode >= 300
          lheaders = event.GetResponseHeaders()
          redirect = lheaders.location
          http.asynccancel()
          return getRawTextAuthenticated(redirect, headers)
        end if
        if responseCode <= 499 AND responseCode >= 400
          return "{error: True}"
        end if
        if responseCode <= 599 AND responseCode >= 500
          http.asynccancel()
          return getRawTextAuthenticated(url, headers)
        end if
        if event <> invalid AND responseCode < 100 OR event <> invalid AND responseCode > 599
          http.asynccancel()
          return getRawTextAuthenticated(url, headers)
        end if
      else if event = invalid then
        http.asynccancel()
        return getRawTextAuthenticated(url, headers)
      Else
        ? "[LBRY_HTTP] AsyncGetToString unknown event"
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
        if event <> invalid AND responseCode < 100 OR event <> invalid AND responseCode > 599
          http.asynccancel()
          return urlExists(url)
        end if
      else if event = invalid then
        http.asynccancel()
        return false
      Else
        ? "[LBRY_HTTP] AsyncGetToString unknown event"
    end if
  end if
cleanup()
end function

Function resolveRedirect(url As String) As String
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
      if event <> invalid AND responseCode < 100 OR event <> invalid AND responseCode > 599
        return url
      end if
    else if event = invalid then
      http.asynccancel()
      return url
    Else
      ? "[LBRY_HTTP] AsyncGetToString unknown event"
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
