--!strict
-- PassBox: the MOVING parts of the cold pass-box during an extraction (client only).
--
-- The box itself (body, deck, funnel, window, strip display) is static, built for everyone by
-- BenchLayout.buildStatic. Here, on the extractor's screen only: the hatch lid (and its
-- gasket and handle), the two grate halves, the capsule carousel with 3 open capsules, the
-- well's inner shutter, the mist under the lid, and the strip display's text. While the scene
-- runs, the static copies of the moving parts are hidden locally (attribute "SceneHidden").
--
-- THE TRANSFER (an element let go over the grate; times from that moment, roblox-animation
-- skill: one timeline table with named markers on the scene's clock; sounds and effects fire
-- from the markers, on the local frame):
--   0.00  the element lies on the grate (the hand has let go)
--   0.15  GrateOpen     the halves slide apart (0.25 s)                  → "GrateSlide"
--   0.30  Drop          the element falls through the funnel into the open capsule in the
--                       FRONT socket, right behind the window (gravity, a slow spin, it rights
--                       itself and settles to capsule size)
--   0.62  Landed        a small milky splash disc stays in the capsule, a squash, a puff
--                                                                         → "CapsuleDrop"
--   0.75  CapClose      the cap swings shut (0.25 s)          → "CapsuleSeal", "CapsuleHiss"
--   1.00  Frost         a frost ring at the cap seam; the grade LED blinks amber until the
--                       server's answer, then lights in its colour       → "SealFrost"
--   1.20  Turn          the carousel turns 120° (0.7 s): the sealed capsule moves back into
--                       the cold well, an empty one comes under the funnel → "CarouselTurn"
--   1.55  GrateClose    (0.25 s)                                          → "GrateSlide"
--   1.90  LidClose      the lid shuts (0.3 s, Quad In, a small rebound); the mist stops
--                                                                         → "HatchClose"
--   2.20  Count         the strip display shows "n/slots"                 → "UiConfirm"
-- The element is never hidden: in the hand, on the grate, falling inside, in its capsule,
-- in the well. At the outro the inner shutter rises over the well IN SHOT.
-- A husk crumbles into dry flakes inside its capsule (they stay); the capsule is inert.
--
--   PassBox.new(kit?, anchor, parent) → Box
--   PassBox.wantLid(box, open)            the lid opens / closes by itself (0.35 s / 0.3 s)
--   PassBox.transfer(box, model, kind, scale) → slot   starts the timeline above
--   PassBox.answer(box, slot, grade?, inert)           the server's answer for that capsule
--   PassBox.busy(box)                      a transfer is still playing
--   PassBox.closeWell(box)                 the outro: the inner shutter closes (0.4 s)
--   PassBox.setDisplay(box, text)          PassBox.step(box, dt, now) → events
--   PassBox.destroy(box)                   (the static parts show again)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BenchLayout = require(ReplicatedStorage.Shared.Contraband.BenchLayout)
local CoreModel = require(script.Parent.CoreModel)
local Parts = require(script.Parent.Parts)

local PassBox = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local ENAMEL = rgb(214, 212, 202)
local STEEL = rgb(170, 174, 176)
local VAPOUR = rgb(236, 244, 248)
local MILK = rgb(226, 228, 214)
local HUSK_FLAKE = rgb(160, 150, 132)
local LED_WAIT = rgb(255, 176, 70)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- built in, no upload
local GRAVITY = 30
local CAPSULE_SCALE = 0.55 -- the element's size inside a capsule (as CoreModel.capsule)
local STANDBY = "STANDBY"

local LID_OPEN_TIME = 0.35
local LID_CLOSE_TIME = 0.3

-- The transfer timeline (seconds from the release over the grate).
local TIMELINE: { { t: number, name: string } } = {
	{ t = 0.15, name = "GrateOpen" },
	{ t = 0.3, name = "Drop" },
	{ t = 0.62, name = "Landed" },
	{ t = 0.75, name = "CapClose" },
	{ t = 1.0, name = "Frost" },
	{ t = 1.2, name = "Turn" },
	{ t = 1.55, name = "GrateClose" },
	{ t = 1.9, name = "LidClose" },
	{ t = 2.2, name = "Count" },
}
local TRANSFER_END = 2.3

