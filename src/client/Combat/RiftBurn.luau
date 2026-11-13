--!strict
-- RiftBurn: someone burning ("Burning" attribute: "Acid" / "Fire", set by
-- the server while Dr. Rift's acid or ray burns them).
--
--   RiftBurn.watch(model)

local Debris = game:GetService("Debris")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local RiftBurn = {}
local P = require(script.Parent.RiftParts)
local ACID = P.ACID
local ACID_DARK = P.ACID_DARK
local FIRE = P.FIRE
local FIRE_HOT = P.FIRE_HOT
local SMOKE = P.SMOKE
local emitter = P.emitter
local sparkTexture = P.sparkTexture

------------------------------------------------------------------------------
-- Burning (acid / fire): the "Burning" attribute
------------------------------------------------------------------------------

local burning: { [Model]: { Instance } } = setmetatable({}, { __mode = "k" }) :: any

local function stopBurning(model: Model)
	local items = burning[model]
	burning[model] = nil
	if items == nil then
		return
	end
	for _, item in items do
		if item:IsA("ParticleEmitter") then
			item.Enabled = false
			Debris:AddItem(item, 1.5)
		else
			Debris:AddItem(item, 0)
		end
	end
end

local function startBurning(model: Model, kind: string)
	stopBurning(model)
	local items: { Instance } = {}
	for _, name in { "Torso", "Head", "Right Arm", "Left Arm" } do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			if kind == "Fire" then
				local flames = emitter(part, {
					Name = "RiftFlames",
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, FIRE_HOT),
						ColorSequenceKeypoint.new(0.4, FIRE),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 30, 10)),
					}),
					LightEmission = 0.8,
					Size = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.5),
						NumberSequenceKeypoint.new(1, 0.1),
					}),
					Transparency = NumberSequence.new(0.2, 1),
					Lifetime = NumberRange.new(0.3, 0.6),
					Speed = NumberRange.new(2, 4),
					SpreadAngle = Vector2.new(20, 20),
					Acceleration = Vector3.new(0, 6, 0),
					EmissionDirection = Enum.NormalId.Top,
					Rate = if name == "Torso" then 30 else 12,
				})
				table.insert(items, flames)
			else
				-- Acid: it fizzes on the skin, yellow-green fumes.
				local fizz = emitter(part, {
					Name = "RiftFizz",
					Color = ColorSequence.new(ACID, ACID_DARK),
					LightEmission = 0.3,
					Size = NumberSequence.new(0.12, 0.02),
					Transparency = NumberSequence.new(0.1, 1),
					Lifetime = NumberRange.new(0.2, 0.4),
					Speed = NumberRange.new(1, 3),
					Rate = if name == "Torso" then 25 else 10,
				})
				sparkTexture(fizz)
				table.insert(items, fizz)
			end
			local smoke = emitter(part, {
				Name = "RiftBurnSmoke",
				Color = ColorSequence.new(
					if kind == "Fire" then SMOKE else Color3.fromRGB(150, 170, 90)
				),
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.4),
					NumberSequenceKeypoint.new(1, 1.6),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.55),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(1, 2),
				SpreadAngle = Vector2.new(25, 25),
				Acceleration = Vector3.new(0, 3, 0),
				EmissionDirection = Enum.NormalId.Top,
				Rate = if name == "Torso" then 10 else 4,
			})
			table.insert(items, smoke)
		end
	end
	local torso = model:FindFirstChild("Torso")
	if kind == "Fire" and torso and torso:IsA("BasePart") then
		local light = Instance.new("PointLight")
		light.Name = "RiftFireLight"
		light.Color = FIRE
		light.Brightness = 1.5
		light.Range = 8
		light.Parent = torso
		table.insert(items, light)
	end
	burning[model] = items
	SoundController.play(if kind == "Fire" then "Burn" else "AcidSizzle", model)
end

local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function RiftBurn.watch(model: Model)
	if watched[model] then
		return
	end
	watched[model] = true
	local function refresh()
		local kind = model:GetAttribute("Burning")
		if typeof(kind) == "string" then
			startBurning(model, kind)
		else
			stopBurning(model)
		end
	end
	model:GetAttributeChangedSignal("Burning"):Connect(refresh)
	refresh()
end

return RiftBurn
