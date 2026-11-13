--!strict
-- WeatherFxController: the small touches that make the weather events feel real.
--
-- WeatherController draws the big things (the rain around you, the lightning, the notice);
-- this one adds the details, all on THIS screen only and cheap (a few particle emitters that
-- are switched on and off, a handful of screen frames):
--
--   RAIN / THUNDERSTORM
--     • DROPS ON THE SCREEN: very rarely (every 6 to 12 s in the rain, a bit more often in a
--       thunderstorm), one to three small water drops land on the "lens", slide down slowly
--       and dry out in 1 to 3 s. Only when the camera is OUTSIDE in the open (not under a
--       roof or an awning, not inside the bar or a shop, never in the park), never in the
--       middle of the screen.
--     • RIPPLES in the puddles near you (tagged CityPuddle): small rings that open and fade.
--     • SPLASHES on your own head and shoulders while you stand in the rain.
--     (the drips under the roof edges, CityDrip, are switched on by the server: Ambience)
--   FOG
--     • a LOW FOG that drifts slowly along the ground around you;
--     • a soft HALO around every lit street lamp near you.
--     (the muffled city sounds are done by CityAudioController)
--   POWER CUT
--     • the transformer at the substation (Config.Weather.SUBSTATION) BLOWS just before the
--       dark: a burst of sparks, smoke, a blue-white flash, and the TransformerBlow sound;
--     • while the power is out, the red emergency lights PULSE slowly.
--
-- The park is always sunny: nothing of this happens in it (ParkAtmosphereController.blend()).
-- In a duel you are in an arena: no screen drops there either.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CityZones = require(ReplicatedStorage.Shared.Util.CityZones)
local ParkAtmosphereController = require(script.Parent.ParkAtmosphereController)
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

-- Screen drops: seconds between two bursts (rain / thunderstorm), drops per burst, the most
-- on screen at once, their size in pixels and how long one lives.
local DROP_GAP_RAIN = NumberRange.new(6, 12)
local DROP_GAP_STORM = NumberRange.new(3.5, 7)
local DROP_MAX = 8
local DROP_SIZE = NumberRange.new(7, 20)
local DROP_LIFE = NumberRange.new(1.2, 3)

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
-- Screen drops
------------------------------------------------------------------------------

type Drop = {
	frame: Frame,
	stroke: UIStroke,
	shine: Frame,
	born: number,
	life: number,
	x: number, -- scale
	y: number, -- scale
	slide: number, -- pixels it slides down over its life
}

local dropGui: ScreenGui
local drops: { Drop } = {}
local nextDropAt = 0

local function buildDropGui()
	dropGui = Instance.new("ScreenGui")
	dropGui.Name = "RainOnScreen"
	dropGui.ResetOnSpawn = false
	dropGui.IgnoreGuiInset = true
	dropGui.DisplayOrder = 1 -- under the HUD and the menus
	dropGui.Parent = player:WaitForChild("PlayerGui")
end

-- A point on the screen away from the middle (the left / right thirds, or the top band).
local function edgePoint(): (number, number)
	if random:NextNumber() < 0.75 then
		local x = if random:NextNumber() < 0.5
			then random:NextNumber(0.04, 0.3)
			else random:NextNumber(0.7, 0.96)
		return x, random:NextNumber(0.06, 0.7)
	end
	return random:NextNumber(0.1, 0.9), random:NextNumber(0.04, 0.16)
end

