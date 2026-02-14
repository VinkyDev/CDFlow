local _, ns = ...

------------------------------------------------------
-- 样式模块
------------------------------------------------------

local Style = {}
ns.Style = Style

local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local DEFAULT_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local ROUND_MASK_TEX = 6707800
local GLOW_COLOR = { 0.95, 0.95, 0.32, 1 }

local _issecretvalue = issecretvalue or function() return false end

local function EnsureIconCaches(button)
    if button._cdf_cacheReady then return end

    button._cdf_swipes = {}
    for i = 1, select("#", button:GetChildren()) do
        local child = select(i, button:GetChildren())
        if child and child.SetSwipeTexture then
            button._cdf_swipes[#button._cdf_swipes + 1] = child
        end
    end

    button._cdf_overlayRegions = {}
    button._cdf_roundMaskRegions = {}
    for _, region in next, { button:GetRegions() } do
        if region:IsObjectType("Texture") then
            local atlas = region.GetAtlas and region:GetAtlas()
            if atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                button._cdf_overlayRegions[#button._cdf_overlayRegions + 1] = region
            end
            local tex = region:GetTexture()
            if not _issecretvalue(tex) and tex == ROUND_MASK_TEX then
                button._cdf_roundMaskRegions[#button._cdf_roundMaskRegions + 1] = region
            end
        end
    end

    button._cdf_cacheReady = true
end

------------------------------------------------------
-- 图标样式
------------------------------------------------------
function Style:ApplyIcon(button, w, h, zoom, borderSize)
    if not button or not button.Icon then return end
    EnsureIconCaches(button)

    if button._cdf_w ~= w or button._cdf_h ~= h then
        button:SetSize(w, h)
        button._cdf_w = w
        button._cdf_h = h
    end

    local crop = zoom * 0.5
    local ratio = w / h
    if not button._cdf_iconAnchored then
        button.Icon:ClearAllPoints()
        button.Icon:SetAllPoints(button)
        button._cdf_iconAnchored = true
    end
    if button.Icon.SetTexCoord
        and (button._cdf_crop ~= crop or button._cdf_ratio ~= ratio) then
        button.Icon:SetTexCoord(crop, 1 - crop, crop * ratio, 1 - crop * ratio)
        button._cdf_crop = crop
        button._cdf_ratio = ratio
    end

    for _, swipe in ipairs(button._cdf_swipes) do
        if not swipe._cdf_squareSwipe then
            swipe:SetSwipeTexture(SQUARE_MASK)
            swipe._cdf_squareSwipe = true
        end
        if swipe._cdf_borderSize ~= borderSize then
            swipe:ClearAllPoints()
            swipe:SetPoint("TOPLEFT", button, "TOPLEFT", borderSize, -borderSize)
            swipe:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -borderSize, borderSize)
            swipe._cdf_borderSize = borderSize
        end
    end

    for _, region in ipairs(button._cdf_overlayRegions) do
        if region:GetAlpha() ~= 0 then
            region:SetAlpha(0)
        end
    end
    for _, region in ipairs(button._cdf_roundMaskRegions) do
        if not region._cdf_replaced then
            region:SetTexture(SQUARE_MASK)
            region._cdf_replaced = true
        end
    end

    if borderSize > 0 then
        if not button._cdf_border then
            button._cdf_border = CreateFrame("Frame", nil, button, "BackdropTemplate")
            button._cdf_border:SetFrameLevel(button:GetFrameLevel() + 1)
            button._cdf_border:ClearAllPoints()
            button._cdf_border:SetAllPoints(button)
        end
        if button._cdf_borderSize ~= borderSize then
            button._cdf_border:SetBackdrop({
                edgeFile = SQUARE_MASK,
                edgeSize = borderSize,
            })
            button._cdf_border:SetBackdropBorderColor(0, 0, 0, 1)
            button._cdf_borderSize = borderSize
        end
        button._cdf_border:Show()
    elseif button._cdf_border then
        button._cdf_border:Hide()
    end

    button._cdf_styled = true
end

------------------------------------------------------
-- 高亮特效模块
------------------------------------------------------

local LCG  -- LibCustomGlow 延迟加载引用
local GLOW_KEY = "CDFlow"
local GLOW_KEY_BUFF = "CDFlowBuff"
local activeGlowFrames = {}   -- 追踪技能激活高亮
local activeBuffGlowFrames = {}  -- 追踪 Buff 高亮

-- 隐藏游戏原生的技能激活高亮
function Style:HideOriginalGlow(button)
    if button.SpellActivationAlert then
        button.SpellActivationAlert:Hide()
    end
end

-- 显示自定义高亮特效
function Style:ShowHighlight(button)
    local cfg = ns.db and ns.db.highlight
    if not cfg or not button then return end

    -- 始终追踪此图标（便于设置变更后刷新）
    activeGlowFrames[button] = true

    -- 禁用模式：隐藏一切
    if cfg.style == "NONE" then
        self:HideOriginalGlow(button)
        self:StopGlow(button)
        return
    end

    -- 默认模式：不干预游戏原生高亮
    if cfg.style == "DEFAULT" then
        self:StopGlow(button)
        return
    end

    -- 自定义模式：隐藏原生，显示 LibCustomGlow 特效
    self:HideOriginalGlow(button)

    if not LCG then
        LCG = LibStub("LibCustomGlow-1.0", true)
        if not LCG then return end
    end

    -- 如果当前已有不同类型的特效，先清除
    if button._cdf_glowType and button._cdf_glowType ~= cfg.style then
        self:StopGlow(button)
    end

    if cfg.style == "PIXEL" then
        LCG.PixelGlow_Start(button, GLOW_COLOR, cfg.lines, cfg.frequency,
            nil, cfg.thickness, 0, 0, false, GLOW_KEY, 1)
    elseif cfg.style == "AUTOCAST" then
        LCG.AutoCastGlow_Start(button, GLOW_COLOR, nil, cfg.frequency,
            cfg.scale, 0, 0, GLOW_KEY, 1)
    elseif cfg.style == "PROC" then
        LCG.ProcGlow_Start(button, {
            color = GLOW_COLOR, key = GLOW_KEY, frameLevel = 1,
            startAnim = true, duration = 1,
        })
    elseif cfg.style == "BUTTON" then
        LCG.ButtonGlow_Start(button, GLOW_COLOR, cfg.frequency, 1)
    end

    button._cdf_glowType = cfg.style
    button._cdf_glowActive = true
end

-- 停止 LibCustomGlow 特效
function Style:StopGlow(button)
    if not LCG or not button._cdf_glowType then return end

    if button._cdf_glowType == "PIXEL" then
        LCG.PixelGlow_Stop(button, GLOW_KEY)
    elseif button._cdf_glowType == "AUTOCAST" then
        LCG.AutoCastGlow_Stop(button, GLOW_KEY)
    elseif button._cdf_glowType == "PROC" then
        LCG.ProcGlow_Stop(button, GLOW_KEY)
    elseif button._cdf_glowType == "BUTTON" then
        LCG.ButtonGlow_Stop(button)
    end

    button._cdf_glowType = nil
    button._cdf_glowActive = nil
end

-- 隐藏自定义高亮
function Style:HideHighlight(button)
    if not button then return end
    activeGlowFrames[button] = nil
    self:StopGlow(button)
end

-- 刷新所有当前活跃的高亮特效
function Style:RefreshAllGlows()
    local frames = {}
    for frame in pairs(activeGlowFrames) do
        frames[#frames + 1] = frame
    end
    for _, frame in ipairs(frames) do
        self:StopGlow(frame)
        self:ShowHighlight(frame)
    end
end

------------------------------------------------------
-- Buff 增益高亮模块
------------------------------------------------------
function Style:ShowBuffGlow(button)
    local cfg = ns.db and ns.db.buffGlow
    if not cfg or not cfg.enabled or not button then return end

    activeBuffGlowFrames[button] = true

    if cfg.style == "NONE" then
        self:StopBuffGlow(button)
        return
    end

    if cfg.style == "DEFAULT" then
        self:StopBuffGlow(button)
        return
    end

    if not LCG then
        LCG = LibStub("LibCustomGlow-1.0", true)
        if not LCG then return end
    end

    if button._cdf_buffGlowType and button._cdf_buffGlowType ~= cfg.style then
        self:StopBuffGlow(button)
    end

    if cfg.style == "PIXEL" then
        LCG.PixelGlow_Start(button, GLOW_COLOR, cfg.lines, cfg.frequency,
            nil, cfg.thickness, 0, 0, false, GLOW_KEY_BUFF, 1)
    elseif cfg.style == "AUTOCAST" then
        LCG.AutoCastGlow_Start(button, GLOW_COLOR, nil, cfg.frequency,
            cfg.scale, 0, 0, GLOW_KEY_BUFF, 1)
    elseif cfg.style == "PROC" then
        LCG.ProcGlow_Start(button, {
            color = GLOW_COLOR, key = GLOW_KEY_BUFF, frameLevel = 1,
            startAnim = true, duration = 1,
        })
    elseif cfg.style == "BUTTON" then
        LCG.ButtonGlow_Start(button, GLOW_COLOR, cfg.frequency, 1)
    end

    button._cdf_buffGlowType = cfg.style
    button._cdf_buffGlowActive = true
end

function Style:StopBuffGlow(button)
    if not LCG or not button._cdf_buffGlowType then return end

    if button._cdf_buffGlowType == "PIXEL" then
        LCG.PixelGlow_Stop(button, GLOW_KEY_BUFF)
    elseif button._cdf_buffGlowType == "AUTOCAST" then
        LCG.AutoCastGlow_Stop(button, GLOW_KEY_BUFF)
    elseif button._cdf_buffGlowType == "PROC" then
        LCG.ProcGlow_Stop(button, GLOW_KEY_BUFF)
    elseif button._cdf_buffGlowType == "BUTTON" then
        LCG.ButtonGlow_Stop(button)
    end

    button._cdf_buffGlowType = nil
    button._cdf_buffGlowActive = nil
end

function Style:HideBuffGlow(button)
    if not button then return end
    activeBuffGlowFrames[button] = nil
    self:StopBuffGlow(button)
end

function Style:RefreshAllBuffGlows()
    local frames = {}
    for frame in pairs(activeBuffGlowFrames) do
        frames[#frames + 1] = frame
    end
    for _, frame in ipairs(frames) do
        self:StopBuffGlow(frame)
        self:ShowBuffGlow(frame)
    end
end

------------------------------------------------------
-- 堆叠文字样式模块
------------------------------------------------------
function Style:ApplyStack(button, cfg)
    if not button or not cfg or not cfg.enabled then return end

    -- 查找堆叠计数 FontString
    local fs
    if button.Applications and button.Applications.Applications then
        fs = button.Applications.Applications
        if button.Applications.SetFrameLevel then
            button.Applications:SetFrameLevel(button:GetFrameLevel() + 2)
        end
    elseif button.ChargeCount and button.ChargeCount.Current then
        fs = button.ChargeCount.Current
        if button.ChargeCount.SetFrameLevel then
            button.ChargeCount:SetFrameLevel(button:GetFrameLevel() + 2)
        end
    end
    if not fs then return end

    local flag = (cfg.outline == "NONE") and "" or cfg.outline
    if fs._cdf_fontSize ~= cfg.fontSize or fs._cdf_outline ~= flag then
        fs:SetFont(DEFAULT_FONT, cfg.fontSize, flag)
        fs._cdf_fontSize = cfg.fontSize
        fs._cdf_outline = flag
    end

    local ox, oy = cfg.offsetX or 0, cfg.offsetY or 0
    if fs._cdf_point ~= cfg.point or fs._cdf_ox ~= ox or fs._cdf_oy ~= oy then
        fs:ClearAllPoints()
        fs:SetPoint(cfg.point, button, cfg.point, ox, oy)
        fs._cdf_point = cfg.point
        fs._cdf_ox = ox
        fs._cdf_oy = oy
    end
end