type Capsule = {
	model: Model,
	socket: number, -- its socket's angle at carousel rotation 0
	cap: number, -- 1 = open .. 0 = shut
	used: boolean,
	answer: { grade: string?, inert: boolean }?,
	waiting: boolean, -- sealed, no server answer yet (the LED blinks amber)
}

type Transfer = {
	start: number,
	next: number, -- the next TIMELINE entry
	model: Model,
	kind: string,
	capsule: Capsule,
	slot: number,
	from: CFrame, -- the element on the grate
	scale: number,
	position: Vector3,
	velocity: Vector3,
	landed: boolean,
	splash: BasePart?,
}

export type Box = {
	anchor: CFrame,
	folder: Folder,
	hidden: { BasePart }, -- the static copies hidden while the scene runs
	lid: { BasePart },
	lidLocal: { CFrame }, -- each lid part at closed, in hinge space
	lidOpen: number, -- 0..1 shown
	lidWant: boolean,
	lidFrom: number,
	lidStart: number,
	lidRebound: number?, -- clock of the last close (small rebound)
	grate: { { part: BasePart, side: number, z: number } },
	grateOpen: number,
	carousel: BasePart,
	carouselAngle: number, -- radians, shown
	turnFrom: number,
	turnTo: number,
	turnStart: number?,
	capsules: { Capsule },
	shutter: BasePart,
	shutterOpen: number,
	shutterGoal: number,
	mistSource: BasePart,
	mist: ParticleEmitter,
	puffSource: BasePart,
	puff: ParticleEmitter,
	bayLight: PointLight, -- lights the capsule bay behind the window during a transfer
	funnelLight: PointLight, -- lights the funnel from inside while the element goes down it
	display: TextLabel?,
	transfer: Transfer?,
	sealed: number,
	slots: number,
	events: { string },
	random: Random,
	flakes: { { part: BasePart, position: Vector3, velocity: Vector3, floorY: number } },
}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeOut(x: number): number
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

local function easeIn(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x
end

-- The pass-box mist: heavy cold vapour that rolls over the hatch rim and down the side
-- (roblox-vfx: built-in smoke texture, fades in and out, lit by the room, never a pop).
local function mistEmitter(parent: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "HatchMist"
	emitter.Texture = SMOKE_TEXTURE
	emitter.Rate = 14
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(VAPOUR)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.9, 0.1),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.7),
		NumberSequenceKeypoint.new(0.6, 0.9),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1.2, 1.8)
	emitter.Speed = NumberRange.new(0.2, 0.4)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Drag = 1.5
	emitter.Acceleration = Vector3.new(0, -1.2, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-20, 20)
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.ZOffset = 0.1
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = parent
	return emitter
end

