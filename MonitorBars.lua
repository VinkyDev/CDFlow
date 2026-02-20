local _, ns = ...

-- MonitorBars 核心：堆叠条/充能条、CDM 扫描、秘密值检测、事件响应

local MB = {}
ns.MonitorBars = MB

local LSM = LibStub("LibSharedMedia-3.0", true)
local DEFAULT_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local SEGMENT_GAP = 1
local UPDATE_INTERVAL = 0.1

local spellToCooldownID = {}   -- spellID → cooldownID（战斗外扫描）
local cooldownIDToFrame = {}  -- cooldownID → CDM 帧缓存
local activeFrames = {}       -- barID → barFrame
ns.cdmSuppressedCooldownIDs = {}  -- Layout.lua 消费：需从 CDM 隐藏的 cooldownID
local elapsed = 0
local inCombat = false

local function HasAuraInstanceID(value)
    if value == nil then return false end
    if issecretvalue and issecretvalue(value) then return true end
    if type(value) == "number" and value == 0 then return false end
    return true
end

local function ResolveFontPath(fontName)
    if not fontName or fontName == "" then return DEFAULT_FONT end
    if LSM and LSM.Fetch then
        local path = LSM:Fetch("font", fontName)
        if path then return path end
    end
    return DEFAULT_FONT
end

local function ConfigureStatusBar(bar)
    local tex = bar:GetStatusBarTexture()
    if tex then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
end

local CDM_VIEWERS = {
    "BuffIconCooldownViewer",
    "BuffBarCooldownViewer",
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
}

local function GetCooldownIDFromFrame(frame)
    local cdID = frame.cooldownID
    if not cdID and frame.cooldownInfo then
        cdID = frame.cooldownInfo.cooldownID
    end
    return cdID
end

local function ResolveSpellID(info)
    if not info then return nil end
    local base = info.spellID or 0
    local linked = info.linkedSpellIDs and info.linkedSpellIDs[1]
    return linked or info.overrideSpellID or (base > 0 and base) or nil
end

local function MapSpellInfo(info, cdID, forceOverwrite)
    if not info then return end
    local sid = ResolveSpellID(info)
    if sid and sid > 0 then
        if forceOverwrite or not spellToCooldownID[sid] then
            spellToCooldownID[sid] = cdID
        end
    end
    if info.linkedSpellIDs then
        for _, lid in ipairs(info.linkedSpellIDs) do
            if lid and lid > 0 and (forceOverwrite or not spellToCooldownID[lid]) then
                spellToCooldownID[lid] = cdID
            end
        end
    end
    if info.spellID and info.spellID > 0 then
        if forceOverwrite or not spellToCooldownID[info.spellID] then
            spellToCooldownID[info.spellID] = cdID
        end
    end
end

function MB:ScanCDMViewers()
    if InCombatLockdown() then return end

    wipe(spellToCooldownID)
    wipe(cooldownIDToFrame)

    -- 阶段 1：API 扫描 aura 类 category（TrackedBuff=2, TrackedBar=3）
    if C_CooldownViewer.GetCooldownViewerCategorySet then
        for _, cat in ipairs({ 2, 3 }) do
            local ids = C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
            if ids then
                for _, cdID in ipairs(ids) do
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                    MapSpellInfo(info, cdID, true)
                end
            end
        end
    end

    -- 阶段 2：扫描查看器子帧，建立 cooldownID → frame
    for _, viewerName in ipairs(CDM_VIEWERS) do
        local viewer = _G[viewerName]
        if viewer then
            local isAuraViewer = (viewerName == "BuffIconCooldownViewer" or viewerName == "BuffBarCooldownViewer")
            for _, child in ipairs({ viewer:GetChildren() }) do
                local cdID = GetCooldownIDFromFrame(child)
                if cdID then
                    cooldownIDToFrame[cdID] = child
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                    MapSpellInfo(info, cdID, isAuraViewer)  -- aura 查看器优先覆盖
                end
            end
        end
    end

    self:PostScanHook()
end

