local addonName, MaxDps = ...

LibStub('AceAddon-3.0'):NewAddon(MaxDps, 'MaxDps','AceBucket-3.0' , 'AceConsole-3.0', 'AceEvent-3.0', 'AceTimer-3.0')

--- @class MaxDps
_G[addonName] = MaxDps

local TableInsert = tinsert
local TableRemove = tremove
local TableContains = tContains
local TableIndexOf = tIndexOf

local UnitIsFriend = UnitIsFriend
local IsPlayerSpell = IsPlayerSpell
local UnitClass = UnitClass
local CreateFrame = CreateFrame
local GetAddOnInfo = C_AddOns.GetAddOnInfo
local GetSpecializationInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local LoadAddOn = C_AddOns.LoadAddOn
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

local WOW_PROJECT_ID = WOW_PROJECT_ID
local WOW_PROJECT_CLASSIC = WOW_PROJECT_CLASSIC
local WOW_PROJECT_BURNING_CRUSADE_CLASSIC = WOW_PROJECT_BURNING_CRUSADE_CLASSIC
local WOW_PROJECT_WRATH_CLASSIC = WOW_PROJECT_WRATH_CLASSIC
local WOW_PROJECT_CATACLYSM_CLASSIC = WOW_PROJECT_CATACLYSM_CLASSIC
local WOW_PROJECT_MISTS_CLASSIC = WOW_PROJECT_MISTS_CLASSIC
local WOW_PROJECT_MAINLINE = WOW_PROJECT_MAINLINE
local LE_EXPANSION_LEVEL_CURRENT = LE_EXPANSION_LEVEL_CURRENT
local LE_EXPANSION_BURNING_CRUSADE =  LE_EXPANSION_BURNING_CRUSADE
local LE_EXPANSION_WRATH_OF_THE_LICH_KING = LE_EXPANSION_WRATH_OF_THE_LICH_KING
local LE_EXPANSION_CATACLYSM = LE_EXPANSION_CATACLYSM
local LE_EXPANSION_MISTS_OF_PANDARIA = LE_EXPANSION_MISTS_OF_PANDARIA

local spellHistoryBlacklist = {
    [75] = true -- Auto shot
}

function MaxDps:OnInitialize()
    self.db = LibStub('AceDB-3.0'):New('MaxDpsOptions', self.defaultOptions)

    self:RegisterChatCommand('maxdps', 'ShowMainWindow')

    if not self.db.global.customRotations then
        self.db.global.customRotations = {}
    end

    self:AddToBlizzardOptions()
end

function MaxDps:IsClassicWow()
    return WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
end

function MaxDps:IsSoDWow()
    return WOW_PROJECT_ID == WOW_PROJECT_CLASSIC and C_Seasons and C_Seasons.HasActiveSeason()
end

function MaxDps:IsTBCWow()
    return WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC and LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_BURNING_CRUSADE
end

function MaxDps:IsWrathWow()
    return WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC and LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_WRATH_OF_THE_LICH_KING
end

function MaxDps:IsCataWow()
    return WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC and LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_CATACLYSM
end

function MaxDps:IsMistsWow()
    return WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC and LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_MISTS_OF_PANDARIA
end

function MaxDps:IsRetailWow()
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
end

local LCS = LibStub("LibClassicSpecs-Doadin", true)
local GetSpecialization = LCS and LCS.GetSpecialization or C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization

function MaxDps:ShowMainWindow()
    if not self.Window then
        self.Window = self:GetModule('Window')
    end

    self.Window:ShowWindow()
end

function MaxDps:GetTexture()
    if self.db.global.customTexture ~= '' and self.db.global.customTexture ~= nil then
        self.FinalTexture = self.db.global.customTexture
        return self.FinalTexture
    end

    self.FinalTexture = self.db.global.texture
    if self.FinalTexture == '' or self.FinalTexture == nil then
        self.FinalTexture = 'Interface\\Cooldown\\ping4'
    end

    return self.FinalTexture
end

