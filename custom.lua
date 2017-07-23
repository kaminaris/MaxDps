local SharedMedia = LibStub('LibSharedMedia-3.0');
local AceGUI = LibStub('AceGUI-3.0');

MaxDps.Specs = {
	[1] = {
		[1] = 'Arms',
		[2] = 'Fury',
		[3] = 'Protection',
	},
	[2] = {
		[1] = 'Holy',
		[2] = 'Protection',
		[3] = 'Retribution',
	},
	[3] = {
		[1] = 'BeastMastery',
		[2] = 'Marksmanship',
		[3] = 'Survival',
	},
	[4] = {
		[1] = 'Assassination',
		[2] = 'Outlaw',
		[3] = 'Subtlety',
	},
	[5] = {
		[1] = 'Discipline',
		[2] = 'Holy',
		[3] = 'Shadow',
	},
	[6] = {
		[1] = 'Blood',
		[2] = 'Frost',
		[3] = 'Unholy',
	},
	[7] = {
		[1] = 'Elemental',
		[2] = 'Enhancement',
		[3] = 'Restoration',
	},
	[8] = {
		[1] = 'Arcane',
		[2] = 'Fire',
		[3] = 'Frost',
	},
	[9] = {
		[1] = 'Affliction',
		[2] = 'Demonology',
		[3] = 'Destruction',
	},
	[10] = {
		[1] = 'Brewmaster',
		[2] = 'Mistweaver',
		[3] = 'Windwalker',
	},
	[11] = {
		[1] = 'Balance',
		[2] = 'Feral',
		[3] = 'Guardian',
		[4] = 'Restoration',
	},
	[12] = {
		[1] = 'Havoc',
		[2] = 'Vengeance',
	},
}

MaxDps.CustomRotations = {};

StaticPopupDialogs['REMOVE_MAXDPS_ROTATION'] = {
	text = 'Are you sure?',
	button1 = 'Yes',
	button2 = 'No',
	OnAccept = function()
		MaxDps:RemoveCustomRotation();
	end,
	OnCancel = function (_,reason)
	end,
	whileDead = true,
	hideOnEscape = true,
}

AceGUI:RegisterLayout('2Columns3', function(content, children)
	if children[1] then
		children[1]:SetWidth(200)
		children[1].frame:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0)
		children[1].frame:SetPoint('BOTTOMLEFT', content, 'BOTTOMLEFT', 0, 0)
		children[1].frame:Show();

		if children[1].DoLayout then
			children[1]:DoLayout()
		end
	end

	if children[2] then
		children[2].frame:SetPoint('TOPLEFT', children[1].frame, 'TOPRIGHT', 0, 0)
		children[2].frame:SetPoint('RIGHT', content, 'RIGHT', 0, 0)
		children[2]:SetHeight(100)
		children[2].frame:Show();

		if children[2].DoLayout then
			children[2]:DoLayout()
		end
	end

	if children[3] then
		children[3].frame:SetPoint('TOPLEFT', children[2].frame, 'BOTTOMLEFT', 0, 0)
		children[3].frame:SetPoint('BOTTOMRIGHT', content, 'BOTTOMRIGHT', 0, 0)
		children[3].frame:Show();

		if children[3].DoLayout then
			children[3]:DoLayout()
		end
	end

	if(content.obj.LayoutFinished) then
		content.obj:LayoutFinished(content.obj, nil, nil);
	end
end)

function MaxDps:ShowCustomWindow()
	if not self.CustomWindow then
		self.CustomWindow = AceGUI:Create('Window');
		self.CustomWindow:SetTitle('MaxDps Custom Rotations');
		self.CustomWindow.frame:SetFrameStrata('DIALOG');
		self.CustomWindow:SetLayout('2Columns3');
		self.CustomWindow:SetWidth(700);
		self.CustomWindow:SetHeight(550);
		self.CustomWindow:EnableResize(true);
		self.CustomWindow:SetCallback('OnClose', function(widget)
			MaxDps:LoadCustomRotations();
		end)

		local scrollLeft = AceGUI:Create('ScrollFrame');
		scrollLeft:SetLayout('Flow');
		self.CustomWindow.scrollLeft = scrollLeft;
		self.CustomWindow:AddChild(scrollLeft);

		local scrollRight = AceGUI:Create('ScrollFrame');
		scrollRight:SetLayout('Flow');
		self.CustomWindow:AddChild(scrollRight);

