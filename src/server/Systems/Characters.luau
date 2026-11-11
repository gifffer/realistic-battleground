--!strict
-- Characters: prepares every character when it spawns.
--
--   • Sets health from Config.
--   • Turns OFF passive regeneration (game design: a kill heals, time doesn't).
--     Roblox puts a script named "Health" in every character that heals 1 %
--     of max health per second; we delete it as soon as the character spawns.
--   • Checks the avatar is R6. The game is built for R6 (6 body parts:
--     simpler animations, ragdoll and hit zones). R6 is NOT forced by code:
--     it is a setting of the place (see docs/SETUP_FR.md, "Avatar R6").
--     If it's wrong, we print a clear warning instead of failing silently.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Characters = {}

local warnedAboutRig = false

-- Deletes Roblox's regeneration script, now or if it shows up a bit later.
local function removeRegeneration(character: Model)
	local function check(child: Instance)
		if child.Name == "Health" and child:IsA("Script") then
			child:Destroy()
		end
	end
	for _, child in character:GetChildren() do
		check(child)
	end
	-- The connection dies with the character (Destroy on respawn), no leak.
	character.ChildAdded:Connect(check)
end

local function onCharacterAdded(character: Model)
	removeRegeneration(character)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end

	if humanoid.RigType ~= Enum.HumanoidRigType.R6 and not warnedAboutRig then
		warnedAboutRig = true
		warn(
			"[Characters] Avatars are not R6. Set Avatar Type to R6 in Studio "
				.. "(see docs/SETUP_FR.md, 'Avatar R6'), then publish the place."
		)
	end

	humanoid.MaxHealth = Config.Character.MAX_HEALTH
	humanoid.Health = Config.Character.MAX_HEALTH
	humanoid.WalkSpeed = Config.Character.WALK_SPEED
end

local function onPlayerAdded(player: Player)
	-- Roblox's built-in "Shift lock" uses Shift, which is our sprint key.
	-- Our CameraController already locks the mouse, so turn Roblox's one off.
	-- (Also set in default.project.json; done here too in case it isn't synced.)
	player.DevEnableMouseLock = false

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

function Characters.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this script ran (happens in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return Characters
