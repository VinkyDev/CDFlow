-- 增益自定义分组设置面板
local _, ns = ...

local L      = ns.L
local UI     = ns.UI
local Layout = ns.Layout
local MB     = ns.MonitorBars

local AceGUI

-- 模块级状态（同 MonitorBarsTab 的 selectedBarIndex）
local selectedGroupIndex = 0  -- 默认选中0号组
local buffCatalogFrame   = nil
local PLAYER_CLASS_TAG = select(2, UnitClass("player"))
local CLASS_TAG_ORDER = {
    "ALL", "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK",
    "DRUID", "DEMONHUNTER", "EVOKER",
}

local function IsClassMatchedForCurrentPlayer(classTag)
    if classTag == nil or classTag == "" or classTag == "ALL" then
        return true
    end
    return classTag == PLAYER_CLASS_TAG
end

------------------------------------------------------
-- 内部工具
------------------------------------------------------

local function GetAceGUILib()
    return AceGUI or LibStub("AceGUI-3.0")
end

local function GetClassItems()
    local items, order = {}, {}
    items.ALL = L.classAll
    order[#order + 1] = "ALL"
    for i = 2, #CLASS_TAG_ORDER do
        local classTag = CLASS_TAG_ORDER[i]
        local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classTag]) or classTag
        items[classTag] = className
        order[#order + 1] = classTag
    end
    return items, order
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

    -- 0号组：只有启用时才显示
    local cfg0 = ns.db and ns.db.buffGroup0
    if cfg0 and cfg0.enabled then
        items[0] = "0. " .. (cfg0.name or L.bg0Title)
        order[#order + 1] = 0
    end

    -- 其他分组
    for i, group in ipairs(groups) do
        if IsClassMatchedForCurrentPlayer(group.class) then
            local name = (group.name and group.name ~= "") and group.name
                or string.format(L.bgGroupTitle, i, "")
            items[i]      = string.format("%d. %s", i, name)
            order[#order + 1] = i
        end
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

local function BuildGroup0Config(container, rebuildTab)
    local aceGUI = GetAceGUILib()
    local cfg = ns.db and ns.db.buffGroup0
    if not cfg then return end

    -- 名称
    local nameBox = aceGUI:Create("EditBox")
    nameBox:SetLabel(L.bgGroupName)
    nameBox:SetText(cfg.name or "")
    nameBox:SetFullWidth(true)
    nameBox:SetCallback("OnEnterPressed", function(_, _, val)
        cfg.name = val ~= "" and val or nil
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
    layoutDD:SetValue(cfg.horizontal ~= false and "horizontal" or "vertical")
    layoutDD:SetFullWidth(true)
    layoutDD:SetCallback("OnValueChanged", function(_, _, val)
        cfg.horizontal = (val == "horizontal")
        if Layout.RefreshBuffGroup0Layout then
            Layout:RefreshBuffGroup0Layout()
        end
        -- 如果正在预览，更新预览
        if Layout.IsBuffGroup0Previewing and Layout:IsBuffGroup0Previewing() then
            if Layout.ShowBuffGroup0Preview then
                Layout:ShowBuffGroup0Preview()
            end
        end
    end)
    container:AddChild(layoutDD)

    -- 尺寸覆盖
    local overrideSizeCB = aceGUI:Create("CheckBox")
    overrideSizeCB:SetLabel(L.bgOverrideSize)
    overrideSizeCB:SetValue(cfg.overrideSize or false)
    overrideSizeCB:SetFullWidth(true)
    overrideSizeCB:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(L.bgOverrideSizeTip, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    overrideSizeCB:SetCallback("OnLeave", function()
        GameTooltip:Hide()
    end)
    container:AddChild(overrideSizeCB)

    local widthSlider, heightSlider

    widthSlider = aceGUI:Create("Slider")
    widthSlider:SetLabel(L.bgIconWidth)
    widthSlider:SetSliderValues(20, 100, 1)
    widthSlider:SetValue(cfg.iconWidth or 40)
    widthSlider:SetFullWidth(true)
    widthSlider:SetDisabled(not (cfg.overrideSize or false))
    widthSlider:SetCallback("OnValueChanged", function(_, _, val)
        cfg.iconWidth = math.floor(val)
        if Layout.RefreshBuffGroup0Layout then
            Layout:RefreshBuffGroup0Layout()
        end
        -- 如果正在预览，更新预览
        if Layout.IsBuffGroup0Previewing and Layout:IsBuffGroup0Previewing() then
            if Layout.ShowBuffGroup0Preview then
                Layout:ShowBuffGroup0Preview()
            end
        end
    end)
    container:AddChild(widthSlider)

    heightSlider = aceGUI:Create("Slider")
    heightSlider:SetLabel(L.bgIconHeight)
    heightSlider:SetSliderValues(20, 100, 1)
    heightSlider:SetValue(cfg.iconHeight or 40)
    heightSlider:SetFullWidth(true)
    heightSlider:SetDisabled(not (cfg.overrideSize or false))
    heightSlider:SetCallback("OnValueChanged", function(_, _, val)
        cfg.iconHeight = math.floor(val)
        if Layout.RefreshBuffGroup0Layout then
            Layout:RefreshBuffGroup0Layout()
        end
        -- 如果正在预览，更新预览
        if Layout.IsBuffGroup0Previewing and Layout:IsBuffGroup0Previewing() then
            if Layout.ShowBuffGroup0Preview then
                Layout:ShowBuffGroup0Preview()
            end
        end
    end)
    container:AddChild(heightSlider)

    overrideSizeCB:SetCallback("OnValueChanged", function(_, _, val)
        cfg.overrideSize = val
        if widthSlider then
            widthSlider:SetDisabled(not val)
        end
        if heightSlider then
            heightSlider:SetDisabled(not val)
        end
        if Layout.RefreshBuffGroup0Layout then
            Layout:RefreshBuffGroup0Layout()
        end
        -- 如果正在预览，更新预览
        if Layout.IsBuffGroup0Previewing and Layout:IsBuffGroup0Previewing() then
            if Layout.ShowBuffGroup0Preview then
                Layout:ShowBuffGroup0Preview()
            end
        end
    end)

    -- 当前坐标
    local posLabel = aceGUI:Create("Label")
    posLabel:SetFullWidth(true)
    local x, y = cfg.x or 0, cfg.y or -320
    posLabel:SetText("|cff888888" .. L.position .. ":  "
        .. "|cffffffff" .. string.format("X: %d  Y: %d", x, y) .. "|r")
    container:AddChild(posLabel)

    local nudgeHint = aceGUI:Create("Label")
    nudgeHint:SetText("|cffaaaaaa" .. L.bgNudgeHint .. "|r")
    nudgeHint:SetFullWidth(true)
    nudgeHint:SetFontObject(GameFontHighlightSmall)
    container:AddChild(nudgeHint)

    -- 物品监控提示
    local itemHint = aceGUI:Create("Label")
    itemHint:SetText("|cffffcc00" .. L.bg0ItemHint .. "|r")
    itemHint:SetFullWidth(true)
    itemHint:SetFontObject(GameFontHighlightSmall)
    container:AddChild(itemHint)

    -- 预览提示
    local previewHint = aceGUI:Create("Label")
    previewHint:SetText("|cffaaaaaa" .. L.bg0PreviewHint .. "|r")
    previewHint:SetFullWidth(true)
    previewHint:SetFontObject(GameFontHighlightSmall)
    container:AddChild(previewHint)

    -- 预览按钮
    local previewBtn = aceGUI:Create("Button")
    local isPreviewing = Layout.IsBuffGroup0Previewing and Layout:IsBuffGroup0Previewing() or false
    previewBtn:SetText(isPreviewing and L.bg0HidePreview or L.bg0ShowPreview)
    previewBtn:SetFullWidth(true)
    previewBtn:SetCallback("OnClick", function()
        if Layout.IsBuffGroup0Previewing and Layout:IsBuffGroup0Previewing() then
            if Layout.HideBuffGroup0Preview then
                Layout:HideBuffGroup0Preview()
            end
            previewBtn:SetText(L.bg0ShowPreview)
        else
            if Layout.ShowBuffGroup0Preview then
                Layout:ShowBuffGroup0Preview()
            end
            previewBtn:SetText(L.bg0HidePreview)
        end
    end)
    container:AddChild(previewBtn)

    -- 自动检测饰品
    local autoTrinketsCB = aceGUI:Create("CheckBox")
    autoTrinketsCB:SetLabel(L.bg0AutoTrinkets)
    autoTrinketsCB:SetValue(cfg.autoTrinkets or false)
    autoTrinketsCB:SetFullWidth(true)
    autoTrinketsCB:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(L.bg0AutoTrinketsHint, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    autoTrinketsCB:SetCallback("OnLeave", function()
        GameTooltip:Hide()
    end)
    autoTrinketsCB:SetCallback("OnValueChanged", function(_, _, val)
        cfg.autoTrinkets = val
        -- 触发重新扫描
        if Layout.ScanBuffGroup0Items then
            Layout:ScanBuffGroup0Items()
        end
        rebuildTab()
    end)
    container:AddChild(autoTrinketsCB)

    -- 监控物品列表
    local itemSection = aceGUI:Create("InlineGroup")
    itemSection:SetTitle(L.bg0MonitorList)
    itemSection:SetFullWidth(true)
    itemSection:SetLayout("Flow")
    container:AddChild(itemSection)

    -- 添加物品按钮
    local addItemBtn = aceGUI:Create("Button")
    addItemBtn:SetText(L.bg0AddItem)
    addItemBtn:SetFullWidth(true)
    addItemBtn:SetCallback("OnClick", function()
        -- 弹出输入框
        StaticPopupDialogs["CDFLOW_ADD_ITEM"] = {
            text = L.bg0PotionHint or "输入物品ID",
            button1 = ACCEPT,
            button2 = CANCEL,
            hasEditBox = true,
            OnAccept = function(self)
                local editBox = self.editBox or _G[self:GetName().."EditBox"]
                local itemID = editBox and tonumber(editBox:GetText())
                if itemID then
                    if not cfg.potionItemIDs then
                        cfg.potionItemIDs = {}
                    end
                    -- 检查是否已存在
                    local exists = false
                    for _, id in ipairs(cfg.potionItemIDs) do
                        if id == itemID then
                            exists = true
                            break
                        end
                    end
                    if not exists then
                        table.insert(cfg.potionItemIDs, itemID)
                        -- 触发重新扫描
                        if Layout.ScanBuffGroup0Items then
                            Layout:ScanBuffGroup0Items()
                        end
                        if rebuildTab then rebuildTab() end
                    else
                        print("|cff00ccff[CDFlow]|r 物品已存在")
                    end
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("CDFLOW_ADD_ITEM")
    end)
    itemSection:AddChild(addItemBtn)

    -- 获取自动检测的物品列表
    local autoItems = Layout.GetBuffGroup0AutoItems and Layout:GetBuffGroup0AutoItems() or {}

    -- 显示自动检测的饰品（灰色，无删除按钮）
    if cfg.autoTrinkets then
        for itemID in pairs(autoItems) do
            local row = aceGUI:Create("SimpleGroup")
            row:SetFullWidth(true)
            row:SetLayout("Flow")
            itemSection:AddChild(row)

            local itemName = C_Item.GetItemNameByID(itemID) or ("ID: " .. itemID)
            local iconPath = C_Item.GetItemIconByID(itemID)

            if iconPath then
                local iconWidget = aceGUI:Create("Icon")
                iconWidget:SetImage(iconPath)
                iconWidget:SetImageSize(20, 20)
                iconWidget:SetWidth(28)
                row:AddChild(iconWidget)
            end

            local nameLabel = aceGUI:Create("Label")
            nameLabel:SetText("|cffaaaaaa" .. itemName .. " " .. L.bg0AutoDetected .. "|r  |cff666666(" .. itemID .. ")|r")
            nameLabel:SetWidth(280)
            row:AddChild(nameLabel)
        end
    end

    -- 显示手动添加的物品
    if cfg.potionItemIDs and #cfg.potionItemIDs > 0 then
        for _, itemID in ipairs(cfg.potionItemIDs) do
            local row = aceGUI:Create("SimpleGroup")
            row:SetFullWidth(true)
            row:SetLayout("Flow")
            itemSection:AddChild(row)

            local itemName = C_Item.GetItemNameByID(itemID) or ("ID: " .. itemID)
            local iconPath = C_Item.GetItemIconByID(itemID)

            if iconPath then
                local iconWidget = aceGUI:Create("Icon")
                iconWidget:SetImage(iconPath)
                iconWidget:SetImageSize(20, 20)
                iconWidget:SetWidth(28)
                row:AddChild(iconWidget)
            end

            local nameLabel = aceGUI:Create("Label")
            nameLabel:SetText("|cffffffff" .. itemName .. "|r  |cff888888(" .. itemID .. ")|r")
            nameLabel:SetWidth(240)
            row:AddChild(nameLabel)

            local removeBtn = aceGUI:Create("Button")
            removeBtn:SetText(L.bgRemoveSpell)
            removeBtn:SetWidth(80)
            removeBtn:SetCallback("OnClick", function()
                -- 从列表中移除
                for i, id in ipairs(cfg.potionItemIDs) do
                    if id == itemID then
                        table.remove(cfg.potionItemIDs, i)
                        break
                    end
                end
                -- 触发重新扫描
                if Layout.ScanBuffGroup0Items then
                    Layout:ScanBuffGroup0Items()
                end
                rebuildTab()
            end)
            row:AddChild(removeBtn)
        end
    end

    -- 如果列表为空
    if not cfg.autoTrinkets and (not cfg.potionItemIDs or #cfg.potionItemIDs == 0) then
        local emptyLabel = aceGUI:Create("Label")
        emptyLabel:SetText("|cff888888" .. L.bgSpellListEmpty .. "|r")
        emptyLabel:SetFullWidth(true)
        itemSection:AddChild(emptyLabel)
    end

    -- 不能删除0号组的提示
    local cannotDeleteLabel = aceGUI:Create("Label")
    cannotDeleteLabel:SetText("|cffff8888" .. L.bg0CannotDelete .. "|r")
    cannotDeleteLabel:SetFullWidth(true)
    container:AddChild(cannotDeleteLabel)
end

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

    -- 尺寸覆盖
    local overrideSizeCB = aceGUI:Create("CheckBox")
    overrideSizeCB:SetLabel(L.bgOverrideSize)
    overrideSizeCB:SetValue(group.overrideSize or false)
    overrideSizeCB:SetFullWidth(true)
    overrideSizeCB:SetCallback("OnEnter", function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(L.bgOverrideSizeTip, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    overrideSizeCB:SetCallback("OnLeave", function()
        GameTooltip:Hide()
    end)
    container:AddChild(overrideSizeCB)

    -- 声明尺寸滑块的引用，以便在复选框变化时更新它们的状态
    local widthSlider, heightSlider

    local widthSlider = aceGUI:Create("Slider")
    widthSlider:SetLabel(L.bgIconWidth)
    widthSlider:SetSliderValues(20, 100, 1)
    widthSlider:SetValue(group.iconWidth or 40)
    widthSlider:SetFullWidth(true)
    widthSlider:SetDisabled(not (group.overrideSize or false))
    widthSlider:SetCallback("OnValueChanged", function(_, _, val)
        group.iconWidth = math.floor(val)
        RefreshBuffView()
    end)
    container:AddChild(widthSlider)

    local heightSlider = aceGUI:Create("Slider")
    heightSlider:SetLabel(L.bgIconHeight)
    heightSlider:SetSliderValues(20, 100, 1)
    heightSlider:SetValue(group.iconHeight or 40)
    heightSlider:SetFullWidth(true)
    heightSlider:SetDisabled(not (group.overrideSize or false))
    heightSlider:SetCallback("OnValueChanged", function(_, _, val)
        group.iconHeight = math.floor(val)
        RefreshBuffView()
    end)
    container:AddChild(heightSlider)

    -- 更新复选框回调，启用/禁用尺寸滑块
    overrideSizeCB:SetCallback("OnValueChanged", function(_, _, val)
        group.overrideSize = val
        if widthSlider then
            widthSlider:SetDisabled(not val)
        end
        if heightSlider then
            heightSlider:SetDisabled(not val)
        end
        RefreshBuffView()
    end)

    -- 载入职业
    local classItems, classOrder = GetClassItems()
    local classDD = aceGUI:Create("Dropdown")
    classDD:SetLabel(L.bgLoadClass)
    classDD:SetList(classItems, classOrder)
    classDD:SetValue(group.class or "ALL")
    classDD:SetFullWidth(true)
    classDD:SetCallback("OnValueChanged", function(_, _, val)
        group.class = val
        if Layout.InitBuffGroups then
            Layout:InitBuffGroups()
        end
        RefreshBuffView()
        rebuildTab()
    end)
    container:AddChild(classDD)

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
    -- 0号组不允许删除
    if groupIdx ~= 0 then
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
                selectedGroupIndex = math.max(0, selectedGroupIndex - 1)  -- 最小为0号组
                RefreshBuffView()
                rebuildTab()
            end
        end)
        container:AddChild(deleteBtn)
    else
        local cannotDeleteLabel = aceGUI:Create("Label")
        cannotDeleteLabel:SetText("|cffff8888" .. L.bg0CannotDelete .. "|r")
        cannotDeleteLabel:SetFullWidth(true)
        container:AddChild(cannotDeleteLabel)
    end
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

    -- 0号组启用开关（独立显示）
    local cfg0 = ns.db and ns.db.buffGroup0
    if cfg0 then
        local group0EnableCB = AceGUI:Create("CheckBox")
        group0EnableCB:SetLabel(L.bg0Enable)
        group0EnableCB:SetValue(cfg0.enabled or false)
        group0EnableCB:SetFullWidth(true)
        group0EnableCB:SetCallback("OnValueChanged", function(_, _, val)
            cfg0.enabled = val
            if Layout.InitBuffGroup0 then
                Layout:InitBuffGroup0()
            end
            RefreshBuffView()
            -- 启用后自动选中0号组
            if val then
                selectedGroupIndex = 0
            end
            RebuildContent()
        end)
        scroll:AddChild(group0EnableCB)
    end

    -- 新建分组
    local addBtn = AceGUI:Create("Button")
    addBtn:SetText(L.bgAddGroup)
    addBtn:SetFullWidth(true)
    addBtn:SetCallback("OnClick", function()
        local idx = #groups + 1
        local playerClass = select(2, UnitClass("player"))
        groups[idx] = {
            name       = string.format("Group %d", idx),
            class      = playerClass,
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

    local groupItems, groupOrder = GetGroupDropdownList(groups)
    if #groupOrder == 0 then
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

    local selectedVisible = false
    for _, idx in ipairs(groupOrder) do
        if idx == selectedGroupIndex then
            selectedVisible = true
            break
        end
    end
    if not selectedVisible then
        selectedGroupIndex = groupOrder[1]
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
    if selectedGroupIndex == 0 then
        -- 0号组特殊配置
        local cfg = ns.db and ns.db.buffGroup0
        if cfg then
            local configGroup = AceGUI:Create("InlineGroup")
            local title = cfg.name or L.bg0Title
            configGroup:SetTitle(title)
            configGroup:SetFullWidth(true)
            configGroup:SetLayout("Flow")
            scroll:AddChild(configGroup)

            BuildGroup0Config(configGroup, RebuildContent)
        end
    else
        -- 普通分组配置
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
    end

    C_Timer.After(0, function()
        if scroll and scroll.DoLayout then scroll:DoLayout() end
    end)
end
