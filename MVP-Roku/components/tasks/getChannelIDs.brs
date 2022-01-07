Sub Init()
    m.top.functionName = "master"
End Sub

sub master()
    di = CreateObject("roDeviceInfo")
    fileSystem = CreateObject("roFileSystem")
    locale = di.GetCurrentLocale().split("_")[0] 'Extract Locale (odyseelogicdiagram) ((en, es, etc))
    ? "[CIDSTask]: Current locale is:"
    ? locale
    try
        if IsValid(getJSON(m.global.constants.frontpageURL).data[locale]) 'Use Locale (if exists) (odysee logic diagram)
            frontpageCIDS = getJSON(m.global.constants.frontpageURL).data[locale]
        else
            frontpageCIDS = getJSON(m.global.constants.frontpageURL).data["en"] 'default to english if all else fails
        end if
        'For each key:
        'channelIds = channelids
        'icon = icon
        'label = label
        locale = invalid
        categorySelectordata = CreateObject("roSGNode", "ContentNode")
        'create search icon
        dataItem = categorySelectordata.CreateChild("catselectordata")
        dataItem.posterUrl = "pkg:/images/png/Search.png"
        dataItem.labelText = "Search"
        ? "Creating categories"
        for each category in frontpageCIDS 'create categories for selector
            catData = frontpageCIDS[category]
            dataItem = categorySelectordata.CreateChild("catselectordata")
            if fileSystem.Exists("pkg:/images/png/"+catData.icon.replace(" ", "")+".png")
                dataItem.posterUrl = "pkg:/images/png/"+catData.icon.replace(" ", "")+".png"
              else
                if urlExists("https://raw.githubusercontent.com/OdyseeTeam/odysee-roku/indev/MVP-Roku/images/png/"+catData.icon.replace(" ", "")+".png")
                    dataItem.posterUrl = "https://raw.githubusercontent.com/OdyseeTeam/odysee-roku/indev/MVP-Roku/images/png/"+catData.icon.replace(" ", "")+".png"
                else
                    ? "No icon for "+catData.icon.replace(" ", "")
                    dataItem.posterUrl = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
                end if
            end if
            dataItem.trueName = category
            dataItem.labelText = catData.label
            catData = invalid 'save memory
        end for
        if frontpageCIDS.count() > 0
        m.top.categoryselectordata = categorySelectordata
        m.top.channelids = frontpageCIDS
        else
            m.top.error = true
        end if
    catch e
        m.top.error = true
    end try
    
End Sub