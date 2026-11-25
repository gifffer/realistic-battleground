--!strict
-- VatVisual: what is INSIDE your lab's vat, on your screen only (the server builds the
-- empty vat: Server/Systems/Contraband/VatBuilder). The look is the first concept
-- (direction/art/02_clone_stages_vats.png): a squat column of pastel fluid, amber → teal →
-- clear, with the clone standing in its lower half and a small monitor at the front-right.
--
--   fluid      ONE transparent cylinder: amber (MATRIX), teal (FRAME), clearing from teal to
--              clear across SHELL (the clearing IS the progress), drained grey (EMPTY /
--              EXTRACTING). Its top stays 0.58 under the cap: the dark band of the concept.
--   fill line  a thin bright band at the FRAME gel height (the progress inside the lattice)
--   bubbles    a pool of small OPAQUE beads rising (parts, not particles: Roblox ships no
--              round bubble texture); the fluid in front fogs them. They grow in at the bottom
--              and flatten and shrink as they break at the surface (never pop on / off). Rate
--              per stage: Matrix 2/s, Frame 4/s, Shell 1/s, phase shift 20/s (40 in the pool).
--   lights     GlowSource (inside, lights the clone's front) + BackGlow (inside, behind the
--              clone: its outline stands out on a lit back wall of fluid) + a weak FrontWash
--              (OUTSIDE the glass, in front:
--              Roblox draws only the front faces of a part, so a light inside a cylinder never
--              lights the skin we look at; FrontWash lights it and pools colour on the floor).
--              No shadows.
--   screen     a SurfaceGui on the server's "VatScreen": ONE bold line in the concept's format
--              ("MATRIX 18%", "FRAME 57%", "READY 100%"), a small line under it, a bar.
--   clone      CloneModel, drifting ±0.05 stud with the fluid
--
-- THE RULE THAT KEEPS IT READABLE AND STEADY: only two parts of the vat are see-through, the
-- server's glass and this fluid. Everything inside is opaque (the fluid in front of it gives
-- the washed look). Nested see-through parts flip their draw order as the camera turns
-- (flicker), and Roblox's Glass material hides see-through parts behind it entirely.
--
-- Phase shift (at 25 % and 75 %, ART_V2 §5.1), 2 s: bubble surge, the lights dim to 0.2 and
-- come back, the screen glitches (3 × 0.3 s of random characters), the old form flickers out
-- and the new one resolves.
--
--   VatVisual.new(vatCore, screen, parent)   → Vat
--   VatVisual.update(vat, view, dt, now)     view = { stage, progress, timeLeft, running, snap }
--   VatVisual.setCloneHidden(vat, hidden)    (the extraction moves the shell to the bench)
--   VatVisual.setCulled(vat, culled)         far away: lights off, bubbles cleared (call it on
--                                            the change only; update() is not called then)
--   VatVisual.destroy(vat)

local CloneModel = require(script.Parent.CloneModel)
local Parts = require(script.Parent.Parts)

local VatVisual = {}

export type CultureStage = "Empty" | "Growing" | "Ready" | "Extracting"

export type View = {
	stage: CultureStage,
	progress: number, -- 0..1
	timeLeft: number, -- seconds
	total: number, -- seconds for a full culture
	running: boolean,
	snap: boolean, -- true = jump straight to this state (first view, no phase shift)
}

type Bubble = {
	part: BasePart,
	active: boolean,
	x: number,
	z: number,
	y: number,
	speed: number,
	seed: number,
	age: number, -- seconds since it left the bottom (grows in)
	size: number, -- diameter
	shownScale: number, -- the scale last written to Size (skip identical writes)
}

