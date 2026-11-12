--!strict
-- Duels: 1v1, best of 3, in arenas built far from the free arena (step 8).
-- SERVER-AUTHORITATIVE.
--
-- Two ways in:
--   • CHALLENGE (not ranked): Duel menu → Remotes.DuelChallenge(target).
--     The target gets 15 s to accept (Remotes.DuelRespond).
--   • RANKED: Remotes.DuelQueue(true) → automatic matchmaking against the
--     closest ELO (the accepted gap widens while you wait).
--
-- A match:
--   1. Both are teleported into a free arena (all busy → they wait in line).
--      Their kit is locked ("InDuel" attribute). Their characters get the
--      same "DuelId": Combat only lets them hit each other.
--   2. Each round: full health / stamina, everything reset, "3, 2, 1, FIGHT"
--      (frozen meanwhile). The first knocked to 0 HP loses the round (no
--      KO on the ground, no finisher: Knockout.setInterceptor).
--   3. First to Config.Duels.ROUNDS_TO_WIN rounds wins. Leaving = forfeit.
--   4. Rewards (XP, coins), ELO for ranked; then back to the free arena.
--
-- Everything the player's UI needs comes through Remotes.DuelEvent (see
-- Types.DuelEventKind) and these Player attributes:
--   "InDuel" (boolean), "Elo" (number), "InQueue" (boolean), "BlocksDuels" (boolean).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Combat = require(script.Parent.Combat)
local Knockout = require(script.Parent.Knockout)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)
local Ragdoll = require(script.Parent.Ragdoll)
local Arenas = require(script.Arenas)

local D = Config.Duels

type Match = {
	id: string,
	a: Player,
	b: Player,
	ranked: boolean,
	arena: Arenas.Arena,
	score: { [Player]: number },
	round: number,
	roundActive: boolean,
	ended: boolean,
	connections: { RBXScriptConnection },
}

type Pending = { from: Player, expires: number }

local Duels = {}

local matches: { [Player]: Match } = {}
local pending: { [Player]: Pending } = {} -- challenged player → challenge
local lastChallengeAt: { [Player]: number } = {}
local queue: { { player: Player, since: number } } = {}
local waitingForArena: { { a: Player, b: Player, ranked: boolean } } = {}
-- "userIdA:userIdB" (sorted) → last rewarded challenge (anti-farm).
local lastRewardedChallenge: { [string]: number } = {}
local nextMatchId = 0

local function send(player: Player, kind: Types.DuelEventKind, data: { [string]: any })
	if player.Parent == Players then
		Remotes.DuelEvent:FireClient(player, kind, data)
	end
end

local function other(match: Match, player: Player): Player
	return if match.a == player then match.b else match.a
end

local function aliveCharacter(player: Player): Model?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid and humanoid.Health > 0 then
		return character
	end
	return nil
end

-- Can `player` start a duel right now? (Not in one, alive, not knocked out.)
local function isFree(player: Player): boolean
	local character = aliveCharacter(player)
	return player.Parent == Players
		and matches[player] == nil
		and character ~= nil
		and not Knockout.isKnockedOut(character)
end

local function inCombat(player: Player): boolean
	local character = player.Character
	return character ~= nil and os.clock() - Knockout.lastHitAt(character) < D.IN_COMBAT_TIME
end

local function inQueue(player: Player): number?
	for index, entry in queue do
		if entry.player == player then
			return index
		end
	end
	return nil
end

local function leaveQueue(player: Player)
	local index = inQueue(player)
	if index then
		table.remove(queue, index)
		player:SetAttribute("InQueue", false)
		send(player, "Queue", { searching = false })
	end
end

local function eloOf(player: Player): number
	local data = PlayerData.getData(player)
	return if data then data.elo else D.START_ELO
end

------------------------------------------------------------------------------
-- Rounds
------------------------------------------------------------------------------

local startRound: (match: Match) -> ()
local endMatch: (match: Match, winner: Player, forfeit: boolean) -> ()

local function scoreFor(match: Match, player: Player): { number }
	return { match.score[player], match.score[other(match, player)] }
end

-- `loser` dropped to 0 HP (or died): the round goes to the other one.
local function endRound(match: Match, loser: Player)
	if match.ended or not match.roundActive then
		return
	end
	match.roundActive = false
	local winner = other(match, loser)
	match.score[winner] += 1
	local loserCharacter = loser.Character
	if loserCharacter then
		Ragdoll.enable(loserCharacter) -- they drop
	end
	local winnerCharacter = winner.Character
	if winnerCharacter then
		Combat.freeze(winnerCharacter, D.ROUND_END_PAUSE)
	end
	for _, player in { match.a, match.b } do
		send(player, "RoundEnd", {
			round = match.round,
			won = player == winner,
			score = scoreFor(match, player),
		})
	end
	task.delay(D.ROUND_END_PAUSE, function()
		if match.ended then
			return
		end
		if match.score[winner] >= D.ROUNDS_TO_WIN then
			endMatch(match, winner, false)
		else
			startRound(match)
		end
	end)
