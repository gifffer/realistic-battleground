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
	kind: string?, -- ElementKind it came from (older saves have none: it follows the grade)
}

-- The bio-elements an extraction shows (stylised lab specimens, never organs).
--   Cluster  fused amber lobes      Pod   ribbed violet seed pod
--   Coil     glossy green spiral    Husk  a dried-out decoy: worth nothing
export type ElementKind = "Cluster" | "Pod" | "Coil" | "Husk"
export type ElementCondition = "Intact" | "Bruised" | "Ruptured"

-- One element as the player sees it (the exact score stays on the server).
export type ExtractElement = {
	kind: ElementKind,
	condition: ElementCondition, -- (a Husk is always "Intact": ignored)
	viability: number, -- 0..3 bars shown on the monitor (coarse, from the score band)
	state: ElementState?, -- where it is in the extraction (ExtractState only)
}

-- The extraction's steps (server FSM, mirrored by the client) and where each element is.
--   Nest     in its gel nest in the shell      Pulling  grabbed, being pulled free
--   Held     in the gloved hand                Loose    set down on the trolley top
--   OnTray   in the steel specimen tray        Sealed   dropped into the pass-box, capsule sealed
export type ExtractStep = "Intro" | "Incise" | "Spread" | "Harvest"
export type ElementState = "Nest" | "Pulling" | "Held" | "Loose" | "OnTray" | "Sealed"

-- The saved contraband part of a player's save (PlayerProfile.contraband).
export type ContrabandProfile = {
	-- grown = seconds of online growth so far; seed = what the culture holds (Extraction rolls
	-- the elements from it, so stopping an extraction never rerolls them; 0 = none yet)
	culture: { active: boolean, grown: number, seed: number },
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
	kinds: { string }, -- their ElementKind, parallel to `bench`
	stashMax: number,
}

-- server → owner (ContrabandEvent "ExtractState")
-- Times are workspace:GetServerTimeNow() (the client compares with the same clock).
export type ExtractStatePayload = {
	active: boolean,
	sessionId: number,
	step: ExtractStep?, -- (nil when not active)
	layer: number, -- 0..2 seam layers cut (Incise)
	spread: { boolean }, -- the two panels open
	coolEnds: number?, -- the cooling bar runs out (nil until the panels are open)
	slots: number, -- capsules to fill (1..Config.Extraction.CAPSULES)
	sealed: number, -- capsules sealed so far
	elements: { ExtractElement }, -- by index (the client lays them out in the cavity), with state
	acked: number, -- ExtractAction messages the server has handled so far in this session
}

-- server → the case HOLDER only (ContrabandEvent "CaseState")
export type CaseStatePayload = {
	holding: boolean,
	tier: string,
	cradles: number,
	grades: { CoreGrade },
	kinds: { string }, -- their ElementKind, parallel to `grades`
}

-- server → seller (ContrabandEvent "SaleResult")
export type SaleResultPayload = {
	ok: boolean,
	coins: number,
	sold: { CoreGrade },
	reason: string?,
}

-- server → owner (ContrabandEvent "ExtractPicked"): one element was transferred and sealed.
-- inert = it was a husk (the capsule is wasted, no core, no grade).
export type ExtractPickedPayload = {
	index: number,
	slot: number, -- which capsule (1..slots), in the order they were sealed
	inert: boolean,
	kind: ElementKind,
	grade: CoreGrade?,
	toCase: boolean, -- the core went into a case lying in the lab (else the stash)
}

-- End of an extraction: the cores made (kind, grade, what each is worth at the buyer), how
-- many capsules were wasted on husks, and where they went.
export type ExtractDonePayload = {
	cores: { { kind: ElementKind, grade: CoreGrade, worth: number } },
	inert: number,
	toCase: boolean,
}

-- Messages from the server to one player (Remotes.ContrabandEvent):
--   LabState      LabStatePayload
--   ExtractState  ExtractStatePayload
--   ExtractPicked ExtractPickedPayload
--   ExtractDone   ExtractDonePayload
--   CaseState     CaseStatePayload
--   SaleStarted   { endsAt: number }   (server time)
--   SaleResult    SaleResultPayload
--   Notice        { text: string }     (short English line, written by the server)
export type ContrabandEventKind =
	"LabState"
	| "ExtractState"
	| "ExtractPicked"
	| "ExtractDone"
	| "CaseState"
	| "SaleStarted"
	| "SaleResult"
	| "Notice"
	| "DoorCut" -- (no data) a lab door teleport is coming: the client fades the screen

return nil
