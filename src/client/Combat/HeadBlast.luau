--!strict
-- HeadBlast: the head that bursts under the bat (Street Brawler finisher).
--
-- Made of the real pieces of WoundKit (GoreKit: real anatomy from
-- Z-Anatomy - the skull's bones under the scalp, the brain and its folds,
-- the eyes, the teeth, the lower jaw, the top of the spine - and blots of
-- blood for the floor). Without them (no kit, an old kit) it draws simpler
-- ones itself.
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
local GoreKit = require(script.Parent.GoreKit)
local GoreShapes = require(ReplicatedStorage.Shared.GoreShapes)
local Blood = require(script.Parent.Blood)
local Squish = require(script.Parent.Squish)

local HeadBlast = {}

HeadBlast.ATTRIBUTE = "HeadBlown"

local BLOOD = Color3.fromRGB(78, 6, 6) -- dark, as it is once out
local BLOOD_WET = Color3.fromRGB(104, 8, 8) -- fresh
local FLESH = Color3.fromRGB(122, 28, 30)
local FLESH_DARK = Color3.fromRGB(84, 16, 18)
local BONE = Color3.fromRGB(224, 212, 188)
local BONE_EDGE = Color3.fromRGB(196, 160, 140) -- broken edge, a bit of blood in it
local BRAIN = Color3.fromRGB(196, 136, 132)
local SCLERA = Color3.fromRGB(236, 230, 220)
local IRIS = Color3.fromRGB(52, 38, 30)
local BRAIN_BLOODY = Color3.fromRGB(152, 72, 72)
local TOOTH = Color3.fromRGB(236, 230, 212)
local PIECE_LIFETIME = 30 -- seconds the pieces stay on the floor
local MARK_LIFETIME = 30 -- seconds the blood stays on the floor (fading the last third)
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
	-- (here, nothing lands on a head that isn't there any more)
	head.CanCollide = false
	head.CanQuery = false
end

------------------------------------------------------------------------------
-- Blood on the floor
------------------------------------------------------------------------------

local marks: { BasePart } = {}
local markCount = 0 -- (never goes down: each new mark a hair higher)

-- Is this part on a character (a body part, or anything in it: ragdoll
-- colliders, accessories...)?
local function onCharacter(part: Instance): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

-- The floor under `position` (through every body, never on one), or nil.
local function floorUnder(position: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = CollectionService:GetTagged(Config.Combat.TAG)
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local from = position + Vector3.new(0, 1, 0)
	for _ = 1, 4 do
		local hit = workspace:Raycast(from, Vector3.new(0, -14, 0), params)
		if hit == nil or not onCharacter(hit.Instance) then
			return hit
		end
		table.insert(ignore, hit.Instance) -- (a body: look under it)
		params.FilterDescendantsInstances = ignore
	end
	return nil
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
	piece.Reflectance = 0
	piece.Transparency = 0.05
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

-- Keeps a floor mark in the list (oldest gone past the cap), fading it out.
local function keepMark(piece: BasePart, lifetime: number?)
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
end

-- A blot of blood from the kit (Splat / Streak / Pool) on the floor under
-- `position`: `size` studs across, its length along `along` (a streak), or
-- turned at random. nil without the kit or a floor.
local function blot(
	kind: { string },
	position: Vector3,
	size: number,
	along: Vector3?,
	random: Random,
	lifetime: number?
): BasePart?
	local pieces = GoreKit.get()
	if pieces == nil or #kind == 0 then
		return nil
	end
	local piece = pieces[kind[random:NextInteger(1, #kind)]]
	local hit = if piece then floorUnder(position) else nil
	if piece == nil or hit == nil then
		return nil
	end
	local layer = piece.layers[1]
	local part = layer.source:Clone()
	part:ClearAllChildren()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = if random:NextNumber() < 0.6 then BLOOD else BLOOD_WET
	part.Reflectance = 0
	part.Transparency = 0.04
	-- (laid flat in X-Z in the kit: 1 stud across at most)
	local across = math.max(layer.size.X, layer.size.Z)
	part.Size = Vector3.new(layer.size.X, layer.size.Y, layer.size.Z) * (size / across)
	markCount += 1
	local up = hit.Normal
	local forward = if along and along.Magnitude > 1e-3
		then along - up * along:Dot(up)
		else up:Cross(Vector3.new(random:NextNumber(-1, 1), 0.01, random:NextNumber(-1, 1)))
	if forward.Magnitude < 1e-3 then
		forward = Vector3.new(1, 0, 0)
	end
	local lift = 0.006 + (markCount % 12) * 0.002
	-- (the kit's X along `forward`, its Y along the floor's normal)
	local right = forward.Unit
	part.CFrame = CFrame.fromMatrix(hit.Position + up * lift, right, up) * layer.offset.Rotation
	part.Parent = workspace
	keepMark(part, lifetime)
	return part
end

-- An irregular splash: a blot made of a few overlapping round ones, and
-- small drops around it.
local function splash(position: Vector3, size: number, random: Random)
	if blot(GoreShapes.splat, position, size * 1.3, nil, random) then
		return
	end
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
			local stretched = size * (1 + (1 - along) * 3.5)
			if
				index > count * 0.6
				or blot(GoreShapes.streak, at, stretched * 1.6, direction, random) == nil
			then
				mark(at, size, stretched, direction, BLOOD)
			end
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

-- The colour and shine of a kit layer (Skin: the fighter's own skin).
local function painter(skin: Color3): (layer: string) -> (Color3, number)
	return function(layer: string): (Color3, number)
		if layer == "Skin" then
			return skin, 0
		elseif layer == "Bone" then
			return BONE, 0.02
		elseif layer == "Brain" then
			return BRAIN, 0.08
		elseif layer == "Sclera" then
			return SCLERA, 0.1
		elseif layer == "Iris" then
			return IRIS, 0.15
		elseif layer == "Tooth" then
			return TOOTH, 0.05
		elseif layer == "Blood" then
			return BLOOD, 0
		end
		return FLESH, 0.06 -- Flesh (and anything new)
	end
end

-- Where the blood pumps out of the neck.
local function neckBlood(torso: BasePart): Attachment
	local mouth = Instance.new("Attachment")
	mouth.Name = "HeadBlastBlood"
	mouth.Position = Vector3.new(0, torso.Size.Y / 2 + 0.15, 0)
	mouth.Parent = torso
	return mouth
end

-- What's left on top of the torso, from the kit: the real lower jaw and its
-- teeth in the skin of the chin, torn along the top, the wound inside, the
-- top of the spine. nil without the kit.
local function buildRealStump(torso: BasePart, skin: Color3): Attachment?
	local pieces = GoreKit.get()
	local jaw = if pieces then pieces.Jaw else nil
	if jaw == nil then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "HeadBlast"
	-- (where the head sits on the torso: its neck joint at rest)
	local headAt = torso.CFrame * CFrame.new(0, torso.Size.Y / 2 + 0.5, 0)
	local main = GoreKit.spawn(jaw, headAt, painter(skin))
	main.CanCollide = false
	main.Massless = true
	main.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = main
	weld.Parent = main
	main.Parent = folder
	local mouth = neckBlood(torso)
	folder.Parent = torso
	return mouth
end

-- What's left on top of the torso (simple version, without the kit): the
-- neck torn open, the lower jaw with a few teeth. Returns the point the
-- blood comes out of.
local function buildSimpleStump(torso: BasePart, skin: Color3, random: Random): Attachment
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
	local mouth = neckBlood(torso)
	folder.Parent = torso
	return mouth
end

local function buildStump(torso: BasePart, skin: Color3, random: Random): Attachment
	return buildRealStump(torso, skin) or buildSimpleStump(torso, skin, random)
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
	local real = blot(GoreShapes.pool, below, 0.4, nil, random, 40)
	if real then
		local k = random:NextNumber(3.2, 4.2) / 0.4
		local grown = real.Size * Vector3.new(k, 1, k) -- (across, not thicker)
		TweenService:Create(
			real,
			TweenInfo.new(PUMP_TIME + 2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = grown }
		):Play()
	end
	for index = 1, if real then 0 else 3 do
		local offset =
			Vector3.new(random:NextNumber(-0.35, 0.35), 0, random:NextNumber(-0.35, 0.35))
		local piece =
			mark(below + offset, 0.3, nil, nil, if index == 1 then BLOOD else BLOOD_WET, 40)
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
			-- (thick blood: real drops and strings with each beat)
			local up = mouth.WorldCFrame.LookVector
			Blood.spray(mouth.WorldPosition, up + Vector3.new(0, 0.6, 0), 1.2 * fade + 0.4, model)
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

-- Simpler pieces, without the kit: plates of scalp and bone, brain, an
-- eye, teeth.
local function simplePieces(head: BasePart, at: Vector3, away: Vector3, random: Random)
	local skin = head.Color
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
		Squish.soft(lump, { softness = 0.5, sag = 0.24, stiffness = 170, lifetime = 14 })
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
	Squish.soft(eye, { softness = 0.25, sag = 0.1, stiffness = 380, lifetime = 10 })
	-- Teeth.
	for _ = 1, 4 do
		fly(
			newPart("Tooth", Vector3.new(0.07, 0.1, 0.06), TOOTH, false),
			at,
			outward(random, away, 1.6, 20),
			random
		)
	end
end

-- The real pieces of the head (from the kit), each from where it was in the
-- head, thrown out from its centre (and away from the blow). false without
-- the kit.
local function realPieces(head: BasePart, away: Vector3, random: Random): boolean
	local pieces = GoreKit.get()
	if pieces == nil then
		return false
	end
	local paint = painter(head.Color)
	-- `soft`: brain, eyes: soft, wet pieces (Squish), not hard plastic
	local function throw(names: { string }, speed: number, up: number, soft: string?)
		for _, name in names do
			local piece = pieces[name]
			if piece then
				local part = GoreKit.spawn(piece, head.CFrame, paint)
				-- (they start inside each other: solid once apart)
				part.CanCollide = false
				task.delay(0.1, function()
					if part.Parent then
						part.CanCollide = true
					end
				end)
				local from = head.CFrame:VectorToWorldSpace(piece.center)
				local direction = if from.Magnitude > 0.05
					then from.Unit
					else random:NextUnitVector()
				direction = (direction + away * 0.5 + Vector3.new(
					0,
					random:NextNumber(up * 0.4, up),
					0
				)).Unit
				part.AssemblyLinearVelocity = direction * speed * random:NextNumber(0.55, 1)
				part.AssemblyAngularVelocity = random:NextUnitVector() * random:NextNumber(6, 22)
				part.Parent = workspace
				Debris:AddItem(part, PIECE_LIFETIME)
				if soft == "Brain" then
					Squish.soft(
						part,
						{ softness = 0.5, sag = 0.24, stiffness = 170, lifetime = 14 }
					)
					Squish.detail(part, "Brain")
				elseif soft == "Eye" then
					Squish.soft(
						part,
						{ softness = 0.25, sag = 0.1, stiffness = 380, lifetime = 10 }
					)
				end
			end
		end
	end
	throw(GoreShapes.skull, 24, 1.1)
	throw(GoreShapes.brain, 13, 0.8, "Brain")
	throw(GoreShapes.eye, 15, 1.2, "Eye")
	throw(GoreShapes.tooth, 20, 1.4)
	return true
end

local function burst(model: Model, head: BasePart, torso: BasePart, random: Random)
	local at = head.Position
	-- Away from the attacker: he stands past the head, so toward the body.
	local flat = Vector3.new(torso.Position.X - at.X, 0, torso.Position.Z - at.Z)
	local away = if flat.Magnitude > 0.1 then flat.Unit * 0.7 else Vector3.zero

	if realPieces(head, away, random) then
		-- (a few bone splinters and bits of brain more, smaller than the kit's)
		for _ = 1, 8 do
			local splinter = newPart(
				"Splinter",
				Vector3.new(random:NextNumber(0.03, 0.06), 0.025, random:NextNumber(0.08, 0.18)),
				BONE,
				false
			)
			fly(splinter, at, outward(random, away, 1.3, 26), random)
		end
	else
		simplePieces(head, at, away, random)
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

	-- Real drops and thick strings of blood thrown out all around (they land
	-- and splash on the floor, the walls, the attacker), more away from him.
	Blood.spray(at, Vector3.new(0, 1, 0) + away, 7, model)
	Blood.spray(at, away + Vector3.new(0, 0.3, 0), 4, model)
	Blood.spray(at, -away + Vector3.new(0, 0.6, 0), 2.5, model)
	-- In the air: a spray of fine drops, and a red mist.
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
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1.3),
	})
	-- (a fine haze: thick, it reads as a dark flat blot from up close)
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.LightInfluence = 0.6
	mist.Acceleration = Vector3.new(0, -8, 0)
	mist.Drag = 5
	mist:Emit(20)
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

-- Blood on the floor under `position`, for other gore (LiverRip): a splash
-- `size` studs across, the same on every client (`seed`).
function HeadBlast.splash(position: Vector3, size: number, seed: number)
	splash(position, size, Random.new(seed))
end

-- A pool spreading under `position` to `size` studs over `seconds`.
function HeadBlast.pool(position: Vector3, size: number, seconds: number, seed: number)
	local random = Random.new(seed)
	local piece = blot(GoreShapes.pool, position, 0.3, nil, random, 40)
		or mark(position, 0.3, nil, nil, BLOOD, 40)
	if piece then
		local k = size / 0.3
		-- (grows across, not thicker: a round mark's thin axis is X)
		local flat = piece:IsA("Part") and piece.Shape == Enum.PartType.Cylinder
		TweenService:Create(
			piece,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = piece.Size * (if flat then Vector3.new(1, k, k) else Vector3.new(k, 1, k)) }
		):Play()
	end
end

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
