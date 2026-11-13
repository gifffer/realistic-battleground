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
		-- Tag on the bodies left by a finisher after their player respawned
		-- (Server/Systems/Corpses): clients draw their wounds, nothing else.
		CORPSE_TAG = "Corpse",

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
		PUNCH_BLOOD_CHANCE = table.freeze({ Head = 0.35, Torso = 0.15, Legs = 0.05 }),
		-- Kits' own blood chances, times this (bloodier fights; capped at 1).
		BLOOD_CHANCE_SCALE = 1.6,
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

	-- Gore of the very strong hits (Shared/Util/HeavyGore): RARE, and only
	-- in a fight - never from a finisher. Someone lands a BIG COMBO on a
	-- fighter (the server counts it per victim: the same attacker's hits
	-- that land, each less than COMBO_GAP after the last); once it is big
	-- enough, its next HEAVY blow (HEAVY_DAMAGE or more, the 4th M1, or a
	-- blow that knocks down / launches) rolls ONCE: it may snap a bone open
	-- (an open fracture of the forearm / the shin on the side it hit) or,
	-- rarer, tear an arm off. Hit or miss, the combo then starts over. The
	-- fighter stays alive and keeps fighting (a broken shin: he limps). On
	-- the blow that knocks him out the chances are higher.
	-- Decided by the server, drawn on every client. Off with
	-- Injuries.SKIN_TEAR too.
	HeavyGore = table.freeze({
		ENABLED = true,
		-- A big combo: this many hits in a row by the same attacker...
		COMBO_HITS = 6,
		-- ...or this much damage in a row from him (whichever comes first).
		COMBO_DAMAGE = 40,
		-- Seconds between two of his hits for the combo to go on.
		COMBO_GAP = 1.6,
		-- A blow counts as heavy at this damage or more (or the 4th M1, or
		-- a blow that knocks down / launches).
		HEAVY_DAMAGE = 9,
		-- The heavy blow that ends a big combo (one roll): the chance of an
		-- open fracture, of a torn arm (a leg only rolls for a fracture)...
		FRACTURE_CHANCE = 0.2,
		TEAR_CHANCE = 0.05,
		-- ...and when that blow knocks him out.
		KO_FRACTURE_CHANCE = 0.3,
		KO_TEAR_CHANCE = 0.1,
		-- Legs torn off too (an R6 body without a leg can't stand: off, only
		-- arms come off).
		TEAR_LEGS = false,
		-- After one of these on someone, nothing more for this long (seconds).
		COOLDOWN = 8,
		-- Also in duels.
		IN_DUELS = false,
		-- At most per body (the Bouncer's torn arm counts).
		MAX_TORN_LIMBS = 2,
		MAX_FRACTURES = 2,
		-- A torn limb flies off (studs/s), then lies there this long.
		LIMB_FLING_SPEED = 24,
		LIMB_FLING_UP = 16,
		TORN_LIMB_TIME = 12,
	}),

	-- Blood (client-side visuals only: nothing here changes a fight). Used by
	-- the client's Combat/Blood*.luau modules and the gore modules.
	-- Realistic gore: on Roblox, fill in the experience's maturity
	-- questionnaire accordingly, or set ENABLED = false.
	Blood = table.freeze({
		-- Master switch: false = no blood at all (hit sprays, drips, pools,
		-- footprints...). The finishers' gore is also gated by Injuries.SKIN_TEAR.
		ENABLED = true,
		-- How much blood a client keeps at once: "Auto" follows the player's
		-- Roblox graphics quality (Esc > Settings), or force "Low" / "Medium" /
		-- "High". Low keeps 40 % of the caps below, Medium 70 %.
		QUALITY = "Auto",
		-- The colours of blood, from fresh to old (one palette for every
		-- module). Real blood is DARK: deep crimson, never pink or bright red.
		PALETTE = table.freeze({
			ARTERIAL = Color3.fromRGB(138, 9, 6), -- fresh from an artery (spurts, fresh spatter)
			ARTERIAL_LIGHT = Color3.fromRGB(161, 20, 14), -- a thin film / mist (thin = lighter)
			VENOUS = Color3.fromRGB(94, 11, 11), -- drips, pools, runs
			CLOTTED = Color3.fromRGB(72, 10, 10), -- 20-60 s: thickening, its edge darkens
			DRYING = Color3.fromRGB(62, 13, 11), -- 60-120 s
			DRY = Color3.fromRGB(48, 14, 11), -- matte, turning reddish-brown (dried blood is never pure red)
			OLD = Color3.fromRGB(42, 21, 16), -- brown-black crust (end of its life)
			GLOSS = Color3.fromRGB(30, 2, 2), -- the wet film on a pool (dark: the sky reflects)
			FABRIC_SOAK = Color3.fromRGB(96, 11, 11), -- soaked into a shirt / pants (fresh: crimson on a light shirt)...
			FABRIC_SOAK_DRY = Color3.fromRGB(46, 17, 13), -- ...once dry
			SALIVA = Color3.fromRGB(168, 38, 36), -- blood mixed with saliva / mucus (spit, mouth)
			SERUM = Color3.fromRGB(214, 176, 96), -- the clear-yellow fluid around an old pool / a graze
			RAW = Color3.fromRGB(190, 80, 72), -- scraped skin (graze, split knuckle)
			FABRIC_WET = Color3.fromRGB(84, 10, 10), -- the wet patch round a soak (darkens a dark shirt; on a white one it must read pink-red: a black ring reads as dirt)
		}),
		-- Passive blood (drips, a run's drop, a stump pouring) falls with this
		-- gravity (studs/s²) instead of workspace.Gravity: real drops fall slower.
		PASSIVE_GRAVITY = 45,
		-- The most blood a client draws at once (at "High"; the oldest goes).
		CAPS = table.freeze({
			STAINS = 700, -- marks on floors / walls
			GLOSS = 40, -- wet shiny films on fresh pools
			POOLS = 20, -- pools growing under bleeders / torn arteries
			BODY = 240, -- marks on bodies (skin, soaked clothes, fists)
			BODY_PER_CHARACTER = 30,
			FOOTPRINTS = 120,
			RUNS = 40, -- blood running down a wall / the skin, at once
			DROPS = 140, -- drops flying at once
			PENDING_LANDINGS = 60, -- drops whose landing is computed in advance
			NEW_PER_FRAME = 40, -- new marks per frame (more wait for the next frames)
			PARTICLES_PER_BURST = 120,
			AGE_PER_FRAME = 150, -- marks updated (drying) per frame
			RIVULETS = 40, -- runs on skin moving at once (all characters)
			PENDANTS = 24, -- drops hanging (chin, fingertips...) at once
			CROWNS = 8, -- splash crowns (a big drop hitting the ground) at once
			RIPPLES = 6, -- rings on pools (a drop falling into one) at once
		}),
		-- How each kind of mark ages, in seconds (real minutes squeezed):
		-- red → dark red at `fresh`, clotted (dark edge) at `clot`, dry at `dry`,
		-- gone at `life` (fading the last 15 %). `gloss`: how shiny it starts
		-- (Reflectance), lost by `glossEnd`.
		PROFILES = table.freeze({
			spatter = table.freeze({
				fresh = 12, -- (stays visibly red through the rest of the fight)
				clot = 30,
				dry = 60,
				life = 120,
				gloss = 0,
				glossEnd = 1,
			}),
			pool = table.freeze({
				fresh = 20,
				clot = 60,
				dry = 150,
				life = 240, -- (long enough for the pale serum ring to show, 90-180 s)
				gloss = 0.25,
				glossEnd = 60,
			}),
			run = table.freeze({
				fresh = 10,
				clot = 30,
				dry = 90,
				life = 120,
				gloss = 0.12,
				glossEnd = 30,
			}),
			body = table.freeze({
				fresh = 10,
				clot = 30,
				dry = 90,
				life = 120,
				gloss = 0.08,
				glossEnd = 25,
			}),
			smear = table.freeze({
				fresh = 5,
				clot = 5,
				dry = 40,
				life = 90,
				gloss = 0,
				glossEnd = 1,
			}),
			soak = table.freeze({
				fresh = 3,
				clot = 20,
				dry = 60,
				life = 600,
				gloss = 0,
				glossEnd = 1,
			}),
			foot = table.freeze({
				fresh = 10,
				clot = 10,
				dry = 50,
				life = 60,
				gloss = 0,
				glossEnd = 1,
			}),
			wound = table.freeze({
				fresh = 15,
				clot = 45,
				dry = 120,
				life = math.huge,
				gloss = 0.3,
				glossEnd = 90,
			}),
			-- (v2: blood ON the face, BloodRivulet / BloodFace: stays until respawn)
			rivulet = table.freeze({ -- a run's trail on the skin: dark first, dry at 60 s
				fresh = 8,
				clot = 20,
				dry = 60,
				life = math.huge,
				gloss = 0,
				glossEnd = 1,
			}),
			bead = table.freeze({ -- the drop at a run's front: wet and shiny the longest
				fresh = 15,
				clot = 60,
				dry = 120,
				life = math.huge,
				gloss = 0.22,
				glossEnd = 90,
			}),
			crust = table.freeze({ -- dried crust (old runs, a graze, split knuckles)
				fresh = 0,
				clot = 0,
				dry = 1,
				life = math.huge,
				gloss = 0,
				glossEnd = 1,
			}),
			cut = table.freeze({ -- the split skin of a brow / cheek cut
				fresh = 15,
				clot = 40,
				dry = 120,
				life = math.huge,
				gloss = 0.25,
				glossEnd = 60,
			}),
			saliva = table.freeze({ -- spit blood (mixed with saliva)
				fresh = 4,
				clot = 10,
				dry = 40,
				life = 90,
				gloss = 0,
				glossEnd = 1,
			}),
		}),
		-- How fast a bleeder's pool grows: area (studs²) per second for each
		-- point of BleedPerSecond.
		FEED_SCALE = 0.35,
		-- Blood pictures: assets/blood/*.png uploaded to Roblox, their image ids
		-- here (guide: docs/BLOOD_FR.md). 0 = not uploaded yet: the game draws
		-- that kind of mark with plain shapes instead. Fill them in any order.
		-- Each list is the numbered files of that kind, in order: spatterRound
		-- = { spatter_round_1, _2, _3 }. footL / footR: 1 heavy, 2 partial,
		-- 3 trace; pool / poolRim go in pairs (pool_2 with pool_rim_2).
		IMAGES = table.freeze({
			spatterRound = table.freeze({ 129652093044803, 121498932398811, 81274669458734 }), -- spatter_round_1..3
			spatterOval = table.freeze({ 133890404957396, 114674991406483, 75490293544153 }), -- spatter_oval_1..3
			spatterTail = table.freeze({ 126762946376902, 81333818985950, 91190695364226 }), -- spatter_tail_1..3
			spatterStreak = table.freeze({ 121791214831633, 95347309663029 }), -- spatter_streak_1..2
			satellites = table.freeze({ 107693275017714, 110691209010386, 127425185904579 }), -- satellites_1..3
			drip = table.freeze({ 101998939021063, 90667518738525 }), -- drip_1..2
			dripPool = table.freeze({ 109255283220791, 115452152095923 }), -- drip_pool_1..2
			pool = table.freeze({ 95384884943813, 80392551772155, 97179242410398 }), -- pool_1..3
			poolRim = table.freeze({ 106826235132117, 89176067619082, 130214366446942 }), -- pool_rim_1..3
			poolLobe = table.freeze({ 108586807874189, 106810200162755, 132219975415999 }), -- pool_lobe_1..3
			run = table.freeze({ 117518789409851, 130904925174038 }), -- run_1..2
			smear = table.freeze({ 108391533303885, 131202605979713 }), -- smear_1..2
			handL = table.freeze({ 71377374998060 }), -- handprint_L_1
			handR = table.freeze({ 84539848533298 }), -- handprint_R_1
			footL = table.freeze({ 82397064928935, 90987243783719, 109215097479157 }), -- foot_L_1..3
			footR = table.freeze({ 115787387957335, 134983683933176, 73258765967837 }), -- foot_R_1..3
			soak = table.freeze({ 140519271845432, 104640502456555, 137232664976275 }), -- soak_1..3
			skinSmear = table.freeze({ 110704894117972, 116898760772229 }), -- skin_smear_1..2
			knuckles = table.freeze({ 78951370578961, 128504747370997 }), -- knuckles_1..2
			arterialArc = table.freeze({ 107996161995401, 115760739284054 }), -- arterial_arc_1..2
			pDrop = table.freeze({ 101151632642906 }), -- p_drop
			pDrops4x4 = table.freeze({ 118856031934638 }), -- p_drops_4x4
			pGobs4x4 = table.freeze({ 100815666699043 }), -- p_gobs_4x4
			pMist8x8 = table.freeze({ 132573984669153 }), -- p_mist_8x8
			beamStream = table.freeze({ 135594613079576 }), -- beam_stream
			-- v2 details on the fighters (0 = not uploaded yet: an uploaded
			-- picture of a close kind is drawn instead, see docs/BLOOD_FR.md)
			rivuletStrip = table.freeze({ 100346535090011, 110604478267351, 82698353383871 }), -- rivulet_strip_1..3 (else "run")
			rivuletBead = table.freeze({ 135979741247839, 122834661572547 }), -- rivulet_bead_1..2
			rivuletFork = table.freeze({ 71095220678891, 71274475403062 }), -- rivulet_fork_1..2
			browCut = table.freeze({ 74392188791197, 104168856657120 }), -- browcut_1..2 (else "skinSmear")
			cheekCut = table.freeze({ 116411472783083 }), -- cheekcut_1 (else "skinSmear")
			lipFilm = table.freeze({ 107014616933821 }), -- lipfilm_1 (else "skinSmear")
			wipeSmear = table.freeze({ 92012326076640, 103011312188202 }), -- wipe_smear_1..2 (else "skinSmear")
			crustStrip = table.freeze({ 130585832246902, 117648492973558 }), -- crust_strip_1..2 (else: no crust picture)
			crustPatch = table.freeze({ 128001428689526, 138052353223010 }), -- crust_patch_1..2
			spit = table.freeze({ 97734736135706, 94100067775351 }), -- spit_1..2
			abrasion = table.freeze({ 139500125178501, 99973089746061 }), -- abrasion_1..2 (else "skinSmear")
			splitKnuckle = table.freeze({ 81428781559324 }), -- split_knuckle_1 (else "knuckles")
			wickHalo = table.freeze({ 130352555506995, 74931157464131 }), -- wick_halo_1..2 (else "soak")
			wickWeave = table.freeze({ 72719573380217 }), -- wick_weave_1
			froth4x4 = table.freeze({ 118371954145824 }), -- froth_4x4 (else p_mist_8x8)
			pendant2x2 = table.freeze({ 99574857270541 }), -- pendant_2x2
			-- v2 details in the world (floors, pools, tracks)
			crown4x4 = table.freeze({ 112579069365148 }), -- crown_4x4 (else: no crown, only its tiny drops)
			rippleRing = table.freeze({ 85645245730750 }), -- ripple_ring_1 (else: no ripple)
			starburst = table.freeze({ 111666805106796, 93606236237598 }), -- starburst_1..2 (else "satellites")
			serumHalo = table.freeze({ 90985594653033, 108670503849941, 130952450009466 }), -- serum_halo_1..3, in pairs with pool_1..3
			drag = table.freeze({ 123680049539259, 126526466461890 }), -- drag_1..2 (else "smear")
			shoeRunL = table.freeze({ 72765684284944 }), -- shoe_run_L_1 (else "footL")
			shoeRunR = table.freeze({ 84666117785445 }), -- shoe_run_R_1 (else "footR")
			-- v2 extreme wounds (finishers). No code draws them yet: ready for
			-- when a finisher wants a torn wound decal.
			scalpSplit = table.freeze({ 106404236391579 }), -- scalp_split_1: Y / star split of the scalp (else "browCut")
			-- flesh_tear_1..2: a torn-open wound (skin edge, yellow fat, muscle,
			-- deep wet cavity). The ONLY picture in colour: draw it with
			-- Decal.Color3 = white (1, 1, 1), never a blood tint.
			-- Kept at 0 ON PURPOSE: flesh_tear_2 was refused by Roblox moderation
			-- (too gory for an image) and flesh_tear_1 is not used for the same
			-- reason. Don't upload pictures of open flesh: build it with parts.
			fleshTear = table.freeze({ 0, 0 }),
		}),
		-- A picture not uploaded yet borrows the picture of a close kind that is
		-- (and, with none at all, that kind's plain shapes): a skin rivulet
		-- looks like a wall run until rivulet_strip is uploaded.
		-- (crown4x4, froth4x4, pendant2x2, rippleRing, serumHalo: no stand-in,
		-- the code skips them or uses another particle picture.)
		IMAGE_FALLBACK = table.freeze({
			rivuletStrip = "run",
			rivuletBead = "drip",
			rivuletFork = "run",
			browCut = "skinSmear",
			cheekCut = "skinSmear",
			lipFilm = "skinSmear",
			wipeSmear = "skinSmear",
			crustStrip = "run",
			crustPatch = "skinSmear",
			spit = "drip",
			abrasion = "skinSmear",
			splitKnuckle = "knuckles",
			wickHalo = "soak",
			wickWeave = "soak",
			starburst = "satellites",
			drag = "smear",
			shoeRunL = "footL",
			shoeRunR = "footR",
			scalpSplit = "browCut",
		}),
		-- Face wounds (BloodFace / BloodRivulet). Times in seconds.
		FACE = table.freeze({
			CUTS = true, -- eyebrow / cheekbone cuts, grazes (false: only runs and drops)
			MAX_MARKS = 14, -- face marks per character (runs, cuts, crust...); oldest dry go first
			MAX_ACTIVE_RUNS = 4, -- runs moving at once per character
			TICK = 1 / 15, -- run / hanging-drop updates (seconds)
			RANGE = 60, -- studs from the camera: farther, runs jump to their end, no hanging drops
			SWEAT_AFTER = 6, -- bloody hits on this fighter before blood runs thinner and further
		}),
		-- World details (drops landing, pools, footprints, drags). Studs / seconds.
		WORLD = table.freeze({
			CROWN_RANGE = 40, -- studs from the camera: farther, no splash crown / ripple
			CROWN_MIN_SIZE = 0.07, -- a drop at least this big (studs)...
			CROWN_MIN_HEIGHT = 1.5, -- ...falling at least this far (studs) splashes a crown
			FOOT_DECAY = 0.7, -- each footprint keeps this much of the previous one's blood (real: 0.6-0.75, about 7 prints)
			STARBURSTS_PER_POOL = 4, -- rings of tiny drops around a pool someone drips into
		}),
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
		-- A player killed by a finisher: their body stays where it fell this
		-- long after the killing blow (a frozen copy, Server/Systems/Corpses),
		-- even though they respawn after RESPAWN_TIME.
		FINISHER_BODY_TIME = 10,
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
