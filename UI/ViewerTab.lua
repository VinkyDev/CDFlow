-- 查看器选项卡（Essential / Utility / Buffs）+ 行覆盖 + 文字叠层
local _, ns = ...

local L = ns.L
local Layout = ns.Layout
local UI = ns.UI

------------------------------------------------------
-- 文字叠层区块构建器
------------------------------------------------------
local function BuildTextOverlaySection(scroll, title, cfg, options)
    local AceGUI = LibStub("AceGUI-3.0")
    options = options or {}
    local maxOffset = options.maxOffset or 20
    local maxSize = options.maxSize or 48
    local enableLabel = options.enableLabel or L.enable

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

        UI.AddSlider(container, L.fontSize, 6, maxSize, 1,
            function() return cfg.fontSize end,
            function(v) cfg.fontSize = v end)

        local fontItems, fontOrder = UI.GetFontItems()
        UI.AddDropdown(container, L.fontFamily, fontItems, fontOrder,
            function() return UI.GetEffectiveFontName(cfg.fontName) end,
            function(v) cfg.fontName = v end)

        UI.AddDropdown(container, L.outline, UI.OUTLINE_ITEMS,
            { "NONE", "OUTLINE", "THICKOUTLINE" },
            function() return cfg.outline end,
            function(v) cfg.outline = v end)

        if type(cfg.textColor) == "table" then
            UI.AddColorPicker(container, L.textColor,
                function() return cfg.textColor end,
                function(r, g, b, a) cfg.textColor = { r, g, b, a } end)
        end

        UI.AddDropdown(container, L.position, UI.POS_ITEMS,
            { "TOPLEFT", "TOPRIGHT", "TOP", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER" },
            function() return cfg.point end,
            function(v) cfg.point = v end)

        UI.AddSlider(container, L.offsetX, -maxOffset, maxOffset, 1,
            function() return cfg.offsetX end,
            function(v) cfg.offsetX = v end)

        UI.AddSlider(container, L.offsetY, -maxOffset, maxOffset, 1,
            function() return cfg.offsetY end,
            function(v) cfg.offsetY = v end)

        if options.buildExtra then
            options.buildExtra(container)
        end

        RefreshScrollLayout()
    end

    RebuildContent()
end

------------------------------------------------------
-- 自定义遮罩层区块
------------------------------------------------------
local function BuildSwipeOverlaySection(scroll, viewerKey)
    local AceGUI = LibStub("AceGUI-3.0")
    local cfg = ns.db[viewerKey].swipeOverlay

    UI.AddHeading(scroll, L.swipeOverlay)

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
        cb:SetLabel(L.enable)
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

        UI.AddColorPicker(container, L.swipeActiveColor,
            function() return cfg.activeAuraColor end,
            function(r, g, b, a) cfg.activeAuraColor = { r, g, b, a } end)

        UI.AddColorPicker(container, L.swipeCDColor,
            function() return cfg.cdSwipeColor end,
            function(r, g, b, a) cfg.cdSwipeColor = { r, g, b, a } end)

        RefreshScrollLayout()
    end

    RebuildContent()
end

------------------------------------------------------
-- 行尺寸覆盖
------------------------------------------------------
local function BuildRowOverrides(scroll, viewerKey)
    local AceGUI = LibStub("AceGUI-3.0")
    local cfg = ns.db[viewerKey]

    UI.AddHeading(scroll, L.rowOverrides)

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
-- 查看器选项卡主体
------------------------------------------------------
function ns.BuildViewerTab(scroll, viewerKey, showPerRow, allowUnlimitedPerRow)
    local AceGUI = LibStub("AceGUI-3.0")
    local cfg = ns.db[viewerKey]

    if viewerKey == "buffs" then
        UI.AddDropdown(scroll, L.growDir, UI.BUFF_GROW_ITEMS,
            { "CENTER", "DEFAULT" },
            function() return cfg.growDir end,
            function(v) cfg.growDir = v end)
        UI.AddDropdown(scroll, L.trackedBarsGrowDir, UI.TRACKED_BARS_DIR_ITEMS,
            { "TOP", "BOTTOM" },
            function() return ns.db.trackedBarsGrowDir end,
            function(v) ns.db.trackedBarsGrowDir = v end)
    else
        UI.AddDropdown(scroll, L.growDir, UI.CD_GROW_ITEMS,
            { "TOP", "BOTTOM" },
            function() return cfg.growDir end,
            function(v) cfg.growDir = v end)
    end

    if showPerRow then
        local minPerRow = allowUnlimitedPerRow and 0 or 1
        local maxPerRow = 20
        UI.AddSlider(scroll, L.iconsPerRow, minPerRow, maxPerRow, 1,
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

    UI.AddSlider(scroll, L.iconWidth, 16, 80, 1,
        function() return cfg.iconWidth end,
        function(v) cfg.iconWidth = v end)

    UI.AddSlider(scroll, L.iconHeight, 16, 80, 1,
        function() return cfg.iconHeight end,
        function(v) cfg.iconHeight = v end)

    UI.AddSlider(scroll, L.spacingX, 0, 20, 1,
        function() return cfg.spacingX end,
        function(v) cfg.spacingX = v end)

    if viewerKey ~= "buffs" then
        UI.AddSlider(scroll, L.spacingY, 0, 20, 1,
            function() return cfg.spacingY end,
            function(v) cfg.spacingY = v end)

        BuildRowOverrides(scroll, viewerKey)
    end

    if cfg.stack then
        BuildTextOverlaySection(scroll, L.stackText, cfg.stack, {
            enableLabel = L.customizeStyle,
            maxSize = 48,
        })
    end

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

                UI.AddEditBox(subGroup, L.spellID,
                    function() return manualSpellID and tostring(manualSpellID) or "" end,
                    function(v) manualSpellID = tonumber(v) end)

                UI.AddEditBox(subGroup, L.displayText,
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

                UI.AddButton(subGroup, L.addOrUpdate, function()
                    if manualSpellID and manualSpellID > 0 and manualText and manualText ~= "" then
                        kb.manualBySpell[manualSpellID] = manualText
                        RebuildManualList()
                    end
                end)

                UI.AddButton(subGroup, L.remove, function()
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

    if cfg.cooldownText then
        BuildTextOverlaySection(scroll, L.cooldownText, cfg.cooldownText, {
            enableLabel = L.customizeStyle,
            maxSize = 48,
            maxOffset = 30,
        })
    end

    if cfg.swipeOverlay then
        BuildSwipeOverlaySection(scroll, viewerKey)
    end
end
