--!strict
-- What a brand-new player's save looks like.
--
-- ProfileStore copies this table for new players, and Profile:Reconcile()
-- adds any field missing from older saves. So: to add a new saved value,
-- add it here (and in Shared/Types.luau). To change the shape of an existing
-- value, write a migration (Migrations.luau).
--
-- Never modify this table from gameplay code — it is shared by everyone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Migrations = require(script.Parent.Migrations)

local template: Types.PlayerProfile = {
	version = Migrations.CURRENT_VERSION,
	coins = 0,
	stats = {
		kills = 0,
		deaths = 0,
		wins = 0,
		matchesPlayed = 0,
	},
	-- Added in v0.0.2: no migration needed, Reconcile() adds it to older saves.
	settings = {
		firstPerson = false,
		blockDuels = false,
	},
	-- Added with the kits (step 4): Reconcile() adds it to older saves.
	equippedKit = "StreetBrawler",
	-- Added with the progression (step 7).
	xp = 0,
	ownedKits = {},
	-- Added with the duels (step 8).
	elo = 1000,
	rankedWins = 0,
	rankedLosses = 0,
	-- Added with the daily quests (step 9).
	quests = { day = 0, list = {} },
	-- Added with the shop (step 10).
	ownedCosmetics = {},
	equipped = { Title = "", Outfit = "", KillEffect = "", Emote = "EmoteShrug" },
}

return template
