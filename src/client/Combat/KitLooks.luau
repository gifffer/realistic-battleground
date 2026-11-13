--!strict
-- KitLooks: what some kits put on the fighter who wears them (drawn by
-- every client, from the "Kit" attribute the server sets on the fighter):
--   • BULL      a pair of curved bull horns (ridged at the base), a gold
--               nose ring, and his breath steaming now and then;
--   • SENTINEL  a real cloth cape (simulated: it falls, swings, flies back
--               when he runs, catches the wind and the shockwaves), gold
--               clasps and chain, a small emblem.
-- The horns, rings, clasps... are plain parts welded to the head / torso
-- (under them: a burst head (HeadBlast) takes the horns with it).
--
-- The cape is a grid of points (Verlet cloth): its top row is pinned to
-- the shoulders, the rest falls with gravity, is pushed by the air (the
-- wind, the speed, the shockwaves), keeps its shape with distance
-- constraints and stays out of the body (boxes of the torso, legs, arms)
-- and above the floor. Drawn with two wedges per triangle.
--
-- Wind: workspace.GlobalWind (the map's / biome's wind), plus a Vector3
-- "Wind" attribute on workspace for events (a storm...), plus gusts from
-- the moves' shockwaves (KitLooks.gust).
--
--   KitLooks.start()                           watch every fighter (and corpse)
--   KitLooks.gust(position, strength, radius)  a blast of air from there
--   KitLooks.hornTips(model)                   the Bull's horn tips

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local KitLooks = {}

local HORN = Color3.fromRGB(232, 222, 196) -- ivory
local HORN_BASE = Color3.fromRGB(128, 106, 80)
local HORN_TIP = Color3.fromRGB(48, 40, 36)
local RIDGE = Color3.fromRGB(150, 130, 104)
local GOLD = Color3.fromRGB(212, 168, 70)
local CAPE = Color3.fromRGB(128, 14, 22)
local TRIM = Color3.fromRGB(200, 156, 64)
local GEM = Color3.fromRGB(255, 44, 30)

local random = Random.new()

local function newPart(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
	return part
end

local function weld(part: BasePart, to: BasePart, offset: CFrame, parent: Instance)
	part.CFrame = to.CFrame * offset
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = to
	joint.Part1 = part
	joint.Parent = part
	part.Parent = parent
end

-- A cylinder from `a` to `b` (its axis is its X: turned to point along).
local function along(a: Vector3, b: Vector3): CFrame
	return CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
end

------------------------------------------------------------------------------
-- BULL
------------------------------------------------------------------------------

-- The horn's centre line (head space, studs: its centre the origin, -Z its
-- face, +X its right): out to the side, up, the tip turning in and forward.
local HORN_CURVE = {
	Vector3.new(0.36, 0.38, -0.02),
	Vector3.new(0.66, 0.46, -0.08),
	Vector3.new(0.95, 0.58, -0.16),
	Vector3.new(1.13, 0.82, -0.26),
	Vector3.new(1.16, 1.07, -0.37),
	Vector3.new(1.06, 1.27, -0.49),
	Vector3.new(0.94, 1.36, -0.58),
}
local HORN_STEPS = 3 -- smooth points between two curve points
local HORN_WIDTH = 0.3 -- at the base (the tip is a point)

local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return 0.5
		* (
			(2 * p1)
			+ (p2 - p0) * t
			+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
			+ (3 * p1 - p0 - 3 * p2 + p3) * t3
		)
end

local function hornPoints(side: number): { Vector3 }
	local points: { Vector3 } = {}
	for _, p in HORN_CURVE do
		table.insert(points, Vector3.new(p.X * side, p.Y, p.Z))
	end
	local count = #points
	local smooth: { Vector3 } = {}
	for index = 1, count - 1 do
		local p0 = points[math.max(1, index - 1)]
		local p1, p2 = points[index], points[index + 1]
		local p3 = points[math.min(count, index + 2)]
		for step = 0, HORN_STEPS - 1 do
			table.insert(smooth, catmull(p0, p1, p2, p3, step / HORN_STEPS))
		end
	end
	table.insert(smooth, points[count])
	return smooth