local function FindCDMFrame(cooldownID)
    if not cooldownID then return nil end
    local cached = cooldownIDToFrame[cooldownID]
    if cached then return cached end

    for _, viewerName in ipairs(CDM_VIEWERS) do
        local viewer = _G[viewerName]
        if viewer then
            for _, child in ipairs({ viewer:GetChildren() }) do
                local cdID = GetCooldownIDFromFrame(child)
                if cdID == cooldownID then
                    cooldownIDToFrame[cdID] = child
                    return child
                end
            end
        end
    end
    return nil
end

local hookedFrames = {}
local frameToBarIDs = {}
local UpdateStackBar

local function OnCDMFrameChanged(frame)
    local ids = frameToBarIDs[frame]
    if not ids then return end
    for _, id in ipairs(ids) do
        local f = activeFrames[id]
        if f and f._cfg and f._cfg.barType == "stack" then
            UpdateStackBar(f)
        end
    end
end

local function HookCDMFrame(frame, barID)
    if not frame then return end
    if not hookedFrames[frame] then
        hookedFrames[frame] = { barIDs = {} }
        frameToBarIDs[frame] = {}
        if frame.RefreshData then
            hooksecurefunc(frame, "RefreshData", OnCDMFrameChanged)
        end
        if frame.RefreshApplications then
            hooksecurefunc(frame, "RefreshApplications", OnCDMFrameChanged)
        end
        if frame.SetAuraInstanceInfo then
            hooksecurefunc(frame, "SetAuraInstanceInfo", OnCDMFrameChanged)
        end
    end
    if not hookedFrames[frame].barIDs[barID] then
        hookedFrames[frame].barIDs[barID] = true
        table.insert(frameToBarIDs[frame], barID)
    end
end

local function ClearAllHookRegistrations()
    for frame in pairs(hookedFrames) do
        hookedFrames[frame].barIDs = {}
        frameToBarIDs[frame] = {}
    end
end

local function AutoHookStackBars()
    for _, f in pairs(activeFrames) do
        local cfg = f._cfg
        if cfg and cfg.barType == "stack" and cfg.spellID > 0 then
            local cdID = spellToCooldownID[cfg.spellID]
            if cdID then
                local cdmFrame = FindCDMFrame(cdID)
                if cdmFrame then
                    HookCDMFrame(cdmFrame, f._barID)
                    f._cdmFrame = cdmFrame
                end
            end
        end
    end
end

function MB:PostScanHook()
    ClearAllHookRegistrations()
    AutoHookStackBars()
end

