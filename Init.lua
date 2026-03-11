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
        self._isDragging = true
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
    -- 点击（非拖动）时将选中事件转发给原生 viewer，
    -- 使 WoW 编辑模式弹出其自带的设置配置面板。
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            local wasDragging = self._isDragging
            self._isDragging = false
            if not wasDragging then
                local viewer = GetTrackedBarsViewerSafe()
                if viewer and EditModeManagerFrame and EditModeManagerFrame.SelectSystem then
                    EditModeManagerFrame:SelectSystem(viewer)
                end
            end
        elseif button == "RightButton" then
            local viewer = GetTrackedBarsViewerSafe()
            if viewer and EditModeManagerFrame and EditModeManagerFrame.SelectSystem then
                EditModeManagerFrame:SelectSystem(viewer)
            end
        end
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

    local function ImmediateBuffRefresh()
        if viewer._cdf_buffRefreshing then return end
        if not viewer.IsInitialized or not viewer:IsInitialized() then
            RequestBuffViewerRefresh()
            return
        end
        if EditModeManagerFrame and EditModeManagerFrame.layoutApplyInProgress then
            RequestBuffViewerRefresh()
            return
        end
        Layout:RefreshViewer("BuffIconCooldownViewer")
    end

    -- OnAcquireItemFrame → 帧创建/获取的最早时机，立即隐藏防止闪烁
    if viewer.OnAcquireItemFrame then
        hooksecurefunc(viewer, "OnAcquireItemFrame", function(_, frame)
            if frame then frame:SetAlpha(0) end
        end)
    end

    -- RefreshData → 数据更新后同步重定位
    if viewer.RefreshData then
        hooksecurefunc(viewer, "RefreshData", ImmediateBuffRefresh)
    end

    -- UpdateLayout / Layout → 布局重算后同步重定位（最关键的防闪烁钩子）
    if viewer.UpdateLayout then
        hooksecurefunc(viewer, "UpdateLayout", ImmediateBuffRefresh)
    elseif viewer.Layout then
        hooksecurefunc(viewer, "Layout", ImmediateBuffRefresh)
    end

    -- itemFramePool.Acquire → debounced 安全网
    -- itemFramePool.Release → 立即标记居中脏 + 同步刷新（buff 消失后需立即重排）
    if viewer.itemFramePool then
        if not viewer.itemFramePool._cdf_acquireHooked then
            viewer.itemFramePool._cdf_acquireHooked = true
            hooksecurefunc(viewer.itemFramePool, "Acquire", RequestBuffViewerRefresh)
        end
        if not viewer.itemFramePool._cdf_releaseHooked then
            viewer.itemFramePool._cdf_releaseHooked = true
            hooksecurefunc(viewer.itemFramePool, "Release", function()
                Layout.MarkBuffCenteringDirty()
                ImmediateBuffRefresh()
            end)
        end
    end

    -- OnShow → viewer 变为可见时刷新
    viewer:HookScript("OnShow", RequestBuffViewerRefresh)

    -- SetPoint hook：系统可能在编辑模式或 RefreshLayout 中重定位 viewer
    hooksecurefunc(viewer, "SetPoint", function()
        if InCombatLockdown() then return end
        if viewer._cdf_buffRefreshing then return end
        RequestBuffViewerRefresh()
    end)

    -- UpdateSystemSettingIconSize → Blizzard 改变图标大小后强制 scale=1
    if viewer.UpdateSystemSettingIconSize then
        hooksecurefunc(viewer, "UpdateSystemSettingIconSize", function()
            if viewer.itemFramePool then
                for frame in viewer.itemFramePool:EnumerateActive() do
                    if frame and frame.SetScale then
                        frame:SetScale(1)
                    end
                end
            end
            RequestBuffViewerRefresh()
        end)
    end
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

------------------------------------------------------
-- 锁定 BuffIconCooldownViewer 编辑模式
-- 阻止系统设置面板、拖拽、选择，防止系统干扰布局
------------------------------------------------------
local buffViewerEditModeLocked = false

