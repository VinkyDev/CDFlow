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
    EnsureIconCaches(button)

    if button._cdf_w ~= w or button._cdf_h ~= h then
        button:SetSize(w, h)
        button._cdf_w = w
        button._cdf_h = h
    end

    local crop = zoom * 0.5
    local ratio = w / h
    if not button._cdf_iconAnchored then
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
