--!strict
-- ContrabandHudController: the small contraband HUD, bottom-right, left of the kit moves and
-- the SpezCola pocket (all text in English, Theme style: quiet, small, out of the way).
--
--       +72 · SOLD 1 CORE                  ← toasts (sale result, server notices), 3 s each
--       OPENING ━━━━━━━━━━━━━━             ← 1.6 s bar while the case is open at the buyer
--       CULTURE 47 % · 4:15                ← the vat culture (anywhere: it grows while online)
--       CASE ──────────────────
--       ◆ A  ◇        1/2      [G] SET DOWN
--
--   • the CASE block shows only while we hold a case: one diamond per cradle, filled with the
--     grade's colour (C amber, B teal, A gold → teal), an outline when empty; "1/2" = cores
--     in the case / cradles. What is inside comes from the server's "CaseState", sent to the
--     holder only (a thief learns the grades when he picks the case up).
--   • SET DOWN is a real button (UI/Button): G on a keyboard, a tap on a touch screen.
--   • "SaleStarted" → the OPENING bar fills until the server's end time; "SaleResult" →
--     "+72 · SOLD 1 CORE" (gold) or "SALE FAILED · Interrupted"; "Notice" → the line as is.
--   • CULTURE: from the server's "LabState" (grown / total / at / running), counted down here
--     every half second; "CULTURE READY" once ready; hidden when the vat is empty.
-- The server decides everything; this only shows what it says.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Button = require(script.Parent.Parent.UI.Button)
local Theme = require(script.Parent.Parent.UI.Theme)
local CaseController = require(script.Parent.CaseController)

local ContrabandHudController = {}

local player = Players.LocalPlayer
local C = Theme.Colors

local BLOCK_WIDTH = 230
local BLOCK_HEIGHT = 150
-- Right edge: the kit moves / pocket block is 240 px wide, 48 px from the screen's right.
local RIGHT_OFFSET = -(48 + 240 + 18)
local TOAST_TIME = 3
local MAX_TOASTS = 4

-- Grade colours (the bio-core lights, brightened for a dark HUD).
local GRADE_COLOR: { [string]: Color3 } = {
	C = Color3.fromRGB(214, 150, 64), -- amber
	B = Color3.fromRGB(90, 200, 190), -- teal
	A = C.Gold, -- gold (+ a teal gradient on the diamond)
}
local TEAL = Color3.fromRGB(90, 200, 190)

local gui: ScreenGui
local caseGroup: CanvasGroup
local pipsRow: Frame
local countLabel: TextLabel
local openingGroup: CanvasGroup
local openingFill: Frame
local toasts: Frame
local setDownButton: Button.Button

local cultureLabel: TextLabel
local culture: Types.LabStatePayload? = nil

local holding = false
local cradles = 0
local grades: { Types.CoreGrade } = {}
local toastCount = 0

------------------------------------------------------------------------------
-- Toasts
------------------------------------------------------------------------------

local function toast(text: string, color: Color3?)
	toastCount += 1
	local line = Theme.text({
		Name = "Toast",
		LayoutOrder = toastCount,
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 13,
		TextColor3 = color or C.Ink,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = text,
		Parent = toasts,
	}) :: TextLabel
	-- Too many at once: the oldest goes.
	local lines: { TextLabel } = {}
	for _, child in toasts:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(lines, child)
		end
	end
	if #lines > MAX_TOASTS then
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		lines[1]:Destroy()
	end
	Theme.tween(line, Theme.FAST, {
		TextTransparency = 0,
		TextStrokeTransparency = Theme.STROKE_TRANSPARENCY,
	})
	task.delay(TOAST_TIME, function()
		if line.Parent == nil then
			return
		end
		local out = Theme.tween(line, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
		out.Completed:Once(function()
			line:Destroy()
		end)
	end)
end

------------------------------------------------------------------------------
-- The CASE block
------------------------------------------------------------------------------

local function makePip(grade: Types.CoreGrade?, order: number)
	local holder = Theme.make("Frame", {
		Name = "Cradle",
		LayoutOrder = order,
		Size = UDim2.fromOffset(if grade then 26 else 14, 18),
		BackgroundTransparency = 1,
		Parent = pipsRow,
	}) :: Frame
	local diamond = Theme.make("Frame", {
		Name = "Diamond",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(7, 9),
		Size = UDim2.fromOffset(8, 8),
		Rotation = 45,
		BackgroundColor3 = if grade then GRADE_COLOR[grade] else C.Scrim,
		BackgroundTransparency = if grade then 0 else 0.6,
		Parent = holder,
	}) :: Frame
	Theme.make("UIStroke", {
		Thickness = 1,
		Color = if grade then GRADE_COLOR[grade] else C.Ink,
		Transparency = if grade then 0.2 else 0.45,
		Parent = diamond,
	})
	if grade == "A" then
		Theme.make("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new(C.Gold, TEAL),
			Parent = diamond,
		})
	end
	if grade then
		Theme.text({
			Name = "Grade",
			Position = UDim2.fromOffset(15, 0),
			Size = UDim2.fromOffset(10, 18),
			FontFace = Theme.Fonts.NumberMedium,
			TextSize = 11,
			TextColor3 = C.Ink,
			Text = grade,
			Parent = holder,
		})
	end
