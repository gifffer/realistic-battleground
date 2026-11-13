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
--   ParkAtmosphereController.inPark()       true while your camera or your character is in it
--   ParkAtmosphereController.serverClockTime()  the server's Lighting.ClockTime (not ours)
--
-- "Am I in the park?": your CAMERA or your CHARACTER is inside a ParkZone box (either one:
-- near the park's edge the camera can swing out of the box behind you). The boxes are read
-- with Shared/Util/CityZones, which also reads the copies the city puts in ReplicatedStorage
-- (a streamed workspace may not have the boxes on your computer).
--
-- Debug (Studio > Players > you > Attributes): InPark (true / false), ParkBlend (0 .. 1) and
-- ParkBoxes (how many park boxes your computer knows; 0 = the park can't be found).
--
-- v6 fixes (the park was at night in a playtest):
--   • the memory of the server's values is a NORMAL table now. It was a weak-keyed table:
--     Roblox may drop an Instance key from such a table while the object still exists (its
--     Lua handle is collected and remade), then the next frame took OUR park value as "the
--     server's value", and leaving the park "restored" the park look;
--   • the boxes are also read from ReplicatedStorage (StreamingEnabled, see above);
--   • the character's position counts too, not only the camera's.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
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
			Brightness = 2.5,
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
-- (A normal table, NOT weak-keyed: see the v6 fixes in the header. It is emptied by restore()
-- and holds at most the 6 objects of LAYERS.)
type Memory = { server: { [string]: any }, written: { [string]: any } }
local memory: { [Instance]: Memory } = {}

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

local player = Players.LocalPlayer
local warnedNoBoxes = false

-- Is your camera or your character in the park? (also updates the debug attributes)
local function checkInPark(): boolean
	local boxes = CityZones.boxes(CityZones.PARK_TAG)
	local inside = false
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	for _, box in boxes do
		if
			(camera ~= nil and CityZones.insideBox(box, camera.CFrame.Position))
			or (root ~= nil and root:IsA("BasePart") and CityZones.insideBox(box, root.Position))
		then
			inside = true
			break
		end
	end
	player:SetAttribute("InPark", inside)
	player:SetAttribute("ParkBoxes", #boxes)
	-- A built city without any park box: say it once (the park would never be sunny).
	if #boxes == 0 and not warnedNoBoxes then
		local city = workspace:FindFirstChild("City")
		if city and city:GetAttribute("Built") == true then
			warnedNoBoxes = true
			warn("[ParkAtmosphere] the city is built but no ParkZone box was found")
		end
	end
	return inside
end

local function update(deltaTime: number)
	local now = os.clock()
	if now >= nextCheck then
		nextCheck = now + CHECK_EVERY
		cameraInPark = checkInPark()
		player:SetAttribute("ParkBlend", math.round(blendValue * 100) / 100)
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

-- (true while your camera or your character is in the park)
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
