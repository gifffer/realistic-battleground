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
--   VatCore, VatPromptPoint, VatGlass, VatBase, VatCap (+ VatRimLight), VatScreen: made by
--                  VatBuilder (see its header)
--   BenchAnchor    invisible, IDENTITY rotation, on the trolley top: the shell lies along +X.
--                  BenchLayout.buildStatic puts its static kit there (Props_Lab > BenchKit:
--                  underpad, instrument + specimen trays, the cold pass-box at the +X end)
--   CutterDock     invisible, identity: the scalpel's rest on the instrument tray
--   ChargerLed     the LED of the UV blade steriliser on the S-wall sterilising worktop (Neon)
--   ScanScreen     the scanner CRT's glass, on the stash freezer's lid (Front face = -Z)
--   MonitorScreen  the station CRT's glass on the trestle (Front face = -X)
--   ChuteMouth     invisible, the biomass bin's mouth at the table's W end (LookVector = into
--                  the bin, -X)
--   ChuteFlap      the bin's lid (swung up against the wall)
--   RackSpot       invisible, on the dispatch rack by the S wall (Take case); RackStencil "BX-7"
--   StashShelf     invisible, identity, INSIDE the clear-lid stash freezer (capsules sit on it)
--   TubeLight      the lab's fluorescent tube (SurfaceLight "Light", shadows, attr Flicker "Tube")
--   LampHead       the work lamp's head over the bench (SpotLight "Light")
--
-- FOLDERS (contracts with ApartmentController / ApartmentAmbienceController, see DESIGN §1.4):
--   Rooms     invisible boxes named Entry, Living, Corridor (×2), Bath, Bed2, Lab
--   Doors     Models Door_<Room>: Leaf (PrimaryPart, SOLID), WorldPivot = hinge line on the floor
--             (on the leaf's face that leads the swing, see AptProps.door);
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
-- Z-FIGHTING: no two visible faces share a plane. Flat details are AptProps overlays at fixed
-- levels (AptProps.LAYER); the floor stacks are layered (see the floors below); panels butt.
--
-- BUDGET: ~1600 parts (measured 1587 per flat; one flat per player who has entered), 5
-- shadow-casting lights (entry pendant, blind sodium, corridor bulb, bend bulb, lab tube);
-- every other light has a small Range (Future lights without shadows shine through walls).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local AptProps = require(script.Parent.AptProps)
local VatBuilder = require(script.Parent.VatBuilder)
local BenchLayout = require(ReplicatedStorage.Shared.Contraband.BenchLayout)

type Look = AptProps.Look

local LabBuilder = {}

-- Half sizes of the flat's box (outer walls and slabs included), for "is someone inside?".
LabBuilder.HALF_SIZE = Vector3.new(29.5, 7, 25.5)
LabBuilder.CENTRE_HEIGHT = 5.5 -- the box centre is this far above the floor top

local CEILING = 11 -- the ceiling's underside
local LAB_FLOOR = 0.08 -- the top of the lab's floor plastic (things on the lab floor stand here)
local DOOR_WIDTH = 4.5
local DOOR_HEIGHT = 7.5

local M = Enum.Material
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local look = AptProps.look
local part = AptProps.part
local CORD_WHITE_LOOK = AptProps.look(Enum.Material.Plastic, 170, 166, 154)

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
	-- (the screed shows in the missing tiles' holes: 0..0.03, tiles 0.03..0.07)
	part(shell, "Screed", V(8, 0.03, 10), L(-8, 0.015, -19), look(M.Concrete, 100, 98, 92))
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
					V(1.96, 0.04, 1.96),
					L(tx, 0.05, tz) * lift,
					AptProps.tint(tileLook, rng, 4)
				)
			end
		end
	end
	-- Bath: ceramic floor (its missing tiles are the overlays with the bathroom's props).
	part(shell, "BathFloor", V(8, 0.05, 10), L(-16, 0.025, -1), look(M.CeramicTiles, 176, 180, 170))
	-- Lab: the old bedroom carpet still shows along the W and S walls (a band with its wooden
	-- tack strip); the rest is a grey rubber mat with clear plastic sheets taped down over it.
	-- Each layer has its own height (no two layers share a plane): carpet 0..0.03, tack strip
	-- 0..0.08, mat 0..0.05, plastic 0.05..LAB_FLOOR (0.08), tape LAB_FLOOR..+0.03. The plastic
	-- sheets BUTT (no overlap, no tilt) and the tape covers the joins.
	local carpet = look(M.Fabric, 92, 78, 70)
	part(shell, "OldCarpet", V(0.8, 0.03, 23.75), L(10.65, 0.015, 12.125), carpet)
	part(shell, "OldCarpet", V(16.95, 0.03, 0.8), L(19.525, 0.015, 0.65), carpet)
	local tack = look(M.Wood, 104, 86, 62)
	part(shell, "TackStrip", V(0.12, 0.08, 22.9), L(11.0, 0.04, 12.55), tack)
	part(shell, "TackStrip", V(16.9, 0.08, 0.12), L(19.5, 0.04, 1.0), tack)
	part(
		shell,
		"LabMat",
		V(16.95, 0.05, 22.95),
		L(19.525, 0.025, 12.525),
		look(M.Rubber, 46, 48, 48)
	)
	for i = 0, 3 do
		local sheet = part(
			shell,
			"FloorPlastic",
			V(4.15, LAB_FLOOR - 0.05, 22.3),
			L(11.1 + 4.15 * (i + 0.5), (0.05 + LAB_FLOOR) / 2, 12.25),
			look(M.SmoothPlastic, 200, 210, 210, 0.6, 0.08)
		)
		sheet.CastShadow = false
	end
	-- the tape on the plastic's joins: short torn pieces, a little crooked, with gaps
	for i = 1, 3 do
		local z = 1.2 + rng:NextNumber(0, 0.6)
		-- (the first join runs under the media fridge from z 21.5: the tape stops before it)
		local tapeEnd = if i == 1 then 21.3 else 23.3
		while z < tapeEnd - 0.1 do
			local length = math.min(rng:NextNumber(4.5, 7), tapeEnd - z)
			AptProps.overlay(
				shell,
				"FloorTape",
				Vector2.new(0.22, length),
				L(11.1 + 4.15 * i, LAB_FLOOR, z + length / 2)
					* ANG(0, rad(rng:NextNumber(-1.5, 1.5)), 0)
					* ANG(rad(90), 0, 0),
				AptProps.LAYER.STEP,
				look(M.Fabric, 72, 74, 70)
			)
			z += length + rng:NextNumber(0.4, 1.4)
		end
	end

	-- Skirting runs: { x0, z0, x1, z1, out } on the wall faces of the warm rooms.
	-- (`skip`: stretches of the run, in studs from its start, with no wallpaper: a window)
	type Run = { a: Vector3, b: Vector3, out: Vector3, room: string, skip: { NumberRange }? }
	local X_PLUS, X_MINUS, Z_PLUS, Z_MINUS =
		Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis
	local runs: { Run } = {
		-- entry
		{ a = V(-11.75, 0, -24), b = V(-10.65, 0, -24), out = Z_PLUS, room = "Entry" },
		{ a = V(-5.35, 0, -24), b = V(-4.25, 0, -24), out = Z_PLUS, room = "Entry" },
		{ a = V(-4.25, 0, -24), b = V(-4.25, 0, -14.25), out = X_MINUS, room = "Entry" },
		-- living
		{
			a = V(-28, 0, -24),
			b = V(-12.25, 0, -24),
			out = Z_PLUS,
			room = "Living",
			skip = { NumberRange.new(4.4, 12.1) }, -- (the blind window, frame included)
		},
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
	-- Two runs meet at an inside corner: the run on the X-facing wall stops short there (by each
	-- element's depth, see AptProps.skirting) and butts against the other one.
	local function endsOnZRun(point: Vector3): boolean
		for _, other in runs do
			if math.abs(other.out.Z) > 0.5 and math.abs(other.a.Z - point.Z) < 0.01 then
				local lo = math.min(other.a.X, other.b.X) - 0.01
				local hi = math.max(other.a.X, other.b.X) + 0.01
				if point.X >= lo and point.X <= hi then
					return true
				end
			end
		end
		return false
	end
	for _, run in runs do
		local along = run.out:Cross(Vector3.yAxis)
		local a, b = run.a, run.b
		if (b - a):Dot(along) < 0 then
			a, b = b, a
		end
		local length = (b - a).Magnitude
		local frame = wallFrame(a.X, 0, a.Z, run.out)
		local parent = props[run.room] or shell
		local facesX = math.abs(run.out.X) > 0.5
		AptProps.skirting(
			parent,
			frame,
			length,
			rng,
			run.room == "Corridor" or run.room == "Entry",
			facesX and endsOnZRun(a),
			facesX and endsOnZRun(b)
		)
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
				run.skip,
				if dado then 3.56 else nil
			)
		end
	end

	-- Stains: the hand-height band along corridor A, damp by the bath door, a halo over the
	-- living room radiator, one by the Bed1 door.
	local corridorColor = CORRIDOR.look.color
	for _, z in { -13, -3.5, 2.5, 8.5 } do
		AptProps.stain(
			props.Corridor,
			wallFrame(-6.25, 2.4, z, X_MINUS),
			Vector2.new(1.6, 0.9),
			corridorColor,
			rng
		)
	end
	AptProps.stain(
		props.Corridor,
		wallFrame(-11.75, 1.2, 2.9, X_PLUS),
		Vector2.new(1.8, 1.6),
		corridorColor,
		rng
	)
	AptProps.stain(
		props.Corridor,
		wallFrame(-11.75, 1.0, -4.6, X_PLUS),
		Vector2.new(1.4, 1.2),
		corridorColor,
		rng
	)
	-- hand grime round the latch side of the Bed1 and bathroom doors
	AptProps.stain(
		props.Corridor,
		wallFrame(-6.25, 2.6, -5.75, X_MINUS),
		Vector2.new(0.9, 1.2),
		corridorColor,
		rng
	)
	AptProps.stain(
		props.Corridor,
		wallFrame(-11.75, 2.6, -4.15, X_PLUS),
		Vector2.new(0.9, 1.2),
		corridorColor,
		rng
	)
	-- a wavy damp tide-mark rising from the skirting beside the bathroom door
	for i = 0, 4 do
		local height = 0.7 + math.sin(i * 1.7) * 0.25 + rng:NextNumber(0, 0.15)
		-- (marks over the damp stain: the MARK level; side by side, they butt)
		AptProps.overlay(
			props.Corridor,
			"TideMark",
			Vector2.new(0.55, height),
			wallFrame(-11.75, 0.55 + height / 2, -6.4 + i * 0.55 + 0.275, X_PLUS),
			AptProps.LAYER.MARK,
			look(M.Plaster, 96, 90, 70)
		)
	end
	AptProps.stain(
		props.Living,
		wallFrame(-14.5, 4.2, -24, Z_PLUS),
		Vector2.new(3, 1.6),
		LIVING.look.color,
		rng
	)
	AptProps.stain(
		props.Bed2,
		wallFrame(-5.75, 9.0, 6, X_PLUS),
		Vector2.new(2.5, 2.2),
		BED2.look.color,
		rng
	)

	------------------------------------------------------------------------------
	-- Doors
	------------------------------------------------------------------------------

	-- A door in a doorway centred at (x, z), swinging toward `into` (a world-axis direction).
	-- The hinge line is on the wall's `into` face (a 0.5 wall: 0.25 from its middle): shut, the
	-- leaf fills the `into` half of the wall; open, it lies inside the doorway's width, clear of
	-- the casing (see AptProps.door).
	local function makeDoor(
		name: string,
		x: number,
		z: number,
		into: Vector3,
		spec: AptProps.DoorSpec
	): Model
		local along = into:Cross(Vector3.yAxis) -- (from the hinge to the latch)
		local centre = V(x, 0, z)
		local hingePos = centre - along * (AptProps.DOOR_LEAF.width / 2) + into * 0.25
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
		floor = 0.05, -- (the bathroom's tiled floor)
	})
	-- (on the leaf's face that swings away from the basin: on the other one the robe went
	-- into the basin cabinet and the mirror at the door's 95° rest)
	AptProps.doorTowelHook(bathDoor, 1)
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
		openAngle = 94, -- (past 96° the leaf cut into the casing)
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
		openAngle = 90, -- (past 90° the foil tape on its hinge side touched the casing)
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
	-- (the bathroom door stays wide open: the garden hose runs out under it)
	setRest(bathDoor, 95)
	setRest(bed2Door, 30)
	setRest(labDoor, 14)

	-- The front door (not in Doors: it never swings; "Leave" is on it).
	-- (its bottom clears the entry tiles, top 0.07; its top clears the casing's head)
	part(
		model,
		"ExitDoor",
		V(4.4, 7.36, 0.25),
		L(-8, 0.09 + 7.36 / 2, -23.85),
		AptProps.solid(look(M.Wood, 70, 52, 40))
	)
	AptProps.frontDoorDetails(props.Entry, L(-8, 0, -23.85, "N"), rng)

	------------------------------------------------------------------------------
	-- ENTRY
	------------------------------------------------------------------------------

	-- (things on the entry floor stand on the tiles, top 0.07)
	AptProps.mailHeap(props.Entry, L(-7.2, 0.07, -22.8, "N"), rng)
	AptProps.coatHooks(props.Entry, L(-4.25, 0, -22.4, "W"), rng)
	AptProps.keyHook(props.Entry, L(-4.25, 0, -20.3, "W"), rng)
	-- a worn doormat, kicked a little way in by the door (it lies ON the tiles, top 0.07)
	part(
		props.Entry,
		"Doormat",
		V(2.6, 0.04, 1.6),
		L(-8.3, 0.09, -21.0) * ANG(0, rad(5), 0),
		look(M.Fabric, 64, 56, 48)
	)
	AptProps.shoePile(props.Entry, L(-9.95, 0.07, -23.0, "N"), rng)
	-- a tied bin bag waiting by the door to go down (it never does)
	AptProps.trashBag(props.Entry, L(-5.1, 0.07, -22.6), rng)
	local _cupboard, cordExit = AptProps.meterCupboard(props.Entry, L(-4.25, 0, -16.25, "W"), rng)
	AptProps.mirror(props.Entry, L(-11.75, 0, -22.8, "E"), rng)
	AptProps.lightSwitch(props.Entry, L(-11.2, 0, -24, "N"), rng)

	------------------------------------------------------------------------------
	-- LIVING ROOM + KITCHENETTE
	------------------------------------------------------------------------------

	-- (the sofa, the rug, the low table and the TV share one axis, Z -15.2: he watches it
	-- straight on; the eating corner is by the kitchen, the walk from the arch stays free)
	local tvAxis = -15.2
	AptProps.sofa(props.Living, L(-25.95, 0, tvAxis, "E"), rng)
	AptProps.rug(
		props.Living,
		L(-22, 0, tvAxis),
		rng,
		Vector2.new(5, 4.2),
		look(M.Fabric, 58, 56, 64)
	)
	AptProps.lowTable(props.Living, L(-22, 0.09, tvAxis, "W"), rng)
	AptProps.crtTV(props.Living, L(-13.5, 0, tvAxis, "W"), rng)
	AptProps.floorLamp(props.Living, L(-27.2, 0, -19.6), rng)
	AptProps.wallClock(props.Living, L(-28, 7.0, tvAxis, "E"), rng)
	AptProps.blindWindow(props.Living, L(-20.5, 0, -24, "N"), rng)
	-- (no laundry airer: in front of the window it read as a dark slab and blocked the room)
	-- the kitchen run along the N wall: counter + sink, the cooker, the fridge, the bin
	AptProps.kitchenCounter(props.Living, L(-24.9, 0, -7.45), rng)
	AptProps.cooker(props.Living, L(-20.7, 0, -7.4), rng)
	AptProps.oldFridge(props.Living, L(-18.3, 0, -7.35), rng)
	-- (the door's hinge line is on its outer face, at the fridge's front-left corner)
	local fridgeHinge = origin * CFrame.fromMatrix(V(-19.4, 0, -8.4), Vector3.xAxis, Vector3.yAxis)
	AptProps.fridgeDoor(doors, fridgeHinge, rng):SetAttribute("ClosedPivot", fridgeHinge)
	AptProps.pedalBin(props.Living, L(-16.4, 0, -7.4), rng, look(M.Plastic, 196, 194, 186))
	-- the eating corner: the fold table against the S wall, west of the window, two plastic
	-- chairs (one pushed back). (Between the kitchen and the sofa it was jammed against the
	-- sofa's back; here it has 3 studs of floor round it.)
	AptProps.foldTable(props.Living, L(-25.5, 0, -22.9, "N"), rng)
	local chair = look(M.Plastic, 200, 198, 190)
	AptProps.plasticChair(props.Living, L(-25.6, 0, -20.3), rng, chair)
	AptProps.plasticChair(props.Living, L(-22.9, 0, -21.2) * ANG(0, rad(65), 0), rng, chair)
	AptProps.radiator(props.Living, L(-14.5, 0, -24, "N"), rng)
	AptProps.pipes(props.Living, { P(-27.6, 10.5, -6.6), P(-12.6, 10.5, -6.6) }, rng, nil)

	------------------------------------------------------------------------------
	-- CORRIDOR (A: the long run, B: after the bend)
	------------------------------------------------------------------------------

	AptProps.runner(props.Corridor, L(-9, 0, -1.5), rng, 23)
	-- the leak sits by the W wall: the bucket stands against the wall under the drip, off the
	-- runner, so the walk stays clear (the E side has the cord bundle along its skirting)
	AptProps.ceilingSag(
		props.Corridor,
		L(-10.075, CEILING, 3.5),
		rng,
		ceilingColor,
		Vector2.new(3.35, 4.5)
	)
	AptProps.bucket(props.Corridor, L(-10.8, 0, 3.5), rng, look(M.Plastic, 70, 90, 110), 1)
	AptProps.mould(props.Corridor, L(-6.3, CEILING, 9.5) * ANG(0, math.pi, 0), rng)
	AptProps.pictureFrame(props.Corridor, L(-11.75, 0, -9.5, "E"), rng)
	AptProps.deadPlant(props.Corridor, L(-11, 0, -7.2), rng)
	AptProps.broom(props.Corridor, L(-11.35, 0, -4.4, "E"), rng)
	AptProps.smokeDetector(props.Corridor, L(-9, CEILING, -8), rng)
	AptProps.coatStand(props.Corridor, L(-10.75, 0, 16.6), rng) -- (its foot clear of the wall)
	AptProps.deadSocket(props.Corridor, L(0, CEILING, 15), rng)
	AptProps.outlet(props.Corridor, L(-6.25, 0, 2, "W"), rng)
	AptProps.pipes(
		props.Corridor,
		{ P(-6.6, 10.45, -14), P(-6.6, 10.45, 12) },
		rng,
		P(-6.6, 10.45, 4.8)
	)
	AptProps.lightSwitch(props.Corridor, L(-11.75, 0, -12.6, "E"), rng)
	-- corridor B: how the gear came up the stairs (a sack truck, the flattened cartons)
	-- (west of the lab door's swing: at x 7 the open leaf cut through it)
	AptProps.sackTruck(props.Corridor, L(2.6, 0, 16.5), rng)
	AptProps.flatCartons(props.Corridor, L(-1.0, 0, 16.9), rng)

	-- The cord bundle: from the meter cupboard, along corridor A's east skirting, across the
	-- bend, along corridor B's north wall, up and into a hole drilled above the lab door.
	local cordPoints = {
		cordExit,
		P(-4.42, 3.4, -16.3),
		-- (down the wall, then over the entry's skirting (its face at x -4.55) and along the
		-- floor in front of it, never inside it)
		P(-4.42, 0.8, -15.75),
		P(-4.8, 0.08, -15.5),
		P(-4.8, 0.08, -14.6),
		P(-6.7, 0.08, -14.6),
		P(-6.7, 0.08, 11.6),
		P(-5.2, 0.08, 17.25),
		P(4.0, 0.08, 17.3),
		P(4.0, 8.6, 17.55),
		P(9.6, 8.6, 17.55),
		P(9.85, 8.6, 16.6),
	}
	AptProps.cordBundle(
		props.Corridor,
		cordPoints,
		{ 5, 5, 5, 4, 4, 3, 3, 3, 4, 4, 4 },
		rng,
		4,
		P(-9, 0.08, 8)
	)
	part(
		props.Corridor,
		"DrillHole",
		V(0.02, 0.9, 0.9),
		L(9.74, 8.6, 16.65) * ANG(0, 0, 0),
		look(M.SmoothPlastic, 8, 8, 8),
		Enum.PartType.Cylinder
	)

	------------------------------------------------------------------------------
	-- BATHROOM
	------------------------------------------------------------------------------

	AptProps.bathtub(props.Bath, L(-18.1, 0.05, -1.95, "E"), rng)
	-- the tub's taps, shower and curtain on the W wall above its north end
	local _fittings, spout = AptProps.tubFittings(props.Bath, L(-19.75, 0, 0.8, "E"), rng)
	AptProps.toilet(props.Bath, L(-12.25, 0.05, 2.9, "W"), rng)
	AptProps.basinCabinet(props.Bath, L(-15.8, 0.05, 3.75, "S"), rng)
	AptProps.foldedSheeting(props.Bath, L(-15.2, 0.05, -4.6), rng)
	AptProps.bucket(props.Bath, L(-13.2, 0.05, -4.9), rng, look(M.Plastic, 150, 150, 140), nil)
	AptProps.gloves(props.Bath, L(-14.0, 1.6, -4.9, "E"), rng, look(M.Rubber, 186, 176, 110))
	AptProps.towelRail(props.Bath, L(-17.5, 0, -5.75, "N"), rng)
	AptProps.mould(props.Bath, L(-19.7, CEILING, 3.7) * ANG(0, math.pi / 2, 0), rng)
	-- missing floor tiles: the grey tile adhesive shows, two next to each other where the
	-- tub's overflow ran (the walls are painted, not tiled: no "missing tile" there)
	local adhesive = look(M.Concrete, 150, 146, 134)
	for _, spot in { V(-16.0, 0, -2.6), V(-15.0, 0, -2.6) } do
		AptProps.overlay(
			props.Bath,
			"MissingTile",
			Vector2.new(1, 1),
			L(spot.X, 0.05, spot.Z) * ANG(rad(90), 0, 0),
			AptProps.LAYER.STEP,
			adhesive
		)
	end

	-- The garden hose (a lighter green, so the eye follows it): pushed onto the tub's spout,
	-- over the tub's rim, out under the bathroom door (it keeps that door wide open), up on hooks
	-- along corridor A's west wall, round the bend, up with the cords through the hole over the
	-- lab door, along the lab's N wall on hooks and down into the feed carboy by the pumps.
	local hosePoints = {
		spout,
		P(-18.7, 3.1, 0.55),
		P(-17.3, 2.55, 0.3),
		P(-16.75, 2.42, 0.2),
		P(-16.3, 0.12, 0.0),
		P(-12.6, 0.12, -0.5),
		P(-11.3, 0.12, 0.9),
		P(-11.3, 0.7, 1.9),
		P(-11.3, 0.7, 7.4),
		P(-11.4, 0.12, 8.3),
		P(-11.4, 0.12, 11.6),
		P(-10.2, 0.12, 16.75),
		P(4.6, 0.12, 16.85),
		P(4.6, 8.85, 17.6),
		P(10.4, 8.85, 16.95),
		P(10.6, 9.5, 17.4),
		P(10.6, 9.5, 23.2),
		P(26.9, 9.5, 23.2),
		P(26.9, 9.5, 21.3),
		P(26.9, 2.25, 21.3),
	}
	AptProps.hose(props.Bath, hosePoints, rng)
	-- the hooks holding it up: corridor A's west wall, the lab's N wall
	local hookLook = look(M.Metal, 120, 120, 116)
	for _, z in { 3.2, 5.3, 7.2 } do
		part(props.Corridor, "HoseHook", V(0.5, 0.2, 0.06), L(-11.5, 0.86, z), hookLook)
	end
	for _, x in { 12.5, 17, 21.5, 25.5 } do
		part(props.Lab, "HoseHook", V(0.06, 0.2, 0.62), L(x, 9.66, 23.38), hookLook)
	end

	------------------------------------------------------------------------------
	-- BEDROOM 2 (the cook's room)
	------------------------------------------------------------------------------

	AptProps.mattress(props.Bed2, L(-3.2, 0, 3.9), rng)
	AptProps.duffelBag(props.Bed2, L(-3.2, 0, 7.6), rng)
	AptProps.fanHeater(props.Bed2, L(-0.6, 0, 5.4, "W"), rng)
	AptProps.alarmClock(props.Bed2, L(0.2, 0, 1.3), rng)
	AptProps.chairClothes(props.Bed2, L(-3.7, 0, 10.2), rng)
	AptProps.deskTable(props.Bed2, L(8.55, 0, 5, "W"), rng)
	AptProps.whiteboard(props.Bed2, L(3, 0, 0.25, "N"), rng)
	AptProps.supplyBoxes(props.Bed2, L(7.9, 0, 9.6, "W"), rng)
	AptProps.calendar(props.Bed2, L(-5.75, 0, 8.8, "E"), rng)
	AptProps.trashBag(props.Bed2, L(-1.6, 0, 10.9), rng)
	AptProps.mould(props.Bed2, L(9.7, CEILING, 11.7) * ANG(0, math.pi, 0), rng)

	------------------------------------------------------------------------------
	-- THE LAB
	------------------------------------------------------------------------------
	-- A believable clandestine biotech line, laid out clean → dirty with the work and the air:
	--   CULTURE (north, Z 15..24): the vat, its pumps / filter / feed carboy / UPS, the media
	--     fridge, the HEPA tower blowing filtered air over the vat; the gowning corner and the
	--     power board by the door.
	--   PROCESS (middle, Z 4.6..15): the extraction table under the range hood and its lamp, the
	--     instrument and specimen trays and the cold pass-box (BenchLayout's static kit), the
	--     stash freezer right behind the pass-box (with the scanner CRT on it), the biomass bin
	--     and its ramp at the table's W end, the trestle station (log PC + seed incubator).
	--   DIRTY (south, Z 0..4.6): the camp sink, the tool sterilising corner, the dispatch rack
	--     with the cases and their ice-pack coolers, the bin; the window is the exhaust.
	-- Every cord starts at the power board (fed by the fuse-box bundle through the hole over the
	-- door) and runs on the ceiling cable tray or a skirting; every hose ends in a container.

	local _tent, swayable = AptProps.plasticTent(props.Lab, toWorld, rng)
	-- three of the sheets sway in the fan's draught (client): Anim/Sheet_n, pivot = top edge
	for i, sheet in swayable do
		local holder = Instance.new("Model")
		holder.Name = `Sheet_{i}`
		sheet.Parent = holder
		holder.WorldPivot = sheet.CFrame * CF(0, sheet.Size.Y / 2, 0)
		-- (clients never get a pivot set by a script: they read this attribute, see AptFx)
		holder:SetAttribute("Pivot", holder.WorldPivot)
		holder.Parent = anim
	end
	local curtain = AptProps.stripCurtain(anim, L(11.4, 0, 15, "W"), rng, 7)
	curtain.Name = "Curtain"
	-- the tacky entry mat after the curtain (an overlay on the floor plastic)
	AptProps.overlay(
		props.Lab,
		"StickyMat",
		Vector2.new(1.8, 4.0),
		L(12.6, LAB_FLOOR, 15) * ANG(rad(90), 0, 0),
		AptProps.LAYER.STEP,
		look(M.Rubber, 96, 112, 128)
	)

	-- CULTURE -----------------------------------------------------------------

	-- The vat: VatBuilder makes the empty column, its monitor, cables and light bar, and the
	-- VatCore / VatPromptPoint / VatScreen markers (the client fills it).
	VatBuilder.build(L(20, 0, 19.5), model, LAB_FLOOR)
	-- (everything on the N wall stands with its back 0.03 in front of the hanging sheets)
	AptProps.labFridge(props.Lab, L(14.5, 0, 22.49), rng)
	AptProps.hepaTower(props.Lab, L(16.9, 0, 22.94), rng)
	AptProps.ups(props.Lab, L(23.5, 0, 22.94), rng)
	AptProps.pumpShelf(props.Lab, L(25.8, 0, 22.4), rng)
	AptProps.feedCarboy(props.Lab, L(26.7, 0, 20.75), rng)
	-- the pump-shelf strip (behind the tank) feeds the air pumps and the UPS
	AptProps.powerStrip(
		props.Lab,
		L(25.8, 6.5, 23.35, "S"),
		rng,
		{ P(24.9, 3.7, 22.3), P(23.5, 0.95, 22.9) },
		false
	)
	-- the culture loop (clear tubing): two feeds from the pumps up to the vat's cap rim, the
	-- drain from the plinth's side back to the circulation pump; its low point drips in a pan
	local tubing = look(M.Glass, 210, 225, 220, 0.4)
	AptProps.catenary(
		props.Lab,
		"Tubing",
		P(22.6, VatBuilder.GLASS_TOP + 0.4, 20.9),
		P(24.6, 7.1, 22.2),
		0.9,
		5,
		0.15,
		tubing
	)
	AptProps.catenary(
		props.Lab,
		"Tubing",
		P(22.75, VatBuilder.GLASS_TOP + 0.4, 18.9),
		P(24.3, 4.0, 21.7),
		0.7,
		5,
		0.15,
		tubing
	)
	AptProps.path(props.Lab, "Tubing", {
		P(22.7, 0.8, 20.9),
		P(23.7, 1.9, 21.0),
		P(25.0, 2.15, 21.0),
		P(25.3, 1.8, 21.5),
		P(24.9, 1.35, 21.85),
	}, 0.15, tubing)
	part(
		props.Lab,
		"DripPan",
		V(0.12, 1.2, 1.2),
		L(25, LAB_FLOOR + 0.06, 21) * ANG(0, 0, rad(90)),
		look(M.Metal, 120, 122, 120),
		Enum.PartType.Cylinder
	)
	part(
		props.Lab,
		"PanWater",
		V(0.03, 1.0, 1.0),
		L(25, LAB_FLOOR + 0.135, 21) * ANG(0, 0, rad(90)),
		look(M.Glass, 170, 200, 196, 0.4, 0.1),
		Enum.PartType.Cylinder
	)
	-- the cartridge filter on the garden hose, just before the feed carboy
	part(
		props.Lab,
		"HoseFilter",
		V(1.4, 0.5, 0.5),
		L(26.9, 5.2, 21.1) * ANG(0, 0, rad(90)),
		look(M.SmoothPlastic, 226, 228, 222),
		Enum.PartType.Cylinder
	)
	-- the glove station on the E wall beside the trolley's pass-box end (fresh gloves before
	-- the cut; in front of the tent's plastic, x 27.55)
	AptProps.gloveRack(props.Lab, L(27.55, 0, 7.5, "W"), rng)
	-- the gowning corner on the W wall (gear up before touching the culture)
	AptProps.gowning(props.Lab, L(10.25, 0, 21.6, "E"), rng)

	-- POWER -------------------------------------------------------------------

	-- The power board on the W wall by the door. The fuse-box bundle comes through the hole
	-- over the door and drops onto it; its cords go UP to the ceiling cable tray (and down the
	-- tray's drops), and DOWN along the skirting to the fridge and the HEPA tower.
	local _board, boardUp, boardDown = AptProps.powerBoard(props.Lab, L(10.25, 6.3, 18.8, "E"), rng)
	AptProps.cordBundle(props.Lab, {
		P(10.4, 8.6, 16.65),
		P(10.5, 8.6, 18.0),
		P(10.5, 7.7, 18.0),
	}, { 4, 4 }, rng, 4)
	local cordLook = look(M.Plastic, 38, 38, 36)
	local TRAY_Y = 10.0
	local TRAY_Z = 14.2
	AptProps.path(props.Lab, "Cord", {
		boardUp,
		Vector3.new(boardUp.X, (origin * CF(0, TRAY_Y, 0)).Position.Y, boardUp.Z),
		P(10.55, TRAY_Y, TRAY_Z),
	}, 0.16, cordLook)
	AptProps.path(props.Lab, "Cord", {
		boardDown,
		P(10.55, 0.7, (boardDown - origin.Position).Z),
		P(10.55, 0.7, 23.3),
		P(13.36, 0.7, 23.3),
	}, 0.12, CORD_WHITE_LOOK)
	-- (the HEPA tower's cord: from the fridge's back to the tower's side)
	AptProps.path(
		props.Lab,
		"Cord",
		{ P(15.64, 0.7, 23.3), P(16.26, 0.7, 23.3) },
		0.12,
		CORD_WHITE_LOOK
	)
	-- the ceiling cable tray (a slotted steel strip hung from the battens), the cords in it
	part(
		props.Lab,
		"CableTray",
		V(16.9, 0.05, 0.6),
		L(19.05, TRAY_Y - 0.05, TRAY_Z),
		look(M.Metal, 140, 142, 140)
	)
	AptProps.rod(
		props.Lab,
		"TrayCords",
		P(10.6, TRAY_Y + 0.1, TRAY_Z),
		P(27.4, TRAY_Y + 0.1, TRAY_Z),
		0.18,
		cordLook
	)
	for x = 11.5, 26.5, 3 do
		part(
			props.Lab,
			"TrayHanger",
			V(0.04, 0.72, 0.04),
			L(x, TRAY_Y + 0.38, TRAY_Z),
			look(M.Metal, 110, 110, 106)
		)
	end
	-- the drops: to the hood (and its lamp), the freezer, the trestle strip on the E wall, the
	-- sterilising corner and the window fan on the S wall
	AptProps.path(props.Lab, "Cord", {
		P(18.0, TRAY_Y, TRAY_Z - 0.3),
		P(18.0, TRAY_Y, 11.8),
		P(18.3, 9.72, 11.2),
	}, 0.1, cordLook)
	AptProps.path(props.Lab, "Cord", {
		P(25.5, TRAY_Y, TRAY_Z - 0.3),
		P(25.55, TRAY_Y, 12.75),
		P(25.4, 1.0, 12.5),
		P(25.2, 0.8, 11.5),
	}, 0.1, cordLook)
	AptProps.path(props.Lab, "Cord", {
		P(27.4, TRAY_Y, TRAY_Z),
		P(27.45, TRAY_Y, 14.0),
		P(27.45, 1.2, 14.0),
	}, 0.1, cordLook)
	AptProps.path(props.Lab, "Cord", {
		P(15.4, TRAY_Y, TRAY_Z - 0.3),
		P(15.4, TRAY_Y, 0.95),
		P(15.4, 3.1, 0.95),
	}, 0.1, cordLook)
	AptProps.path(props.Lab, "Cord", {
		P(17.6, 3.6, 0.95),
		P(16.3, 3.3, 0.95),
		P(15.45, 3.15, 0.95),
	}, 0.08, CORD_WHITE_LOOK)

	-- PROCESS -----------------------------------------------------------------

	-- The extraction table (trolley), its anchor, and BenchLayout's static kit on and around it
	-- (the underpad, the instrument and specimen trays, the cold pass-box at its +X end).
	AptProps.trolleyBench(props.Lab, L(18, 0, 10.5), rng)
	local anchor = L(18, 3.35, 10.5)
	marker("BenchAnchor", anchor)
	BenchLayout.buildStatic(props.Lab, anchor)
	-- (CutterDock: the scalpel's rest on the instrument tray, identity rotation)
	marker("CutterDock", CFrame.new((anchor * BenchLayout.SCALPEL_REST).Position))
	-- the range hood over the table, the work lamp clamped to its edge, the duct to the window
	local _hood, ductStart = AptProps.hoodLamp(props.Lab, L(18.1, 9.2, 10.5), P(19.5, 8.2, 11), rng)
	local duct = look(M.Foil, 180, 182, 184, 0, 0.05)
	AptProps.path(props.Lab, "Duct", {
		ductStart,
		P(19.0, 10.05, 9.5),
		P(19.0, 10.05, 1.4),
		P(19.0, 7.9, 1.4),
		P(19.0, 7.065, 0.62),
	}, 0.7, duct, true)
	-- the stash freezer right behind the pass-box (its long side along Z, its front toward the
	-- table), the capsule shelf inside it, the scanner CRT standing on its north end
	AptProps.stashFreezer(props.Lab, L(24.0, 0, 10.5, "W"), rng)
	marker("StashShelf", L(24.0, 2.2, 10.5))
	AptProps.scanMonitor(props.Lab, L(23.8, 3.14, 11.7), rng)
	-- the biomass bin at the table's W end (the spent shell slides down the ramp into it)
	local rampHinge = origin * CFrame.fromMatrix(V(14.4, 3.4, 10.5), Vector3.zAxis, Vector3.yAxis)
	AptProps.biomassBin(props.Lab, L(11.6, 0, 10.4, "E"), rng, rampHinge)
	marker("ChuteMouth", CFrame.lookAt(P(12.7, 3.3, 10.4), P(11.7, 3.3, 10.4)))
	-- the trestle station: the log PC and the seed incubator; its stool
	AptProps.trestleTable(props.Lab, L(26.2, 0, 16.6, "W"), rng)
	AptProps.powerStrip(
		props.Lab,
		L(27.6, 1.2, 15, "W"),
		rng,
		{ P(27.2, 3.9, 16.4), P(26.9, 3.6, 19.2) },
		true
	)
	local stool = look(M.Plastic, 60, 60, 60)
	part(
		props.Lab,
		"StoolSeat",
		V(0.15, 1.2, 1.2),
		L(24.2, 2.0, 17.0) * ANG(0, 0, rad(90)),
		AptProps.solid(stool),
		Enum.PartType.Cylinder
	)
	for i = 1, 3 do
		part(
			props.Lab,
			"StoolLeg",
			V(0.12, 2.0, 0.12),
			L(24.2, 1.0, 17.0) * ANG(0, rad(i * 120), 0) * CF(0, 0, 0.4) * ANG(rad(-10), 0, 0),
			stool
		)
	end

	-- DIRTY -------------------------------------------------------------------

	AptProps.campSink(props.Lab, L(13.3, 0, 1.85, "N"), rng)
	AptProps.toolBoiler(props.Lab, L(15.4, 0, 1.7, "N"), rng)
	AptProps.pedalBin(props.Lab, L(20.7, LAB_FLOOR, 1.4), rng, look(M.Plastic, 150, 154, 150))
	AptProps.wireShelf(props.Lab, L(24.75, 0, 1.7, "N"), rng)
	marker("RackSpot", L(24.75, 3.3, 1.7))
	local _window, fanBlades = AptProps.foilWindow(props.Lab, L(19, 0, 0.25, "N"), rng)
	fanBlades.Parent = anim

	-- GRIME AND LEFTOVERS -----------------------------------------------------

	-- The floor: only what has a job, square to the room (loose stains and puddles at random
	-- angles read as floating panes or debris at eye level): a rubber mat under the trolley
	-- where the work drips, and one in front of the sink.
	local matLook = look(M.Rubber, 62, 72, 78)
	AptProps.overlay(
		props.Lab,
		"WorkMat",
		Vector2.new(7.0, 3.0),
		L(17.9, LAB_FLOOR, 10.5) * ANG(rad(90), 0, 0),
		2 * AptProps.LAYER.STEP, -- (over the tape on the plastic's joins)
		matLook
	)
	AptProps.overlay(
		props.Lab,
		"SinkMat",
		Vector2.new(2.6, 1.4),
		L(13.3, LAB_FLOOR, 3.7) * ANG(rad(90), 0, 0),
		2 * AptProps.LAYER.STEP,
		matLook
	)
	AptProps.bedroomLeftovers(props.Lab, toWorld, rng)
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
	pendant:SetAttribute("Pivot", pendant.WorldPivot) -- (for the client, see AptFx)
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

	-- Living: the floor lamp by the sofa (the one warm practical at low level: the sofa corner
	-- reads; no shadows, a small range)
	local livingLamp = bulb(fixtures, "LivingLamp", -27.2, 5.55, -19.6, rgb(255, 200, 140))
	livingLamp:SetAttribute("Flicker", "None")
	addLight(livingLamp, {
		class = "PointLight",
		color = rgb(255, 176, 104),
		brightness = 0.55,
		range = 10,
		shadows = false,
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
		L(-15.8, 7.45, 3.5),
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
	local doorGlow =
		part(fixtures, "LabDoorGlow", V(0.05, 0.016, 4.3), L(9.85, 0.008, 15), glowLook)
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
		brightness = 0.85, -- (the vat is the key light; the tube only fills: dimmer keeps the
		-- lit column the brightest thing in the room, as in the concept)
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
		L(25.8, 5.3, 22.2),
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
		brightness = 0.35, -- (the client lights the fluid; this only tints the room)
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
		L(-18.3, 5.2, -7.2),
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

	-- the stash freezer's cold inside light: the capsules read through its clear lids
	local freezerLight = part(
		fixtures,
		"FreezerLight",
		V(0.2, 0.2, 0.2),
		L(24.0, 2.75, 10.5),
		look(M.SmoothPlastic, 0, 0, 0, 1)
	)
	freezerLight.CastShadow = false
	freezerLight:SetAttribute("Flicker", "None")
	addLight(freezerLight, {
		class = "PointLight",
		color = rgb(200, 230, 240),
		brightness = 0.6,
		range = 3,
		shadows = false,
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
	fxHost("Drip_Corridor", V(0.2, 0.2, 0.2), -10.8, 10.4, 3.5, "Corridor", "Drip"):SetAttribute(
		"LandAt",
		P(-10.8, 1.33, 3.5)
	)
	aim(fxHost("Vapour_LabDoor", V(0.4, 0.2, 3.6), 9.6, 0.1, 15, "Corridor", "Vapour"), X_MINUS)
	fxHost("Motes_Bend", V(4, 3, 4), -9, 7, 15, "Corridor", "Motes")
	fxHost("Motes_LabDoor", V(3, 2, 3), 7.5, 2, 15, "Corridor", "Motes")
	aim(fxHost("Bubbles_Tank", V(0.6, 0.1, 0.6), 25.8, 5.82, 22.4, "Lab", "Bubbles"), Vector3.yAxis)
	-- (cold mist rolls off the stash freezer's lid, down its S end, toward the operator)
	aim(fxHost("Mist_Freezer", V(2.0, 0.1, 0.3), 24.0, 3.0, 8.1, "Lab", "Mist"), Z_MINUS)
	fxHost("Motes_Lamp", V(3, 3, 3), 19, 5.5, 11, "Lab", "Motes")
	fxHost("Spark_Strip", V(0.3, 0.1, 0.3), 27.2, 1.2, 14.5, "Lab", "Spark")
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
	sound("KitchenFridge", -18.3, 1, -6.6, "LabFridgeHum", "Living", 3, 18, 0.8, "Loop")
	sound("CorridorBulb", -9, 10.2, -1, "LabFluoBuzz", "Corridor", 2, 12, 0.35, "Loop"):SetAttribute(
		"Fixture",
		"CorridorBulb"
	)
	sound("BathTap", -19.3, 3.3, 0.8, "LabDrip", "Bath", 2, 14, 0.6, "Random")
	sound("CorridorDrip", -10.8, 1.3, 3.5, "LabDrip", "Corridor", 2, 16, 1, "Synced")
	sound("VatHum", 20, 1, 19.5, "VatHum", "Lab", 5, 40, 1, "Loop")
	sound("TubeBuzz", 18, 9.8, 13, "LabFluoBuzz", "Lab", 3, 16, 1, "Loop"):SetAttribute(
		"Fixture",
		"TubeLight"
	)
	sound("LabFridge", 14.5, 1, 22.5, "LabFridgeHum", "Lab", 3, 18, 1, "Loop")
	sound("FreezerHum", 24.0, 0.8, 10.5, "LabFridgeHum", "Lab", 3, 14, 0.7, "Loop", 0.85)
	sound("Pumps", 25.8, 3.6, 22.4, "LabPumpBubble", "Lab", 3, 18, 1, "Loop")
	sound("LabDripPan", 25, 0.2, 21, "LabDrip", "Lab", 2, 14, 0.7, "Synced")
	sound("Spark", 27.2, 1.2, 14.5, "LabSpark", "Lab", 2, 16, 1, "Synced")
	-- (at the vat's own monitor: the chime is the lab's only "culture ready" cue)
	sound("MonitorBeep", 17.0, 2.2, 16.3, "VatReadyChime", "Lab", 3, 20, 1, "Event")

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
