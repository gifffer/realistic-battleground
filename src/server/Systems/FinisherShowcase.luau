--!strict
-- TEMPORARY - for filming the cinematic finishers. Delete this file (and
-- Combat.finishFor, and the showcase bit of CinematicController) once the
-- videos are made.
--
-- In Studio only: two little stages near the spawn, each with a fighter
-- that knocks out a fresh opponent and finishes it, over and over:
--   • left:  a Street Brawler - the bat (the head bursts);
--   • right: a Boxer - the combo, the liver torn out.
-- In game, F6 toggles watching them with the cutscene camera (see
-- CinematicController); otherwise film them with your own camera.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Finishers = require(ReplicatedStorage.Shared.Finishers)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Combat = require(script.Parent.Combat)
local Knockout = require(script.Parent.Knockout)

local ENABLED = true -- (Studio only anyway)
local KO_TIME = 1.5 -- seconds lying knocked out before the finisher
local AFTER = 6 -- seconds left to look at the body once it's over
local BETWEEN = 1.5 -- seconds before the next opponent

local FinisherShowcase = {}

local function createModel(name: string, color: Color3): Model
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
	humanoid.MaxHealth = Config.Character.MAX_HEALTH
	humanoid.Health = Config.Character.MAX_HEALTH
	return model
end

local function place(model: Model, at: CFrame)
	model:PivotTo(at)
	model.Parent = workspace
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root:SetNetworkOwner(nil)
	end
	Combat.register(model)
end

-- One stage: `kitId`'s fighter at `at` (looking along it), forever.
local function stage(kitId: string, label: string, at: CFrame, color: Color3)
	local fighter = createModel(label, color)
	place(fighter, at)
	fighter:SetAttribute("Showcase", true) -- (CinematicController: F6 watches it)
	Combat.setKit(fighter, kitId)
	local cinematic = Finishers.get(Kits.finisher(kitId).cinematic)
	local duration = if cinematic then cinematic.duration else 4
	local humanoid = fighter:FindFirstChildOfClass("Humanoid") :: Humanoid

	while fighter.Parent and humanoid.Health > 0 do
		-- Back to its mark, a fresh opponent in front of it.
		fighter:PivotTo(at)
		local victim = createModel("Opponent", Color3.fromRGB(120, 120, 120))
		place(victim, at * CFrame.new(0, 0, -3) * CFrame.Angles(0, math.pi, 0))
		task.wait(0.6)
		Knockout.knockOut(victim, fighter)
		task.wait(KO_TIME)
		if not Combat.finishFor(fighter, victim) then
			warn(`[FinisherShowcase] {label}: the finisher didn't start`)
		end
		task.wait(duration + AFTER)
		victim:Destroy()
		task.wait(BETWEEN)
	end
end

function FinisherShowcase.start()
	if not (ENABLED and RunService:IsStudio()) then
		return
	end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = (if spawn then spawn.Position else Vector3.new(0, 2, 0)) + Vector3.new(0, 3, -34)
	-- (both look away from the spawn: you see them from the side/behind)
	task.spawn(
		stage,
		"StreetBrawler",
		"Street Brawler",
		CFrame.lookAt(base + Vector3.new(-14, 0, 0), base + Vector3.new(-14, 0, -10)),
		Color3.fromRGB(40, 40, 46)
	)
	task.spawn(
		stage,
		"Boxer",
		"Boxer",
		CFrame.lookAt(base + Vector3.new(14, 0, 0), base + Vector3.new(14, 0, -10)),
		Color3.fromRGB(150, 40, 40)
	)
end

return FinisherShowcase
