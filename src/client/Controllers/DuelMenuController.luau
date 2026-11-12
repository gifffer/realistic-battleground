--!strict
-- DuelMenuController: the DUEL section of the menu (02 DUEL, between KITS
-- and PROFILE).
--
--   DUEL
--   ONE ON ONE · FIRST TO 2 ROUNDS
--   ──────────────────────────────────────────────────────────────────
--   RANKED                                                         ELO
--   SILVER                                                        1112
--   ━━━━━━━━━  ━─────────  ──────────  ──────────  ──────────
--   BRONZE     SILVER 1100  GOLD 1300   PLATINUM 1500  DIAMOND 1700
--   188 TO GOLD · 15 WINS · 9 LOSSES                      — FIND MATCH
--
--   ON THIS SERVER                RANK                      5 PLAYERS
--   17  Rook_77                   GOLD                    — CHALLENGE
--   12  Mara                      SILVER                    IN A DUEL
--   22  Nightjar                  SILVER         CHALLENGE SENT  ·  7
--
-- Top: your ranked standing (ELO from the save, the rank and the ladder
-- from Shared/DuelRanks) and the ranked search: FIND MATCH, then
-- "SEARCHING · 0:23 — CANCEL", then "Waiting for a free arena…".
-- Bottom: every other player on the server, with CHALLENGE or the reason
-- you can't challenge them right now (in a duel, in combat...).
--
-- This controller only DISPLAYS. The duel state (searching, waiting, the
-- challenges you sent, the refusals) belongs to DuelController, the only
-- listener of Remotes.DuelEvent; the buttons call its functions. The
-- server checks everything again (cooldowns, busy players...).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local DuelRanks = require(ReplicatedStorage.Shared.DuelRanks)
local Theme = require(script.Parent.Parent.UI.Theme)
local DuelController = require(script.Parent.DuelController)
local MenuController = require(script.Parent.MenuController)
local PlayerDataController = require(script.Parent.PlayerDataController)
local ProfileMenuController = require(script.Parent.ProfileMenuController)

local player = Players.LocalPlayer
local countTo = ProfileMenuController.countTo

local C = Theme.Colors
local D = Config.Duels

local SECTION_ID = "Duel"

