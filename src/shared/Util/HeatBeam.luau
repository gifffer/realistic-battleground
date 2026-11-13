--!strict
-- HeatBeam: where the Sentinel's heat vision goes and what it ends on.
-- ONE rule for the server (which decides the damage) and every client
-- (which draws the beam), so both stop it at the same place.
--
-- The beam is a thin line straight out of the eyes:
--   1. A wall stops it (a ray that respects CanCollide; fighters are not
--      walls). Same as before.
--   2. Before the wall, the first body part of a fighter on that line stops
--      it too. A thin sphere cast, which does NOT respect CanCollide: R6
--      arms and legs don't collide.
--   3. Only the HEAD burns. An arm, a shoulder, the chest, a leg in the
--      way shields it (and anyone behind). The head is checked against the
--      round head you see (radius 0.6; the head part is a 2x1x1 box), with
--      some leeway (the beam glows wide): a head the beam visibly touches
--      burns, even if the thin line only grazes it (above it, beside the
--      face, or through the top of the chest right under the chin); a line
--      passing farther beside the face goes on.
--   The body only stops it where the beam's white-hot core touches it (a
--   thin cast): a shoulder just under the line doesn't shield the head.
--   A hat / hair / face accessory on the head counts as the head. Other
--   accessories, the root part, held tools and effects don't stop it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HeatBeam = {}

