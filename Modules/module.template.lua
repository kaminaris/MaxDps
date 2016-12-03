-- Replace all occurances of Class with Class Name ex. Warrior
-- Replace Spec1 - Spec3 with specialization names ex. Protection
-- Spells
local _Spell = 23881;

-- Talents
local _isTalent = false;
MaxDps.Class = {};

MaxDps.Class.CheckTalents = function()
	_isTalent = MaxDps:TalentEnabled('Talent Name');
	-- other checking functions
end

function MaxDps:EnableRotationModule(mode)
	mode = mode or 1;
	MaxDps.Description = "Class Module [Spec1, Spec2, Spec3]";
	MaxDps.ModuleOnEnable = MaxDps.Class.CheckTalents;
	if mode == 1 then
		MaxDps.NextSpell = MaxDps.Class.Spec1;
	end;
	if mode == 2 then
		MaxDps.NextSpell = MaxDps.Class.Spec2;
	end;
	if mode == 3 then
		MaxDps.NextSpell = MaxDps.Class.Spec3;
	end;
end

function MaxDps.Class.Spec1()
	local timeShift, currentSpell, gcd = MaxDps:EndCast();

	return _Spell;
end

function MaxDps.Class.Spec2()
	local timeShift, currentSpell, gcd = MaxDps:EndCast();

	return _Spell;
end

function MaxDps.Class.Spec3()
	local timeShift, currentSpell, gcd = MaxDps:EndCast();

	return _Spell;
end