--!strict
-- BloodBody: blood ON the fighters (client-side, the same on every screen as
-- far as the events allow).
--
--   • Runs from a wound: blood runs down the skin from a cut to the lowest
--     point of that face, and the bleeding drips fall from the END of the run
--     (not from nowhere next to the cut).
--   • Nosebleeds and split lips: a head hit that draws blood often bleeds
--     from the nose (a run to the lip and chin, drops off the chin) or the
--     mouth (a short run, a spit of blood on a heavy hit).
--   • Clothes SOAK: on a shirt / pants, blood spreads through the cloth
--     around a wound for half a minute (darker than on skin, never shiny);
--     on bare skin it is a thin film instead.
--   • Bloody fists: hitting a bloody face leaves blood on the knuckles;
--     swinging a bloody fist flicks drops off it in a line (cast-off).
--   Everything on a body goes when the body goes (respawn, removed).
--
--   BloodBody.dripFrom(model, part, point, random)   where a wound drips
--       from (the tip of its run, made the first time)
--   BloodBody.soak(model, part, point, amount)       blood into the clothes
--   BloodBody.face(model, attacker, heavy, random)   nose / mouth bleeding
--   BloodBody.bloodyLimb(model, limb, amount)        blood on a fist / foot
--   BloodBody.onSwing(model, random?)                a swing: cast-off
--   BloodBody.bloodiness(model)                      0..1, the bloodiest limb

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Blood = require(script.Parent.Blood)
local BloodAge = require(script.Parent.BloodAge)
local BloodStain = require(script.Parent.BloodStain)

local BloodBody = {}

local PALETTE = Config.Blood.PALETTE
local MAX_SOAKS_PER_PART = 3
local MAX_SOAKS = 12 -- per character
local MAX_FACE_RUNS = 6
local UP = Vector3.new(0, 1, 0)

type Soak = {
	record: BloodAge.Record,
	part: BasePart,
	localPoint: Vector3,
	started: number,
	time: number, -- seconds to spread
	target: number, -- how much bigger it gets (×)
	maxScale: number, -- (kept on its face)
}

type Knuckle = { record: BloodAge.Record, limb: string }

type State = {
	model: Model,
	bloodiness: { [string]: number },
	knuckles: { Knuckle },
	soaks: { Soak },
	woundRuns: { [string]: { run: Blood.Run, at: number } },
	faceRuns: number,
}

local states: { [Model]: State } = {}

local function stateOf(model: Model): State
	local state = states[model]
	if state then
		return state
	end
	local made: State = {
		model = model,
		bloodiness = {},
		knuckles = {},
		soaks = {},
		woundRuns = {},
		faceRuns = 0,
	}
	states[model] = made
	model.AncestryChanged:Connect(function()
		if model.Parent == nil and states[model] == made then
			states[model] = nil
			BloodAge.releaseOwner(model)
		end
	end)
	return made
end

-- Is `part` under clothes (a Shirt covers the torso and arms, Pants the legs)?
local function clothed(model: Model, part: BasePart): boolean
	local name = part.Name
	if name == "Torso" or string.find(name, "Arm") then
		return model:FindFirstChildOfClass("Shirt") ~= nil
	elseif string.find(name, "Leg") then
		return model:FindFirstChildOfClass("Pants") ~= nil
	end
	return false
end

------------------------------------------------------------------------------
-- Runs from wounds, drips from their tip
------------------------------------------------------------------------------

-- Where a wound at `point` (world) on `part` drips from: the bead at the end
-- of the blood running down from it (the run is made the first time, then
-- kept a while). `point` itself until the run gets going.
function BloodBody.dripFrom(model: Model, part: BasePart, point: Vector3, random: Random): Vector3
	if not Config.Blood.ENABLED then
		return point
	end
	local state = stateOf(model)
	local l = part.CFrame:PointToObjectSpace(point)
	local key = string.format(
		"%s_%d_%d_%d",
		part.Name,
		math.floor(l.X * 4),
		math.floor(l.Y * 4),
		math.floor(l.Z * 4)
	)
	local now = os.clock()
	local entry = state.woundRuns[key]
	if entry and not entry.run.record.dead and now - entry.at < 25 then
		return Blood.runTip(entry.run) or point
	end
	local _, _, out = BloodStain.onSkin(part, point)
	local run = Blood.run(point, out, random:NextNumber(0.04, 0.065), {
		onto = part,
		random = random,
		length = random:NextNumber(0.5, 1.4),
		owner = model,
		fork = false,
	})
	if run then
		state.woundRuns[key] = { run = run, at = now }
		if
			part.Name == "Torso"
			or string.find(part.Name, "Arm")
			or string.find(part.Name, "Leg")
		then
			-- (and it soaks into the cloth around the cut)
			BloodBody.soak(model, part, point, 0.6)
		end
	end
	return point
