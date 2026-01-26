--- @type MaxDps MaxDps
local _, MaxDps = ...

local CustomGlow = LibStub('LibCustomGlow-1.0')

local TableInsert = tinsert
local TableRemove = tremove
local GetItemSpell = C_Item.GetItemSpell
local GetSpecializationInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo or _G.GetSpellInfo
local GetSpellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName
local pairs = pairs
local select = select

local IsAddOnLoaded = C_AddOns.IsAddOnLoaded

local LCS = LibStub("LibClassicSpecs-Doadin", true)
local GetSpecialization = LCS and LCS.GetSpecialization or C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization

MaxDps.Spells = {}
MaxDps.ItemSpells = {} -- hash map of itemId -> itemSpellId
MaxDps.Flags = {}
MaxDps.SpellsGlowing = {}
MaxDps.FramePool = {}
MaxDps.Frames = {}

local LABs = {
    ['LibActionButton-1.0'] = true,
    ['LibActionButton-1.0-ElvUI'] = true,
    ["LibActionButton-1.0-KkthnxUI"] = true,
    ["LibActionButton-1.0-NDui"] = true,
    ["LibActionButton-1.0-ls"] = true,
}

--- Creates frame overlay over a specific frame, it doesn't need to be a button.
-- @param parent - frame that is suppose to be attached to
-- @param id - string id of overlay because frame can have multiple overlays
-- @param texture - optional custom texture
-- @param type - optional type of overlay, standard types are 'normal' and 'cooldown' - used to select overlay color
-- @param color - optional custom color in standard structure {r = 1, g = 1, b = 1, a = 1}
function MaxDps:CreateOverlay(parent, id, texture, overlayType, color)
    local frame = TableRemove(self.FramePool)
    if not frame then
        frame = CreateFrame('Frame', 'MaxDps_Overlay_' .. id, parent)
    end

    local sizeMult = self.db.global.sizeMult or 1.4
    frame:SetParent(parent)
    frame:SetFrameStrata('HIGH')
    frame:SetPoint('CENTER', 0, 0)
    frame:SetWidth(parent:GetWidth() * sizeMult)
    frame:SetHeight(parent:GetHeight() * sizeMult)
    local f = frame.Maxtext
    if not f then
        f = frame:CreateFontString('nil', "OVERLAY", "GameFontNormal")
        f:SetPoint("CENTER", frame, "CENTER") -- Position the text in the center of the frame
        local font, _, flags = f:GetFont()
        f:SetFont(font, 30, flags) -- Set the font with a new size (20 in this case)
        f:SetText("") -- Set the text
        f:SetTextColor(1, 1, 1, 1) -- Red color with full opacity
        frame.Maxtext = f
    end
    --local myText = frame:CreateFontString('MaxDps_Overlay_Text_' .. id, "OVERLAY", "GameFontNormal")
    --myText:SetPoint("CENTER", frame, "CENTER") -- Position the text in the center of the frame
    --myText:SetText("") -- Set the text

    local t = frame.texture
    if not t then
        t = frame:CreateTexture('GlowOverlay', 'OVERLAY')
        t:SetTexture(texture or MaxDps:GetTexture())
        t:SetBlendMode('ADD')
        frame.texture = t
    end

    t:SetAllPoints(frame)
    if color then
        if type(color) ~= 'table' then
            color = self.db.global.highlightColor
        end
        t:SetVertexColor(color.r, color.g, color.b, color.a)
    elseif overlayType then
        frame.ovType = overlayType
        if overlayType == 'normal' then
            local c = self.db.global.highlightColor
            t:SetVertexColor(c.r, c.g, c.b, c.a)
        elseif overlayType == 'cooldown' then
            local c = self.db.global.cooldownColor
            t:SetVertexColor(c.r, c.g, c.b, c.a)
        end
    end

    TableInsert(self.Frames, frame)
    return frame
end

function MaxDps:DestroyAllOverlays()
    for _, frame in pairs(self.Frames) do
        frame:GetParent().MaxDpsOverlays = nil
        frame:ClearAllPoints()
        frame:Hide()
        frame:SetParent(UIParent)
        frame.width = nil
        frame.height = nil
    end

    for key, frame in pairs(self.Frames) do
        TableInsert(self.FramePool, frame)
        self.Frames[key] = nil
    end
end

