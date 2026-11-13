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
--      round head you see (radius 0.6; the head part is a 2x1x1 box): a
--      line passing beside the face goes on.
--   A hat / hair / face accessory on the head counts as the head. Other
--   accessories, the root part, held tools and effects don't stop it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HeatBeam = {}

HeatBeam.CORE_RADIUS = 0.25 -- the part of the beam that meets a body
HeatBeam.HEAD_RADIUS = 0.6 -- the round head you see (per stud of head height)
HeatBeam.HEAD_PAD = 0.3 -- leeway around it (the beam has some width)

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
-- it wears on its head.
local function addBody(list: { Instance }, model: Model)
	for _, name in LIMBS do
		local limb = model:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			table.insert(list, limb)
		end
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		for _, child in model:GetChildren() do
			if child:IsA("Accessory") then
				local handle = child:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") and onHead(handle, head) then
					table.insert(list, handle)
				end
			end
		end
	end
end

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
		for _, instance in CollectionService:GetTagged(Config.Combat.TAG) do
			if instance ~= owner and instance:IsA("Model") then
				addBody(bodies, instance)
			end
		end
		bodyParams.FilterDescendantsInstances = bodies
	end

	-- The first body part on the line, before `reach` (along the axis);
	-- fills `result` and returns true, or false (none).
	local function firstBody(origin: Vector3, direction: Vector3, reach: number): boolean
		local start = origin - direction * BACKSTEP
		-- (the sphere's front stops at the wall: nobody is hit through it)
		local sweep = math.max(0.05, reach + BACKSTEP - HeatBeam.CORE_RADIUS)
		for _ = 1, MAX_PASSES do
			local hit =
				workspace:Spherecast(start, HeatBeam.CORE_RADIUS, direction * sweep, bodyParams)
			if hit == nil then
				return false
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
			local head = if isHead and fighter then fighter:FindFirstChild("Head") else nil
			if head == nil or not head:IsA("BasePart") then
				-- an arm, the chest, a leg: the beam stops on it
				local along = math.clamp((hit.Position - origin):Dot(direction), 0, reach)
				result.length = along
				result.position = origin + direction * along
				result.normal = hit.Normal
				result.part = part
				result.fighter = fighter
				result.head = false
				result.burnAt = nil
				return true
			end
			-- The head: does the line really meet the round head?
			local centre = head.Position
			local radius = HeatBeam.HEAD_RADIUS * head.Size.Y
			local along = math.clamp((centre - origin):Dot(direction), 0, reach)
			local closest = origin + direction * along
			local offset = closest - centre
			local distance = offset.Magnitude
			if distance <= radius + HeatBeam.HEAD_PAD then
				-- where it meets the skin: where the line enters the head,
				-- or (grazing it) the point of the head nearest the line
				local at: Vector3
				if distance < radius then
					at = origin
						+ direction
							* math.max(0, along - math.sqrt(radius * radius - distance * distance))
				else
					at = centre + offset.Unit * radius
				end
				local length = math.clamp((at - origin):Dot(direction), 0, reach)
				local out = at - centre
				result.length = length
				result.position = origin + direction * length
				result.normal = if out.Magnitude > 1e-3 then out.Unit else -direction
				result.part = head
				result.fighter = fighter
				result.head = true
				result.burnAt = at
				return true
			end
			-- beside the face (a corner of the head box, a big hat): goes on,
			-- past that whole head at once (its head and every hat on it: one
			-- pass per fighter, however many accessories they wear)
			local removed = false
			for index = #bodies, 1, -1 do
				local body = bodies[index]
				local holder = body.Parent
				local onFighter = body == head
					or (holder ~= nil and holder:IsA("Accessory") and holder.Parent == fighter)
				if onFighter then
					bodies[index] = bodies[#bodies]
					bodies[#bodies] = nil
					table.insert(beside, body)
					removed = true
				end
			end
			if not removed then
				return false
			end
			bodyParams.FilterDescendantsInstances = bodies
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
