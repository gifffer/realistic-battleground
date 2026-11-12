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

-- Where `elo` sits on the ladder (menu, profile and result draw the same):
--   rank / index           the current rank and its position (1 = BRONZE)
--   minElo                 where it starts
--   nextRank / nextMinElo  the next one (nil at the top)
--   fraction               0 → 1 between this rank and the next (1 at the top)
export type Progress = {
	rank: string,
	index: number,
	minElo: number,
	nextRank: string?,
	nextMinElo: number?,
	fraction: number,
}

function DuelRanks.progress(elo: number): Progress
	local ranks = Config.Duels.RANKS
	local index = 1
	for position, rank in ranks do
		if elo >= rank.minElo then
			index = position
		end
	end
	local current = ranks[index]
	local nextOne = ranks[index + 1]
	return {
		rank = current.name,
		index = index,
		minElo = current.minElo,
		nextRank = if nextOne then nextOne.name else nil,
		nextMinElo = if nextOne then nextOne.minElo else nil,
		fraction = if nextOne
			then math.clamp((elo - current.minElo) / (nextOne.minElo - current.minElo), 0, 1)
			else 1,
	}
end

return table.freeze(DuelRanks)
