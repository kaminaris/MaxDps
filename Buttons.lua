--- @type MaxDps MaxDps
local _, MaxDps = ...;

local CustomGlow = LibStub('LibCustomGlow-1.0');

local TableInsert = tinsert;

MaxDps.Spells = {};
MaxDps.ItemSpells = {}; -- hash map of itemId -> itemSpellId
MaxDps.Flags = {};
MaxDps.SpellsGlowing = {};
MaxDps.FramePool = {};
MaxDps.Frames = {};

local LABs = {
	['LibActionButton-1.0'] = true,
	['LibActionButton-1.0-ElvUI'] = true,
};

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
	if color then
		if type(color) ~= 'table' then
			color = self.db.global.highlightColor;
		end
		t:SetVertexColor(color.r, color.g, color.b, color.a);
	elseif type then
		frame.ovType = type;
		if type == 'normal' then
			local c = self.db.global.highlightColor;
			t:SetVertexColor(c.r, c.g, c.b, c.a);
		elseif type == 'cooldown' then
			local c = self.db.global.cooldownColor;
			t:SetVertexColor(c.r, c.g, c.b, c.a);
		end
	end

	TableInsert(self.Frames, frame);
	return frame;
end

function MaxDps:DestroyAllOverlays()
	for key, frame in pairs(self.Frames) do
		frame:GetParent().MaxDpsOverlays = nil;
		frame:ClearAllPoints();
		frame:Hide();
		frame:SetParent(UIParent);
		frame.width = nil;
		frame.height = nil;
	end

	for key, frame in pairs(self.Frames) do
		TableInsert(self.FramePool, frame);
		self.Frames[key] = nil;
	end
end

function MaxDps:ApplyOverlayChanges()
	for _, frame in pairs(self.Frames) do
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

local origShow;
function MaxDps:UpdateButtonGlow()
	if self.db.global.disableButtonGlow then
		ActionBarActionEventsFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW');

		for LAB in pairs(LABs) do
			local lib = LibStub(LAB, true);
			if lib then
				lib.eventFrame:UnregisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW');
			end
		end

		if not origShow then
			local LBG = LibStub('LibButtonGlow-1.0', true);
			if LBG then
				origShow = LBG.ShowOverlayGlow;
				LBG.ShowOverlayGlow = nop;
			end
		end
	else
		ActionBarActionEventsFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW');

		for LAB in pairs(LABs) do
			local lib = LibStub(LAB, true);
			if lib then
				lib.eventFrame:RegisterEvent('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW');
			end
		end

		if origShow then
			local LBG = LibStub('LibButtonGlow-1.0', true);
			if LBG then
				LBG.ShowOverlayGlow = origShow;
				origShow = nil;
			end
		end
	end
end

function MaxDps:Glow(button, id, texture, type, color)
	local opts = self.db.global;
	if opts.customGlow then
		local col = color and {color.r, color.g, color.b, color.a} or nil;
		if not color and type then
			if type == 'normal' then
				local c = self.db.global.highlightColor;
				col = {c.r, c.g, c.b, c.a};
			elseif type == 'cooldown' then
				local c = self.db.global.cooldownColor;
				col = {c.r, c.g, c.b, c.a};
			end
		end

		if opts.customGlowType == 'pixel' then
			CustomGlow.PixelGlow_Start(
				button,
				col,
				opts.customGlowLines,
				opts.customGlowFrequency,
				opts.customGlowLength,
				opts.customGlowThickness,
				0,
				0,
				false,
				id
			);
		else
			CustomGlow.AutoCastGlow_Start(
				button,
				col,
				math.ceil(opts.customGlowParticles),
				opts.customGlowParticleFrequency,
				opts.customGlowScale,
				0,
				0,
				id
			);
		end
		return
	end

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
	local opts = self.db.global;
	if opts.customGlow then
		if opts.customGlowType == 'pixel' then
			CustomGlow.PixelGlow_Stop(button, id);
		else
			CustomGlow.AutoCastGlow_Stop(button, id);
		end
		return
	end

	if button.MaxDpsOverlays and button.MaxDpsOverlays[id] then
		button.MaxDpsOverlays[id]:Hide();
	end
