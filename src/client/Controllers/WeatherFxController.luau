--!strict
-- WeatherFxController: the small touches that make the weather events feel real.
--
-- WeatherController draws the big things (the rain around you, the lightning, the notice);
-- this one adds the details, all on THIS screen only and cheap (a few particle emitters that
-- are switched on and off, a handful of screen frames):
--
--   RAIN / THUNDERSTORM
--     • WATER ON THE LENS (Client/UI/LensRain): pictures of real drops land now and then,
--       sit, grow, merge, and the big ones run down with a wet trail; a fine mist at the
--       edges in heavy rain. Only when the camera is OUTSIDE in the open (not under a roof
--       or an awning, not inside the bar or a shop); it dries in a few seconds under cover
--       and is wiped at once in the park or a duel. Never much in the middle of the screen.
--       Needs the pictures uploaded (Config.Weather.SCREEN_RAIN_IMAGES): until then, none.
--     • RIPPLES in the puddles near you (tagged CityPuddle): small rings that open and fade.
--     • SPLASHES on your own head and shoulders while you stand in the rain.
--     (the drips under the roof edges, CityDrip, are switched on by the server: Ambience)
--   FOG
--     • a LOW FOG that drifts slowly along the ground around you;
--     • a soft HALO around every lit street lamp near you.
--     (the muffled city sounds are done by CityAudioController)
--   POWER CUT
--     • while the lights stutter (server: Ambience.powerFlicker), the grid BUZZES (PowerBuzz),
--       cut short when the transformer blows;
--     • the transformer at the substation (Config.Weather.SUBSTATION) BLOWS just before the
--       dark: a burst of sparks, smoke, a blue-white flash, and the TransformerBlow sound;
--     • while the power is out, the red emergency lights PULSE slowly.
--
--   STUTTERING STREET LAMPS (any weather, at night)
--     • a lamp with Flicker = true gives a short, faint crackle (PowerBuzz) when it cuts out,
--       if you are close.
--
-- The park is always sunny: nothing of this happens in it (ParkAtmosphereController.blend()).
-- In a duel you are in an arena: no screen drops there either.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local CityZones = require(ReplicatedStorage.Shared.Util.CityZones)
local ParkAtmosphereController = require(script.Parent.ParkAtmosphereController)
local LensRain = require(script.Parent.Parent.UI.LensRain)
local SoundController = require(script.Parent.SoundController)
local WeatherController = require(script.Parent.WeatherController)

local W = Config.Weather

local WeatherFxController = {}

local player = Players.LocalPlayer
local random = Random.new()

-- Built-in Roblox textures (always there, nothing to upload).
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKS = "rbxasset://textures/particles/sparkles_main.dds"
-- The ring of the default Explosion: a perfect ripple.
local RING = "rbxasset://textures/particles/explosion01_shockwave_main.dds"

------------------------------------------------------------------------------
-- Tuning
------------------------------------------------------------------------------

-- Puddle ripples: only the puddles this close to the camera, rings per second per puddle
-- (a big puddle gets more), checked this often.
local RIPPLE_RANGE = 60
local RIPPLE_RATE = 3
local RIPPLE_CHECK_EVERY = 1

-- Splashes on your head and shoulders (specks per second at full rain).
local BODY_SPLASH_RATE = 9

-- Fog: the drifting ground fog (puffs per second at full fog, the square it covers), and the
-- lamp halos (only the lamps this close).
local GROUND_FOG_RATE = 9
local GROUND_FOG_AREA = 150
local HALO_RANGE = 150
local HALO_CHECK_EVERY = 1

-- Power cut: the emergency lights' pulse (cycles per second, dimmest share of the light).
local PULSE_SPEED = 0.7
local PULSE_LOW = 0.35
-- The transformer: height of the burst above the substation's road point.
local TRANSFORMER_HEIGHT = 7

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