function MaxDps:ApplyOverlayChanges()
    for _, frame in pairs(self.Frames) do
        local sizeMult = self.db.global.sizeMult or 1.4
        frame:SetWidth(frame:GetParent():GetWidth() * sizeMult)
        frame:SetHeight(frame:GetParent():GetHeight() * sizeMult)
        frame.texture:SetTexture(MaxDps:GetTexture())
        frame.texture:SetAllPoints(frame)

        if frame.ovType == 'normal' then
            local c = self.db.global.highlightColor
            frame.texture:SetVertexColor(c.r, c.g, c.b, c.a)
        elseif frame.ovType == 'cooldown' then
            local c = self.db.global.cooldownColor
            frame.texture:SetVertexColor(c.r, c.g, c.b, c.a)
        end
    end
end

local origShow
function MaxDps:UpdateButtonGlow()
    if self.db.global.disableButtonGlow then
        ActionBarActionEventsFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')

        for LAB in pairs(LABs) do
            local lib = LibStub(LAB, true)
            if lib then
                lib.eventFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
            end
        end

        if not origShow then
            local LBG = LibStub('LibButtonGlow-1.0', true)
            if LBG then
                origShow = LBG.ShowOverlayGlow
                LBG.ShowOverlayGlow = nop
            end
        end
    else
        ActionBarActionEventsFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')

        for LAB in pairs(LABs) do
            local lib = LibStub(LAB, true)
            if lib then
                lib.eventFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW')
            end
        end

        if origShow then
            local LBG = LibStub('LibButtonGlow-1.0', true)
            if LBG then
                LBG.ShowOverlayGlow = origShow
                origShow = nil
            end
        end
    end
end

function MaxDps:Glow(button, id, texture, type, color, alpha)
    local opts = self.db.global
    if opts.customGlow then
        local col = color and {color.r, color.g, color.b, color.a} or nil
        if not color and type then
            if type == 'normal' then
                local c = self.db.global.highlightColor
                col = {c.r, c.g, c.b, c.a}
            elseif type == 'cooldown' then
                local c = self.db.global.cooldownColor
                col = {c.r, c.g, c.b, c.a}
            end
        end

        if opts.customGlowType == 'pixel' then
            CustomGlow.PixelGlow_Start(
                button,
                col,
                opts.customGlowLines,
                opts.customGlowFrequency,
                opts.customGlowLength,
                opts.customGlowThickness,
                0,
                0,
                false,
                id
            )
        else
            CustomGlow.AutoCastGlow_Start(
                button,
                col,
                math.ceil(opts.customGlowParticles),
                opts.customGlowParticleFrequency,
                opts.customGlowScale,
                0,
                0,
                id
            )
        end
        return
    end

    if button.MaxDpsOverlays and button.MaxDpsOverlays[id] then
        button.MaxDpsOverlays[id]:Show()
        if color and alpha then
            button.MaxDpsOverlays[id].texture:SetVertexColor(color.r, color.g, color.b, alpha)
        elseif color then
            button.MaxDpsOverlays[id].texture:SetVertexColor(color.r, color.g, color.b, color.a)
        end
        button.MaxDpsOverlays[id].Maxtext:SetText("")
        if id and ( (MaxDps.empowerLevel and MaxDps.FrameData.empowerLevel and MaxDps.FrameData.empowerLevel[id]) ) then
            button.MaxDpsOverlays[id].Maxtext:SetText(MaxDps.empowerLevel[id])
        else
            button.MaxDpsOverlays[id].Maxtext:SetText("")
        end
        if id and ( (MaxDps.Spell and MaxDps.FrameData.empowerLevel and MaxDps.FrameData.empowerLevel[MaxDps.Spell]) ) then
            button.MaxDpsOverlays[id].Maxtext:SetText(MaxDps.FrameData.empowerLevel[MaxDps.Spell])
        else
            button.MaxDpsOverlays[id].Maxtext:SetText("")
        end
    else
        if not button.MaxDpsOverlays then
            button.MaxDpsOverlays = {}
        end
        button.MaxDpsOverlays[id] = self:CreateOverlay(button, id, texture, type, color)
        button.MaxDpsOverlays[id]:Show()
        if color and alpha then
            button.MaxDpsOverlays[id].texture:SetVertexColor(color.r, color.g, color.b, alpha)
        elseif color then
            button.MaxDpsOverlays[id].texture:SetVertexColor(color.r, color.g, color.b, color.a)
        end
        if id and ( (MaxDps.empowerLevel and MaxDps.FrameData.empowerLevel and MaxDps.FrameData.empowerLevel[id]) ) then
            button.MaxDpsOverlays[id].Maxtext:SetText(MaxDps.empowerLevel[id])
        else
            button.MaxDpsOverlays[id].Maxtext:SetText("")
        end
        if id and ( (MaxDps.Spell and MaxDps.FrameData.empowerLevel and MaxDps.FrameData.empowerLevel[MaxDps.Spell]) ) then
            button.MaxDpsOverlays[id].Maxtext:SetText(MaxDps.FrameData.empowerLevel[MaxDps.Spell])
        else
            button.MaxDpsOverlays[id].Maxtext:SetText("")
        end
    end
