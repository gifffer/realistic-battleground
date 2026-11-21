--!strict
-- Heat: SILENT counters of what each player does with contraband, for this server session.
-- Server only, never replicated, never saved, and NO effect on the game yet: a future police
-- system will read them (Heat.get). In Studio (Config.Contraband.DEBUG_LOG) they are printed
-- when the player leaves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

export type Counter =
	"extractions"
	| "sales"
	| "coins"
	| "pickupsOwn"
	| "pickupsOthers"
	| "drops"
	| "hitsWhileCarrying"
	| "carrySeconds"
	| "tripFlags"

export type Counters = { [Counter]: number }

local Heat = {}

local byPlayer: { [Player]: Counters } = {}

local function counters(player: Player): Counters
	local found = byPlayer[player]
	if found == nil then
		found = {
			extractions = 0,
			sales = 0,
			coins = 0,
			pickupsOwn = 0,
			pickupsOthers = 0,
			drops = 0,
			hitsWhileCarrying = 0,
			carrySeconds = 0,
			tripFlags = 0,
		}
		byPlayer[player] = found
	end
	return found :: Counters
end

-- Adds `amount` (default 1) to one counter of the player.
function Heat.record(player: Player, counter: Counter, amount: number?)
	if player.Parent == nil then
		return
	end
	local list = counters(player)
	list[counter] = (list[counter] or 0) + (amount or 1)
end

-- A copy of the player's counters (all 0 if nothing happened).
function Heat.get(player: Player): Counters
	return table.clone(counters(player))
end

-- The player left: print the counters (Studio debug) and forget them.
function Heat.forget(player: Player)
	local list = byPlayer[player]
	byPlayer[player] = nil
	if list and RunService:IsStudio() and Config.Contraband.DEBUG_LOG then
		local parts: { string } = {}
		for name, value in list do
			if value ~= 0 then
				table.insert(parts, `{name}={value}`)
			end
		end
		table.sort(parts)
		print(`[Contraband] heat of {player.Name}: {table.concat(parts, " ")}`)
	end
end

function Heat.init()
	-- (a safety net: Contraband/init calls Heat.forget itself on leave, with the print)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			byPlayer[player] = nil
		end)
	end)
end

return Heat