-- An invisible, anchored part nothing touches or hits, in the camera (only this screen).
local function invisiblePart(name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = workspace.CurrentCamera
	return part
end

-- The street's light of a tagged lamp / exit light (its "Light" child), or nil.
local function lightOf(part: Instance): Light?
	local light = part:FindFirstChild("Light")
	if light and light:IsA("Light") then
		return light
	end
	return nil
end

local function cameraPosition(): Vector3?
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else nil
end

------------------------------------------------------------------------------
-- Rain on the lens (the drops themselves: Client/UI/LensRain)
------------------------------------------------------------------------------

local LENS_CHECK_EVERY = 0.25
local nextLensCheck = 0
-- The rain falling on the lens (0 = none: under a roof, indoors...) and "wipe it all now".
local lensRain = 0
local lensClear = false

local function updateLens(dt: number, intensity: number, storm: boolean, park: number)
	if not LensRain.available() then
		return -- (pictures not uploaded: nothing on the screen, see docs/RAIN_FR.md)
	end
	local now = os.clock()
	if now >= nextLensCheck then
		nextLensCheck = now + LENS_CHECK_EVERY
		local _, _, covered, indoors = WeatherController.rainState()
		-- the park is always sunny and a duel is an arena: wiped at once
		lensClear = player:GetAttribute("InDuel") == true or ParkAtmosphereController.inPark()
		local position = cameraPosition()
		local open = not covered
			and not indoors
			and position ~= nil
			and CityZones.musicZoneAt(position) == nil
		lensRain = if open and not lensClear then intensity * (1 - park) else 0
	end
	LensRain.step(dt, lensRain, storm, lensClear)
end

------------------------------------------------------------------------------
-- Puddle ripples and body splashes
------------------------------------------------------------------------------

local rippleEmitters: { [BasePart]: ParticleEmitter } = {}
local nextRippleCheck = 0

local function rippleEmitterFor(puddle: BasePart): ParticleEmitter
	local existing = rippleEmitters[puddle]
	if existing and existing.Parent then
		return existing
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RainRipples"
	emitter.Texture = RING
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.EmissionDirection = Enum.NormalId.Top
	-- moving (very slowly) straight up and drawn PERPENDICULAR to that: lying flat on the water
	emitter.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	emitter.Speed = NumberRange.new(0.02)
	emitter.Lifetime = NumberRange.new(0.5, 0.85)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1.3),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 210, 220))
	emitter.LightInfluence = 1
	emitter.ZOffset = 0.05
	emitter.Rate = 0
	emitter.Parent = puddle
	rippleEmitters[puddle] = emitter
	return emitter
end

-- Every second: ripples on the puddles near the camera, none on the others.
local function updateRipples(rain: number, storm: boolean)
	local position = cameraPosition()
	for _, instance in CollectionService:GetTagged("CityPuddle") do
		if not instance:IsA("BasePart") then
			continue
		end
		local puddle = instance :: BasePart
		local near = position ~= nil and (puddle.Position - position).Magnitude < RIPPLE_RANGE
		if rain > 0.05 and near then
			local area = puddle.Size.X * puddle.Size.Z
			local rate = RIPPLE_RATE * math.clamp(area / 12, 0.5, 4) * rain
			rippleEmitterFor(puddle).Rate = rate * (if storm then 1.8 else 1)
		else
			local emitter = rippleEmitters[puddle]
			if emitter then
				emitter.Rate = 0
			end
		end
	end
	-- (forget the puddles that are gone: streamed out, a rebuilt city)
	for puddle, emitter in rippleEmitters do
		if puddle.Parent == nil or emitter.Parent == nil then
			rippleEmitters[puddle] = nil
		end
	end
end

-- Tiny specks bouncing off your head and shoulders.
local SPLASH_PARTS = { "Head", "Torso" }
local bodySplashes: { ParticleEmitter } = {}
local splashCharacter: Model? = nil

