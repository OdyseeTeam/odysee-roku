sub Init()
    m.top.functionName = "master"
end sub

sub master()
    di = CreateObject("roDeviceInfo")
    fileSystem = CreateObject("roFileSystem")
    locale = di.GetCurrentLocale().split("_")[0] 'Extract Locale (odyseelogicdiagram) ((en, es, etc))
    ?"[CIDSTask]: Current locale is:"
    ?locale
    try
        fpURL = m.top.constants.frontpageURL
        fpURL = "https://kp.odysee.com/$/api/content/v2/get?format=roku"
        if IsValid(getJSON(fpURL).data[locale]) 'Use Locale (if exists) (odysee logic diagram)
            frontpageCIDS = getJSON(fpURL).data[locale].categories
        else
            frontpageCIDS = getJSON(fpURL).data["en"].categories 'default to english if all else fails
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
        dataItem = categorySelectordata.CreateChild("catselectordata")
        dataItem.posterUrl = "pkg:/images/png/Heart.png"
        dataItem.labelText = "Following"
        ?"Creating categories"
        legacyFormatFrontpageCIDS = {} 'until I change HomeScene.
        for each category in frontpageCIDS 'create categories for selector
            dataItem = categorySelectordata.CreateChild("catselectordata")
            if fileSystem.Exists("pkg:/images/png/" + category.icon.replace(" ", "") + ".png")
                dataItem.posterUrl = "pkg:/images/png/" + category.icon.replace(" ", "") + ".png"
            else
                if urlExists("https://raw.githubusercontent.com/OdyseeTeam/odysee-roku/indev/MVP-Roku/images/png/" + category.icon.replace(" ", "") + ".png")
                    dataItem.posterUrl = "https://raw.githubusercontent.com/OdyseeTeam/odysee-roku/indev/MVP-Roku/images/png/" + category.icon.replace(" ", "") + ".png"
                else
                    dataItem.posterUrl = "pkg:/images/generic/bad_icon_requires_usage_rights.png"
                end if
            end if
            dataItem.trueName = category.name
            dataItem.labelText = category.label
            legacyFormatFrontpageCIDS.addReplace(category.name, category)
        end for
        if frontpageCIDS.count() > 0
            m.top.categoryselectordata = categorySelectordata
            m.top.channelids = legacyFormatFrontpageCIDS
        else
            m.top.error = true
        end if
    catch e
        m.top.error = true
    end try
end sub