-- A small burst emitter (capsule splash puff, frost ring): Disc on the rim, Emit only.
local function puffEmitter(parent: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "CapsulePuff"
	emitter.Texture = SMOKE_TEXTURE
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(VAPOUR)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 0.3, 0.05),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.6, 0.9)
	emitter.Speed = NumberRange.new(0.15, 0.4)
	emitter.Drag = 4
	emitter.Acceleration = Vector3.new(0, -0.5, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.Shape = Enum.ParticleEmitterShape.Disc
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.ShapePartial = 0.85
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = parent
	return emitter
end

local function hideStatic(kit: Instance?): { BasePart }
	local hidden: { BasePart } = {}
	if kit == nil then
		return hidden
	end
	for _, descendant in kit:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("SceneHidden") == true then
			descendant.LocalTransparencyModifier = 1
			table.insert(hidden, descendant)
		end
	end
	return hidden
end

-- The lid's hinge frame (world) at `open` 0..1 (it turns about Z, up and over toward +X).
local function hingeAt(box: Box, open: number): CFrame
	local angle = BenchLayout.LID_OPEN * open
	return box.anchor * CFrame.new(BenchLayout.LID_HINGE) * CFrame.Angles(0, 0, -angle)
end

function PassBox.new(kit: Instance?, anchor: CFrame, parent: Instance, slots: number): Box
	local folder = Instance.new("Folder")
	folder.Name = "PassBox"
	local pb = BenchLayout.PASS_BOX
	local hinge = BenchLayout.LID_HINGE
	local function local_(at: Vector3): CFrame
		return anchor * CFrame.new(at)
	end

	-- The lid (same as the static one), in hinge space.
	local lid: { BasePart } = {}
	local lidLocal: { CFrame } = {}
	local function lidPart(
		name: string,
		size: Vector3,
		at: Vector3,
		color: Color3,
		material: Enum.Material
	)
		local part = Parts.part({
			Name = name,
			Size = size,
			Color = color,
			Material = material,
			Parent = folder,
		})
		table.insert(lid, part)
		table.insert(lidLocal, CFrame.new(at - hinge))
	end
	lidPart(
		"Lid",
		Vector3.new(0.7, 0.08, 0.7),
		Vector3.new(hinge.X - 0.35, 0.21, hinge.Z),
		ENAMEL,
		Enum.Material.SmoothPlastic
	)
	-- the gasket: a black rubber RING round the underside's edge (a full black plate made the
	-- open lid read as a thin wire frame round a hole); the enamel shows inside it
	local lidX, lidZ = hinge.X - 0.35, hinge.Z
	for _, ring in
		{
			{ Vector3.new(0.66, 0.02, 0.05), Vector3.new(0, 0, -0.305) },
			{ Vector3.new(0.66, 0.02, 0.05), Vector3.new(0, 0, 0.305) },
			{ Vector3.new(0.05, 0.02, 0.56), Vector3.new(-0.305, 0, 0) },
			{ Vector3.new(0.05, 0.02, 0.56), Vector3.new(0.305, 0, 0) },
		}
	do
		lidPart(
			"LidGasket",
			ring[1],
			Vector3.new(lidX, 0.16, lidZ) + ring[2],
			rgb(24, 24, 24),
			Enum.Material.Rubber
		)
	end
	-- the underside's enamel panel, a shade darker than the top (it is in the lid's shadow)
	lidPart(
		"LidUnder",
		Vector3.new(0.56, 0.012, 0.56),
		Vector3.new(lidX, 0.164, lidZ),
		rgb(184, 182, 172),
		Enum.Material.SmoothPlastic
	)
	lidPart(
		"LidHandle",
		Vector3.new(0.06, 0.04, 0.3),
		Vector3.new(hinge.X - 0.66, 0.27, hinge.Z),
		rgb(60, 62, 64),
		Enum.Material.Metal
	)

	-- The grate: 10 bars, two halves (-Z half slides -Z, +Z half slides +Z).
	local grate = {}
	local half = pb.opening / 2
	for k = 1, 10 do
		local z = pb.centre.Z - half + (k - 0.5) * pb.opening / 10
		local bar = Parts.part({
			Name = "GrateBar",
			Size = Vector3.new(pb.opening, 0.03, 0.035),
			Color = STEEL,
			Material = Enum.Material.Metal,
			Reflectance = 0.15,
			CFrame = local_(Vector3.new(pb.centre.X, BenchLayout.GRATE_Y, z)),
			Parent = folder,
		})
		table.insert(grate, { part = bar, side = if k <= 5 then -1 else 1, z = z })
	end

	-- The carousel and its 3 open capsules (front socket = under the funnel).
	local car = BenchLayout.CAROUSEL
	local carousel = Parts.disc(car.radius * 2 + 0.3, car.height, {
		Name = "Carousel",
		Color = rgb(150, 154, 158),
		Material = Enum.Material.Metal,
		Reflectance = 0.1,
		Parent = folder,
	})
	Parts.disc(0.08, car.centre.Y - pb.floor - pb.wall - car.height / 2, {
		Name = "Spindle",
		Color = rgb(60, 62, 64),
		Material = Enum.Material.Metal,
		CFrame = local_(
			Vector3.new(
				car.centre.X,
				(car.centre.Y - car.height / 2 + pb.floor + pb.wall) / 2,
				car.centre.Z
			)
		) * Parts.UPRIGHT,
		Parent = folder,
	})
	local capsules: { Capsule } = {}
	for k = 0, 2 do
		local angle = k * math.pi * 2 / 3
		local model = CoreModel.capsule(nil, local_(BenchLayout.socket(angle)), true)
		model.Parent = folder
		table.insert(capsules, {
			model = model,
			socket = angle,
			cap = if k == 0 then 1 else 0, -- (only the one under the funnel waits open)
			used = false,
			answer = nil,
			waiting = false,
		})
	end

	-- The well's inner shutter (open: lowered into the box's base while the scene runs).
	local win = BenchLayout.WINDOW
	local shutter = Parts.part({
		Name = "Shutter",
		Size = Vector3.new(win.size.X + 0.06, win.size.Y + 0.06, 0.02),
		Color = rgb(150, 154, 156),
		Material = Enum.Material.DiamondPlate,
		Parent = folder,
	})

	-- Emitters on small invisible parts (Box / Disc shapes need a part parent).
	local mistSource = Parts.part({
		Name = "MistSource",
		Size = Vector3.new(0.55, 0.05, 0.55),
		Transparency = 1,
		CFrame = local_(Vector3.new(pb.centre.X, pb.deckTop + 0.03, pb.centre.Z)),
		Parent = folder,
	})
	local puffSource = Parts.part({
		Name = "PuffSource",
		Size = Vector3.new(0.35, 0.05, 0.35),
		Transparency = 1,
		CFrame = local_(BenchLayout.socket(0) + Vector3.new(0, 0.55, 0)),
		Parent = folder,
	})

	-- Two small cold lights, on only during a transfer (roblox-vfx: the action lit, the box
	-- dark otherwise): one in the capsule bay behind the window, one inside the funnel's
	-- mouth, so the element is seen going down instead of vanishing into a black hole.
	local function coldLight(name: string, at: Vector3, range: number): PointLight
		local host = Parts.part({
			Name = name,
			Size = Vector3.new(0.1, 0.1, 0.1),
			Transparency = 1,
			CFrame = local_(at),
			Parent = folder,
		})
		local light = Instance.new("PointLight")
		light.Color = rgb(215, 240, 245)
		light.Brightness = 0
		light.Range = range
		light.Shadows = false
		light.Parent = host
		return light
	end
	local bayLight = coldLight("BayLight", BenchLayout.socket(0) + Vector3.new(0, 0.45, -0.18), 1.8)
	local funnelLight =
		coldLight("FunnelLight", Vector3.new(pb.centre.X, -0.05, pb.centre.Z - 0.1), 1.2)

	-- The strip display's text (the static one; we only change it on our screen).
	local display: TextLabel? = nil
	local displayPart = if kit then kit:FindFirstChild("PassDisplay", true) else nil
	if displayPart then
		local found = displayPart:FindFirstChild("Text", true)
		if found and found:IsA("TextLabel") then
			display = found
		end
	end

	local box: Box = {
		anchor = anchor,
		folder = folder,
		hidden = hideStatic(kit),
		lid = lid,
		lidLocal = lidLocal,
		lidOpen = 0,
		lidWant = false,
		lidFrom = 0,
		lidStart = 0,
		lidRebound = nil,
		grate = grate,
		grateOpen = 0,
		carousel = carousel,
		carouselAngle = 0,
		turnFrom = 0,
		turnTo = 0,
		turnStart = nil,
		capsules = capsules,
		shutter = shutter,
		shutterOpen = 0,
		shutterGoal = 1, -- (it rises at the start of the scene)
		mistSource = mistSource,
		mist = mistEmitter(mistSource),
		puffSource = puffSource,
		puff = puffEmitter(puffSource),
		bayLight = bayLight,
		funnelLight = funnelLight,
		display = display,
		transfer = nil,
		sealed = 0,
		slots = slots,
		events = {},
		random = Random.new(),
		flakes = {},
	}
	folder.Parent = parent
	PassBox.setDisplay(box, `0/{slots}`)
	PassBox.step(box, 0, os.clock())
	return box
