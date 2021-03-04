Sub Init()
    m.top.functionName = "master"
End Sub

sub master()
    feed = parsejson(GetRawText("https://roku.halitesoftware.com/odysee/trending.json"))
    final_output = {}
    for each key in feed
        final_output[key] = ManufactureVFeed(feed, key, m.top.thumbnaildims)
    end for
    m.top.output = final_output
End Sub