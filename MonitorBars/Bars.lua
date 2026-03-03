-- 监控条创建、样式应用、更新逻辑、事件处理
local _, ns = ...

local MB = ns.MonitorBars
local LSM = LibStub("LibSharedMedia-3.0", true)
local DEFAULT_FONT = ns._mbConst.DEFAULT_FONT
local BAR_TEXTURE  = ns._mbConst.BAR_TEXTURE
local SEGMENT_GAP  = ns._mbConst.SEGMENT_GAP
local UPDATE_INTERVAL = ns._mbConst.UPDATE_INTERVAL

local ResolveFontPath    = MB.ResolveFontPath
local ConfigureStatusBar = MB.ConfigureStatusBar
local HasAuraInstanceID  = MB.HasAuraInstanceID
local FindCDMFrame       = MB.FindCDMFrame
local spellToCooldownID  = MB._spellToCooldownID
local cooldownIDToFrame  = MB._cooldownIDToFrame
local PLAYER_CLASS_TAG   = select(2, UnitClass("player"))

local activeFrames = {}
local elapsed = 0
local inCombat = false
local frameTick = 0

-- 分段条波形填充速度：每秒填充的格数（每格约 83ms）
local STACK_FILL_SPEED = 12

function MB.rounded(num, idp)
    if not num then return num end
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
end

function MB.getPixelPerfectScale(customUIScale)
    local screenHeight = select(2, GetPhysicalScreenSize())
    local scale = customUIScale or UIParent:GetEffectiveScale()
    if scale == 0 or screenHeight == 0 then return 1 end
    return 768 / screenHeight / scale
end

function MB.getNearestPixel(value, customUIScale)
    if value == 0 then return 0 end
    local ppScale = MB.getPixelPerfectScale(customUIScale)
    return MB.rounded(value / ppScale) * ppScale
end

MB.MASK_AND_BORDER_STYLES = {
    ["1px"] = {
        type = "fixed",
        thickness = 1,
    },
    ["Thin"] = {
        type = "fixed",
        thickness = 2,
    },
    ["Medium"] = {
        type = "fixed",
        thickness = 3,
    },
    ["Thick"] = {
        type = "fixed",
        thickness = 5,
    },
    ["None"] = {},
}

-- 御龙术（Skyriding）检测
-- 主判断：御龙术动作条占据 BonusBar slot 11 / offset 5
-- 次判断：canGlide == true 说明玩家骑乘了御龙坐骑（不再要求 powerBar 非零，
--         因为地面停止时 UnitPowerBarID 可能为 0）
local function IsSkyriding()
    if GetBonusBarIndex() == 11 and GetBonusBarOffset() == 5 then
        return true
    end
    local _, canGlide = C_PlayerInfo.GetGlidingInfo()
    return canGlide == true
end

------------------------------------------------------
-- CDM 帧 Hook 管理
------------------------------------------------------

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

------------------------------------------------------
-- 秘密值检测（Arc Detectors）
------------------------------------------------------

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

local function GetOrCreateShadowCooldown(barFrame)
    if barFrame._shadowCooldown then return barFrame._shadowCooldown end
    local cd = CreateFrame("Cooldown", nil, barFrame, "CooldownFrameTemplate")
    cd:SetAllPoints(barFrame)
    cd:SetDrawSwipe(false)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    cd:SetHideCountdownNumbers(true)
    cd:SetAlpha(0)
    barFrame._shadowCooldown = cd
    return cd
end

------------------------------------------------------
-- 段条 / 边框
------------------------------------------------------

