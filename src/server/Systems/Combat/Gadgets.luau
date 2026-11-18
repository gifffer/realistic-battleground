--!strict
-- Gadgets: Dr. Rift's moves that aren't blows (Shared/Kits/Rift, KitTypes
-- GadgetDef). SERVER-AUTHORITATIVE: the server flies the flask, traces the
-- ray, checks the portal, finds who the shockwave reaches; every hit still
-- goes through Combat's resolveHit (DuelId, dodge, block, KO...).
--
--   flask   thrown in an arc; bursts on the first thing it touches: the
--           body it hit takes `hit`, everyone in `radius` (in sight of the
--           burst) takes `splash`, pushed away from the burst. Acid leaves a
--           puddle that keeps burning whoever stands in it.
--   ray     a straight beam from his hand where he aims, stopped by walls:
--           the first body in its way (or all of them: `pierce`).
--   portal  a portal where he aims (floor or wall, in range, inside the map,
--           room for him), one in front of him; he steps through. Checked
--           BEFORE the move starts (Gadgets.portalTarget): a shot that can't
--           open fizzles (short cooldown, no stamina).
--   wave    everyone around him (in sight) at once, pushed away.
--   swarm   his clones go for the one he points at (Combat/Clones).
--
-- Remotes.RiftFx(kind, data) tells every client what to show (look only):
--   "FlaskThrown" { by, id, kind, origin, velocity, gravity }
--   "FlaskBurst"  { id, kind, position, radius }
--   "Puddle"      { position, radius, seconds }
--   "Ray"         { by, from, to, width, big }
--   "PortalShot"  { by, to }                 (the shot flies to `to`)
--   "Portals"     { by, entry: CFrame, exit: CFrame, seconds }
--   "PortalFizzle"{ by, at: Vector3? }
--   "Wave"        { by, position, radius }
--   "CloneIn" / "CloneOut" { clone, at: CFrame } (Combat/Clones)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Push = require(ReplicatedStorage.Shared.Util.Push)
local Knockout = require(script.Parent.Parent.Knockout)
local Ragdoll = require(script.Parent.Parent.Ragdoll)
local Clones = require(script.Parent.Clones)
local MapBounds = require(script.Parent.MapBounds)
local State = require(script.Parent.State)

type CombatState = State.CombatState
type HitSpec = State.HitSpec

export type Context = {
	getState: (model: Model) -> CombatState?,
	allStates: () -> { [Model]: CombatState },
	now: () -> number,
	isAlive: (state: CombatState) -> boolean,
	resolveHit: (attacker: CombatState, victim: CombatState, spec: HitSpec) -> boolean,
	-- Starts a burn without a blow (an acid puddle): same rules as a hit
	-- (same fight, not KO'd, not in a cutscene, not on his own side).
	burn: (attacker: CombatState, victim: CombatState, burn: Kits.BurnDef) -> (),
	specFor: (hit: Kits.HitDef, zone: Types.HitZone, moveId: string) -> HitSpec,
}

local Gadgets = {}

local ctx: Context? = nil

function Gadgets.bind(context: Context)
	ctx = context
end

local function context(): Context
	assert(ctx, "[Gadgets] Combat.start() must call Gadgets.bind() first")
	return ctx
end

local PART_ZONES: { [string]: Types.HitZone } = {
	Head = "Head",
	Torso = "Torso",
	HumanoidRootPart = "Torso",
	["Right Arm"] = "Torso",
	["Left Arm"] = "Torso",
	["Right Leg"] = "Legs",
	["Left Leg"] = "Legs",
}

local flaskSeq = 0

-- Every fighter model (to keep them out of the world raycasts).
local function fighterModels(): { Instance }
	return CollectionService:GetTagged(Config.Combat.TAG)
end

-- Same side (him and his clones): never hurt by his gadgets.
local function sameSide(a: CombatState, b: CombatState): boolean
	return (a.owner or a) == (b.owner or b)
end

-- A fighter his gadget can reach (alive, standing, not on his side).
local function target(state: CombatState, other: CombatState): boolean
	local c = context()
	return other ~= state
		and not sameSide(state, other)
		and other.model:GetAttribute("DuelId") == state.model:GetAttribute("DuelId")
		and c.isAlive(other)
		and not Knockout.isKnockedOut(other.model)
end

-- Is there nothing solid between `from` and `model`'s torso?
local function inSight(from: Vector3, model: Model): boolean
	local torso = model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart")
	if torso == nil or not torso:IsA("BasePart") then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = fighterModels()
	params.RespectCanCollide = true
	local offset = torso.Position - from
	return workspace:Raycast(from, offset, params) == nil
end

-- His right hand (the gun hand), roughly, at head height in front.
local function handOf(state: CombatState): Vector3
	return (state.root.CFrame * CFrame.new(0.9, 1.3, -0.9)).Position
end

local function headOf(state: CombatState): Vector3
	local head = state.model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return state.root.Position + Vector3.new(0, 1.5, 0)
end

local function fx(kind: string, data: { [string]: any })
	Remotes.RiftFx:FireAllClients(kind, data)
end

-- The spec of a gadget hit: the move's HitDef, coming from `from` (no
-- parry, no slip; blocked if it comes from the front), pushed away from
-- `pushFrom` if set.
local function specOf(
	hit: Kits.HitDef,
	zone: Types.HitZone,
	moveId: string,
	from: Vector3,
	pushFrom: Vector3?
): HitSpec
	local spec = context().specFor(hit, zone, moveId)
	spec.from = from
	spec.pushFrom = pushFrom
	return spec
