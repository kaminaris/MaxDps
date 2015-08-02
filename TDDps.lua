_TD = _TD or {};

_TD['DPS_Enabled'] 	= 0;
_TD['DPS_OnEnable'] = nil;
_TD['DPS_NextSpell'] = nil;
_TD['DPS_Description'] = '';
_TD['DPS_Mode'] = 1;

DPS_Skill = nil;

-- Name and colors
TDDpsName = 'TDDPS';
_tdInfo = '|cFF1394CC';
_tdError = '|cFFF0563D';
_tdSuccess = '|cFFBCCF02';

local _DPS_time = 0;
local TDDps_Frame = CreateFrame('frame');
TDDps_Frame.rotationEnabled = false;

----------------------------------------------
-- Disable dps addon functionality
----------------------------------------------
function TDDps_DisableAddon()
	TDDps_Frame:SetScript('OnUpdate', nil);
	TDButton_ClearAll();
end

----------------------------------------------
-- Initialize dps addon functionality
----------------------------------------------
function TDDps_InitAddon()
	TDDps_Frame:Show();

	TDDps_Frame:RegisterEvent('PLAYER_TARGET_CHANGED');
	TDDps_Frame:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED');
	TDDps_Frame:RegisterEvent('PLAYER_REGEN_DISABLED');
	TDDps_Frame:RegisterEvent('PLAYER_REGEN_ENABLED');

	TDDps_Frame:SetScript('OnEvent', TDDps_OnEvent);

	print(_tdInfo .. TDDpsName .. ': Initialized');
end

----------------------------------------------
-- Enable dps addon functionality
----------------------------------------------
function TDDps_EnableAddon(mode)
	TDDps_DisableAddon();
	
	print(_tdInfo .. TDDpsName .. ': Enabling');
	
	if _TD['DPS_NextSpell'] == nil then
		print(_tdError .. TDDpsName .. ': No addon selected, cannot enable');
		return;
	end
	
	if _TD['DPS_Enabled'] == 1 then
		return;
	end
	
	_TD['DPS_Mode'] = mode;

	TDButton_Fetch();
	
	if _TD['DPS_OnEnable'] then
		_TD['DPS_OnEnable']();
	end

	TDDps_Frame:SetScript('OnUpdate', TDDps_OnUpdate);
	
	_TD['DPS_Enabled'] = 1;
	print(_tdSuccess .. TDDpsName .. ': Enabled');
end

----------------------------------------------
-- Event Script, Target Change, Specializaton Change
----------------------------------------------
function TDDps_InvokeNextSpell()
	-- invoke spell check
	local oldSkill = DPS_Skill;
	
	DPS_Skill = _TD['DPS_NextSpell']();

	if (oldSkill ~= DPS_Skill or oldSkill == nil) and DPS_Skill ~= nil then
		TDButton_GlowNextSpellId(DPS_Skill);
	end
end

----------------------------------------------
-- Event Script, Target Change, Specializaton Change
----------------------------------------------
function TDDps_OnEvent(self, event)
	if TDDps_Frame.rotationEnabled then
		if event == 'PLAYER_TARGET_CHANGED' then
			if (UnitIsFriend('player', 'target')) then
				return;
			else
				TDDps_InvokeNextSpell();
			end
		elseif event == 'ACTIVE_TALENT_GROUP_CHANGED' then
			TDDps_LoadModule();
		end
	end
	if event == 'PLAYER_REGEN_DISABLED' and TDDps_Options.onCombatEnter
	and not TDDps_Frame.rotationEnabled then
		print(_tdSuccess .. TDDpsName .. ': Auto enable on combat!');
		TDDps_Frame.rotationEnabled = true;
		TDDps_LoadModule();
	end
--	if event == 'PLAYER_REGEN_ENABLED' then
--		print(_tdSuccess .. TDDpsName .. ': Auto disable on combat!');
--		TDDps_Frame.rotationEnabled = false;
--		TDDps_DisableAddon();
--	end
end

----------------------------------------------
-- Update script (timer)
----------------------------------------------
function TDDps_OnUpdate(self, elapsed)
	_DPS_time = _DPS_time + elapsed;
	if _DPS_time >= TDDps_Options.interval then
		_DPS_time = 0;
		TDDps_InvokeNextSpell();
	end
end

----------------------------------------------
-- Load appropriate addon for class
----------------------------------------------
function TDDps_LoadModule()

	TDDps_Frame.rotationEnabled = true;

	local class = UnitClass('player');
	class = class:gsub(' ', '');
	local module = 'TDDps_' .. class;

	if not IsAddOnLoaded(module) then
		LoadAddOn(module)
	end

	if not IsAddOnLoaded(module) then
		print(_tdError .. TDDpsName .. ': Could not find class module.');
		return;
	end

	local mode = GetSpecialization();
	local init = module .. '_EnableAddon';

	_G[init](mode);
end

TDDps_InitAddon();