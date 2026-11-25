--!strict
-- VatBuilder: builds the EMPTY culture vat of one flat's lab, on the server (LabBuilder calls
-- it once). The client fills it (Client/Contraband/VatVisual: the fluid, the light, the bubbles,
-- the clone, the screen text).
--
-- THE LOOK (the first concept the player loved: direction/art/02_clone_stages_vats.png, made by
-- direction/art/src/lab.py `vat()`, at 0.92 scale so it fits under the 11-stud ceiling):
--   a squat glass column on a dark steel plinth with a thin orange line at its foot, a dark
--   steel cap with a lighter collar, three black cables from the cap up to the ceiling, a small
--   black monitor on a floor stand at the front-right, and a cold neon bar above the vat.
--   No frame, no pipes, no stool: a clean cylinder.
--
-- WHY THE GLASS IS NOT Material.Glass: Roblox's Glass material does not draw transparent
-- things behind it (a long-known engine limit). Everything inside the vat (the fluid) is
-- transparent, so Glass would hide it and the vat would read as a black block. The glass here
-- is SmoothPlastic, very transparent, a little reflective.
--
-- SPACE: `at` = the vat's floor centre (the floor top), never rotated in practice; its -Z is the
-- vat's FRONT (toward the bench and the lab door), +Y up. All the offsets below are in studs
-- in that space. Careful: someone standing in front (at -Z) and looking at the vat (toward
-- +Z) has +X on his LEFT. So the concept's "front-right" monitor is at -X here.
--
-- PARTS MADE AS DIRECT CHILDREN OF `model` (a contract with Lab, Extraction and the client,
-- do not rename):
--   VatCore         invisible 1×1×1, the clone's root (centre of the clone, 4.05 above the
--                   floor: the clone stands in the lower half of the column, as in the concept)
--   VatPromptPoint  invisible, front-left of the vat as you face it (+X), beside the glass,
--                   3.7 above the floor: the vat's ProximityPrompt sits here (never over
--                   the glass, the clone or the monitor text)
--   VatGlass, VatBase, VatCap (+ SpotLight "VatRimLight" shining down into the column)
--   VatScreen       the monitor's screen (Front face = -Z); the client puts the SurfaceGui on it
-- Cosmetic parts go to the model's "Props_Lab" folder (or the model) and the neon bar to its
-- "Fixtures" folder (Flicker "None"), when those folders exist.
--
--   VatBuilder.build(at, model)  → the VatCore part

local AptProps = require(script.Parent.AptProps)

type Look = AptProps.Look

local VatBuilder = {}

local M = Enum.Material
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local look = AptProps.look
local part = AptProps.part