function MB:GetSpellCatalog()
    local cooldowns, auras = {}, {}
    local seen = {}

    local AURA_VIEWERS = { BuffIconCooldownViewer = true, BuffBarCooldownViewer = true }

    for _, viewerName in ipairs(CDM_VIEWERS) do
        local viewer = _G[viewerName]
        if viewer then
            local isAura = AURA_VIEWERS[viewerName]
            for _, child in ipairs({ viewer:GetChildren() }) do
                local cdID = GetCooldownIDFromFrame(child)
                if cdID then
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                    local spellID = ResolveSpellID(info)
                    if spellID and spellID > 0 and not seen[spellID] then
                        seen[spellID] = true
                        local name = C_Spell.GetSpellName(spellID)
                        local icon = C_Spell.GetSpellTexture(spellID)
                        if name then
                            local unit = child.auraDataUnit or "player"
                            local entry = { spellID = spellID, name = name, icon = icon, unit = unit }
                            if isAura then
                                auras[#auras + 1] = entry
                            else
                                cooldowns[#cooldowns + 1] = entry
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(cooldowns, function(a, b) return a.name < b.name end)
    table.sort(auras, function(a, b) return a.name < b.name end)
    return cooldowns, auras
end

-- 秘密值检测：通过 StatusBar SetValue 配合 issecretvalue 解析层数/充能
local function GetArcDetector(barFrame, threshold)
    barFrame._arcDetectors = barFrame._arcDetectors or {}
    local det = barFrame._arcDetectors[threshold]
    if det then return det end

    det = CreateFrame("StatusBar", nil, barFrame)
    det:SetSize(1, 1)
    det:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", 0, 0)
    det:SetAlpha(0)
    det:SetStatusBarTexture(BAR_TEXTURE)
    det:SetMinMaxValues(threshold - 1, threshold)
    ConfigureStatusBar(det)
    barFrame._arcDetectors[threshold] = det
    return det
end

local function FeedArcDetectors(barFrame, secretValue, maxVal)
    for i = 1, maxVal do
        GetArcDetector(barFrame, i):SetValue(secretValue)
    end
end

local function GetExactCount(barFrame, maxVal)
    if not barFrame._arcDetectors then return 0 end
    local count = 0
    for i = 1, maxVal do
        local det = barFrame._arcDetectors[i]
        if det and det:GetStatusBarTexture():IsShown() then
            count = i
        end
    end
    return count
end

local function CreateBorder(parent, cfg)
    local size = cfg.borderSize or 1
    if size <= 0 then return end
    if not parent._mbBorder then
        parent._mbBorder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    end
    local border = parent._mbBorder
    border:SetPoint("TOPLEFT", parent, "TOPLEFT", -size, size)
    border:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", size, -size)
    border:SetBackdrop({
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = size,
    })
    local c = cfg.borderColor or { 0, 0, 0, 1 }
    border:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
    border:SetFrameLevel(parent:GetFrameLevel() + 2)
    border:Show()
end

local function CreateSegments(barFrame, count, cfg)
    barFrame._segments = barFrame._segments or {}
    barFrame._segBGs = barFrame._segBGs or {}

    for _, seg in ipairs(barFrame._segments) do
        seg:Hide()
    end
    for _, bg in ipairs(barFrame._segBGs) do
        bg:Hide()
    end
    wipe(barFrame._segments)
    wipe(barFrame._segBGs)

    if count < 1 then return end

    local container = barFrame._segContainer
    local totalW = container:GetWidth()
    local totalH = container:GetHeight()
    local segW = (totalW - (count - 1) * SEGMENT_GAP) / count
    local barColor = cfg.barColor or { 0.2, 0.8, 0.2, 1 }
    local bgColor = cfg.bgColor or { 0.1, 0.1, 0.1, 0.6 }
    local texPath = BAR_TEXTURE
    if LSM and LSM.Fetch and cfg.barTexture then
        texPath = LSM:Fetch("statusbar", cfg.barTexture) or BAR_TEXTURE
    end

    for i = 1, count do
        local xOff = (i - 1) * (segW + SEGMENT_GAP)

        local bg = container:CreateTexture(nil, "BACKGROUND")
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", container, "TOPLEFT", xOff, 0)
        bg:SetSize(segW, totalH)
        bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
        bg:Show()
        barFrame._segBGs[i] = bg

        local bar = CreateFrame("StatusBar", nil, container)
        bar:SetPoint("TOPLEFT", container, "TOPLEFT", xOff, 0)
        bar:SetSize(segW, totalH)
        bar:SetStatusBarTexture(texPath)
        bar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4])
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar:SetFrameLevel(container:GetFrameLevel() + 1)
        ConfigureStatusBar(bar)

        barFrame._segments[i] = bar
    end
end

