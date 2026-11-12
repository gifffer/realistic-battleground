--!strict
-- City: the free arena, a small urban district built by code when the
-- server starts (step 11). Everything is in Workspace > City.
--
-- Layout (seen from above): a 3 × 3 grid of blocks separated by streets.
--   • Streets: asphalt, a dashed centre line, raised sidewalks with kerbs.
--   • Blocks: 2–4 buildings each, with narrow alleys between them.
--   • Climbable routes to some roofs: dumpster (vault) → annex (mantle) →
--     roof (mantle), using the real climbing heights (Config.Climb).
--   • Street furniture: lamp posts (lit at night), neon signs, dumpsters,
--     crates, barriers, puddles (shine when the street is wet at night).
--   • 8 spawn points spread over the streets (Knockout picks the one
--     farthest from the enemies).
--
-- The layout comes from a fixed seed: same city on every server. To keep a
-- hand-made map instead: put a Folder named "City" in Workspace in Studio,
-- and this code builds nothing.
--
-- Lamps, neons and puddles are tagged (CollectionService) "CityLamp",
-- "CityNeon", "CityPuddle": Server/Systems/Ambience turns them on at night.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CLIMB = Config.Climb

local City = {}

-- Sizes in studs.
local BLOCK = 92 -- a block (buildings), square
local STREET = 34 -- street width, kerb to kerb, between two blocks
local SIDEWALK = 7
local GRID = 3 -- blocks per side
local GROUND_Y = 0 -- top of the baseplate

local SEED = 20261112

local COLORS = {
	asphalt = Color3.fromRGB(46, 47, 50),
	line = Color3.fromRGB(196, 186, 150),
	sidewalk = Color3.fromRGB(120, 118, 112),
	kerb = Color3.fromRGB(148, 146, 138),
	walls = {
		Color3.fromRGB(118, 82, 66), -- brick red
		Color3.fromRGB(150, 140, 122), -- sand
		Color3.fromRGB(86, 88, 92), -- grey concrete
		Color3.fromRGB(104, 96, 88), -- brown
		Color3.fromRGB(162, 156, 148), -- light concrete
	},
	roof = Color3.fromRGB(64, 64, 68),
	metal = Color3.fromRGB(58, 62, 58),
	dumpster = Color3.fromRGB(42, 70, 52),
	wood = Color3.fromRGB(126, 98, 66),
	lamp = Color3.fromRGB(255, 196, 120),
	neons = {
		Color3.fromRGB(255, 70, 90),
		Color3.fromRGB(70, 200, 255),
		Color3.fromRGB(255, 170, 60),
		Color3.fromRGB(160, 255, 120),
	},
	puddle = Color3.fromRGB(30, 32, 36),
}

local random = Random.new(SEED)

------------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------------

