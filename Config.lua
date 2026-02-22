local _, ns = ...

------------------------------------------------------
-- 配置模块：AceDB-3.0 配置管理 + 导入导出
------------------------------------------------------

local AceDB3 = LibStub("AceDB-3.0")
local LibDualSpec = LibStub("LibDualSpec-1.0", true)

ns.defaults = {
    -- 功能模块开关
    modules = {
        cdmBeautify = true,
        monitorBars = true,
    },

    -- 全局样式
    iconZoom    = 0.08,
    borderSize  = 1,
    suppressDebuffBorder = true,
    trackedBarsGrowDir = "BOTTOM",

    -- 核心技能查看器
    essential = {
        enabled     = true,
        growDir     = "CENTER",
        iconsPerRow = 8,
        iconWidth   = 52,
        iconHeight  = 52,
        spacingX    = 2,
        spacingY    = 2,
        rowOverrides = {},
        stack = {
            enabled  = false,
            fontSize = 12,
            fontName = "默认",
            outline  = "OUTLINE",
            textColor = { 1, 1, 1, 1 },
            point    = "BOTTOMRIGHT",
            offsetX  = 0,
            offsetY  = 0,
        },
        keybind = {
            enabled  = false,
            fontSize = 10,
            fontName = "默认",
            outline  = "OUTLINE",
            textColor = { 1, 1, 1, 1 },
            point    = "TOPRIGHT",
            offsetX  = 0,
            offsetY  = -2,
            manualBySpell = {},
        },
        cooldownText = {
            enabled  = false,
            fontSize = 18,
            fontName = "默认",
            outline  = "OUTLINE",
            textColor = { 1, 0.82, 0, 1 },
            point    = "CENTER",
            offsetX  = 0,
            offsetY  = 0,
        },
    },

    utility = {
        enabled     = true,
        growDir     = "CENTER",
        iconsPerRow = 6,
        iconWidth   = 30,
        iconHeight  = 30,
        spacingX    = 2,
        spacingY    = 2,
        rowOverrides = {},
        stack = {
            enabled  = false,
            fontSize = 12,
            fontName = "默认",
            outline  = "OUTLINE",
            textColor = { 1, 1, 1, 1 },
            point    = "BOTTOMRIGHT",
            offsetX  = 0,
            offsetY  = 0,
        },
        keybind = {
            enabled  = false,
            fontSize = 10,
            fontName = "默认",
            outline  = "OUTLINE",
            textColor = { 1, 1, 1, 1 },
            point    = "TOPRIGHT",
            offsetX  = 0,
            offsetY  = -2,
            manualBySpell = {},
        },
        cooldownText = {
            enabled  = false,
            fontSize = 14,
            fontName = "默认",
            outline  = "OUTLINE",
            textColor = { 1, 0.82, 0, 1 },
            point    = "CENTER",
            offsetX  = 0,
            offsetY  = 0,
        },
    },

    buffs = {
        enabled     = true,
        growDir     = "CENTER",
        iconsPerRow = 0,
        iconWidth   = 40,
        iconHeight  = 40,
        spacingX    = 2,
        spacingY    = 2,
        rowOverrides = {},
        stack = {
            enabled  = false,
            fontSize = 12,
            fontName = "默认",
            outline  = "OUTLINE",
            textColor = { 1, 1, 1, 1 },
            point    = "BOTTOMRIGHT",
            offsetX  = 0,
            offsetY  = 0,
        },
        keybind = {
            enabled  = false,
            fontSize = 10,
            fontName = "默认",
            outline  = "OUTLINE",
            textColor = { 1, 1, 1, 1 },
            point    = "TOPRIGHT",
            offsetX  = 0,
            offsetY  = -2,
            manualBySpell = {},
        },
        cooldownText = {
            enabled  = false,
            fontSize = 16,
            fontName = "默认",
            outline  = "OUTLINE",
            textColor = { 1, 0.82, 0, 1 },
            point    = "CENTER",
            offsetX  = 0,
            offsetY  = 0,
        },
    },

    -- 高亮特效（技能激活）
    highlight = {
        style     = "PIXEL",
        lines     = 8,
        frequency = 0.2,
        thickness = 2,
        scale     = 1,
    },

    -- Buff 增益高亮
    buffGlow = {
        enabled     = false,
        style       = "PIXEL",
        lines       = 8,
        frequency   = 0.2,
        thickness   = 2,
        scale       = 1,
        spellFilter = {},
    },

    -- 监控条
    monitorBars = {
        locked = false,
        nextID = 1,
        bars   = {},
    },
}

-- 深拷贝
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = DeepCopy(v) end
    return t
end
ns.DeepCopy = DeepCopy

