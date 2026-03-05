-- 图标裁剪、边框、遮罩替换
local _, ns = ...

local Style = {}
ns.Style = Style

local SQUARE_MASK = "Interface\\BUTTONS\\WHITE8X8"
local DEFAULT_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local ROUND_MASK_TEX = 6707800

ns._styleConst = {
    SQUARE_MASK    = SQUARE_MASK,
    DEFAULT_FONT   = DEFAULT_FONT,
    ROUND_MASK_TEX = ROUND_MASK_TEX,
}

local LSM = LibStub("LibSharedMedia-3.0", true)
local _issecretvalue = issecretvalue or function() return false end

function ns.ResolveFontPath(fontName)
    if LSM then
        local name = fontName
        if not name or name == "" then
            name = LSM.DefaultMedia and LSM.DefaultMedia.font
        end
        if name and name ~= "" then
            local ok, p = pcall(LSM.Fetch, LSM, "font", name, true)
            if ok and p then return p end
        end
    end
    return DEFAULT_FONT
end

local function EnsureIconCaches(button)
    if button._cdf_cacheReady then return end

    button._cdf_swipes = {}
    for i = 1, select("#", button:GetChildren()) do
        local child = select(i, button:GetChildren())
        if child and child.SetSwipeTexture then
            button._cdf_swipes[#button._cdf_swipes + 1] = child
        end
    end

    button._cdf_overlayRegions = {}
    button._cdf_roundMaskRegions = {}
    for _, region in next, { button:GetRegions() } do
        if region:IsObjectType("Texture") then
            local atlas = region.GetAtlas and region:GetAtlas()
            if atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                button._cdf_overlayRegions[#button._cdf_overlayRegions + 1] = region
            end
            local tex = region:GetTexture()
            if not _issecretvalue(tex) and tex == ROUND_MASK_TEX then
                button._cdf_roundMaskRegions[#button._cdf_roundMaskRegions + 1] = region
            end
        end
    end

    button._cdf_cacheReady = true
end

function Style:ApplyIcon(button, w, h, zoom, borderSize)
    if not button or not button.Icon then return end

    -- 检查 Masque 是否激活
    local masqueActive = ns.Masque and ns.Masque:IsActive()

    if ns.db and ns.db.iconBeautify == false then
        if button._cdf_w ~= w or button._cdf_h ~= h then
            button:SetSize(w, h)
            button._cdf_w = w
            button._cdf_h = h
        end

        if button._cdf_styled then
            if button.Icon.SetTexCoord then button.Icon:SetTexCoord(0, 1, 0, 1) end
            if button._cdf_border then button._cdf_border:Hide() end
            if button._cdf_overlayRegions then
                for _, region in ipairs(button._cdf_overlayRegions) do region:SetAlpha(1) end
            end
            if button._cdf_roundMaskRegions then
                for _, region in ipairs(button._cdf_roundMaskRegions) do
                    if region._cdf_replaced then
                        region:SetTexture(ns._styleConst.ROUND_MASK_TEX)
                        region._cdf_replaced = false
                    end
                end
            end
            if button.DebuffBorder then
                button.DebuffBorder:SetAlpha(1)
            end
            button._cdf_styled = false
        end
        return
    end

    EnsureIconCaches(button)

    -- 设置按钮大小(无论是否使用 Masque 都需要)
    if button._cdf_w ~= w or button._cdf_h ~= h then
        button:SetSize(w, h)
        button._cdf_w = w
        button._cdf_h = h
    end

    -- Masque 激活时:注册按钮,隐藏原生边框,让 Masque 接管样式
    if masqueActive then
        if not button._cdf_masqueRegistered then
            ns.Masque:RegisterButton(button, button.Icon, button._cdf_border)
            button._cdf_masqueRegistered = true
        end

        -- 隐藏原生边框
        if button._cdf_border then
            button._cdf_border:Hide()
        end

        -- 隐藏 overlay 和 round mask
        for _, region in ipairs(button._cdf_overlayRegions) do
            if region:GetAlpha() ~= 0 then
                region:SetAlpha(0)
            end
        end
        for _, region in ipairs(button._cdf_roundMaskRegions) do
            if not region._cdf_replaced then
                region:SetTexture(SQUARE_MASK)
                region._cdf_replaced = true
            end
        end

        button._cdf_styled = true

        -- 处理 Debuff 边框
        if button.DebuffBorder then
            local suppress = ns.db and ns.db.suppressDebuffBorder
            local targetAlpha = suppress and 0 or 1
            if button.DebuffBorder:GetAlpha() ~= targetAlpha then
                button.DebuffBorder:SetAlpha(targetAlpha)
            end
        end

        return
    end

    -- Masque 未激活时:清理 Masque 纹理,应用原生样式
    if ns.Masque and ns.Masque:IsInstalled() then
        ns.Masque:CleanupMasqueTextures(button, button.Icon, button._cdf_border)
    end

    -- 应用原生样式
    local crop = zoom * 0.5
    local ratio = w / h
    if not button._cdf_iconAnchored or masqueActive == false then
        -- 当从 Masque 切换回原生样式时,需要重新锚定图标
        button.Icon:ClearAllPoints()
        button.Icon:SetAllPoints(button)
        button._cdf_iconAnchored = true
    end
    if button.Icon.SetTexCoord
        and (button._cdf_crop ~= crop or button._cdf_ratio ~= ratio) then
        button.Icon:SetTexCoord(crop, 1 - crop, crop * ratio, 1 - crop * ratio)
        button._cdf_crop = crop
        button._cdf_ratio = ratio
    end
    local hasTexture = button.Icon:GetTexture() ~= nil
    if hasTexture then
        if button.Icon:GetAlpha() ~= 1 then
            button.Icon:SetAlpha(1)
        end
    elseif button.Icon:GetAlpha() ~= 0 then
        -- 复用帧贴图尚未写入时先隐藏图层，避免黑框
        button.Icon:SetAlpha(0)
    end

    for _, swipe in ipairs(button._cdf_swipes) do
        if not swipe._cdf_squareSwipe then
            swipe:SetSwipeTexture(SQUARE_MASK)
            swipe._cdf_squareSwipe = true
        end
        if swipe._cdf_borderSize ~= borderSize then
            swipe:ClearAllPoints()
            swipe:SetPoint("TOPLEFT", button, "TOPLEFT", borderSize, -borderSize)
            swipe:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -borderSize, borderSize)
            swipe._cdf_borderSize = borderSize
        end
    end

    for _, region in ipairs(button._cdf_overlayRegions) do
        if region:GetAlpha() ~= 0 then
            region:SetAlpha(0)
        end
    end
    for _, region in ipairs(button._cdf_roundMaskRegions) do
        if not region._cdf_replaced then
            region:SetTexture(SQUARE_MASK)
            region._cdf_replaced = true
        end
    end

    if borderSize > 0 then
        if not button._cdf_border then
            button._cdf_border = CreateFrame("Frame", nil, button, "BackdropTemplate")
            button._cdf_border:SetFrameLevel(button:GetFrameLevel() + 1)
            button._cdf_border:ClearAllPoints()
            button._cdf_border:SetAllPoints(button)
        end
        button._cdf_border:SetFrameLevel(button:GetFrameLevel() + 1)
        if button._cdf_borderSize ~= borderSize then
            button._cdf_border:SetBackdrop({
                edgeFile = SQUARE_MASK,
                edgeSize = borderSize,
            })
            button._cdf_border:SetBackdropBorderColor(0, 0, 0, 1)
            button._cdf_borderSize = borderSize
        end
        button._cdf_border:Show()
    elseif button._cdf_border then
        button._cdf_border:Hide()
    end

    button._cdf_styled = true

    if button.DebuffBorder then
        local suppress = ns.db and ns.db.suppressDebuffBorder
        local targetAlpha = suppress and 0 or 1
        if button.DebuffBorder:GetAlpha() ~= targetAlpha then
            button.DebuffBorder:SetAlpha(targetAlpha)
        end
    end
end

-- 一次性挂钩 Cooldown.SetCooldown，按激活/冷却状态应用自定义遮罩色
function Style:ApplySwipeOverlay(button)
    if not button or not button.Cooldown then return end

    if not button._cdf_swipeHooked then
        hooksecurefunc(button.Cooldown, "SetCooldown", function(self)
            local b = self:GetParent()
            local key = b._cdf_viewerKey
            local cfg = key and ns.db and ns.db[key] and ns.db[key].swipeOverlay
            if not cfg or not cfg.enabled then return end
            -- Buff 仅保留冷却遮罩色；技能查看器按激活/冷却区分遮罩色
            local c = (key == "buffs" or not cfg.activeAuraColor)
                and cfg.cdSwipeColor
                or (b.wasSetFromAura and cfg.activeAuraColor or cfg.cdSwipeColor)
            self:SetSwipeColor(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
        end)
        button._cdf_swipeHooked = true
    end
end
