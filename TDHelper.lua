
----------------------------------------------
-- Current Specialisation name
----------------------------------------------
function TDSpecName() 
	local currentSpec = GetSpecialization();
	local currentSpecName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or "None";
	return currentSpecName;
end

----------------------------------------------
-- Is talent enabled
----------------------------------------------
function TDTalentEnabled(talent)
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
function TDAura(name, atLeast)
	atLeast = atLeast or 0.2;
	local spellName = GetSpellInfo(name);
	local _, _, _, count, _, _, expirationTime = UnitAura("player", spellName); 
	if expirationTime ~= nil and (expirationTime - GetTime()) > atLeast then
		return true, count;
	end
	return false, 0;
end


----------------------------------------------
-- Is aura on target
----------------------------------------------
function TDTargetAura(name, TMinus)
	TMinus = TMinus or 0;
	local spellName = GetSpellInfo(name) or name;
	local _, _, _, _, _, _, expirationTime = UnitAura("target", spellName, nil, 'PLAYER|HARMFUL'); 
	if expirationTime ~= nil and (expirationTime - GetTime()) > TMinus then
		return true;
	end
	return false;
end

----------------------------------------------
-- When current cast will end
----------------------------------------------
function TDEndCast()
	local c = GetTime()*1000;
	local spell, _, _, _, _, endTime = UnitCastingInfo("player");
	if endTime == nil then
		return 0, "";
	end
	return (endTime - c)/1000, spell;
end

----------------------------------------------
-- Target Percent Health
----------------------------------------------
function TD_TargetPercentHealth()
	local health = UnitHealth("target");
	if health <= 0 then
		return 0;
	end;
	local healthMax = UnitHealthMax("target");
	if healthMax <= 0 then
		return 0;
	end;
	return health/healthMax;
end

----------------------------------------------
-- Simple calculation of global cooldown
----------------------------------------------
function TDDps_GlobalCooldown()
	local haste = UnitSpellHaste("player");
	local gcd = 1.5 / ((haste / 100) + 1);
	if gcd < 1 then
		gcd = 1;
	end
	return gcd;
end


----------------------------------------------
-- Stacked spell CD, charges and max charges
----------------------------------------------
function TDDps_SpellCharges(spell)
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
function TDDps_SpellCooldown(spell, minus)
	minus = minus or 0;
	local start, duration, enabled = GetSpellCooldown(spell);
	if enabled and duration == 0 and start == 0 then
		return true;
	elseif enabled then
		return (duration - (GetTime() - start) - minus) < 0.1;
	else
		return false;
	end;
end

----------------------------------------------
-- Real spell cooldown
----------------------------------------------
function TDDps_SpellCooldownReal(spell)
	local start, duration, enabled = GetSpellCooldown(spell);
	if enabled and duration == 0 and start == 0 then
		return 0;
	elseif enabled then
		return (duration - (GetTime() - start));
	else
		return false;
	end;
end
