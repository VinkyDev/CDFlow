-- CDM 查看器扫描、spellID/cooldownID 映射、技能目录
local _, ns = ...

local MB = {}
ns.MonitorBars = MB

local LSM = LibStub("LibSharedMedia-3.0", true)
local DEFAULT_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local BAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"

ns._mbConst = {
    DEFAULT_FONT = DEFAULT_FONT,
    BAR_TEXTURE  = BAR_TEXTURE,
    SEGMENT_GAP  = 1,
    UPDATE_INTERVAL = 0.1,
}

local spellToCooldownID = {}
local cooldownIDToFrame = {}
ns.cdmSuppressedCooldownIDs = {}

MB._spellToCooldownID = spellToCooldownID
MB._cooldownIDToFrame = cooldownIDToFrame

local function HasAuraInstanceID(value)
    if value == nil then return false end
    if issecretvalue and issecretvalue(value) then return true end
    if type(value) == "number" and value == 0 then return false end
    return true
end
MB.HasAuraInstanceID = HasAuraInstanceID

function MB.ResolveFontPath(fontName)
    if not fontName or fontName == "" then return DEFAULT_FONT end
    if LSM and LSM.Fetch then
        local path = LSM:Fetch("font", fontName)
        if path then return path end
    end
    return DEFAULT_FONT
end

function MB.ConfigureStatusBar(bar)
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
MB.CDM_VIEWERS = CDM_VIEWERS

local function GetCooldownIDFromFrame(frame)
    local cdID = frame.cooldownID
    if not cdID and frame.cooldownInfo then
        cdID = frame.cooldownInfo.cooldownID
    end
    return cdID
end
MB.GetCooldownIDFromFrame = GetCooldownIDFromFrame

local function ResolveSpellID(info)
    if not info then return nil end
    local base = info.spellID or 0
    local linked = info.linkedSpellIDs and info.linkedSpellIDs[1]
    return linked or info.overrideSpellID or (base > 0 and base) or nil
end
MB.ResolveSpellID = ResolveSpellID

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

    for _, viewerName in ipairs(CDM_VIEWERS) do
        local viewer = _G[viewerName]
        if viewer then
            local isAuraViewer = (viewerName == "BuffIconCooldownViewer" or viewerName == "BuffBarCooldownViewer")
            for _, child in ipairs({ viewer:GetChildren() }) do
                local cdID = GetCooldownIDFromFrame(child)
                if cdID then
                    cooldownIDToFrame[cdID] = child
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                    MapSpellInfo(info, cdID, isAuraViewer)
                end
            end
        end
    end

    self:PostScanHook()
    -- 扫描完成后立即同步 suppressed 集合，确保 OnCombatLeave 后隐藏状态即刻生效
    if self.RebuildCDMSuppressedSet then
        self:RebuildCDMSuppressedSet()
    end
end

function MB.FindCDMFrame(cooldownID)
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
