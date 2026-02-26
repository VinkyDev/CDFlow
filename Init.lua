-- 插件入口：事件编排、查看器 Hook、高亮 Hook
local _, ns = ...

local Layout = ns.Layout
local Style  = ns.Style
local L = ns.L
local MB = ns.MonitorBars
local IM = ns.ItemMonitor

local buffRefreshPending = false
local trackedBarsRefreshPending = false
local RequestTrackedBarsRefresh  -- 前向声明，供 HookTrackedBarChildren 内的闭包捕获

local function HookBuffChildren()
    local viewer = BuffIconCooldownViewer
    if not viewer then return end

    local children = { viewer:GetChildren() }
    for _, child in ipairs(children) do
        if child and child.Icon and not child._cdf_hooked then
            child._cdf_hooked = true
            if child.HookScript then
                for _, script in ipairs({ "OnActiveStateChanged", "OnUnitAuraAddedEvent", "OnUnitAuraRemovedEvent" }) do
                    pcall(child.HookScript, child, script, RequestBuffViewerRefresh)
                end
            end
        end
    end
end

local function RequestBuffViewerRefresh()
    if buffRefreshPending then return end
    buffRefreshPending = true
    C_Timer.After(0.05, function()
        buffRefreshPending = false
        HookBuffChildren()
        Layout:RefreshViewer("BuffIconCooldownViewer")
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

local function RegisterHooks()
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

    if BuffIconCooldownViewer then
        hooksecurefunc(BuffIconCooldownViewer, "RefreshLayout", function()
            HookBuffChildren()
            Layout:RefreshViewer("BuffIconCooldownViewer")
        end)
    end

    if BuffBarCooldownViewer then
        hooksecurefunc(BuffBarCooldownViewer, "RefreshLayout", function()
            HookTrackedBarChildren()
            Layout:RefreshTrackedBars()
        end)
    end

    -- Mixin 级别钩子：在 OnCooldownIDSet / OnActiveStateChanged 触发时
    -- 立即进行临时放置，消除自定义分组图标出现时的首帧延迟（参考 Ayije_CDM Main.lua）
    if CooldownViewerBuffIconItemMixin then
        if CooldownViewerBuffIconItemMixin.OnCooldownIDSet then
            hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnCooldownIDSet", function(frame)
                if not BuffIconCooldownViewer then return end
                if frame:GetParent() ~= BuffIconCooldownViewer then return end
                Layout:ProvisionalPlaceInGroup(frame)
                RequestBuffViewerRefresh()
            end)
        end
        if CooldownViewerBuffIconItemMixin.OnActiveStateChanged then
            hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnActiveStateChanged", function(frame)
                if not BuffIconCooldownViewer then return end
                if frame:GetParent() ~= BuffIconCooldownViewer then return end
                Layout:ProvisionalPlaceInGroup(frame)
                -- 注意：per-instance 的 OnActiveStateChanged 钩子已经调用
                -- RequestBuffViewerRefresh，此处不重复排队
            end)
        end
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

local function RegisterEventRegistryCallbacks()
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
        RequestRefreshAll(0)
        C_Timer.After(0.15, RequestBuffViewerRefresh)
        C_Timer.After(0.15, RequestTrackedBarsRefresh)
        C_Timer.After(0.15, function() Layout:PositionGroupContainers() end)
    end)

    EventRegistry:RegisterCallback("EditMode.Enter", function()
        RequestRefreshAll(0)
    end)
    EventRegistry:RegisterCallback("EditMode.Exit", function()
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

    local function OnProfileChanged()
        ns:OnProfileChanged()
        if ns.db.modules.cdmBeautify then
            Layout:InitBuffGroups()  -- 容器必须在 RefreshAll 前就绪
            Layout:RefreshAll()
        end
        if ns.db.modules.monitorBars and MB then
            MB:RebuildAllBars()
        end
        if IM then IM:Init() end
        if ns.Visibility then
            ns.Visibility:Initialize()
        end
    end

    ns.acedb.RegisterCallback(ns, "OnProfileChanged", function() OnProfileChanged() end)
    ns.acedb.RegisterCallback(ns, "OnProfileCopied", function() OnProfileChanged() end)
    ns.acedb.RegisterCallback(ns, "OnProfileReset", function() OnProfileChanged() end)

    local mods = ns.db.modules

    if mods.cdmBeautify then
        RegisterHooks()
        RegisterEventRegistryCallbacks()
        SetupGlowHooks()
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
        if mods.cdmBeautify then RequestRefreshAll(0) end
        C_Timer.After(0.5, function()
            if mods.monitorBars then
                MB:ScanCDMViewers()
                MB:RebuildAllBars()
            end
            if mods.cdmBeautify then
                Layout:InitBuffGroups()  -- 容器必须在 RefreshAll 前就绪
                Layout:RefreshAll()
            end
            if IM then IM:Init() end
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

    if mods.monitorBars or mods.cdmBeautify then
        eventHandlers["UNIT_AURA"] = function(unit)
            if mods.monitorBars then MB:OnAuraUpdate() end
            if unit == "player" and mods.cdmBeautify then
                RequestTrackedBarsRefresh()
            end
        end
    end

    if mods.monitorBars then
        eventHandlers["SPELL_UPDATE_CHARGES"] = function()
            MB:OnChargeUpdate()
        end

        eventHandlers["SPELL_UPDATE_COOLDOWN"] = function()
            MB:OnCooldownUpdate()
            if IM then IM:UpdateAllCooldowns() end
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

    -- 物品监控事件（参考 Ayije_CDM Trinkets.lua 241-258 行）
    if IM then
        eventHandlers["BAG_UPDATE_COOLDOWN"] = function()
            IM:UpdateAllCooldowns()
        end

        if not eventHandlers["SPELL_UPDATE_COOLDOWN"] then
            -- 仅 monitorBars 关闭时需要独立注册
            eventHandlers["SPELL_UPDATE_COOLDOWN"] = function()
                IM:UpdateAllCooldowns()
            end
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
