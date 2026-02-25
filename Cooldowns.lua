local AddOnName, ns = ...
local AddOn = _G[AddOnName]

local WOW_PROJECT_ID = WOW_PROJECT_ID
local WOW_PROJECT_CLASSIC = WOW_PROJECT_CLASSIC
local WOW_PROJECT_BURNING_CRUSADE_CLASSIC = WOW_PROJECT_BURNING_CRUSADE_CLASSIC
local WOW_PROJECT_WRATH_CLASSIC = WOW_PROJECT_WRATH_CLASSIC
local WOW_PROJECT_CATACLYSM_CLASSIC = WOW_PROJECT_CATACLYSM_CLASSIC
local WOW_PROJECT_MISTS_CLASSIC = WOW_PROJECT_MISTS_CLASSIC
local WOW_PROJECT_MAINLINE = WOW_PROJECT_MAINLINE
local LE_EXPANSION_LEVEL_CURRENT = LE_EXPANSION_LEVEL_CURRENT
local LE_EXPANSION_BURNING_CRUSADE =  LE_EXPANSION_BURNING_CRUSADE
local LE_EXPANSION_WRATH_OF_THE_LICH_KING = LE_EXPANSION_WRATH_OF_THE_LICH_KING
local LE_EXPANSION_CATACLYSM = LE_EXPANSION_CATACLYSM
local LE_EXPANSION_MISTS_OF_PANDARIA = LE_EXPANSION_MISTS_OF_PANDARIA
local function IsClassicWow()
    return WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
end

local function IsTBCWow()
    return WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC and LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_BURNING_CRUSADE
end

local function IsWrathWow()
    return WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC and LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_WRATH_OF_THE_LICH_KING
end

local function IsCataWow()
    return WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC and LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_CATACLYSM
end

local function IsMistsWow()
    return WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC and LE_EXPANSION_LEVEL_CURRENT == LE_EXPANSION_MISTS_OF_PANDARIA
end

local function IsRetailWow()
    return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
end

if not IsRetailWow() then
    return
end

