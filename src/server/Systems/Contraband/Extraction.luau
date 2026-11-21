--!strict
-- Extraction: the server side of the 6-step mini-game that takes the bio-core out of a ready
-- shell. The client (ExtractionController) plays the gestures; the SERVER decides the order,
-- the timing, the fibre guides and the grade.
--
--   1 UNLOCK  two chest clamps         ExtractStep(id, 1, { clamp = 1|2, accuracy = 0..1 })
--   2 OPEN    the hatch                ExtractStep(id, 2, {})
--   3 SPREAD  the membrane             ExtractStep(id, 3, { steadiness = 0..1 })
--   4 CUT     4 of the 6 fibre guides  ExtractStep(id, 4, { guide = 1..6 })  (once per cut)
--   5 LIFT    the bio-core             ExtractStep(id, 5, { smooth = 0..1 })
--   6 SEAL    into a capsule           ExtractStep(id, 6, {})
--   step 0 = the player stops (Esc).
--
-- Rules:
--   • a step cannot end before Config.Extraction.MIN_TIME[step] seconds: an early "done" is
--     simply held until that time (the client just waits a little);
--   • cuts: a guide only once, at least CUT_MIN_GAP s apart; cutting a decoy costs points;
--   • every message is checked (numbers, ranges, NaN, table size, session, step); more than
--     MAX_INVALID bad ones abort the session; at most 12 messages per 10 s;
--   • the session ends after TIMEOUT s, if the player dies / respawns / leaves, or on step 0:
--     the culture goes back to Ready, nothing is lost.
-- Score = 100 − penalties (Config.Extraction.PENALTY), grade A ≥ 85, B ≥ 60, else C. Mouse
-- gestures can't be measured on the server, so the accuracy numbers come from the client, but
-- they can move the price by ±20 % at most (a perfect bot gains little).
--
-- At the end (one synchronous block): the core is made by the Ledger in the first free cradle
-- of a case lying in the lab, else on the bench (the space is checked BEFORE starting); the
-- culture is Empty again; the client gets ExtractDone { grade, toCase, notes, worth }: the notes
-- say why points were lost (taught on the result card), worth is the buyer's price.

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
local P = E.PENALTY

local STEPS = 6
local MAX_DATA_KEYS = 4
local NOTE_BELOW = 0.7 -- a gesture scored below this gets a line on the result card

type Session = {
	id: number,
	player: Player,
	step: number, -- 1..6
	stepStartedAt: number, -- os.clock()
	stepStartedServer: number, -- workspace:GetServerTimeNow()
	startedAt: number,
	pending: boolean, -- the step is done, waiting for its minimum time
	clamps: { number },
	accuracies: { number },
	correct: { number },
	cut: { number },
	lastCutAt: number,
	wrongCuts: number,
	penalty: number,
	invalid: number,
	notes: { string }, -- why points were lost (shown on the result card)
}

local Extraction = {}

local sessions: { [Player]: Session } = {}
local nextSessionId = 0
local stepLimiter = RateLimiter.new(12, 1.2) -- burst 12, then 12 per 10 s

------------------------------------------------------------------------------
-- State to the client
------------------------------------------------------------------------------