function MB:CreateBarFrame(barCfg)
    local id = barCfg.id
    if activeFrames[id] then return activeFrames[id] end

    local f = CreateFrame("Frame", "CDFlowMonitorBar" .. id, UIParent, "BackdropTemplate")
    f:SetSize(barCfg.width, barCfg.height)
    f:SetPoint("CENTER", UIParent, "CENTER", barCfg.posX, barCfg.posY)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(10)
    f:SetClampedToScreen(true)
    f._barID = id

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    local bgc = barCfg.bgColor or { 0.1, 0.1, 0.1, 0.6 }
    f.bg:SetColorTexture(bgc[1], bgc[2], bgc[3], bgc[4])

    local iconSize = barCfg.height
    f._icon = f:CreateTexture(nil, "ARTWORK")
    f._icon:SetSize(iconSize, iconSize)
    f._icon:SetPoint("LEFT", f, "LEFT", 0, 0)
    f._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local showIcon = barCfg.showIcon ~= false
    local segOffset = showIcon and (iconSize + 2) or 0
    f._segContainer = CreateFrame("Frame", nil, f)
    f._segContainer:SetPoint("TOPLEFT", f, "TOPLEFT", segOffset, 0)
    f._segContainer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

    f._textHolder = CreateFrame("Frame", nil, f)
    f._textHolder:SetAllPoints(f._segContainer)
    f._textHolder:SetFrameLevel(f:GetFrameLevel() + 20)

    f._text = f._textHolder:CreateFontString(nil, "OVERLAY")
    local fontPath = ResolveFontPath(barCfg.fontName)
    f._text:SetFont(fontPath, barCfg.fontSize or 12, barCfg.outline or "OUTLINE")
    local align = barCfg.textAlign or "RIGHT"
    local txOff = barCfg.textOffsetX or -4
    local tyOff = barCfg.textOffsetY or 0
    f._text:SetPoint(align, f._textHolder, align, txOff, tyOff)
    f._text:SetTextColor(1, 1, 1, 1)
    f._text:SetJustifyH(align)

    CreateBorder(f, barCfg)

    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if ns.db.monitorBars.locked then return end
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local _, _, _, x, y = self:GetPoint(1)
        barCfg.posX = x or 0
        barCfg.posY = y or 0
    end)

    f._cfg = barCfg
    f._cooldownID = nil
    f._cdmFrame = nil
    f._cachedMaxCharges = 0
    f._cachedChargeDuration = 0
    f._needsChargeRefresh = true
    f._cachedChargeInfo = nil
    f._needsDurationRefresh = true
    f._cachedChargeDurObj = nil
    f._lastRechargingSlot = nil
    f._trackedAuraInstanceID = nil
    f._lastKnownActive = false
    f._lastKnownStacks = 0
    f._nilCount = 0

    activeFrames[id] = f
    return f
end

function MB:ApplyStyle(barFrame)
    local cfg = barFrame._cfg
    if not cfg then return end

    barFrame:SetSize(cfg.width, cfg.height)

    local bgc = cfg.bgColor or { 0.1, 0.1, 0.1, 0.6 }
    barFrame.bg:SetColorTexture(bgc[1], bgc[2], bgc[3], bgc[4])

    local iconSize = cfg.height
    barFrame._icon:SetSize(iconSize, iconSize)
    local showIcon = cfg.showIcon ~= false
    barFrame._icon:SetShown(showIcon)

    local segOffset = showIcon and (iconSize + 2) or 0
    barFrame._segContainer:ClearAllPoints()
    barFrame._segContainer:SetPoint("TOPLEFT", barFrame, "TOPLEFT", segOffset, 0)
    barFrame._segContainer:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", 0, 0)

    local count = (cfg.barType == "charge") and (cfg.maxCharges > 0 and cfg.maxCharges or barFrame._cachedMaxCharges) or cfg.maxStacks
    if count > 0 then
        C_Timer.After(0, function()
            if barFrame._segContainer then
                CreateSegments(barFrame, count, cfg)
            end
        end)
    end

    local fontPath = ResolveFontPath(cfg.fontName)
    barFrame._text:SetFont(fontPath, cfg.fontSize or 12, cfg.outline or "OUTLINE")
    barFrame._text:SetShown(cfg.showText ~= false)
    local align = cfg.textAlign or "RIGHT"
    barFrame._text:ClearAllPoints()
    barFrame._text:SetPoint(align, barFrame._textHolder, align, cfg.textOffsetX or -4, cfg.textOffsetY or 0)
    barFrame._text:SetJustifyH(align)
    CreateBorder(barFrame, cfg)

    if cfg.spellID and cfg.spellID > 0 then
        local tex = C_Spell.GetSpellTexture(cfg.spellID)
        if tex then barFrame._icon:SetTexture(tex) end
    end
