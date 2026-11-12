--!strict
-- Blood: how blood looks when it leaves a body - every client, client-side.
--
-- What real blood does, and how it is drawn here:
--   • DROPS: thrown out of a wound, many small and a few big ones. They fly
--     (gravity, a little air drag), STRETCH along their speed (a fast drop
--     is a streak, not a ball) and splash wherever they land: the floor, a
--     wall, a body (someone's clothes, the attacker's fist).
--   • STRANDS: blood is thick. A heavy blow pulls strings of it out, a gob
--     at the front dragging a thinning thread behind it, that stretches
--     until it snaps into drops.
--   • SPLATS: where a drop lands - a blob of overlapping round puddles, a
--     streak in the direction it was going with a drop at its end (the "!"
--     a fast drop leaves), tiny satellite drops around it. On a wall it RUNS
--     down slowly, a bead at the bottom of each run. On a body it stays,
--     stuck to the part (it moves with it).
--   • It is WET at first (shiny, bright red) and DRIES (darker, dull) over
--     the next seconds, then fades out a long while later.
--   • A fine red MIST hangs a moment in the air on hard blows.
--
--   Blood.spray(point, direction, amount, source, noMist?)  a wound opening: drops
--       (and strands if amount >= 1) out of `point` along `direction`;
--       `amount` 1 = a punch that cuts, 2-3 = a heavy blow, 5+ = gore.
--   Blood.splat(position, normal, size, velocity?, onto?)  a splash on a
--       surface (`onto`: the part hit; a body part keeps it).
--   Blood.drop(position, velocity, size)  one drop (a wound dripping).
--   Blood.mist(point, direction, amount)
--   Blood.strand(point, velocity, thickness)  one string of thick blood.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Blood = {}

Blood.FRESH = Color3.fromRGB(128, 8, 10) -- bright, just out (oxygenated)
Blood.DARK = Color3.fromRGB(80, 5, 7) -- a few seconds later
Blood.DRY = Color3.fromRGB(48, 6, 6) -- dried

local MAX_DROPS = 220 -- flying at once
local MAX_STRANDS = 24
local MAX_SPLATS = 1400 -- pieces of blood on floors / walls at once (oldest fade out)
local MAX_BODY_SPLATS = 220 -- on bodies (their own list: floor spam never takes them)
local MAX_NEW_PER_FRAME = 90 -- new pieces a frame, at most (the rest is skipped)
local FLOOR_LIFETIME = 45 -- seconds a splat stays (fading the last third)
local BODY_LIFETIME = 35
local DRY_TIME = 14 -- seconds to darken and lose its shine
local WET_SHINE = 0.22
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local random = Random.new()

local folder = Instance.new("Folder")
folder.Name = "Blood"
folder.Parent = workspace

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { folder }
params.IgnoreWater = true

local function isBody(instance: Instance): Model?
	local model = instance:FindFirstAncestorOfClass("Model")
	if
		model
		and (
			model:FindFirstChildOfClass("Humanoid")
			or CollectionService:HasTag(model, Config.Combat.TAG)
		)
	then
		return model
	end
	return nil
end

