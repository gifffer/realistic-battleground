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
--   equip.setEnabled(false)  -- grey, no hover, presses ignored
--   equip.setSelected(true)  -- white text + a thin white bar (tabs)
--   equip.setLocked(true)    -- dimmed with a lock on the right (still clickable)
--   equip.setText("CONFIRM")
--   equip.reset()            -- no hover / press (call when its parent hides it)
--
-- Roblox's dark theme (docs/UI_ROBLOX_STYLE.md), rounded 8 px corners:
--   tab        a word in a list. Dim grey; under the mouse it turns white
--              with a faint fill; picked = white + a thin white bar on its
--              left (or under it when centred).
--   primary    the main action (EQUIP, BUY): a white button with dark text,
--              like Roblox's own; a little greyer under the mouse.
--   secondary  dark see-through, a faint outline; lighter under the mouse.
--   danger     like secondary, in blood red.
-- Pressed = a small quick shrink. Gamepad selection counts as hover.
-- Button.badge() draws the non-clickable twin ("✓ EQUIPPED"): just a check
-- and a word, no outline, so it never reads as something to press.
--
-- The TextButton is the hit area and never changes size (lists don't
-- move). On a touch screen it is taller than what is drawn (a finger needs
-- room): the visible part stays small, centred in it.

local TextService = game:GetService("TextService")

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
	setLocked: (locked: boolean) -> (),
	setVariant: (variant: Variant) -> (),
	isEnabled: () -> boolean,
	reset: () -> (), -- drops hover / press at once (its menu was just hidden)
	flash: () -> (), -- a short red outline, on black for a red plate (a refused request)
	press: () -> (), -- plays the press animation (a keyboard shortcut was used)
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

-- Height of each size: what is drawn, and the hit area on a touch screen
-- (a finger needs more). On a phone the menu and the HUD are drawn at x0.8
-- (their smallest scale): 56 x 0.8 = 44.8, the smallest target a finger
-- hits reliably. On a PC the hit area is what is drawn.
local HEIGHTS: { [Size]: { pc: number, touch: number } } = {
	small = { pc = 24, touch = 56 },
	medium = { pc = 28, touch = 56 },
	large = { pc = 32, touch = 60 },
}
local TEXT_SIZES: { [Size]: number } = { small = 11, medium = 12, large = 13 }
local PAD: { [Size]: number } = { small = 10, medium = 12, large = 14 }
local ICON = 14 -- icon box (pixels)
local GAP = 6 -- between icon, label and key cap
local BAR = 2 -- thickness of the selection bar

local PRESS_SCALE = 0.96 -- the press: a small, quick shrink
local FLASH_SECONDS = 0.35 -- the red outline of flash()

type Look = {
	bg: Color3,
	bgT: number,
	stroke: Color3,
	strokeT: number,
	text: Color3,
	bar: Color3, -- the thin bar (selection / the main button's red mark)
	barT: number,
}
type Mode = "idle" | "hover" | "pressed" | "disabled" | "selected"

local function look(
	bg: Color3,
	bgT: number,
	stroke: Color3,
	strokeT: number,
	text: Color3,
	bar: Color3,
	barT: number
): Look
	return {
		bg = bg,
		bgT = bgT,
		stroke = stroke,
		strokeT = strokeT,
		text = text,
		bar = bar,
		barT = barT,
	}
end

-- Primary: Roblox's white button. Others: dark, see-through (they also sit
-- over the world on the HUD), faint outlines, no red marks.
local LOOKS: { [Variant]: { [Mode]: Look } } = {
	primary = {
		idle = look(C.InkHi, 0, C.InkHi, 1, C.Surface, C.Accent, 1),
		hover = look(C.Ink, 0, C.Ink, 1, C.Surface, C.Accent, 1),
		pressed = look(C.Muted, 0, C.Muted, 1, C.Surface, C.Accent, 1),
		selected = look(C.InkHi, 0, C.InkHi, 1, C.Surface, C.Accent, 1),
		-- Same white shape, dimmed (as Roblox does): "BUYING…" stays readable.
		disabled = look(C.InkHi, 0.5, C.InkHi, 1, C.Surface, C.Accent, 1),
	},
	secondary = {
		idle = look(C.Surface, 0.4, C.InkHi, 0.78, C.Ink, C.Accent, 1),
		hover = look(C.CardHi, 0.25, C.InkHi, 0.6, C.InkHi, C.Accent, 1),
		pressed = look(C.Card, 0.25, C.InkHi, 0.7, C.Ink, C.Accent, 1),
		selected = look(C.CardHi, 0.1, C.InkHi, 0.35, C.InkHi, C.Accent, 1),
		disabled = look(C.Surface, 0.6, C.Ink3, 0.88, C.Ink3, C.Accent, 1),
	},
	danger = {
		idle = look(C.Surface, 0.4, C.BloodHi, 0.45, C.BloodHi, C.Accent, 1),
		hover = look(C.BloodHi, 0.8, C.BloodHi, 0, C.InkHi, C.Accent, 1),
		pressed = look(C.BloodHi, 0.65, C.BloodHi, 0, C.InkHi, C.Accent, 1),
		selected = look(C.BloodHi, 0.8, C.BloodHi, 0, C.InkHi, C.Accent, 1),
		disabled = look(C.Surface, 0.6, C.Ink3, 0.88, C.Ink3, C.Accent, 1),
	},
	tab = {
		idle = look(C.InkHi, 1, C.Ink, 1, C.Ink2, C.Ink, 1),
		hover = look(C.InkHi, 0.94, C.Ink, 1, C.InkHi, C.Ink, 0.6),
		pressed = look(C.InkHi, 0.9, C.Ink, 1, C.Ink, C.Ink, 0.4),
		selected = look(C.InkHi, 1, C.Ink, 1, C.InkHi, C.InkHi, 0),
		disabled = look(C.InkHi, 1, C.Ink, 1, C.Ink3, C.Ink, 1),
	},
}

