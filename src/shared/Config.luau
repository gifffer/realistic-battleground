--!strict
-- Tunable values of the game. NOTE: replicated to clients — nothing secret here,
-- and the server never trusts a value reported by a client.
--
-- Tip: to balance the game (faster sprint, more stamina...), change the numbers
-- here and nowhere else.

return table.freeze({
	GAME_TITLE = "Realistic Battleground",
	VERSION = "v0.0.3 PRE-ALPHA",

	-- Seconds between two background saves of a player's profile.
	AUTOSAVE_INTERVAL = 60,

	Character = table.freeze({
		MAX_HEALTH = 100,
		-- Studs per second. Roblox's default 16 is really a running pace for an R6
		-- body: a realistic walk at that speed makes the feet slide. Walk 10,
		-- sprint 22 match the walk / run animations (MovementClips).
		WALK_SPEED = 10,
		SPRINT_SPEED = 22,
		CROUCH_SPEED = 8,
		-- R6: distance from the center of the HumanoidRootPart down to the feet
		-- (legs 2 studs + half of the root part 1 stud).
		ROOT_TO_FEET = 3,
		-- Below this horizontal speed (studs/s) the player counts as standing
		-- still: holding Shift without moving doesn't drain stamina.
		MOVING_THRESHOLD = 2,
	}),

	Stamina = table.freeze({
		MAX = 100,
		REGEN_PER_SECOND = 25,
		-- Seconds without spending stamina before it starts refilling.
		REGEN_DELAY = 1,
		SPRINT_DRAIN_PER_SECOND = 12,
		-- Once stamina hits 0 the player is "exhausted": they can't sprint
		-- again until stamina is back to this value (stops stuttery sprinting).
		EXHAUSTED_RECOVER_AT = 25,
	}),

	-- Keyboard keys. Design rule: keys are for FIGHTING only; everything else
	-- goes through on-screen menus (docs/DESIGN.md, "Interface").
	Controls = table.freeze({
		SPRINT = Enum.KeyCode.LeftShift, -- hold
		-- In third person the cursor is locked in the middle of the screen
		-- (to aim). This key frees it to click the menus, and locks it again.
		FREE_CURSOR = Enum.KeyCode.LeftControl,
		-- Toggle crouch. Pressed while sprinting = slide.
		-- (Climbing uses the normal jump key: jump in front of a ledge.)
		CROUCH = Enum.KeyCode.C,
		-- Attack = left mouse button (hold to keep attacking).
		BLOCK = Enum.KeyCode.F, -- hold; press right before a hit = parry
		DASH = Enum.KeyCode.Q,
		-- Switch first / third person. Roblox key codes follow the key's
		-- POSITION (US layout): KeyCode.Z is the key left of X, labelled
		-- W on an AZERTY keyboard and Z on a QWERTY one.
		CAMERA_TOGGLE = Enum.KeyCode.Z,
		-- Play the equipped emote (Shop). Not while fighting.
		EMOTE = Enum.KeyCode.B,
	}),

	-- Slide: press CROUCH while sprinting. A burst of speed that fades,
	-- then you end up crouched.
	Slide = table.freeze({
		STAMINA_COST = 15,
		COOLDOWN = 1.2, -- seconds between two slides (counted from the start)
		DURATION = 0.75,
		START_SPEED = 34, -- studs/s at the start...
		END_SPEED = 10, -- ...slowing down to this at the end
		-- You must already be running at least this fast (studs/s) to slide.
		MIN_SPEED = 14,
	}),

	-- Ledge climb: jump in front of a wall whose top is reachable. Heights are
	-- measured from the FEET. Two moves, chosen by the height of the ledge:
	--   • VAULT  (low obstacle): one hand on top, the body swings over, fast,
	--     you keep your running speed.
	--   • MANTLE (high ledge): grab the edge, hang, pull up, step onto it.
	Climb = table.freeze({
		STAMINA_COST = 10,
		COOLDOWN = 0.5,
		-- Ledges up to this height are vaulted; higher ones are mantled.
		VAULT_MAX_HEIGHT = 3.6,
		VAULT_DURATION = 0.42,
		-- Mantle: duration for a ledge just above VAULT_MAX_HEIGHT, plus
		-- extra time for each stud higher, never more than MAX_DURATION.
		MANTLE_MIN_DURATION = 0.7,
		MANTLE_SECONDS_PER_STUD = 0.1,
		MAX_DURATION = 0.95,
		MIN_HEIGHT = 2.5, -- lower than this: just walk / jump over it
		MAX_HEIGHT = 5.5, -- higher than this: out of reach
		REACH = 2.5, -- max distance (studs) from the character to the wall
		-- Extra margin when the SERVER checks the ledge: its copy of your
		-- position is slightly behind (network delay).
		SERVER_TOLERANCE = 2,
	}),

	-- Tools for testing in Studio only (never active in the published game).
	Dev = table.freeze({
		-- Builds a parkour test course next to the spawn: walls of every
		-- height, vault rails, a climbing tower... (Server/Systems/DevCourse)
		TEST_COURSE = true,
		-- In Studio only: every kit can be equipped without buying it (to
		-- test new kits without levelling up). Never in the published game.
		UNLOCK_KITS_IN_STUDIO = true,
	}),

	-- Basic combat (M1 combo, block, parry, dash). Times are in seconds.
	-- Everything is decided by the SERVER with these numbers; the client
	-- only uses them to feel responsive (it never decides a hit).
	Combat = table.freeze({
		-- CollectionService tag on every model that can fight (players and
		-- training dummies), so clients can find them for visual effects.
		TAG = "Combatant",

		-- M1 combo: damage of hits 1, 2, 3 and 4 (the 4th is the "finisher").
		M1_DAMAGE = table.freeze({ 5, 5, 5, 8 }),
		M1_INTERVAL = 0.38, -- minimum time between two M1
		-- The server lets a punch / move in this much before its time (the
		-- client sends it right on time, and the network adds a few ms:
		-- without it, chained punches were refused - a swing with no hit).
		ATTACK_GRACE = 0.08,
		FINISHER_RECOVERY = 1.0, -- pause after the 4th hit before attacking again
		COMBO_RESET = 1.0, -- no M1 for this long → the combo starts over at hit 1
		-- Wind-up: time between the click and the moment the hit lands.
		-- Gives the opponent a chance to block/parry. (Later synced with the
		-- "Hit" marker of the animations.)
		HIT_DELAY = 0.15,

		-- Hitbox: a box in front of the attacker.
		HITBOX_SIZE = Vector3.new(5, 5, 5.5),
		HITBOX_FORWARD = 3, -- studs in front of the attacker's center

		-- Being hit.
		HIT_STUN = 0.5, -- longer than M1_INTERVAL: a started combo can't be escaped
		FINISHER_STUN = 0.8,
		KNOCKBACK_SPEED = 45, -- studs/s, 4th hit only
		KNOCKBACK_TIME = 0.2,
		-- Every other hit pushes the victim a little too (about 1 stud): the
		-- body is moved by the fist instead of the fist going through it.
		HIT_PUSH_SPEED = 9,
		HIT_PUSH_TIME = 0.1,
		BLOCK_PUSH_SPEED = 5, -- a blocked hit still shoves the guard back a bit

		-- Blocking.
		BLOCK_REDUCTION = 0.8, -- 80 % less damage
		BLOCK_STAMINA_COST = 15, -- per blocked hit (doubled for the 4th hit)
		GUARD_BREAK_STUN = 1.5, -- out of stamina while blocking
		-- Parry: block started at most PARRY_WINDOW before the hit lands.
		PARRY_WINDOW = 0.2,
		PARRY_STUN = 1.0, -- the ATTACKER is stunned
		-- Anti-spam: a new block only gets a parry window if the previous
		-- block ended at least this long ago.
		PARRY_REARM = 0.6,

		-- Dash.
		DASH_STAMINA_COST = 25,
		DASH_COOLDOWN = 2,
		DASH_DISTANCE = 18,
		DASH_TIME = 0.25,
		DASH_INVULNERABLE = 0.2, -- hits are dodged during this time

		-- Speed multipliers while doing things (see Movement).
		SPEED_WHILE_BLOCKING = 0.5,
		SPEED_WHILE_ATTACKING = 0.7,
		SPEED_WHILE_STUNNED = 0.3,

		-- Hit zones (where the punch lands). The attacker AIMS (centre of the
		-- screen on the head / torso of the opponent); the server checks that
		-- this body part really is inside the hitbox.
		ZONE_DAMAGE = table.freeze({ Head = 1.25, Torso = 1, Legs = 0.85 }),
		-- Punches can land on the head or the torso (legs = kicks, later kits).
		PUNCH_ZONES = table.freeze({ "Head", "Torso" }),
		-- Aim ray (Shared/Util/AimRule): its length in studs (a bit more than a
		-- punch's reach), and how much it must point where the attacker faces
		-- (dot product with the facing; 0.2 ≈ within 78°), else it's ignored.
		AIM_RAY_LENGTH = 14,
		MIN_AIM_FACING = 0.2,
		HEAD_EXTRA_STUN = 0.15, -- seconds added to the stun of a head hit
		LEG_HIT_SLOW = 0.8, -- speed multiplier after a leg hit...
		LEG_HIT_SLOW_TIME = 1.5, -- ...for this long

		-- Studio only: shows hitboxes as red boxes, to check they're right.
		DEBUG_HITBOXES = true,
		-- Spawns training dummies near the spawn point (one passive, one that
		-- attacks you, to practice blocking and parrying).
		TRAINING_DUMMIES = true,
	}),

	-- Kits (Shared/Kits): special moves on keys 1–4 and the Awakening (G).
	-- Each move's own numbers (damage, cooldown...) are in its kit file.
	Kits = table.freeze({
		-- Keys of the 4 move slots, in order.
		MOVE_KEYS = table.freeze({
			Enum.KeyCode.One,
			Enum.KeyCode.Two,
			Enum.KeyCode.Three,
			Enum.KeyCode.Four,
		}),
		AWAKEN_KEY = Enum.KeyCode.G,
		-- The Awakening's activation animation: no attacking during it (seconds).
		AWAKEN_TIME = 1.0,

		-- Awakening gauge ("Fury"), 0 → FURY_MAX. It fills by fighting:
		FURY_MAX = 100,
		FURY_PER_DAMAGE_DEALT = 1.6, -- per HP of damage you deal
		FURY_PER_DAMAGE_TAKEN = 0.5, -- per HP you lose (comebacks)
		-- (It doesn't fill while you are awakened, and resets when you die.)

		-- Bleeding: damage arrives in small ticks this often (seconds).
		BLEED_TICK = 0.5,
		-- A knocked-down fighter (tackle, launch) is dazed this long after
		-- getting back up.
		KNOCKDOWN_GETUP_STUN = 0.5,
		-- A launch (knockback + knockdown) throws the body this high (studs/s).
		LAUNCH_UP_SPEED = 18,
		-- Tackle: how long the charge pushes are allowed to run after contact
		-- before the attacker brakes (seconds).
		CHARGE_BRAKE_TIME = 0.08,
		-- Follow-up strike on the ground (Awakened tackle): reach in studs.
		FOLLOW_UP_RANGE = 7,
	}),

	-- Progression (step 7): XP → levels, coins. Only fights against real
	-- players count (no farming the training dummies).
	Progression = table.freeze({
		KILL_XP = 50,
		KILL_COINS = 10,
		FINISHER_BONUS_XP = 25, -- the kill was a finisher (not a fall / a flee)
		FINISHER_BONUS_COINS = 5,
		-- Assist: you damaged someone killed by another player, recently.
		ASSIST_XP = 20,
		ASSIST_COINS = 4,
		ASSIST_TIME = 15, -- seconds: damage older than this doesn't count
		-- Killing the same player again within this many seconds gives
		-- nothing (no farming between two friends).
		REPEAT_KILL_WINDOW = 180,
		-- Damage dealt: 1 XP every DAMAGE_PER_XP damage (paid out every few seconds).
		DAMAGE_PER_XP = 5,
		-- Time played: every PLAYTIME_INTERVAL seconds.
		PLAYTIME_INTERVAL = 300,
		PLAYTIME_XP = 15,
		PLAYTIME_COINS = 2,
		-- Level curve: going from level n to n + 1 costs
		-- round(LEVEL_BASE_XP × n ^ LEVEL_EXPONENT) XP. Level 2 = 150 XP (≈ 3 kills).
		LEVEL_BASE_XP = 150,
		LEVEL_EXPONENT = 0.8,
		MAX_LEVEL = 100,
	}),

	-- Duels (step 8): best of 3, in arenas built far from the free arena.
	Duels = table.freeze({
		ROUNDS_TO_WIN = 2,
		CHALLENGE_TIMEOUT = 15, -- seconds to accept
		CHALLENGE_COOLDOWN = 10, -- seconds between two challenges sent
		IN_COMBAT_TIME = 5, -- hit less than this long ago = can't be challenged
		COUNTDOWN = 3, -- "3, 2, 1, FIGHT"
		ROUND_END_PAUSE = 3, -- between the KO and the next round
		RESULT_TIME = 6, -- the VICTORY / DEFEAT screen, then back to the free arena
		ARENA_COUNT = 4,
		-- Ranked (ELO).
		START_ELO = 1000,
		ELO_K = 32,
		-- Matchmaking: accept an ELO gap of MATCH_RANGE, widening by
		-- MATCH_RANGE_GROWTH every 5 s of waiting.
		MATCH_RANGE = 100,
		MATCH_RANGE_GROWTH = 50,
		-- Ranks (shown in the menu): minimum ELO of each.
		RANKS = table.freeze({
			table.freeze({ name = "BRONZE", minElo = 0 }),
			table.freeze({ name = "SILVER", minElo = 1100 }),
			table.freeze({ name = "GOLD", minElo = 1300 }),
			table.freeze({ name = "PLATINUM", minElo = 1500 }),
			table.freeze({ name = "DIAMOND", minElo = 1700 }),
		}),
		-- Rewards (XP, coins). Challenges: same anti-farm as kills.
		CHALLENGE_WIN = table.freeze({ xp = 40, coins = 8 }),
		CHALLENGE_LOSS = table.freeze({ xp = 10, coins = 0 }),
		RANKED_WIN = table.freeze({ xp = 100, coins = 25 }),
		RANKED_LOSS = table.freeze({ xp = 30, coins = 0 }),
	}),

	-- Injuries (step 5). They last until you die or get a kill (which heals).
	Injuries = table.freeze({
		-- Legs: after this much damage taken on the legs (kicks), you LIMP.
		LIMP_LEG_DAMAGE = 25,
		LIMP_SPEED = 0.75, -- speed multiplier while limping (no sprinting)
		-- Low health: under this, screen and posture show it (client) and,
		-- out of combat, health slowly comes back up to it.
		LOW_HEALTH = 25,
		REGEN_DELAY = 10, -- seconds without taking damage before it starts
		REGEN_PER_SECOND = 1,
		-- A heavy blow to the head (the 4th M1 on the head) MAY open a cut
		-- (this chance), which bleeds like this.
		CRIT_BLEED = table.freeze({ perSecond = 1.5, duration = 3 }),
		CRIT_BLEED_CHANCE = 0.3,
		-- Chance that a plain punch (M1 1-3) draws visible blood, per zone. Fists
		-- rarely cut: blood is mostly for the bottle (its moves set their own
		-- `bloodChance` in the kit). Decided by the server: everyone sees the same.
		PUNCH_BLOOD_CHANCE = table.freeze({ Head = 0.12, Torso = 0.03, Legs = 0 }),
		-- Glass (moves with `cuts`) cuts the skin where it lands: head or torso,
		-- on the side facing the attacker. Realistic: a smashed bottle
		-- makes a ragged laceration, a broken bottle a clean slash; both go
		-- through the skin into the flesh (a deep slash shows muscle, or the
		-- skull at the bottom on the head) - never an open skull or rib cage.
		-- Hitting the same spot again makes that cut bigger (3 sizes). Drawn
		-- with the wound models (docs/WOUNDS_FR.md). Realistic gore: on Roblox,
		-- fill in the experience's maturity questionnaire accordingly, or turn
		-- this off.
		SKIN_TEAR = true,
		-- Bruise pictures: assets/bruises/*.png uploaded to Roblox, their image
		-- ids here (docs/WOUNDS_FR.md). With them a bruise is soft, mottled
		-- pictures on the skin (tinted by its age); without (0), overlapping
		-- ovals.
		BRUISE_IMAGES = table.freeze({
			blobs = table.freeze({ 0, 0, 0, 0 }), -- bruise_1..4.png
			rim = 0, -- bruise_rim.png
			petechiae = 0, -- bruise_petechiae.png
		}),
		-- Burn pictures (Dr. Rift's acid and fire): assets/burns/*.png uploaded
		-- to Roblox, their image ids here (docs/WOUNDS_FR.md). With them a burn
		-- is realistic pictures spreading over the burnt limbs (raw eroded
		-- flesh running down for acid, mottled char for fire); without (0),
		-- simpler patches.
		BURN_IMAGES = table.freeze({
			acid = table.freeze({ 131778333760722, 126361621625485, 94024882070515 }), -- acid_1..3.png
			fire = table.freeze({ 126783746008106, 105061454734886, 79962622099236 }), -- fire_1..3.png
			halo = 106354500879013, -- burn_halo.png
		}),
		-- A smashed bottle leaves bits of glass stuck in the skin; this often it
		-- only grazes them (glass, no torn cut).
		GLASS_GRAZE_CHANCE = 0.35,
		-- A new cut closer than this (studs) to an old one of the same glass
		-- makes the old one bigger instead.
		GASH_MERGE_DISTANCE = 0.3,
		-- At or under this health, a fighter groans when hit (Sounds.HurtGrunt).
		HURT_SOUND_HEALTH = 70,
	}),

	-- 0 HP = knocked out (KO) on the ground, not dead. Someone can finish
	-- you (M1 on you while you're down); otherwise you get back up.
	Knockout = table.freeze({
		DURATION = 6, -- seconds on the ground
		GETUP_HEALTH = 25, -- health when you get back up on your own
		GETUP_STUN = 0.8, -- dazed for this long after getting up
		-- Finishing: M1 near a KO'd fighter in front of you.
		FINISH_RANGE = 6, -- studs between the two characters
		FINISH_IMPACT = 0.45, -- seconds from the click to the killing blow
		FINISH_DURATION = 1.1, -- the finisher animation; can't attack meanwhile
		KILL_HEAL = 35, -- health given to the killer
		RESPAWN_TIME = 5,
		SPAWN_PROTECTION = 3, -- invulnerable after spawning (ends if you attack)
		-- Hit by someone less than this long ago = "in combat": leaving the
		-- game counts as a death and gives them the kill.
		COMBAT_TAG_TIME = 10,
		-- The kill feed (top right) keeps this many lines, each this long.
		FEED_LINES = 5,
		FEED_TIME = 6,
	}),

	Camera = table.freeze({
		-- Over-the-shoulder offset (right, up, back) in third person.
		SHOULDER_OFFSET = Vector3.new(1.75, 0.25, 0),
		MIN_ZOOM = 6,
		MAX_ZOOM = 12,
		-- Camera distance used when coming back from first person.
		DEFAULT_ZOOM = 10,
		DEFAULT_FOV = 70,
		SPRINT_FOV = 78, -- slightly wider view while sprinting = feeling of speed
		-- How far the camera goes down (studs), matching the body's animation.
		CROUCH_DROP = 1.1,
		SLIDE_DROP = 2.3,
	}),
})
