-- 物品监控设置选项卡
local _, ns = ...

local L      = ns.L
local UI     = ns.UI
local Layout = ns.Layout  -- for Layout:RefreshAll (style changes)

local function GetAceGUI()
    return LibStub("AceGUI-3.0")
end

local function GetIM()
    return ns.ItemMonitor
end

------------------------------------------------------
-- 冷却读秒区块（仿 ViewerTab BuildTextOverlaySection）
------------------------------------------------------

local function BuildCooldownTextSection(scroll)
    local AceGUI = GetAceGUI()
    local cfg    = ns.db.itemMonitor

    UI.AddHeading(scroll, L.cooldownText)

    local container = AceGUI:Create("SimpleGroup")
    container:SetFullWidth(true)
    container:SetLayout("List")
    scroll:AddChild(container)

    local function RefreshLayout()
        C_Timer.After(0, function()
            if scroll and scroll.DoLayout then scroll:DoLayout() end
        end)
    end

    local function RebuildContent()
        container:ReleaseChildren()
        local cdCfg = cfg.cooldownText

        local cb = AceGUI:Create("CheckBox")
        cb:SetLabel(L.customizeStyle)
        cb:SetValue(cdCfg.enabled)
        cb:SetFullWidth(true)
        cb:SetCallback("OnValueChanged", function(_, _, val)
            cdCfg.enabled = val
            local im = GetIM()
            if im then im:Refresh() end
            RebuildContent()
        end)
        container:AddChild(cb)

        if not cdCfg.enabled then RefreshLayout(); return end

        UI.AddSlider(container, L.fontSize, 6, 48, 1,
            function() return cdCfg.fontSize end,
            function(v)
                cdCfg.fontSize = v
                local im = GetIM(); if im then im:Refresh() end
            end)

        local fontItems, fontOrder = UI.GetFontItems()
        UI.AddDropdown(container, L.fontFamily, fontItems, fontOrder,
            function() return UI.GetEffectiveFontName(cdCfg.fontName) end,
            function(v)
                cdCfg.fontName = v
                local im = GetIM(); if im then im:Refresh() end
            end)

        UI.AddDropdown(container, L.outline, UI.OUTLINE_ITEMS,
            { "NONE", "OUTLINE", "THICKOUTLINE" },
            function() return cdCfg.outline end,
            function(v)
                cdCfg.outline = v
                local im = GetIM(); if im then im:Refresh() end
            end)

        if type(cdCfg.textColor) == "table" then
            UI.AddColorPicker(container, L.textColor,
                function() return cdCfg.textColor end,
                function(r, g, b, a)
                    cdCfg.textColor = { r, g, b, a }
                    local im = GetIM(); if im then im:Refresh() end
                end)
        end

        UI.AddDropdown(container, L.position, UI.POS_ITEMS,
            { "TOPLEFT", "TOPRIGHT", "TOP", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER" },
            function() return cdCfg.point end,
            function(v)
                cdCfg.point = v
                local im = GetIM(); if im then im:Refresh() end
            end)

        UI.AddSlider(container, L.offsetX, -20, 20, 1,
            function() return cdCfg.offsetX end,
            function(v)
                cdCfg.offsetX = v
                local im = GetIM(); if im then im:Refresh() end
            end)

        UI.AddSlider(container, L.offsetY, -20, 20, 1,
            function() return cdCfg.offsetY end,
            function(v)
                cdCfg.offsetY = v
                local im = GetIM(); if im then im:Refresh() end
            end)

        RefreshLayout()
    end

    RebuildContent()
end

------------------------------------------------------
-- 键位显示区块（仿 ViewerTab keybind + BuildTextOverlaySection）
------------------------------------------------------

local function BuildKeybindSection(scroll)
    local AceGUI = GetAceGUI()
    local cfg    = ns.db.itemMonitor
    if not cfg.keybind then return end

    UI.AddHeading(scroll, L.keybindText)

    local container = AceGUI:Create("SimpleGroup")
    container:SetFullWidth(true)
    container:SetLayout("List")
    scroll:AddChild(container)

    local function RefreshLayout()
        C_Timer.After(0, function()
            if scroll and scroll.DoLayout then scroll:DoLayout() end
        end)
    end

    local function RebuildContent()
        container:ReleaseChildren()
        local kb = cfg.keybind

        local cb = AceGUI:Create("CheckBox")
        cb:SetLabel(L.enableDisplay)
        cb:SetValue(kb.enabled)
        cb:SetFullWidth(true)
        cb:SetCallback("OnValueChanged", function(_, _, val)
            kb.enabled = val
            local im = GetIM(); if im then im:Refresh() end
            RebuildContent()
        end)
        container:AddChild(cb)

        if not kb.enabled then RefreshLayout(); return end

        UI.AddSlider(container, L.fontSize, 6, 48, 1,
            function() return kb.fontSize end,
            function(v)
                kb.fontSize = v
                local im = GetIM(); if im then im:Refresh() end
            end)

        local fontItems, fontOrder = UI.GetFontItems()
        UI.AddDropdown(container, L.fontFamily, fontItems, fontOrder,
            function() return UI.GetEffectiveFontName(kb.fontName) end,
            function(v)
                kb.fontName = v
                local im = GetIM(); if im then im:Refresh() end
            end)

        UI.AddDropdown(container, L.outline, UI.OUTLINE_ITEMS,
            { "NONE", "OUTLINE", "THICKOUTLINE" },
            function() return kb.outline end,
            function(v)
                kb.outline = v
                local im = GetIM(); if im then im:Refresh() end
            end)

        if type(kb.textColor) == "table" then
            UI.AddColorPicker(container, L.textColor,
                function() return kb.textColor end,
                function(r, g, b, a)
                    kb.textColor = { r, g, b, a }
                    local im = GetIM(); if im then im:Refresh() end
                end)
        end

        UI.AddDropdown(container, L.position, UI.POS_ITEMS,
            { "TOPLEFT", "TOPRIGHT", "TOP", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER" },
            function() return kb.point end,
            function(v)
                kb.point = v
                local im = GetIM(); if im then im:Refresh() end
            end)

        UI.AddSlider(container, L.offsetX, -20, 20, 1,
            function() return kb.offsetX end,
            function(v)
                kb.offsetX = v
                local im = GetIM(); if im then im:Refresh() end
            end)

        UI.AddSlider(container, L.offsetY, -20, 20, 1,
            function() return kb.offsetY end,
            function(v)
                kb.offsetY = v
                local im = GetIM(); if im then im:Refresh() end
            end)

        RefreshLayout()
    end

    RebuildContent()
end

------------------------------------------------------
-- 物品数量区块
------------------------------------------------------

local function BuildItemCountSection(scroll)
    local AceGUI = GetAceGUI()
    local cfg    = ns.db.itemMonitor
    if not cfg then return end
    if not cfg.itemCount then
        cfg.itemCount = { enabled = true, fontSize = 12, whenZero = "gray" }
    end

    UI.AddHeading(scroll, L.imItemCount)

    local container = AceGUI:Create("SimpleGroup")
    container:SetFullWidth(true)
    container:SetLayout("List")
    scroll:AddChild(container)

    local ic = cfg.itemCount

    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(L.enableDisplay)
    cb:SetValue(ic.enabled)
    cb:SetFullWidth(true)
    cb:SetCallback("OnValueChanged", function(_, _, val)
        ic.enabled = val
        local im = GetIM(); if im then im:Refresh() end
    end)
    container:AddChild(cb)

    UI.AddSlider(container, L.fontSize, 8, 32, 1,
        function() return ic.fontSize end,
        function(v)
            ic.fontSize = v
            local im = GetIM(); if im then im:Refresh() end
        end)

    local whenZeroItems = { gray = L.imWhenZeroGray, hide = L.imWhenZeroHide }
    local whenZeroOrder = { "gray", "hide" }
    UI.AddDropdown(container, L.imWhenZero, whenZeroItems, whenZeroOrder,
        function() return ic.whenZero or "gray" end,
        function(v)
            ic.whenZero = v
            local im = GetIM(); if im then im:Refresh() end
        end)

    UI.AddSlider(container, L.offsetX, -20, 20, 1,
        function() return ic.offsetX or -2 end,
        function(v)
            ic.offsetX = v
            local im = GetIM(); if im then im:Refresh() end
        end)

    UI.AddSlider(container, L.offsetY, -20, 20, 1,
        function() return ic.offsetY or 2 end,
        function(v)
            ic.offsetY = v
            local im = GetIM(); if im then im:Refresh() end
        end)
end

------------------------------------------------------
-- 物品列表
------------------------------------------------------

local function BuildItemList(scroll, rebuildTab)
    local AceGUI = GetAceGUI()
    local cfg    = ns.db.itemMonitor
    if not cfg.keybind or type(cfg.keybind.manualByItem) ~= "table" then
        if cfg.keybind then cfg.keybind.manualByItem = {} end
    end

    if #cfg.items == 0 then
        local lbl = AceGUI:Create("Label")
        lbl:SetText("|cffaaaaaa" .. L.imNoItems .. "|r")
        lbl:SetFullWidth(true)
        scroll:AddChild(lbl)
        return
    end

    for idx, itemID in ipairs(cfg.items) do
        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        scroll:AddChild(row)

        -- 图标
        local iconID = C_Item.GetItemIconByID(itemID)
        if iconID then
            local iconWidget = AceGUI:Create("Icon")
            iconWidget:SetImage(iconID)
            iconWidget:SetImageSize(20, 20)
            iconWidget:SetWidth(28)
            row:AddChild(iconWidget)
        end

        -- 名称
        local name = C_Item.GetItemNameByID(itemID) or ("ID: " .. itemID)
        local nameLbl = AceGUI:Create("Label")
        nameLbl:SetText("|cffffffff" .. name .. "|r  |cff888888(" .. itemID .. ")|r")
        nameLbl:SetWidth(220)
        row:AddChild(nameLbl)

        -- 键位输入框（手动指定该物品显示的键位文字）
        local kb = cfg.keybind and cfg.keybind.manualByItem
        local keyBox = AceGUI:Create("EditBox")
        keyBox:SetLabel(L.imKeyLabel)
        keyBox:SetWidth(72)
        keyBox:DisableButton(true)
        keyBox:SetText(kb and (kb[itemID] or kb[tostring(itemID)] or "") or "")
        keyBox:SetCallback("OnEnterPressed", function(_, _, text)
            if not cfg.keybind then return end
            if not cfg.keybind.manualByItem then cfg.keybind.manualByItem = {} end
            local t = cfg.keybind.manualByItem
            if text and text:match("%S") then
                t[itemID] = text
                t[tostring(itemID)] = text
            else
                t[itemID] = nil
                t[tostring(itemID)] = nil
            end
            local im = GetIM()
            if im then im:Refresh() end
        end)
        keyBox:SetCallback("OnLeave", function()
            if not cfg.keybind then return end
            local text = keyBox:GetText()
            if not cfg.keybind.manualByItem then cfg.keybind.manualByItem = {} end
            local t = cfg.keybind.manualByItem
            if text and text:match("%S") then
                t[itemID] = text
                t[tostring(itemID)] = text
            else
                t[itemID] = nil
                t[tostring(itemID)] = nil
            end
            local im = GetIM()
            if im then im:Refresh() end
        end)
        row:AddChild(keyBox)

        -- 移除按钮
        local removeBtn = AceGUI:Create("Button")
        removeBtn:SetText(L.imRemove)
        removeBtn:SetWidth(80)
        removeBtn:SetCallback("OnClick", function()
            table.remove(cfg.items, idx)
            local im = GetIM(); if im then im:Init() end
            rebuildTab()
        end)
        row:AddChild(removeBtn)
    end
end

------------------------------------------------------
-- 主入口
------------------------------------------------------

function ns.BuildItemMonitorTab(scroll)
    local AceGUI = GetAceGUI()
    local cfg    = ns.db.itemMonitor
    if not cfg then return end

    local function RebuildTab()
        scroll:ReleaseChildren()
        ns.BuildItemMonitorTab(scroll)
        C_Timer.After(0, function()
            if scroll and scroll.DoLayout then scroll:DoLayout() end
        end)
    end

    -- 锁定位置
    local lockCB = AceGUI:Create("CheckBox")
    lockCB:SetLabel(L.imLocked)
    lockCB:SetValue(cfg.locked or false)
    lockCB:SetFullWidth(true)
    lockCB:SetCallback("OnValueChanged", function(_, _, val)
        local im = GetIM(); if im then im:SetLocked(val) end
    end)
    scroll:AddChild(lockCB)

    -- 添加物品
    local addGroup = AceGUI:Create("InlineGroup")
    addGroup:SetTitle(L.imAddItem)
    addGroup:SetFullWidth(true)
    addGroup:SetLayout("Flow")
    scroll:AddChild(addGroup)

    local idBox = AceGUI:Create("EditBox")
    idBox:SetLabel(L.imItemID)
    idBox:SetWidth(160)

    local previewLbl = AceGUI:Create("Label")
    previewLbl:SetWidth(200)
    previewLbl:SetText("")

    -- 实时预览（物品名称）
    idBox:SetCallback("OnTextChanged", function(_, _, text)
        local id = tonumber(text)
        if id and id > 0 then
            local name = C_Item.GetItemNameByID(id)
            if name then
                previewLbl:SetText("|cff00ff88" .. string.format(L.imItemPreviewOk, name) .. "|r")
            else
                C_Item.RequestLoadItemDataByID(id)
                previewLbl:SetText("|cffaaaaaa" .. L.imItemLoading .. "|r")
            end
        else
            previewLbl:SetText("")
        end
    end)

    -- Enter 确认添加
    idBox:SetCallback("OnEnterPressed", function(_, _, text)
        local id = tonumber(text)
        if not id or id <= 0 then return end
        local name = C_Item.GetItemNameByID(id)
        if not name then
            previewLbl:SetText("|cffff4444" .. L.imItemPreviewErr .. "|r")
            return
        end
        -- 去重检查
        for _, existing in ipairs(cfg.items) do
            if existing == id then
                idBox:SetText("")
                previewLbl:SetText("")
                return
            end
        end
        cfg.items[#cfg.items + 1] = id
        local im = GetIM(); if im then im:Init() end
        idBox:SetText("")
        previewLbl:SetText("")
        RebuildTab()
    end)

    addGroup:AddChild(idBox)
    addGroup:AddChild(previewLbl)

    local addBtn = AceGUI:Create("Button")
    addBtn:SetText(L.imAddItem)
    addBtn:SetWidth(120)
    addBtn:SetCallback("OnClick", function()
        local text = idBox:GetText()
        local id   = tonumber(text)
        if not id or id <= 0 then return end
        local name = C_Item.GetItemNameByID(id)
        if not name then
            previewLbl:SetText("|cffff4444" .. L.imItemPreviewErr .. "|r")
            return
        end
        for _, existing in ipairs(cfg.items) do
            if existing == id then
                idBox:SetText("")
                previewLbl:SetText("")
                return
            end
        end
        cfg.items[#cfg.items + 1] = id
        local im = GetIM(); if im then im:Init() end
        idBox:SetText("")
        previewLbl:SetText("")
        RebuildTab()
    end)
    addGroup:AddChild(addBtn)

    -- 物品列表
    BuildItemList(scroll, RebuildTab)

    -- 布局配置
    UI.AddHeading(scroll, L.imLayout)

    UI.AddDropdown(scroll, L.growDir, UI.CD_GROW_ITEMS,
        { "TOP", "BOTTOM" },
        function() return cfg.growDir end,
        function(v)
            cfg.growDir = v
            local im = GetIM(); if im then im:Refresh() end
        end)

    UI.AddDropdown(scroll, L.rowAnchor, UI.ROW_ANCHOR_ITEMS,
        { "LEFT", "CENTER", "RIGHT" },
        function() return cfg.rowAnchor or "CENTER" end,
        function(v)
            cfg.rowAnchor = v
            local im = GetIM(); if im then im:Refresh() end
        end)

    local iconsPerRowSlider = AceGUI:Create("Slider")
    iconsPerRowSlider:SetLabel(L.iconsPerRow)
    iconsPerRowSlider:SetSliderValues(0, 20, 1)
    iconsPerRowSlider:SetValue(cfg.iconsPerRow or 6)
    iconsPerRowSlider:SetIsPercent(false)
    iconsPerRowSlider:SetFullWidth(true)
    iconsPerRowSlider:SetCallback("OnValueChanged", function(_, _, v)
        cfg.iconsPerRow = math.floor(v)
        local im = GetIM(); if im then im:Refresh() end
    end)
    scroll:AddChild(iconsPerRowSlider)

    local tip = AceGUI:Create("Label")
    tip:SetText("|cffaaaaaa" .. L.iconsPerRowTip .. "|r")
    tip:SetFullWidth(true)
    tip:SetFontObject(GameFontHighlightSmall)
    scroll:AddChild(tip)

    UI.AddSlider(scroll, L.iconWidth, 16, 80, 1,
        function() return cfg.iconWidth end,
        function(v)
            cfg.iconWidth = v
            local im = GetIM(); if im then im:Refresh() end
        end)

    UI.AddSlider(scroll, L.iconHeight, 16, 80, 1,
        function() return cfg.iconHeight end,
        function(v)
            cfg.iconHeight = v
            local im = GetIM(); if im then im:Refresh() end
        end)

    UI.AddSlider(scroll, L.spacingX, 0, 20, 1,
        function() return cfg.spacingX end,
        function(v)
            cfg.spacingX = v
            local im = GetIM(); if im then im:Refresh() end
        end)

    UI.AddSlider(scroll, L.spacingY, 0, 20, 1,
        function() return cfg.spacingY end,
        function(v)
            cfg.spacingY = v
            local im = GetIM(); if im then im:Refresh() end
        end)

    -- 键位显示
    BuildKeybindSection(scroll)

    -- 物品数量
    BuildItemCountSection(scroll)

    -- 冷却读秒
    BuildCooldownTextSection(scroll)
end
