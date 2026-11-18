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
--   (v2: the runs are BloodRivulet's - they stop and go, a drop hangs and
--   falls from their end; the face's wounds are BloodFace's.)
--
--   BloodBody.woundRun(model, part, point, random)   the run of a wound
--       (made the first time, fed again by each later call)
--   BloodBody.dripFrom(model, part, point, random)   where it is now (its tip)
--   BloodBody.soak(model, part, point, amount)       blood into the clothes
--   BloodBody.face(model, attacker, heavy, random, info?)   nose / mouth / cuts
--   BloodBody.bloodyLimb(model, limb, amount)        blood on a fist / foot
--   BloodBody.countPunch(model, limb)                a punch landed (split knuckles)
--   BloodBody.onSwing(model, random?)                a swing: cast-off
--   BloodBody.bloodiness(model)                      0..1, the bloodiest limb

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Blood = require(script.Parent.Blood)
local BloodAge = require(script.Parent.BloodAge)
local BloodFace = require(script.Parent.BloodFace)
local BloodRivulet = require(script.Parent.BloodRivulet)
local BloodStain = require(script.Parent.BloodStain)

local BloodBody = {}

local PALETTE = Config.Blood.PALETTE
local EXTRA = (Config.Blood :: any).PALETTE :: any
-- (v2 colours, the same values here if the palette doesn't have them yet)
local FABRIC_WET: Color3 = EXTRA.FABRIC_WET or Color3.fromRGB(84, 10, 10) -- wet dark cloth
local RAW: Color3 = EXTRA.RAW or Color3.fromRGB(190, 80, 72) -- raw skin
local MAX_SOAKS_PER_PART = 3
local MAX_SOAKS = 6 -- per character (each soak is 3 pictures: + the wet halo, its fringe)
local SPLIT_AFTER = 12 -- punches landed with one fist before its knuckles split
local UP = Vector3.new(0, 1, 0)

-- The picture to draw: `wanted` once uploaded, else a close uploaded one.
local function kind(wanted: string, fallback: string): string
	return if BloodStain.hasImage(wanted) then wanted else fallback
end
local CRUST_PROFILE = if (Config.Blood.PROFILES :: any).crust then "crust" else "wound"

type Soak = {
	record: BloodAge.Record,
	halo: BloodAge.Record?, -- the darker wet patch around it
	fringe: BloodAge.Record?, -- the pale wicking edge
	size: number,
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
	woundRuns: { [string]: { run: BloodRivulet.Rivulet, at: number } },
	punches: { [string]: number },
	split: { [string]: boolean },
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
		punches = {},
		split = {},
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

-- The run of a wound at `point` (world) on `part`: made the first time
-- (blood breaks over the wound's lowest edge, then runs down in stops and
-- jumps), fed again by every later call while the wound bleeds. Once it
-- reaches a drip point (the bottom of the torso, the chin...) a drop hangs
-- there and falls by itself; a heavy bleed pours a thin stream instead.
function BloodBody.woundRun(
	model: Model,
	part: BasePart,
	point: Vector3,
	random: Random
): BloodRivulet.Rivulet?
	if not Config.Blood.ENABLED then
		return nil
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
	if entry and BloodRivulet.tip(entry.run) and now - entry.at < 25 then
		-- (still bleeding: keep it fed a little longer)
		BloodRivulet.refeed(entry.run, 0.03, 1.2)
		entry.at = now
		return entry.run
	end
	local function perSecond(): number
		local value = model:GetAttribute("BleedPerSecond")
		return if typeof(value) == "number" and value > 0 then value else 1
	end
	local run = BloodRivulet.start(model, part, point, {
		width = random:NextNumber(0.045, 0.065),
		volume = random:NextNumber(0.5, 1.4),
		feed = 4,
		random = Random.new(random:NextInteger(1, 2 ^ 30)),
		source = `{model:GetFullName()}|{key}`, -- (a later bleed rides its old track)
		fast = 2.5, -- (a real bleed, not a trickle: it runs faster)
		-- 3+ per second: it pours; less: a drop hangs, swells and falls
		stream = perSecond() >= 3,
		interval = function(): number
			return math.clamp(0.55 / perSecond(), 0.3, 1.2) * random:NextNumber(0.8, 1.25)
		end,
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
	return run
end

-- Where a wound at `point` drips from now: the tip of its run.
function BloodBody.dripFrom(model: Model, part: BasePart, point: Vector3, random: Random): Vector3
	local run = BloodBody.woundRun(model, part, point, random)
	return (if run then BloodRivulet.tip(run) else nil) or point
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
	-- Under it (drawn first: lower), the way real cloth looks: a pale wicking
	-- fringe where the thin serum travels furthest, and a darker WET patch
	-- (it shows on any shirt colour; on a dark shirt the fringe vanishes and
	-- the wet patch carries it, as in real life).
	local function ring(scale: number, color: Color3, alpha: number): BloodAge.Record?
		return BloodStain.place(
			kind("wickHalo", "soak"),
			at,
			out,
			Vector3.new(0, -1, 0),
			size * scale,
			size * scale * 1.15,
			{
				onto = skin,
				random = random,
				profile = "soak",
				start = color,
				dryColor = PALETTE.FABRIC_SOAK_DRY,
				alpha = alpha,
				owner = model,
				priority = 3,
			}
		)
	end
	local fringe = ring(1.5, PALETTE.ARTERIAL_LIGHT, 0.7)
	local halo = ring(1.2, FABRIC_WET, 0.6) -- (inside the pale fringe, so the fringe still shows)
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
		if halo then
			BloodAge.remove(halo)
		end
		if fringe then
			BloodAge.remove(fringe)
		end
		return
	end
	local localNormal = skin.CFrame:VectorToObjectSpace(out)
	local room = roomAround(skin, localPoint, localNormal)
	local maxScale = math.clamp(room / (size * 0.6), 1, 2.5)
	table.insert(state.soaks, {
		record = record,
		halo = halo,
		fringe = fringe,
		size = size,
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

-- A head hit that draws blood: the nose, the mouth, a cut on the brow...
-- (BloodFace does it; `info` = { strong, moveId, side } of the hit).
function BloodBody.face(
	model: Model,
	attacker: Model?,
	heavy: boolean,
	random: Random,
	info: BloodFace.HitInfo?
)
	BloodFace.hit(model, attacker, info or { strong = heavy }, random)
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

-- A punch landed with `limb` (an arm). After SPLIT_AFTER of them with the
-- same fist in one life, its knuckles split: raw, a little blood (until
-- respawn; the bloody-knuckle mark over it gets wet again at each hit).
function BloodBody.countPunch(model: Model, limb: BasePart)
	if not Config.Blood.ENABLED or string.find(limb.Name, "Arm") == nil then
		return
	end
	local state = stateOf(model)
	local count = (state.punches[limb.Name] or 0) + 1
	state.punches[limb.Name] = count
	if count < SPLIT_AFTER or state.split[limb.Name] then
		return
	end
	state.split[limb.Name] = true
	local half = limb.Size / 2
	local record = BloodStain.place(
		kind("splitKnuckle", "knuckles"),
		limb.CFrame * Vector3.new(0, -half.Y + 0.22, -half.Z),
		limb.CFrame.LookVector,
		-limb.CFrame.UpVector,
		0.3,
		0.2,
		{
			onto = limb,
			profile = CRUST_PROFILE,
			start = RAW,
			dryColor = PALETTE.DRYING,
			owner = model,
			alpha = 0.35,
			pinned = true,
			life = math.huge,
			priority = 3,
		}
	)
	if record then
		BloodRivulet.addMark(model, record, true, false)
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
	-- (3-4 swings empty a fist)
	state.bloodiness[bestName] = best - 0.25
	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector * (if string.find(bestName, "Left") then -1 else 1)
	-- (the fist sweeps forward and across: the drops leave along its path)
	local count = math.floor(2 + 6 * best)
	for index = 1, count do
		local along = index / count
		-- (most of it leaves at the END of the swing, where the fist stops
		-- and turns back: the first two drops wait, and are the biggest)
		local first = index <= 2
		local delay = if first then rand:NextNumber(0.12, 0.18) else 0.18 + index * 0.02
		local tip = limb.CFrame * Vector3.new(0, -limb.Size.Y / 2, 0)
		local direction = (look * (1 - along * 0.5) - right * along * 0.6 + UP * rand:NextNumber(
			0.1,
			0.4
		)).Unit
		Blood.ballistic(
			tip,
			direction * rand:NextNumber(9, 15) * (1 - along * 0.4),
			rand:NextNumber(0.02, 0.05) * (1 - along * 0.5) * (if first then 1.4 else 1),
			{ ignore = { model :: Instance }, random = rand, delay = delay }
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
			-- (spreads fast at first, then slower; along the threads a bit more,
			-- and mostly DOWN: the collar soaks first, then the chest)
			local t = math.clamp((now - soak.started) / soak.time, 0, 1)
			local k = 1 + (soak.target - 1) * (1 - (1 - t) ^ 2)
			local down = soak.size * (k - 1) * 0.3
			for _, layer in { soak.fringe or soak.record, soak.halo or soak.record, soak.record } do
				if not layer.dead then
					BloodStain.rescale(layer, k * 1.07, k * 0.93)
					local shape = BloodStain.shapeOf(layer)
					if shape and #shape.pieces == 1 then
						-- (`along` is down: the picture slides down as it grows)
						BloodStain.movePiece(layer, 1, down / (k * 1.07), 0)
					end
				end
			end
			-- the wet patch fades a little as it spreads (thinner at its edge)
			local halo = soak.halo
			if halo and not halo.dead then
				for _, layer in halo.layers do
					if not layer.rim then
						layer.alpha = 0.55 - 0.2 * t
					end
				end
			end
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
			if BloodRivulet.tip(entry.run) == nil or now - entry.at > 60 then
				state.woundRuns[key] = nil
			end
		end
	end
end)

-- (a wipe of the face with the back of the hand: that hand gets bloody)
BloodFace.setHandHook(BloodBody.bloodyLimb)

return table.freeze(BloodBody)