HeatBeam.CORE_RADIUS = 0.13 -- the part of the beam a body must touch to stop it
HeatBeam.HEAD_RADIUS = 0.6 -- the round head you see (per stud of head height)
HeatBeam.HEAD_PAD = 0.4 -- leeway around it (the beam's glow is that wide)
-- The top of the chest right under the chin: a line through it that close
-- to the round head burns the head (the beam's glow is on the chin)...
HeatBeam.CHIN_PAD = 0.15
local CHIN_DEPTH = 0.55 -- (...when the head is no deeper than this behind it)

local MAX_WALLS = 8 -- (fighters skipped by the wall ray)
local MAX_PASSES = 8 -- (faces a line can pass beside, one per fighter)
local BACKSTEP = 0.5 -- (the body cast starts at the head's centre: a face
-- pressed against the attacker's still counts)
local REFRESH = 0.25 -- (s) the list of bodies is rebuilt this often

local LIMBS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

-- (accessories worn on the head, when no weld says where they are)
local HEAD_ATTACHMENTS = table.freeze({
	HatAttachment = true,
	HairAttachment = true,
	FaceFrontAttachment = true,
	FaceCenterAttachment = true,
})

export type Result = {
	length: number, -- from the origin, along the direction
	position: Vector3, -- where it ends, on its axis
	normal: Vector3?, -- the surface there (nil: nothing, it ran out)
	part: BasePart?, -- what it ends on (the Head itself for a hat)
	fighter: Model?, -- the fighter it ends on (nil: a wall / nothing)
	head: boolean, -- it ends on that fighter's head: it burns there
	burnAt: Vector3?, -- (head only) the point of the round head it touches
}

export type Trace = (origin: Vector3, direction: Vector3, range: number) -> Result

-- Fighters come and go: the lists are rebuilt as soon as that happens.
local version = 0
local function bump()
	version += 1
end
CollectionService:GetInstanceAddedSignal(Config.Combat.TAG):Connect(bump)
CollectionService:GetInstanceRemovedSignal(Config.Combat.TAG):Connect(bump)

-- Is this accessory handle worn on `head`? (its weld says; without one,
-- the name of its attachment)
local function onHead(handle: BasePart, head: BasePart): boolean
	local elsewhere = false
	local byName = false
	for _, child in handle:GetChildren() do
		if child:IsA("JointInstance") or child:IsA("WeldConstraint") then
			local joint = child :: any
			local a, b = joint.Part0, joint.Part1
			if a == head or b == head then
				return true
			elseif a ~= nil and b ~= nil then
				elsewhere = true -- (welded to another body part)
			end
		elseif child:IsA("RigidConstraint") then
			local a, b = child.Attachment0, child.Attachment1
			if (a and a.Parent == head) or (b and b.Parent == head) then
				return true
			elseif a and b then
				elsewhere = true
			end
		elseif child:IsA("Attachment") and HEAD_ATTACHMENTS[child.Name] then
			byName = true
		end
	end
	return byName and not elsewhere
end

-- The parts of `model` that stop the beam: its six body parts and what
-- it wears on its head. Returns its head.
local function addBody(list: { Instance }, model: Model): BasePart?
	for _, name in LIMBS do
		local limb = model:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			table.insert(list, limb)
		end
	end
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return nil
	end
	for _, child in model:GetChildren() do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") and onHead(handle, head) then
				table.insert(list, handle)
			end
		end
	end
	return head
end

-- A head close enough to the line to burn (see the top), before `reach`.
type Near = {
	fighter: Model,
	head: BasePart,
	at: Vector3, -- the point of the round head it touches
	along: number, -- how far along the line that is
	distance: number, -- from the line to the head's centre
	radius: number, -- of the round head
}

-- A tracer for the beam of `owner` (never stopped by `owner` itself nor by
-- `ignore`). It reuses its tables: the Result it returns is the same table
-- each call (read it before the next call).
function HeatBeam.tracer(owner: Model, ignore: { Instance }?): Trace
	local wallParams = RaycastParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Exclude
	wallParams.RespectCanCollide = true
	local bodyParams = RaycastParams.new()
	bodyParams.FilterType = Enum.RaycastFilterType.Include
	bodyParams.RespectCanCollide = false

	local skipped: { Instance } = {}
	local bodies: { Instance } = {}
	local beside: { Instance } = {}
	local heads: { { fighter: Model, head: BasePart } } = {}
	local near: { [Model]: Near } = {}
	local builtVersion = -1
	local builtAt = -math.huge
	local result: Result = {
		length = 0,
		position = Vector3.zero,
		normal = nil,
		part = nil,
		fighter = nil,
		head = false,
		burnAt = nil,
	}

	local function refresh()
		local now = os.clock()
		if builtVersion == version and now - builtAt < REFRESH then
			return
		end
		builtVersion, builtAt = version, now
		table.clear(bodies)
		table.clear(heads)
		for _, instance in CollectionService:GetTagged(Config.Combat.TAG) do
			if instance ~= owner and instance:IsA("Model") then
				local head = addBody(bodies, instance)
				if head then
					table.insert(heads, { fighter = instance, head = head })
				end
			end
		end
		bodyParams.FilterDescendantsInstances = bodies
	end

	-- The heads the line passes close enough to (before the wall, at
	-- `reach`); returns the nearest one along the line.
	local function nearHeads(origin: Vector3, direction: Vector3, reach: number): Near?
		table.clear(near)
		local nearest: Near? = nil
		for _, entry in heads do
			local head = entry.head
			if head.Parent ~= entry.fighter then
				continue -- (gone since the list was made)
			end
			local centre = head.Position
			local radius = HeatBeam.HEAD_RADIUS * head.Size.Y
			local along = (centre - origin):Dot(direction)
			if along < 0 or along > reach then
				continue -- (behind the eyes, or behind the wall)
			end
			local offset = origin + direction * along - centre
			local distance = offset.Magnitude
			if distance > radius + HeatBeam.HEAD_PAD then
				continue
			end
			-- where it meets the skin: where the line enters the head, or
			-- (grazing it) the point of the head nearest the line
			local at = if distance < radius
				then origin + direction * math.max(
					0,
					along - math.sqrt(radius * radius - distance * distance)
				)
				else centre + offset.Unit * radius
			local found: Near = {
				fighter = entry.fighter,
				head = head,
				at = at,
				along = math.clamp((at - origin):Dot(direction), 0, reach),
				distance = distance,
				radius = radius,
			}
			near[entry.fighter] = found
			if nearest == nil or found.along < nearest.along then
				nearest = found
			end
		end
		return nearest
	end

	local function burnHead(origin: Vector3, direction: Vector3, hit: Near)
		local out = hit.at - hit.head.Position
		result.length = hit.along
		result.position = origin + direction * hit.along
		result.normal = if out.Magnitude > 1e-3 then out.Unit else -direction
		result.part = hit.head
		result.fighter = hit.fighter
		result.head = true
		result.burnAt = hit.at
	end

	-- The first body part on the line, before `reach` (along the axis);
	-- fills `result` and returns true, or false (none).
	local function firstBody(origin: Vector3, direction: Vector3, reach: number): boolean
		local nearest = nearHeads(origin, direction, reach)
		local start = origin - direction * BACKSTEP
		-- (the sphere's front stops at the wall: nobody is hit through it)
		local sweep = math.max(0.05, reach + BACKSTEP - HeatBeam.CORE_RADIUS)
		for _ = 1, MAX_PASSES do
			local hit =
				workspace:Spherecast(start, HeatBeam.CORE_RADIUS, direction * sweep, bodyParams)
			if hit == nil then
				break
			end
			-- (something stuck on a body part - a wound, an effect - is
			-- that body part)
			local part: BasePart = hit.Instance
			local fighter = part:FindFirstAncestorOfClass("Model")
			local parent = part.Parent
			if parent ~= fighter and not (parent and parent:IsA("Accessory")) then
				local holder = part:FindFirstAncestorWhichIsA("BasePart")
				if holder then
					part = holder
				end
			end
			local worn = part.Parent ~= nil and part.Parent:IsA("Accessory")
			local isHead = worn or (part.Name == "Head" and part.Parent == fighter)
			local close = if fighter then near[fighter] else nil
			if not isHead then
				-- An arm, the chest, a leg: the beam stops on it, unless a
				-- head it touches is before it (a line grazing a head, the
				-- top of the chest under the chin of the head it burns).
				local along = math.clamp((hit.Position - origin):Dot(direction), 0, reach)
				local chin = close ~= nil
					and part.Name == "Torso"
					and close.distance <= close.radius + HeatBeam.CHIN_PAD
				if close and chin and close.along <= along + CHIN_DEPTH then
					burnHead(origin, direction, close)
				elseif nearest and nearest.along <= along then
					burnHead(origin, direction, nearest)
				else
					result.length = along
					result.position = origin + direction * along
					result.normal = hit.Normal
					result.part = part
					result.fighter = fighter
					result.head = false
					result.burnAt = nil
				end
				return true
			end
			if close then
				burnHead(origin, direction, close)
				return true
			end
			-- beside the face (a corner of the head box, a big hat): goes on,
			-- past that whole head at once (its head and every hat on it: one
			-- pass per fighter, however many accessories they wear)
			local head = if fighter then fighter:FindFirstChild("Head") else nil
			local removed = false
			for index = #bodies, 1, -1 do
				local body = bodies[index]
				local holder = body.Parent
				local onFighter = (head ~= nil and body == head)
					or (holder ~= nil and holder:IsA("Accessory") and holder.Parent == fighter)
				if onFighter then
					bodies[index] = bodies[#bodies]
					bodies[#bodies] = nil
					table.insert(beside, body)
					removed = true
				end
			end
			if not removed then
				break
			end
			bodyParams.FilterDescendantsInstances = bodies
		end
		-- Nothing in the way of a head the beam touches (passing just over
		-- it, beside the face): it burns.
		if nearest then
			burnHead(origin, direction, nearest)
			return true
		end
		return false
	end

	return function(origin: Vector3, direction: Vector3, range: number): Result
		-- 1. Walls (the fighters crossed don't count: see below)
		table.clear(skipped)
		table.insert(skipped, owner)
		if ignore then
			for _, instance in ignore do
				table.insert(skipped, instance)
			end
		end
		local reach = range
		local wall: RaycastResult? = nil
		for _ = 1, MAX_WALLS do
			wallParams.FilterDescendantsInstances = skipped
			local hit = workspace:Raycast(origin, direction * range, wallParams)
			if hit == nil then
				break
			end
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChildOfClass("Humanoid") then
				table.insert(skipped, model)
			else
				reach, wall = hit.Distance, hit
				break
			end
		end

		-- 2. A body before the wall
		refresh()
		local stopped = firstBody(origin, direction, reach)
		if #beside > 0 then
			for _, part in beside do
				table.insert(bodies, part)
			end
			table.clear(beside)
			bodyParams.FilterDescendantsInstances = bodies
		end
		if stopped then
			return result
		end

		-- 3. The wall, or nothing within range
		result.length = reach
		result.position = origin + direction * reach
		result.normal = if wall then wall.Normal else nil
		result.part = if wall then wall.Instance :: BasePart else nil
		result.fighter = nil
		result.head = false
		result.burnAt = nil
		return result
	end
end

return table.freeze(HeatBeam)
