--!strict
-- ExtractionUI: the screen of the extraction (v3, Theme style: small, quiet; the scene is the
-- interface, autopsy-style: the hand and the tools ARE the controls).
--
--   top centre      a thin COOLING bar, no title (only once the panels are open; amber and
--                   pulsing in its last seconds)
--   bottom centre   ONE hint line ("Drag along the seam.") that fades (0.15 s) when it
--                   changes; H hides / shows it. Above it, a STATUS line for 2.5 s, only for
--                   refusals and explanations ("Too fast — the blade skids.")
--   bottom right    DONE (once something is sealed)
--   bottom left     STOP and its key (Backspace: Esc opens the Roblox menu)
--   result card     "SEALED 2/2" in the middle, one line per capsule ("COIL · GRADE A · 48"
--                   or "HUSK · INERT"), and where the cores went
-- No text over the 3D scene: the element readings live on the CRT only.
-- A full-screen invisible button (Modal) sits under all this: it takes the clicks / taps, so
-- they never reach the fight controls, and frees the mouse in first person.
--
-- Transitions follow the roblox-animation skill (TweenService, quiet Quad easing, no Back /
-- Bounce): CanvasGroups fade in (0.18 s Quad Out) and out (0.15 s Quad In); each tween is
-- kept and cancelled by the next one.
--
--   ExtractionUI.new(onStop, onDone) → UI
--   ExtractionUI.show(ui, on)
--   ExtractionUI.setHint(ui, text)        ExtractionUI.toggleHint(ui)
--   ExtractionUI.status(ui, text)         (2.5 s)
--   ExtractionUI.setCooling(ui, left?, low)   (left 0..1, nil = hidden; low = last seconds)
--   ExtractionUI.setDone(ui, visible, enabled)
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
local HINT_FADE = 0.15
local STATUS_TIME = 2.5
local CARD_SIZE = Vector2.new(340, 128)

type Running = {
	panel: Tween?,
	card: { Tween },
	hint: Tween?,
	token: number,
	cardToken: number,
	hintToken: number,
	statusToken: number,
}
local running: { [ScreenGui]: Running } = setmetatable({}, { __mode = "k" }) :: any

local function runningOf(gui: ScreenGui): Running
	local found = running[gui]
	if found then
		return found
	end
	local made: Running = {
		panel = nil,
		card = {},
		hint = nil,
		token = 0,
		cardToken = 0,
		hintToken = 0,
		statusToken = 0,
	}
	running[gui] = made
	return made
end

export type UI = {
	gui: ScreenGui,
	catcher: TextButton,
	panel: CanvasGroup,
	coolBack: Frame,
	coolFill: Frame,
	footer: Frame,
	hintGroup: CanvasGroup,
	hint: TextLabel,
	hintHidden: boolean,
	statusLine: TextLabel,
	done: Button.Button,
	stop: Button.Button,
	stopCap: TextLabel,
	card: CanvasGroup,
	cardTitle: TextLabel,
	cardLines: TextLabel,
	cardSub: TextLabel,
}

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

	-- Top centre: the cooling bar alone (a thin dark track, the fill on it).
	local panel = Theme.make("CanvasGroup", {
		Name = "Head",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(260, 14),
		BackgroundColor3 = COLORS.Scrim,
		BackgroundTransparency = 0.45,
		ZIndex = 10,
		Parent = gui,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}) :: CanvasGroup
	Theme.autoScale(panel, 0.8)
	local coolBack = Theme.make("Frame", {
		Name = "Cooling",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -12, 0, 4),
		BackgroundColor3 = COLORS.Plate,
		Visible = false,
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

	-- Bottom centre: the status line, the hint (on a dark backing: readable over the pale shell).
	local footer = Theme.make("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(440, 56),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	}) :: Frame
	Theme.autoScale(footer, 0.8)
	local statusLine = Theme.text({
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 20),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = Theme.TEXT,
		TextColor3 = LOW,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		Visible = false,
		ZIndex = 11,
		Parent = footer,
	}) :: TextLabel
	local hintGroup = Theme.make("CanvasGroup", {
		Name = "HintGroup",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(440, 26),
		BackgroundColor3 = COLORS.Scrim,
		BackgroundTransparency = 0.35,
		ZIndex = 10,
		Parent = footer,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, 4) }),
	}) :: CanvasGroup
	local hint = Theme.text({
		Name = "Hint",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TEXT,
		TextColor3 = COLORS.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 11,
		Parent = hintGroup,
	}) :: TextLabel

	-- Bottom corners: DONE (right), STOP + its key (left).
	local right = Theme.make("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -24),
		Size = UDim2.fromOffset(140, 44),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	}) :: Frame
	Theme.autoScale(right, 0.8)
	local done = Button.new({
		text = "DONE",
		variant = "primary",
		size = "medium",
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, 0, 0.5, 0),
		zIndex = 11,
		parent = right,
		onActivated = onDone,
	})
	local left = Theme.make("Frame", {
		Name = "Left",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -24),
		Size = UDim2.fromOffset(220, 44),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	}) :: Frame
	Theme.autoScale(left, 0.8)
	local stop = Button.new({
		text = "STOP",
		variant = "secondary",
		size = "medium",
		anchorPoint = Vector2.new(0, 0.5),
		position = UDim2.new(0, 0, 0.5, 0),
		zIndex = 11,
		parent = left,
		onActivated = onStop,
	})
	local stopCap = Theme.keyCap("BACKSPACE", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 104, 0.5, 0),
		ZIndex = 11,
		Parent = left,
	}) :: TextLabel

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
		coolBack = coolBack,
		coolFill = coolFill,
		footer = footer,
		hintGroup = hintGroup,
		hint = hint,
		hintHidden = false,
		statusLine = statusLine,
		done = done,
		stop = stop,
		stopCap = stopCap,
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
	ui.stopCap.Visible = not Theme.isTouch()
	local corners = { ui.done.instance.Parent, ui.stop.instance.Parent }
	if on then
		ui.catcher.Visible = true
		ui.footer.Visible = true
		for _, corner in corners do
			if corner and corner:IsA("GuiObject") then
				corner.Visible = true
			end
		end
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
	for _, corner in corners do
		if corner and corner:IsA("GuiObject") then
			corner.Visible = false
		end
	end
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

