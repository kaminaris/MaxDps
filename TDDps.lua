_TD = _TD or {};

_TD['DPS_Enabled'] 	= 0;
_TD['DPS_OnEnable'] = nil;
_TD['DPS_NextSpell'] = nil;
_TD['DPS_Description'] = '';
_TD['DPS_Mode'] = 1;

DPS_Skill = nil;

local _DPS_time = 0;
local TDDps_Frame = CreateFrame('frame');

----------------------------------------------
-- Disable dps addon functionality
----------------------------------------------
function TDDps_DisableAddon()
	TDDps_Frame:Hide();
	
	TDDps_Frame:UnregisterAllEvents();
	TDDps_Frame:SetScript('OnUpdate', nil);
	TDDps_Frame:SetScript('OnEvent', nil);
	
	print(_TD['DPS_Description']);
	
	DPS_Skill = nil;
	_TD['DPS_Enabled'] = 0;
end

----------------------------------------------
-- Enable dps addon functionality
----------------------------------------------
function TDDps_EnableAddon(mode)
	TDDps_DisableAddon();
	
	print('enabling');
	
	if _TD['DPS_NextSpell'] == nil then
		print('TDDPS: No addon selected, cannot enable');
		return;
	end
	
	if _TD['DPS_Enabled'] == 1 then
		return;
	end
	
	_TD['DPS_Mode'] = mode;
	
	TDDps_Frame:Show();
	
	TDDps_Frame:RegisterEvent('PLAYER_TARGET_CHANGED');
	TDDps_Frame:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED');

	TDButton_Fetch();
	
	if _TD['DPS_OnEnable'] then
		_TD['DPS_OnEnable']();
	end
	
	TDDps_Frame:SetScript('OnUpdate', TDDps_OnUpdate);
	TDDps_Frame:SetScript('OnEvent', TDDps_OnEvent);
	
	_TD['DPS_Enabled'] = 1; 
	print('enabled');
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
function TDDps_OnEvent(event)
	if event == 'PLAYER_TARGET_CHANGED' then
		if (UnitIsFriend('player', 'target')) then
			TDButton_GlowClear();
			return;
		else
			TDDps_InvokeNextSpell();
		end
	elseif event == 'ACTIVE_TALENT_GROUP_CHANGED' then
		TDDps_CheckPlayer();
	end
end

----------------------------------------------
-- Update script (timer)
----------------------------------------------
function TDDps_OnUpdate(self, elapsed)
	_DPS_time = _DPS_time + elapsed;
    if _DPS_time >= 0.15 then
		_DPS_time = 0;
		TDDps_InvokeNextSpell();
    end
end

----------------------------------------------
-- Load appropriate addon for class
----------------------------------------------
function TDDps_LoadModule()
	local class = UnitClass('player');
	class = class:gsub(' ', '');
	local module = 'TDDps_' .. class;

	if not IsAddOnLoaded(module) then
		LoadAddOn(module)
	end

	if not IsAddOnLoaded(module) then
		print('TDDps: Could not find class module.');
		return;
	end

	local mode = GetSpecialization();
	local init = module .. '_EnableAddon';

	_G[init](mode);
end

-- PLAYER_ALIVE