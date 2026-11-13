--!strict
-- LiverRip: the Boxer's finisher (Shared/Finishers "KnockoutCombo"): a left
-- hook into the victim's right side, under the ribs; the hand goes in and
-- tears the liver out. CinematicController calls these at the timeline's
-- moments, on every client:
--
--   LiverRip.gut(victim, attacker)    the hand goes in: blood bursts out
--                                     round the arm, onto him, bits of rib
--   LiverRip.dig(victim, attacker, wrench)  it digs / turns inside: blood
--                                     pushed out round the wrist, running
--   LiverRip.rip(victim, attacker)    torn out: the real liver (WoundKit,
--                                     GoreKit "Liver", soft: Squish) in his
--                                     left fist, strings of torn vessels
--                                     stretching from the hole and
--                                     snapping; the hole pours blood
--   LiverRip.squeeze(attacker)        his fist closes on it: it squashes,
--                                     blood runs out between the fingers
--   LiverRip.drop(attacker)           he lets go: it lands, slaps, splashes
--   LiverRip.cancel(attacker)         (cut short) the liver goes
--
-- The hole itself, broken ribs inside, is a "Tear" cut set by the server
-- when the hand goes in (Gashes draws it, through the clothes).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Corpse = require(ReplicatedStorage.Shared.Util.Corpse)
local Finishers = require(ReplicatedStorage.Shared.Finishers)
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
local VESSEL = Color3.fromRGB(88, 12, 14) -- torn vessels, ligament
local BONE = Color3.fromRGB(224, 212, 188)
local LIFETIME = 240 -- seconds at most the liver stays (it goes with the body before)

-- Where the liver was (the victim's Torso space; the server's "Tear" cut is
-- there too), just out of the skin.
local WOUND = Finishers.LIVER_WOUND + Vector3.new(0, 0, -0.05)

local random = Random.new()

-- The liver each attacker holds. (A plain table, emptied by drop / cancel
-- or when he goes: a weak one could lose it - then it was never let go.)
local held: { [Model]: BasePart } = {}

local function wound(victim: Model): CFrame?
	local torso = victim:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return nil
	end
	-- facing out of the front of the torso
	return torso.CFrame * CFrame.new(WOUND)
end

-- Which way out of the wound, toward him (blood thrown back at the arm).
local function outward(at: CFrame, attacker: Model): Vector3
	local back = attacker:GetPivot().Position - at.Position
	return if back.Magnitude > 0.1 then back.Unit else at.LookVector
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

-- A burst of blood out of the point `at`, along its LookVector.
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
		* CFrame.Angles(
			random:NextNumber(0, 6.3),
			random:NextNumber(0, 6.3),
			random:NextNumber(0, 6.3)
		)
	piece.AssemblyLinearVelocity = velocity
	piece.AssemblyAngularVelocity = random:NextUnitVector() * 15
	piece.Parent = workspace
	Debris:AddItem(piece, 8)
end

-- Ropes of thick blood hanging off `point`, falling (`out`: thrown that way).
local function ropes(point: Vector3, out: Vector3, count: number, source: Model?)
	for _ = 1, count do
		Blood.strand(
			point,
			out * random:NextNumber(1, 3) + Vector3.new(0, random:NextNumber(-3, 0), 0),
			random:NextNumber(0.05, 0.085),
			source
		)
	end
end

-- The hand goes in under the ribs: blood bursts back out round the arm and
-- all over him, rib splinters; a choked gasp.
function LiverRip.gut(victim: Model, attacker: Model)
	local at = wound(victim)
	if at == nil then
		return
	end
	SoundController.play("RibCrack", victim)
	SoundController.play("Choke", victim)
	local out = outward(at, attacker)
	burst(at, 110, 16)
	burst(CFrame.lookAt(at.Position, at.Position + out), 60, 12)
	Blood.mist(at.Position, out + Vector3.new(0, 0.3, 0), 2.2)
	-- the hand going in: blood bursts out round the arm, onto him too
	Blood.spray(at.Position, out + Vector3.new(0, 0.5, 0), 4.5, victim)
	Blood.spray(at.Position, Vector3.new(0, -1, 0) + at.LookVector, 2.5, victim)
	ropes(at.Position, at.LookVector, 3, victim)
	BloodGush.splatter(attacker, at.Position, 12, math.floor(at.X * 7 + at.Z * 13))
	for _ = 1, 9 do
		chip(
			at.Position,
			BONE,
			Vector3.new(0.03, 0.03, random:NextNumber(0.08, 0.2)),
			(
				out
				+ Vector3.new(
					random:NextNumber(-0.5, 0.5),
					random:NextNumber(0, 0.8),
					random:NextNumber(-0.5, 0.5)
				)
			) * 10
		)
	end