local function makeBodySplash(part: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RainOnBody"
	emitter.Texture = SPARKS
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.15, 0.28)
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Acceleration = Vector3.new(0, -45, 0)
	emitter.Size = NumberSequence.new(0.12, 0)
	emitter.Color = ColorSequence.new(Color3.fromRGB(190, 200, 210))
	emitter.Transparency = NumberSequence.new(0.35)
	emitter.LightInfluence = 0.8
	emitter.Parent = part
	return emitter
end

local function updateBodySplashes(rate: number)
	local character = player.Character
	-- (a new character, or one whose Head / Torso were not there yet: build again)
	if character ~= splashCharacter or (character ~= nil and #bodySplashes == 0) then
		for _, emitter in bodySplashes do
			emitter:Destroy()
		end
		table.clear(bodySplashes)
		splashCharacter = character
		if character then
			for _, name in SPLASH_PARTS do
				local part = character:FindFirstChild(name)
				if part and part:IsA("BasePart") then
					table.insert(bodySplashes, makeBodySplash(part))
				end
			end
		end
	end
	-- (first person: your head is hidden and the camera sits in it: the splashes of the head
	-- AND the shoulders would spray into the lens, so they all stop)
	local head = if character then character:FindFirstChild("Head") else nil
	local firstPerson = head ~= nil
		and head:IsA("BasePart")
		and (head :: BasePart).LocalTransparencyModifier > 0.5
	for _, emitter in bodySplashes do
		emitter.Rate = if firstPerson then 0 else rate
	end
end

------------------------------------------------------------------------------
-- Fog: ground fog and lamp halos
------------------------------------------------------------------------------

local groundFogBox: Part
local groundFog: ParticleEmitter
local haloEmitters: { [BasePart]: ParticleEmitter } = {}
local nextHaloCheck = 0
local fogFloorY = 0
local nextFogProbe = 0
-- (refreshed with the floor probe, twice a second: CityZones builds a list on every call)
local fogInside = false
-- True while puffs may still be floating around (cleared at once when you walk into the park)
local fogHasPuffs = false

local function buildGroundFog()
	groundFogBox =
		invisiblePart("WeatherGroundFog", Vector3.new(GROUND_FOG_AREA, 1, GROUND_FOG_AREA))
	groundFog = Instance.new("ParticleEmitter")
	groundFog.Name = "GroundFog"
	groundFog.Texture = SMOKE
	groundFog.Shape = Enum.ParticleEmitterShape.Box
	groundFog.EmissionDirection = Enum.NormalId.Top
	groundFog.Rate = 0
	groundFog.Lifetime = NumberRange.new(9, 14)
	groundFog.Speed = NumberRange.new(0.2, 0.6)
	groundFog.SpreadAngle = Vector2.new(30, 30)
	-- a slow drift along the street
	groundFog.Acceleration = Vector3.new(0.35, 0, 0.15)
	groundFog.Rotation = NumberRange.new(0, 360)
	groundFog.RotSpeed = NumberRange.new(-6, 6)
	groundFog.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 12),
		NumberSequenceKeypoint.new(1, 22),
	})
	groundFog.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.86),
		NumberSequenceKeypoint.new(0.7, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	groundFog.Color = ColorSequence.new(Color3.fromRGB(176, 180, 186))
	groundFog.LightInfluence = 1
	groundFog.Parent = groundFogBox
end

local function haloFor(lamp: BasePart, color: Color3): ParticleEmitter
	local existing = haloEmitters[lamp]
	if existing and existing.Parent then
		existing.Color = ColorSequence.new(color)
		return existing
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "FogHalo"
	emitter.Texture = SMOKE
	emitter.LockedToPart = true
	emitter.Speed = NumberRange.new(0)
	emitter.Rate = 1.5
	emitter.Lifetime = NumberRange.new(2.5, 3.5)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-8, 8)
	emitter.Size = NumberSequence.new(7)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Enabled = false
	emitter.Parent = lamp
	haloEmitters[lamp] = emitter
	return emitter
