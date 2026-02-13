local _, ns = ...

------------------------------------------------------
-- 配置模块：默认值定义 + SavedVariables 管理
------------------------------------------------------

ns.defaults = {
    -- 全局样式
    iconZoom    = 0.08,     -- 图标纹理裁剪量
    borderSize  = 1,        -- 边框像素粗细

    -- 核心技能查看器
    essential = {
        enabled     = true,
        growDir     = "CENTER",     -- CENTER = 居中 / DEFAULT = 游戏默认
        iconsPerRow = 8,
        iconWidth   = 52,
        iconHeight  = 52,
        spacingX    = 2,
        spacingY    = 2,
        rowOverrides = {},          -- [行号] = {width, height}
    },

    -- 工具技能查看器
    utility = {
        enabled     = true,
        growDir     = "CENTER",
        iconsPerRow = 6,
        iconWidth   = 30,
        iconHeight  = 30,
        spacingX    = 2,
        spacingY    = 2,
        rowOverrides = {},
    },

    -- 增益图标查看器
    buffs = {
        enabled     = true,
        growDir     = "CENTER",
        iconsPerRow = 0,            -- 0 = 不限制，单行显示
        iconWidth   = 40,
        iconHeight  = 40,
        spacingX    = 2,
        spacingY    = 2,
        rowOverrides = {},
    },

    -- 高亮特效
    highlight = {
        style     = "PIXEL",        -- DEFAULT / PIXEL / AUTOCAST / PROC / BUTTON / NONE
        lines     = 8,              -- 像素发光：线条数量
        frequency = 0.2,           -- 动画速度
        thickness = 2,              -- 像素发光：线条粗细
        scale     = 1,              -- 自动施法：缩放
    },

    -- 堆叠文字
    stack = {
        enabled     = false,
        fontSize    = 12,
        outline     = "OUTLINE",    -- NONE / OUTLINE / THICKOUTLINE
        point       = "BOTTOMRIGHT",
        offsetX     = 0,            -- X 偏移（像素）
        offsetY     = 0,            -- Y 偏移（像素）
    },
}

-- 深拷贝
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local t = {}
    for k, v in pairs(src) do t[k] = DeepCopy(v) end
    return t
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
    end
    self.db = CDFlowDB
end
