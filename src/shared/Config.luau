--!strict
-- Tunable values of the game. NOTE: replicated to clients — nothing secret here,
-- and the server never trusts a value reported by a client.

return table.freeze({
	GAME_TITLE = "Realistic Battleground",
	VERSION = "v0.0.1 PRE-ALPHA",

	-- Seconds between two background saves of a player's profile.
	AUTOSAVE_INTERVAL = 60,

	-- Walking speeds, in studs per second (Roblox default walk = 16).
	-- Slower than default on purpose: heavier, more "realistic" movement.
	MOVEMENT = table.freeze({
		WALK_SPEED = 12,
		SPRINT_SPEED = 21,
		CROUCH_SPEED = 6,

		-- Sprinting costs this much stamina per second (only while actually moving).
		SPRINT_DRAIN_PER_SECOND = 14,
		-- Under this horizontal speed (studs/s) the server considers you "standing still".
		MOVING_SPEED_THRESHOLD = 2,
	}),

	-- Stamina is shared by every action that tires you out
	-- (sprint now; dash, block and attacks later).
	STAMINA = table.freeze({
		MAX = 100,
		REGEN_PER_SECOND = 22,
		-- Seconds without spending stamina before it starts coming back.
		REGEN_DELAY = 1.2,
		-- Once you hit 0 you are "exhausted": no sprint until stamina is back to this value.
		RECOVER_THRESHOLD = 30,
	}),

	CAMERA = table.freeze({
		-- Mouse wheel zoom range. Zooming all the way in = first person.
		MIN_ZOOM = 0.5,
		MAX_ZOOM = 14,
		DEFAULT_ZOOM = 9,

		-- Over-the-shoulder offset when shift-lock is on (right, up), in studs.
		SHOULDER_OFFSET = Vector3.new(1.75, 0.4, 0),
		-- How far the camera goes down when crouching.
		CROUCH_DROP = 1.3,
		-- First person: push the camera slightly forward so the torso doesn't block the view.
		FIRST_PERSON_FORWARD = 0.45,
		-- First person: show your own arms and legs ("true first person").
		FIRST_PERSON_SHOW_BODY = true,

		BASE_FOV = 70,
		SPRINT_FOV = 78,
		-- Smoothing speed of the offset / FOV transitions (higher = snappier).
		SMOOTHING = 10,
	}),
})
