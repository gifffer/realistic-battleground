--!strict
-- The Bouncer's animations (Shared/Kits/Bouncer), made in code like the others
-- (read the top of CombatClips and MovementClips). Merged into CombatClips.
--
-- How they were made: the hands and feet were placed first (where they must
-- be: on a chest, on top of a head, around a throat, on a wrist), and the
-- joint angles solved from those points on the R6 rig with the same spline
-- as the game, the standing feet kept on the floor; then checked on
-- rendered frames.
--
-- Timing that must not change (Shared/Kits/Bouncer, Shared/Finishers):
--   • Bouncer_Shove: the palms land at 0.22 s; Bouncer_HammerFist at 0.4 s;
--     Bouncer_DoubleHammer at 0.4 and 0.95 s; Bouncer_Grab closes at 0.28 s.
--   • The holds (Bouncer_Choke / Sleeper / Slam / ThrowOut and their *Victim
--     clips) start at the catch and last the grab's `duration`. The victim's
--     root stays where it was caught (anchored, Server/Combat/Grab): its clip
--     moves its body (lifted, slammed). Bouncer_SlamVictim ends on its back
--     with its root at (0, -2.5, +2), turned 90° back: where the server lays
--     it when it lets go.
--   • Bouncer_FinisherArmRip / ...Victim (Shared/Finishers "ArmRip"): the
--     victim laid across in front of him; the arm comes off at 2.35 s and is
--     then held in his right fist (Finishers.ARM_GRIP was measured on these
--     two clips at that moment), thrown at 3.62 s (Finishers.ARM_THROW_FROM).
--     Change them together.

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
					Root = { rot = Vector3.new(-2, -4, 0), pos = Vector3.new(0, 0, 0.2) },
					Neck = { rot = Vector3.new(2, 4, 0) },
					RightShoulder = { rot = Vector3.new(81.3, 0, -34.6) },
					LeftShoulder = { rot = Vector3.new(80.6, 0, 28) },
					RightHip = { rot = Vector3.new(-6, 0, 0), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.22,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-18, 0, 0), pos = Vector3.new(0, -0.358, -0.6) },
					Neck = { rot = Vector3.new(12, 0, 0) },
					RightShoulder = { rot = Vector3.new(101.7, 0, -32.4) },
					LeftShoulder = { rot = Vector3.new(101.7, 0, 32.4) },
					RightHip = { rot = Vector3.new(-26, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(24, 0, 0), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = { rot = Vector3.new(-15, 0, 0), pos = Vector3.new(0, -0.232, -0.5) },
					Neck = { rot = Vector3.new(10, 0, 0) },
					RightShoulder = { rot = Vector3.new(100.2, 0, -31) },
					LeftShoulder = { rot = Vector3.new(100.2, 0, 31) },
					RightHip = { rot = Vector3.new(-22, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(20, 0, 0), pos = Vector3.new(0, 0.35, 0) },
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
				time = 0.14,
				pose = {
					Root = { rot = Vector3.new(-12, 0, 0), pos = Vector3.new(0, -0.119, -0.3) },
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(121, 0, 3.2) },
					LeftShoulder = { rot = Vector3.new(121, 0, -3.2) },
					RightHip = { rot = Vector3.new(-16, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(18, 0, 0), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.28,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-16, 0, 0), pos = Vector3.new(0, -0.251, -0.55) },
					Neck = { rot = Vector3.new(10, 0, 0) },
					RightShoulder = { rot = Vector3.new(122.5, 0, -35.4) },
					LeftShoulder = { rot = Vector3.new(122.5, 0, 35.4) },
					RightHip = { rot = Vector3.new(-22, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(22, 0, 0), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = { rot = Vector3.new(-10, -4, 0), pos = Vector3.new(0, -0.023, -0.3) },
					Neck = { rot = Vector3.new(6, 4, 0) },
					RightShoulder = { rot = Vector3.new(112.1, 0, -37.4) },
					LeftShoulder = { rot = Vector3.new(114.8, 0, 34.5) },
					RightHip = { rot = Vector3.new(-12, 0, 0), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(12, 0, 0), pos = Vector3.new(0, 0.25, 0) },
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
				time = 0.22,
				pose = {
					Root = { rot = Vector3.new(4, 0, 0), pos = Vector3.new(0, -0.002, 0.15) },
					Neck = { rot = Vector3.new(-8, 0, 0) },
					RightShoulder = { rot = Vector3.new(173, 0, -38.9) },
					LeftShoulder = { rot = Vector3.new(173, 0, 38.9) },
					RightHip = { rot = Vector3.new(-4, 0, 0) },
					LeftHip = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.4,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-22, 0, 0), pos = Vector3.new(0, -0.463, -0.7) },
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(154.9, 0, -45.8) },
					LeftShoulder = { rot = Vector3.new(154.9, 0, 45.8) },
					RightHip = { rot = Vector3.new(-24, 0, 0), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(24, 0, 0), pos = Vector3.new(0, 0.45, 0) },
				},
			},
			{
				time = 0.56,
				pose = {
					Root = { rot = Vector3.new(-20, 0, 0), pos = Vector3.new(0, -0.38, -0.6) },
					Neck = { rot = Vector3.new(12, 0, 0) },
					RightShoulder = { rot = Vector3.new(113.6, 0, -47.1) },
					LeftShoulder = { rot = Vector3.new(113.6, 0, 47.1) },
					RightHip = { rot = Vector3.new(-22, 0, 0), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(22, 0, 0), pos = Vector3.new(0, 0.4, 0) },
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
				time = 0.22,
				pose = {
					Root = { rot = Vector3.new(4, 0, 0), pos = Vector3.new(0, -0.002, 0.15) },
					Neck = { rot = Vector3.new(-8, 0, 0) },
					RightShoulder = { rot = Vector3.new(173, 0, -38.9) },
					LeftShoulder = { rot = Vector3.new(173, 0, 38.9) },
					RightHip = { rot = Vector3.new(-4, 0, 0) },
					LeftHip = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.4,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-22, 0, 0), pos = Vector3.new(0, -0.463, -0.7) },
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(154.9, 0, -45.8) },
					LeftShoulder = { rot = Vector3.new(154.9, 0, 45.8) },
					RightHip = { rot = Vector3.new(-24, 0, 0), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(24, 0, 0), pos = Vector3.new(0, 0.45, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, 0.011, 0.15) },
					Neck = { rot = Vector3.new(-8, 0, 0) },
					RightShoulder = { rot = Vector3.new(170.3, 0, -38.9) },
					LeftShoulder = { rot = Vector3.new(170.3, 0, 38.9) },
					RightHip = { rot = Vector3.new(-4, 0, 0) },
					LeftHip = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.95,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-22, 0, 0), pos = Vector3.new(0, -0.463, -0.7) },
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(154.9, 0, -45.8) },
					LeftShoulder = { rot = Vector3.new(154.9, 0, 45.8) },
					RightHip = { rot = Vector3.new(-24, 0, 0), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(24, 0, 0), pos = Vector3.new(0, 0.45, 0) },
				},
			},
			{
				time = 1.1,
				pose = {
					Root = { rot = Vector3.new(-20, 0, 0), pos = Vector3.new(0, -0.38, -0.6) },
					Neck = { rot = Vector3.new(12, 0, 0) },
					RightShoulder = { rot = Vector3.new(113.6, 0, -47.1) },
					LeftShoulder = { rot = Vector3.new(113.6, 0, 47.1) },
					RightHip = { rot = Vector3.new(-22, 0, 0), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(22, 0, 0), pos = Vector3.new(0, 0.4, 0) },
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
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(4, 0, 0), pos = Vector3.new(0, 0.028, 0) },
					Neck = { rot = Vector3.new(0, 0, 28) },
					RightShoulder = { rot = Vector3.new(14, 0, 22) },
					LeftShoulder = { rot = Vector3.new(14, 0, -22) },
				},
			},
			{
				time = 0.36,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(4, 0, 0), pos = Vector3.new(0, 0.028, 0) },
					Neck = { rot = Vector3.new(0, 0, -28) },
					RightShoulder = { rot = Vector3.new(14, 0, 22) },
					LeftShoulder = { rot = Vector3.new(14, 0, -22) },
				},
			},
			{
				time = 0.62,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.04, 0) },
					Neck = { rot = Vector3.new(-10, 0, 0) },
					RightShoulder = { rot = Vector3.new(28, 0, 34) },
					LeftShoulder = { rot = Vector3.new(28, 0, -34) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.04, 0) },
					Neck = { rot = Vector3.new(-10, 0, 0) },
					RightShoulder = { rot = Vector3.new(26, 0, 32) },
					LeftShoulder = { rot = Vector3.new(26, 0, -32) },
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
	Bouncer_Choke = {
		length = 1.9,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(2, 28, 0), pos = Vector3.new(0, -0.058, -0.15) },
					Neck = { rot = Vector3.new(10, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.5, 0, -49.3) },
					LeftShoulder = { rot = Vector3.new(150.9, 0, 66.9) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.33,
				pose = {
					Root = { rot = Vector3.new(2.8, 32, 0), pos = Vector3.new(0, -0.062, -0.15) },
					Neck = { rot = Vector3.new(11.2, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -46.7) },
					LeftShoulder = { rot = Vector3.new(150.2, 0, 68) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.45,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(6, 24, 0), pos = Vector3.new(0, -0.087, -0.15) },
					Neck = { rot = Vector3.new(16, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -52.9) },
					LeftShoulder = { rot = Vector3.new(145.4, 0, 66.5) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.73,
				pose = {
					Root = { rot = Vector3.new(2.8, 32, 0), pos = Vector3.new(0, -0.062, -0.15) },
					Neck = { rot = Vector3.new(11.2, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -46.7) },
					LeftShoulder = { rot = Vector3.new(150.2, 0, 68) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.85,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(6, 24, 0), pos = Vector3.new(0, -0.087, -0.15) },
					Neck = { rot = Vector3.new(16, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -52.9) },
					LeftShoulder = { rot = Vector3.new(145.4, 0, 66.5) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 1.13,
				pose = {
					Root = { rot = Vector3.new(2.8, 32, 0), pos = Vector3.new(0, -0.062, -0.15) },
					Neck = { rot = Vector3.new(11.2, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -46.7) },
					LeftShoulder = { rot = Vector3.new(150.2, 0, 68) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 1.25,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(6, 24, 0), pos = Vector3.new(0, -0.087, -0.15) },
					Neck = { rot = Vector3.new(16, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -52.9) },
					LeftShoulder = { rot = Vector3.new(145.4, 0, 66.5) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 1.75,
				pose = {
					Root = { rot = Vector3.new(3.2, 28, 0), pos = Vector3.new(0, -0.065, -0.15) },
					Neck = { rot = Vector3.new(11.8, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.5, 0, -49.6) },
					LeftShoulder = { rot = Vector3.new(149.3, 0, 67.1) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 1.9,
				pose = {
					Root = { rot = Vector3.new(-4, -6, 0), pos = Vector3.new(0, 0.035, 0) },
					Neck = { rot = Vector3.new(4, 6, 0) },
					RightShoulder = { rot = Vector3.new(97.9, 0, -35.7) },
					LeftShoulder = { rot = Vector3.new(107, 0, 37.3) },
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
					Root = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.006, 0) },
					Neck = { rot = Vector3.new(16, 0, 0) },
					RightShoulder = { rot = Vector3.new(110.2, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(113.1, 0, 43.9) },
					RightHip = { rot = Vector3.new(0, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.33,
				pose = {
					Root = { rot = Vector3.new(8.5, 0, 0), pos = Vector3.new(0, -0.011, 0) },
					Neck = { rot = Vector3.new(16.8, 0, 0) },
					RightShoulder = { rot = Vector3.new(109.3, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(112.5, 0, 43.8) },
					RightHip = { rot = Vector3.new(14, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = { rot = Vector3.new(13, 0, 0), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(24, 0, 0) },
					RightShoulder = { rot = Vector3.new(101, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(107.4, 0, 43.2) },
					RightHip = { rot = Vector3.new(-14, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.73,
				pose = {
					Root = { rot = Vector3.new(8.5, 0, 0), pos = Vector3.new(0, -0.011, 0) },
					Neck = { rot = Vector3.new(16.8, 0, 0) },
					RightShoulder = { rot = Vector3.new(109.3, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(112.5, 0, 43.8) },
					RightHip = { rot = Vector3.new(14, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.85,
				pose = {
					Root = { rot = Vector3.new(13, 0, 0), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(24, 0, 0) },
					RightShoulder = { rot = Vector3.new(101, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(107.4, 0, 43.2) },
					RightHip = { rot = Vector3.new(-14, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 1.13,
				pose = {
					Root = { rot = Vector3.new(8.5, 0, 0), pos = Vector3.new(0, -0.011, 0) },
					Neck = { rot = Vector3.new(16.8, 0, 0) },
					RightShoulder = { rot = Vector3.new(109.3, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(112.5, 0, 43.8) },
					RightHip = { rot = Vector3.new(14, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 1.25,
				pose = {
					Root = { rot = Vector3.new(13, 0, 0), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(24, 0, 0) },
					RightShoulder = { rot = Vector3.new(101, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(107.4, 0, 43.2) },
					RightHip = { rot = Vector3.new(-14, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 1.75,
				pose = {
					Root = { rot = Vector3.new(10.5, 0, 0), pos = Vector3.new(0, 0.006, 0) },
					Neck = { rot = Vector3.new(20, 0, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(110.2, 0, 43.6) },
					RightHip = { rot = Vector3.new(0, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 1.9,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 0), pos = Vector3.new(0, 0.032, 0) },
					Neck = { rot = Vector3.new(16, 0, 0) },
					RightShoulder = { rot = Vector3.new(131.7, 0, -48.9) },
					LeftShoulder = { rot = Vector3.new(131.7, 0, 48.9) },
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
					Root = { rot = Vector3.new(2, 28, 0), pos = Vector3.new(0, -0.058, -0.15) },
					Neck = { rot = Vector3.new(10, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.5, 0, -49.3) },
					LeftShoulder = { rot = Vector3.new(150.9, 0, 66.9) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.33,
				pose = {
					Root = { rot = Vector3.new(2.8, 32, 0), pos = Vector3.new(0, -0.062, -0.15) },
					Neck = { rot = Vector3.new(11.2, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -46.7) },
					LeftShoulder = { rot = Vector3.new(150.2, 0, 68) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.45,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(6, 24, 0), pos = Vector3.new(0, -0.087, -0.15) },
					Neck = { rot = Vector3.new(16, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -52.9) },
					LeftShoulder = { rot = Vector3.new(145.4, 0, 66.5) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.73,
				pose = {
					Root = { rot = Vector3.new(2.8, 32, 0), pos = Vector3.new(0, -0.062, -0.15) },
					Neck = { rot = Vector3.new(11.2, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -46.7) },
					LeftShoulder = { rot = Vector3.new(150.2, 0, 68) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.85,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(6, 24, 0), pos = Vector3.new(0, -0.087, -0.15) },
					Neck = { rot = Vector3.new(16, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -52.9) },
					LeftShoulder = { rot = Vector3.new(145.4, 0, 66.5) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 1.13,
				pose = {
					Root = { rot = Vector3.new(2.8, 32, 0), pos = Vector3.new(0, -0.062, -0.15) },
					Neck = { rot = Vector3.new(11.2, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -46.7) },
					LeftShoulder = { rot = Vector3.new(150.2, 0, 68) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 1.25,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(6, 24, 0), pos = Vector3.new(0, -0.087, -0.15) },
					Neck = { rot = Vector3.new(16, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -52.9) },
					LeftShoulder = { rot = Vector3.new(145.4, 0, 66.5) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 1.53,
				pose = {
					Root = { rot = Vector3.new(2.8, 32, 0), pos = Vector3.new(0, -0.062, -0.15) },
					Neck = { rot = Vector3.new(11.2, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -46.7) },
					LeftShoulder = { rot = Vector3.new(150.2, 0, 68) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 1.65,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(6, 24, 0), pos = Vector3.new(0, -0.087, -0.15) },
					Neck = { rot = Vector3.new(16, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -52.9) },
					LeftShoulder = { rot = Vector3.new(145.4, 0, 66.5) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 2.6,
				pose = {
					Root = { rot = Vector3.new(4.4, 28, 0), pos = Vector3.new(0, -0.073, -0.15) },
					Neck = { rot = Vector3.new(13.6, -24, 0) },
					RightShoulder = { rot = Vector3.new(105.5, 0, -49.9) },
					LeftShoulder = { rot = Vector3.new(147.8, 0, 67.3) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.25, 0) },
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
					Root = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.006, 0) },
					Neck = { rot = Vector3.new(16, 0, 0) },
					RightShoulder = { rot = Vector3.new(110.2, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(113.1, 0, 43.9) },
					RightHip = { rot = Vector3.new(0, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.33,
				pose = {
					Root = { rot = Vector3.new(8.5, 0, 0), pos = Vector3.new(0, -0.011, 0) },
					Neck = { rot = Vector3.new(16.8, 0, 0) },
					RightShoulder = { rot = Vector3.new(109.3, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(112.5, 0, 43.8) },
					RightHip = { rot = Vector3.new(14, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = { rot = Vector3.new(13, 0, 0), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(24, 0, 0) },
					RightShoulder = { rot = Vector3.new(101, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(107.4, 0, 43.2) },
					RightHip = { rot = Vector3.new(-14, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.73,
				pose = {
					Root = { rot = Vector3.new(8.5, 0, 0), pos = Vector3.new(0, -0.011, 0) },
					Neck = { rot = Vector3.new(16.8, 0, 0) },
					RightShoulder = { rot = Vector3.new(109.3, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(112.5, 0, 43.8) },
					RightHip = { rot = Vector3.new(14, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.85,
				pose = {
					Root = { rot = Vector3.new(13, 0, 0), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(24, 0, 0) },
					RightShoulder = { rot = Vector3.new(101, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(107.4, 0, 43.2) },
					RightHip = { rot = Vector3.new(-14, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 1.13,
				pose = {
					Root = { rot = Vector3.new(8.5, 0, 0), pos = Vector3.new(0, -0.001, 0) },
					Neck = { rot = Vector3.new(16.8, 0, 0) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(10, 0, -6) },
					RightHip = { rot = Vector3.new(12, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 1.25,
				pose = {
					Root = { rot = Vector3.new(13, 0, 0), pos = Vector3.new(0, -0.001, 0) },
					Neck = { rot = Vector3.new(24, 0, 0) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(10, 0, -6) },
					RightHip = { rot = Vector3.new(-2, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 1.53,
				pose = {
					Root = { rot = Vector3.new(8.5, 0, 0), pos = Vector3.new(0, 0.007, 0) },
					Neck = { rot = Vector3.new(16.8, 0, 0) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(10, 0, -6) },
					RightHip = { rot = Vector3.new(10, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 1.65,
				pose = {
					Root = { rot = Vector3.new(13, 0, 0), pos = Vector3.new(0, -0.027, 0) },
					Neck = { rot = Vector3.new(24, 0, 0) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(10, 0, -6) },
					RightHip = { rot = Vector3.new(10, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 2.6,
				pose = {
					Root = { rot = Vector3.new(13, 0, 0), pos = Vector3.new(0, -0.027, 0) },
					Neck = { rot = Vector3.new(24, 0, 0) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(10, 0, -6) },
					RightHip = { rot = Vector3.new(10, 0, 4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, -4), pos = Vector3.new(0, 0.15, 0) },
				},
			},
		},
	},
	Bouncer_Slam = {
		length = 1,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-22, 0, 0), pos = Vector3.new(0, -0.485, -0.25) },
					Neck = { rot = Vector3.new(16, 0, 0) },
					RightShoulder = { rot = Vector3.new(102.8, 0, -15.6) },
					LeftShoulder = { rot = Vector3.new(102.8, 0, 15.6) },
					RightHip = { rot = Vector3.new(-14, 0, 0), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(26, 0, 0), pos = Vector3.new(0, 0.55, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, -0.043, 0) },
					Neck = { rot = Vector3.new(-6, 0, 0) },
					RightShoulder = { rot = Vector3.new(127.6, 0, -28.2) },
					LeftShoulder = { rot = Vector3.new(127.6, 0, 28.2) },
					RightHip = { rot = Vector3.new(-6, 0, 0), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.58,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(12, 0, 0), pos = Vector3.new(0, 0.028, 0.1) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(149, 0, -28.4) },
					LeftShoulder = { rot = Vector3.new(149, 0, 28.4) },
					RightHip = { rot = Vector3.new(-4, 0, 0) },
					LeftHip = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.85,
				pose = {
					Root = { rot = Vector3.new(-30, 0, 0), pos = Vector3.new(0, -0.654, -0.4) },
					Neck = { rot = Vector3.new(18, 0, 0) },
					RightShoulder = { rot = Vector3.new(131.2, 0, -30.7) },
					LeftShoulder = { rot = Vector3.new(131.2, 0, 30.7) },
					RightHip = { rot = Vector3.new(-18, 0, 0), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(30, 0, 0), pos = Vector3.new(0, 0.6, 0) },
				},
			},
			{
				time = 1,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-42, 0, 0), pos = Vector3.new(0, -0.81, -0.5) },
					Neck = { rot = Vector3.new(24, 0, 0) },
					RightShoulder = { rot = Vector3.new(103.2, 0, -26.9) },
					LeftShoulder = { rot = Vector3.new(103.2, 0, 26.9) },
					RightHip = { rot = Vector3.new(-20, 0, 0), pos = Vector3.new(0, 0.5, 0) },
					LeftHip = { rot = Vector3.new(36, 0, 0), pos = Vector3.new(0, 0.8, 0) },
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
					Root = { rot = Vector3.new(-24, 0, 0), pos = Vector3.new(0, -0.036, -0.1) },
					Neck = { rot = Vector3.new(-10, 0, 0) },
					RightShoulder = { rot = Vector3.new(70, 0, 30) },
					LeftShoulder = { rot = Vector3.new(70, 0, -30) },
					RightHip = { rot = Vector3.new(4, 0, 0) },
					LeftHip = { rot = Vector3.new(-4, 0, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(30, 0, 0), pos = Vector3.new(0, 1.6, -0.9) },
					Neck = { rot = Vector3.new(-14, 0, 0) },
					RightShoulder = { rot = Vector3.new(120, 0, 50) },
					LeftShoulder = { rot = Vector3.new(110, 0, -50) },
					RightHip = { rot = Vector3.new(-10, 0, 6) },
					LeftHip = { rot = Vector3.new(14, 0, -6) },
				},
			},
			{
				time = 0.58,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(90, 0, 0), pos = Vector3.new(0, 3.3, -1.5) },
					Neck = { rot = Vector3.new(-20, 0, 0) },
					RightShoulder = { rot = Vector3.new(150, 0, 70) },
					LeftShoulder = { rot = Vector3.new(140, 0, -70) },
					RightHip = { rot = Vector3.new(-16, 0, 8) },
					LeftHip = { rot = Vector3.new(10, 0, -8) },
				},
			},
			{
				time = 0.85,
				pose = {
					Root = { rot = Vector3.new(100, 0, 0), pos = Vector3.new(0, 0, 1.5) },
					Neck = { rot = Vector3.new(-10, 0, 0) },
					RightShoulder = { rot = Vector3.new(160, 0, 60) },
					LeftShoulder = { rot = Vector3.new(160, 0, -60) },
					RightHip = { rot = Vector3.new(-20, 0, 10) },
					LeftHip = { rot = Vector3.new(-6, 0, -10) },
				},
			},
			{
				time = 1,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(90, 0, 0), pos = Vector3.new(0, -2.5, 2) },
					Neck = { rot = Vector3.new(6, 0, 0) },
					RightShoulder = { rot = Vector3.new(170, 0, 40) },
					LeftShoulder = { rot = Vector3.new(170, 0, -40) },
					RightHip = { rot = Vector3.new(10, 0, 8) },
					LeftHip = { rot = Vector3.new(24, 0, -8) },
				},
			},
		},
	},
	Bouncer_ThrowOut = {
		length = 0.6,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-10, -40, 0), pos = Vector3.new(0, -0.069, -0.1) },
					Neck = { rot = Vector3.new(8, 30, 0) },
					RightShoulder = { rot = Vector3.new(119.8, 0, -64.3) },
					LeftShoulder = { rot = Vector3.new(49.8, 0, 16.6) },
					RightHip = { rot = Vector3.new(-10, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(14, 0, 0), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.32,
				pose = {
					Root = { rot = Vector3.new(2, -55, 0), pos = Vector3.new(0, -0.012, 0.1) },
					Neck = { rot = Vector3.new(0, 40, 0) },
					RightShoulder = { rot = Vector3.new(118.1, 0, -69.2) },
					LeftShoulder = { rot = Vector3.new(46.8, 0, -2.6) },
					RightHip = { rot = Vector3.new(-14, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.6,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-24, 25, 0), pos = Vector3.new(0, -0.367, -0.55) },
					Neck = { rot = Vector3.new(14, -20, 0) },
					RightShoulder = { rot = Vector3.new(148.7, 0, -9.9) },
					LeftShoulder = { rot = Vector3.new(113.6, 0, 51.2) },
					RightHip = { rot = Vector3.new(-26, 0, 0), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(26, 0, 0), pos = Vector3.new(0, 0.45, 0) },
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
					Root = { rot = Vector3.new(-10, 0, 0), pos = Vector3.new(0, 0.2, -0.1) },
					Neck = { rot = Vector3.new(-12, 0, 0) },
					RightShoulder = { rot = Vector3.new(80, 0, 20) },
					LeftShoulder = { rot = Vector3.new(80, 0, -20) },
					RightHip = { rot = Vector3.new(6, 0, 0) },
					LeftHip = { rot = Vector3.new(-6, 0, 0) },
				},
			},
			{
				time = 0.32,
				pose = {
					Root = { rot = Vector3.new(-8, 50, 10), pos = Vector3.new(0.3, 0.6, -0.2) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(90, 0, 40) },
					LeftShoulder = { rot = Vector3.new(60, 0, -50) },
					RightHip = { rot = Vector3.new(10, 0, 8) },
					LeftHip = { rot = Vector3.new(-14, 0, -8) },
				},
			},
			{
				time = 0.6,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(24, -20, 0), pos = Vector3.new(0, 0.8, 0.3) },
					Neck = { rot = Vector3.new(-20, 0, 0) },
					RightShoulder = { rot = Vector3.new(140, 0, 60) },
					LeftShoulder = { rot = Vector3.new(140, 0, -60) },
					RightHip = { rot = Vector3.new(20, 0, 10) },
					LeftHip = { rot = Vector3.new(30, 0, -10) },
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
