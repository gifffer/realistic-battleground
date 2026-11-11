--!strict
-- SoundController: plays the sound effects listed in Shared/Sounds.luau.
--
--   SoundController.play("Hit", someModel)
--
-- Sounds are played in 3D on the model's HumanoidRootPart. A sound whose id
-- is still 0 is silently skipped (the game works before sounds are chosen).
--
-- Movement sounds (slide, vault, mantle) are started here, for every player,
-- from the "MoveState" attribute the server sets. Combat sounds are started
-- by CombatController (yours, instantly) and CombatEffectsController
-- (everyone else, from the server's messages).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

-- Beyond this distance (studs) a sound can't be heard at all.
local MAX_HEARING_DISTANCE = 90
-- Movement state → sound played when a player enters it.
local MOVE_STATE_SOUNDS: { [string]: string } = {
	Slide = "Slide",
	Vault = "Vault",
	Climb = "Mantle",
}

local SoundController = {}

local random = Random.new()

function SoundController.play(name: string, model: Model?)
	local info = Sounds[name]
	if info == nil then
		warn(`[SoundController] unknown sound "{name}" (see Shared/Sounds.luau)`)
		return
	end
	if info.id == 0 or model == nil then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = `rbxassetid://{info.id}`
	sound.Volume = info.volume
	sound.PlaybackSpeed = 1 + random:NextNumber(-info.pitchVariation, info.pitchVariation)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = MAX_HEARING_DISTANCE
	sound.Parent = root
	sound:Play()
	-- Removed after it finished (TimeLength is 0 until the file is loaded,
	-- hence the safe minimum).
	Debris:AddItem(sound, math.max(sound.TimeLength / sound.PlaybackSpeed, 3) + 0.5)
end

local function watchPlayer(owner: Player)
	owner:GetAttributeChangedSignal("MoveState"):Connect(function()
		local state = owner:GetAttribute("MoveState")
		local soundName = if typeof(state) == "string" then MOVE_STATE_SOUNDS[state] else nil
		if soundName then
			SoundController.play(soundName, owner.Character)
		end
	end)
end

function SoundController.start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, owner in Players:GetPlayers() do
		watchPlayer(owner)
	end
end

return SoundController
