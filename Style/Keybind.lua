-- 键位文字显示 + 动作条绑定映射
local _, ns = ...

local Style = ns.Style
local DEFAULT_FONT = ns._styleConst.DEFAULT_FONT
local ResolveFontPath = ns.ResolveFontPath

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
Style.GetSpellIDFromIcon = GetSpellIDFromIcon

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
