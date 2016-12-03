MaxDps.Spells = {};
MaxDps.Flags = {};
MaxDps.SpellsGlowing = {};
MaxDps.FramePool = {};
MaxDps.Frames = {};

function MaxDps:CreateOverlay(parent, id, texture, r, g, b)
	local frame = tremove(self.FramePool);
	if not frame then
		frame = CreateFrame('Frame', 'MaxDps_Overlay_' .. id, parent);
	end

	frame:SetParent(parent);
	frame:SetFrameStrata('HIGH');
	frame:SetPoint('CENTER', 0, 0);
	frame:SetWidth(parent:GetWidth() * 1.4);
	frame:SetHeight(parent:GetHeight() * 1.4);

	local t = frame.texture;
	if not t then
		t = frame:CreateTexture('GlowOverlay', 'OVERLAY');
		t:SetTexture(texture or MaxDps:GetTexture());
		t:SetBlendMode('ADD');
		frame.texture = t;
	end

	t:SetAllPoints(frame);
	t:SetVertexColor(
		r or self.db.global.highlightColor.r,
		g or self.db.global.highlightColor.g,
		b or self.db.global.highlightColor.b,
		self.db.global.highlightColor.a
	);

	tinsert(self.Frames, frame);
	return frame;
end

function MaxDps:DestroyAllOverlays()
	local frame;
	for key, frame in pairs(self.Frames) do
		frame:GetParent().MaxDpsOverlays = nil;
		frame:ClearAllPoints();
		frame:Hide();
		frame:SetParent(UIParent);
		frame.width = nil;
		frame.height = nil;
	end
	for key, frame in pairs(self.Frames) do
		tinsert(self.FramePool, frame);
		self.Frames[key] = nil;
	end
end

function MaxDps:UpdateButtonGlow()
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

	if self.db.global.disableButtonGlow then
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

function MaxDps:Glow(button, id, r, g, b, texture)
	if button.MaxDpsOverlays and button.MaxDpsOverlays[id] then
		button.MaxDpsOverlays[id]:Show();
	else
		if not button.MaxDpsOverlays then
			button.MaxDpsOverlays = {};
		end

		button.MaxDpsOverlays[id] = self:CreateOverlay(button, id, texture, r, g, b);
		button.MaxDpsOverlays[id]:Show();
	end
end

function MaxDps:HideGlow(button, id)
	if button.MaxDpsOverlays and button.MaxDpsOverlays[id] then
		button.MaxDpsOverlays[id]:Hide();
	end
end

function MaxDps:Fetch()
	self = MaxDps;
	if self.rotationEnabled then
		self:DisableRotationTimer();
	end
	self.Spell = nil;

	self:GlowClear();
	self.Spells = {};
	self.Flags = {};
	self.SpellsGlowing = {};
	local isBartender = IsAddOnLoaded('Bartender4');
	local isElv = IsAddOnLoaded('ElvUI');
	local isSv = IsAddOnLoaded('SVUI_ActionBars');

	if (isBartender) then
		self:FetchBartender4();
	elseif (isElv) then
		self:FetchElvUI();
	elseif (isSv) then
		self:FetchSuperVillain();
	else
		self:FetchBlizzard();
	end

	-- It does not alter original button frames so it needs to be fetched too
	if IsAddOnLoaded('ButtonForge') then
		self:FetchButtonForge();
	end

	if self.rotationEnabled then
		self:EnableRotationTimer();
		self:InvokeNextSpell();
	end
end

function MaxDps:FetchBlizzard()
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
					if self.Spells[actionName] == nil then
						self.Spells[actionName] = {};
					end

					tinsert(self.Spells[actionName], button);
				end
			end
		end
	end
end

function MaxDps:FetchButtonForge()
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
				if self.Spells[actionName] == nil then
					self.Spells[actionName] = {};
				end

				tinsert(self.Spells[actionName], button);
			end
		end
	end
end