end

------------------------------------------------------------------------------
-- Flask
------------------------------------------------------------------------------

local function puddle(
	state: CombatState,
	position: Vector3,
	def: { radius: number, seconds: number, burn: Kits.BurnDef }
)
	local c = context()
	fx("Puddle", { position = position, radius = def.radius, seconds = def.seconds })
	local ends = c.now() + def.seconds
	local nextTick = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local time = c.now()
		if time >= ends then
			if connection then
				connection:Disconnect()
			end
			return
		end
		if time < nextTick then
			return
		end
		nextTick = time + 0.25
		for _, other in c.allStates() do
			if target(state, other) then
				local offset = other.root.Position - position
				local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
				-- Standing in it (feet near the floor, not jumping over it).
				if flat <= def.radius and offset.Y > -1 and offset.Y < 4.5 then
					c.burn(state, other, def.burn)
				end
			end
		end
	end)
end

local function burst(
	state: CombatState,
	move: Kits.MoveDef,
	flask: Kits.FlaskDef,
	id: number,
	position: Vector3,
	direct: CombatState?
)
	local c = context()
	fx("FlaskBurst", { id = id, kind = flask.kind, position = position, radius = flask.radius })
	for _, other in c.allStates() do
		if other ~= direct and target(state, other) then
			local distance = (other.root.Position - position).Magnitude
			if distance <= flask.radius and inSight(position, other.model) then
				c.resolveHit(
					state,
					other,
					specOf(flask.splash, "Torso", move.id, position, position)
				)
			end
		end
	end
	local def = flask.puddle
	if def then
		-- On the floor under the burst.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = fighterModels()
		params.RespectCanCollide = true
		local floor =
			workspace:Raycast(position + Vector3.new(0, 0.5, 0), Vector3.new(0, -12, 0), params)
		if floor then
			puddle(state, floor.Position, def)
		end
	end
end