MaxDps.DefaultPrint = MaxDps.Print
function MaxDps:Print(message,level)
    if not level then level = "info" end
    if self.db.global.disabledInfo and self.db.global.disabledInfo == "none" then
        return
    elseif self.db.global.disabledInfo and self.db.global.disabledInfo == "all" then
        MaxDps:DefaultPrint(message)
    elseif self.db.global.disabledInfo and self.db.global.disabledInfo == "errorinfo" then
        if level == "error" or level == "info" then
            MaxDps:DefaultPrint(message)
        end
    elseif self.db.global.disabledInfo and self.db.global.disabledInfo == "error" then
        if level == "error" then
            MaxDps:DefaultPrint(message)
        end
    elseif self.db.global.disabledInfo and self.db.global.disabledInfo == "info" then
        if level == "info" then
            MaxDps:DefaultPrint(message)
        end
    end
end

MaxDps.profilerStatus = 0
function MaxDps:ProfilerStart()
    local profiler = self:GetModule('Profiler')
    profiler:StartProfiler()
    self.profilerStatus = 1
end

function MaxDps:ProfilerStop()
    local profiler = self:GetModule('Profiler')
    profiler:StopProfiler()
    self.profilerStatus = 0
end

function MaxDps:ProfilerToggle()
    if self.profilerStatus == 0 then
        self:ProfilerStart()
    else
        self:ProfilerStop()
    end
end

function MaxDps:EnableRotation(skipPrint)
    if self.NextSpell == nil then
        local className = self.Classes[self.ClassId]
        local module = 'MaxDps_' .. className
        local _, _, _, loadable, reason = GetAddOnInfo(module)

        if reason == 'MISSING' or reason == 'DISABLED' or (not loadable and reason ~= "DEMAND_LOADED") then
            self:Print(self.Colors.Error .. 'Could not find class module ' .. module .. ', reason: ' .. reason, "error")
            if not loadable and reason == 'DEMAND_LOADED' then
                self:Print(self.Colors.Error .. 'Addon was not loadable, this usually means it is not enabled please check for all characters or this one, that it is enabled!', "error")
            end
            self:Print(self.Colors.Error .. 'Make sure to install class module or create custom rotation', "error")
            self:Print(self.Colors.Error .. 'Missing addon: ' .. module, "error")
        elseif loadable then
            self:Print(self.Colors.Error .. 'Class Function is nil please report to author on discord. Along with ' .. UnitLevel("player") .. module, "error")
            if MaxDps:IsClassicWow() then
                self:Print(self.Colors.Error .. 'Classic WoW Client: True', "error")
            end
            if MaxDps:IsTBCWow() then
                self:Print(self.Colors.Error .. 'TBC WoW Client: True', "error")
            end
            if MaxDps:IsWrathWow() then
                self:Print(self.Colors.Error .. 'Wrath WoW Client: True', "error")
            end
            if MaxDps:IsCataWow() then
                self:Print(self.Colors.Error .. 'Cata WoW Client: True', "error")
            end
            if MaxDps:IsRetailWow() then
                self:Print(self.Colors.Error .. 'Retail WoW Client: True', "error")
            end
        end
    end

    if self.NextSpell == nil or self.rotationEnabled then
        local currentSpec = GetSpecialization()
        if currentSpec and currentSpec == 5 then
            self:Print(self.Colors.Error .. 'You are not in a spec, this is required for MaxDps to work!', "error")
        end
        self:Print(self.Colors.Error .. 'Failed to enable addon, either spec not supported or an error occured. If you have a spec please report on Discord, thanks!', "error")
        return
    end

    -- Track if error message was displayed to not spam
    self.Error = false

    self:Fetch()
    self:UpdateButtonGlow()

    self:CheckTalents()
    self:CheckIsPlayerMelee()
    if MaxDps:IsRetailWow() then
        self:GetAzeriteTraits()
        self:GetAzeriteEssences()
        self:GetCovenantInfo()
        self:GetLegendaryEffects()
    end
    if self.ModuleOnEnable then
        self.ModuleOnEnable()
    end

    self:EnableRotationTimer()

    self.rotationEnabled = true