-- The rank ladder: five segments of LADDER_WIDTH px, LADDER_GAP px apart
-- (5 × 108 + 4 × 5 = 560, the panel's width).
local LADDER_WIDTH = 108
local LADDER_GAP = 5
-- BRONZE starts at 0 ELO, but a bar from 0 would always look full: it is
-- drawn from 900. DIAMOND has no next rank: it fills towards 1900.
local BRONZE_FLOOR = 900
local DIAMOND_CEILING = 1900

-- How often the time-based parts (search clock, cooldowns, "in combat")
-- are refreshed while the section is open.
local TICK_SECONDS = 0.25

-- A refused challenge (DuelController.getState().declined), as shown in
-- the row's reason slot for a few seconds. Keys = the server's reasons.
local DECLINED_WORDS: { [string]: string } = {
	["DECLINED"] = "DECLINED",
	["EXPIRED"] = "NO ANSWER",
	["IN A DUEL"] = "IN A DUEL",
	["IN COMBAT"] = "IN COMBAT",
	["BLOCKS DUELS"] = "BLOCKS DUELS",
	["BUSY"] = "ALREADY HAS A REQUEST",
	["COOLDOWN"] = "WAIT A MOMENT",
}

-- What a player's row shows on its right:
--   challenge  the CHALLENGE button
--   disabled   CHALLENGE, dimmed (you are in a duel / waiting for one)
--   sent       "CHALLENGE SENT · 7" (the per-target cooldown)
--   reason     a word: "IN A DUEL", "BLOCKS DUELS", a refusal...
type ActionKind = "challenge" | "disabled" | "sent" | "reason"

type RowView = {
	available: boolean, -- false = busy: the row is drawn one step darker
	kind: ActionKind,
	text: string, -- the reason (kinds "sent" and "reason")
	color: Color3, -- the reason's colour
	seconds: number, -- cooldown left (kind "sent")
}

-- A "— WORD" button (the menu's MENU / EQUIP button), right-aligned.
type LineButton = {
	button: TextButton,
	setEnabled: (enabled: boolean) -> (),
}

type Row = {
	target: Player,
	frame: Frame, -- placed by the list layout
	slide: CanvasGroup, -- fades / slides in as one (inside `frame`)
	level: TextLabel,
	name: TextLabel,
	rank: TextLabel,
	action: CanvasGroup, -- CHALLENGE or the reason (crossfades between them)
	challenge: LineButton,
	reason: Frame,
	reasonWord: TextLabel,
	reasonDot: TextLabel,
	reasonSeconds: TextLabel,
	kind: ActionKind?, -- nil = nothing shown yet
}

-- What the player sees: one group per DuelController mode, crossfaded.
type Mode = "idle" | "searching" | "waiting" | "duel"

-- DuelController's state snapshot (DuelController.getState()).
type DuelState = typeof(DuelController.getState())

type Tier = {
	fill: Frame,
	name: TextLabel,
	min: TextLabel?, -- BRONZE has no minimum shown
}

type Watch = {
	connections: { RBXScriptConnection },
	character: RBXScriptConnection?,
}

local DuelMenuController = {}

local built = false
local body: CanvasGroup -- slides / fades in as one when the section opens
local rankName: TextLabel
local eloNum: TextLabel
local tiers: { Tier } = {}
local modeGroups: { [Mode]: CanvasGroup } = {}
local shownMode: Mode? = nil
local idleText: TextLabel
local searchText: TextLabel
local searchClock: TextLabel
local waitDot: TextLabel -- MATCH FOUND · 12 Vex
local waitOpponent: Frame
local waitLevel: TextLabel
local waitName: TextLabel
local duelText: TextLabel -- IN A DUEL · ROUND 2
local findButton: LineButton
local sweepLine: Frame
local sweep: Frame
local sweepTween: Tween? = nil
local playersCount: TextLabel
local rowsFrame: ScrollingFrame
local emptyText: TextLabel
local rows: { [Player]: Row } = {}

local shownElo: number? = nil -- the number on screen (counts to the new one)
local shownTier = 0 -- the current rank's index on the ladder
local shownFraction = 0 -- how full the current rank's segment is
local ladderElo: number? = nil -- the ELO the ladder was last drawn for

local watched: { [Player]: Watch } = {}
local refreshQueued = false

------------------------------------------------------------------------------
-- Reading the game state
------------------------------------------------------------------------------

local function isOpen(): boolean
	return built and MenuController.getOpen() == SECTION_ID
end

local function numberAttribute(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

-- Your own ELO: the save first (exact), then the "Elo" attribute.
local function ownElo(): number
	local data = PlayerDataController.get()
	if data then
		return data.elo
	end
	return numberAttribute(player, "Elo") or D.START_ELO
end

local function eloOf(target: Player): number
	return numberAttribute(target, "Elo") or D.START_ELO
end

local function levelOf(target: Player): number
	return math.floor(numberAttribute(target, "Level") or 1)
end

local function isKnockedOut(target: Player): boolean
	local character = target.Character
	return character ~= nil and character:GetAttribute("KnockedOut") == true
end

-- "CombatUntil" is a server time (workspace:GetServerTimeNow()).
local function isInCombat(target: Player, now: number): boolean
	local untilTime = numberAttribute(target, "CombatUntil")
	return untilTime ~= nil and untilTime > now
end

-- 83 → "1:23"
local function formatClock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function formatElo(value: number): string
	-- No thousands separator: in the mono font a thin space is a full cell.
	return string.format("%d", math.floor(value + 0.5))
end

local function plural(count: number, one: string, many: string): string
	return string.format("%d %s", count, if count == 1 then one else many)
end

-- How full the current rank's segment is, 0..1 (BRONZE from 900,
-- DIAMOND towards 1900).
local function ladderFraction(progress: DuelRanks.Progress, elo: number): number
	local low = if progress.index == 1 then BRONZE_FLOOR else progress.minElo
	local high = progress.nextMinElo or DIAMOND_CEILING
	return math.clamp((elo - low) / math.max(high - low, 1), 0, 1)
end

------------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------------

-- "Micro": tiny caps, RobotoCondensed Medium 9, wide tracking.
local function micro(text: string, props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		TextSize = 9,
		TextColor3 = C.Ink3,
		TextStrokeTransparency = 1,
		Text = Theme.track(text, "three"),
	}
	for key, value in props do
		base[key] = value
	end
	return Theme.text(base) :: TextLabel
end

-- A horizontal UIListLayout (the menus line up small groups with these).
local function row(
	padding: number,
	horizontal: Enum.HorizontalAlignment?,
	vertical: Enum.VerticalAlignment?
): Instance
	return Theme.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

local function hairline(parent: Instance, y: UDim, transparency: number)
	Theme.make("Frame", {
		Name = "Hairline",
		Position = UDim2.new(UDim.new(0, 0), y),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = transparency,
		Parent = parent,
	})
end

-- A section head: the title on the left, a faint hairline under it.
-- Column heads are added by the caller.
local function sectionHead(parent: Instance, y: number, title: string): Frame
	local head = Theme.make("Frame", {
		Name = "Head",
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	micro(title, {
		Name = "Label",
		Size = UDim2.new(1, 0, 0, 12),
		TextSize = 10, -- "Label" size (the column heads are Micro)
		Parent = head,
	})
	hairline(head, UDim.new(1, 0), 0.9)
	return head
end

-- The menu's "— WORD" button, right-aligned: a short line, then the word.
-- Hover: the line grows from 18 to 28 px and the word lights up.
-- Disabled: everything at 0.65, no hover, presses ignored.
local function lineButton(word: string, props: { [string]: any }, onPress: () -> ()): LineButton
	props.AutomaticSize = Enum.AutomaticSize.X
	props.Size = UDim2.fromOffset(0, 14)
	props.BackgroundTransparency = 1
	props.AutoButtonColor = false
	props.Text = ""
	local button = Theme.make("TextButton", props, {
		row(10, Enum.HorizontalAlignment.Right),
	}) :: TextButton
	local line = Theme.make("Frame", {
		Name = "Line",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(18, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.15,
		Parent = button,
	}) :: Frame
	local label = Theme.text({
		Name = "Label",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		TextTransparency = 0.15,
		TextStrokeTransparency = 1,
		Text = Theme.track(word, "four"),
		Parent = button,
	}) :: TextLabel

	local enabled = true
	local hovered = false
	local function paint(seconds: number)
		local lit = enabled and hovered
		local transparency = if not enabled then 0.65 elseif lit then 0 else 0.15
		local lineSize = UDim2.fromOffset(if lit then 28 else 18, 1)
		if seconds <= 0 then
			-- Set directly: a 0-second tween only applies on the next frame.
			line.Size = lineSize
			line.BackgroundTransparency = transparency
			label.TextTransparency = transparency
			return
		end
		Theme.tween(line, seconds, { Size = lineSize, BackgroundTransparency = transparency })
		Theme.tween(label, seconds, { TextTransparency = transparency })
	end

	button.MouseEnter:Connect(function()
		hovered = true
		if enabled then
			paint(0.15)
		end
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		if enabled then
			paint(0.15)
		end
	end)
	button.Activated:Connect(function()
		if enabled then
			onPress()
		end
	end)

	return {
		button = button,
		setEnabled = function(value: boolean)
			if value == enabled then
				return
			end
			enabled = value
			button.Active = value
			paint(0)
		end,
	}
end

------------------------------------------------------------------------------
-- RANKED block
------------------------------------------------------------------------------

local function buildLadder(parent: Instance)
	local ladder = Theme.make("Frame", {
		Name = "Ladder",
		Position = UDim2.fromOffset(0, 68),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	for index, rank in D.RANKS do
		local x = (index - 1) * (LADDER_WIDTH + LADDER_GAP)
		-- The segment: the HP bar's faint track, with a fill.
		local segment = Theme.make("Frame", {
			Name = `Seg{index}`,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(LADDER_WIDTH, 2),
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.78,
			Parent = ladder,
		})
		local fill = Theme.make("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = C.Ink,
			Parent = segment,
		}) :: Frame
		-- Under it: the tier's name, then its minimum ELO ("SILVER 1100").
		local tier = Theme.make("Frame", {
			Name = `Tier{index}`,
			Position = UDim2.fromOffset(x, 10),
			Size = UDim2.fromOffset(LADDER_WIDTH, 11),
			BackgroundTransparency = 1,
			Parent = ladder,
		}, {
			row(6, nil, Enum.VerticalAlignment.Bottom),
		})
		local name = micro(rank.name, {
			Name = "Name",
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 11),
			Parent = tier,
		})
		local min: TextLabel? = nil
		if index > 1 then
			min = Theme.text({
				Name = "Min",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 11),
				FontFace = Theme.Fonts.Number,
				TextSize = 9,
				TextColor3 = C.Ink3,
				TextStrokeTransparency = 1,
				Text = formatElo(rank.minElo),
				Parent = tier,
			}) :: TextLabel
		end
		table.insert(tiers, { fill = fill, name = name, min = min })
	end
end

-- Colours and fills of the ladder for `elo`. Past tiers: full, half bright.
-- The current one: bright, filled to where you are. Future: empty, dim.
local function drawLadder(elo: number, animate: boolean)
	local progress = DuelRanks.progress(elo)
	local fraction = ladderFraction(progress, elo)
	shownTier = progress.index
	shownFraction = math.max(0.03, fraction)
	for index, tier in tiers do
		local nameColor, minColor = C.Ink3, C.Ink3
		local size, transparency = 0, 0
		if index < progress.index then
			nameColor, minColor = C.Ink2, C.Ink3
			size, transparency = 1, 0.5
		elseif index == progress.index then
			nameColor, minColor = C.Ink, C.Ink2
			size, transparency = shownFraction, 0
		end
		tier.name.TextColor3 = nameColor
		local min = tier.min
		if min then
			min.TextColor3 = minColor
		end
		tier.fill.BackgroundTransparency = transparency
		local target = UDim2.fromScale(size, 1)
		if animate and tier.fill.Size ~= target then
			Theme.tween(tier.fill, 0.6, { Size = target }, Enum.EasingStyle.Quart)
		else
			tier.fill.Size = target
		end
	end
end

-- One group per mode, all in the same row; only the current one shows.
local function modeGroup(parent: Instance, mode: Mode): CanvasGroup
	local group = Theme.make("CanvasGroup", {
		Name = mode,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = parent,
	}) :: CanvasGroup
	modeGroups[mode] = group
	return group
end

-- The left-hand line of the action row (Micro, ink-2).
local function leftLine(parent: Instance): TextLabel
	return micro("", {
		Name = "Left",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromOffset(340, 11),
		TextColor3 = C.Ink2,
		Parent = parent,
	})
end

-- The right-hand side of the action row: a group aligned on the right.
local function rightGroup(parent: Instance, padding: number): Frame
	return Theme.make("Frame", {
		Name = "Right",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 3),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		row(padding, Enum.HorizontalAlignment.Right),
	}) :: Frame
end

-- "SEARCHING", "MATCH FOUND": Label size, bright.
local function statusWord(parent: Instance, text: string, order: number): TextLabel
	return micro(text, {
		Name = "Word",
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		TextSize = 10,
		TextColor3 = C.Ink,
		Parent = parent,
	})
end

local function dot(parent: Instance, order: number, size: number): TextLabel
	return Theme.text({
		Name = "Dot",
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		TextSize = size,
		TextColor3 = C.Ink3,
		TextStrokeTransparency = 1,
		Text = "·",
		Parent = parent,
	}) :: TextLabel
end

local function buildActionRow(parent: Instance)
	local actionRow = Theme.make("Frame", {
		Name = "ActionRow",
		Position = UDim2.fromOffset(0, 108),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Parent = parent,
	})

	-- Idle: "188 TO GOLD · 15 WINS · 9 LOSSES"   — FIND MATCH
	local idle = modeGroup(actionRow, "idle")
	idleText = leftLine(idle)
	findButton = lineButton("FIND MATCH", {
		Name = "FindMatch",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 3),
		Parent = idle,
	}, function()
		DuelController.findMatch()
	end)

	-- Searching: "MATCHING WITHIN ±200 ELO"   SEARCHING · 0:23   — CANCEL
	local searching = modeGroup(actionRow, "searching")
	searchText = leftLine(searching)
	local searchRight = rightGroup(searching, 28)
	local status = Theme.make("Frame", {
		Name = "Status",
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		BackgroundTransparency = 1,
		Parent = searchRight,
	}, {
		row(8),
	})
	statusWord(status, "SEARCHING", 1)
	dot(status, 2, 11)
	searchClock = Theme.text({
		Name = "Clock",
		LayoutOrder = 3,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		FontFace = Theme.Fonts.Number,
		TextSize = 11,
		TextStrokeTransparency = 1,
		Text = "0:00",
		Parent = status,
	}) :: TextLabel
	lineButton("CANCEL", {
		Name = "Cancel",
		LayoutOrder = 2,
		Parent = searchRight,
	}, function()
		DuelController.cancelSearch()
	end)

	-- Waiting (a match was found, every arena is busy).
	local waiting = modeGroup(actionRow, "waiting")
	Theme.text({
		Name = "Left",
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.fromOffset(340, 14),
		FontFace = Theme.Fonts.Body,
		TextSize = 12,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		Text = "Waiting for a free arena…",
		Parent = waiting,
	})
	-- MATCH FOUND · 12 Vex (the opponent, or the challenger you accepted).
	local waitRight = rightGroup(waiting, 8)
	statusWord(waitRight, "MATCH FOUND", 1)
	waitDot = dot(waitRight, 2, 11)
	waitOpponent = Theme.make("Frame", {
		Name = "Opponent",
		LayoutOrder = 3,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16),
		BackgroundTransparency = 1,
		Parent = waitRight,
	}, {
		row(5, nil, Enum.VerticalAlignment.Bottom),
	}) :: Frame
	waitLevel = Theme.text({
		Name = "Lv",
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 13),
		FontFace = Theme.Fonts.Number,
		TextSize = 10,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		Parent = waitOpponent,
	}) :: TextLabel
	waitName = Theme.text({
		Name = "Name",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16),
		TextSize = 13,
		TextStrokeTransparency = 1,
		Parent = waitOpponent,
	}) :: TextLabel

	-- In a duel (or on its result screen): "IN A DUEL · ROUND 2".
	local duel = modeGroup(actionRow, "duel")
	duelText = leftLine(duel)

	-- The sweep: a short line crossing the hairline again and again while
	-- the server works (searching / waiting). No spinner.
	sweepLine = Theme.make("Frame", {
		Name = "SweepLine",
		Position = UDim2.fromOffset(0, 132),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.9,
		ClipsDescendants = true,
		Visible = false,
		Parent = parent,
	}) :: Frame
	sweep = Theme.make("Frame", {
		Name = "Sweep",
		Position = UDim2.fromOffset(-64, 0),
		Size = UDim2.fromOffset(64, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.3,
		Parent = sweepLine,
	}) :: Frame
end

local function buildRanked(parent: Instance)
	local head = sectionHead(parent, 0, "RANKED")
	micro("ELO", {
		Name = "Column",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 1),
		Size = UDim2.fromOffset(64, 11),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = head,
	})
	rankName = Theme.text({
		Name = "RankName",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.fromOffset(300, 30),
		FontFace = Theme.Fonts.Display,
		TextSize = 26,
		TextStrokeTransparency = 1,
		Parent = parent,
	}) :: TextLabel
	eloNum = Theme.text({
		Name = "EloNum",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 27),
		Size = UDim2.fromOffset(120, 28),
		FontFace = Theme.Fonts.NumberLight,
		TextSize = 22,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = parent,
	}) :: TextLabel
	buildLadder(parent)
	buildActionRow(parent)
