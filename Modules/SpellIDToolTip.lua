-- create an addon with AceHook embeded
local MyAddon = LibStub("AceAddon-3.0"):NewAddon("MaxDpsHookDemo", "AceHook-3.0")
local UnitAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex or UnitAura -- use C_UnitAuras if available

-- Tracks whether an ID line has already been added for the current tooltip build.
-- Reset via hooksecurefunc on SetItem/SetSpell/SetHyperlink (fires after all post-callbacks)
-- and via OnHide.
local tooltipIDAdded = false

local function TooltipHasIDLine(tooltip)
    for i = 1, tooltip:NumLines() do
        local line = _G[tooltip:GetName() .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text:find("ID:") then
                return true
            end
        end
    end
    return false
end

-- NOTE: These functions are called by TooltipDataProcessor as plain functions:
--   callback(tooltipFrame, tooltipData)
-- Because of Lua colon-notation desugaring, the implicit 'self' = tooltipFrame (arg1)
-- and the explicit parameter 'tooltipData' = the data table (arg2).
-- When called via SecureHookScript: callback(tooltipFrame) → self = tooltipFrame, tooltipData = nil.

function MyAddon:SetUnitAura(self, unit, index, filter)
    if MaxDpsOptions and MaxDpsOptions.global and not MaxDpsOptions.global.debugMode then return end
    local _, id, source
    if unit then
        -- print(UnitAura(unit,index,filter))
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
            if aura then
                id = aura.spellId
                source = aura.sourceUnit
            end
        else
            _, _, _, _, _, _, source, _, _, id = UnitAura(unit, index, filter)
        end
    else
        if self.GetSpell then
            _, id = self:GetSpell()
        end
    end
    if id then
        self:AddLine(" ")
        self:AddLine("ID: " .. id)
    end
    if source then
        local name = UnitName(source)
        if name then self:AddLine("Source: " .. name) end
    end
    self:Show()
end

--function MyAddon:Dummy()
--end
function MyAddon:GameTooltip_OnTooltipSetSpell(tooltipData)
    -- self = tooltip frame (from colon-notation implicit first param, NOT shadowed here)
    if MaxDpsOptions and MaxDpsOptions.global and not MaxDpsOptions.global.debugMode then return end
    if not self or not self.AddLine then return end
    local spellId = (self.GetSpell and select(2, self:GetSpell()))
        or (tooltipData and not MaxDps:issecretvalue(tooltipData.id) and tooltipData.id and tooltipData.id ~= 0 and tooltipData.id)
    if tooltipData and tooltipData.type == 25 then
        if tooltipData.lines and tooltipData.lines[1] and tooltipData.lines[1].tooltipType == 1 then
            spellId = tooltipData.lines[1].tooltipID or nil
        end
    end
    if not spellId then return end
    if not tooltipIDAdded and not TooltipHasIDLine(self) then
        self:AddLine("ID: " .. spellId)
        tooltipIDAdded = true
    end
end

function MyAddon:GameTooltip_OnTooltipSetItem(tooltipData)
    -- self = tooltip frame
    if MaxDpsOptions and MaxDpsOptions.global and not MaxDpsOptions.global.debugMode then return end
    if not self or not self.AddLine then return end
    local itemId = (tooltipData and tooltipData.id and tooltipData.id ~= 0 and tooltipData.id)
        or (self.GetItem and select(2, self:GetItem()) and tonumber(string.match(select(2, self:GetItem()) or "", "item:(%d+)")))
    if not itemId then return end
    if not tooltipIDAdded and not TooltipHasIDLine(self) then
        self:AddLine("ID: " .. itemId)
        tooltipIDAdded = true
    end
end

function MyAddon:GameTooltip_OnTooltipSetUnit(tooltipData)
    -- self = tooltip frame
    if MaxDpsOptions and MaxDpsOptions.global and not MaxDpsOptions.global.debugMode then return end
    if not self or not self.GetUnit then return end
    local unit = self:GetUnit()
    if unit then
        local guid = UnitGUID(unit)
        if guid then
            local id = tonumber(guid:match("-(%d+)$"))
            if id and not tooltipIDAdded and not TooltipHasIDLine(self) then
                self:AddLine("ID: " .. id)
                tooltipIDAdded = true
            end
        end
    end
end

function MyAddon:OnEnable()
    --hooksecurefunc(GameTooltip,"SetUnitAura",spellid)
    --hooksecurefunc(GameTooltip,"SetUnitBuff",spellid)
    --hooksecurefunc(GameTooltip,"SetUnitDebuff",spellid)
    --GameTooltip:HookScript("OnTooltipSetSpell",spellid)

    --MyAddon:SecureHook('SetItemRef', 'Dummy')
    --MyAddon:SecureHook('GameTooltip_SetDefaultAnchor', 'Dummy')
    --MyAddon:SecureHook('EmbeddedItemTooltip_SetItemByID', 'Dummy') --EmbeddedItemTooltip_ID
    --MyAddon:SecureHook('EmbeddedItemTooltip_SetCurrencyByID', 'Dummy') --EmbeddedItemTooltip_ID
    --MyAddon:SecureHook('EmbeddedItemTooltip_SetItemByQuestReward', 'Dummy') --EmbeddedItemTooltip_QuestReward

    -- Reset the flag after each tooltip population completes (hooksecurefunc fires after
    -- the original function AND all its post-call callbacks have finished).
    local function resetFlag() tooltipIDAdded = false end
    if GameTooltip.SetItem then hooksecurefunc(GameTooltip, "SetItem", resetFlag) end
    if GameTooltip.SetSpell then hooksecurefunc(GameTooltip, "SetSpell", resetFlag) end
    if GameTooltip.SetHyperlink then hooksecurefunc(GameTooltip, "SetHyperlink", resetFlag) end
    if GameTooltip.SetUnit then hooksecurefunc(GameTooltip, "SetUnit", resetFlag) end
    GameTooltip:HookScript("OnHide", resetFlag)

    MyAddon:SecureHook(GameTooltip, 'SetUnitAura')
    MyAddon:SecureHook(GameTooltip, 'SetUnitBuff', 'SetUnitAura')
    MyAddon:SecureHook(GameTooltip, 'SetUnitDebuff', 'SetUnitAura')
    --MyAddon:SecureHookScript(GameTooltip, 'OnTooltipCleared', 'GameTooltip_OnTooltipCleared')
    --MyAddon:SecureHookScript(GameTooltip.StatusBar, 'OnValueChanged', 'GameTooltipStatusBar_OnValueChanged')

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and not MaxDps.IsMistsWow() and not MaxDps.IsClassicWow() and not MaxDps:IsTBCWow() then -- exists but doesn't work atm on Cata
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, MyAddon.GameTooltip_OnTooltipSetSpell)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Macro, MyAddon.GameTooltip_OnTooltipSetSpell)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, MyAddon.GameTooltip_OnTooltipSetItem)
        --TooltipDataProcessor.AddTooltipPostCall(TooltipDataType.Unit, GameTooltip_OnTooltipSetUnit)
        --MyAddon:SecureHook(GameTooltip, 'Hide', 'GameTooltip_Hide') -- dont use OnHide use Hide directly
    else
        MyAddon:SecureHookScript(GameTooltip, 'OnTooltipSetSpell', MyAddon.GameTooltip_OnTooltipSetSpell)
        MyAddon:SecureHookScript(GameTooltip, 'OnTooltipSetItem', MyAddon.GameTooltip_OnTooltipSetItem)
        MyAddon:SecureHookScript(GameTooltip, 'OnTooltipSetUnit', MyAddon.GameTooltip_OnTooltipSetUnit)
        --MyAddon:SecureHookScript(E.SpellBookTooltip, 'OnTooltipSetSpell', MyAddon.GameTooltip_OnTooltipSetSpell)
        --if not MaxDps.IsClassicWow() then -- what's the replacement in DF
        --    MyAddon:SecureHook(GameTooltip, 'SetCurrencyTokenByID')
        --end
    end

    --if not MaxDps.IsClassicWow() then
    --MyAddon:SecureHook('BattlePetToolTip_Show', 'AddBattlePetID')
    --end
    --if MaxDps.IsRetailWow() then
    --RegisterEvent('WORLD_CURSOR_TOOLTIP_UPDATE', 'WorldCursorTooltipUpdate')
    --MyAddon:SecureHook('EmbeddedItemTooltip_SetSpellWithTextureByID', 'EmbeddedItemTooltip_ID')
    --MyAddon:SecureHook('EmbeddedItemTooltip_SetSpellByQuestReward', 'EmbeddedItemTooltip_QuestReward')
    --MyAddon:SecureHook(GameTooltip, 'SetToyByItemID')
    --MyAddon:SecureHook(GameTooltip, 'SetCurrencyToken')
    --MyAddon:SecureHook(GameTooltip, 'SetBackpackToken')
    --MyAddon:SecureHook('QuestMapLogTitleButton_OnEnter', 'AddQuestID')
    --MyAddon:SecureHook('TaskPOI_OnEnter', 'AddQuestID')
    --end
end