local function IsCooldownViewerSystemFrame(frame)
    local cooldownSystem = Enum and Enum.EditModeSystem and Enum.EditModeSystem.CooldownViewer
    return cooldownSystem and frame and frame.system == cooldownSystem
end

-- 同步 Selection overlay 尺寸到 viewer（确保编辑模式预览区域与 iconLimit 一致）
local function SyncBuffViewerSelectionSize()
    local viewer = BuffIconCooldownViewer
    if not viewer then return end
    local selection = viewer.Selection
    if not selection then return end
    if InCombatLockdown() then return end

    selection:ClearAllPoints()
    selection:SetAllPoints(viewer)
end

local function LockBuffViewerEditMode()
    if buffViewerEditModeLocked then return end

    local function TrySetup()
        local viewer = BuffIconCooldownViewer
        local EditModeSystemSettingsDialog = _G.EditModeSystemSettingsDialog
        if not (viewer and EditModeSystemSettingsDialog and Enum and Enum.EditModeSystem) then
            return false
        end
        if not IsCooldownViewerSystemFrame(viewer) then return false end

        -- 筛选设置项：只保留 Checkbox (对应 Show/Hide, Tooltips, Numbers 等开关)
        -- 隐藏 Slider (Size, Padding) 和 Dropdown (Orientation, Grow Direction)
        if EditModeSystemSettingsDialog.UpdateDialog then
            hooksecurefunc(EditModeSystemSettingsDialog, "UpdateDialog", function(dialog, systemFrame)
                if systemFrame ~= viewer then return end
                
                local container = dialog.Settings
                if not container then return end
                
                -- 辅助函数：判断是否为 Checkbox 设置项
                local function IsCheckboxSetting(frame)
                    -- CheckboxTemplate 通常包含一个 CheckButton 类型的 .Button
                    if frame.Button and frame.Button:IsObjectType("CheckButton") then return true end
                    -- 或者它本身就是 CheckButton
                    if frame:IsObjectType("CheckButton") then return true end
                    -- 兜底：遍历子元素寻找 CheckButton
                    for _, child in ipairs({frame:GetChildren()}) do
                        if child:IsObjectType("CheckButton") then return true end
                    end
                    return false
                end

                for _, child in ipairs({ container:GetChildren() }) do
                    if child:IsShown() and not IsCheckboxSetting(child) then
                        child:Hide()
                    end
                end
                
                if container.Layout then container:Layout() end
                if dialog.Layout then dialog:Layout() end
            end)
        end

        -- 允许拖拽（不锁定位置）
        local selection = viewer.Selection

        -- hook SelectSystem：同步 selection 尺寸
        hooksecurefunc(viewer, "SelectSystem", function(sf)
            SyncBuffViewerSelectionSize()
        end)

        -- hook HighlightSystem：同步 selection 尺寸
        hooksecurefunc(viewer, "HighlightSystem", function()
            SyncBuffViewerSelectionSize()
        end)

        buffViewerEditModeLocked = true
        return true
    end

    if not TrySetup() then
        if EventUtil and EventUtil.ContinueOnAddOnLoaded then
            EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", function()
                TrySetup()
            end)
        end
    end
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

    -- Buff viewer RefreshLayout → 同步重排（布局设置/大小变更时）
    if BuffIconCooldownViewer then
        hooksecurefunc(BuffIconCooldownViewer, "RefreshLayout", function()
            Layout:RefreshViewer("BuffIconCooldownViewer")
        end)
    end

    -- Mixin 级别钩子：OnCooldownIDSet / OnActiveStateChanged
    local function IsBuffViewerIcon(frame)
        local parent = frame:GetParent()
        return parent == BuffIconCooldownViewer or frame._cdf_buffViewer
    end

    if CooldownViewerBuffIconItemMixin.OnCooldownIDSet then
        hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnCooldownIDSet", function(frame)
            if not BuffIconCooldownViewer then return end
            if not IsBuffViewerIcon(frame) then return end
            frame._cdf_buffViewer = true
            if MB and MB.UpdateFrameMapping then
                MB:UpdateFrameMapping(frame)
            end
            Layout.ProvisionalPlaceBuffFrame(frame)
            RequestBuffViewerRefresh()
        end)
    end
    if CooldownViewerBuffIconItemMixin.OnActiveStateChanged then
        hooksecurefunc(CooldownViewerBuffIconItemMixin, "OnActiveStateChanged", function(frame)
            if not BuffIconCooldownViewer then return end
            if not IsBuffViewerIcon(frame) then return end
            Layout.ProvisionalPlaceBuffFrame(frame)
            RequestBuffViewerRefresh()
        end)
    end

    -- 锁定 BuffIconCooldownViewer 编辑模式
    LockBuffViewerEditMode()
