-- 物品监控模块：追踪饰品/药水等物品冷却，显示为可拖拽图标容器
-- 冷却 API 参考 Ayije_CDM Racials.lua + Trinkets.lua
local _, ns = ...

local IM = {}
ns.ItemMonitor = IM

local Style = ns.Style

------------------------------------------------------
-- 模块状态
------------------------------------------------------

local container   = nil   -- 可拖拽容器帧（UIParent 子帧）
local iconFrames  = {}    -- itemID (number) → frame
local itemOrder   = {}    -- 有序 itemID 列表（用于布局）

-- 物品名称/图标缓存（async 加载后填充）
local itemDataCache = {}  -- itemID → { name, icon }

------------------------------------------------------
-- 工具函数
------------------------------------------------------

local function RoundToPixel(v)
    return math.floor(v + 0.5)
end

local function GetCfg()
    return ns.db and ns.db.itemMonitor
end

local function IsLocked()
    local cfg = GetCfg()
    return cfg and cfg.locked or false
end

------------------------------------------------------
-- 物品数据（名称 + 图标）
------------------------------------------------------

-- 尝试从缓存或 C_Item API 获取物品信息；如果数据未加载则发起异步请求
local function GetItemData(itemID)
    if itemDataCache[itemID] then return itemDataCache[itemID] end

    local name = C_Item.GetItemNameByID(itemID)
    local icon = C_Item.GetItemIconByID(itemID)

    if name then
        itemDataCache[itemID] = { name = name, icon = icon }
        return itemDataCache[itemID]
    end

    -- 异步加载，GET_ITEM_INFO_RECEIVED 触发后调用 RefreshItemNames
    C_Item.RequestLoadItemDataByID(itemID)
    return nil
end

------------------------------------------------------
-- 冷却更新（参考 Ayije_CDM Racials.lua 340-347 行）
------------------------------------------------------

local function UpdateItemCooldown(frame)
    if not frame or not frame.itemID then return end
    local itemID = frame.itemID

    -- 主路径：背包物品冷却
    local start, duration, enable = C_Container.GetItemCooldown(itemID)

    -- Fallback：装备槽（饰品槽 13/14）
    if not (start and duration and duration > 1.5) then
        for _, slotID in ipairs({ 13, 14 }) do
            local equippedID = GetInventoryItemID("player", slotID)
            if equippedID and equippedID == itemID then
                start, duration, enable = GetInventoryItemCooldown("player", slotID)
                break
            end
        end
    end

    if start and duration and duration > 1.5 then
        frame.Cooldown:SetCooldown(start, duration)
    else
        frame.Cooldown:Clear()
    end
end

------------------------------------------------------
-- 布局
------------------------------------------------------

