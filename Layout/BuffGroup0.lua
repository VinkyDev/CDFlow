local _, ns = ...

------------------------------------------------------
-- 0号组：饰品&药水监控
--
-- 基于物品ID的独立监控系统，不依赖CDM
-- 监控主动饰品（槽位13/14）+ 手动配置的药水物品
------------------------------------------------------

local Layout = ns.Layout

-- 图标帧池：{[spellID] = {frame, icon, cooldown, itemID, duration, isAuto}}
local iconPool = {}

-- 自动检测的饰品列表（用于UI显示）
local autoDetectedItems = {}  -- {itemID = true}

-- 0号组容器
local group0Container = nil
local previewIcons = {}  -- 预览图标池
local previewActive = false

------------------------------------------------------
-- 工具函数
------------------------------------------------------

local function RoundToPixel(v)
    return math.floor(v + 0.5)
end

local function ScreenToCenterOffset(frame)
    local cx, cy = frame:GetCenter()
    if not cx or not cy then return 0, 0 end
    local sx, sy = UIParent:GetCenter()
    if not sx or not sy then return 0, 0 end
    return RoundToPixel(cx - sx), RoundToPixel(cy - sy)
end

-- 从文本解析持续时间
local function ParseDuration(text)
    if not text or text == "" then return nil end
    -- 排除冷却时间行（避免误判）
    if text:find("冷却") or text:find("Cooldown") then return nil end

    -- 匹配 "持续 x 秒"
    local s = text:match("持续%s*(%d+)%s*秒")
    if s then return tonumber(s) end
    
    -- 匹配 "for x sec"
    s = text:match("for%s*(%d+)%s*sec")
    if s then return tonumber(s) end
    
    -- 匹配 "持续 x 分钟"
    local m = text:match("持续%s*(%d+)%s*分钟")
    if m then return tonumber(m) * 60 end
    
    -- 匹配 "for x min"
    m = text:match("for%s*(%d+)%s*min")
    if m then return tonumber(m) * 60 end
    
    -- 宽松匹配：如果在描述中直接出现 "x seconds" 且不在冷却行
    s = text:match("(%d+)%s*seconds") or text:match("(%d+)%s*sec")
    if s then return tonumber(s) end
    
    s = text:match("(%d+)%s*秒")
    if s then return tonumber(s) end

    return nil
end

-- 从物品ID获取法术ID和持续时间
local scanTooltip = nil
local function GetItemSpellInfo(itemID)
    if not itemID then return nil, nil end
    local _, spellID = C_Item.GetItemSpell(itemID)
    if not spellID then return nil, nil end

    -- 1. 优先尝试直接获取法术描述
    local desc = C_Spell.GetSpellDescription(spellID)
    if desc then
        local d = ParseDuration(desc)
        if d then return spellID, d end
    end

    -- 2. 尝试 C_TooltipInfo
    if C_TooltipInfo then
        -- 试 Spell
        local data = C_TooltipInfo.GetSpellByID(spellID)
        if data and data.lines then
            for _, line in ipairs(data.lines) do
                local d = ParseDuration(line.leftText)
                if d then return spellID, d end
            end
        end
    end

    -- 3. Tooltip 扫描
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "CDFlow_BuffGroup0_Tooltip", nil, "GameTooltipTemplate")
        scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    scanTooltip:ClearLines()
    scanTooltip:SetSpellByID(spellID)
    for i = 1, scanTooltip:NumLines() do
        local line = _G["CDFlow_BuffGroup0_TooltipTextLeft" .. i]
        local text = line and line:GetText()
        local d = ParseDuration(text)
        if d then return spellID, d end
    end
    scanTooltip:Hide()

    return spellID, nil
end

------------------------------------------------------
-- 图标帧创建
------------------------------------------------------