function MB.ApplyMaskAndBorderSettings(barFrame, cfg)
    local styleName = cfg.maskAndBorderStyle or "1px"
    local style = MB.MASK_AND_BORDER_STYLES[styleName] or MB.MASK_AND_BORDER_STYLES["1px"]
    
    local width, height = barFrame:GetSize()
    
    if barFrame._mask then
        barFrame._mask:SetTexture([[Interface\AddOns\CDFlow\Textures\Specials\white.png]])
        barFrame._mask:SetAllPoints(barFrame)
    end

    if style.type == "fixed" then
        if not barFrame._fixedBorders then
            barFrame._fixedBorders = {}
            barFrame._fixedBorders.top    = barFrame._borderFrame:CreateTexture(nil, "OVERLAY")
            barFrame._fixedBorders.bottom = barFrame._borderFrame:CreateTexture(nil, "OVERLAY")
            barFrame._fixedBorders.left   = barFrame._borderFrame:CreateTexture(nil, "OVERLAY")
            barFrame._fixedBorders.right  = barFrame._borderFrame:CreateTexture(nil, "OVERLAY")
        end

        barFrame._border:Hide()
        
        local thickness = (style.thickness or 1) * (cfg.scale or 1)
        local pThickness = MB.getNearestPixel(thickness)
        local borderColor = cfg.borderColor or { 0, 0, 0, 1 }

        for edge, t in pairs(barFrame._fixedBorders) do
            t:ClearAllPoints()
            if edge == "top" then
                t:SetPoint("TOPLEFT", barFrame._borderFrame, "TOPLEFT")
                t:SetPoint("TOPRIGHT", barFrame._borderFrame, "TOPRIGHT")
                t:SetHeight(pThickness)
            elseif edge == "bottom" then
                t:SetPoint("BOTTOMLEFT", barFrame._borderFrame, "BOTTOMLEFT")
                t:SetPoint("BOTTOMRIGHT", barFrame._borderFrame, "BOTTOMRIGHT")
                t:SetHeight(pThickness)
            elseif edge == "left" then
                t:SetPoint("TOPLEFT", barFrame._borderFrame, "TOPLEFT")
                t:SetPoint("BOTTOMLEFT", barFrame._borderFrame, "BOTTOMLEFT")
                t:SetWidth(pThickness)
            elseif edge == "right" then
                t:SetPoint("TOPRIGHT", barFrame._borderFrame, "TOPRIGHT")
                t:SetPoint("BOTTOMRIGHT", barFrame._borderFrame, "BOTTOMRIGHT")
                t:SetWidth(pThickness)
            end
            t:SetColorTexture(borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0, borderColor[4] or 1)
            t:Show()
        end
    elseif style.type == "texture" then
        barFrame._border:Show()
        barFrame._border:SetTexture(style.border)
        barFrame._border:SetAllPoints(barFrame._borderFrame)
        local borderColor = cfg.borderColor or { 0, 0, 0, 1 }
        barFrame._border:SetVertexColor(borderColor[1] or 0, borderColor[2] or 0, borderColor[3] or 0, borderColor[4] or 1)

        if barFrame._fixedBorders then
            for _, t in pairs(barFrame._fixedBorders) do t:Hide() end
        end
    else
        barFrame._border:Hide()
        if barFrame._fixedBorders then
            for _, t in pairs(barFrame._fixedBorders) do t:Hide() end
        end
    end
end

-- 统一监控条层级基线，避免“BACKGROUND”仍因固定高 FrameLevel 覆盖其他 UI
local function GetBaseFrameLevelByStrata(strata)
    if strata == "BACKGROUND" then
        return 0
    end
    return 1
end

