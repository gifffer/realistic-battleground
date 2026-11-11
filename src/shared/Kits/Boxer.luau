--!strict
-- BOXER: not playable yet. Listed in the Kits menu as "coming soon" so the
-- menu already shows where the game is going. Its moves come in a later step.

local KitTypes = require(script.Parent.KitTypes)

local kit: KitTypes.KitDef = {
	id = "Boxer",
	name = "BOXER",
	description = "Footwork, a tight guard and fast hands.",
	order = 2,
	available = false,
	moves = {},
	awakening = nil,
}

return kit
