_TD = _TD or {}; -- depreciated

local timer = LibStub:GetLibrary("BigLibTimer6"):Register(timer);

local TDDps = CreateFrame('Frame', 'TDDps');
TDDps.AddonEnabled = false;
TDDps.rotationEnabled = false;
TDDps.ModuleOnEnable = nil;
TDDps.NextSpell = nil;
TDDps.Spell = nil;
TDDps.Description = nil;
TDDps.Time = 0;

TDDps.Classes = {
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

-- Name and colors
TDDpsName = 'TDDPS';
_tdInfo = '|cFF1394CC';
_tdError = '|cFFF0563D';
_tdSuccess = '|cFFBCCF02';

-- Globals for time to die
TDDps_TargetGuid = nil;
TD_Hp0, TD_T0, TD_Hpm, TD_Tm = nil, nil, nil, nil;

function TDDps:Print(color, message, force)
	if (TDDps_Options.disabledInfo and not TDDps_Options.debugMode) or force then
		return;
	end

	print(color .. TDDpsName .. ': ' .. message);
end

----------------------------------------------
-- Disable dps addon functionality
----------------------------------------------
function TDDps:DisableAddon()
	if not TDDps.AddonEnabled then
		return;
	end

	TDButton.DestroyAllOverlays();
	TDDps:Print(_tdInfo, 'Disabling', true);
	TDDps:SetScript('OnUpdate', nil);
	TDDps.Spell = nil;
	TDDps.rotationEnabled = false;
	TDDps.AddonEnabled = false;
end

----------------------------------------------
-- Initialize dps addon functionality
----------------------------------------------
function TDDps:InitAddon()
	TDDps:Show();

	TDDps:RegisterEvent('PLAYER_TARGET_CHANGED');
	TDDps:RegisterEvent('PLAYER_TALENT_UPDATE');
	TDDps:RegisterEvent('ACTIONBAR_SLOT_CHANGED');
	TDDps:RegisterEvent('PLAYER_REGEN_DISABLED');
	TDDps:RegisterEvent('PLAYER_ENTERING_WORLD');

	TDDps:RegisterEvent('ACTIONBAR_HIDEGRID');
	TDDps:RegisterEvent('ACTIONBAR_PAGE_CHANGED');
	TDDps:RegisterEvent('LEARNED_SPELL_IN_TAB');
	TDDps:RegisterEvent('CHARACTER_POINTS_CHANGED');
	TDDps:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED');
	TDDps:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED');
	TDDps:RegisterEvent('UPDATE_MACROS');
	TDDps:RegisterEvent('VEHICLE_UPDATE');
--	TDDps:RegisterEvent('PLAYER_REGEN_ENABLED');

	TDDps:SetScript('OnEvent', self.OnEvent);

	TDDps:Print(_tdInfo, 'Initialized');
end

----------------------------------------------
-- Enable dps addon functionality
----------------------------------------------
function TDDps:EnableAddon()
	TDDps:Print(_tdInfo, 'Enabling');

	if TDDps.NextSpell == nil or TDDps.AddonEnabled then
		TDDps:Print(_tdError, 'Failed to enable addon!', true);
		return;
	end
	TDDps:Print(_tdInfo, 'Fetching');
	TDButton.Fetch();

	if TDDps.ModuleOnEnable then
		TDDps.ModuleOnEnable();
	end

	TDDps:SetScript('OnUpdate', TDDps.OnUpdate);

	TDDps.AddonEnabled = true;
	TDDps:Print(_tdSuccess, 'Enabled', true);
end

function TDDps_EnableAddon()
	-- backwards compatibility, don't load it until we say so
end

----------------------------------------------
-- Event Script, Target Change, Specializaton Change
----------------------------------------------
function TDDps:InvokeNextSpell()
	-- invoke spell check
	local oldSkill = TDDps.Spell;

	TDDps.Spell = TDDps.NextSpell();

	if (oldSkill ~= TDDps.Spell or oldSkill == nil) and TDDps.Spell ~= nil then
		TDButton.GlowNextSpellId(TDDps.Spell);
	end
	if TDDps.Spell == nil and oldSkill ~= nil then
		TDButton.GlowClear();
	end
end

----------------------------------------------
-- Event Script, Target Change, Specializaton Change
----------------------------------------------
function TDDps.OnEvent(self, event)
	if event == 'PLAYER_TALENT_UPDATE' then
		TDDps:DisableAddon();
	elseif event == 'PLAYER_ENTERING_WORLD' then
		TDButton.UpdateButtonGlow();
	elseif event == 'ACTIONBAR_SLOT_CHANGED' or
			event == 'ACTIONBAR_HIDEGRID' or
			event == 'ACTIONBAR_PAGE_CHANGED' or
			event == 'LEARNED_SPELL_IN_TAB' or
			event == 'CHARACTER_POINTS_CHANGED' or
			event == 'ACTIVE_TALENT_GROUP_CHANGED' or
			event == 'PLAYER_SPECIALIZATION_CHANGED' or
			event == 'UPDATE_MACROS' or
			event == 'VEHICLE_UPDATE' then
			if TDDps.rotationEnabled then
				timer:SetTimer("TDButton_Fetch", 0.5, 0, TDButton.Fetch);
			end
		return;
	end
	if event == 'PLAYER_TARGET_CHANGED' then
		TD_Hp0, TD_T0, TD_Hpm, TD_Tm = nil, nil, nil, nil;

		if UnitExists('target') and not UnitIsFriend('player', 'target') then
			TDDps_TargetGuid = UnitGUID('target');
		else
			TDDps_TargetGuid = nil;
		end
	end
	if TDDps.rotationEnabled then
		if event == 'PLAYER_TARGET_CHANGED' then
			if (UnitIsFriend('player', 'target')) then
				return;
			else
				TDDps:InvokeNextSpell();
			end
		end
	end
	if event == 'PLAYER_REGEN_DISABLED' and TDDps_Options.onCombatEnter and not TDDps.rotationEnabled then
		TDDps:Print(_tdSuccess, 'Auto enable on combat!');
		TDDps.rotationEnabled = true;
		TDDps:LoadModule();
	end
--	if event == 'PLAYER_REGEN_ENABLED' then
--		TDDps:Print(_tdSuccess, 'Auto disable on combat!');
--		TDDps.rotationEnabled = false;
--		TDDps:DisableAddon();
--	end
end

----------------------------------------------
-- Update script (timer)
----------------------------------------------
function TDDps.OnUpdate(self, elapsed)
	TDDps.Time = TDDps.Time + elapsed;
	if TDDps.Time >= TDDps_Options.interval then
		TDDps.Time = 0;
		TDDps:InvokeNextSpell();
	end
end

----------------------------------------------
-- Load appropriate addon for class
----------------------------------------------
function TDDps:LoadModule()
	TDDps.rotationEnabled = true;

	TDDps:Print(_tdInfo, 'Loading class module');
	local _, _, classId = UnitClass('player');
	if TDDps.Classes[classId] == nil then
		TDDps:Print(_tdError, 'Invalid player class, please contact author of addon.', true);
		return;
	end

	local module = 'TDDps_' .. TDDps.Classes[classId];

	if not IsAddOnLoaded(module) then
		LoadAddOn(module);
	end

	if not IsAddOnLoaded(module) then
		TDDps:Print(_tdError, 'Could not find class module.', true);
		return;
	end

	local mode = GetSpecialization();
	local init = module .. '_EnableAddon';

	_G[init](mode);

	-- backward compatiblity
	if _TD['DPS_NextSpell'] ~= nil then
		TDDps:Print(_tdInfo, 'Backward compatibility mode');
		TDDps.NextSpell = _TD['DPS_NextSpell'];
		TDDps.ModuleOnEnable = _TD['DPS_OnEnable'];
		TDDps.Description = _TD['DPS_Description'];
	end

	TDDps:EnableAddon();

	if TDDps.NextSpell == nil then
		TDDps.rotationEnabled = false;
		TDDps:Print(_tdError, 'Specialization is not supported.', true);
	end
	TDDps:Print(_tdSuccess, 'Finished Loading class module');
end

TDDps:InitAddon();