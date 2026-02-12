local _, ns = ...

------------------------------------------------------
-- 样式模块
------------------------------------------------------

local Style = {}
ns.Style = Style

local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local DEFAULT_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local _issecretvalue = issecretvalue or function() return false end

------------------------------------------------------
-- 图标样式
------------------------------------------------------
function Style:ApplyIcon(button, w, h, zoom, borderSize)
    if not button or not button.Icon then return end

    -- 设置图标尺寸
    button:SetSize(w, h)

    -- 纹理裁剪（去除圆形边缘）
    local crop = zoom * 0.5
    local ratio = w / h
    button.Icon:ClearAllPoints()
    button.Icon:SetAllPoints(button)
    if button.Icon.SetTexCoord then
        button.Icon:SetTexCoord(crop, 1 - crop, crop * ratio, 1 - crop * ratio)
    end

    -- 冷却扫过纹理替换为方形
    for i = 1, select("#", button:GetChildren()) do
        local child = select(i, button:GetChildren())
        if child and child.SetSwipeTexture then
            child:SetSwipeTexture(SQUARE_MASK)
            child:ClearAllPoints()
            child:SetPoint("TOPLEFT", button, "TOPLEFT", borderSize, -borderSize)
            child:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -borderSize, borderSize)
        end
    end

    -- 隐藏原生圆形覆盖层
    for _, region in next, { button:GetRegions() } do
        if region:IsObjectType("Texture") then
            local atlas = region.GetAtlas and region:GetAtlas()
            if atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                region:SetAlpha(0)
            end
            -- 替换圆形遮罩纹理（需安全检查 secretvalue）
            local tex = region:GetTexture()
            if not _issecretvalue(tex) and tex == 6707800 then
                region:SetTexture(SQUARE_MASK)
                region._cdf_replaced = true
            end
        end
    end

    -- 创建/更新像素边框
    if borderSize > 0 then
        if not button._cdf_border then
            button._cdf_border = CreateFrame("Frame", nil, button, "BackdropTemplate")
            button._cdf_border:SetFrameLevel(button:GetFrameLevel() + 1)
        end
        button._cdf_border:ClearAllPoints()
        button._cdf_border:SetAllPoints(button)
        button._cdf_border:SetBackdrop({
            edgeFile = SQUARE_MASK,
            edgeSize = borderSize,
        })
        button._cdf_border:SetBackdropBorderColor(0, 0, 0, 1)
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
local activeGlowFrames = {}  -- 追踪当前有高亮的图标

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

    local c = cfg.color

    if cfg.style == "PIXEL" then
        LCG.PixelGlow_Start(button, c, cfg.lines, cfg.frequency,
            nil, cfg.thickness, 0, 0, false, GLOW_KEY, 1)
    elseif cfg.style == "AUTOCAST" then
        LCG.AutoCastGlow_Start(button, c, nil, cfg.frequency,
            cfg.scale, 0, 0, GLOW_KEY, 1)
    elseif cfg.style == "PROC" then
        LCG.ProcGlow_Start(button, {
            color = c, key = GLOW_KEY, frameLevel = 1,
            startAnim = true, duration = 1,
        })
    elseif cfg.style == "BUTTON" then
        LCG.ButtonGlow_Start(button, c, cfg.frequency, 1)
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
    fs:SetFont(DEFAULT_FONT, cfg.fontSize, flag)
    fs:ClearAllPoints()
    fs:SetPoint(cfg.point, button, cfg.point, cfg.offsetX or 0, cfg.offsetY or 0)
end
