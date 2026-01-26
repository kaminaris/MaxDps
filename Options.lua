--- @type MaxDps MaxDps
local _, MaxDps = ...

---@type StdUi
local StdUi = LibStub('StdUi')

MaxDps.Textures = {
	{text = 'Ping', value = 'Interface\\Cooldown\\ping4'},
	{text = 'Star', value = 'Interface\\Cooldown\\star4'},
	{text = 'Starburst', value = 'Interface\\Cooldown\\starburst'},
}
MaxDps.FinalTexture = nil

MaxDps.PrintLevel = {
	{text = 'Error', value = 'error'},
	{text = 'Info', value = 'info'},
	{text = 'Error & Info', value = 'errorinfo'},
	{text = 'All', value = 'all'},
	{text = 'None', value = 'none'},
}

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
	[13] = 'Evoker',
}

MaxDps.defaultOptions = {
	global = {
		enabled = true,
		cdOnlyMode = false,
		disabledInfo = 'errorinfo',
		debugMode = false,
		forceSingle = false,
		forceTargetAmount = false,
		forceTargetAmountCount = 1,
		disableButtonGlow = false,

		customGlow = false,
		customGlowType = 'pixel',

		-- Settings for pixel glow
		customGlowLines = 8,
		customGlowFrequency = 0.25,
		customGlowLength = 3,
		customGlowThickness = 3,

		-- Settings for particle glow
		customGlowParticles = 4,
		customGlowScale = 1,
		customGlowParticleFrequency = 0.125,

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
		sizeMult = 1.4,
        spellFrame = {
            enabled = true,
			isMovable = false,
			spellID = 116,
			x = 0,
			y = 0,
        }
	}
}

function MaxDps:ResetSettings()
	self.db:ResetDB()
end

local function intervalValidator(self)
	local text = self:GetText()
	text = text:trim()

	local value = tonumber(text)

	if value == nil then
		StdUi:MarkAsValid(self, false)
		return false
	end

	if value < 0.1 or value > 2 then
		StdUi:MarkAsValid(self, false)
		return false
	end

	self.value = value

	StdUi:MarkAsValid(self, true)

	return true
end

