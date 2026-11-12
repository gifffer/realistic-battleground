--!strict
-- BloodGush: how a torn artery bleeds, for the finishers that tear something
-- out (the head under the bat, the liver, the arm). Shared by HeadBlast,
-- LiverRip and ArmRip, on every client.
--
-- What a real one does, and what this draws:
--   • it SPURTS with the heartbeat: a jet on each beat (strong, arcing out
--     a metre or two), a weak flow between beats; the heart races, then
--     slows and weakens as the blood runs out (a few seconds);
--   • each jet comes down where its arc meets the floor: elongated drops
--     in a line along the way it flew, a splash where the bulk lands;
--   • it runs down the body from the wound, in streaks that lengthen;
--   • a pool spreads under it, faster at first;
--   • whoever is right there gets it on them (dark spots on his front, his
--     arms).
--
--   BloodGush.artery(part, local, options)   jets out of `local` (in `part`'s
--       space; the jet goes out along its LookVector)
--   BloodGush.runDown(part, local, count, seed)   streaks running down the body
--   BloodGush.splatter(target, toward, count, seed)   spots on someone close
--   BloodGush.neck(model, seed)       the head gone: both carotids, the
--                                     jugular welling, down the chest
--   BloodGush.torso(model, local, outward, seed)   a hole in the body (the
--                                     liver, the shoulder): the artery, the
--                                     streaks running down

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local HeadBlast = require(script.Parent.HeadBlast)

local BloodGush = {}

local BLOOD = Color3.fromRGB(78, 6, 6) -- dark, once out
local BLOOD_WET = Color3.fromRGB(110, 8, 8) -- fresh, arterial (brighter)
local GRAVITY = 60 -- studs/s², what the particles use too (they look heavier)

export type Options = {
	seconds: number, -- how long it keeps pumping
	beat: number, -- seconds between beats at the start (it slows down)
	speed: number, -- studs/s of the first jets
	size: number, -- how thick the jet is (studs)
	pool: number, -- studs across the pool grows to (0: none)
	seed: number,
	ignore: { Instance }?, -- (bodies the jets' landing rays go through)
}

local function jetEmitter(parent: Attachment, size: number): ParticleEmitter
	local jet = Instance.new("ParticleEmitter")
	jet.Name = "Jet"
	jet.Texture = "rbxasset://textures/particles/smoke_main.dds"
	jet.Color = ColorSequence.new(BLOOD_WET, BLOOD)
	jet.LightEmission = 0
	jet.LightInfluence = 1
	jet.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	jet.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, size * 0.6),
	})
	-- stretched along the way they fly: a stream, not dots
	jet.Orientation = Enum.ParticleOrientation.VelocityParallel
	jet.Squash = NumberSequence.new(-1.2)
	jet.Lifetime = NumberRange.new(0.5, 0.9)
	jet.Speed = NumberRange.new(8, 12)
	jet.SpreadAngle = Vector2.new(5, 5)
	jet.Acceleration = Vector3.new(0, -GRAVITY, 0)
	jet.Drag = 0.25
	jet.EmissionDirection = Enum.NormalId.Front
	jet.Rate = 0
	jet.Parent = parent
	return jet
end

local function mistEmitter(parent: Attachment): ParticleEmitter
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(BLOOD_WET)
	mist.LightEmission = 0
	mist.LightInfluence = 1
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	mist.Lifetime = NumberRange.new(0.3, 0.6)
	mist.Speed = NumberRange.new(2, 5)
	mist.SpreadAngle = Vector2.new(40, 40)
	mist.Acceleration = Vector3.new(0, -8, 0)
	mist.Drag = 2
	mist.EmissionDirection = Enum.NormalId.Front
	mist.Rate = 0
	mist.Parent = parent
	return mist
end

