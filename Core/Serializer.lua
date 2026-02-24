-- Base64 编解码、Lua 序列化、配置导入导出
local _, ns = ...

local DeepCopy = ns.DeepCopy

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
