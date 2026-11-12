--!strict
-- WeatherController: what YOU see and hear of the weather events.
--
-- The server (Server/Systems/Weather) decides the events and already changes the sky, the
-- lamps and the puddles for everyone. This controller adds what only makes sense on each
-- screen, following the attributes the server sets on Workspace (Weather, Storm,
-- WeatherStartedAt, WeatherEndsAt, ThunderAt):
--   • RAIN: streaks falling all around the camera (an invisible box that follows it, with a
--     ParticleEmitter), small splashes on the ground around you, a soft cold "wet" grade on
--     the screen. It all grows and fades with the rain. (The rain SOUND is mixed with the
--     music by CityAudioController, which reads WeatherController.rainState().)
--   • THUNDERSTORM (Storm = true): heavier rain (more drops, slanted by the wind) and
--     lightning: a jagged bolt in the sky + a double white flash of the screen at the exact
--     moment the server chose (the same for every player), then the rumble 1 to 4 s later.
--   • THE PARK (ParkZone, see ParkAtmosphereController) is always sunny: no rain, no
--     splashes, no wet grade and no lightning in there.
--   • A one-line notice top-left for 3 s: "RAIN", "THUNDERSTORM", "FOG", "POWER CUT".
--   • CHARACTER FILL LIGHT (night and power cut): a soft, warm, short-range PointLight on every
--     character's HumanoidRootPart (16 at most), only on this screen. Away from the lamps a
--     fighter in dark clothes would melt into the blue night; this keeps everyone readable.
--
-- No images are used: the drops are plain squares stretched along their fall.
-- Sounds come from Shared/Sounds.luau (Thunder): while its ids are empty, nothing plays and
-- everything else still works.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Parent.UI.Theme)
local ParkAtmosphereController = require(script.Parent.ParkAtmosphereController)
local SoundController = require(script.Parent.SoundController)

local W = Config.Weather
local C = Theme.Colors

local WeatherController = {}

local player = Players.LocalPlayer
local random = Random.new()

-- Words of the notice for each event.
local NOTICE_TEXT: { [string]: string } = {
	Rain = "RAIN",
	Storm = "THUNDERSTORM",
	Fog = "FOG",
	PowerCut = "POWER CUT",
}

-- The "wet" screen grade at full rain: a little colder, a little less colour.
local NO_TINT = Color3.fromRGB(255, 255, 255)
local WET_TINT = Color3.fromRGB(226, 234, 242)
local WET_SATURATION = -0.08
local WET_CONTRAST = 0.04

local rainBox: Part
local rainEmitter: ParticleEmitter
local splashBox: Part
local splashEmitter: ParticleEmitter
local grade: ColorCorrectionEffect
local noticeGui: ScreenGui
local noticeText: TextLabel
local noticeLine: Frame

-- Extra screen brightness of the thunder flash (0 = none).
local flash = 0
-- Smoothed camera speed (the rain box moves ahead of a moving camera).
local cameraVelocity = Vector3.zero
local lastCameraPosition: Vector3? = nil
-- Ground height under you (for the splashes) and whether a roof is over the camera.
local floorY = 0
local covered = false
-- A low ceiling right above the camera (inside a shop, the bar): no rain at all in there.
local indoors = false
-- A ceiling closer than this above the camera counts as "indoors" (the shop ceilings are about
-- 9 above a standing camera; the viaduct deck is about 20 above the street).
local INDOOR_CEILING = 14
local nextProbe = 0
-- Low graphics quality: half the drops.
local lowQuality = false
-- Counts the notices, so an old one doesn't hide a newer one.
local noticeId = 0
-- The rain right now (0 → 1, the park not counted) and whether it is a thunderstorm: read by
-- CityAudioController for the rain sound.
local currentIntensity = 0
local currentStorm = false

