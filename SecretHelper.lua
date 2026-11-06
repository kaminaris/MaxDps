local addonName, MaxDps = ...

local GetTime = GetTime
local ipairs = ipairs
local pcall = pcall
local C_Spell_GetOverrideSpell          = C_Spell and C_Spell.GetOverrideSpell

local overrideSpellCache = {}
local overrideCacheTime = -1


local spellBookCache = {}
local spellNameDuration = {}

function MaxDps.CacheSpells()
    --wipe(spellBookCache)

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
    for id,duration in pairs(MaxDps.SHORT_BUFFS)do
        spellNameDuration[C_Spell.GetSpellName(id)] = duration
    end
end

function MaxDps.GetDisplaySpellID(spellID)
    -- <= 0 covers items (negative by our convention) and the queue's wait sentinel:
    -- neither has an override, and the C call's behavior on such ids is not something
    -- we guess at (project rule). Identity is the correct answer for both.
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
    -- Never resolve INTO a passive: the client's override data can map a castable onto
    -- a passive talent's id (the id is real; it is just not a button). Every consumer
    -- of this function wants "the id to DISPLAY/cast", so a passive override is always
    -- wrong - keep the castable input id instead.
    local result = spellID
    if override and override ~= 0 and override ~= spellID and not (IsPassiveID and IsPassiveID(override)) then
        result = override
    end
    -- Forever ranks: any rank of a curated list resolves to the rank actually pressed. The
    -- ONE place that choice is made, so every list (rotation, defensives, gap closers,
    -- interrupts) shows the button's rank and finds its hotkey.
    result = PressedRank and PressedRank(result) or result
    overrideSpellCache[spellID] = result   -- "no override" is cached as well
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

local watcherExpires = {}
local function makeWatcher(spellID)
    local origSpellName = C_Spell.GetSpellName(spellID)
    if not MaxDps.CooldownViewerWatcher then MaxDps.CooldownViewerWatcher = {} end
    if not MaxDps.CooldownViewerWatcher[spellID] then
        local watcherExpire = 0
        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        watcher:SetScript("OnEvent", function(_, _, unit, _, spellId)
            if unit == "player" and spellId == S(origSpellName, spellID) then
                watcherExpire = MaxDps.DOTS[spellID] and GetTime() + MaxDps.DOTS[spellID] or C_Spell.IsSpellHelpful(spellID) and  spellNameDuration[origSpellName] and GetTime() + spellNameDuration[origSpellName] or C_Spell.IsSpellHelpful(spellID) and GetTime() + 60 or 9
                local UID = UnitGUID("target") or 1
                if C_Spell.IsSpellHelpful(spellID) then
                    UID = UnitGUID("player") or 1
                end
                if not MaxDps.CooldownViewerWatcher then MaxDps.CooldownViewerWatcher = {} end
                if not MaxDps.CooldownViewerWatcher[UID] then MaxDps.CooldownViewerWatcher[UID] = {} end
                if not watcherExpires[UID] then
                    watcherExpires[UID] = {}
                end
                watcherExpires[UID][spellID] = watcherExpire
                MaxDps.CooldownViewerWatcher[UID][spellID] = watcher
                if not C_Spell.IsSpellHelpful(spellID) then
                    for guid, spells in pairs(watcherExpires) do
                        for spellID, watcherExpire in pairs(spells) do
                            if GetTime() - watcherExpire > 60 then
                                watcherExpires[guid][spellID] = nil
                                if MaxDps.CooldownViewerWatcher[guid] and MaxDps.CooldownViewerWatcher[guid][spellID] then
                                    local watcherT = MaxDps.CooldownViewerWatcher[guid][spellID]
                                    if watcherT and watcherT.UnregisterEvent then
                                        watcherT:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
                                        watcherT:SetScript("OnEvent", nil)
                                        watcherT = nil
                                    end
                                    MaxDps.CooldownViewerWatcher[guid][spellID] = nil
                                end
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
    local UID = UnitGUID("target") or 1
    if C_Spell.IsSpellHelpful(spellID) then
        UID = UnitGUID("player") or 1
    end

    return ViewerBuffActive(entry) or (watcherExpires[UID] and watcherExpires[UID][spellID] and GetTime() < watcherExpires[UID][spellID])
end

local scratchCooldown
local function DurationObjectActive(durObj)
    if durObj == nil then return false end
    if not scratchCooldown then
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:Hide()  -- parent hidden -> the probe frame never renders
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
    if not (spellID and C_Spell and C_Spell.GetSpellCooldownDuration) then return false end
    if not (spellID and C_Spell and C_Spell.IsSpellUsable and C_Spell.IsSpellUsable(spellID)) then return true end
    local origSpellName = C_Spell.GetSpellName(spellID)
    local spells = spellBookCache[origSpellName]
    if not spells or #spells == 0 then return true end
    -- pcall like every sibling read: this runs inside the queue build, where a throw on
    -- an odd id blanks the queue instead of degrading one entry.
    local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, spellID, ignoregcd)
    return ok and DurationObjectActive(dur) or false
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
