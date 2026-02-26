-- 追踪状态栏（Tracked Bars）布局与样式模块
-- 美化官方 BuffBarCooldownViewer 中的追踪状态栏外观
local _, ns = ...

local Layout = ns.Layout
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- 借用 Layout.lua 暴露的缓存锚点工具函数
local SetPointCached = Layout._SetPointCached

------------------------------------------------------
-- 同步 viewer 尺寸与追踪条，并按生长方向设置锚点
-- 关键：viewer 的锚点决定 SetSize 时从哪一侧扩展
--   TOP    → 锚定 TOP，向下生长
--   BOTTOM → 锚定 BOTTOM，向上生长
--   CENTER → 锚定 CENTER，向两侧扩展
------------------------------------------------------
local function _vertOffset(p)
    if p == "TOP" or p == "TOPLEFT" or p == "TOPRIGHT" then return 1 end
    if p == "BOTTOM" or p == "BOTTOMLEFT" or p == "BOTTOMRIGHT" then return -1 end
    return 0
end

local function UpdateViewerSizeToMatchTrackedBars(viewer, bars, growDir)
    if not viewer or not bars or #bars == 0 then return end
    local vScale = viewer:GetEffectiveScale()
    if not vScale or vScale == 0 then return end

    local left, right, top, bottom = 999999, 0, 0, 999999
    for _, bar in ipairs(bars) do
        if bar and bar:IsShown() then
            local scale = bar:GetEffectiveScale() / vScale
            local l = (bar:GetLeft() or 0) * scale
            local r = (bar:GetRight() or 0) * scale
            local t = (bar:GetTop() or 0) * scale
            local b = (bar:GetBottom() or 0) * scale
            if l < left then left = l end
            if r > right then right = r end
            if t > top then top = t end
            if b < bottom then bottom = b end
        end
    end

    if left >= right or bottom >= top then return end

    local targetW = right - left
    local targetH = top - bottom

    local anchorPoint = (growDir == "TOP") and "TOP" or (growDir == "BOTTOM") and "BOTTOM" or "CENTER"

    local numPoints = viewer:GetNumPoints()
    local relTo = viewer:GetParent() or UIParent
    local relPoint = "CENTER"
    local xOfs, yOfs = 0, 0
    local curAnchor = "CENTER"
    if numPoints > 0 then
        local point, rel, rp, x, y = viewer:GetPoint(1)
        curAnchor = point or "CENTER"
        if rel then relTo = rel end
        if rp then relPoint = rp end
        xOfs = x or 0
        yOfs = y or 0
    end

    -- 当锚点需要变化时始终纠正，使用 targetH 确保坐标转换准确
    -- 保留 Edit Mode 的 relTo/relPoint，仅调整 viewer 自身的锚点与 y 偏移
    if curAnchor ~= anchorPoint then
        local oldV = _vertOffset(curAnchor)
        local newV = _vertOffset(anchorPoint)
        yOfs = yOfs + (newV - oldV) * targetH / 2
        viewer:ClearAllPoints()
        viewer:SetPoint(anchorPoint, relTo, relPoint, xOfs, yOfs)
    end

    -- 尺寸发生变化时才调用 SetSize
    local curW = viewer:GetWidth()
    local curH = viewer:GetHeight()
    if curW and curH and (math.abs(curW - targetW) >= 1 or math.abs(curH - targetH) >= 1) then
        viewer:SetSize(targetW, targetH)
    end
end

-- 获取追踪条的唯一标识（用于激活顺序）
local function GetTrackedBarId(bar)
    if bar.cooldownID then return bar.cooldownID end
    if bar.cooldownInfo and bar.cooldownInfo.cooldownID then
        return bar.cooldownInfo.cooldownID
    end
    return bar.layoutIndex or bar:GetName() or tostring(bar)
end

-- 追踪条激活顺序（会话内持久，先出现者在前）
local _trackedBarsActivationOrder = {}

local function CollectTrackedBars(viewer, sortByActivation)
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

    if sortByActivation then
        -- 按先来后到：新出现的条追加到末尾
        local idToBar = {}
        for _, bar in ipairs(active) do
            idToBar[GetTrackedBarId(bar)] = bar
        end

        local newOrder = {}
        local added = {}
        for _, id in ipairs(_trackedBarsActivationOrder) do
            if idToBar[id] then
                newOrder[#newOrder + 1] = id
                added[id] = true
            end
        end
        for _, bar in ipairs(active) do
            local id = GetTrackedBarId(bar)
            if not added[id] then
                newOrder[#newOrder + 1] = id
                added[id] = true
            end
        end
        _trackedBarsActivationOrder = newOrder

        local orderIdx = {}
        for i, id in ipairs(newOrder) do
            orderIdx[id] = i
        end
        table.sort(active, function(a, b)
            return (orderIdx[GetTrackedBarId(a)] or 999) < (orderIdx[GetTrackedBarId(b)] or 999)
        end)
    else
        table.sort(active, function(a, b)
            return (a.layoutIndex or 0) < (b.layoutIndex or 0)
        end)
    end
    return active
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
--
-- 生长方向 growDir（与 Buff 配置类似）：
--   TOP    → 第一个条在区域顶部，新条在其下方追加
--   CENTER → 第一个条在区域中间；新条出现时整组始终居中
--   BOTTOM → 第一个条在区域底部，新条在其上方追加
------------------------------------------------------
function Layout:RefreshTrackedBars()
    if not (ns.db and ns.db.modules and ns.db.modules.trackedBars) then return end

    local viewer = _G.BuffBarCooldownViewer
    if not viewer then return end
    if EditModeManagerFrame and EditModeManagerFrame.layoutApplyInProgress then return end
    if viewer.IsInitialized and not viewer:IsInitialized() then return end

    local bars = CollectTrackedBars(viewer, true)  -- true = 按先来后到排序
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

    -- 间距：优先使用配置，覆盖系统 viewer.childYPadding
    local spacing = (cfg.spacing ~= nil) and cfg.spacing or (viewer.childYPadding or 0)
    local growDir = cfg.growDir or "CENTER"
    local step = barHeight + spacing
    local n = #bars

    for index, bar in ipairs(bars) do
        local i = index - 1  -- 0-based
        local y
        local anchor

        if growDir == "TOP" then
            -- 从上到下：第一个在顶部，后续在其下方追加
            anchor = "TOP"
            y = -i * step
        elseif growDir == "BOTTOM" then
            -- 从下到上：第一个在底部，后续在其上方追加
            anchor = "BOTTOM"
            y = i * step
        else
            -- 居中：整组始终居中于区域
            -- 第一个条在组顶部，最后一个在组底部，组中心对齐 viewer 中心
            anchor = "CENTER"
            y = (n - 1) * step / 2 - i * step
        end

        SetPointCached(bar, anchor, viewer, 0, y)
    end

    -- 同步 viewer 尺寸与条边界，并按生长方向设置锚点（使扩展从正确方向发生）
    UpdateViewerSizeToMatchTrackedBars(viewer, bars, growDir)
end
