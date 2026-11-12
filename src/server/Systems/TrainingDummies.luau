--!strict
-- TrainingDummies: two R6 dummies near the spawn point, to test combat alone.
--
--   • "Dummy"           stands still. Heals to full after 3 s without damage.
--   • "Attacking Dummy" M1s any player standing close to it, non-stop.
--                       Perfect to practice blocking, parrying, dashing.
--
-- They die like players (and come back after 3 s). Turn them off with
-- Config.Combat.TRAINING_DUMMIES = false.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Combat = require(script.Parent.Combat)

local HEAL_AFTER = 3 -- seconds without damage before a dummy's health comes back
-- Its wounds (bruises, cuts, glass) start healing later, one at a time.
local WOUNDS_HEAL_AFTER = 13 -- seconds without damage
local WOUND_HEAL_STEP = 1.5 -- seconds between two (a bruise pales a level, then goes)
local RESPAWN_AFTER = 25 -- a dead dummy lies there this long (to look at what was done)
local ATTACK_RANGE = 7 -- studs
local THINK_INTERVAL = 0.1 -- the attacking dummy "thinks" 10 times per second

type DummyKind = "Passive" | "Attacking"

local TrainingDummies = {}

-- Where to put the dummies: in front of the SpawnLocation if there is one.
local function getBasePosition(): Vector3
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.Position + Vector3.new(0, 3, -16)
	end
	return Vector3.new(0, 5, -16)
end

local function createModel(name: string, color: Color3): Model
	-- A plain R6 body built by Roblox from an empty "avatar description".
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = color
	description.TorsoColor = color
	description.LeftArmColor = color
	description.RightArmColor = color
	description.LeftLegColor = color
	description.RightLegColor = color

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = name
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.MaxHealth = Config.Character.MAX_HEALTH
	humanoid.Health = Config.Character.MAX_HEALTH
	return model
end

-- Turns toward `target` (left/right only).
local function face(root: BasePart, target: Vector3)
	local flat = Vector3.new(target.X, root.Position.Y, target.Z)
	if (flat - root.Position).Magnitude > 1e-3 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

local function findClosestPlayer(position: Vector3): BasePart?
	local closest: BasePart? = nil
	local closestDistance = ATTACK_RANGE
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		-- A knocked-out player is left alone (training dummies never finish you).
		local down = character ~= nil and character:GetAttribute("KnockedOut") == true
		if humanoid and humanoid.Health > 0 and not down and root and root:IsA("BasePart") then
			local distance = (root.Position - position).Magnitude
			if distance < closestDistance then
				closest = root
				closestDistance = distance
			end
		end
	end
	return closest
end

local function spawnDummy(kind: DummyKind, position: Vector3)
	local isAttacker = kind == "Attacking"
	local model = createModel(
		if isAttacker then "Attacking Dummy" else "Dummy",
		if isAttacker then Color3.fromRGB(150, 60, 60) else Color3.fromRGB(120, 120, 120)
	)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart

	-- Face the spawn point (where players come from).
	model:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 16)))
	model.Parent = workspace
	root:SetNetworkOwner(nil) -- the server simulates dummies, not a player
	Combat.register(model)

	local lastDamagedAt = 0
	local previousHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < previousHealth then
			lastDamagedAt = os.clock()
		end
		previousHealth = health
	end)

	humanoid.Died:Connect(function()
		task.delay(RESPAWN_AFTER, function()
			model:Destroy()
			spawnDummy(kind, position)
		end)
	end)

	-- Brain: heal when left alone; the attacking one hits nearby players.
	local nextWoundHealAt = 0
	task.spawn(function()
		while model.Parent and humanoid.Health > 0 do
			-- Knocked out: lies there (no healing, no attacking) until it
			-- gets up or someone finishes it.
			local knockedOut = model:GetAttribute("KnockedOut") == true
			if not knockedOut and os.clock() - lastDamagedAt > HEAL_AFTER then
				if humanoid.Health < humanoid.MaxHealth then
					humanoid.Health = humanoid.MaxHealth
				end
			end
			local now = os.clock()
			if
				not knockedOut
				and now - lastDamagedAt > WOUNDS_HEAL_AFTER
				and now >= nextWoundHealAt
			then
				nextWoundHealAt = now + WOUND_HEAL_STEP
				Combat.healOneInjury(model)
			end
			if isAttacker and not knockedOut and model:GetAttribute("Stunned") ~= true then
				local target = findClosestPlayer(root.Position)
				if target then
					face(root, target.Position)
					Combat.tryAttack(model)
				end
			end
			task.wait(THINK_INTERVAL)
		end
	end)
end

function TrainingDummies.start()
	if not Config.Combat.TRAINING_DUMMIES then
		return
	end
	local base = getBasePosition()
	spawnDummy("Passive", base + Vector3.new(-6, 0, 0))
	spawnDummy("Attacking", base + Vector3.new(6, 0, 0))
end

return TrainingDummies
