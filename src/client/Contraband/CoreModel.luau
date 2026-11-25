--!strict
-- CoreModel: the bio-elements, the bio-core and its capsule, built from parts (client only,
-- nothing uploaded).
--
-- The elements are STYLISED lab specimens (ART_V2 §5.4, DECISIONS 20/11): they must NEVER
-- read as an egg, an organ, a heart, a kidney, a brain or an eye, and are never red. Each one
-- is a broken, clearly artificial silhouette with a faint inner light that breathes:
--   Cluster  4 fused, flattened amber lobes on a twisted line, 3 thin ribs in the grooves
--   Pod      an elongated bruise-violet seed pod, 6 raised ribs spiralling a quarter turn,
--            nacre tips, a teal light that pulses
--   Coil     a tight 2.5-turn spiral of glossy segments, bile-green to nacre, a slow light
--            travelling along it, going amber ↔ teal
--   Husk     a decoy: the same silhouettes shrivelled, matt beige-grey, NO light, no breath
-- The condition is a second, readable layer:
--   Intact   glossy, steady breath
--   Bruised  dark violet-grey patches, a slower, uneven breath
--   Ruptured a crack with a milky seep, a flickering light
-- About 0.6 stud long at scale 1 (long axis = the model's Y).
--
-- The capsule: a frosted glass tube with steel end caps, an orange band and a small grade
-- light on the band, the element inside at 0.55 scale. Empty capsule = `empty = true`.
--
--   CoreModel.element(kind, condition, scale?, cframe?, shape?) → Model "BioElement"
--                                     (shape: the silhouette of a Husk, "Cluster" by default)
--   CoreModel.core(grade, scale?, cframe?, kind?)   → an intact element (kind from the grade
--                                                     when not given: C Cluster, B Pod, A Coil)
--   CoreModel.kindOf(kind?, grade?)                  a valid kind ("Cluster" by default)
--   CoreModel.capsule(grade?, cframe?, empty?, kind?) → Model "Capsule" (long axis Y, "CapTop")
--   CoreModel.setGradeLight(capsule, grade?, inert?) the small light on the band
--   CoreModel.animate(model, now, lit?)  breathing light (call it each frame, optional); each
--                                        model breathes on its own phase (8 capsules on a
--                                        shelf never pulse in lockstep); lit = false switches
--                                        its PointLight off (the pin still breathes)
--   CoreModel.weldTo(model, part)        unanchor + weld every part to `part` (held case)
--   CoreModel.setCapOpen(capsule, open)  0 = closed .. 1 = top cap lifted off
--   CoreModel.shelfCFrame(shelf, index)  where stash capsule `index` stands
--
-- Every part is anchored, non-colliding, non-queryable. Models are placed with
-- Model:PivotTo (their WorldPivot is the centre).

local Parts = require(script.Parent.Parts)

local CoreModel = {}

export type Grade = "A" | "B" | "C"
export type Kind = "Cluster" | "Pod" | "Coil" | "Husk"
export type Condition = "Intact" | "Bruised" | "Ruptured"

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- How each kind's light behaves.
type Look = {
	light: Color3,
	light2: Color3?, -- the light goes from `light` to `light2` and back (Coil)
	period: number, -- seconds of one breath
}

local LOOKS: { [string]: Look } = {
	Cluster = { light = rgb(255, 170, 80), period = 2.5 },
	Pod = { light = rgb(90, 200, 190), period = 1.4 },
	Coil = { light = rgb(255, 176, 90), light2 = rgb(90, 210, 200), period = 2.2 },
}

local AMBER = rgb(128, 78, 26) -- dark wet amber (never a sweet pastel)
local AMBER_RIB = rgb(100, 62, 22)
local AMBER_GLOW = rgb(196, 122, 48)
local POD = rgb(78, 48, 96)
local POD_RIB = rgb(104, 72, 120)
local NACRE = rgb(226, 220, 212)
local COIL_FROM = rgb(92, 112, 48)
local COIL_TO = rgb(220, 214, 196)
local HUSK = rgb(150, 140, 124)
local HUSK_DARK = rgb(124, 114, 100)
local BRUISE = rgb(86, 76, 94)
local CRACK = rgb(58, 54, 52)
local SEEP = rgb(232, 234, 228) -- milky gel
local GLASS = rgb(210, 225, 230)
local STEEL_DARK = rgb(70, 72, 76)
local CLIP_TAB = rgb(168, 140, 84) -- dull ochre clip tabs on the capsule rim
local LED_OFF = rgb(52, 54, 56)
-- The capsule's grade light (never red: C is a dull amber-brown).
local GRADE_LIGHT: { [string]: Color3 } = {
	A = rgb(150, 236, 220),
	B = rgb(255, 196, 110),
	C = rgb(186, 128, 70),
}

-- A valid kind from anything (an unknown one follows the grade: C Cluster, B Pod, A Coil).
function CoreModel.kindOf(kind: string?, grade: string?): Kind
	if kind == "Cluster" or kind == "Pod" or kind == "Coil" or kind == "Husk" then
		return kind
	end
	return if grade == "A" then "Coil" elseif grade == "B" then "Pod" else "Cluster"
end

------------------------------------------------------------------------------
-- Silhouettes (each takes the model, its root, the scale and whether it is a husk)
------------------------------------------------------------------------------

-- Cluster: 4 lobes (diameter, height along the line, twist angle) and 3 ribs in the grooves.
local LOBES = {
	{ d = 0.34, y = -0.19, twist = 0 },
	{ d = 0.40, y = -0.06, twist = 110 },
	{ d = 0.36, y = 0.08, twist = 215 },
	{ d = 0.30, y = 0.2, twist = 320 },
}
local TWIST_RADIUS = 0.06
local RIBS = { { y = -0.125, from = 20 }, { y = 0.01, from = 140 }, { y = 0.145, from = 260 } }
local RIB_RADIUS = 0.168
local RIB_SPAN = 220 -- degrees (an open band, not a closed ring)
local RIB_SEGMENTS = 5

-- Puts a rod (local space a → b) in the model, placed at root.
local function rodIn(
	model: Model,
	root: CFrame,
	a: Vector3,
	b: Vector3,
	d: number,
	props: Parts.Props
)
	local part = Parts.rod(a, b, d, props)
	part.CFrame = root * part.CFrame
	part.Parent = model
	return part
end

local function buildCluster(model: Model, root: CFrame, s: number, husk: boolean): Vector3
	local squeeze = if husk then 0.72 else 1 -- (a husk is dried and collapsed)
	for _, lobe in LOBES do
		local a = math.rad(lobe.twist)
		local centre = Vector3.new(math.cos(a) * TWIST_RADIUS, lobe.y, math.sin(a) * TWIST_RADIUS)
		local size = Vector3.new(
			lobe.d * squeeze,
			lobe.d * 0.8 * (if husk then 0.86 else 1),
			lobe.d * 0.94 * squeeze
		)
		Parts.ellipsoid(size * s, {
			Name = "Lobe",
			Material = if husk then Enum.Material.Sand else Enum.Material.SmoothPlastic,
			Color = if husk then HUSK else AMBER,
			Transparency = if husk then 0 else 0.25,
			Reflectance = if husk then 0 else 0.3,
			CFrame = root * CFrame.new(centre * s) * CFrame.Angles(0, a, if husk then 0.12 else 0),
			Parent = model,
		})
	end
	for _, rib in RIBS do
		local from = math.rad(rib.from)
		local span = math.rad(RIB_SPAN)
		local radius = RIB_RADIUS * squeeze
		for k = 1, RIB_SEGMENTS do
			local a0 = from + (k - 1) / RIB_SEGMENTS * span
			local a1 = from + k / RIB_SEGMENTS * span
			local p0 = Vector3.new(math.cos(a0) * radius, rib.y, math.sin(a0) * radius)
			local p1 = Vector3.new(math.cos(a1) * radius, rib.y + 0.012, math.sin(a1) * radius)
			rodIn(model, root, p0 * s, p1 * s, 0.04 * s, {
				Name = "Rib",
				Color = if husk then HUSK_DARK else AMBER_RIB,
				Reflectance = if husk then 0 else 0.15,
			})
		end
	end
	if not husk then
		-- a faint warm glow deep inside the biggest lobe: it reads alive and wet, not a nugget
		Parts.ellipsoid(Vector3.new(0.2, 0.16, 0.18) * s, {
			Name = "Glow",
			Material = Enum.Material.Neon,
			Color = AMBER_GLOW,
			Transparency = 0.5,
			CFrame = root * CFrame.new(Vector3.new(-0.05, -0.06, 0.04) * s),
			Parent = model,
		})
	end
	return Vector3.new(0, -0.06, 0) -- (the pin sits in the biggest lobe)
end

local function buildPod(model: Model, root: CFrame, s: number, husk: boolean): Vector3
	local squeeze = if husk then 0.7 else 1
	local length = 0.62
	Parts.ellipsoid(Vector3.new(0.28 * squeeze, length, 0.26 * squeeze) * s, {
		Name = "PodBody",
		Material = if husk then Enum.Material.Sand else Enum.Material.SmoothPlastic,
		Color = if husk then HUSK else POD,
		Transparency = if husk then 0 else 0.15,
		Reflectance = if husk then 0 else 0.22,
		CFrame = root,
		Parent = model,
	})
	-- 6 raised ribs, each twisting a quarter turn from the bottom to the top
	local half = length / 2
	for rib = 1, 6 do
		local start = math.rad(rib * 60)
		local previous: Vector3? = nil
		for k = 0, 4 do
			local f = k / 4
			local y = -half * 0.86 + f * half * 1.72
			local r = (0.14 * squeeze) * math.sqrt(math.max(0, 1 - (y / half) ^ 2)) + 0.006
			local a = start + f * math.pi / 2
			local point = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
			if previous then
				rodIn(model, root, previous * s, point * s, 0.032 * s, {
					Name = "Rib",
					Color = if husk then HUSK_DARK else POD_RIB,
					Reflectance = if husk then 0 else 0.15,
				})
			end
			previous = point
		end
	end
	-- nacre tips at both ends
	for _, side in { -1, 1 } do
		Parts.ellipsoid(Vector3.new(0.1, 0.08, 0.1) * s * squeeze, {
			Name = "Tip",
			Color = if husk then HUSK_DARK else NACRE,
			Reflectance = if husk then 0 else 0.35,
			CFrame = root * CFrame.new(0, side * (half - 0.02) * s, 0),
			Parent = model,
		})
	end
	return Vector3.zero
end

local COIL_SEGMENTS = 16
local function coilPoint(f: number, squeeze: number): Vector3
	local turns = 2.5
	local a = f * turns * math.pi * 2
	local radius = 0.11 * squeeze
	return Vector3.new(math.cos(a) * radius, -0.25 + f * 0.5, math.sin(a) * radius)
end

local function buildCoil(model: Model, root: CFrame, s: number, husk: boolean): Vector3
	local squeeze = if husk then 0.75 else 1
	for i = 1, COIL_SEGMENTS do
		local f = (i - 1) / (COIL_SEGMENTS - 1)
		local point = coilPoint(f, squeeze)
		local ahead = coilPoint(math.min(f + 0.02, 1), squeeze)
			- coilPoint(math.max(f - 0.02, 0), squeeze)
		local cframe = Parts.between(point - ahead / 2, point + ahead / 2)
		local thick = (if husk then 0.08 else 0.11) * s
		local part = Parts.ellipsoid(Vector3.new(0.15 * s, thick, thick), {
			Name = "Segment",
			Material = if husk then Enum.Material.Sand else Enum.Material.SmoothPlastic,
			Color = if husk then HUSK else COIL_FROM:Lerp(COIL_TO, f),
			Transparency = if husk then 0 else 0.08,
			Reflectance = if husk then 0 else 0.3,
			CFrame = root * CFrame.new(cframe.Position * s) * cframe.Rotation,
			Parent = model,
		})
		part:SetAttribute("Along", f)
	end
	return Vector3.zero
end

------------------------------------------------------------------------------
-- Elements
------------------------------------------------------------------------------

-- A bio-element, its long axis along Y, centred on `cframe` (default origin).
function CoreModel.element(
	kind: string,
	condition: string?,
	scale: number?,
	cframe: CFrame?,
	shape: string?
): Model
	local s = scale or 1
	local root = cframe or CFrame.identity
	local realKind = CoreModel.kindOf(kind, nil)
	local husk = realKind == "Husk"
	local silhouette = if husk then CoreModel.kindOf(shape, nil) else realKind
	if silhouette == "Husk" then
		silhouette = "Cluster"
	end
	local state: Condition = if condition == "Bruised" or condition == "Ruptured"
		then condition
		else "Intact"
	if husk then
		state = "Intact"
	end
	local model = Instance.new("Model")
	model.Name = "BioElement"
	model:SetAttribute("Kind", realKind)
	model:SetAttribute("Condition", state)

	local pinAt: Vector3
	if silhouette == "Pod" then
		pinAt = buildPod(model, root, s, husk)
	elseif silhouette == "Coil" then
		pinAt = buildCoil(model, root, s, husk)
	else
		pinAt = buildCluster(model, root, s, husk)
	end

	-- Condition cues on the surface.
	if state == "Bruised" then
		for k, at in { { a = 40, y = -0.12 }, { a = 170, y = 0.05 }, { a = 290, y = 0.17 } } do
			local a = math.rad(at.a)
			local r = if silhouette == "Coil" then 0.15 else 0.13
			Parts.ellipsoid(Vector3.new(0.12, 0.09, 0.035) * s * (1 - k * 0.08), {
				Name = "Bruise",
				Color = BRUISE,
				Reflectance = 0.05,
				CFrame = root
					* CFrame.new(Vector3.new(math.cos(a) * r, at.y, math.sin(a) * r) * s)
					* CFrame.Angles(0, -a + math.pi / 2, 0),
				Parent = model,
			})
		end
	elseif state == "Ruptured" then
		local r = if silhouette == "Coil" then 0.15 else 0.145
		Parts.part({
			Name = "Crack",
			Size = Vector3.new(0.02, 0.24, 0.016) * s,
			Color = CRACK,
			CFrame = root * CFrame.new(0, 0.02 * s, -r * s) * CFrame.Angles(0, 0, math.rad(14)),
			Parent = model,
		})
		Parts.ellipsoid(Vector3.new(0.13, 0.19, 0.07) * s, {
			Name = "Seep",
			Color = SEEP,
			Transparency = 0.2,
			Reflectance = 0.3,
			CFrame = root * CFrame.new(0.02 * s, -0.1 * s, -(r + 0.01) * s),
			Parent = model,
		})
	end

	-- The pinpoint and its faint light (none in a husk: it is dead).
	if not husk then
		local look = LOOKS[silhouette]
		local pin = Parts.ball(0.05 * s, {
			Name = "Pin",
			Material = Enum.Material.Neon,
			Color = look.light,
			Transparency = 0.15,
			CFrame = root * CFrame.new(pinAt * s),
			Parent = model,
		})
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = look.light
		light.Brightness = 0.3
		light.Range = 3 * math.max(s, 0.6)
		light.Shadows = false
		light.Parent = pin
	end

	model.WorldPivot = root
	return model
end

-- An intact element standing for a core of `grade` (the shelf, the case, the capsule).
function CoreModel.core(grade: string?, scale: number?, cframe: CFrame?, kind: string?): Model
	local chosen = CoreModel.kindOf(kind, grade)
	if chosen == "Husk" then
		chosen = CoreModel.kindOf(nil, grade)
	end
	local model = CoreModel.element(chosen, "Intact", scale, cframe)
	model:SetAttribute("Grade", if grade == "A" or grade == "B" or grade == "C" then grade else "")
	return model
end

------------------------------------------------------------------------------
-- Capsule
------------------------------------------------------------------------------

-- A frosted capsule (long axis Y) with the element inside (unless `empty`).
function CoreModel.capsule(grade: string?, cframe: CFrame?, empty: boolean?, kind: string?): Model
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
	-- 4 small ochre clip tabs on the outside of the rim (a full coloured band read as the
	-- cap of a pill bottle from above, and hid the element inside)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		Parts.part({
			Name = "Tab",
			Size = Vector3.new(0.12, 0.06, 0.03),
			Color = CLIP_TAB,
			CFrame = root * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.3, -0.215),
			Parent = model,
		})
	end
	Parts.ball(0.06, {
		Name = "GradeLed",
		Color = LED_OFF,
		CFrame = root * CFrame.new(0, 0.3, -0.21),
		Parent = model,
	})
	if not empty then
		local core = CoreModel.core(grade, 0.55, root * CFrame.new(0, -0.03, 0), kind)
		core.Parent = model
	end
	model.WorldPivot = root
	if grade == "A" or grade == "B" or grade == "C" then
		CoreModel.setGradeLight(model, grade, false)
	end
	return model
