--- @type MaxDps MaxDps
local MaxDps = _G.MaxDps

MaxDps.swingtimer = {}
MaxDps.swingtimer.mainhand = math.huge
MaxDps.swingtimer.offhand = math.huge
MaxDps.swingtimer.melee = math.huge
MaxDps.swingtimer.ranged = math.huge

-- Function to calculate remaining time for swings
local function UpdateSwingTimers()
    local currentTime = GetTime()
    --print(MaxDps.swingtimer.mainhand, currentTime)
    MaxDps.swingtimer.remainingMainhand = math.max(0, MaxDps.swingtimer.mainhand - currentTime)
    MaxDps.swingtimer.remainingOffhand = math.max(0, MaxDps.swingtimer.offhand - currentTime)
    MaxDps.swingtimer.remainingRanged = math.max(0, MaxDps.swingtimer.ranged - currentTime)
    MaxDps.swingtimer.remainingMelee = math.min(MaxDps.swingtimer.remainingMainhand, MaxDps.swingtimer.remainingOffhand)
    MaxDps.swingtimer.remainingAny = math.min(MaxDps.swingtimer.remainingMainhand, MaxDps.swingtimer.remainingOffhand, MaxDps.swingtimer.remainingRanged)
    --print(MaxDps.swingtimer.remainingMainhand)
    --print(MaxDps.swingtimer.remainingMelee)
end

-- Event handler for combat log events
local function OnEvent(self, event)
    local timestamp, eventType, _, sourceGUID, _, _, _, _, _, _, _, _, arg13, arg14, _, _, _, _, _, _, _, _, _, _, _, _, _, _ = CombatLogGetCurrentEventInfo()
    -- Listen for the player's swing events: SWING_DAMAGE, SWING_MISSED, RANGE_DAMAGE, RANGE_MISSED
    -- Check if the source is the player's character
    MaxDps.swingtimer.mainhand = MaxDps.swingtimer.mainhand or math.huge
    MaxDps.swingtimer.offhand = MaxDps.swingtimer.offhand or math.huge
    MaxDps.swingtimer.melee = math.min(MaxDps.swingtimer.mainhand, MaxDps.swingtimer.offhand)
    MaxDps.swingtimer.ranged = MaxDps.swingtimer.ranged or math.huge
    if sourceGUID == UnitGUID("player") then
        if eventType == "SWING_DAMAGE" or eventType == "SWING_MISSED" then
            -- Get the attack speeds for mainhand and offhand
            local mainSpeed, offSpeed = UnitAttackSpeed("player")
            -- Check if it's a mainhand or offhand swing
            if mainSpeed and arg14 == 1 then  -- Mainhand swing
                -- Update the next swing time for the mainhand
                MaxDps.swingtimer.mainhand = GetTime() + mainSpeed
            elseif offSpeed and arg14 == 2 then  -- Offhand swing
                -- Update the next swing time for the offhand
                MaxDps.swingtimer.offhand = GetTime() + offSpeed
            end
        elseif eventType == "RANGE_DAMAGE" or eventType == "RANGE_MISSED" then
            -- Update the next swing time for ranged attacks
            local rangedAttackSpeed = UnitRangedDamage("player") -- First return value is attack speed
            MaxDps.swingtimer.ranged = GetTime() + rangedAttackSpeed
        end
    end
    MaxDps.swingtimer.melee = math.min(MaxDps.swingtimer.mainhand, MaxDps.swingtimer.offhand)
    MaxDps.swingtimer.any = math.min(MaxDps.swingtimer.mainhand, MaxDps.swingtimer.offhand, MaxDps.swingtimer.ranged)

    -- Update remaining time for swings
    UpdateSwingTimers()
end

-- Run MyFunction every 1 second
C_Timer.NewTicker(0.25, UpdateSwingTimers)

-- Create a frame to handle events
local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Set the script to handle the event
frame:SetScript("OnEvent", OnEvent)