function MaxDps:AddToBlizzardOptions()
	if self.optionsFrame then
		return
	end

	local optionsFrame = StdUi:PanelWithTitle(UIParent, 100, 150, 'MaxDps Options')
	self.optionsFrame = optionsFrame
	optionsFrame:Hide()
	optionsFrame.name = 'MaxDps'

	StdUi:EasyLayout(optionsFrame, { padding = { top = 40 } })

	local reset = StdUi:Button(optionsFrame, 120, 24, 'Reset Options')
	reset:SetScript('OnClick', function() MaxDps:ResetSettings() end)

	--- GENERAL options

	local general = StdUi:Label(optionsFrame, 'General', 14)
	StdUi:SetTextColor(general, 'header')

	local enabled = StdUi:Checkbox(optionsFrame, 'Enable addon', 200, 24)
	enabled:SetChecked(MaxDps.db.global.enabled)
	enabled.OnValueChanged = function(_, flag)
		MaxDps.db.global.enabled = flag
		MaxDps[(MaxDps.db.global.enabled and "EnableRotation" or "DisableRotation")](MaxDps)
	end

	local cdOnlyMode = StdUi:Checkbox(optionsFrame, 'Enable CD Only Mode', 200, 24)
	cdOnlyMode:SetChecked(MaxDps.db.global.cdOnlyMode)
	cdOnlyMode.OnValueChanged = function(_, flag) MaxDps.db.global.cdOnlyMode = flag end

	local onCombatEnter = StdUi:Checkbox(optionsFrame, 'Enable upon entering combat', 200, 24)
	onCombatEnter:SetChecked(MaxDps.db.global.onCombatEnter)
	onCombatEnter.OnValueChanged = function(_, flag) MaxDps.db.global.onCombatEnter = flag end

	local forceSingle = StdUi:Checkbox(optionsFrame, 'Force single target mode', 200, 24)
	forceSingle:SetChecked(MaxDps.db.global.forceSingle)
	forceSingle.OnValueChanged = function(_, flag) MaxDps.db.global.forceSingle = flag end

	local forceTargetAmount = StdUi:Checkbox(optionsFrame, 'Enable forcing the number of targets', 200, 24)
	forceTargetAmount:SetChecked(MaxDps.db.global.forceTargetAmount)
	forceTargetAmount.OnValueChanged = function(_, flag) MaxDps.db.global.forceTargetAmount = flag end

	local forceTargetAmountCount = StdUi:SliderWithBox(optionsFrame, 100, 48, MaxDps.db.global.forceTargetAmountCount, 1, 10)
	forceTargetAmountCount:SetPrecision(0)
	StdUi:AddLabel(optionsFrame, forceTargetAmountCount, 'Number of targets to force the rotation to use')
	forceTargetAmountCount.OnValueChanged = function(_, val) MaxDps.db.global.forceTargetAmountCount = val end

	local disableConsumables = StdUi:Checkbox(optionsFrame, 'Disable consumable support', 200, 24)
	disableConsumables:SetChecked(MaxDps.db.global.disableConsumables)
	disableConsumables.OnValueChanged = function(_, flag) MaxDps.db.global.disableConsumables = flag end

	local loadModuleBtn = StdUi:Button(optionsFrame, nil, 24, 'Load current class module')
	loadModuleBtn:SetScript('OnClick', function() MaxDps:InitRotations() end)

	local disableButtonGlow = StdUi:Checkbox(optionsFrame, 'Dissable blizzard button glow (experimental)', 200, 24)
	disableButtonGlow:SetChecked(MaxDps.db.global.disableButtonGlow)
	disableButtonGlow.OnValueChanged = function(_, flag)
		MaxDps.db.global.disableButtonGlow = flag
		MaxDps:UpdateButtonGlow()
	end

	local interval = StdUi:SliderWithBox(optionsFrame, 100, 48, MaxDps.db.global.interval, 0.01, 2)
	interval:SetPrecision(2)
	StdUi:AddLabel(optionsFrame, interval, 'Update Interval')
	interval.OnValueChanged = function(_, val) MaxDps.db.global.interval = val end

	--- Debug options

	local debug = StdUi:Label(optionsFrame, 'Debug options', 14)
	StdUi:SetTextColor(debug, 'header')

	local debugMode = StdUi:Checkbox(optionsFrame, 'Enable debug mode', 200, 24)
	debugMode:SetChecked(MaxDps.db.global.debugMode)
	debugMode.OnValueChanged = function(_, flag) MaxDps.db.global.debugMode = flag end

	local disabledInfo = StdUi:Dropdown(optionsFrame, 200, 24, MaxDps.PrintLevel, MaxDps.db.global.disabledInfo)
	StdUi:AddLabel(optionsFrame, disabledInfo, 'Chat Message Level', 'TOP')
	disabledInfo.OnValueChanged = function(_, val)
		MaxDps.db.global.disabledInfo = val
	end


	--- Overlay options

	local overlay = StdUi:Label(optionsFrame, 'Overlay options', 14)
	StdUi:SetTextColor(overlay, 'header')

	local texture = StdUi:Dropdown(optionsFrame, 200, 24, MaxDps.Textures, MaxDps.db.global.texture)
	StdUi:AddLabel(optionsFrame, texture, 'Texture', 'TOP')
	local textureIcon = StdUi:Texture(optionsFrame, 34, 34, MaxDps.db.global.texture)
	texture.OnValueChanged = function(_, val)
		MaxDps.db.global.texture = val
		textureIcon:SetTexture(val)
		MaxDps:ApplyOverlayChanges()
	end

	local customTexture = StdUi:EditBox(optionsFrame, 200, 24, strtrim(MaxDps.db.global.customTexture or ''))
	StdUi:AddLabel(optionsFrame, customTexture, 'Custom Texture', 'TOP')
	customTexture.OnValueChanged = function(_, val)
		MaxDps.db.global.customTexture = strtrim(val or '')
		MaxDps:ApplyOverlayChanges()
	end

	local highlightColor = StdUi:ColorInput(optionsFrame, 'Highlight color', 200, 24, MaxDps.db.global.highlightColor)
	highlightColor.OnValueChanged = function(_, newColor)
		MaxDps.db.global.highlightColor = newColor
		MaxDps:ApplyOverlayChanges()
	end

	local cooldownColor = StdUi:ColorInput(optionsFrame, 'Cooldown color', 200, 24, MaxDps.db.global.cooldownColor)
	cooldownColor.OnValueChanged = function(_, newColor)
		MaxDps.db.global.cooldownColor = newColor
		MaxDps:ApplyOverlayChanges()
	end

	local sizeMultiplier = StdUi:SliderWithBox(optionsFrame, 100, 48, MaxDps.db.global.sizeMult or 1.4, 0.5, 2)
	StdUi:AddLabel(optionsFrame, sizeMultiplier, 'Size Multiplier')
	sizeMultiplier.OnValueChanged = function(_, val) MaxDps.db.global.sizeMult = val end

	-- Spell Frame Options
	local spellFrameLabel = StdUi:Label(optionsFrame, 'Spell Frame', 14)
	StdUi:SetTextColor(spellFrameLabel, 'header')

	local spellFrameEnabled = StdUi:Checkbox(optionsFrame, 'Enable spell frame', 200, 24)
	spellFrameEnabled:SetChecked(MaxDps.db.global.spellFrame.enabled)
	spellFrameEnabled.OnValueChanged = function(_, flag)
		MaxDps.db.global.spellFrame.enabled = flag
	end

	local spellFramePosx = StdUi:SliderWithBox(optionsFrame, 100, 48, MaxDps.db.global.spellFrame.pos.x or 0, -2000, 2000)
	StdUi:AddLabel(optionsFrame, spellFramePosx, 'x Possition')
	spellFramePosx.OnValueChanged = function(_, val) MaxDps.db.global.spellFrame.pos.x = val end

	local spellFramePosy = StdUi:SliderWithBox(optionsFrame, 100, 48, MaxDps.db.global.spellFrame.pos.y or 0, -2000, 2000)
	StdUi:AddLabel(optionsFrame, spellFramePosy, 'y Possition')
	spellFramePosy.OnValueChanged = function(_, val) MaxDps.db.global.spellFrame.pos.y = val end

	--- Pixel Glow options

	local customGlowHeader = StdUi:Label(optionsFrame, 'Custom Glow', 14)
	StdUi:SetTextColor(customGlowHeader, 'header')

	local customGlow = StdUi:Checkbox(optionsFrame, 'Use Custom Glow', 200, 24)
	customGlow:SetChecked(MaxDps.db.global.customGlow)
	customGlow.OnValueChanged = function(_, flag)
		MaxDps.db.global.customGlow = flag
		MaxDps:ApplyOverlayChanges()
	end

	local customGlowTypes = {
		{text = 'Pixel', value = 'pixel'},
		{text = 'Particle', value = 'particle'},
	}
	local customGlowType = StdUi:Dropdown(optionsFrame, 200, 24, customGlowTypes, MaxDps.db.global.customGlowType)
	StdUi:AddLabel(optionsFrame, customGlowType, 'Custom Glow Type', 'TOP')
	customGlowType.OnValueChanged = function(_, val)
		MaxDps.db.global.customGlowType = val
		MaxDps:ApplyOverlayChanges()
	end

	optionsFrame:AddRow():AddElement(general)
	optionsFrame:AddRow():AddElements(enabled, cdOnlyMode, { column = 'even' })
	optionsFrame:AddRow():AddElements(onCombatEnter, disableConsumables, { column = 'even' })
	optionsFrame:AddRow():AddElements(disableButtonGlow, forceSingle, { column = 'even' })
	optionsFrame:AddRow():AddElements(forceTargetAmount,forceTargetAmountCount, { column = 'even' })
	optionsFrame:AddRow():AddElements(interval, loadModuleBtn, { column = 'even' })
	optionsFrame:AddRow():AddElement(debug)
	optionsFrame:AddRow():AddElements(debugMode, disabledInfo, { column = 'even' })
	optionsFrame:AddRow():AddElement(overlay)
	local rowOverlay = optionsFrame:AddRow({ margin = { top = 20} })
	rowOverlay:AddElement(texture, { column = 5 })
	rowOverlay:AddElement(textureIcon, { column = 1 })
	rowOverlay:AddElement(customTexture, { column = 6 })
	optionsFrame:AddRow():AddElements(highlightColor, cooldownColor, { column = 'even' })
	optionsFrame:AddRow():AddElement(sizeMultiplier, { column = 6, margin = { top = 15 } })
	optionsFrame:AddRow():AddElement(customGlowHeader)
	optionsFrame:AddRow():AddElements(customGlow, customGlowType, { column = 'even' })
	optionsFrame:AddRow():AddElement(spellFrameLabel)
	optionsFrame:AddRow():AddElement(spellFrameEnabled)
	optionsFrame:AddRow():AddElements(spellFramePosx, spellFramePosy, { column = 'even' })

	-- no need to :SetScript when we have a 'native' Settings API callback for Panel:Show
	optionsFrame.OnRefresh = function()
		optionsFrame:DoLayout()
		-- Settings cannot know the registered panel changed size AFTER showing, so rather
		-- than jump through hoops to force a redraw / show a scrollbar, this is a simple workaround
		optionsFrame:SetScale(.75)
	end

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(optionsFrame)
	else
		local category, layout = Settings.RegisterCanvasLayoutCategory(optionsFrame, optionsFrame.name);
		Settings.RegisterAddOnCategory(category);
		MaxDps.settingsCategory = category
	end

	self:AddCustomGlowOptions()
	--self:AddSpellFrameOptions()
