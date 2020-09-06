local addonName, MaxDps = ...;

LibStub('AceAddon-3.0'):NewAddon(MaxDps, 'MaxDps', 'AceConsole-3.0', 'AceEvent-3.0', 'AceTimer-3.0');

--- @class MaxDps
_G[addonName] = MaxDps;

local TableInsert = tinsert;
local TableRemove = tremove;
local TableContains = tContains;
local TableIndexOf = tIndexOf;

local UnitIsFriend = UnitIsFriend;
local IsPlayerSpell = IsPlayerSpell;
local UnitClass = UnitClass;
local GetSpecialization = GetSpecialization;
local CreateFrame = CreateFrame;
local GetAddOnInfo = GetAddOnInfo;
local IsAddOnLoaded = IsAddOnLoaded;
local LoadAddOn = LoadAddOn;

function MaxDps:OnInitialize()
	self.db = LibStub('AceDB-3.0'):New('MaxDpsOptions', self.defaultOptions);

	self:RegisterChatCommand('maxdps', 'ShowMainWindow');

	if not self.db.global.customRotations then
		self.db.global.customRotations = {};
	end

	self:AddToBlizzardOptions();
end

function MaxDps:ShowMainWindow()
	if not self.Window then
		self.Window = self:GetModule('Window');
	end

	self.Window:ShowWindow();
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
		return
	end

	MaxDps:DefaultPrint(...);
end

MaxDps.profilerStatus = 0;
function MaxDps:ProfilerStart()
	local profiler = self:GetModule('Profiler');
	profiler:StartProfiler();
	self.profilerStatus = 1;
end

function MaxDps:ProfilerStop()
	local profiler = self:GetModule('Profiler');
	profiler:StopProfiler();
	self.profilerStatus = 0;
end

function MaxDps:ProfilerToggle()
	if self.profilerStatus == 0 then
		self:ProfilerStart();
	else
		self:ProfilerStop();
	end
end

function MaxDps:EnableRotation()
	if self.NextSpell == nil or self.rotationEnabled then
		self:Print(self.Colors.Error .. 'Failed to enable addon!');
		return
	end

	self:Fetch();
	self:UpdateButtonGlow();

	self:CheckTalents();
	self:GetAzeriteTraits();
	self:GetAzeriteEssences();
	self:CheckIsPlayerMelee();
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
		return
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
	self:RegisterEvent('PLAYER_REGEN_DISABLED');
	-- self:RegisterEvent('PLAYER_ENTERING_WORLD');
	self:RegisterEvent('AZERITE_ESSENCE_ACTIVATED');

	self:RegisterEvent('ACTIONBAR_SLOT_CHANGED', 'ButtonFetch');
	self:RegisterEvent('ACTIONBAR_HIDEGRID', 'ButtonFetch');
	self:RegisterEvent('ACTIONBAR_PAGE_CHANGED', 'ButtonFetch');
	self:RegisterEvent('LEARNED_SPELL_IN_TAB', 'ButtonFetch');
	self:RegisterEvent('CHARACTER_POINTS_CHANGED', 'ButtonFetch');
	self:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED', 'ButtonFetch');
	self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED', 'ButtonFetch');
	self:RegisterEvent('UPDATE_MACROS', 'ButtonFetch');
	self:RegisterEvent('VEHICLE_UPDATE', 'ButtonFetch');
	self:RegisterEvent('UPDATE_STEALTH', 'ButtonFetch');

	self:RegisterEvent('UNIT_ENTERED_VEHICLE');
	self:RegisterEvent('UNIT_EXITED_VEHICLE');

	self:RegisterEvent('NAME_PLATE_UNIT_ADDED');
	self:RegisterEvent('NAME_PLATE_UNIT_REMOVED');
	--	self:RegisterEvent('PLAYER_REGEN_ENABLED');

	if not self.playerUnitFrame then
		self.spellHistory = {};

		self.playerUnitFrame = CreateFrame('Frame');
		self.playerUnitFrame:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player');
		self.playerUnitFrame:SetScript('OnEvent', function(_, _, _, _, spellId)
			-- event, unit, lineId
			if IsPlayerSpell(spellId) then
				TableInsert(self.spellHistory, 1, spellId);

				if #self.spellHistory > 5 then
					TableRemove(self.spellHistory);
				end
			end
		end);
	end

	self:Print(self.Colors.Info .. 'Initialized');
