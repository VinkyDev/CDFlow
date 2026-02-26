-- 插件入口：事件编排、查看器 Hook、高亮 Hook
local _, ns = ...

local Layout = ns.Layout
local Style  = ns.Style
local L = ns.L
local MB = ns.MonitorBars
local IM = ns.ItemMonitor

local buffRefreshPending = false
local buffViewerHooksSetup = false   -- SetupBuffViewerHooks 只执行一次的守卫
local trackedBarsRefreshPending = false
local RequestTrackedBarsRefresh  -- 前向声明，供 HookTrackedBarChildren 内的闭包捕获
local trackedBarsProxyFrame

local function IsManagedTrackedBarsEnabled()
    -- 固定由 CDFlow 接管 TrackedBars 编辑定位（不再提供用户开关）
    return ns.db and ns.db.modules and ns.db.modules.trackedBars and ns.db.trackedBars
end

local function GetTrackedBarsViewerSafe()
    if Layout and Layout.GetTrackedBarsViewer then
        return Layout:GetTrackedBarsViewer()
    end
    return _G.BuffBarCooldownViewer
end

local function MirrorProxyToViewer(proxy)
    local viewer = GetTrackedBarsViewerSafe()
    if not (proxy and viewer and viewer:IsShown()) then return end

    local point, _, _, x, y = proxy:GetPoint(1)
    point = point or "CENTER"
    x, y = x or 0, y or 0

    viewer:ClearAllPoints()
    viewer:SetPoint(point, UIParent, point, x, y)
end

local function SyncTrackedBarsPosToWoWLayout()
    -- 通过同步代理点到系统 viewer 点位，让 WoW EditMode 保存流程读取同一位置。
    if trackedBarsProxyFrame and trackedBarsProxyFrame:IsShown() then
        MirrorProxyToViewer(trackedBarsProxyFrame)
    end
end

local function SaveTrackedBarsManagedPoint(anchor, x, y)
    if not (Layout and Layout.SetTrackedBarsManagedPoint and IsManagedTrackedBarsEnabled()) then return end
    Layout:SetTrackedBarsManagedPoint(anchor, x, y)
end

local function CaptureViewerPointToManagedCfg()
    if not IsManagedTrackedBarsEnabled() then return end
    local viewer = GetTrackedBarsViewerSafe()
    if not viewer then return end

    local p, _, _, x, y = viewer:GetPoint(1)
    SaveTrackedBarsManagedPoint(p or "CENTER", x or 0, y or 0)
end

local function EnsureTrackedBarsProxyFrame()
    if trackedBarsProxyFrame then return trackedBarsProxyFrame end

    local f = CreateFrame("Frame", "CDFTrackedBarsProxyFrame", UIParent, "BackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0.7, 1, 0.10)
    f:SetBackdropBorderColor(0, 0.7, 1, 0.95)

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOP", f, "BOTTOM", 0, -2)
    label:SetText("|cff66ccffCDFlow TrackedBars|r")
    f._posLabel = label

    f:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self:StartMoving()
        self:SetScript("OnUpdate", function()
            MirrorProxyToViewer(self)
        end)
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetScript("OnUpdate", nil)
        local p, _, _, x, y = self:GetPoint(1)
        SaveTrackedBarsManagedPoint(p or "CENTER", x or 0, y or 0)
        SyncTrackedBarsPosToWoWLayout()
        RequestTrackedBarsRefresh()
    end)

    f:Hide()
    trackedBarsProxyFrame = f
    return f
end

local function ShowTrackedBarsProxy()
    if not (ns.db and ns.db.modules and ns.db.modules.trackedBars and IsManagedTrackedBarsEnabled()) then return end
    if InCombatLockdown() then return end

    local viewer = GetTrackedBarsViewerSafe()
    if not viewer then return end

    local proxy = EnsureTrackedBarsProxyFrame()
    local point, x, y = "CENTER", 0, 0
    if Layout and Layout.GetTrackedBarsManagedPoint then
        point, x, y = Layout:GetTrackedBarsManagedPoint()
    end

    proxy:ClearAllPoints()
    proxy:SetPoint(point, UIParent, point, x or 0, y or 0)
    proxy:SetSize(math.max(20, viewer:GetWidth() or 20), math.max(20, viewer:GetHeight() or 20))
    proxy:Show()
    MirrorProxyToViewer(proxy)