local function CreateIconFrame()
    local cfg = ns.db and ns.db.buffGroup0
    local size = (cfg and cfg.overrideSize) and cfg.iconWidth or 40

    local frame = CreateFrame("Frame", nil, group0Container)
    frame:SetSize(size, size)
    frame:Hide()

    -- 创建Icon纹理（模拟CDM图标结构）
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    frame.Icon = icon  -- 关键：让Style:ApplyIcon能找到Icon

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    cooldown:SetHideCountdownNumbers(false)
    cooldown:SetDrawEdge(false) -- 隐藏旋转的边缘（黄线）
    cooldown:SetUseCircularEdge(false) -- 禁用圆形遮罩模式
    cooldown:SetReverse(true)
    cooldown:SetScript("OnCooldownDone", function()
        frame:Hide()
        Layout:RefreshBuffGroup0Layout()
    end)

    -- 设置倒计时文字字体
    local regions = {cooldown:GetRegions()}
    for _, region in ipairs(regions) do
        if region.GetText then
            region:SetFont(STANDARD_TEXT_FONT, 16, "OUTLINE")
        end
    end

    frame.Cooldown = cooldown  -- 让Style能找到Cooldown

    -- 应用图标美化
    local zoom = ns.db and ns.db.iconZoom or 0.08
    local borderSize = ns.db and ns.db.borderSize or 1
    if ns.Style and ns.Style.ApplyIcon then
        ns.Style:ApplyIcon(frame, size, size, zoom, borderSize)
    end

    return frame, icon, cooldown
end

------------------------------------------------------
-- 容器管理
------------------------------------------------------

local function IsBuffGroupsLocked()
    return ns.db and ns.db.buffGroupsLocked or false
end

local function UpdateContainerPosLabel(container, group)
    if not container._bgPosLabel then return end
    local x = group and group.x or 0
    local y = group and group.y or 0
    container._bgPosLabel:SetFormattedText("X: %.0f  Y: %.0f", x, y)
end

local function SetupContainerDrag(container)
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    container:RegisterForDrag("LeftButton")
    container:EnableMouseWheel(true)

    -- 坐标显示标签
    if not container._bgPosLabel then
        local posLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        posLabel:SetPoint("TOP", container, "BOTTOM", 0, -4)
        posLabel:SetTextColor(1, 0.82, 0, 1)
        container._bgPosLabel = posLabel
    end

    -- 提示文字
    if not container._bgHelperText then
        local txt = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("BOTTOM", container, "TOP", 0, 6)
        txt:SetText(ns.L and ns.L.bgNudgeHint or "Drag or scroll to adjust")
        txt:SetTextColor(0.8, 0.8, 0.8, 1)
        container._bgHelperText = txt
    end

    container:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        if IsBuffGroupsLocked() then return end
        self:StartMoving()
        self:SetScript("OnUpdate", function(s)
            local cx, cy = s:GetCenter()
            local sx, sy = UIParent:GetCenter()
            if cx and cy and sx and sy then
                local px = RoundToPixel(cx - sx)
                local py = RoundToPixel(cy - sy)
                if s._bgPosLabel then
                    s._bgPosLabel:SetFormattedText("X: %.0f  Y: %.0f", px, py)
                end
            end
        end)
    end)

    container:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetScript("OnUpdate", nil)
        local cfg = ns.db and ns.db.buffGroup0
        if not cfg then return end

        local x, y = ScreenToCenterOffset(self)
        cfg.x = x
        cfg.y = y

        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", x, y)
        UpdateContainerPosLabel(self, cfg)
    end)

    container:SetScript("OnMouseWheel", function(self, delta)
        if InCombatLockdown() then return end
        if IsBuffGroupsLocked() then return end
        local cfg = ns.db and ns.db.buffGroup0
        if not cfg then return end

        local step = IsControlKeyDown() and 10 or 1
        if IsShiftKeyDown() then
            cfg.x = (cfg.x or 0) + delta * step
        else
            cfg.y = (cfg.y or 0) + delta * step
        end
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", cfg.x, cfg.y)
        UpdateContainerPosLabel(self, cfg)
    end)

    container:SetScript("OnEnter", function(self)
        if not IsBuffGroupsLocked() then
            if self._bgHelperText then self._bgHelperText:Show() end
            if self._bgPosLabel   then self._bgPosLabel:Show() end
        end
    end)

    container:SetScript("OnLeave", function(self)
        if self._bgHelperText then self._bgHelperText:Hide() end
        if self._bgPosLabel   then self._bgPosLabel:Hide() end
    end)
end

