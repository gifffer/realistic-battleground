--!strict
-- BenchVisual: the extraction scene on the lab bench, on the extractor's screen only.
--
-- The finished shell lies on the steel bench (on its back, head toward +X of the bench
-- anchor). Its chest is a sealed port, not a wound: a steel HATCH with two port CLAMPS, under
-- it a milky MEMBRANE, under that a cavity lined with pale gel, a soft cradle, the BIO-CORE
-- and 6 glowing FIBRE GUIDES holding it. Beside the head: an open capsule in a steel holder.
-- Everything inside is milky / teal / amber, never red. No organs, no anatomy.
--
-- The 6 gestures move pieces of this scene (ExtractionController drives them):
--   1 UNLOCK  setClamp(i, turn 0..1), setClampUnlocked(i)   (LED teal → amber)
--   2 OPEN    setHatch(open 0..1), puff()                  (cold vapour)
--   3 SPREAD  setSpread(0..1)                               (the membrane parts)
--   4 CUT     setFibres(correct, cut, active), cut(i)       (fibre snaps, milky droplets)
--   5 LIFT    setLift(0..1)                                 (the core rises from its cradle)
--   6 SEAL    setCoreWorld(cframe?), seal(t), reveal(grade) (into the capsule, frost)
-- Tools: showTool(name, at, camera, pressing): "Hand", "Hands" (spread), "Scalpel", nil.
--
-- Space: the shell is built STANDING (like CloneModel: feet y -2.5, chest = -Z) and laid
-- down by `root`. BenchVisual.lyingRoot(anchor) is where it rests; ExtractionController
-- moves `root` from the vat to the bench (intro) and into the chute (outro) with place().
--
--   BenchVisual.new(anchor, parent)  → Bench
--   BenchVisual.place(bench, root)   (call every frame; also moves the core)
--   BenchVisual.step(bench, dt, now) (droplets, vapour, fibre flicker / snaps, tool)
--   BenchVisual.points(bench)        world points the gestures aim at
--   BenchVisual.chuteRoot(bench, chute, t)  the shell's root along the chute path (t 0..1)
--   BenchVisual.fade(bench, visible) (0 = gone)
--   BenchVisual.destroy(bench)

local CloneModel = require(script.Parent.CloneModel)
local CoreModel = require(script.Parent.CoreModel)
local Parts = require(script.Parent.Parts)

local BenchVisual = {}

type Item = { part: BasePart, base: number }

type Fibre = {
	inner: BasePart,
	outer: BasePart,
	a: Vector3, -- inner end (standing space)
	b: Vector3, -- outer end (rim)
	cutAt: number?, -- clock time of the cut (snap animation)
}

type Particle = {
	part: BasePart,
	active: boolean,
	position: Vector3,
	velocity: Vector3,
	age: number,
	life: number,
}

export type Points = {
	clamps: { Vector3 },
	hatch: Vector3, -- the middle of the hatch
	hatchEdge: Vector3, -- the middle of its free edge (the one you lift)
	membrane: Vector3,
	fibres: { { a: Vector3, b: Vector3 } },
	core: Vector3,
	capsule: Vector3, -- the capsule's open mouth
	plane: CFrame, -- the work plane: position on the chest surface, UpVector = its normal
}

export type Bench = {
	anchor: CFrame,
	root: CFrame,
	folder: Folder,
	rig: Parts.Rig,
	items: { Item },
	hatch: { BasePart },
	hatchLed: BasePart,
	clamps: { { knob: BasePart, lever: BasePart, led: BasePart, at: Vector3, turn: number } },
	membrane: { BasePart },
	strands: { BasePart },
	fibres: { Fibre },
	fibreCorrect: { [number]: boolean },
	fibreCut: { [number]: boolean },
	fibresActive: boolean,
	core: Model,
	coreLift: number,
	coreWorld: CFrame?, -- set while the core is dragged (seal)
	coreHidden: boolean,
	capsule: Model,
	capsuleAt: CFrame,
	sealed: boolean,
	frost: number,
	tools: { [string]: Parts.Rig },
	toolParts: { [string]: { BasePart } },
	shownTool: string?,
	droplets: { Particle },
	vapour: { Particle },
	random: Random,
	visible: number,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local COLORS = CloneModel.COLORS
local LINING = rgb(196, 210, 204) -- pale wet gel lining
local CAVITY_FLOOR = rgb(150, 176, 170)
local FIBRE = rgb(180, 238, 228)
local FIBRE_DEAD = rgb(214, 210, 196)
local FIBRE_DECOY = rgb(214, 228, 190) -- a decoy: a little warmer (easier to tell apart)
local FIBRE_WRONG = rgb(112, 114, 112) -- a decoy that was cut: dull grey
local STEEL = rgb(150, 154, 158)
local GLOVE = rgb(70, 110, 175) -- nitrile blue
local GLOVE_CUFF = rgb(52, 84, 140)
local HAND_SIDE_ANGLE = 40 -- degrees: the single hand comes in from the screen's right
local HAND_GRIP_OFFSET = 0.25 -- studs: a gripping hand holds things from the side
local VAPOUR = rgb(236, 244, 248)
local LED_LOCKED = rgb(150, 220, 230)
local LED_OPEN = rgb(255, 170, 70)
local HAND_SCALE = 0.6

-- The torso's middle (standing space) and the chest surface (front face) depth.
local TORSO = Vector3.new(0, 0.5, 0)
local CHEST_Z = -0.5
local OPENING = 1.2 -- the hatch hole (square)
local HINGE_X = -0.62 -- hatch hinge (the far edge once lying)
local CORE_REST = Vector3.new(0, 0.5, -0.1)
local CAPSULE_LOCAL = Vector3.new(1.75, 0.62, -1.12) -- in the BENCH ANCHOR's space (by the head)

-- Standing space → lying on the bench: the body's up (+Y) runs along the bench (+X), the
-- chest (-Z) faces up (+Y).
local LYING = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(1, 0, 0))

