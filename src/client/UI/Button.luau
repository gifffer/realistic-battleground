--!strict
-- Button: the one look for everything you can click or tap (menus, HUD).
--
--   local Button = require(script.Parent.Parent.UI.Button)
--   local equip = Button.new({
--       text = "EQUIP",
--       variant = "primary",        -- primary | secondary | tab | danger
--       size = "medium",            -- small | medium | large (taller on touch)
--       icon = "check",             -- optional: menu | close | check | lock | coin
--       keyHint = "M",              -- optional: a key cap (hidden on touch)
--       anchorPoint = Vector2.new(1, 0),
--       position = UDim2.new(1, 0, 0, 0),
--       parent = frame,
--       onActivated = function() ... end,
--   })
--   equip.setEnabled(false)  -- flat and grey, no hover, presses ignored
--   equip.setSelected(true)  -- tabs: accent outline + a bar on the left
--   equip.setText("CONFIRM")
--
-- States: idle -> hover (brighter, slightly bigger) -> pressed (darker,
-- slightly smaller). Gamepad selection counts as hover.
-- Button.badge() draws the non-clickable twin ("✓ EQUIPPED"): same shape,
-- accent outline, no fill, so it never reads as something to press.
--
-- The TextButton is the hit area and never changes size (lists don't
-- move); the visible plate inside it grows and shrinks around its centre.

local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local C = Theme.Colors

export type Variant = "primary" | "secondary" | "tab" | "danger"
export type Size = "small" | "medium" | "large"
export type IconName = "menu" | "close" | "check" | "lock" | "coin"

export type Options = {
	text: string,
	variant: Variant?,
	size: Size?,
	icon: IconName?,
	keyHint: string?,
	index: string?, -- small number before the label ("01")
	subtext: string?, -- a second, smaller line (tabs / cards)
	align: ("center" | "left")?,
	width: number?, -- fixed width in pixels (default: fits the text)
	fillWidth: boolean?, -- as wide as its parent (lists, cards)
	height: number?, -- fixed height in pixels (default: from `size`)
	minWidth: number?,
	textSize: number?,
	name: string?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	visible: boolean?,
	parent: Instance?,
	onActivated: (() -> ())?,
}

export type Button = {
	instance: TextButton,
	label: TextLabel,
	sub: TextLabel?,
	index: TextLabel?,
	setText: (text: string) -> (),
	setSubtext: (text: string, color: Color3?) -> (),
	setEnabled: (enabled: boolean) -> (),
	setSelected: (selected: boolean) -> (),
	setVariant: (variant: Variant) -> (),
	isEnabled: () -> boolean,
	flash: () -> (), -- a short red outline (a refused request)
	press: () -> (), -- plays the press animation (a keyboard shortcut was used)
	pulse: (on: boolean) -> (), -- an accent ring that keeps growing out
}

export type BadgeOptions = {
	text: string,
	icon: IconName?,
	size: Size?,
	name: string?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	parent: Instance?,
}

local Button = {}

-- Height of each size, on a PC and on a touch screen (a finger needs more).
local HEIGHTS: { [Size]: { pc: number, touch: number } } = {
	small = { pc = 28, touch = 40 },
	medium = { pc = 34, touch = 44 },
	large = { pc = 44, touch = 52 },
}
local TEXT_SIZES: { [Size]: number } = { small = 11, medium = 12, large = 14 }
local PAD: { [Size]: number } = { small = 10, medium = 14, large = 18 }
local ICON = 14 -- icon box (pixels)
local GAP = 7 -- between icon, label and key cap

local HOVER_SCALE = 1.04
local PRESS_SCALE = 0.95
local TAB_HOVER_SCALE = 1.015
local TAB_PRESS_SCALE = 0.98

type Look = {
	bg: Color3,
	bgT: number,
	stroke: Color3,
	strokeT: number,
	text: Color3,
}
type Mode = "idle" | "hover" | "pressed" | "disabled" | "selected"