end

function MaxDps:HideGlow(button, id)
    local opts = self.db.global
    if opts.customGlow then
        if opts.customGlowType == 'pixel' then
            CustomGlow.PixelGlow_Stop(button, id)
        else
            CustomGlow.AutoCastGlow_Stop(button, id)
        end
        return
    end

    if button.MaxDpsOverlays and button.MaxDpsOverlays[id] then
        button.MaxDpsOverlays[id]:Hide()
    end
end

function MaxDps:AddButton(spellId, button)
    if spellId then
        if self.Spells[spellId] == nil then
            self.Spells[spellId] = {}
        end

        TableInsert(self.Spells[spellId], button)
    end
end

-- this should be pretty universal
function MaxDps:AddItemButton(button)
    -- support for trinkets and potions
    local actionSlot = button:GetAttribute('action') or button.action

    if actionSlot and (IsEquippedAction(actionSlot) or IsConsumableAction(actionSlot)) then
        local type, itemId = GetActionInfo(actionSlot)
        if type == 'item' and itemId then
            local _, itemSpellId = GetItemSpell(itemId) --spellName, itemSpellId
            self.ItemSpells[itemId] = itemSpellId

            self:AddButton(itemSpellId, button)
        end
    end
end

function MaxDps:AddStandardButton(button)
    local btype = button:GetAttribute('type')
    if btype then
        local actionType = button:GetAttribute(btype)
        local spellId = nil

        if btype == 'action' then
            local slot = button:GetAttribute('action')
            if not slot or slot == 0 then
                slot = button.GetPagedID and button:GetPagedID() or button.action
            end
            if not slot or slot == 0 then
                slot = button:CalculateAction()
            end

            if HasAction(slot) then
                btype, actionType = GetActionInfo(slot)
            else
                return
            end
        end

        if btype == 'macro' then
            spellId = actionType and GetMacroSpell(actionType)
            if spellId == nil then
                if button and not button.GetPagedID and button.id then
                    button.GetPagedID = function ()
                        return button.id
                    end
                end
                local macroslot = button.GetPagedID and button:GetPagedID() or button.action
                spellId = macroslot and select(2,GetActionInfo(macroslot))
            end
        elseif btype == 'item' then
            self:AddItemButton(button)
            return
        elseif btype == 'spell' then
            --if MaxDps:IsRetailWow() then
                local spellInfo = GetSpellInfo(actionType)
                spellId = spellInfo and spellInfo.spellID
            --else
            --    spellId = select(7,GetSpellInfo(actionType))
            --end
        end

        if spellId and button then
            self:AddButton(spellId, button)
        --else
            --MaxDps:Print(self.Colors.Error .. "Erorr Adding Standard Button", "error", spellId)
        end
    end
    -- Following code is for stance bars
    -- local _, _, hasAction, spellID = GetShapeshiftFormInfo(id)
    -- Above code will cause error in retail with some buttons and non-blizzard action bars
    if button and button.Name and button.Name.GetName and button.Name.GetName(button):find('Stance') then
        local id = button:GetID()
        if id then
            if id >=1 and id <= GetNumShapeshiftForms() then
                local _, _, hasAction, spellID = GetShapeshiftFormInfo(id)
                if hasAction and spellID then
                    self:AddButton(spellID, button)
                end
            end
        end
    end
    -- End stance bar code
    -- Start pet bar code
    if button and button.Name and button.Name.GetName then
        if button.Name.GetName(button):match('^PetActionButton') then
            local id = button:GetID()
            if id then
                local _, _, _, _, _, _, spellId = GetPetActionInfo(id)
                if spellId then
                    self:AddButton(spellId, button)
                end
            end
        end
    end
    if IsAddOnLoaded('Bartender4') then
        if button.Name.GetName(button):match('^BT4PetButton') then
            if button and button.id then
                local id = button.id
                if id then
                    local _, _, _, _, _, _, spellId = GetPetActionInfo(id)
                    if spellId then
                        self:AddButton(spellId, button)
                    end
                end
            end
        end
    end
    -- End pet bar code
