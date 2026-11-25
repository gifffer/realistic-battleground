--!strict
-- BenchVisual: the extraction scene on the lab trolley, on the extractor's screen only.
--
-- The finished shell lies on the trolley (on its back, head toward +X of the bench anchor).
-- Its chest is closed by two pale PANELS meeting on a seam (no wound, no anatomy). A home-made
-- hot-wire CUTTER (parts: a taped soldering-iron handle, a steel fork, a thin wire) sleeps on
-- its charger at the CutterDock. Under the panels: a cavity lined with milky gel, and 4–6
-- stylised BIO-ELEMENTS (CoreModel.element) each in its own gel nest. Beside the head: a
-- small steel rack of open capsules (one per slot). Everything inside is milky / teal /
-- amber / violet, never red.
--
-- ExtractionController drives it (its own clock, events from its timeline table):
--   setCutter(cframe?)    the cutter in the hand (nil = asleep in its dock); setWire(heat 0..1)
--   setHand(cframe?, grip) the gloved hand (worn yellow-grey dish glove) — handAt() aims it
--   cut(t)                the seam 0..1 (neck → waist): glows dull amber behind the tip, then
--                         cools to a dark scorched line in 0.6 s and STAYS; returns the tip
--   wisp()                one thin cold vapour wisp at the tip (call every 0.1 s while cutting)
--   openPanels(t)         the panels unfold 0..1 (Quad Out by the caller); breath() = the heavy
--                         cold mist spilling out when they open
--   lightUp(index)        an element's inner light comes on (the 80 ms stagger is the caller's)
--   hover(index?)         one Highlight on the hovered element (moved, never one per element)
--   lift(index, t)        held: it rises (0.15 stud) and trembles, 3 milky strands stretch
--   letGo(index)          let go early: it sinks back, the strands shrink back
--   release(index, slot)  the soft pop (mist puff), strands shrink back in 0.2 s, the element
--                         glides 0.35 s into capsule `slot`, the cap drops 0.25 s (step() does
--                         it; events "Landed", "Crumble", "Sealed", "Frost" come out of
--                         takeEvents(), so the sounds play on the frame they belong to)
--   seal(slot, grade?, inert)  the server's answer: grade light + frost ring (when the cap is
--                         down; earlier answers wait for it)
--   closePanels(t)        the outro: panels fold back, leftovers dim and sink
--   chuteRoot / place / fade / destroy  as before (the shell slides into the chute)
-- A husk lifts with no resistance and crumbles to 8 dry beige flakes in its capsule (they stay).
-- A ruptured element leaves a milky pool in its nest and 2–3 beads on its way (they stay).
--
-- Effects (roblox-vfx rules: Rate 0 + Emit bursts, built-in smoke texture, lit by the room,
-- fade in and out, never a pop): ≤ 3 emitters (cold vapour Box, seal-ring Disc, tip wisps),
-- 3 Beams (strands, reused), 1 Highlight, all destroyed with the scene.
--
-- Space: the shell is built STANDING (like CloneModel: feet y -2.5, chest = -Z) and laid
-- down by `root` (lyingRoot). "Out of the cavity" is body -Z (world up once lying).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local CloneModel = require(script.Parent.CloneModel)
local CoreModel = require(script.Parent.CoreModel)
local Parts = require(script.Parent.Parts)

local BenchVisual = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local COLORS = CloneModel.COLORS
local LINING = rgb(118, 136, 128) -- wet grey-green gel lining (never a white tray)
local CAVITY_FLOOR = rgb(86, 104, 98)
local NEST_GEL = rgb(190, 198, 172)
local GLOVE = rgb(178, 170, 122) -- a worn yellow-grey dish glove
local GLOVE_CUFF = rgb(150, 142, 100)
local GLOVE_WORN = rgb(140, 132, 96)
local SEAM_HOT = rgb(255, 150, 70)
local SEAM_COLD = rgb(40, 34, 30)
local WIRE_HOT = rgb(200, 240, 235)
local WIRE_COLD = rgb(120, 122, 124)
local VAPOUR = rgb(236, 244, 248)
local VAPOUR_DEEP = rgb(205, 220, 228)
local HUSK_FLAKE = rgb(160, 150, 132)
local STEEL = rgb(150, 154, 158)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- built in, no upload
local GRAVITY = 30 -- studs/s² (real gravity at 1 stud = 0.28 m: things don't float)
local HAND_SCALE = 0.6
local HAND_SIDE_ANGLE = 40 -- degrees: the hand comes in from the screen's side

-- The torso's middle (standing space), the chest surface depth and the opening.
local TORSO = Vector3.new(0, 0.5, 0)
local CHEST_Z = -0.5
local OPENING = 1.2 -- the chest opening (square), y -0.1 .. 1.1
local FLOOR_Z = CHEST_Z + 0.64
local SEAM_TOP = 1.1 -- neck end of the seam (body Y)
local SEAM_BOTTOM = -0.1 -- waist end
local SEAM_PIECES = 12
local SEAM_COOL = 0.6 -- seconds from amber to scorched
local PANEL_OPEN = math.rad(170) -- (at 150° the near panel hid the bottom row)
local ELEMENT_SCALE = 0.7
local CAPSULE_SCALE = 0.55 -- the element's size inside a capsule
local LIFT_HEIGHT = 0.45 -- (high enough to read as a lift from the camera)
local GLIDE_TIME = 0.35
local CAP_TIME = 0.25
local STRAND_BACK = 0.2
-- Capsule rack slots (bench anchor space): on the trolley top beside the shell's head, on the
-- camera's side, in the lower-left of the close-up. (Not on the far side: the shell's arm lies
-- there. The lab keeps anchor x 1.2..2.95, z -1.35..-0.45 clear on the trolley top for them.)
local RACK =
	{ Vector3.new(1.45, 0.62, -1.1), Vector3.new(2.1, 0.62, -1.1), Vector3.new(2.7, 0.62, -0.7) }