local HOVER_DARK = Color3.fromHex("#2B2926")

local LOOKS: { [Variant]: { [Mode]: Look } } = {
	primary = {
		idle = { bg = C.Accent, bgT = 0, stroke = C.AccentHi, strokeT = 0.2, text = C.Scrim },
		hover = { bg = C.AccentHi, bgT = 0, stroke = C.InkHi, strokeT = 0.3, text = C.Scrim },
		pressed = { bg = C.AccentDeep, bgT = 0, stroke = C.AccentDeep, strokeT = 0, text = C.Scrim },
		selected = { bg = C.AccentHi, bgT = 0, stroke = C.InkHi, strokeT = 0.3, text = C.Scrim },
		disabled = { bg = C.Ink3, bgT = 0.6, stroke = C.Ink3, strokeT = 0.6, text = C.Ink2 },
	},
	secondary = {
		idle = { bg = C.Scrim, bgT = 0.2, stroke = C.Ink, strokeT = 0.5, text = C.Ink },
		hover = { bg = HOVER_DARK, bgT = 0.05, stroke = C.Ink, strokeT = 0.1, text = C.InkHi },
		pressed = { bg = C.Scrim, bgT = 0, stroke = C.Ink, strokeT = 0.35, text = C.Ink2 },
		selected = { bg = HOVER_DARK, bgT = 0.05, stroke = C.Accent, strokeT = 0, text = C.InkHi },
		disabled = { bg = C.Scrim, bgT = 0.5, stroke = C.Ink3, strokeT = 0.6, text = C.Ink3 },
	},
	danger = {
		idle = { bg = C.Blood, bgT = 0, stroke = C.BloodHi, strokeT = 0.2, text = C.Ink },
		hover = { bg = C.BloodHi, bgT = 0, stroke = C.Ink, strokeT = 0.4, text = C.InkHi },
		pressed = { bg = C.BloodDeep, bgT = 0, stroke = C.BloodDeep, strokeT = 0, text = C.Ink2 },
		selected = { bg = C.BloodHi, bgT = 0, stroke = C.Ink, strokeT = 0.4, text = C.InkHi },
		disabled = { bg = C.Scrim, bgT = 0.5, stroke = C.Ink3, strokeT = 0.6, text = C.Ink3 },
	},
	tab = {
		idle = { bg = C.Ink, bgT = 0.94, stroke = C.Ink, strokeT = 0.84, text = C.Ink2 },
		hover = { bg = C.Ink, bgT = 0.87, stroke = C.Ink, strokeT = 0.55, text = C.InkHi },
		pressed = { bg = C.Ink, bgT = 0.82, stroke = C.Ink, strokeT = 0.5, text = C.Ink },
		selected = { bg = C.Ink, bgT = 0.86, stroke = C.Accent, strokeT = 0.05, text = C.InkHi },
		disabled = { bg = C.Ink, bgT = 0.97, stroke = C.Ink, strokeT = 0.92, text = C.Ink3 },
	},
}

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

-- Height of a button of `size` on this device.
function Button.height(size: Size?): number
	local key: Size = size or "medium"
	local heights = HEIGHTS[key]
	return if Theme.isTouch() then heights.touch else heights.pc
end

local function scaledTextSize(size: number): number
	return math.floor(size * Theme.TEXT_SCALE + 0.5)
end

-- Width of `text` once drawn (the house font is a bit wider than the
-- measuring font, hence the margin).
local function measure(text: string, textSize: number): number
	local bounds = TextService:GetTextSize(
		text,
		scaledTextSize(textSize),
		Enum.Font.RobotoCondensed,
		Vector2.new(4096, 4096)
	)
	return math.ceil(bounds.X * 1.12) + 2
end

-- Small icons drawn with frames (no image assets to upload). Returns the
-- holder; every part is recoloured by `paintIcon`.
local function bar(parent: Instance, x: number, y: number, w: number, h: number, rotation: number)
	Theme.make("Frame", {
		Name = "Part",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Rotation = rotation,
		BackgroundColor3 = C.Ink,
		Parent = parent,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, 1) }),
	})
