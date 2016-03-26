
local TDButton_Spells = {};
local TDButton_Flags = {};
local TDButton_SpellsGlowing = {};
TDButton_FramePool = {};
TDButton_Frames = {};

function TDButton_CreateOverlay(parent, id, texture, r, g, b)
	local frame = tremove(TDButton_FramePool);
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

	tinsert(TDButton_Frames, frame);
	return frame;
end

function TDButton_DestroyAllOverlays()
	local frame;
	for key, frame in pairs(TDButton_Frames) do
		frame:GetParent().tdOverlays = nil;
		frame:ClearAllPoints();
		frame:Hide();
		frame:SetParent(UIParent);
		frame.width = nil;
		frame.height = nil;
	end
	for key, frame in pairs(TDButton_Frames) do
		tinsert(TDButton_FramePool, frame);
		TDButton_Frames[key] = nil;
	end
end

----------------------------------------------
-- Show Overlay on button
----------------------------------------------
function TDButton_Glow(button, id, r, g, b, texture)
	if button.tdOverlays and button.tdOverlays[id] then
		button.tdOverlays[id]:Show();
	else
		if not button.tdOverlays then
			button.tdOverlays = {};
		end

		button.tdOverlays[id] = TDButton_CreateOverlay(button, id, texture, r, g, b);
		button.tdOverlays[id]:Show();
	end
end

----------------------------------------------
-- Hide Overlay on button
----------------------------------------------
function TDButton_HideGlow(button, id)
	if button.tdOverlays and button.tdOverlays[id] then
		button.tdOverlays[id]:Hide();
	end
end

----------------------------------------------
-- Fetch button spells
----------------------------------------------
function TDButton_Fetch()
	TDButton_GlowClear();
	TDButton_Spells = {};
	TDButton_Flags = {};
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
	print(_tdInfo .. TDDpsName .. ': Fetched action bars!');
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
		print(k, button);
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
-- Glow cooldown
----------------------------------------------
function TDButton_GlowCooldown(spell, condition)
	if TDButton_Flags[spell] == nil then
		TDButton_Flags[spell] = false;
	end
	if condition and not TDButton_Flags[spell] then
		TDButton_Flags[spell] = true;
		TDButton_GlowIndependent(spell, spell, 0, 1, 0);
	end
	if not condition and TDButton_Flags[spell] then
		TDButton_Flags[spell] = false;
		TDButton_ClearGlowIndependent(spell, spell);
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
-- Clear next spell glows
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