-- One water drop on the lens: a round blob (an exception to the "no rounded corners" rule
-- of the UI: it is water, not interface), lighter at its rim and with a small shine, as if
-- it bent the light.
local function spawnDrop()
	if #drops >= DROP_MAX then
		return
	end
	local size = random:NextNumber(DROP_SIZE.Min, DROP_SIZE.Max)
	local x, y = edgePoint()
	local frame = Instance.new("Frame")
	frame.Name = "Drop"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromOffset(size, size * random:NextNumber(1.05, 1.3))
	frame.BackgroundColor3 = Color3.fromRGB(214, 224, 234)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	-- darker in the middle, lighter towards the bottom (light bent through the drop)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.85),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	gradient.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(240, 246, 252)
	stroke.Thickness = 1
	stroke.Transparency = 1
	stroke.Parent = frame
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.fromScale(0.34, 0.3)
	shine.Size = UDim2.fromScale(0.26, 0.22)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 1
	shine.BorderSizePixel = 0
	local shineCorner = Instance.new("UICorner")
	shineCorner.CornerRadius = UDim.new(1, 0)
	shineCorner.Parent = shine
	shine.Parent = frame
	frame.Parent = dropGui
	table.insert(drops, {
		frame = frame,
		stroke = stroke,
		shine = shine,
		born = os.clock(),
		life = random:NextNumber(DROP_LIFE.Min, DROP_LIFE.Max),
		x = x,
		y = y,
		slide = random:NextNumber(14, 60),
	})
end

-- Every frame: the drops slide down (slowly, then a little faster, like a real drop running)
-- and dry out.
local function updateDrops()
	local now = os.clock()
	for index = #drops, 1, -1 do
		local drop = drops[index]
		local alpha = (now - drop.born) / drop.life
		if alpha >= 1 then
			drop.frame:Destroy()
			table.remove(drops, index)
			continue
		end
		-- fade in fast (0.1 of its life), stay, fade out over the last 40 %
		local visible = math.min(alpha / 0.1, 1) * math.clamp((1 - alpha) / 0.4, 0, 1)
		drop.frame.BackgroundTransparency = 1 - 0.22 * visible
		drop.stroke.Transparency = 1 - 0.5 * visible
		drop.shine.BackgroundTransparency = 1 - 0.55 * visible
		drop.frame.Position =
			UDim2.new(drop.x, 0, drop.y, math.floor(drop.slide * alpha * alpha + 0.5))
	end
end

-- Should a drop land on the lens now? (Raining hard enough, the camera outside in the open.)
local function lensInTheRain(): boolean
	local intensity, _, covered, indoors = WeatherController.rainState()
	if intensity * (1 - ParkAtmosphereController.blend()) < 0.5 or covered or indoors then
		return false
	end
	if player:GetAttribute("InDuel") == true or ParkAtmosphereController.inPark() then
		return false
	end
	local position = cameraPosition()
	return position ~= nil and CityZones.musicZoneAt(position) == nil
end

local function tickDrops()
	local now = os.clock()
	if now >= nextDropAt then
		local _, storm = WeatherController.rainState()
		local gap = if storm then DROP_GAP_STORM else DROP_GAP_RAIN
		nextDropAt = now + random:NextNumber(gap.Min, gap.Max)
		if lensInTheRain() then
			for _ = 1, random:NextInteger(1, if storm then 3 else 2) do
				spawnDrop()
			end
		end
	end
	if #drops > 0 then
		updateDrops()
	end
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
	for _, emitter in bodySplashes do
		local part = emitter.Parent
		-- (first person: your head is hidden, its splashes would hit the lens)
		local hidden = part ~= nil
			and part:IsA("BasePart")
			and (part :: BasePart).LocalTransparencyModifier > 0.5
		emitter.Rate = if hidden then 0 else rate
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
	task.delay(math.max(0, untilBlow), function()
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

local function update()
	local now = os.clock()
	local park = ParkAtmosphereController.blend()

	-- rain
	tickDrops()
	local intensity, storm, covered, indoors = WeatherController.rainState()
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
	end

	-- power cut
	updateEmergencyPulse(powerIsOut(workspace:GetServerTimeNow()))
end

function WeatherFxController.start()
	buildDropGui()
	buildGroundFog()
	workspace:GetAttributeChangedSignal("Weather"):Connect(onWeatherChanged)
	onWeatherChanged()
	RunService.Heartbeat:Connect(update)
end

return WeatherFxController
