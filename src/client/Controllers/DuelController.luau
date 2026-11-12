--!strict
-- DuelController: everything about duels that you see WHILE PLAYING.
-- (The DUEL section of the menu is DuelMenuController's job: it reads the
-- state from here, see "Public API" below.)
--
--   DUEL REQUEST · BEST OF 3                   the challenge prompt: left
--   7  Rook_77 challenges you to a duel        edge, under the MENU button.
--   [Y] ACCEPT    [N] DECLINE                  Y / N (or a click). The
--   ────────────────────────  12               hairline is the 15 s left.
--
--          RANKED · ROUND 2 · BEST OF 3        in a duel, top centre:
--               YOU 1 — 0                      the score (yours on the left),
--     12 Vex                         46        the opponent's level, name
--     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━       and health
--
--   3 · 2 · 1 · FIGHT                          round start (upper third)
--   ROUND 1 — YOU   /   ROUND 1 — Vex          round end
--   VICTORY / DEFEAT                           the result: score, rewards,
--                                              ELO, rank up, then back
--
-- Also: "Vex declined" (the challenger's notice, same slot as the prompt)
-- and, menu closed, a status line under MENU while you search a ranked
-- match ("RANKED · SEARCHING 0:23") or wait for a free arena.
--
-- Nothing here decides anything: the server (Server/Systems/Duels) runs the
-- duels and tells us what happens through Remotes.DuelEvent (this is its
-- ONLY listener). The kinds and their data are listed in Shared/Types
-- (DuelEventKind). Design: docs/ui (duel SPEC, editorial / film).
--
-- Public API (for DuelMenuController and the others):
--   DuelController.getState()   a snapshot (DuelInfo):
--       mode            "idle" | "searching" | "waiting" | "duel" (the menu's four looks)
--       phase           "Idle" | "Searching" | "Waiting" | "InMatch" | "Result"
--       searchingSince  server time the ranked search started (nil if not searching)
--       opponent, ranked, round, scoreMine, scoreTheirs
--       sent            { [UserId] = server time when you may challenge them again }
--       declined        { [UserId] = reason } refusals of the last 3 s ("DECLINED"...)
--   DuelController.getPhase()             just the phase
--   DuelController.onChanged(cb)          cb(phase) on every change (also: a challenge
--   DuelController.onStateChanged(cb)     sent, a refusal received...); same signal
--   DuelController.challenge(userId)      challenge someone (remembers it for the countdown)
--   DuelController.getChallengeCooldown(userId)   seconds before you can challenge them again
--   DuelController.getDeclined(userId)    the last refusal from them, for 3 s (else nil)
--   DuelController.declinedSentence(reason, name)   "Vex declined", "Vex is in combat"...
--   DuelController.findMatch() / cancelSearch()     ranked queue
--   DuelController.getSearchTime() / getSearchRange()   seconds searched / ELO range accepted

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local DuelRanks = require(ReplicatedStorage.Shared.DuelRanks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Theme = require(script.Parent.Parent.UI.Theme)
local HudController = require(script.Parent.HudController)
local MenuController = require(script.Parent.MenuController)
local PlayerDataController = require(script.Parent.PlayerDataController)

local player = Players.LocalPlayer
local C = Theme.Colors
local F = Theme.Fonts
local D = Config.Duels

-- Roboto Medium: only for a name inside a sentence ("Rook_77 challenges you").
local ROBOTO_MEDIUM = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Medium)

local QUAD = Enum.EasingStyle.Quad
local QUART = Enum.EasingStyle.Quart
local LINEAR = Enum.EasingStyle.Linear
local IN = Enum.EasingDirection.In
local IN_OUT = Enum.EasingDirection.InOut

-- Above the menu (10): the prompt stays visible and clickable with it open.
local DISPLAY_ORDER = 11

-- Challenge prompt (left edge, under MENU).
local PROMPT_X = 48
local PROMPT_Y = 24 -- from the middle of the screen
local TIMER_WIDTH = 240 -- the width of the vitals
local NOTICE_LIFE = 3 -- "Vex declined" stays this long
local DECLINED_SHOW = 3 -- the menu row shows the refusal this long

-- In-duel block (top centre) and round beats.
local TOP_Y = 28
local OPP_WIDTH = 360
local GHOST_DELAY = 0.35 -- the opponent's red damage sliver waits, then drains
local NUM_Y = 20
local RULE_WIDTH = 120
local END_TITLE_Y = 20

-- Result.
local BAR_HEIGHT = 64
local RES_ROW = 34
local LADDER_WIDTH = 92 -- one tier of the rank ladder in the result
local LADDER_GAP = 5
local LADDER_FLOOR = 900 -- BRONZE is drawn from here
local LADDER_TOP = 1900 -- DIAMOND fills towards here, then stays full

-- The rest of the fight HUD hidden during the result (like the KO screen).
-- The vitals (HudController) have their own switch: HudController.setHidden.
local HUD_GUIS = { "KitHud", "KillFeed", "Crosshair" }

export type DuelState = "Idle" | "Searching" | "Waiting" | "InMatch" | "Result"
export type DuelMode = "idle" | "searching" | "waiting" | "duel"

export type DuelInfo = {
	mode: DuelMode,
	phase: DuelState,
	searchingSince: number?, -- server time (workspace:GetServerTimeNow())
	opponent: number?, -- UserId (Waiting, InMatch, Result)
	ranked: boolean,
	round: number,
	scoreMine: number,
	scoreTheirs: number,
	sent: { [number]: number }, -- UserId → server time the cooldown on them ends
	declined: { [number]: string }, -- UserId → reason (refusals of the last 3 s)
}

export type Declined = {
	reason: string, -- "DECLINED", "EXPIRED", "IN A DUEL", "IN COMBAT", "BLOCKS DUELS", "BUSY", "COOLDOWN"
	name: string,
	at: number, -- os.clock() when it arrived
}

type Ladder = {
	fills: { Frame },
	names: { TextLabel },
}

local DuelController = {}

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

local state: DuelState = "Idle"
local searchingSince: number? = nil
local opponentId: number? = nil
-- The opponent's name and level, remembered when the match is set: if they
-- leave mid-duel (forfeit) the result still names them.
local opponentName = "Opponent"
local opponentLevel: number? = nil
local ranked = false
local round = 0
local scoreMine = 0
local scoreTheirs = 0
local sentAt: { [number]: number } = {} -- UserId → server time of our challenge
local declined: { [number]: Declined } = {}
local changed = Signal.new() :: Signal.Signal<DuelState>

-- Each running animation has a "token": starting a new one bumps it, and
-- the delayed steps of the old one see it changed and do nothing.
local tokens: { [string]: number } =
	{ prompt = 0, beat = 0, result = 0, top = 0, ghost = 0, status = 0 }

------------------------------------------------------------------------------
-- UI references
------------------------------------------------------------------------------

local gui: ScreenGui
local menuButton: GuiObject? = nil

-- Prompt
local promptHolder: Frame
local promptScrim: CanvasGroup
local prompt: CanvasGroup
local promptEyebrow: TextLabel
local lineLv: TextLabel
local lineName: TextLabel
local lineRest: TextLabel
local keysRow: Frame
local acceptButton: TextButton
local declineButton: TextButton
local acceptCap: TextLabel
local declineCap: TextLabel
local timerTrack: Frame
local timerFill: Frame
local timerNum: TextLabel
local timerTween: Tween? = nil

-- Status line
local statusGroup: CanvasGroup
local statusLabel: TextLabel
local statusTime: TextLabel
local statusShown = false

-- In-duel block
local playLayer: Frame -- DuelTop + round beats (hidden while the menu is open)
local duelTop: CanvasGroup
local topKind: TextLabel
local topRound: TextLabel
local topMine: TextLabel
local topTheirs: TextLabel
local oppLv: TextLabel
local oppName: TextLabel
local oppHp: TextLabel
local oppGhost: Frame
local oppFill: Frame
local oppFillTween: Tween? = nil
local oppGhostTween: Tween? = nil
local shownOppHealth = -1
local oppConnections: { RBXScriptConnection } = {}
local oppCharacterConnections: { RBXScriptConnection } = {}
local watchGeneration = 0 -- bumped on every new watch (a pending wait gives up)

-- Round beats
local roundBand: Frame
local roundBlock: CanvasGroup
local countParts: Frame
local numLabels: { TextLabel } = {}
local numIndex = 1
local countRule: Frame
local countRuleFill: Frame
local endParts: Frame
local endTitle: Frame
local endTitleLabels: { TextLabel } = {}
local endWinner: TextLabel
local endRule: Frame
local nextRow: CanvasGroup
local nextNum: TextLabel
local roundCC: ColorCorrectionEffect

-- Result
local resultLayer: CanvasGroup
local resEdges: CanvasGroup
local resBand: Frame
local barTop: Frame
local barBottom: Frame
local resEyebrow: CanvasGroup
local resKind: TextLabel
local resLv: TextLabel
local resName: TextLabel
local resTitle: TextLabel
local resScore: CanvasGroup
local resMine: TextLabel
local resTheirs: TextLabel
local resTable: Frame
local upEyebrow: TextLabel
local upName: TextLabel
local upLadderFrame: Frame
local upLadder: Ladder
local backFill: Frame
local backNum: TextLabel
local resultCC: ColorCorrectionEffect
local resultTrash: { Instance } = {} -- rows / counters of the last result
local returnAt = 0
local lastBackUpdate = 0
local hudHidden = false
local resultShown = false
local tearDownResult: () -> ()

-- Prompt state
local promptMode: "none" | "challenge" | "notice" = "none"
local challengeFrom: number? = nil -- nil once answered
local challengeExpiresAt = 0
local keysBound = false
-- A request received during the result screen: shown once it is over.
local deferredChallenge: { from: number, name: string, expiresAt: number }? = nil
local waitingVoidSince: number? = nil -- os.clock() the wait for an arena looked void

------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- Runs `callback` after `seconds`, unless the `kind` animation restarted.
local function after(seconds: number, kind: string, callback: () -> ())
	local token = tokens[kind]
	task.delay(math.max(seconds, 0), function()
		if tokens[kind] == token then
			callback()
		end
	end)
end

local function bump(kind: string)
	tokens[kind] += 1
end

local function readNumber(value: any): number?
	if typeof(value) == "number" and value == value then
		return value
	end
	return nil
end

local function readString(value: any, fallback: string): string
	return if typeof(value) == "string" then value else fallback
end

-- The score of a DuelEvent: { mine, theirs } (also accepts { mine =, theirs = }).
local function readScore(value: any): (number, number)
	if typeof(value) ~= "table" then
		return scoreMine, scoreTheirs
	end
	local mine = readNumber(value[1]) or readNumber(value.mine) or 0
	local theirs = readNumber(value[2]) or readNumber(value.theirs) or 0
	return mine, theirs
end

local function isKnockedOut(): boolean
	local character = player.Character
	return character ~= nil and character:GetAttribute("KnockedOut") == true
end

local function levelOf(userId: number): number?
	local other = Players:GetPlayerByUserId(userId)
	local value = if other then other:GetAttribute("Level") else nil
	return if typeof(value) == "number" then value else nil
end

local function displayNameOf(userId: number?, fallback: string): string
	local other = if userId then Players:GetPlayerByUserId(userId) else nil
	return if other then other.DisplayName else fallback
end

-- The opponent's name / level now (or as remembered, if they left).
local function opponentDisplayName(): string
	return displayNameOf(opponentId, opponentName)
end

local function opponentLevelNow(): number?
	return (if opponentId then levelOf(opponentId) else nil) or opponentLevel
end

local function rememberOpponent(userId: number?)
	opponentId = userId
	opponentName = displayNameOf(userId, "Opponent")
	opponentLevel = if userId then levelOf(userId) else nil
end

local function formatClock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function setState(newState: DuelState)
	state = newState
	changed.fire(state)
end

------------------------------------------------------------------------------
-- Building helpers
------------------------------------------------------------------------------

-- A piece of text sized to its content (for rows with a UIListLayout).
local function piece(parent: Instance, order: number, props: { [string]: any }): TextLabel
	props.LayoutOrder = order
	props.AutomaticSize = Enum.AutomaticSize.X
	if props.Size == nil then
		props.Size = UDim2.fromOffset(0, (props.TextSize or 11) + 2)
	end
	props.Parent = parent
	return Theme.text(props) :: TextLabel
end

-- Empty space on the left / right of a piece of text (inside its own size).
local function pad(label: TextLabel, left: number, right: number): TextLabel
	Theme.make("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingRight = UDim.new(0, right),
		Parent = label,
	})
	return label
end

-- A transparent row whose children line up horizontally.
local function hRow(
	className: string,
	props: { [string]: any },
	padding: number,
	horizontal: Enum.HorizontalAlignment?,
	vertical: Enum.VerticalAlignment?
): any
	props.BackgroundTransparency = 1
	return Theme.make(className, props, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, padding),
			HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
			VerticalAlignment = vertical or Enum.VerticalAlignment.Bottom,
		}),
	})
