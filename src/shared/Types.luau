--!strict
-- Shared type definitions. Types that cross the client/server boundary
-- (remote payloads, save format) live here so both sides agree.

export type PlayerStats = {
	kills: number,
	deaths: number,
	wins: number,
	matchesPlayed: number,
}

-- Player preferences (Settings window). Saved so they follow the player
-- from server to server.
export type PlayerSettings = {
	firstPerson: boolean, -- false = over-the-shoulder third person
}

-- A player's save. Everything here must be JSON-friendly (DataStores store
-- JSON): no Instances, no Vector3/CFrame, dictionaries use string keys only.
export type PlayerProfile = {
	version: number, -- save format version (see Server/Systems/PlayerData/Migrations)
	coins: number,
	stats: PlayerStats,
	settings: PlayerSettings,
}

-- What the server sends to the owning client.
export type ProfileSnapshot = PlayerProfile

-- How a character is moving right now. Decided by the server
-- (Server/Systems/Movement), published as the Player attribute "MoveState".
-- "Climb" = mantle onto a high ledge, "Vault" = quick hop over a low obstacle.
export type MoveState = "Walk" | "Sprint" | "Crouch" | "Slide" | "Climb" | "Vault"

-- Short movement moves the client can ask for (Remotes.RequestMoveAction).
-- "Cancel" = the current one is over on the client (jumped out of a slide,
-- or the climb finished before the server's maximum duration).
export type MoveAction = "Slide" | "Climb" | "Vault" | "Cancel"

-- What happened when an attack reached someone (Remotes.CombatEvent).
--   Hit        normal hit          Blocked     hit blocked (chip damage)
--   Finisher   4th hit, knockback  GuardBreak  block broken (no stamina)
--   Parried    perfect block       Dodged      hit during dash frames
export type CombatEventKind = "Hit" | "Finisher" | "Blocked" | "GuardBreak" | "Parried" | "Dodged"

return nil
