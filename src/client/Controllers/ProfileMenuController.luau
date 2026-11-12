--!strict
-- ProfileMenuController: the PROFILE section of the menu (02 PROFILE,
-- between KITS and SETTINGS).
--
--   PROFILE                                              820
--   GIFFFER · LIFETIME RECORD                          COINS
--   ──────────────────────────────────────────────────────────
--   LEVEL                                                 XP
--   8  OF 100                                      193 / 257
--   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━──────────────────────
--   64 XP TO LEVEL 9                          TOTAL 1 382 XP
--
--   RECORD
--   KILLS        | DEATHS      | K/D         | WINS
--   64           | 41          | 1.56        | 9
--
--   NEXT UNLOCK                                LEVEL   COINS
--   MMA FIGHTER                                   10     500
--   Clean strikes, then takes it to the ground.
--
-- Everything comes from the save (PlayerDataController): total XP (the
-- level is worked out with Shared/Progression), coins, lifetime stats.
-- The client never computes rewards: it only shows what the server saved.
--
-- Other controllers can use (the KITS header shows the same wallet):
--   ProfileMenuController.createWallet(panel)   "820 / COINS" top-right of a menu panel
--   ProfileMenuController.formatNumber(1382)    "1 382" (thin space, never a comma)
--   ProfileMenuController.countTo(label, from, to, seconds, format)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local ProgressionCurve = require(ReplicatedStorage.Shared.Progression)
local Theme = require(script.Parent.Parent.UI.Theme)
local MenuController = require(script.Parent.MenuController)
local PlayerDataController = require(script.Parent.PlayerDataController)

local player = Players.LocalPlayer
local C = Theme.Colors

local MAX_LEVEL = Config.Progression.MAX_LEVEL
local SECTION_ID = "Profile"
local THIN_SPACE = "\u{2009}"

export type Wallet = {
	-- Shows `coins`. `animate`: the number counts to it (0.4 s) instead of jumping.
	set: (coins: number, animate: boolean) -> (),
}

local ProfileMenuController = {}

------------------------------------------------------------------------------
-- Shared helpers (also used by KitsMenuController)
------------------------------------------------------------------------------

-- 1382 → "1 382": integers, thousands separated by a thin space.
function ProfileMenuController.formatNumber(value: number): string
	local digits = string.format("%d", math.floor(math.abs(value) + 0.5))
	-- Cut the digits in groups of 3 from the right: "1", "382".
	local groups = {}
	local first = #digits % 3
	if first == 0 then
		first = 3
	end
	table.insert(groups, string.sub(digits, 1, first))
	for start = first + 1, #digits, 3 do
		table.insert(groups, string.sub(digits, start, start + 2))
	end
	local sign = if value <= -0.5 then "-" else ""
	return sign .. table.concat(groups, THIN_SPACE)
end

local formatNumber = ProfileMenuController.formatNumber

-- One running count per label (a new count replaces the old one).
local counting: { [TextLabel]: RBXScriptConnection } = {}

-- Makes `label` count from `from` to `to` in `seconds` (Quad Out), the
-- text rebuilt every frame with `format`.
function ProfileMenuController.countTo(
	label: TextLabel,
	from: number,
	to: number,
	seconds: number,
	format: (number) -> string
)
	local previous = counting[label]
	if previous then
		previous:Disconnect()
		counting[label] = nil
	end
	if seconds <= 0 or from == to then
		label.Text = format(to)
		return
	end
	label.Text = format(from)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local alpha = math.min((os.clock() - started) / seconds, 1)
		local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		label.Text = format(from + (to - from) * eased)
		if alpha >= 1 then
			connection:Disconnect()
			if counting[label] == connection then
				counting[label] = nil
			end
		end
	end)
	counting[label] = connection
end

local countTo = ProfileMenuController.countTo

-- The wallet: a big coin count with "COINS" under it, top-right of a menu
-- panel (on the same lines as the panel's title and subtitle).
function ProfileMenuController.createWallet(panel: Instance): Wallet
	local number = Theme.text({
		Name = "WalletNum",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 14),
		Size = UDim2.fromOffset(160, 24),
		FontFace = Theme.Fonts.NumberLight,
		TextSize = 22,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0",
		Parent = panel,
	}) :: TextLabel
	Theme.text({
		Name = "WalletLabel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 52),
		Size = UDim2.fromOffset(160, 12),
		TextSize = 10,
		TextColor3 = C.Ink2, -- it captions a number (like the HEALTH label)
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = Theme.track("COINS", "three"),
		Parent = panel,
	})
	local shown = 0
	return {
		set = function(coins: number, animate: boolean)
			if coins == shown and not animate then
				number.Text = formatNumber(coins)
				return
			end
			countTo(number, shown, coins, if animate then 0.4 else 0, formatNumber)
			shown = coins
		end,
	}
