local _, ns = ...

------------------------------------------------------
-- Buff CENTER 模式持续居中（OnUpdate 状态机）
--   1. OnUpdate 循环持续检测可见 buff 状态变化
--   2. 帧重新父级到 UIParent，viewer RefreshLayout 无法干扰
--   3. 以 viewer BOTTOM/LEFT 中点为锚点偏移，不依赖 viewer:GetWidth/Height()
--   4. 像素级精确计算，消除亚像素错位
--   5. 爆发（33ms）→ 看门狗（250ms）→ 空闲自关（2s）
------------------------------------------------------

local Layout = ns.Layout

------------------------------------------------------
-- 像素工具
------------------------------------------------------

local function GetPixelSize()
    local px = PixelUtil and PixelUtil.GetPixelToUIUnitFactor
        and PixelUtil.GetPixelToUIUnitFactor() or 1
    local scale = UIParent and UIParent:GetEffectiveScale() or 1
    if scale and scale > 0 then px = px / scale end
    return (px and px > 0) and px or 1
end

local function ToPx(v)
    return math.floor((v or 0) / GetPixelSize() + 0.5)
end

local function ToUI(px)
    return px * GetPixelSize()
end

------------------------------------------------------
-- 时序常量
------------------------------------------------------

local BURST_THROTTLE    = 0.033
local WATCHDOG_THROTTLE = 0.25
local BURST_TICKS       = 5
local IDLE_DISABLE      = 2.0

------------------------------------------------------
-- 模块级状态
------------------------------------------------------

local buffCenFrame     = CreateFrame("Frame")
local nextUpdate       = 0
local cenEnabled       = false
local cenDirty         = true
local cenBurstTicks    = 0
local cenLastActivity  = 0

local cenLastVisSet    = {}
local cenLastVisCount  = 0
local cenLastLayout    = setmetatable({}, { __mode = "k" })
local cenLastSuppressVer = -1

-- 记录我们已 re-parent 到 UIParent 的帧，值为其原始 viewer
-- 弱 key 确保帧被 GC 时自动清理
local cenManagedFrames = setmetatable({}, { __mode = "k" })

-- 当前关联 viewer / cfg（由 EnableBuffCentering 写入）
local _viewer = nil
local _cfg    = nil

-- suppressed 版本号：MonitorBars 重建 suppressed 集合后 +1，
-- 触发状态变化检测，驱动居中循环重排
ns.suppressedVersion = ns.suppressedVersion or 0

-- 前向声明（CenterBuffsOnUpdate 内部调用）
local DisableBuffCentering

------------------------------------------------------
-- 采集主组可见图标
-- 排除：suppressed（hideFromCDM） + 自定义分组图标
------------------------------------------------------

