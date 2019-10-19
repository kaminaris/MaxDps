--- @type MaxDps MaxDps
local _, MaxDps = ...;

-- Global cooldown spell id
local _GlobalCooldown	= 61304;

-- Bloodlust effects
local _Bloodlust		= 2825;
local _TimeWrap			= 80353;
local _Heroism			= 32182;
local _AncientHysteria	= 90355;
local _Netherwinds		= 160452;
local _DrumsOfFury		= 178207;
local _Exhaustion		= 57723;


local _Bloodlusts = {_Bloodlust, _TimeWrap, _Heroism, _AncientHysteria, _Netherwinds, _DrumsOfFury};

-- Global functions
local UnitAura = UnitAura;
local pairs = pairs;
local ipairs = ipairs;
local StringSplit = strsplit;
local Select = select;
local TableInsert = tinsert;
local GetTalentInfo = GetTalentInfo;
local C_AzeriteEmpoweredItem = C_AzeriteEmpoweredItem;
local GetSpecialization = GetSpecialization;
local GetSpecializationInfo = GetSpecializationInfo;
local AzeriteUtil = AzeriteUtil;
local C_AzeriteEssence = C_AzeriteEssence;
local FindSpellOverrideByID = FindSpellOverrideByID;
local UnitCastingInfo = UnitCastingInfo;
local GetTime = GetTime;
local GetSpellCooldown = GetSpellCooldown;
local GetSpellInfo = GetSpellInfo;
local UnitGUID = UnitGUID;
local GetSpellBaseCooldown = GetSpellBaseCooldown;
local IsSpellInRange = IsSpellInRange;
local UnitSpellHaste = UnitSpellHaste;
local GetSpellCharges = GetSpellCharges;
local C_NamePlate = C_NamePlate;
local UnitPower = UnitPower;
local UnitPowerMax = UnitPowerMax;
local UnitHealth = UnitHealth;
local UnitHealthMax = UnitHealthMax;
local IsEquippedItem = IsEquippedItem;
local GetManaRegen = GetManaRegen;
local GetSpellTabInfo = GetSpellTabInfo;
local GetSpellBookItemInfo = GetSpellBookItemInfo;
local GetSpellBookItemName = GetSpellBookItemName;
local IsInInstance = IsInInstance;
local IsItemInRange = IsItemInRange;
local UnitThreatSituation = UnitThreatSituation;


-----------------------------------------------------------------
--- Internal replacement for UnitAura that no longer has ability
--- to filter by spell name
-----------------------------------------------------------------

function MaxDps:IntUnitAura(unit, nameOrId, filter, timeShift)
	local aura = {
		name           = nil,
		up             = false,
		upMath		   = 0,
		count          = 0,
		expirationTime = 0,
		remains        = 0,
		refreshable    = true -- well if it doesn't exist, then it is refreshable
	};

	local i = 1;
	local t = GetTime();

	while true do
		local name, _, count, _, duration, expirationTime, _, _, _, id = UnitAura(unit, i, filter);
		if not name then
			break;
		end

		if name == nameOrId or id == nameOrId then
			local remains = 0;

			if expirationTime == nil then
				remains = 0;
			elseif (expirationTime - t) > timeShift then
				remains = expirationTime - t - timeShift;
			elseif expirationTime == 0 then
				remains = 99999;
			end

			if count == 0 then
				count = 1;
			end

			return {
				name           = name,
				up             = remains > 0,
				upMath		   = remains > 0 and 1 or 0,
				count          = count,
				expirationTime = expirationTime,
				remains        = remains,
				refreshable    = remains < 0.3 * duration,
			};
		end

		i = i + 1;
	end

	return aura;
end