end

-- The hand digs (or `wrench`: turns) inside: blood forced out round the
-- wrist, running down the side.
function LiverRip.dig(victim: Model, attacker: Model, wrench: boolean)
	local at = wound(victim)
	if at == nil then
		return
	end
	SoundController.play(if wrench then "RibCrack" else "BodyShot", victim)
	if wrench then
		SoundController.play("HurtGrunt", victim)
	end
	local out = outward(at, attacker)
	burst(at, if wrench then 70 else 45, if wrench then 11 else 8)
	Blood.spray(
		at.Position,
		at.LookVector + Vector3.new(0, -0.6, 0),
		if wrench then 2.5 else 1.5,
		victim
	)
	ropes(at.Position, at.LookVector * 0.5 + out * 0.5, if wrench then 3 else 2, victim)
	local torso = victim:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		BloodGush.runDown(torso, WOUND, if wrench then 4 else 3, math.floor(at.Y * 17 + at.X * 5))
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

-- Torn vessels and ligament: strings from the hole to the liver in his
-- fist, stretching as he pulls it away, snapping one after the other (a
-- whip of blood off each end).
local function vessels(victim: Model, liver: BasePart)
	local torso = victim:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return
	end
	local root = Instance.new("Attachment")
	root.Name = "TornVessels"
	root.Position = WOUND
	root.Parent = torso
	local tip = Instance.new("Attachment")
	tip.Name = "TornVessels"
	tip.Parent = liver
	local longest = 0
	for index = 1, 4 do
		local beam = Instance.new("Beam")
		beam.Name = "Vessel"
		beam.Attachment0 = root
		beam.Attachment1 = tip
		beam.Color = ColorSequence.new(BLOOD_WET, VESSEL)
		beam.Transparency = NumberSequence.new(0)
		beam.LightInfluence = 1
		beam.LightEmission = 0
		beam.FaceCamera = true
		beam.Segments = 12
		local width = if index == 1 then 0.09 else random:NextNumber(0.025, 0.055)
		beam.Width0 = width
		beam.Width1 = width * 0.7
		-- (sagging, each its own way)
		beam.CurveSize0 = random:NextNumber(-0.5, 0.5)
		beam.CurveSize1 = random:NextNumber(-0.6, 0.1)
		beam.Parent = liver
		-- the thick one holds longest
		local snap = if index == 1
			then random:NextNumber(0.32, 0.42)
			else random:NextNumber(0.06, 0.28)
		longest = math.max(longest, snap)
		task.delay(snap, function()
			if beam.Parent == nil then
				return
			end
			beam:Destroy()
			-- each end whips back, dripping
			if root.Parent then
				ropes(root.WorldPosition, Vector3.new(0, -1, 0), 1, victim)
			end
			if tip.Parent then
				Blood.strand(tip.WorldPosition, Vector3.new(0, -2, 0), width * 0.9, nil)
				Blood.drop(tip.WorldPosition, random:NextUnitVector() * 3, width)
			end
		end)
	end
	Debris:AddItem(root, longest + 0.2)
	Debris:AddItem(tip, longest + 0.2)
end

