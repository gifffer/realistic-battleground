--!strict
-- TrainController: draws the city's freight train on YOUR screen, and the warning before it.
--
-- The server (Server/Systems/Train) only decides WHEN a train passes and who gets hit; it
-- publishes the pass as attributes of Workspace > City (see Shared/Util/TrainPath). This
-- controller:
--   • builds ONE local train (a locomotive + a boxcar + a tank car, blocky like the rest of
--     the city, about 140 parts) that only exists on this screen, so it costs the server
--     and the network nothing;
--   • every frame of a pass, places it from the shared clock (workspace:GetServerTimeNow()):
--     every player sees it at the same place, smoothly, the wheels turning. The parts that
--     are still (or already) inside a tunnel are hidden far away;
--   • the warning (TrainWarnAt, 5 s before the locomotive comes out): the signals of the
--     railway (parts tagged "TrainSignal") blink red and their green lamps (tag
--     "TrainSignalGo") go dark, the horn sounds (Shared/Sounds:
--     TrainHorn, silent while it has no id), and the camera starts to shake if you are
--     within SHAKE_RANGE studs of the track — stronger as the train gets closer;
--   • the rumble loop (TrainRumble) follows the train while it is out.
-- The train's parts never collide and can't be hit by rays: getting hit is decided by the
-- server alone (the box it computes matches this model: Config.Train LENGTH / HALF_WIDTH /
-- HEIGHT).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local TrainPath = require(ReplicatedStorage.Shared.Util.TrainPath)

local T = Config.Train

local TrainController = {}

local SIGNAL_TAG = "TrainSignal"
-- The green lamp under each red one (lit while no train is coming, off during a pass).
local SIGNAL_GO_TAG = "TrainSignalGo"
local GO_OFF = Color3.fromRGB(20, 40, 26)
-- A part whose centre is this far inside a tunnel is hidden (the tunnels are deeper).
local HIDE_IN_TUNNEL = 12
local HIDDEN_CFRAME = CFrame.new(0, -2000, 0)
local WHEEL_RADIUS = 0.85
local SIGNAL_ON = Color3.fromRGB(255, 46, 32)
local SIGNAL_OFF = Color3.fromRGB(70, 14, 12)
local BLINK_RATE = 2 -- blinks per second

------------------------------------------------------------------------------
-- The model
--
-- Built in the TRAIN'S OWN SPACE: X = to its right, Y = up (0 = rail top), Z = backwards
-- from the nose (the nose at Z = 0, the back of the last car at Z = LENGTH). Each frame the
-- whole train is one rigid piece placed with CFrame.lookAt(nose, nose + direction).
------------------------------------------------------------------------------

type TrainPart = {
	part: BasePart,
	offset: CFrame, -- in the train's space
	alongZ: number, -- how far behind the nose its centre is
	wheel: boolean, -- turns with the distance travelled
}

local trainParts: { TrainPart } = {}
local folder: Folder
local headlight: SpotLight? = nil

local ROT_Z = CFrame.Angles(0, math.rad(90), 0) -- a cylinder lying along the track
local ROT_UP = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder standing up

-- Optional details of a part (all can be left out).
type AddOptions = {
	rotation: CFrame?, -- turned in place (cylinders: ROT_Z / ROT_UP)
	shape: Enum.PartType?,
	transparency: number?,
	reflectance: number?,
	wheel: boolean?, -- turns as the train moves
	name: string?,
}
local NO_OPTIONS: AddOptions = {}

local function add(
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	extra: AddOptions?
): BasePart
	local options: AddOptions = extra or NO_OPTIONS
	local part = Instance.new("Part")
	part.Name = options.name or "TrainPart"
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = options.shape or Enum.PartType.Block
	part.Transparency = options.transparency or 0
	part.Reflectance = options.reflectance or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.CFrame = HIDDEN_CFRAME
	part.Parent = folder
	table.insert(trainParts, {
		part = part :: BasePart,
		offset = CFrame.new(position) * (options.rotation or CFrame.identity),
		alongZ = position.Z,
		wheel = options.wheel == true,
	})
	return part
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local METAL = Enum.Material.Metal
local DARK = rgb(34, 34, 36)
local STEEL = rgb(62, 62, 66)

