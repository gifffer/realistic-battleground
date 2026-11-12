--!strict
-- The Bouncer's animations (Shared/Kits/Bouncer), made in code like the others
-- (read the top of CombatClips and MovementClips). Merged into CombatClips.
--
-- How they were made: like motion capture of two bodies. For each keyframe the
-- torsos were placed in space first (the victim lifted across his chest, on
-- his shoulders, slammed down...), the standing feet planted on the floor,
-- then every hand solved onto what it holds: a point of the other body it
-- can really reach (a thigh, the small of the back, a forearm across a
-- throat) without the arm going through that body. Checked on rendered frames
-- (Blender, several camera angles) with the same spline as the game.
--
-- Timing that must not change (Shared/Kits/Bouncer, Shared/Finishers):
--   • Bouncer_Shove: the palms land at 0.22 s; Bouncer_HammerFist at 0.4 s;
--     Bouncer_DoubleHammer at 0.4 and 0.95 s; Bouncer_Grab closes at 0.28 s.
--   • The holds (Bouncer_Choke / Sleeper / Slam / ThrowOut and their *Victim
--     clips) start at the catch and last the grab's `duration`. The victim's
--     root stays where it was caught (anchored, Server/Combat/Grab): its clip
--     moves its body (lifted, slammed). Bouncer_SlamVictim and
--     Bouncer_PowerbombVictim end on its back exactly where the server lays
--     it when it lets go (GrabDef.laidAt in Shared/Kits/Bouncer).
--   • Bouncer_FinisherArmRip / ...Victim (Shared/Finishers "ArmRip"): the
--     victim laid across in front of him; the arm comes off at 2.35 s and is
--     then held in his right fist (Finishers.ARM_GRIP was measured on these
--     two clips at that moment), thrown at 3.62 s (Finishers.ARM_THROW_FROM).
--     Change them together.
--   • Weapon_Swing1 / 2 / 3: the M1 with a weapon in hand (Shared/Weapons,
--     CharacterAnimationController plays them in place of the punches): the
--     blow lands at 0.15 s like a punch (Config.Combat.HIT_DELAY). Solved
--     with the bone's grip in WeaponFx (GRIP).

local R6Pose = require(script.Parent.R6Pose)

