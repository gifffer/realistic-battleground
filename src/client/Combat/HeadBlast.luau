--!strict
-- HeadBlast: the head that bursts under the bat (Street Brawler finisher).
--
-- The server sets the attribute "HeadBlown" (= a seed) on the body when the
-- bat lands. Every client then:
--   • hides the head, its face and the head accessories (Gashes hides the
--     head itself, so its cuts never come back over it);
--   • leaves what a real blow like that leaves: the lower jaw and a few
--     teeth, the open neck (torn skin, flesh, windpipe, the top of the
--     spine), the heart still pumping blood out of it in spurts, a pool
--     spreading under it;
--   • when it happens in front of us (not a body we only see later): the
--     burst itself — thin pieces of skull (scalp outside, bone inside), brain,
--     an eye, teeth, a spray and a mist of blood, the hair / hat sent flying,
--     and on the floor a big splash with drops thrown out in lines, the way
--     real blood spatters. The same pieces on every client (the seed).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local HeadBlast = {}

HeadBlast.ATTRIBUTE = "HeadBlown"

local BLOOD = Color3.fromRGB(86, 10, 9) -- dark, as it is once out
local BLOOD_WET = Color3.fromRGB(116, 12, 11) -- fresh, catching the light
local FLESH = Color3.fromRGB(122, 28, 30)
local FLESH_DARK = Color3.fromRGB(84, 16, 18)
local BONE = Color3.fromRGB(224, 212, 188)
local BONE_EDGE = Color3.fromRGB(196, 160, 140) -- broken edge, a bit of blood in it
local BRAIN = Color3.fromRGB(198, 140, 136)
local BRAIN_BLOODY = Color3.fromRGB(152, 72, 72)
local TOOTH = Color3.fromRGB(236, 230, 212)
local PIECE_LIFETIME = 10 -- seconds the pieces stay on the floor
local MARK_LIFETIME = 12 -- seconds the blood stays on the floor
local MAX_MARKS = 140 -- blood marks on the floor at once (several finishers...)
local PUMP_TIME = 4.5 -- seconds the neck keeps pumping blood
local BEAT = 0.55 -- seconds between two spurts (a racing heart)

local done: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- (gore off in Config: no burst, the head stays)
function HeadBlast.isBlown(model: Model): boolean
	return Config.Injuries.SKIN_TEAR and model:GetAttribute(HeadBlast.ATTRIBUTE) ~= nil
end

------------------------------------------------------------------------------
-- Hiding the head
------------------------------------------------------------------------------

-- Out of sight for good (Transparency, not LocalTransparencyModifier: the
-- bruise marks of Wounds reset that one).
local function hide(item: Instance)
	if item:IsA("BasePart") or item:IsA("Decal") then
		(item :: any).Transparency = 1
	elseif item:IsA("SurfaceGui") then
		item.Enabled = false
	end
end

-- The head accessories, and everything stuck on the head (bruise marks,
-- glass shards), even what comes later.
local function hideAll(model: Model, head: BasePart)
	for _, accessory in model:GetChildren() do
		if accessory:IsA("Accessory") then
			for _, item in accessory:GetDescendants() do
				hide(item)
			end
		end
	end
	for _, item in head:GetDescendants() do
		hide(item)
	end
	head.DescendantAdded:Connect(hide)
end

------------------------------------------------------------------------------
-- Blood on the floor
------------------------------------------------------------------------------

local marks: { BasePart } = {}
local markCount = 0 -- (never goes down: each new mark a hair higher)

-- The floor under `position` (through every fighter), or nil.
local function floorUnder(position: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged(Config.Combat.TAG)
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), params)
	if hit and hit.Instance.Parent and hit.Instance.Parent:FindFirstChildOfClass("Humanoid") then
		return nil
	end
	return hit
end

