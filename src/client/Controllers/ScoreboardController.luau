--!strict
-- ScoreboardController: hold Tab to see who is in the server.
--
--                                    P L A Y E R S                8 / 12
--                                    THIS SERVER · THIS SESSION
--                                    #  LV  PLAYER          KILLS  DEATHS
--                                    1  17  Rook_77             9       3
--                                    2  46  Nightjar            7       2
--                                  | 3   8  gifffer             5       2
--                                    ...
--                                    [TAB]  RELEASE TO CLOSE
--
-- • It replaces Roblox's own player list (turned off here).
-- • It opens on the RIGHT, the mirror of the menu on the left, over a dark
--   gradient; the middle of the screen stays free. The kill feed (same
--   corner) hides while it is open; your health and kit stay.
-- • One row per player, best first: most kills, then fewest deaths, then
--   name. Your own row: name in bold white and a small tick on its left.
-- • Numbers are this session only (server attributes "SessionKills",
--   "SessionDeaths", reset when you join) plus each player's "Level".
-- • While it is open, rows slide to their new place when the order
--   changes, and a new kill flashes white for a moment.
-- • Not available while the menu is open.
--
-- Other controllers can follow it (e.g. to hide their own things too):
--   ScoreboardController.isOpen()
--   ScoreboardController.onOpenChanged(function(open: boolean) ... end)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Theme = require(script.Parent.Parent.UI.Theme)
local HudController = require(script.Parent.HudController)
local KillFeedController = require(script.Parent.KillFeedController)
local MenuController = require(script.Parent.MenuController)

local player = Players.LocalPlayer
local C = Theme.Colors

local ROW_HEIGHT = 30
local ROWS_TOP = 83 -- y of the first row inside the board
local FOOTER_GAP = 17 -- between the last row and the "TAB" footer
local BOARD_X = -48 -- right margin of the board
local SLIDE = 16 -- the board slides in from this many pixels to the right
local BOARD_TOP = 44 -- lower when Roblox's top bar has buttons on the right

-- One fading thing: an instance, which transparency property, and its
-- value when fully shown. The whole board fades by tweening these.
type Fade = {
	instance: Instance,
	property: string,
	shown: number,
}

type Row = {
	owner: Player,
	frame: Frame,
	rank: TextLabel,
	level: TextLabel,
	name: TextLabel,
	kills: TextLabel,
	deaths: TextLabel,
	fades: { Fade },
	index: number, -- current place in the list (1 = top)
	lastKills: number,
	connections: { RBXScriptConnection },
}

local ScoreboardController = {}

local gui: ScreenGui
local scrim: Frame
local board: Frame
local boardTop = BOARD_TOP
local rowsFrame: Frame
local footer: Frame
local countNow: TextLabel
local countMax: TextLabel
local boardFades: { Fade } = {} -- title, heads, footer... (not the rows)
local rows: { [Player]: Row } = {}
local open = false
local openChanged = Signal.new() :: Signal.Signal<boolean>

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------

local function numberAttribute(owner: Player, name: string): number
	local value = owner:GetAttribute(name)
	-- Not a number, NaN (value ~= value) or infinite: count it as 0 (a NaN
	-- would break the sort below).
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		return 0
	end
	return value
end

-- A whole number with thin spaces between thousands: 1382 → "1 382"
-- (the house number format, never a comma).
local function formatNumber(value: number): string
	local digits = tostring(math.floor(math.abs(value)))
	local groups = {}
	-- Cut from the right in groups of three digits.
	local stop = #digits
	while stop > 0 do
		table.insert(groups, 1, string.sub(digits, math.max(1, stop - 2), stop))
		stop -= 3
	end
	local out = table.concat(groups, "\u{2009}")
	return if value < 0 then "-" .. out else out
end

-- Remembers how visible `instance` is now (its "shown" value) so the board
-- can fade it out and back in.
local function addFade(list: { Fade }, instance: Instance, property: string)
	table.insert(list, {
		instance = instance,
		property = property,
		shown = (instance :: any)[property],
	})
end

-- Registers a text label (text) or a frame (background) and the outline of
-- a key cap if it has one.
local function trackFade(list: { Fade }, instance: Instance)
	if instance:IsA("TextLabel") then
		addFade(list, instance, "TextTransparency")
		if instance.BackgroundTransparency < 1 then
			addFade(list, instance, "BackgroundTransparency")
		end
	elseif instance:IsA("Frame") and instance.BackgroundTransparency < 1 then
		addFade(list, instance, "BackgroundTransparency")
	elseif instance:IsA("UIStroke") then
		addFade(list, instance, "Transparency")
	end
end

