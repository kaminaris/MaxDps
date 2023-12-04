--- @type MaxDps MaxDps
local _, MaxDps = ...;
local GetInventorySlotInfo = GetInventorySlotInfo
local GetInventoryItemLink = GetInventoryItemLink
local GetItemInfo = GetItemInfo

local slots = {"HEADSLOT","SHOULDERSLOT", "CHESTSLOT", "LEGSSLOT", "HANDSSLOT"}
local tiernumbers = {30, 31}

function MaxDps:CountTier()
    if not self.tier then
        self.tier = {}
    end
    local _, _, classIndex = UnitClass("player")

    local count = 0

    local tier
    for _,tier in pairs(tiernumbers) do
        if not self.tier[tier] then
            self.tier[tier] = {}
        end
        for _,slotName in pairs(slots) do
            local match = nil
            local slotID = GetInventorySlotInfo(slotName)
            local itemLink = GetInventoryItemLink("player", slotID)
            local itemName
            if itemLink then
                itemName = GetItemInfo(itemLink)
                --print(itemLink)
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
            if match then count = count + 1 end
        end
        self.tier[tier].count = count
    end
    return count
end