-- A two-axle bogie (truck) centred at `z`: two side frames and four wheels.
local function bogie(z: number)
	for _, x in { -2.95, 2.95 } do
		add(Vector3.new(0.4, 0.9, 4.6), Vector3.new(x, 1.0, z), DARK, METAL)
	end
	for _, x in { -2.5, 2.5 } do
		for _, dz in { -1.4, 1.4 } do
			add(
				Vector3.new(0.4, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2),
				Vector3.new(x, WHEEL_RADIUS, z + dz),
				STEEL,
				METAL,
				{ shape = Enum.PartType.Cylinder, wheel = true, name = "Wheel" }
			)
		end
	end
end

-- Two buffers on the end of a car whose end face is at `z` (`outward` = -1 at the front).
local function buffers(z: number, outward: number)
	for _, x in { -2.6, 2.6 } do
		add(
			Vector3.new(0.6, 0.55, 0.55),
			Vector3.new(x, 1.95, z + outward * 0.3),
			STEEL,
			METAL,
			{ shape = Enum.PartType.Cylinder, rotation = ROT_Z }
		)
	end
end

-- The locomotive: Z 0 → 26. A faded red diesel with a cream stripe.
local function buildLocomotive()
	local body = rgb(132, 42, 34)
	local cream = rgb(214, 198, 160)
	local glass = rgb(36, 46, 54)
	-- frame and ends
	add(Vector3.new(7.4, 0.9, 25.2), Vector3.new(0, 1.95, 13), DARK, METAL)
	add(Vector3.new(7.8, 1.3, 0.6), Vector3.new(0, 1.9, 1.1), rgb(150, 120, 40), METAL)
	add(Vector3.new(7.8, 1.3, 0.6), Vector3.new(0, 1.9, 25.3), DARK, METAL)
	buffers(0.8, -1)
	buffers(25.6, 1)
	-- the plough (cowcatcher), leaning back
	add(
		Vector3.new(7.0, 1.3, 0.3),
		Vector3.new(0, 0.78, 0.95),
		rgb(150, 120, 40),
		METAL,
		{ rotation = CFrame.Angles(math.rad(-32), 0, 0) }
	)
	-- short hood (in front of the cab), with the headlights
	add(Vector3.new(6.4, 4.2, 4.6), Vector3.new(0, 4.5, 3.9), body, METAL)
	add(Vector3.new(6.5, 0.45, 4.7), Vector3.new(0, 3.3, 3.9), cream, METAL)
	local lamp = add(
		Vector3.new(1.1, 1.1, 0.2),
		Vector3.new(0, 6.0, 1.52),
		rgb(255, 242, 205),
		Enum.Material.Neon,
		{ name = "Headlight" }
	)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 55
	light.Range = 45
	light.Brightness = 4
	light.Color = rgb(255, 236, 200)
	light.Shadows = false
	light.Parent = lamp
	headlight = light
	for _, x in { -1.9, 1.9 } do
		add(
			Vector3.new(0.8, 0.8, 0.2),
			Vector3.new(x, 5.6, 1.52),
			rgb(255, 236, 190),
			Enum.Material.Neon
		)
		-- ditch lights, low on the buffer beam
		add(
			Vector3.new(0.5, 0.5, 0.2),
			Vector3.new(x * 1.55, 2.1, 0.72),
			rgb(255, 236, 190),
			Enum.Material.Neon
		)
	end
	-- the cab: big front windows, a number board, side windows, visors, the horn
	add(Vector3.new(7.6, 7.2, 6.0), Vector3.new(0, 6.0, 9.2), body, METAL)
	add(Vector3.new(7.7, 0.45, 6.1), Vector3.new(0, 3.3, 9.2), cream, METAL)
	for _, x in { -1.75, 1.75 } do
		add(
			Vector3.new(2.6, 1.8, 0.2),
			Vector3.new(x, 7.9, 6.15),
			glass,
			Enum.Material.Glass,
			{ transparency = 0.1, reflectance = 0.25 }
		)
		add(Vector3.new(2.8, 0.15, 0.6), Vector3.new(x, 8.95, 5.95), DARK, METAL)
	end
	for _, x in { -3.85, 3.85 } do
		add(
			Vector3.new(0.2, 1.8, 3.8),
			Vector3.new(x, 7.9, 9.4),
			glass,
			Enum.Material.Glass,
			{ transparency = 0.1, reflectance = 0.25 }
		)
	end
	local board = add(Vector3.new(3.2, 0.8, 0.2), Vector3.new(0, 9.1, 6.15), DARK, METAL)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local number = Instance.new("TextLabel")
	number.Size = UDim2.fromScale(1, 1)
	number.BackgroundTransparency = 1
	number.Text = "4417"
	number.TextScaled = true
	number.Font = Enum.Font.Oswald
	number.TextColor3 = rgb(240, 236, 220)
	number.Parent = gui
	gui.Parent = board
	add(Vector3.new(8.0, 0.5, 6.6), Vector3.new(0, 9.85, 9.2), DARK, METAL)
	add(
		Vector3.new(1.2, 0.4, 0.4),
		Vector3.new(1.8, 10.3, 8.0),
		STEEL,
		METAL,
		{ shape = Enum.PartType.Cylinder, rotation = ROT_Z }
	)
	-- long hood (behind the cab): grilles, exhaust stacks, radiator fans, handrails
	add(Vector3.new(6.4, 5.0, 13.6), Vector3.new(0, 4.9, 19.2), body, METAL)
	add(Vector3.new(6.5, 0.45, 13.7), Vector3.new(0, 3.3, 19.2), cream, METAL)
	for _, x in { -3.26, 3.26 } do
		for _, z in { 14.4, 17.2, 20.0, 22.8 } do
			add(Vector3.new(0.12, 2.2, 2.4), Vector3.new(x, 5.4, z), rgb(52, 26, 22), METAL)
		end
		add(
			Vector3.new(0.15, 0.15, 13.2),
			Vector3.new(x * 1.135, 4.3, 18.9),
			rgb(200, 170, 60),
			METAL
		)
		for _, z in { 13.0, 19.0, 25.0 } do
			add(
				Vector3.new(0.15, 1.8, 0.15),
				Vector3.new(x * 1.135, 3.4, z),
				rgb(200, 170, 60),
				METAL
			)
		end
	end
	for _, z in { 14.6, 16.8 } do
		add(
			Vector3.new(1.2, 0.9, 0.9),
			Vector3.new(0, 7.95, z),
			DARK,
			METAL,
			{ shape = Enum.PartType.Cylinder, rotation = ROT_UP }
		)
	end
	for _, z in { 20.8, 23.8 } do
		add(
			Vector3.new(0.25, 2.8, 2.8),
			Vector3.new(0, 7.5, z),
			STEEL,
			METAL,
			{ shape = Enum.PartType.Cylinder, rotation = ROT_UP }
		)
	end
	-- fuel tank between the bogies
	add(Vector3.new(5.2, 1.1, 7.0), Vector3.new(0, 0.95, 13), DARK, METAL)
	bogie(5.0)
	bogie(21.0)
