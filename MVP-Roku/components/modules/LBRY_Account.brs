' All account-related functions (Registry, ETC)
Function createAccount()
    input = parsejson(GetRawText("https://api.lbry.com/user/new"))
    if IsValid(input.data)
      data = input.data
      if IsValid(data.id) AND IsValid(data.created_at)
        m.top.uid = data.id
      end if
      if IsValid(data.auth_token)
        m.top.authtoken = data.auth_token
      end if
      if IsValid(data.id) AND IsValid(data.created_at) AND IsValid(data.auth_token)
        return true
      else
        ? "The API isn't responding correctly, we must have done something wrong."
        ? input
        STOP 'stop for debug
      end if
    end if
End Function
  
Function checkAccount()
  ? "Checking Anonymous LBRY account"
  input = parsejson(GetRawText("https://api.lbry.com/user/me?auth_token="+m.top.authtoken))
  if input.success = true
    if IsValid(input.data)
      data = input.data
      if IsValid(data.id) AND IsValid(data.created_at)
        m.top.uid = data.id
      end if
      if IsValid(data.auth_token)
        m.top.authtoken = data.auth_token
      end if
      if IsValid(data.id) AND IsValid(data.created_at) AND IsValid(data.auth_token)
        return true
      end if
    else
      if createAccount() 'Our anonymous account expired. Create another.
        return true
      end if
      ' We stop inside the createAccount function, to have its scope.
    end if
  else
    if createAccount() 'Our anonymous account expired. Create another.
      return true
    end if 
    ' We stop inside the createAccount function, to have its scope.
  end if
End Function

Function exists(email)
  ' Why does LBRY require URL encoding with a POST when that is typically only done with GET?
  response = PostURLEncoded("https://api.lbry.com/user/exists", {auth_token: m.top.authtoken, email: email})
  ? response
  if response.success = true AND isValid(response.data)
    return true
  else
    ? response.data
    return false
  end if
End Function

Function me()
input = parsejson(GetRawText("https://api.lbry.com/user/me?auth_token="+m.top.authtoken))
if input.success = true
  if IsValid(input.data)
    data = input.data
    if IsValid(data.auth_token)
      m.top.authtoken = data.auth_token
    end if
    if IsValid(data.id) AND IsValid(data.created_at)
      m.top.uid = data.id
      return input.data 'Returns data of the endpoint for more flexibility in processing.
    end if
  else
    ? "The account does not exist. /me/ should not be called without a pre-existing account or under the one exception, which is WITHIN checkAccount"
    ? "The check account and create account functions should be the first thing to run in QueryLBRY. If your seeing this, either the API is broken,"
    ? "or, more likely, this spaghetti code broke somewhere. Returning the data so you can debug it."
    ? input
    STOP 'stop for debug
  end if
else
  ? "The API isn't responding correctly, we must have done something wrong."
  ? input
  STOP 'stop for debug
end if
End Function

Function login(email, password)
? "Logging into account: "+email
response = PostURLEncoded("https://api.lbry.com/user/signin", {auth_token: m.top.authtoken, email: email, password: password})
? response.data
if response.success = true AND isValid(response.data.primary_email)
  if IsValid(response.data.id) AND IsValid(response.data.created_at)
    m.top.uid = response.data.id
    return response 'Returns data of the endpoint for more flexibility in processing.
  end if
else
  ? "The API isn't responding correctly, we must have done something wrong."
  ? response
  STOP 'stop for debug
end if
End Function

Function getbal()
? "Getting balance for current account with uid "+m.top.uid.toStr()
response = QueryLBRYAPI({jsonrpc: "2.0", method: "wallet_balance", "id": m.top.uid})
if IsValid(response.result) AND IsValid(response.result.total)
  ? response.result.total
  return response.result.total
else
  ? "The API isn't responding correctly, we must have done something wrong."
  ? response
  ? response.error
  STOP 'stop for debug
end if
End Function

Function logout()
  input = PostURLEncoded("https://api.lbry.com/user/signout", {auth_token: m.top.authtoken})
  if input.success = true
    if IsValid(input.data)
      return True
    else
      ? "The API isn't responding correctly, we must have done something wrong."
      ? input
      STOP 'stop for debug
    end if
  end if
End Function

Function IsValid(value As Dynamic) As Boolean 'TheEndless Roku Development forums
    Return Type(value) <> "<uninitialized>" And value <> invalid
End Function