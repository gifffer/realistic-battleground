--!strict
-- LiverRip: the Boxer's finisher (Shared/Finishers "KnockoutCombo"): a left
-- hook into the victim's right side, under the ribs; the hand goes in and
-- tears the liver out. CinematicController calls these at the timeline's
-- moments, on every client:
--
--   LiverRip.gut(victim, attacker)   the hand goes in: blood bursts out, bits
--                                     of broken rib
--   LiverRip.rip(victim, attacker)   torn out: the real liver (WoundKit,
--                                     GoreKit "Liver") in his left hand,
--                                     dripping; the hole pours blood
--   LiverRip.drop(attacker)          he throws it down: it lands, splashes
--   LiverRip.cancel(attacker)        (cut short) the liver goes
--
-- The hole itself, broken ribs inside, is a "Tear" cut set by the server at
-- the kill (Gashes draws it, through the clothes).

local Debris = game:GetService("Debris")

local GoreKit = require(script.Parent.GoreKit)
local HeadBlast = require(script.Parent.HeadBlast)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local LiverRip = {}

local LIVER = Color3.fromRGB(96, 28, 24) -- dark red-brown, glossy
local GALLBLADDER = Color3.fromRGB(74, 100, 42)
local BLOOD = Color3.fromRGB(78, 6, 6)
local BLOOD_WET = Color3.fromRGB(104, 8, 8)
local BONE = Color3.fromRGB(224, 212, 188)
local LIFETIME = 14 -- seconds the liver stays on the floor
local POUR_TIME = 3.5 -- seconds the hole pours blood

-- Where the liver was: the victim's right, under the ribs, in front (torso
-- space; the server's "Tear" cut is there too).
local WOUND = Vector3.new(0.5, -0.3, -0.5)

local held: { [Model]: BasePart } = {}

local function wound(victim: Model): CFrame?
	local torso = victim:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return nil
	end
	-- facing out of the front of the torso
	return torso.CFrame * CFrame.new(WOUND + Vector3.new(0, 0, -0.05))
end

local function emitter(parent: Attachment, rate: number): ParticleEmitter
	local blood = Instance.new("ParticleEmitter")
	blood.Name = "Blood"
	blood.Texture = "rbxasset://textures/particles/smoke_main.dds"
	blood.Color = ColorSequence.new(BLOOD_WET, BLOOD)
	blood.LightEmission = 0
	blood.LightInfluence = 1
	blood.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.85, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	blood.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.14),
		NumberSequenceKeypoint.new(1, 0.07),
	})
	blood.Lifetime = NumberRange.new(0.4, 0.8)
	blood.Speed = NumberRange.new(2, 6)
	blood.SpreadAngle = Vector2.new(25, 25)
	blood.Acceleration = Vector3.new(0, -60, 0)
	blood.Drag = 0.5
	blood.EmissionDirection = Enum.NormalId.Front
	blood.Rate = rate
	blood.Parent = parent
	return blood
end

-- A burst of blood (and bits) out of the point `at`, toward `out`.
local function burst(at: CFrame, count: number, speed: number)
	local point = Instance.new("Attachment")
	point.WorldCFrame = at
	point.Parent = workspace.Terrain
	local spray = emitter(point, 0)
	spray.Speed = NumberRange.new(speed * 0.4, speed)
	spray.SpreadAngle = Vector2.new(60, 60)
	spray:Emit(count)
	Debris:AddItem(point, 1.5)
end

local function chip(at: Vector3, color: Color3, size: Vector3, velocity: Vector3)
	local piece = Instance.new("Part")
	piece.Name = "Debris"
	piece.Size = size
	piece.Material = Enum.Material.SmoothPlastic
	piece.Color = color
	piece.CanCollide = true
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CFrame = CFrame.new(at)
		* CFrame.Angles(math.random() * 6.3, math.random() * 6.3, math.random() * 6.3)
	piece.AssemblyLinearVelocity = velocity
	piece.AssemblyAngularVelocity = Vector3.new(
		math.random() - 0.5,
		math.random() - 0.5,
		math.random() - 0.5
	) * 30
	piece.Parent = workspace
	Debris:AddItem(piece, 8)
end

-- The hand goes in under the ribs: blood bursts back out, rib splinters.
function LiverRip.gut(victim: Model, attacker: Model)
	local at = wound(victim)
	if at == nil then
		return
	end
	SoundController.play("RibCrack", victim)
	burst(at, 70, 14)
	local back = (attacker:GetPivot().Position - at.Position)
	local out = if back.Magnitude > 0.1 then back.Unit else at.LookVector
	for _ = 1, 6 do
		chip(
			at.Position,
			BONE,
			Vector3.new(0.03, 0.03, math.random() * 0.12 + 0.08),
			(out + Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)) * 10
		)
	end