end

local function hairline(parent: Instance, props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or C.Ink
	props.Parent = parent
	return Theme.make("Frame", props) :: Frame
end

-- The small "S" key cap of the prompt: 22 × 18, outlined.
local function keyCapS(parent: Instance, order: number, text: string, outline: number): TextLabel
	return Theme.text({
		Name = "KeyCap",
		LayoutOrder = order,
		Size = UDim2.fromOffset(22, 18),
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 0.65,
		FontFace = F.NumberMedium,
		TextSize = 10,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
		Parent = parent,
	}, {
		Theme.make("UIStroke", {
			Thickness = 1,
			Color = C.Ink,
			Transparency = outline,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	}) :: TextLabel
end

------------------------------------------------------------------------------
-- Rank ladder (BRONZE · SILVER · GOLD · PLATINUM · DIAMOND)
------------------------------------------------------------------------------

-- Tier index and how full its segment is, for `elo`.
local function ladderPosition(elo: number): (number, number)
	local progress = DuelRanks.progress(elo)
	local low = if progress.index == 1 then LADDER_FLOOR else progress.minElo
	local high = progress.nextMinElo or LADDER_TOP
	return progress.index, math.clamp((elo - low) / math.max(high - low, 1), 0, 1)
end

-- Five hairline segments with the tier names under them (names only: the
-- thresholds are in the DUEL menu).
local function buildLadder(parent: Instance, width: number): Ladder
	local ladder: Ladder = { fills = {}, names = {} }
	for index, rank in D.RANKS do
		local x = (index - 1) * (width + LADDER_GAP)
		local segment = hairline(parent, {
			Name = "Seg" .. index,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(width, 2),
			BackgroundTransparency = 0.78,
		})
		table.insert(
			ladder.fills,
			hairline(segment, { Name = "Fill", Size = UDim2.fromScale(0, 1) })
		)
		table.insert(
			ladder.names,
			Theme.text({
				Name = "Tier" .. index,
				Position = UDim2.fromOffset(x, 10),
				Size = UDim2.fromOffset(width, 11),
				TextSize = 9,
				TextColor3 = C.Ink3,
				TextYAlignment = Enum.TextYAlignment.Bottom,
				Text = Theme.track(rank.name, "three"),
				Parent = parent,
			}) :: TextLabel
		)
	end
	return ladder
end

-- Draws `elo` on the ladder at once: past tiers half bright and full, the
-- current one filled to where you are, the next ones empty.
local function paintLadder(ladder: Ladder, elo: number)
	local current, fraction = ladderPosition(elo)
	for index, fill in ladder.fills do
		if index < current then
			fill.Size = UDim2.fromScale(1, 1)
			fill.BackgroundTransparency = 0.5
			ladder.names[index].TextColor3 = C.Ink2
		elseif index == current then
			fill.Size = UDim2.fromScale(math.max(0.03, fraction), 1)
			fill.BackgroundTransparency = 0
			ladder.names[index].TextColor3 = C.Ink
		else
			fill.Size = UDim2.fromScale(0, 1)
			fill.BackgroundTransparency = 0
			ladder.names[index].TextColor3 = C.Ink3
		end
	end
end

-- Rank up: the old tier fills up, the colours move, the new tier fills.
local function animateLadder(ladder: Ladder, eloBefore: number, eloAfter: number)
	local from = ladderPosition(eloBefore)
	local to, fraction = ladderPosition(eloAfter)
	for index = from, to - 1 do
		Theme.tween(ladder.fills[index], 0.3, { Size = UDim2.fromScale(1, 1) }, QUART)
	end
	after(0.3, "result", function()
		for index = 1, to - 1 do
			Theme.tween(ladder.fills[index], 0.15, { BackgroundTransparency = 0.5 })
			Theme.tween(ladder.names[index], 0.15, { TextColor3 = C.Ink2 })
		end
		Theme.tween(ladder.names[to], 0.15, { TextColor3 = C.Ink })
		local fill = ladder.fills[to]
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundTransparency = 0
		Theme.tween(fill, 0.4, { Size = UDim2.fromScale(math.max(0.03, fraction), 1) }, QUART)
	end)
end

------------------------------------------------------------------------------
-- Building: challenge prompt + status line
------------------------------------------------------------------------------

local function buildPrompt()
	promptHolder = Theme.make("Frame", {
		Name = "ChallengePrompt",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: Frame
	-- A dark patch with no visible edge (fades on all four sides).
	promptScrim = Theme.make("CanvasGroup", {
		Name = "PromptScrim",
		Position = UDim2.new(0, 0, 0.5, -20),
		Size = UDim2.fromOffset(460, 200),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 0,
		Parent = promptHolder,
	}, {
		Theme.gradient(90, { { 0, 1 }, { 0.3, 0 }, { 0.7, 0 }, { 1, 1 } }),
		Theme.make("Frame", {
			Name = "Shade",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.Scrim,
			BackgroundTransparency = 0,
		}, { Theme.gradient(0, { { 0, 0.48 }, { 0.45, 0.7 }, { 1, 1 } }) }),
	}) :: CanvasGroup

	-- The prompt fades as one group (wider than its 300 px so a long name
	-- is never cut).
	prompt = Theme.make("CanvasGroup", {
		Name = "Prompt",
		Position = UDim2.new(0, PROMPT_X, 0.5, PROMPT_Y),
		Size = UDim2.fromOffset(420, 100),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 1,
		Parent = promptHolder,
	}) :: CanvasGroup
	promptEyebrow = Theme.text({
		Name = "Eyebrow",
		Size = UDim2.new(1, 0, 0, 11),
		TextSize = 9,
		TextColor3 = C.Ink2,
		Parent = prompt,
	}) :: TextLabel
	local line = hRow("Frame", {
		Name = "Line",
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = prompt,
	}, 5) :: Frame
	lineLv = piece(line, 1, {
		Name = "Lv",
		FontFace = F.Number,
		TextSize = 10,
		TextColor3 = C.Ink2,
		Size = UDim2.fromOffset(0, 16),
		TextYAlignment = Enum.TextYAlignment.Bottom,
	})
	lineName = piece(line, 2, {
		Name = "Name",
		FontFace = ROBOTO_MEDIUM,
		TextSize = 15,
		Size = UDim2.fromOffset(0, 20),
	})
	lineRest = piece(line, 3, {
		Name = "Rest",
		FontFace = F.Body,
		TextSize = 15,
		Size = UDim2.fromOffset(0, 20),
	})

	keysRow = hRow("Frame", {
		Name = "Keys",
		Position = UDim2.fromOffset(0, 50),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		Parent = prompt,
	}, 24, nil, Enum.VerticalAlignment.Center) :: Frame
	local function keyButton(
		order: number,
		key: string,
		word: string,
		outline: number,
		color: Color3
	)
		local button = hRow("TextButton", {
			Name = word,
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 18),
			Text = "",
			AutoButtonColor = false,
			Parent = keysRow,
		}, 10, nil, Enum.VerticalAlignment.Center) :: TextButton
		local cap = keyCapS(button, 1, key, outline)
		piece(button, 2, {
			Name = "Word",
			TextSize = 11,
			TextColor3 = color,
			Size = UDim2.fromOffset(0, 18),
			Text = Theme.track(word, "four"),
		})
		return button, cap
	end
	-- ACCEPT is the only ink key: the eye lands on the default answer.
	acceptButton, acceptCap = keyButton(1, "Y", "ACCEPT", 0.4, C.Ink)
	declineButton, declineCap = keyButton(2, "N", "DECLINE", 0.6, C.Ink2)

	timerTrack = hairline(prompt, {
		Name = "Timer",
		Position = UDim2.fromOffset(0, 86),
		Size = UDim2.fromOffset(TIMER_WIDTH, 1),
		BackgroundTransparency = 0.82,
	})
	timerFill = hairline(timerTrack, {
		Name = "TimerFill",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.25,
	})
	-- Stays ink to the end: a request running out is not danger.
	timerNum = Theme.text({
		Name = "TimerNum",
		Position = UDim2.fromOffset(TIMER_WIDTH + 12, 80),
		Size = UDim2.fromOffset(30, 12),
		FontFace = F.Number,
		TextSize = 10,
		Parent = prompt,
	}) :: TextLabel
end

-- "RANKED · SEARCHING 0:23" under the word MENU, while the menu is closed.
local function buildStatus()
	statusGroup = hRow("CanvasGroup", {
		Name = "DuelStatus",
		Position = UDim2.new(0, 76, 0.5, -8),
		Size = UDim2.fromOffset(300, 13),
		GroupTransparency = 1,
		Visible = false,
		Parent = gui,
	}, 8) :: CanvasGroup
	statusLabel = piece(statusGroup, 1, {
		Name = "Label",
		TextSize = 9,
		TextColor3 = C.Ink2,
		Size = UDim2.fromOffset(0, 11),
		TextYAlignment = Enum.TextYAlignment.Bottom,
	})
	statusTime = piece(statusGroup, 2, {
		Name = "Time",
		FontFace = F.Number,
		TextSize = 10,
		Size = UDim2.fromOffset(0, 12),
		TextYAlignment = Enum.TextYAlignment.Bottom,
	})
end

------------------------------------------------------------------------------
-- Building: in-duel block (top centre) + round beats
------------------------------------------------------------------------------

local function buildTop()
	playLayer = Theme.make("Frame", {
		Name = "Play",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: Frame
	duelTop = Theme.make("CanvasGroup", {
		Name = "DuelTop",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOP_Y),
		Size = UDim2.fromOffset(400, 76),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = playLayer,
	}) :: CanvasGroup

	-- RANKED · ROUND 2 · BEST OF 3
	local tagRow = hRow("Frame", {
		Name = "TagRow",
		Size = UDim2.new(1, 0, 0, 11),
		Parent = duelTop,
	}, 9, Enum.HorizontalAlignment.Center) :: Frame
	local function micro(order: number, color: Color3, text: string?): TextLabel
		return piece(tagRow, order, {
			TextSize = 9,
			TextColor3 = color,
			Size = UDim2.fromOffset(0, 11),
			Text = text or "",
		})
	end
	local function dot(order: number)
		piece(tagRow, order, {
			Name = "Dot",
			FontFace = F.LabelRegular,
			TextSize = 9,
			TextColor3 = C.Ink2,
			Size = UDim2.fromOffset(0, 11),
			Text = "·",
		})
	end
	topKind = micro(1, C.Ink)
	dot(2)
	topRound = micro(3, C.Ink2)
	dot(4)
	micro(5, C.Ink2, Theme.track("BEST OF 3", "three"))

	-- YOU 1 — 0 (the spacer keeps the digits on the screen centre)
	local scoreRow = hRow("Frame", {
		Name = "ScoreRow",
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = duelTop,
	}, 12, Enum.HorizontalAlignment.Center) :: Frame
	Theme.text({
		Name = "YouCap",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(80, 13),
		TextSize = 9,
		TextColor3 = C.Ink2,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = Theme.track("YOU", "three"),
		Parent = scoreRow,
	})
	local function numeral(order: number, color: Color3, text: string): TextLabel
		return piece(scoreRow, order, {
			FontFace = F.NumberLight,
			TextSize = 22,
			TextColor3 = color,
			Size = UDim2.fromOffset(0, 24),
			Text = text,
		})
	end
	topMine = numeral(2, C.Ink, "0")
	numeral(3, C.Ink2, "—")
	topTheirs = numeral(4, C.Ink, "0")
	Theme.make("Frame", {
		Name = "Spacer",
		LayoutOrder = 5,
		Size = UDim2.fromOffset(80, 13),
		BackgroundTransparency = 1,
		Parent = scoreRow,
	})

	-- 12 Vex ............................ 46
	local oppRow = hRow("Frame", {
		Name = "OppRow",
		Position = UDim2.fromOffset(20, 52),
		Size = UDim2.fromOffset(OPP_WIDTH, 16),
		Parent = duelTop,
	}, 5) :: Frame
	oppLv = piece(oppRow, 1, {
		Name = "Lv",
		FontFace = F.Number,
		TextSize = 10,
		TextColor3 = C.Ink2,
		Size = UDim2.fromOffset(0, 14),
		TextYAlignment = Enum.TextYAlignment.Bottom,
	})
	oppName = piece(oppRow, 2, {
		Name = "Name",
		TextSize = 13,
		Size = UDim2.fromOffset(0, 16),
		TextYAlignment = Enum.TextYAlignment.Bottom,
	})
	oppHp = Theme.text({
		Name = "OppHp",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 54),
		Size = UDim2.fromOffset(40, 13),
		FontFace = F.Number,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "100",
		Parent = duelTop,
	}) :: TextLabel
	local track = hairline(duelTop, {
		Name = "OppTrack",
		Position = UDim2.fromOffset(20, 72),
		Size = UDim2.fromOffset(OPP_WIDTH, 2),
		BackgroundTransparency = 0.78,
	})
	-- Red = the damage YOU just did (it drains away); the bar itself is
	-- never red (red means *your* danger).
	oppGhost = hairline(track, {
		Name = "OppGhost",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.BloodHi,
		BackgroundTransparency = 0.15,
		ZIndex = 2,
	})
	oppFill = hairline(track, {
		Name = "OppFill",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	})
end

local function buildRoundBeats()
	-- The soft dark band of the level-up beat, a little lower.
	roundBand = Theme.make("Frame", {
		Name = "RoundBand",
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 1,
		Parent = playLayer,
	}, { Theme.gradient(90, { { 0, 1 }, { 0.5, 0.58 }, { 1, 1 } }) }) :: Frame
	roundBlock = Theme.make("CanvasGroup", {
		Name = "RoundBlock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 146),
		-- 800, not 400: a CanvasGroup cuts what overflows, and "ROUND 1 — "
		-- plus a long name in Oswald 34 is wider than 400 (all centred).
		Size = UDim2.fromOffset(800, 120),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3,
		Parent = playLayer,
	}) :: CanvasGroup

	-- 3, 2, 1, FIGHT: two labels take turns (the old one fades while the
	-- new one comes in).
	countParts = Theme.make("Frame", {
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = roundBlock,
	}) :: Frame
	for index = 1, 2 do
		table.insert(
			numLabels,
			Theme.text({
				Name = "Num" .. index,
				Position = UDim2.fromOffset(0, NUM_Y),
				Size = UDim2.new(1, 0, 0, 48),
				FontFace = F.Display,
				TextSize = 40,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTransparency = 1,
				Parent = countParts,
			}) :: TextLabel
		)
	end
	countRule = hairline(countParts, {
		Name = "Rule",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(RULE_WIDTH, 1),
		BackgroundTransparency = 0.82,
	})
	countRuleFill = hairline(countRule, {
		Name = "RuleFill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.25,
	})

	-- ROUND 1 — YOU / ROUND 1 — Vex, then NEXT ROUND 3
	endParts = Theme.make("Frame", {
		Name = "End",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = roundBlock,
	}) :: Frame
	endTitle = hRow("Frame", {
		Name = "Title",
		Position = UDim2.fromOffset(0, END_TITLE_Y),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = endParts,
	}, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) :: Frame
	local function display(order: number, color: Color3, text: string): TextLabel
		local label = piece(endTitle, order, {
			FontFace = F.Display,
			TextSize = 34,
			TextColor3 = color,
			Size = UDim2.fromOffset(0, 40),
			Text = text,
		})
		table.insert(endTitleLabels, label)
		return label
	end
	display(1, C.Ink, "")
	display(2, C.Ink2, "—")
	endWinner = display(3, C.Ink, "")
	endRule = hairline(endParts, {
		Name = "Rule",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(0, 1),
		BackgroundTransparency = 0.7,
	})
	nextRow = hRow("CanvasGroup", {
		Name = "Next",
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 13),
		GroupTransparency = 1,
		Parent = endParts,
	}, 10, Enum.HorizontalAlignment.Center) :: CanvasGroup
	piece(nextRow, 1, {
		TextSize = 9,
		TextColor3 = C.Ink2,
		Size = UDim2.fromOffset(0, 11),
		Text = Theme.track("NEXT ROUND", "three"),
	})
	nextNum = piece(nextRow, 2, {
		FontFace = F.Number,
		TextSize = 11,
		Size = UDim2.fromOffset(0, 13),
	})

	roundCC = Theme.make("ColorCorrectionEffect", { Name = "RoundCC", Parent = Lighting })
end

------------------------------------------------------------------------------
-- Building: result (VICTORY / DEFEAT)
------------------------------------------------------------------------------

local function buildResult()
	resultLayer = Theme.make("CanvasGroup", {
		Name = "Result",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	}) :: CanvasGroup

	-- Defeat only: dark then faint blood edges (the kit recipe).
	resEdges = Theme.make("CanvasGroup", {
		Name = "Edges",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		ZIndex = 1,
		Parent = resultLayer,
	}) :: CanvasGroup
	local function edge(name: string, right: boolean, color: Color3, inner: number)
		Theme.make("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(if right then 1 else 0, 0),
			Position = UDim2.fromScale(if right then 1 else 0, 0),
			Size = UDim2.fromScale(0.18, 1),
			BackgroundColor3 = color,
			Parent = resEdges,
		}, { Theme.gradient(if right then 180 else 0, { { 0, inner }, { 1, 1 } }) })
	end
	edge("ResShadeL", false, C.Scrim, 0.7)
	edge("ResShadeR", true, C.Scrim, 0.7)
	edge("ResEdgeL", false, C.BloodDeep, 0.74)
	edge("ResEdgeR", true, C.BloodDeep, 0.74)

	resBand = Theme.make("Frame", {
		Name = "ResBand",
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 540),
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = resultLayer,
	}, { Theme.gradient(90, { { 0, 1 }, { 0.22, 0.38 }, { 0.78, 0.38 }, { 1, 1 } }) }) :: Frame
	barTop = Theme.make("Frame", {
		Name = "BarTop",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = C.Scrim,
		ZIndex = 3,
		Parent = resultLayer,
	}) :: Frame
	barBottom = Theme.make("Frame", {
		Name = "BarBottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = C.Scrim,
		ZIndex = 3,
		Parent = resultLayer,
	}) :: Frame

	local block = Theme.make("Frame", {
		Name = "ResBlock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(480, 440),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = resultLayer,
	}) :: Frame

	-- RANKED · VS  12 Vex
	resEyebrow = hRow("CanvasGroup", {
		Name = "Eyebrow",
		Size = UDim2.new(1, 0, 0, 14),
		GroupTransparency = 1,
		Parent = block,
	}, 6, Enum.HorizontalAlignment.Center) :: CanvasGroup
	resKind =
		piece(resEyebrow, 1, { TextSize = 10, TextColor3 = C.Ink2, Size = UDim2.fromOffset(0, 12) })
	resLv = piece(resEyebrow, 2, {
		FontFace = F.Number,
		TextSize = 10,
		TextColor3 = C.Ink2,
		Size = UDim2.fromOffset(0, 12),
	})
	resName =
		piece(resEyebrow, 3, { TextSize = 12, TextColor3 = C.Ink2, Size = UDim2.fromOffset(0, 14) })

	resTitle = Theme.text({
		Name = "Title",
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 40),
		FontFace = F.Display,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Parent = block,
	}) :: TextLabel

	-- YOU 2 — 1 (bigger numerals; the opponent is named in the eyebrow)
	resScore = hRow("CanvasGroup", {
		Name = "Score",
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 30),
		GroupTransparency = 1,
		Parent = block,
	}, 14, Enum.HorizontalAlignment.Center) :: CanvasGroup
	Theme.text({
		Name = "YouCap",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(90, 13),
		TextSize = 9,
		TextColor3 = C.Ink2,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = Theme.track("YOU", "three"),
		Parent = resScore,
	})
	local function numeral(order: number, color: Color3, text: string): TextLabel
		return piece(resScore, order, {
			FontFace = F.NumberLight,
			TextSize = 30,
			TextColor3 = color,
			Size = UDim2.fromOffset(0, 30),
			Text = text,
		})
	end
	resMine = numeral(2, C.Ink, "0")
	numeral(3, C.Ink3, "—")
	resTheirs = numeral(4, C.Ink, "0")
	Theme.make("Frame", {
		Name = "Spacer",
		LayoutOrder = 5,
		Size = UDim2.fromOffset(90, 13),
		BackgroundTransparency = 1,
		Parent = resScore,
	})

	-- REWARDS / ELO / RANK rows (rebuilt for each result).
	resTable = Theme.make("Frame", {
		Name = "Table",
		Position = UDim2.fromOffset(0, 132),
		Size = UDim2.new(1, 0, 0, RES_ROW),
		BackgroundTransparency = 1,
		Parent = block,
	}) :: Frame
	hairline(
		resTable,
		{ Name = "Top", Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.78 }
	)

	-- RANK UP / SILVER / the ladder
	upEyebrow = Theme.text({
		Name = "UpEyebrow",
		Position = UDim2.fromOffset(0, 234),
		Size = UDim2.new(1, 0, 0, 12),
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Text = Theme.track("RANK UP", "three") .. " ",
		Parent = block,
	}) :: TextLabel
	upName = Theme.text({
		Name = "UpName",
		Position = UDim2.fromOffset(0, 250),
		Size = UDim2.new(1, 0, 0, 30),
		FontFace = F.Display,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Parent = block,
	}) :: TextLabel
	upLadderFrame = Theme.make("Frame", {
		Name = "UpLadder",
		Position = UDim2.fromOffset(0, 300),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = block,
	}) :: Frame
	upLadder = buildLadder(upLadderFrame, LADDER_WIDTH)

	-- BACK TO THE ARENA  4.2 (inside the bottom bar, like the KO attribution)
	local back = Theme.make("Frame", {
		Name = "Back",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -45),
		Size = UDim2.fromOffset(280, 30),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = resultLayer,
	}) :: Frame
	local backTrack = hairline(back, {
		Name = "Track",
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundTransparency = 0.82,
	})
	backFill = hairline(backTrack, { Name = "Fill", Size = UDim2.fromScale(1, 1) })
	Theme.text({
		Name = "Label",
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, -40, 0, 12),
		TextSize = 10,
		TextColor3 = C.Ink2,
		Text = Theme.track("BACK TO THE ARENA", "three"),
		Parent = back,
	})
	backNum = Theme.text({
		Name = "Num",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 12),
		Size = UDim2.fromOffset(40, 13),
		FontFace = F.Number,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = back,
	}) :: TextLabel

	resultCC = Theme.make("ColorCorrectionEffect", { Name = "ResultCC", Parent = Lighting })
