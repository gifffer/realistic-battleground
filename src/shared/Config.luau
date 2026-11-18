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
		-- Use what's in your pocket (the 1-slot inventory, bottom-right): drink your
		-- SpezCola. (G is taken by AWAKEN, 1-4 by the kit moves, E by the prompts.)
		USE_ITEM = Enum.KeyCode.R,
		-- Opens the last top bar panel seen / closes the open one.
		MENU = Enum.KeyCode.M,
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
		-- In Studio only: a limping dummy walking near the spawn, and a stage
		-- where one dummy finishes another with any kit's finisher, to watch
		-- them from outside (Server/Systems/TestTools).
		TEST_TOOLS = true,
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

		-- Lag compensation (Server/Systems/Combat/Rewind): every hitbox also
		-- tests the victims where the ATTACKER saw them. That is his round
		-- trip (measured by Roblox) + REWIND_INTERPOLATION ago: Roblox shows
		-- other characters a little late, to move them smoothly.
		REWIND_INTERPOLATION = 0.1,
		-- Never further back than this (seconds): a very laggy (or lag
		-- switching) player gains no reach beyond it.
		REWIND_MAX = 0.35,
		-- Also tested this much before and after (the ping jitters).
		REWIND_TOLERANCE = 0.06,
		-- Positions remembered per fighter (seconds; > REWIND_MAX + TOLERANCE).
		REWIND_HISTORY = 0.6,
		-- Studio only: added to the measured round trip (seconds). Studio's
		-- simulated lag (Incoming Replication Lag) may not show in the ping
		-- the server measures: if the rewind printed in the Output (with
		-- DEBUG_HITBOXES) stays near REWIND_INTERPOLATION, set it to that lag.
		REWIND_STUDIO_EXTRA_PING = 0,

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
		-- Burn textures (every burn: Dr. Rift's ray, acid and flasks, the
		-- Pyromaniac's fire...): assets/burns/*.png uploaded to Roblox, their
		-- image ids here (docs/BURNS_FR.md). Tiled on the burnt faces, one
		-- per stage (1 redness, 2 blisters, 3 eschar, 4 char). 0 = not
		-- uploaded: the old BURN_IMAGES below stand in (Roblox's own
		-- particles for the flame / smoke / ember).
		BURNS = table.freeze({
			skin = table.freeze({
				113128765394969,
				131967997605329,
				74252597997417,
				125259548593338,
			}), -- skin_1..4.png (bare skin)
			cloth = table.freeze({
				103796817123786,
				82410079132632,
				134218033394583,
				129471308703785,
			}), -- cloth_1..4.png (over a shirt / pants)
			acid = table.freeze({ 112442746763176, 111696045453314, 92317291431094 }), -- acid_1..3.png
			spot = 108212204997924, -- spot.png (a laser / ray burn)
			flame = 83282802493156, -- flame.png (4 x 4 flipbook)
			smoke = 135930341177500, -- smoke.png
			ember = 104956583136032, -- ember.png
		}),
		-- Fire textures (assets/fire, tools/pyro/make_fire.py, docs/FIRE_FR.md):
		-- every flame in the game (burning bodies, the Pyromaniac). 0 = not
		-- uploaded: Roblox's own particles stand in (Client/Combat/FireLook).
		FIRE = table.freeze({
			flameLoop = 0, -- flame_loop.png (8 x 8 flipbook, loops)
			flameTongue = 0, -- flame_tongue.png (4 x 4 flipbook, one shot)
			fireball = 0, -- fireball.png (8 x 8 flipbook, one shot)
			groundFire = 0, -- ground_fire.png (4 x 4 flipbook, loops)
			smoke = 0, -- smoke.png (2 x 2: four puffs)
			ember = 0, -- ember.png (2 x 2: dot, streak, flake, sparks)
			glow = 0, -- glow.png
			flameStrip = 0, -- flame_strip.png (Beams, Trails)
			scorch = 0, -- scorch.png (a decal on the floor)
		}),
		-- The first burn pictures (assets/burns/legacy), still used while
		-- BURNS above is 0: acid 1..3 for acid, fire 1..3 for stages 2..4.
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
			-- The same pools WITHOUT the drops drawn around them (same outline,
			-- same number): used instead of pool / pool_rim / serum_halo once
			-- uploaded, so a big pool's drawn drops don't grow with it.
			poolClean = table.freeze({ 139990585262771, 131795471144890, 70633199831673 }), -- cleanpool_1..3
			poolRimClean = table.freeze({ 125318589793366, 76214080937100, 119786435512225 }), -- cleanrim_1..3
			serumHaloClean = table.freeze({ 72011702248843, 71334546934789, 110660327470319 }), -- cleanserum_1..3
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
		-- The big pools the finishers leave (BloodGush.stump): a torn-off limb, a
		-- head burst, a body cut in two loses a LOT of blood in a few seconds.
		-- Each wound pours its blood on the floor under it: spurts with the
		-- heartbeat first (PULSE seconds), then a steady ooze, then slower and
		-- slower until SECONDS. The pool follows the body part as it falls or
		-- slides (a smear while it slides), flows downhill, stops at curbs and
		-- walls, merges with pools close by, then ages like any pool (wet,
		-- clotting, the pale serum ring, dry).
		-- LITRES: how much blood comes out. On a hard floor it makes ONE pool
		-- (BloodPool): one uniform puddle, one colour, that forms where the
		-- blood lands and grows smoothly from the middle while the wound
		-- pours (never separate blotches), then goes on creeping a little for
		-- CREEP seconds after it stops (slower and slower). On a slope it
		-- slides and stretches a little downhill (one short run leaves it on a
		-- real slope); against a curb or a wall it spreads on its free side;
		-- it flows toward the body and under it (a body lying in its own
		-- blood); two pools that meet become one.
		-- Its size once it is done spreading: SIZE_PER_LITRE studs across for
		-- 1 litre, × the litres to the power SIZE_POWER (a bit more than the
		-- square root: a small wound makes a small pool):
		--   the torso cut in two 3.8 L ≈ 8.1 studs, the neck 3.4 L ≈ 7.6,
		--   the shoulder 3 L ≈ 7, the liver hole / the Bull's legs 2.6 L ≈ 6.4,
		--   the portal's legs 2.4 L ≈ 6, the torn arm 0.6 L ≈ 2.6,
		--   the liver itself 0.3 L ≈ 1.6.
		-- (For scale: a body is ~5 studs long. In real life 1.5 L on a hard
		-- floor is a pool ~1 m across, ~2 mm thick; these are about twice
		-- that, like games and films show them - a body lying in a big dark
		-- lake. Change SIZE_PER_LITRE to make them all bigger or smaller, in
		-- proportion: 2.4 was the old, smaller look; 4.1 a bit too big.)
		FINISHER_POOLS = table.freeze({
			ENABLED = true, -- false: no big finisher pools (the spurts still land)
			SIZE_PER_LITRE = 3.5, -- studs across for 1 litre...
			SIZE_POWER = 0.63, -- ...× litres ^ this (0.5 = the square root)
			-- seconds the pool keeps spreading after its wound stops pouring
			-- (slower and slower: you see it keep growing ~30-40 s in all)
			CREEP = 25,
			LIFE = 240, -- seconds a finisher pool stays (the serum ring shows from 90 s)
			MOVING = 2.5, -- studs/s: a wound moving faster smears instead of pooling
			MAX_HEIGHT = 4.5, -- studs: a wound higher than this (in the air) pools nothing yet
			DRAGS = 12, -- smear marks at most per wound while its body slides
			-- One line per wound. LITRES (blood out), SECONDS (how long it keeps
			-- coming), PULSE (seconds of spurts with the heartbeat; 0 = it only
			-- oozes: a limb lying on the floor), BEAT (seconds between beats).
			NECK = table.freeze({ LITRES = 3.4, SECONDS = 20, PULSE = 9, BEAT = 0.38 }), -- the bat: the head burst
			SHOULDER = table.freeze({ LITRES = 3, SECONDS = 18, PULSE = 8, BEAT = 0.4 }), -- the arm torn off: the socket
			TORN_ARM = table.freeze({ LITRES = 0.6, SECONDS = 14, PULSE = 0, BEAT = 0.4 }), -- the arm itself, lying on the floor
			LIVER_HOLE = table.freeze({ LITRES = 2.6, SECONDS = 18, PULSE = 8, BEAT = 0.4 }), -- the liver torn out: the flank
			LIVER = table.freeze({ LITRES = 0.3, SECONDS = 10, PULSE = 0, BEAT = 0.4 }), -- the liver dropped on the floor
			WAIST_TORSO = table.freeze({ LITRES = 3.8, SECONDS = 22, PULSE = 8, BEAT = 0.38 }), -- the portal cut: the upper body
			WAIST_LEGS = table.freeze({ LITRES = 2.4, SECONDS = 18, PULSE = 7, BEAT = 0.35 }), -- the portal cut: the legs
			BISECT_TORSO = table.freeze({ LITRES = 3.8, SECONDS = 22, PULSE = 8, BEAT = 0.36 }), -- the Bull: the top half
			BISECT_LEGS = table.freeze({ LITRES = 2.6, SECONDS = 18, PULSE = 7, BEAT = 0.36 }), -- the Bull: the legs
			TRAIN_TORSO = table.freeze({ LITRES = 4.2, SECONDS = 22, PULSE = 7, BEAT = 0.36 }), -- the train: the torso, head and limbs torn off
			TRAIN_LIMB = table.freeze({ LITRES = 0.4, SECONDS = 12, PULSE = 0, BEAT = 0.4 }), -- the train: a torn limb lying on the floor
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

	-- Weather events in the city (Server/Systems/Weather decides, everyone sees the same;
	-- Client/Controllers/WeatherController draws the rain, the flashes and the notice).
	-- Times are in seconds. NumberRange.new(a, b) = a random value between a and b.
	Weather = table.freeze({
		-- The first event comes this long after the server starts.
		FIRST_EVENT = NumberRange.new(180, 300),
		-- Calm gap after an event ends, before the next one may start.
		GAP = NumberRange.new(240, 420),
		-- When the dice say "nothing", try again this long after.
		RETRY = 45,
		-- Chances of each event (they don't need to add up to 100). Rain is likelier at
		-- night; a power cut only happens at night (and at most once per night).
		WEIGHTS_DAY = table.freeze({ Rain = 40, Fog = 30, Nothing = 30 }),
		-- (PowerCut = 0: no power cuts for now; put 25 back to have them.)
		WEIGHTS_NIGHT = table.freeze({ Rain = 55, Fog = 20, PowerCut = 0, Nothing = 15 }),

		-- RAIN: lasts 2 to 4 min. The rain grows for RAMP_IN, fades over RAMP_OUT.
		RAIN_DURATION = NumberRange.new(120, 240),
		RAIN_RAMP_IN = 25,
		RAIN_RAMP_OUT = 30,
		-- Part of the rains that are storms (with thunder).
		STORM_CHANCE = 0.5,
		-- Time between two thunder flashes in a THUNDERSTORM (frequent lightning).
		THUNDER_GAP = NumberRange.new(9, 24),
		-- Client: a thunderstorm's rain is this many times denser than a plain rain, and blown
		-- sideways by this wind (studs/s² added to the falling drops).
		STORM_RAIN_MULT = 1.8,
		STORM_WIND = Vector3.new(28, 0, 10),
		-- The rumble is heard this long after the flash (light is faster than sound).
		THUNDER_SOUND_DELAY = NumberRange.new(1.2, 4),

		-- FOG: dense haze (about 90 studs of visibility) for 2 to 3 min.
		FOG_DURATION = NumberRange.new(120, 180),
		FOG_RAMP = 25,

		-- POWER CUT (night only): the lights flicker, go dark, then come back as a wave
		-- from the substation, the sodium lamps warming up from red to orange.
		-- (3.5 s of stuttering lamps before the dark: the grid struggling, then the
		-- transformer at the substation blows in a burst of sparks, see WeatherFxController)
		POWER_FLICKER = 3.5,
		POWER_DARK = 40,
		POWER_WARMUP = 6,
		-- Not if the night ends in less than this (the dawn would come in the dark).
		POWER_MIN_NIGHT_LEFT = 75,
		-- In the compact city: the lot office, north edge of Lot 9 (the road is at Y 1.2).
		SUBSTATION = Vector3.new(60, 1.2, -116),
		-- Speed of the restore wave, in studs per second.
		POWER_WAVE_SPEED = 66,

		-- Client: the rain in the world (Client/Controllers/RainController, guide: docs/RAIN_FR.md).
		-- Three depth layers: NEAR (big, long streaks in cells around the camera), MID (finer
		-- streaks in a ring of bigger cells, up to ~105 studs) and FAR (rain curtains around the
		-- camera at ~150 studs, plus the server's haze). Rates are at full rain, top quality; low
		-- and medium graphics quality draw less (TIERS in RainController).
		RAIN = table.freeze({
			FALL_SPEED = 150, -- studs/s (real rain: about 9 m/s; 90-200 reads right on screen)
			TOP = 70, -- the drops are born this high above the camera
			NEAR_CELL = 14, -- side of a near cell (3 x 3 of them around the camera)
			MID_CELL = 42, -- side of a mid cell (5 x 5 of them, the middle one is the near cells)
			NEAR_RATE = 75, -- drops per second per near cell (at most 400 with a storm)
			MID_RATE = 150, -- drops per second per mid cell (at most 400 with a storm)
			NEAR_SIZE = NumberRange.new(0.2, 0.32), -- width of a near drop before the stretch
			MID_SIZE = NumberRange.new(0.11, 0.16),
			STRETCH = -3, -- ParticleEmitter.Squash (-3 = the longest streak along the fall)
			SPLASHES = 70, -- splashes per second on the ground around you
			SPLASH_RADIUS = 38, -- ...this far from the camera at most
			CURTAINS = 10, -- far rain curtains (needs RAIN_IMAGES.sheet)
			CURTAIN_RADIUS = 150, -- studs from the camera
			CURTAIN_SPEED = 1.6, -- how fast the curtain's texture falls (flip the sign if it rises)
		}),
		-- Pictures of the world rain, made by tools/rain/make_rain_textures.py into assets/rain/.
		-- Upload them (docs/RAIN_FR.md) and paste the IMAGE ids. 0 = not uploaded: the drop and
		-- the splash fall back to a built-in Roblox sparkle, the ripple to the built-in ring, and
		-- the far curtains are not drawn.
		RAIN_IMAGES = table.freeze({
			drop = 89305118963824, -- rain_drop.png (64 x 64)
			splash = 93651150767117, -- rain_splash.png (4 x 4 flipbook)
			ripple = 114893236357354, -- rain_ripple.png (4 x 4 flipbook)
			sheet = 134093860801729, -- rain_sheet.png (1024 x 256, the far curtains)
		}),
		-- The one-line notice top-left ("RAIN", "POWER CUT").
		NOTICE_TIME = 3,

		-- Client: water on the camera "lens" when you stand in the rain (Client/UI/LensRain).
		-- Pictures made by tools/raindrops/make_raindrop_textures.py, in assets/raindrops/.
		-- Upload them (guide: docs/RAIN_FR.md) and paste the IMAGE ids here. 0 = not uploaded.
		-- While `drops` has no id, NOTHING is drawn on the screen (the rest of the rain stays).
		SCREEN_RAIN_IMAGES = table.freeze({
			-- single drops: drop_round.png, drop_egg.png, drop_irregular.png
			drops = table.freeze({ 111660229759033, 71940132609064, 128041657038467 }),
			-- two / three drops that ran together: drop_merged_2.png, drop_merged_3.png
			merged = table.freeze({ 120208136091045, 123722258422810 }),
			-- a running drop and its wet trail: streak_1.png, streak_2.png, streak_3.png
			-- (keep them 128 x 512: the game shows only the bottom part of the trail)
			streaks = table.freeze({ 87263627117702, 136885468981190, 84830595394974 }),
			-- the fine spray at the screen edges in heavy rain: mist_1.png, mist_2.png
			mist = table.freeze({ 121407696421406, 82113857552482 }),
			-- a very faint wet smear at the edges: wet_glass.png
			wet = 72393032484221,
		}),

		-- Studio only: the first event comes after 20 s and the gaps are 45 s, to test.
		-- You can also force one: in the Studio command bar (server), type
		-- workspace:SetAttribute("WeatherForce", "Rain")   ("Rain", "Storm", "Fog", "PowerCut").
		STUDIO_FAST = true,
	}),

	-- The city's window glass (Server/Systems/CityGlass sets the material for everyone,
	-- Client/Controllers/GlassController adds the dirt, the rain on the glass and the
	-- low-quality fallback). Look taken from docs/references/video14.md: a clear face with a
	-- mirror sheen, darker edges, one highlight, light that goes through (no shadow).
	Glass = table.freeze({
		-- See-through panes (shop fronts, glass doors, transoms, phone box, skylight): the
		-- engine's Glass material, a very light green-grey (float glass), no shadow.
		CLEAR_COLOR = Color3.fromRGB(200, 214, 210),
		CLEAR_TRANSPARENCY = 0.62,
		CLEAR_REFLECTANCE = 0.18,
		-- The same panes on low graphics quality (Glass nearly vanishes there) and seen from
		-- inside a building (Roblox hides rain, beams and signs behind Glass on high quality).
		PLAIN_COLOR = Color3.fromRGB(56, 66, 70),
		PLAIN_TRANSPARENCY = 0.55,
		PLAIN_REFLECTANCE = 0.14,
		-- Panes with a wall right behind them (upper-floor windows, tower strips): opaque
		-- dark glass that mirrors the sky. Each pane's tint varies a little (old glass).
		DARK_REFLECTANCE = 0.32,
		DARK_TINT_SPREAD = 0.12,

		-- Pictures made by tools/glass/make_glass_textures.py, in assets/glass/. Upload them
		-- (guide: docs/GLASS_FR.md) and paste the IMAGE ids here. 0 = not uploaded: that
		-- layer is simply not drawn (the glass material itself still works).
		IMAGES = table.freeze({
			dirtWide = 134459334470369, -- glass_dirt_wide.png (shop fronts, transoms, strips)
			dirtTall = 106840351675381, -- glass_dirt_tall.png (windows, doors, phone box)
			rainBeads = 127340739642896, -- glass_rain_beads.png (drops sitting on the glass)
			rainRuns = 104057695886112, -- glass_rain_runs.png (drops running down)
		}),
		-- How see-through the dirt layer is (1 = invisible).
		DIRT_TRANSPARENCY = 0.3,
		-- Size of one tile of the rain pictures on the glass, in studs.
		BEADS_TILE = 3,
		RUNS_TILE = Vector2.new(4, 14),
		-- The running drops slide down this fast (studs/s); a thunderstorm × STORM_RUN.
		RUN_SPEED = 0.4,
		STORM_RUN = 1.6,
		-- 1 or -1: flip it if, in Studio, the running drops climb UP the glass.
		RUN_DIRECTION = 1,
		-- Seconds for a pane to get fully wet once it rains, and to dry once it stops.
		WET_TIME = 20,
		DRY_TIME = 25,
		-- Graphics tiers (Settings > Graphics quality 1-3 low, 4-7 / Automatic medium, 8-10
		-- high; phones and tablets capped at medium): panes that get rain on them (the nearest ones), within this many studs.
		RAIN_PANES = table.freeze({ low = 8, medium = 18, high = 32 }),
		RAIN_RANGE = table.freeze({ low = 30, medium = 50, high = 70 }),
		-- Panes that get the dirt layer, within this many studs (0 = none).
		DIRT_RANGE = table.freeze({ low = 0, medium = 90, high = 160 }),
		-- Broken glass (Server/Systems/Destruction → Client KitVFX): shards per broken piece,
		-- and how long they stay on the ground (s).
		SHARDS_PER_PIECE = 7,
		SHARD_LIFE = NumberRange.new(16, 22),
	}),

	-- The freight train that crosses the railway viaduct (Server/Systems/Train decides when,
	-- every client draws its own copy: Client/Controllers/TrainController). It comes out of a
	-- tunnel portal at one end of the viaduct and goes into the other one.
	-- Times in seconds, distances in studs.
	Train = table.freeze({
		-- The first train comes this long after the city is built.
		FIRST_PASS = NumberRange.new(40, 70),
		-- Time between the end of a pass and the start of the next one (+25 s since v7: the
		-- train came a bit too often).
		INTERVAL = NumberRange.new(95, 155),
		SPEED = 70, -- studs per second (crossing the ~250-stud viaduct takes about 4 s)
		-- Total length of the train: locomotive + 2 cars (must match the model the client
		-- builds in TrainController; it is published to the clients as TrainLength).
		LENGTH = 72,
		-- The train's box, for hits: half its width and its height above the rail top.
		HALF_WIDTH = 4.2,
		HEIGHT = 10,
		-- Signals blink, the horn sounds and the ground starts to rumble this long before
		-- the locomotive comes out of the tunnel.
		WARN_TIME = 5,

		-- Getting hit (once per pass, per fighter).
		DAMAGE = 60,
		KNOCKDOWN_TIME = 2.6, -- seconds on the ground (limp) after the hit
		-- The body is thrown: forward with the train (× the train's speed), sideways off the
		-- track and up.
		FLING_FORWARD = 0.7,
		FLING_SIDE = 55,
		FLING_UP = 38,
		-- The train ALWAYS kills (no knockdown, even with spawn protection; never in a duel or
		-- a finisher's cutscene) and tears the body apart: the head, arms and legs come off and
		-- fly with the train (× its speed for forward, plus a random spread and a lift).
		DISMEMBER_FORWARD = 0.9,
		DISMEMBER_SPREAD = 28,
		DISMEMBER_UP = 30,

		-- Client: camera rumble for players this close to the track (it grows as the train
		-- gets closer) and its strongest shake (1 = 0.1 stud).
		SHAKE_RANGE = 60,
		SHAKE_MAX = 2.2,

		-- Studio only: the first train comes after 15 s and then every 35 s, to test.
		-- You can also force one: in the Studio command bar (server), type
		-- workspace:SetAttribute("TrainForce", true)
		STUDIO_FAST = true,
	}),

	-- The hidden park (Shared/Util/SafeZone, Server/Systems/Combat): nobody fights there.
	Park = table.freeze({
		-- true = no punch, move, grab, throw or finisher starts in the park, and nobody
		-- standing in it can be hit (the train never goes there).
		SAFE_ZONE = true,
		-- The small caption shown when you walk in (Client/Controllers/SafeZoneController).
		CAPTION = "SAFE ZONE",
		CAPTION_SUB = "No fighting in the park",
	}),

	-- SpezCola machines (Server/Systems/SpezCola, Client/Controllers/SpezColaController):
	-- free, purely for fun. Take a can, it drops out of the tray, PICK IT UP (it goes in your
	-- pocket: one can at most, the machine refuses while you have one or while yours still
	-- lies on the floor) and drink it whenever you want with Controls.USE_ITEM (R).
	-- You keep it when knocked out or in a duel (no drinking there); it falls out when you die.
	Cola = table.freeze({
		COOLDOWN = 4, -- seconds between two cans for one player
		MAX_PER_MACHINE = 4, -- cans lying around one machine (the oldest goes first)
		MAX_TOTAL = 30, -- cans in the whole server
		CAN_LIFETIME = 90, -- seconds before a can nobody picked up disappears
		EMPTY_LIFETIME = 10, -- seconds an empty (crushed) can stays on the ground
		DISPENSE_DELAY = 0.55, -- seconds between the button and the can falling (the clunk)
		DRINK_TIME = 2.3, -- length of the "Emote_Drink" clip (Client/Animation/CombatClips)
		DRINK_SPEED = 0.7, -- walking speed × this while drinking
		PROMPT_DISTANCE = 8, -- studs (the machine's button)
		DRINK_DISTANCE = 6, -- studs (the "PICK UP" prompt of a can on the ground)
	}),
})
