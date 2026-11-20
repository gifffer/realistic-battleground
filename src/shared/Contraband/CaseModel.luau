--!strict
-- CaseModel: the "BX-7" courier case, built from plain parts (nothing uploaded).
-- Used by the server (cases lying on the ground) and by the client (the case in a hand).
-- Design: direction/BRIEFCASE.md and PLAN §7.5. Brushed aluminium, black rubber corners,
-- a leather handle on chrome mounts, two 3-wheel combination locks, a cold vent that glows
-- faintly (the SAME glow empty or full: it never tells what is inside), an orange
-- "BX-7 KEEP COLD" stencil, and inside: dark foam with 3 cradles, an egg-crate lid, a cold
-- LED strip and a small "-18.4 C" readout.
--
--   CaseModel.SIZE                        1.6 × 1.15 × 0.42 studs (the Hitbox)
--   CaseModel.build({ lidAngle?, interior?, cradles? }) → Model, PrimaryPart "Hitbox"
--                                          (cradles = 2: the 3rd cradle is filled with a
--                                          raised foam plug, so the tier shows)
--   CaseModel.setLid(model, degrees)       0 = closed .. 100 = wide open; up to SLIVER_MAX°
--                                          only the LED strip shows (a "sliver" of glow) and
--                                          the interior light grows with the angle
--   CaseModel.setInteriorVisible(model, visible, sliver?)
--   CaseModel.cradleCFrames(model)         the 3 cradle points in the foam (world space)
--   CaseModel.GRIP                         the handle's centre, in the case's own space
--   CaseModel.heldCFrame(swing?)           the case seen from the Left Arm (held in the fist)
--   CaseModel.CAPSULE_SCALE                how big a CoreModel capsule is drawn in a cradle
--
-- The case's own axes (looking at its big lid face):
--   X = width (1.6). The vent is on the +X end, the stencil on the −X end.
--   Y = height (1.15). The handle is on the +Y long edge; the hinges and the 2 feet are on
--       the −Y edge (it stands on that edge, like a real case).
--   Z = thickness (0.42). The base is the −Z half (0.26), the lid the +Z half (0.16).
-- The lid turns around the −Y edge: a positive angle lifts its +Y (handle) side.
--
-- How it is held together:
--   • "Hitbox" (invisible box, the size of the whole case) is the only part that collides.
--     It is ANCHORED when built: whoever uses the model decides (the server unanchors the
--     rest and anchors only the Hitbox; the client's held copy is welded to an arm).
--   • every base part is welded (WeldConstraint) to the Hitbox; every lid part is welded to
--     "LidShell"; LidShell is joined to "BaseShell" by the Motor6D "LidHinge", whose C0 is
--     what setLid changes.
--   • visual parts: unanchored, massless, no collision, no queries, no touch.
--   • interior parts (attribute "Interior" = true) are see-through while the lid is shut,
--     so nothing is drawn for nothing. Their normal transparency is kept in the attribute
--     "ShowTransparency".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CaseModel = {}

CaseModel.SIZE = Vector3.new(1.6, 1.15, 0.42)

-- How big a CoreModel capsule is drawn in a cradle (the lab's capsule is 1 stud long; the
-- case is a hand case, so its foam takes smaller ones).
CaseModel.CAPSULE_SCALE = 0.66
CaseModel.CRADLES = 3

-- The handle's centre (where the hand closes), in the case's own space.
local GRIP = Vector3.new(0, 0.665, -0.02)
CaseModel.GRIP = GRIP

-- The lid opens wider than this: the interior is drawn.
local INTERIOR_FROM = 5
local SLIVER_MAX = 12.5 -- degrees: up to this, only the LED strip shows (a KO-dropped case)
local LIGHT_FULL_AT = 48 -- degrees: the interior light is at full brightness from here
local LIGHT_BRIGHTNESS = 0.6

-- Where the hinge axis runs (case space): along X, on the −Y edge, at the seam.
local SEAM_Z = 0.05
local HINGE = Vector3.new(0, -0.525, SEAM_Z)
local BASE_SHELL_AT = Vector3.new(0, 0, -0.18)
local LID_SHELL_AT = Vector3.new(0, 0, 0.18)
-- The hinge, seen from each shell (their centre, no rotation).
local HINGE_IN_BASE = CFrame.new(HINGE - BASE_SHELL_AT)
local HINGE_IN_LID = CFrame.new(HINGE - LID_SHELL_AT)

-- The 3 cradles: centre of a capsule lying in the foam (case space), along X.
local CRADLE_Y = { -0.31, 0, 0.31 }
local CRADLE_Z = -0.03

-- Colours (RGB) and materials.
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local ALU = rgb(172, 174, 176)
local ALU_PANEL = rgb(150, 152, 154)
local STEEL_DARK = rgb(70, 72, 76)
local GROOVE = rgb(58, 60, 62)
local CHROME = rgb(200, 200, 205)
local WHEEL = rgb(120, 120, 125)
local RUBBER = rgb(24, 24, 24)
local LEATHER = rgb(40, 30, 25)
local SLAT = rgb(50, 50, 52)
local COLD = rgb(200, 225, 255)
local STENCIL = rgb(230, 120, 40)
local FOAM = rgb(30, 30, 32)
local FOAM_DARK = rgb(18, 18, 20)
local FOAM_LID = rgb(34, 34, 36)
local READOUT_PLATE = rgb(20, 22, 24)
local READOUT_TEXT = rgb(200, 235, 255)
local PLATE = rgb(190, 190, 195)

-- Rotations used below.
local ROT_NONE = CFrame.identity
-- A label panel on the −X end: its Front face looks out along −X, its text runs along the
-- case's Y axis (the long way of that narrow end), the top of the letters toward the lid.
local ROT_END_LABEL = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))
-- A capsule (long axis = its own Y, see CoreModel) turned to lie along the case's X.
local ROT_CAPSULE = CFrame.Angles(0, 0, -math.pi / 2)