local function newPiece(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = WET_SHINE
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

------------------------------------------------------------------------------
-- Splats
------------------------------------------------------------------------------

local splats: { BasePart } = {}
local bodySplats: { BasePart } = {}
local layer = 0 -- each new piece a hair higher: no flicker where they overlap
local madeThisFrame = 0
RunService.Heartbeat:Connect(function()
	madeThisFrame = 0
end)

local function keep(piece: BasePart, lifetime: number, onBody: boolean)
	local list = if onBody then bodySplats else splats
	table.insert(list, piece)
	if #list > (if onBody then MAX_BODY_SPLATS else MAX_SPLATS) then
		local oldest = table.remove(list, 1)
		if oldest and oldest.Parent then
			-- (faded out, not popped)
			TweenService:Create(oldest, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			Debris:AddItem(oldest, 0.35)
		end
	end
	-- wet → dry
	TweenService:Create(piece, TweenInfo.new(DRY_TIME, Enum.EasingStyle.Sine), {
		Color = piece.Color:Lerp(Blood.DRY, 0.7),
		Reflectance = 0.03,
	}):Play()
	task.delay(lifetime * 0.7, function()
		if piece.Parent then
			TweenService:Create(piece, TweenInfo.new(lifetime * 0.3), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(piece, lifetime)
end

-- A flat ellipse of blood on a surface: centre `at`, facing `normal`, its
-- length along `along`.
local function puddle(
	at: Vector3,
	normal: Vector3,
	along: Vector3,
	width: number,
	length: number,
	color: Color3,
	onto: BasePart?,
	lifetime: number
): Part?
	if madeThisFrame >= MAX_NEW_PER_FRAME then
		return nil
	end
	-- On a body part: only if it lies on it (not hanging past its edge).
	if onto then
		local l = onto.CFrame:PointToObjectSpace(at)
		local h = onto.Size / 2
		local r = math.max(width, length) * 0.5
		local ln = onto.CFrame:VectorToObjectSpace(normal)
		local function inside(value: number, extent: number, facing: number): boolean
			-- (along the face's normal it may sit on the face itself)
			return math.abs(facing) > 0.7 or math.abs(value) + r * 0.6 <= extent + 0.02
		end
		if not (inside(l.X, h.X, ln.X) and inside(l.Y, h.Y, ln.Y) and inside(l.Z, h.Z, ln.Z)) then
			return nil
		end
	end
	madeThisFrame += 1
	layer = (layer + 1) % 64
	local lift = 0.012 + layer * 0.0008
	local forward = along - normal * along:Dot(normal)
	if forward.Magnitude < 1e-3 then
		forward = normal:Cross(Vector3.new(0.37, 0.71, 0.6))
	end
	forward = forward.Unit
	local side = normal:Cross(forward)
	-- (a flattened sphere mesh - a true ellipse, a cylinder would stay
	-- round: X along the normal, Y across, Z along)
	local piece = newPiece("Blood", Vector3.new(0.01, width, length), color)
	piece.Archivable = false -- (copies of a body don't copy its blood)
	local disc = Instance.new("SpecialMesh")
	disc.MeshType = Enum.MeshType.Sphere
	disc.Parent = piece
	piece.CFrame = CFrame.fromMatrix(at + normal * lift, normal, side)
	if onto then
		piece.Anchored = false
		piece.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = onto
		weld.Part1 = piece
		weld.Parent = piece
		local holder = onto:FindFirstChild("BloodSplats")
		if holder == nil or not holder:IsA("Folder") then
			local made = Instance.new("Folder")
			made.Name = "BloodSplats"
			made.Archivable = false
			made.Parent = onto
			holder = made
		end
		piece.Parent = holder
	else
		piece.Parent = folder
	end
	keep(piece, lifetime, onto ~= nil)
	return piece
end

-- Blood running down a wall from `at`: a thin trail growing down slowly,
-- a bead at its tip.
local function run(
	at: Vector3,
	normal: Vector3,
	width: number,
	color: Color3,
	onto: BasePart?,
	lifetime: number
)
	local down = Vector3.new(0, -1, 0)
	down = (down - normal * down:Dot(normal))
	if down.Magnitude < 0.3 then
		return -- (not steep enough to run)
	end
	down = down.Unit
	local length = random:NextNumber(0.3, 1.6) * math.clamp(width * 4, 0.6, 2)
	local time = length * random:NextNumber(1.5, 3)
	local trail: Part? = puddle(at, normal, down, width * 0.45, 0.02, color, onto, lifetime)
	local bead = puddle(at, normal, down, width * 0.7, width * 0.85, color, onto, lifetime)
	if trail == nil or bead == nil then
		return
	end
	-- (the trail itself a straight band, not an ellipse)
	local mesh = trail:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		mesh:Destroy()
	end
	trail.Size = Vector3.new(0.01, width * 0.45, 0.02)
	local base = trail.CFrame
	local beadBase = bead.CFrame
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local t = math.min(1, (os.clock() - started) / time)
		-- (fast at first, then slowing as it thins)
		local reach = length * (1 - (1 - t) ^ 2)
		if trail.Parent == nil or bead.Parent == nil or t >= 1 then
			if connection then
				connection:Disconnect()
			end
			return
		end
		if trail.Anchored then
			trail.Size = Vector3.new(0.01, width * 0.45 * (1 - t * 0.4), math.max(0.02, reach))
			trail.CFrame = base + down * (reach / 2)
			bead.CFrame = beadBase + down * reach
		end
	end)
end

-- A splash where blood lands. `velocity`: how it arrived (a streak along
-- its sliding part, satellites thrown ahead).
function Blood.splat(
	position: Vector3,
	normal: Vector3,
	size: number,
	velocity: Vector3?,
	onto: BasePart?
)
	local body = if onto then isBody(onto) else nil
	-- (stuck to a body, or to anything that moves: it goes with it)
	local stuckTo = if onto and (body ~= nil or not onto.Anchored) then onto else nil
	local lifetime = if body then BODY_LIFETIME else FLOOR_LIFETIME
	local v = velocity or Vector3.zero
	local tangent = v - normal * v:Dot(normal)
	local slide = tangent.Magnitude
	local along = if slide > 1e-3 then tangent.Unit else normal:Cross(Vector3.new(0.6, 0.37, 0.71))
	if slide <= 1e-3 then
		along = if along.Magnitude > 1e-3 then along.Unit else normal:Cross(Vector3.xAxis).Unit
	end
	local across = normal:Cross(along)
	if across.Magnitude > 1e-3 then
		across = across.Unit
	end
	local fresh = Blood.FRESH:Lerp(Blood.DARK, random:NextNumber(0, 0.5))
	-- 1. the blob: a few overlapping round puddles, the middle darker
	-- (a small drop: one puddle; a big splash: up to 5)
	for index = 1, math.clamp(math.floor(size * 6), 1, 5) do
		local offset = along * random:NextNumber(-0.25, 0.25) * size
			+ across * random:NextNumber(-0.25, 0.25) * size
		local d = size * random:NextNumber(0.45, 0.85) * (1 - index * 0.06)
		puddle(
			position + offset,
			normal,
			along,
			d,
			d * random:NextNumber(0.85, 1.15),
			if index == 1 then fresh else fresh:Lerp(Blood.DARK, 0.4),
			stuckTo,
			lifetime
		)
	end
	-- 2. a fast drop leaves a streak with a drop at its end (the "!")
	if slide > 5 and size > 0.15 then
		local length = size * math.clamp(slide / 9, 1.2, 4)
		puddle(
			position + along * length * 0.45,
			normal,
			along,
			size * 0.45,
			length,
			fresh,
			stuckTo,
			lifetime
		)
		puddle(
			position + along * (length * 0.95 + size * 0.3),
			normal,
			along,
			size * 0.3,
			size * 0.36,
			fresh,
			stuckTo,
			lifetime
		)
	end
	-- 3. satellites thrown out around it, more ahead
	-- (only a big drop landing hard throws satellites)
	local impact = math.clamp((v.Magnitude - 8) / 20, 0, 1)
	local satellites = if size < 0.12 then 0 else math.min(9, math.floor(size * 30 * impact))
	for _ = 1, satellites do
		local ahead = if slide > 2 then random:NextNumber(0, 1.6) else random:NextNumber(-1, 1)
		local offset = along * ahead * size * 1.5 + across * random:NextNumber(-1, 1) * size * 1.1
		local d = size * random:NextNumber(0.08, 0.22)
		puddle(
			position + offset,
			normal,
			along,
			d,
			d * random:NextNumber(1, 1.6),
			fresh,
			stuckTo,
			lifetime
		)
	end
	-- 4. on a wall (or a standing body part), it runs down
	if stuckTo == nil and math.abs(normal.Y) < 0.75 and size > 0.08 then
		for _ = 1, random:NextInteger(1, if size > 0.3 then 3 else 1) do
			local start = position + across * random:NextNumber(-0.3, 0.3) * size
			run(start, normal, size * random:NextNumber(0.25, 0.4), fresh, stuckTo, lifetime)
		end
	end
end

------------------------------------------------------------------------------
-- Drops and strands in flight
------------------------------------------------------------------------------

type Drop = {
	part: Part,
	shape: SpecialMesh,
	position: Vector3,
	velocity: Vector3,
	size: number,
	born: number,
	source: Model?,
}
type Strand = {
	head: Drop,
	tail: Vector3,
	tailVelocity: Vector3,
	thread: Part,
	thickness: number,
	rest: number,
}

local drops: { Drop } = {}
local strands: { Strand } = {}
local moved: { BasePart } = {}
local frames: { CFrame } = {}

local function newDrop(position: Vector3, velocity: Vector3, size: number, source: Model?): Drop?
	if #drops >= MAX_DROPS then
		return nil
	end
	local part = newPiece(
		"BloodDrop",
		Vector3.one * size,
		Blood.FRESH:Lerp(Blood.DARK, random:NextNumber(0, 0.4))
	)
	part.Reflectance = 0.3
	local shape = Instance.new("SpecialMesh")
	shape.MeshType = Enum.MeshType.Sphere
	shape.Parent = part
	part.CFrame = CFrame.new(position)
	part.Parent = folder
	local drop: Drop = {
		part = part,
		shape = shape,
		position = position,
		velocity = velocity,
		size = size,
		born = os.clock(),
		source = source,
	}
	table.insert(drops, drop)
	return drop
end

function Blood.drop(position: Vector3, velocity: Vector3, size: number)
	newDrop(position, velocity, size, nil)
end

function Blood.strand(point: Vector3, velocity: Vector3, thickness: number, source: Model?)
	if #strands >= MAX_STRANDS then
		return
	end
	local head = newDrop(point, velocity, thickness * 1.9, source)
	if head == nil then
		return
	end
	local thread = newPiece("BloodStrand", Vector3.new(0.05, thickness, thickness), Blood.FRESH)
	thread.Shape = Enum.PartType.Cylinder
	thread.Reflectance = 0.3
	thread.Parent = folder
	table.insert(strands, {
		head = head,
		tail = point,
		tailVelocity = velocity * 0.35,
		thread = thread,
		thickness = thickness,
		rest = random:NextNumber(0.25, 0.6),
	})
end

local function land(drop: Drop, hit: RaycastResult)
	local speed = drop.velocity.Magnitude
	-- (a bigger, faster drop splashes wider)
	local size = drop.size * (2.2 + math.min(speed, 40) * 0.05)
	Blood.splat(hit.Position, hit.Normal, size, drop.velocity, hit.Instance :: BasePart)
end

-- Moves every drop, lands the ones that hit something.
local function step(dt: number)
	local gravity = Vector3.new(0, -workspace.Gravity, 0)
	local now = os.clock()
	table.clear(moved)
	table.clear(frames)
	local index = 1
	while index <= #drops do
		local drop = drops[index]
		local drag = if drop.size > 0.12 then 0.35 else 1.1 -- (tiny drops slow in the air)
		drop.velocity += (gravity - drop.velocity * drag) * dt
		local travel = drop.velocity * dt
		local hit = nil
		if travel.Magnitude > 1e-4 then
			hit = workspace:Raycast(drop.position, travel, params)
			-- (leaving the wound: not on the body it comes out of)
			if
				hit
				and drop.source
				and now - drop.born < 0.08
				and hit.Instance:IsDescendantOf(drop.source)
			then
				hit = nil
			end
		end
		if hit or now - drop.born > 4 or drop.part.Parent == nil then
			if hit then
				land(drop, hit)
			end
			drop.part:Destroy()
			drops[index] = drops[#drops]
			drops[#drops] = nil
			continue
		end
		drop.position += travel
		-- stretched along its speed (a fast drop is a streak)
		local speed = drop.velocity.Magnitude
		local stretch = 1 + math.min(speed * 0.045, 2.6)
		drop.shape.Scale = Vector3.new(1 / math.sqrt(stretch), 1 / math.sqrt(stretch), stretch)
		table.insert(moved, drop.part)
		table.insert(
			frames,
			if speed > 0.1
				then CFrame.lookAt(
					drop.position,
					drop.position + drop.velocity,
					if math.abs(drop.velocity.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
				)
				else CFrame.new(drop.position)
		)
		index += 1
	end
	-- Strands: the tail is dragged behind the gob, the thread thins as it
	-- stretches, and snaps.
	index = 1
	while index <= #strands do
		local strand = strands[index]
		local head = strand.head
		local alive = table.find(drops, head) ~= nil
		local gap = head.position - strand.tail
		local length = gap.Magnitude
		if not alive or length > strand.rest * 5 then
			-- snapped (or its gob landed): the thread falls as drops
			local count = math.clamp(math.floor(length / 0.25), 1, 5)
			for k = 1, count do
				local at = strand.tail + gap * (k / (count + 1))
				newDrop(
					at,
					strand.tailVelocity * 0.8 + Vector3.new(0, -2, 0),
					strand.thickness * 1.2,
					nil
				)
			end
			strand.thread:Destroy()
			strands[index] = strands[#strands]
			strands[#strands] = nil
			continue
		end
		-- (pulled toward the gob like a stretched spring, gravity on it too)
		local pull = if length > strand.rest
			then gap.Unit * (length - strand.rest) * 60
			else Vector3.zero
		strand.tailVelocity += (gravity + pull - strand.tailVelocity * 2.5) * dt
		strand.tail += strand.tailVelocity * dt
		local mid = (strand.tail + head.position) / 2
		local thin = math.clamp(strand.rest / math.max(length, 1e-3), 0.25, 1)
		strand.thread.Size =
			Vector3.new(math.max(length, 0.02), strand.thickness * thin, strand.thickness * thin)
		table.insert(moved, strand.thread)
		table.insert(
			frames,
			if length > 1e-3
				then CFrame.lookAt(mid, head.position) * CFrame.Angles(0, math.rad(90), 0)
				else CFrame.new(mid)
		)
		index += 1
	end
	if #moved > 0 then
		workspace:BulkMoveTo(moved, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end
RunService.Heartbeat:Connect(step)

------------------------------------------------------------------------------
-- Sprays
------------------------------------------------------------------------------

function Blood.mist(point: Vector3, direction: Vector3, amount: number)
	local k = math.sqrt(math.min(amount, 2.5)) -- (a fine haze, never a red cloud)
	local attachment = Instance.new("Attachment")
	local d = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.yAxis
	local up = if math.abs(d.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	attachment.WorldCFrame = CFrame.lookAt(point, point + d, up)
	attachment.Parent = workspace.Terrain
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = SMOKE
	mist.Color = ColorSequence.new(Blood.FRESH, Blood.DARK)
	mist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.3, 0.45 * k),
		NumberSequenceKeypoint.new(1, 0.8 * k),
	})
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.4, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Speed = NumberRange.new(3, 10)
	mist.SpreadAngle = Vector2.new(35, 35)
	mist.Lifetime = NumberRange.new(0.4, 0.9)
	mist.Drag = 5
	mist.Acceleration = Vector3.new(0, -3, 0)
	mist.EmissionDirection = Enum.NormalId.Front
	mist.RotSpeed = NumberRange.new(-60, 60)
	mist.Rotation = NumberRange.new(0, 360)
	mist.Rate = 0
	mist.Parent = attachment
	mist:Emit(math.min(math.floor(4 + 3 * amount), 14))
	Debris:AddItem(attachment, 1.2)
end

-- A cone of directions around `d` (spread in degrees).
local function cone(d: Vector3, spread: number): Vector3
	local base = if d.Magnitude > 1e-3 then d.Unit else Vector3.yAxis
	local up = if math.abs(base.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local frame = CFrame.lookAt(Vector3.zero, base, up)
	local a = math.rad(spread) * math.sqrt(random:NextNumber())
	local b = random:NextNumber(0, math.pi * 2)
	return frame:VectorToWorldSpace(
		Vector3.new(math.sin(a) * math.cos(b), math.sin(a) * math.sin(b), -math.cos(a))
	)
end

function Blood.spray(
	point: Vector3,
	direction: Vector3,
	amount: number,
	source: Model?,
	noMist: boolean?
)
	local d = if direction.Magnitude > 1e-3 then direction.Unit else Vector3.yAxis
	-- many small drops, a few big gobs
	local count = math.floor(8 + 14 * amount)
	for _ = 1, count do
		local big = random:NextNumber() < 0.18
		local size = if big then random:NextNumber(0.1, 0.17) else random:NextNumber(0.035, 0.08)
		local speed = random:NextNumber(6, 18)
			* (if big then 0.7 else 1)
			* (0.8 + 0.2 * math.min(amount, 3))
		local velocity = cone(d, if big then 30 else 45) * speed
			+ Vector3.new(0, random:NextNumber(1, 5), 0)
		newDrop(point + d * 0.1, velocity, size, source)
	end
	-- thick strings pulled out of the wound
	if amount >= 1 then
		for _ = 1, math.clamp(math.floor(amount * 1.5), 1, 6) do
			local velocity = cone(d, 30) * random:NextNumber(5, 11)
				+ Vector3.new(0, random:NextNumber(1, 4), 0)
			Blood.strand(point + d * 0.05, velocity, random:NextNumber(0.045, 0.08), source)
		end
	end
	if amount >= 1.5 and not noMist then
		Blood.mist(point, d, amount)
	end
end

return table.freeze(Blood)
