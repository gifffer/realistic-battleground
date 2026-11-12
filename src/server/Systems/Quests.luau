--!strict
-- Quests: 3 daily quests per player (step 9). SERVER-AUTHORITATIVE.
--
-- Every day (midnight UTC) each player gets 3 different quests drawn from
-- Shared/Quests, with a random goal ("Get 5 kills"). The server counts the
-- progress and gives the reward (XP + coins) the moment a goal is reached.
-- Everything is in the save (data.quests), so it survives leaving and
-- server hops; the client reads it from the save (Quests menu section).
--
-- What counts (only against real players, with the usual anti-farm):
--   Kills / Finishers / Assists / DuelWins / RankedWins
--       ← the rewards Progression gives (so a farmed kill counts nowhere)
--   Damage, HeadHits, KitMoves, Parries   ← Combat (hits between players)
--   Minutes                                ← time played

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local QuestDefs = require(ReplicatedStorage.Shared.Quests)
local Types = require(ReplicatedStorage.Shared.Types)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)

local Quests = {}

local random = Random.new()

-- Damage not yet counted (decimals: bleeding ticks, blocked hits...).
local damageCarry: { [Player]: number } = {}
-- When each player's kit move was last counted (once per move, not per hit).
local lastMoveCounted: { [Player]: { [string]: number } } = {}
-- Anti-farm between two players: at most PAIR_CAP[stat] counted per pair
-- every PAIR_WINDOW seconds (two friends parrying each other all day...).
local PAIR_WINDOW = 180
local PAIR_CAP: { [string]: number } = { Parries = 4, HeadHits = 12, Damage = 300, KitMoves = 6 }
local pairBudget: { [string]: { start: number, used: { [string]: number } } } = {}

-- How much of `amount` still counts for this pair (and books it).
local function pairAllowance(from: Player, to: Player, stat: string, amount: number): number
	local key = `{from.UserId}:{to.UserId}`
	local time = os.clock()
	local budget = pairBudget[key]
	if budget == nil or time - budget.start > PAIR_WINDOW then
		budget = { start = time, used = {} }
		pairBudget[key] = budget
	end
	local cap = PAIR_CAP[stat]
	if cap == nil then
		return amount
	end
	local allowed = math.max(0, math.min(amount, cap - (budget.used[stat] or 0)))
	budget.used[stat] = (budget.used[stat] or 0) + allowed
	return allowed
end

