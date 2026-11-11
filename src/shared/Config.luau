--!strict
-- Tunable values of the game. NOTE: replicated to clients — nothing secret here,
-- and the server never trusts a value reported by a client.

return table.freeze({
	GAME_TITLE = "Realistic Battleground",
	VERSION = "v0.0.1 PRE-ALPHA",

	-- Seconds between two background saves of a player's profile.
	AUTOSAVE_INTERVAL = 60,
})