-- Where a jet leaving `from` at `velocity` meets the floor (and the line of
-- drops it leaves on the way down): ballistic, the floor found by rays.
local function landing(from: Vector3, velocity: Vector3, ignore: { Instance }): (Vector3?, Vector3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local position, moving = from, velocity
	for _ = 1, 40 do
		local dt = 0.03
		local step = moving * dt
		local hit = workspace:Raycast(position, step, params)
		if hit then
			return hit.Position, moving
		end
		position += step
		moving += Vector3.new(0, -GRAVITY * dt, 0)
	end
	return nil, moving
end

-- One jet's blood coming down: a splash where the bulk lands, drops strung
-- out along the way it flew, short of it and past it.
local function rain(
	from: Vector3,
	velocity: Vector3,
	strength: number,
	ignore: { Instance },
	random: Random
)
	local at, moving = landing(from, velocity, ignore)
	if at == nil then
		return
	end
	local flat = Vector3.new(moving.X, 0, moving.Z)
	local along = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(1, 0, 0)
	local delay = math.clamp((from - at).Magnitude / math.max(velocity.Magnitude, 1), 0.08, 0.6)
	task.delay(delay, function()
		HeadBlast.splash(at, 0.35 + 0.5 * strength, random:NextInteger(1, 2 ^ 20))
		for index = 1, 2 + math.floor(3 * strength) do
			local offset = along * random:NextNumber(-0.6, 1.2) * index * 0.35
				+ along:Cross(Vector3.new(0, 1, 0)) * random:NextNumber(-0.12, 0.12)
			HeadBlast.streak(
				at + offset,
				random:NextNumber(0.18, 0.4) * (0.6 + strength),
				along,
				random:NextInteger(1, 2 ^ 20)
			)
		end
	end)
end

-- An artery torn open at `local` (in `part`'s space; out along its LookVector).
function BloodGush.artery(part: BasePart, localCFrame: CFrame, options: Options)
	local random = Random.new(options.seed)
	local hole = Instance.new("Attachment")
	hole.Name = "Artery"
	hole.CFrame = localCFrame
	hole.Parent = part
	local jet = jetEmitter(hole, options.size)
	local mist = mistEmitter(hole)
	local ignore = options.ignore or { part }
	if options.pool > 0 then
		task.delay(0.3, function()
			if part.Parent then
				HeadBlast.pool(
					hole.WorldPosition,
					options.pool,
					options.seconds + 3,
					random:NextInteger(1, 2 ^ 20)
				)
			end
		end)
	end
	task.spawn(function()
		local start = os.clock()
		local beat = options.beat
		-- the first one: the vessel tears, all at once
		mist:Emit(30)
		jet.Speed = NumberRange.new(options.speed * 0.9, options.speed * 1.1)
		jet:Emit(math.floor(60 * options.size / 0.12))
		rain(
			hole.WorldPosition,
			hole.WorldCFrame.LookVector * options.speed + Vector3.new(0, 2, 0),
			1,
			ignore,
			random
		)
		while hole.Parent and part.Parent and os.clock() - start < options.seconds do
			local left = 1 - (os.clock() - start) / options.seconds -- (it runs out)
			local strength = left * left * 0.8 + left * 0.2
			-- the jet, on the beat: its own direction wavers (the body moves)
			local wobble =
				CFrame.Angles(random:NextNumber(-0.12, 0.12), random:NextNumber(-0.12, 0.12), 0)
			hole.CFrame = localCFrame * wobble
			local speed = options.speed * (0.35 + 0.65 * strength)
			jet.Speed = NumberRange.new(speed * 0.85, speed * 1.1)
			jet.Rate = 260 * (0.3 + 0.7 * strength)
			mist.Rate = 40 * strength
			rain(
				hole.WorldPosition,
				hole.WorldCFrame.LookVector * speed + Vector3.new(0, 1.5, 0),
				strength,
				ignore,
				random
			)
			task.wait(0.11 + 0.05 * (1 - strength))
			-- between beats: it wells out and runs
			jet.Rate = 18 * strength
			jet.Speed = NumberRange.new(1, 2.5)
			mist.Rate = 0
			task.wait(math.max(0.05, beat - 0.13))
			beat = math.min(beat * 1.06, 1.1) -- (the heart slows)
		end
		jet.Rate = 0
		mist.Rate = 0
		-- it keeps oozing a little
		jet.Speed = NumberRange.new(0.3, 1)
		jet.Rate = 6
		task.wait(3)
		jet.Rate = 0
		Debris:AddItem(hole, 1.5)
	end)
end

-- Blood running down the body from `local` (in `part`'s space): thin dark
-- streaks on its surface, welded to it, lengthening downwards.
function BloodGush.runDown(part: BasePart, localPoint: Vector3, count: number, seed: number)
	local random = Random.new(seed)
	for index = 1, count do
		task.delay(random:NextNumber(0, 0.8) + index * 0.1, function()
			if part.Parent == nil then
				return
			end
			-- on the face of the part nearest the wound, going down it
			local half = part.Size / 2
			local start = localPoint
				+ Vector3.new(
					random:NextNumber(-0.18, 0.18),
					random:NextNumber(-0.1, 0.05),
					random:NextNumber(-0.18, 0.18)
				)
			local face = Vector3.new(
				math.clamp(start.X, -half.X, half.X),
				math.clamp(start.Y, -half.Y, half.Y),
				math.clamp(start.Z, -half.Z, half.Z)
			)
			-- (snap to the closest face, a hair out of it)
			local dx, dz = half.X - math.abs(face.X), half.Z - math.abs(face.Z)
			local normal = if dx < dz
				then Vector3.new(math.sign(face.X), 0, 0)
				else Vector3.new(0, 0, math.sign(face.Z))
			face = if dx < dz
				then Vector3.new(math.sign(face.X) * (half.X + 0.012), face.Y, face.Z)
				else Vector3.new(face.X, face.Y, math.sign(face.Z) * (half.Z + 0.012))
			local width = random:NextNumber(0.05, 0.11)
			local length = math.min(random:NextNumber(0.6, 1.6), face.Y + half.Y)
			local streak = Instance.new("Part")
			streak.Name = "BloodRun"
			streak.Anchored = false
			streak.CanCollide = false
			streak.CanQuery = false
			streak.CanTouch = false
			streak.Massless = true
			streak.CastShadow = false
			streak.Material = Enum.Material.SmoothPlastic
			streak.Color = if random:NextNumber() < 0.5 then BLOOD else BLOOD_WET
			streak.Reflectance = 0.12
			-- thin along the face's normal, starting short at the wound
			local size = if normal.X ~= 0
				then Vector3.new(0.01, 0.05, width)
				else Vector3.new(width, 0.05, 0.01)
			streak.Size = size
			local top = CFrame.new(face)
			streak.CFrame = part.CFrame * top * CFrame.new(0, -size.Y / 2, 0)
			local weld = Instance.new("Weld")
			weld.Part0 = part
			weld.Part1 = streak
			weld.C0 = top * CFrame.new(0, -size.Y / 2, 0)
			weld.Parent = streak
			streak.Parent = part
			local grow = random:NextNumber(1.2, 2.6)
			local full = if normal.X ~= 0
				then Vector3.new(0.01, length, width)
				else Vector3.new(width, length, 0.01)
			TweenService:Create(
				streak,
				TweenInfo.new(grow, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = full }
			):Play()
			TweenService
				:Create(
					weld,
					TweenInfo.new(grow, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						C0 = top * CFrame.new(0, -length / 2, 0),
					}
				)
				:Play()
			Debris:AddItem(streak, 40)
		end)
	end
end

-- Spots of blood on `target` (someone right there), on its side facing
-- `toward` (the wound): his front, his arms.
function BloodGush.splatter(target: Model, toward: Vector3, count: number, seed: number)
	local random = Random.new(seed)
	local parts: { BasePart } = {}
	for _, name in { "Torso", "Right Arm", "Left Arm", "Head" } do
		local part = target:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	if #parts == 0 then
		return
	end
	for _ = 1, count do
		local part = parts[random:NextInteger(1, #parts)]
		local side = part.CFrame:VectorToObjectSpace(toward - part.Position)
		local half = part.Size / 2
		-- on the face that looks at the wound (the biggest component)
		local ax, ay, az = math.abs(side.X), math.abs(side.Y), math.abs(side.Z)
		local point: Vector3
		local size: Vector3
		local s = random:NextNumber(0.06, 0.16)
		if ax >= ay and ax >= az then
			point = Vector3.new(
				math.sign(side.X) * (half.X + 0.01),
				random:NextNumber(-half.Y, half.Y) * 0.9,
				random:NextNumber(-half.Z, half.Z) * 0.9
			)
			size = Vector3.new(0.01, s * random:NextNumber(1, 2.2), s)
		elseif az >= ay then
			point = Vector3.new(
				random:NextNumber(-half.X, half.X) * 0.9,
				random:NextNumber(-half.Y, half.Y) * 0.9,
				math.sign(side.Z) * (half.Z + 0.01)
			)
			size = Vector3.new(s, s * random:NextNumber(1, 2.2), 0.01)
		else
			point = Vector3.new(
				random:NextNumber(-half.X, half.X) * 0.9,
				math.sign(side.Y) * (half.Y + 0.01),
				random:NextNumber(-half.Z, half.Z) * 0.9
			)
			size = Vector3.new(s, 0.01, s)
		end
		local spot = Instance.new("Part")
		spot.Name = "BloodSpot"
		spot.CanCollide = false
		spot.CanQuery = false
		spot.CanTouch = false
		spot.Massless = true
		spot.CastShadow = false
		spot.Material = Enum.Material.SmoothPlastic
		spot.Color = BLOOD_WET
		spot.Reflectance = 0.1
		spot.Size = size
		spot.CFrame = part.CFrame * CFrame.new(point)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = spot
		weld.Parent = spot
		spot.Parent = part
		Debris:AddItem(spot, 25)
	end
end

-- The head gone (the bat): the two carotids spurt up and out on each beat,
-- the jugular wells and runs, the blood runs down the chest and back.
function BloodGush.neck(model: Model, seed: number)
	local torso = model:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return
	end
	local top = torso.Size.Y / 2
	for index, x in { -0.17, 0.17 } do
		local from = Vector3.new(x, top + 0.08, -0.12)
		BloodGush.artery(torso, CFrame.lookAt(from, from + Vector3.new(x * 1.5, 1, -0.35)), {
			seconds = 5.5,
			beat = 0.38,
			speed = 15,
			size = 0.13,
			pool = if index == 1 then 4 else 0,
			seed = seed + index,
			ignore = { model },
		})
	end
	local back = Vector3.new(0, top + 0.05, 0.15)
	BloodGush.artery(torso, CFrame.lookAt(back, back + Vector3.new(0, 1, 0.6)), {
		seconds = 6,
		beat = 0.38,
		speed = 3,
		size = 0.16,
		pool = 0,
		seed = seed + 7,
		ignore = { model },
	})
	BloodGush.runDown(torso, Vector3.new(0, top, -0.5), 7, seed + 11)
	BloodGush.runDown(torso, Vector3.new(0, top, 0.5), 5, seed + 13)
end

-- A hole torn in the body at `localPoint` (torso space), facing `outward`:
-- the artery behind it spurting, the blood running down from it.
function BloodGush.torso(
	model: Model,
	localPoint: Vector3,
	outward: Vector3,
	seed: number,
	speed: number?
)
	local torso = model:FindFirstChild("Torso")
	if torso == nil or not torso:IsA("BasePart") then
		return
	end
	BloodGush.artery(
		torso,
		CFrame.lookAt(localPoint, localPoint + outward.Unit + Vector3.new(0, 0.25, 0)),
		{
			seconds = 5.5,
			beat = 0.4,
			speed = speed or 11,
			size = 0.15,
			pool = 3.8,
			seed = seed,
			ignore = { model },
		}
	)
	BloodGush.runDown(torso, localPoint, 9, seed + 5)
end

return table.freeze(BloodGush)