function MaxDps:FetchElvUI()
	local ret = false;
	for x = 1, 10 do
		for i = 1, 12 do
			local button = _G['ElvUI_Bar' .. x .. 'Button' .. i];
			if button then
				local spellId = button:GetSpellId();
				if spellId then
					local actionName, _ = GetSpellInfo(spellId);
					if actionName then
						if self.Spells[actionName] == nil then
							self.Spells[actionName] = {};
						end
						ret = true;
						tinsert(self.Spells[actionName], button);
					end
				end
			end
		end
	end
	return ret;
end

function MaxDps:FetchSuperVillain()
	local ret = false;
	for x = 1, 10 do
		for i = 1, 12 do
			local button = _G['SVUI_ActionBar' .. x .. 'Button' .. i];
			if button then
				local spellId = button:GetSpellId();
				if spellId then
					local actionName, _ = GetSpellInfo(spellId);
					if actionName then
						if self.Spells[actionName] == nil then
							self.Spells[actionName] = {};
						end
						ret = true;
						tinsert(self.Spells[actionName], button);
					end
				end
			end
		end
	end
	return ret;
end

function MaxDps:FetchBartender4()
	local ret = false;
	for i = 1, 120 do
		local button = _G['BT4Button' .. i];
		if button then
			local spellId = button:GetSpellId();
			if spellId then
				local actionName, _ = GetSpellInfo(spellId);
				if actionName then
					if self.Spells[actionName] == nil then
						self.Spells[actionName] = {};
					end
					ret = true;
					tinsert(self.Spells[actionName], button);
				end
			end
		end
	end
	return ret;
end

function MaxDps:Dump()
	local s = '';
	for k, v in pairs(self.Spells) do
		s = s .. ', ' .. k;
	end
	print(s);
end

function MaxDps:FindSpell(spellName)
	local name = GetSpellInfo(spellName) or spellName;
	return self.Spells[name];
end

function MaxDps:GlowIndependent(spellName, id, r, g, b, texture)
	local name = GetSpellInfo(spellName) or spellName;
	if self.Spells[name] ~= nil then
		for k, button in pairs(self.Spells[name]) do
			self:Glow(button, id, r, g, b, texture);
		end
	end
end

function MaxDps:ClearGlowIndependent(spellName, id)
	local name = GetSpellInfo(spellName) or spellName;
	if self.Spells[name] ~= nil then
		for k, button in pairs(self.Spells[name]) do
			self:HideGlow(button, id);
		end
	end
end

function MaxDps:GlowCooldown(spell, condition)
	if self.Flags[spell] == nil then
		self.Flags[spell] = false;
	end
	if condition and not self.Flags[spell] then
		self.Flags[spell] = true;
		self:GlowIndependent(spell, spell, 0, 1, 0);
	end
	if not condition and self.Flags[spell] then
		self.Flags[spell] = false;
		self:ClearGlowIndependent(spell, spell);
	end
end

function MaxDps:GlowSpell(spellName)
	if self.Spells[spellName] ~= nil then
		for k, button in pairs(self.Spells[spellName]) do
			self:Glow(button, 'next');
		end
		self.SpellsGlowing[spellName] = 1;
	else
		self:Print(self.Colors.Error .. 'Spell not found on action bars: ' .. spellName);
	end
end

function MaxDps:GlowSpellId(spellId)
	local name = GetSpellInfo(spellId);
	self:GlowSpell(name);
end

function MaxDps:GlowNextSpell(spellName)
	self:GlowClear();
	self:GlowSpell(spellName);
end

function MaxDps:GlowNextSpellId(spellId)
	local spellName = GetSpellInfo(spellId);
	self:GlowClear();
	self:GlowSpell(spellName);
end

function MaxDps:GlowClear()
	for spellName, v in pairs(self.SpellsGlowing) do
		if v == 1 then
			for k, button in pairs(self.Spells[spellName]) do
				self:HideGlow(button, 'next');
			end
			self.SpellsGlowing[spellName] = 0;
		end
	end
end