-- A flat mark of blood on the floor: round (`length` = nil) or a streak
-- `length` long pointing along `along` (where the drop was going).
local function mark(
	position: Vector3,
	width: number,
	length: number?,
	along: Vector3?,
	color: Color3,
	lifetime: number?
): BasePart?
	local hit = floorUnder(position)
	if hit == nil then
		return nil
	end
	local piece = Instance.new("Part")
	piece.Name = "Blood"
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.Material = Enum.Material.SmoothPlastic
	piece.Color = color
	piece.Reflectance = 0.08 -- wet
	piece.Transparency = 0.08
	-- (each new one a hair higher: no flicker where they overlap)
	markCount += 1
	local lift = 0.012 + (markCount % 12) * 0.002
	local up = hit.Normal
	if length and along and along.Magnitude > 1e-3 then
		local forward = (along - up * along:Dot(up)).Unit
		piece.Size = Vector3.new(width, 0.01, length)
		piece.CFrame =
			CFrame.lookAt(hit.Position + up * lift, hit.Position + up * lift + forward, up)
	else
		piece.Shape = Enum.PartType.Cylinder
		piece.Size = Vector3.new(0.01, width, width)
		piece.CFrame = CFrame.lookAt(hit.Position + up * lift, hit.Position + up * 2)
			* CFrame.Angles(0, math.rad(90), 0)
	end
	piece.Parent = workspace
	table.insert(marks, piece)
	if #marks > MAX_MARKS then
		local oldest = table.remove(marks, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local life = lifetime or MARK_LIFETIME
	task.delay(life * 0.7, function()
		if piece.Parent then
			TweenService:Create(piece, TweenInfo.new(life * 0.3), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(piece, life)
	return piece
end

-- An irregular splash: a blot made of a few overlapping round ones, and
-- small drops around it.
local function splash(position: Vector3, size: number, random: Random)
	mark(position, size, nil, nil, BLOOD)
	for _ = 1, random:NextInteger(3, 5) do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = size * random:NextNumber(0.25, 0.5)
		mark(
			position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance,
			size * random:NextNumber(0.35, 0.65),
			nil,
			nil,
			if random:NextNumber() < 0.5 then BLOOD else BLOOD_WET
		)
	end
	for _ = 1, random:NextInteger(4, 8) do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = size * random:NextNumber(0.6, 1.1)
		mark(
			position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance,
			random:NextNumber(0.06, 0.16),
			nil,
			nil,
			BLOOD
		)
	end
end

-- Drops thrown out along `direction`: they land in a line, the first ones
-- big and stretched (fast), smaller and rounder farther (as they slow).
local function castOff(from: Vector3, direction: Vector3, reach: number, random: Random)
	local count = random:NextInteger(5, 9)
	for index = 1, count do
		local along = index / count
		local distance = reach * (0.25 + along * 0.75) * random:NextNumber(0.9, 1.1)
		local sideways = direction:Cross(Vector3.new(0, 1, 0)) * random:NextNumber(-0.12, 0.12)
		local at = from + direction * distance + sideways
		local size = (1 - along * 0.75) * random:NextNumber(0.08, 0.16)
		task.delay(distance / 22, function() -- (the time it flies)
			mark(at, size, size * (1 + (1 - along) * 3.5), direction, BLOOD)
		end)
	end
end

------------------------------------------------------------------------------
-- What's left on the body
------------------------------------------------------------------------------

local function welded(part: BasePart, to: BasePart, cframe: CFrame, parent: Instance)
	part.CFrame = cframe
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
	part.Parent = parent
end

local function newPart(name: string, size: Vector3, color: Color3, wet: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Reflectance = if wet then 0.12 else 0
	return part
end

local function cylinder(
	name: string,
	length: number,
	diameter: number,
	color: Color3,
	wet: boolean
): Part
	local part = newPart(name, Vector3.new(length, diameter, diameter), color, wet)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- What's left on top of the torso: the neck torn open, the lower jaw with a
-- few teeth. Returns the point the blood comes out of.
local function buildStump(torso: BasePart, skin: Color3, random: Random): Attachment
	local folder = Instance.new("Folder")
	folder.Name = "HeadBlast"
	-- (torso space: Y up the body, -Z its front)
	local top = torso.CFrame * CFrame.new(0, torso.Size.Y / 2, 0)
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis along Y

	-- The neck: skin around, wet flesh inside, the windpipe at the front,
	-- the spine at the back sticking out.
	welded(
		cylinder("Neck", 0.34, 0.92, skin, false),
		torso,
		top * CFrame.new(0, 0.12, 0) * upright,
		folder
	)
	welded(
		cylinder("Flesh", 0.36, 0.78, FLESH, true),
		torso,
		top * CFrame.new(0, 0.14, 0) * upright,
		folder
	)
	welded(
		cylinder("Windpipe", 0.38, 0.2, FLESH_DARK, true),
		torso,
		top * CFrame.new(0, 0.16, -0.22) * upright,
		folder
	)
	welded(
		cylinder("Spine", 0.5, 0.2, BONE, false),
		torso,
		top * CFrame.new(0, 0.3, 0.2) * CFrame.Angles(math.rad(-8), 0, 0) * upright,
		folder
	)
	welded(
		cylinder("Vertebra", 0.06, 0.3, BONE_EDGE, false),
		torso,
		top * CFrame.new(0, 0.5, 0.22) * upright,
		folder
	)

	-- The lower jaw, still there at the front, a few teeth in it.
	local jawAt = top * CFrame.new(0, 0.36, -0.3) * CFrame.Angles(math.rad(12), 0, 0)
	welded(newPart("Jaw", Vector3.new(0.82, 0.24, 0.46), skin, false), torso, jawAt, folder)
	welded(
		newPart("JawFlesh", Vector3.new(0.7, 0.04, 0.36), FLESH, true),
		torso,
		jawAt * CFrame.new(0, 0.13, 0.03),
		folder
	)
	for index = 1, 7 do
		if random:NextNumber() < 0.7 then -- (some knocked out)
			local angle = math.rad(-60 + (index - 1) * 20)
			welded(
				newPart(
					"Tooth",
					Vector3.new(0.07, random:NextNumber(0.08, 0.12), 0.06),
					TOOTH,
					false
				),
				torso,
				jawAt
					* CFrame.new(math.sin(angle) * 0.3, 0.17, -math.cos(angle) * 0.17 + 0.04)
					* CFrame.Angles(math.rad(random:NextNumber(-15, 15)), angle, 0),
				folder
			)
		end
	end

	-- Torn skin all around the edge (curling out), shreds of flesh on top.
	for index = 1, 11 do
		local angle = index / 11 * math.pi * 2 + random:NextNumber(-0.2, 0.2)
		local flap = newPart(
			"Flap",
			Vector3.new(random:NextNumber(0.16, 0.3), random:NextNumber(0.12, 0.32), 0.035),
			if index % 4 == 0 then FLESH else skin,
			false
		)
		welded(
			flap,
			torso,
			top
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, 0.3, -0.45)
				* CFrame.Angles(
					math.rad(random:NextNumber(-50, -15)),
					0,
					math.rad(random:NextNumber(-20, 20))
				),
			folder
		)
	end
	for _ = 1, 8 do
		local shred = newPart(
			"Shred",
			Vector3.new(
				random:NextNumber(0.06, 0.16),
				random:NextNumber(0.04, 0.1),
				random:NextNumber(0.06, 0.16)
			),
			if random:NextNumber() < 0.5 then FLESH else FLESH_DARK,
			true
		)
		welded(
			shred,
			torso,
			top
				* CFrame.new(random:NextNumber(-0.3, 0.3), 0.32, random:NextNumber(-0.25, 0.3))
				* CFrame.Angles(random:NextNumber(0, 6.3), random:NextNumber(0, 6.3), 0),
			folder
		)
	end
	-- Blood run down the front of the chest.
	for index = 1, 3 do
		welded(
			newPart(
				"Run",
				Vector3.new(random:NextNumber(0.08, 0.16), random:NextNumber(0.4, 1.1), 0.012),
				BLOOD_WET,
				true
			),
			torso,
			torso.CFrame
				* CFrame.new(
					(index - 2) * 0.28 + random:NextNumber(-0.06, 0.06),
					0.55,
					-torso.Size.Z / 2 - 0.007
				),
			folder
		)
	end
	folder.Parent = torso

	local mouth = Instance.new("Attachment")
	mouth.Name = "HeadBlastBlood"
	mouth.Position = Vector3.new(0, torso.Size.Y / 2 + 0.3, 0)
	mouth.Parent = torso
	return mouth
end

------------------------------------------------------------------------------
-- Blood in the air
------------------------------------------------------------------------------

local function bloodEmitter(parent: Attachment): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Blood"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(BLOOD_WET, BLOOD)
	emitter.LightEmission = 0
	emitter.LightInfluence = 1
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.85, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16),
		NumberSequenceKeypoint.new(1, 0.08),
	})
	emitter.Lifetime = NumberRange.new(0.45, 0.8)
	emitter.Speed = NumberRange.new(5, 9)
	emitter.SpreadAngle = Vector2.new(14, 14)
	emitter.Acceleration = Vector3.new(0, -60, 0) -- it falls (studs/s²)
	emitter.Drag = 0.6
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
end