end

local function ApplySegmentColors(barFrame, currentCount)
    local cfg = barFrame._cfg
    if not cfg then return end
    local segs = barFrame._segments
    if not segs then return end

    local threshold = cfg.colorThreshold or 0
    local useThreshold = threshold > 0 and type(currentCount) == "number" and currentCount >= threshold
    local c = useThreshold and (cfg.thresholdColor or { 1, 0.5, 0, 1 }) or (cfg.barColor or { 0.2, 0.8, 0.2, 1 })

    for _, seg in ipairs(segs) do
        seg:SetStatusBarColor(c[1], c[2], c[3], c[4])
    end
end

UpdateStackBar = function(barFrame)
    local cfg = barFrame._cfg
    if not cfg or cfg.barType ~= "stack" then return end

    local spellID = cfg.spellID
    if not spellID or spellID <= 0 then return end

    local stacks = 0
    local auraActive = false
    local cooldownID = spellToCooldownID[spellID]
    barFrame._cooldownID = cooldownID

    if cooldownID then
        local cdmFrame = FindCDMFrame(cooldownID)
        if cdmFrame then
            HookCDMFrame(cdmFrame, barFrame._barID)
            barFrame._cdmFrame = cdmFrame

            if HasAuraInstanceID(cdmFrame.auraInstanceID) then
                auraActive = true
                local unit = cdmFrame.auraDataUnit or cfg.unit or "player"
                local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, cdmFrame.auraInstanceID)
                if not auraData then
                    local other = (unit == "player") and "target" or "player"
                    auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(other, cdmFrame.auraInstanceID)
                end
                if auraData then
                    stacks = auraData.applications or 0
                end
                barFrame._trackedAuraInstanceID = cdmFrame.auraInstanceID
            end
        end
    end

    if not auraActive and HasAuraInstanceID(barFrame._trackedAuraInstanceID) then
        local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID("player", barFrame._trackedAuraInstanceID)
        if not auraData then
            auraData = C_UnitAuras.GetAuraDataByAuraInstanceID("target", barFrame._trackedAuraInstanceID)
        end
        if auraData then
            auraActive = true
            stacks = auraData.applications or 0
        end
    end

    if not auraActive then
        if barFrame._lastKnownActive then
            stacks = barFrame._lastKnownStacks or 0
            barFrame._nilCount = (barFrame._nilCount or 0) + 1
            if barFrame._nilCount > 5 then
                barFrame._lastKnownActive = false
                barFrame._lastKnownStacks = 0
                barFrame._trackedAuraInstanceID = nil
                stacks = 0
            end
        end
    else
        barFrame._nilCount = 0
    end

    local isSecret = issecretvalue and issecretvalue(stacks)

    local maxStacks = cfg.maxStacks or 5
    local segs = barFrame._segments
    if segs then
        if isSecret then
            FeedArcDetectors(barFrame, stacks, maxStacks)
            local exact = GetExactCount(barFrame, maxStacks)
            for j = 1, #segs do
                segs[j]:SetValue(j <= exact and 1 or 0)
            end
            stacks = exact
        else
            for i = 1, #segs do
                segs[i]:SetValue(i <= stacks and 1 or 0)
            end
        end
    end

    if auraActive then
        barFrame._lastKnownActive = true
        barFrame._lastKnownStacks = (not isSecret) and stacks or (barFrame._lastKnownStacks or 0)
    end

    ApplySegmentColors(barFrame, stacks)

    if cfg.showText ~= false and barFrame._text then
        barFrame._text:SetText(tostring(stacks))
    end
end

