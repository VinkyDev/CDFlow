-- AceGUI 通用控件工厂 + 选项列表常量
local _, ns = ...

local L = ns.L
local Layout = ns.Layout
local LSM = LibStub("LibSharedMedia-3.0", true)

ns.UI = {}

-- 行内锚点（左/中/右）
ns.UI.ROW_ANCHOR_ITEMS = {
    ["LEFT"]   = L.anchorLeft,
    ["CENTER"] = L.anchorCenter,
    ["RIGHT"]  = L.anchorRight,
}

-- 重要技能 / 效能技能增长方向
ns.UI.CD_GROW_ITEMS = {
    ["TOP"]    = L.dirGrowDown,
    ["BOTTOM"] = L.dirGrowUp,
}

-- 增益效果增长方向
ns.UI.BUFF_GROW_ITEMS = {
    ["CENTER"]  = L.dirBuffCenter,
    ["DEFAULT"] = L.dirBuffDefault,
}

ns.UI.TRACKED_BARS_DIR_ITEMS = {
    ["CENTER"] = L.dirTbCenter,
    ["TOP"]    = L.dirTbTop,
    ["BOTTOM"] = L.dirTbBottom,
}

ns.UI.ICON_POS_ITEMS = {
    ["LEFT"]   = L.tbIconLeft,
    ["RIGHT"]  = L.tbIconRight,
    ["HIDDEN"] = L.tbIconHidden,
}

ns.UI.OUTLINE_ITEMS = {
    ["NONE"]         = L.outNone,
    ["OUTLINE"]      = L.outOutline,
    ["THICKOUTLINE"] = L.outThick,
}

ns.UI.POS_ITEMS = {
    ["TOPLEFT"]     = L.posTL,
    ["TOPRIGHT"]    = L.posTR,
    ["TOP"]         = L.posTop,
    ["BOTTOMLEFT"]  = L.posBL,
    ["BOTTOMRIGHT"] = L.posBR,
    ["CENTER"]      = L.posCenter,
}

ns.UI.HL_ITEMS = {
    ["DEFAULT"]  = L.hlDefault,
    ["PIXEL"]    = L.hlPixel,
    ["AUTOCAST"] = L.hlAutocast,
    ["PROC"]     = L.hlProc,
    ["BUTTON"]   = L.hlButton,
    ["NONE"]     = L.hlNone,
}

function ns.UI.GetLSMDefaultFont()
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

function ns.UI.GetFontItems()
    local items = {}
    local order = {}
    local list = GetFontList()
    for _, name in ipairs(list) do
        items[name] = name
        order[#order + 1] = name
    end
    return items, order
end

function ns.UI.GetEffectiveFontName(fontName)
    if fontName and fontName ~= "" then return fontName end
    return ns.UI.GetLSMDefaultFont()
end

------------------------------------------------------
-- AceGUI 控件工厂
------------------------------------------------------

local function GetAceGUI()
    return LibStub("AceGUI-3.0")
end

function ns.UI.AddHeading(parent, text)
    local AceGUI = GetAceGUI()
    local w = AceGUI:Create("Heading")
    w:SetText(text)
    w:SetFullWidth(true)
    parent:AddChild(w)
end

function ns.UI.AddCheckbox(parent, label, getValue, setValue)
    local AceGUI = GetAceGUI()
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

function ns.UI.AddSlider(parent, label, minVal, maxVal, step, getValue, setValue)
    local AceGUI = GetAceGUI()
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

function ns.UI.AddDropdown(parent, label, items, order, getValue, setValue)
    local AceGUI = GetAceGUI()
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

function ns.UI.AddGlowSlider(parent, label, minVal, maxVal, step, value, onChanged)
    local AceGUI = GetAceGUI()
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

function ns.UI.AddEditBox(parent, label, getValue, setValue)
    local AceGUI = GetAceGUI()
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

function ns.UI.AddButton(parent, text, onClick)
    local AceGUI = GetAceGUI()
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

function ns.UI.AddColorPicker(parent, label, getValue, setValue)
    local AceGUI = GetAceGUI()
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
-- 通用技能目录弹窗
-- 参数：
--   title        - 弹窗标题
--   sections     - { { heading, entries=[{spellID,name,icon}], onSelect } }
--   onManualAdd  - function(spellID, spellName) | nil，有则在顶部显示手动输入
-- 返回：AceGUI Frame widget（调用方可保存以便关闭）
------------------------------------------------------
function ns.UI.OpenSpellCatalogFrame(title, sections, onManualAdd)
    local AceGUI = GetAceGUI()

    local frame = AceGUI:Create("Frame")
    frame:SetTitle(title)
    frame:SetWidth(420)
    frame:SetHeight(500)
    frame:SetLayout("Fill")
    frame:EnableResize(false)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    frame:AddChild(scroll)

    -- 手动输入区域
    if onManualAdd then
        local manualGroup = AceGUI:Create("InlineGroup")
        manualGroup:SetTitle(ns.L and ns.L.bgManualAdd or "Manual Spell ID")
        manualGroup:SetFullWidth(true)
        manualGroup:SetLayout("Flow")
        scroll:AddChild(manualGroup)

        local manualBox = AceGUI:Create("EditBox")
        manualBox:SetLabel(ns.L and ns.L.spellID or "Spell ID")
        manualBox:SetFullWidth(true)
        manualBox:SetCallback("OnEnterPressed", function(_, _, val)
            local spellID = tonumber(val)
            if not spellID or spellID <= 0 then return end
            local spellName = C_Spell.GetSpellName(spellID) or ""
            onManualAdd(spellID, spellName)
            frame:Release()
        end)
        manualGroup:AddChild(manualBox)
    end

    -- 各区块（标题 + 条目列表）
    local hasAny = false
    for _, section in ipairs(sections) do
        if section.entries and #section.entries > 0 then
            hasAny = true
            local heading = AceGUI:Create("Heading")
            heading:SetText(section.heading .. " (" .. #section.entries .. ")")
            heading:SetFullWidth(true)
            scroll:AddChild(heading)

            for _, entry in ipairs(section.entries) do
                local btn = AceGUI:Create("InteractiveLabel")
                local tex = entry.icon and ("|T" .. entry.icon .. ":16:16:0:0|t ") or ""
                btn:SetText(tex .. "|cffffffff" .. entry.name .. "|r  |cff888888(" .. entry.spellID .. ")|r")
                btn:SetFullWidth(true)
                btn:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                btn:SetCallback("OnClick", function()
                    section.onSelect(entry)
                    frame:Release()
                end)
                scroll:AddChild(btn)
            end
        end
    end

    if not hasAny and not onManualAdd then
        local emptyLabel = AceGUI:Create("Label")
        emptyLabel:SetText("|cffaaaaaa" .. (ns.L and ns.L.bgCatalogEmpty or "No entries found") .. "|r")
        emptyLabel:SetFullWidth(true)
        scroll:AddChild(emptyLabel)
    end

    return frame
end