end

-- The sweep loops only while it is visible.
local function setSweep(on: boolean)
	sweepLine.Visible = on
	if on and sweepTween == nil then
		sweep.Position = UDim2.fromOffset(-64, 0)
		local tween = TweenService:Create(
			sweep,
			TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false),
			{ Position = UDim2.fromScale(1, 0) }
		)
		tween:Play()
		sweepTween = tween
	elseif not on and sweepTween then
		sweepTween:Cancel()
		sweepTween = nil
	end
end

-- Shows the group of `mode`. Animated: the old one fades out (0.1 s), the
-- new one fades in while sliding 8 px from the right (0.15 s).
local function setMode(mode: Mode, animate: boolean)
	setSweep(mode == "searching" or mode == "waiting")
	if mode == shownMode then
		return
	end
	local previous = if shownMode then modeGroups[shownMode] else nil
	shownMode = mode
	local group = modeGroups[mode]
	if previous then
		if animate then
			Theme.tween(
				previous,
				0.1,
				{ GroupTransparency = 1 },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			task.delay(0.1, function()
				if modeGroups[shownMode :: Mode] ~= previous then
					previous.Visible = false
				end
			end)
		else
			previous.GroupTransparency = 1
			previous.Visible = false
		end
	end
	group.Visible = true
	if animate then
		group.GroupTransparency = 1
		group.Position = UDim2.fromOffset(8, 0)
		Theme.tween(
			group,
			0.15,
			{ GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) },
			Enum.EasingStyle.Quart
		)
	else
		group.GroupTransparency = 0
		group.Position = UDim2.fromOffset(0, 0)
	end
