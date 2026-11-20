--!strict
-- ExtractionUI: the screen of the extraction mini-game (Theme style: small, quiet).
--
--   top centre      "STEP 3/6 · SPREAD", one hint line, 6 pips (done / now / to do)
--   bottom centre   "ESC  Stop" (a key cap on a PC) and a STOP button (works by touch too)
--   over the scene  markers drawn where the 3D things are on the screen:
--                     rings     the two port clamps (a needle = how far you turned, a short
--                               bright arc = the sweet spot)
--                     marker    a soft pulsing circle: "press here" (hatch, core, capsule)
--                     band      two thin lines: keep the pointer between them (spread)
--                     meter     a thin bar beside the core: lift progress + tension
--   result card     "SEALED · GRADE B" in the middle when the server confirms, where the core
--                   went, and a line with the reasons for lost points and its price
-- A full-screen invisible button sits under all this: it takes the clicks / taps, so they
-- never reach the fight controls (CombatController ignores "game processed" input).
--
-- Every position here is in VIEWPORT pixels (the ScreenGui ignores Roblox's top bar inset),
-- like Camera:WorldToViewportPoint.
--
--   ExtractionUI.new(onStop) → UI
--   ExtractionUI.show(ui, on)
--   ExtractionUI.setStep(ui, step, name, hint)    ExtractionUI.setHint(ui, hint)
--   ExtractionUI.ring(ui, index, centre?, radius, turnDegrees, sweetDegrees, done)
--   ExtractionUI.marker(ui, key, centre?, radius, label?)
--   ExtractionUI.band(ui, y?, halfHeight, x0, x1, inside)
--   ExtractionUI.meter(ui, at?, progress, tension)
--   ExtractionUI.result(ui, text, sub)
--   ExtractionUI.isOverStop(ui, point)
--   ExtractionUI.destroy(ui)

local Players = game:GetService("Players")

local Button = require(script.Parent.Parent.UI.Button)
local Theme = require(script.Parent.Parent.UI.Theme)

local ExtractionUI = {}

local COLORS = Theme.Colors
-- The mini-game's one accent: a cold milky teal (never red).
local MARK = Color3.fromRGB(160, 232, 222)
local SWEET = Color3.fromRGB(255, 196, 110) -- the clamp's sweet spot (amber)
local STEP_COUNT = 6

type Ring = { frame: Frame, needle: Frame, sweet: { Frame }, stroke: UIStroke }

export type UI = {
	gui: ScreenGui,
	catcher: TextButton,
	panel: Frame,
	title: TextLabel,
	hint: TextLabel,
	pips: { Frame },
	stop: Button.Button,
	escCap: TextLabel,
	rings: { Ring },
	markers: { [string]: Frame },
	bandTop: Frame,
	bandBottom: Frame,
	meterBack: Frame,
	meterFill: Frame,
	meterTension: Frame,
	card: Frame,
	cardTitle: TextLabel,
	cardSub: TextLabel,
	cardNote: TextLabel,
}

local function circle(props: { [string]: any }): Frame
	local frame = Theme.make("Frame", props, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}) :: Frame
	return frame
end

local function newRing(parent: Instance): Ring
	local frame = circle({
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3,
		Parent = parent,
	})
	local stroke = Theme.make("UIStroke", {
		Thickness = 2,
		Color = MARK,
		Transparency = 0.45,
		Parent = frame,
	}) :: UIStroke
	-- the sweet spot: 5 small dots on an arc (placed in ExtractionUI.ring)
	local sweet = {}
	for _ = 1, 5 do
		table.insert(
			sweet,
			circle({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(5, 5),
				BackgroundColor3 = SWEET,
				ZIndex = 4,
				Parent = frame,
			})
		)
	end
	local needle = circle({
		Name = "Needle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(9, 9),
		BackgroundColor3 = COLORS.InkHi,
		ZIndex = 5,
		Parent = frame,
	})
	Theme.make(
		"UIStroke",
		{ Thickness = 1.5, Color = Color3.new(0, 0, 0), Transparency = 0.5, Parent = needle }
	)
	return { frame = frame, needle = needle, sweet = sweet, stroke = stroke }
end

