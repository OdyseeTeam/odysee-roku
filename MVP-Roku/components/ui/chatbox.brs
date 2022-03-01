function itemContentChanged()
    itemData = m.top.itemContent
    if isValid(itemData.usericon)
        if itemData.usericon.split("").Count() > 0 AND itemData.usericon.instr("http") > -1
            m.usericon.visible = true
            m.username.translation = [75,20]
            m.usericon.uri = ""
            m.usericon.uri = itemData.usericon
        else
            m.usericon.visible = false
            m.username.translation = [13,20]
        end if
    end if
    '? itemData.username
    '? m.usericon.uri
    '? itemData.message
    m.username.text = itemData.username
    m.message.text = itemData.message
    if itemData.height > 0
        m.message.height = itemData.height - 70
        m.background.height = itemData.height
    end if
end function

function init()
    m.usericon = m.top.findNode("usericon")
    m.username = m.top.findNode("username")
    m.message = m.top.findNode("message")
    m.background = m.top.findNode("background")
end function