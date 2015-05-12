-- Author      : Kaminari
-- Create Date : 13:03 2015-04-20

local _Bloodthirst		= 23881;
local _WildStrike		= 100130;
local _RagingBlow		= 85288;
local _Execute			= 5308;
local _BladeStorm		= 46924;
local _StormBolt		= 107570;
local _DragonRoar		= 118000;
local _BerserkerRage	= 18499;
local _Ravager			= 152277;
local _Recklessness		= 1719;

-- auras
local _Enrage			= 12880;
local _Bloodsurge		= 46916
local _SuddenDeath		= 29725
local _RagingBlowAura	= 131116

-- talents
local _isSuddenDeath = false;
local _isUnquenchableThirst = false;
local _isStormBolt = false;
local _isDragonRoar = false;
local _isUnquenchableThirst = false;
local _isRavager = false;
local _rageMax = 100;

--flags
local _RecklessnessHigh = false;

----------------------------------------------
-- Pre enable, checking talents
----------------------------------------------
TDWarriorDps_CheckTalents = function()
	_isSuddenDeath = TDTalentEnabled("Sudden Death");
	_isUnquenchableThirst = TDTalentEnabled("Unquenchable Thirst");
	_isRavager = TDTalentEnabled("Ravager");
	_isStormBolt = TDTalentEnabled("Storm Bolt");
	_isDragonRoar = TDTalentEnabled("Dragon Roar");

	_rageMax = UnitPowerMax('player', SPELL_POWER_RAGE);
end

----------------------------------------------
-- Enabling Addon
----------------------------------------------
function TDWarriorDps_EnableAddon(mode)
	mode = mode or 1;
	_TD["DPS_Description"] = "TD Warrior DPS supports: Fury";
	_TD["DPS_OnEnable"] = TDWarriorDps_CheckTalents;
	if mode == 1 then
		_TD["DPS_NextSpell"] = TDWarriorDps_Fury
	end;
	TDDps_EnableAddon();
end

----------------------------------------------
-- Main rotation: Elemental
----------------------------------------------
TDWarriorDps_Fury = function()

	local lcd, currentSpell = TDEndCast();

	local berserRage = TDDps_SpellCooldown(_BerserkerRage, lcd);
	local ravager = TDDps_SpellCooldown(_Ravager, lcd);
	local sb = TDDps_SpellCooldown(_StormBolt, lcd);
	local dr = TDDps_SpellCooldown(_DragonRoar, lcd);
	local reck = TDDps_SpellCooldown(_Recklessness, lcd);
	local enrage = TDAura(_Enrage);
	local rb, rbCount = TDAura(_RagingBlowAura);
	local rage = UnitPower('player', SPELL_POWER_RAGE);
	local bs = TDAura(_Bloodsurge);
	local sd = TDAura(_SuddenDeath);

	local ph = TD_TargetPercentHealth();

	if _Recklessness and not _RecklessnessHigh then
		TDGlowIndependent(_Recklessness, 'reck');
		_RecklessnessHigh = true;
	elseif _RecklessnessHigh then
		TDClearGlowIndependent(_Recklessness, 'reck');
		_RecklessnessHigh = false;
	end

	if berserRage and not enrage then
		return _BerserkerRage;
	end

	if (rage/_rageMax) >= 0.9 and ph > 0.2 then
		return _WildStrike;
	end

	if sd then
		return _Execute;
	end

	if rbCount >= 2 and ph > 0.2 then
		return _RagingBlow;
	end

	if not enrage and (_isUnquenchableThirst or rage < 80) then
		return _Bloodthirst;
	end

	if _isRavager and ravager then
		return _Ravager;
	end

	if _isStormBolt and sb then
		return _StormBolt;
	end

	if _isDragonRoar and dr then
		return _DragonRoar;
	end

	if rage >= 30 and ph < 0.2 and enrage then
		return _Execute;
	end

	if bs then
		return _WildStrike;
	end

	if rbCount > 0 then
		return _RagingBlow;
	end

	return _Bloodthirst;
end