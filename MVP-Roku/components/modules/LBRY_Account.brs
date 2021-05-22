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
        'STOP 'stop for debug
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

Function IsValid(value As Dynamic) As Boolean 'TheEndless Roku Development forums
    Return Type(value) <> "<uninitialized>" And value <> invalid
End Function