end

function MaxDps:Fetch(event)
    if self.rotationEnabled then
        self:DisableRotationTimer()
    end
    self.Spell = nil

    self:GlowClear()

    self.Spells = {}
    self.ItemSpells = {}
    self.Flags = {}
    self.SpellsGlowing = {}

    self:FetchLibActionButton()
    self:FetchBlizzard()

    -- It does not alter original button frames so it needs to be fetched too
    if IsAddOnLoaded('Bartender4') then
        self:Bartender4()
    end

    if IsAddOnLoaded('ButtonForge') then
        self:FetchButtonForge()
    end

    -- ElvUI uses LibActionButton but not for stance bar
    if IsAddOnLoaded('ElvUI') then
        self:FetchElvUI()
    end

    if IsAddOnLoaded('G15Buttons') then
        self:FetchG15Buttons()
    end

    if IsAddOnLoaded('SyncUI') then
        self:FetchSyncUI()
    end

    if IsAddOnLoaded('LUI') then
        self:FetchLUI()
    end

    if IsAddOnLoaded('Dominos') then
        self:FetchDominos()
    end

    if IsAddOnLoaded('DiabolicUI') then
        self:FetchDiabolic()
    end

    if IsAddOnLoaded('AzeriteUI') then
        self:FetchAzeriteUI()
    end

    if IsAddOnLoaded('Neuron') then
        self:FetchNeuron()
    end

    if IsAddOnLoaded('DragonflightUI') then
        self:FetchDragonflightUIButtons()
    end

    if self.rotationEnabled then
        self:EnableRotationTimer()
        self:InvokeNextSpell()
    end
end

function MaxDps:Bartender4()
    -- Uses LibActionButton but for some reason at least in cata classic not for stance bar
    for i = 1, 10 do
        local button = _G["BT4Stance" .. 'Button' .. i] and _G["BT4Stance" .. 'Button' .. i] or nil
        if button then
            self:AddStandardButton(button)
        end
    end
    for i = 1, 10 do
        local button = _G["BT4Pet" .. 'Button' .. i] and _G["BT4Pet" .. 'Button' .. i] or nil
        if button then
            self:AddStandardButton(button)
        end
    end
end

function MaxDps:FetchNeuron()
    for x = 1, 12 do
        for i = 1, 12 do
            local button = _G['NeuronActionBar' .. x .. '_' .. 'ActionButton' .. i]
            if button then
                self:AddStandardButton(button)
            end
        end
    end
end

function MaxDps:FetchDiabolic()
    local diabolicBars = {'EngineBar1', 'EngineBar2', 'EngineBar3', 'EngineBar4', 'EngineBar5'}
    for _, bar in pairs(diabolicBars) do
        for i = 1, 12 do
            local button = _G[bar .. 'Button' .. i]
            if button then
                self:AddStandardButton(button)
            end
        end
    end
end

function MaxDps:FetchDominos()
    local Dominos = LibStub("AceAddon-3.0"):GetAddon('Dominos',true)
    local _,dominosButtons = Dominos.ActionButtons:GetAll()
    for button in pairs(dominosButtons) do
        if button and not button.GetPagedID and button.id then
            button.GetPagedID = function ()
                return button.id
            end
        end
        if button then
            self:AddStandardButton(button)
        end
    end
    for i = 1, 10 do
        local button = _G["DominosStanceButton" .. i]
        if button then
            self:AddStandardButton(button)
        end
    end
end

function MaxDps:FetchAzeriteUI()
    --for i = 1, 24 do
    --	local button = _G['AzeriteUIActionButton' .. i]
    --	if button then
    --		self:AddStandardButton(button)
    --	end
    --end
    for b = 1, 8 do
        for i = 1, 12 do
            local button = _G['AzeriteActionBar'.. b .. 'Button' .. i]
            if button and not button.GetPagedID and button.id then
                button.GetPagedID = function ()
                    return button.id
                end
            end
            if button then
                self:AddStandardButton(button)
            end
        end
    end
    for b = 1, 10 do
        local button = _G['AzeriteStanceBar' .. 'Button' .. b]
        if button and not button.GetPagedID and button.id then
            button.GetPagedID = function ()
                return button.id
            end
        end
        if button then
            self:AddStandardButton(button)
        end
    end