-- The extraction camera: a medium 45° shot from the room's door side (-Z of the anchor),
-- looking at the chest a little toward the head (the capsule stays in frame). FOV 50.
BenchVisual.CAMERA_FOV = 50
function BenchVisual.cameraCFrame(anchor: CFrame): CFrame
	local target = anchor * Vector3.new(0.45, 0.85, -0.35)
	local position = target + anchor.UpVector * 2.35 + anchor.LookVector * 1.9
	return CFrame.lookAt(position, target, anchor.UpVector)
end

function BenchVisual.lyingRoot(anchor: CFrame): CFrame
	-- (back on the bench top, the torso's middle over the anchor)
	return anchor * CFrame.new(-0.5, 0.5, 0) * LYING
end

local function track(bench: Bench, part: BasePart, localCFrame: CFrame)
	Parts.add(bench.rig, part, localCFrame)
	table.insert(bench.items, { part = part, base = part.Transparency })
end

local function hatchCFrame(open: number): CFrame
	local angle = math.rad(105) * math.clamp(open, 0, 1)
	return CFrame.new(HINGE_X, TORSO.Y, CHEST_Z - 0.03)
		* CFrame.Angles(0, angle, 0)
		* CFrame.new(-HINGE_X, 0, 0)
end

local function clampLever(at: Vector3, turn: number): CFrame
	return CFrame.new(at) * CFrame.Angles(0, 0, turn * math.pi / 2) * CFrame.new(-0.14, 0, -0.035)
end

------------------------------------------------------------------------------
-- Tools (gloved hand, scalpel). Local frames: the tip at the origin, "up" = away from the
-- work surface, fingers / blade toward -Z.
------------------------------------------------------------------------------

local function buildHand(folder: Folder, mirror: number): (Parts.Rig, { BasePart })
	local rig = Parts.newRig()
	local list: { BasePart } = {}
	-- (drawn at 0.6 scale: a full-size glove hides the small parts it works on)
	local function piece(name: string, size: Vector3, at: CFrame, color: Color3)
		local part = Parts.part({
			Name = name,
			Size = size * HAND_SCALE,
			Color = color,
			Reflectance = 0.12,
			Transparency = 1,
			Parent = folder,
		})
		Parts.add(rig, part, CFrame.new(at.Position * HAND_SCALE) * at.Rotation)
		table.insert(list, part)
	end
	piece("Palm", Vector3.new(0.5, 0.16, 0.5), CFrame.new(0, 0.14, 0.55), GLOVE)
	for index = 1, 4 do
		local x = -0.18 + (index - 1) * 0.12
		piece(
			"Finger",
			Vector3.new(0.1, 0.09, 0.34),
			CFrame.new(x * mirror, 0.07, 0.17) * CFrame.Angles(math.rad(-10), 0, 0),
			GLOVE
		)
	end
	piece(
		"Thumb",
		Vector3.new(0.1, 0.09, 0.28),
		CFrame.new(-0.3 * mirror, 0.1, 0.45) * CFrame.Angles(0, math.rad(-35 * mirror), 0),
		GLOVE
	)
	-- (a short cuff: a long one hid the clamp and the core from the camera)
	piece("Cuff", Vector3.new(0.4, 0.26, 0.36), CFrame.new(0, 0.22, 0.93), GLOVE_CUFF)
	return rig, list
end

local function buildScalpel(folder: Folder): (Parts.Rig, { BasePart })
	local rig = Parts.newRig()
	local list: { BasePart } = {}
	local blade = Parts.part({
		Name = "Blade",
		Size = Vector3.new(0.025, 0.09, 0.3),
		Material = Enum.Material.Metal,
		Color = rgb(205, 210, 215),
		Reflectance = 0.4,
		Transparency = 1,
		Parent = folder,
	})
	Parts.add(rig, blade, CFrame.new(0, 0.03, 0.15))
	table.insert(list, blade)
	local handle = Parts.part({
		Name = "Handle",
		Size = Vector3.new(0.06, 0.1, 0.8),
		Material = Enum.Material.Metal,
		Color = rgb(150, 155, 160),
		Reflectance = 0.25,
		Transparency = 1,
		Parent = folder,
	})
	Parts.add(rig, handle, CFrame.new(0, 0.05, 0.7))
	table.insert(list, handle)
	return rig, list
end

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

function BenchVisual.new(anchor: CFrame, parent: Instance): Bench
	local folder = Instance.new("Folder")
	folder.Name = "BenchVisual"
	local capsuleAt = anchor * CFrame.new(CAPSULE_LOCAL)
	local bench: Bench = {
		anchor = anchor,
		root = BenchVisual.lyingRoot(anchor),
		folder = folder,
		rig = Parts.newRig(),
		items = {},
		hatch = {},
		hatchLed = nil :: any,
		clamps = {},
		membrane = {},
		strands = {},
		fibres = {},
		fibreCorrect = {},
		fibreCut = {},
		fibresActive = false,
		core = CoreModel.core(nil, 1),
		coreLift = 0,
		coreWorld = nil,
		coreHidden = false,
		capsule = CoreModel.capsule(nil, capsuleAt, true),
		capsuleAt = capsuleAt,
		sealed = false,
		frost = 0,
		tools = {},
		toolParts = {},
		shownTool = nil,
		droplets = {},
		vapour = {},
		random = Random.new(),
		visible = 1,
	}

	-- The shell itself (the SHELL look with an open chest).
	for _, item in CloneModel.buildShell(bench.rig, folder, true) do
		table.insert(bench.items, item)
	end

	-- Cavity: a pale wet lining on the floor and the 4 inner walls.
	local half = OPENING / 2
	local depth = 0.64
	local floorZ = CHEST_Z + depth
	track(
		bench,
		Parts.part({
			Name = "CavityFloor",
			Size = Vector3.new(OPENING, OPENING, 0.02),
			Color = CAVITY_FLOOR,
			Reflectance = 0.25,
			Parent = folder,
		}),
		CFrame.new(TORSO.X, TORSO.Y, floorZ - 0.01)
	)
	for _, side in { -1, 1 } do
		track(
			bench,
			Parts.part({
				Name = "Lining",
				Size = Vector3.new(0.01, OPENING, depth),
				Color = LINING,
				Reflectance = 0.2,
				Parent = folder,
			}),
			CFrame.new(side * (half - 0.006), TORSO.Y, CHEST_Z + depth / 2)
		)
		track(
			bench,
			Parts.part({
				Name = "Lining",
				Size = Vector3.new(OPENING, 0.01, depth),
				Color = LINING,
				Reflectance = 0.2,
				Parent = folder,
			}),
			CFrame.new(0, TORSO.Y + side * (half - 0.006), CHEST_Z + depth / 2)
		)
	end
	-- The cradle: a soft milky cushion and a ring of gel beads around the core.
	track(
		bench,
		Parts.ellipsoid(Vector3.new(0.8, 0.8, 0.18), {
			Name = "Cradle",
			Color = COLORS.gel,
			Transparency = 0.2,
			Reflectance = 0.15,
			Parent = folder,
		}),
		CFrame.new(TORSO.X, TORSO.Y, floorZ - 0.08)
	)
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		track(
			bench,
			Parts.ball(0.15, {
				Name = "CradleBead",
				Color = COLORS.gel,
				Transparency = 0.25,
				Reflectance = 0.2,
				Parent = folder,
			}),
			CFrame.new(math.cos(a) * 0.28, TORSO.Y + math.sin(a) * 0.28, floorZ - 0.16)
		)
	end

	-- 6 fibre guides from the core out to the rim (each = 2 halves, so a cut can snap).
	for k = 1, 6 do
		local angle = math.rad(30 + (k - 1) * 60)
		local direction = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local a = CORE_REST + direction * 0.17 + Vector3.new(0, 0, -0.02)
		local b = TORSO + direction * 0.57 + Vector3.new(0, 0, CHEST_Z + 0.07)
		local middle = (a + b) / 2
		local inner, innerCFrame = Parts.rod(a, middle, 0.035, {
			Name = "Fibre",
			Material = Enum.Material.Neon,
			Color = FIBRE,
			Transparency = 0.6,
			Parent = folder,
		})
		local outer, outerCFrame = Parts.rod(middle, b, 0.035, {
			Name = "Fibre",
			Material = Enum.Material.Neon,
			Color = FIBRE,
			Transparency = 0.6,
			Parent = folder,
		})
		track(bench, inner, innerCFrame)
		track(bench, outer, outerCFrame)
		table.insert(bench.fibres, { inner = inner, outer = outer, a = a, b = b, cutAt = nil })
	end

	-- The membrane: two milky halves just under the hatch, and 3 strands between them.
	-- (the halves part along the body's length: left / right on the screen)
	for _, side in { -1, 1 } do
		local part = Parts.part({
			Name = "Membrane",
			Size = Vector3.new(OPENING, half, 0.02),
			Color = COLORS.gel,
			Transparency = 0.3,
			Reflectance = 0.2,
			Parent = folder,
		})
		track(bench, part, CFrame.new(0, TORSO.Y + side * half / 2, CHEST_Z + 0.06))
		table.insert(bench.membrane, part)
	end
	for _, dx in { -0.35, 0, 0.35 } do
		local part = Parts.part({
			Name = "Strand",
			Size = Vector3.new(0.025, 0.05, 0.025),
			Color = COLORS.gel,
			Transparency = 1,
			Parent = folder,
		})
		track(bench, part, CFrame.new(dx, TORSO.Y, CHEST_Z + 0.06))
		table.insert(bench.strands, part)
	end

	-- The hatch: a steel plate with a grip on its free edge and a status LED.
	local plate = Parts.part({
		Name = "Hatch",
		Size = Vector3.new(OPENING + 0.04, OPENING + 0.04, 0.06),
		Material = Enum.Material.Metal,
		Color = COLORS.port,
		Reflectance = 0.1,
		Parent = folder,
	})
	track(bench, plate, hatchCFrame(0))
	table.insert(bench.hatch, plate)
	local grip = Parts.part({
		Name = "HatchGrip",
		Size = Vector3.new(0.08, 0.5, 0.06),
		Material = Enum.Material.Metal,
		Color = rgb(96, 98, 102),
		Parent = folder,
	})
	track(bench, grip, hatchCFrame(0) * CFrame.new(0.5, 0, -0.05))
	table.insert(bench.hatch, grip)
	local hatchLed = Parts.ball(0.07, {
		Name = "HatchLed",
		Material = Enum.Material.Neon,
		Color = LED_LOCKED,
		Parent = folder,
	})
	track(bench, hatchLed, hatchCFrame(0) * CFrame.new(-0.42, 0.45, -0.04))
	table.insert(bench.hatch, hatchLed)
	bench.hatchLed = hatchLed

	-- 2 port clamps on the near wall strip (lying: the camera side), with their LED.
	for _, y in { 0.05, 0.95 } do
		local at = Vector3.new(0.8, y, CHEST_Z - 0.04)
		local knob = Parts.disc(0.24, 0.08, {
			Name = "ClampKnob",
			Material = Enum.Material.Metal,
			Color = rgb(176, 180, 186),
			Reflectance = 0.2,
			Parent = folder,
		})
		track(bench, knob, CFrame.new(at) * CFrame.Angles(0, math.rad(90), 0))
		local lever = Parts.part({
			Name = "ClampLever",
			Size = Vector3.new(0.34, 0.07, 0.05),
			Material = Enum.Material.Metal,
			Color = rgb(120, 124, 130),
			Reflectance = 0.2,
			Parent = folder,
		})
		track(bench, lever, clampLever(at, 0))
		local led = Parts.ball(0.06, {
			Name = "ClampLed",
			Material = Enum.Material.Neon,
			Color = LED_LOCKED,
			Transparency = 0.2,
			Parent = folder,
		})
		track(bench, led, CFrame.new(at + Vector3.new(0.13, 0.17, 0.01)))
		table.insert(bench.clamps, { knob = knob, lever = lever, led = led, at = at, turn = 0 })
	end

	-- The capsule's steel holder beside the head, the capsule open in it.
	local holder = Parts.disc(0.62, 0.22, {
		Name = "CapsuleHolder",
		Material = Enum.Material.Metal,
		Color = STEEL,
		Reflectance = 0.15,
		Parent = folder,
	})
	holder.CFrame = anchor * CFrame.new(CAPSULE_LOCAL.X, 0.11, CAPSULE_LOCAL.Z) * Parts.UPRIGHT
	table.insert(bench.items, { part = holder, base = 0 })
	bench.capsule.Parent = folder
	CoreModel.setCapOpen(bench.capsule, 1)

	-- The core in its cradle.
	bench.core.Parent = folder

	-- Tools (hidden until shown).
	local handRig, handParts = buildHand(folder, 1)
	bench.tools.Hand = handRig
	bench.toolParts.Hand = handParts
	local leftRig, leftParts = buildHand(folder, -1)
	bench.tools.LeftHand = leftRig
	bench.toolParts.LeftHand = leftParts
	local scalpelRig, scalpelParts = buildScalpel(folder)
	bench.tools.Scalpel = scalpelRig
	bench.toolParts.Scalpel = scalpelParts

	-- Particle pools (milky droplets, cold vapour).
	for _ = 1, 14 do
		local part = Parts.ball(0.06, {
			Name = "Droplet",
			Color = COLORS.gel,
			Transparency = 1,
			Reflectance = 0.25,
			Parent = folder,
		})
		table.insert(bench.droplets, {
			part = part,
			active = false,
			position = Vector3.zero,
			velocity = Vector3.zero,
			age = 0,
			life = 1,
		})
	end
	for _ = 1, 12 do
		local part = Parts.ball(0.3, {
			Name = "Vapour",
			Color = VAPOUR,
			Transparency = 1,
			Parent = folder,
		})
		table.insert(bench.vapour, {
			part = part,
			active = false,
			position = Vector3.zero,
			velocity = Vector3.zero,
			age = 0,
			life = 1.4,
		})
	end

	folder.Parent = parent
	BenchVisual.place(bench, bench.root)
	return bench
end

------------------------------------------------------------------------------
-- Gesture states
------------------------------------------------------------------------------

function BenchVisual.setClamp(bench: Bench, index: number, turn: number)
	local clamp = bench.clamps[index]
	if clamp == nil then
		return
	end
	clamp.turn = math.clamp(turn, 0, 1.4)
	Parts.setLocal(bench.rig, clamp.lever, clampLever(clamp.at, clamp.turn))
end

function BenchVisual.setClampUnlocked(bench: Bench, index: number, unlocked: boolean)
	local clamp = bench.clamps[index]
	if clamp == nil then
		return
	end
	clamp.led.Color = if unlocked then LED_OPEN else LED_LOCKED
	if unlocked then
		BenchVisual.setClamp(bench, index, 1)
	end
	local all = true
	for _, other in bench.clamps do
		if other.led.Color ~= LED_OPEN then
			all = false
		end
	end
	bench.hatchLed.Color = if all then LED_OPEN else LED_LOCKED
end

function BenchVisual.setHatch(bench: Bench, open: number)
	local cframe = hatchCFrame(open)
	Parts.setLocal(bench.rig, bench.hatch[1], cframe)
	Parts.setLocal(bench.rig, bench.hatch[2], cframe * CFrame.new(0.5, 0, -0.05))
	Parts.setLocal(bench.rig, bench.hatch[3], cframe * CFrame.new(-0.42, 0.45, -0.04))
end

-- The membrane halves slide apart toward the walls, the strands stretch and give.
function BenchVisual.setSpread(bench: Bench, spread: number)
	local s = math.clamp(spread, 0, 1)
	local half = OPENING / 2
	local width = half - 0.48 * s
	for i, part in bench.membrane do
		local side = if i == 1 then -1 else 1
		part.Size = Vector3.new(OPENING, width, 0.02)
		Parts.setLocal(
			bench.rig,
			part,
			CFrame.new(0, TORSO.Y + side * (half - width / 2), CHEST_Z + 0.06)
		)
		part.Transparency = Parts.fade(0.3 + 0.25 * s, bench.visible)
	end
	local gap = 2 * (half - width)
	for k, strand in bench.strands do
		local alive = s > 0.04 and s < 0.62 + k * 0.04
		local thin = 0.028 * (1 - s / 0.75)
		strand.Size = Vector3.new(math.max(thin, 0.008), math.max(gap, 0.05), math.max(thin, 0.008))
		strand.Transparency = if alive then Parts.fade(0.25, bench.visible) else 1
	end
end

-- Which fibres glow (correct = steady, decoys flicker in step()) and which are cut.
function BenchVisual.setFibres(bench: Bench, correct: { number }, cut: { number }, active: boolean)
	table.clear(bench.fibreCorrect)
	for _, i in correct do
		bench.fibreCorrect[i] = true
	end
	for _, i in cut do
		if not bench.fibreCut[i] then
			BenchVisual.cut(bench, i, true, not bench.fibreCorrect[i])
		end
	end
	bench.fibresActive = active
end

local function puffAt(bench: Bench, at: Vector3, count: number, spread: number)
	local spawned = 0
	for _, puff in bench.vapour do
		if not puff.active and spawned < count then
			spawned += 1
			puff.active = true
			puff.age = 0
			puff.life = bench.random:NextNumber(1.1, 1.6)
			puff.position = at
				+ Vector3.new(
					bench.random:NextNumber(-spread, spread),
					0,
					bench.random:NextNumber(-spread, spread)
				)
			puff.velocity = Vector3.new(
				bench.random:NextNumber(-0.2, 0.2),
				bench.random:NextNumber(0.5, 0.9),
				0
			)
		end
	end
end

-- Snaps fibre `index` (quietly when `silent`: no droplets, e.g. a resync). `wrong`: a decoy
-- was cut: it turns dull grey with a puff instead of the clean white snap.
function BenchVisual.cut(bench: Bench, index: number, silent: boolean?, wrong: boolean?)
	local fibre = bench.fibres[index]
	if fibre == nil or bench.fibreCut[index] then
		return
	end
	bench.fibreCut[index] = true
	fibre.cutAt = if silent then -100 else os.clock()
	for _, part in { fibre.inner, fibre.outer } do
		part.Material = Enum.Material.SmoothPlastic
		part.Color = if wrong then FIBRE_WRONG else FIBRE_DEAD
		part.Transparency = Parts.fade(0.1, bench.visible)
	end
	if silent then
		return
	end
	if wrong then
		puffAt(bench, bench.root * ((fibre.a + fibre.b) / 2), 5, 0.2)
	end
	-- milky droplets from the cut point, falling into the cavity
	local middle = bench.root * ((fibre.a + fibre.b) / 2)
	local spawned = 0
	for _, drop in bench.droplets do
		if not drop.active and spawned < 4 then
			spawned += 1
			drop.active = true
			drop.age = 0
			drop.life = bench.random:NextNumber(1.2, 1.8)
			drop.position = middle
			drop.velocity = Vector3.new(
				bench.random:NextNumber(-0.5, 0.5),
				bench.random:NextNumber(0.2, 0.9),
				bench.random:NextNumber(-0.5, 0.5)
			)
			local d = bench.random:NextNumber(0.045, 0.08)
			drop.part.Size = Vector3.new(d, d, d)
			drop.part.Transparency = 0.15
		end
	end
end

function BenchVisual.setLift(bench: Bench, lift: number)
	bench.coreLift = math.clamp(lift, 0, 1)
end

-- While dragged (seal), the core follows `cframe` in world space; nil = back to its lift.
function BenchVisual.setCoreWorld(bench: Bench, cframe: CFrame?)
	bench.coreWorld = cframe
end

-- Cold vapour puffing out of the opening (hatch open, capsule frost).

function BenchVisual.puff(bench: Bench)
	puffAt(bench, bench.root * Vector3.new(TORSO.X, TORSO.Y, CHEST_Z - 0.1), 8, 0.35)
end

-- Seal: t 0 → 1, the core drops into the capsule, the cap closes, the glass frosts.
function BenchVisual.seal(bench: Bench, t: number)
	if not bench.sealed and t > 0 then
		bench.sealed = true
		bench.coreHidden = true
		local filled = CoreModel.capsule(nil, bench.capsuleAt)
		filled.Parent = bench.folder
		bench.capsule:Destroy()
		bench.capsule = filled
		puffAt(bench, bench.capsuleAt.Position + Vector3.new(0, 0.5, 0), 4, 0.15)
	end
	CoreModel.setCapOpen(bench.capsule, 1 - math.clamp(t * 1.6, 0, 1))
	bench.frost = math.clamp(t, 0, 1)
	local tube = bench.capsule:FindFirstChild("Tube")
	if tube and tube:IsA("BasePart") then
		tube.Transparency = 0.55 - 0.2 * bench.frost
		tube.Color = Color3.fromRGB(210, 225, 230):Lerp(Color3.fromRGB(236, 244, 248), bench.frost)
	end
end

-- After the server's verdict: the capsule shows the real core (grade colour).
function BenchVisual.reveal(bench: Bench, grade: CoreModel.Grade)
	local revealed = CoreModel.capsule(grade, bench.capsuleAt)
	revealed.Parent = bench.folder
	bench.capsule:Destroy()
	bench.capsule = revealed
	local tube = revealed:FindFirstChild("Tube")
	if tube and tube:IsA("BasePart") then
		tube.Transparency = 0.35
		tube.Color = Color3.fromRGB(236, 244, 248)
	end
end

------------------------------------------------------------------------------
-- Placing, tools, per-frame
------------------------------------------------------------------------------

local function coreCFrame(bench: Bench): CFrame
	local world = bench.coreWorld
	if world then
		return world
	end
	-- (eased lift: straight up out of the cradle, 1.1 stud above the chest at the end)
	local lift = bench.coreLift
	local eased = lift * lift * (3 - 2 * lift)
	local rest = CFrame.new(CORE_REST + Vector3.new(0, 0, -1.2 * eased))
	-- the core's long axis follows the body (standing Y)
	return bench.root * rest
end

function BenchVisual.place(bench: Bench, root: CFrame)
	bench.root = root
	Parts.place(bench.rig, root)
	if bench.coreHidden then
		bench.core:PivotTo(CFrame.new(0, -500, 0))
	else
		bench.core:PivotTo(coreCFrame(bench))
	end
end

-- Shows tool `name` ("Hand", "Hands", "Scalpel" or nil) with its tip at `at` (world), turned
-- so its handle / wrist points toward the camera. "Hands" puts two hands `apart` studs apart
-- along the bench's long axis (the spread).
function BenchVisual.showTool(
	bench: Bench,
	name: string?,
	at: Vector3,
	camera: CFrame,
	pressing: boolean,
	apart: number?
)
	local show: { [string]: boolean } = {}
	if name == "Hand" then
		show.Hand = true
	elseif name == "Hands" then
		show.Hand = true
		show.LeftHand = true
	elseif name == "Scalpel" then
		show.Scalpel = true
	end
	-- (a gripping glove is see-through: what it holds stays readable)
	local seeThrough = pressing and name == "Hand"
	for key, parts in bench.toolParts do
		local visible = show[key] == true and bench.visible > 0.5
		for _, part in parts do
			local value = if not visible then 1 elseif seeThrough and key == "Hand" then 0.35 else 0
			if part.Transparency ~= value then
				part.Transparency = value
			end
		end
	end
	bench.shownTool = name
	if name == nil then
		return
	end
	local up = bench.anchor.UpVector
	-- toward the camera, flat on the bench plane
	local toCamera = camera.Position - at
	toCamera -= up * toCamera:Dot(up)
	local back = if toCamera.Magnitude > 1e-3 then toCamera.Unit else -bench.anchor.LookVector
	local lower = if pressing then 0.02 else 0.12
	if name == "Scalpel" then
		-- blade down at the tip, handle up and back toward the camera (about 40°)
		local base = CFrame.lookAt(at, at - back, up) * CFrame.Angles(math.rad(-40), 0, 0)
		Parts.place(bench.tools.Scalpel, CFrame.new(up * lower) * base)
	else
		local along = bench.anchor.RightVector
		local d = (apart or 0) / 2
		if name == "Hands" then
			-- two hands, fingers toward each other's side, pushing the membrane apart
			Parts.place(
				bench.tools.Hand,
				CFrame.lookAt(at + along * d + up * lower, at + along * (d + 1) + up * lower, up)
					* CFrame.Angles(0, math.rad(180), 0)
			)
			Parts.place(
				bench.tools.LeftHand,
				CFrame.lookAt(at - along * d + up * lower, at - along * (d + 1) + up * lower, up)
					* CFrame.Angles(0, math.rad(180), 0)
			)
		else
			-- One hand comes in from the bottom-right of the screen (the wrist about 40° to the
			-- side, not along the view ray, so it never covers what it works on) and grips
			-- from the side.
			local side = camera.RightVector - up * camera.RightVector:Dot(up)
			side = if side.Magnitude > 1e-3 then side.Unit else bench.anchor.RightVector
			local angle = math.rad(HAND_SIDE_ANGLE)
			local from = (back * math.cos(angle) + side * math.sin(angle)).Unit
			local grip = at + side * (if pressing then HAND_GRIP_OFFSET else 0) + up * lower
			Parts.place(bench.tools.Hand, CFrame.lookAt(grip, grip - from, up))
		end
	end
end

function BenchVisual.step(bench: Bench, dt: number, now: number)
	-- Fibres: correct ones glow steady, decoys flicker dimmer; cut ones retract (0.3 s).
	for index, fibre in bench.fibres do
		local cutAt = fibre.cutAt
		if cutAt then
			local t = math.clamp((os.clock() - cutAt) / 0.3, 0, 1)
			local keep = 1 - 0.65 * t
			local middle = (fibre.a + fibre.b) / 2
			local innerEnd = fibre.a + (middle - fibre.a) * keep
			local outerStart = fibre.b + (middle - fibre.b) * keep
			fibre.inner.Size =
				Vector3.new(math.max((innerEnd - fibre.a).Magnitude, 0.03), 0.035, 0.035)
			fibre.outer.Size =
				Vector3.new(math.max((fibre.b - outerStart).Magnitude, 0.03), 0.035, 0.035)
			-- (the cut ends curl down a little into the cavity)
			local droop = Vector3.new(0, 0, 0.08 * t)
			Parts.setLocal(bench.rig, fibre.inner, Parts.between(fibre.a, innerEnd + droop))
			Parts.setLocal(bench.rig, fibre.outer, Parts.between(outerStart + droop, fibre.b))
		else
			local transparency = 0.6
			local color = FIBRE
			if bench.fibresActive then
				if bench.fibreCorrect[index] then
					transparency = 0.05 + 0.05 * math.sin(now * 3 + index)
				else
					-- a decoy: dimmer, a little warmer, and it flickers
					local flicker = math.noise(now * 7, index * 3.1)
					transparency = if flicker > 0.15 then 0.6 else 0.4
					color = FIBRE_DECOY
				end
			end
			local value = Parts.fade(transparency, bench.visible)
			fibre.inner.Transparency = value
			fibre.outer.Transparency = value
			fibre.inner.Color = color
			fibre.outer.Color = color
		end
	end

	-- Droplets: fall, rest on the cavity floor, fade.
	local floorY = (bench.root * Vector3.new(0, 0, CHEST_Z + 0.6)).Y
	local moved: { BasePart } = {}
	local cframes: { CFrame } = {}
	for _, drop in bench.droplets do
		if drop.active then
			drop.age += dt
			if drop.age >= drop.life then
				drop.active = false
				drop.part.Transparency = 1
			else
				drop.velocity += Vector3.new(0, -9, 0) * dt
				local position = drop.position + drop.velocity * dt
				if position.Y < floorY then
					position = Vector3.new(position.X, floorY, position.Z)
					drop.velocity = Vector3.zero
				end
				drop.position = position
				drop.part.Transparency = 0.15
					+ 0.85 * math.max(0, (drop.age - drop.life * 0.6) / (drop.life * 0.4))
				table.insert(moved, drop.part)
				table.insert(cframes, CFrame.new(position))
			end
		end
	end
	-- Vapour: rises, swells, thins out.
	for _, puff in bench.vapour do
		if puff.active then
			puff.age += dt
			local t = puff.age / puff.life
			if t >= 1 then
				puff.active = false
				puff.part.Transparency = 1
			else
				puff.position += puff.velocity * dt
				local d = 0.2 + 0.7 * t
				puff.part.Size = Vector3.new(d, d, d)
				puff.part.Transparency = 0.55 + 0.45 * t
				table.insert(moved, puff.part)
				table.insert(cframes, CFrame.new(puff.position))
			end
		end
	end
	if #moved > 0 then
		workspace:BulkMoveTo(moved, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- The core breathes; the sealed capsule too.
	CoreModel.animate(bench.core, now)
	CoreModel.animate(bench.capsule, now)
end

-- World points the gestures aim at (for projecting onto the screen).
function BenchVisual.points(bench: Bench): Points
	local root = bench.root
	local clamps = {}
	for _, clamp in bench.clamps do
		table.insert(clamps, root * clamp.at)
	end
	local fibres = {}
	for _, fibre in bench.fibres do
		table.insert(fibres, { a = root * fibre.a, b = root * fibre.b })
	end
	local hatch = root * Parts.getLocal(bench.rig, bench.hatch[1])
	return {
		clamps = clamps,
		hatch = hatch.Position,
		hatchEdge = (hatch * CFrame.new(0.6, 0, 0)).Position,
		membrane = root * Vector3.new(TORSO.X, TORSO.Y, CHEST_Z + 0.06),
		fibres = fibres,
		core = coreCFrame(bench).Position,
		capsule = (bench.capsuleAt * CFrame.new(0, 0.6, 0)).Position,
		plane = CFrame.fromMatrix(
			root * Vector3.new(TORSO.X, TORSO.Y, CHEST_Z),
			bench.anchor.RightVector,
			bench.anchor.UpVector
		),
	}
end

-- The shell's root along the chute path, t 0..1 (3 s in ExtractionController): lift a
-- little, glide head first to the chute mouth, slide in (fade it out with fade()).
function BenchVisual.chuteRoot(bench: Bench, chute: CFrame, t: number): CFrame
	local start = BenchVisual.lyingRoot(bench.anchor)
	local inward = chute.Position - start.Position
	inward = Vector3.new(inward.X, 0, inward.Z)
	inward = if inward.Magnitude > 1e-3 then inward.Unit else bench.anchor.RightVector
	-- the shell's middle sits ~2.6 studs behind its head: stop the head at the mouth
	local front = chute.Position - inward * 3.2 + Vector3.new(0, 0.1, 0)
	local inside = chute.Position + inward * 2.5 + Vector3.new(0, -0.4, 0)
	local raised = start.Position + Vector3.new(0, 0.35, 0)
	local rotation = start.Rotation
	local function smooth(x: number): number
		x = math.clamp(x, 0, 1)
		return x * x * (3 - 2 * x)
	end
	local position: Vector3
	if t < 0.15 then
		position = start.Position:Lerp(raised, smooth(t / 0.15))
	elseif t < 0.75 then
		position = raised:Lerp(front, smooth((t - 0.15) / 0.6))
	else
		position = front:Lerp(inside, smooth((t - 0.75) / 0.25))
	end
	return CFrame.new(position) * rotation
end

-- Fades the whole scene (0 = gone, 1 = as designed).
function BenchVisual.fade(bench: Bench, visible: number)
	bench.visible = math.clamp(visible, 0, 1)
	for _, item in bench.items do
		item.part.Transparency = Parts.fade(item.base, bench.visible)
	end
	for _, descendant in bench.core:GetDescendants() do
		if descendant:IsA("BasePart") and bench.visible <= 0 then
			descendant.Transparency = 1
		end
	end
	local stencil = bench.folder:FindFirstChild("Text", true)
	if stencil and stencil:IsA("TextLabel") then
		stencil.TextTransparency = 1 - bench.visible
	end
end

function BenchVisual.destroy(bench: Bench)
	bench.folder:Destroy()
end

return BenchVisual