end

local function redrawCase()
	for _, child in pipsRow:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index = 1, cradles do
		makePip(grades[index], index)
	end
	countLabel.Text = `{#grades}/{cradles}`
	local show = holding and CaseController.isCarrying()
	if show and not caseGroup.Visible then
		caseGroup.Visible = true
		caseGroup.GroupTransparency = 1
		Theme.tween(caseGroup, Theme.NORMAL, { GroupTransparency = 0 })
	elseif not show and caseGroup.Visible then
		caseGroup.Visible = false
		setDownButton.reset()
	end
end

------------------------------------------------------------------------------
-- The CULTURE line
------------------------------------------------------------------------------

local function redrawCulture()
	local state = culture
	-- (above the CASE block while we hold a case, else in its place)
	cultureLabel.Position = UDim2.new(0, 2, 1, if holding then -52 else -16)
	local selling = openingGroup.Visible
	if state == nil or selling or state.stage == "Empty" or state.stage == "Extracting" then
		cultureLabel.Visible = false
		return
	end
	cultureLabel.Visible = true
	if state.stage == "Ready" then
		cultureLabel.Text = "CULTURE READY"
		cultureLabel.TextColor3 = TEAL
		return
	end
	local total = math.max(state.total, 1)
	local grown = state.grown
	if state.running then
		grown += math.max(workspace:GetServerTimeNow() - state.at, 0)
	end
	grown = math.clamp(grown, 0, total)
	local left = math.ceil(total - grown)
	cultureLabel.Text = string.format(
		"CULTURE %d %% · %d:%02d",
		math.floor(grown / total * 100),
		left // 60,
		left % 60
	)
	cultureLabel.TextColor3 = C.Ink2
end

local function hideOpening()
	openingGroup.Visible = false
end