function MaxDps:CollectAura(unit, timeShift, output, filter)
	filter = filter and filter or (unit == 'target' and 'PLAYER|HARMFUL' or nil);

	local t = GetTime();
	local i = 1;
	for k, v in pairs(output) do output[k] = nil; end

	while true do
		local name, _, count, _, duration, expirationTime, _, _, _, id = UnitAura(unit, i, filter);
		if not name then
			break;
		end

		local remains = 0;

		if expirationTime == nil then
			remains = 0;
		elseif (expirationTime - t) > timeShift then
			remains = expirationTime - t - timeShift;
		elseif expirationTime == 0 then
			remains = 99999;
		end

		if count == 0 then
			count = 1;
		end

		output[id] = {
			name           = name,
			up             = remains > 0,
			upMath		   = remains > 0 and 1 or 0,
			count          = count,
			expirationTime = expirationTime,
			remains        = remains,
			duration       = duration,
			refreshable    = remains < 0.3 * duration,
		};

		i = i + 1;
	end
end

local auraMetaTable = {
	__index = function()
		return {
			up          = false,
			upMath		= 0,
			count       = 0,
			remains     = 0,
			duration    = 0,
			refreshable = true,
		};
	end
};

MaxDps.PlayerAuras = setmetatable({}, auraMetaTable);
MaxDps.TargetAuras = setmetatable({}, auraMetaTable);
MaxDps.PlayerCooldowns = setmetatable({}, {
	__index = function(table, key)
		return MaxDps:CooldownConsolidated(key, MaxDps.FrameData.timeShift);
	end
});
MaxDps.ActiveDots = setmetatable({}, {
	__index = function(table, key)
		return MaxDps:DebuffCounter(key, MaxDps.FrameData.timeShift);
	end
});

function MaxDps:CollectAuras()
	self:CollectAura('player', self.FrameData.timeShift, self.PlayerAuras);
	self:CollectAura('target', self.FrameData.timeShift, self.TargetAuras);
	return self.PlayerAuras, self.TargetAuras;
end

function MaxDps:DumpAuras()
	print('Player Auras');
	for id, aura in pairs(self.PlayerAuras) do
		print(aura.name .. '('.. id ..'): ' .. aura.count);
	end

	print('Target Auras');
	for id, aura in pairs(self.TargetAuras) do
		print(aura.name .. '('.. id ..'): ' .. aura.count);
	end
end

-----------------------------------------------------------------
--- Talents and specializations functions
-----------------------------------------------------------------

function MaxDps:SpecName()
	local currentSpec = GetSpecialization();
	local currentSpecName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or 'None';
	return currentSpecName;
end

function MaxDps:CheckTalents()
	self.PlayerTalents = {};

	for talentRow = 1, 7 do
		for talentCol = 1, 3 do
			local _, name, _, sel, _, id = GetTalentInfo(talentRow, talentCol, 1);
			if sel then
				self.PlayerTalents[id] = 1;
			end
		end
	end
end

MaxDps.isMelee = false;
function MaxDps:CheckIsPlayerMelee()
	self.isMelee = false;
	local class = select(3, UnitClass('player'));
	local spec = GetSpecialization();

	-- Warrior, Paladin, Rogue, DeathKnight, Monk, Demon Hunter
	if class == 1 or class == 2 or class == 4 or class == 6 or class == 10 or class == 12 then
		self.isMelee = true;
	elseif class == 3 and spec == 3 then -- Survival Hunter
		self.isMelee = true;
	elseif class == 7 and spec == 2 then -- Enh Shaman
		self.isMelee = true;
	elseif class == 11 and (spec == 2 or spec == 3) then -- Guardian or Feral Druid
		self.isMelee = true;
	end

	return self.isMelee;
end

function MaxDps:HasTalent(talent)
	return self.PlayerTalents[talent];
end

function MaxDps:TalentEnabled(talent)
	self:Print(self.Colors.Error .. 'MaxDps:TalentEnabled is deprecated, please use table `talents` to check talents');
end