end

------------------------------------------------------------------------------
-- Challenge prompt and challenger notice
------------------------------------------------------------------------------

-- What follows the name in a refusal ("Vex declined").
local DECLINED_WORDS: { [string]: string } = {
	DECLINED = "declined",
	EXPIRED = "did not answer",
	["IN A DUEL"] = "is in a duel",
	["IN COMBAT"] = "is in combat",
	["BLOCKS DUELS"] = "blocks duel requests",
	BUSY = "already has a request",
}
local COOLDOWN_SENTENCE = "Wait a moment before challenging again"

local answer: (accept: boolean) -> ()

local function onAnswerKey(
	_action: string,
	inputState: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	-- Typing in the chat, or the prompt hidden (knocked out): not for us.
	if
		inputState ~= Enum.UserInputState.Begin
		or UserInputService:GetFocusedTextBox() ~= nil
		or not promptHolder.Visible
	then
		return Enum.ContextActionResult.Pass
	end
	answer(input.KeyCode == Enum.KeyCode.Y)
	return Enum.ContextActionResult.Sink
end

-- Y / N are only bound while a challenge is on screen.
local function setKeysBound(bound: boolean)
	if bound == keysBound then
		return
	end
	keysBound = bound
	if bound then
		ContextActionService:BindActionAtPriority(
			"DuelAnswer",
			onAnswerKey,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.Y,
			Enum.KeyCode.N
		)
	else
		ContextActionService:UnbindAction("DuelAnswer")
	end
end

local function leavePrompt(seconds: number)
	if promptMode == "none" then
		return
	end
	promptMode = "none"
	challengeFrom = nil
	setKeysBound(false)
	bump("prompt")
	Theme.tween(promptScrim, seconds, { GroupTransparency = 1 }, LINEAR)
	Theme.tween(prompt, seconds, {
		GroupTransparency = 1,
		Position = UDim2.new(0, PROMPT_X - 4, 0.5, PROMPT_Y),
	}, LINEAR)
	after(seconds, "prompt", function()
		promptScrim.Visible = false
		prompt.Visible = false
	end)
end

-- Shows the prompt with `fill` applied. If one is already on screen it is
-- replaced with a short crossfade.
local function presentPrompt(fill: () -> (), onShown: (() -> ())?)
	local wasShowing = prompt.Visible and promptMode ~= "none"
	bump("prompt")
	local function enter()
		fill()
		promptScrim.Visible = true
		prompt.Visible = true
		Theme.tween(promptScrim, 0.2, { GroupTransparency = 0 })
		if not wasShowing then
			prompt.Position = UDim2.new(0, PROMPT_X - 8, 0.5, PROMPT_Y)
		end
		Theme.tween(prompt, if wasShowing then 0.075 else 0.18, {
			GroupTransparency = 0,
			Position = UDim2.new(0, PROMPT_X, 0.5, PROMPT_Y),
		})
		if onShown then
			onShown()
		end
	end
	if wasShowing then
		Theme.tween(prompt, 0.075, { GroupTransparency = 1 }, LINEAR)
		after(0.075, "prompt", enter)
	else
		enter()
	end
end

local function setLine(userId: number?, name: string?, rest: string)
	local level = if userId then levelOf(userId) else nil
	lineLv.Visible = level ~= nil
	lineLv.Text = if level then tostring(level) else ""
	lineName.Visible = name ~= nil and name ~= ""
	lineName.Text = name or ""
	lineRest.Text = rest
end

local function showChallenge(from: number, name: string, expiresAt: number)
	promptMode = "challenge"
	challengeFrom = from
	challengeExpiresAt = expiresAt
	setKeysBound(true)
	presentPrompt(function()
		promptEyebrow.Text = Theme.track("DUEL REQUEST · BEST OF 3", "three")
		setLine(from, displayNameOf(from, name), "challenges you to a duel")
		keysRow.Visible = true
		timerTrack.Visible = true
		timerNum.Visible = true
		local left = math.max(expiresAt - serverNow(), 0)
		timerNum.Text = string.format("%d", math.ceil(left))
		-- The hairline empties over the time left.
		if timerTween then
			timerTween:Cancel()
		end
		timerFill.Size = UDim2.fromScale(math.clamp(left / D.CHALLENGE_TIMEOUT, 0, 1), 1)
		timerTween = Theme.tween(timerFill, left, { Size = UDim2.fromScale(0, 1) }, LINEAR)
	end)
	-- No sound: Shared/Sounds has no UI tick yet and SoundController only
	-- plays sounds placed in the world (same as the level-up beat).
end

local function showNotice(userId: number, name: string, reason: string)
	promptMode = "notice"
	challengeFrom = nil
	setKeysBound(false)
	presentPrompt(function()
		promptEyebrow.Text = Theme.track("YOUR CHALLENGE", "three")
		if reason == "COOLDOWN" then
			setLine(nil, nil, COOLDOWN_SENTENCE)
		else
			setLine(if userId ~= 0 then userId else nil, name, DECLINED_WORDS[reason] or "declined")
		end
		keysRow.Visible = false
		timerTrack.Visible = false
		timerNum.Visible = false
	end, function()
		after(NOTICE_LIFE, "prompt", function()
			leavePrompt(0.3)
		end)
	end)
end

-- The chosen key blinks (the kit "Use" blink), then the prompt leaves.
local function flashKey(cap: TextLabel)
	cap.BackgroundColor3 = C.Ink
	cap.BackgroundTransparency = 0
	cap.TextColor3 = C.Scrim
	Theme.tween(cap, 0.2, {
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 0.65,
		TextColor3 = C.Ink,
	})
end

answer = function(accept: boolean)
	local from = challengeFrom
	if promptMode ~= "challenge" or from == nil then
		return
	end
	challengeFrom = nil
	setKeysBound(false)
	Remotes.DuelRespond:FireServer(from, accept)
	flashKey(if accept then acceptCap else declineCap)
	after(0.2, "prompt", function()
		leavePrompt(0.2)
	end)
end

------------------------------------------------------------------------------
-- Status line (menu closed, searching / waiting)
------------------------------------------------------------------------------

local function wantsStatus(): boolean
	return (state == "Searching" or state == "Waiting") and MenuController.getOpen() == nil
end

local function refreshStatus()
	local want = wantsStatus()
	if want then
		if state == "Searching" then
			statusLabel.Text = Theme.track("RANKED · SEARCHING", "three")
			statusTime.Visible = true
			statusTime.Text = formatClock(DuelController.getSearchTime())
		else
			statusLabel.Text = Theme.track("WAITING FOR AN ARENA", "three")
			statusTime.Visible = false
		end
	end
	if want == statusShown then
		return
	end
	statusShown = want
	bump("status")
	if want then
		statusGroup.Visible = true
		Theme.tween(statusGroup, 0.15, { GroupTransparency = 0 })
	else
		Theme.tween(statusGroup, 0.15, { GroupTransparency = 1 }, LINEAR)
		after(0.15, "status", function()
			statusGroup.Visible = false
		end)
	end
end

------------------------------------------------------------------------------
-- In-duel block
------------------------------------------------------------------------------

local function setOppHealth(health: number, maxHealth: number)
	local ratio = if maxHealth > 0 then math.clamp(health / maxHealth, 0, 1) else 0
	oppHp.Text = tostring(math.ceil(math.max(health, 0)))
	local dropped = shownOppHealth >= 0 and health < shownOppHealth
	shownOppHealth = health
	bump("ghost")
	if oppFillTween then
		oppFillTween:Cancel()
	end
	if dropped then
		-- The bar drops at once, the red sliver drains a moment later.
		oppFillTween = Theme.tween(oppFill, 0.08, { Size = UDim2.fromScale(ratio, 1) })
		after(GHOST_DELAY, "ghost", function()
			oppGhostTween =
				Theme.tween(oppGhost, 0.45, { Size = UDim2.fromScale(ratio, 1) }, QUAD, IN_OUT)
		end)
	else
		if oppGhostTween then
			oppGhostTween:Cancel()
		end
		oppFill.Size = UDim2.fromScale(ratio, 1)
		oppGhost.Size = UDim2.fromScale(ratio, 1)
	end
end

local function clearConnections(list: { RBXScriptConnection })
	for _, connection in list do
		connection:Disconnect()
	end
	table.clear(list)
end

local function watchOpponentCharacter(character: Model)
	clearConnections(oppCharacterConnections)
	watchGeneration += 1
	local generation = watchGeneration
	local found = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 5)
	-- (While we waited: another body, or the duel is over.)
	if
		generation ~= watchGeneration
		or found == nil
		or not found:IsA("Humanoid")
		or character.Parent == nil
	then
		return
	end
	local humanoid: Humanoid = found
	local function refresh()
		setOppHealth(humanoid.Health, humanoid.MaxHealth)
	end
	table.insert(oppCharacterConnections, humanoid.HealthChanged:Connect(refresh))
	table.insert(
		oppCharacterConnections,
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refresh)
	)
	shownOppHealth = -1 -- a new body: no damage animation
	refresh()
