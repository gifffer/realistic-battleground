--!strict
-- AutopsyController: the gate of the autopsy VIDEO mini-game (18+, made to
-- record a video, to be removed later). Nothing of it runs unless we are in
-- Roblox Studio AND Config.Dev.AUTOPSY_VIDEO is true: a live server never
-- even requires the Autopsy code.
--
-- To remove the mini-game: delete this file, the Client/Autopsy folder, the
-- AUTOPSY_VIDEO line in Shared/Config and docs/AUTOPSY_FR.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local AutopsyController = {}

function AutopsyController.start()
	if not RunService:IsStudio() or not Config.Dev.AUTOPSY_VIDEO then
		return
	end
	local Autopsy = require(script.Parent.Parent.Autopsy) :: any
	Autopsy.start()
end

return AutopsyController
