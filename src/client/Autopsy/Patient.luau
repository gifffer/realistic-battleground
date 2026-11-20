--!strict
-- Patient: the R6 body lying face up on the table, wrapped in clear film
-- up to the neck like in the reference, the torso's front left bare to be
-- cut. Client-built, anchored, no Humanoid. Its colours are the local
-- player's own (BodyColors).
--
--   Patient.build(torso, parent) -> Patient
--   Patient.destroy(patient)

local Players = game:GetService("Players")

local Make = require(script.Parent.Make)
local Skin = require(script.Parent.Skin)

local Patient = {}

export type Patient = {
	model: Model,
	frame: CFrame, -- the torso (front -Z up, head +Y)
	anchor: BasePart, -- an invisible part where the torso is (sounds...)
	head: BasePart,
	skin: Skin.State,
}

local DEFAULT_SKIN = Color3.fromRGB(234, 184, 146)
local DEFAULT_LEGS = Color3.fromRGB(60, 70, 90)

local function colours(): { [string]: Color3 }
	local out: { [string]: Color3 } = {
		Head = DEFAULT_SKIN,
		Torso = DEFAULT_SKIN,
		LeftArm = DEFAULT_SKIN,
		RightArm = DEFAULT_SKIN,
		LeftLeg = DEFAULT_LEGS,
		RightLeg = DEFAULT_LEGS,
	}
	local character = Players.LocalPlayer.Character
	local body = if character then character:FindFirstChildOfClass("BodyColors") else nil
	if body then
		out.Head = body.HeadColor3
		out.Torso = body.TorsoColor3
		out.LeftArm = body.LeftArmColor3
		out.RightArm = body.RightArmColor3
		out.LeftLeg = body.LeftLegColor3
		out.RightLeg = body.RightLegColor3
	end
	return out
end

local function film(model: Model, frame: CFrame, size: Vector3, random: Random)
	Make.part({
		Name = "Film",
		Size = size,
		CFrame = frame,
		Color = Make.PLASTIC,
		Transparency = 0.55,
		Reflectance = 0.3,
		CanCollide = false,
		CastShadow = false,
		Ramp = "plastic",
		Parent = model,
	})
	-- (a few creases: thin strips a little turned)
	for _ = 1, 3 do
		local along = random:NextNumber(-size.Y / 2 + 0.2, size.Y / 2 - 0.2)
		Make.part({
			Name = "FilmCrease",
			Size = Vector3.new(size.X + 0.02, 0.06, 0.03),
			CFrame = frame
				* CFrame.new(0, along, -size.Z / 2 - 0.01)
				* CFrame.Angles(0, 0, math.rad(random:NextNumber(-25, 25))),
			Color = Color3.fromRGB(225, 238, 245),
			Transparency = 0.4,
			Reflectance = 0.35,
			CanCollide = false,
			CastShadow = false,
			Ramp = "plastic",
			Parent = model,
		})
	end
end

function Patient.build(torso: CFrame, parent: Instance): Patient
	local random = Random.new(7)
	local model = Instance.new("Model")
	model.Name = "Patient"
	local tint = colours()

	local anchor = Make.part({
		Name = "TorsoAnchor",
		Size = Vector3.new(2, 2, 1),
		CFrame = torso,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = model,
	})

	local head = Make.part({
		Name = "Head",
		Size = Vector3.new(2, 1, 1),
		CFrame = torso * CFrame.new(0, 1.5, 0),
		Color = tint.Head,
		Ramp = "skin",
		Parent = model,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	head:SetAttribute("PixEllipsoid", Vector3.new(0.62, 0.62, 0.62))
	local face = Instance.new("Decal")
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	type Limb = { name: string, at: Vector3, color: Color3 }
	local limbs: { Limb } = {
		{ name = "Right Arm", at = Vector3.new(1.5, 0, 0), color = tint.RightArm },
		{ name = "Left Arm", at = Vector3.new(-1.5, 0, 0), color = tint.LeftArm },
		{ name = "Right Leg", at = Vector3.new(0.5, -2, 0), color = tint.RightLeg },
		{ name = "Left Leg", at = Vector3.new(-0.5, -2, 0), color = tint.LeftLeg },
	}
	for _, limb in limbs do
		Make.part({
			Name = limb.name,
			Size = Vector3.new(1, 2, 1),
			CFrame = torso * CFrame.new(limb.at),
			Color = limb.color,
			Ramp = "skin",
			Parent = model,
		})
	end

	-- the film: legs together, each arm, the torso's sides (not its front)
	film(model, torso * CFrame.new(0, -2, 0), Vector3.new(2.12, 2.1, 1.12), random)
	film(model, torso * CFrame.new(1.5, 0, 0), Vector3.new(1.1, 2.1, 1.12), random)
	film(model, torso * CFrame.new(-1.5, 0, 0), Vector3.new(1.1, 2.1, 1.12), random)
	for _, x in { -1.02, 1.02 } do
		Make.part({
			Name = "Film",
			Size = Vector3.new(0.04, 2.08, 0.8),
			CFrame = torso * CFrame.new(x, 0, 0.1),
			Color = Make.PLASTIC,
			Transparency = 0.55,
			Reflectance = 0.3,
			CanCollide = false,
			CastShadow = false,
			Ramp = "plastic",
			Parent = model,
		})
	end
	-- (the film's torn edge round the bare front: crumpled strips)
	for _, y in { -0.98, 0.98 } do
		Make.part({
			Name = "FilmEdge",
			Size = Vector3.new(2.1, 0.12, 0.06),
			CFrame = torso
				* CFrame.new(0, y, -0.52)
				* CFrame.Angles(math.rad(random:NextNumber(-20, 20)), 0, 0),
			Color = Color3.fromRGB(220, 235, 242),
			Transparency = 0.35,
			Reflectance = 0.35,
			CanCollide = false,
			CastShadow = false,
			Ramp = "plastic",
			Parent = model,
		})
	end

	model.Parent = parent
	local skin = Skin.new(torso, model, tint.Torso)
	return {
		model = model,
		frame = torso,
		anchor = anchor,
		head = head,
		skin = skin,
	}
end

function Patient.destroy(patient: Patient)
	patient.model:Destroy()
end

return Patient
