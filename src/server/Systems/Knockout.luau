--!strict
-- Knockout: what happens at 0 HP. SERVER-AUTHORITATIVE.
--
-- The life of a fight's end:
--   1. A hit would bring a fighter to 0 HP → Combat calls Knockout.knockOut():
--      they stay at 1 HP, fall limp (Ragdoll) and are KNOCKED OUT (KO) for
--      Config.Knockout.DURATION seconds. Normal hits don't affect them.
--   2a. An opponent M1s them while they're down (Combat asks
--       Knockout.findFinishTarget) → finisher animation → Knockout.finish():
--       they die. The finisher gets the kill: +KILL_HEAL health, +1 kill.
--   2b. Nobody does → they get back up with GETUP_HEALTH, dazed for a moment.
--   3. Dead → respawn after RESPAWN_TIME, at the spawn point farthest from
--      the enemies, with SPAWN_PROTECTION seconds of invulnerability (a
--      force field) that ends early if they attack.
--
-- Also:
--   • Leaving the game in the middle of a fight (hit less than
--     COMBAT_TAG_TIME ago, or KO) = a death, and the last attacker gets the kill.
--   • Any other death (fell off the map...) gives the kill to the last
--     attacker if there was one recently.
--   • Every elimination is announced to everyone (Remotes.KillFeed).
--
-- Replicated to clients (attributes on the fighter's model):
--   "KnockedOut" (boolean), "KOEndsAt" (server time, workspace:GetServerTimeNow()),
--   "Protected" (boolean), "Ragdolled" (boolean, see Ragdoll).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local PlayerData = require(script.Parent.PlayerData)
local Ragdoll = require(script.Parent.Ragdoll)

local K = Config.Knockout

type FighterInfo = {
	model: Model,
	humanoid: Humanoid,
	player: Player?,
	knockedOut: boolean,
	koToken: number, -- +1 cancels the pending get-up
	finishedBy: Model?, -- set while someone is finishing them
	lastAttacker: Model?,
	lastHitAt: number,
	protectionToken: number,
	dead: boolean,
}

local Knockout = {}

local fighters: { [Model]: FighterInfo } = {}
-- Called when a KO'd fighter gets back up (Combat stuns them, plays GetUp).
local getUpCallbacks: { (Model) -> () } = {}

local function now(): number
	return os.clock()
end

local function setAttribute(model: Model, name: string, value: any)
	if model:GetAttribute(name) ~= value then
		model:SetAttribute(name, value)
	end
end

local function displayName(model: Model): string
	local player = Players:GetPlayerFromCharacter(model)
	return if player then player.DisplayName else model.Name
end

local function feed(kind: Types.KillFeedKind, victim: string, killer: string?)
	Remotes.KillFeed:FireAllClients(kind, victim, killer)
end

-- The killer: whoever is finishing them, else the last attacker if recent.
local function creditedKiller(info: FighterInfo): Model?
	if info.finishedBy then
		return info.finishedBy
	end
	if info.lastAttacker and now() - info.lastHitAt <= K.COMBAT_TAG_TIME then
		return info.lastAttacker
	end
	return nil
end

-- Kill rewards: health for the killer, stats in the saves.
local function rewardKill(killer: Model?, victim: FighterInfo)
	local victimPlayer = victim.player
	if victimPlayer then
		PlayerData.update(victimPlayer, function(data)
			data.stats.deaths += 1
		end)
	end
	if killer == nil or killer == victim.model then
		return
	end
	local killerHumanoid = killer:FindFirstChildOfClass("Humanoid")
	local killerInfo = fighters[killer]
	if
		killerHumanoid
		and killerHumanoid.Health > 0
		and not (killerInfo and killerInfo.knockedOut)
	then
		killerHumanoid.Health =
			math.min(killerHumanoid.MaxHealth, killerHumanoid.Health + K.KILL_HEAL)
	end
	-- Only kills on real players count in the stats (no farming dummies).
	local killerPlayer = Players:GetPlayerFromCharacter(killer)
	if killerPlayer and victimPlayer then
		PlayerData.update(killerPlayer, function(data)
			data.stats.kills += 1
		end)
	end
end

------------------------------------------------------------------------------
-- Spawn protection
------------------------------------------------------------------------------

local function clearProtection(info: FighterInfo)
	info.protectionToken += 1
	local field = info.model:FindFirstChild("SpawnProtection")
	if field then
		field:Destroy()
	end
	setAttribute(info.model, "Protected", false)
end

local function protect(info: FighterInfo)
	local field = Instance.new("ForceField")
	field.Name = "SpawnProtection"
	field.Visible = true
	field.Parent = info.model
	setAttribute(info.model, "Protected", true)
	info.protectionToken += 1
	local token = info.protectionToken
	task.delay(K.SPAWN_PROTECTION, function()
		if info.protectionToken == token then
			clearProtection(info)
		end
	end)
end

-- Spawn point farthest from the living enemies (when there are several).
local function pickSpawn(player: Player): SpawnLocation?
	local spawns: { SpawnLocation } = {}
	for _, instance in workspace:GetDescendants() do
		if instance:IsA("SpawnLocation") and instance.Enabled then
			table.insert(spawns, instance)
		end
	end
	if #spawns < 2 then
		return nil -- one spawn (or none): Roblox's choice is the only choice
	end
	local best: SpawnLocation? = nil
	local bestDistance = -1
	for _, spawn in spawns do
		local closest = math.huge
		for model, info in fighters do
			local root = model:FindFirstChild("HumanoidRootPart")
			if info.player ~= player and not info.dead and root and root:IsA("BasePart") then
				closest = math.min(closest, (root.Position - spawn.Position).Magnitude)
			end
		end
		if closest > bestDistance then
			best, bestDistance = spawn, closest
		end
	end
	return best
end

------------------------------------------------------------------------------
-- KO, get up, finish
------------------------------------------------------------------------------

local function getUp(info: FighterInfo)
	if not info.knockedOut or info.dead then
		return
	end
	info.knockedOut = false
	info.finishedBy = nil
	Ragdoll.disable(info.model, info.player)
	info.humanoid.Health = math.min(info.humanoid.MaxHealth, K.GETUP_HEALTH)
	setAttribute(info.model, "KnockedOut", false)
	setAttribute(info.model, "KOEndsAt", nil)
	for _, callback in getUpCallbacks do
		task.spawn(callback, info.model)
	end
end

local function onDied(info: FighterInfo)
	if info.dead then
		return
	end
	info.dead = true
	info.koToken += 1
	local killer = creditedKiller(info)
	Ragdoll.enable(info.model) -- a dead body always goes limp
	setAttribute(info.model, "KnockedOut", false)
	setAttribute(info.model, "KOEndsAt", nil)
	feed(
		if info.finishedBy then "Finished" else "Died",
		displayName(info.model),
		if killer then displayName(killer) else nil
	)
	rewardKill(killer, info)
end

------------------------------------------------------------------------------
-- Public API (Combat)
------------------------------------------------------------------------------

-- Makes a model known (called by Combat.register for every fighter).
function Knockout.register(model: Model, player: Player?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	-- The body must stay in one piece at death so it can ragdoll.
	humanoid.BreakJointsOnDeath = false
	local info: FighterInfo = {
		model = model,
		humanoid = humanoid,
		player = player,
		knockedOut = false,
		koToken = 0,
		finishedBy = nil,
		lastAttacker = nil,
		lastHitAt = -math.huge,
		protectionToken = 0,
		dead = false,
	}
	fighters[model] = info
	setAttribute(model, "KnockedOut", false)

	humanoid.Died:Connect(function()
		onDied(info)
	end)
	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			fighters[model] = nil
		end
	end)

	if player then
		protect(info)
		-- Respawn far from the enemies (a frame later, once Roblox placed it).
		local spawn = pickSpawn(player)
		if spawn then
			task.defer(function()
				if model.Parent then
					model:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
				end
			end)
		end
	end
end

function Knockout.isKnockedOut(model: Model): boolean
	local info = fighters[model]
	return info ~= nil and info.knockedOut
end

function Knockout.isProtected(model: Model): boolean
	return model:GetAttribute("Protected") == true
end

-- Attacking ends your spawn protection.
function Knockout.endProtection(model: Model)
	local info = fighters[model]
	if info and model:GetAttribute("Protected") == true then
		clearProtection(info)
	end
end

-- Remembers who hit whom (kill credit, leaving mid-fight).
function Knockout.noteHit(victim: Model, attacker: Model)
	local info = fighters[victim]
	if info then
		info.lastAttacker = attacker
		info.lastHitAt = now()
	end
end

-- 0 HP: knocked out instead of dead.
function Knockout.knockOut(victim: Model, attacker: Model?)
	local info = fighters[victim]
	if info == nil or info.knockedOut or info.dead then
		return
	end
	if attacker then
		Knockout.noteHit(victim, attacker)
	end
	info.knockedOut = true
	info.finishedBy = nil
	info.humanoid.Health = 1
	Ragdoll.enable(victim)
	setAttribute(victim, "KnockedOut", true)
	setAttribute(victim, "KOEndsAt", workspace:GetServerTimeNow() + K.DURATION)

	info.koToken += 1
	local token = info.koToken
	task.delay(K.DURATION, function()
		-- Still the same KO, and nobody is in the middle of finishing them.
		if info.koToken == token and info.finishedBy == nil then
			getUp(info)
		end
	end)
end

-- A KO'd fighter that `attacker` can finish right now (close, in front,
-- not already being finished), or nil.
function Knockout.findFinishTarget(attacker: Model): Model?
	local root = attacker:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local best: Model? = nil
	local bestDistance = K.FINISH_RANGE
	for model, info in fighters do
		if model ~= attacker and info.knockedOut and info.finishedBy == nil and not info.dead then
			local torso = model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart")
			if torso and torso:IsA("BasePart") then
				local offset = torso.Position - root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local distance = flat.Magnitude
				-- In front (within ~70°) or practically underneath.
				local inFront = distance < 1.5 or flat.Unit:Dot(forward) > 0.35
				if distance <= bestDistance and inFront and math.abs(offset.Y) < 6 then
					best, bestDistance = model, distance
				end
			end
		end
	end
	return best