local function UpdateContainerLock(container, group)
    local locked = IsBuffGroupsLocked()
    container:EnableMouse(not locked)
    container:EnableMouseWheel(not locked)
    if container._bgHelperText then container._bgHelperText:SetShown(not locked) end
    if container._bgPosLabel then
        if locked then
            container._bgPosLabel:Hide()
        else
            UpdateContainerPosLabel(container, group)
            container._bgPosLabel:Hide()  -- 只在 OnEnter 时显示
        end
    end
    -- 边框和组名标签在解锁时显示
    if container._bgBorder then
        container._bgBorder:SetShown(not locked)
    end
    if container._bgNameLabel then
        container._bgNameLabel:SetShown(not locked)
    end
end

-- 初始化0号组容器
function Layout:InitBuffGroup0()
    local cfg = ns.db and ns.db.buffGroup0
    if not cfg or not cfg.enabled then
        if group0Container then
            group0Container:Hide()
        end
        return
    end

    if not group0Container then
        local name = "CDFlow_BuffGroup_0"
        group0Container = _G[name] or CreateFrame("Frame", name, UIParent)
        group0Container:SetParent(UIParent)
        group0Container:SetFrameStrata("MEDIUM")
        group0Container:SetFrameLevel(10)
        group0Container:SetSize(200, 50)
        SetupContainerDrag(group0Container)

        -- 添加边框（解锁时显示）
        if not group0Container._bgBorder then
            local border = group0Container:CreateTexture(nil, "BACKGROUND")
            border:SetAllPoints()
            border:SetColorTexture(0.3, 0.6, 0.9, 0.3)
            group0Container._bgBorder = border
        end

        -- 添加组名标签（解锁时显示）
        if not group0Container._bgNameLabel then
            local nameLabel = group0Container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            nameLabel:SetPoint("CENTER", group0Container, "CENTER", 0, 0)
            nameLabel:SetTextColor(1, 0.82, 0, 1)
            group0Container._bgNameLabel = nameLabel
        end
    end

    -- 更新组名标签
    local groupName = cfg.name or (ns.L and ns.L.bg0Title or "饰品&药水")
    if group0Container._bgNameLabel then
        group0Container._bgNameLabel:SetText("0. " .. groupName)
    end

    local x = cfg.x or 0
    local y = cfg.y or -320
    group0Container:ClearAllPoints()
    group0Container:SetPoint("CENTER", UIParent, "CENTER", x, y)
    group0Container:Show()

    UpdateContainerLock(group0Container, cfg)
end

-- 设置锁定状态
function Layout:SetBuffGroup0Locked(locked)
    if group0Container then
        local cfg = ns.db and ns.db.buffGroup0
        UpdateContainerLock(group0Container, cfg)
    end
end

------------------------------------------------------
-- 物品监控数据初始化
------------------------------------------------------

-- 扫描并注册所有需要监控的物品
function Layout:ScanBuffGroup0Items()
    local cfg = ns.db and ns.db.buffGroup0
    if not cfg or not cfg.enabled then return end

    wipe(iconPool)
    wipe(autoDetectedItems)

    -- 扫描饰品槽位（13和14）
    if cfg.autoTrinkets then
        for _, slot in ipairs({13, 14}) do
            local itemID = GetInventoryItemID("player", slot)
            if itemID then
                local spellID, duration = GetItemSpellInfo(itemID)
                if spellID then
                    local iconPath = C_Item.GetItemIconByID(itemID)
                    iconPool[spellID] = {
                        itemID = itemID,
                        duration = duration,
                        iconPath = iconPath,
                        isAuto = true,  -- 标记为自动检测
                    }
                    autoDetectedItems[itemID] = true
                end
            end
        end
    end

    -- 扫描手动添加的物品列表
    if cfg.potionItemIDs then
        for _, itemID in ipairs(cfg.potionItemIDs) do
            local spellID, duration = GetItemSpellInfo(itemID)
            if spellID then
                local iconPath = C_Item.GetItemIconByID(itemID)
                -- 如果已经被自动检测添加，跳过
                if not iconPool[spellID] then
                    iconPool[spellID] = {
                        itemID = itemID,
                        duration = duration,
                        iconPath = iconPath,
                        isAuto = false,
                    }
                end
            else
                print(string.format("|cffff4444[CDFlow]|r 无法获取物品法术信息: 物品ID %d", itemID))
            end
        end
    end

    -- 为每个spellID创建图标帧
    for spellID, data in pairs(iconPool) do
        if not data.frame then
            local frame, icon, cooldown = CreateIconFrame()
            data.frame = frame
            data.icon = icon
            data.cooldown = cooldown
        end
    end
end