function MaxDps:GetAzeriteTraits()
	local t = setmetatable({}, {__index = function() return 0; end});

	for equipSlotIndex, itemLocation in AzeriteUtil.EnumerateEquipedAzeriteEmpoweredItems() do
		local tierInfo = C_AzeriteEmpoweredItem.GetAllTierInfo(itemLocation);
		for i = 1, #tierInfo do
			for x = 1, #tierInfo[i].azeritePowerIDs do
				local powerId = tierInfo[i].azeritePowerIDs[x];
				if C_AzeriteEmpoweredItem.IsPowerSelected(itemLocation, powerId) then
					local spellId = C_AzeriteEmpoweredItem.GetPowerInfo(powerId).spellID;
					if t[spellId] then
						t[spellId] = t[spellId] + 1;
					else
						t[spellId] = 1;
					end

				end

			end
		end
	end

	self.AzeriteTraits = t;
	return t;
end

function MaxDps:GetAzeriteEssences()
	if not self.AzeriteEssences then
		self.AzeriteEssences = {
			major = false,
			minor = {}
		};
	else
		self.AzeriteEssences.major = false;
		self.AzeriteEssences.minor = {};
	end

	local result = self.AzeriteEssences;

	local milestones = C_AzeriteEssence.GetMilestones();
	if not milestones then
		return result;
	end

	for i, milestoneInfo in ipairs(milestones) do
		local spellId = C_AzeriteEssence.GetMilestoneSpell(milestoneInfo.ID);
		local essenceId = C_AzeriteEssence.GetMilestoneEssence(milestoneInfo.ID);
		if milestoneInfo.unlocked then
			if milestoneInfo.slot == Enum.AzeriteEssence.MainSlot then
				-- Major
				if essenceId and spellId then
					local realSpellId = FindSpellOverrideByID(spellId);
					result.major = realSpellId;
				end
			elseif milestoneInfo.slot == Enum.AzeriteEssence.PassiveOneSlot or
				milestoneInfo.slot == Enum.AzeriteEssence.PassiveTwoSlot
			then
				if essenceId and spellId then
					local realSpellId = FindSpellOverrideByID(spellId);
					result.minor[realSpellId] = true;
				end
			end
		end
	end

	return result;
end

local bfaConsumables = {
	[169299] = true, -- Potion of Unbridled Fury
	[168529] = true, -- Potion of Empowered Proximity
	[168506] = true, -- Potion of Focused Resolve
	[168489] = true, -- Superior Battle Potion of Agility
	[168498] = true, -- Superior Battle Potion of Intellect
	[168500] = true, -- Superior Battle Potion of Strength
	[163223] = true, -- Battle Potion of Agility
	[163222] = true, -- Battle Potion of Intellect
	[163224] = true, -- Battle Potion of Strength
	[152559] = true, -- Potion of Rising Death
	[152560] = true, -- Potion of Bursting Blood
};

function MaxDps:GlowConsumables()
	if self.db.global.disableConsumables then
		return
	end

	for itemId, _ in pairs(bfaConsumables) do
		local itemSpellId = self.ItemSpells[itemId];

		if itemSpellId then
			self:GlowCooldown(itemSpellId, self:ItemCooldown(itemId, 0).ready);
		end
	end
end

function MaxDps:GlowEssences()
	local fd = MaxDps.FrameData;
	if not fd.essences.major then
		return
	end

	MaxDps:GlowCooldown(fd.essences.major, fd.cooldown[fd.essences.major].ready);
end

function MaxDps:DumpAzeriteTraits()
	for id, rank in pairs(self.AzeriteTraits) do
		local n = GetSpellInfo(id);
		print(n .. ' (' .. id .. '): ' .. rank);
	end
end

-----------------------------------------------------------------
--- Aura helper functions
-----------------------------------------------------------------

-- Aura on specific unit
-- @deprecated
function MaxDps:UnitAura(auraId, timeShift, unit, filter)
	timeShift = timeShift or 0;
	local aura = self:IntUnitAura(unit, auraId, filter, timeShift);

	return aura.up, aura.count, aura.remains;