export type Vat = {
	core: BasePart,
	folder: Folder,
	clone: CloneModel.Clone,
	cloneHidden: boolean,
	fluid: BasePart,
	fillLine: BasePart,
	lightPart: BasePart,
	light: PointLight,
	washPart: BasePart,
	wash: PointLight,
	backPart: BasePart,
	back: PointLight,
	bubbles: { Bubble },
	spawnDebt: number,
	moved: { BasePart }, -- reused every frame (no table per frame)
	cframes: { CFrame },
	culled: boolean,
	-- what was last written to the fluid (skip the writes when nothing changed)
	shownLevel: number,
	shownColor: Color3,
	shownTransparency: number,
	shownAccent: Color3?,
	shownFill: number,
	-- smoothed fluid and light
	level: number,
	color: Color3,
	transparency: number,
	lightColor: Color3,
	lightOffset: Vector3, -- GlowSource, relative to VatCore
	-- phase
	phase: CloneModel.Stage,
	shiftFrom: CloneModel.Stage?,
	shiftStart: number,
	-- screen
	gui: SurfaceGui?,
	big: TextLabel?,
	sub: TextLabel?,
	bar: Frame?,
	random: Random,
}

local MATRIX_END = 0.25
local FRAME_END = 0.75
local SHIFT_TIME = 2

-- The fluid, relative to VatCore (4.05 above the floor). The glass inside runs 1.23..8.05
-- above the floor and is 5.5 wide: the fluid is 0.1 clear of it on every side, its bottom
-- 0.04 above the glass floor, its full top 0.58 under the cap.
local FLUID_DIAMETER = 5.3
local FLUID_BOTTOM = -2.78
local FLUID_HEIGHT = 6.2
local DRAINED = 0.3