end

-- Every second while foggy: a halo on each lit lamp near you; off everywhere else.
local function updateHalos(fog: number)
	local position = cameraPosition()
	if fog > 0.15 and position then
		for _, instance in CollectionService:GetTagged("CityLamp") do
			if not instance:IsA("BasePart") then
				continue
			end
			local lamp = instance :: BasePart
			local light = lightOf(lamp)
			local lit = if light then light.Enabled else lamp.Material == Enum.Material.Neon
			local near = (lamp.Position - position).Magnitude < HALO_RANGE
			if lit and near then
				haloFor(lamp, if light then light.Color else lamp.Color).Enabled = true
			elseif haloEmitters[lamp] then
				haloEmitters[lamp].Enabled = false
			end
		end
	else
		for _, emitter in haloEmitters do
			emitter.Enabled = false
		end
	end
	for lamp, emitter in haloEmitters do
		if lamp.Parent == nil or emitter.Parent == nil then
			haloEmitters[lamp] = nil
		end
	end
end

local function updateGroundFog(fog: number, park: number)
	local position = cameraPosition()
	if position == nil or fog <= 0.02 then
		groundFog.Rate = 0
		-- walking into the (always sunny) park: the puffs already out would hang there for
		-- up to 14 s, so they are wiped at once
		if fogHasPuffs and park > 0.5 then
			fogHasPuffs = false
			groundFog:Clear()
		end
		return
	end
	if groundFogBox.Parent ~= workspace.CurrentCamera then
		groundFogBox.Parent = workspace.CurrentCamera
	end
	local now = os.clock()
	if now >= nextFogProbe then
		nextFogProbe = now + 0.5
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = { workspace.CurrentCamera :: Camera }
		if player.Character then
			table.insert(ignore, player.Character)
		end
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(position, Vector3.new(0, -80, 0), params)
		fogFloorY = if hit then hit.Position.Y else position.Y - 6
		-- not inside the bar or a shop (the box would push fog through the walls)
		fogInside = CityZones.musicZoneAt(position) ~= nil
	end
	groundFogBox.CFrame = CFrame.new(position.X, fogFloorY + 1, position.Z)
	groundFog.Rate = if fogInside then 0 else GROUND_FOG_RATE * fog
	fogHasPuffs = true
end

------------------------------------------------------------------------------
-- Power cut: the transformer and the emergency lights
------------------------------------------------------------------------------

-- The transformer blowing: sparks, smoke, a cold flash, a bang.
local function transformerBlow(strength: number)
	local at = W.SUBSTATION + Vector3.new(0, TRANSFORMER_HEIGHT, 0)
	local holder = invisiblePart("TransformerBlow", Vector3.one)
	holder.Position = at
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARKS
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.4, 1)
	sparks.Speed = NumberRange.new(18, 42)
	sparks.SpreadAngle = Vector2.new(80, 80)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Acceleration = Vector3.new(0, -70, 0)
	sparks.Size = NumberSequence.new(0.35, 0)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 236, 180), Color3.fromRGB(255, 140, 40))
	sparks.LightEmission = 1
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.Squash = NumberSequence.new(1.5)
	sparks.Parent = holder
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE
	smoke.Rate = 0
	smoke.Lifetime = NumberRange.new(2, 3.5)
	smoke.Speed = NumberRange.new(2, 5)
	smoke.SpreadAngle = Vector2.new(40, 40)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Size = NumberSequence.new(3, 9)
	smoke.Transparency = NumberSequence.new(0.6, 1)
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 70, 74))
	smoke.Parent = holder
	local flashLight = Instance.new("PointLight")
	flashLight.Color = Color3.fromRGB(190, 215, 255)
	flashLight.Range = 45
	flashLight.Brightness = 0
	flashLight.Shadows = false
	flashLight.Parent = holder
	sparks:Emit(math.floor(70 * strength))
	smoke:Emit(math.floor(8 * strength))
	SoundController.playAt("TransformerBlow", at, 300)
	task.spawn(function()
		-- three stutters of blue-white light, the arc
		for _, brightness in { 9, 1, 6, 0.5, 4, 0 } do
			flashLight.Brightness = brightness * strength
			task.wait(0.05)
		end
		task.wait(3.5)
		holder:Destroy()
	end)