end

-- The liver, real (from the kit) or a simple one.
local function newLiver(): BasePart
	local pieces = GoreKit.get()
	local piece = if pieces then pieces.Liver else nil
	if piece then
		return GoreKit.spawn(piece, CFrame.identity, function(layer: string): (Color3, number)
			if layer == "Gallbladder" then
				return GALLBLADDER, 0.18
			end
			return LIVER, 0.14
		end)
	end
	local lump = Instance.new("Part")
	lump.Name = "Liver"
	lump.Shape = Enum.PartType.Ball
	lump.Size = Vector3.new(1, 0.5, 0.65)
	lump.Material = Enum.Material.SmoothPlastic
	lump.Color = LIVER
	lump.Reflectance = 0.14
	return lump
end

-- Torn out: the liver in his left hand, dripping; the hole pours blood.
function LiverRip.rip(victim: Model, attacker: Model)
	LiverRip.cancel(attacker)
	local at = wound(victim)
	local arm = attacker:FindFirstChild("Left Arm")
	SoundController.play("FleshTear", victim)
	if at then
		burst(at, 90, 10)
		-- The hole pours, in spurts, for a while; a pool spreads under it.
		local torso = victim:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			local hole = Instance.new("Attachment")
			hole.Name = "LiverHole"
			hole.CFrame = CFrame.new(WOUND + Vector3.new(0, 0, -0.05))
				* CFrame.Angles(0, math.pi, 0) -- (Front = out of the torso)
			hole.Parent = torso
			local pour = emitter(hole, 40)
			task.spawn(function()
				local start = os.clock()
				while hole.Parent and os.clock() - start < POUR_TIME do
					local fade = 1 - (os.clock() - start) / POUR_TIME
					pour.Rate = 120 * fade
					task.wait(0.15)
					pour.Rate = 20 * fade
					task.wait(0.4)
				end
				pour.Rate = 0
				Debris:AddItem(hole, 1.5)
			end)
			task.delay(0.5, function()
				if torso.Parent then
					HeadBlast.pool(
						torso.Position,
						3.6,
						POUR_TIME + 2,
						math.floor(at.X * 13 + at.Z * 7)
					)
				end
			end)
		end
	end
	if arm == nil or not arm:IsA("BasePart") then
		return
	end
	-- In the fist, hanging out of it.
	local liver = newLiver()
	liver.CanCollide = false
	liver.Massless = true
	liver.Anchored = false
	liver:PivotTo(arm.CFrame * CFrame.new(0, -1.25, -0.15) * CFrame.Angles(0, 0, math.rad(80)))
	local weld = Instance.new("WeldConstraint")
	weld.Name = "Held"
	weld.Part0 = arm
	weld.Part1 = liver
	weld.Parent = liver
	local drip = Instance.new("Attachment")
	drip.Parent = liver
	local drops = emitter(drip, 30)
	drops.EmissionDirection = Enum.NormalId.Bottom
	drops.Speed = NumberRange.new(0.5, 2)
	liver.Parent = workspace
	held[attacker] = liver
	Debris:AddItem(liver, LIFETIME + 6)
end

-- Thrown down at his feet: it lands with a wet slap and a splash.
function LiverRip.drop(attacker: Model)
	local liver: BasePart? = held[attacker]
	held[attacker] = nil
	if liver == nil or liver.Parent == nil then
		return
	end
	local weld = liver:FindFirstChild("Held")
	if weld then
		weld:Destroy()
	end
	liver.Massless = false
	liver.CanCollide = true
	local forward = attacker:GetPivot().LookVector
	liver.AssemblyLinearVelocity = forward * 6
		+ Vector3.new(0, -8, 0)
		+ attacker:GetPivot().RightVector * -3
	liver.AssemblyAngularVelocity = Vector3.new(4, 2, 6)
	task.delay(0.35, function()
		if liver.Parent then
			SoundController.play("OrganDrop", attacker)
			HeadBlast.splash(
				liver.Position,
				1.4,
				math.floor(liver.Position.X * 11 + liver.Position.Z * 5)
			)
		end
	end)
end

-- Cut short (or a new one): the liver he holds goes.
function LiverRip.cancel(attacker: Model)
	local liver = held[attacker]
	held[attacker] = nil
	if liver then
		liver:Destroy()
	end
end

return table.freeze(LiverRip)
