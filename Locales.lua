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
    rowAnchor       = { "行内锚点",     "Row Anchor" },
    trackedBarsGrowDir = { "生长方向", "Growth Direction" },
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

    -- 行内锚点（左/中/右）
    anchorLeft      = { "左",           "Left" },
    anchorCenter    = { "中",           "Center" },
    anchorRight     = { "右",           "Right" },
    -- 布局方向选项（重要技能 / 效能技能）
    dirGrowDown     = { "向下增长",                 "Grow Down" },
    dirGrowUp       = { "向上增长",                 "Grow Up" },
    -- 布局方向选项（增益效果）
    dirBuffCenter   = { "从中间增长",               "Grow from Center" },
    dirBuffDefault  = { "固定位置（系统默认）",     "Fixed (System Default)" },
    -- 追踪状态栏方向
    dirTop          = { "顶部向下",     "Top to Bottom" },
    dirBottom       = { "底部向上",     "Bottom to Top" },
    dirTbCenter     = { "从中间",       "From Center" },
    dirTbTop        = { "从上到下",     "Top to Bottom" },
    dirTbBottom     = { "从下到上",     "Bottom to Top" },

    -- 追踪状态栏 Tab
    trackedBars          = { "追踪状态栏",       "Tracked Bars" },
    tbLayout             = { "布局",             "Layout" },
    tbAppearance         = { "外观",             "Appearance" },
    tbBarHeight          = { "条高度",           "Bar Height" },
    tbSpacing            = { "条间距",           "Bar Spacing" },
    tbIconPosition       = { "图标位置",         "Icon Position" },
    tbIconLeft           = { "左侧",             "Left" },
    tbIconRight          = { "右侧",             "Right" },
    tbIconHidden         = { "隐藏图标",         "Hide Icon" },
    tbBarTexture         = { "材质",              "Texture" },
    tbBarColor           = { "条前景色",         "Bar Color" },
    tbBgColor            = { "背景颜色",         "Background Color" },
    tbNameText           = { "名称文字",         "Name Text" },
    tbDurationText       = { "时长文字",         "Duration Text" },
    tbShowName           = { "显示技能名称",     "Show Spell Name" },
    tbShowDuration       = { "显示剩余时长",     "Show Duration" },

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

    -- 显示规则
    visibilityRules      = { "冷却管理器显示规则",       "Cooldown Manager Visibility" },
    visibilityMode       = { "显示模式",               "Visibility Mode" },
    visModeAlways        = { "始终显示",               "Always Visible" },
    visModeCombat        = { "仅在战斗中显示",         "Show Only in Combat" },
    visModeTarget        = { "有目标时显示",           "Show With Target" },
    visModeCombatOrTarget= { "战斗中或有目标时显示",   "Show in Combat or With Target" },
    visHideMounted       = { "骑乘时隐藏",             "Hide When Mounted" },
    visHideVehicles      = { "载具/特殊场景中隐藏",    "Hide in Vehicles & Override Bar" },

    -- 自定义遮罩层
    swipeOverlay    = { "自定义遮罩层",   "Custom Swipe Overlay" },
    swipeActiveColor= { "激活状态遮罩色", "Active Aura Color" },
    swipeCDColor    = { "冷却遮罩色",     "Cooldown Swipe Color" },

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

    -- 概览快捷操作
    openEditMode    = { "打开编辑模式",   "Open Edit Mode" },
    openCDMSettings = { "打开冷却管理器设置", "Open Cooldown Manager Settings" },

    -- 重置
    resetDefaults   = { "重置为默认配置", "Reset to Defaults" },
    resetConfirm    = { "确认重置？所有配置将恢复为默认值，此操作不可撤销。", "Confirm reset? All settings will be restored to defaults. This cannot be undone." },

    -- 配置文件
    profiles            = { "配置文件",       "Profiles" },
    profileDesc         = { "你可以为每个角色设置不同的配置文件，也可以在角色之间共享同一配置。",
                            "You can have different settings for each character, or share a profile between characters." },
    profileCurrent      = { "当前配置文件:",  "Current Profile:" },
    profileNew          = { "新建",           "New" },
    profileNewDesc      = { "输入名称创建新配置文件", "Enter a name to create a new profile" },
    profileChoose       = { "选择配置文件",   "Existing Profiles" },
    profileChooseDesc   = { "选择一个已有的配置文件", "Select an existing profile to switch to" },
    profileCopyFrom     = { "复制自",         "Copy From" },
    profileCopyDesc     = { "将其他配置文件的设置复制到当前配置", "Copy settings from another profile into the current one" },
    profileDelete       = { "删除配置文件",   "Delete a Profile" },
    profileDeleteConfirm= { "确定要删除选中的配置文件吗？", "Are you sure you want to delete the selected profile?" },
    profileDeleteDesc   = { "删除不再使用的配置文件", "Delete unused profiles to save space" },
    profileReset        = { "重置配置文件",   "Reset Profile" },
    profileResetDesc    = { "将当前配置文件恢复为默认值", "Reset the current profile to default values" },
    profileResetConfirm = { "确认重置？当前配置将恢复为默认值，此操作不可撤销。",
                            "Confirm reset? Current profile will be restored to defaults. This cannot be undone." },
    profileCreated      = { "已创建配置: %s", "Profile created: %s" },
    profileLoaded       = { "已切换配置: %s", "Profile loaded: %s" },
    profileCopied       = { "已复制配置: %s", "Profile copied: %s" },
    profileDeleted      = { "已删除配置: %s", "Profile deleted: %s" },
    profileResetDone    = { "已重置配置: %s", "Profile reset: %s" },
    profileCantDeleteCurrent = { "无法删除当前正在使用的配置文件", "Cannot delete the active profile" },
    profileNoName       = { "请输入配置名称", "Enter a profile name" },

    -- 专精配置
    specProfileEnable   = { "启用专精配置文件", "Enable Spec Profiles" },
    specProfileDesc     = { "启用后，切换专精时自动切换到对应的配置文件。",
                            "When enabled, your profile will automatically switch when you change specialization." },
    specProfileCurrent  = { "%s - 当前",      "%s - Active" },

    -- 导入导出
    importExport    = { "导入 / 导出",      "Import / Export" },
    exportBtn       = { "导出当前配置",     "Export Current Config" },
    importBtn       = { "导入配置",         "Import Config" },
    exportHint      = { "复制下方字符串分享给其他人", "Copy the string below to share" },
    importHint      = { "粘贴配置字符串",   "Paste config string" },
    importName      = { "导入为配置名称",   "Import As Profile Name" },
    importSuccess   = { "已导入配置: %s",   "Imported profile: %s" },
    importFail      = { "导入失败: %s",     "Import failed: %s" },

    -- 提示
    slashHelp       = { "/cdf 打开设置", "/cdf to open settings" },
    loaded          = { "已加载 - %s",      "Loaded - %s" },

    -- 监控条
    monitorBars         = { "监控条",           "Monitor Bars" },
    mbLocked            = { "锁定所有位置",     "Lock All Positions" },
    mbUnlockHint        = { "解锁后可拖动条到任意位置", "Unlock to drag bars freely" },
    mbNudgeHint         = { "滚轮微调 | Shift=水平 | Ctrl=大步进", "Scroll to nudge | Shift=horizontal | Ctrl=10px" },
    mbAddBar            = { "添加监控条",       "Add Monitor Bar" },
    mbManualAdd         = { "手动输入技能ID",   "Manual Spell ID" },
    mbDeleteBar         = { "删除",             "Delete" },
    mbDeleteConfirm     = { "确认删除？",       "Confirm delete?" },
    mbBarType           = { "类型",             "Type" },
    mbTypeStack         = { "Buff堆叠",         "Buff Stacks" },
    mbTypeCharge        = { "技能充能/技能冷却", "Spell Charges/Cooldown" },
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
    mbShowTextCharge    = { "显示当前层冷却",   "Show Charge Cooldown" },
    mbShowTextStack     = { "显示层数",         "Show Stack Count" },
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
    mbCatalogCooldowns  = { "技能（点击添加充能/冷却条）", "Spells (click to add charge/cooldown bar)" },
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
    mbBorderStyle       = { "边框样式",         "Border Style" },
    mbBorderWhole       = { "整体边框",         "Whole Border" },
    mbBorderSegment     = { "分段边框",         "Per-Segment Border" },
    mbSegmentGap        = { "分段间距",         "Segment Gap" },
    mbShowCondition     = { "显示条件",         "Show Condition" },
    mbCondAlways        = { "始终显示",         "Always" },
    mbCondCombat        = { "仅战斗中显示",     "Only in Combat" },
    mbCondTarget        = { "有目标时显示",     "When Has Target" },

    -- 增益自定义分组
    buffGroups          = { "自定义分组",       "Buff Groups" },
    bgAddGroup          = { "新建分组",         "Add Group" },
    bgDeleteGroup       = { "删除此组",         "Delete Group" },
    bgGroupName         = { "分组名称",         "Group Name" },
    bgGroupLayout       = { "分组布局",         "Layout Direction" },
    bgLayoutHorizontal  = { "水平",             "Horizontal" },
    bgLayoutVertical    = { "垂直",             "Vertical" },
    bgLockAll           = { "锁定所有分组位置", "Lock All Group Positions" },
    bgAddBuff           = { "添加 Buff",        "Add Buff" },
    bgCatalogTitle      = { "Buff 目录",        "Buff Catalog" },
    bgNudgeHint         = { "拖动或滚轮微调位置 | Shift=水平 | Ctrl=大步进", "Drag or scroll to adjust | Shift=horizontal | Ctrl=10px" },
    bgRemoveSpell       = { "移除",             "Remove" },
    bgSpellHint         = { "输入技能ID后点击「添加 Buff」", "Enter a spell ID and click Add Buff" },
    bgNoGroups          = { "暂无自定义分组，点击「新建分组」创建", "No groups yet. Click Add Group to create one." },
    bgGroupTitle        = { "分组 %d：%s",      "Group %d: %s" },
    bgDragHint          = { "解锁后可拖动此分组", "Unlock to drag this group" },
    bgSpellListTitle    = { "已添加 Buff",      "Added Buffs" },
    bgSpellListEmpty    = { "（空）",           "(empty)" },
    bgSpellPreviewOk    = { "技能名称: %s",     "Spell: %s" },
    bgSpellPreviewErr   = { "无效的技能ID",     "Invalid spell ID" },
    bgSelectGroup       = { "选择分组",         "Select Group" },
    bgNoGroup           = { "无分组",           "No groups" },
    bgCatalogEmpty      = { "未找到可用 Buff，请先脱战", "No buffs found, leave combat first" },
    bgManualAdd         = { "手动输入技能ID",   "Manual Spell ID" },
    bgCDMHint           = { "提示：分组内 Buff 必须在冷却管理器中追踪才能显示；编辑模式下可预览分组位置",
                            "Note: Buffs in groups must be tracked in the Cooldown Manager; use Edit Mode to preview group positions" },

    -- 功能模块
    moduleManage        = { "功能模块",                                       "Modules" },
    moduleReloadHint    = { "切换模块后需 /reload 重载界面生效",              "Module changes require /reload to take effect" },
    moduleCDMBeautify   = { "冷却管理器美化",                                 "CDM Beautifier" },
    moduleCDMBeautifyD  = { "图标样式、布局引擎、文字叠层、高亮特效",         "Icon style, layout engine, text overlays, highlight effects" },
    moduleMonitorBars   = { "监控条",                                         "Monitor Bars" },
    moduleMonitorBarsD  = { "自定义技能充能/冷却/Buff堆叠监控条",            "Custom spell charge/cooldown/buff stack monitor bars" },
}

-- 构建 L 表
local idx = isZH and 1 or 2
for k, v in pairs(S) do
    L[k] = v[idx]
end
