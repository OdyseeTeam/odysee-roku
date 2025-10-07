function postJSON(json, url, headers) as Object 'json, url, headers: {header: headerdata}
  response = ""
  currentUrl = url
  maxRetries = 5
  maxRedirects = 5
  retries = 0
  backoffMs = 250
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
        event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          responseCode = event.GetResponseCode()
          if responseCode >= 200 and responseCode <= 299
            cookies = http.getCookies("", "/")
            if cookies <> invalid then m.top.cookies = cookies
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
              cookies = http.getCookies("", "/")
            if cookies <> invalid then m.top.cookies = cookies
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
    if done = false and retries <= maxRetries
      Sleep(backoffMs)
      if backoffMs < 2000 then backoffMs = backoffMs * 2
    end if
  end while
  cleanup()
  return response
end function

function postJSONResponseOut(json, url, headers) as Object 'json, url, headers: {header: headerdata}
  responseCode = 500
  currentUrl = url
  maxRetries = 5
  maxRedirects = 5
  retries = 0
  backoffMs = 250
  done = false
  while done = false and retries <= maxRetries
    redirects = 0
    innerUrl = currentUrl
    while redirects <= maxRedirects
      http = httpPreSetup(innerUrl)
      if IsValid(headers)
        if headers.Count() > 0
          http.SetHeaders(headers) 'in some cases, this is actually needed!
        end if
      end if
      http.AddHeader("Content-Type", "application/json")
      http.AddHeader("Accept", "application/json")
      if http.AsyncPostFromString(json) then
        event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          code = event.GetResponseCode()
          if code >= 200 and code <= 299
            responseCode = code
            done = true
            exit while
          else if code >= 300 and code <= 399
            lheaders = event.GetResponseHeaders()
            redirect = lheaders.location
            http.asynccancel()
            if isValid(redirect)
              innerUrl = redirect
              redirects = redirects + 1
            else
              responseCode = code
              done = true
              exit while
            end if
          else if code >= 400 and code <= 499
            responseCode = code
            done = true
            exit while
          else if code >= 500 and code <= 599
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
    if done = false and retries <= maxRetries
      Sleep(backoffMs)
      if backoffMs < 2000 then backoffMs = backoffMs * 2
    end if
  end while
  cleanup()
  return responseCode
end function

function postURLEncoded(data, url, headers) as Object
  response = ""
  currentUrl = url
  maxRetries = 5
  maxRedirects = 5
  retries = 0
  backoffMs = 250
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
      http.AddHeader("Accept", "application/json")
      body = posturlencode(data)
      if http.AsyncPostFromString(body) then
        event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          responseCode = event.GetResponseCode()
          if responseCode >= 200 and responseCode <= 299
            cookies = http.getCookies("", "/")
            if cookies <> invalid then m.top.cookies = cookies
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
            else
              done = true
              exit while
            end if
          else if responseCode >= 400 and responseCode <= 499
            try
              cookies = http.getCookies("", "/")
            if cookies <> invalid then m.top.cookies = cookies
              response = parsejson(event.getString().replace("\n","|||||"))
            catch e
              response = { success: False }
            end try
            done = true
            exit while
          else if responseCode >= 500 and responseCode <= 599
            http.asynccancel()
            retries = retries + 1
            exit while
          else
            http.asynccancel()
            retries = retries + 1
            exit while
          end if
        else if event = invalid then
          http.asynccancel()
          retries = retries + 1
          exit while
        else
          done = true
          exit while
        end if
      else
        done = true
        exit while
      end if
    end while
    if done = false and retries <= maxRetries
      Sleep(backoffMs)
      if backoffMs < 2000 then backoffMs = backoffMs * 2
    end if
  end while
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
  response = ""
  baseUrl = url
  maxRetries = 5
  maxRedirects = 5
  retries = 0
  backoffMs = 250
  done = false
  while done = false and retries <= maxRetries
    redirects = 0
    innerBaseUrl = baseUrl
    while redirects <= maxRedirects
      requestUrl = innerBaseUrl + urlencode(data)
      ? requestUrl
      http = httpPreSetup(requestUrl)
      if IsValid(headers)
        if headers.Count() > 0
          http.SetHeaders(headers)
        end if
      end if
      if http.AsyncGetToString() then
        event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          responseCode = event.GetResponseCode()
          if responseCode >= 200 AND responseCode <= 299
            cookies = http.getCookies("", "/")
            if cookies <> invalid then m.top.cookies = cookies
            response = parsejson(event.getString().replace("\n","|||||"))
            done = true
            exit while
          else if responseCode >= 300 AND responseCode <= 399
            lheaders = event.GetResponseHeaders()
            redirect = lheaders.location
            http.asynccancel()
            if isValid(redirect)
              innerBaseUrl = redirect
              redirects = redirects + 1
            else
              done = true
              exit while
            end if
          else if responseCode >= 400 AND responseCode <= 499
            try
              cookies = http.getCookies("", "/")
            if cookies <> invalid then m.top.cookies = cookies
              response = parsejson(event.getString().replace("\n","|||||"))
            catch e
              response = { success: False }
            end try
            done = true
            exit while
          else if responseCode >= 500 AND responseCode <= 599
            http.asynccancel()
            retries = retries + 1
            exit while
          else
            http.asynccancel()
            retries = retries + 1
            exit while
          end if
        else if event = invalid then
          http.asynccancel()
          retries = retries + 1
          exit while
        else
          done = true
          exit while
        end if
      else
        done = true
        exit while
      end if
    end while
    if done = false and retries <= maxRetries
      Sleep(backoffMs)
      if backoffMs < 2000 then backoffMs = backoffMs * 2
    end if
  end while
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
    ' BrightScript lowercases AA keys on iteration; fix known case-sensitive param names
    keyName = subitem
    if subitem = "claimtype" then keyName = "claimType"
    val = data[subitem]
    ' Safely coerce non-strings to strings before encoding
    if Type(val) <> "roString" and Type(val) <> "String" then
      try: val = val.ToStr() : catch e: val = "" : end try
    end if
    if keyName = "s" then
      ? "[HTTP:urlencode] s='" + val + "'"
    end if
    if beginning
      encoded+="?"+keyName+"="+(val.EncodeUriComponent())
      beginning = False
    else
      encoded+="&"+keyName+"="+(val.EncodeUriComponent())
    end if
  end for
  '? encoded 'debug
  return encoded
