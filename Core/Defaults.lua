-- 默认配置模板 + 深拷贝工具
local _, ns = ...

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
        growDir     = "TOP",
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
        swipeOverlay = {
            enabled         = false,
            activeAuraColor = { 1, 0.95, 0.57, 0.69 },
            cdSwipeColor    = { 0, 0, 0, 0.69 },
        },
    },

    utility = {
        enabled     = true,
        growDir     = "TOP",
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
        swipeOverlay = {
            enabled         = false,
            activeAuraColor = { 1, 0.95, 0.57, 0.69 },
            cdSwipeColor    = { 0, 0, 0, 0.69 },
        },
    },

    buffs = {
        enabled    = true,
        growDir    = "CENTER",
        iconWidth  = 40,
        iconHeight = 40,
        spacingX   = 2,
        spacingY   = 2,
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
        swipeOverlay = {
            enabled         = false,
            activeAuraColor = { 1, 0.95, 0.57, 0.69 },
            cdSwipeColor    = { 0, 0, 0, 0.69 },
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

    -- 显示规则
    visibility = {
        mode            = "ALWAYS",
        hideWhenMounted = false,
        hideInVehicles  = false,
    },
}

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = DeepCopy(v) end
    return t
end
ns.DeepCopy = DeepCopy