end

function MaxDps:AddCustomGlowOptions()
	local config = {
		layoutConfig = { padding = { top = 30 } },
		database     = self.db.global,
		rows         = {
			[1] = {
				pixelGlow = {
					type = 'header',
					label = 'Pixel Glow'
				}
			},
			[2] = {
				customGlowLines     = {
					type   = 'sliderWithBox',
					label  = 'Number of lines',
					min    = 2,
					max    = 10,
					column = 6
				},
				customGlowFrequency = {
					type   = 'sliderWithBox',
					label  = 'Frequency',
					min    = 0.01,
					max    = 2,
					column = 6
				},
			},
			[3] = {
				customGlowLength     = {
					type   = 'sliderWithBox',
					label  = 'Line Length',
					min    = 2,
					max    = 20,
					column = 6
				},
				customGlowThickness = {
					type   = 'sliderWithBox',
					label  = 'Thickness',
					min    = 1,
					max    = 5,
					column = 6
				},
			},

			[4] = {
				particleGlow = {
					type = 'header',
					label = 'Particle Glow'
				}
			},

			[5] = {
				customGlowParticles = {
					type      = 'sliderWithBox',
					label     = 'Number of Particles',
					min       = 4,
					max       = 16,
					precision = 0,
					column    = 6
				},
				customGlowScale = {
					type   = 'sliderWithBox',
					label  = 'Particle Scale',
					min    = 0.2,
					max    = 3,
					column = 6
				},
			},

			[6] = {
				customGlowParticleFrequency     = {
					type   = 'sliderWithBox',
					label  = 'Frequency',
					min    = 0.01,
					max    = 2,
					column = 6
				},
			},
		},
	}

	local customGlowOptionsFrame = StdUi:PanelWithTitle(nil, 100, 100, 'Custom Glow Options')
	customGlowOptionsFrame:Hide()
	customGlowOptionsFrame.name = 'CustomGlow'
	customGlowOptionsFrame.parent = 'MaxDps'

	StdUi:BuildWindow(customGlowOptionsFrame, config)

	customGlowOptionsFrame:SetScript('OnShow', function(of)
		of:DoLayout()
	end)

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(customGlowOptionsFrame)
	else
		-- make the custom glow options a subcategory as intended, do not override the main options category
		local category, layout = Settings.RegisterCanvasLayoutSubcategory(MaxDps.settingsCategory, customGlowOptionsFrame, customGlowOptionsFrame.name);
	end
