--- @type MaxDps MaxDps
local _, MaxDps = ...
local GetInventorySlotInfo = GetInventorySlotInfo
local GetInventoryItemLink = GetInventoryItemLink
local GetItemInfo = C_Item.GetItemInfo

local slots = {"HEADSLOT","SHOULDERSLOT", "CHESTSLOT", "LEGSSLOT", "HANDSSLOT"}
local tiernumbers = {29, 30, 31, 32, 33, 34}

for i=1,40 do
    if not MaxDps.tier then MaxDps.tier = {} end
    if not MaxDps.tier[i] then MaxDps.tier[i] = {} end
    if not MaxDps.tier[i].count then MaxDps.tier[i].count = 0 end
end

function MaxDps:CountTier()
    local _, _, classIndex = UnitClass("player")

    local count

    for _,tier in pairs(tiernumbers) do
        count = 0
        for _,slotName in pairs(slots) do
            local match = nil
            local slotID = GetInventorySlotInfo(slotName)
            local itemLink = GetInventoryItemLink("player", slotID)
            local itemName
            if itemLink then
                itemName = GetItemInfo(itemLink)
            else
                break
            end

            if itemName == nil then return end

            if tier == 30 then
                -- DK
                if classIndex == 6 then
                    match = string.match(itemName,"Lingering Phantom's")
                end
                -- DH
                if classIndex == 12 then
                    match = string.match(itemName,"Kinslayer's")
                end
                -- Druid
                if classIndex == 11 then
                    match = string.match(itemName,"the Autumn Blaze")
                end
                -- Evoker
                if classIndex == 13 then
                    match = string.match(itemName,"Obsidian Secrets")
                end
                -- Hunter
                if classIndex == 3 then
                    match = string.match(itemName,"Ashen Predator's")
                end
                -- Mage
                if classIndex == 8 then
                    match = string.match(itemName,"Underlight Conjurer's")
                end
                -- Monk
                if classIndex == 10 then
                    match = string.match(itemName,"the Vermillion Forge")
                end
                -- Paladin
                if classIndex == 2 then
                    match = string.match(itemName,"Heartfire Sentinel's")
                end
                -- Priest
                if classIndex == 5 then
                    match = string.match(itemName,"The Furnace Seraph")
                end
                -- Rogue
                if classIndex == 4 then
                    match = string.match(itemName,"Lurking Specter's")
                end
                -- Shaman
                if classIndex == 7 then
                    match = string.match(itemName,"of the Cinderwolf")
                end
                -- Warlock
                if classIndex == 9 then
                    match = string.match(itemName,"Grim Inquisitor's")
                end
                -- Warrior
                if classIndex == 1 then
                    match = string.match(itemName,"of the Onyx Crucible")
                end
            end
            if tier == 31 then
                -- DK
                if classIndex == 6 then
                    match = string.match(itemName,"of the Risen Nightmare")
                end
                -- DH
                if classIndex == 12 then
                    match = string.match(itemName,"Screaming Torchfiend's")
                end
                -- Druid
                if classIndex == 11 then
                    match = string.match(itemName,"Benevolent Embersage's")
                end
                -- Evoker
                if classIndex == 13 then
                    match = string.match(itemName,"Werynkeeper's Timeless")
                end
                -- Hunter
                if classIndex == 3 then
                    match = string.match(itemName,"Blazing Dreamstalker's")
                end
                -- Mage
                if classIndex == 8 then
                    match = string.match(itemName,"Wayward Chronomancer's")
                end
                -- Monk
                if classIndex == 10 then
                    match = string.match(itemName,"Mystic Heron's")
                end
                -- Paladin
                if classIndex == 2 then
                    match = string.match(itemName,"Zealous Pyreknight's")
                end
                -- Priest
                if classIndex == 5 then
                    match = string.match(itemName,"of Lunar Communion")
                end
                -- Rogue
                if classIndex == 4 then
                    match = string.match(itemName,"Lucid Shadewalker's")
                end
                -- Shaman
                if classIndex == 7 then
                    match = string.match(itemName,"Greatwolf Outcast's")
                end
                -- Warlock
                if classIndex == 9 then
                    match = string.match(itemName,"Devout Ashdevil's")
                end
                -- Warrior
                if classIndex == 1 then
                    match = string.match(itemName,"Molten Vanguard's")
                end
            end
            if tier == 32 then
                -- DK
                if classIndex == 6 then
                    match = string.match(itemName,"Exhumed Centurion's")
                end
                -- DH
                if classIndex == 12 then
                    match = string.match(itemName,"of the Hypogeal Nemesis")
                end
                -- Druid
                if classIndex == 11 then
                    match = string.match(itemName,"of the Greatlynx")
                end
                -- Evoker
                if classIndex == 13 then
                    match = string.match(itemName,"of the Destroyer")
                end
                -- Hunter
                if classIndex == 3 then
                    match = string.match(itemName,"Lightless Scavenger's")
                end
                -- Mage
                if classIndex == 8 then
                    match = string.match(itemName,"of Violet Rebirth")
                end
                -- Monk
                if classIndex == 10 then
                    match = string.match(itemName,"Gatecrasher's")
                end
                -- Paladin
                if classIndex == 2 then
                    match = string.match(itemName,"Entombed Seraph's")
                end
                -- Priest
                if classIndex == 5 then
                    match = string.match(itemName,"Living Luster's")
                end
                -- Rogue
                if classIndex == 4 then
                    match = string.match(itemName,"K'areshi Phantom's")
                end
                -- Shaman
                if classIndex == 7 then
                    match = string.match(itemName,"of the Forgotten Reservoir")
                end
                -- Warlock
                if classIndex == 9 then
                    match = string.match(itemName,"Hexflame Coven's")
                end
                -- Warrior
                if classIndex == 1 then
                    match = string.match(itemName,"Warsculptor's")
                end
            end
            if tier == 33 then
                -- DK
                if classIndex == 6 then
                    match = string.match(itemName,"Cauldron Champion's")
                end
                -- DH
                if classIndex == 12 then
                    match = string.match(itemName,"Fel-Dealer's")
                end
                -- Druid
                if classIndex == 11 then
                    match = string.match(itemName,"of Reclaiming Blight")
                end
                -- Evoker
                if classIndex == 13 then
                    match = string.match(itemName,"Opulent Treasurescale's")
                end
                -- Hunter
                if classIndex == 3 then
                    match = string.match(itemName,"Tireless Collector's")
                end
                -- Mage
                if classIndex == 8 then
                    match = string.match(itemName,"Aspectral Emissary's")
                end
                -- Monk
                if classIndex == 10 then
                    match = string.match(itemName,"Ageless Serpent's")
                end
                -- Paladin
                if classIndex == 2 then
                    match = string.match(itemName,"Aureate Sentry's")
                end
                -- Priest
                if classIndex == 5 then
                    match = string.match(itemName,"Confessor's Unshakable")
                end
                -- Rogue
                if classIndex == 4 then
                    match = string.match(itemName,"Spectral Gambler's")
                end
                -- Shaman
                if classIndex == 7 then
                    match = string.match(itemName,"Gale Sovereign's")
                end
                -- Warlock
                if classIndex == 9 then
                    match = string.match(itemName,"Spliced Fiendtrader's")
                end
                -- Warrior
                if classIndex == 1 then
                    match = string.match(itemName,"Enforcer's Backalley")
                end
            end
            if tier == 34 then
                -- DK
                if classIndex == 6 then
                    match = string.match(itemName,"Hollow Sentinel's")
                end
                -- DH
                if classIndex == 12 then
                    match = string.match(itemName,"Charhound's Vicious")
                end
                -- Druid
                if classIndex == 11 then
                    match = string.match(itemName,"of the Mother Eagle")
                end
                -- Evoker
                if classIndex == 13 then
                    match = string.match(itemName,"Spellweaver's Immaculate")
                end
                -- Hunter
                if classIndex == 3 then
                    match = string.match(itemName,"Midnight Herald's")
                end
                -- Mage
                if classIndex == 8 then
                    match = string.match(itemName,"Augur's Ephemeral")
                end
                -- Monk
                if classIndex == 10 then
                    match = string.match(itemName,"of Fallen Storms")
                end
                -- Paladin
                if classIndex == 2 then
                    match = string.match(itemName,"of the Lucent Battalion")
                end
                -- Priest
                if classIndex == 5 then
                    match = string.match(itemName,"Dying Star's")
                end
                -- Rogue
                if classIndex == 4 then
                    match = string.match(itemName,"of the Sudden Eclipse")
                end
                -- Shaman
                if classIndex == 7 then
                    match = string.match(itemName,"of Channeled Fury")
                end
                -- Warlock
                if classIndex == 9 then
                    match = string.match(itemName,"of Madness")
                end
                -- Warrior
                if classIndex == 1 then
                    match = string.match(itemName,"Living Weapon's")
                end
            end
            if match then count = count + 1 end
        end
        if count > 0 then
            MaxDps.tier[tier].count = count
        end
    end
end