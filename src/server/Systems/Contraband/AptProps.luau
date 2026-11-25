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
local SHEET = look(M.Glass, 200, 210, 210, 0.62)
local YELLOWED = look(M.SmoothPlastic, 214, 210, 196)
local RUST = look(M.CorrodedMetal, 110, 80, 60)
local PAPER = look(M.SmoothPlastic, 228, 224, 210)
local INK = Color3.fromRGB(34, 32, 30)

------------------------------------------------------------------------------
-- Shell dressing (walls, floors, ceilings)
------------------------------------------------------------------------------

-- A stain: 2-4 thin opaque layers, darker than the surface, turned differently (no decal).
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
		part(
			parent,
			"Stain",
			V(
				size.X * scale * rng:NextNumber(0.8, 1.1),
				size.Y * scale * rng:NextNumber(0.8, 1.1),
				0.01
			),
			at
				* CF(
					rng:NextNumber(-0.15, 0.15) * size.X,
					rng:NextNumber(-0.15, 0.15) * size.Y,
					-0.006 * i
				)
				* ANG(0, 0, rad(rng:NextNumber(5, 30))),
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
			part(
				parent,
				"Wallpaper",
				V(width, top - base, 0.02),
				at * CF(x + width / 2, base + (top - base) / 2, -0.03),
				stripLook
			)
			if curl then
				peeled += 1
				local flap = height - top
				-- the darker plaster under the peeled bit
				part(
					parent,
					"WallpaperScar",
					V(width * 0.9, flap, 0.012),
					at * CF(x + width / 2, top + flap / 2, -0.012),
					look(M.Plaster, 110, 104, 90)
				)
				-- the flap itself, hinged at its bottom edge and curled out 6-15 degrees
				part(
					parent,
					"WallpaperFlap",
					V(width, flap, 0.02),
					at
						* CF(x + width / 2, top, -0.04)
						* ANG(-rad(rng:NextNumber(6, 15)), 0, 0)
						* CF(0, flap / 2, 0),
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
	dado: boolean?
)
	local board = look(M.Wood, 176, 170, 150)
	part(parent, "Skirting", V(length, 0.55, 0.3), at * CF(length / 2, 0.275, -0.15), board)
	local chips = math.floor(length / 12)
	for _ = 1, chips do
		part(
			parent,
			"Chip",
			V(rng:NextNumber(0.15, 0.4), rng:NextNumber(0.08, 0.2), 0.01),
			at * CF(rng:NextNumber(0.3, length - 0.3), rng:NextNumber(0.15, 0.45), -0.305),
			look(M.Wood, 96, 74, 52)
		)
	end
	if dado then
		-- the old two-tone paint: a dark brown-olive gloss below the dado rail
		part(
			parent,
			"LowerPaint",
			V(length, 3.5, 0.02),
			at * CF(length / 2, 1.75, -0.025),
			look(M.Plaster, 92, 86, 68)
		)
		part(
			parent,
			"DadoRail",
			V(length, 0.12, 0.1),
			at * CF(length / 2, 3.5, -0.05),
			look(M.Wood, 132, 122, 100)
		)
	end
end

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
	for _, side in { -1, 1 } do
		part(
			parent,
			"Casing",
			V(0.4, height + 0.4, depth),
			at * CF(side * (width / 2 + 0.2), (height + 0.4) / 2, 0),
			trim
		)
	end
	part(parent, "Casing", V(width + 0.8, 0.4, depth), at * CF(0, height + 0.2, 0), trim)
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
}