end function

function getJSONAuthenticated(url, headers = invalid) as Object
  response = {}
  currentUrl = url
  maxRetries = 5
  maxRedirects = 5
  retries = 0
  backoffMs = 250
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

      if http.AsyncGetToString() then
        event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          responseCode = event.GetResponseCode()

          if responseCode >= 200 and responseCode <= 299
            ' Success
            cookies = http.getCookies("", "/")
            if cookies <> invalid then m.top.cookies = cookies
            response = parsejson(event.getString().replace("\n","|||||"))
            done = true
            exit while
          else if responseCode >= 300 and responseCode <= 399
            ' Redirect
            lheaders = event.GetResponseHeaders()
            redirect = lheaders.location
            if IsValid(redirect) and redirect <> ""
              innerUrl = redirect
              redirects = redirects + 1
              http.asynccancel()
            else
              ' Invalid redirect
              done = true
              response = {success: False, error: "Invalid redirect"}
              exit while
            end if
          else if responseCode >= 400 and responseCode <= 499
            ' Client error - don't retry
            try
              cookies = http.getCookies("", "/")
            if cookies <> invalid then m.top.cookies = cookies
              response = parsejson(event.getString().replace("\n","|||||"))
            catch e
              response = {success: False, error: "Client error"}
            end try
            done = true
            exit while
          else if responseCode >= 500 and responseCode <= 599
            ' Server error - retry with backoff
            http.asynccancel()
            retries = retries + 1
            exit while
          else
            ' Unexpected response code
            http.asynccancel()
            retries = retries + 1
            exit while
          end if
        else if event = invalid then
          ' Timeout or connection error - retry
          http.asynccancel()
          retries = retries + 1
          exit while
        else
          ? "[LBRY_HTTP] AsyncGetToString unknown event"
          done = true
          response = {success: False, error: "Unknown event"}
          exit while
        end if
      else
        ' Failed to start async request
        done = true
        response = {success: False, error: "Failed to start request"}
        exit while
      end if
    end while

    ' Apply backoff before retry
    if done = false and retries <= maxRetries
      Sleep(backoffMs)
      if backoffMs < 2000 then backoffMs = backoffMs * 2
    end if
  end while

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
        event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          responseCode = event.GetResponseCode()
          if responseCode >= 200 AND responseCode <= 299
            cookies = http.getCookies("", "/")
            if cookies <> invalid then m.top.cookies = cookies
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
              cookies = http.getCookies("", "/")
            if cookies <> invalid then m.top.cookies = cookies
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
  response = ""
  currentUrl = url
  maxRetries = 5
  maxRedirects = 5
  retries = 0
  backoffMs = 250
  done = false
  while done = false and retries <= maxRetries
    redirects = 0
    innerUrl = currentUrl
    while redirects <= maxRedirects
      http = httpPreSetup(innerUrl)
      if http.AsyncGetToString() then
        event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          responseCode = event.GetResponseCode()
          if responseCode >= 200 AND responseCode <= 299
            cookies = http.getCookies("", "/")
            if cookies <> invalid then m.top.cookies = cookies
            response = event.getString()
            done = true
            exit while
          else if responseCode >= 300 AND responseCode <= 399
            lheaders = event.GetResponseHeaders()
            redirect = lheaders.location
            http.asynccancel()
            if isValid(redirect)
              innerUrl = redirect
              redirects = redirects + 1
            else
              done = true
              exit while
            end if
          else if responseCode >= 400 AND responseCode <= 499
            return "{error: True}"
          else if responseCode >= 500 AND responseCode <= 599
            http.asynccancel()
            retries = retries + 1
            exit while
          else
            http.asynccancel()
            retries = retries + 1
            exit while
          end if
        else if event = invalid then
          http.asynccancel()
          retries = retries + 1
          exit while
        else
          done = true
          exit while
        end if
      else
        done = true
        exit while
      end if
    end while
    if done = false and retries <= maxRetries
      Sleep(backoffMs)
      if backoffMs < 2000 then backoffMs = backoffMs * 2
    end if
  end while
  cleanup()
  return response
