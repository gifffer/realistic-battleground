--!strict
-- Ambience: the light of the city, on a cycle, and every light of the district.
--
--   LATE AFTERNOON  grey, overcast, a faint warm sun behind the clouds   (6 min)
--   DUSK            the light falls, lamps and windows come on           (1 min 30)
--   NIGHT           wet streets, dirty orange lamps, a few neons         (6 min)
--   DAWN            back to the afternoon                                (1 min 30)
--
-- Done on the server: Lighting and part changes replicate, so every player sees the same moment.
-- The goal is GLOOMY at all times: low saturation, haze, heavy clouds (DIRECTION.md 5.3).
--
-- What it drives (CollectionService tags put on the parts by Server/Systems/City):
--   CityLamp        street lamps: on at night. Attribute Dead = never on, Flicker = cuts out
--                   for a split second now and then (only a few lamps have it).
--   CityNeon        shop signs and small neon lamps. Brighter at night. Attribute
--                   Flicker = "random" (stutters) or "blink" (1 s on / 1 s off),
--                   OwnPower = stays on during a power cut (aircraft light, signals...).
--   CityWindowLit   windows that can light up: about 35 % of them (picked again each night)
--                   are on at night, steady. Day = true ones are dimly lit in the afternoon.
--   CityBulkhead    wall lights above doors: on at night.
--   CityShopLight   shop ceiling lights (+ the shelf lights next to them): always on.
--   CityEmergency   red exit lights: ONLY during a power cut.
--   CityFireEmbers  burn barrel glow: always on, flickering like a fire.
--   CityPuddle      puddles: shine more at night and in the rain (RainOnly ones: rain only).
--   CityWetSurface  big road / roof slabs: a bit shinier in the rain.
--   CityDrip        water drips: rain only.
--   CitySteam       steam vents: twice as much in the rain, half in the fog.
--   CityGutter      drainpipe shoes: a few spout water in the rain.
--
-- The weather EVENTS (rain, fog, power cut, thunder) are decided by Server/Systems/Weather,
-- which calls the functions at the bottom of this file. The weather is applied ON TOP of the
-- day / night look: target = base look of the phase, then the weather changes it.
--
-- Note: Lighting.Technology must be "Future". default.project.json sets it (Rojo writes it into
-- the place); a script cannot change it. Without it the lamp pools, the shop light spilling on
-- the sidewalk and the neon glow look much flatter and darker. Ambience.start() prints a warning
-- in the output when it is not Future.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Ambience = {}

-- Length of each phase, in seconds.
local DAY_TIME = 360
local NIGHT_TIME = 360
local TRANSITION = 90

-- Share of the CityWindowLit windows that are lit at night (picked at random each night).
local LIT_WINDOW_SHARE = 0.35

-- Colours used by the lights (see DIRECTION.md 5.2).
local LAMP_OFF_COLOR = Color3.fromRGB(90, 90, 86) -- a lamp head by day: dirty grey glass
local SODIUM_WARMUP_COLOR = Color3.fromRGB(255, 60, 30) -- a sodium lamp that just came back
local EMERGENCY_COLOR = Color3.fromRGB(170, 20, 20)
local WINDOW_COLORS: { [string]: Color3 } = {
	warm = Color3.fromRGB(150, 104, 58), -- a room lit by a lamp
	tv = Color3.fromRGB(70, 96, 140), -- a TV in a dark room
	cold = Color3.fromRGB(140, 160, 150), -- a stairwell tube
}

local random = Random.new()

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

-- Where we are in the cycle, and when this phase ends (os.clock()).
local phase = "Day"
local phaseEndsAt = 0
-- Counts the nights since the server started (the weather allows one power cut per night).
local nightNumber = 0
-- The look we are going to: night or afternoon (switches at the START of a transition).
local targetNight = false
-- The lamps' phase (switches HALFWAY through a transition).
local lightsNight = false
-- When the current day / night transition ends (os.clock()).
local transitionEndsAt = 0
-- The weather on top of the phase: "Clear", "Rain", "Storm" (a thunderstorm: a darker,
-- heavier rain) or "Fog".
local weather = "Clear"
-- False during a power cut.
local powerOn = true
-- Parts the power-restore wave has not reached yet (treated as unpowered).
local waitingPower: { [Instance]: boolean } = {}
-- The windows lit tonight.
local litWindows: { [Instance]: boolean } = {}
-- During a power cut, a few windows show a candle.
local candles: { [Instance]: boolean } = {}
-- "blink" neons: true = the "on" half of the second.
local blinkOn = true