end

function MaxDps:EnableRotationTimer()
    self.RotationTimer = self:ScheduleRepeatingTimer('InvokeNextSpell', self.db.global.interval)
end

function MaxDps:DisableRotation(skipPrint)
    if not self.rotationEnabled then
        return
    end

    self:DisableRotationTimer()

    self:DestroyAllOverlays()
    if not skipPrint then
        self:Print(self.Colors.Info .. 'Disabling', "info")
    end

    self.Spell = nil
    self.rotationEnabled = false
end

function MaxDps:DisableRotationTimer()
    if self.RotationTimer then
        self:CancelTimer(self.RotationTimer)
    end
end

local talentUpdateEvents
if MaxDps.IsRetailWow() then
    talentUpdateEvents = {
        "TRAIT_CONFIG_CREATED",
        "ACTIVE_COMBAT_CONFIG_CHANGED",
        "STARTER_BUILD_ACTIVATION_FAILED",
        "PLAYER_TALENT_UPDATE",
        "AZERITE_ESSENCE_ACTIVATED",
        "TRAIT_CONFIG_DELETED",
        "TRAIT_CONFIG_UPDATED",
        --"LOADING_SCREEN_DISABLED",
    }
else
    talentUpdateEvents = {
        "TRAIT_CONFIG_CREATED",
        --"ACTIVE_COMBAT_CONFIG_CHANGED",
        --"STARTER_BUILD_ACTIVATION_FAILED",
        "PLAYER_TALENT_UPDATE",
        "AZERITE_ESSENCE_ACTIVATED",
        "TRAIT_CONFIG_DELETED",
        "TRAIT_CONFIG_UPDATED",
        --"LOADING_SCREEN_DISABLED",
    }
end

local function FormatItemorSpell(str)
    if not str then return "" end
    if type(str) ~= "string" then return end
    return str:gsub("%s+", ""):gsub("%'", ""):gsub("%,", ""):gsub("%-", ""):gsub("%:", "")
end

