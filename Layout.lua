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
-- 跳过被监控条隐藏（hideFromCDM）的图标，并将其 alpha 置 0
local function SplitVisible(allIcons)
    local visible = {}
    local slotOf = {}
    local suppressed = ns.cdmSuppressedCooldownIDs
    for slot, icon in ipairs(allIcons) do
        if icon:IsShown() then
            if suppressed and suppressed[icon.cooldownID] then
                icon:SetAlpha(0)
            else
                icon:SetAlpha(1)
                visible[#visible + 1] = icon
                slotOf[icon] = slot - 1   -- 0-based 槽位
            end
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

    -- 应用样式
    for _, icon in ipairs(visible) do
        icon._cdf_viewerKey = "buffs"
        Style:ApplyIcon(icon, w, h, db.iconZoom, db.borderSize)
        Style:ApplyStack(icon, cfg.stack)
        Style:ApplyKeybind(icon, cfg)
        Style:ApplyCooldownText(icon, cfg)
        Style:ApplySwipeOverlay(icon)
    end

    -- 定位
    if isH then
        self:LayoutBuffH(viewer, visible, slotOf, total, w, h, cfg, iconDir, doCenter)
    else
        self:LayoutBuffV(viewer, visible, slotOf, total, w, h, cfg, iconDir, doCenter)
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
end

------------------------------------------------------
-- 技能水平布局
-- growDir "TOP"    → anchor=TOPLEFT,  行从上往下叠（yOffset 递减）
-- growDir "BOTTOM" → anchor=BOTTOMLEFT, 行从下往上叠（yOffset 递增）
-- 行内水平：始终以满行宽度为基准居中
------------------------------------------------------
function Layout:LayoutCDH(viewer, rows, rowInfos, cfg, iconDir, limit, growDir)
    local fromBottom = (growDir == "BOTTOM")
    local rowOffsetMod = fromBottom and 1 or -1
    local rowAnchor = (fromBottom and "BOTTOM" or "TOP") .. ((iconDir == 1) and "LEFT" or "RIGHT")

    -- 参考宽度：第一行满行时的总宽度
    local refW = rowInfos[1].w
    local refTotalW = limit * (refW + cfg.spacingX) - cfg.spacingX

    local yAccum = 0
    for ri, row in ipairs(rows) do
        local w, h = rowInfos[ri].w, rowInfos[ri].h
        local count = #row
        local rowContentW = count * (w + cfg.spacingX) - cfg.spacingX

        -- 行内始终水平居中（以满行宽度为基准）
        local startX = ((refTotalW - rowContentW) / 2) * iconDir

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
    -- 垂直布局中，"BOTTOM"意味着列从右向左增长
    local colOffsetMod = fromBottom and -1 or 1
    local iconVertDir = -iconDir

    -- anchor 的垂直分量由 iconDir 决定（和原逻辑一致）
    -- 水平分量由 growDir 决定
    local vertPart = (iconDir == 1) and "BOTTOM" or "TOP"
    local horizPart = fromBottom and "RIGHT" or "LEFT"
    local colAnchor = vertPart .. horizPart

    -- 参考高度：第一列满列时的总高度
    local refH = rowInfos[1].h
    local refTotalH = limit * (refH + cfg.spacingY) - cfg.spacingY

    local xAccum = 0
    for ri, row in ipairs(rows) do
        local w, h = rowInfos[ri].w, rowInfos[ri].h
        local count = #row
        local colContentH = count * (h + cfg.spacingY) - cfg.spacingY

        -- 列内始终垂直居中（以满列高度为基准）
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

------------------------------------------------------
-- 追踪状态栏（Tracked Bars）样式应用
------------------------------------------------------

local _trackedBarHooked = {}

local function ResolveFontPath(fontName)
    if LSM and fontName and fontName ~= "" and fontName ~= "默认" then
        local path = LSM:Fetch("font", fontName)
        if path then return path end
    end
    return ns.ResolveFontPath and ns.ResolveFontPath(fontName) or GameFontNormal:GetFont()
end

local function ResolveOutline(outline)
    if outline == "NONE" then return "" end
    return outline or "OUTLINE"
end

local function ApplyTrackedBarStyle(frame, cfg)
    if not frame then return end

    local bar = frame.Bar
    local iconFrame = frame.Icon

    -- 确保 fd 表存在
    local fd = _trackedBarHooked[frame]
    if not fd then
        fd = {}
        _trackedBarHooked[frame] = fd
    end

    -- 屏蔽 DebuffBorder 红框（DebuffBorder 直接挂在 frame 上）
    if frame.DebuffBorder then
        local suppress = ns.db and ns.db.suppressDebuffBorder
        local targetAlpha = suppress and 0 or 1
        if frame.DebuffBorder:GetAlpha() ~= targetAlpha then
            frame.DebuffBorder:SetAlpha(targetAlpha)
        end
        if not fd.debuffBorderHooked then
            fd.debuffBorderHooked = true
            hooksecurefunc(frame.DebuffBorder, "Show", function(self)
                if ns.db and ns.db.suppressDebuffBorder then
                    self:SetAlpha(0)
                end
            end)
            if frame.DebuffBorder.UpdateFromAuraData then
                hooksecurefunc(frame.DebuffBorder, "UpdateFromAuraData", function(self)
                    if ns.db and ns.db.suppressDebuffBorder then
                        self:SetAlpha(0)
                    end
                end)
            end
        end
    end

    -- 条纹理与颜色
    if bar then
        local barTexture = (LSM and LSM:Fetch("statusbar", cfg.barTexture))
            or "Interface\\TargetingFrame\\UI-StatusBar"

        bar:SetStatusBarTexture(barTexture)
        local bc = cfg.barColor
        bar:SetStatusBarColor(bc[1] or 0.4, bc[2] or 0.6, bc[3] or 0.9, bc[4] or 1.0)

        -- 背景
        if not fd.barBackground then
            fd.barBackground = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        end
        fd.barBackground:ClearAllPoints()
        fd.barBackground:SetAllPoints(bar)
        fd.barBackground:SetTexture(barTexture)
        local bg = cfg.bgColor
        fd.barBackground:SetVertexColor(bg[1] or 0.1, bg[2] or 0.1, bg[3] or 0.1, bg[4] or 0.8)

        -- 隐藏官方背景纹理
        if bar.BarBG then
            bar.BarBG:Hide()
            bar.BarBG:SetAlpha(0)
        end

        -- 名称文字
        local nameText = bar.Name
        if nameText then
            if cfg.showName then
                nameText:Show()
                nameText:SetAlpha(1)
                local fontPath = ResolveFontPath(cfg.nameFontName)
                nameText:SetFont(fontPath, cfg.nameFontSize or 12, ResolveOutline(cfg.nameOutline))
                local nc = cfg.nameColor
                nameText:SetTextColor(nc[1] or 1, nc[2] or 1, nc[3] or 1, nc[4] or 1)
                nameText:SetShadowOffset(0, 0)
            else
                nameText:Hide()
                nameText:SetAlpha(0)
            end

            -- 防止 Blizzard 重新显示时绕过我们的隐藏
            if not fd.nameHooked then
                fd.nameHooked = true
                hooksecurefunc(nameText, "Show", function(self)
                    if not cfg.showName then
                        self:Hide()
                        self:SetAlpha(0)
                    end
                end)
            end
        end

        -- 时长文字
        local durationText = bar.Duration
        if durationText then
            if cfg.showDuration then
                durationText:Show()
                durationText:SetAlpha(1)
                local fontPath = ResolveFontPath(cfg.durationFontName)
                durationText:SetFont(fontPath, cfg.durationFontSize or 12, ResolveOutline(cfg.durationOutline))
                local dc = cfg.durationColor
                durationText:SetTextColor(dc[1] or 1, dc[2] or 1, dc[3] or 1, dc[4] or 1)
                durationText:SetShadowOffset(0, 0)
            else
                durationText:Hide()
                durationText:SetAlpha(0)
            end

            if not fd.durationHooked then
                fd.durationHooked = true
                hooksecurefunc(durationText, "Show", function(self)
                    if not cfg.showDuration then
                        self:Hide()
                        self:SetAlpha(0)
                    end
                end)
            end
        end

        -- 调整条的锚点以适应图标位置
        local iconPos = cfg.iconPosition or "LEFT"
        if iconPos == "HIDDEN" then
            bar:ClearAllPoints()
            bar:SetPoint("LEFT", frame, "LEFT", 0, 0)
            bar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        elseif iconPos == "RIGHT" then
            bar:ClearAllPoints()
            bar:SetPoint("LEFT", frame, "LEFT", 0, 0)
            bar:SetPoint("RIGHT", iconFrame or frame, iconFrame and "LEFT" or "RIGHT", 0, 0)
        else -- LEFT（默认）
            bar:ClearAllPoints()
            bar:SetPoint("LEFT", iconFrame or frame, iconFrame and "RIGHT" or "LEFT", 0, 0)
            bar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        end
    end

    -- 图标位置
    if iconFrame then
        local iconPos = cfg.iconPosition or "LEFT"
        local barHeight = cfg.barHeight or 20
        if iconPos == "HIDDEN" then
            iconFrame:Hide()
        else
            iconFrame:Show()
            iconFrame:SetSize(barHeight, barHeight)
            iconFrame:ClearAllPoints()
            if iconPos == "RIGHT" then
                iconFrame:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            else
                iconFrame:SetPoint("LEFT", frame, "LEFT", 0, 0)
            end
        end

        -- 钩子：防止 Blizzard 重新显示图标
        if not fd.iconShowHooked then
            fd.iconShowHooked = true
            hooksecurefunc(iconFrame, "Show", function(self)
                if (cfg.iconPosition or "LEFT") == "HIDDEN" then
                    self:Hide()
                end
            end)
        end
    end

    -- 钩子：SetBarContent 后重新应用（防止官方刷新覆盖）
    if not fd.barContentHooked and frame.SetBarContent then
        fd.barContentHooked = true
        hooksecurefunc(frame, "SetBarContent", function()
            ApplyTrackedBarStyle(frame, cfg)
        end)
    end
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

    local cfg = (ns.db and ns.db.trackedBars) or ns.defaults.trackedBars

    -- 应用外观样式
    for _, bar in ipairs(bars) do
        ApplyTrackedBarStyle(bar, cfg)
    end

    local barHeight = (cfg.barHeight and cfg.barHeight > 0) and cfg.barHeight
        or (bars[1] and bars[1]:GetHeight())
        or 20
    if barHeight <= 0 then return end

    local spacing = viewer.childYPadding or 0
    local growFromBottom = (cfg.growDir ~= "TOP")

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
