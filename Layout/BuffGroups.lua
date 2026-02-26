local _, ns = ...

------------------------------------------------------
-- 增益自定义分组布局
--
-- 扩展 ns.Layout，为 BuffIconCooldownViewer 的图标
-- 提供独立的自定义分组容器与排列逻辑。
--
-- 分组容器为锚定于 UIParent 的不可见 Frame，
-- 图标保持父级为原始 Viewer，仅通过 SetPoint 锚定到分组容器，
-- 不影响 WoW 原生帧生命周期。
------------------------------------------------------

local Layout = ns.Layout

-- 分组拼写映射：{[spellID]=groupIndex}，含 base 变体
local _groupSpellMap = {}
local _groupSpellMapDirty = true

------------------------------------------------------
-- 内部工具
------------------------------------------------------

local function RoundToPixel(v)
    return math.floor(v + 0.5)
end

-- 将拖动后的屏幕坐标转换为 UIParent CENTER 相对偏移
local function ScreenToCenterOffset(frame)
    local cx, cy = frame:GetCenter()
    if not cx or not cy then return 0, 0 end
    local sx, sy = UIParent:GetCenter()
    if not sx or not sy then return 0, 0 end
    return RoundToPixel(cx - sx), RoundToPixel(cy - sy)
end

------------------------------------------------------
-- 多源技能ID候选列表
------------------------------------------------------

