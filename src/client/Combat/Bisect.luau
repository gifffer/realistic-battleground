--!strict
-- Bisect: the Bull's finisher (Shared/Finishers "Gore"): the body torn in
-- two at the waist, in the air, on his horns.
--
-- The server, at the kill: takes the legs off the torso (they stay parts of
-- the body, welded to each other: "the legs"), throws the top half on and
-- the legs down, and sets "Bisected" (= a seed) on the body. Every client
-- then (Gashes watches the attribute):
--   • the torso's open bottom: the real abdominal and back muscles torn at
--     their own heights, the lumbar spine sticking out with half the torn
--     disc, nerves hanging from the spinal canal, the small bowel bulging
--     out, fat and skin curling round the edge (WoundKit "Waist");
--   • the legs' top: the real hip bones, the sacrum, the other half of the
--     disc, the torn muscles, the last loops of bowel (WoundKit "Hips");
--   • the GUTS: a chain of loops of bowel (WoundKit "Gut1..3") from the
--     torso's bottom to the hips. When it happens in front of us they pay
--     out of the torso as the halves fly apart (a new loop wherever the gap
--     opens: they lie along the way the top half flew), hang and fall in
--     loops on the floor; a heap of them (WoundKit "GutPile") drops by the
--     legs, soft;
--   • the blood (seen happening): the aorta and the vena cava pumping out
--     of the torso, both iliac arteries out of the hips, a wet smear along
--     the floor where the top half slid, a pool spreading under each half
--     once it lies still, the thuds;
--   • a body seen later (or the frozen copy a finisher leaves, Server/
--     Systems/Corpses): the torn ends, the guts lying still on the floor
--     from one half to the other, the pools.
-- What lies on the floor stays while the body is there; a body left by a
-- finisher stays a while longer as a frozen copy (Corpse.timeLeft): its
-- guts and pools stay that long too, and the copy (same "Bisected" seed)
-- only dresses its own torn ends.
-- Simpler shapes without the kit pieces (an older WoundKit).
--
--   Bisect.ATTRIBUTE           "Bisected"
--   Bisect.apply(model, live)  draws it (once per body)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Corpse = require(ReplicatedStorage.Shared.Util.Corpse)
local Blood = require(script.Parent.Blood)
local BloodGush = require(script.Parent.BloodGush)
local GoreKit = require(script.Parent.GoreKit)
local HeadBlast = require(script.Parent.HeadBlast)
local Squish = require(script.Parent.Squish)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Bisect = {}

Bisect.ATTRIBUTE = "Bisected"

local BLOOD_WET = Color3.fromRGB(104, 8, 8)
local FLESH = Color3.fromRGB(122, 28, 30)
local FLESH_DARK = Color3.fromRGB(80, 14, 16)
local BONE = Color3.fromRGB(226, 214, 190)
local CARTILAGE = Color3.fromRGB(198, 206, 198)
local TENDON = Color3.fromRGB(214, 200, 182)
local MUSCLE = Color3.fromRGB(150, 32, 34)
local MUSCLE_DARK = Color3.fromRGB(112, 22, 26)
local FAT = Color3.fromRGB(222, 190, 112)
-- The bowel: wet pink-grey, the colon and the torn mesentery darker.
local GUT = Color3.fromRGB(204, 128, 118)
local GUT_DARK = Color3.fromRGB(146, 70, 66)

-- Torso space (R6: 2 × 2 × 1, front at Z = -0.5). The legs' own space →
-- the torso's, as if they were still on (R6 hips: C1 · C0⁻¹), as the
-- server welds them (straight, side by side).
local LEG_TO_TORSO: { [string]: CFrame } = {
	["Right Leg"] = CFrame.new(-0.5, 2, 0),
	["Left Leg"] = CFrame.new(0.5, 2, 0),
}
-- Where the guts come out: of the torso's bottom, into the hips' top.
local GUT_OUT = Vector3.new(0.05, -1.04, -0.12)
local GUT_IN = Vector3.new(-0.05, -0.96, -0.12)
-- The aorta and the vena cava (in front of the spine), out of the bottom
-- of the torso; the two iliac arteries out of the hips.
local AORTA = Vector3.new(-0.06, -1.05, 0.12)
local CAVA = Vector3.new(0.14, -1.05, 0.1)
local ILIAC = { Vector3.new(-0.32, -0.95, -0.02), Vector3.new(0.32, -0.95, -0.02) }