function ExtractionUI.new(onStop: () -> ()): UI
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Theme.make("ScreenGui", {
		Name = "Extraction",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	-- The click catcher (under everything).
	local catcher = Theme.make("TextButton", {
		Name = "Catcher",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Selectable = false,
		Parent = gui,
	}) :: TextButton

	-- Top centre: step, hint, pips.
	local panel = Theme.make("Frame", {
		Name = "Step",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(420, 74),
		BackgroundColor3 = COLORS.Scrim,
		BackgroundTransparency = 0.35,
		ZIndex = 10,
		Parent = gui,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, Theme.RADIUS_LARGE) }),
	}) :: Frame
	Theme.autoScale(panel, 0.8)
	local title = Theme.text({
		Name = "Title",
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 16,
		TextColor3 = COLORS.InkHi,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 11,
		Parent = panel,
	}) :: TextLabel
	local hint = Theme.text({
		Name = "Hint",
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -24, 0, 18),
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TEXT,
		TextColor3 = COLORS.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 11,
		Parent = panel,
	}) :: TextLabel
	local pips = {}
	for i = 1, STEP_COUNT do
		local pip = Theme.make("Frame", {
			Name = "Pip",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, (i - 3.5) * 30, 0, 58),
			Size = UDim2.fromOffset(24, 4),
			BackgroundColor3 = COLORS.Ink3,
			ZIndex = 11,
			Parent = panel,
		}, {
			Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}) :: Frame
		table.insert(pips, pip)
	end

	-- Bottom centre: how to stop.
	local footer = Theme.make("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(220, 40),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	}) :: Frame
	Theme.autoScale(footer, 0.8)
	local escCap = Theme.keyCap("ESC", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0.5, -6, 0.5, 0),
		ZIndex = 11,
		Parent = footer,
	}) :: TextLabel
	local stop = Button.new({
		text = "STOP",
		variant = "secondary",
		size = "medium",
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.new(0.5, 6, 0.5, 0),
		zIndex = 11,
		parent = footer,
		onActivated = onStop,
	})

	-- Markers, band, meter, result card.
	local rings = { newRing(gui), newRing(gui) }
	local function line(name: string): Frame
		return Theme.make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = MARK,
			BackgroundTransparency = 0.55,
			Size = UDim2.fromOffset(10, 2),
			Visible = false,
			ZIndex = 3,
			Parent = gui,
		}) :: Frame
	end
	local meterBack = Theme.make("Frame", {
		Name = "Meter",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(8, 120),
		BackgroundColor3 = COLORS.Scrim,
		BackgroundTransparency = 0.3,
		Visible = false,
		ZIndex = 3,
		Parent = gui,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}) :: Frame
	local meterFill = Theme.make("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = MARK,
		ZIndex = 4,
		Parent = meterBack,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}) :: Frame
	-- tension: a tick that climbs above the fill when you pull too hard
	local meterTension = Theme.make("Frame", {
		Name = "Tension",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 8, 0, 3),
		BackgroundColor3 = SWEET,
		ZIndex = 5,
		Parent = meterBack,
	}) :: Frame
	local card = Theme.make("Frame", {
		Name = "Result",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(320, 92),
		BackgroundColor3 = COLORS.Scrim,
		BackgroundTransparency = 0.3,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, Theme.RADIUS_LARGE) }),
	}) :: Frame
	Theme.autoScale(card, 0.8)
	local cardTitle = Theme.text({
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 26),
		FontFace = Theme.Fonts.Display,
		TextSize = Theme.TITLE,
		TextColor3 = COLORS.InkHi,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 21,
		Parent = card,
	}) :: TextLabel
	local cardSub = Theme.text({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 18),
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TEXT,
		TextColor3 = COLORS.Ink2,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 21,
		Parent = card,
	}) :: TextLabel
	-- (why points were lost and what the core is worth: it teaches the mini-game)
	local cardNote = Theme.text({
		Position = UDim2.fromOffset(10, 62),
		Size = UDim2.new(1, -20, 0, 18),
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TEXT,
		TextColor3 = COLORS.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 21,
		Parent = card,
	}) :: TextLabel

	gui.Parent = playerGui
	local ui: UI = {
		gui = gui,
		catcher = catcher,
		panel = panel,
		title = title,
		hint = hint,
		pips = pips,
		stop = stop,
		escCap = escCap,
		rings = rings,
		markers = {},
		bandTop = line("BandTop"),
		bandBottom = line("BandBottom"),
		meterBack = meterBack,
		meterFill = meterFill,
		meterTension = meterTension,
		card = card,
		cardTitle = cardTitle,
		cardSub = cardSub,
		cardNote = cardNote,
	}
	return ui
end

function ExtractionUI.show(ui: UI, on: boolean)
	ui.gui.Enabled = on
	ui.escCap.Visible = not Theme.isTouch()
	if not on then
		ui.card.Visible = false
		ui.stop.reset()
	end
end

-- `step` 1..6 (7 = done).
function ExtractionUI.setStep(ui: UI, step: number, name: string, hint: string)
	ui.title.Text = if step <= STEP_COUNT then `STEP {step}/{STEP_COUNT} · {name}` else name
	ui.hint.Text = hint
	for i, pip in ui.pips do
		if i < step then
			pip.BackgroundColor3 = MARK
			pip.BackgroundTransparency = 0
		elseif i == step then
			pip.BackgroundColor3 = COLORS.InkHi
			pip.BackgroundTransparency = 0
		else
			pip.BackgroundColor3 = COLORS.Ink3
			pip.BackgroundTransparency = 0.3
		end
	end
end

function ExtractionUI.setHint(ui: UI, hint: string)
	if ui.hint.Text ~= hint then
		ui.hint.Text = hint
	end
end