end

function PassBox.setDisplay(box: Box, text: string)
	local label = box.display
	if label and label.Text ~= text then
		label.Text = text
	end
end

-- The lid opens (true) or closes (false) by itself; the mist runs while it is open.
function PassBox.wantLid(box: Box, open: boolean)
	if box.lidWant == open then
		return
	end
	box.lidWant = open
	box.lidFrom = box.lidOpen
	box.lidStart = os.clock()
	if open then
		table.insert(box.events, "HatchOpen")
		box.mist.Enabled = true
	else
		box.mist.Enabled = false -- (the live particles finish: no Clear, no pop)
	end
end

function PassBox.isLidOpen(box: Box): boolean
	return box.lidOpen > 0.8
end

function PassBox.busy(box: Box): boolean
	return box.transfer ~= nil
end

-- The capsule in the front socket (under the funnel) now.
local function frontCapsule(box: Box): Capsule?
	for _, capsule in box.capsules do
		local angle = (capsule.socket + box.carouselAngle) % (math.pi * 2)
		if not capsule.used and (angle < 0.2 or angle > math.pi * 2 - 0.2) then
			return capsule
		end
	end
	return nil
end

-- The element `model` (lying on the grate, world) goes in: starts the timeline. Returns the
-- capsule's slot (1..), or nil if no capsule is ready (a transfer already playing).
function PassBox.transfer(box: Box, model: Model, kind: string, scale: number): number?
	if box.transfer then
		return nil
	end
	local capsule = frontCapsule(box)
	if capsule == nil then
		return nil
	end
	capsule.used = true
	box.sealed += 1
	model.Parent = box.folder
	box.transfer = {
		start = os.clock(),
		next = 1,
		model = model,
		kind = kind,
		capsule = capsule,
		slot = box.sealed,
		from = model:GetPivot(),
		scale = scale,
		position = model:GetPivot().Position,
		velocity = Vector3.zero,
		landed = false,
		splash = nil,
	}
	return box.sealed
