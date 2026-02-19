local _, ns = ...

------------------------------------------------------
-- 设置模块
------------------------------------------------------

local L = ns.L
local Layout = ns.Layout
local Style  = ns.Style
local AceGUI
local LSM = LibStub("LibSharedMedia-3.0", true)

-- 设置面板引用（用于 toggle）
local settingsFrame = nil

------------------------------------------------------
-- 选项列表
------------------------------------------------------
local DIR_ITEMS = {
    ["CENTER"]  = L.dirCenter,
    ["DEFAULT"] = L.dirDefault,
}

local TRACKED_BARS_DIR_ITEMS = {
    ["TOP"]    = L.dirTop,
    ["BOTTOM"] = L.dirBottom,
}

local OUTLINE_ITEMS = {
    ["NONE"]         = L.outNone,
    ["OUTLINE"]      = L.outOutline,
    ["THICKOUTLINE"] = L.outThick,
}

local function GetLSMDefaultFont()
    if LSM and LSM.DefaultMedia and LSM.DefaultMedia.font then
        return LSM.DefaultMedia.font
    end
    return ""
end

local function GetFontList()
    if LSM and LSM.List then
        return LSM:List("font")
    end
    return {}
end

local function GetFontItems()
    local items = {}
    local order = {}
    local list = GetFontList()
    for _, name in ipairs(list) do
        items[name] = name
        order[#order + 1] = name
    end
    return items, order
end

local function GetEffectiveFontName(fontName)
    if fontName and fontName ~= "" then return fontName end
    return GetLSMDefaultFont()
end

local POS_ITEMS = {
    ["TOPLEFT"]     = L.posTL,
    ["TOPRIGHT"]    = L.posTR,
    ["TOP"]         = L.posTop,
    ["BOTTOMLEFT"]  = L.posBL,
    ["BOTTOMRIGHT"] = L.posBR,
    ["CENTER"]      = L.posCenter,
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

local function AddGlowSlider(parent, label, minVal, maxVal, step, value, onChanged)
    local w = AceGUI:Create("Slider")
    w:SetLabel(label)
    w:SetSliderValues(minVal, maxVal, step)
    w:SetValue(value)
    w:SetIsPercent(false)
    w:SetFullWidth(true)
    w:SetCallback("OnValueChanged", function(_, _, v) onChanged(v) end)
    parent:AddChild(w)
    return w
end

local function AddEditBox(parent, label, getValue, setValue)
    local w = AceGUI:Create("EditBox")
    w:SetLabel(label)
    w:SetText(getValue() or "")
    w:SetFullWidth(true)
    w:SetCallback("OnEnterPressed", function(_, _, val)
        setValue(val)
        Layout:RefreshAll()
    end)
    parent:AddChild(w)
    return w
end

local function AddButton(parent, text, onClick)
    local w = AceGUI:Create("Button")
    w:SetText(text)
    w:SetFullWidth(true)
    w:SetCallback("OnClick", function()
        onClick()
        Layout:RefreshAll()
    end)
    parent:AddChild(w)
    return w
end

local function AddColorPicker(parent, label, getValue, setValue)
    local w = AceGUI:Create("ColorPicker")
    w:SetLabel(label)
    w:SetHasAlpha(true)
    local c = getValue()
    w:SetColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    local function OnColor(_, _, r, g, b, a)
        setValue(r, g, b, a)
        Layout:RefreshAll()
    end
    w:SetCallback("OnValueChanged", OnColor)
    w:SetCallback("OnValueConfirmed", OnColor)
    parent:AddChild(w)
    return w
end

------------------------------------------------------
-- 构建「概览」选项卡
------------------------------------------------------
local function BuildGeneralTab(scroll)

    -- Tips 提示
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

    AddCheckbox(scroll, L.suppressDebuffBorder,
        function() return ns.db.suppressDebuffBorder or false end,
        function(v) ns.db.suppressDebuffBorder = v end)

    -- 快捷操作
    AddHeading(scroll, "")

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
        if settingsFrame then
            settingsFrame:Release()
            settingsFrame = nil
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

    -- 重置为默认配置
    AddHeading(scroll, "")

    local resetBtn = AceGUI:Create("Button")
    resetBtn:SetText(L.resetDefaults)
    resetBtn:SetFullWidth(true)
    local pendingConfirm = false
    resetBtn:SetCallback("OnClick", function()
        if not pendingConfirm then
            pendingConfirm = true
            resetBtn:SetText("|cffff4444" .. L.resetConfirm .. "|r")
            C_Timer.After(5, function()
                if pendingConfirm then
                    pendingConfirm = false
                    resetBtn:SetText(L.resetDefaults)
                end
            end)
        else
            pendingConfirm = false
            CDFlowDB = ns.DeepCopy(ns.defaults)
            ns.db = CDFlowDB
            Layout:RefreshAll()
            resetBtn:SetText(L.resetDefaults)
            if settingsFrame then
                settingsFrame:Release()
                settingsFrame = nil
            end
        end
    end)
    scroll:AddChild(resetBtn)
end

------------------------------------------------------
-- 根据高亮样式动态构建选项控件
------------------------------------------------------
local function BuildStyleOptions(parent, cfg, onChanged)
    local style = cfg.style
    if style == "DEFAULT" or style == "NONE" or style == "PROC" then
        return
    end

    if style == "PIXEL" then
        AddGlowSlider(parent, L.hlLines, 1, 16, 1, cfg.lines, function(v)
            cfg.lines = v
            onChanged()
        end)
        AddGlowSlider(parent, L.hlThickness, 1, 5, 1, cfg.thickness, function(v)
            cfg.thickness = v
            onChanged()
        end)
    end

    if style == "PIXEL" or style == "AUTOCAST" or style == "BUTTON" then
        AddGlowSlider(parent, L.hlFrequency, 0.05, 1, 0.05, cfg.frequency, function(v)
            cfg.frequency = v
            onChanged()
        end)
    end

    if style == "AUTOCAST" then
        AddGlowSlider(parent, L.hlScale, 0.5, 2, 0.1, cfg.scale, function(v)
            cfg.scale = v
            onChanged()
        end)
    end
end

------------------------------------------------------
-- 「高亮特效」选项卡
------------------------------------------------------
local function BuildHighlightTab(scroll)
    local cfg = ns.db.highlight
    local buffCfg = ns.db.buffGlow

    local function refreshSkillGlows()
        Style:RefreshAllGlows()
    end

    -- 增益开关变更：需全量刷新布局
    local function refreshBuffLayout()
        Layout:RefreshViewer("BuffIconCooldownViewer")
    end

    -- 增益样式/参数变更：立即刷新特效（与技能高亮一致）
    local function refreshBuffGlowStyle()
        Style:RefreshAllBuffGlows()
    end

    local scrollLayoutPending = false
    local function refreshScrollLayout()
        if scrollLayoutPending then return end
        scrollLayoutPending = true
        C_Timer.After(0, function()
            scrollLayoutPending = false
            if scroll and scroll.DoLayout then scroll:DoLayout() end
        end)
    end

    -- 技能激活高亮
    AddHeading(scroll, L.skillGlow)

    local skillStyleDD = AceGUI:Create("Dropdown")
    skillStyleDD:SetLabel(L.hlStyle)
    skillStyleDD:SetList(HL_ITEMS, { "DEFAULT", "PIXEL", "AUTOCAST", "PROC", "BUTTON", "NONE" })
    skillStyleDD:SetValue(cfg.style)
    skillStyleDD:SetFullWidth(true)
    scroll:AddChild(skillStyleDD)

    local skillOptGroup = AceGUI:Create("InlineGroup")
    skillOptGroup:SetLayout("Flow")
    skillOptGroup:SetFullWidth(true)
    scroll:AddChild(skillOptGroup)

    local function RebuildSkillOptions()
        skillOptGroup:ReleaseChildren()
        BuildStyleOptions(skillOptGroup, cfg, refreshSkillGlows)
        refreshScrollLayout()
    end

    skillStyleDD:SetCallback("OnValueChanged", function(_, _, v)
        cfg.style = v
        RebuildSkillOptions()
        refreshSkillGlows()
    end)
    RebuildSkillOptions()

    -- 增益高亮
    AddHeading(scroll, L.buffGlow)

    -- 前置声明，避免回调里引用到全局同名变量
    local buffOptGroup
    local RebuildBuffOptions

    local buffEnableCB = AceGUI:Create("CheckBox")
    buffEnableCB:SetLabel(L.enableBuffGlow)
    buffEnableCB:SetValue(buffCfg.enabled)
    buffEnableCB:SetFullWidth(true)
    buffEnableCB:SetCallback("OnValueChanged", function(_, _, v)
        buffCfg.enabled = v
        refreshBuffLayout()
        if v then RebuildBuffOptions() else buffOptGroup:ReleaseChildren() end
        refreshScrollLayout()
    end)
    scroll:AddChild(buffEnableCB)

    buffOptGroup = AceGUI:Create("InlineGroup")
    buffOptGroup:SetLayout("Flow")
    buffOptGroup:SetFullWidth(true)
    scroll:AddChild(buffOptGroup)

    RebuildBuffOptions = function()
        buffOptGroup:ReleaseChildren()
        if not buffCfg.enabled then refreshScrollLayout(); return end

        local dd = AceGUI:Create("Dropdown")
        dd:SetLabel(L.hlStyle)
        dd:SetList(HL_ITEMS, { "DEFAULT", "PIXEL", "AUTOCAST", "PROC", "BUTTON", "NONE" })
        dd:SetValue(buffCfg.style)
        dd:SetFullWidth(true)
        dd:SetCallback("OnValueChanged", function(_, _, v)
            buffCfg.style = v
            RebuildBuffOptions()
            refreshBuffGlowStyle()
        end)
        buffOptGroup:AddChild(dd)

        BuildStyleOptions(buffOptGroup, buffCfg, refreshBuffGlowStyle)

        -- 技能ID过滤列表
        local filterGroup = AceGUI:Create("InlineGroup")
        filterGroup:SetTitle(L.buffGlowFilter)
        filterGroup:SetFullWidth(true)
        filterGroup:SetLayout("Flow")
        buffOptGroup:AddChild(filterGroup)

        local hint = AceGUI:Create("Label")
        hint:SetText("|cffaaaaaa" .. L.buffGlowFilterHint .. "|r")
        hint:SetFullWidth(true)
        hint:SetFontObject(GameFontHighlightSmall)
        filterGroup:AddChild(hint)

        if type(buffCfg.spellFilter) ~= "table" then
            buffCfg.spellFilter = {}
        end

        local inputSpellID

        local listLabel = AceGUI:Create("Label")
        listLabel:SetFullWidth(true)
        listLabel:SetFontObject(GameFontHighlightSmall)

        local function RebuildFilterList()
            local ids = {}
            for id in pairs(buffCfg.spellFilter) do
                ids[#ids + 1] = id
            end
            table.sort(ids)
            local lines = { "|cff88ccff" .. L.buffGlowFilterTitle .. "|r" }
            for _, id in ipairs(ids) do
                lines[#lines + 1] = tostring(id)
            end
            if #ids == 0 then
                lines[#lines + 1] = "|cff888888-|r"
            end
            listLabel:SetText(table.concat(lines, "\n"))
        end

        local idBox = AceGUI:Create("EditBox")
        idBox:SetLabel(L.spellID)
        idBox:SetText("")
        idBox:SetFullWidth(true)
        idBox:SetCallback("OnEnterPressed", function(_, _, v)
            inputSpellID = tonumber(v)
        end)
        filterGroup:AddChild(idBox)

        local addBtn = AceGUI:Create("Button")
        addBtn:SetText(L.buffGlowFilterAdd)
        addBtn:SetFullWidth(true)
        addBtn:SetCallback("OnClick", function()
            local id = inputSpellID or tonumber(idBox.editbox:GetText())
            if id and id > 0 then
                buffCfg.spellFilter[id] = true
                RebuildFilterList()
                refreshBuffLayout()
            end
        end)
        filterGroup:AddChild(addBtn)

        local removeBtn = AceGUI:Create("Button")
        removeBtn:SetText(L.buffGlowFilterRemove)
        removeBtn:SetFullWidth(true)
        removeBtn:SetCallback("OnClick", function()
            local id = inputSpellID or tonumber(idBox.editbox:GetText())
            if id and id > 0 then
                buffCfg.spellFilter[id] = nil
                RebuildFilterList()
                refreshBuffLayout()
            end
        end)
        filterGroup:AddChild(removeBtn)

        filterGroup:AddChild(listLabel)
        RebuildFilterList()

        refreshScrollLayout()
    end

    if buffCfg.enabled then
        RebuildBuffOptions()
    end

    refreshScrollLayout()
end

------------------------------------------------------
-- 通用文字叠层区块构建器
------------------------------------------------------
local function BuildTextOverlaySection(scroll, title, cfg, options)
    options = options or {}
    local maxOffset = options.maxOffset or 20
    local maxSize = options.maxSize or 48
    local enableLabel = options.enableLabel or L.enable

    AddHeading(scroll, title)

    local container = AceGUI:Create("SimpleGroup")
    container:SetFullWidth(true)
    container:SetLayout("List")
    scroll:AddChild(container)

    local function RefreshScrollLayout()
        C_Timer.After(0, function()
            if scroll and scroll.DoLayout then scroll:DoLayout() end
        end)
    end

    local function RebuildContent()
        container:ReleaseChildren()

        local cb = AceGUI:Create("CheckBox")
        cb:SetLabel(enableLabel)
        cb:SetValue(cfg.enabled)
        cb:SetFullWidth(true)
        cb:SetCallback("OnValueChanged", function(_, _, val)
            cfg.enabled = val
            Layout:RefreshAll()
            RebuildContent()
        end)
        container:AddChild(cb)

        if not cfg.enabled then
            RefreshScrollLayout()
            return
        end

        -- 字号
        AddSlider(container, L.fontSize, 6, maxSize, 1,
            function() return cfg.fontSize end,
            function(v) cfg.fontSize = v end)

        -- 字体
        local fontItems, fontOrder = GetFontItems()
        AddDropdown(container, L.fontFamily, fontItems, fontOrder,
            function() return GetEffectiveFontName(cfg.fontName) end,
            function(v) cfg.fontName = v end)

        -- 描边
        AddDropdown(container, L.outline, OUTLINE_ITEMS,
            { "NONE", "OUTLINE", "THICKOUTLINE" },
            function() return cfg.outline end,
            function(v) cfg.outline = v end)

        -- 颜色
        if type(cfg.textColor) == "table" then
            AddColorPicker(container, L.textColor,
                function() return cfg.textColor end,
                function(r, g, b, a) cfg.textColor = { r, g, b, a } end)
        end

        -- 位置
        AddDropdown(container, L.position, POS_ITEMS,
            { "TOPLEFT", "TOPRIGHT", "TOP", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER" },
            function() return cfg.point end,
            function(v) cfg.point = v end)

        -- 偏移
        AddSlider(container, L.offsetX, -maxOffset, maxOffset, 1,
            function() return cfg.offsetX end,
            function(v) cfg.offsetX = v end)

        AddSlider(container, L.offsetY, -maxOffset, maxOffset, 1,
            function() return cfg.offsetY end,
            function(v) cfg.offsetY = v end)

        -- 额外内容
        if options.buildExtra then
            options.buildExtra(container)
        end

        RefreshScrollLayout()
    end

    RebuildContent()
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
local function BuildViewerTab(scroll, viewerKey, showPerRow, allowUnlimitedPerRow)
    local cfg = ns.db[viewerKey]

    AddDropdown(scroll, L.growDir, DIR_ITEMS,
        { "CENTER", "DEFAULT" },
        function() return cfg.growDir end,
        function(v) cfg.growDir = v end)

    if viewerKey == "buffs" then
        AddDropdown(scroll, L.trackedBarsGrowDir, TRACKED_BARS_DIR_ITEMS,
            { "TOP", "BOTTOM" },
            function() return ns.db.trackedBarsGrowDir end,
            function(v) ns.db.trackedBarsGrowDir = v end)
    end

    if showPerRow then
        local minPerRow = allowUnlimitedPerRow and 0 or 1
        local maxPerRow = 20
        AddSlider(scroll, L.iconsPerRow, minPerRow, maxPerRow, 1,
            function() return cfg.iconsPerRow end,
            function(v) cfg.iconsPerRow = v end)
        if allowUnlimitedPerRow then
            local tip = AceGUI:Create("Label")
            tip:SetText("|cffaaaaaa" .. L.iconsPerRowTip .. "|r")
            tip:SetFullWidth(true)
            tip:SetFontObject(GameFontHighlightSmall)
            scroll:AddChild(tip)
        end
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

    BuildRowOverrides(scroll, viewerKey)

    -- 堆叠文字
    if cfg.stack then
        BuildTextOverlaySection(scroll, L.stackText, cfg.stack, {
            enableLabel = L.customizeStyle,
            maxSize = 48,
        })
    end

    -- 键位显示
    if cfg.keybind then
        BuildTextOverlaySection(scroll, L.keybindText, cfg.keybind, {
            enableLabel = L.enableDisplay,
            maxSize = 48,
            buildExtra = function(parent)
                local kb = cfg.keybind

                local subGroup = AceGUI:Create("InlineGroup")
                subGroup:SetTitle(L.manualOverride)
                subGroup:SetFullWidth(true)
                subGroup:SetLayout("Flow")
                parent:AddChild(subGroup)

                local hint = AceGUI:Create("Label")
                hint:SetText("|cffaaaaaa" .. L.manualListHint .. "|r")
                hint:SetFullWidth(true)
                hint:SetFontObject(GameFontHighlightSmall)
                subGroup:AddChild(hint)

                if type(kb.manualBySpell) ~= "table" then
                    kb.manualBySpell = {}
                end

                local manualSpellID, manualText

                AddEditBox(subGroup, L.spellID,
                    function() return manualSpellID and tostring(manualSpellID) or "" end,
                    function(v) manualSpellID = tonumber(v) end)

                AddEditBox(subGroup, L.displayText,
                    function() return manualText or "" end,
                    function(v) manualText = v end)

                local listLabel = AceGUI:Create("Label")
                listLabel:SetFullWidth(true)
                listLabel:SetFontObject(GameFontHighlightSmall)
                subGroup:AddChild(listLabel)

                local function RebuildManualList()
                    local keys = {}
                    for id in pairs(kb.manualBySpell) do
                        keys[#keys + 1] = tonumber(id) or id
                    end
                    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
                    local lines = { "|cff88ccff" .. L.manualListTitle .. "|r" }
                    for _, id in ipairs(keys) do
                        local text = kb.manualBySpell[id] or kb.manualBySpell[tostring(id)]
                        lines[#lines + 1] = tostring(id) .. " = " .. tostring(text)
                    end
                    if #keys == 0 then
                        lines[#lines + 1] = "|cff888888-|r"
                    end
                    listLabel:SetText(table.concat(lines, "\n"))
                end

                AddButton(subGroup, L.addOrUpdate, function()
                    if manualSpellID and manualSpellID > 0 and manualText and manualText ~= "" then
                        kb.manualBySpell[manualSpellID] = manualText
                        RebuildManualList()
                    end
                end)

                AddButton(subGroup, L.remove, function()
                    if manualSpellID and manualSpellID > 0 then
                        kb.manualBySpell[manualSpellID] = nil
                        kb.manualBySpell[tostring(manualSpellID)] = nil
                        RebuildManualList()
                    end
                end)

                RebuildManualList()
            end,
        })
    end

    -- 冷却读秒
    if cfg.cooldownText then
        BuildTextOverlaySection(scroll, L.cooldownText, cfg.cooldownText, {
            enableLabel = L.customizeStyle,
            maxSize = 48,
            maxOffset = 30,
        })
    end

    -- 底部提示
    local tip = AceGUI:Create("Label")
    tip:SetText("|cffaaaaaa" .. L.needReloadHint .. "|r")
    tip:SetFullWidth(true)
    tip:SetFontObject(GameFontHighlightSmall)
    scroll:AddChild(tip)
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
        BuildViewerTab(scroll, "essential", true, false)
    elseif group == "utility" then
        BuildViewerTab(scroll, "utility", true, false)
    elseif group == "buffs" then
        BuildViewerTab(scroll, "buffs", true, true)
    elseif group == "highlight" then
        BuildHighlightTab(scroll)
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
        local version = "1.2.0"
        if C_AddOns and C_AddOns.GetAddOnMetadata then
            version = C_AddOns.GetAddOnMetadata("CDFlow", "Version") or version
        elseif GetAddOnMetadata then
            version = GetAddOnMetadata("CDFlow", "Version") or version
        end
        local ver = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ver:SetPoint("LEFT", title, "RIGHT", 8, 0)
        ver:SetText("|cff888888v" .. version .. "|r")

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