end

local function hornColor(t: number): Color3
	if t < 0.25 then
		return HORN_BASE:Lerp(HORN, t / 0.25)
	elseif t > 0.62 then
		return HORN:Lerp(HORN_TIP, (t - 0.62) / 0.38)
	end
	return HORN
end

local function horn(head: BasePart, side: number, folder: Instance)
	local points = hornPoints(side)
	local count = #points
	-- the root, sunk into the head
	local root = newPart("HornRoot", Vector3.new(0.36, 0.3, 0.36), HORN_BASE, Enum.PartType.Ball)
	weld(root, head, CFrame.new(points[1] - Vector3.new(0.04 * side, 0.02, 0)), folder)
	for index = 1, count - 1 do
		local a, b = points[index], points[index + 1]
		local t = (index - 1) / (count - 1)
		-- (tapering faster toward the tip, like a real horn)
		local width = HORN_WIDTH * (1 - t) ^ 0.8 + 0.035
		local color = hornColor(t)
		local piece = newPart(
			`Horn{index}`,
			Vector3.new((b - a).Magnitude + 0.02, width, width),
			color,
			Enum.PartType.Cylinder
		)
		piece.Reflectance = 0.04
		weld(piece, head, along(a, b), folder)
		local joint = newPart(`HornJoint{index}`, Vector3.one * width, color, Enum.PartType.Ball)
		joint.Reflectance = 0.04
		weld(joint, head, CFrame.new(a), folder)
		-- ridges around the base: rings a little wider and darker
		if index >= 2 and index <= 6 and index % 2 == 0 then
			local ridge = newPart(
				"HornRidge",
				Vector3.new(0.035, width * 1.12, width * 1.12),
				RIDGE,
				Enum.PartType.Cylinder
			)
			weld(ridge, head, along(a, b), folder)
		end
	end
	local tip = newPart("HornTip", Vector3.one * 0.06, HORN_TIP, Enum.PartType.Ball)
	weld(tip, head, CFrame.new(points[count]), folder)
end

-- A gold ring through the nose (a loop of small cylinders).
local NOSE_RING_CENTRE = Vector3.new(0, -0.17, -0.63)
local NOSE_RING_RADIUS = 0.11
local function noseRing(head: BasePart, folder: Instance)
	local segments = 12
	local function point(index: number): Vector3
		local angle = index / segments * math.pi * 2
		return NOSE_RING_CENTRE
			+ Vector3.new(math.sin(angle), math.cos(angle), 0) * NOSE_RING_RADIUS
	end
	for index = 0, segments - 1 do
		local a, b = point(index), point(index + 1)
		local piece = newPart(
			"NoseRing",
			Vector3.new((b - a).Magnitude + 0.012, 0.04, 0.04),
			GOLD,
			Enum.PartType.Cylinder
		)
		piece.Material = Enum.Material.Metal
		piece.Reflectance = 0.25
		piece.CastShadow = false
		weld(piece, head, along(a, b), folder)
	end
end

