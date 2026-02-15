local _, ns = ...

------------------------------------------------------
-- 布局模块
--
-- 技能查看器（Essential/Utility）：多行布局 + 行居中
-- 增益查看器（Buffs）：单行/列 + 固定槽位或动态居中
--
-- growDir:
--   "CENTER"  → 居中（默认）
--   "DEFAULT" → 保持游戏默认对齐
------------------------------------------------------

local Layout = {}
ns.Layout = Layout

local Style = ns.Style
local floor = math.floor

local VIEWER_KEY = {
    EssentialCooldownViewer = "essential",
    UtilityCooldownViewer   = "utility",
    BuffIconCooldownViewer  = "buffs",
}

local restoringViewer = {}

------------------------------------------------------
-- 工具函数
------------------------------------------------------

local function IsReady(viewer)
    if not viewer or not viewer.IsInitialized then return false end
    if not EditModeManagerFrame then return false end
    if EditModeManagerFrame.layoutApplyInProgress then return false end
    return viewer:IsInitialized()
end

-- 收集所有图标子帧（含隐藏），按 layoutIndex 排序
local function CollectAllIcons(viewer)
    local all = {}
    local children = { viewer:GetChildren() }
    for _, child in ipairs(children) do
        if child and child.Icon then
            all[#all + 1] = child
        end
    end
    table.sort(all, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    return all
end

-- 从全量列表中筛选可见图标，同时记录每个图标的固定槽位索引
local function SplitVisible(allIcons)
    local visible = {}
    local slotOf = {}
    for slot, icon in ipairs(allIcons) do
        if icon:IsShown() then
            visible[#visible + 1] = icon
            slotOf[icon] = slot - 1   -- 0-based 槽位
        end
    end
    return visible, slotOf
end

-- 按每行上限分组
local function BuildRows(limit, children)
    local rows = {}
    if limit <= 0 then
        rows[1] = children
        return rows
    end
    for i = 1, #children do
        local ri = floor((i - 1) / limit) + 1
        rows[ri] = rows[ri] or {}
        rows[ri][#rows[ri] + 1] = children[i]
    end
    return rows
end

local function SetPointCached(icon, anchor, viewer, x, y)
    local num = icon:GetNumPoints()
    if num == 1 then
        local p, relTo, relPoint, curX, curY = icon:GetPoint(1)
        if p == anchor and relTo == viewer and relPoint == anchor
            and curX == x and curY == y then
            return
        end
    end
    icon:ClearAllPoints()
    icon:SetPoint(anchor, viewer, anchor, x, y)
end

local function CollectTrackedBars(viewer)
    if not viewer then return {} end
    local frames = {}

    if viewer.GetItemFrames then
        local ok, items = pcall(viewer.GetItemFrames, viewer)
        if ok and type(items) == "table" then
            frames = items
        end
    end

    if #frames == 0 then
        local children = { viewer:GetChildren() }
        for _, child in ipairs(children) do
            if child and child:IsObjectType("Frame") then
                frames[#frames + 1] = child
            end
        end
    end

    local active = {}
    for _, frame in ipairs(frames) do
        if frame:IsShown() and frame:IsVisible() then
            active[#active + 1] = frame
        end
    end

    table.sort(active, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    return active
end

------------------------------------------------------
-- 入口：根据查看器类型分发
------------------------------------------------------
function Layout:RefreshViewer(viewerName)
    if restoringViewer[viewerName] then return end
    local viewer = _G[viewerName]
    if not viewer or not IsReady(viewer) then return end

    local cfgKey = VIEWER_KEY[viewerName]
    if not cfgKey then return end
    local cfg = ns.db[cfgKey]
    if not cfg then return end
    viewer._cdf_disabledApplied = nil

    if viewerName == "BuffIconCooldownViewer" then
        self:RefreshBuffViewer(viewer, cfg)
        self:RefreshTrackedBars()
    else
        self:RefreshCDViewer(viewer, cfg)
    end
end

------------------------------------------------------
-- 增益图标查看器
-- DEFAULT = 固定槽位（按 layoutIndex，有 buff 显示在对应位置）
-- CENTER  = 动态居中（仅可见 buff 紧凑排列并居中）
------------------------------------------------------
function Layout:RefreshBuffViewer(viewer, cfg)
    local db = ns.db
    local w, h = cfg.iconWidth, cfg.iconHeight
    local ov = cfg.rowOverrides[1]
    if ov then w, h = ov.width or w, ov.height or h end

    local isH = (viewer.isHorizontal ~= false)
    local iconDir = (viewer.iconDirection == 1) and 1 or -1
    local doCenter = (cfg.growDir == "CENTER")

    local allIcons = CollectAllIcons(viewer)
    local visible, slotOf = SplitVisible(allIcons)
    if #visible == 0 then
        for _, icon in ipairs(allIcons) do
            if icon._cdf_buffGlowActive then
                Style:HideBuffGlow(icon)
            end
        end
        return
    end

    local total = #allIcons
    local buffGlowCfg = db.buffGlow

    -- 构建可见集合，用于快速查找
    local visibleSet = {}
    for _, icon in ipairs(visible) do
        visibleSet[icon] = true
    end

    -- 增益高亮：仅在状态变化时更新，避免频繁 Stop/Start 导致闪烁
    if buffGlowCfg then
        for _, icon in ipairs(allIcons) do
            local shouldGlow = visibleSet[icon] and buffGlowCfg.enabled
            local hasGlow = icon._cdf_buffGlowActive
            local styleMatch = hasGlow and icon._cdf_buffGlowType == buffGlowCfg.style

            if not shouldGlow then
                if hasGlow then Style:HideBuffGlow(icon) end
            elseif not hasGlow or not styleMatch then
                if hasGlow then Style:StopBuffGlow(icon) end
                Style:ShowBuffGlow(icon)
            end
        end
    end

    -- 应用样式
    for _, icon in ipairs(visible) do
        Style:ApplyIcon(icon, w, h, db.iconZoom, db.borderSize)
        Style:ApplyStack(icon, cfg.stack)
        Style:ApplyKeybind(icon, cfg)
        Style:ApplyCooldownText(icon, cfg)
    end

    -- 定位
    local limit = cfg.iconsPerRow or 0
    if limit > 0 then
        if isH then
            self:LayoutBuffWrappedH(viewer, visible, w, h, cfg, iconDir, doCenter, limit)
        else
            self:LayoutBuffWrappedV(viewer, visible, w, h, cfg, iconDir, doCenter, limit)
        end
    else
        if isH then
            self:LayoutBuffH(viewer, visible, slotOf, total, w, h, cfg, iconDir, doCenter)
        else
            self:LayoutBuffV(viewer, visible, slotOf, total, w, h, cfg, iconDir, doCenter)
        end
    end
end

-- Buff 水平布局
function Layout:LayoutBuffH(viewer, visible, slotOf, total, w, h, cfg, iconDir, doCenter)
    local anchor = "TOP" .. ((iconDir == 1) and "LEFT" or "RIGHT")

    if doCenter then
        -- 动态居中：可见 buff 紧凑排列，整体居中于总槽位宽度
        local missing = total - #visible
        local startX = ((w + cfg.spacingX) * missing / 2) * iconDir
        for i, icon in ipairs(visible) do
            local x = startX + (i - 1) * (w + cfg.spacingX) * iconDir
            SetPointCached(icon, anchor, viewer, x, 0)
        end
    else
        for _, icon in ipairs(visible) do
            local x = slotOf[icon] * (w + cfg.spacingX) * iconDir
            SetPointCached(icon, anchor, viewer, x, 0)
        end
    end
end

-- Buff 垂直布局（方向取反，与 CMC 一致）
function Layout:LayoutBuffV(viewer, visible, slotOf, total, w, h, cfg, iconDir, doCenter)
    local vertDir = -iconDir   -- 垂直方向取反
    local anchor = (iconDir == 1) and "BOTTOMLEFT" or "TOPLEFT"

    if doCenter then
        local missing = total - #visible
        local startY = -((h + cfg.spacingY) * missing / 2) * vertDir
        for i, icon in ipairs(visible) do
            local y = startY - (i - 1) * (h + cfg.spacingY) * vertDir
            SetPointCached(icon, anchor, viewer, 0, y)
        end
    else
        for _, icon in ipairs(visible) do
            local y = -(slotOf[icon]) * (h + cfg.spacingY) * vertDir
            SetPointCached(icon, anchor, viewer, 0, y)
        end
    end
end

-- Buff 水平换行布局（iconsPerRow > 0）
function Layout:LayoutBuffWrappedH(viewer, visible, w, h, cfg, iconDir, doCenter, limit)
    local anchor = "TOP" .. ((iconDir == 1) and "LEFT" or "RIGHT")
    local rows = BuildRows(limit, visible)
    local refTotalW = limit * (w + cfg.spacingX) - cfg.spacingX

    local yAccum = 0
    for _, row in ipairs(rows) do
        local count = #row
        local rowContentW = count * (w + cfg.spacingX) - cfg.spacingX
        local startX = 0
        if doCenter and rowContentW < refTotalW then
            startX = ((refTotalW - rowContentW) / 2) * iconDir
        end

        for i, icon in ipairs(row) do
            local x = startX + (i - 1) * (w + cfg.spacingX) * iconDir
            SetPointCached(icon, anchor, viewer, x, -yAccum)
        end

        yAccum = yAccum + h + cfg.spacingY
    end
end

-- Buff 垂直换行布局（iconsPerRow > 0）
function Layout:LayoutBuffWrappedV(viewer, visible, w, h, cfg, iconDir, doCenter, limit)
    local vertDir = -iconDir
    local anchor = (iconDir == 1) and "BOTTOMLEFT" or "TOPLEFT"
    local cols = BuildRows(limit, visible)
    local refTotalH = limit * (h + cfg.spacingY) - cfg.spacingY

    local xAccum = 0
    for _, col in ipairs(cols) do
        local count = #col
        local colContentH = count * (h + cfg.spacingY) - cfg.spacingY
        local startY = 0
        if doCenter and colContentH < refTotalH then
            startY = -((refTotalH - colContentH) / 2) * vertDir
        end

        for i, icon in ipairs(col) do
            local y = startY - (i - 1) * (h + cfg.spacingY) * vertDir
            SetPointCached(icon, anchor, viewer, xAccum, y)
        end

        xAccum = xAccum + w + cfg.spacingX
    end
end

------------------------------------------------------
-- 技能查看器（Essential / Utility）
-- 多行布局 + 行尺寸覆盖
------------------------------------------------------
function Layout:RefreshCDViewer(viewer, cfg)
    local allIcons = CollectAllIcons(viewer)
    local visible, _ = SplitVisible(allIcons)
    if #visible == 0 then return end

    local db = ns.db
    local isH = (viewer.isHorizontal ~= false)
    local iconDir = (viewer.iconDirection == 1) and 1 or -1

    local limit = cfg.iconsPerRow
    if not limit or limit <= 0 then
        limit = viewer.iconLimit or #allIcons
        if limit <= 0 then limit = #visible end
    end

    local rows = BuildRows(limit, visible)
    if #rows == 0 then return end

    -- 行尺寸（支持覆盖）
    local rowInfos = {}
    for ri = 1, #rows do
        local ov = cfg.rowOverrides[ri]
        rowInfos[ri] = {
            w = (ov and ov.width)  or cfg.iconWidth,
            h = (ov and ov.height) or cfg.iconHeight,
        }
    end

    -- 应用样式
    for ri, row in ipairs(rows) do
        local info = rowInfos[ri]
        for _, icon in ipairs(row) do
            Style:ApplyIcon(icon, info.w, info.h, db.iconZoom, db.borderSize)
            Style:ApplyStack(icon, cfg.stack)
            Style:ApplyKeybind(icon, cfg)
            Style:ApplyCooldownText(icon, cfg)
        end
    end

    local doCenter = (cfg.growDir == "CENTER")

    if isH then
        self:LayoutCDH(viewer, rows, rowInfos, cfg, iconDir, limit, doCenter)
    else
        self:LayoutCDV(viewer, rows, rowInfos, cfg, iconDir, limit, doCenter)
    end
end

-- 技能水平布局：行内左右排列，行间上下堆叠
function Layout:LayoutCDH(viewer, rows, rowInfos, cfg, iconDir, limit, doCenter)
    local anchor = "TOP" .. ((iconDir == 1) and "LEFT" or "RIGHT")

    -- 参考宽度：第一行满行时的总宽度
    local refW = rowInfos[1].w
    local refTotalW = limit * (refW + cfg.spacingX) - cfg.spacingX

    local yAccum = 0
    for ri, row in ipairs(rows) do
        local w, h = rowInfos[ri].w, rowInfos[ri].h
        local count = #row
        local rowContentW = count * (w + cfg.spacingX) - cfg.spacingX

        -- 居中偏移：以第一行总宽度为基准
        local startX = 0
        if doCenter and rowContentW < refTotalW then
            startX = ((refTotalW - rowContentW) / 2) * iconDir
        end

        for i, icon in ipairs(row) do
            local x = startX + (i - 1) * (w + cfg.spacingX) * iconDir
            SetPointCached(icon, anchor, viewer, x, -yAccum)
        end

        yAccum = yAccum + h + cfg.spacingY
    end
end

-- 技能垂直布局：列内上下排列，列间左右堆叠
function Layout:LayoutCDV(viewer, rows, rowInfos, cfg, iconDir, limit, doCenter)
    local vertDir = -iconDir
    local anchor = (iconDir == 1) and "BOTTOMLEFT" or "TOPLEFT"

    -- 参考高度：第一列满列时的总高度
    local refH = rowInfos[1].h
    local refTotalH = limit * (refH + cfg.spacingY) - cfg.spacingY

    local xAccum = 0
    for ri, row in ipairs(rows) do
        local w, h = rowInfos[ri].w, rowInfos[ri].h
        local count = #row
        local colContentH = count * (h + cfg.spacingY) - cfg.spacingY

        -- 居中偏移：以第一列总高度为基准
        local startY = 0
        if doCenter and colContentH < refTotalH then
            startY = -((refTotalH - colContentH) / 2) * vertDir
        end

        for i, icon in ipairs(row) do
            local y = startY - (i - 1) * (h + cfg.spacingY) * vertDir
            SetPointCached(icon, anchor, viewer, xAccum, y)
        end

        xAccum = xAccum + w + cfg.spacingX
    end
end

------------------------------------------------------
-- 刷新全部布局
------------------------------------------------------
function Layout:RefreshAll()
    if not ns.db then return end
    self:RefreshViewer("EssentialCooldownViewer")
    self:RefreshViewer("UtilityCooldownViewer")
    self:RefreshViewer("BuffIconCooldownViewer")
end

------------------------------------------------------
-- 追踪状态栏（Tracked Bars）布局
------------------------------------------------------
function Layout:RefreshTrackedBars()
    local viewer = _G.BuffBarCooldownViewer
    if not viewer then return end
    if EditModeManagerFrame and EditModeManagerFrame.layoutApplyInProgress then return end
    if viewer.IsInitialized and not viewer:IsInitialized() then return end

    local bars = CollectTrackedBars(viewer)
    if #bars == 0 then return end

    local barHeight = bars[1] and bars[1]:GetHeight()
    if not barHeight or barHeight <= 0 then return end

    local spacing = viewer.childYPadding or 0
    local growFromBottom = (ns.db.trackedBarsGrowDir ~= "TOP")

    for index, bar in ipairs(bars) do
        local offset = index - 1
        local y = growFromBottom and (offset * (barHeight + spacing)) or (-offset * (barHeight + spacing))
        if growFromBottom then
            SetPointCached(bar, "BOTTOM", viewer, 0, y)
        else
            SetPointCached(bar, "TOP", viewer, 0, y)
        end
    end
end