local function LayoutIcons()
    local cfg = GetCfg()
    if not cfg or not container then return end
    if #itemOrder == 0 then
        container:Hide()
        return
    end
    container:Show()

    local w, h        = cfg.iconWidth, cfg.iconHeight
    local spacingX    = cfg.spacingX or 2
    local spacingY    = cfg.spacingY or 2
    local iconsPerRow = cfg.iconsPerRow or 6
    local growDir     = cfg.growDir or "TOP"
    local rowAnchor   = cfg.rowAnchor or "CENTER"

    if iconsPerRow <= 0 then iconsPerRow = #itemOrder end

    -- 分行（仅排布当前显示的图标；数量为 0 且选择隐藏时该帧不参与布局）
    local rows = {}
    local visibleCount = 0
    for i, itemID in ipairs(itemOrder) do
        local frame = iconFrames[itemID]
        if frame and frame:IsShown() then
            visibleCount = visibleCount + 1
            local ri = math.floor((visibleCount - 1) / iconsPerRow) + 1
            rows[ri] = rows[ri] or {}
            rows[ri][#rows[ri] + 1] = frame
        end
    end

    local numRows = #rows
    if visibleCount == 0 then
        container:Hide()
        return
    end

    -- 计算容器尺寸
    local maxCols = 0
    for _, row in ipairs(rows) do
        if #row > maxCols then maxCols = #row end
    end
    local containerW = maxCols * w + (maxCols - 1) * spacingX
    local containerH = numRows * h + (numRows - 1) * spacingY
    container:SetSize(math.max(containerW, w), math.max(containerH, h))

    -- growDir 决定行起始方向：TOP = 从上往下，BOTTOM = 从下往上
    local rowDirMult = (growDir == "BOTTOM") and 1 or -1  -- BOTTOM 向上增长
    local firstRowY  = (growDir == "BOTTOM") and (containerH / 2 - h / 2)
                                               or -(containerH / 2 - h / 2)

    for ri, row in ipairs(rows) do
        local rowCount = #row
        local rowW = rowCount * w + (rowCount - 1) * spacingX

        -- 行内锚点偏移
        local startX
        if rowAnchor == "LEFT" then
            startX = -containerW / 2 + w / 2
        elseif rowAnchor == "RIGHT" then
            startX = containerW / 2 - rowW + w / 2
        else -- CENTER
            startX = -rowW / 2 + w / 2
        end

        local rowY = firstRowY + (ri - 1) * rowDirMult * (-(h + spacingY))

        for ci, frame in ipairs(row) do
            local x = startX + (ci - 1) * (w + spacingX)
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", container, "CENTER", x, rowY)
            frame:Show()
        end
    end

    -- 隐藏不再使用的帧（不应发生，但做防护）
    for itemID, frame in pairs(iconFrames) do
        local found = false
        for _, id in ipairs(itemOrder) do
            if id == itemID then found = true; break end
        end
        if not found then frame:Hide() end
    end
end

------------------------------------------------------
-- 物品数量显示
------------------------------------------------------

local DEFAULT_FONT = ns._styleConst and ns._styleConst.DEFAULT_FONT or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
local ResolveFontPath = ns.ResolveFontPath or function() return DEFAULT_FONT end

local function UpdateItemCount(frame)
    if not frame or not frame.itemID then return end
    local cfg = GetCfg()
    local count = 0
    if C_Item and C_Item.GetItemCount then
        count = C_Item.GetItemCount(frame.itemID) or 0
    end

    -- 无 itemCount 配置时：始终显示图标、不显示数量文字
    if not cfg or not cfg.itemCount then
        if frame._cdf_itemCount then frame._cdf_itemCount:Hide() end
        frame:Show()
        if frame.Icon then frame.Icon:SetVertexColor(1, 1, 1, 1) end
        return
    end

    local ic = cfg.itemCount
    local whenZero = ic.whenZero or "gray"

    -- 数量为 0 时：整颗图标变灰或整颗图标隐藏（与是否启用数量文字无关，均生效）
    if count == 0 and whenZero == "hide" then
        if frame._cdf_itemCount then frame._cdf_itemCount:Hide() end
        frame:Hide()
        return
    end

    frame:Show()
    if frame.Icon then
        if count == 0 and whenZero == "gray" then
            frame.Icon:SetVertexColor(0.5, 0.5, 0.5, 1)
        else
            frame.Icon:SetVertexColor(1, 1, 1, 1)
        end
    end

    -- 数量文字：仅当启用且数量不为 1 时显示（数量为 1 固定不显示）
    if not frame._cdf_itemCount then
        local fs = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
        frame._cdf_itemCount = fs
    end
    local fs = frame._cdf_itemCount
    if not ic.enabled or count == 1 then
        fs:Hide()
    else
        local ox = ic.offsetX or -2
        local oy = ic.offsetY or 2
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", ox, oy)
        local fontSize = ic.fontSize or 12
        local fontPath = ResolveFontPath("默认")
        if not fs:SetFont(fontPath, fontSize, "OUTLINE") then
            fs:SetFont(DEFAULT_FONT, fontSize, "OUTLINE")
        end
        fs:SetText(tostring(count))
        fs:SetTextColor(1, 1, 1, 1)
        fs:Show()
    end
end

------------------------------------------------------
-- 样式应用
------------------------------------------------------

local function ApplyStyleToFrame(frame)
    local cfg = GetCfg()
    if not cfg then return end

    -- icon 尺寸/裁剪/边框（复用 Style:ApplyIcon，帧结构兼容）
    if Style and Style.ApplyIcon then
        Style:ApplyIcon(frame, cfg.iconWidth, cfg.iconHeight,
            ns.db.iconZoom or 0.08, ns.db.borderSize or 1)
    end

    -- 物品数量
    UpdateItemCount(frame)

    -- 冷却读秒文字（复用 Style:ApplyCooldownText）
    if Style and Style.ApplyCooldownText then
        Style:ApplyCooldownText(frame, cfg)
    end

    -- 键位显示（复用 Style:ApplyKeybind，支持 button.itemID 与 itemMonitor.keybind）
    if Style and Style.ApplyKeybind then
        Style:ApplyKeybind(frame, cfg)
    end
end

------------------------------------------------------
-- 图标帧管理
------------------------------------------------------

local function CreateIconFrame(itemID)
    local frame = CreateFrame("Frame", nil, container)
    local cfg   = GetCfg()
    local w     = cfg and cfg.iconWidth  or 40
    local h     = cfg and cfg.iconHeight or 40
    frame:SetSize(w, h)

    -- Icon 贴图（与 CDM 帧兼容）
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    frame.Icon = icon

    -- Cooldown 帧（CooldownFrameTemplate 提供冷却读秒 + 遮罩）
    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(frame)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    frame.Cooldown = cooldown

    frame.itemID = itemID
    frame:Hide()

    -- 更新图标贴图
    local data = GetItemData(itemID)
    if data and data.icon then
        icon:SetTexture(data.icon)
    else
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    return frame
end

local function RebuildIconFrames()
    local cfg = GetCfg()
    if not cfg then return end

    -- 释放不再监控的帧
    local newSet = {}
    for _, itemID in ipairs(cfg.items) do
        newSet[itemID] = true
    end
    for itemID, frame in pairs(iconFrames) do
        if not newSet[itemID] then
            frame:Hide()
            frame:SetParent(nil)
            iconFrames[itemID] = nil
        end
    end

    -- 创建新帧
    itemOrder = {}
    for _, itemID in ipairs(cfg.items) do
        itemOrder[#itemOrder + 1] = itemID
        if not iconFrames[itemID] then
            iconFrames[itemID] = CreateIconFrame(itemID)
        end
    end

    -- 应用样式
    for _, itemID in ipairs(itemOrder) do
        ApplyStyleToFrame(iconFrames[itemID])
    end
end

------------------------------------------------------
-- 容器拖拽/锁定（参考 BuffGroups SetupContainerDrag）
------------------------------------------------------

local function SetupContainerDrag()
    if not container then return end

    container:SetMovable(true)
    container:SetClampedToScreen(true)
    container:RegisterForDrag("LeftButton")
    container:EnableMouseWheel(true)

    -- 坐标显示标签
    if not container._imPosLabel then
        local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOP", container, "BOTTOM", 0, -4)
        lbl:SetTextColor(1, 0.82, 0, 1)
        lbl:Hide()
        container._imPosLabel = lbl
    end

    -- 提示文字
    if not container._imHintText then
        local txt = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("BOTTOM", container, "TOP", 0, 6)
        txt:SetText(ns.L and ns.L.imNudgeHint or "Drag or scroll | Shift=H | Ctrl=10px")
        txt:SetTextColor(0.8, 0.8, 0.8, 1)
        txt:Hide()
        container._imHintText = txt
    end

    container:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        if IsLocked() then return end
        self:StartMoving()
        self:SetScript("OnUpdate", function(s)
            local cx, cy = s:GetCenter()
            local sx, sy = UIParent:GetCenter()
            if cx and cy and sx and sy then
                local px = RoundToPixel(cx - sx)
                local py = RoundToPixel(cy - sy)
                if s._imPosLabel then
                    s._imPosLabel:SetFormattedText("X: %.0f  Y: %.0f", px, py)
                end
            end
        end)
    end)

    container:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetScript("OnUpdate", nil)
        local cfg = GetCfg()
        if not cfg then return end
        local cx, cy = self:GetCenter()
        local sx, sy = UIParent:GetCenter()
        if cx and sx then
            cfg.posX = RoundToPixel(cx - sx)
            cfg.posY = RoundToPixel(cy - sy)
        end
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", cfg.posX, cfg.posY)
        if self._imPosLabel then
            self._imPosLabel:SetFormattedText("X: %.0f  Y: %.0f", cfg.posX, cfg.posY)
        end
    end)

    container:SetScript("OnMouseWheel", function(self, delta)
        if InCombatLockdown() then return end
        if IsLocked() then return end
        local cfg = GetCfg()
        if not cfg then return end
        local step = IsControlKeyDown() and 10 or 1
        if IsShiftKeyDown() then
            cfg.posX = (cfg.posX or 0) + delta * step
        else
            cfg.posY = (cfg.posY or 0) + delta * step
        end
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", cfg.posX, cfg.posY)
        if self._imPosLabel then
            self._imPosLabel:SetFormattedText("X: %.0f  Y: %.0f", cfg.posX, cfg.posY)
        end
    end)

    container:SetScript("OnEnter", function(self)
        if not IsLocked() then
            if self._imHintText  then self._imHintText:Show() end
            if self._imPosLabel  then
                local cfg = GetCfg()
                if cfg then
                    self._imPosLabel:SetFormattedText("X: %.0f  Y: %.0f",
                        cfg.posX or 0, cfg.posY or 0)
                end
                self._imPosLabel:Show()
            end
        end
    end)

    container:SetScript("OnLeave", function(self)
        if self._imHintText then self._imHintText:Hide() end
        if self._imPosLabel then self._imPosLabel:Hide() end
    end)