-- The Bulls on screen: their breath steams every few seconds.
-- (a dead one doesn't: its Humanoid at 0 HP)
local bulls: { [Model]: { head: BasePart, humanoid: Humanoid?, nextBreath: number } } = {}

local function buildBull(model: Model): Instance?
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "KitLook"
	horn(head, 1, folder)
	horn(head, -1, folder)
	noseRing(head, folder)
	folder.Parent = head
	bulls[model] = {
		head = head,
		humanoid = model:FindFirstChildOfClass("Humanoid"),
		nextBreath = os.clock() + random:NextNumber(1, 3),
	}
	return folder
end

local STEAM = "rbxasset://textures/particles/smoke_main.dds"
local function breathe(head: BasePart)
	for _, side in { -0.1, 0.1 } do
		local point = Instance.new("Attachment")
		point.CFrame = CFrame.new(side, -0.12, -0.62) * CFrame.Angles(math.rad(-35), 0, 0)
		point.Parent = head
		local steam = Instance.new("ParticleEmitter")
		steam.Texture = STEAM
		steam.Color = ColorSequence.new(Color3.fromRGB(235, 235, 240))
		steam.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(1, 0.9),
		})
		steam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		steam.Speed = NumberRange.new(1.5, 3)
		steam.SpreadAngle = Vector2.new(12, 12)
		steam.Lifetime = NumberRange.new(0.6, 1)
		steam.Drag = 3
		steam.Acceleration = Vector3.new(0, 1.2, 0)
		steam.RotSpeed = NumberRange.new(-40, 40)
		steam.Rotation = NumberRange.new(0, 360)
		steam.EmissionDirection = Enum.NormalId.Front
		steam.Rate = 0
		steam.Parent = point
		steam:Emit(4)
		task.delay(1.2, function()
			point:Destroy()
		end)
	end
end

------------------------------------------------------------------------------
-- SENTINEL: clasps, emblem
------------------------------------------------------------------------------

local function buildTrimmings(torso: BasePart, folder: Instance)
	-- gold clasps at the collarbones, a chain between them
	local left, right = Vector3.new(-0.74, 0.86, -0.5), Vector3.new(0.74, 0.86, -0.5)
	for _, at in { left, right } do
		local clasp = newPart("Clasp", Vector3.new(0.08, 0.22, 0.22), GOLD, Enum.PartType.Cylinder)
		clasp.Material = Enum.Material.Metal
		clasp.Reflectance = 0.3
		weld(clasp, torso, CFrame.new(at) * CFrame.Angles(0, math.rad(90), 0), folder)
		local gem = newPart("ClaspGem", Vector3.one * 0.1, GEM, Enum.PartType.Ball)
		gem.Material = Enum.Material.Neon
		weld(gem, torso, CFrame.new(at + Vector3.new(0, 0, -0.06)), folder)
	end
	local sag = Vector3.new(0, 0.82, -0.52)
	for _, segment in { { left, sag }, { sag, right } } do
		local a, b = segment[1], segment[2]
		local chain = newPart(
			"Chain",
			Vector3.new((b - a).Magnitude, 0.035, 0.035),
			GOLD,
			Enum.PartType.Cylinder
		)
		chain.Material = Enum.Material.Metal
		chain.Reflectance = 0.3
		weld(chain, torso, along(a, b), folder)
	end
	-- the emblem on the chest: a gold diamond, a red core
	local plate = newPart("Emblem", Vector3.new(0.42, 0.42, 0.05), GOLD)
	plate.Material = Enum.Material.Metal
	plate.Reflectance = 0.25
	weld(plate, torso, CFrame.new(0, 0.32, -0.52) * CFrame.Angles(0, 0, math.rad(45)), folder)
	local core = newPart("EmblemCore", Vector3.new(0.22, 0.22, 0.05), CAPE)
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(200, 24, 30)
	weld(core, torso, CFrame.new(0, 0.32, -0.54) * CFrame.Angles(0, 0, math.rad(45)), folder)
end

------------------------------------------------------------------------------
-- SENTINEL: the cloth cape
------------------------------------------------------------------------------

local COLS = 5 -- points across
local ROWS = 8 -- points down
local LENGTH = 3.3 -- studs, shoulders to hem
local HEM_WIDTH = 2.6 -- the cape flares out toward the hem
local THICKNESS = 0.045
local STEP = 1 / 60 -- the simulation's fixed time step
local ITERATIONS = 6 -- constraint passes per step (more on a sudden jerk)
-- Full gravity: the cloth falls with the body it hangs from (less would
-- make it float up over his head on every jump). The "floaty" look comes
-- from the air: pushing on its faces, dragging along it, and the form drag
-- of a curved cape (horizontal: wind meeting it edge-on still moves it).
local AERO = 6
local DRAG = 0.4
local SIDE_DRAG = 2
local DAMPING = 0.992
local MARGIN = 0.09 -- distance kept from the body
local SIMULATE_DISTANCE = 220 -- studs from the camera (beyond: hidden)
local SLOW_DISTANCE = 90 -- beyond: simulated every few frames
local BACK_Z = 0.5 + MARGIN -- the back plane of the torso, cape side

