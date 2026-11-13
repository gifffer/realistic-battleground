--!strict
-- BloodTracks: what people leave when they go through blood (client-side).
--
--   • FOOTPRINTS: stepping in a fresh pool wets the soles; the next steps
--     print them on the ground, left / right, heavy at first (a full wet
--     sole), then partial (heel, ball), then a trace - about 9 steps, then
--     nothing. They dry like the rest (BloodAge).
--   • SMEARS: a knocked-out / ragdolled body sliding over blood (or bleeding
--     while it slides) smears it along the way it goes.
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
local BloodPool = require(script.Parent.BloodPool)
local BloodStain = require(script.Parent.BloodStain)

local BloodTracks = {}

local PALETTE = Config.Blood.PALETTE
local RANGE = 80 -- studs from the camera
local STEPS = 9 -- prints after stepping in blood
local WALK_STRIDE = 2.2 -- studs between two prints (one foot)
local RUN_STRIDE = 3
local FEET = Config.Character.ROOT_TO_FEET

type Track = {
	load: number, -- 1 = soles full of blood, 0 = clean
	steps: number,
	walked: number,
	left: boolean,
	last: Vector3?,
	lastSmear: number,
}

local tracks: { [Model]: Track } = setmetatable({}, { __mode = "k" }) :: any

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function groundBelow(position: Vector3, depth: number): RaycastResult?
	return workspace:Raycast(position, Vector3.new(0, -depth, 0), BloodStain.ground())
end

-- One print of a foot (`left`), `level` 1 heavy, 2 partial, 3 trace.
local function footprint(
	root: BasePart,
	moving: Vector3,
	left: boolean,
	level: number,
	random: Random
)
	local side = root.CFrame.RightVector * (if left then -0.5 else 0.5)
	local hit = groundBelow(root.Position + side, FEET + 1.5)
	if hit == nil or hit.Normal.Y < 0.6 then
		return
	end
	local scale = if level == 1 then 1 elseif level == 2 then 0.92 else 0.8
	BloodStain.stain(
		if left then "footL" else "footR",
		hit.Position,
		hit.Normal,
		moving,
		0.42 * scale,
		0.95 * scale,
		{
			random = random,
			index = level,
			profile = "foot",
			category = "foot",
			start = PALETTE.VENOUS,
			alpha = if level == 1 then 0.05 elseif level == 2 then 0.3 else 0.55,
			upright = true,
			material = hit.Material,
			noEdge = true,
			priority = 2,
		}
	)
end

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
	local eye = camera.CFrame.Position
	local now = os.clock()
	for _, model in CollectionService:GetTagged(Config.Combat.TAG) do
		if not model:IsA("Model") then
			continue
		end
		local root = rootOf(model)
		if root == nil or (root.Position - eye).Magnitude > RANGE then
			continue
		end
		local track = tracks[model]
		if track == nil then
			track = { load = 0, steps = 0, walked = 0, left = false, last = nil, lastSmear = 0 }
			tracks[model] = track
		end
		local position = root.Position
		local down = model:GetAttribute("KnockedOut") == true
			or model:GetAttribute("Ragdolled") == true
		local velocity = root.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		if down then
			-- a body sliding over the ground: a smear behind it
			track.load = 0
			local torso = model:FindFirstChild("Torso")
			local body = if torso and torso:IsA("BasePart") then torso else root
			local speed =
				Vector3.new(body.AssemblyLinearVelocity.X, 0, body.AssemblyLinearVelocity.Z)
			if speed.Magnitude > 1.5 and now - track.lastSmear > 0.25 then
				local hit = groundBelow(body.Position, 3)
				if
					hit
					and (
						model:GetAttribute("Bleeding") == true
						or BloodPool.wetAt(hit.Position) > 0.3
					)
				then
					track.lastSmear = now
					Blood.smear(hit.Position, hit.Normal, speed, 0.7, nil)
				end
			end
		else
			local feet = position - Vector3.new(0, FEET, 0)
			if BloodPool.wetAt(feet) > 0.3 then
				-- (standing in it: the soles fill up again)
				track.load = 1
				track.steps = 0
			end
			local last = track.last
			if track.load > 0 and last then
				local moved = Vector3.new(position.X - last.X, 0, position.Z - last.Z)
				track.walked += moved.Magnitude
				local stride = if flat.Magnitude > 14 then RUN_STRIDE else WALK_STRIDE
				if track.walked >= stride and moved.Magnitude > 1e-3 then
					-- (one print a step, left and right in turn)
					track.walked = 0
					track.steps += 1
					track.left = not track.left
					local level = if track.steps <= 2 then 1 elseif track.steps <= 5 then 2 else 3
					local random =
						Random.new(Blood.seed(model.Name, track.steps, math.floor(position.X)))
					footprint(
						root,
						if flat.Magnitude > 0.5 then flat else moved,
						track.left,
						level,
						random
					)
					if track.steps >= STEPS then
						track.load = 0
					end
				end
			end
		end
		track.last = position
	end
end)

return table.freeze(BloodTracks)
