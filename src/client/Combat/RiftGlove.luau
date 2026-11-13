--!strict
-- RiftGlove: Dr. Rift's gravity glove and Awakening, on this client (look
-- only): the glove gathering power, its blast landing, the gravity slam's
-- shockwave, the Awakening's activation.
--
--   RiftGlove.charge(model, seconds)    RiftGlove.wave(data)
--   RiftGlove.onHit(victim, attacker, moveId)    RiftGlove.onAwaken(model)

local Debris = game:GetService("Debris")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local P = require(script.Parent.RiftParts)
local RiftGear = require(script.Parent.RiftGear)
local RiftPortal = require(script.Parent.RiftPortal)

local RiftGlove = {}

local RIFT_GREEN = P.RIFT_GREEN
local RIFT_GLOW = P.RIFT_GLOW
local SMOKE = P.SMOKE
local disc = P.disc
local attachmentAt = P.attachmentAt
local emitter = P.emitter
local sparkTexture = P.sparkTexture
local fade = P.fade
local floorUnder = P.floorUnder
local shakeNear = P.shakeNear

-- The glove gathering power (the glove moves, the awakening).
function RiftGlove.charge(model: Model, seconds: number)
	local palm = RiftGear.palmOf(model)
	if palm == nil then
		return
	end
	local pull = emitter(palm, {
		Name = "GloveCharge",
		Color = ColorSequence.new(RIFT_GLOW),
		LightEmission = 1,
		Size = NumberSequence.new(0.25, 0),
		Transparency = NumberSequence.new(0.2, 1),
		Lifetime = NumberRange.new(0.25, 0.4),
		Speed = NumberRange.new(-8, -5), -- (drawn in)
		Rate = 0,
	})
	sparkTexture(pull)
	pull.Shape = Enum.ParticleEmitterShape.Sphere
	pull.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pull:Emit(30)
	pull.Rate = 60
	task.delay(seconds, function()
		pull.Enabled = false
		Debris:AddItem(pull, 0.5)
	end)
end

------------------------------------------------------------------------------
-- Shockwave (gravity slam)
------------------------------------------------------------------------------

function RiftGlove.wave(data: { [string]: any })
	local position, radius = data.position, data.radius
	if typeof(position) ~= "Vector3" or typeof(radius) ~= "number" then
		return
	end
	local floor = floorUnder(position + Vector3.new(0, 1, 0))
	local ground = if floor then floor.Position else position
	local up = CFrame.lookAt(ground + Vector3.new(0, 0.12, 0), ground + Vector3.new(0, 1, 0))
	-- A ring of distorted air racing out, a flash in the middle.
	for index, layer in { { color = RIFT_GLOW, t = 0.2 }, { color = RIFT_GREEN, t = 0.55 } } do
		local ring = disc("Wave", layer.color, layer.t)
		ring.CFrame = up * CFrame.new(0, 0, -0.02 * index)
		ring.Size = Vector3.new(1, 1, 0.06)
		ring.Parent = workspace
		fade(ring, 0.4 + index * 0.08, { Size = Vector3.new(radius * 2, radius * 2, 0.06) })
	end
	local point = attachmentAt(ground + Vector3.new(0, 0.3, 0))
	local dust = emitter(point, {
		Color = ColorSequence.new(if floor then floor.Instance.Color:Lerp(SMOKE, 0.5) else SMOKE),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 3),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(radius * 2, radius * 3),
		SpreadAngle = Vector2.new(5, 180),
		Drag = 3,
		EmissionDirection = Enum.NormalId.Right,
	})
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust:Emit(50)
	Debris:AddItem(point, 2)
	RiftPortal.flash(ground + Vector3.new(0, 0.5, 0), 1.6)
	shakeNear(ground, 5, 0.45)
	SoundController.playAt("RiftImpact", ground)
end

-- A Rift move landed on `victim`: what it does to the body (the burn
-- itself comes from the "Burning" attribute).
function RiftGlove.onHit(victim: Model, _attacker: Model, moveId: string)
	if moveId == "GravityGlove" then
		local torso = victim:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			RiftPortal.flash(torso.Position, 0.7)
			shakeNear(torso.Position, 3, 0.3)
		end
	end
end

-- (the Awakening: a portal tears open behind him as it starts)
function RiftGlove.onAwaken(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		RiftPortal.door(root.CFrame * CFrame.new(0, 0, 2.2), 0.8)
		RiftPortal.flash(root.Position, 1.2)
		SoundController.play("PortalOpen", model)
		-- (the arms flung out, 0.75 s into Rift_Awaken: the impact)
		task.delay(0.72, function()
			if model.Parent then
				SoundController.play("RiftImpact", model)
			end
		end)
	end
end

return RiftGlove
