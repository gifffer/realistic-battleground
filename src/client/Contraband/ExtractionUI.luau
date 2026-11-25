--!strict
-- ExtractionUI: the screen of the extraction (Theme style: small, quiet; the scene is the
-- interface, autopsy-style).
--
--   top centre      "EXTRACT · CHOOSE 2" and a thin COOLING bar (the time left to choose;
--                   it pulses in its last seconds)
--   bottom centre   one hint line ("Hold on an element to lift it out."), a DONE button and
--                   "ESC  Stop" (a STOP button that works by touch too)
--   over the scene  the HOLD RING: a thin circle of dots around the pointer that fills while
--                   you hold an element (the only meter); the SCAN TAG: a small label next to
--                   the hovered element ("POD" + 3 viability bars, or "NO SIGNAL")
--   result card     "SEALED 2/2" in the middle, one line per capsule ("COIL · GRADE A · 48"
--                   or "INERT"), and where the cores went
-- A full-screen invisible button (Modal) sits under all this: it takes the clicks / taps, so
-- they never reach the fight controls, and frees the mouse in first person.
--
-- Positions are VIEWPORT pixels (the ScreenGui ignores Roblox's top bar inset), like
-- Camera:WorldToViewportPoint. Transitions follow the roblox-animation skill (TweenService,
-- quiet Quad easing, no Back / Bounce): the panel and the card are CanvasGroups that fade in
-- (0.18 s Quad Out, the card also grows 96 % → 100 %) and out (0.15 s Quad In); each tween is
-- kept and cancelled by the next show / hide.
--
--   ExtractionUI.new(onStop, onDone) → UI
--   ExtractionUI.show(ui, on)
--   ExtractionUI.setTitle(ui, text)       ExtractionUI.setHint(ui, text)
--   ExtractionUI.setCooling(ui, left?, low)   (left 0..1, nil = hidden; low = last seconds)
--   ExtractionUI.setDone(ui, visible, enabled)
--   ExtractionUI.holdRing(ui, at?, progress)
--   ExtractionUI.tag(ui, at?, title, bars, scanning)
--   ExtractionUI.result(ui, title?, lines, sub)
--   ExtractionUI.isOverButtons(ui, point)
--   ExtractionUI.destroy(ui)

local Players = game:GetService("Players")

local Button = require(script.Parent.Parent.UI.Button)
local Theme = require(script.Parent.Parent.UI.Theme)

local ExtractionUI = {}

local COLORS = Theme.Colors
-- The mini-game's one accent: a cold milky teal (never red); amber for the last seconds.
local MARK = Color3.fromRGB(160, 232, 222)
local LOW = Color3.fromRGB(255, 196, 110)
local FADE_IN = 0.18
local FADE_OUT = 0.15
local CARD_SIZE = Vector2.new(340, 128)
local RING_DOTS = 16
local RING_RADIUS = 26
local TAG_BARS = 3

type Running = { panel: Tween?, card: { Tween }, token: number, cardToken: number }
local running: { [ScreenGui]: Running } = setmetatable({}, { __mode = "k" }) :: any

local function runningOf(gui: ScreenGui): Running
	local found = running[gui]
	if found then
		return found
	end
	local made: Running = { panel = nil, card = {}, token = 0, cardToken = 0 }
	running[gui] = made
	return made
end

export type UI = {
	gui: ScreenGui,
	catcher: TextButton,
	panel: CanvasGroup,
	title: TextLabel,
	coolBack: Frame,
	coolFill: Frame,
	footer: Frame,
	hint: TextLabel,
	done: Button.Button,
	stop: Button.Button,
	escCap: TextLabel,
	ring: Frame,
	ringDots: { Frame },
	tagFrame: Frame,
	tagTitle: TextLabel,
	tagBars: { Frame },
	card: CanvasGroup,
	cardTitle: TextLabel,
	cardLines: TextLabel,
	cardSub: TextLabel,
}

local function circle(props: { [string]: any }, extra: { Instance }?): Frame
	local children: { Instance } = {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}
	if extra then
		for _, child in extra do
			table.insert(children, child)
		end
	end
	return Theme.make("Frame", props, children) :: Frame
end

function ExtractionUI.new(onStop: () -> (), onDone: () -> ()): UI
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Theme.make("ScreenGui", {
		Name = "Extraction",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	-- The click catcher (under everything; Modal frees the mouse in first person).
	local catcher = Theme.make("TextButton", {
		Name = "Catcher",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Selectable = false,
		Modal = true,
		Parent = gui,
	}) :: TextButton

	-- Top centre: title + cooling bar.
	local panel = Theme.make("CanvasGroup", {
		Name = "Head",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(300, 52),
		BackgroundColor3 = COLORS.Scrim,
		BackgroundTransparency = 0.35,
		ZIndex = 10,
		Parent = gui,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, Theme.RADIUS_LARGE) }),
	}) :: CanvasGroup
	Theme.autoScale(panel, 0.8)
	local title = Theme.text({
		Name = "Title",
		Position = UDim2.fromOffset(0, 9),
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 16,
		TextColor3 = COLORS.InkHi,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 11,
		Parent = panel,
	}) :: TextLabel
	local coolBack = Theme.make("Frame", {
		Name = "Cooling",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 36),
		Size = UDim2.new(1, -48, 0, 4),
		BackgroundColor3 = COLORS.Plate,
		ZIndex = 11,
		Parent = panel,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}) :: Frame
	local coolFill = Theme.make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = MARK,
		ZIndex = 12,
		Parent = coolBack,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}) :: Frame

	-- Bottom centre: the hint, DONE, how to stop.
	local footer = Theme.make("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(420, 78),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	}) :: Frame
	Theme.autoScale(footer, 0.8)
	-- (a dark backing: the hint must stay readable over the pale shell)
	Theme.make("Frame", {
		Name = "HintBack",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -1),
		Size = UDim2.fromOffset(440, 22),
		BackgroundColor3 = COLORS.Scrim,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = footer,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, 4) }),
	})
	local hint = Theme.text({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TEXT,
		TextColor3 = COLORS.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 11,
		Parent = footer,
	}) :: TextLabel
	local done = Button.new({
		text = "DONE",
		variant = "primary",
		size = "medium",
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(0.5, -60, 0, 52),
		zIndex = 11,
		parent = footer,
		onActivated = onDone,
	})
	local escCap = Theme.keyCap("ESC", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0.5, 34, 0, 52),
		ZIndex = 11,
		Parent = footer,
	}) :: TextLabel
	local stop = Button.new({
		text = "STOP",
		variant = "secondary",
		size = "medium",
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.new(0.5, 42, 0, 52),
		zIndex = 11,
		parent = footer,
		onActivated = onStop,
	})

	-- The hold ring (dots around the pointer).
	local ring = Theme.make("Frame", {
		Name = "HoldRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(RING_RADIUS * 2, RING_RADIUS * 2),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	}) :: Frame
	local ringDots = {}
	for k = 1, RING_DOTS do
		local a = math.rad((k - 1) / RING_DOTS * 360 - 90)
		table.insert(
			ringDots,
			circle({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(
					0.5,
					math.cos(a) * RING_RADIUS,
					0.5,
					math.sin(a) * RING_RADIUS
				),
				Size = UDim2.fromOffset(5, 5),
				-- (light ink with a dark outline: MARK teal vanished on the pale cavity)
				BackgroundColor3 = COLORS.InkHi,
				BackgroundTransparency = 0.75,
				ZIndex = 6,
				Parent = ring,
			}, {
				Theme.make("UIStroke", { Thickness = 1, Color = COLORS.Scrim, Transparency = 0.2 }),
			})
		)
	end

	-- The scan tag (next to the hovered element).
	local tagFrame = Theme.make("Frame", {
		Name = "ScanTag",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(112, 34),
		BackgroundColor3 = COLORS.Scrim,
		BackgroundTransparency = 0.4,
		Visible = false,
		ZIndex = 7,
		Parent = gui,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Theme.make("UIStroke", { Thickness = 1, Color = MARK, Transparency = 0.6 }),
	}) :: Frame
	local tagTitle = Theme.text({
		Name = "Kind",
		Position = UDim2.fromOffset(8, 3),
		Size = UDim2.new(1, -16, 0, 16),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = Theme.SMALL,
		TextColor3 = COLORS.InkHi,
		Text = "",
		ZIndex = 8,
		Parent = tagFrame,
	}) :: TextLabel
	local tagBars = {}
	for k = 1, TAG_BARS do
		table.insert(
			tagBars,
			Theme.make("Frame", {
				Name = "Bar",
				Position = UDim2.fromOffset(8 + (k - 1) * 14, 22),
				Size = UDim2.fromOffset(11, 5),
				BackgroundColor3 = MARK,
				ZIndex = 8,
				Parent = tagFrame,
			}) :: Frame
		)
	end

	-- The result card.
	local card = Theme.make("CanvasGroup", {
		Name = "Result",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
		GroupTransparency = 1,
		BackgroundColor3 = COLORS.Scrim,
		BackgroundTransparency = 0.3,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, Theme.RADIUS_LARGE) }),
	}) :: CanvasGroup
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
	local cardLines = Theme.text({
		Position = UDim2.fromOffset(10, 44),
		Size = UDim2.new(1, -20, 0, 52),
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TEXT,
		TextColor3 = COLORS.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ZIndex = 21,
		Parent = card,
	}) :: TextLabel
	local cardSub = Theme.text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -10),
		Size = UDim2.new(1, 0, 0, 18),
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TEXT,
		TextColor3 = COLORS.Ink2,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 21,
		Parent = card,
	}) :: TextLabel

	gui.Parent = playerGui
	return {
		gui = gui,
		catcher = catcher,
		panel = panel,
		title = title,
		coolBack = coolBack,
		coolFill = coolFill,
		footer = footer,
		hint = hint,
		done = done,
		stop = stop,
		escCap = escCap,
		ring = ring,
		ringDots = ringDots,
		tagFrame = tagFrame,
		tagTitle = tagTitle,
		tagBars = tagBars,
		card = card,
		cardTitle = cardTitle,
		cardLines = cardLines,
		cardSub = cardSub,
	}
