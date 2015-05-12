
local numtdOverlays = 0;
local TDActionSpells = {};
local TDActionSpellsGlowing = {};

----------------------------------------------
-- Show Overlay on button
----------------------------------------------
function TDActionButton_ShowOverlayGlow(self)
	if ( self.tdOverlay ) then
		self.tdOverlay:Show();
	else
		numtdOverlays = numtdOverlays + 1;
		self.tdOverlay = CreateFrame("Frame", "ActionButtonTdOverlay" .. numtdOverlays, UIParent);

		self.tdOverlay:SetParent(self);
		self.tdOverlay:SetFrameStrata("HIGH")
		self.tdOverlay:SetWidth(self:GetWidth() * 1.4) 
		self.tdOverlay:SetHeight(self:GetHeight() * 1.4)

		local t = self.tdOverlay:CreateTexture(nil,"OVERLAY")
		t:SetTexture("Interface\\Cooldown\\ping4")
		t:SetBlendMode("ADD");
		t:SetAllPoints(self.tdOverlay);
		self.tdOverlay.texture = t;

		self.tdOverlay:SetPoint("CENTER",0,0);
		self.tdOverlay:Show();
	end
end

----------------------------------------------
-- Hide Overlay on button
----------------------------------------------
function TDActionButton_HideOverlayGlow(self)
	if ( self.tdOverlay ) then
		self.tdOverlay:Hide();
	end
end


----------------------------------------------
-- Show Overlay on button
----------------------------------------------
function TDActionButton_Glow(self, id, r, g, b)
	if ( self.tdOverlays and self.tdOverlays[id] ) then
		self.tdOverlays[id]:Show();
	else
		if not self.tdOverlays then
			self.tdOverlays = {};
		end
		self.tdOverlays[id] = CreateFrame("Frame", "ActionButtonTdOverlays" .. id, UIParent);

		self.tdOverlays[id]:SetParent(self);
		self.tdOverlays[id]:SetFrameStrata("HIGH")
		self.tdOverlays[id]:SetWidth(self:GetWidth() * 1.4)
		self.tdOverlays[id]:SetHeight(self:GetHeight() * 1.4)

		local t = self.tdOverlays[id]:CreateTexture(nil, "OVERLAY")
		t:SetTexture("Interface\\Cooldown\\ping4")
		t:SetBlendMode("ADD");
		t:SetAllPoints(self.tdOverlays[id]);
		t:SetVertexColor(r or 1, g or 0, b or 0);
		self.tdOverlays[id].texture = t;

		self.tdOverlays[id]:SetPoint("CENTER",0,0);
		self.tdOverlays[id]:Show();
	end
end

----------------------------------------------
-- Hide Overlay on button
----------------------------------------------
function TDActionButton_HideGlow(self, id)
	if ( self.tdOverlays[id] ) then
		self.tdOverlays[id]:Hide();
	end
end

----------------------------------------------
-- Fetch button spells
----------------------------------------------
function TDFetchActions()
	TDGlowClear();
	TDActionSpells = {};
	TDActionSpellsGlowing = {};
	local isBartender = IsAddOnLoaded('Bartender4');
	local isElv = IsAddOnLoaded('ElvUI');

	if (isBartender) then
		TDFetchActionsBartender4();
	elseif (isElv) then
		TDFetchActionsElvUI();
	else
		TDFetchActionsBlizzard();
	end
	print('TDDps: fetched action bars!');
end

----------------------------------------------
-- Button spells on original blizzard UI
----------------------------------------------
function TDFetchActionsBlizzard()
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
                if TDActionSpells[actionName] == nil then
                   TDActionSpells[actionName] = {};
                end

                tinsert(TDActionSpells[actionName], button);
             end
          end
       end
    end
end

----------------------------------------------
-- Button spells on ElvUI
----------------------------------------------
function TDFetchActionsElvUI()
	local ret = false;
	for x = 1, 10 do
		for i = 1, 12 do
			local button = _G['ElvUI_Bar' .. x .. 'Button' .. i];
			if button then
				local spellId = button:GetSpellId();
				if spellId then
					local actionName, _ = GetSpellInfo(spellId);
					if actionName then
						if TDActionSpells[actionName] == nil then
							TDActionSpells[actionName] = {};
						end
						ret = true;
						tinsert(TDActionSpells[actionName], button);
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
function TDFetchActionsBartender4()
	local ret = false;
	for i = 1, 120 do
		local button = _G['BT4Button' .. i];
		if button then
			local spellId = button:GetSpellId();
			if spellId then
				local actionName, _ = GetSpellInfo(spellId);
				print(actionName, spellId);
				if actionName then
					if TDActionSpells[actionName] == nil then
						TDActionSpells[actionName] = {};
					end
					ret = true;
					tinsert(TDActionSpells[actionName], button);
				end
			end
		end
	end
	return ret;
end

----------------------------------------------
-- Dump spells for debug
----------------------------------------------
function TDDumpSpells() 
	for k, button in pairs(TDActionSpells) do
		print(k, button:GetName());
	end
end

----------------------------------------------
-- Glow spell by id
----------------------------------------------
function TDGlowSpellId(spellId)
	local name = GetSpellInfo(spellId);
    TDGlowSpell(name);
end

----------------------------------------------
-- Glow independent button by spell name
----------------------------------------------
function TDGlowIndependent(spellName, id, r, g, b)
	local name = GetSpellInfo(spellName) or spellName;
	if TDActionSpells[name] ~= nil then
		for k, button in pairs(TDActionSpells[name]) do
			TDActionButton_Glow(button, id, r, g, b);
		end
	end
end

----------------------------------------------
-- Clear glow independent button by spell name
----------------------------------------------
function TDClearGlowIndependent(spellName, id)
	local name = GetSpellInfo(spellName) or spellName;
	for k, button in pairs(TDActionSpells[name]) do
		TDActionButton_HideGlow(button, id);
	end
end

----------------------------------------------
-- Glow spell by name
----------------------------------------------
function TDGlowSpell(spellName)
    if TDActionSpells[spellName] ~= nil then
        for k, button in pairs(TDActionSpells[spellName]) do
            TDActionButton_ShowOverlayGlow(button);
        end
        TDActionSpellsGlowing[spellName] = 1;
    end
end

----------------------------------------------
-- Glow next spell by name
----------------------------------------------
function TDGlowNextSpell(spellName)
    TDGlowClear();
    TDGlowSpell(spellName);
end

----------------------------------------------
-- Glow next spell by id
----------------------------------------------
function TDGlowNextSpellId(spellId)
	local spellName = GetSpellInfo(spellId);
    TDGlowClear();
    TDGlowSpell(spellName);
end

----------------------------------------------
-- Clear all spell glows
----------------------------------------------
function TDGlowClear()
    for spellName, v in pairs(TDActionSpellsGlowing) do
        if v == 1 then 
            for k, button in pairs(TDActionSpells[spellName]) do
                TDActionButton_HideOverlayGlow(button);
            end
            TDActionSpellsGlowing[spellName] = 0;
        end
    end
end

----------------------------------------------
-- Frame init
----------------------------------------------
local TDButtonsFrame = CreateFrame("FRAME", "TDButtonsFrame");
TDButtonsFrame:RegisterEvent("PLAYER_ENTERING_WORLD");

local function eventHandler(self, event, ...)
	TDFetchActions();
end

TDButtonsFrame:SetScript("OnEvent", eventHandler);