end

-- A rusty boxcar: Z z0 → z0 + 24, with a sliding door, ribs and some graffiti.
local function buildBoxcar(z0: number)
	local rust = rgb(112, 58, 40)
	local c = z0 + 12
	add(Vector3.new(7.2, 0.7, 23.0), Vector3.new(0, 1.85, c), DARK, METAL)
	add(Vector3.new(7.6, 6.8, 22.8), Vector3.new(0, 5.6, c), rust, METAL)
	add(Vector3.new(7.9, 0.35, 23.2), Vector3.new(0, 9.18, c), rgb(84, 46, 34), METAL)
	add(Vector3.new(1.4, 0.15, 22.0), Vector3.new(0, 9.42, c), DARK, METAL)
	for _, x in { -3.86, 3.86 } do
		-- the sliding door and its rails
		add(Vector3.new(0.12, 6.0, 5.6), Vector3.new(x, 5.4, c), rgb(90, 46, 32), METAL)
		add(Vector3.new(0.15, 0.25, 12.0), Vector3.new(x * 1.02, 8.6, c), DARK, METAL)
		add(Vector3.new(0.15, 0.25, 12.0), Vector3.new(x * 1.02, 2.4, c), DARK, METAL)
		-- vertical ribs (not over the door)
		for _, dz in { -10, -7, -4, 4, 7, 10 } do
			add(
				Vector3.new(0.18, 6.6, 0.3),
				Vector3.new(x * 1.005, 5.6, c + dz),
				rgb(96, 50, 36),
				METAL
			)
		end
	end
	-- graffiti: blocky tags in loud colours (one side has more)
	add(Vector3.new(0.06, 1.6, 4.2), Vector3.new(3.83, 4.2, c - 6.5), rgb(210, 70, 140))
	add(Vector3.new(0.06, 0.7, 3.4), Vector3.new(3.83, 5.6, c - 6.0), rgb(240, 236, 220))
	add(Vector3.new(0.06, 1.2, 3.0), Vector3.new(3.83, 4.8, c + 6.6), rgb(60, 170, 170))
	add(Vector3.new(0.06, 1.4, 4.4), Vector3.new(-3.83, 4.4, c + 6.0), rgb(230, 190, 50))
	add(Vector3.new(0.06, 0.6, 3.0), Vector3.new(-3.83, 3.4, c - 6.2), rgb(120, 200, 90))
	buffers(z0 + 0.2, -1)
	buffers(z0 + 23.8, 1)
	bogie(z0 + 4.0)
	bogie(z0 + 20.0)