end

function MaxDps:FetchLUI()
    local luiBars = {
        'LUIBarBottom1', 'LUIBarBottom2', 'LUIBarBottom3', 'LUIBarBottom4', 'LUIBarBottom5', 'LUIBarBottom6',
        'LUIBarRight1', 'LUIBarRight2', 'LUIBarLeft1', 'LUIBarLeft2'
    }

    for _, bar in pairs(luiBars) do
        for i = 1, 12 do
            local button = _G[bar .. 'Button' .. i]
            if button then
                self:AddStandardButton(button)
            end
        end
    end
end

function MaxDps:FetchSyncUI()
    local syncbars = {}

    syncbars[1] = SyncUI_ActionBar
    syncbars[2] = SyncUI_MultiBar
    syncbars[3] = SyncUI_SideBar.Bar1
    syncbars[4] = SyncUI_SideBar.Bar2
    syncbars[5] = SyncUI_SideBar.Bar3
    syncbars[6] = SyncUI_PetBar

    for _, bar in pairs(syncbars) do
        for i = 1, 12 do
            local button = bar['Button' .. i]
            if button then
                self:AddStandardButton(button)
            end
        end
    end
end

function MaxDps:RegisterLibActionButton(name)
    assert(type(name) == 'string', format('Bad argument to "RegisterLibActionButton", expected string, got "%s"', type(name)))

    if not name:match('LibActionButton%-1%.0') then
        error(format('Bad argument to "RegisterLibActionButton", expected "LibActionButton-1.0*", got "%s"', name), 2)
    end

    LABs[name] = true
end

-- ElvUI Uses FetchLibActionButton but not for stance bar
function MaxDps:FetchElvUI()
    for i = 1, 10 do
        local button = _G["ElvUI_StanceBarButton" .. i]
        if button then
            self:AddStandardButton(button)
        end
    end
end

function MaxDps:FetchLibActionButton()
    local _, libs  = LibStub:IterateLibraries()
    for libname in pairs(libs) do
        if libname:match('^LibActionButton%-1%.0') then
            local lib = LibStub(libname, true)
            for button in pairs(lib:GetAllButtons()) do
                local spellId = button:GetSpellId()
                if spellId then
                    self:AddButton(spellId, button)
                end

                self:AddItemButton(button)
            end
        end
    end
    --for LAB in pairs(LABs) do
    --    local lib = LibStub(LAB, true)
    --    if lib then
    --        for button in pairs(lib:GetAllButtons()) do
    --            local spellId = button:GetSpellId()
    --            if spellId then
    --                self:AddButton(spellId, button)
    --            end
--
    --            self:AddItemButton(button)
    --        end
    --    end
    --end
end

function MaxDps:FetchBlizzard()
    local BlizzardBars = {'Action', 'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft', 'MultiBar5', 'MultiBar6', 'MultiBar7'}
    for _, barName in pairs(BlizzardBars) do
        if _G[barName] or barName == "Action" then
            for i = 1, 12 do
                local button = _G[barName .. 'Button' .. i]
                if button then
                    self:AddStandardButton(button)
                end
            end
        end
    end
    for i = 1, 10 do
        local button = _G["Stance" .. 'Button' .. i]
        if button then
            self:AddStandardButton(button)
        end
    end
    for i = 1, 10 do
        local button = _G["PetActionButton" .. i]
        if button then
            if not button.GetPagedID and button.id then
                button.GetPagedID = function ()
                    return button.id
                end
            end
            self:AddStandardButton(button)
        end
    end
end

function MaxDps:FetchG15Buttons()
    local i = 2 -- it starts from 2
    while true do
        local button = _G['objG15_btn_' .. i]
        if not button then
            break
        end
        i = i + 1

        self:AddStandardButton(button)
    end
end

function MaxDps:FetchButtonForge()
    local i = 1
    while true do
        local button = _G['ButtonForge' .. i]
        if not button then
            break
        end
        i = i + 1

        MaxDps:AddStandardButton(button)
    end
end

