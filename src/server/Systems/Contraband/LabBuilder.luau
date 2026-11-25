--!strict
-- LabBuilder: builds one player's private hideout, "Flat 4B", on the server, from plain parts and
-- built-in materials only (no uploaded asset). The props come from AptProps.
--
-- WHAT IT IS: an ordinary, run-down flat at night (entry, living room + kitchenette, an L-shaped
-- corridor, a bathroom, three bedrooms) whose back bedroom was turned into a clandestine biotech
-- lab. Walking in reads as a slow discovery: one more sign of the lab at each step (cords in the
-- fuse box, cords and a hose along the corridor, a cold light line under the far door, the cook's
-- room, then the lab behind a strip curtain). Warm 2700 K darkness outside, cold teal inside.
--
-- WHERE: flats live in a row far from the city: slot n has its floor centre at
-- Config.Lab.ORIGIN + (n - 1) × SPACING on X. Every flat is a Model "Lab_<userId>" in
-- Workspace > Labs, attributes Owner (userId) and Unbreakable (heavy moves don't smash it),
-- ModelStreamingMode Atomic (it streams in as one piece), PrimaryPart "Floor". All anchored.
--
-- LOCAL FRAME: origin = the top of the floor at the centre of the footprint; +Z = from the front
-- door into the flat; +Y up; never rotated. Room interiors: X -28..28, Z -24..24; ceiling at 11.
--   Entry X -12..-4, Z -24..-14      Living X -28..-12, Z -24..-6   Bath X -20..-12, Z -6..4
--   Corridor A X -12..-6, Z -14..12  Corridor B X -12..10, Z 12..18 Bed1 X -6..6, Z -14..0 (locked)
--   Bed2 X -6..10, Z 0..12 (open)    Bed3 X -24..-12, Z 4..18 (boarded)  LAB X 10..28, Z 0..24
--
-- NAMED PARTS, DIRECT CHILDREN OF THE MODEL (a contract with Lab, Extraction, Case and the client
-- controllers: do not rename):
--   Floor          the PrimaryPart (one slab under everything)
--   Spawn          invisible, in the entry (LookVector = +Z, into the flat)
--   ExitDoor       the front door leaf (Apartments puts "Leave" on it)
--   VatCore        invisible, the vat's centre (the vat prompt is on it); VatGlass, VatBase,
--                  VatCap (+ SpotLight VatRimLight), VatPipe ×2; VatScreen (faces -Z)
--   BenchAnchor    invisible, IDENTITY rotation, on the trolley top: the shell lies along +X
--   CutterDock     invisible, identity: the cutter's charger sits here
--   ChargerLed     the charger's LED (Neon); X / V recolour it (attribute "Busy" while the
--                  cutter is out, set by the client)
--   ScanScreen     the small CRT's glass on the crate (Front face = -Z)
--   MonitorScreen  the station CRT's glass on the trestle (Front face = -X)
--   ChuteMouth     invisible, the chute hatch in the E wall (LookVector = into the wall)
--   ChuteFlap      the hatch's flap (side-hinged, open against the wall)
--   RackSpot       invisible, on the wire shelving (Take case); RackStencil "BX-7"
--   StashShelf     invisible, identity, INSIDE the glass-lid freezer (capsules sit on it)
--   TubeLight      the lab's fluorescent tube (SurfaceLight "Light", shadows, attr Flicker "Tube")
--   LampHead       the work lamp's head over the bench (SpotLight "Light")
--
-- FOLDERS (contracts with ApartmentController / ApartmentAmbienceController, see DESIGN §1.4):
--   Rooms     invisible boxes named Entry, Living, Corridor (×2), Bath, Bed2, Lab
--   Doors     Models Door_<Room>: Leaf (PrimaryPart), WorldPivot = hinge line on the floor;
--             attributes Room, Mode ("Auto" | "Prompt" | "Locked"), RestAngle, OpenAngle (deg,
--             a positive angle swings toward the hinge's local -Z), Label, ClosedPivot (CFrame),
--             TriggerDistance (studs, Auto doors)
--   Fixtures  light fixtures: a part with its light named "Light", attribute Flicker
--             ("None" | "Bulb" | "Rare" | "Toggle"); some have "Follows" (the fixture they copy)
--   Fx        invisible emitter hosts (V builds the emitters): attributes Zone, Kind, optional
--             Aim (Vector3, world direction), LandAt (Vector3, where a drip lands), Fixture
--   Sfx       invisible sound hosts: attributes Slot, Zone, Min, Max, Volume, Pitch, Type
--   Anim      Models the client moves: Pendant, FanBlades, Sheet_1..3, Curtain
--   Shell, Props_<Room>   everything else (no contract)
--
-- BUDGET: ~1000 parts, 5 shadow-casting lights (entry pendant, blind sodium, corridor bulb, bend
-- bulb, lab tube); every other light has a small Range (Future lights without shadows shine
-- through walls).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AptProps = require(script.Parent.AptProps)

type Look = AptProps.Look

local LabBuilder = {}

-- Half sizes of the flat's box (outer walls and slabs included), for "is someone inside?".
LabBuilder.HALF_SIZE = Vector3.new(29.5, 7, 25.5)
LabBuilder.CENTRE_HEIGHT = 5.5 -- the box centre is this far above the floor top

local CEILING = 11 -- the ceiling's underside
local DOOR_WIDTH = 4.5
local DOOR_HEIGHT = 7.5

local M = Enum.Material
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local look = AptProps.look
local part = AptProps.part

-- The CFrame of the floor-top centre of flat slot `slot` (1, 2, 3...).
function LabBuilder.origin(slot: number): CFrame
	return CFrame.new(Config.Lab.ORIGIN + Vector3.new((slot - 1) * Config.Lab.SPACING, 0, 0))
end

-- Which way a prop faces: its front (local -Z) looks toward this world direction.
local FACING: { [string]: CFrame } = {
	S = CFrame.identity, -- toward -Z (back toward the front door)
	N = ANG(0, math.pi, 0), -- toward +Z (deeper into the flat)
	E = ANG(0, -math.pi / 2, 0), -- toward +X
	W = ANG(0, math.pi / 2, 0), -- toward -X
}

-- Wall styles: the look of each face (and an optional upper look above `split`, e.g. tiles).
type Style = { look: Look, upper: Look?, split: number? }

local function style(material: Enum.Material, r: number, g: number, b: number): Style
	return { look = AptProps.wall(look(material, r, g, b)) }
end

local LIVING = style(M.Plaster, 148, 138, 116)
-- (the entry and corridors: a darker, greyer plaster, with dark gloss below the dado rail)
local ENTRY = style(M.Plaster, 128, 124, 110)
local CORRIDOR = ENTRY
local BED2 = style(M.Plaster, 120, 118, 104)
local LAB = style(M.Plaster, 122, 116, 96) -- (the old bedroom wallpaper, behind the plastic)
local VOID = style(M.Plaster, 110, 106, 96)
local BATH: Style = {
	look = AptProps.wall(look(M.CeramicTiles, 188, 192, 182)),
	upper = AptProps.wall(look(M.Plaster, 170, 172, 160)),
	split = 5.5,
}

-- An opening in a wall run: centre along the run, width, bottom and top heights.
type Opening = { centre: number, width: number, bottom: number, top: number }

local function door(centre: number): Opening
	return { centre = centre, width = DOOR_WIDTH, bottom = 0, top = DOOR_HEIGHT }
end

function LabBuilder.build(slot: number, owner: number): Model
	local origin = LabBuilder.origin(slot)
	-- (one seeded generator per flat: the same flat every visit, a different one per player)
	local rng = Random.new(owner)
	local model = Instance.new("Model")
	model.Name = `Lab_{owner}`
	model:SetAttribute("Owner", owner)
	model:SetAttribute("Unbreakable", true)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local function folder(name: string): Folder
		local made = Instance.new("Folder")
		made.Name = name
		made.Parent = model
		return made
	end
	local shell = folder("Shell")
	local roomsFolder = folder("Rooms")
	local doors = folder("Doors")
	local fixtures = folder("Fixtures")
	local fx = folder("Fx")
	local sfx = folder("Sfx")
	local anim = folder("Anim")
	local props = {
		Entry = folder("Props_Entry"),
		Living = folder("Props_Living"),
		Corridor = folder("Props_Corridor"),
		Bath = folder("Props_Bath"),
		Bed2 = folder("Props_Bed2"),
		Lab = folder("Props_Lab"),
	}

	-- flat-local → world helpers
	local function L(x: number, y: number, z: number, facing: string?): CFrame
		return origin * CF(x, y, z) * (FACING[facing or "S"] or CFrame.identity)
	end
	local function P(x: number, y: number, z: number): Vector3
		return (origin * CF(x, y, z)).Position
	end
	local function toWorld(localCf: CFrame): CFrame
		return origin * localCf
	end
	-- A frame ON a wall face: at local point (x, y, z), LookVector = `out` (out of the wall),
	-- +X running along the wall. Used by skirting, wallpaper, stains.
	local function wallFrame(x: number, y: number, z: number, out: Vector3): CFrame
		local along = out:Cross(Vector3.yAxis)
		return origin * CFrame.fromMatrix(V(x, y, z), along, Vector3.yAxis)
	end
	-- An invisible marker (no collisions, no queries).
	local function marker(name: string, at: CFrame, parent: Instance?): Part
		local made = part(parent or model, name, Vector3.one, at, look(M.SmoothPlastic, 0, 0, 0, 1))
		made.CastShadow = false
		return made
	end
	-- An invisible host box (for emitters / sounds / room lookups).
	local function host(parent: Instance, name: string, size: Vector3, at: CFrame): Part
		local made = part(parent, name, size, at, look(M.SmoothPlastic, 0, 0, 0, 1))
		made.CastShadow = false
		return made
	end

	------------------------------------------------------------------------------
	-- The shell: floor, ceiling, walls
	------------------------------------------------------------------------------

	local floor = part(
		model,
		"Floor",
		V(58, 1, 50),
		L(0, -0.5, 0),
		AptProps.wall(look(M.WoodPlanks, 92, 70, 52))
	)
	model.PrimaryPart = floor
	local ceilingColor = Color3.fromRGB(150, 144, 128)
	local ceilingLook = AptProps.wall(look(M.Plaster, 150, 144, 128))
	part(shell, "Ceiling", V(58, 1, 50), L(0, CEILING + 0.5, 0), ceilingLook) -- (also stops rain rays)

	-- One slab of wall between heights y0 and y1 (split in two looks when the style has an upper).
	local function slab(
		axis: "X" | "Z",
		line: number,
		depthCentre: number,
		thickness: number,
		a0: number,
		a1: number,
		y0: number,
		y1: number,
		s: Style
	)
		local function one(lo: number, hi: number, l: Look)
			if hi - lo < 0.01 or a1 - a0 < 0.01 then
				return
			end
			local mid = (a0 + a1) / 2
			local size: Vector3
			local at: CFrame
			if axis == "Z" then
				size = V(a1 - a0, hi - lo, thickness)
				at = L(mid, (lo + hi) / 2, line + depthCentre)
			else
				size = V(thickness, hi - lo, a1 - a0)
				at = L(line + depthCentre, (lo + hi) / 2, mid)
			end
			part(shell, "Wall", size, at, l)
		end
		local split = s.split
		local upper = s.upper
		if split and upper and y0 < split and y1 > split then
			one(y0, split, s.look)
			one(split, y1, upper)
		elseif split and upper and y0 >= split then
			one(y0, y1, upper)
		else
			one(y0, y1, s.look)
		end
	end

	-- A straight wall on line `line` (axis "Z": runs along X at z = line; axis "X": runs along Z
	-- at x = line), from `from` to `to`, with openings. `neg` / `pos` = the styles of its two
	-- faces (the room on the smaller / bigger side; nil = never seen). `outer` = "neg" / "pos":
	-- an outer wall 1 thick lying on that side of the line (the room is on the other side).
	local function wallRun(
		axis: "X" | "Z",
		line: number,
		from: number,
		to: number,
		openings: { Opening },
		neg: Style?,
		pos: Style?,
		outer: ("neg" | "pos")?
	)
		-- the layers across the wall: { depth centre, thickness, style }
		local layers: { { centre: number, thickness: number, s: Style } } = {}
		if outer == "neg" then
			table.insert(layers, { centre = -0.5, thickness = 1, s = pos or VOID })
		elseif outer == "pos" then
			table.insert(layers, { centre = 0.5, thickness = 1, s = neg or VOID })
		elseif neg and pos and neg ~= pos then
			table.insert(layers, { centre = -0.125, thickness = 0.25, s = neg })
			table.insert(layers, { centre = 0.125, thickness = 0.25, s = pos })
		else
			table.insert(layers, { centre = 0, thickness = 0.5, s = neg or pos or VOID })
		end
		local sorted = table.clone(openings)
		table.sort(sorted, function(a, b)
			return a.centre < b.centre
		end)
		for _, layer in layers do
			local cursor = from
			for _, opening in sorted do
				local o0 = opening.centre - opening.width / 2
				local o1 = opening.centre + opening.width / 2
				if o1 > from and o0 < to then
					slab(
						axis,
						line,
						layer.centre,
						layer.thickness,
						cursor,
						math.max(cursor, o0),
						0,
						CEILING,
						layer.s
					)
					local c0, c1 = math.max(o0, from), math.min(o1, to)
					slab(
						axis,
						line,
						layer.centre,
						layer.thickness,
						c0,
						c1,
						opening.top,
						CEILING,
						layer.s
					)
					if opening.bottom > 0 then
						slab(
							axis,
							line,
							layer.centre,
							layer.thickness,
							c0,
							c1,
							0,
							opening.bottom,
							layer.s
						)
					end
					cursor = math.max(cursor, o1)
				end
			end
			slab(axis, line, layer.centre, layer.thickness, cursor, to, 0, CEILING, layer.s)
		end
	end

	local FRONT_DOOR: Opening = door(-8)
	local WINDOW: Opening = { centre = -20.5, width = 7, bottom = 3, top = 8 }
	local ARCH: Opening = { centre = -19, width = 5, bottom = 0, top = 8.5 }
	local LAB_WINDOW: Opening = { centre = 19, width = 6, bottom = 3.5, top = 7.5 }

	-- walls running along X (z = line)
	wallRun("Z", -24, -29, -12, { WINDOW }, nil, LIVING, "neg")
	wallRun("Z", -24, -12, -4, { FRONT_DOOR }, nil, ENTRY, "neg")
	wallRun("Z", -24, -4, 29, {}, nil, VOID, "neg")
	wallRun("Z", -14, -6, -4, {}, ENTRY, nil)
	wallRun("Z", -14, -4, 6, {}, VOID, nil)
	wallRun("Z", -6, -28, -20, {}, LIVING, nil)
	wallRun("Z", -6, -20, -12, {}, LIVING, BATH)
	wallRun("Z", 0, -6, 10, {}, nil, BED2)
	wallRun("Z", 0, 10, 28, { LAB_WINDOW }, nil, LAB)
	wallRun("Z", 4, -24, -20, {}, VOID, nil)
	wallRun("Z", 4, -20, -12, {}, BATH, nil)
	wallRun("Z", 12, -6, 10, { door(3) }, BED2, CORRIDOR)
	wallRun("Z", 18, -24, -12, {}, nil, VOID)
	wallRun("Z", 18, -12, 10, {}, CORRIDOR, nil)
	wallRun("Z", 24, -29, 10, {}, VOID, nil, "pos")
	wallRun("Z", 24, 10, 29, {}, LAB, nil, "pos")
	-- walls running along Z (x = line)
	wallRun("X", -28, -24, -6, {}, nil, LIVING, "neg")
	wallRun("X", -28, -6, 24, {}, nil, VOID, "neg")
	wallRun("X", -24, 4, 18, {}, VOID, nil)
	wallRun("X", -20, -6, 4, {}, nil, BATH)
	wallRun("X", -12, -24, -14, { ARCH }, LIVING, ENTRY)
	wallRun("X", -12, -14, -6, {}, LIVING, CORRIDOR)
	wallRun("X", -12, -6, 4, { door(-1) }, BATH, CORRIDOR)
	wallRun("X", -12, 4, 18, { door(8) }, nil, CORRIDOR)
	wallRun("X", -6, -14, 0, { door(-9) }, CORRIDOR, nil)
	wallRun("X", -6, 0, 12, {}, CORRIDOR, BED2)
	wallRun("X", -4, -24, -14, {}, ENTRY, nil)
	wallRun("X", 6, -14, 0, {}, VOID, nil)
	wallRun("X", 10, 0, 12, {}, BED2, LAB)
	wallRun("X", 10, 12, 18, { door(15) }, CORRIDOR, LAB)
	wallRun("X", 10, 18, 24, {}, nil, LAB)
	wallRun("X", 28, -24, 0, {}, VOID, nil, "pos")
	wallRun("X", 28, 0, 24, {}, LAB, nil, "pos")

	-- Behind the two windows: dark backdrops so the void outside never shows.
	part(shell, "Backdrop", V(16, 14, 0.5), L(-20.5, 6, -31), look(M.SmoothPlastic, 40, 24, 14))
	part(shell, "Backdrop", V(8, 6, 0.3), L(19, 5.5, -1.2), look(M.SmoothPlastic, 10, 12, 12))

	-- Door casings (both faces of every doorway) and the arch's trim.
	local function casing(
		x: number,
		z: number,
		alongX: boolean,
		width: number,
		height: number,
		paint: Color3?,
		thickness: number?
	)
		local at = if alongX then L(x, 0, z) else L(x, 0, z) * ANG(0, math.pi / 2, 0)
		AptProps.casing(shell, at, width, height, thickness or 0.5, paint)
	end
	casing(-8, -24.5, true, DOOR_WIDTH, DOOR_HEIGHT, Color3.fromRGB(150, 140, 118), 1)
	casing(-12, -19, false, 5, 8.5)
	casing(-12, -1, false, DOOR_WIDTH, DOOR_HEIGHT)
	casing(-12, 8, false, DOOR_WIDTH, DOOR_HEIGHT)
	casing(-6, -9, false, DOOR_WIDTH, DOOR_HEIGHT)
	casing(3, 12, true, DOOR_WIDTH, DOOR_HEIGHT)
	casing(10, 15, false, DOOR_WIDTH, DOOR_HEIGHT, Color3.fromRGB(150, 146, 132))

	------------------------------------------------------------------------------
	-- Floors, skirting, wallpaper, stains
	------------------------------------------------------------------------------

	-- Entry: 2 × 2 checker tiles, 3 missing (concrete under), 2 lifted.
	part(shell, "Screed", V(8, 0.02, 10), L(-8, 0.01, -19), look(M.Concrete, 100, 98, 92))
	local tileIndex = 0
	for tx = -11, -5, 2 do
		for tz = -23, -15, 2 do
			tileIndex += 1
			local missing = tileIndex == 6 or tileIndex == 13 or tileIndex == 17
			if not missing then
				local dark = ((tx + tz) // 2) % 2 == 0
				local tileLook = if dark
					then look(M.SmoothPlastic, 78, 78, 70)
					else look(M.SmoothPlastic, 124, 118, 104)
				local lift = if tileIndex == 3 or tileIndex == 11
					then ANG(rad(2), 0, rad(1))
					else CFrame.identity
				part(
					shell,
					"Tile",
					V(1.96, 0.05, 1.96),
					L(tx, 0.045, tz) * lift,
					AptProps.tint(tileLook, rng, 4)
				)
			end
		end
	end
	-- Bath: ceramic floor, 4 missing tiles.
	part(shell, "BathFloor", V(8, 0.05, 10), L(-16, 0.025, -1), look(M.CeramicTiles, 176, 180, 170))
	for i = 1, 4 do
		part(
			shell,
			"MissingTile",
			V(1, 0.03, 1),
			L(-19 + i * 1.4, 0.055, -4.5 + (i % 2) * 6.2),
			look(M.Concrete, 100, 98, 92)
		)
	end
	-- Lab: the old bedroom carpet still shows along the W and S walls (a band with its wooden
	-- tack strip); the rest is a grey rubber mat + overlapping clear plastic taped down.
	local carpet = look(M.Fabric, 92, 78, 70)
	part(shell, "OldCarpet", V(0.8, 0.03, 23.75), L(10.65, 0.015, 12.125), carpet)
	part(shell, "OldCarpet", V(17.75, 0.03, 0.8), L(19.125, 0.015, 0.65), carpet)
	local tack = look(M.Wood, 104, 86, 62)
	part(shell, "TackStrip", V(0.12, 0.04, 22.9), L(11.0, 0.035, 12.55), tack)
	part(shell, "TackStrip", V(16.9, 0.04, 0.12), L(19.5, 0.035, 1.0), tack)
	part(
		shell,
		"LabMat",
		V(16.95, 0.04, 22.95),
		L(19.525, 0.02, 12.525),
		look(M.Rubber, 46, 48, 48)
	)
	for i = 0, 3 do
		local sheet = part(
			shell,
			"FloorPlastic",
			V(5.2, 0.01, 23),
			L(12.5 + i * 4.6, 0.045, 12) * ANG(0, rad(rng:NextNumber(-0.8, 0.8)), 0),
			look(M.Glass, 200, 210, 210, 0.75)
		)
		sheet.CastShadow = false
	end
	-- the tape on the plastic's joins: short torn pieces, a little crooked, with gaps
	for i = 0, 2 do
		local z = 1.2 + rng:NextNumber(0, 0.6)
		while z < 23.2 do
			local length = math.min(rng:NextNumber(4.5, 7), 23.4 - z)
			part(
				shell,
				"FloorTape",
				V(0.22, 0.012, length),
				L(14.9 + i * 4.6, 0.052, z + length / 2) * ANG(0, rad(rng:NextNumber(-1.5, 1.5)), 0),
				look(M.Fabric, 72, 74, 70)
			)
			z += length + rng:NextNumber(0.4, 1.4)
		end
	end

	-- Skirting runs: { x0, z0, x1, z1, out } on the wall faces of the warm rooms.
	type Run = { a: Vector3, b: Vector3, out: Vector3, room: string }
	local X_PLUS, X_MINUS, Z_PLUS, Z_MINUS =
		Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis
	local runs: { Run } = {
		-- entry
		{ a = V(-12, 0, -24), b = V(-10.65, 0, -24), out = Z_PLUS, room = "Entry" },
		{ a = V(-5.35, 0, -24), b = V(-4, 0, -24), out = Z_PLUS, room = "Entry" },
		{ a = V(-4.25, 0, -24), b = V(-4.25, 0, -14.25), out = X_MINUS, room = "Entry" },
		-- living
		{ a = V(-28, 0, -24), b = V(-12.25, 0, -24), out = Z_PLUS, room = "Living" },
		{ a = V(-28, 0, -24), b = V(-28, 0, -6.25), out = X_PLUS, room = "Living" },
		{ a = V(-12.25, 0, -24), b = V(-12.25, 0, -21.9), out = X_MINUS, room = "Living" },
		{ a = V(-12.25, 0, -16.1), b = V(-12.25, 0, -6.25), out = X_MINUS, room = "Living" },
		-- corridor A west face (entry → bend), with its openings
		{ a = V(-11.75, 0, -24), b = V(-11.75, 0, -21.9), out = X_PLUS, room = "Entry" },
		{ a = V(-11.75, 0, -16.1), b = V(-11.75, 0, -3.65), out = X_PLUS, room = "Corridor" },
		{ a = V(-11.75, 0, 1.65), b = V(-11.75, 0, 5.35), out = X_PLUS, room = "Corridor" },
		{ a = V(-11.75, 0, 10.65), b = V(-11.75, 0, 17.75), out = X_PLUS, room = "Corridor" },
		-- corridor A east face
		{ a = V(-6.25, 0, -14.25), b = V(-6.25, 0, -11.65), out = X_MINUS, room = "Corridor" },
		{ a = V(-6.25, 0, -6.35), b = V(-6.25, 0, 12.25), out = X_MINUS, room = "Corridor" },
		-- corridor B
		{ a = V(-6.25, 0, 12.25), b = V(0.35, 0, 12.25), out = Z_PLUS, room = "Corridor" },
		{ a = V(5.65, 0, 12.25), b = V(9.75, 0, 12.25), out = Z_PLUS, room = "Corridor" },
		{ a = V(-11.75, 0, 17.75), b = V(9.75, 0, 17.75), out = Z_MINUS, room = "Corridor" },
		-- bed 2
		{ a = V(-5.75, 0, 0.25), b = V(-5.75, 0, 11.75), out = X_PLUS, room = "Bed2" },
		{ a = V(-5.75, 0, 0.25), b = V(9.75, 0, 0.25), out = Z_PLUS, room = "Bed2" },
		{ a = V(9.75, 0, 0.25), b = V(9.75, 0, 11.75), out = X_MINUS, room = "Bed2" },
		{ a = V(-5.75, 0, 11.75), b = V(0.35, 0, 11.75), out = Z_MINUS, room = "Bed2" },
		{ a = V(5.65, 0, 11.75), b = V(9.75, 0, 11.75), out = Z_MINUS, room = "Bed2" },
	}
	local WALLPAPER: { [string]: { Color3 } } = {
		Entry = { Color3.fromRGB(132, 124, 98), Color3.fromRGB(138, 128, 104) },
		Living = { Color3.fromRGB(126, 118, 94), Color3.fromRGB(132, 124, 98) },
		Corridor = { Color3.fromRGB(126, 118, 94), Color3.fromRGB(122, 116, 96) },
	}
	for _, run in runs do
		local along = run.out:Cross(Vector3.yAxis)
		local a, b = run.a, run.b
		if (b - a):Dot(along) < 0 then
			a, b = b, a
		end
		local length = (b - a).Magnitude
		local frame = wallFrame(a.X, 0, a.Z, run.out)
		local parent = props[run.room] or shell
		AptProps.skirting(parent, frame, length, rng, run.room == "Corridor" or run.room == "Entry")
		local tones = WALLPAPER[run.room]
		if tones then
			local dado = run.room == "Corridor" or run.room == "Entry"
			AptProps.wallpaper(
				parent,
				frame,
				length,
				CEILING,
				tones,
				if length > 8 then 1 else 0,
				rng,
				nil,
				if dado then 3.56 else nil
			)
		end
	end

	-- Stains: the hand-height band along corridor A, damp by the bath door, a halo over the
	-- living room radiator, one by the Bed1 door.
	local corridorColor = CORRIDOR.look.color
	for z = -11, 10, 6 do
		AptProps.stain(
			props.Corridor,
			wallFrame(-6.29, 3.5, z, X_MINUS),
			Vector2.new(1.6, 0.9),
			corridorColor,
			rng
		)
	end
	AptProps.stain(
		props.Corridor,
		wallFrame(-11.71, 1.2, 2.6, X_PLUS),
		Vector2.new(1.8, 1.6),
		corridorColor,
		rng
	)
	AptProps.stain(
		props.Corridor,
		wallFrame(-11.71, 1.0, -4.4, X_PLUS),
		Vector2.new(1.4, 1.2),
		corridorColor,
		rng
	)
	-- hand grime round the latch side of the Bed1 and bathroom doors
	AptProps.stain(
		props.Corridor,
		wallFrame(-6.29, 3.4, -6.1, X_MINUS),
		Vector2.new(0.9, 1.5),
		corridorColor,
		rng
	)
	AptProps.stain(
		props.Corridor,
		wallFrame(-11.71, 3.4, -3.9, X_PLUS),
		Vector2.new(0.9, 1.5),
		corridorColor,
		rng
	)
	-- a wavy damp tide-mark rising from the skirting beside the bathroom door
	for i = 0, 4 do
		local height = 0.7 + math.sin(i * 1.7) * 0.25 + rng:NextNumber(0, 0.15)
		part(
			props.Corridor,
			"TideMark",
			V(0.012, height, 0.62),
			L(-11.7, 0.55 + height / 2, -6.4 + i * 0.55),
			look(M.Plaster, 96, 90, 70)
		)
	end
	AptProps.stain(
		props.Living,
		wallFrame(-14.5, 4.2, -23.96, Z_PLUS),
		Vector2.new(3, 1.6),
		LIVING.look.color,
		rng
	)
	AptProps.stain(
		props.Bed2,
		wallFrame(-5.71, 9.0, 6, X_PLUS),
		Vector2.new(2.5, 2.2),
		BED2.look.color,
		rng
	)

	------------------------------------------------------------------------------
	-- Doors
	------------------------------------------------------------------------------

	-- A door in a doorway centred at (x, z), swinging toward `into` (a world-axis direction).
	-- The hinge sits on the face on the `into` side so the leaf lies flat when open.
	local function makeDoor(
		name: string,
		x: number,
		z: number,
		into: Vector3,
		spec: AptProps.DoorSpec
	): Model
		local along = into:Cross(Vector3.yAxis) -- (from the hinge to the latch)
		local centre = V(x, 0, z)
		local hingePos = centre - along * 2.2 + into * 0.125
		local hinge = origin * CFrame.fromMatrix(hingePos, along, Vector3.yAxis)
		local made = AptProps.door(doors, name, hinge, spec, rng)
		made:SetAttribute("ClosedPivot", hinge)
		made:PivotTo(hinge * ANG(0, rad(spec.restAngle), 0))
		return made
	end
	-- (positive angles swing the latch toward `into`; detail side -1 = the `into` face)
	local bathDoor = makeDoor("Door_Bath", -12, -1, X_MINUS, {
		room = "Bath",
		mode = "Auto",
		restAngle = 0,
		openAngle = 95,
		label = "Bathroom",
		paint = Color3.fromRGB(176, 170, 150),
	})
	AptProps.doorTowelHook(bathDoor, -1)
	local bed1Door = makeDoor("Door_Bed1", -6, -9, X_PLUS, {
		room = "Bed1",
		mode = "Locked",
		restAngle = 0,
		openAngle = 0,
		label = "Door",
	})
	AptProps.doorPadlock(bed1Door, 1)
	local bed2Door = makeDoor("Door_Bed2", 3, 12, Z_MINUS, {
		room = "Bed2",
		mode = "Auto",
		restAngle = 0,
		openAngle = 100,
		label = "Bedroom",
		paint = Color3.fromRGB(110, 96, 76),
	})
	AptProps.doorSock(bed2Door, 1)
	local bed3Door = makeDoor("Door_Bed3", -12, 8, X_MINUS, {
		room = "Bed3",
		mode = "Locked",
		restAngle = 0,
		openAngle = 0,
		label = "Door",
		paint = Color3.fromRGB(90, 80, 64),
	})
	AptProps.doorBoards(bed3Door, 1, rng)
	-- The lab door opens OUT into the corridor (hinge on the north side): when open it lies
	-- against the corridor wall and never cuts through the strip curtain behind it.
	local labDoor = makeDoor("Door_Lab", 10, 15, X_MINUS, {
		room = "Lab",
		mode = "Auto",
		restAngle = 0,
		openAngle = 92,
		label = "Door",
		paint = Color3.fromRGB(128, 116, 96),
	})
	AptProps.doorLabDetails(labDoor, -1)
	labDoor:SetAttribute("TriggerDistance", 6)
	-- Rest angles (ajar) set after the details so they swing with the leaf.
	local function setRest(made: Model, angle: number)
		made:SetAttribute("RestAngle", angle)
		local closed = made:GetAttribute("ClosedPivot")
		if typeof(closed) == "CFrame" then
			made:PivotTo(closed * ANG(0, rad(angle), 0))
		end
	end
	setRest(bathDoor, 35)
	setRest(bed2Door, 30)
	setRest(labDoor, 14)

	-- The front door (not in Doors: it never swings; "Leave" is on it).
	part(
		model,
		"ExitDoor",
		V(4.4, 7.4, 0.25),
		L(-8, 3.75, -23.85),
		AptProps.solid(look(M.Wood, 70, 52, 40))
	)
	AptProps.frontDoorDetails(props.Entry, L(-8, 0, -23.85, "N"), rng)

	------------------------------------------------------------------------------
	-- ENTRY
	------------------------------------------------------------------------------

	AptProps.mailHeap(props.Entry, L(-7.6, 0, -22.9, "N"), rng)
	AptProps.coatHooks(props.Entry, L(-4.25, 0, -22.4, "W"), rng)
	-- a worn doormat, kicked a little way in by the door
	part(
		props.Entry,
		"Doormat",
		V(2.6, 0.04, 1.6),
		L(-8.3, 0.08, -21.4) * ANG(0, rad(5), 0),
		look(M.Fabric, 64, 56, 48)
	)
	AptProps.shoePile(props.Entry, L(-10.9, 0, -23.1, "N"), rng)
	local _cupboard, cordExit = AptProps.meterCupboard(props.Entry, L(-4.25, 0, -16.25, "W"), rng)
	AptProps.mirror(props.Entry, L(-11.75, 0, -22.8, "E"), rng)
	AptProps.lightSwitch(props.Entry, L(-11.2, 0, -24, "N"), rng)

	------------------------------------------------------------------------------
	-- LIVING ROOM + KITCHENETTE
	------------------------------------------------------------------------------

	AptProps.sofa(props.Living, L(-25.95, 0, -16.5, "E"), rng)
	AptProps.rug(
		props.Living,
		L(-22, 0, -16.5),
		rng,
		Vector2.new(5, 4.2),
		look(M.Fabric, 58, 56, 64)
	)
	AptProps.lowTable(props.Living, L(-22, 0.05, -16.5, "W"), rng)
	AptProps.crtTV(props.Living, L(-13.6, 0, -10.75, "W"), rng)
	AptProps.blindWindow(props.Living, L(-20.5, 0, -24, "N"), rng)
	AptProps.kitchenCounter(props.Living, L(-23.5, 0, -7.45), rng)
	AptProps.oldFridge(props.Living, L(-17.5, 0, -7.15), rng)
	local fridgeHinge = origin * CFrame.fromMatrix(V(-18.6, 0, -8.2), Vector3.xAxis, Vector3.yAxis)
	AptProps.fridgeDoor(doors, fridgeHinge, rng):SetAttribute("ClosedPivot", fridgeHinge)
	AptProps.foldTable(props.Living, L(-18.5, 0, -12.6, "N"), rng)
	AptProps.radiator(props.Living, L(-14.5, 0, -24, "N"), rng)
	AptProps.pipes(props.Living, { P(-27.6, 10.5, -6.6), P(-12.6, 10.5, -6.6) }, rng, nil)

	------------------------------------------------------------------------------
	-- CORRIDOR (A: the long run, B: after the bend)
	------------------------------------------------------------------------------

	AptProps.runner(props.Corridor, L(-9, 0, -1.5), rng, 23)
	AptProps.ceilingSag(props.Corridor, L(-9, CEILING, 5), rng, ceilingColor)
	AptProps.bucket(props.Corridor, L(-8.4, 0, 5.2), rng, look(M.Plastic, 70, 90, 110), 0.8)
	AptProps.mould(props.Corridor, L(-6.7, CEILING, 5.8), rng)
	AptProps.pictureFrame(props.Corridor, L(-11.75, 0, -9.5, "E"), rng)
	AptProps.deadPlant(props.Corridor, L(-11, 0, -7.2), rng)
	AptProps.broom(props.Corridor, L(-11.35, 0, 1.9, "E"), rng)
	AptProps.smokeDetector(props.Corridor, L(-9, CEILING, -8), rng)
	AptProps.coatStand(props.Corridor, L(-11, 0, 16.6), rng)
	AptProps.deadSocket(props.Corridor, L(0, CEILING, 15), rng)
	AptProps.outlet(props.Corridor, L(-6.25, 0, 2, "W"), rng)
	AptProps.pipes(
		props.Corridor,
		{ P(-6.6, 10.45, -14), P(-6.6, 10.45, 12) },
		rng,
		P(-6.6, 10.45, 4.8)
	)
	AptProps.lightSwitch(props.Corridor, L(-11.75, 0, -12.6, "E"), rng)

	-- The cord bundle: from the meter cupboard, along corridor A's east skirting, across the
	-- bend, along corridor B's north wall, up and into a hole drilled above the lab door.
	local cordPoints = {
		cordExit,
		P(-4.42, 3.4, -16.3),
		P(-4.42, 0.08, -15.6),
		P(-4.55, 0.08, -14.6),
		P(-6.7, 0.08, -14.6),
		P(-6.7, 0.08, 11.6),
		P(-5.2, 0.08, 17.25),
		P(4.0, 0.08, 17.3),
		P(4.0, 8.6, 17.55),
		P(9.6, 8.6, 17.55),
		P(9.85, 8.6, 16.6),
	}
	AptProps.cordBundle(props.Corridor, cordPoints, { 5, 5, 4, 4, 3, 3, 3, 4, 4, 4 }, rng, 4)
	-- ...and inside the lab, from the hole along the ceiling to the vat frame.
	AptProps.cordBundle(props.Lab, {
		P(10.4, 8.6, 16.6),
		P(10.4, 10.5, 16.6),
		P(17.2, 10.5, 16.6),
		P(17.2, 9.85, 16.6),
	}, { 4, 4, 4 }, rng, 4)
	part(
		props.Corridor,
		"DrillHole",
		V(0.02, 0.9, 0.9),
		L(9.74, 8.6, 16.65) * ANG(0, 0, 0),
		look(M.SmoothPlastic, 8, 8, 8),
		Enum.PartType.Cylinder
	)

	-- The garden hose: from the bathtub, out of the bathroom, along corridor A's west skirting,
	-- round the bend, up with the cords into the lab, down into the vat.
	AptProps.hose(props.Bath, {
		P(-18.5, 0.85, -1.4),
		P(-16.9, 2.25, -1.3),
		P(-16.2, 0.12, -1.2),
		P(-12.3, 0.12, -0.6),
		P(-11.4, 0.12, 11.6),
		P(-10.2, 0.12, 16.75),
		P(4.6, 0.12, 16.85),
		P(4.6, 8.95, 17.6),
		P(10.4, 8.95, 16.95),
		P(10.5, 10.3, 17.2),
		P(18.6, 10.3, 18.4),
		P(19.2, 9.85, 19.0),
	}, rng)

	------------------------------------------------------------------------------
	-- BATHROOM
	------------------------------------------------------------------------------

	AptProps.bathtub(props.Bath, L(-18.1, 0.05, -1.95, "E"), rng)
	AptProps.basinCabinet(props.Bath, L(-15, 0.05, 3.75, "S"), rng)
	AptProps.foldedSheeting(props.Bath, L(-15.2, 0.05, -4.6), rng)
	AptProps.bucket(props.Bath, L(-13.2, 0.05, -4.9), rng, look(M.Plastic, 150, 150, 140), nil)
	AptProps.gloves(props.Bath, L(-13.4, 1.55, -4.9, "E"), rng, look(M.Rubber, 186, 176, 110))
	AptProps.towelRail(props.Bath, L(-17.5, 0, -5.75, "N"), rng)
	AptProps.mould(props.Bath, L(-19.9, CEILING, 2.1), rng)
	for _ = 1, 3 do
		part(
			props.Bath,
			"MissingWallTile",
			V(0.9, 0.9, 0.02),
			L(-19.74, rng:NextNumber(1.5, 4.8), rng:NextNumber(-4.5, 3)) * ANG(0, math.pi / 2, 0),
			look(M.Concrete, 128, 124, 114)
		)
	end

	------------------------------------------------------------------------------
	-- BEDROOM 2 (the cook's room)
	------------------------------------------------------------------------------

	AptProps.mattress(props.Bed2, L(-3.2, 0, 3.9), rng)
	AptProps.alarmClock(props.Bed2, L(0.2, 0, 1.3), rng)
	AptProps.chairClothes(props.Bed2, L(-3.7, 0, 10.2), rng)
	AptProps.deskTable(props.Bed2, L(8.55, 0, 5, "W"), rng)
	AptProps.whiteboard(props.Bed2, L(3, 0, 0.25, "N"), rng)
	AptProps.supplyBoxes(props.Bed2, L(7.9, 0, 10.3, "W"), rng)
	AptProps.calendar(props.Bed2, L(-5.75, 0, 8.8, "E"), rng)
	AptProps.trashBag(props.Bed2, L(-1.6, 0, 10.9), rng)
	AptProps.mould(props.Bed2, L(8.2, CEILING, 10.2), rng)

	------------------------------------------------------------------------------
	-- THE LAB
	------------------------------------------------------------------------------

	local _tent, swayable = AptProps.plasticTent(props.Lab, toWorld, rng)
	-- three of the sheets sway in the fan's draught (client): Anim/Sheet_n, pivot = top edge
	for i, sheet in swayable do
		local holder = Instance.new("Model")
		holder.Name = `Sheet_{i}`
		sheet.Parent = holder
		holder.WorldPivot = sheet.CFrame * CF(0, sheet.Size.Y / 2, 0)
		holder.Parent = anim
	end
	local curtain = AptProps.stripCurtain(anim, L(11.4, 0, 15, "W"), rng, 7)
	curtain.Name = "Curtain"

	-- The vat (same recipe as before, moved into the flat; the client builds the fluid inside).
	local function cylinder(
		name: string,
		diameter: number,
		height: number,
		centre: Vector3,
		l: Look
	): Part
		return part(
			model,
			name,
			V(height, diameter, diameter),
			L(centre.X, centre.Y, centre.Z) * ANG(0, 0, rad(90)),
			l,
			Enum.PartType.Cylinder
		)
	end
	local metal = M.Metal
	cylinder("VatBase", 5, 1, V(20, 0.5, 19.5), AptProps.solid(look(metal, 90, 94, 98)))
	local glass = cylinder(
		"VatGlass",
		4.4,
		8,
		V(20, 5, 19.5),
		AptProps.solid(look(M.Glass, 150, 176, 192, 0.6))
	)
	glass.CastShadow = false
	glass.CanQuery = false -- (prompts and clicks reach the vat's contents through it)
	local cap =
		cylinder("VatCap", 5, 0.8, V(20, 9.4, 19.5), AptProps.solid(look(metal, 70, 72, 76)))
	-- a weak cold light from the cap down into the vat: a rim on the clone (no shadows)
	local rim = Instance.new("SpotLight")
	rim.Name = "VatRimLight"
	rim.Face = Enum.NormalId.Left -- (the cylinder is turned: its -X face looks down)
	rim.Brightness = 0.8
	rim.Range = 9
	rim.Angle = 50
	rim.Color = Color3.fromRGB(200, 225, 245)
	rim.Shadows = false
	rim.Parent = cap
	for _, offset in { -1.2, 1.2 } do
		cylinder("VatPipe", 0.4, 1.4, V(20 + offset, 10.5, 19.5), look(metal, 80, 82, 86))
	end
	marker("VatCore", L(20, 5, 19.5))
	part(model, "VatScreen", V(1.6, 1, 0.1), L(20, 2.4, 17.02), look(M.SmoothPlastic, 20, 22, 24))
	AptProps.vatFrame(props.Lab, L(20, 0, 19.5), rng)

	-- The bench (trolley), its anchor and the cutter's dock.
	AptProps.trolleyBench(props.Lab, L(18, 0, 10.5), rng)
	marker("BenchAnchor", L(18, 3.35, 10.5))
	marker("CutterDock", L(21, 3.5, 11.6))
	AptProps.cutterCharger(props.Lab, L(21, 3.5, 11.6), rng, P(20.5, 0.3, 11.4))
	AptProps.scanCrate(props.Lab, L(13.4, 0, 11.0), rng)
	AptProps.lampStand(props.Lab, P(22.6, 0, 12.6), P(19.5, 8.2, 11), rng)

	-- The chute hatch in the E wall.
	local chuteMouth = CFrame.lookAt(P(27.4, 2.5, 10), P(28.4, 2.5, 10))
	marker("ChuteMouth", chuteMouth)
	AptProps.chuteHatch(props.Lab, chuteMouth, rng)

	-- The stash freezer, the fridge, the pumps, the wire shelving for the cases.
	AptProps.stashFreezer(props.Lab, L(11.8, 0, 21.3, "E"), rng)
	marker("StashShelf", L(11.8, 2.2, 21.3))
	AptProps.labFridge(props.Lab, L(14.5, 0, 22.75), rng)
	AptProps.pumpShelf(props.Lab, L(25.8, 0, 22.6), rng)
	AptProps.wireShelf(props.Lab, L(11.5, 0, 6, "E"), rng)
	marker("RackSpot", L(11.6, 3.3, 6))
	AptProps.trestleTable(props.Lab, L(26.2, 0, 17.4, "W"), rng)
	AptProps.utilitySink(props.Lab, L(13.3, 0, 1.7, "N"), rng)
	local _window, fanBlades = AptProps.foilWindow(props.Lab, L(19, 0, 0.25, "N"), rng)
	fanBlades.Parent = anim
	AptProps.coolerStack(props.Lab, L(26.0, 0, 2.3, "W"), rng)
	AptProps.toolCart(props.Lab, L(23.25, 0, 5.5, "W"), rng)
	AptProps.labLitter(props.Lab, toWorld, rng)

	-- Power strips + drooping cords (the E-wall one is scorched: the spark's source).
	AptProps.powerStrip(
		props.Lab,
		L(13, 1.2, 0.3, "N"),
		rng,
		{ P(17.6, 3.7, 0.6), P(13.4, 2.6, 1.0) },
		false
	)
	AptProps.powerStrip(
		props.Lab,
		L(27.8, 1.2, 15, "W"),
		rng,
		{ P(27.3, 3.9, 16.4), P(27.0, 3.6, 19.8) },
		true
	)
	AptProps.powerStrip(
		props.Lab,
		L(25, 6.5, 23.7, "S"),
		rng,
		{ P(24.9, 3.7, 22.5), P(23.0, 9.4, 21.6) },
		false
	)
	-- the trolley's own cord, taped to the floor from the S-wall strip
	AptProps.cordBundle(
		props.Lab,
		{ P(13.6, 0.07, 0.9), P(15.5, 0.07, 6.0), P(20.5, 0.07, 11.2) },
		{ 1, 1 },
		rng,
		2.5
	)
	-- the tubing loops between the vat and the pumps (clear), the lowest one drips into a pan
	local tubing = look(M.Glass, 210, 225, 220, 0.4)
	AptProps.catenary(
		props.Lab,
		"Tubing",
		P(22.9, 9.6, 21.0),
		P(24.6, 7.1, 22.4),
		0.9,
		5,
		0.15,
		tubing
	)
	AptProps.catenary(
		props.Lab,
		"Tubing",
		P(22.9, 8.8, 18.6),
		P(24.3, 4.0, 21.9),
		0.7,
		5,
		0.15,
		tubing
	)
	AptProps.path(props.Lab, "Tubing", {
		P(22.9, 4.6, 20.6),
		P(23.9, 2.9, 20.9),
		P(25.0, 2.15, 21.0),
		P(25.6, 2.6, 21.3),
		P(24.4, 3.35, 22.0),
	}, 0.15, tubing)
	part(
		props.Lab,
		"DripPan",
		V(0.12, 1.2, 1.2),
		L(25, 0.1, 21) * ANG(0, 0, rad(90)),
		look(M.Metal, 120, 122, 120),
		Enum.PartType.Cylinder
	)
	part(
		props.Lab,
		"PanWater",
		V(0.02, 1.0, 1.0),
		L(25, 0.15, 21) * ANG(0, 0, rad(90)),
		look(M.Glass, 170, 200, 196, 0.4, 0.1),
		Enum.PartType.Cylinder
	)
	-- grime: old stains on the mat, a wet patch under the vat's drip tray, marks on the trolley
	-- top (flat overlays: the top stays clear for the shell), the old bedroom's curtain rail
	-- with a ragged curtain pushed aside, the bedroom's skirting showing under the plastic
	for _, spot in { V(15.5, 0, 7.5), V(22.5, 0, 14.5), V(13.5, 0, 17.5) } do
		AptProps.stain(
			props.Lab,
			L(spot.X, 0.06, spot.Z) * ANG(rad(90), 0, 0),
			Vector2.new(rng:NextNumber(1.6, 2.6), rng:NextNumber(1.2, 2.0)),
			Color3.fromRGB(62, 64, 62),
			rng
		)
	end
	-- the wet patch in front of the vat: three overlapping puddles, not one black slab
	for _, puddle in
		{
			{ size = V(3.0, 0.01, 1.4), at = V(20.0, 0.065, 15.6), turn = 9 },
			{ size = V(2.2, 0.01, 1.0), at = V(22.1, 0.066, 14.8), turn = -14 },
			{ size = V(1.4, 0.01, 0.8), at = V(18.3, 0.067, 14.6), turn = 27 },
		}
	do
		part(
			props.Lab,
			"WetPatch",
			puddle.size,
			L(puddle.at.X, puddle.at.Y, puddle.at.Z) * ANG(0, rad(puddle.turn), 0),
			look(M.Glass, 70, 92, 90, 0.65, 0.3)
		)
	end
	AptProps.bedroomLeftovers(props.Lab, toWorld, rng)
	for _, mark in { CF(15.6, 3.351, 10.0), CF(19.2, 3.351, 11.3) } do
		part(
			props.Lab,
			"TopStain",
			V(rng:NextNumber(0.8, 1.4), 0.005, rng:NextNumber(0.5, 0.9)),
			toWorld(mark * ANG(0, rng:NextNumber(0, 3), 0)),
			look(M.Metal, 132, 136, 136)
		)
	end
	part(
		props.Lab,
		"CurtainRail",
		V(7.6, 0.12, 0.12),
		L(19, 8.0, 0.75),
		look(M.Metal, 120, 110, 90)
	)
	part(
		props.Lab,
		"OldCurtain",
		V(1.2, 6.2, 0.25),
		L(23.0, 4.9, 0.8) * ANG(0, 0, rad(2)),
		look(M.Fabric, 96, 70, 76)
	)
	part(
		props.Lab,
		"OldCurtain",
		V(0.9, 5.4, 0.25),
		L(14.9, 5.3, 0.8) * ANG(rad(2), 0, rad(-3)),
		look(M.Fabric, 90, 66, 72)
	)
	AptProps.skirting(props.Lab, wallFrame(10.25, 0, 0.25, X_PLUS), 12.1, rng)
	AptProps.skirting(props.Lab, wallFrame(10.25, 0, 17.65, X_PLUS), 6.35, rng)
	AptProps.skirting(props.Lab, wallFrame(28, 0, 24, X_MINUS), 24, rng)
	-- the tube light hangs on two chains
	for _, x in { 16, 20 } do
		part(props.Lab, "Chain", V(0.05, 1.05, 0.05), L(x, 10.45, 13), look(M.Metal, 110, 110, 106))
	end

	------------------------------------------------------------------------------
	-- LIGHTS (Fixtures; V animates the flicker and toggles)
	------------------------------------------------------------------------------

	type LightSpec = {
		class: "PointLight" | "SpotLight" | "SurfaceLight",
		color: Color3,
		brightness: number,
		range: number,
		angle: number?,
		face: Enum.NormalId?,
		shadows: boolean,
		enabled: boolean?,
	}
	local function addLight(target: BasePart, spec: LightSpec): Light
		local light: Light
		if spec.class == "SpotLight" then
			local spot = Instance.new("SpotLight")
			spot.Angle = spec.angle or 90
			spot.Face = spec.face or Enum.NormalId.Front
			spot.Range = spec.range
			light = spot
		elseif spec.class == "SurfaceLight" then
			local surface = Instance.new("SurfaceLight")
			surface.Angle = spec.angle or 90
			surface.Face = spec.face or Enum.NormalId.Front
			surface.Range = spec.range
			light = surface
		else
			local point = Instance.new("PointLight")
			point.Range = spec.range
			light = point
		end
		light.Name = "Light"
		light.Color = spec.color
		light.Brightness = spec.brightness
		light.Shadows = spec.shadows
		light.Enabled = spec.enabled ~= false
		light.Parent = target
		return light
	end
	local function rgb(r: number, g: number, b: number): Color3
		return Color3.fromRGB(r, g, b)
	end
	-- A bare bulb (Neon ball) on a flex from the ceiling.
	local function bulb(
		parent: Instance,
		name: string,
		x: number,
		y: number,
		z: number,
		glow: Color3
	): Part
		local made = part(
			parent,
			name,
			V(0.35, 0.35, 0.35),
			L(x, y, z),
			look(M.Neon, 0, 0, 0),
			Enum.PartType.Ball
		)
		made.Color = glow
		return made
	end

	-- Entry: the pendant (Anim/Pendant; it swings, its shadows swing with it).
	local pendant = Instance.new("Model")
	pendant.Name = "Pendant"
	AptProps.rod(
		pendant,
		"Flex",
		P(-8, CEILING, -19),
		P(-8, 8.85, -19),
		0.04,
		look(M.Plastic, 40, 36, 32)
	)
	part(
		pendant,
		"Holder",
		V(0.3, 0.26, 0.26),
		L(-8, 8.85, -19) * ANG(0, 0, rad(90)),
		look(M.Plastic, 150, 120, 80),
		Enum.PartType.Cylinder
	)
	local pendantBulb = bulb(pendant, "Bulb", -8, 8.6, -19, rgb(255, 196, 140))
	pendantBulb:SetAttribute("Flicker", "None")
	addLight(pendantBulb, {
		class = "PointLight",
		color = rgb(255, 166, 90),
		brightness = 0.9,
		range = 14,
		shadows = true,
	})
	pendant.WorldPivot = L(-8, CEILING, -19)
	pendant.Parent = anim
	part(
		props.Entry,
		"CeilingRose",
		V(0.1, 0.5, 0.5),
		L(-8, CEILING - 0.05, -19) * ANG(0, 0, rad(90)),
		look(M.Plaster, 170, 164, 148),
		Enum.PartType.Cylinder
	)

	-- Living: the kitchen strip under the wall cabinet, the sodium street lamp through the blind.
	local kitchenStrip = part(
		fixtures,
		"KitchenStrip",
		V(3, 0.08, 0.15),
		L(-25, 6.04, -6.95),
		look(M.Neon, 235, 225, 190)
	)
	kitchenStrip:SetAttribute("Flicker", "None")
	addLight(kitchenStrip, {
		class = "PointLight",
		color = rgb(235, 225, 190),
		brightness = 0.35,
		range = 9,
		shadows = false,
	})
	local sodium = part(
		fixtures,
		"BlindSodium",
		V(0.5, 0.5, 0.5),
		CFrame.lookAt(P(-20.5, 9, -27.5), P(-21, 0, -15)),
		look(M.SmoothPlastic, 0, 0, 0, 1)
	)
	sodium.CastShadow = false
	sodium:SetAttribute("Flicker", "None")
	addLight(sodium, {
		class = "SpotLight",
		color = rgb(255, 140, 60),
		brightness = 0.85, -- (strong enough for the blind's stripes to land on the floor)
		range = 22,
		angle = 45,
		face = Enum.NormalId.Front,
		shadows = true,
	})

	-- Corridor: the flickering bulb (A), the bend bulb in its cracked shade.
	AptProps.rod(
		props.Corridor,
		"Flex",
		P(-9, CEILING, -1),
		P(-9, 10.4, -1),
		0.04,
		look(M.Plastic, 220, 216, 204)
	)
	local corridorBulb = bulb(fixtures, "CorridorBulb", -9, 10.2, -1, rgb(255, 190, 130))
	corridorBulb:SetAttribute("Flicker", "Bulb")
	addLight(corridorBulb, {
		class = "PointLight",
		color = rgb(255, 160, 85),
		brightness = 0.55,
		range = 12, -- (leaves a dark gap before the bend bulb: depth)
		shadows = true,
	})
	local bendBulb = bulb(fixtures, "BendBulb", -9, 10.1, 15, rgb(255, 196, 140))
	bendBulb:SetAttribute("Flicker", "None")
	addLight(bendBulb, {
		class = "PointLight",
		color = rgb(255, 170, 100),
		brightness = 0.4,
		range = 11,
		shadows = true,
	})
	-- (the shade is see-through enough not to cast a shadow; one wedge of it is broken off)
	for i = 1, 5 do
		local angle = i * (2 * math.pi / 6)
		part(
			props.Corridor,
			"Shade",
			V(0.62, 0.7, 0.05),
			L(-9, 10.35, 15) * ANG(0, angle, 0) * CF(0, 0, -0.55) * ANG(rad(-25), 0, 0),
			look(M.SmoothPlastic, 220, 200, 160, 0.35)
		)
	end

	-- Bath: the mirror light (rare stutter), the spill through the door onto the corridor.
	local bathMirror = part(
		fixtures,
		"BathMirror",
		V(1.6, 0.15, 0.2),
		L(-15, 7.45, 3.5),
		look(M.Neon, 220, 235, 200)
	)
	bathMirror:SetAttribute("Flicker", "Rare")
	addLight(bathMirror, {
		class = "PointLight",
		color = rgb(220, 235, 200),
		brightness = 0.6,
		range = 7,
		shadows = false,
	})
	local bathSpill = part(
		fixtures,
		"BathSpill",
		V(0.3, 0.3, 0.3),
		CFrame.lookAt(
			P(-12.6, 7.4, -1),
			P(-12.6, 7.4, -1) + V(math.cos(rad(40)), -math.sin(rad(40)), 0)
		),
		look(M.SmoothPlastic, 0, 0, 0, 1)
	)
	bathSpill.CastShadow = false
	bathSpill:SetAttribute("Flicker", "None")
	bathSpill:SetAttribute("Follows", "BathMirror")
	addLight(bathSpill, {
		class = "SpotLight",
		color = rgb(225, 235, 205),
		brightness = 0.8,
		range = 10,
		angle = 70,
		face = Enum.NormalId.Front,
		shadows = false,
	})

	-- Bed2: the desk lamp.
	local deskLamp = part(
		fixtures,
		"DeskLamp",
		V(0.3, 0.3, 0.3),
		L(8.15, 4.4, 3.1) * ANG(rad(-90), 0, 0),
		look(M.Neon, 255, 200, 140, 0.4)
	)
	deskLamp:SetAttribute("Flicker", "None")
	addLight(deskLamp, {
		class = "SpotLight",
		color = rgb(255, 180, 110),
		brightness = 0.8,
		range = 10,
		angle = 60,
		face = Enum.NormalId.Front,
		shadows = false,
	})

	-- Bed3: the mysterious light under the boarded door (toggles on and off).
	local bed3Line = part(
		fixtures,
		"Bed3DoorLine",
		V(0.04, 0.04, 3.6),
		L(-11.8, 0.05, 8),
		look(M.Neon, 255, 190, 120)
	)
	bed3Line:SetAttribute("Flicker", "Toggle")
	addLight(bed3Line, {
		class = "SurfaceLight",
		color = rgb(255, 190, 120),
		brightness = 0.2,
		range = 4,
		angle = 90,
		face = Enum.NormalId.Right,
		shadows = false,
	})

	-- The lab door: a cold teal line under it and down its latch side (the discovery cue).
	local glowLook = look(M.Neon, 120, 220, 205)
	local doorGlow = part(fixtures, "LabDoorGlow", V(0.05, 0.05, 4.3), L(9.85, 0.04, 15), glowLook)
	doorGlow:SetAttribute("Flicker", "None")
	addLight(doorGlow, {
		class = "SurfaceLight",
		color = rgb(130, 225, 215),
		brightness = 0.55,
		range = 8,
		angle = 90,
		face = Enum.NormalId.Left,
		shadows = false,
	})
	part(doorGlow, "LatchLine", V(0.05, 7.2, 0.05), L(9.85, 3.7, 12.85), glowLook)

	-- The lab: the tube (shadows), the work lamp, the aquarium strip, the monitor glow, a fill.
	local tube =
		part(model, "TubeLight", V(5, 0.3, 0.4), L(18, 9.8, 13), look(M.Neon, 205, 235, 228))
	tube.CastShadow = false
	tube:SetAttribute("Flicker", "Tube")
	addLight(tube, {
		class = "SurfaceLight",
		color = rgb(205, 235, 228),
		brightness = 1.0, -- (the vat is the key light; the tube only fills)
		range = 14,
		angle = 120,
		face = Enum.NormalId.Bottom,
		shadows = true,
	})
	part(props.Lab, "TubeHousing", V(5.2, 0.15, 0.6), L(18, 10.0, 13), look(M.Metal, 150, 152, 150))
	local aquarium = part(
		fixtures,
		"AquariumStrip",
		V(3, 0.06, 0.1),
		L(25.8, 5.3, 22.4),
		look(M.Neon, 90, 200, 190)
	)
	aquarium:SetAttribute("Flicker", "None")
	addLight(aquarium, {
		class = "SurfaceLight",
		color = rgb(90, 200, 190),
		brightness = 0.6,
		range = 6,
		angle = 100,
		face = Enum.NormalId.Bottom,
		shadows = false,
	})
	local fill =
		part(fixtures, "LabFill", V(0.2, 0.2, 0.2), L(21, 8, 12), look(M.SmoothPlastic, 0, 0, 0, 1))
	fill.CastShadow = false
	fill:SetAttribute("Flicker", "None")
	addLight(fill, {
		class = "PointLight",
		color = rgb(150, 175, 175),
		brightness = 0.12,
		range = 9,
		shadows = false,
	})
	-- the vat's own teal glow from inside the glass: the room's key light
	local vatGlow = part(
		fixtures,
		"VatGlow",
		V(0.2, 0.2, 0.2),
		L(20, 4, 19.5),
		look(M.SmoothPlastic, 0, 0, 0, 1)
	)
	vatGlow.CastShadow = false
	vatGlow:SetAttribute("Flicker", "None")
	addLight(vatGlow, {
		class = "PointLight",
		color = rgb(80, 200, 190),
		brightness = 0.5,
		range = 9,
		shadows = false,
	})
	-- Bed2: the alarm clock's digits throw a faint orange glow on the mattress
	local clockGlow = part(
		fixtures,
		"ClockGlow",
		V(0.1, 0.1, 0.1),
		L(0.2, 1.6, 1.0),
		look(M.SmoothPlastic, 0, 0, 0, 1)
	)
	clockGlow.CastShadow = false
	clockGlow:SetAttribute("Flicker", "None")
	addLight(clockGlow, {
		class = "PointLight",
		color = rgb(255, 150, 60),
		brightness = 0.15,
		range = 4,
		shadows = false,
	})
	local fridgeLight = part(
		fixtures,
		"FridgeLight",
		V(0.2, 0.2, 0.2),
		L(-17.5, 5.2, -7.0),
		look(M.SmoothPlastic, 0, 0, 0, 1)
	)
	fridgeLight.CastShadow = false
	fridgeLight:SetAttribute("Flicker", "None")
	addLight(fridgeLight, {
		class = "PointLight",
		color = rgb(235, 240, 255),
		brightness = 0.5,
		range = 6,
		shadows = false,
		enabled = false,
	})

	-- Move the contract parts the prop builders made to the model's root.
	local function promote(name: string): BasePart?
		local found = model:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then
			found.Parent = model
			return found
		end
		warn(`[Contraband] LabBuilder: {name} was not built`)
		return nil
	end
	promote("ChargerLed")
	promote("ScanScreen")
	promote("RackStencil")
	promote("ChuteFlap")
	local lampHead = promote("LampHead")
	if lampHead then
		lampHead:SetAttribute("Flicker", "None")
		addLight(lampHead, {
			class = "SpotLight",
			color = rgb(255, 244, 228),
			brightness = 1.2, -- (1.8 blew the shell out to white; the client dims it to 1.0 while extracting)
			range = 10,
			angle = 45,
			face = Enum.NormalId.Left,
			shadows = false,
		})
	end
	local monitor = promote("MonitorScreen")
	if monitor then
		local glow = Instance.new("SurfaceLight")
		glow.Name = "MonitorGlow"
		glow.Face = Enum.NormalId.Front
		glow.Color = rgb(120, 190, 170)
		glow.Brightness = 0.3
		glow.Range = 5
		glow.Angle = 90
		glow.Shadows = false
		glow.Parent = monitor
	end

	------------------------------------------------------------------------------
	-- Rooms (client room lookup), Fx and Sfx hosts
	------------------------------------------------------------------------------

	local function room(name: string, x0: number, z0: number, x1: number, z1: number)
		host(
			roomsFolder,
			name,
			V(x1 - x0, CEILING, z1 - z0),
			L((x0 + x1) / 2, CEILING / 2, (z0 + z1) / 2)
		)
	end
	room("Entry", -12, -24, -4, -14)
	room("Living", -28, -24, -12, -6)
	room("Corridor", -12, -14, -6, 12)
	room("Corridor", -12, 12, 10, 18)
	room("Bath", -20, -6, -12, 4)
	room("Bed2", -6, 0, 10, 12)
	room("Lab", 10, 0, 28, 24)

	local function fxHost(
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		zone: string,
		kind: string
	): Part
		local made = host(fx, name, size, L(x, y, z))
		made:SetAttribute("Zone", zone)
		made:SetAttribute("Kind", kind)
		return made
	end
	-- (directional emitters: an Attachment "Aim" whose +Y points the way particles go)
	local function aim(target: Part, direction: Vector3)
		local attachment = Instance.new("Attachment")
		attachment.Name = "Aim"
		local up = direction.Unit
		local side = if math.abs(up.Y) > 0.9
			then Vector3.xAxis
			else Vector3.new(0, 1, 0):Cross(up).Unit
		attachment.CFrame = CFrame.fromMatrix(Vector3.zero, side, up)
		attachment.Parent = target
		target:SetAttribute("Aim", direction.Unit)
	end
	aim(fxHost("Dust_Threshold", V(4, 0.3, 1), -8, 0.2, -23.2, "Entry", "Burst"), Z_PLUS)
	fxHost("Motes_Entry", V(5, 4, 5), -8, 6, -19, "Entry", "Motes")
	fxHost("Motes_Corridor", V(5, 4, 5), -9, 7, -1, "Corridor", "Motes"):SetAttribute(
		"Fixture",
		"CorridorBulb"
	)
	fxHost("Drip_Corridor", V(0.2, 0.2, 0.2), -8.4, 10.4, 5.2, "Corridor", "Drip"):SetAttribute(
		"LandAt",
		P(-8.4, 0.8, 5.2)
	)
	aim(fxHost("Vapour_LabDoor", V(0.4, 0.2, 3.6), 9.6, 0.1, 15, "Corridor", "Vapour"), X_MINUS)
	fxHost("Motes_Bend", V(4, 3, 4), -9, 7, 15, "Corridor", "Motes")
	fxHost("Motes_LabDoor", V(3, 2, 3), 7.5, 2, 15, "Corridor", "Motes")
	aim(fxHost("Bubbles_Tank", V(0.6, 0.1, 0.6), 25.8, 5.82, 22.6, "Lab", "Bubbles"), Vector3.yAxis)
	aim(fxHost("Mist_Freezer", V(0.3, 0.1, 4.2), 12.95, 3.0, 21.3, "Lab", "Mist"), X_PLUS)
	fxHost("Motes_Lamp", V(3, 3, 3), 19, 5.5, 11, "Lab", "Motes")
	fxHost("Spark_Strip", V(0.3, 0.1, 0.3), 27.5, 1.2, 15.5, "Lab", "Spark")
	fxHost("Drip_Lab", V(0.2, 0.2, 0.2), 25, 2.0, 21, "Lab", "Drip"):SetAttribute(
		"LandAt",
		P(25, 0.16, 21)
	)
	fxHost("Breath_Floor", V(14, 0.2, 18), 19, 0.15, 12, "Lab", "Haze")

	local function sound(
		name: string,
		x: number,
		y: number,
		z: number,
		soundSlot: string,
		zone: string,
		minD: number,
		maxD: number,
		volume: number,
		kind: string,
		pitch: number?
	)
		local made = host(sfx, name, V(0.5, 0.5, 0.5), L(x, y, z))
		made:SetAttribute("Slot", soundSlot)
		made:SetAttribute("Zone", zone)
		made:SetAttribute("Min", minD)
		made:SetAttribute("Max", maxD)
		made:SetAttribute("Volume", volume)
		made:SetAttribute("Pitch", pitch or 1)
		made:SetAttribute("Type", kind)
		return made
	end
	sound("Neighbours", 0, 5, -19, "AptNeighbours", "Neighbour", 4, 30, 1, "Loop")
	sound("KitchenFridge", -17.5, 1, -6.4, "LabFridgeHum", "Living", 3, 18, 0.8, "Loop")
	sound("CorridorBulb", -9, 10.2, -1, "LabFluoBuzz", "Corridor", 2, 12, 0.35, "Loop"):SetAttribute(
		"Fixture",
		"CorridorBulb"
	)
	sound("BathTap", -15, 3, 3.5, "LabDrip", "Bath", 2, 14, 0.6, "Random")
	sound("CorridorDrip", -8.4, 0.8, 5.2, "LabDrip", "Corridor", 2, 16, 1, "Synced")
	sound("VatHum", 20, 1, 19.5, "VatHum", "Lab", 5, 40, 1, "Loop")
	sound("TubeBuzz", 18, 9.8, 13, "LabFluoBuzz", "Lab", 3, 16, 1, "Loop"):SetAttribute(
		"Fixture",
		"TubeLight"
	)
	sound("LabFridge", 14.5, 1, 22.8, "LabFridgeHum", "Lab", 3, 18, 1, "Loop")
	sound("FreezerHum", 11.8, 0.8, 21.3, "LabFridgeHum", "Lab", 3, 14, 0.7, "Loop", 0.85)
	sound("Pumps", 25.8, 3.6, 22.6, "LabPumpBubble", "Lab", 3, 18, 1, "Loop")
	sound("LabDripPan", 25, 0.2, 21, "LabDrip", "Lab", 2, 14, 0.7, "Synced")
	sound("Spark", 27.5, 1.2, 15.5, "LabSpark", "Lab", 2, 16, 1, "Synced")
	sound("MonitorBeep", 26.9, 4.55, 17, "VatReadyChime", "Lab", 3, 20, 1, "Event")

	------------------------------------------------------------------------------
	-- Markers for arriving
	------------------------------------------------------------------------------

	marker("Spawn", CFrame.lookAt(P(-8, 3, -21), P(-8, 3, -18)))

	return model
end

-- Is `position` inside the box of the flat at `slot` (grown by `margin` studs)?
function LabBuilder.contains(slot: number, position: Vector3, margin: number): boolean
	local centre = LabBuilder.origin(slot).Position + Vector3.new(0, LabBuilder.CENTRE_HEIGHT, 0)
	local offset = position - centre
	local half = LabBuilder.HALF_SIZE + Vector3.one * margin
	return math.abs(offset.X) <= half.X
		and math.abs(offset.Y) <= half.Y
		and math.abs(offset.Z) <= half.Z
end

return table.freeze(LabBuilder)