local function UpdateChargeBar(barFrame)
    local cfg = barFrame._cfg
    if not cfg or cfg.barType ~= "charge" then return end

    local spellID = cfg.spellID
    if not spellID or spellID <= 0 then return end

    local chargeJustRefreshed = false
    if barFrame._needsChargeRefresh then
        barFrame._cachedChargeInfo = C_Spell.GetSpellCharges(spellID)
        barFrame._needsChargeRefresh = false
        chargeJustRefreshed = true
    end

    local chargeInfo = barFrame._cachedChargeInfo
    if not chargeInfo then return end

    local maxCharges = cfg.maxCharges
    if maxCharges <= 0 then
        if chargeInfo.maxCharges then
            if not issecretvalue or not issecretvalue(chargeInfo.maxCharges) then
                barFrame._cachedMaxCharges = chargeInfo.maxCharges
            end
        end
        maxCharges = barFrame._cachedMaxCharges
    end
    if maxCharges <= 0 then maxCharges = 2 end

    local segs = barFrame._segments
    if not segs or #segs ~= maxCharges then
        CreateSegments(barFrame, maxCharges, cfg)
        segs = barFrame._segments
    end
    if not segs then return end

    local currentCharges = chargeInfo.currentCharges
    local isSecret = issecretvalue and issecretvalue(currentCharges)
    local exactCharges = currentCharges

    if isSecret then
        FeedArcDetectors(barFrame, currentCharges, maxCharges)
        exactCharges = GetExactCount(barFrame, maxCharges)
    end

    local needApplyTimer = false
    if barFrame._needsDurationRefresh then
        if isSecret and chargeJustRefreshed then
            -- 秘密值需一帧渲染后才能解析，下帧再刷新 duration
        else
            barFrame._cachedChargeDurObj = C_Spell.GetSpellChargeDuration(spellID)
            barFrame._needsDurationRefresh = false
            needApplyTimer = true
        end
    end

    local chargeDurObj = barFrame._cachedChargeDurObj
    local rechargingSlot = (type(exactCharges) == "number" and exactCharges < maxCharges) and (exactCharges + 1) or nil

    if barFrame._lastRechargingSlot ~= rechargingSlot then
        needApplyTimer = true
        barFrame._lastRechargingSlot = rechargingSlot
    end

    local interpolation = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut or 0
    local direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0

    for i = 1, maxCharges do
        local seg = segs[i]
        if not seg then break end

        if type(exactCharges) == "number" then
            if i <= exactCharges then
                seg:SetMinMaxValues(0, 1)
                seg:SetValue(1)
            elseif rechargingSlot and i == rechargingSlot then
                if needApplyTimer then
                    if chargeDurObj and seg.SetTimerDuration then
                        seg:SetMinMaxValues(0, 1)
                        seg:SetTimerDuration(chargeDurObj, interpolation, direction)
                        if seg.SetToTargetValue then
                            seg:SetToTargetValue()
                        end
                    else
                        local cd = chargeInfo.cooldownDuration or 0
                        local start = chargeInfo.cooldownStartTime or 0
                        if cd > 0 and start > 0 then
                            seg:SetMinMaxValues(0, 1)
                            local now = GetTime()
                            seg:SetValue(math.min(math.max((now - start) / cd, 0), 1))
                        else
                            seg:SetMinMaxValues(0, 1)
                            seg:SetValue(0)
                        end
                    end
                end
            else
                seg:SetMinMaxValues(0, 1)
                seg:SetValue(0)
            end
        end
    end

    ApplySegmentColors(barFrame, exactCharges)

    if cfg.showText ~= false and barFrame._text then
        if type(exactCharges) == "number" and exactCharges >= maxCharges then
            barFrame._text:SetText("")
        elseif chargeDurObj then
            local remaining = chargeDurObj:GetRemainingDuration()
            local ok, result = pcall(function()
                local num = tonumber(remaining)
                if num then
                    return string.format("%.1f", num)
                end
                return remaining
            end)
            if ok and result then
                barFrame._text:SetText(result)
            else
                barFrame._text:SetText(remaining or "")
            end
        else
            barFrame._text:SetText("")
        end
    end
end

local function UpdateAllBars()
    local bars = ns.db and ns.db.monitorBars and ns.db.monitorBars.bars
    if not bars then return end

    for _, barCfg in ipairs(bars) do
        local f = activeFrames[barCfg.id]
        if f and barCfg.enabled and barCfg.spellID > 0 then
            if barCfg.barType == "stack" then
                UpdateStackBar(f)
            elseif barCfg.barType == "charge" then
                UpdateChargeBar(f)
            end
        end
    end
