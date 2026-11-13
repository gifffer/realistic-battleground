--!strict
-- BloodTracks: what people leave when they go through blood (client-side).
--
--   • FOOTPRINTS: stepping in a fresh pool wets the soles; the next steps
--     print them on the ground, left / right. Each print keeps only part of
--     the blood of the one before (Config.Blood.WORLD.FOOT_DECAY): a full
--     wet sole first, then partial (heel, ball), then a trace - about 7
--     prints, then nothing. Running, only the toe hits the ground and the
--     sole slides forward: a "running" print (toe + forward smear), further
--     apart. They dry like the rest (BloodAge).
--   • SKIDS: running INTO a fresh pool, the foot slips: a long smear out of
--     the pool along the way he ran (not every time).
--   • DRAG MARKS: a knocked-out / ragdolled body sliding over blood (or
--     bleeding while it slides) leaves ONE continuous striated mark that
--     lengthens as it slides the same way, fading as the body runs out of
--     blood (a body still bleeding never runs dry).
--   • SLAMS: a bleeding body slammed / thrown to the ground: a splash of
--     blood under its head and droplets thrown out around it.
--   • HANDPRINTS: a bloody fighter getting up pushes on the ground: a print
--     of the hand there.
--   Only for fighters within 80 studs of the camera (no one sees farther),
--   10 checks a second.
--
--   BloodTracks.onGetUp(model)   a fighter getting back up (a handprint)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Blood = require(script.Parent.Blood)
local BloodAge = require(script.Parent.BloodAge)
local BloodPool = require(script.Parent.BloodPool)
local BloodStain = require(script.Parent.BloodStain)

local BloodTracks = {}

local PALETTE = Config.Blood.PALETTE
local WORLD = Config.Blood.WORLD
local RANGE = 80 -- studs from the camera
local WALK_STRIDE = 2.2 -- studs between two prints (one foot)
local RUN_STRIDE = 3
local RUN_SPEED = 14 -- studs/s: faster than this is running
local LAST_PRINT = 0.92 -- a print fainter than this (its alpha) is not drawn: the soles are clean
local SKID_CHANCE = 0.3
local DRAG_MAX = 2.5 -- studs: a drag mark longer than this starts a new piece
local DRAG_START = 0.5 -- studs: a new piece's first length
local DRAG_TURN = math.cos(math.rad(20)) -- turning more than 20°: a new piece
local DRAG_KEEP = 0.7 -- the body keeps this much of its blood per stud slid
local DRAG_BLEEDING = 0.4 -- (a body still bleeding never has less than this)
local DRAG_STOP = 0.12 -- less blood than this on it: no more mark
local SLAM_FALL = -15 -- studs/s: falling faster than this...
local SLAM_STOPPED = 4 -- ...and then (0.1 s later) almost still = a slam
local FEET = Config.Character.ROOT_TO_FEET
local DOWN = Vector3.new(0, -1, 0)

-- One continuous drag mark being drawn (a picture stretched as it goes).
type Drag = {
	record: BloodAge.Record,
	start: Vector3, -- where it began (its back end)
	direction: Vector3, -- (flat, unit) the way the body slid
	normal: Vector3,
	length: number,
	width: number,
	-- (false: its stand-in is made of plain shapes, which can't be stretched;
	-- it is then only DRAG_START long and the next piece starts past it)
	stretch: boolean,
}