-- Clamp ring `index` around `centre` (nil = hidden). `turn` and `sweet` in degrees (0 = the
-- lever at rest, measured clockwise on the screen); `done` = unlocked (solid ring).
function ExtractionUI.ring(
	ui: UI,
	index: number,
	centre: Vector2?,
	radius: number,
	turn: number,
	sweet: number,
	done: boolean
)
	local ring = ui.rings[index]
	if ring == nil then
		return
	end
	if centre == nil then
		ring.frame.Visible = false
		return
	end
	ring.frame.Visible = true
	ring.frame.Position = UDim2.fromOffset(centre.X, centre.Y)
	ring.frame.Size = UDim2.fromOffset(radius * 2, radius * 2)
	ring.stroke.Transparency = if done then 0.1 else 0.45
	ring.stroke.Color = if done then SWEET else MARK
	local function onRing(degrees: number): UDim2
		local a = math.rad(degrees - 90) -- 0° = top of the ring
		return UDim2.new(0.5, math.cos(a) * radius, 0.5, math.sin(a) * radius)
	end
	for k, dot in ring.sweet do
		dot.Position = onRing(sweet + (k - 3) * 3)
		dot.Visible = not done
	end
	ring.needle.Position = onRing(turn)
	ring.needle.Visible = not done
end

-- A soft pulsing "press here" circle (nil centre = hidden). One per `key`.
function ExtractionUI.marker(ui: UI, key: string, centre: Vector2?, radius: number, label: string?)
	local existing: Frame? = ui.markers[key]
	if existing == nil then
		local frame = circle({
			Name = "Marker",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = MARK,
			BackgroundTransparency = 0.88,
			ZIndex = 3,
			Parent = ui.gui,
		})
		Theme.make(
			"UIStroke",
			{ Thickness = 1.5, Color = MARK, Transparency = 0.35, Parent = frame }
		)
		Theme.text({
			Name = "Label",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 6),
			Size = UDim2.fromOffset(160, 16),
			FontFace = Theme.Fonts.LabelBold,
			TextSize = Theme.SMALL,
			TextColor3 = COLORS.InkHi,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 4,
			Parent = frame,
		})
		ui.markers[key] = frame
		existing = frame
	end
	local marker = existing :: Frame
	if centre == nil then
		marker.Visible = false
		return
	end
	marker.Visible = true
	local pulse = 1 + 0.08 * math.sin(os.clock() * 5)
	marker.Position = UDim2.fromOffset(centre.X, centre.Y)
	marker.Size = UDim2.fromOffset(radius * 2 * pulse, radius * 2 * pulse)
	local text = marker:FindFirstChild("Label")
	if text and text:IsA("TextLabel") then
		text.Text = label or ""
	end
end

-- The spread band: two lines at y ± halfHeight from x0 to x1 (nil y = hidden). `inside` =
-- the pointer is between them (lines brighten).
function ExtractionUI.band(
	ui: UI,
	y: number?,
	halfHeight: number,
	x0: number,
	x1: number,
	inside: boolean
)
	for i, line in { ui.bandTop, ui.bandBottom } do
		if y == nil then
			line.Visible = false
		else
			line.Visible = true
			local offset = if i == 1 then -halfHeight else halfHeight
			line.Position = UDim2.fromOffset(math.min(x0, x1), y + offset)
			line.Size = UDim2.fromOffset(math.abs(x1 - x0), 2)
			line.BackgroundColor3 = if inside then MARK else SWEET
			line.BackgroundTransparency = if inside then 0.45 else 0.2
		end
	end
end

-- The lift meter beside the core (nil = hidden): progress 0..1, tension 0..1.
function ExtractionUI.meter(ui: UI, at: Vector2?, progress: number, tension: number)
	if at == nil then
		ui.meterBack.Visible = false
		return
	end
	ui.meterBack.Visible = true
	ui.meterBack.Position = UDim2.fromOffset(at.X, at.Y)
	ui.meterFill.Size = UDim2.fromScale(1, math.clamp(progress, 0, 1))
	local tick = math.clamp(progress + tension, 0, 1)
	ui.meterTension.Position = UDim2.fromScale(0.5, 1 - tick)
	ui.meterTension.BackgroundTransparency = if tension > 0.25 then 0 else 0.6
end

function ExtractionUI.result(ui: UI, text: string?, sub: string?, note: string?)
	if text == nil then
		ui.card.Visible = false
		return
	end
	ui.card.Visible = true
	ui.cardTitle.Text = text
	ui.cardSub.Text = sub or ""
	ui.cardNote.Text = note or ""
end

-- Is the viewport point over the STOP button? (its own clicks must not start a gesture)
function ExtractionUI.isOverStop(ui: UI, point: Vector2): boolean
	local button = ui.stop.instance
	local position = button.AbsolutePosition
	local size = button.AbsoluteSize
	return point.X >= position.X
		and point.X <= position.X + size.X
		and point.Y >= position.Y
		and point.Y <= position.Y + size.Y
end

function ExtractionUI.destroy(ui: UI)
	ui.gui:Destroy()
end

return ExtractionUI
