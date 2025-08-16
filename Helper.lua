--- @type MaxDps MaxDps
local _, MaxDps = ...

-- Global cooldown spell id
local _GlobalCooldown = 61304

-- Bloodlust effects
local _Bloodlust = 2825
local _TimeWrap = 80353
local _Heroism = 32182
local _AncientHysteria = 90355
local _Netherwinds = 160452
local _DrumsOfFury = 178207
local _Exhaustion = 57723

local _Bloodlusts = { _Bloodlust, _TimeWrap, _Heroism, _AncientHysteria, _Netherwinds, _DrumsOfFury }

-- Global functions
local UnitAura = C_UnitAuras.GetAuraDataByIndex
local pairs = pairs
local ipairs = ipairs
local StringSplit = strsplit
local Select = select
local TableInsert = tinsert
local GetTalentInfo = GetTalentInfo
local C_AzeriteEmpoweredItem = C_AzeriteEmpoweredItem
local GetSpecializationInfo = GetSpecializationInfo
local AzeriteUtil = AzeriteUtil
local C_AzeriteEssence = C_AzeriteEssence
local FindSpellOverrideByID = FindSpellOverrideByID
local UnitCastingInfo = UnitCastingInfo
local GetItemCooldown = C_Item and C_Item.GetItemCooldown or GetItemCooldown
local GetTime = GetTime
local GetSpellCooldown = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown or GetSpellCooldown
local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo or GetSpellInfo
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local GetSpellBaseCooldown = GetSpellBaseCooldown
local IsSpellInRange = IsSpellInRange
local UnitSpellHaste = UnitSpellHaste
local GetSpellCharges = C_Spell and C_Spell.GetSpellCharges or GetSpellCharges
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local IsEquippedItem = C_Item.IsEquippedItem
local GetManaRegen = GetManaRegen
local GetSpellTabInfo = C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo or GetSpellTabInfo
local GetSpellBookItemInfo = C_SpellBook and C_SpellBook.GetSpellBookItemInfo or GetSpellBookItemInfo
local GetSpellBookItemName = C_SpellBook and C_SpellBook.GetSpellBookItemName or GetSpellBookItemName
local GetGlyphLink = C_GlyphInfo and C_GlyphInfo.GetGlyphLink or GetGlyphLink
local IsInInstance = IsInInstance
local IsItemInRange = C_Item.IsItemInRange
local UnitThreatSituation = UnitThreatSituation
local GetActiveCovenantID = C_Covenants and C_Covenants.GetActiveCovenantID
local GetActiveSoulbindID = C_Soulbinds and C_Soulbinds.GetActiveSoulbindID
local GetSoulbindData = C_Soulbinds and C_Soulbinds.GetSoulbindData

local LCS = LibStub("LibClassicSpecs-Doadin", true)
local GetSpecialization = LCS and LCS.GetSpecialization or C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization

-----------------------------------------------------------------
--- Internal replacement for UnitAura that no longer has ability
--- to filter by spell name
-----------------------------------------------------------------

function MaxDps:IntUnitAura(unit, nameOrId, filter, timeShift)
    local aura = {
        name           = nil,
        up             = false,
        upMath         = 0,
        count          = 0,
        expirationTime = 0,
        remains        = 0,
        refreshable    = true, -- well if it doesn't exist, then it is refreshable
        maxStacks      = 0,
    }

    local i = 1
    local t = GetTime()

    while true do
        --local name, _, count, _, duration, expirationTime, _, _, _, id = UnitAura(unit, i, filter)
        local auraData = UnitAura(unit, i, filter)
        local name = auraData and auraData.name
        local count = auraData and auraData.applications
        local duration = auraData and auraData.duration
        local expirationTime = auraData and auraData.expirationTime
        local id = auraData and auraData.spellId
        local maxstacks = auraData and auraData.maxCharges
        if not name then
            break
        end

        if name == nameOrId or id == nameOrId then
            local remains = 0

            if expirationTime == nil then
                remains = 0
            elseif (expirationTime - t) > timeShift then
                remains = expirationTime - t - timeShift
            elseif expirationTime == 0 then
                remains = 99999
            end

            if count == 0 then
                count = 1
            end

            return {
                name           = name,
                up             = remains > 0,
                upMath         = remains > 0 and 1 or 0,
                count          = count,
                expirationTime = expirationTime,
                remains        = remains,
                refreshable    = remains < 0.3 * duration,
                maxStacks      = maxstacks or 1,
            }
        end

        i = i + 1
    end

    return aura
end

function MaxDps:CollectAura(unit, timeShift, output, filter)
    filter = filter and filter or (unit == 'target' and 'PLAYER|HARMFUL' or nil)

    local t = GetTime()
    local i = 1
    for k, _ in pairs(output) do
        output[k] = nil
    end

    while true do
        -- name, _, count, _, duration, expirationTime, _, _, _, id
        local auraData = UnitAura(unit, i, filter)
        local name = auraData and auraData.name
        local count = auraData and auraData.applications
        local duration = auraData and auraData.duration
        local expirationTime = auraData and auraData.expirationTime
        local id = auraData and auraData.spellId
        local maxstacks = auraData and auraData.maxCharges
        local value = auraData and auraData.points and auraData.points[1]
        if not name then
            break
        end

        local remains = 0

        if expirationTime == nil then
            remains = 0
        elseif (expirationTime - t) > timeShift then
            remains = expirationTime - t - timeShift
        elseif expirationTime == 0 then
            remains = 99999
        end

        if count == 0 then
            count = 1
        end

        if id then
            output[id] = {
                name           = name,
                up             = remains > 0,
                upMath         = remains > 0 and 1 or 0,
                count          = count,
                expirationTime = expirationTime,
                remains        = remains,
                duration       = duration,
                refreshable    = remains < 0.3 * duration,
                maxStacks      = maxstacks or 1,
                value          = value or 0
            }
        end

        i = i + 1
    end
end

local auraMetaTable = {
    __index = function()
        return {
            up          = false,
            upMath      = 0,
            count       = 0,
            remains     = 0,
            duration    = 0,
            refreshable = true,
            maxStacks   = 0,
            value       = 0,
        }
    end
}

MaxDps.PlayerAuras = setmetatable({}, auraMetaTable)
MaxDps.TargetAuras = setmetatable({}, auraMetaTable)
MaxDps.PlayerCooldowns = setmetatable({}, {
    __index = function(table, key)
        return MaxDps:CooldownConsolidated(key, MaxDps.FrameData.timeShift)
    end
})
--local activeDotsMetaTable = {
--    __index = function()
--        return {
--            count          = 0,
--            remains        = 0,
--        }
--    end
--}
--MaxDps.ActiveDots = setmetatable({}, activeDotsMetaTable)
MaxDps.ActiveDots = {}
MaxDps.TargetDispels = {}

--function MaxDps:CollectAuras()
--    self:CollectAura('player', self.FrameData.timeShift, self.PlayerAuras)
--    self:CollectAura('target', self.FrameData.timeShift, self.TargetAuras)
--    return self.PlayerAuras, self.TargetAuras
--end