-- 收集图标帧所有可能的技能ID来源，优先级从高到低：
--   GetAuraSpellID > GetSpellID > cooldownInfo 所有字段
local function GetSpellIDCandidatesForIcon(icon)
    local candidates = {}
    local seen = {}
    local function add(id)
        if id == nil then return end
        -- WoW 12.0 secret values cannot be compared numerically; skip them
        if issecretvalue and issecretvalue(id) then return end
        if type(id) ~= "number" then return end
        if id <= 0 or id ~= math.floor(id) then return end
        if seen[id] then return end
        seen[id] = true
        candidates[#candidates + 1] = id
    end

    -- 优先使用 Aura 方法（最准确）
    if icon.GetAuraSpellID then add(icon:GetAuraSpellID()) end
    if icon.GetSpellID     then add(icon:GetSpellID())     end

    -- 从 CooldownInfo 读取多个字段（fallback 链）
    local info
    if icon.cooldownID and C_CooldownViewer
        and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        info = C_CooldownViewer.GetCooldownViewerCooldownInfo(icon.cooldownID)
    end
    if not info and icon.GetCooldownInfo then
        info = icon:GetCooldownInfo()
    end
    if not info then info = icon.cooldownInfo end

    if info then
        add(info.linkedSpellID)
        add(info.overrideTooltipSpellID)
        add(info.overrideSpellID)
        add(info.spellID)
        if info.linkedSpellIDs then
            for _, id in ipairs(info.linkedSpellIDs) do add(id) end
        end
    end

    return candidates
end

------------------------------------------------------
-- 公开接口：分组映射 + 帧级查找
------------------------------------------------------

-- 标记分组配置已变更，下次刷新时重建 spellID→groupIndex 映射表
function Layout:MarkBuffGroupsDirty()
    _groupSpellMapDirty = true
end

-- 返回 {[spellID] = groupIndex} 的映射表（按需重建）
-- 每个用户配置的 spellID 同时注册其 C_Spell.GetBaseSpell 变体，
-- 确保天赋替换/Override 技能 ID 也能匹配。
function Layout:GetBuffGroupSpellMap()
    if not _groupSpellMapDirty then
        return _groupSpellMap
    end

    wipe(_groupSpellMap)
    local groups = ns.db and ns.db.buffGroups
    if groups then
        for i, group in ipairs(groups) do
            if group.spellIDs then
                for spellID in pairs(group.spellIDs) do
                    _groupSpellMap[spellID] = i
                    -- 同时注册 base spell 变体（不覆盖已有精确配置）
                    if C_Spell and C_Spell.GetBaseSpell then
                        local baseID = C_Spell.GetBaseSpell(spellID)
                        if baseID and baseID ~= spellID then
                            _groupSpellMap[baseID] = _groupSpellMap[baseID] or i
                        end
                    end
                end
            end
        end
    end
    _groupSpellMapDirty = false
    return _groupSpellMap
end

-- 查找图标所属分组索引（无帧级缓存，每次直接查找）
-- 匹配顺序：直接映射命中 → base spell 归一化
-- 不缓存原因：帧级缓存在 buff 激活/失活时序中极易产生过期 nil，
-- 而此函数仅在 RefreshBuffViewer 遍历可见图标时调用，开销可忽略。
function Layout:GetGroupIdxForIcon(icon)
    if not icon then return nil end

    local groupSpellMap = self:GetBuffGroupSpellMap()
    if not next(groupSpellMap) then return nil end

    local candidates = GetSpellIDCandidatesForIcon(icon)
    for _, spellID in ipairs(candidates) do
        -- 直接映射
        local gIdx = groupSpellMap[spellID]
        if gIdx and self.buffGroupContainers and self.buffGroupContainers[gIdx] then
            return gIdx
        end
        -- base spell 归一化（候选ID本身不在映射中时）
        if C_Spell and C_Spell.GetBaseSpell then
            local base = C_Spell.GetBaseSpell(spellID)
            if base and base ~= spellID then
                gIdx = groupSpellMap[base]
                if gIdx and self.buffGroupContainers and self.buffGroupContainers[gIdx] then
                    return gIdx
                end
            end
        end
    end
    return nil
end

-- 临时放置：立即对分组内全部图标做正确排列 + 应用样式，无需等待全量刷新。
function Layout:ProvisionalPlaceInGroup(frame)
    if not frame then return end
    local gIdx = self:GetGroupIdxForIcon(frame)
    if not gIdx then return end
    local container = self.buffGroupContainers[gIdx]
    if not container or not container:IsShown() then return end

    local db = ns.db
    local cfg = db and db.buffs
    if not cfg then return end

    -- 收集分组内已可见的其他图标；触发帧始终加入（可能尚未 IsShown）
    -- 优先 itemFramePool：re-parent 后的帧已不在 GetChildren 中，需通过 pool 枚举
    local viewer = _G["BuffIconCooldownViewer"]
    local groupIcons = {}

    if viewer then
        if viewer.itemFramePool then
            for child in viewer.itemFramePool:EnumerateActive() do
                if child and child.Icon and child ~= frame and child:IsShown()
                    and self:GetGroupIdxForIcon(child) == gIdx then
                    groupIcons[#groupIcons + 1] = child
                end
            end
        else
            for _, child in ipairs({ viewer:GetChildren() }) do
                if child and child.Icon and child ~= frame and child:IsShown()
                    and self:GetGroupIdxForIcon(child) == gIdx then
                    groupIcons[#groupIcons + 1] = child
                end
            end
        end
    end
    -- 始终将触发帧加入（可能尚未 IsShown，所以不在上面的循环中）
    groupIcons[#groupIcons + 1] = frame

    -- 按 layoutIndex 排序，与 CollectAllIcons → RefreshBuffViewer 路径保持一致，
    -- 避免 GetChildren() 的非确定顺序与全量刷新顺序不同导致图标互换位置
    table.sort(groupIcons, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)

    -- 立即应用样式（尺寸、缩放、边框等），避免首帧出现原始 WoW 样式
    local Style = ns.Style
    if Style then
        local w, h = cfg.iconWidth, cfg.iconHeight
        for _, icon in ipairs(groupIcons) do
            icon._cdf_viewerKey = "buffs"
            Style:ApplyIcon(icon, w, h, db.iconZoom, db.borderSize)
            Style:ApplyStack(icon, cfg.stack)
            Style:ApplyKeybind(icon, cfg)
            Style:ApplyCooldownText(icon, cfg)
            Style:ApplySwipeOverlay(icon)
        end
    end

    -- 立即对组内全部图标做正确的多图标排列
    self:RefreshBuffGroups({ [gIdx] = groupIcons }, cfg.iconWidth, cfg.iconHeight, cfg)
end

------------------------------------------------------
-- 容器管理
------------------------------------------------------

-- buffGroupContainers[i] = anchor Frame for group i
Layout.buffGroupContainers = Layout.buffGroupContainers or {}

-- 更新容器坐标显示标签（解锁状态下显示）
local function UpdateContainerPosLabel(container, group)
    if not container._bgPosLabel then return end
    local x = group and group.x or 0
    local y = group and group.y or 0
    container._bgPosLabel:SetFormattedText("X: %.0f  Y: %.0f", x, y)
end

-- 读取全局锁定状态
local function IsBuffGroupsLocked()
    return ns.db and ns.db.buffGroupsLocked or false
end

local function SetupContainerDrag(container, groupIdx)
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    container:RegisterForDrag("LeftButton")
    container:EnableMouseWheel(true)

    -- 坐标显示标签（解锁时显示在容器下方）
    if not container._bgPosLabel then
        local posLabel = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        posLabel:SetPoint("TOP", container, "BOTTOM", 0, -4)
        posLabel:SetTextColor(1, 0.82, 0, 1)
        container._bgPosLabel = posLabel
    end

    -- 提示文字（解锁时显示在容器上方）
    if not container._bgHelperText then
        local txt = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("BOTTOM", container, "TOP", 0, 6)
        txt:SetText(ns.L and ns.L.bgNudgeHint or "Drag or scroll to adjust | Shift=horizontal | Ctrl=10px")
        txt:SetTextColor(0.8, 0.8, 0.8, 1)
        container._bgHelperText = txt
    end

    container:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        if IsBuffGroupsLocked() then return end
        self:StartMoving()
        -- 拖动时实时更新坐标显示
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
        local groups = ns.db and ns.db.buffGroups
        if not groups or not groups[groupIdx] then return end

        local x, y = ScreenToCenterOffset(self)
        groups[groupIdx].x = x
        groups[groupIdx].y = y

        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", x, y)
        UpdateContainerPosLabel(self, groups[groupIdx])
    end)

    -- 滚轮微调
    -- 默认=垂直，Shift=水平，Ctrl=大步进10px
    container:SetScript("OnMouseWheel", function(self, delta)
        if InCombatLockdown() then return end
        if IsBuffGroupsLocked() then return end
        local groups = ns.db and ns.db.buffGroups
        if not groups or not groups[groupIdx] then return end

        local step = IsControlKeyDown() and 10 or 1
        if IsShiftKeyDown() then
            groups[groupIdx].x = (groups[groupIdx].x or 0) + delta * step
        else
            groups[groupIdx].y = (groups[groupIdx].y or 0) + delta * step
        end
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", groups[groupIdx].x, groups[groupIdx].y)
        UpdateContainerPosLabel(self, groups[groupIdx])
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

-- 根据全局锁定状态更新容器的交互性和标签可见性
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
end

-- 创建单个分组容器
local function CreateGroupContainer(i, group)
    local name = "CDFlow_BuffGroup_" .. i
    local container = _G[name] or CreateFrame("Frame", name, UIParent)
    container:SetParent(UIParent)
    container:SetFrameStrata("MEDIUM")
    container:SetFrameLevel(10)
    container:SetSize(200, 50)

    local x = group.x or 0
    local y = group.y or (-260 - (i - 1) * 60)
    container:ClearAllPoints()
    container:SetPoint("CENTER", UIParent, "CENTER", x, y)
    container:Show()

    SetupContainerDrag(container, i)
    UpdateContainerLock(container, group)

    return container
end

-- 初始化/同步所有分组容器（配置变化时调用）
function Layout:InitBuffGroups()
    local groups = ns.db and ns.db.buffGroups or {}

    -- 销毁多余容器
    for i = #groups + 1, #self.buffGroupContainers do
        local c = self.buffGroupContainers[i]
        if c then
            c:Hide()
            c:SetScript("OnDragStart", nil)
            c:SetScript("OnDragStop", nil)
            c:SetScript("OnMouseWheel", nil)
        end
        self.buffGroupContainers[i] = nil
    end

    -- 创建或更新容器
    for i, group in ipairs(groups) do
        if not self.buffGroupContainers[i] then
            self.buffGroupContainers[i] = CreateGroupContainer(i, group)
        else
            -- 同步锁定状态（位置已由 DB 保存，不在此重置）
            UpdateContainerLock(self.buffGroupContainers[i], group)
        end
    end

    self:MarkBuffGroupsDirty()
end

-- 重新应用所有容器的屏幕位置（DB 更改后调用）
function Layout:PositionGroupContainers()
    local groups = ns.db and ns.db.buffGroups or {}
    for i, group in ipairs(groups) do
        local container = self.buffGroupContainers[i]
        if container then
            local x = group.x or 0
            local y = group.y or (-260 - (i - 1) * 60)
            container:ClearAllPoints()
            container:SetPoint("CENTER", UIParent, "CENTER", x, y)
            UpdateContainerLock(container, group)
        end
    end
end

-- 设置全局锁定状态，立即应用到所有容器（从 UI 锁定复选框调用）
function Layout:SetBuffGroupsLocked(locked)
    if ns.db then ns.db.buffGroupsLocked = locked end
    local groups = ns.db and ns.db.buffGroups or {}
    for i, group in ipairs(groups) do
        local container = self.buffGroupContainers[i]
        if container then
            UpdateContainerLock(container, group)
        end
    end
end

-- 当特定分组被添加/删除时重建
function Layout:RebuildBuffGroup(idx)
    local groups = ns.db and ns.db.buffGroups or {}
    if idx > #groups then
        -- 删除：销毁容器
        local c = self.buffGroupContainers[idx]
        if c then
            c:Hide()
            c:SetScript("OnDragStart", nil)
            c:SetScript("OnDragStop", nil)
            c:SetScript("OnMouseWheel", nil)
            self.buffGroupContainers[idx] = nil
        end
        -- 收缩列表
        for i = idx, #self.buffGroupContainers do
            self.buffGroupContainers[i] = self.buffGroupContainers[i + 1]
        end
    else
        -- 新增：创建容器
        if not self.buffGroupContainers[idx] then
            self.buffGroupContainers[idx] = CreateGroupContainer(idx, groups[idx])
        end
    end
    self:MarkBuffGroupsDirty()
end

------------------------------------------------------
-- 分组内图标排列
------------------------------------------------------

function Layout:RefreshBuffGroups(groupBuckets, w, h, cfg)
    local groups = ns.db and ns.db.buffGroups
    if not groups then return end

    local spacingX = cfg.spacingX or 2
    local spacingY = cfg.spacingY or 2

    for gIdx, icons in pairs(groupBuckets) do
        local group = groups[gIdx]
        local container = self.buffGroupContainers[gIdx]
        local count = icons and #icons or 0

        if group and container and count > 0 then
            if group.horizontal ~= false then
                -- 水平居中排列
                local totalW = count * w + (count - 1) * spacingX
                local startX = -(totalW / 2) + w / 2
                container:SetSize(totalW, h)
                for i, icon in ipairs(icons) do
                    -- re-parent 到 UIParent，防止 viewer RefreshLayout 干扰分组图标
                    icon:SetParent(UIParent)
                    icon:ClearAllPoints()
                    icon:SetPoint("CENTER", container, "CENTER",
                        startX + (i - 1) * (w + spacingX), 0)
                end
            else
                -- 垂直向下排列（顶部居中）
                local totalH = count * h + (count - 1) * spacingY
                local startY = (totalH / 2) - h / 2
                container:SetSize(w, totalH)
                for i, icon in ipairs(icons) do
                    -- re-parent 到 UIParent，防止 viewer RefreshLayout 干扰分组图标
                    icon:SetParent(UIParent)
                    icon:ClearAllPoints()
                    icon:SetPoint("CENTER", container, "CENTER",
                        0, startY - (i - 1) * (h + spacingY))
                end
            end
        end
    end
end