end

function MaxDps:AddSpellFrameOptions()
	local config = {
		layoutConfig = { padding = { top = 30 } },
		database     = self.db.global.spellFrame,
		rows         = {
			[1] = {
				spellFrame = {
					type = 'header',
					label = 'Spell Frame'
				}
			},
			[2] = {
				enabled = {
					type = 'checkbox',
					label = 'Enable'
				}
			},
			[3] = {
				x = {
					type   = 'sliderWithBox',
					label  = 'x possition',
					min    = -2000,
					max    = 2000,
					column = 6
				},
			},
			[4] = {
				y = {
					type   = 'sliderWithBox',
					label  = 'y possition',
					min    = -2000,
					max    = 2000,
					column = 6
				},
			},
		},
	}

	local SpellFrameOptionsFrame = StdUi:PanelWithTitle(nil, 100, 100, 'Spell Frame Options')
	SpellFrameOptionsFrame:Hide()
	SpellFrameOptionsFrame.name = 'SpellFrame'
	SpellFrameOptionsFrame.parent = 'MaxDps'

	StdUi:BuildWindow(SpellFrameOptionsFrame, config)

	SpellFrameOptionsFrame:SetScript('OnShow', function(of)
		of:DoLayout()
	end)

	if InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(SpellFrameOptionsFrame)
	else
		-- make the custom glow options a subcategory as intended, do not override the main options category
		local category, layout = Settings.RegisterCanvasLayoutSubcategory(MaxDps.settingsCategory, SpellFrameOptionsFrame, SpellFrameOptionsFrame.name);
	end
end