end

local function refreshRanked(animate: boolean)
	local elo = ownElo()
	local progress = DuelRanks.progress(elo)
	rankName.Text = Theme.track(progress.rank, "thin")
	if shownElo ~= elo then
		countTo(eloNum, shownElo or elo, elo, if animate and shownElo then 0.4 else 0, formatElo)
		shownElo = elo
	end
	-- Only redrawn when the ELO changes (the 0.25 s tick must not restart
	-- the fill's tween while it plays).
	if ladderElo ~= elo or not animate then
		ladderElo = elo
		drawLadder(elo, animate)
	end

	-- Idle line: what is left to the next rank, then the ranked record.
	local data = PlayerDataController.get()
	local wins = if data then data.rankedWins else 0
	local losses = if data then data.rankedLosses else 0
	local nextRank, nextMin = progress.nextRank, progress.nextMinElo
	local goal = if nextRank and nextMin
		then `{formatElo(nextMin - elo)} TO {nextRank}`
		else "TOP RANK"
	idleText.Text = Theme.track(
		`{goal} · {plural(wins, "WIN", "WINS")} · {plural(losses, "LOSS", "LOSSES")}`,
		"three"
	)

	local info = DuelController.getState()
	local mode: Mode = info.mode
	if mode == "searching" then
		-- The server accepts a wider ELO gap every 5 s of waiting.
		local now = workspace:GetServerTimeNow()
		local waited = math.max(0, now - (info.searchingSince or now))
		local range = D.MATCH_RANGE + D.MATCH_RANGE_GROWTH * math.floor(waited / 5)
		searchText.Text = Theme.track(`MATCHING WITHIN ±{range} ELO`, "three")
		searchClock.Text = formatClock(waited)
	elseif mode == "waiting" then
		local opponentId = info.opponent
		local opponent = if opponentId then Players:GetPlayerByUserId(opponentId) else nil
		-- The opponent may have left already (the server then drops the match).
		waitDot.Visible = opponent ~= nil
		waitOpponent.Visible = opponent ~= nil
		if opponent then
			waitLevel.Text = tostring(levelOf(opponent))
			waitName.Text = opponent.DisplayName -- as typed
		end
	elseif mode == "duel" then
		duelText.Text = Theme.track(
			if info.round > 0 then `IN A DUEL · ROUND {info.round}` else "IN A DUEL",
			"three"
		)
	end
	-- Searching does not block challenges; a duel and its arena wait do.
	findButton.setEnabled(player:GetAttribute("InDuel") ~= true)
	setMode(mode, animate)
end

------------------------------------------------------------------------------
-- ON THIS SERVER: the players list
------------------------------------------------------------------------------

local function buildPlayers(parent: Instance)
	local head = sectionHead(parent, 158, "ON THIS SERVER")
	micro("RANK", {
		Name = "RankColumn",
		Position = UDim2.fromOffset(300, 1),
		Size = UDim2.fromOffset(100, 11),
		Parent = head,
	})
	playersCount = micro("", {
		Name = "CountColumn",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 1),
		Size = UDim2.fromOffset(120, 11),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = head,
	})
	rowsFrame = Theme.make("ScrollingFrame", {
		Name = "Rows",
		Position = UDim2.fromOffset(0, 177),
		Size = UDim2.new(1, 0, 0, 180),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 1,
		ScrollBarImageColor3 = C.Ink,
		ScrollBarImageTransparency = 0.6,
		Parent = parent,
	}, {
		Theme.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	}) :: ScrollingFrame
	emptyText = Theme.text({
		Name = "Empty",
		Position = UDim2.fromOffset(0, 185),
		Size = UDim2.fromOffset(400, 14),
		FontFace = Theme.Fonts.Body,
		TextSize = 12,
		TextColor3 = C.Ink3,
		TextStrokeTransparency = 1,
		Text = "Nobody else on this server yet.",
		Visible = false,
		Parent = parent,
	}) :: TextLabel
