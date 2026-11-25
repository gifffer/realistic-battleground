--!strict
-- AptProps: the furniture and clutter of the hidden-lab flat ("Flat 4B"), built from plain parts
-- and built-in materials only (no uploaded mesh, image or decal). LabBuilder calls these.
--
-- HOW A BUILDER WORKS
--   AptProps.<name>(parent, at, rng, ...) -> Model
--   • `at` is a world CFrame: the point ON THE FLOOR at the centre of the prop's footprint
--     (unless the builder's comment says otherwise), turned so that the prop's FRONT looks
--     along `at.LookVector` (its local -Z). Every part is placed with `at * offset`.
--   • `rng` is the flat's seeded Random (Random.new(owner)): the same flat looks the same on
--     every visit, but two players' flats differ a little (small turns, sizes, colours).
--   • Each builder makes one Model (3-40 parts) and gives it ONE "story" detail (tape, a dent,
--     a label, a stain...). Text is written with SurfaceGui + TextLabel (no decals).
--
-- PART RULES (keep them: they protect the frame rate and the camera)
--   • Everything is Anchored and CanTouch = false.
--   • Decor: CanCollide = false, CanQuery = false. Only `solid` looks collide (big furniture
--     you would bump into); walls/floors use `wall` looks (they also block the camera).
--   • Small parts (every side under 1 stud) and see-through parts cast no shadow.
--
-- ART RULES (from the player; never break them)
--   • A poor, run-down flat with a CLANDESTINE BIOTECH lab in the back bedroom: salvage,
--     appliances, plastic sheeting, cords, coolers, aquarium pumps. Never a clean clinic.
--   • NEVER anything that reads "drug lab": no glassware / flasks / beakers, crystals, powder,
--     scales, pills, syringes, needles, baggies, vials, gas masks + chemicals, burners,
--     magenta grow lights, red liquids. No tobacco, no alcohol anywhere.
--   • The only red in the whole flat is the TV's tiny standby LED in the living room.

local AptProps = {}

local M = Enum.Material
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

------------------------------------------------------------------------------
-- Looks (material + colour + flags) and the part helpers
------------------------------------------------------------------------------

export type Look = {
	material: Enum.Material,
	color: Color3,
	transparency: number,
	reflectance: number,
	collide: boolean, -- blocks characters
	query: boolean, -- seen by raycasts (the camera stops on it)
}

-- A look: material + colour (0-255) + optional transparency / reflectance. Does not collide.
function AptProps.look(
	material: Enum.Material,
	r: number,
	g: number,
	b: number,
	transparency: number?,
	reflectance: number?
): Look
	return {
		material = material,
		color = Color3.fromRGB(r, g, b),
		transparency = transparency or 0,
		reflectance = reflectance or 0,
		collide = false,
		query = false,
	}
end
local look = AptProps.look

-- The same look, but characters bump into it (big furniture).
function AptProps.solid(base: Look): Look
	local copy = table.clone(base)
	copy.collide = true
	return copy
end
local solid = AptProps.solid

-- The same look for walls / floors / ceilings: collides AND stops the camera.
function AptProps.wall(base: Look): Look
	local copy = table.clone(base)
	copy.collide = true
	copy.query = true
	return copy
end

-- The same look with its colour moved by up to ±`amount` (default 8) on each channel.
function AptProps.tint(base: Look, rng: Random, amount: number?): Look
	local spread = amount or 8
	local copy = table.clone(base)
	local function channel(value: number): number
		return math.clamp(value * 255 + rng:NextInteger(-spread, spread), 0, 255)
	end
	copy.color = Color3.fromRGB(channel(base.color.R), channel(base.color.G), channel(base.color.B))
	return copy
end
local tint = AptProps.tint

-- A small random turn (2..12 degrees, random sign), in radians: "nothing is perfectly straight".
function AptProps.jitterAngle(rng: Random, minDeg: number?, maxDeg: number?): number
	local angle = rad(rng:NextNumber(minDeg or 2, maxDeg or 12))
	return if rng:NextNumber() < 0.5 then -angle else angle
end
local jitterAngle = AptProps.jitterAngle

-- One anchored part. Cylinders run along their local X (Roblox's rule).
function AptProps.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	l: Look,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Material = l.material
	part.Color = l.color
	part.Transparency = l.transparency
	part.Reflectance = l.reflectance
	part.CanCollide = l.collide
	part.CanQuery = l.query
	part.CanTouch = false
	-- (small clutter and see-through parts: no shadow, it costs and looks noisy)
	local biggest = math.max(size.X, size.Y, size.Z)
	part.CastShadow = biggest >= 1 and l.transparency < 0.3 and l.material ~= M.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end
local part = AptProps.part

-- A cylinder (or a block when `square`) from world point `a` to world point `b`.
function AptProps.rod(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	l: Look,
	square: boolean?
): Part
	local length = (b - a).Magnitude
	local middle = (a + b) / 2
	local direction = (b - a).Unit
	local frame: CFrame
	if math.abs(direction.Y) > 0.999 then
		-- (straight up or down: lookAt cannot use "up" as its up vector)
		frame = CF(middle) * ANG(0, 0, rad(90))
	else
		-- lookAt points -Z at `b`; a quarter turn puts the cylinder's X axis there instead
		frame = CFrame.lookAt(middle, b) * ANG(0, rad(90), 0)
	end
	return part(
		parent,
		name,
		V(length, diameter, diameter),
		frame,
		l,
		if square then Enum.PartType.Block else Enum.PartType.Cylinder
	)
end
local rod = AptProps.rod

-- Rods through a list of world points (cords, hoses, tubing). `joints` adds a ball at each
-- inner point so thick hoses have no gaps at the bends.
function AptProps.path(
	parent: Instance,
	name: string,
	points: { Vector3 },
	diameter: number,
	l: Look,
	joints: boolean?
): { Part }
	local made = {}
	for i = 1, #points - 1 do
		if (points[i + 1] - points[i]).Magnitude > 0.02 then
			table.insert(made, rod(parent, name, points[i], points[i + 1], diameter, l))
		end
		if joints and i > 1 then
			table.insert(
				made,
				part(
					parent,
					name,
					V(diameter, diameter, diameter),
					CF(points[i]),
					l,
					Enum.PartType.Ball
				)
			)
		end
	end
	return made
end
local path = AptProps.path

-- A hanging cord between two world points: `segments` rods along a sagging curve.
function AptProps.catenary(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	sag: number,
	segments: number,
	diameter: number,
	l: Look
): { Part }
	local points = {}
	for i = 0, segments do
		local t = i / segments
		local drop = 4 * sag * t * (1 - t) -- a parabola: 0 at both ends, `sag` in the middle
		table.insert(points, a:Lerp(b, t) - V(0, drop, 0))
	end
	return path(parent, name, points, diameter, l)
end
local catenary = AptProps.catenary

-- Writes `text` on one face of `target` (a SurfaceGui + TextLabel; no decal, no upload).
function AptProps.text(
	target: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	font: Enum.Font?,
	pixelsPerStud: number?
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Writing"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 60
	gui.LightInfluence = 1
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = font or Enum.Font.PermanentMarker
	label.TextColor3 = color
	label.Parent = gui
	return label
end
local writeOn = AptProps.text

-- Starts a prop: a Model under `parent` and an `add` function that places parts relative to
-- `at` (offsets are local: +X right, +Y up, -Z = the prop's front).
type Adder = (
	name: string,
	size: Vector3,
	offset: CFrame,
	l: Look,
	shape: Enum.PartType?
) -> Part
local function begin(parent: Instance, name: string, at: CFrame): (Model, Adder)
	local model = Instance.new("Model")
	model.Name = name
	model.WorldPivot = at
	model.Parent = parent
	local function add(
		partName: string,
		size: Vector3,
		offset: CFrame,
		l: Look,
		shape: Enum.PartType?
	): Part
		return part(model, partName, size, at * offset, l, shape)
	end
	return model, add
end

-- Turns used everywhere: a cylinder standing up, a cylinder along Z.
local UP = ANG(0, 0, rad(90))
local ALONG_Z = ANG(0, rad(90), 0)
local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local WEDGE = Enum.PartType.Wedge

-- A few shared looks.
local TAPE = look(M.Fabric, 140, 140, 132)
local CORD_BLACK = look(M.Plastic, 30, 30, 30)
local CORD_WHITE = look(M.Plastic, 170, 166, 154) -- (an old grubby white)
local CORD_BLUE = look(M.Plastic, 60, 62, 120)
local CORD_LOOKS = { CORD_BLACK, CORD_WHITE, CORD_BLUE, CORD_BLACK, CORD_WHITE, CORD_BLACK }
-- (plastic sheeting: SmoothPlastic, never Material Glass, which hides every see-through part
-- behind it)
local SHEET = look(M.SmoothPlastic, 200, 210, 210, 0.62, 0.12)

------------------------------------------------------------------------------
-- Overlays (paint, paper, stains, tape, scuffs) and z-fighting
------------------------------------------------------------------------------

-- Two faces that lie (almost) in the same plane fight for the same pixels: the screen shows one,
-- then the other, and the surface flickers as the camera moves ("z-fighting"). So every flat
-- detail here is an OVERLAY: a thin slab that starts ON the surface and ends a fixed distance in
-- front of it, and each level is at least 0.03 studs in front of the one under it. Levels,
-- measured from a wall / floor / top face:
AptProps.LAYER = table.freeze({
	PAINT = 0.05, -- lower paint, wallpaper, floor sheeting, a missing tile's adhesive
	STAIN = 0.08, -- the first stain layer (each extra layer adds STEP)
	MARK = 0.14, -- tide marks and marks drawn over stains
	STEP = 0.03, -- the smallest gap between two levels
})
local LAYER = AptProps.LAYER

-- One overlay: `size` = width (local X) and height (local Y) on the surface; `at` = the overlay's
-- centre ON the surface, its LookVector pointing out of the surface; `front` = how far its visible
-- face stands in front of the surface (a LAYER value). The slab fills the gap down to the surface,
-- so it never floats and never shares a plane with what is under it.
function AptProps.overlay(
	parent: Instance,
	name: string,
	size: Vector2,
	at: CFrame,
	front: number,
	l: Look,
	shape: Enum.PartType?
): Part
	local made = part(parent, name, V(size.X, size.Y, front), at * CF(0, 0, -front / 2), l, shape)
	made.CastShadow = false
	return made
end
local overlay = AptProps.overlay
local YELLOWED = look(M.SmoothPlastic, 214, 210, 196)
local RUST = look(M.CorrodedMetal, 110, 80, 60)
local PAPER = look(M.SmoothPlastic, 228, 224, 210)
local INK = Color3.fromRGB(34, 32, 30)

------------------------------------------------------------------------------
-- Shell dressing (walls, floors, ceilings)
------------------------------------------------------------------------------

-- A stain: 2 opaque overlays, darker than the surface, turned differently (no decal). They sit
-- at LAYER.STAIN and LAYER.STAIN + STEP, in front of any paint or paper on that wall.
-- `at`: the centre ON the surface, its LookVector = out of the surface. `size`: width, height.
function AptProps.stain(parent: Instance, at: CFrame, size: Vector2, base: Color3, rng: Random)
	local layers = 2
	for i = 1, layers do
		-- (30-45 darker than the surface: lighter stains vanish once graded in game)
		local darker = rng:NextInteger(22, 34) * (0.6 + 0.4 * i / layers) + 10
		local color = Color3.fromRGB(
			math.max(0, base.R * 255 - darker),
			math.max(0, base.G * 255 - darker * 0.95),
			math.max(0, base.B * 255 - darker * 1.1)
		)
		local scale = 1 - (i - 1) * 0.22
		overlay(
			parent,
			"Stain",
			Vector2.new(
				size.X * scale * rng:NextNumber(0.8, 1.1),
				size.Y * scale * rng:NextNumber(0.8, 1.1)
			),
			at
				* CF(rng:NextNumber(-0.15, 0.15) * size.X, rng:NextNumber(-0.15, 0.15) * size.Y, 0)
				* ANG(0, 0, rad(rng:NextNumber(5, 30))),
			LAYER.STAIN + (i - 1) * LAYER.STEP,
			{
				material = M.Plaster,
				color = color,
				transparency = 0,
				reflectance = 0,
				collide = false,
				query = false,
			}
		)
	end
end

-- Wallpaper strips on one wall face. `at`: the bottom-left corner of the run ON the wall,
-- LookVector = out of the wall, +X along the wall. `length` along the wall, `height` up.
-- `peel` strips get a separate curled top (hinged at its bottom edge, the plaster behind
-- shows darker).
function AptProps.wallpaper(
	parent: Instance,
	at: CFrame,
	length: number,
	height: number,
	tones: { Color3 },
	peel: number,
	rng: Random,
	skip: { NumberRange }?,
	bottom: number?
)
	local base = bottom or 0.6 -- (where the paper starts: above the skirting, or the dado)
	local x = 0
	local index = 0
	local peeled = 0
	while x < length - 0.3 do
		local width = math.min(rng:NextNumber(1.6, 2.2), length - x)
		index += 1
		local blocked = false
		local ranges: { NumberRange } = skip or {}
		for _, range in ranges do
			if x + width > range.Min and x < range.Max then
				blocked = true
			end
		end
		-- (every other strip only: the wall's own colour is the other tone)
		if not blocked and index % 2 == 0 then
			local tone = tones[(index // 2) % #tones + 1]
			local stripLook = tint(look(M.Plaster, 0, 0, 0), rng, 0)
			stripLook.color = tone
			local curl = peeled < peel and rng:NextNumber() < 0.45
			local top = if curl then height - rng:NextNumber(1, 2) else height
			-- (the paper is a PAINT-level overlay; it stops 0.02 under the ceiling so its top face
			-- never lies in the ceiling's plane)
			local topY = math.min(top, height - 0.02)
			overlay(
				parent,
				"Wallpaper",
				Vector2.new(width, topY - base),
				at * CF(x + width / 2, base + (topY - base) / 2, 0),
				LAYER.PAINT,
				stripLook
			)
			if curl then
				peeled += 1
				local flap = height - 0.02 - top
				-- the darker plaster under the peeled bit (thinner than the paper: it is the wall)
				overlay(
					parent,
					"WallpaperScar",
					Vector2.new(width * 0.9, flap),
					at * CF(x + width / 2, top + flap / 2, 0),
					LAYER.STEP,
					look(M.Plaster, 110, 104, 90)
				)
				-- the flap itself, hinged at the paper's front bottom edge, curled out 6-15 degrees
				part(
					parent,
					"WallpaperFlap",
					V(width, flap, 0.02),
					at
						* CF(x + width / 2, top, -LAYER.PAINT)
						* ANG(-rad(rng:NextNumber(6, 15)), 0, 0)
						* CF(0, flap / 2, -0.01),
					stripLook
				)
			end
		end
		x += width
	end
end

-- Skirting board along a wall face (+ a few paint chips). `at`: start of the run on the floor,
-- ON the wall face, LookVector = out of the wall, +X along the wall.
function AptProps.skirting(
	parent: Instance,
	at: CFrame,
	length: number,
	rng: Random,
	dado: boolean?,
	trimStart: boolean?,
	trimEnd: boolean?
)
	-- (at an inside corner two runs meet: `trimStart` / `trimEnd` shorten this run by each
	-- element's own depth so it BUTTS against the other run instead of overlapping it; two
	-- overlapping boards share their top face and flicker)
	local function piece(name: string, depth: number, y: number, height: number, l: Look)
		local from = if trimStart then depth else 0
		local to = length - (if trimEnd then depth else 0)
		part(parent, name, V(to - from, height, depth), at * CF((from + to) / 2, y, -depth / 2), l)
	end
	local board = look(M.Wood, 176, 170, 150)
	piece("Skirting", 0.3, 0.275, 0.55, board)
	local chips = math.floor(length / 12)
	for _ = 1, chips do
		-- (a chip is an overlay on the board's front face, 0.3 out from the wall)
		overlay(
			parent,
			"Chip",
			Vector2.new(rng:NextNumber(0.15, 0.4), rng:NextNumber(0.08, 0.2)),
			at * CF(rng:NextNumber(0.6, length - 0.6), rng:NextNumber(0.15, 0.45), -0.3),
			LAYER.STEP,
			look(M.Wood, 96, 74, 52)
		)
	end
	if dado then
		-- the old two-tone paint: a dark brown-olive gloss below the dado rail (from the
		-- skirting's top to under the rail: it never shares a face with either)
		piece(
			"LowerPaint",
			LAYER.PAINT,
			0.55 + (3.44 - 0.55) / 2,
			3.44 - 0.55,
			look(M.Plaster, 92, 86, 68)
		)
		-- (the rail stands 0.16 out: in front of any stain layer on the wall)
		piece("DadoRail", 0.16, 3.5, 0.12, look(M.Wood, 132, 122, 100))
	end
end

-- How far a casing's inner faces stand inside the opening (doors are built to clear it).
AptProps.CASING_INSET = 0.03

-- A door casing (frame trim) on both faces of a wall opening. `at`: the opening's bottom
-- centre in the middle of the wall, +X along the wall. `thickness`: the wall's.
function AptProps.casing(
	parent: Instance,
	at: CFrame,
	width: number,
	height: number,
	thickness: number,
	paint: Color3?
)
	local trim = look(M.Wood, 176, 170, 150)
	if paint then
		trim.color = paint
	end
	local depth = thickness + 0.6
	-- The trim covers the wall's cut ends: its inner faces stand CASING_INSET inside the opening
	-- (never in the same plane as the wall's end faces or the lintel's underside), and the side
	-- pieces stop under the head piece (the corners butt, they don't overlap).
	local inset = AptProps.CASING_INSET
	local headBottom = height - inset
	for _, side in { -1, 1 } do
		part(
			parent,
			"Casing",
			V(0.4, headBottom, depth),
			at * CF(side * (width / 2 + 0.2 - inset), headBottom / 2, 0),
			trim
		)
	end
	part(
		parent,
		"Casing",
		V(width + 0.8 - 2 * inset, 0.4, depth),
		at * CF(0, headBottom + 0.2, 0),
		trim
	)
end

------------------------------------------------------------------------------
-- Doors (Doors/Door_<Room>: a Model, the client swings it)
------------------------------------------------------------------------------

export type DoorSpec = {
	room: string,
	mode: "Auto" | "Prompt" | "Locked",
	restAngle: number, -- degrees, the angle it is built at
	openAngle: number, -- degrees (Auto / Prompt doors)
	label: string, -- the prompt's object text
	paint: Color3?,
	floor: number?, -- the height of the floor the leaf swings over (a tiled floor), default 0
}

-- The leaf of every flat door. It stands LIFT above the floor (no gap you can see, no face in the
-- floor's plane) and leaves a hair of room under the casing's head.
AptProps.DOOR_LEAF = table.freeze({ width = 4.4, height = 7.4, thickness = 0.25, lift = 0.02 })
local DOOR_LEAF = AptProps.DOOR_LEAF

-- The frame door details are placed in: on the floor at the leaf's hinge edge, in the MIDDLE of
-- its thickness (+X toward the latch, ±Z = the leaf's two faces at ±thickness / 2). Call it while
-- the door is shut (the builders do, before the rest angle is applied).
function AptProps.leafBase(door: Model): CFrame
	return door.WorldPivot * CF(0, 0, DOOR_LEAF.thickness / 2)
end
local leafBase = AptProps.leafBase

-- A door leaf turning about `hinge` (world CFrame on the floor). +X runs from the hinge to the
-- latch side; a POSITIVE angle swings the latch toward the hinge's local -Z. The hinge line is
-- the leaf's edge ON ITS -Z FACE (the face that leads the swing), like a real butt hinge: the
-- leaf body lies on +Z, so when open it stays inside the doorway's width and never cuts through
-- the casing. The Model's WorldPivot is that hinge line; the leaf is "Leaf" (PrimaryPart).
-- The client turns the whole model with PivotTo(closedPivot * CFrame.Angles(0, angle, 0)).
-- Every leaf is SOLID: ApartmentController only lets you through while it is moving.
function AptProps.door(
	parent: Instance,
	name: string,
	hinge: CFrame,
	spec: DoorSpec,
	rng: Random
): Model
	local model = Instance.new("Model")
	model.Name = name
	local paint = spec.paint or Color3.fromRGB(98, 84, 66)
	local leafLook = tint(look(M.Wood, 0, 0, 0), rng, 0)
	leafLook.color = paint
	leafLook = solid(leafLook)
	local base = hinge * CF(0, 0, DOOR_LEAF.thickness / 2)
	local function add(
		partName: string,
		size: Vector3,
		offset: CFrame,
		l: Look,
		shape: Enum.PartType?
	): Part
		return part(model, partName, size, base * offset, l, shape)
	end
	local half = DOOR_LEAF.thickness / 2
	-- (over a raised floor the leaf starts higher and is shorter: its top stays put)
	local floor = spec.floor or 0
	local lift = DOOR_LEAF.lift + floor
	local height = DOOR_LEAF.height - floor
	local leaf = add(
		"Leaf",
		V(DOOR_LEAF.width, height, DOOR_LEAF.thickness),
		CF(DOOR_LEAF.width / 2, lift + height / 2, 0),
		leafLook
	)
	model.PrimaryPart = leaf
	-- two-tone panels (a hollow door's moulding) on the +Z face, paint chips on the -Z face
	local panel = tint(leafLook, rng, 6)
	panel.collide = false
	panel.color = panel.color:Lerp(Color3.new(0, 0, 0), 0.08)
	add("Panel", V(3.2, 2.6, 0.03), CF(2.2, 5.6, half + 0.015), panel)
	add("Panel", V(3.2, 3.2, 0.03), CF(2.2, 1.9, half + 0.015), panel)
	for _ = 1, rng:NextInteger(1, 2) do
		local chip = overlay(
			model,
			"Chip",
			Vector2.new(rng:NextNumber(0.1, 0.35), rng:NextNumber(0.08, 0.25)),
			base * CF(rng:NextNumber(0.5, 4), rng:NextNumber(0.7, 6.5), -half),
			LAYER.STEP,
			look(M.Wood, 70, 56, 42)
		)
		chip.CastShadow = false
	end
	-- 2 hinge knuckles on the hinge line, and the knob (both sides)
	local brass = look(M.Metal, 138, 120, 84)
	for _, y in { 1.0, 6.6 } do
		-- (thin knuckles just inside the leaf's edge, 0.015 proud of its -Z face: thicker
		-- ones on the hinge line itself went 0.04 into the casing at every angle)
		add("Hinge", V(0.5, 0.07, 0.07), CF(0.015, y, -half + 0.02) * UP, brass, CYL)
	end
	for _, side in { -1, 1 } do
		add("Knob", V(0.24, 0.24, 0.24), CF(3.9, 3.4, side * 0.24), brass, BALL)
	end
	model.WorldPivot = hinge
	model:SetAttribute("Room", spec.room)
	model:SetAttribute("Mode", spec.mode)
	model:SetAttribute("RestAngle", spec.restAngle)
	model:SetAttribute("OpenAngle", spec.openAngle)
	model:SetAttribute("Label", spec.label)
	model.Parent = parent
	return model
end

-- Extra dressing for each door (parts go inside the door model so they swing with it).
-- `side` = +1 / -1: the face of the leaf (the hinge's local ±Z) the detail goes on.
function AptProps.doorPadlock(door: Model, side: number)
	local hinge = leafBase(door)
	local metal = look(M.Metal, 120, 118, 110)
	local z = side * 0.18
	-- (everything stays on the leaf, short of its latch edge: nothing cuts into the casing)
	part(door, "Hasp", V(0.6, 0.18, 0.06), hinge * CF(4.08, 4.6, z), metal)
	part(door, "Staple", V(0.12, 0.3, 0.12), hinge * CF(4.28, 4.6, z + side * 0.05), metal)
	part(
		door,
		"Padlock",
		V(0.32, 0.4, 0.16),
		hinge * CF(4.2, 4.25, z + side * 0.12),
		look(M.Metal, 140, 136, 122)
	)
	part(
		door,
		"Shackle",
		V(0.06, 0.22, 0.22),
		hinge * CF(4.2, 4.53, z + side * 0.12) * ALONG_Z,
		metal,
		CYL
	)
	-- "PRIVATE" in marker pen on the upper panel (an invisible holder 0.02 in front of the
	-- panel's face carries the text; well clear of the hasp and the padlock)
	local plate = part(
		door,
		"Scrawl",
		-- (about 60 % of the first size, well inside the leaf's edges)
		V(1.6, 0.5, 0.01),
		hinge * CF(2.1, 5.9, side * 0.18) * ANG(0, 0, rad(-3)),
		look(M.Wood, 98, 84, 66, 1)
	)
	writeOn(
		plate,
		if side < 0 then Enum.NormalId.Front else Enum.NormalId.Back,
		"PRIVATE",
		Color3.fromRGB(70, 60, 52)
	)
end

-- Three planks screwed across the CASING (not just the leaf): the doorway is boarded up.
function AptProps.doorBoards(door: Model, side: number, rng: Random)
	local hinge = leafBase(door)
	local plank = tint(look(M.WoodPlanks, 120, 96, 70), rng)
	local screw = look(M.Metal, 150, 150, 146)
	-- (the casing's front face stands 0.55 out from the wall's middle; the leaf's middle is
	-- 0.125 the other way: the planks' backs rest on the casing)
	local onCasing = DOOR_LEAF.thickness / 2 + 0.55 + 0.075
	local specs = {
		{ y = 5.0, angle = 25, length = 5.4 },
		{ y = 2.6, angle = -18, length = 5.4 },
		{ y = 6.85, angle = 7, length = 5.2 },
	}
	for i, spec in specs do
		-- (each plank is nailed over the one before: they cross without sharing a face)
		local depth = onCasing + (i - 1) * 0.15
		local board = part(
			door,
			"Plank",
			V(spec.length, 0.6, 0.15),
			hinge * CF(2.2, spec.y, side * depth) * ANG(0, 0, rad(spec.angle)),
			tint(plank, rng, 6)
		)
		for _, x in { -2.45, 2.45 } do
			part(
				door,
				"Screw",
				V(0.06, 0.08, 0.08),
				board.CFrame * CF(x, 0, side * 0.08) * ALONG_Z,
				screw,
				CYL
			)
		end
	end
end

function AptProps.doorLabDetails(door: Model, side: number)
	local hinge = leafBase(door)
	local half = DOOR_LEAF.thickness / 2
	-- (the frame of an overlay on the `side` face: LookVector out of that face)
	local function onFace(x: number, y: number): CFrame
		return hinge
			* CF(x, y, side * half)
			* (if side < 0 then CFrame.identity else ANG(0, math.pi, 0))
	end
	local bright = look(M.Metal, 190, 192, 196, 0, 0.3)
	-- a NEW steel deadbolt + hasp on an old door
	part(door, "Deadbolt", V(0.7, 0.45, 0.16), hinge * CF(3.95, 4.3, side * 0.2), bright)
	part(door, "Deadbolt", V(0.7, 0.45, 0.16), hinge * CF(3.95, 4.3, -side * 0.2), bright)
	part(door, "Hasp", V(0.7, 0.16, 0.05), hinge * CF(4.0, 5.1, side * 0.16), bright)
	-- the plywood patch screwed over a punched hole
	local patch = part(
		door,
		"Patch",
		V(1.6, 1.4, 0.06),
		hinge * CF(1.9, 3.1, side * 0.16) * ANG(0, 0, rad(4)),
		look(M.WoodPlanks, 150, 120, 84)
	)
	for _, corner in { V(-0.65, 0.55, 0), V(0.65, 0.55, 0), V(-0.65, -0.55, 0), V(0.65, -0.55, 0) } do
		part(
			door,
			"Screw",
			V(0.05, 0.07, 0.07),
			patch.CFrame * CF(corner + V(0, 0, side * 0.04)) * ALONG_Z,
			bright,
			CYL
		)
	end
	-- foil tape sealing the bottom, the top and the hinge edge (it catches the teal glow), a
	-- foam weather strip on the latch edge. The tape wraps the leaf 0.03 proud of both faces,
	-- and the four pieces butt end to end (no two share a face).
	local foil = look(M.Foil, 196, 198, 200, 0, 0.15)
	-- (0.03 proud of the panels' faces, which are 0.03 proud of the leaf)
	local wrap = DOOR_LEAF.thickness + 4 * LAYER.STEP
	-- (all of it stays 0.5 clear of the hinge edge: open, that part of the leaf lies against
	-- the wall's casing, and tape wrapped round it there cut into the casing)
	part(door, "FoilTape", V(3.67, 0.3, wrap), hinge * CF(2.515, 0.27, 0), foil)
	part(door, "FoilTape", V(3.67, 0.22, wrap), hinge * CF(2.515, 7.21, 0), foil)
	-- (the hinge-side strip: 0.5 in from the edge, thinner, 0.045 proud of each face)
	part(
		door,
		"FoilTape",
		V(0.18, 6.68, DOOR_LEAF.thickness + 3 * LAYER.STEP),
		hinge * CF(0.59, 3.76, 0),
		foil
	)
	-- (the foam is on the latch EDGE: 0.02 thick, between the leaf and the casing)
	part(
		door,
		"FoamStrip",
		V(0.02, 6.68, wrap),
		hinge * CF(4.41, 3.76, 0),
		look(M.Fabric, 70, 70, 66)
	)
	-- paint chips knocked off the dark leaf: the old cream paint showing under it (dark chips
	-- on a dark leaf read as black stickers), one level above the leaf's own chips
	for _, chip in { V(3.3, 2.4, 0), V(0.9, 5.6, 0), V(3.8, 1.1, 0) } do
		overlay(
			door,
			"PaintChip",
			Vector2.new(0.16, 0.09),
			onFace(chip.X, chip.Y) * ANG(0, 0, rad(chip.X * 20)),
			2 * LAYER.STEP,
			look(M.SmoothPlastic, 176, 164, 136)
		)
	end
end

function AptProps.doorSock(door: Model, side: number)
	local hinge = leafBase(door)
	part(
		door,
		"Sock",
		V(0.3, 0.9, 0.1),
		hinge * CF(3.9, 2.9, side * 0.38) * ANG(0, 0, rad(8)),
		look(M.Fabric, 92, 96, 104)
	)
end

function AptProps.doorTowelHook(door: Model, side: number)
	local hinge = leafBase(door)
	part(
		door,
		"Hook",
		V(0.12, 0.12, 0.3),
		hinge * CF(2.2, 6.4, side * 0.25),
		look(M.Metal, 170, 170, 164)
	)
	part(
		door,
		"Robe",
		V(1.0, 2.6, 0.35),
		hinge * CF(2.2, 5.0, side * 0.4) * ANG(0.05, 0, 0.04),
		look(M.Fabric, 120, 128, 120)
	)
end

------------------------------------------------------------------------------
-- ENTRY
------------------------------------------------------------------------------

-- Details on the inside of the front door. `at`: the leaf's centre on the floor, local -Z = into
-- the flat; the leaf's inner face is at local z = -0.125.
function AptProps.frontDoorDetails(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "FrontDoorDetails", at)
	local brass = look(M.Metal, 150, 128, 80)
	-- three deadbolts of three different ages
	add("Deadbolt", V(0.4, 0.26, 0.12), CF(-1.75, 4.1, -0.19), brass)
	add("Deadbolt", V(0.32, 0.34, 0.14), CF(-1.75, 4.9, -0.2), look(M.Metal, 110, 108, 100))
	add("Deadbolt", V(0.44, 0.24, 0.13), CF(-1.75, 5.8, -0.19), look(M.Metal, 192, 194, 198))
	add("Peephole", V(0.08, 0.16, 0.16), CF(0, 5.3, -0.16) * ALONG_Z, brass, CYL)
	-- a door chain hanging loose from its rail (clear of the deadbolts)
	add("ChainRail", V(0.6, 0.12, 0.08), CF(-1.3, 5.35, -0.17), brass)
	for i = 1, 3 do
		local t = i / 3
		add(
			"ChainLink",
			V(0.08, 0.08, 0.08),
			CF(-1.0 + t * 0.4, 5.3 - math.sin(t * math.pi) * 0.35 - t * 0.2, -0.2),
			brass,
			BALL
		)
	end
	add("Letterbox", V(1.2, 0.3, 0.06), CF(0, 2.7, -0.15), brass)
	-- a crack in the paint and a scuffed kick zone (overlays on the inner face)
	local face = CF(0, 0, -0.125)
	local crackLook = look(M.SmoothPlastic, 52, 44, 36)
	overlay(
		model,
		"PaintCrack",
		Vector2.new(0.035, 1.6),
		at * face * CF(0.7, 2.0, 0) * ANG(0, 0, rad(18)),
		LAYER.STEP,
		crackLook
	)
	overlay(
		model,
		"PaintCrack",
		Vector2.new(0.03, 0.7),
		at * face * CF(1.05, 2.75, 0) * ANG(0, 0, rad(-25)),
		LAYER.STEP,
		crackLook
	)
	overlay(
		model,
		"Scuff",
		Vector2.new(3.4, 0.6),
		at * face * CF(0, 0.45, 0),
		LAYER.STEP,
		tint(look(M.SmoothPlastic, 64, 54, 44), rng)
	)
	return model
end

-- A heap of mail behind the door (envelopes fanned on the floor; a red-stamped bill on top, no
-- words: it is the pile that tells the story).
function AptProps.mailHeap(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "MailHeap", at)
	local tones = {
		look(M.SmoothPlastic, 232, 228, 214),
		look(M.SmoothPlastic, 214, 200, 168),
		look(M.SmoothPlastic, 224, 222, 210),
		look(M.Cardboard, 150, 118, 82),
	}
	local count = rng:NextInteger(6, 8)
	for i = 1, count do
		local l = tint(tones[(i % #tones) + 1], rng, 6)
		-- (each envelope 0.03 above the last: stacked ones never share a plane)
		add(
			"Envelope",
			V(0.8 * rng:NextNumber(0.9, 1.15), 0.02, 0.5 * rng:NextNumber(0.9, 1.1)),
			CF(rng:NextNumber(-1.0, 1.0), 0.01 + (i - 1) * 0.03, rng:NextNumber(-0.4, 0.4))
				* ANG(0, rng:NextNumber(0, math.pi), 0),
			l
		)
	end
	add(
		"FinalNotice",
		V(0.85, 0.02, 0.55),
		CF(0.3, 0.01 + count * 0.03, -0.2) * ANG(0, rad(14), 0),
		look(M.SmoothPlastic, 236, 232, 220)
	)
	return model
end

-- Coat hooks on a wall with two sagging jackets. `at`: on the floor against the wall, local -Z
-- = out of the wall.
-- The glove station by the trolley: a steel wire shelf screwed through the tent's plastic,
-- three open boxes of nitrile gloves (blue-grey, the size the player's glove is) standing on
-- it, a cuff poking out of each, and a roll of blue paper wipes on a rod under it. `at`: on the
-- wall at the shelf's height (y in `at` is the floor), local -Z = out of the wall.
function AptProps.gloveRack(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "GloveRack", at)
	local wire = look(M.Metal, 168, 170, 168, 0, 0.1)
	local y = 4.4 -- the shelf's top
	add("ShelfBase", V(3.4, 0.05, 0.55), CF(0, y - 0.025, -0.3), wire)
	add("ShelfLip", V(3.4, 0.18, 0.04), CF(0, y + 0.05, -0.58), wire) -- (bottom above the base's)
	for _, x in { -1.5, 1.5 } do
		add("Bracket", V(0.05, 0.5, 0.05), CF(x, y - 0.3, -0.05), wire)
		add("Bracket", V(0.05, 0.05, 0.55), CF(x, y - 0.075, -0.3), wire)
	end
	-- (the boxes stand on the shelf: from its top up, a small gap between them)
	local boxLooks = {
		look(M.Cardboard, 90, 118, 150),
		look(M.Cardboard, 214, 214, 208),
		look(M.Cardboard, 142, 126, 168),
	}
	local glove = look(M.SmoothPlastic, 70, 98, 124)
	for i, x in { -1.05, 0, 1.05 } do
		local h = 0.5
		add("GloveBox", V(0.95, h, 0.45), CF(x, y + h / 2, -0.3), tint(boxLooks[i], rng, 3))
		-- the oval opening on the front (an overlay just proud of the box's face)
		overlay(
			model,
			"BoxSlot",
			Vector2.new(0.5, 0.2),
			at * CF(x, y + 0.3, -0.525),
			LAYER.STEP,
			look(M.SmoothPlastic, 30, 34, 38)
		)
		-- the cuff of the next glove, pulled half out
		add(
			"GloveCuff",
			V(0.22, 0.16, 0.12),
			CF(x + rng:NextNumber(-0.08, 0.08), y + 0.34, -0.6)
				* ANG(rad(-25), 0, rad(rng:NextNumber(-10, 10))),
			glove
		)
	end
	-- the wipes roll under the shelf
	add("RollRod", V(1.2, 0.04, 0.04), CF(0, y - 0.55, -0.32), wire)
	for _, x in { -0.56, 0.56 } do
		add("RollHanger", V(0.04, 0.5, 0.04), CF(x, y - 0.3, -0.32), wire)
	end
	add("WipesRoll", V(1.0, 0.42, 0.42), CF(0, y - 0.55, -0.32), look(M.Fabric, 96, 150, 196), CYL)
	return model
end

function AptProps.coatHooks(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "CoatHooks", at)
	add("HookBoard", V(3, 0.3, 0.12), CF(0, 5.5, -0.06), look(M.Wood, 120, 96, 70))
	local metal = look(M.Metal, 60, 60, 58)
	for _, x in { -1.1, 0, 1.1 } do
		add("Hook", V(0.08, 0.08, 0.35), CF(x, 5.4, -0.25) * ANG(rad(-20), 0, 0), metal)
	end
	-- two thin old jackets hanging by their collars
	local jacketA = tint(look(M.Fabric, 46, 44, 42), rng)
	add("Jacket", V(0.9, 1.9, 0.3), CF(-1.1, 4.35, -0.33) * ANG(rad(4), 0, rad(-6)), jacketA)
	add("Collar", V(0.7, 0.22, 0.34), CF(-1.12, 5.32, -0.3) * ANG(0, 0, rad(-6)), jacketA)
	add(
		"Sleeve",
		V(0.28, 1.5, 0.24),
		CF(-0.68, 4.1, -0.36) * ANG(0, 0, rad(-14)),
		look(M.Fabric, 44, 42, 40)
	)
	local jacketB = tint(look(M.Fabric, 70, 62, 52), rng)
	add("Jacket", V(0.85, 1.75, 0.32), CF(1.1, 4.42, -0.34) * ANG(rad(6), 0, rad(9)), jacketB)
	add("Collar", V(0.66, 0.2, 0.36), CF(1.08, 5.32, -0.3) * ANG(0, 0, rad(9)), jacketB)
	-- (the story: a bag strap left on the middle hook)
	add(
		"BagStrap",
		V(0.08, 1.4, 0.06),
		CF(0.1, 4.75, -0.32) * ANG(0, 0, rad(6)),
		look(M.Fabric, 30, 30, 32)
	)
	return model
end

-- Three pairs of shoes kicked against a wall.
function AptProps.shoePile(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "ShoePile", at)
	local pairs_ = {
		{ upper = look(M.Leather, 30, 28, 26), sole = look(M.Rubber, 20, 20, 20) },
		{ upper = look(M.Fabric, 170, 168, 160), sole = look(M.Rubber, 205, 200, 190) },
		{ upper = look(M.Leather, 90, 62, 40), sole = look(M.Rubber, 50, 40, 32) },
	}
	for p, pair in pairs_ do
		for s = 1, 2 do
			local x = (p - 2) * 0.98 + (s - 1.5) * 0.48 + rng:NextNumber(-0.03, 0.03)
			local onSide = p == 3 and s == 2
			-- (every other shoe 0.03 higher: two that overlap never share a plane)
			local k = (p - 1) * 2 + s
			local frame = CF(
				x,
				(if onSide then 0.24 else 0.06) + (k % 2) * 0.03,
				rng:NextNumber(-0.3, 0.3)
			) * ANG(0, jitterAngle(rng, 4, 14), if onSide then rad(80) else 0)
			add("Sole", V(0.42, 0.12, 1.0), frame, pair.sole)
			add("Upper", V(0.36, 0.35, 0.72), frame * CF(0, 0.22, 0.12), tint(pair.upper, rng))
		end
	end
	return model
end

-- The open meter cupboard: a fuse box choked with six extension cords (the FIRST lab sign). Its
-- supply comes up from the floor in a grey conduit; its door is swung right back, flat beside it
-- (toward the front door), never into the way to the corridor.
-- `at`: on the floor against the wall, local -Z = out of the wall. Returns the model and the
-- world point where the cord bundle leaves the cupboard.
function AptProps.meterCupboard(parent: Instance, at: CFrame, _rng: Random): (Model, Vector3)
	local model, add = begin(parent, "MeterCupboard", at)
	local board = look(M.Wood, 168, 160, 140)
	-- (a small cupboard: 2 wide, 4 high, 0.8 deep, from y 3.6 to 7.6; the top and bottom sit
	-- BETWEEN the sides, so no two boards share an outer face)
	-- (0.08 thick: its face stands in front of the wallpaper's, 0.05)
	add("Back", V(1.84, 3.92, 0.08), CF(0, 5.6, -0.04), look(M.Wood, 120, 112, 96))
	for _, x in { -0.96, 0.96 } do
		add("Side", V(0.08, 4.08, 0.8), CF(x, 5.6, -0.4), board)
	end
	add("Top", V(1.84, 0.08, 0.8), CF(0, 7.6, -0.4), board)
	add("Bottom", V(1.84, 0.08, 0.8), CF(0, 3.6, -0.4), board)
	-- the cupboard door, swung back 172 degrees on its right-hand hinge
	add(
		"CupboardDoor",
		V(2, 4.08, 0.06),
		CF(1.03, 5.6, -0.83) * ANG(0, rad(-172), 0) * CF(-1.0, 0, 0),
		board
	)
	-- the supply: a grey conduit from the skirting up into the cupboard's bottom
	add("Conduit", V(0.24, 3.05, 0.24), CF(0.65, 2.075, -0.16), look(M.Plastic, 150, 150, 146))
	add("ConduitClip", V(0.32, 0.12, 0.3), CF(0.65, 2.0, -0.17), look(M.Plastic, 120, 120, 116))
	-- the fuse box and its six plugs
	add("FuseBox", V(1.3, 1.4, 0.35), CF(0.1, 6.3, -0.225), look(M.Metal, 160, 158, 150))
	add("FuseCover", V(1.2, 0.5, 0.05), CF(0.1, 6.75, -0.425), look(M.Metal, 140, 138, 130))
	local exit = at * CF(0.2, 3.66, -0.55)
	-- the six cords droop from their plugs to a knot under the box, then run down the wall
	-- as one taped bundle to the exit (where LabBuilder's corridor bundle takes over)
	local knot = at * CF(0.15, 5.45, -0.42)
	for i = 1, 6 do
		local x = -0.45 + (i - 1) * 0.18
		local plugAt = at * CF(x, 5.95 + (i % 2) * 0.2, -0.485)
		part(model, "Plug", V(0.15, 0.19, 0.17), plugAt, look(M.Plastic, 220, 216, 204))
		rod(
			model,
			"Cord",
			plugAt.Position + plugAt.LookVector * 0.1,
			knot.Position + V((i - 3.5) * 0.03, 0, 0),
			0.09,
			CORD_LOOKS[i]
		)
	end
	rod(model, "Cord", knot.Position, exit.Position, 0.3, look(M.Plastic, 38, 38, 36))
	-- tape round the bundle, a torch and a roll of duct tape on the cupboard's floor
	add("Tape", V(0.4, 0.25, 0.4), CF(0.15, 4.6, -0.58), TAPE)
	add(
		"Torch",
		V(0.8, 0.2, 0.2),
		CF(-0.45, 3.74, -0.4) * ANG(0, rad(20), 0),
		look(M.Plastic, 40, 44, 48),
		CYL
	)
	add(
		"DuctTape",
		V(0.22, 0.5, 0.5),
		CF(0.55, 3.75, -0.38) * UP,
		look(M.Fabric, 150, 150, 146),
		CYL
	)
	return model, exit.Position
end

-- A small mirror with a dark corner (the silvering gone).
function AptProps.mirror(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "Mirror", at)
	add("Frame", V(1.4, 1.8, 0.1), CF(0, 5.2, -0.05), look(M.Wood, 70, 56, 42))
	add("Glass", V(1.2, 1.6, 0.04), CF(0, 5.2, -0.11), look(M.Glass, 120, 126, 124, 0, 0.3))
	-- (a wedge's sloped profile lies in its Y-Z plane: turned a quarter, that is the glass)
	add(
		"DarkCorner",
		V(0.03, 0.6, 0.5),
		CF(0.35, 4.7, -0.145) * ANG(0, rad(90), 0),
		look(M.SmoothPlastic, 16, 16, 16),
		WEDGE
	)
	return model
end

-- A light switch with its cover hanging crooked, a grey hand-grime halo round it.
function AptProps.lightSwitch(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "LightSwitch", at)
	overlay(
		model,
		"Grime",
		Vector2.new(0.5, 0.6),
		at * CF(0, 4.05, 0),
		LAYER.STAIN,
		look(M.Plaster, 104, 96, 80)
	)
	add(
		"Cover",
		V(0.32, 0.46, 0.05),
		CF(0, 4, -LAYER.STAIN - 0.025)
			* ANG(0, 0, rad(8) * (if rng:NextNumber() < 0.5 then 1 else -1)),
		look(M.SmoothPlastic, 206, 200, 182)
	)
	add(
		"Toggle",
		V(0.08, 0.14, 0.06),
		CF(0, 4, -LAYER.STAIN - 0.08),
		look(M.SmoothPlastic, 220, 216, 200)
	)
	return model
end

-- An old column radiator: 10 slabs, rust streaks under the valve. `at` on the floor against the
-- wall, local -Z = out of the wall.
function AptProps.radiator(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "Radiator", at)
	local paint = tint(look(M.Metal, 196, 190, 176), rng)
	for i = 1, 8 do
		add("Slab", V(0.2, 2.2, 0.6), CF((i - 4.5) * 0.28, 1.6, -0.45), paint)
	end
	add("Header", V(2.5, 0.15, 0.25), CF(0, 2.6, -0.45), paint)
	add("Footer", V(2.5, 0.15, 0.25), CF(0, 0.6, -0.45), paint)
	for _, x in { -1.1, 1.1 } do
		add("Foot", V(0.15, 0.5, 0.4), CF(x, 0.25, -0.45), paint)
	end
	add("Valve", V(0.3, 0.3, 0.3), CF(1.35, 0.7, -0.45), look(M.Metal, 150, 128, 80), BALL)
	add("Pipe", V(0.6, 0.2, 0.2), CF(1.35, 0.3, -0.45) * UP, look(M.Metal, 150, 146, 138), CYL)
	for i = 1, 3 do
		add(
			"RustStreak",
			V(0.08, rng:NextNumber(0.4, 1.0), 0.02),
			CF(1.0 - i * 0.24, 1.0, -0.76),
			RUST
		)
	end
	return model
end

------------------------------------------------------------------------------
-- LIVING ROOM + KITCHENETTE
------------------------------------------------------------------------------

-- A worn leather sofa with a blanket. Front = local -Z.
function AptProps.sofa(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "Sofa", at)
	local leather = tint(look(M.Leather, 60, 40, 32), rng)
	add("Base", V(6.8, 1.0, 2.8), CF(0, 0.85, 0), solid(leather))
	add("Back", V(6.8, 2.0, 0.7), CF(0, 2.3, 1.05) * ANG(rad(-8), 0, 0), leather)
	-- (the arms stand 0.03 proud of the base's front and back: no shared face)
	for _, x in { -3.2, 3.2 } do
		add("Arm", V(0.6, 1.4, 2.86), CF(x, 1.75, 0), leather)
	end
	local cushion = tint(leather, rng, 5)
	add("Cushion", V(2.9, 0.5, 2.1), CF(-1.48, 1.6, -0.2) * ANG(rad(2), 0, rad(-1.5)), cushion)
	add("Cushion", V(2.9, 0.42, 2.1), CF(1.48, 1.56, -0.25) * ANG(rad(-1), 0, rad(2)), cushion)
	-- the worn patch (cloth showing through) on the left cushion
	add(
		"Patch",
		V(1, 0.03, 1),
		CF(-1.3, 1.875, -0.4) * ANG(rad(2), rad(12), rad(-1.5)),
		look(M.Fabric, 84, 64, 50)
	)
	add(
		"Blanket",
		V(1.6, 0.35, 1.3),
		CF(2.2, 2.0, 0.3) * ANG(0, rad(25), rad(4)),
		tint(look(M.Fabric, 88, 96, 82), rng)
	)
	for _, x in { -3.1, 3.1 } do
		for _, z in { -1.1, 1.1 } do
			add("Foot", V(0.25, 0.35, 0.25), CF(x, 0.175, z), look(M.Wood, 40, 30, 24))
		end
	end
	return model
end

-- A low coffee table: takeaway boxes, plates, a closed laptop. Front = local -Z.
function AptProps.lowTable(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "LowTable", at)
	local wood = tint(look(M.Wood, 86, 64, 46), rng)
	add("Top", V(3, 0.15, 3), CF(0, 1.3, 0), solid(wood))
	for _, x in { -1.35, 1.35 } do
		for _, z in { -1.35, 1.35 } do
			add("Leg", V(0.18, 1.22, 0.18), CF(x, 0.61, z), wood)
		end
	end
	local card = look(M.Cardboard, 150, 118, 82)
	add("Takeaway", V(0.6, 0.4, 0.6), CF(-0.8, 1.58, 0.6) * ANG(0, rad(17), 0), tint(card, rng))
	add(
		"Takeaway",
		V(0.55, 0.36, 0.55),
		CF(-0.75, 1.56, -0.3) * ANG(0, rad(-8), rad(3)),
		tint(card, rng)
	)
	add("TakeawayLid", V(0.55, 0.04, 0.55), CF(-0.2, 1.4, 1.0) * ANG(0, rad(40), 0), card)
	local plate = look(M.SmoothPlastic, 210, 206, 196)
	add("Plate", V(0.04, 0.8, 0.8), CF(0.5, 1.4, 0.7) * UP, plate, CYL)
	add("Plate", V(0.04, 0.8, 0.8), CF(0.55, 1.45, 0.72) * UP * ANG(rad(3), 0, 0), plate, CYL)
	add("Plate", V(0.04, 0.7, 0.7), CF(0.9, 1.4, -0.7) * UP, tint(plate, rng), CYL)
	add(
		"Laptop",
		V(1.2, 0.08, 0.85),
		CF(0.3, 1.42, -0.2) * ANG(0, rad(-12), 0),
		look(M.Plastic, 40, 40, 42)
	)
	-- (the story: a ring stain on the wood, an overlay on the top)
	add("Ring", V(0.03, 0.5, 0.5), CF(-0.2, 1.39, -1.0) * UP, look(M.Wood, 64, 46, 32), CYL)
	return model
end

-- An old boxy CRT television on a plastic crate, on standby (the ONLY red light of the flat).
function AptProps.crtTV(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "CrtTV", at)
	add("Crate", V(2.4, 1.4, 1.7), CF(0, 0.7, 0), solid(tint(look(M.Plastic, 52, 70, 84), rng)))
	add("Body", V(2.0, 1.55, 1.5), CF(0, 2.175, 0.05), look(M.Plastic, 54, 50, 46))
	add("Screen", V(1.6, 1.15, 0.05), CF(-0.05, 2.22, -0.72), look(M.Glass, 22, 24, 24, 0, 0.12))
	add("Led", V(0.06, 0.06, 0.04), CF(0.85, 1.55, -0.72), look(M.Neon, 255, 40, 30))
	local rodLook = look(M.Metal, 160, 160, 156)
	add("Antenna", V(1.4, 0.04, 0.04), CF(-0.3, 3.4, 0.3) * ANG(0, 0, rad(55)), rodLook, CYL)
	add("Antenna", V(1.4, 0.04, 0.04), CF(0.3, 3.4, 0.3) * ANG(0, 0, rad(125)), rodLook, CYL)
	add("Dust", V(1.9, 0.03, 1.4), CF(0, 2.965, 0.05), look(M.Plastic, 76, 72, 66))
	return model
end

-- The venetian blind window. `at`: the window's bottom centre ON the wall line (the wall's
-- room face), local -Z = into the room. The opening is 7 wide, 5 high, from y 3 to 8.
function AptProps.blindWindow(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "BlindWindow", at)
	local frame = look(M.Wood, 150, 140, 118)
	add("Sill", V(7.6, 0.2, 0.7), CF(0, 2.95, -0.1), frame)
	add("FrameTop", V(7.4, 0.25, 0.4), CF(0, 8.0, 0.25), frame)
	-- (the sides stand 0.06 inside the opening: they cover the wall's cut ends)
	for _, x in { -3.565, 3.565 } do
		add("FrameSide", V(0.25, 5, 0.4), CF(x, 5.5, 0.25), frame)
	end
	add("Mullion", V(0.15, 5, 0.12), CF(0, 5.5, 0.7), frame)
	add("Pane", V(7, 5, 0.04), CF(0, 5.5, 0.75), look(M.Glass, 90, 80, 70, 0.75))
	-- the blind: head rail, 10 slats tilted 30 degrees (two bent, one missing), a pull cord
	local slat = tint(look(M.SmoothPlastic, 196, 186, 160), rng, 5)
	add("HeadRail", V(7.0, 0.25, 0.3), CF(0, 7.75, 0.1), slat)
	local missing = rng:NextInteger(3, 8)
	for i = 1, 10 do
		if i ~= missing then
			local y = 7.4 - (i - 1) * 0.47
			local tilt = 30
			local bend = 0
			if i == 2 or i == 7 then
				tilt = -10
				bend = rad(rng:NextNumber(-5, 5))
			end
			add("Slat", V(7, 0.05, 0.35), CF(0, y, 0.1) * ANG(rad(tilt), bend, 0), slat)
		end
	end
	add("PullCord", V(0.03, 3.2, 0.03), CF(3.3, 6.1, -0.05), look(M.Fabric, 200, 196, 180))
	return model
end

-- The kitchen counter (carcass, chipped marble top, a drop-in steel sink full of dishes, a
-- kettle, a dish rack) and the wall cabinet above it. Front = local -Z, 6.2 long (local X),
-- 2.4 deep; the freestanding cooker stands at its +X end (AptProps.cooker).
function AptProps.kitchenCounter(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "KitchenCounter", at)
	local carcass = look(M.Wood, 156, 146, 120)
	add("Carcass", V(6.2, 2.85, 2.25), CF(0, 1.5, 0.05), solid(carcass))
	add("ToeKick", V(6.2, 0.3, 0.05), CF(0, 0.15, -1.1), look(M.Wood, 52, 44, 36))
	add("Top", V(6.2, 0.15, 2.4), CF(0, 3.025, 0), look(M.Marble, 150, 146, 136))
	-- a chipped corner on the front edge (concrete core showing, a little proud of the edge)
	add("TopChip", V(0.4, 0.05, 0.2), CF(2.4, 3.01, -1.13), look(M.Concrete, 110, 104, 94))
	-- three cabinet doors, one hanging off its hinge
	local front = tint(look(M.Wood, 150, 140, 114), rng)
	for i = 1, 3 do
		local x = -2.05 + (i - 1) * 2.05
		if i == 2 then
			add(
				"CabinetDoor",
				V(1.95, 2.4, 0.06),
				CF(x - 0.975, 1.6, -1.24) * ANG(0, 0, rad(-12)) * CF(0.975, 0, 0),
				front
			)
		else
			add("CabinetDoor", V(1.95, 2.4, 0.06), CF(x, 1.6, -1.2), tint(front, rng, 4))
		end
		add("Handle", V(0.5, 0.08, 0.08), CF(x + 0.55, 2.4, -1.3), look(M.Metal, 150, 146, 138))
	end
	-- the drop-in steel sink (its rim rests on the top), plates and mugs in it, a tap behind
	local steel = look(M.Metal, 160, 162, 160)
	add("Sink", V(2.2, 0.08, 1.6), CF(-1.6, 3.14, -0.1), look(M.Metal, 110, 112, 110))
	for _, z in { -0.92, 0.72 } do
		add("SinkRim", V(2.3, 0.1, 0.08), CF(-1.6, 3.2, z), steel)
	end
	add("Tap", V(0.12, 0.9, 0.12), CF(-1.6, 3.55, 0.85), steel)
	add("Spout", V(0.6, 0.1, 0.1), CF(-1.6, 3.97, 0.6) * ALONG_Z, steel, CYL)
	local plate = look(M.SmoothPlastic, 210, 206, 196)
	for i = 1, 2 do
		add(
			"Plate",
			V(0.04, 0.8, 0.8),
			CF(-1.9 + i * 0.12, 3.5, -0.1) * ANG(rad(70 + i * 3), 0, 0) * UP,
			tint(plate, rng, 6),
			CYL
		)
	end
	add("Mug", V(0.4, 0.3, 0.3), CF(-0.9, 3.38, 0.2) * UP, look(M.SmoothPlastic, 70, 96, 110), CYL)
	add(
		"Mug",
		V(0.4, 0.3, 0.3),
		CF(-2.3, 3.33, -0.4) * ANG(rad(90), 0, rad(70)),
		look(M.SmoothPlastic, 200, 190, 150),
		CYL
	)
	-- the dish rack and the kettle (lime-scale band)
	local wire = look(M.Metal, 170, 170, 166)
	add("RackBase", V(1.4, 0.06, 1.0), CF(0.35, 3.13, 0.1), wire)
	for i = 1, 3 do
		add("RackWire", V(0.03, 0.6, 1.0), CF(-0.15 + i * 0.3, 3.46, 0.1), wire)
	end
	add("RackPlate", V(0.04, 0.8, 0.8), CF(0.3, 3.56, 0.1) * ANG(0, rad(90), 0), plate, CYL)
	local kettleLook = look(M.Plastic, 200, 196, 186)
	add("KettleBase", V(0.1, 0.8, 0.8), CF(1.9, 3.15, 0.3) * UP, look(M.Plastic, 40, 40, 40), CYL)
	add(
		"KettleScale",
		V(0.2, 0.72, 0.72),
		CF(1.9, 3.3, 0.3) * UP,
		look(M.Plastic, 170, 166, 150),
		CYL
	)
	add("Kettle", V(0.7, 0.7, 0.7), CF(1.9, 3.75, 0.3) * UP, kettleLook, CYL)
	add("KettleHandle", V(0.12, 0.6, 0.12), CF(1.9, 3.8, 0.72), kettleLook)
	-- the wall cabinet above (one door ajar, swung OUT into the room)
	add("WallCabinet", V(6, 2.4, 1.2), CF(0, 7.3, 0.6), carcass)
	add(
		"WallCabinetDoor",
		V(2.9, 2.3, 0.06),
		CF(-2.95, 7.3, -0.03) * ANG(0, rad(25), 0) * CF(1.45, 0, 0),
		front
	)
	add("WallCabinetDoor", V(2.9, 2.3, 0.06), CF(1.5, 7.3, -0.03), tint(front, rng, 4))
	-- grease shadow on the wall above the kettle
	overlay(
		model,
		"Grease",
		Vector2.new(1.6, 1.8),
		at * CF(1.9, 4.4, 1.2),
		LAYER.STAIN,
		look(M.Plaster, 112, 100, 78)
	)
	return model
end

-- An old freestanding cooker beside the counter: enamel body, four hob rings, a pan on one,
-- the oven door with its window and handle, knobs on the splashback. Front = local -Z,
-- 2.2 wide, 2.2 deep, the hob at y 2.96.
function AptProps.cooker(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "Cooker", at)
	local enamel = tint(look(M.SmoothPlastic, 206, 200, 184), rng, 5)
	add("Body", V(2.2, 2.9, 2.2), CF(0, 1.45, 0), solid(enamel))
	add("Splash", V(2.2, 0.6, 0.12), CF(0, 3.2, 1.04), enamel)
	add("Hob", V(2.1, 0.06, 1.96), CF(0, 2.93, -0.1), look(M.Metal, 58, 58, 56))
	local ring = look(M.Metal, 34, 34, 34)
	for _, spot in { V(-0.5, 0, -0.55), V(0.5, 0, -0.55), V(-0.5, 0, 0.4), V(0.5, 0, 0.4) } do
		add("Ring", V(0.04, 0.62, 0.62), CF(spot.X, 2.98, spot.Z) * UP, ring, CYL)
	end
	-- a dented pan on the front-left ring, its handle out to the side
	add("Pan", V(0.32, 0.8, 0.8), CF(-0.5, 3.16, -0.55) * UP, look(M.Metal, 120, 118, 112), CYL)
	add(
		"PanHandle",
		V(0.8, 0.08, 0.12),
		CF(-1.1, 3.26, -0.75) * ANG(0, rad(20), 0),
		look(M.Plastic, 30, 30, 30)
	)
	for i = 1, 4 do
		add(
			"Knob",
			V(0.08, 0.16, 0.16),
			CF(-0.75 + (i - 1) * 0.5, 3.2, 0.95) * ALONG_Z,
			look(M.Plastic, 40, 40, 40),
			CYL
		)
	end
	-- the oven: door, dark window, handle; the grill drawer under it
	add("OvenDoor", V(1.9, 1.6, 0.06), CF(0, 1.6, -1.13), enamel)
	add("OvenWindow", V(1.1, 0.6, 0.04), CF(0, 1.7, -1.18), look(M.Glass, 26, 24, 22, 0, 0.15))
	add(
		"OvenHandle",
		V(1.5, 0.08, 0.08),
		CF(0, 2.32, -1.3) * ANG(0, 0, 0),
		look(M.Metal, 160, 160, 156),
		CYL
	)
	add("Drawer", V(1.9, 0.5, 0.06), CF(0, 0.4, -1.13), tint(enamel, rng, 4))
	-- years of grease down the front (an overlay under the hob's edge)
	overlay(
		model,
		"Grease",
		Vector2.new(1.4, 0.3),
		at * CF(0.2, 2.6, -1.1),
		LAYER.STEP,
		look(M.SmoothPlastic, 150, 132, 96)
	)
	return model
end

-- A cheap stacking plastic chair (seat, back, four legs). Front = local -Z.
function AptProps.plasticChair(parent: Instance, at: CFrame, rng: Random, l: Look): Model
	local model, add = begin(parent, "PlasticChair", at)
	local body = tint(l, rng, 5)
	add("Seat", V(1.5, 0.12, 1.5), CF(0, 1.9, 0), solid(body))
	add("Back", V(1.5, 1.5, 0.12), CF(0, 2.75, 0.72) * ANG(rad(-8), 0, 0), body)
	for _, x in { -0.65, 0.65 } do
		for _, z in { -0.65, 0.65 } do
			add("Leg", V(0.12, 1.86, 0.12), CF(x, 0.93, z) * ANG(rad(z * 4), 0, rad(-x * 4)), body)
		end
	end
	return model
end

-- A floor lamp with a fabric drum shade (the light itself is a LabBuilder fixture in the shade).
function AptProps.floorLamp(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "FloorLamp", at)
	local brass = look(M.Metal, 120, 100, 70)
	add("Base", V(0.12, 1.0, 1.0), CF(0, 0.06, 0) * UP, brass, CYL)
	add("Pole", V(5.3, 0.1, 0.1), CF(0, 2.77, 0) * UP, brass, CYL)
	add("Shade", V(1.0, 1.4, 1.4), CF(0, 5.6, 0) * UP, look(M.Fabric, 200, 170, 120, 0.15), CYL)
	add("ShadeTop", V(0.03, 1.0, 1.0), CF(0, 6.115, 0) * UP, look(M.Fabric, 150, 120, 80), CYL)
	-- its cord along the floor to the wall
	path(model, "Cord", {
		(at * CF(0.1, 0.03, 0.3)).Position,
		(at * CF(0.3, 0.03, 0.9)).Position,
		(at * CF(0.3, 0.03, 1.6)).Position,
	}, 0.06, CORD_WHITE)
	return model
end

-- A folding laundry airer with three things drying (by the radiator).
function AptProps.laundryAirer(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "LaundryAirer", at)
	local wire = look(M.Metal, 190, 192, 190)
	for _, x in { -1.4, 1.4 } do
		add("Frame", V(0.06, 3.4, 0.06), CF(x, 1.6, -0.5) * ANG(rad(-14), 0, 0), wire)
		add("Frame", V(0.06, 3.4, 0.06), CF(x, 1.6, 0.5) * ANG(rad(14), 0, 0), wire)
	end
	for _, y in { 2.8, 3.2 } do
		add("Rail", V(2.8, 0.04, 0.04), CF(0, y, -0.1 * (y - 2.6)), wire, CYL)
	end
	local clothes = {
		look(M.Fabric, 70, 74, 80),
		look(M.Fabric, 150, 150, 140),
		look(M.Fabric, 50, 62, 90),
	}
	for i, l in clothes do
		add(
			"Cloth",
			V(0.8, rng:NextNumber(1.0, 1.5), 0.06),
			CF(-0.95 + (i - 1) * 0.95, 2.6, -0.04 * i) * ANG(0, 0, rad(rng:NextNumber(-2, 2))),
			tint(l, rng, 5)
		)
	end
	return model
end

-- A wall clock that stopped long ago (no numbers: hour marks and two hands). On a wall;
-- `at` = the clock's centre ON the wall, local -Z = out.
function AptProps.wallClock(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "WallClock", at)
	add("Rim", V(0.12, 1.2, 1.2), CF(0, 0, -0.06) * ALONG_Z, look(M.Plastic, 40, 40, 40), CYL)
	add(
		"Face",
		V(0.04, 1.05, 1.05),
		CF(0, 0, -0.14) * ALONG_Z,
		look(M.SmoothPlastic, 226, 222, 206),
		CYL
	)
	local ink = look(M.SmoothPlastic, 30, 30, 30)
	for i = 0, 3 do
		add(
			"Mark",
			V(0.05, 0.14, 0.03),
			CF(0, 0, -0.175) * ANG(0, 0, i * math.pi / 2) * CF(0, 0.42, 0),
			ink
		)
	end
	add("Hand", V(0.05, 0.3, 0.03), CF(0, 0, -0.2) * ANG(0, 0, rad(-100)) * CF(0, 0.15, 0), ink)
	add("Hand", V(0.04, 0.42, 0.03), CF(0, 0, -0.23) * ANG(0, 0, rad(35)) * CF(0, 0.21, 0), ink)
	return model
end

-- A pedal bin (dented, lid shut). `at` on the floor.
function AptProps.pedalBin(parent: Instance, at: CFrame, rng: Random, l: Look): Model
	local model, add = begin(parent, "PedalBin", at)
	local body = tint(l, rng, 5)
	add("Bin", V(1.5, 1.0, 1.0), CF(0, 0.75, 0) * UP, body, CYL)
	add("Lid", V(0.12, 1.06, 1.06), CF(0, 1.56, 0) * UP, look(M.Metal, 60, 62, 64), CYL)
	add("Pedal", V(0.4, 0.06, 0.25), CF(0, 0.1, -0.6), look(M.Metal, 60, 62, 64))
	return model
end

-- A key hook board by the door with a bunch of keys and a lanyard. On a wall; local -Z = out.
function AptProps.keyHook(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "KeyHook", at)
	add("Board", V(0.9, 0.3, 0.1), CF(0, 4.6, -0.05), look(M.Wood, 110, 86, 60))
	local metal = look(M.Metal, 150, 150, 146)
	for _, x in { -0.25, 0.25 } do
		add("Peg", V(0.05, 0.05, 0.25), CF(x, 4.55, -0.2), metal)
	end
	add(
		"Keys",
		V(0.12, 0.35, 0.05),
		CF(-0.25, 4.32, -0.29) * ANG(0, 0, rad(6)),
		look(M.Metal, 170, 160, 120)
	)
	add("Fob", V(0.18, 0.18, 0.06), CF(-0.25, 4.1, -0.29), look(M.Plastic, 60, 90, 120))
	add("Lanyard", V(0.05, 0.9, 0.03), CF(0.25, 4.15, -0.27), look(M.Fabric, 40, 40, 44))
	return model
end

-- The old kitchen fridge (yellowed, rust at the base) with two tubs inside. The door itself is a
-- Doors model (Door_Fridge) made by `fridgeDoor`. Front = local -Z; 2.2 wide, 2.1 deep (door
-- included), 6 high. The panels BUTT (top, bottom and back between the sides): no two of them
-- share an outer face.
function AptProps.oldFridge(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "OldFridge", at)
	local shell = solid(tint(YELLOWED, rng))
	for _, x in { -1.05, 1.05 } do
		add("Side", V(0.1, 6, 1.9), CF(x, 3, 0.1), shell)
	end
	add("Back", V(2.0, 6, 0.1), CF(0, 3, 1.0), shell)
	add("Top", V(2.0, 0.1, 1.8), CF(0, 5.95, 0.05), shell)
	add("Bottom", V(2.0, 0.5, 1.8), CF(0, 0.25, 0.05), shell)
	add("Inside", V(1.95, 5.3, 0.03), CF(0, 3.2, 0.92), look(M.SmoothPlastic, 226, 228, 222))
	-- rust creeping up both sides from the floor
	for _, x in { -1.1, 1.1 } do
		overlay(
			model,
			"Rust",
			Vector2.new(1.9, 0.35),
			at * CF(x, 0.2, 0.1) * ANG(0, if x < 0 then rad(90) else rad(-90), 0),
			LAYER.STEP,
			RUST
		)
	end
	local shelf = look(M.Glass, 200, 214, 214, 0.5)
	for _, y in { 2.0, 3.6 } do
		add("Shelf", V(1.95, 0.04, 1.6), CF(0, y, 0.15), shelf)
	end
	-- two plain tubs (milky, teal lids) and half a loaf: nothing else
	local tubLook = look(M.SmoothPlastic, 220, 226, 222)
	local lidLook = look(M.SmoothPlastic, 70, 120, 128)
	for i = 1, 2 do
		local x = -0.5 + (i - 1) * 0.7
		add("Tub", V(0.5, 0.5, 0.7), CF(x, 2.27, 0.1), tubLook)
		add("Lid", V(0.56, 0.06, 0.76), CF(x, 2.55, 0.1), lidLook)
	end
	add("Loaf", V(0.8, 0.45, 0.5), CF(0.35, 3.875, 0.3), look(M.Plastic, 190, 140, 80))
	add("LoafBag", V(1.16, 0.56, 0.61), CF(0.45, 3.9, 0.3), look(M.Glass, 220, 214, 196, 0.6))
	-- (the hum comes from the back: a dusty compressor grille)
	add("Grille", V(1.8, 1.0, 0.04), CF(0, 0.9, 1.07), look(M.Metal, 40, 40, 38))
	return model
end

-- The kitchen fridge's door (a Doors model, Prompt mode). `hinge`: see AptProps.door (the
-- hinge line is on the leaf's outer face, so it swings clear of the cabinet).
function AptProps.fridgeDoor(parent: Instance, hinge: CFrame, rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "Door_Fridge"
	local base = hinge * CF(0, 0, 0.1) -- (the leaf's middle; the leaf is 0.2 thick)
	local function add(partName: string, size: Vector3, offset: CFrame, l: Look): Part
		return part(model, partName, size, base * offset, l)
	end
	local leaf = add("Leaf", V(2.2, 5.4, 0.2), CF(1.1, 3.25, 0), solid(tint(YELLOWED, rng)))
	model.PrimaryPart = leaf
	add("Gasket", V(2.0, 5.2, 0.05), CF(1.1, 3.25, 0.125), look(M.Rubber, 120, 118, 110))
	add("Handle", V(0.12, 1.4, 0.15), CF(1.95, 3.9, -0.2), look(M.Metal, 170, 172, 174))
	add("DoorShelf", V(1.8, 0.4, 0.3), CF(1.1, 2.2, 0.3), look(M.SmoothPlastic, 214, 220, 216))
	local magnetColors = {
		Color3.fromRGB(60, 110, 160),
		Color3.fromRGB(220, 190, 70),
		Color3.fromRGB(70, 140, 80),
		Color3.fromRGB(230, 230, 220),
	}
	-- (scattered unevenly: in a row above the note they read as a face)
	local magnetSpots = { V(0.5, 5.6, 0), V(1.72, 5.28, 0), V(0.38, 3.72, 0), V(1.86, 3.3, 0) }
	for i, color in magnetColors do
		local magnet = look(M.Plastic, 0, 0, 0)
		magnet.color = color
		local spot = magnetSpots[i]
		add(
			"Magnet",
			V(0.22, 0.22, 0.06),
			CF(spot.X + rng:NextNumber(-0.06, 0.06), spot.Y, -0.13)
				* ANG(0, 0, jitterAngle(rng, 5, 30)),
			magnet
		)
	end
	-- a blank shopping list taped on (an overlay on the leaf, the tape one level above it)
	local face = base * CF(0, 0, -0.1)
	overlay(
		model,
		"Note",
		Vector2.new(1.0, 1.1),
		face * CF(1.05, 4.6, 0) * ANG(0, 0, rad(-3)),
		LAYER.STEP,
		PAPER
	)
	overlay(
		model,
		"NoteTape",
		Vector2.new(0.5, 0.14),
		face * CF(1.05, 5.12, 0),
		2 * LAYER.STEP,
		TAPE
	)
	model.WorldPivot = hinge
	model:SetAttribute("Room", "Living")
	model:SetAttribute("Mode", "Prompt")
	model:SetAttribute("RestAngle", 0)
	model:SetAttribute("OpenAngle", 90)
	model:SetAttribute("Label", "Fridge")
	model.Parent = parent
	return model
end

-- A folding table: a pile of bills (one with a coffee ring), a calculator, two cooler lids.
function AptProps.foldTable(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "FoldTable", at)
	add("Top", V(3, 0.1, 2), CF(0, 2.6, 0), solid(look(M.Plastic, 182, 176, 160)))
	local leg = look(M.Metal, 120, 120, 116)
	for _, x in { -1.3, 1.3 } do
		add("Leg", V(0.1, 2.6, 0.1), CF(x, 1.3, -0.8) * ANG(rad(8), 0, 0), leg)
		add("Leg", V(0.1, 2.6, 0.1), CF(x, 1.3, 0.8) * ANG(rad(-8), 0, 0), leg)
	end
	-- (the pile: each sheet 0.03 above the last, so stacked sheets never share a plane)
	for i = 1, 6 do
		add(
			"Invoice",
			V(0.75, 0.01, 1.0),
			CF(-0.6 + rng:NextNumber(-0.1, 0.1), 2.655 + i * 0.03, rng:NextNumber(-0.1, 0.1))
				* ANG(0, jitterAngle(rng), 0),
			tint(PAPER, rng, 6)
		)
	end
	add(
		"CoffeeRing",
		V(0.03, 0.4, 0.4),
		CF(-0.5, 2.655 + 6 * 0.03 + 0.02, 0.2) * UP,
		look(M.SmoothPlastic, 150, 120, 86),
		CYL
	)
	add(
		"Calculator",
		V(0.45, 0.06, 0.7),
		CF(0.4, 2.68, -0.3) * ANG(0, rad(-20), 0),
		look(M.Plastic, 50, 50, 52)
	)
	local lid = look(M.Plastic, 70, 120, 140)
	add("CoolerLid", V(1.4, 0.15, 1.0), CF(0.75, 2.73, 0.35) * ANG(0, rad(6), 0), lid)
	add(
		"CoolerLid",
		V(1.3, 0.15, 0.95),
		CF(0.78, 2.88, 0.38) * ANG(0, rad(-5), 0),
		look(M.Plastic, 196, 190, 170)
	)
	return model
end

-- A rug with one corner curled up.
function AptProps.rug(parent: Instance, at: CFrame, rng: Random, size: Vector2, l: Look): Model
	local model, add = begin(parent, "Rug", at)
	add("Rug", V(size.X, 0.04, size.Y), CF(0, 0.07, 0), tint(l, rng))
	add(
		"Curl",
		V(0.9, 0.04, 0.9),
		CF(size.X / 2 - 0.45, 0.12, size.Y / 2 - 0.45) * ANG(rad(-8), 0, rad(8)),
		tint(l, rng, 4)
	)
	return model
end

------------------------------------------------------------------------------
-- CORRIDOR
------------------------------------------------------------------------------

-- The faded runner with a worn path down its middle. `at`: its centre; length along local Z.
function AptProps.runner(parent: Instance, at: CFrame, rng: Random, length: number): Model
	local model, add = begin(parent, "Runner", at)
	add("Runner", V(2.6, 0.05, length), CF(0, 0.025, 0), look(M.Fabric, 82, 44, 40))
	add(
		"Wear",
		V(1.3, 0.03, length - 1),
		CF(rng:NextNumber(-0.1, 0.1), 0.065, 0),
		look(M.Fabric, 104, 70, 62)
	)
	-- the fringes stick out past both ends (flatter than the runner)
	for _, z in { -1, 1 } do
		add(
			"Fringe",
			V(2.6, 0.03, 0.25),
			CF(0, 0.015, z * (length / 2 + 0.125)),
			look(M.Fabric, 160, 146, 120)
		)
	end
	return model
end

-- A bundle of extension cords taped together, following world `points` (the cords lie side by
-- side; grey tape every `tapeEvery` studs). `counts[i]` = how many cords on segment i.
function AptProps.cordBundle(
	parent: Instance,
	points: { Vector3 },
	counts: { number },
	rng: Random,
	tapeEvery: number?,
	loopToward: Vector3? -- (a point in the room: stray loops go to that side, never into a wall)
): Model
	-- (cheap on parts: per run, ONE thick taped bundle + one loose cord beside it, a stray
	-- cord looping off the bundle every ~10 studs on long runs, tape every `tapeEvery` x 2)
	local model = Instance.new("Model")
	model.Name = "CordBundle"
	model.Parent = parent
	local looseLook = look(M.Plastic, 170, 166, 154)
	local bundleLook = look(M.Plastic, 38, 38, 36)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local direction = (b - a).Unit
		-- the side direction: across the run, flat on the floor / wall
		local side = direction:Cross(Vector3.yAxis)
		if side.Magnitude < 0.1 then
			side = Vector3.xAxis
		end
		side = side.Unit
		local count = counts[i] or 4
		local width = math.clamp(count * 0.07, 0.2, 0.34)
		rod(model, "Cord", a, b, width, bundleLook)
		-- the loose light cord, never quite parallel (each end moved a little)
		local jitterA = side * (width / 2 + 0.06 + rng:NextNumber(-0.05, 0.05))
		local jitterB = side * (width / 2 + 0.06 + rng:NextNumber(-0.05, 0.05))
		rod(model, "Cord", a + jitterA, b + jitterB, 0.1, looseLook)
		local length = (b - a).Magnitude
		-- a stray cord looping off the bundle and back (only on long floor runs)
		if length > 8 and math.abs(direction.Y) < 0.2 then
			local t = rng:NextNumber(2, 5)
			while t < length - 2 do
				local from = a + direction * t
				local to = from + direction * 1.6
				local sign = if rng:NextNumber() < 0.5 then -1 else 1
				if loopToward then
					sign = if side:Dot(loopToward - from) >= 0 then 1 else -1
				end
				local out = side * sign * 0.5
				path(
					model,
					"Cord",
					{ from, (from + to) / 2 + out + V(0, 0.05, 0), to },
					0.1,
					CORD_BLUE
				)
				t += rng:NextNumber(9, 12)
			end
		end
		local step = (tapeEvery or 3) * 2
		local t = step * rng:NextNumber(0.3, 0.7)
		while t < length - 0.2 do
			local centre = a + direction * t
			local tape = rod(
				model,
				"Tape",
				centre - direction * 0.13,
				centre + direction * 0.13,
				width + 0.08,
				TAPE,
				true
			)
			tape.Size = V(tape.Size.X, width + 0.06, width + 0.3)
			t += step * rng:NextNumber(0.85, 1.15)
		end
	end
	return model
end

-- A faded green garden hose along world `points`, with gentle seeded wobbles.
function AptProps.hose(parent: Instance, points: { Vector3 }, rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "Hose"
	model.Parent = parent
	local wobbled = {}
	for i, point in points do
		if i > 1 and i < #points then
			table.insert(
				wobbled,
				point + V(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06))
			)
		else
			table.insert(wobbled, point)
		end
	end
	path(model, "Hose", wobbled, 0.22, look(M.Rubber, 54, 92, 62))
	return model
end

-- A bucket: a plastic body, a rolled lip a little under its top edge, and a disc on top that is
-- either its dark inside (empty, `water` nil) or the water surface (`water` given: leak water).
function AptProps.bucket(parent: Instance, at: CFrame, rng: Random, l: Look, water: number?): Model
	local model, add = begin(parent, "Bucket", at)
	local body = tint(l, rng, 5)
	add("Bucket", V(1.3, 1.3, 1.3), CF(0, 0.65, 0) * UP, body, CYL)
	add("Rim", V(0.08, 1.42, 1.42), CF(0, 1.24, 0) * UP, body, CYL)
	add(
		"Handle",
		V(1.3, 0.05, 0.05),
		CF(0, 1.55, 0) * ANG(0, 0, rad(10)),
		look(M.Metal, 140, 140, 136)
	)
	-- (the disc stands 0.03 above the body's top: an overlay, never inside the solid body)
	if water then
		add(
			"Water",
			V(0.03, 1.18, 1.18),
			CF(0, 1.315, 0) * UP,
			look(M.Glass, 60, 58, 50, 0.1, 0.1),
			CYL
		)
	else
		add(
			"Inside",
			V(0.03, 1.18, 1.18),
			CF(0, 1.315, 0) * UP,
			look(M.SmoothPlastic, 40, 40, 38),
			CYL
		)
	end
	return model
end

-- A picture frame hanging crooked (a dark landscape, no image). On a wall; local -Z = out.
function AptProps.pictureFrame(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "PictureFrame", at)
	-- the paler rectangle where a bigger picture hung straight for years (an overlay)
	overlay(
		model,
		"Ghost",
		Vector2.new(2.2, 1.6),
		at * CF(0.15, 5.75, 0),
		LAYER.STAIN,
		look(M.Plaster, 142, 138, 124)
	)
	-- a small cheap print (a dull landscape in two bands) in a thin wooden frame, hung over it
	local tilt = ANG(0, 0, rad(4))
	add(
		"Frame",
		V(1.3, 1.0, 0.08),
		CF(0, 5.6, -LAYER.STAIN - 0.04) * tilt,
		look(M.Wood, 90, 70, 46)
	)
	add(
		"Picture",
		V(1.12, 0.5, 0.03),
		CF(0, 5.8, -LAYER.STAIN - 0.095) * tilt,
		look(M.SmoothPlastic, 104, 100, 84)
	)
	add(
		"Hills",
		V(1.12, 0.34, 0.03),
		CF(0.01, 5.38, -LAYER.STAIN - 0.095) * tilt,
		look(M.SmoothPlastic, 58, 54, 44)
	)
	return model
end

-- A dead plant: a terracotta pot with three dry stalks.
function AptProps.deadPlant(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "DeadPlant", at)
	add("Pot", V(1.1, 1.0, 1.0), CF(0, 0.55, 0) * UP, look(M.Plastic, 120, 70, 50), CYL)
	-- (the soil is a disc ON the pot's top, inside its rim: never hidden in the solid pot)
	add("Soil", V(0.03, 0.86, 0.86), CF(0, 1.115, 0) * UP, look(M.Concrete, 50, 40, 32), CYL)
	for i = 1, 3 do
		local lean = ANG(jitterAngle(rng, 8, 25), rad(i * 120), 0)
		add(
			"Stalk",
			V(0.06, 1.8, 0.06),
			CF(0, 1.1, 0) * lean * CF(0, 0.9, 0),
			look(M.Wood, 104, 82, 56)
		)
	end
	add(
		"Leaf",
		V(0.4, 0.03, 0.25),
		CF(0.4, 0.015, -0.6) * ANG(0, rad(30), 0),
		look(M.Fabric, 110, 90, 50)
	)
	return model
end

-- A broom leaning on a wall. `at` on the floor at the bristles; it leans toward local +Z.
function AptProps.broom(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "Broom", at)
	local lean = ANG(rad(-12), 0, rad(4))
	add("Head", V(1.2, 0.3, 0.3), CF(0, 0.3, 0) * lean, look(M.Plastic, 60, 90, 120))
	add("Bristles", V(1.1, 0.3, 0.28), CF(0, 0.08, 0) * lean, look(M.Fabric, 70, 64, 50))
	add("Handle", V(0.12, 5, 0.12), lean * CF(0, 2.9, 0), look(M.Wood, 150, 120, 80))
	return model
end

-- A smoke detector on the ceiling with its lid open and the battery hanging on two wires.
-- `at`: the ceiling point (local -Y = down).
function AptProps.smokeDetector(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "SmokeDetector", at)
	local white = look(M.SmoothPlastic, 214, 210, 196)
	add("Base", V(0.15, 0.9, 0.9), CF(0, -0.08, 0) * UP, white, CYL)
	add("Lid", V(0.1, 0.85, 0.85), CF(0.45, -0.35, 0) * ANG(0, 0, rad(70)), white, CYL)
	add("Wire", V(0.02, 0.5, 0.02), CF(-0.08, -0.4, 0), look(M.Plastic, 40, 40, 40))
	add("Wire", V(0.02, 0.5, 0.02), CF(0.04, -0.4, 0.04), look(M.Plastic, 40, 40, 40))
	add(
		"Battery",
		V(0.3, 0.2, 0.12),
		CF(-0.02, -0.72, 0.02) * ANG(0, rad(20), rad(8)),
		look(M.Plastic, 50, 50, 54)
	)
	return model
end

-- A coat stand with nothing on it (a silhouette against the lab's glow).
function AptProps.coatStand(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "CoatStand", at)
	local wood = look(M.Wood, 70, 52, 38)
	add("Pole", V(0.22, 6.2, 0.22), CF(0, 3.2, 0) * ANG(0, 0, rad(1.5)), wood)
	for i = 1, 3 do
		local turn = ANG(0, rad(i * 120), 0)
		add(
			"Foot",
			V(0.15, 0.12, 1.1),
			CF(0, 0.12, 0) * turn * CF(0, 0, 0.5) * ANG(rad(-10), 0, 0),
			wood
		)
		add(
			"Peg",
			V(0.1, 0.1, 0.6),
			CF(0, 5.9, 0) * turn * CF(0, 0, 0.25) * ANG(rad(-30), 0, 0),
			wood
		)
	end
	return model
end

-- A bare bulb socket on a flex, no bulb. `at`: the ceiling point.
function AptProps.deadSocket(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "DeadSocket", at)
	add("Rose", V(0.1, 0.5, 0.5), CF(0, -0.05, 0) * UP, look(M.SmoothPlastic, 200, 196, 184), CYL)
	add("Flex", V(0.04, 1.0, 0.04), CF(0, -0.55, 0), CORD_WHITE)
	add("Socket", V(0.3, 0.26, 0.26), CF(0, -1.15, 0) * UP, look(M.Plastic, 150, 120, 80), CYL)
	return model
end

-- A 3-way adapter in a wall socket with nothing plugged in, a scorch mark above it. On a wall;
-- local -Z = out.
function AptProps.outlet(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "Outlet", at)
	overlay(
		model,
		"Scorch",
		Vector2.new(0.3, 0.3),
		at * CF(0.05, 1.3, 0),
		LAYER.STAIN,
		look(M.Plaster, 90, 84, 70)
	)
	add(
		"Plate",
		V(0.5, 0.5, 0.05),
		CF(0, 1.0, -LAYER.STAIN - 0.025),
		look(M.SmoothPlastic, 206, 200, 182)
	)
	add(
		"Adapter",
		V(0.4, 0.4, 0.35),
		CF(0, 1.0, -LAYER.STAIN - 0.225),
		look(M.Plastic, 220, 216, 204)
	)
	return model
end

-- A sagging ceiling section (lowered 0.3, tilted, a dark gap round it, ring stains). `at`: the
-- ceiling point at its centre (the ceiling's underside). `size`: its width (X) and depth (Z).
function AptProps.ceilingSag(
	parent: Instance,
	at: CFrame,
	rng: Random,
	ceiling: Color3,
	size: Vector2?
): Model
	local model, add = begin(parent, "CeilingSag", at)
	local w = if size then size.X else 6
	local d = if size then size.Y else 6
	-- (the dark gap is an overlay ON the ceiling, its face 0.03 under it)
	add(
		"Gap",
		V(w + 0.1, LAYER.STEP, d + 0.1),
		CF(0, -LAYER.STEP / 2, 0),
		look(M.SmoothPlastic, 26, 24, 20)
	)
	local panel = look(M.Plaster, 0, 0, 0)
	panel.color = ceiling:Lerp(Color3.fromRGB(110, 96, 70), 0.25)
	local tilt = ANG(rad(3), 0, rad(2))
	add("Panel", V(w, 0.1, d), CF(0, -0.3, 0) * tilt, panel)
	-- ring stains on the panel's underside: each one 0.03 lower than the last (smaller ones lower)
	local stain = Color3.fromRGB(120, 100, 70)
	for i, scale in { 0.7, 0.5, 0.3 } do
		local ring = look(M.Plaster, 0, 0, 0)
		ring.color = stain:Lerp(Color3.fromRGB(80, 64, 44), (i - 1) / 2)
		local thick = LAYER.STEP * i
		local dia = math.min(w, d) * scale
		add(
			"RingStain",
			V(thick, dia, dia * rng:NextNumber(0.8, 1)),
			CF(0, -0.3, 0) * tilt * CF(0.1 * w, -0.05 - thick / 2, 0.05 * d) * UP,
			ring,
			CYL
		)
	end
	return model
end

-- Exposed pipes along world points, brackets every 4 studs, one leaking joint at `leakAt`.
function AptProps.pipes(parent: Instance, points: { Vector3 }, rng: Random, leakAt: Vector3?): Model
	local model = Instance.new("Model")
	model.Name = "Pipes"
	model.Parent = parent
	local paint = tint(look(M.Metal, 150, 146, 138), rng)
	path(model, "Pipe", points, 0.4, paint, true)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		local direction = (b - a).Unit
		local t = 2
		while t < length do
			rod(
				model,
				"Bracket",
				a + direction * (t - 0.08),
				a + direction * (t + 0.08),
				0.5,
				look(M.Metal, 90, 90, 86)
			)
			t += 4
		end
	end
	if leakAt then
		part(model, "LeakJoint", V(0.55, 0.55, 0.55), CF(leakAt), RUST, BALL)
		part(
			model,
			"LeakStreak",
			V(0.5, 0.02, 1.4),
			CF(leakAt + V(-0.6, 0.15, 0)),
			look(M.CorrodedMetal, 90, 70, 50)
		)
	end
	return model
end

------------------------------------------------------------------------------
-- BATHROOM
------------------------------------------------------------------------------

-- A stained bathtub (tide-line), murky water. Front = local -Z; length along local X (7 long,
-- 2.5 wide). The walls stand BETWEEN the two ends and the bottom inside all four, so no two
-- enamel panels share a face. Its taps, shower and curtain are on the wall (tubFittings).
function AptProps.bathtub(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "Bathtub", at)
	local enamel = solid(tint(look(M.SmoothPlastic, 206, 204, 192), rng))
	for _, x in { -3.38, 3.38 } do
		add("End", V(0.16, 2.2, 2.52), CF(x, 1.1, 0), enamel)
	end
	for _, z in { -1.18, 1.18 } do
		add("Wall", V(6.6, 2.2, 0.16), CF(0, 1.1, z), enamel)
	end
	add("Bottom", V(6.6, 0.4, 2.2), CF(0, 0.2, 0), enamel)
	add("Inside", V(6.6, 0.03, 2.2), CF(0, 0.415, 0), look(M.SmoothPlastic, 176, 172, 156))
	add("Water", V(6.6, 0.03, 2.2), CF(0, 0.8, 0), look(M.Glass, 70, 78, 64, 0.3, 0.05))
	-- the tide-line: a brown band on the four inner faces, just above the water
	local tide = look(M.SmoothPlastic, 132, 120, 100)
	for _, z in { -1.1, 1.1 } do
		overlay(
			model,
			"TideLine",
			Vector2.new(6.6, 0.18),
			at * CF(0, 0.92, z) * (if z < 0 then ANG(0, math.pi, 0) else CFrame.identity),
			LAYER.STEP,
			tide
		)
	end
	for _, x in { -3.3, 3.3 } do
		overlay(
			model,
			"TideLine",
			Vector2.new(2.14, 0.18),
			at * CF(x, 0.92, 0) * ANG(0, if x < 0 then rad(-90) else rad(90), 0),
			LAYER.STEP,
			tide
		)
	end
	return model
end

-- The tub's fittings on the wall above its north end: a mixer with two taps and a spout, a
-- shower hose up to its holder, the curtain rail along the tub with a mouldy curtain pushed
-- back. The garden hose is pushed onto the spout with a jubilee clip (the lab's water).
-- `at`: on the floor ON the wall face, local -Z = out of the wall; the tub runs from here along
-- local -X. Returns the model and the world point where the garden hose starts (the spout).
function AptProps.tubFittings(parent: Instance, at: CFrame, rng: Random): (Model, Vector3)
	local model, add = begin(parent, "TubFittings", at)
	local chrome = look(M.Metal, 170, 172, 170, 0, 0.1)
	add("MixerPlate", V(0.9, 0.35, 0.06), CF(0, 3.6, -0.03), chrome)
	for _, x in { -0.35, 0.35 } do
		add("TapHead", V(0.12, 0.24, 0.24), CF(x, 3.6, -0.18) * ALONG_Z, chrome, CYL)
	end
	add("Spout", V(0.4, 0.12, 0.12), CF(0, 3.45, -0.26) * ALONG_Z, chrome, CYL)
	local spoutEnd = (at * CF(0, 3.45, -0.46)).Position
	-- the jubilee clip and tape where the garden hose is forced onto the spout
	add("Clip", V(0.12, 0.3, 0.3), CF(0, 3.45, -0.42) * ALONG_Z, look(M.Metal, 150, 150, 146), CYL)
	add("HoseTape", V(0.1, 0.27, 0.27), CF(0, 3.45, -0.55) * ALONG_Z, TAPE, CYL)
	-- the shower: hose up the wall to its holder (over the tub), the head in it
	local hose = look(M.Metal, 160, 162, 160)
	path(model, "ShowerHose", {
		(at * CF(-0.35, 3.45, -0.12)).Position,
		(at * CF(-0.6, 3.0, -0.16)).Position,
		(at * CF(-0.8, 4.4, -0.14)).Position,
		(at * CF(-0.8, 6.2, -0.14)).Position,
	}, 0.07, hose)
	add("Holder", V(0.2, 0.25, 0.2), CF(-0.8, 6.45, -0.1), chrome)
	add("ShowerHead", V(0.3, 0.45, 0.45), CF(-0.8, 6.75, -0.28) * ANG(0, 0, rad(-70)), chrome, CYL)
	-- the curtain rail along the tub's open side, 2.5 out from the wall, two wall brackets
	local rail = look(M.Metal, 150, 150, 146)
	add("Rail", V(6.4, 0.07, 0.07), CF(-3.3, 7.5, -2.5), rail, CYL)
	add("RailArm", V(0.07, 0.07, 2.5), CF(-0.1, 7.5, -1.25), rail)
	add("RailArm", V(0.07, 0.07, 2.5), CF(-6.5, 7.5, -1.25), rail)
	-- the curtain, pushed back to this end in three folds (a dirty grey-green)
	local curtain = tint(look(M.Fabric, 132, 146, 130), rng, 5)
	for i = 1, 3 do
		add(
			"Curtain",
			V(0.5, 5.2, 0.08),
			CF(-0.35 - i * 0.3, 4.85, -2.5 + (i % 2) * 0.12)
				* ANG(0, rad(35 * (if i % 2 == 0 then 1 else -1)), 0),
			curtain
		)
	end

	return model, spoutEnd
end

-- A toilet: pedestal, bowl, the seat UP, the cistern on the wall with its flush button, the
-- pipe into the floor. Front = local -Z (`at` on the floor against the wall).
function AptProps.toilet(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "Toilet", at)
	local china = solid(tint(look(M.SmoothPlastic, 214, 214, 206), rng, 4))
	add("Pedestal", V(0.9, 1.2, 1.3), CF(0, 0.6, -0.85), china)
	add("Bowl", V(1.4, 0.45, 1.9), CF(0, 1.42, -1.05), china)
	add("BowlInside", V(1.0, 0.03, 1.4), CF(0, 1.66, -1.1), look(M.SmoothPlastic, 150, 150, 136))
	-- (the seat is up: hinged at the bowl's back edge, leaning on the cistern)
	add(
		"Seat",
		V(1.35, 0.08, 1.75),
		CF(0, 1.69, -0.8) * ANG(rad(-85), 0, 0) * CF(0, 0, 0.875),
		look(M.Plastic, 230, 228, 220)
	)
	add("Cistern", V(1.6, 1.4, 0.6), CF(0, 2.8, -0.3), china)
	add("CisternLid", V(1.66, 0.1, 0.66), CF(0, 3.55, -0.34), china)
	add("Flush", V(0.08, 0.26, 0.26), CF(0, 3.64, -0.3) * UP, look(M.Metal, 170, 172, 170), CYL)
	add("Pipe", V(0.25, 0.25, 0.5), CF(0, 0.3, -0.25), look(M.Plastic, 200, 198, 190))
	-- a limescale stain down the inside of the bowl's back (the flat is not cleaned)
	add("Limescale", V(0.5, 0.03, 0.3), CF(0, 1.7, -0.55), look(M.SmoothPlastic, 150, 140, 104))
	return model
end

-- The basin and the mirror cabinet above it (cabinet open, empty, cracked mirror). On a wall;
-- local -Z = out. Returns the model.
function AptProps.basinCabinet(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "BasinCabinet", at)
	local ceramic = look(M.SmoothPlastic, 214, 214, 204)
	add("Basin", V(2, 0.5, 1.4), CF(0, 2.9, -0.7), ceramic)
	add("Bowl", V(1.6, 0.03, 1.0), CF(0, 3.165, -0.75), look(M.SmoothPlastic, 170, 168, 150))
	add("Pedestal", V(0.6, 2.6, 0.6), CF(0, 1.3, -0.45), ceramic)
	add("Tap", V(0.12, 0.45, 0.12), CF(0, 3.375, -0.2), look(M.Metal, 150, 146, 138))
	add("Spout", V(0.1, 0.1, 0.45), CF(0, 3.53, -0.4), look(M.Metal, 150, 146, 138))
	add("Plughole", V(0.03, 0.2, 0.2), CF(0, 3.195, -0.75) * UP, look(M.Metal, 60, 60, 60), CYL)
	-- the cabinet: back, sides, shelves BETWEEN the sides and in front of the back (no shared
	-- face), door open with a cracked mirror (two pieces, a gap)
	local box = tint(look(M.SmoothPlastic, 196, 194, 182), rng)
	add("Cabinet", V(1.9, 2.3, 0.1), CF(0, 6.0, -0.05), box)
	for _, x in { -0.95, 0.95 } do
		add("CabinetSide", V(0.06, 2.3, 0.5), CF(x, 6.0, -0.35), box)
	end
	for _, y in { 4.9, 5.6, 6.4, 7.1 } do
		add("CabinetShelf", V(1.84, 0.06, 0.5), CF(0, y, -0.35), box)
	end
	local hinge = CF(0.95, 6.0, -0.62) * ANG(0, rad(-115), 0)
	add("CabinetDoor", V(1.9, 2.3, 0.08), hinge * CF(-0.95, 0, 0), box)
	add(
		"Mirror",
		V(1.7, 1.25, 0.03),
		hinge * CF(-0.95, 0.5, -0.055) * ANG(0, 0, rad(1)),
		look(M.Glass, 150, 156, 150, 0, 0.3)
	)
	add(
		"Mirror",
		V(1.7, 0.85, 0.03),
		hinge * CF(-0.95, -0.6, -0.055) * ANG(0, 0, rad(-1)),
		look(M.Glass, 150, 156, 150, 0, 0.3)
	)
	return model
end

-- A stack of folded clear plastic sheeting on the floor (6 slabs of different sizes).
function AptProps.foldedSheeting(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "FoldedSheeting", at)
	local y = 0
	for _ = 1, 6 do
		local height = rng:NextNumber(0.12, 0.2)
		add(
			"Sheeting",
			V(rng:NextNumber(1.6, 2.1), height, rng:NextNumber(1.1, 1.4)),
			CF(rng:NextNumber(-0.1, 0.1), y + height / 2, rng:NextNumber(-0.1, 0.1))
				* ANG(0, jitterAngle(rng, 2, 8), 0),
			look(M.Glass, 200, 210, 210, 0.5)
		)
		y += height
	end
	add("Tape", V(0.3, y, 1.2), CF(0.4, y / 2 + 0.02, 0), TAPE)
	return model
end

-- Rubber gloves draped over something (two flat hands + cuffs). `at`: where they hang.
function AptProps.gloves(parent: Instance, at: CFrame, _rng: Random, l: Look): Model
	local model, add = begin(parent, "Gloves", at)
	add("Glove", V(0.5, 0.06, 1.2), CF(0, 0, 0) * ANG(rad(-60), 0, rad(6)), l)
	add("Glove", V(0.5, 0.06, 1.1), CF(0.35, -0.05, 0.1) * ANG(rad(-70), rad(10), rad(-4)), l)
	add("Fingers", V(0.45, 0.06, 0.4), CF(0.05, -0.55, 0.3) * ANG(rad(-90), 0, 0), l)
	return model
end

-- A towel on a rail. On a wall; local -Z = out.
function AptProps.towelRail(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "TowelRail", at)
	add("Rail", V(2, 0.1, 0.1), CF(0, 5, -0.3), look(M.Metal, 170, 170, 164), CYL)
	add(
		"Towel",
		V(1.3, 2.2, 0.1),
		CF(0.1, 4.0, -0.32) * ANG(0, 0, rad(3)),
		tint(look(M.Fabric, 120, 128, 120), rng)
	)
	return model
end

-- Mould clusters in a ceiling corner. `at`: the corner point on the ceiling. Each cluster hangs
-- one level (0.03) lower than the one before: overlapping clusters never share a plane.
function AptProps.mould(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "Mould", at)
	for i = 1, 3 do
		local thick = LAYER.STEP * i
		add(
			"Mould",
			V(rng:NextNumber(0.3, 1.2), thick, rng:NextNumber(0.3, 1.0)),
			CF(rng:NextNumber(0.3, 1.3), -thick / 2, rng:NextNumber(0.3, 1.3))
				* ANG(0, rng:NextNumber(0, 3), 0),
			tint(look(M.Fabric, 36, 44, 34), rng, 5)
		)
	end
	return model
end

------------------------------------------------------------------------------
-- BEDROOM 2 (the cook's room)
------------------------------------------------------------------------------

-- A mattress on the floor with a half-open sleeping bag and a pillow.
function AptProps.mattress(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "Mattress", at)
	add(
		"Mattress",
		V(4.2, 0.7, 6.2),
		CF(0, 0.35, 0),
		solid(tint(look(M.Fabric, 150, 146, 130), rng))
	)
	add(
		"Stain",
		V(1.4, 0.03, 1.1),
		CF(0.9, 0.715, 1.2) * ANG(0, rad(20), 0),
		look(M.Fabric, 124, 116, 96)
	)
	local bag = tint(look(M.Fabric, 52, 70, 64), rng)
	add("SleepingBag", V(3.0, 0.35, 4.2), CF(-0.2, 0.86, -0.8) * ANG(0, rad(-4), 0), bag)
	add("BagFlap", V(1.6, 0.12, 3.6), CF(1.0, 0.82, -0.6) * ANG(rad(-2), rad(-12), rad(-6)), bag)
	add("Zip", V(0.04, 0.05, 3.6), CF(0.25, 1.06, -0.75), look(M.Metal, 120, 120, 116))
	add(
		"Pillow",
		V(1.8, 0.4, 1.1),
		CF(-0.3, 0.9, 2.3) * ANG(0, rad(6), 0),
		look(M.Fabric, 190, 186, 170)
	)
	return model
end

-- An upturned crate with an alarm clock frozen at 03:17 (amber digits).
function AptProps.alarmClock(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "AlarmClock", at)
	add("Crate", V(1.6, 1.3, 1.3), CF(0, 0.65, 0), tint(look(M.Plastic, 96, 92, 70), rng))
	add(
		"Clock",
		V(0.8, 0.45, 0.35),
		CF(0.1, 1.53, 0) * ANG(0, rad(-15), 0),
		look(M.Plastic, 30, 30, 32)
	)
	local face = add(
		"Digits",
		V(0.6, 0.25, 0.02),
		CF(0.1, 1.55, 0) * ANG(0, rad(-15), 0) * CF(0, 0, -0.2),
		look(M.Neon, 255, 150, 60, 0.6)
	)
	writeOn(face, Enum.NormalId.Front, "03:17", Color3.fromRGB(255, 150, 60), Enum.Font.Code, 120)
	add(
		"Mug",
		V(0.35, 0.3, 0.3),
		CF(-0.45, 1.48, 0.3) * UP,
		look(M.SmoothPlastic, 120, 96, 70),
		CYL
	)
	return model
end

-- A wooden chair with clothes draped over it.
function AptProps.chairClothes(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "ChairClothes", at)
	local wood = tint(look(M.Wood, 110, 84, 60), rng)
	add("Seat", V(1.6, 0.15, 1.6), CF(0, 2.0, 0), solid(wood))
	add("Backrest", V(1.6, 2.0, 0.15), CF(0, 3.1, 0.75), wood)
	for _, x in { -0.7, 0.7 } do
		for _, z in { -0.7, 0.7 } do
			add("Leg", V(0.14, 2.0, 0.14), CF(x, 1.0, z), wood)
		end
	end
	add(
		"Hoodie",
		V(1.5, 1.6, 0.5),
		CF(0, 3.2, 0.85) * ANG(rad(-6), 0, rad(3)),
		tint(look(M.Fabric, 70, 74, 80), rng)
	)
	add(
		"Jeans",
		V(1.2, 0.2, 1.7),
		CF(0.1, 2.18, 0) * ANG(0, rad(10), rad(-4)),
		look(M.Fabric, 50, 62, 90)
	)
	add(
		"Shirt",
		V(0.9, 1.4, 0.1),
		CF(0.85, 1.5, -0.1) * ANG(0, 0, rad(-8)),
		look(M.Fabric, 150, 150, 140)
	)
	return model
end

-- The folding desk by the window: where he watches the culture at night. An open laptop (its
-- screen glows faintly), a notebook, energy-drink cans, an instant-noodle cup, the desk lamp
-- (the light is a fixture), a cooler box used as a stool. Front = local -Z, 6 long (local X).
function AptProps.deskTable(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "DeskTable", at)
	add("Top", V(6, 0.1, 2.1), CF(0, 2.8, 0), solid(look(M.Plastic, 170, 164, 146)))
	for _, x in { -2.8, 2.8 } do
		add("Leg", V(0.12, 2.75, 1.9), CF(x, 1.375, 0), look(M.Metal, 110, 110, 106))
	end
	-- the open laptop: base on the desk, screen tilted back, its glow
	local laptop = CF(-1.4, 2.89, -0.1) * ANG(0, rad(10), 0)
	add("Laptop", V(1.3, 0.08, 0.9), laptop, look(M.Plastic, 52, 52, 56))
	local lid = laptop * CF(0, 0.04, 0.45) * ANG(rad(-105), 0, 0) * CF(0, 0, -0.45)
	add("LaptopLid", V(1.3, 0.05, 0.9), lid, look(M.Plastic, 52, 52, 56))
	add("LaptopScreen", V(1.16, 0.03, 0.76), lid * CF(0, -0.04, 0), look(M.Neon, 70, 96, 110, 0.06))
	add(
		"Notebook",
		V(0.8, 0.06, 1.1),
		CF(0.4, 2.88, 0.2) * ANG(0, rad(-18), 0),
		look(M.SmoothPlastic, 40, 60, 90)
	)
	add(
		"Pen",
		V(0.6, 0.04, 0.04),
		CF(0.9, 2.87, -0.5) * ANG(0, rad(40), 0),
		look(M.Plastic, 30, 30, 40),
		CYL
	)
	-- three energy-drink cans (one on its side) and a noodle cup with its fork
	local can = look(M.Metal, 60, 90, 70, 0, 0.1)
	add("Can", V(0.45, 0.24, 0.24), CF(0.0, 3.075, -0.6) * UP, can, CYL)
	add("Can", V(0.45, 0.24, 0.24), CF(-0.25, 3.075, -0.75) * UP, tint(can, rng, 8), CYL)
	add("Can", V(0.45, 0.24, 0.24), CF(1.3, 2.97, 0.5) * ANG(0, rad(70), 0), can, CYL)
	add(
		"NoodleCup",
		V(0.42, 0.4, 0.4),
		CF(1.0, 3.06, -0.2) * UP,
		look(M.SmoothPlastic, 220, 210, 180),
		CYL
	)
	add(
		"Fork",
		V(0.03, 0.45, 0.03),
		CF(1.02, 3.35, -0.2) * ANG(rad(12), 0, 0),
		look(M.Plastic, 230, 230, 226)
	)
	-- the desk lamp (arm + shade; the SpotLight is the DeskLamp fixture over it)
	local lampLook = look(M.Metal, 60, 64, 60)
	add("LampBase", V(0.12, 0.6, 0.6), CF(1.9, 2.91, 0.4) * UP, lampLook, CYL)
	add("LampArm", V(0.08, 1.6, 0.08), CF(1.9, 3.6, 0.3) * ANG(rad(-15), 0, 0), lampLook)
	add("LampArm", V(0.08, 1.0, 0.08), CF(1.9, 4.45, 0.05) * ANG(rad(55), 0, 0), lampLook)
	add("LampShade", V(0.5, 0.55, 0.55), CF(1.9, 4.65, -0.4) * UP, lampLook, CYL)
	-- the cooler-box stool
	add("CoolerStool", V(1.8, 1.4, 1.2), CF(-1.0, 0.7, -1.7), solid(look(M.Plastic, 196, 190, 170)))
	add("CoolerLid", V(1.86, 0.15, 1.26), CF(-1.0, 1.475, -1.7), look(M.Plastic, 70, 120, 140))
	return model
end

-- The whiteboard: the clone timeline in marker pen (a growth curve, "MATRIX / FRAME / SHELL",
-- the failed batch). On a wall; local -Z = out. 4 wide, 2.6 high, from y 3.6 to 6.2.
function AptProps.whiteboard(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "Whiteboard", at)
	add("Frame", V(4.16, 2.76, 0.08), CF(0, 4.9, -0.04), look(M.Metal, 150, 150, 146))
	local board =
		add("Board", V(4, 2.6, 0.04), CF(0, 4.9, -0.1), look(M.SmoothPlastic, 228, 230, 226))
	-- (the board's face is at z -0.12: everything drawn on it is a 0.03 overlay, centred at
	-- inkZ, and the text holders sit just in front of that)
	local inkZ = -0.12 - 0.015
	local marker = Color3.fromRGB(40, 60, 90)
	-- (the numbers below read like a page: x grows to the READER's right. A prop's local +X is
	-- the viewer's LEFT when facing its front, so every x is mirrored with -x.)
	local function line(text: string, x: number, y: number, w: number, h: number, angle: number?)
		local strip = add(
			"Writing",
			V(w, h, 0.01),
			CF(-x, y, inkZ - 0.01) * ANG(0, 0, rad(angle or 0)),
			look(M.SmoothPlastic, 228, 230, 226, 1)
		)
		writeOn(strip, Enum.NormalId.Front, text, marker, Enum.Font.PermanentMarker, 50)
	end
	-- (the phase labels 0.35 above the tray's top, the title clear of the curve: "->", not an
	-- arrow glyph the font may not have)
	line("MATRIX", -1.3, 4.0, 0.9, 0.24)
	line("FRAME", -0.15, 4.0, 0.9, 0.24)
	line("SHELL", 1.0, 4.0, 0.9, 0.24)
	line("BATCH 14 -> FAILED", 0.85, 5.88, 1.6, 0.28, -2)
	-- the growth curve itself: a few thin marker strokes (above the labels, under the title)
	local stroke = look(M.SmoothPlastic, 40, 60, 90)
	local points = {
		V(-1.8, 4.3, 0),
		V(-1.25, 4.38, 0),
		V(-0.75, 4.65, 0),
		V(-0.25, 5.1, 0),
		V(0.2, 5.38, 0),
		V(0.5, 5.48, 0),
	}
	for i = 1, #points - 1 do
		-- (board-centre space: its face is at z -0.02, a 0.025 stroke centred at -0.031 rests
		-- just on it)
		local a = (board.CFrame * CF(-points[i].X, points[i].Y - 4.9, -0.031)).Position
		local b = (board.CFrame * CF(-points[i + 1].X, points[i + 1].Y - 4.9, -0.031)).Position
		rod(model, "Stroke", a, b, 0.025, stroke)
	end
	for _, x in { -0.72, 0.42 } do
		-- (short ticks on the time axis, not tall bars: tall ones made the curve read as an "N")
		add("PhaseMark", V(0.02, 0.28, 0.03), CF(-x, 4.3, inkZ), stroke)
	end
	add("Tray", V(3.4, 0.1, 0.3), CF(0, 3.47, -0.27), look(M.Metal, 150, 150, 146))
	add("Marker", V(0.6, 0.08, 0.08), CF(0.8, 3.56, -0.29), look(M.Plastic, 30, 40, 80), CYL)
	return model
end

-- Five cardboard boxes of supplies (one open with coiled tubing: it says "tubing" by itself).
function AptProps.supplyBoxes(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "SupplyBoxes", at)
	local card = look(M.Cardboard, 150, 118, 82)
	local specs = {
		{ size = V(1.8, 1.4, 1.5), at = CF(-0.9, 0.7, 0.4) },
		{ size = V(1.5, 1.1, 1.3), at = CF(-0.8, 1.95, 0.45) },
		{ size = V(1.6, 1.6, 1.4), at = CF(1.0, 0.8, 0.5) },
		{ size = V(1.2, 0.9, 1.0), at = CF(1.1, 2.05, 0.4) },
		{ size = V(1.4, 1.0, 1.2), at = CF(0.4, 0.5, -1.2) },
	}
	for i, spec in specs do
		add("Box", spec.size, spec.at * ANG(0, jitterAngle(rng, 2, 9), 0), tint(card, rng))
		if i == 5 then
			-- the open one: flaps up, coiled tubing inside
			add("Flap", V(1.4, 0.05, 0.6), spec.at * CF(0, 0.5, -0.85) * ANG(rad(60), 0, 0), card)
			for c = 1, 3 do
				add(
					"Coil",
					V(0.15, 0.9 - c * 0.1, 0.9 - c * 0.1),
					spec.at * CF(0, 0.45 + c * 0.05, 0) * UP,
					look(M.Glass, 210, 225, 220, 0.4),
					CYL
				)
			end
		end
	end
	return model
end

-- A paper calendar taped on a wall, days crossed out.
function AptProps.calendar(parent: Instance, at: CFrame, _rng: Random): Model
	local model = begin(parent, "Calendar", at)
	local page = overlay(
		model,
		"Page",
		Vector2.new(1.4, 1.8),
		at * CF(0, 5.5, 0) * ANG(0, 0, rad(-2)),
		LAYER.STEP,
		PAPER
	)
	writeOn(
		page,
		Enum.NormalId.Front,
		"X X X X X X X\nX X X X X X X\nX X X . . . .",
		Color3.fromRGB(40, 40, 46),
		Enum.Font.PermanentMarker,
		40
	)
	overlay(model, "Tape", Vector2.new(0.4, 0.12), at * CF(0, 6.4, 0), 2 * LAYER.STEP, TAPE)
	return model
end

-- A half-open duffel bag at the mattress's foot, clothes spilling out (he moved in with it).
function AptProps.duffelBag(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "DuffelBag", at)
	local canvas = tint(look(M.Fabric, 40, 52, 46), rng, 5)
	add("Bag", V(2.6, 1.0, 1.0), CF(0, 0.5, 0) * ANG(0, 0, 0), canvas, CYL)
	add(
		"Strap",
		V(0.15, 0.05, 1.6),
		CF(0.6, 1.0, 0) * ANG(0, rad(10), rad(30)),
		look(M.Fabric, 30, 30, 32)
	)
	add(
		"Shirt",
		V(1.0, 0.12, 0.9),
		CF(-1.0, 0.06, 0.75) * ANG(0, rad(25), 0),
		look(M.Fabric, 150, 150, 140)
	)
	add(
		"Hoodie",
		V(1.1, 0.25, 0.8),
		CF(-0.9, 0.9, -0.35) * ANG(rad(20), rad(-10), 0),
		look(M.Fabric, 70, 74, 80)
	)
	return model
end

-- A small electric fan heater on the floor, pointed at the mattress (the flat is cold): a box,
-- an orange glow behind its grille. Front = local -Z.
function AptProps.fanHeater(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "FanHeater", at)
	add("Body", V(1.0, 1.1, 0.7), CF(0, 0.6, 0), look(M.Plastic, 196, 192, 180))
	add("Foot", V(1.1, 0.06, 0.8), CF(0, 0.03, 0), look(M.Plastic, 60, 60, 60))
	add("Glow", V(0.7, 0.6, 0.03), CF(0, 0.65, -0.365), look(M.Neon, 255, 130, 50, 0.3))
	for i = 1, 4 do
		add("Grille", V(0.72, 0.04, 0.04), CF(0, 0.4 + i * 0.12, -0.4), look(M.Metal, 70, 70, 70))
	end
	add("Dial", V(0.08, 0.18, 0.18), CF(0.3, 1.18, 0.1) * UP, look(M.Plastic, 40, 40, 40), CYL)
	return model
end

-- A sack truck (hand trolley) leaning against a wall: how the vat, the freezer and the cases came
-- up the stairs. `at` on the floor at its wheels, it leans toward local +Z (the wall).
function AptProps.sackTruck(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "SackTruck", at)
	local lean = ANG(rad(14), 0, 0) -- (its top toward local +Z)
	local frame = look(M.Metal, 60, 90, 120)
	for _, x in { -0.6, 0.6 } do
		add("Rail", V(0.1, 4.4, 0.1), CF(x, 0.35, 0) * lean * CF(0, 2.2, 0), frame)
		add("Wheel", V(0.25, 0.7, 0.7), CF(x * 1.25, 0.35, -0.15), look(M.Rubber, 30, 30, 30), CYL)
	end
	for _, y in { 1.4, 2.6, 3.8 } do
		add("Bar", V(1.2, 0.08, 0.08), CF(0, 0.35, 0) * lean * CF(0, y, 0), frame)
	end
	add("Toe", V(1.3, 0.05, 0.6), CF(0, 0.08, -0.3), look(M.Metal, 120, 120, 116))
	add("Axle", V(1.6, 0.08, 0.08), CF(0, 0.35, -0.15), look(M.Metal, 80, 80, 80), CYL)
	return model
end

-- Flattened delivery cartons and their packing straps, leaning toward local +Z (a wall; no labels).
function AptProps.flatCartons(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "FlatCartons", at)
	local card = look(M.Cardboard, 150, 118, 82)
	add("Carton", V(3.2, 3.6, 0.08), CF(0, 1.78, 0.25) * ANG(rad(6), 0, 0), tint(card, rng))
	add("Carton", V(2.6, 3.0, 0.08), CF(0.3, 1.48, 0.0) * ANG(rad(8), 0, rad(2)), tint(card, rng))
	add(
		"Strap",
		V(0.12, 0.03, 2.0),
		CF(-0.6, 0.015, -0.9) * ANG(0, rad(20), 0),
		look(M.Plastic, 200, 190, 60)
	)
	add(
		"Strap",
		V(0.12, 0.03, 1.6),
		CF(0.4, 0.015, -1.0) * ANG(0, rad(-35), 0),
		look(M.Plastic, 200, 190, 60)
	)
	return model
end

-- A black rubbish bag, tied: one lumpy body (three overlapping blobs sinking into each other)
-- and the knot on top. `at` on the floor.
function AptProps.trashBag(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "TrashBag", at)
	local bag = look(M.Plastic, 40, 42, 44, 0, 0.08)
	add("Bag", V(1.2, 1.2, 1.2), CF(-0.3, 0.6, 0), bag, BALL)
	add("Bag", V(1.1, 1.1, 1.1), CF(0.35, 0.56, 0.15) * ANG(0, jitterAngle(rng), 0), bag, BALL)
	add("Bag", V(0.9, 0.9, 0.9), CF(0.05, 1.1, 0.05), bag, BALL)
	add("Neck", V(0.3, 0.3, 0.3), CF(0.05, 1.58, 0.05), bag, BALL)
	add("Knot", V(0.3, 0.2, 0.18), CF(0.06, 1.78, 0.05) * ANG(0, rad(30), 0), bag)
	return model
end

------------------------------------------------------------------------------
-- THE LAB (the converted back bedroom)
------------------------------------------------------------------------------

-- The plastic tent: battens on the walls and ceiling, clear sheets hung off the walls (each
-- one turned a little: they sag), taped seams, sagging ceiling bays. Built in flat-local
-- coordinates through `toWorld` (the lab's interior: X 10..28, Z 0..24, ceiling 11).
-- Neighbouring sheets overlap at their edges, so they hang at two alternating depths 0.12
-- apart (overlapping sheets never share a plane). The ceiling plastic is cut away over the vat
-- (X 14.5..23.5, Z 16.6..24): its cables and light bar go up to the real ceiling.
-- The sheets are SmoothPlastic, never Material Glass: Glass hides every see-through part behind
-- it (the vat's fluid seen through the strip curtain and the airlock sheets, for one).
-- Returns the model and the sheets to sway (Anim/Sheet_1..3 are made by LabBuilder from them).
function AptProps.plasticTent(
	parent: Instance,
	toWorld: (CFrame) -> CFrame,
	rng: Random
): (Model, { Part })
	local model = Instance.new("Model")
	model.Name = "PlasticTent"
	model.Parent = parent
	local batten = look(M.Wood, 150, 128, 96)
	local swayable: { Part } = {}
	local function add(name: string, size: Vector3, localCf: CFrame, l: Look): Part
		return part(model, name, size, toWorld(localCf), l)
	end
	-- wall battens along the top of the N, E and S walls (they butt at the corners)
	add("Batten", V(17.3, 0.2, 0.2), CF(19, 10.6, 23.7), batten)
	add("Batten", V(0.2, 0.2, 23.0), CF(27.75, 10.6, 12.125), batten)
	add("Batten", V(17.3, 0.2, 0.2), CF(19, 10.6, 0.55), batten)
	-- ceiling battens every 3 studs (across the room, along Z), and the one along the edge of
	-- the cut-out over the vat
	for x = 11.5, 27, 3 do
		add("Batten", V(0.2, 0.2, 23.0), CF(x, 10.85, 12.125), batten)
	end
	add("Batten", V(8.8, 0.15, 0.15), CF(19, 10.72, 16.6), batten)
	-- sheets: N wall (Z 23.6), E wall (X 27.76), S wall (Z 0.62, around the window); their tops
	-- hang just under the wall battens (10.49)
	-- `inward` = the direction of the room from the sheet; `index` picks its depth (odd ones
	-- hang 0.12 further out from the wall)
	local function sheet(
		centre: Vector3,
		width: number,
		height: number,
		inward: Vector3,
		index: number
	): Part
		local alongX = math.abs(inward.Z) > 0.5
		local sag = ANG(
			rad(rng:NextNumber(0.2, 0.5)) * (if rng:NextNumber() < 0.5 then -1 else 1),
			0,
			rad(rng:NextNumber(-0.4, 0.4))
		)
		local size = if alongX then V(width, height, 0.03) else V(0.03, height, width)
		local sheetLook = tint(SHEET, rng, 4)
		if rng:NextNumber() < 0.35 then
			-- an older sheet: yellowed / greyed by months of damp
			sheetLook.color = sheetLook.color:Lerp(Color3.fromRGB(150, 150, 128), 0.45)
			sheetLook.transparency = 0.5
		end
		local at = centre + inward * (if index % 2 == 1 then 0.12 else 0)
		local sheetPart = add("Sheet", size, CF(at) * sag, sheetLook)
		sheetPart.CastShadow = false
		if rng:NextNumber() < 0.3 then
			-- a grime smear low on the sheet's room face (hands, splashes): an overlay. (The
			-- flat is never rotated: `inward` is also the world direction.)
			local onFace = (sheetPart.CFrame * CF(0, -height / 2 + rng:NextNumber(1.2, 3), 0)).Position
				+ inward * 0.015
			local smear = overlay(
				model,
				"Grime",
				Vector2.new(rng:NextNumber(0.8, 1.6), rng:NextNumber(0.6, 1.4)),
				CFrame.lookAt(onFace, onFace + inward),
				LAYER.STEP,
				look(M.SmoothPlastic, 96, 100, 88, 0.55)
			)
			smear.CastShadow = false
		end
		return sheetPart
	end
	for i = 0, 5 do
		local made = sheet(V(11.5 + i * 3, 5.24, 23.6), 3.1, 10.5, -Vector3.zAxis, i)
		if i == 4 then
			table.insert(swayable, made)
		end
	end
	for i = 0, 7 do
		local made = sheet(V(27.76, 5.24, 1.5 + i * 3), 3.1, 10.5, -Vector3.xAxis, i)
		if i == 1 then
			table.insert(swayable, made)
		end
	end
	-- the S wall: full sheets left and right of the window, a short one above it
	-- (the two W-most sheets have torn off their batten: only their lower part is still taped
	-- up, and the old bedroom wallpaper shows above them; see AptProps.bedroomLeftovers)
	for i, x in { 11.5, 14.5 } do
		sheet(V(x, 3.0, 0.62), 3.1, 6.0, Vector3.zAxis, i)
	end
	for i, x in { 23.5, 26.5 } do
		local made = sheet(V(x, 5.24, 0.62), 3.1, 10.5, Vector3.zAxis, i)
		if x == 23.5 then
			table.insert(swayable, made)
		end
	end
	-- (above the window: it stops at 8.3, clear of the old curtain rail and the exhaust duct)
	sheet(V(19, 9.55, 0.9), 6.4, 2.5, Vector3.zAxis, 0)
	-- the sheets that close the "airlock" by the door (W side, next to the strip curtain)
	sheet(V(11.4, 5.4, 18.2), 1.4, 10.8, Vector3.xAxis, 0)
	sheet(V(11.4, 5.4, 12.3), 1.4, 10.8, Vector3.xAxis, 0)
	-- taped seams (vertical strips on a few joins, on the sheet in front). The sheets hang up
	-- to 0.5° off true, so over their height their face moves ±0.05: the tape stands 0.08 in
	-- front of the front sheet's middle plane, never on (or flickering through) its face.
	local TAPE_OUT = 0.12 + 0.08
	for _, x in { 13, 19, 25 } do
		add("SeamTape", V(0.3, 10.2, 0.03), CF(x, 5.3, 23.6 - TAPE_OUT), TAPE)
	end
	for _, z in { 6, 12, 18 } do
		add("SeamTape", V(0.03, 10.2, 0.3), CF(27.76 - TAPE_OUT, 5.3, z), TAPE)
	end
	-- the ceiling: every 3-stud bay sags between its battens (one sheet per bay, hanging lower
	-- than the battens and a little skewed; neighbours at alternating heights). The bays over
	-- the vat stop at the cut-out's batten.
	local bay = 0
	for x = 11.5, 25, 3 do
		bay += 1
		local centreX = x + 1.5
		local overVat = centreX > 14.5 and centreX < 23.5
		-- (between the S and N wall sheets' tops, never touching them: they hang up to 0.05
		-- off true)
		local z0, z1 = 0.98, 23.4 -- (0.98: clear of the short sheet over the window, z 0.9)
		if overVat then
			z1 = 16.6
		end
		local depth = if bay % 2 == 0 then 0.32 else 0.18
		local panel = add(
			"CeilingSheet",
			V(3.05, 0.03, z1 - z0),
			CF(centreX, 10.75 - depth, (z0 + z1) / 2)
				* ANG(rad(rng:NextNumber(-0.2, 0.2)), 0, rad(rng:NextNumber(-1, 1))),
			tint(SHEET, rng, 4)
		)
		panel.CastShadow = false
	end
	return model, swayable
end

-- What is left of the bedroom the lab used to be (so the room reads "a converted bedroom",
-- not a storeroom): the old wallpaper and a poster ghost where the sheeting tore off the S wall,
-- a dusty lampshade above the ceiling sheets (a silhouette through the plastic). The carpet
-- band is in LabBuilder (floors). `toWorld`: the flat's local frame → world.
function AptProps.bedroomLeftovers(
	parent: Instance,
	toWorld: (CFrame) -> CFrame,
	rng: Random
): Model
	local model = Instance.new("Model")
	model.Name = "BedroomLeftovers"
	model.Parent = parent
	-- (frames ON the S wall's face, z 0.25, looking into the room)
	local function onWall(x: number, y: number): CFrame
		return toWorld(CF(x, y, 0.25) * ANG(0, math.pi, 0))
	end
	-- the old wallpaper (3 strips, two tones) above the torn sheets
	local paper = { look(M.Fabric, 150, 132, 108), look(M.Fabric, 138, 120, 98) }
	-- (they stop short of the window frame)
	for i = 0, 2 do
		overlay(
			model,
			"OldWallpaper",
			Vector2.new(1.75, 4.6),
			onWall(11.25 + i * 1.75, 8.3),
			LAYER.PAINT,
			tint(paper[i % 2 + 1], rng, 4)
		)
	end
	-- a paler rectangle where a poster hung for years, and the 4 bits of tape it left
	overlay(
		model,
		"PosterGhost",
		Vector2.new(1.8, 2.6),
		onWall(13.1, 8.2),
		LAYER.STAIN,
		look(M.Fabric, 160, 146, 122)
	)
	for _, corner in { V(-0.8, 1.2, 0), V(0.8, 1.2, 0), V(-0.8, -1.2, 0), V(0.8, -1.2, 0) } do
		overlay(
			model,
			"PosterTape",
			Vector2.new(0.28, 0.12),
			onWall(13.1 + corner.X, 8.2 + corner.Y) * ANG(0, 0, jitterAngle(rng, 10, 35)),
			LAYER.STAIN + LAYER.STEP,
			look(M.Fabric, 176, 168, 136)
		)
	end
	-- a dusty fabric drum shade above the ceiling sheeting (unlit)
	part(
		model,
		"OldLampshade",
		V(0.36, 1.6, 1.6),
		toWorld(CF(13, 10.8, 18) * UP),
		look(M.Fabric, 150, 132, 104),
		CYL
	)
	return model
end

-- The strip curtain at the lab entrance (an Anim model: its strips are its children; V parts
-- them when the player walks through). `at`: the rail's centre at the floor (local X = along the
-- rail), strips hang from y 8 down to 0.2. SmoothPlastic, not Glass (Glass would hide the vat's
-- see-through fluid behind it).
function AptProps.stripCurtain(parent: Instance, at: CFrame, rng: Random, strips: number): Model
	local model = Instance.new("Model")
	model.Name = "Curtain"
	local width = 0.62
	local span = strips * width - (strips - 1) * 0.05
	part(model, "Rail", V(span + 0.4, 0.15, 0.2), at * CF(0, 8.1, 0), look(M.Metal, 150, 150, 146))
	for i = 1, strips do
		local x = -span / 2 + width / 2 + (i - 1) * (width - 0.05)
		-- (every other strip 0.05 behind: neighbours overlap a little, never touching)
		local strip = part(
			model,
			"Strip",
			V(width, 7.8, 0.03),
			at * CF(x, 4.1, (i % 2) * 0.05) * ANG(rad(rng:NextNumber(-0.8, 0.8)), 0, 0),
			look(M.SmoothPlastic, 205, 215, 212, 0.55, 0.1)
		)
		strip.CastShadow = false
	end
	-- two wire hangers up to the ceiling
	for _, x in { -span / 2 + 0.3, span / 2 - 0.3 } do
		part(model, "Hanger", V(0.04, 2.9, 0.04), at * CF(x, 9.6, 0), look(M.Metal, 120, 120, 116))
	end
	model.WorldPivot = at * CF(0, 8, 0)
	model.Parent = parent
	return model
end

-- The pump shelf: a wire shelf, three aquarium air pumps (different sizes and colours) on the
-- middle shelf, two circulation pumps with hose barbs on the bottom shelf (the vat's loop), the
-- buffer tank (a small aquarium with teal water and gravel) on top. `at`: the shelf's centre on
-- the floor, local -Z = out of the wall. 3.6 wide, 2 deep.
function AptProps.pumpShelf(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "PumpShelf", at)
	local wire = look(M.Metal, 170, 172, 174)
	for _, x in { -1.75, 1.75 } do
		for _, z in { -0.95, 0.95 } do
			add("Upright", V(0.1, 7.2, 0.1), CF(x, 3.6, z), wire)
		end
	end
	-- (the shelves stop at the uprights' centres: no shared outer face)
	for _, y in { 1.0, 3.2, 5.4 } do
		add("WireShelf", V(3.5, 0.08, 1.9), CF(0, y, 0), wire)
	end
	-- three air pumps on the middle shelf
	local pumps = {
		{ size = V(0.9, 0.5, 0.6), color = look(M.Plastic, 40, 44, 48), x = -1.1 },
		{ size = V(0.7, 0.4, 0.5), color = look(M.Plastic, 200, 196, 186), x = 0.1 },
		{ size = V(1.1, 0.6, 0.7), color = look(M.Plastic, 70, 90, 100), x = 1.15 },
	}
	for i, pump in pumps do
		local body = add(
			"Pump",
			pump.size,
			CF(pump.x, 3.3 + pump.size.Y / 2, 0.1) * ANG(0, jitterAngle(rng, 2, 10), 0),
			pump.color
		)
		add(
			"PumpFoot",
			V(pump.size.X * 0.9, 0.06, pump.size.Z * 0.9),
			CF(pump.x, 3.27, 0.1),
			look(M.Rubber, 30, 30, 30)
		)
		-- each pump's thin air line up into the tank (clear tubing)
		path(model, "AirLine", {
			(body.CFrame * CF(0, pump.size.Y / 2, -pump.size.Z / 2)).Position,
			(at * CF(pump.x * 0.6, 4.8, -0.7)).Position,
			(at * CF(-0.6 + i * 0.4, 6.6, -0.2)).Position,
		}, 0.06, look(M.Glass, 210, 225, 220, 0.4))
	end
	-- (the story: pump 2 sits on a folded rag to stop it rattling)
	add("Rag", V(0.8, 0.06, 0.6), CF(0.1, 3.27, 0.1), look(M.Fabric, 150, 140, 110))
	-- the two circulation pumps of the vat's loop, on the bottom shelf, barbs to the front
	for _, x in { -0.9, 0.6 } do
		add("CircPump", V(0.8, 0.5, 0.6), CF(x, 1.29, 0.0), look(M.Plastic, 50, 54, 58))
		add(
			"Barb",
			V(0.3, 0.12, 0.12),
			CF(x, 1.35, -0.4) * ALONG_Z,
			look(M.Plastic, 220, 220, 214),
			CYL
		)
	end
	-- the buffer tank on the top shelf (its glass is SmoothPlastic: Glass would hide the water)
	add("TankBase", V(2.5, 0.12, 1.3), CF(0, 5.5, 0), look(M.Plastic, 30, 30, 30))
	add(
		"TankGlass",
		V(2.4, 1.5, 1.2),
		CF(0, 6.31, 0),
		look(M.SmoothPlastic, 190, 220, 216, 0.72, 0.1)
	)
	add("Gravel", V(2.3, 0.2, 1.1), CF(0, 5.66, 0), look(M.Pebble, 120, 116, 104))
	add("TankWater", V(2.26, 1.02, 1.06), CF(0, 6.27, 0), look(M.SmoothPlastic, 90, 170, 160, 0.45))
	add(
		"TankLid",
		V(2.46, 0.08, 1.26),
		CF(0, 7.1, 0.05) * ANG(rad(-2), 0, 0),
		look(M.Plastic, 40, 40, 40)
	)
	add("AirStone", V(0.4, 0.12, 0.12), CF(0, 5.82, 0), look(M.Concrete, 120, 110, 100), CYL)
	return model
end

-- The stash: a salvaged sliding-lid shop freezer (yellowed, rust at the base, an open padlock,
-- a digital thermometer taped on, frost under the lids). The lids are clear plastic (not
-- Material Glass: Glass would hide the see-through capsules inside); a cold light inside
-- (a LabBuilder fixture) shows the capsules on their shelf. `at`: its centre on the floor,
-- local -Z = its front (where the player stands). 2.2 deep (local Z), 4.6 long (local X), 3 high.
-- The panels butt (walls between the ends, the base under all four): no shared face.
function AptProps.stashFreezer(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "StashFreezer", at)
	local shell = solid(tint(look(M.SmoothPlastic, 176, 180, 172), rng))
	add("Bottom", V(4.6, 0.6, 2.2), CF(0, 0.3, 0), shell)
	for _, z in { -1.05, 1.05 } do
		add("Wall", V(4.4, 2.4, 0.1), CF(0, 1.8, z), shell)
	end
	for _, x in { -2.25, 2.25 } do
		add("End", V(0.1, 2.4, 2.2), CF(x, 1.8, 0), shell)
	end
	add("Liner", V(4.4, 0.04, 2.0), CF(0, 2.15, 0), look(M.SmoothPlastic, 190, 200, 204))
	-- rust creeping up the front and the ends from the floor
	overlay(model, "Rust", Vector2.new(4.6, 0.4), at * CF(0, 0.2, -1.1), LAYER.STEP, RUST)
	for _, x in { -2.3, 2.3 } do
		overlay(
			model,
			"Rust",
			Vector2.new(2.2, 0.4),
			at * CF(x, 0.2, 0) * ANG(0, if x < 0 then rad(90) else rad(-90), 0),
			LAYER.STEP,
			RUST
		)
	end
	-- an old brand sticker, half scraped off (two torn pieces, the second over the first)
	local front = at * CF(0, 0, -1.1)
	overlay(
		model,
		"Sticker",
		Vector2.new(1.1, 0.7),
		front * CF(1.2, 1.5, 0),
		LAYER.STEP,
		look(M.SmoothPlastic, 120, 150, 160)
	)
	overlay(
		model,
		"Sticker",
		Vector2.new(0.5, 0.35),
		front * CF(1.75, 1.25, 0) * ANG(0, 0, rad(-14)),
		2 * LAYER.STEP,
		look(M.SmoothPlastic, 132, 150, 150)
	)
	-- the rim round the opening (four rails), the two sliding lids (one slid a little open,
	-- each on its own runner height), the frost under the rim
	local frame = look(M.Plastic, 160, 156, 146)
	-- (the rim sits ON the walls' tops, 3.0..3.1; the lids slide on top of it)
	for _, z in { -1.025, 1.025 } do
		add("LidFrame", V(4.6, 0.1, 0.15), CF(0, 3.05, z), frame)
	end
	for _, x in { -2.225, 2.225 } do
		add("LidFrame", V(0.15, 0.1, 1.9), CF(x, 3.05, 0), frame)
	end
	local lid = look(M.SmoothPlastic, 200, 222, 226, 0.45, 0.2)
	add("Lid", V(2.3, 0.04, 2.0), CF(-1.1, 3.12, 0), lid)
	add("Lid", V(2.3, 0.04, 2.0), CF(0.95, 3.18, 0), lid)
	add("Frost", V(4.3, 0.05, 0.12), CF(0, 2.92, -0.89), look(M.Ice, 220, 235, 240, 0.2))
	add("Frost", V(4.3, 0.05, 0.12), CF(0, 2.92, 0.89), look(M.Ice, 220, 235, 240, 0.3))
	-- the open padlock hanging off its hasp
	add("Hasp", V(0.5, 0.15, 0.08), CF(-0.9, 2.8, -1.14), look(M.Metal, 120, 118, 110))
	add(
		"Padlock",
		V(0.3, 0.38, 0.14),
		CF(-0.8, 2.45, -1.17) * ANG(0, 0, rad(20)),
		look(M.Metal, 140, 136, 122)
	)
	-- the cheap thermometer taped on the front: -18.4
	add("Thermometer", V(0.8, 0.45, 0.05), CF(-1.75, 2.2, -1.125), look(M.Plastic, 220, 220, 214))
	local display = add(
		"ThermoDisplay",
		V(0.6, 0.25, 0.03),
		CF(-1.75, 2.22, -1.165),
		look(M.SmoothPlastic, 30, 40, 38)
	)
	writeOn(
		display,
		Enum.NormalId.Front,
		"-18.4",
		Color3.fromRGB(120, 200, 190),
		Enum.Font.Code,
		120
	)
	add("Tape", V(0.95, 0.12, 0.06), CF(-1.75, 2.5, -1.13), TAPE)
	-- condensation drips running down the front
	for i = 1, 2 do
		overlay(
			model,
			"Streak",
			Vector2.new(0.06, rng:NextNumber(0.5, 1.0)),
			front * CF(0.2 + i * 0.4, 2.3, 0),
			LAYER.STEP,
			look(M.SmoothPlastic, 186, 184, 170)
		)
	end
	return model
end

-- The lab's old fridge (sealed media and seed tubes: a different model from the kitchen one,
-- rounded top, chrome handle), locked with a bicycle cable lock, one blank taped note.
-- Front = local -Z.
function AptProps.labFridge(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "LabFridge", at)
	local shell = solid(tint(look(M.SmoothPlastic, 196, 182, 148), rng)) -- (old almond enamel)
	add("Body", V(2.2, 5.0, 1.9), CF(0, 2.5, 0), shell)
	-- (a 1950s-style rounded top: a cylinder lying along X, its ends 0.02 inside the body's
	-- sides so they never share the sides' plane)
	add("RoundTop", V(2.14, 1.9, 1.9), CF(0, 5.0, 0), shell, CYL)
	local face = at * CF(0, 0, -0.95)
	overlay(
		model,
		"DoorLine",
		Vector2.new(2.0, 0.03),
		face * CF(0, 4.0, 0),
		LAYER.STEP,
		look(M.SmoothPlastic, 120, 118, 106)
	)
	overlay(model, "Rust", Vector2.new(2.2, 0.3), face * CF(0, 0.15, 0), LAYER.STEP, RUST)
	add("Handle", V(0.15, 1.0, 0.18), CF(0.85, 3.2, -1.05), look(M.Metal, 200, 202, 206))
	-- the cable lock: a loop round the body, its lock body
	local cable = look(M.Rubber, 30, 32, 30)
	add("Cable", V(2.35, 0.1, 0.1), CF(0, 3.5, -1.02), cable)
	add("Cable", V(0.1, 0.1, 2.0), CF(1.15, 3.5, 0), cable)
	add("Cable", V(0.1, 0.1, 2.0), CF(-1.15, 3.5, 0), cable)
	add("LockBody", V(0.3, 0.45, 0.2), CF(0.3, 3.3, -1.1), look(M.Metal, 60, 60, 60))
	-- one blank note taped on (an overlay), clear of the cable
	overlay(
		model,
		"Note",
		Vector2.new(0.8, 0.6),
		face * CF(-0.45, 4.55, 0) * ANG(0, 0, jitterAngle(rng, 2, 6)),
		LAYER.STEP,
		tint(PAPER, rng, 6)
	)
	return model
end

-- The extraction table: a salvaged hospital trolley (steel top with a lip, a lower shelf with gauze rolls, a spray bottle, tape; legs, castors). `at`:
-- the TOP's centre at floor level (the top's surface is at y 3.35). Its top must stay clear
-- (Extraction uses it). The lips butt at the corners; the shelf stops inside the legs.
function AptProps.trolleyBench(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "TrolleyBench", at)
	-- (dull, scratched steel: years of use, never a shiny clinic top)
	local worn = look(M.Metal, 122, 124, 120, 0, 0.05)
	add("Top", V(7, 0.3, 3), CF(0, 3.2, 0), solid(worn))
	-- (the lip stays outside the top's 7 x 3 so the shell lies flat)
	for _, z in { -1.55, 1.55 } do
		add("Lip", V(7.0, 0.1, 0.1), CF(0, 3.35, z), worn)
	end
	for _, x in { -3.55, 3.55 } do
		add("Lip", V(0.1, 0.1, 3.2), CF(x, 3.35, 0), worn)
	end
	-- a strip of grey duct tape mending the near lip
	add("LipTape", V(0.9, 0.16, 0.16), CF(-1.6, 3.35, -1.55), TAPE)
	-- (the underpad under the shell, the trays and the pass-box are BenchLayout's static kit)
	local frame = look(M.Metal, 130, 134, 138)
	for _, x in { -3.3, 3.3 } do
		for _, z in { -1.3, 1.3 } do
			add("Leg", V(0.22, 2.8, 0.22), CF(x, 1.75, z), frame)
			add(
				"Castor",
				V(0.3, 0.32, 0.32),
				CF(x, 0.16, z) * ANG(0, rng:NextNumber(0, math.pi), 0),
				look(M.Rubber, 30, 30, 30),
				CYL
			)
		end
	end
	add("Shelf", V(6.6, 0.1, 2.6), CF(0, 1.2, 0), frame)
	-- one leg mended with tape (the story)
	add("LegTape", V(0.3, 0.5, 0.3), CF(3.3, 2.3, -1.3), TAPE)
	-- the lower shelf
	local gauze = look(M.Fabric, 230, 230, 222)
	for i = 1, 3 do
		add(
			"Gauze",
			V(0.5, 0.45, 0.45),
			CF(-2.6 + i * 0.5, 1.48, 0.4) * ALONG_Z * ANG(jitterAngle(rng, 2, 10), 0, 0),
			gauze,
			CYL
		)
	end
	add("SprayBottle", V(0.4, 0.9, 0.35), CF(0.6, 1.7, -0.2), look(M.Plastic, 220, 222, 226))
	add("SprayHead", V(0.3, 0.25, 0.4), CF(0.6, 2.275, -0.25), look(M.Plastic, 60, 150, 150))
	add("TapeRoll", V(0.2, 0.5, 0.5), CF(1.6, 1.36, 0.3) * UP, TAPE, CYL)
	add(
		"Towel",
		V(1.4, 0.25, 1.0),
		CF(2.6, 1.375, 0) * ANG(0, rad(8), 0),
		look(M.Fabric, 150, 170, 170)
	)
	return model
end

-- The work surface: an old interior door laid on two trestles; on it the CRT station (its glass
-- "MonitorScreen" is moved to the model's root), a keyboard with missing keys, a webcam on
-- books, the home-made warm box (the seed-culture incubator), a mug of pens, two taped notes
-- on the sheeting above. `at`: the door-top's centre at floor level, local -Z = out of the wall
-- (the door is 7.5 long along local X, 2.8 deep; its back edge is against the sheeted wall).
function AptProps.trestleTable(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "TrestleTable", at)
	local doorLook = tint(look(M.Wood, 120, 104, 84), rng)
	add("DoorTop", V(7.5, 0.18, 2.8), CF(0, 3.0, 0), solid(doorLook))
	add("KnobHole", V(0.03, 0.35, 0.35), CF(3.4, 3.105, -0.9) * UP, look(M.Wood, 30, 26, 20), CYL)
	local trestle = look(M.Wood, 150, 120, 84)
	for _, x in { -2.8, 2.8 } do
		add("TrestleBar", V(0.25, 0.25, 2.6), CF(x, 2.785, 0), trestle)
		for _, z in { -1.0, 1.0 } do
			add(
				"TrestleLeg",
				V(0.2, 2.9, 0.2),
				CF(x, 1.4, z * 0.85) * ANG(rad(z * -10), 0, 0),
				trestle
			)
		end
	end
	-- the CRT station (screen faces local -Z; its back clear of the wall's sheets)
	add("Books", V(2.0, 0.3, 1.0), CF(0.4, 3.24, 0.85), look(M.Cardboard, 120, 60, 50))
	add(
		"Books",
		V(1.8, 0.25, 0.9),
		CF(0.45, 3.515, 0.87) * ANG(0, rad(4), 0),
		look(M.Cardboard, 60, 80, 70)
	)
	add("Monitor", V(2.4, 2.1, 0.95), CF(0.4, 4.69, 0.9), look(M.Plastic, 180, 174, 160))
	add("MonitorScreen", V(1.8, 1.4, 0.05), CF(0.4, 4.64, 0.4), look(M.Glass, 8, 18, 14, 0, 0.1))
	-- keyboard with a missing key
	local keyboard = add(
		"Keyboard",
		V(1.9, 0.1, 0.7),
		CF(0.4, 3.14, -0.8) * ANG(0, rad(-4), 0),
		look(M.Plastic, 196, 190, 176)
	)
	part(
		model,
		"MissingKey",
		V(0.14, 0.03, 0.14),
		keyboard.CFrame * CF(-0.39, 0.065, 0.1),
		look(M.Plastic, 40, 40, 40)
	)
	-- a webcam on a stack of books
	add("BookStack", V(0.9, 0.6, 0.7), CF(-1.2, 3.39, 0.5), look(M.Cardboard, 90, 70, 110))
	add("Webcam", V(0.35, 0.3, 0.3), CF(-1.2, 3.85, 0.5), look(M.Plastic, 40, 40, 44), BALL)
	add(
		"WebcamLens",
		V(0.03, 0.12, 0.12),
		CF(-1.2, 3.85, 0.335) * ALONG_Z,
		look(M.Glass, 20, 30, 40),
		CYL
	)
	-- the warm box: a cooler box with a round hole, a clamp-lamp shade over it (no light), a
	-- taped thermostat reading 37.0
	add("WarmBox", V(2.0, 1.2, 1.2), CF(-2.6, 3.69, 0.1), look(M.Plastic, 70, 120, 140))
	add("WarmLid", V(2.08, 0.15, 1.28), CF(-2.6, 4.365, 0.1), look(M.Plastic, 196, 190, 170))
	add("LidHole", V(0.03, 0.6, 0.6), CF(-2.6, 4.455, 0.1) * UP, look(M.Plastic, 20, 20, 20), CYL)
	add("ClampShade", V(0.6, 0.7, 0.7), CF(-2.6, 5.2, 0.1) * UP, look(M.Metal, 160, 150, 130), CYL)
	add(
		"ClampArm",
		V(0.08, 1.0, 0.08),
		CF(-2.2, 4.8, 0.1) * ANG(0, 0, rad(30)),
		look(M.Metal, 60, 60, 60)
	)
	add("Thermostat", V(0.5, 0.35, 0.05), CF(-2.6, 3.75, -0.525), look(M.Plastic, 220, 220, 214))
	local reading = add(
		"ThermostatDisplay",
		V(0.4, 0.2, 0.03),
		CF(-2.6, 3.77, -0.565),
		look(M.SmoothPlastic, 30, 30, 28)
	)
	writeOn(reading, Enum.NormalId.Front, "37.0", Color3.fromRGB(255, 170, 70), Enum.Font.Code, 120)
	-- a mug of pens
	add(
		"PenMug",
		V(0.45, 0.35, 0.35),
		CF(2.2, 3.315, -0.3) * UP,
		look(M.SmoothPlastic, 90, 110, 120),
		CYL
	)
	for i = 1, 2 do
		add(
			"Pen",
			V(0.05, 0.6, 0.05),
			CF(2.2 + (i - 1.5) * 0.1, 3.7, -0.3) * ANG(rad((i - 1.5) * 14), 0, rad((i - 1.5) * 10)),
			look(M.Plastic, 30, 30, 40)
		)
	end
	-- two taped notes on the sheeting above, side by side (0.4 apart), clear of the CRT
	for i, text in { "pump 2 rattles", "change filters FRI" } do
		local note = overlay(
			model,
			"Note",
			Vector2.new(0.9, 0.7),
			at
				* CF(-2.6 + (i - 1) * 1.3, 6.4 + (i - 1) * 0.12, 1.36)
				* ANG(0, 0, jitterAngle(rng, 2, 5)),
			LAYER.STEP,
			tint(PAPER, rng, 6)
		)
		writeOn(note, Enum.NormalId.Front, text, INK)
	end
	return model
end

-- The dispatch rack for the cases (chrome wire shelving): the "BX-7" stencil on the middle
-- shelf's front lip (moved to the root by LabBuilder), two spare empty case shells on the middle
-- shelf, the ice-pack coolers on the bottom shelf (ice packs go into the cases), folded
-- underpads and a glove box on top. `at`: its centre on the floor, local -Z = out of the wall
-- (5.6 long along local X, 1.8 deep).
function AptProps.wireShelf(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "WireShelf", at)
	local chrome = look(M.Metal, 170, 172, 174)
	for _, x in { -2.75, 2.75 } do
		for _, z in { -0.85, 0.85 } do
			add("Upright", V(0.12, 6.4, 0.12), CF(x, 3.2, z), chrome)
		end
	end
	for _, y in { 0.4, 2.6, 4.8 } do
		-- (between the uprights' centres: no face shared with them)
		add("WireShelf", V(5.5, 0.08, 1.7), CF(0, y, 0), chrome)
		for i = 1, 3 do
			add("Rod", V(0.04, 0.04, 1.7), CF(-2.8 + i * 1.4, y + 0.06, 0), chrome)
		end
	end
	-- the stencil plate hangs from the middle shelf's front edge
	local stencil = add(
		"RackStencil",
		V(1.6, 0.48, 0.05),
		CF(0, 2.3, -0.88),
		look(M.SmoothPlastic, 120, 124, 120)
	)
	writeOn(
		stencil,
		Enum.NormalId.Front,
		"BX-7",
		Color3.fromRGB(230, 120, 40),
		Enum.Font.GothamBold,
		80
	)
	-- two spare, empty case shells on the middle shelf (dark plastic boxes with latches)
	for i, x in { -1.4, 1.2 } do
		local shell = add(
			"SpareCase",
			V(2.0, 0.9, 1.2),
			CF(x, 3.09, 0.05) * ANG(0, jitterAngle(rng, 2, 6), 0),
			look(M.Plastic, 44 + i * 6, 48, 50)
		)
		for _, lx in { -0.5, 0.5 } do
			part(
				model,
				"Latch",
				V(0.2, 0.25, 0.05),
				shell.CFrame * CF(lx, 0.1, -0.625),
				look(M.Metal, 150, 150, 146)
			)
		end
	end
	-- the ice-pack coolers on the bottom shelf
	for i, x in { -1.35, 1.35 } do
		local body = if i == 1
			then look(M.Plastic, 70, 120, 140)
			else look(M.Plastic, 196, 190, 170)
		add("Cooler", V(2.3, 1.3, 1.4), CF(x, 1.09, 0.05), solid(body))
		add(
			"CoolerLid",
			V(2.36, 0.15, 1.46),
			CF(x, 1.815, 0.05) * ANG(0, rad(i * 1.5), 0),
			look(M.Plastic, 220, 222, 216)
		)
	end
	-- on top: a stack of folded blue underpads (each 0.06 thick, stacked) and a glove box
	for i = 1, 4 do
		add(
			"Underpads",
			V(1.4, 0.06, 1.0),
			CF(-1.2, 4.87 + i * 0.06, 0) * ANG(0, rad(i * 3 - 6), 0),
			look(M.Fabric, 96, 124, 146)
		)
	end
	add("GloveBox", V(1.0, 0.5, 0.55), CF(1.1, 5.09, 0), look(M.Cardboard, 90, 120, 160))
	return model
end

-- A HEPA air-purifier tower (the clean end of the lab: it blows filtered air over the vat).
-- Grey plastic, an intake grille on the front, an outlet on top, a small blue LED. Front = -Z.
function AptProps.hepaTower(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "HepaTower", at)
	add("Body", V(1.2, 3.2, 1.0), CF(0, 1.65, 0), solid(look(M.Plastic, 150, 154, 156)))
	add("Foot", V(1.3, 0.05, 1.1), CF(0, 0.025, 0), look(M.Plastic, 50, 52, 54))
	local face = at * CF(0, 0, -0.5)
	overlay(
		model,
		"Intake",
		Vector2.new(0.9, 2.2),
		face * CF(0, 1.5, 0),
		LAYER.STEP,
		look(M.Plastic, 70, 74, 78)
	)
	for i = 1, 6 do
		add(
			"Slat",
			V(0.9, 0.05, 0.04),
			CF(0, 0.6 + i * 0.32, -0.55),
			look(M.Plastic, 130, 134, 138)
		)
	end
	add("Outlet", V(0.9, 0.04, 0.7), CF(0, 3.27, 0), look(M.Plastic, 70, 74, 78))
	add("Led", V(0.08, 0.08, 0.03), CF(0.4, 3.0, -0.515), look(M.Neon, 90, 150, 255))
	return model
end

-- The UPS (a black battery box with a green LED): it keeps the pumps and the vat alive through
-- a power cut. The "DO NOT UNPLUG" note is taped on its front. Front = -Z.
function AptProps.ups(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "Ups", at)
	add("Body", V(1.0, 0.9, 1.0), CF(0, 0.45, 0), solid(look(M.Plastic, 34, 36, 38)))
	add("Led", V(0.06, 0.06, 0.03), CF(0.35, 0.75, -0.515), look(M.Neon, 110, 230, 120))
	add("Button", V(0.12, 0.12, 0.03), CF(0.2, 0.75, -0.515), look(M.Plastic, 70, 72, 74))
	local note = overlay(
		model,
		"Note",
		Vector2.new(0.7, 0.35),
		at * CF(-0.1, 0.42, -0.5) * ANG(0, 0, jitterAngle(rng, 2, 5)),
		LAYER.STEP,
		look(M.SmoothPlastic, 226, 210, 120)
	)
	writeOn(note, Enum.NormalId.Front, "DO NOT UNPLUG", INK, Enum.Font.SourceSansBold)
	return model
end

-- The feed carboy: a 20-litre translucent jerrycan, two-thirds full of milky culture medium
-- (the pumps draw from it, the garden hose refills it through the filter). Front = -Z.
function AptProps.feedCarboy(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "FeedCarboy", at)
	add("Medium", V(1.26, 1.2, 1.06), CF(0, 0.62, 0), look(M.SmoothPlastic, 214, 224, 216, 0.15))
	add(
		"Can",
		V(1.4, 1.9, 1.2),
		CF(0, 0.95, 0),
		solid(look(M.SmoothPlastic, 226, 232, 228, 0.55, 0.05))
	)
	add(
		"Neck",
		V(0.25, 0.4, 0.4),
		CF(0.25, 2.02, 0.2) * UP,
		look(M.SmoothPlastic, 226, 232, 228, 0.4),
		CYL
	)
	add("Cap", V(0.12, 0.44, 0.44), CF(0.25, 2.2, 0.2) * UP, look(M.Plastic, 70, 120, 128), CYL)
	add("Handle", V(0.8, 0.12, 0.2), CF(-0.3, 2.0, 0.2), look(M.SmoothPlastic, 226, 232, 228, 0.3))
	return model
end

-- The gowning corner by the lab door: a hook board with a lab coat and a plastic apron, a
-- small shelf with glove and mask boxes, a hand-gel pump. You gear up before touching the
-- culture. On a wall; `at` on the floor against it, local -Z = out of the wall.
function AptProps.gowning(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "Gowning", at)
	add("HookBoard", V(2.4, 0.3, 0.1), CF(0, 6.0, -0.05), look(M.Wood, 120, 96, 70))
	local metal = look(M.Metal, 140, 140, 136)
	for _, x in { -0.8, 0, 0.8 } do
		add("Hook", V(0.06, 0.06, 0.3), CF(x, 5.95, -0.25), metal)
	end
	-- the coat (grey-white, a sleeve hanging), the clear apron
	local coat = tint(look(M.Fabric, 206, 208, 204), rng, 4)
	add("LabCoat", V(1.0, 3.2, 0.3), CF(-0.8, 4.3, -0.32) * ANG(rad(3), 0, rad(-3)), coat)
	add("Sleeve", V(0.28, 1.9, 0.24), CF(-0.32, 4.2, -0.36) * ANG(0, 0, rad(-6)), coat)
	add(
		"Apron",
		V(1.1, 3.4, 0.04),
		CF(0.8, 4.2, -0.3) * ANG(rad(2), 0, rad(2)),
		look(M.SmoothPlastic, 214, 224, 226, 0.4, 0.08)
	)
	-- the shelf below, with two glove boxes, a mask box and the gel pump
	add("Shelf", V(2.4, 0.08, 0.7), CF(0, 2.4, -0.35), look(M.Wood, 150, 130, 100))
	for _, x in { -1.1, 1.1 } do
		add("Bracket", V(0.06, 0.4, 0.6), CF(x, 2.16, -0.32), metal)
	end
	add("GloveBox", V(0.8, 0.35, 0.45), CF(-0.7, 2.615, -0.35), look(M.Cardboard, 90, 120, 160))
	add(
		"GloveBox",
		V(0.8, 0.35, 0.45),
		CF(-0.7, 2.97, -0.35) * ANG(0, rad(4), 0),
		look(M.Cardboard, 90, 120, 160)
	)
	add("MaskBox", V(0.6, 0.4, 0.4), CF(0.3, 2.64, -0.35), look(M.Cardboard, 200, 200, 196))
	add(
		"GelBottle",
		V(0.6, 0.3, 0.3),
		CF(0.95, 2.74, -0.35) * UP,
		look(M.SmoothPlastic, 220, 230, 232, 0.3),
		CYL
	)
	add("GelPump", V(0.12, 0.2, 0.12), CF(0.95, 3.12, -0.35), look(M.Plastic, 230, 230, 226))
	return model
end

-- The power distribution board: plywood screwed to the wall, an RCD box, two power strips and a
-- plug-in timer. The cord bundle from the fuse box lands here; every lab cord starts here or
-- at the strips it feeds. On a wall; `at` = the board's centre ON the wall, local -Z = out.
-- Returns the model and the world points where its cords leave (up, down).
function AptProps.powerBoard(parent: Instance, at: CFrame, _rng: Random): (Model, Vector3, Vector3)
	local model, add = begin(parent, "PowerBoard", at)
	add("Board", V(2.0, 2.6, 0.15), CF(0, 0, -0.075), look(M.WoodPlanks, 156, 128, 92))
	add("Rcd", V(0.6, 0.8, 0.3), CF(-0.55, 0.75, -0.3), look(M.Plastic, 214, 212, 204))
	add("RcdSwitch", V(0.2, 0.12, 0.06), CF(-0.55, 0.85, -0.48), look(M.Plastic, 40, 110, 200))
	for _, y in { 0.05, -0.75 } do
		add("Strip", V(1.6, 0.3, 0.22), CF(0.1, y, -0.26), look(M.Plastic, 220, 216, 204))
		for i = 1, 3 do
			add(
				"Plug",
				V(0.22, 0.26, 0.26),
				CF(-0.35 + i * 0.32, y, -0.5),
				look(M.Plastic, 40, 40, 40)
			)
		end
	end
	add("Timer", V(0.4, 0.4, 0.3), CF(0.55, 0.75, -0.3), look(M.Plastic, 230, 230, 226))
	add(
		"TimerDial",
		V(0.04, 0.3, 0.3),
		CF(0.55, 0.75, -0.47) * ALONG_Z,
		look(M.Plastic, 70, 160, 90),
		CYL
	)
	return model, (at * CF(-0.2, 1.3, -0.3)).Position, (at * CF(0.6, -1.3, -0.35)).Position
end

-- The biomass bin at the table's W end: a grey two-wheeled bin, its lid swung up against the
-- wall ("ChuteFlap", moved to the root by LabBuilder), and the loose steel ramp the spent
-- shell slides down, stored leaning on the bin's front between uses (stood up on the
-- trolley's end it read as a random board stuck on the bench). `at`: the bin's centre on the
-- floor, local -Z = toward the table (the bin's open side faces it), its back on the wall.
-- (`_rampHinge`: where the ramp hooks on the table's end when in use; kept for the scene.)
function AptProps.biomassBin(parent: Instance, at: CFrame, rng: Random, _rampHinge: CFrame): Model
	local model, add = begin(parent, "BiomassBin", at)
	local grey = tint(look(M.Plastic, 78, 84, 86), rng, 4)
	add("Body", V(2.2, 3.0, 2.0), CF(0, 1.62, 0), solid(grey))
	add("Rim", V(2.3, 0.12, 2.1), CF(0, 3.18, 0), grey)
	add("Inside", V(2.0, 0.03, 1.8), CF(0, 3.255, 0), look(M.Plastic, 30, 32, 32))
	for _, x in { -0.85, 0.85 } do
		add(
			"Wheel",
			V(0.25, 0.5, 0.5),
			CF(x, 0.25, 0.85) * ANG(0, rad(90), 0),
			look(M.Rubber, 30, 30, 30),
			CYL
		)
	end
	-- the lid: hinged at the back edge, swung up past vertical so it rests on the wall
	add(
		"ChuteFlap",
		V(2.3, 0.1, 2.1),
		CF(0, 3.24, 1.05) * ANG(rad(92), 0, 0) * CF(0, 0, -1.05),
		grey
	)
	-- the ramp: a steel plate standing up on its hinge at the table's end, two side rails
	local steel = look(M.Metal, 140, 142, 140, 0, 0.06)
	-- (attribute SceneHidden: the extractor's client may hide them while it swings its own copy
	-- down for the shell's slide, like BenchLayout's moving parts)
	-- (tilted 12° back onto the bin: its foot just above the floor plastic, its top edge on
	-- the bin's front face)
	local lean = at * CF(0, 0.87, -1.2) * ANG(rad(12), 0, 0)
	local ramp = part(model, "ChuteRamp", V(1.2, 1.6, 0.06), lean, steel)
	ramp:SetAttribute("SceneHidden", true)
	for _, x in { -0.62, 0.62 } do
		local rail = part(model, "RampRail", V(0.04, 1.6, 0.12), lean * CF(x, 0, -0.06), steel)
		rail:SetAttribute("SceneHidden", true)
	end
	return model
end

-- The range hood hung over the table on four chains (it pulls the fumes and the cold mist off
-- the work), its duct neck on top, and the work lamp clamped to its edge ("LampHead", moved to
-- the root by LabBuilder, its SpotLight added there). `at`: the hood's centre at its BOTTOM
-- face; `lampAt`: the lamp head's centre (world). Returns the model and the duct's start point.
function AptProps.hoodLamp(
	parent: Instance,
	at: CFrame,
	lampAt: Vector3,
	_rng: Random
): (Model, Vector3)
	local model, add = begin(parent, "HoodLamp", at)
	local steel = look(M.Metal, 150, 150, 146, 0, 0.06)
	add("Hood", V(3.2, 0.5, 2.2), CF(0, 0.25, 0), steel)
	add("HoodNeck", V(1.0, 0.3, 1.0), CF(0, 0.65, 0), steel)
	add("Filter", V(2.9, 0.03, 1.9), CF(0, -0.015, 0), look(M.Metal, 90, 92, 92))
	for _, x in { -1.5, 1.5 } do
		for _, z in { -1.0, 1.0 } do
			add("Chain", V(0.05, 1.1, 0.05), CF(x, 1.05, z), look(M.Metal, 110, 110, 106))
		end
	end
	-- the work lamp: a short arm down from the hood's edge, a dented conical metal shade (the
	-- wide mouth is LampHead), a narrow neck, a corroded rim, the lens
	local dark = look(M.Metal, 60, 62, 64)
	local top = (at * CF(0, 0, 0)).Position
	rod(model, "Arm", Vector3.new(lampAt.X, top.Y, lampAt.Z), lampAt + V(0, 0.6, 0), 0.12, dark)
	part(model, "LampHead", V(0.45, 1.0, 1.0), CF(lampAt) * UP, look(M.Metal, 120, 124, 126), CYL)
	part(
		model,
		"LampNeck",
		V(0.3, 0.55, 0.55),
		CF(lampAt + V(0, 0.375, 0)) * UP,
		look(M.Metal, 110, 114, 116),
		CYL
	)
	part(
		model,
		"LampRim",
		V(0.07, 1.06, 1.06),
		CF(lampAt - V(0, 0.15, 0)) * UP,
		look(M.CorrodedMetal, 104, 92, 78),
		CYL
	)
	part(
		model,
		"LampDent",
		V(0.22, 0.3, 0.08),
		CF(lampAt + V(0.3, 0.02, -0.4)) * ANG(rad(12), rad(35), 0),
		look(M.Metal, 92, 96, 98)
	)
	part(
		model,
		"LampLens",
		V(0.03, 0.85, 0.85),
		CF(lampAt - V(0, 0.255, 0)) * UP,
		look(M.Neon, 255, 236, 210, 0.45),
		CYL
	)
	return model, (at * CF(0, 0.8, 0)).Position
end

-- A camp sink (there is no plumbing in a bedroom): a steel basin on a frame, a fresh-water
-- jerrycan with a tap on a shelf above it, a grey-water jerrycan under it fed by a short drain
-- hose, a foot pump, rubber gloves. `at`: its centre on the floor, local -Z = out of the wall.
function AptProps.campSink(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "CampSink", at)
	local steel = look(M.Metal, 140, 142, 140)
	-- the basin: a bottom plate and four butting sides
	add("Basin", V(2.4, 0.1, 1.8), CF(0, 2.6, 0), steel)
	for _, z in { -0.95, 0.95 } do
		add("Side", V(2.6, 0.9, 0.1), CF(0, 3.0, z), steel)
	end
	for _, x in { -1.25, 1.25 } do
		add("Side", V(0.1, 0.9, 1.8), CF(x, 3.0, 0), steel)
	end
	add("Grime", V(2.3, 0.03, 1.7), CF(0, 2.665, 0), look(M.Metal, 104, 106, 100))
	add("Drain", V(0.03, 0.3, 0.3), CF(0.6, 2.695, 0.2) * UP, look(M.Metal, 50, 50, 50), CYL)
	for _, x in { -1.1, 1.1 } do
		for _, z in { -0.8, 0.8 } do
			add("Leg", V(0.12, 2.55, 0.12), CF(x, 1.275, z), steel)
		end
	end
	-- the fresh water: a blue jerrycan lying on a wall shelf above, its tap over the basin
	add("WaterShelf", V(1.8, 0.08, 0.9), CF(-0.3, 4.6, 0.5), look(M.Wood, 150, 130, 100))
	add("FreshCan", V(1.5, 0.9, 0.8), CF(-0.3, 5.09, 0.5), look(M.Plastic, 60, 100, 150))
	add("CanTap", V(0.12, 0.3, 0.12), CF(-0.3, 4.5, 0.05), look(M.Plastic, 200, 60, 40))
	-- the grey water: a jerrycan under the basin, the drain hose into it
	add("GreyCan", V(1.3, 1.6, 0.9), CF(0.5, 0.8, 0.1), look(M.Plastic, 120, 124, 120))
	path(model, "DrainHose", {
		(at * CF(0.6, 2.55, 0.2)).Position,
		(at * CF(0.6, 2.0, 0.3)).Position,
		(at * CF(0.5, 1.62, 0.2)).Position,
	}, 0.12, look(M.Rubber, 40, 44, 42))
	-- the foot pump on the floor in front
	add(
		"FootPump",
		V(0.7, 0.25, 0.9),
		CF(-0.6, 0.125, -1.2) * ANG(0, rad(10), 0),
		look(M.Plastic, 60, 62, 64)
	)
	AptProps.gloves(model, at * CF(1.1, 3.6, -0.95), rng, look(M.Rubber, 180, 150, 150))
	return model
end

-- Where the instruments are cleaned between runs (the cheap autoclave): a small steel worktop,
-- a hot plate with a pressure cooker, a UV blade steriliser. `at`: the worktop's centre on the floor, local -Z
-- = out of the wall. Returns the model and the hot plate's cord end (world, at the back).
function AptProps.toolBoiler(parent: Instance, at: CFrame, _rng: Random): (Model, Vector3)
	local model, add = begin(parent, "ToolBoiler", at)
	local steel = look(M.Metal, 150, 152, 150)
	add("Worktop", V(1.2, 0.08, 1.8), CF(0, 2.96, 0), steel)
	for _, x in { -0.52, 0.52 } do
		for _, z in { -0.82, 0.82 } do
			add("Leg", V(0.08, 2.92, 0.08), CF(x, 1.46, z), steel)
		end
	end
	add("HotPlate", V(1.0, 0.14, 0.9), CF(0, 3.07, -0.4), look(M.Metal, 60, 60, 58))
	add("Ring", V(0.03, 0.55, 0.55), CF(0, 3.155, -0.4) * UP, look(M.Metal, 30, 30, 30), CYL)
	add(
		"Cooker",
		V(0.8, 0.9, 0.9),
		CF(0, 3.57, -0.4) * UP,
		look(M.Metal, 170, 172, 172, 0, 0.1),
		CYL
	)
	add("CookerLid", V(0.12, 0.92, 0.92), CF(0, 4.03, -0.4) * UP, look(M.Metal, 120, 122, 122), CYL)
	add("Valve", V(0.15, 0.12, 0.12), CF(0, 4.165, -0.4) * UP, look(M.Plastic, 30, 30, 30), CYL)
	add("Handle", V(0.6, 0.1, 0.12), CF(0.65, 4.0, -0.4), look(M.Plastic, 30, 30, 30))
	-- the little UV blade steriliser beside it (its LED is "ChargerLed", moved to the model's
	-- root by LabBuilder: lit while a blade is in)
	add("Steriliser", V(0.6, 0.3, 0.45), CF(0, 3.15, 0.5), look(M.Plastic, 120, 130, 140))
	add("ChargerLed", V(0.1, 0.06, 0.04), CF(0.15, 3.2, 0.255), look(M.Neon, 120, 220, 120))
	return model, (at * CF(0, 3.0, 0.85)).Position
end

-- The scanner's little CRT, standing on the stash freezer's lid by the pass-box: its glass is
-- "ScanScreen" (moved to the root by LabBuilder; Front face = -Z). `at`: its foot's centre.
function AptProps.scanMonitor(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "ScanMonitor", at)
	add("Crt", V(1.3, 1.1, 1.2), CF(0, 0.55, 0), look(M.Plastic, 176, 170, 156))
	add("CrtBack", V(0.9, 0.8, 0.5), CF(0, 0.5, 0.85), look(M.Plastic, 160, 154, 140))
	add("ScanScreen", V(1.0, 0.75, 0.05), CF(0, 0.62, -0.625), look(M.Glass, 14, 22, 20, 0, 0.1))
	path(model, "CrtCord", {
		(at * CF(0.3, 0.3, 1.1)).Position,
		(at * CF(0.4, -0.1, 1.3)).Position,
	}, 0.08, CORD_BLACK)
	return model
end

-- A power strip fixed to a wall with plugs, and drooping cords (catenaries) toward `targets`.
-- `scorched`: burn marks and a melted plug (the spark's source). `at`: on the wall, local -Z = out.
function AptProps.powerStrip(
	parent: Instance,
	at: CFrame,
	_rng: Random,
	targets: { Vector3 },
	scorched: boolean
): Model
	local model, add = begin(parent, "PowerStrip", at)
	add("Strip", V(1.8, 0.35, 0.25), CF(0, 0, -0.13), look(M.Plastic, 220, 216, 204))
	add("Switch", V(0.2, 0.15, 0.06), CF(-0.75, 0, -0.27), look(M.Plastic, 230, 120, 40))
	for i, target in targets do
		local plug = add(
			"Plug",
			V(0.22, 0.28, 0.3),
			CF(-0.5 + (i - 1) * 0.35, 0, -0.38),
			look(M.Plastic, 40, 40, 40)
		)
		local start = plug.Position + at.LookVector * 0.15
		local distance = (target - start).Magnitude
		catenary(
			model,
			"Cord",
			start,
			target,
			math.min(1.5, distance * 0.2),
			2,
			0.1,
			CORD_LOOKS[(i % #CORD_LOOKS) + 1]
		)
	end
	if scorched then
		overlay(
			model,
			"Scorch",
			Vector2.new(0.5, 0.3),
			at * CF(0.5, 0.05, -0.255) * ANG(0, 0, rad(10)),
			LAYER.STEP,
			look(M.SmoothPlastic, 20, 18, 16)
		)
		add(
			"MeltedPlug",
			V(0.22, 0.24, 0.3),
			CF(0.55, 0, -0.4) * ANG(0, 0, rad(12)),
			look(M.Plastic, 60, 52, 40)
		)
	end
	return model
end

-- The window, turned into the lab's exhaust: a plywood panel fills its top with the duct's
-- collar (the range-hood duct ends here), a box fan wedged under it blows out, flat dull foil
-- closes the gaps beside the fan. `at`: the window's bottom centre ON the wall's room face,
-- local -Z = into the room. Returns the model and the fan's blade model (Anim/FanBlades; its
-- WorldPivot = the hub, RightVector = into the room). The opening is 6 wide, 4 high, from y 3.5
-- to 7.5 above `at`.
function AptProps.foilWindow(parent: Instance, at: CFrame, _rng: Random): (Model, Model)
	local model, add = begin(parent, "FoilWindow", at)
	local frame = look(M.Wood, 140, 130, 110)
	add("Sill", V(6.6, 0.2, 0.7), CF(0, 3.45, -0.1), frame)
	add("FrameTop", V(6.4, 0.25, 0.5), CF(0, 7.625, 0.2), frame)
	for _, x in { -3.075, 3.075 } do
		add("FrameSide", V(0.25, 4.0, 0.5), CF(x, 5.5, 0.2), frame)
	end
	-- the plywood exhaust panel over the fan, and the duct's collar through it
	local ply = look(M.WoodPlanks, 150, 120, 84)
	add("ExhaustPanel", V(5.9, 0.87, 0.1), CF(0, 7.065, 0.25), ply)
	add(
		"Collar",
		V(0.5, 0.76, 0.76),
		CF(0, 7.06, -0.05) * ALONG_Z,
		look(M.Foil, 180, 182, 184, 0, 0.05),
		CYL
	)
	-- flat, dull foil closing the gaps beside the fan
	local foil = look(M.Foil, 176, 178, 180, 0, 0.04)
	for _, x in { -2.3, 2.3 } do
		add("Foil", V(1.3, 3.0, 0.04), CF(x, 5.1, 0.32), foil)
		add("Tape", V(1.3, 0.12, 0.03), CF(x, 6.55, 0.285), TAPE)
	end
	-- the box fan: a square frame, a round dark shroud behind the blades, a grille in front
	local fanFrame = look(M.Plastic, 200, 196, 186)
	local hub = at * CF(0, 5.1, 0.15)
	for _, x in { -1.45, 1.45 } do
		add("FanFrame", V(0.15, 2.75, 0.6), CF(x, 5.1, 0.15), fanFrame)
	end
	for _, y in { 3.65, 6.55 } do
		add("FanFrame", V(3.05, 0.15, 0.6), CF(0, y, 0.15), fanFrame)
	end
	add("Shroud", V(0.08, 2.6, 2.6), CF(0, 5.1, 0.4) * ALONG_Z, look(M.Plastic, 40, 40, 40), CYL)
	for i = 1, 3 do
		add("Grille", V(2.7, 0.03, 0.03), CF(0, 3.75 + i * 0.7, -0.12), look(M.Metal, 80, 80, 78))
	end
	add("FanCord", V(0.08, 0.08, 1.5), CF(1.4, 3.7, -0.6) * ANG(rad(30), 0, 0), CORD_WHITE)
	local blades = Instance.new("Model")
	blades.Name = "FanBlades"
	local bladeLook = look(M.Rubber, 60, 62, 60)
	part(blades, "Hub", V(0.25, 0.5, 0.5), hub * ALONG_Z, bladeLook, CYL)
	for i = 1, 5 do
		local angle = (i - 1) * (2 * math.pi / 5)
		-- each blade: 1.1 long, out from the hub, pitched 20 degrees
		part(
			blades,
			"Blade",
			V(0.5, 1.1, 0.04),
			hub * ANG(0, 0, angle) * CF(0, 0.7, 0) * ANG(0, rad(20), 0),
			bladeLook
		)
	end
	-- the pivot: at the hub, its X axis pointing into the room (local -Z of the window)
	local intoRoom = at.LookVector
	blades.WorldPivot = CFrame.fromMatrix(hub.Position, intoRoom, Vector3.yAxis)
	blades:SetAttribute("Pivot", blades.WorldPivot) -- (for the client, see AptFx)
	blades.Parent = parent
	return model, blades
end

return table.freeze(AptProps)