-- The neck pumps blood in spurts (the heart still beats a few times, weaker
-- each time); a pool spreads under it.
local function pump(model: Model, mouth: Attachment, random: Random)
	local emitter = bloodEmitter(mouth)
	local below = mouth.WorldPosition
	local pool: { BasePart } = {}
	for index = 1, 3 do
		local offset =
			Vector3.new(random:NextNumber(-0.35, 0.35), 0, random:NextNumber(-0.35, 0.35))
		local piece =
			mark(below + offset, 0.3, nil, nil, if index == 1 then BLOOD else BLOOD_WET, 25)
		if piece then
			table.insert(pool, piece)
		end
	end
	for index, piece in pool do
		local grown = Vector3.new(0.01, 1, 1) * (3.4 - index * 0.6) * random:NextNumber(0.85, 1.1)
		TweenService:Create(
			piece,
			TweenInfo.new(PUMP_TIME + 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = grown }
		):Play()
	end
	task.spawn(function()
		local start = os.clock()
		while mouth.Parent and os.clock() - start < PUMP_TIME do
			local fade = 1 - (os.clock() - start) / PUMP_TIME
			emitter.Speed = NumberRange.new(3 + 6 * fade, 6 + 9 * fade)
			emitter.Rate = 160 * fade -- a spurt
			task.wait(0.14)
			emitter.Rate = 10 * fade -- between two
			task.wait(BEAT - 0.14)
		end
		emitter.Rate = 0
		Debris:AddItem(emitter, 1)
	end)
	-- (this body's pieces go with it)
	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			emitter.Rate = 0
		end
	end)
