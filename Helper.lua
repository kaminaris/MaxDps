--- @type MaxDps MaxDps
local _, MaxDps = ...;

-- Global cooldown spell id
local _GlobalCooldown = 61304;

-- Bloodlust effects
local _Bloodlust = 2825;
local _TimeWrap = 80353;
local _Heroism = 32182;
local _AncientHysteria = 90355;
local _Netherwinds = 160452;
local _DrumsOfFury = 178207;
local _Exhaustion = 57723;

local _Bloodlusts = { _Bloodlust, _TimeWrap, _Heroism, _AncientHysteria, _Netherwinds, _DrumsOfFury };

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
local GetActiveCovenantID = C_Covenants.GetActiveCovenantID;
local GetActiveSoulbindID = C_Soulbinds.GetActiveSoulbindID;
local GetSoulbindData = C_Soulbinds.GetSoulbindData;


-----------------------------------------------------------------
--- Internal replacement for UnitAura that no longer has ability
--- to filter by spell name
-----------------------------------------------------------------

function MaxDps:IntUnitAura(unit, nameOrId, filter, timeShift)
	local aura = {
		name           = nil,
		up             = false,
		upMath         = 0,
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
				upMath         = remains > 0 and 1 or 0,
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
	for k, _ in pairs(output) do
		output[k] = nil;
	end

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
			upMath         = remains > 0 and 1 or 0,
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
			upMath      = 0,
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
		print(aura.name .. '(' .. id .. '): ' .. aura.count);
	end

	print('Target Auras');
	for id, aura in pairs(self.TargetAuras) do
		print(aura.name .. '(' .. id .. '): ' .. aura.count);
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
			local _, _, _, sel, _, id = GetTalentInfo(talentRow, talentCol, 1);
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
	elseif class == 3 and spec == 3 then
		-- Survival Hunter
		self.isMelee = true;
	elseif class == 7 and spec == 2 then
		-- Enh Shaman
		self.isMelee = true;
	elseif class == 11 and (spec == 2 or spec == 3) then
		-- Guardian or Feral Druid
		self.isMelee = true;
	end

	return self.isMelee;
end

function MaxDps:HasTalent(talent)
	return self.PlayerTalents[talent];
end

function MaxDps:GetAzeriteTraits()
	local t = setmetatable({}, { __index = function()
		return 0;
	end });

	for _, itemLocation in AzeriteUtil.EnumerateEquipedAzeriteEmpoweredItems() do -- equipSlotIndex
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

	return result;
end

--- Get active covenant and soulbind Ids, use Enum.CovenantType for covenantId
---
function MaxDps:GetCovenantInfo()
	local covenantId = GetActiveCovenantID();
	local soulbindId = GetActiveSoulbindID();

	--if soulbindId == 0 then
	--	soulbindId = Soulbinds.GetDefaultSoulbindID(covenantId);
	--end

	local soulbindData = {};
	local soulbindAbilities = {};
	local soulbindConduits = {};

	if soulbindId ~= 0 then
		soulbindData = GetSoulbindData(soulbindId);

		if soulbindData.tree then
			for _, node in ipairs(soulbindData.tree.nodes) do
				if node.state == Enum.SoulbindNodeState.Selected then
					if node.spellID ~= 0 then
						soulbindAbilities[node.spellID] = true;
					end

					if node.conduitID ~= 0 then
						soulbindConduits[node.conduitID] = node.conduitRank;
					end
				end
			end
		end
	end

	self.CovenantInfo = {
		covenantId        = covenantId,
		soulbindId        = soulbindId,
		soulbindData      = soulbindData,
		soulbindAbilities = soulbindAbilities,
		soulbindConduits  = soulbindConduits,
	};

	return self.CovenantInfo;
end

--[[
	Borrowed from WeakAuras

	This is free software: you can redistribute it and/or modify it under the terms of
	the GNU General Public License version 2 as published by the Free Software
	Foundation.

	For more information see WeakAuras License
]]
--------------------------------------------
--- Legendaries
--------------------------------------------
local generalLegendaries = {
	[7100] = true, -- Echo of Eonar
	[7102] = true, -- Norgannon's Sagacity
	[7103] = true, -- Sephuz's Proclamation
	[7104] = true, -- Stable Phantasma Lure
	[7105] = true, -- Third Eye of the Jailer
	[7106] = true, -- Vitality Sacrifice
}

local allLegendaryBonusIds = {
	SHAMAN = { -- 7
		[6993] = true, -- Doom Winds
		[6997] = true, -- Jonat's Natural Focus
		[7102] = true, -- Norgannon's Sagacity
		[7106] = true, -- Vitality Sacrifice
		[6986] = true, -- Deeptremor Stone
		[6990] = true, -- Elemental Equilibrium
		[6994] = true, -- Legacy of the Frost Witch
		[6998] = true, -- Spiritwalker's Tidal Totem
		[7103] = true, -- Sephuz's Proclamation
		[6987] = true, -- Deeply Rooted Elements
		[6991] = true, -- Echoes of Great Sundering
		[6995] = true, -- Witch Doctor's Wolf Bones
		[6999] = true, -- Primal Tide Core
		[7100] = true, -- Echo of Eonar
		[7104] = true, -- Stable Phantasma Lure
		[6988] = true, -- Chains of Devastation
		[6992] = true, -- Windspeaker's Lava Resurgence
		[6996] = true, -- Primal Lava Actuators
		[7000] = true, -- Earthen Harmony
		[7159] = true, -- Maw Rattle
		[7101] = true, -- Judgment of the Arbiter
		[7105] = true, -- Third Eye of the Jailer
		[6985] = true, -- Ancestral Reminder
		[6989] = true, -- Skybreaker's Fiery Demise
	},
	WARRIOR = { -- 1
		[6962] = true, -- Enduring Blow
		[6966] = true, -- Will of the Berserker
		[6970] = true, -- Unhinged
		[7102] = true, -- Norgannon's Sagacity
		[7106] = true, -- Vitality Sacrifice
		[6955] = true, -- Leaper
		[6959] = true, -- Signet of Tormented Kings
		[6963] = true, -- Cadence of Fujieda
		[6967] = true, -- Unbreakable Will
		[6971] = true, -- Seismic Reverberation
		[7103] = true, -- Sephuz's Proclamation
		[6956] = true, -- Thunderlord
		[6960] = true, -- Battlelord
		[6964] = true, -- Deathmaker
		[7100] = true, -- Echo of Eonar
		[7104] = true, -- Stable Phantasma Lure
		[6957] = true, -- The Wall
		[6961] = true, -- Exploiter
		[6965] = true, -- Reckless Defense
		[6969] = true, -- Reprisal
		[7159] = true, -- Maw Rattle
		[7101] = true, -- Judgment of the Arbiter
		[7105] = true, -- Third Eye of the Jailer
		[6958] = true, -- Misshapen Mirror
	},
	PALADIN = { -- 2
		[7055] = true, -- Of Dusk and Dawn
		[7059] = true, -- Shock Barrier
		[7063] = true, -- Reign of Endless Kings
		[7067] = true, -- Tempest of the Lightbringer
		[7102] = true, -- Norgannon's Sagacity
		[7106] = true, -- Vitality Sacrifice
		[7056] = true, -- The Magistrate's Judgment
		[7060] = true, -- Holy Avenger's Engraved Sigil
		[7064] = true, -- Final Verdict
		[7103] = true, -- Sephuz's Proclamation
		[7053] = true, -- Uther's Devotion
		[7057] = true, -- Shadowbreaker, Dawn of the Sun
		[7061] = true, -- The Ardent Protector's Sanctum
		[7065] = true, -- Vanguard's Momentum
		[7100] = true, -- Echo of Eonar
		[7104] = true, -- Stable Phantasma Lure
		[7054] = true, -- The Mad Paragon
		[7058] = true, -- Inflorescence of the Sunwell
		[7062] = true, -- Bulwark of Righteous Fury
		[7128] = true, -- Maraad's Dying Breath
		[7101] = true, -- Judgment of the Arbiter
		[7105] = true, -- Third Eye of the Jailer
		[7159] = true, -- Maw Rattle
		[7066] = true, -- Relentless Inquisitor
	},
	ROGUE = { -- 4
		[7117] = true, -- Zoldyck Insignia
		[7121] = true, -- Celerity
		[7125] = true, -- The Rotten
		[7102] = true, -- Norgannon's Sagacity
		[7106] = true, -- Vitality Sacrifice
		[7114] = true, -- Invigorating Shadowdust
		[7118] = true, -- Duskwalker's Patch
		[7122] = true, -- Concealed Blunderbuss
		[7126] = true, -- Deathly Shadows
		[7103] = true, -- Sephuz's Proclamation
		[7111] = true, -- Mark of the Master Assassin
		[7115] = true, -- Dashing Scoundrel
		[7119] = true, -- Greenskin's Wickers
		[7123] = true, -- Finality
		[7100] = true, -- Echo of Eonar
		[7104] = true, -- Stable Phantasma Lure
		[7112] = true, -- Tiny Toxic Blade
		[7116] = true, -- Doomblade
		[7120] = true, -- Guile Charm
		[7124] = true, -- Akaari's Soul Fragment
		[7159] = true, -- Maw Rattle
		[7101] = true, -- Judgment of the Arbiter
		[7105] = true, -- Third Eye of the Jailer
		[7113] = true, -- Essence of Bloodfang
	},
	MAGE = { -- 8
		[6931] = true, -- Fevered Incantation
		[7102] = true, -- Norgannon's Sagacity
		[7106] = true, -- Vitality Sacrifice
		[6831] = true, -- Expanded Potential
		[6928] = true, -- Siphon Storm
		[6932] = true, -- Firestorm
		[6936] = true, -- Triune Ward
		[7103] = true, -- Sephuz's Proclamation
		[6828] = true, -- Cold Front
		[6832] = true, -- Disciplinary Command
		[6933] = true, -- Molten Skyfall
		[6937] = true, -- Grisly Icicle
		[7100] = true, -- Echo of Eonar
		[7104] = true, -- Stable Phantasma Lure
		[6829] = true, -- Freezing Winds
		[6926] = true, -- Arcane Infinity
		[6934] = true, -- Sun King's Blessing
		[6823] = true, -- Slick Ice
		[7159] = true, -- Maw Rattle
		[7101] = true, -- Judgment of the Arbiter
		[7105] = true, -- Third Eye of the Jailer
		[6830] = true, -- Glacial Fragments
		[6834] = true, -- Temporal Warp
		[6927] = true, -- Arcane Bombardment
	},
	WARLOCK = { -- 9
		[7028] = true, -- Pillars of the Dark Portal
		[7032] = true, -- Wrath of Consumption
		[7036] = true, -- Balespider's Burning Core
		[7102] = true, -- Norgannon's Sagacity
		[7106] = true, -- Vitality Sacrifice
		[7025] = true, -- Wilfred's Sigil of Superior Summoning
		[7029] = true, -- Perpetual Agony of Azj'Aqir
		[7033] = true, -- Implosive Potential
		[7037] = true, -- Odr, Shawl of the Ymirjar
		[7103] = true, -- Sephuz's Proclamation
		[7026] = true, -- Claw of Endereth
		[7030] = true, -- Sacrolash's Dark Strike
		[7034] = true, -- Grim Inquisitor's Dread Calling
		[7100] = true, -- Echo of Eonar
		[7104] = true, -- Stable Phantasma Lure
		[7040] = true, -- Embers of the Diabolic Raiment
		[7027] = true, -- Relic of Demonic Synergy
		[7031] = true, -- Malefic Wrath
		[7159] = true, -- Maw Rattle
		[7101] = true, -- Judgment of the Arbiter
		[7105] = true, -- Third Eye of the Jailer
		[7039] = true, -- Madness of the Azj'Aqir
		[7038] = true, -- Cinders of the Azj'Aqir
		[7035] = true, -- Forces of the Horned Nightmare
	},
	PRIEST = { -- 5
		[6974] = true, -- Flash Concentration
		[7102] = true, -- Norgannon's Sagacity
		[7106] = true, -- Vitality Sacrifice
		[7002] = true, -- Twins of the Sun Priestess
		[6975] = true, -- Cauterizing Shadows
		[7103] = true, -- Sephuz's Proclamation
		[6983] = true, -- Eternal Call to the Void
		[7162] = true, -- Talbadar's Stratagem
		[6982] = true, -- Shadowflame Prism
		[6981] = true, -- Painbreaker Psalm
		[6972] = true, -- Vault of Heavens
		[7100] = true, -- Echo of Eonar
		[7104] = true, -- Stable Phantasma Lure
		[6984] = true, -- X'anshi, Return of Archbishop Benedictus
		[6973] = true, -- Divine Image
		[6977] = true, -- Harmonious Apparatus
		[6976] = true, -- The Penitent One
		[6978] = true, -- Crystalline Reflection
		[7159] = true, -- Maw Rattle
		[7101] = true, -- Judgment of the Arbiter
		[7105] = true, -- Third Eye of the Jailer
		[6979] = true, -- Kiss of Death
		[6980] = true, -- Clarity of Mind
		[7161] = true, -- Measured Contemplation
	},
	MONK = { -- 10
		[7102] = true, -- Norgannon's Sagacity
		[7106] = true, -- Vitality Sacrifice
		[7079] = true, -- Shaohao's Might
		[7184] = true, -- Escape from Reality
		[7068] = true, -- Keefer's Skyreach
		[7103] = true, -- Sephuz's Proclamation
		[7076] = true, -- Charred Passions
		[7080] = true, -- Swiftsure Wraps
		[7069] = true, -- Last Emperor's Capacitor
		[7071] = true, -- Jade Ignition
		[7070] = true, -- Xuen's Treasure
		[7100] = true, -- Echo of Eonar
		[7104] = true, -- Stable Phantasma Lure
		[7077] = true, -- Stormstout's Last Keg
		[7081] = true, -- Fatal Touch
		[7072] = true, -- Tear of Morning
		[7074] = true, -- Clouded Focus
		[7073] = true, -- Yu'lon's Whisper
		[7159] = true, -- Maw Rattle
		[7101] = true, -- Judgment of the Arbiter
		[7105] = true, -- Third Eye of the Jailer
		[7078] = true, -- Celestial Infusion
		[7082] = true, -- Invoker's Delight
		[7075] = true, -- Ancient Teachings of the Monastery
	},
	HUNTER = { -- 3
		[7005] = true, -- Soulforge Embers
		[7102] = true, -- Norgannon's Sagacity
		[7106] = true, -- Vitality Sacrifice
		[7017] = true, -- Latent Poison Injectors
		[7006] = true, -- Craven Strategem
		[7103] = true, -- Sephuz's Proclamation
		[7014] = true, -- Secrets of the Unblinking Vigil
		[7018] = true, -- Butcher's Bone Fragments
		[7009] = true, -- Qa'pla, Eredun War Order
		[7013] = true, -- Serpentstalker's Trickery
		[7003] = true, -- Call of the Wild
		[7100] = true, -- Echo of Eonar
		[7104] = true, -- Stable Phantasma Lure
		[7015] = true, -- Wildfire Cluster
		[7012] = true, -- Surging Shots
		[7011] = true, -- Eagletalon's True Focus
		[7007] = true, -- Dire Command
		[7008] = true, -- Flamewaker's Cobra Sting
		[7004] = true, -- Nessingwary's Trapping Apparatus
		[7101] = true, -- Judgment of the Arbiter
		[7105] = true, -- Third Eye of the Jailer
		[7016] = true, -- Rylakstalker's Confounding Strikes
		[7010] = true, -- Rylakstalker's Piercing Fangs
		[7159] = true, -- Maw Rattle
	},
	DEATHKNIGHT = { -- 6
		[6943] = true, -- Gorefiend's Domination
		[7102] = true, -- Norgannon's Sagacity
		[7106] = true, -- Vitality Sacrifice
		[6940] = true, -- Bryndaor's Might
		[6944] = true, -- Koltira's Favor
		[7103] = true, -- Sephuz's Proclamation
		[6952] = true, -- Deadliest Coil
		[6951] = true, -- Death's Certainty
		[6950] = true, -- Frenzied Monstrosity
		[6949] = true, -- Reanimated Shambler
		[6941] = true, -- Crimson Rune Weapon
		[7100] = true, -- Echo of Eonar
		[7104] = true, -- Stable Phantasma Lure
		[6953] = true, -- Superstrain
		[7160] = true, -- Rage of the Frozen Champion
		[6946] = true, -- Absolute Zero
		[6945] = true, -- Biting Cold
		[6947] = true, -- Death's Embrace
		[6942] = true, -- Vampiric Aura
		[7101] = true, -- Judgment of the Arbiter
		[7105] = true, -- Third Eye of the Jailer
		[6954] = true, -- Phearomones
		[6948] = true, -- Grip of the Everlasting
		[7159] = true, -- Maw Rattle
	},
	DEMONHUNTER = { -- 12
		[7102] = true, -- Norgannon's Sagacity
		[7044] = true, -- Darkest Hour
		[7048] = true, -- Fiery Soul
		[7052] = true, -- Burning Wound
		[7041] = true, -- Collective Anguish
		[7045] = true, -- Spirit of the Darkness Flame
		[7049] = true, -- Darker Nature
		[7100] = true, -- Echo of Eonar
		[7104] = true, -- Stable Phantasma Lure
		[7046] = true, -- Razelikh's Defilement
		[7050] = true, -- Chaos Theory
		[7042] = true, -- Fel Bombardment
		[7043] = true, -- Darkglare Medallion
		[7103] = true, -- Sephuz's Proclamation
		[7159] = true, -- Maw Rattle
		[7101] = true, -- Judgment of the Arbiter
		[7105] = true, -- Third Eye of the Jailer
		[7047] = true, -- Fel Flame Fortification
		[7051] = true, -- Erratic Fel Core
		[7106] = true, -- Vitality Sacrifice
	},
	DRUID = { -- 11
		[7086] = true, -- Draught of Deep Focus
		[7090] = true, -- Eye of Fearful Symmetry
		[7094] = true, -- Ursoc's Fury Remembered
		[7098] = true, -- Verdant Infusion
		[7102] = true, -- Norgannon's Sagacity
		[7106] = true, -- Vitality Sacrifice
		[7110] = true, -- Lycara's Fleeting Glimpse
		[7087] = true, -- Oneth's Clear Vision
		[7091] = true, -- Apex Predator's Craving
		[7095] = true, -- Legacy of the Sleeper
		[7099] = true, -- Vision of Unending Growth
		[7103] = true, -- Sephuz's Proclamation
		[7107] = true, -- Balance of All Things
		[7084] = true, -- Oath of the Elder Druid
		[7088] = true, -- Primordial Arcanic Pulsar
		[7092] = true, -- Luffa-Infused Embrace
		[7096] = true, -- Memory of the Mother Tree
		[7100] = true, -- Echo of Eonar
		[7104] = true, -- Stable Phantasma Lure
		[7108] = true, -- Timeworn Dreambinder
		[7085] = true, -- Circle of Life and Death
		[7089] = true, -- Cat-eye Curio
		[7093] = true, -- The Natural Order's Will
		[7159] = true, -- Maw Rattle
		[7101] = true, -- Judgment of the Arbiter
		[7105] = true, -- Third Eye of the Jailer
		[7109] = true, -- Frenzyband
		[7097] = true, -- The Dark Titan's Lesson
	},
}

local function GetItemSplit(itemLink)
	local itemString = string.match(itemLink, 'item:([%-?%d:]+)');
	local itemSplit = {};

	-- Split data into a table
	for _, v in ipairs({strsplit(':', itemString)}) do
		if v == '' then
			itemSplit[#itemSplit + 1] = 0;
		else
			itemSplit[#itemSplit + 1] = tonumber(v);
		end
	end

	return itemSplit;
end

local OFFSET_BONUS_ID = 13;
function MaxDps:ExtractBonusIds(itemLink)
	local itemSplit = GetItemSplit(itemLink);
	local bonuses = {}

	for i = 1, itemSplit[OFFSET_BONUS_ID] do
		bonuses[itemSplit[OFFSET_BONUS_ID + i]] = true;
	end

	return bonuses;
end

function MaxDps:GetLegendaryEffects()
	local legendaryBonusIds = {};
	local playerClass = select(2, UnitClass('player'));

	for i = 1, 19 do
		local link = GetInventoryItemLink('player', i);

		if link then
			local itemBonusIds = self:ExtractBonusIds(link);

			for bonusId, _ in pairs(generalLegendaries) do
				if itemBonusIds[bonusId] then
					legendaryBonusIds[bonusId] = true;
				end
			end

			for bonusId, _ in pairs(allLegendaryBonusIds[playerClass]) do
				if itemBonusIds[bonusId] then
					legendaryBonusIds[bonusId] = true;
				end
			end
		end
	end

	self.LegendaryBonusIds = legendaryBonusIds;

	return legendaryBonusIds;
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
		end ;
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
	return 1 / ((haste / 100) + 1);
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
		ready   = remains <= 0,
		remains = remains,
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
	end ;
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
	end ;

	local healthMax = UnitHealthMax(unit or 'target');
	if healthMax <= 0 then
		return 0;
	end ;

	return health / healthMax;
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
	for k, v in pairs(_Bloodlusts) do
		if MaxDps:Aura(v, timeShift or 0) then
			return true;
		end
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

	if WeakAuras then
		WeakAuras.ScanEvents('MAXDPS_TARGET_COUNT', count);
	end
	return count;
end

function MaxDps:FormatTime(left)
	local seconds = left >= 0 and math.floor((left % 60) / 1) or 0;
	local minutes = left >= 60 and math.floor((left % 3600) / 60) or 0;
	local hours = left >= 3600 and math.floor((left % 86400) / 3600) or 0;
	local days = left >= 86400 and math.floor((left % 31536000) / 86400) or 0;
	local years = left >= 31536000 and math.floor(left / 31536000) or 0;

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