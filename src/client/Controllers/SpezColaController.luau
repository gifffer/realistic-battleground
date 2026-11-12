--!strict
-- SpezColaController: the SOUNDS of the SpezCola machines, on this screen
-- (the machines and the cans themselves are handled by Server/Systems/SpezCola).
--
--   • every machine HUMS: a quiet loop (Shared/Sounds "SpezColaHum") in 3D on its "Hum" part,
--     heard only when you're close (short roll-off, like a real fridge);
--   • a can dropping out of the tray: "SpezColaDrop", in 3D where the can appears (each new
--     can the server puts into Workspace > SpezColaCans).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Sounds)
local SoundController = require(script.Parent.SoundController)

local SpezColaController = {}

local MACHINE_TAG = "SpezColaMachine"
local FOLDER_NAME = "SpezColaCans"
-- The hum: full volume within HUM_NEAR studs, silent beyond HUM_FAR.
local HUM_NEAR = 3
local HUM_FAR = 26
-- The can falling: heard up to this far.
local DROP_RANGE = 45

local humming: { [Model]: Sound } = {}

local function startHum(instance: Instance)
	if not instance:IsA("Model") or humming[instance] then
		return
	end
	local model = instance :: Model
	local info = Sounds.SpezColaHum
	if info == nil or #info.ids == 0 then
		return
	end
	local hum = model:WaitForChild("Hum", 15)
	if hum == nil or not hum:IsA("BasePart") or humming[model] then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "SpezColaHum"
	sound.SoundId = `rbxassetid://{info.ids[1]}`
	sound.Volume = info.volume
	sound.PlaybackSpeed = info.pitch
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = HUM_NEAR
	sound.RollOffMaxDistance = HUM_FAR
	-- (each machine starts at a different point of the loop: three machines never hum in sync)
	sound.TimePosition = math.random() * 2
	sound.Parent = hum
	sound:Play()
	humming[model] = sound
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			humming[model] = nil
		end
	end)
end

local function onCanAdded(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local body = instance:WaitForChild("Body", 5)
	if body and body:IsA("BasePart") then
		SoundController.playAt("SpezColaDrop", body.Position, DROP_RANGE)
	end
end

function SpezColaController.start()
	CollectionService:GetInstanceAddedSignal(MACHINE_TAG):Connect(function(instance)
		task.spawn(startHum, instance)
	end)
	for _, instance in CollectionService:GetTagged(MACHINE_TAG) do
		task.spawn(startHum, instance)
	end

	local folder = workspace:WaitForChild(FOLDER_NAME, 60)
	if folder == nil then
		return
	end
	-- (cans already there when we join fell long ago: no sound for them)
	folder.ChildAdded:Connect(function(child)
		task.spawn(onCanAdded, child)
	end)
end

return SpezColaController