-- Function to calculate 'remains' dynamically
local function calculateRemains(aura)
    return (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime()
end

-- Function to calculate 'refreshable' dynamically
local function calculateRefreshable(aura)
    return (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration
end

function MaxDps:CollectAuras(unitTarget, updateInfo)
    if not unitTarget then
        return
    end
    local guid = UnitGUID(unitTarget)
    local targetGUID = UnitGUID("target")
    local playerGUID = UnitGUID("player")
    if (updateInfo and updateInfo.isFullUpdate) then
        local playerUnitauraInfo = {}
        local targetUnitauraInfo = {}
        local unitauraInfo = {}
        local targetDispelUnitAuraInfo = {}
        if (AuraUtil.ForEachAura) then
            if guid == playerGUID then
                AuraUtil.ForEachAura(unitTarget, "HELPFUL", nil,
                    function(aura)
                        if aura and aura.auraInstanceID then
                            playerUnitauraInfo[aura.auraInstanceID] = aura
                        end
                    end,
                true)
            end
            AuraUtil.ForEachAura(unitTarget, "PLAYER|HARMFUL", nil,
                function(aura)
                    if aura and aura.auraInstanceID then
                        if guid == targetGUID then
                            targetUnitauraInfo[aura.auraInstanceID] = aura
                        end
                        unitauraInfo[aura.auraInstanceID] = aura
                    end
                end,
            true)
            if guid == targetGUID and UnitIsEnemy('player',unitTarget) then
                AuraUtil.ForEachAura(unitTarget, "HELPFUL", nil,
                    function(aura)
                        if aura and aura.auraInstanceID then
                            targetDispelUnitAuraInfo[aura.auraInstanceID] = aura
                        end
                    end,
                true)
            end
        else
            for i = 0, 40 do
                if guid == playerGUID then
                    local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, i, "HELPFUL")
                    if auraData then
                        playerUnitauraInfo[auraData.auraInstanceID] = auraData
                    end
                end
            end
            for i = 0, 40 do
                local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, i, "PLAYER|HARMFUL")
                if auraData then
                    if guid == targetGUID then
                        targetUnitauraInfo[auraData.auraInstanceID] = auraData
                    end
                    unitauraInfo[auraData.auraInstanceID] = auraData
                end
            end
            for i = 0, 40 do
                if guid == targetGUID and UnitIsEnemy('player',unitTarget) then
                    local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, i, "HELPFUL")
                    if auraData then
                        targetDispelUnitAuraInfo[auraData.auraInstanceID] = auraData
                    end
                end
            end
        end
        if guid == playerGUID then
            for id, aura in pairs(self.PlayerAuras) do
                self.PlayerAuras[id] = nil
            end
        end
        if guid == targetGUID then
            for id, aura in pairs(self.TargetAuras) do
                self.TargetAuras[id] = nil
            end
        end
        if guid and self.ActiveDots[guid] then
            self.ActiveDots[guid] = nil
        end
        if guid == targetGUID and UnitIsEnemy('player',unitTarget) then
            for id, aura in pairs(self.TargetDispels) do
                self.TargetDispels[id] = nil
            end
        end
        for _, aura in pairs(playerUnitauraInfo) do
            if guid == playerGUID then
                self.PlayerAuras[aura.spellId] = {
                    name           = aura.name,
                    up             = true,
                    upMath         = 1,
                    count          = aura.applications > 0 and aura.applications or 1,
                    expirationTime = (aura.expirationTime >0 and aura.expirationTime or math.huge),
                    --remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime(),
                    duration       = aura.duration >0 and aura.duration or math.huge,
                    --refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration,
                    maxStacks      = aura.maxCharges and aura.maxCharges > 0 and aura.maxCharges or 1,
                    value          = aura.points[1],
                    auraID         = aura.auraInstanceID
                }
                setmetatable(self.PlayerAuras[aura.spellId], {
                    __index = function(_, key)
                        if key == "remains" then
                            return calculateRemains(self.PlayerAuras[aura.spellId]) -- Dynamically calculate remains for ID 123
                        end
                        if key == "refreshable" then
                            return calculateRefreshable(self.PlayerAuras[aura.spellId]) -- Dynamically calculate refreshable for ID 123
                        end
                    end
                })
            end
        end
        for _, aura in pairs(targetUnitauraInfo) do
            if guid == targetGUID then
                self.TargetAuras[aura.spellId] = {
                    name           = aura.name,
                    up             = true,
                    upMath         = 1,
                    count          = aura.applications > 0 and aura.applications or 1,
                    expirationTime = (aura.expirationTime >0 and aura.expirationTime or math.huge),
                    --remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime(),
                    duration       = aura.duration >0 and aura.duration or math.huge,
                    --refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration,
                    maxStacks      = aura.maxCharges and aura.maxCharges > 0 and aura.maxCharges or 1,
                    value          = aura.points[1],
                    auraID         = aura.auraInstanceID
                }
                setmetatable(self.TargetAuras[aura.spellId], {
                    __index = function(_, key)
                        if key == "remains" then
                            return calculateRemains(self.TargetAuras[aura.spellId]) -- Dynamically calculate remains for ID 123
                        end
                        if key == "refreshable" then
                            return calculateRefreshable(self.TargetAuras[aura.spellId]) -- Dynamically calculate refreshable for ID 123
                        end
                    end
                })
            end
        end
        for _, aura in pairs(unitauraInfo) do
            if guid and not self.ActiveDots[guid] then
                self.ActiveDots[guid] = {}
            end
            self.ActiveDots[guid][aura.auraInstanceID] = {
                name           = aura.name,
                up             = true,
                upMath         = 1,
                count          = aura.applications > 0 and aura.applications or 1,
                expirationTime = (aura.expirationTime >0 and aura.expirationTime or math.huge),
                --remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime(),
                duration       = aura.duration >0 and aura.duration or math.huge,
                --refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration,
                maxStacks      = aura.maxCharges and aura.maxCharges > 0 and aura.maxCharges or 1,
                value          = aura.points[1],
                spellId        = aura.spellId,
                auraID         = aura.auraInstanceID
            }
            setmetatable(self.ActiveDots[guid][aura.auraInstanceID], {
                __index = function(_, key)
                    if key == "remains" then
                        return calculateRemains(self.ActiveDots[guid][aura.auraInstanceID]) -- Dynamically calculate remains for ID 123
                    end
                    if key == "refreshable" then
                        return calculateRefreshable(self.ActiveDots[guid][aura.auraInstanceID]) -- Dynamically calculate refreshable for ID 123
                    end
                end
            })
        end
        for _, aura in pairs(targetDispelUnitAuraInfo) do
            if guid == targetGUID and UnitIsEnemy('player',unitTarget) and aura.isHelpful then
                self.TargetDispels[aura.spellId] = {
                    name           = aura.name,
                    up             = true,
                    upMath         = 1,
                    count          = aura.applications > 0 and aura.applications or 1,
                    expirationTime = (aura.expirationTime >0 and aura.expirationTime or math.huge),
                    --remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime(),
                    duration       = aura.duration >0 and aura.duration or math.huge,
                    --refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration,
                    maxStacks      = aura.maxCharges and aura.maxCharges > 0 and aura.maxCharges or 1,
                    value          = aura.points[1],
                    auraID         = aura.auraInstanceID
                }
                setmetatable(self.TargetDispels[aura.spellId], {
                    __index = function(_, key)
                        if key == "remains" then
                            return calculateRemains(self.TargetDispels[aura.spellId]) -- Dynamically calculate remains for ID 123
                        end
                        if key == "refreshable" then
                            return calculateRefreshable(self.TargetDispels[aura.spellId]) -- Dynamically calculate refreshable for ID 123
                        end
                    end
                })
            end
        end
    end

    if updateInfo and updateInfo.addedAuras then
        for _, aura in pairs(updateInfo.addedAuras) do
            if guid == playerGUID and aura.isHelpful then
                self.PlayerAuras[aura.spellId] = {
                    name           = aura.name,
                    up             = true,
                    upMath         = 1,
                    count          = aura.applications > 0 and aura.applications or 1,
                    expirationTime = (aura.expirationTime >0 and aura.expirationTime or math.huge),
                    --remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime(),
                    duration       = aura.duration >0 and aura.duration or math.huge,
                    --refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration,
                    maxStacks      = aura.maxCharges and aura.maxCharges > 0 and aura.maxCharges or 1,
                    value          = aura.points[1],
                    auraID         = aura.auraInstanceID
                }
                setmetatable(self.PlayerAuras[aura.spellId], {
                    __index = function(_, key)
                        if key == "remains" then
                            return calculateRemains(self.PlayerAuras[aura.spellId]) -- Dynamically calculate remains for ID 123
                        end
                        if key == "refreshable" then
                            return calculateRefreshable(self.PlayerAuras[aura.spellId]) -- Dynamically calculate refreshable for ID 123
                        end
                    end
                })
            end
            if guid == targetGUID and aura.isHarmful and aura.sourceUnit and ( UnitGUID(aura.sourceUnit) == UnitGUID("player") ) then
                self.TargetAuras[aura.spellId] = {
                    name           = aura.name,
                    up             = true,
                    upMath         = 1,
                    count          = aura.applications > 0 and aura.applications or 1,
                    expirationTime = (aura.expirationTime >0 and aura.expirationTime or math.huge),
                    --remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime(),
                    duration       = aura.duration >0 and aura.duration or math.huge,
                    --refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration,
                    maxStacks      = aura.maxCharges and aura.maxCharges > 0 and aura.maxCharges or 1,
                    value          = aura.points[1],
                    auraID         = aura.auraInstanceID
                }
                setmetatable(self.TargetAuras[aura.spellId], {
                    __index = function(_, key)
                        if key == "remains" then
                            return calculateRemains(self.TargetAuras[aura.spellId]) -- Dynamically calculate remains for ID 123
                        end
                        if key == "refreshable" then
                            return calculateRefreshable(self.TargetAuras[aura.spellId]) -- Dynamically calculate refreshable for ID 123
                        end
                    end
                })
            end
            if aura.isHarmful and aura.sourceUnit and ( UnitGUID(aura.sourceUnit) == UnitGUID("player") ) then
                if guid and not self.ActiveDots[guid] then
                    self.ActiveDots[guid] = {}
                end
                if guid then
                    self.ActiveDots[guid][aura.auraInstanceID] = {
                        name           = aura.name,
                        up             = true,
                        upMath         = 1,
                        count          = aura.applications > 0 and aura.applications or 1,
                        expirationTime = (aura.expirationTime >0 and aura.expirationTime or math.huge),
                        --remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime(),
                        duration       = aura.duration >0 and aura.duration or math.huge,
                        --refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration,
                        maxStacks      = aura.maxCharges and aura.maxCharges > 0 and aura.maxCharges or 1,
                        value          = aura.points[1],
                        spellId        = aura.spellId,
                        auraID         = aura.auraInstanceID
                    }
                    setmetatable(self.ActiveDots[guid][aura.auraInstanceID], {
                        __index = function(_, key)
                            if key == "remains" then
                                return calculateRemains(self.ActiveDots[guid][aura.auraInstanceID]) -- Dynamically calculate remains for ID 123
                            end
                            if key == "refreshable" then
                                return calculateRefreshable(self.ActiveDots[guid][aura.auraInstanceID]) -- Dynamically calculate refreshable for ID 123
                            end
                        end
                    })
                end
            end
            if guid == targetGUID and UnitIsEnemy('player',unitTarget) and aura.isHelpful then
                self.TargetDispels[aura.spellId] = {
                    name           = aura.name,
                    up             = true,
                    upMath         = 1,
                    count          = aura.applications > 0 and aura.applications or 1,
                    expirationTime = (aura.expirationTime >0 and aura.expirationTime or math.huge),
                    --remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime(),
                    duration       = aura.duration >0 and aura.duration or math.huge,
                    --refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration,
                    maxStacks      = aura.maxCharges and aura.maxCharges > 0 and aura.maxCharges or 1,
                    value          = aura.points[1],
                    auraID         = aura.auraInstanceID
                }
                setmetatable(self.TargetDispels[aura.spellId], {
                    __index = function(_, key)
                        if key == "remains" then
                            return calculateRemains(self.TargetDispels[aura.spellId]) -- Dynamically calculate remains for ID 123
                        end
                        if key == "refreshable" then
                            return calculateRefreshable(self.TargetDispels[aura.spellId]) -- Dynamically calculate refreshable for ID 123
                        end
                    end
                })
            end
        end
    end

    if updateInfo and updateInfo.updatedAuraInstanceIDs then
        for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unitTarget, auraInstanceID)
            if aura then
                if guid == playerGUID and aura.isHelpful then
                    self.PlayerAuras[aura.spellId] = {
                        name           = aura.name,
                        up             = true,
                        upMath         = 1,
                        count          = aura.applications > 0 and aura.applications or 1,
                        expirationTime = (aura.expirationTime >0 and aura.expirationTime or math.huge),
                        --remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime(),
                        duration       = aura.duration >0 and aura.duration or math.huge,
                        --refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration,
                        maxStacks      = aura.maxCharges and aura.maxCharges > 0 and aura.maxCharges or 1,
                        value          = aura.points[1],
                        auraID         = aura.auraInstanceID
                    }
                    setmetatable(self.PlayerAuras[aura.spellId], {
                        __index = function(_, key)
                            if key == "remains" then
                                return calculateRemains(self.PlayerAuras[aura.spellId]) -- Dynamically calculate remains for ID 123
                            end
                            if key == "refreshable" then
                                return calculateRefreshable(self.PlayerAuras[aura.spellId]) -- Dynamically calculate refreshable for ID 123
                            end
                        end
                    })
                end
                if guid == targetGUID and aura.isHarmful and aura.sourceUnit and ( UnitGUID(aura.sourceUnit) == UnitGUID("player") ) then
                    self.TargetAuras[aura.spellId] = {
                        name           = aura.name,
                        up             = true,
                        upMath         = 1,
                        count          = aura.applications > 0 and aura.applications or 1,
                        expirationTime = (aura.expirationTime >0 and aura.expirationTime or math.huge),
                        --remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime(),
                        duration       = aura.duration >0 and aura.duration or math.huge,
                        --refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration,
                        maxStacks      = aura.maxCharges and aura.maxCharges > 0 and aura.maxCharges or 1,
                        value          = aura.points[1],
                        auraID         = aura.auraInstanceID
                    }
                    setmetatable(self.TargetAuras[aura.spellId], {
                        __index = function(_, key)
                            if key == "remains" then
                                return calculateRemains(self.TargetAuras[aura.spellId]) -- Dynamically calculate remains for ID 123
                            end
                            if key == "refreshable" then
                                return calculateRefreshable(self.TargetAuras[aura.spellId]) -- Dynamically calculate refreshable for ID 123
                            end
                        end
                    })
                end
                if aura.isHarmful and aura.sourceUnit and ( UnitGUID(aura.sourceUnit) == UnitGUID("player") ) then
                    if guid and not self.ActiveDots[guid] then
                        self.ActiveDots[guid] = {}
                    end
                    if guid then
                        self.ActiveDots[guid][aura.auraInstanceID] = {
                            name           = aura.name,
                            up             = true,
                            upMath         = 1,
                            count          = aura.applications > 0 and aura.applications or 1,
                            expirationTime = (aura.expirationTime >0 and aura.expirationTime or math.huge),
                            --remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime(),
                            duration       = aura.duration >0 and aura.duration or math.huge,
                            --refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration,
                            maxStacks      = aura.maxCharges and aura.maxCharges > 0 and aura.maxCharges or 1,
                            value          = aura.points[1],
                            spellId        = aura.spellId,
                            auraID         = aura.auraInstanceID
                        }
                        setmetatable(self.ActiveDots[guid][aura.auraInstanceID], {
                            __index = function(_, key)
                                if key == "remains" then
                                    return calculateRemains(self.ActiveDots[guid][aura.auraInstanceID]) -- Dynamically calculate remains for ID 123
                                end
                                if key == "refreshable" then
                                    return calculateRefreshable(self.ActiveDots[guid][aura.auraInstanceID]) -- Dynamically calculate refreshable for ID 123
                                end
                            end
                        })
                    end
                end
                if guid == targetGUID and UnitIsEnemy('player',unitTarget) and aura.isHelpful then
                    self.TargetDispels[aura.spellId] = {
                        name           = aura.name,
                        up             = true,
                        upMath         = 1,
                        count          = aura.applications > 0 and aura.applications or 1,
                        expirationTime = (aura.expirationTime >0 and aura.expirationTime or math.huge),
                        --remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime(),
                        duration       = aura.duration >0 and aura.duration or math.huge,
                        --refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration,
                        maxStacks      = aura.maxCharges and aura.maxCharges > 0 and aura.maxCharges or 1,
                        value          = aura.points[1],
                        auraID         = aura.auraInstanceID
                    }
                    setmetatable(self.TargetDispels[aura.spellId], {
                        __index = function(_, key)
                            if key == "remains" then
                                return calculateRemains(self.TargetDispels[aura.spellId]) -- Dynamically calculate remains for ID 123
                            end
                            if key == "refreshable" then
                                return calculateRefreshable(self.TargetDispels[aura.spellId]) -- Dynamically calculate refreshable for ID 123
                            end
                        end
                    })
                end
            else
                for spellID,auraTable in pairs(self.PlayerAuras) do
                    if auraTable.auraID == auraInstanceID then
                        self.PlayerAuras[spellID] = nil
                    end
                end
                for spellID,auraTable in pairs(self.TargetAuras) do
                    if auraTable.auraID == auraInstanceID then
                        self.TargetAuras[spellID] = nil
                    end
                end
                if guid and self.ActiveDots[guid] then
                    for auraID,auraTable in pairs(self.ActiveDots[guid]) do
                        if auraID == auraInstanceID then
                            self.ActiveDots[guid][auraID] = nil
                        end
                    end
                end
                for spellID,auraTable in pairs(self.TargetDispels) do
                    if auraTable.auraID == auraInstanceID then
                        self.TargetDispels[spellID] = nil
                    end
                end
            end
        end
    end

    if updateInfo and updateInfo.removedAuraInstanceIDs then
        for _, auraInstanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
            for id, aura in pairs(self.PlayerAuras) do
                if auraInstanceID == aura.auraID then
                    self.PlayerAuras[id] = nil
                end
            end
            for id, aura in pairs(self.TargetAuras) do
                if auraInstanceID == aura.auraID then
                    self.TargetAuras[id] = nil
                end
            end
            if guid and self.ActiveDots[guid] then
                for auraID,auraTable in pairs(self.ActiveDots[guid]) do
                    if auraID == auraInstanceID then
                        self.ActiveDots[guid][auraID] = nil
                    end
                end
            end
            for id, aura in pairs(self.TargetDispels) do
                if auraInstanceID == aura.auraID then
                    self.TargetDispels[id] = nil
                end
            end
        end
    end
    if guid and self.ActiveDots[guid] then
        local numAuras = 0
        for id, info in pairs(self.ActiveDots[guid]) do
            numAuras = numAuras + 1
        end
        if numAuras == 0 then
            self.ActiveDots[guid] = nil
        end
    end

