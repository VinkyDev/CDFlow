-- 追踪状态栏（Tracked Bars）布局与样式模块
-- 美化官方 BuffBarCooldownViewer 中的追踪状态栏外观
local _, ns = ...

local Layout = ns.Layout
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- 借用 Layout.lua 暴露的缓存锚点工具函数
local SetPointCached = Layout._SetPointCached

------------------------------------------------------
-- 同步 viewer 高度（不触碰 viewer 位置/锚点）
-- 说明：编辑模式位置漂移的根因是运行期修改了 viewer:SetPoint。
-- 这里仅更新高度，避免任何坐标写回影响 Edit Mode 保存结果。
------------------------------------------------------
local function _syncViewerHeight(viewer, n, barHeight, spacing)
    if n <= 0 or barHeight <= 0 then return end
    local targetH = n * barHeight + math.max(0, n - 1) * spacing

    local curH = viewer:GetHeight()
    if not curH or math.abs(curH - targetH) >= 1 then
        viewer:SetSize(viewer:GetWidth(), targetH)
    end
end

local function _normalizeAnchor(anchor)
    if anchor == "TOP" or anchor == "BOTTOM" or anchor == "CENTER" then
        return anchor
    end
    return "CENTER"
end

local function EnsureTrackedBarsViewerPoint(viewer, cfg)
    if not viewer or not cfg then return end

    if not cfg.anchor then cfg.anchor = "CENTER" end
    if cfg.x == nil then cfg.x = 0 end
    if cfg.y == nil then cfg.y = 0 end

    local anchor = _normalizeAnchor(cfg.anchor)
    local x = cfg.x or 0
    local y = cfg.y or 0

    if viewer:GetNumPoints() == 1 then
        local p, relTo, relPoint, curX, curY = viewer:GetPoint(1)
        if p == anchor and relTo == UIParent and relPoint == anchor and curX == x and curY == y then
            return
        end
    end

    viewer:ClearAllPoints()
    viewer:SetPoint(anchor, UIParent, anchor, x, y)
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
-- 生长方向 growDir：
--   TOP    → bar[0] 固定，新条向下追加（第一个条不动）
--   BOTTOM → bar[0] 固定，新条向上追加（第一个条不动）
--   CENTER → 整组动态居中
--
-- 实现策略：所有 bar 均使用 CENTER 锚点，但 TOP/BOTTOM 采用“首条为原点”。
-- 这样既满足生长方向语义，又不依赖 viewer 自身锚点，不会触发位置漂移。
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
    EnsureTrackedBarsViewerPoint(viewer, cfg)

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
    -- 补丁策略：编辑模式与运行时使用同一 growDir。
    -- 这样可确保“编辑看到的位置”与“保存后实际位置”一致，避免退出编辑后跳变。
    local layoutGrowDir = growDir
    local step = barHeight + spacing
    local n = #bars

    for index, bar in ipairs(bars) do
        local i = index - 1  -- 0-based
        local y
        if layoutGrowDir == "TOP" then
            -- 以首条为原点：bar[0] 永远在 y=0，新条向下追加
            y = -i * step
        elseif layoutGrowDir == "BOTTOM" then
            -- 以首条为原点：bar[0] 永远在 y=0，新条向上追加
            y = i * step
        else
            -- CENTER：整组动态居中，n 变化时所有 bar 均匀重排
            y = (n - 1) * step / 2 - i * step
        end
        SetPointCached(bar, "CENTER", viewer, 0, y)
    end

    -- 仅同步高度，不修改 viewer 位置/锚点
    _syncViewerHeight(viewer, n, barHeight, spacing)
end

function Layout:GetTrackedBarsViewer()
    local viewer = _G.BuffBarCooldownViewer
    if not viewer then return nil end
    if viewer.IsInitialized and not viewer:IsInitialized() then return nil end
    return viewer
end

function Layout:GetTrackedBarsManagedPoint()
    local cfg = ns.db and ns.db.trackedBars
    if not cfg then return "CENTER", 0, 0 end
    return _normalizeAnchor(cfg.anchor), cfg.x or 0, cfg.y or 0
end

function Layout:SetTrackedBarsManagedPoint(anchor, x, y)
    if not (ns.db and ns.db.trackedBars) then return end
    local cfg = ns.db.trackedBars
    cfg.anchor = _normalizeAnchor(anchor)
    cfg.x = x or 0
    cfg.y = y or 0
end