function MaxDps:OnEnable()
    self:RegisterEvent('PLAYER_TARGET_CHANGED')
    self:RegisterEvent('PLAYER_REGEN_DISABLED')
    self:RegisterEvent('PLAYER_REGEN_ENABLED')
    self:RegisterEvent('LOADING_SCREEN_DISABLED')
    self:RegisterEvent('LOADING_SCREEN_ENABLED')

    for _, event in pairs(talentUpdateEvents) do
        self:RegisterEvent(event, 'TalentsUpdated')
    end

    self:RegisterBucketEvent('ACTIONBAR_SLOT_CHANGED', 1.5, 'ButtonFetch')
    self:RegisterEvent('ACTIONBAR_HIDEGRID', 'ButtonFetch')
    self:RegisterEvent('ACTIONBAR_PAGE_CHANGED', 'ButtonFetch')
    --self:RegisterBucketEvent('ACTIONBAR_UPDATE_STATE', 1, 'ButtonFetch')
    self:RegisterEvent('UPDATE_BONUS_ACTIONBAR', 'ButtonFetch')
    self:RegisterEvent('UPDATE_SHAPESHIFT_FORM', 'ButtonFetch')
    self:RegisterEvent('LEARNED_SPELL_IN_TAB', 'ButtonFetch')
    self:RegisterEvent('CHARACTER_POINTS_CHANGED', 'ButtonFetch')
    self:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED', 'ButtonFetch')
    self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED', 'ButtonFetch')
    self:RegisterEvent('UPDATE_MACROS', 'ButtonFetch')
    self:RegisterEvent('VEHICLE_UPDATE', 'ButtonFetch')
    self:RegisterEvent('UPDATE_STEALTH', 'ButtonFetch')
    self:RegisterEvent('SPELLS_CHANGED', 'ButtonFetch')
    --self:RegisterBucketEvent('SPELL_UPDATE_USABLE', 1, 'ButtonFetch')

    self:RegisterEvent('UNIT_ENTERED_VEHICLE')
    self:RegisterEvent('UNIT_EXITED_VEHICLE')

    self:RegisterEvent('NAME_PLATE_UNIT_ADDED')
    self:RegisterEvent('NAME_PLATE_UNIT_REMOVED')
    --	self:RegisterEvent('PLAYER_REGEN_ENABLED')

    if not self.playerUnitFrame then
        self.spellHistory = {}
        self.spellHistoryTime = {}

        self.playerUnitFrame = CreateFrame('Frame')
        self.playerUnitFrame:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player')
        self.playerUnitFrame:SetScript('OnEvent', function(_, _, _, _, spellId)
            -- event, unit, lineId
            if not spellHistoryBlacklist[spellId] and IsPlayerSpell(spellId) then
                TableInsert(self.spellHistory, 1, spellId)
                if MaxDps:IsRetailWow() then
                    if not self.spellHistoryTime[FormatItemorSpell(C_Spell.GetSpellName(spellId))] then
                        self.spellHistoryTime[FormatItemorSpell(C_Spell.GetSpellName(spellId))] = {}
                    end
                    self.spellHistoryTime[FormatItemorSpell(C_Spell.GetSpellName(spellId))].last_used = GetTime()

                    if #self.spellHistory > 5 then
                        TableRemove(self.spellHistory)
                    end
                else
                    if not self.spellHistoryTime[FormatItemorSpell(GetSpellInfo(spellId))] then
                        self.spellHistoryTime[FormatItemorSpell(GetSpellInfo(spellId))] = {}
                    end
                    self.spellHistoryTime[FormatItemorSpell(GetSpellInfo(spellId))].last_used = GetTime()

                    if #self.spellHistory > 5 then
                        TableRemove(self.spellHistory)
                    end
                end
            end
        end)
    end
    -- Set for Default
    MaxDps.incoming_damage_5 = 0
    MaxDps.incoming_damage_3 = 0

    self:Print(self.Colors.Info .. 'Initialized', "info")
end

MaxDps.visibleNameplates = {}
function MaxDps:NAME_PLATE_UNIT_ADDED(_, nameplateUnit)
    if not TableContains(self.visibleNameplates, nameplateUnit) then
        TableInsert(self.visibleNameplates, nameplateUnit)
    end
end

function MaxDps:NAME_PLATE_UNIT_REMOVED(_, nameplateUnit)
    local index = TableIndexOf(self.visibleNameplates, nameplateUnit)
    if index ~= nil then
        TableRemove(self.visibleNameplates, index)
    end
end

function MaxDps:TalentsUpdated()
    local currentState = self.rotationEnabled
    self:DisableRotation(true)
    self:UpdateSpellsAndTalents()
    -- Changing from "not self.db.global.onCombatEnter and not self.rotationEnabled"
    -- Regardles of onCombatEnter setting if the rotation was active keep it active
    -- Or in this case since we are modifiying spells temp disable then reenable
    -- so the user doesnt get missing spell errors, this should
    -- happen within a unnoticeable amount of time and be seamless to the user
    -- We need to track the original state though as disableRotation will set self.rotationEnabled false
    -- this is needed for situation like when a player levels up mid combat which triggers talent update
    if currentState then
        self:InitRotations(true)
        self:EnableRotation(true)
    end
end