end

function ExtractionUI.show(ui: UI, on: boolean)
	local state = runningOf(ui.gui)
	if state.panel then
		state.panel:Cancel()
		state.panel = nil
	end
	state.token += 1
	local token = state.token
	ui.escCap.Visible = not Theme.isTouch()
	if on then
		ui.catcher.Visible = true
		ui.footer.Visible = true
		if not ui.gui.Enabled then
			ui.panel.GroupTransparency = 1
		end
		ui.gui.Enabled = true
		state.panel = Theme.tween(
			ui.panel,
			FADE_IN,
			{ GroupTransparency = 0 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)
		return
	end
	-- (the clicks go back to the game at once; the panel fades out, then the gui is off)
	ui.catcher.Visible = false
	ui.footer.Visible = false
	ui.ring.Visible = false
	ui.tagFrame.Visible = false
	ui.stop.reset()
	ui.done.reset()
	ExtractionUI.result(ui, nil, {}, nil)
	if not ui.gui.Enabled then
		return
	end
	local tween = Theme.tween(
		ui.panel,
		FADE_OUT,
		{ GroupTransparency = 1 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	state.panel = tween
	tween.Completed:Once(function(playback)
		if playback == Enum.PlaybackState.Completed and state.token == token then
			ui.gui.Enabled = false
		end
	end)
end

function ExtractionUI.setTitle(ui: UI, text: string)
	if ui.title.Text ~= text then
		ui.title.Text = text
	end
end

function ExtractionUI.setHint(ui: UI, text: string)
	if ui.hint.Text ~= text then
		ui.hint.Text = text
	end
end

-- The cooling bar: `left` 0..1 of the time left (nil = hidden). `low` = the last seconds:
-- amber, and it pulses.
function ExtractionUI.setCooling(ui: UI, left: number?, low: boolean)
	if left == nil then
		ui.coolBack.Visible = false
		return
	end
	ui.coolBack.Visible = true
	ui.coolFill.Size = UDim2.fromScale(math.clamp(left, 0, 1), 1)
	ui.coolFill.BackgroundColor3 = if low then LOW else MARK
	ui.coolFill.BackgroundTransparency = if low
		then 0.3 * (0.5 + 0.5 * math.sin(os.clock() * 9))
		else 0
end

function ExtractionUI.setDone(ui: UI, visible: boolean, enabled: boolean)
	ui.done.instance.Visible = visible
	if ui.done.isEnabled() ~= enabled then
		ui.done.setEnabled(enabled)
	end
end

-- The hold ring around `at` (nil = hidden), filled to `progress` (0..1).
function ExtractionUI.holdRing(ui: UI, at: Vector2?, progress: number)
	if at == nil then
		ui.ring.Visible = false
		return
	end
	ui.ring.Visible = true
	ui.ring.Position = UDim2.fromOffset(at.X, at.Y)
	local filled = math.floor(math.clamp(progress, 0, 1) * RING_DOTS + 0.5)
	for k, dot in ui.ringDots do
		local wanted = if k <= filled then 0 else 0.75
		if dot.BackgroundTransparency ~= wanted then
			dot.BackgroundTransparency = wanted
		end
	end
end

-- The scan tag beside `at` (nil = hidden): `title` ("POD", "NO SIGNAL"), `bars` 0..3 lit,
-- `scanning` = still reading (the bars flicker, the title shows "SCANNING").
function ExtractionUI.tag(ui: UI, at: Vector2?, title: string, bars: number, scanning: boolean)
	if at == nil then
		ui.tagFrame.Visible = false
		return
	end
	ui.tagFrame.Visible = true
	ui.tagFrame.Position = UDim2.fromOffset(at.X + 28, at.Y - 24)
	local shown = if scanning then "SCANNING" else title
	if ui.tagTitle.Text ~= shown then
		ui.tagTitle.Text = shown
	end
	for k, bar in ui.tagBars do
		local on = if scanning then math.noise(os.clock() * 14, k) > 0 else k <= bars
		bar.BackgroundTransparency = if on then 0 else 0.8
	end
end

-- The result card (nil title = hide it). `lines`: one per capsule.
function ExtractionUI.result(ui: UI, title: string?, lines: { string }, sub: string?)
	local state = runningOf(ui.gui)
	for _, tween in state.card do
		tween:Cancel()
	end
	table.clear(state.card)
	state.cardToken += 1
	local token = state.cardToken
	local card = ui.card
	if title == nil then
		if not card.Visible then
			return
		end
		local tween = Theme.tween(
			card,
			FADE_OUT,
			{ GroupTransparency = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		table.insert(state.card, tween)
		tween.Completed:Once(function(playback)
			if playback == Enum.PlaybackState.Completed and state.cardToken == token then
				card.Visible = false
			end
		end)
		return
	end
	ui.cardTitle.Text = title
	ui.cardLines.Text = table.concat(lines, "\n")
	ui.cardSub.Text = sub or ""
	if not card.Visible then
		card.GroupTransparency = 1
		card.Size = UDim2.fromOffset(CARD_SIZE.X * 0.96, CARD_SIZE.Y * 0.96)
	end
	card.Visible = true
	table.insert(state.card, Theme.tween(card, FADE_IN, { GroupTransparency = 0 }))
	table.insert(
		state.card,
		Theme.tween(card, FADE_IN, { Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y) })
	)
end

local function inside(button: GuiObject, point: Vector2): boolean
	if not button.Visible then
		return false
	end
	local position = button.AbsolutePosition
	local size = button.AbsoluteSize
	return point.X >= position.X
		and point.X <= position.X + size.X
		and point.Y >= position.Y
		and point.Y <= position.Y + size.Y
end

-- Is the viewport point over STOP or DONE? (their own clicks must not start a pick)
function ExtractionUI.isOverButtons(ui: UI, point: Vector2): boolean
	return inside(ui.stop.instance, point) or inside(ui.done.instance, point)
end

function ExtractionUI.destroy(ui: UI)
	ui.gui:Destroy()
end

return ExtractionUI
