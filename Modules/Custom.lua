--- @type MaxDps MaxDps
local _, MaxDps = ...

local SharedMedia = LibStub('LibSharedMedia-3.0')
---@type StdUi
local StdUi = LibStub('StdUi')

--- @class MaxDpsCustom
local Custom = MaxDps:NewModule('Custom', 'AceTimer-3.0')

local IndentationLib = IndentationLib
local TableInsert = tinsert
local unpack = unpack
local format = format
local pairs = pairs
local loadstring = loadstring
local pcall = pcall
local GetNumClasses = GetNumClasses
local GetClassInfo = GetClassInfo

local GetNumSpecializationsForClassID =  C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID or GetNumSpecializationsForClassID
local GetSpecializationInfoForClassID =  GetSpecializationInfoForClassID

local CLASS_ICON_TCOORDS = CLASS_ICON_TCOORDS

function Custom:GetClassIcon(classTag)
    local x1, x2, y1, y2 = unpack(CLASS_ICON_TCOORDS[classTag])

    return format(
        '|TInterface\\TARGETINGFRAME\\UI-CLASSES-CIRCLES:14:14:0:0:256:256:%u:%u:%u:%u|t',
        x1 * 256,
        x2 * 256,
        y1 * 256,
        y2 * 256
    )
end

function Custom:OnEnable()
    self.CustomRotations = {}
    self.Specs = {}
    -- private for dropdowns
    self.classList = {}
    self.specList = {}

    for i = 1, MaxDps.IsClassicWow() and 11 or GetNumClasses() do -- Classic only returns 9 but Druid is 11
        local classDisplayName, classTag, classId = GetClassInfo(i)
        if not ((i==6 or i==10) and MaxDps.IsClassicWow()) then -- Skip DK 6 and Monk 10 in Classic but continue to Druid 11
            TableInsert(self.classList, {
                text  = self:GetClassIcon(classTag) .. ' ' .. classDisplayName,
                value = classId
            })

            local specNum = GetNumSpecializationsForClassID(classId)
            for sI = 0, specNum do
                local _, specName, _, specIcon = GetSpecializationInfoForClassID(classId, sI)
                if specName then
                    specName = '|T' .. specIcon .. ':0|t ' .. specName
                    if not self.Specs[classId] then
                        self.Specs[classId] = {}
                    end

                    self.Specs[classId][sI] = specName

                    if not self.specList[classId] then
                        self.specList[classId] = {}
                    end
                    TableInsert(self.specList[classId], { text = specName, value = sI })
                end
            end
        end
    end

    return self
end

function Custom:CreateCustomRotation()
    local customRotation = {
        name    = 'New Rotation',
        enabled = false,
        class   = nil,
        spec    = nil,
        fn      = 'function()\n    local fd = MaxDps.FrameData\n    -- your code here\nend',
    }

    TableInsert(MaxDps.db.global.customRotations, customRotation)
    return customRotation
end

function Custom:RemoveCustomRotation()
    local needRefresh
    for k, rotation in pairs(MaxDps.db.global.customRotations) do
        if rotation == Custom.CurrentEditRotation then
            MaxDps.db.global.customRotations[k] = nil
            needRefresh = true
        end
    end
    if needRefresh then
        MaxDps:DisableRotation(true)
        MaxDps:InitRotations()
        MaxDps:EnableRotation()
    end

    self.CurrentEditRotation = nil
end

function Custom:LoadCustomRotations()
    for k, _ in pairs(self.CustomRotations) do
        self.CustomRotations[k] = nil
    end

    for _, rotation in pairs(MaxDps.db.global.customRotations) do
        MaxDps:Print(MaxDps.Colors.Info .. 'Loaded Custom Rotation: ' .. (rotation and rotation.name or "Unknown") )
        if rotation.enabled and rotation.class ~= nil and rotation.spec ~= nil then
            local fn = Custom.LoadFunction(rotation.fn)
            if not self.CustomRotations[rotation.class] then
                self.CustomRotations[rotation.class] = {}
            end

            self.CustomRotations[rotation.class][rotation.spec] = {
                name = rotation.name,
                fn   = fn
            }
        end
    end
end

function Custom:GetCustomRotation(classId, spec)
    if self.CustomRotations[classId] and self.CustomRotations[classId][spec] then
        return self.CustomRotations[classId][spec]
    else
        return nil
    end
end

--[[
    Borrowed from WeakAuras

    This is free software: you can redistribute it and/or modify it under the terms of
    the GNU General Public License version 2 as published by the Free Software
    Foundation.

    For more information see WeakAuras License
]]
local blockedFunctions = {
  -- Lua functions that may allow breaking out of the environment
  getfenv = true,
  setfenv = true,
  loadstring = true,
  pcall = true,
  xpcall = true,
  -- blocked WoW API
  SendMail = true,
  SetTradeMoney = true,
  AddTradeMoney = true,
  PickupTradeMoney = true,
  PickupPlayerMoney = true,
  TradeFrame = true,
  MailFrame = true,
  EnumerateFrames = true,
  RunScript = true,
  AcceptTrade = true,
  SetSendMailMoney = true,
  EditMacro = true,
  DevTools_DumpCommand = true,
  hash_SlashCmdList = true,
  RegisterNewSlashCommand = true,
  CreateMacro = true,
  SetBindingMacro = true,
  GuildDisband = true,
  GuildUninvite = true,
  securecall = true,
  DeleteCursorItem = true,
  ChatEdit_SendText = true,
  ChatEdit_ActivateChat = true,
  ChatEdit_ParseText = true,
  ChatEdit_OnEnterPressed = true,
  GetButtonMetatable = true,
  GetEditBoxMetatable = true,
  GetFontStringMetatable = true,
  GetFrameMetatable = true,
}

local function forbidden()
    print('|cffffff00A A MaxDps custom rotation just tried to use a forbidden function but has been blocked from doing so.|r')
end

local env_getglobal
local exec_env = setmetatable({}, { __index = function(t, k)
    if k == '_G' then
        return t
    elseif k == 'getglobal' then
        return env_getglobal
    elseif blockedFunctions[k] then
        return forbidden
    else
        return _G[k]
    end
end
})

local function_cache = {}
function Custom.LoadFunction(string)
    if function_cache[string] then
        return function_cache[string]
    else
        local loadedFunction, errorString = loadstring('return ' .. string)
        if errorString then
            print(errorString)
        else
            setfenv(loadedFunction, exec_env)
            local success, func = pcall(assert(loadedFunction))
            if success then
                function_cache[string] = func
                return func
            end
        end
    end
end
