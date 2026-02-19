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
    keybindText     = { "键位显示",     "Keybind" },

    -- 通用配置标题
    generalSettings = { "通用配置",     "General Settings" },

    -- 控件标签
    enable          = { "启用",         "Enable" },
    customizeStyle  = { "自定义样式",   "Customize Style" },
    enableDisplay   = { "启用显示",     "Enable Display" },
    growDir         = { "布局方向",     "Layout Direction" },
    trackedBarsGrowDir = { "追踪状态栏方向", "Tracked Bars Direction" },
    iconsPerRow     = { "每行数量",     "Icons Per Row" },
    iconsPerRowTip  = { "0 = 不限制，单行/单列显示。推荐设为 0。", "0 = unlimited, single row/column. Recommended: 0." },
    iconWidth       = { "图标宽度",     "Icon Width" },
    iconHeight      = { "图标高度",     "Icon Height" },
    spacingX        = { "列间距",       "Column Spacing" },
    spacingY        = { "行间距",       "Row Spacing" },
    iconZoom        = { "图标裁剪",     "Icon Zoom" },
    borderSize      = { "边框粗细",     "Border Size" },
    suppressDebuffBorder = { "屏蔽 Debuff 红框", "Suppress Debuff Border" },
    fontSize        = { "字号",         "Font Size" },
    fontFamily      = { "字体",         "Font" },
    textColor       = { "文字颜色",     "Text Color" },
    outline         = { "描边",         "Outline" },
    position        = { "位置",         "Position" },
    offsetX         = { "X偏移",        "X Offset" },
    offsetY         = { "Y偏移",        "Y Offset" },
    colorR          = { "红色",         "Red" },
    colorG          = { "绿色",         "Green" },
    colorB          = { "蓝色",         "Blue" },
    colorA          = { "透明度",       "Alpha" },
    spellID         = { "技能ID",       "Spell ID" },
    displayText     = { "显示文本",     "Display Text" },
    addOrUpdate     = { "添加/更新",    "Add/Update" },
    remove          = { "删除",         "Remove" },
    manualOverride  = { "手动覆盖",     "Manual Override" },
    manualListTitle = { "当前覆盖列表", "Current Overrides" },
    manualListHint  = { "无法自动识别或识别错误时，可按技能ID手动指定显示文本。", "Set display text by spell ID when auto-detection fails." },
    needReloadHint  = { "如果某些外部插件接管了同一文本，关闭后可能需要 /reload 才完全恢复。", "If another addon controls the same text, you may need /reload after disabling." },

    -- 布局选项
    dirDefault      = { "默认",         "Default" },
    dirCenter       = { "居中",         "Center" },
    dirTop          = { "顶部向下",     "Top to Bottom" },
    dirBottom       = { "底部向上",     "Bottom to Top" },

    -- 描边选项
    outNone         = { "无",           "None" },
    outOutline      = { "描边",         "Outline" },
    outThick        = { "粗描边",       "Thick" },


    -- 锚点位置
    posTL           = { "左上",         "Top Left" },
    posTR           = { "右上",         "Top Right" },
    posTop          = { "顶部",         "Top" },
    posBL           = { "左下",         "Bottom Left" },
    posBR           = { "右下",         "Bottom Right" },
    posCenter       = { "居中",         "Center" },

    -- 高亮特效
    highlight           = { "高亮特效",         "Highlight" },
    skillGlow           = { "技能激活高亮",     "Skill Glow" },
    buffGlow            = { "增益高亮",         "Buff Glow" },
    enableBuffGlow      = { "开启 Buff 高亮显示", "Enable Buff Glow" },
    buffGlowFilter      = { "技能 ID 过滤",     "Spell ID Filter" },
    buffGlowFilterHint  = { "指定后，仅对列表中的技能显示增益高亮；列表为空时对全部技能生效。", "When set, buff glow only applies to listed spell IDs. Empty = apply to all." },
    buffGlowFilterTitle = { "过滤列表",         "Filter List" },
    buffGlowFilterAdd   = { "添加",             "Add" },
    buffGlowFilterRemove= { "移除",             "Remove" },
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
    cooldownText    = { "冷却读秒",     "Cooldown Text" },
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

    -- 概览快捷操作
    openEditMode    = { "打开编辑模式",   "Open Edit Mode" },
    openCDMSettings = { "打开冷却管理器设置", "Open Cooldown Manager Settings" },

    -- 重置
    resetDefaults   = { "重置为默认配置", "Reset to Defaults" },
    resetConfirm    = { "确认重置？所有配置将恢复为默认值，此操作不可撤销。", "Confirm reset? All settings will be restored to defaults. This cannot be undone." },

    -- 提示
    slashHelp       = { "/cdf 打开设置", "/cdf to open settings" },
    loaded          = { "已加载 - %s",      "Loaded - %s" },
}

-- 构建 L 表
local idx = isZH and 1 or 2
for k, v in pairs(S) do
    L[k] = v[idx]
end