end

function MaxDps:AddButton(spellId, button)
	if spellId then
		if self.Spells[spellId] == nil then
			self.Spells[spellId] = {};
		end

		TableInsert(self.Spells[spellId], button);
	end
end

-- this should be pretty universal
function MaxDps:AddItemButton(button)
	-- support for trinkets and potions
	local actionSlot = button:GetAttribute('action');

	if actionSlot and (IsEquippedAction(actionSlot) or IsConsumableAction(actionSlot)) then
		local type, itemId = GetActionInfo(actionSlot);
		if type == 'item' then
			local _, itemSpellId = GetItemSpell(itemId);
			self.ItemSpells[itemId] = itemSpellId;

			self:AddButton(itemSpellId, button);
		end
	end
end

function MaxDps:AddStandardButton(button)
	local type = button:GetAttribute('type');
	if type then
		local actionType = button:GetAttribute(type);
		local id;
		local spellId;

		if type == 'action' then
			local slot = button:GetAttribute('action');
			if not slot or slot == 0 then
				slot = ActionButton_GetPagedID(button);
			end
			if not slot or slot == 0 then
				slot = ActionButton_CalculateAction(button);
			end

			if HasAction(slot) then
				type, actionType = GetActionInfo(slot);
			else
				return
			end
		end

		if type == 'macro' then
			spellId = GetMacroSpell(actionType);
		elseif type == 'item' then
			self:AddItemButton(button);
			return
		elseif type == 'spell' then
			spellId = select(7, GetSpellInfo(actionType));
		end

		self:AddButton(spellId, button);
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
	self.ItemSpells = {};
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

	if IsAddOnLoaded('SyncUI') then
		self:FetchSyncUI();
	end

	if IsAddOnLoaded('LUI') then
		self:FetchLUI();
	end

	if IsAddOnLoaded('Dominos') then
		self:FetchDominos();
	end

	if IsAddOnLoaded('DiabolicUI') then
		self:FetchDiabolic();
	end

	if IsAddOnLoaded('AzeriteUI') then
		self:FetchAzeriteUI();
	end

	if IsAddOnLoaded('Neuron') then
		self:FetchNeuron();
	end

	if self.rotationEnabled then
		self:EnableRotationTimer();
		self:InvokeNextSpell();
	end
end

function MaxDps:FetchNeuron()
	for x = 1, 12 do
		for i = 1, 12 do
			local button = _G['NeuronActionBar' .. x .. '_' .. 'ActionButton' .. i];
			if button then
				self:AddStandardButton(button);
			end
		end
	end
end

function MaxDps:FetchDiabolic()
	local diabolicBars = {'EngineBar1', 'EngineBar2', 'EngineBar3', 'EngineBar4', 'EngineBar5'};
	for _, bar in pairs(diabolicBars) do
		for i = 1, 12 do
			local button = _G[bar .. 'Button' .. i];
			if button then
				self:AddStandardButton(button);
			end
		end
	end
end

function MaxDps:FetchDominos()
	-- Dominos is using half of the blizzard frames so we just fetch the missing one

	for i = 1, 60 do
		local button = _G['DominosActionButton' .. i];
		if button then
			self:AddStandardButton(button);
		end
	end
end

function MaxDps:FetchAzeriteUI()
	for i = 1, 24 do
		local button = _G['AzeriteUIActionButton' .. i];
		if button then
			self:AddStandardButton(button);
		end
	end
end