local function showOpening(endsAt: number)
	local left = math.clamp(endsAt - workspace:GetServerTimeNow(), 0, Config.Market.OPEN_TIME + 1)
	openingGroup.Visible = true
	openingGroup.GroupTransparency = 0
	openingFill.Size = UDim2.new(0, 0, 1, 0)
	Theme.tween(openingFill, left, { Size = UDim2.new(1, 0, 1, 0) }, Enum.EasingStyle.Linear)
	task.delay(left + 0.6, function()
		-- (no result came: don't leave the bar up)
		if openingGroup.Visible and openingFill.Size.X.Scale >= 1 then
			hideOpening()
		end
	end)
end

------------------------------------------------------------------------------
-- Server messages
------------------------------------------------------------------------------

local function onContrabandEvent(kind: string, data: any)
	if typeof(data) ~= "table" then
		return
	end
	if kind == "LabState" then
		if
			typeof(data.stage) == "string"
			and typeof(data.grown) == "number"
			and typeof(data.total) == "number"
			and typeof(data.at) == "number"
		then
			culture = data :: Types.LabStatePayload
			redrawCulture()
		end
	elseif kind == "CaseState" then
		holding = data.holding == true
		cradles = if typeof(data.cradles) == "number"
			then math.clamp(math.floor(data.cradles), 0, 3)
			else 0
		local list: { Types.CoreGrade } = {}
		if typeof(data.grades) == "table" then
			for _, grade in data.grades do
				if grade == "A" or grade == "B" or grade == "C" then
					table.insert(list, grade)
				end
			end
		end
		grades = list
		redrawCase()
		redrawCulture()
	elseif kind == "SaleStarted" then
		if typeof(data.endsAt) == "number" then
			showOpening(data.endsAt)
		end
	elseif kind == "SaleResult" then
		hideOpening()
		if data.ok == true then
			local sold = if typeof(data.sold) == "table" then #data.sold else 0
			local coins = if typeof(data.coins) == "number" then math.floor(data.coins) else 0
			toast(`+{coins} · SOLD {sold} {if sold == 1 then "CORE" else "CORES"}`, C.Gold)
		else
			local reason = if typeof(data.reason) == "string" then data.reason else "Try again."
			toast(`SALE FAILED · {reason}`, C.Ink)
		end
	elseif kind == "Notice" then
		if typeof(data.text) == "string" and data.text ~= "" then
			toast(string.sub(data.text, 1, 80))
		end
	end
end

------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------

local function build()
	gui = Theme.make("ScreenGui", {
		Name = "ContrabandHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local block = Theme.make("Frame", {
		Name = "Contraband",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, RIGHT_OFFSET, 1, -44),
		Size = UDim2.fromOffset(BLOCK_WIDTH, BLOCK_HEIGHT),
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: Frame
	Theme.autoScale(block, if Theme.isTouch() then 0.85 else 0.75)

	-- The CASE block, at the bottom. (A CanvasGroup fades it all at once.)
	caseGroup = Theme.make("CanvasGroup", {
		Name = "Case",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = block,
	}) :: CanvasGroup
	local header = Theme.text({
		Name = "Header",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(0, 12),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 10,
		TextColor3 = C.Ink2,
		Text = "CASE",
		Parent = caseGroup,
	}) :: TextLabel
	local hairline = Theme.make("Frame", {
		Name = "Hairline",
		Position = UDim2.fromOffset(40, 8),
		Size = UDim2.new(1, -42, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.84,
		Parent = caseGroup,
	}) :: Frame
	header:GetPropertyChangedSignal("TextBounds"):Connect(function()
		local x = 2 + header.TextBounds.X + 8
		hairline.Position = UDim2.fromOffset(x, 8)
		hairline.Size = UDim2.new(1, -(x + 2), 0, 1)
	end)
	pipsRow = Theme.make("Frame", {
		Name = "Cradles",
		Position = UDim2.fromOffset(2, 22),
		Size = UDim2.fromOffset(90, 22),
		BackgroundTransparency = 1,
		Parent = caseGroup,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	}) :: Frame
	countLabel = Theme.text({
		Name = "Count",
		Position = UDim2.fromOffset(94, 24),
		Size = UDim2.fromOffset(30, 18),
		FontFace = Theme.Fonts.Number,
		TextSize = 12,
		TextColor3 = C.Ink2,
		Text = "0/0",
		Parent = caseGroup,
	}) :: TextLabel
	setDownButton = Button.new({
		name = "SetDown",
		text = "SET DOWN",
		variant = "secondary",
		size = "small",
		keyHint = Config.Controls.CASE_SET_DOWN.Name,
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -2, 0, 21),
		parent = caseGroup,
		onActivated = function()
			CaseController.trySetDown()
		end,
	})

	-- The CULTURE line (moved above the CASE block while we hold a case).
	cultureLabel = Theme.text({
		Name = "Culture",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 2, 1, -16),
		Size = UDim2.new(1, -4, 0, 14),
		FontFace = Theme.Fonts.Number,
		TextSize = 11,
		TextColor3 = C.Ink2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Visible = false,
		Parent = block,
	}) :: TextLabel

	-- The OPENING bar (selling), just above.
	openingGroup = Theme.make("CanvasGroup", {
		Name = "Opening",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -54),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = block,
	}) :: CanvasGroup
	Theme.text({
		Name = "Label",
		Position = UDim2.fromOffset(2, 0),
		Size = UDim2.fromOffset(60, 12),
		TextSize = 10,
		TextColor3 = C.Ink,
		Text = "OPENING",
		Parent = openingGroup,
	})
	local track = Theme.make("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(2, 15),
		Size = UDim2.new(1, -4, 0, 2),
		BackgroundColor3 = C.Plate,
		BackgroundTransparency = 0.2,
		Parent = openingGroup,
	}) :: Frame
	openingFill = Theme.make("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = C.Ink,
		Parent = track,
	}) :: Frame

	-- Toasts, stacked upward above everything, right-aligned.
	toasts = Theme.make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -78),
		Size = UDim2.new(1, -2, 0, 72),
		BackgroundTransparency = 1,
		Parent = block,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
	}) :: Frame
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

local function watchCharacter(character: Model)
	character:GetAttributeChangedSignal("Carrying"):Connect(redrawCase)
	redrawCase()
end

function ContrabandHudController.start()
	build()
	Remotes.ContrabandEvent.OnClientEvent:Connect(onContrabandEvent)
	player.CharacterAdded:Connect(function(character)
		holding = false
		grades = {}
		cradles = 0
		hideOpening()
		watchCharacter(character)
	end)
	if player.Character then
		watchCharacter(player.Character)
	end
	-- The server's first push may have come before we listened: ask again.
	Remotes.ContrabandSync:FireServer()
	-- The culture count-down (no server message needed between two LabStates).
	task.spawn(function()
		while true do
			task.wait(0.5)
			redrawCulture()
		end
	end)
end

return ContrabandHudController