-- Registers `root` and everything inside it.
local function trackAll(list: { Fade }, root: Instance)
	trackFade(list, root)
	for _, child in root:GetDescendants() do
		trackFade(list, child)
	end
end

-- Sets every fade to invisible right away.
local function setInvisible(list: { Fade })
	for _, fade in list do
		(fade.instance :: any)[fade.property] = 1
	end
end

local function fadeIn(list: { Fade }, seconds: number, delay: number?)
	local function play()
		if not open then
			return -- closed again before the delay was over
		end
		for _, fade in list do
			Theme.tween(
				fade.instance,
				seconds,
				{ [fade.property] = fade.shown },
				Enum.EasingStyle.Quart
			)
		end
	end
	if delay and delay > 0 then
		task.delay(delay, play)
	else
		play()
	end
end

local function fadeOut(list: { Fade }, seconds: number)
	for _, fade in list do
		Theme.tween(
			fade.instance,
			seconds,
			{ [fade.property] = 1 },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
	end
end

-- A small grey column head ("KILLS").
local function columnHead(text: string, props: { [string]: any }): TextLabel
	props.Text = Theme.track(text, "three")
	props.TextSize = 9
	props.TextColor3 = C.Ink3
	props.TextStrokeTransparency = 1
	props.Size = props.Size or UDim2.fromOffset(40, 11)
	return Theme.text(props) :: TextLabel
end

------------------------------------------------------------------------------
-- Rows
------------------------------------------------------------------------------

local function rowY(index: number): UDim2
	return UDim2.fromOffset(0, (index - 1) * ROW_HEIGHT)
end

local function buildRow(owner: Player): Row
	local mine = owner == player
	local frame = Theme.make("Frame", {
		Name = "Row_" .. owner.Name,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		Parent = rowsFrame,
	}) :: Frame
	-- Hairline under the row.
	Theme.make("Frame", {
		Name = "Rule",
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.93,
		Parent = frame,
	})
	local rank = Theme.text({
		Name = "Rank",
		Size = UDim2.new(0, 18, 1, 0),
		FontFace = Theme.Fonts.Number,
		TextSize = 10,
		TextColor3 = C.Ink3,
		Text = "",
		Parent = frame,
	}) :: TextLabel
	local level = Theme.text({
		Name = "Lv",
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(0, 28, 1, 0),
		FontFace = Theme.Fonts.Number,
		TextSize = 11,
		TextColor3 = C.Ink2,
		Text = "",
		Parent = frame,
	}) :: TextLabel
	local name = Theme.text({
		Name = "Name",
		Position = UDim2.fromOffset(66, 0),
		Size = UDim2.new(0, 220, 1, 0),
		-- Your own row, the house way (like the kill feed): bold, pure white.
		FontFace = if mine then Theme.Fonts.LabelBold else Theme.Fonts.Label,
		TextSize = 13,
		TextColor3 = if mine then C.InkHi else C.Ink,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = owner.DisplayName,
		Parent = frame,
	}) :: TextLabel
	local kills = Theme.text({
		Name = "Kills",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -90, 0, 0),
		Size = UDim2.new(0, 60, 1, 0),
		FontFace = Theme.Fonts.Number,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = frame,
	}) :: TextLabel
	local deaths = Theme.text({
		Name = "Deaths",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 70, 1, 0),
		FontFace = Theme.Fonts.Number,
		TextSize = 13,
		TextColor3 = C.Ink2,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		Parent = frame,
	}) :: TextLabel
	if mine then
		-- A small tick left of your row (no fill, no box).
		Theme.make("Frame", {
			Name = "Marker",
			Position = UDim2.fromOffset(-14, 9),
			Size = UDim2.fromOffset(2, 12),
			BackgroundColor3 = C.Ink,
			Parent = frame,
		})
	end
	local fades: { Fade } = {}
	trackAll(fades, frame)
	if not open then
		setInvisible(fades)
	end
	return {
		owner = owner,
		frame = frame,
		rank = rank,
		level = level,
		name = name,
		kills = kills,
		deaths = deaths,
		fades = fades,
		index = 0,
		lastKills = numberAttribute(owner, "SessionKills"),
		connections = {},
	}
end

-- Best first: most kills, then fewest deaths, then name.
local function sortedRows(): { Row }
	local list: { Row } = {}
	for _, row in rows do
		table.insert(list, row)
	end
	table.sort(list, function(a, b)
		local killsA = numberAttribute(a.owner, "SessionKills")
		local killsB = numberAttribute(b.owner, "SessionKills")
		if killsA ~= killsB then
			return killsA > killsB
		end
		local deathsA = numberAttribute(a.owner, "SessionDeaths")
		local deathsB = numberAttribute(b.owner, "SessionDeaths")
		if deathsA ~= deathsB then
			return deathsA < deathsB
		end
		local nameA, nameB = string.lower(a.owner.DisplayName), string.lower(b.owner.DisplayName)
		if nameA ~= nameB then
			return nameA < nameB
		end
		return a.owner.UserId < b.owner.UserId
	end)
	return list