end

local function createRow(target: Player): Row
	local frame = Theme.make("Frame", {
		Name = target.Name,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = rowsFrame,
	}) :: Frame
	local slide = Theme.make("CanvasGroup", {
		Name = "Slide",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = frame,
	}) :: CanvasGroup
	hairline(slide, UDim.new(1, -1), 0.93)
	local level = Theme.text({
		Name = "Lv",
		Size = UDim2.new(0, 28, 1, 0),
		FontFace = Theme.Fonts.Number,
		TextSize = 11,
		TextStrokeTransparency = 1,
		Parent = slide,
	}) :: TextLabel
	local name = Theme.text({
		Name = "Name",
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(0, 250, 1, 0),
		TextSize = 13,
		TextStrokeTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = slide,
	}) :: TextLabel
	local rank = Theme.text({
		Name = "Rank",
		Position = UDim2.fromOffset(300, 0),
		Size = UDim2.new(0, 110, 1, 0),
		TextSize = 10,
		TextStrokeTransparency = 1,
		Parent = slide,
	}) :: TextLabel
	local action = Theme.make("CanvasGroup", {
		Name = "Action",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 170, 1, 0),
		BackgroundTransparency = 1,
		Parent = slide,
	}) :: CanvasGroup
	local challenge = lineButton("CHALLENGE", {
		Name = "Challenge",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Visible = false,
		Parent = action,
	}, function()
		-- DuelController sends it and remembers the cooldown; its change
		-- signal refreshes this row to "CHALLENGE SENT · 10".
		DuelController.challenge(target.UserId)
	end)
	local reason = Theme.make("Frame", {
		Name = "Reason",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = action,
	}, {
		row(6, Enum.HorizontalAlignment.Right),
	}) :: Frame
	local reasonWord = micro("", {
		Name = "Word",
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = reason,
	})
	local reasonDot = dot(reason, 2, 10)
	local reasonSeconds = Theme.text({
		Name = "Seconds",
		LayoutOrder = 3,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		FontFace = Theme.Fonts.Number,
		TextSize = 10,
		TextStrokeTransparency = 1,
		Parent = reason,
	}) :: TextLabel
	return {
		target = target,
		frame = frame,
		slide = slide,
		level = level,
		name = name,
		rank = rank,
		action = action,
		challenge = challenge,
		reason = reason,
		reasonWord = reasonWord,
		reasonDot = reasonDot,
		reasonSeconds = reasonSeconds,
		kind = nil,
	}
