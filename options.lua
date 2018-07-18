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