-- An anchored part. `base` = centre of its BOTTOM face.
local function box(
	parent: Instance,
	name: string,
	size: Vector3,
	base: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = base + Vector3.new(0, size.Y / 2, 0)
	part.Color = color
	part.Material = material or Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Total size of the district (blocks + streets around and between them).
local function districtSize(): number
	return GRID * BLOCK + (GRID + 1) * STREET
end

-- Centre (on the ground) of block (i, j), 1-based.
local function blockCenter(i: number, j: number): Vector3
	local half = districtSize() / 2
	local x = -half + STREET + (i - 1) * (BLOCK + STREET) + BLOCK / 2
	local z = -half + STREET + (j - 1) * (BLOCK + STREET) + BLOCK / 2
	return Vector3.new(x, GROUND_Y, z)
end

------------------------------------------------------------------------------
-- Streets
------------------------------------------------------------------------------

local function buildStreets(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Streets"
	folder.Parent = parent
	local size = districtSize()
	-- One asphalt slab under everything (the streets are what shows).
	box(
		folder,
		"Asphalt",
		Vector3.new(size, 0.2, size),
		Vector3.new(0, GROUND_Y, 0),
		COLORS.asphalt,
		Enum.Material.Asphalt
	)
	-- Dashed centre lines along every street.
	local half = size / 2
	for k = 0, GRID do
		local offset = -half + STREET / 2 + k * (BLOCK + STREET)
		for t = -half + 6, half - 6, 14 do
			box(
				folder,
				"Line",
				Vector3.new(7, 0.05, 0.4),
				Vector3.new(t, GROUND_Y + 0.2, offset),
				COLORS.line,
				Enum.Material.SmoothPlastic
			)
			box(
				folder,
				"Line",
				Vector3.new(0.4, 0.05, 7),
				Vector3.new(offset, GROUND_Y + 0.2, t),
				COLORS.line,
				Enum.Material.SmoothPlastic
			)
		end
	end
end

------------------------------------------------------------------------------
-- Props
------------------------------------------------------------------------------

local function lampPost(parent: Instance, base: Vector3, facing: Vector3)
	box(parent, "LampPole", Vector3.new(0.6, 14, 0.6), base, COLORS.metal, Enum.Material.Metal)
	local arm = box(
		parent,
		"LampArm",
		Vector3.new(0.4, 0.4, 3),
		base + Vector3.new(0, 13.6, 0),
		COLORS.metal,
		Enum.Material.Metal
	)
	arm.CFrame = CFrame.lookAt(arm.Position, arm.Position + facing) * CFrame.new(0, 0, -1.3)
	local head = box(
		parent,
		"LampHead",
		Vector3.new(1.4, 0.5, 1.4),
		Vector3.zero,
		COLORS.lamp,
		Enum.Material.Neon
	)
	head.CFrame = arm.CFrame * CFrame.new(0, -0.4, -1.5)
	local light = Instance.new("SpotLight")
	light.Name = "Light"
	light.Face = Enum.NormalId.Bottom
	light.Angle = 110
	light.Range = 34
	light.Brightness = 0 -- the Ambience turns it on at night
	light.Color = COLORS.lamp
	light.Shadows = true
	light.Parent = head
	CollectionService:AddTag(head, "CityLamp")
end

local function neonSign(parent: Instance, wall: Part, side: Vector3)
	local color = COLORS.neons[random:NextInteger(1, #COLORS.neons)]
	local width = random:NextNumber(4, 8)
	local sign = box(
		parent,
		"NeonSign",
		Vector3.new(width, 1.6, 0.3),
		Vector3.zero,
		color,
		Enum.Material.Neon
	)
	local height = random:NextNumber(7, math.min(wall.Size.Y - 2, 14))
	local position = wall.Position
		+ side * ((math.abs(side.X) * wall.Size.X + math.abs(side.Z) * wall.Size.Z) / 2 + 0.2)
		+ Vector3.new(0, height - wall.Size.Y / 2, 0)
	sign.CFrame = CFrame.lookAt(position, position + side)
	sign.Transparency = 0.4 -- dim by day
	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Range = 14
	light.Brightness = 0
	light.Color = color
	light.Parent = sign
	CollectionService:AddTag(sign, "CityNeon")
end

local function dumpster(parent: Instance, base: Vector3, yaw: number): Part
	-- 3.4 studs high: vaultable (Config.Climb.VAULT_MAX_HEIGHT).
	local height = math.min(3.4, CLIMB.VAULT_MAX_HEIGHT - 0.1)
	local body = box(
		parent,
		"Dumpster",
		Vector3.new(6, height, 3.6),
		base,
		COLORS.dumpster,
		Enum.Material.Metal
	)
	body.CFrame = CFrame.new(body.Position) * CFrame.Angles(0, yaw, 0)
	return body
end

local function crates(parent: Instance, base: Vector3)
	local count = random:NextInteger(1, 3)
	for index = 1, count do
		local size = 3
		local crate = box(
			parent,
			"Crate",
			Vector3.new(size, size, size),
			base + Vector3.new((index - 1) * 3.1, 0, 0),
			COLORS.wood,
			Enum.Material.WoodPlanks
		)
		crate.CFrame = crate.CFrame * CFrame.Angles(0, random:NextNumber(-0.3, 0.3), 0)
	end
	-- Sometimes a second layer: 6 studs, a mantle onto it.
	if count >= 2 and random:NextNumber() < 0.5 then
		box(
			parent,
			"Crate",
			Vector3.new(3, 3, 3),
			base + Vector3.new(1.5, 3, 0),
			COLORS.wood,
			Enum.Material.WoodPlanks
		)
	end
end

local function puddle(parent: Instance, base: Vector3)
	local size = random:NextNumber(4, 10)
	local water = box(
		parent,
		"Puddle",
		Vector3.new(size, 0.05, size * random:NextNumber(0.5, 0.9)),
		base + Vector3.new(0, 0.21, 0),
		COLORS.puddle,
		Enum.Material.Glass
	)
	water.CanCollide = false
	water.Transparency = 1 -- dry by day (the Ambience shows them at night)
	water.CFrame = water.CFrame * CFrame.Angles(0, random:NextNumber(0, math.pi), 0)
	CollectionService:AddTag(water, "CityPuddle")
end

------------------------------------------------------------------------------
-- Blocks
------------------------------------------------------------------------------

-- A climbable corner: dumpster (vault) → annex (mantle) → roof (mantle).
local function climbRoute(parent: Instance, building: Part, side: Vector3)
	local roofTop = building.Size.Y
	-- Each step must be within the mantle reach.
	local step = CLIMB.MAX_HEIGHT - 0.6
	local annexHeight = roofTop - step
	if annexHeight < 3.4 + 0.5 or annexHeight - 3.4 > step then
		return -- the building is too tall or too short for this route
	end
	local halfDepth = (math.abs(side.X) * building.Size.X + math.abs(side.Z) * building.Size.Z) / 2
	local along = Vector3.new(side.Z, 0, -side.X) -- along the wall
	local floorY = building.Position.Y - building.Size.Y / 2
	local wallBase = Vector3.new(building.Position.X, floorY, building.Position.Z)
		+ side * halfDepth
	-- Against the wall, on the sidewalk: the annex, and the dumpster right
	-- next to it (vault onto the dumpster, mantle onto the annex, mantle
	-- onto the roof).
	box(
		parent,
		"Annex",
		Vector3.new(5, annexHeight, 5),
		wallBase + side * 2.5 + along * 8,
		COLORS.walls[1],
		Enum.Material.Brick
	)
	local yaw = if math.abs(side.X) > 0.5 then math.pi / 2 else 0
	dumpster(parent, wallBase + side * 1.8 + along * 13.6, yaw)
end

local function buildBlock(parent: Instance, i: number, j: number)
	local folder = Instance.new("Folder")
	folder.Name = `Block_{i}_{j}`
	folder.Parent = parent
	local center = blockCenter(i, j)
	-- Sidewalk around the block (raised, with a kerb).
	box(
		folder,
		"Sidewalk",
		Vector3.new(BLOCK + SIDEWALK * 2, 0.6, BLOCK + SIDEWALK * 2),
		center - Vector3.new(0, 0, 0),
		COLORS.sidewalk,
		Enum.Material.Concrete
	)
	local inner = BLOCK - 4

	-- The middle block is a small square (open space to fight in).
	if i == 2 and j == 2 then
		box(
			folder,
			"Square",
			Vector3.new(inner, 0.2, inner),
			center + Vector3.new(0, 0.6, 0),
			Color3.fromRGB(110, 104, 96),
			Enum.Material.Cobblestone
		)
		for corner = 0, 3 do
			local angle = corner * math.pi / 2 + math.pi / 4
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (inner * 0.32)
			box(
				folder,
				"Planter",
				Vector3.new(6, 2.6, 6),
				center + offset + Vector3.new(0, 0.6, 0),
				Color3.fromRGB(90, 88, 84)
			)
		end
		crates(folder, center + Vector3.new(-6, 0.8, 14))
		puddle(folder, center + Vector3.new(10, 0.6, -8))
		return
	end

	-- Two rows of buildings with an alley between (alley along X or Z).
	local alongX = (i + j) % 2 == 0
	local alley = 8
	local half = inner / 2
	for row = -1, 1, 2 do
		local count = random:NextInteger(1, 2)
		local length = inner / count
		for k = 1, count do
			local height = random:NextInteger(3, 7) * 4 + 0.6 -- 12.6 to 28.6
			local depth = half - alley / 2
			local start = -half + (k - 1) * length
			local size = if alongX
				then Vector3.new(length - 2, height, depth)
				else Vector3.new(depth, height, length - 2)
			local offset = if alongX
				then Vector3.new(start + length / 2, 0, row * (alley / 2 + depth / 2))
				else Vector3.new(row * (alley / 2 + depth / 2), 0, start + length / 2)
			local color = COLORS.walls[random:NextInteger(1, #COLORS.walls)]
			local building = box(
				folder,
				"Building",
				size,
				center + offset + Vector3.new(0, 0.6, 0),
				color,
				Enum.Material.Brick
			)
			box(
				folder,
				"Roof",
				Vector3.new(size.X, 0.4, size.Z),
				building.Position + Vector3.new(0, size.Y / 2, 0),
				COLORS.roof
			)
			-- The street side of this building.
			local street = if alongX then Vector3.new(0, 0, row) else Vector3.new(row, 0, 0)
			if random:NextNumber() < 0.6 then
				neonSign(folder, building, street)
			end
			if random:NextNumber() < 0.6 then
				climbRoute(folder, building, street) -- on the street side
			end
		end
	end
	-- Alley clutter.
	local alleyAxis = if alongX then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	dumpster(
		folder,
		center + alleyAxis * random:NextNumber(-20, 20) + Vector3.new(0, 0.6, 0),
		if alongX then 0 else math.pi / 2
	)
	crates(folder, center + alleyAxis * random:NextNumber(-30, 30) + Vector3.new(0, 0.6, 0))
	puddle(folder, center + alleyAxis * random:NextNumber(-25, 25) + Vector3.new(0, 0.6, 0))
end

------------------------------------------------------------------------------
-- Lamps, spawns, street props
------------------------------------------------------------------------------

local function buildStreetProps(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "StreetProps"
	folder.Parent = parent
	local half = districtSize() / 2
	-- Lamp posts along each street, on the sidewalk edge, both sides.
	for k = 0, GRID do
		local offset = -half + STREET / 2 + k * (BLOCK + STREET)
		for t = -half + 20, half - 20, 36 do
			-- Not in the middle of a crossing street.
			local inStreet = false
			for m = 0, GRID do
				local streetCenter = -half + STREET / 2 + m * (BLOCK + STREET)
				if math.abs(t - streetCenter) < STREET / 2 + 2 then
					inStreet = true
				end
			end
			if inStreet then
				continue
			end
			local side = STREET / 2 + 1
			lampPost(folder, Vector3.new(t, GROUND_Y + 0.6, offset - side), Vector3.new(0, 0, 1))
			lampPost(folder, Vector3.new(offset + side, GROUND_Y + 0.6, t), Vector3.new(-1, 0, 0))
			if random:NextNumber() < 0.35 then
				puddle(
					folder,
					Vector3.new(
						t + random:NextNumber(-10, 10),
						GROUND_Y,
						offset + random:NextNumber(-8, 8)
					)
				)
			end
		end
	end
	-- Concrete barriers here and there in the streets (cover, vault).
	for _ = 1, 10 do
		local k = random:NextInteger(0, GRID)
		local offset = -half + STREET / 2 + k * (BLOCK + STREET)
		local t = random:NextNumber(-half + 30, half - 30)
		local onX = random:NextNumber() < 0.5
		local base = if onX
			then Vector3.new(t, GROUND_Y, offset)
			else Vector3.new(offset, GROUND_Y, t)
		local barrier =
			box(folder, "Barrier", Vector3.new(8, 2.8, 1.6), base, Color3.fromRGB(170, 166, 156))
		barrier.CFrame = CFrame.new(barrier.Position)
			* CFrame.Angles(0, if onX then 0 else math.pi / 2, 0)
	end
end

local function buildSpawns(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Spawns"
	folder.Parent = parent
	local half = districtSize() / 2
	-- 8 spawns spread over the street crossings and middles.
	local spots = {}
	for _, k in { 0, GRID } do
		for _, t in { -0.5, 0.5 } do
			local offset = -half + STREET / 2 + k * (BLOCK + STREET)
			table.insert(spots, Vector3.new(t * half, GROUND_Y + 0.2, offset))
			table.insert(spots, Vector3.new(offset, GROUND_Y + 0.2, t * half))
		end
	end
	for index, spot in spots do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = `Spawn{index}`
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 0.2, 6)
		spawn.Position = spot + Vector3.new(0, 0.1, 0)
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Duration = 0 -- our own spawn protection (Knockout) is used
		spawn.Neutral = true
		local decal = spawn:FindFirstChildOfClass("Decal")
		if decal then
			decal:Destroy()
		end
		spawn.Parent = folder
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function City.init()
	if workspace:FindFirstChild("City") then
		return -- a hand-made map is in the place: keep it
	end
	local city = Instance.new("Folder")
	city.Name = "City"
	buildStreets(city)
	for i = 1, GRID do
		for j = 1, GRID do
			buildBlock(city, i, j)
		end
	end
	buildStreetProps(city)
	buildSpawns(city)
	city.Parent = workspace
	-- The place's own spawn (Roblox's default one) is no longer needed.
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child.Enabled = false
		end
	end
end

return City
