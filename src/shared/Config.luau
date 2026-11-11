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
		WALK_SPEED = 16, -- studs per second (Roblox default)
		SPRINT_SPEED = 24,
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
		HEAD_EXTRA_STUN = 0.15, -- seconds added to the stun of a head hit
		LEG_HIT_SLOW = 0.8, -- speed multiplier after a leg hit...
		LEG_HIT_SLOW_TIME = 1.5, -- ...for this long

		-- Studio only: shows hitboxes as red boxes, to check they're right.
		DEBUG_HITBOXES = true,
		-- Spawns training dummies near the spawn point (one passive, one that
		-- attacks you, to practice blocking and parrying).
		TRAINING_DUMMIES = true,
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
