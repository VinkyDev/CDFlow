local _, ns = ...

------------------------------------------------------
-- 布局模块
--
-- 技能查看器（Essential/Utility）：多行布局 + 行内始终水平居中
-- growDir:
--   "TOP"    → 从顶部向下增长（默认）
--   "BOTTOM" → 从底部向上增长
--
-- 增益查看器（Buffs）：单行/列 + 固定槽位或动态居中
-- growDir:
--   "CENTER"  → 从中间增长（动态居中）
--   "DEFAULT" → 固定位置（系统默认）
------------------------------------------------------

local Layout = {}
ns.Layout = Layout

local Style = ns.Style
local floor = math.floor
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

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
-- 跳过被监控条隐藏（hideFromCDM）的图标：alpha 置 0、移出布局区
-- 有 suppressed 时使用紧凑槽位，避免占据空位
local function SplitVisible(allIcons)
    local visible = {}
    local slotOf = {}
    local suppressed = ns.cdmSuppressedCooldownIDs
    local hasSuppressed = false
    for slot, icon in ipairs(allIcons) do
        if icon:IsShown() then
            if suppressed and suppressed[icon.cooldownID] then
                hasSuppressed = true
                icon:SetAlpha(0)
                icon:ClearAllPoints()
                icon:SetPoint("CENTER", icon:GetParent(), "CENTER", -5000, 0)
            else
                icon:SetAlpha(1)
                visible[#visible + 1] = icon
                slotOf[icon] = slot - 1   -- 0-based 槽位
            end
        end
    end
    if hasSuppressed then
        for i, icon in ipairs(visible) do
            slotOf[icon] = i - 1
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
-- 供 Layout/TrackedBars.lua 使用
Layout._SetPointCached = SetPointCached

------------------------------------------------------
-- 同步 viewer 尺寸与实际图标边界框
-- 使编辑模式的圈选区域与实际显示区域一致
------------------------------------------------------
local function UpdateViewerSizeToMatchIcons(viewer, icons)
    if not viewer or not icons or #icons == 0 then return end
    local vScale = viewer:GetEffectiveScale()
    if not vScale or vScale == 0 then return end

    local left, right, top, bottom = 999999, 0, 0, 999999
    for _, icon in ipairs(icons) do
        if icon and icon:IsShown() then
            local scale = icon:GetEffectiveScale() / vScale
            local l = (icon:GetLeft() or 0) * scale
            local r = (icon:GetRight() or 0) * scale
            local t = (icon:GetTop() or 0) * scale
            local b = (icon:GetBottom() or 0) * scale
            if l < left then left = l end
            if r > right then right = r end
            if t > top then top = t end
            if b < bottom then bottom = b end
        end
    end

    if left >= right or bottom >= top then return end

    -- 已转换为 viewer 本地单位，直接使用（与 CMC 一致）
    local targetW = right - left
    local targetH = top - bottom
    local curW = viewer:GetWidth()
    local curH = viewer:GetHeight()
    if curW and curH and (math.abs(curW - targetW) >= 1 or math.abs(curH - targetH) >= 1) then
        viewer:SetSize(targetW, targetH)
    end
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
        if self.RefreshTrackedBars then self:RefreshTrackedBars() end
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
        -- 分组容器也可能有图标，但若全部不可见则无需处理
        return
    end

    -- 将 visible 拆分为主组和各自定义分组
    -- 使用 GetGroupIdxForIcon 进行多源技能ID匹配（含 base 归一化与帧级缓存）
    local hasGroups = self.GetGroupIdxForIcon ~= nil
        and ns.db and ns.db.buffGroups and #ns.db.buffGroups > 0
    local mainVisible = visible
    local groupBuckets = {}

    if hasGroups then
        mainVisible = {}
        for _, icon in ipairs(visible) do
            local gIdx = self:GetGroupIdxForIcon(icon)
            if gIdx then
                groupBuckets[gIdx] = groupBuckets[gIdx] or {}
                groupBuckets[gIdx][#groupBuckets[gIdx] + 1] = icon
            else
                mainVisible[#mainVisible + 1] = icon
            end
        end
    end

    local buffGlowCfg = db.buffGlow

    -- 构建可见集合（含分组图标），用于高亮判断
    local visibleSet = {}
    for _, icon in ipairs(visible) do
        visibleSet[icon] = true
    end

    -- 增益高亮：仅在状态变化时更新，避免频繁 Stop/Start 导致闪烁
    if buffGlowCfg then
        local hasFilter = buffGlowCfg.spellFilter and next(buffGlowCfg.spellFilter)
        for _, icon in ipairs(allIcons) do
            local shouldGlow = visibleSet[icon] and buffGlowCfg.enabled
            -- 技能ID过滤：有过滤列表时，仅对列表内的技能高亮
            if shouldGlow and hasFilter then
                local spellID = Style.GetSpellIDFromIcon(icon)
                shouldGlow = spellID and buffGlowCfg.spellFilter[spellID] or false
            end
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

    -- 应用样式（含分组图标）
    for _, icon in ipairs(visible) do
        icon._cdf_viewerKey = "buffs"
        Style:ApplyIcon(icon, w, h, db.iconZoom, db.borderSize)
        Style:ApplyStack(icon, cfg.stack)
        Style:ApplyKeybind(icon, cfg)
        Style:ApplyCooldownText(icon, cfg)
        Style:ApplySwipeOverlay(icon)
    end

    -- 主组定位（仅非分组图标）
    if #mainVisible > 0 then
        if isH then
            self:LayoutBuffH(viewer, mainVisible, slotOf, w, h, cfg, iconDir, doCenter)
        else
            self:LayoutBuffV(viewer, mainVisible, slotOf, w, h, cfg, iconDir, doCenter)
        end
    end

    -- 自定义分组定位
    if hasGroups then
        self:RefreshBuffGroups(groupBuckets, w, h, cfg)
    end

    -- 同步 viewer 尺寸与主组图标边界，使编辑模式圈选区域与实际显示一致
    UpdateViewerSizeToMatchIcons(viewer, mainVisible)
end

-- Buff 水平布局
-- CENTER 模式：以 viewer CENTER 为锚点动态居中，可见图标始终整体居中，
--             无需 total/missing，buff 出现/消失时整组平滑居中展开/收缩。
-- DEFAULT 模式：固定槽位，按 layoutIndex 排列。
function Layout:LayoutBuffH(viewer, visible, slotOf, w, h, cfg, iconDir, doCenter)
    if doCenter then
        local n = #visible
        local totalW = n * w + math.max(0, n - 1) * cfg.spacingX
        -- 以 viewer CENTER 为原点：第一个图标中心偏移量
        -- iconDir=1（左→右）：从 -(totalW-w)/2 开始向右排列
        -- iconDir=-1（右→左）：从 +(totalW-w)/2 开始向左排列
        local startX = -((totalW - w) / 2) * iconDir
        for i, icon in ipairs(visible) do
            local x = startX + (i - 1) * (w + cfg.spacingX) * iconDir
            SetPointCached(icon, "CENTER", viewer, x, 0)
        end
    else
        local anchor = "TOP" .. ((iconDir == 1) and "LEFT" or "RIGHT")
        for _, icon in ipairs(visible) do
            local x = slotOf[icon] * (w + cfg.spacingX) * iconDir
            SetPointCached(icon, anchor, viewer, x, 0)
        end
    end
end

-- Buff 垂直布局（方向取反，与 CMC 一致）
-- CENTER 模式：以 viewer CENTER 为锚点动态居中。
--   iconDir=1（上→下）：第一个图标中心在 +halfSpan（高），最后一个在 -halfSpan（低）
--   iconDir=-1（下→上）：反向排列
-- DEFAULT 模式：固定槽位。
function Layout:LayoutBuffV(viewer, visible, slotOf, w, h, cfg, iconDir, doCenter)
    if doCenter then
        local n = #visible
        local totalH = n * h + math.max(0, n - 1) * cfg.spacingY
        local halfSpan = (totalH - h) / 2
        for i, icon in ipairs(visible) do
            -- iconDir=1: 从上到下，y 由 +halfSpan 递减
            -- iconDir=-1: 从下到上，y 由 -halfSpan 递增
            local y = (halfSpan - (i - 1) * (h + cfg.spacingY)) * iconDir
            SetPointCached(icon, "CENTER", viewer, 0, y)
        end
    else
        local vertDir = -iconDir   -- 垂直方向取反，与 CMC 一致
        local anchor = (iconDir == 1) and "BOTTOMLEFT" or "TOPLEFT"
        for _, icon in ipairs(visible) do
            local y = -(slotOf[icon]) * (h + cfg.spacingY) * vertDir
            SetPointCached(icon, anchor, viewer, 0, y)
        end
    end
end

------------------------------------------------------
-- 技能查看器（Essential / Utility）
-- 多行布局 + 行尺寸覆盖 + 行内始终水平居中
-- growDir:
--   "TOP"    → 从顶部向下增长（anchor = TOPLEFT/TOPRIGHT）
--   "BOTTOM" → 从底部向上增长（anchor = BOTTOMLEFT/BOTTOMRIGHT）
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
    local viewerKey = VIEWER_KEY[viewer:GetName()]
    for ri, row in ipairs(rows) do
        local info = rowInfos[ri]
        for _, icon in ipairs(row) do
            icon._cdf_viewerKey = viewerKey
            Style:ApplyIcon(icon, info.w, info.h, db.iconZoom, db.borderSize)
            Style:ApplyStack(icon, cfg.stack)
            Style:ApplyKeybind(icon, cfg)
            Style:ApplyCooldownText(icon, cfg)
            Style:ApplySwipeOverlay(icon)
        end
    end

    local growDir = cfg.growDir or "TOP"

    if isH then
        self:LayoutCDH(viewer, rows, rowInfos, cfg, iconDir, limit, growDir)
    else
        self:LayoutCDV(viewer, rows, rowInfos, cfg, iconDir, limit, growDir)
    end

    -- 同步 viewer 尺寸与图标边界，使编辑模式圈选区域与实际显示一致
    UpdateViewerSizeToMatchIcons(viewer, visible)
end

------------------------------------------------------
-- 技能水平布局
-- growDir "TOP"    → anchor=TOPLEFT,  行从上往下叠（yOffset 递减）
-- growDir "BOTTOM" → anchor=BOTTOMLEFT, 行从下往上叠（yOffset 递增）
-- rowAnchor: LEFT/CENTER/RIGHT 行内水平锚点
------------------------------------------------------
function Layout:LayoutCDH(viewer, rows, rowInfos, cfg, iconDir, limit, growDir)
    local fromBottom = (growDir == "BOTTOM")
    local rowOffsetMod = fromBottom and 1 or -1
    local rowAnchor = (fromBottom and "BOTTOM" or "TOP") .. ((iconDir == 1) and "LEFT" or "RIGHT")

    -- 参考宽度：第一行满行时的总宽度
    local refW = rowInfos[1].w
    local refTotalW = limit * (refW + cfg.spacingX) - cfg.spacingX

    local anchorMode = (cfg.rowAnchor == "LEFT" or cfg.rowAnchor == "RIGHT") and cfg.rowAnchor or "CENTER"

    local yAccum = 0
    for ri, row in ipairs(rows) do
        local w, h = rowInfos[ri].w, rowInfos[ri].h
        local count = #row
        local rowContentW = count * (w + cfg.spacingX) - cfg.spacingX

        -- 行内水平锚点：左 / 中 / 右
        -- iconDir=1(TOPLEFT): 正x向右; iconDir=-1(TOPRIGHT): 正x向左
        local startX
        if anchorMode == "LEFT" then
            startX = (iconDir == 1) and 0 or ((refTotalW - rowContentW) / 2)
        elseif anchorMode == "RIGHT" then
            startX = (iconDir == 1) and (refTotalW - rowContentW) or 0
        else
            startX = ((refTotalW - rowContentW) / 2) * iconDir
        end

        local yOffset = yAccum * rowOffsetMod
        for i, icon in ipairs(row) do
            local x = startX + (i - 1) * (w + cfg.spacingX) * iconDir
            SetPointCached(icon, rowAnchor, viewer, x, yOffset)
        end

        yAccum = yAccum + h + cfg.spacingY
    end
end

------------------------------------------------------
-- 技能垂直布局
-- growDir "TOP"    → anchor=BOTTOMLEFT, 列从左往右叠（xOffset 递增）
-- growDir "BOTTOM" → anchor=BOTTOMRIGHT, 列从右往左叠（xOffset 递减）
-- 列内垂直：始终以满列高度为基准居中
------------------------------------------------------
function Layout:LayoutCDV(viewer, rows, rowInfos, cfg, iconDir, limit, growDir)
    local fromBottom = (growDir == "BOTTOM")
    local colOffsetMod = fromBottom and -1 or 1
    local iconVertDir = -iconDir

    local vertPart = (iconDir == 1) and "BOTTOM" or "TOP"
    local horizPart = fromBottom and "RIGHT" or "LEFT"
    local colAnchor = vertPart .. horizPart

    local refH = rowInfos[1].h
    local refTotalH = limit * (refH + cfg.spacingY) - cfg.spacingY

    local xAccum = 0
    for ri, row in ipairs(rows) do
        local w, h = rowInfos[ri].w, rowInfos[ri].h
        local count = #row
        local colContentH = count * (h + cfg.spacingY) - cfg.spacingY

        local startY = -((refTotalH - colContentH) / 2) * iconVertDir

        local xOffset = xAccum * colOffsetMod
        for i, icon in ipairs(row) do
            local y = startY - (i - 1) * (h + cfg.spacingY) * iconVertDir
            SetPointCached(icon, colAnchor, viewer, xOffset, y)
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