end

local collectAurasframe = CreateFrame("Frame")
collectAurasframe:SetScript("OnEvent", function(self, event, unitTarget, updateInfo)
    if event == "UNIT_AURA" then
        MaxDps:CollectAuras(unitTarget, updateInfo)
    end
    if event == "LOADING_SCREEN_DISABLED" then
        MaxDps:CollectAuras("player", {isFullUpdate = true} )
    end
    if event == "PLAYER_TARGET_CHANGED" then
        MaxDps:CollectAuras("target", {isFullUpdate = true} )
    end
end)
collectAurasframe:RegisterEvent("UNIT_AURA")
collectAurasframe:RegisterEvent("PLAYER_TARGET_CHANGED")
collectAurasframe:RegisterEvent("LOADING_SCREEN_DISABLED")

function MaxDps:UpdateAuraData()
    --if MaxDps.PlayerAuras then
    --    for id, aura in pairs(MaxDps.PlayerAuras) do
    --        MaxDps.PlayerAuras[id].remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime()
    --        MaxDps.PlayerAuras[id].refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration
    --    end
    --end
    --if MaxDps.TargetAuras then
    --    for id, aura in pairs(MaxDps.TargetAuras) do
    --        MaxDps.TargetAuras[id].remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime()
    --        MaxDps.TargetAuras[id].refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration
    --    end
    --end
    --if MaxDps.ActiveDots then
    --    for MobID, auraID in pairs(MaxDps.ActiveDots) do
    --        --print(MobID,auraID)
    --        for aid,info in pairs(auraID) do
    --            MaxDps.ActiveDots[MobID][aid].remains        = (info.expirationTime >0 and info.expirationTime or math.huge) - GetTime()
    --            MaxDps.ActiveDots[MobID][aid].refreshable    = (info.expirationTime >0 and info.expirationTime or math.huge) - GetTime() < 0.3 * info.duration
    --        end
    --    end
    --end
    --if MaxDps.TargetDispels then
    --    for id, aura in pairs(MaxDps.TargetDispels) do
    --        MaxDps.TargetAuras[id].remains        = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime()
    --        MaxDps.TargetAuras[id].refreshable    = (aura.expirationTime >0 and aura.expirationTime or math.huge) - GetTime() < 0.3 * aura.duration
    --    end
    --end
end

function MaxDps:DumpAuras()
    print('Player Auras')
    for id, aura in pairs(self.PlayerAuras) do
        print(aura.name .. '(' .. id .. '): ' .. aura.count)
    end

    print('Target Auras')
    for id, aura in pairs(self.TargetAuras) do
        print(aura.name .. '(' .. id .. '): ' .. aura.count)
    end
end

-----------------------------------------------------------------
--- Talents and specializations functions
-----------------------------------------------------------------

function MaxDps:SpecName()
    local currentSpec = GetSpecialization()
    local currentSpecName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or 'None'
    return currentSpecName
end

local heroidtoname = {
    [31] = "sanlayn",
    [38] = "chronowarden",
    [54] = "totemic",
    [62] = "colossus",
    [39] = "sunfury",
    [55] = "stormbringer",
    [20] = "oracle",
    [24] = "eluneschosen",
    [32] = "rideroftheapocalypse",
    [40] = "spellslinger",
    [48] = "templar",
    [56] = "farseer",
    [64] = "conduitofthecelestials",
    [65] = "shadopan",
    [41] = "frostfire",
    [49] = "lightsmith",
    [57] = "soulharvester",
    [66] = "masterofharmony",
    [21] = "druidoftheclaw",
    [34] = "felscarred",
    [42] = "sentinel",
    [50] = "heraldofthesun",
    [58] = "hellcaller",
    [35] = "aldrachireaver",
    [43] = "packleader",
    [51] = "trickster",
    [59] = "diabolist",
    [18] = "voidweaver",
    [22] = "wildstalker",
    [36] = "scalecommander",
    [44] = "darkranger",
    [52] = "fatebound",
    [60] = "slayer",
    [37] = "flameshaper",
    [53] = "deathstalker",
    [61] = "mountainthane",
    [19] = "archon",
    [23] = "keeperofthegrove",
    [33] = "deathbringer",
}

function MaxDps:CheckTalents()
    self.PlayerTalents = {}
    if MaxDps:IsRetailWow() then
        self.ActiveHeroTree = ""

        -- last selected configID or fall back to default spec config
        local configID = C_ClassTalents.GetActiveConfigID()
        local configInfo = configID and C_Traits.GetConfigInfo(configID)
        local treeIDs = configInfo and configInfo.treeIDs

        if not treeIDs then
            return
        end

        for _, treeID in ipairs(treeIDs) do
            local nodes = C_Traits.GetTreeNodes(treeID)
            for _, nodeID in ipairs(nodes) do
                if configID then
                    local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                    if nodeInfo.currentRank and nodeInfo.currentRank > 0 then
                        local entryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID and nodeInfo.activeEntry.entryID
                        local entryInfo = entryID and C_Traits.GetEntryInfo(configID, entryID)
                        local definitionInfo = entryInfo and entryInfo.definitionID and C_Traits.GetDefinitionInfo(entryInfo.definitionID)

                        if definitionInfo ~= nil then
                            self.PlayerTalents[definitionInfo.spellID] = nodeInfo.currentRank
                            if nodeInfo.subTreeID then
                                local subTreeInfo = C_Traits.GetSubTreeInfo(configID, nodeInfo.subTreeID)
                                if not subTreeInfo.isActive then
                                    self.PlayerTalents[definitionInfo.spellID] = nil
                                end
                                if subTreeInfo.isActive then
                                    --self.ActiveHeroTree = string.lower(subTreeInfo.name:gsub("%s+", ""):gsub("%'", ""):gsub("%,", ""):gsub("%-", ""):gsub("%:", ""))
                                    self.ActiveHeroTree = subTreeInfo and subTreeInfo.ID and heroidtoname[subTreeInfo.ID] or ""
                                end
                            end
                        end
                    end
                end
            end
        end
    elseif MaxDps:IsMistsWow() then
        for t=1,6 do
            for i=1,3 do
                local talentInfoQuery = {}
                local numColumns = 3
                talentInfoQuery.tier = t
                talentInfoQuery.column = i
                talentInfoQuery.groupIndex = "1"
                talentInfoQuery.isInspect = false
                talentInfoQuery.target = nil
                local talentInfo = C_SpecializationInfo.GetTalentInfo(talentInfoQuery)
                if talentInfo and talentInfo.name and talentInfo.known and talentInfo.spellID then
                    self.PlayerTalents[talentInfo.spellID] = 1
                end
            end
        end
    else
        if not MaxDpsTalentsSpellTooltip then
            local tip = CreateFrame( "GameTooltip", "MaxDpsTalentsSpellTooltip", nil, "GameTooltipTemplate" )
		    MaxDpsTalentsSpellTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
        end
        for tab = 1, GetNumTalentTabs() do
            for num_talent = 1, GetNumTalents(tab) do
                MaxDpsTalentsSpellTooltip:SetTalent(tab, num_talent)
                local _, spellID = MaxDpsTalentsSpellTooltip:GetSpell()
                local talentName, talentIcon, row , column , rank, maxrank = GetTalentInfo(tab, num_talent)
                --local talentId = (tab - 1) * MAX_NUM_TALENTS + num_talent
                if (talentName and talentIcon and spellID and rank > 0) then
                    if spellID then
                        self.PlayerTalents[spellID] = rank
                    end
                end
            end
        end
        MaxDpsTalentsSpellTooltip:Hide()
    end
end

MaxDps.isMelee = false
function MaxDps:CheckIsPlayerMelee()
    self.isMelee = false
    local class = select(3, UnitClass('player'))
    local spec = GetSpecialization()

    -- Warrior, Paladin, Rogue, DeathKnight, Monk, Demon Hunter
    if class == 1 or class == 2 or class == 4 or class == 6 or class == 10 or class == 12 then
        self.isMelee = true
    elseif class == 3 and spec == 3 then
        -- Survival Hunter
        self.isMelee = true
    elseif class == 7 and spec == 2 then
        -- Enh Shaman
        self.isMelee = true
    elseif class == 11 and (spec == 2 or spec == 3) then
        -- Guardian or Feral Druid
        self.isMelee = true
    end

    return self.isMelee
end

function MaxDps:HasTalent(talent)
    return self.PlayerTalents[talent]
end

function MaxDps:GetAzeriteTraits()
    local t = setmetatable({}, { __index = function()
        return 0
    end })

    for _, itemLocation in AzeriteUtil.EnumerateEquipedAzeriteEmpoweredItems() do
        local tierInfo = C_AzeriteEmpoweredItem.GetAllTierInfo(itemLocation)
        for i = 1, #tierInfo do
            for x = 1, #tierInfo[i].azeritePowerIDs do
                local powerId = tierInfo[i].azeritePowerIDs[x]
                if C_AzeriteEmpoweredItem.IsPowerSelected(itemLocation, powerId) then
                    local spellId = C_AzeriteEmpoweredItem.GetPowerInfo(powerId).spellID
                    if t[spellId] then
                        t[spellId] = t[spellId] + 1
                    else
                        t[spellId] = 1
                    end

                end

            end
        end
    end

    self.AzeriteTraits = t
    return t
end

function MaxDps:GetAzeriteEssences()
    if not self.AzeriteEssences then
        self.AzeriteEssences = {
            major = false,
            minor = {}
        }
    else
        self.AzeriteEssences.major = false
        self.AzeriteEssences.minor = {}
    end

    local result = self.AzeriteEssences

    return result
end

--- Get active covenant and soulbind Ids, use Enum.CovenantType for covenantId
---
function MaxDps:GetCovenantInfo()
    local covenantId = GetActiveCovenantID()
    local soulbindId = GetActiveSoulbindID()

    --if soulbindId == 0 then
    --	soulbindId = Soulbinds.GetDefaultSoulbindID(covenantId)
    --end

    local soulbindData = {}
    local soulbindAbilities = {}
    local soulbindConduits = {}

    if soulbindId ~= 0 then
        soulbindData = GetSoulbindData(soulbindId)

        if soulbindData.tree then
            for _, node in ipairs(soulbindData.tree.nodes) do
                if node.state == Enum.SoulbindNodeState.Selected then
                    if node.spellID ~= 0 then
                        soulbindAbilities[node.spellID] = true
                    end

                    if node.conduitID ~= 0 then
                        soulbindConduits[node.conduitID] = node.conduitRank
                    end
                end
            end
        end
    end

    self.CovenantInfo = {
        covenantId        = covenantId,
        soulbindId        = soulbindId,
        soulbindData      = soulbindData,
        soulbindAbilities = soulbindAbilities,
        soulbindConduits  = soulbindConduits,
    }

    return self.CovenantInfo
end

--[[
    Borrowed from WeakAuras

    This is free software: you can redistribute it and/or modify it under the terms of
    the GNU General Public License version 2 as published by the Free Software
    Foundation.

    For more information see WeakAuras License
]]
--------------------------------------------
--- Legendaries
--------------------------------------------
local generalLegendaries = {
    [7100] = true, -- Echo of Eonar
    [7102] = true, -- Norgannon's Sagacity
    [7103] = true, -- Sephuz's Proclamation
    [7104] = true, -- Stable Phantasma Lure
    [7105] = true, -- Third Eye of the Jailer
    [7106] = true, -- Vitality Sacrifice
}

