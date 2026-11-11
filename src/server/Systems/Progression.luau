--!strict
-- Progression: XP, levels and coins (step 7). SERVER-AUTHORITATIVE.
--
-- What earns what (numbers: Config.Progression). Only fights between real
-- players count: hitting or killing a training dummy gives nothing.
--   • Kill           KILL_XP / KILL_COINS, + a bonus if it was a finisher
--   • Assist         you damaged the victim in the last ASSIST_TIME seconds
--                    but someone else got the kill
--   • Damage dealt   1 XP every DAMAGE_PER_XP damage (paid every few seconds)
--   • Time played    every PLAYTIME_INTERVAL seconds
--
-- The save keeps the TOTAL XP (data.xp); the level comes from it through
-- the shared curve (Shared/Progression), so it can never disagree.
--
-- Replicated to everyone (attributes on the Player):
--   "Level"                              for name tags, kill feed, scoreboard
--   "SessionKills", "SessionDeaths"      this server only (scoreboard)
-- The player also gets Remotes.Progress for each reward (the HUD's "+50 XP").
--
-- Kits that cost something (Kits.unlockLevel / price) are bought here
-- (Remotes.BuyKit): level reached + enough coins → saved in data.ownedKits.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local ProgressionCurve = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Combat = require(script.Parent.Combat)
local Knockout = require(script.Parent.Knockout)
local PlayerData = require(script.Parent.PlayerData)

local P = Config.Progression

-- Damage XP is paid out in one go every this many seconds (not per hit).
local DAMAGE_PAYOUT_INTERVAL = 5

local Progression = {}

-- Per victim body: who (players) damaged it, and when.
local contributors: { [Model]: { [Player]: number } } = {}
-- Per player: damage dealt to players, not yet turned into XP.
local damageCarry: { [Player]: number } = {}
-- Per player: seconds played since the last playtime reward.
local playtime: { [Player]: number } = {}

local function setLevelAttribute(player: Player, xp: number)
	local level = ProgressionCurve.levelFromXp(xp)
	if player:GetAttribute("Level") ~= level then
		player:SetAttribute("Level", level)
	end
end

local function addAttribute(player: Player, name: string, amount: number)
	local value = player:GetAttribute(name)
	player:SetAttribute(name, (if typeof(value) == "number" then value else 0) + amount)
end

-- Gives `xp` and `coins` to `player` (saved) and tells their client why.
function Progression.grant(player: Player, kind: Types.RewardKind, xp: number, coins: number)
	if xp <= 0 and coins <= 0 then
		return
	end
	local saved = PlayerData.update(player, function(data)
		data.xp += xp
		data.coins += coins
	end)
	if not saved then
		return
	end
	local data = PlayerData.getData(player)
	if data then
		setLevelAttribute(player, data.xp)
	end
	Remotes.Progress:FireClient(player, kind, xp, coins)
end

------------------------------------------------------------------------------
-- Fights
------------------------------------------------------------------------------

local function onDamaged(info: Combat.DamageInfo)
	local victimPlayer = Players:GetPlayerFromCharacter(info.victim)
	local attackerPlayer = Players:GetPlayerFromCharacter(info.attacker)
	if victimPlayer == nil or attackerPlayer == nil or victimPlayer == attackerPlayer then
		return -- dummies (or yourself) give nothing
	end
	local list = contributors[info.victim]
	if list == nil then
		list = {}
		contributors[info.victim] = list
		-- Forget a body once it's gone.
		info.victim.AncestryChanged:Connect(function()
			if info.victim.Parent == nil then
				contributors[info.victim] = nil
			end
		end)
	end
	list[attackerPlayer] = os.clock()
	damageCarry[attackerPlayer] = (damageCarry[attackerPlayer] or 0) + info.amount
end

local function onEliminated(elimination: Knockout.Elimination)
	local victimPlayer = elimination.victimPlayer
	local killerPlayer = elimination.killerPlayer
	if victimPlayer then
		addAttribute(victimPlayer, "SessionDeaths", 1)
	end
	-- Only kills of real players are rewarded.
	if victimPlayer == nil then
		return
	end
	if killerPlayer and killerPlayer.Parent == Players then
		addAttribute(killerPlayer, "SessionKills", 1)
		local finisher = elimination.kind == "Finished"
		Progression.grant(
			killerPlayer,
			"Kill",
			P.KILL_XP + (if finisher then P.FINISHER_BONUS_XP else 0),
			P.KILL_COINS + (if finisher then P.FINISHER_BONUS_COINS else 0)
		)
	end
	-- Assists: everyone else who hurt them recently.
	local list = contributors[elimination.victim]
	if list then
		local time = os.clock()
		for player, at in list do
			if
				player ~= killerPlayer
				and player.Parent == Players
				and time - at <= P.ASSIST_TIME
			then
				Progression.grant(player, "Assist", P.ASSIST_XP, P.ASSIST_COINS)
			end
		end
		contributors[elimination.victim] = nil
	end
end

------------------------------------------------------------------------------
-- Damage payout and time played
------------------------------------------------------------------------------

local sincePayout = 0

local function update(dt: number)
	-- Time played.
	for player, seconds in playtime do
		seconds += dt
		if seconds >= P.PLAYTIME_INTERVAL then
			seconds -= P.PLAYTIME_INTERVAL
			Progression.grant(player, "Playtime", P.PLAYTIME_XP, P.PLAYTIME_COINS)
		end
		playtime[player] = seconds
	end
	-- Damage dealt, a few seconds' worth at a time.
	sincePayout += dt
	if sincePayout < DAMAGE_PAYOUT_INTERVAL then
		return
	end
	sincePayout = 0
	for player, damage in damageCarry do
		local xp = math.floor(damage / P.DAMAGE_PER_XP)
		if xp > 0 then
			damageCarry[player] = damage - xp * P.DAMAGE_PER_XP
			Progression.grant(player, "Damage", xp, 0)
		end
	end
end

------------------------------------------------------------------------------
-- Buying kits
------------------------------------------------------------------------------

local buyLimiter = RateLimiter.new(3, 0.5)

local function onBuyKit(player: Player, kitId: unknown)
	if typeof(kitId) ~= "string" or not buyLimiter.allow(player) then
		return
	end
	local kit = Kits.get(kitId)
	local data = PlayerData.getData(player)
	if kit == nil or data == nil or not kit.available or Kits.owns(data, kit) then
		return
	end
	local level = ProgressionCurve.levelFromXp(data.xp)
	if level < (kit.unlockLevel or 1) then
		return
	end
	local price = kit.price or 0
	if price > 0 and not PlayerData.spendCoins(player, price) then
		return
	end
	PlayerData.update(player, function(current)
		current.ownedKits[kit.id] = true
	end)
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

local function onLoaded(player: Player)
	local data = PlayerData.getData(player)
	if data then
		setLevelAttribute(player, data.xp)
	end
	player:SetAttribute("SessionKills", 0)
	player:SetAttribute("SessionDeaths", 0)
	playtime[player] = 0
end

function Progression.start()
	Combat.onDamaged(onDamaged)
	Knockout.onEliminated(onEliminated)
	PlayerData.onLoaded(onLoaded)
	Players.PlayerRemoving:Connect(function(player)
		playtime[player] = nil
		damageCarry[player] = nil
		for _, list in contributors do
			list[player] = nil
		end
	end)
	Remotes.BuyKit.OnServerEvent:Connect(onBuyKit)
	RunService.Heartbeat:Connect(update)
end

return Progression
