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
	blockDuels: boolean, -- true = nobody can challenge you to a duel
	music: boolean, -- false = no music (the city's outdoor music and the places' speakers)
}

-- A player's save. Everything here must be JSON-friendly (DataStores store
-- JSON): no Instances, no Vector3/CFrame, dictionaries use string keys only.
export type PlayerProfile = {
	version: number, -- save format version (see Server/Systems/PlayerData/Migrations)
	coins: number,
	stats: PlayerStats,
	settings: PlayerSettings,
	equippedKit: string, -- id of the kit used in fights (Shared/Kits)
	xp: number, -- total XP ever earned (the level comes from it: Shared/Progression)
	ownedKits: { [string]: boolean }, -- kits bought (free kits don't need to be here)
	-- Ranked duels (step 8).
	elo: number,
	rankedWins: number,
	rankedLosses: number,
	-- Daily quests (step 9): today's 3 quests and their progress.
	quests: DailyQuests,
	-- Shop (step 10): cosmetics bought, and the one equipped per category
	-- (Shared/Cosmetics ids; "" = none).
	ownedCosmetics: { [string]: boolean },
	equipped: { Title: string, Outfit: string, KillEffect: string, Emote: string },
	-- Contraband prototype: the lab culture, the bio-cores in the stash, the case.
	contraband: ContrabandProfile,
}

export type QuestState = {
	id: string, -- Shared/Quests id
	goal: number,
	progress: number,
	done: boolean, -- reward already given
}

export type DailyQuests = {
	day: number, -- Quests.today() they were drawn on (0 = never)
	list: { QuestState },
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
--   Protected  the victim has spawn protection (nothing happens)
export type CombatEventKind =
	"Hit"
	| "Finisher"
	| "Blocked"
	| "GuardBreak"
	| "Parried"
	| "Dodged"
	| "Protected"

-- Where a hit lands (Config.Combat.ZONE_DAMAGE).
export type HitZone = "Head" | "Torso" | "Legs"

-- Which side of the victim the attacker stands on when the hit lands
-- (Shared/Util/HitSide). Picks the hit reaction: a punch on the left
-- cheek doesn't throw the head the same way as one on the right.
export type HitSide = "Front" | "Back" | "Left" | "Right"

-- Why a player earned XP / coins (Remotes.Progress, shown in the HUD).
export type RewardKind =
	"Kill"
	| "Assist"
	| "Damage"
	| "Playtime"
	| "DuelWin"
	| "DuelLoss"
	| "RankedWin"
	| "RankedLoss"
	| "Quest"

-- Duel messages from the server to one player (Remotes.DuelEvent).
--   Challenged   someone challenges you      { from: number (UserId), name, expiresAt }
--   Declined     your challenge was refused / expired   { userId, name, reason }
--   Queue        ranked search state         { searching: boolean, since: number? }
--   Waiting      all arenas busy, you're in line        { opponent, ranked }
--   Start        the match begins            { opponent: number, ranked: boolean }
--   Round        a round is about to start   { round, score: {mine, theirs}, fightAt }
--   RoundEnd     a round is over             { round, won: boolean, score, last }
--   End          the match is over           { won, ranked, score, xp, coins, eloBefore?, eloAfter?, forfeit, returnAt }
export type DuelEventKind =
	"Challenged"
	| "Declined"
	| "Queue"
	| "Waiting"
	| "Start"
	| "Round"
	| "RoundEnd"
	| "End"

-- A line of the kill feed (Remotes.KillFeed).
--   Finished  killer finished a KO'd victim
--   Fled      victim left the game in the middle of a fight (killer gets the kill)
--   Died      no killer (fell off the map...)
--   Train     hit by the city's train (Knockout.killByEnvironment)
export type KillFeedKind = "Finished" | "Fled" | "Died" | "Train"

-- The extra facts sent with a kill feed line (6th argument). Every field can
-- be missing (a dummy has no user id, a death with no killer has no kit).
--   finisher   name of the finisher that killed ("LIVER RIP"), Finished only
--   killerKit  the killer's kit id ("Boxer"), for the death screen
--   victimId / killerId   UserIds (names can repeat: ids say who is who)
export type KillFeedDetails = {
	finisher: string?,
	killerKit: string?,
	victimId: number?,
	killerId: number?,
}

-- ===================== Contraband prototype =====================
-- (Server/Systems/Contraband). Labs, clones, bio-cores, the courier case.

-- How good an extracted bio-core is (Shared/Contraband/Grades).
export type CoreGrade = "A" | "B" | "C"

-- One bio-core kept in the lab stash (saved). No id: ids only exist for one
-- server session (Ledger) and never leave the server.
export type StashCore = {
	grade: CoreGrade,
	score: number, -- 0..100, the extraction score that gave the grade
	madeAt: number, -- os.time() when it was extracted
}

-- The saved contraband part of a player's save (PlayerProfile.contraband).
export type ContrabandProfile = {
	culture: { active: boolean, grown: number }, -- grown = seconds of online growth so far
	stash: { StashCore },
	caseTier: string, -- "Courier" (2 cradles); "MkII" later
	log: { extractions: number, sales: number, coinsEarned: number, casesLost: number },
}

-- Where the culture in the lab vat is.
export type CultureStage = "Empty" | "Growing" | "Ready" | "Extracting"

-- server → owner (ContrabandEvent "LabState")
export type LabStatePayload = {
	inLab: boolean,
	stage: CultureStage,
	grown: number, -- seconds grown at server time `at`
	total: number, -- seconds needed (Config.Lab.CULTURE_TIME or the fast value)
	at: number, -- workspace:GetServerTimeNow() when `grown` was measured
	running: boolean, -- true = grows at 1 s per s from `at`
	bench: { CoreGrade }, -- stash cores, in order (NO ids)
	stashMax: number,
}

-- server → owner (ContrabandEvent "ExtractState")
export type ExtractStatePayload = {
	active: boolean,
	sessionId: number,
	step: number, -- 1..6 (current), 7 = done
	stepStartedAt: number, -- server time
	guides: number, -- 6
	correct: { number }, -- the fibre guides to cut (1..6), e.g. {1,3,4,6}
	cut: { number }, -- guides already cut
	clamps: { number }, -- clamps already unlocked (1, 2)
	minTimes: { number }, -- copy of Config.Extraction.MIN_TIME
}

-- server → the case HOLDER only (ContrabandEvent "CaseState")
export type CaseStatePayload = {
	holding: boolean,
	tier: string,
	cradles: number,
	grades: { CoreGrade },
}

-- server → seller (ContrabandEvent "SaleResult")
export type SaleResultPayload = {
	ok: boolean,
	coins: number,
	sold: { CoreGrade },
	reason: string?,
}

-- End of an extraction: the grade, where the core went, why points were lost (short English
-- lines from the server, e.g. "1 wrong fibre") and what the core is worth at the buyer.
export type ExtractDonePayload = {
	grade: CoreGrade,
	toCase: boolean,
	notes: { string },
	worth: number,
}

-- Messages from the server to one player (Remotes.ContrabandEvent):
--   LabState      LabStatePayload
--   ExtractState  ExtractStatePayload
--   ExtractDone   ExtractDonePayload
--   CaseState     CaseStatePayload
--   SaleStarted   { endsAt: number }   (server time)
--   SaleResult    SaleResultPayload
--   Notice        { text: string }     (short English line, written by the server)
export type ContrabandEventKind =
	"LabState"
	| "ExtractState"
	| "ExtractDone"
	| "CaseState"
	| "SaleStarted"
	| "SaleResult"
	| "Notice"

return nil