-- THUNDERSTORM: how much heavier than a plain rain (Config.Weather.STORM_RAIN_MULT /
-- STORM_WIND): more drops, blown sideways.
local STORM_RATE: number = W.STORM_RAIN_MULT
local STORM_WIND: Vector3 = W.STORM_WIND
local CALM_WIND = Vector3.new(6, 0, 2)
-- The lightning bolt: segments of neon in the sky, far from you.
local BOLT_COLOR = Color3.fromRGB(214, 226, 255)
local BOLT_TIME = 0.22 -- seconds it stays

-- Character fill light (see the header).
local FILL_NAME = "CityFillLight"
local FILL_COLOR = Color3.fromRGB(255, 236, 220)
local FILL_RANGE = 7 -- studs: it lights the character, barely the ground around it
local FILL_BRIGHTNESS = 0.35
local FILL_MAX = 16 -- one per player of a full server
local FILL_CHECK_EVERY = 0.5 -- seconds between two checks
-- Lighting.ClockTime of the night phase is 22.4, of the afternoon 16.9: anything from 19:00 to
-- 06:00 counts as night.
local NIGHT_FROM = 19
local NIGHT_UNTIL = 6
local nextFillCheck = 0

------------------------------------------------------------------------------
-- Reading the server's attributes
------------------------------------------------------------------------------

local function numberAttribute(name: string, default: number): number
	local value = workspace:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

-- 0 (no rain) → 1 (full rain): grows over RAIN_RAMP_IN, fades over RAIN_RAMP_OUT before
-- the end, like the server's sky.
local function rainIntensity(now: number): number
	if workspace:GetAttribute("Weather") ~= "Rain" then
		return 0
	end
	local started = numberAttribute("WeatherStartedAt", now)
	local ends = numberAttribute("WeatherEndsAt", now)
	local fadeIn = math.clamp((now - started) / W.RAIN_RAMP_IN, 0, 1)
	local fadeOut = math.clamp((ends - now) / W.RAIN_RAMP_OUT, 0, 1)
	return math.min(fadeIn, fadeOut)
end

------------------------------------------------------------------------------
-- Building the effects
------------------------------------------------------------------------------

-- An invisible, anchored box that nothing touches or hits (it lives in the camera, so only
-- this player has it).
local function makeBox(name: string, size: Vector3): Part
	local box = Instance.new("Part")
	box.Name = name
	box.Size = size
	box.Transparency = 1
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Parent = workspace.CurrentCamera
	return box
end

local function buildRain()
	-- The drops: born on the box's bottom face, falling fast, stretched along their fall.
	rainBox = makeBox("WeatherRain", Vector3.new(W.RAIN_AREA, 1, W.RAIN_AREA))
	rainEmitter = Instance.new("ParticleEmitter")
	rainEmitter.Name = "Drops"
	rainEmitter.Texture = "" -- no image: a plain square, stretched into a streak by Squash
	rainEmitter.Shape = Enum.ParticleEmitterShape.Box
	rainEmitter.EmissionDirection = Enum.NormalId.Bottom
	rainEmitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	rainEmitter.Rate = 0
	rainEmitter.Lifetime = NumberRange.new(0.55, 0.75)
	rainEmitter.Speed = NumberRange.new(110, 130)
	rainEmitter.Size = NumberSequence.new(0.3)
	rainEmitter.Squash = NumberSequence.new(3) -- thin and long
	rainEmitter.Color = ColorSequence.new(Color3.fromRGB(170, 180, 190))
	rainEmitter.Transparency = NumberSequence.new(0.6)
	rainEmitter.LightInfluence = 0.7 -- the lamps light the drops a little
	rainEmitter.Acceleration = Vector3.new(6, 0, 2) -- a light wind
	rainEmitter.Parent = rainBox

	-- The splashes: tiny specks jumping off the ground around you.
	splashBox = makeBox("WeatherSplash", Vector3.new(40, 0.2, 40))
	splashEmitter = Instance.new("ParticleEmitter")
	splashEmitter.Name = "Splashes"
	splashEmitter.Texture = ""
	splashEmitter.Shape = Enum.ParticleEmitterShape.Box
	splashEmitter.EmissionDirection = Enum.NormalId.Top
	splashEmitter.Rate = 0
	splashEmitter.Lifetime = NumberRange.new(0.12, 0.18)
	splashEmitter.Speed = NumberRange.new(2, 4)
	splashEmitter.SpreadAngle = Vector2.new(80, 80)
	splashEmitter.Size = NumberSequence.new(0.25, 0)
	splashEmitter.Color = ColorSequence.new(Color3.fromRGB(180, 188, 196))
	splashEmitter.Transparency = NumberSequence.new(0.4)
	splashEmitter.LightInfluence = 0.7
	splashEmitter.Parent = splashBox

	-- Our own colour correction (made on the client: only this player has it).
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "WeatherGrade"
	grade.Parent = Lighting