end

------------------------------------------------------------------------------
-- Clothes soaking
------------------------------------------------------------------------------

-- Room around `localPoint` on its face before an edge (to keep a soak on it).
local function roomAround(part: BasePart, localPoint: Vector3, localNormal: Vector3): number
	local h = part.Size / 2
	local room = math.huge
	if math.abs(localNormal.X) < 0.7 then
		room = math.min(room, h.X - math.abs(localPoint.X))
	end
	if math.abs(localNormal.Y) < 0.7 then
		room = math.min(room, h.Y - math.abs(localPoint.Y))
	end
	if math.abs(localNormal.Z) < 0.7 then
		room = math.min(room, h.Z - math.abs(localPoint.Z))
	end
	return math.max(room, 0.05)
end

-- Blood into the clothes at `point` on `part` (`amount` ~ 0.5 a cut, 1 a
-- heavy one): a stain that spreads through the cloth for half a minute. On
-- bare skin: a thin film instead.
function BloodBody.soak(model: Model, part: BasePart, point: Vector3, amount: number)
	if not Config.Blood.ENABLED then
		return
	end
	local skin, at, out = BloodStain.onSkin(part, point)
	if skin == nil then
		return
	end
	local state = stateOf(model)
	local random =
		Random.new(Blood.seed(model.Name, skin.Name, math.floor(at.X * 10), math.floor(at.Z * 10)))
	if not clothed(model, skin) then
		local w = 0.12 + 0.1 * amount
		BloodStain.stain("skinSmear", at, out, Vector3.new(0, -1, 0), w, w * 1.5, {
			onto = skin,
			random = random,
			profile = "smear",
			start = PALETTE.ARTERIAL_LIGHT,
			alpha = 0.3,
			owner = model,
		})
		return
	end
	local localPoint = skin.CFrame:PointToObjectSpace(at)
	-- an old soak close by spreads further instead
	local count = 0
	for _, soak in state.soaks do
		if soak.part == skin and not soak.record.dead then
			count += 1
			if (soak.localPoint - localPoint).Magnitude < 0.35 then
				soak.target = math.min(soak.maxScale, soak.target + 0.4 * amount)
				soak.time = math.max(soak.time, os.clock() - soak.started + 10)
				BloodAge.touch(soak.record)
				return
			end
		end
	end
	if count >= MAX_SOAKS_PER_PART or #state.soaks >= MAX_SOAKS then
		return
	end
	local size = 0.16 + 0.1 * amount
	local record = BloodStain.place("soak", at, out, Vector3.new(0, -1, 0), size, size * 1.15, {
		onto = skin,
		random = random,
		profile = "soak",
		start = PALETTE.FABRIC_SOAK,
		dryColor = PALETTE.FABRIC_SOAK_DRY,
		alpha = 0.15,
		owner = model,
		priority = 3,
	})
	if record == nil then
		return
	end
	local localNormal = skin.CFrame:VectorToObjectSpace(out)
	local room = roomAround(skin, localPoint, localNormal)
	local maxScale = math.clamp(room / (size * 0.6), 1, 2.5)
	table.insert(state.soaks, {
		record = record,
		part = skin,
		localPoint = localPoint,
		started = os.clock(),
		time = random:NextNumber(20, 40),
		target = math.min(maxScale, 1 + 0.9 * amount),
		maxScale = maxScale,
	})
end

------------------------------------------------------------------------------
-- The face: nose, mouth
------------------------------------------------------------------------------

