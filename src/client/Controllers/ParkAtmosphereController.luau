--!strict
-- ParkAtmosphereController: the hidden park is ALWAYS a sunny afternoon, for you.
--
-- The rest of the city follows the server's day / night cycle and weather (Server/Systems/
-- Ambience changes Lighting, the Atmosphere, the clouds... and those changes replicate to
-- every player). When YOUR camera enters the park (a part tagged "ParkZone", see
-- Shared/Util/CityZones), this controller lays a LOCAL "sunny" look on top, blended in over
-- 1.5 s, and takes it off the same way when you leave. Only your screen changes.
--
-- How it keeps the server from fighting it:
--   • while the override is on, every frame (RenderStepped, right before the picture is drawn)
--     it writes the blended values itself;
--   • before writing, it compares each property with what it wrote last frame: a different
--     value means the SERVER changed it meanwhile (a tween of the sunset, the rain...). That
--     new value is remembered as the "server value", and the blend starts from it. So the
--     server can tween as much as it likes: the park stays sunny, and when you walk out you
--     find the city exactly as the server has it NOW.
--   • when the blend is back to 0, it writes the server values one last time and stops
--     touching anything.
--
--   ParkAtmosphereController.blend()        0 (city look) → 1 (full park look)
--   ParkAtmosphereController.inPark()       true while your camera is in the park
--   ParkAtmosphereController.serverClockTime()  the server's Lighting.ClockTime (not ours)

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CityZones = require(ReplicatedStorage.Shared.Util.CityZones)

local ParkAtmosphereController = {}

-- Seconds to blend in / out.
local BLEND_TIME = 1.5
-- How often the camera is tested against the park boxes (seconds).
local CHECK_EVERY = 0.15

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- The park look: a warm, clear early afternoon. One table per object; the object is found by
-- `find` (it can be created late or replaced by the server).
type Layer = {
	find: () -> Instance?,
	props: { [string]: any },
}

local LAYERS: { Layer } = {
	{
		find = function()
			return Lighting
		end,
		props = {
			ClockTime = 14,
			Brightness = 2.6,
			Ambient = rgb(108, 104, 98),
			OutdoorAmbient = rgb(150, 146, 138),
			ExposureCompensation = 0.05,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.5,
			ShadowSoftness = 0.2,
		},
	},
	{
		find = function()
			return Lighting:FindFirstChildOfClass("Atmosphere")
		end,
		props = {
			Density = 0.22,
			Offset = 0.12,
			Color = rgb(200, 214, 230),
			Decay = rgb(118, 146, 178),
			Glare = 0.35,
			Haze = 0.6,
		},
	},
	{
		find = function()
			return workspace.Terrain:FindFirstChildOfClass("Clouds")
		end,
		props = { Cover = 0.42, Density = 0.35, Color = rgb(255, 255, 255) },
	},
	{
		find = function()
			-- (the server's grade; our own weather grade is handled by WeatherController)
			return Lighting:FindFirstChild("AmbienceGrade")
		end,
		props = {
			Brightness = 0.02,
			Contrast = 0.08,
			Saturation = 0.1,
			TintColor = rgb(255, 248, 236),
		},
	},
	{
		find = function()
			return Lighting:FindFirstChildOfClass("BloomEffect")
		end,
		props = { Intensity = 0.4, Size = 24, Threshold = 1.8 },
	},
	{
		find = function()
			return Lighting:FindFirstChildOfClass("SunRaysEffect")
		end,
		props = { Intensity = 0.1, Spread = 0.6 },
	},
}

-- For each object: the server's value of each property, and what we wrote last.
type Memory = { server: { [string]: any }, written: { [string]: any } }
local memory: { [Instance]: Memory } = setmetatable({}, { __mode = "k" }) :: any

local blendValue = 0
local cameraInPark = false
local nextCheck = 0
-- True while we are writing (blend > 0, or the one last restoring write).
local active = false

local function lerpValue(from: any, to: any, alpha: number): any
	if typeof(from) == "number" and typeof(to) == "number" then
		return from + (to - from) * alpha
	elseif typeof(from) == "Color3" and typeof(to) == "Color3" then
		return from:Lerp(to, alpha)
	end
	return if alpha >= 0.5 then to else from
end

-- Writes the blended look on one object (see the header for the server-value trick).
local function applyLayer(layer: Layer, alpha: number)
	local instance = layer.find()
	if instance == nil then
		return
	end
	local mem = memory[instance]
	if mem == nil then
		mem = { server = {}, written = {} }
		memory[instance] = mem
	end
	for name, parkValue in layer.props do
		local current = (instance :: any)[name]
		-- Not what we wrote (or never written): the server's value.
		if mem.written[name] == nil or current ~= mem.written[name] then
			mem.server[name] = current
		end
		local value = lerpValue(mem.server[name], parkValue, alpha)
		if current ~= value then
			(instance :: any)[name] = value
		end
		-- (read back: the engine may round what we write, e.g. ClockTime)
		mem.written[name] = (instance :: any)[name]
	end
end

-- Stops overriding: puts the server's values back and forgets them.
local function restore()
	for instance, mem in memory do
		for name, value in mem.server do
			if (instance :: any)[name] == mem.written[name] then
				(instance :: any)[name] = value
			end
		end
	end
	table.clear(memory)
end

local function update(deltaTime: number)
	local now = os.clock()
	if now >= nextCheck then
		nextCheck = now + CHECK_EVERY
		local camera = workspace.CurrentCamera
		cameraInPark = camera ~= nil and CityZones.inPark(camera.CFrame.Position)
	end
	local target = if cameraInPark then 1 else 0
	if blendValue ~= target then
		local step = deltaTime / BLEND_TIME
		blendValue = if target > blendValue
			then math.min(target, blendValue + step)
			else math.max(target, blendValue - step)
	end
	if blendValue <= 0 then
		if active then
			active = false
			restore()
		end
		return
	end
	active = true
	-- smoothstep: eases in and out
	local alpha = blendValue * blendValue * (3 - 2 * blendValue)
	for _, layer in LAYERS do
		applyLayer(layer, alpha)
	end
end

-- 0 (city) → 1 (park), eased: the sounds and the rain follow it too.
function ParkAtmosphereController.blend(): number
	return blendValue * blendValue * (3 - 2 * blendValue)
end

function ParkAtmosphereController.inPark(): boolean
	return cameraInPark
end

-- The server's ClockTime, even while the park override has changed ours.
function ParkAtmosphereController.serverClockTime(): number
	local mem = memory[Lighting]
	local value = if mem then mem.server.ClockTime else nil
	return if typeof(value) == "number" then value else Lighting.ClockTime
end

function ParkAtmosphereController.start()
	-- Last in the frame's RenderStepped list: after anything else that touches Lighting.
	RunService:BindToRenderStep("ParkAtmosphere", Enum.RenderPriority.Last.Value, update)
end

return ParkAtmosphereController