end

-- The row's entrance: from the left and from transparent (0.2 s).
local function animateRowIn(entry: Row, delaySeconds: number)
	entry.slide.GroupTransparency = 1
	entry.slide.Position = UDim2.fromOffset(-8, 0)
	task.delay(delaySeconds, function()
		if entry.frame.Parent == nil then
			return
		end
		Theme.tween(
			entry.slide,
			0.2,
			{ GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) },
			Enum.EasingStyle.Quart
		)
	end)
end

-- What `target`'s row shows (the first reason that applies wins).
local function rowView(
	target: Player,
	state: DuelState,
	now: number,
	selfBusy: boolean,
	selfInCombat: boolean
): RowView
	local view: RowView = {
		available = false,
		kind = "reason",
		text = "",
		color = C.Ink3,
		seconds = 0,
	}
	local refusal = state.declined[target.UserId]
	if refusal then
		-- Your challenge was just refused: say why (for a few seconds).
		view.available = true
		view.text = DECLINED_WORDS[refusal] or refusal
		view.color = C.Ink2
	elseif target:GetAttribute("InDuel") == true then
		view.text = "IN A DUEL"
	elseif isKnockedOut(target) then
		view.text = "KNOCKED OUT"
	elseif selfInCombat or isInCombat(target, now) then
		view.text = "IN COMBAT"
	elseif target:GetAttribute("BlocksDuels") == true then
		view.text = "BLOCKS DUELS"
	else
		view.available = true
		-- `sent`: the server time the cooldown on them ends.
		local cooldownEnd = state.sent[target.UserId]
		if cooldownEnd and cooldownEnd > now then
			view.kind = "sent"
			view.text = "CHALLENGE SENT"
			view.color = C.Ink2
			view.seconds = math.ceil(cooldownEnd - now)
		elseif selfBusy then
			view.kind = "disabled"
		else
			view.kind = "challenge"
		end
	end
	return view