function MaxDps:UpdateSpellsAndTalents()
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

    local className, classFilename, classId = UnitClass("player")
    local currentSpec = GetSpecialization()
    local id, name, description, icon, background, role
    if MaxDps:IsRetailWow() or MaxDps:IsMistsWow() then
        id, name, description, icon, background, role = GetSpecializationInfo(currentSpec)
    else
        --id, name, description, icon, background, role = GetSpecializationInfoForSpecID(currentSpec)
        id, name, description, icon, background, role = GetSpecializationInfoForClassID(classId, currentSpec)
    end

    if MaxDps:IsRetailWow() and MaxDps.classSpellData and id and idtoclass and idtoclass[classId] and idtospec and idtospec[id] then
        -- Insert Racials
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["Berserking"] = 26297
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["HyperOrganicLightOriginator"] = 312924
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["BloodFury"] = 20572
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["Shadowmeld"] = 58984
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["FerocityoftheFrostwolf"] = 274741
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["MightoftheBlackrock"] = 274742
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["ZealoftheBurningBlade"] = 274740
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["RictusoftheLaughingSkull"] = 274739
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["AncestralCall"] = 274738
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["ArcanePulse"] = 260369
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["Fireblood"] = 273104
        -- TWW Trinkets
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["house_of_cards"] = 466681
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["tome_of_lights_devotion"] = 443535
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["bestinslots"] = 473402
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["treacherous_transmitter"] = 449954
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["mad_queens_mandate"] = 443124
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["skardyns_grace"] = 92099
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["signet_of_the_priory"] = 443531
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["junkmaestros_mega_magnet"] = 1219661
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["geargrinders_spare_keys"] = 471059
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["grim_codex"] = 345739
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["ravenous_honey_buzzer"] = 448904
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["spymasters_web"] = 444959
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["imperfect_ascendancy_serum"] = 455482
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["neural_synapse_enhancer"] = 300612
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["aberrant_spellforge"] = 445619
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["nymues_unraveling_spindle"] = 422956
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["flarendos_pilot_light"] = 471142
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["algethar_puzzle_box"] = 383781
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["ingenious_mana_battery"] = 300968
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["high_speakers_accretion"] = 443415
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["gladiators_badge"] = 277185
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["hyperthread_wristwraps"] = 300142
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["burst_of_knowledge"] = 469925
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["ratfang_toxin"] = 1216604
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["funhouse_lens"] = 1213432
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["elementium_pocket_anvil"] = 401306
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["beacon_to_the_beyond"] = 402583
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["manic_grieftorch"] = 377463
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["time_thiefs_gambit"] = 417534
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["mirror_of_fractured_tomorrows"] = 418527
        --
        MaxDps.SpellTable = MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]
        for spellName,spellID in pairs(MaxDps.SpellTable) do
            local origSpellData = C_Spell.GetSpellInfo(spellID)
            local origSpellName = origSpellData and origSpellData.name
            local spellData = origSpellName and C_Spell.GetSpellInfo(origSpellName)
            if spellID and origSpellName and spellData then
                local newID = C_Spell.GetSpellInfo(C_Spell.GetSpellInfo(spellID).name).spellID
                local newSpellName = C_Spell.GetSpellInfo(C_Spell.GetSpellInfo(spellID).name).name
                if spellName == FormatItemorSpell(newSpellName) and spellID ~= newID then
                    MaxDps.SpellTable[spellName] = newID
                end
            end
        end
    end
    if MaxDps:IsCataWow() and MaxDps.classSpellData and idtoclass and idtoclass[classId] then
        -- Insert Racials
        --MaxDpsSpellTable[idtoclass[classId]][name]["Berserking"] = 26297
        --MaxDpsSpellTable[idtoclass[classId]][name]["HyperOrganicLightOriginator"] = 312924
        --MaxDpsSpellTable[idtoclass[classId]][name]["BloodFury"] = 20572
        --MaxDpsSpellTable[idtoclass[classId]][name]["Shadowmeld"] = 58984
        --MaxDpsSpellTable[idtoclass[classId]][name]["FerocityoftheFrostwolf"] = 274741
        --MaxDpsSpellTable[idtoclass[classId]][name]["MightoftheBlackrock"] = 274742
        --MaxDpsSpellTable[idtoclass[classId]][name]["ZealoftheBurningBlade"] = 274740
        --MaxDpsSpellTable[idtoclass[classId]][name]["RictusoftheLaughingSkull"] = 274739
        --MaxDpsSpellTable[idtoclass[classId]][name]["AncestralCall"] = 274738
        --MaxDpsSpellTable[idtoclass[classId]][name]["ArcanePulse"] = 260369
        --MaxDpsSpellTable[idtoclass[classId]][name]["Fireblood "] = 273104
        --
        --Insert Potions
        MaxDps.classSpellData[idtoclass[classId]]["VolcanicPotion"] = 58091
        MaxDps.classSpellData[idtoclass[classId]]["GolembloodPotion"] = 58146
        MaxDps.classSpellData[idtoclass[classId]]["TolvirPotion"] = 58145
        --
        MaxDps.SpellTable = MaxDps.classSpellData[idtoclass[classId]]
    end
    if MaxDps:IsClassicWow() then
        -- Insert Racials
        --MaxDpsSpellTable[idtoclass[classId]][name]["Berserking"] = 26297
        --MaxDpsSpellTable[idtoclass[classId]][name]["HyperOrganicLightOriginator"] = 312924
        --MaxDpsSpellTable[idtoclass[classId]][name]["BloodFury"] = 20572
        --MaxDpsSpellTable[idtoclass[classId]][name]["Shadowmeld"] = 58984
        --MaxDpsSpellTable[idtoclass[classId]][name]["FerocityoftheFrostwolf"] = 274741
        --MaxDpsSpellTable[idtoclass[classId]][name]["MightoftheBlackrock"] = 274742
        --MaxDpsSpellTable[idtoclass[classId]][name]["ZealoftheBurningBlade"] = 274740
        --MaxDpsSpellTable[idtoclass[classId]][name]["RictusoftheLaughingSkull"] = 274739
        --MaxDpsSpellTable[idtoclass[classId]][name]["AncestralCall"] = 274738
        --MaxDpsSpellTable[idtoclass[classId]][name]["ArcanePulse"] = 260369
        --MaxDpsSpellTable[idtoclass[classId]][name]["Fireblood "] = 273104
        --
        --Insert Potions
        --MaxDpsSpellTable[idtoclass[classId]]["VolcanicPotion"] = 58091
        --MaxDpsSpellTable[idtoclass[classId]]["GolembloodPotion"] = 58146
        --MaxDpsSpellTable[idtoclass[classId]]["TolvirPotion"] = 58145
        --

        MaxDps.SpellTable = {}
    end
    if MaxDps:IsMistsWow() and MaxDps.classSpellData and id and idtoclass and idtoclass[classId] and idtospec and idtospec[id] then
        MaxDps.SpellTable = {}
        --for tabIndex = 1, GetNumSpellTabs() do
        --    local _, texture, offset, numSpells = GetSpellTabInfo(tabIndex)
        --    for spellIndex = offset + 1, offset + numSpells do
        --        local spellName, spellSubName = GetSpellBookItemName(spellIndex, "spell")
        --        local spellType, spellID = GetSpellBookItemInfo(spellIndex, "spell")
        --        if spellType == "SPELL" and (classId and id and idtoclass[classId] and idtospec[id]) then
        --            if not MaxDps.classSpellData[idtoclass[classId]][idtospec[id]][FormatItemorSpell(spellName)] then
        --                MaxDps.classSpellData[idtoclass[classId]][idtospec[id]][FormatItemorSpell(spellName)] = spellID
        --            end
        --            if MaxDps.classSpellData[idtoclass[classId]][idtospec[id]][FormatItemorSpell(spellName)]
        --            and MaxDps.classSpellData[idtoclass[classId]][idtospec[id]][FormatItemorSpell(spellName)] ~= spellID then
        --                MaxDps.classSpellData[idtoclass[classId]][idtospec[id]][FormatItemorSpell(spellName)] = spellID
        --            end
        --        end
        --    end
        --end

        -- Insert Potions
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["VirmensBite"] = 105697
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["PotionoftheJadeSerpent"] = 105702
        MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]["PotionofMoguPower"] = 105706

        MaxDps.SpellTable = MaxDps.classSpellData[idtoclass[classId]][idtospec[id]]
    end
    --MaxDps.SpellInfoTable = {}
