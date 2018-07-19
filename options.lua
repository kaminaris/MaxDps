---@type StdUi
local StdUi = LibStub('StdUi');
local media = LibStub('LibSharedMedia-3.0');


MaxDps.Textures = {
	{text = 'Ping', value = 'Interface\\Cooldown\\ping4'},
	{text = 'Star', value = 'Interface\\Cooldown\\star4'},
	{text = 'Starburst', value = 'Interface\\Cooldown\\starburst'},
};
MaxDps.FinalTexture = nil;

MaxDps.Colors = {
	Info = '|cFF1394CC',
	Error = '|cFFF0563D',
	Success = '|cFFBCCF02',
}

MaxDps.Classes = {
	[1] = 'Warrior',
	[2] = 'Paladin',
	[3] = 'Hunter',
	[4] = 'Rogue',
	[5] = 'Priest',
	[6] = 'DeathKnight',
	[7] = 'Shaman',
	[8] = 'Mage',
	[9] = 'Warlock',
	[10] = 'Monk',
	[11] = 'Druid',
	[12] = 'DemonHunter',
}

MaxDps.defaultOptions = {
	global = {
		enabled = true,
		disabledInfo = false,
		debugMode = false,
		disableButtonGlow = false,
		onCombatEnter = true,
		texture = 'Interface\\Cooldown\\ping4',
		customTexture = '',
		highlightColor = {
			r = 1,
			g = 1,
			b = 1,
			a = 1
		},
		cooldownColor = {
			r = 0,
			g = 1,
			b = 0,
			a = 1
		},
		interval = 0.15,
		sizeMult = 1.4
	}
};

MaxDps.options = {
	type = 'group',
	name = 'MaxDps Options',
	inline = false,
	args = {
		general = {
			order = 10,
			name = 'General',
			type = 'group',
			args = {
				enable = {
					order = 10,
					name = 'Enable',
					desc = 'Enables / disables the addon',
					type = 'toggle',
					width = 'full',
					set = function(info, val)
						MaxDps.db.global.enabled = val;
					end,
					get = function(info) return MaxDps.db.global.enabled end
				},
				onCombatEnter = {
					order = 20,
					name = 'Enable upon entering combat',
					desc = 'Automatically enables helper upon entering combat',
					type = 'toggle',
					width = 'full',
					set = function(info, val)
						MaxDps.db.global.onCombatEnter = val;
					end,
					get = function(info) return MaxDps.db.global.onCombatEnter end
				},
				disableButtonGlow = {
					order = 30,
					name = 'Dissable blizzard button glow (experimental)',
					desc = 'Disables original blizzard button glow',
					type = 'toggle',
					width = 'full',
					set = function(info, val)
						MaxDps.db.global.disableButtonGlow = val;
						MaxDps:UpdateButtonGlow();
					end,
					get = function(info) return MaxDps.db.global.disableButtonGlow end
				},
				interval = {
					order = 40,
					name = 'Interval in seconds',
					desc = 'Sets how frequent rotation updates will be. Low value will result in fps drops.',
					type = 'range',
					min = 0.01,
					max = 2,
					set = function(info, val) MaxDps.db.global.interval = val end,
					get = function(info) return MaxDps.db.global.interval end
				},
			}
		},
		debug = {
			order = 30,
			name = 'Debug options',
			type = 'group',
			args = {
				debugMode = {
					order = 10,
					name = 'Enable debug mode',
					desc = 'Enables spammy chat messages (use this when addon does not work for you)',
					type = 'toggle',
					width = 'full',
					set = function(info, val)
						MaxDps.db.global.debugMode = val;
					end,
					get = function(info) return MaxDps.db.global.debugMode end
				},
				disabledInfo = {
					order = 20,
					name = 'Disable info messages',
					desc = 'Enables / disables info messages, if you have issues with addon, make sure to deselect this.',
					type = 'toggle',
					width = 'full',
					set = function(info, val)
						MaxDps.db.global.disabledInfo = val;
					end,
					get = function(info) return MaxDps.db.global.disabledInfo end
				},
			}
		},
		overlay = {
			order = 20,
			name = 'Overlay settings',
			type = 'group',
			args = {
				texture = {
					order = 10,
					type = 'select',
					dialogControl = 'LSM30_Background',
					name = 'Texture',
					width = 'normal',
					desc = 'Sets Highlight texture (changing this requires UI Reload)',
					values = function()
						return MaxDps.Textures;
					end,
					get = function()
						return MaxDps.db.global.texture;
					end,
					set = function(self, val)
						MaxDps.db.global.texture = val;
						MaxDps:ApplyOverlayChanges();
					end,
				},
				customTexture = {
					order = 20,
					name = 'Custom Texture',
					desc = 'Sets Highlight texture, has priority over selected one (changing this requires UI Reload)',
					type = 'input',
					width = 'normal',
					set = function(info, val)
						MaxDps.db.global.customTexture = strtrim(val or '');
						MaxDps:ApplyOverlayChanges();
					end,
					get = function(info) return strtrim(MaxDps.db.global.customTexture or '') end
				},
				highlightColor = {
					order = 30,
					name = 'Highlight color',
					desc = 'Sets Highlight color',
					type = 'color',
					width = 'normal',
					set = function(info, r, g, b, a)
						local c = MaxDps.db.global.highlightColor;
						c.r, c.g, c.b, c.a = r, g, b, a;
						MaxDps:ApplyOverlayChanges();
					end,
					get = function(info)
						local c = MaxDps.db.global.highlightColor;
						return c.r, c.g, c.b, c.a;
					end,
					hasAlpha = true
				},
				cooldownColor = {
					order = 40,
					name = 'Cooldown color',
					desc = 'Sets Cooldown color',
					type = 'color',
					width = 'normal',
					set = function(info, r, g, b, a)
						local c = MaxDps.db.global.cooldownColor;
						c.r, c.g, c.b, c.a = r, g, b, a;
						MaxDps:ApplyOverlayChanges();
					end,
					get = function(info)
						local c = MaxDps.db.global.cooldownColor;
						return c.r, c.g, c.b, c.a;
					end,
					hasAlpha = true
				},
				sizeMult = {
					order = 50,
					name = 'Overlay size multiplier',
					desc = 'Sets how big will be overlay on the button. 1 = exactly the same as button',
					type = 'range',
					width = 'full',
					min = 0.5,
					max = 2,
					set = function(info, val)
						MaxDps.db.global.sizeMult = val;
						MaxDps:ApplyOverlayChanges();
					end,
					get = function(info) return MaxDps.db.global.sizeMult or 1.4 end
				},
			}
		},
		reset = {
			name = 'Reset settings',
			desc = 'Resets settings to default values',
			type = 'execute',
			func = function()
				MaxDps:ResetSettings();
				MaxDps:ApplyOverlayChanges();
			end
		}
	},
};