-- Nest layouts (body space x, y offsets from the torso's middle) for 4, 5 and 6 elements:
-- a little irregular, never a perfect grid.
local LAYOUTS: { [number]: { Vector2 } } = {
	[4] = {
		Vector2.new(-0.28, -0.3),
		Vector2.new(0.3, -0.26),
		Vector2.new(-0.3, 0.28),
		Vector2.new(0.27, 0.31),
	},
	[5] = {
		Vector2.new(-0.3, -0.37),
		Vector2.new(0.29, -0.39),
		Vector2.new(0.03, 0.0),
		Vector2.new(-0.29, 0.37),
		Vector2.new(0.3, 0.35),
	},
	[6] = {
		Vector2.new(-0.29, -0.38),
		Vector2.new(0.31, -0.37),
		Vector2.new(-0.3, 0.01),
		Vector2.new(0.28, -0.02),
		Vector2.new(-0.27, 0.38),
		Vector2.new(0.3, 0.39),
	},
}
local YAW_JITTER = { 6, -9, 4, -5, 11, -3 } -- degrees, per nest

-- Standing space → lying on the bench: the body's up (+Y) runs along the bench (+X), the
-- chest (-Z) faces up (+Y).
local LYING = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(1, 0, 0))

-- The extraction camera: steeply down over the open chest from the room's camera side
-- (-Z of the anchor). The cavity sits right of centre (about a third of the width), the
-- capsule rack lower left. FOV 40.
BenchVisual.CAMERA_FOV = 40
function BenchVisual.cameraCFrame(anchor: CFrame): CFrame
	local target = anchor * Vector3.new(0.9, 0.5, -0.1)
	local position = anchor * Vector3.new(0.6, 3.4, -1.8)
	return CFrame.lookAt(position, target, anchor.UpVector)
end