local GUT_PIECES = { "Gut1", "Gut2", "Gut3" }
local SEGMENT = 0.5 -- studs: one loop of gut
local HALF = 0.24 -- (its ends, a hair inside it: no gap at the joints)
local MAX_SEGMENTS = 22 -- (11 studs of it at most)
local PAYOUT_TIME = 4 -- seconds the guts keep coming out (live)
local GAP_TEAR = 2.5 -- studs between the last loop and the torso: torn off there
-- studs of slack in the strand to the torso: the guts hang and drop from
-- it (a strand as long as the gap held the chain taut, a stiff rope up to
-- the flying torso)
local GUT_SLACK = 1.2
local SETTLE_TIME = 8 -- then what lies still is fixed where it lies
local DEBRIS_GROUP = "Debris" -- (collides with the map, not with fighters)
local GUT_PHYSICS = PhysicalProperties.new(1, 1, 0, 100, 100) -- limp, wet, no bounce
local BEND = 70 -- degrees: most a loop bends from the one before it

local done: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local folder = Instance.new("Folder")
folder.Name = "Bisect"
folder.Parent = workspace

-- (gore off in Config: nothing drawn, the body just comes apart)
local function enabled(model: Model): boolean
	return Config.Injuries.SKIN_TEAR and model:GetAttribute(Bisect.ATTRIBUTE) ~= nil
end

-- Each layer's colour and shine. `skin` = the body's own skin colour.
local function painter(skin: Color3): (layer: string) -> (Color3, number)
	return function(layer: string): (Color3, number)
		if layer == "Skin" then
			return skin, 0
		elseif layer == "Bone" then
			return BONE, 0.05
		elseif layer == "Cartilage" then
			return CARTILAGE, 0.15
		elseif layer == "Tendon" then
			return TENDON, 0.12
		elseif layer == "FleshDark" then
			return FLESH_DARK, 0.18
		elseif layer == "Muscle" then
			return MUSCLE, 0.16
		elseif layer == "MuscleDark" then
			return MUSCLE_DARK, 0.16
		elseif layer == "Fat" then
			return FAT, 0.08
		elseif layer == "Gut" then
			return GUT, 0.22
		elseif layer == "GutDark" then
			return GUT_DARK, 0.2
		elseif layer == "Blood" then
			return BLOOD_WET, 0.25
		end
		return FLESH, 0.14
	end
end