end

------------------------------------------------------------------------------
-- What we show (read from the save)
------------------------------------------------------------------------------

type View = {
	level: number,
	xp: number, -- earned inside the current level
	needed: number, -- the current level needs this much
	totalXp: number,
	coins: number,
	kills: number,
	deaths: number,
	wins: number,
}

local function readView(): View
	local data = PlayerDataController.get()
	local totalXp = if data then data.xp else 0
	local level, xp, needed = ProgressionCurve.levelFromXp(totalXp)
	if data == nil then
		-- The save isn't here yet: show the "Level" attribute (the server
		-- sets it as soon as the save loads), with an empty bar.
		local attribute = player:GetAttribute("Level")
		if typeof(attribute) == "number" then
			level = math.clamp(math.floor(attribute), 1, MAX_LEVEL)
			xp = 0
			needed = ProgressionCurve.xpToNext(level)
		end
	end
	return {
		level = level,
		xp = xp,
		needed = needed,
		totalXp = totalXp,
		coins = if data then data.coins else 0,
		kills = if data then data.stats.kills else 0,
		deaths = if data then data.stats.deaths else 0,
		wins = if data then data.stats.wins else 0,
	}
end

-- The next kit to unlock: the lowest unlockLevel above `level` (or nil).
local function nextUnlock(level: number): Kits.KitDef?
	local best: Kits.KitDef? = nil
	for _, kit in Kits.list() do
		local unlockLevel = kit.unlockLevel
		if kit.available and unlockLevel and unlockLevel > level then
			if best == nil or unlockLevel < (best.unlockLevel or math.huge) then
				best = kit
			end
		end
	end
	return best
end

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

type Cell = {
	value: TextLabel,
	read: (view: View) -> number,
	format: (number) -> string,
	shown: number,
}

local built = false
local body: CanvasGroup -- slides / fades in as one when the section opens
local wallet: Wallet
local levelNum: TextLabel
local levelOf: TextLabel
local xpNums: Frame
local xpNow: TextLabel
local xpNeed: TextLabel
local xpFill: Frame
local fillRatio = 0 -- how full the XP bar should be (0..1)
local toGo: TextLabel
local total: TextLabel
local cells: { Cell } = {}
local nextHead: Frame
local nextRow: Frame
local nextName: TextLabel
local nextSentence: TextLabel
local nextLevel: TextLabel
local nextPrice: TextLabel

-- Small caps text: "LEVEL", "KILLS", "64 XP TO LEVEL 9"...
local function caption(text: string, props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		TextSize = 10,
		TextColor3 = C.Ink3,
		TextStrokeTransparency = 1,
		Text = Theme.track(text, "three"),
	}
	for key, value in props do
		base[key] = value
	end
	return Theme.text(base) :: TextLabel
end

local function hairline(parent: Instance, y: UDim, transparency: number, name: string?)
	Theme.make("Frame", {
		Name = name or "Hairline",
		Position = UDim2.new(UDim.new(0, 0), y),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = transparency,
		Parent = parent,
	})
end