function BenchVisual.lyingRoot(anchor: CFrame): CFrame
	-- (back on the trolley top, the torso's middle over the anchor)
	return anchor * CFrame.new(-0.5, 0.5, 0) * LYING
end

type Element = {
	model: Model,
	kind: string,
	condition: string,
	nest: CFrame, -- body space (the shell's root)
	state: "Nest" | "Held" | "Glide" | "Sealed",
	lift: number, -- 0..1 (shown)
	lit: boolean,
	glideFrom: CFrame?,
	glideStart: number,
	slot: number,
	pool: BasePart?,
	trail: number, -- beads dropped on the way (ruptured)
	sink: number, -- outro: 0..1
}

type Capsule = {
	model: Model,
	at: CFrame,
	cap: number, -- 1 = open .. 0 = shut
	closing: number?, -- clock when the cap started to drop
	sealed: boolean,
	answer: { grade: string?, inert: boolean }?, -- the server's, applied once sealed
	answered: boolean,
}

type Falling = {
	part: BasePart,
	position: Vector3,
	velocity: Vector3,
	floorY: number,
	landed: boolean,
	rest: Vector3?, -- once landed on the shell: in the shell's root space (it follows it)
	onShell: boolean,
	flat: Vector3, -- its size once landed
}

export type Bench = {
	anchor: CFrame,
	root: CFrame,
	folder: Folder,
	rig: Parts.Rig,
	panels: { BasePart },
	seam: { { part: BasePart, side: number, y: number, at: number? } },
	panelOpen: number,
	elements: { Element },
	capsules: { Capsule },
	highlight: Highlight,
	hovered: number?,
	strandBase: BasePart,
	strandTip: BasePart,
	beams: { Beam },
	strandsFor: number?, -- element index the strands hang from
	strandsBack: number?, -- clock when they started shrinking back
	cutter: Parts.Rig,
	cutterParts: { BasePart },
	wire: BasePart,
	wireLight: PointLight,
	cord: { BasePart },
	dock: CFrame,
	cutterAt: CFrame?, -- nil = in the dock
	hand: Parts.Rig,
	handParts: { BasePart },
	handShown: boolean,
	vapourSource: BasePart,
	vapour: ParticleEmitter,
	mistSource: BasePart,
	mist: ParticleEmitter,
	tipSource: BasePart,
	wisps: ParticleEmitter,
	falling: { Falling },
	events: { { name: string, slot: number } },
	random: Random,
	visible: number,
	fadeBase: { [BasePart]: number }?,
}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeIn(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * x
end

local function easeOut(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

------------------------------------------------------------------------------
-- Emitters (built-in smoke texture, bursts only)
------------------------------------------------------------------------------

-- Cold vapour: heavier than air, it spills, slows (Drag) and sinks; soft, matte, lit by
-- the room (not a glow), fades in and out.
local function vapourEmitter(parent: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "ColdVapour"
	emitter.Texture = SMOKE_TEXTURE
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(VAPOUR, VAPOUR_DEEP)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.4, 0.55, 0.1),
		NumberSequenceKeypoint.new(1, 0.9, 0.15),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.6),
		NumberSequenceKeypoint.new(0.5, 0.78),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1.0, 1.6)
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Drag = 3
	emitter.Acceleration = Vector3.new(0, -0.8, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-20, 20)
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.ZOffset = 0.2
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = parent
	return emitter
end

-- The thin ring of cold mist at a capsule's cap seam (one burst when the grade light comes on).
local function mistEmitter(parent: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SealMist"
	emitter.Texture = SMOKE_TEXTURE
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(VAPOUR)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 0.3, 0.05),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.6, 0.9)
	emitter.Speed = NumberRange.new(0.2, 0.5)
	emitter.Drag = 4
	emitter.Acceleration = Vector3.new(0, -0.6, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.ZOffset = 0.1
	emitter.Shape = Enum.ParticleEmitterShape.Disc
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.ShapePartial = 0.85
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = parent
	return emitter
end

-- Thin wisps at the cutter's tip (the hot wire meeting the cold shell).
local function wispEmitter(parent: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "TipWisps"
	emitter.Texture = SMOKE_TEXTURE
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(VAPOUR)
	emitter.Size = NumberSequence.new(0.15, 0.5)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.6, 0.9)
	emitter.Speed = NumberRange.new(0.2, 0.5)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Drag = 2
	emitter.Acceleration = Vector3.new(0, 0.3, 0) -- (warm at the wire: a wisp rises a little)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-25, 25)
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.ZOffset = 0.15
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = parent
	return emitter
end

------------------------------------------------------------------------------
-- Tools: the gloved hand and the cutter (local frames: the tip at the origin)
------------------------------------------------------------------------------

local function buildHand(folder: Folder): (Parts.Rig, { BasePart })
	local rig = Parts.newRig()
	local list: { BasePart } = {}
	local function piece(name: string, size: Vector3, at: CFrame, color: Color3)
		local part = Parts.part({
			Name = name,
			Size = size * HAND_SCALE,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.06,
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
			CFrame.new(x, 0.07, 0.17) * CFrame.Angles(math.rad(-10), 0, 0),
			if index == 2 then GLOVE_WORN else GLOVE -- (a worn, darker fingertip)
		)
	end
	piece(
		"Thumb",
		Vector3.new(0.1, 0.09, 0.28),
		CFrame.new(-0.3, 0.1, 0.45) * CFrame.Angles(0, math.rad(-35), 0),
		GLOVE
	)
	piece("Cuff", Vector3.new(0.42, 0.27, 0.36), CFrame.new(0, 0.22, 0.93), GLOVE_CUFF)
	return rig, list
end

-- The SEAM CUTTER: a taped soldering-iron handle, a small steel fork, a thin wire between
-- the fork tips (the tip = the wire's middle, at the origin; the handle runs along +Z).
local function buildCutter(folder: Folder): (Parts.Rig, { BasePart }, BasePart, PointLight)
	local rig = Parts.newRig()
	local list: { BasePart } = {}
	local function add(part: BasePart, at: CFrame)
		part.Parent = folder
		Parts.add(rig, part, at)
		table.insert(list, part)
	end
	-- the fork: two prongs from the tips back to the tape
	for _, side in { -1, 1 } do
		local tip = Vector3.new(side * 0.075, 0, 0)
		local base = Vector3.new(side * 0.035, 0.03, 0.3)
		local prong, at = Parts.rod(tip, base, 0.028, {
			Name = "Prong",
			Material = Enum.Material.Metal,
			Color = rgb(168, 170, 172),
			Reflectance = 0.25,
		})
		add(prong, at)
	end
	local wire, wireAt = Parts.rod(Vector3.new(-0.075, 0, 0), Vector3.new(0.075, 0, 0), 0.018, {
		Name = "Wire",
		Material = Enum.Material.Metal,
		Color = WIRE_COLD,
	})
	add(wire, wireAt)
	local tape = Parts.part({
		Name = "Tape",
		Size = Vector3.new(0.13, 0.11, 0.1),
		Material = Enum.Material.Fabric,
		Color = rgb(122, 122, 116),
	})
	add(tape, CFrame.new(0, 0.03, 0.33))
	local handle, handleAt =
		Parts.rod(Vector3.new(0, 0.03, 0.36), Vector3.new(0, 0.03, 0.9), 0.11, {
			Name = "Handle",
			Color = rgb(26, 26, 28),
			Reflectance = 0.05,
		})
	add(handle, handleAt)
	for k = 1, 3 do
		local rib = Parts.disc(0.125, 0.025, { Name = "Grip", Color = rgb(44, 44, 46) })
		add(rib, CFrame.new(0, 0.03, 0.5 + k * 0.09) * CFrame.Angles(0, math.rad(90), 0))
	end
	local light = Instance.new("PointLight")
	light.Name = "WireGlow"
	light.Color = WIRE_HOT
	light.Range = 2
	light.Brightness = 0
	light.Shadows = false
	light.Enabled = false
	light.Parent = wire
	return rig, list, wire, light
end

-- Where the cutter sleeps: flat on its charger, handle toward the camera side.
local function dockRest(dock: CFrame): CFrame
	return dock * CFrame.new(0, 0.07, 0) * CFrame.Angles(0, math.rad(-60), 0)
end

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

local function track(bench: Bench, part: BasePart, localCFrame: CFrame)
	Parts.add(bench.rig, part, localCFrame)
end

local function panelCFrame(side: number, open: number): CFrame
	local angle = PANEL_OPEN * math.clamp(open, 0, 1)
	return CFrame.new(side * OPENING / 2, TORSO.Y, CHEST_Z - 0.025)
		* CFrame.Angles(0, -side * angle, 0)
		* CFrame.new(-side * OPENING / 4, 0, 0)
end

function BenchVisual.new(
	anchor: CFrame,
	parent: Instance,
	elements: { Types.ExtractElement },
	slots: number,
	dock: CFrame?
): Bench
	local folder = Instance.new("Folder")
	folder.Name = "BenchVisual"
	local highlight = Instance.new("Highlight")
	highlight.Name = "Hover"
	highlight.FillTransparency = 1
	highlight.OutlineColor = rgb(200, 240, 232)
	highlight.OutlineTransparency = 0.15
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = folder
	local cutter, cutterParts, wire, wireLight = buildCutter(folder)
	local hand, handParts = buildHand(folder)
	local bench: Bench = {
		anchor = anchor,
		root = BenchVisual.lyingRoot(anchor),
		folder = folder,
		rig = Parts.newRig(),
		panels = {},
		seam = {},
		panelOpen = 0,
		elements = {},
		capsules = {},
		highlight = highlight,
		hovered = nil,
		strandBase = nil :: any,
		strandTip = nil :: any,
		beams = {},
		strandsFor = nil,
		strandsBack = nil,
		cutter = cutter,
		cutterParts = cutterParts,
		wire = wire,
		wireLight = wireLight,
		cord = {},
		dock = dock or anchor * CFrame.new(3, 0.15, 1.1),
		cutterAt = nil,
		hand = hand,
		handParts = handParts,
		handShown = false,
		vapourSource = nil :: any,
		vapour = nil :: any,
		mistSource = nil :: any,
		mist = nil :: any,
		tipSource = nil :: any,
		wisps = nil :: any,
		falling = {},
		events = {},
		random = Random.new(),
		visible = 1,
		fadeBase = nil,
	}

	-- The shell (SHELL look, chest open under the panels).
	CloneModel.buildShell(bench.rig, folder, true)

	-- Cavity: a dark wet lining on the floor and the 4 inner walls.
	local half = OPENING / 2
	local depth = 0.64
	track(
		bench,
		Parts.part({
			Name = "CavityFloor",
			Size = Vector3.new(OPENING, OPENING, 0.02),
			Color = CAVITY_FLOOR,
			Reflectance = 0.25,
			Parent = folder,
		}),
		CFrame.new(TORSO.X, TORSO.Y, FLOOR_Z - 0.01)
	)
	for _, side in { -1, 1 } do
		track(
			bench,
			Parts.part({
				Name = "Lining",
				Size = Vector3.new(0.01, OPENING, depth),
				Color = LINING,
				Reflectance = 0.35,
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
				Reflectance = 0.35,
				Parent = folder,
			}),
			CFrame.new(0, TORSO.Y + side * (half - 0.006), CHEST_Z + depth / 2)
		)
	end

	-- The two chest panels and the seam pieces on their meeting edges (they move with them).
	for _, side in { -1, 1 } do
		local panel = Parts.part({
			Name = "ChestPanel",
			Size = Vector3.new(OPENING / 2, OPENING, 0.05),
			Color = COLORS.pearl,
			Reflectance = 0.15,
			Parent = folder,
		})
		track(bench, panel, panelCFrame(side, 0))
		table.insert(bench.panels, panel)
	end
	for k = 1, SEAM_PIECES do
		local y = SEAM_TOP + (SEAM_BOTTOM - SEAM_TOP) * (k - 0.5) / SEAM_PIECES
		for _, side in { -1, 1 } do
			local piece = Parts.part({
				Name = "Seam",
				Size = Vector3.new(0.022, (SEAM_TOP - SEAM_BOTTOM) / SEAM_PIECES + 0.01, 0.012),
				Material = Enum.Material.Neon,
				Color = SEAM_HOT,
				Transparency = 1,
				Parent = folder,
			})
			track(
				bench,
				piece,
				panelCFrame(side, 0)
					* CFrame.new(-side * (OPENING / 4 - 0.011), y - TORSO.Y, -0.031)
			)
			table.insert(bench.seam, { part = piece, side = side, y = y, at = nil })
		end
	end

	-- Nests and elements.
	local layout = LAYOUTS[math.clamp(#elements, 4, 6)] or LAYOUTS[6]
	for index, info in elements do
		local offset = layout[math.min(index, #layout)]
		local at = Vector3.new(offset.X, TORSO.Y + offset.Y, FLOOR_Z - 0.13)
		local yaw = math.rad(90 + (YAW_JITTER[index] or 0))
		local nest = CFrame.new(at) * CFrame.Angles(0, 0, yaw)
		track(
			bench,
			Parts.ellipsoid(Vector3.new(0.5, 0.34, 0.1), {
				Name = "Nest",
				Color = NEST_GEL,
				Transparency = 0.45,
				Reflectance = 0.2,
				Parent = folder,
			}),
			CFrame.new(at.X, at.Y, FLOOR_Z - 0.04) * CFrame.Angles(0, 0, yaw)
		)
		-- (a husk takes the silhouette of one of the real kinds, by its index)
		local shapes = { "Cluster", "Pod", "Coil" }
		local model = CoreModel.element(
			info.kind,
			info.condition,
			ELEMENT_SCALE,
			nil,
			shapes[(index % 3) + 1]
		)
		model.Parent = folder
		local record: Element = {
			model = model,
			kind = info.kind :: string,
			condition = info.condition :: string,
			nest = nest,
			state = "Nest",
			lift = 0,
			lit = false,
			glideFrom = nil,
			glideStart = 0,
			slot = 0,
			pool = nil,
			trail = 0,
			sink = 0,
		}
		table.insert(bench.elements, record)
	end

	-- The capsule rack: a steel ring holder per slot, an open capsule in it.
	for slot = 1, math.clamp(slots, 1, #RACK) do
		local at = anchor * CFrame.new(RACK[slot])
		local holder = Parts.disc(0.6, 0.18, {
			Name = "RackHolder",
			Material = Enum.Material.Metal,
			Color = STEEL,
			Reflectance = 0.15,
			CFrame = anchor * CFrame.new(RACK[slot].X, 0.09, RACK[slot].Z) * Parts.UPRIGHT,
			Parent = folder,
		})
		holder:SetAttribute("Rack", true)
		local capsule = CoreModel.capsule(nil, at, true)
		capsule.Parent = folder
		CoreModel.setCapOpen(capsule, 1)
		table.insert(bench.capsules, {
			model = capsule,
			at = at,
			cap = 1,
			closing = nil,
			sealed = false,
			answer = nil,
			answered = false,
		})
	end

	-- Strands: two invisible carrier parts with 3 attachments each, 3 milky Beams.
	local function carrier(name: string): BasePart
		local part = Parts.part({
			Name = name,
			Size = Vector3.new(0.05, 0.05, 0.05),
			Transparency = 1,
			CFrame = anchor,
			Parent = folder,
		})
		for k = 1, 3 do
			local attachment = Instance.new("Attachment")
			attachment.Name = `A{k}`
			local a = math.rad(k * 120)
			attachment.Position = Vector3.new(math.cos(a) * 0.06, 0, math.sin(a) * 0.06)
			attachment.Parent = part
		end
		return part
	end
	bench.strandBase = carrier("StrandBase")
	bench.strandTip = carrier("StrandTip")
	for k = 1, 3 do
		local beam = Instance.new("Beam")
		beam.Name = "Strand"
		beam.Attachment0 = bench.strandBase:FindFirstChild(`A{k}`) :: Attachment
		beam.Attachment1 = bench.strandTip:FindFirstChild(`A{k}`) :: Attachment
		beam.Color = ColorSequence.new(COLORS.gel)
		beam.Transparency = NumberSequence.new(0.3, 0.8)
		beam.Width0 = 0.03
		beam.Width1 = 0.01
		beam.CurveSize0 = 0.05 * (if k == 2 then -1 else 1)
		beam.CurveSize1 = -0.04
		beam.Segments = 8
		beam.FaceCamera = true
		beam.LightEmission = 0
		beam.LightInfluence = 1
		beam.Enabled = false
		beam.Parent = bench.strandBase
		table.insert(bench.beams, beam)
	end

	-- Emitters on small invisible parts (Box / Disc shapes need a part parent).
	local vapourSource = Parts.part({
		Name = "VapourSource",
		Size = Vector3.new(0.7, 0.05, 0.7),
		Transparency = 1,
		CFrame = anchor,
		Parent = folder,
	})
	bench.vapourSource = vapourSource
	bench.vapour = vapourEmitter(vapourSource)
	local mistSource = Parts.part({
		Name = "SealMistSource",
		Size = Vector3.new(0.5, 0.05, 0.5),
		Transparency = 1,
		CFrame = anchor,
		Parent = folder,
	})
	bench.mistSource = mistSource
	bench.mist = mistEmitter(mistSource)
	local tipSource = Parts.part({
		Name = "TipSource",
		Size = Vector3.new(0.05, 0.05, 0.05),
		Transparency = 1,
		CFrame = anchor,
		Parent = folder,
	})
	bench.tipSource = tipSource
	bench.wisps = wispEmitter(tipSource)

	-- The cutter's coiled cord: a chain of small dark rods (placed every frame).
	for _ = 1, 8 do
		table.insert(
			bench.cord,
			Parts.part({
				Name = "Cord",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.1, 0.035, 0.035),
				Color = rgb(30, 30, 32),
				Parent = folder,
			})
		)
	end

	folder.Parent = parent
	BenchVisual.place(bench, bench.root)
	BenchVisual.setCutter(bench, nil)
	return bench
end

------------------------------------------------------------------------------
-- Tools
------------------------------------------------------------------------------

local function placeCord(bench: Bench)
	local from = (bench.cutterAt or dockRest(bench.dock)) * Vector3.new(0, 0.03, 0.92)
	local to = bench.dock * Vector3.new(0.2, 0, 0.15)
	local floorY = bench.anchor.Position.Y + 0.02
	local sag = 0.15 + 0.08 * (to - from).Magnitude
	local count = #bench.cord
	local previous = from
	local cframes = table.create(count)
	for k = 1, count do
		local f = k / count
		local point = from:Lerp(to, f) - Vector3.new(0, sag * 4 * f * (1 - f), 0)
		point = Vector3.new(point.X, math.max(point.Y, floorY), point.Z)
		local length = (point - previous).Magnitude
		bench.cord[k].Size = Vector3.new(math.max(length + 0.02, 0.04), 0.035, 0.035)
		cframes[k] = Parts.between(previous, point)
		previous = point
	end
	workspace:BulkMoveTo(bench.cord, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

-- The cutter in the hand at `cframe` (world, tip = wire middle), or nil = asleep in its dock.
function BenchVisual.setCutter(bench: Bench, cframe: CFrame?)
	bench.cutterAt = cframe
	Parts.place(bench.cutter, cframe or dockRest(bench.dock))
	placeCord(bench)
end

-- The cutter's rest pose in its dock (world), for the controller's reach / return glides.
function BenchVisual.dockCFrame(bench: Bench): CFrame
	return dockRest(bench.dock)
end

-- The wire's heat: 0 = cold grey .. 1 = cold white-teal Neon with a small light.
function BenchVisual.setWire(bench: Bench, heat: number)
	local h = math.clamp(heat, 0, 1)
	bench.wire.Material = if h > 0.05 then Enum.Material.Neon else Enum.Material.Metal
	bench.wire.Color = WIRE_COLD:Lerp(WIRE_HOT, h)
	bench.wireLight.Enabled = h > 0.05 and bench.visible > 0.5
	bench.wireLight.Brightness = 0.6 * h
end

-- The gloved hand at `cframe` (world; its fingers along -Z), or hidden (nil).
function BenchVisual.setHand(bench: Bench, cframe: CFrame?, seeThrough: boolean?)
	local shown = cframe ~= nil and bench.visible > 0.5
	local value = if not shown then 1 elseif seeThrough then 0.35 else 0
	for _, part in bench.handParts do
		if part.Transparency ~= value then
			part.Transparency = value
		end
	end
	bench.handShown = shown
	if cframe then
		Parts.place(bench.hand, cframe)
	end
end

-- Where the hand goes to work at `at` (world): it comes in from the bottom-right of the
-- screen, the wrist about 40° to the side (never covering what it works on).
function BenchVisual.handAt(bench: Bench, at: Vector3, camera: CFrame, pressing: boolean): CFrame
	local up = bench.anchor.UpVector
	local toCamera = camera.Position - at
	toCamera -= up * toCamera:Dot(up)
	local back = if toCamera.Magnitude > 1e-3 then toCamera.Unit else -bench.anchor.LookVector
	local side = camera.RightVector - up * camera.RightVector:Dot(up)
	side = if side.Magnitude > 1e-3 then side.Unit else bench.anchor.RightVector
	local angle = math.rad(HAND_SIDE_ANGLE)
	local from = (back * math.cos(angle) + side * math.sin(angle)).Unit
	local grip = at + side * (if pressing then 0.2 else 0) + up * (if pressing then 0.03 else 0.14)
	return CFrame.lookAt(grip, grip - from, up)
end

-- The hand holding the cutter (by its handle).
function BenchVisual.handOnCutter(cutter: CFrame): CFrame
	return cutter * CFrame.new(0, 0.1, 0.68) * CFrame.Angles(0, math.rad(180), 0)
end

------------------------------------------------------------------------------
-- The cut
------------------------------------------------------------------------------

-- The tip's world point at seam progress t (0 = neck, 1 = waist).
function BenchVisual.seamPoint(bench: Bench, t: number): Vector3
	local y = SEAM_TOP + (SEAM_BOTTOM - SEAM_TOP) * math.clamp(t, 0, 1)
	return bench.root * Vector3.new(0, y, CHEST_Z - 0.04)
end

-- The cutter's pose at seam progress t: the wire on the seam, the handle up and back toward
-- the camera (about 40°).
function BenchVisual.cutterPose(bench: Bench, t: number, camera: CFrame): CFrame
	local at = BenchVisual.seamPoint(bench, t)
	local up = bench.anchor.UpVector
	local toCamera = camera.Position - at
	toCamera -= up * toCamera:Dot(up)
	local back = if toCamera.Magnitude > 1e-3 then toCamera.Unit else -bench.anchor.LookVector
	return CFrame.lookAt(at, at - back, up) * CFrame.Angles(math.rad(-40), 0, 0)
end

-- The seam up to t: pieces light up (dull amber) as the tip passes, then cool (step()).
function BenchVisual.cut(bench: Bench, t: number): Vector3
	local y = SEAM_TOP + (SEAM_BOTTOM - SEAM_TOP) * math.clamp(t, 0, 1)
	local now = os.clock()
	for _, piece in bench.seam do
		if piece.at == nil and piece.y >= y then
			piece.at = now
		end
	end
	local tip = BenchVisual.seamPoint(bench, t)
	bench.tipSource.CFrame = CFrame.new(tip) * bench.anchor.Rotation
	return tip
end

-- One thin cold wisp at the tip (the caller emits every 0.1 s while cutting).
function BenchVisual.wisp(bench: Bench)
	if bench.visible > 0 then
		bench.wisps:Emit(bench.random:NextInteger(1, 2))
	end
end

-- A burst of cold vapour over a square around `at` (world).
local function puffAt(bench: Bench, at: Vector3, count: number, spread: number, slow: boolean?)
	if bench.visible <= 0 then
		return
	end
	local source = bench.vapourSource
	source.Size = Vector3.new(spread * 2, 0.05, spread * 2)
	source.CFrame = CFrame.new(at) * bench.anchor.Rotation
	bench.vapour.Speed = if slow then NumberRange.new(0.2, 0.5) else NumberRange.new(0.4, 1.2)
	bench.vapour:Emit(count)
end

-- The panels unfold (0 = shut .. 1 = open).
function BenchVisual.openPanels(bench: Bench, t: number)
	bench.panelOpen = math.clamp(t, 0, 1)
	for i, panel in bench.panels do
		local side = if i == 1 then -1 else 1
		Parts.setLocal(bench.rig, panel, panelCFrame(side, bench.panelOpen))
	end
	for _, piece in bench.seam do
		Parts.setLocal(
			bench.rig,
			piece.part,
			panelCFrame(piece.side, bench.panelOpen)
				* CFrame.new(-piece.side * (OPENING / 4 - 0.011), piece.y - TORSO.Y, -0.031)
		)
	end
end

-- The heavy cold breath spilling out of the opened chest.
function BenchVisual.breath(bench: Bench)
	puffAt(bench, bench.root * Vector3.new(TORSO.X, TORSO.Y, CHEST_Z - 0.1), 10, 0.45)
end

------------------------------------------------------------------------------
-- Elements
------------------------------------------------------------------------------

function BenchVisual.lightUp(bench: Bench, index: number)
	local element = bench.elements[index]
	if element then
		element.lit = true
	end
end

-- World point of element `index` (where the pointer aims).
function BenchVisual.elementPoint(bench: Bench, index: number): Vector3
	local element = bench.elements[index]
	if element == nil then
		return bench.root.Position
	end
	return element.model.WorldPivot.Position
end

function BenchVisual.elementCount(bench: Bench): number
	return #bench.elements
end

-- Can element `index` still be picked (in its nest)?
function BenchVisual.isFree(bench: Bench, index: number): boolean
	local element = bench.elements[index]
	return element ~= nil and (element.state == "Nest" or element.state == "Held")
end

function BenchVisual.hover(bench: Bench, index: number?)
	if bench.hovered == index then
		return
	end
	bench.hovered = index
	local element = if index then bench.elements[index] else nil
	if element and element.state ~= "Sealed" then
		bench.highlight.Adornee = element.model
		bench.highlight.Enabled = true
	else
		bench.highlight.Enabled = false
		bench.highlight.Adornee = nil
	end
end

local function strandsOn(bench: Bench, index: number?)
	bench.strandsFor = index
	bench.strandsBack = nil
	for _, beam in bench.beams do
		beam.Enabled = index ~= nil and bench.visible > 0.5
	end
end

-- Held: t 0..1 of the hold. Real elements rise against resistance with strands; a husk
-- comes up at once, dry, no strands.
function BenchVisual.lift(bench: Bench, index: number, t: number)
	local element = bench.elements[index]
	if element == nil or (element.state ~= "Nest" and element.state ~= "Held") then
		return
	end
	if element.state == "Nest" then
		element.state = "Held"
		if element.kind ~= "Husk" then
			strandsOn(bench, index)
		end
		if element.condition == "Ruptured" and element.pool == nil then
			-- milky gel seeps into its nest: a flat pool that grows (step()) and STAYS
			local pool = Parts.disc(0.05, 0.012, {
				Name = "GelPool",
				Color = COLORS.gel,
				Transparency = 0.2,
				Reflectance = 0.3,
				Parent = bench.folder,
			})
			pool:SetAttribute("Born", os.clock())
			element.pool = pool
		end
	end
	element.lift = if element.kind == "Husk" then smooth(t * 3) else easeOut(t)
end

-- Let go before the release: it sinks back into its nest, the strands shrink back.
function BenchVisual.letGo(bench: Bench, index: number)
	local element = bench.elements[index]
	if element == nil or element.state ~= "Held" then
		return
	end
	element.state = "Nest"
	if bench.strandsFor == index then
		bench.strandsBack = os.clock()
	end
end

-- The release: a soft pop of cold mist, the strands shrink back, the element glides into
-- capsule `slot`.
function BenchVisual.release(bench: Bench, index: number, slot: number)
	local element = bench.elements[index]
	local capsule = bench.capsules[slot]
	if
		element == nil
		or capsule == nil
		or element.state == "Glide"
		or element.state == "Sealed"
	then
		return
	end
	if bench.hovered == index then
		BenchVisual.hover(bench, nil)
	end
	element.state = "Glide"
	element.slot = slot
	element.glideFrom = element.model.WorldPivot
	element.glideStart = os.clock()
	if bench.strandsFor == index then
		bench.strandsBack = os.clock()
	end
	if element.kind ~= "Husk" then
		puffAt(bench, element.model.WorldPivot.Position, 4, 0.12, true)
	end
end

-- The server's answer for capsule `slot` (applied once the cap is down).
function BenchVisual.seal(bench: Bench, slot: number, grade: string?, inert: boolean)
	local capsule = bench.capsules[slot]
	if capsule and not capsule.answered then
		capsule.answer = { grade = grade, inert = inert }
	end
end

-- Has the cap of every slot that was used come down (the outro can start)?
function BenchVisual.isSettled(bench: Bench): boolean
	for _, element in bench.elements do
		if element.state == "Glide" then
			return false
		end
	end
	for _, capsule in bench.capsules do
		if capsule.closing and not capsule.sealed then
			return false
		end
	end
	return true
end

-- Events since the last call ("Landed", "Crumble", "Sealed", "Frost" with their slot).
function BenchVisual.takeEvents(bench: Bench): { { name: string, slot: number } }
	local list = bench.events
	bench.events = {}
	return list
end

-- Outro: t 0..1, the panels fold back over the cavity, the leftovers dim and sink.
function BenchVisual.closePanels(bench: Bench, t: number)
	BenchVisual.openPanels(bench, 1 - smooth(t))
	for _, element in bench.elements do
		if element.state == "Nest" or element.state == "Held" then
			element.state = "Nest"
			element.lift = 0
			element.lit = false
			element.sink = math.max(element.sink, smooth(t))
		end
	end
	if t > 0 then
		BenchVisual.hover(bench, nil)
		if bench.strandsFor then
			bench.strandsBack = bench.strandsBack or os.clock()
		end
	end
end

------------------------------------------------------------------------------
-- Falling bits (ruptured beads, husk flakes): real gravity, they land and STAY
------------------------------------------------------------------------------

-- The height (world Y) something falling at `point` lands on: the shell's body or the trolley.
local function groundAt(bench: Bench, point: Vector3): (number, boolean)
	local p = bench.anchor:PointToObjectSpace(point)
	local top = bench.anchor.Position.Y
	if p.X >= -3 and p.X <= 1.0 and math.abs(p.Z) <= 2 then
		return top + 1.0, true -- (chest, arms, legs: 1 stud thick lying down)
	elseif p.X > 1.0 and p.X <= 2.2 and math.abs(p.Z) <= 0.58 then
		return top + 1.08, true -- (the head)
	end
	return top + 0.01, false
end

local function drop(bench: Bench, part: BasePart, at: Vector3, floorY: number?, flat: Vector3)
	local ground, onShell = groundAt(bench, at)
	table.insert(bench.falling, {
		part = part,
		position = at,
		velocity = Vector3.new(
			bench.random:NextNumber(-0.3, 0.3),
			0.2,
			bench.random:NextNumber(-0.3, 0.3)
		),
		floorY = floorY or ground,
		landed = false,
		rest = nil,
		onShell = floorY == nil and onShell,
		flat = flat,
	})
end

-- A milky bead falling from `at` (ruptured element on its way).
local function bead(bench: Bench, at: Vector3)
	local d = bench.random:NextNumber(0.05, 0.08)
	local part = Parts.ellipsoid(Vector3.new(d, d, d), {
		Name = "Bead",
		Color = COLORS.gel,
		Transparency = 0.15,
		Reflectance = 0.25,
		CFrame = CFrame.new(at),
		Parent = bench.folder,
	})
	drop(bench, part, at, nil, Vector3.new(d * 1.6, d * 0.35, d * 1.6))
end

-- 8 dry beige flakes falling into a capsule (a husk crumbling).
local function crumble(bench: Bench, at: Vector3, capsule: Capsule)
	local bottom = (capsule.at * Vector3.new(0, -0.42, 0)).Y
	for _ = 1, 8 do
		local size = Vector3.new(
			bench.random:NextNumber(0.04, 0.08),
			0.04,
			bench.random:NextNumber(0.05, 0.09)
		)
		local part = Instance.new("WedgePart")
		part.Name = "Flake"
		part.Size = size
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Sand
		part.Color = HUSK_FLAKE
		local start = at
			+ Vector3.new(
				bench.random:NextNumber(-0.08, 0.08),
				0,
				bench.random:NextNumber(-0.08, 0.08)
			)
		part.CFrame = CFrame.new(start)
		part.Parent = bench.folder
		local fallen = {
			part = part :: BasePart,
			position = start,
			velocity = Vector3.new(
				bench.random:NextNumber(-0.2, 0.2),
				0,
				bench.random:NextNumber(-0.2, 0.2)
			),
			floorY = bottom + bench.random:NextNumber(0, 0.05),
			landed = false,
			rest = nil,
			onShell = false,
			flat = size,
		}
		table.insert(bench.falling, fallen)
	end
end

------------------------------------------------------------------------------
-- Placing and per-frame
------------------------------------------------------------------------------

-- Moves the shell and everything in its nests to `root` (call every frame).
function BenchVisual.place(bench: Bench, root: CFrame)
	bench.root = root
	Parts.place(bench.rig, root)
	local now = os.clock()
	for index, element in bench.elements do
		if element.state == "Nest" or element.state == "Held" then
			local rise = LIFT_HEIGHT * element.lift
			-- (held: a small tremble, stronger as the strands strain)
			local shake = Vector3.zero
			if element.state == "Held" and element.kind ~= "Husk" then
				local k = 0.012 * element.lift
				shake =
					Vector3.new(math.noise(now * 13, index) * k, math.noise(index, now * 11) * k, 0)
			end
			local sinkBy = 0.1 * element.sink
			element.model:PivotTo(
				root * CFrame.new(shake + Vector3.new(0, 0, -rise + sinkBy)) * element.nest
			)
		end
	end
end

function BenchVisual.step(bench: Bench, dt: number, now: number)
	-- Seam: amber behind the tip, then it cools to a dark scorched line that stays.
	for _, piece in bench.seam do
		local at = piece.at
		if at then
			local cool = math.clamp((now - at) / SEAM_COOL, 0, 1)
			local part = piece.part
			if cool < 1 then
				part.Material = Enum.Material.Neon
				part.Color = SEAM_HOT:Lerp(SEAM_COLD, smooth(cool))
			elseif part.Material ~= Enum.Material.SmoothPlastic then
				part.Material = Enum.Material.SmoothPlastic
				part.Color = SEAM_COLD
			end
			local wanted = Parts.fade(0, bench.visible)
			if part.Transparency ~= wanted then
				part.Transparency = wanted
			end
		end
	end

	-- Elements: breathing lights, gliding into their capsule.
	for _, element in bench.elements do
		if element.state == "Nest" and element.lift > 0 then
			-- (let go early: it settles back into its nest, it doesn't snap)
			element.lift = math.max(0, element.lift - dt * 4)
		end
		if element.state == "Glide" then
			local capsule = bench.capsules[element.slot]
			local from = element.glideFrom
			if capsule == nil or from == nil then
				element.state = "Sealed"
				continue
			end
			local t = (now - element.glideStart) / GLIDE_TIME
			local goal = capsule.at * CFrame.new(0, -0.03, 0)
			local over = capsule.at * CFrame.new(0, 0.75, 0)
			local s = smooth(t)
			local position = from.Position:Lerp(over.Position, s)
				+ Vector3.new(0, math.sin(s * math.pi) * 0.3, 0)
			if t >= 0.85 then
				position = over.Position:Lerp(goal.Position, smooth((t - 0.85) / 0.15))
			end
			local rotation = from.Rotation:Lerp(goal.Rotation, s)
			local scale = 1 + (CAPSULE_SCALE / ELEMENT_SCALE - 1) * s
			element.model:ScaleTo(scale)
			element.model:PivotTo(CFrame.new(position) * rotation)
			-- a ruptured one leaves 2–3 milky beads on its way
			if
				element.condition == "Ruptured"
				and element.trail < 3
				and s > (element.trail + 1) * 0.22
			then
				element.trail += 1
				bead(bench, position)
			end
			if t >= 1 then
				element.state = "Sealed"
				element.model:PivotTo(goal)
				capsule.closing = now
				table.insert(bench.events, { name = "Landed", slot = element.slot })
				if element.kind == "Husk" then
					-- it crumbles to dry flakes in the capsule (they stay)
					crumble(bench, goal.Position + Vector3.new(0, 0.1, 0), capsule)
					element.model:Destroy()
					table.insert(bench.events, { name = "Crumble", slot = element.slot })
				else
					element.model.Parent = capsule.model
				end
			end
		elseif element.state ~= "Sealed" then
			local lit = element.lit and bench.visible > 0.5
			CoreModel.animate(element.model, now, lit)
		end
		-- the milky pool of a ruptured element grows in its nest (and stays)
		local pool = element.pool
		if pool then
			local born = pool:GetAttribute("Born")
			local grow = if typeof(born) == "number" then smooth((now - born) / 1.0) else 1
			local d = 0.05 + 0.27 * grow
			if math.abs(pool.Size.Y - d) > 1e-3 then
				pool.Size = Vector3.new(0.012, d, d)
			end
			local nest = bench.root
				* CFrame.new(element.nest.Position.X, element.nest.Position.Y, FLOOR_Z - 0.06)
			pool.CFrame = nest * CFrame.Angles(0, math.rad(90), 0)
		end
	end

	-- Capsule caps: drop (spring-loaded: accelerating, ease-in) once the element is in.
	for slot, capsule in bench.capsules do
		local closing = capsule.closing
		if closing and not capsule.sealed then
			local t = (now - closing) / CAP_TIME
			capsule.cap = 1 - easeIn(t)
			CoreModel.setCapOpen(capsule.model, capsule.cap)
			if t >= 1 then
				capsule.sealed = true
				table.insert(bench.events, { name = "Sealed", slot = slot })
				puffAt(bench, capsule.at.Position + Vector3.new(0, 0.5, 0), 3, 0.12, true)
			end
		end
		local answer = capsule.answer
		if capsule.sealed and answer and not capsule.answered then
			capsule.answered = true
			CoreModel.setGradeLight(capsule.model, answer.grade, answer.inert)
			local tube = capsule.model:FindFirstChild("Tube")
			if tube and tube:IsA("BasePart") then
				tube.Color = rgb(236, 244, 248) -- frosted
				tube.Transparency = 0.4
			end
			if not answer.inert and bench.visible > 0 then
				bench.mistSource.CFrame = capsule.at * CFrame.new(0, 0.45, 0)
				bench.mist:Emit(10)
			end
			table.insert(bench.events, { name = "Frost", slot = slot })
		end
		if capsule.sealed then
			CoreModel.animate(capsule.model, now, bench.visible > 0.5)
		end
	end

	-- Strands: from the nest to the held element; shrinking back after a release / let go.
	local index = bench.strandsFor
	if index then
		local element = bench.elements[index]
		local base = bench.root
			* CFrame.new(element.nest.Position.X, element.nest.Position.Y, FLOOR_Z - 0.08)
		local tip = element.model.WorldPivot
		local back = bench.strandsBack
		if back then
			local t = (now - back) / STRAND_BACK
			-- (they shrink back into the nest, thinning, no snapping flash)
			tip = CFrame.new(tip.Position:Lerp(base.Position, smooth(t)))
			if t >= 1 then
				strandsOn(bench, nil)
			end
		end
		bench.strandBase.CFrame = base
		bench.strandTip.CFrame = CFrame.new(tip.Position) * base.Rotation
		local stretch = (tip.Position - base.Position).Magnitude
		for _, beam in bench.beams do
			beam.Width0 = math.clamp(0.035 - stretch * 0.05, 0.012, 0.035)
		end
	end

	-- Falling bits: real gravity, they land and stay (on the shell they follow it).
	for _, item in bench.falling do
		local position: Vector3
		if item.landed then
			local rest = item.rest
			position = if rest then bench.root * rest else item.position
		else
			item.velocity += Vector3.new(0, -GRAVITY, 0) * dt
			position = item.position + item.velocity * dt
			if position.Y <= item.floorY then
				position = Vector3.new(position.X, item.floorY, position.Z)
				item.landed = true
				item.part.Size = item.flat
				if item.onShell then
					item.rest = bench.root:PointToObjectSpace(position)
				end
			end
		end
		item.position = position
		item.part.CFrame = CFrame.new(position)
	end
end

-- The shell's root along the chute path, t 0..1: lift a little, glide head first to the
-- chute mouth, slide in (fade it out with fade()).
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

-- Fades the whole scene (0 = gone, 1 = as designed). `onlyShell`: the capsule rack and what
-- was sealed stay (the shell goes into the chute first).
function BenchVisual.fade(bench: Bench, visible: number, onlyShell: boolean?)
	bench.visible = math.clamp(visible, 0, 1)
	local base = bench.fadeBase
	if base == nil then
		-- (the first fade: remember every part's own transparency once)
		local made: { [BasePart]: number } = {}
		for _, descendant in bench.folder:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 then
				made[descendant] = descendant.Transparency
			end
		end
		bench.fadeBase = made
		base = made
	end
	for part, own in base :: { [BasePart]: number } do
		if part.Parent == nil then
			continue
		end
		if onlyShell then
			local inRack = part:FindFirstAncestor("Capsule") ~= nil
				or part:GetAttribute("Rack") == true
				or part.Name == "Flake"
			if inRack then
				continue
			end
		end
		part.Transparency = Parts.fade(own, bench.visible)
	end
	local stencil = bench.folder:FindFirstChild("Text", true)
	if stencil and stencil:IsA("TextLabel") then
		stencil.TextTransparency = 1 - bench.visible
	end
	if bench.visible <= 0.5 then
		bench.highlight.Enabled = false
		for _, beam in bench.beams do
			beam.Enabled = false
		end
		bench.wireLight.Enabled = false
	end
	if bench.visible <= 0 then
		bench.vapour:Clear()
		bench.mist:Clear()
		bench.wisps:Clear()
	end
end

function BenchVisual.destroy(bench: Bench)
	bench.folder:Destroy()
end

return BenchVisual
