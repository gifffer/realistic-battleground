--!strict
-- BloodStain: ONE mark of blood on a surface (floor, wall, a body), the
-- building block every other blood module uses.
--
-- Two ways to draw it:
--   • with PICTURES (Config.Blood.IMAGES, docs/BLOOD_FR.md): a Decal on an
--     invisible thin Part ("carrier"). The picture is grey (white = a thin
--     film, dark = thick blood); Decal.Color3 tints it with the palette, so
--     the same picture goes from red to brown as it ages (BloodAge).
--     Carriers are REUSED (a free list): no Destroy / Instance.new for every
--     drop.
--   • without (id 0, not uploaded yet): plain shapes, but never a perfect
--     disc - a main ellipse, a scalloped edge (small spines), a darker thick
--     centre, a dark clotting ring that appears as it dries, thin lighter
--     bits (satellites, tails). Each shape below is drawn for its kind.
--
-- The shape follows real blood:
--   • a drop landing straight down is round; slanted, it stretches into an
--     oval, then a "!" (a body and a tail toward where it was going), and a
--     grazing one is a long streak. `along` = the way it was going.
--   • it stays ON the surface: a mark half off a ledge is shrunk or dropped
--     (4 short rays at its corners), and if it hangs over a curb the blood
--     runs down the side (the run hook, set by Blood).
--   • rough ground (concrete, asphalt, wood...) soaks it in: it dries faster
--     and lets the ground show through a little; grass hides it; water takes
--     it (no mark).
--
--   BloodStain.stain(kind, at, normal, along, width, length, options?)
--       a mark (if too many marks were made this frame, it waits a few frames:
--       never silently skipped, except tiny satellites after 0.5 s)
--   BloodStain.place(...) same, now, returns its BloodAge record (or nil)
--   BloodStain.rescale(record, kAlong, kAcross)  grows a mark (pools, soaks)
--   BloodStain.image(kind, random, index?)  an uploaded picture id, or 0
--   BloodStain.resolve(kind)   the kind actually drawn (a picture not uploaded
--       yet borrows a close kind's, Config.Blood.IMAGE_FALLBACK) and its id
--   BloodStain.porous(material)  rough ground (blood soaks in)?
--   BloodStain.onSkin(part, point)   where blood sticks on a body (the skin)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BloodAge = require(script.Parent.BloodAge)

local BloodStain = {}

local PALETTE = Config.Blood.PALETTE
local PROFILES = Config.Blood.PROFILES
local IMAGES = Config.Blood.IMAGES
local IMAGE_FALLBACK: { [string]: string } = (Config.Blood :: any).IMAGE_FALLBACK or {}

-- Turn of the pictures on their carrier (radians), in case a picture shows
-- turned in Studio (a tail not pointing where the drop went): adjust here.
local IMAGE_TURN = 0
local CARRIER_THICKNESS = 0.02
-- How far a mark sits off its surface (studs). Less than ~0.02 and the
-- surface and the mark fight for the same pixels (they flicker, worse far
-- from the camera); each new mark and each piece of a mark a little higher
-- still, so overlapping marks don't fight each other either.
local MIN_LIFT = 0.02
local MARK_STEP = 0.0015 -- (between two marks, 10 steps then it starts again)
local PIECE_STEP = 0.0012 -- (between two pieces of one mark)
local UP = Vector3.new(0, 1, 0)
-- (a flattened sphere: its thin X axis out of the surface, Y across, Z along)
local TO_ELLIPSE = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))

local folder = Instance.new("Folder")
folder.Name = "Blood"
folder.Parent = workspace
BloodStain.folder = folder

------------------------------------------------------------------------------
-- Bodies and skin
------------------------------------------------------------------------------

function BloodStain.isBody(instance: Instance): Model?
	local model = instance:FindFirstAncestorOfClass("Model")
	if
		model
		and (
			model:FindFirstChildOfClass("Humanoid")
			or CollectionService:HasTag(model, Config.Combat.TAG)
		)
	then
		return model
	end
	return nil
end
local isBody = BloodStain.isBody

