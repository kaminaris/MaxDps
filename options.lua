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

function MaxDps:ResetSettings()
	self.db:ResetDB();
end

StdUi:RegisterWidget('SliderWithBox', function(stdUi, parent, width, height, value, min, max)
	local widget = CreateFrame('Frame', nil, parent);
	StdUi:SetObjSize(widget, width, height);

	widget.label = stdUi:Label(widget, '');
	widget.slider = stdUi:Slider(widget, 100, 12, value, false);
	widget.editBox = stdUi:NumericBox(widget, 80, 16, value);
	widget.editBox:SetNumeric(false);
	widget.leftLabel = stdUi:Label(widget, '');
	widget.rightLabel = stdUi:Label(widget, '');

	widget.slider.widget = widget;
	widget.editBox.widget = widget;

	function widget:SetLabelText(text)
		self.label:SetText(text);
	end

	function widget:SetMinMaxValues(min, max)
		widget.min = min;
		widget.max = max;

		widget.editBox:SetMinMaxValue(min, max);
		widget.slider:SetMinMaxValues(min, max);
		widget.leftLabel:SetText(min);
		widget.rightLabel:SetText(max);
	end

	if min and max then
		widget:SetMinMaxValues(min, max);
	end

	widget.slider.OnValueChanged = function(s, val)
		if s.widget.lock then return end;

		val = math.floor(val * 100) / 100;
		if val < s.widget.min then val = s.widget.min end
		if val > s.widget.max then val = s.widget.max end

		if widget.OnValueChanged then
			widget.OnValueChanged(widget, val);
		end

		s.widget.lock = true;
		s.widget.editBox:SetValue(val);
		s.widget.lock = false;
	end;

	widget.editBox.OnValueChanged = function(e, val)
		if e.widget.lock then return end;

		val = math.floor(val * 100) / 100;
		if val < e.widget.min then val = e.widget.min end
		if val > e.widget.max then val = e.widget.max end

		if widget.OnValueChanged then
			widget.OnValueChanged(widget, val);
		end

		e.widget.lock = true;
		e.widget.slider:SetValue(val);
		e.widget.lock = false;
	end;

	stdUi:GlueTop(widget.label, widget, 0, 0, 'CENTER');
	widget.slider:SetPoint('LEFT', widget, 'LEFT', 0, 0);
	widget.slider:SetPoint('RIGHT', widget, 'RIGHT', 0, 0);
	stdUi:GlueBottom(widget.editBox, widget, 0, 0, 'CENTER');
	widget.leftLabel:SetPoint('TOPLEFT', widget.slider, 'BOTTOMLEFT', 0, 0);
	widget.rightLabel:SetPoint('TOPRIGHT', widget.slider, 'BOTTOMRIGHT', 0, 0);

	return widget;
end);

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

	local optionsFrame = StdUi:PanelWithTitle(UIParent, 100, 100, 'MaxDps Options');
	self.optionsFrame = optionsFrame;
	optionsFrame:Hide();
	optionsFrame.name = 'MaxDps';

	StdUi:EasyLayout(optionsFrame, { padding = { top = 40 } });

	local reset = StdUi:Button(optionsFrame, 120, 24, 'Reset Options');
	reset:SetScript('OnClick', function() MaxDps:ResetSettings(); end);

	--- GENERAL options

	local general = StdUi:Label(optionsFrame, 'General', 14);
	StdUi:SetTextColor(general, 'header');

	local enabled = StdUi:Checkbox(optionsFrame, 'Enable addon', 200, 24);
	enabled:SetChecked(MaxDps.db.global.enabled);
	enabled.OnValueChanged = function(_, flag) MaxDps.db.global.enabled = flag; end;

	local onCombatEnter = StdUi:Checkbox(optionsFrame, 'Enable upon entering combat', 200, 24);
	onCombatEnter:SetChecked(MaxDps.db.global.onCombatEnter);
	onCombatEnter.OnValueChanged = function(_, flag) MaxDps.db.global.onCombatEnter = flag; end;

	local disableButtonGlow = StdUi:Checkbox(optionsFrame, 'Dissable blizzard button glow (experimental)', 200, 24);
	disableButtonGlow:SetChecked(MaxDps.db.global.disableButtonGlow);
	disableButtonGlow.OnValueChanged = function(_, flag) MaxDps.db.global.disableButtonGlow = flag; end;

	local interval = StdUi:SliderWithBox(optionsFrame, 100, 48, MaxDps.db.global.interval, 0.01, 2);
	interval:SetLabelText('Update Interval');
	interval.OnValueChanged = function(_, val) MaxDps.db.global.interval = val; end;

	--- Debug options

	local debug = StdUi:Label(optionsFrame, 'Debug options', 14);
	StdUi:SetTextColor(debug, 'header');

	local debugMode = StdUi:Checkbox(optionsFrame, 'Enable debug mode', 200, 24);
	debugMode:SetChecked(MaxDps.db.global.debugMode);
	debugMode.OnValueChanged = function(_, flag) MaxDps.db.global.debugMode = flag; end;

	local disabledInfo = StdUi:Checkbox(optionsFrame, 'Enable info messages', 200, 24);
	disabledInfo:SetChecked(not MaxDps.db.global.disabledInfo);
	disabledInfo.OnValueChanged = function(_, flag) MaxDps.db.global.disabledInfo = not flag; end;


	--- Overlay options

	local overlay = StdUi:Label(optionsFrame, 'Overlay options', 14);
	StdUi:SetTextColor(overlay, 'header');

	local texture = StdUi:Dropdown(optionsFrame, 200, 24, MaxDps.Textures, MaxDps.db.global.texture);
	StdUi:AddLabel(optionsFrame, texture, 'Texture', 'TOP');
	local textureIcon = StdUi:Texture(optionsFrame, 34, 34, MaxDps.db.global.texture);
	texture.OnValueChanged = function(_, val)
		MaxDps.db.global.texture = val;
		textureIcon:SetTexture(val);
		MaxDps:ApplyOverlayChanges();
	end;

	local customTexture = StdUi:EditBox(optionsFrame, 200, 24, strtrim(MaxDps.db.global.customTexture or ''));
	StdUi:AddLabel(optionsFrame, customTexture, 'Custom Texture', 'TOP');
	customTexture.OnValueChanged = function(_, val)
		MaxDps.db.global.customTexture = strtrim(val or '');
		MaxDps:ApplyOverlayChanges();
	end;

	local c = MaxDps.db.global.highlightColor;
	local highlightColor = StdUi:ColorInput(optionsFrame, 'Highlight color', 200, 24, c.r, c.g, c.b, c.a);
	highlightColor.OnValueChanged = function(_, r, g, b, a)
		c.r, c.g, c.b, c.a = r, g, b, a;
		MaxDps:ApplyOverlayChanges();
	end;

	local cc = MaxDps.db.global.cooldownColor;
	local cooldownColor = StdUi:ColorInput(optionsFrame, 'Cooldown color', 200, 24, cc.r, cc.g, cc.b, cc.a);
	cooldownColor.OnValueChanged = function(_, r, g, b, a)
		cc.r, cc.g, cc.b, cc.a = r, g, b, a;
		MaxDps:ApplyOverlayChanges();
	end;


	local sizeMultiplier = StdUi:SliderWithBox(optionsFrame, 100, 48, MaxDps.db.global.sizeMult or 1.4, 0.5, 2);
	sizeMultiplier:SetLabelText('Size Multiplier');
	sizeMultiplier.OnValueChanged = function(_, val) MaxDps.db.global.sizeMult = val; end;


	optionsFrame:AddRow():AddElement(general);
	optionsFrame:AddRow():AddElements(enabled, onCombatEnter, { column = 'even' });
	optionsFrame:AddRow():AddElements(disableButtonGlow, interval, { column = 'even' });
	optionsFrame:AddRow():AddElement(debug);
	optionsFrame:AddRow():AddElements(debugMode, disabledInfo, { column = 'even' });
	optionsFrame:AddRow():AddElement(overlay);
	local rowOverlay = optionsFrame:AddRow({ margin = { top = 20} });
	rowOverlay:AddElement(texture, { column = 5 });
	rowOverlay:AddElement(textureIcon, { column = 1 });
	rowOverlay:AddElement(customTexture, { column = 6 });
	optionsFrame:AddRow():AddElements(highlightColor, cooldownColor, { column = 'even' });
	optionsFrame:AddRow():AddElement(sizeMultiplier, { column = 6 });

	optionsFrame:SetScript('OnShow', function(of)
		of:DoLayout();
	end);

	InterfaceOptions_AddCategory(optionsFrame);
end