--		Rotation Name
		local rotationName = AceGUI:Create('EditBox');
		rotationName:SetLabel('Rotation Name');
		rotationName:SetCallback('OnTextChanged', function(self, event, text)
			if not MaxDps.CurrentEditRotation then return end;
			MaxDps.CurrentEditRotation.name = text;
			MaxDps:UpdateCustomRotationButtons();
		end);
		scrollRight:AddChild(rotationName);
		self.CustomWindow.rotationName = rotationName;

--		Rotation Class
		local rotationClass = AceGUI:Create('Dropdown');
		rotationClass:SetLabel('Class');
		rotationClass:SetList(MaxDps.Classes);
		rotationClass:SetCallback('OnValueChanged', function(self, event, key)
			if not MaxDps.CurrentEditRotation then return end;
			MaxDps.CurrentEditRotation.class = key;
			local specs = MaxDps.Specs[key];
			if specs then
				MaxDps.CustomWindow.rotationSpec:SetList(specs);
			end
		end);
		scrollRight:AddChild(rotationClass);
		self.CustomWindow.rotationClass = rotationClass;

--		Rotation Spec
		local rotationSpec = AceGUI:Create('Dropdown');
		rotationSpec:SetLabel('Spec');
		rotationSpec:SetCallback('OnValueChanged', function(self, event, key)
			if not MaxDps.CurrentEditRotation then return end;
			MaxDps.CurrentEditRotation.spec = key;
		end);
		scrollRight:AddChild(rotationSpec);
		self.CustomWindow.rotationSpec = rotationSpec;

--		Rotation Enabled
		local rotationEnabled = AceGUI:Create('CheckBox');
		rotationEnabled:SetLabel('Enabled');
		rotationEnabled:SetCallback('OnValueChanged', function(self, event, val)
			if not MaxDps.CurrentEditRotation then return end;
			MaxDps.CurrentEditRotation.enabled = val;
		end);
		scrollRight:AddChild(rotationEnabled);
		self.CustomWindow.rotationEnabled = rotationEnabled;

--		Rotation Delete
		local rotationDelete = AceGUI:Create('Button');
		rotationDelete:SetText('Remove');
		rotationDelete:SetCallback('OnClick', function()
			if not MaxDps.CurrentEditRotation then return end;
			StaticPopup_Show('REMOVE_MAXDPS_ROTATION');
		end);
		scrollRight:AddChild(rotationDelete);

--		Editor
		local editor = AceGUI:Create('MultiLineEditBox');
		editor:SetLabel('Custom Rotation');
		editor.button:Hide();
		local fontPath = SharedMedia:Fetch('font', 'Fira Mono Medium');
		if(fontPath) then
			editor.editBox:SetFont(fontPath, 12);
		end
		editor:SetCallback('OnTextChanged', function(self, event, value)
			if not MaxDps.CurrentEditRotation then return end;
			value = IndentationLib.decode(value);
			if MaxDps.CurrentEditRotation then
				MaxDps.CurrentEditRotation.fn = value;
			end
		end);
		self.CustomWindow:AddChild(editor);
		self.CustomWindow.editor = editor;

		IndentationLib.enable(editor.editBox, nil, 4);

		self:UpdateCustomRotationButtons();
		self:EnableDisableCustomFields(true, true);
	end
	self:DisableRotation();
	self.CustomWindow:Show();
end

function MaxDps:UpdateCustomRotationButtons()
	self.CustomWindow.scrollLeft:ReleaseChildren();

	local btn = AceGUI:Create('Button');

	btn:SetFullWidth(true);
	btn:SetText('Add Rotation');
	btn:SetHeight(40);
	btn.text:SetTextColor(1, 0, 0);
	btn:SetCallback('OnClick', function()
		MaxDps:AddCustomRotation();
	end);

	self.CustomWindow.scrollLeft:AddChild(btn);

	for k, rotation in pairs(self.db.global.customRotations) do
		local btn = AceGUI:Create('Button');

		btn:SetFullWidth(true);
		btn:SetText(rotation.name);
		btn:SetHeight(40);
		btn:SetCallback('OnClick', function(self, event)
			for k, btn in pairs(MaxDps.CustomWindow.scrollLeft.children) do
				if k > 1 then
					btn.text:SetTextColor(1, 1, 1);
				end
			end
			self.text:SetTextColor(0, 1, 0);
			MaxDps:EditRotation(rotation);
		end);
		if self.CurrentEditRotation == rotation then
			btn.text:SetTextColor(0, 1, 0);
		else
			btn.text:SetTextColor(1, 1, 1);
		end
		self.CustomWindow.scrollLeft:AddChild(btn);
	end
	self.CustomWindow.scrollLeft:DoLayout();
end