end

function MaxDps:UNIT_ENTERED_VEHICLE(_, unit)
    if unit == 'player' and self.rotationEnabled then
        self:DisableRotation()
    end
end

function MaxDps:UNIT_EXITED_VEHICLE(_, unit)
    if unit == 'player' and not self.rotationEnabled then
        self:UpdateSpellsAndTalents()
        self:InitRotations()
        self:EnableRotation()
    end
end

function MaxDps:PLAYER_TARGET_CHANGED()
    if self.rotationEnabled then
        if UnitIsFriend('player', 'target') then
            return
        else
            self:InvokeNextSpell()
        end
    end
end

function MaxDps:PLAYER_REGEN_DISABLED()
    if self.db.global.onCombatEnter and not self.rotationEnabled then
        self:Print(self.Colors.Success .. 'Auto enable on combat!', "info")
        self:UpdateSpellsAndTalents()
        self:InitRotations()
        self:EnableRotation()
    end
end

function MaxDps:PLAYER_REGEN_ENABLED()
    if self.db.global.onCombatEnter and self.rotationEnabled then
        self:DisableRotation()
    end
end

function MaxDps:LOADING_SCREEN_DISABLED()
    if not self.db.global.onCombatEnter and not self.rotationEnabled then
        self:Print(self.Colors.Success .. 'Rotation Enabled!', "info")
        self:UpdateSpellsAndTalents()
        self:InitRotations()
        self:EnableRotation()
    end