end

local function isButtonKind(kind: ActionKind?): boolean
	return kind == "challenge" or kind == "disabled"
end

local function applyRow(entry: Row, view: RowView)
	local target = entry.target
	-- Busy rows are one step darker: the list reads by brightness.
	entry.level.Text = tostring(levelOf(target))
	entry.level.TextColor3 = if view.available then C.Ink2 else C.Ink3
	entry.name.Text = target.DisplayName -- as typed, never re-cased
	entry.name.TextColor3 = if view.available then C.Ink else C.Ink2
	entry.rank.Text = Theme.track(DuelRanks.rankOf(eloOf(target)), "three")
	entry.rank.TextColor3 = if view.available then C.Ink2 else C.Ink3

	local previous: ActionKind? = entry.kind
	local wasButton = isButtonKind(previous)
	local changed = previous ~= nil and previous ~= view.kind
	entry.kind = view.kind
	local showButton = isButtonKind(view.kind)
	entry.challenge.button.Visible = showButton
	entry.challenge.setEnabled(view.kind == "challenge")
	entry.reason.Visible = not showButton
	if not showButton then
		entry.reasonWord.Text = Theme.track(view.text, "three")
		entry.reasonWord.TextColor3 = view.color
		local sent = view.kind == "sent"
		entry.reasonDot.Visible = sent
		entry.reasonSeconds.Visible = sent
		entry.reasonSeconds.Text = string.format("%d", view.seconds)
	end
	-- The button turned into a reason (or back): quick crossfade.
	if changed and not (wasButton and showButton) then
		entry.action.GroupTransparency = 1
		Theme.tween(entry.action, 0.1, { GroupTransparency = 0 })
	end
end

-- Adds / removes rows so there is one per other player.
-- Returns the rows that were just created.
local function syncRows(): { Row }
	-- A leaving player is still in Players during PlayerRemoving: the rows
	-- follow `watched` (cleared at PlayerRemoving) instead.
	for target, entry in rows do
		if watched[target] == nil or target.Parent ~= Players then
			entry.frame:Destroy()
			rows[target] = nil
		end
	end
	local created = {}
	for _, target in Players:GetPlayers() do
		if target ~= player and watched[target] ~= nil and rows[target] == nil then
			local entry = createRow(target)
			rows[target] = entry
			table.insert(created, entry)
		end
	end
	return created
end

type Sorted = { entry: Row, view: RowView, level: number }

