local addonName, MaxDps = ...

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")

loader:SetScript("OnEvent", function(self, event, name)

    if name ~= addonName then
        return
    end

    local cfg = MaxDps.db.global.spellFrame
    cfg.enabled = cfg.enabled ~= false  -- default true
    cfg.spellID = cfg.spellID or 116
    cfg.pos = cfg.pos or { x = 0, y = 0 }
    cfg.size = cfg.size or { x = 48, y = 48 }
    cfg.isMovable =  cfg.isMovable or false

    ------------------------------------------------------------
    -- Frame
    ------------------------------------------------------------
    local f = CreateFrame("Frame", "MaxDpsSpellFrame", UIParent, "BackdropTemplate")
    f:SetSize(cfg.size.x, cfg.size.y)
    f:SetPoint("CENTER", UIParent, "CENTER", cfg.pos.x, cfg.pos.y)
    f:SetMovable(cfg.isMovable)
    C_Timer.After(0,function()
        f:SetMouseMotionEnabled(true)
        f:SetMouseClickEnabled(cfg.isMovable)
    end) -- next frame, as frame engine ignores mouse setting at frame creation
    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and cfg.isMovable then
            self:StartMoving()
            self.isMoving = true
        end
    end)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and cfg.isMovable then
            self:StopMovingOrSizing()
            self.isMoving = false

            -- Save position
            local x, y = self:GetCenter()
            local ux, uy = UIParent:GetCenter()
            cfg.pos.x = x - ux
            cfg.pos.y = y - uy

            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "CENTER", cfg.pos.x, cfg.pos.y)
        end
        if button == "RightButton" and cfg.isMovable then
            cfg.isMovable = false
            self:SetMouseClickEnabled(cfg.isMovable)
            self:SetMovable(cfg.isMovable)
        end
    end)
    f:SetScript("OnShow", function(self)
        self:SetMouseClickEnabled(cfg.isMovable)
        self:SetMovable(cfg.isMovable)
    end)
    f:SetScript("OnHide", function(self)
        self:StopMovingOrSizing()
        self.isMoving = false
    end)
    f:SetScript("OnEnter", function(self)
        if not InCombatLockdown() then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("MaxDps Spell Frame")
            if cfg.isMovable then
                GameTooltip:AddLine("Right-click to Lock")
            else
                GameTooltip:AddLine("Unlock from Options")
            end
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then
            GameTooltip_Hide()
        end
    end)
    f:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Buttons/WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0, 0, 0.6)
    f:SetBackdropBorderColor(0, 0, 0)

    ------------------------------------------------------------
    -- Icon + Cooldown
    ------------------------------------------------------------
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    f.icon = icon

    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cd:SetAllPoints()

    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("BOTTOMRIGHT", -2, 2)
    local font, _, flags = text:GetFont()
    text:SetFont(font, 24, flags)
    text:SetTextColor(1, 1, 1)
    f.bindText = text

    if MaxDpsSpellFrame and ( (not MaxDps.db.global.spellFrame.enabled) or (not MaxDps.db.global.enabled) or (MaxDps.db.global.onCombatEnter) ) then
        MaxDpsSpellFrame:Hide()
    end
end)

local function CreateExtraFrames(type, number)
    local cfg = MaxDps.db.global.spellFrame
    local parent = MaxDpsSpellFrame
    local name = "MaxDpsSpellFrame" .. type .. number

    local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
    --f:SetSize(20, 20) -- example size
    f:SetSize(cfg.size.x/2, cfg.size.y/2)

    if number == 1 then
        -- First frame anchors to the main frame
        if type == "consumable" then
            f:SetPoint("LEFT", parent, "RIGHT", 5, 12)
        elseif type == "defensive" then
            f:SetPoint("RIGHT", parent, "LEFT", -5, 12)
        elseif type == "offensive" then
            f:SetPoint("RIGHT", parent, "LEFT", -5, -12)
        elseif type == "trinket" then
            f:SetPoint("LEFT", parent, "RIGHT", 5, -12)
        end
    else
        local prev = _G["MaxDpsSpellFrame" .. type .. (number - 1)]
        if prev then
            if type == "defensive" or type == "offensive" then
                f:SetPoint("LEFT", prev, "LEFT", -cfg.size.y/2, 0)
            else
                f:SetPoint("LEFT", prev, "RIGHT", 5, 0)
            end
        end
    end
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("BOTTOMRIGHT", -2, 2)
    local font, _, flags = text:GetFont()
    text:SetFont(font, 12, flags)
    text:SetTextColor(1, 1, 1)
    f.bindText = text
    f:Hide() -- hide by default
end

