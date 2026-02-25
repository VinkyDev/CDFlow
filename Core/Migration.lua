-- 旧版数据迁移逻辑
local _, ns = ...

local DeepCopy = ns.DeepCopy

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

local function MigrateOldViewerFields(cfg, isCDViewer)
    if not cfg then return end
    cfg.enabled = true
    if cfg.showKeybind == true and cfg.keybind then
        cfg.keybind.enabled = true
    end
    cfg.showKeybind = nil
    -- 旧版 growDir 值迁移：Essential/Utility 的 "CENTER"/"DEFAULT" 统一迁移为 "TOP"
    if isCDViewer then
        if cfg.growDir ~= "TOP" and cfg.growDir ~= "BOTTOM" then
            cfg.growDir = "TOP"
        end
    end
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
    for _, key in ipairs({ "essential", "utility" }) do
        MigrateOldViewerFields(profileData[key], true)
    end
    MigrateOldViewerFields(profileData["buffs"], false)
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

ns.MigrateOldData = MigrateOldData
