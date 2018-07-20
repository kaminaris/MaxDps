local SharedMedia = LibStub('LibSharedMedia-3.0');
---@type StdUi
local StdUi = LibStub('StdUi');

local Custom = MaxDps:NewModule('Custom');

function Custom:Enable()
	LoadAddOn('Blizzard_DebugTools') ----- RRRRRRRRRRRREEEEEEEEEEMOOOOOOOVEEEEEEEEE

	self.CustomRotations = {};
	self.Specs = {};
	-- private for dropdowns
	self.classList = {};
	self.specList = {};

	local x = GetNumClasses();
	for i = 1, x do
		local classDisplayName, classTag, classId = GetClassInfo(i);
		tinsert(self.classList, {text = classDisplayName, value = classId});

		local specNum = GetNumSpecializationsForClassID(classId);
		for sI = 1, specNum do
			local specId, specName = GetSpecializationInfoForClassID(classId, sI);

			if not self.Specs[classId] then self.Specs[classId] = {}; end;
			self.Specs[classId][sI] = specName;

			if not self.specList[classId] then self.specList[classId] = {}; end
			tinsert(self.specList[classId], {text = specName, value = sI});
		end
	end

	return self;
end

StaticPopupDialogs['REMOVE_MAXDPS_ROTATION'] = {
	text = 'Are you sure?',
	button1 = 'Yes',
	button2 = 'No',
	OnAccept = function()
		Custom:RemoveCustomRotation();
	end,
	OnCancel = function (_,reason)
	end,
	whileDead = true,
	hideOnEscape = true,
}

function Custom:ShowCustomWindow()
	if self.CustomWindow then
		self.CustomWindow:Show();
		return;
	end
print('sss');
	self.CustomWindow = StdUi:Window(nil, 'MaxDps Custom Rotations', 700, 550);
	self.CustomWindow:SetPoint('CENTER');
	self.CustomWindow:SetScript('OnHide', function()
		Custom:LoadCustomRotations();
	end)

	local btn = StdUi:Button(self.CustomWindow, 100, 24, 'Add Rotation');
	btn:SetScript('OnClick', function()
		Custom:AddCustomRotation();
	end);

	local rotations = StdUi:FauxScrollFrame(self.CustomWindow, 200, 500, 20, 24);

	--		Rotation Name
	local rotationName = StdUi:EditBox(self.CustomWindow, 140, 24);
	StdUi:AddLabel(self.CustomWindow, rotationName, 'Rotation Name', 'TOP');
	rotationName.OnValueChanged = function(self, text)
		if not Custom.CurrentEditRotation then return end;
		Custom.CurrentEditRotation.name = text;
		Custom:UpdateCustomRotationButtons();
	end;

	--		Rotation Class
	local rotationClass = StdUi:Dropdown(self.CustomWindow, 140, 24, self.classList);
	StdUi:AddLabel(self.CustomWindow, rotationClass, 'Class', 'TOP');
	rotationClass.OnValueChanged = function(self, value)
		if not Custom.CurrentEditRotation or Custom.EditingRotation then return end;

		Custom.CurrentEditRotation.class = value;

		local specs = Custom.specList[value];
		if specs then
			--Custom.CustomWindow.rotationSpec:SetValue(Custom.CurrentEditRotation.spec);
			Custom.CustomWindow.rotationSpec:SetOptions(Custom.specList[value]);
		end
	end;

	--		Rotation Spec
	local rotationSpec = StdUi:Dropdown(self.CustomWindow, 140, 24, self.classList);
	StdUi:AddLabel(self.CustomWindow, rotationSpec, 'Specialization', 'TOP');
	rotationSpec.OnValueChanged = function(self, value)
		if not Custom.CurrentEditRotation or Custom.EditingRotation then return end;
		print(Custom.CurrentEditRotation.spec);
		print(value);
		Custom.CurrentEditRotation.spec = value;
	end;

	--		Rotation Enabled
	local rotationEnabled = StdUi:Checkbox(self.CustomWindow, 'Enabled', 140, 24);
	rotationEnabled.OnValueChanged = function(self, flag)
		if not Custom.CurrentEditRotation then return end;
		Custom.CurrentEditRotation.enabled = flag;
	end;

	--		Rotation Delete
	local rotationDelete = StdUi:Button(self.CustomWindow, 100, 24, 'Remove');
	rotationDelete:SetScript('OnClick', function()
		if not Custom.CurrentEditRotation then return end;
		StaticPopup_Show('REMOVE_MAXDPS_ROTATION');
	end);

	--		Editor
	local editor = StdUi:MultiLineBox(self.CustomWindow, 400, 200, 'adasda');
	local fontPath = SharedMedia:Fetch('font', 'Fira Mono Medium');
	if fontPath then
		editor:SetFont(fontPath, 12);
	end
	editor.OnValueChanged = function(self, event, value)
		if not Custom.CurrentEditRotation then return end;

		value = IndentationLib.decode(value);
		if Custom.CurrentEditRotation then
			Custom.CurrentEditRotation.fn = value;
		end
	end;

	StdUi:GlueTop(btn, self.CustomWindow, 10, -30, 'LEFT');
	StdUi:GlueAcross(rotations, self.CustomWindow, 10, -80, -500, 20);
	StdUi:GlueAfter(rotationName, rotations, 20, -20);
	StdUi:GlueRight(rotationClass, rotationName, 10, 0);
	StdUi:GlueRight(rotationSpec, rotationClass, 10, 0);
	StdUi:GlueBelow(rotationEnabled, rotationName, 0, -10, 'LEFT');
	StdUi:GlueRight(rotationDelete, rotationEnabled, 100, 0);
	StdUi:GlueAcross(editor.panel, self.CustomWindow, 220, -200, -10, 20);

	self.CustomWindow.rotations = rotations;
	self.CustomWindow.rotationName = rotationName;
	self.CustomWindow.rotationClass = rotationClass;
	self.CustomWindow.rotationSpec = rotationSpec;
	self.CustomWindow.rotationEnabled = rotationEnabled;
	self.CustomWindow.editor = editor;

	IndentationLib.enable(editor, nil, 4);

	self:UpdateCustomRotationButtons();
	self:EnableDisableCustomFields(true, true);

	MaxDps:DisableRotation();
	self.CustomWindow:Show();
