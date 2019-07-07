local SharedMedia = LibStub('LibSharedMedia-3.0');
---@type StdUi
local StdUi = LibStub('StdUi');

local Custom = MaxDps:NewModule('Custom', 'AceTimer-3.0');

local IndentationLib = IndentationLib;
local TableInsert = tinsert;
local GetNumClasses = GetNumClasses;
local GetClassInfo = GetClassInfo;
local GetNumSpecializationsForClassID = GetNumSpecializationsForClassID;
local GetSpecializationInfoForClassID = GetSpecializationInfoForClassID;

function Custom:GetClassIcon(classTag)
	local x1, x2, y1, y2 = unpack(CLASS_ICON_TCOORDS[classTag]);

	return string.format('|TInterface\\TARGETINGFRAME\\UI-CLASSES-CIRCLES:14:14:0:0:256:256:%u:%u:%u:%u|t',
		x1 * 256, x2 * 256, y1 * 256, y2 * 256);
end

function Custom:Enable()
	--LoadAddOn('Blizzard_DebugTools') ----- RRRRRRRRRRRREEEEEEEEEEMOOOOOOOVEEEEEEEEE
	SharedMedia:Register('font', 'Inconsolata', [[Interface\Addons\MaxDps\media\Inconsolata.otf]]);

	self.CustomRotations = {};
	self.Specs = {};
	-- private for dropdowns
	self.classList = {};
	self.specList = {};

	for i = 1, GetNumClasses() do
		local classDisplayName, classTag, classId = GetClassInfo(i);
		TableInsert(self.classList, {text = self:GetClassIcon(classTag) .. ' ' .. classDisplayName, value = classId});

		local specNum = GetNumSpecializationsForClassID(classId);
		for sI = 1, specNum do
			local _, specName, _ , specIcon = GetSpecializationInfoForClassID(classId, sI);

			specName = '|T' .. specIcon .. ':0|t ' .. specName;
			if not self.Specs[classId] then self.Specs[classId] = {}; end;
			self.Specs[classId][sI] = specName;

			if not self.specList[classId] then self.specList[classId] = {}; end
			TableInsert(self.specList[classId], {text = specName, value = sI});
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

local saveDebounceTimer;
function Custom:SaveEditorValue(value)
	value = IndentationLib.decode(value);
	if Custom.CurrentEditRotation then
		Custom.CurrentEditRotation.fn = value;
	end
end

function Custom:ShowCustomWindow()
	if self.CustomWindow then
		self.CustomWindow:Show();
		return;
	end

	self.CustomWindow = StdUi:Window(nil, 'MaxDps', 700, 550);

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
	local editor = StdUi:MultiLineBox(self.CustomWindow, 100, 200, 'adasda');
	local fontPath = SharedMedia:Fetch('font', 'Inconsolata');

	if fontPath then
		editor:SetFont(fontPath, 14);
	end
	editor.OnValueChanged = function(self, value)
		if not Custom.CurrentEditRotation then return end;
		if saveDebounceTimer then
			Custom:CancelTimer(saveDebounceTimer);
			saveDebounceTimer = nil;
		end

		saveDebounceTimer = Custom:ScheduleTimer('SaveEditorValue', 0.4, value);
	end;

	StdUi:GlueTop(btn, self.CustomWindow, 10, -30, 'LEFT');
	StdUi:GlueAcross(rotations, self.CustomWindow, 10, -80, -500, 20);
	StdUi:GlueAfter(rotationName, rotations, 20, -20);
	StdUi:GlueRight(rotationClass, rotationName, 10, 0);
	StdUi:GlueRight(rotationSpec, rotationClass, 10, 0);
	StdUi:GlueBelow(rotationEnabled, rotationName, 0, -10, 'LEFT');
	StdUi:GlueBelow(rotationDelete, rotationSpec, 0, -10, 'RIGHT');
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
				StdUi:SetTextColor(self, 'header');
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
			MaxDps.db.global.customRotations[k] = nil;
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

	MaxDps:Print(MaxDps.Colors.Info .. 'Custom Rotations Loaded!');
end

function Custom:GetCustomRotation(classId, spec)
	if self.CustomRotations[classId] and self.CustomRotations[classId][spec] then
		return self.CustomRotations[classId][spec];
	else
		return nil;
	end
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