local allLegendaryBonusIds = {
    SHAMAN      = { -- 7
        [6993] = true, -- Doom Winds
        [6997] = true, -- Jonat's Natural Focus
        [7102] = true, -- Norgannon's Sagacity
        [7106] = true, -- Vitality Sacrifice
        [6986] = true, -- Deeptremor Stone
        [6990] = true, -- Elemental Equilibrium
        [6994] = true, -- Legacy of the Frost Witch
        [6998] = true, -- Spiritwalker's Tidal Totem
        [7103] = true, -- Sephuz's Proclamation
        [6987] = true, -- Deeply Rooted Elements
        [6991] = true, -- Echoes of Great Sundering
        [6995] = true, -- Witch Doctor's Wolf Bones
        [6999] = true, -- Primal Tide Core
        [7100] = true, -- Echo of Eonar
        [7104] = true, -- Stable Phantasma Lure
        [6988] = true, -- Chains of Devastation
        [6992] = true, -- Windspeaker's Lava Resurgence
        [6996] = true, -- Primal Lava Actuators
        [7000] = true, -- Earthen Harmony
        [7159] = true, -- Maw Rattle
        [7101] = true, -- Judgment of the Arbiter
        [7105] = true, -- Third Eye of the Jailer
        [6985] = true, -- Ancestral Reminder
        [6989] = true, -- Skybreaker's Fiery Demise
    },
    WARRIOR     = { -- 1
        [6962] = true, -- Enduring Blow
        [6966] = true, -- Will of the Berserker
        [6970] = true, -- Unhinged
        [7102] = true, -- Norgannon's Sagacity
        [7106] = true, -- Vitality Sacrifice
        [6955] = true, -- Leaper
        [6959] = true, -- Signet of Tormented Kings
        [6963] = true, -- Cadence of Fujieda
        [6967] = true, -- Unbreakable Will
        [6971] = true, -- Seismic Reverberation
        [7103] = true, -- Sephuz's Proclamation
        [6956] = true, -- Thunderlord
        [6960] = true, -- Battlelord
        [6964] = true, -- Deathmaker
        [7100] = true, -- Echo of Eonar
        [7104] = true, -- Stable Phantasma Lure
        [6957] = true, -- The Wall
        [6961] = true, -- Exploiter
        [6965] = true, -- Reckless Defense
        [6969] = true, -- Reprisal
        [7159] = true, -- Maw Rattle
        [7101] = true, -- Judgment of the Arbiter
        [7105] = true, -- Third Eye of the Jailer
        [6958] = true, -- Misshapen Mirror
    },
    PALADIN     = { -- 2
        [7055] = true, -- Of Dusk and Dawn
        [7059] = true, -- Shock Barrier
        [7063] = true, -- Reign of Endless Kings
        [7067] = true, -- Tempest of the Lightbringer
        [7102] = true, -- Norgannon's Sagacity
        [7106] = true, -- Vitality Sacrifice
        [7056] = true, -- The Magistrate's Judgment
        [7060] = true, -- Holy Avenger's Engraved Sigil
        [7064] = true, -- Final Verdict
        [7103] = true, -- Sephuz's Proclamation
        [7053] = true, -- Uther's Devotion
        [7057] = true, -- Shadowbreaker, Dawn of the Sun
        [7061] = true, -- The Ardent Protector's Sanctum
        [7065] = true, -- Vanguard's Momentum
        [7100] = true, -- Echo of Eonar
        [7104] = true, -- Stable Phantasma Lure
        [7054] = true, -- The Mad Paragon
        [7058] = true, -- Inflorescence of the Sunwell
        [7062] = true, -- Bulwark of Righteous Fury
        [7128] = true, -- Maraad's Dying Breath
        [7101] = true, -- Judgment of the Arbiter
        [7105] = true, -- Third Eye of the Jailer
        [7159] = true, -- Maw Rattle
        [7066] = true, -- Relentless Inquisitor
    },
    ROGUE       = { -- 4
        [7117] = true, -- Zoldyck Insignia
        [7121] = true, -- Celerity
        [7125] = true, -- The Rotten
        [7102] = true, -- Norgannon's Sagacity
        [7106] = true, -- Vitality Sacrifice
        [7114] = true, -- Invigorating Shadowdust
        [7118] = true, -- Duskwalker's Patch
        [7122] = true, -- Concealed Blunderbuss
        [7126] = true, -- Deathly Shadows
        [7103] = true, -- Sephuz's Proclamation
        [7111] = true, -- Mark of the Master Assassin
        [7115] = true, -- Dashing Scoundrel
        [7119] = true, -- Greenskin's Wickers
        [7123] = true, -- Finality
        [7100] = true, -- Echo of Eonar
        [7104] = true, -- Stable Phantasma Lure
        [7112] = true, -- Tiny Toxic Blade
        [7116] = true, -- Doomblade
        [7120] = true, -- Guile Charm
        [7124] = true, -- Akaari's Soul Fragment
        [7159] = true, -- Maw Rattle
        [7101] = true, -- Judgment of the Arbiter
        [7105] = true, -- Third Eye of the Jailer
        [7113] = true, -- Essence of Bloodfang
    },
    MAGE        = { -- 8
        [6931] = true, -- Fevered Incantation
        [7102] = true, -- Norgannon's Sagacity
        [7106] = true, -- Vitality Sacrifice
        [6831] = true, -- Expanded Potential
        [6928] = true, -- Siphon Storm
        [6932] = true, -- Firestorm
        [6936] = true, -- Triune Ward
        [7103] = true, -- Sephuz's Proclamation
        [6828] = true, -- Cold Front
        [6832] = true, -- Disciplinary Command
        [6933] = true, -- Molten Skyfall
        [6937] = true, -- Grisly Icicle
        [7100] = true, -- Echo of Eonar
        [7104] = true, -- Stable Phantasma Lure
        [6829] = true, -- Freezing Winds
        [6926] = true, -- Arcane Infinity
        [6934] = true, -- Sun King's Blessing
        [6823] = true, -- Slick Ice
        [7159] = true, -- Maw Rattle
        [7101] = true, -- Judgment of the Arbiter
        [7105] = true, -- Third Eye of the Jailer
        [6830] = true, -- Glacial Fragments
        [6834] = true, -- Temporal Warp
        [6927] = true, -- Arcane Bombardment
    },
    WARLOCK     = { -- 9
        [7028] = true, -- Pillars of the Dark Portal
        [7032] = true, -- Wrath of Consumption
        [7036] = true, -- Balespider's Burning Core
        [7102] = true, -- Norgannon's Sagacity
        [7106] = true, -- Vitality Sacrifice
        [7025] = true, -- Wilfred's Sigil of Superior Summoning
        [7029] = true, -- Perpetual Agony of Azj'Aqir
        [7033] = true, -- Implosive Potential
        [7037] = true, -- Odr, Shawl of the Ymirjar
        [7103] = true, -- Sephuz's Proclamation
        [7026] = true, -- Claw of Endereth
        [7030] = true, -- Sacrolash's Dark Strike
        [7034] = true, -- Grim Inquisitor's Dread Calling
        [7100] = true, -- Echo of Eonar
        [7104] = true, -- Stable Phantasma Lure
        [7040] = true, -- Embers of the Diabolic Raiment
        [7027] = true, -- Relic of Demonic Synergy
        [7031] = true, -- Malefic Wrath
        [7159] = true, -- Maw Rattle
        [7101] = true, -- Judgment of the Arbiter
        [7105] = true, -- Third Eye of the Jailer
        [7039] = true, -- Madness of the Azj'Aqir
        [7038] = true, -- Cinders of the Azj'Aqir
        [7035] = true, -- Forces of the Horned Nightmare
    },
    PRIEST      = { -- 5
        [6974] = true, -- Flash Concentration
        [7102] = true, -- Norgannon's Sagacity
        [7106] = true, -- Vitality Sacrifice
        [7002] = true, -- Twins of the Sun Priestess
        [6975] = true, -- Cauterizing Shadows
        [7103] = true, -- Sephuz's Proclamation
        [6983] = true, -- Eternal Call to the Void
        [7162] = true, -- Talbadar's Stratagem
        [6982] = true, -- Shadowflame Prism
        [6981] = true, -- Painbreaker Psalm
        [6972] = true, -- Vault of Heavens
        [7100] = true, -- Echo of Eonar
        [7104] = true, -- Stable Phantasma Lure
        [6984] = true, -- X'anshi, Return of Archbishop Benedictus
        [6973] = true, -- Divine Image
        [6977] = true, -- Harmonious Apparatus
        [6976] = true, -- The Penitent One
        [6978] = true, -- Crystalline Reflection
        [7159] = true, -- Maw Rattle
        [7101] = true, -- Judgment of the Arbiter
        [7105] = true, -- Third Eye of the Jailer
        [6979] = true, -- Kiss of Death
        [6980] = true, -- Clarity of Mind
        [7161] = true, -- Measured Contemplation
    },
    MONK        = { -- 10
        [7102] = true, -- Norgannon's Sagacity
        [7106] = true, -- Vitality Sacrifice
        [7079] = true, -- Shaohao's Might
        [7184] = true, -- Escape from Reality
        [7068] = true, -- Keefer's Skyreach
        [7103] = true, -- Sephuz's Proclamation
        [7076] = true, -- Charred Passions
        [7080] = true, -- Swiftsure Wraps
        [7069] = true, -- Last Emperor's Capacitor
        [7071] = true, -- Jade Ignition
        [7070] = true, -- Xuen's Treasure
        [7100] = true, -- Echo of Eonar
        [7104] = true, -- Stable Phantasma Lure
        [7077] = true, -- Stormstout's Last Keg
        [7081] = true, -- Fatal Touch
        [7072] = true, -- Tear of Morning
        [7074] = true, -- Clouded Focus
        [7073] = true, -- Yu'lon's Whisper
        [7159] = true, -- Maw Rattle
        [7101] = true, -- Judgment of the Arbiter
        [7105] = true, -- Third Eye of the Jailer
        [7078] = true, -- Celestial Infusion
        [7082] = true, -- Invoker's Delight
        [7075] = true, -- Ancient Teachings of the Monastery
    },
    HUNTER      = { -- 3
        [7005] = true, -- Soulforge Embers
        [7102] = true, -- Norgannon's Sagacity
        [7106] = true, -- Vitality Sacrifice
        [7017] = true, -- Latent Poison Injectors
        [7006] = true, -- Craven Strategem
        [7103] = true, -- Sephuz's Proclamation
        [7014] = true, -- Secrets of the Unblinking Vigil
        [7018] = true, -- Butcher's Bone Fragments
        [7009] = true, -- Qa'pla, Eredun War Order
        [7013] = true, -- Serpentstalker's Trickery
        [7003] = true, -- Call of the Wild
        [7100] = true, -- Echo of Eonar
        [7104] = true, -- Stable Phantasma Lure
        [7015] = true, -- Wildfire Cluster
        [7012] = true, -- Surging Shots
        [7011] = true, -- Eagletalon's True Focus
        [7007] = true, -- Dire Command
        [7008] = true, -- Flamewaker's Cobra Sting
        [7004] = true, -- Nessingwary's Trapping Apparatus
        [7101] = true, -- Judgment of the Arbiter
        [7105] = true, -- Third Eye of the Jailer
        [7016] = true, -- Rylakstalker's Confounding Strikes
        [7010] = true, -- Rylakstalker's Piercing Fangs
        [7159] = true, -- Maw Rattle
    },
    DEATHKNIGHT = { -- 6
        [6943] = true, -- Gorefiend's Domination
        [7102] = true, -- Norgannon's Sagacity
        [7106] = true, -- Vitality Sacrifice
        [6940] = true, -- Bryndaor's Might
        [6944] = true, -- Koltira's Favor
        [7103] = true, -- Sephuz's Proclamation
        [6952] = true, -- Deadliest Coil
        [6951] = true, -- Death's Certainty
        [6950] = true, -- Frenzied Monstrosity
        [6949] = true, -- Reanimated Shambler
        [6941] = true, -- Crimson Rune Weapon
        [7100] = true, -- Echo of Eonar
        [7104] = true, -- Stable Phantasma Lure
        [6953] = true, -- Superstrain
        [7160] = true, -- Rage of the Frozen Champion
        [6946] = true, -- Absolute Zero
        [6945] = true, -- Biting Cold
        [6947] = true, -- Death's Embrace
        [6942] = true, -- Vampiric Aura
        [7101] = true, -- Judgment of the Arbiter
        [7105] = true, -- Third Eye of the Jailer
        [6954] = true, -- Phearomones
        [6948] = true, -- Grip of the Everlasting
        [7159] = true, -- Maw Rattle
    },
    DEMONHUNTER = { -- 12
        [7102] = true, -- Norgannon's Sagacity
        [7044] = true, -- Darkest Hour
        [7048] = true, -- Fiery Soul
        [7052] = true, -- Burning Wound
        [7041] = true, -- Collective Anguish
        [7045] = true, -- Spirit of the Darkness Flame
        [7049] = true, -- Darker Nature
        [7100] = true, -- Echo of Eonar
        [7104] = true, -- Stable Phantasma Lure
        [7046] = true, -- Razelikh's Defilement
        [7050] = true, -- Chaos Theory
        [7042] = true, -- Fel Bombardment
        [7043] = true, -- Darkglare Medallion
        [7103] = true, -- Sephuz's Proclamation
        [7159] = true, -- Maw Rattle
        [7101] = true, -- Judgment of the Arbiter
        [7105] = true, -- Third Eye of the Jailer
        [7047] = true, -- Fel Flame Fortification
        [7051] = true, -- Erratic Fel Core
        [7106] = true, -- Vitality Sacrifice
    },
    DRUID       = { -- 11
        [7086] = true, -- Draught of Deep Focus
        [7090] = true, -- Eye of Fearful Symmetry
        [7094] = true, -- Ursoc's Fury Remembered
        [7098] = true, -- Verdant Infusion
        [7102] = true, -- Norgannon's Sagacity
        [7106] = true, -- Vitality Sacrifice
        [7110] = true, -- Lycara's Fleeting Glimpse
        [7087] = true, -- Oneth's Clear Vision
        [7091] = true, -- Apex Predator's Craving
        [7095] = true, -- Legacy of the Sleeper
        [7099] = true, -- Vision of Unending Growth
        [7103] = true, -- Sephuz's Proclamation
        [7107] = true, -- Balance of All Things
        [7084] = true, -- Oath of the Elder Druid
        [7088] = true, -- Primordial Arcanic Pulsar
        [7092] = true, -- Luffa-Infused Embrace
        [7096] = true, -- Memory of the Mother Tree
        [7100] = true, -- Echo of Eonar
        [7104] = true, -- Stable Phantasma Lure
        [7108] = true, -- Timeworn Dreambinder
        [7085] = true, -- Circle of Life and Death
        [7089] = true, -- Cat-eye Curio
        [7093] = true, -- The Natural Order's Will
        [7159] = true, -- Maw Rattle
        [7101] = true, -- Judgment of the Arbiter
        [7105] = true, -- Third Eye of the Jailer
        [7109] = true, -- Frenzyband
        [7097] = true, -- The Dark Titan's Lesson
    },
    EVOKER = {}
}