end

local function HideTrackedBarsProxy()
    if trackedBarsProxyFrame then
        trackedBarsProxyFrame:Hide()
        trackedBarsProxyFrame:SetScript("OnUpdate", nil)
    end
end

------------------------------------------------------
-- Buff Viewer 刷新（带 IsInitialized 重试）
------------------------------------------------------

local function DoBuffViewerRefresh(attempt)
    attempt = attempt or 0
    local viewer = BuffIconCooldownViewer
    if not viewer then return end
    -- viewer 尚未初始化时（reload 后首次进入世界的短暂窗口），延迟重试
    if viewer.IsInitialized and not viewer:IsInitialized() then
        if attempt < 5 then
            C_Timer.After(0.1, function() DoBuffViewerRefresh(attempt + 1) end)
        end
        return
    end
    Layout:RefreshViewer("BuffIconCooldownViewer")
end

local function RequestBuffViewerRefresh()
    if buffRefreshPending then return end
    buffRefreshPending = true
    -- 下一帧触发，确保当帧所有 OnActiveStateChanged 处理完后再居中
    C_Timer.After(0, function()
        buffRefreshPending = false
        DoBuffViewerRefresh()
    end)
end

-- 供 MonitorBars/Bars.lua 的 RebuildCDMSuppressedSet 调用：
-- 重建 suppressed 集合后立即触发完整 RefreshViewer（执行 SplitVisible 隐藏逻辑）。
-- 在 ADDON_LOADED 完成后注入到 Layout 命名空间，避免循环依赖。
Layout.RequestBuffRefreshFromMB = RequestBuffViewerRefresh

------------------------------------------------------
-- Buff Viewer 综合钩子
-- 只执行一次，由 RegisterCDMHooks 和 PLAYER_ENTERING_WORLD 保证调用
------------------------------------------------------

local function SetupBuffViewerHooks()
    local viewer = BuffIconCooldownViewer
    if not viewer or buffViewerHooksSetup then return end
    buffViewerHooksSetup = true

    -- RefreshData → 战斗中每次 buff 数据更新触发
    if viewer.RefreshData then
        hooksecurefunc(viewer, "RefreshData", function()
            Layout:MarkBuffCenteringDirty()
            RequestBuffViewerRefresh()
        end)
    end

    -- UpdateLayout / Layout → 布局重算完成后触发
    local function OnPostLayout()
        Layout:MarkBuffCenteringDirty()
        RequestBuffViewerRefresh()
    end
    if viewer.UpdateLayout then
        hooksecurefunc(viewer, "UpdateLayout", OnPostLayout)
    elseif viewer.Layout then
        hooksecurefunc(viewer, "Layout", OnPostLayout)
    end

    -- itemFramePool.Acquire → 新帧从池激活（新 buff 出现）
    -- itemFramePool.Release → 帧归还池（buff 消失），立即重排
    if viewer.itemFramePool then
        if not viewer.itemFramePool._cdf_acquireHooked then
            viewer.itemFramePool._cdf_acquireHooked = true
            hooksecurefunc(viewer.itemFramePool, "Acquire", function()
                RequestBuffViewerRefresh()
            end)
        end
        if not viewer.itemFramePool._cdf_releaseHooked then
            viewer.itemFramePool._cdf_releaseHooked = true
            hooksecurefunc(viewer.itemFramePool, "Release", function()
                Layout:MarkBuffCenteringDirty()   -- 立即标脏，下帧 OnUpdate 重排
                RequestBuffViewerRefresh()
            end)
        end
    end

    -- OnShow → viewer 变为可见时刷新
    viewer:HookScript("OnShow", function()
        RequestBuffViewerRefresh()
    end)
end

