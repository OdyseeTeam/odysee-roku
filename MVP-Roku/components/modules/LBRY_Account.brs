' All account-related functions (Registry, ETC)
sub createAccount()
    '? "creating an account (makes new vars)"
    raw = queryLBRY("", "/user/new")
  end sub
  
sub checkAccount()
  '? "checking LBRY account (will refresh top)"
  queryLBRY("", "/user/me?auth_token="+m.top.authtoken)
end sub

Function GetRegistry(key) As Dynamic
     if m.registry.Exists(key)
         return m.registry.Read(key)
     endif
     return invalid
End Function

Function SetRegistry(key, value) As Void
  m.registry.Write(key, value)
  m.registry.Flush()
End Function