-- A door leaf hinged on the floor at `hinge` (world CFrame: +X runs from the hinge to the
-- latch side, a POSITIVE angle swings the latch toward the hinge's local -Z). The Model's
-- WorldPivot is the hinge line on the floor; the leaf is "Leaf" (PrimaryPart).
-- The client turns the whole model with PivotTo(closedPivot * CFrame.Angles(0, angle, 0)).
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
	if spec.mode == "Locked" then
		leafLook = solid(leafLook)
	end
	local function add(
		partName: string,
		size: Vector3,
		offset: CFrame,
		l: Look,
		shape: Enum.PartType?
	): Part
		return part(model, partName, size, hinge * offset, l, shape)
	end
	local leaf = add("Leaf", V(4.4, 7.2, 0.25), CF(2.2, 3.84, 0), leafLook)
	model.PrimaryPart = leaf
	-- two-tone panels (a hollow door's moulding) and paint chips
	local panel = tint(leafLook, rng, 6)
	panel.collide = false
	panel.color = panel.color:Lerp(Color3.new(0, 0, 0), 0.08)
	-- (on one face only: the one that looks into the corridor / the flat)
	add("Panel", V(3.2, 2.6, 0.03), CF(2.2, 5.6, 0.14), panel)
	add("Panel", V(3.2, 3.2, 0.03), CF(2.2, 1.9, 0.14), panel)
	for _ = 1, rng:NextInteger(1, 2) do
		add(
			"Chip",
			V(rng:NextNumber(0.1, 0.35), rng:NextNumber(0.08, 0.25), 0.01),
			CF(
				rng:NextNumber(0.5, 4),
				rng:NextNumber(0.5, 6.5),
				if rng:NextNumber() < 0.5 then -0.13 else 0.13
			),
			look(M.Wood, 70, 56, 42)
		)
	end
	-- 2 hinges and the knob (both sides)
	local brass = look(M.Metal, 138, 120, 84)
	for _, y in { 1.0, 6.6 } do
		add("Hinge", V(0.12, 0.5, 0.3), CF(0, y, 0), brass)
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
	local hinge = door.WorldPivot
	local metal = look(M.Metal, 120, 118, 110)
	local z = side * 0.18
	part(door, "Hasp", V(0.7, 0.18, 0.06), hinge * CF(4.15, 4.6, z), metal)
	part(door, "Staple", V(0.12, 0.3, 0.12), hinge * CF(4.45, 4.6, z + side * 0.05), metal)
	part(
		door,
		"Padlock",
		V(0.32, 0.4, 0.16),
		hinge * CF(4.45, 4.3, z + side * 0.12),
		look(M.Metal, 140, 136, 122)
	)
	part(
		door,
		"Shackle",
		V(0.06, 0.22, 0.22),
		hinge * CF(4.45, 4.58, z + side * 0.12) * ALONG_Z,
		metal,
		CYL
	)
	-- "PRIVATE" in marker pen
	local plate = part(
		door,
		"Scrawl",
		V(2.6, 0.8, 0.01),
		hinge * CF(2.1, 5.9, side * 0.14) * ANG(0, 0, rad(-3)),
		look(M.Wood, 98, 84, 66, 1)
	)
	writeOn(
		plate,
		if side < 0 then Enum.NormalId.Front else Enum.NormalId.Back,
		"PRIVATE",
		Color3.fromRGB(70, 60, 52)
	)
end

function AptProps.doorBoards(door: Model, side: number, rng: Random)
	local hinge = door.WorldPivot
	local plank = tint(look(M.WoodPlanks, 120, 96, 70), rng)
	local screw = look(M.Metal, 150, 150, 146)
	for i, angle in { 25, -18 } do
		local y = if i == 1 then 5.0 else 2.6
		local board = part(
			door,
			"Plank",
			V(6, 0.6, 0.15),
			hinge * CF(2.2, y, side * 0.21) * ANG(0, 0, rad(angle)),
			tint(plank, rng, 6)
		)
		for _, x in { -2.5, 2.5 } do
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
	local hinge = door.WorldPivot
	local bright = look(M.Metal, 190, 192, 196, 0, 0.3)
	-- a NEW steel deadbolt + hasp on an old door
	part(door, "Deadbolt", V(0.7, 0.45, 0.16), hinge * CF(3.95, 4.3, side * 0.2), bright)
	part(door, "Deadbolt", V(0.7, 0.45, 0.16), hinge * CF(3.95, 4.3, -side * 0.2), bright)
	part(door, "Hasp", V(0.8, 0.16, 0.05), hinge * CF(4.05, 5.1, side * 0.16), bright)
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
	-- foam weather strip on the latch edge, foil tape on the bottom
	part(door, "FoamStrip", V(0.1, 7.2, 0.3), hinge * CF(4.38, 3.8, 0), look(M.Fabric, 70, 70, 66))
	part(
		door,
		"FoilTape",
		V(4.3, 0.3, 0.27),
		hinge * CF(2.2, 0.25, 0),
		look(M.Foil, 196, 198, 200, 0, 0.15)
	)
	-- foil tape also sealing the top and the hinge edge (it catches the teal glow)
	local foil = look(M.Foil, 196, 198, 200, 0, 0.15)
	part(door, "FoilTape", V(4.3, 0.22, 0.27), hinge * CF(2.2, 7.25, 0), foil)
	part(door, "FoilTape", V(0.22, 7.0, 0.27), hinge * CF(0.12, 3.7, 0), foil)
	-- paint chips knocked off the leaf (the old brown under the cream)
	for _, chip in { V(3.3, 2.4, 0), V(0.9, 5.6, 0), V(2.8, 6.4, 0), V(3.8, 1.1, 0) } do
		part(
			door,
			"PaintChip",
			V(0.2, 0.12, 0.01),
			hinge * CF(chip.X, chip.Y, side * 0.13) * ANG(0, 0, rad(chip.X * 20)),
			look(M.Wood, 100, 84, 64)
		)
	end
end

function AptProps.doorSock(door: Model, side: number)
	local hinge = door.WorldPivot
	part(
		door,
		"Sock",
		V(0.3, 0.9, 0.1),
		hinge * CF(3.9, 2.9, side * 0.38) * ANG(0, 0, rad(8)),
		look(M.Fabric, 92, 96, 104)
	)
end

function AptProps.doorTowelHook(door: Model, side: number)
	local hinge = door.WorldPivot
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
-- the flat; the leaf's inner face is at local z = -0.13.
function AptProps.frontDoorDetails(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "FrontDoorDetails", at)
	local brass = look(M.Metal, 150, 128, 80)
	-- three deadbolts of three different ages
	add("Deadbolt", V(0.4, 0.26, 0.12), CF(-1.75, 4.1, -0.19), brass)
	add("Deadbolt", V(0.32, 0.34, 0.14), CF(-1.75, 4.9, -0.2), look(M.Metal, 110, 108, 100))
	add("Deadbolt", V(0.44, 0.24, 0.13), CF(-1.75, 5.8, -0.19), look(M.Metal, 192, 194, 198))
	add("Peephole", V(0.08, 0.16, 0.16), CF(0, 5.3, -0.16) * ALONG_Z, brass, CYL)
	-- a door chain hanging loose from its rail
	add("ChainRail", V(0.6, 0.12, 0.08), CF(-1.3, 5.35, -0.17), brass)
	for i = 1, 3 do
		local t = i / 3
		add(
			"ChainLink",
			V(0.08, 0.08, 0.08),
			CF(-1.6 - t * 0.45, 5.3 - math.sin(t * math.pi) * 0.35 - t * 0.2, -0.2),
			brass,
			BALL
		)
	end
	add("Letterbox", V(1.2, 0.3, 0.06), CF(0, 2.7, -0.15), brass)
	-- a crack in the paint and a scuffed kick zone
	local crackLook = look(M.SmoothPlastic, 52, 44, 36)
	add("PaintCrack", V(0.035, 1.6, 0.01), CF(0.7, 2.0, -0.135) * ANG(0, 0, rad(18)), crackLook)
	add("PaintCrack", V(0.03, 0.7, 0.01), CF(0.95, 2.6, -0.135) * ANG(0, 0, rad(-25)), crackLook)
	add(
		"Scuff",
		V(3.4, 0.7, 0.01),
		CF(0, 0.45, -0.132),
		tint(look(M.SmoothPlastic, 64, 54, 44), rng)
	)
	-- the flat number on the inside, a reminder sticker
	return model
end

-- A heap of mail behind the door (envelopes fanned on the floor; one "FINAL NOTICE").
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
		add(
			"Envelope",
			V(0.8 * rng:NextNumber(0.9, 1.15), 0.02, 0.5 * rng:NextNumber(0.9, 1.1)),
			CF(rng:NextNumber(-1.4, 1.4), 0.012 + i * 0.022, rng:NextNumber(-0.4, 0.4))
				* ANG(
					rad(rng:NextNumber(-3, 3)),
					rng:NextNumber(0, math.pi),
					rad(rng:NextNumber(-3, 3))
				),
			l
		)
	end
	local notice = add(
		"FinalNotice",
		V(0.85, 0.02, 0.55),
		CF(0.3, 0.03 + count * 0.022, -0.2) * ANG(0, rad(14), 0),
		look(M.SmoothPlastic, 236, 232, 220)
	)
	writeOn(notice, Enum.NormalId.Top, "FINAL NOTICE", INK, Enum.Font.SourceSansBold, 80)
	return model
end

-- Coat hooks on a wall with two sagging jackets. `at`: on the floor against the wall, local -Z
-- = out of the wall.
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
			local x = (p - 2) * 0.9 + (s - 1.5) * 0.42 + rng:NextNumber(-0.1, 0.1)
			local onSide = p == 3 and s == 2
			local frame = CF(x, if onSide then 0.24 else 0.06, rng:NextNumber(-0.3, 0.3))
				* ANG(0, jitterAngle(rng, 5, 35), if onSide then rad(80) else 0)
			add("Sole", V(0.42, 0.12, 1.0), frame, pair.sole)
			add("Upper", V(0.38, 0.35, 0.72), frame * CF(0, 0.22, 0.12), tint(pair.upper, rng))
		end
	end
	return model
end

-- The open meter cupboard: a fuse box choked with six extension cords (the FIRST lab sign).
-- `at`: on the floor against the wall, local -Z = out of the wall. Returns the model and the
-- world point where the cord bundle leaves the cupboard.
function AptProps.meterCupboard(parent: Instance, at: CFrame, _rng: Random): (Model, Vector3)
	local model, add = begin(parent, "MeterCupboard", at)
	local board = look(M.Wood, 168, 160, 140)
	-- (a small cupboard: 2 wide, 4 high, 0.8 deep, from y 3.6 to 7.6)
	add("Back", V(2, 4, 0.05), CF(0, 5.6, -0.03), look(M.Wood, 120, 112, 96))
	for _, x in { -1, 1 } do
		add("Side", V(0.08, 4, 0.8), CF(x, 5.6, -0.4), board)
	end
	add("Top", V(2.08, 0.08, 0.8), CF(0, 7.6, -0.4), board)
	add("Bottom", V(2.08, 0.08, 0.8), CF(0, 3.6, -0.4), board)
	-- the cupboard door, swung wide open (150 degrees) on its left hinge
	add("CupboardDoor", V(2, 4, 0.08), CF(-1, 5.6, -0.8) * ANG(0, rad(150), 0) * CF(1, 0, 0), board)
	-- the fuse box and its six plugs
	add("FuseBox", V(1.3, 1.4, 0.35), CF(0.1, 6.3, -0.22), look(M.Metal, 160, 158, 150))
	add("FuseCover", V(1.2, 0.5, 0.05), CF(0.1, 6.75, -0.42), look(M.Metal, 140, 138, 130))
	local exit = at * CF(0.2, 3.66, -0.55)
	-- the six cords droop from their plugs to a knot under the box, then run down the wall
	-- as one taped bundle to the exit (where LabBuilder's corridor bundle takes over)
	local knot = at * CF(0.15, 5.45, -0.42)
	for i = 1, 6 do
		local x = -0.45 + (i - 1) * 0.18
		local plugAt = at * CF(x, 5.95 + (i % 2) * 0.2, -0.45)
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
	-- tape round the bundle, a torch, a roll of duct tape, the sticker
	add("Tape", V(0.4, 0.25, 0.4), CF(0.15, 4.6, -0.58), TAPE)
	add(
		"Torch",
		V(0.8, 0.2, 0.2),
		CF(-0.55, 3.75, -0.4) * ANG(0, rad(20), 0),
		look(M.Plastic, 40, 44, 48),
		CYL
	)
	add("DuctTape", V(0.22, 0.5, 0.5), CF(0.6, 3.9, -0.38) * UP, look(M.Fabric, 150, 150, 146), CYL)
	local sticker = add(
		"Sticker",
		V(0.9, 0.3, 0.01),
		CF(0.1, 7.15, -0.07) * ANG(0, 0, rad(-4)),
		look(M.SmoothPlastic, 226, 210, 120)
	)
	writeOn(sticker, Enum.NormalId.Front, "DO NOT SWITCH OFF", INK, Enum.Font.SourceSansBold)
	return model, exit.Position
end

-- A small mirror with a dark corner (the silvering gone).
function AptProps.mirror(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "Mirror", at)
	add("Frame", V(1.4, 1.8, 0.08), CF(0, 5.2, -0.04), look(M.Wood, 70, 56, 42))
	add("Glass", V(1.2, 1.6, 0.03), CF(0, 5.2, -0.09), look(M.Glass, 120, 126, 124, 0, 0.3))
	add(
		"DarkCorner",
		V(0.01, 0.6, 0.5),
		CF(0.35, 4.7, -0.11) * ANG(0, rad(90), 0) * ANG(0, 0, 0),
		look(M.SmoothPlastic, 16, 16, 16),
		WEDGE
	)
	return model
end

-- A light switch with its cover hanging crooked.
function AptProps.lightSwitch(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "LightSwitch", at)
	add(
		"Cover",
		V(0.32, 0.46, 0.05),
		CF(0, 4, -0.03) * ANG(0, 0, rad(8) * (if rng:NextNumber() < 0.5 then 1 else -1)),
		look(M.SmoothPlastic, 206, 200, 182)
	)
	add("Toggle", V(0.08, 0.14, 0.06), CF(0, 4, -0.07), look(M.SmoothPlastic, 220, 216, 200))
	add("Grime", V(0.5, 0.6, 0.01), CF(0, 4.05, -0.005), look(M.Plaster, 104, 96, 80))
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
	for _, x in { -3.2, 3.2 } do
		add("Arm", V(0.6, 1.4, 2.8), CF(x, 1.75, 0), leather)
	end
	local cushion = tint(leather, rng, 5)
	add("Cushion", V(2.9, 0.5, 2.1), CF(-1.48, 1.6, -0.2) * ANG(rad(2), 0, rad(-1.5)), cushion)
	add("Cushion", V(2.9, 0.42, 2.1), CF(1.48, 1.56, -0.25) * ANG(rad(-1), 0, rad(2)), cushion)
	-- the worn patch (cloth showing through) and a sagging seat
	add(
		"Patch",
		V(1, 0.02, 1),
		CF(-1.3, 1.86, -0.4) * ANG(0, rad(12), 0),
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
			add("Foot", V(0.25, 0.35, 0.25), CF(x, 0.17, z), look(M.Wood, 40, 30, 24))
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
	add("Plate", V(0.04, 0.8, 0.8), CF(0.55, 1.44, 0.72) * UP * ANG(rad(3), 0, 0), plate, CYL)
	add("Plate", V(0.04, 0.7, 0.7), CF(0.9, 1.4, -0.7) * UP, tint(plate, rng), CYL)
	add(
		"Laptop",
		V(1.2, 0.08, 0.85),
		CF(0.3, 1.42, -0.2) * ANG(0, rad(-12), 0),
		look(M.Plastic, 40, 40, 42)
	)
	-- (the story: a ring stain on the wood)
	add("Ring", V(0.01, 0.5, 0.5), CF(-0.2, 1.376, -1.0) * UP, look(M.Wood, 64, 46, 32), CYL)
	return model
end

-- An old boxy CRT television on a plastic crate, on standby (the ONLY red light of the flat).
function AptProps.crtTV(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "CrtTV", at)
	add("Crate", V(2.4, 1.4, 1.7), CF(0, 0.7, 0), solid(tint(look(M.Plastic, 52, 70, 84), rng)))
	add("Body", V(2.0, 1.55, 1.5), CF(0, 2.18, 0.05), look(M.Plastic, 54, 50, 46))
	add("Screen", V(1.6, 1.15, 0.05), CF(-0.05, 2.22, -0.71), look(M.Glass, 22, 24, 24, 0, 0.12))
	add("Led", V(0.06, 0.06, 0.03), CF(0.85, 1.55, -0.71), look(M.Neon, 255, 40, 30))
	local rodLook = look(M.Metal, 160, 160, 156)
	add("Antenna", V(1.4, 0.04, 0.04), CF(-0.3, 3.4, 0.3) * ANG(0, 0, rad(55)), rodLook, CYL)
	add("Antenna", V(1.4, 0.04, 0.04), CF(0.3, 3.4, 0.3) * ANG(0, 0, rad(125)), rodLook, CYL)
	add("Dust", V(1.9, 0.01, 1.4), CF(0, 2.96, 0.05), look(M.Plastic, 76, 72, 66))
	return model
end

-- The venetian blind window. `at`: the window's bottom centre ON the wall line (the wall's
-- room face), local -Z = into the room. The opening is 7 wide, 5 high, from y 3 to 8.
function AptProps.blindWindow(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "BlindWindow", at)
	local frame = look(M.Wood, 150, 140, 118)
	add("Sill", V(7.6, 0.2, 0.7), CF(0, 2.95, -0.1), frame)
	add("FrameTop", V(7.4, 0.25, 0.4), CF(0, 8.0, 0.25), frame)
	for _, x in { -3.6, 3.6 } do
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

-- The kitchen counter (carcass, chipped marble top, a sink full of dishes, a kettle, a dish rack)
-- and the wall cabinet above it. Front = local -Z, 9 long (local X), 2.4 deep.
function AptProps.kitchenCounter(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "KitchenCounter", at)
	local carcass = look(M.Wood, 156, 146, 120)
	add("Carcass", V(9, 2.85, 2.25), CF(0, 1.5, 0.05), solid(carcass))
	add("ToeKick", V(9, 0.3, 0.05), CF(0, 0.15, -1.08), look(M.Wood, 52, 44, 36))
	add("Top", V(9.1, 0.15, 2.4), CF(0, 3.025, 0), look(M.Marble, 150, 146, 136))
	add("TopChip", V(0.4, 0.16, 0.2), CF(-2.7, 3.02, -1.12), look(M.Concrete, 110, 104, 94))
	-- four cabinet doors, one hanging off its hinge
	local front = tint(look(M.Wood, 150, 140, 114), rng)
	for i = 1, 4 do
		local x = -3.4 + (i - 1) * 2.27
		if i == 3 then
			add(
				"CabinetDoor",
				V(2.1, 2.4, 0.06),
				CF(x - 1.05, 1.6, -1.2) * ANG(0, 0, rad(-12)) * CF(1.05, 0, 0),
				front
			)
		else
			add("CabinetDoor", V(2.1, 2.4, 0.06), CF(x, 1.6, -1.2), tint(front, rng, 4))
		end
		add("Handle", V(0.5, 0.08, 0.08), CF(x + 0.6, 2.4, -1.26), look(M.Metal, 150, 146, 138))
	end
	-- the sink (a steel tray set into the top) full of plates and mugs, a tap
	local steel = look(M.Metal, 160, 162, 160)
	add("Sink", V(2.2, 0.06, 1.6), CF(-1.2, 3.0, -0.1), look(M.Metal, 110, 112, 110))
	for _, offset in { CF(-1.2, 3.1, -0.92), CF(-1.2, 3.1, 0.72) } do
		add("SinkRim", V(2.3, 0.1, 0.06), offset, steel)
	end
	add("Tap", V(0.12, 0.9, 0.12), CF(-1.2, 3.5, 0.75), steel)
	add("Spout", V(0.6, 0.1, 0.1), CF(-1.2, 3.92, 0.5) * ALONG_Z, steel, CYL)
	local plate = look(M.SmoothPlastic, 210, 206, 196)
	for i = 1, 2 do
		add(
			"Plate",
			V(0.04, 0.8, 0.8),
			CF(-1.5 + i * 0.12, 3.15, -0.1) * ANG(rad(70 + i * 3), 0, 0) * UP,
			tint(plate, rng, 6),
			CYL
		)
	end
	add("Mug", V(0.4, 0.3, 0.3), CF(-0.5, 3.25, 0.2) * UP, look(M.SmoothPlastic, 70, 96, 110), CYL)
	add(
		"Mug",
		V(0.4, 0.3, 0.3),
		CF(-1.9, 3.18, -0.4) * ANG(rad(90), 0, rad(70)),
		look(M.SmoothPlastic, 200, 190, 150),
		CYL
	)
	-- the kettle (lime-scale band) and a dish rack
	local kettleLook = look(M.Plastic, 200, 196, 186)
	add("Kettle", V(0.9, 0.7, 0.7), CF(1.6, 3.55, 0.3) * UP, kettleLook, CYL)
	add(
		"KettleScale",
		V(0.2, 0.72, 0.72),
		CF(1.6, 3.2, 0.3) * UP,
		look(M.Plastic, 170, 166, 150),
		CYL
	)
	add("KettleHandle", V(0.12, 0.7, 0.12), CF(1.6, 3.6, 0.72), kettleLook)
	add("KettleBase", V(0.1, 0.8, 0.8), CF(1.6, 3.15, 0.3) * UP, look(M.Plastic, 40, 40, 40), CYL)
	local wire = look(M.Metal, 170, 170, 166)
	add("RackBase", V(1.6, 0.06, 1.0), CF(3.2, 3.15, 0.1), wire)
	for i = 1, 3 do
		add("RackWire", V(0.03, 0.6, 1.0), CF(2.6 + i * 0.36, 3.45, 0.1), wire)
	end
	add(
		"RackPlate",
		V(0.04, 0.8, 0.8),
		CF(3.1, 3.55, 0.1) * ANG(0, rad(90), 0) * ANG(0, 0, 0),
		plate
	)
	-- the wall cabinet above (one door ajar), 6 long, at the counter's left end
	add("WallCabinet", V(6, 2.4, 1.2), CF(-1.5, 7.3, 0.6), carcass)
	add(
		"WallCabinetDoor",
		V(2.9, 2.3, 0.06),
		CF(-4.4, 7.3, -0.03) * ANG(0, rad(-25), 0) * CF(1.45, 0, 0),
		front
	)
	add(
		"WallCabinetDoor",
		V(2.9, 2.3, 0.06),
		CF(1.45 - 1.5 + 0.05, 7.3, -0.03),
		tint(front, rng, 4)
	)
	-- grease shadow on the wall above the kettle
	add("Grease", V(1.6, 1.8, 0.01), CF(1.6, 4.4, 1.15), look(M.Plaster, 112, 100, 78))
	return model
end

-- The old kitchen fridge (yellowed, rusty base, magnets, taped note) with a few tubs inside.
-- The door itself is a Doors model (Door_Fridge) made by `fridgeDoor`. Front = local -Z;
-- 2.2 wide, 2.1 deep (door included), 6 high.
function AptProps.oldFridge(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "OldFridge", at)
	local shell = solid(tint(YELLOWED, rng))
	add("Back", V(2.2, 6, 0.1), CF(0, 3, 1.0), shell)
	for _, x in { -1.05, 1.05 } do
		add("Side", V(0.1, 6, 1.9), CF(x, 3, 0.1), shell)
	end
	add("Top", V(2.2, 0.1, 1.9), CF(0, 5.95, 0.1), shell)
	add("Bottom", V(2.2, 0.5, 1.9), CF(0, 0.25, 0.1), shell)
	add("Inside", V(1.95, 5.3, 0.02), CF(0, 3.2, 0.93), look(M.SmoothPlastic, 226, 228, 222))
	add("RustBase", V(2.22, 0.3, 1.92), CF(0, 0.15, 0.1), RUST)
	local shelf = look(M.Glass, 200, 214, 214, 0.5)
	for _, y in { 2.0, 3.6 } do
		add("Shelf", V(1.95, 0.04, 1.6), CF(0, y, 0.15), shelf)
	end
	-- three tubs of "culture medium" (milky, with teal lids) and half a loaf: nothing else
	local tubLook = look(M.SmoothPlastic, 220, 226, 222)
	local lidLook = look(M.SmoothPlastic, 70, 120, 128)
	for i, label in { "MEDIUM A", "MEDIUM B", "SEALS" } do
		local x = -0.6 + (i - 1) * 0.6
		local y = if i == 3 then 3.62 else 2.02
		local tub = add("Tub", V(0.5, 0.5, 0.7), CF(x, y + 0.25, 0.1), tubLook)
		add("Lid", V(0.52, 0.06, 0.72), CF(x, y + 0.53, 0.1), lidLook)
		writeOn(tub, Enum.NormalId.Front, label, INK)
	end
	add("Loaf", V(0.8, 0.45, 0.5), CF(0.35, 3.85, 0.3), look(M.Plastic, 190, 140, 80))
	add("LoafBag", V(1.1, 0.5, 0.55), CF(0.45, 3.86, 0.3), look(M.Glass, 220, 214, 196, 0.6))
	-- (the hum comes from the back: a dusty compressor grille)
	add("Grille", V(1.8, 1.0, 0.05), CF(0, 0.9, 1.07), look(M.Metal, 40, 40, 38))
	return model
end

-- The kitchen fridge's door (a Doors model, Prompt mode). `hinge`: see AptProps.door.
function AptProps.fridgeDoor(parent: Instance, hinge: CFrame, rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "Door_Fridge"
	local function add(partName: string, size: Vector3, offset: CFrame, l: Look): Part
		return part(model, partName, size, hinge * offset, l)
	end
	local leaf = add("Leaf", V(2.2, 5.4, 0.2), CF(1.1, 3.25, 0), tint(YELLOWED, rng))
	model.PrimaryPart = leaf
	add("Gasket", V(2.0, 5.2, 0.05), CF(1.1, 3.25, 0.12), look(M.Rubber, 120, 118, 110))
	add("Handle", V(0.12, 1.4, 0.15), CF(1.95, 3.9, -0.2), look(M.Metal, 170, 172, 174))
	add("DoorShelf", V(1.8, 0.4, 0.3), CF(1.1, 2.2, 0.28), look(M.SmoothPlastic, 214, 220, 216))
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
			CF(spot.X + rng:NextNumber(-0.06, 0.06), spot.Y, -0.12)
				* ANG(0, 0, jitterAngle(rng, 5, 30)),
			magnet
		)
	end
	local note = add("Note", V(1.0, 1.1, 0.01), CF(1.05, 4.6, -0.105) * ANG(0, 0, rad(-3)), PAPER)
	writeOn(note, Enum.NormalId.Front, "DON'T OPEN\nCULTURE MEDIUM", INK)
	add("NoteTape", V(0.5, 0.14, 0.012), CF(1.05, 5.12, -0.11), TAPE)
	model.WorldPivot = hinge
	model:SetAttribute("Room", "Living")
	model:SetAttribute("Mode", "Prompt")
	model:SetAttribute("RestAngle", 0)
	model:SetAttribute("OpenAngle", 100)
	model:SetAttribute("Label", "Fridge")
	model.Parent = parent
	return model
end

-- A folding table: a pile of invoices (one with a coffee ring), a calculator, two cooler lids.
function AptProps.foldTable(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "FoldTable", at)
	add("Top", V(3, 0.1, 2), CF(0, 2.6, 0), solid(look(M.Plastic, 182, 176, 160)))
	local leg = look(M.Metal, 120, 120, 116)
	for _, x in { -1.3, 1.3 } do
		add("Leg", V(0.1, 2.6, 0.1), CF(x, 1.3, -0.8) * ANG(rad(8), 0, 0), leg)
		add("Leg", V(0.1, 2.6, 0.1), CF(x, 1.3, 0.8) * ANG(rad(-8), 0, 0), leg)
	end
	for i = 1, 6 do
		add(
			"Invoice",
			V(0.75, 0.01, 1.0),
			CF(-0.6 + rng:NextNumber(-0.1, 0.1), 2.66 + i * 0.012, rng:NextNumber(-0.1, 0.1))
				* ANG(0, jitterAngle(rng), 0),
			tint(PAPER, rng, 6)
		)
	end
	add(
		"CoffeeRing",
		V(0.01, 0.4, 0.4),
		CF(-0.5, 2.74, 0.2) * UP,
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
	add("Runner", V(2.6, 0.04, length), CF(0, 0.06, 0), look(M.Fabric, 82, 44, 40))
	add(
		"Wear",
		V(1.3, 0.01, length - 1),
		CF(rng:NextNumber(-0.1, 0.1), 0.085, 0),
		look(M.Fabric, 104, 70, 62)
	)
	for _, z in { -length / 2, length / 2 } do
		add("Fringe", V(2.6, 0.03, 0.25), CF(0, 0.055, z), look(M.Fabric, 160, 146, 120))
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
	tapeEvery: number?
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
				local out = side * (if rng:NextNumber() < 0.5 then -1 else 1) * 0.5
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

-- A bucket. `water` = the height of the water surface (nil = empty). Its "Water" disc is named.
function AptProps.bucket(parent: Instance, at: CFrame, rng: Random, l: Look, water: number?): Model
	local model, add = begin(parent, "Bucket", at)
	local body = tint(l, rng, 5)
	add("Bucket", V(1.35, 1.3, 1.3), CF(0, 0.675, 0) * UP, body, CYL)
	add("Rim", V(0.1, 1.42, 1.42), CF(0, 1.33, 0) * UP, body, CYL)
	add(
		"Handle",
		V(1.3, 0.05, 0.05),
		CF(0, 1.55, 0) * ANG(0, 0, rad(10)),
		look(M.Metal, 140, 140, 136)
	)
	if water then
		add(
			"Water",
			V(0.02, 1.24, 1.24),
			CF(0, water, 0) * UP,
			look(M.Glass, 60, 58, 50, 0.1, 0.1),
			CYL
		)
	end
	return model
end

-- A picture frame hanging crooked (a dark landscape, no image). On a wall; local -Z = out.
function AptProps.pictureFrame(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "PictureFrame", at)
	local tilt = ANG(0, 0, rad(4))
	-- a small cheap print (a dull landscape in two bands) in a thin wooden frame
	add("Frame", V(1.3, 1.0, 0.08), CF(0, 5.6, -0.04) * tilt, look(M.Wood, 90, 70, 46))
	add(
		"Picture",
		V(1.12, 0.5, 0.02),
		CF(0, 5.8, -0.09) * tilt,
		look(M.SmoothPlastic, 104, 100, 84)
	)
	add(
		"Hills",
		V(1.12, 0.34, 0.02),
		CF(0.01, 5.38, -0.09) * tilt,
		look(M.SmoothPlastic, 58, 54, 44)
	)
	-- the paler rectangle where a bigger picture hung straight for years
	add("Ghost", V(2.2, 1.6, 0.01), CF(0.15, 5.75, -0.005), look(M.Plaster, 142, 138, 124))
	return model
end

-- A dead plant: a terracotta pot with three dry stalks.
function AptProps.deadPlant(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "DeadPlant", at)
	add("Pot", V(1.1, 1.0, 1.0), CF(0, 0.55, 0) * UP, look(M.Plastic, 120, 70, 50), CYL)
	add("Soil", V(0.02, 0.9, 0.9), CF(0, 1.08, 0) * UP, look(M.Concrete, 50, 40, 32), CYL)
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
		V(0.4, 0.02, 0.25),
		CF(0.4, 0.06, -0.6) * ANG(0, rad(30), 0),
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

-- A 3-way adapter in a wall socket with nothing plugged in. On a wall; local -Z = out.
function AptProps.outlet(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "Outlet", at)
	add("Plate", V(0.5, 0.5, 0.05), CF(0, 1.0, -0.03), look(M.SmoothPlastic, 206, 200, 182))
	add("Adapter", V(0.4, 0.4, 0.35), CF(0, 1.0, -0.22), look(M.Plastic, 220, 216, 204))
	add("Scorch", V(0.3, 0.3, 0.01), CF(0.05, 1.25, -0.06), look(M.Plaster, 90, 84, 70))
	return model
end

-- A sagging ceiling section (lowered 0.3, tilted, a dark gap round it, ring stains). `at`: the
-- ceiling point at its centre (the ceiling's underside).
function AptProps.ceilingSag(parent: Instance, at: CFrame, rng: Random, ceiling: Color3): Model
	local model, add = begin(parent, "CeilingSag", at)
	add("Gap", V(6.1, 0.02, 6.1), CF(0, -0.02, 0), look(M.SmoothPlastic, 26, 24, 20))
	local panel = look(M.Plaster, 0, 0, 0)
	panel.color = ceiling:Lerp(Color3.fromRGB(110, 96, 70), 0.25)
	add("Panel", V(6, 0.1, 6), CF(0, -0.3, 0) * ANG(rad(3), 0, rad(2)), panel)
	local stain = Color3.fromRGB(120, 100, 70)
	for i, size in { 4.2, 3.0, 1.8 } do
		local ring = look(M.Plaster, 0, 0, 0)
		ring.color = stain:Lerp(Color3.fromRGB(80, 64, 44), (i - 1) / 2)
		add(
			"RingStain",
			V(0.01, size, size * rng:NextNumber(0.8, 1)),
			CF(0.6, -0.36 - i * 0.008, 0.3) * ANG(rad(3), 0, rad(2)) * UP,
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

-- A stained bathtub (tide-line), murky water, with the green hose over its rim (the hose is
-- built by AptProps.hose). Front = local -Z; length along local X (7 long, 2.6 wide).
function AptProps.bathtub(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "Bathtub", at)
	local enamel = solid(tint(look(M.SmoothPlastic, 206, 204, 192), rng))
	add("Bottom", V(6.9, 0.4, 2.5), CF(0, 0.2, 0), enamel)
	for _, z in { -1.18, 1.18 } do
		add("Wall", V(6.9, 2.2, 0.16), CF(0, 1.1, z), enamel)
	end
	for _, x in { -3.38, 3.38 } do
		add("End", V(0.16, 2.2, 2.5), CF(x, 1.1, 0), enamel)
	end
	add("Inside", V(6.5, 0.02, 2.2), CF(0, 0.41, 0), look(M.SmoothPlastic, 176, 172, 156))
	add("TideLine", V(6.56, 0.18, 2.22), CF(0, 0.9, 0), look(M.SmoothPlastic, 132, 120, 100))
	add("Water", V(6.5, 0.02, 2.2), CF(0, 0.8, 0), look(M.Glass, 70, 78, 64, 0.3, 0.05))
	add("Tap", V(0.12, 0.5, 0.12), CF(-3.2, 2.4, 0.9), look(M.Metal, 150, 146, 138))
	add("Spout", V(0.5, 0.12, 0.12), CF(-3.0, 2.6, 0.9), look(M.Metal, 150, 146, 138), CYL)
	add(
		"Limescale",
		V(0.4, 0.5, 0.01),
		CF(-3.29, 1.9, 0.9) * ANG(0, rad(90), 0),
		look(M.SmoothPlastic, 170, 176, 150)
	)
	return model
end

-- The basin and the mirror cabinet above it (cabinet open, empty, cracked mirror). On a wall;
-- local -Z = out. Returns the model.
function AptProps.basinCabinet(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "BasinCabinet", at)
	local ceramic = look(M.SmoothPlastic, 214, 214, 204)
	add("Basin", V(2, 0.5, 1.4), CF(0, 2.9, -0.7), ceramic)
	add("Bowl", V(1.6, 0.02, 1.0), CF(0, 3.16, -0.75), look(M.SmoothPlastic, 170, 168, 150))
	add("Pedestal", V(0.6, 2.6, 0.6), CF(0, 1.3, -0.45), ceramic)
	add("Tap", V(0.12, 0.45, 0.12), CF(0, 3.35, -0.2), look(M.Metal, 150, 146, 138))
	add("Spout", V(0.12, 0.1, 0.45), CF(0, 3.55, -0.38), look(M.Metal, 150, 146, 138))
	add("Plughole", V(0.02, 0.2, 0.2), CF(0, 3.17, -0.75) * UP, look(M.Metal, 60, 60, 60), CYL)
	-- the cabinet: box, empty shelves, door open with a cracked mirror (two pieces, a gap)
	local box = tint(look(M.SmoothPlastic, 196, 194, 182), rng)
	add("Cabinet", V(1.9, 2.3, 0.1), CF(0, 6.0, -0.06), box)
	for _, x in { -0.95, 0.95 } do
		add("CabinetSide", V(0.06, 2.3, 0.55), CF(x, 6.0, -0.33), box)
	end
	for _, y in { 4.88, 5.6, 6.4, 7.12 } do
		add("CabinetShelf", V(1.9, 0.06, 0.55), CF(0, y, -0.33), box)
	end
	local hinge = CF(0.95, 6.0, -0.62) * ANG(0, rad(-115), 0)
	add("CabinetDoor", V(1.9, 2.3, 0.08), hinge * CF(-0.95, 0, 0), box)
	add(
		"Mirror",
		V(1.7, 1.25, 0.02),
		hinge * CF(-0.95, 0.5, -0.05) * ANG(0, 0, rad(1)),
		look(M.Glass, 150, 156, 150, 0, 0.3)
	)
	add(
		"Mirror",
		V(1.7, 0.85, 0.02),
		hinge * CF(-0.95, -0.6, -0.05) * ANG(0, 0, rad(-1)),
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
	add("Tape", V(0.3, y + 0.02, 1.2), CF(0.4, y / 2, 0), TAPE)
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

-- Mould clusters in a ceiling corner. `at`: the corner point on the ceiling.
function AptProps.mould(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "Mould", at)
	for _ = 1, 3 do
		add(
			"Mould",
			V(rng:NextNumber(0.3, 1.2), 0.02, rng:NextNumber(0.3, 1.0)),
			CF(rng:NextNumber(0, 1.6), -0.015, rng:NextNumber(0, 1.6))
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
		V(1.4, 0.01, 1.1),
		CF(0.6, 0.706, 0.6) * ANG(0, rad(20), 0),
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
		CF(0.1, 1.55, 0) * ANG(0, rad(-15), 0) * CF(0, 0, -0.18),
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

-- The folding desk by the window: a desk lamp head (the light is a fixture), a closed laptop,
-- notebooks, a cooler box used as a stool. Front = local -Z, length along local X (6 long).
function AptProps.deskTable(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "DeskTable", at)
	add("Top", V(6, 0.1, 2.1), CF(0, 2.8, 0), solid(look(M.Plastic, 170, 164, 146)))
	for _, x in { -2.8, 2.8 } do
		add("Leg", V(0.12, 2.8, 1.9), CF(x, 1.4, 0), look(M.Metal, 110, 110, 106))
	end
	add(
		"Laptop",
		V(1.3, 0.08, 0.9),
		CF(-1.4, 2.9, -0.1) * ANG(0, rad(10), 0),
		look(M.Plastic, 52, 52, 56)
	)
	add(
		"Notebook",
		V(0.8, 0.06, 1.1),
		CF(0.4, 2.88, 0.2) * ANG(0, rad(-18), 0),
		look(M.SmoothPlastic, 40, 60, 90)
	)
	add(
		"Notebook",
		V(0.8, 0.05, 1.1),
		CF(0.45, 2.94, 0.25) * ANG(0, rad(-6), 0),
		look(M.SmoothPlastic, 170, 150, 90)
	)
	add(
		"Pen",
		V(0.6, 0.04, 0.04),
		CF(0.9, 2.88, -0.5) * ANG(0, rad(40), 0),
		look(M.Plastic, 30, 30, 40),
		CYL
	)
	-- the desk lamp (arm + shade; the SpotLight is the DeskLamp fixture over it)
	local lampLook = look(M.Metal, 60, 64, 60)
	add("LampBase", V(0.12, 0.6, 0.6), CF(1.9, 2.91, 0.4) * UP, lampLook, CYL)
	add("LampArm", V(0.08, 1.6, 0.08), CF(1.9, 3.6, 0.3) * ANG(rad(-15), 0, 0), lampLook)
	add("LampArm", V(0.08, 1.0, 0.08), CF(1.9, 4.45, 0.05) * ANG(rad(55), 0, 0), lampLook)
	add("LampShade", V(0.5, 0.55, 0.55), CF(1.9, 4.65, -0.4) * UP, lampLook, CYL)
	-- the cooler-box stool
	add("CoolerStool", V(1.8, 1.4, 1.2), CF(-1.0, 0.7, -1.7), solid(look(M.Plastic, 196, 190, 170)))
	add("CoolerLid", V(1.85, 0.15, 1.25), CF(-1.0, 1.45, -1.7), look(M.Plastic, 70, 120, 140))
	return model
end

-- The whiteboard: the clone timeline in marker pen ("MATRIX / FRAME / SHELL", failed batch,
-- crossed days). On a wall; local -Z = out. 6 wide, 3.5 high, bottom at y 3.5.
function AptProps.whiteboard(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "Whiteboard", at)
	add("Frame", V(6.2, 3.7, 0.08), CF(0, 5.25, -0.04), look(M.Metal, 150, 150, 146))
	local board =
		add("Board", V(6, 3.5, 0.03), CF(0, 5.25, -0.09), look(M.SmoothPlastic, 228, 230, 226))
	-- ghost marks of old wiped writing
	add(
		"Ghost",
		V(2.4, 0.9, 0.01),
		CF(-1.4, 6.3, -0.11) * ANG(0, 0, rad(4)),
		look(M.SmoothPlastic, 206, 208, 204)
	)
	local marker = Color3.fromRGB(40, 60, 90)
	-- (the numbers below read like a page: x grows to the READER's right. A prop's local +X is
	-- the viewer's LEFT when facing its front, so every x is mirrored with -x.)
	local function line(text: string, x: number, y: number, w: number, h: number, angle: number?)
		local strip = add(
			"Writing",
			V(w, h, 0.01),
			CF(-x, y, -0.115) * ANG(0, 0, rad(angle or 0)),
			look(M.SmoothPlastic, 228, 230, 226, 1)
		)
		writeOn(strip, Enum.NormalId.Front, text, marker, Enum.Font.PermanentMarker, 50)
	end
	line("GROWTH", -2.1, 6.75, 1.5, 0.4)
	line("MATRIX", -1.9, 3.95, 1.0, 0.3)
	line("FRAME", -0.6, 3.95, 1.0, 0.3)
	line("SHELL", 0.6, 3.95, 1.0, 0.3)
	line("BATCH 14 → FAILED", 2.0, 6.6, 1.8, 0.35, -2)
	line("BATCH 15 ?", 2.0, 6.1, 1.2, 0.35, 1)
	line("X X X X X X X", 2.0, 4.6, 1.6, 0.3)
	-- the growth curve itself: a few marker strokes
	local stroke = look(M.SmoothPlastic, 40, 60, 90)
	local points = {
		V(-2.7, 4.3, 0),
		V(-1.9, 4.45, 0),
		V(-1.2, 4.9, 0),
		V(-0.4, 5.7, 0),
		V(0.3, 6.15, 0),
		V(1.0, 6.3, 0),
	}
	for i = 1, #points - 1 do
		local a = (board.CFrame * CF(-points[i].X, points[i].Y - 5.25, -0.02)).Position
		local b = (board.CFrame * CF(-points[i + 1].X, points[i + 1].Y - 5.25, -0.02)).Position
		rod(model, "Stroke", a, b, 0.04, stroke)
	end
	for _, x in { -1.4, -0.1 } do
		add("PhaseMark", V(0.03, 2.4, 0.01), CF(-x, 5.3, -0.115), stroke)
	end
	add("Tray", V(5, 0.1, 0.3), CF(0, 3.45, -0.2), look(M.Metal, 150, 150, 146))
	add("Marker", V(0.6, 0.08, 0.08), CF(1.2, 3.55, -0.22), look(M.Plastic, 30, 40, 80), CYL)
	return model
end

-- Five cardboard boxes of supplies (one open with coiled tubing).
function AptProps.supplyBoxes(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "SupplyBoxes", at)
	local card = look(M.Cardboard, 150, 118, 82)
	local specs = {
		{ size = V(1.8, 1.4, 1.5), at = CF(-0.9, 0.7, 0.4), label = "TUBING" },
		{ size = V(1.5, 1.1, 1.3), at = CF(-0.8, 1.95, 0.45), label = "FILTERS" },
		{ size = V(1.6, 1.6, 1.4), at = CF(1.0, 0.8, 0.5), label = "SPARE PUMPS" },
		{ size = V(1.2, 0.9, 1.0), at = CF(1.1, 2.05, 0.4), label = "SEALS" },
		{ size = V(1.4, 1.0, 1.2), at = CF(0.4, 0.5, -1.2), label = "" },
	}
	for i, spec in specs do
		local box =
			add("Box", spec.size, spec.at * ANG(0, jitterAngle(rng, 2, 9), 0), tint(card, rng))
		if spec.label ~= "" then
			writeOn(box, Enum.NormalId.Front, spec.label, INK)
		end
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
	add("Tape", V(1.82, 0.05, 0.3), CF(-0.9, 1.41, 0.4), TAPE)
	return model
end

-- A paper calendar taped on a wall, days crossed out.
function AptProps.calendar(parent: Instance, at: CFrame, _rng: Random): Model
	local model, add = begin(parent, "Calendar", at)
	local page = add("Page", V(1.4, 1.8, 0.02), CF(0, 5.5, -0.02) * ANG(0, 0, rad(-2)), PAPER)
	writeOn(
		page,
		Enum.NormalId.Front,
		"X X X X X X X\nX X X X X X X\nX X X . . . .",
		Color3.fromRGB(40, 40, 46),
		Enum.Font.PermanentMarker,
		40
	)
	add("Tape", V(0.4, 0.12, 0.022), CF(0, 6.4, -0.025), TAPE)
	return model
end

-- A black rubbish bag, tied (two lumpy parts).
function AptProps.trashBag(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "TrashBag", at)
	local bag = look(M.Plastic, 26, 26, 28, 0, 0.05)
	add("Bag", V(1.4, 1.5, 1.3), CF(0, 0.7, 0) * ANG(0, jitterAngle(rng), rad(6)), bag, BALL)
	add("Bag", V(1.0, 0.9, 1.0), CF(0.3, 1.3, 0.1), bag, BALL)
	add("Knot", V(0.3, 0.4, 0.3), CF(0.3, 1.8, 0.1), bag)
	return model
end

------------------------------------------------------------------------------
-- THE LAB (the converted back bedroom)
------------------------------------------------------------------------------

-- The plastic tent: battens on the walls and ceiling, clear sheets hung off the walls (each
-- one turned a little: they sag), taped seams, sagging ceiling bays. Built in flat-local
-- coordinates through `toWorld` (the lab's interior: X 10..28, Z 0..24, ceiling 11).
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
	-- wall battens along the top of the N, E and S walls
	add("Batten", V(18, 0.2, 0.2), CF(19, 10.6, 23.7), batten)
	add("Batten", V(0.2, 0.2, 24), CF(27.75, 10.6, 12), batten)
	add("Batten", V(18, 0.2, 0.2), CF(19, 10.6, 0.55), batten)
	-- ceiling battens every 3 studs (across the room, along Z)
	for x = 11.5, 27, 3 do
		add("Batten", V(0.2, 0.2, 24), CF(x, 10.85, 12), batten)
	end
	-- sheets: N wall (Z 23.7, X 10..28), E wall (X 27.85, Z 0..24), S wall (Z 0.6, around the window)
	local function sheet(centre: Vector3, width: number, height: number, alongX: boolean): Part
		local sag = ANG(
			rad(rng:NextNumber(0.5, 1.5)) * (if rng:NextNumber() < 0.5 then -1 else 1),
			0,
			rad(rng:NextNumber(-0.6, 0.6))
		)
		local size = if alongX then V(width, height, 0.03) else V(0.03, height, width)
		local sheetLook = tint(SHEET, rng, 4)
		if rng:NextNumber() < 0.35 then
			-- an older sheet: yellowed / greyed by months of damp
			sheetLook.color = sheetLook.color:Lerp(Color3.fromRGB(150, 150, 128), 0.45)
			sheetLook.transparency = 0.5
		end
		local sheetPart = add("Sheet", size, CF(centre) * sag, sheetLook)
		sheetPart.CastShadow = false
		if rng:NextNumber() < 0.3 then
			-- a grime smear low on the sheet (hands, splashes)
			local smear = part(
				model,
				"Grime",
				if alongX
					then V(rng:NextNumber(0.8, 1.6), rng:NextNumber(0.6, 1.4), 0.01)
					else V(0.01, rng:NextNumber(0.6, 1.4), rng:NextNumber(0.8, 1.6)),
				sheetPart.CFrame * CF(0, -height / 2 + rng:NextNumber(1.2, 3), 0) * ANG(0, 0, 0),
				look(M.SmoothPlastic, 96, 100, 88, 0.55)
			)
			smear.CastShadow = false
		end
		return sheetPart
	end
	for i = 0, 5 do
		local made = sheet(V(11.5 + i * 3, 5.3, 23.72 - rng:NextNumber(0, 0.15)), 3.1, 10.5, true)
		if i == 4 then
			table.insert(swayable, made)
		end
	end
	for i = 0, 7 do
		local made = sheet(V(27.88 - rng:NextNumber(0, 0.06), 5.3, 1.5 + i * 3), 3.1, 10.5, false)
		if i == 1 then
			table.insert(swayable, made)
		end
	end
	-- the S wall: full sheets left and right of the window, a short one above it
	-- (the two W-most sheets have torn off their batten: only their lower part is still taped
	-- up, and the old bedroom wallpaper shows above them; see AptProps.bedroomLeftovers)
	for _, x in { 11.5, 14.5 } do
		sheet(V(x, 3.0, 0.6 + rng:NextNumber(0, 0.12)), 3.1, 6.0, true)
	end
	for _, x in { 23.5, 26.5 } do
		local made = sheet(V(x, 5.3, 0.6 + rng:NextNumber(0, 0.12)), 3.1, 10.5, true)
		if x == 23.5 then
			table.insert(swayable, made)
		end
	end
	sheet(V(19, 9.3, 0.6), 6.4, 3.0, true)
	-- the sheets that close the "airlock" by the door (W side, next to the strip curtain)
	sheet(V(11.4, 5.4, 18.2), 1.4, 10.8, false)
	sheet(V(11.4, 5.4, 11.0), 2.8, 10.8, false)
	-- taped seams (vertical strips on a few joins)
	for _, x in { 13, 19, 25 } do
		add("SeamTape", V(0.3, 10.2, 0.02), CF(x, 5.3, 23.66), TAPE)
	end
	for _, z in { 6, 12, 18 } do
		add("SeamTape", V(0.02, 10.2, 0.3), CF(27.8, 5.3, z), TAPE)
	end
	-- the ceiling: every 3-stud bay sags between its battens (two panels forming a V)
	for x = 11.5, 25, 3 do
		local depth = rng:NextNumber(0.2, 0.35)
		-- (one sheet per bay, hanging lower than the battens and a little skewed: it sags)
		local panel = add(
			"CeilingSheet",
			V(3.05, 0.03, 23.6),
			CF(x + 1.5, 10.8 - depth, 12)
				* ANG(rad(rng:NextNumber(-0.4, 0.4)), 0, rad(rng:NextNumber(-2, 2))),
			tint(SHEET, rng, 4)
		)
		panel.CastShadow = false
	end
	return model, swayable
end

-- What is left of the bedroom the lab used to be (so the room reads "a converted bedroom",
-- not a storeroom): the old wallpaper and a poster ghost where the sheeting tore off the S wall,
-- the torn sheet folded on the floor, the bed's headboard leaning on the E wall, a dusty
-- lampshade above the ceiling sheets (a silhouette through the plastic). The carpet band is
-- in LabBuilder (floors). `toWorld`: the flat's local frame → world.
function AptProps.bedroomLeftovers(
	parent: Instance,
	toWorld: (CFrame) -> CFrame,
	rng: Random
): Model
	local model = Instance.new("Model")
	model.Name = "BedroomLeftovers"
	model.Parent = parent
	local function add(
		name: string,
		size: Vector3,
		localCf: CFrame,
		l: Look,
		shape: Enum.PartType?
	): Part
		return part(model, name, size, toWorld(localCf), l, shape)
	end
	-- the old wallpaper (3 strips, two tones) above the torn sheets, S wall (face at Z 0.25)
	local paper = { look(M.Fabric, 150, 132, 108), look(M.Fabric, 138, 120, 98) }
	for i = 0, 2 do
		add(
			"OldWallpaper",
			V(1.95, 4.6, 0.02),
			CF(11.25 + i * 1.95, 8.3, 0.27),
			tint(paper[i % 2 + 1], rng, 4)
		)
	end
	-- a paler rectangle where a poster hung for years, and the 4 bits of tape it left
	add("PosterGhost", V(1.8, 2.6, 0.01), CF(13.1, 8.2, 0.29), look(M.Fabric, 160, 146, 122))
	for _, corner in { V(-0.8, 1.2, 0), V(0.8, 1.2, 0), V(-0.8, -1.2, 0), V(0.8, -1.2, 0) } do
		add(
			"PosterTape",
			V(0.28, 0.12, 0.01),
			CF(13.1 + corner.X, 8.2 + corner.Y, 0.3) * ANG(0, 0, jitterAngle(rng, 10, 35)),
			look(M.Fabric, 176, 168, 136)
		)
	end
	-- the torn sheet, folded and dropped on the floor
	local fold = add(
		"FallenSheet",
		V(2.5, 0.15, 1.6),
		CF(16.4, 0.12, 2.5) * ANG(0, rad(rng:NextNumber(8, 16)), rad(2)),
		look(M.Glass, 196, 204, 200, 0.5)
	)
	fold.CastShadow = false
	-- the bed's old headboard, stood on its end against the E wall, leaning 10 degrees
	local wood = tint(look(M.Wood, 110, 84, 60), rng, 5)
	local lean = ANG(0, 0, rad(-10))
	add("Headboard", V(0.25, 4.0, 5.0), CF(27.45, 2.05, 5.3) * lean, solid(wood))
	for _, z in { 2.75, 7.85 } do
		add("HeadboardPost", V(0.35, 4.4, 0.35), CF(27.42, 2.2, z) * lean, wood)
	end
	-- a dusty fabric drum shade above the ceiling sheeting (unlit)
	add(
		"OldLampshade",
		V(0.36, 1.6, 1.6),
		CF(13, 10.8, 18) * UP,
		look(M.Fabric, 150, 132, 104),
		CYL
	)
	return model
end

-- The strip curtain at the lab entrance (an Anim model: its strips are its children; V parts
-- them when the player walks through). `at`: the rail's centre at the floor (local X = along the
-- rail), strips hang from y 8 down to 0.2.
function AptProps.stripCurtain(parent: Instance, at: CFrame, rng: Random, strips: number): Model
	local model = Instance.new("Model")
	model.Name = "Curtain"
	local width = 0.62
	local span = strips * width - (strips - 1) * 0.05
	part(model, "Rail", V(span + 0.4, 0.15, 0.2), at * CF(0, 8.1, 0), look(M.Metal, 150, 150, 146))
	for i = 1, strips do
		local x = -span / 2 + width / 2 + (i - 1) * (width - 0.05)
		local strip = part(
			model,
			"Strip",
			V(width, 7.8, 0.03),
			at * CF(x, 4.1, (i % 2) * 0.03) * ANG(rad(rng:NextNumber(-0.8, 0.8)), 0, 0),
			look(M.Glass, 205, 215, 212, 0.55)
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

-- The salvaged steel frame round the vat (posts, rails, corroded joints), a drip tray, a step
-- stool, the vat screen's bracket. `at`: the vat's centre on the floor.
function AptProps.vatFrame(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "VatFrame", at)
	local steel = tint(look(M.Metal, 96, 98, 100), rng)
	add("DripTray", V(5.6, 0.15, 5.6), CF(0, 0.075, 0), solid(look(M.Metal, 80, 82, 82)))
	add("TrayWater", V(5.2, 0.02, 5.2), CF(0, 0.16, 0), look(M.Glass, 150, 196, 190, 0.5, 0.1))
	for _, x in { -2.9, 2.9 } do
		for _, z in { -2.9, 2.9 } do
			add("Post", V(0.3, 9.9, 0.3), CF(x, 4.95, z), solid(steel))
			add("Joint", V(0.45, 0.45, 0.45), CF(x, 1.2, z), RUST)
		end
	end
	for _, y in { 1.2, 9.7 } do
		for _, offset in { -2.9, 2.9 } do
			add("Rail", V(5.8, 0.22, 0.22), CF(0, y, offset), steel)
			add("Rail", V(0.22, 0.22, 5.8), CF(offset, y, 0), steel)
		end
	end
	-- a diagonal brace (welded on later, another colour)
	add(
		"Brace",
		V(0.18, 8.0, 0.18),
		CF(2.9, 5.4, 0) * ANG(rad(36), 0, 0),
		look(M.Metal, 120, 110, 96)
	)
	-- the bracket that holds the vat screen in front
	-- (behind the screen: the screen itself is the VatScreen part, just in front)
	add("ScreenBracket", V(1.9, 1.3, 0.08), CF(0, 2.4, -2.38), look(M.Metal, 70, 72, 74))
	add("ScreenArm", V(0.15, 0.15, 0.5), CF(0, 2.4, -2.1), steel)
	-- a step stool at the front
	local stool = look(M.Plastic, 180, 170, 140)
	add("StoolTop", V(1.6, 0.15, 1.0), CF(0.9, 1.0, -3.7), solid(stool))
	add("StoolTop", V(1.6, 0.15, 0.8), CF(0.9, 0.5, -4.3), stool)
	for _, x in { 0.2, 1.6 } do
		add("StoolLeg", V(0.12, 1.0, 1.8), CF(x, 0.5, -3.9) * ANG(rad(6), 0, 0), stool)
	end
	-- tape label on a post: the fill date
	local label =
		add("Label", V(0.31, 0.5, 0.31), CF(-2.9, 6.0, -2.9), look(M.Fabric, 200, 196, 170))
	writeOn(label, Enum.NormalId.Front, "FILL 14/11", INK, Enum.Font.PermanentMarker, 80)
	return model
end

-- The pump shelf: a wire shelf, three aquarium air pumps (different sizes and colours), the
-- buffer tank (a small aquarium with teal water and gravel). `at`: the shelf's centre on the
-- floor, local -Z = out of the wall. 3.6 wide, 2 deep.
function AptProps.pumpShelf(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "PumpShelf", at)
	local wire = look(M.Metal, 170, 172, 174)
	for _, x in { -1.75, 1.75 } do
		for _, z in { -0.95, 0.95 } do
			add("Upright", V(0.1, 7.2, 0.1), CF(x, 3.6, z), wire)
		end
	end
	for _, y in { 1.0, 3.2, 5.4 } do
		add("WireShelf", V(3.6, 0.08, 2.0), CF(0, y, 0), wire)
	end
	-- three pumps on the middle shelf
	local pumps = {
		{ size = V(0.9, 0.5, 0.6), color = look(M.Plastic, 40, 44, 48), x = -1.1 },
		{ size = V(0.7, 0.4, 0.5), color = look(M.Plastic, 200, 196, 186), x = 0.1 },
		{ size = V(1.1, 0.6, 0.7), color = look(M.Plastic, 70, 90, 100), x = 1.15 },
	}
	for i, pump in pumps do
		local body = add(
			"Pump",
			pump.size,
			CF(pump.x, 3.24 + pump.size.Y / 2, 0.1) * ANG(0, jitterAngle(rng, 2, 10), 0),
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
	add("Rag", V(0.8, 0.06, 0.6), CF(0.1, 3.26, 0.1), look(M.Fabric, 150, 140, 110))
	-- the buffer tank on the top shelf
	add("TankBase", V(2.5, 0.12, 1.3), CF(0, 5.5, 0), look(M.Plastic, 30, 30, 30))
	add("TankGlass", V(2.4, 1.5, 1.2), CF(0, 6.3, 0), look(M.Glass, 190, 220, 216, 0.6))
	add("TankWater", V(2.3, 1.2, 1.1), CF(0, 6.18, 0), look(M.Glass, 90, 170, 160, 0.45))
	add("Gravel", V(2.3, 0.2, 1.1), CF(0, 5.66, 0), look(M.Pebble, 120, 116, 104))
	add(
		"TankLid",
		V(2.44, 0.08, 1.24),
		CF(0, 7.08, 0.05) * ANG(rad(-2), 0, 0),
		look(M.Plastic, 40, 40, 40)
	)
	add("AirStone", V(0.4, 0.12, 0.12), CF(0, 5.82, 0), look(M.Concrete, 120, 110, 100), CYL)
	return model
end

-- The stash: a salvaged glass-lid shop freezer (yellowed, rust at the base, an open padlock, a
-- digital thermometer taped on, frost under the lid). `at`: its centre on the floor, local -Z =
-- its front (where the player stands). 2.2 deep (local Z), 4.6 long (local X), 3 high.
function AptProps.stashFreezer(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "StashFreezer", at)
	local shell = solid(tint(look(M.SmoothPlastic, 176, 180, 172), rng))
	add("Bottom", V(4.6, 0.6, 2.2), CF(0, 0.3, 0), shell)
	for _, z in { -1.05, 1.05 } do
		add("Wall", V(4.6, 2.4, 0.1), CF(0, 1.8, z), shell)
	end
	for _, x in { -2.25, 2.25 } do
		add("End", V(0.1, 2.4, 2.2), CF(x, 1.8, 0), shell)
	end
	add("Liner", V(4.4, 0.04, 2.0), CF(0, 2.15, 0), look(M.SmoothPlastic, 190, 200, 204))
	add("RustBase", V(4.62, 0.4, 2.22), CF(0, 0.2, 0), RUST)
	-- an old brand sticker, half scraped off (two torn pieces)
	add("Sticker", V(1.1, 0.7, 0.01), CF(1.2, 1.5, -1.06), look(M.SmoothPlastic, 120, 150, 160))
	add(
		"Sticker",
		V(0.5, 0.35, 0.01),
		CF(1.75, 1.25, -1.06) * ANG(0, 0, rad(-14)),
		look(M.SmoothPlastic, 132, 150, 150)
	)
	-- the sliding glass lids (two, one slid a little open), the frost rim
	local frame = look(M.Plastic, 160, 156, 146)
	add("LidFrame", V(4.6, 0.1, 2.2), CF(0, 3.0, 0), frame)
	add("Lid", V(2.2, 0.04, 1.95), CF(-1.1, 3.03, 0), look(M.Glass, 200, 220, 222, 0.55))
	add("Lid", V(2.2, 0.04, 1.95), CF(0.95, 3.08, 0), look(M.Glass, 200, 220, 222, 0.55))
	add("Frost", V(4.4, 0.05, 0.12), CF(0, 2.93, -0.95), look(M.Ice, 220, 235, 240, 0.2))
	add("Frost", V(4.4, 0.05, 0.12), CF(0, 2.93, 0.95), look(M.Ice, 220, 235, 240, 0.3))
	-- the open padlock hanging off its hasp
	add("Hasp", V(0.5, 0.15, 0.08), CF(0, 2.8, -1.12), look(M.Metal, 120, 118, 110))
	add(
		"Padlock",
		V(0.3, 0.38, 0.14),
		CF(0.1, 2.45, -1.15) * ANG(0, 0, rad(20)),
		look(M.Metal, 140, 136, 122)
	)
	-- the cheap thermometer taped on the front: -18.4
	add("Thermometer", V(0.8, 0.45, 0.05), CF(-1.4, 2.2, -1.12), look(M.Plastic, 220, 220, 214))
	local display = add(
		"ThermoDisplay",
		V(0.6, 0.25, 0.01),
		CF(-1.4, 2.22, -1.15),
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
	add("Tape", V(0.95, 0.12, 0.06), CF(-1.4, 2.47, -1.13), TAPE)
	-- condensation drips running down the front
	for i = 1, 2 do
		add(
			"Streak",
			V(0.06, rng:NextNumber(0.5, 1.2), 0.01),
			CF(0.6 + i * 0.4, 2.3, -1.105),
			look(M.SmoothPlastic, 186, 184, 170)
		)
	end
	return model
end

-- The lab's old fridge (a different model from the kitchen one: rounded top, chrome handle),
-- locked with a bicycle cable lock, two taped notes. Front = local -Z.
function AptProps.labFridge(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "LabFridge", at)
	local shell = solid(tint(look(M.SmoothPlastic, 196, 182, 148), rng)) -- (old almond enamel)
	add("Body", V(2.2, 5.0, 1.9), CF(0, 2.5, 0), shell)
	-- (a 1950s-style rounded top: a cylinder lying along X)
	add("RoundTop", V(2.2, 1.9, 1.9), CF(0, 5.0, 0), shell, CYL)
	add("DoorLine", V(2.0, 0.03, 0.02), CF(0, 4.0, -0.96), look(M.SmoothPlastic, 120, 118, 106))
	add("Handle", V(0.15, 1.0, 0.18), CF(0.85, 3.2, -1.05), look(M.Metal, 200, 202, 206))
	add("RustBase", V(2.22, 0.3, 1.92), CF(0, 0.15, 0), RUST)
	-- the cable lock: a loop round the body, its lock body
	local cable = look(M.Rubber, 30, 32, 30)
	add("Cable", V(2.35, 0.1, 0.1), CF(0, 3.5, -1.02), cable)
	add("Cable", V(0.1, 0.1, 2.0), CF(1.15, 3.5, 0), cable)
	add("Cable", V(0.1, 0.1, 2.0), CF(-1.15, 3.5, 0), cable)
	add("LockBody", V(0.3, 0.45, 0.2), CF(0.3, 3.3, -1.1), look(M.Metal, 60, 60, 60))
	for i, text in { "DO NOT UNPLUG", "pH 7.2 OK" } do
		local note = add(
			"Note",
			V(0.9, 0.7, 0.01),
			CF(-0.5 + (i - 1) * 0.3, 4.5 - (i - 1) * 0.9, -0.955)
				* ANG(0, 0, jitterAngle(rng, 2, 6)),
			tint(PAPER, rng, 6)
		)
		writeOn(note, Enum.NormalId.Front, text, INK)
	end
	return model
end

-- The extraction bench: a salvaged hospital trolley (steel top with a lip, lower shelf with gauze
-- rolls, a spray bottle, tape; legs, castors). `at`: the TOP's centre at floor level (the top
-- sits at y 3.2). Its top must stay clear (Extraction uses it).
function AptProps.trolleyBench(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "TrolleyBench", at)
	-- (dull, scratched steel: years of use, never a shiny clinic top)
	local worn = look(M.Metal, 122, 124, 120, 0, 0.05)
	add("Top", V(7, 0.3, 3), CF(0, 3.2, 0), solid(worn))
	-- (the lip stays outside the top's 7 x 3 so the shell lies flat)
	for _, z in { -1.55, 1.55 } do
		add("Lip", V(7.1, 0.1, 0.1), CF(0, 3.35, z), worn)
	end
	for _, x in { -3.45, 3.45 } do
		add("Lip", V(0.1, 0.1, 3.2), CF(x, 3.35, 0), worn)
	end
	-- scuffs and dried water rings on the top (flat overlays: the top stays clear)
	for _, spot in { V(2.4, 0, -0.9), V(-2.7, 0, 0.8), V(2.9, 0, 0.6) } do
		add(
			"Scuff",
			V(rng:NextNumber(0.7, 1.3), 0.004, rng:NextNumber(0.4, 0.8)),
			CF(spot.X, 3.352, spot.Z) * ANG(0, rng:NextNumber(0, math.pi), 0),
			look(M.Metal, 98, 100, 96)
		)
	end
	-- a strip of grey duct tape mending the near lip
	add("LipTape", V(0.9, 0.14, 0.14), CF(-1.6, 3.35, -1.55), TAPE)
	-- a blue disposable underpad under the shell, one corner folded back (paler underside)
	add(
		"Underpad",
		V(3.2, 0.02, 2.2),
		CF(-0.4, 3.36, -0.05) * ANG(0, rad(3), 0),
		look(M.Fabric, 104, 132, 150)
	)
	add(
		"UnderpadFold",
		V(0.7, 0.02, 0.7),
		CF(-1.75, 3.38, -0.9) * ANG(0, rad(45), 0),
		look(M.Fabric, 150, 156, 158)
	)
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
	add("Shelf", V(6.8, 0.1, 2.8), CF(0, 1.2, 0), frame)
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
	add("SprayHead", V(0.3, 0.25, 0.4), CF(0.6, 2.25, -0.25), look(M.Plastic, 60, 150, 150))
	add("TapeRoll", V(0.2, 0.5, 0.5), CF(1.6, 1.36, 0.3) * UP, TAPE, CYL)
	add(
		"Towel",
		V(1.4, 0.25, 1.0),
		CF(2.6, 1.37, 0) * ANG(0, rad(8), 0),
		look(M.Fabric, 150, 170, 170)
	)
	-- the power strip under the trolley (the charger's cord ends there)
	add("UnderStrip", V(1.6, 0.25, 0.4), CF(2.5, 0.15, 0.9), look(M.Plastic, 220, 216, 204))
	return model
end

-- The cutter's charger dock on the trolley (a beige box with a slot and the LED "ChargerLed";
-- LabBuilder moves ChargerLed to the model's root). `at` = CutterDock (the box sits on it).
function AptProps.cutterCharger(parent: Instance, at: CFrame, _rng: Random, cordEnd: Vector3): Model
	local model, add = begin(parent, "CutterCharger", at)
	add("Box", V(0.8, 0.4, 0.6), CF(0, 0.05, 0), look(M.Plastic, 196, 184, 150))
	add("Slot", V(0.5, 0.02, 0.2), CF(0, 0.26, 0.05), look(M.Plastic, 30, 30, 30))
	add("ChargerLed", V(0.1, 0.06, 0.04), CF(0.25, 0.12, -0.31), look(M.Neon, 120, 220, 120))
	local cordStart = (at * CF(-0.4, -0.05, 0.25)).Position
	-- the coiled cord down to the strip under the trolley (6 dark segments)
	path(model, "ChargerCord", {
		cordStart,
		cordStart + V(-0.2, -0.1, 0.25),
		cordStart + V(-0.25, -0.9, 0.45),
		cordStart + V(-0.15, -1.8, 0.4),
		cordEnd + V(0, 0.6, 0),
		cordEnd,
	}, 0.08, CORD_BLACK)
	return model
end

-- An upturned plastic crate with a small boxy CRT on it. Its glass is "ScanScreen" (moved to
-- the model's root by LabBuilder). `at`: the crate's centre on the floor, local -Z = the screen
-- side.
function AptProps.scanCrate(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "ScanCrate", at)
	add("Crate", V(1.6, 2.4, 2.0), CF(0, 1.2, 0), solid(tint(look(M.Plastic, 52, 70, 84), rng)))
	for _, y in { 0.6, 1.2, 1.8 } do
		add("CrateSlot", V(1.62, 0.15, 1.6), CF(0, y, 0), look(M.Plastic, 30, 40, 48))
	end
	add("Crt", V(1.6, 1.6, 1.5), CF(0, 3.2, -0.25), look(M.Plastic, 176, 170, 156))
	add("CrtBack", V(1.1, 1.1, 0.6), CF(0, 3.15, 0.75), look(M.Plastic, 160, 154, 140))
	add("ScanScreen", V(1.3, 1.0, 0.05), CF(0, 3.45, -1.03), look(M.Glass, 14, 22, 20, 0, 0.1))
	add("Bezel", V(1.45, 0.25, 0.04), CF(0, 2.75, -1.01), look(M.Plastic, 150, 144, 130))
	add("CrtCord", V(0.08, 0.08, 1.2), CF(0.5, 2.5, 1.0), CORD_BLACK)
	return model
end

-- The salvaged clamp work lamp: a weighted base, two arm segments, the head "LampHead" (moved to
-- the model's root by LabBuilder, its SpotLight is added there). `base`, `head`: world points.
function AptProps.lampStand(parent: Instance, base: Vector3, head: Vector3, _rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "LampStand"
	model.Parent = parent
	local dark = look(M.Metal, 60, 62, 64)
	part(model, "Base", V(0.4, 1.6, 1.6), CF(base + V(0, 0.2, 0)) * UP, solid(dark), CYL)
	local elbow = base + V(0, 6.6, 0)
	rod(model, "Pole", base + V(0, 0.3, 0), elbow, 0.2, dark)
	rod(model, "Arm", elbow, head + V(0, 0.55, 0), 0.16, look(M.Metal, 70, 72, 74))
	part(model, "Knob", V(0.35, 0.35, 0.35), CF(elbow), look(M.Metal, 40, 40, 40), BALL)
	-- a dented conical metal shade (old workshop lamp): the wide mouth is LampHead, a narrow
	-- neck above it, a corroded rim, one dent
	part(model, "LampHead", V(0.45, 1.0, 1.0), CF(head) * UP, look(M.Metal, 120, 124, 126), CYL)
	part(
		model,
		"LampNeck",
		V(0.3, 0.55, 0.55),
		CF(head + V(0, 0.36, 0)) * UP,
		look(M.Metal, 110, 114, 116),
		CYL
	)
	part(
		model,
		"LampRim",
		V(0.07, 1.06, 1.06),
		CF(head - V(0, 0.2, 0)) * UP,
		look(M.CorrodedMetal, 104, 92, 78),
		CYL
	)
	part(
		model,
		"LampDent",
		V(0.22, 0.3, 0.08),
		CF(head + V(0.3, 0.02, -0.38)) * ANG(rad(12), rad(35), 0),
		look(M.Metal, 92, 96, 98)
	)
	part(
		model,
		"LampLens",
		V(0.02, 0.85, 0.85),
		CF(head - V(0, 0.245, 0)) * UP,
		look(M.Neon, 255, 236, 210, 0.45),
		CYL
	)
	-- its cord dropping down the pole
	path(model, "LampCord", {
		head + V(0.2, 0.5, 0),
		elbow + V(0.15, -0.1, 0.1),
		base + V(0.4, 0.1, 0.4),
		base + V(1.6, 0.05, -0.5),
	}, 0.07, CORD_BLACK)
	return model
end

-- The chute: a hacked waste hatch in the E wall (plywood frame, a metal flap held UP by a
-- bungee, rubber gasket, a hand-painted "IN"). `at` = ChuteMouth (LookVector = into the wall).
function AptProps.chuteHatch(parent: Instance, at: CFrame, _rng: Random): Model
	-- (in the mouth's frame: local -Z = into the wall, +X = sideways, +Y = up)
	-- The opening is 3.0 wide x 2.8 tall (a waste hatch, not a doorway), centred on the mouth.
	local model, add = begin(parent, "ChuteHatch", at)
	local ply = look(M.WoodPlanks, 150, 120, 84)
	add("FrameTop", V(3.8, 0.4, 0.5), CF(0, 1.6, -0.35), ply)
	add("FrameBottom", V(3.8, 0.3, 0.5), CF(0, -1.55, -0.35), ply)
	for _, x in { -1.7, 1.7 } do
		add("FrameSide", V(0.4, 3.5, 0.5), CF(x, 0.0, -0.35), ply)
	end
	add("ChuteDark", V(3.0, 2.8, 0.05), CF(0, 0.0, -0.56), look(M.SmoothPlastic, 0, 0, 0))
	-- the boxed duct's inner sides (plywood, darker), so the hole has depth
	for _, x in { -1.46, 1.46 } do
		add("DuctSide", V(0.08, 2.8, 0.5), CF(x, 0.0, -0.35), look(M.WoodPlanks, 70, 56, 40))
	end
	add("DuctFloor", V(2.9, 0.08, 0.5), CF(0, -1.36, -0.35), look(M.Metal, 70, 70, 68))
	-- rubber gasket strips round the opening
	add("Gasket", V(3.0, 0.1, 0.12), CF(0, 1.37, -0.12), look(M.Rubber, 40, 42, 40))
	add("Gasket", V(3.0, 0.1, 0.12), CF(0, -1.37, -0.12), look(M.Rubber, 40, 42, 40))
	-- the flap: hinged at the TOP, hanging open 20 degrees into the room
	add(
		"ChuteFlap",
		V(2.9, 2.7, 0.08),
		CF(0, 1.4, 0.05) * ANG(rad(-20), 0, 0) * CF(0, -1.35, 0),
		look(M.Metal, 120, 122, 120)
	)
	add("Hinge", V(2.4, 0.12, 0.12), CF(0, 1.4, 0.05), look(M.Metal, 60, 60, 60), CYL)
	local sign =
		add("Sign", V(0.6, 0.2, 0.01), CF(0, 1.95, 0.07), look(M.WoodPlanks, 150, 120, 84, 1))
	writeOn(
		sign,
		Enum.NormalId.Back,
		"IN",
		Color3.fromRGB(220, 220, 210),
		Enum.Font.PermanentMarker,
		80
	)
	return model
end

-- The work surface: an old interior door laid on two trestles; on it the CRT station (its glass
-- "MonitorScreen" is moved to the model's root), a keyboard with missing keys, a webcam on
-- books, the home-made warm box, a mug of pens, taped notes on the sheeting above.
-- `at`: the door-top's centre at floor level, local -Z = out of the wall (the door is 7.5 long
-- along local X, 2.8 deep).
function AptProps.trestleTable(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "TrestleTable", at)
	local doorLook = tint(look(M.Wood, 120, 104, 84), rng)
	add("DoorTop", V(7.5, 0.18, 2.8), CF(0, 3.0, 0), solid(doorLook))
	add("KnobHole", V(0.02, 0.35, 0.35), CF(3.4, 3.1, -0.9) * UP, look(M.Wood, 30, 26, 20), CYL)
	local trestle = look(M.Wood, 150, 120, 84)
	for _, x in { -2.8, 2.8 } do
		add("TrestleBar", V(0.25, 0.25, 2.6), CF(x, 2.8, 0), trestle)
		for _, z in { -1.0, 1.0 } do
			add(
				"TrestleLeg",
				V(0.2, 2.9, 0.2),
				CF(x, 1.4, z * 0.85) * ANG(rad(z * -10), 0, 0),
				trestle
			)
		end
	end
	-- the CRT station (screen faces local -Z)
	add("Books", V(2.0, 0.3, 1.0), CF(0.4, 3.24, 1.0), look(M.Cardboard, 120, 60, 50))
	add(
		"Books",
		V(1.8, 0.25, 0.9),
		CF(0.45, 3.5, 1.02) * ANG(0, rad(4), 0),
		look(M.Cardboard, 60, 80, 70)
	)
	add("Monitor", V(2.4, 2.1, 0.95), CF(0.4, 4.6, 1.2), look(M.Plastic, 180, 174, 160))
	add("MonitorScreen", V(1.8, 1.4, 0.05), CF(0.4, 4.55, 0.7), look(M.Glass, 8, 18, 14, 0, 0.1))
	-- keyboard with four missing keys
	local keyboard = add(
		"Keyboard",
		V(1.9, 0.1, 0.7),
		CF(0.4, 3.14, -0.8) * ANG(0, rad(-4), 0),
		look(M.Plastic, 196, 190, 176)
	)
	part(
		model,
		"MissingKey",
		V(0.14, 0.02, 0.14),
		keyboard.CFrame * CF(-0.39, 0.05, 0.1),
		look(M.Plastic, 40, 40, 40)
	)
	-- a webcam on a stack of books
	add("BookStack", V(0.9, 0.6, 0.7), CF(-1.2, 3.4, 0.5), look(M.Cardboard, 90, 70, 110))
	add("Webcam", V(0.35, 0.3, 0.3), CF(-1.2, 3.85, 0.5), look(M.Plastic, 40, 40, 44), BALL)
	add(
		"WebcamLens",
		V(0.02, 0.12, 0.12),
		CF(-1.2, 3.85, 0.34) * ALONG_Z,
		look(M.Glass, 20, 30, 40),
		CYL
	)
	-- the warm box: a cooler box with a round hole, a clamp-lamp shade over it (no light), a
	-- taped thermostat reading 37.0
	add("WarmBox", V(2.0, 1.2, 1.2), CF(-2.6, 3.7, 0.1), look(M.Plastic, 70, 120, 140))
	add("WarmLid", V(2.05, 0.15, 1.25), CF(-2.6, 4.37, 0.1), look(M.Plastic, 196, 190, 170))
	add("LidHole", V(0.02, 0.6, 0.6), CF(-2.6, 4.45, 0.1) * UP, look(M.Plastic, 20, 20, 20), CYL)
	add("ClampShade", V(0.6, 0.7, 0.7), CF(-2.6, 5.2, 0.1) * UP, look(M.Metal, 160, 150, 130), CYL)
	add(
		"ClampArm",
		V(0.08, 1.0, 0.08),
		CF(-2.2, 4.8, 0.1) * ANG(0, 0, rad(30)),
		look(M.Metal, 60, 60, 60)
	)
	add("Thermostat", V(0.5, 0.35, 0.05), CF(-2.6, 3.75, -0.53), look(M.Plastic, 220, 220, 214))
	local reading = add(
		"ThermostatDisplay",
		V(0.4, 0.2, 0.01),
		CF(-2.6, 3.77, -0.56),
		look(M.SmoothPlastic, 30, 30, 28)
	)
	writeOn(reading, Enum.NormalId.Front, "37.0", Color3.fromRGB(255, 170, 70), Enum.Font.Code, 120)
	-- a mug of pens
	add(
		"PenMug",
		V(0.45, 0.35, 0.35),
		CF(2.2, 3.32, -0.3) * UP,
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
	-- taped notes on the sheeting above (each turned a little)
	local notes = {
		"pump 2 rattles",
		"batch 14 → failed",
		"change filters FRI",
		"-18 MIN",
	}
	for i, text in notes do
		local col = (i - 1) % 2 + (i - 1) // 2 * 0.5
		local row = (i - 1) // 2
		local note = add(
			"Note",
			V(0.9, 0.7, 0.01),
			CF(-2.2 + col * 1.6 + rng:NextNumber(-0.2, 0.2), 6.6 - row * 1.0, 1.62)
				* ANG(0, 0, jitterAngle(rng, 2, 7)),
			tint(PAPER, rng, 6)
		)
		writeOn(note, Enum.NormalId.Front, text, INK)
	end
	return model
end

-- The wire shelving for the cases (chrome rods), the "BX-7" stencil kept on its front (moved to
-- the root by LabBuilder), two spare empty case shells, labelled tubs. `at`: its centre on the
-- floor, local -Z = out of the wall (6 long along local X, 1.8 deep).
function AptProps.wireShelf(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "WireShelf", at)
	local chrome = look(M.Metal, 170, 172, 174)
	for _, x in { -2.95, 2.95 } do
		for _, z in { -0.85, 0.85 } do
			add("Upright", V(0.12, 6.4, 0.12), CF(x, 3.2, z), chrome)
		end
	end
	for _, y in { 0.4, 2.6, 4.8 } do
		add("WireShelf", V(6, 0.08, 1.8), CF(0, y, 0), chrome)
		for i = 1, 3 do
			add("Rod", V(0.04, 0.04, 1.8), CF(-3.0 + i * 1.5, y + 0.05, 0), chrome)
		end
	end
	local stencil = add(
		"RackStencil",
		V(1.6, 0.6, 0.05),
		CF(0, 2.35, -0.93),
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
	-- two spare, empty case shells on the bottom shelf (dark plastic boxes with latches)
	for i, x in { -1.6, 0.8 } do
		local shell = add(
			"SpareCase",
			V(2.0, 0.9, 1.2),
			CF(x, 0.89, 0) * ANG(0, jitterAngle(rng, 2, 8), 0),
			look(M.Plastic, 44 + i * 6, 48, 50)
		)
		for _, lx in { -0.5, 0.5 } do
			part(
				model,
				"Latch",
				V(0.2, 0.25, 0.05),
				shell.CFrame * CF(lx, 0.1, -0.62),
				look(M.Metal, 150, 150, 146)
			)
		end
	end
	-- labelled tubs on the top shelf
	local lids = {
		look(M.SmoothPlastic, 120, 122, 118),
		look(M.SmoothPlastic, 60, 80, 120),
		look(M.SmoothPlastic, 70, 120, 128),
	}
	for i, text in { "FILTERS", "SEALS", "MEDIUM A" } do
		local tub = add(
			"Tub",
			V(1.4, 0.9, 1.2),
			CF(-2.0 + (i - 1) * 1.8, 5.29, 0) * ANG(0, jitterAngle(rng, 2, 6), 0),
			look(M.SmoothPlastic, 220, 226, 222)
		)
		add("TubLid", V(1.44, 0.08, 1.24), at:ToObjectSpace(tub.CFrame) * CF(0, 0.49, 0), lids[i])
		writeOn(tub, Enum.NormalId.Front, text, INK)
	end
	return model
end

-- A power strip taped to a wall with plugs, and drooping cords (catenaries) toward `targets`.
-- `scorched`: two black burn marks (the spark's source). `at`: on the wall, local -Z = out.
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
		add(
			"Scorch",
			V(0.5, 0.3, 0.01),
			CF(0.5, 0.05, -0.26) * ANG(0, 0, rad(10)),
			look(M.SmoothPlastic, 20, 18, 16)
		)
		add(
			"Scorch",
			V(0.7, 0.9, 0.01),
			CF(0.6, 0.5, 0.0) * ANG(0, 0, rad(-14)),
			look(M.Plaster, 40, 36, 32)
		)
		add(
			"MeltedPlug",
			V(0.22, 0.24, 0.3),
			CF(0.55, 0, -0.38) * ANG(0, 0, rad(12)),
			look(M.Plastic, 60, 52, 40)
		)
	end
	return model
end

-- A metal utility sink on legs: a bucket under it, a scrub brush, the second rubber gloves
-- (muted pink-grey, never red), a drip from the tap. `at`: its centre on the floor, local -Z
-- = out of the wall.
function AptProps.utilitySink(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "UtilitySink", at)
	local steel = look(M.Metal, 140, 142, 140)
	add("Basin", V(2.6, 0.1, 2.0), CF(0, 2.6, 0), steel)
	for _, x in { -1.25, 1.25 } do
		add("Side", V(0.1, 1.0, 2.0), CF(x, 3.1, 0), steel)
	end
	for _, z in { -0.95, 0.95 } do
		add("Side", V(2.6, 1.0, 0.1), CF(0, 3.1, z), steel)
	end
	add("Grime", V(2.4, 0.01, 1.8), CF(0, 2.66, 0), look(M.Metal, 104, 106, 100))
	for _, x in { -1.15, 1.15 } do
		for _, z in { -0.85, 0.85 } do
			add("Leg", V(0.12, 2.6, 0.12), CF(x, 1.3, z), steel)
		end
	end
	add("Tap", V(0.12, 1.0, 0.12), CF(0, 4.1, 0.85), look(M.Metal, 150, 146, 138))
	add("Spout", V(0.12, 0.12, 0.6), CF(0, 4.55, 0.6), look(M.Metal, 150, 146, 138))
	AptProps.bucket(model, at * CF(0.3, 0, 0.1), rng, look(M.Plastic, 120, 120, 112), nil)
	add(
		"Brush",
		V(0.8, 0.25, 0.35),
		CF(-0.7, 2.75, 0.3) * ANG(0, rad(30), 0),
		look(M.Plastic, 70, 110, 90)
	)
	AptProps.gloves(model, at * CF(1.2, 3.55, -0.9), rng, look(M.Rubber, 180, 150, 150))
	return model
end

-- The foil-covered window with a box fan wedged in its lower half. `at`: the window's bottom
-- centre ON the wall's room face, local -Z = into the room. Returns the model and the fan's
-- blade model (Anim/FanBlades; its WorldPivot = the hub, RightVector = into the room).
function AptProps.foilWindow(parent: Instance, at: CFrame, rng: Random): (Model, Model)
	local model, add = begin(parent, "FoilWindow", at)
	-- (the opening: 6 wide, 4 high, from y 3.5 to 7.5 above `at`)
	local frame = look(M.Wood, 140, 130, 110)
	add("Sill", V(6.6, 0.2, 0.7), CF(0, 3.4, -0.1), frame)
	add("FrameTop", V(6.4, 0.25, 0.5), CF(0, 7.6, 0.2), frame)
	for _, x in { -3.1, 3.1 } do
		add("FrameSide", V(0.25, 4.2, 0.5), CF(x, 5.5, 0.2), frame)
	end
	-- the foil pieces over the upper part, each turned a little, tape at the corners
	for i = 1, 5 do
		local x = -2.4 + (i - 1) * 1.2
		add(
			"Foil",
			V(1.35, 1.6, 0.02),
			CF(x, 6.75, 0.35)
				* ANG(0, 0, rad(rng:NextNumber(1, 3)) * (if i % 2 == 0 then 1 else -1)),
			look(M.Foil, 196, 198, 200, 0, 0.15)
		)
		add("Tape", V(0.3, 0.12, 0.022), CF(x - 0.5, 7.5, 0.33), TAPE)
	end
	add(
		"Foil",
		V(1.2, 0.9, 0.02),
		CF(-2.4, 5.2, 0.35) * ANG(0, 0, rad(2)),
		look(M.Foil, 190, 192, 194, 0, 0.15)
	)
	add(
		"Foil",
		V(1.1, 0.9, 0.02),
		CF(2.5, 5.2, 0.35) * ANG(0, 0, rad(-2)),
		look(M.Foil, 196, 198, 200, 0, 0.15)
	)
	-- the box fan in the lower middle (frame + grille rods; the blades are an Anim model)
	local fanFrame = look(M.Plastic, 200, 196, 186)
	local hub = at * CF(0, 5.1, 0.15)
	for _, x in { -1.45, 1.45 } do
		add("FanFrame", V(0.15, 3.0, 0.6), CF(x, 5.1, 0.15), fanFrame)
	end
	for _, y in { 3.65, 6.55 } do
		add("FanFrame", V(3.0, 0.15, 0.6), CF(0, y, 0.15), fanFrame)
	end
	for i = 1, 3 do
		add("Grille", V(2.8, 0.03, 0.03), CF(0, 3.75 + i * 0.7, -0.12), look(M.Metal, 80, 80, 78))
	end
	add("FanCord", V(0.08, 0.08, 1.5), CF(1.4, 3.7, -0.6) * ANG(rad(30), 0, 0), CORD_WHITE)
	-- tape and cardboard closing the gaps round the fan
	add("Cardboard", V(1.3, 3.0, 0.05), CF(-2.25, 5.0, 0.3), look(M.Cardboard, 150, 118, 82))
	add("Cardboard", V(1.3, 3.0, 0.05), CF(2.25, 5.0, 0.3), look(M.Cardboard, 140, 110, 78))
	local blades = Instance.new("Model")
	blades.Name = "FanBlades"
	local bladeLook = look(M.Rubber, 60, 62, 60)
	part(blades, "Hub", V(0.25, 0.5, 0.5), hub * ALONG_Z, bladeLook, CYL)
	for i = 1, 5 do
		local angle = (i - 1) * (2 * math.pi / 5)
		-- each blade: 1.3 long, out from the hub, pitched 20 degrees
		part(
			blades,
			"Blade",
			V(0.5, 1.3, 0.04),
			hub * ANG(0, 0, angle) * CF(0, 0.75, 0) * ANG(0, rad(20), 0),
			bladeLook
		)
	end
	-- the pivot: at the hub, its X axis pointing into the room (local -Z of the window)
	local intoRoom = at.LookVector
	blades.WorldPivot = CFrame.fromMatrix(hub.Position, intoRoom, Vector3.yAxis)
	blades.Parent = parent
	return model, blades
end

-- Two cooler boxes of different sizes/colours, lids off-true, a third lid against the wall.
function AptProps.coolerStack(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "CoolerStack", at)
	add("Cooler", V(2.6, 1.6, 1.6), CF(0, 0.8, 0.3), solid(look(M.Plastic, 70, 120, 140)))
	add(
		"CoolerLid",
		V(2.65, 0.2, 1.65),
		CF(0.05, 1.7, 0.3) * ANG(0, rad(3), 0),
		look(M.Plastic, 220, 222, 216)
	)
	add(
		"Cooler",
		V(2.0, 1.2, 1.3),
		CF(-0.1, 2.4, 0.35) * ANG(0, jitterAngle(rng, 3, 9), 0),
		look(M.Plastic, 196, 190, 170)
	)
	add(
		"CoolerLid",
		V(2.05, 0.18, 1.35),
		CF(-0.15, 3.09, 0.3) * ANG(0, rad(-6), rad(2)),
		look(M.Plastic, 70, 120, 140)
	)
	add(
		"SpareLid",
		V(2.4, 1.5, 0.18),
		CF(0.2, 0.75, 1.55) * ANG(rad(-12), 0, 0),
		look(M.Plastic, 150, 160, 120)
	)
	local tape = add("TapeLabel", V(1.0, 0.25, 0.02), CF(0, 1.0, -0.51), TAPE)
	writeOn(tape, Enum.NormalId.Front, "ICE PACKS", INK)
	return model
end

-- A small steel tool cart: a tray with forceps, clamps, foil, gauze, cable ties.
-- (No scalpels, no needles, no syringes: see the art rules.)
function AptProps.toolCart(parent: Instance, at: CFrame, rng: Random): Model
	local model, add = begin(parent, "ToolCart", at)
	local steel = look(M.Metal, 150, 152, 154)
	for _, y in { 0.8, 2.6 } do
		add("Tray", V(1.4, 0.08, 1.9), CF(0, y, 0), steel)
		for _, z in { -0.95, 0.95 } do
			add("TrayLip", V(1.4, 0.2, 0.05), CF(0, y + 0.1, z), steel)
		end
	end
	for _, x in { -0.65, 0.65 } do
		for _, z in { -0.9, 0.9 } do
			add("Leg", V(0.1, 2.6, 0.1), CF(x, 1.4, z), steel)
			add("Wheel", V(0.12, 0.25, 0.25), CF(x, 0.12, z), look(M.Rubber, 30, 30, 30), CYL)
		end
	end
	local chrome = look(M.Metal, 200, 202, 206)
	add("Forceps", V(0.05, 0.03, 0.9), CF(-0.3, 2.68, -0.3) * ANG(0, rad(8), 0), chrome)
	add("Forceps", V(0.05, 0.03, 0.9), CF(-0.25, 2.68, -0.3) * ANG(0, rad(12), 0), chrome)
	add(
		"Clamp",
		V(0.3, 0.12, 0.5),
		CF(0.3, 2.7, -0.5) * ANG(0, jitterAngle(rng), 0),
		look(M.Metal, 90, 92, 94)
	)
	add(
		"Clamp",
		V(0.25, 0.12, 0.45),
		CF(0.35, 2.7, 0.1) * ANG(0, jitterAngle(rng), 0),
		look(M.Metal, 110, 112, 114)
	)
	add("FoilRoll", V(1.2, 0.25, 0.25), CF(0, 2.78, 0.6), look(M.Foil, 196, 198, 200), CYL)
	add("Gauze", V(0.4, 0.4, 0.4), CF(-0.35, 2.85, 0.25) * UP, look(M.Fabric, 230, 230, 222), CYL)
	for _ = 1, 3 do
		add(
			"CableTie",
			V(0.6, 0.02, 0.04),
			CF(rng:NextNumber(-0.5, 0.5), 2.66, rng:NextNumber(-0.6, 0.6))
				* ANG(0, rng:NextNumber(0, 3), 0),
			look(M.Plastic, 230, 230, 226)
		)
	end
	add("SpareGloves", V(0.6, 0.15, 0.8), CF(0, 0.92, 0.2), look(M.Rubber, 186, 176, 110))
	return model
end

-- Floor litter in the lab: two flattened boxes, a coil of spare tubing, scattered cable ties, a
-- stool. `toWorld` converts lab-local CFrames (flat-local) to world.
function AptProps.labLitter(parent: Instance, toWorld: (CFrame) -> CFrame, rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "LabLitter"
	model.Parent = parent
	local function add(
		name: string,
		size: Vector3,
		localCf: CFrame,
		l: Look,
		shape: Enum.PartType?
	): Part
		return part(model, name, size, toWorld(localCf), l, shape)
	end
	local card = look(M.Cardboard, 150, 118, 82)
	add("FlatBox", V(2.4, 0.05, 1.8), CF(14.5, 0.08, 4.5) * ANG(0, rad(22), 0), tint(card, rng))
	add("FlatBox", V(1.9, 0.05, 1.5), CF(25.8, 0.08, 9.5) * ANG(0, rad(-35), 0), tint(card, rng))
	for c = 1, 2 do
		add(
			"TubingCoil",
			V(0.12, 1.3 - c * 0.2, 1.3 - c * 0.2),
			CF(13.2, 0.1 + c * 0.06, 13.8) * UP,
			look(M.Glass, 210, 225, 220, 0.4),
			CYL
		)
	end
	for _ = 1, 3 do
		add(
			"CableTie",
			V(0.6, 0.02, 0.04),
			CF(rng:NextNumber(14, 24), 0.07, rng:NextNumber(3, 14))
				* ANG(0, rng:NextNumber(0, 3), 0),
			look(M.Plastic, 230, 230, 226)
		)
	end
	local stool = look(M.Plastic, 60, 60, 60)
	add("StoolSeat", V(0.15, 1.2, 1.2), CF(25.3, 2.0, 6.9) * UP, solid(stool), CYL)
	for i = 1, 3 do
		local turn = ANG(0, rad(i * 120), 0)
		add(
			"StoolLeg",
			V(0.12, 2.0, 0.12),
			CF(25.3, 1.0, 6.9) * turn * CF(0, 0, 0.4) * ANG(rad(-10), 0, 0),
			stool
		)
	end
	return model
end

return table.freeze(AptProps)
