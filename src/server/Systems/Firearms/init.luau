--!strict
-- Firearms (server): who carries which gun, its ammo, its actions (draw, holster,
-- reloads, bolt cycles) run from the shared timelines, and every shot validated
-- before it can hurt anyone. SERVER-AUTHORITATIVE: the client only asks.
-- docs/firearms/ARCHITECTURE.md §9, docs/firearms/CORE.md.
--
-- Life of a shot (FireShot):
--   1. the shooter's client fired at once (prediction) and sends what it did;
--   2. here, in order (any failure = ShotRefused with the true counters, nothing
--      relayed): types (Validate.shot), state (drawn, ready, not stunned / KO /
--      sliding / in the park / just sprinting / mid-reload past its cancel window),
--      the weapon's own rate (token bucket at its rpm), ammo (Shared/Firearms/Ammo),
--      the shot time (within the rewind window), the muzzle near the head with a clear
--      line head -> muzzle, the direction against the aim stream and the body;
--   3. the ammo is spent; each claimed hit must match a bullet / pellet of the shot
--      (the spread is recomputed from the seed: Ballistics.seed(GunSalt, shotId)),
--      have no wall between the muzzle and it (city glass: rifle-class bullets go
--      through), and cross the victim's body put back where the shooter saw it
--      (Combat/Rewind; the rest-pose boxes, inflated, or the live parts); the zone is
--      the server's;
--   4. damage = Ballistics.damage (zone, falloff, DAMAGE_SCALE) through
--      Combat.firearmHit (the existing hit resolution: blood, KO, kill feed);
--   5. ShotFired is relayed to the other clients (look only).
--
-- Attributes on the character (read by every client to dress and pose the gun):
--   Firearm (id or nil), GunDrawn, GunMode, GunAction ("<Timeline>|<server time>"),
--   GunMag (rounds in the feed, -1 = no mag in), GunChambered, GunReserve,
--   GunBoltOpen, GunNeedsCycle, GunCoverOpen, GunBipod.
-- On the Player: GunSalt (the spread seed's per-life salt).
--
-- API for other server systems:
--   Firearms.give(model, id)    the gun, holstered, loaded (replaces any other)
--   Firearms.take(model)        no gun any more
--   Firearms.carried(model)     -> id?
--   Firearms.isDrawn(model)     -> boolean
--
-- How players get guns is not decided yet (ARCHITECTURE §20): the only way now is
-- the Studio test key (Config.Dev.FIREARMS_TEST, GunAction "DevCycle"). On a KO the
-- gun is put away (instantly); on death it is gone; in a duel nobody has one.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SafeZone = require(ReplicatedStorage.Shared.Util.SafeZone)
local FirearmsData = require(ReplicatedStorage.Shared.Firearms)
local Ammo = require(ReplicatedStorage.Shared.Firearms.Ammo)
local Ballistics = require(ReplicatedStorage.Shared.Firearms.Ballistics)
local Types = require(ReplicatedStorage.Shared.Firearms.Types)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Combat = require(script.Parent.Combat)
local Hitbox = require(script.Parent.Combat.Hitbox)
local Rewind = require(script.Parent.Combat.Rewind)
local Knockout = require(script.Parent.Knockout)
local Movement = require(script.Parent.Movement)
local Ragdoll = require(script.Parent.Ragdoll)
local Validate = require(script.Validate)

type Def = Types.FirearmDef
type Timeline = Types.Timeline

local FC = Config.Firearms
local BITS = FirearmsData.BITS
local GLASS_TAG = "CityGlass"
local GLASS_SCALE = 0.85
local MAX_PANES = 3
local BUSY_MOVES = table.freeze({ Slide = true, Climb = true, Vault = true })
local AIM_STALE = 1.0 -- seconds: an older aim sample is not used for the pitch check
local BIPOD_MOVE = 2.5 -- studs/s: moving folds the bipod

type Action = {
	steps: { string },
	index: number,
	timeline: Timeline,
	startedAt: number, -- os.clock() of the current step
	nextEvent: number,
	kind: string, -- "Draw" / "Holster" / "Reload" / "Cycle" / "Bipod"
}

type Carrier = {
	model: Model,
	player: Player?,
	def: Def,
	ammo: Types.AmmoState,
	drawn: boolean,
	readyAt: number, -- os.clock(): can fire from then (draw / raise done)
	mode: Types.FireMode,
	action: Action?,
	lastShotId: number,
	bucket: Validate.Bucket,
	bloom: number,
	bloomAt: number,
	aimPitch: number?,
	aimBits: number,
	aimAt: number,
	aimDirty: boolean,
	bipod: boolean,
	shotIndex: number,
	salt: number,
}

local Firearms = {}

local carriers: { [Model]: Carrier } = {}
local sprintEndedAt: { [Player]: number } = {}
local random = Random.new()
local mapParams = RaycastParams.new()
mapParams.FilterType = Enum.RaycastFilterType.Exclude
mapParams.IgnoreWater = true

local shotLimiter = RateLimiter.new(30, 25)
local actionLimiter = RateLimiter.new(12, 6)
local aimLimiter = RateLimiter.new(40, 30)

------------------------------------------------------------------------------
-- State and attributes
------------------------------------------------------------------------------

local function setAttr(model: Model, name: string, value: any)
	if model:GetAttribute(name) ~= value then
		model:SetAttribute(name, value)
	end
end

local function publish(c: Carrier)
	local model, ammo = c.model, c.ammo
	setAttr(model, "Firearm", c.def.id)
	setAttr(model, "GunDrawn", c.drawn)
	setAttr(model, "GunMode", c.mode)
	setAttr(model, "GunMag", if ammo.mag == nil then -1 else ammo.mag)
	setAttr(model, "GunChambered", ammo.chambered)
	setAttr(model, "GunReserve", ammo.reserve)
	setAttr(model, "GunBoltOpen", ammo.boltOpen)
	setAttr(model, "GunNeedsCycle", ammo.needsCycle)
	setAttr(model, "GunCoverOpen", ammo.coverOpen)
	setAttr(model, "GunBipod", c.bipod)
end

local ATTRIBUTES = table.freeze({
	"Firearm",
	"GunDrawn",
	"GunMode",
	"GunAction",
	"GunMag",
	"GunChambered",
	"GunReserve",
	"GunBoltOpen",
	"GunNeedsCycle",
	"GunCoverOpen",
	"GunBipod",
})

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function alive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return model.Parent ~= nil and humanoid ~= nil and humanoid.Health > 0
end

function Firearms.carried(model: Model): string?
	local c = carriers[model]
	return if c then c.def.id else nil
end

function Firearms.isDrawn(model: Model): boolean
	local c = carriers[model]
	return c ~= nil and c.drawn
end

function Firearms.take(model: Model)
	carriers[model] = nil
	for _, name in ATTRIBUTES do
		if model:GetAttribute(name) ~= nil then
			model:SetAttribute(name, nil)
		end
	end
end

function Firearms.give(model: Model, id: string): boolean
	local def = FirearmsData.get(id)
	if def == nil then
		return false
	end
	Firearms.take(model)
	local player = Players:GetPlayerFromCharacter(model)
	local salt = random:NextInteger(1, 2 ^ 24)
	carriers[model] = {
		model = model,
		player = player,
		def = def,
		ammo = Ammo.new(def),
		drawn = false,
		readyAt = math.huge,
		mode = def.modes[1],
		action = nil,
		lastShotId = 0,
		bucket = Validate.newBucket(),
		bloom = 0,
		bloomAt = 0,
		aimPitch = nil,
		aimBits = 0,
		aimAt = -math.huge,
		aimDirty = false,
		bipod = false,
		shotIndex = 0,
		salt = salt,
	}
	if player then
		player:SetAttribute("GunSalt", salt)
	end
	publish(carriers[model])
	setAttr(model, "GunAction", nil)
	return true
end

------------------------------------------------------------------------------
-- Actions (timelines)
------------------------------------------------------------------------------

local function stopAction(c: Carrier)
	c.action = nil
	setAttr(c.model, "GunAction", nil)
end

local function startStep(c: Carrier, action: Action)
	local name = action.steps[action.index]
	local timeline = FirearmsData.timeline(c.def.id, name)
	if timeline == nil then
		-- (no clip timing for this step: done at once)
		action.timeline = { length = 0, events = {} }
	else
		action.timeline = timeline
	end
	action.startedAt = os.clock()
	action.nextEvent = 1
	setAttr(c.model, "GunAction", `{name}|{string.format("%.3f", workspace:GetServerTimeNow())}`)
end

local function startAction(c: Carrier, kind: string, steps: { string })
	local action: Action = {
		steps = steps,
		index = 1,
		timeline = { length = 0, events = {} },
		startedAt = os.clock(),
		nextEvent = 1,
		kind = kind,
	}
	c.action = action
	startStep(c, action)
end

-- Can the current action still be stopped (a shot, a stun, a sprint, ReloadCancel)?
local function cancellable(c: Carrier): boolean
	local action = c.action
	if action == nil then
		return true
	end
	if action.kind == "Draw" or action.kind == "Holster" or action.kind == "Bipod" then
		return false
	end
	local timeline = action.timeline
	if timeline.loop then
		return true -- between shells
	end
	local name = action.steps[action.index]
	if name == "ShellStart" or name == "ShellEnd" then
		return name == "ShellStart"
	end
	local limit = timeline.cancelUntil
	return limit ~= nil and os.clock() - action.startedAt < limit
end

-- Stops what can be stopped. The shell loop ends with its remount (ShellEnd).
local function interrupt(c: Carrier): boolean
	local action = c.action
	if action == nil then
		return true
	end
	if not cancellable(c) then
		return false
	end
	local endIndex = table.find(action.steps, "ShellEnd")
	if endIndex and action.index < endIndex then
		action.index = endIndex
		startStep(c, action)
		return true
	end
	stopAction(c)
	return true
end

local function stepAction(c: Carrier)
	local action = c.action
	if action == nil then
		return
	end
	local elapsed = os.clock() - action.startedAt
	local events = action.timeline.events
	local changed = false
	while action.nextEvent <= #events and events[action.nextEvent].time <= elapsed do
		Ammo.applyEvent(c.def, c.ammo, events[action.nextEvent].name)
		action.nextEvent += 1
		changed = true
	end
	if elapsed >= action.timeline.length then
		local kind = action.kind
		if action.index < #action.steps then
			action.index += 1
			startStep(c, action)
		else
			stopAction(c)
			if kind == "Holster" then
				c.drawn = false
				c.bipod = false
			end
		end
		changed = true
	end
	if changed then
		publish(c)
	end
end

local function reloadSteps(c: Carrier): { string }?
	local plan = Ammo.reloadPlan(c.def, c.ammo)
	if plan == nil then
		return nil
	end
	if plan == "Shells" then
		local missing = c.def.capacity - (c.ammo.mag or 0)
		local count = math.min(missing, c.ammo.reserve)
		if count <= 0 then
			return nil
		end
		local steps = { "ShellStart" }
		for _ = 1, count do
			table.insert(steps, "ShellLoop")
		end
		table.insert(steps, "ShellEnd")
		return steps
	end
	return { plan }
end

------------------------------------------------------------------------------
-- Checks shared by shots and actions
------------------------------------------------------------------------------

local function busy(c: Carrier): string?
	local model = c.model
	if not alive(model) then
		return "dead"
	end
	if model:GetAttribute("Stunned") == true then
		return "stunned"
	end
	if Knockout.isKnockedOut(model) or Ragdoll.isRagdolled(model) then
		return "down"
	end
	if Combat.isInCinematic(model) or model:GetAttribute("Held") ~= nil then
		return "busy"
	end
	local player = c.player
	if player and BUSY_MOVES[Movement.getMoveState(player)] then
		return "moving"
	end
	local root = rootOf(model)
	if root and SafeZone.contains(root.Position) then
		return "safe"
	end
	return nil
end

local function refreshMapFilter()
	local list: { Instance } = {}
	for _, model in CollectionService:GetTagged(Config.Combat.TAG) do
		table.insert(list, model)
	end
	for _, model in CollectionService:GetTagged(Config.Combat.CORPSE_TAG) do
		table.insert(list, model)
	end
	mapParams.FilterDescendantsInstances = list
end

-- The map between two points: nil when clear, else the blocking point. City glass
-- lets rifle-class bullets through (`through`), at GLASS_SCALE each pane.
local function mapBetween(from: Vector3, to: Vector3, through: boolean): (Vector3?, number)
	local scale = 1
	local start = from
	for _ = 1, MAX_PANES + 1 do
		local offset = to - start
		local length = offset.Magnitude
		if length < 0.05 then
			return nil, scale
		end
		local result = workspace:Raycast(start, offset, mapParams)
		if result == nil then
			return nil, scale
		end
		local part = result.Instance
		if through and CollectionService:HasTag(part, GLASS_TAG) then
			scale *= GLASS_SCALE
			start = result.Position + offset.Unit * 0.05
		else
			return result.Position, scale
		end
	end
	return to, scale
end

local function stanceOf(c: Carrier): string
	if bit32.band(c.aimBits, BITS.Aim) ~= 0 then
		return "Aim"
	end
	if bit32.band(c.aimBits, BITS.LowReady + BITS.Sprint) ~= 0 then
		return "Hip"
	end
	return "Ready"
end

local function refuse(player: Player, c: Carrier?, shotId: unknown, reason: string)
	local id = if typeof(shotId) == "number" then shotId else 0
	if c then
		Remotes.ShotRefused:FireClient(player, id, reason, c.ammo.mag, c.ammo.chambered, c.ammo.reserve)
	else
		Remotes.ShotRefused:FireClient(player, id, reason, nil, false, 0)
	end
end

------------------------------------------------------------------------------
-- FireShot
------------------------------------------------------------------------------

local function onFireShot(
	player: Player,
	shotId: unknown,
	weaponId: unknown,
	shotTime: unknown,
	origin: unknown,
	direction: unknown,
	hits: unknown
)
	if not shotLimiter.allow(player) then
		return
	end
	local model = player.Character
	local c = if model then carriers[model] else nil
	if model == nil or c == nil then
		refuse(player, nil, shotId, "nogun")
		return
	end
	local shot, why = Validate.shot(shotId, weaponId, shotTime, origin, direction, hits, c.lastShotId)
	if shot == nil then
		refuse(player, c, shotId, why or "type")
		return
	end
	c.lastShotId = shot.shotId
	local def = c.def
	if shot.weaponId ~= def.id then
		refuse(player, c, shotId, "weapon")
		return
	end
	-- state
	local clock = os.clock()
	if not c.drawn or clock < c.readyAt then
		refuse(player, c, shotId, "notready")
		return
	end
	local problem = busy(c)
	if problem then
		refuse(player, c, shotId, problem)
		return
	end
	if player:GetAttribute("Sprinting") == true then
		refuse(player, c, shotId, "sprint")
		return
	end
	if clock - (sprintEndedAt[player] or -math.huge) < def.handling.sprintToFire * FC.SPRINT_FIRE then
		refuse(player, c, shotId, "sprint")
		return
	end
	if c.action and not interrupt(c) then
		refuse(player, c, shotId, "action")
		return
	end
	-- rate and ammo
	local okRate, rateWhy = Validate.rate(c.bucket, def, clock)
	if not okRate then
		refuse(player, c, shotId, rateWhy or "rate")
		return
	end
	local canFire, ammoWhy = Ammo.canFire(def, c.ammo)
	if not canFire then
		refuse(player, c, shotId, ammoWhy or "empty")
		return
	end
	-- time, origin, direction
	local now = workspace:GetServerTimeNow()
	local age = Validate.time(shot.shotTime, now, Rewind.amount(player, 0))
	if age == nil then
		refuse(player, c, shotId, "time")
		return
	end
	local head = model:FindFirstChild("Head")
	local root = rootOf(model)
	if head == nil or not head:IsA("BasePart") or root == nil then
		refuse(player, c, shotId, "body")
		return
	end
	local speed = root.AssemblyLinearVelocity.Magnitude
	if not Validate.origin(head.Position, shot.origin, speed, def.originSlack) then
		refuse(player, c, shotId, "origin")
		return
	end
	refreshMapFilter()
	if mapBetween(head.Position, shot.origin, false) then
		refuse(player, c, shotId, "muzzle") -- the muzzle is through a wall
		return
	end
	local aimPitch = if clock - c.aimAt < AIM_STALE then c.aimPitch else nil
	local okAim, aimWhy = Validate.aim(shot.direction, aimPitch, root.CFrame.LookVector)
	if not okAim then
		refuse(player, c, shotId, aimWhy or "aim")
		return
	end

	-- the shot happens: ammo, bloom, protection
	Ammo.fire(def, c.ammo)
	c.bloom = Ballistics.bloomAfter(def, c.bloom, clock - c.bloomAt)
	local bloom = c.bloom
	c.bloom = math.min(def.spread.max, c.bloom + def.spread.perShot)
	c.bloomAt = clock
	c.shotIndex += 1
	Knockout.endProtection(model)
	publish(c)

	-- hits
	local walk = Config.Character.WALK_SPEED * def.handling.walkSpeed
	local flat = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local crouched = bit32.band(c.aimBits, BITS.Crouch) ~= 0
	local lo, hi = Validate.spreadRange(def, stanceOf(c), flat.Magnitude / walk, crouched, c.bipod, bloom)
	local seed = Ballistics.seed(c.salt, shot.shotId)
	local claims = Validate.claimedHits(def, shot.origin, shot.direction, seed, lo, hi, shot.hits)
	local endsByPellet: { [number]: Vector3 } = {}
	local throughGlass = def.glass == "Through"
	local pierced: { [number]: number } = {}
	for _, claim in claims do
		local victim = claim.model
		if victim ~= model and CollectionService:HasTag(victim, Config.Combat.TAG) and alive(victim) then
			local blocked, glassScale = mapBetween(shot.origin, claim.at, throughGlass)
			local victimRoot = rootOf(victim)
			if blocked == nil and victimRoot then
				local dir = (claim.at - shot.origin).Unit
				local reach = claim.distance + 4
				local rootAt = Rewind.rootAt(victim, age) or victimRoot.CFrame
				-- the live parts (put back where he was), else the rest-pose boxes inflated
				local livePart = Hitbox.rayAt(victim, shot.origin, dir * reach, rootAt)
				local partName: string? = nil
				if livePart then
					partName = if livePart.Parent and livePart.Parent:IsA("Accessory") then "Head" else livePart.Name
				else
					local _, restName = Ballistics.rayRestBody(
						shot.origin,
						dir,
						reach,
						rootAt,
						FC.HIT_SLACK_H,
						FC.HIT_SLACK_V
					)
					if restName then
						partName = claim.part -- (inside the slack: the zone the shooter saw)
					end
				end
				local zone = if partName then Ballistics.zoneOf(partName) else nil
				if zone then
					local index = pierced[claim.pellet] or 0
					pierced[claim.pellet] = index + 1
					local damage = Ballistics.damage(def, zone, claim.distance, FC.DAMAGE_SCALE) * glassScale
					if index > 0 then
						damage *= def.pierceScale ^ index
					end
					Combat.firearmHit(model, victim, {
						damage = damage,
						zone = zone,
						from = shot.origin,
						weaponId = def.id,
					})
					endsByPellet[claim.pellet] = claim.at
				end
			end
		end
	end

	-- relay (the look): one end point per bullet / pellet
	local mid = (lo + hi) / 2
	local directions = Ballistics.directions(def, shot.direction, seed, math.min(mid, hi))
	local ends = table.create(#directions)
	for index, dir in directions do
		local hitAt = endsByPellet[index]
		if hitAt == nil then
			local target = shot.origin + dir * def.range
			hitAt = mapBetween(shot.origin, target, throughGlass) or target
		end
		table.insert(ends, hitAt)
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.ShotFired:FireClient(other, model, def.id, shot.origin, ends, c.shotIndex)
		end
	end
end

------------------------------------------------------------------------------
-- GunAction
------------------------------------------------------------------------------

local function devCycle(model: Model)
	local list = FirearmsData.list()
	local current = carriers[model]
	local index = if current then (table.find(list, current.def) or 0) else 0
	local nextDef = list[index + 1]
	if nextDef then
		Firearms.give(model, nextDef.id)
	else
		Firearms.take(model)
	end
end

local function tryBipod(c: Carrier): boolean
	if c.def.spread.bipod == nil then
		return false
	end
	local root = rootOf(c.model)
	if root == nil or root.AssemblyLinearVelocity.Magnitude > BIPOD_MOVE then
		return false
	end
	-- a surface under the front of the gun: a sill, a crate, a car's bonnet
	local probe = root.CFrame * CFrame.new(0, 0.6, -2.6)
	local result = workspace:Raycast(probe.Position, Vector3.new(0, -3.2, 0), mapParams)
	if result == nil then
		return false
	end
	local height = result.Position.Y - root.Position.Y
	return height > -2.6 and height < 0.8
end

local function onGunAction(player: Player, action: unknown, arg: unknown, requestId: unknown)
	if not actionLimiter.allow(player) then
		return
	end
	if typeof(action) ~= "string" then
		return
	end
	local model = player.Character
	if model == nil or not alive(model) then
		return
	end
	if action == "DevCycle" then
		if Config.Dev.FIREARMS_TEST and RunService:IsStudio() then
			devCycle(model)
		end
		return
	end
	local c = carriers[model]
	if c == nil then
		return
	end
	local problem = busy(c)
	if action == "Draw" then
		if c.drawn or c.action or problem then
			return
		end
		if model:GetAttribute("DuelId") ~= nil then
			return
		end
		c.drawn = true
		c.readyAt = os.clock() + c.def.handling.drawTime
		startAction(c, "Draw", { "Draw" })
		publish(c)
	elseif action == "Holster" then
		if not c.drawn or (c.action and not interrupt(c)) then
			return
		end
		c.bipod = false
		c.readyAt = math.huge
		startAction(c, "Holster", { "Holster" })
		publish(c)
	elseif action == "Reload" then
		if not c.drawn or c.action or problem or player:GetAttribute("Sprinting") == true then
			return
		end
		local steps = reloadSteps(c)
		if steps then
			startAction(c, "Reload", steps)
		end
	elseif action == "ReloadCancel" then
		if c.action and c.action.kind == "Reload" then
			interrupt(c)
		end
	elseif action == "Cycle" then
		if not c.drawn or c.action or problem then
			return
		end
		local plan = Ammo.cyclePlan(c.def, c.ammo)
		if plan then
			startAction(c, "Cycle", { plan })
		end
	elseif action == "Mode" then
		if #c.def.modes > 1 and not problem then
			local index = table.find(c.def.modes, c.mode) or 1
			c.mode = c.def.modes[index % #c.def.modes + 1]
			publish(c)
		end
	elseif action == "Bipod" then
		if not c.drawn or c.action or problem then
			return
		end
		local want = if typeof(arg) == "boolean" then arg else not c.bipod
		if want and not c.bipod and tryBipod(c) then
			c.bipod = true
			startAction(c, "Bipod", { "BipodDeploy" })
		elseif not want and c.bipod then
			c.bipod = false
			startAction(c, "Bipod", { "BipodFold" })
		end
		publish(c)
	end
	local _ = requestId
end

------------------------------------------------------------------------------
-- GunAim (stream) and its relay
------------------------------------------------------------------------------

local function onGunAim(player: Player, pitch: unknown, bits: unknown)
	if not aimLimiter.allow(player) then
		return
	end
	local model = player.Character
	local c = if model then carriers[model] else nil
	if c == nil or typeof(pitch) ~= "number" or typeof(bits) ~= "number" then
		return
	end
	if pitch ~= pitch or bits ~= bits then
		return
	end
	c.aimPitch = math.clamp(pitch, -89, 89)
	c.aimBits = math.clamp(math.floor(bits), 0, 255)
	c.aimAt = os.clock()
	c.aimDirty = true
end

local relayAccumulator = 0
local function relayAims(dt: number)
	relayAccumulator += dt
	if relayAccumulator < 1 / FC.AIM_RATE then
		return
	end
	relayAccumulator = 0
	local batch: { [Model]: { number } } = {}
	local any = false
	for model, c in carriers do
		if c.aimDirty and c.aimPitch then
			c.aimDirty = false
			batch[model] = { math.floor(c.aimPitch * 10 + 0.5) / 10, c.aimBits }
			any = true
		end
	end
	if any then
		Remotes.GunAimRelay:FireAllClients(batch)
	end
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

local function update(dt: number)
	for model, c in carriers do
		if model.Parent == nil then
			carriers[model] = nil
			continue
		end
		if not alive(model) then
			Firearms.take(model) -- (dead: the gun is gone; a corpse never carries one)
			continue
		end
		if model:GetAttribute("DuelId") ~= nil then
			Firearms.take(model) -- (no guns in a duel)
			continue
		end
		local down = Knockout.isKnockedOut(model) or Ragdoll.isRagdolled(model)
		if down and c.drawn then
			-- put away at once (the look: GunModel slings it), the action is lost
			c.drawn = false
			c.bipod = false
			c.readyAt = math.huge
			stopAction(c)
			publish(c)
		end
		local player = c.player
		local sprinting = player ~= nil and player:GetAttribute("Sprinting") == true
		if c.action and (model:GetAttribute("Stunned") == true or sprinting) then
			interrupt(c)
		end
		if c.bipod then
			local root = rootOf(model)
			if root and root.AssemblyLinearVelocity.Magnitude > BIPOD_MOVE then
				c.bipod = false
				publish(c)
			end
		end
		stepAction(c)
	end
	relayAims(dt)
end

function Firearms.start()
	Remotes.FireShot.OnServerEvent:Connect(onFireShot)
	Remotes.GunAction.OnServerEvent:Connect(onGunAction)
	Remotes.GunAim.OnServerEvent:Connect(onGunAim)
	RunService.Heartbeat:Connect(update)
	local function watch(player: Player)
		player:GetAttributeChangedSignal("Sprinting"):Connect(function()
			if player:GetAttribute("Sprinting") ~= true then
				sprintEndedAt[player] = os.clock()
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		sprintEndedAt[player] = nil
		local character = player.Character
		if character then
			carriers[character] = nil
		end
	end)
end

return Firearms