-- The top row, pinned (torso space): over the shoulders, across the back.
local PINS: { Vector3 } = {}
for column = 1, COLS do
	local t = (column - 1) / (COLS - 1)
	local x = -0.94 + 1.88 * t
	local edge = column == 1 or column == COLS
	table.insert(PINS, Vector3.new(x, if edge then 1.0 else 1.02, if edge then 0.3 else 0.54))
end

-- Where each point hangs at rest (torso space): row 1 = the pins.
local function restPoint(row: number, column: number): Vector3
	local pin = PINS[column]
	if row == 1 then
		return pin
	end
	local t = (row - 1) / (ROWS - 1)
	local spread = 1 + (HEM_WIDTH / 1.88 - 1) * t
	return Vector3.new(
		pin.X * spread,
		pin.Y - LENGTH / (ROWS - 1) * (row - 1),
		math.max(pin.Z, BACK_Z) + 0.05 * t
	)
end

type Constraint = { a: number, b: number, rest: number, stiffness: number }
-- A body part the cloth stays out of. mode "torso": pushed out through the
-- back; "leg": the shortest way, but never out the front; "free": the
-- shortest way.
type Box = { part: BasePart, half: Vector3, mode: string }
type Cloth = {
	model: Model,
	torso: BasePart,
	root: BasePart,
	folder: Folder,
	pos: { Vector3 },
	prev: { Vector3 },
	wedges: { WedgePart },
	trim: { Part },
	moved: { BasePart },
	frames: { CFrame },
	boxes: { Box },
	boxFrames: { CFrame },
	floorParams: RaycastParams,
	gust: Vector3,
	seed: number,
	accumulator: number,
	lastFrame: CFrame,
	skip: number,
	hidden: boolean,
}

local function index(row: number, column: number): number
	return (row - 1) * COLS + column
end

local cloths: { [Model]: Cloth } = {}

-- Every point at rest (start / after a teleport / back in view).
local function hang(cloth: Cloth)
	local frame = cloth.torso.CFrame
	for row = 1, ROWS do
		for column = 1, COLS do
			local world = frame * restPoint(row, column)
			cloth.pos[index(row, column)] = world
			cloth.prev[index(row, column)] = world
		end
	end
	cloth.lastFrame = frame
end

-- Distance constraints, their rest lengths measured on the rest pose.
local function buildConstraints(): { Constraint }
	local list: { Constraint } = {}
	local function link(rowA: number, colA: number, rowB: number, colB: number, stiffness: number)
		table.insert(list, {
			a = index(rowA, colA),
			b = index(rowB, colB),
			rest = (restPoint(rowB, colB) - restPoint(rowA, colA)).Magnitude,
			stiffness = stiffness,
		})
	end
	for row = 1, ROWS do
		for column = 1, COLS do
			if column < COLS then
				link(row, column, row, column + 1, 1)
			end
			if row < ROWS then
				link(row, column, row + 1, column, 1)
				if column < COLS then
					link(row, column, row + 1, column + 1, 0.6)
					link(row, column + 1, row + 1, column, 0.6)
				end
			end
			-- bending: a little stiffness, so it folds softly, not like paper
			if row + 2 <= ROWS then
				link(row, column, row + 2, column, 0.35)
			end
			if column + 2 <= COLS then
				link(row, column, row, column + 2, 0.2)
			end
		end
	end
	return list
end
local CONSTRAINTS = buildConstraints()