end

-- Reserves a KO'd fighter for `attacker`'s finisher (nobody else can).
-- Returns false if it's no longer possible.
function Knockout.reserve(victim: Model, attacker: Model): boolean
	local info = fighters[victim]
	if info == nil or not info.knockedOut or info.finishedBy ~= nil or info.dead then
		return false
	end
	info.finishedBy = attacker
	return true
end

-- The finisher was interrupted: the victim can be finished by someone else,
-- or gets up if their KO time is over.
function Knockout.release(victim: Model)
	local info = fighters[victim]
	if info == nil or info.finishedBy == nil then
		return
	end
	info.finishedBy = nil
	local endsAt = victim:GetAttribute("KOEndsAt")
	if typeof(endsAt) == "number" and workspace:GetServerTimeNow() >= endsAt then
		getUp(info)
	end
end

-- The killing blow of the finisher.
function Knockout.finish(victim: Model, attacker: Model)
	local info = fighters[victim]
	if info == nil or not info.knockedOut or info.finishedBy ~= attacker then
		return
	end
	info.humanoid.Health = 0 -- → Humanoid.Died → onDied (kill credit, feed)
end

-- `callback(model)` when a KO'd fighter gets back up.
function Knockout.onGetUp(callback: (Model) -> ())
	table.insert(getUpCallbacks, callback)
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

-- Leaving mid-fight (or while KO) = a death, the last attacker gets the kill.
local function onLeaving(player: Player)
	local character = player.Character
	local info = if character then fighters[character] else nil
	if info == nil or info.dead then
		return
	end
	local inFight = info.knockedOut or now() - info.lastHitAt <= K.COMBAT_TAG_TIME
	if not inFight then
		return
	end
	local killer = creditedKiller(info)
	info.dead = true
	feed("Fled", displayName(info.model), if killer then displayName(killer) else nil)
	rewardKill(killer, info)
end

function Knockout.init()
	-- Roblox respawns dead players by itself after this delay.
	Players.RespawnTime = K.RESPAWN_TIME
	PlayerData.onLeaving(onLeaving)
end

return Knockout
