--!strict
-- DeathSoundController: no Roblox "oof" when someone dies.
--
-- Roblox adds its own LocalScript to every player (RbxCharacterSounds, in
-- StarterPlayerScripts). It creates the default character sounds (footsteps, jump, landing...)
-- inside each character's HumanoidRootPart, ON THIS COMPUTER ONLY, and one of them is named
-- "Died": the cartoon "oof" played when the Humanoid dies. A realistic game has no oof: the
-- train kill, a finisher, a fall... have their own sounds (TrainCrash, TrainScream...).
--
-- What this does: for EVERY character on this screen (yours and the others'), as soon as a
-- Sound named "Died" appears in it (normally in its HumanoidRootPart), it is muted for good (no file, volume 0,
-- and stopped at once if something still plays it). The other default sounds (footsteps...)
-- are not touched. The sound is muted rather than deleted: the Roblox script keeps a reference
-- to it, and a muted sound is the safest thing to leave it.
--
-- Our own sounds are never named "Died" (they are named after their Shared/Sounds slot), so
-- the train's scream and crash still play.

local Players = game:GetService("Players")

local DeathSoundController = {}

local DEFAULT_DEATH_SOUND = "Died"

-- Mutes one default death sound (and keeps it muted).
local function mute(sound: Sound)
	sound.Volume = 0
	sound.SoundId = ""
	sound:Stop()
	sound.Played:Connect(function()
		sound:Stop()
	end)
	sound:GetPropertyChangedSignal("Volume"):Connect(function()
		if sound.Volume ~= 0 then
			sound.Volume = 0
		end
	end)
	sound:GetPropertyChangedSignal("SoundId"):Connect(function()
		if sound.SoundId ~= "" then
			sound.SoundId = ""
		end
	end)
end

local function onDescendant(descendant: Instance)
	if descendant.Name == DEFAULT_DEATH_SOUND and descendant:IsA("Sound") then
		mute(descendant)
	end
end

-- Watches the WHOLE character, not only its HumanoidRootPart: older versions of the Roblox
-- script put the sounds in the Head, and with streaming a part can leave and come back (its
-- sounds are then made again). Our own sounds are never named "Died", so nothing else is hit.
local function watchCharacter(character: Model)
	for _, descendant in character:GetDescendants() do
		onDescendant(descendant)
	end
	character.DescendantAdded:Connect(onDescendant)
end

local function watchPlayer(other: Player)
	if other.Character then
		watchCharacter(other.Character)
	end
	other.CharacterAdded:Connect(watchCharacter)
end

function DeathSoundController.start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
end

return DeathSoundController