end

-- The small light on the capsule's band: the grade's colour, a dull grey for an inert
-- (husk) capsule, off for nil.
function CoreModel.setGradeLight(capsule: Model, grade: string?, inert: boolean?)
	local led = capsule:FindFirstChild("GradeLed")
	if led == nil or not led:IsA("BasePart") then
		return
	end
	local color = if grade then GRADE_LIGHT[grade] else nil
	if color then
		led.Material = Enum.Material.Neon
		led.Color = color
	else
		led.Material = Enum.Material.SmoothPlastic
		led.Color = if inert then rgb(120, 116, 108) else LED_OFF
	end
end

-- Lifts the capsule's top cap: 0 = closed, 1 = lying flat beside the capsule.
function CoreModel.setCapOpen(capsule: Model, open: number)
	local cap = capsule:FindFirstChild("CapTop")
	if cap == nil or not cap:IsA("BasePart") then
		return
	end
	local o = math.clamp(open, 0, 1)
	local closed = CFrame.new(0, 0.51, 0)
	local aside = CFrame.new(0.5, -0.51, 0.12)
	local lift = math.sin(o * math.pi) * 0.25
	cap.CFrame = capsule.WorldPivot * closed:Lerp(aside, o) * CFrame.new(0, lift, 0) * Parts.UPRIGHT