export type Options = {
	lidAngle: number?, -- degrees, 0 (default) = shut
	interior: boolean?, -- false = no foam / LED / readout at all (default: built)
	cradles: number?, -- working cradles (default 3); fewer = the others are plugged
}

type Spec = {
	name: string,
	size: Vector3,
	at: Vector3, -- centre, case space (lid parts: with the lid SHUT)
	rot: CFrame?,
	color: Color3,
	material: Enum.Material?,
	reflectance: number?,
	transparency: number?,
	shape: Enum.PartType?,
	shadow: boolean?,
}

local function makePart(spec: Spec): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Size = spec.size
	part.CFrame = CFrame.new(spec.at) * (spec.rot or ROT_NONE)
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.Metal
	part.Reflectance = spec.reflectance or 0
	part.Transparency = spec.transparency or 0
	if spec.shape then
		part.Shape = spec.shape
	end
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = spec.shadow == true
	part.Locked = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- A text written on the Front face of `part` (SurfaceGui + TextLabel).
local function writeOn(part: BasePart, text: string, color: Color3, glowing: boolean): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 300
	gui.LightInfluence = if glowing then 0 else 1
	gui.Brightness = if glowing then 1.4 else 1
	gui.MaxDistance = 40
	gui.ClipsDescendants = true
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Parent = gui
	gui.Parent = part
	return gui
end

-- Every part, in case space (lid shut). `group` = what it is welded to.
type Group = "Base" | "Lid"