-- The measurements (studs, in the vat's space). Shared with nothing else: the client reads the
-- parts themselves.
local CORE_HEIGHT = 4.05 -- VatCore above the floor
-- The lab is a plastic tent: its ceiling sheets sag to about 10.4 above the floor (wooden
-- battens at 10.75–10.95 hold them, the real ceiling is at 11). The cables go up through the
-- sheets to the battens; the light bar hangs under the sheets.
local TENT_UNDERSIDE = 10.4
local CABLE_TOP = 10.85

-- The colours of the concept (lab.py: dark steel, hazard orange, black cables).
local DARK_STEEL = look(M.Metal, 46, 48, 52)
local COLLAR = look(M.Metal, 78, 80, 84)
local HAZARD = look(M.SmoothPlastic, 190, 110, 30)
local CABLE = look(M.SmoothPlastic, 22, 22, 24)
local MONITOR = look(M.Metal, 24, 26, 28)

function VatBuilder.build(at: CFrame, model: Instance): BasePart
	local props: Instance = model:FindFirstChild("Props_Lab") or model
	local fixtures: Instance = model:FindFirstChild("Fixtures") or model

	-- A point / frame in the vat's space.
	local function P(x: number, y: number, z: number): Vector3
		return (at * CF(x, y, z)).Position
	end
	local function frame(x: number, y: number, z: number): CFrame
		return at * CF(x, y, z)
	end

	-- A vertical cylinder (Roblox cylinders run along their local X: turn it upright).
	local function column(
		parent: Instance,
		name: string,
		diameter: number,
		height: number,
		centreY: number,
		l: Look
	): Part
		return part(
			parent,
			name,
			V(height, diameter, diameter),
			frame(0, centreY, 0) * ANG(0, 0, rad(90)),
			l,
			Enum.PartType.Cylinder
		)
	end

	-- An invisible marker (no collisions, no queries, no shadow).
	local function marker(name: string, cframe: CFrame): Part
		local made = part(model, name, Vector3.one, cframe, look(M.SmoothPlastic, 0, 0, 0, 1))
		made.CastShadow = false
		return made
	end

	-- 1. The shell, bottom to top. Heights never share a face with a neighbour's visible face:
	-- plinth 0–1.1, orange line 1.1–1.22 (narrower than the plinth), the glass floor disc
	-- 1.22–1.24 (inside the glass), glass 1.23–9.05, collar 8.93–9.05 (wider than the glass,
	-- around it), cap 9.05–9.85.
	column(model, "VatBase", 6.1, 1.1, 0.55, AptProps.solid(DARK_STEEL))
	column(props, "VatHazard", 5.8, 0.12, 1.16, HAZARD)
	local glass = column(
		model,
		"VatGlass",
		5.5,
		7.82,
		5.14,
		AptProps.solid(look(M.SmoothPlastic, 200, 220, 225, 0.88, 0.15))
	)
	glass.CastShadow = false
	glass.CanQuery = false -- (prompts and clicks reach what is inside through it)
	-- the glass floor: a dark steel disc just inside the glass (without it the orange line's
	-- top showed through the fluid as an orange floor)
	column(props, "VatFloor", 5.44, 0.02, 1.23, look(M.Metal, 70, 74, 78))
	column(props, "VatCapLip", 5.75, 0.12, 8.99, COLLAR)
	local cap = column(model, "VatCap", 6.1, 0.8, 9.45, AptProps.solid(DARK_STEEL))
	-- a weak cold light from the cap down into the column: a rim on the clone (no shadows)
	local rim = Instance.new("SpotLight")
	rim.Name = "VatRimLight"
	rim.Face = Enum.NormalId.Left -- (the cylinder is turned: its -X face looks down)
	rim.Brightness = 0.6
	rim.Range = 9
	rim.Angle = 50
	rim.Color = Color3.fromRGB(200, 225, 245)
	rim.Shadows = false
	rim.Parent = cap

	-- 2. Three black cables from the cap's top up and back through the tent's sheet (the
	-- concept's bezier cables), each a few short rods along a curve, small balls hiding the
	-- joints.
	local SEGMENTS = 4
	for _, angle in { 0.6, 2.2, 4.0 } do
		local c, s = math.cos(angle), math.sin(angle)
		-- (-X: the concept's layout seen from the front, see SPACE above)
		local p0 = P(-1.5 * c, 9.85, 1.5 * s) -- on the cap
		local h0 = P(-1.75 * c, 10.5, 1.75 * s) -- leaves the cap straight up...
		local h1 = P(-2.5 * c, CABLE_TOP, 2.4) -- ...and bends back...
		local p1 = P(-3 * c, CABLE_TOP, 3.2) -- ...up through the tent's sheet, behind the vat
		local points = {}
		for i = 0, SEGMENTS do
			local t = i / SEGMENTS
			local u = 1 - t
			-- (a cubic Bézier: the same curve shape as the concept's cables)
			table.insert(
				points,
				p0 * (u * u * u) + h0 * (3 * u * u * t) + h1 * (3 * u * t * t) + p1 * (t * t * t)
			)
		end
		for i = 1, SEGMENTS do
			local a, b = points[i], points[i + 1]
			part(
				props,
				"VatCable",
				V((b - a).Magnitude, 0.14, 0.14),
				CFrame.lookAt((a + b) / 2, b) * ANG(0, rad(90), 0),
				CABLE,
				Enum.PartType.Cylinder
			)
			if i < SEGMENTS then
				part(props, "VatCableJoint", V(0.14, 0.14, 0.14), CF(b), CABLE, Enum.PartType.Ball)
			end
		end
	end

	-- 3. The monitor: a small black box on a floor stand, front-right, low (the concept's
	-- "MATRIX 18%" box; -X = the right as you face the vat). The screen pokes 0.03 out of
	-- the housing's front (no shared face).
	part(props, "MonitorFoot", V(0.7, 0.06, 0.5), frame(-3.0, 0.03, -3.0), MONITOR)
	part(props, "MonitorStem", V(0.14, 1.64, 0.14), frame(-3.0, 0.88, -3.0), MONITOR)
	part(props, "VatMonitor", V(1.7, 1.0, 0.3), frame(-3.0, 2.2, -3.1), AptProps.solid(MONITOR))
	local screen = part(
		model,
		"VatScreen",
		V(1.5, 0.8, 0.04),
		frame(-3.0, 2.2, -3.26),
		look(M.SmoothPlastic, 8, 10, 12)
	)
	screen.CastShadow = false

	-- 4. The cold neon bar above the vat, a little in front (the concept's top light): a metal
	-- housing hung under the tent's sheet on two rods, the tube under it, a soft light down.
	local barTop = TENT_UNDERSIDE - 0.1
	for _, x in { -2.6, 2.6 } do
		part(
			props,
			"VatTubeHanger",
			V(0.04, 10.8 - barTop, 0.04),
			frame(x, (10.8 + barTop) / 2, -2.4),
			look(M.Metal, 120, 122, 120)
		)
	end
	part(
		props,
		"VatTubeHousing",
		V(6.2, 0.1, 0.35),
		frame(0, barTop - 0.05, -2.4),
		look(M.Metal, 150, 152, 150)
	)
	local tube = part(
		fixtures,
		"VatTube",
		V(6.0, 0.16, 0.16),
		frame(0, barTop - 0.18, -2.4),
		look(M.Neon, 215, 232, 240)
	)
	tube.CastShadow = false
	tube:SetAttribute("Flicker", "None")
	local light = Instance.new("SurfaceLight")
	light.Name = "Light"
	light.Face = Enum.NormalId.Bottom
	light.Color = Color3.fromRGB(190, 220, 240)
	light.Brightness = 0.7
	light.Range = 10
	light.Angle = 100
	light.Shadows = false
	light.Parent = tube

	-- 5. The markers: the clone's root, and the prompt's place: front-left as you face the vat,
	-- just beyond the glass's edge, 3.7 above the floor (reachable standing), 6 studs from the
	-- monitor. So the prompt's billboard never covers the monitor text nor the clone.
	local core = marker("VatCore", frame(0, CORE_HEIGHT, 0))
	marker("VatPromptPoint", frame(3.2, 3.7, -2.6))
	return core
end

return VatBuilder
