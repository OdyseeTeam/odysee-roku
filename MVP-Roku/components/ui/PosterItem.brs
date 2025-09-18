sub Init()
    m.Poster = m.top.findNode("poster")
    m.ChannelIcon = m.top.findNode("channelIcon")
    m.liveDot = m.top.findNode("liveDot")
    m.liveDotBg = m.top.findNode("liveDotBg")
    m.Title = m.top.findNode("title")
    m.Published = m.top.findNode("published")
    m.LBC = m.top.findNode("lbc")
    m.Background = m.top.findNode("ibackground")
    m.Creator = m.top.findNode("creator")
    m.videoLength = m.top.findNode("videoLength")
    m.videoLengthBackground = m.top.findNode("lbackground")
    m.viewers = invalid
    m.viewersBackground = invalid
    m.viewersIcon = invalid
    m.repostIcon = m.top.findNode("repostIcon")
    m.repostedBy = m.top.findNode("repostedBy")
    m.repostedBackground = m.top.findNode("rbackground")
    m.placeholderOverlay = m.top.findNode("placeholderOverlay")
    m.placeholderPulse = m.top.findNode("placeholderPulse")
end sub
sub itemContentChanged()
    ' Ensure nodes exist (onChange can fire before init)
    if not isValid(m.Poster) then m.Poster = m.top.findNode("poster")
    if not isValid(m.ChannelIcon) then m.ChannelIcon = m.top.findNode("channelIcon")
    if not isValid(m.Background) then m.Background = m.top.findNode("ibackground")
    if not isValid(m.Title) then m.Title = m.top.findNode("title")
    if not isValid(m.Creator) then m.Creator = m.top.findNode("creator")
    if not isValid(m.Published) then m.Published = m.top.findNode("published")
    if not isValid(m.videoLength) then m.videoLength = m.top.findNode("videoLength")
    if not isValid(m.videoLengthBackground) then m.videoLengthBackground = m.top.findNode("lbackground")

    if isValid(m.Poster) and isValid(m.top.itemContent) then m.Poster.uri = m.top.itemContent.HDPOSTERURL
    ' Always show channel icons when provided; URIs are pre-optimized via CHANNEL_ICON_PROCESSOR
    if isValid(m.top.itemContent) and isValid(m.top.itemContent.ChannelIcon) and m.top.itemContent.ChannelIcon <> ""
        if isValid(m.ChannelIcon)
            m.ChannelIcon.uri = m.top.itemContent.ChannelIcon
            m.ChannelIcon.visible = true
        end if
    else
        if isValid(m.ChannelIcon) then m.ChannelIcon.visible = false
    end if
    m.Title.text = m.top.itemContent.TITLE
    m.Creator.text = m.top.itemContent.CREATOR
    m.Published.text = m.top.itemContent.RELEASEDATE
    if isValid(m.top.itemContent.ITEMTYPE)
        if m.top.itemContent.ITEMTYPE = "livestream"
            m.Background.color = "0x3f0000" ' darker backdrop
            m.liveDot.visible = true
            m.liveDotBg.visible = true
            if isValid(m.Poster) then m.Poster.loadDisplayMode = "limitSize"
            m.videoLength.visible = false
            m.videoLengthBackground.visible = false
            ' viewer chip
            if not isValid(m.viewers) then m.viewers = m.top.findNode("viewers")
            if not isValid(m.viewersBackground) then m.viewersBackground = m.top.findNode("vbackground")
            if not isValid(m.viewersIcon) then m.viewersIcon = m.top.findNode("viewersIcon")
            if isValid(m.top.itemContent.viewerDisplay) and m.top.itemContent.viewerDisplay <> ""
                m.viewers.text = m.top.itemContent.viewerDisplay
                m.viewers.visible = true
                m.viewersBackground.visible = true
                m.viewersIcon.visible = true
                m.viewersIcon.uri = "pkg:/images/png/eye.png"
                ' Dynamic width for background: icon (16) + gap (6) + text charWidth*len + padding
                charCount = Len(m.viewers.text)
                charWidth = 12
                bgWidth = 16 + 6 + (charCount * charWidth) + 12
                if bgWidth < 70 then bgWidth = 70
                if isValid(m.viewersBackground) then m.viewersBackground.width = bgWidth
                if isValid(m.viewers) then m.viewers.width = bgWidth - 22
            else
                if isValid(m.viewers) then m.viewers.visible = false
                if isValid(m.viewersBackground) then m.viewersBackground.visible = false
                if isValid(m.viewersIcon) then m.viewersIcon.visible = false
            end if
            ' Ensure placeholder pulse is off for non-placeholder
            if isValid(m.placeholderPulse) then m.placeholderPulse.control = "stop"
            if isValid(m.placeholderOverlay) then m.placeholderOverlay.visible = false
        else if m.top.itemContent.ITEMTYPE = "video"
            m.Background.color = "0x1f1f1f"
            if isValid(m.liveDot) then m.liveDot.visible = false
            if isValid(m.liveDotBg) then m.liveDotBg.visible = false
            if not isValid(m.viewers) then m.viewers = m.top.findNode("viewers")
            if not isValid(m.viewersBackground) then m.viewersBackground = m.top.findNode("vbackground")
            if not isValid(m.viewersIcon) then m.viewersIcon = m.top.findNode("viewersIcon")
            if isValid(m.viewers) then m.viewers.visible = false
            if isValid(m.viewersBackground) then m.viewersBackground.visible = false
            if isValid(m.viewersIcon) then m.viewersIcon.visible = false
            if isValid(m.placeholderPulse) then m.placeholderPulse.control = "stop"
            if isValid(m.placeholderOverlay) then m.placeholderOverlay.visible = false
        else if m.top.itemContent.ITEMTYPE = "channel"
            m.Background.color = "0x1f1f1f"
            if isValid(m.liveDot) then m.liveDot.visible = false
            if isValid(m.liveDotBg) then m.liveDotBg.visible = false
            m.videoLength.visible = false
            m.videoLengthBackground.visible = false
            m.Published.text = m.top.itemContent.FOLLOWERS
            ' Ensure channel tile has enough height for followers text
            if isValid(m.Background) then m.Background.height = 400
            if isValid(m.placeholderPulse) then m.placeholderPulse.control = "stop"
            if isValid(m.placeholderOverlay) then m.placeholderOverlay.visible = false
        else if LCase(m.top.itemContent.ITEMTYPE) = "placeholder"
            ' Keep reserved space but render empty
            if isValid(m.Poster) then m.Poster.uri = "pkg:/images/placeholder1x1.png"
            if isValid(m.Title) then m.Title.text = ""
            if isValid(m.Creator) then m.Creator.text = ""
            if isValid(m.Published) then m.Published.text = ""
            if isValid(m.videoLength) then m.videoLength.visible = false
            if isValid(m.videoLengthBackground) then m.videoLengthBackground.visible = false
            if isValid(m.liveDot) then m.liveDot.visible = false
            if isValid(m.liveDotBg) then m.liveDotBg.visible = false
            if isValid(m.viewers) then m.viewers.visible = false
            if isValid(m.viewersBackground) then m.viewersBackground.visible = false
            if isValid(m.viewersIcon) then m.viewersIcon.visible = false
            if isValid(m.ChannelIcon) then m.ChannelIcon.visible = false
            if not isValid(m.viewers) then m.viewers = m.top.findNode("viewers")
            if not isValid(m.viewersBackground) then m.viewersBackground = m.top.findNode("vbackground")
            if not isValid(m.viewersIcon) then m.viewersIcon = m.top.findNode("viewersIcon")
            if isValid(m.viewers) then m.viewers.visible = false
            if isValid(m.viewersBackground) then m.viewersBackground.visible = false
            if isValid(m.viewersIcon) then m.viewersIcon.visible = false
            ' Show pulse overlay
            if isValid(m.placeholderOverlay) then m.placeholderOverlay.visible = true
            if isValid(m.placeholderPulse) then m.placeholderPulse.control = "start"
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
            ' Adjust duration background width dynamically to fit text snugly
            charCount = Len(m.videoLength.text)
            charWidth = 12 'approx width per character at font size 24
            bgWidth = (charCount * charWidth) + 16 'padding
            if bgWidth < 70 then bgWidth = 70
            if bgWidth > 130 then bgWidth = 130
            m.videoLengthBackground.width = bgWidth
            m.videoLength.width = bgWidth - 10
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
        ' Poster area
        if isValid(m.Poster) then m.Poster.width = m.top.width - 20
        if isValid(m.Poster) then m.Poster.height = 220
        if not isValid(m.viewers) then m.viewers = m.top.findNode("viewers")
        if not isValid(m.viewersBackground) then m.viewersBackground = m.top.findNode("vbackground")
        if not isValid(m.viewersIcon) then m.viewersIcon = m.top.findNode("viewersIcon")
        ' Sync placeholder overlay to poster
        if isValid(m.placeholderOverlay)
            m.placeholderOverlay.width = m.Poster.width
            m.placeholderOverlay.height = m.Poster.height
            m.placeholderOverlay.translation = m.Poster.translation
        end if
        ' Duration pill pinned near poster bottom-left
        ' Bottom-left corner of poster with small inset
        if isValid(m.videoLengthBackground) and isValid(m.Poster) then m.videoLengthBackground.translation = [10, 10 + m.Poster.height - 32]
        if isValid(m.videoLength) and isValid(m.Poster) then m.videoLength.translation = [14, 10 + m.Poster.height - 35]
        if isValid(m.liveDot) and isValid(m.liveDotBg)
            ' Keep LIVE dot at top-left over poster area
            m.liveDotBg.translation = [10, 10]
            m.liveDot.translation = [18, 18]
        end if
        ' viewers chip baseline near duration pill
        if isValid(m.Poster)
            baseY = 10 + m.Poster.height - 32 'top of the chip background (height ~29)
            if isValid(m.viewersBackground) then m.viewersBackground.translation = [10, baseY]
            ' Center label vertically in the 29px bar (label height 32)
            if isValid(m.viewers) then m.viewers.translation = [32, baseY - 2]
            ' Center icon vertically relative to background height and icon height
            if isValid(m.viewersIcon)
                iconH = 16
                try
                    if isValid(m.viewersIcon.height) then iconH = m.viewersIcon.height
                catch e
                end try
                chipH = 29
                iconY = baseY + Int((chipH - iconH) / 2)
                m.viewersIcon.translation = [12, iconY]
            end if
        end if
        ' Title below poster, allow 2 lines without overlap
        if isValid(m.Title) then m.Title.translation = [10, 234]
        if isValid(m.Title) then m.Title.width = m.top.width - 20
        if isValid(m.Title) then m.Title.wrap = true
        ' Published/date below title
        if isValid(m.Published) then m.Published.translation = [10, 292]
        if isValid(m.Published) then m.Published.width = m.top.width - 20
        ' Bottom row: channel icon + creator
        if isValid(m.ChannelIcon) then m.ChannelIcon.translation = [10, m.top.height - 26]
        if isValid(m.Creator) then m.Creator.translation = [36, m.top.height - 30]
        if isValid(m.Creator) then m.Creator.width = m.top.width - 46
        ' Background
        if isValid(m.Background) then m.Background.width = m.top.width
        if isValid(m.Background) then m.Background.height = m.top.height
    end if
end sub