end

local function drawIcon(name: IconName, parent: Instance, order: number): Frame
	local holder = Theme.make("Frame", {
		Name = "Icon",
		LayoutOrder = order,
		Size = UDim2.fromOffset(ICON, ICON),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	if name == "menu" then
		bar(holder, 7, 3, 14, 2, 0)
		bar(holder, 7, 7, 14, 2, 0)
		bar(holder, 7, 11, 14, 2, 0)
	elseif name == "close" then
		bar(holder, 7, 7, 15, 2, 45)
		bar(holder, 7, 7, 15, 2, -45)
	elseif name == "check" then
		bar(holder, 4.5, 8.5, 6, 2, 45)
		bar(holder, 9, 6.5, 11, 2, -52)
	elseif name == "lock" then
		-- Shackle: a rounded outline whose bottom hides behind the body.
		Theme.make("Frame", {
			Name = "Shackle",
			Position = UDim2.fromOffset(3.5, 0.5),
			Size = UDim2.fromOffset(7, 9),
			BackgroundTransparency = 1,
			Parent = holder,
		}, {
			Theme.make("UICorner", { CornerRadius = UDim.new(0, 3) }),
			Theme.make("UIStroke", {
				Thickness = 1.6,
				Color = C.Ink,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
		Theme.make("Frame", {
			Name = "Part",
			Position = UDim2.fromOffset(1.5, 6),
			Size = UDim2.fromOffset(11, 8),
			BackgroundColor3 = C.Ink,
			Parent = holder,
		}, {
			Theme.make("UICorner", { CornerRadius = UDim.new(0, 2) }),
		})
	elseif name == "coin" then
		Theme.make("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(7, 7),
			Size = UDim2.fromOffset(11, 11),
			BackgroundTransparency = 1,
			Parent = holder,
		}, {
			Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Theme.make("UIStroke", {
				Thickness = 1.6,
				Color = C.Ink,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
		bar(holder, 7, 7, 2, 5, 0)
	end
	return holder
end

local function paintIcon(icon: Frame?, color: Color3, seconds: number)
	if icon == nil then
		return
	end
	for _, part in icon:GetDescendants() do
		if part:IsA("Frame") and part.Name == "Part" then
			if seconds > 0 then
				Theme.tween(part, seconds, { BackgroundColor3 = color })
			else
				part.BackgroundColor3 = color
			end
		elseif part:IsA("UIStroke") then
			if seconds > 0 then
				Theme.tween(part, seconds, { Color = color })
			else
				part.Color = color
			end
		end
	end
end

-- A key cap inside a button ("M"), in the button's text colour.
local function keyCap(text: string, parent: Instance, order: number): (Frame, TextLabel, UIStroke)
	local cap = Theme.make("Frame", {
		Name = "KeyCap",
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, 3) }),
		Theme.make("UIPadding", {
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
		}),
	}) :: Frame
	local stroke = Theme.make("UIStroke", {
		Thickness = 1,
		Color = C.Ink,
		Transparency = 0.45,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = cap,
	}) :: UIStroke
	local label = Theme.text({
		Name = "Key",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(8, 18),
		FontFace = Theme.Fonts.NumberMedium,
		TextSize = 10,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
		Parent = cap,
	}) :: TextLabel
	return cap, label, stroke
end

------------------------------------------------------------------------------
-- Button
------------------------------------------------------------------------------

function Button.new(options: Options): Button
	local variant: Variant = options.variant or "secondary"
	local size: Size = options.size or "medium"
	local isTab = variant == "tab"
	local align = options.align or (if isTab then "left" else "center")
	local textSize = options.textSize or TEXT_SIZES[size]
	local height = options.height or Button.height(size)
	local pad = PAD[size]
	local touch = Theme.isTouch()
	local showKey = options.keyHint ~= nil and not touch
	local text = options.text

	local instance = Theme.make("TextButton", {
		Name = options.name or "Button",
		AnchorPoint = options.anchorPoint or Vector2.zero,
		Position = options.position or UDim2.new(),
		Size = if options.fillWidth
			then UDim2.new(1, 0, 0, height)
			else UDim2.fromOffset(options.width or 0, height),
		LayoutOrder = options.layoutOrder or 0,
		ZIndex = options.zIndex or 1,
		Visible = if options.visible == nil then true else options.visible,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = true,
		Text = "",
	}) :: TextButton

	-- Glow ring for pulse() (behind the plate).
	local glow = Theme.make("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = instance,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, Theme.RADIUS + 2) }),
		Theme.make("UIStroke", {
			Thickness = 2,
			Color = C.Accent,
			Transparency = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	}) :: Frame
	local glowScale = Theme.make("UIScale", { Parent = glow }) :: UIScale

	local plate = Theme.make("Frame", {
		Name = "Plate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Scrim,
		Parent = instance,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, Theme.RADIUS) }),
	}) :: Frame
	local stroke = Theme.make("UIStroke", {
		Thickness = 1.5,
		Color = C.Ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = plate,
	}) :: UIStroke
	local scale = Theme.make("UIScale", { Parent = plate }) :: UIScale

	-- Tabs: an accent bar on the left when selected.
	local selectBar: Frame? = nil
	if isTab then
		selectBar = Theme.make("Frame", {
			Name = "SelectBar",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.new(0, 3, 1, -14),
			BackgroundColor3 = C.Accent,
			BackgroundTransparency = 1,
			Parent = plate,
		}, {
			Theme.make("UICorner", { CornerRadius = UDim.new(0, 2) }),
		})
	end

	local content = Theme.make("Frame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = plate,
	}, {
		Theme.make("UIPadding", {
			PaddingLeft = UDim.new(0, if isTab then pad + 2 else pad),
			PaddingRight = UDim.new(0, pad),
		}),
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = if align == "left"
				then Enum.HorizontalAlignment.Left
				else Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame

	local icon: Frame? = if options.icon then drawIcon(options.icon, content, 1) else nil

	local indexLabel: TextLabel? = nil
	if options.index then
		indexLabel = Theme.text({
			Name = "Index",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(18, height),
			FontFace = Theme.Fonts.Number,
			TextSize = 10,
			TextColor3 = C.Ink3,
			TextStrokeTransparency = 1,
			Text = options.index,
			Parent = content,
		}) :: TextLabel
	end

	-- The label (and, for cards, a second line under it).
	local label: TextLabel
	local sub: TextLabel? = nil
	if options.subtext then
		local stack = Theme.make("Frame", {
			Name = "Stack",
			LayoutOrder = 3,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
			Parent = content,
		}, {
			Theme.make("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		})
		label = Theme.text({
			Name = "Label",
			Position = UDim2.new(0, 0, 0.5, -15),
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = textSize + 1,
			TextStrokeTransparency = 1,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = Theme.track(text, "four"),
			Parent = stack,
		}) :: TextLabel
		sub = Theme.text({
			Name = "Sub",
			Position = UDim2.new(0, 0, 0.5, 3),
			Size = UDim2.new(1, 0, 0, 12),
			TextSize = 9,
			TextColor3 = C.Ink3,
			TextStrokeTransparency = 1,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = Theme.track(options.subtext :: string, "three"),
			Parent = stack,
		}) :: TextLabel
	else
		label = Theme.text({
			Name = "Label",
			LayoutOrder = 3,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, height),
			FontFace = if isTab then Theme.Fonts.Label else Theme.Fonts.LabelBold,
			TextSize = textSize,
			TextStrokeTransparency = 1,
			TextXAlignment = if align == "left"
				then Enum.TextXAlignment.Left
				else Enum.TextXAlignment.Center,
			Text = Theme.track(text, "four"),
			Parent = content,
		}) :: TextLabel
	end

	local key: TextLabel? = nil
	local keyStroke: UIStroke? = nil
	if showKey then
		local _, keyLabel, capStroke = keyCap(options.keyHint :: string, content, 4)
		key = keyLabel
		keyStroke = capStroke
	end

	-- Width: fixed, or what the content needs.
	local function fitWidth()
		if options.width or options.fillWidth then
			return
		end
		local width = 2 * pad + measure(Theme.track(text, "four"), textSize)
		if icon then
			width += ICON + GAP
		end
		if indexLabel then
			width += 18 + GAP
		end
		if showKey then
			width += GAP + 10 + measure(options.keyHint :: string, 10)
		end
		instance.Size = UDim2.fromOffset(math.max(width, options.minWidth or 0), height)
	end
	fitWidth()

	local enabled = true
	local selected = false
	local hovered = false
	local pressed = false

	local function mode(): Mode
		if not enabled then
			return "disabled"
		elseif pressed then
			return "pressed"
		elseif selected then
			return "selected"
		elseif hovered then
			return "hover"
		end
		return "idle"
	end

	local function paint(seconds: number)
		local current: Mode = mode()
		local looks = LOOKS[variant]
		local wanted = looks[current]
		-- A selected tab under the mouse keeps its look, a touch brighter.
		if current == "selected" and hovered then
			wanted = table.clone(wanted)
			wanted.bgT = math.max(wanted.bgT - 0.04, 0)
		end
		local targetScale = 1
		if current == "pressed" then
			targetScale = if isTab then TAB_PRESS_SCALE else PRESS_SCALE
		elseif hovered and enabled then
			targetScale = if isTab then TAB_HOVER_SCALE else HOVER_SCALE
		end
		if seconds <= 0 then
			plate.BackgroundColor3 = wanted.bg
			plate.BackgroundTransparency = wanted.bgT
			stroke.Color = wanted.stroke
			stroke.Transparency = wanted.strokeT
			label.TextColor3 = wanted.text
			scale.Scale = targetScale
		else
			Theme.tween(plate, seconds, {
				BackgroundColor3 = wanted.bg,
				BackgroundTransparency = wanted.bgT,
			})
			Theme.tween(stroke, seconds, { Color = wanted.stroke, Transparency = wanted.strokeT })
			Theme.tween(label, seconds, { TextColor3 = wanted.text })
			Theme.tween(scale, seconds, { Scale = targetScale }, Enum.EasingStyle.Back)
		end
		paintIcon(icon, wanted.text, seconds)
		if key then
			key.TextColor3 = wanted.text
		end
		if keyStroke then
			keyStroke.Color = wanted.text
		end
		local barFrame = selectBar
		if barFrame then
			barFrame.BackgroundTransparency = if selected then 0 else 1
		end
	end
	paint(0)

	local function isPointer(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end

	instance.MouseEnter:Connect(function()
		-- (A finger fires MouseEnter but not always MouseLeave: no hover on touch.)
		if Theme.isTouch() then
			return
		end
		hovered = true
		paint(Theme.FAST)
	end)
	instance.MouseLeave:Connect(function()
		hovered = false
		pressed = false
		paint(Theme.FAST)
	end)
	instance.SelectionGained:Connect(function()
		hovered = true
		paint(Theme.FAST)
	end)
	instance.SelectionLost:Connect(function()
		hovered = false
		paint(Theme.FAST)
	end)
	instance.InputBegan:Connect(function(input)
		if enabled and isPointer(input) then
			pressed = true
			paint(0.06)
		end
	end)
	instance.InputEnded:Connect(function(input)
		if pressed and isPointer(input) then
			pressed = false
			paint(Theme.FAST)
		end
	end)
	instance.Activated:Connect(function()
		if not enabled then
			return
		end
		pressed = false
		paint(Theme.FAST)
		local callback = options.onActivated
		if callback then
			callback()
		end
	end)

	local pulseTweens: { Tween } = {}
	local function stopPulse()
		for _, tween in pulseTweens do
			tween:Cancel()
		end
		table.clear(pulseTweens)
		glow.Visible = false
	end
	instance.Destroying:Connect(stopPulse)

	local api: Button = {
		instance = instance,
		label = label,
		sub = sub,
		index = indexLabel,
		setText = function(newText: string)
			if newText == text then
				return
			end
			text = newText
			label.Text = Theme.track(newText, "four")
			fitWidth()
		end,
		setSubtext = function(newText: string, color: Color3?)
			local subLabel = sub
			if subLabel then
				subLabel.Text = Theme.track(newText, "three")
				if color then
					subLabel.TextColor3 = color
				end
			end
		end,
		setEnabled = function(value: boolean)
			if value == enabled then
				return
			end
			enabled = value
			instance.Active = value
			instance.Selectable = value
			if not value then
				pressed = false
			end
			paint(Theme.FAST)
		end,
		setSelected = function(value: boolean)
			if value == selected then
				return
			end
			selected = value
			paint(Theme.FAST)
		end,
		setVariant = function(value: Variant)
			if value == variant then
				return
			end
			variant = value
			paint(Theme.FAST)
		end,
		isEnabled = function(): boolean
			return enabled
		end,
		flash = function()
			stroke.Color = C.BloodHi
			stroke.Transparency = 0
			task.delay(0.35, function()
				if instance.Parent ~= nil then
					paint(0.3)
				end
			end)
		end,
		press = function()
			pressed = true
			paint(0.06)
			task.delay(0.12, function()
				pressed = false
				if instance.Parent ~= nil then
					paint(Theme.FAST)
				end
			end)
		end,
		pulse = function(on: boolean)
			stopPulse()
			if not on then
				return
			end
			glow.Visible = true
			local ring = glow:FindFirstChildOfClass("UIStroke") :: UIStroke
			ring.Transparency = 0.1
			glowScale.Scale = 1
			local info = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1)
			local grow = TweenService:Create(glowScale, info, { Scale = 1.18 })
			local fade = TweenService:Create(ring, info, { Transparency = 1 })
			grow:Play()
			fade:Play()
			pulseTweens = { grow, fade }
		end,
	}
	instance.Parent = options.parent
	return api
end

------------------------------------------------------------------------------
-- Badge (not clickable)
------------------------------------------------------------------------------

-- "✓ EQUIPPED": a button's shape with an accent outline and no fill, so it
-- reads as a state, not an action. Returns the frame.
function Button.badge(options: BadgeOptions): Frame
	local size: Size = options.size or "medium"
	local height = Button.height(size)
	local pad = PAD[size]
	local textSize = TEXT_SIZES[size]
	local width = 2 * pad + measure(Theme.track(options.text, "four"), textSize)
	if options.icon then
		width += ICON + GAP
	end
	local badge = Theme.make("Frame", {
		Name = options.name or "Badge",
		AnchorPoint = options.anchorPoint or Vector2.zero,
		Position = options.position or UDim2.new(),
		Size = UDim2.fromOffset(width, height),
		LayoutOrder = options.layoutOrder or 0,
		BackgroundColor3 = C.Accent,
		BackgroundTransparency = 0.88,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, Theme.RADIUS) }),
		Theme.make("UIStroke", {
			Thickness = 1.5,
			Color = C.Accent,
			Transparency = 0.1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	}) :: Frame
	local content = Theme.make("Frame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = badge,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	if options.icon then
		paintIcon(drawIcon(options.icon, content, 1), C.Accent, 0)
	end
	Theme.text({
		Name = "Label",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = textSize,
		TextColor3 = C.Accent,
		TextStrokeTransparency = 1,
		Text = Theme.track(options.text, "four"),
		Parent = content,
	})
	badge.Parent = options.parent
	return badge
end

return table.freeze(Button)
