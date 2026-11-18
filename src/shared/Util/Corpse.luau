--!strict
-- Corpse: a player killed by a finisher leaves their body on the floor for
-- Config.Knockout.FINISHER_BODY_TIME seconds after the killing blow, even
-- though they respawn sooner (Server/Systems/Corpses makes a frozen copy
-- of it, tagged Config.Combat.CORPSE_TAG, when Roblox removes the real one).
--
--   Corpse.ATTRIBUTE        on the victim's body (and its copy): the server
--                           time (workspace:GetServerTimeNow()) of the
--                           killing blow
--   Corpse.timeLeft(model)  seconds this body (or what fell off it: pieces
--                           of a burst head, a torn liver...) should still
--                           be seen; 0 for any other body

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Corpse = {}

Corpse.ATTRIBUTE = "FinisherBody"

function Corpse.timeLeft(model: Instance): number
	local killedAt = model:GetAttribute(Corpse.ATTRIBUTE)
	if typeof(killedAt) ~= "number" then
		return 0
	end
	local left = killedAt + Config.Knockout.FINISHER_BODY_TIME - workspace:GetServerTimeNow()
	return math.max(0, left)
end

return table.freeze(Corpse)
