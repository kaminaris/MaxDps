
local TDButton_Spells = {};
local TDButton_SpellsGlowing = {};

----------------------------------------------
-- Show Overlay on button
----------------------------------------------
function TDButton_Glow(self, id, r, g, b, texture)
	if (self.tdOverlays and self.tdOverlays[id]) then
		self.tdOverlays[id]:Show();
	else
		if not self.tdOverlays then
			self.tdOverlays = {};
		end
		texture = texture or 'Interface\\Cooldown\\ping4';
		self.tdOverlays[id] = CreateFrame('Frame', 'TDButton_Overlay_' .. id, UIParent);

		self.tdOverlays[id]:SetParent(self);
		self.tdOverlays[id]:SetFrameStrata('HIGH')
		self.tdOverlays[id]:SetWidth(self:GetWidth() * 1.4)
		self.tdOverlays[id]:SetHeight(self:GetHeight() * 1.4)

		local t = self.tdOverlays[id]:CreateTexture(nil, 'OVERLAY')
		t:SetTexture(texture)
		t:SetBlendMode('ADD');
		t:SetAllPoints(self.tdOverlays[id]);
		t:SetVertexColor(r or 1, g or 1, b or 1);
		self.tdOverlays[id].texture = t;

		self.tdOverlays[id]:SetPoint('CENTER',0,0);
		self.tdOverlays[id]:Show();
	end
end

----------------------------------------------
-- Hide Overlay on button
----------------------------------------------
function TDButton_HideGlow(self, id)
	if (self.tdOverlays[id]) then
		self.tdOverlays[id]:Hide();
	end
end

----------------------------------------------
-- Fetch button spells
----------------------------------------------
function TDButton_Fetch()
	TDButton_GlowClear();
	TDButton_Spells = {};
	TDButton_SpellsGlowing = {};
	local isBartender = IsAddOnLoaded('Bartender4');
	local isElv = IsAddOnLoaded('ElvUI');

	if (isBartender) then
		TDButton_FetchBartender4();
	elseif (isElv) then
		TDButton_FetchElvUI();
	else
		TDButton_FetchBlizzard();
	end
	print('TDDps: fetched action bars!');
end

----------------------------------------------
-- Button spells on original blizzard UI
----------------------------------------------
function TDButton_FetchBlizzard()
	local TDActionBarsBlizzard = {'Action', 'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft'};
    for _, barName in pairs(TDActionBarsBlizzard) do
       for i = 1, 12 do
          local button = _G[barName .. 'Button' .. i];
          local slot = ActionButton_GetPagedID(button) or ActionButton_CalculateAction(button) or button:GetAttribute('action') or 0;
          if HasAction(slot) then
             local actionName, _;
             local actionType, id = GetActionInfo(slot);
             if actionType == 'macro' then _, _ , id = GetMacroSpell(id) end
             if actionType == 'item' then
                actionName = GetItemInfo(id);
             elseif actionType == 'spell' or (actionType == 'macro' and id) then
                actionName = GetSpellInfo(id);
             end
             if actionName then
                if TDButton_Spells[actionName] == nil then
                   TDButton_Spells[actionName] = {};
                end

                tinsert(TDButton_Spells[actionName], button);
             end
          end
       end
    end
end

----------------------------------------------
-- Button spells on ElvUI
----------------------------------------------
function TDButton_FetchElvUI()
	local ret = false;
	for x = 1, 10 do
		for i = 1, 12 do
			local button = _G['ElvUI_Bar' .. x .. 'Button' .. i];
			if button then
				local spellId = button:GetSpellId();
				if spellId then
					local actionName, _ = GetSpellInfo(spellId);
					if actionName then
						if TDButton_Spells[actionName] == nil then
							TDButton_Spells[actionName] = {};
						end
						ret = true;
						tinsert(TDButton_Spells[actionName], button);
					end
				end
			end
		end
	end
	return ret;
end

----------------------------------------------
-- Button spells on Bartender4
----------------------------------------------
function TDButton_FetchBartender4()
	local ret = false;
	for i = 1, 120 do
		local button = _G['BT4Button' .. i];
		if button then
			local spellId = button:GetSpellId();
			if spellId then
				local actionName, _ = GetSpellInfo(spellId);
				print(actionName, spellId);
				if actionName then
					if TDButton_Spells[actionName] == nil then
						TDButton_Spells[actionName] = {};
					end
					ret = true;
					tinsert(TDButton_Spells[actionName], button);
				end
			end
		end
	end
	return ret;
end

----------------------------------------------
-- Dump spells for debug
----------------------------------------------
function TDButton_Dump() 
	for k, button in pairs(TDButton_Spells) do
		print(k, button:GetName());
	end
end

----------------------------------------------
-- Glow independent button by spell name
----------------------------------------------
function TDButton_GlowIndependent(spellName, id, r, g, b, texture)
	local name = GetSpellInfo(spellName) or spellName;
	if TDButton_Spells[name] ~= nil then
		for k, button in pairs(TDButton_Spells[name]) do
			TDButton_Glow(button, id, r, g, b, texture);
		end
	end
end

----------------------------------------------
-- Clear glow independent button by spell name
----------------------------------------------
function TDButton_ClearGlowIndependent(spellName, id)
	local name = GetSpellInfo(spellName) or spellName;
	if TDButton_Spells[name] ~= nil then
		for k, button in pairs(TDButton_Spells[name]) do
			TDButton_HideGlow(button, id);
		end
	end
end

----------------------------------------------
-- Glow spell by name
----------------------------------------------
function TDButton_GlowSpell(spellName)
	if TDButton_Spells[spellName] ~= nil then
		for k, button in pairs(TDButton_Spells[spellName]) do
			TDButton_Glow(button, 'next');
		end
		TDButton_SpellsGlowing[spellName] = 1;
	end
end

----------------------------------------------
-- Glow spell by id
----------------------------------------------
function TDButton_GlowSpellId(spellId)
	local name = GetSpellInfo(spellId);
	TDButton_GlowSpell(name);
end

----------------------------------------------
-- Glow next spell by name
----------------------------------------------
function TDButton_GlowNextSpell(spellName)
    TDButton_GlowClear();
    TDButton_GlowSpell(spellName);
end

----------------------------------------------
-- Glow next spell by id
----------------------------------------------
function TDButton_GlowNextSpellId(spellId)
	local spellName = GetSpellInfo(spellId);
    TDButton_GlowClear();
    TDButton_GlowSpell(spellName);
end

----------------------------------------------
-- Clear all spell glows
----------------------------------------------
function TDButton_GlowClear()
    for spellName, v in pairs(TDButton_SpellsGlowing) do
        if v == 1 then 
            for k, button in pairs(TDButton_Spells[spellName]) do
                TDButton_HideGlow(button, 'next');
            end
            TDButton_SpellsGlowing[spellName] = 0;
        end
    end
end

----------------------------------------------
-- Frame init
----------------------------------------------
local TDButton_Frame = CreateFrame('FRAME', 'TDButton_Frame');
TDButton_Frame:RegisterEvent('PLAYER_ENTERING_WORLD');

local function TDButton_EventHandler(self, event, ...)
	TDButton_Fetch();
end

TDButton_Frame:SetScript('OnEvent', TDButton_EventHandler);