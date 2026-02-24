-- 配置文件 + 导入导出选项卡
local _, ns = ...

local L = ns.L
local UI = ns.UI

local function GetProfileList(db, excludeCurrent)
    local profiles = {}
    local order = {}
    local tmpProfiles = {}
    local current = db:GetCurrentProfile()
    for _, name in pairs(db:GetProfiles(tmpProfiles)) do
        if not (excludeCurrent and name == current) then
            profiles[name] = name
            order[#order + 1] = name
        end
    end
    table.sort(order)
    return profiles, order
end

local function GetSpecNames()
    local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
    local names = {}
    if isRetail then
        local _, classId = UnitClassBase("player")
        local numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(classId)
        for i = 1, numSpecs do
            local _, name = GetSpecializationInfoForClassID(classId, i)
            names[i] = name
        end
    else
        names[1] = TALENT_SPEC_PRIMARY or "Spec 1"
        names[2] = TALENT_SPEC_SECONDARY or "Spec 2"
    end
    return names
end

function ns.BuildProfilesTab(scroll)
    local AceGUI = LibStub("AceGUI-3.0")
    local db = ns.acedb
    local LibDualSpec = LibStub("LibDualSpec-1.0", true)

    local function RefreshTab()
        local tabs = ns._settingsFrame and ns._settingsFrame.children and ns._settingsFrame.children[1]
        if tabs and tabs.SelectTab then tabs:SelectTab("profiles") end
    end

    local desc = AceGUI:Create("Label")
    desc:SetText("|cffaaaaaa" .. L.profileDesc .. "|r")
    desc:SetFullWidth(true)
    desc:SetFontObject(GameFontHighlight)
    scroll:AddChild(desc)

    UI.AddHeading(scroll, "")

    local currentLabel = AceGUI:Create("Label")
    currentLabel:SetText(L.profileCurrent .. "  " .. NORMAL_FONT_COLOR_CODE .. db:GetCurrentProfile() .. FONT_COLOR_CODE_CLOSE)
    currentLabel:SetFullWidth(true)
    currentLabel:SetFontObject(GameFontNormalLarge)
    scroll:AddChild(currentLabel)

    UI.AddHeading(scroll, L.profileNew)

    local newDesc = AceGUI:Create("Label")
    newDesc:SetText("|cffaaaaaa" .. L.profileNewDesc .. "|r")
    newDesc:SetFullWidth(true)
    newDesc:SetFontObject(GameFontHighlightSmall)
    scroll:AddChild(newDesc)

    local newBox = AceGUI:Create("EditBox")
    newBox:SetLabel(L.profileNew)
    newBox:SetFullWidth(true)
    newBox:SetCallback("OnEnterPressed", function(_, _, val)
        val = val and val:match("^%s*(.-)%s*$")
        if not val or val == "" then return end
        if LibDualSpec and db.IsDualSpecEnabled and db:IsDualSpecEnabled() then
            db:SetDualSpecProfile(val)
        else
            db:SetProfile(val)
        end
        print("|cff00ccff[CDFlow]|r " .. format(L.profileCreated, val))
        RefreshTab()
    end)
    scroll:AddChild(newBox)

    UI.AddHeading(scroll, L.profileChoose)

    local chooseDesc = AceGUI:Create("Label")
    chooseDesc:SetText("|cffaaaaaa" .. L.profileChooseDesc .. "|r")
    chooseDesc:SetFullWidth(true)
    chooseDesc:SetFontObject(GameFontHighlightSmall)
    scroll:AddChild(chooseDesc)

    local profileItems, profileOrder = GetProfileList(db)
    local isDualSpecActive = LibDualSpec and db.IsDualSpecEnabled and db:IsDualSpecEnabled()

    local chooseDD = AceGUI:Create("Dropdown")
    chooseDD:SetLabel(L.profileChoose)
    chooseDD:SetList(profileItems, profileOrder)
    chooseDD:SetValue(db:GetCurrentProfile())
    chooseDD:SetFullWidth(true)
    if isDualSpecActive then
        chooseDD:SetDisabled(true)
    end
    chooseDD:SetCallback("OnValueChanged", function(_, _, val)
        db:SetProfile(val)
        print("|cff00ccff[CDFlow]|r " .. format(L.profileLoaded, val))
        RefreshTab()
    end)
    scroll:AddChild(chooseDD)

    local copyItems, copyOrder = GetProfileList(db, true)
    if next(copyItems) then
        UI.AddHeading(scroll, L.profileCopyFrom)

        local copyDesc = AceGUI:Create("Label")
        copyDesc:SetText("|cffaaaaaa" .. L.profileCopyDesc .. "|r")
        copyDesc:SetFullWidth(true)
        copyDesc:SetFontObject(GameFontHighlightSmall)
        scroll:AddChild(copyDesc)

        local copyDD = AceGUI:Create("Dropdown")
        copyDD:SetLabel(L.profileCopyFrom)
        copyDD:SetList(copyItems, copyOrder)
        copyDD:SetFullWidth(true)
        copyDD:SetCallback("OnValueChanged", function(_, _, val)
            db:CopyProfile(val)
            print("|cff00ccff[CDFlow]|r " .. format(L.profileCopied, val))
            RefreshTab()
        end)
        scroll:AddChild(copyDD)
    end

    local delItems, delOrder = GetProfileList(db, true)
    if next(delItems) then
        UI.AddHeading(scroll, L.profileDelete)

        local delDesc = AceGUI:Create("Label")
        delDesc:SetText("|cffaaaaaa" .. L.profileDeleteDesc .. "|r")
        delDesc:SetFullWidth(true)
        delDesc:SetFontObject(GameFontHighlightSmall)
        scroll:AddChild(delDesc)

        local delDD = AceGUI:Create("Dropdown")
        delDD:SetLabel(L.profileDelete)
        delDD:SetList(delItems, delOrder)
        delDD:SetFullWidth(true)
        scroll:AddChild(delDD)

        local pendingDel = false
        local delBtn = AceGUI:Create("Button")
        delBtn:SetText("|cffff4444" .. L.profileDelete .. "|r")
        delBtn:SetFullWidth(true)
        delBtn:SetCallback("OnClick", function()
            local selected = delDD:GetValue()
            if not selected then return end
            if selected == db:GetCurrentProfile() then
                print("|cff00ccff[CDFlow]|r " .. L.profileCantDeleteCurrent)
                return
            end
            if not pendingDel then
                pendingDel = true
                delBtn:SetText("|cffff4444" .. L.profileDeleteConfirm .. "|r")
                C_Timer.After(5, function()
                    if pendingDel then
                        pendingDel = false
                        delBtn:SetText("|cffff4444" .. L.profileDelete .. "|r")
                    end
                end)
            else
                pendingDel = false
                db:DeleteProfile(selected)
                print("|cff00ccff[CDFlow]|r " .. format(L.profileDeleted, selected))
                RefreshTab()
            end
        end)
        scroll:AddChild(delBtn)
    end

    if LibDualSpec and db.IsDualSpecEnabled then
        UI.AddHeading(scroll, L.specProfileEnable)

        local specDesc = AceGUI:Create("Label")
        specDesc:SetText("|cffaaaaaa" .. L.specProfileDesc .. "|r")
        specDesc:SetFullWidth(true)
        specDesc:SetFontObject(GameFontHighlightSmall)
        scroll:AddChild(specDesc)

        local specToggle = AceGUI:Create("CheckBox")
        specToggle:SetLabel("|cffffd200" .. L.specProfileEnable .. "|r")
        specToggle:SetValue(db:IsDualSpecEnabled())
        specToggle:SetFullWidth(true)
        scroll:AddChild(specToggle)

        local specGroup = AceGUI:Create("InlineGroup")
        specGroup:SetFullWidth(true)
        specGroup:SetLayout("Flow")
        scroll:AddChild(specGroup)

        local function RebuildSpecOptions()
            specGroup:ReleaseChildren()
            local enabled = db:IsDualSpecEnabled()
            chooseDD:SetDisabled(enabled)

            local specNames = GetSpecNames()
            local currentSpec = (GetSpecialization and GetSpecialization()) or 0
            local allProfiles, allOrder = GetProfileList(db)

            for i, specName in ipairs(specNames) do
                local label = (i == currentSpec) and format(L.specProfileCurrent, specName) or specName

                local dd = AceGUI:Create("Dropdown")
                dd:SetLabel(label)
                dd:SetList(allProfiles, allOrder)
                dd:SetValue(db:GetDualSpecProfile(i))
                dd:SetFullWidth(true)
                dd:SetDisabled(not enabled)
                dd:SetCallback("OnValueChanged", function(_, _, val)
                    db:SetDualSpecProfile(val, i)
                end)
                specGroup:AddChild(dd)
            end
        end

        specToggle:SetCallback("OnValueChanged", function(_, _, val)
            db:SetDualSpecEnabled(val)
            RebuildSpecOptions()
        end)

        RebuildSpecOptions()
    end

    UI.AddHeading(scroll, L.importExport)

    local exportBox = AceGUI:Create("MultiLineEditBox")
    exportBox:SetLabel(L.exportHint)
    exportBox:SetFullWidth(true)
    exportBox:SetNumLines(3)
    exportBox:SetText("")
    exportBox:DisableButton(true)
    scroll:AddChild(exportBox)

    local exportBtn = AceGUI:Create("Button")
    exportBtn:SetText(L.exportBtn)
    exportBtn:SetFullWidth(true)
    exportBtn:SetCallback("OnClick", function()
        local str = ns:ExportConfig()
        exportBox:SetText(str)
        exportBox:SetFocus()
        exportBox:HighlightText()
    end)
    scroll:AddChild(exportBtn)

    local importBox = AceGUI:Create("MultiLineEditBox")
    importBox:SetLabel(L.importHint)
    importBox:SetFullWidth(true)
    importBox:SetNumLines(3)
    importBox:SetText("")
    importBox:DisableButton(true)
    scroll:AddChild(importBox)

    local importGroup = AceGUI:Create("SimpleGroup")
    importGroup:SetFullWidth(true)
    importGroup:SetLayout("Flow")
    scroll:AddChild(importGroup)

    local importNameBox = AceGUI:Create("EditBox")
    importNameBox:SetLabel(L.importName)
    importNameBox:SetWidth(260)
    importNameBox:SetCallback("OnEnterPressed", function() end)
    importGroup:AddChild(importNameBox)

    local importBtn = AceGUI:Create("Button")
    importBtn:SetText(L.importBtn)
    importBtn:SetWidth(160)
    importBtn:SetCallback("OnClick", function()
        local name = importNameBox:GetText()
        if not name or name:match("^%s*$") then
            print("|cff00ccff[CDFlow]|r " .. L.profileNoName)
            return
        end
        name = name:match("^%s*(.-)%s*$")
        local str = importBox:GetText()
        if not str or str == "" then return end
        local ok, errMsg = ns:ImportConfig(str, name)
        if ok then
            print("|cff00ccff[CDFlow]|r " .. format(L.importSuccess, name))
            RefreshTab()
        else
            print("|cff00ccff[CDFlow]|r " .. format(L.importFail, errMsg or "unknown"))
        end
    end)
    importGroup:AddChild(importBtn)

    UI.AddHeading(scroll, "")

    local resetBtn = AceGUI:Create("Button")
    resetBtn:SetText(L.profileReset)
    resetBtn:SetFullWidth(true)
    local pendingReset = false
    resetBtn:SetCallback("OnClick", function()
        if not pendingReset then
            pendingReset = true
            resetBtn:SetText("|cffff4444" .. L.profileResetConfirm .. "|r")
            C_Timer.After(5, function()
                if pendingReset then
                    pendingReset = false
                    resetBtn:SetText(L.profileReset)
                end
            end)
        else
            pendingReset = false
            db:ResetProfile()
            print("|cff00ccff[CDFlow]|r " .. format(L.profileResetDone, db:GetCurrentProfile()))
            RefreshTab()
        end
    end)
    scroll:AddChild(resetBtn)
end