end

local function ApplyLockToContainer()
    if not container then return end
    local locked = IsLocked()
    container:EnableMouse(not locked)
    container:EnableMouseWheel(not locked)
end

------------------------------------------------------
-- 公开接口
------------------------------------------------------

-- 初始化/重建：创建容器 + 图标帧 + 布局 + 样式
function IM:Init()
    local cfg = GetCfg()
    if not cfg then return end

    -- 创建容器帧
    if not container then
        container = CreateFrame("Frame", "CDFlow_ItemMonitorContainer", UIParent)
        container:SetFrameStrata("MEDIUM")
        container:SetFrameLevel(10)
        SetupContainerDrag()
    end

    -- 定位
    container:ClearAllPoints()
    container:SetPoint("CENTER", UIParent, "CENTER", cfg.posX or 0, cfg.posY or -340)

    ApplyLockToContainer()
    RebuildIconFrames()
    LayoutIcons()
    self:UpdateAllCooldowns()
end

-- 刷新所有物品冷却
function IM:UpdateAllCooldowns()
    for _, itemID in ipairs(itemOrder) do
        local frame = iconFrames[itemID]
        if frame then UpdateItemCooldown(frame) end
    end
end

-- 更新锁定状态
function IM:SetLocked(locked)
    local cfg = GetCfg()
    if cfg then cfg.locked = locked end
    ApplyLockToContainer()
