--- @type MaxDps MaxDps
local _, MaxDps = ...;

local StdUi = LibStub('StdUi');

local Profiler = MaxDps:NewModule('Profiler', 'AceEvent-3.0');

function Profiler:StartProfiler()
	self.Spells = {};
	self.PlayerAuras = {};
	self.TargetAuras = {};
	self:RegisterEvent('UNIT_AURA');
	self:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED', 'SpellEvent');
	self:RegisterEvent('UNIT_SPELLCAST_INTERRUPTED', 'SpellEvent');
	self:RegisterEvent('UNIT_SPELLCAST_FAILED', 'SpellEvent');
	self:RegisterEvent('UNIT_SPELLCAST_START', 'SpellEvent');

	MaxDps:Print(MaxDps.Colors.Info .. 'Profiler started');
end

function Profiler:StopProfiler()
	self:UnregisterEvent('UNIT_AURA');
	self:UnregisterEvent('UNIT_SPELLCAST_SUCCEEDED');
	self:UnregisterEvent('UNIT_SPELLCAST_INTERRUPTED');
	self:UnregisterEvent('UNIT_SPELLCAST_FAILED');
	self:UnregisterEvent('UNIT_SPELLCAST_START');

	self:ShowWindow();
	MaxDps:Print(MaxDps.Colors.Success .. 'Profiler finished');
end

function Profiler:UNIT_AURA(e, unit)
	if UnitIsUnit(unit, 'player') then
		for i = 1, 40 do
			local name, _, _, debuffType, _, _, unitCaster, _, _, spellId = UnitAura('player', i);
			if spellId and not self.PlayerAuras[spellId] then
				self.PlayerAuras[spellId] = name;
			end
		end
	end

	if UnitIsUnit(unit, 'target') then
		for i = 1, 40 do
			local name, _, _, debuffType, _, _, unitCaster, _, _, spellId = UnitAura('target', i, 'PLAYER|HARMFUL');
			print(spellId);
			if spellId and not self.TargetAuras[spellId] then
				self.TargetAuras[spellId] = name;
			end
		end
	end
end

function Profiler:SpellEvent(e, unit, _, spellId)
	if not UnitIsUnit(unit, 'player') then
		return
	end

	if self.Spells[spellId] then
		return
	end

	local spellName = GetSpellInfo(spellId);
	self.Spells[spellId] = spellName;
end

function Profiler:SanitizeSpellName(spellName)
	return spellName:gsub('%s+', ''):gsub('%W','');
end

function Profiler:GenerateLua()
	local output = '-- Spells\nlocal S = {\n';
	for spellId, spellName in pairs(self.Spells) do
		output = output .. '    ' .. self:SanitizeSpellName(spellName) .. ' = ' .. spellId .. ',\n';
	end
	output = output .. '};\n'

	output = output .. '\n-- Player Auras\nlocal A = {\n';
	for auraId, auraName in pairs(self.PlayerAuras) do
		output = output .. '    ' .. self:SanitizeSpellName(auraName) .. ' = ' .. auraId .. ',\n';
	end
	output = output .. '};\n'

	output = output .. '\n-- Target Auras\nlocal TA = {\n';
	for auraId, auraName in pairs(self.TargetAuras) do
		output = output .. '    ' .. self:SanitizeSpellName(auraName) .. ' = ' .. auraId .. ',\n';
	end
	output = output .. '};\n'

	return output;
end

function Profiler:ShowWindow()
	if self.frame then
		self.editBox:SetText(self:GenerateLua());
		self.frame:Show();
		return
	end

	local f = StdUi:Window(UIParent, 500, 600, 'MaxDps Profiler');
	f:SetPoint('CENTER');

	local editBox = StdUi:MultiLineBox(f, 480, 550);
	editBox:SetText(self:GenerateLua());
	StdUi:GlueTop(editBox.panel, f, 0, -30, 'CENTER');

	f:Show();

	self.frame = f;
	self.editBox = editBox;
end