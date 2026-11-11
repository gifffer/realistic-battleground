--!strict
-- Tunable values of the game. NOTE: replicated to clients — nothing secret here,
-- and the server never trusts a value reported by a client.
--
-- Tip: to balance the game (faster sprint, more stamina...), change the numbers
-- here and nowhere else.

return table.freeze({
	GAME_TITLE = "Realistic Battleground",
	VERSION = "v0.0.2 PRE-ALPHA",

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