end

local function refreshOppLevel()
	local level = opponentLevelNow()
	oppLv.Visible = level ~= nil
	oppLv.Text = if level then tostring(level) else ""
end

local function watchOpponent(userId: number?)
	clearConnections(oppConnections)
	clearConnections(oppCharacterConnections)
	watchGeneration += 1
	shownOppHealth = -1
	local opponent = if userId then Players:GetPlayerByUserId(userId) else nil
	if opponent == nil then
		return
	end
	table.insert(
		oppConnections,
		opponent.CharacterAdded:Connect(function(character)
			watchOpponentCharacter(character)
		end)
	)
	table.insert(
		oppConnections,
		opponent:GetAttributeChangedSignal("Level"):Connect(refreshOppLevel)
	)
	if opponent.Character then
		task.spawn(watchOpponentCharacter, opponent.Character)
	end
end

local function setTopRound(roundNumber: number, animate: boolean)
	local text = Theme.track("ROUND " .. roundNumber, "three")
	if not animate or topRound.Text == text then
		topRound.Text = text
		return
	end
	bump("top")
	Theme.tween(topRound, 0.075, { TextTransparency = 1 }, LINEAR)
	after(0.075, "top", function()
		topRound.Text = text
		Theme.tween(topRound, 0.075, { TextTransparency = 0 }, LINEAR)
	end)