-- 异步扫描（等待物品数据加载）
local scanTimer = nil
local function ScheduleScan()
    if scanTimer then scanTimer:Cancel() end
    scanTimer = C_Timer.NewTicker(0.5, function()
        Layout:ScanBuffGroup0Items()
        if scanTimer then
            scanTimer:Cancel()
            scanTimer = nil
        end
    end, 10)  -- 最多尝试10次
end

-- 获取自动检测的物品列表（供UI使用）
function Layout:GetBuffGroup0AutoItems()
    return autoDetectedItems
end

------------------------------------------------------
-- 布局刷新
------------------------------------------------------

function Layout:RefreshBuffGroup0Layout()
    local cfg = ns.db and ns.db.buffGroup0
    if not cfg or not cfg.enabled or not group0Container then return end

    local visibleIcons = {}
    for spellID, data in pairs(iconPool) do
        if data.frame and data.cooldown then
            local _, duration = data.cooldown:GetCooldownTimes()
            if duration and duration > 1000 then
                table.insert(visibleIcons, data)
            end
        end
    end

    local count = #visibleIcons

    -- 如果有真实图标，隐藏预览
    if count > 0 and previewActive then
        self:HideBuffGroup0Preview()
    end

    if count == 0 then return end

    local iconW = (cfg.overrideSize and cfg.iconWidth) or 40
    local iconH = (cfg.overrideSize and cfg.iconHeight) or 40
    local spacing = 2
    local zoom = ns.db and ns.db.iconZoom or 0.08
    local borderSize = ns.db and ns.db.borderSize or 1

    if cfg.horizontal ~= false then
        -- 水平居中排列
        local totalW = count * iconW + (count - 1) * spacing
        local startX = -(totalW / 2) + iconW / 2
        group0Container:SetSize(totalW, iconH)
        for i, data in ipairs(visibleIcons) do
            data.frame:ClearAllPoints()
            data.frame:SetPoint("CENTER", group0Container, "CENTER",
                startX + (i - 1) * (iconW + spacing), 0)
            -- 应用尺寸和样式
            data.frame:SetSize(iconW, iconH)
            if ns.Style and ns.Style.ApplyIcon then
                ns.Style:ApplyIcon(data.frame, iconW, iconH, zoom, borderSize)
            end
        end
    else
        -- 垂直向下排列
        local totalH = count * iconH + (count - 1) * spacing
        local startY = (totalH / 2) - iconH / 2
        group0Container:SetSize(iconW, totalH)
        for i, data in ipairs(visibleIcons) do
            data.frame:ClearAllPoints()
            data.frame:SetPoint("CENTER", group0Container, "CENTER",
                0, startY - (i - 1) * (iconH + spacing))
            -- 应用尺寸和样式
            data.frame:SetSize(iconW, iconH)
            if ns.Style and ns.Style.ApplyIcon then
                ns.Style:ApplyIcon(data.frame, iconW, iconH, zoom, borderSize)
            end
        end
    end
end

------------------------------------------------------
-- 预览功能
------------------------------------------------------

-- 创建预览图标
local function CreatePreviewIcon()
    local cfg = ns.db and ns.db.buffGroup0
    local size = (cfg and cfg.overrideSize) and cfg.iconWidth or 40

    local frame = CreateFrame("Frame", nil, group0Container)
    frame:SetSize(size, size)
    frame:Hide()

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")  -- 默认占位图标
    icon:SetAlpha(0.5)
    frame.Icon = icon

    -- 应用图标美化
    local zoom = ns.db and ns.db.iconZoom or 0.08
    local borderSize = ns.db and ns.db.borderSize or 1
    if ns.Style and ns.Style.ApplyIcon then
        ns.Style:ApplyIcon(frame, size, size, zoom, borderSize)
    end

    return frame
end

