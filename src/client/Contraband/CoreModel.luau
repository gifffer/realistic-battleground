--!strict
-- CoreModel: the bio-core and its capsule, built from parts (client only, nothing uploaded).
--
-- The bio-core (ART_V2 §5.4) must NEVER read as an egg, an organ, a heart, a kidney, a
-- brain or an eye. So it is a broken silhouette: 4 fused, slightly flattened lobes on a
-- twisted line, 3 thin ribs wrapping the grooves, a fibrous stub where it was cut, a tiny
-- Neon pinpoint inside and a faint light. About 0.6 stud long. Never red.
--   C  dull amber, warm light
--   B  bruise-violet, teal light that pulses
--   A  two amber lobes + two teal-violet lobes, light slowly going amber ↔ teal
--   nil  (grade not known yet, during the extraction) a pale milky amber
--
-- The capsule: a frosted glass tube with steel end caps and an orange band, the core inside
-- at 0.55 scale. Empty capsule = grade nil and `empty = true`.
--
--   CoreModel.core(grade, scale?, cframe?)   → Model "BioCore" (long axis = the model's Y)
--   CoreModel.capsule(grade?, cframe?, empty?) → Model "Capsule" (long axis = Y, cap "CapTop")
--   CoreModel.animate(model, now, lit?)      breathing light (call it each frame, optional);
--                                            each model breathes on its own phase (8 capsules
--                                            on a shelf never pulse in lockstep); lit = false
--                                            switches its PointLight off (the pin still breathes)
--   CoreModel.weldTo(model, part)            unanchor + weld every part to `part` (held case)
--   CoreModel.setCapOpen(capsule, open)      0 = closed .. 1 = top cap lifted off (seal step)
--
-- Every part is anchored, non-colliding, non-queryable at first. Models are placed with
-- Model:PivotTo (their WorldPivot is the centre).

local Parts = require(script.Parent.Parts)

local CoreModel = {}

export type Grade = "A" | "B" | "C"

type Look = {
	lobes: { Color3 }, -- one colour per lobe (4)
	transparency: number,
	rib: Color3,
	light: Color3,
	light2: Color3?, -- A: the light goes from `light` to `light2` and back
	pulse: boolean, -- B: the light pulses (faster breath)
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local AMBER = rgb(176, 118, 44)
local VIOLET = rgb(92, 58, 104)
local TEAL_VIOLET = rgb(84, 110, 140)
local MILKY_AMBER = rgb(196, 160, 110)

local LOOKS: { [string]: Look } = {
	C = {
		lobes = { AMBER, AMBER, AMBER, AMBER },
		transparency = 0.25,
		rib = rgb(140, 92, 34),
		light = rgb(255, 170, 80),
		pulse = false,
	},
	B = {
		lobes = { VIOLET, VIOLET, VIOLET, VIOLET },
		transparency = 0.2,
		rib = rgb(72, 46, 84),
		light = rgb(90, 200, 190),
		pulse = true,
	},
	A = {
		lobes = { rgb(196, 136, 52), TEAL_VIOLET, rgb(196, 136, 52), TEAL_VIOLET },
		transparency = 0.2,
		rib = rgb(124, 100, 84),
		light = rgb(255, 176, 90),
		light2 = rgb(90, 210, 200),
		pulse = false,
	},
	None = {
		lobes = { MILKY_AMBER, MILKY_AMBER, MILKY_AMBER, MILKY_AMBER },
		transparency = 0.3,
		rib = rgb(164, 132, 94),
		light = rgb(255, 214, 160),
		pulse = false,
	},
}

local STUB = rgb(230, 225, 210) -- the pale fibres where it was cut
local GLASS = rgb(210, 225, 230)
local STEEL_DARK = rgb(70, 72, 76)
local HAZARD = rgb(230, 120, 40)

-- The 4 lobes: diameter, height along the line (Y) and twist angle (degrees).
local LOBES = {
	{ d = 0.34, y = -0.19, twist = 0 },
	{ d = 0.40, y = -0.06, twist = 110 },
	{ d = 0.36, y = 0.08, twist = 215 },
	{ d = 0.30, y = 0.2, twist = 320 },
}
local TWIST_RADIUS = 0.06
-- The ribs sit in the grooves between lobes: height, start angle (degrees).
local RIBS = { { y = -0.125, from = 20 }, { y = 0.01, from = 140 }, { y = 0.145, from = 260 } }
local RIB_RADIUS = 0.168
local RIB_SPAN = 220 -- degrees of each rib (an open band, not a closed ring)
local RIB_SEGMENTS = 5

local function lobeCentre(lobe: { d: number, y: number, twist: number }): Vector3
	local a = math.rad(lobe.twist)
	return Vector3.new(math.cos(a) * TWIST_RADIUS, lobe.y, math.sin(a) * TWIST_RADIUS)
end

-- The bio-core, its long axis along Y, centred on `cframe` (default origin).
function CoreModel.core(grade: string?, scale: number?, cframe: CFrame?): Model
	local s = scale or 1
	local root = cframe or CFrame.identity
	local known = if grade == "A" or grade == "B" or grade == "C" then grade else nil
	local look = LOOKS[known or "None"]
	local model = Instance.new("Model")
	model.Name = "BioCore"
	model:SetAttribute("Grade", known or "")

	-- Lobes: flattened along the line so the cluster reads "segmented pod", not "egg".
	local biggest: BasePart? = nil
	for i, lobe in LOBES do
		local size = Vector3.new(lobe.d, lobe.d * 0.8, lobe.d * 0.94) * s
		local part = Parts.ellipsoid(size, {
			Name = "Lobe",
			Color = look.lobes[i],
			Transparency = look.transparency,
			Reflectance = 0.2,
			CFrame = root
				* CFrame.new(lobeCentre(lobe) * s)
				* CFrame.Angles(0, math.rad(lobe.twist), 0),
			Parent = model,
		})
		if lobe.d >= 0.4 then
			biggest = part
		end
	end

	-- Ribs: thin bands following the grooves, each an open arc of short rods.
	for _, rib in RIBS do
		local from = math.rad(rib.from)
		local span = math.rad(RIB_SPAN)
		for k = 1, RIB_SEGMENTS do
			local a0 = from + (k - 1) / RIB_SEGMENTS * span
			local a1 = from + k / RIB_SEGMENTS * span
			local p0 = Vector3.new(math.cos(a0) * RIB_RADIUS, rib.y, math.sin(a0) * RIB_RADIUS)
			local p1 =
				Vector3.new(math.cos(a1) * RIB_RADIUS, rib.y + 0.012, math.sin(a1) * RIB_RADIUS)
			local part = Parts.rod(p0 * s, p1 * s, 0.04 * s, {
				Name = "Rib",
				Color = look.rib,
				Reflectance = 0.15,
			})
			part.CFrame = root * part.CFrame
			part.Parent = model
		end
	end

	-- The fibrous stub at the bottom (where the fibres were cut): two pale strands.
	for _, side in { -1, 1 } do
		local base = Vector3.new(side * 0.03, -0.31, 0.01)
		local tip = base + Vector3.new(side * 0.05, -0.14, side * 0.02)
		local part = Parts.rod(base * s, tip * s, 0.03 * s, {
			Name = "Stub",
			Color = STUB,
			Transparency = 0.1,
		})
		part.CFrame = root * part.CFrame
		part.Parent = model
	end

	-- The pinpoint and its faint light, inside the biggest lobe.
	local pinAt = if biggest then biggest.CFrame.Position else root.Position
	local pin = Parts.ball(0.05 * s, {
		Name = "Pin",
		Material = Enum.Material.Neon,
		Color = look.light,
		Transparency = 0.15,
		CFrame = CFrame.new(pinAt),
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = look.light
	light.Brightness = 0.3
	light.Range = 4 * math.max(s, 0.5)
	light.Shadows = false
	light.Parent = pin

	model.WorldPivot = root
	return model
end

-- A frosted capsule (long axis Y) with the core inside (unless `empty`).
function CoreModel.capsule(grade: string?, cframe: CFrame?, empty: boolean?): Model
	local root = cframe or CFrame.identity
	local model = Instance.new("Model")
	model.Name = "Capsule"
	local upright = Parts.UPRIGHT
	Parts.disc(0.40, 0.90, {
		Name = "Tube",
		Material = Enum.Material.Glass,
		Color = GLASS,
		Transparency = 0.55,
		Reflectance = 0.1,
		CFrame = root * upright,
		Parent = model,
	})
	for _, y in { -0.51, 0.51 } do
		Parts.disc(0.44, 0.12, {
			Name = if y > 0 then "CapTop" else "CapBottom",
			Material = Enum.Material.Metal,
			Color = STEEL_DARK,
			Reflectance = 0.1,
			CFrame = root * CFrame.new(0, y, 0) * upright,
			Parent = model,
		})
	end
	Parts.disc(0.42, 0.06, {
		Name = "Band",
		Color = HAZARD,
		CFrame = root * CFrame.new(0, 0.3, 0) * upright,
		Parent = model,
	})
	if not empty then
		local core = CoreModel.core(grade, 0.55, root * CFrame.new(0, -0.03, 0))
		core.Parent = model
	end
	model.WorldPivot = root
	return model
end

-- Lifts the capsule's top cap: 0 = closed, 1 = 0.35 stud up and tilted (seal step).
function CoreModel.setCapOpen(capsule: Model, open: number)
	local cap = capsule:FindFirstChild("CapTop")
	if cap == nil or not cap:IsA("BasePart") then
		return
	end
	-- open = lying flat beside the capsule (on whatever the capsule stands on)
	local o = math.clamp(open, 0, 1)
	local closed = CFrame.new(0, 0.51, 0)
	local aside = CFrame.new(0.5, -0.51, 0.12)
	local lift = math.sin(o * math.pi) * 0.25
	cap.CFrame = capsule.WorldPivot * closed:Lerp(aside, o) * CFrame.new(0, lift, 0) * Parts.UPRIGHT
end

-- What animate() needs per model, found once (no recursive search per frame).
type Breath = { pin: BasePart, light: PointLight?, look: Look, phase: number, lit: boolean }
local breaths: { [Model]: Breath | false } = setmetatable({}, { __mode = "k" }) :: any
local phases = Random.new()

local function breathOf(model: Model): Breath?
	local known = breaths[model]
	if known ~= nil then
		return known or nil
	end
	local pin = model:FindFirstChild("Pin", true)
	if pin == nil or not pin:IsA("BasePart") then
		breaths[model] = false
		return nil
	end
	local core = if pin.Parent and pin.Parent:IsA("Model") then pin.Parent else model
	local grade = core:GetAttribute("Grade")
	local breath: Breath = {
		pin = pin,
		light = pin:FindFirstChildOfClass("PointLight"),
		look = LOOKS[if grade == "A" or grade == "B" or grade == "C" then grade else "None"],
		phase = phases:NextNumber(0, 7), -- seconds: its own place in the breath
		lit = true,
	}
	breaths[model] = breath
	return breath
end

-- Breathing light: brightness 0.3 ± a little (2.5 s), B pulses faster, A changes colour.
function CoreModel.animate(model: Model, now: number, lit: boolean?)
	local breath = breathOf(model)
	if breath == nil then
		return
	end
	local pin, light, look = breath.pin, breath.light, breath.look
	local t = now + breath.phase
	local period = if look.pulse then 1.4 else 2.5
	local wave = 0.5 + 0.5 * math.sin(t * math.pi * 2 / period)
	local on = lit ~= false
	if light and breath.lit ~= on then
		breath.lit = on
		light.Enabled = on
	end
	if light and on then
		light.Brightness = 0.22 + 0.16 * wave
	end
	if look.light2 then
		local mix = 0.5 + 0.5 * math.sin(t * math.pi * 2 / 7)
		local color = look.light:Lerp(look.light2 :: Color3, mix)
		if light and on then
			light.Color = color
		end
		pin.Color = color
	end
	pin.Transparency = 0.1 + 0.25 * (1 - wave)
end

-- Where stash capsule number `index` (1..8) stands on the lab's stash shelf (the server's
-- "StashShelf" marker, on the cabinet's middle shelf, the open front toward +X): two rows of
-- four along Z, upright.
function CoreModel.shelfCFrame(shelf: CFrame, index: number): CFrame
	local i = math.max(index, 1) - 1
	local column = i % 4
	local row = i // 4
	return shelf * CFrame.new(-0.45 * row + 0.1, 0.63, (column - 1.5) * 0.42)
end

-- For a capsule carried in a case: every part unanchored, massless, welded to `part`.
function CoreModel.weldTo(model: Model, part: BasePart)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
end

return CoreModel