end

local function buildNotice()
	noticeGui = Theme.make("ScreenGui", {
		Name = "WeatherNotice",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 4,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- ── RAIN    (a short hairline, then the word)
	noticeLine = Theme.make("Frame", {
		Name = "Line",
		Position = UDim2.fromOffset(24, 77),
		Size = UDim2.fromOffset(14, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 1,
		Parent = noticeGui,
	})
	noticeText = Theme.text({
		Name = "Text",
		Position = UDim2.fromOffset(46, 70),
		Size = UDim2.fromOffset(200, 14),
		FontFace = Theme.Fonts.Label,
		TextSize = 12,
		TextColor3 = C.Ink,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
		Parent = noticeGui,
	})
end

------------------------------------------------------------------------------
-- Notice and thunder
------------------------------------------------------------------------------

local function showNotice(text: string)
	-- In a duel you are in an arena: the city's weather news is not for now.
	if player:GetAttribute("InDuel") == true then
		return
	end
	noticeId += 1
	local id = noticeId
	noticeText.Text = Theme.track(text, "three")
	noticeText.Position = UDim2.fromOffset(40, 70)
	Theme.tween(noticeText, 0.4, {
		TextTransparency = 0.1,
		TextStrokeTransparency = Theme.STROKE_TRANSPARENCY,
		Position = UDim2.fromOffset(46, 70),
	})
	Theme.tween(noticeLine, 0.4, { BackgroundTransparency = 0.3 })
	task.delay(W.NOTICE_TIME, function()
		if id ~= noticeId then
			return
		end
		Theme.tween(noticeText, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
		Theme.tween(noticeLine, 0.6, { BackgroundTransparency = 1 })
	end)
end

-- A jagged bolt of light far away in the sky, roughly where you look (only this screen has
-- it), for a split second. Plain neon parts, no image.
local function drawBolt()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
	-- 160 to 320 studs away, up to 50 degrees left or right of where you look
	local angle = math.rad(random:NextNumber(-50, 50))
	local direction = CFrame.Angles(0, angle, 0):VectorToWorldSpace(flat)
	local base = camera.CFrame.Position + direction * random:NextNumber(160, 320)
	local point = Vector3.new(base.X, 420, base.Z)
	local bottom = math.max(base.Y - 20, 30)
	local folder = Instance.new("Folder")
	folder.Name = "LightningBolt"
	local width = 1.6
	while point.Y > bottom do
		local nextPoint = point
			+ Vector3.new(
				random:NextNumber(-14, 14),
				-random:NextNumber(18, 34),
				random:NextNumber(-14, 14)
			)
		local segment = Instance.new("Part")
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.CastShadow = false
		segment.Material = Enum.Material.Neon
		segment.Color = BOLT_COLOR
		segment.Size = Vector3.new(width, width, (nextPoint - point).Magnitude)
		segment.CFrame = CFrame.lookAt((point + nextPoint) / 2, nextPoint)
		segment.Parent = folder
		-- a small branch now and then
		if random:NextNumber() < 0.3 then
			local branchEnd = nextPoint
				+ Vector3.new(
					random:NextNumber(-20, 20),
					-random:NextNumber(10, 22),
					random:NextNumber(-20, 20)
				)
			local branch = segment:Clone()
			branch.Size = Vector3.new(width * 0.5, width * 0.5, (branchEnd - nextPoint).Magnitude)
			branch.CFrame = CFrame.lookAt((nextPoint + branchEnd) / 2, branchEnd)
			branch.Parent = folder
		end
		point = nextPoint
		width = math.max(0.5, width * 0.93)
	end
	folder.Parent = camera
	task.delay(BOLT_TIME, function()
		folder:Destroy()
	end)
end

-- The bolt and the double flash of the screen, then the rumble. (Not in the park: the sun
-- shines there.) A thunderstorm's flashes are brighter.
local function thunder()
	if ParkAtmosphereController.blend() > 0.5 then
		return
	end
	local strength = if workspace:GetAttribute("Storm") == true then 1.6 else 1
	drawBolt()
	flash = 0.35 * strength
	task.wait(0.06)
	flash = 0.12 * strength
	task.wait(0.08)
	flash = 0
	task.wait(0.1)
	flash = 0.2 * strength
	task.wait(0.05)
	flash = 0
	task.wait(random:NextNumber(W.THUNDER_SOUND_DELAY.Min, W.THUNDER_SOUND_DELAY.Max))
	SoundController.play2D("Thunder", random:NextNumber(0.6, 1))
end

local function onThunderAt()
	local at = workspace:GetAttribute("ThunderAt")
	if typeof(at) ~= "number" then
		return
	end
	local secondsLeft = at - workspace:GetServerTimeNow()
	-- Too old (we just joined): no flash.
	if secondsLeft < -1 then
		return
	end
	task.delay(math.max(0, secondsLeft), thunder)
end

local function onWeatherChanged()
	local kind = workspace:GetAttribute("Weather")
	if typeof(kind) ~= "string" then
		return
	end
	if kind == "Rain" and workspace:GetAttribute("Storm") == true then
		kind = "Storm"
	end
	-- In the park the sun always shines: no weather notice there (nothing happens in it).
	if ParkAtmosphereController.inPark() then
		return
	end
	local text = NOTICE_TEXT[kind]
	if text then
		showNotice(text)
	end
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

-- Every 0.25 s: the ground height under you, and whether a roof is above the camera.
local function probe(cameraPosition: Vector3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { workspace.CurrentCamera }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local from = if root and root:IsA("BasePart") then root.Position else cameraPosition
	local down = workspace:Raycast(from, Vector3.new(0, -60, 0), params)
	floorY = if down then down.Position.Y else from.Y - 3
	local up = workspace:Raycast(cameraPosition, Vector3.new(0, 40, 0), params)
	covered = up ~= nil
	indoors = up ~= nil and (up :: RaycastResult).Distance < INDOOR_CEILING
end

local function update(deltaTime: number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local now = workspace:GetServerTimeNow()
	currentIntensity = rainIntensity(now)
	currentStorm = workspace:GetAttribute("Storm") == true
	-- No rain at all in the park (always sunny there): faded with the park's light.
	local intensity = currentIntensity * (1 - ParkAtmosphereController.blend())
	local cameraPosition = camera.CFrame.Position
	-- The camera can be replaced (rare): move our boxes into the new one.
	if rainBox.Parent ~= camera then
		rainBox.Parent = camera
		splashBox.Parent = camera
	end

	-- Screen grade: wet look + thunder flash.
	grade.Brightness = flash
	grade.TintColor = NO_TINT:Lerp(WET_TINT, intensity)
	grade.Saturation = WET_SATURATION * intensity
	grade.Contrast = WET_CONTRAST * intensity

	if intensity <= 0 then
		rainEmitter.Rate = 0
		splashEmitter.Rate = 0
		lastCameraPosition = nil
		return
	end

	-- The camera's speed, smoothed (and capped, so a respawn doesn't throw the rain away).
	if lastCameraPosition and deltaTime > 0 then
		local velocity = (cameraPosition - lastCameraPosition) / deltaTime
		if velocity.Magnitude > 80 then
			velocity = Vector3.zero
		end
		cameraVelocity = cameraVelocity:Lerp(velocity, math.min(1, deltaTime * 4))
	end
	lastCameraPosition = cameraPosition
	if os.clock() >= nextProbe then
		nextProbe = os.clock() + 0.25
		probe(cameraPosition)
	end

	local ahead = cameraVelocity * W.RAIN_LEAD
	rainBox.CFrame = CFrame.new(cameraPosition + ahead + Vector3.new(0, W.RAIN_HEIGHT, 0))
	-- A thunderstorm: more drops, slanted by the wind.
	local heavy = if currentStorm then STORM_RATE else 1
	rainEmitter.Rate = if indoors
		then 0
		else W.RAIN_RATE * intensity * heavy * (if lowQuality then 0.5 else 1)
	rainEmitter.Acceleration = if currentStorm then STORM_WIND else CALM_WIND
	splashBox.CFrame = CFrame.new(cameraPosition.X, floorY + 0.2, cameraPosition.Z)
	splashEmitter.Rate = if covered then 0 else W.SPLASH_RATE * intensity * heavy
end

------------------------------------------------------------------------------
-- Character fill light
------------------------------------------------------------------------------

-- True at night and during a power cut (when the fill light is wanted).
local function fillWanted(): boolean
	local clock = Lighting.ClockTime
	local night = clock >= NIGHT_FROM or clock < NIGHT_UNTIL
	return night or workspace:GetAttribute("Weather") == "PowerCut"
end

-- Gives every character a fill light (created once, then only switched on and off).
local function updateFillLights()
	local wanted = fillWanted()
	local count = 0
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local light = root:FindFirstChild(FILL_NAME)
			if light == nil and wanted and count < FILL_MAX then
				local newLight = Instance.new("PointLight")
				newLight.Name = FILL_NAME
				newLight.Color = FILL_COLOR
				newLight.Range = FILL_RANGE
				newLight.Brightness = FILL_BRIGHTNESS
				newLight.Shadows = false
				newLight.Parent = root
				light = newLight
			end
			if light and light:IsA("PointLight") then
				light.Enabled = wanted and count < FILL_MAX
				count += 1
			end
		end
	end
end

------------------------------------------------------------------------------
-- Read by CityAudioController (the rain sound)
------------------------------------------------------------------------------

-- The rain right now: its intensity (0 → 1, the park NOT counted: the caller fades it
-- itself), whether it is a thunderstorm, whether a roof is above the camera, and whether
-- the camera is under a low ceiling (inside).
function WeatherController.rainState(): (number, boolean, boolean, boolean)
	return currentIntensity, currentStorm, covered, indoors
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

local function readQuality()
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	-- "Automatic" counts as high; levels 1 to 3 are low.
	lowQuality = ok and level.Value >= 1 and level.Value <= 3
end

function WeatherController.start()
	buildRain()
	buildNotice()
	readQuality()
	task.spawn(function()
		while true do
			task.wait(5)
			readQuality()
		end
	end)
	workspace:GetAttributeChangedSignal("Weather"):Connect(onWeatherChanged)
	workspace:GetAttributeChangedSignal("ThunderAt"):Connect(onThunderAt)
	RunService.RenderStepped:Connect(update)
	-- The fill lights are checked twice a second (players join, respawn, night falls).
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextFillCheck then
			nextFillCheck = now + FILL_CHECK_EVERY
			updateFillLights()
		end
	end)
end

return WeatherController
