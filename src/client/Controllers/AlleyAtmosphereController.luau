--!strict
-- AlleyAtmosphereController: the alleys under the viaduct feel closer and darker, for you.
--
-- When YOUR camera or character is inside an "AlleyZone" box (an invisible box part placed by
-- the city, read with Shared/Util/CityZones like the ParkZone boxes), a subtle oppressive layer
-- is blended in over 2.5 s and taken off the same way when you leave. Only your screen changes:
--   • Lighting: exposure a little lower, the ambient light (sky and fill) dimmer, so the lamps
--     and the faulty bulbs carry the place;
--   • Atmosphere: a bit thicker and hazier, a dirtier colour (the air under the tracks);
--   • our OWN ColorCorrectionEffect ("AlleyGrade"): a touch less colour, a touch more contrast,
--     a faint sickly tint.
--
-- It never fights the server (Ambience: day / night, weather, power cut) nor the park:
--   • every value is RELATIVE to the server's current one (server + offset, server × factor);
--   • the server's value is found like ParkAtmosphereController does: a value different from
--     what we wrote last frame was changed by the server meanwhile, and becomes the new base.
--     So the server can tween its sunset or its rain: the alley layer rides on top;
--   • it runs just BEFORE ParkAtmosphereController in the frame (the zones never overlap; if
--     they did, the park would simply win);
--   • when the blend is back to 0 it writes the server's values back and stops touching them.
--
--   AlleyAtmosphereController.blend()   0 (city) → 1 (in the alley), eased
--   AlleyAtmosphereController.inAlley() true while your camera or character is in a box
--
-- Debug (Studio > Players > you > Attributes): InAlley, AlleyBlend, AlleyBoxes.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CityZones = require(ReplicatedStorage.Shared.Util.CityZones)

local AlleyAtmosphereController = {}

-- The zone tag (the city also mirrors it into ReplicatedStorage > CityZoneBoxes with
-- ZoneTag = "AlleyZone" once it is in City/init.luau's mirror list).
AlleyAtmosphereController.TAG = "AlleyZone"

local BLEND_TIME = 2.5
local CHECK_EVERY = 0.15

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- How a property moves at full blend: `add` (numbers), `mul` (numbers or colours, a factor),
-- `toward` + `amount` (colours: lerp toward that colour).
type Change = { add: number?, mul: number?, toward: Color3?, amount: number? }
type Layer = {
	find: () -> Instance?,
	changes: { [string]: Change },
}

local LAYERS: { Layer } = {
	{
		find = function()
			return Lighting
		end,
		changes = {
			ExposureCompensation = { add = -0.22 },
			Ambient = { mul = 0.72 },
			OutdoorAmbient = { mul = 0.62 },
			EnvironmentDiffuseScale = { mul = 0.7 },
		},
	},
	{
		find = function()
			return Lighting:FindFirstChildOfClass("Atmosphere")
		end,
		changes = {
			Density = { add = 0.05 },
			Haze = { add = 0.7 },
			Color = { toward = rgb(52, 50, 46), amount = 0.45 },
			Decay = { toward = rgb(34, 32, 30), amount = 0.4 },
		},
	},
}

-- Our own grade (only this controller touches it).
local GRADE_FULL = {
	Brightness = -0.03,
	Contrast = 0.08,
	Saturation = -0.14,
	TintColor = rgb(236, 238, 224),
}
local NO_TINT = rgb(255, 255, 255)

type Memory = { server: { [string]: any }, written: { [string]: any } }
local memory: { [Instance]: Memory } = {}

local blendValue = 0
local inside = false
local nextCheck = 0
local active = false
local grade: ColorCorrectionEffect? = nil

local function changed(value: any, change: Change, alpha: number): any
	if typeof(value) == "number" then
		local target = value
		if change.add then
			target += change.add
		end
		if change.mul then
			target *= change.mul
		end
		return value + (target - value) * alpha
	elseif typeof(value) == "Color3" then
		local target = value
		if change.mul then
			local m = change.mul
			target = Color3.new(target.R * m, target.G * m, target.B * m)
		end
		if change.toward then
			target = target:Lerp(change.toward, change.amount or 1)
		end
		return value:Lerp(target, alpha)
	end
	return value
end

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
	for name, change in layer.changes do
		local current = (instance :: any)[name]
		if mem.written[name] == nil or current ~= mem.written[name] then
			mem.server[name] = current
		end
		local value = changed(mem.server[name], change, alpha)
		if current ~= value then
			(instance :: any)[name] = value
		end
		mem.written[name] = (instance :: any)[name]
	end
end

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

local function applyGrade(alpha: number)
	local effect = grade
	if effect == nil or effect.Parent ~= Lighting then
		local made = Instance.new("ColorCorrectionEffect")
		made.Name = "AlleyGrade"
		made.Parent = Lighting
		effect = made
		grade = made
	end
	local g = effect :: ColorCorrectionEffect
	g.Enabled = alpha > 0
	g.Brightness = GRADE_FULL.Brightness * alpha
	g.Contrast = GRADE_FULL.Contrast * alpha
	g.Saturation = GRADE_FULL.Saturation * alpha
	g.TintColor = NO_TINT:Lerp(GRADE_FULL.TintColor, alpha)
end

local player = Players.LocalPlayer

local function checkInside(): boolean
	local boxes = CityZones.boxes(AlleyAtmosphereController.TAG)
	local found = false
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	for _, box in boxes do
		if
			(camera ~= nil and CityZones.insideBox(box, camera.CFrame.Position))
			or (root ~= nil and root:IsA("BasePart") and CityZones.insideBox(box, root.Position))
		then
			found = true
			break
		end
	end
	player:SetAttribute("InAlley", found)
	player:SetAttribute("AlleyBoxes", #boxes)
	return found
end

local function update(deltaTime: number)
	local now = os.clock()
	if now >= nextCheck then
		nextCheck = now + CHECK_EVERY
		inside = checkInside()
		player:SetAttribute("AlleyBlend", math.round(blendValue * 100) / 100)
	end
	local target = if inside then 1 else 0
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
			applyGrade(0)
		end
		return
	end
	active = true
	local alpha = blendValue * blendValue * (3 - 2 * blendValue)
	for _, layer in LAYERS do
		applyLayer(layer, alpha)
	end
	applyGrade(alpha)
end

function AlleyAtmosphereController.blend(): number
	return blendValue * blendValue * (3 - 2 * blendValue)
end

function AlleyAtmosphereController.inAlley(): boolean
	return inside
end

function AlleyAtmosphereController.start()
	-- Just before ParkAtmosphere (Last): the park, if ever both were on, writes over us.
	RunService:BindToRenderStep("AlleyAtmosphere", Enum.RenderPriority.Last.Value - 1, update)
end

return AlleyAtmosphereController