-- Rounded (Theme.RADIUS); none at all when it is 0.
local function corner(parent: Instance, extra: number)
	local radius = Theme.RADIUS + (if Theme.RADIUS > 0 then extra else 0)
	if radius > 0 then
		Theme.make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
	end
end

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

-- Width of `text` once drawn (measured in the regular weight; the labels
-- are a bit heavier, hence the margin).
local function measure(text: string, textSize: number): number
	local bounds = TextService:GetTextSize(
		text,
		scaledTextSize(textSize),
		Enum.Font.BuilderSans,
		Vector2.new(4096, 4096)
	)
	return math.ceil(bounds.X * 1.08) + 2
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

-- Recolours an icon. Tweens it starts go into `tweens` (if given).
local function paintIcon(icon: Frame?, color: Color3, seconds: number, tweens: { Tween }?)
	if icon == nil then
		return
	end
	for _, part in icon:GetDescendants() do
		local tween: Tween? = nil
		if part:IsA("Frame") and part.Name == "Part" then
			if seconds > 0 then
				tween = Theme.tween(part, seconds, { BackgroundColor3 = color })
			else
				part.BackgroundColor3 = color
			end
		elseif part:IsA("UIStroke") then
			if seconds > 0 then
				tween = Theme.tween(part, seconds, { Color = color })
			else
				part.Color = color
			end
		end
		if tween and tweens then
			table.insert(tweens, tween)
		end
	end
end

