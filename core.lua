local AceGUI = LibStub('AceGUI-3.0');
local lsm = LibStub('AceGUISharedMediaWidgets-1.0');
local media = LibStub('LibSharedMedia-3.0');

MaxDps = LibStub('AceAddon-3.0'):NewAddon('MaxDps', 'AceConsole-3.0', 'AceEvent-3.0', 'AceTimer-3.0');

MaxDps.Textures = {
	['Ping'] = 'Interface\\Cooldown\\ping4',
	['Star'] = 'Interface\\Cooldown\\star4',
	['Starburst'] = 'Interface\\Cooldown\\starburst',
};
MaxDps.FinalTexture = nil;

MaxDps.Colors = {
	Info = '|cFF1394CC',
	Error = '|cFFF0563D',
	Success = '|cFFBCCF02',
}

MaxDps.Classes = {
	[1] = 'Warrior',
	[2] = 'Paladin',
	[3] = 'Hunter',
	[4] = 'Rogue',
	[5] = 'Priest',
	[6] = 'DeathKnight',
	[7] = 'Shaman',
	[8] = 'Mage',
	[9] = 'Warlock',
	[10] = 'Monk',
	[11] = 'Druid',
	[12] = 'DemonHunter',
}

local defaultOptions = {
	global = {
		enabled = true,
		disabledInfo = false,
		debugMode = false,
		disableButtonGlow = false,
		onCombatEnter = true,
		texture = '',
		customTexture = '',
		highlightColor = {
			r = 1, g = 1, b = 1, a = 1
		},
		interval = 0.15
	}
}

local options = {
	type = 'group',
	name = 'MaxDps Options',
	inline = false,
	args = {
		enable = {
			name = 'Enable',
			desc = 'Enables / disables the addon',
			type = 'toggle',
			width = 'full',
			set = function(info, val)
				MaxDps.db.global.enabled = val;
			end,
			get = function(info) return MaxDps.db.global.enabled end
		},
		disabledInfo = {
			name = 'Disable info messages',
			desc = 'Enables / disables info messages, if you have issues with addon, make sure to deselect this.',
			type = 'toggle',
			width = 'full',
			set = function(info, val)
				MaxDps.db.global.disabledInfo = val;
			end,
			get = function(info) return MaxDps.db.global.disabledInfo end
		},
		debugMode = {
			name = 'Enable debug mode',
			desc = 'Enables spammy chat messages (use this when addon does not work for you)',
			type = 'toggle',
			width = 'full',
			set = function(info, val)
				MaxDps.db.global.debugMode = val;
			end,
			get = function(info) return MaxDps.db.global.debugMode end
		},
		disableButtonGlow = {
			name = 'Dissable blizzard button glow (experimental)',
			desc = 'Disables original blizzard button glow',
			type = 'toggle',
			width = 'full',
			set = function(info, val)
				MaxDps.db.global.disableButtonGlow = val;
				MaxDps:UpdateButtonGlow();
			end,
			get = function(info) return MaxDps.db.global.disableButtonGlow end
		},
		onCombatEnter = {
			name = 'Enable upon entering combat',
			desc = 'Automatically enables helper upon entering combat',
			type = 'toggle',
			width = 'full',
			set = function(info, val)
				MaxDps.db.global.onCombatEnter = val;
			end,
			get = function(info) return MaxDps.db.global.onCombatEnter end
		},
		customTexture = {
			name = 'Custom Texture',
			desc = 'Sets Highlight texture, has priority over selected one (changing this requires UI Reload)',
			type = 'input',
			set = function(info, val) MaxDps.db.global.customTexture = strtrim(val or ''); end,
			get = function(info) return strtrim(MaxDps.db.global.customTexture or '') end
		},
		texture = {
			type = 'select',
			dialogControl = 'LSM30_Background',
			name = 'Texture',
			desc = 'Sets Highlight texture (changing this requires UI Reload)',
			values = function()
				return MaxDps.Textures;
			end,
			get = function()
				return MaxDps.db.global.texture;
			end,
			set = function(self, val)
				MaxDps.db.global.texture = val;
			end,
		},
		highlightColor = {
			name = 'Highlight color',
			desc = 'Sets Highlight color',
			type = 'color',
			set = function(info, r, g, b, a)
				MaxDps.db.global.highlightColor.r = r;
				MaxDps.db.global.highlightColor.g = g;
				MaxDps.db.global.highlightColor.b = b;
				MaxDps.db.global.highlightColor.a = a;
			end,
			get = function(info)
				return MaxDps.db.global.highlightColor.r, MaxDps.db.global.highlightColor.g, MaxDps.db.global.highlightColor.b, MaxDps.db.global.highlightColor.a;
			end,
			hasAlpha = true
		},
		interval = {
			name = 'Interval in seconds',
			desc = 'Sets how frequent rotation updates will be. Low value will result in fps drops.',
			type = 'range',
			min = 0.01,
			max = 2,
			set = function(info,val) MaxDps.db.global.interval = val end,
			get = function(info) return MaxDps.db.global.interval end
		},
	},
}