function MaxDps:FetchLUI()
	local luiBars = {
		'LUIBarBottom1', 'LUIBarBottom2', 'LUIBarBottom3', 'LUIBarBottom4', 'LUIBarBottom5', 'LUIBarBottom6',
		'LUIBarRight1', 'LUIBarRight2', 'LUIBarLeft1', 'LUIBarLeft2'
	};

	for _, bar in pairs(luiBars) do
		for i = 1, 12 do
			local button = _G[bar .. 'Button' .. i];
			if button then
				self:AddStandardButton(button);
			end
		end
	end
end

function MaxDps:FetchSyncUI()
	local syncbars = {};

	syncbars[1] = SyncUI_ActionBar;
	syncbars[2] = SyncUI_MultiBar;
	syncbars[3] = SyncUI_SideBar.Bar1;
	syncbars[4] = SyncUI_SideBar.Bar2;
	syncbars[5] = SyncUI_SideBar.Bar3;
	syncbars[6] = SyncUI_PetBar;

	for _, bar in pairs(syncbars) do
		for i = 1, 12 do
			local button = bar['Button' .. i];
			if button then
				self:AddStandardButton(button);
			end
		end
	end
end

function MaxDps:RegisterLibActionButton(name)
	assert(type(name) == 'string', format('Bad argument to "RegisterLibActionButton", expected string, got "%s"', type(name)));

	if not name:match('LibActionButton%-1%.0') then
		error(format('Bad argument to "RegisterLibActionButton", expected "LibActionButton-1.0*", got "%s"', name), 2);
	end

	LABs[name] = true;
end

function MaxDps:FetchLibActionButton()
	for LAB in pairs(LABs) do
		local lib = LibStub(LAB, true);
		if lib then
			for button in pairs(lib:GetAllButtons()) do
				local spellId = button:GetSpellId();
				if spellId then
					self:AddButton(spellId, button);
				end

				self:AddItemButton(button);
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
	for k, v in pairs(self.Spells) do
		print(k, GetSpellInfo(k));
	end
end

function MaxDps:FindSpell(spellId)
	return self.Spells[spellId];
end

function MaxDps:GlowIndependent(spellId, id, texture, color)
	if self.Spells[spellId] ~= nil then
		for k, button in pairs(self.Spells[spellId]) do
			self:Glow(button, id, texture, 'cooldown', color);
		end
	end
end

function MaxDps:ClearGlowIndependent(spellId, id)
	if self.Spells[spellId] ~= nil then
		for k, button in pairs(self.Spells[spellId]) do
			self:HideGlow(button, id);
		end
	end
end

function MaxDps:GlowCooldown(spellId, condition, color)
	if self.Flags[spellId] == nil then
		self.Flags[spellId] = false;
	end
	if condition and not self.Flags[spellId] then
		self.Flags[spellId] = true;
		self:GlowIndependent(spellId, spellId, nil, color);
	end
	if not condition and self.Flags[spellId] then
		self.Flags[spellId] = false;
		self:ClearGlowIndependent(spellId, spellId);
	end

	if WeakAuras then WeakAuras.ScanEvents('MAXDPS_COOLDOWN_UPDATE', self.Flags); end
end

function MaxDps:GlowSpell(spellId)
	if self.Spells[spellId] ~= nil then
		for k, button in pairs(self.Spells[spellId]) do
			self:Glow(button, 'next', nil, 'normal');
		end

		self.SpellsGlowing[spellId] = 1;
	else
		local spellName = GetSpellInfo(spellId);
		self:Print(self.Colors.Error .. 'Spell not found on action bars: ' .. spellName .. '(' .. spellId .. ')');
	end
end

function MaxDps:GlowNextSpell(spellId)
	self:GlowClear();
	self:GlowSpell(spellId);
end

function MaxDps:GlowClear()
	for spellId, v in pairs(self.SpellsGlowing) do
		if v == 1 then
			for k, button in pairs(self.Spells[spellId]) do
				self:HideGlow(button, 'next');
			end
			self.SpellsGlowing[spellId] = 0;
		end
	end
end