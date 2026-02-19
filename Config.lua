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

}

-- 深拷贝
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = DeepCopy(v) end
    return t
end
ns.DeepCopy = DeepCopy

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
    self.db = CDFlowDB
end