end

-- Writes every number and puts the rows in order. While the board is
-- open, rows that move slide to their new place.
local function refresh()
	local list = sortedRows()
	for index, row in list do
		local owner = row.owner
		local kills = numberAttribute(owner, "SessionKills")
		row.rank.Text = tostring(index)
		local level = owner:GetAttribute("Level")
		row.level.Text = if typeof(level) == "number" then tostring(level) else ""
		row.name.Text = owner.DisplayName
		row.kills.Text = formatNumber(kills)
		row.deaths.Text = formatNumber(numberAttribute(owner, "SessionDeaths"))
		if open and kills > row.lastKills then
			-- A new kill: the number flashes white, then settles.
			row.kills.TextColor3 = C.InkHi
			Theme.tween(row.kills, 0.4, { TextColor3 = C.Ink })
		end
		row.lastKills = kills
		if row.index ~= index then
			local first = row.index == 0
			row.index = index
			if open and not first then
				Theme.tween(row.frame, 0.18, { Position = rowY(index) }, Enum.EasingStyle.Quart)
			else
				row.frame.Position = rowY(index)
			end
		end
	end
	-- Player count and the footer under the last row.
	local count = #list
	countNow.Text = tostring(count)
	countMax.Text = " / " .. tostring(Players.MaxPlayers)
	rowsFrame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT * count)
	footer.Position = UDim2.fromOffset(0, ROWS_TOP + ROW_HEIGHT * count + FOOTER_GAP)
end

local function removeRow(owner: Player)
	local row = rows[owner]
	if row == nil then
		return
	end
	rows[owner] = nil
	for _, connection in row.connections do
		connection:Disconnect()
	end
	row.frame:Destroy()
	refresh()
end

local function addRow(owner: Player)
	if rows[owner] then
		return
	end
	local row = buildRow(owner)
	rows[owner] = row
	for _, attribute in { "Level", "SessionKills", "SessionDeaths" } do
		table.insert(row.connections, owner:GetAttributeChangedSignal(attribute):Connect(refresh))
	end
	table.insert(row.connections, owner:GetPropertyChangedSignal("DisplayName"):Connect(refresh))
	refresh()
	if open then
		fadeIn(row.fades, 0.18)
	end
end

------------------------------------------------------------------------------
-- Building the board
------------------------------------------------------------------------------

local function build()
	gui = Theme.make("ScreenGui", {
		Name = "Scoreboard",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		-- Under the HUD (DisplayOrder 0): the kit block (bottom right) stays
		-- crisp on top of the dark gradient.
		DisplayOrder = -1,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Dark gradient on the right, fading out towards the middle.
	scrim = Theme.make("Frame", {
		Name = "SbScrim",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 760, 1, 0),
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = gui,
	}, { Theme.gradient(180, { { 0, 0.14 }, { 0.4, 0.22 }, { 0.7, 0.58 }, { 1, 1 } }) })
	board = Theme.make("Frame", {
		Name = "Board",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, BOARD_X + SLIDE, 0, boardTop),
		Size = UDim2.fromOffset(440, 370),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = gui,
	})
	-- Follows the screen size from its corner (smaller on a phone).
	Theme.autoScale(board, 0.7)
	-- Never under Roblox's top-bar buttons (they'd cover the title).
	Theme.onViewportChanged(function(viewport)
		boardTop = math.max(BOARD_TOP, Theme.topInset("right", viewport) + 8)
		board.Position = UDim2.new(1, board.Position.X.Offset, 0, boardTop)
	end)

	-- Title, player count, subtitle.
	local title = Theme.text({
		Name = "Title",
		Position = UDim2.fromOffset(0, -4),
		Size = UDim2.fromOffset(300, 30),
		FontFace = Theme.Fonts.Display,
		TextSize = 26,
		TextStrokeTransparency = 1,
		Text = Theme.track("PLAYERS", "thin"),
		Parent = board,
	})
	local count = Theme.make("Frame", {
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 13),
		BackgroundTransparency = 1,
		Parent = board,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	countNow = Theme.text({
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 13),
		FontFace = Theme.Fonts.Number,
		TextSize = 11,
		TextStrokeTransparency = 1,
		Text = "",
		Parent = count,
	})
	countMax = Theme.text({
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 13),
		FontFace = Theme.Fonts.Number,
		TextSize = 11,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		Text = "",
		Parent = count,
	})
	local sub = Theme.text({
		Name = "Sub",
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 11),
		TextSize = 9,
		TextColor3 = C.Ink3,
		TextStrokeTransparency = 1,
		Text = Theme.track("THIS SERVER · THIS SESSION", "three"),
		Parent = board,
	})

	-- Column heads, with a hairline under them.
	local head = Theme.make("Frame", {
		Name = "Head",
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Parent = board,
	}, {
		Theme.make("Frame", {
			Name = "Rule",
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.9,
		}),
		columnHead("#", { Position = UDim2.fromOffset(0, 4) }),
		columnHead("LV", { Position = UDim2.fromOffset(30, 4) }),
		columnHead(
			"PLAYER",
			{ Position = UDim2.fromOffset(66, 4), Size = UDim2.fromOffset(120, 11) }
		),
		columnHead("KILLS", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -90, 0, 4),
			Size = UDim2.fromOffset(60, 11),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		columnHead("DEATHS", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 4),
			Size = UDim2.fromOffset(70, 11),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})

	rowsFrame = Theme.make("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(0, ROWS_TOP),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = board,
	})

	-- [TAB]  RELEASE TO CLOSE
	footer = Theme.make("Frame", {
		Name = "Footer",
		Position = UDim2.fromOffset(0, ROWS_TOP + FOOTER_GAP),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		BackgroundTransparency = 1,
		Parent = board,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Theme.keyCap("TAB", { LayoutOrder = 1 }),
		Theme.text({
			Name = "Hint",
			LayoutOrder = 2,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			TextSize = 10,
			TextColor3 = C.Ink2,
			TextStrokeTransparency = 1,
			Text = Theme.track("RELEASE TO CLOSE", "three"),
		}),
	})

	for _, part in { title, count, sub, head, footer } do
		trackAll(boardFades, part)
	end
	setInvisible(boardFades)
