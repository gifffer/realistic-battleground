--!strict
-- WeatherController: what YOU see and hear of the weather events.
--
-- The server (Server/Systems/Weather) decides the events and already changes the sky, the
-- lamps and the puddles for everyone. This controller adds what only makes sense on each
-- screen, following the attributes the server sets on Workspace (Weather, Storm,
-- WeatherStartedAt, WeatherEndsAt, ThunderAt):
--   • RAIN: the rain's state (how strong, storm or not, a roof above you, the wind and its
--     gusts) and a soft cold "wet" grade on the screen. It all grows and fades with the rain.
--     The falling drops, splashes and ripples are drawn by RainController (it reads
--     rainState() and fallDirection()); the rain SOUND is mixed with the music by
--     CityAudioController.
--   • THUNDERSTORM (Storm = true): heavier rain (more drops, slanted by the wind) and
--     lightning: a jagged bolt in the sky + a double white flash of the screen at the exact
--     moment the server chose (the same for every player), then the rumble 1 to 4 s later.
--     The bolt falls in a random direction (often in front of you, so you see it). The flash
--     is a cold blue-white, and lights the whole picture for a frame or two. About one bolt
--     in five is CLOSE: brighter, a short burst of light on the street where it falls, the
--     camera shakes a little, and the thunder comes almost at once (a loud crack).
--   • WIND GUSTS (rain and thunderstorm): every few seconds a gust leans the rain harder for
--     1 to 3 s, then it settles back. fallDirection() is the slanted fall (much more in a
--     thunderstorm).
--   • THE PARK (ParkZone, see ParkAtmosphereController) is always sunny: no rain, no
--     splashes, no wet grade and no lightning in there.
--   • A one-line notice top-left for 3 s: "RAIN", "THUNDERSTORM", "FOG", "POWER CUT".
--   • CHARACTER FILL LIGHT (night and power cut): a soft, warm, short-range PointLight on every
--     character's HumanoidRootPart (16 at most), only on this screen. Away from the lamps a
--     fighter in dark clothes would melt into the blue night; this keeps everyone readable.
--
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

local grade: ColorCorrectionEffect
local noticeGui: ScreenGui
local noticeText: TextLabel
local noticeLine: Frame

-- Extra screen brightness of the thunder flash (0 = none).
local flash = 0
-- Whether a roof is over the camera.
local covered = false
-- A low ceiling right above the camera (inside a shop, the bar): no rain at all in there.
local indoors = false
-- A ceiling closer than this above the camera counts as "indoors" (the shop ceilings are about
-- 9 above a standing camera; the viaduct deck is about 20 above the street).
local INDOOR_CEILING = 14
local nextProbe = 0
-- Counts the notices, so an old one doesn't hide a newer one.
local noticeId = 0
-- The rain right now (0 → 1, the park not counted) and whether it is a thunderstorm: read by
-- CityAudioController for the rain sound.
local currentIntensity = 0
local currentStorm = false
-- The way the drops fall right now (a unit vector, slanted by the wind and the gusts).
local currentFall = Vector3.new(0, -1, 0)