local clips: { [string]: R6Pose.Clip } = {
	Bouncer_Shove = {
		length = 0.65,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(4.02, -5.99, 0.42),
						pos = Vector3.new(0, -0.25, 0.25),
					},
					Neck = { rot = Vector3.new(4, 4, 0) },
					RightShoulder = { rot = Vector3.new(81.8, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(81.4, 0, 31) },
					RightHip = { rot = Vector3.new(-9.3, 0, 3.3), pos = Vector3.new(0, 0.265, 0) },
					LeftHip = { rot = Vector3.new(-1.6, 0, -3.3), pos = Vector3.new(0, 0.272, 0) },
				},
			},
			{
				time = 0.22,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-20, 0, 0), pos = Vector3.new(0, -0.4, -0.55) },
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(116.3, 0, -33.8) },
					LeftShoulder = { rot = Vector3.new(116.3, 0, 33.8) },
					RightHip = { rot = Vector3.new(-9.5, 0, 2.8), pos = Vector3.new(0, 0.107, 0) },
					LeftHip = { rot = Vector3.new(42.2, 0, -2.8), pos = Vector3.new(0, 0.225, 0) },
				},
			},
			{
				time = 0.34,
				pose = {
					Root = { rot = Vector3.new(-17, 0, 0), pos = Vector3.new(0, -0.35, -0.5) },
					Neck = { rot = Vector3.new(12, 0, 0) },
					RightShoulder = { rot = Vector3.new(114.9, 0, -32.3) },
					LeftShoulder = { rot = Vector3.new(114.9, 0, 32.3) },
					RightHip = { rot = Vector3.new(-12, 0, 2.8), pos = Vector3.new(0, 0.078, 0) },
					LeftHip = { rot = Vector3.new(40, 0, -2.8), pos = Vector3.new(0, 0.175, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-8.04, -5.94, -0.84),
						pos = Vector3.new(0, -0.2, -0.2),
					},
					Neck = { rot = Vector3.new(8, 6, 0) },
					RightShoulder = { rot = Vector3.new(111.2, 0, -36.7) },
					LeftShoulder = { rot = Vector3.new(115.5, 0, 37.2) },
					RightHip = { rot = Vector3.new(-3.9, 0, 4.5), pos = Vector3.new(0, 0.181, 0) },
					LeftHip = { rot = Vector3.new(20.8, 0, -3.9), pos = Vector3.new(0, 0.171, 0) },
				},
			},
			{
				time = 0.65,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},
	Bouncer_Grab = {
		length = 0.7,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-10, 0, 0), pos = Vector3.new(0, -0.3, 0.05) },
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(123.6, 0, 5) },
					LeftShoulder = { rot = Vector3.new(123.6, 0, -5) },
					RightHip = { rot = Vector3.new(7.7, 0, 2.8), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(20.7, 0, -2.8), pos = Vector3.new(0, 0.276, 0) },
				},
			},
			{
				time = 0.28,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-20, 0, 0), pos = Vector3.new(0, -0.4, -0.5) },
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(137.1, 0, -38.7) },
					LeftShoulder = { rot = Vector3.new(137.1, 0, 38.7) },
					RightHip = { rot = Vector3.new(-4.1, 0, 2.8), pos = Vector3.new(0, 0.198, 0) },
					LeftHip = { rot = Vector3.new(40.5, 0, -2.8), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = {
						rot = Vector3.new(-12.03, -3.91, -0.83),
						pos = Vector3.new(0, -0.3, -0.3),
					},
					Neck = { rot = Vector3.new(8, 4, 0) },
					RightShoulder = { rot = Vector3.new(120.4, 0, -39.1) },
					LeftShoulder = { rot = Vector3.new(122.1, 0, 35.2) },
					RightHip = { rot = Vector3.new(-3.7, 0, 4.3), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(26.7, 0, -3.6), pos = Vector3.new(0, 0.245, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},
	Bouncer_HammerFist = {
		length = 0.85,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, 0.1, 0.25) },
					Neck = { rot = Vector3.new(-12, 0, 0) },
					RightShoulder = { rot = Vector3.new(164.1, 0, -43.8) },
					LeftShoulder = { rot = Vector3.new(164.1, 0, 43.8) },
					RightHip = { rot = Vector3.new(-11.5, 0, 3.3) },
					LeftHip = { rot = Vector3.new(7.2, 0, -3.6) },
				},
			},
			{
				time = 0.4,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-30, 0, 0), pos = Vector3.new(0, -0.6, -0.6) },
					Neck = { rot = Vector3.new(22, 0, 0) },
					RightShoulder = { rot = Vector3.new(172.5, 0, -42.8) },
					LeftShoulder = { rot = Vector3.new(172.5, 0, 42.8) },
					RightHip = { rot = Vector3.new(3.3, 0, 2.8), pos = Vector3.new(0, 0.315, 0) },
					LeftHip = { rot = Vector3.new(51.8, 0, -2.8), pos = Vector3.new(0, 0.397, 0) },
				},
			},
			{
				time = 0.52,
				pose = {
					Root = { rot = Vector3.new(-36, 0, 0), pos = Vector3.new(0, -0.7, -0.6) },
					Neck = { rot = Vector3.new(26, 0, 0) },
					RightShoulder = { rot = Vector3.new(147.5, 0, -53.2) },
					LeftShoulder = { rot = Vector3.new(147.5, 0, 53.2) },
					RightHip = { rot = Vector3.new(9.7, 0, 2.8), pos = Vector3.new(0, 0.398, 0) },
					LeftHip = { rot = Vector3.new(58, 0, -2.8), pos = Vector3.new(0, 0.474, 0) },
				},
			},
			{
				time = 0.85,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},
	Bouncer_DoubleHammer = {
		length = 1.3,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, 0.1, 0.25) },
					Neck = { rot = Vector3.new(-12, 0, 0) },
					RightShoulder = { rot = Vector3.new(164.1, 0, -43.8) },
					LeftShoulder = { rot = Vector3.new(164.1, 0, 43.8) },
					RightHip = { rot = Vector3.new(-11.5, 0, 3.3) },
					LeftHip = { rot = Vector3.new(7.2, 0, -3.6) },
				},
			},
			{
				time = 0.4,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-30, 0, 0), pos = Vector3.new(0, -0.6, -0.6) },
					Neck = { rot = Vector3.new(22, 0, 0) },
					RightShoulder = { rot = Vector3.new(172.5, 0, -42.8) },
					LeftShoulder = { rot = Vector3.new(172.5, 0, 42.8) },
					RightHip = { rot = Vector3.new(3.3, 0, 2.8), pos = Vector3.new(0, 0.315, 0) },
					LeftHip = { rot = Vector3.new(51.8, 0, -2.8), pos = Vector3.new(0, 0.397, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-36, 0, 0), pos = Vector3.new(0, -0.7, -0.6) },
					Neck = { rot = Vector3.new(26, 0, 0) },
					RightShoulder = { rot = Vector3.new(147.5, 0, -53.2) },
					LeftShoulder = { rot = Vector3.new(147.5, 0, 53.2) },
					RightHip = { rot = Vector3.new(9.7, 0, 2.8), pos = Vector3.new(0, 0.398, 0) },
					LeftHip = { rot = Vector3.new(58, 0, -2.8), pos = Vector3.new(0, 0.474, 0) },
				},
			},
			{
				time = 0.76,
				pose = {
					Root = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.1, 0.25) },
					Neck = { rot = Vector3.new(-12, 0, 0) },
					RightShoulder = { rot = Vector3.new(158.9, 0, -43.7) },
					LeftShoulder = { rot = Vector3.new(158.9, 0, 43.7) },
					RightHip = { rot = Vector3.new(-17.4, 0, 3.4) },
					LeftHip = { rot = Vector3.new(1.4, 0, -3.5) },
				},
			},
			{
				time = 0.95,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-30, 0, 0), pos = Vector3.new(0, -0.6, -0.6) },
					Neck = { rot = Vector3.new(22, 0, 0) },
					RightShoulder = { rot = Vector3.new(172.5, 0, -42.8) },
					LeftShoulder = { rot = Vector3.new(172.5, 0, 42.8) },
					RightHip = { rot = Vector3.new(3.3, 0, 2.8), pos = Vector3.new(0, 0.315, 0) },
					LeftHip = { rot = Vector3.new(51.8, 0, -2.8), pos = Vector3.new(0, 0.397, 0) },
				},
			},
			{
				time = 1.07,
				pose = {
					Root = { rot = Vector3.new(-36, 0, 0), pos = Vector3.new(0, -0.7, -0.6) },
					Neck = { rot = Vector3.new(26, 0, 0) },
					RightShoulder = { rot = Vector3.new(147.5, 0, -53.2) },
					LeftShoulder = { rot = Vector3.new(147.5, 0, 53.2) },
					RightHip = { rot = Vector3.new(9.7, 0, 2.8), pos = Vector3.new(0, 0.398, 0) },
					LeftHip = { rot = Vector3.new(58, 0, -2.8), pos = Vector3.new(0, 0.474, 0) },
				},
			},
			{
				time = 1.3,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},
	Bouncer_Awaken = {
		length = 1,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.16,
				pose = {
					Root = { rot = Vector3.new(-2, 0, -6), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(0, 0, 30) },
					RightShoulder = { rot = Vector3.new(10, 0, 18) },
					LeftShoulder = { rot = Vector3.new(10, 0, -18) },
					RightHip = { rot = Vector3.new(-1.3, 0, 11.4), pos = Vector3.new(0, 0.184, 0) },
					LeftHip = { rot = Vector3.new(7.2, 0, 5.5) },
				},
			},
			{
				time = 0.34,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-2, 0, 6), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(0, 0, -30) },
					RightShoulder = { rot = Vector3.new(10, 0, 18) },
					LeftShoulder = { rot = Vector3.new(10, 0, -18) },
					RightHip = { rot = Vector3.new(-1.3, 0, -5.6) },
					LeftHip = { rot = Vector3.new(7.1, 0, -11.4), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.55,
				pose = {
					Root = { rot = Vector3.new(-10, 0, 0), pos = Vector3.new(0, -0.2, 0.05) },
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(20, 0, 26) },
					LeftShoulder = { rot = Vector3.new(20, 0, -26) },
					RightHip = { rot = Vector3.new(10.9, 0, 7.1), pos = Vector3.new(0, 0.234, 0) },
					LeftHip = { rot = Vector3.new(18, 0, -7.1), pos = Vector3.new(0, 0.214, 0) },
				},
			},
			{
				time = 0.7,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0, 0.1) },
					Neck = { rot = Vector3.new(-12, 0, 0) },
					RightShoulder = { rot = Vector3.new(30, 0, 38) },
					LeftShoulder = { rot = Vector3.new(30, 0, -38) },
					RightHip = { rot = Vector3.new(-16.3, 0, 7) },
					LeftHip = { rot = Vector3.new(-9.3, 0, -7) },
				},
			},
			{
				time = 0.85,
				pose = {
					Root = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, -0.02, 0.1) },
					Neck = { rot = Vector3.new(-10, 0, 0) },
					RightShoulder = { rot = Vector3.new(28, 0, 36) },
					LeftShoulder = { rot = Vector3.new(28, 0, -36) },
					RightHip = { rot = Vector3.new(-13.4, 0, 6.9) },
					LeftHip = { rot = Vector3.new(-6.2, 0, -6.9) },
				},
			},
			{
				time = 1,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},
	Weapon_Swing1 = {
		length = 0.45,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.08,
				pose = {
					Root = {
						rot = Vector3.new(2.31, -29.98, 1.15),
						pos = Vector3.new(0, -0.1, 0.1),
					},
					Neck = { rot = Vector3.new(6, 25, 0) },
					RightShoulder = { rot = Vector3.new(163.3, 0, -16.5) },
					LeftShoulder = { rot = Vector3.new(107.1, 0, 10.6) },
					RightHip = { rot = Vector3.new(-0.5, 0, 4.1), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(4.5, 0, -9.7), pos = Vector3.new(0, 0.142, 0) },
				},
			},
			{
				time = 0.15,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-15.38, 24.21, 6.44),
						pos = Vector3.new(0, -0.3, -0.35),
					},
					Neck = { rot = Vector3.new(12, -15, 0) },
					RightShoulder = { rot = Vector3.new(172.3, 0, -34.2) },
					LeftShoulder = { rot = Vector3.new(134.3, 0, 58.6) },
					RightHip = { rot = Vector3.new(-6.2, 0, -7.4), pos = Vector3.new(0, 0.073, 0) },
					LeftHip = { rot = Vector3.new(32.7, 0, 1.2), pos = Vector3.new(0, 0.159, 0) },
				},
			},
			{
				time = 0.26,
				pose = {
					Root = {
						rot = Vector3.new(-15.38, 24.21, 6.44),
						pos = Vector3.new(0, -0.3, -0.35),
					},
					Neck = { rot = Vector3.new(12, -15, 0) },
					RightShoulder = { rot = Vector3.new(120.6, 0, -77.7) },
					LeftShoulder = { rot = Vector3.new(134.3, 0, 58.6) },
					RightHip = { rot = Vector3.new(-6.2, 0, -7.4), pos = Vector3.new(0, 0.073, 0) },
					LeftHip = { rot = Vector3.new(32.7, 0, 1.2), pos = Vector3.new(0, 0.159, 0) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},
	Weapon_Swing2 = {
		length = 0.45,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.08,
				pose = {
					Root = {
						rot = Vector3.new(-4.88, 34.9, 2.8),
						pos = Vector3.new(0, -0.15, 0.05),
					},
					Neck = { rot = Vector3.new(8, -25, 0) },
					RightShoulder = { rot = Vector3.new(149, 0, -59.7) },
					LeftShoulder = { rot = Vector3.new(109.1, 0, 61.6) },
					RightHip = { rot = Vector3.new(-11.5, 0, -5.2), pos = Vector3.new(0, 0.022, 0) },
					LeftHip = { rot = Vector3.new(30, 0, 8.4) },
				},
			},
			{
				time = 0.15,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-13.2, -24.42, -5.54),
						pos = Vector3.new(0, -0.3, -0.3),
					},
					Neck = { rot = Vector3.new(12, 15, 0) },
					RightShoulder = { rot = Vector3.new(157.5, 0, -49.9) },
					LeftShoulder = { rot = Vector3.new(148.8, 0, 28.2) },
					RightHip = { rot = Vector3.new(6.5, 0, 9), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(15.3, 0, -4.2), pos = Vector3.new(0, 0.313, 0) },
				},
			},
			{
				time = 0.26,
				pose = {
					Root = {
						rot = Vector3.new(-13.2, -24.42, -5.54),
						pos = Vector3.new(0, -0.3, -0.3),
					},
					Neck = { rot = Vector3.new(12, 15, 0) },
					RightShoulder = { rot = Vector3.new(131.8, 0, -14.9) },
					LeftShoulder = { rot = Vector3.new(148.8, 0, 28.2) },
					RightHip = { rot = Vector3.new(6.5, 0, 9), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(15.3, 0, -4.2), pos = Vector3.new(0, 0.313, 0) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},
	Weapon_Swing3 = {
		length = 0.6,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.08,
				pose = {
					Root = { rot = Vector3.new(8.08, -7.92, 1.12), pos = Vector3.new(0, 0.05, 0.2) },
					Neck = { rot = Vector3.new(-8, 6, 0) },
					RightShoulder = { rot = Vector3.new(174.9, 0, -40) },
					LeftShoulder = { rot = Vector3.new(88.4, 0, 29.1) },
					RightHip = { rot = Vector3.new(-13.7, 0, 3.5) },
					LeftHip = { rot = Vector3.new(6.2, 0, -6) },
				},
			},
			{
				time = 0.15,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-26, 0, 0), pos = Vector3.new(0, -0.5, -0.5) },
					Neck = { rot = Vector3.new(18, 0, 0) },
					RightShoulder = { rot = Vector3.new(192.5, 0, -41.8) },
					LeftShoulder = { rot = Vector3.new(173.4, 0, 45.2) },
					RightHip = { rot = Vector3.new(9.4, 0, 2.8), pos = Vector3.new(0, 0.375, 0) },
					LeftHip = { rot = Vector3.new(34.3, 0, -2.8), pos = Vector3.new(0, 0.445, 0) },
				},
			},
			{
				time = 0.26,
				pose = {
					Root = { rot = Vector3.new(-26, 0, 0), pos = Vector3.new(0, -0.5, -0.5) },
					Neck = { rot = Vector3.new(18, 0, 0) },
					RightShoulder = { rot = Vector3.new(139.3, 0, -68.3) },
					LeftShoulder = { rot = Vector3.new(173.4, 0, 45.2) },
					RightHip = { rot = Vector3.new(9.4, 0, 2.8), pos = Vector3.new(0, 0.375, 0) },
					LeftHip = { rot = Vector3.new(34.3, 0, -2.8), pos = Vector3.new(0, 0.445, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},
	Bouncer_Slam = {
		length = 1.6,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-19.72, 23.7, 8.2),
						pos = Vector3.new(-0.3, -0.2, -0.1),
					},
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(41.3, 0, -22.3) },
					LeftShoulder = { rot = Vector3.new(127.7, 0, 84.6) },
					RightHip = { rot = Vector3.new(9.9, 0, 5.3), pos = Vector3.new(0, 0.177, 0) },
					LeftHip = { rot = Vector3.new(30.4, 0, 8), pos = Vector3.new(0, 0.019, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = {
						rot = Vector3.new(-34.25, 27.32, 17.35),
						pos = Vector3.new(-0.45, -0.65, -0.3),
					},
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(57.8, 0, -44.3) },
					LeftShoulder = { rot = Vector3.new(193.2, 0, 66.8) },
					RightHip = { rot = Vector3.new(6.2, 0, 1.3), pos = Vector3.new(0, 0.41, 0) },
					LeftHip = { rot = Vector3.new(63.6, 0, 16.9) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-31.06, 24.49, 14.02),
						pos = Vector3.new(-0.35, -0.7, -0.35),
					},
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(3.6, 0, -25.4) },
					LeftShoulder = { rot = Vector3.new(197.5, 0, 56.1) },
					RightHip = { rot = Vector3.new(4, 0, 0.3), pos = Vector3.new(0, 0.467, 0) },
					LeftHip = { rot = Vector3.new(55.3, 0, 12.6), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = {
						rot = Vector3.new(-10.3, 13.78, 2.48),
						pos = Vector3.new(-0.1, -0.25, -0.2),
					},
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(134.3, 0, 1) },
					LeftShoulder = { rot = Vector3.new(172.2, 0, 76) },
					RightHip = { rot = Vector3.new(-6.1, 0, 1.3), pos = Vector3.new(0, 0.169, 0) },
					LeftHip = { rot = Vector3.new(35.1, 0, 2.9), pos = Vector3.new(0, 0.021, 0) },
				},
			},
			{
				time = 0.6,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(8, 1.98, -0.28), pos = Vector3.new(0, 0.05, 0.05) },
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(112, 0, -22.5) },
					LeftShoulder = { rot = Vector3.new(145.5, 0, 15.1) },
					RightHip = { rot = Vector3.new(-20.6, 0, 3) },
					LeftHip = { rot = Vector3.new(10.4, 0, -4.1) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(10.01, -1.97, 0.35),
						pos = Vector3.new(0, 0.05, 0.08),
					},
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(95.5, 0, -24.6) },
					LeftShoulder = { rot = Vector3.new(140.9, 0, 29.3) },
					RightHip = { rot = Vector3.new(-21.6, 0, 3.5) },
					LeftHip = { rot = Vector3.new(7, 0, -5.6) },
				},
			},
			{
				time = 0.88,
				pose = {
					Root = { rot = Vector3.new(-26, 0, 0), pos = Vector3.new(0, -0.45, -0.35) },
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(114.6, 0, -18.6) },
					LeftShoulder = { rot = Vector3.new(117.2, 0, 18.4) },
					RightHip = { rot = Vector3.new(14, 0, 2.8), pos = Vector3.new(0, 0.364, 0) },
					LeftHip = { rot = Vector3.new(46.7, 0, -4.3), pos = Vector3.new(0, 0.278, 0) },
				},
			},
			{
				time = 1,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-42, 0, 0), pos = Vector3.new(0, -1.05, -0.6) },
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(68.4, 0, -14.9) },
					LeftShoulder = { rot = Vector3.new(75.2, 0, 25.6) },
					RightHip = { rot = Vector3.new(17.2, 0, 2.8), pos = Vector3.new(0, 0.847, 0) },
					LeftHip = { rot = Vector3.new(44.4, 0, -4.2), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 1.15,
				pose = {
					Root = { rot = Vector3.new(-36, 0, 0), pos = Vector3.new(0, -1.1, -0.55) },
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(65.7, 0, -15) },
					LeftShoulder = { rot = Vector3.new(59.1, 0, 41.4) },
					RightHip = { rot = Vector3.new(11.1, 0, 2.8), pos = Vector3.new(0, 0.919, 0) },
					LeftHip = { rot = Vector3.new(40.1, 0, -4), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 1.4,
				pose = {
					Root = { rot = Vector3.new(-16, 0, 0), pos = Vector3.new(0, -0.45, -0.25) },
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(78.3, 0, -33.2) },
					LeftShoulder = { rot = Vector3.new(83, 0, 33.7) },
					RightHip = { rot = Vector3.new(3.6, 0, 2.8), pos = Vector3.new(0, 0.402, 0) },
					LeftHip = { rot = Vector3.new(35.6, 0, -4.3), pos = Vector3.new(0, 0.338, 0) },
				},
			},
		},
	},
	Bouncer_SlamVictim = {
		length = 1,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0), pos = Vector3.new(0, -0.05, 0.05) },
					Neck = { rot = Vector3.new(-10, 0, 0) },
					RightShoulder = { rot = Vector3.new(98.6, 0, -19.2) },
					LeftShoulder = { rot = Vector3.new(100, 0, 32.9) },
					RightHip = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, 0.045, 0) },
					LeftHip = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, 0.045, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(-12, 0, 0), pos = Vector3.new(0, -0.1, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(94.2, 0, -14.6) },
					LeftShoulder = { rot = Vector3.new(85.4, 0, 53.2) },
					RightHip = { rot = Vector3.new(14.6, 0, 0), pos = Vector3.new(0, 0.078, 0) },
					LeftHip = { rot = Vector3.new(14.6, 0, 0), pos = Vector3.new(0, 0.078, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-1.52, 6.99, -24.9),
						pos = Vector3.new(0.1, 0.1, -0.2),
					},
					Neck = { rot = Vector3.new(-20, 12, 0) },
					RightShoulder = { rot = Vector3.new(90.1, 0, -17.9) },
					LeftShoulder = { rot = Vector3.new(47.1, 0, 43.5) },
					RightHip = { rot = Vector3.new(30, 0, 14) },
					LeftHip = { rot = Vector3.new(8, 0, -10) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = {
						rot = Vector3.new(21.47, 5.35, -68),
						pos = Vector3.new(0.2, 0.75, -0.5),
					},
					Neck = { rot = Vector3.new(-24, 18, 0) },
					RightShoulder = { rot = Vector3.new(70, 0, 40) },
					LeftShoulder = { rot = Vector3.new(60, 0, -30) },
					RightHip = { rot = Vector3.new(22, 0, 16) },
					LeftHip = { rot = Vector3.new(4, 0, -12) },
				},
			},
			{
				time = 0.6,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(26.59, 2.56, -84.9),
						pos = Vector3.new(0.15, 1.35, -0.65),
					},
					Neck = { rot = Vector3.new(-12, 10, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 60) },
					LeftShoulder = { rot = Vector3.new(80, 0, -45) },
					RightHip = { rot = Vector3.new(14, 0, 18) },
					LeftHip = { rot = Vector3.new(24, 0, -14) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(26.95, -1.42, -84.9),
						pos = Vector3.new(0.1, 1.4, -0.6),
					},
					Neck = { rot = Vector3.new(-14, 6, 0) },
					RightShoulder = { rot = Vector3.new(75, 0, 55) },
					LeftShoulder = { rot = Vector3.new(55, 0, -60) },
					RightHip = { rot = Vector3.new(24, 0, 16) },
					LeftHip = { rot = Vector3.new(8, 0, -16) },
				},
			},
			{
				time = 0.88,
				pose = {
					Root = {
						rot = Vector3.new(67.85, 1.54, -88.58),
						pos = Vector3.new(0, 0.2, 0.25),
					},
					Neck = { rot = Vector3.new(-30, 0, 0) },
					RightShoulder = { rot = Vector3.new(40, 0, 70) },
					LeftShoulder = { rot = Vector3.new(40, 0, -70) },
					RightHip = { rot = Vector3.new(10, 0, 12) },
					LeftHip = { rot = Vector3.new(16, 0, -12) },
				},
			},
			{
				time = 1,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(90, 0, -90), pos = Vector3.new(-0.2, -2.5, 0.9) },
					Neck = { rot = Vector3.new(24, 0, 0) },
					RightShoulder = { rot = Vector3.new(20, 0, 75) },
					LeftShoulder = { rot = Vector3.new(25, 0, -80) },
					RightHip = { rot = Vector3.new(18, 0, 14) },
					LeftHip = { rot = Vector3.new(6, 0, -12) },
				},
			},
		},
	},
	Bouncer_Powerbomb = {
		length = 1.8,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-18, 0, 0), pos = Vector3.new(0, -0.15, -0.05) },
					Neck = { rot = Vector3.new(10, 0, 0) },
					RightShoulder = { rot = Vector3.new(182, 0, -64.7) },
					LeftShoulder = { rot = Vector3.new(182, 0, 64.7) },
					RightHip = { rot = Vector3.new(19.6, 0, 9.9), pos = Vector3.new(0, 0.164, 0) },
					LeftHip = { rot = Vector3.new(19.6, 0, -9.9), pos = Vector3.new(0, 0.164, 0) },
				},
			},
			{
				time = 0.22,
				pose = {
					Root = { rot = Vector3.new(-55, 0, 0), pos = Vector3.new(0, -0.75, -0.3) },
					Neck = { rot = Vector3.new(35, 0, 0) },
					RightShoulder = { rot = Vector3.new(144.1, 0, -18.4) },
					LeftShoulder = { rot = Vector3.new(144.1, 0, 18.4) },
					RightHip = { rot = Vector3.new(50.4, 0, 9.9), pos = Vector3.new(0, 0.651, 0) },
					LeftHip = { rot = Vector3.new(50.4, 0, -9.9), pos = Vector3.new(0, 0.651, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(-22, 0, 0), pos = Vector3.new(0, -0.55, 0) },
					Neck = { rot = Vector3.new(15, 0, 0) },
					RightShoulder = { rot = Vector3.new(102, 0, -68.9) },
					LeftShoulder = { rot = Vector3.new(102, 0, 68.9) },
					RightHip = { rot = Vector3.new(22.3, 0, 9.9), pos = Vector3.new(0, 0.575, 0) },
					LeftHip = { rot = Vector3.new(22.3, 0, -9.9), pos = Vector3.new(0, 0.575, 0) },
				},
			},
			{
				time = 0.6,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(4, 0, 0), pos = Vector3.new(0, 0, 0.1) },
					Neck = { rot = Vector3.new(-10, 0, 0) },
					RightShoulder = { rot = Vector3.new(135.4, 0, -73) },
					LeftShoulder = { rot = Vector3.new(135.4, 0, 73) },
					RightHip = { rot = Vector3.new(-7.4, 0, 9.8) },
					LeftHip = { rot = Vector3.new(-7.4, 0, -9.8) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.02, 0.15) },
					Neck = { rot = Vector3.new(-14, 0, 0) },
					RightShoulder = { rot = Vector3.new(141.1, 0, -71.8) },
					LeftShoulder = { rot = Vector3.new(141.1, 0, 71.8) },
					RightHip = { rot = Vector3.new(-14.9, 0, 9.8) },
					LeftHip = { rot = Vector3.new(-14.9, 0, -9.8) },
				},
			},
			{
				time = 0.97,
				pose = {
					Root = { rot = Vector3.new(-24, 0, 0), pos = Vector3.new(0, -0.45, -0.3) },
					Neck = { rot = Vector3.new(12, 0, 0) },
					RightShoulder = { rot = Vector3.new(149.4, 0, -97.8) },
					LeftShoulder = { rot = Vector3.new(149.4, 0, 97.8) },
					RightHip = { rot = Vector3.new(17.7, 0, 9.9), pos = Vector3.new(0, 0.446, 0) },
					LeftHip = { rot = Vector3.new(17.7, 0, -9.9), pos = Vector3.new(0, 0.446, 0) },
				},
			},
			{
				time = 1.15,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-30, 0, 0), pos = Vector3.new(0, -1.55, -0.45) },
					Neck = { rot = Vector3.new(20, 0, 0) },
					RightShoulder = { rot = Vector3.new(90.7, 0, -53.2) },
					LeftShoulder = { rot = Vector3.new(90.7, 0, 53.2) },
					RightHip = { rot = Vector3.new(-34, 0, 2.8), pos = Vector3.new(0, 0.637, 0) },
					LeftHip = { rot = Vector3.new(-34, 0, -2.8), pos = Vector3.new(0, 0.637, 0) },
				},
			},
			{
				time = 1.45,
				pose = {
					Root = { rot = Vector3.new(-24, 0, 0), pos = Vector3.new(0, -1.5, -0.35) },
					Neck = { rot = Vector3.new(20, 0, 0) },
					RightShoulder = { rot = Vector3.new(74.7, 0, -31) },
					LeftShoulder = { rot = Vector3.new(74.7, 0, 30.9) },
					RightHip = { rot = Vector3.new(-37.4, 0, 2.8), pos = Vector3.new(0, 0.693, 0) },
					LeftHip = { rot = Vector3.new(-37.4, 0, -2.8), pos = Vector3.new(0, 0.693, 0) },
				},
			},
			{
				time = 1.8,
				pose = {
					Root = { rot = Vector3.new(-12, 0, 0), pos = Vector3.new(0, -0.3, -0.1) },
					Neck = { rot = Vector3.new(10, 0, 0) },
					RightShoulder = { rot = Vector3.new(20, 0, 10) },
					LeftShoulder = { rot = Vector3.new(20, 0, -10) },
					RightHip = { rot = Vector3.new(8.9, 0, 9.9), pos = Vector3.new(0, 0.339, 0) },
					LeftHip = { rot = Vector3.new(8.9, 0, -9.9), pos = Vector3.new(0, 0.339, 0) },
				},
			},
		},
	},
	Bouncer_PowerbombVictim = {
		length = 1.15,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(-10, 0, 0) },
					RightShoulder = { rot = Vector3.new(57, 0, -73.1) },
					LeftShoulder = { rot = Vector3.new(57, 0, 73) },
					RightHip = { rot = Vector3.new(11.8, 0, 0), pos = Vector3.new(0, 0.036, 0) },
					LeftHip = { rot = Vector3.new(11.8, 0, 0), pos = Vector3.new(0, 0.036, 0) },
				},
			},
			{
				time = 0.22,
				pose = {
					Root = { rot = Vector3.new(-70, 0, 0), pos = Vector3.new(0, -0.75, 0.05) },
					Neck = { rot = Vector3.new(-30, 0, 0) },
					RightShoulder = { rot = Vector3.new(121.1, 0, -18.4) },
					LeftShoulder = { rot = Vector3.new(121.1, 0, 18.4) },
					RightHip = { rot = Vector3.new(90, 0, 1.5), pos = Vector3.new(0, 0.606, 0) },
					LeftHip = { rot = Vector3.new(90, 0, -1.5), pos = Vector3.new(0, 0.606, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(-40, 0, 0), pos = Vector3.new(0, 0.7, -0.55) },
					Neck = { rot = Vector3.new(-20, 0, 0) },
					RightShoulder = { rot = Vector3.new(120, 0, 50) },
					LeftShoulder = { rot = Vector3.new(100, 0, -60) },
					RightHip = { rot = Vector3.new(60, 0, 20) },
					LeftHip = { rot = Vector3.new(50, 0, -20) },
				},
			},
			{
				time = 0.6,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-4, 0, 0), pos = Vector3.new(0, 2.15, -0.85) },
					Neck = { rot = Vector3.new(10, 0, 0) },
					RightShoulder = { rot = Vector3.new(55.2, 0, -66.7) },
					LeftShoulder = { rot = Vector3.new(55.2, 0, 66.7) },
					RightHip = { rot = Vector3.new(82, 0, 22) },
					LeftHip = { rot = Vector3.new(82, 0, -22) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = { rot = Vector3.new(12, 0, 0), pos = Vector3.new(0, 2.25, -0.8) },
					Neck = { rot = Vector3.new(18, 0, 0) },
					RightShoulder = { rot = Vector3.new(150, 0, 60) },
					LeftShoulder = { rot = Vector3.new(150, 0, -60) },
					RightHip = { rot = Vector3.new(84, 0, 22) },
					LeftHip = { rot = Vector3.new(80, 0, -22) },
				},
			},
			{
				time = 0.97,
				pose = {
					Root = { rot = Vector3.new(50, 0, 0), pos = Vector3.new(0, 0.9, 0.15) },
					Neck = { rot = Vector3.new(-25, 0, 0) },
					RightShoulder = { rot = Vector3.new(100, 0, 70) },
					LeftShoulder = { rot = Vector3.new(100, 0, -70) },
					RightHip = { rot = Vector3.new(70, 0, 18) },
					LeftHip = { rot = Vector3.new(70, 0, -18) },
				},
			},
			{
				time = 1.15,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(90, 0, 0), pos = Vector3.new(0, -2.5, 1.2) },
					Neck = { rot = Vector3.new(25, 0, 0) },
					RightShoulder = { rot = Vector3.new(30, 0, 80) },
					LeftShoulder = { rot = Vector3.new(30, 0, -80) },
					RightHip = { rot = Vector3.new(72, 0, 16) },
					LeftHip = { rot = Vector3.new(72, 0, -16) },
				},
			},
		},
	},
	Bouncer_Choke = {
		length = 1.9,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-7.61, 26.6, 13.42),
						pos = Vector3.new(0.9, -0.16, -0.46),
					},
					Neck = { rot = Vector3.new(15.2, -20, -14) },
					RightShoulder = { rot = Vector3.new(38.1, 0, -81.5) },
					LeftShoulder = { rot = Vector3.new(84, 0, 61) },
					RightHip = { rot = Vector3.new(-13.4, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.2, 0, -34.9), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 0.31,
				pose = {
					Root = {
						rot = Vector3.new(-7.61, 26.6, 13.42),
						pos = Vector3.new(0.9, -0.16, -0.46),
					},
					Neck = { rot = Vector3.new(15.2, -20, -14) },
					RightShoulder = { rot = Vector3.new(41.7, 0, -83.3) },
					LeftShoulder = { rot = Vector3.new(84, 0, 61) },
					RightHip = { rot = Vector3.new(-13.4, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.2, 0, -34.9), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 0.45,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-11.51, 29.5, 15.73),
						pos = Vector3.new(0.9, -0.2, -0.5),
					},
					Neck = { rot = Vector3.new(20, -20, -14) },
					RightShoulder = { rot = Vector3.new(105.7, 0, -55) },
					LeftShoulder = { rot = Vector3.new(91.1, 0, 65.6) },
					RightHip = { rot = Vector3.new(-8.9, 0, -35.2) },
					LeftHip = { rot = Vector3.new(34.2, 0, -34), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 0.71,
				pose = {
					Root = {
						rot = Vector3.new(-7.61, 26.6, 13.42),
						pos = Vector3.new(0.9, -0.16, -0.46),
					},
					Neck = { rot = Vector3.new(15.2, -20, -14) },
					RightShoulder = { rot = Vector3.new(41.7, 0, -83.3) },
					LeftShoulder = { rot = Vector3.new(84, 0, 61) },
					RightHip = { rot = Vector3.new(-13.4, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.2, 0, -34.9), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 0.85,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-11.51, 29.5, 15.73),
						pos = Vector3.new(0.9, -0.2, -0.5),
					},
					Neck = { rot = Vector3.new(20, -20, -14) },
					RightShoulder = { rot = Vector3.new(105.7, 0, -55) },
					LeftShoulder = { rot = Vector3.new(91.1, 0, 65.6) },
					RightHip = { rot = Vector3.new(-8.9, 0, -35.2) },
					LeftHip = { rot = Vector3.new(34.2, 0, -34), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 1.11,
				pose = {
					Root = {
						rot = Vector3.new(-7.61, 26.6, 13.42),
						pos = Vector3.new(0.9, -0.16, -0.46),
					},
					Neck = { rot = Vector3.new(15.2, -20, -14) },
					RightShoulder = { rot = Vector3.new(41.7, 0, -83.3) },
					LeftShoulder = { rot = Vector3.new(84, 0, 61) },
					RightHip = { rot = Vector3.new(-13.4, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.2, 0, -34.9), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 1.25,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-11.51, 29.5, 15.73),
						pos = Vector3.new(0.9, -0.2, -0.5),
					},
					Neck = { rot = Vector3.new(20, -20, -14) },
					RightShoulder = { rot = Vector3.new(105.7, 0, -55) },
					LeftShoulder = { rot = Vector3.new(91.1, 0, 65.6) },
					RightHip = { rot = Vector3.new(-8.9, 0, -35.2) },
					LeftHip = { rot = Vector3.new(34.2, 0, -34), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 1.7,
				pose = {
					Root = {
						rot = Vector3.new(-9.04, 27.7, 14.23),
						pos = Vector3.new(0.9, -0.175, -0.475),
					},
					Neck = { rot = Vector3.new(17, -20, -14) },
					RightShoulder = { rot = Vector3.new(101.2, 0, -70.3) },
					LeftShoulder = { rot = Vector3.new(86.5, 0, 62.7) },
					RightHip = { rot = Vector3.new(-11.8, 0, -34.1) },
					LeftHip = { rot = Vector3.new(30.4, 0, -34.6), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 1.9,
				pose = {
					Root = {
						rot = Vector3.new(-12.06, 5.87, 1.25),
						pos = Vector3.new(0, -0.1, -0.1),
					},
					Neck = { rot = Vector3.new(10, -4, 0) },
					RightShoulder = { rot = Vector3.new(81.2, 0, -32.6) },
					LeftShoulder = { rot = Vector3.new(87.8, 0, 46.5) },
					RightHip = { rot = Vector3.new(2.6, 0, 4.2), pos = Vector3.new(0, 0.084, 0) },
					LeftHip = { rot = Vector3.new(25.2, 0, -0.7), pos = Vector3.new(0, 0.032, 0) },
				},
			},
		},
	},
	Bouncer_ChokeVictim = {
		length = 1.9,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(6.6, 0, -6), pos = Vector3.new(-0.15, -0.72, 0.05) },
					Neck = { rot = Vector3.new(26, 0, 0) },
					RightShoulder = { rot = Vector3.new(-70.3, 0, -70.1) },
					LeftShoulder = { rot = Vector3.new(-52.5, 0, 64.2) },
					RightHip = { rot = Vector3.new(1, 0, 12.3), pos = Vector3.new(0, 0.847, 0) },
					LeftHip = { rot = Vector3.new(-0.4, 0, 10.1), pos = Vector3.new(0, 0.559, 0) },
				},
			},
			{
				time = 0.31,
				pose = {
					Root = { rot = Vector3.new(6.6, 0, -2), pos = Vector3.new(-0.15, -0.72, 0.05) },
					Neck = { rot = Vector3.new(26, 8, 0) },
					RightShoulder = { rot = Vector3.new(108.9, 0, -146.9) },
					LeftShoulder = { rot = Vector3.new(307.8, 0, 63.8) },
					RightHip = { rot = Vector3.new(-7.3, 0, 14.8), pos = Vector3.new(0, 0.814, 0) },
					LeftHip = { rot = Vector3.new(8.8, 0, 11.3), pos = Vector3.new(0, 0.508, 0) },
				},
			},
			{
				time = 0.45,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(9, 0, -10), pos = Vector3.new(-0.15, -0.6, 0.05) },
					Neck = { rot = Vector3.new(34, -8, 0) },
					RightShoulder = { rot = Vector3.new(-50.5, 0, -53.2) },
					LeftShoulder = { rot = Vector3.new(288.5, 0, 63.8) },
					RightHip = { rot = Vector3.new(6.1, 0, 10.5), pos = Vector3.new(0, 0.697, 0) },
					LeftHip = { rot = Vector3.new(-13, 0, 9.4), pos = Vector3.new(0, 0.412, 0) },
				},
			},
			{
				time = 0.71,
				pose = {
					Root = { rot = Vector3.new(6.6, 0, -2), pos = Vector3.new(-0.15, -0.72, 0.05) },
					Neck = { rot = Vector3.new(26, 8, 0) },
					RightShoulder = { rot = Vector3.new(108.9, 0, -146.9) },
					LeftShoulder = { rot = Vector3.new(307.8, 0, 63.8) },
					RightHip = { rot = Vector3.new(-7.3, 0, 14.8), pos = Vector3.new(0, 0.814, 0) },
					LeftHip = { rot = Vector3.new(8.8, 0, 11.3), pos = Vector3.new(0, 0.508, 0) },
				},
			},
			{
				time = 0.85,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(9, 0, -10), pos = Vector3.new(-0.15, -0.6, 0.05) },
					Neck = { rot = Vector3.new(34, -8, 0) },
					RightShoulder = { rot = Vector3.new(-50.5, 0, -53.2) },
					LeftShoulder = { rot = Vector3.new(288.5, 0, 63.8) },
					RightHip = { rot = Vector3.new(6.1, 0, 10.5), pos = Vector3.new(0, 0.697, 0) },
					LeftHip = { rot = Vector3.new(-13, 0, 9.4), pos = Vector3.new(0, 0.412, 0) },
				},
			},
			{
				time = 1.11,
				pose = {
					Root = { rot = Vector3.new(6.6, 0, -2), pos = Vector3.new(-0.15, -0.72, 0.05) },
					Neck = { rot = Vector3.new(26, 8, 0) },
					RightShoulder = { rot = Vector3.new(108.9, 0, -146.9) },
					LeftShoulder = { rot = Vector3.new(307.8, 0, 63.8) },
					RightHip = { rot = Vector3.new(-7.3, 0, 14.8), pos = Vector3.new(0, 0.814, 0) },
					LeftHip = { rot = Vector3.new(8.8, 0, 11.3), pos = Vector3.new(0, 0.508, 0) },
				},
			},
			{
				time = 1.25,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(9, 0, -10), pos = Vector3.new(-0.15, -0.6, 0.05) },
					Neck = { rot = Vector3.new(34, -8, 0) },
					RightShoulder = { rot = Vector3.new(-50.5, 0, -53.2) },
					LeftShoulder = { rot = Vector3.new(288.5, 0, 63.8) },
					RightHip = { rot = Vector3.new(6.1, 0, 10.5), pos = Vector3.new(0, 0.697, 0) },
					LeftHip = { rot = Vector3.new(-13, 0, 9.4), pos = Vector3.new(0, 0.412, 0) },
				},
			},
			{
				time = 1.7,
				pose = {
					Root = {
						rot = Vector3.new(7.8, 0, -4.4),
						pos = Vector3.new(-0.15, -0.66, 0.05),
					},
					Neck = { rot = Vector3.new(30, 3.2, 0) },
					RightShoulder = { rot = Vector3.new(-51, 0, -56.6) },
					LeftShoulder = { rot = Vector3.new(-74.1, 0, 64.9) },
					RightHip = { rot = Vector3.new(-3.9, 0, 13.4), pos = Vector3.new(0, 0.782, 0) },
					LeftHip = { rot = Vector3.new(1.5, 0, 10.7), pos = Vector3.new(0, 0.486, 0) },
				},
			},
			{
				time = 1.9,
				pose = {
					Root = { rot = Vector3.new(-28, 0, 0), pos = Vector3.new(0, -0.3, 0.15) },
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(118, 0, -38) },
					LeftShoulder = { rot = Vector3.new(118, 0, 38) },
					RightHip = { rot = Vector3.new(45.9, 0, 1.4), pos = Vector3.new(0, 0.111, 0) },
					LeftHip = { rot = Vector3.new(34.3, 0, -1.4), pos = Vector3.new(0, 0.207, 0) },
				},
			},
		},
	},
	Bouncer_Sleeper = {
		length = 2.6,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-7.61, 26.6, 13.42),
						pos = Vector3.new(0.9, -0.16, -0.46),
					},
					Neck = { rot = Vector3.new(15.2, -20, -14) },
					RightShoulder = { rot = Vector3.new(38.1, 0, -81.5) },
					LeftShoulder = { rot = Vector3.new(84, 0, 61) },
					RightHip = { rot = Vector3.new(-13.4, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.2, 0, -34.9), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 0.31,
				pose = {
					Root = {
						rot = Vector3.new(-7.61, 26.6, 13.42),
						pos = Vector3.new(0.9, -0.16, -0.46),
					},
					Neck = { rot = Vector3.new(15.2, -20, -14) },
					RightShoulder = { rot = Vector3.new(41.7, 0, -83.3) },
					LeftShoulder = { rot = Vector3.new(84, 0, 61) },
					RightHip = { rot = Vector3.new(-13.4, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.2, 0, -34.9), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 0.45,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-11.51, 29.5, 15.73),
						pos = Vector3.new(0.9, -0.2, -0.5),
					},
					Neck = { rot = Vector3.new(20, -20, -14) },
					RightShoulder = { rot = Vector3.new(105.7, 0, -55) },
					LeftShoulder = { rot = Vector3.new(91.1, 0, 65.6) },
					RightHip = { rot = Vector3.new(-8.9, 0, -35.2) },
					LeftHip = { rot = Vector3.new(34.2, 0, -34), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 0.71,
				pose = {
					Root = {
						rot = Vector3.new(-7.61, 26.6, 13.42),
						pos = Vector3.new(0.9, -0.16, -0.46),
					},
					Neck = { rot = Vector3.new(15.2, -20, -14) },
					RightShoulder = { rot = Vector3.new(41.7, 0, -83.3) },
					LeftShoulder = { rot = Vector3.new(84, 0, 61) },
					RightHip = { rot = Vector3.new(-13.4, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.2, 0, -34.9), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 0.85,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-11.51, 29.5, 15.73),
						pos = Vector3.new(0.9, -0.2, -0.5),
					},
					Neck = { rot = Vector3.new(20, -20, -14) },
					RightShoulder = { rot = Vector3.new(105.7, 0, -55) },
					LeftShoulder = { rot = Vector3.new(91.1, 0, 65.6) },
					RightHip = { rot = Vector3.new(-8.9, 0, -35.2) },
					LeftHip = { rot = Vector3.new(34.2, 0, -34), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 1.11,
				pose = {
					Root = {
						rot = Vector3.new(-7.61, 26.6, 13.42),
						pos = Vector3.new(0.9, -0.16, -0.46),
					},
					Neck = { rot = Vector3.new(15.2, -20, -14) },
					RightShoulder = { rot = Vector3.new(23.5, 0, -57.6) },
					LeftShoulder = { rot = Vector3.new(84, 0, 61) },
					RightHip = { rot = Vector3.new(-13.4, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.2, 0, -34.9), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 1.25,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-11.51, 29.5, 15.73),
						pos = Vector3.new(0.9, -0.2, -0.5),
					},
					Neck = { rot = Vector3.new(20, -20, -14) },
					RightShoulder = { rot = Vector3.new(15.5, 0, -62.4) },
					LeftShoulder = { rot = Vector3.new(91.1, 0, 65.6) },
					RightHip = { rot = Vector3.new(-8.9, 0, -35.2) },
					LeftHip = { rot = Vector3.new(34.2, 0, -34), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 1.51,
				pose = {
					Root = {
						rot = Vector3.new(-7.61, 26.6, 13.42),
						pos = Vector3.new(0.9, -0.16, -0.46),
					},
					Neck = { rot = Vector3.new(15.2, -20, -14) },
					RightShoulder = { rot = Vector3.new(17.3, 0, -90.2) },
					LeftShoulder = { rot = Vector3.new(84, 0, 61) },
					RightHip = { rot = Vector3.new(-13.4, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.2, 0, -34.9), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 1.65,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-11.51, 29.5, 15.73),
						pos = Vector3.new(0.9, -0.2, -0.5),
					},
					Neck = { rot = Vector3.new(20, -20, -14) },
					RightShoulder = { rot = Vector3.new(274.4, 0, -136.3) },
					LeftShoulder = { rot = Vector3.new(91.1, 0, 65.6) },
					RightHip = { rot = Vector3.new(-8.9, 0, -35.2) },
					LeftHip = { rot = Vector3.new(34.2, 0, -34), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 2.6,
				pose = {
					Root = {
						rot = Vector3.new(-10.02, 28.43, 14.81),
						pos = Vector3.new(0.9, -0.185, -0.485),
					},
					Neck = { rot = Vector3.new(18.2, -20, -14) },
					RightShoulder = { rot = Vector3.new(20.8, 0, -57.8) },
					LeftShoulder = { rot = Vector3.new(88.3, 0, 63.9) },
					RightHip = { rot = Vector3.new(-10.6, 0, -34.6) },
					LeftHip = { rot = Vector3.new(32, 0, -34.4), pos = Vector3.new(0, 0.211, 0) },
				},
			},
		},
	},
	Bouncer_SleeperVictim = {
		length = 2.6,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(6.6, 0, -6), pos = Vector3.new(-0.15, -0.72, 0.05) },
					Neck = { rot = Vector3.new(26, 0, 0) },
					RightShoulder = { rot = Vector3.new(-70.3, 0, -70.1) },
					LeftShoulder = { rot = Vector3.new(-52.5, 0, 64.2) },
					RightHip = { rot = Vector3.new(1, 0, 12.3), pos = Vector3.new(0, 0.847, 0) },
					LeftHip = { rot = Vector3.new(-0.4, 0, 10.1), pos = Vector3.new(0, 0.559, 0) },
				},
			},
			{
				time = 0.31,
				pose = {
					Root = { rot = Vector3.new(6.6, 0, -2), pos = Vector3.new(-0.15, -0.72, 0.05) },
					Neck = { rot = Vector3.new(26, 8, 0) },
					RightShoulder = { rot = Vector3.new(108.9, 0, -146.9) },
					LeftShoulder = { rot = Vector3.new(307.8, 0, 63.8) },
					RightHip = { rot = Vector3.new(-7.3, 0, 14.8), pos = Vector3.new(0, 0.814, 0) },
					LeftHip = { rot = Vector3.new(8.8, 0, 11.3), pos = Vector3.new(0, 0.508, 0) },
				},
			},
			{
				time = 0.45,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(9, 0, -10), pos = Vector3.new(-0.15, -0.6, 0.05) },
					Neck = { rot = Vector3.new(34, -8, 0) },
					RightShoulder = { rot = Vector3.new(-50.5, 0, -53.2) },
					LeftShoulder = { rot = Vector3.new(288.5, 0, 63.8) },
					RightHip = { rot = Vector3.new(6.1, 0, 10.5), pos = Vector3.new(0, 0.697, 0) },
					LeftHip = { rot = Vector3.new(-13, 0, 9.4), pos = Vector3.new(0, 0.412, 0) },
				},
			},
			{
				time = 0.71,
				pose = {
					Root = { rot = Vector3.new(6.6, 0, -2), pos = Vector3.new(-0.15, -0.72, 0.05) },
					Neck = { rot = Vector3.new(26, 8, 0) },
					RightShoulder = { rot = Vector3.new(108.9, 0, -146.9) },
					LeftShoulder = { rot = Vector3.new(307.8, 0, 63.8) },
					RightHip = { rot = Vector3.new(-7.3, 0, 14.8), pos = Vector3.new(0, 0.814, 0) },
					LeftHip = { rot = Vector3.new(8.8, 0, 11.3), pos = Vector3.new(0, 0.508, 0) },
				},
			},
			{
				time = 0.85,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(9, 0, -10), pos = Vector3.new(-0.15, -0.6, 0.05) },
					Neck = { rot = Vector3.new(34, -8, 0) },
					RightShoulder = { rot = Vector3.new(-50.5, 0, -53.2) },
					LeftShoulder = { rot = Vector3.new(288.5, 0, 63.8) },
					RightHip = { rot = Vector3.new(6.1, 0, 10.5), pos = Vector3.new(0, 0.697, 0) },
					LeftHip = { rot = Vector3.new(-13, 0, 9.4), pos = Vector3.new(0, 0.412, 0) },
				},
			},
			{
				time = 1.11,
				pose = {
					Root = { rot = Vector3.new(10.6, 0, -4), pos = Vector3.new(-0.15, -0.82, 0.1) },
					Neck = { rot = Vector3.new(26, 4, 0) },
					RightShoulder = { rot = Vector3.new(-44.6, 0, -51.5) },
					LeftShoulder = { rot = Vector3.new(294.9, 0, 66.2) },
					RightHip = { rot = Vector3.new(-5.7, 0, 13.3), pos = Vector3.new(0, 0.935, 0) },
					LeftHip = { rot = Vector3.new(1.3, 0, 10.5), pos = Vector3.new(0, 0.634, 0) },
				},
			},
			{
				time = 1.25,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(13, 0, -8), pos = Vector3.new(-0.15, -0.7, 0.1) },
					Neck = { rot = Vector3.new(34, -4, 0) },
					RightShoulder = { rot = Vector3.new(-70.9, 0, -70.2) },
					LeftShoulder = { rot = Vector3.new(-54.6, 0, 64.5) },
					RightHip = { rot = Vector3.new(-0.8, 0, 11.2), pos = Vector3.new(0, 0.808, 0) },
					LeftHip = { rot = Vector3.new(-11.3, 0, 9.4), pos = Vector3.new(0, 0.532, 0) },
				},
			},
			{
				time = 1.51,
				pose = {
					Root = { rot = Vector3.new(14.6, 0, -6), pos = Vector3.new(-0.15, -0.92, 0.15) },
					Neck = { rot = Vector3.new(26, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-3.8, 0, 11.7), pos = Vector3.new(0, 1.026, 0) },
					LeftHip = { rot = Vector3.new(-5.6, 0, 9.5), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 1.65,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(17, 0, -6), pos = Vector3.new(-0.15, -0.8, 0.15) },
					Neck = { rot = Vector3.new(34, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-7.3, 0, 12), pos = Vector3.new(0, 0.908, 0) },
					LeftHip = { rot = Vector3.new(-9.4, 0, 9.8), pos = Vector3.new(0, 0.625, 0) },
				},
			},
			{
				time = 2.6,
				pose = {
					Root = { rot = Vector3.new(16.4, 0, -6), pos = Vector3.new(-0.15, -0.83, 0.15) },
					Neck = { rot = Vector3.new(32, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-6.4, 0, 12), pos = Vector3.new(0, 0.938, 0) },
					LeftHip = { rot = Vector3.new(-8.4, 0, 9.7), pos = Vector3.new(0, 0.656, 0) },
				},
			},
		},
	},
	Bouncer_ThrowOut = {
		length = 0.95,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 0), pos = Vector3.new(0, -0.15, -0.15) },
					Neck = { rot = Vector3.new(10, 0, 0) },
					RightShoulder = { rot = Vector3.new(140.1, 0, -71.5) },
					LeftShoulder = { rot = Vector3.new(62.8, 0, 67.5) },
					RightHip = { rot = Vector3.new(10, 0, 2.8), pos = Vector3.new(0, 0.142, 0) },
					LeftHip = { rot = Vector3.new(24.4, 0, -2.8), pos = Vector3.new(0, 0.113, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-5.22, -39.88, -7.35),
						pos = Vector3.new(0.15, -0.35, 0.15),
					},
					Neck = { rot = Vector3.new(4, 25, 0) },
					RightShoulder = { rot = Vector3.new(-49.6, 0, -139.9) },
					LeftShoulder = { rot = Vector3.new(62.1, 0, 52.1) },
					RightHip = { rot = Vector3.new(9.5, 0, 9.4), pos = Vector3.new(0, 0.446, 0) },
					LeftHip = { rot = Vector3.new(3.3, 0, -4.9), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.6,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-29.83, 19.31, 10.74),
						pos = Vector3.new(-0.1, -0.45, -0.55),
					},
					Neck = { rot = Vector3.new(18, -10, 0) },
					RightShoulder = { rot = Vector3.new(143.5, 0, -21.1) },
					LeftShoulder = { rot = Vector3.new(126.3, 0, 53.8) },
					RightHip = { rot = Vector3.new(-1.9, 0, -4.7), pos = Vector3.new(0, 0.028, 0) },
					LeftHip = { rot = Vector3.new(58.7, 0, 7.8) },
				},
			},
			{
				time = 0.95,
				pose = {
					Root = {
						rot = Vector3.new(-18.26, 9.51, 3.12),
						pos = Vector3.new(0, -0.3, -0.35),
					},
					Neck = { rot = Vector3.new(12, 0, 0) },
					RightShoulder = { rot = Vector3.new(70.8, 0, -26.1) },
					LeftShoulder = { rot = Vector3.new(68.6, 0, 37.1) },
					RightHip = { rot = Vector3.new(-2.2, 0, 1.2), pos = Vector3.new(0, 0.144, 0) },
					LeftHip = { rot = Vector3.new(44.6, 0, 2.7), pos = Vector3.new(0, 0.017, 0) },
				},
			},
		},
	},
	Bouncer_ThrowVictim = {
		length = 0.6,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-12, 0, 0), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(-10, 0, 0) },
					RightShoulder = { rot = Vector3.new(270.3, 0, -125.9) },
					LeftShoulder = { rot = Vector3.new(270.3, 0, 125.9) },
					RightHip = { rot = Vector3.new(14.8, 0, 1.4), pos = Vector3.new(0, 0.038, 0) },
					LeftHip = { rot = Vector3.new(14.8, 0, -1.4), pos = Vector3.new(0, 0.038, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-21.64, -33.06, -2.21),
						pos = Vector3.new(-0.5, 0.3, -0.2),
					},
					Neck = { rot = Vector3.new(-20, 0, 0) },
					RightShoulder = { rot = Vector3.new(110.1, 0, -89.9) },
					LeftShoulder = { rot = Vector3.new(92.2, 0, 86.2) },
					RightHip = { rot = Vector3.new(-10, 0, 8) },
					LeftHip = { rot = Vector3.new(20, 0, -6) },
				},
			},
			{
				time = 0.6,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(25.34, 9.05, -10.26),
						pos = Vector3.new(0.2, 0.7, 0.4),
					},
					Neck = { rot = Vector3.new(25, 0, 0) },
					RightShoulder = { rot = Vector3.new(120, 0, 50) },
					LeftShoulder = { rot = Vector3.new(130, 0, -50) },
					RightHip = { rot = Vector3.new(30, 0, 12) },
					LeftHip = { rot = Vector3.new(10, 0, -12) },
				},
			},
		},
	},
	Bouncer_FinisherArmRip = {
		length = 4.6,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(18, 0, 0) },
					RightShoulder = { rot = Vector3.new(10, 0, 8) },
					LeftShoulder = { rot = Vector3.new(10, 0, -8) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(-34, 0, 0), pos = Vector3.new(0, -0.9, -0.15) },
					Neck = { rot = Vector3.new(24, 0, 0) },
					RightShoulder = { rot = Vector3.new(57.1, 0, -22.4) },
					LeftShoulder = { rot = Vector3.new(56, 0, 58.3) },
					RightHip = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.9, 0) },
					LeftHip = { rot = Vector3.new(30, 0, 0), pos = Vector3.new(0, 1, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = { rot = Vector3.new(-26, 0, 0), pos = Vector3.new(0, -0.77, 0) },
					Neck = { rot = Vector3.new(30, 0, 0) },
					RightShoulder = { rot = Vector3.new(64.3, 0, -68.4) },
					LeftShoulder = { rot = Vector3.new(56.5, 0, 45.7) },
					RightHip = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, 0.8, 0) },
					LeftHip = { rot = Vector3.new(24, 0, 0), pos = Vector3.new(0, 0.9, 0) },
				},
			},
			{
				time = 0.95,
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, -0.697, 0.25) },
					Neck = { rot = Vector3.new(29.2, 0, 0) },
					RightShoulder = { rot = Vector3.new(48.8, 0, -63.9) },
					LeftShoulder = { rot = Vector3.new(44.1, 0, 41.8) },
					RightHip = { rot = Vector3.new(90, 0, -4.2), pos = Vector3.new(0, 0.228, 0) },
					LeftHip = { rot = Vector3.new(-1.6, 0, 0), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 1.2,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, -0.75, 0.25) },
					Neck = { rot = Vector3.new(23.6, 0, 0) },
					RightShoulder = { rot = Vector3.new(41.6, 0, -68.6) },
					LeftShoulder = { rot = Vector3.new(36.8, 0, 45.1) },
					RightHip = { rot = Vector3.new(82.6, 0, -6) },
					LeftHip = { rot = Vector3.new(-5.8, 0, 0), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 1.4,
				pose = {
					Root = { rot = Vector3.new(-4, 0, 0), pos = Vector3.new(0, -0.705, 0.25) },
					Neck = { rot = Vector3.new(27.6, 0, 0) },
					RightShoulder = { rot = Vector3.new(41, 0, -64.4) },
					LeftShoulder = { rot = Vector3.new(39.1, 0, 41.9) },
					RightHip = { rot = Vector3.new(90, 0, -4.6), pos = Vector3.new(0, 0.068, 0) },
					LeftHip = { rot = Vector3.new(-2.8, 0, 0), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 1.55,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, -0.73, 0.25) },
					Neck = { rot = Vector3.new(22, 0, 0) },
					RightShoulder = { rot = Vector3.new(38.1, 0, -69.5) },
					LeftShoulder = { rot = Vector3.new(34.4, 0, 46.5) },
					RightHip = { rot = Vector3.new(77.7, 0, 0) },
					LeftHip = { rot = Vector3.new(-7, 0, 0), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 1.75,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, -0.72, 0.25) },
					Neck = { rot = Vector3.new(26, 0, 0) },
					RightShoulder = { rot = Vector3.new(37.5, 0, -66.1) },
					LeftShoulder = { rot = Vector3.new(36.6, 0, 43.3) },
					RightHip = { rot = Vector3.new(88, 0, -5.1) },
					LeftHip = { rot = Vector3.new(-4, 0, 0), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 1.9,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(14, 0, 0), pos = Vector3.new(0, -0.717, 0.25) },
					Neck = { rot = Vector3.new(20.4, 0, 0) },
					RightShoulder = { rot = Vector3.new(35.5, 0, -69.6) },
					LeftShoulder = { rot = Vector3.new(32.6, 0, 48.2) },
					RightHip = { rot = Vector3.new(72.9, 0, -7.2) },
					LeftHip = { rot = Vector3.new(-8.2, 0, 0), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 2.15,
				pose = {
					Root = { rot = Vector3.new(4, 0, 0), pos = Vector3.new(0, -0.741, 0.25) },
					Neck = { rot = Vector3.new(24.4, 0, 0) },
					RightShoulder = { rot = Vector3.new(39.5, 0, -70.1) },
					LeftShoulder = { rot = Vector3.new(37.9, 0, 47.1) },
					RightHip = { rot = Vector3.new(84.4, 0, -5.7) },
					LeftHip = { rot = Vector3.new(-5.2, 0, 0), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 2.35,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(18, 0, 0), pos = Vector3.new(0, -0.71, 0.25) },
					Neck = { rot = Vector3.new(18.8, 0, 0) },
					RightShoulder = { rot = Vector3.new(36.7, 0, -69.9) },
					LeftShoulder = { rot = Vector3.new(32.5, 0, 50.1) },
					RightHip = { rot = Vector3.new(68, 0, -7.8) },
					LeftHip = { rot = Vector3.new(-9.4, 0, 0), pos = Vector3.new(0, 0.75, 0) },
				},
			},
			{
				time = 2.6,
				pose = {
					Root = { rot = Vector3.new(14, 0, 0), pos = Vector3.new(0, -0.119, 0.45) },
					Neck = { rot = Vector3.new(10, 0, 0) },
					RightShoulder = { rot = Vector3.new(59.5, 0, -37) },
					LeftShoulder = { rot = Vector3.new(64.3, 0, 42.3) },
					RightHip = { rot = Vector3.new(-24, 0, 0), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(12, 0, 0), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 3,
				pose = {
					Root = { rot = Vector3.new(6, -10, 0), pos = Vector3.new(0, -0.02, 0.2) },
					Neck = { rot = Vector3.new(26, 14, 0) },
					RightShoulder = { rot = Vector3.new(148.4, 0, -28.2) },
					LeftShoulder = { rot = Vector3.new(14.4, 0, -1.3) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 3.4,
				pose = {
					Root = { rot = Vector3.new(6, -16, 0), pos = Vector3.new(0, -0.009, 0.2) },
					Neck = { rot = Vector3.new(24, 20, 0) },
					RightShoulder = { rot = Vector3.new(147.6, 0, -27.6) },
					LeftShoulder = { rot = Vector3.new(4.7, 0, -2.1) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 3.62,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-14, 20, 0), pos = Vector3.new(0, -0.043, -0.1) },
					Neck = { rot = Vector3.new(12, -10, 0) },
					RightShoulder = { rot = Vector3.new(79.8, 0, 28.6) },
					LeftShoulder = { rot = Vector3.new(39.2, 0, 15.6) },
					RightHip = { rot = Vector3.new(-14, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(14, 0, 0), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 4,
				pose = {
					Root = { rot = Vector3.new(-12, 12, 0), pos = Vector3.new(0, 0.022, 0) },
					Neck = { rot = Vector3.new(18, -6, 0) },
					RightShoulder = { rot = Vector3.new(22.1, 0, 9.7) },
					LeftShoulder = { rot = Vector3.new(33.9, 0, 9.4) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 4.6,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(18, 0, 0) },
					RightShoulder = { rot = Vector3.new(6, 0, 6) },
					LeftShoulder = { rot = Vector3.new(6, 0, -6) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},
	Bouncer_FinisherArmRipVictim = {
		length = 2.6,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 30, 0) },
					RightShoulder = { rot = Vector3.new(4, 0, 4) },
					LeftShoulder = { rot = Vector3.new(40, 0, -10) },
					RightHip = { rot = Vector3.new(6, 0, 4) },
					LeftHip = { rot = Vector3.new(4, 0, -4) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(-10, 35, 0) },
					RightShoulder = { rot = Vector3.new(30, 0, 8) },
					LeftShoulder = { rot = Vector3.new(70, 0, 10) },
					RightHip = { rot = Vector3.new(12, 0, 4) },
					LeftHip = { rot = Vector3.new(-1, 0, -4) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = { rot = Vector3.new(0, 6, 0), pos = Vector3.new(0.03, 0, -0.07) },
					Neck = { rot = Vector3.new(-14, 40, 0) },
					RightShoulder = { rot = Vector3.new(92, 0, 20) },
					LeftShoulder = { rot = Vector3.new(90, 0, 30) },
					RightHip = { rot = Vector3.new(0, 0, 4) },
					LeftHip = { rot = Vector3.new(9, 0, -4) },
				},
			},
			{
				time = 0.95,
				pose = {
					Root = { rot = Vector3.new(0, 10, 0), pos = Vector3.new(0.06, 0, -0.14) },
					Neck = { rot = Vector3.new(-20, 35, 0) },
					RightShoulder = { rot = Vector3.new(96, 0, 34) },
					LeftShoulder = { rot = Vector3.new(60, 0, 40) },
					RightHip = { rot = Vector3.new(18, 0, 4) },
					LeftHip = { rot = Vector3.new(-6, 0, -4) },
				},
			},
			{
				time = 1.2,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(0, 20, 0), pos = Vector3.new(0.135, 0, -0.315) },
					Neck = { rot = Vector3.new(-25, 30, 10) },
					RightShoulder = { rot = Vector3.new(100, 0, 52) },
					LeftShoulder = { rot = Vector3.new(100, 0, 60) },
					RightHip = { rot = Vector3.new(-6, 0, 4) },
					LeftHip = { rot = Vector3.new(14, 0, -4) },
				},
			},
			{
				time = 1.4,
				pose = {
					Root = { rot = Vector3.new(0, 12, 0), pos = Vector3.new(0.075, 0, -0.175) },
					Neck = { rot = Vector3.new(-15, 30, 0) },
					RightShoulder = { rot = Vector3.new(98, 0, 42) },
					LeftShoulder = { rot = Vector3.new(40, 0, 30) },
					RightHip = { rot = Vector3.new(13.2, 0, 4) },
					LeftHip = { rot = Vector3.new(-2, 0, -4) },
				},
			},
			{
				time = 1.55,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(0, 24, 0), pos = Vector3.new(0.165, 0, -0.385) },
					Neck = { rot = Vector3.new(-30, 20, 15) },
					RightShoulder = { rot = Vector3.new(104, 0, 60) },
					LeftShoulder = { rot = Vector3.new(110, 0, 70) },
					RightHip = { rot = Vector3.new(-6, 0, 4) },
					LeftHip = { rot = Vector3.new(14, 0, -4) },
				},
			},
			{
				time = 1.75,
				pose = {
					Root = { rot = Vector3.new(0, 16, 0), pos = Vector3.new(0.105, 0, -0.245) },
					Neck = { rot = Vector3.new(-20, 25, 5) },
					RightShoulder = { rot = Vector3.new(100, 0, 50) },
					LeftShoulder = { rot = Vector3.new(60, 0, 40) },
					RightHip = { rot = Vector3.new(18, 0, 4) },
					LeftHip = { rot = Vector3.new(-6, 0, -4) },
				},
			},
			{
				time = 1.9,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(0, 28, 0), pos = Vector3.new(0.195, 0, -0.455) },
					Neck = { rot = Vector3.new(-34, 15, 20) },
					RightShoulder = { rot = Vector3.new(106, 0, 68) },
					LeftShoulder = { rot = Vector3.new(120, 0, 80) },
					RightHip = { rot = Vector3.new(-6, 0, 4) },
					LeftHip = { rot = Vector3.new(14, 0, -4) },
				},
			},
			{
				time = 2.15,
				pose = {
					Root = { rot = Vector3.new(0, 24, 0), pos = Vector3.new(0.165, 0, -0.385) },
					Neck = { rot = Vector3.new(-28, 20, 15) },
					RightShoulder = { rot = Vector3.new(104, 0, 62) },
					LeftShoulder = { rot = Vector3.new(100, 0, 60) },
					RightHip = { rot = Vector3.new(12, 0, 4) },
					LeftHip = { rot = Vector3.new(-1, 0, -4) },
				},
			},
			{
				time = 2.35,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(0, 32, 0), pos = Vector3.new(0.225, 0, -0.525) },
					Neck = { rot = Vector3.new(-36, 10, 25) },
					RightShoulder = { rot = Vector3.new(108, 0, 74) },
					LeftShoulder = { rot = Vector3.new(130, 0, 90) },
					RightHip = { rot = Vector3.new(-6, 0, 4) },
					LeftHip = { rot = Vector3.new(14, 0, -4) },
				},
			},
			{
				time = 2.6,
				pose = {
					Root = { rot = Vector3.new(0, 10, 0), pos = Vector3.new(0.045, 0, -0.105) },
					Neck = { rot = Vector3.new(0, 40, 0) },
					RightShoulder = { rot = Vector3.new(80, 0, 40) },
					LeftShoulder = { rot = Vector3.new(20, 0, 10) },
					RightHip = { rot = Vector3.new(6, 0, 4) },
					LeftHip = { rot = Vector3.new(4, 0, -4) },
				},
			},
		},
	},
}

return table.freeze(clips)
