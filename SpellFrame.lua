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
    cfg.isMovable =  cfg.isMovable or false

    ------------------------------------------------------------
    -- Frame
    ------------------------------------------------------------
    local f = CreateFrame("Frame", "MaxDpsSpellFrame", UIParent, "BackdropTemplate")
    f:SetSize(48, 48)
    f:SetPoint("CENTER", UIParent, "CENTER", cfg.pos.x, cfg.pos.y)
    f:SetMovable(cfg.isMovable)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            -- Toggle movable state
            local newState = not self.isMovable
            self.isMovable = newState
            cfg.isMovable = newState
            self:SetMovable(newState)

            if newState then
                print("Frame unlocked — drag with left click")
            else
                print("Frame locked")
            end
        elseif button == "LeftButton" and self.isMovable then
            self:SetMovable(true)
            self:StartMoving()
        end
    end)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.isMovable then
            self:StopMovingOrSizing()

            -- Save position
            local x, y = self:GetCenter()
            local ux, uy = UIParent:GetCenter()
            cfg.pos.x = x - ux
            cfg.pos.y = y - uy

            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "CENTER", cfg.pos.x, cfg.pos.y)
        end
    end)
    --f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        cfg.pos.x = x - ux
        cfg.pos.y = y - uy
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
    MaxDpsSpellFrame:ClearAllPoints()
    MaxDpsSpellFrame:SetPoint("CENTER", UIParent, "CENTER", cfg.pos.x, cfg.pos.y)

    MaxDpsSpellFrame.bindText:SetText(ShortenKeybind(GetSpellKeybind(spellID)))

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
end