-- Where blood lands on a body: on the SKIN you see, not on the part's box.
-- The classic head is round (a cylinder 0.6 across, its top and bottom
-- rounded off; its part a wider box); the invisible root is the torso; an
-- accessory is on the part it's worn on - but hair and hats cover the skin
-- (no blood on them). Returns the part it sticks to, the point on its
-- surface and the way out of it; nil: no skin there (beside the head, under
-- the chin, on hair).
function BloodStain.onSkin(part: BasePart, world: Vector3): (BasePart?, Vector3, Vector3)
	local model = part:FindFirstAncestorOfClass("Model")
	if part.Parent and part.Parent:IsA("Accessory") then
		local weld = part:FindFirstChild("AccessoryWeld")
		local body: BasePart? = nil
		if weld and weld:IsA("JointInstance") then
			local other = if weld.Part0 == part then weld.Part1 else weld.Part0
			if other and other:IsA("BasePart") then
				body = other
			end
		end
		if body == nil or body.Name == "Head" then
			return nil, world, UP -- (hair / a hat: covers the skin)
		end
		part = body
	elseif part.Name == "HumanoidRootPart" and model then
		local torso = model:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			part = torso
		end
	end
	local p = part.CFrame:PointToObjectSpace(world)
	if part.Name == "Head" then
		-- The exact surface: a core (a disc 0.3 across, from -0.3 to 0.3)
		-- padded by 0.3 all round - the nearest point on it, out by 0.3.
		local flatP = Vector3.new(p.X, 0, p.Z)
		local r = flatP.Magnitude
		if r > 0.68 then
			return nil, world, UP -- (beside the head: through its empty box)
		end
		local out = if r > 1e-3 then flatP.Unit else Vector3.new(0, 0, -1)
		local ay = math.abs(p.Y)
		local sy = if p.Y < 0 then -1 else 1
		local cr, cy = math.min(r, 0.3), math.min(ay, 0.3)
		local d = Vector2.new(r - cr, ay - cy)
		if d.Magnitude < 1e-3 then
			-- (inside the core: out along the nearer side)
			if r >= ay then
				cr, d = 0.3, Vector2.new(1, 0)
			else
				cy, d = 0.3, Vector2.new(0, 1)
			end
		end
		d = d.Unit
		local normal = out * d.X + UP * (sy * d.Y)
		local point = out * (cr + d.X * 0.3) + Vector3.new(0, sy * (cy + d.Y * 0.3), 0)
		if point.Y < -0.42 then
			return nil, world, UP -- (under the chin: the neck, the torso)
		end
		return part, part.CFrame * point, part.CFrame:VectorToWorldSpace(normal)
	end
	-- a block: the face the point is closest to
	local half = part.Size / 2
	local rx, ry, rz = math.abs(p.X) / half.X, math.abs(p.Y) / half.Y, math.abs(p.Z) / half.Z
	local localNormal: Vector3
	if rx >= ry and rx >= rz then
		localNormal = Vector3.new(math.sign(p.X), 0, 0)
	elseif ry >= rz then
		localNormal = Vector3.new(0, math.sign(p.Y), 0)
	else
		localNormal = Vector3.new(0, 0, math.sign(p.Z))
	end
	local onFace = Vector3.new(
		if localNormal.X ~= 0 then localNormal.X * half.X else math.clamp(p.X, -half.X, half.X),
		if localNormal.Y ~= 0 then localNormal.Y * half.Y else math.clamp(p.Y, -half.Y, half.Y),
		if localNormal.Z ~= 0 then localNormal.Z * half.Z else math.clamp(p.Z, -half.Z, half.Z)
	)
	return part, part.CFrame * onFace, part.CFrame:VectorToWorldSpace(localNormal)
end
local onSkin = BloodStain.onSkin

------------------------------------------------------------------------------
-- Pictures
------------------------------------------------------------------------------

-- An uploaded picture of `kind` (a random one of those uploaded, or number
-- `index`), or 0 (none: draw shapes).
function BloodStain.image(kind: string, random: Random?, index: number?): number
	local list = (IMAGES :: any)[kind]
	if typeof(list) ~= "table" then
		return 0
	end
	if index then
		local id = list[index]
		return if typeof(id) == "number" then id else 0
	end
	local uploaded: { number } = {}
	for _, id in list do
		if typeof(id) == "number" and id ~= 0 then
			table.insert(uploaded, id)
		end
	end
	if #uploaded == 0 then
		return 0
	end
	local pick = if random then random:NextInteger(1, #uploaded) else math.random(1, #uploaded)
	return uploaded[pick]
end

-- Does this exact kind have its own uploaded picture? (no stand-in)
function BloodStain.hasImage(kind: string): boolean
	return BloodStain.image(kind, nil) ~= 0
end

-- The kind that is really drawn for `kind`, and one of its picture ids:
-- `kind` itself if it has an uploaded picture; else its stand-in from
-- Config.Blood.IMAGE_FALLBACK (a skin rivulet not uploaded yet looks like a
-- wall run), up to 3 steps; else the last stand-in and 0 (its plain shapes).
function BloodStain.resolve(kind: string): (string, number)
	local current = kind
	for _ = 1, 4 do
		local id = BloodStain.image(current, nil)
		if id ~= 0 then
			return current, id
		end
		local nextKind = IMAGE_FALLBACK[current]
		if nextKind == nil then
			break
		end
		current = nextKind
	end
	return current, 0
end

------------------------------------------------------------------------------
-- Raycasts (the ground under a mark), through bodies and blood
------------------------------------------------------------------------------

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = false
local paramsAt = 0
local function ground(): RaycastParams
	local now = os.clock()
	if now - paramsAt > 1 then
		paramsAt = now
		local ignore: { Instance } = CollectionService:GetTagged(Config.Combat.TAG)
		-- (the frozen bodies the finishers leave are bodies too: the floor
		-- is under them, a pool never lands on one)
		for _, corpse in CollectionService:GetTagged(Config.Combat.CORPSE_TAG) do
			table.insert(ignore, corpse)
		end
		table.insert(ignore, folder)
		groundParams.FilterDescendantsInstances = ignore
	end
	return groundParams
end
BloodStain.ground = ground

-- Rough ground: blood soaks in (dries faster, lets the ground show through).
local POROUS: { [Enum.Material]: boolean } = {
	[Enum.Material.Concrete] = true,
	[Enum.Material.Asphalt] = true,
	[Enum.Material.Brick] = true,
	[Enum.Material.Pavement] = true,
	[Enum.Material.Wood] = true,
	[Enum.Material.WoodPlanks] = true,
	[Enum.Material.Fabric] = true,
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Mud] = true,
	[Enum.Material.Sand] = true,
	[Enum.Material.Cobblestone] = true,
	[Enum.Material.Carpet] = true,
}
-- Rough ground (concrete, asphalt, wood...)? Blood soaks into it.
function BloodStain.porous(material: Enum.Material?): boolean
	return material ~= nil and POROUS[material] == true