end

-- The red exit lights pulse slowly while the power is out (their brightness only: the
-- server switches them on and off).
local pulseLights: { [Light]: number } = {} -- light → its normal brightness
-- (the lights are listed ONCE when the dark starts, not looked up every frame)
local pulsingNow = false

local function updateEmergencyPulse(pulsing: boolean)
	if pulsing then
		if not pulsingNow then
			pulsingNow = true
			for _, instance in CollectionService:GetTagged("CityEmergency") do
				local light = lightOf(instance)
				if light then
					pulseLights[light] = light.Brightness
				end
			end
		end
		local wave = 0.5 + 0.5 * math.sin(os.clock() * math.pi * 2 * PULSE_SPEED)
		local level = PULSE_LOW + (1 - PULSE_LOW) * wave
		for light, normal in pulseLights do
			light.Brightness = normal * level
		end
	elseif pulsingNow then
		pulsingNow = false
		for light, normal in pulseLights do
			light.Brightness = normal
		end
		table.clear(pulseLights)
	end
end

-- Lowers a sound to silence over `seconds`, then stops and removes it.
local function fadeOut(sound: Sound, seconds: number)
	local tween = TweenService:Create(sound, TweenInfo.new(seconds), { Volume = 0 })
	tween.Completed:Connect(function()
		sound:Destroy()
	end)
	tween:Play()
end

