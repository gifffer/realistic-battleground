--!strict
-- Train: a freight train crosses the railway viaduct now and then. SERVER-AUTHORITATIVE for
-- the timing and the hits; every player's computer draws its own copy of the train
-- (Client/Controllers/TrainController), moved from the same clock, so it is smooth and in
-- the same place for everyone.
--
-- The schedule:
--   • the first pass comes Config.Train.FIRST_PASS seconds after the city is built, then
--     one every INTERVAL seconds (random, 70 to 130 s), alternating directions;
--   • WARN_TIME (5 s) before the locomotive comes out of its tunnel, the signals blink red,
--     the horn sounds and the ground rumbles (clients);
--   • the train crosses at SPEED studs per second and disappears into the other tunnel.
-- The track's ends come from the city data (attributes TrainA / TrainB / TrainLaneWidth of
-- Workspace > City). No such attributes (a hand-made map, an old city): no train at all.
--
-- What the clients read (attributes of Workspace > City, see Shared/Util/TrainPath):
--   TrainWarnAt, TrainPassStart, TrainPassEnd (server times), TrainDir (1 = A→B, -1 = B→A),
--   TrainSpeed, TrainLength.
--
-- The hits: every frame of a pass, the server works out where the train's box is (from the
-- time: no physics), and every fighter (player or training dummy) whose HumanoidRootPart is
-- inside it gets hit ONCE per pass: Combat.environmentHit → Config.Train.DAMAGE, knocked
-- down and thrown sideways off the track and forward with the train. Lethal damage, or a
-- fighter lying knocked out on the track: dead at once ("<name> was hit by a train").
-- Fighters in a duel are never hit (and duels are in their own arenas anyway).
--
-- Studio: shorter waits (Config.Train.STUDIO_FAST), and you can call a train at once from
-- the command bar (server): workspace:SetAttribute("TrainForce", true)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local TrainPath = require(ReplicatedStorage.Shared.Util.TrainPath)
local Combat = require(script.Parent.Combat)

local T = Config.Train

local Train = {}

local random = Random.new()
local fast = RunService:IsStudio() and T.STUDIO_FAST
-- A train asked for from the Studio command bar: the next one comes right away.
local forced = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function between(range: NumberRange): number
	return random:NextNumber(range.Min, range.Max)
end

-- Waits `seconds`, but stops early if a train is forced from Studio.
local function waitOrForced(seconds: number)
	local untilTime = os.clock() + seconds
	while os.clock() < untilTime and not forced do
		task.wait(0.25)
	end
	forced = false
end

-- The model's HumanoidRootPart, if it is a living fighter.
local function rootOf(model: Instance): BasePart?
	if not model:IsA("Model") then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

-- One frame of a pass: hits every fighter inside the train's box (once per pass each).
local function checkHits(
	track: TrainPath.Track,
	pass: TrainPath.Pass,
	frame: TrainPath.Frame,
	hit: { [Model]: boolean }
)
	local nose = TrainPath.nose(pass, now())
	local tail = nose - pass.length
	-- (the train is only out of the tunnels between 0 and trackLength)
	if nose < 0 or tail > frame.trackLength then
		return
	end
	local halfWidth = math.min(T.HALF_WIDTH + 1, track.laneWidth / 2 + 0.5)
	for _, instance in CollectionService:GetTagged(Config.Combat.TAG) do
		local root = rootOf(instance)
		local model = instance :: Model
		if root == nil or hit[model] then
			continue
		end
		local offset = root.Position - frame.origin
		local along = offset:Dot(frame.axis)
		if along < tail - 1 or along > nose + 1.2 then
			continue
		end
		-- rail top under that point (the track may slope a little)
		local railY = frame.origin.Y + frame.axis.Y * along
		local height = root.Position.Y - railY
		local side = offset:Dot(frame.right)
		if math.abs(side) > halfWidth or height < -2 or height > T.HEIGHT + 1.5 then
			continue
		end
		hit[model] = true
		-- thrown off the track, on the side they were on (random if dead centre), forward
		-- with the train and up
		local sideSign = if math.abs(side) > 0.3
			then math.sign(side)
			else (if random:NextNumber() < 0.5 then -1 else 1)
		local velocity = frame.axis * (pass.speed * T.FLING_FORWARD)
			+ frame.right * (sideSign * T.FLING_SIDE)
			+ Vector3.new(0, T.FLING_UP, 0)
		Combat.environmentHit(model, T.DAMAGE, velocity, T.KNOCKDOWN_TIME, "Train")
	end
end

-- One pass of the train, from the warning to the back of the train leaving the viaduct.
local function runPass(city: Instance, track: TrainPath.Track, dir: number)
	local warnAt = now()
	local pass: TrainPath.Pass = {
		warnAt = warnAt,
		start = warnAt + T.WARN_TIME,
		dir = dir,
		speed = T.SPEED,
		length = T.LENGTH,
	}
	local passEnd = TrainPath.passEnd(track, pass)
	-- (TrainWarnAt last: clients start the pass when it changes, the rest is already there)
	city:SetAttribute("TrainDir", pass.dir)
	city:SetAttribute("TrainSpeed", pass.speed)
	city:SetAttribute("TrainLength", pass.length)
	city:SetAttribute("TrainPassStart", pass.start)
	city:SetAttribute("TrainPassEnd", passEnd)
	city:SetAttribute("TrainWarnAt", pass.warnAt)

	local frame = TrainPath.frame(track, dir)
	local hit: { [Model]: boolean } = {}
	local connection = RunService.Heartbeat:Connect(function()
		checkHits(track, pass, frame, hit)
	end)
	task.wait(math.max(0, passEnd - now()) + 0.2)
	connection:Disconnect()
end

local function waitForTrack(): (Instance?, TrainPath.Track?)
	local city = workspace:WaitForChild("City", 60)
	if city == nil then
		return nil, nil
	end
	while city:GetAttribute("Built") ~= true do
		city:GetAttributeChangedSignal("Built"):Wait()
	end
	return city, TrainPath.readTrack(city)
end

local function director()
	local city, track = waitForTrack()
	if city == nil or track == nil then
		return -- no city, or a city without a railway: no train
	end
	local dir = if random:NextNumber() < 0.5 then 1 else -1
	waitOrForced(if fast then 15 else between(T.FIRST_PASS))
	while city.Parent do
		runPass(city, track, dir)
		dir = -dir
		waitOrForced(if fast then 35 else between(T.INTERVAL))
	end
end

function Train.start()
	task.spawn(director)
	-- Studio only: workspace:SetAttribute("TrainForce", true) in the command bar calls the
	-- next train at once (or right after the one passing now).
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("TrainForce"):Connect(function()
			if workspace:GetAttribute("TrainForce") then
				forced = true
				workspace:SetAttribute("TrainForce", nil)
			end
		end)
	end
end

return Train