type Track = {
	prints: number, -- prints since the soles were last in a pool (0: clean)
	walked: number,
	left: boolean,
	last: Vector3?,
	wasWet: boolean, -- (its feet were in a fresh pool at the last check)
	load: number, -- blood on a sliding body: 1 = soaked, 0 = none
	drag: Drag?,
	lastBody: Vector3?,
	fallSpeed: number, -- (its body's vertical speed at the last check)
	lastSlam: number,
}

local tracks: { [Model]: Track } = setmetatable({}, { __mode = "k" }) :: any

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function partOf(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

local function groundBelow(position: Vector3, depth: number): RaycastResult?
	return workspace:Raycast(position, DOWN * depth, BloodStain.ground())
end

-- A cut on the head (a "Gash_Head_<n>" attribute)? It bleeds onto the ground.
local function headCut(model: Model): boolean
	for name in model:GetAttributes() do
		if string.sub(name, 1, 10) == "Gash_Head_" then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Footprints
------------------------------------------------------------------------------

-- How faint print number `n` is (its alpha: 0 = full, 1 = invisible). Each
-- print keeps FOOT_DECAY of the blood of the one before (0.7): 0.1, 0.37,
-- 0.56, 0.69, 0.78, 0.85, 0.89, then fainter than LAST_PRINT: no more.
local function printAlpha(n: number): number
	return 1 - 0.9 * WORLD.FOOT_DECAY ^ (n - 1)
end

-- One print of a foot (`left`), print number `n` since the pool.
local function footprint(
	root: BasePart,
	moving: Vector3,
	left: boolean,
	n: number,
	running: boolean,
	random: Random
)
	local side = root.CFrame.RightVector * (if left then -0.5 else 0.5)
	local hit = groundBelow(root.Position + side, FEET + 1.5)
	if hit == nil or hit.Normal.Y < 0.6 then
		return
	end
	-- (picture 1 = a full wet sole, 2 = partial, 3 = a trace)
	local level = if n <= 2 then 1 elseif n <= 4 then 2 else 3
	local scale = if level == 1 then 1 elseif level == 2 then 0.92 else 0.8
	local kind = if running
		then (if left then "shoeRunL" else "shoeRunR")
		else (if left then "footL" else "footR")
	-- (the running print has one picture; its stand-in, the walking print,
	-- keeps the level)
	local index = if running and BloodStain.hasImage(kind) then 1 else level
	local length = if running then 1.1 else 0.95 -- (running: the sole slides forward)
	BloodStain.stain(
		kind,
		-- (running: the smear goes ahead of the toe)
		hit.Position + (if running then moving.Unit * 0.1 else Vector3.zero),
		hit.Normal,
		moving,
		0.42 * scale,
		length * scale,
		{
			random = random,
			index = index,
			profile = "foot",
			category = "foot",
			start = PALETTE.VENOUS,
			alpha = printAlpha(n),
			upright = true,
			material = hit.Material,
			noEdge = true,
			priority = 2,
		}
	)
end

-- Running into a fresh pool: the foot slips, a long smear out of it.
local function skid(root: BasePart, moving: Vector3, random: Random)
	local hit = groundBelow(root.Position, FEET + 1.5)
	if hit == nil or hit.Normal.Y < 0.6 then
		return
	end
	local direction = Vector3.new(moving.X, 0, moving.Z)
	if direction.Magnitude < 1e-3 then
		return
	end
	direction = direction.Unit
	local length = random:NextNumber(1.2, 1.8)
	BloodStain.stain(
		"smear",
		hit.Position + direction * length * 0.5,
		hit.Normal,
		direction,
		0.4,
		length,
		{
			random = random,
			profile = "smear",
			category = "foot",
			start = PALETTE.VENOUS,
			alpha = 0.15,
			material = hit.Material,
			noEdge = true,
			priority = 2,
		}
	)
end

local function walkStep(model: Model, root: BasePart, track: Track)
	local position = root.Position
	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local running = flat.Magnitude > RUN_SPEED
	local wet = BloodPool.wetAt(position - Vector3.new(0, FEET, 0))
	if wet > 0.3 then
		-- (standing in it: the soles fill up again)
		if wet > 0.6 and running and not track.wasWet then
			-- just ran into a fresh pool: maybe a skid (the same on every client)
			local random = Random.new(
				Blood.seed(model.Name, math.floor(position.X), math.floor(position.Z), "skid")
			)
			if random:NextNumber() < SKID_CHANCE then
				skid(root, flat, random)
			end
		end
		track.prints = 1
		track.wasWet = true
	else
		track.wasWet = false
	end
	local last = track.last
	if track.prints > 0 and last then
		local moved = Vector3.new(position.X - last.X, 0, position.Z - last.Z)
		track.walked += moved.Magnitude
		local stride = if running then RUN_STRIDE else WALK_STRIDE
		if track.walked >= stride and moved.Magnitude > 1e-3 then
			-- (one print a step, left and right in turn)
			track.walked = 0
			track.left = not track.left
			local n = track.prints
			if printAlpha(n) > LAST_PRINT then
				track.prints = 0 -- (the soles are clean now)
			else
				track.prints += 1
				local random = Random.new(Blood.seed(model.Name, n, math.floor(position.X)))
				footprint(
					root,
					if flat.Magnitude > 0.5 then flat else moved,
					track.left,
					n,
					running,
					random
				)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Drag marks and slams (a body on the ground)
------------------------------------------------------------------------------

-- Starts a new piece of drag mark at `hit`, going `direction`.
local function newDrag(
	at: Vector3,
	normal: Vector3,
	direction: Vector3,
	width: number,
	load: number,
	material: Enum.Material
): Drag?
	local record = BloodStain.place(
		"drag",
		at + direction * DRAG_START * 0.5,
		normal,
		direction,
		width,
		DRAG_START,
		{
			profile = "smear",
			category = "stain",
			start = PALETTE.VENOUS,
			-- (less blood on the body: a fainter mark)
			alpha = math.clamp(1 - load, 0.05, 0.85),
			material = material,
			noEdge = true,
			priority = 2,
		}
	)
	if record == nil then
		return nil
	end
	-- (only a single picture can be stretched; plain shapes stay short, and
	-- the next piece starts where this one ends - never one per check)
	local shape = BloodStain.shapeOf(record)
	local stretch = shape ~= nil and #shape.pieces == 1 and shape.pieces[1].carrier == true
	return {
		record = record,
		start = at,
		direction = direction,
		normal = normal,
		length = DRAG_START,
		width = width,
		stretch = stretch,
	}
end

-- Makes the current drag mark longer, if the body still goes the same way
-- on the same ground. False: a new piece is needed.
local function extendDrag(drag: Drag, at: Vector3, normal: Vector3, direction: Vector3): boolean
	if drag.record.dead or drag.direction:Dot(direction) < DRAG_TURN then
		return false
	end
	if drag.normal:Dot(normal) < 0.97 then
		return false -- (a step, a slope: a new piece on the new ground)
	end
	local gap = at - drag.start
	local along = gap:Dot(drag.direction)
	local aside = (gap - drag.direction * along - drag.normal * gap:Dot(drag.normal)).Magnitude
	if along > DRAG_MAX or aside > drag.width * 0.6 then
		return false
	end
	if not drag.stretch then
		return along <= drag.length -- (past its end: a new piece)
	end
	if along > drag.length then
		drag.length = along
		-- (its back end stays put: the picture's centre moves half the growth)
		BloodStain.movePiece(drag.record, 1, (along - DRAG_START) * 0.5, 0, along)
	end
	return true
end

-- A bleeding body hitting the ground hard (slammed, thrown): a splash under
-- its head and droplets thrown out around it.
local function slam(model: Model, body: BasePart)
	local head = partOf(model, "Head") or body
	local hit = groundBelow(head.Position + Vector3.new(0, 0.5, 0), 4)
	if hit == nil then
		return
	end
	local random = Random.new(
		Blood.seed(model.Name, math.floor(hit.Position.X), math.floor(hit.Position.Z), "slam")
	)
	Blood.splat(hit.Position, hit.Normal, 0.5, Vector3.new(0, -12, 0), nil, random)
	local ignore: { Instance } = { model }
	for _ = 1, random:NextInteger(4, 6) do
		local a = random:NextNumber(0, math.pi * 2)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		Blood.ballistic(
			hit.Position + hit.Normal * 0.15,
			out * random:NextNumber(4, 8) + hit.Normal * random:NextNumber(2, 4),
			random:NextNumber(0.03, 0.06),
			{ ignore = ignore, random = random }
		)
	end
end

local function downStep(model: Model, root: BasePart, track: Track, now: number)
	track.prints = 0
	track.wasWet = false
	local body = partOf(model, "Torso") or root
	local velocity = body.AssemblyLinearVelocity
	-- a slam: falling fast at the last check, almost still now
	local bleeding = model:GetAttribute("Bleeding") == true
	local cut = headCut(model)
	if
		track.fallSpeed < SLAM_FALL
		and math.abs(velocity.Y) < SLAM_STOPPED
		and (bleeding or cut)
		and now - track.lastSlam > 1
	then
		track.lastSlam = now
		slam(model, body)
	end
	track.fallSpeed = velocity.Y
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local lastBody = track.lastBody
	track.lastBody = body.Position
	local hit = groundBelow(body.Position, 3)
	if hit == nil or hit.Normal.Y < 0.6 then
		track.drag = nil
		return
	end
	local wet = BloodPool.wetAt(hit.Position) > 0.3
	if wet then
		track.load = 1 -- (lying in a pool: soaked)
	end
	if flat.Magnitude < 1.5 then
		track.drag = nil -- (still: the next slide starts a new mark)
		if bleeding or cut then
			track.load = math.max(track.load, DRAG_BLEEDING)
		end
		return
	end
	-- it slides: it leaves some of its blood on the ground
	local slid = if lastBody
		then Vector3.new(body.Position.X - lastBody.X, 0, body.Position.Z - lastBody.Z).Magnitude
		else 0
	track.load *= DRAG_KEEP ^ slid
	if bleeding or cut then
		track.load = math.max(track.load, DRAG_BLEEDING)
	end
	if track.load < DRAG_STOP then
		track.drag = nil
		return
	end
	-- (soaked or bleeding from the body: a torso-wide mark; only a cut head:
	-- a narrow one under the head)
	local width = 0.6
	local at = hit.Position
	if cut and not bleeding and not wet then
		width = 0.35
		local head = partOf(model, "Head")
		local headHit = if head then groundBelow(head.Position, 3) else nil
		if headHit then
			at = headHit.Position
		end
	end
	local direction = flat.Unit
	local drag = track.drag
	if drag and extendDrag(drag, at, hit.Normal, direction) then
		return
	end
	-- a new piece, from where the last one ended (or here)
	local from = at - direction * 0.2
	if drag and not drag.record.dead then
		local tail = drag.start + drag.direction * drag.length
		if (tail - at).Magnitude < 1 then
			from = tail
		end
	end
	track.drag = newDrag(from, hit.Normal, direction, width, track.load, hit.Material)
end

------------------------------------------------------------------------------
-- Handprints
------------------------------------------------------------------------------

-- A fighter getting up: if bloody, a handprint where a hand pushed.
function BloodTracks.onGetUp(model: Model)
	if not Config.Blood.ENABLED then
		return
	end
	local root = rootOf(model)
	if root == nil then
		return
	end
	local bloody = model:GetAttribute("Bleeding") == true
		or BloodPool.wetAt(root.Position - Vector3.new(0, FEET, 0)) > 0.2
	if not bloody then
		return
	end
	local random =
		Random.new(Blood.seed(model.Name, math.floor(root.Position.X), math.floor(root.Position.Z)))
	local left = random:NextNumber() < 0.5
	local arm = model:FindFirstChild(if left then "Left Arm" else "Right Arm")
	local from = if arm and arm:IsA("BasePart") then arm.Position else root.Position
	local hit = groundBelow(from + Vector3.new(0, 1, 0), FEET + 3)
	if hit == nil then
		return
	end
	BloodStain.stain(
		if left then "handL" else "handR",
		hit.Position,
		hit.Normal,
		root.CFrame.LookVector,
		0.42,
		0.5,
		{
			random = random,
			profile = "foot",
			category = "foot",
			start = PALETTE.VENOUS,
			alpha = 0.1,
			upright = true,
			material = hit.Material,
		}
	)
end

local accumulated = 0
RunService.Heartbeat:Connect(function(dt: number)
	accumulated += dt
	if accumulated < 0.1 or not Config.Blood.ENABLED then
		return
	end
	accumulated = 0
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	debug.profilebegin("BloodTracks")
	local eye = camera.CFrame.Position
	local now = os.clock()
	for _, model in CollectionService:GetTagged(Config.Combat.TAG) do
		if not model:IsA("Model") then
			continue
		end
		local root = rootOf(model)
		if root == nil or (root.Position - eye).Magnitude > RANGE then
			local away = tracks[model]
			if away then
				-- (not watched meanwhile: no jump in distance when it comes back)
				away.last = nil
				away.lastBody = nil
				away.drag = nil
			end
			continue
		end
		local track = tracks[model]
		if track == nil then
			track = {
				prints = 0,
				walked = 0,
				left = false,
				last = nil,
				wasWet = false,
				load = 0,
				drag = nil,
				lastBody = nil,
				fallSpeed = 0,
				lastSlam = 0,
			}
			tracks[model] = track
		end
		local down = model:GetAttribute("KnockedOut") == true
			or model:GetAttribute("Ragdolled") == true
		if down then
			downStep(model, root, track, now)
		else
			track.drag = nil
			track.load = 0
			track.lastBody = nil
			track.fallSpeed = 0
			walkStep(model, root, track)
		end
		track.last = root.Position
	end
	debug.profileend()
end)

return table.freeze(BloodTracks)
