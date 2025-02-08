--- @type MaxDps MaxDps
local MaxDps = _G.MaxDps

MaxDps.swingtimer = {}

-- Event handler for combat log events
local function OnEvent(self, event)
    local timestamp, eventType, _, sourceGUID, _, _, _, _, _, _, _, _, arg13, arg14, _, _, _, _, _, _, _, _, _, _, _, _, _, _ = CombatLogGetCurrentEventInfo()
    -- Listen for the player's swing events: SWING_DAMAGE, SWING_MISSED, RANGE_DAMAGE, RANGE_MISSED
    -- Check if the source is the player's character
    MaxDps.swingtimer.mainhand = MaxDps.swingtimer.mainhand or math.huge
    MaxDps.swingtimer.offhand = MaxDps.swingtimer.offhand or math.huge
    MaxDps.swingtimer.ranged = MaxDps.swingtimer.ranged or math.huge
    if sourceGUID == UnitGUID("player") then
        if eventType == "SWING_DAMAGE" or eventType == "SWING_MISSED" then
            -- Get the attack speeds for mainhand and offhand
            local mainSpeed, offSpeed = UnitAttackSpeed("player")
            -- Check if it's a mainhand or offhand swing
            if mainSpeed and arg14 == 1 then  -- Mainhand swing
                -- Update the next swing time for the mainhand
                MaxDps.swingtimer.mainhand = timestamp + mainSpeed
            elseif offSpeed and arg14 == 2 then  -- Offhand swing
                -- Update the next swing time for the offhand
                MaxDps.swingtimer.offhand = timestamp + offSpeed
            end
        elseif eventType == "RANGE_DAMAGE" or eventType == "RANGE_MISSED" then
            -- Update the next swing time for ranged attacks
            local rangedAttackSpeed = UnitRangedDamage("player") -- First return value is attack speed
            MaxDps.swingtimer.ranged = timestamp + rangedAttackSpeed
        end
    end
    MaxDps.swingtimer.any = math.min(MaxDps.swingtimer.mainhand, MaxDps.swingtimer.offhand, MaxDps.swingtimer.ranged)
end

-- Create a frame to handle events
local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Set the script to handle the event
frame:SetScript("OnEvent", OnEvent)