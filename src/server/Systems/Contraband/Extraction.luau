--!strict
-- Extraction (v2): the server side of taking bio-elements out of a ready shell.
--
-- What the player does (ExtractionController draws it):
--   hold E "Extract" on the ready vat → the cutter opens the shell's chest seam BY ITSELF
--   (no gesture) → 4 to 6 stylised bio-elements show in the cavity → the player lifts out the
--   ones he wants (click-and-hold), one per capsule, up to `slots` capsules → done.
--
-- What the SERVER decides (never the client):
--   • the contents: rolled from the culture's saved seed (Lab.seed). Stopping before any pick
--     puts the culture back to Ready with the SAME seed: cancelling never rerolls;
--   • every score: KIND_BASE + CONDITION_SCORE + a small hidden roll fixed by (seed, index),
--     then the grade (Grades.fromScore). The client only ever sees kind, condition and a
--     coarse 0..3 "viability" (exactly what the player sees on screen);
--   • the timing: no pick before the seam is open (revealAt), at least PICK_MIN_GAP s between
--     two picks, the cooling bar (endsAt), a TIMEOUT safety;
--   • the slots: min(CAPSULES, room in the stash / lab cases) fixed at the start.
--
-- The client sends Remotes.ExtractAction(sessionId, action, index?):
--   "Pick" index   lift element `index` (a whole number 1..#elements, not picked yet)
--   "Done"         finish now (≥ 1 pick) — with 0 picks it is the same as "Stop"
--   "Stop"         stop: 0 picks → culture Ready again (same contents); ≥ 1 pick → finished
-- Every message is checked (types, NaN, ranges, session id, own lab, alive); more than
-- MAX_INVALID bad ones abort the session; RateLimiter 6 burst, 0.6 per s.
--
-- A pick is REAL at once: the core is made in the Ledger right away (a free cradle of a case
-- lying in the lab, else the stash; never lost: over the stash limit if it must), the stash is
-- saved, and the client gets ExtractPicked { index, slot, inert, kind, grade?, toCase }. A
-- husk wastes its capsule (inert, no core). The end (all slots filled, Done, time out, Stop /
-- death / leaving after ≥ 1 pick): culture Empty, ExtractDone { cores, inert, toCase }.

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

-- The client's intro before the cut starts (the hand takes the cutter): the seam is open
-- INTRO_TIME + CUT_TIME after the start. (Server clock: a little earlier than the client
-- sees it, which only makes the check more lenient, never stricter.)
local INTRO_TIME = 0.9
-- Seconds after the cooling bar ends before the server ends the session itself (the client
-- normally sends "Done" on time; this covers a slow or silent client).
local END_GRACE = 1.5

type Element = {
	kind: Types.ElementKind,
	condition: Types.ElementCondition,
	score: number, -- server only (never sent)
	viability: number,
}

type Session = {
	id: number,
	player: Player,
	seed: number,
	startedAt: number, -- os.clock()
	revealAt: number, -- os.clock(): picks accepted from here
	endsAt: number, -- os.clock(): the cooling bar runs out
	revealServer: number, -- the same two moments on workspace:GetServerTimeNow() (client clock)
	endsServer: number,
	slots: number,
	elements: { Element },
	picked: { number },
	lastPickAt: number,
	invalid: number,
	cores: { { kind: Types.ElementKind, grade: Types.CoreGrade, worth: number } },
	inert: number,
	toCase: boolean,
}

local Extraction = {}

local sessions: { [Player]: Session } = {}
local nextSessionId = 0
local actionLimiter = RateLimiter.new(6, 0.6) -- burst 6, then 6 per 10 s

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
			table.insert(
				elements,
				{ kind = "Husk", condition = "Intact", score = 0, viability = 0 }
			)
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
			phase = nil,
			revealAt = 0,
			endsAt = 0,
			slots = 0,
			elements = {},
			picked = {},
		}
	end
	local shown: { Types.ExtractElement } = {}
	for _, element in session.elements do
		-- (never the score: only what the player can see)
		table.insert(shown, {
			kind = element.kind,
			condition = element.condition,
			viability = element.viability,
		})
	end
	return {
		active = true,
		sessionId = session.id,
		phase = if os.clock() >= session.revealAt then "Select" else "Cut",
		revealAt = session.revealServer,
		endsAt = session.endsServer,
		slots = session.slots,
		elements = shown,
		picked = table.clone(session.picked),
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

-- The normal end (≥ 1 pick): the culture is used up.
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

-- Ends a session. With no pick yet the culture goes back to Ready with the SAME seed (the
-- same elements next time); after a pick it is a normal end (the sealed cores stay).
function Extraction.abort(player: Player, why: string)
	local session = sessions[player]
	if session == nil then
		return
	end
	if #session.picked > 0 then
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

-- Lifts element `index` into the next capsule (all checks done by the caller).
local function pick(session: Session, index: number)
	local player = session.player
	local element = session.elements[index]
	table.insert(session.picked, index)
	session.lastPickAt = os.clock()
	local slot = #session.picked
	if slot == 1 then
		-- (first element taken: the saved culture is used up NOW, before any core is created,
		-- so a crash can never give back both the cores and the same culture)
		Lab.consume(player)
	end
	local payload: Types.ExtractPickedPayload
	if element.kind == "Husk" then
		session.inert += 1
		payload =
			{ index = index, slot = slot, inert = true, kind = "Husk", grade = nil, toCase = false }
	else
		local grade: Types.CoreGrade = Grades.fromScore(element.score)
		local owner = player.UserId
		local location, toCase = destination(player)
		local id: string? = nil
		if location then
			id =
				Ledger.create(owner, grade, element.score, os.time(), location, false, element.kind)
		end
		if id == nil then
			-- (no room after all: never lose a core, put it on the stash over the limit)
			toCase = false
			Ledger.create(
				owner,
				grade,
				element.score,
				os.time(),
				Ledger.bench(owner),
				true,
				element.kind
			)
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
	if #session.picked >= session.slots then
		finish(session, "all capsules filled")
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
	local serverNow = workspace:GetServerTimeNow()
	local untilReveal = INTRO_TIME + E.CUT_TIME
	sessions[player] = {
		id = nextSessionId,
		player = player,
		seed = seed,
		startedAt = now,
		revealAt = now + untilReveal,
		endsAt = now + untilReveal + E.SELECT_TIME,
		revealServer = serverNow + untilReveal,
		endsServer = serverNow + untilReveal + E.SELECT_TIME,
		slots = math.clamp(free, 1, E.CAPSULES),
		elements = Extraction.roll(seed),
		picked = {},
		lastPickAt = -math.huge,
		invalid = 0,
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

local function invalid(session: Session, why: string)
	session.invalid += 1
	Guard.debug(`{session.player.Name}: bad ExtractAction ({why})`)
	if session.invalid > E.MAX_INVALID then
		Extraction.abort(session.player, "too many bad messages")
	end
end

local function onAction(player: Player, sessionId: any, action: any, index: any)
	local session = sessions[player]
	if session == nil then
		return
	end
	-- (only picks are rate-limited: a dropped "Stop" would leave the player frozen in place
	-- while his own screen has already given the camera back)
	if action == "Pick" and not actionLimiter.allow(player) then
		return
	end
	if not isWhole(sessionId, 1, 2 ^ 31) or sessionId ~= session.id then
		invalid(session, "session id")
		return
	end
	if action ~= "Pick" and action ~= "Done" and action ~= "Stop" then
		invalid(session, "action")
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
	if action == "Done" or action == "Stop" then
		Extraction.abort(player, if action == "Done" then "done" else "stopped by the player")
		return
	end
	-- "Pick"
	if not isWhole(index, 1, #session.elements) then
		invalid(session, "index")
		return
	end
	if table.find(session.picked, index) then
		invalid(session, "already picked")
		return
	end
	local now = os.clock()
	if now < session.revealAt then
		invalid(session, "before the seam is open")
		return
	end
	if now > session.endsAt + 0.5 then
		invalid(session, "cooling bar over")
		return
	end
	if now - session.lastPickAt < E.PICK_MIN_GAP then
		invalid(session, "picks too fast")
		return
	end
	if #session.picked >= session.slots then
		invalid(session, "no capsule left")
		return
	end
	pick(session, index :: number)
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
			if player.Parent == nil then
				sessions[player] = nil
			elseif now >= session.endsAt + END_GRACE then
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