function MaxDps:FetchDragonflightUIButtons()
    local DragonflightUIBars = {'DragonflightUIActionbarFrame1',
    'DragonflightUIActionbarFrame2',
    'DragonflightUIActionbarFrame3',
    'DragonflightUIActionbarFrame4',
    'DragonflightUIActionbarFrame5',
    'DragonflightUIActionbarFrame6',
    'DragonflightUIActionbarFrame7',
    'DragonflightUIActionbarFrame8'}
    for _, barName in pairs(DragonflightUIBars) do
        if type(_G[barName]) == "table" then
            for i,button in pairs(_G[barName].buttonTable) do
                if button and not button.GetPagedID and button.action then
                    button.GetPagedID = function ()
                        return button.action
                    end
                end
                self:AddStandardButton(button)
            end
        end
    end
end

function MaxDps:Dump()
    for k, _ in pairs(self.Spells) do
        local name
        if MaxDps:IsRetailWow() or MaxDps:IsMistsWow() then
            local spellInfo = GetSpellInfo(k)
            name = spellInfo and spellInfo.name
        else
            name = GetSpellInfo(k)
        end
        print(k, name)
    end
end

function MaxDps:DumpTalents()
    for spellID, Rank in pairs(self.FrameData.talents) do
        local name
        if MaxDps:IsRetailWow() or MaxDps:IsMistsWow() then
            local spellInfo = GetSpellInfo(spellID)
            name = spellInfo and spellInfo.name
        else
            name = GetSpellInfo(spellID)
        end
        print(spellID, name)
    end
end

function MaxDps:FindSpell(spellId)
    return self.Spells[spellId]
end

function MaxDps:GlowIndependent(spellId, id, texture, color, alpha)
    if self.Spells[spellId] ~= nil then
        for _, button in pairs(self.Spells[spellId]) do
            if MaxDps:IsRetailWow() then
                self:Glow(button, id, texture, nil, color, alpha)
            else
                self:Glow(button, id, texture, "cooldown", color)
            end
        end
    end
end

function MaxDps:ClearGlowIndependent(spellId, id)
    if self.Spells[spellId] ~= nil then
        for _, button in pairs(self.Spells[spellId]) do
            self:HideGlow(button, id)
        end
    end
end

function MaxDps:GlowCooldown(spellId, condition, color)
    if not spellId or spellId == 0 then
        return
    end
    local idtoclass = {
        [1] = "Warrior",
        [2] = "Paladin",
        [3] = "Hunter",
        [4] = "Rogue",
        [5] = "Priest",
        [6] = "Death Knight",
        [7] = "Shaman",
        [8] = "Mage",
        [9] = "Warlock",
        [10] = "Monk",
        [11] = "Druid",
        [12] = "Demon Hunter",
        [13] = "Evoker",
    }
	local idtospec = {
	    --Death Knight
	    [250] = "Blood",
	    [251] = "Frost",
	    [252] = "Unholy",
	    --Demon Hunter
	    [577] = "Havoc",
	    [581] = "Vengeance",
	    --Druid
	    [102] = "Balance",
	    [103] = "Feral",
	    [104] = "Guardian",
	    [105] = "Restoration",
		--Evoker
		[1473] = "Augmentation",
		[1467] = "Devastation",
		[1468] = "Preservation",
	    --Hunter
	    [253] = "Beast Mastery",
	    [254] = "Marksmanship",
	    [255] = "Survival",
	    --Mage
	    [62] = "Arcane",
	    [63] = "Fire",
	    [64] = "Frost",
	    --Monk
	    [268] = "Brewmaster",
	    [269] = "Windwalker",
	    [270] = "Mistweaver",
	    --Paladin
	    [65] = "Holy",
	    [66] = "Protection",
	    [70] = "Retribution",
	    --Priest
	    [256] = "Discipline",
	    [257] = "Holy",
	    [258] = "Shadow",
	    --Rogue
	    [259] = "Assassination",
	    [260] = "Outlaw",
	    [261] = "Subtlety",
	    --Shaman
	    [262] = "Elemental",
	    [263] = "Enhancement",
	    [264] = "Restoration",
	    --Warlock
	    [265] = "Affliction",
	    [266] = "Demonology",
	    [267] = "Destruction",
	    --Warrior
	    [71] = "Arms",
	    [72] = "Fury",
	    [73] = "Protection",
    }
    if MaxDps:IsRetailWow() and self.db.global.cdOnlyMode then
        if (C_AssistedCombat and C_AssistedCombat.GetRotationSpells()) or (AssistedCombatManager and AssistedCombatManager.rotationSpells) then
            local spells = AssistedCombatManager and AssistedCombatManager.rotationSpells or C_AssistedCombat.GetRotationSpells()
            if AssistedCombatManager and AssistedCombatManager.rotationSpells then
                if spells and spells[spellId] then
                    return
                end
            elseif C_AssistedCombat and C_AssistedCombat.GetRotationSpells() then
                for _, ACspellid in pairs(spells) do
                    if ACspellid == spellId then
                        return
                    end
                end
            end
        end
    end
    if MaxDps:IsRetailWow() or MaxDps:IsMistsWow() then
        local id = GetSpecializationInfo(GetSpecialization())
        if spellId == nil then
            self:Print(
                self.Colors.Error ..
                'Cannot find spellId for GlowCooldown in: ' .. "Class: " .. idtoclass[self.ClassId] .. "Spec: " .. idtospec[id],
                "error"
            )
            return
        end
    end
    if self.Flags[spellId] == nil then
        self.Flags[spellId] = false
    end
    if condition then
        self.Flags[spellId] = true
        self:GlowIndependent(spellId, spellId, nil, color)
    end
    if not condition then
        self.Flags[spellId] = false
        self:ClearGlowIndependent(spellId, spellId)
    end

    if WeakAuras then WeakAuras.ScanEvents('MAXDPS_COOLDOWN_UPDATE', self.Flags) end