function MaxDps:AddCustomRotation()
	local customRotation = {
		name = 'New Rotation',
		enabled = false,
		class = nil,
		spec = nil,
		fn = "function(_, timeShift, currentSpell, gcd, talents)\n    \nend",
	};

	tinsert(self.db.global.customRotations, customRotation);
	self:UpdateCustomRotationButtons();
	MaxDps:EditRotation(customRotation);
end

function MaxDps:RemoveCustomRotation()
	for k, rotation in pairs(self.db.global.customRotations) do
		if rotation == MaxDps.CurrentEditRotation then
			self.db.global.customRotations[k] = nil;
		end
	end

	self.CurrentEditRotation = nil;
	self:UpdateCustomRotationButtons();
	self:EnableDisableCustomFields(true, true);
end

function MaxDps:EditRotation(rotation)
	self.CurrentEditRotation = rotation;

	self.CustomWindow.rotationName:SetText(rotation.name);
	self.CustomWindow.rotationEnabled:SetValue(rotation.enabled);
	self.CustomWindow.rotationClass:SetValue(rotation.class);
	local specs = MaxDps.Specs[rotation.class];
	if specs then
		self.CustomWindow.rotationSpec:SetList(specs);
	else
		self.CustomWindow.rotationSpec:SetList({});
	end
	self.CustomWindow.rotationSpec:SetValue(rotation.spec);
	self.CustomWindow.editor:SetText(IndentationLib.encode(rotation.fn));
	self:EnableDisableCustomFields(false);
end

function MaxDps:EnableDisableCustomFields(flag, clear)
	clear = clear or false;
	self.CustomWindow.rotationName:SetDisabled(flag);
	self.CustomWindow.rotationEnabled:SetDisabled(flag);
	self.CustomWindow.rotationClass:SetDisabled(flag);
	self.CustomWindow.rotationSpec:SetDisabled(flag);
	self.CustomWindow.editor:SetDisabled(flag);
	if clear then
		self.CustomWindow.rotationName:SetText('');
		self.CustomWindow.rotationEnabled:SetValue(false);
		self.CustomWindow.rotationClass:SetValue(nil);
		self.CustomWindow.rotationSpec:SetValue(nil);
		self.CustomWindow.editor:SetText('');
	end
end

function MaxDps:LoadCustomRotations()
	for k,v in pairs(self.CustomRotations) do
		self.CustomRotations[k] = nil;
	end

	for k, rotation in pairs(self.db.global.customRotations) do
		if rotation.enabled then
			local fn = MaxDps.LoadFunction(rotation.fn);
			if not self.CustomRotations[rotation.class] then
				self.CustomRotations[rotation.class] = {}
			end

			self.CustomRotations[rotation.class][rotation.spec] = {
				name = rotation.name,
				fn = fn
			}
		end
	end
	self:Print(self.Colors.Info .. 'Custom Rotations Loaded!');
end

--[[
	Borrowed from WeakAuras

	This is free software: you can redistribute it and/or modify it under the terms of
	the GNU General Public License version 2 as published by the Free Software
	Foundation.

	For more information see WeakAuras License
]]
local blockedFunctions = {
	getfenv = true,
	setfenv = true,
	loadstring = true,
	pcall = true,
	SendMail = true,
	SetTradeMoney = true,
	AddTradeMoney = true,
	PickupTradeMoney = true,
	PickupPlayerMoney = true,
	TradeFrame = true,
	MailFrame = true,
	EnumerateFrames = true,
	RunScript = true,
	AcceptTrade = true,
	SetSendMailMoney = true,
	EditMacro = true,
	SlashCmdList = true,
	DevTools_DumpCommand = true,
	hash_SlashCmdList = true,
	CreateMacro = true,
	SetBindingMacro = true,
	GuildDisband = true,
	GuildUninvite = true,
}

local function forbidden()
	print('|cffffff00A MaxDps just tried to use a forbidden function but has been blocked from doing so.|r');
end

local env_getglobal;
local exec_env = setmetatable({}, { __index =
function(t, k)
	if k == '_G' then
		return t;
	elseif k == 'getglobal' then
		return env_getglobal;
	elseif blockedFunctions[k] then
		return forbidden;
	else
		return _G[k];
	end
end
});

local function_cache = {};
function MaxDps.LoadFunction(string)
	if function_cache[string] then
		return function_cache[string];
	else
		local loadedFunction, errorString = loadstring('return ' .. string);
		if errorString then
			print(errorString);
		else
			setfenv(loadedFunction, exec_env);
			local success, func = pcall(assert(loadedFunction));
			if success then
				function_cache[string] = func;
				return func;
			end
		end
	end
end