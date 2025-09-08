sub Init()
    m.Poster = m.top.findNode("poster")
    m.liveIcon = m.top.findNode("liveIcon")
    m.Title = m.top.findNode("title")
    m.Published = m.top.findNode("published")
    m.LBC = m.top.findNode("lbc")
    m.Background = m.top.findNode("ibackground")
    m.Creator = m.top.findNode("creator")
    m.videoLength = m.top.findNode("videoLength")
    m.videoLengthBackground = m.top.findNode("lbackground")
    m.repostIcon = m.top.findNode("repostIcon")
    m.repostedBy = m.top.findNode("repostedBy")
    m.repostedBackground = m.top.findNode("rbackground")
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
            m.videoLength.visible = false
            m.videoLengthBackground.visible = false
        else if m.top.itemContent.ITEMTYPE = "video"
            m.Background.color = "0x1f1f1f"
            m.liveIcon.visible = false
        else if m.top.itemContent.ITEMTYPE = "channel"
            m.Background.color = "0x1f1f1f"
            m.liveIcon.visible = false
            m.videoLength.visible = false
            m.videoLengthBackground.visible = false
            m.Published.text = m.top.itemContent.FOLLOWERS
        end if
    end if
    if isValid(m.top.itemContent.reposted) AND isValid(m.top.itemContent.repostedBy)
        if m.top.itemContent.reposted
            m.repostIcon.visible = true
            m.repostedBy.visible = true
            m.repostedBackground.visible = true
            m.repostedBy.text = m.top.itemContent.repostedBy
        else
            m.repostIcon.visible = false
            m.repostedBy.visible = false
            m.repostedBackground.visible = false
        end if
    end if
    if isValid(m.top.itemContent.videolength) AND isValid(m.top.itemContent.ITEMTYPE)
        if m.top.itemContent.videolength <> "" AND m.top.itemContent.ITEMTYPE = "video"
            m.videoLength.visible = true
            m.videoLengthBackground.visible = true
            m.videoLength.text = m.top.itemContent.videolength
        end if
    end if
end sub
sub updateLayout()
    ' Ensure node refs exist (update can fire before init)
    if not isValid(m.Poster) then m.Poster = m.top.findNode("poster")
    if not isValid(m.Title) then m.Title = m.top.findNode("title")
    if not isValid(m.Published) then m.Published = m.top.findNode("published")
    if not isValid(m.liveIcon) then m.liveIcon = m.top.findNode("liveIcon")
    if not isValid(m.videoLength) then m.videoLength = m.top.findNode("videoLength")
    if not isValid(m.videoLengthBackground) then m.videoLengthBackground = m.top.findNode("lbackground")
    if not isValid(m.Background) then m.Background = m.top.findNode("ibackground")
    if not isValid(m.Creator) then m.Creator = m.top.findNode("creator")
    if m.top.height > 0 and m.top.width > 0 then
        if m.top.height > 349
            if isValid(m.Title) then m.Title.wrap = true
            if isValid(m.Published) then m.Published.translation=[10,277]
        else
            if isValid(m.Published) then m.Published.translation=[10,240]
            if isValid(m.Title) then m.Title.wrap = false
            if isValid(m.liveIcon) then m.liveIcon.visible = false
            if isValid(m.videoLength) then m.videoLength.visible = false
            if isValid(m.videoLengthBackground) then m.videoLengthBackground.visible = false
            if isValid(m.videoLength) then m.videoLength.text = ""
        end if
        if isValid(m.Poster) then m.Poster.width = m.top.width - 20
        if isValid(m.Poster) then m.Poster.height = 197
        if isValid(m.liveIcon) and isValid(m.Poster) then m.liveIcon.translation = [m.poster.width-160, m.poster.height-40]
        if isValid(m.Background) then m.Background.width = m.top.width
        if isValid(m.Background) then m.Background.height = m.top.height
        if isValid(m.Title) then m.Title.width = m.top.width - 20
        if isValid(m.Published) then m.Published.width = m.top.width - 20
        if isValid(m.Creator) then m.Creator.width = m.top.width - 20
    end if
end sub
