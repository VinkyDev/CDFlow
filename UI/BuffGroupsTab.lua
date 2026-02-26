-- 增益自定义分组设置面板
local _, ns = ...

local L      = ns.L
local UI     = ns.UI
local Layout = ns.Layout
local MB     = ns.MonitorBars

local AceGUI

-- 模块级状态（同 MonitorBarsTab 的 selectedBarIndex）
local selectedGroupIndex = 1
local buffCatalogFrame   = nil

------------------------------------------------------
-- 内部工具
------------------------------------------------------

local function GetAceGUILib()
    return AceGUI or LibStub("AceGUI-3.0")
end

-- 重新刷新 Buff 查看器（分组变更后调用）
local function RefreshBuffView()
    if Layout.MarkBuffGroupsDirty then
        Layout:MarkBuffGroupsDirty()
    end
    local viewer = _G["BuffIconCooldownViewer"]
    if viewer and Layout.RefreshViewer then
        Layout:RefreshViewer("BuffIconCooldownViewer")
    end
end

------------------------------------------------------
-- 分组下拉菜单数据
------------------------------------------------------

local function GetGroupDropdownList(groups)
    local items, order = {}, {}
    for i, group in ipairs(groups) do
        local name = (group.name and group.name ~= "") and group.name
            or string.format(L.bgGroupTitle, i, "")
        items[i]      = string.format("%d. %s", i, name)
        order[#order + 1] = i
    end
    return items, order
end

------------------------------------------------------
-- 快捷添加 Buff 目录弹窗
------------------------------------------------------

local function ShowBuffCatalog(groupIdx, rebuildTab)
    if InCombatLockdown() then
        print("|cff00ccff[CDFlow]|r " .. (L.mbScanCombatWarn or "Cannot scan in combat"))
        return
    end

    local groups = ns.db and ns.db.buffGroups
    if not groups or not groups[groupIdx] then return end

    if buffCatalogFrame then
        buffCatalogFrame:Release()
        buffCatalogFrame = nil
    end

    -- 修复：Lua 多返回值解析问题，逗号右侧的 {} 会覆盖第二个返回值
    local _, auras = {}, {}
    if MB then
        MB:ScanCDMViewers()
        _, auras = MB:GetSpellCatalog()
    end

    local function AddBuff(spellID, spellName)
        if not groups[groupIdx] then return end
        if not groups[groupIdx].spellIDs then
            groups[groupIdx].spellIDs = {}
        end
        groups[groupIdx].spellIDs[spellID] = true
        RefreshBuffView()
        if rebuildTab then rebuildTab() end
        print("|cff00ccff[CDFlow]|r " .. string.format(
            (L.mbAdded or "Added: %s"), spellName ~= "" and spellName or tostring(spellID)))
    end

    buffCatalogFrame = ns.UI.OpenSpellCatalogFrame(
        "CDFlow - " .. L.bgCatalogTitle,
        {
            {
                heading  = L.bgSpellListTitle,
                entries  = auras,
                onSelect = function(entry)
                    AddBuff(entry.spellID, entry.name)
                end,
            },
        },
        function(spellID, spellName)
            AddBuff(spellID, spellName)
        end
    )
    buffCatalogFrame:SetCallback("OnClose", function(w) w:Release(); buffCatalogFrame = nil end)
end

------------------------------------------------------
-- 当前选中分组的配置区块
------------------------------------------------------

local function BuildGroupConfig(container, groupIdx, rebuildTab)
    local aceGUI = GetAceGUILib()
    local groups = ns.db and ns.db.buffGroups
    if not groups then return end
    local group = groups[groupIdx]
    if not group then return end

    -- 名称
    local nameBox = aceGUI:Create("EditBox")
    nameBox:SetLabel(L.bgGroupName)
    nameBox:SetText(group.name or "")
    nameBox:SetFullWidth(true)
    nameBox:SetCallback("OnEnterPressed", function(_, _, val)
        group.name = val ~= "" and val or nil
        rebuildTab()
    end)
    container:AddChild(nameBox)

    -- 布局方向
    local layoutItems = {
        ["horizontal"] = L.bgLayoutHorizontal,
        ["vertical"]   = L.bgLayoutVertical,
    }
    local layoutDD = aceGUI:Create("Dropdown")
    layoutDD:SetLabel(L.bgGroupLayout)
    layoutDD:SetList(layoutItems, { "horizontal", "vertical" })
    layoutDD:SetValue(group.horizontal ~= false and "horizontal" or "vertical")
    layoutDD:SetFullWidth(true)
    layoutDD:SetCallback("OnValueChanged", function(_, _, val)
        group.horizontal = (val == "horizontal")
        RefreshBuffView()
    end)
    container:AddChild(layoutDD)

    -- 当前坐标（只读显示，由拖动/滚轮更新）
    local posLabel = aceGUI:Create("Label")
    posLabel:SetFullWidth(true)
    local x, y = group.x or 0, group.y or -260
    posLabel:SetText("|cff888888" .. L.position .. ":  "
        .. "|cffffffff" .. string.format("X: %d  Y: %d", x, y) .. "|r")
    container:AddChild(posLabel)

    local nudgeHint = aceGUI:Create("Label")
    nudgeHint:SetText("|cffaaaaaa" .. L.bgNudgeHint .. "|r")
    nudgeHint:SetFullWidth(true)
    nudgeHint:SetFontObject(GameFontHighlightSmall)
    container:AddChild(nudgeHint)

    -- 打开编辑模式按钮（不关闭设置面板，与 GeneralTab 实现一致）
    local editModeBtn = aceGUI:Create("Button")
    editModeBtn:SetText(L.openEditMode)
    editModeBtn:SetFullWidth(true)
    editModeBtn:SetCallback("OnClick", function()
        if InCombatLockdown() then return end
        local frame = _G.EditModeManagerFrame
        if not frame then
            local loader = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
            if loader then loader("Blizzard_EditMode") end
            frame = _G.EditModeManagerFrame
        end
        if frame then
            if frame.CanEnterEditMode and not frame:CanEnterEditMode() then return end
            if frame:IsShown() then HideUIPanel(frame) else ShowUIPanel(frame) end
        end
    end)
    container:AddChild(editModeBtn)

    -- CDM 追踪提示
    local cdmHint = aceGUI:Create("Label")
    cdmHint:SetText("|cffffcc00" .. L.bgCDMHint .. "|r")
    cdmHint:SetFullWidth(true)
    cdmHint:SetFontObject(GameFontHighlightSmall)
    container:AddChild(cdmHint)

    -- 已添加 Buff 区域
    local spellSection = aceGUI:Create("InlineGroup")
    spellSection:SetTitle(L.bgSpellListTitle)
    spellSection:SetFullWidth(true)
    spellSection:SetLayout("Flow")
    container:AddChild(spellSection)

    -- 添加 Buff 按钮 → 弹出目录
    local addBuffBtn = aceGUI:Create("Button")
    addBuffBtn:SetText(L.bgAddBuff)
    addBuffBtn:SetFullWidth(true)
    addBuffBtn:SetCallback("OnClick", function()
        ShowBuffCatalog(groupIdx, rebuildTab)
    end)
    spellSection:AddChild(addBuffBtn)

    -- 已添加技能列表
    local spellIDs = group.spellIDs or {}
    local sortedIDs = {}
    for id in pairs(spellIDs) do
        sortedIDs[#sortedIDs + 1] = id
    end
    table.sort(sortedIDs)

    if #sortedIDs == 0 then
        local emptyLabel = aceGUI:Create("Label")
        emptyLabel:SetText("|cff888888" .. L.bgSpellListEmpty .. "|r")
        emptyLabel:SetFullWidth(true)
        spellSection:AddChild(emptyLabel)
    else
        for _, spellID in ipairs(sortedIDs) do
            local row = aceGUI:Create("SimpleGroup")
            row:SetFullWidth(true)
            row:SetLayout("Flow")
            spellSection:AddChild(row)

            local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
            local spellName = spellInfo and spellInfo.name or ("ID: " .. spellID)
            local iconPath  = spellInfo and spellInfo.iconID

            if iconPath then
                local iconWidget = aceGUI:Create("Icon")
                iconWidget:SetImage(iconPath)
                iconWidget:SetImageSize(20, 20)
                iconWidget:SetWidth(28)
                row:AddChild(iconWidget)
            end

            local nameLabel = aceGUI:Create("Label")
            nameLabel:SetText("|cffffffff" .. spellName .. "|r  |cff888888(" .. spellID .. ")|r")
            nameLabel:SetWidth(240)
            row:AddChild(nameLabel)

            local removeBtn = aceGUI:Create("Button")
            removeBtn:SetText(L.bgRemoveSpell)
            removeBtn:SetWidth(80)
            removeBtn:SetCallback("OnClick", function()
                group.spellIDs[spellID] = nil
                RefreshBuffView()
                rebuildTab()
            end)
            row:AddChild(removeBtn)
        end
    end

    -- 删除此组（二次确认，同 MonitorBars 删除逻辑）
    local sep = aceGUI:Create("Heading")
    sep:SetText("")
    sep:SetFullWidth(true)
    container:AddChild(sep)

    local deleteBtn = aceGUI:Create("Button")
    deleteBtn:SetText("|cffff4444" .. L.bgDeleteGroup .. "|r")
    deleteBtn:SetFullWidth(true)
    local pendingDelete = false
    deleteBtn:SetCallback("OnClick", function()
        if not pendingDelete then
            pendingDelete = true
            deleteBtn:SetText("|cffff4444" .. (L.mbDeleteConfirm or "Confirm delete?") .. "|r")
            C_Timer.After(5, function()
                if pendingDelete then
                    pendingDelete = false
                    deleteBtn:SetText("|cffff4444" .. L.bgDeleteGroup .. "|r")
                end
            end)
        else
            pendingDelete = false
            local groups2 = ns.db and ns.db.buffGroups
            if groups2 then table.remove(groups2, groupIdx) end
            if Layout.InitBuffGroups then Layout:InitBuffGroups() end
            selectedGroupIndex = math.max(1, selectedGroupIndex - 1)
            RefreshBuffView()
            rebuildTab()
        end
    end)
    container:AddChild(deleteBtn)
end

------------------------------------------------------
-- 主入口
------------------------------------------------------

function ns.BuildBuffGroupsTab(scroll)
    AceGUI = AceGUI or LibStub("AceGUI-3.0")

    local groups = ns.db and ns.db.buffGroups
    if not groups then
        local errLabel = AceGUI:Create("Label")
        errLabel:SetText("|cffff4444DB not ready|r")
        errLabel:SetFullWidth(true)
        scroll:AddChild(errLabel)
        return
    end

    local function RebuildContent()
        scroll:ReleaseChildren()
        ns.BuildBuffGroupsTab(scroll)
        C_Timer.After(0, function()
            if scroll and scroll.DoLayout then scroll:DoLayout() end
        end)
    end

    -- 全局锁定（同 MonitorBars 全局锁）
    local lockCB = AceGUI:Create("CheckBox")
    lockCB:SetLabel(L.bgLockAll)
    lockCB:SetValue(ns.db.buffGroupsLocked or false)
    lockCB:SetFullWidth(true)
    lockCB:SetCallback("OnValueChanged", function(_, _, val)
        if Layout.SetBuffGroupsLocked then
            Layout:SetBuffGroupsLocked(val)
        end
    end)
    scroll:AddChild(lockCB)

    -- 新建分组
    local addBtn = AceGUI:Create("Button")
    addBtn:SetText(L.bgAddGroup)
    addBtn:SetFullWidth(true)
    addBtn:SetCallback("OnClick", function()
        local idx = #groups + 1
        groups[idx] = {
            name       = string.format("Group %d", idx),
            horizontal = true,
            x          = 0,
            y          = -260 - (idx - 1) * 60,
            spellIDs   = {},
        }
        if Layout.InitBuffGroups then Layout:InitBuffGroups() end
        selectedGroupIndex = idx
        RebuildContent()
    end)
    scroll:AddChild(addBtn)

    if #groups == 0 then
        local emptyLabel = AceGUI:Create("Label")
        emptyLabel:SetText("\n|cffaaaaaa" .. L.bgNoGroups .. "|r")
        emptyLabel:SetFullWidth(true)
        scroll:AddChild(emptyLabel)
        return
    end

    -- 分组选择下拉框（同 MonitorBars 的 barDD）
    local heading = AceGUI:Create("Heading")
    heading:SetText(L.buffGroups)
    heading:SetFullWidth(true)
    scroll:AddChild(heading)

    local groupItems, groupOrder = GetGroupDropdownList(groups)
    if selectedGroupIndex > #groups then
        selectedGroupIndex = #groups
    end

    local groupDD = AceGUI:Create("Dropdown")
    groupDD:SetLabel(L.bgSelectGroup)
    groupDD:SetList(groupItems, groupOrder)
    groupDD:SetValue(selectedGroupIndex)
    groupDD:SetFullWidth(true)
    groupDD:SetCallback("OnValueChanged", function(_, _, val)
        selectedGroupIndex = val
        RebuildContent()
    end)
    scroll:AddChild(groupDD)

    -- 当前选中分组的配置
    local groupCfg = groups[selectedGroupIndex]
    if groupCfg then
        local configGroup = AceGUI:Create("InlineGroup")
        local title = (groupCfg.name and groupCfg.name ~= "")
            and groupCfg.name
            or string.format(L.bgGroupTitle, selectedGroupIndex, "")
        configGroup:SetTitle(title)
        configGroup:SetFullWidth(true)
        configGroup:SetLayout("Flow")
        scroll:AddChild(configGroup)

        BuildGroupConfig(configGroup, selectedGroupIndex, RebuildContent)
    end

    C_Timer.After(0, function()
        if scroll and scroll.DoLayout then scroll:DoLayout() end
    end)
end