end

-- The server's answer for capsule `slot` (its LED lights within a frame once it is shut).
function PassBox.answer(box: Box, slot: number, grade: string?, inert: boolean)
	local index = 0
	for _, capsule in box.capsules do
		if capsule.used then
			index += 1
			-- (capsules are used in slot order: the n-th used one is slot n)
			if index == slot then
				capsule.answer = { grade = grade, inert = inert }
			end
		end
	end
end

function PassBox.closeWell(box: Box)
	box.shutterGoal = 0
	PassBox.wantLid(box, false)
end

-- The cap of a capsule at `open` 0..1: it hinges up off the back of the rim (it never swings
-- into the funnel or the walls).
local function setCap(capsule: Capsule, open: number)
	local cap = capsule.model:FindFirstChild("CapTop")
	if cap == nil or not cap:IsA("BasePart") then
		return
	end
	local pivot = capsule.model.WorldPivot
	local o = math.clamp(open, 0, 1)
	-- hinge on the +Z rim of the top (back of the capsule, away from the window); open, the
	-- cap stands up behind the mouth, under the funnel's exit
	local hinge = pivot * CFrame.new(0, 0.57, 0.22)
	cap.CFrame = hinge
		* CFrame.Angles(math.rad(88) * o, 0, 0)
		* CFrame.new(0, -0.06, -0.22)
		* Parts.UPRIGHT
end