local MAX_BUBBLES = 40
local BUBBLE_GROW = 0.25 -- seconds a new bubble takes to reach its size
local BUBBLE_BREAK = 0.3 -- studs under the surface where a bubble flattens and shrinks
local BUBBLE_RADIUS = 2.3 -- how far from the axis bubbles start (the fluid's radius is 2.65)

local GLOW_RANGE = 6.5
local WASH_RANGE = 9
local WASH_BRIGHTNESS = 0.35 -- (low: brighter lit the fluid's skin into a flat opaque column)
-- BackGlow: a second, small light INSIDE, behind the clone, so its outline and the scaffold
-- stand out against a lit back of the column (the concept's backlit look)
local BACK_RANGE = 4.5
local BACK_SHARE = 0.7 -- of GlowSource's brightness
local BACK_OFFSET = Vector3.new(0, 0.6, 1.7)
-- FrontWash's place, relative to VatCore: outside the glass, 4.5 studs in front, at the
-- clone's head (≈ 5.6 studs above the floor: it reaches the column's top too).
local WASH_OFFSET = Vector3.new(0, 1.6, -4.5)

local GLITCH = "#%&@$/\\|=+<>?*01"

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

type Look = {
	color: Color3,
	transparency: number,
	light: Color3,
	brightness: number, -- GlowSource's brightness (FrontWash follows it, see below)
	glowAt: Vector3, -- GlowSource's place, relative to VatCore
}

-- Fluid and lights per look (VAT_SPEC §4.1; the concept's pastel columns).
local LOOKS: { [string]: Look } = {
	MATRIX = {
		color = rgb(232, 168, 98),
		transparency = 0.45, -- (0.25 hid the scaffold and lobes: a solid peach column)
		light = rgb(255, 170, 95),
		brightness = 0.5, -- (lower: close to the lobes it made a hot orange spot)
		-- (in FRONT of the lobes' cluster: a light inside the opaque lobes would leave their
		-- outer faces dark)
		glowAt = Vector3.new(0, 0.55, -1.3),
	},
	FRAME = {
		color = rgb(115, 190, 180),
		transparency = 0.5,
		light = rgb(120, 225, 205),
		brightness = 0.9,
		glowAt = Vector3.new(0, 0.4, 0),
	},
	SHELL = {
		color = rgb(165, 200, 210),
		transparency = 0.58, -- (0.35 read as a milky column: the body must show)
		light = rgb(185, 230, 250),
		brightness = 0.75,
		-- (in front of the body, as in the concept, but near the glass: 1 stud from the chest
		-- it burnt a white spot on the port)
		glowAt = Vector3.new(0, 1.2, -1.9),
	},
	DRAINED = {
		color = rgb(110, 118, 122),
		transparency = 0.55,
		light = rgb(170, 190, 210),
		brightness = 0.25,
		glowAt = Vector3.new(0, 0.4, 0),
	},
}

-- Screen accent per look (the bar only: the big line stays one calm colour).
local ACCENT = {
	MATRIX = rgb(240, 170, 80),
	FRAME = rgb(120, 220, 210),
	SHELL = rgb(190, 230, 245),
	READY = rgb(120, 220, 200),
	IDLE = rgb(150, 160, 170),
}
local SCREEN_TEXT = rgb(225, 240, 235)
local SCREEN_SUB = rgb(140, 160, 160)

local function phaseOf(progress: number): CloneModel.Stage
	if progress < MATRIX_END then
		return "MATRIX"
	elseif progress < FRAME_END then
		return "FRAME"
	end
	return "SHELL"
end

local function stageT(phase: CloneModel.Stage, progress: number): number
	if phase == "MATRIX" then
		return progress / MATRIX_END
	elseif phase == "FRAME" then
		return (progress - MATRIX_END) / (FRAME_END - MATRIX_END)
	end
	return (progress - FRAME_END) / (1 - FRAME_END)
end

local function clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- The monitor's face: 1.5 × 0.8 studs at 160 px per stud = 240 × 128 px.
--   big line   y 0.14..0.52, bold, centred ("FRAME 57%")
--   small line y 0.60..0.76, mono, dim ("3:42 LEFT")
--   bar        y 0.85, thin, the stage's accent
-- (Brightness 1: brighter made the lines bloom into each other.)
local function buildScreen(vat: Vat, screen: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "VatScreenGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 160
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.ClipsDescendants = true
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = rgb(8, 12, 14)
	back.BorderSizePixel = 0
	back.Parent = gui
	local function label(
		name: string,
		y: number,
		height: number,
		font: Enum.Font,
		maxSize: number,
		color: Color3
	): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = name
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromScale(0.06, y)
		text.Size = UDim2.fromScale(0.88, height)
		text.Font = font
		text.TextScaled = true
		text.TextXAlignment = Enum.TextXAlignment.Center
		text.TextYAlignment = Enum.TextYAlignment.Center
		text.TextColor3 = color
		text.Text = ""
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = maxSize
		limit.Parent = text
		text.Parent = back
		return text
	end
	vat.big = label("Big", 0.14, 0.38, Enum.Font.GothamBold, 44, SCREEN_TEXT)
	vat.sub = label("Sub", 0.6, 0.16, Enum.Font.RobotoMono, 20, SCREEN_SUB)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromScale(0.08, 0.85)
	track.Size = UDim2.fromScale(0.84, 0.04)
	track.BackgroundColor3 = rgb(32, 38, 42)
	track.BorderSizePixel = 0
	track.Parent = back
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = ACCENT.IDLE
	bar.BorderSizePixel = 0
	bar.Parent = track
	vat.bar = bar
	gui.Parent = screen
	vat.gui = gui
end

local function pointLight(parent: BasePart, range: number, color: Color3): PointLight
	local light = Instance.new("PointLight")
	light.Brightness = 0
	light.Range = range
	light.Shadows = false
	light.Color = color
	light.Parent = parent
	return light
end

function VatVisual.new(vatCore: BasePart, screen: BasePart?, parent: Instance): Vat
	local folder = Instance.new("Folder")
	folder.Name = "VatVisual"
	local drained = LOOKS.DRAINED
	local fluid = Parts.disc(FLUID_DIAMETER, DRAINED, {
		Name = "Fluid",
		Color = drained.color,
		Transparency = drained.transparency,
		Reflectance = 0.05,
		CFrame = vatCore.CFrame * CFrame.new(0, FLUID_BOTTOM + DRAINED / 2, 0) * Parts.UPRIGHT,
		Parent = folder,
	})
	-- (a thin band inside the lattice's footprint only, resized with the height: a disc
	-- across the whole fluid read as a white plate)
	local fillLine = Parts.part({
		Name = "FillLine",
		Material = Enum.Material.Neon,
		Color = rgb(230, 240, 240),
		Size = Vector3.new(2, 0.025, 1),
		Transparency = 1,
		CFrame = vatCore.CFrame,
		Parent = folder,
	})
	local lightPart = Parts.part({
		Name = "GlowSource",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
		CFrame = vatCore.CFrame * CFrame.new(drained.glowAt),
		Parent = folder,
	})
	local washPart = Parts.part({
		Name = "FrontWash",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
		CFrame = vatCore.CFrame * CFrame.new(WASH_OFFSET),
		Parent = folder,
	})
	local backPart = Parts.part({
		Name = "BackGlow",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
		CFrame = vatCore.CFrame * CFrame.new(BACK_OFFSET),
		Parent = folder,
	})

	local vat: Vat = {
		core = vatCore,
		folder = folder,
		clone = CloneModel.new(folder),
		cloneHidden = false,
		fluid = fluid,
		fillLine = fillLine,
		lightPart = lightPart,
		light = pointLight(lightPart, GLOW_RANGE, drained.light),
		washPart = washPart,
		wash = pointLight(washPart, WASH_RANGE, drained.light),
		backPart = backPart,
		back = pointLight(backPart, BACK_RANGE, drained.light),
		bubbles = {},
		spawnDebt = 0,
		moved = {},
		cframes = {},
		culled = false,
		shownLevel = -1,
		shownColor = drained.color,
		shownTransparency = -1,
		shownAccent = nil,
		shownFill = -1,
		level = DRAINED,
		color = drained.color,
		transparency = drained.transparency,
		lightColor = drained.light,
		lightOffset = drained.glowAt,
		phase = "NONE",
		shiftFrom = nil,
		shiftStart = -100,
		gui = nil,
		big = nil,
		sub = nil,
		bar = nil,
		random = Random.new(),
	}
	for i = 1, MAX_BUBBLES do
		-- (0.08 .. 0.2 studs across, spread evenly over the pool)
		local d = 0.08 + 0.12 * ((i * 37) % 10) / 9
		-- (an ellipsoid, not a Ball: a Ball can't be flattened when it breaks at the surface)
		local part = Parts.ellipsoid(Vector3.new(d, d, d), {
			Name = "Bubble",
			Color = rgb(235, 245, 245),
			Transparency = 1,
			Reflectance = 0.4,
			CFrame = vatCore.CFrame,
			Parent = folder,
		})
		table.insert(vat.bubbles, {
			part = part,
			active = false,
			x = 0,
			z = 0,
			y = 0,
			speed = 1,
			seed = i,
			age = 0,
			size = d,
			shownScale = 1,
		})
	end
	if screen then
		buildScreen(vat, screen)
	end
	folder.Parent = parent
	return vat
end

function VatVisual.setCloneHidden(vat: Vat, hidden: boolean)
	vat.cloneHidden = hidden
end

-- The look the fluid should have for a view, its level, and (during SHELL) how far it has
-- cleared from the FRAME teal toward the SHELL clear (0..1).
local function fluidTarget(
	view: View,
	phase: CloneModel.Stage,
	t: number
): (Look, number, Look?, number)
	if view.stage == "Empty" or view.stage == "Extracting" then
		return LOOKS.DRAINED, DRAINED, nil, 0
	end
	if view.stage == "Ready" then
		return LOOKS.SHELL, FLUID_HEIGHT, nil, 0
	end
	if phase == "SHELL" then
		-- the fluid clears from teal to clear across the stage: the clearing IS the progress
		return LOOKS.SHELL, FLUID_HEIGHT, LOOKS.FRAME, 1 - math.clamp(t, 0, 1)
	end
	return LOOKS[phase] or LOOKS.DRAINED, FLUID_HEIGHT, nil, 0
end

local function retireBubble(bubble: Bubble)
	bubble.active = false
	bubble.part.Transparency = 1
	if bubble.shownScale ~= 1 then
		bubble.shownScale = 1
		bubble.part.Size = Vector3.new(bubble.size, bubble.size, bubble.size)
	end
end

local function updateBubbles(vat: Vat, rate: number, surge: boolean, dt: number, now: number)
	vat.spawnDebt += rate * dt
	local top = FLUID_BOTTOM + vat.level - 0.12
	local moved, cframes = vat.moved, vat.cframes
	table.clear(moved)
	table.clear(cframes)
	local base = vat.core.CFrame
	-- (bubbles take a little of the fluid's light colour: amber / teal / pearl)
	local tint = vat.lightColor:Lerp(Color3.new(1, 1, 1), 0.7)
	for _, bubble in vat.bubbles do
		if not bubble.active and vat.spawnDebt >= 1 and vat.level > 1 then
			vat.spawnDebt -= 1
			local angle = vat.random:NextNumber(0, math.pi * 2)
			local radius = math.sqrt(vat.random:NextNumber()) * BUBBLE_RADIUS
			bubble.active = true
			bubble.age = 0
			bubble.x = math.cos(angle) * radius
			bubble.z = math.sin(angle) * radius
			bubble.y = FLUID_BOTTOM + 0.15
			-- (the surge's bubbles are faster: 20/s then fits in the pool)
			bubble.speed = if surge
				then vat.random:NextNumber(3, 4)
				else vat.random:NextNumber(1.3, 2.4)
			bubble.part.Color = tint
			bubble.part.Transparency = 0
		end
		if bubble.active then
			bubble.age += dt
			bubble.y += bubble.speed * dt
			if bubble.y >= top then
				retireBubble(bubble)
			else
				-- grows in at the bottom; at the surface, flattens and shrinks (it breaks).
				-- (Size, not Transparency: an opaque bead inside the see-through fluid never
				-- flips its draw order with the camera)
				local below = top - bubble.y
				local grow = math.clamp(bubble.age / BUBBLE_GROW, 0, 1)
				local breakT = 1 - math.clamp(below / BUBBLE_BREAK, 0, 1)
				local scale = math.floor((0.2 + 0.8 * grow) * (1 - 0.7 * breakT) * 50 + 0.5) / 50
				if scale ~= bubble.shownScale or breakT > 0 then
					bubble.shownScale = scale
					local d = bubble.size * scale
					bubble.part.Size = Vector3.new(
						d * (1 + 0.4 * breakT),
						d * (1 - 0.5 * breakT),
						d * (1 + 0.4 * breakT)
					)
				end
				local wobble = math.sin(now * 5 + bubble.seed) * 0.06
				table.insert(moved, bubble.part)
				table.insert(cframes, base * CFrame.new(bubble.x + wobble, bubble.y, bubble.z))
			end
		end
	end
	vat.spawnDebt = math.min(vat.spawnDebt, math.max(1, rate * 0.2))
	if #moved > 0 then
		workspace:BulkMoveTo(moved, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Far away (LabController stops calling update): the lights go off and the bubbles are
-- cleared, instead of freezing mid-fluid with the lights on. Called on the change only.
function VatVisual.setCulled(vat: Vat, culled: boolean)
	if vat.culled == culled then
		return
	end
	vat.culled = culled
	vat.light.Enabled = not culled
	vat.wash.Enabled = not culled
	vat.back.Enabled = not culled
	if culled then
		vat.fillLine.Transparency = 1
		for _, bubble in vat.bubbles do
			if bubble.active then
				retireBubble(bubble)
			end
		end
		vat.spawnDebt = 0
	end
end

local function setScreen(
	vat: Vat,
	big: string,
	sub: string,
	fill: number,
	accent: Color3,
	glitch: boolean
)
	local bigLabel, subLabel, bar = vat.big, vat.sub, vat.bar
	if bigLabel == nil or subLabel == nil or bar == nil then
		return
	end
	if glitch then
		local chars = table.create(#big)
		for i = 1, #big do
			local k = vat.random:NextInteger(1, #GLITCH)
			chars[i] = string.sub(GLITCH, k, k)
		end
		big = table.concat(chars)
	end
	-- (written only when they change: a SurfaceGui redraws on every property write)
	if bigLabel.Text ~= big then
		bigLabel.Text = big
	end
	if subLabel.Text ~= sub then
		subLabel.Text = sub
	end
	if vat.shownAccent ~= accent then
		vat.shownAccent = accent
		bar.BackgroundColor3 = accent
	end
	local width = math.floor(math.clamp(fill, 0, 1) * 1000 + 0.5) / 1000
	if vat.shownFill ~= width then
		vat.shownFill = width
		bar.Size = UDim2.fromScale(width, 1)
	end
end

local function sineInOut(t: number): number
	local x = math.clamp(t, 0, 1)
	return 0.5 - 0.5 * math.cos(x * math.pi)
end

local function smooth(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

local function closeColor(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.004
end

function VatVisual.update(vat: Vat, view: View, dt: number, now: number)
	local progress = math.clamp(view.progress, 0, 1)
	local phase: CloneModel.Stage = phaseOf(progress)
	if view.stage == "Ready" then
		phase = "SHELL"
	end
	local growing = view.stage == "Growing" or view.stage == "Ready"

	-- Phase shift: a growing culture crossed 25 % or 75 % while we watched.
	if not growing then
		vat.phase = "NONE"
		vat.shiftFrom = nil
	elseif view.snap or vat.phase == "NONE" then
		vat.phase = phase
		vat.shiftFrom = nil
	elseif phase ~= vat.phase then
		vat.shiftFrom = vat.phase
		vat.shiftStart = now
		vat.phase = phase
	end
	local shiftT = now - vat.shiftStart
	local shifting = vat.shiftFrom ~= nil and shiftT < SHIFT_TIME
	if vat.shiftFrom ~= nil and not shifting then
		vat.shiftFrom = nil
	end

	-- Clone: the old form flickers out over the first second, the new one resolves.
	local cloneStage: CloneModel.Stage = if growing then phase else "NONE"
	local cloneT = if view.stage == "Ready" then 1 else stageT(phase, progress)
	local visible = 1
	if shifting then
		if shiftT < 1 then
			cloneStage = vat.shiftFrom :: CloneModel.Stage
			cloneT = 1
			local flicker = if math.sin(now * 40) > 0 then 1 else 0.35
			-- (fades fully out by 1 s: no pop when the new form takes over at 0)
			visible = (1 - smooth(shiftT)) * flicker
		else
			visible = math.clamp((shiftT - 1) / 1, 0, 1)
		end
	end
	if vat.cloneHidden then
		cloneStage = "NONE"
	end
	local led: CloneModel.Led = if view.stage == "Ready" then "ready" else "growing"
	CloneModel.update(vat.clone, cloneStage, cloneT, visible, led, now)
	local drift = vat.core.CFrame
		* CFrame.new(0, math.sin(now * 0.5) * 0.05, 0)
		* CFrame.Angles(0, math.sin(now * 0.3) * 0.02, 0)
	CloneModel.place(vat.clone, drift)

	-- Fluid colour / level glide toward the look (during SHELL: from teal toward clear).
	local target, targetLevel, from, fromWeight = fluidTarget(view, phase, stageT(phase, progress))
	local targetColor, targetTransparency = target.color, target.transparency
	local targetLight = target.light
	if from then
		targetColor = target.color:Lerp(from.color, fromWeight)
		targetTransparency += (from.transparency - target.transparency) * fromWeight
		targetLight = target.light:Lerp(from.light, fromWeight)
	end
	local k = 1 - math.exp(-dt * (if view.snap then 60 else 1.4))
	vat.level += (targetLevel - vat.level) * k
	vat.color = vat.color:Lerp(targetColor, k)
	vat.transparency += (targetTransparency - vat.transparency) * k
	vat.lightColor = vat.lightColor:Lerp(targetLight, k)
	vat.lightOffset = vat.lightOffset:Lerp(target.glowAt, k)
	-- (the glide never quite arrives: snap the last hair so the writes below stop)
	if math.abs(targetLevel - vat.level) < 0.002 then
		vat.level = targetLevel
	end
	if math.abs(targetTransparency - vat.transparency) < 0.002 then
		vat.transparency = targetTransparency
	end
	if closeColor(vat.color, targetColor) then
		vat.color = targetColor
	end
	if closeColor(vat.lightColor, targetLight) then
		vat.lightColor = targetLight
	end
	if vat.level ~= vat.shownLevel then
		vat.shownLevel = vat.level
		vat.fluid.Size = Vector3.new(vat.level, FLUID_DIAMETER, FLUID_DIAMETER)
		vat.fluid.CFrame = vat.core.CFrame
			* CFrame.new(0, FLUID_BOTTOM + vat.level / 2, 0)
			* Parts.UPRIGHT
	end
	if vat.color ~= vat.shownColor then
		vat.shownColor = vat.color
		vat.fluid.Color = vat.color
	end
	if vat.transparency ~= vat.shownTransparency then
		vat.shownTransparency = vat.transparency
		vat.fluid.Transparency = vat.transparency
	end

	-- Fill line at the FRAME gel height.
	if cloneStage == "FRAME" and not vat.cloneHidden then
		local y = CloneModel.LAYOUT.FEET + math.clamp(cloneT, 0, 1) * CloneModel.LAYOUT.HEIGHT
		-- the lattice's width at that height: legs, arms + torso, head
		local width = if y < -0.5 then 1.85 elseif y < 1.5 then 3.85 else 1.05
		vat.fillLine.Size = Vector3.new(width, 0.025, 0.85)
		vat.fillLine.CFrame = vat.core.CFrame * CFrame.new(0, y, 0)
		vat.fillLine.Transparency = Parts.fade(0.75, visible)
	else
		vat.fillLine.Transparency = 1
	end

	-- Lights: stage-coloured; during a shift they dim to 0.2 and come back (Sine in / out: a
	-- light dimming). FrontWash keeps the same share of its own brightness.
	local base = target.brightness
	local brightness = base
	if shifting then
		if shiftT < 0.3 then
			brightness = base - (base - 0.2) * sineInOut(shiftT / 0.3)
		elseif shiftT < 1.6 then
			brightness = 0.2 + (if math.sin(now * 23) > 0.6 then 0.15 else 0)
		else
			brightness = 0.2 + (base - 0.2) * sineInOut((shiftT - 1.6) / 0.4)
		end
	end
	-- (full while a culture is in, whatever its stage; it follows the shift's dimming, and a
	-- drained vat only gets a little)
	local washBrightness = if base < 0.5
		then WASH_BRIGHTNESS * base / 0.9
		else WASH_BRIGHTNESS * brightness / base
	if vat.light.Brightness ~= brightness then
		vat.light.Brightness = brightness
	end
	if vat.wash.Brightness ~= washBrightness then
		vat.wash.Brightness = washBrightness
	end
	local backBrightness = brightness * BACK_SHARE
	if vat.back.Brightness ~= backBrightness then
		vat.back.Brightness = backBrightness
	end
	if vat.light.Color ~= vat.lightColor then
		vat.light.Color = vat.lightColor
		vat.wash.Color = vat.lightColor
		vat.back.Color = vat.lightColor
	end
	local glowAt = vat.core.CFrame * CFrame.new(vat.lightOffset)
	if vat.lightPart.CFrame ~= glowAt then
		vat.lightPart.CFrame = glowAt
	end

	-- Bubbles.
	local rate = 0
	if shifting then
		rate = 20
	elseif view.stage == "Growing" then
		rate = if phase == "MATRIX" then 2 elseif phase == "FRAME" then 4 else 1
	elseif view.stage == "Ready" then
		rate = 0.6
	end
	updateBubbles(vat, rate, shifting, dt, now)

	-- Screen: one bold line in the concept's format, a small line, a bar.
	local glitch = shifting and (shiftT % 0.6) < 0.3 and shiftT < 1.8
	if view.stage == "Empty" then
		setScreen(vat, "EMPTY", "PLANT CULTURE", 0, ACCENT.IDLE, false)
	elseif view.stage == "Extracting" then
		setScreen(vat, "EXTRACTING", "", 1, ACCENT.IDLE, false)
	elseif view.stage == "Ready" then
		-- (no small line: the LED, the chime and the prompt already say "extract")
		setScreen(vat, "READY 100%", "", 1, ACCENT.READY, false)
	else
		-- (+1e-6: 0.57 × 100 is 56.99999 in floating point)
		local percent = math.floor(progress * 100 + 1e-6)
		local sub = if view.running then clock(view.timeLeft) .. " LEFT" else "PAUSED"
		setScreen(vat, `{phase} {percent}%`, sub, progress, ACCENT[phase] or ACCENT.IDLE, glitch)
	end
end

function VatVisual.destroy(vat: Vat)
	if vat.gui then
		vat.gui:Destroy()
	end
	vat.folder:Destroy()
end

return VatVisual