end

function MaxDps:GlowDefensiveHPMidnight(spellId, condition)
    if not MaxDps.db.global.enableDefensives then
        if self.Flags[spellId] == nil then
            self.Flags[spellId] = false
        end
        if self.Flags[spellId] == true then
            self.Flags[spellId] = false
        end
        self:ClearGlowIndependent(spellId, spellId)
    end
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    curve:AddPoint(0.0, CreateColor(1, 0, 0, 1))
    curve:AddPoint(0.3, CreateColor(1, 1, 0, 0.5))
    curve:AddPoint(0.7, CreateColor(0, 1, 0, 0))
    local color = UnitHealthPercent("player", false, curve)
    local duration = C_Spell.GetSpellCooldownDuration(spellId)
    local durColor = duration and duration:EvaluateRemainingDuration(curve)
    local _, _, _, alpha = durColor:GetRGBA()
    if self.Flags[spellId] == nil then
        self.Flags[spellId] = false
    end
    if not UnitIsDeadOrGhost("player") then
        --print("Condition is true, applying glow for spellId: ", spellId)
        self.Flags[spellId] = true
        self:GlowIndependent(spellId, spellId, nil, color, alpha)
    end
    if UnitIsDeadOrGhost("player") then
        --print("Condition is false, clearing glow for spellId: ", spellId)
        self.Flags[spellId] = false
        self:ClearGlowIndependent(spellId, spellId)
    end
end

function MaxDps:GlowInteruptMidnight(spellId)
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    curve:AddPoint(0.0, CreateColor(1, 0, 0, 1))
    curve:AddPoint(0.3, CreateColor(1, 1, 0, 0.5))
    curve:AddPoint(0.7, CreateColor(0, 1, 0, 0))
    local color = UnitCastingDuration("target")
    local duration = C_Spell.GetSpellCooldownDuration(spellId)
    local durColor = duration and duration:EvaluateRemainingDuration(curve)
    local _, _, _, alpha = durColor:GetRGBA()
    if self.Flags[spellId] == nil then
        self.Flags[spellId] = false
    end
    if color then
        --print("Condition is true, applying glow for spellId: ", spellId)
        self.Flags[spellId] = true
        self:GlowIndependent(spellId, spellId, nil, CreateColor(1, 0, 0, 1), alpha)
    end
    if not color then
        --print("Condition is false, clearing glow for spellId: ", spellId)
        self.Flags[spellId] = false
        self:ClearGlowIndependent(spellId, spellId)
    end
end

function MaxDps:GlowCooldownMidnight(spellId, condition)
    local color = CreateColor(1, 0, 0, 1)

    if self.Flags[spellId] == nil then
        self.Flags[spellId] = false
    end

    if condition then
        self.Flags[spellId] = true
        self:GlowIndependent(spellId, spellId, nil, color)
    end
    if not condition then
        self.Flags[spellId] = false
        self:ClearGlowIndependent(spellId, spellId)
    end
end

