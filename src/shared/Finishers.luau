--!strict
-- Finishers: the cinematic kills of the kits (a KO'd opponent + M1).
--
--   "Bat"            Street Brawler: pulls a baseball bat from behind his
--                    back straight into a big golf swing: up over his right
--                    shoulder, then swept low across the head of the
--                    opponent lying on the ground, from his right to his
--                    left: the head bursts.
--   "Incinerate"     Sentinel: lifted by the throat, his heat vision point
--                    blank into the heart: a deep hole burnt in the chest
--                    (no blood: cauterized), smoking; thrown down.
--   "Gore"           Bull: gored, lifted on the horns, shaken, slammed down.
--   "KnockoutCombo"  Boxer: hauls the opponent up by the collar, two hooks
--                    to the body, hook, hook, cross, then a left hook into
--                    their right side under the ribs: the hand goes in and
--                    tears the liver out; he looks at it, lets it drop.
--   "ArmRip"         Bouncer: the opponent laid on their back across in
--                    front of him; he takes their right wrist in both hands,
--                    puts his foot on their chest and pulls, three times:
--                    the shoulder gives, the arm comes off. He holds it up,
--                    looks at it, throws it down by the body.
--
-- One timeline, read by the server (placement, the killing blow) and by
-- every client (camera, sounds, blood, the bat). Times in seconds from the
-- start. Positions are relative to the ANCHOR: the attacker's root part
-- during the finisher (X right, Y up, -Z = where he looks), feet on the
-- ground at Y = -3.

local Finishers = {}

export type Event = {
	time: number,
	-- "Prop" (the bat appears), "PropAway", "Plea" (the victim speaks),
	-- "Swing" (whoosh), "Body" / "Face" (a punch lands), "Kill" (the
	-- killing blow), "Gut" / "Dig" / "Rip" / "Drop" (the liver: the hand
	-- goes in, digs, tears it out, throws it down)
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
	-- ("heart": the Sentinel's bore on the victim's chest, Shared/Util/Gash)
	look: Vector3 | "victim" | "heart",
	fov: number,
}

export type Cinematic = {
	id: string,
	duration: number,
	kill: number, -- the killing blow (server)
	-- Where the attacker stands: "head" = past the lying victim's head
	-- (the body beyond it), facing it, HEAD_DISTANCE away; "front" = where he is, the victim
	-- pulled up in front of him at HOLD_DISTANCE, facing him; "side" = by
	-- the victim laid on its back across in front of him (SIDE_VICTIM).
	placement: "head" | "front" | "side",
	victimAnimation: string?, -- played on the victim (held up / laid out)
	events: { Event },
	shots: { Shot },
}

Finishers.HEAD_DISTANCE = 3.8 -- studs, attacker root → victim head (flat): under the barrel
-- Incinerate: on the victim when it died, the server time when the beam
-- stopped (the hole smoking and cooling down from then: Client/Combat/KitVFX,
-- also on a body seen later).
Finishers.BORED_ATTRIBUTE = "HeartBored"
Finishers.HOLD_DISTANCE = 2.2 -- studs between the two roots (Boxer: within punching reach)
-- "side": where the victim's root is laid (anchor space): on its back, its
-- head to his left, its right side (the arm he pulls) toward him.
Finishers.SIDE_VICTIM = CFrame.new(0.3, -2.5, -2.7, 0, -1, 0, 0, 0, -1, 1, 0, 0)
-- ArmRip: the torn arm in his right fist (his Right Arm's space), and where
-- it is (anchor space) when he throws it. Measured on the two clips
-- (Client/Animation/BouncerClips): change them together.
Finishers.ARM_GRIP = CFrame.new(
	0.7757,
	-1.1319,
	0.1752,
	-0.1069,
	0.9447,
	0.3101,
	0.3554,
	-0.255,
	0.8992,
	0.9286,
	0.2064,
	-0.3085
)
Finishers.ARM_THROW_FROM = CFrame.new(
	2.4602,
	-0.2834,
	-1.8162,
	-0.104,
	0.9834,
	0.1484,
	-0.7243,
	-0.1772,
	0.6663,
	0.6816,
	-0.0382,
	0.7308
)
Finishers.ARM_THROW_VELOCITY = Vector3.new(3, -2, -1) -- anchor space, studs/s

local cinematics: { [string]: Cinematic } = {
	Bat = {
		id = "Bat",
		duration = 3.3,
		kill = 1.7,
		placement = "head",
		victimAnimation = "Brawler_FinisherBatVictim",
		events = {
			{ time = 0.35, kind = "Prop" },
			{ time = 0.55, kind = "Plea" },
			{ time = 1.45, kind = "Swing" },
			{ time = 1.7, kind = "Kill" },
			{ time = 3.1, kind = "PropAway" },
		},
		-- (the server lays the victim out along -Z, face up: its head at
		-- (0, -2.45, -HEAD_DISTANCE),
		-- its body beyond)
		shots = {
			-- From the side, wide: the body on the ground, him drawing the bat.
			{
				time = 0,
				from = Vector3.new(5.6, -0.6, -3.4),
				to = Vector3.new(4.9, -0.9, -2.9),
				look = Vector3.new(0, -1.3, -3.4),
				fov = 62,
			},
			-- Close on the face of the one on the ground (they plead): from its
			-- left, its raised right hand reaching out in the back of the shot.
			{
				time = 0.55,
				from = Vector3.new(-1.9, -1.1, -5.4),
				to = Vector3.new(-1.6, -1.3, -5.1),
				look = "victim",
				fov = 50,
			},
			-- From the ground, by the head: he raises the bat over it.
			{
				time = 0.95,
				from = Vector3.new(-2.4, -2.4, -5.7),
				to = Vector3.new(-2.1, -2.5, -5.3),
				look = Vector3.new(0, 1.0, -0.8),
				fov = 58,
			},
			-- From the side, low, on the head as the bat comes down: it
			-- bursts; held a while to see it (the spray, the pieces, the neck).
			{
				time = 1.5,
				from = Vector3.new(-3.6, -1.4, -4.4),
				to = Vector3.new(-3.1, -1.7, -4.9),
				look = Vector3.new(0, -2.5, -4.2),
				fov = 56,
			},
			-- Wide, slowly turning: what's left, him with the bat.
			{
				time = 2.45,
				from = Vector3.new(5.2, 0.6, -6.6),
				to = Vector3.new(5.6, 1.2, -2.0),
				look = Vector3.new(0, -1.5, -3.2),
				fov = 60,
			},
		},
	},
	KnockoutCombo = {
		id = "KnockoutCombo",
		duration = 4.1,
		kill = 2.62,
		placement = "front",
		victimAnimation = "Boxer_FinisherVictim",
		events = {
			{ time = 0.7, kind = "Body" },
			{ time = 0.95, kind = "Body" },
			{ time = 1.25, kind = "Face" },
			{ time = 1.55, kind = "Face" },
			{ time = 1.85, kind = "Face" },
			{ time = 2.12, kind = "Swing" },
			{ time = 2.25, kind = "Gut" }, -- the hand goes in under the ribs
			{ time = 2.42, kind = "Dig" },
			{ time = 2.62, kind = "Rip" }, -- the liver torn out, in his hand
			{ time = 3.55, kind = "Drop" }, -- he lets go: it drops to the floor
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
			-- Behind his left side, low: past him, the fist going into their right
			-- side under the ribs (nothing in between: checked on the poses).
			{
				time = 1.98,
				from = Vector3.new(-2.9, -0.3, 0.35),
				to = Vector3.new(-2.6, -0.45, 0.05),
				look = Vector3.new(-0.52, -0.95, -2.0),
				fov = 50,
			},
			-- From his left, low: the arm pulls out, the liver in the fist.
			{
				time = 2.55,
				from = Vector3.new(-4.1, -1.15, -0.6),
				to = Vector3.new(-3.8, -1.0, -0.85),
				look = Vector3.new(-1.1, -0.5, -1.4),
				fov = 55,
			},
			-- In front of it: he holds it out at arm's length and looks at it.
			{
				time = 2.85,
				from = Vector3.new(-1.5, 1.15, -3.7),
				to = Vector3.new(-1.45, 1.05, -3.4),
				look = Vector3.new(-1.4, 0.4, -1.12),
				fov = 45,
			},
			-- Low, from his left: the liver drops from his hand to the floor.
			{
				time = 3.45,
				from = Vector3.new(-3.7, -1.2, -3.3),
				to = Vector3.new(-3.5, -1.35, -3.0),
				look = Vector3.new(-1.4, -1.15, -1.2),
				fov = 58,
			},
			-- Wide: the body on the floor, the liver by it.
			{
				time = 3.95,
				from = Vector3.new(4.6, 1.0, -4.6),
				to = Vector3.new(5.2, 1.4, -2.2),
				look = Vector3.new(-0.3, -1.3, -1.9),
				fov = 60,
			},
		},
	},
	ArmRip = {
		id = "ArmRip",
		duration = 4.6,
		kill = 2.35,
		placement = "side",
		victimAnimation = "Bouncer_FinisherArmRipVictim",
		events = {
			{ time = 0.3, kind = "Grab" }, -- both hands on their right wrist
			{ time = 0.55, kind = "Plea" },
			{ time = 0.95, kind = "Stomp" }, -- his foot on their chest
			{ time = 1.2, kind = "Strain" },
			{ time = 1.55, kind = "Strain" },
			{ time = 1.62, kind = "Pop" }, -- the shoulder comes out
			{ time = 1.9, kind = "Strain" },
			{ time = 2.35, kind = "Tear" }, -- off (the kill)
			{ time = 3.62, kind = "Throw" }, -- thrown down by the body
		},
		-- (the victim lies along X in front of him, its head to his left at
		-- (-1.2, -2.5, -2.7), its right shoulder at about (-0.2, -2, -1.7))
		shots = {
			-- Wide and low, from beyond their feet: he bends down, takes the wrist.
			{
				time = 0,
				from = Vector3.new(4.8, -0.6, -4.6),
				to = Vector3.new(4.4, -0.8, -4.2),
				look = Vector3.new(0, -1.2, -1.6),
				fov = 60,
			},
			-- Close on their face, from the far side: they plead.
			{
				time = 0.55,
				from = Vector3.new(-2.0, -1.3, -4.4),
				to = Vector3.new(-1.8, -1.4, -4.1),
				look = "victim",
				fov = 48,
			},
			-- Low, from his left: the foot on the chest, the arm pulled tight.
			{
				time = 0.95,
				from = Vector3.new(-3.4, -1.6, -0.4),
				to = Vector3.new(-3.2, -1.5, -0.7),
				look = Vector3.new(0, -1.4, -1.4),
				fov = 55,
			},
			-- Across their shoulder, from the far side: it stretches, his face
			-- beyond, straining.
			{
				time = 1.5,
				from = Vector3.new(-1.8, -1.2, -3.6),
				to = Vector3.new(-1.5, -1.3, -3.3),
				look = Vector3.new(-0.2, -1.6, -1.5),
				fov = 46,
			},
			-- Wider, low, from his left: it comes off, he staggers back.
			{
				time = 2.2,
				from = Vector3.new(-3.8, -1.0, 0.8),
				to = Vector3.new(-4.2, -0.8, 1.2),
				look = Vector3.new(-0.2, -1.3, -1.2),
				fov = 58,
			},
			-- From low in front of him: he holds it up and looks at it.
			{
				time = 2.75,
				from = Vector3.new(2.2, -0.8, -3.4),
				to = Vector3.new(2.0, -0.6, -3.1),
				look = Vector3.new(0.9, 1.8, -0.5),
				fov = 52,
			},
			-- Wide, from above: thrown down by the body.
			{
				time = 3.55,
				from = Vector3.new(5.2, 1.6, -5.4),
				to = Vector3.new(5.6, 2.0, -3.4),
				look = Vector3.new(0.6, -2.2, -2.0),
				fov = 60,
			},
		},
	},
}

-- Sentinel: "Incinerate" - he takes them by the throat and lifts them off
-- their feet, his eyes charge, he looks down and burns straight into their
-- heart, point blank: a deep hole in the chest, so hot nothing bleeds (the
-- server's "Bore" cut, drawn by Gashes: the ribs cut, the lung, the heart
-- burnt through). The beam stops, the hole glows and smokes; he throws the
-- body down on its back and the camera closes in on the smoking hole.
-- Bull: "Gore" - horns into the belly, lifted up on them, shaken like a
-- rag, slammed down into the floor.
cinematics.Incinerate = {
	id = "Incinerate",
	duration = 5.6,
	kill = 4.05, -- (on its back on the floor: KILL_POSE)
	placement = "front",
	victimAnimation = "Sentinel_FinisherVictim",
	events = {
		{ time = 0.3, kind = "Grab" }, -- the hand on the throat
		{ time = 0.6, kind = "Lift" }, -- off their feet, choking
		{ time = 0.9, kind = "Charge" }, -- the eyes charge (his head goes down)
		{ time = 1.4, kind = "Beam" }, -- both beams into the heart
		{ time = 2.1, kind = "Ribs" }, -- through the ribs (the bore: M)
		{ time = 2.5, kind = "Heart" }, -- through the heart (the bore: L)
		{ time = 2.9, kind = "Burnt" }, -- the beam stops
		{ time = 3.4, kind = "Toss" }, -- thrown down
		{ time = 3.85, kind = "Thud" }, -- on its back on the floor
	},
	shots = {
		-- Over his right shoulder: he takes them by the throat.
		{
			time = 0,
			from = Vector3.new(2.2, 1.3, 3.0),
			to = Vector3.new(1.8, 1.1, 2.4),
			look = Vector3.new(0.4, 0.9, -2.0),
			fov = 58,
		},
		-- Low, from the side: lifted off their feet, the legs dangling.
		{
			time = 0.6,
			from = Vector3.new(4.4, -1.8, -0.6),
			to = Vector3.new(4.0, -1.9, -0.9),
			look = Vector3.new(0.5, 0.6, -1.5),
			fov = 55,
		},
		-- Close on his eyes, charging; his head goes down.
		{
			time = 0.9,
			from = Vector3.new(-1.7, 1.5, -1.1),
			to = Vector3.new(-1.45, 1.42, -0.95),
			look = Vector3.new(0.05, 1.35, -0.3),
			fov = 40,
		},
		-- Profile, a little above: both beams down into the chest.
		{
			time = 1.4,
			from = Vector3.new(3.8, 2.0, -0.5),
			to = Vector3.new(3.5, 1.85, -0.7),
			look = Vector3.new(0.6, 1.0, -1.0),
			fov = 50,
		},
		-- Close on the chest, between them: it burns in.
		{
			time = 1.9,
			from = Vector3.new(1.9, 0.55, -0.35),
			to = Vector3.new(1.65, 0.6, -0.45),
			look = "heart",
			fov = 42,
		},
		-- His view, high over his right shoulder: down the beams into the hole.
		{
			time = 2.45,
			from = Vector3.new(1.25, 3.0, 0.6),
			to = Vector3.new(1.1, 2.7, 0.35),
			look = "heart",
			fov = 45,
		},
		-- The beam stops: the hole glowing, smoking.
		{
			time = 2.9,
			from = Vector3.new(2.2, 0.4, -0.1),
			to = Vector3.new(2.0, 0.5, -0.3),
			look = "heart",
			fov = 38,
		},
		-- Wide: thrown down on its back.
		{
			time = 3.4,
			from = Vector3.new(5.5, 1.2, -1.5),
			to = Vector3.new(5.8, 1.6, -2.2),
			look = Vector3.new(0.4, -1.4, -2.8),
			fov = 62,
		},
		-- Slowly down onto the hole, still smoking, him standing beyond.
		{
			time = 4.0,
			from = Vector3.new(2.0, 0.7, -2.5),
			to = Vector3.new(1.05, -0.95, -3.7),
			look = "heart",
			fov = 48,
		},
	},
}
cinematics.Gore = {
	id = "Gore",
	duration = 4.4,
	kill = 3.4,
	placement = "front",
	victimAnimation = "Bull_FinisherVictim",
	events = {
		{ time = 0.1, kind = "Snort" },
		{ time = 0.7, kind = "Gore" }, -- the horns go in
		{ time = 1.65, kind = "Shake" },
		{ time = 1.9, kind = "Shake" },
		{ time = 2.15, kind = "Shake" },
		{ time = 2.4, kind = "Shake" },
		{ time = 3.4, kind = "Slam" }, -- slammed into the floor
		{ time = 3.9, kind = "Stomp" },
	},
	shots = {
		-- Low, three-quarter: he paws the floor, head down.
		{
			time = 0,
			from = Vector3.new(4.2, -0.8, -3.6),
			to = Vector3.new(3.9, -0.9, -3.0),
			look = Vector3.new(0, -0.3, -1),
			fov = 58,
		},
		-- From the side: the horns go in.
		{
			time = 0.6,
			from = Vector3.new(5.2, 0.2, -1.2),
			to = Vector3.new(4.8, 0, -1.2),
			look = Vector3.new(0, 0, -1.3),
			fov = 52,
		},
		-- From the floor, looking up: lifted up on the horns.
		{
			time = 1.15,
			from = Vector3.new(3.4, -2.0, 1.6),
			to = Vector3.new(3.0, -2.2, 1.3),
			look = Vector3.new(0, 2, -1.4),
			fov = 60,
		},
		-- In front: shaken like a rag, blood flying.
		{
			time = 1.6,
			from = Vector3.new(0.5, 1.2, -6.5),
			to = Vector3.new(0.3, 1.0, -6.0),
			look = Vector3.new(0, 1.5, -1.5),
			fov = 62,
		},
		-- Wide from the side: slammed down.
		{
			time = 2.75,
			from = Vector3.new(6.5, 1.0, -1.5),
			to = Vector3.new(6, 0.4, -1.6),
			look = Vector3.new(0, -1.2, -2),
			fov = 60,
		},
		-- From above: the body in the cracked floor, him over it.
		{
			time = 3.5,
			from = Vector3.new(3.5, 4.5, -5.5),
			to = Vector3.new(3.8, 5, -4.5),
			look = Vector3.new(0, -2.5, -2.2),
			fov = 60,
		},
	},
}

-- The cinematic of a finisher id, or nil (a plain finisher).
function Finishers.get(id: string?): Cinematic?
	return if id then cinematics[id] else nil
end

return table.freeze(Finishers)