-- A section head: "RECORD" on the left, small column heads on the right,
-- a faint hairline under it. `columns` = { {text, right edge, width} }.
local function sectionHead(parent: Instance, y: number, title: string, columns: { { any } }): Frame
	local head = Theme.make("Frame", {
		Name = `{title}Head`,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	caption(title, { Name = "Label", Size = UDim2.new(1, 0, 0, 12), Parent = head })
	for _, column in columns do
		caption(column[1], {
			Name = "Column",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, column[2], 0, 1),
			Size = UDim2.fromOffset(column[3], 11),
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = head,
		})
	end
	hairline(head, UDim.new(1, 0), 0.9)
	return head
end

local function formatRatio(value: number): string
	return string.format("%.2f", value)
end

local function buildLevel()
	sectionHead(body, 0, "LEVEL", { { "XP", 0, 82 } })
	levelNum = Theme.text({
		Name = "LevelNum",
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.fromOffset(60, 30),
		FontFace = Theme.Fonts.NumberLight,
		TextSize = 30,
		TextStrokeTransparency = 1,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "1",
		Parent = body,
	}) :: TextLabel
	levelOf = caption("OF 100", {
		Name = "LevelOf",
		Position = UDim2.fromOffset(56, 43),
		Size = UDim2.fromOffset(120, 12),
		TextColor3 = C.Ink2,
		Parent = body,
	})
	-- "OF 100" follows the numeral (a fixed spot left a hole after "8").
	local function followNumeral()
		local width = levelNum.TextBounds.X
		if width > 0 then -- 0 = not measured yet (keep the 56 px fallback)
			levelOf.Position = UDim2.fromOffset(width + 14, 43)
		end
	end
	levelNum:GetPropertyChangedSignal("TextBounds"):Connect(followNumeral)
	task.defer(followNumeral) -- once the first text is measured

	xpNums = Theme.make("Frame", {
		Name = "XpNums",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 43),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 12),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame
	local function number(name: string, order: number, color: Color3): TextLabel
		return Theme.text({
			Name = name,
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 12),
			FontFace = Theme.Fonts.Number,
			TextSize = 11,
			TextColor3 = color,
			TextStrokeTransparency = 1,
			Parent = xpNums,
		}) :: TextLabel
	end
	xpNow = number("Now", 1, C.Ink)
	xpNeed = number("Needed", 2, C.Ink2)

	-- The XP bar: the HP bar's look (2 px, faint track, full ink fill).
	local bar = Theme.make("Frame", {
		Name = "XpBar",
		Position = UDim2.fromOffset(0, 68),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.78,
		Parent = body,
	})
	xpFill = Theme.make("Frame", {
		Name = "XpBarFill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Ink,
		Parent = bar,
	}) :: Frame
	toGo = caption("", {
		Name = "ToGo",
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.fromOffset(300, 11),
		TextSize = 9,
		TextColor3 = C.Ink2,
		Parent = body,
	})
	total = caption("", {
		Name = "Total",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 76),
		Size = UDim2.fromOffset(240, 11),
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = body,
	})
end

