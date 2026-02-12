local _, ns = ...

------------------------------------------------------
-- 设置模块
------------------------------------------------------

local L = ns.L
local Layout = ns.Layout
local Style  = ns.Style
local AceGUI

-- 设置面板引用（用于 toggle）
local settingsFrame = nil

------------------------------------------------------
-- 选项列表
------------------------------------------------------
local DIR_ITEMS = {
    ["CENTER"]  = L.dirCenter,
    ["DEFAULT"] = L.dirDefault,
}

local OUTLINE_ITEMS = {
    ["NONE"]         = L.outNone,
    ["OUTLINE"]      = L.outOutline,
    ["THICKOUTLINE"] = L.outThick,
}

local POS_ITEMS = {
    ["TOPLEFT"]     = L.posTL,
    ["TOPRIGHT"]    = L.posTR,
    ["BOTTOMLEFT"]  = L.posBL,
    ["BOTTOMRIGHT"] = L.posBR,
}

local HL_ITEMS = {
    ["DEFAULT"]  = L.hlDefault,
    ["PIXEL"]    = L.hlPixel,
    ["AUTOCAST"] = L.hlAutocast,
    ["PROC"]     = L.hlProc,
    ["BUTTON"]   = L.hlButton,
    ["NONE"]     = L.hlNone,
}

------------------------------------------------------
-- AceGUI
------------------------------------------------------

local function AddHeading(parent, text)
    local w = AceGUI:Create("Heading")
    w:SetText(text)
    w:SetFullWidth(true)
    parent:AddChild(w)
end

local function AddCheckbox(parent, label, getValue, setValue)
    local w = AceGUI:Create("CheckBox")
    w:SetLabel(label)
    w:SetValue(getValue())
    w:SetFullWidth(true)
    w:SetCallback("OnValueChanged", function(_, _, val)
        setValue(val)
        Layout:RefreshAll()
    end)
    parent:AddChild(w)
    return w
end

local function AddSlider(parent, label, minVal, maxVal, step, getValue, setValue)
    local w = AceGUI:Create("Slider")
    w:SetLabel(label)
    w:SetSliderValues(minVal, maxVal, step)
    w:SetValue(getValue())
    w:SetIsPercent(false)
    w:SetFullWidth(true)
    w:SetCallback("OnValueChanged", function(_, _, val)
        setValue(val)
        Layout:RefreshAll()
    end)
    parent:AddChild(w)
    return w
end

local function AddDropdown(parent, label, items, order, getValue, setValue)
    local w = AceGUI:Create("Dropdown")
    w:SetLabel(label)
    w:SetList(items, order)
    w:SetValue(getValue())
    w:SetFullWidth(true)
    w:SetCallback("OnValueChanged", function(_, _, val)
        setValue(val)
        Layout:RefreshAll()
    end)
    parent:AddChild(w)
    return w
end

------------------------------------------------------
-- 构建「概览」选项卡
------------------------------------------------------
local function BuildGeneralTab(scroll)
    -- 使用方法
    AddHeading(scroll, L.general)

    local usage = AceGUI:Create("Label")
    usage:SetText(L.overviewUsage)
    usage:SetFullWidth(true)
    usage:SetFontObject(GameFontHighlight)
    scroll:AddChild(usage)

    -- Tips 提示（橙色醒目）
    local tipGroup = AceGUI:Create("InlineGroup")
    tipGroup:SetTitle("|cffff8800Tips|r")
    tipGroup:SetFullWidth(true)
    tipGroup:SetLayout("Flow")
    scroll:AddChild(tipGroup)

    local tipLabel = AceGUI:Create("Label")
    tipLabel:SetText("|cffff8800" .. L.overviewTip .. "|r")
    tipLabel:SetFullWidth(true)
    tipLabel:SetFontObject(GameFontHighlightSmall)
    tipGroup:AddChild(tipLabel)

    -- 通用配置
    AddHeading(scroll, L.generalSettings)

    AddSlider(scroll, L.iconZoom, 0, 0.3, 0.01,
        function() return ns.db.iconZoom end,
        function(v) ns.db.iconZoom = v end)

    AddSlider(scroll, L.borderSize, 0, 4, 1,
        function() return ns.db.borderSize end,
        function(v) ns.db.borderSize = v end)
end

local function AddColorPicker(parent, label, getColor, setColor)
    local w = AceGUI:Create("ColorPicker")
    w:SetLabel(label)
    local c = getColor()
    w:SetColor(c[1] or 1, c[2] or 1, c[3] or 0.3, c[4] or 1)
    w:SetHasAlpha(true)
    w:SetFullWidth(true)
    w:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a)
        setColor({ r, g, b, a })
        Layout:RefreshAll()
    end)
    parent:AddChild(w)
    return w