local function ShortenKeybind(key)
    if not key then return "" end

    key = key:gsub("SHIFT%-", "S-")
    key = key:gsub("CTRL%-", "C-")
    key = key:gsub("ALT%-", "A-")
    key = key:gsub("BUTTON1", "LMB")
    key = key:gsub("BUTTON2", "RMB")
    key = key:gsub("BUTTON3", "MB3")
    key = key:gsub("BUTTON4", "MB4")
    key = key:gsub("BUTTON5", "MB5")
    key = key:gsub("MOUSEWHEELUP", "MWU")
    key = key:gsub("MOUSEWHEELDOWN", "MWD")
    key = key:gsub("NUMPAD", "N")
    key = key:gsub("PLUS", "+")
    key = key:gsub("MINUS", "-")

    return key
end

local function GetSpellKeybind(spellID)
    if MaxDps
    and MaxDps.Spells
    and MaxDps.Spells[spellID]
    and MaxDps.Spells[spellID][1]
    and MaxDps.Spells[spellID][1].HotKey then
        for i = 1, #MaxDps.Spells[spellID] do
            local entry = MaxDps.Spells[spellID][i]
            local hotkey = entry and entry.HotKey

            if hotkey and hotkey.GetText then
                local key = hotkey:GetText()
                if key and key ~= "" and string.byte(key) ~= 226 then
                    return key
                end
            end
        end
    end
    for slot = 1, 180 do
        local actionType, id = GetActionInfo(slot)
        if actionType == "spell" and id == spellID then
            local binding = "ACTIONBUTTON" .. slot
            local key = GetBindingKey(binding)
            return key
        end
    end
    return ""
end