------------------------------------------------------
-- 序列化 / 反序列化（导入导出用）
------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Base64Encode(data)
    local out = {}
    local pad = (3 - #data % 3) % 3
    data = data .. string.rep("\0", pad)
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + b * 256 + c
        out[#out + 1] = B64:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
        out[#out + 1] = B64:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        out[#out + 1] = B64:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1)
        out[#out + 1] = B64:sub(n % 64 + 1, n % 64 + 1)
    end
    for i = 1, pad do out[#out - i + 1] = "=" end
    return table.concat(out)
end

local B64_INV = {}
for i = 1, 64 do B64_INV[B64:byte(i)] = i - 1 end

local function Base64Decode(str)
    str = str:gsub("[^A-Za-z0-9+/=]", "")
    local pad = str:match("(=*)$")
    pad = pad and #pad or 0
    str = str:gsub("=", "A")
    local out = {}
    for i = 1, #str, 4 do
        local a = B64_INV[str:byte(i)] or 0
        local b = B64_INV[str:byte(i + 1)] or 0
        local c = B64_INV[str:byte(i + 2)] or 0
        local d = B64_INV[str:byte(i + 3)] or 0
        local n = a * 262144 + b * 4096 + c * 64 + d
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        out[#out + 1] = string.char(math.floor(n / 256) % 256)
        out[#out + 1] = string.char(n % 256)
    end
    local result = table.concat(out)
    if pad > 0 then result = result:sub(1, -pad - 1) end
    return result
end

local function SerializeValue(v)
    local t = type(v)
    if t == "string" then
        return string.format("%q", v)
    elseif t == "number" then
        return tostring(v)
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "table" then
        local parts = {}
        local isArr = true
        local maxn = 0
        for k in pairs(v) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                isArr = false
                break
            end
            if k > maxn then maxn = k end
        end
        if isArr and maxn == #v then
            for i = 1, #v do
                parts[#parts + 1] = SerializeValue(v[i])
            end
        else
            for k2, v2 in pairs(v) do
                if type(k2) == "string" then
                    parts[#parts + 1] = "[" .. string.format("%q", k2) .. "]=" .. SerializeValue(v2)
                elseif type(k2) == "number" then
                    parts[#parts + 1] = "[" .. tostring(k2) .. "]=" .. SerializeValue(v2)
                end
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "nil"
end

------------------------------------------------------
-- 导出 / 导入
------------------------------------------------------

local function DeepMergeForExport(dst, defaults)
    for k, v in pairs(defaults) do
        if dst[k] == nil then
            dst[k] = DeepCopy(v)
        elseif type(v) == "table" and type(dst[k]) == "table" then
            DeepMergeForExport(dst[k], v)
        end
    end
end

function ns:ExportConfig()
    local snapshot = {}
    for k, v in pairs(ns.db) do
        if type(v) == "table" then
            snapshot[k] = DeepCopy(v)
        else
            snapshot[k] = v
        end
    end
    DeepMergeForExport(snapshot, ns.defaults)
    local str = SerializeValue(snapshot)
    return "!CDF1!" .. Base64Encode(str)
end

function ns:ImportConfig(encoded, profileName)
    if type(encoded) ~= "string" then return false, "invalid" end
    if not profileName or profileName:match("^%s*$") then return false, "no name" end
    encoded = encoded:match("^%s*(.-)%s*$")
    local prefix, payload = encoded:match("^(!CDF%d+!)(.+)$")
    if not prefix then return false, "bad format" end
    local raw = Base64Decode(payload)
    if not raw or raw == "" then return false, "decode failed" end
    local fn, err = loadstring("return " .. raw)
    if not fn then return false, "parse error: " .. (err or "") end
    setfenv(fn, {})
    local ok, data = pcall(fn)
    if not ok or type(data) ~= "table" then return false, "eval error" end

    ns.acedb.sv.profiles[profileName] = data
    return true
end

------------------------------------------------------
-- AceDB 初始化 + 旧数据迁移
------------------------------------------------------

local function MigrateOldBarFields(db)
    if not db.monitorBars or type(db.monitorBars.bars) ~= "table" then return end
    local barDefaults = {
        enabled = true, barType = "stack", spellID = 0, spellName = "",
        unit = "player", maxStacks = 5, maxCharges = 2,
        width = 200, height = 20, posX = 0, posY = 0,
        barColor    = { 0.2, 0.8, 0.2, 1 },
        bgColor     = { 0.1, 0.1, 0.1, 0.6 },
        borderColor = { 0, 0, 0, 1 },
        borderSize  = 1,
        showIcon = true, showText = true,
        textAlign = "RIGHT", textOffsetX = -4, textOffsetY = 0,
        fontName = "", fontSize = 12, outline = "OUTLINE",
        barTexture = "Solid",
        colorThreshold  = 0,
        thresholdColor  = { 1.0, 0.5, 0.0, 1 },
        hideFromCDM     = false,
        specs = {},
    }
    for _, bar in ipairs(db.monitorBars.bars) do
        for k, v in pairs(barDefaults) do
            if bar[k] == nil then bar[k] = DeepCopy(v) end
        end
    end
    if type(db.monitorBars.nextID) ~= "number" then
        db.monitorBars.nextID = #db.monitorBars.bars + 1
    end
end

local function MigrateOldViewerFields(cfg)
    if not cfg then return end
    cfg.enabled = true
    if cfg.showKeybind == true and cfg.keybind then
        cfg.keybind.enabled = true
    end
    cfg.showKeybind = nil
    if cfg.stack then
        if type(cfg.stack.fontName) ~= "string" then cfg.stack.fontName = "默认" end
        if type(cfg.stack.textColor) ~= "table" then cfg.stack.textColor = { 1, 1, 1, 1 } end
    end
    if cfg.keybind then
        cfg.keybind.fontPath = nil
        if type(cfg.keybind.fontName) ~= "string" then cfg.keybind.fontName = "默认" end
        if type(cfg.keybind.manualBySpell) ~= "table" then cfg.keybind.manualBySpell = {} end
        if type(cfg.keybind.textColor) ~= "table" then cfg.keybind.textColor = { 1, 1, 1, 1 } end
    end
    if cfg.cooldownText then
        cfg.cooldownText.fontPath = nil
        if type(cfg.cooldownText.fontName) ~= "string" then cfg.cooldownText.fontName = "默认" end
        if type(cfg.cooldownText.textColor) ~= "table" then cfg.cooldownText.textColor = { 1, 0.82, 0, 1 } end
    end
end

local function MigrateOldData(profileData)
    for _, key in ipairs({ "essential", "utility", "buffs" }) do
        MigrateOldViewerFields(profileData[key])
    end
    if profileData.stack and type(profileData.stack) == "table" then
        local old = profileData.stack
        for _, key in ipairs({ "essential", "utility", "buffs" }) do
            if profileData[key] then
                profileData[key].stack = DeepCopy(old)
            end
        end
        profileData.stack = nil
    end
    if profileData.trackedBarsGrowDir ~= "TOP" and profileData.trackedBarsGrowDir ~= "BOTTOM" then
        profileData.trackedBarsGrowDir = ns.defaults.trackedBarsGrowDir
    end
    MigrateOldBarFields(profileData)
end

function ns:InitDB()
    local charKey = UnitName("player") .. " - " .. GetRealmName()

    -- Detect old-format data before AceDB overwrites CDFlowDB
    local oldCharConfig = CDFlowDB_Char and CDFlowDB_Char.config and DeepCopy(CDFlowDB_Char.config)
    local oldProfiles = CDFlowDB_Profiles and next(CDFlowDB_Profiles) and DeepCopy(CDFlowDB_Profiles)
    local oldAccountConfig = nil
    if CDFlowDB and CDFlowDB.essential and not CDFlowDB.profiles then
        oldAccountConfig = DeepCopy(CDFlowDB)
        wipe(CDFlowDB)
    end

    local db = AceDB3:New("CDFlowDB", { profile = ns.defaults }, charKey)

    if LibDualSpec then
        LibDualSpec:EnhanceDatabase(db, "CDFlow")
    end

    ns.acedb = db

    -- Migrate old per-character config into current profile
    local migrated = false
    if oldCharConfig then
        MigrateOldData(oldCharConfig)
        for k, v in pairs(oldCharConfig) do
            if type(v) == "table" then
                db.profile[k] = DeepCopy(v)
            else
                db.profile[k] = v
            end
        end
        migrated = true
    elseif oldAccountConfig then
        MigrateOldData(oldAccountConfig)
        for k, v in pairs(oldAccountConfig) do
            if type(v) == "table" then
                db.profile[k] = DeepCopy(v)
            else
                db.profile[k] = v
            end
        end
        migrated = true
    end

    -- Migrate old named profiles into AceDB
    if oldProfiles then
        for name, cfg in pairs(oldProfiles) do
            MigrateOldData(cfg)
            db.sv.profiles[name] = cfg
        end
    end

    -- Clear old SavedVariables after migration
    if migrated or oldProfiles then
        CDFlowDB_Char = nil
        CDFlowDB_Profiles = nil
    end

    ns.db = db.profile
end

------------------------------------------------------
-- Profile change handler (called by Core.lua callbacks)
------------------------------------------------------

function ns:OnProfileChanged()
    ns.db = ns.acedb.profile
end