end

------------------------------------------------------
-- 「高亮特效」选项卡
------------------------------------------------------
local function BuildHighlightTab(scroll)
    local cfg = ns.db.highlight

    -- 设置变更后刷新所有活跃的高亮特效
    local function refreshGlows()
        Style:RefreshAllGlows()
    end

    AddHeading(scroll, L.highlight)

    -- 样式选择
    local dd = AceGUI:Create("Dropdown")
    dd:SetLabel(L.hlStyle)
    dd:SetList(HL_ITEMS, { "DEFAULT", "PIXEL", "AUTOCAST", "PROC", "BUTTON", "NONE" })
    dd:SetValue(cfg.style)
    dd:SetFullWidth(true)
    dd:SetCallback("OnValueChanged", function(_, _, v) cfg.style = v; refreshGlows() end)
    scroll:AddChild(dd)

    -- 颜色
    local cp = AceGUI:Create("ColorPicker")
    cp:SetLabel(L.hlColor)
    cp:SetColor(cfg.color[1], cfg.color[2], cfg.color[3], cfg.color[4])
    cp:SetHasAlpha(true)
    cp:SetFullWidth(true)
    cp:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a)
        cfg.color = { r, g, b, a }; refreshGlows()
    end)
    scroll:AddChild(cp)

    -- 像素发光：线条数量
    local s1 = AceGUI:Create("Slider")
    s1:SetLabel(L.hlLines); s1:SetSliderValues(1, 16, 1)
    s1:SetValue(cfg.lines); s1:SetFullWidth(true)
    s1:SetCallback("OnValueChanged", function(_, _, v) cfg.lines = v; refreshGlows() end)
    scroll:AddChild(s1)

    -- 像素发光：线条粗细
    local s2 = AceGUI:Create("Slider")
    s2:SetLabel(L.hlThickness); s2:SetSliderValues(1, 5, 1)
    s2:SetValue(cfg.thickness); s2:SetFullWidth(true)
    s2:SetCallback("OnValueChanged", function(_, _, v) cfg.thickness = v; refreshGlows() end)
    scroll:AddChild(s2)

    -- 动画速度
    local s3 = AceGUI:Create("Slider")
    s3:SetLabel(L.hlFrequency); s3:SetSliderValues(0.05, 1, 0.05)
    s3:SetValue(cfg.frequency); s3:SetFullWidth(true)
    s3:SetCallback("OnValueChanged", function(_, _, v) cfg.frequency = v; refreshGlows() end)
    scroll:AddChild(s3)

    -- 自动施法：缩放
    local s4 = AceGUI:Create("Slider")
    s4:SetLabel(L.hlScale); s4:SetSliderValues(0.5, 2, 0.1)
    s4:SetValue(cfg.scale); s4:SetFullWidth(true)
    s4:SetCallback("OnValueChanged", function(_, _, v) cfg.scale = v; refreshGlows() end)
    scroll:AddChild(s4)
end

