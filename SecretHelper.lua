local addonName, MaxDps = ...

local GetTime = GetTime
local ipairs = ipairs
local pcall = pcall
local C_Spell_GetOverrideSpell          = C_Spell and C_Spell.GetOverrideSpell

local overrideSpellCache = {}
local overrideCacheTime = -1


local spellBookCache = {}
local spellNameDuration = {}
local spellNameTrackedID = {}
MaxDps.DOTSName = {}

function MaxDps.CacheSpells()

    local skillLineIndex = 1

    while true do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)

        if not skillLineInfo then
            break
        end

        for slot = skillLineInfo.itemIndexOffset + 1,
                    skillLineInfo.itemIndexOffset + skillLineInfo.numSpellBookItems do

            local itemInfo = C_SpellBook.GetSpellBookItemInfo(
                slot,
                Enum.SpellBookSpellBank.Player
            )

            if itemInfo and itemInfo.spellID then
                local spellName = C_Spell.GetSpellName(itemInfo.spellID)

                if spellName then
                    spellBookCache[spellName] = spellBookCache[spellName] or {}
                    table.insert(spellBookCache[spellName], itemInfo.spellID)
                end
            end
        end

        skillLineIndex = skillLineIndex + 1
    end
    for id,duration in pairs(MaxDps.SHORT_BUFFS) do
        C_Spell.RequestLoadSpellData(id)
        spellNameDuration[C_Spell.GetSpellName(id)] = duration
    end

    local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBuff, true)
    if cooldownIDs then
        for i, id in ipairs(cooldownIDs) do
            local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
            if info and info.spellID  then
                local name = C_Spell.GetSpellName(info.spellID)
                if name then
                    spellNameTrackedID[name] = info.spellID
                end
            end
        end
    end
    for spellID, duration in pairs(MaxDps.DOTS) do
        MaxDps.DOTSName[C_Spell.GetSpellName(spellID)] = duration
    end
end

function MaxDps.GetDisplaySpellID(spellID)
    if not spellID or spellID <= 0 then return spellID end
    if not C_Spell_GetOverrideSpell then return spellID end

    local now = GetTime()
    if now ~= overrideCacheTime then
        wipe(overrideSpellCache)
        overrideCacheTime = now
    end
    local cached = overrideSpellCache[spellID]
    if cached ~= nil then
        return cached
    end

    local override = C_Spell_GetOverrideSpell(spellID)
    local result = spellID
    if override and override ~= 0 and override ~= spellID and not (IsPassiveID and IsPassiveID(override)) then
        result = override
    end
    result = PressedRank and PressedRank(result) or result
    overrideSpellCache[spellID] = result
    return result
end

local function Matches(entry, info)
    if type(info) ~= "table" then return false end
    local function hit(value)
        return type(value) == "number"
            and (value == entry.cast or value == entry.aura
                or MaxDps.GetDisplaySpellID(value) == MaxDps.GetDisplaySpellID(entry.aura))
    end
    if hit(info.spellID) or hit(info.overrideSpellID)
       or hit(info.overrideTooltipSpellID) or hit(info.linkedSpellID) then
        return true
    end
    local linkedSpellIDs = info.linkedSpellIDs
    if type(linkedSpellIDs) == "table" then
        for i = 1, #linkedSpellIDs do
            if hit(linkedSpellIDs[i]) then return true end
        end
    end
    return false
end

