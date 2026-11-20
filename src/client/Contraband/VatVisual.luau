--!strict
-- VatVisual: what is INSIDE your lab's vat, on your screen only (the server builds the
-- empty glass vat; Server/Systems/Contraband/LabBuilder).
--
--   fluid      a cylinder of liquid around the clone: amber (MATRIX), teal (FRAME), clear
--              (SHELL / READY), drained grey (EMPTY / EXTRACTING). Colour and level glide.
--   fill line  a thin bright disc at the FRAME gel height (the progress bar inside the vat)
--   bubbles    a pool of small balls rising; their rate tells the stage (Matrix 2/s, Frame
--              4/s, Shell 1/s, phase shift 20/s)
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
local MAX_BUBBLES = 24
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
	local bottomGlow = Parts.disc(3.6, 0.03, {
		Name = "BottomGlow",
		Material = Enum.Material.Neon,
		Color = FLUID.DRAINED.light,
		Transparency = 0.88,
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
		local part = Parts.ball(d, {
			Name = "Bubble",
			Color = rgb(245, 248, 248),
			Transparency = 1,
			Reflectance = 0.3,
			CFrame = vatCore.CFrame,
			Parent = folder,
		})
		table.insert(
			vat.bubbles,
			{ part = part, active = false, x = 0, z = 0, y = 0, speed = 1, seed = i }
		)
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

local function updateBubbles(vat: Vat, rate: number, dt: number, now: number)
	vat.spawnDebt += rate * dt
	local top = BOTTOM + vat.level - 0.1
	local moved: { BasePart } = {}
	local cframes: { CFrame } = {}
	local base = vat.core.CFrame
	for _, bubble in vat.bubbles do
		if not bubble.active and vat.spawnDebt >= 1 and vat.level > 1 then
			vat.spawnDebt -= 1
			local angle = vat.random:NextNumber(0, math.pi * 2)
			local radius = math.sqrt(vat.random:NextNumber()) * 1.75
			bubble.active = true
			bubble.x = math.cos(angle) * radius
			bubble.z = math.sin(angle) * radius
			bubble.y = BOTTOM + 0.15
			bubble.speed = vat.random:NextNumber(1.3, 2.4)
			bubble.part.Transparency = 0.4
		end
		if bubble.active then
			bubble.y += bubble.speed * dt
			if bubble.y >= top then
				bubble.active = false
				bubble.part.Transparency = 1
			else
				local wobble = math.sin(now * 5 + bubble.seed) * 0.06
				table.insert(moved, bubble.part)
				table.insert(cframes, base * CFrame.new(bubble.x + wobble, bubble.y, bubble.z))
			end
		end
	end
	vat.spawnDebt = math.min(vat.spawnDebt, 3)
	if #moved > 0 then
		workspace:BulkMoveTo(moved, cframes, Enum.BulkMoveMode.FireCFrameChanged)
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
	bigLabel.TextColor3 = accent
	bar.BackgroundColor3 = accent
	bar.Size = UDim2.fromScale(math.clamp(fill, 0, 1), 1)
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
			visible = (1 - shiftT * 0.7) * flicker
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
	vat.fluid.Size = Vector3.new(vat.level, FLUID_DIAMETER, FLUID_DIAMETER)
	vat.fluid.CFrame = vat.core.CFrame * CFrame.new(0, BOTTOM + vat.level / 2, 0) * Parts.UPRIGHT
	vat.fluid.Color = vat.color
	vat.fluid.Transparency = vat.transparency
	vat.surface.CFrame = vat.core.CFrame * CFrame.new(0, BOTTOM + vat.level, 0) * Parts.UPRIGHT
	vat.bottomGlow.Color = vat.light.Color

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

	-- Glow: fluid-coloured, dims to 0.2 during a shift.
	local brightness = 0.6
	if shifting then
		if shiftT < 0.3 then
			brightness = 0.6 - 0.4 * (shiftT / 0.3)
		elseif shiftT < 1.6 then
			brightness = 0.2 + (if math.sin(now * 23) > 0.6 then 0.15 else 0)
		else
			brightness = 0.2 + 0.4 * ((shiftT - 1.6) / 0.4)
		end
	elseif view.stage == "Empty" or view.stage == "Extracting" then
		brightness = 0.25
	end
	vat.light.Brightness = brightness
	vat.light.Color = vat.light.Color:Lerp(fluidLook.light, k)

	-- Bubbles.
	local rate = 0
	if shifting then
		rate = 20
	elseif view.stage == "Growing" then
		rate = if phase == "MATRIX" then 2 elseif phase == "FRAME" then 4 else 1
	elseif view.stage == "Ready" then
		rate = 0.6
	end
	updateBubbles(vat, rate, dt, now)

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