-- Torn out: the liver in his left fist, dripping, the vessels snapping; the
-- hole pours blood.
function LiverRip.rip(victim: Model, attacker: Model)
	LiverRip.cancel(attacker)
	local at = wound(victim)
	local arm = attacker:FindFirstChild("Left Arm")
	SoundController.play("FleshTear", victim)
	if at then
		burst(at, 120, 12)
		-- torn out: thick blood pulled out with it, strings, drops
		Blood.spray(at.Position, at.LookVector + Vector3.new(0, 0.4, 0), 5, victim)
		Blood.mist(at.Position, at.LookVector, 1.8)
		ropes(at.Position, at.LookVector, 3, victim)
		-- The vessels of the liver torn: the hole spurts with each beat and
		-- runs down the side, a pool spreads; it gets all over him.
		BloodGush.torso(
			victim,
			WOUND,
			Vector3.new(0.35, -0.25, -1),
			math.floor(at.X * 13 + at.Z * 7),
			8
		)
		BloodGush.splatter(attacker, at.Position, 18, math.floor(at.Z * 11 + at.X * 3))
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
	liver.CFrame = arm.CFrame * Finishers.LIVER_GRIP
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
				random:NextNumber(0.06, 0.11)
			)
			task.wait(random:NextNumber(0.08, 0.2))
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
	-- (wrenched out: it wobbles in the fist)
	Squish.squeeze(liver, arm.CFrame.UpVector, 0.3)
	if at then
		vessels(victim, liver)
	end
	held[attacker] = liver
	attacker.Destroying:Once(function()
		if held[attacker] == liver then
			held[attacker] = nil
		end
	end)
	Debris:AddItem(liver, LIFETIME + 6)
	-- (it stays until the body it came from is removed; a body left by a
	-- finisher stays a while longer, as a copy: Server/Systems/Corpses)
	local gone = false
	local moved: RBXScriptConnection? = nil
	local function remove()
		if gone then
			return
		end
		gone = true
		if moved then
			moved:Disconnect()
		end
		task.delay(Corpse.timeLeft(victim), function()
			if liver.Parent and not liver:FindFirstChild("Held") then
				liver:Destroy()
			end
		end)
	end
	victim.Destroying:Once(remove)
	moved = victim.AncestryChanged:Connect(function()
		if victim.Parent == nil then
			remove()
		end
	end)
end

-- His fist closes on it: it squashes, blood runs out between the fingers
-- and down his wrist.
function LiverRip.squeeze(attacker: Model)
	local liver: BasePart? = held[attacker]
	if liver == nil or liver.Parent == nil then
		return
	end
	local arm = attacker:FindFirstChild("Left Arm")
	local across = if arm and arm:IsA("BasePart") then arm.CFrame.RightVector else Vector3.xAxis
	Squish.squeeze(liver, across, 0.42)
	local sound = SoundController.play("FleshTear", attacker)
	if sound then
		-- (shorter and wetter than the tear itself)
		sound.Volume *= 0.55
		sound.PlaybackSpeed *= 1.3
	end
	local at = liver.Position
	burst(CFrame.lookAt(at, at - Vector3.yAxis), 50, 5)
	Blood.spray(at, Vector3.new(0, -1, 0) + across * 0.4, 1.4, attacker)
	ropes(at, across * 0.3, 3, attacker)
	if arm and arm:IsA("BasePart") then
		-- it runs down his wrist and forearm
		BloodGush.runDown(arm, Vector3.new(0, -0.8, 0), 3, math.floor(at.X * 19 + at.Y * 3))
	end
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
		+ Vector3.new(0, -2, 0)
	liver.AssemblyAngularVelocity = Vector3.new(2.5, 0.8, 3)
	-- When it reaches the floor (a fall from where it is).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { liver, attacker }
	local floor = workspace:Raycast(liver.Position, Vector3.new(0, -20, 0), params)
	local height = if floor then math.max(0, liver.Position.Y - floor.Position.Y - 0.25) else 3
	local g = workspace.Gravity
	-- (thrown down at 2 studs/s: h = 2t + g t^2 / 2)
	local fall = (-2 + math.sqrt(4 + 2 * g * height)) / g + 1 / g
	task.delay(fall, function()
		if liver.Parent then
			SoundController.play("OrganDrop", attacker)
			HeadBlast.splash(
				liver.Position,
				1.6,
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
