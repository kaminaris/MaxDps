
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

local INF = 2147483647;

local _Bloodlusts = {_Bloodlust, _TimeWrap, _Heroism, _AncientHysteria, _Netherwinds, _DrumsOfFury};

function MaxDps:SpecName()
	local currentSpec = GetSpecialization();
	local currentSpecName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or 'None';
	return currentSpecName;
end

function MaxDps:CheckTalents()
	self.PlayerTalents = {};
	self.PlayerSpec = GetActiveSpecGroup();
	for talentRow = 1, 7 do
		for talentCol = 1, 3 do
			local _, name, _, sel, _, id = GetTalentInfo(talentRow, talentCol, self.PlayerSpec);
			if sel then
				self.PlayerTalents[id] = name;
			end
		end
	end
end

function MaxDps:HasTalent(talent)
	for id, name in pairs(self.PlayerTalents) do
		if id == talent or name == talent then
			return true;
		end
	end
	return false;
end

function MaxDps:TalentEnabled(talent)
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

function MaxDps:PersistentAura(name)
	local spellName = GetSpellInfo(name);
	local aura, _, _, count = UnitAura('player', spellName);
	if aura then
		return true, count;
	end
	return false, 0;
end

function MaxDps:Aura(name, timeShift, filter)
	filter = filter or nil;
	timeShift = timeShift or 0.2;
	local spellName = GetSpellInfo(name) or name;
	local _, _, _, count, _, _, expirationTime = UnitAura('player', spellName, nil, filter);
	local time = GetTime();
	if expirationTime ~= nil and (expirationTime - time) > timeShift then
		return true, count, (expirationTime - time);
	end
	return false, 0, 0;
end

function MaxDps:UnitAura(name, timeShift, unit)
	timeShift = timeShift or 0.2;
	local spellName = GetSpellInfo(name) or name;
	local _, _, _, count, _, _, expirationTime = UnitAura(unit, spellName);
	if expirationTime ~= nil and (expirationTime - GetTime()) > timeShift then
		return true, count;
	end
	return false, 0;
end

function MaxDps:TargetAura(name, timeShift)
	timeShift = timeShift or 0;
	local spellName = GetSpellInfo(name) or name;
	local _, _, _, _, _, _, expirationTime = UnitAura('target', spellName, nil, 'PLAYER|HARMFUL');
	if expirationTime ~= nil and (expirationTime - GetTime()) > timeShift then
		local cd = expirationTime - GetTime() - (timeShift or 0);
		return true, cd;
	end
	return false, 0;
end

function MaxDps:EndCast(target)
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

function MaxDps:SameSpell(spell1, spell2)
	local spellName1 = GetSpellInfo(spell1);
	local spellName2 = GetSpellInfo(spell2);
	return spellName1 == spellName2;
end

function MaxDps:TargetPercentHealth()
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

function MaxDps:GlobalCooldown()
	local haste = UnitSpellHaste('player');
	local gcd = 1.5 / ((haste / 100) + 1);
	if gcd < 1 then
		gcd = 1;
	end
	return gcd;
end

function MaxDps:AttackHaste()
	local haste = UnitSpellHaste('player');
	return 1/((haste / 100) + 1);
end

function MaxDps:SpellCharges(spell, timeShift)
	local currentCharges, maxCharges, cooldownStart, cooldownDuration = GetSpellCharges(spell);
	if currentCharges == nil then
		local cd = MaxDps:Cooldown(spell, timeShift);
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
	if cd > 0 then
		currentCharges = currentCharges + (1 - (cd / cooldownDuration));
	end
	return cd, currentCharges, maxCharges;
end

function MaxDps:SpellAvailable(spell, timeShift)
	local cd = MaxDps:Cooldown(spell, timeShift);
	return cd <= 0, cd;
end

function MaxDps:ExtractTooltip(spell, pattern)
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

function MaxDps:Cooldown(spell, timeShift)
	local start, duration, enabled = GetSpellCooldown(spell);
	if enabled and duration == 0 and start == 0 then
		return 0;
	elseif enabled then
		return (duration - (GetTime() - start) - (timeShift or 0));
	else
		return 100000;
	end;
end

function MaxDps:Mana(minus, timeShift)
	local _, casting = GetManaRegen();
	local mana = UnitPower('player', 0) - minus + (casting * timeShift);
	return mana / UnitPowerMax('player', 0), mana;
end

function MaxDps:Bloodlust(timeShift)
	-- @TODO: detect exhausted/seated debuff instead of 6 auras
	for k, v in pairs (_Bloodlusts) do
		if MaxDps:Aura(v, timeShift or 0) then return true; end
	end

	return false;
end

MaxDps.Spellbook = {};
function MaxDps:FindSpellInSpellbook(spell)
	local spellName = GetSpellInfo(spell);
	if MaxDps.Spellbook[spellName] then
		return MaxDps.Spellbook[spellName];
	end

	local _, _, offset, numSpells = GetSpellTabInfo(2);

	local booktype = 'spell';

	for index = offset + 1, numSpells + offset do
		local spellID = select(2, GetSpellBookItemInfo(index, booktype));
		if spellID and spellName == GetSpellBookItemName(index, booktype) then
			MaxDps.Spellbook[spellName] = index;
			return index;
		end
	end

	return nil;
end

function MaxDps:IsSpellInRange(spell, unit)
	unit = unit or 'target';

	local inRange = IsSpellInRange(spell, unit);

	if inRange == nil then
		local booktype = 'spell';
		local myIndex = MaxDps:FindSpellInSpellbook(spell)
		if myIndex then
			return IsSpellInRange(myIndex, booktype, unit);
		end
		return inRange;
	end
	return inRange;
end

function MaxDps:TargetsInRange(spell)
	local count = 0;
	for i = 0, 1000, 1 do
		local np = _G['NamePlate' .. i];
		if np ~= nil and
			np:IsVisible() and
			MaxDps:IsSpellInRange(spell, np.UnitFrame.unit) == 1
		then
			count = count + 1;
		end
	end

	return count;
end

function MaxDps:FormatTime(left)
	local seconds = left >= 0        and math.floor((left % 60)    / 1   ) or 0;
	local minutes = left >= 60       and math.floor((left % 3600)  / 60  ) or 0;
	local hours   = left >= 3600     and math.floor((left % 86400) / 3600) or 0;
	local days    = left >= 86400    and math.floor((left % 31536000) / 86400) or 0;
	local years   = left >= 31536000 and math.floor( left / 31536000) or 0;

	if years > 0 then
		return string.format("%d [Y] %d [D] %d:%d:%d [H]", years, days, hours, minutes, seconds);
	elseif days > 0 then
		return string.format("%d [D] %d:%d:%d [H]", days, hours, minutes, seconds);
	elseif hours > 0 then
		return string.format("%d:%d:%d [H]", hours, minutes, seconds);
	elseif minutes > 0 then
		return string.format("%d:%d [M]", minutes, seconds);
	else
		return string.format("%d [S]", seconds);
	end
end