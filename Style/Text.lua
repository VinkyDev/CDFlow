-- 堆叠数字样式 + 冷却读秒样式
local _, ns = ...

local Style = ns.Style
local DEFAULT_FONT = ns._styleConst.DEFAULT_FONT
local ResolveFontPath = ns.ResolveFontPath

function Style:ApplyStack(button, cfg)
    if not button or not cfg then return end

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

    if not cfg.enabled then
        if fs._cdf_stackOrig then
            local o = fs._cdf_stackOrig
            if o.font and o.size then
                fs:SetFont(o.font, o.size, o.flags or "")
            end
            if o.color then
                fs:SetTextColor(o.color[1], o.color[2], o.color[3], o.color[4])
            end
            if o.point then
                fs:ClearAllPoints()
                pcall(fs.SetPoint, fs, o.point, o.relTo, o.relPoint, o.x or 0, o.y or 0)
            end
        end
        fs._cdf_fontSize = nil
        fs._cdf_outline = nil
        fs._cdf_fontName = nil
        fs._cdf_point = nil
        fs._cdf_ox = nil
        fs._cdf_oy = nil
        return
    end

    if not fs._cdf_stackOrig then
        local font, size, flags = fs:GetFont()
        local p, relTo, relPoint, x, y = fs:GetPoint(1)
        local r, g, b, a = fs:GetTextColor()
        fs._cdf_stackOrig = {
            font = font,
            size = size,
            flags = flags,
            color = { r, g, b, a },
            point = p,
            relTo = relTo,
            relPoint = relPoint,
            x = x,
            y = y,
        }
    end

    local fontPath = ResolveFontPath(cfg.fontName)
    local flag = (cfg.outline == "NONE") and "" or cfg.outline
    if fs._cdf_fontSize ~= cfg.fontSize or fs._cdf_outline ~= flag or fs._cdf_fontName ~= cfg.fontName then
        if not fs:SetFont(fontPath, cfg.fontSize, flag) then
            fs:SetFont(DEFAULT_FONT, cfg.fontSize, flag)
        end
        fs._cdf_fontSize = cfg.fontSize
        fs._cdf_outline = flag
        fs._cdf_fontName = cfg.fontName
    end

    if type(cfg.textColor) == "table" then
        fs:SetTextColor(cfg.textColor[1] or 1, cfg.textColor[2] or 1, cfg.textColor[3] or 1, cfg.textColor[4] or 1)
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

------------------------------------------------------
-- 冷却读秒
------------------------------------------------------

local function GetCountdownFontString(button)
    if not button or not button.Cooldown then return nil end
    local cd = button.Cooldown
    if cd.GetCountdownFontString then
        local fs = cd:GetCountdownFontString()
        if fs and fs.SetFont then return fs end
    end
    for _, region in ipairs({ cd:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            return region
        end
    end
    return nil
end

function Style:ApplyCooldownText(button, cfg)
    if not button or not cfg or not cfg.cooldownText then return end
    local cdCfg = cfg.cooldownText
    local fs = GetCountdownFontString(button)
    if not fs then return end

    if not cdCfg.enabled then
        if fs._cdf_cdOrig then
            local o = fs._cdf_cdOrig
            if o.font and o.size then
                fs:SetFont(o.font, o.size, o.flags or "")
            end
            if o.color then
                fs:SetTextColor(o.color[1], o.color[2], o.color[3], o.color[4])
            end
            if o.point then
                fs:ClearAllPoints()
                pcall(fs.SetPoint, fs, o.point, o.relTo, o.relPoint, o.x or 0, o.y or 0)
            end
        end
        fs._cdf_cdFontSize = nil
        fs._cdf_cdOutline = nil
        fs._cdf_cdFontPath = nil
        fs._cdf_cdPoint = nil
        return
    end

    if not fs._cdf_cdOrig then
        local font, size, flags = fs:GetFont()
        local r, g, b, a = fs:GetTextColor()
        local p, relTo, relPoint, x, y = fs:GetPoint(1)
        fs._cdf_cdOrig = {
            font = font,
            size = size,
            flags = flags,
            color = { r or 1, g or 1, b or 1, a or 1 },
            point = p,
            relTo = relTo,
            relPoint = relPoint,
            x = x,
            y = y,
        }
    end

    local flag = (cdCfg.outline == "NONE") and "" or cdCfg.outline
    local fontPath = ResolveFontPath(cdCfg.fontName)
    if fs._cdf_cdFontSize ~= cdCfg.fontSize or fs._cdf_cdOutline ~= flag or fs._cdf_cdFontPath ~= fontPath then
        if not fs:SetFont(fontPath, cdCfg.fontSize, flag) then
            fs:SetFont(DEFAULT_FONT, cdCfg.fontSize, flag)
            fontPath = DEFAULT_FONT
        end
        fs._cdf_cdFontSize = cdCfg.fontSize
        fs._cdf_cdOutline = flag
        fs._cdf_cdFontPath = fontPath
    end

    if type(cdCfg.textColor) == "table" then
        local r = cdCfg.textColor[1] or 1
        local g = cdCfg.textColor[2] or 0.82
        local b = cdCfg.textColor[3] or 0
        local a = cdCfg.textColor[4] or 1
        if fs._cdf_cdR ~= r or fs._cdf_cdG ~= g or fs._cdf_cdB ~= b or fs._cdf_cdA ~= a then
            fs:SetTextColor(r, g, b, a)
            fs._cdf_cdR = r
            fs._cdf_cdG = g
            fs._cdf_cdB = b
            fs._cdf_cdA = a
        end
    end

    local ox, oy = cdCfg.offsetX or 0, cdCfg.offsetY or 0
    if fs._cdf_cdPoint ~= cdCfg.point or fs._cdf_cdOx ~= ox or fs._cdf_cdOy ~= oy then
        fs:ClearAllPoints()
        fs:SetPoint(cdCfg.point, button, cdCfg.point, ox, oy)
        fs._cdf_cdPoint = cdCfg.point
        fs._cdf_cdOx = ox
        fs._cdf_cdOy = oy
    end
end
