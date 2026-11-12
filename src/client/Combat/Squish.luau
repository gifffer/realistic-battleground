--!strict
-- Squish: makes a flying piece of body (an organ, brain, flesh) SOFT and
-- WET instead of a hard plastic block.
--
-- What makes something look soft, and how it is done (Roblox has no soft
-- bodies, so the look is faked on the piece's parts):
--   • it doesn't bounce or tumble like a stone: no elasticity, a lot of
--     friction, and once down its spin dies fast (it slumps and stays);
--   • on every impact it SQUASHES flat along the hit then wobbles back
--     (a damped spring), keeping its volume (flatter = wider), and stays a
--     little flattened once at rest (it sags under its own weight);
--   • it jiggles a little while it flies (it's not rigid);
--   • it's wet: shiny, it splats blood where it lands and leaves a smear
--     when it slides;
--   • its surface isn't one flat colour: darker / lighter blotches and fine
--     vessels (`detail`).
--
--   Squish.soft(part, options)   `part`: the piece (its welded children
--                                 squash with it)
--   Squish.detail(part, kind)    surface blotches and vessels ("Liver",
--                                 "Brain", "Flesh")

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

type Member = { part: BasePart, size: Vector3, weld: Weld?, c0: CFrame? }
type Soft = {
	root: BasePart,
	members: { Member },
	normal: Vector3, -- the squash axis (world)
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
}

local softs: { Soft } = {}
local random = Random.new()

-- No bounce, lots of friction, light enough to tumble, heavy enough to
-- plop (the weights make 0 elasticity / high friction win against the
-- floor's values).
local SOFT_PHYSICS = PhysicalProperties.new(1.05, 1.6, 0, 3, 100)

function Squish.soft(part: BasePart, options: Options?)
	local o: Options = options or {}
	local members: { Member } = { { part = part, size = part.Size } }
	part.CustomPhysicalProperties = SOFT_PHYSICS
	for _, child in part:GetDescendants() do
		if child:IsA("BasePart") then
			child.CustomPhysicalProperties = SOFT_PHYSICS
			local weld: Weld? = nil
			for _, joint in child:GetChildren() do
				if joint:IsA("Weld") and joint.Part0 == part and joint.Part1 == child then
					weld = joint
				end
			end
			table.insert(
				members,
				{ part = child, size = child.Size, weld = weld, c0 = if weld then weld.C0 else nil }
			)
		end
	end
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
	})
end

-- The scale of a box axis `axis` (world) when squashing along `normal` by
-- `along` and `across` the other way.
local function axisScale(axis: Vector3, normal: Vector3, along: number, across: number): number
	local c = axis:Dot(normal)
	local c2 = c * c
	return math.sqrt(c2 * along * along + (1 - c2) * across * across)
end

local function shape(soft: Soft)
	local along = math.clamp(1 + soft.offset - soft.sagNow, 0.45, 1.6)
	local across = 1 / math.sqrt(along) -- (volume kept)
	local n = soft.normal
	local root = soft.root
	for _, member in soft.members do
		local p = member.part
		local frame = p.CFrame
		p.Size = Vector3.new(
			member.size.X * axisScale(frame.RightVector, n, along, across),
			member.size.Y * axisScale(frame.UpVector, n, along, across),
			member.size.Z * axisScale(frame.LookVector, n, along, across)
		)
		local weld, c0 = member.weld, member.c0
		if weld and c0 and weld.Parent then
			-- the child's offset squashed with the rest
			local world = root.CFrame:VectorToWorldSpace(c0.Position)
			local alongPart = n * world:Dot(n)
			local moved = alongPart * along + (world - alongPart) * across
			weld.C0 = CFrame.new(root.CFrame:VectorToObjectSpace(moved)) * c0.Rotation
		end
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
-- (through the piece itself)
local function surfaceParams(root: BasePart): RaycastParams
	rayParams.FilterDescendantsInstances = { root }
	return rayParams
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
		local change = velocity - soft.lastVelocity
		soft.lastVelocity = velocity
		-- An impact: the speed changed hard in one frame (not gravity).
		local kick = change.Magnitude - workspace.Gravity * dt * 1.5
		if kick > 5 and not root.Anchored then
			local normal = change.Unit
			soft.normal = normal
			local amount = math.clamp(kick / 45, 0.08, 1) * soft.softness
			soft.offset = -amount
			soft.speed = 0
			-- it slumps a bit more each time it lands, up to its sag
			soft.sagNow = math.min(soft.sag, soft.sagNow + soft.sag * 0.6)
			-- wet slap: blood under it
			-- (only against a surface: not a jolt in someone's hand)
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
					velocity * 0.3,
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
		-- (a little jiggle while flying fast)
		local speed = velocity.Magnitude
		if speed > 8 and math.abs(soft.offset) < 0.02 then
			soft.speed += random:NextNumber(-1, 1) * speed * 0.02
		end
		-- the damped spring
		local damping = 2 * math.sqrt(soft.stiffness) * 0.32
		soft.speed += (-soft.stiffness * soft.offset - damping * soft.speed) * dt
		soft.offset += soft.speed * dt
		-- resting on the floor: it sags along gravity, spin dies
		if speed < 1.2 then
			soft.still += dt
			if soft.still > 0.15 then
				soft.normal = soft.normal:Lerp(Vector3.yAxis, math.min(1, dt * 3)).Unit
				root.AssemblyAngularVelocity *= math.max(0, 1 - dt * 6)
			end
		else
			soft.still = 0
		end
		-- sliding on the floor: a smear of blood behind it
		if
			soft.bleeds
			and speed > 2.5
			and speed < 25
			and soft.still == 0
			and now - soft.lastSmear > 0.07
		then
			local floor = workspace:Raycast(
				root.Position,
				Vector3.new(0, -(root.Size.Magnitude * 0.6 + 0.4), 0),
				surfaceParams(root)
			)
			if floor then
				soft.lastSmear = now
				Blood.splat(
					floor.Position,
					floor.Normal,
					math.clamp(root.Size.Magnitude * 0.25, 0.12, 0.6),
					velocity,
					nil
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

-- Points on `part`'s real surface (rays shot at it from around).
local function surfacePoints(part: BasePart, count: number): { RaycastResult }
	local onlyIt = RaycastParams.new()
	onlyIt.FilterType = Enum.RaycastFilterType.Include
	onlyIt.FilterDescendantsInstances = { part }
	local wasQuery = part.CanQuery
	part.CanQuery = true
	local found: { RaycastResult } = {}
	local reach = part.Size.Magnitude
	for _ = 1, count * 3 do
		if #found >= count then
			break
		end
		local from = part.Position + random:NextUnitVector() * reach
		local hit = workspace:Raycast(from, (part.Position - from) * 1.2, onlyIt)
		if hit and hit.Instance == part then
			table.insert(found, hit)
		end
	end
	part.CanQuery = wasQuery
	return found
end

local function stick(piece: BasePart, to: BasePart)
	piece.Anchored = false
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Massless = true
	piece.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = to
end

-- Blotches and fine vessels on `part`'s surface, and a wet shine.
function Squish.detail(part: BasePart, kind: string)
	local look = LOOKS[kind]
	if look == nil then
		return
	end
	part.Reflectance = math.max(part.Reflectance, look.shine)
	local size = part.Size.Magnitude
	for _, hit in surfacePoints(part, 10) do
		local d = size * random:NextNumber(0.08, 0.18)
		local blotch = Instance.new("Part")
		blotch.Name = "Blotch"
		blotch.Shape = Enum.PartType.Cylinder
		blotch.Size = Vector3.new(0.008, d, d * random:NextNumber(0.6, 1))
		blotch.Material = Enum.Material.SmoothPlastic
		blotch.Color = look.blotches[random:NextInteger(1, #look.blotches)]
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
			-- a short wandering vessel: a few thin segments along the surface
			local up = if math.abs(hit.Normal.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
			local dir = hit.Normal:Cross(up).Unit
			local at = hit.Position + hit.Normal * 0.006
			local width = size * random:NextNumber(0.008, 0.014)
			for _ = 1, 3 do
				local side = hit.Normal:Cross(dir).Unit
				dir = (dir + side * random:NextNumber(-0.6, 0.6)).Unit
				local length = size * random:NextNumber(0.05, 0.1)
				local nextAt = at + dir * length
				local segment = Instance.new("Part")
				segment.Name = "Vessel"
				segment.Size = Vector3.new(width, width * 0.5, length + width)
				segment.Material = Enum.Material.SmoothPlastic
				segment.Color = vessel
				segment.Transparency = 0.25
				segment.CFrame = CFrame.lookAt((at + nextAt) / 2, nextAt, hit.Normal)
				stick(segment, part)
				at = nextAt
			end
		end
	end
end

return table.freeze(Squish)
