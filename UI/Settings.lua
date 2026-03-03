-- 设置面板框架、选项卡路由、斜杠命令、Blizzard 面板注册
local _, ns = ...

local L = ns.L
local AceGUI

local CHANGELOG = {
    {
        "v3.3.1",
        "监控条像素整体优化，便于对齐并支持小数配置，支持御龙术时隐藏",
        "Buff堆叠监控条支持平滑动画",
        "Buff组偏移范围增大",
        "修复部分bug"
    },
    {
        "v3.3.0",
        "新增TTS自定义播报功能，可自定义播报文字或音效文件",
        "监控条添加仅御龙术时显示选项，可制作御龙术监控条",
        "新增小地图按钮"
    },
    { 
        "v3.2.0",
        "增加buff持续监测系统，防止更新不及时",
        "高亮特效添加技能可用高亮配置",
        "若干bug修复及体验优化",
    },
    { 
        "v3.1.0",
        "修复BUFF中间增长异常和固定模式bug",
    },
    { 
        "v3.0.0",
        "新增Buff分组功能",
        "新增物品监控模块，追踪状态栏拆分出单独模块",
        "若干bug修复及体验优化",
    },
}

local function BuildChangelog(entries)
    local lines = {}
    for _, entry in ipairs(entries) do
        lines[#lines + 1] = "|cffffd100" .. entry[1] .. "|r"
        for i = 2, #entry do
            lines[#lines + 1] = "  • " .. entry[i]
        end
        lines[#lines + 1] = ""
    end
    return table.concat(lines, "\n")
end

local CHANGELOG_TEXT = BuildChangelog(CHANGELOG)

local function ShowChangelog()
    if ns._changelogFrame then
        if ns._changelogFrame.frame:IsShown() then
            ns._changelogFrame.frame:Hide()
        else
            ns._changelogFrame.frame:Show()
        end
        return
    end

    local clFrame = AceGUI:Create("Frame")
    clFrame:SetTitle(L.changelog)
    clFrame:SetWidth(400)
    clFrame:SetHeight(500)
    clFrame:SetLayout("Fill")
    clFrame:EnableResize(false)
    clFrame:SetCallback("OnClose", function(widget)
        widget.frame:Hide()
    end)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    clFrame:AddChild(scroll)

    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetFontObject(GameFontHighlight)
    label:SetText(CHANGELOG_TEXT)
    scroll:AddChild(label)

    ns._changelogFrame = clFrame
end

local function GetTabList()
    local tabs = {
        { value = "general", text = L.general },
    }
    local mods = ns.db and ns.db.modules
    if not mods or mods.cdmBeautify then
        tabs[#tabs + 1] = { value = "essential",  text = L.essential }
        tabs[#tabs + 1] = { value = "utility",    text = L.utility }
        tabs[#tabs + 1] = { value = "buffs",      text = L.buffs }
        tabs[#tabs + 1] = { value = "buffGroups", text = L.buffGroups }
        tabs[#tabs + 1] = { value = "highlight",  text = L.highlight }
    end
    if not mods or mods.monitorBars then
        tabs[#tabs + 1] = { value = "monitorBars", text = L.monitorBars }
    end
    if not mods or mods.trackedBars then
        tabs[#tabs + 1] = { value = "trackedBars", text = L.trackedBars }
    end
    if not mods or mods.itemMonitor then
        tabs[#tabs + 1] = { value = "itemMonitor", text = L.itemMonitor }
    end
    if not mods or mods.tts then
        tabs[#tabs + 1] = { value = "tts", text = L.moduleTTS }
    end
    tabs[#tabs + 1] = { value = "profiles", text = L.profiles }
    return tabs
end

local function OnTabSelected(container, _, group)
    container:ReleaseChildren()

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    if group == "general" then
        ns.BuildGeneralTab(scroll)
    elseif group == "essential" then
        ns.BuildViewerTab(scroll, "essential", true, false)
    elseif group == "utility" then
        ns.BuildViewerTab(scroll, "utility", true, true)
    elseif group == "buffs" then
        ns.BuildViewerTab(scroll, "buffs", false, false)
    elseif group == "buffGroups" then
        if ns.BuildBuffGroupsTab then
            ns.BuildBuffGroupsTab(scroll)
        end
    elseif group == "itemMonitor" then
        if ns.BuildItemMonitorTab then
            ns.BuildItemMonitorTab(scroll)
        end
    elseif group == "trackedBars" then
            if ns.BuildTrackedBarsTab then
                ns.BuildTrackedBarsTab(scroll)
            end
    elseif group == "highlight" then
        ns.BuildHighlightTab(scroll)
    elseif group == "monitorBars" then
        if ns.BuildMonitorBarsTab then
            ns.BuildMonitorBarsTab(scroll)
        end
    elseif group == "tts" then
        if ns.BuildTTSTab then
            ns.BuildTTSTab(scroll)
        end
    elseif group == "profiles" then
        ns.BuildProfilesTab(scroll)
    end

    C_Timer.After(0, function()
        if scroll and scroll.DoLayout then
            scroll:DoLayout()
        end
    end)
end

local function ToggleSettings()
    if ns._settingsFrame then
        ns._settingsFrame:Release()
        ns._settingsFrame = nil
        return
    end

    local frame = AceGUI:Create("Frame")
    local ver = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("CDFlow", "Version")
        or GetAddOnMetadata and GetAddOnMetadata("CDFlow", "Version")
    frame:SetTitle("CDFlow" .. (ver and ("  v" .. ver) or ""))
    frame:SetWidth(520)
    frame:SetHeight(600)
    frame:SetLayout("Fill")
    frame:EnableResize(false)

    local f = frame.frame
    frame.titlebg:ClearAllPoints()
    frame.titlebg:SetPoint("TOP", f, "TOP", 0, 4)

    local dragBar = CreateFrame("Frame", nil, f)
    dragBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    dragBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    dragBar:SetHeight(32)
    dragBar:EnableMouse(true)
    dragBar:SetScript("OnMouseDown", function() f:StartMoving() end)
    dragBar:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)
    dragBar:SetFrameLevel(f:GetFrameLevel() + 5)

    local clBtn = CreateFrame("Button", nil, f)
    clBtn:SetSize(70, 20)
    clBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -7)
    clBtn:SetFrameLevel(dragBar:GetFrameLevel() + 1)
    local clText = clBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clText:SetAllPoints()
    clText:SetText("|cff999999" .. L.changelog .. "|r")
    clBtn:SetScript("OnEnter", function()
        clText:SetText("|cffffffff" .. L.changelog .. "|r")
    end)
    clBtn:SetScript("OnLeave", function()
        clText:SetText("|cff999999" .. L.changelog .. "|r")
    end)
    clBtn:SetScript("OnClick", ShowChangelog)

    frame.content:ClearAllPoints()
    frame.content:SetPoint("TOPLEFT", f, "TOPLEFT", 17, -38)
    frame.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -17, 40)

    local tabs = AceGUI:Create("TabGroup")
    tabs:SetTabs(GetTabList())
    tabs:SetLayout("Fill")
    tabs:SetCallback("OnGroupSelected", OnTabSelected)
    frame:AddChild(tabs)

    -- 底部快捷按钮：打开编辑模式 / 打开冷却管理器设置
    local function DoOpenEditMode()
        if InCombatLockdown() then
            print(L.cdmCombatLocked)
            return
        end
        local emFrame = _G.EditModeManagerFrame
        if not emFrame then
            local loader = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
            if loader then loader("Blizzard_EditMode") end
            emFrame = _G.EditModeManagerFrame
        end
        if emFrame then
            if emFrame.CanEnterEditMode and not emFrame:CanEnterEditMode() then return end
            if emFrame:IsShown() then HideUIPanel(emFrame) else ShowUIPanel(emFrame) end
        end
    end

    local function DoOpenCDMSettings()
        if InCombatLockdown() then
            print(L.cdmCombatLocked)
            return
        end
        local emFrame = _G.EditModeManagerFrame
        if emFrame and emFrame:IsShown() then
            print(L.cdmEditModeLocked)
            return
        end
        C_Timer.After(0.05, function()
            if CooldownViewerSettings and CooldownViewerSettings.ShowUIPanel then
                CooldownViewerSettings:ShowUIPanel(false)
            end
        end)
    end

    -- 与 AceGUI 关闭按钮对齐：closebutton 位于 BOTTOMRIGHT(-27,17) 高20，中心 y=27
    -- AceGUI Button 高度 24，底边 y=15 时中心 y=27，完全对齐
    local btnEM = AceGUI:Create("Button")
    btnEM:SetText(L.openEditMode)
    btnEM:SetWidth(160)
    btnEM.frame:SetParent(f)
    btnEM.frame:ClearAllPoints()
    btnEM.frame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 15)
    btnEM.frame:SetFrameLevel(f:GetFrameLevel() + 3)
    btnEM.frame:Show()
    btnEM:SetCallback("OnClick", DoOpenEditMode)

    local btnCDM = AceGUI:Create("Button")
    btnCDM:SetText(L.openCDMSettings)
    btnCDM:SetWidth(190)
    btnCDM.frame:SetParent(f)
    btnCDM.frame:ClearAllPoints()
    btnCDM.frame:SetPoint("LEFT", btnEM.frame, "RIGHT", 8, 0)
    btnCDM.frame:SetFrameLevel(f:GetFrameLevel() + 3)
    btnCDM.frame:Show()
    btnCDM:SetCallback("OnClick", DoOpenCDMSettings)

    frame:SetCallback("OnClose", function(widget)
        dragBar:Hide()
        clBtn:Hide()
        btnEM.frame:Hide()
        btnCDM.frame:Hide()
        widget:Release()
        ns._settingsFrame = nil
    end)

    tabs:SelectTab("general")
    ns._settingsFrame = frame
end

ns.ToggleSettings = ToggleSettings

function ns:InitSettings()
    AceGUI = LibStub("AceGUI-3.0")

    SLASH_CDFLOW1 = "/cdflow"
    SLASH_CDFLOW2 = "/cdf"
    SlashCmdList["CDFLOW"] = ToggleSettings

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local panel = CreateFrame("Frame")
        panel:SetSize(600, 300)

        local LOGO_PATH = "Interface\\AddOns\\CDFlow\\Media\\logo"

        local logo = panel:CreateTexture(nil, "ARTWORK")
        logo:SetSize(64, 64)
        logo:SetPoint("TOPLEFT", 20, -20)
        logo:SetTexture(LOGO_PATH)

        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -4)
        title:SetText("|cff00ccffCDFlow|r")

        local version
        if C_AddOns and C_AddOns.GetAddOnMetadata then
            version = C_AddOns.GetAddOnMetadata("CDFlow", "Version")
        elseif GetAddOnMetadata then
            version = GetAddOnMetadata("CDFlow", "Version")
        end
        local ver = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ver:SetPoint("LEFT", title, "RIGHT", 8, 0)
        ver:SetText("|cff888888v" .. version .. "|r")

        local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        desc:SetWidth(460)
        desc:SetJustifyH("LEFT")
        desc:SetText(L.aboutDesc)

        local author = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        author:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -16)
        author:SetText(L.aboutAuthor .. ":  |cffffffffVinky|r")

        local github = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        github:SetPoint("TOPLEFT", author, "BOTTOMLEFT", 0, -6)
        github:SetText(L.aboutGithub .. ": |cffffffffVinkyDev/CDFlow|r")

        local cmdTip = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cmdTip:SetPoint("TOPLEFT", github, "BOTTOMLEFT", 0, -14)
        cmdTip:SetText("|cff888888" .. L.slashHelp .. "|r")

        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(160, 28)
        btn:SetPoint("TOPLEFT", cmdTip, "BOTTOMLEFT", 0, -10)
        btn:SetText(L.openSettings)
        btn:SetScript("OnClick", function()
            ToggleSettings()
            if SettingsPanel and SettingsPanel:IsShown() then
                HideUIPanel(SettingsPanel)
            end
        end)

        local category = Settings.RegisterCanvasLayoutCategory(panel, "CDFlow", "CDFlow")
        Settings.RegisterAddOnCategory(category)
        ns.settingsCategory = category
    end
end
