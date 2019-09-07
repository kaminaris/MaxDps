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

function MaxDps:EnableRotationModule()

	MaxDps.Description = "Class Module [Spec1, Spec2, Spec3]";
	MaxDps.ModuleOnEnable = MaxDps.Class.CheckTalents;

	MaxDps.NextSpell = MaxDps.Class.Rotation;
end

function MaxDps.Class.Rotation()
	local timeShift, currentSpell, gcd = MaxDps:EndCast();

	return _Spell;
end