local BODY_BOXES: { { name: string, half: Vector3, mode: string } } = {
	{ name = "Torso", half = Vector3.new(1, 1, 0.5), mode = "torso" },
	{ name = "Head", half = Vector3.new(0.62, 0.62, 0.62), mode = "torso" },
	-- (the legs a little fatter: the hem never brushes into the feet)
	{ name = "Left Leg", half = Vector3.new(0.56, 1.08, 0.58), mode = "leg" },
	{ name = "Right Leg", half = Vector3.new(0.56, 1.08, 0.58), mode = "leg" },
	{ name = "Left Arm", half = Vector3.new(0.5, 1, 0.5), mode = "free" },
	{ name = "Right Arm", half = Vector3.new(0.5, 1, 0.5), mode = "free" },
}

local function buildCape(model: Model): Instance?
	local torso = model:FindFirstChild("Torso")
	local root = model:FindFirstChild("HumanoidRootPart")
	if torso == nil or not torso:IsA("BasePart") or root == nil or not root:IsA("BasePart") then
		return nil
	end
	-- Welded things go under the body; the cloth (anchored, moved every
	-- frame) in its own folder in the workspace.
	local look = Instance.new("Folder")
	look.Name = "KitLook"
	buildTrimmings(torso, look)
	look.Parent = torso

	local folder = Instance.new("Folder")
	folder.Name = `Cape_{model.Name}`
	local wedges: { WedgePart } = {}
	for _ = 1, (COLS - 1) * (ROWS - 1) * 4 do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Cloth"
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanQuery = false
		wedge.CanTouch = false
		wedge.Color = CAPE
		wedge.Material = Enum.Material.Fabric
		wedge.Size = Vector3.new(THICKNESS, 0.1, 0.1)
		wedge.Parent = folder
		table.insert(wedges, wedge)
	end
	local trim: { Part } = {}
	for _ = 1, COLS - 1 do
		local edge = Instance.new("Part")
		edge.Name = "Hem"
		edge.Shape = Enum.PartType.Cylinder
		edge.Anchored = true
		edge.CanCollide = false
		edge.CanQuery = false
		edge.CanTouch = false
		edge.Color = TRIM
		edge.Material = Enum.Material.Metal
		edge.Size = Vector3.new(0.1, 0.09, 0.09)
		edge.Parent = folder
		table.insert(trim, edge)
	end
	folder.Parent = workspace

	local boxes: { Box } = {}
	for _, box in BODY_BOXES do
		local limb = model:FindFirstChild(box.name)
		if limb and limb:IsA("BasePart") then
			table.insert(
				boxes,
				{ part = limb, half = box.half + Vector3.one * MARGIN, mode = box.mode }
			)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	params.FilterDescendantsInstances = { model, folder }

	local cloth: Cloth = {
		model = model,
		torso = torso,
		root = root,
		folder = folder,
		pos = {},
		prev = {},
		wedges = wedges,
		trim = trim,
		moved = {},
		frames = {},
		boxes = boxes,
		boxFrames = {},
		floorParams = params,
		gust = Vector3.zero,
		seed = random:NextNumber(0, 1000),
		accumulator = 0,
		lastFrame = torso.CFrame,
		skip = 0,
		hidden = false,
	}
	hang(cloth)
	cloths[model] = cloth
	-- (the look and the cloth go together)
	look.Destroying:Connect(function()
		folder:Destroy()
		if cloths[model] == cloth then
			cloths[model] = nil
		end
	end)
	return look
end

-- Pushes `p` out of a box (CFrame `frame`, half sizes `half`), see Box.
local function pushOut(p: Vector3, frame: CFrame, half: Vector3, mode: string): (Vector3, boolean)
	local l = frame:PointToObjectSpace(p)
	local dx = half.X - math.abs(l.X)
	local dy = half.Y - math.abs(l.Y)
	local dz = half.Z - math.abs(l.Z)
	if dx <= 0 or dy <= 0 or dz <= 0 then
		return p, false
	end
	if mode == "torso" and l.Z > -half.Z * 0.4 then
		l = Vector3.new(l.X, l.Y, half.Z)
	elseif dx < dy and dx < dz then
		l = Vector3.new(if l.X >= 0 then half.X else -half.X, l.Y, l.Z)
	elseif dy < dz then
		l = Vector3.new(l.X, if l.Y >= 0 then half.Y else -half.Y, l.Z)
	else
		l = Vector3.new(l.X, l.Y, if l.Z >= 0 or mode ~= "free" then half.Z else -half.Z)
	end
	return frame * l, true
