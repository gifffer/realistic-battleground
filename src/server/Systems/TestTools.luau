--!strict
-- TestTools: things to look at from OUTSIDE when testing alone in Studio.
--
--   • "Limping Dummy" walks back and forth near the spawn, limping
--     ("Limping" attribute; "LimpLeg" switches Left / Right every lap).
--   • Finisher stage: one button (ProximityPrompt) per kit. Press it: an
--     attacker dummy with that kit knocks out a victim dummy and finishes
--     it with the kit's finisher (the real server path, Combat.devFinish).
--     You keep your own camera: only the two fighters get the cutscene.
--     The bodies stay a few seconds, then a fresh pair stands there.
--
-- Only in Roblox Studio (never in the published game), and only if
-- Config.Dev.TEST_TOOLS is true. Built by code, nothing saved in the place.
--
-- Layout (seen from above, the spawn in the middle, the parkour course on
-- its right): the limping dummy's lane in front-left, the finisher stage
-- behind-left with its buttons on the spawn side.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Finishers = require(ReplicatedStorage.Shared.Finishers)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Combat = require(script.Parent.Combat)
local Knockout = require(script.Parent.Knockout)
local TrainingDummies = require(script.Parent.TrainingDummies)

-- Limping dummy: its lane (from the spawn, studs) and its pace.
local LIMP_FROM = Vector3.new(-12, 0, -24)
local LIMP_TO = Vector3.new(-36, 0, -24)
local LIMP_PAUSE = 1.2 -- seconds standing (on its good leg) at each end
local LIMP_WALK_TIMEOUT = 10 -- seconds: stuck, turn around anyway
local HEAL_AFTER = 3 -- seconds without damage: back to full health
local WOUNDS_HEAL_AFTER = 13 -- seconds without damage: cuts and bruises go
local WOUND_HEAL_STEP = 1.5 -- seconds between two (as TrainingDummies)
local RESPAWN_AFTER = 8 -- seconds a dead test dummy lies there

-- Finisher stage (from the spawn, studs): the victim lies in the middle,
-- the attacker comes from its left, the buttons face the stage.
local STAGE_CENTER = Vector3.new(-36, 0, 8)
local BUTTONS_FROM_STAGE = 15 -- studs toward the spawn side (+Z)
local BUTTON_SPACING = 5
local ATTACKER_GAP = 3.2 -- studs between the attacker and the body
local SETTLE_TIME = 1.5 -- seconds for the knocked-out body to fall
local BODY_TIME = 8 -- seconds the bodies stay after the finisher
local IDLE_RESPAWN_AFTER = 4 -- seconds a dead idle stage dummy lies there

local VICTIM_COLOR = Color3.fromRGB(120, 120, 120)
local ATTACKER_COLOR = Color3.fromRGB(70, 90, 140)
local LIMP_COLOR = Color3.fromRGB(150, 120, 70)

local TestTools = {}

local spawnPosition = Vector3.zero