local function CollectMainVisible(viewer)
    if not viewer then return {} end

    local suppressed = ns.cdmSuppressedCooldownIDs
    local icons = {}

    if viewer.itemFramePool then
        for frame in viewer.itemFramePool:EnumerateActive() do
            if frame and frame.Icon and frame:IsShown() then
                if not (suppressed and suppressed[frame.cooldownID]) then
                    if not (Layout.GetGroupIdxForIcon
                            and Layout:GetGroupIdxForIcon(frame)) then
                        icons[#icons + 1] = frame
                    end
                end
            end
        end
    else
        for _, child in ipairs({ viewer:GetChildren() }) do
            if child and child.Icon and child:IsShown() then
                if not (suppressed and suppressed[child.cooldownID]) then
                    if not (Layout.GetGroupIdxForIcon
                            and Layout:GetGroupIdxForIcon(child)) then
                        icons[#icons + 1] = child
                    end
                end
            end
        end
    end

    table.sort(icons, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    return icons
end

------------------------------------------------------
-- 状态变化检测
------------------------------------------------------

local function HasStateChanged(icons)
    if cenDirty then return true end

    if cenLastSuppressVer ~= ns.suppressedVersion then return true end

    local count = #icons
    if count ~= cenLastVisCount then return true end

    for i = 1, count do
        if not cenLastVisSet[icons[i]] then return true end
    end

    for i = 1, count do
        local frame = icons[i]
        if cenLastLayout[frame] ~= (frame.layoutIndex or 0) then
            return true
        end
    end

    return false
end

------------------------------------------------------
-- 缓存状态
------------------------------------------------------

local function CacheState(icons)
    cenLastSuppressVer = ns.suppressedVersion

    wipe(cenLastVisSet)
    local count = #icons
    for i = 1, count do
        cenLastVisSet[icons[i]] = true
    end
    cenLastVisCount = count

    wipe(cenLastLayout)
    for i = 1, count do
        local frame = icons[i]
        cenLastLayout[frame] = frame.layoutIndex or 0
    end
end

------------------------------------------------------
-- 像素级精确居中定位
--
-- 帧 re-parent 到 UIParent，以 viewer 的 BOTTOM（底边中点）或
-- LEFT（左边中点）为锚点做偏移，完全不依赖 viewer:GetWidth/Height()，
-- 避免 viewer 宽度为 0 或不正确时的偏移计算错误。
------------------------------------------------------

local function PixelCenterBuffs(viewer, icons, cfg)
    local count = #icons
    if count == 0 or not viewer then return end

    local w  = cfg.iconWidth  or 36
    local h  = cfg.iconHeight or 36
    local isH = (viewer.isHorizontal ~= false)

    -- 使用 viewer 的 CENTER 而非 BOTTOM/LEFT 作为锚点。
    -- 当我们把图标 re-parent 到 UIParent 后，viewer 没有可见子节点，
    -- WoW 布局引擎会把 viewer 高度/宽度缩为 0，导致 BOTTOM/LEFT 锚点
    -- 漂移（偏高 iconHeight/2 或偏右 iconWidth/2）。
    -- viewer 的 CENTER 由 WoW edit mode 以 CENTER 锚点定位，不随内容
    -- 数量变化，因此是稳定的参考点

    if isH then
        local sx       = cfg.spacingX or 2
        local itemWPx  = math.max(1, ToPx(w))
        local itemHPx  = math.max(1, ToPx(h))
        local gapPx    = math.max(0, ToPx(sx))
        local stepPx   = itemWPx + gapPx
        local rowWPx   = count * itemWPx + (count - 1) * gapPx
        local halfRowPx = math.floor(rowWPx * 0.5)
        -- 以 viewer CENTER 为参考，Y 偏移 -halfH 把 BOTTOMLEFT 定在
        -- viewer 配置中心以下半个图标高度处
        local halfHPx  = math.floor(itemHPx * 0.5)

        for i, frame in ipairs(icons) do
            local xPx = -halfRowPx + (i - 1) * stepPx
            cenManagedFrames[frame] = viewer
            frame:SetParent(UIParent)
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", viewer, "CENTER", ToUI(xPx), ToUI(-halfHPx))
        end
    else
        local sy       = cfg.spacingY or 2
        local itemWPx  = math.max(1, ToPx(w))
        local itemHPx  = math.max(1, ToPx(h))
        local gapPx    = math.max(0, ToPx(sy))
        local stepPx   = itemHPx + gapPx
        local colHPx   = count * itemHPx + (count - 1) * gapPx
        local halfColPx = math.floor(colHPx * 0.5)
        -- 以 viewer CENTER 为参考，X 偏移 -halfW 使图标水平居中
        local halfWPx  = math.floor(itemWPx * 0.5)

        for i, frame in ipairs(icons) do
            local yPx = halfColPx - itemHPx - (i - 1) * stepPx
            cenManagedFrames[frame] = viewer
            frame:SetParent(UIParent)
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", viewer, "CENTER", ToUI(-halfWPx), ToUI(yPx))
        end
    end
end

------------------------------------------------------
-- OnUpdate：居中状态机主循环
-- 节流 → 采集 → 检测变化 → 定位 → 缓存 → 爆发/空闲管理
------------------------------------------------------

local function CenterBuffsOnUpdate()
    local now      = GetTime()
    local throttle = (cenDirty or cenBurstTicks > 0)
        and BURST_THROTTLE or WATCHDOG_THROTTLE
    if now < nextUpdate then return end
    nextUpdate = now + throttle

    local viewer = _viewer
    if not viewer then
        DisableBuffCentering()
        return
    end

    local icons = CollectMainVisible(viewer)

    if #icons == 0 then
        DisableBuffCentering()
        return
    end

    local changed = HasStateChanged(icons)
    if not changed then
        if cenBurstTicks > 0 then
            cenBurstTicks = cenBurstTicks - 1
        elseif (now - cenLastActivity) >= IDLE_DISABLE then
            DisableBuffCentering()
        end
        return
    end

    PixelCenterBuffs(viewer, icons, _cfg or {})
    CacheState(icons)
    cenDirty        = false
    cenBurstTicks   = BURST_TICKS
    cenLastActivity = now
end

------------------------------------------------------
-- 公开 API（挂载到 Layout 命名空间）
------------------------------------------------------

local function MarkBuffCenteringDirty()
    cenDirty        = true
    cenBurstTicks   = BURST_TICKS
    cenLastActivity = GetTime()
    nextUpdate      = 0
end

-- 以 self:EnableBuffCentering(viewer, cfg) 调用时，第一个参数是 self（Layout 表），
-- 用 _ 忽略，第二、三个参数才是实际的 viewer 和 cfg。
local function EnableBuffCentering(_, viewer, cfg)
    _viewer = viewer
    _cfg    = cfg
    MarkBuffCenteringDirty()
    if not cenEnabled then
        buffCenFrame:SetScript("OnUpdate", CenterBuffsOnUpdate)
        cenEnabled = true
    end
end

DisableBuffCentering = function()
    if cenEnabled then
        buffCenFrame:SetScript("OnUpdate", nil)
        cenEnabled = false
    end

    -- 将被管理帧还原到原始 viewer（切换 DEFAULT 模式时需要）
    for frame, originalViewer in pairs(cenManagedFrames) do
        if frame and frame.IsObjectType and frame:IsObjectType("Frame")
            and originalViewer then
            frame:SetParent(originalViewer)
        end
    end
    wipe(cenManagedFrames)

    cenDirty           = true
    cenBurstTicks      = 0
    cenLastActivity    = 0
    nextUpdate         = 0
    cenLastVisCount    = 0
    cenLastSuppressVer = -1
    wipe(cenLastVisSet)
    wipe(cenLastLayout)
end

Layout.EnableBuffCentering    = EnableBuffCentering
Layout.DisableBuffCentering   = DisableBuffCentering
Layout.MarkBuffCenteringDirty = MarkBuffCenteringDirty