end

function MaxDps:LOADING_SCREEN_ENABLED()
    if not self.db.global.onCombatEnter and self.rotationEnabled then
        self:Print(self.Colors.Success .. 'Rotation Disabled!', "info")
        self:DisableRotation()
    end
end

--ButtenFetchTable = {}
function MaxDps:ButtonFetch(event)
    --ButtenFetchTable[event] = ButtenFetchTable[event] and ButtenFetchTable[event] + 1 or 1
    if self.rotationEnabled then
        if event ~= "SPELLS_CHANGED" or event ~= "UPDATE_SHAPESHIFT_FORM" or event ~= "UPDATE_BONUS_ACTIONBAR" or event ~= "UPDATE_STEALTH" then
            if self.fetchTimer then
                self:CancelTimer(self.fetchTimer)
            end
            self.fetchTimer = self:ScheduleTimer('Fetch', 0.5, event)
        end
        if event == "SPELLS_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_BONUS_ACTIONBAR" or event == "UPDATE_STEALTH" then
            MaxDps.Fetch(self, event)
        end
    end
end

function MaxDps:PrepareFrameData()
    if not self.FrameData then
        self.FrameData = {
            cooldown  = self.PlayerCooldowns,
        }
    end

    self.FrameData.activeDot = self.ActiveDots
    self.FrameData.timeShift, self.FrameData.currentSpell, self.FrameData.gcdRemains = MaxDps:EndCast()
    self.FrameData.gcd = self:GlobalCooldown()
    self.FrameData.buff, self.FrameData.debuff = self.PlayerAuras, self.TargetAuras
    self.FrameData.talents = self.PlayerTalents
    self.FrameData.azerite = self.AzeriteTraits
    self.FrameData.essences = self.AzeriteEssences
    self.FrameData.covenant = self.CovenantInfo
    self.FrameData.runeforge = self.LegendaryBonusIds
    self.FrameData.spellHistory = self.spellHistory
    self.FrameData.timeToDie = self:GetTimeToDie()
end

function MaxDps:err(s)
    if not self.Error then
	    self:Print(self.Colors.Error .. s, "error")
        self.Error = true
    end
    geterrorhandler()(s)
end