local function crumble(box: Box, at: Vector3, floorY: number)
	for _ = 1, 8 do
		local size =
			Vector3.new(box.random:NextNumber(0.03, 0.06), 0.03, box.random:NextNumber(0.04, 0.07))
		local part = Instance.new("WedgePart")
		part.Name = "Flake"
		part.Size = size
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Sand
		part.Color = HUSK_FLAKE
		local start = at
			+ Vector3.new(box.random:NextNumber(-0.06, 0.06), 0, box.random:NextNumber(-0.06, 0.06))
		part.CFrame = CFrame.new(start)
		part.Parent = box.folder
		table.insert(box.flakes, {
			part = part :: BasePart,
			position = start,
			velocity = Vector3.new(
				box.random:NextNumber(-0.15, 0.15),
				0,
				box.random:NextNumber(-0.15, 0.15)
			),
			floorY = floorY + box.random:NextNumber(0, 0.04),
		})
	end
end

local function fire(box: Box, name: string, item: Transfer, now: number)
	local capsule = item.capsule
	if name == "GrateOpen" or name == "GrateClose" then
		table.insert(box.events, name)
	elseif name == "Landed" then
		table.insert(box.events, "CapsuleDrop")
		box.puffSource.CFrame = capsule.model.WorldPivot * CFrame.new(0, 0.5, 0)
		box.puff:Emit(3)
	elseif name == "CapClose" then
		table.insert(box.events, "CapClose")
	elseif name == "Frost" then
		capsule.waiting = capsule.answer == nil
		table.insert(box.events, "Frost")
		box.puffSource.CFrame = capsule.model.WorldPivot * CFrame.new(0, 0.5, 0)
		if item.kind ~= "Husk" then
			box.puff:Emit(10)
		end
		local tube = capsule.model:FindFirstChild("Tube")
		if tube and tube:IsA("BasePart") then
			tube.Color = rgb(236, 244, 248) -- frosted (the element still shows through)
			tube.Transparency = 0.5
		end
	elseif name == "Turn" then
		box.turnFrom = box.carouselAngle
		box.turnTo = box.carouselAngle + math.pi * 2 / 3
		box.turnStart = now
		table.insert(box.events, "CarouselTurn")
	elseif name == "LidClose" then
		PassBox.wantLid(box, false)
		table.insert(box.events, "HatchClose")
	elseif name == "Count" then
		PassBox.setDisplay(box, `{box.sealed}/{box.slots}`)
		table.insert(box.events, "Count")
	end
end

-- Events since the last call (sound names / beats), on the frame they happened.
function PassBox.takeEvents(box: Box): { string }
	local list = box.events
	box.events = {}
	return list
end