function MaxDps:GlowSpell(spellId)
    local BaseSpellID = spellId and FindBaseSpellByID(spellId) or nil
    local overrideID = spellId and FindSpellOverrideByID(spellId) or nil
    local foundspell = false
    if self.Spells[spellId] ~= nil then
        for _, button in pairs(self.Spells[spellId]) do
            self:Glow(button, 'next', nil, 'normal')
        end

        self.SpellsGlowing[spellId] = 1
        foundspell = true
    elseif BaseSpellID and self.Spells[BaseSpellID] ~= nil then
        for _, button in pairs(self.Spells[BaseSpellID]) do
            self:Glow(button, 'next', nil, 'normal')
        end

        self.SpellsGlowing[BaseSpellID] = 1
        foundspell = true
    elseif overrideID and self.Spells[overrideID] ~= nil then
        for _, button in pairs(self.Spells[overrideID]) do
            self:Glow(button, 'next', nil, 'normal')
        end

        self.SpellsGlowing[overrideID] = 1
        foundspell = true
    end

    if (MaxDps:IsRetailWow() and not foundspell) or (MaxDps:IsClassicWow() or MaxDps:IsTBCWow()) then
        C_Spell.RequestLoadSpellData(spellId)
        local searchName = GetSpellName and GetSpellName(spellId) or GetSpellInfo(spellId)
        for spellid,v in pairs(self.Spells) do
            local knownSpellName = GetSpellName and GetSpellName(spellid) or GetSpellInfo(spellId)
            if searchName == knownSpellName then
                for _, button in pairs(self.Spells[spellid]) do
                    self:Glow(button, 'next', nil, 'normal')
                end
                self.SpellsGlowing[spellid] = 1
                foundspell = true
            end
        end
    end

    --elseif self.Spells[spellId] == nil and (BaseSpellID and self.Spells[BaseSpellID] == nil) and (overrideID and self.Spells[overrideID] == nil) then
    --    for _, index in pairs(self.Spells) do
    --        for _,button in pairs(index) do
    --            local slot = button and ( (button.GetPagedID and button:GetPagedID() ) or ( button.CalculateAction and button:CalculateAction() ) or ( button.GetAttribute and button:GetAttribute("action") ) or nil)
    --            if slot == nil then return end
    --            local actionName = nil
    --            if HasAction(slot) then
    --                local actionType, id, subType = GetActionInfo(slot)
    --                if not id then return end
    --                if actionType == "macro" then
    --                    actionName, _, id = GetMacroSpell(id)
    --                --elseif actionType == "item" then
    --                --	actionName = C_Item.GetItemInfo(id)
    --                --elseif actionType == "spell" then
    --                --	actionName = GetSpellInfo(id)
    --                end
    --                local FindSpellName
    --                if MaxDps:IsRetailWow() then
    --                    local spellInfo = GetSpellInfo(spellId)
    --                    FindSpellName = spellInfo and spellInfo.name
    --                else
    --                    FindSpellName = GetSpellInfo(spellId)
    --                end
    --                local searchName
    --                if MaxDps:IsRetailWow() then
    --                    local spellInfo = id and GetSpellInfo(id)
    --                    searchName = spellInfo and spellInfo.name
    --                else
    --                    searchName = id and GetSpellInfo(id)
    --                end
    --                --print("looking for: ",FindSpellName, " found", searchName)
    --                if FindSpellName and id and searchName and FindSpellName == searchName then
    --                    foundspell = true
    --                    self:Glow(button, 'next', nil, 'normal')
    --                end
    --            end
    --        end
    --    end
    --end
    if foundspell == false then
        local spellInfo = GetSpellInfo(spellId)
        local spellName = spellInfo and spellInfo.name

        if not IsMounted() then
            self:Print(
                self.Colors.Error ..
                'Spell not found on action bars: ' ..
                (spellName and spellName or 'Unknown') ..
                '(' .. spellId .. ')',
                "error"
            )
        end
    end
end

function MaxDps:GlowNextSpell(spellId)
    self:GlowClear()
    self:GlowSpell(spellId)
end

function MaxDps:GlowClear()
    for spellId, v in pairs(self.SpellsGlowing) do
        if v == 1 then
            for _, button in pairs(self.Spells[spellId]) do
                self:HideGlow(button, 'next')
            end
            self.SpellsGlowing[spellId] = 0
        end
    end
end

function MaxDps:GetButtonKeybind(button)
    -- Lib action button only so far
    local hotkey = button.HotKey
    if not hotkey then
        local hotkeyName = button:GetName() .. 'HotKey'
        hotkey = _G[hotkeyName]
    end

    if not hotkey then return nil end

    return hotkey:GetText()
end