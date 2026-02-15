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
local LSM = LibStub("LibSharedMedia-3.0", true)

local _issecretvalue = issecretvalue or function() return false end

local function ResolveFontPath(fontName)
    if LSM then
        local name = fontName
        if not name or name == "" then
            name = LSM.DefaultMedia and LSM.DefaultMedia.font
        end
        if name and name ~= "" then
            local ok, p = pcall(LSM.Fetch, LSM, "font", name, true)
            if ok and p then return p end
        end
    end
    return DEFAULT_FONT
end

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
-- 键位显示模块（基于 C_CooldownViewer + 动作条绑定映射）
------------------------------------------------------
local spellToKeyCache = {}
local KEYBIND_BAR_PREFIXES = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
}
local KEYBIND_BINDING_NAMES = {
    "ACTIONBUTTON",
    "MULTIACTIONBAR1BUTTON",
    "MULTIACTIONBAR2BUTTON",
    "MULTIACTIONBAR4BUTTON",
    "MULTIACTIONBAR3BUTTON",
}

local function FormatCompact(raw)
    local s = raw:upper()
    s = s:gsub("STRG%-", "CTRL-")
    s = s:gsub("CONTROL%-", "CTRL-")
    s = s:gsub("%s+", "")

    local mods = ""
    if s:find("CTRL-", 1, true) then mods = mods .. "C" end
    if s:find("ALT-", 1, true) then mods = mods .. "A" end
    if s:find("SHIFT-", 1, true) then mods = mods .. "S" end
    if s:find("META-", 1, true) then mods = mods .. "M" end

    s = s:gsub("CTRL%-", "")
    s = s:gsub("ALT%-", "")
    s = s:gsub("SHIFT%-", "")
    s = s:gsub("META%-", "")

    s = s:gsub("MOUSEWHEELUP", "MU")
    s = s:gsub("MOUSEWHEELDOWN", "MD")
    s = s:gsub("MOUSEBUTTON(%d+)", "M%1")
    s = s:gsub("BUTTON(%d+)", "M%1")
    s = s:gsub("NUMPAD(%d+)", "N%1")
    s = s:gsub("NUMPADPLUS", "N+")
    s = s:gsub("NUMPADMINUS", "N-")
    s = s:gsub("NUMPADMULTIPLY", "N*")
    s = s:gsub("NUMPADDIVIDE", "N/")
    s = s:gsub("HOME", "HM")
    s = s:gsub("END", "ED")
    s = s:gsub("INSERT", "INS")
    s = s:gsub("DELETE", "DEL")
    s = s:gsub("PAGEUP", "PU")
    s = s:gsub("PAGEDOWN", "PD")
    s = s:gsub("SPACEBAR", "SP")
    s = s:gsub("BACKSPACE", "BS")
    s = s:gsub("CAPSLOCK", "CL")
    s = s:gsub("ESCAPE", "ESC")
    s = s:gsub("RETURN", "RT")
    s = s:gsub("ENTER", "RT")
    s = s:gsub("TAB", "TB")
    s = s:gsub("%+", "")
    return mods .. s
end

local function FormatKeyForDisplay(raw)
    if not raw or raw == "" or raw == "●" then return "" end
    return FormatCompact(raw)
end

local function BuildSpellToKeyMap()
    local map = {}
    local function add(spellID, key)
        if spellID and spellID > 0 and key and key ~= "" then
            map[spellID] = key
        end
    end
    for barIdx, prefix in ipairs(KEYBIND_BAR_PREFIXES) do
        local bindPrefix = KEYBIND_BINDING_NAMES[barIdx]
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn and btn.action then
                local slot = btn.action
                local cmd = bindPrefix .. i
                local key = GetBindingKey(cmd)
                if key then
                    local kind, id, subType = GetActionInfo(slot)
                    if kind == "spell" and id then
                        add(id, key)
                        local override = C_Spell and C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(id)
                        if override then add(override, key) end
                    elseif kind == "macro" and id then
                        if subType == "spell" then
                            add(id, key)
                            local override = C_Spell and C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(id)
                            if override then add(override, key) end
                        else
                            local macroSpell = GetMacroSpell and GetMacroSpell(id)
                            if macroSpell then
                                add(macroSpell, key)
                                local override = C_Spell and C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(macroSpell)
                                if override then add(override, key) end
                            end
                        end
                    end
                end
            end
        end
    end
    return map
