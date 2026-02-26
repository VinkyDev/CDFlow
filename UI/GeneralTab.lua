-- 概览选项卡
local _, ns = ...

local L = ns.L
local UI = ns.UI

function ns.BuildGeneralTab(scroll)
    local AceGUI = LibStub("AceGUI-3.0")
    local mods = ns.db.modules

    local moduleGroup = AceGUI:Create("InlineGroup")
    moduleGroup:SetTitle(L.moduleManage)
    moduleGroup:SetFullWidth(true)
    moduleGroup:SetLayout("Flow")
    scroll:AddChild(moduleGroup)

    local reloadBtn = AceGUI:Create("Button")
    reloadBtn:SetText("|cffff8800/reload|r  -  " .. L.moduleReloadHint)
    reloadBtn:SetFullWidth(true)
    reloadBtn:SetCallback("OnClick", function() ReloadUI() end)
    moduleGroup:AddChild(reloadBtn)

    local cbBeautify = AceGUI:Create("CheckBox")
    cbBeautify:SetLabel(L.moduleCDMBeautify)
    cbBeautify:SetValue(mods.cdmBeautify)
    cbBeautify:SetFullWidth(true)
    cbBeautify:SetCallback("OnValueChanged", function(_, _, val) mods.cdmBeautify = val end)
    moduleGroup:AddChild(cbBeautify)

    local descBeautify = AceGUI:Create("Label")
    descBeautify:SetText("    |cffaaaaaa" .. L.moduleCDMBeautifyD .. "|r")
    descBeautify:SetFullWidth(true)
    descBeautify:SetFontObject(GameFontHighlightSmall)
    moduleGroup:AddChild(descBeautify)

    local cbMonitorBars = AceGUI:Create("CheckBox")
    cbMonitorBars:SetLabel(L.moduleMonitorBars)
    cbMonitorBars:SetValue(mods.monitorBars)
    cbMonitorBars:SetFullWidth(true)
    cbMonitorBars:SetCallback("OnValueChanged", function(_, _, val) mods.monitorBars = val end)
    moduleGroup:AddChild(cbMonitorBars)

    local descMB = AceGUI:Create("Label")
    descMB:SetText("    |cffaaaaaa" .. L.moduleMonitorBarsD .. "|r")
    descMB:SetFullWidth(true)
    descMB:SetFontObject(GameFontHighlightSmall)
    moduleGroup:AddChild(descMB)

    local cbTrackedBars = AceGUI:Create("CheckBox")
    cbTrackedBars:SetLabel(L.moduleTrackedBars)
    cbTrackedBars:SetValue(mods.trackedBars)
    cbTrackedBars:SetFullWidth(true)
    cbTrackedBars:SetCallback("OnValueChanged", function(_, _, val) mods.trackedBars = val end)
    moduleGroup:AddChild(cbTrackedBars)

    local descTB = AceGUI:Create("Label")
    descTB:SetText("    |cffaaaaaa" .. L.moduleTrackedBarsD .. "|r")
    descTB:SetFullWidth(true)
    descTB:SetFontObject(GameFontHighlightSmall)
    moduleGroup:AddChild(descTB)

    local cbItemMonitor = AceGUI:Create("CheckBox")
    cbItemMonitor:SetLabel(L.moduleItemMonitor)
    cbItemMonitor:SetValue(mods.itemMonitor)
    cbItemMonitor:SetFullWidth(true)
    cbItemMonitor:SetCallback("OnValueChanged", function(_, _, val) mods.itemMonitor = val end)
    moduleGroup:AddChild(cbItemMonitor)

    local descIM = AceGUI:Create("Label")
    descIM:SetText("    |cffaaaaaa" .. L.moduleItemMonitorD .. "|r")
    descIM:SetFullWidth(true)
    descIM:SetFontObject(GameFontHighlightSmall)
    moduleGroup:AddChild(descIM)

    if mods.cdmBeautify then

        UI.AddHeading(scroll, L.generalSettings)

        UI.AddSlider(scroll, L.iconZoom, 0, 0.3, 0.01,
            function() return ns.db.iconZoom end,
            function(v) ns.db.iconZoom = v end)

        UI.AddSlider(scroll, L.borderSize, 0, 4, 1,
            function() return ns.db.borderSize end,
            function(v) ns.db.borderSize = v end)

        UI.AddCheckbox(scroll, L.suppressDebuffBorder,
            function() return ns.db.suppressDebuffBorder or false end,
            function(v) ns.db.suppressDebuffBorder = v end)

        UI.AddHeading(scroll, L.visibilityRules)

        UI.AddDropdown(scroll, L.visibilityMode,
            {
                ALWAYS           = L.visModeAlways,
                COMBAT_ONLY      = L.visModeCombat,
                TARGET_ONLY      = L.visModeTarget,
                COMBAT_OR_TARGET = L.visModeCombatOrTarget,
            },
            { "ALWAYS", "COMBAT_ONLY", "TARGET_ONLY", "COMBAT_OR_TARGET" },
            function() return ns.db.visibility.mode end,
            function(v)
                ns.db.visibility.mode = v
                if ns.Visibility then ns.Visibility:Initialize() end
            end)

        UI.AddCheckbox(scroll, L.visHideMounted,
            function() return ns.db.visibility.hideWhenMounted end,
            function(v)
                ns.db.visibility.hideWhenMounted = v
                if ns.Visibility then ns.Visibility:Initialize() end
            end)

        UI.AddCheckbox(scroll, L.visHideVehicles,
            function() return ns.db.visibility.hideInVehicles end,
            function(v)
                ns.db.visibility.hideInVehicles = v
                if ns.Visibility then ns.Visibility:Initialize() end
            end)
    end

    UI.AddHeading(scroll, "")

    local editModeBtn = AceGUI:Create("Button")
    editModeBtn:SetText(L.openEditMode)
    editModeBtn:SetFullWidth(true)
    editModeBtn:SetCallback("OnClick", function()
        if InCombatLockdown() then return end
        local frame = _G.EditModeManagerFrame
        if not frame then
            local loader = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
            if loader and loader("Blizzard_EditMode") then
                frame = _G.EditModeManagerFrame
            end
        end
        if frame then
            if frame.CanEnterEditMode and not frame:CanEnterEditMode() then return end
            if frame:IsShown() then
                HideUIPanel(frame)
            else
                ShowUIPanel(frame)
            end
        end
    end)
    scroll:AddChild(editModeBtn)

    local cdmBtn = AceGUI:Create("Button")
    cdmBtn:SetText(L.openCDMSettings)
    cdmBtn:SetFullWidth(true)
    cdmBtn:SetCallback("OnClick", function()
        if InCombatLockdown() then return end
        if ns._settingsFrame then
            ns._settingsFrame:Release()
            ns._settingsFrame = nil
        end
        if SettingsPanel and SettingsPanel:IsShown() then
            HideUIPanel(SettingsPanel)
        end
        C_Timer.After(0.1, function()
            if CooldownViewerSettings and CooldownViewerSettings.ShowUIPanel then
                CooldownViewerSettings:ShowUIPanel(false)
            end
        end)
    end)
    scroll:AddChild(cdmBtn)
end