local function ResolveCooldownIDs(entry)
    if entry.cooldownIDs ~= nil then return entry.cooldownIDs end
    entry.cooldownIDs = {}

    local cooldownViewer = C_CooldownViewer
    if not (cooldownViewer and cooldownViewer.GetCooldownViewerCategorySet
            and cooldownViewer.GetCooldownViewerCooldownInfo) then
        return entry.cooldownIDs
    end

    local maxCategory = 3
    local categories = Enum and Enum.CooldownViewerCategory
    if type(categories) == "table" then
        for _, category in pairs(categories) do
            if type(category) == "number" and category > maxCategory then
                maxCategory = category
            end
        end
    end

    for category = 0, maxCategory do
        local ok, cooldownIDs = pcall(cooldownViewer.GetCooldownViewerCategorySet, category, true)
        if ok and type(cooldownIDs) == "table" then
            for i = 1, #cooldownIDs do
                local cooldownID = cooldownIDs[i]
                local okInfo, info = pcall(cooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
                if okInfo and Matches(entry, info) and type(cooldownID) == "number" then
                    entry.cooldownIDs[cooldownID] = category
                end
            end
        end
    end

    return entry.cooldownIDs
end

local auraCategories
local function IsAuraCategory(category)
    if not auraCategories then
        local categories = Enum and Enum.CooldownViewerCategory or {}
        auraCategories = {}
        for _, name in ipairs({ "TrackedBuff", "TrackedBar", "HiddenPassive", "EquipSlotTracked",
                                "SpecAgnosticTracked", "GroupBuff" }) do
            if categories[name] then auraCategories[categories[name]] = true end
        end
    end
    return auraCategories[category] == true
end

local BUFF_VIEWER_NAMES = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local function ViewerBuffActive(entry)
    local cooldownIDs = ResolveCooldownIDs(entry)
    if not next(cooldownIDs) then return nil end

    local sawFalse = false
    for i = 1, #BUFF_VIEWER_NAMES do
        local viewer = _G[BUFF_VIEWER_NAMES[i]]
        local pool = viewer and viewer.IsShown and viewer:IsShown() and viewer.itemFramePool
        if pool and pool.EnumerateActive then
            for item in pool:EnumerateActive() do
                local ok, cooldownID = pcall(item.GetCooldownID, item)
                if ok and type(cooldownID) == "number" and cooldownIDs[cooldownID]
                   and IsAuraCategory(cooldownIDs[cooldownID]) then
                    local active = item.isActive
                    if not MaxDps:issecretvalue(active) then
                        if active == true then return true end
                        if active == false then sawFalse = true end
                    end
                end
            end
        end
    end

    if sawFalse then return false end
    return nil
end

local trackedEntries = {}
local TRACKED_RESCAN = 5

local function S(name, fallback)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        if ok and info and info.spellID then return info.spellID end
    end
    return fallback
end

MaxDps.watcherExpires = {}
local function makeWatcher(spellID)
    local origSpellName = C_Spell.GetSpellName(spellID)
    if not MaxDps.CooldownViewerWatcher then
        local watcherExpire = 0
        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        watcher:SetScript("OnEvent", function(_, _, unit, _, spellId)
            local canCompare = C_Secrets.CanCompareUnitTokens(unit, "player")
            local sameUnit = not C_Secrets.ShouldUnitIdentityBeSecret(unit) and canCompare and UnitIsUnit(unit, "player") or false
            if sameUnit then
                watcherExpire = MaxDps.DOTS[spellId] and GetTime() + MaxDps.DOTS[spellId]
                or MaxDps.DOTSName[origSpellName] and GetTime() + MaxDps.DOTSName[origSpellName]
                or C_Spell.IsSpellHelpful(spellId) and  spellNameDuration[origSpellName] and GetTime() + spellNameDuration[origSpellName]
                or C_Spell.IsSpellHelpful(spellId) and GetTime() + 60
                or GetTime() + 9
                local targetGUID = not C_Secrets.ShouldUnitIdentityBeSecret("target") and UnitGUID("target")
                local UID
                if targetGUID and not MaxDps.issecretvalue(targetGUID) then
                    UID = targetGUID
                elseif C_Spell.IsSpellHelpful(spellId) or
                spellId == 8075 or
                spellId == 8835 or
                spellId == 3599 or
                spellId == 8190 then
                    UID = "player"
                else
                    UID = "target"
                end
                if not MaxDps.issecretvalue(UID) then
                    if not MaxDps.watcherExpires[UID] then
                        MaxDps.watcherExpires[UID] = {}
                    end
                    MaxDps.watcherExpires[UID][spellId] = watcherExpire
                    if not MaxDps.CooldownViewerWatcher then
                        MaxDps.CooldownViewerWatcher = watcher
                    end
                end

                for guid, spells in pairs(MaxDps.watcherExpires) do
                    for ID, Expire in pairs(spells) do
                        if not C_Spell.IsSpellHelpful(ID) then
                            if GetTime() - Expire > 60 then
                                MaxDps.watcherExpires[guid][ID] = nil
                            end
                        end
                    end
                end
            end
        end)
    end
end

function MaxDps.IsTrackedAuraActive(spellID)
    if not spellID then return nil end
    local origSpellName = C_Spell.GetSpellName(spellID)
    local spells = spellBookCache[origSpellName]
    local highestSpellRank = nil
    if spells and #spells > 0 then
        local lastSpellID = spells[#spells]
        highestSpellRank = lastSpellID
    end
    if highestSpellRank then
        spellID = highestSpellRank
    end
    if spellNameTrackedID and spellNameTrackedID[origSpellName] then
        spellID = spellNameTrackedID[origSpellName]
    end
    makeWatcher(spellID)
    --if spells and #spells > 0 then
    --    local highestSpellID = spells[1]
    --    for i = 2, #spells do
    --        if spells[i] > highestSpellID then
    --            highestSpellID = spells[i]
    --        end
    --    end
    --    spellID = highestSpellID
    --end

    local entry = trackedEntries[spellID]
    if not entry then
        entry = { cast = spellID, aura = spellID }
        trackedEntries[spellID] = entry
    end

    if entry.cooldownIDs and not next(entry.cooldownIDs)
       and GetTime() - (entry.resolvedAt or 0) > TRACKED_RESCAN then
        entry.cooldownIDs = nil
    end
    if entry.cooldownIDs == nil then entry.resolvedAt = GetTime() end
    local targetGUID = UnitGUID("target")
    local UID
    if targetGUID and not MaxDps.issecretvalue(targetGUID) then
        UID = targetGUID
    elseif C_Spell.IsSpellHelpful(spellID) then
        UID = "player"
    else
        UID = "target"
    end

    local enabled = GetCVar("cooldownViewerEnabled")
    local viewerBuff = ViewerBuffActive(entry)
    if enabled == "1" and viewerBuff then
        return ViewerBuffActive(entry)
    else
        return ViewerBuffActive(entry) or (not IsInInstance() and MaxDps.watcherExpires[UID] and MaxDps.watcherExpires[UID][spellID] and GetTime() < MaxDps.watcherExpires[UID][spellID])
    end
end

local scratchCooldown
local function DurationObjectActive(durObj)
    if durObj == nil then return false end
    if not scratchCooldown then
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:Hide()
        scratchCooldown = CreateFrame("Cooldown", nil, holder, "CooldownFrameTemplate")
    end
    if not scratchCooldown.SetCooldownFromDurationObject then return false end
    scratchCooldown:SetCooldownFromDurationObject(durObj)
    local shown = scratchCooldown:IsShown()
    scratchCooldown:SetCooldown(0, 0)
    return shown and true or false
end

function MaxDps.IsDurationObjectActive(durObj)
    return DurationObjectActive(durObj)
end

function MaxDps.IsSpellOnCooldown(spellID, ignoregcd)
    local origSpellName = C_Spell.GetSpellName(spellID)
    local spells = spellBookCache[origSpellName]
    if not spells or #spells == 0 then return true end
    local lastSpellID = spells[#spells]
    if lastSpellID then
        spellID = lastSpellID
    end
    if not (spellID and C_Spell and C_Spell.GetSpellCooldownDuration) then return false end
    if not (spellID and C_Spell and C_Spell.IsSpellUsable and C_Spell.IsSpellUsable(spellID)) then return true end
    local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, spellID, ignoregcd)
    return ok and DurationObjectActive(dur) or false
end

local clearAuraTableFrame
if MaxDps:IsForeverWow() then
    if not clearAuraTableFrame then
        clearAuraTableFrame = CreateFrame("Frame")
    end
    clearAuraTableFrame:SetScript("OnEvent", function(self, event, unitTarget, updateInfo)
        MaxDps.watcherExpires = {}
    end)
    clearAuraTableFrame:RegisterEvent("PLAYER_DEAD")
end

function MaxDps.Power(resource, isPercent)
    if resource == "mana" or resource == "energy" or resource == "rage" then
        return math.huge
    end
    if resource ~= "combo_points" then
        return 1
    end
    local powerTypes = Enum and Enum.PowerType
    local powerType = powerTypes and powerTypes.ComboPoints or 4
    local current = UnitPower("player", powerType)
    if isPercent == false then return current end
    local maximum = UnitPowerMax("player", powerType)
    return maximum > 0 and current / maximum * 100 or 0
end

function MaxDps.Stacks(_unit, spellID, _filter)
    if MaxDps.IsTrackedAuraActive(spellID) then
        return 1
    else
        return 0
    end
end

function MaxDps.Near(yards)
    if not UnitExists("target") then return false end
    local rangeCheck = LibStub and LibStub("LibRangeCheck-3.0", true)
    if rangeCheck then
        local minimum, maximum = rangeCheck:GetRange("target")
        return maximum ~= nil and maximum <= yards
    end
    return yards == 10 and CheckInteractDistance("target", 3) or false
end

function MaxDps.Starved()
    local _, insufficientPower
    local _, _, classId = UnitClass("target") -- "Mage", "MAGE", 8
    local checkSpell
    if classId == 1 then -- Warrior
        checkSpell = 100 --  Charge
    end
    if classId == 2 then -- Paladin
        checkSpell = 639 --  Holy Light
    end
    if classId == 3 then -- Hunter
        checkSpell = 2973 --  Raptor Strike
    end
    if classId == 4 then
        checkSpell = 1752 --  Sinister Strike
    end
    if classId == 5 then -- Priest
        checkSpell = 585 --  Smite
    end
    if classId == 7 then -- Shaman
        checkSpell = 403 --  Lightning Bolt
    end
    if classId == 8 then -- Mage
        checkSpell = 116 --  Frostbolt
    end
    if classId == 9 then -- Warlock
        checkSpell = 686 --  Shadow Bolt
    end
    if classId == 11 then -- Druid
        checkSpell = 5176 --  Wrath
    end
    if checkSpell then
        _, insufficientPower = C_Spell.IsSpellUsable(checkSpell)
        if insufficientPower then
            return true
        end
    end
    return false
end
