--- @type MaxDps MaxDps
local _, MaxDps = ...;

local StdUi = LibStub('StdUi');
local SharedMedia = LibStub('LibSharedMedia-3.0');
local IndentationLib = IndentationLib;

---@class MaxDpsWindow Window
local Window = MaxDps:NewModule('Window', 'AceEvent-3.0', 'AceTimer-3.0');

---@type MaxDpsCustom Custom
local Custom = MaxDps:GetModule('Custom');

function Window:OnEnable()
	SharedMedia:Register('font', 'Inconsolata', [[Interface\Addons\MaxDps\media\Inconsolata.otf]]);

	return self;
end

function Window:ShowWindow()
	if self.window then
		self.window:Show();
		return
	end

	local window = StdUi:Window(nil, 800, 600, 'MaxDps');
	window:SetPoint('CENTER');

	StdUi:BuildWindow(window, self:GetWindowConfig());
	StdUi:EasyLayout(window, { padding = { top = 40 } });

	window:SetScript('OnShow', function(of)
		of:DoLayout();
	end);

	window:Show();
	self.window = window;
	self:ToggleCustomFields(false);
end

local function updateRotationBtn(parent, btn, rotation)
	btn.rotation = rotation;
	StdUi:SetObjSize(btn, 60, 24);
	btn:SetPoint('LEFT', 1, 0);
	btn:SetPoint('RIGHT', -2, 0);
	btn:SetText(rotation.name);

	if Custom.CurrentEditRotation == rotation then
		StdUi:ApplyBackdrop(btn, 'highlight');
	else
		StdUi:ApplyBackdrop(btn, 'button');
	end

	if not btn.hooked then
		btn:SetScript('OnClick', function(self)
			StdUi:SetTextColor(self, 'header');
			Window:EditRotation(self.rotation);
			Window:UpdateCustomRotationButtons()
		end);
		btn.hooked = true;
	end
end

