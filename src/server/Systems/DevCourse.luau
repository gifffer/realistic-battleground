--!strict
-- DevCourse: builds a parkour TEST COURSE next to the spawn, to try the
-- vault, the mantle and the slide without building anything by hand.
--
--   • Only in Roblox Studio (never in the published game), and only if
--     Config.Dev.TEST_COURSE is true.
--   • Built by code when the server starts, inside Workspace > DevTestCourse.
--     Nothing is saved in the place: stop the playtest and it's gone.
--   • Every obstacle has a floating label saying what should happen.
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

-- Floating text above a part.
-- Floating label above a test obstacle (same quiet style as the game UI:
-- off-white condensed caps on a dark band, square corners).
local function label(part: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 3, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Adornee = part

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BorderSizePixel = 0
	textLabel.BackgroundColor3 = Color3.fromHex("#0B0B0C")
	textLabel.BackgroundTransparency = 0.45
	textLabel.TextColor3 = Color3.fromHex("#ECE8E1")
	textLabel.FontFace =
		Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Medium)
	textLabel.TextSize = 13
	textLabel.TextWrapped = true
	textLabel.Text = text
	textLabel.Parent = gui

	gui.Parent = part
end

-- What should happen at a wall of this height, from the same Config values
-- the real climbing code uses (so the labels can't lie).
local function describeWall(height: number): (string, Color3)
	if height <= CLIMB.VAULT_MAX_HEIGHT then
		return `{height} studs\nVAULT (Space)`, COLOR_VAULT
	elseif height <= CLIMB.MAX_HEIGHT then
		return `{height} studs\nMANTLE (Space)`, COLOR_MANTLE
	end
	return `{height} studs\nJUMP, then Space in the air`, COLOR_JUMP
end

-- Where the course starts: on the ground, next to the first spawn.
local function findOrigin(): Vector3
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local around = if spawn then spawn.Position else Vector3.zero
	local start = around + Vector3.new(START_DISTANCE, 0, 0)
	-- Look for the ground under that point.
	local hit = workspace:Raycast(start + Vector3.new(0, 200, 0), Vector3.new(0, -1000, 0))
	return if hit then hit.Position else start
end

local function buildWalls(parent: Instance, origin: Vector3)
	for index, height in WALL_HEIGHTS do
		local text, color = describeWall(height)
		local base = origin + Vector3.new((index - 1) * WALL_SPACING, 0, 0)
		local wall =
			block(parent, `Wall_{height}`, Vector3.new(WALL_WIDTH, height, WALL_DEPTH), base, color)
		label(wall, text)
	end
end

local function buildVaultRow(parent: Instance, origin: Vector3)
	-- A thin wall: you vault over it and land on the other side.
	local thin = block(parent, "ThinWall", Vector3.new(10, 3, 0.6), origin, COLOR_VAULT)
	label(thin, "THIN WALL\nVault over it")

	-- Four rails in a line: sprint and vault them one after the other.
	for index = 1, 4 do
		local base = origin + Vector3.new(16, 0, 0) + Vector3.new(0, 0, (index - 1) * -12)
		local rail = block(parent, `VaultRail_{index}`, Vector3.new(10, 3, 1), base, COLOR_VAULT)
		if index == 1 then
			label(rail, "VAULT RUN\nSprint + Space at each rail")
		end
	end

	-- A block with a ceiling right above it: no room to stand → no climb.
	local blockedBase = origin + Vector3.new(36, 0, 0)
	local blocked = block(parent, "NoRoomBlock", Vector3.new(8, 4, 6), blockedBase, COLOR_BLOCKED)
	block(
		parent,
		"NoRoomCeiling",
		Vector3.new(8, 1, 6),
		blockedBase + Vector3.new(0, 5.5, 0),
		COLOR_BLOCKED
	)
	label(blocked, "NO ROOM ON TOP\nShould NOT climb")
end

local function buildTowerRow(parent: Instance, origin: Vector3)
	-- A dark strip on the ground: room to sprint and slide.
	local laneBase = origin + Vector3.new(30, 0, 0)
	local lane = block(parent, "SlideLane", Vector3.new(60, 0.2, 10), laneBase, COLOR_NEUTRAL)
	lane.Material = Enum.Material.SmoothPlastic
	label(lane, "SLIDE LANE\nSprint, then C")

	-- Steps of 5 studs: chain mantles up to the top.
	local towerBase = origin + Vector3.new(72, 0, 0)
	for level = 1, 4 do
		local step = block(
			parent,
			`Tower_{level}`,
			Vector3.new(10, level * 5, 10),
			towerBase + Vector3.new((level - 1) * 10, 0, 0),
			COLOR_MANTLE
		)
		if level == 4 then
			label(step, "TOWER\nMantle step by step to the top")
		end
	end
end

function DevCourse.start()
	if not RunService:IsStudio() or not Config.Dev.TEST_COURSE then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "DevTestCourse"

	local origin = findOrigin()
	buildWalls(folder, origin)
	buildVaultRow(folder, origin + Vector3.new(0, 0, -ROW_SPACING))
	buildTowerRow(folder, origin + Vector3.new(0, 0, ROW_SPACING))

	-- Parent last: the whole course appears at once.
	folder.Parent = workspace
	print("[DevCourse] Test course built next to the spawn (Studio only).")
end

return DevCourse
