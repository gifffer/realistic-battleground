--!strict
-- Things picked up in the world and THROWN (one use). Held in the right hand
-- ("Weapon" attribute); a left click throws it instead of punching. It flies
-- in an arc (the server simulates it: what it hits counts) and lands on
-- whatever it hits first: someone, a wall, the floor. Dropped at your feet
-- when you are knocked out or die.
--
--   "Bone"     the upper arm bone, pulled out of an arm the Bouncer tore off
--              (Shared/Finishers "ArmRip"). Snaps in two.
--   "IronBar"  a length of rusty pipe lying in an alley. Heavy: hits hard,
--              knocks back further. Doesn't break: it clangs off and lies
--              there a few seconds.
--   "Plank"    a worn board with a bent nail through one end. Cracks in two.
--
-- The two from the street lie at the edges of the map and in the alleys
-- (Server/Systems/Pickups, "WeaponSpawn" markers); the bone only comes from
-- a torn arm (Server/Combat).
--
-- Read by the server (Combat: the throw, the hit; Pickups: the ones lying
-- in the street) and the clients (in the hand, in the air, where it lands).

-- "Whole"; once broken: "A" the end that was in the fist, "B" the other.
export type Piece = "Whole" | "A" | "B"

export type WeaponDef = {
	id: string,
	name: string, -- shown on the pickup prompt (English)
	damage: number, -- a direct hit
	stun: number, -- seconds, on a direct hit
	knockback: number, -- studs/s, a direct hit pushes them back
	speed: number, -- studs/s when it leaves the hand
	lift: number, -- studs/s up added to the aim (an arc)
	gravity: number, -- studs/s² pulling it down in flight
	release: number, -- seconds into the throw clip when it leaves the hand
	recovery: number, -- seconds before he can attack again
	lifetime: number, -- seconds in the air at most (then it comes down there)
	clip: string, -- the throw clip (CombatClips)
	moveId: string, -- the hit's move id (hit reaction, sound, blood on the face)
	breaks: boolean, -- breaks where it lands (else it lies there a while)
	-- Glass: cuts the skin where it hits (Server/Combat resolveHit), and
	-- how long the cut bleeds.
	cuts: ("Lac" | "Slash")?,
	bleed: { perSecond: number, duration: number }?,
	hitSound: string?, -- Shared/Sounds, when it hits someone (nil = "Hit")
	breakSound: string?, -- Shared/Sounds, where it lands (anyone, a wall, the floor)
	length: number, -- studs, end to end
	grip: number, -- studs from the fist to its middle (it carries on forward)
	-- Chance (0-1) a hit draws visible blood, per zone.
	bloodChance: { [string]: number },
	-- Builds it from plain parts (nil = the client draws it itself: the
	-- bone, from the WoundKit). See Weapons.build.
	build: ((piece: Piece) -> BasePart)?,
}

local Weapons = {}

------------------------------------------------------------------------------
-- Models (plain parts, built the same on the server and every client)
------------------------------------------------------------------------------
-- Weapon space: its middle at the origin, its length along Y, the end held
-- in the fist down -Y. The root is a tiny invisible part right there (the
-- model's pivot); the parts you see are its children, welded to it (moving
-- the root moves them all). Nothing collides or can be hit: whoever uses it
-- sets what it needs.

local RUST = Color3.fromRGB(92, 50, 32)
local RUST_DARK = Color3.fromRGB(62, 38, 28)
local RUST_ORANGE = Color3.fromRGB(128, 66, 34)
local STEEL_DIRTY = Color3.fromRGB(70, 66, 62)
local WOOD = Color3.fromRGB(108, 92, 72) -- weathered grey-brown pine
local WOOD_DARK = Color3.fromRGB(74, 60, 46) -- dirt, rot at the ends
local WOOD_FRESH = Color3.fromRGB(176, 146, 104) -- the inside, where it cracks
local NAIL = Color3.fromRGB(64, 52, 44)

local BAR_LENGTH = 3.2 -- about a metre of 1-inch pipe
local PLANK_LENGTH = 3.2 -- about a metre of 2x4

