local _, ns = ...

------------------------------------------------------
-- 核心模块
------------------------------------------------------

local Layout = ns.Layout
local Style  = ns.Style
local L = ns.L
local MB = ns.MonitorBars

-- Buff 图标子帧 Hook（防抖：避免 OnActiveStateChanged 等频繁触发导致闪烁）
------------------------------------------------------
local buffRefreshPending = false

local function RequestBuffViewerRefresh()
    if buffRefreshPending then return end
    buffRefreshPending = true
    C_Timer.After(0.05, function()
        buffRefreshPending = false
        Layout:RefreshViewer("BuffIconCooldownViewer")
    end)
end

local function HookBuffChildren()
    local viewer = BuffIconCooldownViewer
    if not viewer then return end

    local children = { viewer:GetChildren() }
    for _, child in ipairs(children) do
        if child and child.Icon and not child._cdf_hooked then
            child._cdf_hooked = true
            if child.OnActiveStateChanged then
                hooksecurefunc(child, "OnActiveStateChanged", RequestBuffViewerRefresh)
            end
            if child.OnUnitAuraAddedEvent then
                hooksecurefunc(child, "OnUnitAuraAddedEvent", RequestBuffViewerRefresh)
            end
            if child.OnUnitAuraRemovedEvent then
                hooksecurefunc(child, "OnUnitAuraRemovedEvent", RequestBuffViewerRefresh)
            end
        end
    end
end

------------------------------------------------------
-- Hook 三个冷却查看器的 RefreshLayout
------------------------------------------------------
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
            Layout:RefreshTrackedBars()
        end)
    end
end

------------------------------------------------------
-- 高亮特效 Hook（检测技能激活/取消高亮）
------------------------------------------------------
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

------------------------------------------------------
-- EventRegistry 回调：响应冷却管理器设置变更
------------------------------------------------------
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

    ns:LoadConfig()

    local mods = ns.db.modules

    -- CDM 美化模块（含高亮特效）
    if mods.cdmBeautify then
        RegisterHooks()
        RegisterEventRegistryCallbacks()
        SetupGlowHooks()
    end

    -- 按模块注册游戏事件
    local eventFrame = CreateFrame("Frame")
    local eventHandlers = {}

    eventHandlers["PLAYER_ENTERING_WORLD"] = function()
        if mods.cdmBeautify then RequestRefreshAll(0) end
        C_Timer.After(0.5, function()
            if mods.cdmBeautify then Layout:RefreshAll() end
            if mods.monitorBars then
                MB:ScanCDMViewers()
                MB:RebuildAllBars()
            end
        end)
    end

    eventHandlers["PLAYER_SPECIALIZATION_CHANGED"] = function()
        if mods.cdmBeautify then RequestRefreshAll(0) end
        if mods.monitorBars then
            C_Timer.After(0.5, function()
                MB:ScanCDMViewers()
                MB:RebuildAllBars()
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

    if mods.monitorBars then
        eventHandlers["UNIT_AURA"] = function(unit)
            MB:OnAuraUpdate()
        end

        eventHandlers["SPELL_UPDATE_CHARGES"] = function()
            MB:OnChargeUpdate()
        end

        eventHandlers["SPELL_UPDATE_COOLDOWN"] = function()
            MB:OnCooldownUpdate()
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

    for event in pairs(eventHandlers) do
        eventFrame:RegisterEvent(event)
    end

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        local handler = eventHandlers[event]
        if handler then handler(...) end
    end)

    -- 初始化设置面板
    if ns.InitSettings then
        ns:InitSettings()
    end

    -- 初始化监控条（延迟，等 CDM 就绪）
    if mods.monitorBars then
        C_Timer.After(1, function()
            MB:ScanCDMViewers()
            MB:InitAllBars()
        end)
    end

    print("|cff00ccff[CDFlow]|r " .. format(L.loaded, L.slashHelp))

    initFrame:UnregisterAllEvents()
end)
