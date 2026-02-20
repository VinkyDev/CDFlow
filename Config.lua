local _, ns = ...

------------------------------------------------------
-- 配置模块：默认值定义 + SavedVariables 管理
------------------------------------------------------

ns.defaults = {
    -- 全局样式
    iconZoom    = 0.08,     -- 图标纹理裁剪量
    borderSize  = 1,        -- 边框像素粗细
    suppressDebuffBorder = true, -- 屏蔽 debuff 红色边框
    trackedBarsGrowDir = "BOTTOM", -- 追踪状态栏增长方向：BOTTOM/TOP

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
        style     = "PIXEL",        -- DEFAULT / PIXEL / AUTOCAST / PROC / BUTTON / NONE
        lines     = 8,              -- 像素发光：线条数量
        frequency = 0.2,             -- 动画速度
        thickness = 2,              -- 像素发光：线条粗细
        scale     = 1,              -- 自动施法：缩放
    },

    -- Buff 增益高亮（所有 buff 显示时高亮）
    buffGlow = {
        enabled     = false,
        style       = "PIXEL",      -- 同 highlight
        lines       = 8,
        frequency   = 0.2,
        thickness   = 2,
        scale       = 1,
        spellFilter = {},           -- 空 = 全部高亮；非空 = 仅高亮列表中的技能ID
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
-- 序列化 / 反序列化（纯 Lua，无外部依赖）
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

function ns:ExportConfig()
    local str = SerializeValue(ns.db)
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
    local profiles = self:GetProfileList()
    profiles[profileName] = data
    return true
end

------------------------------------------------------
-- 多配置管理
------------------------------------------------------

function ns:GetProfileList()
    if not CDFlowDB_Profiles then CDFlowDB_Profiles = {} end
    return CDFlowDB_Profiles
end

function ns:SaveProfile(name)
    if not name or name == "" then return false end
    local profiles = self:GetProfileList()
    profiles[name] = DeepCopy(ns.db)
    return true
end

function ns:LoadProfile(name)
    local profiles = self:GetProfileList()
    if not profiles[name] then return false end
    CDFlowDB = DeepCopy(profiles[name])
    ns:LoadConfig()
    return true
end

function ns:DeleteProfile(name)
    local profiles = self:GetProfileList()
    if not profiles[name] then return false end
    profiles[name] = nil
    return true
end

-- 用默认值填充缺失字段（不覆盖已有值）
local function DeepMerge(dst, defaults)
    for k, v in pairs(defaults) do
        if dst[k] == nil then
            dst[k] = DeepCopy(v)
        elseif type(v) == "table" and type(dst[k]) == "table" then
            DeepMerge(dst[k], v)
        end
    end
end

-- 加载配置：合并 SavedVariables 与默认值
function ns:LoadConfig()
    if not CDFlowDB then
        CDFlowDB = DeepCopy(self.defaults)
    else
        DeepMerge(CDFlowDB, self.defaults)
        if CDFlowDB.trackedBarsGrowDir ~= "TOP" and CDFlowDB.trackedBarsGrowDir ~= "BOTTOM" then
            CDFlowDB.trackedBarsGrowDir = self.defaults.trackedBarsGrowDir
        end
        for _, key in ipairs({ "essential", "utility", "buffs" }) do
            if CDFlowDB[key] then
                CDFlowDB[key].enabled = true
                if CDFlowDB[key].showKeybind == true and CDFlowDB[key].keybind then
                    CDFlowDB[key].keybind.enabled = true
                end
                if CDFlowDB[key].stack then
                    if type(CDFlowDB[key].stack.fontName) ~= "string" then
                        CDFlowDB[key].stack.fontName = "默认"
                    end
                    if type(CDFlowDB[key].stack.textColor) ~= "table" then
                        CDFlowDB[key].stack.textColor = { 1, 1, 1, 1 }
                    end
                end
                if CDFlowDB[key].keybind then
                    CDFlowDB[key].keybind.fontPath = nil
                    if type(CDFlowDB[key].keybind.fontName) ~= "string" then
                        CDFlowDB[key].keybind.fontName = "默认"
                    end
                    if type(CDFlowDB[key].keybind.manualBySpell) ~= "table" then
                        CDFlowDB[key].keybind.manualBySpell = {}
                    end
                    if type(CDFlowDB[key].keybind.textColor) ~= "table" then
                        CDFlowDB[key].keybind.textColor = { 1, 1, 1, 1 }
                    end
                end
                if CDFlowDB[key].cooldownText then
                    CDFlowDB[key].cooldownText.fontPath = nil
                    if type(CDFlowDB[key].cooldownText.fontName) ~= "string" then
                        CDFlowDB[key].cooldownText.fontName = "默认"
                    end
                    if type(CDFlowDB[key].cooldownText.textColor) ~= "table" then
                        CDFlowDB[key].cooldownText.textColor = { 1, 0.82, 0, 1 }
                    end
                end
                CDFlowDB[key].showKeybind = nil
            end
        end
        if CDFlowDB.stack and type(CDFlowDB.stack) == "table" then
            local old = CDFlowDB.stack
            for _, key in ipairs({ "essential", "utility", "buffs" }) do
                if CDFlowDB[key] then
                    CDFlowDB[key].stack = DeepCopy(old)
                end
            end
            CDFlowDB.stack = nil
        end
    end
    -- 监控条迁移：确保 bars 内条目字段完整
    if CDFlowDB.monitorBars and type(CDFlowDB.monitorBars.bars) == "table" then
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
        for _, bar in ipairs(CDFlowDB.monitorBars.bars) do
            for k, v in pairs(barDefaults) do
                if bar[k] == nil then bar[k] = DeepCopy(v) end
            end
        end
        if type(CDFlowDB.monitorBars.nextID) ~= "number" then
            CDFlowDB.monitorBars.nextID = #CDFlowDB.monitorBars.bars + 1
        end
    end

    self.db = CDFlowDB
end
