local _, ns = ...

-- 监控条设置面板：条选择、技能目录、专精、样式

local L   = ns.L
local MB  = ns.MonitorBars
local AceGUI
local LSM

local OUTLINE_ITEMS = {
    ["NONE"]         = L.outNone,
    ["OUTLINE"]      = L.outOutline,
    ["THICKOUTLINE"] = L.outThick,
}

local BAR_TYPE_ITEMS = {
    ["stack"]  = L.mbTypeStack,
    ["charge"] = L.mbTypeCharge,
}

local UNIT_ITEMS = {
    ["player"] = L.mbUnitPlayer,
    ["target"] = L.mbUnitTarget,
}

local selectedBarIndex = 1

local function GetFontItems()
    local items, order = {}, {}
    if LSM and LSM.List then
        for _, name in ipairs(LSM:List("font")) do
            items[name] = name
            order[#order + 1] = name
        end
    end
    return items, order
end

local function GetTextureItems()
    local items, order = {}, {}
    if LSM and LSM.List then
        for _, name in ipairs(LSM:List("statusbar")) do
            items[name] = name
            order[#order + 1] = name
        end
    end
    return items, order
end

local function NewBarDefaults(id, barType, spellID, spellName, unit)
    return {
        id         = id,
        enabled    = true,
        barType    = barType or "stack",
        spellID    = spellID or 0,
        spellName  = spellName or "",
        unit       = unit or "player",
        maxStacks  = 5,
        maxCharges = 0,
        width      = 200,
        height     = 20,
        posX       = 0,
        posY       = 0,
        barColor    = { 0.2, 0.8, 0.2, 1 },
        bgColor     = { 0.1, 0.1, 0.1, 0.6 },
        borderColor = { 0, 0, 0, 1 },
        borderSize  = 1,
        showIcon   = true,
        showText   = true,
        textAlign  = "RIGHT",
        textOffsetX = -4,
        textOffsetY = 0,
        fontName   = "",
        fontSize   = 12,
        outline    = "OUTLINE",
        barTexture = "Solid",
        colorThreshold  = 0,
        thresholdColor  = { 1.0, 0.5, 0.0, 1 },
        hideFromCDM     = false,
        specs      = { GetSpecialization() or 1 },
    }
end

local function GetBarDropdownList(cfg)
    local items, order = {}, {}
    for i, bar in ipairs(cfg.bars) do
        local name = bar.spellName and bar.spellName ~= "" and bar.spellName or L.mbNoSpell
        local typeTag = bar.barType == "charge" and L.mbTypeCharge or L.mbTypeStack
        items[i] = string.format("%s  [%s]", name, typeTag)
        order[#order + 1] = i
    end
    return items, order
end

local function BuildBarConfig(container, barCfg, rebuildAll)
    local function Refresh()
        local f = MB:GetActiveFrame(barCfg.id)
        if f then         MB:ApplyStyle(f) end
    end

    local enableCB = AceGUI:Create("CheckBox")
    enableCB:SetLabel(L.enable)
    enableCB:SetValue(barCfg.enabled)
    enableCB:SetFullWidth(true)
    enableCB:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.enabled = val
        MB:RebuildAllBars()
    end)
    container:AddChild(enableCB)

    local typeDD = AceGUI:Create("Dropdown")
    typeDD:SetLabel(L.mbBarType)
    typeDD:SetList(BAR_TYPE_ITEMS, { "stack", "charge" })
    typeDD:SetValue(barCfg.barType)
    typeDD:SetFullWidth(true)
    typeDD:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.barType = val
        MB:RebuildAllBars()
        rebuildAll()
    end)
    container:AddChild(typeDD)

    local spellBox = AceGUI:Create("EditBox")
    spellBox:SetLabel(L.mbSpellID)
    spellBox:SetText(barCfg.spellID > 0 and tostring(barCfg.spellID) or "")
    spellBox:SetFullWidth(true)
    spellBox:SetCallback("OnEnterPressed", function(_, _, val)
        local id = tonumber(val)
        if id and id > 0 then
            barCfg.spellID = id
            barCfg.spellName = C_Spell.GetSpellName(id) or ""
            MB:RebuildAllBars()
            rebuildAll()
        end
    end)
    container:AddChild(spellBox)

    if barCfg.spellID > 0 then
        local spellName = barCfg.spellName
        if (not spellName or spellName == "") then
            spellName = C_Spell.GetSpellName(barCfg.spellID) or "?"
            barCfg.spellName = spellName
        end
        local nameLabel = AceGUI:Create("Label")
        nameLabel:SetText("|cff88ccff" .. L.mbSpellName .. ": " .. spellName .. "|r")
        nameLabel:SetFullWidth(true)
        nameLabel:SetFontObject(GameFontHighlightSmall)
        container:AddChild(nameLabel)
    end

    if barCfg.barType == "stack" then
        local cdmHint = AceGUI:Create("Label")
        cdmHint:SetText("|cffffcc00" .. L.mbCDMHint .. "|r")
        cdmHint:SetFullWidth(true)
        cdmHint:SetFontObject(GameFontHighlightSmall)
        container:AddChild(cdmHint)

        local unitDD = AceGUI:Create("Dropdown")
        unitDD:SetLabel(L.mbUnit)
        unitDD:SetList(UNIT_ITEMS, { "player", "target" })
        unitDD:SetValue(barCfg.unit or "player")
        unitDD:SetFullWidth(true)
        unitDD:SetCallback("OnValueChanged", function(_, _, val)
            barCfg.unit = val
            Refresh()
        end)
        container:AddChild(unitDD)
    end

    local hideCDMCB = AceGUI:Create("CheckBox")
    hideCDMCB:SetLabel(L.mbHideFromCDM)
    hideCDMCB:SetValue(barCfg.hideFromCDM or false)
    hideCDMCB:SetFullWidth(true)
    hideCDMCB:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.hideFromCDM = val
        MB:RebuildAllBars()
        ns.Layout:RefreshAll()
    end)
    container:AddChild(hideCDMCB)

    if barCfg.barType == "stack" then
        local maxSlider = AceGUI:Create("Slider")
        maxSlider:SetLabel(L.mbMaxStacks)
        maxSlider:SetSliderValues(1, 30, 1)
        maxSlider:SetValue(barCfg.maxStacks or 5)
        maxSlider:SetFullWidth(true)
        maxSlider:SetCallback("OnValueChanged", function(_, _, val)
            barCfg.maxStacks = math.floor(val)
            MB:RebuildAllBars()
        end)
        container:AddChild(maxSlider)
    else
        local chargeSlider = AceGUI:Create("Slider")
        chargeSlider:SetLabel(L.mbMaxCharges)
        chargeSlider:SetSliderValues(0, 10, 1)
        chargeSlider:SetValue(barCfg.maxCharges or 0)
        chargeSlider:SetFullWidth(true)
        chargeSlider:SetCallback("OnValueChanged", function(_, _, val)
            barCfg.maxCharges = math.floor(val)
            MB:RebuildAllBars()
        end)
        container:AddChild(chargeSlider)

        local chargeTip = AceGUI:Create("Label")
        chargeTip:SetText("|cffaaaaaa" .. L.mbMaxChargesAuto .. "|r")
        chargeTip:SetFullWidth(true)
        chargeTip:SetFontObject(GameFontHighlightSmall)
        container:AddChild(chargeTip)
    end

    local specGroup = AceGUI:Create("InlineGroup")
    specGroup:SetTitle(L.mbSpecs)
    specGroup:SetFullWidth(true)
    specGroup:SetLayout("Flow")
    container:AddChild(specGroup)

    local specs = barCfg.specs or {}
    local numSpecs = GetNumSpecializations() or 4

    for i = 1, numSpecs do
        local _, specName = GetSpecializationInfo(i)
        if specName then
            local specCB = AceGUI:Create("CheckBox")
            specCB:SetLabel(specName)
            specCB:SetWidth(200)
            local found = false
            for _, s in ipairs(specs) do
                if s == i then found = true; break end
            end
            specCB:SetValue(#specs == 0 or found)
            specCB:SetCallback("OnValueChanged", function(_, _, val)
                local newSpecs = {}
                for j = 1, numSpecs do
                    local checked = (j == i) and val
                    if j ~= i then
                        for _, s in ipairs(barCfg.specs or {}) do
                            if s == j then checked = true; break end
                        end
                    end
                    if checked then newSpecs[#newSpecs + 1] = j end
                end
                barCfg.specs = newSpecs
                MB:RebuildAllBars()
            end)
            specGroup:AddChild(specCB)
        end
    end

    local styleGroup = AceGUI:Create("InlineGroup")
    styleGroup:SetTitle(L.generalSettings)
    styleGroup:SetFullWidth(true)
    styleGroup:SetLayout("Flow")
    container:AddChild(styleGroup)

    local wSlider = AceGUI:Create("Slider")
    wSlider:SetLabel(L.mbBarWidth)
    wSlider:SetSliderValues(60, 500, 1)
    wSlider:SetValue(barCfg.width)
    wSlider:SetFullWidth(true)
    wSlider:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.width = math.floor(val)
        MB:RebuildAllBars()
    end)
    styleGroup:AddChild(wSlider)

    local hSlider = AceGUI:Create("Slider")
    hSlider:SetLabel(L.mbBarHeight)
    hSlider:SetSliderValues(8, 60, 1)
    hSlider:SetValue(barCfg.height)
    hSlider:SetFullWidth(true)
    hSlider:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.height = math.floor(val)
        MB:RebuildAllBars()
    end)
    styleGroup:AddChild(hSlider)

    local texItems, texOrder = GetTextureItems()
    if next(texItems) then
        local texDD = AceGUI:Create("Dropdown")
        texDD:SetLabel(L.mbBarTexture)
        texDD:SetList(texItems, texOrder)
        texDD:SetValue(barCfg.barTexture or "Solid")
        texDD:SetFullWidth(true)
        texDD:SetCallback("OnValueChanged", function(_, _, val)
            barCfg.barTexture = val
            MB:RebuildAllBars()
        end)
        styleGroup:AddChild(texDD)
    end

    local barColorPicker = AceGUI:Create("ColorPicker")
    barColorPicker:SetLabel(L.mbBarColor)
    barColorPicker:SetHasAlpha(true)
    local bc = barCfg.barColor or { 0.2, 0.8, 0.2, 1 }
    barColorPicker:SetColor(bc[1], bc[2], bc[3], bc[4])
    local function OnBarColor(_, _, r, g, b, a)
        barCfg.barColor = { r, g, b, a }
        MB:RebuildAllBars()
    end
    barColorPicker:SetCallback("OnValueChanged", OnBarColor)
    barColorPicker:SetCallback("OnValueConfirmed", OnBarColor)
    styleGroup:AddChild(barColorPicker)

    local maxVal = barCfg.barType == "charge" and (barCfg.maxCharges > 0 and barCfg.maxCharges or 10) or (barCfg.maxStacks or 30)
    local thresholdSlider = AceGUI:Create("Slider")
    thresholdSlider:SetLabel(L.mbColorThreshold)
    thresholdSlider:SetSliderValues(0, maxVal, 1)
    thresholdSlider:SetValue(barCfg.colorThreshold or 0)
    thresholdSlider:SetFullWidth(true)
    thresholdSlider:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.colorThreshold = math.floor(val)
        MB:RebuildAllBars()
    end)
    styleGroup:AddChild(thresholdSlider)

    local thresholdTip = AceGUI:Create("Label")
    thresholdTip:SetText("|cffaaaaaa" .. L.mbColorThresholdTip .. "|r")
    thresholdTip:SetFullWidth(true)
    thresholdTip:SetFontObject(GameFontHighlightSmall)
    styleGroup:AddChild(thresholdTip)

    local thresholdColorPicker = AceGUI:Create("ColorPicker")
    thresholdColorPicker:SetLabel(L.mbThresholdColor)
    thresholdColorPicker:SetHasAlpha(true)
    local tc = barCfg.thresholdColor or { 1.0, 0.5, 0.0, 1 }
    thresholdColorPicker:SetColor(tc[1], tc[2], tc[3], tc[4])
    local function OnThresholdColor(_, _, r, g, b, a)
        barCfg.thresholdColor = { r, g, b, a }
        MB:RebuildAllBars()
    end
    thresholdColorPicker:SetCallback("OnValueChanged", OnThresholdColor)
    thresholdColorPicker:SetCallback("OnValueConfirmed", OnThresholdColor)
    styleGroup:AddChild(thresholdColorPicker)

    local bgColorPicker = AceGUI:Create("ColorPicker")
    bgColorPicker:SetLabel(L.mbBgColor)
    bgColorPicker:SetHasAlpha(true)
    local bgc = barCfg.bgColor or { 0.1, 0.1, 0.1, 0.6 }
    bgColorPicker:SetColor(bgc[1], bgc[2], bgc[3], bgc[4])
    local function OnBgColor(_, _, r, g, b, a)
        barCfg.bgColor = { r, g, b, a }
        MB:RebuildAllBars()
    end
    bgColorPicker:SetCallback("OnValueChanged", OnBgColor)
    bgColorPicker:SetCallback("OnValueConfirmed", OnBgColor)
    styleGroup:AddChild(bgColorPicker)

    local borderColorPicker = AceGUI:Create("ColorPicker")
    borderColorPicker:SetLabel(L.mbBorderColor)
    borderColorPicker:SetHasAlpha(true)
    local bdc = barCfg.borderColor or { 0, 0, 0, 1 }
    borderColorPicker:SetColor(bdc[1], bdc[2], bdc[3], bdc[4])
    local function OnBorderColor(_, _, r, g, b, a)
        barCfg.borderColor = { r, g, b, a }
        MB:RebuildAllBars()
    end
    borderColorPicker:SetCallback("OnValueChanged", OnBorderColor)
    borderColorPicker:SetCallback("OnValueConfirmed", OnBorderColor)
    styleGroup:AddChild(borderColorPicker)

    local borderSlider = AceGUI:Create("Slider")
    borderSlider:SetLabel(L.mbBorderSize)
    borderSlider:SetSliderValues(0, 4, 1)
    borderSlider:SetValue(barCfg.borderSize or 1)
    borderSlider:SetFullWidth(true)
    borderSlider:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.borderSize = math.floor(val)
        MB:RebuildAllBars()
    end)
    styleGroup:AddChild(borderSlider)

    local iconCB = AceGUI:Create("CheckBox")
    iconCB:SetLabel(L.mbShowIcon)
    iconCB:SetValue(barCfg.showIcon ~= false)
    iconCB:SetFullWidth(true)
    iconCB:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.showIcon = val
        MB:RebuildAllBars()
    end)
    styleGroup:AddChild(iconCB)

    local textCB = AceGUI:Create("CheckBox")
    textCB:SetLabel(L.mbShowText)
    textCB:SetValue(barCfg.showText ~= false)
    textCB:SetFullWidth(true)
    textCB:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.showText = val
        Refresh()
    end)
    styleGroup:AddChild(textCB)

    local TEXT_ALIGN_ITEMS = {
        ["LEFT"]   = L.mbTextAlignLeft,
        ["CENTER"] = L.mbTextAlignCenter,
        ["RIGHT"]  = L.mbTextAlignRight,
    }
    local alignDD = AceGUI:Create("Dropdown")
    alignDD:SetLabel(L.mbTextAlign)
    alignDD:SetList(TEXT_ALIGN_ITEMS, { "LEFT", "CENTER", "RIGHT" })
    alignDD:SetValue(barCfg.textAlign or "RIGHT")
    alignDD:SetFullWidth(true)
    alignDD:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.textAlign = val
        Refresh()
    end)
    styleGroup:AddChild(alignDD)

    local txSlider = AceGUI:Create("Slider")
    txSlider:SetLabel(L.mbTextOffsetX)
    txSlider:SetSliderValues(-50, 50, 1)
    txSlider:SetValue(barCfg.textOffsetX or -4)
    txSlider:SetFullWidth(true)
    txSlider:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.textOffsetX = math.floor(val)
        Refresh()
    end)
    styleGroup:AddChild(txSlider)

    local tySlider = AceGUI:Create("Slider")
    tySlider:SetLabel(L.mbTextOffsetY)
    tySlider:SetSliderValues(-30, 30, 1)
    tySlider:SetValue(barCfg.textOffsetY or 0)
    tySlider:SetFullWidth(true)
    tySlider:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.textOffsetY = math.floor(val)
        Refresh()
    end)
    styleGroup:AddChild(tySlider)

    local fontItems, fontOrder = GetFontItems()
    if next(fontItems) then
        local fontDD = AceGUI:Create("Dropdown")
        fontDD:SetLabel(L.fontFamily)
        fontDD:SetList(fontItems, fontOrder)
        fontDD:SetValue(barCfg.fontName ~= "" and barCfg.fontName or nil)
        fontDD:SetFullWidth(true)
        fontDD:SetCallback("OnValueChanged", function(_, _, val)
            barCfg.fontName = val
            Refresh()
        end)
        styleGroup:AddChild(fontDD)
    end

    local fontSizeSlider = AceGUI:Create("Slider")
    fontSizeSlider:SetLabel(L.fontSize)
    fontSizeSlider:SetSliderValues(6, 24, 1)
    fontSizeSlider:SetValue(barCfg.fontSize or 12)
    fontSizeSlider:SetFullWidth(true)
    fontSizeSlider:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.fontSize = math.floor(val)
        Refresh()
    end)
    styleGroup:AddChild(fontSizeSlider)

    local outlineDD = AceGUI:Create("Dropdown")
    outlineDD:SetLabel(L.outline)
    outlineDD:SetList(OUTLINE_ITEMS, { "NONE", "OUTLINE", "THICKOUTLINE" })
    outlineDD:SetValue(barCfg.outline or "OUTLINE")
    outlineDD:SetFullWidth(true)
    outlineDD:SetCallback("OnValueChanged", function(_, _, val)
        barCfg.outline = val
        Refresh()
    end)
    styleGroup:AddChild(outlineDD)

    local deleteBtn = AceGUI:Create("Button")
    deleteBtn:SetText("|cffff4444" .. L.mbDeleteBar .. "|r")
    deleteBtn:SetFullWidth(true)
    local pendingDelete = false
    deleteBtn:SetCallback("OnClick", function()
        if not pendingDelete then
            pendingDelete = true
            deleteBtn:SetText("|cffff4444" .. L.mbDeleteConfirm .. "|r")
            C_Timer.After(5, function()
                if pendingDelete then
                    pendingDelete = false
                    deleteBtn:SetText("|cffff4444" .. L.mbDeleteBar .. "|r")
                end
            end)
        else
            pendingDelete = false
            MB:DestroyBar(barCfg.id)
            local bars = ns.db.monitorBars.bars
            for i, b in ipairs(bars) do
                if b.id == barCfg.id then
                    table.remove(bars, i)
                    break
                end
            end
            selectedBarIndex = math.max(1, selectedBarIndex - 1)
            rebuildAll()
        end
    end)
    container:AddChild(deleteBtn)