-- 显示预览
function Layout:ShowBuffGroup0Preview()
    if not group0Container then return end
    local cfg = ns.db and ns.db.buffGroup0
    if not cfg or not cfg.enabled then return end

    previewActive = true

    -- 收集当前监控的物品图标（最多3个）
    local previewIcons_data = {}
    for spellID, data in pairs(iconPool) do
        if #previewIcons_data < 3 then
            table.insert(previewIcons_data, data.iconPath)
        end
    end

    -- 创建3个预览图标
    local previewCount = 3
    for i = 1, previewCount do
        if not previewIcons[i] then
            previewIcons[i] = CreatePreviewIcon()
        end

        -- 设置图标纹理
        local iconTexture = previewIcons_data[i] or "Interface\\Icons\\INV_Misc_QuestionMark"
        if previewIcons[i].Icon then
            previewIcons[i].Icon:SetTexture(iconTexture)
            previewIcons[i].Icon:SetAlpha(0.5)
        end

        previewIcons[i]:Show()
    end

    -- 布局预览图标
    local iconW = (cfg.overrideSize and cfg.iconWidth) or 40
    local iconH = (cfg.overrideSize and cfg.iconHeight) or 40
    local spacing = 2

    if cfg.horizontal ~= false then
        -- 水平居中排列
        local totalW = previewCount * iconW + (previewCount - 1) * spacing
        local startX = -(totalW / 2) + iconW / 2
        group0Container:SetSize(totalW, iconH)
        for i = 1, previewCount do
            previewIcons[i]:ClearAllPoints()
            previewIcons[i]:SetPoint("CENTER", group0Container, "CENTER",
                startX + (i - 1) * (iconW + spacing), 0)
            if cfg.overrideSize then
                previewIcons[i]:SetSize(iconW, iconH)
            end
            -- 重新应用美化
            local zoom = ns.db and ns.db.iconZoom or 0.08
            local borderSize = ns.db and ns.db.borderSize or 1
            if ns.Style and ns.Style.ApplyIcon then
                ns.Style:ApplyIcon(previewIcons[i], iconW, iconH, zoom, borderSize)
            end
        end
    else
        -- 垂直向下排列
        local totalH = previewCount * iconH + (previewCount - 1) * spacing
        local startY = (totalH / 2) - iconH / 2
        group0Container:SetSize(iconW, totalH)
        for i = 1, previewCount do
            previewIcons[i]:ClearAllPoints()
            previewIcons[i]:SetPoint("CENTER", group0Container, "CENTER",
                0, startY - (i - 1) * (iconH + spacing))
            if cfg.overrideSize then
                previewIcons[i]:SetSize(iconW, iconH)
            end
            -- 重新应用美化
            local zoom = ns.db and ns.db.iconZoom or 0.08
            local borderSize = ns.db and ns.db.borderSize or 1
            if ns.Style and ns.Style.ApplyIcon then
                ns.Style:ApplyIcon(previewIcons[i], iconW, iconH, zoom, borderSize)
            end
        end
    end
end

-- 隐藏预览
function Layout:HideBuffGroup0Preview()
    previewActive = false
    for _, frame in ipairs(previewIcons) do
        frame:Hide()
    end
    -- 恢复容器默认大小
    if group0Container then
        group0Container:SetSize(200, 50)
    end
end

-- 检查是否正在预览
function Layout:IsBuffGroup0Previewing()
    return previewActive
end

------------------------------------------------------
-- 事件处理
------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("PLAYER_DEAD")

eventFrame:SetScript("OnEvent", function(self, event, unit, guid, spellID)
    if event == "PLAYER_ENTERING_WORLD" then
        Layout:InitBuffGroup0()
        ScheduleScan()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        ScheduleScan()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit ~= "player" then return end

        local data = iconPool[spellID]
        if data and data.frame and data.duration then
            -- 应用当前配置的尺寸和样式
            local cfg = ns.db and ns.db.buffGroup0
            local iconW = (cfg and cfg.overrideSize and cfg.iconWidth) or 40
            local iconH = (cfg and cfg.overrideSize and cfg.iconHeight) or 40
            local zoom = ns.db and ns.db.iconZoom or 0.08
            local borderSize = ns.db and ns.db.borderSize or 1

            data.frame:SetSize(iconW, iconH)
            if ns.Style and ns.Style.ApplyIcon then
                ns.Style:ApplyIcon(data.frame, iconW, iconH, zoom, borderSize)
            end

            data.frame:Show()
            data.icon:SetTexture(data.iconPath)
            data.cooldown:SetCooldown(GetTime(), data.duration)
            Layout:RefreshBuffGroup0Layout()
        end
    elseif event == "PLAYER_DEAD" then
        -- 清除所有冷却
        for _, data in pairs(iconPool) do
            if data.cooldown then
                data.cooldown:SetCooldown(GetTime(), 1)
            end
        end
    end
end)
