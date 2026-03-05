-- Masque 集成模块
local _, ns = ...
local Masque = LibStub("Masque", true)

-- 创建 CDFlow 的 Masque 组
local masqueGroup = Masque and Masque:Group("CDFlow")

-- Masque 模块
local MasqueIntegration = {
    masqueGroup = masqueGroup,
    registeredButtons = {},
}

ns.Masque = MasqueIntegration

---检查 Masque 是否已安装
---@return boolean
function MasqueIntegration:IsInstalled()
    return Masque ~= nil
end

---检查 Masque 是否激活(已安装且未禁用)
---@return boolean
function MasqueIntegration:IsActive()
    return masqueGroup ~= nil and not masqueGroup.db.Disabled
end

---注册一个按钮到 Masque
---@param button table 按钮帧
---@param icon table 图标纹理
---@param border? table 边框帧(可选)
function MasqueIntegration:RegisterButton(button, icon, border)
    if not masqueGroup then
        return
    end

    -- 避免重复注册
    if self.registeredButtons[button] then
        return
    end

    -- 注册到 Masque
    local buttonData = {
        Icon = icon,
    }

    -- 如果有边框,也注册边框(作为 Normal 纹理)
    if border then
        buttonData.Normal = border
    end

    masqueGroup:AddButton(button, buttonData)
    self.registeredButtons[button] = true
end

---取消注册一个按钮
---@param button table 按钮帧
function MasqueIntegration:UnregisterButton(button)
    if not masqueGroup or not self.registeredButtons[button] then
        return
    end

    masqueGroup:RemoveButton(button)
    self.registeredButtons[button] = nil
end

---刷新所有已注册的按钮皮肤
function MasqueIntegration:ReSkin()
    if not masqueGroup then
        return
    end

    masqueGroup:ReSkin()
end

---清理 Masque 创建的纹理(当 Masque 被禁用时)
---@param button table 按钮帧
---@param icon table 图标纹理
---@param border? table 边框帧
function MasqueIntegration:CleanupMasqueTextures(button, icon, border)
    if not masqueGroup then
        return
    end

    -- 隐藏 Masque 创建的额外纹理(Backdrop, Shadow, Gloss 等)
    for _, region in next, { button:GetRegions() } do
        if region:IsObjectType("Texture") and region ~= icon and region ~= border then
            region:Hide()
        end
    end
end

-- 注册 Masque 皮肤改变回调
if masqueGroup then
    masqueGroup:RegisterCallback(function()
        -- 延迟刷新,因为 Masque 在回调后才修改按钮区域
        C_Timer.After(0, function()
            -- 触发 CDFlow 的刷新
            if ns.RequestRefreshAll then
                ns.RequestRefreshAll()
            end
        end)
    end)
end
