--!strict
-- RiftRay: Dr. Rift's ray gun and overcharged ray, on this client (look
-- only; Server/Combat/Gadgets traced it): the beam from his gun to where it
-- stopped, the muzzle flash, the impact.
--
--   RiftRay.ray(data, muzzleOf)    Remotes.RiftFx "Ray" { by, from, to, width, big }

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local P = require(script.Parent.RiftParts)

local RiftRay = {}

local RAY_CORE = P.RAY_CORE
local RAY_GLOW = P.RAY_GLOW
local ghost = P.ghost
local attachmentAt = P.attachmentAt
local emitter = P.emitter
local sparkTexture = P.sparkTexture
local fade = P.fade
local shakeNear = P.shakeNear

------------------------------------------------------------------------------
-- Rays
------------------------------------------------------------------------------

function RiftRay.ray(data: { [string]: any }, muzzleOf: (model: Model) -> Vector3?)
	local from, to, width, big = data.from, data.to, data.width, data.big
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or typeof(width) ~= "number" then
		return
	end
	local by = data.by
	local start = from
	if typeof(by) == "Instance" and by:IsA("Model") then
		start = muzzleOf(by) or from
	end
	local length = (to - start).Magnitude
	if length < 0.1 then
		return
	end
	local along = CFrame.lookAt((start + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0)
	local seconds = if big == true then 0.45 else 0.22
	-- Core, glow, and (the big one) a wider haze.
	local layers = {
		{ color = RAY_CORE, scale = 0.35, transparency = 0 },
		{ color = RAY_GLOW, scale = 1, transparency = 0.35 },
	}
	if big == true then
		table.insert(
			layers,
			{ color = Color3.fromRGB(255, 60, 20), scale = 1.8, transparency = 0.7 }
		)
	end
	for _, layer in layers do
		local beam = ghost(
			"Ray",
			Vector3.new(length, width * layer.scale, width * layer.scale),
			layer.color,
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
		beam.Anchored = true
		beam.Transparency = layer.transparency
		beam.CFrame = along
		beam.Parent = workspace
		fade(beam, seconds, { Size = Vector3.new(length, 0.02, 0.02) })
	end
	-- Muzzle flash and the impact: sparks, a glowing scorch.
	for _, position in { start, to } do
		local point = attachmentAt(position)
		local sparks = emitter(point, {
			Color = ColorSequence.new(RAY_CORE, RAY_GLOW),
			LightEmission = 1,
			Size = NumberSequence.new(0.18, 0),
			Lifetime = NumberRange.new(0.15, 0.4),
			Speed = NumberRange.new(8, 20),
			Acceleration = Vector3.new(0, -30, 0),
		})
		sparkTexture(sparks)
		sparks:Emit(if position == to then 30 else 12)
		local light = Instance.new("PointLight")
		light.Color = RAY_GLOW
		light.Brightness = 4
		light.Range = 10
		light.Parent = point
		TweenService:Create(light, TweenInfo.new(seconds + 0.1), { Brightness = 0 }):Play()
		Debris:AddItem(point, 1)
	end
	-- (its sound plays from the move's start, at the shot: RiftFx.onAction)
	shakeNear(to, if big == true then 2.5 else 0.8, 0.2)
end

return RiftRay
