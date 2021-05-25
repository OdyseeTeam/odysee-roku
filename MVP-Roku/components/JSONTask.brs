Sub Init()
    m.top.functionName = "JSONTask"
End Sub

sub JSONTask()
    feed = ["PRIMARY_CONTENT", "CHEESE", "BIG_HITS", "GAMING", "SCIENCE", "TECHNOLOGY", "NEWS", "FINANCE", "THE_UNIVERSE"]
    final_output = {}
    for each key in feed
        final_output[key] = ManufacturePlaceholderVideoGrid(80, key)
    end for
    m.top.output = final_output
End Sub