local function specs(
	interior: boolean,
	cradles: number
): { { spec: Spec, group: Group, inside: boolean } }
	local list: { { spec: Spec, group: Group, inside: boolean } } = {}
	local function add(group: Group, spec: Spec, inside: boolean?)
		table.insert(list, { spec = spec, group = group, inside = inside == true })
	end

	-- BASE: a tray (bottom + 4 walls) so the open case has a real hollow.
	add("Base", {
		name = "BaseShell",
		size = Vector3.new(1.5, 1.05, 0.04),
		at = BASE_SHELL_AT,
		color = ALU,
		reflectance = 0.05,
		shadow = true,
	})
	for _, side in { 1, -1 } do
		add("Base", {
			name = "BaseWall",
			size = Vector3.new(1.5, 0.04, 0.21),
			at = Vector3.new(0, 0.505 * side, -0.055),
			color = ALU,
			reflectance = 0.05,
			shadow = true,
		})
		add("Base", {
			name = "BaseWall",
			size = Vector3.new(0.04, 0.97, 0.21),
			at = Vector3.new(0.73 * side, 0, -0.055),
			color = ALU,
			reflectance = 0.05,
			shadow = true,
		})
		-- Dark steel lip around the seam.
		add("Base", {
			name = "SeamLip",
			size = Vector3.new(1.56, 0.03, 0.04),
			at = Vector3.new(0, 0.535 * side, 0.035),
			color = STEEL_DARK,
		})
		add("Base", {
			name = "SeamLip",
			size = Vector3.new(0.03, 1.1, 0.04),
			at = Vector3.new(0.765 * side, 0, 0.035),
			color = STEEL_DARK,
		})
	end
	-- Recessed inset panel (a thin dark groove frame under a slightly darker plate).
	add("Base", {
		name = "InsetGroove",
		size = Vector3.new(1.24, 0.79, 0.01),
		at = Vector3.new(0, 0, -0.203),
		color = GROOVE,
	})
	add("Base", {
		name = "InsetPanel",
		size = Vector3.new(1.2, 0.75, 0.012),
		at = Vector3.new(0, 0, -0.207),
		color = ALU_PANEL,
		reflectance = 0.04,
	})
	-- Rubber corner guards (the silhouette cue).
	for _, sx in { 1, -1 } do
		for _, sy in { 1, -1 } do
			add("Base", {
				name = "Corner",
				size = Vector3.new(0.16, 0.16, 0.22),
				at = Vector3.new(0.72 * sx, 0.495 * sy, -0.1),
				color = RUBBER,
				material = Enum.Material.Rubber,
			})
		end
	end
	-- Handle: leather grip on two chrome mounts, on the +Y edge.
	for _, sx in { 1, -1 } do
		add("Base", {
			name = "HandleMount",
			size = Vector3.new(0.08, 0.14, 0.1),
			at = Vector3.new(0.25 * sx, 0.595, GRIP.Z),
			color = CHROME,
			reflectance = 0.3,
		})
	end
	add("Base", {
		name = "HandleGrip",
		size = Vector3.new(0.58, 0.09, 0.09),
		at = GRIP,
		color = LEATHER,
		material = Enum.Material.Leather,
		shape = Enum.PartType.Cylinder, -- (a cylinder's axis is its X: along the edge)
	})
	-- Two combination locks either side of the handle: a chrome plate with 3 thumbwheels.
	for _, sx in { 1, -1 } do
		add("Base", {
			name = "LockPlate",
			size = Vector3.new(0.22, 0.03, 0.1),
			at = Vector3.new(0.5 * sx, 0.538, 0),
			color = CHROME,
			reflectance = 0.3,
		})
		for wheel = -1, 1 do
			add("Base", {
				name = "LockWheel",
				size = Vector3.new(0.03, 0.05, 0.05),
				at = Vector3.new(0.5 * sx + wheel * 0.06, 0.556, -0.01),
				color = WHEEL,
				shape = Enum.PartType.Cylinder,
			})
		end
	end
	-- Back edge: 2 knuckle hinges + 2 rubber feet.
	for _, sx in { 1, -1 } do
		add("Base", {
			name = "Hinge",
			size = Vector3.new(0.2, 0.06, 0.06),
			at = Vector3.new(0.45 * sx, -0.54, SEAM_Z),
			color = CHROME,
			reflectance = 0.2,
			shape = Enum.PartType.Cylinder,
		})
		add("Base", {
			name = "Foot",
			size = Vector3.new(0.1, 0.04, 0.1),
			at = Vector3.new(0.35 * sx, -0.555, -0.1),
			color = RUBBER,
			material = Enum.Material.Rubber,
		})
	end
	-- Cold vent on the +X end: a faint cold glow behind 6 dark slats.
	add("Base", {
		name = "VentGlow",
		size = Vector3.new(0.01, 0.36, 0.13),
		at = Vector3.new(0.752, 0, -0.085),
		color = COLD,
		material = Enum.Material.Neon,
		transparency = 0.4,
	})
	for slat = 0, 5 do
		add("Base", {
			name = "VentSlat",
			size = Vector3.new(0.02, 0.025, 0.15),
			at = Vector3.new(0.762, -0.15 + slat * 0.06, -0.085),
			color = SLAT,
		})
	end
	-- Stencil panel on the −X end (invisible: only its text shows).
	add("Base", {
		name = "Stencil",
		size = Vector3.new(0.8, 0.1, 0.004),
		at = Vector3.new(-0.757, 0, -0.085),
		rot = ROT_END_LABEL,
		color = ALU,
		transparency = 1,
	})

	-- LID: the same tray, shallower, upside down.
	add("Lid", {
		name = "LidShell",
		size = Vector3.new(1.5, 1.05, 0.04),
		at = LID_SHELL_AT,
		color = ALU,
		reflectance = 0.05,
		shadow = true,
	})
	for _, side in { 1, -1 } do
		add("Lid", {
			name = "LidWall",
			size = Vector3.new(1.5, 0.04, 0.11),
			at = Vector3.new(0, 0.505 * side, 0.105),
			color = ALU,
			reflectance = 0.05,
			shadow = true,
		})
		add("Lid", {
			name = "LidWall",
			size = Vector3.new(0.04, 0.97, 0.11),
			at = Vector3.new(0.73 * side, 0, 0.105),
			color = ALU,
			reflectance = 0.05,
			shadow = true,
		})
	end
	add("Lid", {
		name = "InsetGroove",
		size = Vector3.new(1.24, 0.79, 0.01),
		at = Vector3.new(0, 0, 0.203),
		color = GROOVE,
	})
	add("Lid", {
		name = "InsetPanel",
		size = Vector3.new(1.2, 0.75, 0.012),
		at = Vector3.new(0, 0, 0.207),
		color = ALU_PANEL,
		reflectance = 0.04,
	})
	-- Blank engraved plate (no brand), near the handle.
	add("Lid", {
		name = "Plate",
		size = Vector3.new(0.3, 0.1, 0.01),
		at = Vector3.new(0.4, 0.27, 0.216),
		color = PLATE,
		reflectance = 0.15,
	})
	for _, sx in { 1, -1 } do
		for _, sy in { 1, -1 } do
			add("Lid", {
				name = "Corner",
				size = Vector3.new(0.16, 0.16, 0.15),
				at = Vector3.new(0.72 * sx, 0.495 * sy, 0.135),
				color = RUBBER,
				material = Enum.Material.Rubber,
			})
		end
		-- The latch tongues the locks close on.
		add("Lid", {
			name = "Latch",
			size = Vector3.new(0.12, 0.025, 0.06),
			at = Vector3.new(0.5 * sx, 0.537, 0.08),
			color = CHROME,
			reflectance = 0.3,
		})
	end

	if not interior then
		return list
	end
	-- INTERIOR: foam with 3 darker cradles + a finger notch, the cold LED strip along the
	-- inner front wall (the "sliver of glow" when the lid is ajar), egg-crate lid foam and
	-- the readout.
	add("Base", {
		name = "FoamBase",
		size = Vector3.new(1.42, 0.97, 0.12),
		at = Vector3.new(0, 0, -0.1),
		color = FOAM,
		material = Enum.Material.Fabric,
	}, true)
	for index, y in CRADLE_Y do
		if index > cradles then
			-- (a cradle this tier does not have: a raised foam plug, flush with the foam)
			add("Base", {
				name = "FoamPlug",
				size = Vector3.new(1.14, 0.24, 0.03),
				at = Vector3.new(0, y, -0.03),
				color = FOAM,
				material = Enum.Material.Fabric,
			}, true)
			continue
		end
		add("Base", {
			name = "Cradle",
			size = Vector3.new(1.12, 0.22, 0.01),
			at = Vector3.new(0, y, -0.037),
			color = FOAM_DARK,
			material = Enum.Material.Fabric,
		}, true)
	end
	add("Base", {
		name = "FingerNotch",
		size = Vector3.new(0.1, 0.8, 0.012),
		at = Vector3.new(0.63, 0, -0.036),
		color = FOAM_DARK,
		material = Enum.Material.Fabric,
	}, true)
	add("Base", {
		name = "LedStrip",
		size = Vector3.new(1.3, 0.02, 0.02),
		at = Vector3.new(0, 0.475, 0.02),
		color = COLD,
		material = Enum.Material.Neon,
	}, true)
	add("Lid", {
		name = "FoamLid",
		size = Vector3.new(1.42, 0.97, 0.03),
		at = Vector3.new(0, 0, 0.145),
		color = FOAM_LID,
		material = Enum.Material.Fabric,
	}, true)
	for _, y in { -0.32, -0.12, 0.08 } do
		add("Lid", {
			name = "FoamRidge",
			size = Vector3.new(1.42, 0.05, 0.016),
			at = Vector3.new(0, y, 0.124),
			color = FOAM,
			material = Enum.Material.Fabric,
		}, true)
	end
	add("Lid", {
		name = "Readout",
		size = Vector3.new(0.3, 0.12, 0.01),
		at = Vector3.new(-0.42, 0.3, 0.125),
		color = READOUT_PLATE,
		material = Enum.Material.SmoothPlastic,
	}, true)
	return list
end

-- The lid's turn (case space) for an angle in degrees.
local function lidTurn(degrees: number): CFrame
	return CFrame.new(HINGE) * CFrame.Angles(math.rad(degrees), 0, 0) * CFrame.new(-HINGE)
end

-- The interior for a lid angle: hidden when shut, only the LED strip up to SLIVER_MAX°, all of
-- it above; the interior light grows with the angle (a dim sliver when barely ajar).
local applyLid: (Model, number) -> ()

local function interiorParts(model: Model): { BasePart }
	local found: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("Interior") == true then
			table.insert(found, descendant)
		end
	end
	return found
end

-- Builds a case. Its pivot is the case's centre (the Hitbox), placed at the origin: use
-- model:PivotTo(cframe) to move it.
function CaseModel.build(options: Options?): Model
	local lidAngle = math.clamp((options and options.lidAngle) or 0, 0, 100)
	local withInterior = not (options and options.interior == false)
	local cradles = math.clamp(math.floor((options and options.cradles) or #CRADLE_Y), 1, #CRADLE_Y)

	local model = Instance.new("Model")
	model.Name = "BX7Case"

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = CaseModel.SIZE
	hitbox.CFrame = CFrame.identity
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = true
	hitbox.CanQuery = true
	hitbox.CanTouch = false
	hitbox.CastShadow = false
	hitbox.Material = Enum.Material.Metal
	hitbox.Locked = true
	hitbox.Parent = model
	model.PrimaryPart = hitbox

	-- 1. Every part where it goes, lid parts turned to the lid's angle.
	local turn = lidTurn(lidAngle)
	local baseShell: BasePart? = nil
	local lidShell: BasePart? = nil
	local lidParts: { BasePart } = {}
	local baseParts: { BasePart } = {}
	for _, entry in specs(withInterior, cradles) do
		local part = makePart(entry.spec)
		if entry.inside then
			part:SetAttribute("Interior", true)
			part:SetAttribute("ShowTransparency", part.Transparency)
		end
		if entry.group == "Lid" then
			part.CFrame = turn * part.CFrame
			if part.Name == "LidShell" then
				lidShell = part
			else
				table.insert(lidParts, part)
			end
		else
			if part.Name == "BaseShell" then
				baseShell = part
			end
			table.insert(baseParts, part)
		end
		part.Parent = model
	end
	assert(baseShell and lidShell, "CaseModel: shells missing")

	-- 2. Lights and labels.
	local vent = model:FindFirstChild("VentGlow")
	if vent and vent:IsA("BasePart") then
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Right
		light.Color = COLD
		light.Brightness = 0.3
		light.Range = 2
		light.Angle = 120
		light.Shadows = false
		light.Parent = vent
	end
	local stencil = model:FindFirstChild("Stencil")
	if stencil and stencil:IsA("BasePart") then
		writeOn(stencil, "BX-7 KEEP COLD", STENCIL, false)
	end
	local led = model:FindFirstChild("LedStrip")
	if led and led:IsA("BasePart") then
		local light = Instance.new("PointLight")
		light.Name = "InteriorLight"
		light.Color = COLD
		light.Brightness = LIGHT_BRIGHTNESS
		light.Range = 2.5
		light.Shadows = false
		light.Parent = led
	end
	local readout = model:FindFirstChild("Readout")
	if readout and readout:IsA("BasePart") then
		-- (the readout faces the base when shut: its Front face is −Z, like the lid foam)
		local text = Config.Case.READOUT
		writeOn(readout, text, READOUT_TEXT, true)
	end

	-- 3. Joints. Welds are made once everything is in place (a WeldConstraint keeps the
	-- offset the two parts have when it is made).
	for _, part in baseParts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hitbox
		weld.Part1 = part
		weld.Parent = part
	end
	for _, part in lidParts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = lidShell
		weld.Part1 = part
		weld.Parent = part
	end
	local hinge = Instance.new("Motor6D")
	hinge.Name = "LidHinge"
	hinge.Part0 = baseShell
	hinge.Part1 = lidShell
	hinge.C0 = HINGE_IN_BASE * CFrame.Angles(math.rad(lidAngle), 0, 0)
	hinge.C1 = HINGE_IN_LID
	hinge.Parent = baseShell

	model.WorldPivot = CFrame.identity
	applyLid(model, lidAngle)
	return model
end

-- Shows / hides the foam, the LED strip (and its light) and the readout. `sliver`: only the
-- LED strip (the lid barely ajar: a thin line of cold light, nothing else readable).
function CaseModel.setInteriorVisible(model: Model, visible: boolean, sliver: boolean?)
	local mode = if not visible then "None" elseif sliver then "Sliver" else "Full"
	if model:GetAttribute("InteriorMode") == mode then
		return
	end
	model:SetAttribute("InteriorMode", mode)
	model:SetAttribute("InteriorVisible", visible)
	for _, part in interiorParts(model) do
		local shown = visible and (not sliver or part.Name == "LedStrip")
		local show = part:GetAttribute("ShowTransparency")
		part.Transparency = if shown then (if typeof(show) == "number" then show else 0) else 1
		for _, child in part:GetChildren() do
			if child:IsA("Light") or child:IsA("SurfaceGui") then
				(child :: any).Enabled = shown -- (both have Enabled)
			end
		end
	end
end

applyLid = function(model: Model, angle: number)
	CaseModel.setInteriorVisible(model, angle > INTERIOR_FROM, angle <= SLIVER_MAX)
	local led = model:FindFirstChild("LedStrip")
	local light = if led then led:FindFirstChild("InteriorLight") else nil
	if light and light:IsA("PointLight") then
		light.Brightness = LIGHT_BRIGHTNESS * math.clamp(angle / LIGHT_FULL_AT, 0, 1)
	end
end

-- Turns the lid: 0 = shut .. 100 = wide open (degrees). The interior shows above 5°.
-- (The lid moves through the Motor6D, so the model's parts must not be anchored, apart
-- from the Hitbox.)
function CaseModel.setLid(model: Model, degrees: number)
	local angle = math.clamp(degrees, 0, 100)
	local baseShell = model:FindFirstChild("BaseShell")
	local hinge = baseShell and baseShell:FindFirstChild("LidHinge")
	if hinge and hinge:IsA("Motor6D") then
		hinge.C0 = HINGE_IN_BASE * CFrame.Angles(math.rad(angle), 0, 0)
	end
	applyLid(model, angle)
end

-- Carried in the LEFT hand (BRIEFCASE §2.1): seen from the Left Arm (R6, arm centre =
-- origin, arm bottom at Y −1, −Z = the character's front), the handle sits in the fist, the
-- case's width along the walking direction (vent to the back), its lid facing out (−X) and
-- its thickness centred on the arm, so it clears the leg.
local HAND = Vector3.new(0, -0.98, 0) -- where the fist closes (arm space)
local HELD_TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
CaseModel.HAND = HAND

-- The case's CFrame seen from the Left Arm. `swing` (a rotation, arm space) turns it
-- around the fist: the pendulum (nil = hanging straight along the arm).
function CaseModel.heldCFrame(swing: CFrame?): CFrame
	return CFrame.new(HAND) * (swing or CFrame.identity) * HELD_TURN * CFrame.new(-GRIP)
end

-- The 3 cradles in the foam, in world space: a CoreModel capsule (long axis = its Y)
-- placed at one of these lies along the case's width. Scale it by CAPSULE_SCALE.
function CaseModel.cradleCFrames(model: Model): { CFrame }
	local baseShell = model:FindFirstChild("BaseShell")
	local base = if baseShell and baseShell:IsA("BasePart")
		then baseShell.CFrame * CFrame.new(-BASE_SHELL_AT)
		else model:GetPivot()
	local list: { CFrame } = {}
	for _, y in CRADLE_Y do
		table.insert(list, base * CFrame.new(0, y, CRADLE_Z) * ROT_CAPSULE)
	end
	return list
end

return CaseModel