end

local catalogFrame = nil

local function ShowCatalog(rebuildTab)
    if InCombatLockdown() then
        print("|cff00ccff[CDFlow]|r " .. L.mbScanCombatWarn)
        return
    end

    MB:ScanCDMViewers()
    local cooldowns, auras = MB:GetSpellCatalog()

    if catalogFrame then
        catalogFrame:Release()
        catalogFrame = nil
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("CDFlow - " .. L.mbScanCatalog)
    frame:SetWidth(420)
    frame:SetHeight(500)
    frame:SetLayout("Fill")
    frame:SetCallback("OnClose", function(w) w:Release(); catalogFrame = nil end)
    frame:EnableResize(false)
    catalogFrame = frame

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    frame:AddChild(scroll)

    local cfg = ns.db.monitorBars

    local manualGroup = AceGUI:Create("InlineGroup")
    manualGroup:SetTitle(L.mbManualAdd)
    manualGroup:SetFullWidth(true)
    manualGroup:SetLayout("Flow")
    scroll:AddChild(manualGroup)

    local manualBox = AceGUI:Create("EditBox")
    manualBox:SetLabel(L.mbSpellID)
    manualBox:SetFullWidth(true)
    manualBox:SetCallback("OnEnterPressed", function(_, _, val)
        local spellID = tonumber(val)
        if not spellID or spellID <= 0 then return end
        local spellName = C_Spell.GetSpellName(spellID) or ""
        local chargeInfo = C_Spell.GetSpellCharges(spellID)
        local barType = chargeInfo and "charge" or "stack"
        local id = cfg.nextID or (#cfg.bars + 1)
        cfg.nextID = id + 1
        local bar = NewBarDefaults(id, barType, spellID, spellName)
        if chargeInfo and chargeInfo.maxCharges then
            if not issecretvalue or not issecretvalue(chargeInfo.maxCharges) then
                bar.maxCharges = chargeInfo.maxCharges
            end
        end
        table.insert(cfg.bars, bar)
        selectedBarIndex = #cfg.bars
        MB:RebuildAllBars()
        if rebuildTab then rebuildTab() end
        if catalogFrame then catalogFrame:Release(); catalogFrame = nil end
        print("|cff00ccff[CDFlow]|r " .. string.format(L.mbAdded, spellName ~= "" and spellName or tostring(spellID)))
    end)
    manualGroup:AddChild(manualBox)

    local function AddEntry(entry, barType)
        local btn = AceGUI:Create("InteractiveLabel")
        local tex = entry.icon and ("|T" .. entry.icon .. ":16:16:0:0|t ") or ""
        btn:SetText(tex .. "|cffffffff" .. entry.name .. "|r  |cff888888(" .. entry.spellID .. ")|r")
        btn:SetFullWidth(true)
        btn:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        btn:SetCallback("OnClick", function()
            local id = cfg.nextID or (#cfg.bars + 1)
            cfg.nextID = id + 1
            local bar = NewBarDefaults(id, barType, entry.spellID, entry.name, entry.unit)
            if barType == "charge" then
                local chargeInfo = C_Spell.GetSpellCharges(entry.spellID)
                if chargeInfo and chargeInfo.maxCharges then
                    if not issecretvalue or not issecretvalue(chargeInfo.maxCharges) then
                        bar.maxCharges = chargeInfo.maxCharges
                    end
                end
            end
            table.insert(cfg.bars, bar)
            selectedBarIndex = #cfg.bars
            MB:RebuildAllBars()
            if rebuildTab then rebuildTab() end
            print("|cff00ccff[CDFlow]|r " .. string.format(L.mbAdded, entry.name))
        end)
        scroll:AddChild(btn)
    end

    if #cooldowns > 0 then
        local h1 = AceGUI:Create("Heading")
        h1:SetText(L.mbCatalogCooldowns .. " (" .. #cooldowns .. ")")
        h1:SetFullWidth(true)
        scroll:AddChild(h1)
        for _, entry in ipairs(cooldowns) do
            AddEntry(entry, "charge")
        end
    end

    if #auras > 0 then
        local h2 = AceGUI:Create("Heading")
        h2:SetText(L.mbCatalogAuras .. " (" .. #auras .. ")")
        h2:SetFullWidth(true)
        scroll:AddChild(h2)
        for _, entry in ipairs(auras) do
            AddEntry(entry, "stack")
        end
    end

    if #cooldowns == 0 and #auras == 0 then
        local emptyLabel = AceGUI:Create("Label")
        emptyLabel:SetText("|cffaaaaaa" .. L.mbCatalogEmpty .. "|r")
        emptyLabel:SetFullWidth(true)
        scroll:AddChild(emptyLabel)
    end
end

function ns.BuildMonitorBarsTab(scroll)
    AceGUI = AceGUI or LibStub("AceGUI-3.0")
    LSM = LSM or LibStub("LibSharedMedia-3.0", true)

    local cfg = ns.db.monitorBars
    if not cfg then return end

    local function RebuildContent()
        scroll:ReleaseChildren()
        ns.BuildMonitorBarsTab(scroll)
        C_Timer.After(0, function()
            if scroll and scroll.DoLayout then scroll:DoLayout() end
        end)
    end

    local lockCB = AceGUI:Create("CheckBox")
    lockCB:SetLabel(L.mbLocked)
    lockCB:SetValue(cfg.locked or false)
    lockCB:SetFullWidth(true)
    lockCB:SetCallback("OnValueChanged", function(_, _, val)
        MB:SetLocked(val)
    end)
    scroll:AddChild(lockCB)

    local addBtn = AceGUI:Create("Button")
    addBtn:SetText(L.mbAddBar)
    addBtn:SetFullWidth(true)
    addBtn:SetCallback("OnClick", function()
        ShowCatalog(RebuildContent)
    end)
    scroll:AddChild(addBtn)

    if #cfg.bars == 0 then
        local emptyLabel = AceGUI:Create("Label")
        emptyLabel:SetText("\n|cffaaaaaa" .. L.mbNoBar .. "|r")
        emptyLabel:SetFullWidth(true)
        scroll:AddChild(emptyLabel)
        return
    end

    local heading = AceGUI:Create("Heading")
    heading:SetText(L.monitorBars)
    heading:SetFullWidth(true)
    scroll:AddChild(heading)

    local barItems, barOrder = GetBarDropdownList(cfg)
    if selectedBarIndex > #cfg.bars then
        selectedBarIndex = #cfg.bars
    end

    local barDD = AceGUI:Create("Dropdown")
    barDD:SetLabel(L.mbSelectBar)
    barDD:SetList(barItems, barOrder)
    barDD:SetValue(selectedBarIndex)
    barDD:SetFullWidth(true)
    barDD:SetCallback("OnValueChanged", function(_, _, val)
        selectedBarIndex = val
        RebuildContent()
    end)
    scroll:AddChild(barDD)

    local barCfg = cfg.bars[selectedBarIndex]
    if barCfg then
        local configGroup = AceGUI:Create("InlineGroup")
        local title = barCfg.spellName and barCfg.spellName ~= "" and barCfg.spellName or L.mbNoSpell
        configGroup:SetTitle(title)
        configGroup:SetFullWidth(true)
        configGroup:SetLayout("Flow")
        scroll:AddChild(configGroup)

        BuildBarConfig(configGroup, barCfg, RebuildContent)
    end

    C_Timer.After(0, function()
        if scroll and scroll.DoLayout then scroll:DoLayout() end
    end)
end