local function drawCustomRotationsScroll(scrollFrame)
	local scrollChild = scrollFrame.scrollChild;

	if not scrollChild.items then
		scrollChild.items = {};
	end

	StdUi:ObjectList(
		scrollChild,
		scrollChild.items,
		'Button',
		updateRotationBtn,
		MaxDps.db.global.customRotations
	);
	scrollFrame:UpdateItemsCount(#MaxDps.db.global.customRotations);
end

function Window:UpdateCustomRotationButtons()
	local customTab = self.window.elements.container:GetTabByName('custom');
	local scrollFrame = customTab.frame.elements.customList;

	drawCustomRotationsScroll(scrollFrame);
end

function Window:SaveEditorValue(value)
	value = IndentationLib.decode(value);

	if Custom.CurrentEditRotation then
		Custom.CurrentEditRotation.fn = value;
	end
end

function Window:ConfirmRotationRemove()
	if self.confirmRotationRemoveWindow then
		self.confirmRotationRemoveWindow:Show();
		return
	end

	local btn = {
		yes = {
			text    = YES,
			onClick = function(btn)
				Custom:RemoveCustomRotation();
				Window:ToggleCustomFields(true, true);
				Window:UpdateCustomRotationButtons();
				btn.window:Hide();
			end
		},
		no  = {
			text    = NO,
			onClick = function(btn)
				btn.window:Hide();
			end
		}
	};

	self.confirmRotationRemoveWindow = StdUi:Confirm(
		'Confirm Removal',
		'Are you sure?',
		btn,
		'maxdpsRemoveCustomRotation'
	);
end

function Window:UpdateSpecList(class)
	local specs = Custom.specList[class];

	if specs then
		local customTab = self.window.elements.container:GetTabByName('custom');
		local container = customTab.frame.elements.customEdit.elements;
		container.rotationSpec:SetOptions(specs);
		container.rotationSpec:SetValue(nil);
	end
end

function Window:EditRotation(rotation)
	self.EditingRotation = true;
	Custom.CurrentEditRotation = rotation;

	local customTab = self.window.elements.container:GetTabByName('custom');
	local container = customTab.frame.elements.customEdit.elements;

	container.rotationName:SetText(rotation.name);
	container.rotationEnabled:SetChecked(rotation.enabled);
	container.rotationClass:SetValue(rotation.class);

	local specs = Custom.specList[rotation.class];

	if specs then
		container.rotationSpec:SetOptions(specs);
	else
		container.rotationSpec:SetOptions({});
	end

	container.rotationSpec:SetValue(rotation.spec);
	container.editor:SetText(IndentationLib.encode(rotation.fn));
	self:ToggleCustomFields(false);
	self.EditingRotation = false;
end

function Window:ToggleCustomFields(flag, clear)
	clear = clear or false;

	local customTab = self.window.elements.container:GetTabByName('custom');
	local container = customTab.frame.elements.customEdit.elements;

	if flag then
		container.rotationName:Disable();
		container.rotationEnabled:Disable();
		container.rotationClass:Disable();
		container.rotationSpec:Disable();
		container.editor:Disable();
	else
		container.rotationName:Enable();
		container.rotationEnabled:Enable();
		container.rotationClass:Enable();
		container.rotationSpec:Enable();
		container.editor:Enable();
	end

	if clear then
		container.rotationName:SetText('');
		container.rotationEnabled:SetChecked(false);
		container.rotationClass:SetValue(nil);
		container.rotationSpec:SetValue(nil);
		container.editor:SetText('');
	end
end

function Window:GetWindowConfig()
	local infoLayout = {
		rows = {
			{
				info = {
					type  = 'header',
					label = 'MaxDps information',
				},
			},
			{
				infoText = {
					type  = 'label',
					label = 'Rotation helper addon based on SimulationCraft APL profiles, code was tuned to be' ..
						'extremely efficient and lightweight. Supports custom rotations.',
				},
			},
			{
				support = {
					type  = 'header',
					label = 'Support',
				},
			},
			{
				discord = {
					type         = 'editBox',
					label        = 'Discord',
					initialValue = 'https://discord.gg/wCSj5SD',
					column       = 6,
					order        = 1,
				},
				forum   = {
					type         = 'editBox',
					label        = 'Patreon',
					initialValue = 'https://www.patreon.com/maxdps',
					column       = 6,
					order        = 2,
				}
			},
			{
				forum = {
					type         = 'editBox',
					label        = 'Forum',
					initialValue = 'http://maxdps.net/',
					column       = 6,
					order        = 1,
				},
				faq   = {
					type         = 'editBox',
					label        = 'FAQ',
					initialValue = 'http://maxdps.net/viewtopic.php?f=5&t=2',
					column       = 6,
					order        = 2,
				}
			},
			{
				thanks = {
					type  = 'header',
					label = 'Special Thanks',
				},
			},
			{
				infoText = {
					type  = 'label',
					label = 'Patreons:\n\n- Nub\n- Pman\n- monetta\n- Critycal\n\n' ..
						'Special thanks to everyone that helped with implementing BfA rotations, submitted bug reports' ..
						' and pull requests :)'
				},
			},
		}
	};

	local optionsLayout = {
		database = MaxDps.db.global,
		rows     = {
			{
				general = {
					type  = 'header',
					label = 'General',
				}
			},
			{
				enabled       = {
					type   = 'checkbox',
					label  = 'Enable addon',
					column = 4,
					order  = 1
				},
				onCombatEnter = {
					type   = 'checkbox',
					label  = 'Enable on combat enter',
					column = 4,
					order  = 2
				},
				disableConsumables = {
					type   = 'checkbox',
					label  = 'Disable consumables',
					column = 4,
					order  = 3
				},
			},
			{
				disableButtonGlow = {
					type     = 'checkbox',
					label    = 'Dissable blizzard button glow',
					column   = 6,
					order    = 1,
					onChange = function(_, flag)
						MaxDps.db.global.disableButtonGlow = flag;
						MaxDps:UpdateButtonGlow();
					end
				},
				forceSingle       = {
					type   = 'checkbox',
					label  = 'Force single target mode',
					column = 6,
					order  = 2
				}
			},
			{
				interval   = {
					type      = 'slider',
					label     = 'Update Interval',
					min       = 0.01,
					max       = 2,
					precision = 2,
					column    = 6,
					order     = 1,
				},
				loadModule = {
					type    = 'button',
					text    = 'Load current class module',
					column  = 6,
					order   = 2,
					onClick = function()
						MaxDps:InitRotations();
					end
				}
			},
			{
				debugHeader = {
					type  = 'header',
					label = 'Debug options',
				}
			},
			{
				debugMode    = {
					type   = 'checkbox',
					label  = 'Enable debug mode',
					column = 6,
					order  = 1
				},
				disabledInfo = {
					type   = 'checkbox',
					label  = 'Enable info messages',
					column = 6,
					order  = 2
				}
			},
			{
				overlay = {
					type  = 'header',
					label = 'Overlay options',
				}
			},
			{
				texture       = {
					type     = 'dropdown',
					label    = 'Texture',
					column   = 5,
					order    = 1,
					options  = MaxDps.Textures,
					onChange = function(_, val)
						--Window.:SetTexture(val);
						MaxDps:ApplyOverlayChanges();
					end
				},
				textureIcon   = {
					type    = 'texture',
					width   = 34,
					height  = 34,
					texture = MaxDps.db.global.texture,
					column  = 1,
					order   = 2,
				},
				customTexture = {
					type           = 'editBox',
					label          = 'Overlay options',
					column         = 6,
					order          = 3,
					initialValue   = strtrim(MaxDps.db.global.customTexture or ''),
					onValueChanged = function(_, val)
						MaxDps.db.global.customTexture = strtrim(val or '');
						MaxDps:ApplyOverlayChanges();
					end;
				}
			},
			{
				highlightColor = {
					type     = 'color',
					label    = 'Highlight color',
					column   = 6,
					order    = 1,
					onChange = function()
						MaxDps:ApplyOverlayChanges();
					end
				},
				cooldownColor  = {
					type     = 'color',
					label    = 'Cooldown color',
					column   = 6,
					order    = 2,
					onChange = function()
						MaxDps:ApplyOverlayChanges();
					end
				}
			},
			{
				sizeMult = {
					type     = 'slider',
					label    = 'Size Multiplier',
					min      = 0.5,
					max      = 2,
					column   = 6,
					order    = 1,
					onChange = function()
						MaxDps:ApplyOverlayChanges();
					end
				},
			},
			{
				overlay = {
					type  = 'header',
					label = 'Custom Glow',
				}
			},
			{
				customGlow     = {
					type     = 'checkbox',
					label    = 'Use Custom Glow',
					column   = 6,
					order    = 1,
					onChange = function()
						MaxDps:ApplyOverlayChanges();
					end
				},
				customGlowType = {
					type     = 'dropdown',
					label    = 'Custom Glow Type',
					column   = 6,
					order    = 2,
					options  = {
						{ text = 'Pixel', value = 'pixel' },
						{ text = 'Particle', value = 'particle' },
					},
					onChange = function()
						MaxDps:ApplyOverlayChanges();
					end
				}
			},
		}
	};

	local customEditRotation = {
		rows = {
			{ -- 1st row
				rotationEnabled = {
					type           = 'checkbox',
					label          = 'Enabled',
					column         = 6,
					order          = 1,
					onValueChanged = function(_, flag)
						if not Custom.CurrentEditRotation then
							return
						end

						Custom.CurrentEditRotation.enabled = flag;
					end
				},
				rotationDelete  = {
					type    = 'button',
					text    = 'Remove',
					column  = 6,
					order   = 2,
					onClick = function()
						if not Custom.CurrentEditRotation then
							return
						end

						Window:ConfirmRotationRemove();
					end
				},
			},
			{ -- 2
				rotationName  = {
					type           = 'editBox',
					label          = 'Rotation Name',
					column         = 4,
					order          = 1,
					onValueChanged = function(_, text)
						if not Custom.CurrentEditRotation then
							return
						end

						Custom.CurrentEditRotation.name = text;
						Window:UpdateCustomRotationButtons();
					end
				},
				rotationClass = {
					type           = 'dropdown',
					label          = 'Class',
					column         = 4,
					order          = 2,
					options        = Custom.classList,
					onValueChanged = function(_, value)
						if not Custom.CurrentEditRotation or Window.EditingRotation then
							return
						end

						Custom.CurrentEditRotation.class = value;
						Window:UpdateSpecList(value);
					end
				},
				rotationSpec  = {
					type           = 'dropdown',
					label          = 'Specialization',
					column         = 4,
					order          = 3,
					options        = Custom.specList,
					onValueChanged = function(_, value)
						if not Custom.CurrentEditRotation or Window.EditingRotation then
							return
						end

						Custom.CurrentEditRotation.spec = value;
					end
				}
			},
			{ -- 3
				editor = {
					type           = 'multiLineBox',
					label          = 'Rotation Code',
					fullHeight     = true,
					init           = function(editor)
						local fontPath = SharedMedia:Fetch('font', 'Inconsolata');

						if fontPath then
							editor:SetFont(fontPath, 14);
						end

						IndentationLib.enable(editor.editBox, nil, 4);
					end,
					onValueChanged = function(editor, text)
						if not Custom.CurrentEditRotation then
							return
						end

						if editor.saveDebounceTimer then
							Window:CancelTimer(editor.saveDebounceTimer);
							editor.saveDebounceTimer = nil;
						end

						editor.saveDebounceTimer = Window:ScheduleTimer('SaveEditorValue', 0.5, text);
					end
				},
			},
		}
	}

	local customLayout = {
		rows = {
			{
				customHeader = {
					type   = 'header',
					label  = 'Custom Rotations',
					column = 12,
					order  = 1,
				},
			},
			{
				customAdd = {
					type    = 'button',
					text    = 'Add New',
					column  = 3,
					order   = 1,
					onClick = function()
						local newRotation = Custom:CreateCustomRotation();
						Window:EditRotation(newRotation);
						Window:UpdateCustomRotationButtons();
					end
				},
			},
			{
				customList = {
					type        = 'fauxScroll',
					fullHeight  = true,
					column      = 3,
					order       = 1,
					scrollChild = drawCustomRotationsScroll
				},
				customEdit = {
					type       = 'panel',
					fullHeight = true,
					column     = 9,
					order      = 2,
					children   = customEditRotation
				},
			},
		}
	};

	local config = {
		layoutConfig = { padding = { top = 30 } },
		rows         = {
			[1] = {
				container = {
					type     = 'tab',
					fullSize = true,
					tabs     = {
						{
							name   = 'info',
							title  = 'Information',
							layout = infoLayout
						},
						{
							name   = 'options',
							title  = 'Options',
							layout = optionsLayout
						},
						{
							name   = 'custom',
							title  = 'Custom Rotations',
							layout = customLayout,
							onHide = function()
								Custom:LoadCustomRotations();
							end
						}
					},
				}
			},
		},
	};

	return config;
end