function MaxDps:InvokeNextSpell()
    -- invoke spell check
    local oldSkill = self.Spell

    self:PrepareFrameData()
    self:UpdateAuraData()

    self:GlowConsumables()

    -- Removed backward compatibility
    --self.Spell = self.NextSpell()
    local ok, res = xpcall(self.NextSpell, geterrorhandler(),self)
    if ok then
        self.Spell = res
    else
        if not self.Error then
            if GetCVar('ScriptErrors')=='1' then
                self:Print(self.Colors.Error .. "MaxDps Encountered an error, please report on Discord, including game version eg.Classic Retail Etc, And Class/Spec. Thanks!", "error")
            else
                self:Print(self.Colors.Error .. "MaxDps Encountered an error, displaying errors is not enabled please enable then report on Discord, including game version eg.Classic Retail Etc, And Class/Spec. Thanks!", "error")
                self:Print(self.Colors.Error .. "Can enable the game displaying errors by typing /run SetCVar(“ScriptErrors”,“1”), the same but change 1 to 0 to disable displaying errors.", "error")
            end
            if res then
                self:Print(self.Colors.Error .. res, "error")
            end
        end
        self.Error = true
    end

    if not self.db.global.cdOnlyMode then
        if self.Spell == 0 then
            self:GlowClear()
            if WeakAuras then
                WeakAuras.ScanEvents('MAXDPS_SPELL_UPDATE', nil)
            end
            return
        end
        if (oldSkill ~= self.Spell or oldSkill == nil) and self.Spell ~= nil and self.Spell ~= "" then
            self:GlowNextSpell(self.Spell)
            if WeakAuras then
                WeakAuras.ScanEvents('MAXDPS_SPELL_UPDATE', self.Spell)
            end
        end

        if (self.Spell == nil or self.Spell == "") and oldSkill ~= nil then
            self:GlowClear()
            if WeakAuras then
                WeakAuras.ScanEvents('MAXDPS_SPELL_UPDATE', nil)
            end
        end
    end
end

function MaxDps:InitRotations(skipPrint)
    local version = GetAddOnMetadata("MaxDps", "Version") or ""
    if not skipPrint then
        self:Print(self.Colors.Info .. version .. ' Initializing rotations', "info")
    end
    self:CountTier()

    local _, _, classId = UnitClass('player')
    local spec = GetSpecialization()

    self.ClassId = classId
    self.Spec = spec

    if not self.Custom then
        self.Custom = self:GetModule('Custom')
    end

    self.Custom:LoadCustomRotations()
    local customRotation = self.Custom:GetCustomRotation(classId, spec)

    if customRotation then
        self.NextSpell = customRotation.fn

        if not skipPrint then
            self:Print(self.Colors.Success .. 'Loaded Custom Rotation: ' .. customRotation.name, "info")
        end
    else
        self:LoadModule(skipPrint)
    end
end

function MaxDps:LoadModule(skipPrint)
    if self.Classes[self.ClassId] == nil then
        self:Print(self.Colors.Error .. 'Invalid player class, please contact author of addon.', "error")
        return
    end

    local className = self.Classes[self.ClassId]
    local module = 'MaxDps_' .. className
    local _, _, _, loadable, reason = GetAddOnInfo(module)

    local loadedOrLoading, loaded = IsAddOnLoaded(module)

    if loaded then
        self:InitTTD()
        self:EnableRotationModule(className, skipPrint)
        return
    else
        local sucess, value = LoadAddOn(module)
        if sucess then
            self:InitTTD()
            self:EnableRotationModule(className)
            return
        else
            self:Print(self.Colors.Error .. 'Error loading class module ' .. module .. ', reason: ' .. value, "error")
        end
    end

    if reason then
        self:Print(self.Colors.Error .. 'Could not load class module ' .. module .. ', reason: ' .. reason, "error")
    end

end

function MaxDps:EnableRotationModule(className, skipPrint)
    local loaded = self:EnableModule(className)

    if not loaded then
        self:Print(self.Colors.Error .. 'Could not find load module ' .. className .. ', reason: OUTDATED', "error")
    else
        if not skipPrint then
            local version = GetAddOnMetadata("MaxDps_" .. className, "Version") or ""
            self:Print(self.Colors.Info .. 'Finished Loading class module ' .. version, "info")
        end
    end
end
