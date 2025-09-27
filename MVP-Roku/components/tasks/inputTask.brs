Sub Init()
    'input=CreateObject("roInput")
    'm.port=createobject("roMessagePort")
    'input.setMessagePort(m.port)
    m.top.functionName = "listenInput"
End Sub

function ListenInput()
    port=createobject("romessageport")
    InputObject=createobject("roInput")
    InputObject.setmessageport(port)

    while true
      msg=port.waitmessage(500)
      if type(msg)="roInputEvent" then
        print "INPUT EVENT!"
        if msg.isInput()
          inputData = msg.getInfo()
          'print inputData'
          for each item in inputData
            print item  +": " inputData[item]
          end for

          ' pass the deeplink to UI
          if inputData.DoesExist("mediaType") and (inputData.DoesExist("contentID") or inputData.DoesExist("contentId"))
            contentId = ""
            if inputData.DoesExist("contentID")
              contentId = inputData.contentID
            else if inputData.DoesExist("contentId")
              contentId = inputData.contentId
            end if
            deeplink = {
                contentId: contentId
                type: inputData.mediaType
            }
            print "got input deeplink= "; deeplink
            m.top.inputData = deeplink
          end if
        end if
      end if
    end while
end function
