--!strict
-- Squish: makes a flying piece of body (an organ, brain, flesh) SOFT and
-- WET instead of a hard plastic block.
--
-- What makes something look soft, and how it is done (Roblox has no soft
-- bodies, so the look is faked):
--   • it doesn't bounce or tumble like a stone: no elasticity, a lot of
--     friction, and once down its spin dies fast (it slumps and stays);
--   • on every impact it SQUASHES flat along the hit then wobbles back
--     (a damped spring), keeping its volume (flatter = wider), and stays a
--     little flattened once at rest (it sags under its own weight);
--   • it jiggles a little while it flies (it's not rigid);
--   • it's wet: shiny, it splats blood where it lands and leaves a smear
--     when it slides on something;
--   • its surface isn't one flat colour: darker / lighter blotches and fine
--     vessels (`detail`).
-- The physics and the look are apart: the piece's own part becomes an
-- invisible collider of a fixed size (no popping through the floor); a
-- copy of it, welded on, is what you see, and that copy (with the piece's
-- other layers) is what squashes - its contact side kept where it was.
--
--   Squish.detail(part, kind)    surface blotches and vessels ("Liver",
--                                 "Brain", "Flesh") - before `soft`, the
--                                 part in the workspace
--   Squish.soft(part, options)   `part`: the piece (its welded children
--                                 squash with it)
--   Squish.squeeze(part, along, amount)  squashed by a hand closing on it

local RunService = game:GetService("RunService")

local Blood = require(script.Parent.Blood)

local Squish = {}

export type Options = {
	stiffness: number?, -- spring (higher = firmer: wobbles faster, squashes less)
	softness: number?, -- how much an impact squashes it (0.3 = a lot)
	sag: number?, -- flattening once at rest (0.15 = 15 %)
	bleeds: boolean?, -- splats / smears blood
	lifetime: number?, -- seconds it is followed (then left as it is)
}

-- A visible part of the piece: its rest size, its weld to the collider
-- and the weld's rest offset.
type Member = { part: BasePart, size: Vector3, weld: Weld, c0: CFrame }
type Soft = {
	root: BasePart, -- the collider (invisible)
	members: { Member },
	normal: Vector3, -- the squash direction (world)
	offset: number, -- the spring's displacement (−: squashed)
	speed: number, -- its rate
	sag: number,
	sagNow: number,
	stiffness: number,
	softness: number,
	bleeds: boolean,
	lastVelocity: Vector3,
	lastSmear: number,
	lastSplat: number,
	stopAt: number,
	still: number,
	lastAlong: number,
	lastNormal: Vector3,
}

local softs: { Soft } = {}
local random = Random.new()

-- No bounce, lots of friction (the weights make 0 elasticity / high
-- friction win against the floor's values).
local SOFT_PHYSICS = PhysicalProperties.new(1.05, 1.6, 0, 3, 100)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
-- (through the piece itself)
local function surfaceParams(root: BasePart): RaycastParams
	rayParams.FilterDescendantsInstances = { root }
	return rayParams
end

-- A visible copy of the collider `root` (its mesh, its look), welded on.
local function visualOf(root: BasePart): (BasePart, Weld)
	local copy = root:Clone()
	for _, child in copy:GetChildren() do
		if not child:IsA("DataModelMesh") then
			child:Destroy()
		end
	end
	copy.Name = root.Name .. "Look"
	copy.Anchored = false
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.Massless = true
	copy.CFrame = root.CFrame
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = copy
	weld.Parent = copy
	copy.Parent = root
	return copy, weld
end

function Squish.soft(part: BasePart, options: Options?)
	local o: Options = options or {}
	part.CustomPhysicalProperties = SOFT_PHYSICS
	local members: { Member } = {}
	-- the piece's other layers (welded to it with a Weld) squash too
	for _, child in part:GetDescendants() do
		if child:IsA("Weld") and child.Part0 == part and child.Part1 then
			local layer = child.Part1 :: BasePart
			layer.CustomPhysicalProperties = SOFT_PHYSICS
			table.insert(members, { part = layer, size = layer.Size, weld = child, c0 = child.C0 })
		end
	end
	-- the piece itself: shown by a copy, the part only collides
	local look, lookWeld = visualOf(part)
	part.Transparency = 1
	table.insert(
		members,
		1,
		{ part = look, size = look.Size, weld = lookWeld, c0 = CFrame.identity }
	)
	table.insert(softs, {
		root = part,
		members = members,
		normal = Vector3.yAxis,
		offset = 0,
		speed = 0,
		sag = o.sag or 0.14,
		sagNow = 0,
		stiffness = o.stiffness or 260,
		softness = o.softness or 0.35,
		bleeds = o.bleeds ~= false,
		lastVelocity = part.AssemblyLinearVelocity,
		lastSmear = 0,
		lastSplat = 0,
		stopAt = os.clock() + (o.lifetime or 12),
		still = 0,
		lastAlong = 1,
		lastNormal = Vector3.yAxis,
	})
end

-- Squeezes a soft piece (`part`, given to `soft`) along the world
-- direction `along`: it squashes by `amount` (0.3 = a lot) and wobbles back
-- (a fist closing on it). Does nothing if it isn't soft (any more).
function Squish.squeeze(part: BasePart, along: Vector3, amount: number)
	if along.Magnitude < 1e-3 then
		return
	end
	for _, soft in softs do
		if soft.root == part then
			soft.normal = along.Unit
			soft.offset = -math.clamp(amount, 0, 0.6)
			soft.speed = 0
			return
		end
	end
end

-- The local axis of `frame` closest to the world direction `n`.
local function nearestAxis(frame: CFrame, n: Vector3): Vector3
	local l = frame:VectorToObjectSpace(n)
	local ax, ay, az = math.abs(l.X), math.abs(l.Y), math.abs(l.Z)
	return if ax >= ay and ax >= az
		then Vector3.xAxis
		elseif ay >= az then Vector3.yAxis
		else Vector3.zAxis
end

local function shape(soft: Soft)
	local along = math.clamp(1 + soft.offset - soft.sagNow, 0.45, 1.6)
	-- (settled: nothing to rewrite)
	if math.abs(along - soft.lastAlong) < 0.002 and soft.normal:Dot(soft.lastNormal) > 0.9999 then
		return
	end
	soft.lastAlong = along
	soft.lastNormal = soft.normal
	local across = 1 / math.sqrt(along) -- (volume kept)
	local root = soft.root
	-- A box only scales along its own axes: squash along the collider's
	-- axis closest to the hit, the same axis for every layer.
	local axisLocal = nearestAxis(root.CFrame, soft.normal)
	local axisWorld = root.CFrame:VectorToWorldSpace(axisLocal)
	-- which side touched: kept where it was (the look sinks onto it)
	local sign = if axisWorld:Dot(soft.normal) >= 0 then 1 else -1
	local half = math.abs((root.Size / 2):Dot(axisLocal))
	local shift = -axisLocal * sign * half * (1 - along)
	for _, member in soft.members do
		local p = member.part
		local mine = nearestAxis(p.CFrame, axisWorld)
		local scale = Vector3.one * across + mine * (along - across)
		p.Size = member.size * scale
		if member.weld.Parent then
			-- its offset from the collider squashed with the rest
			local offset = member.c0.Position
			local alongPart = axisLocal * offset:Dot(axisLocal)
			local moved = alongPart * along + (offset - alongPart) * across + shift
			member.weld.C0 = CFrame.new(moved) * member.c0.Rotation
		end
	end
end

local function update(dt: number)
	local now = os.clock()
	local index = 1
	while index <= #softs do
		local soft = softs[index]
		local root = soft.root
		if root.Parent == nil or now > soft.stopAt then
			softs[index] = softs[#softs]
			softs[#softs] = nil
			continue
		end
		local velocity = root.AssemblyLinearVelocity
		local before = soft.lastVelocity
		local change = velocity - before
		soft.lastVelocity = velocity
		-- An impact: the speed changed hard in one frame, beyond gravity's
		-- own pull (the same fall reads the same at any frame rate).
		local gdt = workspace.Gravity * dt
		local kick = math.min(change.Magnitude, (change + Vector3.new(0, gdt, 0)).Magnitude)
		if kick > 5 + 0.5 * gdt and not root.Anchored then
			local normal = change.Unit
			soft.normal = normal
			local amount = math.clamp(kick / 45, 0.08, 1) * soft.softness
			soft.offset = -amount
			soft.speed = 0
			-- it slumps a bit more each time it lands, up to its sag
			soft.sagNow = math.min(soft.sag, soft.sagNow + soft.sag * 0.6)
			-- wet slap, only against a surface (not a jolt in someone's hand)
			local surface = if soft.bleeds and now - soft.lastSplat > 0.12
				then workspace:Raycast(
					root.Position,
					-normal * (root.Size.Magnitude * 0.6 + 0.4),
					surfaceParams(root)
				)
				else nil
			if surface then
				soft.lastSplat = now
				Blood.splat(
					surface.Position,
					surface.Normal,
					math.clamp(root.Size.Magnitude * 0.45, 0.25, 1.4),
					before * 0.5,
					surface.Instance :: BasePart
				)
				for _ = 1, 3 do
					Blood.drop(
						surface.Position + surface.Normal * 0.15,
						surface.Normal * random:NextNumber(3, 7) + random:NextUnitVector() * 3,
						random:NextNumber(0.04, 0.08)
					)
				end
			end
			-- soft things don't keep rolling
			root.AssemblyAngularVelocity *= 0.35
		end
		-- (a little jiggle while flying fast; the same at any frame rate)
		local speed = velocity.Magnitude
		if speed > 8 and math.abs(soft.offset) < 0.02 then
			soft.speed += random:NextNumber(-1, 1) * speed * 0.02 * math.sqrt(dt * 60)
		end
		-- the damped spring (clamped, in small steps: stable on long frames)
		local damping = 2 * math.sqrt(soft.stiffness) * 0.32
		local h = math.min(dt, 0.1)
		local steps = math.ceil(h / (1 / 120))
		local sub = h / steps
		for _ = 1, steps do
			soft.speed += (-soft.stiffness * soft.offset - damping * soft.speed) * sub
			soft.offset += soft.speed * sub
		end
		if soft.offset ~= soft.offset or soft.speed ~= soft.speed then
			soft.offset, soft.speed = 0, 0 -- (NaN: reset)
		end
		-- resting: it sags along gravity, its spin dies
		if speed < 1.2 then
			soft.still += dt
			if soft.still > 0.15 then
				soft.normal = soft.normal:Lerp(Vector3.yAxis, math.min(1, dt * 3)).Unit
				root.AssemblyAngularVelocity *= math.max(0, 1 - dt * 6)
			end
		else
			soft.still = 0
		end
		-- sliding ON something (touching it): a smear of blood behind it
		if
			soft.bleeds
			and speed > 2.5
			and speed < 25
			and soft.still == 0
			and now - soft.lastSmear > 0.07
		then
			soft.lastSmear = now -- (throttled even when it doesn't touch)
			local f, s = root.CFrame, root.Size
			local below = 0.5
				* (
					math.abs(f.RightVector.Y) * s.X
					+ math.abs(f.UpVector.Y) * s.Y
					+ math.abs(f.LookVector.Y) * s.Z
				)
			local floor = workspace:Raycast(
				root.Position,
				Vector3.new(0, -(below + 0.15), 0),
				surfaceParams(root)
			)
			if floor then
				Blood.splat(
					floor.Position,
					floor.Normal,
					math.clamp(s.Magnitude * 0.25, 0.12, 0.6),
					velocity,
					floor.Instance :: BasePart
				)
			end
		end
		shape(soft)
		index += 1
	end
end
RunService.Heartbeat:Connect(update)

------------------------------------------------------------------------------
-- Surface detail
------------------------------------------------------------------------------

type Look = {
	blotches: { Color3 },
	vessel: Color3?,
	shine: number,
}
local LOOKS: { [string]: Look } = {
	Liver = {
		blotches = {
			Color3.fromRGB(70, 16, 14),
			Color3.fromRGB(128, 44, 36),
			Color3.fromRGB(58, 12, 12),
		},
		vessel = Color3.fromRGB(48, 8, 16),
		shine = 0.2,
	},
	Brain = {
		blotches = {
			Color3.fromRGB(176, 112, 110),
			Color3.fromRGB(150, 70, 72),
			Color3.fromRGB(212, 158, 150),
		},
		vessel = Color3.fromRGB(120, 18, 24),
		shine = 0.16,
	},
	Flesh = {
		blotches = {
			Color3.fromRGB(96, 18, 20),
			Color3.fromRGB(150, 44, 44),
			Color3.fromRGB(220, 200, 180),
		},
		vessel = nil,
		shine = 0.14,
	},
}

local onlyIt = RaycastParams.new()
onlyIt.FilterType = Enum.RaycastFilterType.Include

-- A point on `part`'s surface: a ray at it (its collision shape; CanQuery
-- turned on just for this).
local function hitOn(part: BasePart, from: Vector3, toward: Vector3): RaycastResult?
	onlyIt.FilterDescendantsInstances = { part }
	local wasQuery = part.CanQuery
	part.CanQuery = true
	local hit = workspace:Raycast(from, toward, onlyIt)
	part.CanQuery = wasQuery
	return if hit and hit.Instance == part then hit else nil
end

local function surfacePoints(part: BasePart, count: number): { RaycastResult }
	local found: { RaycastResult } = {}
	local reach = part.Size.Magnitude
	for _ = 1, count * 3 do
		if #found >= count then
			break
		end
		local from = part.Position + random:NextUnitVector() * reach
		local hit = hitOn(part, from, (part.Position - from) * 1.2)
		if hit then
			table.insert(found, hit)
		end
	end
	return found
end

-- Welded on with a Weld (a fixed offset: `soft` squashes it with the rest).
local function stick(piece: BasePart, to: BasePart)
	piece.Anchored = false
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Massless = true
	piece.CastShadow = false
	local weld = Instance.new("Weld")
	weld.Part0 = to
	weld.Part1 = piece
	weld.C0 = to.CFrame:ToObjectSpace(piece.CFrame)
	weld.Parent = piece
	piece.Parent = to
end

-- A flat ellipse (a flattened sphere mesh: a cylinder would stay round).
local function disc(size: Vector3, color: Color3): Part
	local piece = Instance.new("Part")
	piece.Size = size
	piece.Material = Enum.Material.SmoothPlastic
	piece.Color = color
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = piece
	return piece
end

-- Blotches and fine vessels on `part`'s surface, and a wet shine. Call it
-- with the part in the workspace, before `soft`.
function Squish.detail(part: BasePart, kind: string)
	local look = LOOKS[kind]
	if look == nil or part.Parent == nil then
		return
	end
	part.Reflectance = math.max(part.Reflectance, look.shine)
	local size = part.Size.Magnitude
	for _, hit in surfacePoints(part, 10) do
		local d = size * random:NextNumber(0.08, 0.18)
		local blotch = disc(
			Vector3.new(0.008, d, d * random:NextNumber(0.6, 1)),
			look.blotches[random:NextInteger(1, #look.blotches)]
		)
		blotch.Name = "Blotch"
		blotch.Transparency = random:NextNumber(0.35, 0.6)
		blotch.Reflectance = look.shine
		local up = if math.abs(hit.Normal.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
		blotch.CFrame = CFrame.fromMatrix(
			hit.Position + hit.Normal * 0.004,
			hit.Normal,
			hit.Normal:Cross(up).Unit
		)
		stick(blotch, part)
	end
	local vessel = look.vessel
	if vessel then
		for _, hit in surfacePoints(part, 6) do
			-- a short wandering vessel: a few thin segments, each put back
			-- on the surface
			local n = hit.Normal
			local up = if math.abs(n.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
			local dir = n:Cross(up).Unit
			local at = hit.Position + n * 0.006
			local width = size * random:NextNumber(0.008, 0.014)
			for _ = 1, 3 do
				local side = n:Cross(dir).Unit
				dir = (dir + side * random:NextNumber(-0.6, 0.6)).Unit
				local length = size * random:NextNumber(0.05, 0.1)
				local guess = at + dir * length
				local landed = hitOn(part, guess + n * 0.3, -n * 0.6)
				if landed == nil then
					break
				end
				local nextAt = landed.Position + landed.Normal * 0.006
				local segment = Instance.new("Part")
				segment.Name = "Vessel"
				segment.Size = Vector3.new(width, width * 0.5, (nextAt - at).Magnitude + width)
				segment.Material = Enum.Material.SmoothPlastic
				segment.Color = vessel
				segment.Transparency = 0.25
				segment.CFrame = CFrame.lookAt((at + nextAt) / 2, nextAt, landed.Normal)
				stick(segment, part)
				at = nextAt
				n = landed.Normal
				dir = dir - n * dir:Dot(n)
				if dir.Magnitude < 1e-3 then
					break
				end
				dir = dir.Unit
			end
		end
	end
end

return table.freeze(Squish)