local function buildRecord()
	sectionHead(body, 118, "RECORD", {})
	local row = Theme.make("Frame", {
		Name = "Cells",
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 1,
		Parent = body,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local definitions: { { any } } = {
		{
			"KILLS",
			function(view: View): number
				return view.kills
			end,
			formatNumber,
		},
		{
			"DEATHS",
			function(view: View): number
				return view.deaths
			end,
			formatNumber,
		},
		{
			"K/D",
			function(view: View): number
				return view.kills / math.max(view.deaths, 1)
			end,
			formatRatio,
		},
		{
			"WINS",
			function(view: View): number
				return view.wins
			end,
			formatNumber,
		},
	}
	for order, definition in definitions do
		local x = if order == 1 then 0 else 20
		local cell = Theme.make("Frame", {
			Name = definition[1],
			LayoutOrder = order,
			Size = UDim2.new(0, 140, 1, 0),
			BackgroundTransparency = 1,
			Parent = row,
		})
		if order > 1 then
			Theme.make("Frame", {
				Name = "LeftRule",
				Size = UDim2.new(0, 1, 1, 0),
				BackgroundColor3 = C.Ink,
				BackgroundTransparency = 0.9,
				Parent = cell,
			})
		end
		caption(definition[1], {
			Name = "Label",
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.new(1, -x, 0, 11),
			TextSize = 9,
			Parent = cell,
		})
		local value = Theme.text({
			Name = "Value",
			Position = UDim2.fromOffset(x, 18),
			Size = UDim2.new(1, -x, 0, 24),
			FontFace = Theme.Fonts.NumberLight,
			TextSize = 22,
			TextStrokeTransparency = 1,
			Text = "0",
			Parent = cell,
		}) :: TextLabel
		table.insert(cells, {
			value = value,
			read = definition[2],
			format = definition[3],
			shown = 0,
		})
	end
end

local function buildNextUnlock()
	nextHead = sectionHead(body, 236, "NEXT UNLOCK", { { "LEVEL", -82, 64 }, { "COINS", 0, 82 } })
	nextRow = Theme.make("Frame", {
		Name = "NextRow",
		Position = UDim2.fromOffset(0, 255),
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
		Parent = body,
	}) :: Frame
	nextName = Theme.text({
		Name = "Name",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(300, 13),
		TextStrokeTransparency = 1,
		Parent = nextRow,
	}) :: TextLabel
	nextSentence = Theme.text({
		Name = "Sentence",
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.fromOffset(380, 14),
		FontFace = Theme.Fonts.Body,
		TextSize = 12,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		Parent = nextRow,
	}) :: TextLabel
	local function column(name: string, right: number, width: number): TextLabel
		return Theme.text({
			Name = name,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, right, 0, 6),
			Size = UDim2.fromOffset(width, 13),
			FontFace = Theme.Fonts.Number,
			TextColor3 = C.Ink2,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = nextRow,
		}) :: TextLabel
	end
	nextLevel = column("Level", -82, 64)
	nextPrice = column("Price", 0, 82)
end

-- Puts the save's numbers on screen. `animate`: the record values count
-- from where they are (used for live updates while the menu is open).
local function refresh(animate: boolean)
	if not built then
		return
	end
	local view = readView()
	wallet.set(view.coins, animate)

	local atMax = view.level >= MAX_LEVEL
	levelNum.Text = tostring(view.level)
	levelOf.Text = Theme.track(if atMax then "MAX LEVEL" else `OF {MAX_LEVEL}`, "three")
	xpNums.Visible = not atMax
	toGo.Visible = not atMax
	xpNow.Text = formatNumber(view.xp)
	xpNeed.Text = " / " .. formatNumber(view.needed)
	toGo.Text =
		Theme.track(`{formatNumber(view.needed - view.xp)} XP TO LEVEL {view.level + 1}`, "three")
	total.Text = Theme.track(`TOTAL {formatNumber(view.totalXp)} XP`, "three")
	fillRatio = if atMax then 1 else math.clamp(view.xp / math.max(view.needed, 1), 0, 1)
	if animate then
		Theme.tween(xpFill, 0.3, { Size = UDim2.fromScale(fillRatio, 1) }, Enum.EasingStyle.Quart)
	else
		-- Set it directly: a 0-second tween only applies on the next frame.
		xpFill.Size = UDim2.fromScale(fillRatio, 1)
	end

	for _, cell in cells do
		local value = cell.read(view)
		if value ~= cell.shown then
			countTo(cell.value, cell.shown, value, if animate then 0.4 else 0, cell.format)
			cell.shown = value
		end
	end

	-- NEXT UNLOCK: hidden (no gap) when there is nothing left to unlock.
	local kit = nextUnlock(view.level)
	nextHead.Visible = kit ~= nil
	nextRow.Visible = kit ~= nil
	if kit then
		nextName.Text = Theme.track(kit.name, "four")
		nextSentence.Text = kit.description
		nextLevel.Text = tostring(kit.unlockLevel or 1)
		nextPrice.Text = formatNumber(kit.price or 0)
	end
end

-- The section opens: the body slides in, the XP bar fills and the record
-- values count up from 0 (one after the other).
local function playEnter()
	if not built then
		return
	end
	refresh(false)
	body.Position = UDim2.fromOffset(-16, 0)
	body.GroupTransparency = 1
	Theme.tween(
		body,
		0.22,
		{ Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 },
		Enum.EasingStyle.Quart
	)

	xpFill.Size = UDim2.fromScale(0, 1)
	Theme.tween(xpFill, 0.6, { Size = UDim2.fromScale(fillRatio, 1) }, Enum.EasingStyle.Quart)

	for order, cell in cells do
		cell.value.Text = cell.format(0)
		task.delay(0.03 * (order - 1), function()
			countTo(cell.value, 0, cell.shown, 0.4, cell.format)
		end)
	end
end

local function build(content: Frame)
	-- The wallet sits in the panel's header (top right), above the content.
	wallet = ProfileMenuController.createWallet(content.Parent :: Instance)
	body = Theme.make("CanvasGroup", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 380),
		BackgroundTransparency = 1,
		Parent = content,
	}) :: CanvasGroup
	buildLevel()
	buildRecord()
	buildNextUnlock()
	built = true
	refresh(false)
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function ProfileMenuController.start()
	MenuController.register({
		id = SECTION_ID,
		label = "PROFILE",
		subtitle = string.upper(player.DisplayName) .. " · LIFETIME RECORD",
		order = 50, -- between KITS (10) and SETTINGS (100)
		size = Vector2.new(560, 480),
		scrimWidth = 1100,
		build = build,
	})
	MenuController.onOpenChanged(function(id)
		if id == SECTION_ID then
			playEnter()
		end
	end)
	-- Live updates while the menu is open (a reward, a kill...).
	PlayerDataController.onChanged(function()
		refresh(MenuController.getOpen() == SECTION_ID)
	end)
	player:GetAttributeChangedSignal("Level"):Connect(function()
		refresh(MenuController.getOpen() == SECTION_ID)
	end)
end

return ProfileMenuController
