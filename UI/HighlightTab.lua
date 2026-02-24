-- 高亮特效选项卡
local _, ns = ...

local L = ns.L
local Layout = ns.Layout
local Style  = ns.Style
local UI = ns.UI

local function BuildStyleOptions(parent, cfg, onChanged)
    local style = cfg.style
    if style == "DEFAULT" or style == "NONE" or style == "PROC" then
        return
    end

    if style == "PIXEL" then
        UI.AddGlowSlider(parent, L.hlLines, 1, 16, 1, cfg.lines, function(v)
            cfg.lines = v
            onChanged()
        end)
        UI.AddGlowSlider(parent, L.hlThickness, 1, 5, 1, cfg.thickness, function(v)
            cfg.thickness = v
            onChanged()
        end)
    end

    if style == "PIXEL" or style == "AUTOCAST" or style == "BUTTON" then
        UI.AddGlowSlider(parent, L.hlFrequency, 0.05, 1, 0.05, cfg.frequency, function(v)
            cfg.frequency = v
            onChanged()
        end)
    end

    if style == "AUTOCAST" then
        UI.AddGlowSlider(parent, L.hlScale, 0.5, 2, 0.1, cfg.scale, function(v)
            cfg.scale = v
            onChanged()
        end)
    end
end

function ns.BuildHighlightTab(scroll)
    local AceGUI = LibStub("AceGUI-3.0")
    local cfg = ns.db.highlight
    local buffCfg = ns.db.buffGlow

    local function refreshSkillGlows()
        Style:RefreshAllGlows()
    end

    local function refreshBuffLayout()
        Layout:RefreshViewer("BuffIconCooldownViewer")
    end

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

    UI.AddHeading(scroll, L.skillGlow)

    local skillStyleDD = AceGUI:Create("Dropdown")
    skillStyleDD:SetLabel(L.hlStyle)
    skillStyleDD:SetList(UI.HL_ITEMS, { "DEFAULT", "PIXEL", "AUTOCAST", "PROC", "BUTTON", "NONE" })
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

    UI.AddHeading(scroll, L.buffGlow)

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
        dd:SetList(UI.HL_ITEMS, { "DEFAULT", "PIXEL", "AUTOCAST", "PROC", "BUTTON", "NONE" })
        dd:SetValue(buffCfg.style)
        dd:SetFullWidth(true)
        dd:SetCallback("OnValueChanged", function(_, _, v)
            buffCfg.style = v
            RebuildBuffOptions()
            refreshBuffGlowStyle()
        end)
        buffOptGroup:AddChild(dd)

        BuildStyleOptions(buffOptGroup, buffCfg, refreshBuffGlowStyle)

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