end

MaxDps.visibleNameplates = {};
function MaxDps:NAME_PLATE_UNIT_ADDED(_, nameplateUnit)
	if not TableContains(self.visibleNameplates, nameplateUnit) then
		TableInsert(self.visibleNameplates, nameplateUnit);
	end
end

function MaxDps:NAME_PLATE_UNIT_REMOVED(_, nameplateUnit)
	local index = TableIndexOf(self.visibleNameplates, nameplateUnit);
	if index ~= nil then
		TableRemove(self.visibleNameplates, index)
	end
end

function MaxDps:PLAYER_TALENT_UPDATE()
	self:DisableRotation();
end

function MaxDps:AZERITE_ESSENCE_ACTIVATED()
	self:DisableRotation();
end

function MaxDps:UNIT_ENTERED_VEHICLE(_, unit)
	if unit == 'player' and self.rotationEnabled then
		self:DisableRotation();
	end
end

function MaxDps:UNIT_EXITED_VEHICLE(_, unit)
	if unit == 'player' then
		self:InitRotations();
		self:EnableRotation();
	end
end

function MaxDps:PLAYER_TARGET_CHANGED()
	if self.rotationEnabled then
		if UnitIsFriend('player', 'target') then
			return
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

function MaxDps:PrepareFrameData()
	if not self.FrameData then
		self.FrameData = {
			cooldown  = self.PlayerCooldowns,
			activeDot = self.ActiveDots
		};
	end

	self.FrameData.timeShift, self.FrameData.currentSpell, self.FrameData.gcdRemains = MaxDps:EndCast();
	self.FrameData.gcd = self:GlobalCooldown();
	self.FrameData.buff, self.FrameData.debuff = MaxDps:CollectAuras();
	self.FrameData.talents = self.PlayerTalents;
	self.FrameData.azerite = self.AzeriteTraits;
	self.FrameData.essences = self.AzeriteEssences;
	self.FrameData.spellHistory = self.spellHistory;
	self.FrameData.timeToDie = self:GetTimeToDie();
end

function MaxDps:InvokeNextSpell()
	-- invoke spell check
	local oldSkill = self.Spell;

	self:PrepareFrameData();

	self:GlowConsumables();

	-- Removed backward compatibility
	self.Spell = self:NextSpell();

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

	if not self.Custom then
		self.Custom = self:GetModule('Custom');
	end

	self.Custom:LoadCustomRotations();
	local customRotation = self.Custom:GetCustomRotation(classId, spec);

	if customRotation then
		self.NextSpell = customRotation.fn;

		self:Print(self.Colors.Success .. 'Loaded Custom Rotation: ' .. customRotation.name);
	else
		self:LoadModule();
	end
end

function MaxDps:LoadModule()
	if self.Classes[self.ClassId] == nil then
		self:Print(self.Colors.Error .. 'Invalid player class, please contact author of addon.');
		return
	end

	local className = self.Classes[self.ClassId];
	local module = 'MaxDps_' .. className;
	local _, _, _, _, reason = GetAddOnInfo(module);

	if IsAddOnLoaded(module) then
		self:EnableRotationModule(className);
		return
	end

	if reason == 'MISSING' or reason == 'DISABLED' then
		self:Print(self.Colors.Error .. 'Could not find class module ' .. module .. ', reason: ' .. reason);
		self:Print(self.Colors.Error .. 'Make sure to install class module or create custom rotation');
		self:Print(self.Colors.Error .. 'Missing addon: ' .. module);
		return
	end

	LoadAddOn(module);

	self:InitTTD();
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