function MaxDps:GetTexture()
	if self.db.global.customTexture ~= '' and self.db.global.customTexture ~= nil then
		self.FinalTexture = self.db.global.customTexture;
		return self.FinalTexture;
	end

	self.FinalTexture = self.Textures[self.db.global.texture];
	if self.FinalTexture == '' or self.FinalTexture == nil then
		self.FinalTexture = 'Interface\\Cooldown\\ping4';
	end

	return self.FinalTexture;
end

function MaxDps:OnInitialize()
	LibStub('AceConfig-3.0'):RegisterOptionsTable('MaxDps', options, {'/maxdps'});
	self.db = LibStub('AceDB-3.0'):New('MaxDpsOptions', defaultOptions);
	self.optionsFrame = LibStub('AceConfigDialog-3.0'):AddToBlizOptions('MaxDps', 'MaxDps');
end

MaxDps.DefaultPrint = MaxDps.Print;
function MaxDps:Print(...)
	if self.db.global.disabledInfo then
		return;
	end
	MaxDps:DefaultPrint(...);
end

function MaxDps:EnableRotation()
	self:Print(self.Colors.Info .. 'Enabling');

	if self.NextSpell == nil or self.rotationEnabled then
		self:Print(self.Colors.Error .. 'Failed to enable addon!');
		return;
	end
	self:Print(self.Colors.Info .. 'Fetching');
	self.Fetch();

	if self.ModuleOnEnable then
		self.ModuleOnEnable();
	end

	self:EnableRotationTimer();

	self.rotationEnabled = true;
	self:Print(self.Colors.Success .. 'Enabled');
end

function MaxDps:EnableRotationTimer()
	self.RotationTimer = self:ScheduleRepeatingTimer('InvokeNextSpell', self.db.global.interval);
end

function MaxDps:DisableRotation()
	if not self.rotationEnabled then
		return;
	end

	self:DisableRotationTimer();

	self:DestroyAllOverlays();
	self:Print(self.Colors.Info .. 'Disabling');

	self.Spell = nil;
	self.rotationEnabled = false;
end

function MaxDps:DisableRotationTimer()
	if self.RotationTimer then
		self:CancelTimer(self.RotationTimer);
	end
end

function MaxDps:OnEnable()
	self:RegisterEvent('PLAYER_TARGET_CHANGED');
	self:RegisterEvent('PLAYER_TALENT_UPDATE');
	self:RegisterEvent('ACTIONBAR_SLOT_CHANGED');
	self:RegisterEvent('PLAYER_REGEN_DISABLED');
	self:RegisterEvent('PLAYER_ENTERING_WORLD');

	self:RegisterEvent('ACTIONBAR_HIDEGRID');
	self:RegisterEvent('ACTIONBAR_PAGE_CHANGED');
	self:RegisterEvent('LEARNED_SPELL_IN_TAB');
	self:RegisterEvent('CHARACTER_POINTS_CHANGED');
	self:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED');
	self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED');
	self:RegisterEvent('UPDATE_MACROS');
	self:RegisterEvent('VEHICLE_UPDATE');

	self:RegisterEvent('UNIT_ENTERED_VEHICLE');
	self:RegisterEvent('UNIT_EXITED_VEHICLE');
	--	self:RegisterEvent('PLAYER_REGEN_ENABLED');

	self:Print(self.Colors.Info .. 'Initialized');