end

function Custom:UpdateCustomRotationButtons()
	local scrollChild = self.CustomWindow.rotations.scrollChild;

	local updateBtn = function(parent, btn, rotation)
		btn.rotation = rotation;
		StdUi:SetObjSize(btn, 60, 24);
		btn:SetPoint('LEFT', 1, 0);
		btn:SetPoint('RIGHT', -2, 0);
		btn:SetText(rotation.name);

		if not btn.hooked then
			btn:SetScript('OnClick', function(self)
				--self:SetTextColor(0, 1, 0);
				Custom:EditRotation(self.rotation);
			end);
			btn.hooked = true;
		end
	end

	if not scrollChild.items then
		scrollChild.items = {};
	end

	StdUi:ObjectList(scrollChild, scrollChild.items, 'Button', updateBtn, MaxDps.db.global.customRotations);
	self.CustomWindow.rotations:UpdateItemsCount(#MaxDps.db.global.customRotations);
end

function Custom:AddCustomRotation()
	local customRotation = {
		name    = 'New Rotation',
		enabled = false,
		class   = nil,
		spec    = nil,
		fn      = "function(_, timeShift, currentSpell, gcd, talents)\n    \nend",
	};

	tinsert(MaxDps.db.global.customRotations, customRotation);
	self:UpdateCustomRotationButtons();
	Custom:EditRotation(customRotation);
end

function Custom:RemoveCustomRotation()
	for k, rotation in pairs(MaxDps.db.global.customRotations) do
		if rotation == Custom.CurrentEditRotation then
			self.db.global.customRotations[k] = nil;
		end
	end

	self.CurrentEditRotation = nil;
	self:UpdateCustomRotationButtons();
	self:EnableDisableCustomFields(true, true);
end

function Custom:EditRotation(rotation)
	Custom.EditingRotation = true;
	self.CurrentEditRotation = rotation;

	self.CustomWindow.rotationName:SetText(rotation.name);
	self.CustomWindow.rotationEnabled:SetChecked(rotation.enabled);
	self.CustomWindow.rotationClass:SetValue(rotation.class);

	local specs = Custom.specList[rotation.class];

	if specs then
		self.CustomWindow.rotationSpec:SetOptions(specs);
	else
		self.CustomWindow.rotationSpec:SetOptions({});
	end

	self.CustomWindow.rotationSpec:SetValue(rotation.spec);
	self.CustomWindow.editor:SetText(IndentationLib.encode(rotation.fn));
	self:EnableDisableCustomFields(false);
	Custom.EditingRotation = false;
end

function Custom:EnableDisableCustomFields(flag, clear)
	clear = clear or false;
	if flag then
		self.CustomWindow.rotationName:Disable();
		self.CustomWindow.rotationEnabled:Disable();
		self.CustomWindow.rotationClass:Disable();
		self.CustomWindow.rotationSpec:Disable();
		self.CustomWindow.editor:Disable();
	else
		self.CustomWindow.rotationName:Enable();
		self.CustomWindow.rotationEnabled:Enable();
		self.CustomWindow.rotationClass:Enable();
		self.CustomWindow.rotationSpec:Enable();
		self.CustomWindow.editor:Enable();
	end

	if clear then
		self.CustomWindow.rotationName:SetText('');
		self.CustomWindow.rotationEnabled:SetChecked(false);
		self.CustomWindow.rotationClass:SetValue(nil);
		self.CustomWindow.rotationSpec:SetValue(nil);
		self.CustomWindow.editor:SetText('');
	end
end

function Custom:LoadCustomRotations()
	for k, v in pairs(self.CustomRotations) do
		self.CustomRotations[k] = nil;
	end

	for k, rotation in pairs(MaxDps.db.global.customRotations) do
		if rotation.enabled and rotation.class ~= nil and rotation.spec ~= nil then
			local fn = Custom.LoadFunction(rotation.fn);
			if not self.CustomRotations[rotation.class] then
				self.CustomRotations[rotation.class] = {}
			end

			self.CustomRotations[rotation.class][rotation.spec] = {
				name = rotation.name,
				fn   = fn
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
	getfenv              = true,
	setfenv              = true,
	loadstring           = true,
	pcall                = true,
	SendMail             = true,
	SetTradeMoney        = true,
	AddTradeMoney        = true,
	PickupTradeMoney     = true,
	PickupPlayerMoney    = true,
	TradeFrame           = true,
	MailFrame            = true,
	EnumerateFrames      = true,
	RunScript            = true,
	AcceptTrade          = true,
	SetSendMailMoney     = true,
	EditMacro            = true,
	SlashCmdList         = true,
	DevTools_DumpCommand = true,
	hash_SlashCmdList    = true,
	CreateMacro          = true,
	SetBindingMacro      = true,
	GuildDisband         = true,
	GuildUninvite        = true,
}

local function forbidden()
	print('|cffffff00A MaxDps just tried to use a forbidden function but has been blocked from doing so.|r');
end

local env_getglobal;
local exec_env = setmetatable({}, { __index = function(t, k)
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
function Custom.LoadFunction(string)
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