-- A key cap inside a button ("M"), in the button's text colour.
local function keyCap(text: string, parent: Instance, order: number): (Frame, TextLabel, UIStroke)
	local cap = Theme.make("Frame", {
		Name = "KeyCap",
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Theme.make("UIPadding", {
			PaddingLeft = UDim.new(0, 5),
			PaddingRight = UDim.new(0, 5),
		}),
	}) :: Frame
	local stroke = Theme.make("UIStroke", {
		Thickness = 1,
		Color = C.Ink,
		Transparency = 0.65,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = cap,
	}) :: UIStroke
	local label = Theme.text({
		Name = "Key",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(8, 16),
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
	-- The bar sits left of the text (lists, the main button) or under it
	-- (centred tabs). A left bar needs a little room before the text.
	local sideBar = align == "left" or variant == "primary"
	local lead = if sideBar and isTab then 4 else 0
	-- What is drawn: the PC height, even where the hit area is taller.
	local drawn = if options.height then height else math.min(height, HEIGHTS[size].pc)

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

	local plate = Theme.make("Frame", {
		Name = "Plate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, drawn),
		BackgroundColor3 = C.InkHi,
		BackgroundTransparency = 1,
		Parent = instance,
	}) :: Frame
	corner(plate, 0)
	local stroke = Theme.make("UIStroke", {
		Thickness = 1,
		Color = C.Ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = plate,
	}) :: UIStroke
	local scale = Theme.make("UIScale", { Parent = plate }) :: UIScale

	-- The thin bar: selection (tabs), the red mark (main button).
	local barFrame = Theme.make("Frame", {
		Name = "Bar",
		AnchorPoint = if sideBar then Vector2.new(0, 0.5) else Vector2.new(0.5, 1),
		Position = if sideBar then UDim2.fromScale(0, 0.5) else UDim2.fromScale(0.5, 1),
		Size = if sideBar
			then UDim2.new(0, BAR, 1, if isTab then -math.floor(drawn * 0.4) else 0)
			else UDim2.new(1, -2 * pad, 0, BAR),
		BackgroundColor3 = C.Accent,
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = plate,
	}) :: Frame

	-- Locked (setLocked): a lock on the right, the text dimmed.
	local lockIcon: Frame? = nil

	local content = Theme.make("Frame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = plate,
	}, {
		Theme.make("UIPadding", {
			PaddingLeft = UDim.new(0, pad + lead),
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
	local contentPadding = content:FindFirstChildOfClass("UIPadding") :: UIPadding

	local icon: Frame? = if options.icon then drawIcon(options.icon, content, 1) else nil

	local indexLabel: TextLabel? = nil
	if options.index then
		indexLabel = Theme.text({
			Name = "Index",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(18, drawn),
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
			Position = UDim2.new(0, 0, 0.5, -14),
			Size = UDim2.new(1, 0, 0, 15),
			FontFace = Theme.Fonts.Label,
			TextSize = textSize + 1,
			TextStrokeTransparency = 1,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = Theme.track(text, "four"),
			Parent = stack,
		}) :: TextLabel
		sub = Theme.text({
			Name = "Sub",
			Position = UDim2.new(0, 0, 0.5, 2),
			Size = UDim2.new(1, 0, 0, 12),
			FontFace = Theme.Fonts.Body,
			TextSize = 11,
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
			Size = UDim2.fromOffset(0, drawn),
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
		local width = 2 * pad + lead + measure(Theme.track(text, "four"), textSize)
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
	local locked = false
	local hovered = false
	local pressed = false
	local subColor = C.Ink3 -- the second line's own colour (setSubtext)

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

	-- The last paint's tweens: a new paint stops them first, or one still
	-- running (e.g. towards the hover size) would undo it. The stroke's is
	-- kept apart: while the red outline of flash() shows (until flashUntil)
	-- paint leaves the stroke alone.
	local paintTweens: { Tween } = {}
	local strokeTween: Tween? = nil
	local flashUntil = 0

	local function paint(seconds: number)
		local current: Mode = mode()
		local looks = LOOKS[variant]
		local wanted = looks[current]
		local strokeFree = os.clock() >= flashUntil
		-- A selected tab under the mouse: the faint hover plate, bar kept.
		if current == "selected" and hovered and isTab then
			wanted = table.clone(wanted)
			local hoverMode: Mode = "hover"
			wanted.bgT = looks[hoverMode].bgT
		end
		-- Locked (not picked): one step quieter, text dimmed.
		if locked and (current == "idle" or current == "hover") then
			wanted = table.clone(wanted)
			wanted.text = if current == "hover" then C.Ink2 else C.Ink3
		end
		local iconColor = wanted.text
		local targetScale = if current == "pressed" then PRESS_SCALE else 1
		for _, tween in paintTweens do
			tween:Cancel()
		end
		table.clear(paintTweens)
		if strokeFree and strokeTween then
			strokeTween:Cancel()
			strokeTween = nil
		end
		if seconds <= 0 then
			plate.BackgroundColor3 = wanted.bg
			plate.BackgroundTransparency = wanted.bgT
			if strokeFree then
				stroke.Color = wanted.stroke
				stroke.Transparency = wanted.strokeT
				stroke.Thickness = 1
			end
			label.TextColor3 = wanted.text
			barFrame.BackgroundColor3 = wanted.bar
			barFrame.BackgroundTransparency = wanted.barT
			scale.Scale = targetScale
		else
			table.insert(
				paintTweens,
				Theme.tween(plate, seconds, {
					BackgroundColor3 = wanted.bg,
					BackgroundTransparency = wanted.bgT,
				})
			)
			if strokeFree then
				stroke.Thickness = 1
				strokeTween = Theme.tween(
					stroke,
					seconds,
					{ Color = wanted.stroke, Transparency = wanted.strokeT }
				)
			end
			table.insert(paintTweens, Theme.tween(label, seconds, { TextColor3 = wanted.text }))
			table.insert(
				paintTweens,
				Theme.tween(barFrame, seconds, {
					BackgroundColor3 = wanted.bar,
					BackgroundTransparency = wanted.barT,
				})
			)
			table.insert(paintTweens, Theme.tween(scale, seconds, { Scale = targetScale }))
		end
		paintIcon(icon, iconColor, seconds, paintTweens)
		if key then
			key.TextColor3 = wanted.text
		end
		if keyStroke then
			keyStroke.Color = wanted.text
		end
		local indexText = indexLabel
		if indexText then
			indexText.TextColor3 = if current == "selected" then C.Ink2 else C.Ink3
		end
		local subText = sub
		if subText then
			subText.TextColor3 = if current == "selected" or current == "hover"
				then C.Ink2
				else subColor
		end
		local lockFrame = lockIcon
		if lockFrame then
			paintIcon(lockFrame, if current == "selected" then C.Ink else C.Ink3, 0)
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

	-- Hidden (by itself, e.g. MENU while the menu is open): Roblox does not
	-- always send MouseLeave then, so it would come back lit up.
	local function reset()
		hovered = false
		pressed = false
		paint(0)
	end
	instance:GetPropertyChangedSignal("Visible"):Connect(function()
		if not instance.Visible then
			reset()
		end
	end)

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
					subColor = color
				end
				subLabel.TextColor3 = if selected and enabled then C.Ink2 else subColor
			end
		end,
		setLocked = function(value: boolean)
			if value == locked then
				return
			end
			locked = value
			if value and lockIcon == nil then
				local holder = drawIcon("lock", plate, 0)
				holder.Name = "Lock"
				holder.AnchorPoint = Vector2.new(1, 0.5)
				holder.Position = UDim2.new(1, -pad + 4, 0.5, 0)
				lockIcon = holder
			end
			local lockFrame = lockIcon
			if lockFrame then
				lockFrame.Visible = value
			end
			-- (the text stops before the lock)
			contentPadding.PaddingRight = UDim.new(0, if value then pad + ICON + 2 else pad)
			paint(Theme.FAST)
		end,
		setEnabled = function(value: boolean)
			if value == enabled then
				return
			end
			enabled = value
			-- (Active stays on: a press on a greyed button is still taken by
			-- the GUI, so it never reaches combat as a punch.)
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
		reset = reset,
		flash = function()
			-- Stop the outline's tween (setEnabled / hover just started one)
			-- or it paints over the red on the next frame.
			local running = strokeTween
			if running then
				running:Cancel()
				strokeTween = nil
			end
			local untilTime = os.clock() + FLASH_SECONDS
			flashUntil = untilTime
			stroke.Color = C.BloodHi
			stroke.Thickness = 2
			stroke.Transparency = 0
			task.delay(FLASH_SECONDS, function()
				-- (a newer flash keeps the red for its own time)
				if flashUntil ~= untilTime then
					return
				end
				flashUntil = 0
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
	}
	instance.Parent = options.parent
	return api
end

------------------------------------------------------------------------------
-- Badge (not clickable)
------------------------------------------------------------------------------

-- "✓ EQUIPPED": a check in gold (what you wear) and a word, nothing around
-- them, so it reads as a state, not an action. Returns the frame.
function Button.badge(options: BadgeOptions): Frame
	local size: Size = options.size or "medium"
	local height = HEIGHTS[size].pc
	local pad = PAD[size]
	local textSize = TEXT_SIZES[size]
	local width = 2 * pad + measure(options.text, textSize)
	if options.icon then
		width += ICON + GAP
	end
	local badge = Theme.make("Frame", {
		Name = options.name or "Badge",
		AnchorPoint = options.anchorPoint or Vector2.zero,
		Position = options.position or UDim2.new(),
		Size = UDim2.fromOffset(width, height),
		LayoutOrder = options.layoutOrder or 0,
		BackgroundTransparency = 1,
	}) :: Frame
	local content = Theme.make("Frame", {
		Name = "Content",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = badge,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	if options.icon then
		paintIcon(drawIcon(options.icon, content, 1), C.Gold, 0)
	end
	Theme.text({
		Name = "Label",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = textSize,
		TextColor3 = C.Ink,
		TextStrokeTransparency = 1,
		Text = options.text,
		Parent = content,
	})
	badge.Parent = options.parent
	return badge
end

return table.freeze(Button)