end

local function windAt(cloth: Cloth, time: number): Vector3
	local wind = workspace.GlobalWind
	local event = workspace:GetAttribute("Wind")
	if typeof(event) == "Vector3" then
		wind += event
	end
	-- turbulence: never perfectly still, stronger in a strong wind
	local s = cloth.seed
	local turbulence = Vector3.new(
		math.noise(time * 0.8, s, 0.5),
		math.noise(s, time * 1.1, 1.5) * 0.5,
		math.noise(time * 0.9, s + 7, 2.5)
	) * (wind.Magnitude * 0.45 + 2.5)
	return wind + turbulence + cloth.gust
end

-- One step. `frame`: the torso at this step (interpolated across the
-- frame's steps); wind, floor and body boxes: read once per frame.
local function simulate(cloth: Cloth, frame: CFrame, dt: number, wind: Vector3, floorY: number)
	local pos, prev = cloth.pos, cloth.prev
	local gravity = Vector3.new(0, -workspace.Gravity, 0)

	-- Forces (gravity, air) and motion of the free points.
	for row = 2, ROWS do
		for column = 1, COLS do
			local i = index(row, column)
			local p = pos[i]
			-- the cloth's normal here (from its neighbours)
			local left = pos[index(row, math.max(1, column - 1))]
			local right = pos[index(row, math.min(COLS, column + 1))]
			local up = pos[index(row - 1, column)]
			local down = pos[index(math.min(ROWS, row + 1), column)]
			local normal = (right - left):Cross(down - up)
			normal = if normal.Magnitude > 1e-6 then normal.Unit else Vector3.zero
			local velocity = (p - prev[i]) / dt
			local relative = wind - velocity
			local push = normal * normal:Dot(relative) * AERO
				+ relative * DRAG
				+ Vector3.new(relative.X, 0, relative.Z) * SIDE_DRAG
			if push.Magnitude > 600 then
				push = push.Unit * 600
			end
			local nextPosition = p + (p - prev[i]) * DAMPING + (gravity + push) * dt * dt
			prev[i] = p
			pos[i] = nextPosition
		end
	end
	-- The top row follows the shoulders.
	local jerk = 0
	for column = 1, COLS do
		local i = index(1, column)
		local pinned = frame * PINS[column]
		jerk = math.max(jerk, (pinned - pos[i]).Magnitude)
		prev[i] = pos[i]
		pos[i] = pinned
	end

	-- Keep the cloth's shape (harder on a sudden jerk: take-off, landing).
	for _ = 1, if jerk > 0.4 then ITERATIONS * 2 else ITERATIONS do
		for _, c in CONSTRAINTS do
			local a, b = c.a, c.b
			local pa, pb = pos[a], pos[b]
			local delta = pb - pa
			local length = delta.Magnitude
			if length > 1e-6 then
				local pinnedA = a <= COLS
				local pinnedB = b <= COLS
				local correction = delta * ((length - c.rest) / length * c.stiffness)
				if pinnedA and not pinnedB then
					pos[b] = pb - correction
				elseif pinnedB and not pinnedA then
					pos[a] = pa + correction
				elseif not pinnedA and not pinnedB then
					pos[a] = pa + correction * 0.5
					pos[b] = pb - correction * 0.5
				end
			end
		end
	end

	-- Out of the body, behind the back, above the floor (a little friction
	-- when touching).
	local boxes, boxFrames = cloth.boxes, cloth.boxFrames
	for i = COLS + 1, COLS * ROWS do
		local p = pos[i]
		local touched = false
		for k, box in boxes do
			local pushed, hit = pushOut(p, boxFrames[k], box.half, box.mode)
			if hit then
				p = pushed
				touched = true
			end
		end
		-- never in front of the back plane, from the shoulders to the hem: no
		-- flipping over the head onto his chest, no slipping between / into
		-- the legs when the air pushes it forward (walking backward)
		local l = frame:PointToObjectSpace(p)
		if math.abs(l.X) < 1.2 and l.Z < BACK_Z then
			p = frame * Vector3.new(l.X, l.Y, BACK_Z)
			touched = true
		end
		if p.Y < floorY then
			p = Vector3.new(p.X, floorY, p.Z)
			touched = true
		end
		if touched then
			prev[i] = prev[i]:Lerp(p, 0.25)
		end
		pos[i] = p
	end
end

-- The wedges of the triangle a, b, c (two right-angled wedges make it).
local function triangle(cloth: Cloth, slot: number, a: Vector3, b: Vector3, c: Vector3)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local w1, w2 = cloth.wedges[slot], cloth.wedges[slot + 1]
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-6 or bc.Magnitude < 1e-6 then
		w1.Size = Vector3.new(THICKNESS, 0.001, 0.001)
		w2.Size = Vector3.new(THICKNESS, 0.001, 0.001)
		table.insert(cloth.moved, w1)
		table.insert(cloth.frames, CFrame.new(a))
		table.insert(cloth.moved, w2)
		table.insert(cloth.frames, CFrame.new(a))
		return
	end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.max(0.001, math.abs(ab:Dot(up)))
	w1.Size = Vector3.new(THICKNESS, height, math.max(0.001, math.abs(ab:Dot(back))))
	w2.Size = Vector3.new(THICKNESS, height, math.max(0.001, math.abs(ac:Dot(back))))
	table.insert(cloth.moved, w1)
	table.insert(cloth.frames, CFrame.fromMatrix((a + b) / 2, right, up, back))
	table.insert(cloth.moved, w2)
	table.insert(cloth.frames, CFrame.fromMatrix((a + c) / 2, -right, up, -back))
end

local function draw(cloth: Cloth)
	table.clear(cloth.moved)
	table.clear(cloth.frames)
	local pos = cloth.pos
	local slot = 1
	for row = 1, ROWS - 1 do
		for column = 1, COLS - 1 do
			local a = pos[index(row, column)]
			local b = pos[index(row, column + 1)]
			local c = pos[index(row + 1, column)]
			local d = pos[index(row + 1, column + 1)]
			triangle(cloth, slot, a, b, c)
			triangle(cloth, slot + 2, b, d, c)
			slot += 4
		end
	end
	-- the gold hem
	for column = 1, COLS - 1 do
		local a, b = pos[index(ROWS, column)], pos[index(ROWS, column + 1)]
		local edge = cloth.trim[column]
		edge.Size = Vector3.new((b - a).Magnitude + 0.06, 0.09, 0.09)
		table.insert(cloth.moved, edge)
		table.insert(cloth.frames, along(a, b))
	end
	workspace:BulkMoveTo(cloth.moved, cloth.frames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function updateCloths(dt: number)
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local time = os.clock()
	for model, cloth in cloths do
		if cloth.torso.Parent == nil or cloth.root.Parent == nil or model.Parent == nil then
			cloth.folder:Destroy()
			cloths[model] = nil
			continue
		end
		cloth.gust *= math.exp(-dt * 2.2)
		local frame = cloth.torso.CFrame
		-- Far away: hidden (not left floating where it was).
		local distance = (frame.Position - eye).Magnitude
		if distance > SIMULATE_DISTANCE then
			if not cloth.hidden then
				cloth.hidden = true
				cloth.folder.Parent = nil
			end
			continue
		elseif cloth.hidden then
			cloth.hidden = false
			cloth.folder.Parent = workspace
			hang(cloth)
			cloth.accumulator = 0
		end
		local every = if distance > SLOW_DISTANCE then 3 else 1
		cloth.skip += 1
		cloth.accumulator = math.min(cloth.accumulator + dt, STEP * 4)
		if cloth.skip < every then
			continue
		end
		cloth.skip = 0
		-- Teleported / respawned: back to rest.
		if (frame.Position - cloth.lastFrame.Position).Magnitude > 12 then
			hang(cloth)
		end
		-- Read once for the frame's steps: wind, floor, body.
		local wind = windAt(cloth, time)
		local floor =
			workspace:Raycast(cloth.root.Position, Vector3.new(0, -8, 0), cloth.floorParams)
		local floorY = if floor then floor.Position.Y + 0.06 else -math.huge
		for k, box in cloth.boxes do
			cloth.boxFrames[k] = box.part.CFrame
		end
		local steps = math.floor(cloth.accumulator / STEP)
		local from = cloth.lastFrame
		for step = 1, steps do
			cloth.accumulator -= STEP
			-- (the shoulders move smoothly across the frame's steps)
			simulate(cloth, from:Lerp(frame, step / steps), STEP, wind, floorY)
		end
		if steps > 0 then
			cloth.lastFrame = frame
		end
		draw(cloth)
	end
end

------------------------------------------------------------------------------

local BUILDERS: { [string]: (Model) -> Instance? } = {
	Bull = buildBull,
	Sentinel = buildCape,
}

local worn: { [Model]: Instance } = {}

local function refresh(model: Model)
	local old = worn[model]
	if old then
		old:Destroy()
		worn[model] = nil
	end
	bulls[model] = nil
	local kitId = model:GetAttribute("Kit")
	local build = if typeof(kitId) == "string" then BUILDERS[kitId] else nil
	if build then
		local look = build(model)
		if look then
			worn[model] = look
		end
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("Kit"):Connect(function()
		refresh(model)
	end)
	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			local old = worn[model]
			if old then
				old:Destroy()
			end
			worn[model] = nil
			bulls[model] = nil
		end
	end)
	task.defer(refresh, model) -- (once its body has loaded)
end

local function breatheBulls()
	local camera = workspace.CurrentCamera
	local now = os.clock()
	for model, bull in bulls do
		if bull.head.Parent == nil then
			bulls[model] = nil
			continue
		end
		local humanoid = bull.humanoid
		if now >= bull.nextBreath and (humanoid == nil or humanoid.Health > 0) then
			bull.nextBreath = now + random:NextNumber(3, 5.5)
			if camera and (camera.CFrame.Position - bull.head.Position).Magnitude < 70 then
				breathe(bull.head)
			end
		end
	end
end

-- A blast of air from `position` (a shockwave): capes within `radius` fly
-- away from it, more the closer they are.
function KitLooks.gust(position: Vector3, strength: number, radius: number)
	for _, cloth in cloths do
		local offset = cloth.torso.Position - position
		local distance = offset.Magnitude
		if distance < radius then
			local direction = if distance > 0.5
				then offset.Unit
				else cloth.torso.CFrame.LookVector * -1
			direction = (direction + Vector3.new(0, 0.35, 0)).Unit
			cloth.gust += direction * strength * (1 - distance / radius)
		end
	end
end

-- The tips of the Bull's horns (empty if he has none).
function KitLooks.hornTips(model: Model): { BasePart }
	local found: { BasePart } = {}
	local head = model:FindFirstChild("Head")
	local look = head and head:FindFirstChild("KitLook")
	if look then
		for _, part in look:GetChildren() do
			if part.Name == "HornTip" and part:IsA("BasePart") then
				table.insert(found, part)
			end
		end
	end
	return found
end

function KitLooks.start()
	-- (fighters, and the bodies a finisher left: Server/Systems/Corpses)
	for _, tag in { Config.Combat.TAG, Config.Combat.CORPSE_TAG } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
		for _, model in CollectionService:GetTagged(tag) do
			watch(model)
		end
	end
	RunService.RenderStepped:Connect(updateCloths)
	RunService.Heartbeat:Connect(breatheBulls)
end

return KitLooks
