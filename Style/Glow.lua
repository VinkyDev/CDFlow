-- 技能激活高亮 + Buff 增益高亮特效
local _, ns = ...

local Style = ns.Style
local LCG
local GLOW_COLOR = { 0.95, 0.95, 0.32, 1 }
local GLOW_KEY = "CDFlow"
local GLOW_KEY_BUFF = "CDFlowBuff"
local activeGlowFrames = {}
local activeBuffGlowFrames = {}

function Style:HideOriginalGlow(button)
    if button.SpellActivationAlert then
        button.SpellActivationAlert:Hide()
    end
end

function Style:ShowHighlight(button)
    local cfg = ns.db and ns.db.highlight
    if not cfg or not button then return end

    activeGlowFrames[button] = true

    if cfg.style == "NONE" then
        self:HideOriginalGlow(button)
        self:StopGlow(button)
        return
    end

    if cfg.style == "DEFAULT" then
        self:StopGlow(button)
        return
    end

    self:HideOriginalGlow(button)

    if not LCG then
        LCG = LibStub("LibCustomGlow-1.0", true)
        if not LCG then return end
    end

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

function Style:HideHighlight(button)
    if not button then return end
    activeGlowFrames[button] = nil
    self:StopGlow(button)
end

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
-- Buff 增益高亮
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
