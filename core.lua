
--- @class MaxDps
MaxDps = LibStub('AceAddon-3.0'):NewAddon('MaxDps', 'AceConsole-3.0', 'AceEvent-3.0', 'AceTimer-3.0');

function MaxDps:OnInitialize()
	self.db = LibStub('AceDB-3.0'):New('MaxDpsOptions', self.defaultOptions);

	self:RegisterChatCommand('maxdps', 'ShowCustomWindow');

	if not self.db.global.customRotations then
		self.db.global.customRotations = {};
	end

	self:AddToBlizzardOptions();
end

function MaxDps:ShowCustomWindow()
	local custom = self:EnableModule('Custom');
	custom:ShowCustomWindow();
end

function MaxDps:GetTexture()
	if self.db.global.customTexture ~= '' and self.db.global.customTexture ~= nil then
		self.FinalTexture = self.db.global.customTexture;
		return self.FinalTexture;
	end

	self.FinalTexture = self.db.global.texture;
	if self.FinalTexture == '' or self.FinalTexture == nil then
		self.FinalTexture = 'Interface\\Cooldown\\ping4';
	end

	return self.FinalTexture;
end


MaxDps.DefaultPrint = MaxDps.Print;
function MaxDps:Print(...)
	if self.db.global.disabledInfo then
		return;
	end
	MaxDps:DefaultPrint(...);
end

function MaxDps:EnableRotation()
	if self.NextSpell == nil or self.rotationEnabled then
		self:Print(self.Colors.Error .. 'Failed to enable addon!');
		return;
	end

	self:Fetch();

	self:CheckTalents();
	if self.ModuleOnEnable then
		self.ModuleOnEnable();
	end

	self:EnableRotationTimer();

	self.rotationEnabled = true;
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
	if unit == 'player' then
		self:InitRotations();
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
		self:InitRotations();
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

	local timeShift, currentSpell, gcd = MaxDps:EndCast();
	local auras, targetAuras = MaxDps:CollectAuras();

	self.Spell = self:NextSpell(timeShift, currentSpell, gcd, self.PlayerTalents);

	if (oldSkill ~= self.Spell or oldSkill == nil) and self.Spell ~= nil then
		self:GlowNextSpell(self.Spell);
		if WeakAuras then
			WeakAuras.ScanEvents('MAXDPS_SPELL_UPDATE', self.Spell);
		end
	end

	if self.Spell == nil and oldSkill ~= nil then
		self:GlowClear();
		if WeakAuras then
			WeakAuras.ScanEvents('MAXDPS_SPELL_UPDATE', nil);
		end
	end
end

function MaxDps:InitRotations()
	self:Print(self.Colors.Info .. 'Initializing rotations');

	local _, _, classId = UnitClass('player');
	local spec = GetSpecialization();
	self.ClassId = classId;
	self.Spec = spec;

	self:LoadCustomRotations();

	if self.CustomRotations[classId] and self.CustomRotations[classId][spec] then
		self.CurrentRotation = self.CustomRotations[classId][spec];
		self.NextSpell = self.CurrentRotation.fn;

		self:Print(self.Colors.Success .. 'Loaded Custom Rotation: ' .. self.CurrentRotation.name);
	else
		self:LoadModule();
	end
end

function MaxDps:LoadModule()
	print('shits not working');
	if self.Classes[self.ClassId] == nil then
		self:Print(self.Colors.Error .. 'Invalid player class, please contact author of addon.');
		return;
	end

	local className = self.Classes[self.ClassId];
	local module = 'MaxDps_' .. className;
	local _, _, _, loadable, reason = GetAddOnInfo(module);

	if IsAddOnLoaded(module) then
		self:EnableRotationModule(className);
		return;
	end

	if reason == 'MISSING' or reason == 'DISABLED' then
		self:Print(self.Colors.Error .. 'Could not find class module ' .. module .. ', reason: ' .. reason);
		return;
	end

	LoadAddOn(module);

	self:EnableRotationModule(className);
end

function MaxDps:EnableRotationModule(className)
	local loaded = self:EnableModule(className);

	if not loaded then
		self:Print(self.Colors.Error .. 'Could not find load module ' .. className .. ', reason: OUTDATED');
	else
		self:Print(self.Colors.Info .. 'Finished Loading class module');
	end
end