end

local function RegisterTrackedBarsHooks()
    if BuffBarCooldownViewer then
        hooksecurefunc(BuffBarCooldownViewer, "RefreshLayout", function()
            HookTrackedBarChildren()
            Layout:RefreshTrackedBars()
        end)
    end
end

------------------------------------------------------
-- TTS 自定义播报 hook
--
--   不能直接替换 CooldownViewerAlert_PlayAlert：
--   直接赋值会把该全局函数标记为"tainted"，
--   导致 Blizzard 后续代码（TriggerAvailableAlert → RefreshData → ...）
--   在访问 secret value（wasOnGCDLookup 等）时报错。
--
--   采用hooksecurefunc 后置钩子：
--   原函数在安全上下文中运行完毕后，钩子才执行（addon 上下文），
--   不会污染 Blizzard 调用栈。
--   由于 TTS 是 QueuedLocalPlayback（入队异步），钩子在同一 Lua tick
--   内调用 StopSpeakingText() 可在实际播放前取消原始语音，
--   再用 SpeakText() 改为自定义文字朗读。
------------------------------------------------------

local function SetupTTSHook()
    if type(CooldownViewerAlert_PlayAlert) ~= "function" then return end

    local function ResolveEntry(entry)
        if type(entry) ~= "table" or not entry.mode then return nil end
        return entry.mode,
               entry.text  or "",
               entry.sound or "",
               entry.soundChannel or "Master"
    end

    hooksecurefunc("CooldownViewerAlert_PlayAlert", function(cooldownItem, _spellName, alert)
        local aliases = ns.db and ns.db.ttsAliases
        if not aliases then return end

        -- 仅处理 TTS 播报（payload == CooldownViewerSound.TextToSpeech）
        if not (CooldownViewerAlert_GetPayload and CooldownViewerSound) then return end
        if CooldownViewerAlert_GetPayload(alert) ~= CooldownViewerSound.TextToSpeech then return end
        -- 从 cooldownInfo.spellID 读取注册时的基础技能 ID（固定整数，非 secret）。
        local info = cooldownItem and cooldownItem.cooldownInfo
        if not info then return end

        local spellID
        pcall(function() spellID = info.spellID end)
        if not spellID then return end

        -- 同时检查 overrideSpellID，兼容天赋替换技能的别名
        local entry = aliases[spellID]
        if not entry then
            pcall(function()
                if info.overrideSpellID then
                    entry = aliases[info.overrideSpellID]
                end
            end)
        end
        if not entry then return end

        local mode, text, sound, channel = ResolveEntry(entry)
        if not mode then return end

        -- 取消原始 TTS，防止与自定义播报重叠
        C_VoiceChat.StopSpeakingText()

        if mode == "text" and text ~= "" then
            TextToSpeechFrame_PlayCooldownAlertMessage(alert, text, false)
        elseif mode == "sound" and sound ~= "" then
            PlaySoundFile(sound, channel or "Master")
        end
    end)
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

    EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", function()
        RequestBuffViewerRefresh()
        if mods.trackedBars then
            RequestTrackedBarsRefresh()
        end
    end)

    EventRegistry:RegisterCallback("EditMode.Enter", function()
        CaptureViewerPointToManagedCfg()
        ShowTrackedBarsProxy()
        RequestRefreshAll(0)
        -- 延迟同步 Selection overlay 尺寸，确保 RefreshAll 设置 viewer 尺寸后生效
        C_Timer.After(0.1, SyncBuffViewerSelectionSize)
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
        Layout:InitBuffGroups()
    end

    if mods.trackedBars then
        RegisterTrackedBarsHooks()
    end

    -- TTS hook：等待 Blizzard_CooldownViewer 加载后执行（仅在 TTS 模块开启时）
    if mods.tts then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_CooldownViewer", function()
            SetupTTSHook()
        end)
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

                -- 强制刷新 Masque 皮肤，解决 reload 后部分按钮未正确应用皮肤的问题
                if ns.Masque and ns.Masque:IsActive() then
                    ns.Masque:ReSkin()
                end
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
        eventHandlers["LOADING_SCREEN_DISABLED"] = function()
            RequestRefreshAll(0)
            SetupBuffViewerHooks()
            Layout.EnableBuffCentering()
        end

        eventHandlers["UI_SCALE_CHANGED"] = function()
            RequestRefreshAll(0)
        end

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
            if mods.monitorBars then MB:OnSkyridingChanged() end
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
            if mods.monitorBars then MB:OnAuraUpdate(unit) end
            if unit == "player" and mods.trackedBars then
                RequestTrackedBarsRefresh()
            end
        end
    end

    if mods.monitorBars then
        eventHandlers["SPELL_UPDATE_CHARGES"] = function()
            MB:OnChargeUpdate()
        end

        eventHandlers["PLAYER_TARGET_CHANGED"] = function()
            MB:OnTargetChanged()
        end

        -- 御龙术专用事件（与 Glider 插件相同：UPDATE_BONUS_ACTIONBAR、
        -- ACTIONBAR_UPDATE_STATE、PLAYER_CAN_GLIDE_CHANGED、PLAYER_IS_GLIDING_CHANGED）
        -- UPDATE_BONUS_ACTIONBAR 若 cdmBeautify 未开，需单独注册
        if not mods.cdmBeautify then
            eventHandlers["UPDATE_BONUS_ACTIONBAR"] = function() MB:OnSkyridingChanged() end
        end
        eventHandlers["ACTIONBAR_UPDATE_STATE"]    = function() MB:OnSkyridingChanged() end
        eventHandlers["PLAYER_CAN_GLIDE_CHANGED"]  = function() MB:OnSkyridingChanged() end
        eventHandlers["PLAYER_IS_GLIDING_CHANGED"] = function() MB:OnSkyridingChanged() end
    end

    -- PLAYER_REGEN_ENABLED/DISABLED：服务 MonitorBars + 技能可用高亮（combatOnly）
    if mods.monitorBars or mods.cdmBeautify then
        eventHandlers["PLAYER_REGEN_ENABLED"] = function()
            if mods.monitorBars then MB:OnCombatLeave() end
            if mods.cdmBeautify then RequestRefreshAll(0) end
        end

        eventHandlers["PLAYER_REGEN_DISABLED"] = function()
            if mods.monitorBars then MB:OnCombatEnter() end
            if mods.cdmBeautify then RequestRefreshAll(0) end
        end
    end

    -- SPELL_UPDATE_COOLDOWN：服务 MonitorBars、ItemMonitor、技能可用高亮
    if mods.monitorBars or (mods.itemMonitor and IM) or mods.cdmBeautify then
        eventHandlers["SPELL_UPDATE_COOLDOWN"] = function()
            if mods.monitorBars then MB:OnCooldownUpdate() end
            if mods.itemMonitor and IM then IM:UpdateAllCooldowns() end
            if mods.cdmBeautify then RequestRefreshAll(0) end
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

    if ns.InitMinimapButton then
        ns:InitMinimapButton()
    end

    if ns.Visibility then
        ns.Visibility:Initialize()
    end

    print("|cff00ccff[CDFlow]|r " .. format(L.loaded, L.slashHelp))

    initFrame:UnregisterAllEvents()
end)