end

------------------------------------------------------------------------------
-- Breathing
------------------------------------------------------------------------------

-- What animate() needs per model, found once (no recursive search per frame).
type Breath = {
	pin: BasePart,
	light: PointLight?,
	look: Look,
	phase: number,
	lit: boolean,
	condition: string,
	segments: { { part: BasePart, along: number, base: Color3 } }, -- Coil: the travelling light
}
local breaths: { [Model]: Breath | false } = setmetatable({}, { __mode = "k" }) :: any
local phases = Random.new()

local function breathOf(model: Model): Breath?
	local known = breaths[model]
	if known == false then
		return nil
	elseif known then
		return known :: Breath
	end
	local pin = model:FindFirstChild("Pin", true)
	if pin == nil or not pin:IsA("BasePart") then
		breaths[model] = false -- (a husk, an empty capsule: nothing breathes)
		return nil
	end
	local element = if pin.Parent and pin.Parent:IsA("Model") then pin.Parent else model
	local kind = CoreModel.kindOf(element:GetAttribute("Kind") :: string?, nil)
	local segments = {}
	if kind == "Coil" then
		for _, part in element:GetChildren() do
			local along = part:GetAttribute("Along")
			if part:IsA("BasePart") and typeof(along) == "number" then
				table.insert(segments, { part = part, along = along, base = part.Color })
			end
		end
	end
	local condition = element:GetAttribute("Condition")
	local breath: Breath = {
		pin = pin,
		light = pin:FindFirstChildOfClass("PointLight"),
		look = LOOKS[kind] or LOOKS.Cluster,
		phase = phases:NextNumber(0, 7), -- seconds: its own place in the breath
		lit = true,
		condition = if typeof(condition) == "string" then condition else "Intact",
		segments = segments,
	}
	breaths[model] = breath
	return breath
