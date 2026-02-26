-- 设置面板框架、选项卡路由、斜杠命令、Blizzard 面板注册
local _, ns = ...

local L = ns.L
local AceGUI

local function GetTabList()
    local tabs = {
        { value = "general", text = L.general },
    }
    local mods = ns.db and ns.db.modules
    if not mods or mods.cdmBeautify then
        tabs[#tabs + 1] = { value = "essential",   text = L.essential }
        tabs[#tabs + 1] = { value = "utility",     text = L.utility }
        tabs[#tabs + 1] = { value = "buffs",       text = L.buffs }
        tabs[#tabs + 1] = { value = "buffGroups",  text = L.buffGroups }
        tabs[#tabs + 1] = { value = "trackedBars", text = L.trackedBars }
        tabs[#tabs + 1] = { value = "highlight",   text = L.highlight }
    end
    if not mods or mods.monitorBars then
        tabs[#tabs + 1] = { value = "monitorBars", text = L.monitorBars }
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
        ns.BuildViewerTab(scroll, "utility", true, false)
    elseif group == "buffs" then
        ns.BuildViewerTab(scroll, "buffs", false, false)
    elseif group == "buffGroups" then
        if ns.BuildBuffGroupsTab then
            ns.BuildBuffGroupsTab(scroll)
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
    frame:SetCallback("OnClose", function(widget)
        widget:Release()
        ns._settingsFrame = nil
    end)
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

    frame.content:ClearAllPoints()
    frame.content:SetPoint("TOPLEFT", f, "TOPLEFT", 17, -38)
    frame.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -17, 40)

    local tabs = AceGUI:Create("TabGroup")
    tabs:SetTabs(GetTabList())
    tabs:SetLayout("Fill")
    tabs:SetCallback("OnGroupSelected", OnTabSelected)
    frame:AddChild(tabs)

    tabs:SelectTab("general")
    ns._settingsFrame = frame
end

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