end

-- Changes a score digit; a changed one fades back in.
local function setDigit(label: TextLabel, value: number, animate: boolean)
	local text = tostring(value)
	if label.Text == text then
		return
	end
	label.Text = text
	if animate then
		label.TextTransparency = 1
		Theme.tween(label, 0.25, { TextTransparency = 0 })
	end
end

local function showTop()
	topKind.Text = Theme.track(if ranked then "RANKED" else "CHALLENGE", "three")
	setTopRound(math.max(round, 1), false)
	topMine.Text = tostring(scoreMine)
	topTheirs.Text = tostring(scoreTheirs)
	oppName.Text = opponentDisplayName()
	refreshOppLevel()
	oppFill.Size = UDim2.fromScale(1, 1)
	oppGhost.Size = UDim2.fromScale(1, 1)
	duelTop.Visible = true
	duelTop.GroupTransparency = 1
	duelTop.Position = UDim2.new(0.5, 0, 0, TOP_Y - 8)
	Theme.tween(duelTop, 0.25, {
		GroupTransparency = 0,
		Position = UDim2.new(0.5, 0, 0, TOP_Y),
	}, QUART)
end

local function hideTop(seconds: number)
	bump("top")
	Theme.tween(duelTop, seconds, { GroupTransparency = 1 }, LINEAR)
	after(seconds, "top", function()
		duelTop.Visible = false
	end)
end

------------------------------------------------------------------------------
-- Round beats
------------------------------------------------------------------------------

-- A new digit (or FIGHT) comes in; the previous one fades out.
local function showCount(text: string)
	local old = numLabels[numIndex]
	numIndex = 3 - numIndex
	local new = numLabels[numIndex]
	Theme.tween(old, 0.12, { TextTransparency = 1 }, LINEAR)
	new.Text = text
	new.TextTransparency = 1
	new.Position = UDim2.fromOffset(0, NUM_Y + 6)
	Theme.tween(new, 0.12, { TextTransparency = 0 })
	Theme.tween(new, 0.2, { Position = UDim2.fromOffset(0, NUM_Y) }, QUART)
end

local function resetBeat()
	bump("beat")
	roundBlock.GroupTransparency = 0
	roundBlock.Visible = true
	roundBand.Visible = true
end

