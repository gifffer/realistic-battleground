--!strict
-- Arenas: the duel rooms, built by code when the server starts (there is no
-- final map yet). Far from the free arena, so nobody walks in.
--
-- Each arena: a concrete floor, four walls (nobody falls out), soft light,
-- two spawn points facing each other ("SpawnA", "SpawnB" CFrames).
-- To use your own builds later: put Models named DuelArena1..N in
-- Workspace > DuelArenas, each with two Parts named SpawnA and SpawnB; the
-- code uses them instead of building its own.
--
--   Arenas.build()            once, at start
--   Arenas.claim()  → arena?  a free arena (nil if all busy)
--   Arenas.release(arena)

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type Arena = {
	index: number,
	spawnA: CFrame,
	spawnB: CFrame,
	busy: boolean,
}

local Arenas = {}

local FLOOR = Vector3.new(70, 1, 70)
local WALL_HEIGHT = 16
local SPACING = 160
-- Far from the free arena (and from each other).
local ORIGIN = Vector3.new(3000, 200, 3000)
local SPAWN_GAP = 24 -- studs between the two fighters at the start

local arenas: { Arena } = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildOne(folder: Instance, index: number): Arena
	local model = Instance.new("Model")
	model.Name = `DuelArena{index}`
	model:SetAttribute("Unbreakable", true) -- (heavy moves don't smash its walls)
	local center = ORIGIN + Vector3.new((index - 1) * SPACING, 0, 0)
	local floorColor = Color3.fromRGB(92, 92, 96)
	local wallColor = Color3.fromRGB(58, 58, 62)
	local floor = part(model, "Floor", FLOOR, CFrame.new(center), floorColor)
	floor.Material = Enum.Material.Asphalt
	local half = FLOOR.X / 2
	local y = center.Y + WALL_HEIGHT / 2
	part(
		model,
		"WallN",
		Vector3.new(FLOOR.X, WALL_HEIGHT, 1),
		CFrame.new(center.X, y, center.Z - half),
		wallColor
	)
	part(
		model,
		"WallS",
		Vector3.new(FLOOR.X, WALL_HEIGHT, 1),
		CFrame.new(center.X, y, center.Z + half),
		wallColor
	)
	part(
		model,
		"WallE",
		Vector3.new(1, WALL_HEIGHT, FLOOR.Z),
		CFrame.new(center.X + half, y, center.Z),
		wallColor
	)
	part(
		model,
		"WallW",
		Vector3.new(1, WALL_HEIGHT, FLOOR.Z),
		CFrame.new(center.X - half, y, center.Z),
		wallColor
	)
	-- A dim lamp above the middle (street-fight mood).
	local lampHolder = part(
		model,
		"Lamp",
		Vector3.new(1, 1, 1),
		CFrame.new(center + Vector3.new(0, 22, 0)),
		wallColor
	)
	lampHolder.Transparency = 1
	lampHolder.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 226, 190)
	light.Parent = lampHolder
	model.Parent = folder

	local standY = center.Y + FLOOR.Y / 2 + 3
	local a = Vector3.new(center.X - SPAWN_GAP / 2, standY, center.Z)
	local b = Vector3.new(center.X + SPAWN_GAP / 2, standY, center.Z)
	return {
		index = index,
		spawnA = CFrame.lookAt(a, b),
		spawnB = CFrame.lookAt(b, a),
		busy = false,
	}
end

-- Uses hand-made arenas from Workspace > DuelArenas if there are any.
local function fromWorkspace(): { Arena }
	local found = {}
	local folder = workspace:FindFirstChild("DuelArenas")
	if folder == nil then
		return found
	end
	for _, model in folder:GetChildren() do
		local a = model:FindFirstChild("SpawnA")
		local b = model:FindFirstChild("SpawnB")
		if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
			table.insert(found, {
				index = #found + 1,
				spawnA = a.CFrame + Vector3.new(0, 3, 0),
				spawnB = b.CFrame + Vector3.new(0, 3, 0),
				busy = false,
			})
		end
	end
	return found
end

function Arenas.build()
	arenas = fromWorkspace()
	if #arenas > 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "DuelArenas"
	for index = 1, Config.Duels.ARENA_COUNT do
		table.insert(arenas, buildOne(folder, index))
	end
	folder.Parent = workspace
end

function Arenas.claim(): Arena?
	for _, arena in arenas do
		if not arena.busy then
			arena.busy = true
			return arena
		end
	end
	return nil
end

function Arenas.release(arena: Arena)
	arena.busy = false
end

return Arenas
