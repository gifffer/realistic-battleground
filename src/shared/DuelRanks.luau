--!strict
-- Ranked duels: the rank shown for an ELO (Config.Duels.RANKS), shared by
-- the server and the UI.
--
--   DuelRanks.rankOf(1234) → "SILVER"

local Config = require(script.Parent.Config)

local DuelRanks = {}

function DuelRanks.rankOf(elo: number): string
	local name = Config.Duels.RANKS[1].name
	for _, rank in Config.Duels.RANKS do
		if elo >= rank.minElo then
			name = rank.name
		end
	end
	return name
end

return table.freeze(DuelRanks)