end

-- Breathing light: brightness 0.22..0.38 over its period; a Pod pulses faster; a Coil's
-- light travels along it and changes colour; bruised = slower and uneven; ruptured = flickers.
function CoreModel.animate(model: Model, now: number, lit: boolean?)
	local breath = breathOf(model)
	if breath == nil then
		return
	end
	local pin, light, look = breath.pin, breath.light, breath.look
	local t = now + breath.phase
	local period = look.period
	local wave: number
	if breath.condition == "Bruised" then
		-- slower, and every other breath shallower (uneven)
		period *= 1.6
		wave = 0.5 + 0.5 * math.sin(t * math.pi * 2 / period)
		wave *= 0.65 + 0.35 * math.abs(math.sin(t * math.pi / period))
	else
		wave = 0.5 + 0.5 * math.sin(t * math.pi * 2 / period)
	end
	if breath.condition == "Ruptured" and math.noise(t * 6, breath.phase) > 0.25 then
		wave = 0.05 -- (a short dip: the light stutters)
	end
	local on = lit ~= false
	if light and breath.lit ~= on then
		breath.lit = on
		light.Enabled = on
	end
	if light and on then
		light.Brightness = 0.22 + 0.16 * wave
	end
	local color = look.light
	if look.light2 then
		local mix = 0.5 + 0.5 * math.sin(t * math.pi * 2 / 7)
		color = look.light:Lerp(look.light2 :: Color3, mix)
		if light and on then
			light.Color = color
		end
		pin.Color = color
	end
	pin.Transparency = if on then 0.1 + 0.25 * (1 - wave) else 0.7
	-- Coil: a soft glow travels along the spiral (only while lit)
	if #breath.segments > 0 then
		local head = (t / 3.2) % 1.3 - 0.15
		for _, segment in breath.segments do
			local bump = if on then math.max(0, 1 - math.abs(segment.along - head) / 0.15) else 0
			local wanted = segment.base:Lerp(color, bump * 0.55)
			if segment.part.Color ~= wanted then
				segment.part.Color = wanted
			end
		end
	end
end

-- Where stash capsule number `index` (1..8) stands on the stash shelf (the server's
-- "StashShelf" marker): two rows of four along Z, upright.
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
