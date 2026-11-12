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
-- Sampled densely (a key every 0.06 s, plus the authored ones): between keys
-- the torsos follow a spline and a rotation spline, feet step in arcs, and
-- every hand / foot is solved again on every key, so contacts hold all the
-- way through; the held fighter struggles (legs kicking, arms flailing).
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
--   • Bone_Throw: throwing what you hold (Shared/Weapons): it leaves the
--     hand at 0.24 s (WeaponDef.release). Solved with the bone's grip in
--     WeaponFx (GRIP).

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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(1.53, -8.39, 0.55),
						pos = Vector3.new(0, -0.136, 0.198),
					},
					Neck = { rot = Vector3.new(4.18, 6.767, 0) },
					RightShoulder = { rot = Vector3.new(91.2, 0, -40.9) },
					LeftShoulder = { rot = Vector3.new(93.3, 0, 33.8) },
					RightHip = { rot = Vector3.new(-3.3, 0, 1.8), pos = Vector3.new(0, 0.267, 0) },
					LeftHip = { rot = Vector3.new(1.1, 0, -3), pos = Vector3.new(0, 0.16, 0) },
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
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(2.1, -4.8, 0.22),
						pos = Vector3.new(0, -0.286, 0.156),
					},
					Neck = { rot = Vector3.new(5.246, 3.072, 0) },
					RightShoulder = { rot = Vector3.new(85.4, 0, -39.6) },
					LeftShoulder = { rot = Vector3.new(85.3, 0, 32.3) },
					RightHip = { rot = Vector3.new(-10.3, 0, 3.5), pos = Vector3.new(0, 0.344, 0) },
					LeftHip = { rot = Vector3.new(1.3, 0, -3.3), pos = Vector3.new(0, 0.501, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-11.54, -1.53, -0.15),
						pos = Vector3.new(0, -0.377, -0.365),
					},
					Neck = { rot = Vector3.new(11.731, 0.633, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -35.6) },
					LeftShoulder = { rot = Vector3.new(105.8, 0, 33) },
					RightHip = { rot = Vector3.new(-14.1, 0, 3.4), pos = Vector3.new(0, 0.279, 0) },
					LeftHip = { rot = Vector3.new(24.3, 0, -3.3), pos = Vector3.new(0, 0.681, 0) },
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
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-22.06, 0.45, 0.1),
						pos = Vector3.new(0, -0.398, -0.55),
					},
					Neck = { rot = Vector3.new(13.911, -0.06, 0) },
					RightShoulder = { rot = Vector3.new(118.9, 0, -33.5) },
					LeftShoulder = { rot = Vector3.new(118.8, 0, 34.3) },
					RightHip = { rot = Vector3.new(-6.6, 0, 2.7), pos = Vector3.new(0, 0.107, 0) },
					LeftHip = { rot = Vector3.new(45.7, 0, -2.6), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-20.77, 0.65, 0.17),
						pos = Vector3.new(0, -0.376, -0.535),
					},
					Neck = { rot = Vector3.new(12.899, -0.381, 0) },
					RightShoulder = { rot = Vector3.new(119.3, 0, -32.5) },
					LeftShoulder = { rot = Vector3.new(119.2, 0, 33.7) },
					RightHip = { rot = Vector3.new(-7.9, 0, 2.5), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(44.6, 0, -2.6), pos = Vector3.new(0, 0.169, 0) },
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
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-15.19, -0.51, -0.13),
						pos = Vector3.new(0, -0.335, -0.471),
					},
					Neck = { rot = Vector3.new(11.542, 0.515, 0) },
					RightShoulder = { rot = Vector3.new(112.7, 0, -32.6) },
					LeftShoulder = { rot = Vector3.new(112.9, 0, 32) },
					RightHip = { rot = Vector3.new(-13.5, 0, 3.2), pos = Vector3.new(0, 0.127, 0) },
					LeftHip = { rot = Vector3.new(37, 0, -3), pos = Vector3.new(0, 0.248, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-10.96, -2.57, -0.57),
						pos = Vector3.new(0, -0.283, -0.357),
					},
					Neck = { rot = Vector3.new(9.959, 2.783, 0) },
					RightShoulder = { rot = Vector3.new(111.4, 0, -34.4) },
					LeftShoulder = { rot = Vector3.new(113.3, 0, 34.5) },
					RightHip = { rot = Vector3.new(-11.2, 0, 4.1), pos = Vector3.new(0, 0.274, 0) },
					LeftHip = { rot = Vector3.new(27, 0, -3.3), pos = Vector3.new(0, 0.376, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-8.49, -5.09, -0.83),
						pos = Vector3.new(0, -0.222, -0.235),
					},
					Neck = { rot = Vector3.new(8.421, 5.295, 0) },
					RightShoulder = { rot = Vector3.new(112.4, 0, -36.3) },
					LeftShoulder = { rot = Vector3.new(116.3, 0, 37.6) },
					RightHip = { rot = Vector3.new(-5.2, 0, 4.5), pos = Vector3.new(0, 0.237, 0) },
					LeftHip = { rot = Vector3.new(20.9, 0, -3.7), pos = Vector3.new(0, 0.253, 0) },
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
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-7.66, -7.6, -0.71),
						pos = Vector3.new(0, -0.141, -0.13),
					},
					Neck = { rot = Vector3.new(7.233, 7.396, 0) },
					RightShoulder = { rot = Vector3.new(108.2, 0, -37.3) },
					LeftShoulder = { rot = Vector3.new(112.7, 0, 35.4) },
					RightHip = { rot = Vector3.new(-0.7, 0, 3.6), pos = Vector3.new(0, 0.219, 0) },
					LeftHip = { rot = Vector3.new(18.9, 0, -4.1), pos = Vector3.new(0, 0.261, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-7.83, -10, -0.33),
						pos = Vector3.new(0, -0.039, -0.034),
					},
					Neck = { rot = Vector3.new(6.303, 9.321, 0) },
					RightShoulder = { rot = Vector3.new(108.9, 0, -37.1) },
					LeftShoulder = { rot = Vector3.new(113.2, 0, 35.8) },
					RightHip = { rot = Vector3.new(7.7, 0, 0.1), pos = Vector3.new(0, 0.118, 0) },
					LeftHip = { rot = Vector3.new(13.6, 0, -2.9), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 0.65,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-8.56, -5.44, -0.04),
						pos = Vector3.new(0, -0.129, 0.052),
					},
					Neck = { rot = Vector3.new(6.571, 5.536, 0) },
					RightShoulder = { rot = Vector3.new(111.5, 0, -19.5) },
					LeftShoulder = { rot = Vector3.new(116.1, 0, 15.2) },
					RightHip = { rot = Vector3.new(10.2, 0, 0.6), pos = Vector3.new(0, 0.116, 0) },
					LeftHip = { rot = Vector3.new(16.4, 0, -3), pos = Vector3.new(0, 0.131, 0) },
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
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-14.05, 1.85, 0.15),
						pos = Vector3.new(0, -0.365, -0.166),
					},
					Neck = { rot = Vector3.new(10.568, -0.837, 0) },
					RightShoulder = { rot = Vector3.new(132.2, 0, -7.9) },
					LeftShoulder = { rot = Vector3.new(130.1, 0, 11.4) },
					RightHip = { rot = Vector3.new(2.3, 0, 2.7), pos = Vector3.new(0, 0.444, 0) },
					LeftHip = { rot = Vector3.new(25.3, 0, -2.2), pos = Vector3.new(0, 0.571, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-18.45, 1.06, 0.16),
						pos = Vector3.new(0, -0.395, -0.427),
					},
					Neck = { rot = Vector3.new(13.277, -0.268, 0) },
					RightShoulder = { rot = Vector3.new(135.9, 0, -32.3) },
					LeftShoulder = { rot = Vector3.new(135.4, 0, 33.8) },
					RightHip = { rot = Vector3.new(-3.9, 0, 2.6), pos = Vector3.new(0, 0.317, 0) },
					LeftHip = { rot = Vector3.new(35.1, 0, -2.4), pos = Vector3.new(0, 0.487, 0) },
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
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-20.04, -0.5, -0.12),
						pos = Vector3.new(0, -0.398, -0.495),
					},
					Neck = { rot = Vector3.new(13.81, 0.104, 0) },
					RightShoulder = { rot = Vector3.new(137, 0, -39) },
					LeftShoulder = { rot = Vector3.new(137.1, 0, 38.3) },
					RightHip = { rot = Vector3.new(-3.6, 0, 3), pos = Vector3.new(0, 0.203, 0) },
					LeftHip = { rot = Vector3.new(40.1, 0, -3), pos = Vector3.new(0, 0.254, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-17.75, -1.85, -0.5),
						pos = Vector3.new(0, -0.373, -0.433),
					},
					Neck = { rot = Vector3.new(11.644, 1.349, 0) },
					RightShoulder = { rot = Vector3.new(132.6, 0, -39.4) },
					LeftShoulder = { rot = Vector3.new(133.3, 0, 37.4) },
					RightHip = { rot = Vector3.new(-2.8, 0, 3.6), pos = Vector3.new(0, 0.235, 0) },
					LeftHip = { rot = Vector3.new(35.1, 0, -3.3), pos = Vector3.new(0, 0.273, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-13.82, -3.17, -0.78),
						pos = Vector3.new(0, -0.328, -0.341),
					},
					Neck = { rot = Vector3.new(8.882, 3.186, 0) },
					RightShoulder = { rot = Vector3.new(124.5, 0, -39.2) },
					LeftShoulder = { rot = Vector3.new(125.9, 0, 36.2) },
					RightHip = { rot = Vector3.new(-3.1, 0, 4.1), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(28.7, 0, -3.4), pos = Vector3.new(0, 0.265, 0) },
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
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-10.7, -4.74, -0.83),
						pos = Vector3.new(0, -0.266, -0.26),
					},
					Neck = { rot = Vector3.new(7.478, 4.792, 0) },
					RightShoulder = { rot = Vector3.new(116.5, 0, -39.2) },
					LeftShoulder = { rot = Vector3.new(118.6, 0, 34.2) },
					RightHip = { rot = Vector3.new(-3.8, 0, 4.2), pos = Vector3.new(0, 0.267, 0) },
					LeftHip = { rot = Vector3.new(24.8, 0, -3.7), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-9.24, -6.59, -0.68),
						pos = Vector3.new(0, -0.176, -0.167),
					},
					Neck = { rot = Vector3.new(6.707, 6.651, 0) },
					RightShoulder = { rot = Vector3.new(110.5, 0, -38.8) },
					LeftShoulder = { rot = Vector3.new(113.5, 0, 33.3) },
					RightHip = { rot = Vector3.new(-0.2, 0, 3.1), pos = Vector3.new(0, 0.275, 0) },
					LeftHip = { rot = Vector3.new(20.3, 0, -3.6), pos = Vector3.new(0, 0.354, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-8.75, -8.62, -0.44),
						pos = Vector3.new(0, -0.083, -0.077),
					},
					Neck = { rot = Vector3.new(6.247, 8.459, 0) },
					RightShoulder = { rot = Vector3.new(109.1, 0, -38) },
					LeftShoulder = { rot = Vector3.new(112.7, 0, 34.3) },
					RightHip = { rot = Vector3.new(5.9, 0, 0.9), pos = Vector3.new(0, 0.192, 0) },
					LeftHip = { rot = Vector3.new(16, 0, -3), pos = Vector3.new(0, 0.293, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-8.46, -10.68, -0.18),
						pos = Vector3.new(0, -0.015, -0.014),
					},
					Neck = { rot = Vector3.new(6.035, 9.716, 0) },
					RightShoulder = { rot = Vector3.new(110.4, 0, -36.9) },
					LeftShoulder = { rot = Vector3.new(114.3, 0, 36.3) },
					RightHip = { rot = Vector3.new(11.1, 0, -1.4), pos = Vector3.new(0, 0.04, 0) },
					LeftHip = { rot = Vector3.new(12.8, 0, -2.6), pos = Vector3.new(0, 0.136, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-2.05, -8.04, 0.42),
						pos = Vector3.new(0, 0.041, 0.073),
					},
					Neck = { rot = Vector3.new(1.608, 8.155, 0) },
					RightShoulder = { rot = Vector3.new(124.2, 0, -40.2) },
					LeftShoulder = { rot = Vector3.new(128.2, 0, 40.9) },
					RightHip = { rot = Vector3.new(2.8, 0, -0.3), pos = Vector3.new(0, 0.026, 0) },
					LeftHip = { rot = Vector3.new(7.3, 0, -2.4), pos = Vector3.new(0, 0.052, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(4.31, -3.94, 0.43),
						pos = Vector3.new(0, 0.108, 0.205),
					},
					Neck = { rot = Vector3.new(-6.816, 4.24, 0) },
					RightShoulder = { rot = Vector3.new(147.7, 0, -44.1) },
					LeftShoulder = { rot = Vector3.new(150.1, 0, 43.8) },
					RightHip = { rot = Vector3.new(-6.9, 0, 1.8) },
					LeftHip = { rot = Vector3.new(5.6, 0, -3.1) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(6.78, -0.72, 0.09),
						pos = Vector3.new(0, 0.122, 0.267),
					},
					Neck = { rot = Vector3.new(-12.144, 0.685, 0) },
					RightShoulder = { rot = Vector3.new(160.9, 0, -44.2) },
					LeftShoulder = { rot = Vector3.new(161.2, 0, 44) },
					RightHip = { rot = Vector3.new(-11.9, 0, 3.2) },
					LeftHip = { rot = Vector3.new(6.2, 0, -3.7) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, 0.1, 0.25) },
					Neck = { rot = Vector3.new(-12, 0, 0) },
					RightShoulder = { rot = Vector3.new(164.2, 0, -43.8) },
					LeftShoulder = { rot = Vector3.new(164.1, 0, 43.8) },
					RightHip = { rot = Vector3.new(-11.5, 0, 3.3) },
					LeftHip = { rot = Vector3.new(7.2, 0, -3.6) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(1.51, 0.8, -0.07),
						pos = Vector3.new(0, -0.011, 0.123),
					},
					Neck = { rot = Vector3.new(-7.44, -0.64, 0) },
					RightShoulder = { rot = Vector3.new(167.5, 0, -43.6) },
					LeftShoulder = { rot = Vector3.new(167.2, 0, 43.8) },
					RightHip = { rot = Vector3.new(-9.8, 0, 2.8), pos = Vector3.new(0, 0.074, 0) },
					LeftHip = { rot = Vector3.new(13.7, 0, -2.6), pos = Vector3.new(0, 0.104, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-10.06, 0.84, 0.02),
						pos = Vector3.new(0, -0.287, -0.212),
					},
					Neck = { rot = Vector3.new(6, -0.625, 0) },
					RightShoulder = { rot = Vector3.new(166.4, 0, -43.8) },
					LeftShoulder = { rot = Vector3.new(166.2, 0, 44.1) },
					RightHip = { rot = Vector3.new(-7.2, 0, 2.7), pos = Vector3.new(0, 0.313, 0) },
					LeftHip = { rot = Vector3.new(27.1, 0, -2.5), pos = Vector3.new(0, 0.453, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-23.03, 0.27, 0.04),
						pos = Vector3.new(0, -0.537, -0.521),
					},
					Neck = { rot = Vector3.new(18.72, -0.16, 0) },
					RightShoulder = { rot = Vector3.new(167.4, 0, -43) },
					LeftShoulder = { rot = Vector3.new(167.3, 0, 43.2) },
					RightHip = { rot = Vector3.new(-3.2, 0, 2.8), pos = Vector3.new(0, 0.363, 0) },
					LeftHip = { rot = Vector3.new(41.1, 0, -2.7), pos = Vector3.new(0, 0.567, 0) },
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
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-32.47, -0.02, 0),
						pos = Vector3.new(0, -0.611, -0.604),
					},
					Neck = { rot = Vector3.new(22.395, -0.062, 0) },
					RightShoulder = { rot = Vector3.new(174.3, 0, -43.5) },
					LeftShoulder = { rot = Vector3.new(174.3, 0, 43.5) },
					RightHip = { rot = Vector3.new(6.4, 0, 2.8), pos = Vector3.new(0, 0.321, 0) },
					LeftHip = { rot = Vector3.new(55.1, 0, -2.9), pos = Vector3.new(0, 0.381, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-36.06, 0.12, 0.03),
						pos = Vector3.new(0, -0.698, -0.624),
					},
					Neck = { rot = Vector3.new(25.595, -0.395, 0) },
					RightShoulder = { rot = Vector3.new(160.7, 0, -50.8) },
					LeftShoulder = { rot = Vector3.new(160.7, 0, 50.9) },
					RightHip = { rot = Vector3.new(9.2, 0, 2.8), pos = Vector3.new(0, 0.385, 0) },
					LeftHip = { rot = Vector3.new(57.3, 0, -2.8), pos = Vector3.new(0, 0.484, 0) },
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
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-35.45, -0.23, -0.06),
						pos = Vector3.new(0, -0.669, -0.57),
					},
					Neck = { rot = Vector3.new(25.161, 0.498, 0) },
					RightShoulder = { rot = Vector3.new(144.1, 0, -52.7) },
					LeftShoulder = { rot = Vector3.new(144.2, 0, 52.4) },
					RightHip = { rot = Vector3.new(9.8, 0, 2.9), pos = Vector3.new(0, 0.421, 0) },
					LeftHip = { rot = Vector3.new(56.9, 0, -3), pos = Vector3.new(0, 0.528, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-32.22, -1.61, -0.35),
						pos = Vector3.new(0, -0.535, -0.45),
					},
					Neck = { rot = Vector3.new(21.411, 2.498, 0) },
					RightShoulder = { rot = Vector3.new(128.5, 0, -49.3) },
					LeftShoulder = { rot = Vector3.new(129.4, 0, 47.5) },
					RightHip = { rot = Vector3.new(11.3, 0, 2.6), pos = Vector3.new(0, 0.47, 0) },
					LeftHip = { rot = Vector3.new(50.5, 0, -3.4), pos = Vector3.new(0, 0.64, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-27.19, -3.78, -0.64),
						pos = Vector3.new(0, -0.367, -0.306),
					},
					Neck = { rot = Vector3.new(16.605, 4.904, 0) },
					RightShoulder = { rot = Vector3.new(115.1, 0, -44.8) },
					LeftShoulder = { rot = Vector3.new(117, 0, 41.5) },
					RightHip = { rot = Vector3.new(14.1, 0, 1.7), pos = Vector3.new(0, 0.446, 0) },
					LeftHip = { rot = Vector3.new(41.7, 0, -3.7), pos = Vector3.new(0, 0.626, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-21.13, -6.42, -0.74),
						pos = Vector3.new(0, -0.199, -0.165),
					},
					Neck = { rot = Vector3.new(11.762, 7.257, 0) },
					RightShoulder = { rot = Vector3.new(108.8, 0, -41.2) },
					LeftShoulder = { rot = Vector3.new(111.6, 0, 37.7) },
					RightHip = { rot = Vector3.new(16.7, 0, 0.2), pos = Vector3.new(0, 0.319, 0) },
					LeftHip = { rot = Vector3.new(31.9, 0, -3.7), pos = Vector3.new(0, 0.489, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(-14.78, -9.15, -0.54),
						pos = Vector3.new(0, -0.066, -0.054),
					},
					Neck = { rot = Vector3.new(7.902, 9.101, 0) },
					RightShoulder = { rot = Vector3.new(108.8, 0, -38.4) },
					LeftShoulder = { rot = Vector3.new(112.4, 0, 36.8) },
					RightHip = { rot = Vector3.new(17, 0, -1.4), pos = Vector3.new(0, 0.128, 0) },
					LeftHip = { rot = Vector3.new(21.9, 0, -3.3), pos = Vector3.new(0, 0.276, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(-8.88, -11.63, -0.09),
						pos = Vector3.new(0, -0.001, -0.001),
					},
					Neck = { rot = Vector3.new(6.044, 9.98, 0) },
					RightShoulder = { rot = Vector3.new(110.9, 0, -36.6) },
					LeftShoulder = { rot = Vector3.new(114.9, 0, 37) },
					RightHip = { rot = Vector3.new(13, 0, -2) },
					LeftHip = { rot = Vector3.new(12.7, 0, -2.8), pos = Vector3.new(0, 0.055, 0) },
				},
			},
			{
				time = 0.85,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-2.12, -8.05, 0.41),
						pos = Vector3.new(0, 0.041, 0.073),
					},
					Neck = { rot = Vector3.new(1.608, 8.155, 0) },
					RightShoulder = { rot = Vector3.new(124.2, 0, -40.2) },
					LeftShoulder = { rot = Vector3.new(128.2, 0, 40.9) },
					RightHip = { rot = Vector3.new(2.9, 0, -0.3), pos = Vector3.new(0, 0.026, 0) },
					LeftHip = { rot = Vector3.new(7.4, 0, -2.4), pos = Vector3.new(0, 0.052, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(4.15, -3.97, 0.42),
						pos = Vector3.new(0, 0.108, 0.205),
					},
					Neck = { rot = Vector3.new(-6.816, 4.24, 0) },
					RightShoulder = { rot = Vector3.new(147.9, 0, -44.1) },
					LeftShoulder = { rot = Vector3.new(150.3, 0, 43.8) },
					RightHip = { rot = Vector3.new(-6.7, 0, 1.8) },
					LeftHip = { rot = Vector3.new(5.8, 0, -3.1) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(6.69, -0.73, 0.09),
						pos = Vector3.new(0, 0.122, 0.267),
					},
					Neck = { rot = Vector3.new(-12.144, 0.685, 0) },
					RightShoulder = { rot = Vector3.new(161, 0, -44.2) },
					LeftShoulder = { rot = Vector3.new(161.4, 0, 44) },
					RightHip = { rot = Vector3.new(-11.7, 0, 3.2) },
					LeftHip = { rot = Vector3.new(6.3, 0, -3.7) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, 0.1, 0.25) },
					Neck = { rot = Vector3.new(-12, 0, 0) },
					RightShoulder = { rot = Vector3.new(164.2, 0, -43.8) },
					LeftShoulder = { rot = Vector3.new(164.1, 0, 43.8) },
					RightHip = { rot = Vector3.new(-11.5, 0, 3.3) },
					LeftHip = { rot = Vector3.new(7.2, 0, -3.6) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(1.8, 0.84, -0.07),
						pos = Vector3.new(0, -0.011, 0.123),
					},
					Neck = { rot = Vector3.new(-7.44, -0.64, 0) },
					RightShoulder = { rot = Vector3.new(167.2, 0, -43.6) },
					LeftShoulder = { rot = Vector3.new(166.8, 0, 43.8) },
					RightHip = { rot = Vector3.new(-10.2, 0, 2.8), pos = Vector3.new(0, 0.073, 0) },
					LeftHip = { rot = Vector3.new(13.3, 0, -2.6), pos = Vector3.new(0, 0.105, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-9.37, 0.94, 0.01),
						pos = Vector3.new(0, -0.287, -0.212),
					},
					Neck = { rot = Vector3.new(6, -0.625, 0) },
					RightShoulder = { rot = Vector3.new(165.5, 0, -43.7) },
					LeftShoulder = { rot = Vector3.new(165.2, 0, 44.1) },
					RightHip = { rot = Vector3.new(-8.2, 0, 2.7), pos = Vector3.new(0, 0.312, 0) },
					LeftHip = { rot = Vector3.new(26.2, 0, -2.4), pos = Vector3.new(0, 0.456, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-22.42, 0.35, 0.04),
						pos = Vector3.new(0, -0.537, -0.521),
					},
					Neck = { rot = Vector3.new(18.72, -0.16, 0) },
					RightShoulder = { rot = Vector3.new(166.6, 0, -43) },
					LeftShoulder = { rot = Vector3.new(166.5, 0, 43.2) },
					RightHip = { rot = Vector3.new(-4, 0, 2.8), pos = Vector3.new(0, 0.362, 0) },
					LeftHip = { rot = Vector3.new(40.4, 0, -2.7), pos = Vector3.new(0, 0.57, 0) },
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
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-32.96, -0.08, -0.02),
						pos = Vector3.new(0, -0.617, -0.608),
					},
					Neck = { rot = Vector3.new(22.718, 0, 0) },
					RightShoulder = { rot = Vector3.new(174.5, 0, -43.8) },
					LeftShoulder = { rot = Vector3.new(174.5, 0, 43.8) },
					RightHip = { rot = Vector3.new(6.9, 0, 2.9), pos = Vector3.new(0, 0.324, 0) },
					LeftHip = { rot = Vector3.new(55.5, 0, -2.9), pos = Vector3.new(0, 0.387, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-36.84, -0.05, -0.01),
						pos = Vector3.new(0, -0.714, -0.63),
					},
					Neck = { rot = Vector3.new(26.793, 0, 0) },
					RightShoulder = { rot = Vector3.new(155.4, 0, -52.7) },
					LeftShoulder = { rot = Vector3.new(155.4, 0, 52.7) },
					RightHip = { rot = Vector3.new(9.9, 0, 2.9), pos = Vector3.new(0, 0.396, 0) },
					LeftHip = { rot = Vector3.new(57.5, 0, -2.9), pos = Vector3.new(0, 0.508, 0) },
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
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-30.8, 0.08, 0.02),
						pos = Vector3.new(0, -0.594, -0.478),
					},
					Neck = { rot = Vector3.new(20.92, 0, 0) },
					RightShoulder = { rot = Vector3.new(141.3, 0, -52.3) },
					LeftShoulder = { rot = Vector3.new(141.3, 0, 52.4) },
					RightHip = { rot = Vector3.new(7.2, 0, 2.8), pos = Vector3.new(0, 0.414, 0) },
					LeftHip = { rot = Vector3.new(53.6, 0, -2.8), pos = Vector3.new(0, 0.501, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-17.24, 0.16, 0.01),
						pos = Vector3.new(0, -0.368, -0.23),
					},
					Neck = { rot = Vector3.new(10.094, 0, 0) },
					RightShoulder = { rot = Vector3.new(143.1, 0, -52.5) },
					LeftShoulder = { rot = Vector3.new(143, 0, 52.6) },
					RightHip = { rot = Vector3.new(0.1, 0, 2.8), pos = Vector3.new(0, 0.371, 0) },
					LeftHip = { rot = Vector3.new(39.1, 0, -2.8), pos = Vector3.new(0, 0.448, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-2.14, 0.15, -0.01),
						pos = Vector3.new(0, -0.126, 0.025),
					},
					Neck = { rot = Vector3.new(-1.359, 0, 0) },
					RightShoulder = { rot = Vector3.new(152, 0, -49.4) },
					LeftShoulder = { rot = Vector3.new(152, 0, 49.4) },
					RightHip = { rot = Vector3.new(-9.2, 0, 2.8), pos = Vector3.new(0, 0.207, 0) },
					LeftHip = { rot = Vector3.new(20.4, 0, -2.8), pos = Vector3.new(0, 0.274, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(8.44, 0.08, -0.01),
						pos = Vector3.new(0, 0.053, 0.208),
					},
					Neck = { rot = Vector3.new(-9.816, 0, 0) },
					RightShoulder = { rot = Vector3.new(157.1, 0, -44.7) },
					LeftShoulder = { rot = Vector3.new(157.1, 0, 44.7) },
					RightHip = { rot = Vector3.new(-17.2, 0, 2.9) },
					LeftHip = { rot = Vector3.new(4.7, 0, 0) },
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
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(8.54, -0.05, 0.01),
						pos = Vector3.new(0, 0.082, 0.224),
					},
					Neck = { rot = Vector3.new(-11.091, 0, 0) },
					RightShoulder = { rot = Vector3.new(159.4, 0, -43.8) },
					LeftShoulder = { rot = Vector3.new(159.4, 0, 43.8) },
					RightHip = { rot = Vector3.new(-16.4, 0, 3.1) },
					LeftHip = { rot = Vector3.new(4, 0, -3.1) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(-2.78, -0.2, 0.01),
						pos = Vector3.new(0, -0.162, -0.075),
					},
					Neck = { rot = Vector3.new(0.769, 0, 0) },
					RightShoulder = { rot = Vector3.new(159.5, 0, -44.3) },
					LeftShoulder = { rot = Vector3.new(159.5, 0, 44.2) },
					RightHip = { rot = Vector3.new(-11.5, 0, 2.9), pos = Vector3.new(0, 0.222, 0) },
					LeftHip = { rot = Vector3.new(19.2, 0, -2.9), pos = Vector3.new(0, 0.339, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(-18.68, -0.21, -0.02),
						pos = Vector3.new(0, -0.478, -0.454),
					},
					Neck = { rot = Vector3.new(16.089, 0, 0) },
					RightShoulder = { rot = Vector3.new(163.5, 0, -43.4) },
					LeftShoulder = { rot = Vector3.new(163.5, 0, 43.3) },
					RightHip = { rot = Vector3.new(-6, 0, 2.9), pos = Vector3.new(0, 0.359, 0) },
					LeftHip = { rot = Vector3.new(36.3, 0, -3), pos = Vector3.new(0, 0.564, 0) },
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
				time = 0.96,
				pose = {
					Root = {
						rot = Vector3.new(-31.64, 0.07, 0.01),
						pos = Vector3.new(0, -0.603, -0.601),
					},
					Neck = { rot = Vector3.new(22.114, -0.022, 0) },
					RightShoulder = { rot = Vector3.new(174.3, 0, -43) },
					LeftShoulder = { rot = Vector3.new(174.2, 0, 43) },
					RightHip = { rot = Vector3.new(5.4, 0, 2.8), pos = Vector3.new(0, 0.316, 0) },
					LeftHip = { rot = Vector3.new(54.2, 0, -2.8), pos = Vector3.new(0, 0.377, 0) },
				},
			},
			{
				time = 1.02,
				pose = {
					Root = {
						rot = Vector3.new(-36.75, 0.41, 0.11),
						pos = Vector3.new(0, -0.692, -0.629),
					},
					Neck = { rot = Vector3.new(25.273, -0.486, 0) },
					RightShoulder = { rot = Vector3.new(166.5, 0, -49.4) },
					LeftShoulder = { rot = Vector3.new(166.3, 0, 49.7) },
					RightHip = { rot = Vector3.new(10, 0, 2.8), pos = Vector3.new(0, 0.375, 0) },
					LeftHip = { rot = Vector3.new(58.5, 0, -2.6), pos = Vector3.new(0, 0.46, 0) },
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
				time = 1.08,
				pose = {
					Root = {
						rot = Vector3.new(-35.44, -0.22, -0.05),
						pos = Vector3.new(0, -0.68, -0.581),
					},
					Neck = { rot = Vector3.new(25.472, 0.316, 0) },
					RightShoulder = { rot = Vector3.new(145.1, 0, -52.9) },
					LeftShoulder = { rot = Vector3.new(145.1, 0, 52.7) },
					RightHip = { rot = Vector3.new(9.4, 0, 2.9), pos = Vector3.new(0, 0.415, 0) },
					LeftHip = { rot = Vector3.new(56.9, 0, -3), pos = Vector3.new(0, 0.521, 0) },
				},
			},
			{
				time = 1.14,
				pose = {
					Root = {
						rot = Vector3.new(-29.92, -2.54, -0.49),
						pos = Vector3.new(0, -0.487, -0.409),
					},
					Neck = { rot = Vector3.new(20.021, 3.183, 0) },
					RightShoulder = { rot = Vector3.new(122.8, 0, -47.8) },
					LeftShoulder = { rot = Vector3.new(124.1, 0, 45.2) },
					RightHip = { rot = Vector3.new(11, 0, 2.4), pos = Vector3.new(0, 0.479, 0) },
					LeftHip = { rot = Vector3.new(46.2, 0, -3.7), pos = Vector3.new(0, 0.672, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-22, -5.99, -0.74),
						pos = Vector3.new(0, -0.24, -0.2),
					},
					Neck = { rot = Vector3.new(12.931, 6.675, 0) },
					RightShoulder = { rot = Vector3.new(109.4, 0, -42) },
					LeftShoulder = { rot = Vector3.new(112, 0, 38.3) },
					RightHip = { rot = Vector3.new(15.4, 0, 0.6), pos = Vector3.new(0, 0.363, 0) },
					LeftHip = { rot = Vector3.new(33.2, 0, -3.8), pos = Vector3.new(0, 0.539, 0) },
				},
			},
			{
				time = 1.26,
				pose = {
					Root = {
						rot = Vector3.new(-13.35, -9.75, -0.46),
						pos = Vector3.new(0, -0.046, -0.038),
					},
					Neck = { rot = Vector3.new(7.342, 9.362, 0) },
					RightShoulder = { rot = Vector3.new(109.3, 0, -37.9) },
					LeftShoulder = { rot = Vector3.new(113, 0, 36.8) },
					RightHip = { rot = Vector3.new(16.4, 0, -1.7), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(19.6, 0, -3.2), pos = Vector3.new(0, 0.229, 0) },
				},
			},
			{
				time = 1.3,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-5.85, -6.94, -2.92),
						pos = Vector3.new(0, -0.014, 0),
					},
					Neck = { rot = Vector3.new(4.35, 7.25, 10.733) },
					RightShoulder = { rot = Vector3.new(83.22, 0, -21.51) },
					LeftShoulder = { rot = Vector3.new(86.12, 0, 21.872) },
					RightHip = { rot = Vector3.new(7.1, 0, 4.4), pos = Vector3.new(0, 0.064, 0) },
					LeftHip = { rot = Vector3.new(10.1, 0, 1.8) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-3.49, -2.19, -5.69),
						pos = Vector3.new(0, -0.039, 0),
					},
					Neck = { rot = Vector3.new(1.335, 2.224, 27.298) },
					RightShoulder = { rot = Vector3.new(32.465, 0, 5.878) },
					LeftShoulder = { rot = Vector3.new(33.355, 0, -5.767) },
					RightHip = { rot = Vector3.new(1.7, 0, 10.5), pos = Vector3.new(0, 0.165, 0) },
					LeftHip = { rot = Vector3.new(8.6, 0, 5.1) },
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
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(-1.35, 0.66, -5.4), pos = Vector3.new(0, -0.052, 0) },
					Neck = { rot = Vector3.new(-0.279, -0.465, 26.548) },
					RightShoulder = { rot = Vector3.new(5.306, 0, 20.533) },
					LeftShoulder = { rot = Vector3.new(5.12, 0, -20.556) },
					RightHip = { rot = Vector3.new(-2.4, 0, 10.5), pos = Vector3.new(0, 0.175, 0) },
					LeftHip = { rot = Vector3.new(6.5, 0, 4.8) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-0.14, 1.24, -1.31),
						pos = Vector3.new(0, -0.054, 0),
					},
					Neck = { rot = Vector3.new(-0.436, -0.726, 2.801) },
					RightShoulder = { rot = Vector3.new(2.665, 0, 21.958) },
					LeftShoulder = { rot = Vector3.new(2.375, 0, -21.994) },
					RightHip = { rot = Vector3.new(-4.6, 0, 4.2) },
					LeftHip = { rot = Vector3.new(4.9, 0, -0.8), pos = Vector3.new(0, 0.041, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(-0.52, 0.61, 3.73), pos = Vector3.new(0, -0.051, 0) },
					Neck = { rot = Vector3.new(-0.122, -0.203, -23.038) },
					RightShoulder = { rot = Vector3.new(7.946, 0, 19.108) },
					LeftShoulder = { rot = Vector3.new(7.865, 0, -19.118) },
					RightHip = { rot = Vector3.new(-3.7, 0, -2.6) },
					LeftHip = { rot = Vector3.new(5.1, 0, -8.1), pos = Vector3.new(0, 0.14, 0) },
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
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-3.19, -0.25, 6.48),
						pos = Vector3.new(0, -0.054, 0.001),
					},
					Neck = { rot = Vector3.new(0.414, 0, -29.379) },
					RightShoulder = { rot = Vector3.new(10.159, 0, 18.108) },
					LeftShoulder = { rot = Vector3.new(10.159, 0, -18.108) },
					RightHip = { rot = Vector3.new(0.5, 0, -6.1) },
					LeftHip = { rot = Vector3.new(8.7, 0, -12.2), pos = Vector3.new(0, 0.191, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-7.65, -0.61, 5.64),
						pos = Vector3.new(0, -0.101, 0.011),
					},
					Neck = { rot = Vector3.new(5.176, 0, -21.828) },
					RightShoulder = { rot = Vector3.new(12.2, 0, 19.55) },
					LeftShoulder = { rot = Vector3.new(12.2, 0, -19.55) },
					RightHip = { rot = Vector3.new(7.5, 0, -4.1), pos = Vector3.new(0, 0.001, 0) },
					LeftHip = { rot = Vector3.new(14.7, 0, -12.1), pos = Vector3.new(0, 0.217, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-11.14, -0.38, 2.94),
						pos = Vector3.new(0, -0.165, 0.028),
					},
					Neck = { rot = Vector3.new(11.407, 0, -10.37) },
					RightShoulder = { rot = Vector3.new(15.679, 0, 22.198) },
					LeftShoulder = { rot = Vector3.new(15.679, 0, -22.198) },
					RightHip = { rot = Vector3.new(12.4, 0, 1.8), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(19.3, 0, -10), pos = Vector3.new(0, 0.226, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-10.67, -0.02, 0.3),
						pos = Vector3.new(0, -0.2, 0.047),
					},
					Neck = { rot = Vector3.new(14.21, 0, -0.953) },
					RightShoulder = { rot = Vector3.new(19.43, 0, 25.443) },
					LeftShoulder = { rot = Vector3.new(19.43, 0, -25.443) },
					RightHip = { rot = Vector3.new(11.8, 0, 6.6), pos = Vector3.new(0, 0.227, 0) },
					LeftHip = { rot = Vector3.new(18.9, 0, -7.4), pos = Vector3.new(0, 0.217, 0) },
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
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-4.13, -0.13, -0.68),
						pos = Vector3.new(0, -0.145, 0.069),
					},
					Neck = { rot = Vector3.new(6.519, 0, 1.852) },
					RightShoulder = { rot = Vector3.new(23.827, 0, 30.346) },
					LeftShoulder = { rot = Vector3.new(23.827, 0, -30.346) },
					RightHip = { rot = Vector3.new(3.5, 0, 8), pos = Vector3.new(0, 0.202, 0) },
					LeftHip = { rot = Vector3.new(10.5, 0, -6.2), pos = Vector3.new(0, 0.164, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(5.11, -0.26, -0.34),
						pos = Vector3.new(0, -0.034, 0.093),
					},
					Neck = { rot = Vector3.new(-7.7, 0, 0.652) },
					RightShoulder = { rot = Vector3.new(28.68, 0, 36.33) },
					LeftShoulder = { rot = Vector3.new(28.68, 0, -36.33) },
					RightHip = { rot = Vector3.new(-9.3, 0, 7.3) },
					LeftHip = { rot = Vector3.new(-2.1, 0, -6.6), pos = Vector3.new(0, 0.067, 0) },
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
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(11.49, 0.27, 0.07),
						pos = Vector3.new(0, -0.001, 0.101),
					},
					Neck = { rot = Vector3.new(-12.041, -0.077, 0) },
					RightShoulder = { rot = Vector3.new(29.279, 0, 38.477) },
					LeftShoulder = { rot = Vector3.new(29.248, 0, -38.481) },
					RightHip = { rot = Vector3.new(-18.6, 0, 6.9) },
					LeftHip = { rot = Vector3.new(-11.3, 0, -7.1) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(12.23, 1.05, -0.02),
						pos = Vector3.new(0, -0.011, 0.107),
					},
					Neck = { rot = Vector3.new(-12.095, -0.664, 0) },
					RightShoulder = { rot = Vector3.new(23.524, 0, 41.845) },
					LeftShoulder = { rot = Vector3.new(23.259, 0, -41.878) },
					RightHip = { rot = Vector3.new(-19.8, 0, 6.7) },
					LeftHip = { rot = Vector3.new(-12, 0, -7.1) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(8.83, 0.38, -0.04),
						pos = Vector3.new(0, -0.02, 0.103),
					},
					Neck = { rot = Vector3.new(-10.548, -0.29, 0) },
					RightShoulder = { rot = Vector3.new(25.673, 0, 38.189) },
					LeftShoulder = { rot = Vector3.new(25.557, 0, -38.203) },
					RightHip = { rot = Vector3.new(-14.7, 0, 6.9) },
					LeftHip = { rot = Vector3.new(-7.3, 0, -6.9) },
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
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(3.14, -3.17, 0.27),
						pos = Vector3.new(0, -0.015, 0.067),
					},
					Neck = { rot = Vector3.new(-4.519, 3.333, 0) },
					RightShoulder = { rot = Vector3.new(55.519, 0, 11.685) },
					LeftShoulder = { rot = Vector3.new(56.852, 0, -11.519) },
					RightHip = { rot = Vector3.new(-5.4, 0, 5.2), pos = Vector3.new(0, 0.125, 0) },
					LeftHip = { rot = Vector3.new(-1, 0, -5.6), pos = Vector3.new(0, 0.053, 0) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = {
						rot = Vector3.new(-3.53, -8.52, 0.32),
						pos = Vector3.new(0, -0.004, 0.015),
					},
					Neck = { rot = Vector3.new(3.663, 8.507, 0) },
					RightShoulder = { rot = Vector3.new(98.553, 0, -25.725) },
					LeftShoulder = { rot = Vector3.new(101.956, 0, 26.151) },
					RightHip = { rot = Vector3.new(4.8, 0, 0.2), pos = Vector3.new(0, 0.062, 0) },
					LeftHip = { rot = Vector3.new(6.2, 0, -2.6) },
				},
			},
			{
				time = 1,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
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
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-25.95, 25.63, 12.1),
						pos = Vector3.new(-0.35, -0.334, -0.158),
					},
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(51.4, 0, -33.2) },
					LeftShoulder = { rot = Vector3.new(164.3, 0, 69.8) },
					RightHip = { rot = Vector3.new(9.7, 0, 3.9), pos = Vector3.new(0, 0.335, 0) },
					LeftHip = { rot = Vector3.new(40.1, 0, 10.8), pos = Vector3.new(0, 0.286, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-32.02, 27.03, 15.99),
						pos = Vector3.new(-0.431, -0.571, -0.263),
					},
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(53.4, 0, -37.7) },
					LeftShoulder = { rot = Vector3.new(186.4, 0, 68.8) },
					RightHip = { rot = Vector3.new(6.1, 0, 2), pos = Vector3.new(0, 0.422, 0) },
					LeftHip = { rot = Vector3.new(56.9, 0, 16.1), pos = Vector3.new(0, 0.172, 0) },
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
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-35.57, 27.29, 18.03),
						pos = Vector3.new(-0.448, -0.694, -0.323),
					},
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(61, 0, -50.7) },
					LeftShoulder = { rot = Vector3.new(196.6, 0, 64.2) },
					RightHip = { rot = Vector3.new(6.4, 0, 0.9), pos = Vector3.new(0, 0.438, 0) },
					LeftHip = { rot = Vector3.new(64.4, 0, 17), pos = Vector3.new(0, 0.032, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-35.27, 26.44, 17.27),
						pos = Vector3.new(-0.413, -0.735, -0.352),
					},
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(20, 0, -8.5) },
					LeftShoulder = { rot = Vector3.new(203.5, 0, 78.3) },
					RightHip = { rot = Vector3.new(5.9, 0, 0.3), pos = Vector3.new(0, 0.472, 0) },
					LeftHip = { rot = Vector3.new(66, 0, 16.5) },
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
					RightShoulder = { rot = Vector3.new(75.5, 0, -33.3) },
					LeftShoulder = { rot = Vector3.new(197.5, 0, 56.1) },
					RightHip = { rot = Vector3.new(4, 0, 0.3), pos = Vector3.new(0, 0.467, 0) },
					LeftHip = { rot = Vector3.new(55.3, 0, 12.6), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-23.52, 21.15, 9.1),
						pos = Vector3.new(-0.254, -0.549, -0.309),
					},
					Neck = { rot = Vector3.new(14.288, 0, 0) },
					RightShoulder = { rot = Vector3.new(31.4, 0, -6.6) },
					LeftShoulder = { rot = Vector3.new(189.4, 0, 63.6) },
					RightHip = { rot = Vector3.new(1.2, 0, 0.6), pos = Vector3.new(0, 0.379, 0) },
					LeftHip = { rot = Vector3.new(48.9, 0, 8.8), pos = Vector3.new(0, 0.183, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-14.64, 16.45, 4.32),
						pos = Vector3.new(-0.143, -0.338, -0.24),
					},
					Neck = { rot = Vector3.new(14.384, 0, 0) },
					RightShoulder = { rot = Vector3.new(55.7, 0, 30.5) },
					LeftShoulder = { rot = Vector3.new(171.3, 0, 34.9) },
					RightHip = { rot = Vector3.new(-3.2, 0, 1), pos = Vector3.new(0, 0.232, 0) },
					LeftHip = { rot = Vector3.new(40.3, 0, 4.6), pos = Vector3.new(0, 0.062, 0) },
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
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-6.23, 11.09, 1.17),
						pos = Vector3.new(-0.067, -0.171, -0.148),
					},
					Neck = { rot = Vector3.new(12.992, 0, 0) },
					RightShoulder = { rot = Vector3.new(107.2, 0, 17.3) },
					LeftShoulder = { rot = Vector3.new(159.6, 0, 23.3) },
					RightHip = { rot = Vector3.new(-8.9, 0, 1.7), pos = Vector3.new(0, 0.111, 0) },
					LeftHip = { rot = Vector3.new(29.9, 0, 1.2) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(1.2, 6.05, -0.14),
						pos = Vector3.new(-0.018, -0.02, -0.019),
					},
					Neck = { rot = Vector3.new(9.824, 0, 0) },
					RightShoulder = { rot = Vector3.new(115.1, 0, -11.2) },
					LeftShoulder = { rot = Vector3.new(153.3, 0, 49.3) },
					RightHip = { rot = Vector3.new(-14.1, 0, 2.3) },
					LeftHip = { rot = Vector3.new(20.1, 0, -2.1) },
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
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(13.53, -0.69, 0.08),
						pos = Vector3.new(0, 0.076, 0.081),
					},
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(92.9, 0, -25.5) },
					LeftShoulder = { rot = Vector3.new(140, 0, 29.2) },
					RightHip = { rot = Vector3.new(-26.8, 0, 3.7) },
					LeftHip = { rot = Vector3.new(2.1, 0, -5.1) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(13.6, -1.9, 0.37),
						pos = Vector3.new(0, 0.084, 0.104),
					},
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(94.2, 0, -25) },
					LeftShoulder = { rot = Vector3.new(139.2, 0, 28.8) },
					RightHip = { rot = Vector3.new(-25.9, 0, 3.9) },
					LeftHip = { rot = Vector3.new(2.2, 0, -5.6) },
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
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(3.46, -1.71, 0.22),
						pos = Vector3.new(0, -0.026, 0.011),
					},
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(120, 0, -22.3) },
					LeftShoulder = { rot = Vector3.new(144.3, 0, 30.1) },
					RightHip = { rot = Vector3.new(-14.4, 0, 2.9) },
					LeftHip = { rot = Vector3.new(15.6, 0, -5.3) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(-14.45, -0.63, -0.01),
						pos = Vector3.new(0, -0.268, -0.213),
					},
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(117.8, 0, -20.4) },
					LeftShoulder = { rot = Vector3.new(127.9, 0, 16.7) },
					RightHip = { rot = Vector3.new(4.1, 0, 2.8), pos = Vector3.new(0, 0.231, 0) },
					LeftHip = { rot = Vector3.new(36, 0, -4.6), pos = Vector3.new(0, 0.134, 0) },
				},
			},
			{
				time = 0.88,
				pose = {
					Root = { rot = Vector3.new(-26, 0, 0), pos = Vector3.new(0, -0.45, -0.35) },
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(114.3, 0, -15.4) },
					LeftShoulder = { rot = Vector3.new(117.2, 0, 18.4) },
					RightHip = { rot = Vector3.new(14, 0, 2.8), pos = Vector3.new(0, 0.364, 0) },
					LeftHip = { rot = Vector3.new(46.7, 0, -4.3), pos = Vector3.new(0, 0.278, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(-30.63, 0.16, 0.03),
						pos = Vector3.new(0, -0.556, -0.406),
					},
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(96.9, 0, -13) },
					LeftShoulder = { rot = Vector3.new(109.8, 0, 19.6) },
					RightHip = { rot = Vector3.new(17.1, 0, 2.9), pos = Vector3.new(0, 0.445, 0) },
					LeftHip = { rot = Vector3.new(49.4, 0, -4.2), pos = Vector3.new(0, 0.393, 0) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = {
						rot = Vector3.new(-39.56, 0.15, 0.04),
						pos = Vector3.new(0, -0.934, -0.559),
					},
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(79.8, 0, -10.6) },
					LeftShoulder = { rot = Vector3.new(91.5, 0, 25) },
					RightHip = { rot = Vector3.new(17.7, 0, 2.9), pos = Vector3.new(0, 0.755, 0) },
					LeftHip = { rot = Vector3.new(46.1, 0, -4.2), pos = Vector3.new(0, 0.936, 0) },
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
				time = 1.02,
				pose = {
					Root = {
						rot = Vector3.new(-42.35, -0.05, -0.01),
						pos = Vector3.new(0, -1.056, -0.6),
					},
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightHip = { rot = Vector3.new(17.5, 0, 2.8), pos = Vector3.new(0, 0.852, 0) },
					LeftHip = { rot = Vector3.new(44.7, 0, -4.2), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 1.08,
				pose = {
					Root = {
						rot = Vector3.new(-40.78, -0.08, -0.02),
						pos = Vector3.new(0, -1.107, -0.59),
					},
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightHip = { rot = Vector3.new(15.1, 0, 2.8), pos = Vector3.new(0, 0.906, 0) },
					LeftHip = { rot = Vector3.new(43.5, 0, -4), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 1.14,
				pose = {
					Root = {
						rot = Vector3.new(-36.77, -0.01, 0),
						pos = Vector3.new(0, -1.112, -0.558),
					},
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightHip = { rot = Vector3.new(11.5, 0, 2.8), pos = Vector3.new(0, 0.926, 0) },
					LeftHip = { rot = Vector3.new(40.6, 0, -4), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 1.15,
				pose = {
					Root = { rot = Vector3.new(-36, 0, 0), pos = Vector3.new(0, -1.1, -0.55) },
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightHip = { rot = Vector3.new(11.1, 0, 2.8), pos = Vector3.new(0, 0.919, 0) },
					LeftHip = { rot = Vector3.new(40.1, 0, -4), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-32.09, 0.03, 0.01),
						pos = Vector3.new(0, -0.984, -0.491),
					},
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightHip = { rot = Vector3.new(10.2, 0, 2.8), pos = Vector3.new(0, 0.835, 0) },
					LeftHip = { rot = Vector3.new(39.4, 0, -4.3), pos = Vector3.new(0, 0.999, 0) },
				},
			},
			{
				time = 1.26,
				pose = {
					Root = {
						rot = Vector3.new(-27.3, 0.04, 0),
						pos = Vector3.new(0, -0.781, -0.397),
					},
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightHip = { rot = Vector3.new(10.1, 0, 2.9), pos = Vector3.new(0, 0.677, 0) },
					LeftHip = { rot = Vector3.new(41, 0, -4.2), pos = Vector3.new(0, 0.724, 0) },
				},
			},
			{
				time = 1.32,
				pose = {
					Root = {
						rot = Vector3.new(-22.45, 0.02, 0),
						pos = Vector3.new(0, -0.581, -0.307),
					},
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(89.5, 0, -35.4) },
					LeftShoulder = { rot = Vector3.new(95.1, 0, 36.1) },
					RightHip = { rot = Vector3.new(9, 0, 2.9), pos = Vector3.new(0, 0.511, 0) },
					LeftHip = { rot = Vector3.new(41, 0, -4.2), pos = Vector3.new(0, 0.466, 0) },
				},
			},
			{
				time = 1.38,
				pose = {
					Root = { rot = Vector3.new(-17.6, 0, 0), pos = Vector3.new(0, -0.46, -0.254) },
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(80.2, 0, -33.4) },
					LeftShoulder = { rot = Vector3.new(84.9, 0, 34) },
					RightHip = { rot = Vector3.new(5.5, 0, 2.8), pos = Vector3.new(0, 0.409, 0) },
					LeftHip = { rot = Vector3.new(37.6, 0, -4.3), pos = Vector3.new(0, 0.338, 0) },
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
			{
				time = 1.44,
				pose = {
					Root = { rot = Vector3.new(-16, 0, 0), pos = Vector3.new(0, -0.45, -0.25) },
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(78.3, 0, -33.2) },
					LeftShoulder = { rot = Vector3.new(83, 0, 33.7) },
					RightHip = { rot = Vector3.new(3.6, 0, 2.8), pos = Vector3.new(0, 0.402, 0) },
					LeftHip = { rot = Vector3.new(35.6, 0, -4.3), pos = Vector3.new(0, 0.338, 0) },
				},
			},
			{
				time = 1.5,
				pose = {
					Root = { rot = Vector3.new(-16, 0, 0), pos = Vector3.new(0, -0.45, -0.25) },
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(78.3, 0, -33.2) },
					LeftShoulder = { rot = Vector3.new(83, 0, 33.7) },
					RightHip = { rot = Vector3.new(3.6, 0, 2.8), pos = Vector3.new(0, 0.402, 0) },
					LeftHip = { rot = Vector3.new(35.6, 0, -4.3), pos = Vector3.new(0, 0.338, 0) },
				},
			},
			{
				time = 1.56,
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
					RightShoulder = { rot = Vector3.new(108.9, 0, -20.9) },
					LeftShoulder = { rot = Vector3.new(115.5, 0, 45) },
					RightHip = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, 0.045, 0) },
					LeftHip = { rot = Vector3.new(6, 0, 0), pos = Vector3.new(0, 0.045, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-8.92, -0.3, 0.83),
						pos = Vector3.new(-0.005, -0.075, 0.062),
					},
					Neck = { rot = Vector3.new(-11.632, -0.576, 0) },
					RightShoulder = { rot = Vector3.new(109, 0, -20.3) },
					LeftShoulder = { rot = Vector3.new(117.4, 0, 53.3) },
					RightHip = { rot = Vector3.new(10.7, 0, -1.1), pos = Vector3.new(0, 0.045, 0) },
					LeftHip = { rot = Vector3.new(10.4, 0, -1.1), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-11.49, -0.43, 1.09),
						pos = Vector3.new(-0.006, -0.104, 0.066),
					},
					Neck = { rot = Vector3.new(-14.736, -0.768, 0) },
					RightShoulder = { rot = Vector3.new(57, 0, -10.3) },
					LeftShoulder = { rot = Vector3.new(77.1, 0, 48) },
					RightHip = { rot = Vector3.new(14.5, 0, -1.5), pos = Vector3.new(0, 0.059, 0) },
					LeftHip = { rot = Vector3.new(14.1, 0, -1.5), pos = Vector3.new(0, 0.107, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(-12, 0, 0), pos = Vector3.new(0, -0.1, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(65.9, 0, 9.3) },
					LeftShoulder = { rot = Vector3.new(73, 0, 49.5) },
					RightHip = { rot = Vector3.new(14.6, 0, 0), pos = Vector3.new(0, 0.078, 0) },
					LeftHip = { rot = Vector3.new(14.6, 0, 0), pos = Vector3.new(0, 0.078, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-11.68, 0.93, -2.38),
						pos = Vector3.new(0.014, -0.083, 0.017),
					},
					Neck = { rot = Vector3.new(-16.928, 1.728, 0) },
					RightShoulder = { rot = Vector3.new(51.8, 0, -8.4) },
					LeftShoulder = { rot = Vector3.new(68.6, 0, 50.1) },
					RightHip = { rot = Vector3.new(12.9, 0, 3.2), pos = Vector3.new(0, 0.113, 0) },
					LeftHip = { rot = Vector3.new(13.8, 0, 3.4) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-8.39, 3.9, -11.08),
						pos = Vector3.new(0.055, -0.024, -0.084),
					},
					Neck = { rot = Vector3.new(-18.496, 7.056, 0) },
					RightShoulder = { rot = Vector3.new(54.4, 0, 7) },
					LeftShoulder = { rot = Vector3.new(57.9, 0, 49.9) },
					RightHip = { rot = Vector3.new(9.848, 0, 12.537) },
					LeftHip = { rot = Vector3.new(18.12, 0, -10.041) },
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
					RightShoulder = { rot = Vector3.new(36.4, 0, -0.6) },
					LeftShoulder = { rot = Vector3.new(38.3, 0, 38.6) },
					RightHip = { rot = Vector3.new(28.191, 0, 12.119) },
					LeftHip = { rot = Vector3.new(9.809, 0, -8.119) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(8.16, 8.09, -42.8),
						pos = Vector3.new(0.147, 0.33, -0.324),
					},
					Neck = { rot = Vector3.new(-22.368, 15.504, 0) },
					RightShoulder = { rot = Vector3.new(64.4, 0, -31.5) },
					LeftShoulder = { rot = Vector3.new(37, 0, 20.2) },
					RightHip = { rot = Vector3.new(47.547, 0, 9.375) },
					LeftHip = { rot = Vector3.new(-12.475, 0, -5.087) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(17.69, 6.53, -60.59),
						pos = Vector3.new(0.19, 0.616, -0.449),
					},
					Neck = { rot = Vector3.new(-24.224, 17.792, 0) },
					RightShoulder = { rot = Vector3.new(44.1, 0, 44.4) },
					LeftShoulder = { rot = Vector3.new(68.6, 0, -16.2) },
					RightHip = { rot = Vector3.new(45.417, 0, 9.018) },
					LeftHip = { rot = Vector3.new(-17.881, 0, -4.954) },
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
					RightShoulder = { rot = Vector3.new(57.772, 0, 53.083) },
					LeftShoulder = { rot = Vector3.new(83.199, 0, -24.41) },
					RightHip = { rot = Vector3.new(37.369, 0, 10.011) },
					LeftHip = { rot = Vector3.new(-11.369, 0, -6.011) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(24.33, 4.45, -73.88),
						pos = Vector3.new(0.198, 0.892, -0.544),
					},
					Neck = { rot = Vector3.new(-22.24, 17.04, 0) },
					RightShoulder = { rot = Vector3.new(62.588, 0, 59.134) },
					LeftShoulder = { rot = Vector3.new(89.953, 0, -32.142) },
					RightHip = { rot = Vector3.new(26.295, 0, 11.756) },
					LeftHip = { rot = Vector3.new(0.953, 0, -7.756) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(27.35, 3.46, -81.54),
						pos = Vector3.new(0.17, 1.199, -0.619),
					},
					Neck = { rot = Vector3.new(-15.84, 12.72, 0) },
					RightShoulder = { rot = Vector3.new(70.072, 0, 67.211) },
					LeftShoulder = { rot = Vector3.new(94.084, 0, -50.477) },
					RightHip = { rot = Vector3.new(1.929, 0, 16.776) },
					LeftHip = { rot = Vector3.new(31.847, 0, -12.776) },
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
					RightShoulder = { rot = Vector3.new(73.948, 0, 64.306) },
					LeftShoulder = { rot = Vector3.new(84.031, 0, -59.804) },
					RightHip = { rot = Vector3.new(-7.876, 0, 21.606) },
					LeftHip = { rot = Vector3.new(45.876, 0, -17.606) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(22.94, 0.55, -85.4),
						pos = Vector3.new(0.14, 1.427, -0.679),
					},
					Neck = { rot = Vector3.new(-11.778, 9.106, 0) },
					RightShoulder = { rot = Vector3.new(82.089, 0, 51.539) },
					LeftShoulder = { rot = Vector3.new(60.098, 0, -61.748) },
					RightHip = { rot = Vector3.new(7.48, 0, 23.897) },
					LeftHip = { rot = Vector3.new(29.025, 0, -21.099) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(23.01, -1.26, -84.96),
						pos = Vector3.new(0.115, 1.474, -0.667),
					},
					Neck = { rot = Vector3.new(-12.558, 7.102, 0) },
					RightShoulder = { rot = Vector3.new(83.493, 0, 41.196) },
					LeftShoulder = { rot = Vector3.new(36.461, 0, -61.161) },
					RightHip = { rot = Vector3.new(33.7, 0, 22.75) },
					LeftHip = { rot = Vector3.new(-0.253, 0, -22.06) },
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
					RightShoulder = { rot = Vector3.new(76.779, 0, 40.038) },
					LeftShoulder = { rot = Vector3.new(30.042, 0, -59.131) },
					RightHip = { rot = Vector3.new(42.342, 0, 20.951) },
					LeftHip = { rot = Vector3.new(-10.342, 0, -20.951) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(34.39, -0.87, -85.23),
						pos = Vector3.new(0.083, 1.248, -0.46),
					},
					Neck = { rot = Vector3.new(-18.114, 4.683, 0) },
					RightShoulder = { rot = Vector3.new(63.581, 0, 42.542) },
					LeftShoulder = { rot = Vector3.new(27.722, 0, -56.319) },
					RightHip = { rot = Vector3.new(44.349, 0, 18.384) },
					LeftHip = { rot = Vector3.new(-13.751, 0, -18.68) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(54.91, 0.95, -87.11),
						pos = Vector3.new(0.041, 0.735, -0.03),
					},
					Neck = { rot = Vector3.new(-29.85, 1.51, 0) },
					RightShoulder = { rot = Vector3.new(29.119, 0, 56.701) },
					LeftShoulder = { rot = Vector3.new(33.044, 0, -52.346) },
					RightHip = { rot = Vector3.new(28.494, 0, 11.595) },
					LeftHip = { rot = Vector3.new(-0.891, 0, -11.87) },
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
					RightShoulder = { rot = Vector3.new(15.101, 0, 68.651) },
					LeftShoulder = { rot = Vector3.new(40.978, 0, -55.011) },
					RightHip = { rot = Vector3.new(10.705, 0, 8.067) },
					LeftHip = { rot = Vector3.new(15.295, 0, -8.067) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(72.82, 1.5, -89.09),
						pos = Vector3.new(-0.031, -0.217, 0.381),
					},
					Neck = { rot = Vector3.new(-23.889, -0.333, 0) },
					RightShoulder = { rot = Vector3.new(13.944, 0, 73.415) },
					LeftShoulder = { rot = Vector3.new(43.191, 0, -59.297) },
					RightHip = { rot = Vector3.new(4.698, 0, 7.657) },
					LeftHip = { rot = Vector3.new(20.71, 0, -7.398) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = {
						rot = Vector3.new(83.44, 0.67, -89.75),
						pos = Vector3.new(-0.159, -1.939, 0.785),
					},
					Neck = { rot = Vector3.new(11.351, -0.213, 0) },
					RightShoulder = { rot = Vector3.new(19.602, 0, 76.969) },
					LeftShoulder = { rot = Vector3.new(32.51, 0, -76.289) },
					RightHip = { rot = Vector3.new(11.005, 0, 11.934) },
					LeftHip = { rot = Vector3.new(13.229, 0, -10.382) },
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
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(-30.05, 0, 0), pos = Vector3.new(0, -0.248, -0.097) },
					Neck = { rot = Vector3.new(14.423, 0, 0) },
					RightShoulder = { rot = Vector3.new(231.6, 0, -81.8) },
					LeftShoulder = { rot = Vector3.new(231.6, 0, 81.8) },
					RightHip = { rot = Vector3.new(34.5, 0, 9.9), pos = Vector3.new(0, 0.189, 0) },
					LeftHip = { rot = Vector3.new(34.5, 0, -9.9), pos = Vector3.new(0, 0.189, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-43.07, 0, 0), pos = Vector3.new(0, -0.462, -0.196) },
					Neck = { rot = Vector3.new(23.846, 0, 0) },
					RightShoulder = { rot = Vector3.new(-106.1, 0, -35.8) },
					LeftShoulder = { rot = Vector3.new(-106.1, 0, 35.8) },
					RightHip = { rot = Vector3.new(46.1, 0, 9.9), pos = Vector3.new(0, 0.336, 0) },
					LeftHip = { rot = Vector3.new(46.1, 0, -9.9), pos = Vector3.new(0, 0.336, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(-52.67, 0, 0), pos = Vector3.new(0, -0.672, -0.281) },
					Neck = { rot = Vector3.new(32.502, 0, 0) },
					RightShoulder = { rot = Vector3.new(298.7, 0, -35.2) },
					LeftShoulder = { rot = Vector3.new(298.7, 0, 35.2) },
					RightHip = { rot = Vector3.new(50.6, 0, 9.9), pos = Vector3.new(0, 0.549, 0) },
					LeftHip = { rot = Vector3.new(50.6, 0, -9.9), pos = Vector3.new(0, 0.549, 0) },
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
				time = 0.24,
				pose = {
					Root = { rot = Vector3.new(-54.51, 0, 0), pos = Vector3.new(0, -0.763, -0.292) },
					Neck = { rot = Vector3.new(34.846, 0, 0) },
					RightShoulder = { rot = Vector3.new(146.9, 0, -18.4) },
					LeftShoulder = { rot = Vector3.new(146.9, 0, 18.4) },
					RightHip = { rot = Vector3.new(49.6, 0, 9.9), pos = Vector3.new(0, 0.675, 0) },
					LeftHip = { rot = Vector3.new(49.6, 0, -9.9), pos = Vector3.new(0, 0.675, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(-47.41, 0, 0), pos = Vector3.new(0, -0.745, -0.211) },
					Neck = { rot = Vector3.new(30.577, 0, 0) },
					RightShoulder = { rot = Vector3.new(121.3, 0, -18.4) },
					LeftShoulder = { rot = Vector3.new(121.3, 0, 18.4) },
					RightHip = { rot = Vector3.new(43.5, 0, 9.9), pos = Vector3.new(0, 0.699, 0) },
					LeftHip = { rot = Vector3.new(43.5, 0, -9.9), pos = Vector3.new(0, 0.699, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = { rot = Vector3.new(-35.17, 0, 0), pos = Vector3.new(0, -0.663, -0.094) },
					Neck = { rot = Vector3.new(22.952, 0, 0) },
					RightShoulder = { rot = Vector3.new(102.5, 0, -74.2) },
					LeftShoulder = { rot = Vector3.new(102.5, 0, 74.2) },
					RightHip = { rot = Vector3.new(33.9, 0, 9.9), pos = Vector3.new(0, 0.656, 0) },
					LeftHip = { rot = Vector3.new(33.9, 0, -9.9), pos = Vector3.new(0, 0.656, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(-22, 0, 0), pos = Vector3.new(0, -0.55, 0) },
					Neck = { rot = Vector3.new(15, 0, 0) },
					RightShoulder = { rot = Vector3.new(100.2, 0, -59) },
					LeftShoulder = { rot = Vector3.new(102, 0, 68.9) },
					RightHip = { rot = Vector3.new(22.3, 0, 9.9), pos = Vector3.new(0, 0.575, 0) },
					LeftHip = { rot = Vector3.new(22.3, 0, -9.9), pos = Vector3.new(0, 0.575, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = { rot = Vector3.new(-11.25, 0, 0), pos = Vector3.new(0, -0.355, 0.054) },
					Neck = { rot = Vector3.new(5.361, 0, 0) },
					RightShoulder = { rot = Vector3.new(113.6, 0, -70.7) },
					LeftShoulder = { rot = Vector3.new(113.6, 0, 70.7) },
					RightHip = { rot = Vector3.new(11.8, 0, 9.9), pos = Vector3.new(0, 0.399, 0) },
					LeftHip = { rot = Vector3.new(11.8, 0, -9.9), pos = Vector3.new(0, 0.399, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = { rot = Vector3.new(-2.88, 0, 0), pos = Vector3.new(0, -0.116, 0.088) },
					Neck = { rot = Vector3.new(-5.097, 0, 0) },
					RightShoulder = { rot = Vector3.new(128.6, 0, -73.1) },
					LeftShoulder = { rot = Vector3.new(128.6, 0, 73.1) },
					RightHip = { rot = Vector3.new(2.3, 0, 9.9), pos = Vector3.new(0, 0.171, 0) },
					LeftHip = { rot = Vector3.new(2.3, 0, -9.9), pos = Vector3.new(0, 0.171, 0) },
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
				time = 0.66,
				pose = {
					Root = { rot = Vector3.new(9.73, 0, 0), pos = Vector3.new(0, 0.021, 0.127) },
					Neck = { rot = Vector3.new(-11.83, 0, 0) },
					RightShoulder = { rot = Vector3.new(134.7, 0, -72.4) },
					LeftShoulder = { rot = Vector3.new(134.7, 0, 72.4) },
					RightHip = { rot = Vector3.new(-15.1, 0, 9.8) },
					LeftHip = { rot = Vector3.new(-15.1, 0, -9.8) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = { rot = Vector3.new(12.52, 0, 0), pos = Vector3.new(0, 0.047, 0.166) },
					Neck = { rot = Vector3.new(-14.549, 0, 0) },
					RightShoulder = { rot = Vector3.new(136.1, 0, -70.6) },
					LeftShoulder = { rot = Vector3.new(136.1, 0, 70.6) },
					RightHip = { rot = Vector3.new(-18.1, 0, 9.9) },
					LeftHip = { rot = Vector3.new(-18.1, 0, -9.9) },
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
				time = 0.84,
				pose = {
					Root = { rot = Vector3.new(0.96, 0, 0), pos = Vector3.new(0, -0.07, 0.034) },
					Neck = { rot = Vector3.new(-7.38, 0, 0) },
					RightShoulder = { rot = Vector3.new(127, 0, -72.6) },
					LeftShoulder = { rot = Vector3.new(127, 0, 72.6) },
					RightHip = { rot = Vector3.new(-4.6, 0, 9.9), pos = Vector3.new(0, 0.122, 0) },
					LeftHip = { rot = Vector3.new(-4.6, 0, -9.9), pos = Vector3.new(0, 0.122, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = { rot = Vector3.new(-11.36, 0, 0), pos = Vector3.new(0, -0.207, -0.134) },
					Neck = { rot = Vector3.new(2.416, 0, 0) },
					RightShoulder = { rot = Vector3.new(202.5, 0, -74.7) },
					LeftShoulder = { rot = Vector3.new(202.5, 0, 74.7) },
					RightHip = { rot = Vector3.new(7.6, 0, 9.9), pos = Vector3.new(0, 0.244, 0) },
					LeftHip = { rot = Vector3.new(7.6, 0, -9.9), pos = Vector3.new(0, 0.244, 0) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = { rot = Vector3.new(-22.55, 0, 0), pos = Vector3.new(0, -0.409, -0.282) },
					Neck = { rot = Vector3.new(10.996, 0, 0) },
					RightShoulder = { rot = Vector3.new(334.6, 0, -120.3) },
					LeftShoulder = { rot = Vector3.new(334.6, 0, 120.3) },
					RightHip = { rot = Vector3.new(16.8, 0, 9.9), pos = Vector3.new(0, 0.41, 0) },
					LeftHip = { rot = Vector3.new(16.8, 0, -9.9), pos = Vector3.new(0, 0.41, 0) },
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
				time = 1.02,
				pose = {
					Root = { rot = Vector3.new(-28.87, 0, 0), pos = Vector3.new(0, -0.768, -0.371) },
					Neck = { rot = Vector3.new(15.905, 0, 0) },
					RightShoulder = { rot = Vector3.new(-270, 0, -98.3) },
					LeftShoulder = { rot = Vector3.new(-90, 0, 118.6) },
					RightHip = { rot = Vector3.new(10.3, 0, 8.5), pos = Vector3.new(0, 0.727, 0) },
					LeftHip = { rot = Vector3.new(10.3, 0, -8.5), pos = Vector3.new(0, 0.727, 0) },
				},
			},
			{
				time = 1.08,
				pose = {
					Root = { rot = Vector3.new(-30.72, 0, 0), pos = Vector3.new(0, -1.251, -0.427) },
					Neck = { rot = Vector3.new(18.84, 0, 0) },
					RightShoulder = { rot = Vector3.new(65.8, 0, -71.9) },
					LeftShoulder = { rot = Vector3.new(65.8, 0, 71.9) },
					RightHip = { rot = Vector3.new(-13.8, 0, 5.2), pos = Vector3.new(0, 0.848, 0) },
					LeftHip = { rot = Vector3.new(-13.8, 0, -5.2), pos = Vector3.new(0, 0.848, 0) },
				},
			},
			{
				time = 1.14,
				pose = {
					Root = { rot = Vector3.new(-30.18, 0, 0), pos = Vector3.new(0, -1.542, -0.45) },
					Neck = { rot = Vector3.new(19.977, 0, 0) },
					RightShoulder = { rot = Vector3.new(89.5, 0, -53.8) },
					LeftShoulder = { rot = Vector3.new(89.5, 0, 53.8) },
					RightHip = { rot = Vector3.new(-33.3, 0, 2.9), pos = Vector3.new(0, 0.646, 0) },
					LeftHip = { rot = Vector3.new(-33.3, 0, -2.9), pos = Vector3.new(0, 0.646, 0) },
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
				time = 1.2,
				pose = {
					Root = { rot = Vector3.new(-29.13, 0, 0), pos = Vector3.new(0, -1.56, -0.446) },
					Neck = { rot = Vector3.new(20.107, 0, 0) },
					RightShoulder = { rot = Vector3.new(20, 0, 10) },
					LeftShoulder = { rot = Vector3.new(20, 0, -10) },
					RightHip = { rot = Vector3.new(-35.1, 0, 2.8), pos = Vector3.new(0, 0.643, 0) },
					LeftHip = { rot = Vector3.new(-35.1, 0, -2.8), pos = Vector3.new(0, 0.643, 0) },
				},
			},
			{
				time = 1.26,
				pose = {
					Root = { rot = Vector3.new(-28.09, 0, 0), pos = Vector3.new(0, -1.584, -0.433) },
					Neck = { rot = Vector3.new(20.393, 0, 0) },
					RightShoulder = { rot = Vector3.new(20, 0, 10) },
					LeftShoulder = { rot = Vector3.new(20, 0, -10) },
					RightHip = { rot = Vector3.new(-36.4, 0, 2.8), pos = Vector3.new(0, 0.665, 0) },
					LeftHip = { rot = Vector3.new(-36.4, 0, -2.8), pos = Vector3.new(0, 0.665, 0) },
				},
			},
			{
				time = 1.32,
				pose = {
					Root = { rot = Vector3.new(-26.98, 0, 0), pos = Vector3.new(0, -1.6, -0.413) },
					Neck = { rot = Vector3.new(20.642, 0, 0) },
					RightShoulder = { rot = Vector3.new(79.2, 0, -32.3) },
					LeftShoulder = { rot = Vector3.new(79.2, 0, 32.3) },
					RightHip = { rot = Vector3.new(-37.4, 0, 2.8), pos = Vector3.new(0, 0.692, 0) },
					LeftHip = { rot = Vector3.new(-37.4, 0, -2.8), pos = Vector3.new(0, 0.692, 0) },
				},
			},
			{
				time = 1.38,
				pose = {
					Root = { rot = Vector3.new(-25.73, 0, 0), pos = Vector3.new(0, -1.586, -0.386) },
					Neck = { rot = Vector3.new(20.633, 0, 0) },
					RightShoulder = { rot = Vector3.new(78.3, 0, -31.9) },
					LeftShoulder = { rot = Vector3.new(78.3, 0, 31.9) },
					RightHip = { rot = Vector3.new(-37.8, 0, 2.8), pos = Vector3.new(0, 0.71, 0) },
					LeftHip = { rot = Vector3.new(-37.8, 0, -2.8), pos = Vector3.new(0, 0.71, 0) },
				},
			},
			{
				time = 1.44,
				pose = {
					Root = { rot = Vector3.new(-24.27, 0, 0), pos = Vector3.new(0, -1.518, -0.355) },
					Neck = { rot = Vector3.new(20.144, 0, 0) },
					RightShoulder = { rot = Vector3.new(75.4, 0, -31.1) },
					LeftShoulder = { rot = Vector3.new(75.4, 0, 31.1) },
					RightHip = { rot = Vector3.new(-37.5, 0, 2.8), pos = Vector3.new(0, 0.699, 0) },
					LeftHip = { rot = Vector3.new(-37.5, 0, -2.8), pos = Vector3.new(0, 0.699, 0) },
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
				time = 1.5,
				pose = {
					Root = { rot = Vector3.new(-22.54, 0, 0), pos = Vector3.new(0, -1.363, -0.316) },
					Neck = { rot = Vector3.new(18.881, 0, 0) },
					RightShoulder = { rot = Vector3.new(67.8, 0, -27.9) },
					LeftShoulder = { rot = Vector3.new(67.8, 0, 27.9) },
					RightHip = { rot = Vector3.new(-33.4, 0, 3.2), pos = Vector3.new(0, 0.711, 0) },
					LeftHip = { rot = Vector3.new(-33.4, 0, -3.2), pos = Vector3.new(0, 0.711, 0) },
				},
			},
			{
				time = 1.56,
				pose = {
					Root = { rot = Vector3.new(-20.59, 0, 0), pos = Vector3.new(0, -1.119, -0.264) },
					Neck = { rot = Vector3.new(16.862, 0, 0) },
					RightShoulder = { rot = Vector3.new(55.2, 0, -20.4) },
					LeftShoulder = { rot = Vector3.new(55.2, 0, 20.4) },
					RightHip = { rot = Vector3.new(-23.1, 0, 4.5), pos = Vector3.new(0, 0.766, 0) },
					LeftHip = { rot = Vector3.new(-23.1, 0, -4.5), pos = Vector3.new(0, 0.766, 0) },
				},
			},
			{
				time = 1.62,
				pose = {
					Root = { rot = Vector3.new(-18.49, 0, 0), pos = Vector3.new(0, -0.839, -0.206) },
					Neck = { rot = Vector3.new(14.522, 0, 0) },
					RightShoulder = { rot = Vector3.new(42.8, 0, -11.2) },
					LeftShoulder = { rot = Vector3.new(42.8, 0, 11.2) },
					RightHip = { rot = Vector3.new(-10.9, 0, 6.2), pos = Vector3.new(0, 0.735, 0) },
					LeftHip = { rot = Vector3.new(-10.9, 0, -6.2), pos = Vector3.new(0, 0.735, 0) },
				},
			},
			{
				time = 1.68,
				pose = {
					Root = { rot = Vector3.new(-16.3, 0, 0), pos = Vector3.new(0, -0.574, -0.153) },
					Neck = { rot = Vector3.new(12.305, 0, 0) },
					RightShoulder = { rot = Vector3.new(31.9, 0, -1.8) },
					LeftShoulder = { rot = Vector3.new(31.9, 0, 1.8) },
					RightHip = { rot = Vector3.new(0.2, 0, 8), pos = Vector3.new(0, 0.595, 0) },
					LeftHip = { rot = Vector3.new(0.2, 0, -8), pos = Vector3.new(0, 0.595, 0) },
				},
			},
			{
				time = 1.74,
				pose = {
					Root = { rot = Vector3.new(-14.12, 0, 0), pos = Vector3.new(0, -0.377, -0.115) },
					Neck = { rot = Vector3.new(10.65, 0, 0) },
					RightShoulder = { rot = Vector3.new(23.6, 0, 6.4) },
					LeftShoulder = { rot = Vector3.new(23.6, 0, -6.4) },
					RightHip = { rot = Vector3.new(7.6, 0, 9.3), pos = Vector3.new(0, 0.42, 0) },
					LeftHip = { rot = Vector3.new(7.6, 0, -9.3), pos = Vector3.new(0, 0.42, 0) },
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
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(-27.28, 0, 0), pos = Vector3.new(0, -0.199, 0.025) },
					Neck = { rot = Vector3.new(-13.368, 0, 0) },
					RightShoulder = { rot = Vector3.new(257.1, 0, -120.7) },
					LeftShoulder = { rot = Vector3.new(257.1, 0, 120.7) },
					RightHip = { rot = Vector3.new(41.3, 0, 0), pos = Vector3.new(0, 0.136, 0) },
					LeftHip = { rot = Vector3.new(41.3, 0, 0), pos = Vector3.new(0, 0.136, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-47.75, 0, 0), pos = Vector3.new(0, -0.501, 0.067) },
					Neck = { rot = Vector3.new(-20.651, 0, 0) },
					RightShoulder = { rot = Vector3.new(117.4, 0, -18.4) },
					LeftShoulder = { rot = Vector3.new(117.4, 0, 18.4) },
					RightHip = { rot = Vector3.new(75.8, 0, 0), pos = Vector3.new(0, 0.089, 0) },
					LeftHip = { rot = Vector3.new(75.8, 0, 0), pos = Vector3.new(0, 0.089, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(-64.07, 0, 0), pos = Vector3.new(0, -0.737, 0.081) },
					Neck = { rot = Vector3.new(-27.619, 0, 0) },
					RightShoulder = { rot = Vector3.new(115.7, 0, -18.4) },
					LeftShoulder = { rot = Vector3.new(115.7, 0, 18.4) },
					RightHip = { rot = Vector3.new(90, 0, 0.9), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(90, 0, -0.9), pos = Vector3.new(0, 0.4, 0) },
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
				time = 0.24,
				pose = {
					Root = { rot = Vector3.new(-70.95, 0, 0), pos = Vector3.new(0, -0.694, 0.016) },
					Neck = { rot = Vector3.new(-30.295, 0, 0) },
					RightShoulder = { rot = Vector3.new(131.1, 0, -14.4) },
					LeftShoulder = { rot = Vector3.new(131, 0, 14.3) },
					RightHip = { rot = Vector3.new(90, 0, 1.8), pos = Vector3.new(0, 0.593, 0) },
					LeftHip = { rot = Vector3.new(90, 0, -1.8), pos = Vector3.new(0, 0.593, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(-66.65, 0, 0), pos = Vector3.new(0, -0.335, -0.153) },
					Neck = { rot = Vector3.new(-29.187, 0, 0) },
					RightShoulder = { rot = Vector3.new(94.6, 0, 5.8) },
					LeftShoulder = { rot = Vector3.new(90.5, 0, -8.3) },
					RightHip = { rot = Vector3.new(90, 0, 2.8), pos = Vector3.new(0, 0.125, 0) },
					LeftHip = { rot = Vector3.new(90, 0, -2.8), pos = Vector3.new(0, 0.125, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = { rot = Vector3.new(-54.92, 0, 0), pos = Vector3.new(0, 0.185, -0.367) },
					Neck = { rot = Vector3.new(-25.555, 0, 0) },
					RightShoulder = { rot = Vector3.new(98.1, 0, 40.3) },
					LeftShoulder = { rot = Vector3.new(80.9, 0, -47.2) },
					RightHip = { rot = Vector3.new(72.374, 0, 15.375) },
					LeftHip = { rot = Vector3.new(33.448, 0, -15.375) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(-40, 0, 0), pos = Vector3.new(0, 0.7, -0.55) },
					Neck = { rot = Vector3.new(-20, 0, 0) },
					RightShoulder = { rot = Vector3.new(120, 0, 50) },
					LeftShoulder = { rot = Vector3.new(100, 0, -60) },
					RightHip = { rot = Vector3.new(77.157, 0, 14.622) },
					LeftHip = { rot = Vector3.new(32.843, 0, -14.622) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = { rot = Vector3.new(-25.57, 0, 0), pos = Vector3.new(0, 1.279, -0.691) },
					Neck = { rot = Vector3.new(-9.415, 0, 0) },
					RightShoulder = { rot = Vector3.new(117.3, 0, 32.5) },
					LeftShoulder = { rot = Vector3.new(104.4, 0, -44.8) },
					RightHip = { rot = Vector3.new(72.28, 0, 16.807) },
					LeftHip = { rot = Vector3.new(55.509, 0, -16.807) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = { rot = Vector3.new(-13.22, 0, 0), pos = Vector3.new(0, 1.876, -0.804) },
					Neck = { rot = Vector3.new(3.626, 0, 0) },
					RightShoulder = { rot = Vector3.new(67.3, 0, -68.4) },
					LeftShoulder = { rot = Vector3.new(58.7, 0, 68.4) },
					RightHip = { rot = Vector3.new(65.516, 0, 20.969) },
					LeftHip = { rot = Vector3.new(86.379, 0, -20.969) },
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
					RightHip = { rot = Vector3.new(64.101, 0, 24.951) },
					LeftHip = { rot = Vector3.new(99.899, 0, -24.951) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = { rot = Vector3.new(1.7, 0, 0), pos = Vector3.new(0, 2.221, -0.873) },
					Neck = { rot = Vector3.new(13.335, 0, 0) },
					RightShoulder = { rot = Vector3.new(49.5, 0, -50.5) },
					LeftShoulder = { rot = Vector3.new(44.7, 0, 49.2) },
					RightHip = { rot = Vector3.new(74.568, 0, 27.292) },
					LeftHip = { rot = Vector3.new(90.297, 0, -27.292) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = { rot = Vector3.new(6.08, 0, 0), pos = Vector3.new(0, 2.314, -0.885) },
					Neck = { rot = Vector3.new(18.448, 0, 0) },
					RightShoulder = { rot = Vector3.new(93.7, 0, 47.5) },
					LeftShoulder = { rot = Vector3.new(263.3, 0, -94.5) },
					RightHip = { rot = Vector3.new(92.909, 0, 27.304) },
					LeftHip = { rot = Vector3.new(72.821, 0, -27.304) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = { rot = Vector3.new(12, 0, 0), pos = Vector3.new(0, 2.25, -0.8) },
					Neck = { rot = Vector3.new(18, 0, 0) },
					RightShoulder = { rot = Vector3.new(150, 0, 60) },
					LeftShoulder = { rot = Vector3.new(150, 0, -60) },
					RightHip = { rot = Vector3.new(101.919, 0, 24.613) },
					LeftHip = { rot = Vector3.new(62.081, 0, -24.613) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = { rot = Vector3.new(21.58, 0, 0), pos = Vector3.new(0, 2.003, -0.57) },
					Neck = { rot = Vector3.new(4.942, 0, 0) },
					RightShoulder = { rot = Vector3.new(140.877, 0, 63.179) },
					LeftShoulder = { rot = Vector3.new(142.395, 0, -62.42) },
					RightHip = { rot = Vector3.new(91.997, 0, 19.956) },
					LeftHip = { rot = Vector3.new(65.213, 0, -19.956) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = { rot = Vector3.new(34.01, 0, 0), pos = Vector3.new(0, 1.618, -0.249) },
					Neck = { rot = Vector3.new(-13.86, 0, 0) },
					RightShoulder = { rot = Vector3.new(123.535, 0, 66.299) },
					LeftShoulder = { rot = Vector3.new(124.415, 0, -65.859) },
					RightHip = { rot = Vector3.new(69.055, 0, 15.078) },
					LeftHip = { rot = Vector3.new(78.77, 0, -15.078) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = { rot = Vector3.new(47.7, 0, 0), pos = Vector3.new(0, 1.024, 0.095) },
					Neck = { rot = Vector3.new(-24.872, 0, 0) },
					RightShoulder = { rot = Vector3.new(103.285, 0, 69.462) },
					LeftShoulder = { rot = Vector3.new(103.312, 0, -69.448) },
					RightHip = { rot = Vector3.new(52.752, 0, 12.642) },
					LeftHip = { rot = Vector3.new(87.893, 0, -12.642) },
				},
			},
			{
				time = 0.97,
				pose = {
					Root = { rot = Vector3.new(50, 0, 0), pos = Vector3.new(0, 0.9, 0.15) },
					Neck = { rot = Vector3.new(-25, 0, 0) },
					RightShoulder = { rot = Vector3.new(100, 0, 70) },
					LeftShoulder = { rot = Vector3.new(100, 0, -70) },
					RightHip = { rot = Vector3.new(52.158, 0, 12.625) },
					LeftHip = { rot = Vector3.new(87.842, 0, -12.625) },
				},
			},
			{
				time = 1.02,
				pose = {
					Root = { rot = Vector3.new(61.29, 0, 0), pos = Vector3.new(0, -0.076, 0.489) },
					Neck = { rot = Vector3.new(-15.076, 0, 0) },
					RightShoulder = { rot = Vector3.new(78.339, 0, 73.296) },
					LeftShoulder = { rot = Vector3.new(78.339, 0, -73.296) },
					RightHip = { rot = Vector3.new(59.197, 0, 14.06) },
					LeftHip = { rot = Vector3.new(80.147, 0, -14.06) },
				},
			},
			{
				time = 1.08,
				pose = {
					Root = { rot = Vector3.new(74.56, 0, 0), pos = Vector3.new(0, -1.571, 0.937) },
					Neck = { rot = Vector3.new(8.511, 0, 0) },
					RightShoulder = { rot = Vector3.new(48.13, 0, 77.538) },
					LeftShoulder = { rot = Vector3.new(48.13, 0, -77.538) },
					RightHip = { rot = Vector3.new(71.278, 0, 16.065) },
					LeftHip = { rot = Vector3.new(70.478, 0, -16.065) },
				},
			},
			{
				time = 1.14,
				pose = {
					Root = { rot = Vector3.new(87.78, 0, 0), pos = Vector3.new(0, -2.476, 1.193) },
					Neck = { rot = Vector3.new(24.564, 0, 0) },
					RightShoulder = { rot = Vector3.new(30.454, 0, 79.939) },
					LeftShoulder = { rot = Vector3.new(30.454, 0, -79.939) },
					RightHip = { rot = Vector3.new(72.084, 0, 16.028) },
					LeftHip = { rot = Vector3.new(71.852, 0, -16.028) },
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
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-7.37, 26.41, 13.29),
						pos = Vector3.new(0.9, -0.159, -0.459),
					},
					Neck = { rot = Vector3.new(15.1, -20, -14) },
					RightShoulder = { rot = Vector3.new(39.2, 0, -82.1) },
					LeftShoulder = { rot = Vector3.new(83.8, 0, 60.8) },
					RightHip = { rot = Vector3.new(-13.8, 0, -33.4) },
					LeftHip = { rot = Vector3.new(27.8, 0, -35), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-6.9, 26.03, 13.02),
						pos = Vector3.new(0.9, -0.157, -0.457),
					},
					Neck = { rot = Vector3.new(14.896, -20, -14) },
					RightShoulder = { rot = Vector3.new(40.7, 0, -82.7) },
					LeftShoulder = { rot = Vector3.new(83.5, 0, 60.4) },
					RightHip = { rot = Vector3.new(-14.4, 0, -33.2) },
					LeftHip = { rot = Vector3.new(26.9, 0, -35.1), pos = Vector3.new(0, 0.214, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-6.52, 25.73, 12.81),
						pos = Vector3.new(0.9, -0.156, -0.456),
					},
					Neck = { rot = Vector3.new(14.732, -20, -14) },
					RightShoulder = { rot = Vector3.new(42.1, 0, -83.3) },
					LeftShoulder = { rot = Vector3.new(83.2, 0, 60.1) },
					RightHip = { rot = Vector3.new(-15, 0, -33) },
					LeftHip = { rot = Vector3.new(26.2, 0, -35.2), pos = Vector3.new(0, 0.217, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-6.57, 25.77, 12.83),
						pos = Vector3.new(0.9, -0.156, -0.456),
					},
					Neck = { rot = Vector3.new(14.752, -20, -14) },
					RightShoulder = { rot = Vector3.new(42.8, 0, -83.6) },
					LeftShoulder = { rot = Vector3.new(83.2, 0, 60.1) },
					RightHip = { rot = Vector3.new(-14.9, 0, -33.1) },
					LeftHip = { rot = Vector3.new(26.3, 0, -35.2), pos = Vector3.new(0, 0.217, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-7.37, 26.41, 13.29),
						pos = Vector3.new(0.9, -0.159, -0.459),
					},
					Neck = { rot = Vector3.new(15.1, -20, -14) },
					RightShoulder = { rot = Vector3.new(42.1, 0, -83.4) },
					LeftShoulder = { rot = Vector3.new(83.8, 0, 60.8) },
					RightHip = { rot = Vector3.new(-13.8, 0, -33.4) },
					LeftHip = { rot = Vector3.new(27.8, 0, -35), pos = Vector3.new(0, 0.211, 0) },
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
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-9.15, 27.78, 14.32),
						pos = Vector3.new(0.9, -0.173, -0.473),
					},
					Neck = { rot = Vector3.new(16.82, -20, -14) },
					RightShoulder = { rot = Vector3.new(99.7, 0, -70.1) },
					LeftShoulder = { rot = Vector3.new(86.3, 0, 62.7) },
					RightHip = { rot = Vector3.new(-11.5, 0, -34.1) },
					LeftHip = { rot = Vector3.new(30.7, 0, -34.6), pos = Vector3.new(0, 0.207, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-11.01, 29.14, 15.42),
						pos = Vector3.new(0.9, -0.196, -0.496),
					},
					Neck = { rot = Vector3.new(19.487, -20, -14) },
					RightShoulder = { rot = Vector3.new(104.9, 0, -62.6) },
					LeftShoulder = { rot = Vector3.new(90.2, 0, 65) },
					RightHip = { rot = Vector3.new(-9.5, 0, -35) },
					LeftHip = { rot = Vector3.new(33.4, 0, -34.1), pos = Vector3.new(0, 0.212, 0) },
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
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-11.52, 29.51, 15.74),
						pos = Vector3.new(0.9, -0.199, -0.499),
					},
					Neck = { rot = Vector3.new(19.823, -20, -14) },
					RightShoulder = { rot = Vector3.new(105.4, 0, -55) },
					LeftShoulder = { rot = Vector3.new(90.9, 0, 65.5) },
					RightHip = { rot = Vector3.new(-8.9, 0, -35.2) },
					LeftHip = { rot = Vector3.new(34.3, 0, -34), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-10.46, 28.76, 15.1),
						pos = Vector3.new(0.9, -0.189, -0.489),
					},
					Neck = { rot = Vector3.new(18.673, -20, -14) },
					RightShoulder = { rot = Vector3.new(103.3, 0, -62.7) },
					LeftShoulder = { rot = Vector3.new(89, 0, 64.4) },
					RightHip = { rot = Vector3.new(-10.1, 0, -34.8) },
					LeftHip = { rot = Vector3.new(32.7, 0, -34.3), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-8.83, 27.55, 14.13),
						pos = Vector3.new(0.9, -0.175, -0.475),
					},
					Neck = { rot = Vector3.new(17.051, -20, -14) },
					RightShoulder = { rot = Vector3.new(100.1, 0, -70.2) },
					LeftShoulder = { rot = Vector3.new(86.4, 0, 62.6) },
					RightHip = { rot = Vector3.new(-12.1, 0, -34.1) },
					LeftHip = { rot = Vector3.new(30.1, 0, -34.7), pos = Vector3.new(0, 0.214, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-7.62, 26.61, 13.43),
						pos = Vector3.new(0.9, -0.164, -0.464),
					},
					Neck = { rot = Vector3.new(15.664, -20, -14) },
					RightShoulder = { rot = Vector3.new(42.3, 0, -83.8) },
					LeftShoulder = { rot = Vector3.new(84.4, 0, 61.1) },
					RightHip = { rot = Vector3.new(-13.6, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.1, 0, -35), pos = Vector3.new(0, 0.215, 0) },
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
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-7.77, 26.72, 13.51),
						pos = Vector3.new(0.9, -0.161, -0.461),
					},
					Neck = { rot = Vector3.new(15.27, -20, -14) },
					RightShoulder = { rot = Vector3.new(41.5, 0, -83.3) },
					LeftShoulder = { rot = Vector3.new(84.2, 0, 61.1) },
					RightHip = { rot = Vector3.new(-13.2, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.5, 0, -34.9), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(-9.53, 28.05, 14.53),
						pos = Vector3.new(0.9, -0.18, -0.48),
					},
					Neck = { rot = Vector3.new(17.6, -20, -14) },
					RightShoulder = { rot = Vector3.new(101.3, 0, -70.2) },
					LeftShoulder = { rot = Vector3.new(87.4, 0, 63.3) },
					RightHip = { rot = Vector3.new(-11.2, 0, -34.3) },
					LeftHip = { rot = Vector3.new(31.2, 0, -34.5), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(-11.34, 29.37, 15.62),
						pos = Vector3.new(0.9, -0.199, -0.499),
					},
					Neck = { rot = Vector3.new(19.93, -20, -14) },
					RightShoulder = { rot = Vector3.new(105.5, 0, -55.1) },
					LeftShoulder = { rot = Vector3.new(90.9, 0, 65.4) },
					RightHip = { rot = Vector3.new(-9.1, 0, -35.1) },
					LeftHip = { rot = Vector3.new(34, 0, -34), pos = Vector3.new(0, 0.212, 0) },
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
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(-11.51, 29.55, 15.76),
						pos = Vector3.new(0.9, -0.196, -0.496),
					},
					Neck = { rot = Vector3.new(19.536, -20, -14) },
					RightShoulder = { rot = Vector3.new(104.9, 0, -55) },
					LeftShoulder = { rot = Vector3.new(90.6, 0, 65.5) },
					RightHip = { rot = Vector3.new(-8.8, 0, -35.2) },
					LeftHip = { rot = Vector3.new(38.2, 0, -35.7) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = {
						rot = Vector3.new(-10.26, 28.73, 15.05),
						pos = Vector3.new(0.9, -0.185, -0.485),
					},
					Neck = { rot = Vector3.new(18.149, -20, -14) },
					RightShoulder = { rot = Vector3.new(102.3, 0, -70.3) },
					LeftShoulder = { rot = Vector3.new(88.3, 0, 64.1) },
					RightHip = { rot = Vector3.new(-10.3, 0, -34.7) },
					LeftHip = { rot = Vector3.new(32.5, 0, -34.3), pos = Vector3.new(0, 0.208, 0) },
				},
			},
			{
				time = 1.02,
				pose = {
					Root = {
						rot = Vector3.new(-8.63, 27.54, 14.11),
						pos = Vector3.new(0.9, -0.171, -0.471),
					},
					Neck = { rot = Vector3.new(16.527, -20, -14) },
					RightShoulder = { rot = Vector3.new(221, 0, -133.1) },
					LeftShoulder = { rot = Vector3.new(85.8, 0, 62.3) },
					RightHip = { rot = Vector3.new(-12.3, 0, -34.1) },
					LeftHip = { rot = Vector3.new(33.4, 0, -36.7) },
				},
			},
			{
				time = 1.08,
				pose = {
					Root = {
						rot = Vector3.new(-7.61, 26.68, 13.47),
						pos = Vector3.new(0.9, -0.161, -0.461),
					},
					Neck = { rot = Vector3.new(15.377, -20, -14) },
					RightShoulder = { rot = Vector3.new(41.8, 0, -83.4) },
					LeftShoulder = { rot = Vector3.new(84.1, 0, 61.1) },
					RightHip = { rot = Vector3.new(-13.5, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.2, 0, -35), pos = Vector3.new(0, 0.211, 0) },
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
				time = 1.14,
				pose = {
					Root = {
						rot = Vector3.new(-8.07, 26.83, 13.61),
						pos = Vector3.new(0.9, -0.165, -0.465),
					},
					Neck = { rot = Vector3.new(15.767, -20, -14) },
					RightShoulder = { rot = Vector3.new(41.7, 0, -83.6) },
					LeftShoulder = { rot = Vector3.new(84.9, 0, 61.4) },
					RightHip = { rot = Vector3.new(-12.9, 0, -33.6) },
					LeftHip = { rot = Vector3.new(28.8, 0, -34.8), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-9.86, 28.05, 14.57),
						pos = Vector3.new(0.9, -0.188, -0.488),
					},
					Neck = { rot = Vector3.new(18.601, -20, -14) },
					RightShoulder = { rot = Vector3.new(103.3, 0, -70.2) },
					LeftShoulder = { rot = Vector3.new(88.7, 0, 63.7) },
					RightHip = { rot = Vector3.new(-11, 0, -34.4) },
					LeftHip = { rot = Vector3.new(31.4, 0, -34.4), pos = Vector3.new(0, 0.218, 0) },
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
				time = 1.26,
				pose = {
					Root = {
						rot = Vector3.new(-11.78, 29.81, 15.97),
						pos = Vector3.new(0.9, -0.2, -0.5),
					},
					Neck = { rot = Vector3.new(19.999, -20.005, -14.005) },
					RightShoulder = { rot = Vector3.new(105.8, 0, -54.9) },
					LeftShoulder = { rot = Vector3.new(91.2, 0, 65.8) },
					RightHip = { rot = Vector3.new(-8.5, 0, -35.4) },
					LeftHip = { rot = Vector3.new(38.6, 0, -35.6) },
				},
			},
			{
				time = 1.32,
				pose = {
					Root = {
						rot = Vector3.new(-12.91, 31.65, 17.39),
						pos = Vector3.new(0.913, -0.2, -0.504),
					},
					Neck = { rot = Vector3.new(19.946, -20.226, -14.198) },
					RightShoulder = { rot = Vector3.new(19, 0, -61.9) },
					LeftShoulder = { rot = Vector3.new(91.3, 0, 66.9) },
					RightHip = { rot = Vector3.new(-6.6, 0, -36.6) },
					LeftHip = { rot = Vector3.new(37.8, 0, -34.1), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 1.38,
				pose = {
					Root = {
						rot = Vector3.new(-13.25, 33.31, 18.59),
						pos = Vector3.new(0.937, -0.199, -0.511),
					},
					Neck = { rot = Vector3.new(19.804, -20.657, -14.575) },
					RightShoulder = { rot = Vector3.new(19.5, 0, -61.5) },
					LeftShoulder = { rot = Vector3.new(90.7, 0, 67.3) },
					RightHip = { rot = Vector3.new(-5.7, 0, -38.1) },
					LeftHip = { rot = Vector3.new(39.9, 0, -35), pos = Vector3.new(0, 0.157, 0) },
				},
			},
			{
				time = 1.44,
				pose = {
					Root = {
						rot = Vector3.new(-12.97, 34.53, 19.37),
						pos = Vector3.new(0.964, -0.198, -0.519),
					},
					Neck = { rot = Vector3.new(19.56, -21.141, -14.998) },
					RightShoulder = { rot = Vector3.new(27.6, 0, -58.1) },
					LeftShoulder = { rot = Vector3.new(89.7, 0, 67.2) },
					RightHip = { rot = Vector3.new(-5.7, 0, -39.4) },
					LeftHip = { rot = Vector3.new(41, 0, -36.2), pos = Vector3.new(0, 0.143, 0) },
				},
			},
			{
				time = 1.5,
				pose = {
					Root = {
						rot = Vector3.new(-12.2, 35.03, 19.55),
						pos = Vector3.new(0.985, -0.195, -0.523),
					},
					Neck = { rot = Vector3.new(19.201, -21.519, -15.33) },
					RightShoulder = { rot = Vector3.new(27.6, 0, -58.8) },
					LeftShoulder = { rot = Vector3.new(88.4, 0, 66.5) },
					RightHip = { rot = Vector3.new(-6.4, 0, -40.3) },
					LeftHip = { rot = Vector3.new(40.9, 0, -37.4), pos = Vector3.new(0, 0.139, 0) },
				},
			},
			{
				time = 1.56,
				pose = {
					Root = {
						rot = Vector3.new(-11.13, 34.52, 18.96),
						pos = Vector3.new(0.992, -0.191, -0.522),
					},
					Neck = { rot = Vector3.new(18.713, -21.635, -15.431) },
					RightShoulder = { rot = Vector3.new(27.5, 0, -59.6) },
					LeftShoulder = { rot = Vector3.new(87.3, 0, 65.6) },
					RightHip = { rot = Vector3.new(-7.9, 0, -40.2) },
					LeftHip = { rot = Vector3.new(42.4, 0, -39.4) },
				},
			},
			{
				time = 1.62,
				pose = {
					Root = {
						rot = Vector3.new(-10.02, 32.7, 17.53),
						pos = Vector3.new(0.975, -0.185, -0.51),
					},
					Neck = { rot = Vector3.new(18.083, -21.331, -15.165) },
					RightShoulder = { rot = Vector3.new(100.5, 0, -73.1) },
					LeftShoulder = { rot = Vector3.new(86.5, 0, 64.4) },
					RightHip = { rot = Vector3.new(-9.7, 0, -38.9) },
					LeftHip = { rot = Vector3.new(36.3, 0, -37.7), pos = Vector3.new(0, 0.172, 0) },
				},
			},
			{
				time = 1.68,
				pose = {
					Root = {
						rot = Vector3.new(-9.19, 29.26, 15.21),
						pos = Vector3.new(0.925, -0.178, -0.486),
					},
					Neck = { rot = Vector3.new(17.298, -20.45, -14.393) },
					RightShoulder = { rot = Vector3.new(101, 0, -71.2) },
					LeftShoulder = { rot = Vector3.new(86.4, 0, 63.2) },
					RightHip = { rot = Vector3.new(-11.4, 0, -35.7) },
					LeftHip = { rot = Vector3.new(32, 0, -35.7), pos = Vector3.new(0, 0.202, 0) },
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
				time = 1.74,
				pose = {
					Root = {
						rot = Vector3.new(-9.03, 23.99, 11.98),
						pos = Vector3.new(0.771, -0.163, -0.42),
					},
					Neck = { rot = Vector3.new(15.878, -17.706, -11.993) },
					RightShoulder = { rot = Vector3.new(102.3, 0, -66.6) },
					LeftShoulder = { rot = Vector3.new(87, 0, 61) },
					RightHip = { rot = Vector3.new(-11.5, 0, -29) },
					LeftHip = { rot = Vector3.new(26.9, 0, -29.7), pos = Vector3.new(0, 0.231, 0) },
				},
			},
			{
				time = 1.8,
				pose = {
					Root = {
						rot = Vector3.new(-9.7, 17.37, 8.1),
						pos = Vector3.new(0.415, -0.134, -0.272),
					},
					Neck = { rot = Vector3.new(13.115, -11.385, -6.462) },
					RightShoulder = { rot = Vector3.new(73.5, 0, -46.2) },
					LeftShoulder = { rot = Vector3.new(87.8, 0, 56.2) },
					RightHip = { rot = Vector3.new(-7.9, 0, -16.3) },
					LeftHip = { rot = Vector3.new(23.3, 0, -17.3), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 1.86,
				pose = {
					Root = {
						rot = Vector3.new(-11, 10.34, 3.96),
						pos = Vector3.new(0.085, -0.107, -0.135),
					},
					Neck = { rot = Vector3.new(10.63, -5.506, -1.318) },
					RightShoulder = { rot = Vector3.new(77.6, 0, -33.1) },
					LeftShoulder = { rot = Vector3.new(87.8, 0, 50.2) },
					RightHip = { rot = Vector3.new(-1.4, 0, -2.2), pos = Vector3.new(0, 0.008, 0) },
					LeftHip = { rot = Vector3.new(23.9, 0, -5.2), pos = Vector3.new(0, 0.096, 0) },
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
					RightShoulder = { rot = Vector3.new(114.7, 0, -135.1) },
					LeftShoulder = { rot = Vector3.new(91.8, 0, 130.5) },
					RightHip = { rot = Vector3.new(1, 0, 12.3), pos = Vector3.new(0, 0.847, 0) },
					LeftHip = { rot = Vector3.new(-0.4, 0, 10.1), pos = Vector3.new(0, 0.559, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(6.45, -0.01, -4.65),
						pos = Vector3.new(-0.15, -0.722, 0.05),
					},
					Neck = { rot = Vector3.new(25.834, 0.95, 0) },
					RightShoulder = { rot = Vector3.new(-65.9, 0, -81.8) },
					LeftShoulder = { rot = Vector3.new(92.6, 0, 130.4) },
					RightHip = { rot = Vector3.new(0.6, 0, 11.3), pos = Vector3.new(0, 0.909, 0) },
					LeftHip = { rot = Vector3.new(0.9, 0, 8.8), pos = Vector3.new(0, 0.652, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(6.15, -0.03, -2.7),
						pos = Vector3.new(-0.15, -0.728, 0.05),
					},
					Neck = { rot = Vector3.new(25.494, 3.174, 0) },
					RightShoulder = { rot = Vector3.new(113, 0, -134.8) },
					LeftShoulder = { rot = Vector3.new(93.6, 0, 130.2) },
					RightHip = { rot = Vector3.new(-0.8, 0, 10.8), pos = Vector3.new(0, 0.944, 0) },
					LeftHip = { rot = Vector3.new(3.5, 0, 7.9), pos = Vector3.new(0, 0.717, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(5.91, -0.05, -0.99),
						pos = Vector3.new(-0.15, -0.732, 0.05),
					},
					Neck = { rot = Vector3.new(25.221, 5.739, 0) },
					RightShoulder = { rot = Vector3.new(122.5, 0, -130.1) },
					LeftShoulder = { rot = Vector3.new(274.6, 0, 86.9) },
					RightHip = { rot = Vector3.new(-2.9, 0, 11), pos = Vector3.new(0, 0.935, 0) },
					LeftHip = { rot = Vector3.new(6.4, 0, 7.6), pos = Vector3.new(0, 0.72, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(5.94, -0.06, -0.33),
						pos = Vector3.new(-0.15, -0.731, 0.05),
					},
					Neck = { rot = Vector3.new(25.254, 7.706, 0) },
					RightShoulder = { rot = Vector3.new(-57.9, 0, -86.7) },
					LeftShoulder = { rot = Vector3.new(-87.8, 0, 71.9) },
					RightHip = { rot = Vector3.new(-5.2, 0, 12.1), pos = Vector3.new(0, 0.885, 0) },
					LeftHip = { rot = Vector3.new(8.5, 0, 8.4), pos = Vector3.new(0, 0.655, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(6.45, -0.01, -1.55),
						pos = Vector3.new(-0.15, -0.722, 0.05),
					},
					Neck = { rot = Vector3.new(25.834, 8.142, 0) },
					RightShoulder = { rot = Vector3.new(112.9, 0, -135.1) },
					LeftShoulder = { rot = Vector3.new(94.9, 0, 130.1) },
					RightHip = { rot = Vector3.new(-7.1, 0, 14.3), pos = Vector3.new(0, 0.822, 0) },
					LeftHip = { rot = Vector3.new(8.9, 0, 10.7), pos = Vector3.new(0, 0.533, 0) },
				},
			},
			{
				time = 0.31,
				pose = {
					Root = { rot = Vector3.new(6.6, 0, -2), pos = Vector3.new(-0.15, -0.72, 0.05) },
					Neck = { rot = Vector3.new(26, 8, 0) },
					RightShoulder = { rot = Vector3.new(-246.9, 0, -135.1) },
					LeftShoulder = { rot = Vector3.new(94.6, 0, 130.1) },
					RightHip = { rot = Vector3.new(-7.3, 0, 14.8), pos = Vector3.new(0, 0.814, 0) },
					LeftHip = { rot = Vector3.new(8.8, 0, 11.3), pos = Vector3.new(0, 0.508, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(7.57, 0.04, -5.12),
						pos = Vector3.new(-0.15, -0.68, 0.05),
					},
					Neck = { rot = Vector3.new(28.7, 2.968, 0) },
					RightShoulder = { rot = Vector3.new(297.2, 0, -81.6) },
					LeftShoulder = { rot = Vector3.new(-84.2, 0, 86.8) },
					RightHip = { rot = Vector3.new(-2.8, 0, 13.7), pos = Vector3.new(0, 1.06, 0) },
					LeftHip = { rot = Vector3.new(3, 0, 11.1), pos = Vector3.new(0, 0.721, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(8.7, 0.02, -8.95),
						pos = Vector3.new(-0.15, -0.613, 0.05),
					},
					Neck = { rot = Vector3.new(33.145, -6.201, 0) },
					RightShoulder = { rot = Vector3.new(-56.3, 0, -81.4) },
					LeftShoulder = { rot = Vector3.new(99.8, 0, 129.7) },
					RightHip = { rot = Vector3.new(5.2, 0, 10), pos = Vector3.new(0, 0.884, 0) },
					LeftHip = { rot = Vector3.new(-9.6, 0, 8.7), pos = Vector3.new(0, 0.608, 0) },
				},
			},
			{
				time = 0.45,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(9, 0, -10), pos = Vector3.new(-0.15, -0.6, 0.05) },
					Neck = { rot = Vector3.new(34, -8, 0) },
					RightShoulder = { rot = Vector3.new(-55.2, 0, -81.4) },
					LeftShoulder = { rot = Vector3.new(100.1, 0, 129.6) },
					RightHip = { rot = Vector3.new(6.1, 0, 10.5), pos = Vector3.new(0, 0.697, 0) },
					LeftHip = { rot = Vector3.new(-13, 0, 9.4), pos = Vector3.new(0, 0.412, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(9.01, 0, -10.07),
						pos = Vector3.new(-0.15, -0.604, 0.05),
					},
					Neck = { rot = Vector3.new(33.705, -7.41, 0) },
					RightShoulder = { rot = Vector3.new(-55.6, 0, -81.3) },
					LeftShoulder = { rot = Vector3.new(-80.3, 0, 87.2) },
					RightHip = { rot = Vector3.new(5.9, 0, 10.5), pos = Vector3.new(0, 0.804, 0) },
					LeftHip = { rot = Vector3.new(-11.9, 0, 9.4), pos = Vector3.new(0, 0.51, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(8.38, 0.03, -7.97),
						pos = Vector3.new(-0.15, -0.633, 0.05),
					},
					Neck = { rot = Vector3.new(31.788, -3.576, 0) },
					RightShoulder = { rot = Vector3.new(-58.2, 0, -81.5) },
					LeftShoulder = { rot = Vector3.new(-81.6, 0, 87.1) },
					RightHip = { rot = Vector3.new(3.3, 0, 10.8), pos = Vector3.new(0, 0.992, 0) },
					LeftHip = { rot = Vector3.new(-6, 0, 9.1), pos = Vector3.new(0, 0.7, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(7.38, 0.04, -4.6),
						pos = Vector3.new(-0.15, -0.674, 0.05),
					},
					Neck = { rot = Vector3.new(29.084, 1.832, 0) },
					RightShoulder = { rot = Vector3.new(117.8, 0, -135.1) },
					LeftShoulder = { rot = Vector3.new(-82.9, 0, 87) },
					RightHip = { rot = Vector3.new(-1, 0, 11.8), pos = Vector3.new(0, 1.054, 0) },
					LeftHip = { rot = Vector3.new(1.5, 0, 9.3), pos = Vector3.new(0, 0.766, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(6.62, 0, -2.04),
						pos = Vector3.new(-0.15, -0.708, 0.05),
					},
					Neck = { rot = Vector3.new(26.774, 6.452, 0) },
					RightShoulder = { rot = Vector3.new(-65.6, 0, -81.8) },
					LeftShoulder = { rot = Vector3.new(-84, 0, 86.9) },
					RightHip = { rot = Vector3.new(-5.3, 0, 13.4), pos = Vector3.new(0, 0.957, 0) },
					LeftHip = { rot = Vector3.new(7.4, 0, 10), pos = Vector3.new(0, 0.669, 0) },
				},
			},
			{
				time = 0.71,
				pose = {
					Root = { rot = Vector3.new(6.6, 0, -2), pos = Vector3.new(-0.15, -0.72, 0.05) },
					Neck = { rot = Vector3.new(26, 8, 0) },
					RightShoulder = { rot = Vector3.new(-246.9, 0, -135.1) },
					LeftShoulder = { rot = Vector3.new(94.6, 0, 130.1) },
					RightHip = { rot = Vector3.new(-7.3, 0, 14.8), pos = Vector3.new(0, 0.814, 0) },
					LeftHip = { rot = Vector3.new(8.8, 0, 11.3), pos = Vector3.new(0, 0.508, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(6.7, 0.01, -2.33),
						pos = Vector3.new(-0.15, -0.718, 0.05),
					},
					Neck = { rot = Vector3.new(26.117, 7.767, 0) },
					RightShoulder = { rot = Vector3.new(-66.6, 0, -81.8) },
					LeftShoulder = { rot = Vector3.new(94.6, 0, 130.1) },
					RightHip = { rot = Vector3.new(-7, 0, 14.9), pos = Vector3.new(0, 0.879, 0) },
					LeftHip = { rot = Vector3.new(8.6, 0, 11.4), pos = Vector3.new(0, 0.56, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(7.77, 0.04, -5.98),
						pos = Vector3.new(-0.15, -0.66, 0.05),
					},
					Neck = { rot = Vector3.new(30, 0, 0) },
					RightShoulder = { rot = Vector3.new(-60.8, 0, -81.7) },
					LeftShoulder = { rot = Vector3.new(277.3, 0, 87) },
					RightHip = { rot = Vector3.new(0.5, 0, 11.7), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(-1, 0, 9.4), pos = Vector3.new(0, 0.758, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(8.89, 0.01, -9.66),
						pos = Vector3.new(-0.15, -0.602, 0.05),
					},
					Neck = { rot = Vector3.new(33.883, -7.767, 0) },
					RightShoulder = { rot = Vector3.new(304.6, 0, -81.4) },
					LeftShoulder = { rot = Vector3.new(100.2, 0, 129.6) },
					RightHip = { rot = Vector3.new(6.2, 0, 10), pos = Vector3.new(0, 0.755, 0) },
					LeftHip = { rot = Vector3.new(-12.2, 0, 8.8), pos = Vector3.new(0, 0.482, 0) },
				},
			},
			{
				time = 0.85,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(9, 0, -10), pos = Vector3.new(-0.15, -0.6, 0.05) },
					Neck = { rot = Vector3.new(34, -8, 0) },
					RightShoulder = { rot = Vector3.new(-55.2, 0, -81.4) },
					LeftShoulder = { rot = Vector3.new(100.1, 0, 129.6) },
					RightHip = { rot = Vector3.new(6.1, 0, 10.5), pos = Vector3.new(0, 0.697, 0) },
					LeftHip = { rot = Vector3.new(-13, 0, 9.4), pos = Vector3.new(0, 0.412, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(9.09, -0.01, -10.02),
						pos = Vector3.new(-0.15, -0.612, 0.05),
					},
					Neck = { rot = Vector3.new(33.226, -6.452, 0) },
					RightShoulder = { rot = Vector3.new(-56.5, 0, -81.3) },
					LeftShoulder = { rot = Vector3.new(-81.5, 0, 87.1) },
					RightHip = { rot = Vector3.new(5.1, 0, 11), pos = Vector3.new(0, 0.882, 0) },
					LeftHip = { rot = Vector3.new(-10.6, 0, 9.8), pos = Vector3.new(0, 0.572, 0) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = {
						rot = Vector3.new(8.45, 0.02, -7.52),
						pos = Vector3.new(-0.15, -0.646, 0.05),
					},
					Neck = { rot = Vector3.new(30.916, -1.832, 0) },
					RightShoulder = { rot = Vector3.new(-59.6, 0, -81.4) },
					LeftShoulder = { rot = Vector3.new(97.2, 0, 129.9) },
					RightHip = { rot = Vector3.new(1.6, 0, 11.7), pos = Vector3.new(0, 1.041, 0) },
					LeftHip = { rot = Vector3.new(-4, 0, 9.8), pos = Vector3.new(0, 0.728, 0) },
				},
			},
			{
				time = 1.02,
				pose = {
					Root = {
						rot = Vector3.new(7.5, 0.02, -4.18),
						pos = Vector3.new(-0.15, -0.687, 0.05),
					},
					Neck = { rot = Vector3.new(28.212, 3.576, 0) },
					RightShoulder = { rot = Vector3.new(476.3, 0, -135.2) },
					LeftShoulder = { rot = Vector3.new(-264.1, 0, 130) },
					RightHip = { rot = Vector3.new(-2.9, 0, 13), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(3.3, 0, 10.2), pos = Vector3.new(0, 0.739, 0) },
				},
			},
			{
				time = 1.08,
				pose = {
					Root = {
						rot = Vector3.new(6.74, 0, -2.01),
						pos = Vector3.new(-0.15, -0.716, 0.05),
					},
					Neck = { rot = Vector3.new(26.295, 7.41, 0) },
					RightShoulder = { rot = Vector3.new(293.4, 0, -81.7) },
					LeftShoulder = { rot = Vector3.new(94.9, 0, 130.1) },
					RightHip = { rot = Vector3.new(-6.5, 0, 14.2), pos = Vector3.new(0, 0.908, 0) },
					LeftHip = { rot = Vector3.new(8.2, 0, 10.7), pos = Vector3.new(0, 0.605, 0) },
				},
			},
			{
				time = 1.11,
				pose = {
					Root = { rot = Vector3.new(6.6, 0, -2), pos = Vector3.new(-0.15, -0.72, 0.05) },
					Neck = { rot = Vector3.new(26, 8, 0) },
					RightShoulder = { rot = Vector3.new(-246.9, 0, -135.1) },
					LeftShoulder = { rot = Vector3.new(94.6, 0, 130.1) },
					RightHip = { rot = Vector3.new(-7.3, 0, 14.8), pos = Vector3.new(0, 0.814, 0) },
					LeftHip = { rot = Vector3.new(8.8, 0, 11.3), pos = Vector3.new(0, 0.508, 0) },
				},
			},
			{
				time = 1.14,
				pose = {
					Root = {
						rot = Vector3.new(6.69, 0.02, -2.94),
						pos = Vector3.new(-0.15, -0.706, 0.05),
					},
					Neck = { rot = Vector3.new(26.945, 6.111, 0) },
					RightShoulder = { rot = Vector3.new(114.7, 0, -135) },
					LeftShoulder = { rot = Vector3.new(95.4, 0, 130) },
					RightHip = { rot = Vector3.new(-4.7, 0, 14), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(7, 0, 10.8), pos = Vector3.new(0, 0.67, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(7.58, 0.07, -6.64),
						pos = Vector3.new(-0.15, -0.635, 0.05),
					},
					Neck = { rot = Vector3.new(31.668, -3.335, 0) },
					RightShoulder = { rot = Vector3.new(-58, 0, -81.9) },
					LeftShoulder = { rot = Vector3.new(100, 0, 129.7) },
					RightHip = { rot = Vector3.new(3.9, 0, 9.6), pos = Vector3.new(0, 0.978, 0) },
					LeftHip = { rot = Vector3.new(-4.7, 0, 7.8), pos = Vector3.new(0, 0.73, 0) },
				},
			},
			{
				time = 1.25,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(9, 0, -10), pos = Vector3.new(-0.15, -0.6, 0.05) },
					Neck = { rot = Vector3.new(34, -8, 0) },
					RightShoulder = { rot = Vector3.new(-55.2, 0, -81.4) },
					LeftShoulder = { rot = Vector3.new(100.1, 0, 129.6) },
					RightHip = { rot = Vector3.new(6.1, 0, 10.5), pos = Vector3.new(0, 0.697, 0) },
					LeftHip = { rot = Vector3.new(-13, 0, 9.4), pos = Vector3.new(0, 0.412, 0) },
				},
			},
			{
				time = 1.26,
				pose = {
					Root = {
						rot = Vector3.new(9.36, -0.03, -10.56),
						pos = Vector3.new(-0.15, -0.6, 0.05),
					},
					Neck = { rot = Vector3.new(34.001, -7.986, 0) },
					RightShoulder = { rot = Vector3.new(124.5, 0, -135.7) },
					LeftShoulder = { rot = Vector3.new(459.4, 0, 129.7) },
					RightHip = { rot = Vector3.new(5.7, 0, 11), pos = Vector3.new(0, 0.72, 0) },
					LeftHip = { rot = Vector3.new(-13.4, 0, 10), pos = Vector3.new(0, 0.413, 0) },
				},
			},
			{
				time = 1.32,
				pose = {
					Root = {
						rot = Vector3.new(11.83, -0.31, -12.81),
						pos = Vector3.new(-0.152, -0.608, 0.049),
					},
					Neck = { rot = Vector3.new(34.023, -7.384, 0) },
					RightShoulder = { rot = Vector3.new(121.8, 0, -136.5) },
					LeftShoulder = { rot = Vector3.new(94.1, 0, 129.6) },
					RightHip = { rot = Vector3.new(2.5, 0, 13.7), pos = Vector3.new(0, 0.853, 0) },
					LeftHip = { rot = Vector3.new(-15.8, 0, 13), pos = Vector3.new(0, 0.44, 0) },
				},
			},
			{
				time = 1.38,
				pose = {
					Root = {
						rot = Vector3.new(14.48, -0.64, -13.46),
						pos = Vector3.new(-0.156, -0.624, 0.046),
					},
					Neck = { rot = Vector3.new(34.013, -6.065, 0) },
					RightShoulder = { rot = Vector3.new(-50.3, 0, -82.6) },
					LeftShoulder = { rot = Vector3.new(88.7, 0, 129.2) },
					RightHip = { rot = Vector3.new(-1.5, 0, 15.3), pos = Vector3.new(0, 0.963, 0) },
					LeftHip = { rot = Vector3.new(-17.2, 0, 14.6), pos = Vector3.new(0, 0.49, 0) },
				},
			},
			{
				time = 1.44,
				pose = {
					Root = {
						rot = Vector3.new(16.73, -0.88, -12.85),
						pos = Vector3.new(-0.161, -0.644, 0.043),
					},
					Neck = { rot = Vector3.new(33.889, -4.267, 0) },
					RightShoulder = { rot = Vector3.new(-54.4, 0, -82.1) },
					LeftShoulder = { rot = Vector3.new(84.3, 0, 128.5) },
					RightHip = { rot = Vector3.new(-5.6, 0, 16.1), pos = Vector3.new(0, 1.036, 0) },
					LeftHip = { rot = Vector3.new(-17.4, 0, 15.3), pos = Vector3.new(0, 0.541, 0) },
				},
			},
			{
				time = 1.5,
				pose = {
					Root = {
						rot = Vector3.new(18.02, -0.92, -11.35),
						pos = Vector3.new(-0.164, -0.663, 0.041),
					},
					Neck = { rot = Vector3.new(33.567, -2.23, 0) },
					RightShoulder = { rot = Vector3.new(-57.7, 0, -81.8) },
					LeftShoulder = { rot = Vector3.new(82.1, 0, 127.9) },
					RightHip = { rot = Vector3.new(-9.1, 0, 16.4), pos = Vector3.new(0, 1.058, 0) },
					LeftHip = { rot = Vector3.new(-16.1, 0, 15.3), pos = Vector3.new(0, 0.572, 0) },
				},
			},
			{
				time = 1.56,
				pose = {
					Root = {
						rot = Vector3.new(17.76, -0.75, -9.32),
						pos = Vector3.new(-0.165, -0.677, 0.04),
					},
					Neck = { rot = Vector3.new(32.965, -0.195, 0) },
					RightShoulder = { rot = Vector3.new(108.9, 0, -128.8) },
					LeftShoulder = { rot = Vector3.new(82.8, 0, 127.5) },
					RightHip = { rot = Vector3.new(-11.1, 0, 16.2), pos = Vector3.new(0, 1.027, 0) },
					LeftHip = { rot = Vector3.new(-13.4, 0, 14.6), pos = Vector3.new(0, 0.576, 0) },
				},
			},
			{
				time = 1.62,
				pose = {
					Root = {
						rot = Vector3.new(15.35, -0.44, -7.1),
						pos = Vector3.new(-0.162, -0.68, 0.042),
					},
					Neck = { rot = Vector3.new(31.998, 1.598, 0) },
					RightShoulder = { rot = Vector3.new(482.4, 0, -134) },
					LeftShoulder = { rot = Vector3.new(447.2, 0, 127.9) },
					RightHip = { rot = Vector3.new(-10.7, 0, 15.5), pos = Vector3.new(0, 0.945, 0) },
					LeftHip = { rot = Vector3.new(-8.7, 0, 13.4), pos = Vector3.new(0, 0.552, 0) },
				},
			},
			{
				time = 1.68,
				pose = {
					Root = {
						rot = Vector3.new(10.22, -0.1, -5.01),
						pos = Vector3.new(-0.154, -0.668, 0.047),
					},
					Neck = { rot = Vector3.new(30.585, 2.911, 0) },
					RightShoulder = { rot = Vector3.new(-52.9, 0, -84.6) },
					LeftShoulder = { rot = Vector3.new(92.3, 0, 144.3) },
					RightHip = { rot = Vector3.new(-6.4, 0, 14), pos = Vector3.new(0, 0.827, 0) },
					LeftHip = { rot = Vector3.new(-1.6, 0, 11.5), pos = Vector3.new(0, 0.506, 0) },
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
					RightShoulder = { rot = Vector3.new(-61.6, 0, -81.5) },
					LeftShoulder = { rot = Vector3.new(98.2, 0, 129.9) },
					RightHip = { rot = Vector3.new(-3.9, 0, 13.4), pos = Vector3.new(0, 0.782, 0) },
					LeftHip = { rot = Vector3.new(1.5, 0, 10.7), pos = Vector3.new(0, 0.486, 0) },
				},
			},
			{
				time = 1.74,
				pose = {
					Root = {
						rot = Vector3.new(1.88, 0.17, -3.33),
						pos = Vector3.new(-0.128, -0.611, 0.064),
					},
					Neck = { rot = Vector3.new(27.548, 3.182, 0) },
					RightShoulder = { rot = Vector3.new(114.7, 0, -131.3) },
					LeftShoulder = { rot = Vector3.new(73.5, 0, 129) },
					RightHip = { rot = Vector3.new(2.9, 0, 11.4), pos = Vector3.new(0, 0.712, 0) },
					LeftHip = { rot = Vector3.new(7.4, 0, 8.3), pos = Vector3.new(0, 0.605, 0) },
				},
			},
			{
				time = 1.8,
				pose = {
					Root = {
						rot = Vector3.new(-8.89, 0.29, -2.01),
						pos = Vector3.new(-0.069, -0.468, 0.104),
					},
					Neck = { rot = Vector3.new(21.231, 1.908, 0) },
					RightShoulder = { rot = Vector3.new(106.8, 0, -83.4) },
					LeftShoulder = { rot = Vector3.new(108.2, 0, 76.2) },
					RightHip = { rot = Vector3.new(16.4, 0, 7.3), pos = Vector3.new(0, 0.517, 0) },
					LeftHip = { rot = Vector3.new(13.9, 0, 4.1), pos = Vector3.new(0, 0.62, 0) },
				},
			},
			{
				time = 1.86,
				pose = {
					Root = {
						rot = Vector3.new(-20.53, 0.21, -0.82),
						pos = Vector3.new(-0.014, -0.334, 0.141),
					},
					Neck = { rot = Vector3.new(15.467, 0.412, 0) },
					RightShoulder = { rot = Vector3.new(116.2, 0, -44) },
					LeftShoulder = { rot = Vector3.new(117.6, 0, 40.6) },
					RightHip = { rot = Vector3.new(33.6, 0, 3.2), pos = Vector3.new(0, 0.269, 0) },
					LeftHip = { rot = Vector3.new(23.7, 0, 0.3), pos = Vector3.new(0, 0.412, 0) },
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
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-7.37, 26.41, 13.29),
						pos = Vector3.new(0.9, -0.159, -0.459),
					},
					Neck = { rot = Vector3.new(15.1, -20, -14) },
					RightShoulder = { rot = Vector3.new(39.2, 0, -82.1) },
					LeftShoulder = { rot = Vector3.new(83.8, 0, 60.8) },
					RightHip = { rot = Vector3.new(-13.8, 0, -33.4) },
					LeftHip = { rot = Vector3.new(27.8, 0, -35), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-6.9, 26.03, 13.02),
						pos = Vector3.new(0.9, -0.157, -0.457),
					},
					Neck = { rot = Vector3.new(14.896, -20, -14) },
					RightShoulder = { rot = Vector3.new(40.7, 0, -82.7) },
					LeftShoulder = { rot = Vector3.new(83.5, 0, 60.4) },
					RightHip = { rot = Vector3.new(-14.4, 0, -33.2) },
					LeftHip = { rot = Vector3.new(26.9, 0, -35.1), pos = Vector3.new(0, 0.214, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-6.52, 25.73, 12.81),
						pos = Vector3.new(0.9, -0.156, -0.456),
					},
					Neck = { rot = Vector3.new(14.732, -20, -14) },
					RightShoulder = { rot = Vector3.new(42.1, 0, -83.3) },
					LeftShoulder = { rot = Vector3.new(83.2, 0, 60.1) },
					RightHip = { rot = Vector3.new(-15, 0, -33) },
					LeftHip = { rot = Vector3.new(26.2, 0, -35.2), pos = Vector3.new(0, 0.217, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-6.57, 25.77, 12.83),
						pos = Vector3.new(0.9, -0.156, -0.456),
					},
					Neck = { rot = Vector3.new(14.752, -20, -14) },
					RightShoulder = { rot = Vector3.new(42.8, 0, -83.6) },
					LeftShoulder = { rot = Vector3.new(83.2, 0, 60.1) },
					RightHip = { rot = Vector3.new(-14.9, 0, -33.1) },
					LeftHip = { rot = Vector3.new(26.3, 0, -35.2), pos = Vector3.new(0, 0.217, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-7.37, 26.41, 13.29),
						pos = Vector3.new(0.9, -0.159, -0.459),
					},
					Neck = { rot = Vector3.new(15.1, -20, -14) },
					RightShoulder = { rot = Vector3.new(42.1, 0, -83.4) },
					LeftShoulder = { rot = Vector3.new(83.8, 0, 60.8) },
					RightHip = { rot = Vector3.new(-13.8, 0, -33.4) },
					LeftHip = { rot = Vector3.new(27.8, 0, -35), pos = Vector3.new(0, 0.211, 0) },
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
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-9.15, 27.78, 14.32),
						pos = Vector3.new(0.9, -0.173, -0.473),
					},
					Neck = { rot = Vector3.new(16.82, -20, -14) },
					RightShoulder = { rot = Vector3.new(99.7, 0, -70.1) },
					LeftShoulder = { rot = Vector3.new(86.3, 0, 62.7) },
					RightHip = { rot = Vector3.new(-11.5, 0, -34.1) },
					LeftHip = { rot = Vector3.new(30.7, 0, -34.6), pos = Vector3.new(0, 0.207, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-11.01, 29.14, 15.42),
						pos = Vector3.new(0.9, -0.196, -0.496),
					},
					Neck = { rot = Vector3.new(19.487, -20, -14) },
					RightShoulder = { rot = Vector3.new(104.9, 0, -62.6) },
					LeftShoulder = { rot = Vector3.new(90.2, 0, 65) },
					RightHip = { rot = Vector3.new(-9.5, 0, -35) },
					LeftHip = { rot = Vector3.new(33.4, 0, -34.1), pos = Vector3.new(0, 0.212, 0) },
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
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-11.52, 29.51, 15.73),
						pos = Vector3.new(0.9, -0.199, -0.499),
					},
					Neck = { rot = Vector3.new(19.823, -20, -14) },
					RightShoulder = { rot = Vector3.new(105.4, 0, -55) },
					LeftShoulder = { rot = Vector3.new(90.9, 0, 65.5) },
					RightHip = { rot = Vector3.new(-8.9, 0, -35.2) },
					LeftHip = { rot = Vector3.new(34.3, 0, -34), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-10.45, 28.75, 15.09),
						pos = Vector3.new(0.9, -0.189, -0.489),
					},
					Neck = { rot = Vector3.new(18.673, -20, -14) },
					RightShoulder = { rot = Vector3.new(103.3, 0, -62.7) },
					LeftShoulder = { rot = Vector3.new(89, 0, 64.3) },
					RightHip = { rot = Vector3.new(-10.1, 0, -34.8) },
					LeftHip = { rot = Vector3.new(32.7, 0, -34.3), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-8.81, 27.53, 14.12),
						pos = Vector3.new(0.9, -0.175, -0.475),
					},
					Neck = { rot = Vector3.new(17.051, -20, -14) },
					RightShoulder = { rot = Vector3.new(100.1, 0, -70.2) },
					LeftShoulder = { rot = Vector3.new(86.4, 0, 62.6) },
					RightHip = { rot = Vector3.new(-12.1, 0, -34.1) },
					LeftHip = { rot = Vector3.new(30, 0, -34.7), pos = Vector3.new(0, 0.214, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-7.61, 26.59, 13.42),
						pos = Vector3.new(0.9, -0.164, -0.464),
					},
					Neck = { rot = Vector3.new(15.664, -20, -14) },
					RightShoulder = { rot = Vector3.new(42.1, 0, -83.8) },
					LeftShoulder = { rot = Vector3.new(84.4, 0, 61.1) },
					RightHip = { rot = Vector3.new(-13.6, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.1, 0, -35), pos = Vector3.new(0, 0.215, 0) },
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
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-7.77, 26.72, 13.52),
						pos = Vector3.new(0.9, -0.161, -0.461),
					},
					Neck = { rot = Vector3.new(15.27, -20, -14) },
					RightShoulder = { rot = Vector3.new(41.5, 0, -83.3) },
					LeftShoulder = { rot = Vector3.new(84.2, 0, 61.1) },
					RightHip = { rot = Vector3.new(-13.2, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.5, 0, -34.9), pos = Vector3.new(0, 0.209, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(-9.55, 28.08, 14.55),
						pos = Vector3.new(0.9, -0.18, -0.48),
					},
					Neck = { rot = Vector3.new(17.6, -20, -14) },
					RightShoulder = { rot = Vector3.new(101.3, 0, -70.1) },
					LeftShoulder = { rot = Vector3.new(87.4, 0, 63.3) },
					RightHip = { rot = Vector3.new(-11.2, 0, -34.4) },
					LeftHip = { rot = Vector3.new(31.3, 0, -34.5), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(-11.35, 29.38, 15.63),
						pos = Vector3.new(0.9, -0.199, -0.499),
					},
					Neck = { rot = Vector3.new(19.93, -20, -14) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -62.5) },
					LeftShoulder = { rot = Vector3.new(90.9, 0, 65.4) },
					RightHip = { rot = Vector3.new(-9.1, 0, -35.1) },
					LeftHip = { rot = Vector3.new(34, 0, -34), pos = Vector3.new(0, 0.212, 0) },
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
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(-11.45, 29.45, 15.69),
						pos = Vector3.new(0.9, -0.196, -0.496),
					},
					Neck = { rot = Vector3.new(19.536, -20, -14) },
					RightShoulder = { rot = Vector3.new(104.6, 0, -55.4) },
					LeftShoulder = { rot = Vector3.new(90.5, 0, 65.4) },
					RightHip = { rot = Vector3.new(-8.9, 0, -35.1) },
					LeftHip = { rot = Vector3.new(34.3, 0, -34), pos = Vector3.new(0, 0.206, 0) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = {
						rot = Vector3.new(-10.11, 28.49, 14.88),
						pos = Vector3.new(0.9, -0.185, -0.485),
					},
					Neck = { rot = Vector3.new(18.149, -20, -14) },
					RightShoulder = { rot = Vector3.new(100.5, 0, -64.3) },
					LeftShoulder = { rot = Vector3.new(88.3, 0, 63.9) },
					RightHip = { rot = Vector3.new(-10.5, 0, -34.6) },
					LeftHip = { rot = Vector3.new(32.1, 0, -34.3), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 1.02,
				pose = {
					Root = {
						rot = Vector3.new(-8.45, 27.25, 13.9),
						pos = Vector3.new(0.9, -0.171, -0.471),
					},
					Neck = { rot = Vector3.new(16.527, -20, -14) },
					RightShoulder = { rot = Vector3.new(196.1, 0, -155.5) },
					LeftShoulder = { rot = Vector3.new(85.7, 0, 62.1) },
					RightHip = { rot = Vector3.new(-12.6, 0, -33.9) },
					LeftHip = { rot = Vector3.new(29.5, 0, -34.8), pos = Vector3.new(0, 0.214, 0) },
				},
			},
			{
				time = 1.08,
				pose = {
					Root = {
						rot = Vector3.new(-7.5, 26.51, 13.36),
						pos = Vector3.new(0.9, -0.161, -0.461),
					},
					Neck = { rot = Vector3.new(15.377, -20, -14) },
					RightShoulder = { rot = Vector3.new(23.9, 0, -57.8) },
					LeftShoulder = { rot = Vector3.new(84.1, 0, 60.9) },
					RightHip = { rot = Vector3.new(-13.7, 0, -33.4) },
					LeftHip = { rot = Vector3.new(27.9, 0, -35), pos = Vector3.new(0, 0.212, 0) },
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
				time = 1.14,
				pose = {
					Root = {
						rot = Vector3.new(-8.21, 27.07, 13.77),
						pos = Vector3.new(0.9, -0.165, -0.465),
					},
					Neck = { rot = Vector3.new(15.767, -20, -14) },
					RightShoulder = { rot = Vector3.new(23.6, 0, -57.8) },
					LeftShoulder = { rot = Vector3.new(84.9, 0, 61.6) },
					RightHip = { rot = Vector3.new(-12.7, 0, -33.7) },
					LeftHip = { rot = Vector3.new(29.2, 0, -34.8), pos = Vector3.new(0, 0.208, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-10.19, 28.56, 14.93),
						pos = Vector3.new(0.9, -0.188, -0.488),
					},
					Neck = { rot = Vector3.new(18.601, -20, -14) },
					RightShoulder = { rot = Vector3.new(277.5, 0, -141.6) },
					LeftShoulder = { rot = Vector3.new(88.8, 0, 64.1) },
					RightHip = { rot = Vector3.new(-10.5, 0, -34.7) },
					LeftHip = { rot = Vector3.new(35.9, 0, -36.2) },
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
				time = 1.26,
				pose = {
					Root = {
						rot = Vector3.new(-11.62, 29.58, 15.8),
						pos = Vector3.new(0.9, -0.2, -0.5),
					},
					Neck = { rot = Vector3.new(19.979, -20, -14) },
					RightShoulder = { rot = Vector3.new(15.5, 0, -62.2) },
					LeftShoulder = { rot = Vector3.new(91.1, 0, 65.7) },
					RightHip = { rot = Vector3.new(-8.8, 0, -35.2) },
					LeftHip = { rot = Vector3.new(38.3, 0, -35.7) },
				},
			},
			{
				time = 1.32,
				pose = {
					Root = {
						rot = Vector3.new(-11.26, 29.32, 15.57),
						pos = Vector3.new(0.9, -0.193, -0.493),
					},
					Neck = { rot = Vector3.new(19.144, -20, -14) },
					RightShoulder = { rot = Vector3.new(195.2, 0, -155.8) },
					LeftShoulder = { rot = Vector3.new(90, 0, 65.1) },
					RightHip = { rot = Vector3.new(-9, 0, -35) },
					LeftHip = { rot = Vector3.new(34, 0, -34), pos = Vector3.new(0, 0.204, 0) },
				},
			},
			{
				time = 1.38,
				pose = {
					Root = {
						rot = Vector3.new(-9.8, 28.27, 14.7),
						pos = Vector3.new(0.9, -0.18, -0.48),
					},
					Neck = { rot = Vector3.new(17.6, -20, -14) },
					RightShoulder = { rot = Vector3.new(22.4, 0, -56.9) },
					LeftShoulder = { rot = Vector3.new(87.5, 0, 63.5) },
					RightHip = { rot = Vector3.new(-10.8, 0, -34.4) },
					LeftHip = { rot = Vector3.new(31.7, 0, -34.4), pos = Vector3.new(0, 0.207, 0) },
				},
			},
			{
				time = 1.44,
				pose = {
					Root = {
						rot = Vector3.new(-8.27, 27.11, 13.8),
						pos = Vector3.new(0.9, -0.167, -0.467),
					},
					Neck = { rot = Vector3.new(16.056, -20, -14) },
					RightShoulder = { rot = Vector3.new(36.2, 0, -48.7) },
					LeftShoulder = { rot = Vector3.new(85.2, 0, 61.8) },
					RightHip = { rot = Vector3.new(-12.7, 0, -33.8) },
					LeftHip = { rot = Vector3.new(29.2, 0, -34.8), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 1.5,
				pose = {
					Root = {
						rot = Vector3.new(-7.58, 26.57, 13.41),
						pos = Vector3.new(0.9, -0.16, -0.46),
					},
					Neck = { rot = Vector3.new(15.221, -20, -14) },
					RightShoulder = { rot = Vector3.new(17.6, 0, -90.3) },
					LeftShoulder = { rot = Vector3.new(84, 0, 60.9) },
					RightHip = { rot = Vector3.new(-13.5, 0, -33.5) },
					LeftHip = { rot = Vector3.new(28.1, 0, -34.9), pos = Vector3.new(0, 0.21, 0) },
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
				time = 1.56,
				pose = {
					Root = {
						rot = Vector3.new(-8.46, 27.26, 13.91),
						pos = Vector3.new(0.9, -0.172, -0.472),
					},
					Neck = { rot = Vector3.new(16.599, -20, -14) },
					RightShoulder = { rot = Vector3.new(35.5, 0, -49.6) },
					LeftShoulder = { rot = Vector3.new(85.8, 0, 62.1) },
					RightHip = { rot = Vector3.new(-12.6, 0, -33.9) },
					LeftHip = { rot = Vector3.new(29.4, 0, -34.8), pos = Vector3.new(0, 0.215, 0) },
				},
			},
			{
				time = 1.62,
				pose = {
					Root = {
						rot = Vector3.new(-10.43, 28.73, 15.07),
						pos = Vector3.new(0.9, -0.195, -0.495),
					},
					Neck = { rot = Vector3.new(19.433, -20, -14) },
					RightShoulder = { rot = Vector3.new(20.8, 0, -58.5) },
					LeftShoulder = { rot = Vector3.new(89.8, 0, 64.6) },
					RightHip = { rot = Vector3.new(-10.4, 0, -34.8) },
					LeftHip = { rot = Vector3.new(32.4, 0, -34.3), pos = Vector3.new(0, 0.22, 0) },
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
				time = 1.68,
				pose = {
					Root = {
						rot = Vector3.new(-12.49, 30.18, 16.33),
						pos = Vector3.new(0.9, -0.2, -0.5),
					},
					Neck = { rot = Vector3.new(19.995, -20, -14) },
					RightShoulder = { rot = Vector3.new(21.5, 0, -58.6) },
					LeftShoulder = { rot = Vector3.new(91.7, 0, 66.3) },
					RightHip = { rot = Vector3.new(-7.4, 0, -35.4) },
					LeftHip = { rot = Vector3.new(39.7, 0, -35.2) },
				},
			},
			{
				time = 1.74,
				pose = {
					Root = {
						rot = Vector3.new(-14.09, 31.25, 17.33),
						pos = Vector3.new(0.9, -0.2, -0.5),
					},
					Neck = { rot = Vector3.new(19.955, -20, -14) },
					RightShoulder = { rot = Vector3.new(88.9, 0, -87.9) },
					LeftShoulder = { rot = Vector3.new(92.6, 0, 67.3) },
					RightHip = { rot = Vector3.new(-5, 0, -35.7) },
					LeftHip = { rot = Vector3.new(39, 0, -33), pos = Vector3.new(0, 0.167, 0) },
				},
			},
			{
				time = 1.8,
				pose = {
					Root = {
						rot = Vector3.new(-15.24, 31.99, 18.05),
						pos = Vector3.new(0.9, -0.199, -0.499),
					},
					Neck = { rot = Vector3.new(19.88, -20, -14) },
					RightShoulder = { rot = Vector3.new(88.8, 0, -87.9) },
					LeftShoulder = { rot = Vector3.new(93.3, 0, 68.1) },
					RightHip = { rot = Vector3.new(-3.2, 0, -35.9) },
					LeftHip = { rot = Vector3.new(44, 0, -33.4) },
				},
			},
			{
				time = 1.86,
				pose = {
					Root = {
						rot = Vector3.new(-15.95, 32.43, 18.51),
						pos = Vector3.new(0.9, -0.198, -0.498),
					},
					Neck = { rot = Vector3.new(19.775, -20, -14) },
					RightShoulder = { rot = Vector3.new(88.7, 0, -88) },
					LeftShoulder = { rot = Vector3.new(93.5, 0, 68.5) },
					RightHip = { rot = Vector3.new(-2.2, 0, -36) },
					LeftHip = { rot = Vector3.new(45, 0, -33) },
				},
			},
			{
				time = 1.92,
				pose = {
					Root = {
						rot = Vector3.new(-16.27, 32.63, 18.72),
						pos = Vector3.new(0.9, -0.197, -0.497),
					},
					Neck = { rot = Vector3.new(19.646, -20, -14) },
					RightShoulder = { rot = Vector3.new(268.4, 0, -128.9) },
					LeftShoulder = { rot = Vector3.new(93.6, 0, 68.7) },
					RightHip = { rot = Vector3.new(-1.6, 0, -36) },
					LeftHip = { rot = Vector3.new(43, 0, -32), pos = Vector3.new(0, 0.118, 0) },
				},
			},
			{
				time = 1.98,
				pose = {
					Root = {
						rot = Vector3.new(-16.26, 32.62, 18.7),
						pos = Vector3.new(0.9, -0.196, -0.496),
					},
					Neck = { rot = Vector3.new(19.499, -20, -14) },
					RightShoulder = { rot = Vector3.new(88.1, 0, -87.9) },
					LeftShoulder = { rot = Vector3.new(93.5, 0, 68.6) },
					RightHip = { rot = Vector3.new(-1.6, 0, -36) },
					LeftHip = { rot = Vector3.new(43, 0, -32), pos = Vector3.new(0, 0.117, 0) },
				},
			},
			{
				time = 2.04,
				pose = {
					Root = {
						rot = Vector3.new(-15.96, 32.44, 18.51),
						pos = Vector3.new(0.9, -0.194, -0.494),
					},
					Neck = { rot = Vector3.new(19.339, -20, -14) },
					RightShoulder = { rot = Vector3.new(87.5, 0, -87.8) },
					LeftShoulder = { rot = Vector3.new(93, 0, 68.3) },
					RightHip = { rot = Vector3.new(-2, 0, -35.9) },
					LeftHip = { rot = Vector3.new(42.6, 0, -32.1), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 2.1,
				pose = {
					Root = {
						rot = Vector3.new(-15.44, 32.11, 18.17),
						pos = Vector3.new(0.9, -0.193, -0.493),
					},
					Neck = { rot = Vector3.new(19.171, -20, -14) },
					RightShoulder = { rot = Vector3.new(267, 0, -129.2) },
					LeftShoulder = { rot = Vector3.new(92.6, 0, 67.9) },
					RightHip = { rot = Vector3.new(-2.7, 0, -35.8) },
					LeftHip = { rot = Vector3.new(44.3, 0, -33.2) },
				},
			},
			{
				time = 2.16,
				pose = {
					Root = {
						rot = Vector3.new(-14.75, 31.68, 17.73),
						pos = Vector3.new(0.9, -0.192, -0.492),
					},
					Neck = { rot = Vector3.new(19.001, -20, -14) },
					RightShoulder = { rot = Vector3.new(22.3, 0, -57.4) },
					LeftShoulder = { rot = Vector3.new(92, 0, 67.4) },
					RightHip = { rot = Vector3.new(-3.7, 0, -35.7) },
					LeftHip = { rot = Vector3.new(40.4, 0, -32.6), pos = Vector3.new(0, 0.141, 0) },
				},
			},
			{
				time = 2.22,
				pose = {
					Root = {
						rot = Vector3.new(-13.96, 31.17, 17.23),
						pos = Vector3.new(0.9, -0.19, -0.49),
					},
					Neck = { rot = Vector3.new(18.834, -20, -14) },
					RightShoulder = { rot = Vector3.new(22.1, 0, -57.4) },
					LeftShoulder = { rot = Vector3.new(91.3, 0, 66.9) },
					RightHip = { rot = Vector3.new(-4.8, 0, -35.5) },
					LeftHip = { rot = Vector3.new(39.1, 0, -32.9), pos = Vector3.new(0, 0.153, 0) },
				},
			},
			{
				time = 2.28,
				pose = {
					Root = {
						rot = Vector3.new(-13.12, 30.61, 16.71),
						pos = Vector3.new(0.9, -0.189, -0.489),
					},
					Neck = { rot = Vector3.new(18.675, -20, -14) },
					RightShoulder = { rot = Vector3.new(21.8, 0, -57.5) },
					LeftShoulder = { rot = Vector3.new(90.6, 0, 66.2) },
					RightHip = { rot = Vector3.new(-6.1, 0, -35.4) },
					LeftHip = { rot = Vector3.new(37.6, 0, -33.2), pos = Vector3.new(0, 0.167, 0) },
				},
			},
			{
				time = 2.34,
				pose = {
					Root = {
						rot = Vector3.new(-12.29, 30.05, 16.19),
						pos = Vector3.new(0.9, -0.188, -0.488),
					},
					Neck = { rot = Vector3.new(18.531, -20, -14) },
					RightShoulder = { rot = Vector3.new(21.6, 0, -57.6) },
					LeftShoulder = { rot = Vector3.new(90, 0, 65.6) },
					RightHip = { rot = Vector3.new(-7.3, 0, -35.2) },
					LeftHip = { rot = Vector3.new(36.1, 0, -33.5), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 2.4,
				pose = {
					Root = {
						rot = Vector3.new(-11.52, 29.51, 15.72),
						pos = Vector3.new(0.9, -0.187, -0.487),
					},
					Neck = { rot = Vector3.new(18.406, -20, -14) },
					RightShoulder = { rot = Vector3.new(21.3, 0, -57.7) },
					LeftShoulder = { rot = Vector3.new(89.4, 0, 65) },
					RightHip = { rot = Vector3.new(-8.4, 0, -35) },
					LeftHip = { rot = Vector3.new(34.7, 0, -33.8), pos = Vector3.new(0, 0.191, 0) },
				},
			},
			{
				time = 2.46,
				pose = {
					Root = {
						rot = Vector3.new(-10.86, 29.04, 15.32),
						pos = Vector3.new(0.9, -0.186, -0.486),
					},
					Neck = { rot = Vector3.new(18.306, -20, -14) },
					RightShoulder = { rot = Vector3.new(21.1, 0, -57.8) },
					LeftShoulder = { rot = Vector3.new(88.9, 0, 64.5) },
					RightHip = { rot = Vector3.new(-9.4, 0, -34.8) },
					LeftHip = { rot = Vector3.new(33.5, 0, -34.1), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 2.52,
				pose = {
					Root = {
						rot = Vector3.new(-10.36, 28.68, 15.01),
						pos = Vector3.new(0.9, -0.185, -0.485),
					},
					Neck = { rot = Vector3.new(18.236, -20, -14) },
					RightShoulder = { rot = Vector3.new(21, 0, -57.8) },
					LeftShoulder = { rot = Vector3.new(88.5, 0, 64.1) },
					RightHip = { rot = Vector3.new(-10.1, 0, -34.6) },
					LeftHip = { rot = Vector3.new(32.6, 0, -34.2), pos = Vector3.new(0, 0.206, 0) },
				},
			},
			{
				time = 2.58,
				pose = {
					Root = {
						rot = Vector3.new(-10.06, 28.46, 14.84),
						pos = Vector3.new(0.9, -0.185, -0.485),
					},
					Neck = { rot = Vector3.new(18.202, -20, -14) },
					RightShoulder = { rot = Vector3.new(20.9, 0, -57.8) },
					LeftShoulder = { rot = Vector3.new(88.3, 0, 63.9) },
					RightHip = { rot = Vector3.new(-10.6, 0, -34.6) },
					LeftHip = { rot = Vector3.new(35.7, 0, -36.2) },
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
					RightShoulder = { rot = Vector3.new(114.7, 0, -135.1) },
					LeftShoulder = { rot = Vector3.new(91.8, 0, 130.5) },
					RightHip = { rot = Vector3.new(1, 0, 12.3), pos = Vector3.new(0, 0.847, 0) },
					LeftHip = { rot = Vector3.new(-0.4, 0, 10.1), pos = Vector3.new(0, 0.559, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(6.45, -0.01, -4.65),
						pos = Vector3.new(-0.15, -0.722, 0.05),
					},
					Neck = { rot = Vector3.new(25.834, 0.95, 0) },
					RightShoulder = { rot = Vector3.new(-65.9, 0, -81.8) },
					LeftShoulder = { rot = Vector3.new(92.6, 0, 130.4) },
					RightHip = { rot = Vector3.new(0.6, 0, 11.3), pos = Vector3.new(0, 0.909, 0) },
					LeftHip = { rot = Vector3.new(0.9, 0, 8.8), pos = Vector3.new(0, 0.652, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(6.15, -0.03, -2.71),
						pos = Vector3.new(-0.15, -0.728, 0.05),
					},
					Neck = { rot = Vector3.new(25.494, 3.174, 0) },
					RightShoulder = { rot = Vector3.new(-67, 0, -82) },
					LeftShoulder = { rot = Vector3.new(93.6, 0, 130.2) },
					RightHip = { rot = Vector3.new(-0.8, 0, 10.8), pos = Vector3.new(0, 0.945, 0) },
					LeftHip = { rot = Vector3.new(3.5, 0, 7.9), pos = Vector3.new(0, 0.717, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(5.91, -0.05, -1),
						pos = Vector3.new(-0.15, -0.732, 0.05),
					},
					Neck = { rot = Vector3.new(25.221, 5.739, 0) },
					RightShoulder = { rot = Vector3.new(122.6, 0, -130.1) },
					LeftShoulder = { rot = Vector3.new(94.6, 0, 130) },
					RightHip = { rot = Vector3.new(-2.9, 0, 11), pos = Vector3.new(0, 0.935, 0) },
					LeftHip = { rot = Vector3.new(6.4, 0, 7.7), pos = Vector3.new(0, 0.72, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(5.94, -0.06, -0.34),
						pos = Vector3.new(-0.15, -0.731, 0.05),
					},
					Neck = { rot = Vector3.new(25.254, 7.706, 0) },
					RightShoulder = { rot = Vector3.new(122.1, 0, -130.1) },
					LeftShoulder = { rot = Vector3.new(-87.8, 0, 71.9) },
					RightHip = { rot = Vector3.new(-5.2, 0, 12.1), pos = Vector3.new(0, 0.885, 0) },
					LeftHip = { rot = Vector3.new(8.5, 0, 8.4), pos = Vector3.new(0, 0.655, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(6.45, -0.01, -1.56),
						pos = Vector3.new(-0.15, -0.722, 0.05),
					},
					Neck = { rot = Vector3.new(25.834, 8.142, 0) },
					RightShoulder = { rot = Vector3.new(112.9, 0, -135.1) },
					LeftShoulder = { rot = Vector3.new(274.8, 0, 86.8) },
					RightHip = { rot = Vector3.new(-7.1, 0, 14.3), pos = Vector3.new(0, 0.823, 0) },
					LeftHip = { rot = Vector3.new(8.9, 0, 10.7), pos = Vector3.new(0, 0.533, 0) },
				},
			},
			{
				time = 0.31,
				pose = {
					Root = { rot = Vector3.new(6.6, 0, -2), pos = Vector3.new(-0.15, -0.72, 0.05) },
					Neck = { rot = Vector3.new(26, 8, 0) },
					RightShoulder = { rot = Vector3.new(-246.9, 0, -135.1) },
					LeftShoulder = { rot = Vector3.new(-265.4, 0, 130.1) },
					RightHip = { rot = Vector3.new(-7.3, 0, 14.8), pos = Vector3.new(0, 0.814, 0) },
					LeftHip = { rot = Vector3.new(8.8, 0, 11.3), pos = Vector3.new(0, 0.508, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(7.56, 0.04, -5.11),
						pos = Vector3.new(-0.15, -0.68, 0.05),
					},
					Neck = { rot = Vector3.new(28.7, 2.968, 0) },
					RightShoulder = { rot = Vector3.new(297.2, 0, -81.6) },
					LeftShoulder = { rot = Vector3.new(95.8, 0, 130) },
					RightHip = { rot = Vector3.new(-2.8, 0, 13.7), pos = Vector3.new(0, 1.06, 0) },
					LeftHip = { rot = Vector3.new(3, 0, 11), pos = Vector3.new(0, 0.721, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(8.69, 0.02, -8.94),
						pos = Vector3.new(-0.15, -0.613, 0.05),
					},
					Neck = { rot = Vector3.new(33.145, -6.201, 0) },
					RightShoulder = { rot = Vector3.new(-56.3, 0, -81.4) },
					LeftShoulder = { rot = Vector3.new(99.8, 0, 129.7) },
					RightHip = { rot = Vector3.new(5.2, 0, 10), pos = Vector3.new(0, 0.884, 0) },
					LeftHip = { rot = Vector3.new(-9.6, 0, 8.7), pos = Vector3.new(0, 0.609, 0) },
				},
			},
			{
				time = 0.45,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(9, 0, -10), pos = Vector3.new(-0.15, -0.6, 0.05) },
					Neck = { rot = Vector3.new(34, -8, 0) },
					RightShoulder = { rot = Vector3.new(-55.2, 0, -81.4) },
					LeftShoulder = { rot = Vector3.new(100.1, 0, 129.6) },
					RightHip = { rot = Vector3.new(6.1, 0, 10.5), pos = Vector3.new(0, 0.697, 0) },
					LeftHip = { rot = Vector3.new(-13, 0, 9.4), pos = Vector3.new(0, 0.412, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(9.03, 0, -10.09),
						pos = Vector3.new(-0.15, -0.604, 0.05),
					},
					Neck = { rot = Vector3.new(33.705, -7.41, 0) },
					RightShoulder = { rot = Vector3.new(-55.6, 0, -81.3) },
					LeftShoulder = { rot = Vector3.new(99.6, 0, 129.7) },
					RightHip = { rot = Vector3.new(5.9, 0, 10.6), pos = Vector3.new(0, 0.804, 0) },
					LeftHip = { rot = Vector3.new(-11.9, 0, 9.5), pos = Vector3.new(0, 0.509, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(8.44, 0.03, -8.04),
						pos = Vector3.new(-0.15, -0.633, 0.05),
					},
					Neck = { rot = Vector3.new(31.788, -3.576, 0) },
					RightShoulder = { rot = Vector3.new(121.8, 0, -135.3) },
					LeftShoulder = { rot = Vector3.new(278.3, 0, 87.1) },
					RightHip = { rot = Vector3.new(3.3, 0, 10.9), pos = Vector3.new(0, 0.993, 0) },
					LeftHip = { rot = Vector3.new(-6.1, 0, 9.2), pos = Vector3.new(0, 0.699, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(7.47, 0.03, -4.71),
						pos = Vector3.new(-0.15, -0.674, 0.05),
					},
					Neck = { rot = Vector3.new(29.084, 1.832, 0) },
					RightShoulder = { rot = Vector3.new(117.8, 0, -135) },
					LeftShoulder = { rot = Vector3.new(277, 0, 87) },
					RightHip = { rot = Vector3.new(-1.1, 0, 11.9), pos = Vector3.new(0, 1.056, 0) },
					LeftHip = { rot = Vector3.new(1.4, 0, 9.4), pos = Vector3.new(0, 0.764, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(6.69, 0, -2.12),
						pos = Vector3.new(-0.15, -0.708, 0.05),
					},
					Neck = { rot = Vector3.new(26.774, 6.452, 0) },
					RightShoulder = { rot = Vector3.new(114.4, 0, -135) },
					LeftShoulder = { rot = Vector3.new(455.9, 0, 129.9) },
					RightHip = { rot = Vector3.new(-5.3, 0, 13.5), pos = Vector3.new(0, 0.958, 0) },
					LeftHip = { rot = Vector3.new(7.3, 0, 10.1), pos = Vector3.new(0, 0.668, 0) },
				},
			},
			{
				time = 0.71,
				pose = {
					Root = { rot = Vector3.new(6.6, 0, -2), pos = Vector3.new(-0.15, -0.72, 0.05) },
					Neck = { rot = Vector3.new(26, 8, 0) },
					RightShoulder = { rot = Vector3.new(-246.9, 0, -135.1) },
					LeftShoulder = { rot = Vector3.new(-265.4, 0, 130.1) },
					RightHip = { rot = Vector3.new(-7.3, 0, 14.8), pos = Vector3.new(0, 0.814, 0) },
					LeftHip = { rot = Vector3.new(8.8, 0, 11.3), pos = Vector3.new(0, 0.508, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(6.67, 0.01, -2.31),
						pos = Vector3.new(-0.15, -0.718, 0.05),
					},
					Neck = { rot = Vector3.new(26.117, 7.767, 0) },
					RightShoulder = { rot = Vector3.new(-66.6, 0, -81.7) },
					LeftShoulder = { rot = Vector3.new(-85.4, 0, 86.7) },
					RightHip = { rot = Vector3.new(-7, 0, 14.9), pos = Vector3.new(0, 0.879, 0) },
					LeftHip = { rot = Vector3.new(8.6, 0, 11.4), pos = Vector3.new(0, 0.56, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(7.62, 0.05, -5.81),
						pos = Vector3.new(-0.15, -0.66, 0.05),
					},
					Neck = { rot = Vector3.new(30, 0, 0) },
					RightShoulder = { rot = Vector3.new(119.2, 0, -135.2) },
					LeftShoulder = { rot = Vector3.new(97.6, 0, 129.9) },
					RightHip = { rot = Vector3.new(0.6, 0, 11.5), pos = Vector3.new(0, 1.053, 0) },
					LeftHip = { rot = Vector3.new(-0.9, 0, 9.2), pos = Vector3.new(0, 0.761, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(8.83, 0.01, -9.6),
						pos = Vector3.new(-0.15, -0.602, 0.05),
					},
					Neck = { rot = Vector3.new(33.883, -7.767, 0) },
					RightShoulder = { rot = Vector3.new(-55.4, 0, -81.4) },
					LeftShoulder = { rot = Vector3.new(100.4, 0, 129.6) },
					RightHip = { rot = Vector3.new(6.3, 0, 9.9), pos = Vector3.new(0, 0.753, 0) },
					LeftHip = { rot = Vector3.new(-12.2, 0, 8.8), pos = Vector3.new(0, 0.483, 0) },
				},
			},
			{
				time = 0.85,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(9, 0, -10), pos = Vector3.new(-0.15, -0.6, 0.05) },
					Neck = { rot = Vector3.new(34, -8, 0) },
					RightShoulder = { rot = Vector3.new(-55.2, 0, -81.4) },
					LeftShoulder = { rot = Vector3.new(100.1, 0, 129.6) },
					RightHip = { rot = Vector3.new(6.1, 0, 10.5), pos = Vector3.new(0, 0.697, 0) },
					LeftHip = { rot = Vector3.new(-13, 0, 9.4), pos = Vector3.new(0, 0.412, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(9.57, -0.05, -10.56),
						pos = Vector3.new(-0.15, -0.619, 0.054),
					},
					Neck = { rot = Vector3.new(33.226, -6.917, 0) },
					RightShoulder = { rot = Vector3.new(-56.6, 0, -81.7) },
					LeftShoulder = { rot = Vector3.new(277.2, 0, 87.4) },
					RightHip = { rot = Vector3.new(4.9, 0, 11.4), pos = Vector3.new(0, 0.854, 0) },
					LeftHip = { rot = Vector3.new(-11.7, 0, 10.3), pos = Vector3.new(0, 0.531, 0) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = {
						rot = Vector3.new(9.86, -0.08, -8.94),
						pos = Vector3.new(-0.15, -0.678, 0.066),
					},
					Neck = { rot = Vector3.new(30.916, -3.642, 0) },
					RightShoulder = { rot = Vector3.new(119, 0, -133.6) },
					LeftShoulder = { rot = Vector3.new(271.9, 0, 88.2) },
					RightHip = { rot = Vector3.new(2, 0, 11.9), pos = Vector3.new(0, 1.01, 0) },
					LeftHip = { rot = Vector3.new(-7, 0, 10.4), pos = Vector3.new(0, 0.683, 0) },
				},
			},
			{
				time = 1.02,
				pose = {
					Root = {
						rot = Vector3.new(9.99, -0.06, -6.32),
						pos = Vector3.new(-0.15, -0.75, 0.081),
					},
					Neck = { rot = Vector3.new(28.212, 0.297, 0) },
					RightShoulder = { rot = Vector3.new(305.6, 0, -88.7) },
					LeftShoulder = { rot = Vector3.new(445.6, 0, 127.9) },
					RightHip = { rot = Vector3.new(-1.6, 0, 12.6), pos = Vector3.new(0, 1.062, 0) },
					LeftHip = { rot = Vector3.new(-1.8, 0, 10.3), pos = Vector3.new(0, 0.743, 0) },
				},
			},
			{
				time = 1.08,
				pose = {
					Root = {
						rot = Vector3.new(10.29, -0.02, -4.3),
						pos = Vector3.new(-0.15, -0.806, 0.095),
					},
					Neck = { rot = Vector3.new(26.295, 3.323, 0) },
					RightShoulder = { rot = Vector3.new(119.7, 0, -126.5) },
					LeftShoulder = { rot = Vector3.new(80.1, 0, 127.3) },
					RightHip = { rot = Vector3.new(-4.7, 0, 13.2), pos = Vector3.new(0, 0.996, 0) },
					LeftHip = { rot = Vector3.new(1.3, 0, 10.4), pos = Vector3.new(0, 0.69, 0) },
				},
			},
			{
				time = 1.11,
				pose = {
					Root = { rot = Vector3.new(10.6, 0, -4), pos = Vector3.new(-0.15, -0.82, 0.1) },
					Neck = { rot = Vector3.new(26, 4, 0) },
					RightShoulder = { rot = Vector3.new(118.2, 0, -126.1) },
					LeftShoulder = { rot = Vector3.new(78.3, 0, 127.2) },
					RightHip = { rot = Vector3.new(-5.7, 0, 13.3), pos = Vector3.new(0, 0.935, 0) },
					LeftHip = { rot = Vector3.new(1.3, 0, 10.5), pos = Vector3.new(0, 0.634, 0) },
				},
			},
			{
				time = 1.14,
				pose = {
					Root = {
						rot = Vector3.new(11.05, 0.02, -4.37),
						pos = Vector3.new(-0.15, -0.81, 0.102),
					},
					Neck = { rot = Vector3.new(26.945, 3.241, 0) },
					RightShoulder = { rot = Vector3.new(119.6, 0, -126) },
					LeftShoulder = { rot = Vector3.new(78.8, 0, 126.9) },
					RightHip = { rot = Vector3.new(-4.8, 0, 12.8), pos = Vector3.new(0, 1.009, 0) },
					LeftHip = { rot = Vector3.new(0.1, 0, 10), pos = Vector3.new(0, 0.712, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(12.16, 0.03, -6.33),
						pos = Vector3.new(-0.15, -0.738, 0.101),
					},
					Neck = { rot = Vector3.new(31.668, -1.553, 0) },
					RightShoulder = { rot = Vector3.new(-51.4, 0, -90.4) },
					LeftShoulder = { rot = Vector3.new(265.3, 0, 90.8) },
					RightHip = { rot = Vector3.new(-1.3, 0, 10.8), pos = Vector3.new(0, 0.964, 0) },
					LeftHip = { rot = Vector3.new(-6.6, 0, 8.7), pos = Vector3.new(0, 0.702, 0) },
				},
			},
			{
				time = 1.25,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(13, 0, -8), pos = Vector3.new(-0.15, -0.7, 0.1) },
					Neck = { rot = Vector3.new(34, -4, 0) },
					RightShoulder = { rot = Vector3.new(-47.1, 0, -89.9) },
					LeftShoulder = { rot = Vector3.new(448.1, 0, 125.8) },
					RightHip = { rot = Vector3.new(-0.8, 0, 11.2), pos = Vector3.new(0, 0.808, 0) },
					LeftHip = { rot = Vector3.new(-11.3, 0, 9.4), pos = Vector3.new(0, 0.532, 0) },
				},
			},
			{
				time = 1.26,
				pose = {
					Root = {
						rot = Vector3.new(13.13, -0.01, -8.23),
						pos = Vector3.new(-0.15, -0.701, 0.1),
					},
					Neck = { rot = Vector3.new(33.965, -3.986, 0) },
					RightShoulder = { rot = Vector3.new(-46.5, 0, -89.7) },
					LeftShoulder = { rot = Vector3.new(88.5, 0, 125.8) },
					RightHip = { rot = Vector3.new(-1, 0, 11.4), pos = Vector3.new(0, 0.813, 0) },
					LeftHip = { rot = Vector3.new(-11.5, 0, 9.7), pos = Vector3.new(0, 0.528, 0) },
				},
			},
			{
				time = 1.32,
				pose = {
					Root = {
						rot = Vector3.new(13.63, -0.03, -8.72),
						pos = Vector3.new(-0.15, -0.736, 0.107),
					},
					Neck = { rot = Vector3.new(32.573, -3.424, 0) },
					RightShoulder = { rot = Vector3.new(-25.8, 0, -81.1) },
					LeftShoulder = { rot = Vector3.new(265.9, 0, 91.2) },
					RightHip = { rot = Vector3.new(-1.8, 0, 12.4), pos = Vector3.new(0, 0.864, 0) },
					LeftHip = { rot = Vector3.new(-10.9, 0, 10.7), pos = Vector3.new(0, 0.547, 0) },
				},
			},
			{
				time = 1.38,
				pose = {
					Root = {
						rot = Vector3.new(13.86, -0.04, -8.13),
						pos = Vector3.new(-0.15, -0.802, 0.121),
					},
					Neck = { rot = Vector3.new(30, -2.325, 0) },
					RightShoulder = { rot = Vector3.new(-1.8, 0, -43.3) },
					LeftShoulder = { rot = Vector3.new(-7.8, 0, 54.2) },
					RightHip = { rot = Vector3.new(-2.6, 0, 12.6), pos = Vector3.new(0, 0.931, 0) },
					LeftHip = { rot = Vector3.new(-8.9, 0, 10.8), pos = Vector3.new(0, 0.615, 0) },
				},
			},
			{
				time = 1.44,
				pose = {
					Root = {
						rot = Vector3.new(14.06, -0.02, -7.07),
						pos = Vector3.new(-0.15, -0.871, 0.136),
					},
					Neck = { rot = Vector3.new(27.427, -1.088, 0) },
					RightShoulder = { rot = Vector3.new(8.9, 0, -3.4) },
					LeftShoulder = { rot = Vector3.new(8.3, 0, 2.7) },
					RightHip = { rot = Vector3.new(-3.2, 0, 12.3), pos = Vector3.new(0, 0.992, 0) },
					LeftHip = { rot = Vector3.new(-6.6, 0, 10.3), pos = Vector3.new(0, 0.691, 0) },
				},
			},
			{
				time = 1.5,
				pose = {
					Root = {
						rot = Vector3.new(14.49, 0, -6.11),
						pos = Vector3.new(-0.15, -0.917, 0.149),
					},
					Neck = { rot = Vector3.new(26.035, -0.11, 0) },
					RightShoulder = { rot = Vector3.new(11.9, 0, 7.8) },
					LeftShoulder = { rot = Vector3.new(11.9, 0, -7.8) },
					RightHip = { rot = Vector3.new(-3.7, 0, 11.8), pos = Vector3.new(0, 1.025, 0) },
					LeftHip = { rot = Vector3.new(-5.6, 0, 9.6), pos = Vector3.new(0, 0.745, 0) },
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
				time = 1.56,
				pose = {
					Root = {
						rot = Vector3.new(15.35, 0.01, -5.75),
						pos = Vector3.new(-0.15, -0.89, 0.153),
					},
					Neck = { rot = Vector3.new(28.332, 0.207, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-4.7, 0, 11.6), pos = Vector3.new(0, 0.992, 0) },
					LeftHip = { rot = Vector3.new(-6.6, 0, 9.3), pos = Vector3.new(0, 0.723, 0) },
				},
			},
			{
				time = 1.62,
				pose = {
					Root = {
						rot = Vector3.new(16.46, 0.01, -5.87),
						pos = Vector3.new(-0.15, -0.815, 0.151),
					},
					Neck = { rot = Vector3.new(33.055, 0.051, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-6.5, 0, 11.9), pos = Vector3.new(0, 0.921, 0) },
					LeftHip = { rot = Vector3.new(-8.6, 0, 9.6), pos = Vector3.new(0, 0.643, 0) },
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
				time = 1.68,
				pose = {
					Root = {
						rot = Vector3.new(17.48, -0.01, -6.12),
						pos = Vector3.new(-0.15, -0.8, 0.15),
					},
					Neck = { rot = Vector3.new(33.994, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-7.8, 0, 12.2), pos = Vector3.new(0, 0.91, 0) },
					LeftHip = { rot = Vector3.new(-10, 0, 9.9), pos = Vector3.new(0, 0.622, 0) },
				},
			},
			{
				time = 1.74,
				pose = {
					Root = {
						rot = Vector3.new(18.25, -0.02, -6.31),
						pos = Vector3.new(-0.15, -0.801, 0.15),
					},
					Neck = { rot = Vector3.new(33.95, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-8.6, 0, 12.3), pos = Vector3.new(0, 0.914, 0) },
					LeftHip = { rot = Vector3.new(-10.9, 0, 10.1), pos = Vector3.new(0, 0.618, 0) },
				},
			},
			{
				time = 1.8,
				pose = {
					Root = {
						rot = Vector3.new(18.79, -0.03, -6.45),
						pos = Vector3.new(-0.15, -0.802, 0.15),
					},
					Neck = { rot = Vector3.new(33.866, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-9.2, 0, 12.5), pos = Vector3.new(0, 0.917, 0) },
					LeftHip = { rot = Vector3.new(-11.6, 0, 10.3), pos = Vector3.new(0, 0.616, 0) },
				},
			},
			{
				time = 1.86,
				pose = {
					Root = {
						rot = Vector3.new(19.13, -0.03, -6.54),
						pos = Vector3.new(-0.15, -0.804, 0.15),
					},
					Neck = { rot = Vector3.new(33.75, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-9.5, 0, 12.6), pos = Vector3.new(0, 0.921, 0) },
					LeftHip = { rot = Vector3.new(-12, 0, 10.4), pos = Vector3.new(0, 0.616, 0) },
				},
			},
			{
				time = 1.92,
				pose = {
					Root = {
						rot = Vector3.new(19.28, -0.04, -6.59),
						pos = Vector3.new(-0.15, -0.806, 0.15),
					},
					Neck = { rot = Vector3.new(33.607, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-9.7, 0, 12.6), pos = Vector3.new(0, 0.923, 0) },
					LeftHip = { rot = Vector3.new(-12.1, 0, 10.4), pos = Vector3.new(0, 0.617, 0) },
				},
			},
			{
				time = 1.98,
				pose = {
					Root = {
						rot = Vector3.new(19.28, -0.04, -6.6),
						pos = Vector3.new(-0.15, -0.808, 0.15),
					},
					Neck = { rot = Vector3.new(33.444, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-9.7, 0, 12.6), pos = Vector3.new(0, 0.926, 0) },
					LeftHip = { rot = Vector3.new(-12.1, 0, 10.4), pos = Vector3.new(0, 0.618, 0) },
				},
			},
			{
				time = 2.04,
				pose = {
					Root = {
						rot = Vector3.new(19.16, -0.04, -6.58),
						pos = Vector3.new(-0.15, -0.811, 0.15),
					},
					Neck = { rot = Vector3.new(33.266, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-9.5, 0, 12.6), pos = Vector3.new(0, 0.928, 0) },
					LeftHip = { rot = Vector3.new(-11.9, 0, 10.4), pos = Vector3.new(0, 0.622, 0) },
				},
			},
			{
				time = 2.1,
				pose = {
					Root = {
						rot = Vector3.new(18.93, -0.03, -6.53),
						pos = Vector3.new(-0.15, -0.814, 0.15),
					},
					Neck = { rot = Vector3.new(33.079, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-9.2, 0, 12.5), pos = Vector3.new(0, 0.931, 0) },
					LeftHip = { rot = Vector3.new(-11.6, 0, 10.3), pos = Vector3.new(0, 0.627, 0) },
				},
			},
			{
				time = 2.16,
				pose = {
					Root = {
						rot = Vector3.new(18.62, -0.03, -6.47),
						pos = Vector3.new(-0.15, -0.817, 0.15),
					},
					Neck = { rot = Vector3.new(32.89, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-8.9, 0, 12.5), pos = Vector3.new(0, 0.933, 0) },
					LeftHip = { rot = Vector3.new(-11.2, 0, 10.3), pos = Vector3.new(0, 0.631, 0) },
				},
			},
			{
				time = 2.22,
				pose = {
					Root = {
						rot = Vector3.new(18.26, -0.02, -6.39),
						pos = Vector3.new(-0.15, -0.819, 0.15),
					},
					Neck = { rot = Vector3.new(32.704, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-8.5, 0, 12.4), pos = Vector3.new(0, 0.933, 0) },
					LeftHip = { rot = Vector3.new(-10.8, 0, 10.2), pos = Vector3.new(0, 0.635, 0) },
				},
			},
			{
				time = 2.28,
				pose = {
					Root = {
						rot = Vector3.new(17.87, -0.02, -6.31),
						pos = Vector3.new(-0.15, -0.822, 0.15),
					},
					Neck = { rot = Vector3.new(32.528, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-8, 0, 12.3), pos = Vector3.new(0, 0.935, 0) },
					LeftHip = { rot = Vector3.new(-10.3, 0, 10.1), pos = Vector3.new(0, 0.64, 0) },
				},
			},
			{
				time = 2.34,
				pose = {
					Root = {
						rot = Vector3.new(17.48, -0.01, -6.22),
						pos = Vector3.new(-0.15, -0.824, 0.15),
					},
					Neck = { rot = Vector3.new(32.367, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-7.6, 0, 12.2), pos = Vector3.new(0, 0.936, 0) },
					LeftHip = { rot = Vector3.new(-9.8, 0, 10), pos = Vector3.new(0, 0.645, 0) },
				},
			},
			{
				time = 2.4,
				pose = {
					Root = {
						rot = Vector3.new(17.12, -0.01, -6.14),
						pos = Vector3.new(-0.15, -0.827, 0.15),
					},
					Neck = { rot = Vector3.new(32.229, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-7.2, 0, 12.1), pos = Vector3.new(0, 0.937, 0) },
					LeftHip = { rot = Vector3.new(-9.3, 0, 9.9), pos = Vector3.new(0, 0.65, 0) },
				},
			},
			{
				time = 2.46,
				pose = {
					Root = {
						rot = Vector3.new(16.8, 0, -6.08),
						pos = Vector3.new(-0.15, -0.828, 0.15),
					},
					Neck = { rot = Vector3.new(32.118, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-6.8, 0, 12), pos = Vector3.new(0, 0.937, 0) },
					LeftHip = { rot = Vector3.new(-8.9, 0, 9.8), pos = Vector3.new(0, 0.652, 0) },
				},
			},
			{
				time = 2.52,
				pose = {
					Root = {
						rot = Vector3.new(16.56, 0, -6.03),
						pos = Vector3.new(-0.15, -0.829, 0.15),
					},
					Neck = { rot = Vector3.new(32.04, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-6.6, 0, 12), pos = Vector3.new(0, 0.937, 0) },
					LeftHip = { rot = Vector3.new(-8.6, 0, 9.7), pos = Vector3.new(0, 0.654, 0) },
				},
			},
			{
				time = 2.58,
				pose = {
					Root = {
						rot = Vector3.new(16.42, 0, -6),
						pos = Vector3.new(-0.15, -0.83, 0.15),
					},
					Neck = { rot = Vector3.new(32.003, 0, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -8) },
					RightHip = { rot = Vector3.new(-6.4, 0, 12), pos = Vector3.new(0, 0.938, 0) },
					LeftHip = { rot = Vector3.new(-8.5, 0, 9.7), pos = Vector3.new(0, 0.656, 0) },
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
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-11.32, -9.64, -2.31),
						pos = Vector3.new(0.017, -0.166, -0.112),
					},
					Neck = { rot = Vector3.new(9.248, 2.76, 0) },
					RightShoulder = { rot = Vector3.new(111.4, 0, -83.9) },
					LeftShoulder = { rot = Vector3.new(61.8, 0, 61.9) },
					RightHip = { rot = Vector3.new(8.8, 0, 4.7), pos = Vector3.new(0, 0.249, 0) },
					LeftHip = { rot = Vector3.new(18.2, 0, -3.3), pos = Vector3.new(0, 0.156, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-8.37, -21.16, -4.58),
						pos = Vector3.new(0.058, -0.206, -0.025),
					},
					Neck = { rot = Vector3.new(7.504, 9.28, 0) },
					RightShoulder = { rot = Vector3.new(113.9, 0, -86) },
					LeftShoulder = { rot = Vector3.new(52.5, 0, 47.8) },
					RightHip = { rot = Vector3.new(8.2, 0, 6.8), pos = Vector3.new(0, 0.361, 0) },
					LeftHip = { rot = Vector3.new(11.9, 0, -3.7), pos = Vector3.new(0, 0.204, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-5.91, -31.87, -6.27),
						pos = Vector3.new(0.104, -0.258, 0.073),
					},
					Neck = { rot = Vector3.new(5.536, 16.92, 0) },
					RightShoulder = { rot = Vector3.new(144.6, 0, -74.7) },
					LeftShoulder = { rot = Vector3.new(53.9, 0, 42.1) },
					RightHip = { rot = Vector3.new(8.4, 0, 8.4), pos = Vector3.new(0, 0.441, 0) },
					LeftHip = { rot = Vector3.new(6.4, 0, -3.8), pos = Vector3.new(0, 0.244, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-4.6, -39.03, -7.2),
						pos = Vector3.new(0.141, -0.31, 0.144),
					},
					Neck = { rot = Vector3.new(4.112, 23.04, 0) },
					RightShoulder = { rot = Vector3.new(-58.2, 0, -137.3) },
					LeftShoulder = { rot = Vector3.new(57.2, 0, 50.5) },
					RightHip = { rot = Vector3.new(9, 0, 9.3), pos = Vector3.new(0, 0.469, 0) },
					LeftHip = { rot = Vector3.new(3, 0, -4.1), pos = Vector3.new(0, 0.283, 0) },
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
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-8.15, -32.74, -6.33),
						pos = Vector3.new(0.118, -0.38, 0.052),
					},
					Neck = { rot = Vector3.new(5.968, 20.72, 0) },
					RightShoulder = { rot = Vector3.new(155.7, 0, -52.7) },
					LeftShoulder = { rot = Vector3.new(70.9, 0, 60.5) },
					RightHip = { rot = Vector3.new(8.5, 0, 9.7), pos = Vector3.new(0, 0.457, 0) },
					LeftHip = { rot = Vector3.new(9.2, 0, -6.4), pos = Vector3.new(0, 0.517, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-12.66, -19.93, -3.76),
						pos = Vector3.new(0.055, -0.407, -0.125),
					},
					Neck = { rot = Vector3.new(9.504, 11.96, 0) },
					RightShoulder = { rot = Vector3.new(137.8, 0, -67.9) },
					LeftShoulder = { rot = Vector3.new(85.2, 0, 73.5) },
					RightHip = { rot = Vector3.new(5, 0, 9.8), pos = Vector3.new(0, 0.427, 0) },
					LeftHip = { rot = Vector3.new(19.8, 0, -6.4), pos = Vector3.new(0, 0.631, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-18.23, -4.83, 0.4),
						pos = Vector3.new(-0.017, -0.429, -0.323),
					},
					Neck = { rot = Vector3.new(13.456, 1.84, 0) },
					RightShoulder = { rot = Vector3.new(124.9, 0, -43.7) },
					LeftShoulder = { rot = Vector3.new(114.8, 0, 25.7) },
					RightHip = { rot = Vector3.new(0.3, 0, 7.1), pos = Vector3.new(0, 0.317, 0) },
					LeftHip = { rot = Vector3.new(32.6, 0, -3.1), pos = Vector3.new(0, 0.588, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-24.42, 9.23, 5.7),
						pos = Vector3.new(-0.076, -0.444, -0.484),
					},
					Neck = { rot = Vector3.new(16.672, -6.52, 0) },
					RightShoulder = { rot = Vector3.new(134.6, 0, -31) },
					LeftShoulder = { rot = Vector3.new(121.5, 0, 43.4) },
					RightHip = { rot = Vector3.new(-2.6, 0, 1.2), pos = Vector3.new(0, 0.152, 0) },
					LeftHip = { rot = Vector3.new(46.2, 0, 2.7), pos = Vector3.new(0, 0.35, 0) },
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
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-32.16, 23.78, 13.18),
						pos = Vector3.new(-0.092, -0.438, -0.534),
					},
					Neck = { rot = Vector3.new(17.531, -9.219, 0) },
					RightShoulder = { rot = Vector3.new(145, 0, -16.2) },
					LeftShoulder = { rot = Vector3.new(125.4, 0, 57.6) },
					RightHip = { rot = Vector3.new(0.1, 0, -7.1) },
					LeftHip = { rot = Vector3.new(60.6, 0, 9.5) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-31.09, 23.83, 12.6),
						pos = Vector3.new(-0.073, -0.409, -0.496),
					},
					Neck = { rot = Vector3.new(16.368, -7.28, 0) },
					RightShoulder = { rot = Vector3.new(136.1, 0, -15.4) },
					LeftShoulder = { rot = Vector3.new(117.2, 0, 57.2) },
					RightHip = { rot = Vector3.new(0.9, 0, -6.7), pos = Vector3.new(0, 0.009, 0) },
					LeftHip = { rot = Vector3.new(59.6, 0, 9) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(-27.84, 20.92, 10.1),
						pos = Vector3.new(-0.048, -0.372, -0.446),
					},
					Neck = { rot = Vector3.new(14.871, -4.786, 0) },
					RightShoulder = { rot = Vector3.new(116.5, 0, -17.9) },
					LeftShoulder = { rot = Vector3.new(103.8, 0, 53.2) },
					RightHip = { rot = Vector3.new(0.9, 0, -4.8), pos = Vector3.new(0, 0.048, 0) },
					LeftHip = { rot = Vector3.new(56.6, 0, 7.3) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(-23.87, 16.44, 7.06),
						pos = Vector3.new(-0.023, -0.335, -0.397),
					},
					Neck = { rot = Vector3.new(13.405, -2.342, 0) },
					RightShoulder = { rot = Vector3.new(92.3, 0, -22) },
					LeftShoulder = { rot = Vector3.new(88.1, 0, 46.7) },
					RightHip = { rot = Vector3.new(0.3, 0, -2.4), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(52.4, 0, 5.1) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(-20.33, 11.97, 4.48),
						pos = Vector3.new(-0.006, -0.308, -0.361),
					},
					Neck = { rot = Vector3.new(12.332, -0.554, 0) },
					RightShoulder = { rot = Vector3.new(75.5, 0, -24.7) },
					LeftShoulder = { rot = Vector3.new(74.3, 0, 40.2) },
					RightHip = { rot = Vector3.new(-0.8, 0, -0.1), pos = Vector3.new(0, 0.125, 0) },
					LeftHip = { rot = Vector3.new(47.9, 0, 3.4) },
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
					RightShoulder = { rot = Vector3.new(251.9, 0, -137.8) },
					LeftShoulder = { rot = Vector3.new(54, 0, 46.1) },
					RightHip = { rot = Vector3.new(14.8, 0, 1.4), pos = Vector3.new(0, 0.038, 0) },
					LeftHip = { rot = Vector3.new(14.8, 0, -1.4), pos = Vector3.new(0, 0.038, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-14.62, -7.87, 0.08),
						pos = Vector3.new(-0.055, -0.026, -0.027),
					},
					Neck = { rot = Vector3.new(-11.6, 0, 0) },
					RightShoulder = { rot = Vector3.new(71.4, 0, -62.4) },
					LeftShoulder = { rot = Vector3.new(42.8, 0, 45.2) },
					RightHip = { rot = Vector3.new(20.2, 0, 0.5) },
					LeftHip = { rot = Vector3.new(16.2, 0, -2.1) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-18.22, -16.97, -0.26),
						pos = Vector3.new(-0.186, 0.037, -0.09),
					},
					Neck = { rot = Vector3.new(-15.2, 0, 0) },
					RightShoulder = { rot = Vector3.new(242.5, 0, -139.9) },
					LeftShoulder = { rot = Vector3.new(41.5, 0, 44) },
					RightHip = { rot = Vector3.new(26.1, 0, 0.8) },
					LeftHip = { rot = Vector3.new(17.9, 0, -1.9) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-21.62, -25.41, -1.16),
						pos = Vector3.new(-0.338, 0.123, -0.158),
					},
					Neck = { rot = Vector3.new(-19, 0, 0) },
					RightShoulder = { rot = Vector3.new(256.4, 0, -135.7) },
					LeftShoulder = { rot = Vector3.new(36.9, 0, 40.5) },
					RightHip = { rot = Vector3.new(-25.35, 0, 11.423) },
					LeftHip = { rot = Vector3.new(33.19, 0, -9.279) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-23.37, -31.37, -2.12),
						pos = Vector3.new(-0.461, 0.216, -0.205),
					},
					Neck = { rot = Vector3.new(-21.2, 0, 0) },
					RightShoulder = { rot = Vector3.new(63.4, 0, -62.6) },
					LeftShoulder = { rot = Vector3.new(49.5, 0, 25.5) },
					RightHip = { rot = Vector3.new(-24.79, 0, 9.368) },
					LeftHip = { rot = Vector3.new(32.87, 0, -7.24) },
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
					RightShoulder = { rot = Vector3.new(67.9, 0, -64.4) },
					LeftShoulder = { rot = Vector3.new(31.3, 0, 30.7) },
					RightHip = { rot = Vector3.new(-11.151, 0, 6.803) },
					LeftHip = { rot = Vector3.new(21.151, 0, -4.803) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-15.4, -29.25, -1.28),
						pos = Vector3.new(-0.414, 0.39, -0.112),
					},
					Neck = { rot = Vector3.new(-13.08, 0, 0) },
					RightShoulder = { rot = Vector3.new(290.1, 0, -148.4) },
					LeftShoulder = { rot = Vector3.new(46.9, 0, 17.5) },
					RightHip = { rot = Vector3.new(7.668, 0, 5.195) },
					LeftHip = { rot = Vector3.new(7.372, 0, -3.531) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-6.36, -21.07, -0.84),
						pos = Vector3.new(-0.239, 0.495, 0.04),
					},
					Neck = { rot = Vector3.new(-1.64, 0, 0) },
					RightShoulder = { rot = Vector3.new(42.3, 0, -23.8) },
					LeftShoulder = { rot = Vector3.new(49.7, 0, 0) },
					RightHip = { rot = Vector3.new(20.304, 0, 5.513) },
					LeftHip = { rot = Vector3.new(2.416, 0, -4.361) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(3.93, -10.5, -2.15),
						pos = Vector3.new(-0.037, 0.595, 0.208),
					},
					Neck = { rot = Vector3.new(10.84, 0, 0) },
					RightShoulder = { rot = Vector3.new(26.7, 0, 41.7) },
					LeftShoulder = { rot = Vector3.new(105.4, 0, -51.2) },
					RightHip = { rot = Vector3.new(21.754, 0, 7.788) },
					LeftHip = { rot = Vector3.new(9.126, 0, -7.18) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(14.73, 0.24, -5.49),
						pos = Vector3.new(0.13, 0.67, 0.344),
					},
					Neck = { rot = Vector3.new(20.88, 0, 0) },
					RightShoulder = { rot = Vector3.new(112.9, 0, 62.3) },
					LeftShoulder = { rot = Vector3.new(132.6, 0, -58.6) },
					RightHip = { rot = Vector3.new(17.495, 0, 11.195) },
					LeftHip = { rot = Vector3.new(19.865, 0, -11.019) },
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
					RightShoulder = { rot = Vector3.new(137.2, 0, 53.1) },
					LeftShoulder = { rot = Vector3.new(132.9, 0, -60.7) },
					RightHip = { rot = Vector3.new(16.079, 0, 14.295) },
					LeftHip = { rot = Vector3.new(23.921, 0, -14.295) },
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
	Bone_Throw = {
		length = 0.75,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(2.89, -28.47, 2.56),
						pos = Vector3.new(0.053, -0.078, 0.178),
					},
					Neck = { rot = Vector3.new(2.625, 21.562, 0) },
					RightShoulder = { rot = Vector3.new(148.8, 0, -22.3) },
					LeftShoulder = { rot = Vector3.new(112.3, 0, 20.7) },
					RightHip = { rot = Vector3.new(-0.6, 0, 1.2), pos = Vector3.new(0, 0.286, 0) },
					LeftHip = { rot = Vector3.new(1.2, 0, -8.6), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(9.74, -34.61, 5.57),
						pos = Vector3.new(0.1, -0.2, 0.3),
					},
					Neck = { rot = Vector3.new(0, 30, 0) },
					RightShoulder = { rot = Vector3.new(178.6, 0, -7.5) },
					LeftShoulder = { rot = Vector3.new(108.7, 0, -10.9) },
					RightHip = { rot = Vector3.new(-8.6, 0, 6.6), pos = Vector3.new(0, 0.237, 0) },
					LeftHip = { rot = Vector3.new(-1.9, 0, -14.6), pos = Vector3.new(0, 0.243, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-0.94, -11.65, 2.28),
						pos = Vector3.new(0.022, -0.297, -0.103),
					},
					Neck = { rot = Vector3.new(6.375, 5.938, 0) },
					RightShoulder = { rot = Vector3.new(177.8, 0, -30) },
					LeftShoulder = { rot = Vector3.new(129, 0, 29.7) },
					RightHip = { rot = Vector3.new(-17.1, 0, 6.6), pos = Vector3.new(0, 0.207, 0) },
					LeftHip = { rot = Vector3.new(17.2, 0, -8.7), pos = Vector3.new(0, 0.475, 0) },
				},
			},
			{
				time = 0.24,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-16.97, 19.19, 5.73),
						pos = Vector3.new(-0.05, -0.35, -0.45),
					},
					Neck = { rot = Vector3.new(12, -15, 0) },
					RightShoulder = { rot = Vector3.new(175.1, 0, -31.2) },
					LeftShoulder = { rot = Vector3.new(-56.9, 0, 3.9) },
					RightHip = { rot = Vector3.new(-17.3, 0, -5.2) },
					LeftHip = { rot = Vector3.new(46.9, 0, 6.4) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-30.68, 31.65, 14.04),
						pos = Vector3.new(-0.068, -0.402, -0.476),
					},
					Neck = { rot = Vector3.new(14.614, -16.996, 0) },
					RightShoulder = { rot = Vector3.new(184.9, 0, -47.7) },
					LeftShoulder = { rot = Vector3.new(-35, 0, -16) },
					RightHip = { rot = Vector3.new(-5, 0, -11) },
					LeftHip = { rot = Vector3.new(60.6, 0, 13) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-35.37, 29.73, 17.33),
						pos = Vector3.new(-0.095, -0.483, -0.509),
					},
					Neck = { rot = Vector3.new(18.882, -19.881, 0) },
					RightShoulder = { rot = Vector3.new(124.3, 0, -82.7) },
					LeftShoulder = { rot = Vector3.new(-41.9, 0, -16.7) },
					RightHip = { rot = Vector3.new(-0.6, 0, -12.6) },
					LeftHip = { rot = Vector3.new(66.3, 0, 12.1) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-33.69, 25.66, 16.1),
						pos = Vector3.new(-0.1, -0.5, -0.5),
					},
					Neck = { rot = Vector3.new(20, -20, 0) },
					RightShoulder = { rot = Vector3.new(95.9, 0, -81.7) },
					LeftShoulder = { rot = Vector3.new(-47.8, 0, -11.7) },
					RightHip = { rot = Vector3.new(-1, 0, -12) },
					LeftHip = { rot = Vector3.new(66.3, 0, 9.5) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-31.85, 23.69, 14.79),
						pos = Vector3.new(-0.095, -0.49, -0.481),
					},
					Neck = { rot = Vector3.new(19.643, -19.19, 0) },
					RightShoulder = { rot = Vector3.new(96.6, 0, -81.2) },
					LeftShoulder = { rot = Vector3.new(-51.1, 0, -7.5) },
					RightHip = { rot = Vector3.new(-2.3, 0, -11.6) },
					LeftHip = { rot = Vector3.new(65.8, 0, 8.7) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-24.17, 18.16, 9.46),
						pos = Vector3.new(-0.06, -0.417, -0.385),
					},
					Neck = { rot = Vector3.new(16.475, -14.712, 0) },
					RightShoulder = { rot = Vector3.new(111.5, 0, -69.6) },
					LeftShoulder = { rot = Vector3.new(206.5, 0, 84.1) },
					RightHip = { rot = Vector3.new(-3.7, 0, -6.7), pos = Vector3.new(0, 0.195, 0) },
					LeftHip = { rot = Vector3.new(50.5, 0, 4.3), pos = Vector3.new(0, 0.255, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-16.1, 12.21, 4.13),
						pos = Vector3.new(-0.019, -0.314, -0.267),
					},
					Neck = { rot = Vector3.new(12.189, -8.764, 0) },
					RightShoulder = { rot = Vector3.new(120.6, 0, -41.7) },
					LeftShoulder = { rot = Vector3.new(127.1, 0, 54.2) },
					RightHip = { rot = Vector3.new(-2.8, 0, -2), pos = Vector3.new(0, 0.242, 0) },
					LeftHip = { rot = Vector3.new(36.3, 0, 1.2), pos = Vector3.new(0, 0.254, 0) },
				},
			},
			{
				time = 0.58,
				pose = {
					Root = {
						rot = Vector3.new(-12.11, 7.82, 1.67),
						pos = Vector3.new(0, -0.25, -0.2),
					},
					Neck = { rot = Vector3.new(10, -5, 0) },
					RightShoulder = { rot = Vector3.new(116.4, 0, -36.3) },
					LeftShoulder = { rot = Vector3.new(119.3, 0, 47.5) },
					RightHip = { rot = Vector3.new(-2.6, 0, 0.3), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(31.2, 0, 0.3), pos = Vector3.new(0, 0.117, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-10.82, 5.54, 0.94),
						pos = Vector3.new(0.004, -0.218, -0.17),
					},
					Neck = { rot = Vector3.new(9.224, -3.091, 0) },
					RightShoulder = { rot = Vector3.new(112.6, 0, -37.7) },
					LeftShoulder = { rot = Vector3.new(116.1, 0, 44.8) },
					RightHip = { rot = Vector3.new(-2.6, 0, 1.1), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(28.8, 0, -0.1), pos = Vector3.new(0, 0.169, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-9.04, -1.44, 0.11),
						pos = Vector3.new(0.006, -0.104, -0.077),
					},
					Neck = { rot = Vector3.new(7.279, 3.761, 0) },
					RightShoulder = { rot = Vector3.new(107.5, 0, -39) },
					LeftShoulder = { rot = Vector3.new(111.9, 0, 38) },
					RightHip = { rot = Vector3.new(3.3, 0, 1.2), pos = Vector3.new(0, 0.201, 0) },
					LeftHip = { rot = Vector3.new(20.5, 0, -1.6), pos = Vector3.new(0, 0.246, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-8.49, -8.49, 0.09),
						pos = Vector3.new(0.001, -0.014, -0.01),
					},
					Neck = { rot = Vector3.new(6.155, 9.137, 0) },
					RightShoulder = { rot = Vector3.new(110.1, 0, -37.2) },
					LeftShoulder = { rot = Vector3.new(114.3, 0, 36.7) },
					RightHip = { rot = Vector3.new(10.7, 0, -1.4), pos = Vector3.new(0, 0.037, 0) },
					LeftHip = { rot = Vector3.new(13.6, 0, -2.5), pos = Vector3.new(0, 0.121, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
		},
	},
}

return table.freeze(clips)
