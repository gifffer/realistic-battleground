--!strict
-- Kits: equipping a kit from the Kits menu (Remotes.EquipKit). Saved in the
-- player's profile (equippedKit), so it follows them between servers.
--
-- The kit takes effect right away (Combat.setKit), except while awakened:
-- then it waits for the next life (no switching mid-Street Fury).
-- The kits themselves (moves, numbers) are in Shared/Kits; the moves run in
-- Server/Systems/Combat/Moves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KitDefs = require(ReplicatedStorage.Shared.Kits)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local Combat = require(script.Parent.Combat)
local PlayerData = require(script.Parent.PlayerData)

local Kits = {}

local limiter = RateLimiter.new(3, 1)

local function onEquipKit(player: Player, kitId: unknown)
	if typeof(kitId) ~= "string" or not limiter.allow(player) then
		return
	end
	-- Only real kits that are playable (not "coming soon" ones).
	local kit = KitDefs.get(kitId)
	local data = PlayerData.getData(player)
	if kit == nil or not kit.available or data == nil or not KitDefs.owns(data, kit) then
		return -- unknown, coming soon, or not bought yet
	end
	local saved = PlayerData.update(player, function(current)
		current.equippedKit = kitId
	end)
	if not saved then
		return
	end
	local character = player.Character
	if character and character:GetAttribute("Awakened") ~= true then
		Combat.setKit(character, kitId)
	end
end

function Kits.start()
	Remotes.EquipKit.OnServerEvent:Connect(onEquipKit)
end

return Kits
