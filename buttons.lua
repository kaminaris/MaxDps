MaxDps.Spells = {};
MaxDps.Flags = {};
MaxDps.SpellsGlowing = {};
MaxDps.FramePool = {};
MaxDps.Frames = {};

--- Creates frame overlay over a specific frame, it doesn't need to be a button.
-- @param parent - frame that is suppose to be attached to
-- @param id - string id of overlay because frame can have multiple overlays
-- @param texture - optional custom texture
-- @param type - optional type of overlay, standard types are 'normal' and 'cooldown' - used to select overlay color
-- @param color - optional custom color in standard structure {r = 1, g = 1, b = 1, a = 1}
function MaxDps:CreateOverlay(parent, id, texture, type, color)
	local frame = tremove(self.FramePool);
	if not frame then
		frame = CreateFrame('Frame', 'MaxDps_Overlay_' .. id, parent);
	end

	local sizeMult = self.db.global.sizeMult or 1.4;
	frame:SetParent(parent);
	frame:SetFrameStrata('HIGH');
	frame:SetPoint('CENTER', 0, 0);
	frame:SetWidth(parent:GetWidth() * sizeMult);
	frame:SetHeight(parent:GetHeight() * sizeMult);

	local t = frame.texture;
	if not t then
		t = frame:CreateTexture('GlowOverlay', 'OVERLAY');
		t:SetTexture(texture or MaxDps:GetTexture());
		t:SetBlendMode('ADD');
		frame.texture = t;
	end

	t:SetAllPoints(frame);

	if type then
		frame.ovType = type;
		if type == 'normal' then
			local c = self.db.global.highlightColor;
			t:SetVertexColor(c.r, c.g, c.b, c.a);
		elseif type == 'cooldown' then
			local c = self.db.global.cooldownColor;
			t:SetVertexColor(c.r, c.g, c.b, c.a);
		else
			t:SetVertexColor(color.r, color.r, color.r, color.r);
		end
	else
		t:SetVertexColor(color.r, color.g, color.b, color.a);
	end

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

function MaxDps:ApplyOverlayChanges()
	for key, frame in pairs(self.Frames) do
		local sizeMult = self.db.global.sizeMult or 1.4;
		frame:SetWidth(frame:GetParent():GetWidth() * sizeMult);
		frame:SetHeight(frame:GetParent():GetHeight() * sizeMult);
		frame.texture:SetTexture(MaxDps:GetTexture());
		frame.texture:SetAllPoints(frame);

		if frame.ovType == 'normal' then
			local c = self.db.global.highlightColor;
			frame.texture:SetVertexColor(c.r, c.g, c.b, c.a);
		elseif frame.ovType == 'cooldown' then
			local c = self.db.global.cooldownColor;
			frame.texture:SetVertexColor(c.r, c.g, c.b, c.a);
		end
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

function MaxDps:Glow(button, id, texture, type, color)
	if button.MaxDpsOverlays and button.MaxDpsOverlays[id] then
		button.MaxDpsOverlays[id]:Show();
	else
		if not button.MaxDpsOverlays then
			button.MaxDpsOverlays = {};
		end

		button.MaxDpsOverlays[id] = self:CreateOverlay(button, id, texture, type, color);
		button.MaxDpsOverlays[id]:Show();
	end
end

function MaxDps:HideGlow(button, id)
	if button.MaxDpsOverlays and button.MaxDpsOverlays[id] then
		button.MaxDpsOverlays[id]:Hide();
	end
end

function MaxDps:AddButton(actionName, button)
	if actionName then
		if self.Spells[actionName] == nil then
			self.Spells[actionName] = {};
		end
		tinsert(self.Spells[actionName], button);
	end
end

function MaxDps:AddStandardButton(button)
	local type = button:GetAttribute('type');
	if type then
		local actionType = button:GetAttribute(type);
		local id;
		local actionName;

		if type == 'action' then
			local slot = ActionButton_GetPagedID(button) or ActionButton_CalculateAction(button)
					or button:GetAttribute('action') or 0;

			if HasAction(slot) then
				type, actionType = GetActionInfo(slot);
			else
				return;
			end
		end

		if type == 'macro' then
			local name, rank, spellId = GetMacroSpell(actionType);
			if spellId then
				actionName = GetSpellInfo(spellId);
			else
				return;
			end
		elseif type == 'item' then
			actionName = GetItemInfo(actionType);
		elseif type == 'spell' then
			actionName = GetSpellInfo(actionType);
		end

		self:AddButton(actionName, button)
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

	self:FetchLibActionButton();
	self:FetchBlizzard();

	-- It does not alter original button frames so it needs to be fetched too
	if IsAddOnLoaded('ButtonForge') then
		self:FetchButtonForge();
	end

	if IsAddOnLoaded('G15Buttons') then
		self:FetchG15Buttons();
	end

	if self.rotationEnabled then
		self:EnableRotationTimer();
		self:InvokeNextSpell();
	end
end

function MaxDps:FetchLibActionButton()
	local LAB = {
		original = LibStub:GetLibrary('LibActionButton-1.0', true),
		elvui = LibStub:GetLibrary('LibActionButton-1.0-ElvUI', true),
	}

	for _, lib in pairs(LAB) do
		if lib and lib.GetAllButtons then
			for button in pairs(lib:GetAllButtons()) do
				local spellId = button:GetSpellId();
				if spellId then
					local actionName, _ = GetSpellInfo(spellId);
					self:AddButton(actionName, button);
				end
			end
		end
	end
end

function MaxDps:FetchBlizzard()
	local BlizzardBars = {'Action', 'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft'};
	for _, barName in pairs(BlizzardBars) do
		for i = 1, 12 do
			local button = _G[barName .. 'Button' .. i];
			self:AddStandardButton(button);
		end
	end
end

function MaxDps:FetchG15Buttons()
	local i = 2; -- it starts from 2
	while true do
		local button = _G['objG15_btn_' .. i];
		if not button then
			break;
		end
		i = i + 1;

		self:AddStandardButton(button);
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

		MaxDps:AddStandardButton(button)
	end
end

function MaxDps:Dump()
	local s = '';
	for k, v in pairs(self.Spells) do
		print(k);
	end
end

function MaxDps:FindSpell(spellName)
	local name = GetSpellInfo(spellName) or spellName;
	return self.Spells[name];
end

function MaxDps:GlowIndependent(spellName, id, texture, color)
	local name = GetSpellInfo(spellName) or spellName;
	if self.Spells[name] ~= nil then
		for k, button in pairs(self.Spells[name]) do
			self:Glow(button, id, texture, 'cooldown', color);
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
		self:GlowIndependent(spell, spell);
	end
	if not condition and self.Flags[spell] then
		self.Flags[spell] = false;
		self:ClearGlowIndependent(spell, spell);
	end
end

function MaxDps:GlowSpell(spellName)
	if self.Spells[spellName] ~= nil then
		for k, button in pairs(self.Spells[spellName]) do
			self:Glow(button, 'next', nil, 'normal');
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