end

-- A black tank car: Z z0 → z0 + 22.
local function buildTankCar(z0: number)
	local tank = rgb(46, 48, 52)
	local c = z0 + 11
	add(Vector3.new(6.8, 0.6, 21.0), Vector3.new(0, 1.8, c), DARK, METAL)
	add(
		Vector3.new(19.5, 6.0, 6.0),
		Vector3.new(0, 5.4, c),
		tank,
		METAL,
		{ shape = Enum.PartType.Cylinder, rotation = ROT_Z }
	)
	for _, dz in { -9.9, 9.9 } do
		add(
			Vector3.new(0.6, 5.4, 5.4),
			Vector3.new(0, 5.4, c + dz),
			rgb(38, 40, 44),
			METAL,
			{ shape = Enum.PartType.Cylinder, rotation = ROT_Z }
		)
	end
	for _, dz in { -6, 0, 6 } do
		add(
			Vector3.new(0.5, 6.15, 6.15),
			Vector3.new(0, 5.4, c + dz),
			rgb(30, 30, 33),
			METAL,
			{ shape = Enum.PartType.Cylinder, rotation = ROT_Z }
		)
	end
	add(
		Vector3.new(1.0, 2.0, 2.0),
		Vector3.new(0, 8.6, c + 3),
		rgb(30, 30, 33),
		METAL,
		{ shape = Enum.PartType.Cylinder, rotation = ROT_UP }
	)
	for _, x in { -1, 1 } do
		add(Vector3.new(1.0, 0.15, 19.0), Vector3.new(x * 3.2, 2.45, c), DARK, METAL)
		add(Vector3.new(0.12, 0.12, 19.0), Vector3.new(x * 3.75, 3.6, c), rgb(200, 170, 60), METAL)
		-- hazard placard
		add(Vector3.new(0.06, 1.0, 1.0), Vector3.new(x * 3.03, 5.4, c - 7.5), rgb(230, 120, 30))
	end
	add(Vector3.new(0.06, 1.4, 3.6), Vector3.new(3.03, 5.0, c + 2.5), rgb(80, 150, 200))
	buffers(z0 + 0.2, -1)
	buffers(z0 + 21.8, 1)
	bogie(z0 + 4.0)
	bogie(z0 + 18.0)
end

local function buildTrain()
	folder = Instance.new("Folder")
	folder.Name = "LocalTrain"
	buildLocomotive()
	buildBoxcar(26)
	buildTankCar(50) -- (26 + 24: the back of the train at Z 72 = Config.Train.LENGTH)
	folder.Parent = workspace
end

------------------------------------------------------------------------------
-- Sounds (3D, from an invisible point that follows the train, or waits at its portal)
------------------------------------------------------------------------------

local soundAnchor: Part
local horn: Sound? = nil
local rumble: Sound? = nil

local function makeSound(name: string, looped: boolean, maxDistance: number): Sound?
	local info = Sounds[name]
	if info == nil or #info.ids == 0 then
		return nil -- no id yet: silent
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = `rbxassetid://{info.ids[1]}`
	sound.Volume = info.volume
	sound.PlaybackSpeed = info.pitch
	sound.Looped = looped
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = maxDistance
	sound.Parent = soundAnchor
	return sound
end