ns.classCooldowns = {
    DEATHKNIGHT = {
        Blood = {
            offensive = {
                --["Dancing Rune Weapon"] = 49028,
                ["Abomination Limb"] = 383269,
                ["Empower Rune Weapon"] = 47568,
                ["Blooddrinker"] = 206931,
                ["Bonestorm"] = 194844,
                --raise_dead
            },
            defensive = {
                ["Vampiric Blood"] = 55233,
                ["Icebound Fortitude"] = 48792,
                ["Rune Tap"] = 194679,
                ["Anti-Magic Shell"] = 48707,
                ["Anti-Magic Zone"] = 51052,
                ["Lichborne"] = 49039,
                ["Death Pact"] = 48743,
                ["Tombstone"] = 219809,
            },
        },

        Frost = {
            offensive = {
                --["Pillar of Frost"] = 51271,
                ["Empower Rune Weapon"] = 47568,
                ["Breath of Sindragosa"] = 152279,
                ["Abomination Limb"] = 383269,
                --["Frostwyrm's Fury"] = 279302,
                --["Glacial Advance"] = 194913,
                --raise_dead
            },
            defensive = {
                ["Icebound Fortitude"] = 48792,
                ["Anti-Magic Shell"] = 48707,
                ["Lichborne"] = 49039,
                ["Anti-Magic Zone"] = 51052,
                ["Death Pact"] = 48743,
            },
        },

        Unholy = {
            offensive = {
                --["Dark Transformation"] = 63560,
                --["Army of the Dead"] = 42650,
                ["Unholy Assault"] = 207289,
                ["Summon Gargoyle"] = 49206,
                ["Abomination Limb"] = 383269,
                ["Vile Contagion"] = 390279,
                ["Soul Reaper"] = 343294,
            },
            defensive = {
                ["Icebound Fortitude"] = 48792,
                ["Anti-Magic Shell"] = 48707,
                ["Lichborne"] = 49039,
                ["Anti-Magic Zone"] = 51052,
                ["Death Pact"] = 48743,
            },
        },
    },
    DEMONHUNTER = {
        Devourer = {
            offensive = {
                ["Metamorphosis"] = 1217605,
            },
            defensive = {
                ["Blur"] = 198589,
                ["Darkness"] = 196718,
                ["Netherwalk"] = 196555,
                --["Desperate Instincts"] = 205411,
                --["Vengeful Retreat"] = 198793, -- mobility but often tracked
            },
        },
        Havoc = {
            offensive = {
                ["Metamorphosis"] = 191427,
                ["Essence Break"] = 258860,
                --["Eye Beam"] = 198013,
                ["Fel Barrage"] = 258925,
                ["The Hunt"] = 370965,
                ["Glaive Tempest"] = 342817,
                --["Throw Glaive"] = 185123, -- rotational but often tracked
            },
            defensive = {
                ["Blur"] = 198589,
                ["Darkness"] = 196718,
                ["Netherwalk"] = 196555,
                --["Desperate Instincts"] = 205411,
                --["Vengeful Retreat"] = 198793, -- mobility but often tracked
            },
        },

        Vengeance = {
            offensive = {
                ["Metamorphosis"] = 187827,
                ["Fel Devastation"] = 212084,
                ["The Hunt"] = 370965,
                --["Soul Carver"] = 207407,
                --["Sigil of Flame"] = 204596,
            },
            defensive = {
                ["Demon Spikes"] = 203720,
                ["Fiery Brand"] = 204021,
                ["Darkness"] = 196718,
                ["Fel Devastation"] = 212084, -- hybrid
                ["Soul Barrier"] = 263648,
                ["Bulk Extraction"] = 320341,
            },
        },
    },
    DRUID = {
        Balance = {
            offensive = {
                ["Celestial Alignment"] = 194223,
                ["Incarnation: Chosen of Elune"] = 102560,
                --["Convoke the Spirits"] = 391528,
                --["Fury of Elune"] = 202770,
                --["Starfall"] = 191034, -- AoE burst window
                --["Warrior of Elune"] = 202425,
            },
            defensive = {
                ["Barkskin"] = 22812,
                ["Renewal"] = 108238,
                --["Well-Honed Instincts"] = 377847, -- auto Frenzied Regeneration
                ["Ironbark"] = 102342,
                --["Bear Form"] = 5487,
            },
        },

        Feral = {
            offensive = {
                ["Berserk"] = 106951,
                ["Incarnation: Avatar of Ashamane"] = 102543,
                --["Convoke the Spirits"] = 391528,
                ["Tiger's Fury"] = 5217,
                ["Berserk: Frenzy"] = 343223,
                --["Feral Frenzy"] = 274837,
            },
            defensive = {
                ["Barkskin"] = 22812,
                ["Survival Instincts"] = 61336,
                ["Renewal"] = 108238,
                --["Well-Honed Instincts"] = 377847,
                --["Bear Form"] = 5487,
            },
        },

        Guardian = {
            offensive = {
                ["Incarnation: Guardian of Ursoc"] = 102558,
                ["Berserk"] = 50334,
                ["Rage of the Sleeper"] = 200851,
                --["Convoke the Spirits"] = 391528,
            },
            defensive = {
                ["Barkskin"] = 22812,
                ["Survival Instincts"] = 61336,
                ["Ironfur"] = 192081,
                ["Frenzied Regeneration"] = 22842,
                ["Renewal"] = 108238,
                --["Well-Honed Instincts"] = 377847,
            },
        },

        Restoration = {
            offensive = {
                ["Convoke the Spirits"] = 391528,
                ["Flourish"] = 197721,
                ["Incarnation: Tree of Life"] = 33891,
                ["Tranquility"] = 740,
            },
            defensive = {
                ["Ironbark"] = 102342,
                ["Barkskin"] = 22812,
                ["Renewal"] = 108238,
                --["Well-Honed Instincts"] = 377847,
                --["Bear Form"] = 5487,
            },
        },
    },
    EVOKER = {
        Devastation = {
            offensive = {
                ["Dragonrage"] = 375087,
                ["Deep Breath"] = 357210,
                ["Fire Breath"] = 382266,
                --["Eternity Surge"] = 382411,
                --["Shattering Star"] = 370452,
                ["Tip the Scales"] = 370553,
                ["Time Skip"] = 404977,
            },
            defensive = {
                ["Obsidian Scales"] = 363916,
                ["Renewing Blaze"] = 374348,
                --["Time Spiral"] = 374968,
                ["Zephyr"] = 374227,
                ["Verdant Embrace"] = 360995,
            },
        },

        Preservation = {
            offensive = {
                ["Tip the Scales"] = 370553,
                ["Deep Breath"] = 357210,
                ["Fire Breath"] = 382266,
                ["Eternity Surge"] = 382411,
            },
            defensive = {
                ["Rewind"] = 363534,
                --["Stasis"] = 370537,
                ["Time Dilation"] = 357170,
                ["Obsidian Scales"] = 363916,
                ["Renewing Blaze"] = 374348,
                ["Zephyr"] = 374227,
                ["Verdant Embrace"] = 360995,
                ["Emerald Communion"] = 370960,
            },
        },

        Augmentation = {
            offensive = {
                --["Ebon Might"] = 395152,
                ["Breath of Eons"] = 403631,
                ["Tip the Scales"] = 370553,
                --["Fire Breath"] = 382266,
                ["Eternity Surge"] = 382411,
                --["Upheaval"] = 396286,
            },
            defensive = {
                ["Obsidian Scales"] = 363916,
                ["Renewing Blaze"] = 374348,
                --["Time Skip"] = 404977,
                ["Zephyr"] = 374227,
                ["Verdant Embrace"] = 360995,
                --["Spatial Paradox"] = 406732,
            },
        },
    },
    HUNTER = {
        BeastMastery = {
            offensive = {
                --["Bestial Wrath"] = 19574,
                ["Call of the Wild"] = 359844,
                ["Aspect of the Wild"] = 193530,
                ["Stampede"] = 201430,
                ["Bloodshed"] = 321530,
            },
            defensive = {
                ["Exhilaration"] = 109304,
                ["Aspect of the Turtle"] = 186265,
                ["Fortitude of the Bear"] = 388035,
                ["Survival of the Fittest"] = 281195,
                --["Feign Death"] = 5384,
                --["Mend Pet"] = 136,
            },
        },

        Marksmanship = {
            offensive = {
                ["Trueshot"] = 288613,
                --["Rapid Fire"] = 257044,
                --["Aimed Shot"] = 19434, -- charge-based burst
                --["Volley"] = 260243,
                --["Wailing Arrow"] = 392060,
                ["Death Chakram"] = 375891,
            },
            defensive = {
                ["Exhilaration"] = 109304,
                ["Aspect of the Turtle"] = 186265,
                ["Survival of the Fittest"] = 281195,
                --["Feign Death"] = 5384,
                ["Camouflage"] = 199483,
            },
        },

        Survival = {
            offensive = {
                ["Coordinated Assault"] = 360952,
                --["Spearhead"] = 360966,
                ["Death Chakram"] = 375891,
                ["Stampede"] = 201430,
            },
            defensive = {
                ["Exhilaration"] = 109304,
                ["Aspect of the Turtle"] = 186265,
                ["Survival of the Fittest"] = 281195,
                --["Feign Death"] = 5384,
                ["Camouflage"] = 199483,
            },
        },
    },
    MAGE = {
        Arcane = {
            offensive = {
                ["Arcane Surge"] = 365350,
                --["Touch of the Magi"] = 321507,
                ["Evocation"] = 12051,
            },
            defensive = {
                ["Prismatic Barrier"] = 235450,
                ["Ice Block"] = 45438,
                ["Mirror Image"] = 55342,
                ["Alter Time"] = 342245,
                ["Greater Invisibility"] = 110959,
            },
        },

        Fire = {
            offensive = {
                ["Combustion"] = 190319,
                --["Phoenix Flames"] = 257541,
                ["Rune of Power"] = 116011, -- only if talented (legacy)
            },
            defensive = {
                ["Blazing Barrier"] = 235313,
                ["Ice Block"] = 45438,
                --["Cauterize"] = 86949,
                ["Alter Time"] = 342245,
            },
        },

        Frost = {
            offensive = {
                ["Icy Veins"] = 12472,
                --["Frozen Orb"] = 84714,
                --["Ray of Frost"] = 205021,
                --["Comet Storm"] = 153595,
            },
            defensive = {
                ["Ice Barrier"] = 11426,
                ["Ice Block"] = 45438,
                ["Cold Snap"] = 235219,
                ["Alter Time"] = 342245,
            },
        },
    },
    MONK = {
        Brewmaster = {
            offensive = {
                ["Weapons of Order"] = 387184,
                --["Exploding Keg"] = 325153,
                ["Bonedust Brew"] = 386276,
                --["Breath of Fire"] = 115181, -- mitigation + damage
            },
            defensive = {
                ["Fortifying Brew"] = 115203,
                ["Dampen Harm"] = 122278,
                ["Diffuse Magic"] = 122783,
                ["Celestial Brew"] = 322507,
                ["Purifying Brew"] = 119582,
                ["Zen Meditation"] = 115176,
                ["Expel Harm"] = 322101,
            },
        },

        Mistweaver = {
            offensive = {
                ["Weapons of Order"] = 387184,
                ["Chi-Ji"] = 325197,
                ["Yu'lon the Jade Serpent"] = 322118,
                ["Bonedust Brew"] = 386276,
            },
            defensive = {
                ["Life Cocoon"] = 116849,
                ["Fortifying Brew"] = 243435,
                ["Dampen Harm"] = 122278,
                ["Diffuse Magic"] = 122783,
                ["Revival"] = 115310,
                ["Expel Harm"] = 322101,
            },
        },

        Windwalker = {
            offensive = {
                --["Storm, Earth, and Fire"] = 137639,
                ["Serenity"] = 152173,
                ["Weapons of Order"] = 387184,
                ["Invoke Xuen, the White Tiger"] = 123904,
                ["Bonedust Brew"] = 386276,
                --["Strike of the Windlord"] = 392983,
            },
            defensive = {
                ["Touch of Karma"] = 122470,
                ["Fortifying Brew"] = 243435,
                ["Dampen Harm"] = 122278,
                ["Diffuse Magic"] = 122783,
                ["Expel Harm"] = 322101,
            },
        },
    },
    PALADIN = {
        Holy = {
            offensive = {
                ["Holy Prism"] = 114165,
                ["Hammer of Wrath"] = 24275, -- executes are often tracked
                ["Avenging Crusader"] = 216331,
                ["Divine Toll"] = 375576,
            },
            defensive = {
                ["Divine Shield"] = 642,
                ["Blessing of Protection"] = 1022,
                --["Blessing of Sacrifice"] = 6940,
                ["Aura Mastery"] = 31821,
                ["Divine Protection"] = 498,
                ["Lay on Hands"] = 633,
                ["Divine Favor"] = 210294,
                --["Blessing of Freedom"] = 1044,
                ["Shield of Vengeance"] = 184662,
            },
        },

        Protection = {
            offensive = {
                ["Avenging Wrath"] = 31884,
                --["Divine Toll"] = 375576,
                --["Hammer of Wrath"] = 24275,
            },
            defensive = {
                ["Ardent Defender"] = 31850,
                ["Guardian of Ancient Kings"] = 86659,
                ["Divine Shield"] = 642,
                ["Lay on Hands"] = 633,
                ["Blessing of Protection"] = 1022,
                ["Blessing of Spellwarding"] = 204018,
                ["Divine Protection"] = 498,
                --["Blessing of Freedom"] = 1044,
                ["Shield of the Righteous"] = 53600,
            },
        },

        Retribution = {
            offensive = {
                ["Avenging Wrath"] = 31884,
                ["Crusade"] = 231895,
                --["Execution Sentence"] = 343527,
                --["Final Reckoning"] = 343721,
                --["Wake of Ashes"] = 255937,
                --["Divine Toll"] = 375576,
                --["Hammer of Wrath"] = 24275,
            },
            defensive = {
                ["Divine Shield"] = 642,
                ["Shield of Vengeance"] = 184662,
                ["Divine Protection"] = 498,
                ["Lay on Hands"] = 633,
                ["Blessing of Protection"] = 1022,
                --["Blessing of Freedom"] = 1044,
                --["Blessing of Sacrifice"] = 6940,
            },
        },
    },
    PRIEST = {
        Discipline = {
            offensive = {
                ["Schism"] = 214621,
                ["Mindbender"] = 123040,
                ["Shadowfiend"] = 34433,
                ["Power Infusion"] = 10060,
                ["Penance"] = 47540, -- rotational but often tracked
            },
            defensive = {
                ["Pain Suppression"] = 33206,
                ["Power Word: Barrier"] = 62618,
                --["Rapture"] = 47536,
                ["Desperate Prayer"] = 19236,
                ["Fade"] = 586,
                ["Power Word: Life"] = 373481,
            },
        },

        Holy = {
            offensive = {
                ["Holy Word: Chastise"] = 88625,
                ["Divine Word"] = 372760,
                ["Shadowfiend"] = 34433,
                ["Power Infusion"] = 10060,
            },
            defensive = {
                ["Guardian Spirit"] = 47788,
                ["Holy Word: Serenity"] = 2050,
                ["Holy Word: Sanctify"] = 34861,
                ["Desperate Prayer"] = 19236,
                ["Symbol of Hope"] = 64901,
                ["Fade"] = 586,
            },
        },

        Shadow = {
            offensive = {
                ["Void Eruption"] = 228260,
                ["Dark Ascension"] = 391109,
                ["Power Infusion"] = 10060,
                ["Mindbender"] = 200174,
                ["Shadowfiend"] = 34433,
                --["Void Torrent"] = 263165,
                ["Dark Evangelism"] = 391112,
            },
            defensive = {
                ["Dispersion"] = 47585,
                ["Desperate Prayer"] = 19236,
                ["Fade"] = 586,
                ["Vampiric Embrace"] = 15286,
            },
        },
    },
    ROGUE = {
        Assassination = {
            offensive = {
                ["Vendetta"] = 79140,
                ["Deathmark"] = 360194,
                --["Kingsbane"] = 385627,
                ["Sepsis"] = 385408,
                ["Thistle Tea"] = 381623,
                --["Cold Blood"] = 382245,
                ["Shadowstep"] = 36554, -- mobility but often tracked
            },
            defensive = {
                ["Evasion"] = 5277,
                ["Feint"] = 1966,
                ["Cloak of Shadows"] = 31224,
                ["Crimson Vial"] = 185311,
                ["Vanish"] = 1856,
                --["Cheat Death"] = 31230,
                ["Smoke Bomb"] = 212182,
            },
        },

        Outlaw = {
            offensive = {
                ["Adrenaline Rush"] = 13750,
                --["Blade Flurry"] = 13877,
                --["Killing Spree"] = 51690,
                --["Between the Eyes"] = 315341,
                ["Roll the Bones"] = 315508,
                ["Thistle Tea"] = 381623,
                ["Shadowstep"] = 36554,
            },
            defensive = {
                ["Evasion"] = 5277,
                ["Feint"] = 1966,
                ["Cloak of Shadows"] = 31224,
                ["Crimson Vial"] = 185311,
                ["Vanish"] = 1856,
                --["Cheat Death"] = 31230,
                ["Smoke Bomb"] = 212182,
            },
        },

        Subtlety = {
            offensive = {
                --["Shadow Dance"] = 185313,
                --["Symbols of Death"] = 212283,
                --["Secret Technique"] = 280719,
                ["Shadow Blades"] = 121471,
                ["Thistle Tea"] = 381623,
                ["Shadowstep"] = 36554,
            },
            defensive = {
                ["Evasion"] = 5277,
                ["Feint"] = 1966,
                ["Cloak of Shadows"] = 31224,
                ["Crimson Vial"] = 185311,
                ["Vanish"] = 1856,
                --["Cheat Death"] = 31230,
                ["Smoke Bomb"] = 212182,
            },
        },
    },
    SHAMAN = {
        Elemental = {
            offensive = {
                --["Stormkeeper"] = 191634,
                --["Fire Elemental"] = 198067,
                --["Storm Elemental"] = 192249,
                ["Ascendance"] = 114050,
                --["Primordial Wave"] = 375982,
                ["Echoing Shock"] = 320125,
            },
            defensive = {
                ["Astral Shift"] = 108271,
                ["Earth Elemental"] = 198103,
                ["Healing Stream Totem"] = 5394,
                ["Healing Tide Totem"] = 108280,
                --["Spiritwalker's Grace"] = 79206,
                --["Ghost Wolf"] = 2645,
            },
        },

        Enhancement = {
            offensive = {
                --["Feral Spirit"] = 51533,
                ["Doom Winds"] = 384352,
                ["Ascendance"] = 114051,
                --["Primordial Wave"] = 375982,
                --["Sundering"] = 197214,
            },
            defensive = {
                ["Astral Shift"] = 108271,
                ["Earth Elemental"] = 198103,
                ["Healing Stream Totem"] = 5394,
                ["Spirit Walk"] = 58875,
                --["Ghost Wolf"] = 2645,
            },
        },

        Restoration = {
            offensive = {
                ["Cloudburst Totem"] = 157153,
                ["Primordial Wave"] = 375982,
                ["Ascendance"] = 114052,
                ["Spirit Link Totem"] = 98008, -- hybrid but major CD
            },
            defensive = {
                ["Spirit Link Totem"] = 98008,
                ["Healing Tide Totem"] = 108280,
                ["Earth Elemental"] = 198103,
                ["Astral Shift"] = 108271,
                --["Spiritwalker's Grace"] = 79206,
                --["Mana Tide Totem"] = 16191,
            },
        },
    },
    WARLOCK = {
        Affliction = {
            offensive = {
                ["Summon Darkglare"] = 205180,
                --["Soul Rot"] = 386997,
                --["Vile Taint"] = 278350,
                --["Phantom Singularity"] = 205179,
                --["Haunt"] = 48181,
                ["Soulburn"] = 385899,
            },
            defensive = {
                ["Unending Resolve"] = 104773,
                ["Dark Pact"] = 108416,
                ["Mortal Coil"] = 6789,
                ["Healthstone"] = 6262,
                ["Drain Life"] = 234153,
                --["Demonic Circle: Teleport"] = 48020,
            },
        },

        Demonology = {
            offensive = {
                ["Summon Demonic Tyrant"] = 265187,
                ["Nether Portal"] = 267217,
                --["Grimoire: Felguard"] = 111898,
                --["Power Siphon"] = 264130,
                --["Demonic Strength"] = 267171,
                ["Soulburn"] = 385899,
            },
            defensive = {
                ["Unending Resolve"] = 104773,
                ["Dark Pact"] = 108416,
                ["Mortal Coil"] = 6789,
                ["Healthstone"] = 6262,
                --["Demonic Circle: Teleport"] = 48020,
                --["Fel Domination"] = 333889,
            },
        },

        Destruction = {
            offensive = {
                ["Summon Infernal"] = 1122,
                --["Cataclysm"] = 152108,
                --["Soul Fire"] = 6353,
                --["Channel Demonfire"] = 196447,
                ["Soulburn"] = 385899,
            },
            defensive = {
                ["Unending Resolve"] = 104773,
                ["Dark Pact"] = 108416,
                ["Mortal Coil"] = 6789,
                ["Healthstone"] = 6262,
                --["Demonic Circle: Teleport"] = 48020,
                --["Soul Leech"] = 108370,
            },
        },
    },
    WARRIOR = {
        Arms = {
            offensive = {
                ["Avatar"] = 107574,
                --["Colossus Smash"] = 167105,
                --["Bladestorm"] = 227847,
                --["Sweeping Strikes"] = 260708,
                ["Warbreaker"] = 262161,
            },
            defensive = {
                ["Die by the Sword"] = 118038,
                --["Defensive Stance"] = 197690,
                ["Rallying Cry"] = 97462,
                ["Spell Reflection"] = 23920,
                ["Shield Wall"] = 871, -- if using sword+board talents
            },
        },

        Fury = {
            offensive = {
                ["Recklessness"] = 1719,
                --["Odyn's Fury"] = 385059,
                ["Avatar"] = 107574,
                --["Onslaught"] = 315720,
            },
            defensive = {
                ["Enraged Regeneration"] = 184364,
                --["Defensive Stance"] = 197690,
                ["Rallying Cry"] = 97462,
                ["Spell Reflection"] = 23920,
            },
        },

        Protection = {
            offensive = {
                ["Avatar"] = 107574,
                ["Demoralizing Shout"] = 1160,
                ["Shield Charge"] = 385952,
            },
            defensive = {
                ["Shield Wall"] = 871,
                ["Last Stand"] = 12975,
                ["Ignore Pain"] = 190456,
                ["Shield Block"] = 2565,
                ["Rallying Cry"] = 97462,
                ["Spell Reflection"] = 23920,
            },
        },
    },
}