-- Updates every row and puts them in order: available first, then the
-- highest level, then by name.
local function refreshRows(animate: boolean)
	local created = syncRows()
	local state = DuelController.getState()
	local mode: Mode = state.mode
	local now = workspace:GetServerTimeNow()
	-- You can't challenge anyone while in a duel, waiting for an arena or
	-- knocked out (the server would refuse it).
	local selfBusy = player:GetAttribute("InDuel") == true
		or mode == "waiting"
		or mode == "duel"
		or isKnockedOut(player)
	local selfInCombat = isInCombat(player, now)

	local list: { Sorted } = {}
	for target, entry in rows do
		table.insert(list, {
			entry = entry,
			view = rowView(target, state, now, selfBusy, selfInCombat),
			level = levelOf(target),
		})
	end
	table.sort(list, function(a: Sorted, b: Sorted): boolean
		if a.view.available ~= b.view.available then
			return a.view.available
		end
		if a.level ~= b.level then
			return a.level > b.level
		end
		local nameA, nameB = a.entry.target.DisplayName, b.entry.target.DisplayName
		if nameA ~= nameB then
			return nameA < nameB
		end
		return a.entry.target.UserId < b.entry.target.UserId
	end)
	for order, item in list do
		item.entry.frame.LayoutOrder = order
		applyRow(item.entry, item.view)
	end

	playersCount.Text = Theme.track(plural(#list, "PLAYER", "PLAYERS"), "three")
	emptyText.Visible = #list == 0
	if animate then
		for _, entry in created do
			animateRowIn(entry, 0)
		end
	end
end

------------------------------------------------------------------------------
-- Refreshing
------------------------------------------------------------------------------

-- `animate`: live update while the section is open (the ELO counts, the
-- ladder slides, the action row crossfades, new rows slide in).
local function refresh(animate: boolean)
	if not built then
		return
	end
	refreshRanked(animate)
	refreshRows(animate)
end

-- Many signals can fire in the same frame: refresh once, at the end of it.
-- Nothing is updated while the section is closed (it refreshes on open).
local function requestRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		if isOpen() then
			refresh(true)
		end
	end)
end

-- The section opens: the body slides in, the current rank's segment fills,
-- the rows come in one after the other.
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

	local tier = tiers[shownTier]
	if tier then
		tier.fill.Size = UDim2.fromScale(0, 1)
		Theme.tween(
			tier.fill,
			0.6,
			{ Size = UDim2.fromScale(shownFraction, 1) },
			Enum.EasingStyle.Quart
		)
	end

	local ordered = {}
	for _, entry in rows do
		table.insert(ordered, entry)
	end
	table.sort(ordered, function(a: Row, b: Row): boolean
		return a.frame.LayoutOrder < b.frame.LayoutOrder
	end)
	for order, entry in ordered do
		animateRowIn(entry, 0.03 * (order - 1))
	end
end

local function build(content: Frame)
	body = Theme.make("CanvasGroup", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = content,
	}) :: CanvasGroup
	buildRanked(body)
	buildPlayers(body)
	built = true
	refresh(false)
end

------------------------------------------------------------------------------
-- Watching the players (attributes the rows depend on)
------------------------------------------------------------------------------

local WATCHED_ATTRIBUTES = { "InDuel", "InQueue", "BlocksDuels", "Elo", "Level", "CombatUntil" }

local function watch(target: Player)
	if watched[target] then
		return
	end
	local record: Watch = { connections = {}, character = nil }
	watched[target] = record
	for _, attribute in WATCHED_ATTRIBUTES do
		table.insert(
			record.connections,
			target:GetAttributeChangedSignal(attribute):Connect(requestRefresh)
		)
	end
	table.insert(
		record.connections,
		target:GetPropertyChangedSignal("DisplayName"):Connect(requestRefresh)
	)
	-- "KnockedOut" lives on the character: follow each new one.
	local function onCharacter(character: Model)
		local old = record.character
		if old then
			old:Disconnect()
		end
		record.character = character:GetAttributeChangedSignal("KnockedOut"):Connect(requestRefresh)
		requestRefresh()
	end
	table.insert(record.connections, target.CharacterAdded:Connect(onCharacter))
	if target.Character then
		onCharacter(target.Character)
	end
	requestRefresh()
end

local function unwatch(target: Player)
	local record = watched[target]
	if record == nil then
		return
	end
	watched[target] = nil
	for _, connection in record.connections do
		connection:Disconnect()
	end
	local characterConnection = record.character
	if characterConnection then
		characterConnection:Disconnect()
	end
	requestRefresh()
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function DuelMenuController.start()
	MenuController.register({
		id = SECTION_ID,
		label = "DUEL",
		subtitle = "ONE ON ONE · FIRST TO 2 ROUNDS",
		order = 30, -- between KITS (10) and PROFILE (50)
		size = Vector2.new(560, 480),
		scrimWidth = 1100,
		build = build,
	})
	MenuController.onOpenChanged(function(id)
		if id == SECTION_ID then
			playEnter()
		elseif built then
			-- Section hidden: stop the looping sweep (refresh restarts it).
			setSweep(false)
		end
	end)

	-- Searching, waiting, challenges sent, refusals...
	DuelController.onChanged(function()
		requestRefresh()
	end)
	-- ELO and ranked record (the save).
	PlayerDataController.onChanged(function()
		requestRefresh()
	end)

	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(unwatch)
	for _, target in Players:GetPlayers() do
		watch(target)
	end

	-- Time-based parts: the search clock, the cooldowns, "in combat".
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			if isOpen() then
				refresh(true)
			end
		end
	end)
end

return DuelMenuController