end

-- Waits (a few seconds at most) until both fighters have a living body.
local function waitForBodies(match: Match): boolean
	local deadline = os.clock() + Players.RespawnTime + 5
	while os.clock() < deadline do
		if match.ended then
			return false
		end
		if aliveCharacter(match.a) and aliveCharacter(match.b) then
			return true
		end
		task.wait(0.2)
	end
	return false
end

startRound = function(match: Match)
	if match.ended then
		return
	end
	if not waitForBodies(match) then
		-- One of them never came back: the other wins.
		local a = aliveCharacter(match.a)
		endMatch(match, if a then match.a else match.b, true)
		return
	end
	match.round += 1
	for _, connection in match.connections do
		connection:Disconnect()
	end
	table.clear(match.connections)
	local fightAt = workspace:GetServerTimeNow() + D.COUNTDOWN
	for _, player in { match.a, match.b } do
		local character = aliveCharacter(player) :: Model
		character:SetAttribute("DuelId", match.id)
		Knockout.endProtection(character)
		Combat.resetForRound(character)
		character:PivotTo(if player == match.a then match.arena.spawnA else match.arena.spawnB)
		Combat.freeze(character, D.COUNTDOWN)
		-- Dying some other way (reset...) also loses the round.
		local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
		table.insert(
			match.connections,
			humanoid.Died:Connect(function()
				endRound(match, player)
			end)
		)
		send(player, "Round", {
			round = match.round,
			score = scoreFor(match, player),
			fightAt = fightAt,
		})
	end
	task.delay(D.COUNTDOWN, function()
		if not match.ended then
			match.roundActive = true
		end
	end)
end

------------------------------------------------------------------------------
-- Start / end of a match
------------------------------------------------------------------------------

local function processWaitingList()
	while #waitingForArena > 0 do
		local entry = waitingForArena[1]
		if not (entry.a.Parent == Players and entry.b.Parent == Players) then
			table.remove(waitingForArena, 1)
			continue
		end
		local arena = Arenas.claim()
		if arena == nil then
			return
		end
		table.remove(waitingForArena, 1)
		Arenas.release(arena) -- startMatch claims it again
		Duels.startMatch(entry.a, entry.b, entry.ranked)
	end
end

function Duels.startMatch(a: Player, b: Player, ranked: boolean)
	if not (isFree(a) and isFree(b)) or a == b then
		return
	end
	leaveQueue(a)
	leaveQueue(b)
	pending[a] = nil
	pending[b] = nil
	local arena = Arenas.claim()
	if arena == nil then
		table.insert(waitingForArena, { a = a, b = b, ranked = ranked })
		send(a, "Waiting", {})
		send(b, "Waiting", {})
		return
	end
	nextMatchId += 1
	local match: Match = {
		id = `duel{nextMatchId}`,
		a = a,
		b = b,
		ranked = ranked,
		arena = arena,
		score = { [a] = 0, [b] = 0 },
		round = 0,
		roundActive = false,
		ended = false,
		connections = {},
	}
	matches[a] = match
	matches[b] = match
	for _, player in { a, b } do
		player:SetAttribute("InDuel", true)
		send(player, "Start", { opponent = other(match, player).UserId, ranked = ranked })
	end
	task.spawn(startRound, match)
end

-- ELO change for the winner (the loser loses the same amount).
local function eloGain(winnerElo: number, loserElo: number): number
	local expected = 1 / (1 + 10 ^ ((loserElo - winnerElo) / 400))
	return math.max(1, math.floor(D.ELO_K * (1 - expected) + 0.5))
end