local atmosphere: Atmosphere
local grade: ColorCorrectionEffect
local bloom: BloomEffect
local sunRays: SunRaysEffect
local clouds: Clouds

------------------------------------------------------------------------------
-- The looks
------------------------------------------------------------------------------

-- A "look" lists, for each object, the properties to tween and their target value.
type Props = { [string]: any }
type Look = {
	lighting: Props,
	atmosphere: Props,
	clouds: Props,
	grade: Props,
	bloom: Props,
	sunRays: Props,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- A colour made darker (factor < 1) or lighter (factor > 1).
local function scale(color: Color3, factor: number): Color3
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

-- The base look of the afternoon or of the night (a new table each call: the weather
-- changes it freely). Values from DIRECTION2.md 6.2: still gloomy, but the night is no longer a
-- flat dark blue. The ambient light is lifted and almost neutral, so a fighter in dark clothes
-- stays readable away from the lamps, and the lamps and shop windows give the contrast.
local function baseLook(night: boolean): Look
	if night then
		return {
			lighting = {
				ClockTime = 22.4,
				Brightness = 0.7,
				Ambient = rgb(46, 46, 54),
				OutdoorAmbient = rgb(84, 86, 104),
				ExposureCompensation = 0.35,
				EnvironmentDiffuseScale = 0.35,
				EnvironmentSpecularScale = 0.9,
				ShadowSoftness = 0.25,
			},
			atmosphere = {
				-- A low Offset keeps the near streets clear; the haze builds up with distance.
				Density = 0.32,
				Offset = 0.02,
				Color = rgb(72, 78, 98),
				Decay = rgb(40, 44, 60),
				Glare = 0,
				Haze = 1.4,
			},
			clouds = { Cover = 0.88, Density = 0.6, Color = rgb(54, 56, 66) },
			grade = {
				Brightness = 0.04,
				Contrast = 0.1,
				Saturation = -0.08,
				TintColor = rgb(232, 234, 246),
			},
			-- (Threshold 1.6, was 1.3: lit sidewalks and zebras bloomed to white)
			bloom = { Intensity = 0.6, Size = 24, Threshold = 1.6 },
			sunRays = { Intensity = 0, Spread = 0.6 },
		}
	end
	return {
		lighting = {
			ClockTime = 16.9,
			Brightness = 1.8,
			Ambient = rgb(70, 70, 76),
			OutdoorAmbient = rgb(120, 120, 126),
			ExposureCompensation = 0,
			EnvironmentDiffuseScale = 0.4,
			EnvironmentSpecularScale = 0.6,
			ShadowSoftness = 0.35,
		},
		-- (a little less haze and a little more contrast: the afternoon was a grey wash)
		atmosphere = {
			Density = 0.26,
			Offset = 0.08,
			Color = rgb(176, 174, 170),
			Decay = rgb(100, 100, 106),
			Glare = 0.1,
			Haze = 1.2,
		},
		clouds = { Cover = 0.8, Density = 0.7, Color = rgb(140, 140, 144) },
		grade = {
			Brightness = 0,
			Contrast = 0.16,
			Saturation = -0.22,
			TintColor = rgb(240, 238, 234),
		},
		bloom = { Intensity = 0.35, Size = 24, Threshold = 2 },
		sunRays = { Intensity = 0.03, Spread = 0.6 },
	}
end

-- The base look, changed by the current weather and by a power cut.
local function currentLook(): Look
	local look = baseLook(targetNight)
	if weather == "Rain" or weather == "Storm" then
		-- Darker sky, thicker air, the lamps get halos.
		look.lighting.Brightness *= 0.7
		look.lighting.OutdoorAmbient =
			scale(look.lighting.OutdoorAmbient, if targetNight then 0.9 else 0.85)
		look.atmosphere.Density += 0.08
		look.atmosphere.Haze += 0.8
		look.clouds.Cover = 1
		look.clouds.Density = 0.9
		look.clouds.Color = scale(look.clouds.Color, 0.7)
		look.grade.Saturation -= 0.1
		look.grade.Contrast += 0.04
		look.bloom.Size += 6
		look.sunRays.Intensity = 0
		if weather == "Storm" then
			-- A thunderstorm: a black sky, thicker rain haze, colder and darker still.
			look.lighting.Brightness *= 0.75
			look.lighting.OutdoorAmbient = scale(look.lighting.OutdoorAmbient, 0.85)
			look.atmosphere.Density += 0.05
			look.atmosphere.Haze += 0.6
			look.clouds.Color = scale(look.clouds.Color, 0.7)
			look.grade.Contrast += 0.04
			look.grade.TintColor = look.grade.TintColor:Lerp(rgb(214, 224, 240), 0.5)
		end
	elseif weather == "Fog" then
		-- About 70 studs of visibility on this small map: the lamps become orbs.
		look.atmosphere.Density = 0.5
		look.atmosphere.Offset = 0
		look.atmosphere.Haze = 3.6
		look.atmosphere.Color = if targetNight then rgb(48, 52, 62) else rgb(160, 162, 164)
		look.atmosphere.Glare = 0
		look.bloom.Size = 36
		look.grade.Contrast -= 0.05
		look.sunRays.Intensity = 0
	end
	if not powerOn then
		look.lighting.Ambient = scale(look.lighting.Ambient, 0.75)
		look.lighting.OutdoorAmbient = scale(look.lighting.OutdoorAmbient, 0.75)
	end
	return look
end

local function tweenTo(instance: Instance, seconds: number, props: Props)
	if seconds <= 0.05 then
		for key, value in props do
			(instance :: any)[key] = value
		end
		return
	end
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(instance, info, props):Play()
end

-- Tweens everything to the current look. `withClock` = also move the sun (only the day /
-- night transitions do: the weather must not hurry the sunset).
local function applyLook(seconds: number, withClock: boolean)
	local look = currentLook()
	if not withClock then
		look.lighting.ClockTime = nil
		-- A transition is running: don't finish it sooner than planned.
		seconds = math.max(seconds, transitionEndsAt - os.clock())
	end
	tweenTo(Lighting, seconds, look.lighting)
	tweenTo(atmosphere, seconds, look.atmosphere)
	tweenTo(clouds, seconds, look.clouds)
	tweenTo(grade, seconds, look.grade)
	tweenTo(bloom, seconds, look.bloom)
	tweenTo(sunRays, seconds, look.sunRays)
end

local function setupEffects()
	Lighting.GlobalShadows = true
	Lighting.GeographicLatitude = 52
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "AmbienceGrade"
	grade.Parent = Lighting
	bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Parent = Lighting
	sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	sunRays.Parent = Lighting
	-- No stars (the city lights and the clouds hide them), but keep the moon.
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = 0
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting
	-- Thick, low clouds over everything.
	local terrain = workspace.Terrain
	clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Parent = terrain
end

------------------------------------------------------------------------------
-- Lights: helpers
------------------------------------------------------------------------------

-- The light object of a tagged part (its child named "Light"), if any.
local function lightOf(part: Instance): Light?
	local light = part:FindFirstChild("Light")
	if light and light:IsA("Light") then
		return light
	end
	return nil
end

-- The first time we touch a part, we write down how the city built it (as attributes), so we
-- can always put it back exactly.
local function remember(part: BasePart)
	if part:GetAttribute("BuiltColor") == nil then
		part:SetAttribute("BuiltColor", part.Color)
		part:SetAttribute("BuiltMaterial", part.Material.Name)
		part:SetAttribute("BuiltReflectance", part.Reflectance)
		part:SetAttribute("BuiltTransparency", part.Transparency)
	end
	local light = lightOf(part)
	if light and light:GetAttribute("BuiltBrightness") == nil then
		light:SetAttribute("BuiltBrightness", light.Brightness)
		light:SetAttribute("BuiltColor", light.Color)
	end
end

local function builtColor(part: Instance): Color3
	local value = part:GetAttribute("BuiltColor")
	return if typeof(value) == "Color3" then value else Color3.new(1, 1, 1)
end

local function builtNumber(part: Instance, name: string, default: number): number
	local value = part:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function builtMaterial(part: Instance): Enum.Material
	local name = part:GetAttribute("BuiltMaterial")
	if typeof(name) == "string" then
		local ok, material = pcall(function()
			return (Enum.Material :: any)[name]
		end)
		if ok and material then
			return material
		end
	end
	return Enum.Material.SmoothPlastic
end

-- Puts a light back to the brightness / colour the city gave it.
local function restoreLight(light: Light)
	light.Brightness = builtNumber(light, "BuiltBrightness", light.Brightness)
	local color = light:GetAttribute("BuiltColor")
	if typeof(color) == "Color3" then
		light.Color = color
	end
end

-- Is this part powered right now? (No during a power cut, nor before the restore wave
-- reaches it. Parts with OwnPower = true always are.)
local function powered(part: Instance): boolean
	if part:GetAttribute("OwnPower") == true then
		return true
	end
	return powerOn and not waitingPower[part]
end

local function tagged(tag: string): { BasePart }
	local parts = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			table.insert(parts, instance)
		end
	end
	return parts
end

------------------------------------------------------------------------------
-- Lights: each kind
------------------------------------------------------------------------------

-- STREET LAMPS ---------------------------------------------------------------

local function lampShouldBeOn(head: BasePart): boolean
	return lightsNight and powered(head) and head:GetAttribute("Dead") ~= true
end

local function setLamp(head: BasePart, on: boolean)
	remember(head)
	local light = lightOf(head)
	if on then
		head.Material = Enum.Material.Neon
		head.Color = builtColor(head)
		if light then
			restoreLight(light)
			light.Enabled = true
		end
	else
		head.Material = Enum.Material.SmoothPlastic
		head.Color = LAMP_OFF_COLOR
		if light then
			light.Enabled = false
		end
	end
end

-- A lamp with Flicker = true: every 1 to 6 s it cuts out for a split second (sometimes 3 times
-- in a row). Runs as long as the lamp exists.
local function flickerLamp(head: BasePart)
	while head.Parent do
		task.wait(random:NextNumber(1, 6))
		if lampShouldBeOn(head) then
			local cuts = if random:NextNumber() < 0.3 then 3 else 1
			for _ = 1, cuts do
				setLamp(head, false)
				task.wait(random:NextNumber(0.05, 0.25))
				setLamp(head, lampShouldBeOn(head))
				task.wait(random:NextNumber(0.04, 0.12))
			end
		end
	end
end

-- NEON SIGNS -----------------------------------------------------------------

-- "off", "day" (dim) or "night" (full).
local function neonLevel(sign: BasePart): string
	if not powered(sign) then
		return "off"
	end
	if sign:GetAttribute("Flicker") == "blink" and not blinkOn then
		return "off"
	end
	return if lightsNight then "night" else "day"
end

local function setNeon(sign: BasePart, level: string)
	remember(sign)
	local surface = sign:FindFirstChild("Sign")
	if surface and surface:IsA("SurfaceGui") then
		if level == "off" then
			-- Unlit text: lit by the scene like paint (so almost black at night).
			surface.LightInfluence = 1
			surface.Brightness = 1
		else
			surface.LightInfluence = 0
			surface.Brightness = if level == "night" then 2.5 else 0.7
		end
	end
	-- Small lamps made of Neon parts (signals, aircraft light): the glass goes dark when off.
	if sign:GetAttribute("BuiltMaterial") == "Neon" then
		sign.Material = if level == "off" then Enum.Material.SmoothPlastic else Enum.Material.Neon
		sign.Color = if level == "off" then scale(builtColor(sign), 0.35) else builtColor(sign)
	end
	local light = lightOf(sign)
	if light then
		light.Enabled = level == "night"
	end
end

-- A neon with Flicker = "random": stutters every 2 to 8 s.
local function flickerNeon(sign: BasePart)
	while sign.Parent do
		task.wait(random:NextNumber(2, 8))
		if neonLevel(sign) ~= "off" then
			for _ = 1, random:NextInteger(2, 4) do
				setNeon(sign, "off")
				task.wait(random:NextNumber(0.04, 0.15))
				setNeon(sign, neonLevel(sign))
				task.wait(random:NextNumber(0.05, 0.2))
			end
		end
	end
end

-- WINDOWS --------------------------------------------------------------------

-- "off", "dim" (afternoon lamp behind net curtains), "on" or "candle" (power cut).
local function windowLevel(window: BasePart): string
	if not powered(window) then
		return if candles[window] then "candle" else "off"
	end
	if lightsNight then
		return if litWindows[window] then "on" else "off"
	end
	return if window:GetAttribute("Day") == true then "dim" else "off"
end

local function setWindow(window: BasePart, level: string)
	remember(window)
	window:SetAttribute("LitLevel", level)
	if level == "off" then
		window.Material = builtMaterial(window)
		window.Color = builtColor(window)
		window.Reflectance = builtNumber(window, "BuiltReflectance", 0)
		window.Transparency = builtNumber(window, "BuiltTransparency", 0)
		return
	end
	local kind = window:GetAttribute("Kind")
	local color = WINDOW_COLORS[if typeof(kind) == "string" then kind else "warm"]
		or WINDOW_COLORS.warm
	if level == "candle" then
		color = WINDOW_COLORS.warm
	end
	-- Attribute Glow (0..1, optional): a dimmer glow, e.g. the TV screens of the emote shop
	-- that bloomed to white-blue right in front of the players.
	local glow = window:GetAttribute("Glow")
	if typeof(glow) == "number" then
		color = Color3.new(color.R * glow, color.G * glow, color.B * glow)
	end
	window.Material = Enum.Material.Neon
	window.Color = color
	window.Reflectance = 0
	window.Transparency = if level == "on" then 0.25 elseif level == "dim" then 0.5 else 0.6
end

-- Picks tonight's lit windows: the Day ones, plus about 35 % of the others.
local function pickLitWindows()
	table.clear(litWindows)
	for _, window in tagged("CityWindowLit") do
		if window:GetAttribute("Day") == true or random:NextNumber() < LIT_WINDOW_SHARE then
			litWindows[window] = true
		end
	end
end

-- A candle in a dark window during a power cut: its glow wavers slowly.
local function candleLoop(window: BasePart)
	while candles[window] and window.Parent do
		if window:GetAttribute("LitLevel") == "candle" then
			window.Transparency = random:NextNumber(0.55, 0.75)
		end
		task.wait(random:NextNumber(0.2, 0.45))
	end
end

-- WALL LIGHTS, SHOPS, EMERGENCY, FIRE --------------------------------------------

-- A Neon part with an optional child light, simply on or off.
local function setGlow(part: BasePart, on: boolean)
	remember(part)
	if builtMaterial(part) == Enum.Material.Neon then
		part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Color = if on then builtColor(part) else scale(builtColor(part), 0.4)
	end
	local light = lightOf(part)
	if light then
		light.Enabled = on
	end
end

-- The shop interior lights are on the "Shelf" parts next to the ceiling lights (no tag):
-- found once the city is built.
local shelfLights: { Light } = {}

local function findShelfLights()
	table.clear(shelfLights)
	local city = workspace:FindFirstChild("City")
	if city == nil then
		return
	end
	for _, descendant in city:GetDescendants() do
		if
			descendant:IsA("PointLight")
			and descendant.Parent
			and descendant.Parent.Name == "Shelf"
		then
			table.insert(shelfLights, descendant)
		end
	end
end

local function setEmergency(part: BasePart, on: boolean)
	remember(part)
	part.Material = if on then Enum.Material.Neon else builtMaterial(part)
	part.Color = if on then EMERGENCY_COLOR else builtColor(part)
	local light = lightOf(part)
	if light then
		light.Enabled = on
	end
end

-- Burn barrels: the glow wavers like a fire, brighter at night.
local function fireLoop(embers: BasePart)
	remember(embers)
	local light = lightOf(embers)
	if light == nil then
		return
	end
	while embers.Parent do
		local strength = if lightsNight then 1 else 0.6
		light.Brightness = random:NextNumber(1.2, 2.0) * strength
		task.wait(random:NextNumber(0.08, 0.15))
	end
end

-- Applies the right state to one tagged part, by its tag.
local function applyOne(part: BasePart, tag: string)
	if tag == "CityLamp" then
		setLamp(part, lampShouldBeOn(part))
	elseif tag == "CityNeon" then
		setNeon(part, neonLevel(part))
	elseif tag == "CityWindowLit" then
		setWindow(part, windowLevel(part))
	elseif tag == "CityBulkhead" then
		setGlow(part, lightsNight and powered(part))
	elseif tag == "CityShopLight" then
		setGlow(part, powered(part))
	elseif tag == "CityEmergency" then
		setEmergency(part, not powerOn)
	end
end

local LIGHT_TAGS =
	{ "CityLamp", "CityNeon", "CityWindowLit", "CityBulkhead", "CityShopLight", "CityEmergency" }

-- Puts every light in the state it should be in. Windows switch one by one at random over
-- `windowSpread` seconds (a city doesn't light up all at once).
local function refreshLights(windowSpread: number)
	for _, tag in LIGHT_TAGS do
		for _, part in tagged(tag) do
			if tag == "CityWindowLit" and windowSpread > 0 then
				if part:GetAttribute("LitLevel") ~= windowLevel(part) then
					task.delay(random:NextNumber(0, windowSpread), function()
						setWindow(part, windowLevel(part))
					end)
				end
			else
				applyOne(part, tag)
			end
		end
	end
	for _, light in shelfLights do
		light.Enabled = powerOn
	end
end

------------------------------------------------------------------------------
-- Wet things: puddles, slabs, drips, steam, gutters
------------------------------------------------------------------------------

-- Gutter shoes that spout water in the rain (a few, picked the first time it rains).
local MAX_GUTTER_SPOUTS = 8
local gutterSpouts: { ParticleEmitter } = {}

local function makeGutterSpouts()
	local gutters = tagged("CityGutter")
	for _ = 1, math.min(MAX_GUTTER_SPOUTS, #gutters) do
		local shoe = table.remove(gutters, random:NextInteger(1, #gutters)) :: BasePart
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Spout"
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(170, 180, 190))
		emitter.Transparency = NumberSequence.new(0.4)
		emitter.Size = NumberSequence.new(0.18)
		emitter.Squash = NumberSequence.new(2)
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.Rate = 20
		emitter.Lifetime = NumberRange.new(0.5, 0.7)
		emitter.Speed = NumberRange.new(4, 6)
		emitter.SpreadAngle = Vector2.new(10, 10)
		emitter.Acceleration = Vector3.new(0, -60, 0)
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Enabled = false
		emitter.Parent = shoe
		table.insert(gutterSpouts, emitter)
	end
end

local function applyWet(seconds: number)
	local raining = weather == "Rain" or weather == "Storm"
	for _, puddle in tagged("CityPuddle") do
		local transparency: number, reflectance: number
		-- (At night there is little to reflect: a puddle that is too opaque and shiny reads as a
		-- black hole in the road. They stay see-through.)
		if raining then
			transparency = if targetNight then 0.35 else 0.25
			reflectance = if targetNight then 0.4 else 0.35
		elseif puddle:GetAttribute("RainOnly") == true then
			transparency, reflectance = 1, 0
		else
			-- The ground is still damp from the last rain.
			transparency = if targetNight then 0.55 else 0.5
			reflectance = 0.25
		end
		tweenTo(puddle, seconds, { Transparency = transparency, Reflectance = reflectance })
	end
	for _, slab in tagged("CityWetSurface") do
		remember(slab)
		local dry = builtNumber(slab, "BuiltReflectance", 0)
		-- Damp at night (+0.03), wet in the rain (+0.08), dry in the afternoon.
		local wet = if raining then 0.08 elseif targetNight then 0.03 else 0
		tweenTo(slab, seconds, { Reflectance = dry + wet })
	end
	for _, drip in tagged("CityDrip") do
		local emitter = drip:FindFirstChild("FX")
		if emitter and emitter:IsA("ParticleEmitter") then
			emitter.Enabled = raining
		end
	end
	for _, vent in tagged("CitySteam") do
		local emitter = vent:FindFirstChild("FX")
		if emitter and emitter:IsA("ParticleEmitter") then
			local baseRate = builtNumber(vent, "BaseRate", emitter.Rate)
			emitter.Rate = baseRate * (if raining then 2 elseif weather == "Fog" then 0.5 else 1)
		end
	end
	if raining and #gutterSpouts == 0 then
		makeGutterSpouts()
	end
	for _, emitter in gutterSpouts do
		emitter.Enabled = raining
	end
end

------------------------------------------------------------------------------
-- The cycle
------------------------------------------------------------------------------

-- Moves the whole look to night (true) or afternoon (false) over `seconds`.
local function goTo(night: boolean, seconds: number)
	targetNight = night
	transitionEndsAt = os.clock() + seconds
	applyLook(seconds, true)
	applyWet(seconds)
	-- Lamps, neons, windows: they switch halfway through the transition.
	task.delay(seconds / 2, function()
		lightsNight = night
		if night then
			pickLitWindows()
		end
		refreshLights(seconds / 2)
	end)
end

local function setPhase(name: string, seconds: number)
	phase = name
	phaseEndsAt = os.clock() + seconds
	if name == "Night" then
		nightNumber += 1
	end
end

-- A newly built (or streamed) tagged part gets the current state at once; the flickering
-- ones get their own little loop.
local function watchTag(tag: string)
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance: Instance)
		if not instance:IsA("BasePart") then
			return
		end
		local part = instance :: BasePart
		if tag == "CityWindowLit" and lightsNight and random:NextNumber() < LIT_WINDOW_SHARE then
			litWindows[part] = true
		end
		applyOne(part, tag)
		if tag == "CityLamp" and part:GetAttribute("Flicker") == true then
			task.spawn(flickerLamp, part)
		elseif tag == "CityNeon" and part:GetAttribute("Flicker") == "random" then
			task.spawn(flickerNeon, part)
		end
	end)
end

-- Same as watchTag, for the parts that already exist.
local function startExisting()
	for _, head in tagged("CityLamp") do
		if head:GetAttribute("Flicker") == true then
			task.spawn(flickerLamp, head)
		end
	end
	for _, sign in tagged("CityNeon") do
		if sign:GetAttribute("Flicker") == "random" then
			task.spawn(flickerNeon, sign)
		end
	end
end

-- "blink" neons (aircraft light, signals, the taxi's hazards): 1 s on, 1 s off, forever.
local function blinkLoop()
	while true do
		task.wait(1)
		blinkOn = not blinkOn
		for _, sign in tagged("CityNeon") do
			if sign:GetAttribute("Flicker") == "blink" then
				setNeon(sign, neonLevel(sign))
			end
		end
	end
end

local function fires()
	for _, embers in tagged("CityFireEmbers") do
		task.spawn(fireLoop, embers)
	end
	CollectionService:GetInstanceAddedSignal("CityFireEmbers"):Connect(function(instance: Instance)
		if instance:IsA("BasePart") then
			task.spawn(fireLoop, instance :: BasePart)
		end
	end)
end

function Ambience.init()
	setupEffects()
	for _, tag in LIGHT_TAGS do
		watchTag(tag)
	end
end

-- Warns (once, in the output) when the place does not use the Future lighting technology.
-- Reading Lighting.Technology can fail in some contexts: then we stay silent.
local function checkTechnology()
	local ok, technology = pcall(function()
		return Lighting.Technology
	end)
	if ok and technology ~= Enum.Technology.Future then
		warn(
			`[Ambience] Lighting.Technology is {technology.Name}, not Future: the city's lamps and`
				.. " neons will look flat. Set it in Lighting's properties (or sync default.project.json)."
		)
	end
end

function Ambience.start()
	checkTechnology()
	-- Start in the afternoon right away.
	setPhase("Day", DAY_TIME)
	goTo(false, 0.1)
	startExisting()
	fires()
	task.spawn(blinkLoop)
	-- The city is built in the background (Server/Systems/City): once it is done, set every
	-- puddle / slab / light to the current phase and find the shop lights.
	task.spawn(function()
		local city = workspace:WaitForChild("City", 60)
		if city and city:GetAttribute("Built") == false then
			city:GetAttributeChangedSignal("Built"):Wait()
		end
		findShelfLights()
		applyWet(0.1)
		refreshLights(0)
	end)
	task.spawn(function()
		while true do
			task.wait(DAY_TIME)
			setPhase("Dusk", TRANSITION)
			goTo(true, TRANSITION)
			task.wait(TRANSITION)
			setPhase("Night", NIGHT_TIME)
			task.wait(NIGHT_TIME)
			setPhase("Dawn", TRANSITION)
			goTo(false, TRANSITION)
			task.wait(TRANSITION)
			setPhase("Day", DAY_TIME)
		end
	end)
end

------------------------------------------------------------------------------
-- Used by Server/Systems/Weather
------------------------------------------------------------------------------

-- "Day", "Dusk", "Night" or "Dawn", plus the seconds left in that phase.
function Ambience.getPhase(): (string, number)
	return phase, math.max(0, phaseEndsAt - os.clock())
end

-- 1 for the first night, 2 for the second... (0 before the first night).
function Ambience.getNightNumber(): number
	return nightNumber
end

-- Changes the weather layer ("Clear", "Rain", "Storm" or "Fog") over `seconds`.
function Ambience.setWeather(kind: string, seconds: number)
	weather = kind
	applyLook(seconds, false)
	applyWet(seconds)
end

-- POWER CUT, step 1: every powered light toggles 3 to 6 times at random for `seconds`,
-- then the power goes (step 2). Yields.
function Ambience.powerFlicker(seconds: number)
	local parts: { { part: BasePart, tag: string } } = {}
	for _, tag in { "CityLamp", "CityNeon", "CityWindowLit", "CityBulkhead", "CityShopLight" } do
		for _, part in tagged(tag) do
			if part:GetAttribute("OwnPower") ~= true then
				table.insert(parts, { part = part, tag = tag })
			end
		end
	end
	for _, entry in parts do
		task.spawn(function()
			local deadline = os.clock() + seconds
			for count = 1, random:NextInteger(3, 6) * 2 do
				if os.clock() > deadline then
					break
				end
				-- Odd = off, even = back to normal.
				if count % 2 == 1 then
					if entry.tag == "CityLamp" then
						setLamp(entry.part, false)
					elseif entry.tag == "CityNeon" then
						setNeon(entry.part, "off")
					elseif entry.tag == "CityWindowLit" then
						setWindow(entry.part, "off")
					else
						setGlow(entry.part, false)
					end
				else
					applyOne(entry.part, entry.tag)
				end
				task.wait(random:NextNumber(0.04, 0.25))
			end
		end)
	end
	task.wait(seconds)
end

-- POWER CUT, step 2: everything on the grid goes dark, the red exit lights come on, a few
-- windows show a candle.
function Ambience.cutPower()
	powerOn = false
	table.clear(candles)
	local lit = {}
	for window in litWindows do
		table.insert(lit, window)
	end
	for _ = 1, math.min(3, #lit) do
		local window = table.remove(lit, random:NextInteger(1, #lit)) :: BasePart
		candles[window] = true
		task.spawn(candleLoop, window)
	end
	refreshLights(0)
	applyLook(1.5, false)
end

-- POWER CUT, step 3: the power comes back as a wave spreading from `origin` (the substation)
-- at `speed` studs per second. Sodium lamps come back red and dim and warm up to orange over
-- `warmup` seconds, neons stutter once, windows come back within 4 s. Yields until done.
function Ambience.restorePower(origin: Vector3, speed: number, warmup: number)
	local parts: { { part: BasePart, tag: string } } = {}
	local longest = 0
	for _, tag in LIGHT_TAGS do
		for _, part in tagged(tag) do
			waitingPower[part] = true
			table.insert(parts, { part = part, tag = tag })
		end
	end
	powerOn = true
	table.clear(candles)
	applyLook(warmup, false)
	for _, light in shelfLights do
		light.Enabled = true
	end
	for _, entry in parts do
		local part = entry.part
		local reachedIn = (part.Position - origin).Magnitude / speed
		if entry.tag == "CityWindowLit" then
			reachedIn += random:NextNumber(0, 4)
		end
		longest = math.max(longest, reachedIn)
		task.delay(reachedIn, function()
			waitingPower[part] = nil
			if entry.tag == "CityLamp" and lampShouldBeOn(part) then
				setLamp(part, true)
				local light = lightOf(part)
				-- Sodium lamps (orange) warm up: red and dim first.
				if light and light.Color.R - light.Color.G > 0.2 then
					local fullColor, fullBrightness = light.Color, light.Brightness
					light.Color = SODIUM_WARMUP_COLOR
					light.Brightness = 0.4
					part.Color = scale(SODIUM_WARMUP_COLOR, 0.8)
					tweenTo(light, warmup, { Color = fullColor, Brightness = fullBrightness })
					tweenTo(part, warmup, { Color = builtColor(part) })
				end
			elseif entry.tag == "CityNeon" and neonLevel(part) ~= "off" then
				-- One stutter, then on.
				setNeon(part, neonLevel(part))
				task.wait(0.08)
				setNeon(part, "off")
				task.wait(0.12)
				setNeon(part, neonLevel(part))
			else
				applyOne(part, entry.tag)
			end
		end)
	end
	-- Wait for the last lamp to finish warming up, then make sure everything is right.
	task.wait(longest + warmup + 0.5)
	table.clear(waitingPower)
	refreshLights(0)
end

return Ambience
