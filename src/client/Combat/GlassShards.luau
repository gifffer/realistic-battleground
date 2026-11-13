--!strict
-- GlassShards: bits of bottle glass stuck in a fighter's skin.
--
-- A bottle bursting on someone leaves a few slivers of glass planted in
-- them, often without a real cut (the server stores them as
-- "Shard_<Part>_<n>" attributes, Shared/Util/Gash). Each one is drawn as a
-- sliver of glass half sunk in the skin, leaning, with a little blood
-- around it and sometimes a thin trickle running down. The rest of the
-- sliver is inside the body part, which hides it. Same look on every
-- client (random details from the shard's seed).
--
--   GlassShards.watch(model)   follow the shards of this fighter

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Gash = require(ReplicatedStorage.Shared.Util.Gash)
local BloodAge = require(script.Parent.BloodAge)

local GlassShards = {}

local GLASS_COLOR = Color3.fromRGB(116, 140, 92) -- the green-brown bottle, thin
local BLOOD_COLOR = Config.Blood.PALETTE.VENOUS
local HEAD_RADIUS = 0.6 -- the classic head (see Gashes)
local LIFT = 0.012 -- blood just over the skin (and over the bruise marks)

local function setUp(piece: BasePart, part: BasePart, parent: Instance)
	piece.Anchored = false
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = parent
end

-- The skin's outward normal at `point` (part space).
local function normalAt(part: BasePart, point: Vector3): Vector3
	if part.Name == "Head" then
		local flat = Vector3.new(point.X, 0, point.Z)
		return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	end
	local half = part.Size / 2
	local best, normal = -math.huge, Vector3.new(0, 0, -1)
	for _, axis in
		{ Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1) }
	do
		local along = point:Dot(axis) / math.abs(axis:Dot(half))
		if along > best then
			best, normal = along, axis
		end
	end
	return normal
end

-- The point moved onto the skin (the server's point may be a hair off).
local function onSkin(part: BasePart, point: Vector3, normal: Vector3): Vector3
	if part.Name == "Head" then
		return Vector3.new(normal.X * HEAD_RADIUS, point.Y, normal.Z * HEAD_RADIUS)
	end
	local depth = math.abs(normal:Dot(part.Size / 2))
	return point - normal * point:Dot(normal) + normal * depth
end

local function drawShard(part: BasePart, shard: Gash.Shard, parent: Instance)
	local random = Random.new(shard.seed)
	local normal = normalAt(part, shard.point)
	local at = onSkin(part, shard.point, normal)
	local up = Vector3.new(0, 1, 0)
	local side = up:Cross(normal).Unit
	-- The skin's own frame here: X along it, Y up, Z out.
	local skin = CFrame.fromMatrix(at, side, up, normal) * CFrame.Angles(0, 0, math.rad(shard.yaw))

	-- 1 or 2 slivers, leaning, half in the skin.
	for index = 1, random:NextInteger(1, 2) do
		local length = random:NextNumber(0.09, 0.16) / index
		local sliver = Instance.new("WedgePart")
		sliver.Name = "GlassShard"
		sliver.Size = Vector3.new(0.012, length, random:NextNumber(0.035, 0.06))
		sliver.Material = Enum.Material.Glass
		sliver.Color = GLASS_COLOR
		sliver.Transparency = 0.35
		sliver.Reflectance = 0.3
		local lean = math.rad(shard.tilt + random:NextNumber(-10, 10))
		-- The wedge's Y (its length) turned from up to out of the skin, then
		-- leaning by `lean`; 45 % of it is under the skin.
		local offset =
			Vector3.new(random:NextNumber(-0.02, 0.02), random:NextNumber(-0.02, 0.02), 0)
		sliver.CFrame = part.CFrame
			* skin
			* CFrame.new(offset)
			* CFrame.Angles(math.rad(90) - lean, random:NextNumber(0, math.pi), 0)
			* CFrame.new(0, length * 0.05, 0)
		setUp(sliver, part, parent)
	end

	-- Blood where the glass went in.
	local dot = Instance.new("Part")
	dot.Name = "ShardBlood"
	local size = random:NextNumber(0.05, 0.09)
	-- (a small uneven bead: a flattened sphere, a little oval)
	dot.Size = Vector3.new(0.01, size, size * random:NextNumber(1, 1.35))
	local bead = Instance.new("SpecialMesh")
	bead.MeshType = Enum.MeshType.Sphere
	bead.Parent = dot
	dot.Material = Enum.Material.SmoothPlastic
	dot.Color = BLOOD_COLOR
	dot.Reflectance = 0.25
	-- (its thin X axis points out of the skin)
	dot.CFrame = part.CFrame * CFrame.fromMatrix(at + normal * LIFT, normal, up)
	setUp(dot, part, parent)
	BloodAge.track(dot, "wound", Config.Blood.PALETTE.ARTERIAL) -- (it darkens, dulls)

	-- Sometimes a thin trickle running down the skin.
	if random:NextNumber() < 0.6 then
		local length = random:NextNumber(0.06, 0.16)
		local trickle = Instance.new("Part")
		trickle.Name = "ShardBlood"
		trickle.Size = Vector3.new(random:NextNumber(0.012, 0.02), length, 0.008)
		trickle.Material = Enum.Material.SmoothPlastic
		trickle.Color = BLOOD_COLOR
		trickle.Reflectance = 0.25
		-- (a thin run, tapered at both ends: a stretched sphere)
		local spindle = Instance.new("SpecialMesh")
		spindle.MeshType = Enum.MeshType.Sphere
		spindle.Parent = trickle
		local start = at + normal * LIFT + Vector3.new(0, -length / 2, 0)
		trickle.CFrame = part.CFrame * CFrame.fromMatrix(start, side, up)
		setUp(trickle, part, parent)
		BloodAge.track(trickle, "wound", Config.Blood.PALETTE.VENOUS)
	end
end

local function refresh(model: Model, partName: string)
	local key = Gash.KEY_OF[partName]
	local part = model:FindFirstChild(partName)
	if key == nil or part == nil or not part:IsA("BasePart") then
		return
	end
	local old = part:FindFirstChild("GlassShards")
	if old then
		old:Destroy() -- rebuilt from scratch: only when a shard comes or goes
	end
	local shards: { Gash.Shard } = {}
	for index = 1, Gash.MAX_SHARDS_PER_PART do
		local shard = Gash.decodeShard(model:GetAttribute(Gash.shardAttribute(key, index)))
		if shard then
			table.insert(shards, shard)
		end
	end
	if #shards == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "GlassShards"
	for _, shard in shards do
		drawShard(part, shard, folder)
	end
	folder.Parent = part
end

function GlassShards.watch(model: Model)
	model.AttributeChanged:Connect(function(name: string)
		local key = string.match(name, "^" .. Gash.SHARD_PREFIX .. "(%a+)_%d+$")
		local partName = if key then Gash.PART_OF[key] else nil
		if partName then
			refresh(model, partName)
		end
	end)
	for partName in Gash.KEY_OF do
		refresh(model, partName)
	end
end

return table.freeze(GlassShards)