-- Draws today's quests if the save still holds another day's.
local function ensureToday(player: Player)
	local data = PlayerData.getData(player)
	local today = QuestDefs.today()
	if data == nil or data.quests.day == today then
		return
	end
	-- 3 different quests, each with a random goal.
	local pool = table.clone(QuestDefs.POOL)
	local list: { Types.QuestState } = {}
	for _ = 1, math.min(QuestDefs.PER_DAY, #pool) do
		local quest = table.remove(pool, random:NextInteger(1, #pool)) :: QuestDefs.QuestDef
		local steps = math.floor((quest.max - quest.min) / quest.step)
		local goal = quest.min + quest.step * random:NextInteger(0, steps)
		table.insert(list, { id = quest.id, goal = goal, progress = 0, done = false })
	end
	PlayerData.update(player, function(current)
		current.quests = { day = today, list = list }
	end)
end

-- Adds `amount` to every quest of today that counts `stat`; gives the reward
-- of each quest that reaches its goal.
function Quests.add(player: Player, stat: QuestDefs.Stat, amount: number)
	if amount <= 0 or player.Parent ~= Players then
		return
	end
	ensureToday(player)
	local data = PlayerData.getData(player)
	if data == nil then
		return
	end
	local finished: { { xp: number, coins: number } } = {}
	local changed = false
	for _, state in data.quests.list do
		local quest = QuestDefs.get(state.id)
		if quest and quest.stat == stat and not state.done then
			changed = true
			local progress = math.min(state.goal, state.progress + amount)
			local done = progress >= state.goal
			PlayerData.update(player, function()
				state.progress = progress
				state.done = done
			end)
			if done then
				local xp, coins = QuestDefs.reward(quest, state.goal)
				table.insert(finished, { xp = xp, coins = coins })
			end
		end
	end
	if not changed then
		return
	end
	for _, reward in finished do
		Progression.grant(player, "Quest", reward.xp, reward.coins)
	end
end

------------------------------------------------------------------------------
-- What counts
------------------------------------------------------------------------------

local function onGranted(player: Player, kind: Types.RewardKind, xp: number, _coins: number)
	if kind == "Kill" then
		Quests.add(player, "Kills", 1)
		-- A finisher kill is worth more than a plain one.
		if xp > Config.Progression.KILL_XP then
			Quests.add(player, "Finishers", 1)
		end
	elseif kind == "Assist" then
		Quests.add(player, "Assists", 1)
	elseif kind == "DuelWin" then
		Quests.add(player, "DuelWins", 1)
	elseif kind == "RankedWin" then
		Quests.add(player, "DuelWins", 1)
		Quests.add(player, "RankedWins", 1)
	end
end

-- Both fighters are real players (no farming the training dummies).
local function players(attacker: Model, victim: Model): (Player?, Player?)
	local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	if attackerPlayer == nil or victimPlayer == nil or attackerPlayer == victimPlayer then
		return nil, nil
	end
	return attackerPlayer, victimPlayer
end

local function onCombatEvent(info: Combat.CombatEventInfo)
	local attackerPlayer, victimPlayer = players(info.attacker, info.victim)
	if attackerPlayer == nil or victimPlayer == nil then
		return
	end
	if info.kind == "Parried" then
		-- The one who blocked at the right time.
		Quests.add(
			victimPlayer,
			"Parries",
			pairAllowance(victimPlayer, attackerPlayer, "Parries", 1)
		)
	elseif info.kind == "Hit" or info.kind == "Finisher" then
		if info.zone == "Head" then
			Quests.add(
				attackerPlayer,
				"HeadHits",
				pairAllowance(attackerPlayer, victimPlayer, "HeadHits", 1)
			)
		end
		-- A kit move the player used (not a counter or a follow-up), once
		-- per use even if it hits several times.
		local moveId = info.moveId
		if
			moveId
			and not string.find(moveId, "_Counter", 1, true)
			and not string.find(moveId, "_FollowUp", 1, true)
			and not string.find(moveId, "_Hold", 1, true)
			and moveId ~= "BoneThrow" -- (a thrown bone, not a kit move)
		then
			local counted = lastMoveCounted[attackerPlayer]
			if counted == nil then
				counted = {}
				lastMoveCounted[attackerPlayer] = counted
			end
			local time = os.clock()
			if time - (counted[moveId] or -math.huge) > 2 then
				counted[moveId] = time
				Quests.add(
					attackerPlayer,
					"KitMoves",
					pairAllowance(attackerPlayer, victimPlayer, "KitMoves", 1)
				)
			end
		end
	end
end

local function onDamaged(info: Combat.DamageInfo)
	local attackerPlayer, victimPlayer = players(info.attacker, info.victim)
	if attackerPlayer == nil or victimPlayer == nil then
		return
	end
	-- Whole points only; the decimals wait for the next hits.
	local total = (damageCarry[attackerPlayer] or 0) + info.amount
	local whole = math.floor(total)
	damageCarry[attackerPlayer] = total - whole
	Quests.add(
		attackerPlayer,
		"Damage",
		pairAllowance(attackerPlayer, victimPlayer, "Damage", whole)
	)
end

function Quests.start()
	Progression.onGranted(onGranted)
	Combat.onEvent(onCombatEvent)
	Combat.onDamaged(onDamaged)
	PlayerData.onLoaded(ensureToday)
	Players.PlayerRemoving:Connect(function(player)
		damageCarry[player] = nil
		lastMoveCounted[player] = nil
	end)
	-- Every minute: time played, and new quests after midnight UTC.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				ensureToday(player)
				Quests.add(player, "Minutes", 1)
			end
		end
	end)
end

return Quests