-- A head hit that draws blood: often the nose bleeds (a run down to the lip
-- and chin, drops falling off the chin for a few seconds), sometimes the
-- mouth (a split lip; a spit of blood on a heavy hit).
function BloodBody.face(model: Model, attacker: Model?, heavy: boolean, random: Random)
	if not Config.Blood.ENABLED then
		return
	end
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local state = stateOf(model)
	if state.faceRuns >= MAX_FACE_RUNS then
		return
	end
	local roll = random:NextNumber()
	if roll < 0.5 then
		-- the nose: both nostrils sometimes
		state.faceRuns += 1
		local nostrils: { number } = if random:NextNumber() < 0.4
			then { -0.05, 0.05 }
			else { random:NextNumber(-0.05, 0.05) }
		local tip: Blood.Run? = nil
		for _, x in nostrils do
			local point = head.CFrame * Vector3.new(x, -0.12, -0.62)
			local _, _, out = BloodStain.onSkin(head, point)
			tip = Blood.run(point, out, random:NextNumber(0.03, 0.045), {
				onto = head,
				random = random,
				length = random:NextNumber(0.2, 0.3),
				owner = model,
				start = PALETTE.ARTERIAL,
				fork = false,
			}) or tip
		end
		-- drops off the chin (about one every two seconds, a few seconds)
		local seconds = random:NextNumber(3, 6)
		local dropSeed = random:NextInteger(1, 2 ^ 30)
		task.spawn(function()
			local drips = Random.new(dropSeed)
			local stop = os.clock() + seconds
			task.wait(0.6)
			while os.clock() < stop and head.Parent do
				local from = (if tip then Blood.runTip(tip) else nil)
					or (head.CFrame * Vector3.new(0, -0.45, -0.5))
				Blood.drop(
					from,
					head.AssemblyLinearVelocity * 0.5,
					drips:NextNumber(0.035, 0.055),
					drips
				)
				task.wait(drips:NextNumber(1.4, 2.6))
			end
		end)
	elseif roll < 0.7 then
		-- the mouth: a split lip, a short run from its corner
		state.faceRuns += 1
		local x = if random:NextNumber() < 0.5 then -0.14 else 0.14
		local point = head.CFrame * Vector3.new(x, -0.27, -0.58)
		local _, _, out = BloodStain.onSkin(head, point)
		Blood.run(point, out, 0.03, {
			onto = head,
			random = random,
			length = random:NextNumber(0.1, 0.18),
			owner = model,
			fork = false,
		})
		if heavy and attacker then
			-- a spit of blood toward the blow's way
			local toward = head.Position - attacker:GetPivot().Position
			local flat = Vector3.new(toward.X, 0, toward.Z)
			local d = if flat.Magnitude > 1e-3 then flat.Unit else head.CFrame.LookVector
			for _ = 1, 6 do
				local side = d:Cross(UP) * random:NextNumber(-0.5, 0.5)
				Blood.ballistic(
					head.CFrame * Vector3.new(0, -0.27, -0.62),
					(d + side + UP * random:NextNumber(0.1, 0.5)).Unit * random:NextNumber(5, 10),
					random:NextNumber(0.02, 0.04),
					{ ignore = { model :: Instance }, random = random }
				)
			end
		end
	end
end

------------------------------------------------------------------------------
-- Bloody fists and cast-off
------------------------------------------------------------------------------

local function paintKnuckle(knuckle: Knuckle, bloodiness: number)
	for _, layer in knuckle.record.layers do
		if not layer.rim then
			layer.alpha = math.clamp(0.75 - bloodiness * 0.7, 0.05, 0.9)
		end
	end
	BloodAge.paint(knuckle.record)
end

