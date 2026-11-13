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
--   "Gore"           Bull: paws the floor, charges the opponent (stood up
--                    groggy a dozen studs away), rams his horns into their
--                    ribcage, carries them and leaps; in the air he tosses
--                    his head and the body tears in two at the waist: the
--                    top half flies on and lands further, the legs drop,
--                    the guts trail on the floor from one to the other.
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
	-- the victim laid on its back across in front of him (SIDE_VICTIM);
	-- "charge" = the victim stood up CHARGE.victim studs in front of him,
	-- facing him, a clear run between them (Finishers.CHARGE).
	placement: "head" | "front" | "side" | "charge",
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

-- "charge" (the Bull's "Gore"): his run, his leap and his landing.
--   victim   studs from the anchor to where the victim stands (facing him)
--   short    no room for the whole run: he starts this much closer (the
--            anchor stays where a full run would start, so the shots and
--            everything after the impact are the same)
--   ends     where his root is at the end (anchor space): the server puts
--            his (anchored) root there at the start; every client shows
--            his body along `path` meanwhile (CharacterAnimationController
--            .pinRoot), so where the root is never shows
--   path     where his body (his torso's centre) is, anchor space, over
--            time; `flat` = it stops there. The clip Bull_Finisher has a
--            keyframe at each of these times.
--   rip      the victim's root at the kill, in its own placed root's space
--            (the last keyframe of Bull_FinisherVictim): the server drops
--            the body from there, already torn
export type PathPoint = { time: number, at: Vector3, flat: boolean? }
Finishers.CHARGE = table.freeze({
	victim = 11,
	short = 4,
	ends = Vector3.new(0, 0, -15.5),
	path = table.freeze({
		{ time = 0, at = Vector3.new(0, 0, 0), flat = true },
		{ time = 0.25, at = Vector3.new(0, -0.2, 0.1) },
		{ time = 0.45, at = Vector3.new(0, -0.2, 0.1) },
		{ time = 0.6, at = Vector3.new(0, -0.45, 0.35), flat = true }, -- (weight back: off)
		{ time = 0.85, at = Vector3.new(0, -0.35, -4.3) },
		{ time = 1.1, at = Vector3.new(0, -0.45, -9.0) }, -- the horns go in
		{ time = 1.3, at = Vector3.new(0, -0.35, -10.6) },
		{ time = 1.45, at = Vector3.new(0, -0.75, -11.4) }, -- (crouched: the leap)
		{ time = 1.65, at = Vector3.new(0, 1.9, -12.7) },
		{ time = 1.85, at = Vector3.new(0, 2.8, -13.8) }, -- the toss
		{ time = 2.05, at = Vector3.new(0, 1.8, -14.9) },
		{ time = 2.25, at = Vector3.new(0, -0.8, -15.5), flat = true }, -- landed
		{ time = 2.55, at = Vector3.new(0, -0.15, -15.5) },
		{ time = 3.0, at = Vector3.new(0, -0.05, -15.5) },
		{ time = 4.4, at = Vector3.new(0, 0, -15.5), flat = true },
	} :: { PathPoint }),
	-- (on his horns over his head, thrown back, high in the air)
	rip = CFrame.new(0, 5.1, 4.4) * CFrame.Angles(math.rad(62), 0, 0),
	run = 0.6, -- (when he sets off, and when the horns go in: the short
	impact = 1.1, -- run is slower between the two)
})

-- Where the Bull's body is (anchor space) `time` seconds into "Gore", with
-- `short` studs less of a run (0 or CHARGE.short): a smooth spline through
-- CHARGE.path (like the clips': it passes through the points without
-- stopping, except at the flat ones).
function Finishers.chargeRoot(time: number, short: number): Vector3
	local path = Finishers.CHARGE.path
	local count = #path
	local t = math.clamp(time, 0, path[count].time)
	local from = 1
	for index = 1, count - 1 do
		if path[index + 1].time >= t then
			from = index
			break
		end
	end
	local to = math.min(from + 1, count)
	local function tangent(index: number): Vector3
		local point = path[index]
		if point.flat or index == 1 or index == count then
			return Vector3.zero
		end
		local before, after = path[index - 1], path[index + 1]
		return (after.at - before.at) / (after.time - before.time)
	end
	local a, b = path[from], path[to]
	local span = b.time - a.time
	local at: Vector3
	if span <= 0 then
		at = a.at
	else
		local u = (t - a.time) / span
		local u2, u3 = u * u, u * u * u
		at = a.at * (2 * u3 - 3 * u2 + 1)
			+ tangent(from) * ((u3 - 2 * u2 + u) * span)
			+ b.at * (-2 * u3 + 3 * u2)
			+ tangent(to) * ((u3 - u2) * span)
	end
	if short > 0 then
		-- (he starts closer: the run itself is shorter, the rest the same;
		-- eased, so his speed doesn't jump as he sets off or at the impact)
		local C = Finishers.CHARGE
		local u = math.clamp((C.impact - t) / (C.impact - C.run), 0, 1)
		local share = u * u * (3 - 2 * u)
		at += Vector3.new(0, 0, -short * share)
	end
	return at
end

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
-- Bull: "Gore" - a charge, the horns into the ribcage, a leap, torn in two
-- in the air (see the top of the file).
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
	kill = 1.85,
	placement = "charge",
	victimAnimation = "Bull_FinisherVictim",
	events = {
		{ time = 0.05, kind = "Snort" },
		{ time = 0.25, kind = "Scrape" }, -- a hoof scrapes the floor
		{ time = 0.45, kind = "Scrape" },
		{ time = 0.6, kind = "Rush" }, -- he charges at them
		{ time = 1.1, kind = "Impact" }, -- the horns into the ribcage
		{ time = 1.45, kind = "Jump" }, -- he leaps, them on his horns
		{ time = 1.85, kind = "Rip" }, -- tossed: torn in two at the waist (the kill)
		{ time = 2.25, kind = "Land" },
		{ time = 3.3, kind = "Huff" }, -- snorts over what's left
		{ time = 3.95, kind = "Scrape" },
	},
	-- (his run: Finishers.CHARGE; they stand at (0, 0, -11), the top half
	-- lands around (0, -2.5, -21), the legs around (0, -2.5, -13), he lands
	-- between them at (0, 0, -15.5))
	shots = {
		-- Low behind him, past his shoulder, down the way he'll run: he
		-- snorts, paws the floor; them, groggy, at the end of it.
		{
			time = 0,
			from = Vector3.new(2.0, -1.6, 4.4),
			to = Vector3.new(1.7, -1.8, 3.8),
			look = Vector3.new(0, -0.6, -9),
			fov = 50,
		},
		-- Low, by them, looking back at him: head down, a hoof scraping.
		{
			time = 0.4,
			from = Vector3.new(-2.6, -2.3, -8.2),
			to = Vector3.new(-2.4, -2.4, -7.8),
			look = Vector3.new(0, -1.2, -1.2),
			fov = 46,
		},
		-- Low alongside the charge, toward them.
		{
			time = 0.62,
			from = Vector3.new(5.0, -1.9, -2.0),
			to = Vector3.new(4.2, -2.0, -7.2),
			look = Vector3.new(0, -0.6, -9.5),
			fov = 58,
		},
		-- Close from the side: the horns into the ribcage, folded over his
		-- head, carried.
		{
			time = 1.08,
			from = Vector3.new(3.0, -0.9, -9.6),
			to = Vector3.new(2.7, -0.6, -10.6),
			look = Vector3.new(0, 0.2, -10.8),
			fov = 44,
		},
		-- Wide, in profile: the leap, the toss, the body torn in two in the
		-- air, the top flying on, the legs dropping, him landing.
		{
			time = 1.42,
			from = Vector3.new(8.5, -1.2, -12.0),
			to = Vector3.new(8.2, -1.0, -13.0),
			look = Vector3.new(0, 1.6, -14.8),
			fov = 60,
		},
		-- On the floor by the legs: the guts trailing away from them, under
		-- him, to the top half further on.
		{
			time = 2.35,
			from = Vector3.new(-1.8, -2.6, -10.8),
			to = Vector3.new(-1.6, -2.55, -11.6),
			look = Vector3.new(0.2, -2.3, -19),
			fov = 52,
		},
		-- Behind his right shoulder: snorting over it.
		{
			time = 3.2,
			from = Vector3.new(4.5, 1.5, -11.8),
			to = Vector3.new(4.9, 2.2, -11.0),
			look = Vector3.new(0, -1.8, -17.5),
			fov = 58,
		},
		-- Wide from above: all of it.
		{
			time = 3.8,
			from = Vector3.new(6.5, 5.5, -22),
			to = Vector3.new(7.5, 7, -20),
			look = Vector3.new(0, -2.6, -16.5),
			fov = 60,
		},
	},
}

-- The cinematic of a finisher id, or nil (a plain finisher).
function Finishers.get(id: string?): Cinematic?
	return if id then cinematics[id] else nil
end

return table.freeze(Finishers)
