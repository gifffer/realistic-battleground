--!strict
-- Extraction (v3, by hand): the server side of taking bio-elements out of a ready shell.
--
-- What the player does (ExtractionController and BenchVisual draw it, all by hand):
--   hold E "Extract" on the ready vat → pick up the scalpel → drag it along the chest seam
--   twice (the skin, then the membrane) → pull the two panels open (a clip holds each) → grab
--   a bio-element and pull it free → set it in the steel specimen tray → lift it into the cold
--   pass-box (it drops into a capsule that seals) → the next one, up to `slots`, or DONE.
--
-- What the SERVER decides (never the client):
--   • the contents: rolled from the culture's saved seed (Lab.seed). Stopping before any
--     transfer puts the culture back to Ready with the SAME seed: cancelling never rerolls;
--   • every score: KIND_BASE + CONDITION_SCORE + a small hidden roll fixed by (seed, index),
--     then the grade (Grades.fromScore). The client only sees kind, condition and a coarse
--     0..3 "viability";
--   • the ORDER of the steps and the least time between them (Config.Extraction.MIN), on its
--     own clock: a step machine per session (below);
--   • the slots: min(CAPSULES, room in the stash / lab cases) fixed at the start.
-- No accuracy, speed or position sent by the client changes anything: a sloppy cut only costs
-- time (and leaves scratches on the shell). Value comes only from the server's roll.
--
-- THE STEP MACHINE (per session):
--   Intro ─Tool─▶ Incise(layer 0) ─Layer 1─▶ Incise(layer 1) ─Layer 2─▶ Spread
--     ─Spread 1, Spread 2─▶ Harvest ─(all capsules sealed | Done | cooling bar over)─▶ end
--   In Harvest, per element:
--     Nest ─Grab─▶ Pulling ─Free─▶ Held ─Tray─▶ OnTray ─Lift─▶ Held (from the tray)
--       ─Transfer─▶ Sealed
--     Held ─Drop─▶ Loose ─Lift─▶ Held (NOT from the tray: it can't be transferred)
--     Pulling / Held ─Let─▶ Nest (let go over the open chest)
--   At most one element in the hand, at most 2 on the tray, and no Grab once
--   sealed + on the tray + in the hand ≥ slots.
--
-- The client sends Remotes.ExtractAction(sessionId, action, arg?):
--   "Tool"                       the scalpel is in the hand
--   "Layer" 1..2                 a seam layer is cut through
--   "Spread" 1..2                a panel is open (each once)
--   "Grab" / "Free" / "Let" / "Tray" / "Drop" / "Lift" / "Transfer"  element index 1..#elements
--   "Done"                       finish now (≥ 1 transfer; with 0 it is the same as "Stop")
--   "Stop"                       stop: 0 transfers → culture Ready again (same contents);
--                                ≥ 1 transfer → finished
-- Every message is checked (types, NaN, whole numbers, ranges, session id, own lab, alive,
-- the step, the element's state, the least time). A refused one counts as invalid and the
-- server sends the client a fresh ExtractState (it snaps back to the server's state); more
-- than MAX_INVALID refused ones abort the session. RateLimiter: burst 12, 2 per s (a whole
-- run is about 16 messages in 25 s).
--
-- A TRANSFER is real at once: the core is made in the Ledger right away (a free cradle of a
-- case lying in the lab, else the stash; never lost: over the stash limit if it must), the
-- stash is saved, and the client gets ExtractPicked { index, slot, inert, kind, grade?,
-- toCase } (it lights the capsule's grade LED). A husk wastes its capsule (inert, no core).
-- The end (all slots sealed, Done, cooling bar over, time out, Stop / death / leaving after
-- ≥ 1 transfer): culture Empty, ExtractDone { cores, inert, toCase }.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Grades = require(ReplicatedStorage.Shared.Contraband.Grades)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Combat = require(script.Parent.Parent.Combat)
local Movement = require(script.Parent.Parent.Movement)
local PlayerData = require(script.Parent.Parent.PlayerData)
local RateLimiter = require(script.Parent.Parent.Parent.Util.RateLimiter)
local Apartments = require(script.Parent.Apartments)
local Case = require(script.Parent.Case)
local Guard = require(script.Parent.Guard)
local Heat = require(script.Parent.Heat)
local Lab = require(script.Parent.Lab)
local Ledger = require(script.Parent.Ledger)

local E = Config.Extraction
local MIN = E.MIN

-- Seconds after the cooling bar ends before the server ends the session itself (the client
-- normally sends "Done" on time; this covers a slow or silent client).
local END_GRACE = 1.5
-- An element left in the hand / on the tray this long after it came free is "warm"
-- (only with E.WARM_PENALTY > 0).
local WARM_AFTER = 15
local MAX_ON_TRAY = 2

type Element = {
	kind: Types.ElementKind,
	condition: Types.ElementCondition,
	score: number, -- server only (never sent)
	viability: number,
	state: Types.ElementState,
	fromTray: boolean, -- Held: lifted from the specimen tray (only those can be transferred)
	freedAt: number, -- os.clock() when it came free of its nest (warming)
}

type Session = {
	id: number,
	player: Player,
	seed: number,
	startedAt: number, -- os.clock()
	step: Types.ExtractStep,
	layer: number, -- 0..2
	spread: { boolean },
	stepAt: number, -- os.clock() of the last step message (Tool, Layer, Spread)
	handAt: number, -- os.clock() of the last element message
	transferAt: number, -- os.clock() of the last transfer
	coolEnds: number?, -- os.clock(): the cooling bar runs out (from Harvest on)
	coolEndsServer: number?, -- the same on workspace:GetServerTimeNow() (the client's clock)
	slots: number,
	elements: { Element },
	sealed: { number }, -- element indices, in the order they were sealed
	invalid: number,
	acked: number, -- messages handled (the client knows its state is up to date when it matches)
	cores: { { kind: Types.ElementKind, grade: Types.CoreGrade, worth: number } },
	inert: number,
	toCase: boolean,
}

local Extraction = {}

local sessions: { [Player]: Session } = {}
local nextSessionId = 0
local actionLimiter = RateLimiter.new(12, 2) -- burst 12, then 2 per s

------------------------------------------------------------------------------
-- Contents (pure: the same seed always gives the same elements)
------------------------------------------------------------------------------

-- Picks a key of `weights` ({ name = weight }) with `random`, in a FIXED order (`order`), so
-- the same seed gives the same result on every server.
local function weighted(random: Random, weights: { [string]: number }, order: { string }): string
	local total = 0
	for _, name in order do
		total += weights[name] or 0
	end
	local roll = random:NextNumber() * total
	for _, name in order do
		roll -= weights[name] or 0
		if roll < 0 then
			return name
		end
	end
	return order[#order]
end

local KIND_ORDER = { "Cluster", "Pod", "Coil" }
local CONDITION_ORDER = { "Intact", "Bruised", "Ruptured" }

-- The score of a (non-husk) element before the hidden roll.
local function baseScore(kind: string, condition: string): number
	local bases: { [string]: number } = E.KIND_BASE :: any
	local conditions: { [string]: number } = E.CONDITION_SCORE :: any
	return (bases[kind] or 0) + (conditions[condition] or 0)
end

-- 0..3 bars for the monitor: coarse, from the score band (no roll in it).
local function viabilityOf(kind: string, condition: string): number
	if kind == "Husk" then
		return 0
	end
	local score = baseScore(kind, condition)
	if score >= E.GRADE_A then
		return 3
	elseif score >= E.GRADE_B then
		return 2
	end
	return 1
end

-- The culture's elements: 4..6, husks 0 (4 elements), 1 (5) or 1–2 (6), always enough real
-- ones to fill every capsule.
function Extraction.roll(seed: number): { Element }
	local random = Random.new(seed)
	local count = random:NextInteger(E.ELEMENTS[1], E.ELEMENTS[2])
	local husks = if count <= 4 then 0 elseif count == 5 then 1 else random:NextInteger(1, 2)
	husks = math.clamp(husks, 0, math.max(0, count - E.CAPSULES))
	-- which indices are husks
	local isHusk: { [number]: boolean } = {}
	local free: { number } = {}
	for index = 1, count do
		table.insert(free, index)
	end
	for _ = 1, husks do
		local at = random:NextInteger(1, #free)
		isHusk[free[at]] = true
		table.remove(free, at)
	end
	local elements: { Element } = {}
	for index = 1, count do
		if isHusk[index] then
			table.insert(elements, {
				kind = "Husk",
				condition = "Intact",
				score = 0,
				viability = 0,
				state = "Nest",
				fromTray = false,
				freedAt = 0,
			})
		else
			local kind: Types.ElementKind =
				weighted(random, E.KIND_WEIGHT :: any, KIND_ORDER) :: any
			local condition: Types.ElementCondition =
				weighted(random, E.CONDITION_WEIGHT :: any, CONDITION_ORDER) :: any
			-- the hidden roll: its own generator per index (fixed whatever was picked before)
			local roll = Random.new(seed + index):NextInteger(-E.ROLL, E.ROLL)
			local element: Element = {
				kind = kind,
				condition = condition,
				score = math.clamp(baseScore(kind, condition) + roll, 0, 100),
				viability = viabilityOf(kind, condition),
				state = "Nest",
				fromTray = false,
				freedAt = 0,
			}
			table.insert(elements, element)
		end
	end
	return elements
end

------------------------------------------------------------------------------
-- State to the client
------------------------------------------------------------------------------

local function statePayload(session: Session?): Types.ExtractStatePayload
	if session == nil then
		return {
			active = false,
			sessionId = 0,
			step = nil,
			layer = 0,
			spread = { false, false },
			coolEnds = nil,
			slots = 0,
			sealed = 0,
			elements = {},
			acked = 0,
		}
	end
	local shown: { Types.ExtractElement } = {}
	for _, element in session.elements do
		-- (never the score: only what the player can see)
		table.insert(shown, {
			kind = element.kind,
			condition = element.condition,
			viability = element.viability,
			state = element.state,
		})
	end
	return {
		active = true,
		sessionId = session.id,
		step = session.step,
		layer = session.layer,
		spread = table.clone(session.spread),
		coolEnds = session.coolEndsServer,
		slots = session.slots,
		sealed = #session.sealed,
		elements = shown,
		acked = session.acked,
	}
end

function Extraction.pushState(player: Player)
	Guard.sendExtractState(player, statePayload(sessions[player]))
end

------------------------------------------------------------------------------
-- Session life
------------------------------------------------------------------------------

local function clearPlayer(player: Player)
	player:SetAttribute("Extracting", nil)
	Movement.setSpeedModifier(player, "Extract", nil)
end

local function isPrivateServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
end

-- Where a new core goes: (location, toCase) or nil if there is no room.
local function destination(player: Player): (Ledger.Location?, boolean)
	local owner = player.UserId
	local caseId, slot = Case.freeCradleInLab(owner)
	if caseId and slot then
		return Ledger.inCase(caseId, slot), true
	end
	if Ledger.benchCount(owner) < Ledger.stashMax() then
		return Ledger.bench(owner), false
	end
	return nil, false
end

-- How many cores fit right now (at least the stash's free places, plus one if a lab case has
-- a free cradle; picks can still go over the stash limit rather than be lost).
local function room(player: Player): number
	local owner = player.UserId
	local free = math.max(0, Ledger.stashMax() - Ledger.benchCount(owner))
	if Case.freeCradleInLab(owner) ~= nil then
		free += 1
	end
	return free
end

-- The normal end (≥ 1 transfer): the culture is used up.
local function finish(session: Session, why: string)
	local player = session.player
	if sessions[player] ~= session then
		return
	end
	sessions[player] = nil
	clearPlayer(player)
	Lab.setStage(player, "Empty") -- (also clears the culture's seed)
	PlayerData.update(player, function(data)
		data.contraband.log.extractions += 1
	end)
	Heat.record(player, "extractions")
	local payload: Types.ExtractDonePayload = {
		cores = table.clone(session.cores),
		inert = session.inert,
		toCase = session.toCase,
	}
	Guard.sendExtractDone(player, payload)
	Extraction.pushState(player)
	Guard.debug(`{player.Name}: extraction done ({why}), {#session.cores} core(s)`)
end

-- Ends a session. With no transfer yet the culture goes back to Ready with the SAME seed (the
-- same elements next time); after a transfer it is a normal end (the sealed cores stay).
function Extraction.abort(player: Player, why: string)
	local session = sessions[player]
	if session == nil then
		return
	end
	if #session.sealed > 0 then
		finish(session, why)
		return
	end
	sessions[player] = nil
	clearPlayer(player)
	if Lab.stage(player) == "Extracting" then
		Lab.setStage(player, "Ready")
	end
	Extraction.pushState(player)
	if why == "cooling bar ran out" then
		Guard.notice(player, "The tissue cooled. The vat is still ready.")
	end
	Guard.debug(`{player.Name}: extraction stopped ({why})`)
end

-- Seals element `index` into the next capsule (all checks done by the caller): the real pick.
local function transfer(session: Session, index: number)
	local player = session.player
	local element = session.elements[index]
	element.state = "Sealed"
	element.fromTray = false
	table.insert(session.sealed, index)
	session.transferAt = os.clock()
	local slot = #session.sealed
	if slot == 1 then
		-- (first element sealed: the saved culture is used up NOW, before any core is created,
		-- so a crash can never give back both the cores and the same culture)
		Lab.consume(player)
	end
	local payload: Types.ExtractPickedPayload
	if element.kind == "Husk" then
		session.inert += 1
		payload =
			{ index = index, slot = slot, inert = true, kind = "Husk", grade = nil, toCase = false }
	else
		local score = element.score
		if E.WARM_PENALTY > 0 and os.clock() - element.freedAt > WARM_AFTER then
			score = math.max(0, score - E.WARM_PENALTY)
		end
		local grade: Types.CoreGrade = Grades.fromScore(score)
		local owner = player.UserId
		local location, toCase = destination(player)
		local id: string? = nil
		if location then
			id = Ledger.create(owner, grade, score, os.time(), location, false, element.kind)
		end
		if id == nil then
			-- (no room after all: never lose a core, put it on the stash over the limit)
			toCase = false
			Ledger.create(owner, grade, score, os.time(), Ledger.bench(owner), true, element.kind)
		end
		session.toCase = session.toCase or toCase
		table.insert(session.cores, {
			kind = element.kind,
			grade = grade,
			worth = Grades.priceOf(grade, isPrivateServer()),
		})
		payload = {
			index = index,
			slot = slot,
			inert = false,
			kind = element.kind,
			grade = grade,
			toCase = toCase,
		}
		Lab.benchChanged(player) -- (saved at once: a sealed core is never lost)
	end
	Guard.sendExtractPicked(player, payload)
	if #session.sealed >= session.slots then
		finish(session, "all capsules sealed")
	end
end

-- The VatPrompt "Extract" (Lab checked: own lab, prompt rules, stage Ready).
function Extraction.begin(player: Player)
	if sessions[player] or Lab.stage(player) ~= "Ready" then
		return
	end
	local character = player.Character
	if character == nil or not Guard.canAct(player) or not Combat.isIdle(character) then
		return
	end
	if character:GetAttribute("Carrying") ~= nil then
		Guard.notice(player, "Set the case down first (G).")
		return
	end
	local bench = Apartments.labPart(player, "BenchAnchor")
	local vat = Apartments.labPart(player, "VatCore")
	local nearBench = bench ~= nil and Guard.near(player, bench.Position, E.START_DISTANCE)
	local nearVat = vat ~= nil and Guard.near(player, vat.Position, E.START_DISTANCE)
	if not nearBench and not nearVat then
		return
	end
	local free = room(player)
	if free <= 0 or destination(player) == nil then
		Guard.notice(player, "Stash full: load your case.")
		return
	end
	local seed = Lab.seed(player)
	if seed == 0 then
		return -- (should not happen: a Ready culture always has a seed)
	end
	nextSessionId += 1
	local now = os.clock()
	sessions[player] = {
		id = nextSessionId,
		player = player,
		seed = seed,
		startedAt = now,
		step = "Intro",
		layer = 0,
		spread = { false, false },
		stepAt = now,
		handAt = -math.huge,
		transferAt = -math.huge,
		coolEnds = nil,
		coolEndsServer = nil,
		slots = math.clamp(free, 1, E.CAPSULES),
		elements = Extraction.roll(seed),
		sealed = {},
		invalid = 0,
		acked = 0,
		cores = {},
		inert = 0,
		toCase = false,
	}
	player:SetAttribute("Extracting", true)
	Movement.setSpeedModifier(player, "Extract", 0)
	Lab.setStage(player, "Extracting")
	Extraction.pushState(player)
end

------------------------------------------------------------------------------
-- ExtractAction (client → server: untrusted)
------------------------------------------------------------------------------

local function isWhole(value: any, low: number, high: number): boolean
	return Guard.isFinite(value) and value % 1 == 0 and value >= low and value <= high
end

-- A refused message: counted, logged, and the client gets the server's state back (so an
-- element that moved on its screen snaps back to where the server has it).
local function refuse(session: Session, why: string)
	session.invalid += 1
	Guard.debug(`{session.player.Name}: refused ExtractAction ({why})`)
	if session.invalid > E.MAX_INVALID then
		Extraction.abort(session.player, "too many bad messages")
		return
	end
	Extraction.pushState(session.player)
end

-- Counts of elements per state (for the hand / tray / slot limits).
local function countIn(session: Session, state: Types.ElementState): number
	local n = 0
	for _, element in session.elements do
		if element.state == state then
			n += 1
		end
	end
	return n
end

local function inHand(session: Session): number
	return countIn(session, "Pulling") + countIn(session, "Held")
end

-- The step messages (Tool, Layer, Spread). Returns why it is refused, or nil (done).
local function stepAction(session: Session, action: string, arg: any, now: number): string?
	local since = now - session.stepAt
	if action == "Tool" then
		if session.step ~= "Intro" then
			return "Tool: wrong step"
		end
		if now - session.startedAt < MIN.Tool then
			return "Tool: too early"
		end
		session.step = "Incise"
		session.stepAt = now
		return nil
	elseif action == "Layer" then
		if session.step ~= "Incise" or not isWhole(arg, 1, 2) or arg ~= session.layer + 1 then
			return "Layer: wrong step or layer"
		end
		if since < (if arg == 1 then MIN.Layer1 else MIN.Layer2) then
			return "Layer: too early"
		end
		session.layer = arg
		session.stepAt = now
		if arg == 2 then
			session.step = "Spread"
		end
		return nil
	end
	-- "Spread"
	if session.step ~= "Spread" or not isWhole(arg, 1, 2) or session.spread[arg] then
		return "Spread: wrong step or side"
	end
	local first = not session.spread[1] and not session.spread[2]
	if since < (if first then MIN.Spread else MIN.SpreadGap) then
		return "Spread: too early"
	end
	session.spread[arg] = true
	session.stepAt = now
	if session.spread[1] and session.spread[2] then
		session.step = "Harvest"
		session.coolEnds = now + E.COOL_TIME
		session.coolEndsServer = workspace:GetServerTimeNow() + E.COOL_TIME
		-- (the client starts its cooling bar from this state)
		Extraction.pushState(session.player)
	end
	return nil
end

-- The element messages (Harvest only). Returns why it is refused, or nil (done).
local function elementAction(session: Session, action: string, arg: any, now: number): string?
	if session.step ~= "Harvest" then
		return `{action}: not harvesting yet`
	end
	if not isWhole(arg, 1, #session.elements) then
		return `{action}: bad index`
	end
	local index = arg :: number
	local element = session.elements[index]
	local state = element.state
	local since = now - session.handAt
	if action == "Grab" then
		if state ~= "Nest" then
			return "Grab: not in its nest"
		end
		if inHand(session) > 0 then
			return "Grab: the hand is full"
		end
		if #session.sealed + countIn(session, "OnTray") >= session.slots then
			return "Grab: no capsule left for it"
		end
		if since < MIN.Grab then
			return "Grab: too early"
		end
		element.state = "Pulling"
	elseif action == "Free" then
		if state ~= "Pulling" then
			return "Free: not pulling"
		end
		if since < (if element.kind == "Husk" then MIN.FreeHusk else MIN.Free) then
			return "Free: too early"
		end
		element.state = "Held"
		element.fromTray = false
		element.freedAt = now
	elseif action == "Let" then
		if state ~= "Pulling" and state ~= "Held" then
			return "Let: not in the hand"
		end
		element.state = "Nest"
		element.fromTray = false
	elseif action == "Tray" then
		if state ~= "Held" then
			return "Tray: not in the hand"
		end
		if countIn(session, "OnTray") >= MAX_ON_TRAY then
			return "Tray: the tray is full"
		end
		if since < MIN.Tray then
			return "Tray: too early"
		end
		element.state = "OnTray"
		element.fromTray = false
	elseif action == "Drop" then
		if state ~= "Held" then
			return "Drop: not in the hand"
		end
		if since < MIN.Drop then
			return "Drop: too early"
		end
		element.state = "Loose"
		element.fromTray = false
	elseif action == "Lift" then
		if state ~= "OnTray" and state ~= "Loose" then
			return "Lift: not on the tray or the trolley"
		end
		if inHand(session) > 0 then
			return "Lift: the hand is full"
		end
		if since < MIN.Lift then
			return "Lift: too early"
		end
		element.fromTray = state == "OnTray"
		element.state = "Held"
	else -- "Transfer"
		if state ~= "Held" or not element.fromTray then
			return "Transfer: not lifted from the tray"
		end
		if since < MIN.Transfer or now - session.transferAt < MIN.TransferGap then
			return "Transfer: too early"
		end
		if #session.sealed >= session.slots then
			return "Transfer: no capsule left"
		end
		session.handAt = now
		transfer(session, index)
		return nil
	end
	session.handAt = now
	return nil
end

local STEP_ACTIONS = { Tool = true, Layer = true, Spread = true }
local ELEMENT_ACTIONS =
	{ Grab = true, Free = true, Let = true, Tray = true, Drop = true, Lift = true, Transfer = true }

local function onAction(player: Player, sessionId: any, action: any, arg: any)
	local session = sessions[player]
	if session == nil then
		return
	end
	-- (Stop / Done are never rate-limited: a dropped "Stop" would leave the player frozen in
	-- place while his own screen has already given the camera back)
	local ending = action == "Done" or action == "Stop"
	if not ending and not actionLimiter.allow(player) then
		session.acked += 1
		refuse(session, "rate limit")
		return
	end
	if not isWhole(sessionId, 1, 2 ^ 31) or sessionId ~= session.id then
		refuse(session, "session id")
		return
	end
	session.acked += 1
	if typeof(action) ~= "string" then
		refuse(session, "action type")
		return
	end
	if Guard.body(player) == nil then
		Extraction.abort(player, "not alive")
		return
	end
	if not Apartments.isInOwnLab(player) then
		Extraction.abort(player, "left the lab")
		return
	end
	if ending then
		Extraction.abort(player, if action == "Done" then "done" else "stopped by the player")
		return
	end
	local now = os.clock()
	local refused: string?
	if STEP_ACTIONS[action] then
		refused = stepAction(session, action, arg, now)
	elseif ELEMENT_ACTIONS[action] then
		local cool = session.coolEnds
		if cool and now > cool + 0.5 then
			refused = "cooling bar over"
		else
			refused = elementAction(session, action, arg, now)
		end
	else
		refused = "unknown action"
	end
	if refused then
		refuse(session, refused)
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function Extraction.onLeaving(player: Player)
	if sessions[player] then
		Extraction.abort(player, "left the game")
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		Extraction.abort(player, "respawned")
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				Extraction.abort(player, "died")
			end)
		end
	end)
	player.CharacterRemoving:Connect(function()
		Extraction.abort(player, "body removed")
	end)
end

function Extraction.init()
	Lab.setExtractHandler(Extraction.begin)
end

-- Lifecycle (Contraband/init calls it): remote, players, the cooling bar and timeouts.
function Extraction.start()
	Remotes.ExtractAction.OnServerEvent:Connect(onAction)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	while true do
		task.wait(0.5)
		local now = os.clock()
		for player, session in sessions do
			local cool = session.coolEnds
			if player.Parent == nil then
				sessions[player] = nil
			elseif cool and now >= cool + END_GRACE then
				Extraction.abort(player, "cooling bar ran out")
			elseif now - session.startedAt > E.TIMEOUT then
				Extraction.abort(player, "timed out")
			elseif player:GetAttribute("InLab") ~= true then
				Extraction.abort(player, "left the lab")
			end
		end
	end
end

return Extraction