-- The hint line: a new text fades out the old one and in the new one (0.15 s each).
function ExtractionUI.setHint(ui: UI, text: string)
	if ui.hint.Text == text or ui.hint:GetAttribute("Next") == text then
		return
	end
	ui.hint:SetAttribute("Next", text)
	local state = runningOf(ui.gui)
	if state.hint then
		state.hint:Cancel()
	end
	state.hintToken += 1
	local token = state.hintToken
	local group = ui.hintGroup
	local out = Theme.tween(
		group,
		HINT_FADE,
		{ GroupTransparency = 1 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	state.hint = out
	out.Completed:Once(function(playback)
		if playback ~= Enum.PlaybackState.Completed or state.hintToken ~= token then
			return
		end
		ui.hint.Text = text
		group.Visible = text ~= "" and not ui.hintHidden
		state.hint = Theme.tween(
			group,
			HINT_FADE,
			{ GroupTransparency = 0 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)
	end)
end

-- H: hides / shows the hint line.
function ExtractionUI.toggleHint(ui: UI)
	ui.hintHidden = not ui.hintHidden
	ui.hintGroup.Visible = ui.hint.Text ~= "" and not ui.hintHidden
end

-- A refusal or an explanation, for 2.5 s.
function ExtractionUI.status(ui: UI, text: string)
	local state = runningOf(ui.gui)
	state.statusToken += 1
	local token = state.statusToken
	ui.statusLine.Text = text
	ui.statusLine.Visible = text ~= ""
	if text ~= "" then
		task.delay(STATUS_TIME, function()
			if state.statusToken == token then
				ui.statusLine.Visible = false
			end
		end)
	end
end

-- The cooling bar: `left` 0..1 of the time left (nil = hidden). `low` = the last seconds:
-- amber, and it pulses.
function ExtractionUI.setCooling(ui: UI, left: number?, low: boolean)
	if left == nil then
		ui.coolBack.Visible = false
		ui.panel.Visible = false
		return
	end
	ui.panel.Visible = true
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
	local parent = button.Parent
	if parent and parent:IsA("GuiObject") and not parent.Visible then
		return false
	end
	local position = button.AbsolutePosition
	local size = button.AbsoluteSize
	return point.X >= position.X
		and point.X <= position.X + size.X
		and point.Y >= position.Y
		and point.Y <= position.Y + size.Y
end

-- Is the viewport point over STOP or DONE? (their own clicks must not reach the scene)
function ExtractionUI.isOverButtons(ui: UI, point: Vector2): boolean
	return inside(ui.stop.instance, point) or inside(ui.done.instance, point)
end

function ExtractionUI.destroy(ui: UI)
	ui.gui:Destroy()
end

return ExtractionUI