ns.classInterrupts = {
    WARRIOR = {
        Arms = {
            ["Pummel"] = 6552,
        },
        Fury = {
            ["Pummel"] = 6552,
        },
        Protection = {
            ["Pummel"] = 6552,
        },
    },

    PALADIN = {
        Holy = {
            ["Rebuke"] = 96231,
        },
        Protection = {
            ["Rebuke"] = 96231,
        },
        Retribution = {
            ["Rebuke"] = 96231,
        },
    },

    HUNTER = {
        BeastMastery = {
            ["Counter Shot"] = 147362,
        },
        Marksmanship = {
            ["Counter Shot"] = 147362,
        },
        Survival = {
            ["Muzzle"] = 187707,
        },
    },

    ROGUE = {
        Assassination = {
            ["Kick"] = 1766,
        },
        Outlaw = {
            ["Kick"] = 1766,
        },
        Subtlety = {
            ["Kick"] = 1766,
        },
    },

    PRIEST = {
        Discipline = {},
        Holy = {},
        Shadow = {},
    },

    DEATHKNIGHT = {
        Blood = {
            ["Mind Freeze"] = 47528,
        },
        Frost = {
            ["Mind Freeze"] = 47528,
        },
        Unholy = {
            ["Mind Freeze"] = 47528,
        },
    },

    SHAMAN = {
        Elemental = {
            ["Wind Shear"] = 57994,
        },
        Enhancement = {
            ["Wind Shear"] = 57994,
        },
        Restoration = {
            ["Wind Shear"] = 57994,
        },
    },

    MAGE = {
        Arcane = {
            ["Counterspell"] = 2139,
        },
        Fire = {
            ["Counterspell"] = 2139,
        },
        Frost = {
            ["Counterspell"] = 2139,
        },
    },

    WARLOCK = {
        Affliction = {
            ["Spell Lock"] = 19647,
        },
        Demonology = {
            ["Spell Lock"] = 19647,
        },
        Destruction = {
            ["Spell Lock"] = 19647,
        },
    },

    MONK = {
        Brewmaster = {
            ["Spear Hand Strike"] = 116705,
        },
        Mistweaver = {
            ["Spear Hand Strike"] = 116705,
        },
        Windwalker = {
            ["Spear Hand Strike"] = 116705,
        },
    },

    DRUID = {
        Balance = {
            ["Skull Bash"] = 106839,
        },
        Feral = {
            ["Skull Bash"] = 106839,
        },
        Guardian = {
            ["Skull Bash"] = 106839,
        },
        Restoration = {
            ["Skull Bash"] = 106839,
        },
    },

    DEMONHUNTER = {
        Devourer = {
            ["Disrupt"] = 183752,
        },
        Havoc = {
            ["Disrupt"] = 183752,
        },
        Vengeance = {
            ["Disrupt"] = 183752,
        },
    },

    EVOKER = {
        Devastation = {
            ["Quell"] = 351338,
        },
        Preservation = {
            ["Quell"] = 351338,
        },
        Augmentation = {
            ["Quell"] = 351338,
        },
    },
}

