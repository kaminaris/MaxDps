-- create an addon with AceHook embeded
local MyAddon = LibStub("AceAddon-3.0"):NewAddon("MaxDpsHookDemo", "AceHook-3.0")
local UnitAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex or UnitAura -- use C_UnitAuras if available

function MyAddon:SetUnitAura(self,unit,index,filter)
    local _,id, source
    if unit then
        -- print(UnitAura(unit,index,filter))
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
            if aura then
                id = aura.spellId
                source = aura.sourceUnit
            end
        else
            _,_,_,_,_,_,source,_,_,id=UnitAura(unit,index,filter)
        end
    else
        if self.GetSpell then
            _,id=self:GetSpell()
        end
    end
    if id then
        self:AddLine(" ")
        self:AddLine("ID: "..id)
    end
    if source then
        local name = UnitName(source)
        if name then self:AddLine("Source: " .. name) end
    end
    self:Show()
end

--function MyAddon:Dummy()
--end
function MyAddon:GameTooltip_OnTooltipSetSpell(self)
    local spellId = self.GetSpell and self:GetSpell() or self.id and self.id ~= 0 and self.id
    if self.type and self.type == 25 then
        if self.lines and self.lines[1] and self.lines[1] and self.lines[1].tooltipType == 1 then
            spellId = self.lines[1].tooltipID or nil
        end
    end
    if not spellId then return end
    if spellId then
        GameTooltip:AddLine("ID: " .. spellId)
    end
end
function MyAddon:GameTooltip_OnTooltipSetItem(self)
    maxdpstest = self
    local itemId = self.GetItem and self:GetItem() or self.id and self.id ~= 0 and self.id
    if itemId then
        GameTooltip:AddLine("ID: " .. itemId)
    end
end
function MyAddon:GameTooltip_OnTooltipSetUnit(self)
    local unit = self:GetUnit()
    if unit then
        local guid = UnitGUID(unit)
        if guid then
            local id = tonumber(guid:match("-(%d+)$"))
            if id then
                GameTooltip:AddLine("ID: " .. id)
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
    MyAddon:SecureHook(GameTooltip, 'SetUnitAura')
    MyAddon:SecureHook(GameTooltip, 'SetUnitBuff', 'SetUnitAura')
    MyAddon:SecureHook(GameTooltip, 'SetUnitDebuff', 'SetUnitAura')
    --MyAddon:SecureHookScript(GameTooltip, 'OnTooltipCleared', 'GameTooltip_OnTooltipCleared')
    --MyAddon:SecureHookScript(GameTooltip.StatusBar, 'OnValueChanged', 'GameTooltipStatusBar_OnValueChanged')

    if TooltipDataProcessor.AddTooltipPostCall and not MaxDps.IsMistsWow() then -- exists but doesn't work atm on Cata
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, MyAddon.GameTooltip_OnTooltipSetSpell)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Macro, MyAddon.GameTooltip_OnTooltipSetSpell)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, MyAddon.GameTooltip_OnTooltipSetItem)
        --TooltipDataProcessor.AddTooltipPostCall(TooltipDataType.Unit, GameTooltip_OnTooltipSetUnit)
        --MyAddon:SecureHook(GameTooltip, 'Hide', 'GameTooltip_Hide') -- dont use OnHide use Hide directly
    else
        MyAddon:SecureHookScript(GameTooltip, 'OnTooltipSetSpell', MyAddon.GameTooltip_OnTooltipSetSpell)
        MyAddon:SecureHookScript(GameTooltip, 'OnTooltipSetItem', MyAddon.GameTooltip_OnTooltipSetItem)
        MyAddon:SecureHookScript(GameTooltip, 'OnTooltipSetUnit', MyAddon.GameTooltip_OnTooltipSetUnit)
        MyAddon:SecureHookScript(E.SpellBookTooltip, 'OnTooltipSetSpell', MyAddon.GameTooltip_OnTooltipSetSpell)
        --if not MaxDps.IsClassicWow() then -- what's the replacement in DF
        --    MyAddon:SecureHook(GameTooltip, 'SetCurrencyTokenByID')
        --end
    end

    --if not MaxDps.IsClassicWow() then
    --	MyAddon:SecureHook('BattlePetToolTip_Show', 'AddBattlePetID')
    --end
    --if MaxDps.IsRetailWow() then
    --	RegisterEvent('WORLD_CURSOR_TOOLTIP_UPDATE', 'WorldCursorTooltipUpdate')
    --	MyAddon:SecureHook('EmbeddedItemTooltip_SetSpellWithTextureByID', 'EmbeddedItemTooltip_ID')
    --	MyAddon:SecureHook('EmbeddedItemTooltip_SetSpellByQuestReward', 'EmbeddedItemTooltip_QuestReward')
    --	MyAddon:SecureHook(GameTooltip, 'SetToyByItemID')
    --	MyAddon:SecureHook(GameTooltip, 'SetCurrencyToken')
    --	MyAddon:SecureHook(GameTooltip, 'SetBackpackToken')
    --	MyAddon:SecureHook('QuestMapLogTitleButton_OnEnter', 'AddQuestID')
    --	MyAddon:SecureHook('TaskPOI_OnEnter', 'AddQuestID')
    --end
end