-- The street lamps that stutter (attribute Flicker, server: Ambience) give a short, faint
-- electric crackle when they cut out, if you are close (the PowerBuzz sound, very quiet).
-- Each lamp near the camera is watched (its light's Enabled), the far ones are forgotten.
local CRACKLE_RANGE = 26 -- studs: heard only this close
local CRACKLE_WATCH_RANGE = 60
local CRACKLE_VOLUME = 0.3 -- share of PowerBuzz's volume
local CRACKLE_LENGTH = NumberRange.new(0.3, 0.7) -- seconds before it is cut
local CRACKLE_COOLDOWN = 2.5 -- seconds between two crackles (all lamps)
local crackleWatch: { [BasePart]: RBXScriptConnection } = {}
local nextCrackle = 0

local function crackle(lamp: BasePart)
	local now = os.clock()
	local position = cameraPosition()
	if now < nextCrackle or position == nil or ParkAtmosphereController.blend() > 0.5 then
		return
	end
	if (lamp.Position - position).Magnitude > CRACKLE_RANGE then
		return
	end
	nextCrackle = now + CRACKLE_COOLDOWN
	local sound = SoundController.playAt("PowerBuzz", lamp.Position, CRACKLE_RANGE + 10)
	if sound then
		sound.Volume *= CRACKLE_VOLUME
		-- a random bit of the buzz, cut short
		sound.TimePosition = random:NextNumber(0, 1.5)
		task.delay(random:NextNumber(CRACKLE_LENGTH.Min, CRACKLE_LENGTH.Max), function()
			if sound.Parent then
				fadeOut(sound, 0.08)
			end
		end)
	end
end

-- Every second: watch the stuttering lamps near the camera, forget the far ones.
local function updateCrackleWatch()
	local position = cameraPosition()
	for _, instance in CollectionService:GetTagged("CityLamp") do
		if not instance:IsA("BasePart") or instance:GetAttribute("Flicker") ~= true then
			continue
		end
		local lamp = instance :: BasePart
		local near = position ~= nil and (lamp.Position - position).Magnitude < CRACKLE_WATCH_RANGE
		local watching: RBXScriptConnection? = crackleWatch[lamp]
		if near and watching == nil then
			local light = lightOf(lamp)
			if light then
				crackleWatch[lamp] = light:GetPropertyChangedSignal("Enabled"):Connect(function()
					if not light.Enabled then
						crackle(lamp)
					end
				end)
			end
		elseif not near and watching then
			watching:Disconnect()
			crackleWatch[lamp] = nil
		end
	end
	for lamp, connection in crackleWatch do
		if lamp.Parent == nil then
			connection:Disconnect()
			crackleWatch[lamp] = nil
		end
	end
end

-- The power cut's timeline, from the server's attributes: started at WeatherStartedAt, the
-- lights stutter for POWER_FLICKER s, then dark for POWER_DARK s.
local scheduledCut = -1

local function onWeatherChanged()
	if workspace:GetAttribute("Weather") ~= "PowerCut" then
		return
	end
	local started = workspace:GetAttribute("WeatherStartedAt")
	if typeof(started) ~= "number" or started == scheduledCut then
		return
	end
	scheduledCut = started
	local untilBlow = started + W.POWER_FLICKER - 0.35 - workspace:GetServerTimeNow()
	if untilBlow < -1 then
		return -- joined in the middle of it
	end
	-- the grid buzzing and crackling while the lights stutter (not heard from the park)
	local buzz: Sound? = nil
	if untilBlow > 1 and ParkAtmosphereController.blend() < 0.5 then
		buzz = SoundController.play2D("PowerBuzz")
	end
	task.delay(math.max(0, untilBlow), function()
		-- the buzz dies with the grid (it stops fast just as the transformer blows)
		if buzz then
			fadeOut(buzz, 0.25)
		end
		if ParkAtmosphereController.blend() > 0.5 then
			return -- (from the park you neither see nor hear the substation)
		end
		transformerBlow(1)
		-- a last little crackle as the grid dies
		task.delay(0.45, function()
			transformerBlow(0.35)
		end)
	end)
end

-- True during the dark part of a power cut (stops a moment before the power comes back, so
-- the server's restore wave always has the last word on the lights).
local function powerIsOut(now: number): boolean
	if workspace:GetAttribute("Weather") ~= "PowerCut" then
		return false
	end
	local started = workspace:GetAttribute("WeatherStartedAt")
	if typeof(started) ~= "number" then
		return false
	end
	local darkFrom = started + W.POWER_FLICKER
	return now >= darkFrom and now < darkFrom + W.POWER_DARK - 0.4
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

local function update(dt: number)
	local now = os.clock()
	local park = ParkAtmosphereController.blend()

	-- rain
	local intensity, storm, covered, indoors = WeatherController.rainState()
	updateLens(dt, intensity, storm, park)
	local rain = intensity * (1 - park)
	if now >= nextRippleCheck then
		nextRippleCheck = now + RIPPLE_CHECK_EVERY
		updateRipples(rain, storm)
	end
	local outside = not covered and not indoors and rain > 0.05
	updateBodySplashes(if outside then BODY_SPLASH_RATE * rain * (if storm then 1.6 else 1) else 0)

	-- fog
	local fog = WeatherController.fogIntensity() * (1 - park)
	updateGroundFog(fog, park)
	if now >= nextHaloCheck then
		nextHaloCheck = now + HALO_CHECK_EVERY
		updateHalos(fog)
		updateCrackleWatch()
	end

	-- power cut
	updateEmergencyPulse(powerIsOut(workspace:GetServerTimeNow()))
end

function WeatherFxController.start()
	LensRain.build(player:WaitForChild("PlayerGui"))
	buildGroundFog()
	workspace:GetAttributeChangedSignal("Weather"):Connect(onWeatherChanged)
	onWeatherChanged()
	RunService.Heartbeat:Connect(update)
end

return WeatherFxController
