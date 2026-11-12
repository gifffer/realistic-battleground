--!strict
-- Finishers: the cinematic kills of the kits (a KO'd opponent + M1).
--
--   "Bat"            Street Brawler: pulls a baseball bat from behind his
--                    back, rests it on his shoulder, raises it with both
--                    hands and brings it down on the head of the opponent
--                    lying on the ground (the skull is crushed).
--   "KnockoutCombo"  Boxer: hauls the opponent up by the collar, two hooks
--                    to the liver, hook, hook, cross, then crouches and
--                    lands a huge uppercut that sends them flying.
--
-- One timeline, read by the server (placement, the killing blow) and by
-- every client (camera, sounds, blood, the bat). Times in seconds from the
-- start. Positions are relative to the ANCHOR: the attacker's root part
-- during the finisher (X right, Y up, -Z = where he looks), feet on the
-- ground at Y = -3.

local Finishers = {}

export type Event = {
	time: number,
	-- "Prop" (the bat appears), "PropAway", "Swing" (whoosh), "Body" /
	-- "Face" (a punch lands), "Kill" (the killing blow)
	kind: string,
}

-- A camera shot: from `time` until the next shot (a cut between shots).
-- The camera goes from `from` to `to` (positions, anchor space) looking at
-- `look` (anchor space) or at the victim's head ("victim"), with this field
-- of view, smoothly (ease in-out) over the shot.
export type Shot = {
	time: number,
	from: Vector3,
	to: Vector3,
	look: Vector3 | "victim",
	fov: number,
}

export type Cinematic = {
	id: string,
	duration: number,
	kill: number, -- the killing blow (server)
	-- Where the attacker stands: "head" = beside the lying victim's head,
	-- facing it, HEAD_DISTANCE away; "front" = where he is, the victim
	-- pulled up in front of him at HOLD_DISTANCE, facing him.
	placement: "head" | "front",
	victimAnimation: string?, -- played on the victim (held up)
	events: { Event },
	shots: { Shot },
}

Finishers.HEAD_DISTANCE = 3.1 -- studs, attacker root → victim head (flat)
Finishers.HOLD_DISTANCE = 2.2 -- studs between the two roots (Boxer: within punching reach)

local cinematics: { [string]: Cinematic } = {
	Bat = {
		id = "Bat",
		duration = 3.3,
		kill = 1.7,
		placement = "head",
		events = {
			{ time = 0.35, kind = "Prop" },
			{ time = 1.5, kind = "Swing" },
			{ time = 1.7, kind = "Kill" },
			{ time = 3.1, kind = "PropAway" },
		},
		shots = {
			-- Behind his left shoulder: he draws the bat, looks down at them.
			{
				time = 0,
				from = Vector3.new(-2.6, 1.4, 3.6),
				to = Vector3.new(-2.1, 1.2, 2.8),
				look = Vector3.new(0, 0.6, -1.5),
				fov = 62,
			},
			-- From the ground, by the victim's head: he raises the bat.
			{
				time = 0.95,
				from = Vector3.new(2.6, -2.3, -4.6),
				to = Vector3.new(2.3, -2.4, -4.3),
				look = Vector3.new(0, 1.2, -0.6),
				fov = 58,
			},
			-- Close on the head as the bat comes down.
			{
				time = 1.55,
				from = Vector3.new(3.4, -1.6, -3.0),
				to = Vector3.new(3.0, -1.9, -3.1),
				look = Vector3.new(0, -2.5, -3.1),
				fov = 48,
			},
			-- Wide, turning slowly: the bat back on his shoulder.
			{
				time = 2.15,
				from = Vector3.new(5.5, 1.5, 1.5),
				to = Vector3.new(-1.5, 2.3, 4.6),
				look = Vector3.new(0, -0.8, -1.6),
				fov = 60,
			},
		},
	},
	KnockoutCombo = {
		id = "KnockoutCombo",
		duration = 3.4,
		kill = 2.42,
		placement = "front",
		victimAnimation = "Boxer_FinisherVictim",
		events = {
			{ time = 0.7, kind = "Body" },
			{ time = 0.95, kind = "Body" },
			{ time = 1.25, kind = "Face" },
			{ time = 1.55, kind = "Face" },
			{ time = 1.85, kind = "Face" },
			{ time = 2.3, kind = "Swing" },
			{ time = 2.42, kind = "Kill" },
		},
		shots = {
			-- Over his shoulder: he hauls them up.
			{
				time = 0,
				from = Vector3.new(2.2, 0.9, 3.4),
				to = Vector3.new(1.9, 0.8, 2.8),
				look = Vector3.new(0, 0.4, -2.6),
				fov = 60,
			},
			-- Side view: the body shots.
			{
				time = 0.55,
				from = Vector3.new(5.6, 0.3, -1.1),
				to = Vector3.new(5.0, 0.2, -1.3),
				look = Vector3.new(0, 0.1, -1.3),
				fov = 55,
			},
			-- Behind the victim, past their shoulder: the hooks to the face.
			{
				time = 1.1,
				from = Vector3.new(-2.4, 1.0, -5.4),
				to = Vector3.new(-2.0, 0.9, -5.0),
				look = Vector3.new(0, 0.6, -1.0),
				fov = 56,
			},
			-- Low, looking up: he crouches, the uppercut.
			{
				time = 1.98,
				from = Vector3.new(2.6, -2.2, -0.4),
				to = Vector3.new(2.3, -2.3, -0.6),
				look = Vector3.new(0, 1.0, -2.2),
				fov = 66,
			},
			-- Following the victim through the air.
			{
				time = 2.5,
				from = Vector3.new(4.5, 0.5, 1.5),
				to = Vector3.new(5.5, 1.5, -1.0),
				look = "victim",
				fov = 62,
			},
		},
	},
}

-- The cinematic of a finisher id, or nil (a plain finisher).
function Finishers.get(id: string?): Cinematic?
	return if id then cinematics[id] else nil
end

return table.freeze(Finishers)
