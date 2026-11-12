--!strict
-- DevCourse: builds a parkour TEST COURSE next to the spawn, to try the
-- vault, the mantle and the slide without building anything by hand.
--
--   • Only in Roblox Studio (never in the published game), and only if
--     Config.Dev.TEST_COURSE is true.
--   • Built by code when the server starts, inside Workspace > DevTestCourse.
--     Nothing is saved in the place: stop the playtest and it's gone.
--   • No floating labels (only the structures): wall colours still tell
--     what should happen (green = vault, blue = mantle, orange = jump + grab,
--     red = no room on top).
--
-- Layout (seen from above, the spawn is on the left):
--
--   spawn →  [ walls of increasing height ...................... ]   row 1
--            [ thin wall ] [ vault run x4 ] [ no-room block ]        row 2
--            [ slide lane ]                  [ climbing tower ]      row 3

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local CLIMB = Config.Climb

-- Distance from the spawn to the start of the course, and between rows.
local START_DISTANCE = 24
local ROW_SPACING = 26
-- Heights (studs) of the walls of row 1.
local WALL_HEIGHTS = { 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 7, 9 }
local WALL_WIDTH = 8
local WALL_DEPTH = 6
local WALL_SPACING = 12

local COLOR_VAULT = Color3.fromRGB(86, 156, 110)
local COLOR_MANTLE = Color3.fromRGB(84, 122, 178)
local COLOR_JUMP = Color3.fromRGB(190, 140, 70)
local COLOR_BLOCKED = Color3.fromRGB(170, 80, 80)
local COLOR_NEUTRAL = Color3.fromRGB(110, 110, 118)

local DevCourse = {}

-- A solid, anchored block. `base` = center of its BOTTOM face.
local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	base: Vector3,
	color: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = base + Vector3.new(0, size.Y / 2, 0)
	part.Anchored = true
	part.Material = Enum.Material.Concrete
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- The colour of a wall of this height, from the same Config values the real
-- climbing code uses: green = vault, blue = mantle, orange = jump then grab.
local function wallColor(height: number): Color3
	if height <= CLIMB.VAULT_MAX_HEIGHT then
		return COLOR_VAULT
	elseif height <= CLIMB.MAX_HEIGHT then
		return COLOR_MANTLE
	end
	return COLOR_JUMP
end

-- With the city built (Server/Systems/City), the course sits just south of it, outside its
-- walls, on its own floor: the city removes Studio's Baseplate, so there is no ground there.
-- CITY_ORIGIN is the course's first wall; the floor top is at the city's road height (Y 1.2).
-- The city's ground ends at Z = 155 (its invisible wall is at Z = 152.5; the v4 city is wider
-- than v3, whose ground ended at Z = 140). Measured from the origin, the course goes from X -5
-- to +107 and from Z -63 (the last vault rail) to +31 (the towers): the floor below covers all
-- of it, and its north edge (Z 164) stays out of the city.
local CITY_ORIGIN = Vector3.new(-50, 1.2, 230)
local CITY_FLOOR_SIZE = Vector3.new(124, 2, 104)
-- Center of the floor's bottom face, measured from the origin (Y: the floor's top = origin).
local CITY_FLOOR_OFFSET = Vector3.new(52, -CITY_FLOOR_SIZE.Y, -14)

-- Where the course starts: on the ground, next to the first spawn (or south of the city).
local function findOrigin(): Vector3
	if workspace:FindFirstChild("City") then
		return CITY_ORIGIN
	end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local around = if spawn then spawn.Position else Vector3.zero
	local start = around + Vector3.new(START_DISTANCE, 0, 0)
	-- Look for the ground under that point.
	local hit = workspace:Raycast(start + Vector3.new(0, 200, 0), Vector3.new(0, -1000, 0))
	return if hit then hit.Position else start
end

-- The course's own floor (only next to the city): its top is exactly at the origin's height.
local function buildFloor(parent: Instance, origin: Vector3)
	local floor =
		block(parent, "CourseFloor", CITY_FLOOR_SIZE, origin + CITY_FLOOR_OFFSET, COLOR_NEUTRAL)
	floor.Material = Enum.Material.Concrete
end

local function buildWalls(parent: Instance, origin: Vector3)
	for index, height in WALL_HEIGHTS do
		local base = origin + Vector3.new((index - 1) * WALL_SPACING, 0, 0)
		block(
			parent,
			`Wall_{height}`,
			Vector3.new(WALL_WIDTH, height, WALL_DEPTH),
			base,
			wallColor(height)
		)
	end
end

local function buildVaultRow(parent: Instance, origin: Vector3)
	-- A thin wall: you vault over it and land on the other side.
	block(parent, "ThinWall", Vector3.new(10, 3, 0.6), origin, COLOR_VAULT)

	-- Four rails in a line: sprint and vault them one after the other.
	for index = 1, 4 do
		local base = origin + Vector3.new(16, 0, 0) + Vector3.new(0, 0, (index - 1) * -12)
		block(parent, `VaultRail_{index}`, Vector3.new(10, 3, 1), base, COLOR_VAULT)
	end

	-- A block with a ceiling right above it: no room to stand → no climb.
	local blockedBase = origin + Vector3.new(36, 0, 0)
	block(parent, "NoRoomBlock", Vector3.new(8, 4, 6), blockedBase, COLOR_BLOCKED)
	block(
		parent,
		"NoRoomCeiling",
		Vector3.new(8, 1, 6),
		blockedBase + Vector3.new(0, 5.5, 0),
		COLOR_BLOCKED
	)
end

local function buildTowerRow(parent: Instance, origin: Vector3)
	-- A dark strip on the ground: room to sprint and slide.
	local laneBase = origin + Vector3.new(30, 0, 0)
	local lane = block(parent, "SlideLane", Vector3.new(60, 0.2, 10), laneBase, COLOR_NEUTRAL)
	lane.Material = Enum.Material.SmoothPlastic

	-- Steps of 5 studs: chain mantles up to the top.
	local towerBase = origin + Vector3.new(72, 0, 0)
	for level = 1, 4 do
		block(
			parent,
			`Tower_{level}`,
			Vector3.new(10, level * 5, 10),
			towerBase + Vector3.new((level - 1) * 10, 0, 0),
			COLOR_MANTLE
		)
	end
end

function DevCourse.start()
	if not RunService:IsStudio() or not Config.Dev.TEST_COURSE then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "DevTestCourse"

	local origin = findOrigin()
	if workspace:FindFirstChild("City") then
		buildFloor(folder, origin)
	end
	buildWalls(folder, origin)
	buildVaultRow(folder, origin + Vector3.new(0, 0, -ROW_SPACING))
	buildTowerRow(folder, origin + Vector3.new(0, 0, ROW_SPACING))

	-- Parent last: the whole course appears at once.
	folder.Parent = workspace
	print("[DevCourse] Test course built next to the spawn (Studio only).")
end

return DevCourse
