--- @type MaxDps MaxDps
local _, MaxDps = ...

local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local TableInsert = tinsert
local TableRemove = tremove
local MathMin = math.min
local wipe = wipe

function MaxDps:InitTTD(maxSamples, interval)
    interval = interval or 0.25
    maxSamples = maxSamples or 50

    if self.ttd and self.ttd.timer then
        self:CancelTimer(self.ttd.timer)
        self.ttd.timer = nil
    end

    self.ttd = {
        interval   = interval,
        maxSamples = maxSamples,
        HPTable    = {},
    }

    self.ttd.timer = self:ScheduleRepeatingTimer('TimeToDie', interval)
end

function MaxDps:DisableTTD()
    if self.ttd.timer then
        self:CancelTimer(self.ttd.timer)
    end
end

local HPTable = {}
local trackedGuid
function MaxDps:TimeToDie(trackedUnit)
    trackedUnit = trackedUnit or 'target'

    -- Query current time (throttle updating over time)
    local now = GetTime()

    -- Current data
    local ttd = self.ttd
    local guid = UnitGUID(trackedUnit)

    if trackedGuid ~= guid then
        wipe(HPTable)
        trackedGuid = guid
    end

    if guid and UnitExists(trackedUnit) then
        local hpPct = self:TargetPercentHealth() * 100
        TableInsert(HPTable, 1, { time = now, hp = hpPct})

        if #HPTable > ttd.maxSamples then
            TableRemove(HPTable)
        end
    else
        wipe(HPTable)
    end
end

function MaxDps:GetTimeToDie()
    local seconds = 5*60

    local n = #HPTable
    if n > 5 then
        local a, b
        local Ex2, Ex, Exy, Ey = 0, 0, 0, 0

        local hpPoint, x, y
        for i = 1, n do
            hpPoint = HPTable[i]
            x, y = hpPoint.time, hpPoint.hp

            Ex2 = Ex2 + x * x
            Ex = Ex + x
            Exy = Exy + x * y
            Ey = Ey + y
        end

        -- Invariant to find matrix inverse
        local invariant = 1 / (Ex2 * n - Ex * Ex)

        -- Solve for a and b
        a = (-Ex * Exy * invariant) + (Ex2 * Ey * invariant)
        b = (n * Exy * invariant) - (Ex * Ey * invariant)

        if b ~= 0 then
            -- Use best fit line to calculate estimated time to reach target health
            seconds = (0 - a) / b
            seconds = MathMin(5*60, seconds - (GetTime() - 0))

            if seconds < 0 then
                seconds = 5*60
            end
        end
    end

    if WeakAuras then WeakAuras.ScanEvents('MAXDPS_TIME_TO_DIE', seconds) end
    return seconds
end

local unitidtable = {}
do
    TableInsert(unitidtable,"target")
    for i=1,40 do
        TableInsert(unitidtable,"nameplate" .. i)
    end
end

local function NewTimeToDieTracker()
    for i,plate in pairs(unitidtable) do
        local unitguid = UnitGUID(plate)
        if UnitExists(plate) then
            if not MaxDps.ttd then
                MaxDps.ttd = {}
            end
            if not MaxDps.ttd.data then
                MaxDps.ttd.data = {}
            end
            if not MaxDps.ttd.data[plate] then
                MaxDps.ttd.data[plate] = {}
            end
            if not MaxDps.ttd.data[plate].unitguid then
                MaxDps.ttd.data[plate].unitguid = unitguid
            end
            if (not MaxDps.ttd.data[plate].oldHP) or (MaxDps.ttd.data[plate].unitguid ~= unitguid)  then
                MaxDps.ttd.data[plate].oldHP = UnitHealth(plate)
            end
            if (MaxDps.ttd.data[plate].unitguid ~= unitguid)  then
                MaxDps.ttd.data[plate].unitguid = unitguid
            end
            if MaxDps.ttd.data[plate] then
                MaxDps.ttd.data[plate].newHP = UnitHealth(plate)
            end
            if MaxDps.ttd.data[plate] and MaxDps.ttd.data[plate].oldHP and MaxDps.ttd.data[plate].newHP then
                local dps = MaxDps.ttd.data[plate].oldHP - MaxDps.ttd.data[plate].newHP
                if dps >= 0 then
                    MaxDps.ttd.data[plate].DPS = MaxDps.ttd.data[plate].oldHP - MaxDps.ttd.data[plate].newHP
                end
            end
            -- Reset old hp for next calculation
            MaxDps.ttd.data[plate].oldHP = UnitHealth(plate)
        else
            if MaxDps and MaxDps.ttd and MaxDps.ttd.data and MaxDps.ttd.data[plate] then
                MaxDps.ttd.data[plate] = nil
            end
        end
    end
end

local newTTDtimer
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        --self:ScheduleRepeatingTimer('NewTimeToDie', 1)
        newTTDtimer = C_Timer.NewTicker(1,NewTimeToDieTracker)
    end
    if event == "PLAYER_REGEN_ENABLED" then
        --self:ScheduleRepeatingTimer('NewTimeToDie', 1)
        if newTTDtimer and not newTTDtimer:IsCancelled() then
            newTTDtimer:Cancel()
        end
        if not MaxDps.ttd then
            MaxDps.ttd = {}
        end
        if not MaxDps.ttd.data then
            MaxDps.ttd.data = {}
        end
        MaxDps.ttd.data = {}
    end
end)

-- Function to calculate time till target health reaches a specific percentage
function MaxDps:GetTimeToPct(Pct)
    if not UnitExists("target") then
        return 500
    end
    local howFar
    local damagePerSecond = (MaxDps.ttd and MaxDps.ttd.data and MaxDps.ttd.data.target and MaxDps.ttd.data.target.DPS and MaxDps.ttd.data.target.DPS) or 0
    local timeToReach
    local currentHealth = UnitHealth("target")
    local goalHP = Pct / 100 * UnitHealthMax("target")
    if currentHealth > goalHP then
        howFar = UnitHealth("target") - goalHP
        timeToReach = howFar / damagePerSecond
        if timeToReach == math.huge then
            timeToReach = 500
        end
    else
        timeToReach = 0
    end
    return timeToReach
end

-- Function to find what mod has the longest ttd and how long that is
function MaxDps:MaxAddDuration()
    local duration
    local durationtotal = 0
    if MaxDps.ttd and MaxDps.ttd.data then
       for target,data in pairs(MaxDps.ttd.data) do
          if target and data and data.DPS and data.DPS>0 then
             local howFar
             local damagePerSecond = data.DPS
             local currentHealth = UnitHealth(target)
             local goalHP = 0 / 100 * UnitHealthMax(target)
             if currentHealth > goalHP then
                howFar = UnitHealth(target) - goalHP
                duration = howFar / damagePerSecond
                if duration == math.huge then
                   duration = 500
                end
             else
                duration = 0
             end
             if duration > durationtotal then
                durationtotal = duration
             end
          end
       end
    end
    return durationtotal
end