function MaxDps:ResetSettings()
	self.db:ResetDB();
end

local function intervalValidator(self)
	local text = self:GetText();
	text = text:trim();

	local value = tonumber(text);

	if value == nil then
		StdUi:MarkAsValid(self, false);
		return false;
	end

	if value < 0.1 or value > 2 then
		StdUi:MarkAsValid(self, false);
		return false;
	end

	self.value = value;

	StdUi:MarkAsValid(self, true);

	return true;
end

function MaxDps:AddToBlizzardOptions()
	if self.optionsFrame then
		return;
	end

	self.optionsFrame = StdUi:PanelWithTitle(UIParent, 100, 100, 'MaxDps Options');
	self.optionsFrame:Hide();
	self.optionsFrame.name = 'MaxDps';

	local reset = StdUi:Button(self.optionsFrame, 120, 24, 'Reset Options');
	reset:SetScript('OnClick', function() MaxDps:ResetSettings(); end);
	StdUi:GlueTop(reset, self.optionsFrame, -10, -20, 'RIGHT');

	--- GENERAL options

	local general = StdUi:Label(self.optionsFrame, 'General', 14);
	StdUi:SetTextColor(general, 'header');

	local enabled = StdUi:Checkbox(self.optionsFrame, 'Enable addon', 200, 24);
	enabled:SetChecked(MaxDps.db.global.enabled);
	enabled.OnValueChanged = function(_, flag) MaxDps.db.global.enabled = flag; end;

	local onCombatEnter = StdUi:Checkbox(self.optionsFrame, 'Enable upon entering combat', 200, 24);
	onCombatEnter:SetChecked(MaxDps.db.global.onCombatEnter);
	onCombatEnter.OnValueChanged = function(_, flag) MaxDps.db.global.onCombatEnter = flag; end;

	local disableButtonGlow = StdUi:Checkbox(self.optionsFrame, 'Dissable blizzard button glow (experimental)', 200, 24);
	disableButtonGlow:SetChecked(MaxDps.db.global.disableButtonGlow);
	disableButtonGlow.OnValueChanged = function(_, flag) MaxDps.db.global.disableButtonGlow = flag; end;

	local intervalSlider = StdUi:Slider(self.optionsFrame, 100, 16, MaxDps.db.global.interval, false, 0.01, 2);
	local intervalEditBox = StdUi:EditBox(self.optionsFrame, 80, 24, MaxDps.db.global.interval, intervalValidator);

	StdUi:AddLabel(self.optionsFrame, intervalEditBox, 'Interval', 'TOP');

	intervalSlider.OnValueChanged = function(_, val)
		val = math.floor(val * 100) / 100;
		if val < 0.1 then val = 0.1 end
		MaxDps.db.global.interval = val;
		intervalEditBox:SetValue(val);
	end;

	intervalEditBox.OnValueChanged = function(_, val)
		val = math.floor(val * 100) / 100;
		if val < 0.1 then val = 0.1 end
		MaxDps.db.global.interval = val;
		intervalSlider:SetValue(val);
	end;

	StdUi:GlueTop(general, self.optionsFrame, 10, -50, 'LEFT');
	StdUi:GlueBelow(enabled, general, 0, -10, 'LEFT');
	StdUi:GlueRight(onCombatEnter, enabled, 10, 0);
	StdUi:GlueBelow(disableButtonGlow, enabled, 0, -10);

	StdUi:GlueRight(intervalEditBox, disableButtonGlow, 10, -20);
	StdUi:GlueRight(intervalSlider, intervalEditBox, 10, 0);

	--- Debug options

	local debug = StdUi:Label(self.optionsFrame, 'Debug options', 14);
	StdUi:SetTextColor(debug, 'header');

	local debugMode = StdUi:Checkbox(self.optionsFrame, 'Enable debug mode', 200, 24);
	debugMode:SetChecked(MaxDps.db.global.debugMode);
	debugMode.OnValueChanged = function(_, flag) MaxDps.db.global.debugMode = flag; end;

	local disabledInfo = StdUi:Checkbox(self.optionsFrame, 'Enable info messages', 200, 24);
	disabledInfo:SetChecked(not MaxDps.db.global.disabledInfo);
	disabledInfo.OnValueChanged = function(_, flag) MaxDps.db.global.disabledInfo = not flag; end;

	StdUi:GlueBelow(debug, disableButtonGlow, 0, -20, 'LEFT');
	StdUi:GlueBelow(debugMode, debug, 0, -10, 'LEFT');
	StdUi:GlueRight(disabledInfo, debugMode, 10, 0);

	--- Overlay options

	local overlay = StdUi:Label(self.optionsFrame, 'Overlay options', 14);
	StdUi:SetTextColor(overlay, 'header');

	local texture = StdUi:Dropdown(self.optionsFrame, 200, 24, MaxDps.Textures, MaxDps.db.global.texture);
	StdUi:AddLabel(self.optionsFrame, texture, 'Texture', 'TOP');
	local textureIcon = StdUi:Texture(self.optionsFrame, 34, 34, MaxDps.db.global.texture);
	texture.OnValueChanged = function(_, val)
		MaxDps.db.global.texture = val;
		textureIcon:SetTexture(val);
		MaxDps:ApplyOverlayChanges();
	end;

	local customTexture = StdUi:EditBox(self.optionsFrame, 200, 24, strtrim(MaxDps.db.global.customTexture or ''));
	StdUi:AddLabel(self.optionsFrame, customTexture, 'Custom Texture', 'TOP');
	customTexture.OnValueChanged = function(_, val)
		MaxDps.db.global.customTexture = strtrim(val or '');
		MaxDps:ApplyOverlayChanges();
	end;

	local c = MaxDps.db.global.highlightColor;
	local highlightColor = StdUi:ColorInput(self.optionsFrame, 'Highlight color', 200, 24, c.r, c.g, c.b, c.a);
	highlightColor.OnValueChanged = function(_, r, g, b, a)
		c.r, c.g, c.b, c.a = r, g, b, a;
		MaxDps:ApplyOverlayChanges();
	end;

	local cc = MaxDps.db.global.cooldownColor;
	local cooldownColor = StdUi:ColorInput(self.optionsFrame, 'Cooldown color', 200, 24, cc.r, cc.g, cc.b, cc.a);
	cooldownColor.OnValueChanged = function(_, r, g, b, a)
		cc.r, cc.g, cc.b, cc.a = r, g, b, a;
		MaxDps:ApplyOverlayChanges();
	end;

	local sizeSlider = StdUi:Slider(self.optionsFrame, 100, 16, MaxDps.db.global.sizeMult or 1.4, false, 0.01, 2);
	local sizeEditBox = StdUi:EditBox(self.optionsFrame, 80, 24, MaxDps.db.global.sizeMult or 1.4, intervalValidator);

	StdUi:AddLabel(self.optionsFrame, sizeEditBox, 'Size Multiplier', 'TOP', 80);

	sizeSlider.OnValueChanged = function(_, val)
		val = math.floor(val * 100) / 100;
		if val < 0.1 then val = 0.1 end
		MaxDps.db.global.sizeMult = val;
		sizeEditBox:SetValue(val);
	end;

	sizeEditBox.OnValueChanged = function(_, val)
		val = math.floor(val * 100) / 100;
		if val < 0.1 then val = 0.1 end
		MaxDps.db.global.sizeMult = val;
		sizeSlider:SetValue(val);
	end;

	StdUi:GlueBelow(overlay, debugMode, 0, -10, 'LEFT');
	StdUi:GlueBelow(texture, overlay, 0, -30, 'LEFT');
	StdUi:GlueRight(textureIcon, texture, 10, 0);
	StdUi:GlueRight(customTexture, textureIcon, 10, 0);
	StdUi:GlueBelow(highlightColor, texture, 0, -10, 'LEFT');
	StdUi:GlueRight(cooldownColor, highlightColor, 10, 0);
	StdUi:GlueBelow(sizeEditBox, highlightColor, 0, -30, 'LEFT');
	StdUi:GlueRight(sizeSlider, sizeEditBox, 10, 0);

	InterfaceOptions_AddCategory(self.optionsFrame);
end