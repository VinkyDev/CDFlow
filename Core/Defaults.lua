-- 默认配置模板 + 深拷贝工具
local _, ns = ...

ns.defaults = {
    -- 功能模块开关
    modules = {
        cdmBeautify = true,
        monitorBars = true,
        trackedBars = true,
        itemMonitor = true,
        tts         = true,
    },

    -- 全局样式
    iconBeautify = true,
    iconZoom    = 0.08,
    borderSize  = 1,
    suppressDebuffBorder = true,

    -- 追踪状态栏
    trackedBars = {
        anchor           = "CENTER",
        x                = 0,
        y                = 0,
        growDir          = "CENTER",
        barHeight        = 20,
        spacing          = 2,
        iconPosition     = "LEFT",
        barTexture       = "Solid",
        barColor         = { 0.4, 0.6, 0.9, 1.0 },
        bgColor          = { 0.1, 0.1, 0.1, 0.8 },
        showName         = true,
        nameFontSize     = 12,
        nameFontName     = "默认",
        nameOutline      = "OUTLINE",
        nameColor        = { 1, 1, 1, 1 },
        showDuration     = true,
        durationFontSize = 12,
        durationFontName = "默认",
        durationOutline  = "OUTLINE",
        durationColor    = { 1, 1, 1, 1 },
    },

    -- 核心技能查看器
    essential = {
        enabled     = true,
        growDir     = "TOP",
        rowAnchor   = "CENTER",
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
        rowAnchor   = "CENTER",
        iconsPerRow = 5,
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
        buffOffsetX = 0,
        buffOffsetY = 0,
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

    -- 技能可用高亮（冷却完毕时高亮）
    spellHighlight = {
        enabled     = false,
        combatOnly  = false,
        style       = "PIXEL",
        lines       = 8,
        frequency   = 0.2,
        thickness   = 2,
        scale       = 1,
        spellFilter = {},  -- [spellID] = true，为空时不生效
    },

    -- 监控条
    monitorBars = {
        locked = false,
        nextID = 1,
        bars   = {},
    },

    -- 增益自定义分组
    -- 每个元素：{ name, horizontal, x, y, spellIDs={[spellID]=true} }
    buffGroupsLocked = true,
    buffGroups = {},

    -- 0号组：饰品&药水（特殊组，基于物品ID监控）
    buffGroup0 = {
        enabled           = true,   -- 是否启用0号组
        autoTrinkets      = true,   -- 自动检测主动饰品
        potionItemIDs     = { 212265, 241308, 241288, 241296, 241292 }, -- 药水物品ID列表
        name              = nil,    -- 自定义名称
        horizontal        = false,
        x                 = 100,
        y                 = 0,
        overrideSize      = true,
        iconWidth         = 32,
        iconHeight        = 32,
    },

    -- 物品监控
    itemMonitor = {
        locked      = false,
        posX        = 0,
        posY        = -340,
        growDir     = "TOP",
        rowAnchor   = "CENTER",
        iconsPerRow = 6,
        iconWidth   = 40,
        iconHeight  = 40,
        spacingX    = 2,
        spacingY    = 2,
        items       = {},   -- array of { type="item"|"spell", id=N }；向后兼容裸 number
        itemCount = {
            enabled   = true,
            fontSize   = 12,
            whenZero   = "gray",   -- "gray" = 整颗图标变灰; "hide" = 整颗图标隐藏
            offsetX    = -2,
            offsetY    = 2,
        },
        keybind = {
            enabled      = false,
            fontSize     = 10,
            fontName     = "默认",
            outline      = "OUTLINE",
            textColor    = { 1, 1, 1, 1 },
            point        = "TOPRIGHT",
            offsetX      = 0,
            offsetY      = -2,
            manualByItem  = {},
            manualBySpell = {},
        },
        cooldownText = {
            enabled   = false,
            fontSize  = 14,
            fontName  = "默认",
            outline   = "OUTLINE",
            textColor = { 1, 0.82, 0, 1 },
            point     = "CENTER",
            offsetX   = 0,
            offsetY   = 0,
        },
    },

    -- TTS 自定义播报别名：[spellID] = "自定义文字"
    -- 当冷却管理器触发 TTS 播报时，用自定义文字替代默认技能名称
    ttsAliases = {},

    -- 小地图按钮
    minimap = {
        hide = false,
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