end

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < UPDATE_INTERVAL then return end
    elapsed = 0
    UpdateAllBars()
end)
updateFrame:Hide()

local function IsBarVisibleForSpec(barCfg)
    local specs = barCfg.specs
    if not specs or #specs == 0 then return true end
    local cur = GetSpecialization() or 1
    for _, s in ipairs(specs) do
        if s == cur then return true end
    end
    return false
end

local function RebuildCDMSuppressedSet()
    local suppressed = ns.cdmSuppressedCooldownIDs
    wipe(suppressed)
    local bars = ns.db and ns.db.monitorBars and ns.db.monitorBars.bars
    if not bars then return end
    for _, barCfg in ipairs(bars) do
        if barCfg.enabled and barCfg.hideFromCDM and barCfg.spellID > 0 then
            local cdID = spellToCooldownID[barCfg.spellID]
            if cdID then
                suppressed[cdID] = true
            end
        end
    end
end

function MB:InitAllBars()
    local bars = ns.db and ns.db.monitorBars and ns.db.monitorBars.bars
    if not bars then return end

    RebuildCDMSuppressedSet()

    for _, barCfg in ipairs(bars) do
        if barCfg.enabled and barCfg.spellID > 0 and IsBarVisibleForSpec(barCfg) then
            local f = self:CreateBarFrame(barCfg)
            self:ApplyStyle(f)

            local count = (barCfg.barType == "charge")
                and (barCfg.maxCharges > 0 and barCfg.maxCharges or 2)
                or barCfg.maxStacks
            C_Timer.After(0, function()
                if f._segContainer and f._segContainer:GetWidth() > 0 then
                    CreateSegments(f, count, barCfg)
                end
            end)

            f:Show()
        end
    end

    updateFrame:Show()
end

function MB:DestroyBar(barID)
    local f = activeFrames[barID]
    if f then
        f:Hide()
        f:SetParent(nil)
        activeFrames[barID] = nil
    end
end

function MB:DestroyAllBars()
    for id, f in pairs(activeFrames) do
        f:Hide()
        f:SetParent(nil)
    end
    wipe(activeFrames)
    wipe(ns.cdmSuppressedCooldownIDs)
    updateFrame:Hide()
end

function MB:RebuildAllBars()
    self:DestroyAllBars()
    self:InitAllBars()
end

function MB:OnCombatEnter()
    inCombat = true
end

function MB:OnCombatLeave()
    inCombat = false
    self:ScanCDMViewers()
    for _, f in pairs(activeFrames) do
        f._needsChargeRefresh = true
        f._nilCount = 0
        if f._cfg and f._cfg.barType == "charge" and f._cfg.spellID > 0 then
            local chargeInfo = C_Spell.GetSpellCharges(f._cfg.spellID)
            if chargeInfo and chargeInfo.maxCharges then
                if not issecretvalue or not issecretvalue(chargeInfo.maxCharges) then
                    f._cachedMaxCharges = chargeInfo.maxCharges
                end
            end
        end
    end
end

function MB:OnChargeUpdate()
    for _, f in pairs(activeFrames) do
        f._needsChargeRefresh = true
        f._needsDurationRefresh = true
    end
end

function MB:OnCooldownUpdate()
    for _, f in pairs(activeFrames) do
        if f._cfg and f._cfg.barType == "charge" then
            f._needsDurationRefresh = true
        end
    end
end

function MB:OnAuraUpdate()
end

function MB:OnTargetChanged()
    for _, f in pairs(activeFrames) do
        if f._cfg and f._cfg.unit == "target" then
            f._trackedAuraInstanceID = nil
        end
    end
end

function MB:SetLocked(locked)
    ns.db.monitorBars.locked = locked
    for _, f in pairs(activeFrames) do
        f:EnableMouse(not locked)
    end
end

function MB:GetActiveFrame(barID)
    return activeFrames[barID]
end
