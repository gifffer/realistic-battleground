--!strict
-- Shared type definitions. Types that cross the client/server boundary
-- (remote payloads, save format) live here so both sides agree.

export type PlayerStats = {
	kills: number,
	deaths: number,
	wins: number,
	matchesPlayed: number,
}

-- A player's save. Everything here must be JSON-friendly (DataStores store
-- JSON): no Instances, no Vector3/CFrame, dictionaries use string keys only.
export type PlayerProfile = {
	version: number, -- save format version (see Server/Systems/PlayerData/Migrations)
	coins: number,
	stats: PlayerStats,
}

-- What the server sends to the owning client.
export type ProfileSnapshot = PlayerProfile

return nil