local function throwFlask(
	state: CombatState,
	move: Kits.MoveDef,
	flask: Kits.FlaskDef,
	aim: Vector3?,
	token: number
)
	local c = context()
	task.delay(flask.release, function()
		if state.attackToken ~= token or not c.isAlive(state) then
			return -- stunned during the wind-up: he keeps it
		end
		flaskSeq += 1
		local id = flaskSeq
		local direction = aim or state.root.CFrame.LookVector
		local origin = handOf(state)
		local velocity = direction.Unit * flask.speed + Vector3.new(0, flask.lift, 0)
		fx("FlaskThrown", {
			by = state.model,
			id = id,
			kind = flask.kind,
			origin = origin,
			velocity = velocity,
			gravity = flask.gravity,
		})
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = { state.model }
		params.FilterDescendantsInstances = ignore
		params.RespectCanCollide = false
		local started = c.now()
		local position = state.root.Position
		local done = false
		-- One step of flight: true if it burst.
		local function fly(from: Vector3, step: Vector3): boolean
			local a = from
			local left = step
			for _ = 1, 6 do
				local hit = workspace:Raycast(a, left, params)
				if hit == nil then
					return false
				end
				local part = hit.Instance
				local model = part:FindFirstAncestorOfClass("Model")
				local other = if model then c.getState(model) else nil
				local body = other ~= nil
					and other.model == part.Parent
					and PART_ZONES[part.Name] ~= nil
				if other and (sameSide(state, other) or not body) then
					-- his own clones, hats, accessories: through
					table.insert(ignore, if body then other.model else part)
					params.FilterDescendantsInstances = ignore
				elseif not part.CanCollide and not body then
					table.insert(ignore, part)
					params.FilterDescendantsInstances = ignore
				else
					local direct: CombatState? = nil
					if other and body and target(state, other) then
						direct = other
						c.resolveHit(
							state,
							other,
							specOf(flask.hit, PART_ZONES[part.Name], move.id, a)
						)
					end
					burst(state, move, flask, id, hit.Position, direct)
					return true
				end
				left -= hit.Position - a
				a = hit.Position
				if left.Magnitude < 1e-3 then
					return false
				end
			end
			return false
		end
		-- From his body to his hand first (not through a wall he stands at).
		if fly(position, origin - position) then
			return
		end
		position = origin
		local connection: RBXScriptConnection? = nil
		connection = RunService.Heartbeat:Connect(function(dt: number)
			if done then
				return
			end
			local step = velocity * dt
			if fly(position, step) then
				done = true
			elseif c.now() - started > flask.lifetime then
				done = true
				burst(state, move, flask, id, position, nil)
			end
			if done then
				if connection then
					connection:Disconnect()
				end
				return
			end
			position += step
			velocity -= Vector3.new(0, flask.gravity * dt, 0)
		end)
	end)
end

------------------------------------------------------------------------------
-- Ray
------------------------------------------------------------------------------

-- The point of the line a→b closest to p, and how far along it (0 at a, 1
-- at b; outside 0-1: before / past the segment).
local function closest(a: Vector3, b: Vector3, p: Vector3): (Vector3, number)
	local ab = b - a
	local length2 = ab:Dot(ab)
	if length2 < 1e-6 then
		return a, 0
	end
	local t = (p - a):Dot(ab) / length2
	return a + ab * t, t
end

local function fireRay(
	state: CombatState,
	move: Kits.MoveDef,
	ray: Kits.RayDef,
	aim: Vector3?,
	token: number
)
	local c = context()
	task.delay(ray.at, function()
		if state.attackToken ~= token or not c.isAlive(state) then
			return
		end
		local direction = (aim or state.root.CFrame.LookVector).Unit
		local from = handOf(state)
		-- Walls stop it (bodies are found below, along the line).
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = fighterModels()
		params.RespectCanCollide = true
		local start = headOf(state)
		-- (not through a wall he stands against: from his head to his hand)
		local blocked = workspace:Raycast(start, from - start, params)
		if blocked then
			from = blocked.Position
		end
		local wall = workspace:Raycast(from, direction * ray.range, params)
		local to = if wall then wall.Position else from + direction * ray.range
		-- Bodies along it: the closest point of each body to the line.
		type Found = { state: CombatState, t: number, zone: Types.HitZone }
		local found: { Found } = {}
		local reach = ray.width / 2 + 1.1 -- (half a body)
		for _, other in c.allStates() do
			if target(state, other) then
				local body = other.root.Position
				-- Feet to head, nearest to the line.
				local onLine, t = closest(from, to, body)
				local length = (to - from).Magnitude
				-- (along the beam only: not behind the gun, not past the wall)
				local along = t * length
				local inRange = along > -0.3 and along < length + 0.2
				t = math.clamp(t, 0, 1)
				onLine = from + (to - from) * t
				local height = math.clamp(onLine.Y - body.Y, -3, 2)
				local point = body + Vector3.new(0, height, 0)
				local offset = point - onLine
				if
					inRange
					and Vector3.new(offset.X, 0, offset.Z).Magnitude <= reach
					and math.abs(offset.Y) <= reach + 1
					and inSight(from, other.model)
				then
					local zone: Types.HitZone = if height > 1.1
						then "Head"
						elseif height < -1.2 then "Legs"
						else "Torso"
					table.insert(found, { state = other, t = t, zone = zone })
				end
			end
		end
		table.sort(found, function(a, b)
			return a.t < b.t
		end)
		if not ray.pierce and found[1] then
			found = { found[1] }
			to = from + (to - from) * found[1].t
		end
		fx("Ray", { by = state.model, from = from, to = to, width = ray.width, big = ray.pierce })
		for _, item in found do
			c.resolveHit(state, item.state, specOf(ray.hit, item.zone, move.id, from))
		end
	end)