end

-- 添加物品（UI 调用后需调用 Init）
function IM:AddItem(itemID)
    local cfg = GetCfg()
    if not cfg then return end
    -- 去重
    for _, id in ipairs(cfg.items) do
        if id == itemID then return end
    end
    cfg.items[#cfg.items + 1] = itemID
    self:Init()
end

-- 移除物品（UI 调用后需调用 Init）
function IM:RemoveItem(itemID)
    local cfg = GetCfg()
    if not cfg then return end
    for i, id in ipairs(cfg.items) do
        if id == itemID then
            table.remove(cfg.items, i)
            break
        end
    end
    self:Init()
end

-- 异步物品数据到达后刷新图标贴图
function IM:RefreshItemNames()
    for _, itemID in ipairs(itemOrder) do
        local frame = iconFrames[itemID]
        if frame and frame.Icon then
            local data = GetItemData(itemID)
            if data and data.icon then
                frame.Icon:SetTexture(data.icon)
            end
        end
    end
end

-- 配置变更后重新布局 + 样式（无需重建帧）
function IM:Refresh()
    if not container then self:Init(); return end
    local cfg = GetCfg()
    if not cfg then return end
    for _, itemID in ipairs(itemOrder) do
        local frame = iconFrames[itemID]
        if frame then ApplyStyleToFrame(frame) end
    end
    LayoutIcons()
end

-- 仅刷新物品数量（背包变化时调用）；会重排布局以便隐藏的图标不占位
function IM:RefreshItemCounts()
    for _, itemID in ipairs(itemOrder) do
        local frame = iconFrames[itemID]
        if frame then UpdateItemCount(frame) end
    end
    LayoutIcons()
end