-- Blood on `limb` (a fist that hit a bloody face): its knuckles redden.
function BloodBody.bloodyLimb(model: Model, limb: BasePart, amount: number)
	if not Config.Blood.ENABLED then
		return
	end
	local state = stateOf(model)
	local value = math.min(1, (state.bloodiness[limb.Name] or 0) + amount)
	state.bloodiness[limb.Name] = value
	for _, knuckle in state.knuckles do
		if knuckle.limb == limb.Name and not knuckle.record.dead then
			BloodAge.touch(knuckle.record)
			paintKnuckle(knuckle, value)
			return
		end
	end
	local isLeg = string.find(limb.Name, "Leg") ~= nil
	local half = limb.Size / 2
	-- the knuckles (fist: the front of its end; foot: the toe)
	local point = limb.CFrame * Vector3.new(0, -half.Y + 0.22, -half.Z)
	local record = BloodStain.place(
		"knuckles",
		point,
		limb.CFrame.LookVector,
		-limb.CFrame.UpVector,
		if isLeg then 0.5 else 0.45,
		0.32,
		{
			onto = limb,
			profile = "body",
			start = PALETTE.VENOUS,
			owner = model,
			alpha = 0.3,
			priority = 3,
		}
	)
	if record then
		local knuckle: Knuckle = { record = record, limb = limb.Name }
		table.insert(state.knuckles, knuckle)
		paintKnuckle(knuckle, value)
	end
end

function BloodBody.bloodiness(model: Model): number
	local state = states[model]
	if state == nil then
		return 0
	end
	local best = 0
	for _, value in state.bloodiness do
		best = math.max(best, value)
	end
	return best
end

-- A swing: a bloody fist flicks blood off in a line (cast-off), smaller and
-- smaller along the swing's arc.
function BloodBody.onSwing(model: Model, random: Random?)
	local state = states[model]
	if state == nil or not Config.Blood.ENABLED then
		return
	end
	local bestName, best = nil, 0.25
	for name, value in state.bloodiness do
		if value > best then
			bestName, best = name, value
		end
	end
	if bestName == nil then
		return
	end
	local limb = model:FindFirstChild(bestName)
	local root = model:FindFirstChild("HumanoidRootPart")
	if limb == nil or not limb:IsA("BasePart") or root == nil or not root:IsA("BasePart") then
		return
	end
	local rand = random or Random.new()
	state.bloodiness[bestName] = best - 0.1
	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector * (if string.find(bestName, "Left") then -1 else 1)
	-- (the fist sweeps forward and across: the drops leave along its path)
	local count = math.floor(2 + 6 * best)
	for index = 1, count do
		local along = index / count
		local tip = limb.CFrame * Vector3.new(0, -limb.Size.Y / 2, 0)
		local direction = (look * (1 - along * 0.5) - right * along * 0.6 + UP * rand:NextNumber(
			0.1,
			0.4
		)).Unit
		Blood.ballistic(
			tip,
			direction * rand:NextNumber(9, 15) * (1 - along * 0.4),
			rand:NextNumber(0.02, 0.05) * (1 - along * 0.5),
			{ ignore = { model :: Instance }, random = rand, delay = index * 0.02 }
		)
	end
end

------------------------------------------------------------------------------
-- Spreading soaks, drying fists (4 times a second)
------------------------------------------------------------------------------

local accumulated = 0
RunService.Heartbeat:Connect(function(dt: number)
	accumulated += dt
	if accumulated < 0.25 then
		return
	end
	local step = accumulated
	accumulated = 0
	local now = os.clock()
	for model, state in states do
		if model.Parent == nil then
			continue
		end
		local index = 1
		while index <= #state.soaks do
			local soak = state.soaks[index]
			if soak.record.dead then
				table.remove(state.soaks, index)
				continue
			end
			-- (spreads fast at first, then slower; along the threads a bit more)
			local t = math.clamp((now - soak.started) / soak.time, 0, 1)
			local k = 1 + (soak.target - 1) * (1 - (1 - t) ^ 2)
			BloodStain.rescale(soak.record, k, k * 0.92)
			index += 1
		end
		for name, value in state.bloodiness do
			-- (blood wipes off / dries on the fists in about a minute)
			local left = math.max(0, value - step / 60)
			state.bloodiness[name] = left
			for _, knuckle in state.knuckles do
				if knuckle.limb == name and not knuckle.record.dead then
					paintKnuckle(knuckle, left)
				end
			end
		end
		for key, entry in state.woundRuns do
			if entry.run.record.dead or now - entry.at > 60 then
				state.woundRuns[key] = nil
			end
		end
		if state.faceRuns > 0 and model:GetAttribute("Bleeding") ~= true then
			-- (old face blood washes off between fights: room for new)
			state.faceRuns = math.max(0, state.faceRuns - step / 40)
		end
	end
end)

return table.freeze(BloodBody)