local function HookTrackedBarChildren()
    local viewer = BuffBarCooldownViewer
    if not viewer then return end

    local frames = {}
    if viewer.GetItemFrames then
        local ok, items = pcall(viewer.GetItemFrames, viewer)
        if ok and type(items) == "table" then frames = items end
    end
    if #frames == 0 then
        for _, child in ipairs({ viewer:GetChildren() }) do
            if child and child:IsObjectType("Frame") then
                frames[#frames + 1] = child
            end
        end
    end

    for _, frame in ipairs(frames) do
        if frame and not frame._cdf_tb_hooked then
            frame._cdf_tb_hooked = true
            if frame.HookScript then
                -- OnShow：同步立即重排，消除新条出现时的首帧闪烁
                pcall(frame.HookScript, frame, "OnShow", function()
                    Layout:RefreshTrackedBars()
                    RequestTrackedBarsRefresh()  -- 延迟同步 viewer 尺寸
                end)
                -- 其他事件：防抖刷新
                for _, script in ipairs({ "OnActiveStateChanged", "OnUnitAuraAddedEvent", "OnUnitAuraRemovedEvent" }) do
                    pcall(frame.HookScript, frame, script, RequestTrackedBarsRefresh)
                end
            end
        end
    end
end

RequestTrackedBarsRefresh = function()
    if trackedBarsRefreshPending then return end
    trackedBarsRefreshPending = true
    C_Timer.After(0.05, function()
        trackedBarsRefreshPending = false
        HookTrackedBarChildren()
        Layout:RefreshTrackedBars()
    end)
end

local function RegisterCDMHooks()
    -- Essential / Utility：只需 hook RefreshLayout
    if EssentialCooldownViewer then
        hooksecurefunc(EssentialCooldownViewer, "RefreshLayout", function()
            Layout:RefreshViewer("EssentialCooldownViewer")
        end)
    end
    if UtilityCooldownViewer then
        hooksecurefunc(UtilityCooldownViewer, "RefreshLayout", function()
            Layout:RefreshViewer("UtilityCooldownViewer")
        end)
    end

    -- Buff viewer：RefreshData / UpdateLayout / Pool / OnShow 综合钩子
    SetupBuffViewerHooks()

    -- Buff viewer RefreshLayout → 兜底钩子（布局设置/大小变更时）
    if BuffIconCooldownViewer then
        hooksecurefunc(BuffIconCooldownViewer, "RefreshLayout", function()
            Layout:MarkBuffCenteringDirty()
            Layout:RefreshViewer("BuffIconCooldownViewer")
        end)
    end

    -- Mixin 级别钩子：OnCooldownIDSet / OnActiveStateChanged
        if CooldownViewerBuffIconItemMixin.OnCooldownIDSet then
            hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnCooldownIDSet", function(frame)
                if not BuffIconCooldownViewer then return end
                local parent = frame:GetParent()
                if parent ~= BuffIconCooldownViewer and parent ~= UIParent then return end
                -- 实时更新 spellID→cooldownID 映射并重建 suppressed 集合
                if MB and MB.UpdateFrameMapping then
                    MB:UpdateFrameMapping(frame)
                end
                Layout:ProvisionalPlaceInGroup(frame)
                Layout:MarkBuffCenteringDirty()
                RequestBuffViewerRefresh()
            end)
        end
        if CooldownViewerBuffIconItemMixin.OnActiveStateChanged then
            hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnActiveStateChanged", function(frame)
                if not BuffIconCooldownViewer then return end
                local parent = frame:GetParent()
                if parent ~= BuffIconCooldownViewer and parent ~= UIParent then return end
                Layout:ProvisionalPlaceInGroup(frame)
                Layout:MarkBuffCenteringDirty()
                RequestBuffViewerRefresh()
            end)
        end
end

local function RegisterTrackedBarsHooks()
    if BuffBarCooldownViewer then
        hooksecurefunc(BuffBarCooldownViewer, "RefreshLayout", function()
            HookTrackedBarChildren()
            Layout:RefreshTrackedBars()
        end)
    end
end

local VIEWER_SET = {}

local function SetupGlowHooks()
    if EssentialCooldownViewer then VIEWER_SET[EssentialCooldownViewer] = true end
    if UtilityCooldownViewer   then VIEWER_SET[UtilityCooldownViewer]   = true end
    if BuffIconCooldownViewer  then VIEWER_SET[BuffIconCooldownViewer]  = true end

    if not ActionButtonSpellAlertManager then return end

    hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, frame)
        if not frame or not frame._cdf_styled then return end
        local parent = frame:GetParent()
        if not parent or not VIEWER_SET[parent] then return end

        frame._cdf_alertActive = true

        C_Timer.After(0, function()
            if frame._cdf_alertActive then
                Style:ShowHighlight(frame)
            end
        end)
    end)

    hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", function(_, frame)
        if not frame or not frame._cdf_alertActive then return end
        frame._cdf_alertActive = nil
        Style:HideHighlight(frame)
    end)
