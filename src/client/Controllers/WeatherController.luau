--!strict
-- WeatherController: what YOU see and hear of the weather events.
--
-- The server (Server/Systems/Weather) decides the events and already changes the sky, the
-- lamps and the puddles for everyone. This controller adds what only makes sense on each
-- screen, following the attributes the server sets on Workspace (Weather, Storm,
-- WeatherStartedAt, WeatherEndsAt, ThunderAt):
--   • RAIN: streaks falling all around the camera (an invisible box that follows it, with a
--     ParticleEmitter), small splashes on the ground around you, a soft cold "wet" grade on
--     the screen and the rain sound loop. It all grows and fades with the rain.
--   • THUNDER (storms): a double white flash of the screen at the exact moment the server
--     chose (the same for every player), then the rumble 1 to 4 s later.
--   • A one-line notice top-left for 3 s: "RAIN", "STORM", "FOG", "POWER CUT". No banner.
--   • CHARACTER FILL LIGHT (night and power cut): a soft, warm, short-range PointLight on every
--     character's HumanoidRootPart (16 at most), only on this screen. Away from the lamps a
--     fighter in dark clothes would melt into the blue night; this keeps everyone readable.
--
-- No images are used: the drops are plain squares stretched along their fall.
-- Sounds come from Shared/Sounds.luau (Rain, Thunder): while their ids are empty, nothing
-- plays and everything else still works.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local Theme = require(script.Parent.Parent.UI.Theme)
local SoundController = require(script.Parent.SoundController)

local W = Config.Weather
local C = Theme.Colors

local WeatherController = {}

local player = Players.LocalPlayer
local random = Random.new()

-- Words of the notice for each event.
local NOTICE_TEXT: { [string]: string } = {
	Rain = "RAIN",
	Storm = "STORM",
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
local rainSound: Sound? = nil
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

	rainSound = SoundController.loop("Rain")
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

-- The double flash of a lightning bolt, then the rumble.
local function thunder()
	flash = 0.35
	task.wait(0.06)
	flash = 0.12
	task.wait(0.08)
	flash = 0
	task.wait(0.1)
	flash = 0.2
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
	local intensity = rainIntensity(now)
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
		if rainSound and rainSound.IsPlaying then
			rainSound:Stop()
		end
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
	rainEmitter.Rate = if indoors
		then 0
		else W.RAIN_RATE * intensity * (if lowQuality then 0.5 else 1)
	splashBox.CFrame = CFrame.new(cameraPosition.X, floorY + 0.2, cameraPosition.Z)
	splashEmitter.Rate = if covered then 0 else W.SPLASH_RATE * intensity

	if rainSound then
		rainSound.Volume = Sounds.Rain.volume
			* intensity
			* (if indoors then 0.25 elseif covered then 0.5 else 1)
		if not rainSound.IsPlaying then
			rainSound:Play()
		end
	end
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