end

local function GetSpellIDFromIcon(icon)
    if icon.cooldownID and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(icon.cooldownID)
        if info and info.spellID then
            return info.spellID
        end
    end
    return nil
end

local function FindKeyForSpell(spellID, map)
    if not spellID or not map then return "" end
    if map[spellID] then return map[spellID] end
    if C_Spell and C_Spell.GetOverrideSpell then
        local ov = C_Spell.GetOverrideSpell(spellID)
        if ov and map[ov] then return map[ov] end
    end
    if C_Spell and C_Spell.GetBaseSpell then
        local base = C_Spell.GetBaseSpell(spellID)
        if base and map[base] then return map[base] end
    end
    return ""
end

function Style:ApplyKeybind(button, cfg)
    if not button or not cfg or not cfg.keybind then return end
    local kb = cfg.keybind
    if not kb.enabled then
        if button._cdf_keybindFrame then
            button._cdf_keybindFrame:Hide()
        end
        return
    end

    if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCooldownInfo then
        return
    end

    if next(spellToKeyCache) == nil then
        spellToKeyCache = BuildSpellToKeyMap()
    end
    local spellID = GetSpellIDFromIcon(button)
    local keyText
    if spellID and kb.manualBySpell and kb.manualBySpell[spellID] and kb.manualBySpell[spellID] ~= "" then
        keyText = kb.manualBySpell[spellID]
    elseif spellID and kb.manualBySpell and kb.manualBySpell[tostring(spellID)] and kb.manualBySpell[tostring(spellID)] ~= "" then
        keyText = kb.manualBySpell[tostring(spellID)]
    else
        local rawKey = FindKeyForSpell(spellID, spellToKeyCache)
        keyText = FormatKeyForDisplay(rawKey)
    end

    if not button._cdf_keybindFrame then
        local f = CreateFrame("Frame", nil, button)
        f:SetAllPoints(button)
        f:SetFrameLevel(button:GetFrameLevel() + 3)
        local fs = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        fs:SetTextColor(1, 1, 1, 1)
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
        f.text = fs
        button._cdf_keybindFrame = f
    end
    local fs = button._cdf_keybindFrame.text
    fs:SetText(keyText or "")

    local flag = (kb.outline == "NONE") and "" or kb.outline
    local fontPath = ResolveFontPath(kb.fontName)
    if fs._cdf_kbFontSize ~= kb.fontSize or fs._cdf_kbOutline ~= flag or fs._cdf_kbFontPath ~= fontPath then
        if not fs:SetFont(fontPath, kb.fontSize, flag) then
            fs:SetFont(DEFAULT_FONT, kb.fontSize, flag)
            fontPath = DEFAULT_FONT
        end
        fs._cdf_kbFontSize = kb.fontSize
        fs._cdf_kbOutline = flag
        fs._cdf_kbFontPath = fontPath
    end
    if type(kb.textColor) == "table" then
        local r = kb.textColor[1] or 1
        local g = kb.textColor[2] or 1
        local b = kb.textColor[3] or 1
        local a = kb.textColor[4] or 1
        if fs._cdf_kbR ~= r or fs._cdf_kbG ~= g or fs._cdf_kbB ~= b or fs._cdf_kbA ~= a then
            fs:SetTextColor(r, g, b, a)
            fs._cdf_kbR = r
            fs._cdf_kbG = g
            fs._cdf_kbB = b
            fs._cdf_kbA = a
        end
    end
    local ox, oy = kb.offsetX or 0, kb.offsetY or 0
    if fs._cdf_kbPoint ~= kb.point or fs._cdf_kbOx ~= ox or fs._cdf_kbOy ~= oy then
        fs:ClearAllPoints()
        fs:SetPoint(kb.point, button, kb.point, ox, oy)
        fs._cdf_kbPoint = kb.point
        fs._cdf_kbOx = ox
        fs._cdf_kbOy = oy
    end

    if keyText and keyText ~= "" then
        button._cdf_keybindFrame:Show()
    else
        button._cdf_keybindFrame:Hide()
    end
end

function Style:InvalidateKeybindCache()
    spellToKeyCache = {}
end

------------------------------------------------------
-- 堆叠文字样式模块
------------------------------------------------------
function Style:ApplyStack(button, cfg)
    if not button or not cfg then return end

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