end

------------------------------------------------------------------------------
-- Portal
------------------------------------------------------------------------------

-- Where the portal gun can open the far portal (aimed at a floor or a
-- wall within range, not too high, inside the map, room for him there):
-- the CFrame he comes out at (facing away from the surface / his way), and
-- the portal's CFrame on the surface. nil = it can't (the shot fizzles).
function Gadgets.portalTarget(
	state: CombatState,
	portal: Kits.PortalDef,
	aim: Vector3?
): (CFrame?, CFrame?)
	if aim == nil then
		return nil, nil
	end
	local direction = aim.Unit
	if math.deg(math.asin(math.clamp(direction.Y, -1, 1))) > portal.maxPitch then
		return nil, nil -- aimed too high: nothing to open on
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = fighterModels()
	params.RespectCanCollide = true
	local hit = workspace:Raycast(headOf(state), direction * portal.range, params)
	if hit == nil or hit.Normal.Y < -0.4 then
		return nil, nil -- the void, or a ceiling
	end
	local flatLook = Vector3.new(direction.X, 0, direction.Z)
	flatLook = if flatLook.Magnitude > 1e-3 then flatLook.Unit else state.root.CFrame.LookVector
	local exit: Vector3
	local face: CFrame
	if hit.Normal.Y > 0.6 then
		-- A floor: he comes up out of it, standing.
		exit = hit.Position + Vector3.new(0, 3.05, 0)
		face = CFrame.lookAt(
			hit.Position + Vector3.new(0, 0.05, 0),
			hit.Position + Vector3.new(0, 1, 0)
		)
	else
		-- A wall: he steps out of it, onto the floor below if it's close.
		local out = hit.Position + hit.Normal * 1.4
		local floor = workspace:Raycast(out, Vector3.new(0, -8, 0), params)
		if floor == nil then
			return nil, nil -- a wall over the void
		end
		exit = Vector3.new(out.X, floor.Position.Y + 3.05, out.Z)
		local onWall = Vector3.new(hit.Position.X, exit.Y, hit.Position.Z)
		face = CFrame.lookAt(onWall + hit.Normal * 0.05, onWall + hit.Normal)
		flatLook = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
		flatLook = if flatLook.Magnitude > 1e-3 then flatLook.Unit else state.root.CFrame.LookVector
	end
	if not MapBounds.allows(state.model, exit) then
		return nil, nil
	end
	return CFrame.lookAt(exit, exit + flatLook), face
end

local function usePortal(
	state: CombatState,
	portal: Kits.PortalDef,
	exit: CFrame?,
	face: CFrame?,
	token: number
)
	local c = context()
	task.delay(portal.at, function()
		if state.attackToken ~= token or not c.isAlive(state) then
			return
		end
		if exit == nil or face == nil then
			fx("PortalFizzle", { by = state.model })
			return
		end
		fx("PortalShot", { by = state.model, to = face.Position })
	end)
	if exit == nil or face == nil then
		return
	end
	task.delay(portal.open, function()
		if state.attackToken ~= token or not c.isAlive(state) then
			return
		end
		-- The near one: standing, right in front of him.
		local entry = state.root.CFrame * CFrame.new(0, 0, -1.6) * CFrame.Angles(0, math.pi, 0)
		fx("Portals", {
			by = state.model,
			entry = entry,
			exit = face,
			-- (where he comes out, and when: his own client moves him there
			-- itself at that moment, it simulates its character)
			land = exit,
			travelIn = portal.travel - portal.open,
			seconds = portal.travel - portal.open + 0.7,
		})
		-- Stepping in: he can't be hit in between.
		state.invulnerableUntil =
			math.max(state.invulnerableUntil, c.now() + portal.travel - portal.open + 0.15)
	end)
	task.delay(portal.travel, function()
		if
			state.attackToken ~= token
			or not c.isAlive(state)
			or Knockout.isKnockedOut(state.model)
		then
			return
		end
		-- (still room there? something may have moved in)
		if not MapBounds.hasRoom(exit.Position, { state.model :: Instance }) then
			fx("PortalFizzle", { by = state.model, at = face.Position })
			return
		end
		Push.cancel(state.root)
		state.knockbackUntil = 0
		-- (a player's client simulates its own character and would keep it
		-- where it was for a while: the server takes it for the move, then
		-- gives it back)
		local root = state.root
		local owner = state.player
		local owned = owner ~= nil and root:CanSetNetworkOwnership()
		if owned then
			root:SetNetworkOwner(nil)
		end
		state.model:PivotTo(exit)
		root.AssemblyLinearVelocity = Vector3.zero
		if owned then
			task.delay(0.1, function()
				if
					root.Parent
					and root:CanSetNetworkOwnership()
					and owner
					and owner.Character == state.model
					-- (knocked down meanwhile: the server keeps the limp body,
					-- Ragdoll gives it back when it gets up)
					and not Ragdoll.isRagdolled(state.model)
				then
					root:SetNetworkOwner(owner)
				end
			end)
		end
	end)
