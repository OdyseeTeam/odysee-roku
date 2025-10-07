sub Init()
    m.background = m.top.findNode("background")
    m.focusIndicator = m.top.findNode("focusIndicator")
    m.channelThumb = m.top.findNode("channelThumb")
    m.channelTitle = m.top.findNode("channelTitle")
    m.channelUploads = m.top.findNode("channelUploads")

    m.top.focusable = true
    m.top.observeField("focusedChild", "onFocusChanged")

    print "[ChannelTile] Init called"
end sub

sub updateContent()
    content = m.top.itemContent
    print "[ChannelTile] updateContent called, content: "; content

    if content <> invalid
        print "[ChannelTile] Content title: "; content.title

        ' Set channel title
        if content.title <> invalid and content.title <> ""
            m.channelTitle.text = content.title
            print "[ChannelTile] Set title to: "; content.title
        end if

        ' Set channel thumbnail
        if content.channelThumb <> invalid and content.channelThumb <> ""
            m.channelThumb.uri = content.channelThumb
        else
            m.channelThumb.uri = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
        end if

        ' Set upload count
        if content.videoCount <> invalid and content.videoCount <> ""
            m.channelUploads.text = content.videoCount
        end if
    else
        print "[ChannelTile] Content is invalid!"
    end if
end sub

sub onFocusChanged()
    if m.top.hasFocus()
        ' Show focus indicator
        m.focusIndicator.opacity = 1.0
    else
        ' Hide focus indicator
        m.focusIndicator.opacity = 0.0
    end if
end sub