local ALONG_Y = CFrame.Angles(0, 0, math.rad(90)) -- (a cylinder's axis is its X)

local function newPart(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = size.Magnitude > 0.25
	return part
end

local function newWedge(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Size = size
	wedge.Color = color
	wedge.Material = material
	wedge.CanCollide = false
	wedge.CanQuery = false
	wedge.CanTouch = false
	wedge.Massless = true
	wedge.CastShadow = false
	return wedge
end

local function newRoot(name: string): Part
	local root =
		newPart(name, Vector3.new(0.05, 0.05, 0.05), Color3.new(), Enum.Material.SmoothPlastic)
	root.Transparency = 1
	root.CastShadow = false
	root.CFrame = CFrame.new()
	return root
end

-- `part` at `at` (weapon space), welded to the root.
local function attach(root: BasePart, part: BasePart, at: CFrame)
	part.CFrame = root.CFrame * at
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = part
	weld.C0 = at
	weld.Parent = part
	part.Parent = root
end

-- A length of rusty pipe: a threaded coupling still on the far end,
-- flaking rust in bands, the near end a dirty saw cut.
local function buildIronBar(_piece: Piece): BasePart
	local root = newRoot("IronBar")
	local diameter = 0.15
	local function pipe(name: string, length: number, thick: number, color: Color3, y: number)
		local part = newPart(
			name,
			Vector3.new(length, diameter + thick, diameter + thick),
			color,
			Enum.Material.CorrodedMetal,
			Enum.PartType.Cylinder
		)
		attach(root, part, CFrame.new(0, y, 0) * ALONG_Y)
		return part
	end
	pipe("Pipe", BAR_LENGTH, 0, RUST, 0)
	pipe("Coupling", 0.26, 0.06, RUST_DARK, BAR_LENGTH / 2 - 0.13)
	-- (a hair proud of the pipe)
	for index, y in { -0.9, -0.15, 0.55, 1.05 } do
		pipe(
			"Rust",
			0.12 + (index % 2) * 0.14,
			0.012,
			if index % 2 == 0 then RUST_ORANGE else RUST_DARK,
			y
		)
	end
	local cut = pipe("Cut", 0.05, 0.004, STEEL_DIRTY, -BAR_LENGTH / 2 + 0.02)
	cut.Material = Enum.Material.Metal
	return root
end

-- A worn board (a 2x4) with a bent nail through one end. Broken: "A" the
-- end that was held, "B" the end with the nail, each with the raw, pale
-- wood showing where it cracked.
local function buildPlank(piece: Piece): BasePart
	local root = newRoot("Plank")
	local width, thick = 0.32, 0.13
	local from, to = -PLANK_LENGTH / 2, PLANK_LENGTH / 2
	if piece == "A" then
		to = -0.1
	elseif piece == "B" then
		from = -0.1
	end
	local function board(name: string, length: number, y: number, color: Color3)
		local part = newPart(name, Vector3.new(width, length, thick), color, Enum.Material.Wood)
		attach(root, part, CFrame.new(0, y, 0))
		return part
	end
	board("Board", to - from, (from + to) / 2, WOOD)
	-- Dirt and rot at the ends that stood in the wet (a hair bigger).
	if piece ~= "B" then
		local rot = board("Rot", 0.3, from + 0.15, WOOD_DARK)
		rot.Size += Vector3.new(0.01, 0, 0.01)
	end
	if piece ~= "A" then
		local rot = board("Rot", 0.22, to - 0.11, WOOD_DARK)
		rot.Size += Vector3.new(0.01, 0, 0.01)
		-- The nail: through the board near its end, its flat head on the
		-- back, the point out the front and bent over.
		local y = to - 0.3
		local function nail(name: string, length: number, diameter: number, at: CFrame)
			attach(
				root,
				newPart(
					name,
					Vector3.new(length, diameter, diameter),
					NAIL,
					Enum.Material.Metal,
					Enum.PartType.Cylinder
				),
				at
			)
		end
		local across = CFrame.Angles(0, math.rad(90), 0) -- (its axis through the board, Z)
		nail("NailHead", 0.02, 0.07, CFrame.new(0.04, y, thick / 2 + 0.01) * across)
		nail("Nail", 0.3, 0.025, CFrame.new(0.04, y, -thick / 2 - 0.13) * across)
		nail(
			"NailBent",
			0.12,
			0.025,
			CFrame.new(0.08, y + 0.03, -thick / 2 - 0.29) * CFrame.Angles(0, 0, math.rad(35))
		)
	end
	-- Where it cracked: pale wood and a few long splinters sticking out.
	if piece ~= "Whole" then
		local edge = if piece == "A" then to else from
		local out = if piece == "A" then 1 else -1
		local crack = board("Crack", 0.03, edge, WOOD_FRESH)
		crack.Size -= Vector3.new(0.04, 0, 0.02) -- (a hair inside the edges)
		for index, x in { -0.1, 0.04, 0.11 } do
			local splinter = newWedge(
				"Splinter",
				Vector3.new(0.05, 0.14 + index * 0.06, thick * 0.6),
				WOOD_FRESH,
				Enum.Material.Wood
			)
			attach(
				root,
				splinter,
				CFrame.new(x, edge + out * splinter.Size.Y / 2, 0)
					* CFrame.Angles(if out > 0 then 0 else math.pi, 0, 0)
			)
		end
	end
	return root
end

local registry: { [string]: WeaponDef } = {
	Bone = {
		id = "Bone",
		name = "BONE",
		damage = 16,
		stun = 0.8,
		knockback = 14,
		speed = 95,
		lift = 6,
		gravity = 60,
		release = 0.24,
		recovery = 0.7,
		lifetime = 3,
		clip = "Bone_Throw",
		moveId = "BoneThrow",
		breaks = true,
		length = 1.7,
		grip = 1.7 * 0.2,
		bloodChance = { Head = 0.8, Torso = 0.35, Legs = 0.15 },
	},
	IronBar = {
		id = "IronBar",
		name = "IRON BAR",
		damage = 22,
		stun = 1.0,
		knockback = 26,
		speed = 80,
		lift = 7,
		gravity = 70,
		release = 0.27,
		recovery = 0.9,
		lifetime = 3,
		clip = "Bone_Throw",
		moveId = "IronBarThrow",
		breaks = false,
		hitSound = "HeavyHit",
		breakSound = "MetalClang",
		length = BAR_LENGTH,
		grip = BAR_LENGTH / 2 - 0.45,
		bloodChance = { Head = 0.7, Torso = 0.2, Legs = 0.1 },
		build = buildIronBar,
	},

	Plank = {
		id = "Plank",
		name = "PLANK",
		damage = 15,
		stun = 0.8,
		knockback = 18,
		speed = 85,
		lift = 7,
		gravity = 65,
		release = 0.25,
		recovery = 0.8,
		lifetime = 3,
		clip = "Bone_Throw",
		moveId = "PlankThrow",
		breaks = true,
		hitSound = "HeavyHit",
		breakSound = "PlankBreak",
		length = PLANK_LENGTH,
		grip = PLANK_LENGTH / 2 - 0.45,
		bloodChance = { Head = 0.6, Torso = 0.2, Legs = 0.1 },
		build = buildPlank,
	},
}

-- What a "Random" street spawn picks from.
Weapons.STREET = table.freeze({ "IronBar", "Plank" })

local byMove: { [string]: WeaponDef } = {}
for _, weapon in registry do
	byMove[weapon.moveId] = weapon
end

function Weapons.get(id: unknown): WeaponDef?
	return if typeof(id) == "string" then registry[id] else nil
end

-- The weapon a hit's move id is the throw of (nil: not a thrown weapon).
function Weapons.byMove(moveId: unknown): WeaponDef?
	return if typeof(moveId) == "string" then byMove[moveId] else nil
end

-- A new model of `id` (its root part, weapon space at the origin), or nil
-- for one drawn elsewhere (the bone).
function Weapons.build(id: string, piece: Piece?): BasePart?
	local weapon = registry[id]
	local build = if weapon then weapon.build else nil
	return if build then build(piece or "Whole") else nil
end

-- Moves a built one (its root) to `at`, its parts with it. (The welds only
-- hold once it is in the world: out of it, each part is placed by hand.)
function Weapons.pivot(root: BasePart, at: CFrame)
	root.CFrame = at
	for _, item in root:GetDescendants() do
		if item:IsA("Weld") and item.Part0 == root and item.Part1 then
			item.Part1.CFrame = at * item.C0
		end
	end
end

return table.freeze(Weapons)