end

-- Smooth ground: it stays wet and shiny longer.
local SMOOTH: { [Enum.Material]: boolean } = {
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.SmoothPlastic] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.Marble] = true,
	[Enum.Material.Granite] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.Plastic] = true,
	[Enum.Material.Foil] = true,
	[Enum.Material.Ice] = true,
}

-- How the ground takes it: (takes a mark?, dries ×speed, + transparency, × size).
local function porosity(material: Enum.Material?): (boolean, number, number, number)
	if material == nil then
		return true, 1, 0, 1
	end
	if material == Enum.Material.Water then
		return false, 1, 0, 1 -- (washed away)
	end
	if material == Enum.Material.Grass or material == Enum.Material.LeafyGrass then
		return true, 1.6, 0.2, 0.7 -- (it hides in the grass)
	end
	if POROUS[material] then
		return true, 1.6, 0.05, 1
	end
	if SMOOTH[material] then
		return true, 0.7, 0, 1
	end
	return true, 1, 0, 1
end

------------------------------------------------------------------------------
-- Pieces: carriers (pictures) and ellipses (no pictures)
------------------------------------------------------------------------------

export type Piece = {
	inst: BasePart,
	weld: Weld?,
	cx: number, -- centre along the mark's direction (studs, before scaling)
	cz: number, -- centre across it
	w: number, -- size across
	l: number, -- size along
	angle: number, -- its own direction (radians from `along` toward the side)
	lift: number,
	carrier: boolean,
	upright: boolean,
}

export type Shape = {
	frame: CFrame, -- X = along, Y = out of the surface, Z = across (world, or local to `stuck`)
	stuck: BasePart?,
	pieces: { Piece },
	kAlong: number,
	kAcross: number,
}

local shapes: { [any]: Shape } = setmetatable({}, { __mode = "k" }) :: any

local freeCarriers: { Part } = {}
local glossCount = 0