end

------------------------------------------------------------------------------
-- Showing / hiding
------------------------------------------------------------------------------

local function setOpen(value: boolean)
	if open == value then
		return
	end
	open = value
	KillFeedController.setHidden(value)
	HudController.setRewardsHidden(value)
	openChanged.fire(value)

	local rowsInOrder = sortedRows()
	if value then
		refresh()
		gui.Enabled = true
		-- Scrim fades in, the board slides in from the right, rows one
		-- after the other.
		scrim.BackgroundTransparency = 1
		Theme.tween(scrim, 0.15, { BackgroundTransparency = 0 })
		board.Position = UDim2.new(1, BOARD_X + SLIDE, 0, boardTop)
		Theme.tween(
			board,
			0.18,
			{ Position = UDim2.new(1, BOARD_X, 0, boardTop) },
			Enum.EasingStyle.Quart
		)
		setInvisible(boardFades)
		fadeIn(boardFades, 0.18)
		for index, row in rowsInOrder do
			setInvisible(row.fades)
			fadeIn(row.fades, 0.18, (index - 1) * 0.02)
		end
	else
		-- The reverse, quicker.
		local quadIn = Enum.EasingDirection.In
		Theme.tween(scrim, 0.1, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, quadIn)
		Theme.tween(
			board,
			0.1,
			{ Position = UDim2.new(1, BOARD_X + SLIDE, 0, boardTop) },
			Enum.EasingStyle.Quad,
			quadIn
		)
		fadeOut(boardFades, 0.1)
		for _, row in rowsInOrder do
			fadeOut(row.fades, 0.1)
		end
		task.delay(0.1, function()
			if not open then
				gui.Enabled = false
			end
		end)
	end
end

-- Tab pressed → open, released → close.
local function onTab(
	_actionName: string,
	state: Enum.UserInputState,
	_input: InputObject
): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		if MenuController.getOpen() ~= nil then
			return Enum.ContextActionResult.Pass -- not while the menu is open
		end
		setOpen(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		setOpen(false)
	end
	return Enum.ContextActionResult.Sink
end

------------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------------

-- Is the scoreboard open right now (Tab held)?
function ScoreboardController.isOpen(): boolean
	return open
end

-- Calls `callback(open)` each time the scoreboard opens or closes.
function ScoreboardController.onOpenChanged(callback: (boolean) -> ()): Signal.Connection
	return openChanged.connect(callback)
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function ScoreboardController.init()
	-- Our board replaces Roblox's player list.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	build()
end

function ScoreboardController.start()
	Players.PlayerAdded:Connect(addRow)
	Players.PlayerRemoving:Connect(removeRow)
	for _, owner in Players:GetPlayers() do
		addRow(owner)
	end
	ContextActionService:BindAction("Scoreboard", onTab, false, Enum.KeyCode.Tab)
	-- The menu opening closes the board.
	MenuController.onOpenChanged(function(id)
		if id ~= nil then
			setOpen(false)
		end
	end)
end

return ScoreboardController