endMatch = function(match: Match, winner: Player, forfeit: boolean)
	if match.ended then
		return
	end
	match.ended = true
	match.roundActive = false
	for _, connection in match.connections do
		connection:Disconnect()
	end
	local loser = other(match, winner)
	matches[match.a] = nil
	matches[match.b] = nil

	-- Ranked: ELO and ranked record.
	local eloBefore: { [Player]: number } = { [winner] = eloOf(winner), [loser] = eloOf(loser) }
	local eloAfter: { [Player]: number } = table.clone(eloBefore)
	if match.ranked then
		local gain = eloGain(eloBefore[winner], eloBefore[loser])
		eloAfter[winner] += gain
		eloAfter[loser] = math.max(0, eloAfter[loser] - gain)
	end
	for _, player in { winner, loser } do
		local won = player == winner
		PlayerData.update(player, function(data)
			data.stats.matchesPlayed += 1
			if won then
				data.stats.wins += 1
			end
			if match.ranked then
				data.elo = eloAfter[player]
				if won then
					data.rankedWins += 1
				else
					data.rankedLosses += 1
				end
			end
		end)
		if match.ranked then
			player:SetAttribute("Elo", eloAfter[player])
		end
	end

	-- Rewards. Challenges between the same two players: once per few minutes.
	local rewards: { [Player]: { xp: number, coins: number } } = {}
	local pairKey = if match.a.UserId < match.b.UserId
		then `{match.a.UserId}:{match.b.UserId}`
		else `{match.b.UserId}:{match.a.UserId}`
	local farming = not match.ranked
		and os.clock() - (lastRewardedChallenge[pairKey] or -math.huge)
			< Config.Progression.REPEAT_KILL_WINDOW
	if not farming then
		if not match.ranked then
			lastRewardedChallenge[pairKey] = os.clock()
		end
		rewards[winner] = if match.ranked then D.RANKED_WIN else D.CHALLENGE_WIN
		rewards[loser] = if match.ranked then D.RANKED_LOSS else D.CHALLENGE_LOSS
		Progression.grant(
			winner,
			if match.ranked then "RankedWin" else "DuelWin",
			rewards[winner].xp,
			rewards[winner].coins
		)
		-- (A forfeit gives the leaver nothing.)
		if not forfeit then
			Progression.grant(
				loser,
				if match.ranked then "RankedLoss" else "DuelLoss",
				rewards[loser].xp,
				rewards[loser].coins
			)
		end
	end

	for _, player in { winner, loser } do
		local reward = rewards[player]
		send(player, "End", {
			won = player == winner,
			ranked = match.ranked,
			forfeit = forfeit,
			score = scoreFor(match, player),
			xp = if reward and (player == winner or not forfeit) then reward.xp else 0,
			coins = if reward and (player == winner or not forfeit) then reward.coins else 0,
			eloBefore = if match.ranked then eloBefore[player] else nil,
			eloAfter = if match.ranked then eloAfter[player] else nil,
		})
	end

	-- Back to the free arena after the result screen.
	task.delay(D.ROUND_END_PAUSE + 1, function()
		for _, player in { match.a, match.b } do
			if player.Parent ~= Players then
				continue
			end
			player:SetAttribute("InDuel", false)
			local character = player.Character
			if character then
				character:SetAttribute("DuelId", nil)
				Combat.resetForRound(character)
				local spawn = Knockout.pickSpawn(player)
				if spawn then
					character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
				else
					task.spawn(function()
						player:LoadCharacterAsync()
					end)
				end
			end
		end
		Arenas.release(match.arena)
		processWaitingList()
	end)
end

------------------------------------------------------------------------------
-- 0 HP in a duel = round lost (instead of a KO on the ground)
------------------------------------------------------------------------------

local function interceptKnockout(victim: Model, _attacker: Model?): boolean
	local player = Players:GetPlayerFromCharacter(victim)
	local match = if player then matches[player] else nil
	if player == nil or match == nil then
		return false -- normal KO
	end
	-- In a duel: never a KO. During the countdown / pause nothing happens.
	endRound(match, player)
	return true
end

------------------------------------------------------------------------------
-- Challenges
------------------------------------------------------------------------------

local challengeLimiter = RateLimiter.new(3, 0.5)
local respondLimiter = RateLimiter.new(5, 1)
local queueLimiter = RateLimiter.new(4, 1)

local function blocksDuels(player: Player): boolean
	local data = PlayerData.getData(player)
	return data ~= nil and data.settings.blockDuels == true
end

