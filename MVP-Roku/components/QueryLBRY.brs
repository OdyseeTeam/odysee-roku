Sub Init()
    m.top.functionName = "master"
End Sub

sub master()
    if m.top.query.endpoint = ""
        output = QueryLBRYAPI(m.top.query.query, m.top.cookies)
    else
        output = QueryLBRYcom(m.top.query.endpoint, m.top.query.query, m.top.cookies)
    end if
    m.resp = ""
    m.cookies = ""
    m.top.resp = output[0]
    m.top.cookies = output[1]
End Sub