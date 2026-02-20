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

    -- 配置管理
    profileManage   = { "配置管理",         "Profile Management" },
    profileName     = { "配置名称",         "Profile Name" },
    profileSave     = { "保存当前配置",     "Save Current" },
    profileLoad     = { "加载配置",         "Load Profile" },
    profileDelete   = { "删除配置",         "Delete Profile" },
    profileSelect   = { "选择配置",         "Select Profile" },
    profileSaved    = { "配置已保存: %s",   "Profile saved: %s" },
    profileLoaded   = { "配置已加载: %s",   "Profile loaded: %s" },
    profileDeleted  = { "配置已删除: %s",   "Profile deleted: %s" },
    profileNoName   = { "请输入配置名称",   "Please enter a profile name" },
    profileNone     = { "无已保存配置",     "No saved profiles" },

    -- 导入导出
    importExport    = { "导入/导出",        "Import / Export" },
    exportBtn       = { "导出配置",         "Export Config" },
    importBtn       = { "导入配置",         "Import Config" },
    exportHint      = { "复制下方字符串以导出", "Copy the string below to export" },
    importName      = { "导入配置名称",     "Import Profile Name" },
    importHint      = { "粘贴配置字符串后点击导入", "Paste config string then click Import" },
    importSuccess   = { "已导入为配置: %s", "Imported as profile: %s" },
    importFail      = { "导入失败: %s",     "Import failed: %s" },

    -- 提示
    slashHelp       = { "/cdf 打开设置", "/cdf to open settings" },
    loaded          = { "已加载 - %s",      "Loaded - %s" },

    -- 监控条
    monitorBars         = { "监控条",           "Monitor Bars" },
    mbLocked            = { "锁定所有位置",     "Lock All Positions" },
    mbUnlockHint        = { "解锁后可拖动条到任意位置", "Unlock to drag bars freely" },
    mbAddBar            = { "添加监控条",       "Add Monitor Bar" },
    mbManualAdd         = { "手动输入技能ID",   "Manual Spell ID" },
    mbDeleteBar         = { "删除",             "Delete" },
    mbDeleteConfirm     = { "确认删除？",       "Confirm delete?" },
    mbBarType           = { "类型",             "Type" },
    mbTypeStack         = { "Buff堆叠",         "Buff Stacks" },
    mbTypeCharge        = { "技能充能",         "Spell Charges" },
    mbSpellID           = { "技能ID",           "Spell ID" },
    mbSpellName         = { "技能名称",         "Spell Name" },
    mbUnit              = { "监控单位",         "Unit" },
    mbUnitPlayer        = { "自身",             "Player" },
    mbUnitTarget        = { "目标",             "Target" },
    mbMaxStacks         = { "最大层数",         "Max Stacks" },
    mbMaxCharges        = { "最大充能",         "Max Charges" },
    mbMaxChargesAuto    = { "0 = 自动检测",     "0 = Auto detect" },
    mbBarWidth          = { "条宽度",           "Bar Width" },
    mbBarHeight         = { "条高度",           "Bar Height" },
    mbBarColor          = { "条颜色",           "Bar Color" },
    mbBgColor           = { "背景颜色",         "Background Color" },
    mbBorderColor       = { "边框颜色",         "Border Color" },
    mbBorderSize        = { "边框粗细",         "Border Size" },
    mbShowIcon          = { "显示图标",         "Show Icon" },
    mbShowText          = { "显示文字",         "Show Text" },
    mbTextAlign         = { "文字位置",         "Text Alignment" },
    mbTextAlignLeft     = { "靠左",             "Left" },
    mbTextAlignCenter   = { "居中",             "Center" },
    mbTextAlignRight    = { "靠右",             "Right" },
    mbTextOffsetX       = { "文字X偏移",        "Text X Offset" },
    mbTextOffsetY       = { "文字Y偏移",        "Text Y Offset" },
    mbNoSpell           = { "未设置技能",       "No spell set" },
    mbScanHint          = { "脱战后自动扫描CDM", "Auto-scan CDM out of combat" },
    mbPreview           = { "预览",             "Preview" },
    mbSelectBar         = { "选择监控条",       "Select Bar" },
    mbNoBar             = { "无监控条",         "No bars" },
    mbScanCatalog       = { "扫描技能目录",     "Scan Spell Catalog" },
    mbScanCombatWarn    = { "战斗中无法扫描",   "Cannot scan in combat" },
    mbCatalogCooldowns  = { "技能（点击添加充能条）", "Spells (click to add charge bar)" },
    mbCatalogAuras      = { "Buff/Debuff（点击添加堆叠条）", "Buffs/Debuffs (click to add stack bar)" },
    mbCatalogEmpty      = { "未扫描到技能，请先脱战", "No spells found, leave combat first" },
    mbBarTexture        = { "条材质",           "Bar Texture" },
    mbCDMHint           = { "提示：Buff堆叠条需要对应Buff已在冷却管理器中", "Note: buff stack bars require the buff to be in the Cooldown Manager" },
    mbHideFromCDM       = { "在冷却管理器中隐藏",  "Hide from Cooldown Manager" },
    mbColorThreshold    = { "染色阈值",         "Color Threshold" },
    mbColorThresholdTip = { "0 = 关闭；大于等于此层数时条颜色变化", "0 = off; bar color changes above this count" },
    mbThresholdColor    = { "阈值颜色",         "Threshold Color" },
    mbSpecs             = { "专精显示",         "Spec Visibility" },
    mbSpecAll           = { "所有专精",         "All Specs" },
    mbSpecCurrent       = { "仅当前专精",       "Current Spec Only" },
    mbSpec              = { "专精%d",           "Spec %d" },
    mbAdded             = { "已添加: %s",       "Added: %s" },
}

-- 构建 L 表
local idx = isZH and 1 or 2
for k, v in pairs(S) do
    L[k] = v[idx]
end