end

local refreshAllPending = false

local function RequestRefreshAll(delay)
    if refreshAllPending then return end
    refreshAllPending = true
    C_Timer.After(delay or 0, function()
        refreshAllPending = false
        Layout:RefreshAll()
    end)
end

local function RegisterEventRegistryCallbacks(mods)
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
        RequestRefreshAll(0)
        C_Timer.After(0.15, RequestBuffViewerRefresh)
        if mods.trackedBars then
            C_Timer.After(0.15, RequestTrackedBarsRefresh)
        end
        C_Timer.After(0.15, function() Layout:PositionGroupContainers() end)
    end)

    EventRegistry:RegisterCallback("EditMode.Enter", function()
        CaptureViewerPointToManagedCfg()
        ShowTrackedBarsProxy()
        RequestRefreshAll(0)
    end)
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        HideTrackedBarsProxy()
        SyncTrackedBarsPosToWoWLayout()
        RequestRefreshAll(0)
    end)
end

------------------------------------------------------
-- 插件加载入口
------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, _, addonName)
    if addonName ~= "CDFlow" then return end

    ns:InitDB()

    local mods = ns.db.modules

    local function OnProfileChanged()
        ns:OnProfileChanged()
        if ns.db.modules.cdmBeautify then
            Layout:InitBuffGroups()  -- 容器必须在 RefreshAll 前就绪
            Layout:RefreshAll()
        end
        if ns.db.modules.monitorBars and MB then
            MB:RebuildAllBars()
        end
        if ns.db.modules.itemMonitor and IM then IM:Init() end
        if ns.Visibility then
            ns.Visibility:Initialize()
        end
    end

    ns.acedb.RegisterCallback(ns, "OnProfileChanged", function() OnProfileChanged() end)
    ns.acedb.RegisterCallback(ns, "OnProfileCopied", function() OnProfileChanged() end)
    ns.acedb.RegisterCallback(ns, "OnProfileReset", function() OnProfileChanged() end)

    if mods.cdmBeautify then
        RegisterCDMHooks()
        RegisterEventRegistryCallbacks(mods)
        SetupGlowHooks()
        -- 立即初始化分组容器，确保第一次 buff 触发时 buffGroupContainers 已就绪。
        -- GetGroupIdxForIcon 在返回分组索引前会检查 buffGroupContainers[gIdx]，
        -- 若容器为 nil（InitBuffGroups 未调用），ProvisionalPlaceInGroup 永远返回 nil
        -- 导致首次触发的 buff 显示在系统 buff 组而非自定义分组。
        Layout:InitBuffGroups()
    end

    if mods.trackedBars then
        RegisterTrackedBarsHooks()
    end

    if mods.cdmBeautify and mods.monitorBars and MB then
        hooksecurefunc(MB, "RebuildAllBars", function()
            C_Timer.After(0, function()
                if ns.db.modules.cdmBeautify then Layout:RefreshAll() end
            end)
        end)
    end

    local eventFrame = CreateFrame("Frame")
    local eventHandlers = {}

    eventHandlers["PLAYER_ENTERING_WORLD"] = function()
        if mods.cdmBeautify then
            RequestRefreshAll(0)
            -- 确保 buff viewer 钩子就位（ADDON_LOADED 时 viewer 可能尚未可用）
            SetupBuffViewerHooks()
            -- 立即重建分组容器（进入新地图/reload 时，确保战斗开始前容器就绪）
            Layout:InitBuffGroups()
        end
        C_Timer.After(0.5, function()
            if mods.monitorBars then
                MB:ScanCDMViewers()
                MB:RebuildAllBars()
            end
            if mods.cdmBeautify then
                -- 再次尝试挂钩
                SetupBuffViewerHooks()
                Layout:InitBuffGroups()  -- 容器必须在 RefreshAll 前就绪
                Layout:RefreshAll()
            end
            if mods.trackedBars then
                HookTrackedBarChildren()
                Layout:RefreshTrackedBars()
            end
            if mods.itemMonitor and IM then IM:Init() end
            if ns.Visibility then ns.Visibility:UpdateAll() end
        end)
    end

    eventHandlers["PLAYER_SPECIALIZATION_CHANGED"] = function()
        if mods.cdmBeautify then RequestRefreshAll(0) end
        if mods.monitorBars then
            C_Timer.After(0.5, function()
                MB:ScanCDMViewers()
                MB:RebuildAllBars()
                if mods.cdmBeautify then Layout:RefreshAll() end
            end)
        end
    end

    if mods.cdmBeautify then
        eventHandlers["EDIT_MODE_LAYOUTS_UPDATED"] = function()
            if IsManagedTrackedBarsEnabled() and trackedBarsProxyFrame and trackedBarsProxyFrame:IsShown() then
                local p, _, _, x, y = trackedBarsProxyFrame:GetPoint(1)
                SaveTrackedBarsManagedPoint(p or "CENTER", x or 0, y or 0)
                SyncTrackedBarsPosToWoWLayout()
            end
            RequestRefreshAll(0)
        end

        eventHandlers["TRAIT_CONFIG_UPDATED"] = function()
            RequestRefreshAll(0)
        end

        eventHandlers["UPDATE_BINDINGS"] = function()
            if Style.InvalidateKeybindCache then
                Style:InvalidateKeybindCache()
            end
            RequestRefreshAll(0)
        end

        eventHandlers["UPDATE_BONUS_ACTIONBAR"] = function()
            if Style.InvalidateKeybindCache then
                Style:InvalidateKeybindCache()
            end
            RequestRefreshAll(0)
        end

        eventHandlers["ACTIONBAR_HIDEGRID"] = function()
            if Style.InvalidateKeybindCache then
                Style:InvalidateKeybindCache()
            end
            RequestRefreshAll(0)
        end
    end

    if mods.monitorBars or mods.trackedBars then
        eventHandlers["UNIT_AURA"] = function(unit)
            if mods.monitorBars then MB:OnAuraUpdate() end
            if unit == "player" and mods.trackedBars then
                RequestTrackedBarsRefresh()
            end
        end
    end

    if mods.monitorBars then
        eventHandlers["SPELL_UPDATE_CHARGES"] = function()
            MB:OnChargeUpdate()
        end

        eventHandlers["PLAYER_REGEN_ENABLED"] = function()
            MB:OnCombatLeave()
        end

        eventHandlers["PLAYER_REGEN_DISABLED"] = function()
            MB:OnCombatEnter()
        end

        eventHandlers["PLAYER_TARGET_CHANGED"] = function()
            MB:OnTargetChanged()
        end
    end

    -- SPELL_UPDATE_COOLDOWN：同时服务 MonitorBars 和 ItemMonitor
    if mods.monitorBars or (mods.itemMonitor and IM) then
        eventHandlers["SPELL_UPDATE_COOLDOWN"] = function()
            if mods.monitorBars then MB:OnCooldownUpdate() end
            if mods.itemMonitor and IM then IM:UpdateAllCooldowns() end
        end
    end

    -- 物品监控事件
    if mods.itemMonitor and IM then
        eventHandlers["BAG_UPDATE_COOLDOWN"] = function()
            IM:UpdateAllCooldowns()
        end

        eventHandlers["PLAYER_EQUIPMENT_CHANGED"] = function()
            IM:Init()
        end

        eventHandlers["GET_ITEM_INFO_RECEIVED"] = function()
            IM:RefreshItemNames()
        end

        eventHandlers["BAG_UPDATE"] = function()
            IM:RefreshItemCounts()
        end
    end

    for event in pairs(eventHandlers) do
        eventFrame:RegisterEvent(event)
    end

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        local handler = eventHandlers[event]
        if handler then handler(...) end
    end)

    if ns.InitSettings then
        ns:InitSettings()
    end

    if ns.Visibility then
        ns.Visibility:Initialize()
    end

    print("|cff00ccff[CDFlow]|r " .. format(L.loaded, L.slashHelp))

    initFrame:UnregisterAllEvents()
end)