------------------------------------------------------
-- 「行尺寸覆盖」区块
------------------------------------------------------
local function BuildRowOverrides(scroll, viewerKey)
    local cfg = ns.db[viewerKey]

    AddHeading(scroll, L.rowOverrides)

    -- 内容容器（下拉切换时刷新）
    local contentGroup = AceGUI:Create("InlineGroup")
    contentGroup:SetLayout("Flow")
    contentGroup:SetFullWidth(true)

    local selectedRow = 1

    local function RebuildRowContent()
        contentGroup:ReleaseChildren()
        contentGroup:SetTitle(format(L.rowN, selectedRow))

        local row = selectedRow
        local ov = cfg.rowOverrides[row]
        local wSlider, hSlider

        -- 启用复选框
        local cb = AceGUI:Create("CheckBox")
        cb:SetLabel(L.enable)
        cb:SetValue(ov ~= nil)
        cb:SetFullWidth(true)
        cb:SetCallback("OnValueChanged", function(_, _, val)
            if val then
                cfg.rowOverrides[row] = {
                    width  = math.floor(wSlider.value or cfg.iconWidth),
                    height = math.floor(hSlider.value or cfg.iconHeight),
                }
            else
                cfg.rowOverrides[row] = nil
            end
            wSlider:SetDisabled(not val)
            hSlider:SetDisabled(not val)
            Layout:RefreshAll()
        end)
        contentGroup:AddChild(cb)

        -- 宽度滑块
        wSlider = AceGUI:Create("Slider")
        wSlider:SetLabel(L.width)
        wSlider:SetSliderValues(16, 80, 1)
        wSlider:SetValue(ov and ov.width or cfg.iconWidth)
        wSlider:SetFullWidth(true)
        wSlider:SetDisabled(ov == nil)
        wSlider:SetCallback("OnValueChanged", function(_, _, v)
            if cfg.rowOverrides[row] then
                cfg.rowOverrides[row].width = math.floor(v)
                Layout:RefreshAll()
            end
        end)
        contentGroup:AddChild(wSlider)

        -- 高度滑块
        hSlider = AceGUI:Create("Slider")
        hSlider:SetLabel(L.height)
        hSlider:SetSliderValues(16, 80, 1)
        hSlider:SetValue(ov and ov.height or cfg.iconHeight)
        hSlider:SetFullWidth(true)
        hSlider:SetDisabled(ov == nil)
        hSlider:SetCallback("OnValueChanged", function(_, _, v)
            if cfg.rowOverrides[row] then
                cfg.rowOverrides[row].height = math.floor(v)
                Layout:RefreshAll()
            end
        end)
        contentGroup:AddChild(hSlider)
    end

    -- 行选择下拉
    local ROW_LIST = {}
    for i = 1, 3 do ROW_LIST[i] = format(L.rowN, i) end

    local dd = AceGUI:Create("Dropdown")
    dd:SetLabel(L.rowSelect)
    dd:SetList(ROW_LIST, { 1, 2, 3 })
    dd:SetValue(1)
    dd:SetFullWidth(true)
    dd:SetCallback("OnValueChanged", function(_, _, val)
        selectedRow = val
        RebuildRowContent()
    end)
    scroll:AddChild(dd)
    scroll:AddChild(contentGroup)

    RebuildRowContent()
end

------------------------------------------------------
-- 「查看器」选项卡
------------------------------------------------------
local function BuildViewerTab(scroll, viewerKey, showPerRow)
    local cfg = ns.db[viewerKey]

    AddCheckbox(scroll, L.enable,
        function() return cfg.enabled end,
        function(v) cfg.enabled = v end)

    AddDropdown(scroll, L.growDir, DIR_ITEMS,
        { "CENTER", "DEFAULT" },
        function() return cfg.growDir end,
        function(v) cfg.growDir = v end)

    if showPerRow then
        AddSlider(scroll, L.iconsPerRow, 1, 12, 1,
            function() return cfg.iconsPerRow end,
            function(v) cfg.iconsPerRow = v end)
    end

    AddSlider(scroll, L.iconWidth, 16, 80, 1,
        function() return cfg.iconWidth end,
        function(v) cfg.iconWidth = v end)

    AddSlider(scroll, L.iconHeight, 16, 80, 1,
        function() return cfg.iconHeight end,
        function(v) cfg.iconHeight = v end)

    AddSlider(scroll, L.spacingX, 0, 20, 1,
        function() return cfg.spacingX end,
        function(v) cfg.spacingX = v end)

    AddSlider(scroll, L.spacingY, 0, 20, 1,
        function() return cfg.spacingY end,
        function(v) cfg.spacingY = v end)

    -- 特色功能：行尺寸覆盖
    BuildRowOverrides(scroll, viewerKey)
end

