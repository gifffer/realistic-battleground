--!strict
-- Characters: prepares every character when it spawns.
--
--   • Sets health from Config (no passive regeneration: the default Roblox
--     "Health" script is replaced by an empty one, see src/character/Health.server.luau).
--   • Checks the avatar is R6. The game is built for R6 (6 body parts:
--     simpler animations, ragdoll and hit zones). R6 is NOT forced by code:
--     it is a setting of the place (see docs/SETUP_FR.md, "Avatar R6").
--     If it's wrong, we print a clear warning instead of failing silently.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Characters = {}

local warnedAboutRig = false

local function onCharacterAdded(character: Model)
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
