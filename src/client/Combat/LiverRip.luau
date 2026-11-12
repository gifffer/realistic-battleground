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
local Blood = require(script.Parent.Blood)
local BloodGush = require(script.Parent.BloodGush)
local HeadBlast = require(script.Parent.HeadBlast)
local Squish = require(script.Parent.Squish)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local LiverRip = {}

local LIVER = Color3.fromRGB(96, 28, 24) -- dark red-brown, glossy
local GALLBLADDER = Color3.fromRGB(74, 100, 42)
local BLOOD = Color3.fromRGB(78, 6, 6)
local BLOOD_WET = Color3.fromRGB(104, 8, 8)
local BONE = Color3.fromRGB(224, 212, 188)
local LIFETIME = 240 -- seconds at most the liver stays (it goes with the body before)

-- Where the liver was: the victim's right, under the ribs, in front (torso
-- space; the server's "Tear" cut is there too).
local WOUND = Vector3.new(0.5, -0.3, -0.5)

-- The liver each attacker holds. (A plain table, emptied by drop / cancel
-- or when he goes: a weak one could lose it - then it was never let go.)
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
	-- the hand going in: blood bursts out around the arm, onto him too
	Blood.spray(at.Position, out + Vector3.new(0, 0.5, 0), 3.5, victim)
	Blood.spray(at.Position, Vector3.new(0, -1, 0) + at.LookVector, 2, victim)
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
	-- (a sphere mesh, not a Ball part: it can be squashed)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = lump
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
		-- torn out: thick blood pulled out with it, strings, drops
		Blood.spray(at.Position, at.LookVector + Vector3.new(0, 0.4, 0), 4.5, victim)
		-- The vessels of the liver torn: the hole spurts with each beat and
		-- runs down the side, a pool spreads; it gets all over him.
		BloodGush.torso(
			victim,
			WOUND + Vector3.new(0, 0, -0.05),
			Vector3.new(0.35, -0.25, -1),
			math.floor(at.X * 13 + at.Z * 7),
			7
		)
		BloodGush.splatter(attacker, at.Position, 16, math.floor(at.Z * 11 + at.X * 3))
	end
	if arm == nil or not arm:IsA("BasePart") then
		warn("[LiverRip] no Left Arm to hold the liver")
		return
	end
	-- In the fist, hanging out of it.
	local liver = newLiver()
	liver.CanCollide = false
	liver.Massless = true
	liver.Anchored = false
	-- (its CFrame, not PivotTo: an imported piece's pivot is elsewhere)
	liver.CFrame = arm.CFrame * CFrame.new(0, -1.25, -0.15) * CFrame.Angles(0, 0, math.rad(80))
	liver:SetAttribute("LiverOf", attacker.Name)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "Held"
	weld.Part0 = arm
	weld.Part1 = liver
	weld.Parent = liver
	-- dripping thick drops while he holds it
	task.defer(function() -- (once it is in the workspace, below)
		while liver.Parent and liver:FindFirstChild("Held") do
			Blood.drop(
				liver.Position - Vector3.new(0, 0.3, 0),
				liver.AssemblyLinearVelocity * 0.5,
				Random.new():NextNumber(0.06, 0.11)
			)
			task.wait(Random.new():NextNumber(0.08, 0.2))
		end
	end)
	local drip = Instance.new("Attachment")
	drip.Parent = liver
	local drops = emitter(drip, 30)
	drops.EmissionDirection = Enum.NormalId.Bottom
	drops.Speed = NumberRange.new(0.5, 2)
	liver.Parent = workspace
	-- soft and wet: it jiggles in his hand, slaps and slumps on the floor
	-- (its surface detail first, in the workspace: then it squashes too)
	Squish.detail(liver, "Liver")
	Squish.soft(liver, { softness = 0.45, sag = 0.2, stiffness = 200, lifetime = LIFETIME })
	held[attacker] = liver
	attacker.Destroying:Once(function()
		if held[attacker] == liver then
			held[attacker] = nil
		end
	end)
	Debris:AddItem(liver, LIFETIME + 6)
	-- (it stays until the body it came from is removed)
	local function remove()
		if liver.Parent and not liver:FindFirstChild("Held") then
			liver:Destroy()
		end
	end
	victim.Destroying:Once(remove)
	victim.AncestryChanged:Connect(function()
		if victim.Parent == nil then
			remove()
		end
	end)
end

-- He opens his hand: the liver drops to the floor; a wet slap and a
-- splash when it lands.
function LiverRip.drop(attacker: Model)
	local liver: BasePart? = held[attacker]
	held[attacker] = nil
	if liver == nil or liver.Parent == nil then
		-- (lost track of it? find it in his hand)
		for _, item in workspace:GetChildren() do
			if
				item:IsA("BasePart")
				and item:GetAttribute("LiverOf") == attacker.Name
				and item:FindFirstChild("Held")
			then
				liver = item
			end
		end
	end
	if liver == nil then
		warn("[LiverRip] no liver in the hand to drop")
		return
	end
	local weld = liver:FindFirstChild("Held")
	if weld then
		weld:Destroy()
	end
	liver.Massless = false
	liver.CanCollide = true
	-- (it slips out of the fist, out to his side - away from the body that
	-- falls in front of him - turning over)
	local pivot = attacker:GetPivot()
	liver.AssemblyLinearVelocity = -pivot.RightVector * 2.2
		+ pivot.LookVector * 0.4
		+ Vector3.new(0, -1, 0)
	liver.AssemblyAngularVelocity = Vector3.new(2.5, 0.8, 3)
	-- When it reaches the floor (a free fall from where it is).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { liver, attacker }
	local floor = workspace:Raycast(liver.Position, Vector3.new(0, -20, 0), params)
	local height = if floor then math.max(0, liver.Position.Y - floor.Position.Y - 0.25) else 3
	local fall = math.sqrt(2 * height / workspace.Gravity) + 1 / workspace.Gravity
	task.delay(fall, function()
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