end

-- Aura on player
function MaxDps:Aura(name, timeShift)
	return self:UnitAura(name, timeShift, 'player');
end


-- Aura on target
function MaxDps:TargetAura(name, timeShift)
	return self:UnitAura(name, timeShift, 'target');
end

-----------------------------------------------------------------
--- Casting info helpers
-----------------------------------------------------------------

function MaxDps:EndCast(target)
	target = target or 'player';
	local t = GetTime();
	local c = t * 1000;
	local gcd = 0;
	local _, _, _, _, endTime, _, _, _, spellId = UnitCastingInfo(target or 'player');
	if not spellId then
		_, _, _, _, endTime, _, _, spellId = UnitChannelInfo(target or 'player');
	end

	-- we can only check player global cooldown
	if target == 'player' then
		local gstart, gduration = GetSpellCooldown(_GlobalCooldown);
		gcd = gduration - (t - gstart);

		if gcd < 0 then
			gcd = 0;
		end;
	end

	if not endTime then
		return gcd, nil, gcd;
	end

	local timeShift = (endTime - c) / 1000;
	if gcd > timeShift then
		timeShift = gcd;
	end

	return timeShift, spellId, gcd;
end

function MaxDps:GlobalCooldown(spellId)
	local baseGCD = 1.5;
	if spellId then
		baseGCD = select(2, GetSpellBaseCooldown(spellId)) / 1000;
	end
	local haste = UnitSpellHaste('player');
	local gcd = baseGCD / ((haste / 100) + 1);

	if gcd < 0.75 then
		gcd = 0.75;
	end

	return gcd;
end

function MaxDps:AttackHaste()
	local haste = UnitSpellHaste('player');
	return 1/((haste / 100) + 1);
end

-----------------------------------------------------------------
--- Spell helpers
-----------------------------------------------------------------

function MaxDps:ItemCooldown(itemId, timeShift)
	local start, duration, enabled = GetItemCooldown(itemId);

	local t = GetTime();
	local remains = 100000;

	if enabled and duration == 0 and start == 0 then
		remains = 0;
	elseif enabled then
		remains = duration - (t - start) - timeShift;
	end

	return {
		ready           = remains <= 0,
		remains         = remains,
	};
end

function MaxDps:CooldownConsolidated(spellId, timeShift)
	timeShift = timeShift or 0;
	local remains = 100000;
	local t = GetTime();

	local enabled;
	local charges, maxCharges, start, duration = GetSpellCharges(spellId);
	local fullRecharge, partialRecharge = 0, 0;

	if charges == nil then
		start, duration, enabled = GetSpellCooldown(spellId);
		maxCharges = 1;

		if enabled and duration == 0 and start == 0 then
			remains = 0;
		elseif enabled then
			remains = duration - (t - start) - timeShift;
		end

		fullRecharge = remains;
		partialRecharge = remains;
	else
		remains = duration - (t - start) - timeShift;

		if remains > duration then
			remains = 0;
		end

		if remains > 0 then
			charges = charges + (1 - (remains / duration));
		end

		fullRecharge = (maxCharges - charges) * duration;
		partialRecharge = remains;

		if charges >= 1 then
			remains = 0;
		end
	end

	return {
		duration        = GetSpellBaseCooldown(spellId) / 1000,
		ready           = remains <= 0,
		remains         = remains,
		fullRecharge    = fullRecharge,
		partialRecharge = partialRecharge,
		charges         = charges,
		maxCharges      = maxCharges
	};
end

-- @deprecated
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

-- @deprecated
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

-- @deprecated
function MaxDps:SpellAvailable(spell, timeShift)
	local cd = MaxDps:Cooldown(spell, timeShift);
	return cd <= 0, cd;
end

-----------------------------------------------------------------
--- Utility functions
-----------------------------------------------------------------