end function

function getRawTextAuthenticated(url, headers) as Object
  response = ""
  currentUrl = url
  maxRetries = 5
  maxRedirects = 5
  retries = 0
  backoffMs = 250
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
      if http.AsyncGetToString() then
        event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          responseCode = event.GetResponseCode()
          if responseCode >= 200 AND responseCode <= 299
            cookies = http.getCookies("", "/")
            if cookies <> invalid then m.top.cookies = cookies
            response = event.getString()
            done = true
            exit while
          else if responseCode >= 300 AND responseCode <= 399
            lheaders = event.GetResponseHeaders()
            redirect = lheaders.location
            http.asynccancel()
            if isValid(redirect)
              innerUrl = redirect
              redirects = redirects + 1
            else
              done = true
              exit while
            end if
          else if responseCode >= 400 AND responseCode <= 499
            return "{error: True}"
          else if responseCode >= 500 AND responseCode <= 599
            http.asynccancel()
            retries = retries + 1
            exit while
          else
            http.asynccancel()
            retries = retries + 1
            exit while
          end if
        else if event = invalid then
          http.asynccancel()
          retries = retries + 1
          exit while
        else
          done = true
          exit while
        end if
      else
        done = true
        exit while
      end if
    end while
    if done = false and retries <= maxRetries
      Sleep(backoffMs)
      if backoffMs < 2000 then backoffMs = backoffMs * 2
    end if
  end while
  cleanup()
  return response
end function

function urlExists(url) as Object
  currentUrl = url
  maxRetries = 3
  maxRedirects = 5
  retries = 0
  backoffMs = 250
  done = false
  while done = false and retries <= maxRetries
    redirects = 0
    innerUrl = currentUrl
    while redirects <= maxRedirects
      http = httpPreSetup(innerUrl)
      if http.AsyncHead() then
        event = Wait(30000, http.GetPort())
        if Type(event) = "roUrlEvent" Then
          responseCode = event.GetResponseCode()
          if responseCode >= 200 AND responseCode <= 299
            return true
          else if responseCode >= 300 AND responseCode <= 399
            lheaders = event.GetResponseHeaders()
            redirect = lheaders.location
            http.asynccancel()
            if isValid(redirect)
              innerUrl = redirect
              redirects = redirects + 1
            else
              return false
            end if
          else if responseCode >= 400 AND responseCode <= 499
            return false
          else if responseCode >= 500 AND responseCode <= 599
            http.asynccancel()
            retries = retries + 1
            exit while
          else
            http.asynccancel()
            retries = retries + 1
            exit while
          end if
        else if event = invalid then
          http.asynccancel()
          retries = retries + 1
          exit while
        else
          return false
        end if
      else
        return false
      end if
    end while
    if retries <= maxRetries
      Sleep(backoffMs)
      if backoffMs < 2000 then backoffMs = backoffMs * 2
    end if
  end while
  cleanup()
end function

Function resolveRedirect(url As String) As String
http = httpPreSetup(url)
if http.AsyncHead() then
  event = Wait(10000, http.GetPort())
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
        if redirect.Instr("://") = -1
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