local function newEllipse(): Part
	local part = Instance.new("Part")
	part.Name = "Blood"
	part.Size = Vector3.new(0.01, 0.1, 0.1)
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Archivable = false -- (copies of a body don't copy its blood)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function newCarrier(): Part
	local part = table.remove(freeCarriers)
	if part then
		return part
	end
	local made = Instance.new("Part")
	made.Name = "BloodStain"
	made.Transparency = 1 -- (only its picture shows)
	made.Material = Enum.Material.SmoothPlastic
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Archivable = false
	local decal = Instance.new("Decal")
	decal.Name = "Main"
	decal.Face = Enum.NormalId.Top
	decal.Parent = made
	return made
end

-- Where a piece goes (relative to the shape's frame).
local function pieceFrame(shape: Shape, piece: Piece): (CFrame, Vector3)
	local cx, cz = piece.cx * shape.kAlong, piece.cz * shape.kAcross
	local k = math.sqrt(shape.kAlong * shape.kAcross)
	if piece.carrier then
		local turn = CFrame.Angles(0, -piece.angle + IMAGE_TURN, 0)
		if piece.upright then
			-- (a picture drawn "up" = the way it goes: feet, runs, hands)
			turn *= CFrame.Angles(0, -math.pi / 2, 0)
		end
		local cf = CFrame.new(cx, piece.lift - CARRIER_THICKNESS / 2, cz) * turn
		local size = if piece.upright
			then Vector3.new(piece.w * shape.kAcross, CARRIER_THICKNESS, piece.l * shape.kAlong)
			else Vector3.new(
				piece.l * shape.kAlong,
				CARRIER_THICKNESS,
				piece.w * shape.kAcross
			)
		return cf, size
	end
	local cf = CFrame.new(cx, piece.lift, cz) * CFrame.Angles(0, -piece.angle, 0) * TO_ELLIPSE
	return cf, Vector3.new(0.01, piece.w * k, piece.l * k)
end

local function setPiece(shape: Shape, piece: Piece)
	local cf, size = pieceFrame(shape, piece)
	piece.inst.Size = size
	local weld = piece.weld
	if weld then
		weld.C0 = shape.frame * cf
	else
		piece.inst.CFrame = shape.frame * cf
	end
end

local function attach(shape: Shape, piece: Piece)
	local stuck = shape.stuck
	local part = piece.inst
	if stuck then
		part.Anchored = false
		part.Massless = true
		local weld = Instance.new("Weld")
		weld.Part0 = stuck
		weld.Part1 = part
		piece.weld = weld
		setPiece(shape, piece)
		weld.Parent = part
		local holder = stuck:FindFirstChild("BloodSplats")
		if holder == nil or not holder:IsA("Folder") then
			local made = Instance.new("Folder")
			made.Name = "BloodSplats"
			made.Archivable = false
			made.Parent = stuck
			holder = made
		end
		part.Parent = holder
	else
		part.Anchored = true
		setPiece(shape, piece)
		part.Parent = folder
	end
end

-- Grows (or shrinks) a mark made by `place`: along its direction ×kAlong,
-- across ×kAcross (from its size when made).
function BloodStain.rescale(record: BloodAge.Record, kAlong: number, kAcross: number)
	local shape = shapes[record]
	if shape == nil or record.dead then
		return
	end
	shape.kAlong, shape.kAcross = kAlong, kAcross
	for _, piece in shape.pieces do
		if piece.inst.Parent then
			setPiece(shape, piece)
		end
	end
end

-- Moves a piece of a mark (runs: the bead at the tip goes down).
function BloodStain.movePiece(
	record: BloodAge.Record,
	index: number,
	cx: number,
	cz: number,
	l: number?
)
	local shape = shapes[record]
	local piece = if shape then shape.pieces[index] else nil
	if shape == nil or piece == nil or record.dead then
		return
	end
	piece.cx, piece.cz = cx, cz
	if l then
		piece.l = l
	end
	setPiece(shape, piece)
end

-- The world point at (cx, cz) of a mark's frame (the tip of a run...).
function BloodStain.worldPoint(record: BloodAge.Record, cx: number, cz: number): Vector3?
	local shape = shapes[record]
	if shape == nil then
		return nil
	end
	local cf = shape.frame * CFrame.new(cx * shape.kAlong, 0, cz * shape.kAcross)
	local stuck = shape.stuck
	if stuck then
		cf = stuck.CFrame * cf
	end
	return cf.Position
end

function BloodStain.shapeOf(record: BloodAge.Record): Shape?
	return shapes[record]
end

------------------------------------------------------------------------------
-- The shapes drawn without pictures
------------------------------------------------------------------------------

-- Each fallback kind: ellipses in the mark's frame (X along, Z across), with
-- `W` the width and `L` the length of the mark. Drawn bottom first (the
-- clotting ring under the main one, so it shows as a dark edge).
local function drawFallback(
	kind: string,
	W: number,
	L: number,
	random: Random,
	add: (
		number,
		number,
		number,
		number,
		number?,
		number?,
		number?,
		boolean?
	) -> ()
)
	local function scallops(count: number, front: boolean, radiusW: number, radiusL: number)
		-- the crown: short spines out of the edge (front only: a slanted drop)
		for _ = 1, count do
			local a = if front
				then random:NextNumber(-1.2, 1.2)
				else random:NextNumber(0, math.pi * 2)
			local r = random:NextNumber(0.46, 0.56)
			local cx, cz = math.cos(a) * radiusL * r, math.sin(a) * radiusW * r
			local s = random:NextNumber(0.1, 0.22) * math.min(radiusW, radiusL)
			add(
				cx,
				cz,
				s * random:NextNumber(0.4, 0.7),
				s * random:NextNumber(1.2, 2.2),
				a,
				-0.15,
				0.08
			)
		end
	end
	if kind == "spatterRound" or kind == "drip" or kind == "dripPool" then
		add(
			0,
			0,
			W * 1.08,
			W * random:NextNumber(1.04, 1.12),
			random:NextNumber(0, math.pi),
			0.5,
			0.05,
			true
		)
		add(0, 0, W, W * random:NextNumber(0.95, 1.1), random:NextNumber(0, math.pi), 0, 0)
		-- (thick in the middle: darker)
		add(
			W * random:NextNumber(-0.08, 0.08),
			W * random:NextNumber(-0.08, 0.08),
			W * 0.55,
			W * 0.6,
			random:NextNumber(0, math.pi),
			0.3,
			0.1
		)
		scallops(
			if W < 0.1
				then 0
				elseif W < 0.2 then random:NextInteger(2, 4)
				else random:NextInteger(4, 7),
			false,
			W,
			W
		)
		if kind == "dripPool" or (kind == "spatterRound" and W > 0.14) then
			-- satellites: small drops thrown around it
			for _ = 1, random:NextInteger(3, 6) do
				local a = random:NextNumber(0, math.pi * 2)
				local r = W * random:NextNumber(0.75, 1.3)
				local s = W * random:NextNumber(0.06, 0.13)
				add(
					math.cos(a) * r,
					math.sin(a) * r,
					s,
					s * random:NextNumber(1, 1.6),
					a,
					-0.1,
					0.05
				)
			end
		end
	elseif kind == "spatterOval" then
		add(0, 0, W * 1.07, L * 1.05, 0, 0.5, 0.05, true)
		add(0, 0, W, L, 0, 0, 0)
		add(-L * 0.08, 0, W * 0.5, L * 0.5, 0, 0.3, 0.1)
		scallops(random:NextInteger(3, 5), true, W, L)
		for index = 1, random:NextInteger(1, 3) do
			local s = W * random:NextNumber(0.08, 0.16)
			add(
				L * (0.6 + 0.18 * index),
				W * random:NextNumber(-0.25, 0.25),
				s,
				s * 1.6,
				0,
				-0.1,
				0.05
			)
		end
	elseif kind == "spatterTail" then
		-- the "!": a body, a narrowing tail ahead of it, a drop at its tip
		local body = L * 0.55
		add(-L * 0.2, 0, W * 1.06, body * 1.05, 0, 0.5, 0.05, true)
		add(-L * 0.2, 0, W, body, 0, 0, 0)
		add(-L * 0.25, 0, W * 0.5, body * 0.5, 0, 0.3, 0.1)
		add(L * 0.22, 0, W * 0.35, L * 0.55, 0, -0.1, 0.05)
		add(L * 0.5, W * random:NextNumber(-0.05, 0.05), W * 0.22, W * 0.3, 0, 0, 0.05)
	elseif kind == "spatterStreak" then
		add(0, 0, W * 0.5, L, 0, -0.1, 0.05)
		for index = 1, random:NextInteger(2, 3) do
			add(L * (index * 0.18 - 0.3), 0, W * 0.38, W * 0.6, 0, 0.1, 0.05)
		end
		add(L * 0.58, W * random:NextNumber(-0.1, 0.1), W * 0.18, W * 0.28, 0, 0, 0.05)
	elseif kind == "satellites" then
		-- a fan of tiny drops, stretched away from the impact
		for _ = 1, random:NextInteger(5, 9) do
			local a = random:NextNumber(-0.9, 0.9)
			local r = random:NextNumber(0.1, 0.5)
			local s = W * random:NextNumber(0.025, 0.06)
			add(math.cos(a) * r * L, math.sin(a) * r * W, s, s * (1.3 + r * 2), a, -0.15, 0.08)
		end
	elseif kind == "pool" or kind == "poolLobe" then
		local parts = if kind == "pool" then random:NextInteger(3, 4) else 1
		-- the clotting ring (under), then lobes of the pool, then its thick middle
		add(0, 0, W * 1.06, L * 1.06, random:NextNumber(-0.2, 0.2), 0.55, 0.02, true)
		add(0, 0, W, L, 0, 0, 0)
		for _ = 2, parts do
			local a = random:NextNumber(0, math.pi * 2)
			add(
				math.cos(a) * L * 0.22,
				math.sin(a) * W * 0.22,
				W * random:NextNumber(0.55, 0.75),
				L * random:NextNumber(0.6, 0.8),
				a,
				0.05,
				0
			)
		end
		add(0, 0, W * 0.55, L * 0.55, random:NextNumber(0, math.pi), 0.35, 0)
	elseif kind == "run" then
		-- blood running down: its trail (1), the bead at its tip (2), where it
		-- started (3) - Blood moves 1 and 2 as it runs
		add(L * 0.5, 0, W * 0.5, L, 0, -0.05, 0.05)
		add(L, 0, W * 0.9, W * 1.25, 0, 0.35, 0)
		add(0, 0, W * 1.1, W * 0.9, 0, 0.1, 0.05)
	elseif kind == "smear" then
		-- a drag: heavy where it started, feathered striations behind
		add(-L * 0.32, 0, W, L * 0.35, 0, 0.2, 0.05)
		for index = -2, 2 do
			add(0, index * W * 0.18, W * 0.14, L * random:NextNumber(0.75, 1), 0, -0.25, 0.3)
		end
		add(0, 0, W * 0.8, L * 0.85, 0, -0.1, 0.45)
	elseif kind == "footL" or kind == "footR" then
		-- a shoe sole: the ball and the toe ahead, the heel behind (L: its length)
		add(L * 0.18, 0, W, L * 0.55, 0, 0, 0)
		add(-L * 0.34, 0, W * 0.8, L * 0.3, 0, 0, 0)
	elseif kind == "handL" or kind == "handR" then
		add(0, 0, W * 0.75, L * 0.5, 0, 0.1, 0.1)
		for index = -2, 1 do
			add(L * 0.38, index * W * 0.17 + W * 0.08, W * 0.12, L * 0.32, 0, -0.1, 0.2)
		end
		add(
			L * 0.05,
			(if kind == "handL" then 1 else -1) * W * 0.42,
			W * 0.12,
			L * 0.25,
			0.7,
			-0.1,
			0.2
		)
	elseif kind == "arterialArc" then
		-- big drops along a wave (the beats of an artery sweeping by)
		local count = random:NextInteger(5, 7)
		for index = 1, count do
			local x = (index / (count + 1) - 0.5) * L
			local z = math.sin(index * 1.3) * W * 0.3
			local s = W * random:NextNumber(0.2, 0.32)
			add(x, z, s, s * 1.5, 0, 0.1, 0)
		end
	elseif kind == "soak" or kind == "skinSmear" or kind == "knuckles" then
		local thin = kind == "skinSmear"
		add(0, 0, W * 1.04, L * 1.04, 0, if thin then 0.2 else 0.4, 0.15, true)
		add(0, 0, W, L, 0, if thin then -0.3 else 0.1, if thin then 0.35 else 0.1)
		-- (cloth wicks along its threads: a little cross of longer bits)
		if kind == "soak" then
			add(0, 0, W * 0.35, L * 1.2, 0, 0.1, 0.25)
			add(0, 0, W * 1.2, L * 0.35, 0, 0.1, 0.25)
		end
	else
		add(0, 0, W, L, 0, 0, 0)
	end
end

------------------------------------------------------------------------------
-- Making a mark
------------------------------------------------------------------------------

export type Options = {
	random: Random?,
	onto: BasePart?, -- what it lands on (a body part: it sticks to the skin)
	profile: string?, -- Config.Blood.PROFILES (default "spatter", "body" on a body)
	category: string?, -- "stain" / "body" / "foot" (default by where it is)
	start: Color3?, -- its colour fresh (default ARTERIAL)
	dryColor: Color3?,
	alpha: number?, -- more transparent (a thin film, a trace)
	pinned: boolean?, -- (pools, finisher marks: the last to be removed)
	gloss: number?, -- a wet film this fraction of its size (pools)
	priority: number?, -- 3 main, 2 (default), 1 satellites (dropped first)
	index: number?, -- a given picture (feet: 1 heavy, 2 partial, 3 trace)
	material: Enum.Material?, -- the ground (else found by a ray)
	upright: boolean?, -- (a picture drawn upright: its top = along)
	turn: number?, -- (a picture turned around its centre, radians)
	noEdge: boolean?, -- (skip the ledge check)
	owner: Model?,
	life: number?,
}

local layerCount = 0
local madeThisFrame = 0
local runHook: ((Vector3, Vector3, number) -> ())? = nil

-- Blood (it owns runs) gives us how to make blood run down a ledge.
function BloodStain.setRunHook(hook: (at: Vector3, normal: Vector3, width: number) -> ())
	runHook = hook
end

-- Blood flowing over the ledge at `corner` (the ground ends going `away`):
-- it runs down the side below it.
function BloodStain.overLedge(corner: Vector3, away: Vector3, width: number)
	local hook = runHook
	if hook == nil or away.Magnitude < 1e-3 then
		return
	end
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 1e-3 then
		return
	end
	away = away.Unit
	local face =
		workspace:Raycast(corner + away * 0.3 - Vector3.new(0, 0.25, 0), -away * 0.6, ground())
	if face and math.abs(face.Normal.Y) < 0.5 then
		hook(face.Position + Vector3.new(0, 0.2, 0), face.Normal, width)
	end
end

-- Is the mark sitting on its surface? 0 corners off: yes; 1 (on a floor):
-- it hangs over a ledge (that corner returned); more: no.
local function edgeCheck(
	at: Vector3,
	normal: Vector3,
	along: Vector3,
	side: Vector3,
	w: number,
	l: number
): (number, Vector3?)
	local params = ground()
	local missed = 0
	local missedAt: Vector3? = nil
	for _, corner in
		{ Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(-1, -1) }
	do
		local point = at + along * (corner.X * l * 0.4) + side * (corner.Y * w * 0.4)
		local hit = workspace:Raycast(point + normal * 0.12, -normal * 0.24, params)
		if hit == nil then
			missed += 1
			missedAt = point
		end
	end
	return missed, missedAt
end

-- Makes the mark now. Returns its record (nil: nowhere to put it).
function BloodStain.place(
	kind: string,
	at: Vector3,
	normal: Vector3,
	along: Vector3,
	width: number,
	length: number,
	options: Options?
): BloodAge.Record?
	if not Config.Blood.ENABLED then
		return nil
	end
	local opts: Options = options or {}
	local random = opts.random or Random.new()
	local asked = kind
	-- (a new kind not uploaded yet: drawn as its stand-in, picture or shapes)
	kind = BloodStain.resolve(kind)
	local stuck: BasePart? = nil
	local onto = opts.onto
	local model: Model? = if onto then isBody(onto) else nil
	local speed, soakIn, sizeK = 1, 0, 1
	if onto and model then
		local skin, point, out = onSkin(onto, at)
		if skin == nil then
			return nil
		end
		stuck, at, normal = skin, point, out
		local r = math.max(width, length) * 0.5
		if skin.Name == "Head" then
			-- (small on the round head: a flat piece can't follow its curve)
			width, length = math.min(width, 0.3), math.min(length, 0.36)
		else
			-- inside the face: its centre at least `r` from the edges
			local l = skin.CFrame:PointToObjectSpace(at)
			local ln = skin.CFrame:VectorToObjectSpace(normal)
			local h = skin.Size / 2
			local function keepIn(value: number, extent: number, facing: number): number
				if math.abs(facing) > 0.7 then
					return value
				end
				local room = math.max(0, extent - r * 0.85)
				return math.clamp(value, -room, room)
			end
			l = Vector3.new(keepIn(l.X, h.X, ln.X), keepIn(l.Y, h.Y, ln.Y), keepIn(l.Z, h.Z, ln.Z))
			at = skin.CFrame * l
		end
	else
		if onto and not onto.Anchored then
			stuck = onto -- (something that moves: the mark goes with it)
		end
		local material = opts.material
		if material == nil then
			local hit = workspace:Raycast(at + normal * 0.1, -normal * 0.3, ground())
			material = if hit then hit.Material else nil
		end
		local takes, s, t, k = porosity(material)
		if not takes then
			return nil -- (in water: washed away)
		end
		speed, soakIn, sizeK = s, t, k
		width *= sizeK
		length *= sizeK
	end
	-- the frame: X along, Y out of the surface, Z across
	local forward = along - normal * along:Dot(normal)
	if forward.Magnitude < 1e-3 then
		forward = normal:Cross(Vector3.new(0.37, 0.71, 0.6))
	end
	forward = forward.Unit
	local side = forward:Cross(normal)
	-- on the ground: still sitting on it? (never hanging in the air)
	if stuck == nil and not opts.noEdge and math.max(width, length) > 0.14 then
		local missed, corner = edgeCheck(at, normal, forward, side, width, length)
		if missed >= 2 then
			width, length = width * 0.7, length * 0.7
			missed, corner = edgeCheck(at, normal, forward, side, width, length)
			if missed >= 2 then
				return nil
			end
		end
		if missed == 1 and corner and normal.Y > 0.7 and kind ~= "footL" and kind ~= "footR" then
			-- over a ledge: it runs down the side below that corner
			BloodStain.overLedge(corner, corner - at, math.min(width, length) * 0.3)
		end
	end
	-- (each new mark a hair higher than the last: no flicker where they
	-- overlap; a bit more far from the camera, where depth is less precise)
	layerCount = (layerCount + 1) % 10
	local camera = workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - at).Magnitude else 0
	local baseLift = if stuck and model
		then MIN_LIFT + layerCount * MARK_STEP * 0.5
		else MIN_LIFT + layerCount * MARK_STEP + math.min(distance * 0.0001, 0.015)
	local topLift = baseLift -- (the highest piece: the wet film goes over it)
	local frame = CFrame.fromMatrix(at, forward, normal)
	if stuck then
		frame = stuck.CFrame:ToObjectSpace(frame)
	end
	local shape: Shape = { frame = frame, stuck = stuck, pieces = {}, kAlong = 1, kAcross = 1 }
	local layers: { BloodAge.Layer } = {}
	local profileName = opts.profile or (if model then "body" else "spatter")
	local profile = (PROFILES :: any)[profileName] or PROFILES.spatter
	local category = opts.category or (if model then "body" else "stain")
	local start = opts.start or PALETTE.ARTERIAL
	local alpha = opts.alpha or 0
	local image = BloodStain.image(kind, random, opts.index)
	if image == 0 and kind ~= asked then
		-- (a stand-in may have fewer numbered pictures than asked for)
		image = BloodStain.image(kind, random)
	end
	local anchor: BasePart
	local release: ((BloodAge.Record) -> ())? = nil
	if image ~= 0 then
		local carrier = newCarrier()
		local decal = carrier:FindFirstChild("Main") :: Decal
		decal.Texture = "rbxassetid://" .. image
		decal.ZIndex = 1
		local piece: Piece = {
			inst = carrier,
			weld = nil,
			cx = 0,
			cz = 0,
			w = width,
			l = length,
			angle = opts.turn or 0,
			lift = baseLift,
			carrier = true,
			upright = opts.upright == true,
		}
		table.insert(shape.pieces, piece)
		attach(shape, piece)
		local main = BloodAge.layer(decal, 0, alpha)
		if kind == "pool" then
			main.gel = 0.1 -- (clotting: the thick middle gels, a shade darker)
		end
		table.insert(layers, main)
		if kind == "pool" then
			-- its clotting ring: the same outline (same number), it shows as it dries
			local rimId = BloodStain.image("poolRim", nil, table.find((IMAGES :: any).pool, image))
			if rimId ~= 0 then
				local rim = Instance.new("Decal")
				rim.Name = "Rim"
				rim.Face = Enum.NormalId.Top
				rim.Texture = "rbxassetid://" .. rimId
				rim.ZIndex = 2
				rim.Parent = carrier
				table.insert(layers, BloodAge.layer(rim, 0.3, 0, true))
			end
			-- the pale serum ring that seeps out of an old pool (same outline,
			-- same frame: pool_2 with serum_halo_2); invisible until 90 s
			local serumId =
				BloodStain.image("serumHalo", nil, table.find((IMAGES :: any).pool, image))
			if serumId ~= 0 then
				local serum = Instance.new("Decal")
				serum.Name = "Serum"
				serum.Face = Enum.NormalId.Top
				serum.Texture = "rbxassetid://" .. serumId
				serum.ZIndex = 0 -- (under the pool: it only shows outside its edge)
				serum.Parent = carrier
				local layer = BloodAge.layer(serum, 0, 0.45)
				layer.color = PALETTE.SERUM
				layer.showFrom = 90
				layer.showFull = 180
				table.insert(layers, layer)
			end
		end
		anchor = carrier
		if stuck == nil then
			release = function(record: BloodAge.Record)
				local gloss = record.gloss
				if gloss then
					gloss:Destroy()
					glossCount -= 1
				end
				for _, name in { "Rim", "Serum" } do
					local extra = carrier:FindFirstChild(name)
					if extra then
						extra:Destroy()
					end
				end
				if carrier.Parent == nil then
					return -- (already destroyed: never reuse it)
				end
				carrier.Parent = nil
				if #freeCarriers < 300 then
					table.insert(freeCarriers, carrier)
				else
					carrier:Destroy()
				end
			end
		end
	else
		local lift = baseLift
		local count = 0
		drawFallback(kind, width, length, random, function(cx, cz, w, l, angle, shade, a, rim)
			if count >= 14 then
				return
			end
			count += 1
			lift += PIECE_STEP
			topLift = lift
			local part = newEllipse()
			local piece: Piece = {
				inst = part,
				weld = nil,
				cx = cx,
				cz = cz,
				w = math.max(w, 0.012),
				l = math.max(l, 0.012),
				angle = angle or 0,
				lift = lift,
				carrier = false,
				upright = false,
			}
			table.insert(shape.pieces, piece)
			local layer =
				BloodAge.layer(part, shade or 0, math.clamp(alpha + (a or 0), 0, 0.95), rim)
			layer.shiny = not layer.rim
			table.insert(layers, layer)
			-- (painted right away: no grey flash before its first ageing pass)
			part.Color = start
			part.Transparency = if rim then 1 else layer.alpha
			attach(shape, piece)
		end)
		if #shape.pieces == 0 then
			return nil
		end
		anchor = shape.pieces[1].inst
	end
	madeThisFrame += #shape.pieces
	-- a wet shiny film over a fresh pool (dark: the sky reflects in it)
	local gloss: BasePart? = nil
	local glossPiece: Piece? = nil
	local glossScale = opts.gloss
	if
		glossScale
		and glossScale > 0
		and glossCount < BloodAge.cap("GLOSS")
		and profile.gloss > 0
	then
		local film = newEllipse()
		film.Name = "BloodGloss"
		film.Color = PALETTE.GLOSS
		film.Transparency = 0.55
		local piece: Piece = {
			inst = film,
			weld = nil,
			cx = 0,
			cz = 0,
			w = width * glossScale,
			l = length * glossScale,
			angle = 0,
			lift = topLift + 0.003,
			carrier = false,
			upright = false,
		}
		table.insert(shape.pieces, piece)
		attach(shape, piece)
		gloss = film
		glossCount += 1
		glossPiece = piece
		if release == nil then
			release = function(record: BloodAge.Record)
				glossCount -= 1
				for _, layer in record.layers do
					layer.inst:Destroy()
				end
				film:Destroy()
				record.anchor:Destroy()
			end
		end
	end
	local record: BloodAge.Record = {
		layers = layers,
		anchor = anchor,
		gloss = gloss,
		glossAlpha = 0.55,
		start = start,
		dryColor = opts.dryColor,
		born = os.clock(),
		profile = profile,
		speed = speed,
		soakIn = soakIn,
		life = opts.life or profile.life,
		category = category,
		owner = opts.owner or model,
		pinned = opts.pinned == true,
		fadeStart = nil,
		dead = false,
		release = release,
		-- (plain shapes: about 3 of them count as one picture)
		weight = if image ~= 0 then 1 else math.ceil(#shape.pieces / 3),
	}
	local wetFilm = glossPiece
	if wetFilm then
		-- (drying, the wet film retreats toward the thick middle: from its
		-- size fresh down to 0.43 of it when the gloss ends, 0.7 → 0.3 × the pool)
		local baseW, baseL = wetFilm.w, wetFilm.l
		local lastK = 1
		record.reshape = function(rec: BloodAge.Record, t: number)
			local p = rec.profile
			local u = math.clamp((t - p.fresh) / math.max(p.glossEnd - p.fresh, 1), 0, 1)
			local k = 1 - 0.57 * u * u * (3 - 2 * u)
			if math.abs(k - lastK) > 0.03 and wetFilm.inst.Parent then
				lastK = k
				wetFilm.w, wetFilm.l = baseW * k, baseL * k
				setPiece(shape, wetFilm)
			end
		end
	end
	shapes[record] = shape
	BloodAge.add(record)
	BloodAge.paint(record)
	return record
end

------------------------------------------------------------------------------
-- The queue: never more than NEW_PER_FRAME new pieces a frame
------------------------------------------------------------------------------

type Pending = { run: () -> (), priority: number, at: number }
local queue: { Pending } = {}

local function budget(): number
	return Config.Blood.CAPS.NEW_PER_FRAME
end

-- A mark (see `place`); when this frame is full it waits its turn.
function BloodStain.stain(
	kind: string,
	at: Vector3,
	normal: Vector3,
	along: Vector3,
	width: number,
	length: number,
	options: Options?
)
	if not Config.Blood.ENABLED then
		return
	end
	if madeThisFrame < budget() and #queue == 0 then
		BloodStain.place(kind, at, normal, along, width, length, options)
		return
	end
	local priority = if options and options.priority then options.priority else 2
	table.insert(queue, {
		run = function()
			BloodStain.place(kind, at, normal, along, width, length, options)
		end,
		priority = priority,
		at = os.clock(),
	})
end

-- Can a mark still be made this frame?
function BloodStain.room(): boolean
	return madeThisFrame < budget()
end

RunService.Heartbeat:Connect(function()
	madeThisFrame = 0
	if #queue == 0 then
		return
	end
	local now = os.clock()
	-- (the important ones first; tiny satellites waiting too long: dropped)
	table.sort(queue, function(a, b)
		if a.priority ~= b.priority then
			return a.priority > b.priority
		end
		return a.at < b.at
	end)
	local kept: { Pending } = {}
	for _, pending in queue do
		local waited = now - pending.at
		if (pending.priority <= 1 and waited > 0.5) or waited > 1.5 then
			continue
		end
		if madeThisFrame < budget() then
			pending.run()
		else
			table.insert(kept, pending)
		end
	end
	queue = kept
end)

return table.freeze(BloodStain)