------------------------------------------------------
-- 「堆叠文字」选项卡
------------------------------------------------------
local function BuildStackTab(scroll)
    local cfg = ns.db.stack

    AddHeading(scroll, L.stackText)

    AddCheckbox(scroll, L.enable,
        function() return cfg.enabled end,
        function(v) cfg.enabled = v end)

    AddSlider(scroll, L.fontSize, 6, 24, 1,
        function() return cfg.fontSize end,
        function(v) cfg.fontSize = v end)

    AddDropdown(scroll, L.outline, OUTLINE_ITEMS,
        { "NONE", "OUTLINE", "THICKOUTLINE" },
        function() return cfg.outline end,
        function(v) cfg.outline = v end)

    AddDropdown(scroll, L.position, POS_ITEMS,
        { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" },
        function() return cfg.point end,
        function(v) cfg.point = v end)

    AddSlider(scroll, L.offsetX, -20, 20, 1,
        function() return cfg.offsetX end,
        function(v) cfg.offsetX = v end)

    AddSlider(scroll, L.offsetY, -20, 20, 1,
        function() return cfg.offsetY end,
        function(v) cfg.offsetY = v end)
end

------------------------------------------------------
-- 选项卡定义
------------------------------------------------------
local TAB_LIST = {
    { value = "general",   text = L.general },
    { value = "essential", text = L.essential },
    { value = "utility",   text = L.utility },
    { value = "buffs",     text = L.buffs },
    { value = "highlight", text = L.highlight },
    { value = "stack",     text = L.stackText },
}

local function OnTabSelected(container, _, group)
    container:ReleaseChildren()

    -- 包裹滚动区域，处理内容溢出
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    if group == "general" then
        BuildGeneralTab(scroll)
    elseif group == "essential" then
        BuildViewerTab(scroll, "essential", true)
    elseif group == "utility" then
        BuildViewerTab(scroll, "utility", true)
    elseif group == "buffs" then
        BuildViewerTab(scroll, "buffs", false)
    elseif group == "highlight" then
        BuildHighlightTab(scroll)
    elseif group == "stack" then
        BuildStackTab(scroll)
    end

    -- 延迟一帧重新布局，确保嵌套容器高度计算正确
    C_Timer.After(0, function()
        if scroll and scroll.DoLayout then
            scroll:DoLayout()
        end
    end)
end

------------------------------------------------------
-- 打开设置面板
------------------------------------------------------
local function ToggleSettings()
    if settingsFrame then
        settingsFrame:Release()
        settingsFrame = nil
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("CDFlow")
    frame:SetWidth(520)
    frame:SetHeight(600)
    frame:SetLayout("Fill")
    frame:SetCallback("OnClose", function(widget)
        widget:Release()
        settingsFrame = nil
    end)
    frame:EnableResize(false)

    -- 标题下移，增加上边距（原始 titlebg 锚点为 TOP 0 12）
    local f = frame.frame
    frame.titlebg:ClearAllPoints()
    frame.titlebg:SetPoint("TOP", f, "TOP", 0, 4)

    -- 扩大拖拽区域为整行宽度
    local dragBar = CreateFrame("Frame", nil, f)
    dragBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    dragBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    dragBar:SetHeight(32)
    dragBar:EnableMouse(true)
    dragBar:SetScript("OnMouseDown", function() f:StartMoving() end)
    dragBar:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)
    dragBar:SetFrameLevel(f:GetFrameLevel() + 5)

    -- 增加标题与 Tab 之间的间距
    frame.content:ClearAllPoints()
    frame.content:SetPoint("TOPLEFT", f, "TOPLEFT", 17, -38)
    frame.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -17, 40)

    local tabs = AceGUI:Create("TabGroup")
    tabs:SetTabs(TAB_LIST)
    tabs:SetLayout("Fill")
    tabs:SetCallback("OnGroupSelected", OnTabSelected)
    frame:AddChild(tabs)

    -- 默认选中通用选项卡
    tabs:SelectTab("general")
    settingsFrame = frame
end

------------------------------------------------------
-- 初始化
------------------------------------------------------
function ns:InitSettings()
    AceGUI = LibStub("AceGUI-3.0")

    -- 斜杠命令
    SLASH_CDFLOW1 = "/cdflow"
    SLASH_CDFLOW2 = "/cdf"
    SlashCmdList["CDFLOW"] = ToggleSettings

    -- 注册到 Blizzard Settings
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local panel = CreateFrame("Frame")
        panel:SetSize(600, 300)

        local LOGO_PATH = "Interface\\AddOns\\CDFlow\\Media\\logo"

        -- Logo
        local logo = panel:CreateTexture(nil, "ARTWORK")
        logo:SetSize(64, 64)
        logo:SetPoint("TOPLEFT", 20, -20)
        logo:SetTexture(LOGO_PATH)

        -- 标题
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -4)
        title:SetText("|cff00ccffCDFlow|r")

        -- 版本号
        local ver = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ver:SetPoint("LEFT", title, "RIGHT", 8, 0)
        ver:SetText("|cff888888v1.0.0|r")

        -- 简介
        local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        desc:SetWidth(460)
        desc:SetJustifyH("LEFT")
        desc:SetText(L.aboutDesc)

        -- 作者
        local author = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        author:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -16)
        author:SetText(L.aboutAuthor .. ":  |cffffffffVinky|r")

        -- GitHub
        local github = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        github:SetPoint("TOPLEFT", author, "BOTTOMLEFT", 0, -6)
        github:SetText(L.aboutGithub .. ": |cffffffffVinkyDev/CDFlow|r")

        -- 命令提示
        local cmdTip = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cmdTip:SetPoint("TOPLEFT", github, "BOTTOMLEFT", 0, -14)
        cmdTip:SetText("|cff888888" .. L.slashHelp .. "|r")

        -- 打开设置按钮
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