local function onChallenge(player: Player, targetUserId: unknown)
	if typeof(targetUserId) ~= "number" or not challengeLimiter.allow(player) then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	local time = os.clock()
	local function refuse(reason: string)
		send(
			player,
			"Declined",
			{ name = if target then target.DisplayName else "", reason = reason }
		)
	end
	if target == nil or target == player then
		return
	end
	if time - (lastChallengeAt[player] or -math.huge) < D.CHALLENGE_COOLDOWN then
		refuse("COOLDOWN")
		return
	end
	if not isFree(player) or not isFree(target) then
		refuse("IN A DUEL")
		return
	end
	if inCombat(player) or inCombat(target) then
		refuse("IN COMBAT")
		return
	end
	if blocksDuels(target) then
		refuse("BLOCKS DUELS")
		return
	end
	local existing = pending[target]
	if existing and existing.expires > time and existing.from ~= player then
		refuse("BUSY")
		return
	end
	lastChallengeAt[player] = time
	local challenge: Pending = { from = player, expires = time + D.CHALLENGE_TIMEOUT }
	pending[target] = challenge
	send(target, "Challenged", {
		from = player.UserId,
		name = player.DisplayName,
		expiresAt = workspace:GetServerTimeNow() + D.CHALLENGE_TIMEOUT,
	})
	task.delay(D.CHALLENGE_TIMEOUT, function()
		if pending[target] == challenge then
			pending[target] = nil
			refuse("EXPIRED")
		end
	end)
end

local function onRespond(player: Player, challengerUserId: unknown, accept: unknown)
	if
		typeof(challengerUserId) ~= "number"
		or typeof(accept) ~= "boolean"
		or not respondLimiter.allow(player)
	then
		return
	end
	local challenge = pending[player]
	if challenge == nil or challenge.from.UserId ~= challengerUserId then
		return
	end
	pending[player] = nil
	local challenger = challenge.from
	if not accept then
		send(challenger, "Declined", { name = player.DisplayName, reason = "DECLINED" })
		return
	end
	if os.clock() > challenge.expires or not (isFree(player) and isFree(challenger)) then
		send(challenger, "Declined", { name = player.DisplayName, reason = "IN A DUEL" })
		return
	end
	Duels.startMatch(challenger, player, false)
end

------------------------------------------------------------------------------
-- Ranked matchmaking
------------------------------------------------------------------------------

local function onQueue(player: Player, searching: unknown)
	if typeof(searching) ~= "boolean" or not queueLimiter.allow(player) then
		return
	end
	if not searching then
		leaveQueue(player)
		return
	end
	if inQueue(player) or not isFree(player) then
		return
	end
	table.insert(queue, { player = player, since = os.clock() })
	player:SetAttribute("InQueue", true)
	send(player, "Queue", { searching = true, since = workspace:GetServerTimeNow() })
end

-- Pairs waiting players whose ELO are close enough (the range widens with time).
local function matchmake()
	local time = os.clock()
	local function range(entry: { player: Player, since: number }): number
		return D.MATCH_RANGE + D.MATCH_RANGE_GROWTH * math.floor((time - entry.since) / 5)
	end
	local index = 1
	while index <= #queue do
		local first = queue[index]
		local best, bestGap = nil, math.huge
		for candidate = index + 1, #queue do
			local second = queue[candidate]
			local gap = math.abs(eloOf(first.player) - eloOf(second.player))
			if gap <= math.max(range(first), range(second)) and gap < bestGap then
				best, bestGap = candidate, gap
			end
		end
		if best then
			local second = queue[best]
			Duels.startMatch(first.player, second.player, true) -- removes both from the queue
			if inQueue(first.player) then
				index += 1 -- couldn't start (busy): skip
			end
		else
			index += 1
		end
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

-- Leaving: forfeit (saved before the player's last save), out of the queue.
local function onLeaving(player: Player)
	leaveQueue(player)
	pending[player] = nil
	for target, challenge in pending do
		if challenge.from == player then
			pending[target] = nil
		end
	end
	local match = matches[player]
	if match then
		endMatch(match, other(match, player), true)
	end
end

local function onLoaded(player: Player)
	local data = PlayerData.getData(player)
	if data then
		player:SetAttribute("Elo", data.elo)
		player:SetAttribute("BlocksDuels", data.settings.blockDuels == true)
	end
	player:SetAttribute("InDuel", false)
	player:SetAttribute("InQueue", false)
end

function Duels.isInDuel(player: Player): boolean
	return matches[player] ~= nil
end

function Duels.start()
	Arenas.build()
	Knockout.setInterceptor(interceptKnockout)
	PlayerData.onLoaded(onLoaded)
	PlayerData.onLeaving(onLeaving)
	Players.PlayerRemoving:Connect(function(player)
		lastChallengeAt[player] = nil
		onLeaving(player) -- (if the save never loaded, onLeaving didn't run)
	end)
	Remotes.DuelChallenge.OnServerEvent:Connect(onChallenge)
	Remotes.DuelRespond.OnServerEvent:Connect(onRespond)
	Remotes.DuelQueue.OnServerEvent:Connect(onQueue)
	task.spawn(function()
		while true do
			task.wait(1)
			matchmake()
		end
	end)
end

return Duels
