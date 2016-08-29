
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
function TD_Aura(name, timeShift)
	timeShift = timeShift or 0.2;
	local spellName = GetSpellInfo(name);
	local _, _, _, count, _, _, expirationTime = UnitAura('player', spellName); 
	if expirationTime ~= nil and (expirationTime - GetTime()) > timeShift then
		return true, count;
	end
	return false, 0;
end


----------------------------------------------
-- Is aura on target
----------------------------------------------
function TD_TargetAura(name, timeShift)
	timeShift = timeShift or 0;
	local spellName = GetSpellInfo(name) or name;
	local _, _, _, _, _, _, expirationTime = UnitAura('target', spellName, nil, 'PLAYER|HARMFUL'); 
	if expirationTime ~= nil and (expirationTime - GetTime()) > timeShift then
		local cd = expirationTime - GetTime() - (timeShift or 0);
		return true, cd;
	end
	return false, 0;
end

----------------------------------------------
-- When current cast will end
----------------------------------------------
function TD_EndCast(target)
	local t = GetTime();
	local c = t * 1000;
	local spell, _, _, _, _, endTime = UnitCastingInfo(target or 'player');
	local gstart, gduration = GetSpellCooldown(_GlobalCooldown);
	local gcd = gduration - (t - gstart);
	if gcd < 0 then gcd = 0; end;
	if endTime == nil then
		return gcd, '', gcd;
	end
	local timeShift = (endTime - c) / 1000;
	if gcd > timeShift then
		timeShift = gcd;
	end
	return timeShift, spell, gcd;
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
function TD_SpellCharges(spell, timeShift)
	local currentCharges, maxCharges, cooldownStart, cooldownDuration = GetSpellCharges(spell);
	if currentCharges == nil then
		local cd = TD_Cooldown(spell, timeShift);
		if cd <= 0 then
			return 0, 1, 0;
		else
			return cd, 0, 1;
		end
	end
	local cd = cooldownDuration - (GetTime() - cooldownStart) - (timeShift or 0);
	if cd > cooldownDuration then
		cd = 0;
	end
	return cd, currentCharges, maxCharges;
end

----------------------------------------------
-- Is Spell Available
----------------------------------------------
function TD_SpellAvailable(spell, timeShift)
	local cd = TD_Cooldown(spell, timeShift);
	return cd <= 0, cd;
end

----------------------------------------------
-- Extract tooltip number
----------------------------------------------
function TD_ExtractTooltip(spell, pattern)
	local _pattern = gsub(pattern, "%%s", "([%%d%.,]+)");

	if not TDSpellTooltip then
		CreateFrame('GameTooltip', 'TDSpellTooltip', UIParent, 'GameTooltipTemplate');
		TDSpellTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	end
	TDSpellTooltip:SetSpellByID(spell);

	for i = 2, 4 do
		local line = _G['TDSpellTooltipTextLeft' .. i];
		local text = line:GetText();

		if text then
			local cost = strmatch(text, _pattern);
			if cost then
				cost = cost and tonumber((gsub(cost, "%D", "")));
				return cost;
			end
		end
	end

	return 0;
end

----------------------------------------------
-- Spell Cooldown
----------------------------------------------
function TD_Cooldown(spell, timeShift)
	local start, duration, enabled = GetSpellCooldown(spell);
	if enabled and duration == 0 and start == 0 then
		return 0;
	elseif enabled then
		return (duration - (GetTime() - start) - (timeShift or 0));
	else
		return 100000;
	end;
end

----------------------------------------------
-- Current or Future Mana Percent
----------------------------------------------
function TD_Mana(minus, timeShift)
	local _, casting = GetManaRegen();
	local mana = UnitPower('player', 0) - minus + (casting * timeShift);
	return mana / UnitPowerMax('player', 0), mana;
end

----------------------------------------------
-- Is bloodlust or similar effect
----------------------------------------------
function TD_Bloodlust(timeShift)
	-- @TODO: detect exhausted/seated debuff instead of 6 auras
	for k, v in pairs (_Bloodlusts) do
		if TD_Aura(v, timeShift or 0) then return true; end
	end

	return false;
end
