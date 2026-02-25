-- 追踪状态栏选项卡
-- 美化官方 BuffBarCooldownViewer 中"追踪的状态栏"的外观
local _, ns = ...

local L = ns.L
local Layout = ns.Layout
local UI = ns.UI

------------------------------------------------------
-- 文字区块构建器（名称/时长文字各一块）
-- showLabel   - 启用复选框文字
-- getEnabled  / setEnabled  - 启用状态 getter/setter
-- getFontSize / setFontSize
-- getFontName / setFontName
-- getOutline  / setOutline
-- getColor    / setColor   - 返回/接收 {r,g,b,a} 表
------------------------------------------------------
local function BuildTextSection(scroll, title, opts)
    local AceGUI = LibStub("AceGUI-3.0")

    UI.AddHeading(scroll, title)

    local container = AceGUI:Create("SimpleGroup")
    container:SetFullWidth(true)
    container:SetLayout("List")
    scroll:AddChild(container)

    local function RefreshScrollLayout()
        C_Timer.After(0, function()
            if scroll and scroll.DoLayout then scroll:DoLayout() end
        end)
    end

    local function Rebuild()
        container:ReleaseChildren()

        local cb = AceGUI:Create("CheckBox")
        cb:SetLabel(opts.showLabel)
        cb:SetValue(opts.getEnabled())
        cb:SetFullWidth(true)
        cb:SetCallback("OnValueChanged", function(_, _, val)
            opts.setEnabled(val)
            Layout:RefreshAll()
            Rebuild()
        end)
        container:AddChild(cb)

        if not opts.getEnabled() then
            RefreshScrollLayout()
            return
        end

        UI.AddSlider(container, L.fontSize, 6, 36, 1,
            opts.getFontSize, opts.setFontSize)

        local fontItems, fontOrder = UI.GetFontItems()
        UI.AddDropdown(container, L.fontFamily, fontItems, fontOrder,
            function() return UI.GetEffectiveFontName(opts.getFontName()) end,
            opts.setFontName)

        UI.AddDropdown(container, L.outline, UI.OUTLINE_ITEMS,
            { "NONE", "OUTLINE", "THICKOUTLINE" },
            opts.getOutline, opts.setOutline)

        UI.AddColorPicker(container, L.textColor,
            opts.getColor,
            function(r, g, b, a) opts.setColor({ r, g, b, a }) end)

        RefreshScrollLayout()
    end

    Rebuild()
end

------------------------------------------------------
-- 追踪状态栏 Tab 主体
------------------------------------------------------
function ns.BuildTrackedBarsTab(scroll)
    local AceGUI = LibStub("AceGUI-3.0")
    local cfg = ns.db.trackedBars

    -- ---- 布局区块 ----
    UI.AddHeading(scroll, L.tbLayout)

    UI.AddDropdown(scroll, L.trackedBarsGrowDir, UI.TRACKED_BARS_DIR_ITEMS,
        { "CENTER", "TOP", "BOTTOM" },
        function() return cfg.growDir or "CENTER" end,
        function(v) cfg.growDir = v Layout:RefreshAll() end)

    UI.AddSlider(scroll, L.tbBarHeight, 10, 60, 1,
        function() return cfg.barHeight end,
        function(v) cfg.barHeight = v Layout:RefreshAll() end)

    UI.AddSlider(scroll, L.tbSpacing, 0, 20, 1,
        function() return cfg.spacing ~= nil and cfg.spacing or 0 end,
        function(v) cfg.spacing = v Layout:RefreshAll() end)

    UI.AddDropdown(scroll, L.tbIconPosition, UI.ICON_POS_ITEMS,
        { "LEFT", "RIGHT", "HIDDEN" },
        function() return cfg.iconPosition end,
        function(v) cfg.iconPosition = v Layout:RefreshAll() end)

    -- ---- 外观区块 ----
    UI.AddHeading(scroll, L.tbAppearance)

    -- 条纹理（LibSharedMedia）
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local textureItems = {}
        local textureOrder = {}
        for _, name in ipairs(LSM:List("statusbar")) do
            textureItems[name] = name
            textureOrder[#textureOrder + 1] = name
        end
        UI.AddDropdown(scroll, L.tbBarTexture, textureItems, textureOrder,
            function() return cfg.barTexture end,
            function(v) cfg.barTexture = v end)
    end

    UI.AddColorPicker(scroll, L.tbBarColor,
        function() return cfg.barColor end,
        function(r, g, b, a) cfg.barColor = { r, g, b, a } end)

    UI.AddColorPicker(scroll, L.tbBgColor,
        function() return cfg.bgColor end,
        function(r, g, b, a) cfg.bgColor = { r, g, b, a } end)

    -- ---- 名称文字区块 ----
    BuildTextSection(scroll, L.tbNameText, {
        showLabel   = L.tbShowName,
        getEnabled  = function() return cfg.showName end,
        setEnabled  = function(v) cfg.showName = v end,
        getFontSize = function() return cfg.nameFontSize end,
        setFontSize = function(v) cfg.nameFontSize = v end,
        getFontName = function() return cfg.nameFontName end,
        setFontName = function(v) cfg.nameFontName = v end,
        getOutline  = function() return cfg.nameOutline end,
        setOutline  = function(v) cfg.nameOutline = v end,
        getColor    = function() return cfg.nameColor end,
        setColor    = function(t) cfg.nameColor = t end,
    })

    -- ---- 时长文字区块 ----
    BuildTextSection(scroll, L.tbDurationText, {
        showLabel   = L.tbShowDuration,
        getEnabled  = function() return cfg.showDuration end,
        setEnabled  = function(v) cfg.showDuration = v end,
        getFontSize = function() return cfg.durationFontSize end,
        setFontSize = function(v) cfg.durationFontSize = v end,
        getFontName = function() return cfg.durationFontName end,
        setFontName = function(v) cfg.durationFontName = v end,
        getOutline  = function() return cfg.durationOutline end,
        setOutline  = function(v) cfg.durationOutline = v end,
        getColor    = function() return cfg.durationColor end,
        setColor    = function(t) cfg.durationColor = t end,
    })
end