local function CreateSegments(barFrame, count, cfg)
    barFrame._segments = barFrame._segments or {}
    barFrame._segBGs = barFrame._segBGs or {}
    barFrame._segBorders = barFrame._segBorders or {}

    for _, seg in ipairs(barFrame._segments) do seg:Hide() end
    for _, bg in ipairs(barFrame._segBGs) do bg:Hide() end
    for _, b in ipairs(barFrame._segBorders) do b:Hide() end
    wipe(barFrame._segments)
    wipe(barFrame._segBGs)
    wipe(barFrame._segBorders)

    if count < 1 then return end

    local container = barFrame._segContainer
    local totalW = container:GetWidth()
    local totalH = container:GetHeight()
    local gap = cfg.segmentGap ~= nil and cfg.segmentGap or SEGMENT_GAP
    local borderSize = cfg.borderSize or 1
    local perSegBorder = (cfg.borderStyle == "segment")
    local segW = (totalW - (count - 1) * gap) / count
    local barColor = cfg.barColor or { 0.2, 0.8, 0.2, 1 }
    local bgColor = cfg.bgColor or { 0.1, 0.1, 0.1, 0.6 }
    local borderColor = cfg.borderColor or { 0, 0, 0, 1 }
    local texPath = BAR_TEXTURE
    if LSM and LSM.Fetch and cfg.barTexture then
        texPath = LSM:Fetch("statusbar", cfg.barTexture) or BAR_TEXTURE
    end

    for i = 1, count do
        local xOff = (i - 1) * (segW + gap)

        local bg = container:CreateTexture(nil, "BACKGROUND")
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", container, "TOPLEFT", xOff, 0)
        bg:SetSize(segW, totalH)
        bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
        if barFrame._mask then bg:AddMaskTexture(barFrame._mask) end
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
        
        if barFrame._mask then
            bar:GetStatusBarTexture():AddMaskTexture(barFrame._mask)
        end

        if perSegBorder and borderSize > 0 then
            local border = CreateFrame("Frame", nil, container, "BackdropTemplate")
            border:SetPoint("TOPLEFT", bar, "TOPLEFT", -borderSize, borderSize)
            border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", borderSize, -borderSize)
            border:SetBackdrop({
                edgeFile = "Interface\\BUTTONS\\WHITE8X8",
                edgeSize = borderSize,
            })
            border:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
            border:SetFrameLevel(bar:GetFrameLevel() + 2)
            border:Show()
            barFrame._segBorders[i] = border
        end

        barFrame._segments[i] = bar
    end

    if perSegBorder then
        if barFrame._mbBorder then barFrame._mbBorder:Hide() end
    else
        MB.ApplyMaskAndBorderSettings(barFrame, cfg)
    end
end

------------------------------------------------------
-- 文字锚点工具
------------------------------------------------------

-- 根据锚点推导 SetJustifyH 水平对齐方向
local function AnchorToJustifyH(anchor)
    if anchor == "LEFT" or anchor == "TOPLEFT" or anchor == "BOTTOMLEFT" then
        return "LEFT"
    elseif anchor == "CENTER" or anchor == "TOP" or anchor == "BOTTOM" then
        return "CENTER"
    else
        return "RIGHT"
    end
end

-- 将用户选择的锚点拆成 point / relativePoint / defaultOffsetX：
-- 顶部系列：文字底边对齐父帧顶边（文字在顶部）
-- 底部系列：文字顶边对齐父帧底边（文字在底部）
-- 其余：自对齐
local ANCHOR_POINT = {
    TOPLEFT     = "BOTTOMLEFT",  TOP     = "BOTTOM",  TOPRIGHT     = "BOTTOMRIGHT",
    LEFT        = "LEFT",        CENTER  = "CENTER",  RIGHT        = "RIGHT",
    BOTTOMLEFT  = "TOPLEFT",     BOTTOM  = "TOP",     BOTTOMRIGHT  = "TOPRIGHT",
}
local ANCHOR_REL = {
    TOPLEFT     = "TOPLEFT",     TOP     = "TOP",     TOPRIGHT     = "TOPRIGHT",
    LEFT        = "LEFT",        CENTER  = "CENTER",  RIGHT        = "RIGHT",
    BOTTOMLEFT  = "BOTTOMLEFT",  BOTTOM  = "BOTTOM",  BOTTOMRIGHT  = "BOTTOMRIGHT",
}

------------------------------------------------------
-- 条创建 / 样式
------------------------------------------------------