local function GetItemSplit(itemLink)
    local itemString = string.match(itemLink, 'item:([%-?%d:]+)')
    local itemSplit = {}

    -- Split data into a table
    for _, v in ipairs({ strsplit(':', itemString) }) do
        if v == '' then
            itemSplit[#itemSplit + 1] = 0
        else
            itemSplit[#itemSplit + 1] = tonumber(v)
        end
    end

    return itemSplit
end

local OFFSET_BONUS_ID = 13
function MaxDps:ExtractBonusIds(itemLink)
    local itemSplit = GetItemSplit(itemLink)
    local bonuses = {}

    for i = 1, itemSplit[OFFSET_BONUS_ID] do
        bonuses[itemSplit[OFFSET_BONUS_ID + i]] = true
    end

    return bonuses
end

function MaxDps:GetLegendaryEffects()
    local legendaryBonusIds = {}
    local playerClass = select(2, UnitClass('player'))

    for i = 1, 19 do
        local link = GetInventoryItemLink('player', i)

        if link then
            local itemBonusIds = self:ExtractBonusIds(link)

            for bonusId, _ in pairs(generalLegendaries) do
                if itemBonusIds[bonusId] then
                    legendaryBonusIds[bonusId] = true
                end
            end

            for bonusId, _ in pairs(allLegendaryBonusIds[playerClass]) do
                if itemBonusIds[bonusId] then
                    legendaryBonusIds[bonusId] = true
                end
            end
        end
    end

    self.LegendaryBonusIds = legendaryBonusIds

    return legendaryBonusIds
end

local Consumables = {
    --BFA
    [169299] = true, -- Potion of Unbridled Fury
    [168529] = true, -- Potion of Empowered Proximity
    [168506] = true, -- Potion of Focused Resolve
    [168489] = true, -- Superior Battle Potion of Agility
    [168498] = true, -- Superior Battle Potion of Intellect
    [168500] = true, -- Superior Battle Potion of Strength
    [163223] = true, -- Battle Potion of Agility
    [163222] = true, -- Battle Potion of Intellect
    [163224] = true, -- Battle Potion of Strength
    [152559] = true, -- Potion of Rising Death
    [152560] = true, -- Potion of Bursting Blood
    --DF
    [191383] = true, -- Elemental Potion of Ultimate Power
    [191389] = true, -- Elemental Potion of Power
    [191401] = true, -- Potion of Shocking Disclosure
    --TWW
    [212259] = true, -- Potion of Unwavering Focus
    [212265] = true, -- Tempered Potion
    [431419] = true, --Cavedweller's Delight
    [431416] = true, --Healing Potion algari
    [431914] = true, --Potion of Unwavering Focus
    [431932] = true, --Tempered Potion
    [453205] = true, --Potion Bomb of Power
    [453162] = true, --Potion Bomb of Recovery
    [453283] = true, --Potion Bomb of Speed
    [431925] = true, --Frontline Potion
    [431941] = true, --Potion of the Reborn Cheetah
    [431418] = true, --Algari Mana Potion
    [431422] = true, --Slumbering Soul Serum
    [431432] = true, --Draught of Shocking Revelations
    [431424] = true, --Draught of Silent Footfalls / Treading Lightly
    [460074] = true, --Grotesque Vial
}

function MaxDps:GlowConsumables()
    if self.db.global.disableConsumables then
        return
    end

    for itemId in pairs(Consumables) do
        local itemSpellId = self.ItemSpells[itemId]

        if itemSpellId then
            self:GlowCooldown(itemSpellId, self:ItemCooldown(itemId, 0).ready)
        end
    end
end

function MaxDps:GlowEssences()
    local fd = MaxDps.FrameData
    if not fd.essences.major then
        return
    end

    MaxDps:GlowCooldown(fd.essences.major, fd.cooldown[fd.essences.major].ready)
end

function MaxDps:DumpAzeriteTraits()
    for id, rank in pairs(self.AzeriteTraits) do
        local n
        if MaxDps:IsRetailWow() then
            local spellInfo = GetSpellInfo(id)
            n = spellInfo and spellInfo.name
        else
            n = GetSpellInfo(id)
        end
        print(n .. ' (' .. id .. '): ' .. rank)
    end
end

-----------------------------------------------------------------
--- Aura helper functions
-----------------------------------------------------------------

-- Aura on specific unit
-- @deprecated
function MaxDps:UnitAura(auraId, timeShift, unit, filter)
    timeShift = timeShift or 0
    local aura = self:IntUnitAura(unit, auraId, filter, timeShift)

    return aura.up, aura.count, aura.remains
end

-- Aura on player
function MaxDps:Aura(name, timeShift)
    return self:UnitAura(name, timeShift, 'player')
end


-- Aura on target
function MaxDps:TargetAura(name, timeShift)
    return self:UnitAura(name, timeShift, 'target')
end

-- TODO
function MaxDps:HasDispellableAura()
    return false
end

-----------------------------------------------------------------
--- Casting info helpers
-----------------------------------------------------------------

function MaxDps:EndCast(target)
    target = target or 'player'
    local t = GetTime()
    local c = t * 1000
    local gcd = 0
    local _, _, _, _, endTime, _, _, _, spellId = UnitCastingInfo(target or 'player')
    if not spellId then
        _, _, _, _, endTime, _, _, spellId = UnitChannelInfo(target or 'player')
    end

    -- we can only check player global cooldown
    if target == 'player' then
        local gstart, gduration
        if C_Spell and C_Spell.GetSpellCooldown then
            local spellCooldownInfo = _GlobalCooldown and C_Spell.GetSpellCooldown(_GlobalCooldown)
            gstart = spellCooldownInfo and spellCooldownInfo.startTime
            gduration = spellCooldownInfo and spellCooldownInfo.duration
        else
            gstart, gduration = GetSpellCooldown(_GlobalCooldown)
        end
        gcd = gduration - (t - gstart)

        if gcd < 0 then
            gcd = 0
        end
    end

    if not endTime then
        return gcd, nil, gcd
    end

    local timeShift = (endTime - c) / 1000
    if gcd > timeShift then
        timeShift = gcd
    end

    return timeShift, spellId, gcd
end

function MaxDps:GlobalCooldown(spellId)
    local baseGCD = 1.5
    if spellId then
        baseGCD = select(2, GetSpellBaseCooldown(spellId)) / 1000
    end
    local haste = UnitSpellHaste('player')
    local gcd = baseGCD / ((haste / 100) + 1)

    if gcd < 0.75 then
        gcd = 0.75
    end

    return gcd
end

function MaxDps:AttackHaste()
    local haste = UnitSpellHaste('player')
    return 1 / ((haste / 100) + 1)
end

-----------------------------------------------------------------
--- Spell helpers
-----------------------------------------------------------------

function MaxDps:ItemCooldown(itemId, timeShift)
    local start, duration, enabled = GetItemCooldown(itemId)

    local t = GetTime()
    local remains = 100000

    if enabled and duration == 0 and start == 0 then
        remains = 0
    elseif enabled then
        remains = duration - (t - start) - timeShift
    end

    return {
        duration        = (duration and duration / 1000) or 0,
        ready           = remains <= 0,
        remains         = remains,
        fullRecharge    = remains,
        partialRecharge = remains,
        charges         = 1,
        maxCharges      = 1
    }
end

function MaxDps:CooldownConsolidated(spellId, timeShift)
    -- timeShift = timeShift or 0
    -- local remains = 100000
    for itemID,itemSpellID in pairs(MaxDps.ItemSpells) do
        if spellId == itemSpellID then
            return MaxDps:ItemCooldown(itemID, 0)
        end
    end
    local t = GetTime()

    local chargeInfo, charges, maxCharges, start, duration, enabled, fullRecharge, partialRecharge, spellCooldownInfo, remains
    local GCDspellCooldownInfo, GCDstart, GCDduration, GCDenabled
    if C_Spell and C_Spell.GetSpellCharges then
        chargeInfo  = spellId and C_Spell.GetSpellCharges(spellId)
        charges = chargeInfo and chargeInfo.currentCharges
        maxCharges = chargeInfo and chargeInfo.maxCharges
        start = chargeInfo and chargeInfo.cooldownStartTime
        duration = chargeInfo and chargeInfo.cooldownDuration
    else
        charges, maxCharges, start, duration = GetSpellCharges(spellId)
    end
    if C_Spell and C_Spell.GetSpellCooldown then
        GCDspellCooldownInfo = C_Spell.GetSpellCooldown(61304)
        GCDstart = GCDspellCooldownInfo and GCDspellCooldownInfo.startTime
        GCDduration = GCDspellCooldownInfo and GCDspellCooldownInfo.duration
        GCDenabled = GCDspellCooldownInfo and GCDspellCooldownInfo.isEnabled
    else
        GCDstart, GCDduration, GCDenabled = GetSpellCooldown(61304)
    end

    if not chargeInfo then
        if C_Spell and C_Spell.GetSpellCooldown then
            spellCooldownInfo = spellId and C_Spell.GetSpellCooldown(spellId)
            start = spellCooldownInfo and spellCooldownInfo.startTime
            duration = spellCooldownInfo and spellCooldownInfo.duration
            enabled = spellCooldownInfo and spellCooldownInfo.isEnabled
        else
            start, duration, enabled = GetSpellCooldown(spellId)
        end

        if not start then
            remains = 100000 --luacheck: ignore
            start = GetTime()
            duration = 10000
        end

        if start > 0 then
            remains = duration - (GetTime() - start)
        else
            remains = start
        end
        if (GCDduration and GCDduration > 0) then
            if remains <= GCDduration then -- + (MaxDpsOptions and MaxDpsOptions.global and  MaxDpsOptions.global.interval or 0.2) then
                remains = 0
            end
        end
        if (remains <= 0.5) then
            remains = 0
        end

        fullRecharge = remains
        partialRecharge = remains
    else
        if start > 0 then
            remains = duration - (GetTime() - start)
        else
            remains = start
        end
        if (GCDduration and GCDduration > 0) then
            if remains <= GCDduration then -- + (MaxDpsOptions and MaxDpsOptions.global and  MaxDpsOptions.global.interval or 0.2) then
                remains = 0
            end
        end
        if (remains <= 0.5) then
            remains = 0
        end

        if charges >= maxCharges then
            remains = 0
            fullRecharge = remains
            partialRecharge = remains
        else
            fullRecharge = (maxCharges - charges > 1 and (duration * (maxCharges - charges - 1)) + remains) or remains
            partialRecharge = remains
            if partialRecharge < 0 then
                partialRecharge = 0
            end
        end

        if charges >= 1 then
            remains = 0
        end
    end

    return {
        duration        = (duration and duration / 1000) or 0,
        ready           = remains <= 0,
        remains         = remains,
        fullRecharge    = fullRecharge,
        partialRecharge = partialRecharge,
        charges         = charges or 1,
        maxCharges      = maxCharges or 1
    }
end

-- @deprecated
function MaxDps:Cooldown(spell, timeShift)
    local start, duration, enabled
    if C_Spell and C_Spell.GetSpellCooldown then
        local spellCooldownInfo = spell and C_Spell.GetSpellCooldown(spell)
        start = spellCooldownInfo and spellCooldownInfo.startTime
        duration = spellCooldownInfo and spellCooldownInfo.duration
        enabled = spellCooldownInfo and spellCooldownInfo.isEnabled
    else
        start, duration, enabled = GetSpellCooldown(spell)
    end
    if enabled and duration == 0 and start == 0 then
        return 0
    elseif enabled then
        return (duration - (GetTime() - start) - (timeShift or 0))
    else
        return 100000
    end
end

-- @deprecated
function MaxDps:SpellCharges(spell, timeShift)
    local currentCharges, maxCharges, cooldownStart, cooldownDuration
    if C_Spell and C_Spell.GetSpellCharges then
        local chargeInfo  = spell and C_Spell.GetSpellCharges(spell)
        currentCharges = chargeInfo and chargeInfo.currentCharges
        maxCharges = chargeInfo and chargeInfo.maxCharges
        cooldownStart = chargeInfo and chargeInfo.cooldownStartTime
        cooldownDuration = chargeInfo and chargeInfo.cooldownDuration
    else
        currentCharges, maxCharges, cooldownStart, cooldownDuration = GetSpellCharges(spell)
    end

    if currentCharges == nil then
        local cd = MaxDps:Cooldown(spell, timeShift)
        if cd <= 0 then
            return 0, 1, 0
        else
            return cd, 0, 1
        end
    end

    local cd = cooldownDuration - (GetTime() - cooldownStart) - (timeShift or 0)
    if cd > cooldownDuration then
        cd = 0
    end

    if cd > 0 then
        currentCharges = currentCharges + (1 - (cd / cooldownDuration))
    end

    return cd, currentCharges, maxCharges
end

-- @deprecated
function MaxDps:SpellAvailable(spell, timeShift)
    local cd = MaxDps:Cooldown(spell, timeShift)
    return cd <= 0, cd
end

-----------------------------------------------------------------
--- Utility functions
-----------------------------------------------------------------

function MaxDps:TargetPercentHealth(unit)
    local health = UnitHealth(unit or 'target')
    if health <= 0 then
        return 0
    end

    local healthMax = UnitHealthMax(unit or 'target')
    if healthMax <= 0 then
        return 0
    end

    return health / healthMax
end

function MaxDps:SetBonus(items)
    local c = 0
    for _, item in ipairs(items) do
        if IsEquippedItem(item) then
            c = c + 1
        end
    end
    return c
end

function MaxDps:Mana(minus, timeShift)
    local _, casting = GetManaRegen()
    local mana = UnitPower('player', 0) - minus + (casting * timeShift)
    return mana / UnitPowerMax('player', 0), mana
end

function MaxDps:ExtractTooltip(spell, pattern)
    local _pattern = gsub(pattern, "%%s", "([%%d%.,]+)")

    if not MaxDpsSpellTooltip then
        CreateFrame('GameTooltip', 'MaxDpsSpellTooltip', UIParent, 'GameTooltipTemplate')
        MaxDpsSpellTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    MaxDpsSpellTooltip:SetSpellByID(spell)

    for i = 2, 4 do
        local line = _G['MaxDpsSpellTooltipTextLeft' .. i]
        local text = line:GetText()

        if text then
            local cost = strmatch(text, _pattern)
            if cost then
                cost = cost and tonumber((gsub(cost, "%D", "")))
                return cost
            end
        end
    end

    return 0
end

function MaxDps:Bloodlust(timeShift)
    -- @TODO: detect exhausted/seated debuff instead of 6 auras
    for k, v in pairs(_Bloodlusts) do
        if MaxDps:Aura(v, timeShift or 0) then
            return true
        end
    end

    return false
end

function MaxDps:FindSpellInSpellbook(spellId)
    if not MaxDps.Spellbook then
        MaxDps.Spellbook = {}
    end
    local spellName
    if MaxDps:IsRetailWow() then
        local spellInfo = GetSpellInfo(spellId)
        spellName = spellInfo.name
    else
        spellName = GetSpellInfo(spellId)
    end
    if MaxDps.Spellbook[spellName] then
        return MaxDps.Spellbook[spellName]
    end

    local bookType = Enum.SpellBookSpellBank.Player
    local spellSlot = FindSpellBookSlotBySpellID(spellId)

    if not spellSlot then
        bookType = Enum.SpellBookSpellBank.Pet
        spellSlot = FindSpellBookSlotBySpellID(spellId, true)
    end

    if spellSlot then
        local spellBookItemName = GetSpellBookItemName(spellSlot, bookType)
        local SBII = GetSpellBookItemInfo(spellSlot, bookType)
        local spellBookSpellId = SBII and SBII.spellID

        if spellBookItemName and spellBookItemName == spellName and spellBookSpellId and spellBookSpellId == spellId then
            MaxDps.Spellbook[spellName] = spellSlot
            return spellSlot
        end
    end

    return nil
end

function MaxDps:IsSpellInRange(spell, unit)
    unit = unit or 'target'

    local inRange = IsSpellInRange(spell, unit)

    if inRange == nil then
        local bookType = 'spell'
        local myIndex = MaxDps:FindSpellInSpellbook(spell)
        if myIndex then
            return IsSpellInRange(myIndex, bookType, unit)
        end
        return inRange
    end

    return inRange
end

function MaxDps:TargetsInRange(spell)
    local count = 0

    for _, unit in ipairs(self.visibleNameplates) do
        if MaxDps:IsSpellInRange(spell, unit) == 1 then
            count = count + 1
        end
    end

    return count
end

function MaxDps:ThreatCounter()
    local count = 0
    local units = {}

    for _, unit in ipairs(self.visibleNameplates) do
        if UnitThreatSituation('player', unit) ~= nil then
            count = count + 1
            TableInsert(units, unit)
        else
            local npcId = Select(6, StringSplit('-', UnitGUID(unit)))
            npcId = tonumber(npcId)
            -- Risen Soul, Tormented Soul, Lost Soul
            if npcId == 148716 or npcId == 148893 or npcId == 148894 then
                count = count + 1
                TableInsert(units, unit)
            end
        end
    end

    return count, units
end

function MaxDps:DebuffCounter(spellId, timeShift)
    local count, totalRemains, totalCount, totalCountRemains = 0, 0, 0, 0

    for mobID, AuraID in pairs(self.ActiveDots) do
        for AuraIDTable,auraTable in pairs(AuraID) do
            if auraTable.spellId == spellId then
                count = count + 1
                totalCount = totalCount + auraTable.count
                totalRemains = totalRemains + auraTable.remains
                totalCountRemains = totalRemains + (auraTable.remains * auraTable.count)
            end
        end
    end

    return count, totalRemains, totalCount, totalCountRemains
end

local combatTimer
MaxDps.combatTime = 0
local function TrackTimeInCombat(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if combatTimer and not combatTimer:IsCancelled() then
            combatTimer:Cancel()
        end
        if not combatTimer or combatTimer:IsCancelled() then
            combatTimer = C_Timer.NewTicker(1,
            function()
                MaxDps.combatTime = MaxDps.combatTime + 1
            end
            )
        end
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if combatTimer and not combatTimer:IsCancelled() then
            combatTimer:Cancel()
        end
        MaxDps.combatTime = 0
    end
end

local combatTimeframe = CreateFrame("Frame")
combatTimeframe:SetScript("OnEvent", TrackTimeInCombat)
combatTimeframe:RegisterEvent("PLAYER_REGEN_DISABLED")
combatTimeframe:RegisterEvent("PLAYER_REGEN_ENABLED")

--For encounters with multiple targets
--but only 1 takes 100% dmg
--Eg. encounters where a target takes reduced dmg
--or other targets are immune
--track the encounter ID for use in SmartAoe
local encounterID = nil
local function UpdateEncounterID(self, event, EventencounterID, EventencounterName, EventdifficultyID, EventgroupSize)
    --print(event, EventencounterID, EventencounterName, EventdifficultyID, EventgroupSize)
    if event == "ENCOUNTER_START" then
        encounterID = EventencounterID
    end
    if event == "ENCOUNTER_END" then
        encounterID = nil
    end
end

local encounterIDframe = CreateFrame("Frame")
encounterIDframe:SetScript("OnEvent", UpdateEncounterID)
encounterIDframe:RegisterEvent("ENCOUNTER_START")
encounterIDframe:RegisterEvent("ENCOUNTER_END")

--format is encounter id = number of targets
--that are a part of that encounter
local singleTargetEncounters = {
    -- Ascendant Lord Obsidius - Blackrock Caverns
    [1036] = 4,
    -- WM Triad
    [2113] = 3
}

local LibRangeCheck = LibStub("LibRangeCheck-3.0")
function MaxDps:SmartAoe(itemId)
    if self.db.global.forceSingle then
        return 1
    end
    if self.db.global.forceTargetAmount then
        return self.db.global.forceTargetAmountCount
    end

    --local _, instanceType = IsInInstance()
    --local count, units
    local _, units = self:ThreatCounter()
    local originalCount

    --local itemToCheck = itemId or 18904

    -- 5 man content, we count battleground also as small party
    --if self.isMelee then
    --	-- 8 yards range
    --	itemToCheck = itemId or 61323
    --elseif instanceType == 'pvp' or instanceType == 'party' then
    --	-- 30 yards range
    --	itemToCheck = itemId or 7734
    --elseif instanceType == 'arena' and instanceType == 'raid' then
    --	-- 35 yards range
    --	itemToCheck = itemId or 18904
    --end

    local count = 0
    --if not IsInInstance() then
    --    for i = 1, #units do
    --    	-- 8 yards range check IsItemInRange blocked on retail in instance since 10.2
    --    	if IsItemInRange(itemToCheck, units[i]) then
    --    		count = count + 1
    --    	end
    --    end
    --end
    --if IsInInstance() then
    for i = 1, #units do
        if MaxDps.isMelee then
            local range = LibRangeCheck:GetRange(units[i], true)
            if range and range <= 15 then
                count = count + 1
            end
        else
            local range = LibRangeCheck:GetRange(units[i], true)
            if range and range  <= 30 then
                count = count + 1
            end
        end
    end
    --end

    if WeakAuras then
        WeakAuras.ScanEvents('MAXDPS_TARGET_COUNT', count)
    end

    if encounterID and singleTargetEncounters and singleTargetEncounters[encounterID] then
        originalCount = count
        if count <= singleTargetEncounters[encounterID] then
            count = 1
        end
        if count >= singleTargetEncounters[encounterID] then
            count = count - singleTargetEncounters[encounterID] + 1
        end
        if count < 0 then
            count = originalCount
        end
    end

    if count == 0 and UnitExists("target") and UnitHealth("target") > 0 and UnitCanAttack("player","target") == true then
        count = 1
    end

    return count
end

function MaxDps:FormatTime(left)
    local seconds = left >= 0 and math.floor((left % 60) / 1) or 0
    local minutes = left >= 60 and math.floor((left % 3600) / 60) or 0
    local hours = left >= 3600 and math.floor((left % 86400) / 3600) or 0
    local days = left >= 86400 and math.floor((left % 31536000) / 86400) or 0
    local years = left >= 31536000 and math.floor(left / 31536000) or 0

    if years > 0 then
        return string.format("%d [Y] %d [D] %d:%d:%d [H]", years, days, hours, minutes, seconds)
    elseif days > 0 then
        return string.format("%d [D] %d:%d:%d [H]", days, hours, minutes, seconds)
    elseif hours > 0 then
        return string.format("%d:%d:%d [H]", hours, minutes, seconds)
    elseif minutes > 0 then
        return string.format("%d:%d [M]", minutes, seconds)
    else
        return string.format("%d [S]", seconds)
    end
end
--FindSpellOverrideByID
--FindBaseSpellByID

function MaxDps:FormatItemorSpell(str)
    if not str then return "" end
    if type(str) ~= "string" then return end
    return str:gsub("%s+", ""):gsub("%'", ""):gsub("%,", ""):gsub("%-", ""):gsub("%:", "")
end

local twwitems = {
    ["house_of_cards"] = 466681,
    ["tome_of_lights_devotion"] = 443535,
    ["bestinslots"] = 473402,
    ["treacherous_transmitter"] = 449954,
    ["mad_queens_mandate"] = 443124,
    ["skardyns_grace"] = 92099,
    ["signet_of_the_priory"] = 443531,
    ["junkmaestros_mega_magnet"] = 1219661,
    ["geargrinders_spare_keys"] = 471059,
    ["grim_codex"] = 345739,
    ["ravenous_honey_buzzer"] = 448904,
    ["spymasters_web"] = 444959,
    ["imperfect_ascendancy_serum"] = 455482,
    ["neural_synapse_enhancer"] = 300612,
    ["aberrant_spellforge"] = 445619,
    ["nymues_unraveling_spindle"] = 422956,
    ["flarendos_pilot_light"] = 471142,
    ["algethar_puzzle_box"] = 383781,
    ["ingenious_mana_battery"] = 300968,
    ["high_speakers_accretion"] = 443415,
    ["gladiators_badge"] = 277185,
    ["hyperthread_wristwraps"] = 300142,
    ["burst_of_knowledge"] = 469925,
    ["ratfang_toxin"] = 1216604,
    ["funhouse_lens"] = 1213432,
    ["elementium_pocket_anvil"] = 401306,
    ["beacon_to_the_beyond"] = 402583,
    ["manic_grieftorch"] = 377463,
    ["time_thiefs_gambit"] = 417534,
    ["mirror_of_fractured_tomorrows"] = 418527,
    ["unyielding_netherprism"] = 1233556,
    ["spellstrike_warplance"] = 1243411,
    ["cursed_stone_idol"] = 1242326,
    ['skarmorak_shard'] = 443407,
}

function MaxDps:FormatSim(itemname)
    if not itemname then return "" end
    itemname = itemname:lower():gsub("%s+", "_"):gsub("%'", ""):gsub("%,", ""):gsub("%-", ""):gsub("%:", ""):gsub('"', '')
    return itemname
end

MaxDps.equipedItems = {}
function MaxDps:TrackGearItems()
    wipe(MaxDps.equipedItems)
    for i=1,19 do
        local itemLink = GetInventoryItemLink("player", i)
        local itemID = GetInventoryItemID('player', i)
        local itemSpellID = (itemID and select(2,GetItemSpell(itemID)) ) or 0
        local itemName = itemLink and GetItemInfo(itemLink)
        if itemName and itemSpellID then
            if not twwitems[MaxDps:FormatSim(itemName)] then
                twwitems[MaxDps:FormatSim(itemName)] = itemSpellID
            end
        end
        if itemName and itemID then
            MaxDps.equipedItems[MaxDps:FormatSim(itemName)] = itemSpellID and itemSpellID > 0 and itemSpellID or itemID
        end
    end
end

function MaxDps:CheckSpellUsable(spell,spellstring)
    if spell == 0 then
        return false
    end
    if (not spell) and spellstring then
        MaxDps:Print(self.Colors.Error .. "Error No Spell Data For " .. spellstring, "error")
        return false
    end
    local isPassive = C_Spell.IsSpellPassive(spell)
    if isPassive then
        return false
    end
    if MaxDps:IsRetailWow() or MaxDps:IsMistsWow() then
        if UnitExists("pet") then
            for i = 1, NUM_PET_ACTION_SLOTS do
                local _, _, _, _, _, _, spellID = GetPetActionInfo(i)
                if spellID == spell and C_Spell.IsSpellUsable(spell) and MaxDps:CooldownConsolidated(spell).ready then
                    return true
                end
            end
        end
        if not IsSpellKnownOrOverridesKnown(spell) and
            spellstring ~= "trinket1" and
            spellstring ~= "trinket2" and
            not twwitems[spellstring] or
            (twwitems[spellstring] and not MaxDps.equipedItems[spellstring]) then
                return false
        end
        if not C_Spell.IsSpellUsable(spell) then return false end
        local ORID = FindSpellOverrideByID(spell)
        -- Check that the Override ID is active
        if ORID and ORID ~= spell and MaxDps.Spells[ORID] then
            --local spellCooldownInfo = C_Spell.GetSpellCooldown(ORID)
            ---- If the spell is currently over written and its on cooldown return false
            --if spellCooldownInfo and spellCooldownInfo.duration > 0 then
            --    return false
            --end
            local spellCooldownInfo = MaxDps:CooldownConsolidated(ORID)
            if spellCooldownInfo and spellCooldownInfo.remains > 0 then
                return false
            end
            local isPassiveORID = C_Spell.IsSpellPassive(ORID)
            if isPassiveORID then
                return false
            end
        end
        local costs = C_Spell.GetSpellPowerCost(spell)
        if type(costs) ~= 'table' and spellstring then return true end
        for i,costtable in pairs(costs) do
            if UnitPower('player', costtable.type) < costtable.cost then
                if GetPowerRegenForPowerType(costtable.type) > 0 then
                    if UnitPower('player', costtable.type) + GetPowerRegenForPowerType(costtable.type) < costtable.cost then
                        return false
                    end
                else
                    return false
                end
                --return false
            end
        end
    end

    if MaxDps:IsCataWow() then
        for i = 1, NUM_PET_ACTION_SLOTS do
            local _, _, _, _, _, _, spellID = GetPetActionInfo(i)
            if spellID == spell and C_Spell.IsSpellUsable(spell) and MaxDps:CooldownConsolidated(spell).ready then
                return true
            end
        end

        if not IsSpellKnownOrOverridesKnown(spell) then return false end
        if not C_Spell.IsSpellUsable(spell) then return false end
        local costs = C_Spell.GetSpellPowerCost(spell)
        if type(costs) ~= 'table' and spellstring then return true end
        for i,costtable in pairs(costs) do
            if UnitPower('player', costtable.type) < costtable.cost then
                if GetPowerRegenForPowerType(costtable.type) > 0 then
                    if UnitPower('player', costtable.type) + GetPowerRegenForPowerType(costtable.type) < costtable.cost then
                        return false
                    end
                else
                    return false
                end
                --return false
            end
        end
    end

    local spellFound = false
    if MaxDps:IsClassicWow() then
        -- Loop through all the spells in the player's spellbook
        local lspellName = C_Spell.GetSpellName(spell)
        for i = 1, GetNumSpellTabs() do
            local name, _, offset, numSpells = GetSpellTabInfo(i)
            -- Loop through each spell in the tab
            for j = offset + 1, offset + numSpells do
                local spellType, spellID = GetSpellBookItemInfo(j,"player")
                local spellData = C_Spell.GetSpellInfo(spellID)
                local spellName = spellData and spellData.name
                -- Check if the spell ID matches the one you're looking for
                if lspellName == spellName then
                    spellFound = true
                    break
                end
            end
        end
        if not spellFound then return false end
    end

    return true
end

function MaxDps:GetSpellCost(spell,power)
    local costs = C_Spell.GetSpellPowerCost(spell)
    if type(costs) ~= 'table' then return 0 end
    for i,costtable in pairs(costs) do
        if costtable.name == power then
            return costtable.cost
        end
    end
    return 0
end

function MaxDps:CheckEquipped(checkName)
    for i=1,14 do
        local itemID = GetInventoryItemID('player', i)
        local itemName = itemID and C_Item.GetItemInfo(itemID) or ''
        if MaxDps:FormatItemorSpell(checkName) == MaxDps:FormatItemorSpell(itemName) then
            return true
        end
    end
    return false
end

function MaxDps:CheckTrinketNames(checkName)
    for i=13,14 do
        local itemID = GetInventoryItemID('player', i)
        if not itemID then return false end
        local itemName = C_Item.GetItemInfo(itemID)
        if MaxDps:FormatItemorSpell(checkName) == MaxDps:FormatItemorSpell(itemName) then
            return true
        end
    end
    return false
end

function MaxDps:CheckTrinketCooldown(slot)
    if slot == 1 then
        slot = 13
    end
    if slot == 2 then
        slot = 14
    end
    if slot == 13 or slot == 14 then
        local itemID = GetInventoryItemID('player', slot)
        local _, duration, _ = C_Item.GetItemCooldown(itemID)
        return duration
    else
        local tOneitemID = GetInventoryItemID('player', 13)
        local tTwoitemID = GetInventoryItemID('player', 14)
        local tOneitemName = C_Item.GetItemInfo(tOneitemID)
        local tTwoitemName = C_Item.GetItemInfo(tTwoitemID)
        if tOneitemName == slot then
            local _, duration, _ = C_Item.GetItemCooldown(tOneitemID)
            return duration
        end
        if tTwoitemName == slot then
            local _, duration, _ = C_Item.GetItemCooldown(tTwoitemID)
            return duration
        end
    end
    return math.huge
end

function MaxDps:CheckTrinketCooldownDuration(slot)
    if slot == 1 then
        slot = 13
    end
    if slot == 2 then
        slot = 14
    end
    local itemID = GetInventoryItemID('player', slot)
    local itemSpellID = (itemID and select(2,GetItemSpell(itemID)) ) or 0
    local spellCooldownInfo = C_Spell.GetSpellCooldown(itemSpellID)
    local duration = spellCooldownInfo and C_Spell.GetSpellCooldown(itemSpellID).duration or math.huge
    return duration
end

function MaxDps:CheckTrinketReady(slot)
    if slot == 1 then
        slot = 13
    end
    if slot == 2 then
        slot = 14
    end
    if slot == 13 or slot == 14 then
        local itemID = GetInventoryItemID('player', slot)
        local _, duration, _ = C_Item.GetItemCooldown(itemID)
        if duration == 0 then return true else return false end
    else
        local tOneitemID = GetInventoryItemID('player', 13)
        local tTwoitemID = GetInventoryItemID('player', 14)
        local tOneitemName = C_Item.GetItemInfo(tOneitemID)
        local tTwoitemName = C_Item.GetItemInfo(tTwoitemID)
        if tOneitemName == slot then
            local _, duration, _ = C_Item.GetItemCooldown(tOneitemID)
            if duration == 0 then return true else return false end
        end
        if tTwoitemName == slot then
            local _, duration, _ = C_Item.GetItemCooldown(tTwoitemID)
            if duration == 0 then return true else return false end
        end
    end
    return false
end

function MaxDps:CheckTrinketItemLevel(slot)
    local itemLevel = 0
    if slot == 1 then
        slot = 13
    end
    if slot == 2 then
        slot = 14
    end
    if slot == 13 or slot == 14 then
        local itemID = GetInventoryItemID('player', slot)
        itemLevel = C_Item.GetDetailedItemLevelInfo(itemID)
    end
    return itemLevel
end

function MaxDps:CheckTrinketCastTime(slot)
    if slot == 1 then
        slot = 13
    end
    if slot == 2 then
        slot = 14
    end
    local itemID = GetInventoryItemID('player', slot)
    local itemSpellID = (itemID and select(2,GetItemSpell(itemID)) ) or 0
    local spellCooldownInfo = C_Spell.GetSpellInfo(itemSpellID)
    local castTime = spellCooldownInfo and spellCooldownInfo.castTime or 0
    return castTime
end

function MaxDps:HasOnUseEffect(itemSlot)
    -- Get the item ID of the trinket in the given slot
    local itemID = GetInventoryItemID("player", itemSlot)
    -- If the trinket slot is empty (no item in the slot), return false
    if not itemID then
        return false
    end
    -- Check if the item has an on-use effect (if it's usable)
    if C_Item.IsUsableItem(itemID) then
        return true
    else
        return false
    end
end

local TrinketBuffCache = {}
function MaxDps:HasBuffEffect(slotId, searchWord)
    TrinketBuffCache = TrinketBuffCache or {}
    if type(slotId) ~= "string" then return false end
    if type(searchWord) ~= "string" then return false end
    local key = searchWord and searchWord:lower() or nil
    if not key then
        return false
    end

    if TrinketBuffCache[slotId] and TrinketBuffCache[slotId][searchWord] then
        return TrinketBuffCache[slotId][key]
    end
    if not MaxDpsTrinketBuffToolTip then --luacheck: ignore 113
        local tooltip = CreateFrame("GameTooltip", "MaxDpsTrinketBuffToolTip", nil, "GameTooltipTemplate")
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    -- Clear previous lines
    MaxDpsTrinketBuffToolTip:ClearLines() --luacheck: ignore 113
    MaxDpsTrinketBuffToolTip:SetInventoryItem("player", slotId) --luacheck: ignore 113

    if searchWord:lower() == "any" then
        for i = 1, MaxDpsTrinketBuffToolTip:NumLines() do --luacheck: ignore 113
            local line = _G["MaxDpsTrinketBuffToolTipTextLeft" .. i]
            if line and line:GetText() then
                line = line:GetText()
                line = line:match("^Equip:%s*(.+)") or line:match("^Use:%s*(.+)")
            end
            if line then
                if line and ( line:lower():find("agility")
                or line:lower():find("crit")
                or line:lower():find("haste")
                or line:lower():find("intellect")
                or line:lower():find("mastery")
                or line:lower():find("strength")
                or line:lower():find("versatility") ) then
                    TrinketBuffCache[slotId] = TrinketBuffCache[slotId] or {}
                    TrinketBuffCache[slotId][key] = true
                    break
                end
            end
        end
    end

    for i = 1, MaxDpsTrinketBuffToolTip:NumLines() do --luacheck: ignore 113
        local line = _G["MaxDpsTrinketBuffToolTipTextLeft" .. i]
        if line and line:GetText() then
            line = line:GetText()
            line = line:match("^Equip:%s*(.+)") or line:match("^Use:%s*(.+)")
        end
        if line then
            if line and line:lower():find(searchWord:lower()) then
                TrinketBuffCache[slotId] = TrinketBuffCache[slotId] or {}
                TrinketBuffCache[slotId][key] = true
                break
            end
        end
    end
    if not TrinketBuffCache and not TrinketBuffCache[slotId] and not TrinketBuffCache[slotId][key] then
        TrinketBuffCache[slotId] = TrinketDurationCache[slotId] or {}
        TrinketBuffCache[slotId][key] = false
    end
    MaxDpsTrinketBuffToolTip:Hide() --luacheck: ignore 113
    return (TrinketBuffCache and TrinketBuffCache[slotId] and TrinketBuffCache[slotId][key]) or false
end

local TrinketDurationCache = {}
function MaxDps:CheckTrinketBuffDuration(slotId, searchWord)
    TrinketDurationCache = TrinketDurationCache or {}
    if type(slotId) ~= "string" then return 0 end
    if type(searchWord) ~= "string" then return 0 end
    local key = searchWord and searchWord:lower() or nil
    if not key then
        return 0
    end

    local linebuff
    local lineduration
    if TrinketDurationCache[slotId] and TrinketDurationCache[slotId][searchWord] then
        return TrinketDurationCache[slotId][key]
    end
    if not MaxDpsTrinketDurationToolTip then --luacheck: ignore 113
        local tooltip = CreateFrame("GameTooltip", "MaxDpsTrinketDurationToolTip", nil, "GameTooltipTemplate")
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    -- Clear previous lines
    MaxDpsTrinketDurationToolTip:ClearLines() --luacheck: ignore 113
    MaxDpsTrinketDurationToolTip:SetInventoryItem("player", slotId) --luacheck: ignore 113

    if searchWord:lower() == "any" then
        for i = 1, MaxDpsTrinketDurationToolTip:NumLines() do --luacheck: ignore 113
            local line = _G["MaxDpsTrinketDurationToolTipTextLeft" .. i]
            if line and line:GetText() then
                line = line:GetText()
                lineduration = tonumber(line:match("for%s+(%d+)"))
                linebuff = line:match("^Equip:%s*(.+)") or line:match("^Use:%s*(.+)")
            end
            if lineduration then
                if linebuff and ( linebuff:lower():find("agility")
                or linebuff:lower():find("crit")
                or linebuff:lower():find("haste")
                or linebuff:lower():find("intellect")
                or linebuff:lower():find("mastery")
                or linebuff:lower():find("strength")
                or linebuff:lower():find("versatility") ) then
                    TrinketDurationCache[slotId] = TrinketDurationCache[slotId] or {}
                    TrinketDurationCache[slotId][key] = lineduration
                    break
                end
            end
        end
    end

    for i = 1, MaxDpsTrinketDurationToolTip:NumLines() do --luacheck: ignore 113
        local line = _G["MaxDpsTrinketDurationToolTipTextLeft" .. i]
        if line and line:GetText() then
            line = line:GetText()
            lineduration = tonumber(line:match("for%s+(%d+)"))
            linebuff = line:match("^Equip:%s*(.+)") or line:match("^Use:%s*(.+)")
        end
        if lineduration then
            if linebuff and linebuff:lower():find(searchWord:lower()) then
                TrinketDurationCache[slotId] = TrinketDurationCache[slotId] or {}
                TrinketDurationCache[slotId][key] = lineduration
                break
            end
        end
    end
    if not TrinketBuffCache and not TrinketBuffCache[slotId] and not TrinketBuffCache[slotId][key] then
        TrinketDurationCache[slotId] = TrinketDurationCache[slotId] or {}
        TrinketDurationCache[slotId][key] = 0
    end
    MaxDpsTrinketDurationToolTip:Hide() --luacheck: ignore 113
    return tonumber(TrinketDurationCache and TrinketDurationCache[slotId] and TrinketDurationCache[slotId][key]) or 0
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("LOADING_SCREEN_DISABLED")

f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        if TrinketBuffCache then
            wipe(TrinketBuffCache) --luacheck: ignore 113 -- Clear the cache when equipment changes
        end
        if TrinketDurationCache then
            wipe(TrinketDurationCache) --luacheck: ignore 113 -- Clear the cache when equipment changes
        end
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "LOADING_SCREEN_DISABLED" then
        MaxDps:TrackGearItems() -- Track gear items when equipment changes
    end
end)


function MaxDps:CheckPrevSpell(spell,number)
    if MaxDps and MaxDps.spellHistory and not number then
        if MaxDps.spellHistory[1] then
            if MaxDps.spellHistory[1] == spell then
                return true
            end
            if MaxDps.spellHistory[1] ~= spell then
                return false
            end
        end
    end
    if MaxDps and MaxDps.spellHistory and number then
        if MaxDps.spellHistory[number] then
            if MaxDps.spellHistory[number] == spell then
                return true
            end
            if MaxDps.spellHistory[number] ~= spell then
                return false
            end
        end
    end
    return true
end

function MaxDps:boss()
    if UnitExists('boss1')
    or UnitExists('boss2')
    or UnitExists('boss3')
    or UnitExists('boss4')
    or UnitExists('boss5')
    or UnitExists('boss6')
    or UnitExists('boss7')
    or UnitExists('boss8')
    or UnitExists('boss9')
    or UnitExists('boss10') then
        return true
    end
    return false
end

function MaxDps:GetPartyState()
    local _, instanceType, _, _, maxPlayers = GetInstanceInfo()
    if maxPlayers == 0 then
        maxPlayers = 1
    end
    if instanceType == "arena" then
        return "arena", maxPlayers or 5
    elseif instanceType == "pvp" or (instanceType == "none" and C_PvP.GetZonePVPInfo() == "combat") then
        return "bg", maxPlayers or 40
    elseif maxPlayers == 1 or not IsInGroup() then -- treat solo scenarios as solo, not party or raid
        return "solo", 1
    elseif IsInRaid() then
        if instanceType == "none" then
            -- GetInstanceInfo reports maxPlayers = 5 in Broken Isles
            maxPlayers = 40
        end
        return "raid", maxPlayers or 40
    else
        return "party", 5
    end
end

function MaxDps:NumGroupFriends()
    local groupType, maxPlayers = MaxDps:GetPartyState()
    local num = GetNumGroupMembers()
    -- In world BG zones such as wintergrasp
    -- GetNumGroupMembers when solo returns 0
    if num == 0 and groupType == "bg" then
        return 1
    end
    if num == 0 then
        num = 1
    end
    return num
end

function MaxDps:HasGlyphEnabled(spellID)
    if not spellID then return false end
    if not MaxDps:IsRetailWow() then
        for i = 1, GetNumGlyphSockets() do
            local enabled, glyphType, glyphTooltipIndex, glyphSpellID, icon, glyphID = GetGlyphSocketInfo(i)
            if ( enabled ) then
                local link = glyphID and GetGlyphLink(i, glyphID) or ""-- Retrieves the Glyph's link ("" if no glyph in Socket)
                if ( link ~= "") and spellID == glyphSpellID then
                    return true
                   --DEFAULT_CHAT_FRAME:AddMessage("Glyph Socket "..i.." contains "..link)
                --else
                --   DEFAULT_CHAT_FRAME:AddMessage("Glyph Socket "..i.." is unlocked and empty!")
                end
            --else
            --    DEFAULT_CHAT_FRAME:AddMessage("Glyph Socket "..i.." is locked!")
            end
        end
        return false
    end
    return false
end

local damageEvents = {}  -- Table to store damage events

-- Function to handle combat log events and set incoming damage to MaxDps.incoming_damage_5
local function incoming_damage_5()
    local timestamp = GetTime()  -- Current time in seconds
    local _, eventType, _, sourceGUID, _, _, _, destGUID, destName, _, _, damage = CombatLogGetCurrentEventInfo()
    local playerGUID = UnitGUID("player")
    if destGUID == playerGUID then
        -- Check if the event is related to damage taken
        if eventType == "SPELL_DAMAGE" or eventType == "RANGE_DAMAGE" or eventType == "SWING_DAMAGE" then
            -- Store the damage and the timestamp
            table.insert(damageEvents, {timestamp = timestamp, damage = damage})

            -- Remove events that are older than 5 seconds
            for i = #damageEvents, 1, -1 do
                if damageEvents[i].timestamp < timestamp - 5 then
                    table.remove(damageEvents, i)
                end
            end
        end

        -- Calculate total damage taken in the last 5 seconds
        local totalDamage = 0
        for _, event in ipairs(damageEvents) do
            if timestamp - event.timestamp <= 5 then
                totalDamage = totalDamage + event.damage
            end
        end

        -- Set the total damage taken in the last 5 seconds to MaxDps.incoming_damage_5
        MaxDps.incoming_damage_5 = totalDamage
    end
end

local function incoming_damage_3()
    local timestamp = GetTime()  -- Current time in seconds
    local _, eventType, _, sourceGUID, _, _, _, destGUID, destName, _, _, damage = CombatLogGetCurrentEventInfo()
    local playerGUID = UnitGUID("player")
    if destGUID == playerGUID then
        -- Check if the event is related to damage taken
        if eventType == "SPELL_DAMAGE" or eventType == "RANGE_DAMAGE" or eventType == "SWING_DAMAGE" then
            -- Store the damage and the timestamp
            table.insert(damageEvents, {timestamp = timestamp, damage = damage})
        end

        -- Calculate total damage taken in the last 3 seconds
        local totalDamage = 0
        for _, event in ipairs(damageEvents) do
            if timestamp - event.timestamp <= 3 then
                totalDamage = totalDamage + event.damage
            end
        end

        -- Set the total damage taken in the last 3 seconds to MaxDps.incoming_damage_5
        MaxDps.incoming_damage_3 = totalDamage
    end
end

-- Register the event listeners
local incomingDamageFrame = CreateFrame("Frame")
incomingDamageFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
incomingDamageFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Event for leaving combat
incomingDamageFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        incoming_damage_5(...)
        incoming_damage_3(...)
    elseif event == "PLAYER_REGEN_ENABLED" then
        damageEvents = {}
    end
end)

function MaxDps:FindADAuraData(spellID)
    local aura = {
        name           = nil,
        up             = false,
        upMath         = 0,
        count          = 0,
        expirationTime = 0,
        remains        = 0,
        duration       = 0,
        refreshable    = true, -- well if it doesn't exist, then it is refreshable
        maxStacks      = 0,
        value          = 0,
    }
    local lname = C_Spell.GetSpellName(spellID)
    if not lname then return end
    for guid,AuraIDTable in pairs(MaxDps.ActiveDots) do
        --print(guid,AuraIDTable)
        for iD, Data in pairs(AuraIDTable) do
            if lname == Data.name then
                local remains = 0
                if Data.expirationTime == nil then
                    remains = 0
                elseif (Data.expirationTime - GetTime()) > 1 then
                    remains = Data.expirationTime - GetTime() - 1
                elseif Data.expirationTime == 0 then
                    remains = 99999
                end
                aura.name = Data.name
                aura.up = true
                aura.upMath = 1
                aura.count = (Data.applications and Data.applications > 0 and Data.applications) or 1
                aura.expirationTime = (Data.expirationTime and Data.expirationTime > 0 and Data.expirationTime) or math.huge
                aura.remains = remains
                aura.duration = (Data.duration and Data.duration >0 and Data.duration) or math.huge
                aura.refreshable = remains < 0.3 * Data.duration
                aura.maxStacks = (Data.maxCharges and Data.maxCharges > 0 and Data.maxCharges) or 1
                aura.value = Data.points and Data.points[1] or 0
            end
        end
    end
    return aura
end

function MaxDps:FindBuffAuraData(spellID)
    local aura = {
        name           = nil,
        up             = false,
        upMath         = 0,
        count          = 0,
        expirationTime = 0,
        remains        = 0,
        duration       = 0,
        refreshable    = true, -- well if it doesn't exist, then it is refreshable
        maxStacks      = 0,
        value          = 0,
    }
    local lname = C_Spell.GetSpellName(spellID)
    if not lname then return end
    for _,Data in pairs(MaxDps.PlayerAuras) do
        if lname == Data.name then
            local remains = 0
            if Data.expirationTime == nil then
                remains = 0
            elseif (Data.expirationTime - GetTime()) > 1 then
                remains = Data.expirationTime - GetTime() - 1
            elseif Data.expirationTime == 0 then
                remains = 99999
            end
            aura.name = Data.name
            aura.up = true
            aura.upMath = 1
            aura.count = (Data.applications and Data.applications > 0 and Data.applications) or 1
            aura.expirationTime = (Data.expirationTime and Data.expirationTime > 0 and Data.expirationTime) or math.huge
            aura.remains = remains
            aura.duration = (Data.duration and Data.duration >0 and Data.duration) or math.huge
            aura.refreshable = remains < 0.3 * Data.duration
            aura.maxStacks = (Data.maxCharges and Data.maxCharges > 0 and Data.maxCharges) or 1
            aura.value = Data.points and Data.points[1] or 0
        end
    end
    return aura
end

function MaxDps:FindDeBuffAuraData(spellID)
    local aura = {
        name           = nil,
        up             = false,
        upMath         = 0,
        count          = 0,
        expirationTime = 0,
        remains        = 0,
        duration       = 0,
        refreshable    = true, -- well if it doesn't exist, then it is refreshable
        maxStacks      = 0,
        value          = 0,
    }
    local lname = C_Spell.GetSpellName(spellID)
    if not lname then return end
    for _,Data in pairs(MaxDps.TargetAuras) do
        if lname == Data.name then
            local remains = 0
            if Data.expirationTime == nil then
                remains = 0
            elseif (Data.expirationTime - GetTime()) > 1 then
                remains = Data.expirationTime - GetTime() - 1
            elseif Data.expirationTime == 0 then
                remains = 99999
            end
            aura.name = Data.name
            aura.up = true
            aura.upMath = 1
            aura.count = (Data.applications and Data.applications > 0 and Data.applications) or 1
            aura.expirationTime = (Data.expirationTime and Data.expirationTime > 0 and Data.expirationTime) or math.huge
            aura.remains = remains
            aura.duration = (Data.duration and Data.duration >0 and Data.duration) or math.huge
            aura.refreshable = remains < 0.3 * Data.duration
            aura.maxStacks = (Data.maxCharges and Data.maxCharges > 0 and Data.maxCharges) or 1
            aura.value = Data.points and Data.points[1] or 0
        end
    end
    return aura
end