end

------------------------------------------------------------------------------
-- Shockwave
------------------------------------------------------------------------------

local function wave(state: CombatState, move: Kits.MoveDef, def: Kits.WaveDef, token: number)
	local c = context()
	task.delay(def.at, function()
		if state.attackToken ~= token or not c.isAlive(state) then
			return
		end
		local center = state.root.Position
		fx(
			"Wave",
			{ by = state.model, position = center - Vector3.new(0, 3, 0), radius = def.radius }
		)
		for _, other in c.allStates() do
			if target(state, other) then
				local offset = other.root.Position - center
				if
					Vector3.new(offset.X, 0, offset.Z).Magnitude <= def.radius
					and math.abs(offset.Y) < 6
					and inSight(center, other.model)
				then
					c.resolveHit(
						state,
						other,
						specOf(def.hit, def.hit.zone or "Torso", move.id, center, center)
					)
				end
			end
		end
	end)
end

------------------------------------------------------------------------------
-- Swarm (the clones go for one fighter)
------------------------------------------------------------------------------

-- The fighter he points at (the best lined up with his aim, in range), or
-- the closest one in front of him.
local function pointedAt(state: CombatState, range: number, aim: Vector3?): CombatState?
	local c = context()
	local look = (aim or state.root.CFrame.LookVector).Unit
	local from = headOf(state)
	local best: CombatState? = nil
	local bestScore = -math.huge
	for _, other in c.allStates() do
		if target(state, other) and other.owner == nil then
			local offset = other.root.Position - from
			local distance = offset.Magnitude
			if distance <= range and distance > 0.1 then
				local dot = offset.Unit:Dot(look)
				if dot > 0.5 then
					local score = dot * 2 - distance / range
					if score > bestScore then
						best = other
						bestScore = score
					end
				end
			end
		end
	end
	return best
end

local function swarm(
	state: CombatState,
	move: Kits.MoveDef,
	def: Kits.SwarmDef,
	aim: Vector3?,
	token: number
)
	local c = context()
	task.delay(def.at, function()
		if state.attackToken ~= token or not c.isAlive(state) then
			return
		end
		local victim = pointedAt(state, def.range, aim)
		if victim == nil then
			fx("PortalFizzle", { by = state.model })
			return
		end
		Clones.swarm(state, victim, move.id, def.hits)
	end)
end

------------------------------------------------------------------------------

-- Runs the gadget of `move` (Moves.use, once it started). `portalExit` /
-- `portalFace` = what Gadgets.portalTarget found before it started.
function Gadgets.run(
	state: CombatState,
	move: Kits.MoveDef,
	gadget: Kits.GadgetDef,
	aim: Vector3?,
	token: number,
	portalExit: CFrame?,
	portalFace: CFrame?
)
	if gadget.flask then
		throwFlask(state, move, gadget.flask, aim, token)
	end
	if gadget.ray then
		fireRay(state, move, gadget.ray, aim, token)
	end
	if gadget.portal then
		usePortal(state, gadget.portal, portalExit, portalFace, token)
	end
	if gadget.wave then
		wave(state, move, gadget.wave, token)
	end
	if gadget.swarm then
		swarm(state, move, gadget.swarm, aim, token)
	end
end

return table.freeze(Gadgets)