-- 3, 2, 1, FIGHT, timed on the server clock (`fightAt`).
local function playRoundStart(fightAt: number)
	resetBeat()
	countParts.Visible = true
	endParts.Visible = false
	countRule.Visible = true
	for _, label in numLabels do
		label.TextTransparency = 1
	end
	local now = serverNow()
	local entered = false
	local function enter()
		if entered then
			return
		end
		entered = true
		Theme.tween(roundBand, 0.3, { BackgroundTransparency = 0 })
		Theme.tween(roundCC, 0.3, { Saturation = -0.2, Contrast = 0 })
	end
	for count = D.COUNTDOWN, 1, -1 do
		local untilTick = fightAt - count - now
		if untilTick > -1 then -- (a digit already over is skipped)
			after(untilTick, "beat", function()
				enter()
				showCount(tostring(count))
				countRuleFill.Size = UDim2.fromScale(1, 1)
				Theme.tween(countRuleFill, 1, { Size = UDim2.fromScale(0, 1) }, LINEAR)
			end)
		end
	end
	after(fightAt - now, "beat", function()
		enter()
		countRule.Visible = false
		-- (+1 trailing space: the wide tracking stays centred.)
		showCount(Theme.track("FIGHT", "en") .. " ")
		Theme.tween(roundCC, 0.3, { Saturation = 0, Contrast = 0 })
		after(0.45, "beat", function()
			for _, label in numLabels do
				Theme.tween(label, 0.3, {
					TextTransparency = 1,
					Position = UDim2.fromOffset(0, NUM_Y - 3),
				}, LINEAR)
			end
			Theme.tween(roundBand, 0.3, { BackgroundTransparency = 1 }, LINEAR)
			after(0.3, "beat", function()
				roundBand.Visible = false
				roundBlock.Visible = false
			end)
		end)
	end)
	-- No sound yet (no UI tick in Shared/Sounds, see showChallenge).
end

-- "ROUND 1 — YOU" (you took it) or "ROUND 1 — Vex", then NEXT ROUND 3.
local function playRoundEnd(roundNumber: number, won: boolean, last: boolean)
	resetBeat()
	countParts.Visible = false
	endParts.Visible = true
	endTitleLabels[1].Text = Theme.track("ROUND " .. roundNumber, "thin")
	if won then
		endWinner.Text = Theme.track("YOU", "thin")
		endWinner.TextColor3 = C.InkHi
	else
		endWinner.Text = Theme.track(opponentDisplayName(), "thin")
		endWinner.TextColor3 = C.Ink
	end
	for _, label in endTitleLabels do
		label.TextTransparency = 1
	end
	endTitle.Position = UDim2.fromOffset(0, END_TITLE_Y + 6)
	endRule.Size = UDim2.fromOffset(0, 1)
	nextRow.GroupTransparency = 1
	nextRow.Visible = not last
	local pause = D.ROUND_END_PAUSE
	nextNum.Text = string.format("%d", pause)

	Theme.tween(roundBand, 0.3, { BackgroundTransparency = 0 })
	Theme.tween(roundCC, 0.3, { Saturation = -0.3, Contrast = 0.05 })
	after(0.1, "beat", function()
		for _, label in endTitleLabels do
			Theme.tween(label, 0.4, { TextTransparency = 0 }, QUART)
		end
		Theme.tween(endTitle, 0.4, { Position = UDim2.fromOffset(0, END_TITLE_Y) }, QUART)
	end)
	after(0.15, "beat", function()
		Theme.tween(endRule, 0.5, { Size = UDim2.fromOffset(RULE_WIDTH, 1) }, QUART)
	end)
	after(0.4, "beat", function()
		Theme.tween(nextRow, 0.25, { GroupTransparency = 0 })
	end)
	for second = 1, pause - 1 do
		after(second, "beat", function()
			nextNum.Text = string.format("%d", pause - second)
		end)
	end
	after(pause - 0.4, "beat", function()
		Theme.tween(roundBlock, 0.4, { GroupTransparency = 1 }, LINEAR)
		Theme.tween(roundBand, 0.4, { BackgroundTransparency = 1 }, LINEAR)
		Theme.tween(roundCC, 0.4, { Saturation = 0, Contrast = 0 }, LINEAR)
		after(0.4, "beat", function()
			roundBand.Visible = false
			roundBlock.Visible = false
		end)
	end)
end

-- The result takes over from a beat still on screen.
local function stopBeat(seconds: number)
	bump("beat")
	Theme.tween(roundBlock, seconds, { GroupTransparency = 1 }, LINEAR)
	Theme.tween(roundBand, seconds, { BackgroundTransparency = 1 }, LINEAR)
	Theme.tween(roundCC, seconds, { Saturation = 0, Contrast = 0 }, LINEAR)
	after(seconds, "beat", function()
		roundBand.Visible = false
		roundBlock.Visible = false
	end)
end

------------------------------------------------------------------------------
-- Fight HUD hidden during the result
------------------------------------------------------------------------------

-- The vitals hide through HudController.setHidden. The kit block, the feed,
-- the crosshair and the MENU button decide their own visibility (knocked
-- out, menu open) and have no such switch: during the result we turn their
-- ScreenGuis off just before each frame is drawn, so we have the last word.
local function enforceHudHidden()
	if not hudHidden then
		return
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	for _, name in HUD_GUIS do
		local hud = playerGui:FindFirstChild(name)
		if hud and hud:IsA("ScreenGui") then
			hud.Enabled = false
		end
	end
	if menuButton then
		menuButton.Visible = false
	end
end

-- Puts them back the way their own rules want them (they correct
-- themselves on their next update anyway).
local function restoreHud()
	hudHidden = false
	HudController.setHidden(false)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return
	end
	local menuClosed = MenuController.getOpen() == nil
	local fightHud = menuClosed and not isKnockedOut()
	local wanted: { [string]: boolean } = {
		KitHud = fightHud,
		KillFeed = menuClosed,
		Crosshair = true,
	}
	for name, enabled in wanted do
		local hud = playerGui:FindFirstChild(name)
		if hud and hud:IsA("ScreenGui") then
			hud.Enabled = enabled
		end
	end
	if menuButton then
		menuButton.Visible = menuClosed
	end
end

------------------------------------------------------------------------------
-- Result
------------------------------------------------------------------------------

local function clearResultRows()
	for _, instance in resultTrash do
		instance:Destroy()
	end
	table.clear(resultTrash)
end

-- One row of the result table: label on the left, value row on the right.
local function tableRow(index: number, label: string): (CanvasGroup, Frame)
	local row = Theme.make("CanvasGroup", {
		Name = label,
		Position = UDim2.fromOffset(-8, (index - 1) * RES_ROW),
		Size = UDim2.new(1, 0, 0, RES_ROW),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = resTable,
	}) :: CanvasGroup
	table.insert(resultTrash, row)
	hairline(row, {
		Name = "Bottom",
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundTransparency = 0.93,
	})
	Theme.text({
		Name = "Label",
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.fromOffset(120, 11),
		TextSize = 9,
		TextColor3 = C.Ink2,
		Text = Theme.track(label, "three"),
		Parent = row,
	})
	local value = hRow("Frame", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 10),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 13),
		Parent = row,
	}, 0, Enum.HorizontalAlignment.Right) :: Frame
	return row, value
end

local function mono(
	parent: Instance,
	order: number,
	text: string,
	size: number,
	color: Color3
): TextLabel
	return piece(parent, order, {
		FontFace = F.Number,
		TextSize = size,
		TextColor3 = color,
		Size = UDim2.fromOffset(0, 13),
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = text,
	})
end

-- "+100 XP · +25 COINS" (the reward row of the HUD).
local function fillRewards(value: Frame, xp: number, coins: number, forfeit: boolean)
	if xp <= 0 and coins <= 0 then
		piece(value, 1, {
			TextSize = 9,
			TextColor3 = C.Ink2,
			Size = UDim2.fromOffset(0, 13),
			TextYAlignment = Enum.TextYAlignment.Bottom,
			Text = Theme.track(if forfeit then "NO REWARD · FORFEIT" else "NO REWARD", "three"),
		})
		return
	end
	mono(value, 1, "+" .. xp, 11, C.Ink)
	pad(mono(value, 2, "XP", 10, C.Ink2), 4, 0)
	if coins > 0 then
		pad(
			piece(value, 3, {
				FontFace = F.LabelRegular,
				TextSize = 11,
				TextColor3 = C.Ink2,
				Size = UDim2.fromOffset(0, 13),
				TextYAlignment = Enum.TextYAlignment.Bottom,
				Text = "·",
			}),
			7,
			7
		)
		mono(value, 4, "+" .. coins, 11, C.Ink2)
		pad(mono(value, 5, "COINS", 10, C.Ink2), 4, 0)
	end
end

-- "1088 → 1112   +24": the new value counts up, the change appears after.
local function fillElo(value: Frame, before: number, afterElo: number): (TextLabel, TextLabel)
	mono(value, 1, tostring(before), 11, C.Ink2)
	pad(mono(value, 2, "→", 11, C.Ink2), 8, 8)
	local afterLabel = mono(value, 3, tostring(before), 11, C.Ink)
	local change = afterElo - before
	local delta = Theme.text({
		Name = "Delta",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(34 + 16, 13),
		FontFace = F.Number,
		TextSize = 11,
		TextColor3 = if change >= 0 then C.Ink else C.Ink2,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextTransparency = 1,
		-- U+2212: a real minus sign (as wide as the plus).
		Text = if change >= 0 then "+" .. change else "\u{2212}" .. -change,
		Parent = value,
	}) :: TextLabel
	return afterLabel, delta
end