local function part(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

-- A frame at `position` whose UP is `direction` (a loop of gut lies along
-- its Y axis).
local function along(position: Vector3, direction: Vector3): CFrame
	local up = if direction.Magnitude > 1e-4 then direction.Unit else Vector3.yAxis
	local side = if math.abs(up.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local right = up:Cross(side).Unit
	return CFrame.fromMatrix(position, right, up, right:Cross(up))
end

-- (a Weld with its offset written in: a WeldConstraint takes the offset
-- the parts have when it comes on, maybe another pose of the body's clips
-- than the one the piece was placed for)
local function weldTo(base: BasePart, piece: BasePart, parent: Instance)
	piece.Anchored = false
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Massless = true
	local weld = Instance.new("Weld")
	weld.Part0 = base
	weld.Part1 = piece
	weld.C0 = base.CFrame:ToObjectSpace(piece.CFrame)
	weld.Parent = piece
	piece.Parent = parent
end

local function simplePart(name: string, shape: Enum.PartType, size: Vector3, color: Color3): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Shape = shape
	piece.Size = size
	piece.Material = Enum.Material.SmoothPlastic
	piece.Color = color
	piece.Reflectance = if color == FLESH or color == GUT then 0.18 else 0
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = true
	return piece
end

------------------------------------------------------------------------------
-- The torn ends
------------------------------------------------------------------------------

-- Skin torn round an open end at `top` (torso space, its Y = the cut),
-- curling out (`down` = -1: hanging down, 1: standing up).
local function skinRing(
	base: BasePart,
	frame: CFrame,
	y: number,
	down: number,
	skin: Color3,
	random: Random,
	parent: Instance
)
	for index = 1, 12 do
		local u = (index - 0.5) / 12
		-- round the 2 × 1 edge
		local x, z, turn
		if u < 0.3 then
			x, z, turn = -0.95 + u / 0.3 * 1.9, -0.5, 0
		elseif u < 0.5 then
			x, z, turn = 0.98, -0.5 + (u - 0.3) / 0.2, -math.pi / 2
		elseif u < 0.8 then
			x, z, turn = 0.95 - (u - 0.5) / 0.3 * 1.9, 0.5, math.pi
		else
			x, z, turn = -0.98, 0.5 - (u - 0.8) / 0.2, math.pi / 2
		end
		local flap = simplePart(
			"Skin",
			Enum.PartType.Block,
			Vector3.new(random:NextNumber(0.18, 0.32), random:NextNumber(0.1, 0.22), 0.03),
			skin
		)
		flap.CFrame = base.CFrame
			* frame
			* CFrame.new(x, y, z)
			* CFrame.Angles(0, turn, 0)
			* CFrame.Angles(math.rad(random:NextNumber(20, 55)) * -down, 0, 0)
			* CFrame.new(0, down * flap.Size.Y / 2, -0.015)
		weldTo(base, flap, parent)
	end
end

-- The torso's open bottom, or the legs' top (`frame`: torso space on
-- `base`). `name`: the kit's piece ("Waist" / "Hips").
local function dress(base: BasePart, frame: CFrame, name: string, skin: Color3, random: Random)
	local parent = Instance.new("Folder")
	parent.Name = "Bisect"
	local pieces = GoreKit.get()
	local piece = if pieces then pieces[name] else nil
	if piece then
		weldTo(base, GoreKit.spawn(piece, base.CFrame * frame, painter(skin)), parent)
	elseif name == "Waist" then
		-- Raw meat under the bottom, the spine's end out of it, a loop of
		-- bowel bulging, the skin torn round.
		local raw = simplePart("Raw", Enum.PartType.Block, Vector3.new(1.98, 0.1, 0.98), FLESH_DARK)
		raw.CFrame = base.CFrame * frame * CFrame.new(0, -1.03, 0)
		weldTo(base, raw, parent)
		local spine =
			simplePart("Bone", Enum.PartType.Cylinder, Vector3.new(0.34, 0.26, 0.26), BONE)
		spine.CFrame = base.CFrame
			* frame
			* CFrame.new(0, -1.12, 0.3)
			* CFrame.Angles(0, 0, math.pi / 2)
		weldTo(base, spine, parent)
		for index = 1, 4 do
			local loop = simplePart(
				"Gut",
				Enum.PartType.Ball,
				Vector3.one * random:NextNumber(0.26, 0.36),
				GUT
			)
			loop.CFrame = base.CFrame
				* frame
				* CFrame.new(
					-0.55 + index * 0.24,
					-1.12 - random:NextNumber(0, 0.14),
					-0.15 + random:NextNumber(-0.1, 0.1)
				)
			weldTo(base, loop, parent)
		end
		skinRing(base, frame, -1, -1, skin, random, parent)
	else
		-- The pelvis' top: raw, the hip bones' crests, the sacrum.
		local raw = simplePart("Raw", Enum.PartType.Block, Vector3.new(1.98, 0.1, 0.98), FLESH_DARK)
		raw.CFrame = base.CFrame * frame * CFrame.new(0, -0.97, 0)
		weldTo(base, raw, parent)
		for _, x in { -0.62, 0.62 } do
			local crest =
				simplePart("Bone", Enum.PartType.Block, Vector3.new(0.5, 0.12, 0.16), BONE)
			crest.CFrame = base.CFrame
				* frame
				* CFrame.new(x, -0.9, 0.05)
				* CFrame.Angles(0, math.rad(x * 30), 0)
			weldTo(base, crest, parent)
		end
		local sacrum = simplePart("Bone", Enum.PartType.Block, Vector3.new(0.3, 0.16, 0.2), BONE)
		sacrum.CFrame = base.CFrame * frame * CFrame.new(0, -0.9, 0.32)
		weldTo(base, sacrum, parent)
		skinRing(base, frame, -1, 1, skin, random, parent)
	end
	parent.Parent = base
end

------------------------------------------------------------------------------
-- The guts
------------------------------------------------------------------------------

type Segment = {
	part: BasePart,
	axis: CFrame, -- the loop's own frame (Y along it), in its part's space
	start: Attachment, -- its two ends
	finish: Attachment,
}

-- A loop of bowel, not placed yet.
local function newSegment(random: Random): Segment
	local pieces = GoreKit.get()
	local piece = if pieces then pieces[GUT_PIECES[random:NextInteger(1, #GUT_PIECES)]] else nil
	local main: BasePart
	local axis: CFrame
	if piece then
		main = GoreKit.spawn(piece, CFrame.identity, painter(GUT))
		-- (the piece's own space, long along Y, centred: turned at random round it)
		axis = piece.layers[1].offset:Inverse()
			* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	else
		main =
			simplePart("Gut", Enum.PartType.Cylinder, Vector3.new(SEGMENT + 0.04, 0.17, 0.17), GUT)
		main.Reflectance = 0.22
		axis = CFrame.Angles(0, 0, math.pi / 2) -- (a cylinder lies along X)
	end
	main.Name = "Gut"
	main.CanQuery = false
	main.CanTouch = false
	main.CollisionGroup = DEBRIS_GROUP
	main.CustomPhysicalProperties = GUT_PHYSICS
	for _, item in main:GetDescendants() do
		if item:IsA("BasePart") then
			item.CollisionGroup = DEBRIS_GROUP
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	-- (an attachment's X runs along the loop: a joint's cone limit is then
	-- how far the next loop bends; its twist round the loop is free)
	local alongLoop = CFrame.Angles(0, 0, math.pi / 2)
	local start = Instance.new("Attachment")
	start.Name = "GutStart"
	start.CFrame = axis * CFrame.new(0, -HALF, 0) * alongLoop
	start.Parent = main
	local finish = Instance.new("Attachment")
	finish.Name = "GutEnd"
	finish.CFrame = axis * CFrame.new(0, HALF, 0) * alongLoop
	finish.Parent = main
	return { part = main, axis = axis, start = start, finish = finish }
end

-- The way a loop runs (world), from its start to its end.
local function wayOf(segment: Segment): Vector3
	return (segment.part.CFrame * segment.axis).UpVector
end

-- `direction`, turned toward `previous` (unit) until it bends at most
-- `degrees` from it.
local function withinBend(direction: Vector3, previous: Vector3, degrees: number): Vector3
	if direction.Magnitude < 1e-4 then
		return previous
	end
	local unit = direction.Unit
	local limit = math.rad(degrees)
	local dot = math.clamp(unit:Dot(previous), -1, 1)
	if math.acos(dot) <= limit then
		return unit
	end
	local across = unit - previous * dot
	if across.Magnitude < 1e-4 then
		-- (straight back: bent to any side)
		across =
			previous:Cross(if math.abs(previous.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis)
	end
	return previous * math.cos(limit) + across.Unit * math.sin(limit)
end

-- Puts the loop from `from` toward `toward` (world), its start at `from`.
local function place(segment: Segment, from: Vector3, toward: Vector3)
	local direction = toward - from
	if direction.Magnitude < 1e-3 then
		direction = Vector3.yAxis
	end
	local frame = along(from + direction.Unit * HALF, direction)
	segment.part.CFrame = frame * segment.axis:Inverse()
end

-- What this client drew on the floor for one kill, by its seed (a frozen
-- copy of the body keeps the seed): a copy of a body drawn here does not
-- draw them again over the ones still lying there.
type Drawn = {
	guts: boolean, -- the guts and the heap
	pools: { boolean }, -- the pool under the top half, under the legs
}
local drawn: { [number]: Drawn } = {}

-- What lies on the floor of this body (removed with it).
type Body = {
	model: Model,
	seed: number,
	drawn: Drawn,
	items: { Instance }, -- floor things (the guts, the heap)
	connections: { RBXScriptConnection },
	gone: boolean,
}
local bodies: { [Model]: Body } = setmetatable({}, { __mode = "k" }) :: any

local function keep(body: Body, item: Instance)
	table.insert(body.items, item)
end

-- The body went (respawn, streamed out): what lay on the floor goes at
-- once; for a body left by a finisher (Server/Systems/Corpses puts a frozen
-- copy in its place) only once its time is up, fixed where it lies.
local function release(body: Body)
	if body.gone then
		return
	end
	body.gone = true
	for _, connection in body.connections do
		connection:Disconnect()
	end
	table.clear(body.connections)
	if bodies[body.model] == body then
		bodies[body.model] = nil
	end
	local items = table.clone(body.items)
	table.clear(body.items)
	local function remove()
		for _, item in items do
			item:Destroy()
		end
		-- (forgotten: a body seen after this draws its own)
		if drawn[body.seed] == body.drawn then
			drawn[body.seed] = nil
		end
	end
	local left = Corpse.timeLeft(body.model)
	if left <= 0 then
		remove()
		return
	end
	for _, item in items do
		if item:IsA("BasePart") and item.Parent then
			item.AssemblyLinearVelocity = Vector3.zero
			item.Anchored = true
		end
	end
	task.delay(left, remove)
end

local function bodyOf(model: Model, seed: number): Body
	local existing = bodies[model]
	if existing then
		return existing
	end
	local record = drawn[seed]
	if record == nil then
		record = { guts = false, pools = { false, false } }
		drawn[seed] = record
	end
	local body: Body = {
		model = model,
		seed = seed,
		drawn = record :: Drawn,
		items = {},
		connections = {},
		gone = false,
	}
	bodies[model] = body
	table.insert(
		body.connections,
		model.Destroying:Connect(function()
			release(body)
		end)
	)
	table.insert(
		body.connections,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(game) then
				release(body)
				-- (back in the game later: drawn again)
				done[model] = nil
				for _, name in { "Torso", "Right Leg", "Left Leg" } do
					local piece = model:FindFirstChild(name)
					local dressed = if piece then piece:FindFirstChild("Bisect") else nil
					if dressed then
						dressed:Destroy()
					end
				end
			end
		end)
	)
	return body
end

-- Rays for the floor: through bodies (fighters, the bodies left by
-- finishers), the guts, effects. Made once per use, not per frame.
local function floorParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local ignore: { Instance } = CollectionService:GetTagged(Config.Combat.TAG)
	for _, corpse in CollectionService:GetTagged(Config.Combat.CORPSE_TAG) do
		table.insert(ignore, corpse)
	end
	table.insert(ignore, folder)
	params.FilterDescendantsInstances = ignore
	return params
end

-- The floor under `position` (within `reach` studs below it), or nil.
local function floorUnder(position: Vector3, reach: number, params: RaycastParams): RaycastResult?
	return workspace:Raycast(
		position + Vector3.new(0, 1, 0),
		Vector3.new(0, -(reach + 1), 0),
		params
	)
end

-- The heap of bowel by the legs (bottom at its origin). `live`: dropped
-- from the hips, soft; else lying there.
local function gutPile(body: Body, at: CFrame, live: boolean, random: Random)
	local pieces = GoreKit.get()
	local piece = if pieces then pieces.GutPile else nil
	local heap: BasePart
	if piece then
		heap = GoreKit.spawn(piece, at, painter(GUT))
	else
		heap = simplePart("Gut", Enum.PartType.Ball, Vector3.new(0.7, 0.32, 0.55), GUT)
		heap.CFrame = at * CFrame.new(0, 0.16, 0)
		for index = 1, 4 do
			local loop = simplePart(
				"Gut",
				Enum.PartType.Ball,
				Vector3.one * random:NextNumber(0.24, 0.34),
				if index == 4 then GUT_DARK else GUT
			)
			loop.CanCollide = false
			loop.Massless = true
			loop.CFrame = heap.CFrame
				* CFrame.new(
					random:NextNumber(-0.25, 0.25),
					random:NextNumber(0, 0.15),
					random:NextNumber(-0.2, 0.2)
				)
			local weld = Instance.new("Weld")
			weld.Part0 = heap
			weld.Part1 = loop
			weld.C0 = heap.CFrame:Inverse() * loop.CFrame
			weld.Parent = loop
			loop.Parent = heap
		end
	end
	heap.Name = "GutPile"
	heap.CanQuery = false
	heap.CanTouch = false
	heap.CollisionGroup = DEBRIS_GROUP
	heap.CustomPhysicalProperties = GUT_PHYSICS
	heap.Anchored = not live
	heap.CanCollide = live
	heap.Parent = folder
	keep(body, heap)
	if live then
		Squish.detail(heap, "Flesh")
		Squish.soft(
			heap,
			{ softness = 0.4, sag = 0.25, stiffness = 180, bleeds = true, lifetime = 12 }
		)
		heap.AssemblyLinearVelocity =
			Vector3.new(random:NextNumber(-2, 2), -2, random:NextNumber(-2, 2))
	end
end

-- Seen happening: the guts pay out of the torso as the halves fly apart: a
-- new loop wherever the gap to the torso opens (so they lie along the way
-- it flew), joined loosely; the first one held at the hips. Then they lie
-- in loops on the floor; still ones are fixed there after a while.
local function payOut(body: Body, torso: BasePart, leg: BasePart, legFrame: CFrame, random: Random)
	local hips = Instance.new("Attachment")
	hips.Name = "BisectGutIn"
	hips.Position = (legFrame * CFrame.new(GUT_IN)).Position
	hips.Parent = leg
	keep(body, hips)
	local exit = Instance.new("Attachment")
	exit.Name = "BisectGutOut"
	exit.Position = GUT_OUT
	exit.Parent = torso
	keep(body, exit)

	local chain: { Segment } = {}
	local function add(from: Vector3, toward: Vector3): Segment
		local segment = newSegment(random)
		local last = chain[#chain]
		if last then
			-- (bent no further than its joint allows: it would snap round)
			toward = from + withinBend(toward - from, wayOf(last), BEND - 10)
		end
		place(segment, from, toward)
		segment.part.Parent = folder
		keep(body, segment.part)
		-- (a little of the torso's speed: out of it, they fall behind it)
		segment.part.AssemblyLinearVelocity = torso.AssemblyLinearVelocity * 0.3
			+ leg.AssemblyLinearVelocity * 0.3
		if last then
			local joint = Instance.new("BallSocketConstraint")
			joint.Attachment0 = last.finish
			joint.Attachment1 = segment.start
			joint.LimitsEnabled = true
			joint.UpperAngle = BEND
			joint.Parent = segment.part
			local apart = Instance.new("NoCollisionConstraint")
			apart.Part0 = last.part
			apart.Part1 = segment.part
			apart.Parent = segment.part
		end
		table.insert(chain, segment)
		return segment
	end

	-- the first loop, held at the hips (a short loose tie)
	local first = add(hips.WorldPosition, exit.WorldPosition)
	local tie = Instance.new("RopeConstraint")
	tie.Attachment0 = hips
	tie.Attachment1 = first.start
	tie.Length = 0.15
	tie.Parent = first.part
	-- the last one, to the torso: a strand of mesentery (slack: it never
	-- pulls on the torso, it follows it)
	local strand = Instance.new("RopeConstraint")
	strand.Attachment0 = first.finish
	strand.Attachment1 = exit
	strand.Length = GUT_SLACK
	strand.Visible = true
	strand.Color = BrickColor.new(GUT_DARK)
	strand.Thickness = 0.06
	strand.Parent = first.part
	local torn = false

	local start = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		if body.gone or torso.Parent == nil or os.clock() - start > PAYOUT_TIME then
			if connection then
				connection:Disconnect()
			end
			return
		end
		if torn then
			return
		end
		local target = exit.WorldPosition
		local made = 0
		local last = chain[#chain]
		local gap = (target - last.finish.WorldPosition).Magnitude
		while gap > SEGMENT * 0.7 and #chain < MAX_SEGMENTS and made < 2 do
			last = add(last.finish.WorldPosition, target)
			strand.Attachment0 = last.finish
			strand.Parent = last.part
			made += 1
			gap = (target - last.finish.WorldPosition).Magnitude
		end
		if #chain >= MAX_SEGMENTS and gap > GAP_TEAR then
			-- all out, still pulling: it tears off the torso
			torn = true
			strand:Destroy()
			Blood.spray(target, Vector3.new(0, -1, 0), 1.2, body.model, true)
			return
		end
		strand.Length = gap + GUT_SLACK
	end)
	if connection then
		table.insert(body.connections, connection)
	end

	-- once it lies still: fixed (no physics left running, nothing nudges it)
	task.delay(SETTLE_TIME, function()
		if body.gone then
			return
		end
		for _, segment in chain do
			local loop = segment.part
			if loop.Parent and loop.AssemblyLinearVelocity.Magnitude < 1 then
				loop.Anchored = true
			end
		end
	end)
end

-- Seen later (or a frozen copy): the guts lying still on the floor from
-- `from` to `to`, in lazy curves. (Laid from the hips, as the live ones
-- hang from them: cut short, they end short of the torso.)
local function layOut(body: Body, from: Vector3, to: Vector3, random: Random, params: RaycastParams)
	local a = floorUnder(from, 6, params)
	local b = floorUnder(to, 6, params)
	if a == nil or b == nil then
		return
	end
	local floorA = a.Position + a.Normal * 0.08
	local floorB = b.Position + b.Normal * 0.08
	local flatGap = Vector3.new(floorB.X - floorA.X, 0, floorB.Z - floorA.Z)
	local side = if flatGap.Magnitude > 1e-3
		then flatGap.Unit:Cross(Vector3.yAxis)
		else Vector3.xAxis
	local waves = random:NextNumber(1.2, 2.4)
	local amplitude = math.min(0.6, 0.1 + flatGap.Magnitude * 0.06)
		* (if random:NextNumber() < 0.5 then -1 else 1)
	local phase = random:NextNumber(0, math.pi)
	-- the curve, on the floor (each point dropped onto it)
	local points: { Vector3 } = { from }
	local samples = 48
	for index = 0, samples do
		local s = index / samples
		local p = floorA:Lerp(floorB, s)
			+ side * math.sin(s * math.pi * waves + phase) * amplitude * math.sin(s * math.pi)
		local hit = floorUnder(p, 2.5, params)
		table.insert(points, if hit then hit.Position + hit.Normal * 0.08 else p)
	end
	table.insert(points, to)
	-- loops along it, one every SEGMENT studs
	local count = 0
	local cursor = points[1]
	for index = 2, #points do
		local target = points[index]
		while (target - cursor).Magnitude >= SEGMENT * 0.96 and count < MAX_SEGMENTS do
			local direction = (target - cursor).Unit
			local segment = newSegment(random)
			place(segment, cursor, cursor + direction)
			segment.part.Anchored = true
			segment.part.CanCollide = false
			segment.part.Parent = folder
			keep(body, segment.part)
			cursor += direction * SEGMENT * 0.96
			count += 1
		end
	end
end

------------------------------------------------------------------------------
-- The blood
------------------------------------------------------------------------------

-- Seen happening: the halves fly, land (a thud, a splash), the top half
-- slides (a smear behind it), each lies still (a pool spreading under it).
local function follow(body: Body, torso: BasePart, leg: BasePart, seed: number)
	local random = Random.new(seed + 17)
	type Half = {
		part: BasePart,
		offset: Vector3, -- (its torn end, in its space)
		landed: boolean,
		pooled: boolean,
		still: number,
		sound: string,
		splash: number,
		pool: number,
	}
	local halves: { Half } = {
		{
			part = torso,
			offset = Vector3.new(0, -torso.Size.Y / 2, 0),
			landed = false,
			pooled = false,
			still = 0,
			sound = "BodySlam",
			splash = 2.4,
			pool = 4.6,
		},
		{
			part = leg,
			offset = (LEG_TO_TORSO[leg.Name] or CFrame.identity) * Vector3.new(0, -1, 0),
			landed = false,
			pooled = false,
			still = 0,
			sound = "LimbDrop",
			splash = 1.6,
			pool = 3.6,
		},
	}
	local params = floorParams()
	local smears = 0
	local lastSmear = 0
	local start = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt: number)
		local age = os.clock() - start
		if body.gone or age > 7 then
			if connection then
				connection:Disconnect()
			end
			return
		end
		for index, half in halves do
			local piece = half.part
			if piece.Parent == nil or (half.landed and half.pooled) then
				continue
			end
			local velocity = piece.AssemblyLinearVelocity
			local stump = piece.CFrame * half.offset
			local hit = floorUnder(piece.Position, piece.Size.Magnitude * 0.5 + 0.6, params)
			local onFloor = hit ~= nil
			if onFloor and not half.landed and age > 0.1 then
				half.landed = true
				SoundController.play(half.sound, body.model)
				local spot = (hit :: RaycastResult).Position
				HeadBlast.splash(spot, half.splash, random:NextInteger(1, 2 ^ 20))
				local away = if velocity.Magnitude > 0.1 then velocity.Unit * 0.3 else Vector3.zero
				Blood.spray(
					spot + Vector3.new(0, 0.2, 0),
					Vector3.yAxis + away,
					1.5,
					body.model,
					true
				)
			end
			-- the top half sliding: a smear behind its torn end
			if half.part == torso and onFloor and smears < 30 then
				local flat = Vector3.new(velocity.X, 0, velocity.Z)
				if flat.Magnitude > 2.5 and os.clock() - lastSmear > 0.06 then
					lastSmear = os.clock()
					smears += 1
					HeadBlast.streak(
						stump,
						math.clamp(flat.Magnitude * 0.08, 0.5, 1.4),
						flat,
						random:NextInteger(1, 2 ^ 20)
					)
				end
			end
			-- still: the pool under it
			if half.landed and not half.pooled then
				if velocity.Magnitude < 1.5 then
					half.still += dt
				else
					half.still = 0
				end
				if half.still > 0.3 or age > 3 then
					half.pooled = true
					body.drawn.pools[index] = true
					HeadBlast.pool(stump, half.pool, 6, random:NextInteger(1, 2 ^ 20))
				end
			end
		end
	end)
	if connection then
		table.insert(body.connections, connection)
	end
end

-- Seen happening: the stumps pump.
local function bleed(model: Model, torso: BasePart, leg: BasePart, legFrame: CFrame, seed: number)
	local ignore: { Instance } = { model }
	BloodGush.artery(torso, CFrame.lookAt(AORTA, AORTA + Vector3.new(0, -1, 0.15)), {
		seconds = 5,
		beat = 0.36,
		speed = 11,
		size = 0.15,
		pool = 0,
		seed = seed + 1,
		ignore = ignore,
	})
	BloodGush.artery(torso, CFrame.lookAt(CAVA, CAVA + Vector3.new(0.2, -1, 0)), {
		seconds = 6,
		beat = 0.36,
		speed = 4,
		size = 0.18,
		pool = 0,
		seed = seed + 2,
		ignore = ignore,
	})
	for index, point in ILIAC do
		local at = (legFrame * CFrame.new(point)).Position
		local out = Vector3.new(point.X * 0.6, 1, 0)
		BloodGush.artery(leg, CFrame.lookAt(at, at + out), {
			seconds = 4,
			beat = 0.36,
			speed = 8,
			size = 0.12,
			pool = 0,
			seed = seed + 3 + index,
			ignore = ignore,
		})
	end
	BloodGush.runDown(leg, Vector3.new(0, leg.Size.Y / 2, -0.5), 6, seed + 9)
	BloodGush.runDown(torso, Vector3.new(0, -torso.Size.Y / 2, -0.5), 5, seed + 11)
end

------------------------------------------------------------------------------

-- The body of `model` is torn in two. `live`: it's happening now, not a
-- body we only see now (streamed in late, a frozen copy): then the torn
-- ends, the guts lying on the floor between the halves, the pools.
function Bisect.apply(model: Model, live: boolean)
	local seed = model:GetAttribute(Bisect.ATTRIBUTE)
	if typeof(seed) ~= "number" or done[model] or not enabled(model) then
		return
	end
	local torso = part(model, "Torso")
	local leg = part(model, "Right Leg") or part(model, "Left Leg")
	if torso == nil or leg == nil then
		return
	end
	done[model] = true
	local random = Random.new(seed)
	local head = part(model, "Head")
	local arm = part(model, "Left Arm") or part(model, "Right Arm")
	local skin = if head then head.Color elseif arm then arm.Color else leg.Color
	-- (the legs in the torso's space, as if still on)
	local legFrame = LEG_TO_TORSO[leg.Name] or CFrame.identity
	dress(torso, CFrame.identity, "Waist", skin, random)
	dress(leg, legFrame, "Hips", skin, random)

	local body = bodyOf(model, seed)
	local hipsTop = leg.CFrame * legFrame
	if live and not body.drawn.guts then
		body.drawn.guts = true
		SoundController.play("OrganDrop", model)
		payOut(body, torso, leg, legFrame, random)
		gutPile(
			body,
			hipsTop * CFrame.new(0.1, -0.9, -0.2) * CFrame.Angles(0, random:NextNumber(0, 6.3), 0),
			true,
			random
		)
		bleed(model, torso, leg, legFrame, seed)
		follow(body, torso, leg, seed)
	elseif not live then
		-- (a copy of a body drawn here: its guts and pools still lie there)
		local params = floorParams()
		local torsoEnd = (torso.CFrame * CFrame.new(GUT_OUT)).Position
		local hipsEnd = (hipsTop * CFrame.new(GUT_IN)).Position
		if not body.drawn.guts then
			body.drawn.guts = true
			layOut(body, hipsEnd, torsoEnd, random, params)
			-- the heap beside the legs
			local beside = hipsTop * CFrame.new(random:NextNumber(-0.9, 0.9), -1, -0.9)
			local floor = floorUnder(beside.Position, 4, params)
			if floor then
				gutPile(
					body,
					CFrame.new(floor.Position) * CFrame.Angles(0, random:NextNumber(0, 6.3), 0),
					false,
					random
				)
			end
		end
		-- the pools under both halves
		if not body.drawn.pools[1] then
			body.drawn.pools[1] = true
			HeadBlast.pool(torsoEnd, 4.2, 0.4, seed + 21)
		end
		if not body.drawn.pools[2] then
			body.drawn.pools[2] = true
			HeadBlast.pool((hipsTop * CFrame.new(0, -1, 0)).Position, 3.2, 0.4, seed + 22)
		end
	end
end

return table.freeze(Bisect)