function MB:CreateBarFrame(barCfg)
    local id = barCfg.id
    if activeFrames[id] then return activeFrames[id] end

    local f = CreateFrame("Frame", "CDFlowMonitorBar" .. id, UIParent, "BackdropTemplate")
    f:SetSize(barCfg.width, barCfg.height)
    f:SetPoint("CENTER", UIParent, "CENTER", barCfg.posX, barCfg.posY)
    local strata = barCfg.frameStrata or "MEDIUM"
    local baseLevel = GetBaseFrameLevelByStrata(strata)
    f:SetFrameStrata(strata)
    f:SetFrameLevel(baseLevel)
    f:SetClampedToScreen(true)
    f._barID = id

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    local bgc = barCfg.bgColor or { 0.1, 0.1, 0.1, 0.6 }
    f.bg:SetColorTexture(bgc[1], bgc[2], bgc[3], bgc[4])

    -- Mask
    f._mask = f:CreateMaskTexture()
    f._mask:SetAllPoints()
    f._mask:SetTexture([[Interface\AddOns\CDFlow\Textures\Specials\white.png]])
    f.bg:AddMaskTexture(f._mask)

    -- Border Frame
    f._borderFrame = CreateFrame("Frame", nil, f)
    f._borderFrame:SetAllPoints()
    f._borderFrame:SetFrameLevel(f:GetFrameLevel() + 5)
    f._border = f._borderFrame:CreateTexture(nil, "OVERLAY")
    f._border:SetAllPoints()
    f._border:SetBlendMode("BLEND")
    f._border:Hide()

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
    f._segContainer:SetFrameLevel(f:GetFrameLevel() + 1)

    f._textHolder = CreateFrame("Frame", nil, f)
    f._textHolder:SetAllPoints(f._segContainer)
    f._textHolder:SetFrameLevel(f:GetFrameLevel() + 6)

    f._text = f._textHolder:CreateFontString(nil, "OVERLAY")
    local fontPath = ResolveFontPath(barCfg.fontName)
    f._text:SetFont(fontPath, barCfg.fontSize or 12, barCfg.outline or "OUTLINE")
    local anchor = barCfg.textAnchor or barCfg.textAlign or "RIGHT"
    local txOff = barCfg.textOffsetX or -4
    local tyOff = barCfg.textOffsetY or 0
    f._text:SetPoint(ANCHOR_POINT[anchor] or anchor, f._textHolder, ANCHOR_REL[anchor] or anchor, txOff, tyOff)
    f._text:SetTextColor(1, 1, 1, 1)
    f._text:SetJustifyH(AnchorToJustifyH(anchor))

    f._posLabel = f:CreateFontString(nil, "OVERLAY")
    f._posLabel:SetFont(STANDARD_TEXT_FONT or DEFAULT_FONT, 10, "OUTLINE")
    f._posLabel:SetPoint("BOTTOM", f, "TOP", 0, 2)
    f._posLabel:SetTextColor(1, 1, 0, 0.8)
    f._posLabel:Hide()

    local function UpdatePosLabel(frame)
        if not frame._posLabel then return end
        local cfg = frame._cfg or barCfg
        frame._posLabel:SetFormattedText("X: %.1f  Y: %.1f", cfg.posX or 0, cfg.posY or 0)
    end

    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if ns.db.monitorBars.locked then return end
        self:StartMoving()
        self:SetScript("OnUpdate", function(s)
            local cx, cy = s:GetCenter()
            local p = s:GetParent()
            if p and p == UIParent then
                local posX = MB.rounded(cx - p:GetWidth() * 0.5, 1)
                local posY = MB.rounded(cy - p:GetHeight() * 0.5, 1)
                if s._posLabel then
                    s._posLabel:SetFormattedText("X: %.1f  Y: %.1f", posX, posY)
                end
            end
        end)
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetScript("OnUpdate", nil)
        local cx, cy = self:GetCenter()
        local p = self:GetParent()
        if p and p == UIParent then
            barCfg.posX = MB.rounded(cx - p:GetWidth() * 0.5, 1)
            barCfg.posY = MB.rounded(cy - p:GetHeight() * 0.5, 1)
        else
            local _, _, _, x, y = self:GetPoint(1)
            barCfg.posX = MB.rounded(x or 0, 1)
            barCfg.posY = MB.rounded(y or 0, 1)
        end
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", barCfg.posX, barCfg.posY)
        UpdatePosLabel(self)
    end)

    f:SetScript("OnMouseWheel", function(self, delta)
        if ns.db.monitorBars.locked then return end
        local step = IsControlKeyDown() and 1 or 0.1
        if IsShiftKeyDown() then
            barCfg.posX = MB.rounded((barCfg.posX or 0) + delta * step, 1)
        else
            barCfg.posY = MB.rounded((barCfg.posY or 0) + delta * step, 1)
        end
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", barCfg.posX, barCfg.posY)
        UpdatePosLabel(self)
    end)

    f:SetScript("OnEnter", function(self)
        if ns.db.monitorBars.locked then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        local name = barCfg.spellName or ""
        if name ~= "" then
            GameTooltip:AddLine(name, 1, 1, 1)
        end
        GameTooltip:AddLine(ns.L.mbNudgeHint or "", 0.6, 0.8, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local locked = ns.db and ns.db.monitorBars and ns.db.monitorBars.locked
    f:EnableMouseWheel(not locked)
    if not locked then
        UpdatePosLabel(f)
        f._posLabel:Show()
    end

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
    f._isChargeSpell = nil
    f._shadowCooldown = nil
    f._arcFeedFrame = 0

    activeFrames[id] = f
    return f
end

function MB:GetSize(barFrame)
    local cfg = barFrame._cfg
    if not cfg then return 200, 20 end
    
    local width = cfg.width
    local scale = cfg.scale or 1
    local height = cfg.height
    
    return MB.getNearestPixel(width, scale), MB.getNearestPixel(height, scale)
end

function MB:ApplyStyle(barFrame)
    local cfg = barFrame._cfg
    if not cfg then return end

    local width, height = self:GetSize(barFrame)
    barFrame:SetSize(width, height)

    local strata = cfg.frameStrata or "MEDIUM"
    local baseLevel = GetBaseFrameLevelByStrata(strata)
    barFrame:SetFrameStrata(strata)
    barFrame:SetFrameLevel(baseLevel)
    if barFrame._segContainer then barFrame._segContainer:SetFrameStrata(strata) end
    if barFrame._textHolder    then barFrame._textHolder:SetFrameStrata(strata) end
    if barFrame._borderFrame   then barFrame._borderFrame:SetFrameStrata(strata) end
    if barFrame._segContainer then barFrame._segContainer:SetFrameLevel(baseLevel + 1) end
    if barFrame._textHolder    then barFrame._textHolder:SetFrameLevel(baseLevel + 6) end
    if barFrame._borderFrame   then barFrame._borderFrame:SetFrameLevel(baseLevel + 5) end
    if barFrame._segments then
        for _, seg in ipairs(barFrame._segments) do
            seg:SetFrameStrata(strata)
            seg:SetFrameLevel(baseLevel + 2)
        end
    end
    if barFrame._segBorders then
        for _, border in ipairs(barFrame._segBorders) do
            border:SetFrameStrata(strata)
            border:SetFrameLevel(baseLevel + 4)
        end
    end

    local bgc = cfg.bgColor or { 0.1, 0.1, 0.1, 0.6 }
    barFrame.bg:SetColorTexture(bgc[1], bgc[2], bgc[3], bgc[4])

    local iconSize = height
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
    local anchor = cfg.textAnchor or cfg.textAlign or "RIGHT"
    barFrame._text:ClearAllPoints()
    barFrame._text:SetPoint(ANCHOR_POINT[anchor] or anchor, barFrame._textHolder, ANCHOR_REL[anchor] or anchor, cfg.textOffsetX or -4, cfg.textOffsetY or 0)
    barFrame._text:SetJustifyH(AnchorToJustifyH(anchor))

    if cfg.borderStyle ~= "segment" then
        MB.ApplyMaskAndBorderSettings(barFrame, cfg)
    elseif barFrame._borderFrame then
        barFrame._borderFrame:Hide()
    end

    if cfg.spellID and cfg.spellID > 0 then
        local tex = C_Spell.GetSpellTexture(cfg.spellID)
        if tex then barFrame._icon:SetTexture(tex) end
    end
end

------------------------------------------------------
-- 更新逻辑
------------------------------------------------------

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
    local rawStacks = stacks

    local stacksResolved = true
    local maxStacks = cfg.maxStacks or 5
    local segs = barFrame._segments
    if segs then
        -- Arc detection（修改 stacks 的值，不直接渲染）
        if isSecret then
            local lastFeed = barFrame._arcFeedFrame or 0
            if lastFeed == frameTick then
                stacks = barFrame._arcResolvedStacks or 0
            elseif lastFeed > 0 then
                stacks = GetExactCount(barFrame, maxStacks)
            else
                stacksResolved = false
            end
            FeedArcDetectors(barFrame, rawStacks, maxStacks)
            barFrame._arcFeedFrame = frameTick
            if stacksResolved then
                barFrame._arcResolvedStacks = stacks
            end
        else
            barFrame._arcFeedFrame = 0
            if barFrame._arcDetectors then
                for i = 1, maxStacks do
                    local det = barFrame._arcDetectors[i]
                    if det then det:SetValue(0) end
                end
            end
        end

        -- 设置动画目标，波形渲染由 AnimateStackBars 每帧处理
        if stacksResolved then
            local prevDisplay = barFrame._displayStacks
            local smooth = (cfg.smoothAnimation ~= false)
            if prevDisplay == nil or not smooth then
                -- 首次初始化或禁用平滑动画：直接跳至当前层数
                barFrame._displayStacks = stacks
                barFrame._targetStacks  = stacks
                for i = 1, #segs do
                    segs[i]:SetValue(i <= stacks and 1 or 0)
                end
                ApplySegmentColors(barFrame, stacks)
            else
                barFrame._targetStacks = stacks
                if stacks < prevDisplay then
                    -- 层数减少：立即收回，响应迅速
                    barFrame._displayStacks = stacks
                    for i = 1, #segs do
                        segs[i]:SetValue(i <= stacks and 1 or 0)
                    end
                    ApplySegmentColors(barFrame, stacks)
                end
                -- 层数增加的部分由 AnimateStackBars 的波形动画处理
            end
        end
    end

    if auraActive then
        barFrame._lastKnownActive = true
        barFrame._lastKnownStacks = (not isSecret) and stacks or (barFrame._lastKnownStacks or 0)
    end

    if stacksResolved then
        ApplySegmentColors(barFrame, stacks)
    end

    if stacksResolved and cfg.showText ~= false and barFrame._text then
        barFrame._text:SetText(tostring(stacks))
    end
end

local function UpdateRegularCooldownBar(barFrame)
    local cfg = barFrame._cfg
    local spellID = cfg.spellID

    local isOnGCD = false
    pcall(function()
        local cdInfo = C_Spell.GetSpellCooldown(spellID)
        if cdInfo and cdInfo.isOnGCD == true then isOnGCD = true end
    end)

    local shadowCD = GetOrCreateShadowCooldown(barFrame)
    local durObj = nil
    if isOnGCD then
        shadowCD:SetCooldown(0, 0)
    else
        pcall(function() durObj = C_Spell.GetSpellCooldownDuration(spellID) end)
        if durObj then
            shadowCD:Clear()
            pcall(function() shadowCD:SetCooldownFromDurationObject(durObj, true) end)
        else
            shadowCD:SetCooldown(0, 0)
        end
    end

    local isOnCooldown = shadowCD:IsShown()

    local segs = barFrame._segments
    if not segs or #segs ~= 1 then
        CreateSegments(barFrame, 1, cfg)
        segs = barFrame._segments
    end
    if not segs or #segs < 1 then return end

    local seg = segs[1]
    local interpolation = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut or 0
    local direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0

    if isOnCooldown and not isOnGCD then
        if barFrame._needsDurationRefresh and durObj then
            seg:SetMinMaxValues(0, 1)
            if seg.SetTimerDuration then
                seg:SetTimerDuration(durObj, interpolation, direction)
                if seg.SetToTargetValue then
                    seg:SetToTargetValue()
                end
            else
                seg:SetMinMaxValues(0, 1)
                seg:SetValue(0)
            end
            barFrame._needsDurationRefresh = false
        end
    else
        seg:SetMinMaxValues(0, 1)
        seg:SetValue(1)
    end

    ApplySegmentColors(barFrame, isOnCooldown and 0 or 1)

    if cfg.showText ~= false and barFrame._text then
        if isOnCooldown and not isOnGCD and durObj then
            local remaining = durObj:GetRemainingDuration()
            local ok, result = pcall(function()
                local num = tonumber(remaining)
                if num then return string.format("%.1f", num) end
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

local function UpdateChargeBar(barFrame)
    local cfg = barFrame._cfg
    if not cfg or cfg.barType ~= "charge" then return end

    local spellID = cfg.spellID
    if not spellID or spellID <= 0 then return end

    local chargeJustRefreshed = false
    if barFrame._needsChargeRefresh then
        barFrame._cachedChargeInfo = C_Spell.GetSpellCharges(spellID)
        barFrame._needsChargeRefresh = false
        barFrame._isChargeSpell = barFrame._cachedChargeInfo ~= nil
        chargeJustRefreshed = true
    end

    if barFrame._isChargeSpell == false then
        UpdateRegularCooldownBar(barFrame)
        return
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
            -- 秘密值需一帧渲染后才能解析
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

------------------------------------------------------
-- OnUpdate 循环
------------------------------------------------------

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

-- 每帧推进 stack 类型分段条的波形填充动画
local function AnimateStackBars(dt)
    for _, barFrame in pairs(activeFrames) do
        local cfg = barFrame._cfg
        if cfg and cfg.barType == "stack" and cfg.smoothAnimation ~= false then
            local target  = barFrame._targetStacks
            local display = barFrame._displayStacks
            if target ~= nil and display ~= nil and display < target then
                local diff = target - display
                local speed = STACK_FILL_SPEED
                if diff > 1 then
                    speed = speed * diff
                end
                display = math.min(target, display + speed * dt)
                barFrame._displayStacks = display

                local segs = barFrame._segments
                if segs then
                    for i = 1, #segs do
                        -- 波形进度：第 i 格在 display-(i-1) 处，clamp 到 [0,1]
                        segs[i]:SetValue(math.max(0, math.min(1, display - (i - 1))))
                    end
                end
            end
        end
    end
end

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(_, dt)
    frameTick = frameTick + 1

    -- 波形动画每帧驱动（不节流）
    AnimateStackBars(dt)

    elapsed = elapsed + dt
    if elapsed < UPDATE_INTERVAL then return end
    elapsed = 0
    UpdateAllBars()
end)
updateFrame:Hide()

------------------------------------------------------
-- 生命周期 / 事件
------------------------------------------------------

local hasTarget = false
local isDragonriding = false

local function IsClassMatchedForCurrentPlayer(classTag)
    if classTag == nil or classTag == "" or classTag == "ALL" then
        return true
    end
    return classTag == PLAYER_CLASS_TAG
end

local function ShouldBarBeVisible(barCfg)
    if not IsClassMatchedForCurrentPlayer(barCfg.class) then
        return false
    end
    local cond = barCfg.showCondition or (barCfg.combatOnly and "combat") or "always"
    if cond == "combat"          then return inCombat end
    if cond == "target"          then return hasTarget end
    if cond == "dragonriding"    then return isDragonriding end
    if cond == "not_dragonriding" then return not isDragonriding end
    return true
end

local function IsBarVisibleForSpec(barCfg)
    local specs = barCfg.specs
    if not specs or #specs == 0 then return true end
    local cur = GetSpecialization() or 1
    for _, s in ipairs(specs) do
        if s == cur then return true end
    end
    return false
end

function MB:RebuildCDMSuppressedSet()
    local suppressed = ns.cdmSuppressedCooldownIDs
    wipe(suppressed)
    local bars = ns.db and ns.db.monitorBars and ns.db.monitorBars.bars
    if not bars then return end
    for _, barCfg in ipairs(bars) do
        if barCfg.enabled
            and IsClassMatchedForCurrentPlayer(barCfg.class)
            and barCfg.hideFromCDM
            and barCfg.spellID > 0 then
            local sid = barCfg.spellID
            local cdID = spellToCooldownID[sid]
            -- 若直接 spellID 未命中，尝试 base spell 变体（天赋替换/Override 时 ID 不同）
            if not cdID and C_Spell and C_Spell.GetBaseSpell then
                local baseID = C_Spell.GetBaseSpell(sid)
                if baseID and baseID ~= sid then
                    cdID = spellToCooldownID[baseID]
                end
            end
            if cdID then
                suppressed[cdID] = true
            end
        end
    end
    -- 触发完整 RefreshViewer，重新分类并隐藏 suppressed 帧
    if ns.Layout and ns.Layout.RequestBuffRefreshFromMB then
        ns.Layout.RequestBuffRefreshFromMB()
    end
end

-- 当 CDM buff 图标帧首次出现时（含战斗中），实时更新 spellID→cooldownID 映射并重建 suppressed 集合。
-- 解决 reload 后首次战斗中 hideFromCDM 未能及时生效的时序问题。
function MB:UpdateFrameMapping(frame)
    if not frame then return end
    local cdID = MB.GetCooldownIDFromFrame(frame)
    if not cdID then return end
    cooldownIDToFrame[cdID] = frame
    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo and
        C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
    if info then
        local sid = MB.ResolveSpellID(info)
        if sid and sid > 0 and not spellToCooldownID[sid] then
            spellToCooldownID[sid] = cdID
        end
        if info.linkedSpellIDs then
            for _, lid in ipairs(info.linkedSpellIDs) do
                if lid and lid > 0 and not spellToCooldownID[lid] then
                    spellToCooldownID[lid] = cdID
                end
            end
        end
        if info.spellID and info.spellID > 0 and not spellToCooldownID[info.spellID] then
            spellToCooldownID[info.spellID] = cdID
        end
    end
    self:RebuildCDMSuppressedSet()
end

function MB:InitAllBars()
    local bars = ns.db and ns.db.monitorBars and ns.db.monitorBars.bars
    if not bars then return end

    self:RebuildCDMSuppressedSet()

    for _, barCfg in ipairs(bars) do
        if barCfg.enabled
            and barCfg.spellID > 0
            and IsClassMatchedForCurrentPlayer(barCfg.class)
            and IsBarVisibleForSpec(barCfg) then
            local f = self:CreateBarFrame(barCfg)
            self:ApplyStyle(f)

            local count = (barCfg.barType == "charge")
                and (barCfg.maxCharges > 0 and barCfg.maxCharges or 1)
                or barCfg.maxStacks
            C_Timer.After(0, function()
                if f._segContainer and f._segContainer:GetWidth() > 0 then
                    CreateSegments(f, count, barCfg)
                end
            end)

            if ShouldBarBeVisible(barCfg) then
                f:Show()
            else
                f:Hide()
            end
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

local function RefreshBarVisibility()
    for _, f in pairs(activeFrames) do
        if f._cfg then
            f:SetShown(ShouldBarBeVisible(f._cfg))
        end
    end
end

function MB:OnCombatEnter()
    inCombat = true
    RefreshBarVisibility()
end

function MB:OnCombatLeave()
    inCombat = false
    RefreshBarVisibility()
    self:ScanCDMViewers()
    for _, f in pairs(activeFrames) do
        f._needsChargeRefresh = true
        f._needsDurationRefresh = true
        f._nilCount = 0
        f._isChargeSpell = nil
        if f._cfg and f._cfg.barType == "stack" then
            f._arcFeedFrame = 0
            if f._arcDetectors then
                for _, det in pairs(f._arcDetectors) do
                    det:SetValue(0)
                end
            end
        end
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

function MB:OnAuraUpdate(unit)
end

function MB:OnSkyridingChanged()
    local prev = isDragonriding
    isDragonriding = IsSkyriding()
    if isDragonriding ~= prev then
        RefreshBarVisibility()
    end
end

function MB:OnTargetChanged()
    hasTarget = UnitExists("target") == true
    for _, f in pairs(activeFrames) do
        if f._cfg then
            if f._cfg.unit == "target" then
                f._trackedAuraInstanceID = nil
            end
            f:SetShown(ShouldBarBeVisible(f._cfg))
        end
    end
end

function MB:SetLocked(locked)
    ns.db.monitorBars.locked = locked
    for _, f in pairs(activeFrames) do
        f:EnableMouse(not locked)
        f:EnableMouseWheel(not locked)
        if f._posLabel then
            if locked then
                f._posLabel:Hide()
            else
                local cfg = f._cfg
                if cfg then
                    f._posLabel:SetFormattedText("X: %.1f  Y: %.1f", cfg.posX or 0, cfg.posY or 0)
                end
                f._posLabel:Show()
            end
        end
    end
end

function MB:GetActiveFrame(barID)
    return activeFrames[barID]
end