local function statePayload(session: Session?): Types.ExtractStatePayload
	if session == nil then
		return {
			active = false,
			sessionId = 0,
			step = 0,
			stepStartedAt = 0,
			guides = E.GUIDES,
			correct = {},
			cut = {},
			clamps = {},
			minTimes = table.clone(E.MIN_TIME),
		}
	end
	return {
		active = true,
		sessionId = session.id,
		step = session.step,
		stepStartedAt = session.stepStartedServer,
		guides = E.GUIDES,
		correct = table.clone(session.correct),
		cut = table.clone(session.cut),
		clamps = table.clone(session.clamps),
		minTimes = table.clone(E.MIN_TIME),
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

-- Ends a session without a core (stopped, timed out, died...): the culture is Ready again.
function Extraction.abort(player: Player, why: string)
	local session = sessions[player]
	if session == nil then
		return
	end
	sessions[player] = nil
	clearPlayer(player)
	if Lab.stage(player) == "Extracting" then
		Lab.setStage(player, "Ready")
	end
	Extraction.pushState(player)
	Guard.debug(`{player.Name}: extraction stopped ({why})`)
end

-- Where the new core will go: (location, toCase) or nil if there is no room.
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

local function finish(session: Session)
	local player = session.player
	sessions[player] = nil
	clearPlayer(player)
	local score = math.clamp(100 - session.penalty, 0, 100)
	local grade: Types.CoreGrade = Grades.fromScore(score)
	local location, toCase = destination(player)
	local id: string? = nil
	if location then
		id = Ledger.create(player.UserId, grade, score, os.time(), location)
	end
	if id == nil then
		-- (no room after all: never lose the core, put it on the bench over the limit)
		toCase = false
		id =
			Ledger.create(player.UserId, grade, score, os.time(), Ledger.bench(player.UserId), true)
	end
	Lab.setStage(player, "Empty")
	Lab.benchChanged(player)
	PlayerData.update(player, function(data)
		data.contraband.log.extractions += 1
	end)
	Heat.record(player, "extractions")
	local notes = table.clone(session.notes)
	if session.wrongCuts > 0 then
		table.insert(
			notes,
			1,
			if session.wrongCuts == 1 then "1 wrong fibre" else `{session.wrongCuts} wrong fibres`
		)
	end
	local payload: Types.ExtractDonePayload = {
		grade = grade,
		toCase = toCase,
		notes = notes,
		-- (the same price rule as Market: half on a real private server)
		worth = Grades.priceOf(
			grade,
			game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
		),
	}
	Guard.sendExtractDone(player, payload)
	Extraction.pushState(player)
	Guard.debug(`{player.Name}: extraction done, score {math.floor(score)} → {grade}`)
end

-- Moves to the next step (or finishes), no sooner than the step's minimum time.
local function completeStep(session: Session)
	if session.pending then
		return
	end
	session.pending = true
	local waitFor = E.MIN_TIME[session.step] - (os.clock() - session.stepStartedAt)
	local function advance()
		if sessions[session.player] ~= session then
			return -- (aborted meanwhile)
		end
		session.pending = false
		if session.step >= STEPS then
			finish(session)
			return
		end
		session.step += 1
		session.stepStartedAt = os.clock()
		session.stepStartedServer = workspace:GetServerTimeNow()
		Extraction.pushState(session.player)
	end
	if waitFor > 0 then
		task.delay(waitFor, advance)
	else
		advance()
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
	local location = destination(player)
	if location == nil then
		Guard.notice(player, "Stash full: load your case.")
		return
	end
	-- The 4 guides to cut, out of 6, at random.
	local pool: { number } = {}
	for guide = 1, E.GUIDES do
		table.insert(pool, guide)
	end
	local correct: { number } = {}
	for _ = 1, math.min(E.CORRECT_GUIDES, E.GUIDES) do
		table.insert(correct, table.remove(pool, math.random(1, #pool)) :: number)
	end
	table.sort(correct)
	nextSessionId += 1
	local now = os.clock()
	sessions[player] = {
		id = nextSessionId,
		player = player,
		step = 1,
		stepStartedAt = now,
		stepStartedServer = workspace:GetServerTimeNow(),
		startedAt = now,
		pending = false,
		clamps = {},
		accuracies = {},
		correct = correct,
		cut = {},
		lastCutAt = -math.huge,
		wrongCuts = 0,
		penalty = 0,
		invalid = 0,
		notes = {},
	}
	player:SetAttribute("Extracting", true)
	Movement.setSpeedModifier(player, "Extract", 0)
	Lab.setStage(player, "Extracting")
	Extraction.pushState(player)
end

------------------------------------------------------------------------------
-- ExtractStep (client → server: untrusted)
------------------------------------------------------------------------------

-- A 0..1 number from the client (anything else counts as 0).
local function unit(value: any): number
	if not Guard.isFinite(value) then
		return 0
	end
	return math.clamp(value :: number, 0, 1)
end

local function isWhole(value: any, low: number, high: number): boolean
	return Guard.isFinite(value) and value % 1 == 0 and value >= low and value <= high
end

local function invalid(session: Session, why: string)
	session.invalid += 1
	Guard.debug(`{session.player.Name}: bad ExtractStep ({why})`)
	if session.invalid > E.MAX_INVALID then
		Extraction.abort(session.player, "too many bad messages")
	end
end

local function onStep(player: Player, sessionId: any, step: any, data: any)
	if not stepLimiter.allow(player) then
		return
	end
	local session = sessions[player]
	if session == nil then
		return
	end
	if not isWhole(sessionId, 1, math.huge - 1) or sessionId ~= session.id then
		invalid(session, "session id")
		return
	end
	if not isWhole(step, 0, STEPS) then
		invalid(session, "step")
		return
	end
	if step == 0 then
		Extraction.abort(player, "stopped by the player")
		return
	end
	local fields: { [string]: any } = {}
	if data ~= nil then
		if typeof(data) ~= "table" then
			invalid(session, "data")
			return
		end
		local keys = 0
		for key, value in data do
			keys += 1
			if keys > MAX_DATA_KEYS or typeof(key) ~= "string" then
				invalid(session, "data keys")
				return
			end
			fields[key] = value
		end
	end
	if step ~= session.step or session.pending then
		invalid(session, `step {step} while on {session.step}`)
		return
	end
	if not Apartments.isInOwnLab(player) then
		Extraction.abort(player, "left the lab")
		return
	end

	if step == 1 then -- UNLOCK: each clamp once
		local clamp = fields.clamp
		if not isWhole(clamp, 1, 2) or table.find(session.clamps, clamp) then
			invalid(session, "clamp")
			return
		end
		table.insert(session.clamps, clamp)
		table.insert(session.accuracies, unit(fields.accuracy))
		if #session.clamps >= 2 then
			local mean = (session.accuracies[1] + session.accuracies[2]) / 2
			session.penalty += (1 - mean) * P.unlock
			if mean < NOTE_BELOW then
				table.insert(session.notes, "clamps forced")
			end
			completeStep(session)
		else
			Extraction.pushState(player)
		end
	elseif step == 2 or step == 6 then -- OPEN the hatch / SEAL the capsule: nothing to score
		completeStep(session)
	elseif step == 3 then -- SPREAD
		local steadiness = unit(fields.steadiness)
		session.penalty += (1 - steadiness) * P.spread
		if steadiness < NOTE_BELOW then
			table.insert(session.notes, "membrane torn")
		end
		completeStep(session)
	elseif step == 4 then -- CUT: one guide per message
		local guide = fields.guide
		if not isWhole(guide, 1, E.GUIDES) or table.find(session.cut, guide) then
			invalid(session, "guide")
			return
		end
		local now = os.clock()
		if now - session.lastCutAt < E.CUT_MIN_GAP then
			invalid(session, "cuts too fast")
			return
		end
		session.lastCutAt = now
		table.insert(session.cut, guide)
		if not table.find(session.correct, guide) then
			session.wrongCuts += 1
			if session.wrongCuts <= P.wrongCutMax then
				session.penalty += P.wrongCut
			end
		end
		local allCut = true
		for _, needed in session.correct do
			if not table.find(session.cut, needed) then
				allCut = false
				break
			end
		end
		if allCut then
			completeStep(session)
		else
			Extraction.pushState(player)
		end
	elseif step == 5 then -- LIFT: too fast or rough loses points
		local took = os.clock() - session.stepStartedAt
		local fast = math.clamp((E.LIFT_GOOD_TIME - took) / 1, 0, 1)
		local smooth = unit(fields.smooth)
		session.penalty += fast * P.liftFast
		session.penalty += (1 - smooth) * P.liftRough
		if fast > 0.25 then
			table.insert(session.notes, "lifted too fast")
		elseif smooth < NOTE_BELOW then
			table.insert(session.notes, "rough lift")
		end
		completeStep(session)
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

-- Lifecycle (Contraband/init calls it): remote, players, timeouts.
function Extraction.start()
	Remotes.ExtractStep.OnServerEvent:Connect(onStep)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	while true do
		task.wait(1)
		local now = os.clock()
		for player, session in sessions do
			if player.Parent == nil then
				sessions[player] = nil
			elseif now - session.startedAt > E.TIMEOUT then
				Extraction.abort(player, "timed out")
			end
		end
	end
end

return Extraction