-- The floor under a point (spawn-relative offset), `height` above it.
-- (bodies don't count: only the map)
local function groundAt(offset: Vector3, height: number): Vector3
	local point = spawnPosition + offset
	local ignore: { Instance } = CollectionService:GetTagged(Config.Combat.TAG)
	for _, body in CollectionService:GetTagged(Config.Combat.CORPSE_TAG) do
		table.insert(ignore, body)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(point + Vector3.new(0, 200, 0), Vector3.new(0, -1000, 0), params)
	local y = if hit then hit.Position.Y else spawnPosition.Y
	return Vector3.new(point.X, y + height, point.Z)
end

-- A dummy that fights (animated on every client, can be hit, KO'd...),
-- standing at `at` facing `toward`.
local function spawnFighter(name: string, color: Color3, at: Vector3, toward: Vector3): Model
	local model = TrainingDummies.createModel(name, color)
	model:PivotTo(CFrame.lookAt(at, Vector3.new(toward.X, at.Y, toward.Z)))
	model.Parent = workspace
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root:SetNetworkOwner(nil) -- the server moves it, not a player
	Combat.register(model)
	return model
end

-- Back to full health after HEAL_AFTER seconds without damage, then its
-- cuts and bruises go one by one, like the training dummies (not while
-- knocked out: it gets up or gets finished).
local function healWhenLeftAlone(model: Model, humanoid: Humanoid)
	local lastDamagedAt = 0
	local previous = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < previous then
			lastDamagedAt = os.clock()
		end
		previous = health
	end)
	local nextWoundHealAt = 0
	task.spawn(function()
		while model.Parent and humanoid.Health > 0 do
			if not Knockout.isKnockedOut(model) then
				local now = os.clock()
				if now - lastDamagedAt > HEAL_AFTER and humanoid.Health < humanoid.MaxHealth then
					humanoid.Health = humanoid.MaxHealth
				end
				if now - lastDamagedAt > WOUNDS_HEAL_AFTER and now >= nextWoundHealAt then
					nextWoundHealAt = now + WOUND_HEAL_STEP
					Combat.healOneInjury(model)
				end
			end
			task.wait(0.5)
		end
	end)
end

------------------------------------------------------------------------------
-- Limping dummy
------------------------------------------------------------------------------

-- Can't walk right now (knocked out, stunned, held).
local function cannotWalk(model: Model): boolean
	return Knockout.isKnockedOut(model)
		or model:GetAttribute("Stunned") == true
		or model:GetAttribute("InCinematic") == true
end

-- Walks to `point`; false if it didn't get there in time, or got hit on the
-- way (then it stops where it is, like a stunned player).
local function walkTo(model: Model, humanoid: Humanoid, root: BasePart, point: Vector3): boolean
	local done = false
	local reached = false
	local connection = humanoid.MoveToFinished:Connect(function(success)
		done = true
		reached = success
	end)
	humanoid:MoveTo(point)
	local deadline = os.clock() + LIMP_WALK_TIMEOUT
	while not done and os.clock() < deadline and model.Parent do
		if cannotWalk(model) then
			humanoid:MoveTo(root.Position)
			break
		end
		task.wait(0.1)
	end
	connection:Disconnect()
	return reached
end

local function spawnLimper()
	local a = groundAt(LIMP_FROM, 3)
	local b = groundAt(LIMP_TO, 3)
	local model = spawnFighter("Limping Dummy", LIMP_COLOR, a, b)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	-- (the pace of a limping player: Movement, Config.Injuries.LIMP_SPEED)
	humanoid.WalkSpeed = Config.Character.WALK_SPEED * Config.Injuries.LIMP_SPEED
	healWhenLeftAlone(model, humanoid)

	humanoid.Died:Connect(function()
		task.delay(RESPAWN_AFTER, function()
			model:Destroy()
			spawnLimper()
		end)
	end)

	task.spawn(function()
		local leg = "Left"
		local goal = b
		while model.Parent and humanoid.Health > 0 do
			-- Knocked out, stunned, held: wait until it can walk again.
			if cannotWalk(model) then
				task.wait(0.25)
				continue
			end
			-- (set again each lap: healing its injuries clears them)
			model:SetAttribute("Limping", true)
			model:SetAttribute("LimpLeg", leg)
			if not walkTo(model, humanoid, root, goal) and cannotWalk(model) then
				continue -- (hit on the way: same goal once it can walk)
			end
			task.wait(LIMP_PAUSE)
			goal = if goal == b then a else b
			leg = if leg == "Left" then "Right" else "Left"
		end
	end)
end

------------------------------------------------------------------------------
-- Finisher stage
------------------------------------------------------------------------------

local prompts: { ProximityPrompt } = {}
local stageModels: { Model } = {}
local busy = false
local stageGeneration = 0 -- +1 each time the stage is cleared

local function clearStage()
	stageGeneration += 1
	for _, model in stageModels do
		if model.Parent then
			model:Destroy()
		end
	end
	table.clear(stageModels)
end

-- A fresh pair standing on the stage (registered fighters: animated, can
-- be hit). `kit` = the attacker's kit, nil = the default one.
local function spawnPair(kit: Kits.KitDef?): (Model, Model)
	local victimAt = groundAt(STAGE_CENTER, 3)
	local attackerAt = groundAt(STAGE_CENTER - Vector3.new(ATTACKER_GAP + 1, 0, 0), 3)
	local victim = spawnFighter("Finisher Victim", VICTIM_COLOR, victimAt, attackerAt)
	local name = if kit then `{kit.name} Dummy` else "Finisher Dummy"
	local attacker = spawnFighter(name, ATTACKER_COLOR, attackerAt, victimAt)
	if kit then
		Combat.setKit(attacker, kit.id)
	end
	table.insert(stageModels, victim)
	table.insert(stageModels, attacker)
	local generation = stageGeneration
	for _, model in { victim, attacker } do
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		healWhenLeftAlone(model, humanoid)
		-- The idle pair killed by a player: a fresh pair a bit later (a demo
		-- clears and respawns the stage itself).
		if kit == nil then
			humanoid.Died:Connect(function()
				task.delay(IDLE_RESPAWN_AFTER, function()
					if busy or stageGeneration ~= generation then
						return
					end
					clearStage()
					spawnPair(nil)
				end)
			end)
		end
	end
	return attacker, victim
end

local function setPromptsEnabled(enabled: boolean)
	for _, prompt in prompts do
		prompt.Enabled = enabled
	end
end

-- One demo: KO, then the kit's finisher through the real server path.
local function perform(kit: Kits.KitDef)
	local attacker, victim = spawnPair(kit)
	task.wait(0.5) -- (every client picks the two dummies up first)
	Knockout.knockOut(victim, attacker)
	task.wait(SETTLE_TIME)
	local torso = victim:FindFirstChild("Torso")
	if
		attacker.Parent == nil
		or not Knockout.isKnockedOut(victim)
		or not (torso and torso:IsA("BasePart"))
	then
		warn(`[TestTools] {kit.id}: the victim is not knocked out, demo stopped`)
		return
	end
	-- Stand by the body (on its left as seen from the buttons), facing it.
	local body = torso.Position
	local at = groundAt(body - spawnPosition - Vector3.new(ATTACKER_GAP, 0, 0), 3)
	attacker:PivotTo(CFrame.lookAt(at, Vector3.new(body.X, at.Y, body.Z)))
	task.wait(0.1)
	if not Combat.devFinish(attacker, victim, kit.id) then
		warn(`[TestTools] {kit.id}: the finisher did not start`)
		return
	end
	local finisher = Kits.finisher(kit.id)
	local cinematic = Finishers.get(finisher.cinematic)
	task.wait((if cinematic then cinematic.duration else finisher.duration) + BODY_TIME)
end

local function runDemo(kit: Kits.KitDef)
	if busy then
		return
	end
	busy = true
	setPromptsEnabled(false)
	clearStage()
	local ok, problem = pcall(function()
		perform(kit)
	end)
	if not ok then
		warn(`[TestTools] {kit.id}: {problem}`)
	end
	clearStage()
	spawnPair(nil)
	setPromptsEnabled(true)
	busy = false
end

-- A text floating over a part.
local function label(parent: BasePart, text: string, height: number, size: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, size + 8)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextSize = size
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0.4
	textLabel.Text = text
	textLabel.Parent = gui
	gui.Parent = parent
end

-- A flat marker on the floor: nothing touches it, raycasts go through.
local function floorMarker(parent: Instance, name: string, center: Vector3, size: Vector2): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = Vector3.new(size.X, 0.1, size.Y)
	part.Position = center + Vector3.new(0, 0.06, 0)
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(45, 45, 52)
	part.Transparency = 0.35
	part.Parent = parent
	return part
end

local function buildStage(parent: Folder)
	-- Every kit that has a finisher (its cinematic, if it has one).
	local kits: { Kits.KitDef } = {}
	for _, kit in Kits.list() do
		if kit.finisher then
			table.insert(kits, kit)
		end
	end

	local center = groundAt(STAGE_CENTER, 0)
	local stage = floorMarker(parent, "FinisherStage", center, Vector2.new(30, 16))
	label(stage, "FINISHER DEMO (Studio only)", 9, 22)

	for index, kit in kits do
		local x = (index - (#kits + 1) / 2) * BUTTON_SPACING
		local base = groundAt(STAGE_CENTER + Vector3.new(x, 0, BUTTONS_FROM_STAGE), 0)
		local button = Instance.new("Part")
		button.Name = `Finisher_{kit.id}`
		button.Anchored = true
		button.Size = Vector3.new(1.6, 3, 1.6)
		button.Position = base + Vector3.new(0, 1.5, 0)
		button.Material = Enum.Material.Neon
		button.Color = Color3.fromRGB(200, 70, 60)
		button.Parent = parent

		local cinematic = Finishers.get((kit.finisher :: Kits.FinisherDef).cinematic)
		local finisherName = if cinematic then cinematic.id else "plain finisher"
		label(button, `{kit.name}\n{finisherName}`, 3.2, 16)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Watch finisher"
		prompt.ObjectText = `{kit.name}: {finisherName}`
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = button
		prompt.Triggered:Connect(function()
			task.spawn(runDemo, kit)
		end)
		table.insert(prompts, prompt)
	end
end

function TestTools.start()
	if not RunService:IsStudio() or not Config.Dev.TEST_TOOLS then
		return
	end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	spawnPosition = if spawn then spawn.Position else Vector3.zero

	local parent = Instance.new("Folder")
	parent.Name = "DevTestTools"
	buildStage(parent)
	-- (parent last: everything appears at once)
	parent.Parent = workspace

	spawnLimper()
	spawnPair(nil)
	print("[TestTools] Limping dummy and finisher stage built (Studio only).")
end

return TestTools