local function buildSounds()
	soundAnchor = Instance.new("Part")
	soundAnchor.Name = "TrainSound"
	soundAnchor.Size = Vector3.one
	soundAnchor.Transparency = 1
	soundAnchor.Anchored = true
	soundAnchor.CanCollide = false
	soundAnchor.CanQuery = false
	soundAnchor.CanTouch = false
	soundAnchor.CFrame = HIDDEN_CFRAME
	soundAnchor.Parent = folder
	horn = makeSound("TrainHorn", false, 320)
	rumble = makeSound("TrainRumble", true, 180)
end

------------------------------------------------------------------------------
-- Signals (parts tagged TrainSignal in the city): blink red during a warning / pass
------------------------------------------------------------------------------

type SignalInfo = { color: Color3, material: Enum.Material }
local signals: { [BasePart]: SignalInfo } = {}
-- the green lamps (tag TrainSignalGo): their colour at rest, as built
local goLamps: { [BasePart]: SignalInfo } = {}
local signalsLit = false

local function addSignal(instance: Instance)
	if instance:IsA("BasePart") and signals[instance] == nil then
		signals[instance] = { color = instance.Color, material = instance.Material }
	end
end

local function addGoLamp(instance: Instance)
	if instance:IsA("BasePart") and goLamps[instance] == nil then
		goLamps[instance] = { color = instance.Color, material = instance.Material }
	end
end

local function setSignals(active: boolean, on: boolean)
	for part, info in signals do
		if part.Parent == nil then
			signals[part] = nil
		elseif active then
			part.Color = if on then SIGNAL_ON else SIGNAL_OFF
			part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		else
			part.Color = info.color
			part.Material = info.material
		end
		local light = part:FindFirstChildWhichIsA("Light")
		if light then
			light.Enabled = if active then on else false
		end
	end
	-- green = "no train": off (dark glass) during the warning and the pass, lit at rest
	for part, info in goLamps do
		if part.Parent == nil then
			goLamps[part] = nil
		elseif active then
			part.Color = GO_OFF
			part.Material = Enum.Material.SmoothPlastic
		else
			part.Color = info.color
			part.Material = info.material
		end
	end
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

local city: Instance
local track: TrainPath.Track? = nil
local hidden = true
local hornedWarn = -1 -- the TrainWarnAt we already sounded the horn for
local hornedOut = -1 -- ... and the TrainPassStart
local shakeStrength = 0
local random = Random.new()

local partsBuffer: { BasePart } = {}
local cframesBuffer: { CFrame } = {}

local function hideTrain()
	if hidden then
		return
	end
	hidden = true
	table.clear(partsBuffer)
	table.clear(cframesBuffer)
	for _, info in trainParts do
		table.insert(partsBuffer, info.part)
		table.insert(cframesBuffer, HIDDEN_CFRAME)
	end
	workspace:BulkMoveTo(partsBuffer, cframesBuffer, Enum.BulkMoveMode.FireCFrameChanged)
	soundAnchor.CFrame = HIDDEN_CFRAME
	local sound = rumble
	if sound and sound.Playing then
		sound:Stop()
	end
end

