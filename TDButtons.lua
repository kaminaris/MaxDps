TDButton = {};
TDButton.Spells = {};
TDButton.Flags = {};
TDButton.SpellsGlowing = {};
TDButton.FramePool = {};
TDButton.Frames = {};

function TDButton.CreateOverlay(parent, id, texture, r, g, b)
	local frame = tremove(TDButton.FramePool);
	if not frame then
		frame = CreateFrame('Frame', 'TDButton_Overlay_' .. id, parent);
	else
--		frame:SetAttribute('name', 'TDButton_Overlay_' .. id);
	end

	frame:SetParent(parent);
	frame:SetFrameStrata('HIGH');
	frame:SetPoint('CENTER', 0, 0);
	frame:SetWidth(parent:GetWidth() * 1.4);
	frame:SetHeight(parent:GetHeight() * 1.4);

	local t = frame.texture;
	if not t then
		t = frame:CreateTexture('GlowOverlay', 'OVERLAY');
		t:SetTexture(texture or TDDps_Options_GetTexture());
		t:SetBlendMode('ADD');
		frame.texture = t;
	end

	t:SetAllPoints(frame);
	t:SetVertexColor(
		r or TDDps_Options.highlightColor.r,
		g or TDDps_Options.highlightColor.g,
		b or TDDps_Options.highlightColor.b,
		TDDps_Options.highlightColor.a
	);

	tinsert(TDButton.Frames, frame);
	return frame;
end

function TDButton.DestroyAllOverlays()
	local frame;
	for key, frame in pairs(TDButton.Frames) do
		frame:GetParent().tdOverlays = nil;
		frame:ClearAllPoints();
		frame:Hide();
		frame:SetParent(UIParent);
		frame.width = nil;
		frame.height = nil;
	end
	for key, frame in pairs(TDButton.Frames) do
		tinsert(TDButton.FramePool, frame);
		TDButton.Frames[key] = nil;
	end
end

function TDButton.UpdateButtonGlow()
	local LAB;
	local LBG;
	local origShow;
	local noFunction = function() end;

	if IsAddOnLoaded('ElvUI') then
		LAB = LibStub:GetLibrary('LibActionButton-1.0-ElvUI');
		LBG = LibStub:GetLibrary('LibButtonGlow-1.0');
		origShow = LBG.ShowOverlayGlow;
	elseif IsAddOnLoaded('Bartender4') then
		LAB = LibStub:GetLibrary('LibActionButton-1.0');
	end

	if TDDps_Options.disableButtonGlow then
		ActionBarActionEventsFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW');
		if LAB then
			LAB.eventFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW');
		end

		if LBG then
			LBG.ShowOverlayGlow = noFunction;
		end
	else
		ActionBarActionEventsFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW');
		if LAB then
			LAB.eventFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW');
		end

		if LBG then
			LBG.ShowOverlayGlow = origShow;
		end
	end
end

----------------------------------------------
-- Show Overlay on button
----------------------------------------------
function TDButton.Glow(button, id, r, g, b, texture)
	if button.tdOverlays and button.tdOverlays[id] then
		button.tdOverlays[id]:Show();
	else
		if not button.tdOverlays then
			button.tdOverlays = {};
		end

		button.tdOverlays[id] = TDButton.CreateOverlay(button, id, texture, r, g, b);
		button.tdOverlays[id]:Show();
	end
end

----------------------------------------------
-- Hide Overlay on button
----------------------------------------------
function TDButton.HideGlow(button, id)
	if button.tdOverlays and button.tdOverlays[id] then
		button.tdOverlays[id]:Hide();
	end
end

----------------------------------------------
-- Fetch button spells
----------------------------------------------
function TDButton.Fetch()
	local origEna = TDDps.rotationEnabled;
	TDDps.rotationEnabled = false;
	TDDps.Spell = nil;

	TDButton.GlowClear();
	TDButton.Spells = {};
	TDButton.Flags = {};
	TDButton.SpellsGlowing = {};
	local isBartender = IsAddOnLoaded('Bartender4');
	local isElv = IsAddOnLoaded('ElvUI');
	local isSv = IsAddOnLoaded('SVUI_ActionBars');

	if (isBartender) then
		TDButton.FetchBartender4();
	elseif (isElv) then
		TDButton.FetchElvUI();
	elseif (isSv) then
		TDButton.FetchSuperVillain();
	else
		TDButton.FetchBlizzard();
	end

	-- It does not alter original button frames so it needs to be fetched too
	if IsAddOnLoaded('ButtonForge') then
		TDButton.FetchButtonForge();
	end

	TDDps.rotationEnabled = origEna;
	TDDps:Print(_tdInfo, 'Fetched action bars!');
	-- after fetching invoke spell check
	if TDDps.rotationEnabled then
		TDDps:InvokeNextSpell();
	end
end

----------------------------------------------
-- Button spells on original blizzard UI
----------------------------------------------
function TDButton.FetchBlizzard()
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
					if TDButton.Spells[actionName] == nil then
						TDButton.Spells[actionName] = {};
					end

					tinsert(TDButton.Spells[actionName], button);
				end
			end
		end
	end
end

----------------------------------------------
-- Button spells on original button forge
----------------------------------------------
function TDButton.FetchButtonForge()
	local i = 1;
	while true do
		local button = _G['ButtonForge' .. i];
		if not button then
			break;
		end
		i = i + 1;

		local type = button:GetAttribute('type');
		if type then
			local actionType = button:GetAttribute(type);
			local id;
			local actionName;
			if type == 'macro' then
				local id = GetMacroSpell(actionType);
				if id then
					actionName = GetSpellInfo(id);
				end
			elseif type == 'item' then
				actionName = GetItemInfo(actionType);
			elseif type == 'spell' then
				actionName = GetSpellInfo(actionType);
			end
			if actionName then
				if TDButton.Spells[actionName] == nil then
					TDButton.Spells[actionName] = {};
				end

				tinsert(TDButton.Spells[actionName], button);
			end
		end
	end