function MaxDps:TargetPercentHealth(unit)
	local health = UnitHealth(unit or 'target');
	if health <= 0 then
		return 0;
	end;

	local healthMax = UnitHealthMax(unit or 'target');
	if healthMax <= 0 then
		return 0;
	end;

	return health/healthMax;
end

function MaxDps:SetBonus(items)
	local c = 0;
	for _, item in ipairs(items) do
		if IsEquippedItem(item) then
			c = c + 1;
		end
	end
	return c;
end

function MaxDps:Mana(minus, timeShift)
	local _, casting = GetManaRegen();
	local mana = UnitPower('player', 0) - minus + (casting * timeShift);
	return mana / UnitPowerMax('player', 0), mana;
end


function MaxDps:ExtractTooltip(spell, pattern)
	local _pattern = gsub(pattern, "%%s", "([%%d%.,]+)");

	if not MaxDpsSpellTooltip then
		CreateFrame('GameTooltip', 'MaxDpsSpellTooltip', UIParent, 'GameTooltipTemplate');
		MaxDpsSpellTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	end
	MaxDpsSpellTooltip:SetSpellByID(spell);

	for i = 2, 4 do
		local line = _G['MaxDpsSpellTooltipTextLeft' .. i];
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
		local bookType = 'spell';
		local myIndex = MaxDps:FindSpellInSpellbook(spell)
		if myIndex then
			return IsSpellInRange(myIndex, bookType, unit);
		end
		return inRange;
	end

	return inRange;
end

function MaxDps:TargetsInRange(spell)
	local count = 0;

	for _, unit in ipairs(self.visibleNameplates) do
		if MaxDps:IsSpellInRange(spell, unit) == 1 then
			count = count + 1;
		end
	end

	return count;
end

function MaxDps:ThreatCounter()
	local count = 0;
	local units = {};

	for _, unit in ipairs(self.visibleNameplates) do
		if UnitThreatSituation('player', unit) ~= nil then
			count = count + 1;
			TableInsert(units, unit);
		else
			local npcId = Select(6, StringSplit('-', UnitGUID(unit)));
			npcId = tonumber(npcId);
			-- Risen Soul, Tormented Soul, Lost Soul
			if npcId == 148716 or npcId == 148893 or npcId == 148894 then
				count = count + 1;
				TableInsert(units, unit);
			end
		end
	end

	return count, units;
end

function MaxDps:DebuffCounter(spellId, timeShift)
	local count, totalRemains, totalCount, totalCountRemains = 0, 0, 0, 0;

	for _, unit in ipairs(self.visibleNameplates) do
		local aura = MaxDps:IntUnitAura(unit, spellId, 'PLAYER|HARMFUL', timeShift);
		if aura.up then
			count = count + 1;
			totalCount = totalCount + aura.count;
			totalRemains = totalRemains + aura.remains;
			totalCountRemains = totalRemains + (aura.remains * aura.count);
		end
	end

	return count, totalRemains, totalCount, totalCountRemains;
end

function MaxDps:SmartAoe(itemId)
	if self.db.global.forceSingle then
		return 1;
	end

	local _, instanceType = IsInInstance();
	local count, units = self:ThreatCounter();

	local itemToCheck = itemId or 18904;

	-- 5 man content, we count battleground also as small party
	if self.isMelee then
		-- 8 yards range
		itemToCheck = itemId or 61323;
	elseif instanceType == 'pvp' or instanceType == 'party' then
		-- 30 yards range
		itemToCheck = itemId or 7734;
	elseif instanceType == 'arena' and instanceType == 'raid' then
		-- 35 yards range
		itemToCheck = itemId or 18904;
	end

	count = 0;
	for i = 1, #units do
		-- 8 yards range check
		if IsItemInRange(itemToCheck, units[i]) then
			count = count + 1;
		end
	end

	if WeakAuras then WeakAuras.ScanEvents('MAXDPS_TARGET_COUNT', count); end
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