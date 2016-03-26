
-- Global cooldown spell id
_GlobalCooldown		= 61304;

-- Bloodlust effects
_Bloodlust			= 2825;
_TimeWrap			= 80353;
_Heroism			= 32182;
_AncientHysteria	= 90355;
_Netherwinds		= 160452;
_DrumsOfFury		= 178207;
_Exhaustion			= 57723;

local _Bloodlusts = {_Bloodlust, _TimeWrap, _Heroism, _AncientHysteria, _Netherwinds, _DrumsOfFury};

----------------------------------------------
-- Current Specialisation name
----------------------------------------------
function TD_SpecName()
	local currentSpec = GetSpecialization();
	local currentSpecName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or 'None';
	return currentSpecName;
end

----------------------------------------------
-- Is talent enabled
----------------------------------------------
function TD_TalentEnabled(talent)
	local found = false;
	for i=1,7 do
		for j=1,3 do 
			local id, n, x, sel = GetTalentInfo(i,j,GetActiveSpecGroup());
			if (id == talent or n == talent) and sel then
				found = true;
			end
		end
	end
	return found;
end

----------------------------------------------
-- Is aura on player
----------------------------------------------
function TD_Aura(name, atLeast)
	atLeast = atLeast or 0.2;
	local spellName = GetSpellInfo(name);
	local _, _, _, count, _, _, expirationTime = UnitAura('player', spellName); 
	if expirationTime ~= nil and (expirationTime - GetTime()) > atLeast then
		return true, count;
	end
	return false, 0;
end


----------------------------------------------
-- Is aura on target
----------------------------------------------
function TD_TargetAura(name, TMinus)
	TMinus = TMinus or 0;
	local spellName = GetSpellInfo(name) or name;
	local _, _, _, _, _, _, expirationTime = UnitAura('target', spellName, nil, 'PLAYER|HARMFUL'); 
	if expirationTime ~= nil and (expirationTime - GetTime()) > TMinus then
		return true;
	end
	return false;
end

----------------------------------------------
-- When current cast will end
----------------------------------------------
function TD_EndCast()
	local t = GetTime();
	local c = t * 1000;
	local spell, _, _, _, _, endTime = UnitCastingInfo('player');
	local gstart, gduration = GetSpellCooldown(_GlobalCooldown);
	local gcd = gduration - (t - gstart);
	if gcd < 0 then gcd = 0; end;
	if endTime == nil then
		return 0, '', gcd;
	end
	return (endTime - c)/1000, spell, gcd;
end

----------------------------------------------
-- Target Percent Health
----------------------------------------------
function TD_TargetPercentHealth()
	local health = UnitHealth('target');
	if health <= 0 then
		return 0;
	end;
	local healthMax = UnitHealthMax('target');
	if healthMax <= 0 then
		return 0;
	end;
	return health/healthMax;
end

----------------------------------------------
-- Simple calculation of global cooldown
----------------------------------------------
function TD_GlobalCooldown()
	local haste = UnitSpellHaste('player');
	local gcd = 1.5 / ((haste / 100) + 1);
	if gcd < 1 then
		gcd = 1;
	end
	return gcd;
end


----------------------------------------------
-- Stacked spell CD, charges and max charges
----------------------------------------------
function TD_SpellCharges(spell)
	local currentCharges, maxCharges, cooldownStart, cooldownDuration = GetSpellCharges(spell);
	local cd = cooldownDuration - (GetTime() - cooldownStart);
	if cd > cooldownDuration then
		cd = 0;
	end
	return cd, currentCharges, maxCharges;
end

----------------------------------------------
-- Is Spell Available
----------------------------------------------
function TD_SpellAvailable(spell, minus)
	local cd = TD_Cooldown(spell, minus);
	return cd <= 0, cd;
end

----------------------------------------------
-- Spell Cooldown
----------------------------------------------
function TD_Cooldown(spell, minus)
	minus = minus or 0;
	local start, duration, enabled = GetSpellCooldown(spell);
	if enabled and duration == 0 and start == 0 then
		return 0;
	elseif enabled then
		return (duration - (GetTime() - start) - minus);
	else
		return 100000;
	end;
end

----------------------------------------------
-- Current or Future Mana Percent
----------------------------------------------
function TD_Mana(minus, afterTime)
	local _, casting = GetManaRegen();
	local mana = UnitPower('player', 0) - minus + (casting * afterTime);
	return mana / UnitPowerMax('player', 0), mana;
end

----------------------------------------------
-- Is bloodlust or similar effect
----------------------------------------------
function TD_Bloodlust(minus)
	minus = minus or 0;
	-- @TODO: detect exhausted/seated debuff instead of 6 auras
	for k, v in pairs (_Bloodlusts) do
		if TD_Aura(v, minus) then return true; end
	end

	return false;
end
