--!strict
-- BenchVisual: the shell on the lab trolley during an extraction, on the extractor's screen
-- only (v3: everything is done BY HAND; ExtractionController moves the hand and calls this).
--
-- The finished shell lies on its back on the trolley's underpad, head toward +X of the bench
-- anchor. Its chest is closed by two pale PANELS meeting on a seam; a faint dashed GUIDE runs
-- down the seam (no text, no wound, no anatomy). Under the panels: a cavity lined with milky
-- gel, and 4–6 stylised BIO-ELEMENTS (CoreModel.element), each in its own gel nest. Everything
-- inside is milky / teal / amber / violet, never red.
--
-- What the controller drives:
--   THE SEAM   12 cells, each cut 0..2 deep (1 = the synthetic skin: a thin dark split with a
--              cold teal light leaking from it, a milky bead every 2nd cell; 2 = the membrane:
--              the split widens, wet milky edges, a cold breath). Only where the blade
--              passes: cutCell(k, depth). Scratches off the seam stay (scratch).
--   THE PANELS setPanel(side, open, tremble): each opens on its outer hinge; clipFrame(side)
--              is where a retractor clip bites its rim.
--   ELEMENTS   in the nest (pulled by setPull), or free in the world (setFree: held, loose,
--              on the tray), or handed to the pass-box (takeModel). Strands stretch from the
--              nest while pulled, then thin, sag and retract (release); a milky drop falls
--              back into the nest and stays. A ruptured one leaves a pool in its nest and
--              beads on its way (bead), which land and STAY.
--   THE TRAY   runoff(): the element's gel coat drains into the tray's channel (it stays).
-- Persistence (art direction): the split, the glow (fading to 0.85, never to nothing), the
-- beads, the drops and the scratches stay until the shell goes down the chute.
--
-- Effects (roblox-vfx: Rate 0 + Emit bursts, built-in smoke texture, lit by the room, fade in
-- and out, never a pop): 1 vapour emitter (cold breath / release puff), 3 Beams (strands),
-- 1 Highlight (moved between targets), 1 small PointLight on the cut; all destroyed with the
-- scene. The pass-box (PassBox) has its own 2.
--
-- Space: the shell is built STANDING (like CloneModel: feet y -2.5, chest = -Z) and laid down
-- by `root` (lyingRoot). "Out of the cavity" is body -Z (world up once lying). Body X runs
-- across the chest (anchor Z), body Y along the body (anchor X).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BenchLayout = require(ReplicatedStorage.Shared.Contraband.BenchLayout)
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
local SPLIT = rgb(30, 36, 38)
local GLOW = rgb(120, 210, 200)
local GUIDE = rgb(190, 194, 190)
local MILK = rgb(226, 228, 214)
local SCRATCH = rgb(204, 204, 196)
local VAPOUR = rgb(236, 244, 248)
local VAPOUR_DEEP = rgb(205, 220, 228)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- built in, no upload
local GRAVITY = 30 -- studs/s² (real gravity at 1 stud = 0.28 m: things don't float)

-- The torso's middle (standing space), the chest surface depth and the opening.
local TORSO = Vector3.new(0, 0.5, 0)
local CHEST_Z = -0.5
local PANEL_Z = CHEST_Z - 0.025 -- the panels' middle (0.05 thick, on the chest)
local PANEL_FRONT = CHEST_Z - 0.05 -- the panels' outer face
local OPENING = 1.2 -- the chest opening (square), y -0.1 .. 1.1
local FLOOR_Z = CHEST_Z + 0.64
local SEAM_TOP = 1.1 -- neck end of the seam (body Y)
local SEAM_BOTTOM = -0.1 -- waist end
local CELLS = 12
local CELL = (SEAM_TOP - SEAM_BOTTOM) / CELLS
local PANEL_OPEN = math.rad(170) -- (at 150° the near panel hid the bottom row)
local ELEMENT_SCALE = 0.7
local MAX_SCRATCHES = 8
local GLOW_FADE = 3 -- s: the teal glow of a cut cell fades from 0.6 to 0.85 (never out)

BenchVisual.CELLS = CELLS
BenchVisual.ELEMENT_SCALE = ELEMENT_SCALE
BenchVisual.PANEL_OPEN = PANEL_OPEN

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

function BenchVisual.lyingRoot(anchor: CFrame): CFrame
	-- (on its back on the underpad, the torso's middle over the anchor)
	return anchor * CFrame.new(-0.5, 0.5 + BenchLayout.SHELL_LIFT, 0) * LYING
end

export type ElementMode = "Nest" | "Free" | "Gone"

type Element = {
	model: Model,
	kind: string,
	condition: string,
	nest: CFrame, -- body space (the shell's root)
	mode: ElementMode,
	pull: Vector3, -- world offset from the nest while pulled
	lit: boolean,
	pool: BasePart?,
	sink: number, -- outro: 0..1
	half: number, -- half its thickness lying down (studs)
	glossy: boolean,
}

type Cell = {
	depth: number,
	guide: BasePart,
	splits: { BasePart }, -- one per panel edge (side -1, +1)
	wets: { BasePart },
	glow: BasePart,
	cutAt: number?,
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
	sound: boolean,
}

export type Bench = {
	anchor: CFrame,
	root: CFrame,
	folder: Folder,
	rig: Parts.Rig,
	panels: { BasePart },
	panelOpen: { number },
	panelTremble: { number },
	cells: { Cell },
	scratches: number,
	riders: { { part: BasePart, side: number, at: CFrame } }, -- beads / scratches on a panel
	elements: { Element },
	highlight: Highlight,
	strandBase: BasePart,
	strandTip: BasePart,
	beams: { Beam },
	strandsFor: number?,
	strandsBack: number?, -- clock when they started to thin and retract
	strandStretch: number,
	vapourSource: BasePart,
	vapour: ParticleEmitter,
	cutLight: PointLight,
	runoff: BasePart?,
	runoffGrow: number,
	runoffBorn: number,
	falling: { Falling },
	landed: number, -- beads landed since the last takeLanded()
	random: Random,
	visible: number,
	fadeBase: { [BasePart]: number }?,
	kit: Model?, -- a fallback static kit (the lab had none)
}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

------------------------------------------------------------------------------
-- Emitter (built-in smoke texture, bursts only)
------------------------------------------------------------------------------

-- Cold vapour: heavier than air, it spills, slows (Drag) and sinks; soft, matte, lit by the
-- room (not a glow), fades in and out.
local function vapourEmitter(parent: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "ColdVapour"
	emitter.Texture = SMOKE_TEXTURE
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(VAPOUR, VAPOUR_DEEP)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.4, 0.8, 0.1),
		NumberSequenceKeypoint.new(1, 1.2, 0.15),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.65),
		NumberSequenceKeypoint.new(0.5, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1.6, 2.4)
	emitter.Speed = NumberRange.new(0.2, 0.5)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Drag = 2
	emitter.Acceleration = Vector3.new(0, -0.6, 0)
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

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

local function track(bench: Bench, part: BasePart, localCFrame: CFrame)
	Parts.add(bench.rig, part, localCFrame)
end

-- A panel (side -1 / +1) at `open` 0..1: hinged on its OUTER edge (body x = ±0.6).
local function panelCFrame(side: number, open: number, tremble: number?): CFrame
	local angle = PANEL_OPEN * math.clamp(open, 0, 1)
	return CFrame.new(side * OPENING / 2, TORSO.Y, PANEL_Z)
		* CFrame.Angles(0, -side * angle, 0)
		* CFrame.new(-side * OPENING / 4, 0, (tremble or 0))
end

local function cellY(k: number): number
	return SEAM_TOP - (k - 0.5) * CELL
end

-- Where a piece on panel `side`'s meeting edge sits (in the panel's space), `width` wide,
-- `lift` in front of the panel's outer face.
local function onEdge(side: number, k: number, width: number, lift: number): CFrame
	return CFrame.new(-side * (OPENING / 4 - width / 2), cellY(k) - TORSO.Y, -0.025 - lift)
end

function BenchVisual.new(
	anchor: CFrame,
	parent: Instance,
	elements: { Types.ExtractElement },
	needKit: boolean
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
	local bench: Bench = {
		anchor = anchor,
		root = BenchVisual.lyingRoot(anchor),
		folder = folder,
		rig = Parts.newRig(),
		panels = {},
		panelOpen = { 0, 0 },
		panelTremble = { 0, 0 },
		cells = {},
		scratches = 0,
		riders = {},
		elements = {},
		highlight = highlight,
		strandBase = nil :: any,
		strandTip = nil :: any,
		beams = {},
		strandsFor = nil,
		strandsBack = nil,
		strandStretch = 0,
		vapourSource = nil :: any,
		vapour = nil :: any,
		cutLight = nil :: any,
		runoff = nil,
		runoffGrow = 0,
		runoffBorn = 0,
		falling = {},
		landed = 0,
		random = Random.new(),
		visible = 1,
		fadeBase = nil,
		kit = nil,
	}
	if needKit then
		-- (the lab has no static bench kit: build one for this scene only)
		bench.kit = BenchLayout.buildStatic(folder, anchor)
	end

	-- The shell (SHELL look, chest open under the panels).
	CloneModel.buildShell(bench.rig, folder, true)

	-- Cavity: a dark wet lining on the floor and the 4 inner walls (inset from the shell's own
	-- walls by 0.006: no shared faces).
	local half = OPENING / 2
	local depth = 0.64
	track(
		bench,
		Parts.part({
			Name = "CavityFloor",
			Size = Vector3.new(OPENING - 0.02, OPENING - 0.02, 0.02),
			Color = CAVITY_FLOOR,
			Reflectance = 0.25,
			Parent = folder,
		}),
		CFrame.new(TORSO.X, TORSO.Y, FLOOR_Z - 0.016)
	)
	for _, side in { -1, 1 } do
		track(
			bench,
			Parts.part({
				Name = "Lining",
				Size = Vector3.new(0.01, OPENING - 0.02, depth - 0.02),
				Color = LINING,
				Reflectance = 0.35,
				Parent = folder,
			}),
			CFrame.new(side * (half - 0.011), TORSO.Y, CHEST_Z + depth / 2)
		)
		track(
			bench,
			Parts.part({
				Name = "Lining",
				Size = Vector3.new(OPENING - 0.04, 0.01, depth - 0.02),
				Color = LINING,
				Reflectance = 0.35,
				Parent = folder,
			}),
			CFrame.new(0, TORSO.Y + side * (half - 0.011), CHEST_Z + depth / 2)
		)
	end

	-- The two chest panels.
	for _, side in { -1, 1 } do
		local panel = Parts.part({
			Name = "ChestPanel",
			Size = Vector3.new(OPENING / 2 - 0.004, OPENING - 0.004, 0.05),
			Color = COLORS.pearl,
			Reflectance = 0.15,
			Parent = folder,
		})
		track(bench, panel, panelCFrame(side, 0))
		table.insert(bench.panels, panel)
	end

	-- The seam: per cell a guide dash (on the -1 panel's edge, over the meeting line), two
	-- split halves and two wet edges (one per panel edge, they ride the panels), and the teal
	-- glow strip over the line. All hidden until cut (the guide until then only).
	for _ = 1, CELLS do
		local guide = Parts.part({
			Name = "SeamGuide",
			Size = Vector3.new(0.008, CELL * 0.6, 0.004),
			Color = GUIDE,
			Transparency = 0.45,
			Parent = folder,
		})
		track(bench, guide, CFrame.identity)
		local splits, wets = {}, {}
		for _ = 1, 2 do
			local split = Parts.part({
				Name = "Split",
				Size = Vector3.new(0.014, CELL + 0.004, 0.008),
				Color = SPLIT,
				Transparency = 1,
				Parent = folder,
			})
			track(bench, split, CFrame.identity)
			table.insert(splits, split)
			local wet = Parts.part({
				Name = "WetEdge",
				Size = Vector3.new(0.012, CELL + 0.004, 0.012),
				Color = MILK,
				Reflectance = 0.3,
				Transparency = 1,
				Parent = folder,
			})
			track(bench, wet, CFrame.identity)
			table.insert(wets, wet)
		end
		local glow = Parts.part({
			Name = "CutGlow",
			Size = Vector3.new(0.008, CELL, 0.004),
			Material = Enum.Material.Neon,
			Color = GLOW,
			Transparency = 1,
			Parent = folder,
		})
		track(bench, glow, CFrame.identity)
		table.insert(bench.cells, {
			depth = 0,
			guide = guide,
			splits = splits,
			wets = wets,
			glow = glow,
			cutAt = nil,
		})
	end
	BenchVisual.layoutPanels(bench)

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
			CFrame.new(at.X, at.Y, FLOOR_Z - 0.05) * CFrame.Angles(0, 0, yaw)
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
		local _, size = model:GetBoundingBox()
		table.insert(bench.elements, {
			model = model,
			kind = info.kind :: string,
			condition = info.condition :: string,
			nest = nest,
			mode = "Nest",
			pull = Vector3.zero,
			lit = false,
			pool = nil,
			sink = 0,
			half = math.min(size.X, size.Z) / 2,
			glossy = false,
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
		beam.Color = ColorSequence.new(rgb(228, 232, 220))
		beam.Transparency = NumberSequence.new(0.3)
		beam.Width0 = 0.035
		beam.Width1 = 0.021
		beam.CurveSize0 = 0.1 * (if k == 2 then -1 else 1)
		beam.CurveSize1 = -0.08
		beam.Segments = 8
		beam.FaceCamera = true
		beam.LightEmission = 0
		beam.LightInfluence = 1
		beam.Enabled = false
		beam.Parent = bench.strandBase
		table.insert(bench.beams, beam)
	end

	-- The vapour emitter on a small invisible part (Box shape needs a part parent).
	local vapourSource = Parts.part({
		Name = "VapourSource",
		Size = Vector3.new(0.7, 0.05, 0.7),
		Transparency = 1,
		CFrame = anchor,
		Parent = folder,
	})
	bench.vapourSource = vapourSource
	bench.vapour = vapourEmitter(vapourSource)
	-- The small cold light that follows the cut (then rests on the seam's middle, dim).
	local lightHost = Parts.part({
		Name = "CutLightHost",
		Size = Vector3.new(0.05, 0.05, 0.05),
		Transparency = 1,
		CFrame = anchor,
		Parent = folder,
	})
	local light = Instance.new("PointLight")
	light.Name = "CutLight"
	light.Color = GLOW
	light.Range = 1.5
	light.Brightness = 0
	light.Shadows = false
	light.Parent = lightHost
	bench.cutLight = light

	folder.Parent = parent
	BenchVisual.place(bench, bench.root)
	return bench
end

------------------------------------------------------------------------------
-- Seam and panels
------------------------------------------------------------------------------

-- Places the panels and everything riding them (call after a change of open / tremble).
function BenchVisual.layoutPanels(bench: Bench)
	for i, panel in bench.panels do
		local side = if i == 1 then -1 else 1
		Parts.setLocal(
			bench.rig,
			panel,
			panelCFrame(side, bench.panelOpen[i], bench.panelTremble[i])
		)
	end
	local shut = bench.panelOpen[1] < 0.02 and bench.panelOpen[2] < 0.02
	for k, cell in bench.cells do
		for s = 1, 2 do
			local side = if s == 1 then -1 else 1
			local panel = panelCFrame(side, bench.panelOpen[s], bench.panelTremble[s])
			local width = if cell.depth >= 2 then 0.025 else 0.007
			Parts.setLocal(bench.rig, cell.splits[s], panel * onEdge(side, k, width, 0.004))
			cell.splits[s].Size = Vector3.new(width, CELL + 0.004, 0.008)
			-- the wet milky edge: just outside the split, a little proud
			Parts.setLocal(
				bench.rig,
				cell.wets[s],
				panel * onEdge(side, k, 0.012, 0.006) * CFrame.new(side * width, 0, 0)
			)
		end
		local panelA = panelCFrame(-1, bench.panelOpen[1], bench.panelTremble[1])
		Parts.setLocal(
			bench.rig,
			cell.guide,
			panelA * CFrame.new(OPENING / 4, cellY(k) - TORSO.Y, -0.025 - 0.002)
		)
		Parts.setLocal(bench.rig, cell.glow, CFrame.new(0, cellY(k), PANEL_FRONT - 0.009))
		if not shut and cell.glow.Transparency < 1 then
			cell.glow.Transparency = 1 -- (the panels are apart: no line left to glow)
		end
	end
	-- beads and scratches on a panel ride it
	for _, rider in bench.riders do
		local side = if rider.side == 1 then -1 else 1
		Parts.setLocal(
			bench.rig,
			rider.part,
			panelCFrame(side, bench.panelOpen[rider.side], bench.panelTremble[rider.side])
				* rider.at
		)
	end
end

-- The chest plane (world): a point on it and its normal (out of the chest = up).
function BenchVisual.chestPlane(bench: Bench): (Vector3, Vector3)
	return bench.root * Vector3.new(0, TORSO.Y, PANEL_FRONT),
		bench.root:VectorToWorldSpace(Vector3.new(0, 0, -1))
end

-- A world point → seam coordinates: `s` in cells (0 = neck end .. CELLS = waist end) and the
-- lateral distance `e` from the seam (studs, body X).
function BenchVisual.toSeam(bench: Bench, world: Vector3): (number, number)
	local p = bench.root:PointToObjectSpace(world)
	return (SEAM_TOP - p.Y) / CELL, p.X
end

-- Seam coordinates → a world point on the panels' surface (`lift` above it).
function BenchVisual.seamPoint(bench: Bench, s: number, e: number, lift: number?): Vector3
	return bench.root * Vector3.new(e, SEAM_TOP - s * CELL, PANEL_FRONT - (lift or 0))
end

function BenchVisual.cellDepth(bench: Bench, k: number): number
	local cell = bench.cells[k]
	return if cell then cell.depth else 0
end

-- Cuts cell `k` to `depth` (1 skin, 2 membrane). Returns true if it got deeper.
function BenchVisual.cutCell(bench: Bench, k: number, depth: number): boolean
	local cell = bench.cells[k]
	if cell == nil or depth <= cell.depth then
		return false
	end
	cell.depth = math.min(depth, 2)
	cell.cutAt = os.clock()
	cell.guide.Transparency = 1
	for s = 1, 2 do
		cell.splits[s].Transparency = 0
		cell.wets[s].Transparency = if cell.depth >= 2 then 0.15 else 1
	end
	cell.glow.Transparency = if cell.depth >= 2 then 1 else 0.6
	BenchVisual.layoutPanels(bench)
	-- the small cold light follows the last cut cell
	local host = bench.cutLight.Parent
	if host and host:IsA("BasePart") then
		host.CFrame = CFrame.new(BenchVisual.seamPoint(bench, k - 0.5, 0, 0.05))
	end
	bench.cutLight.Brightness = 0.4
	-- a milky bead wells up on every 2nd cell of the skin cut (it grows, then stays)
	if cell.depth == 1 and k % 2 == 0 then
		local side = if k % 4 == 0 then 1 else -1
		local beadPart = Parts.ball(0.01, {
			Name = "SeamBead",
			Color = MILK,
			Reflectance = 0.12,
			Parent = bench.folder,
		})
		beadPart:SetAttribute("Born", os.clock())
		local at = onEdge(side, k, 0.05, 0.02) * CFrame.new(side * 0.02, 0, 0)
		track(bench, beadPart, panelCFrame(side, 0) * at)
		table.insert(bench.riders, { part = beadPart, side = if side < 0 then 1 else 2, at = at })
	end
	return true
end

-- A pale scratch left by the blade off the seam, from `a` to `b` (world). At most 8, they stay.
function BenchVisual.scratch(bench: Bench, a: Vector3, b: Vector3): boolean
	if bench.scratches >= MAX_SCRATCHES or (b - a).Magnitude < 0.04 then
		return false
	end
	bench.scratches += 1
	local pa = bench.root:PointToObjectSpace(a)
	local pb = bench.root:PointToObjectSpace(b)
	local flatA = Vector3.new(pa.X, pa.Y, 0)
	local flatB = Vector3.new(pb.X, pb.Y, 0)
	local middle = (flatA + flatB) / 2
	local along = flatB - flatA
	local length = math.min(along.Magnitude, 0.4)
	local part = Parts.part({
		Name = "Scratch",
		Size = Vector3.new(0.006, length, 0.002),
		Color = SCRATCH,
		Transparency = 0.2,
		Parent = bench.folder,
	})
	local angle = math.atan2(-along.X, along.Y)
	-- (on the chest wall or a panel: 0.003 above the outer surface of whichever it is on)
	local onPanel = math.abs(middle.X) < OPENING / 2
		and middle.Y > SEAM_BOTTOM
		and middle.Y < SEAM_TOP
	local z = if onPanel then PANEL_FRONT - 0.002 else CHEST_Z - 0.002
	local body = CFrame.new(middle.X, middle.Y, z) * CFrame.Angles(0, 0, angle)
	track(bench, part, body)
	if onPanel then
		local which = if middle.X < 0 then 1 else 2
		local panel = panelCFrame(if which == 1 then -1 else 1, bench.panelOpen[which], 0)
		table.insert(bench.riders, { part = part, side = which, at = panel:Inverse() * body })
	end
	return true
end

-- Panel `side` (1 = body -X, 2 = body +X) open 0..1, with a small tremble (studs).
function BenchVisual.setPanel(bench: Bench, side: number, open: number, tremble: number)
	bench.panelOpen[side] = math.clamp(open, 0, 1)
	bench.panelTremble[side] = tremble
	BenchVisual.layoutPanels(bench)
end

function BenchVisual.panelOpen(bench: Bench, side: number): number
	return bench.panelOpen[side]
end

-- Where a retractor clip bites panel `side`'s rim (world; the clip's +Z points away from the
-- chest, its hooks on the rim).
function BenchVisual.clipFrame(bench: Bench, side: number): CFrame
	local s = if side == 1 then -1 else 1
	local panel = panelCFrame(s, bench.panelOpen[side], 0)
	local rim = bench.root * panel * CFrame.new(-s * OPENING / 4, 0.05, -0.03)
	local outward = (bench.root * Vector3.new(s * 1.2, TORSO.Y, CHEST_Z)) - bench.root.Position
	local up = bench.root:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local flat = outward - up * outward:Dot(up)
	local look = if flat.Magnitude > 1e-3 then flat.Unit else bench.anchor.LookVector
	return CFrame.lookAt(rim.Position, rim.Position - look, up)
end

-- The middle of the chest opening (world) and whether `world` is over it.
function BenchVisual.overOpening(bench: Bench, world: Vector3): boolean
	local p = bench.root:PointToObjectSpace(world)
	return math.abs(p.X) < OPENING / 2
		and p.Y > TORSO.Y - OPENING / 2
		and p.Y < TORSO.Y + OPENING / 2
end

-- The panel the point `world` grabs (within `reach` of the seam, on one side), or nil.
function BenchVisual.panelAt(bench: Bench, world: Vector3, reach: number): number?
	local p = bench.root:PointToObjectSpace(world)
	if p.Y < SEAM_BOTTOM or p.Y > SEAM_TOP or math.abs(p.X) > reach then
		return nil
	end
	return if p.X < 0 then 1 else 2
end

-- The heavy cold breath spilling out of the opened seam (count = particles).
function BenchVisual.breath(bench: Bench, count: number, at: Vector3?, spread: number?)
	if bench.visible <= 0 then
		return
	end
	local source = bench.vapourSource
	local size = spread or 0.45
	source.Size = Vector3.new(size * 2, 0.05, size * 2)
	source.CFrame = CFrame.new(at or (bench.root * Vector3.new(0, TORSO.Y, CHEST_Z - 0.1)))
		* bench.anchor.Rotation
	bench.vapour:Emit(count)
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

function BenchVisual.elementCount(bench: Bench): number
	return #bench.elements
end

function BenchVisual.mode(bench: Bench, index: number): ElementMode?
	local element = bench.elements[index]
	return if element then element.mode else nil
end

-- The element's current pivot (world).
function BenchVisual.elementCFrame(bench: Bench, index: number): CFrame
	local element = bench.elements[index]
	return if element then element.model:GetPivot() else bench.root
end

-- Its nest pose (world, not pulled).
function BenchVisual.nestCFrame(bench: Bench, index: number): CFrame
	local element = bench.elements[index]
	return if element then bench.root * element.nest else bench.root
end

-- Half its thickness lying down (to rest it ON something).
function BenchVisual.halfHeight(bench: Bench, index: number): number
	local element = bench.elements[index]
	return if element then element.half else 0.1
end

-- In the nest, pulled by `offset` (world).
function BenchVisual.setPull(bench: Bench, index: number, offset: Vector3)
	local element = bench.elements[index]
	if element then
		element.mode = "Nest"
		element.pull = offset
	end
end

-- Free in the world at `cframe` (held, loose, on the tray).
function BenchVisual.setFree(bench: Bench, index: number, cframe: CFrame)
	local element = bench.elements[index]
	if element and element.mode ~= "Gone" then
		element.mode = "Free"
		element.model:PivotTo(cframe)
	end
end

-- The element leaves the bench for good (the pass-box takes its model).
function BenchVisual.takeModel(bench: Bench, index: number): Model?
	local element = bench.elements[index]
	if element == nil or element.mode == "Gone" then
		return nil
	end
	element.mode = "Gone"
	if bench.highlight.Adornee == element.model then
		bench.highlight.Enabled = false
		bench.highlight.Adornee = nil
	end
	return element.model
end

-- The one outline, on `target` (an element model, a tool model...) or nothing.
function BenchVisual.outline(bench: Bench, target: Instance?)
	if target == nil or bench.visible <= 0.5 then
		bench.highlight.Enabled = false
		bench.highlight.Adornee = nil
		return
	end
	if bench.highlight.Adornee ~= target then
		bench.highlight.Adornee = target
	end
	bench.highlight.Enabled = true
end

function BenchVisual.elementModel(bench: Bench, index: number): Model?
	local element = bench.elements[index]
	return if element and element.mode ~= "Gone" then element.model else nil
end

-- Pulled out of its nest: the strands stretch to it (a husk has none: dry, no tension). A
-- ruptured one starts seeping into its nest (a pool that grows and stays).
function BenchVisual.grab(bench: Bench, index: number)
	local element = bench.elements[index]
	if element == nil then
		return
	end
	if element.kind ~= "Husk" then
		bench.strandsFor = index
		bench.strandsBack = nil
		for _, beam in bench.beams do
			beam.Enabled = bench.visible > 0.5
		end
	end
	if element.condition == "Ruptured" and element.pool == nil then
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

-- The strands give: 0.15 s thinning, then they sag and retract into the nest (0.3 s); a milky
-- drop falls back into the nest and stays. `freed` = it came free (else let go: no drop).
function BenchVisual.releaseStrands(bench: Bench, index: number, freed: boolean)
	if bench.strandsFor ~= index or bench.strandsBack then
		return
	end
	bench.strandsBack = os.clock()
	local element = bench.elements[index]
	if freed and element then
		local at = element.model:GetPivot().Position
		local part = Parts.ellipsoid(Vector3.new(0.06, 0.06, 0.06), {
			Name = "MilkDrop",
			Color = MILK,
			Reflectance = 0.2,
			CFrame = CFrame.new(at),
			Parent = bench.folder,
		})
		local floor = bench.root
			* Vector3.new(element.nest.Position.X, element.nest.Position.Y, FLOOR_Z - 0.1)
		table.insert(bench.falling, {
			part = part,
			position = at,
			velocity = Vector3.zero,
			floorY = floor.Y,
			landed = false,
			rest = nil,
			onShell = true,
			flat = Vector3.new(0.09, 0.02, 0.09),
			sound = true,
		})
	end
end

-- How far the strands stretch (0..1): their width and sag follow it.
function BenchVisual.setStretch(bench: Bench, stretch: number)
	bench.strandStretch = math.clamp(stretch, 0, 1)
end

-- What the surface under `world` is (world Y of the top, and whether it is the shell).
local function groundAt(bench: Bench, point: Vector3): (number, boolean)
	local p = bench.anchor:PointToObjectSpace(point)
	local top = bench.anchor.Position.Y
	local lift = BenchLayout.SHELL_LIFT
	local st = BenchLayout.SPECIMEN_TRAY
	local it = BenchLayout.INSTRUMENT_TRAY
	if p.X >= -3 and p.X <= 1.0 and math.abs(p.Z) <= 2 and (math.abs(p.Z) <= 1 or p.X >= -1) then
		return top + lift + 1.0, true -- (chest, arms, legs: 1 stud thick lying down)
	elseif p.X > 1.0 and p.X <= 2.2 and math.abs(p.Z) <= 0.58 then
		return top + lift + 1.08, true -- (the head)
	elseif
		math.abs(p.X - st.centre.X) <= st.size.X / 2
		and math.abs(p.Z - st.centre.Z) <= st.size.Z / 2
	then
		return top + BenchLayout.MAT_TOP, false
	elseif
		math.abs(p.X - it.centre.X) <= it.size.X / 2
		and math.abs(p.Z - it.centre.Z) <= it.size.Z / 2
	then
		return top + BenchLayout.TRAY_FLOOR + 0.01, false
	elseif math.abs(p.X) <= 3.5 and math.abs(p.Z) <= 1.5 then
		return top + 0.002, false
	end
	return top - 3.35 + 0.002, false -- (the floor)
end

-- A milky bead falling from `at` (a ruptured element on its way). It lands and stays.
function BenchVisual.bead(bench: Bench, at: Vector3)
	local d = bench.random:NextNumber(0.04, 0.07)
	local part = Parts.ellipsoid(Vector3.new(d, d, d), {
		Name = "Bead",
		Color = COLORS.gel,
		Transparency = 0.15,
		Reflectance = 0.25,
		CFrame = CFrame.new(at),
		Parent = bench.folder,
	})
	local ground, onShell = groundAt(bench, at)
	table.insert(bench.falling, {
		part = part,
		position = at,
		velocity = Vector3.new(
			bench.random:NextNumber(-0.2, 0.2),
			0,
			bench.random:NextNumber(-0.2, 0.2)
		),
		floorY = ground,
		landed = false,
		rest = nil,
		onShell = onShell,
		flat = Vector3.new(d * 1.6, d * 0.35, d * 1.6),
		sound = true,
	})
end

-- Beads / drops that landed since the last call (the controller plays MilkDrip, ≤ 4 per s).
function BenchVisual.takeLanded(bench: Bench): number
	local n = bench.landed
	bench.landed = 0
	return n
end

-- The element set on the specimen tray drains: its gel coat slides into the tray's channel
-- (a milky runoff that grows and stays), and it gets glossier.
function BenchVisual.runoff(bench: Bench, index: number)
	local element = bench.elements[index]
	if element and not element.glossy then
		element.glossy = true
		for _, descendant in element.model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Material ~= Enum.Material.Neon then
				descendant.Reflectance = math.min(descendant.Reflectance + 0.12, 0.5)
			end
		end
	end
	if bench.runoff == nil then
		bench.runoff = Parts.part({
			Name = "Runoff",
			Size = Vector3.new(0.09, 0.006, 0.02),
			Color = rgb(214, 222, 210),
			Transparency = 0.35,
			Reflectance = 0.3,
			Parent = bench.folder,
		})
	end
	bench.runoffGrow = math.min(bench.runoffGrow + 0.5, 1)
	bench.runoffBorn = os.clock()
end

------------------------------------------------------------------------------
-- Placing and per-frame
------------------------------------------------------------------------------

-- Moves the shell and everything in its nests to `root` (call every frame).
function BenchVisual.place(bench: Bench, root: CFrame)
	bench.root = root
	Parts.place(bench.rig, root)
	for _, element in bench.elements do
		if element.mode == "Nest" then
			local sinkBy = 0.1 * element.sink
			element.model:PivotTo(
				CFrame.new(element.pull) * root * CFrame.new(0, 0, sinkBy) * element.nest
			)
		end
	end
end

function BenchVisual.step(bench: Bench, dt: number, now: number)
	-- Cut cells: the teal glow fades to 0.85 (never out); beads grow in.
	for _, cell in bench.cells do
		local at = cell.cutAt
		if at and cell.depth == 1 then
			local wanted = Parts.fade(0.6 + 0.25 * smooth((now - at) / GLOW_FADE), bench.visible)
			if math.abs(cell.glow.Transparency - wanted) > 0.01 then
				cell.glow.Transparency = wanted
			end
		end
	end
	bench.cutLight.Brightness = math.max(0.15, bench.cutLight.Brightness - dt * 0.2)
		* (if bench.visible > 0.5 then 1 else 0)
	for _, part in bench.rig.parts do
		if part.Name == "SeamBead" then
			local born = part:GetAttribute("Born")
			if typeof(born) == "number" then
				local d = 0.01 + 0.04 * smooth((now - born) / 0.4)
				if part.Size.X < 0.05 - 1e-3 then
					part.Size = Vector3.new(d, d, d)
				end
			end
		end
	end

	-- Elements: breathing lights; the pool of a ruptured one grows in its nest (and stays).
	for _, element in bench.elements do
		if element.mode ~= "Gone" then
			CoreModel.animate(element.model, now, element.lit and bench.visible > 0.5)
		end
		local pool = element.pool
		if pool then
			local born = pool:GetAttribute("Born")
			local grow = if typeof(born) == "number" then smooth((now - born) / 1.0) else 1
			local d = 0.05 + 0.27 * grow
			if math.abs(pool.Size.Y - d) > 1e-3 then
				pool.Size = Vector3.new(0.012, d, d)
			end
			pool.CFrame = bench.root
				* CFrame.new(element.nest.Position.X, element.nest.Position.Y, FLOOR_Z - 0.032)
				* CFrame.Angles(0, math.rad(90), 0)
		end
	end

	-- Strands: from the nest to the pulled element, thinner as they stretch; after a release
	-- they thin (0.15 s), then sag and retract into the nest (0.3 s). No snap, no flash.
	local index = bench.strandsFor
	if index then
		local element = bench.elements[index]
		local base = bench.root
			* CFrame.new(element.nest.Position.X, element.nest.Position.Y, FLOOR_Z - 0.08)
		local tip = element.model:GetPivot().Position
		local width = 0.035 * (1 - 0.6 * bench.strandStretch)
		local curve = 0.1 * (1 - bench.strandStretch)
		local transparency = 0.3 + 0.3 * bench.strandStretch
		local back = bench.strandsBack
		if back then
			local t = now - back
			width *= 0.3
			if t > 0.15 then
				local r = smooth((t - 0.15) / 0.3)
				tip = tip:Lerp(base.Position, r)
				curve = 0.25 * (1 - r)
				transparency = 0.6 + 0.4 * r
			end
			if t >= 0.45 then
				bench.strandsFor = nil
				bench.strandsBack = nil
				for _, beam in bench.beams do
					beam.Enabled = false
				end
			end
		end
		bench.strandBase.CFrame = base
		bench.strandTip.CFrame = CFrame.new(tip) * base.Rotation
		for k, beam in bench.beams do
			beam.Width0 = width
			beam.Width1 = width * 0.6
			beam.CurveSize0 = curve * (if k == 2 then -1 else 1)
			beam.Transparency = NumberSequence.new(transparency)
		end
	end

	-- The tray runoff: grows along the drain channel (and stays).
	local runoff = bench.runoff
	if runoff then
		local grow = bench.runoffGrow * smooth((now - bench.runoffBorn) / 1.2)
			+ math.max(0, bench.runoffGrow - 0.5) * (1 - smooth((now - bench.runoffBorn) / 1.2))
		local drain = BenchLayout.DRAIN
		local length = math.max(0.02, drain.size.Z * 0.9 * grow)
		if math.abs(runoff.Size.Z - length) > 1e-3 then
			runoff.Size = Vector3.new(0.09, 0.006, length)
		end
		runoff.CFrame = bench.anchor
			* CFrame.new(
				drain.centre.X,
				drain.centre.Y + 0.004,
				drain.centre.Z - drain.size.Z * 0.45 + length / 2
			)
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
				if item.sound then
					bench.landed += 1
				end
				if item.onShell then
					item.rest = bench.root:PointToObjectSpace(position)
				end
			end
		end
		item.position = position
		item.part.CFrame = CFrame.new(position)
	end
end

-- Outro: t 0..1, the panels fold back over the cavity, the leftovers dim and sink.
function BenchVisual.closePanels(bench: Bench, t: number, from: { number })
	local s = smooth(t)
	bench.panelOpen[1] = from[1] * (1 - s)
	bench.panelOpen[2] = from[2] * (1 - s)
	bench.panelTremble[1] = 0
	bench.panelTremble[2] = 0
	BenchVisual.layoutPanels(bench)
	for _, element in bench.elements do
		if element.mode == "Nest" then
			element.pull = Vector3.zero
			element.lit = false
			element.sink = math.max(element.sink, s)
		end
	end
	if t > 0 then
		BenchVisual.outline(bench, nil)
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

-- Fades the shell and what lies on the trolley (0 = gone, 1 = as designed). The pass-box,
-- the hand and the tools are not in this folder (they stay).
function BenchVisual.fade(bench: Bench, visible: number)
	bench.visible = math.clamp(visible, 0, 1)
	local base = bench.fadeBase
	if base == nil then
		-- (the first fade: remember every part's own transparency once; the fallback kit, if
		-- any, stays as it is)
		local made: { [BasePart]: number } = {}
		for _, descendant in bench.folder:GetDescendants() do
			if
				descendant:IsA("BasePart")
				and descendant.Transparency < 1
				and (bench.kit == nil or not descendant:IsDescendantOf(bench.kit :: Model))
			then
				made[descendant] = descendant.Transparency
			end
		end
		bench.fadeBase = made
		base = made
	end
	for part, own in base :: { [BasePart]: number } do
		if part.Parent ~= nil then
			part.Transparency = Parts.fade(own, bench.visible)
		end
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
		bench.cutLight.Enabled = false
	end
	if bench.visible <= 0 then
		bench.vapour:Clear()
	end
end

function BenchVisual.destroy(bench: Bench)
	bench.folder:Destroy()
end

return BenchVisual
