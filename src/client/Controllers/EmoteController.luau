--!strict
-- EmoteController: the emote key (B, Config.Controls.EMOTE). Plays the
-- emote equipped in the SHOP. The server checks you can (not mid-fight,
-- you own it) and tells everyone to play it (Remotes.CombatAction), so
-- there's nothing to predict here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local EmoteController = {}

function EmoteController.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Config.Controls.EMOTE then
			Remotes.Emote:FireServer()
		end
	end)
end

return EmoteController
