sub Init()
    m.Poster = m.top.findNode("poster")
    m.liveIcon = m.top.findNode("liveIcon")
    m.Title = m.top.findNode("title")
    m.Published = m.top.findNode("published")
    m.LBC = m.top.findNode("lbc")
    m.Background = m.top.findNode("ibackground")
    m.Creator = m.top.findNode("creator")
end sub
sub itemContentChanged()
    m.Poster.uri = m.top.itemContent.HDPOSTERURL
    m.Title.text = m.top.itemContent.TITLE
    m.Creator.text = m.top.itemContent.CREATOR
    m.Published.text = m.top.itemContent.RELEASEDATE
    if isValid(m.top.itemContent.ITEMTYPE)
        if m.top.itemContent.ITEMTYPE = "livestream"
            m.Background.color = "#3f0000"
            m.liveIcon.visible = true
        else
            m.Background.color = "0x1f1f1f"
            m.liveIcon.visible = false
        end if
    end if
end sub
sub updateLayout()
    if m.top.height > 0 and m.top.width > 0 then
        if m.top.height > 349
            m.Title.wrap = true
        else
            m.Title.wrap = false
        end if
        m.Poster.width = m.top.width - 20
        m.Poster.loadwidth = m.poster.width
        m.Poster.height = 197
        m.poster.loadHeight = m.poster.height
        m.liveIcon.translation = [m.poster.width-160, m.poster.height-40]
        m.Background.width = m.top.width
        m.Background.height = m.top.height
        m.Title.width = m.top.width - 20
        m.Published.width = m.top.width - 20
        m.Creator.width = m.top.width - 20
    end if
end sub