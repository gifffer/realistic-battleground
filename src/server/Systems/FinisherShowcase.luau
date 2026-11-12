--!strict
-- TEMPORARY - for filming the cinematic finishers. Delete this file (and
-- Combat.finishFor, Remotes.ShowcaseTrigger, ShowcasePanelController and
-- the showcase bit of CinematicController) once the
-- videos are made.
--
-- In Studio only: two little stages near the spawn, each with a fighter
-- waiting; YOU trigger them from a small panel you can drag around
-- (ShowcasePanelController): the Street Brawler (left: the bat, the head
-- bursts), the Boxer (right: the combo, the liver torn out). A fresh
-- opponent appears, is knocked out and finished; the cutscene camera
-- watches it (the panel turns it on / off).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Finishers = require(ReplicatedStorage.Shared.Finishers)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Combat = require(script.Parent.Combat)
local Knockout = require(script.Parent.Knockout)

local ENABLED = true -- (Studio only anyway)
local KO_TIME = 1.5 -- seconds lying knocked out before the finisher
local AFTER = 6 -- seconds left to look at the body once it's over

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

type Stage = { fighter: Model, at: CFrame, duration: number, busy: boolean }
local stages: { [string]: Stage } = {}

-- A stage: `kitId`'s fighter standing at `at` (looking along it), waiting.
local function stage(kitId: string, label: string, at: CFrame, color: Color3)
	local fighter = createModel(label, color)
	place(fighter, at)
	fighter:SetAttribute("Showcase", true) -- (CinematicController: watched)
	Combat.setKit(fighter, kitId)
	local cinematic = Finishers.get(Kits.finisher(kitId).cinematic)
	stages[label] = {
		fighter = fighter,
		at = at,
		duration = if cinematic then cinematic.duration else 4,
		busy = false,
	}
end

-- Plays one finisher on `label`'s stage: a fresh opponent in front of the
-- fighter, knocked out, finished; the body left a while, then cleared.
local function play(label: string)
	local current = stages[label]
	if current == nil or current.busy or current.fighter.Parent == nil then
		return
	end
	current.busy = true
	local fighter = current.fighter
	fighter:PivotTo(current.at) -- (back to its mark)
	local victim = createModel("Opponent", Color3.fromRGB(120, 120, 120))
	place(victim, current.at * CFrame.new(0, 0, -3) * CFrame.Angles(0, math.pi, 0))
	task.wait(0.4)
	Knockout.knockOut(victim, fighter)
	task.wait(KO_TIME)
	if not Combat.finishFor(fighter, victim) then
		warn(`[FinisherShowcase] {label}: the finisher didn't start`)
	end
	task.wait(current.duration + 0.5)
	current.busy = false -- (another one can start; this body stays a while)
	task.delay(AFTER, function()
		victim:Destroy()
	end)
end

function FinisherShowcase.start()
	if not (ENABLED and RunService:IsStudio()) then
		return
	end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = (if spawn then spawn.Position else Vector3.new(0, 2, 0)) + Vector3.new(0, 3, -34)
	-- (both look away from the spawn: you see them from the side/behind)
	stage(
		"StreetBrawler",
		"Street Brawler",
		CFrame.lookAt(base + Vector3.new(-14, 0, 0), base + Vector3.new(-14, 0, -10)),
		Color3.fromRGB(40, 40, 46)
	)
	stage(
		"Boxer",
		"Boxer",
		CFrame.lookAt(base + Vector3.new(14, 0, 0), base + Vector3.new(14, 0, -10)),
		Color3.fromRGB(150, 40, 40)
	)
	-- You trigger them (the showcase panel, ShowcasePanelController).
	Remotes.ShowcaseTrigger.OnServerEvent:Connect(function(_player: Player, label: unknown)
		if typeof(label) == "string" then
			task.spawn(play, label)
		end
	end)
end

return FinisherShowcase
