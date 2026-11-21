--!strict
-- VatVisual: what is INSIDE your lab's vat, on your screen only (the server builds the
-- empty glass vat; Server/Systems/Contraband/LabBuilder).
--
--   fluid      a cylinder of liquid around the clone: amber (MATRIX), teal (FRAME), clear
--              (SHELL / READY), drained grey (EMPTY / EXTRACTING). Colour and level glide.
--   fill line  a thin bright disc at the FRAME gel height (the progress bar inside the vat)
--   bubbles    a pool of small glossy beads rising (parts, not particles: Roblox ships no
--              round bubble texture); they fade in at the bottom and flatten and thin out as
--              they break at the surface (never pop on / off), tinted by the fluid's light;
--              their rate tells the stage (Matrix 2/s, Frame 4/s, Shell 1/s, phase shift
--              20/s with faster bubbles: 40 in the pool is enough for the surge)
--   glow       one PointLight in the vat, coloured by the fluid (no shadows)
--   screen     a SurfaceGui on the server's "VatScreen" part: stage, %, time left, a bar
--   clone      CloneModel, drifting ±0.05 stud with the fluid
--
-- Phase shift (at 25 % and 75 %, ART_V2 §5.1), 2 s: bubble surge, light dims to 0.2 and
-- comes back, the screen glitches (3 × 0.3 s of random characters), the old form flickers out
-- and the new one resolves.
--
--   VatVisual.new(vatCore, screen, parent)   → Vat
--   VatVisual.update(vat, view, dt, now)     view = { stage, progress, timeLeft, running, snap }
--   VatVisual.setCloneHidden(vat, hidden)    (the extraction moves the shell to the bench)
--   VatVisual.setCulled(vat, culled)         far away: light off, bubbles cleared (call it on
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
	age: number, -- seconds since it left the bottom (fade in)
	size: number, -- diameter
	breaking: boolean, -- flattened at the surface (Size written while true)
}

export type Vat = {
	core: BasePart,
	folder: Folder,
	clone: CloneModel.Clone,
	cloneHidden: boolean,
	fluid: BasePart,
	surface: BasePart,
	fillLine: BasePart,
	bottomGlow: BasePart,
	lightPart: BasePart,
	light: PointLight,
	bubbles: { Bubble },
	spawnDebt: number,
	moved: { BasePart }, -- reused every frame (no table per frame)
	cframes: { CFrame },
	culled: boolean,
	-- what was last written to the fluid parts (skip the writes when nothing changed)
	shownLevel: number,
	shownColor: Color3,
	shownTransparency: number,
	shownAccent: Color3?,
	shownFill: number,
	-- smoothed fluid
	level: number,
	color: Color3,
	transparency: number,
	-- phase
	phase: CloneModel.Stage,
	shiftFrom: CloneModel.Stage?,
	shiftStart: number,
	-- screen
	gui: SurfaceGui?,
	title: TextLabel?,
	big: TextLabel?,
	sub: TextLabel?,
	bar: Frame?,
	random: Random,
}

local MATRIX_END = 0.25
local FRAME_END = 0.75
local SHIFT_TIME = 2
local FLUID_DIAMETER = 4.2
local FLUID_HEIGHT = 7.6
local DRAINED = 0.3
local BOTTOM = -FLUID_HEIGHT / 2 -- relative to VatCore
local MAX_BUBBLES = 40
local BUBBLE_FADE_IN = 0.15 -- seconds
local BUBBLE_BREAK = 0.3 -- studs under the surface where a bubble flattens and thins out
local BUBBLE_TRANSPARENCY = 0.45
local WHITE = Color3.new(1, 1, 1)
local BOTTOM_GLOW_TRANSPARENCY = 0.9
local GLITCH = "#%&@$/\\|=+<>?*01"

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Fluid colour and transparency per look.
local FLUID = {
	MATRIX = { color = rgb(200, 130, 40), transparency = 0.55, light = rgb(255, 170, 80) },
	FRAME = { color = rgb(60, 140, 140), transparency = 0.55, light = rgb(110, 210, 200) },
	SHELL = { color = rgb(200, 220, 225), transparency = 0.8, light = rgb(205, 230, 255) },
	DRAINED = { color = rgb(110, 115, 118), transparency = 0.5, light = rgb(170, 190, 210) },
}