------------------------------------------------------------
-- Update Logic
------------------------------------------------------------
function MaxDps:UpdateSpellFrame(spellID)
    local cfg = MaxDps.db.global.spellFrame
    if not MaxDpsSpellFrame then
        return
    end
    if not spellID then
        return
    end
    if type(spellID) ~= "number" then
        return
    end
    if not cfg.enabled then
        MaxDpsSpellFrame:Hide()
        return
    end
    if MaxDpsSpellFrame and spellID == 0 then
        MaxDpsSpellFrame.icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
        return
    end

    MaxDpsSpellFrame:Show()

    spellID = spellID or cfg.spellID
    local texture
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        texture = C_Spell.GetSpellTexture(spellID)
    else
        texture = GetSpellTexture(spellID)
    end

    if not texture then
        MaxDpsSpellFrame.icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
        return
    end

    MaxDpsSpellFrame.icon:SetTexture(texture)
    if not MaxDpsSpellFrame.isMoving then
        MaxDpsSpellFrame:ClearAllPoints()
        MaxDpsSpellFrame:SetPoint("CENTER", UIParent, "CENTER", cfg.pos.x, cfg.pos.y)
        MaxDpsSpellFrame:SetSize(cfg.size.x, cfg.size.x)
    end

    local key = ShortenKeybind(GetSpellKeybind(spellID))
    if key and key ~= "" and string.byte(key) ~= 226 then
        MaxDpsSpellFrame.bindText:SetText(key)
    else
        MaxDpsSpellFrame.bindText:SetText("")
    end

    --local start, duration = GetSpellCooldown(spellID)
    --if start and duration then
    --    cd:SetCooldown(start, duration)
    --end

    --local usable, oom = IsUsableSpell(spellID)
    --if usable then
    --    icon:SetVertexColor(1, 1, 1)
    --elseif oom then
    --    icon:SetVertexColor(0.3, 0.3, 1)
    --else
    --    icon:SetVertexColor(0.4, 0.4, 0.4)
    --end
    if not MaxDpsSpellFrame.extraFramesCreated then
        if cfg.showConsumable then
            local c = 0
            for id in pairs(MaxDps.Consumables) do
                c = c + 1
            end
            for i=1, c do
                CreateExtraFrames("consumable", i)
            end
        end
        if cfg.showDefensive then
            local _, class = UnitClass("player")
            local specIndex = GetSpecialization()
            local specName = specIndex and select(2, GetSpecializationInfo(specIndex))
            local d = 1
            for i in pairs(MaxDps.classCooldowns[class][specName].defensive) do
                if MaxDps and MaxDps.Spells and MaxDps.Spells[spellID] then
                    d = d + 1
                end
            end
            for i=1, d do
                CreateExtraFrames("defensive", i)
            end
        end
        if cfg.showOffensive then
            local _, class = UnitClass("player")
            local specIndex = GetSpecialization()
            local specName = specIndex and select(2, GetSpecializationInfo(specIndex))
            local d = 1
            for i in pairs(MaxDps.classCooldowns[class][specName].offensive) do
                if MaxDps and MaxDps.Spells and MaxDps.Spells[spellID] then
                    d = d + 1
                end
            end
            for i=1, d do
                CreateExtraFrames("offensive", i)
            end
        end
        if cfg.showTrinket then
            CreateExtraFrames("trinket", 1)
            CreateExtraFrames("trinket", 2)
        end
        MaxDpsSpellFrame.extraFramesCreated = true
    end
    --local icon = select(5, GetItemInfoInstant(itemID))
    if MaxDpsSpellFrame.extraFramesCreated then
        if cfg.showConsumable then
            local index = 1
            for id in pairs(MaxDps.Consumables) do
                if MaxDps and MaxDps.ItemSpells and MaxDps.ItemSpells[id] then
                    local texture
                    local spellID = MaxDps.ItemSpells[id]
                    --local overlay = _G["MaxDps_Overlay_" .. spellID]
                    --local alpha = 1
                    local visible = true
                    local CD = C_Item and type(C_Item.GetItemCooldown) == "function" and C_Item.GetItemCooldown(id) or GetItemCooldown(id)
                    if CD and CD > 0 then
                        visible = false
                    end
                    --if overlay and overlay.texture then
                    --    --alpha = overlay.texture:GetAlpha()
                    --    visible = overlay.texture:IsVisible()
                    --end
                    if C_Item and type(C_Item.GetItemIconByID) == "function" then
                        texture = C_Item.GetItemIconByID(id)
                    else
                        texture = select(5, GetItemInfoInstant(id))
                    end
                    if not texture then
                        texture = select(5, GetItemInfoInstant(id))
                    end
                    local frame = _G["MaxDpsSpellFrameconsumable" .. index]
                    local ckey = ShortenKeybind(GetSpellKeybind(spellID))
                    if ckey and ckey ~= "" and string.byte(ckey) ~= 226 then
                        frame.bindText:SetText(ckey)
                    else
                        frame.bindText:SetText("")
                    end
                    if frame and texture and texture ~= 134400 then
                        frame.icon:SetTexture(texture)
                        frame.icon:SetAlphaFromBoolean(visible, 1, 0.5)
                        frame:Show()
                    end
                    index = index + 1
                end
            end
        end

        if cfg.showDefensive then
            local _, class = UnitClass("player")
            local specIndex = GetSpecialization()
            local specName = specIndex and select(2, GetSpecializationInfo(specIndex))
            local index = 1
            for _, spellID in pairs(MaxDps.classCooldowns[class][specName].defensive) do
                if MaxDps:CheckSpellUsable(spellID) then
                    local texture
                    local overlay = _G["MaxDps_Overlay_" .. spellID]
                    local alpha = 1
                    local SCD
                    local iszero
                    local CD
                    if MaxDps.IsRetailWow() then
                        SCD = C_Spell.GetSpellCooldownDuration(spellID)
                        iszero = SCD and SCD:IsZero()
                    else
                        CD = MaxDps:Cooldown(spellID)
                    end
                    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
                        texture = C_Spell.GetSpellTexture(spellID)
                    else
                        texture = GetSpellTexture(spellID)
                    end
                    local frame = _G["MaxDpsSpellFramedefensive" .. index]
                    local ckey = ShortenKeybind(GetSpellKeybind(spellID))
                    if ckey and ckey ~= "" and string.byte(ckey) ~= 226 then
                        frame.bindText:SetText(ckey)
                    else
                        frame.bindText:SetText("")
                    end
                    if frame and texture and texture ~= 134400 then
                        frame.icon:SetTexture(texture)
                        if MaxDps.IsRetailWow() then
                            frame.icon:SetAlphaFromBoolean(iszero, 1, 0.5)
                        else
                            if CD and CD > 0 then
                                frame.icon:SetAlpha(0.5)
                            else
                                frame.icon:SetAlpha(1)
                            end
                        end
                        frame:Show()
                    end
                    index = index + 1
                end
            end
        end

        if cfg.showOffensive then
            local _, class = UnitClass("player")
            local specIndex = GetSpecialization()
            local specName = specIndex and select(2, GetSpecializationInfo(specIndex))
            local index = 1
            for _, spellID in pairs(MaxDps.classCooldowns[class][specName].offensive) do
                if MaxDps:CheckSpellUsable(spellID) then
                    local texture
                    local overlay = _G["MaxDps_Overlay_" .. spellID]
                    local alpha = 1
                    local SCD
                    local iszero
                    local CD
                    if MaxDps.IsRetailWow() then
                        SCD = C_Spell.GetSpellCooldownDuration(spellID)
                        iszero = SCD and SCD:IsZero()
                    else
                        CD = MaxDps:Cooldown(spellID)
                    end
                    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
                        texture = C_Spell.GetSpellTexture(spellID)
                    else
                        texture = GetSpellTexture(spellID)
                    end
                    local frame = _G["MaxDpsSpellFrameoffensive" .. index]
                    local ckey = ShortenKeybind(GetSpellKeybind(spellID))
                    if ckey and ckey ~= "" and string.byte(ckey) ~= 226 then
                        frame.bindText:SetText(ckey)
                    else
                        frame.bindText:SetText("")
                    end
                    if frame and texture and texture ~= 134400 then
                        frame.icon:SetTexture(texture)
                        if MaxDps.IsRetailWow() then
                            frame.icon:SetAlphaFromBoolean(iszero, 1, 0.5)
                        else
                            if CD and CD > 0 then
                                frame.icon:SetAlpha(0.5)
                            else
                                frame.icon:SetAlpha(1)
                            end
                        end
                        frame:Show()
                    end
                    index = index + 1
                end
            end
        end

        if cfg.showTrinket then
            local id13 = GetInventoryItemID("player", 13)
            local id14 = GetInventoryItemID("player", 14)
            if MaxDps and MaxDps.ItemSpells and MaxDps.ItemSpells[id13] then
                local texture
                local spellID = MaxDps.ItemSpells[id13]
                --local overlay = _G["MaxDps_Overlay_" .. spellID]
                --local alpha = 1
                local visible = true
                local CD = C_Item and type(C_Item.GetItemCooldown) == "function" and C_Item.GetItemCooldown(id13) or GetItemCooldown(id13)
                if CD and CD > 0 then
                    visible = false
                end
                --if overlay and overlay.texture then
                --    --alpha = overlay.texture:GetAlpha()
                --    visible = overlay.texture:IsVisible()
                --end
                if C_Item and type(C_Item.GetItemIconByID) == "function" then
                    texture = C_Item.GetItemIconByID(id13)
                else
                    texture = select(5, GetItemInfoInstant(id13))
                end
                if not texture then
                    texture = select(5, GetItemInfoInstant(id13))
                end
                local frame = _G["MaxDpsSpellFrametrinket" .. 1]
                local tkey = ShortenKeybind(GetSpellKeybind(spellID))
                if tkey and tkey ~= "" and string.byte(tkey) ~= 226 then
                    frame.bindText:SetText(tkey)
                else
                    frame.bindText:SetText("")
                end
                if frame and texture and texture ~= 134400 then
                    frame.icon:SetTexture(texture)
                    frame.icon:SetAlphaFromBoolean(visible, 1, 0.5)
                    frame:Show()
                end
            end
            if MaxDps and MaxDps.ItemSpells and MaxDps.ItemSpells[id14] then
                local texture
                local spellID = MaxDps.ItemSpells[id14]
                --local overlay = _G["MaxDps_Overlay_" .. spellID]
                --local alpha = 1
                local visible = true
                local CD = C_Item and type(C_Item.GetItemCooldown) == "function" and C_Item.GetItemCooldown(id14) or GetItemCooldown(id14)
                if CD and CD > 0 then
                    visible = false
                end
                --if overlay and overlay.texture then
                --    --alpha = overlay.texture:GetAlpha()
                --    visible = overlay.texture:IsVisible()
                --end
                if C_Item and type(C_Item.GetItemIconByID) == "function" then
                    texture = C_Item.GetItemIconByID(id14)
                else
                    texture = select(5, GetItemInfoInstant(id14))
                end
                if not texture then
                    texture = select(5, GetItemInfoInstant(id14))
                end
                local frame
                if MaxDps:HasOnUseEffect(13) then
                    frame = _G["MaxDpsSpellFrametrinket" .. 2]
                else
                    frame = _G["MaxDpsSpellFrametrinket" .. 1]
                end
                local tkey = ShortenKeybind(GetSpellKeybind(spellID))
                if tkey and tkey ~= "" and string.byte(tkey) ~= 226 then
                    frame.bindText:SetText(tkey)
                else
                    frame.bindText:SetText("")
                end
                if frame and texture and texture ~= 134400 then
                    frame.icon:SetTexture(texture)
                    frame.icon:SetAlphaFromBoolean(visible, 1, 0.5)
                    frame:Show()
                end
            end
            if not MaxDps:HasOnUseEffect(13) and MaxDps:HasOnUseEffect(14) then
                local frame = _G["MaxDpsSpellFrametrinket" .. 2]
                if frame then
                    frame:Hide()
                end
            end
        end
    end
end
