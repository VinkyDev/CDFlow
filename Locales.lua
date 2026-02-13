local _, ns = ...

------------------------------------------------------
-- 本地化模块：中英文双语支持
------------------------------------------------------

local L = {}
ns.L = L

local isZH = (GetLocale() == "zhCN" or GetLocale() == "zhTW")

local S = {
    -- 分区
    general         = { "概览",         "Overview" },
    essential       = { "重要技能",     "Essential" },
    utility         = { "效能技能",     "Utility" },
    buffs           = { "增益效果",     "Buffs" },
    stackText       = { "堆叠文字",     "Stack Text" },

    -- 通用配置标题
    generalSettings = { "通用配置",     "General Settings" },

    -- 控件标签
    enable          = { "启用美化",     "Enable" },
    growDir         = { "布局方向",     "Layout Direction" },
    iconsPerRow     = { "每行数量",     "Icons Per Row" },
    iconWidth       = { "图标宽度",     "Icon Width" },
    iconHeight      = { "图标高度",     "Icon Height" },
    spacingX        = { "列间距",       "Column Spacing" },
    spacingY        = { "行间距",       "Row Spacing" },
    iconZoom        = { "图标裁剪",     "Icon Zoom" },
    borderSize      = { "边框粗细",     "Border Size" },
    fontSize        = { "字号",         "Font Size" },
    outline         = { "描边",         "Outline" },
    position        = { "位置",         "Position" },
    offsetX         = { "X偏移",        "X Offset" },
    offsetY         = { "Y偏移",        "Y Offset" },

    -- 布局选项
    dirDefault      = { "默认",         "Default" },
    dirCenter       = { "居中",         "Center" },

    -- 描边选项
    outNone         = { "无",           "None" },
    outOutline      = { "描边",         "Outline" },
    outThick        = { "粗描边",       "Thick" },

    -- 锚点位置
    posTL           = { "左上",         "Top Left" },
    posTR           = { "右上",         "Top Right" },
    posBL           = { "左下",         "Bottom Left" },
    posBR           = { "右下",         "Bottom Right" },
    posCenter       = { "居中",         "Center" },

    -- 高亮特效
    highlight       = { "高亮特效",     "Highlight" },
    hlStyle         = { "特效样式",     "Glow Style" },
    hlLines         = { "线条数量",     "Lines" },
    hlFrequency     = { "动画速度",     "Speed" },
    hlThickness     = { "线条粗细",     "Thickness" },
    hlScale         = { "缩放",         "Scale" },
    hlDefault       = { "默认",         "Default" },
    hlPixel         = { "像素",         "Pixel" },
    hlAutocast      = { "自动施法",     "Autocast" },
    hlProc          = { "触发光环",     "Proc" },
    hlButton        = { "按钮发光",     "Button Glow" },
    hlNone          = { "禁用",         "None" },

    -- 行覆盖
    rowOverrides    = { "行尺寸覆盖",   "Row Size Override" },
    rowSelect       = { "选择行",       "Select Row" },
    rowN            = { "第%d行",       "Row %d" },
    width           = { "宽",           "W" },
    height          = { "高",           "H" },

    -- 关于面板
    openSettings    = { "打开设置",     "Open Settings" },
    aboutDesc       = { "轻量级冷却管理器美化插件，专注简洁与实用。",
                        "Lightweight Cooldown Manager Beautifier, focused on simplicity." },
    aboutAuthor     = { "作者",         "Author" },
    aboutGithub     = { "GitHub",       "GitHub" },

    -- 概览面板
    overviewTip     = { "修改技能美化配置后，建议进入编辑模式调整冷却管理器的「图标列数」和「图标填充」，让框选区域与实际显示区域吻合，以便在编辑模式中调整位置与更智能的自动对齐。",
                        "After changing settings, enter Edit Mode and adjust the cooldown manager's Column Count and Icon Padding so the selection area matches the actual display, for better positioning and smarter auto-snapping." },

    -- 提示
    slashHelp       = { "/cdf 打开设置", "/cdf to open settings" },
    loaded          = { "已加载 - %s",      "Loaded - %s" },
}

-- 构建 L 表
local idx = isZH and 1 or 2
for k, v in pairs(S) do
    L[k] = v[idx]
end