-- Screen accent per look (bar and big line).
local ACCENT = {
	MATRIX = rgb(240, 170, 80),
	FRAME = rgb(120, 220, 210),
	SHELL = rgb(225, 235, 240),
	READY = rgb(120, 220, 200),
	IDLE = rgb(150, 160, 170),
}

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

local function buildScreen(vat: Vat, screen: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "VatScreenGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 150
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.ClipsDescendants = true
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = rgb(8, 12, 14)
	back.BorderSizePixel = 0
	back.Parent = gui
	local function label(name: string, y: number, height: number, color: Color3): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = name
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromScale(0.07, y)
		text.Size = UDim2.fromScale(0.86, height)
		text.Font = Enum.Font.RobotoMono
		text.TextScaled = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextColor3 = color
		text.Text = ""
		text.Parent = back
		return text
	end
	local title = label("Title", 0.08, 0.14, rgb(120, 135, 140))
	title.Text = "VAT 01 · CULTURE"
	vat.title = title
	vat.big = label("Big", 0.27, 0.3, rgb(240, 240, 240))
	vat.sub = label("Sub", 0.6, 0.14, rgb(170, 185, 190))
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromScale(0.07, 0.84)
	track.Size = UDim2.fromScale(0.86, 0.05)
	track.BackgroundColor3 = rgb(40, 46, 50)
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

function VatVisual.new(vatCore: BasePart, screen: BasePart?, parent: Instance): Vat
	local folder = Instance.new("Folder")
	folder.Name = "VatVisual"
	local function at(y: number): CFrame
		return vatCore.CFrame * CFrame.new(0, y, 0) * Parts.UPRIGHT
	end
	local fluid = Parts.disc(FLUID_DIAMETER, DRAINED, {
		Name = "Fluid",
		Color = FLUID.DRAINED.color,
		Transparency = FLUID.DRAINED.transparency,
		Reflectance = 0.05,
		CFrame = at(BOTTOM + DRAINED / 2),
		Parent = folder,
	})
	local surface = Parts.disc(FLUID_DIAMETER - 0.04, 0.03, {
		Name = "Surface",
		Color = rgb(235, 240, 240),
		Transparency = 0.6,
		Reflectance = 0.2,
		CFrame = at(BOTTOM + DRAINED),
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
		CFrame = at(0),
		Parent = folder,
	})
	-- (a faint tint on the vat floor: SmoothPlastic, not Neon, so it never blooms into a
	-- glowing plate; the PointLight does the glowing; ART_V2 "Neon only for pinpoints")
	local bottomGlow = Parts.disc(3.6, 0.03, {
		Name = "BottomGlow",
		Color = FLUID.DRAINED.light,
		Transparency = BOTTOM_GLOW_TRANSPARENCY,
		CFrame = at(BOTTOM + 0.02),
		Parent = folder,
	})
	local lightPart = Parts.part({
		Name = "GlowSource",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
		CFrame = vatCore.CFrame,
		Parent = folder,
	})
	local light = Instance.new("PointLight")
	light.Brightness = 0.6
	light.Range = 8
	light.Shadows = false
	light.Color = FLUID.DRAINED.light
	light.Parent = lightPart

	local vat: Vat = {
		core = vatCore,
		folder = folder,
		clone = CloneModel.new(folder),
		cloneHidden = false,
		fluid = fluid,
		surface = surface,
		fillLine = fillLine,
		bottomGlow = bottomGlow,
		lightPart = lightPart,
		light = light,
		bubbles = {},
		spawnDebt = 0,
		moved = {},
		cframes = {},
		culled = false,
		shownLevel = -1,
		shownColor = FLUID.DRAINED.color,
		shownTransparency = -1,
		shownAccent = nil,
		shownFill = -1,
		level = DRAINED,
		color = FLUID.DRAINED.color,
		transparency = FLUID.DRAINED.transparency,
		phase = "NONE",
		shiftFrom = nil,
		shiftStart = -100,
		gui = nil,
		title = nil,
		big = nil,
		sub = nil,
		bar = nil,
		random = Random.new(),
	}
	for i = 1, MAX_BUBBLES do
		local d = 0.12 + 0.13 * ((i * 37) % 10) / 10
		-- (an ellipsoid, not a Ball: a Ball can't be flattened when it breaks at the surface)
		local part = Parts.ellipsoid(Vector3.new(d, d, d), {
			Name = "Bubble",
			Color = rgb(245, 248, 248),
			Transparency = 1,
			Reflectance = 0.3,
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
			breaking = false,
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

-- The look the fluid should have for a view.
local function fluidTarget(view: View, phase: CloneModel.Stage): (string, number)
	if view.stage == "Empty" or view.stage == "Extracting" then
		return "DRAINED", DRAINED
	end
	if view.stage == "Ready" then
		return "SHELL", FLUID_HEIGHT
	end
	return phase, FLUID_HEIGHT
end

local function retireBubble(bubble: Bubble)
	bubble.active = false
	bubble.part.Transparency = 1
	if bubble.breaking then
		bubble.breaking = false
		bubble.part.Size = Vector3.new(bubble.size, bubble.size, bubble.size)
	end
end

local function updateBubbles(vat: Vat, rate: number, surge: boolean, dt: number, now: number)
	vat.spawnDebt += rate * dt
	local top = BOTTOM + vat.level - 0.1
	local moved, cframes = vat.moved, vat.cframes
	table.clear(moved)
	table.clear(cframes)
	local base = vat.core.CFrame
	-- (bubbles take a little of the fluid's light colour: amber / teal / pearl)
	local tint = vat.light.Color:Lerp(WHITE, 0.7)
	for _, bubble in vat.bubbles do
		if not bubble.active and vat.spawnDebt >= 1 and vat.level > 1 then
			vat.spawnDebt -= 1
			local angle = vat.random:NextNumber(0, math.pi * 2)
			local radius = math.sqrt(vat.random:NextNumber()) * 1.75
			bubble.active = true
			bubble.age = 0
			bubble.x = math.cos(angle) * radius
			bubble.z = math.sin(angle) * radius
			bubble.y = BOTTOM + 0.15
			-- (the surge's bubbles are faster: 20/s then fits in the pool)
			bubble.speed = if surge
				then vat.random:NextNumber(3, 4)
				else vat.random:NextNumber(1.3, 2.4)
			bubble.part.Color = tint
		end
		if bubble.active then
			bubble.age += dt
			bubble.y += bubble.speed * dt
			if bubble.y >= top then
				retireBubble(bubble)
			else
				-- fade in at the bottom; at the surface, flatten and thin out (it breaks)
				local below = top - bubble.y
				local fadeIn = math.clamp(bubble.age / BUBBLE_FADE_IN, 0, 1)
				local breakT = 1 - math.clamp(below / BUBBLE_BREAK, 0, 1)
				local visible = fadeIn * (1 - breakT)
				bubble.part.Transparency = 1 - (1 - BUBBLE_TRANSPARENCY) * visible
				if breakT > 0 then
					bubble.breaking = true
					local d = bubble.size
					bubble.part.Size = Vector3.new(
						d * (1 + 0.3 * breakT),
						d * (1 - 0.6 * breakT),
						d * (1 + 0.3 * breakT)
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

-- Far away (LabController stops calling update): the light goes off and the bubbles are
-- cleared, instead of freezing mid-fluid with the light on. Called on the change only.
function VatVisual.setCulled(vat: Vat, culled: boolean)
	if vat.culled == culled then
		return
	end
	vat.culled = culled
	vat.light.Enabled = not culled
	vat.bottomGlow.Transparency = if culled then 1 else BOTTOM_GLOW_TRANSPARENCY
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
	if bigLabel.Text ~= big then
		bigLabel.Text = big
	end
	if subLabel.Text ~= sub then
		subLabel.Text = sub
	end
	-- (written only when they change: a SurfaceGui redraws on every property write)
	if vat.shownAccent ~= accent then
		vat.shownAccent = accent
		bigLabel.TextColor3 = accent
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

	-- Fluid colour / level glide toward the look.
	local look, targetLevel = fluidTarget(view, phase)
	local fluidLook = FLUID[look]
	local k = 1 - math.exp(-dt * (if view.snap then 60 else 1.4))
	vat.level += (targetLevel - vat.level) * k
	vat.color = vat.color:Lerp(fluidLook.color, k)
	vat.transparency += (fluidLook.transparency - vat.transparency) * k
	-- (the glide never quite arrives: snap the last hair so the writes below stop)
	if math.abs(targetLevel - vat.level) < 0.002 then
		vat.level = targetLevel
	end
	if math.abs(fluidLook.transparency - vat.transparency) < 0.002 then
		vat.transparency = fluidLook.transparency
	end
	local c, t = vat.color, fluidLook.color
	if math.abs(c.R - t.R) + math.abs(c.G - t.G) + math.abs(c.B - t.B) < 0.004 then
		vat.color = t
	end
	if vat.level ~= vat.shownLevel then
		vat.shownLevel = vat.level
		vat.fluid.Size = Vector3.new(vat.level, FLUID_DIAMETER, FLUID_DIAMETER)
		vat.fluid.CFrame = vat.core.CFrame
			* CFrame.new(0, BOTTOM + vat.level / 2, 0)
			* Parts.UPRIGHT
		vat.surface.CFrame = vat.core.CFrame * CFrame.new(0, BOTTOM + vat.level, 0) * Parts.UPRIGHT
	end
	if vat.color ~= vat.shownColor then
		vat.shownColor = vat.color
		vat.fluid.Color = vat.color
	end
	if vat.transparency ~= vat.shownTransparency then
		vat.shownTransparency = vat.transparency
		vat.fluid.Transparency = vat.transparency
	end
	if vat.bottomGlow.Color ~= vat.light.Color then
		vat.bottomGlow.Color = vat.light.Color
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

	-- Glow: fluid-coloured, dims to 0.2 during a shift (Sine in / out: a light dimming).
	local brightness = 0.6
	if shifting then
		if shiftT < 0.3 then
			brightness = 0.6 - 0.4 * sineInOut(shiftT / 0.3)
		elseif shiftT < 1.6 then
			brightness = 0.2 + (if math.sin(now * 23) > 0.6 then 0.15 else 0)
		else
			brightness = 0.2 + 0.4 * sineInOut((shiftT - 1.6) / 0.4)
		end
	elseif view.stage == "Empty" or view.stage == "Extracting" then
		brightness = 0.25
	end
	if vat.light.Brightness ~= brightness then
		vat.light.Brightness = brightness
	end
	if vat.light.Color ~= fluidLook.light then
		local lightColor = vat.light.Color:Lerp(fluidLook.light, k)
		local l = fluidLook.light
		if
			math.abs(lightColor.R - l.R)
				+ math.abs(lightColor.G - l.G)
				+ math.abs(lightColor.B - l.B)
			< 0.004
		then
			lightColor = l
		end
		vat.light.Color = lightColor
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

	-- Screen.
	local glitch = shifting and (shiftT % 0.6) < 0.3 and shiftT < 1.8
	if view.stage == "Empty" then
		setScreen(
			vat,
			"EMPTY · PLANT CULTURE",
			clock(view.total) .. " TO GROW",
			0,
			ACCENT.IDLE,
			false
		)
	elseif view.stage == "Extracting" then
		setScreen(vat, "EXTRACTING", "STAND BY", 1, ACCENT.IDLE, false)
	elseif view.stage == "Ready" then
		setScreen(vat, "READY 100 %", "READY · EXTRACT", 1, ACCENT.READY, false)
	else
		local percent = math.floor(progress * 100)
		local sub = if view.running then clock(view.timeLeft) .. " LEFT" else "PAUSED"
		setScreen(vat, `{phase} {percent} %`, sub, progress, ACCENT[phase] or ACCENT.IDLE, glitch)
	end
end

function VatVisual.destroy(vat: Vat)
	if vat.gui then
		vat.gui:Destroy()
	end
	vat.folder:Destroy()
end

return VatVisual