end

------------------------------------------------------------------------------
-- The burst
------------------------------------------------------------------------------

-- A flying piece (collides with the floor, never with fighters' clicks).
local function fly(piece: BasePart, at: Vector3, velocity: Vector3, random: Random)
	piece.CanCollide = true
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CFrame = CFrame.new(at + random:NextUnitVector() * 0.25)
		* CFrame.Angles(
			random:NextNumber(0, 6.3),
			random:NextNumber(0, 6.3),
			random:NextNumber(0, 6.3)
		)
	piece.AssemblyLinearVelocity = velocity
	piece.AssemblyAngularVelocity = random:NextUnitVector() * random:NextNumber(8, 28)
	piece.Parent = workspace
	Debris:AddItem(piece, PIECE_LIFETIME)
end

-- Two parts stuck together into one piece (the other one rides along).
local function stuck(main: BasePart, other: BasePart, offset: CFrame)
	other.CFrame = main.CFrame * offset
	other.CanCollide = false
	other.CanQuery = false
	other.CanTouch = false
	other.Massless = true
	-- (a Weld with its offset: right wherever the main part is put later)
	local weld = Instance.new("Weld")
	weld.Part0 = main
	weld.Part1 = other
	weld.C0 = offset
	weld.Parent = other
	other.Parent = main
end

-- Away from the blow: mostly sideways and up (the bat came from above), a
-- bit more away from the attacker.
local function outward(random: Random, away: Vector3, up: number, speed: number): Vector3
	local angle = random:NextNumber(0, math.pi * 2)
	local flat = Vector3.new(math.cos(angle), 0, math.sin(angle)) + away * 0.6
	return (flat.Unit + Vector3.new(0, random:NextNumber(up * 0.3, up), 0)).Unit
		* speed
		* random:NextNumber(0.4, 1)
end

local function burst(model: Model, head: BasePart, torso: BasePart, random: Random)
	local at = head.Position
	local skin = head.Color
	-- Away from the attacker: he stands past the head, so toward the body.
	local flat = Vector3.new(torso.Position.X - at.X, 0, torso.Position.Z - at.Z)
	local away = if flat.Magnitude > 0.1 then flat.Unit * 0.7 else Vector3.zero

	-- Skull: thin curved plates, scalp on the outside, bone on the inside;
	-- a few bare bone splinters.
	for index = 1, 15 do
		local width = random:NextNumber(0.16, 0.36)
		local depth = random:NextNumber(0.12, 0.3)
		local plate: BasePart
		if index % 3 == 0 then
			plate = Instance.new("WedgePart")
		else
			plate = Instance.new("Part")
		end
		plate.Name = "Skull"
		plate.Size = Vector3.new(width, 0.05, depth)
		plate.Material = Enum.Material.SmoothPlastic
		plate.Color = skin
		local bone = newPart("Bone", Vector3.new(width * 0.92, 0.04, depth * 0.92), BONE, false)
		stuck(plate, bone, CFrame.new(0, -0.045, 0))
		local edge = newPart("Edge", Vector3.new(width * 0.95, 0.02, 0.02), BONE_EDGE, true)
		stuck(plate, edge, CFrame.new(0, -0.02, depth * 0.46))
		fly(plate, at, outward(random, away, 1.5, 24), random)
	end
	for _ = 1, 6 do
		local splinter = newPart(
			"Splinter",
			Vector3.new(random:NextNumber(0.04, 0.08), 0.03, random:NextNumber(0.12, 0.24)),
			BONE,
			false
		)
		fly(splinter, at, outward(random, away, 1.3, 26), random)
	end
	-- Brain: soft lumps, some bloody.
	for _ = 1, 14 do
		local size = random:NextNumber(0.1, 0.24)
		local lump = newPart(
			"Brain",
			Vector3.new(size, size * 0.8, size),
			if random:NextNumber() < 0.65 then BRAIN else BRAIN_BLOODY,
			true
		)
		lump.Shape = Enum.PartType.Ball
		if random:NextNumber() < 0.5 then
			local more = newPart("Brain", Vector3.new(size, size, size) * 0.7, BRAIN, true)
			more.Shape = Enum.PartType.Ball
			stuck(lump, more, CFrame.new(size * 0.4, 0, size * 0.2))
		end
		fly(lump, at, outward(random, away, 1.1, 15), random)
	end
	-- An eye.
	local eye = newPart("Eye", Vector3.new(0.2, 0.2, 0.2), Color3.fromRGB(238, 234, 226), true)
	eye.Shape = Enum.PartType.Ball
	local iris = newPart("Iris", Vector3.new(0.09, 0.09, 0.09), Color3.fromRGB(40, 32, 28), true)
	iris.Shape = Enum.PartType.Ball
	stuck(eye, iris, CFrame.new(0, 0, -0.07))
	local nerve = newPart("Nerve", Vector3.new(0.04, 0.04, 0.22), FLESH, true)
	stuck(eye, nerve, CFrame.new(0, 0, 0.18))
	fly(eye, at, outward(random, away, 1.4, 14), random)
	-- Teeth.
	for _ = 1, 4 do
		fly(
			newPart("Tooth", Vector3.new(0.07, 0.1, 0.06), TOOTH, false),
			at,
			outward(random, away, 1.6, 20),
			random
		)
	end

	-- The hair / hat: sent flying.
	for _, accessory in model:GetChildren() do
		local handle = if accessory:IsA("Accessory")
			then accessory:FindFirstChild("Handle")
			else nil
		if handle and handle:IsA("BasePart") then
			local copy = handle:Clone()
			for _, item in copy:GetDescendants() do
				if
					item:IsA("JointInstance")
					or item:IsA("WeldConstraint")
					or item:IsA("Attachment")
				then
					item:Destroy()
				end
			end
			copy.Anchored = false
			copy.Massless = false
			copy.CFrame = handle.CFrame
			fly(copy, handle.Position, outward(random, away, 2.2, 18), random)
			copy.CFrame = handle.CFrame -- (as it was on the head, not turned)
		end
	end

	-- In the air: a spray of drops, and a red mist.
	local point = Instance.new("Attachment")
	point.WorldPosition = at
	point.Parent = workspace.Terrain
	local spray = bloodEmitter(point)
	spray.SpreadAngle = Vector2.new(180, 180)
	spray.Speed = NumberRange.new(8, 28)
	spray.Lifetime = NumberRange.new(0.35, 0.9)
	spray.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(1, 0.06),
	})
	spray.Acceleration = Vector3.new(0, -70, 0)
	spray:Emit(160)
	local mist = bloodEmitter(point)
	mist.SpreadAngle = Vector2.new(180, 180)
	mist.Speed = NumberRange.new(3, 9)
	mist.Lifetime = NumberRange.new(0.5, 1.1)
	mist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 2.4),
	})
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Acceleration = Vector3.new(0, -8, 0)
	mist.Drag = 5
	mist:Emit(36)
	Debris:AddItem(point, 1.6)

	-- On the floor: a big splash where the head was, drops thrown out in
	-- lines all around (more of them away from the attacker).
	splash(at, 2.4, random)
	for _ = 1, 12 do
		local angle = random:NextNumber(0, math.pi * 2)
		local direction = (Vector3.new(math.cos(angle), 0, math.sin(angle)) + away * 0.5).Unit
		castOff(at, direction, random:NextNumber(1.8, 4.2), random)
	end
end

------------------------------------------------------------------------------

-- The head of `model` is gone. `live`: it's happening now (the burst), not
-- a body we only see now (streamed in late): then just what's left.
function HeadBlast.apply(model: Model, live: boolean)
	local seed = model:GetAttribute(HeadBlast.ATTRIBUTE)
	if typeof(seed) ~= "number" or done[model] or not HeadBlast.isBlown(model) then
		return
	end
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("Torso")
	if head == nil or not head:IsA("BasePart") or torso == nil or not torso:IsA("BasePart") then
		return
	end
	done[model] = true
	local random = Random.new(seed)
	if live then
		burst(model, head, torso, random)
	end
	hideAll(model, head)
	local mouth = buildStump(torso, head.Color, random)
	if live then
		pump(model, mouth, random)
	end
end

return table.freeze(HeadBlast)