local function placeTrain(frame: TrainPath.Frame, nose: number)
	hidden = false
	local nosePosition = frame.origin + frame.axis * nose
	local trainCFrame = CFrame.lookAt(nosePosition, nosePosition + frame.axis)
	local spin = CFrame.Angles(-nose / WHEEL_RADIUS, 0, 0)
	table.clear(partsBuffer)
	table.clear(cframesBuffer)
	for _, info in trainParts do
		local along = nose - info.alongZ
		local cframe: CFrame
		if along < -HIDE_IN_TUNNEL or along > frame.trackLength + HIDE_IN_TUNNEL then
			cframe = HIDDEN_CFRAME
		elseif info.wheel then
			cframe = trainCFrame * info.offset * spin
		else
			cframe = trainCFrame * info.offset
		end
		table.insert(partsBuffer, info.part)
		table.insert(cframesBuffer, cframe)
	end
	workspace:BulkMoveTo(partsBuffer, cframesBuffer, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Distance from the camera to the part of the track the train covers (or its portal).
local function distanceToTrain(frame: TrainPath.Frame, from: number, to: number): number
	local camera = workspace.CurrentCamera
	if camera == nil then
		return math.huge
	end
	local offset = camera.CFrame.Position - frame.origin
	local along = math.clamp(offset:Dot(frame.axis), from, to)
	return (camera.CFrame.Position - (frame.origin + frame.axis * along)).Magnitude
end

local function update()
	local currentTrack = track
	local pass = if currentTrack then TrainPath.readPass(city) else nil
	if currentTrack == nil or pass == nil then
		shakeStrength = 0
		return
	end
	local time = workspace:GetServerTimeNow()
	local passEnd = TrainPath.passEnd(currentTrack, pass)
	if time < pass.warnAt or time > passEnd then
		hideTrain()
		if signalsLit then
			signalsLit = false
			setSignals(false, false)
		end
		shakeStrength = 0
		return
	end

	local frame = TrainPath.frame(currentTrack, pass.dir)
	local nose = TrainPath.nose(pass, time)
	local tail = nose - pass.length
	local length = frame.trackLength

	-- signals blink while the train is coming or on the viaduct
	signalsLit = true
	setSignals(true, math.floor(time * BLINK_RATE * 2) % 2 == 0)

	-- the train itself
	if nose > -HIDE_IN_TUNNEL then
		placeTrain(frame, nose)
	else
		hideTrain()
	end
	local light = headlight
	if light then
		light.Enabled = nose > -HIDE_IN_TUNNEL
	end

	-- sounds: from the portal while it is still in the tunnel, then from the train
	local soundAlong = math.clamp((nose + tail) / 2, 0, length)
	soundAnchor.CFrame = CFrame.new(frame.origin + frame.axis * soundAlong + Vector3.new(0, 4, 0))
	local hornSound = horn
	if hornSound then
		if hornedWarn ~= pass.warnAt then
			hornedWarn = pass.warnAt
			hornSound:Play()
		elseif hornedOut ~= pass.start and time >= pass.start - 0.3 then
			hornedOut = pass.start
			hornSound.TimePosition = 0
			hornSound:Play()
		end
	end
	local rumbleSound = rumble
	if rumbleSound then
		local out = nose > -20 and tail < length + 20
		if out and not rumbleSound.Playing then
			rumbleSound:Play()
		elseif not out and rumbleSound.Playing then
			rumbleSound:Stop()
		end
	end

	-- camera rumble: before it comes out, a growing tremor near its portal; then the closer
	-- the train, the stronger
	local distance: number
	local scale: number
	if nose < 0 then
		distance = distanceToTrain(frame, 0, 0)
		scale = 0.35
			* math.clamp((time - pass.warnAt) / math.max(0.1, pass.start - pass.warnAt), 0, 1)
	else
		distance = distanceToTrain(frame, math.max(tail, 0), math.min(nose, length))
		scale = 1
	end
	local closeness = math.clamp(1 - distance / T.SHAKE_RANGE, 0, 1)
	shakeStrength = T.SHAKE_MAX * scale * closeness * closeness
end

-- Runs right after the camera scripts: moves the camera a tiny bit (position only, like
-- the combat shake: a shaking rotation would slowly shift where you aim).
local function shakeCamera()
	if shakeStrength <= 0.01 then
		return
	end
	local camera = workspace.CurrentCamera
	if camera then
		local s = shakeStrength * 0.1
		local offset = Vector3.new(random:NextNumber(-s, s), random:NextNumber(-s, s), 0)
		camera.CFrame += camera.CFrame:VectorToWorldSpace(offset)
	end
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function TrainController.start()
	local found = workspace:WaitForChild("City", 120)
	if found == nil then
		return
	end
	city = found
	-- the track's ends are set when the city is created; wait for the build to be sure
	while city:GetAttribute("Built") ~= true do
		city:GetAttributeChangedSignal("Built"):Wait()
	end
	track = TrainPath.readTrack(city)
	if track == nil then
		return -- no railway in this city: no train
	end
	buildTrain()
	buildSounds()
	hidden = false
	hideTrain()

	CollectionService:GetInstanceAddedSignal(SIGNAL_TAG):Connect(addSignal)
	for _, instance in CollectionService:GetTagged(SIGNAL_TAG) do
		addSignal(instance)
	end
	CollectionService:GetInstanceAddedSignal(SIGNAL_GO_TAG):Connect(addGoLamp)
	for _, instance in CollectionService:GetTagged(SIGNAL_GO_TAG) do
		addGoLamp(instance)
	end
	setSignals(false, false) -- at rest: red off (its light too), green on

	RunService.RenderStepped:Connect(update)
	RunService:BindToRenderStep("TrainShake", Enum.RenderPriority.Camera.Value + 3, shakeCamera)
end

return TrainController
