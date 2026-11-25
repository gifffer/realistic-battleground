--!strict
-- BenchLayout: WHERE everything of the extraction bench is, in ONE place (shared by the
-- server's LabBuilder and the client's BenchVisual / BenchHand / PassBox), and the builder of
-- its STATIC parts (the parts everyone sees at all times).
--
-- SPACE: "anchor space" = the lab's `BenchAnchor` marker (identity rotation, y 0 = the
-- trolley's top surface, world L(18, 3.35, 10.5)). The trolley top is 7 × 3: x -3.5..3.5,
-- z -1.5..1.5. The camera of the extraction looks from -Z. Seen from there, +X is on the
-- screen's LEFT. All numbers below are studs in that space.
--
--   ┌─────────────────────── trolley top 7 × 3 ────────────────────────┐
--   │  head          torso / chest seam           legs                 │   PASS BOX
--   │ ┌────────┐                               ┌──────────────────┐    │   (floor,
--   │ │SPECIMEN│                               │ INSTRUMENT TRAY  │    │    +X end,
--   │ │  TRAY  │                               │ scalpel · clips  │    │    x 3.6..4.8)
--   └──────────────────────────────────────────────────────────────────┘
--            near side (-Z) = the camera
--
-- THE STATIC KIT (BenchLayout.buildStatic, called ONCE by LabBuilder on the server):
--   • Underpad: a folded absorbent pad under the shell (x -3.05..1.05, z -0.98..0.98,
--     0.055 thick). The shell lies ON it, and its arms (z ±1..±2) clear the trolley lip.
--     → LabBuilder must REMOVE the old blue underpad (+ its folded corner) of trolleyBench.
--   • InstrumentTray: a steel tray by the legs with a folded green-grey towel, plus a rest
--     copy of the scalpel and the 2 retractor clips.
--   • SpecimenTray: a steel tray by the head with a dark ribbed silicone mat and a drain
--     channel.
--   • PassBox: the cold pass-box, a squat insulated cabinet standing on the floor at the
--     trolley's +X end: a hatch lid on top, a grate, a funnel inside (the client adds the
--     capsule carousel during the scene), a double-pane window on its camera face (-Z) and a small strip display under it.
--   Parts that MOVE in the extraction scene (the lid, the grate bars, the well's inner
--   shutter (closed at rest: the stored capsules are behind it), the rest scalpel / clips)
--   carry the attribute "SceneHidden" = true: the extractor's client hides them locally
--   (LocalTransparencyModifier) while it plays its own moving copies, and shows them again
--   after. Everyone else keeps seeing the static ones.
--   The window panes are SmoothPlastic, never Material.Glass (Glass hides every transparent
--   thing behind it: the capsules' tubes would vanish).
--   No coplanar faces: every overlay is raised by ≥ 0.004, every pane stands off its frame.
--
--   BenchLayout.buildStatic(parent, anchor) → Model "BenchKit" (made once, server)
--   BenchLayout.SCALPEL / BenchLayout.CLIP   piece lists (the client builds its rigs from the
--                                             same lists, so the copies match exactly)

local BenchLayout = {}

local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

------------------------------------------------------------------------------
-- The numbers (anchor space)
------------------------------------------------------------------------------

BenchLayout.TOP = table.freeze({ x0 = -3.5, x1 = 3.5, z0 = -1.5, z1 = 1.5 })

-- The shell lies on the underpad, this much above the trolley top (its arms then clear the
-- trolley's lip, whose top is at 0.05).
BenchLayout.SHELL_LIFT = 0.055
BenchLayout.UNDERPAD = table.freeze({ centre = V(-1.0, 0.0275, 0), size = V(4.1, 0.055, 1.96) })

-- Instrument tray (beside the legs, near side; never under the legs: they reach z -1).
BenchLayout.INSTRUMENT_TRAY =
	table.freeze({ centre = V(-2.15, 0, -1.26), size = V(1.5, 0.06, 0.42) })
BenchLayout.TRAY_FLOOR = 0.012 -- the trays' floor thickness (their inside floor top)
-- Rest poses on the instrument tray (the towel's top is at 0.022).
-- (the scalpel lies on its handle on the towel, tip toward -X; the clips on the bare steel,
-- rings toward the camera)
BenchLayout.SCALPEL_REST = CF(-2.75, 0.04, -1.22) * ANG(0, rad(90), 0)
BenchLayout.CLIP_RESTS = table.freeze({
	CF(-1.8, 0.04, -1.26) * ANG(0, math.pi, 0),
	CF(-1.6, 0.04, -1.26) * ANG(0, math.pi, 0),
})

-- Specimen tray (beside the head, near side).
BenchLayout.SPECIMEN_TRAY = table.freeze({ centre = V(1.88, 0, -1.05), size = V(1.1, 0.07, 0.5) })
BenchLayout.MAT_TOP = 0.036 -- the ribbed mat's top (the element rests on it)
BenchLayout.SPECIMEN_REST = V(1.8, 0.036, -1.05) -- the element's bottom goes here
BenchLayout.DRAIN = table.freeze({ centre = V(2.33, 0.013, -1.05), size = V(0.12, 0.002, 0.42) })

-- The cold pass-box (on the floor at the trolley's +X end; the floor is at -3.35).
local BOX_X, BOX_Z = 4.2, -0.55
BenchLayout.PASS_BOX = table.freeze({
	centre = V(BOX_X, 0, BOX_Z),
	size = V(1.2, 3.5, 1.4), -- x 3.6..4.8, z -1.25..0.15, y -3.35..0.15
	floor = -3.35,
	deckTop = 0.15,
	wall = 0.06,
	opening = 0.6, -- the square hatch opening in the deck
	front = BOX_Z - 0.7, -- the camera face (z)
})
-- The hatch lid: its hinge runs along the opening's +X edge (it opens away from the trolley).
BenchLayout.LID_HINGE = V(BOX_X + 0.35, 0.17, BOX_Z)
BenchLayout.LID_OPEN = rad(105)
BenchLayout.GRATE_Y = 0.12 -- the grate bars' centre (just under the deck top)
BenchLayout.GRATE_SLIDE = 0.3 -- each half slides this far along ±Z
-- Inside: the funnel takes the element from the grate down to the capsule waiting in the
-- FRONT socket (right behind the window, so it is seen landing).
BenchLayout.FUNNEL_EXIT = V(BOX_X, -0.15, BOX_Z - 0.32)
-- (the capsules stand 0.4 under the funnel's exit: room for a capsule's cap to stand open)
BenchLayout.CAROUSEL =
	table.freeze({ centre = V(BOX_X, -1.715, BOX_Z), radius = 0.32, height = 0.05 })
BenchLayout.CAPSULE_Y = -1.12 -- capsule centres (their bottom sits on the carousel)
-- The window on the camera face, the strip display under it.
BenchLayout.WINDOW = table.freeze({ centre = V(BOX_X, -1.02, BOX_Z - 0.7), size = V(0.8, 1.1, 0) })
BenchLayout.DISPLAY = table.freeze({ centre = V(BOX_X, -1.8, BOX_Z - 0.7), size = V(0.5, 0.1, 0) })
-- Where the hand lets an element go to drop it in (the grate's centre) and how close counts.
BenchLayout.GRATE_CENTRE = V(BOX_X, 0.15, BOX_Z)
BenchLayout.GRATE_RADIUS = 0.35

-- The socket of the carousel at `angle` (radians, 0 = the front socket under the funnel).
function BenchLayout.socket(angle: number): Vector3
	local c = BenchLayout.CAROUSEL.centre
	local r = BenchLayout.CAROUSEL.radius
	return V(c.X + math.sin(angle) * r, BenchLayout.CAPSULE_Y, c.Z - math.cos(angle) * r)
end

------------------------------------------------------------------------------
-- The instruments (piece lists in their own space; built the same on both sides)
------------------------------------------------------------------------------

-- One piece: a Part (or a WedgePart / Cylinder) of `size` at `at` in the tool's space.
export type Piece = {
	name: string,
	size: Vector3,
	at: CFrame,
	color: Color3,
	material: Enum.Material,
	reflectance: number,
	shape: ("Block" | "Wedge" | "Cylinder")?,
}

local STEEL = rgb(176, 180, 184)
local STEEL_DARK = rgb(132, 136, 140)

-- The scalpel: a No. 4 handle and a No. 22 blade. Its space: the blade's TIP at the origin,
-- the instrument along +Z (blade z 0..0.2, handle z 0.2..0.75), lying flat (Y up). The
-- cutting edge is on the +X side (the spine on -X): to cut, turn it so +X points down.
BenchLayout.SCALPEL = table.freeze({
	{
		name = "Blade",
		size = V(0.012, 0.07, 0.2),
		at = CF(-0.035, 0, 0.1) * ANG(0, 0, rad(90)),
		color = rgb(206, 210, 214),
		material = Enum.Material.Metal,
		reflectance = 0.45,
		shape = "Wedge",
	},
	{
		name = "Spine",
		size = V(0.012, 0.018, 0.2),
		at = CF(-0.074, 0, 0.12),
		color = rgb(190, 194, 198),
		material = Enum.Material.Metal,
		reflectance = 0.4,
	},
	{
		name = "Handle",
		size = V(0.06, 0.035, 0.55),
		at = CF(-0.05, 0, 0.475),
		color = STEEL,
		material = Enum.Material.Metal,
		reflectance = 0.3,
	},
	{
		name = "Knurl",
		size = V(0.066, 0.042, 0.02),
		at = CF(-0.05, 0, 0.5),
		color = STEEL_DARK,
		material = Enum.Material.Metal,
		reflectance = 0.1,
	},
	{
		name = "Knurl",
		size = V(0.066, 0.042, 0.02),
		at = CF(-0.05, 0, 0.54),
		color = STEEL_DARK,
		material = Enum.Material.Metal,
		reflectance = 0.1,
	},
	{
		name = "Knurl",
		size = V(0.066, 0.042, 0.02),
		at = CF(-0.05, 0, 0.58),
		color = STEEL_DARK,
		material = Enum.Material.Metal,
		reflectance = 0.1,
	},
	{
		name = "Knurl",
		size = V(0.066, 0.042, 0.02),
		at = CF(-0.05, 0, 0.62),
		color = STEEL_DARK,
		material = Enum.Material.Metal,
		reflectance = 0.1,
	},
} :: { Piece })

-- A small self-retaining retractor clip. Its space: the two hooks' middle at the origin
-- (they bite the panel's rim), the clip along +Z (rings at z 0.3), lying flat (Y up).
local function buildClipPieces(): { Piece }
	local list: { Piece } = {}
	local function add(name: string, size: Vector3, at: CFrame, shape: ("Block" | "Cylinder")?)
		table.insert(list, {
			name = name,
			size = size,
			at = at,
			color = STEEL,
			material = Enum.Material.Metal,
			reflectance = 0.3,
			shape = shape,
		})
	end
	for _, side in { -1, 1 } do
		-- each arm: 3 short segments bowing out, from the hook (z 0) to the ring (z 0.3)
		local points = {
			V(side * 0.03, 0, 0),
			V(side * 0.06, 0, 0.09),
			V(side * 0.065, 0, 0.18),
			V(side * 0.05, 0, 0.27),
		}
		for k = 1, 3 do
			local a, b = points[k], points[k + 1]
			local middle = (a + b) / 2
			add("Arm", V(0.025, 0.025, (b - a).Magnitude + 0.02), CFrame.lookAt(middle, b))
		end
		-- the 3-prong hook (tiny cubes bent down)
		for k = -1, 1 do
			add("Prong", V(0.016, 0.03, 0.016), CF(side * 0.03 + k * 0.014, -0.012, -0.01))
		end
		-- the finger ring (a thin disc lying flat)
		add("Ring", V(0.012, 0.07, 0.07), CF(side * 0.05, 0, 0.3) * ANG(0, 0, rad(90)), "Cylinder")
	end
	-- the ratchet bar across the arms
	add("Ratchet", V(0.17, 0.018, 0.028), CF(0, 0.012, 0.2))
	return list
end
BenchLayout.CLIP = table.freeze(buildClipPieces())

------------------------------------------------------------------------------
-- The static kit (server, once)
------------------------------------------------------------------------------

local function makePiece(piece: Piece): BasePart
	local part: BasePart
	if piece.shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
		if piece.shape == "Cylinder" then
			(part :: Part).Shape = Enum.PartType.Cylinder
		end
	end
	part.Name = piece.name
	part.Size = piece.size
	part.Color = piece.color
	part.Material = piece.material
	part.Reflectance = piece.reflectance
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Builds a tool's pieces as one static model at `at` (world).
local function staticTool(name: string, pieces: { Piece }, at: CFrame, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	for _, piece in pieces do
		local part = makePiece(piece)
		part.CFrame = at * piece.at
		part:SetAttribute("SceneHidden", true)
		part.Parent = model
	end
	model.WorldPivot = at
	model.Parent = parent
	return model
end

-- Builds the static bench kit at the BenchAnchor's CFrame `anchor` (world) into `parent`.
function BenchLayout.buildStatic(parent: Instance, anchor: CFrame): Model
	local kit = Instance.new("Model")
	kit.Name = "BenchKit"

	-- (one helper: a box in anchor space; `solid` = players collide with it)
	local function box(
		name: string,
		size: Vector3,
		at: CFrame,
		color: Color3,
		material: Enum.Material,
		into: Instance?,
		solid: boolean?,
		extra: { [string]: any }?
	): BasePart
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = anchor * at
		part.Color = color
		part.Material = material
		part.Anchored = true
		part.CanCollide = solid == true
		part.CanQuery = solid == true
		part.CanTouch = false
		part.CastShadow = solid == true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if extra then
			for key, value in extra do
				(part :: any)[key] = value
			end
		end
		part.Parent = into or kit
		return part
	end

	local steel = rgb(128, 132, 134)
	local enamel = rgb(214, 212, 202)

	-- Underpad under the shell: absorbent, folded thick (dull blue-grey, not a white sheet).
	local pad = BenchLayout.UNDERPAD
	box("Underpad", pad.size, CF(pad.centre), rgb(96, 118, 132), Enum.Material.Fabric)

	-- A steel tray: floor + 4 lips (lips stand on the floor's edge, never coplanar with it).
	local function tray(name: string, centre: Vector3, size: Vector3): Model
		local model = Instance.new("Model")
		model.Name = name
		local floor = BenchLayout.TRAY_FLOOR
		local lip = 0.025
		local extra = { Reflectance = 0.08 }
		box(
			"Floor",
			V(size.X, floor, size.Z),
			CF(centre + V(0, floor / 2, 0)),
			steel,
			Enum.Material.Metal,
			model,
			false,
			extra
		)
		for _, side in { -1, 1 } do
			box(
				"Lip",
				V(size.X, size.Y, lip),
				CF(centre + V(0, size.Y / 2, side * (size.Z / 2 - lip / 2))),
				steel,
				Enum.Material.Metal,
				model,
				false,
				extra
			)
			box(
				"Lip",
				V(lip, size.Y, size.Z - lip * 2),
				CF(centre + V(side * (size.X / 2 - lip / 2), size.Y / 2, 0)),
				steel,
				Enum.Material.Metal,
				model,
				false,
				extra
			)
		end
		model.Parent = kit
		return model
	end

	-- Instrument tray: towel, gauze, the rest scalpel and clips.
	local it = BenchLayout.INSTRUMENT_TRAY
	local instruments = tray("InstrumentTray", it.centre, it.size)
	box(
		"Towel",
		V(1.0, 0.01, 0.34),
		CF(V(-2.35, BenchLayout.TRAY_FLOOR + 0.005, it.centre.Z)),
		rgb(88, 104, 96),
		Enum.Material.Fabric,
		instruments
	)
	staticTool(
		"Scalpel",
		BenchLayout.SCALPEL :: any,
		anchor * BenchLayout.SCALPEL_REST,
		instruments
	)
	for k, rest in BenchLayout.CLIP_RESTS do
		staticTool(`Clip{k}`, BenchLayout.CLIP :: any, anchor * rest, instruments)
	end

	-- Specimen tray: ribbed mat and drain channel.
	local st = BenchLayout.SPECIMEN_TRAY
	local specimen = tray("SpecimenTray", st.centre, st.size)
	local matTop = BenchLayout.MAT_TOP
	local matBase = 0.014
	box(
		"Mat",
		V(0.86, matBase, 0.42),
		CF(st.centre + V(-0.09, BenchLayout.TRAY_FLOOR + matBase / 2, 0)),
		rgb(44, 48, 50),
		Enum.Material.Rubber,
		specimen
	)
	for k = 1, 5 do
		box(
			"Rib",
			V(0.84, matTop - BenchLayout.TRAY_FLOOR - matBase, 0.03),
			CF(
				st.centre
					+ V(
						-0.09,
						(BenchLayout.TRAY_FLOOR + matBase + matTop) / 2,
						-0.16 + (k - 1) * 0.08
					)
			),
			rgb(52, 56, 58),
			Enum.Material.Rubber,
			specimen
		)
	end
	local drain = BenchLayout.DRAIN
	box(
		"Drain",
		V(drain.size.X, 0.004, drain.size.Z),
		CF(drain.centre),
		rgb(70, 74, 78),
		Enum.Material.Metal,
		specimen
	)

	-- The pass-box.
	local pb = BenchLayout.PASS_BOX
	local box3 = Instance.new("Model")
	box3.Name = "PassBox"
	local w = pb.wall
	local x0, x1 = pb.centre.X - pb.size.X / 2, pb.centre.X + pb.size.X / 2
	local z0, z1 = pb.centre.Z - pb.size.Z / 2, pb.centre.Z + pb.size.Z / 2
	local y0, yTop = pb.floor, pb.deckTop
	local deck = 0.06
	local wallTop = yTop - deck
	local height = wallTop - y0
	local midY = (y0 + wallTop) / 2
	local function wallPart(name: string, size: Vector3, at: Vector3)
		box(name, size, CF(at), enamel, Enum.Material.SmoothPlastic, box3, true)
	end
	-- side walls (full depth), back wall (between them), bottom
	wallPart("Side", V(w, height, pb.size.Z), V(x0 + w / 2, midY, pb.centre.Z))
	wallPart("Side", V(w, height, pb.size.Z), V(x1 - w / 2, midY, pb.centre.Z))
	wallPart("Back", V(pb.size.X - 2 * w, height, w), V(pb.centre.X, midY, z1 - w / 2))
	wallPart(
		"Bottom",
		V(pb.size.X - 2 * w, w, pb.size.Z - 2 * w),
		V(pb.centre.X, y0 + w / 2, pb.centre.Z)
	)
	-- front wall with the window hole: 4 pieces around it
	local win = BenchLayout.WINDOW
	local wx0, wx1 = win.centre.X - win.size.X / 2, win.centre.X + win.size.X / 2
	local wy0, wy1 = win.centre.Y - win.size.Y / 2, win.centre.Y + win.size.Y / 2
	local innerW = pb.size.X - 2 * w
	local fz = z0 + w / 2
	wallPart("Front", V(innerW, wy0 - y0, w), V(pb.centre.X, (y0 + wy0) / 2, fz))
	wallPart("Front", V(innerW, wallTop - wy1, w), V(pb.centre.X, (wy1 + wallTop) / 2, fz))
	wallPart("Front", V(wx0 - (x0 + w), wy1 - wy0, w), V((x0 + w + wx0) / 2, win.centre.Y, fz))
	wallPart("Front", V((x1 - w) - wx1, wy1 - wy0, w), V((wx1 + x1 - w) / 2, win.centre.Y, fz))
	-- the kick plate (darker band at the foot, proud of the walls) and the compressor grille
	box(
		"KickPlate",
		V(pb.size.X + 0.03, 0.22, pb.size.Z + 0.03),
		CF(V(pb.centre.X, y0 + 0.11, pb.centre.Z)),
		rgb(86, 86, 82),
		Enum.Material.Metal,
		box3
	)
	for k = 1, 4 do
		box(
			"Grille",
			V(0.8, 0.03, 0.015),
			CF(V(pb.centre.X, y0 + 0.4 + k * 0.09, z0 - 0.0075)),
			rgb(70, 72, 70),
			Enum.Material.Metal,
			box3
		)
	end
	-- duct tape on the front-left corner, a chipped spot
	box(
		"Tape",
		V(0.24, 0.5, 0.012),
		CF(V(x1 - 0.1, -0.45, z0 - 0.006)),
		rgb(122, 124, 118),
		Enum.Material.Fabric,
		box3
	)
	box(
		"Chip",
		V(0.07, 0.05, 0.01),
		CF(V(x0 + 0.2, -2.1, z0 - 0.004)),
		rgb(70, 60, 50),
		Enum.Material.SmoothPlastic,
		box3
	)
	-- the steel deck with its square opening (4 plates)
	local half = pb.opening / 2
	local deckY = yTop - deck / 2
	local deckColor = rgb(150, 154, 156)
	local function deckPlate(size: Vector3, at: Vector3)
		box(
			"Deck",
			size,
			CF(at),
			deckColor,
			Enum.Material.DiamondPlate,
			box3,
			true,
			{ Reflectance = 0.05 }
		)
	end
	deckPlate(
		V(pb.size.X, deck, (pb.centre.Z - half) - z0),
		V(pb.centre.X, deckY, (z0 + pb.centre.Z - half) / 2)
	)
	deckPlate(
		V(pb.size.X, deck, z1 - (pb.centre.Z + half)),
		V(pb.centre.X, deckY, (pb.centre.Z + half + z1) / 2)
	)
	deckPlate(
		V((pb.centre.X - half) - x0, deck, pb.opening),
		V((x0 + pb.centre.X - half) / 2, deckY, pb.centre.Z)
	)
	deckPlate(
		V(x1 - (pb.centre.X + half), deck, pb.opening),
		V((pb.centre.X + half + x1) / 2, deckY, pb.centre.Z)
	)
	-- the funnel: 4 sloped plates from the opening's edges down to the exit square
	local exit = BenchLayout.FUNNEL_EXIT
	local exitHalf = 0.15
	local topY = yTop - deck - 0.005
	local funnelColor = rgb(160, 164, 166)
	local corners = {
		{
			V(pb.centre.X - half, topY, pb.centre.Z - half),
			V(exit.X - exitHalf, exit.Y, exit.Z - exitHalf),
		},
		{
			V(pb.centre.X + half, topY, pb.centre.Z - half),
			V(exit.X + exitHalf, exit.Y, exit.Z - exitHalf),
		},
		{
			V(pb.centre.X + half, topY, pb.centre.Z + half),
			V(exit.X + exitHalf, exit.Y, exit.Z + exitHalf),
		},
		{
			V(pb.centre.X - half, topY, pb.centre.Z + half),
			V(exit.X - exitHalf, exit.Y, exit.Z + exitHalf),
		},
	}
	for k = 1, 4 do
		local a, b = corners[k], corners[k % 4 + 1]
		local topMid = (a[1] + b[1]) / 2
		local lowMid = (a[2] + b[2]) / 2
		local along = (b[1] - a[1]).Unit
		local down = lowMid - topMid
		local width = ((b[1] - a[1]).Magnitude + (b[2] - a[2]).Magnitude) / 2
		local centre = (topMid + lowMid) / 2
		local normal = along:Cross(down.Unit).Unit
		local frame = CFrame.fromMatrix(centre, along, down.Unit, normal)
		box("Funnel", V(width, down.Magnitude, 0.02), frame, funnelColor, Enum.Material.Metal, box3)
	end
	-- the inside light (a teal strip under the deck, lighting the capsules from above)
	local strip = box(
		"InnerLight",
		V(0.7, 0.02, 0.06),
		CF(V(pb.centre.X, wallTop - 0.04, z0 + w + 0.1)),
		rgb(170, 235, 225),
		Enum.Material.Neon,
		box3
	)
	local glow = Instance.new("SurfaceLight")
	glow.Name = "WindowGlow"
	glow.Face = Enum.NormalId.Bottom
	glow.Color = rgb(170, 235, 225)
	glow.Brightness = 0.6
	glow.Range = 3
	glow.Angle = 120
	glow.Shadows = false
	glow.Parent = strip
	-- the window: a frame proud of the wall, two panes standing off it and each other
	local frameColor = rgb(176, 176, 168)
	local fw = 0.05
	local frontZ = z0
	box(
		"WindowFrame",
		V(win.size.X + 2 * fw, fw, 0.03),
		CF(V(win.centre.X, wy1 + fw / 2, frontZ - 0.015)),
		frameColor,
		Enum.Material.Metal,
		box3
	)
	box(
		"WindowFrame",
		V(win.size.X + 2 * fw, fw, 0.03),
		CF(V(win.centre.X, wy0 - fw / 2, frontZ - 0.015)),
		frameColor,
		Enum.Material.Metal,
		box3
	)
	box(
		"WindowFrame",
		V(fw, win.size.Y, 0.03),
		CF(V(wx0 - fw / 2, win.centre.Y, frontZ - 0.015)),
		frameColor,
		Enum.Material.Metal,
		box3
	)
	box(
		"WindowFrame",
		V(fw, win.size.Y, 0.03),
		CF(V(wx1 + fw / 2, win.centre.Y, frontZ - 0.015)),
		frameColor,
		Enum.Material.Metal,
		box3
	)
	local paneLook = { Transparency = 0.82, Reflectance = 0.12 }
	box(
		"PassWindow",
		V(win.size.X - 0.01, win.size.Y - 0.01, 0.012),
		CF(V(win.centre.X, win.centre.Y, frontZ + 0.012)),
		rgb(205, 222, 226),
		Enum.Material.SmoothPlastic,
		box3,
		false,
		paneLook
	)
	box(
		"PaneInner",
		V(win.size.X - 0.01, win.size.Y - 0.01, 0.012),
		CF(V(win.centre.X, win.centre.Y, frontZ + w + 0.012)),
		rgb(205, 222, 226),
		Enum.Material.SmoothPlastic,
		box3,
		false,
		paneLook
	)
	-- frost slivers on the inner pane's edges (Ice, see-through)
	for _, at in { V(wx0 + 0.05, win.centre.Y - 0.25, 0), V(wx1 - 0.06, win.centre.Y + 0.3, 0) } do
		box(
			"Frost",
			V(0.05, 0.4, 0.01),
			CF(V(at.X, at.Y, frontZ + w + 0.035)),
			rgb(226, 238, 244),
			Enum.Material.Ice,
			box3,
			false,
			{ Transparency = 0.4 }
		)
	end
	for _, at in { V(win.centre.X - 0.2, wy0 + 0.04, 0), V(win.centre.X + 0.25, wy1 - 0.04, 0) } do
		box(
			"Frost",
			V(0.3, 0.04, 0.01),
			CF(V(at.X, at.Y, frontZ + w + 0.035)),
			rgb(226, 238, 244),
			Enum.Material.Ice,
			box3,
			false,
			{ Transparency = 0.4 }
		)
	end
	-- the strip display (black plate proud of the wall; the only text on the box)
	local dsp = BenchLayout.DISPLAY
	local display = box(
		"PassDisplay",
		V(dsp.size.X, dsp.size.Y, 0.02),
		CF(V(dsp.centre.X, dsp.centre.Y, frontZ - 0.01)),
		rgb(10, 12, 12),
		Enum.Material.SmoothPlastic,
		box3
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "StripGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 200
	gui.LightInfluence = 0
	gui.Brightness = 1
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.RobotoMono
	label.TextSize = 14
	label.TextColor3 = rgb(150, 236, 214)
	label.Text = "STANDBY"
	label.Parent = gui
	gui.Parent = display
	-- the hatch lid (enamel, black gasket under it), its pneumatic strut, the grate, the
	-- carousel: the moving parts (hidden for the extractor while his scene runs)
	local hinge = BenchLayout.LID_HINGE
	local lid = box(
		"Lid",
		V(0.7, 0.08, 0.7),
		CF(V(hinge.X - 0.35, 0.21, hinge.Z)),
		enamel,
		Enum.Material.SmoothPlastic,
		box3
	)
	lid:SetAttribute("SceneHidden", true)
	local gasket = box(
		"LidGasket",
		V(0.66, 0.02, 0.66),
		CF(V(hinge.X - 0.35, 0.16, hinge.Z)),
		rgb(24, 24, 24),
		Enum.Material.Rubber,
		box3
	)
	gasket:SetAttribute("SceneHidden", true)
	local handle = box(
		"LidHandle",
		V(0.06, 0.04, 0.3),
		CF(V(hinge.X - 0.66, 0.27, hinge.Z)),
		rgb(60, 62, 64),
		Enum.Material.Metal,
		box3
	)
	handle:SetAttribute("SceneHidden", true)
	box(
		"Strut",
		V(0.35, 0.05, 0.05),
		CF(V(hinge.X + 0.08, 0.2, hinge.Z + 0.38)) * ANG(0, 0, rad(30)),
		rgb(40, 42, 44),
		Enum.Material.Metal,
		box3
	)
	for k = 1, 10 do
		local z = pb.centre.Z - half + (k - 0.5) * pb.opening / 10
		local bar = box(
			"GrateBar",
			V(pb.opening, 0.03, 0.035),
			CF(V(pb.centre.X, BenchLayout.GRATE_Y, z)),
			rgb(170, 174, 176),
			Enum.Material.Metal,
			box3
		)
		bar:SetAttribute("SceneHidden", true)
	end
	-- the well's inner shutter, CLOSED (a steel slat right behind the inner pane): the
	-- stored capsules are behind it. The extractor's client opens its own copy in the scene.
	local shutter = box(
		"Shutter",
		V(win.size.X + 0.06, win.size.Y + 0.06, 0.02),
		CF(V(win.centre.X, win.centre.Y, frontZ + w + 0.06)),
		rgb(150, 154, 156),
		Enum.Material.DiamondPlate,
		box3
	)
	shutter:SetAttribute("SceneHidden", true)
	box3.Parent = kit

	kit.WorldPivot = anchor
	kit.Parent = parent
	return kit
end

return BenchLayout