local function onEnd(data: { [string]: any })
	local won = data.won == true
	local isRanked = data.ranked == true
	local forfeit = data.forfeit == true
	scoreMine, scoreTheirs = readScore(data.score)
	local xp = readNumber(data.xp) or 0
	local coins = readNumber(data.coins) or 0
	local eloBefore = readNumber(data.eloBefore)
	local eloAfter = readNumber(data.eloAfter)
	returnAt = readNumber(data.returnAt) or (serverNow() + D.RESULT_TIME)
	setState("Result")
	resultShown = true

	bump("result")
	clearResultRows()
	stopBeat(0.15)
	hideTop(0.2)
	if MenuController.getOpen() then
		MenuController.close()
	end
	hudHidden = true
	HudController.setHidden(true)
	enforceHudHidden()

	-- Texts
	resKind.Text = Theme.track(if isRanked then "RANKED · VS" else "CHALLENGE · VS", "three")
	local level = opponentLevelNow()
	resLv.Visible = level ~= nil
	resLv.Text = if level then tostring(level) else ""
	resName.Text = opponentDisplayName()
	resTitle.Text = Theme.track(if won then "VICTORY" else "DEFEAT", "en") .. " "
	resMine.Text = tostring(scoreMine)
	resTheirs.Text = tostring(scoreTheirs)

	-- Table rows
	local rows: { CanvasGroup } = {}
	local rewardsRow, rewardsValue = tableRow(1, "REWARDS")
	-- "FORFEIT" only for the one who left (the winner of a forfeit is not told
	-- off when the anti-farm rule gave nothing).
	fillRewards(rewardsValue, xp, coins, forfeit and not won)
	table.insert(rows, rewardsRow)
	local eloLabel: TextLabel? = nil
	local deltaLabel: TextLabel? = nil
	local rankUp = false
	if isRanked and eloBefore and eloAfter then
		local eloRow, eloValue = tableRow(2, "ELO")
		eloLabel, deltaLabel = fillElo(eloValue, eloBefore, eloAfter)
		table.insert(rows, eloRow)
		local fromIndex = DuelRanks.progress(eloBefore).index
		local toIndex = DuelRanks.progress(eloAfter).index
		rankUp = toIndex > fromIndex
		if not rankUp then
			local rankRow, rankValue = tableRow(3, "RANK")
			local rankText = DuelRanks.rankOf(eloAfter)
			local down = toIndex < fromIndex
			if down then
				rankText = DuelRanks.rankOf(eloBefore) .. " → " .. rankText
			end
			piece(rankValue, 1, {
				TextSize = 11,
				TextColor3 = if down then C.Ink2 else C.Ink,
				Size = UDim2.fromOffset(0, 13),
				TextYAlignment = Enum.TextYAlignment.Bottom,
				Text = Theme.track(rankText, "three"),
			})
			table.insert(rows, rankRow)
		end
	end
	resTable.Size = UDim2.new(1, 0, 0, RES_ROW * #rows)

	-- Start state
	resultLayer.GroupTransparency = 0
	resultLayer.Visible = true
	resEdges.GroupTransparency = 1
	resEdges.Visible = not won
	resBand.BackgroundTransparency = 1
	barTop.Size = UDim2.new(1, 0, 0, 0)
	barBottom.Size = UDim2.new(1, 0, 0, 0)
	resEyebrow.GroupTransparency = 1
	resTitle.TextTransparency = 1
	resScore.GroupTransparency = 1
	upEyebrow.TextTransparency = 1
	upName.TextTransparency = 1
	upLadderFrame.Visible = false
	if rankUp and eloBefore and eloAfter then
		upName.Text = Theme.track(DuelRanks.rankOf(eloAfter), "thin")
		paintLadder(upLadder, eloBefore)
	end
	local left = math.max(returnAt - serverNow(), 0)
	backFill.Size = UDim2.fromScale(math.clamp(left / D.RESULT_TIME, 0, 1), 1)
	Theme.tween(backFill, left, { Size = UDim2.fromScale(0, 1) }, LINEAR)
	backNum.Text = string.format("%.1f", left)

	-- 0 s: bars, grade, band, edges
	Theme.tween(barTop, 0.35, { Size = UDim2.new(1, 0, 0, BAR_HEIGHT) }, QUART)
	Theme.tween(barBottom, 0.35, { Size = UDim2.new(1, 0, 0, BAR_HEIGHT) }, QUART)
	Theme.tween(resBand, 0.4, { BackgroundTransparency = 0 })
	if won then
		Theme.tween(resultCC, 0.4, { Saturation = -0.6, Brightness = -0.1, Contrast = 0 })
	else
		Theme.tween(resEdges, 0.4, { GroupTransparency = 0 })
		Theme.tween(resultCC, 0.4, { Saturation = -0.85, Brightness = -0.2, Contrast = 0.1 })
	end
	after(0.15, "result", function()
		Theme.tween(resEyebrow, 0.3, { GroupTransparency = 0 })
	end)
	after(0.2, "result", function()
		Theme.tween(resTitle, 0.6, { TextTransparency = 0 })
	end)
	after(0.35, "result", function()
		Theme.tween(resScore, 0.25, { GroupTransparency = 0 })
	end)
	for index, row in rows do
		after(0.5 + (index - 1) * 0.06, "result", function()
			Theme.tween(row, 0.2, {
				GroupTransparency = 0,
				Position = UDim2.fromOffset(0, (index - 1) * RES_ROW),
			}, QUART)
		end)
	end
	local counted = eloLabel
	local delta = deltaLabel
	if counted and delta and eloBefore and eloAfter then
		after(0.8, "result", function()
			local counter = Instance.new("NumberValue")
			counter.Value = eloBefore
			counter.Parent = resTable
			table.insert(resultTrash, counter)
			counter.Changed:Connect(function(value: number)
				counted.Text = tostring(math.floor(value + 0.5))
			end)
			Theme.tween(counter, 0.6, { Value = eloAfter })
			after(0.6, "result", function()
				counted.Text = tostring(eloAfter)
				Theme.tween(delta, 0.15, { TextTransparency = 0 })
			end)
		end)
	end
	if rankUp and eloBefore and eloAfter then
		after(1.4, "result", function()
			Theme.tween(upEyebrow, 0.25, { TextTransparency = 0 })
			upName.Position = UDim2.fromOffset(0, 256)
			Theme.tween(upName, 0.4, {
				TextTransparency = 0,
				Position = UDim2.fromOffset(0, 250),
			}, QUART)
			upLadderFrame.Visible = true
			animateLadder(upLadder, eloBefore, eloAfter)
			-- (The level-up sound is not chosen yet: no sound here either.)
		end)
	end
end

-- The result screen goes away and the HUD comes back (nothing if it is
-- not showing).
tearDownResult = function()
	if not resultShown then
		return
	end
	resultShown = false
	bump("result")
	clearResultRows()
	Theme.tween(resultLayer, 0.3, { GroupTransparency = 1 }, QUAD, IN)
	Theme.tween(barTop, 0.3, { Size = UDim2.new(1, 0, 0, 0) }, QUAD, IN)
	Theme.tween(barBottom, 0.3, { Size = UDim2.new(1, 0, 0, 0) }, QUAD, IN)
	Theme.tween(resultCC, 0.5, { Saturation = 0, Brightness = 0, Contrast = 0 })
	after(0.3, "result", function()
		resultLayer.Visible = false
	end)
	restoreHud()
end

-- Back in the free arena: everything goes, the HUD comes back.
local function finishResult()
	tearDownResult()
	watchOpponent(nil)
	opponentId = nil
	round = 0
	setState(if player:GetAttribute("InQueue") == true then "Searching" else "Idle")
	-- A request that arrived during the result is shown now (if still valid).
	local deferred = deferredChallenge
	deferredChallenge = nil
	if deferred and deferred.expiresAt - serverNow() > 1 then
		showChallenge(deferred.from, deferred.name, deferred.expiresAt)
	end
end

------------------------------------------------------------------------------
-- DuelEvent handlers
------------------------------------------------------------------------------

local handlers: { [string]: (data: { [string]: any }) -> () } = {}

handlers.Challenged = function(data)
	local from = readNumber(data.from)
	local expiresAt = readNumber(data.expiresAt)
	if from == nil or expiresAt == nil or state == "InMatch" then
		return
	end
	if state == "Result" then
		-- The server can send one here (the match is over for it): keep it
		-- for when the result screen leaves.
		deferredChallenge = { from = from, name = readString(data.name, ""), expiresAt = expiresAt }
		return
	end
	showChallenge(from, readString(data.name, ""), expiresAt)
end

handlers.Declined = function(data)
	local userId = readNumber(data.userId) or 0
	local name = readString(data.name, "")
	local reason = readString(data.reason, "DECLINED")
	if userId ~= 0 then
		declined[userId] = { reason = reason, name = name, at = os.clock() }
		-- Refused before it was sent: the server's cooldown did not start.
		if reason ~= "DECLINED" and reason ~= "EXPIRED" and reason ~= "COOLDOWN" then
			sentAt[userId] = nil
		end
	end
	-- Same slot as the prompt: a challenge waiting for YOUR answer wins.
	if promptMode ~= "challenge" and state ~= "InMatch" and state ~= "Result" then
		showNotice(userId, name, reason)
	end
	changed.fire(state)
end

handlers.Queue = function(data)
	if data.searching == true then
		searchingSince = readNumber(data.since) or serverNow()
		if state == "Idle" or state == "Searching" then
			setState("Searching")
		end
	else
		searchingSince = nil
		-- (Also ends a "waiting for a free arena" the server called off.)
		if state == "Searching" or state == "Waiting" then
			setState("Idle")
		end
	end
end

handlers.Waiting = function(data)
	tearDownResult()
	rememberOpponent(readNumber(data.opponent))
	ranked = data.ranked == true
	-- The match is set: any other request on screen is void (server side too).
	if promptMode == "challenge" then
		leavePrompt(0.2)
	end
	setState("Waiting")
end

handlers.Start = function(data)
	tearDownResult()
	deferredChallenge = nil
	rememberOpponent(readNumber(data.opponent))
	ranked = data.ranked == true
	round = 0
	scoreMine, scoreTheirs = 0, 0
	searchingSince = nil
	if promptMode ~= "none" then
		leavePrompt(0.2)
	end
	watchOpponent(opponentId)
	-- The fight starts: the menu must not hide the countdown.
	if MenuController.getOpen() ~= nil then
		MenuController.close()
	end
	showTop()
	setState("InMatch")
end

handlers.Round = function(data)
	if state ~= "InMatch" then
		return
	end
	round = readNumber(data.round) or (round + 1)
	scoreMine, scoreTheirs = readScore(data.score)
	setTopRound(round, true)
	setDigit(topMine, scoreMine, false)
	setDigit(topTheirs, scoreTheirs, false)
	-- New round: full health for both (the server resets it right away).
	shownOppHealth = -1
	if oppFillTween then
		oppFillTween:Cancel()
	end
	if oppGhostTween then
		oppGhostTween:Cancel()
	end
	bump("ghost")
	oppFill.Size = UDim2.fromScale(1, 1)
	oppGhost.Size = UDim2.fromScale(1, 1)
	local fightAt = readNumber(data.fightAt) or (serverNow() + D.COUNTDOWN)
	playRoundStart(fightAt)
	changed.fire(state)
end

handlers.RoundEnd = function(data)
	if state ~= "InMatch" then
		return
	end
	local roundNumber = readNumber(data.round) or round
	scoreMine, scoreTheirs = readScore(data.score)
	setDigit(topMine, scoreMine, true)
	setDigit(topTheirs, scoreTheirs, true)
	playRoundEnd(roundNumber, data.won == true, data.last == true)
	changed.fire(state)
end

handlers.End = function(data)
	onEnd(data)
end

local function onDuelEvent(kind: unknown, data: unknown)
	if typeof(kind) ~= "string" then
		return
	end
	local handler = handlers[kind]
	if handler then
		handler(if typeof(data) == "table" then data :: { [string]: any } else {})
	end
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

local function update()
	local now = serverNow()

	-- Challenge prompt: seconds left; hidden (still counting) while knocked out.
	if promptMode == "challenge" then
		local left = challengeExpiresAt - now
		if left <= 0 then
			leavePrompt(0.2) -- expired: nothing to send, the server expires it
		else
			timerNum.Text = string.format("%d", math.ceil(left))
		end
	end
	promptHolder.Visible = not isKnockedOut()

	-- The duel block and round beats follow the HUD: hidden while the menu is open.
	playLayer.Visible = MenuController.getOpen() == nil

	-- Waiting for an arena: the server drops the pair silently when one of
	-- you is busy by then (e.g. the opponent started another duel). Checked
	-- for a second, so our own "Start" (which follows their attribute by a
	-- moment when the match is ours) is not mistaken for it.
	local opponent = if state == "Waiting" and opponentId
		then Players:GetPlayerByUserId(opponentId)
		else nil
	if
		opponent
		and opponent:GetAttribute("InDuel") == true
		and player:GetAttribute("InDuel") ~= true
	then
		waitingVoidSince = waitingVoidSince or os.clock()
		if os.clock() - (waitingVoidSince :: number) >= 1 then
			waitingVoidSince = nil
			opponentId = nil
			setState(if player:GetAttribute("InQueue") == true then "Searching" else "Idle")
		end
	else
		waitingVoidSince = nil
	end

	refreshStatus()

	if state == "Result" then
		local clock = os.clock()
		if clock - lastBackUpdate >= 0.1 then
			lastBackUpdate = clock
			backNum.Text = string.format("%.1f", math.max(returnAt - now, 0))
		end
		-- The server teleports us back and clears "InDuel" (or a safety delay).
		local back = player:GetAttribute("InDuel") ~= true and now >= returnAt - 1
		if back or now >= returnAt + 2 then
			finishResult()
		end
	end

	-- Forget old challenges / refusals (the menu redraws on the signal).
	local clock = os.clock()
	local expired = false
	for userId, sent in sentAt do
		if now - sent >= D.CHALLENGE_COOLDOWN then
			sentAt[userId] = nil
			expired = true
		end
	end
	for userId, entry in declined do
		if clock - entry.at >= DECLINED_SHOW then
			declined[userId] = nil
			expired = true
		end
	end
	if expired then
		changed.fire(state)
	end
end

------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------

local MODES: { [DuelState]: DuelMode } = {
	Idle = "idle",
	Searching = "searching",
	Waiting = "waiting",
	InMatch = "duel",
	Result = "duel",
}

-- A snapshot of everything the menu needs (a copy: changing it changes nothing).
function DuelController.getState(): DuelInfo
	local sent: { [number]: number } = {}
	for userId, at in sentAt do
		sent[userId] = at + D.CHALLENGE_COOLDOWN
	end
	local refusals: { [number]: string } = {}
	local clock = os.clock()
	for userId, entry in declined do
		if clock - entry.at < DECLINED_SHOW then
			refusals[userId] = entry.reason
		end
	end
	return {
		mode = MODES[state],
		phase = state,
		searchingSince = if state == "Searching" then searchingSince else nil,
		opponent = opponentId,
		ranked = ranked,
		round = round,
		scoreMine = scoreMine,
		scoreTheirs = scoreTheirs,
		sent = sent,
		declined = refusals,
	}
end

-- "Idle" | "Searching" | "Waiting" | "InMatch" | "Result"
function DuelController.getPhase(): DuelState
	return state
end

-- `callback(state)` on every change of the state, of a sent challenge or a refusal.
function DuelController.onStateChanged(callback: (DuelState) -> ()): Signal.Connection
	return changed.connect(callback)
end

function DuelController.onChanged(callback: (DuelState) -> ()): Signal.Connection
	return changed.connect(callback)
end

-- Seconds before `userId` can be challenged again (0 = now).
function DuelController.getChallengeCooldown(userId: number): number
	local sent = sentAt[userId]
	if sent == nil then
		return 0
	end
	return math.max(0, D.CHALLENGE_COOLDOWN - (serverNow() - sent))
end

-- Challenges `userId` (ignored while the cooldown on them runs).
function DuelController.challenge(userId: number)
	if DuelController.getChallengeCooldown(userId) > 0 then
		return
	end
	sentAt[userId] = serverNow()
	declined[userId] = nil
	Remotes.DuelChallenge:FireServer(userId)
	changed.fire(state)
end

-- The last refusal from `userId`, during the 3 s the menu row shows it.
function DuelController.getDeclined(userId: number): Declined?
	local entry = declined[userId]
	if entry and os.clock() - entry.at < DECLINED_SHOW then
		return entry
	end
	return nil
end

-- The sentence for a refusal: "Vex declined", "Vex is in combat"...
function DuelController.declinedSentence(reason: string, name: string): string
	if reason == "COOLDOWN" then
		return COOLDOWN_SENTENCE
	end
	return name .. " " .. (DECLINED_WORDS[reason] or "declined")
end

function DuelController.findMatch()
	Remotes.DuelQueue:FireServer(true)
end

function DuelController.cancelSearch()
	Remotes.DuelQueue:FireServer(false)
end

-- Seconds since the ranked search started (0 if not searching).
function DuelController.getSearchTime(): number
	local since = searchingSince
	return if since then math.max(0, serverNow() - since) else 0
end

-- The ELO gap the matchmaking accepts right now (it widens every 5 s).
function DuelController.getSearchRange(): number
	return D.MATCH_RANGE + D.MATCH_RANGE_GROWTH * math.floor(DuelController.getSearchTime() / 5)
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function DuelController.init()
	gui = Theme.make("ScreenGui", {
		Name = "DuelGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = DISPLAY_ORDER,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildTop()
	buildRoundBeats()
	buildPrompt()
	buildStatus()
	buildResult()
	Remotes.DuelEvent.OnClientEvent:Connect(onDuelEvent)
end

function DuelController.start()
	acceptButton.Activated:Connect(function()
		answer(true)
	end)
	declineButton.Activated:Connect(function()
		answer(false)
	end)

	-- The challenger left: their request goes. The opponent we were waiting
	-- with left: the server drops the match silently, we go back to idle.
	Players.PlayerRemoving:Connect(function(leaving)
		if challengeFrom == leaving.UserId and promptMode == "challenge" then
			leavePrompt(0.2)
		end
		local deferred = deferredChallenge
		if deferred and deferred.from == leaving.UserId then
			deferredChallenge = nil
		end
		if state == "Waiting" and opponentId == leaving.UserId then
			opponentId = nil
			setState(if player:GetAttribute("InQueue") == true then "Searching" else "Idle")
		end
		sentAt[leaving.UserId] = nil
		declined[leaving.UserId] = nil
	end)

	-- "Block duel requests" turned on while a request is showing: declined.
	-- (Read from the save and from the "BlocksDuels" attribute the server
	-- sets, whichever arrives first.)
	PlayerDataController.onChanged(function(data)
		if data.settings.blockDuels == true and promptMode == "challenge" then
			answer(false)
		end
	end)
	player:GetAttributeChangedSignal("BlocksDuels"):Connect(function()
		if player:GetAttribute("BlocksDuels") == true and promptMode == "challenge" then
			answer(false)
		end
	end)

	-- The status line: clicking MENU while it shows opens the DUEL section.
	local menuGui = player:WaitForChild("PlayerGui"):WaitForChild("Menu", 10)
	local found = if menuGui then menuGui:FindFirstChild("MenuButton") else nil
	if found and found:IsA("GuiButton") then
		menuButton = found
		-- Read at the press (InputBegan comes before Activated): MenuController's
		-- own Activated handler may run first and open the menu, which hides
		-- the status line before ours runs.
		local statusAtPress = false
		found.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				statusAtPress = statusShown
			end
		end)
		found.Activated:Connect(function()
			if statusAtPress or statusShown then
				statusAtPress = false
				task.defer(MenuController.open, "Duel")
			end
		end)
	end

	MenuController.onOpenChanged(function()
		refreshStatus()
	end)
	RunService.RenderStepped:Connect(enforceHudHidden)
	RunService.Heartbeat:Connect(update)
end

return DuelController