function PassBox.step(box: Box, dt: number, now: number)
	local anchor = box.anchor
	-- the lid: Quad Out up, Quad In down with a small rebound
	local want = if box.lidWant then 1 else 0
	local duration = if box.lidWant then LID_OPEN_TIME else LID_CLOSE_TIME
	local t = (now - box.lidStart) / duration
	local open: number
	if box.lidWant then
		open = box.lidFrom + (1 - box.lidFrom) * easeOut(t)
	else
		open = box.lidFrom * (1 - easeIn(t))
		if t >= 1 then
			-- (a 0.02-stud rebound in the gasket: a few degrees, gone in 0.12 s)
			local after = now - (box.lidStart + duration)
			open = if after < 0.12 then 0.025 * math.sin(after / 0.12 * math.pi) else 0
		end
	end
	if box.lidStart == 0 then
		open = want
	end
	box.lidOpen = open
	local hinge = hingeAt(box, open)
	local cframes = table.create(#box.lid)
	for k, part in box.lid do
		cframes[k] = hinge * box.lidLocal[k]
		local _ = part
	end
	workspace:BulkMoveTo(box.lid, cframes, Enum.BulkMoveMode.FireCFrameChanged)

	-- the transfer timeline
	local item = box.transfer
	local grateGoal = 0
	-- (the two cold lights: up as the grate opens, the funnel one down once the element has
	-- landed, the bay one once the lid is shut)
	local bayGoal, funnelGoal = 0, 0
	if item then
		local lit = now - item.start
		bayGoal = if lit >= 0.1 and lit < 2.0 then 1.4 else 0
		funnelGoal = if lit >= 0.1 and lit < 0.8 then 1.1 else 0
	end
	local glide = 1 - math.exp(-dt * 12)
	box.bayLight.Brightness += (bayGoal - box.bayLight.Brightness) * glide
	box.funnelLight.Brightness += (funnelGoal - box.funnelLight.Brightness) * glide
	if item then
		local elapsed = now - item.start
		while TIMELINE[item.next] and elapsed >= TIMELINE[item.next].t do
			fire(box, TIMELINE[item.next].name, item, now)
			item.next += 1
		end
		grateGoal = if elapsed >= 0.15 and elapsed < 1.55 then 1 else 0
		local capsule = item.capsule
		local goal = capsule.model.WorldPivot * CFrame.new(0, -0.03, 0)
		if elapsed < 0.3 then
			-- (lying on the grate)
			item.model:PivotTo(item.from)
		elseif not item.landed then
			-- falling: real gravity, a slow spin; it rights itself and settles to capsule size
			item.velocity += Vector3.new(0, -GRAVITY, 0) * dt
			local position = item.position + item.velocity * dt
			-- (steered into the funnel's exit, then the capsule mouth: it slides on the funnel)
			local fall = math.clamp(
				(item.from.Position.Y - position.Y) / (item.from.Position.Y - goal.Position.Y),
				0,
				1
			)
			local x = item.from.Position:Lerp(goal.Position, smooth(fall * 1.6))
			position = Vector3.new(x.X, position.Y, x.Z)
			if position.Y <= goal.Position.Y then
				position = goal.Position
				item.landed = true
				fire(box, "Landed", item, now)
				item.next = math.max(item.next, 4)
				-- a small milky splash that stays at the bottom of the capsule
				local splash = Parts.disc(0.2, 0.015, {
					Name = "Splash",
					Color = MILK,
					Reflectance = 0.25,
					CFrame = capsule.model.WorldPivot * CFrame.new(0, -0.43, 0) * Parts.UPRIGHT,
					Parent = capsule.model,
				})
				item.splash = splash
				if item.kind == "Husk" then
					-- it crumbles to dry flakes in the capsule (they stay)
					crumble(
						box,
						position + Vector3.new(0, 0.1, 0),
						(capsule.model.WorldPivot * Vector3.new(0, -0.42, 0)).Y
					)
					item.model:Destroy()
				else
					item.model.Parent = capsule.model
				end
			end
			item.position = position
			if not item.landed then
				local upright = goal.Rotation * CFrame.Angles(0, math.rad(40) * fall, 0)
				local rotation = item.from.Rotation:Lerp(upright, smooth(fall * 1.3))
				local s = 1 + (CAPSULE_SCALE / item.scale - 1) * smooth(fall)
				item.model:ScaleTo(s)
				item.model:PivotTo(CFrame.new(position) * rotation)
			end
		end
		if item.landed and item.model.Parent == capsule.model then
			-- the landing squash (y 0.85 → 1 over 0.15 s) and then it rides the carousel
			local since = elapsed - 0.62
			local squash = if since < 0.15 then 0.85 + 0.15 * smooth(since / 0.15) else 1
			item.model:PivotTo(
				capsule.model.WorldPivot * CFrame.new(0, -0.03 - (1 - squash) * 0.1, 0)
			)
		end
		-- the cap swings shut (spring-loaded: accelerating)
		if elapsed >= 0.75 then
			capsule.cap = 1 - easeIn((elapsed - 0.75) / 0.25)
		end
		if elapsed >= TRANSFER_END then
			box.transfer = nil
		end
	end

	-- the grate halves
	local grateTarget = grateGoal
	box.grateOpen += (grateTarget - box.grateOpen) * (1 - 2 ^ (-dt / 0.06))
	local grateCFrames = table.create(#box.grate)
	local parts = table.create(#box.grate)
	local pb = BenchLayout.PASS_BOX
	for k, bar in box.grate do
		parts[k] = bar.part
		local offset = bar.side * BenchLayout.GRATE_SLIDE * smooth(box.grateOpen)
		grateCFrames[k] = anchor * CFrame.new(pb.centre.X, BenchLayout.GRATE_Y, bar.z + offset)
	end
	workspace:BulkMoveTo(parts, grateCFrames, Enum.BulkMoveMode.FireCFrameChanged)

	-- the carousel (Sine In-Out, 0.7 s) and the capsules riding it
	local turnStart = box.turnStart
	if turnStart then
		local u = math.clamp((now - turnStart) / 0.7, 0, 1)
		local eased = -(math.cos(math.pi * u) - 1) / 2
		box.carouselAngle = box.turnFrom + (box.turnTo - box.turnFrom) * eased
		if u >= 1 then
			box.turnStart = nil
		end
	end
	local car = BenchLayout.CAROUSEL
	box.carousel.CFrame = anchor
		* CFrame.new(car.centre)
		* CFrame.Angles(0, -box.carouselAngle, 0)
		* Parts.UPRIGHT
	for _, capsule in box.capsules do
		-- (each capsule faces out of the carousel: its LED outward, its cap hinged on the inner
		-- rim, so an open cap stands toward the middle, clear of the walls)
		local angle = capsule.socket + box.carouselAngle
		local at = anchor * CFrame.new(BenchLayout.socket(angle)) * CFrame.Angles(0, -angle, 0)
		capsule.model:PivotTo(at)
		if not capsule.used then
			-- an empty capsule opens once it stops under the funnel (and only there)
			local wrapped = angle % (math.pi * 2)
			local under = box.turnStart == nil and (wrapped < 0.05 or wrapped > math.pi * 2 - 0.05)
			capsule.cap += ((if under then 1 else 0) - capsule.cap) * (1 - 2 ^ (-dt / 0.08))
		end
		setCap(capsule, capsule.cap)
		-- the grade LED: amber blink while waiting for the server, then its colour
		local answer = capsule.answer
		if capsule.cap <= 0.01 and capsule.used then
			if answer then
				if capsule.waiting or capsule.model:GetAttribute("Lit") ~= true then
					capsule.waiting = false
					capsule.model:SetAttribute("Lit", true)
					CoreModel.setGradeLight(capsule.model, answer.grade, answer.inert)
				end
			elseif capsule.waiting then
				local led = capsule.model:FindFirstChild("GradeLed")
				if led and led:IsA("BasePart") then
					local on = math.floor(now * 8) % 2 == 0
					led.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
					led.Color = if on then LED_WAIT else rgb(60, 52, 40)
				end
			end
		end
		if capsule.used and capsule.cap <= 0.01 then
			CoreModel.animate(capsule.model, now, true)
		end
	end

	-- the inner shutter: down in the box's base (open) during the scene; at the outro it rises
	-- over the well, in shot
	box.shutterOpen += (box.shutterGoal - box.shutterOpen) * (1 - 2 ^ (-dt / 0.1))
	local win = BenchLayout.WINDOW
	local lift = -(win.size.Y + 0.08) * smooth(box.shutterOpen)
	box.shutter.CFrame = anchor
		* CFrame.new(win.centre.X, win.centre.Y + lift, win.centre.Z + pb.wall + 0.06)

	-- husk flakes: real gravity, they land in the capsule and stay
	for _, flake in box.flakes do
		if flake.position.Y > flake.floorY then
			flake.velocity += Vector3.new(0, -GRAVITY, 0) * dt
			local position = flake.position + flake.velocity * dt
			if position.Y <= flake.floorY then
				position = Vector3.new(position.X, flake.floorY, position.Z)
			end
			flake.position = position
			flake.part.CFrame = CFrame.new(position)
		end
	end
end

function PassBox.destroy(box: Box)
	for _, part in box.hidden do
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
	PassBox.setDisplay(box, STANDBY)
	box.folder:Destroy()
end

return PassBox