-- THUNDERSTORM: the rain is blown sideways (Config.Weather.STORM_WIND; how much denser it
-- is, STORM_RAIN_MULT, is used by RainController).
local STORM_WIND: Vector3 = W.STORM_WIND
local CALM_WIND = Vector3.new(6, 0, 2)
-- The lightning bolt: segments of neon in the sky, far from you.
local BOLT_COLOR = Color3.fromRGB(214, 226, 255)
local BOLT_TIME = 0.22 -- seconds it stays
-- The cold tint of the screen during a lightning flash (mixed in with the flash's strength).
local FLASH_TINT = Color3.fromRGB(200, 214, 255)
-- Share of the bolts that fall CLOSE (60 to 120 studs): brighter, a shake, an instant crack.
local CLOSE_STRIKE_CHANCE = 0.2
local CLOSE_SHAKE = 1.4 -- strongest camera shake of a close strike (1 = 0.1 stud)
-- How much the rain leans with the wind (sideways studs per stud of fall): plain rain,
-- thunderstorm, and the extra lean of a full gust.
local RAIN_LEAN = 0.07
local STORM_LEAN = 0.22
local GUST_LEAN = 0.2
-- Gusts: seconds between two, and how long one lasts.
local GUST_GAP = NumberRange.new(5, 12)
local GUST_TIME = NumberRange.new(1.2, 3)

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

-- Gust state: when the current gust started / lasts, when the next one comes, and its
-- strength right now (0 → 1).
local gustStart = 0
local gustLength = 0
local nextGust = 0
local gustLevel = 0
-- Camera shake of a close lightning strike (decays to 0).
local thunderShake = 0

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

-- 0 (no fog) → 1 (full fog), with the server's FOG_RAMP in and out (the park not counted).
local function fogIntensity(now: number): number
	if workspace:GetAttribute("Weather") ~= "Fog" then
		return 0
	end
	local started = numberAttribute("WeatherStartedAt", now)
	local ends = numberAttribute("WeatherEndsAt", now)
	local fadeIn = math.clamp((now - started) / W.FOG_RAMP, 0, 1)
	local fadeOut = math.clamp((ends - now) / W.FOG_RAMP, 0, 1)
	return math.min(fadeIn, fadeOut)
end

------------------------------------------------------------------------------
-- Building the effects
------------------------------------------------------------------------------

local function buildGrade()
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

-- A jagged bolt of light in the sky (only this screen has it), for a split second, `distance`
-- studs away in a random direction (2 times out of 3 within 60 degrees of where you look, so
-- you see most of them). Plain neon parts, no image. Returns where it touches down.
local function drawBolt(distance: number): Vector3?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
	local angle = if random:NextNumber() < 0.67
		then math.rad(random:NextNumber(-60, 60))
		else math.rad(random:NextNumber(0, 360))
	local direction = CFrame.Angles(0, angle, 0):VectorToWorldSpace(flat)
	local base = camera.CFrame.Position + direction * distance
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
	return Vector3.new(base.X, bottom, base.Z)
end

-- A close strike lights the street where it falls: one short, strong, cold light.
local function strikeLight(at: Vector3)
	local holder = Instance.new("Part")
	holder.Name = "LightningGlow"
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Size = Vector3.one
	holder.Position = at + Vector3.new(0, 12, 0)
	local light = Instance.new("PointLight")
	light.Color = BOLT_COLOR
	light.Range = 60
	light.Brightness = 6
	light.Shadows = false
	light.Parent = holder
	holder.Parent = workspace.CurrentCamera
	task.delay(0.08, function()
		light.Brightness = 2
	end)
	task.delay(0.2, function()
		holder:Destroy()
	end)
end

-- The bolt and the double flash of the screen, then the rumble. (Not in the park: the sun
-- shines there.) A thunderstorm's flashes are brighter.
local function thunder()
	if ParkAtmosphereController.blend() > 0.5 then
		return
	end
	local close = random:NextNumber() < CLOSE_STRIKE_CHANCE
	local strength = (if workspace:GetAttribute("Storm") == true then 1.6 else 1)
		* (if close then 1.35 else 1)
	local ground =
		drawBolt(if close then random:NextNumber(60, 120) else random:NextNumber(170, 380))
	if close and ground then
		strikeLight(ground)
		thunderShake = CLOSE_SHAKE
	end
	flash = 0.35 * strength
	task.wait(0.06)
	flash = 0.12 * strength
	task.wait(0.08)
	flash = 0
	task.wait(0.1)
	flash = 0.2 * strength
	task.wait(0.05)
	flash = 0
	-- (light is faster than sound: a close strike cracks almost at once, and louder)
	if close then
		task.wait(random:NextNumber(0.15, 0.5))
		SoundController.play2D("Thunder", 1.15)
	else
		task.wait(random:NextNumber(W.THUNDER_SOUND_DELAY.Min, W.THUNDER_SOUND_DELAY.Max))
		SoundController.play2D("Thunder", random:NextNumber(0.6, 1))
	end
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

-- Every 0.25 s: whether a roof is above the camera.
local function probe(cameraPosition: Vector3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { workspace.CurrentCamera }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local up = workspace:Raycast(cameraPosition, Vector3.new(0, 40, 0), params)
	covered = up ~= nil
	indoors = up ~= nil and (up :: RaycastResult).Distance < INDOOR_CEILING
end

local function update()
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

	-- Screen grade: wet look + thunder flash (a cold blue-white while it lasts).
	grade.Brightness = flash
	grade.TintColor = NO_TINT:Lerp(WET_TINT, intensity):Lerp(FLASH_TINT, math.min(1, flash * 2))
	grade.Saturation = WET_SATURATION * intensity
	grade.Contrast = WET_CONTRAST * intensity

	if intensity <= 0 then
		return
	end

	if os.clock() >= nextProbe then
		nextProbe = os.clock() + 0.25
		probe(cameraPosition)
	end

	-- Gusts: a smooth bump (0 → 1 → 0) every few seconds.
	local clock = os.clock()
	if clock >= nextGust then
		gustStart = clock
		gustLength = random:NextNumber(GUST_TIME.Min, GUST_TIME.Max)
		nextGust = clock + gustLength + random:NextNumber(GUST_GAP.Min, GUST_GAP.Max)
	end
	local gustAlpha = math.clamp((clock - gustStart) / math.max(gustLength, 0.01), 0, 1)
	gustLevel = math.sin(gustAlpha * math.pi)
	-- The rain leans with the wind (and harder in a gust): RainController turns its rain
	-- cells along this slanted fall.
	local wind = if currentStorm then STORM_WIND else CALM_WIND
	local windFlat = Vector3.new(wind.X, 0, wind.Z)
	windFlat = if windFlat.Magnitude > 0 then windFlat.Unit else Vector3.xAxis
	local lean = (if currentStorm then STORM_LEAN else RAIN_LEAN) + GUST_LEAN * gustLevel
	currentFall = (Vector3.new(0, -1, 0) + windFlat * lean).Unit
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

-- The fog right now: 0 → 1 (fades in / out like the server's haze; the park NOT counted).
-- Read by CityAudioController (muffled city) and WeatherFxController (ground fog, halos).
function WeatherController.fogIntensity(): number
	return fogIntensity(workspace:GetServerTimeNow())
end

-- The way the drops fall right now: a unit vector, slanted by the wind and the gusts.
-- Read by RainController.
function WeatherController.fallDirection(): Vector3
	return currentFall
end

-- The current gust (0 = calm → 1 = the peak of a gust).
function WeatherController.gust(): number
	return gustLevel
end

-- A close lightning strike's camera shake: right after the camera scripts, a tiny move
-- (position only, like the train's rumble: a shaking rotation would shift where you aim).
local function shakeCamera(deltaTime: number)
	if thunderShake <= 0.01 then
		thunderShake = 0
		return
	end
	local camera = workspace.CurrentCamera
	if camera then
		local s = thunderShake * 0.1
		local offset = Vector3.new(random:NextNumber(-s, s), random:NextNumber(-s, s), 0)
		camera.CFrame += camera.CFrame:VectorToWorldSpace(offset)
	end
	-- (gone in about half a second)
	thunderShake = math.max(0, thunderShake - deltaTime * 2.6)
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function WeatherController.start()
	buildGrade()
	buildNotice()
	workspace:GetAttributeChangedSignal("Weather"):Connect(onWeatherChanged)
	workspace:GetAttributeChangedSignal("ThunderAt"):Connect(onThunderAt)
	RunService.RenderStepped:Connect(update)
	RunService:BindToRenderStep("ThunderShake", Enum.RenderPriority.Camera.Value + 4, shakeCamera)
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