end

----------------------------------------------
-- Button spells on ElvUI
----------------------------------------------
function TDButton.FetchElvUI()
	local ret = false;
	for x = 1, 10 do
		for i = 1, 12 do
			local button = _G['ElvUI_Bar' .. x .. 'Button' .. i];
			if button then
				local spellId = button:GetSpellId();
				if spellId then
					local actionName, _ = GetSpellInfo(spellId);
					if actionName then
						if TDButton.Spells[actionName] == nil then
							TDButton.Spells[actionName] = {};
						end
						ret = true;
						tinsert(TDButton.Spells[actionName], button);
					end
				end
			end
		end
	end
	return ret;
end

----------------------------------------------
-- Button spells on SuperVillain
----------------------------------------------
function TDButton.FetchSuperVillain()
	local ret = false;
	for x = 1, 10 do
		for i = 1, 12 do
			local button = _G['SVUI_ActionBar' .. x .. 'Button' .. i];
			if button then
				local spellId = button:GetSpellId();
				if spellId then
					local actionName, _ = GetSpellInfo(spellId);
					if actionName then
						if TDButton.Spells[actionName] == nil then
							TDButton.Spells[actionName] = {};
						end
						ret = true;
						tinsert(TDButton.Spells[actionName], button);
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
function TDButton.FetchBartender4()
	local ret = false;
	for i = 1, 120 do
		local button = _G['BT4Button' .. i];
		if button then
			local spellId = button:GetSpellId();
			if spellId then
				local actionName, _ = GetSpellInfo(spellId);
				if actionName then
					if TDButton.Spells[actionName] == nil then
						TDButton.Spells[actionName] = {};
					end
					ret = true;
					tinsert(TDButton.Spells[actionName], button);
				end
			end
		end
	end
	return ret;
end

----------------------------------------------
-- Dump spells for debug
----------------------------------------------
function TDButton.Dump()
	local s = '';
	for k, v in pairs(TDButton.Spells) do
		s = s .. ', ' .. k;
	end
	print(s);
end

----------------------------------------------
-- Find button on action bars
----------------------------------------------
function TDButton.FindSpell(spellName)
	local name = GetSpellInfo(spellName) or spellName;
	return TDButton.Spells[name];
end

----------------------------------------------
-- Glow independent button by spell name
----------------------------------------------
function TDButton.GlowIndependent(spellName, id, r, g, b, texture)
	local name = GetSpellInfo(spellName) or spellName;
	if TDButton.Spells[name] ~= nil then
		for k, button in pairs(TDButton.Spells[name]) do
			TDButton.Glow(button, id, r, g, b, texture);
		end
	end
end

----------------------------------------------
-- Clear glow independent button by spell name
----------------------------------------------
function TDButton.ClearGlowIndependent(spellName, id)
	local name = GetSpellInfo(spellName) or spellName;
	if TDButton.Spells[name] ~= nil then
		for k, button in pairs(TDButton.Spells[name]) do
			TDButton.HideGlow(button, id);
		end
	end
end

----------------------------------------------
-- Glow cooldown
----------------------------------------------
function TDButton.GlowCooldown(spell, condition)
	if TDButton.Flags[spell] == nil then
		TDButton.Flags[spell] = false;
	end
	if condition and not TDButton.Flags[spell] then
		TDButton.Flags[spell] = true;
		TDButton.GlowIndependent(spell, spell, 0, 1, 0);
	end
	if not condition and TDButton.Flags[spell] then
		TDButton.Flags[spell] = false;
		TDButton.ClearGlowIndependent(spell, spell);
	end
end

function TDButton_GlowCooldown(spell, condition)
	TDButton.GlowCooldown(spell, condition);
end
----------------------------------------------
-- Glow spell by name
----------------------------------------------
function TDButton.GlowSpell(spellName)
	if TDButton.Spells[spellName] ~= nil then
		for k, button in pairs(TDButton.Spells[spellName]) do
			TDButton.Glow(button, 'next');
		end
		TDButton.SpellsGlowing[spellName] = 1;
	else
		TDDps:Print(_tdError, 'Spell not found on action bars: ' .. spellName);
	end
end

----------------------------------------------
-- Glow spell by id
----------------------------------------------
function TDButton.GlowSpellId(spellId)
	local name = GetSpellInfo(spellId);
	TDButton.GlowSpell(name);
end

----------------------------------------------
-- Glow next spell by name
----------------------------------------------
function TDButton.GlowNextSpell(spellName)
	TDButton.GlowClear();
	TDButton.GlowSpell(spellName);
end

----------------------------------------------
-- Glow next spell by id
----------------------------------------------
function TDButton.GlowNextSpellId(spellId)
	local spellName = GetSpellInfo(spellId);
	TDButton.GlowClear();
	TDButton.GlowSpell(spellName);
end

----------------------------------------------
-- Clear next spell glows
----------------------------------------------
function TDButton.GlowClear()
	for spellName, v in pairs(TDButton.SpellsGlowing) do
		if v == 1 then
			for k, button in pairs(TDButton.Spells[spellName]) do
				TDButton.HideGlow(button, 'next');
			end
			TDButton.SpellsGlowing[spellName] = 0;
		end
	end
end