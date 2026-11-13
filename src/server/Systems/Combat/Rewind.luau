--!strict
-- Rewind: lag compensation for hitboxes. SERVER only.
--
-- The problem: an attacker sees the others where they were a moment ago
-- (the network trip to him, plus the smoothing Roblox adds to other
-- characters). His click then takes another trip to reach us. So when the
-- server checks the hitbox, a running opponent is already a few studs
-- away from where the attacker saw him: a punch that clearly touched on
-- his screen whiffs (sprinting at 22 studs/s with 0.15 s of ping is ~5.5
-- studs: more than the whole hitbox is wide).
--
-- The fix ("rewind"): every frame we remember where each fighter's
-- HumanoidRootPart was (a short history, Config.Combat.REWIND_HISTORY
-- seconds). A hit is then also checked against the victims put back
-- where the attacker SAW them: `Rewind.amount(attacker)` seconds ago
-- (his round trip + the smoothing). Bounded on purpose: never more than
-- Config.Combat.REWIND_MAX, so a laggy (or lag-switching) player gets
-- no reach the others don't have beyond that.
--
-- Only POSITIONS are rewound. States (blocking, dodge frames, KO...) are
-- always the current ones: a block that is up when the hit lands counts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local C = Config.Combat

-- Samples kept per fighter (one per Heartbeat: 60 a second; a bit more
-- than REWIND_HISTORY seconds even if the server runs faster).
local SLOTS = math.ceil(C.REWIND_HISTORY * 60) + 8
-- A root that jumps this far in one frame was teleported (respawn, duel
-- arena, round reset): its history is forgotten, a hit can't land where
-- it was before.
local TELEPORT_JUMP = 15

type History = {
	root: BasePart,
	times: { number }, -- os.clock() of each sample (ring buffer)
	cframes: { CFrame },
	newest: number, -- index of the newest sample
	count: number, -- samples stored (0 = none yet)
}

local Rewind = {}

local histories: { [Model]: History } = {}
local roots: { [Model]: BasePart } = {} -- the same models, their root
local started = false

-- Starts remembering where `model`'s root is (Combat.register).
function Rewind.track(model: Model, root: BasePart)
	histories[model] = {
		root = root,
		times = table.create(SLOTS, 0),
		cframes = table.create(SLOTS, CFrame.identity),
		newest = 0,
		count = 0,
	}
	roots[model] = root
end

-- Forgets `model` (removed from the game).
function Rewind.untrack(model: Model)
	histories[model] = nil
	roots[model] = nil
end

-- Every tracked model and its root (read only: Hitbox walks it).
function Rewind.each(): { [Model]: BasePart }
	return roots
end

local function record()
	local time = os.clock()
	for _, history in histories do
		local cframe = history.root.CFrame
		if history.count > 0 then
			local last = history.cframes[history.newest]
			if (cframe.Position - last.Position).Magnitude > TELEPORT_JUMP then
				history.count = 0 -- teleported: the old places don't count
			end
		end
		local index = history.newest % SLOTS + 1
		history.newest = index
		history.times[index] = time
		history.cframes[index] = cframe
		history.count = math.min(history.count + 1, SLOTS)
	end
end

-- Where `model`'s root was `age` seconds ago (between two samples: the
-- mix of both). Older than the history: its oldest sample. nil if the
-- model isn't tracked or has no sample yet.
function Rewind.rootAt(model: Model, age: number): CFrame?
	local history = histories[model]
	if history == nil or history.count == 0 then
		return nil
	end
	local target = os.clock() - age
	local times, cframes = history.times, history.cframes
	local index = history.newest
	if target >= times[index] then
		return history.root.CFrame -- (newer than the last sample: now)
	end
	for _ = 2, history.count do
		local older = if index == 1 then SLOTS else index - 1
		local olderTime = times[older]
		if olderTime <= target then
			local span = times[index] - olderTime
			local alpha = if span > 1e-6 then (target - olderTime) / span else 1
			return cframes[older]:Lerp(cframes[index], alpha)
		end
		index = older
	end
	return cframes[index] -- (the oldest we have)
end

-- How far back (seconds) to look for `player`'s hits: his round trip
-- (measured by Roblox, not sent by his client: lagging on purpose is the
-- only way to raise it, and REWIND_MAX caps that) + the smoothing of other characters on his screen + how late
-- the server is checking (`lateBy`: a task.delay wakes up on the next
-- frame, up to ~17 ms after its time). Never more than REWIND_MAX.
-- Training dummies (no player) don't lag: 0.
function Rewind.amount(player: Player?, lateBy: number): number
	if player == nil or player.Parent ~= Players then
		return 0
	end
	local ok, ping = pcall(player.GetNetworkPing, player)
	local roundTrip = if ok and typeof(ping) == "number" and ping == ping then ping else 0
	local amount = roundTrip + C.REWIND_INTERPOLATION + math.max(lateBy, 0)
	return math.clamp(amount, 0, C.REWIND_MAX)
end

function Rewind.start()
	if started then
		return
	end
	started = true
	-- (after the physics step: the positions every client is sent)
	RunService.Heartbeat:Connect(record)
end

return table.freeze(Rewind)
