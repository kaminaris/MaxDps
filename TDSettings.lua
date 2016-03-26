local AceGUI = LibStub('AceGUI-3.0');
local lsm = LibStub("AceGUISharedMediaWidgets-1.0");
local media = LibStub("LibSharedMedia-3.0");

TDDps_textures = {
	['Ping'] = 'Interface\\Cooldown\\ping4',
	['Star'] = 'Interface\\Cooldown\\star4',
	['Starburst'] = 'Interface\\Cooldown\\starburst',
};

TDDps_Options = {
	enabled = true,
	onCombatEnter = true,
	texture = '',
	customTexture = '',
	highlightColor = {
		r = 1, g = 1, b = 1, a = 1
	},
	interval = 0.15
}

TDDps_Temp = {};

function TDDps_Options_GetTexture()
	if TDDps_Options.customTexture ~= '' and TDDps_Options.customTexture ~= nil then
		TDDps_Temp.finalTexture = TDDps_Options.customTexture;
		return TDDps_Temp.finalTexture;
	end

	TDDps_Temp.finalTexture = TDDps_textures[TDDps_Options.texture];
	if TDDps_Temp.finalTexture == '' or TDDps_Temp.finalTexture == nil then
		TDDps_Temp.finalTexture = 'Interface\\Cooldown\\ping4';
	end

	return TDDps_Temp.finalTexture;
end

local options = {
	type = 'group',
	name = 'TD Dps Options',
	inline = false,
	args = {
		enable = {
			name = 'Enable',
			desc = 'Enables / disables the addon',
			type = 'toggle',
			width = 'full',
			set = function(info, val)
				TDDps_Options.enabled = val;
			end,
			get = function(info) return TDDps_Options.enabled end
		},
		onCombatEnter = {
			name = 'Enable upon entering combat',
			desc = 'Automatically enables helper upon entering combat',
			type = 'toggle',
			width = 'full',
			set = function(info, val)
				TDDps_Options.onCombatEnter = val;
			end,
			get = function(info) return TDDps_Options.onCombatEnter end
		},
		customTexture = {
			name = 'Custom Texture',
			desc = 'Sets Highlight texture, has priority over selected one (changing this requires UI Reload)',
			type = 'input',
			set = function(info, val) TDDps_Options.customTexture = strtrim(val or ''); end,
			get = function(info) return strtrim(TDDps_Options.customTexture or '') end
		},
		texture = {
			type = "select",
			dialogControl = 'LSM30_Background',
			name = "Texture",
			desc = "Sets Highlight texture (changing this requires UI Reload)",
			values = function()
				return TDDps_textures;
			end,
			get = function()
				return TDDps_Options.texture;
			end,
			set = function(self, val)
				TDDps_Options.texture = val;
			end,
		},
		highlightColor = {
			name = 'Highlight color',
			desc = 'Sets Highlight color',
			type = 'color',
			set = function(info, r, g, b, a)
				TDDps_Options.highlightColor.r = r;
				TDDps_Options.highlightColor.g = g;
				TDDps_Options.highlightColor.b = b;
				TDDps_Options.highlightColor.a = a;
			end,
			get = function(info)
				return TDDps_Options.highlightColor.r, TDDps_Options.highlightColor.g, TDDps_Options.highlightColor.b, TDDps_Options.highlightColor.a;
			end,
			hasAlpha = true
		},
		interval = {
			name = "Interval in seconds",
			desc = "Sets how frequent rotation updates will be. Low value will result in fps drops.",
			type = "range",
			min = 0.01,
			max = 2,
			set = function(info,val) TDDps_Options.interval = val end,
			get = function(info) return TDDps_Options.interval end
		},
	},
}

LibStub('AceConfigRegistry-3.0'):RegisterOptionsTable('TDDps_Settings', options)
LibStub('AceConfigDialog-3.0'):AddToBlizOptions('TDDps_Settings', 'TD Dps')
