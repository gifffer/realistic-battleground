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
		-- Attack = left mouse button (hold to keep attacking).
		BLOCK = Enum.KeyCode.F, -- hold; press right before a hit = parry
		DASH = Enum.KeyCode.Q,
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

		-- Studio only: shows hitboxes as red boxes, to check they're right.
		DEBUG_HITBOXES = true,
		-- Spawns training dummies near the spawn point (one passive, one that
		-- attacks you, to practice blocking and parrying).
		TRAINING_DUMMIES = true,
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
	}),
})