end

function MaxDps:PLAYER_TALENT_UPDATE()
	self:DisableRotation();
end

function MaxDps:UNIT_ENTERED_VEHICLE(event, unit)
	if unit == 'player' and self.rotationEnabled then
		self:DisableRotation();
	end
end

function MaxDps:UNIT_EXITED_VEHICLE(event, unit)
	if unit == 'player' and self.ModuleLoaded then
		self:EnableRotation();
	end
end

function MaxDps:PLAYER_ENTERING_WORLD()
	self:UpdateButtonGlow();
end

function MaxDps:PLAYER_TARGET_CHANGED()
	if self.rotationEnabled then
		if (UnitIsFriend('player', 'target')) then
			return;
		else
			self:InvokeNextSpell();
		end
	end
end

function MaxDps:PLAYER_REGEN_DISABLED()
	if self.db.global.onCombatEnter and not self.rotationEnabled then
		self:Print(self.Colors.Success .. 'Auto enable on combat!');
		self:LoadModule();
		self:CheckSpecialization();
		self:EnableRotation();
	end
end

function MaxDps:ButtonFetch()
	if self.rotationEnabled then
		if self.fetchTimer then
			self:CancelTimer(self.fetchTimer);
		end
		self.fetchTimer = self:ScheduleTimer('Fetch', 0.5);
	end
end

MaxDps.ACTIONBAR_SLOT_CHANGED = MaxDps.ButtonFetch;
MaxDps.ACTIONBAR_HIDEGRID = MaxDps.ButtonFetch;
MaxDps.ACTIONBAR_PAGE_CHANGED = MaxDps.ButtonFetch;
MaxDps.LEARNED_SPELL_IN_TAB = MaxDps.ButtonFetch;
MaxDps.CHARACTER_POINTS_CHANGED = MaxDps.ButtonFetch;
MaxDps.ACTIVE_TALENT_GROUP_CHANGED = MaxDps.ButtonFetch;
MaxDps.PLAYER_SPECIALIZATION_CHANGED = MaxDps.ButtonFetch;
MaxDps.UPDATE_MACROS = MaxDps.ButtonFetch;
MaxDps.VEHICLE_UPDATE = MaxDps.ButtonFetch;

function MaxDps:InvokeNextSpell()
	-- invoke spell check
	local oldSkill = self.Spell;

	self.Spell = self:NextSpell();

	if (oldSkill ~= self.Spell or oldSkill == nil) and self.Spell ~= nil then
		self:GlowNextSpellId(self.Spell);
	end
	if self.Spell == nil and oldSkill ~= nil then
		self:GlowClear();
	end
end

function MaxDps:LoadModule()
	if self.ModuleLoaded then
		return;
	end

	self:Print(self.Colors.Info .. 'Loading class module');
	local _, _, classId = UnitClass('player');
	if self.Classes[classId] == nil then
		self:Print(_tdError, 'Invalid player class, please contact author of addon.');
		return;
	end

	local module = 'MaxDps_' .. self.Classes[classId];

	if not IsAddOnLoaded(module) then
		LoadAddOn(module);
	end

	if not IsAddOnLoaded(module) then
		self:Print(self.Colors.Error .. 'Could not find class module.');
		return;
	end

	local mode = GetSpecialization();

	self:EnableRotationModule(mode);
	self:Print(self.Colors.Info .. self.Description);

	self:Print(self.Colors.Info .. 'Finished Loading class module');
	self.ModuleLoaded = true;
end

function MaxDps:CheckSpecialization()
	local mode = GetSpecialization();

	self:EnableRotationModule(mode);
end