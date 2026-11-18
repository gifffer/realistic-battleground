--!strict
-- Dr. Rift's clips (Shared/Kits/Rift). R6Pose format, see R6Pose / CombatClips.
-- Merged into CombatClips (the end of that file).
--
-- Authored as whole-body keys (the torso placed, the hands put on targets:
-- the gun aimed along the arm, the glove's palm thrust at a point) with the
-- feet planted apart from them (a foot moves only in a step, an arc from one
-- spot to the next, so it never slides), then solved every 1/30 s (the
-- finisher every 0.05 s), each solve starting from the last one (no pops),
-- with extra keys wherever the game's spline between two keys would let a
-- planted foot drift or a hand leave its arc. Animation principles on top:
-- anticipation before every action, the torso leading and the arm whipping
-- after it, the head lagging behind the torso's turns and settling late,
-- arcs (a long swing of an arm follows the great circle round its shoulder,
-- going round the body, never through it), ease in / out on every key,
-- breathing on the finisher's holds. Checked on
-- rendered frames from three camera angles (a Blender rig with the same
-- spline as the game). Every clip starts and ends on the shared Guard pose.
-- The timings below must stay in sync with the kit data (Shared/Kits/Rift)
-- and Shared/Finishers:
--
--   • Rift_Flask / Rift_FlaskBomb: snatched from the belt, held up to the
--     light (shaken twice / hefted, the heavy one), cocked up over the head
--     and back as the left foot strides in, an overhand lob: the flask
--     leaves his right hand at 0.34 / 0.36 s (FlaskDef.release) with the arm
--     about vertical, the hand at its fastest and going forward; follow-
--     through on over the top and down across the body, the back foot
--     comes through.
--   • Rift_RayGun: drawn from the hip into a side-on duellist's stance;
--     fires at 0.32 s, the kick after, the muzzle up by his face.
--   • Rift_MegaRay: charged at the hip, both hands; fires at 0.45 s, the
--     recoil throws him back a step.
--   • Rift_Glove: the metal palm thrust out at 0.36 s, a lunge.
--   • Rift_Portal: far shot 0.28 s, near shot (down in front) 0.52 s, walks
--     in, furthest in at 0.78 s (Gadgets moves him to the exit then); after
--     that he comes up out of the floor portal where he stands now (a jump
--     between two flat keys at 0.78 / 0.784, hidden by the move).
--   • Rift_Swarm: points the glove at them at 0.35 s, then waves them on.
--   • Rift_Slam: a crouch, a hop with the glove raised in front, brought
--     down over the top into the floor at 0.55 s, down on one knee.
--   • Rift_Awaken: 1.0 s (Config.Kits.AWAKEN_TIME): gathers, the glove raised
--     and trembling, then both arms flung out at 0.75 s.
--   • Rift_ClonePunch: a clone's hook (a small coil, the right side turned
--     through), landing at 0.12 s.
--   • Rift_FinisherPortalCut / ...Victim (4.6 s, PortalCut): the glove lifts
--     them 0.15-0.9 s, the portal gun on their waist 1.15 s, the cut 2.55 s.
--     The victim stands 3.4 studs in front (Finishers.PORTAL_DISTANCE).

local R6Pose = require(script.Parent.R6Pose)

local clips: { [string]: R6Pose.Clip } = {
	Rift_Flask = {
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
				},
			},
			{
				time = 0.017,
				pose = {
					Root = {
						rot = Vector3.new(-9.66, -14.41, -1.18),
						pos = Vector3.new(0.01, -0.027, 0.008),
					},
					Neck = { rot = Vector3.new(1.6, 7.82, 0.24) },
					RightShoulder = { rot = Vector3.new(81.09, 0, -33.24) },
					LeftShoulder = { rot = Vector3.new(115.82, 0, 32.91) },
					RightHip = { rot = Vector3.new(3.02, 0, 0.8), pos = Vector3.new(0, 0.041, 0) },
					LeftHip = { rot = Vector3.new(1.81, 0, 0.85), pos = Vector3.new(0, 0.014, 0) },
				},
			},
			{
				time = 0.033,
				pose = {
					Root = {
						rot = Vector3.new(-13.01, -19.56, -3.61),
						pos = Vector3.new(0.033, -0.086, 0.027),
					},
					Neck = { rot = Vector3.new(-7.33, 3.58, 0.59) },
					RightShoulder = { rot = Vector3.new(52.05, 0, -11.27) },
					LeftShoulder = { rot = Vector3.new(117.14, 0, 23.89) },
					RightHip = { rot = Vector3.new(8.8, 0, 1.64), pos = Vector3.new(0, 0.116, 0) },
					LeftHip = { rot = Vector3.new(5.07, 0, 1.93), pos = Vector3.new(0, 0.052, 0) },
				},
			},
			{
				time = 0.047,
				pose = {
					Root = {
						rot = Vector3.new(-15.33, -23.64, -5.35),
						pos = Vector3.new(0.05, -0.133, 0.044),
					},
					Neck = { rot = Vector3.new(-14.01, 0.41, 0.58) },
					RightShoulder = { rot = Vector3.new(27.21, 0, -3.96) },
					LeftShoulder = { rot = Vector3.new(117.52, 0, 16.66) },
					RightHip = { rot = Vector3.new(12.8, 0, 1.86), pos = Vector3.new(0, 0.197, 0) },
					LeftHip = { rot = Vector3.new(6.82, 0, 2.15), pos = Vector3.new(0, 0.091, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(-16, -26, -6), pos = Vector3.new(0.06, -0.16, 0.06) },
					Neck = { rot = Vector3.new(-17.41, -1.46, 0) },
					RightShoulder = { rot = Vector3.new(6.9, 0, -9.95) },
					LeftShoulder = { rot = Vector3.new(116.46, 0, 12.32) },
					RightHip = { rot = Vector3.new(14.78, 0, 2.08), pos = Vector3.new(0, 0.264, 0) },
					LeftHip = { rot = Vector3.new(6.92, 0, 1.95), pos = Vector3.new(0, 0.121, 0) },
				},
			},
			{
				time = 0.08,
				pose = {
					Root = {
						rot = Vector3.new(-13.86, -26.29, -4.89),
						pos = Vector3.new(0.061, -0.165, 0.081),
					},
					Neck = { rot = Vector3.new(-16.93, -2.78, -1.92) },
					RightShoulder = { rot = Vector3.new(32.72, 0, 1.53) },
					LeftShoulder = { rot = Vector3.new(112, 0, 10.93) },
					RightHip = { rot = Vector3.new(14.44, 0, 2.93), pos = Vector3.new(0, 0.298, 0) },
					LeftHip = { rot = Vector3.new(4.57, 0, 1.42), pos = Vector3.new(0, 0.138, 0) },
				},
			},
			{
				time = 0.09,
				pose = {
					Root = {
						rot = Vector3.new(-12.05, -25.78, -3.86),
						pos = Vector3.new(0.058, -0.16, 0.091),
					},
					Neck = { rot = Vector3.new(-16.12, -4.01, -3.16) },
					RightShoulder = { rot = Vector3.new(48.24, 0, 1.14) },
					LeftShoulder = { rot = Vector3.new(108.95, 0, 11.24) },
					RightHip = { rot = Vector3.new(13.52, 0, 3.41), pos = Vector3.new(0, 0.282, 0) },
					LeftHip = { rot = Vector3.new(2.77, 0, 1.05), pos = Vector3.new(0, 0.141, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-9.97, -25.01, -2.66),
						pos = Vector3.new(0.055, -0.153, 0.102),
					},
					Neck = { rot = Vector3.new(-15.19, -5.57, -4.51) },
					RightShoulder = { rot = Vector3.new(62.47, 0, -7.67) },
					LeftShoulder = { rot = Vector3.new(105.59, 0, 11.98) },
					RightHip = { rot = Vector3.new(12.14, 0, 3.79), pos = Vector3.new(0, 0.247, 0) },
					LeftHip = { rot = Vector3.new(0.71, 0, 0.58), pos = Vector3.new(0, 0.143, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-5.6, -23.23, -0.1),
						pos = Vector3.new(0.046, -0.134, 0.122),
					},
					Neck = { rot = Vector3.new(-13.01, -8.73, -7.36) },
					RightShoulder = { rot = Vector3.new(89.01, 0, -22.75) },
					LeftShoulder = { rot = Vector3.new(98.78, 0, 13.98) },
					RightHip = { rot = Vector3.new(8.24, 0, 3.92), pos = Vector3.new(0, 0.153, 0) },
					LeftHip = { rot = Vector3.new(-3.75, 0, -0.61), pos = Vector3.new(0, 0.144, 0) },
				},
			},
			{
				time = 0.14,
				pose = {
					Root = { rot = Vector3.new(-2, -22, 2), pos = Vector3.new(0.04, -0.12, 0.14) },
					Neck = { rot = Vector3.new(-10.39, -10.13, -10) },
					RightShoulder = { rot = Vector3.new(116.48, 0, -25.23) },
					LeftShoulder = { rot = Vector3.new(93.17, 0, 15.3) },
					RightHip = { rot = Vector3.new(3.89, 0, 3.11), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(-7.62, 0, -1.77), pos = Vector3.new(0, 0.145, 0) },
				},
			},
			{
				time = 0.16,
				pose = {
					Root = { rot = Vector3.new(-2, -23, 2), pos = Vector3.new(0.04, -0.12, 0.14) },
					Neck = { rot = Vector3.new(-10.15, -7.43, -12) },
					RightShoulder = { rot = Vector3.new(119.31, 0, -18.2) },
					LeftShoulder = { rot = Vector3.new(93.25, 0, 14.24) },
					RightHip = { rot = Vector3.new(4.23, 0, 3.04), pos = Vector3.new(0, 0.109, 0) },
					LeftHip = { rot = Vector3.new(-7.87, 0, -1.64), pos = Vector3.new(0, 0.143, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(-2, -24, 2), pos = Vector3.new(0.04, -0.12, 0.14) },
					Neck = { rot = Vector3.new(-7.1, -6.06, -8) },
					RightShoulder = { rot = Vector3.new(114.71, 0, -29.17) },
					LeftShoulder = { rot = Vector3.new(93.35, 0, 13.15) },
					RightHip = { rot = Vector3.new(4.58, 0, 2.97), pos = Vector3.new(0, 0.107, 0) },
					LeftHip = { rot = Vector3.new(-8.1, 0, -1.5), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(0.07, -30.94, 3.48),
						pos = Vector3.new(0.069, -0.135, 0.188),
					},
					Neck = { rot = Vector3.new(-4.68, 10.29, -4.77) },
					RightShoulder = { rot = Vector3.new(142.96, 0, -26.74) },
					LeftShoulder = { rot = Vector3.new(94.65, 0, 3.7) },
					RightHip = { rot = Vector3.new(5.22, 0, 0.27), pos = Vector3.new(0, 0.093, 0) },
					LeftHip = { rot = Vector3.new(-11.38, 0, -2.4), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.217,
				pose = {
					Root = {
						rot = Vector3.new(2.22, -38.08, 4.99),
						pos = Vector3.new(0.099, -0.148, 0.239),
					},
					Neck = { rot = Vector3.new(-3.6, 25.24, -2.01) },
					RightShoulder = { rot = Vector3.new(165.74, 0, -22.27) },
					LeftShoulder = { rot = Vector3.new(96.03, 0, -5.46) },
					RightHip = { rot = Vector3.new(5.91, 0, -2.36), pos = Vector3.new(0, 0.075, 0) },
					LeftHip = { rot = Vector3.new(-12.36, 0, -3.8), pos = Vector3.new(0, 0.302, 0) },
				},
			},
			{
				time = 0.233,
				pose = {
					Root = {
						rot = Vector3.new(4.26, -44.75, 6.44),
						pos = Vector3.new(0.128, -0.163, 0.286),
					},
					Neck = { rot = Vector3.new(-3.91, 36.83, 0.57) },
					RightShoulder = { rot = Vector3.new(189.29, 0, -17.6) },
					LeftShoulder = { rot = Vector3.new(98.16, 0, -14.96) },
					RightHip = { rot = Vector3.new(6.53, 0, -4.77), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(-10.14, 0, -7.5), pos = Vector3.new(0, 0.504, 0) },
				},
			},
			{
				time = 0.249,
				pose = {
					Root = {
						rot = Vector3.new(5.62, -49.09, 7.51),
						pos = Vector3.new(0.149, -0.179, 0.316),
					},
					Neck = { rot = Vector3.new(-3.7, 45.69, 2.6) },
					RightShoulder = { rot = Vector3.new(212.83, 0, -13.48) },
					LeftShoulder = { rot = Vector3.new(101.61, 0, -25.21) },
					RightHip = { rot = Vector3.new(6.88, 0, -6.44), pos = Vector3.new(0, 0.056, 0) },
					LeftHip = {
						rot = Vector3.new(-6.65, 0, -12.89),
						pos = Vector3.new(0, 0.615, 0),
					},
				},
			},
			{
				time = 0.265,
				pose = {
					Root = { rot = Vector3.new(6, -50, 8), pos = Vector3.new(0.16, -0.2, 0.32) },
					Neck = { rot = Vector3.new(-2.02, 50.61, 4) },
					RightShoulder = { rot = Vector3.new(233.07, 0, -9.91) },
					LeftShoulder = { rot = Vector3.new(101.33, 0, -30.08) },
					RightHip = { rot = Vector3.new(6.74, 0, -7.11), pos = Vector3.new(0, 0.068, 0) },
					LeftHip = {
						rot = Vector3.new(-2.24, 0, -18.72),
						pos = Vector3.new(0, 0.591, 0),
					},
				},
			},
			{
				time = 0.285,
				pose = {
					Root = {
						rot = Vector3.new(1.92, -36.13, 6.34),
						pos = Vector3.new(0.128, -0.254, 0.227),
					},
					Neck = { rot = Vector3.new(3.11, 30.8, 2.59) },
					RightShoulder = { rot = Vector3.new(238.64, 0, -4.35) },
					LeftShoulder = { rot = Vector3.new(91, 0, -19.76) },
					RightHip = { rot = Vector3.new(4.97, 0, -4.65), pos = Vector3.new(0, 0.151, 0) },
					LeftHip = {
						rot = Vector3.new(11.98, 0, -21.32),
						pos = Vector3.new(0, 0.444, 0),
					},
				},
			},
			{
				time = 0.305,
				pose = {
					Root = { rot = Vector3.new(-4, -14, 3), pos = Vector3.new(0.07, -0.3, 0.04) },
					Neck = { rot = Vector3.new(9.37, 3.1, 0) },
					RightShoulder = { rot = Vector3.new(234.82, 0, -1) },
					LeftShoulder = { rot = Vector3.new(78.73, 0, -5.42) },
					RightHip = { rot = Vector3.new(0.53, 0, 1.5), pos = Vector3.new(0, 0.262, 0) },
					LeftHip = { rot = Vector3.new(26.85, 0, -9.99), pos = Vector3.new(0, 0.244, 0) },
				},
			},
			{
				time = 0.323,
				pose = {
					Root = {
						rot = Vector3.new(-6.77, 3.94, -0.71),
						pos = Vector3.new(0.023, -0.278, -0.208),
					},
					Neck = { rot = Vector3.new(12.98, -12.4, -0.23) },
					RightShoulder = { rot = Vector3.new(222.26, 0, -6.71) },
					LeftShoulder = { rot = Vector3.new(56.78, 0, -7.05) },
					RightHip = { rot = Vector3.new(-8.76, 0, 6.82), pos = Vector3.new(0, 0.258, 0) },
					LeftHip = { rot = Vector3.new(30.36, 0, 5.07), pos = Vector3.new(0, 0.049, 0) },
				},
			},
			{
				time = 0.34,
				pose = {
					Root = {
						rot = Vector3.new(-9, 18, -4),
						pos = Vector3.new(-0.02, -0.371, -0.45),
					},
					Neck = { rot = Vector3.new(15.05, -25.05, 0) },
					RightShoulder = { rot = Vector3.new(202.84, 0, -15.77) },
					LeftShoulder = { rot = Vector3.new(34.77, 0, -5.45) },
					RightHip = {
						rot = Vector3.new(-17.75, 0, 8.32),
						pos = Vector3.new(0, 0.276, 0),
					},
					LeftHip = { rot = Vector3.new(29.94, 0, 16.93) },
				},
			},
			{
				time = 0.353,
				pose = {
					Root = {
						rot = Vector3.new(-10.97, 21.95, -5.11),
						pos = Vector3.new(-0.043, -0.42, -0.562),
					},
					Neck = { rot = Vector3.new(15.87, -29.46, 0) },
					RightShoulder = { rot = Vector3.new(167.87, 0, -22.92) },
					LeftShoulder = { rot = Vector3.new(15.72, 0, -4.29) },
					RightHip = { rot = Vector3.new(-19.88, 0, 8.8), pos = Vector3.new(0, 0.285, 0) },
					LeftHip = { rot = Vector3.new(30.03, 0, 20.7) },
				},
			},
			{
				time = 0.367,
				pose = {
					Root = {
						rot = Vector3.new(-12.94, 22.84, -5.62),
						pos = Vector3.new(-0.063, -0.443, -0.646),
					},
					Neck = { rot = Vector3.new(15.69, -31.5, 0) },
					RightShoulder = { rot = Vector3.new(132.44, 0, -25.34) },
					LeftShoulder = { rot = Vector3.new(-3.12, 0, -1.22) },
					RightHip = {
						rot = Vector3.new(-19.42, 0, 9.59),
						pos = Vector3.new(0, 0.343, 0),
					},
					LeftHip = { rot = Vector3.new(30.39, 0, 22.39) },
				},
			},
			{
				time = 0.385,
				pose = {
					Root = {
						rot = Vector3.new(-15, 23, -6),
						pos = Vector3.new(-0.08, -0.464, -0.72),
					},
					Neck = { rot = Vector3.new(16.02, -33.1, 0) },
					RightShoulder = { rot = Vector3.new(83.31, 0, -29.65) },
					LeftShoulder = { rot = Vector3.new(-26.49, 0, 5.81) },
					RightHip = {
						rot = Vector3.new(-16.61, 0, 10.4),
						pos = Vector3.new(0, 0.475, 0),
					},
					LeftHip = { rot = Vector3.new(31.08, 0, 23.63) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-16.15, 24.01, -6.37),
						pos = Vector3.new(-0.089, -0.488, -0.761),
					},
					Neck = { rot = Vector3.new(16.45, -34.13, 0) },
					RightShoulder = { rot = Vector3.new(70.81, 0, -31.63) },
					LeftShoulder = { rot = Vector3.new(-30.22, 0, 7.33) },
					RightHip = {
						rot = Vector3.new(-13.79, 0, 10.73),
						pos = Vector3.new(0, 0.596, 0),
					},
					LeftHip = { rot = Vector3.new(31.62, 0, 24.89) },
				},
			},
			{
				time = 0.433,
				pose = {
					Root = {
						rot = Vector3.new(-18.3, 26.1, -7.08),
						pos = Vector3.new(-0.101, -0.54, -0.824),
					},
					Neck = { rot = Vector3.new(16.84, -31.79, 0) },
					RightShoulder = { rot = Vector3.new(54.06, 0, -36.91) },
					LeftShoulder = { rot = Vector3.new(-34, 0, 9.14) },
					RightHip = { rot = Vector3.new(-5.84, 0, 12.28), pos = Vector3.new(0, 0.77, 0) },
					LeftHip = { rot = Vector3.new(33.1, 0, 27.37) },
				},
			},
			{
				time = 0.47,
				pose = {
					Root = { rot = Vector3.new(-19, 26, -7), pos = Vector3.new(-0.1, -0.55, -0.82) },
					Neck = { rot = Vector3.new(15.78, -31.24, 0) },
					RightShoulder = { rot = Vector3.new(37.09, 0, -29.12) },
					LeftShoulder = { rot = Vector3.new(-30.08, 0, 8.11) },
					RightHip = { rot = Vector3.new(2.12, 0, 14.07), pos = Vector3.new(0, 0.729, 0) },
					LeftHip = { rot = Vector3.new(34.36, 0, 27.53) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-17.31, 22.66, -5.64),
						pos = Vector3.new(-0.082, -0.488, -0.731),
					},
					Neck = { rot = Vector3.new(12.07, -22.35, 0) },
					RightShoulder = { rot = Vector3.new(47.82, 0, -37.81) },
					LeftShoulder = { rot = Vector3.new(6.18, 0, -1.54) },
					RightHip = { rot = Vector3.new(4.85, 0, 12.52), pos = Vector3.new(0, 0.637, 0) },
					LeftHip = { rot = Vector3.new(34.25, 0, 23.89) },
				},
			},
			{
				time = 0.533,
				pose = {
					Root = {
						rot = Vector3.new(-14.08, 16.84, -3.42),
						pos = Vector3.new(-0.05, -0.346, -0.573),
					},
					Neck = { rot = Vector3.new(6.89, -9.17, 0) },
					RightShoulder = { rot = Vector3.new(58.44, 0, -34.23) },
					LeftShoulder = { rot = Vector3.new(46.1, 0, 0.2) },
					RightHip = { rot = Vector3.new(8.33, 0, 9.03), pos = Vector3.new(0, 0.46, 0) },
					LeftHip = { rot = Vector3.new(32.3, 0, 17.09) },
				},
			},
			{
				time = 0.56,
				pose = {
					Root = { rot = Vector3.new(-12, 12, -2), pos = Vector3.new(-0.03, -0.3, -0.45) },
					Neck = { rot = Vector3.new(4.65, -1.38, 0) },
					RightShoulder = { rot = Vector3.new(70.67, 0, -31.72) },
					LeftShoulder = { rot = Vector3.new(78.59, 0, 29.44) },
					RightHip = { rot = Vector3.new(11.03, 0, 6.16), pos = Vector3.new(0, 0.376, 0) },
					LeftHip = { rot = Vector3.new(24.42, 0, 10.54), pos = Vector3.new(0, 0.179, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-10.39, 4.45, -0.87),
						pos = Vector3.new(-0.013, -0.227, -0.274),
					},
					Neck = { rot = Vector3.new(4.79, 5.23, 0) },
					RightShoulder = { rot = Vector3.new(87.52, 0, -33.7) },
					LeftShoulder = { rot = Vector3.new(94.61, 0, 36.34) },
					RightHip = { rot = Vector3.new(16.72, 0, 2.89), pos = Vector3.new(0, 0.241, 0) },
					LeftHip = { rot = Vector3.new(11.29, 0, 3.72), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.633,
				pose = {
					Root = {
						rot = Vector3.new(-9.55, -1.9, -0.31),
						pos = Vector3.new(-0.005, -0.151, -0.133),
					},
					Neck = { rot = Vector3.new(5.27, 9.11, 0) },
					RightShoulder = { rot = Vector3.new(101.34, 0, -35.8) },
					LeftShoulder = { rot = Vector3.new(104.81, 0, 37.75) },
					RightHip = { rot = Vector3.new(20.65, 0, -0.1), pos = Vector3.new(0, 0.118, 0) },
					LeftHip = { rot = Vector3.new(3.3, 0, 1.03), pos = Vector3.new(0, 0.183, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = { rot = Vector3.new(-9, -6, 0), pos = Vector3.new(0, -0.1, -0.05) },
					Neck = { rot = Vector3.new(5.33, 10.9, 0) },
					RightShoulder = { rot = Vector3.new(109.07, 0, -36.55) },
					LeftShoulder = { rot = Vector3.new(111.02, 0, 38.18) },
					RightHip = {
						rot = Vector3.new(15.13, 0, -1.59),
						pos = Vector3.new(0, 0.126, 0),
					},
					LeftHip = { rot = Vector3.new(1.13, 0, 0.12), pos = Vector3.new(0, 0.092, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = {
						rot = Vector3.new(-8.32, -10.06, 0.13),
						pos = Vector3.new(0.002, -0.039, 0),
					},
					Neck = { rot = Vector3.new(5.48, 11.43, 0) },
					RightShoulder = { rot = Vector3.new(112.32, 0, -36.57) },
					LeftShoulder = { rot = Vector3.new(114.98, 0, 37.96) },
					RightHip = { rot = Vector3.new(2.47, 0, -0.74), pos = Vector3.new(0, 0.065, 0) },
					LeftHip = { rot = Vector3.new(0.78, 0, -0.29), pos = Vector3.new(0, 0.043, 0) },
				},
			},
			{
				time = 0.733,
				pose = {
					Root = {
						rot = Vector3.new(-8.04, -11.78, 0.03),
						pos = Vector3.new(0, -0.005, 0.001),
					},
					Neck = { rot = Vector3.new(5.82, 10.8, 0) },
					RightShoulder = { rot = Vector3.new(111.33, 0, -36.51) },
					LeftShoulder = { rot = Vector3.new(115.11, 0, 37.17) },
					RightHip = { rot = Vector3.new(0.04, 0, -0.07), pos = Vector3.new(0, 0.005, 0) },
					LeftHip = { rot = Vector3.new(0.12, 0, -0.06), pos = Vector3.new(0, 0.006, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
		},
	},
	Rift_FlaskBomb = {
		length = 0.8,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
			{
				time = 0.017,
				pose = {
					Root = {
						rot = Vector3.new(-9.5, -14.18, -1.07),
						pos = Vector3.new(0.009, -0.025, 0.007),
					},
					Neck = { rot = Vector3.new(2.02, 8.02, 0.22) },
					RightShoulder = { rot = Vector3.new(83.08, 0, -33.79) },
					LeftShoulder = { rot = Vector3.new(115.74, 0, 33.31) },
					RightHip = { rot = Vector3.new(2.74, 0, 0.74), pos = Vector3.new(0, 0.038, 0) },
					LeftHip = { rot = Vector3.new(1.64, 0, 0.77), pos = Vector3.new(0, 0.012, 0) },
				},
			},
			{
				time = 0.025,
				pose = {
					Root = {
						rot = Vector3.new(-10.99, -16.4, -2.14),
						pos = Vector3.new(0.019, -0.05, 0.015),
					},
					Neck = { rot = Vector3.new(-1.91, 6.13, 0.4) },
					RightShoulder = { rot = Vector3.new(68.83, 0, -26.97) },
					LeftShoulder = { rot = Vector3.new(116.4, 0, 29.45) },
					RightHip = { rot = Vector3.new(5.37, 0, 1.26), pos = Vector3.new(0, 0.071, 0) },
					LeftHip = { rot = Vector3.new(3.18, 0, 1.38), pos = Vector3.new(0, 0.027, 0) },
				},
			},
			{
				time = 0.033,
				pose = {
					Root = {
						rot = Vector3.new(-12.63, -18.95, -3.33),
						pos = Vector3.new(0.03, -0.079, 0.024),
					},
					Neck = { rot = Vector3.new(-6.3, 4.06, 0.56) },
					RightShoulder = { rot = Vector3.new(55.23, 0, -14.22) },
					LeftShoulder = { rot = Vector3.new(117.02, 0, 24.96) },
					RightHip = { rot = Vector3.new(8.17, 0, 1.59), pos = Vector3.new(0, 0.106, 0) },
					LeftHip = { rot = Vector3.new(4.74, 0, 1.85), pos = Vector3.new(0, 0.047, 0) },
				},
			},
			{
				time = 0.041,
				pose = {
					Root = {
						rot = Vector3.new(-14.04, -21.28, -4.37),
						pos = Vector3.new(0.04, -0.106, 0.034),
					},
					Neck = { rot = Vector3.new(-10.21, 2.22, 0.63) },
					RightShoulder = { rot = Vector3.new(42.98, 0, -4.88) },
					LeftShoulder = { rot = Vector3.new(117.41, 0, 20.83) },
					RightHip = { rot = Vector3.new(10.54, 0, 1.76), pos = Vector3.new(0, 0.147, 0) },
					LeftHip = { rot = Vector3.new(5.93, 0, 2.09), pos = Vector3.new(0, 0.067, 0) },
				},
			},
			{
				time = 0.048,
				pose = {
					Root = {
						rot = Vector3.new(-15.21, -23.41, -5.26),
						pos = Vector3.new(0.049, -0.13, 0.043),
					},
					Neck = { rot = Vector3.new(-13.66, 0.57, 0.59) },
					RightShoulder = { rot = Vector3.new(29.14, 0, -3.62) },
					LeftShoulder = { rot = Vector3.new(117.53, 0, 17.06) },
					RightHip = { rot = Vector3.new(12.59, 0, 1.85), pos = Vector3.new(0, 0.192, 0) },
					LeftHip = { rot = Vector3.new(6.76, 0, 2.16), pos = Vector3.new(0, 0.089, 0) },
				},
			},
			{
				time = 0.064,
				pose = {
					Root = { rot = Vector3.new(-16, -26, -6), pos = Vector3.new(0.06, -0.16, 0.06) },
					Neck = { rot = Vector3.new(-17.42, -1.48, 0) },
					RightShoulder = { rot = Vector3.new(6.91, 0, -9.95) },
					LeftShoulder = { rot = Vector3.new(116.46, 0, 12.32) },
					RightHip = { rot = Vector3.new(14.78, 0, 2.07), pos = Vector3.new(0, 0.264, 0) },
					LeftHip = { rot = Vector3.new(6.92, 0, 1.95), pos = Vector3.new(0, 0.121, 0) },
				},
			},
			{
				time = 0.082,
				pose = {
					Root = {
						rot = Vector3.new(-14.21, -26.33, -5.1),
						pos = Vector3.new(0.061, -0.165, 0.078),
					},
					Neck = { rot = Vector3.new(-17.18, -2.79, -1.64) },
					RightShoulder = { rot = Vector3.new(27.71, 0, 0.22) },
					LeftShoulder = { rot = Vector3.new(112.6, 0, 10.97) },
					RightHip = { rot = Vector3.new(14.52, 0, 2.82), pos = Vector3.new(0, 0.298, 0) },
					LeftHip = { rot = Vector3.new(4.93, 0, 1.52), pos = Vector3.new(0, 0.135, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-10.96, -25.36, -3.28),
						pos = Vector3.new(0.057, -0.154, 0.096),
					},
					Neck = { rot = Vector3.new(-15.77, -5.24, -3.85) },
					RightShoulder = { rot = Vector3.new(54.58, 0, -2.09) },
					LeftShoulder = { rot = Vector3.new(107.03, 0, 11.61) },
					RightHip = { rot = Vector3.new(12.71, 0, 3.65), pos = Vector3.new(0, 0.267, 0) },
					LeftHip = { rot = Vector3.new(1.69, 0, 0.88), pos = Vector3.new(0, 0.139, 0) },
				},
			},
			{
				time = 0.117,
				pose = {
					Root = {
						rot = Vector3.new(-7.48, -23.97, -1.26),
						pos = Vector3.new(0.05, -0.14, 0.112),
					},
					Neck = { rot = Vector3.new(-14.03, -7.83, -6.08) },
					RightShoulder = { rot = Vector3.new(75.99, 0, -17.89) },
					LeftShoulder = { rot = Vector3.new(101.46, 0, 13.09) },
					RightHip = { rot = Vector3.new(9.97, 0, 4.04), pos = Vector3.new(0, 0.198, 0) },
					LeftHip = { rot = Vector3.new(-1.83, 0, 0.04), pos = Vector3.new(0, 0.139, 0) },
				},
			},
			{
				time = 0.133,
				pose = {
					Root = {
						rot = Vector3.new(-4.19, -22.65, 0.68),
						pos = Vector3.new(0.044, -0.126, 0.128),
					},
					Neck = { rot = Vector3.new(-11.93, -9.63, -8.28) },
					RightShoulder = { rot = Vector3.new(99.32, 0, -23.97) },
					LeftShoulder = { rot = Vector3.new(96.41, 0, 14.61) },
					RightHip = { rot = Vector3.new(6.57, 0, 3.78), pos = Vector3.new(0, 0.128, 0) },
					LeftHip = { rot = Vector3.new(-5.27, 0, -0.98), pos = Vector3.new(0, 0.141, 0) },
				},
			},
			{
				time = 0.148,
				pose = {
					Root = { rot = Vector3.new(-2, -22, 2), pos = Vector3.new(0.04, -0.12, 0.14) },
					Neck = { rot = Vector3.new(-10.13, -10.12, -10) },
					RightShoulder = { rot = Vector3.new(116.51, 0, -25.23) },
					LeftShoulder = { rot = Vector3.new(93.16, 0, 15.3) },
					RightHip = { rot = Vector3.new(3.88, 0, 3.11), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(-7.63, 0, -1.77), pos = Vector3.new(0, 0.145, 0) },
				},
			},
			{
				time = 0.167,
				pose = {
					Root = {
						rot = Vector3.new(-2.57, -21.96, 2.02),
						pos = Vector3.new(0.035, -0.136, 0.143),
					},
					Neck = { rot = Vector3.new(-10.94, -10.51, -12.05) },
					RightShoulder = { rot = Vector3.new(109.96, 0, -26.08) },
					LeftShoulder = { rot = Vector3.new(94.52, 0, 15.56) },
					RightHip = { rot = Vector3.new(4.72, 0, 2.9), pos = Vector3.new(0, 0.121, 0) },
					LeftHip = { rot = Vector3.new(-6.76, 0, -1.99), pos = Vector3.new(0, 0.166, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(-3, -24, 2), pos = Vector3.new(0.04, -0.15, 0.15) },
					Neck = { rot = Vector3.new(-11.08, -6.28, -12) },
					RightShoulder = { rot = Vector3.new(106.36, 0, -25.84) },
					LeftShoulder = { rot = Vector3.new(96.66, 0, 13.31) },
					RightHip = { rot = Vector3.new(6.12, 0, 2.32), pos = Vector3.new(0, 0.127, 0) },
					LeftHip = { rot = Vector3.new(-6.55, 0, -2.15), pos = Vector3.new(0, 0.183, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-1.04, -31.21, 3.18),
						pos = Vector3.new(0.063, -0.16, 0.187),
					},
					Neck = { rot = Vector3.new(-8.71, 9.14, -9.26) },
					RightShoulder = { rot = Vector3.new(131.12, 0, -23.01) },
					LeftShoulder = { rot = Vector3.new(97.67, 0, 4.16) },
					RightHip = { rot = Vector3.new(6.75, 0, 0.06), pos = Vector3.new(0, 0.111, 0) },
					LeftHip = { rot = Vector3.new(-10.01, 0, -2.53), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.217,
				pose = {
					Root = {
						rot = Vector3.new(1.16, -38.85, 4.42),
						pos = Vector3.new(0.088, -0.165, 0.228),
					},
					Neck = { rot = Vector3.new(-6.92, 23.33, -6.33) },
					RightShoulder = { rot = Vector3.new(152.35, 0, -19.89) },
					LeftShoulder = { rot = Vector3.new(98.26, 0, -5.3) },
					RightHip = { rot = Vector3.new(7.32, 0, -2.09), pos = Vector3.new(0, 0.092, 0) },
					LeftHip = {
						rot = Vector3.new(-13.38, 0, -2.22),
						pos = Vector3.new(0, 0.199, 0),
					},
				},
			},
			{
				time = 0.233,
				pose = {
					Root = {
						rot = Vector3.new(3.47, -46.65, 5.71),
						pos = Vector3.new(0.113, -0.17, 0.269),
					},
					Neck = { rot = Vector3.new(-6.45, 34.83, -3.15) },
					RightShoulder = { rot = Vector3.new(173.14, 0, -16.62) },
					LeftShoulder = { rot = Vector3.new(99.03, 0, -14.27) },
					RightHip = { rot = Vector3.new(7.9, 0, -4.08), pos = Vector3.new(0, 0.073, 0) },
					LeftHip = {
						rot = Vector3.new(-13.72, 0, -3.36),
						pos = Vector3.new(0, 0.347, 0),
					},
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(5.5, -53.27, 6.86),
						pos = Vector3.new(0.136, -0.177, 0.303),
					},
					Neck = { rot = Vector3.new(-6.2, 45.22, -0.1) },
					RightShoulder = { rot = Vector3.new(194.39, 0, -13.54) },
					LeftShoulder = { rot = Vector3.new(101.55, 0, -25.3) },
					RightHip = { rot = Vector3.new(8.42, 0, -5.63), pos = Vector3.new(0, 0.061, 0) },
					LeftHip = {
						rot = Vector3.new(-11.53, 0, -7.22),
						pos = Vector3.new(0, 0.519, 0),
					},
				},
			},
			{
				time = 0.267,
				pose = {
					Root = {
						rot = Vector3.new(6.86, -57.4, 7.69),
						pos = Vector3.new(0.153, -0.188, 0.321),
					},
					Neck = { rot = Vector3.new(-4.32, 53.06, 2.48) },
					RightShoulder = { rot = Vector3.new(217.19, 0, -11.37) },
					LeftShoulder = { rot = Vector3.new(104.38, 0, -35.39) },
					RightHip = { rot = Vector3.new(8.66, 0, -6.55), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = {
						rot = Vector3.new(-8.39, 0, -13.19),
						pos = Vector3.new(0, 0.598, 0),
					},
				},
			},
			{
				time = 0.281,
				pose = {
					Root = { rot = Vector3.new(7.2, -58, 8), pos = Vector3.new(0.16, -0.2, 0.32) },
					Neck = { rot = Vector3.new(-2.22, 56.59, 4) },
					RightShoulder = { rot = Vector3.new(233.08, 0, -9.91) },
					LeftShoulder = { rot = Vector3.new(102.81, 0, -38.63) },
					RightHip = { rot = Vector3.new(8.44, 0, -6.74), pos = Vector3.new(0, 0.071, 0) },
					LeftHip = {
						rot = Vector3.new(-5.13, 0, -18.68),
						pos = Vector3.new(0, 0.563, 0),
					},
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(3.35, -43.3, 6.58),
						pos = Vector3.new(0.133, -0.247, 0.24),
					},
					Neck = { rot = Vector3.new(2.91, 35.66, 2.97) },
					RightShoulder = { rot = Vector3.new(238.29, 0, -5) },
					LeftShoulder = { rot = Vector3.new(91.65, 0, -26.49) },
					RightHip = { rot = Vector3.new(6.02, 0, -4.72), pos = Vector3.new(0, 0.144, 0) },
					LeftHip = { rot = Vector3.new(8.85, 0, -23.51), pos = Vector3.new(0, 0.447, 0) },
				},
			},
			{
				time = 0.311,
				pose = {
					Root = {
						rot = Vector3.new(-0.6, -28.13, 4.85),
						pos = Vector3.new(0.101, -0.28, 0.148),
					},
					Neck = { rot = Vector3.new(6.74, 14.91, 1.22) },
					RightShoulder = { rot = Vector3.new(237.85, 0, -2.07) },
					LeftShoulder = { rot = Vector3.new(85.02, 0, -14.28) },
					RightHip = { rot = Vector3.new(3.68, 0, -1.85), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = {
						rot = Vector3.new(21.27, 0, -19.35),
						pos = Vector3.new(0, 0.321, 0),
					},
				},
			},
			{
				time = 0.323,
				pose = {
					Root = { rot = Vector3.new(-4, -14, 3), pos = Vector3.new(0.07, -0.3, 0.04) },
					Neck = { rot = Vector3.new(10.22, 3.11, 0) },
					RightShoulder = { rot = Vector3.new(234.82, 0, -0.99) },
					LeftShoulder = { rot = Vector3.new(78.71, 0, -5.4) },
					RightHip = { rot = Vector3.new(0.53, 0, 1.51), pos = Vector3.new(0, 0.262, 0) },
					LeftHip = {
						rot = Vector3.new(29.91, 0, -10.64),
						pos = Vector3.new(0, 0.202, 0),
					},
				},
			},
			{
				time = 0.342,
				pose = {
					Root = {
						rot = Vector3.new(-7.7, 7.62, -0.72),
						pos = Vector3.new(0.023, -0.319, -0.209),
					},
					Neck = { rot = Vector3.new(13.89, -12.8, -0.23) },
					RightShoulder = { rot = Vector3.new(222.19, 0, -6.74) },
					LeftShoulder = { rot = Vector3.new(56.72, 0, -7.05) },
					RightHip = { rot = Vector3.new(-8.97, 0, 6.38), pos = Vector3.new(0, 0.291, 0) },
					LeftHip = { rot = Vector3.new(36.11, 0, 7.34) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-10.8, 24, -4),
						pos = Vector3.new(-0.02, -0.522, -0.45),
					},
					Neck = { rot = Vector3.new(15.04, -25.04, 0) },
					RightShoulder = { rot = Vector3.new(202.84, 0, -15.77) },
					LeftShoulder = { rot = Vector3.new(34.77, 0, -5.45) },
					RightHip = { rot = Vector3.new(-18.02, 0, 6.79), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(37.64, 0, 21.53) },
				},
			},
			{
				time = 0.384,
				pose = {
					Root = {
						rot = Vector3.new(-14.86, 28.14, -5.5),
						pos = Vector3.new(-0.057, -0.597, -0.62),
					},
					Neck = { rot = Vector3.new(16.75, -31.02, 0) },
					RightShoulder = { rot = Vector3.new(144.18, 0, -26.88) },
					LeftShoulder = { rot = Vector3.new(3.13, 0, -2.54) },
					RightHip = {
						rot = Vector3.new(-19.26, 0, 8.12),
						pos = Vector3.new(0, 0.457, 0),
					},
					LeftHip = { rot = Vector3.new(39.09, 0, 26.8) },
				},
			},
			{
				time = 0.408,
				pose = {
					Root = {
						rot = Vector3.new(-18, 27, -6),
						pos = Vector3.new(-0.08, -0.598, -0.72),
					},
					Neck = { rot = Vector3.new(17.07, -33.1, 0) },
					RightShoulder = { rot = Vector3.new(83.34, 0, -29.66) },
					LeftShoulder = { rot = Vector3.new(-26.47, 0, 5.81) },
					RightHip = {
						rot = Vector3.new(-15.38, 0, 10.06),
						pos = Vector3.new(0, 0.602, 0),
					},
					LeftHip = { rot = Vector3.new(40.19, 0, 27.64) },
				},
			},
			{
				time = 0.421,
				pose = {
					Root = {
						rot = Vector3.new(-19.09, 27.67, -6.28),
						pos = Vector3.new(-0.087, -0.616, -0.759),
					},
					Neck = { rot = Vector3.new(17.12, -32.02, 0) },
					RightShoulder = { rot = Vector3.new(73, 0, -31.11) },
					LeftShoulder = { rot = Vector3.new(-29.51, 0, 7.03) },
					RightHip = {
						rot = Vector3.new(-13.35, 0, 10.43),
						pos = Vector3.new(0, 0.695, 0),
					},
					LeftHip = { rot = Vector3.new(40.68, 0, 28.61) },
				},
			},
			{
				time = 0.433,
				pose = {
					Root = {
						rot = Vector3.new(-20.18, 28.52, -6.57),
						pos = Vector3.new(-0.093, -0.636, -0.797),
					},
					Neck = { rot = Vector3.new(17.26, -28.86, 0) },
					RightShoulder = { rot = Vector3.new(66.07, 0, -33.08) },
					LeftShoulder = { rot = Vector3.new(-31.74, 0, 8) },
					RightHip = {
						rot = Vector3.new(-11.02, 0, 10.89),
						pos = Vector3.new(0, 0.78, 0),
					},
					LeftHip = { rot = Vector3.new(41.18, 0, 29.64) },
				},
			},
			{
				time = 0.467,
				pose = {
					Root = {
						rot = Vector3.new(-22.46, 30.51, -7.15),
						pos = Vector3.new(-0.102, -0.681, -0.875),
					},
					Neck = { rot = Vector3.new(17.06, -32.19, 0) },
					RightShoulder = { rot = Vector3.new(51.2, 0, -37.59) },
					LeftShoulder = { rot = Vector3.new(-33.99, 0, 9.21) },
					RightHip = {
						rot = Vector3.new(-4.01, 0, 12.83),
						pos = Vector3.new(0, 0.904, 0),
					},
					LeftHip = { rot = Vector3.new(42.31, 0, 31.79) },
				},
			},
			{
				time = 0.499,
				pose = {
					Root = {
						rot = Vector3.new(-22.8, 30, -7),
						pos = Vector3.new(-0.1, -0.676, -0.88),
					},
					Neck = { rot = Vector3.new(15.84, -31.09, 0) },
					RightShoulder = { rot = Vector3.new(37.09, 0, -29.1) },
					LeftShoulder = { rot = Vector3.new(-30.08, 0, 8.11) },
					RightHip = { rot = Vector3.new(2.11, 0, 14.53), pos = Vector3.new(0, 0.855, 0) },
					LeftHip = { rot = Vector3.new(42.59, 0, 31.4) },
				},
			},
			{
				time = 0.533,
				pose = {
					Root = {
						rot = Vector3.new(-19.82, 25.15, -5.55),
						pos = Vector3.new(-0.08, -0.58, -0.77),
					},
					Neck = { rot = Vector3.new(10.96, -20.78, 0) },
					RightShoulder = { rot = Vector3.new(48.33, 0, -37.7) },
					LeftShoulder = { rot = Vector3.new(7.9, 0, -1.8) },
					RightHip = { rot = Vector3.new(5.04, 0, 12.79), pos = Vector3.new(0, 0.733, 0) },
					LeftHip = { rot = Vector3.new(40.9, 0, 26.44) },
				},
			},
			{
				time = 0.55,
				pose = {
					Root = {
						rot = Vector3.new(-17.52, 21.69, -4.52),
						pos = Vector3.new(-0.066, -0.513, -0.685),
					},
					Neck = { rot = Vector3.new(7.97, -14.12, 0) },
					RightShoulder = { rot = Vector3.new(53.26, 0, -36.4) },
					LeftShoulder = { rot = Vector3.new(26.63, 0, -4.36) },
					RightHip = { rot = Vector3.new(6.52, 0, 11.07), pos = Vector3.new(0, 0.651, 0) },
					LeftHip = { rot = Vector3.new(39.47, 0, 22.76) },
				},
			},
			{
				time = 0.567,
				pose = {
					Root = {
						rot = Vector3.new(-15.16, 18, -3.46),
						pos = Vector3.new(-0.051, -0.402, -0.594),
					},
					Neck = { rot = Vector3.new(5.35, -7.79, 0) },
					RightShoulder = { rot = Vector3.new(58.21, 0, -34.33) },
					LeftShoulder = { rot = Vector3.new(45.27, 0, -0.35) },
					RightHip = { rot = Vector3.new(8.32, 0, 9.29), pos = Vector3.new(0, 0.519, 0) },
					LeftHip = { rot = Vector3.new(36.84, 0, 18.5) },
				},
			},
			{
				time = 0.581,
				pose = {
					Root = {
						rot = Vector3.new(-13.33, 14.84, -2.63),
						pos = Vector3.new(-0.039, -0.319, -0.517),
					},
					Neck = { rot = Vector3.new(3.78, -3.21, 0) },
					RightShoulder = { rot = Vector3.new(64.79, 0, -32.47) },
					LeftShoulder = { rot = Vector3.new(64.89, 0, 16.34) },
					RightHip = { rot = Vector3.new(9.81, 0, 7.65), pos = Vector3.new(0, 0.416, 0) },
					LeftHip = { rot = Vector3.new(32.77, 0, 14.73), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.596,
				pose = {
					Root = { rot = Vector3.new(-12, 12, -2), pos = Vector3.new(-0.03, -0.3, -0.45) },
					Neck = { rot = Vector3.new(3.2, -0.29, 0) },
					RightShoulder = { rot = Vector3.new(70.69, 0, -31.71) },
					LeftShoulder = { rot = Vector3.new(78.65, 0, 29.49) },
					RightHip = { rot = Vector3.new(11.04, 0, 6.15), pos = Vector3.new(0, 0.376, 0) },
					LeftHip = { rot = Vector3.new(27.13, 0, 11.01), pos = Vector3.new(0, 0.151, 0) },
				},
			},
			{
				time = 0.633,
				pose = {
					Root = {
						rot = Vector3.new(-10.26, 5.2, -0.98),
						pos = Vector3.new(-0.015, -0.235, -0.293),
					},
					Neck = { rot = Vector3.new(4.18, 4.82, 0) },
					RightShoulder = { rot = Vector3.new(85.17, 0, -33.33) },
					LeftShoulder = { rot = Vector3.new(92.76, 0, 35.86) },
					RightHip = { rot = Vector3.new(15.7, 0, 3.24), pos = Vector3.new(0, 0.258, 0) },
					LeftHip = { rot = Vector3.new(13.93, 0, 4.42), pos = Vector3.new(0, 0.289, 0) },
				},
			},
			{
				time = 0.667,
				pose = {
					Root = {
						rot = Vector3.new(-9.57, -0.71, -0.41),
						pos = Vector3.new(-0.006, -0.166, -0.16),
					},
					Neck = { rot = Vector3.new(5.27, 8.06, 0) },
					RightShoulder = { rot = Vector3.new(98.5, 0, -35.41) },
					LeftShoulder = { rot = Vector3.new(102.72, 0, 37.6) },
					RightHip = { rot = Vector3.new(20.56, 0, 0.51), pos = Vector3.new(0, 0.129, 0) },
					LeftHip = { rot = Vector3.new(4.94, 0, 1.41), pos = Vector3.new(0, 0.216, 0) },
				},
			},
			{
				time = 0.703,
				pose = {
					Root = { rot = Vector3.new(-9, -6, 0), pos = Vector3.new(0, -0.1, -0.05) },
					Neck = { rot = Vector3.new(5.5, 10.42, 0) },
					RightShoulder = { rot = Vector3.new(109.06, 0, -36.55) },
					LeftShoulder = { rot = Vector3.new(111.01, 0, 38.18) },
					RightHip = {
						rot = Vector3.new(15.14, 0, -1.59),
						pos = Vector3.new(0, 0.126, 0),
					},
					LeftHip = { rot = Vector3.new(1.14, 0, 0.12), pos = Vector3.new(0, 0.092, 0) },
				},
			},
			{
				time = 0.733,
				pose = {
					Root = {
						rot = Vector3.new(-8.49, -9.05, 0.14),
						pos = Vector3.new(0.002, -0.056, -0.007),
					},
					Neck = { rot = Vector3.new(5.49, 11.12, 0) },
					RightShoulder = { rot = Vector3.new(112.15, 0, -36.59) },
					LeftShoulder = { rot = Vector3.new(114.41, 0, 38.21) },
					RightHip = { rot = Vector3.new(5.77, 0, -1.24), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(1.01, 0, -0.29), pos = Vector3.new(0, 0.059, 0) },
				},
			},
			{
				time = 0.767,
				pose = {
					Root = {
						rot = Vector3.new(-8.13, -11.24, 0.07),
						pos = Vector3.new(0.001, -0.016, 0.003),
					},
					Neck = { rot = Vector3.new(5.69, 10.99, 0) },
					RightShoulder = { rot = Vector3.new(111.87, 0, -36.54) },
					LeftShoulder = { rot = Vector3.new(115.21, 0, 37.48) },
					RightHip = { rot = Vector3.new(0.04, 0, -0.19), pos = Vector3.new(0, 0.015, 0) },
					LeftHip = { rot = Vector3.new(0.38, 0, -0.18), pos = Vector3.new(0, 0.019, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
		},
	},
	Rift_RayGun = {
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
				},
			},
			{
				time = 0.017,
				pose = {
					Root = {
						rot = Vector3.new(-8.06, -10.34, 0),
						pos = Vector3.new(0.005, -0.011, 0.004),
					},
					Neck = { rot = Vector3.new(4.5, 8.39, 0) },
					RightShoulder = { rot = Vector3.new(92.38, 0, -36.93) },
					LeftShoulder = { rot = Vector3.new(113.91, 0, 37.69) },
					RightHip = {
						rot = Vector3.new(-0.27, 0, -0.17),
						pos = Vector3.new(0, 0.011, 0),
					},
					LeftHip = { rot = Vector3.new(0.54, 0, -0.15), pos = Vector3.new(0, 0.013, 0) },
				},
			},
			{
				time = 0.033,
				pose = {
					Root = {
						rot = Vector3.new(-8.19, -6.12, 0),
						pos = Vector3.new(0.017, -0.039, 0.014),
					},
					Neck = { rot = Vector3.new(0.98, 3.86, 0) },
					RightShoulder = { rot = Vector3.new(69.03, 0, -31.69) },
					LeftShoulder = { rot = Vector3.new(110.86, 0, 39.31) },
					RightHip = {
						rot = Vector3.new(-0.99, 0, -0.61),
						pos = Vector3.new(0, 0.035, 0),
					},
					LeftHip = { rot = Vector3.new(1.92, 0, -0.45), pos = Vector3.new(0, 0.044, 0) },
				},
			},
			{
				time = 0.067,
				pose = {
					Root = {
						rot = Vector3.new(-8.22, 5.66, 0),
						pos = Vector3.new(0.049, -0.104, 0.041),
					},
					Neck = { rot = Vector3.new(-6.67, -9.22, 0) },
					RightShoulder = { rot = Vector3.new(27.18, 0, -16.47) },
					LeftShoulder = { rot = Vector3.new(99.75, 0, 42.54) },
					RightHip = {
						rot = Vector3.new(-3.16, 0, -1.97),
						pos = Vector3.new(0, 0.087, 0),
					},
					LeftHip = { rot = Vector3.new(4.23, 0, -0.6), pos = Vector3.new(0, 0.163, 0) },
				},
			},
			{
				time = 0.08,
				pose = {
					Root = { rot = Vector3.new(-8, 10, 0), pos = Vector3.new(0.06, -0.12, 0.05) },
					Neck = { rot = Vector3.new(-8.01, -13.39, 0) },
					RightShoulder = { rot = Vector3.new(13.61, 0, -12.55) },
					LeftShoulder = { rot = Vector3.new(93.71, 0, 42.73) },
					RightHip = {
						rot = Vector3.new(-4.18, 0, -2.59),
						pos = Vector3.new(0, 0.096, 0),
					},
					LeftHip = { rot = Vector3.new(4.09, 0, -0.63), pos = Vector3.new(0, 0.208, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-7.31, 16.28, 0),
						pos = Vector3.new(0.074, -0.13, 0.062),
					},
					Neck = { rot = Vector3.new(-7.61, -19.63, 0) },
					RightShoulder = { rot = Vector3.new(22.38, 0, -9.51) },
					LeftShoulder = { rot = Vector3.new(73.43, 0, 39.03) },
					RightHip = {
						rot = Vector3.new(-4.33, 0, -3.52),
						pos = Vector3.new(0, 0.153, 0),
					},
					LeftHip = { rot = Vector3.new(3.17, 0, -0.97), pos = Vector3.new(0, 0.235, 0) },
				},
			},
			{
				time = 0.117,
				pose = {
					Root = {
						rot = Vector3.new(-6.51, 21.84, 0),
						pos = Vector3.new(0.086, -0.132, 0.072),
					},
					Neck = { rot = Vector3.new(-6.07, -25.2, 0) },
					RightShoulder = { rot = Vector3.new(36.9, 0, -0.86) },
					LeftShoulder = { rot = Vector3.new(57.56, 0, 28.35) },
					RightHip = {
						rot = Vector3.new(-2.51, 0, -3.86),
						pos = Vector3.new(0, 0.219, 0),
					},
					LeftHip = { rot = Vector3.new(2.44, 0, -1.59), pos = Vector3.new(0, 0.219, 0) },
				},
			},
			{
				time = 0.133,
				pose = {
					Root = {
						rot = Vector3.new(-5.62, 27.41, 0),
						pos = Vector3.new(0.098, -0.132, 0.082),
					},
					Neck = { rot = Vector3.new(-3.95, -30.8, 0) },
					RightShoulder = { rot = Vector3.new(49.83, 0, 6.21) },
					LeftShoulder = { rot = Vector3.new(40.66, 0, 8.6) },
					RightHip = { rot = Vector3.new(0.42, 0, -3.37), pos = Vector3.new(0, 0.267, 0) },
					LeftHip = { rot = Vector3.new(2.05, 0, -2.42), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.152,
				pose = {
					Root = {
						rot = Vector3.new(-4.71, 33.11, 0),
						pos = Vector3.new(0.109, -0.13, 0.092),
					},
					Neck = { rot = Vector3.new(-1.59, -36.57, 0) },
					RightShoulder = { rot = Vector3.new(67.39, 0, 13.17) },
					LeftShoulder = { rot = Vector3.new(22.71, 0, 2.74) },
					RightHip = { rot = Vector3.new(3.98, 0, -1.83), pos = Vector3.new(0, 0.274, 0) },
					LeftHip = { rot = Vector3.new(2.29, 0, -3.29), pos = Vector3.new(0, 0.134, 0) },
				},
			},
			{
				time = 0.17,
				pose = {
					Root = { rot = Vector3.new(-4, 38, 0), pos = Vector3.new(0.12, -0.13, 0.1) },
					Neck = { rot = Vector3.new(0.21, -41.56, 0) },
					RightShoulder = { rot = Vector3.new(81.38, 0, 17.4) },
					LeftShoulder = { rot = Vector3.new(6.89, 0, 7.19) },
					RightHip = { rot = Vector3.new(7.01, 0, 0.3), pos = Vector3.new(0, 0.236, 0) },
					LeftHip = { rot = Vector3.new(3.26, 0, -3.78), pos = Vector3.new(0, 0.127, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-3.39, 43.99, 0),
						pos = Vector3.new(0.134, -0.134, 0.11),
					},
					Neck = { rot = Vector3.new(1.69, -47.81, 0) },
					RightShoulder = { rot = Vector3.new(89.92, 0, 22.55) },
					LeftShoulder = { rot = Vector3.new(-5.57, 0, 10.87) },
					RightHip = { rot = Vector3.new(8.6, 0, 2.61), pos = Vector3.new(0, 0.164, 0) },
					LeftHip = { rot = Vector3.new(4.96, 0, -4.05), pos = Vector3.new(0, 0.133, 0) },
				},
			},
			{
				time = 0.233,
				pose = {
					Root = {
						rot = Vector3.new(-3.1, 48.46, 0),
						pos = Vector3.new(0.146, -0.139, 0.117),
					},
					Neck = { rot = Vector3.new(2.39, -51.62, 0) },
					RightShoulder = { rot = Vector3.new(94.06, 0, 28.09) },
					LeftShoulder = { rot = Vector3.new(-15.74, 0, 12.01) },
					RightHip = { rot = Vector3.new(7.38, 0, 2.86), pos = Vector3.new(0, 0.174, 0) },
					LeftHip = { rot = Vector3.new(6.48, 0, -3.98), pos = Vector3.new(0, 0.133, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = { rot = Vector3.new(-3, 50, 0), pos = Vector3.new(0.15, -0.14, 0.12) },
					Neck = { rot = Vector3.new(2.54, -52.03, 0) },
					RightShoulder = { rot = Vector3.new(95.76, 0, 29.95) },
					LeftShoulder = { rot = Vector3.new(-19.17, 0, 12.2) },
					RightHip = { rot = Vector3.new(6.95, 0, 2.93), pos = Vector3.new(0, 0.177, 0) },
					LeftHip = { rot = Vector3.new(7.01, 0, -3.93), pos = Vector3.new(0, 0.133, 0) },
				},
			},
			{
				time = 0.267,
				pose = {
					Root = {
						rot = Vector3.new(-2.94, 50.77, 0),
						pos = Vector3.new(0.152, -0.141, 0.121),
					},
					Neck = { rot = Vector3.new(2.55, -51.8, 0) },
					RightShoulder = { rot = Vector3.new(96.9, 0, 30.68) },
					LeftShoulder = { rot = Vector3.new(-20.75, 0, 12.29) },
					RightHip = { rot = Vector3.new(6.72, 0, 2.94), pos = Vector3.new(0, 0.178, 0) },
					LeftHip = { rot = Vector3.new(7.26, 0, -3.91), pos = Vector3.new(0, 0.133, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-2.97, 50.33, 0),
						pos = Vector3.new(0.151, -0.14, 0.121),
					},
					Neck = { rot = Vector3.new(2.1, -49.41, 0) },
					RightShoulder = { rot = Vector3.new(96.25, 0, 30.27) },
					LeftShoulder = { rot = Vector3.new(-19.85, 0, 12.24) },
					RightHip = { rot = Vector3.new(6.85, 0, 2.93), pos = Vector3.new(0, 0.177, 0) },
					LeftHip = { rot = Vector3.new(7.12, 0, -3.92), pos = Vector3.new(0, 0.133, 0) },
				},
			},
			{
				time = 0.32,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-3, 50, 0), pos = Vector3.new(0.15, -0.14, 0.12) },
					Neck = { rot = Vector3.new(2, -48, 0) },
					RightShoulder = { rot = Vector3.new(95.78, 0, 29.96) },
					LeftShoulder = { rot = Vector3.new(-19.18, 0, 12.2) },
					RightHip = { rot = Vector3.new(6.95, 0, 2.93), pos = Vector3.new(0, 0.177, 0) },
					LeftHip = { rot = Vector3.new(7.01, 0, -3.93), pos = Vector3.new(0, 0.133, 0) },
				},
			},
			{
				time = 0.333,
				pose = {
					Root = {
						rot = Vector3.new(-1.27, 50.47, 0.52),
						pos = Vector3.new(0.163, -0.13, 0.151),
					},
					Neck = { rot = Vector3.new(-0.79, -46.96, 0.52) },
					RightShoulder = { rot = Vector3.new(99.92, 0, 30.26) },
					LeftShoulder = { rot = Vector3.new(-18.35, 0, 12.14) },
					RightHip = { rot = Vector3.new(6.15, 0, 0.82), pos = Vector3.new(0, 0.132, 0) },
					LeftHip = { rot = Vector3.new(6.4, 0, -6.04), pos = Vector3.new(0, 0.156, 0) },
				},
			},
			{
				time = 0.37,
				pose = {
					Root = { rot = Vector3.new(7, 52, 3), pos = Vector3.new(0.22, -0.183, 0.3) },
					Neck = { rot = Vector3.new(-14.47, -43.09, 3) },
					RightShoulder = { rot = Vector3.new(118.78, 0, 29.05) },
					LeftShoulder = { rot = Vector3.new(-14.95, 0, 11.93) },
					RightHip = { rot = Vector3.new(2.54, 0, -9.72) },
					LeftHip = { rot = Vector3.new(3.72, 0, -15.7), pos = Vector3.new(0, 0.349, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(4.59, 50.18, 2.17),
						pos = Vector3.new(0.192, -0.123, 0.263),
					},
					Neck = { rot = Vector3.new(-10.25, -41.83, 2.48) },
					RightShoulder = { rot = Vector3.new(109.4, 0, 29.25) },
					LeftShoulder = { rot = Vector3.new(-19.18, 0, 12.38) },
					RightHip = { rot = Vector3.new(3.62, 0, -6.32) },
					LeftHip = { rot = Vector3.new(3.63, 0, -12.74), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.433,
				pose = {
					Root = {
						rot = Vector3.new(-0.44, 46.63, 0.51),
						pos = Vector3.new(0.14, -0.115, 0.179),
					},
					Neck = { rot = Vector3.new(2.81, -38.46, 0.98) },
					RightShoulder = { rot = Vector3.new(93.52, 0, 26.84) },
					LeftShoulder = { rot = Vector3.new(-27.17, 0, 17.07) },
					RightHip = { rot = Vector3.new(6.46, 0, 0.53), pos = Vector3.new(0, 0.106, 0) },
					LeftHip = { rot = Vector3.new(4.35, 0, -6.27), pos = Vector3.new(0, 0.155, 0) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = { rot = Vector3.new(-2, 44, 0), pos = Vector3.new(0.12, -0.12, 0.15) },
					Neck = { rot = Vector3.new(5.38, -35.37, 0) },
					RightShoulder = { rot = Vector3.new(90.31, 0, 23.38) },
					LeftShoulder = { rot = Vector3.new(-27.18, 0, 16.6) },
					RightHip = { rot = Vector3.new(7.74, 0, 2.34), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(4.09, 0, -4.34), pos = Vector3.new(0, 0.133, 0) },
				},
			},
			{
				time = 0.467,
				pose = {
					Root = {
						rot = Vector3.new(-2.52, 40.68, -0.19),
						pos = Vector3.new(0.106, -0.118, 0.135),
					},
					Neck = { rot = Vector3.new(5.32, -30.27, -1.3) },
					RightShoulder = { rot = Vector3.new(94.02, 0, 16.57) },
					LeftShoulder = { rot = Vector3.new(-18.22, 0, 11.75) },
					RightHip = { rot = Vector3.new(8.67, 0, 2.64), pos = Vector3.new(0, 0.142, 0) },
					LeftHip = { rot = Vector3.new(3.01, 0, -3.77), pos = Vector3.new(0, 0.124, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-2.33, 32.58, -0.21),
						pos = Vector3.new(0.085, -0.106, 0.119),
					},
					Neck = { rot = Vector3.new(2.73, -17.23, -4.76) },
					RightShoulder = { rot = Vector3.new(107.17, 0, -3.42) },
					LeftShoulder = { rot = Vector3.new(3.8, 0, -2.33) },
					RightHip = { rot = Vector3.new(10.04, 0, 1.41), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(-0.51, 0, -3.86), pos = Vector3.new(0, 0.116, 0) },
				},
			},
			{
				time = 0.533,
				pose = {
					Root = {
						rot = Vector3.new(-1.84, 23.97, -0.04),
						pos = Vector3.new(0.068, -0.089, 0.108),
					},
					Neck = { rot = Vector3.new(1.37, -6.63, -7.55) },
					RightShoulder = { rot = Vector3.new(117.43, 0, -24.73) },
					LeftShoulder = { rot = Vector3.new(23.17, 0, 12.07) },
					RightHip = {
						rot = Vector3.new(10.39, 0, -0.69),
						pos = Vector3.new(0, 0.087, 0),
					},
					LeftHip = { rot = Vector3.new(-4.33, 0, -3.78), pos = Vector3.new(0, 0.097, 0) },
				},
			},
			{
				time = 0.55,
				pose = {
					Root = { rot = Vector3.new(-2, 20, 0), pos = Vector3.new(0.06, -0.08, 0.1) },
					Neck = { rot = Vector3.new(1.7, -2.81, -8) },
					RightShoulder = { rot = Vector3.new(120.06, 0, -31.25) },
					LeftShoulder = { rot = Vector3.new(35.46, 0, 23.45) },
					RightHip = { rot = Vector3.new(8.18, 0, -1.89), pos = Vector3.new(0, 0.121, 0) },
					LeftHip = { rot = Vector3.new(-5.64, 0, -3.28), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.567,
				pose = {
					Root = {
						rot = Vector3.new(-2.52, 15.94, 0),
						pos = Vector3.new(0.052, -0.071, 0.089),
					},
					Neck = { rot = Vector3.new(2.52, 0.16, -7.72) },
					RightShoulder = { rot = Vector3.new(120.02, 0, -33.52) },
					LeftShoulder = { rot = Vector3.new(40.62, 0, 25.36) },
					RightHip = { rot = Vector3.new(4.8, 0, -2.71), pos = Vector3.new(0, 0.153, 0) },
					LeftHip = { rot = Vector3.new(-6.45, 0, -2.48), pos = Vector3.new(0, 0.064, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-4.09, 6.73, 0),
						pos = Vector3.new(0.034, -0.049, 0.061),
					},
					Neck = { rot = Vector3.new(4.53, 5.62, -5.93) },
					RightShoulder = { rot = Vector3.new(118.2, 0, -36.12) },
					LeftShoulder = { rot = Vector3.new(58.66, 0, 31.95) },
					RightHip = {
						rot = Vector3.new(-2.29, 0, -2.52),
						pos = Vector3.new(0, 0.127, 0),
					},
					LeftHip = { rot = Vector3.new(-5.7, 0, -0.6), pos = Vector3.new(0, 0.086, 0) },
				},
			},
			{
				time = 0.633,
				pose = {
					Root = {
						rot = Vector3.new(-5.89, -2.33, 0),
						pos = Vector3.new(0.017, -0.025, 0.032),
					},
					Neck = { rot = Vector3.new(5.96, 9.89, -3.34) },
					RightShoulder = { rot = Vector3.new(115.17, 0, -36.93) },
					LeftShoulder = { rot = Vector3.new(76.95, 0, 35.39) },
					RightHip = { rot = Vector3.new(-4.55, 0, -0.65), pos = Vector3.new(0, 0.03, 0) },
					LeftHip = { rot = Vector3.new(-2.89, 0, 0.3), pos = Vector3.new(0, 0.079, 0) },
				},
			},
			{
				time = 0.667,
				pose = {
					Root = {
						rot = Vector3.new(-7.38, -9.26, 0),
						pos = Vector3.new(0.005, -0.007, 0.009),
					},
					Neck = { rot = Vector3.new(6.5, 12.14, -1.01) },
					RightShoulder = { rot = Vector3.new(112.28, 0, -36.76) },
					LeftShoulder = { rot = Vector3.new(97.73, 0, 37.22) },
					RightHip = {
						rot = Vector3.new(-1.39, 0, -0.05),
						pos = Vector3.new(0, 0.009, 0),
					},
					LeftHip = { rot = Vector3.new(-0.37, 0, 0.09), pos = Vector3.new(0, 0.021, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
		},
	},
	Rift_MegaRay = {
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
				},
			},
			{
				time = 0.033,
				pose = {
					Root = {
						rot = Vector3.new(-8.68, -9.7, -0.16),
						pos = Vector3.new(0.002, -0.039, 0.018),
					},
					Neck = { rot = Vector3.new(6.28, 7.76, 0) },
					RightShoulder = { rot = Vector3.new(95.57, 0, -36.15) },
					LeftShoulder = { rot = Vector3.new(107.88, 0, 42.1) },
					RightHip = { rot = Vector3.new(0.75, 0, -0.06), pos = Vector3.new(0, 0.041, 0) },
					LeftHip = { rot = Vector3.new(1.87, 0, -0.03), pos = Vector3.new(0, 0.041, 0) },
				},
			},
			{
				time = 0.067,
				pose = {
					Root = {
						rot = Vector3.new(-10.36, -4.03, -0.56),
						pos = Vector3.new(0.006, -0.136, 0.061),
					},
					Neck = { rot = Vector3.new(7.19, 1.53, 0) },
					RightShoulder = { rot = Vector3.new(75.85, 0, -33.96) },
					LeftShoulder = { rot = Vector3.new(92.49, 0, 47.36) },
					RightHip = { rot = Vector3.new(1.85, 0, 2.03), pos = Vector3.new(0, 0.232, 0) },
					LeftHip = { rot = Vector3.new(6.52, 0, 0.44), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-12.53, 3.15, -1.09),
						pos = Vector3.new(0.012, -0.259, 0.116),
					},
					Neck = { rot = Vector3.new(8.43, -6.4, 0) },
					RightShoulder = { rot = Vector3.new(58.83, 0, -30.57) },
					LeftShoulder = { rot = Vector3.new(77.47, 0, 50.55) },
					RightHip = { rot = Vector3.new(1.66, 0, 8.07), pos = Vector3.new(0, 0.454, 0) },
					LeftHip = { rot = Vector3.new(14.03, 0, 1.28), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.133,
				pose = {
					Root = {
						rot = Vector3.new(-14.66, 9.99, -1.63),
						pos = Vector3.new(0.017, -0.378, 0.169),
					},
					Neck = { rot = Vector3.new(9.42, -12.69, 0) },
					RightShoulder = { rot = Vector3.new(40.13, 0, -24.3) },
					LeftShoulder = { rot = Vector3.new(62.12, 0, 52.62) },
					RightHip = { rot = Vector3.new(0.86, 0, 14.31), pos = Vector3.new(0, 0.515, 0) },
					LeftHip = { rot = Vector3.new(28.95, 0, 1.41), pos = Vector3.new(0, 0.37, 0) },
				},
			},
			{
				time = 0.16,
				pose = {
					Root = { rot = Vector3.new(-16, 14, -2), pos = Vector3.new(0.02, -0.45, 0.2) },
					Neck = { rot = Vector3.new(9.87, -15.89, 0) },
					RightShoulder = { rot = Vector3.new(29.09, 0, -17.09) },
					LeftShoulder = { rot = Vector3.new(58.55, 0, 50.98) },
					RightHip = { rot = Vector3.new(0.7, 0, 16.96), pos = Vector3.new(0, 0.52, 0) },
					LeftHip = { rot = Vector3.new(44.02, 0, 2.34), pos = Vector3.new(0, 0.207, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-16.71, 15.56, -2.25),
						pos = Vector3.new(0.021, -0.5, 0.213),
					},
					Neck = { rot = Vector3.new(10.07, -16.14, 0) },
					RightShoulder = { rot = Vector3.new(27.46, 0, -16.87) },
					LeftShoulder = { rot = Vector3.new(57.31, 0, 50.74) },
					RightHip = { rot = Vector3.new(0.75, 0, 17.42), pos = Vector3.new(0, 0.58, 0) },
					LeftHip = { rot = Vector3.new(54.26, 0, 3.02) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-17.26, 16.09, -2.5),
						pos = Vector3.new(0.021, -0.62, 0.219),
					},
					Neck = { rot = Vector3.new(10.29, -15.13, 0) },
					RightShoulder = { rot = Vector3.new(28.06, 0, -16.78) },
					LeftShoulder = { rot = Vector3.new(57.87, 0, 51.04) },
					RightHip = { rot = Vector3.new(0.34, 0, 17.54), pos = Vector3.new(0, 0.703, 0) },
					LeftHip = { rot = Vector3.new(58.1, 0, 3.22) },
				},
			},
			{
				time = 0.233,
				pose = {
					Root = {
						rot = Vector3.new(-17.85, 15.95, -2.87),
						pos = Vector3.new(0.02, -0.637, 0.22),
					},
					Neck = { rot = Vector3.new(10.62, -12.75, 0) },
					RightShoulder = { rot = Vector3.new(30.79, 0, -16.78) },
					LeftShoulder = { rot = Vector3.new(60.19, 0, 51.84) },
					RightHip = { rot = Vector3.new(0.94, 0, 18.11), pos = Vector3.new(0, 0.73, 0) },
					LeftHip = { rot = Vector3.new(59.07, 0, 3.58) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = { rot = Vector3.new(-18, 16, -3), pos = Vector3.new(0.02, -0.644, 0.22) },
					Neck = { rot = Vector3.new(10.7, -12.24, 0) },
					RightShoulder = { rot = Vector3.new(31.56, 0, -16.82) },
					LeftShoulder = { rot = Vector3.new(60.79, 0, 52.01) },
					RightHip = { rot = Vector3.new(1.02, 0, 18.29), pos = Vector3.new(0, 0.739, 0) },
					LeftHip = { rot = Vector3.new(59.35, 0, 3.77) },
				},
			},
			{
				time = 0.267,
				pose = {
					Root = {
						rot = Vector3.new(-18.06, 16.14, -3.13),
						pos = Vector3.new(0.02, -0.65, 0.219),
					},
					Neck = { rot = Vector3.new(10.66, -12.17, 0) },
					RightShoulder = { rot = Vector3.new(30.49, 0, -16.98) },
					LeftShoulder = { rot = Vector3.new(59.98, 0, 51.51) },
					RightHip = { rot = Vector3.new(0.94, 0, 18.41), pos = Vector3.new(0, 0.746, 0) },
					LeftHip = { rot = Vector3.new(59.5, 0, 3.99) },
				},
			},
			{
				time = 0.31,
				pose = {
					Root = { rot = Vector3.new(-17, 16, -3), pos = Vector3.new(0.02, -0.613, 0.2) },
					Neck = { rot = Vector3.new(9.46, -12.04, 0) },
					RightShoulder = { rot = Vector3.new(35.16, 0, -23.36) },
					LeftShoulder = { rot = Vector3.new(59.45, 0, 51.1) },
					RightHip = {
						rot = Vector3.new(-0.36, 0, 17.95),
						pos = Vector3.new(0, 0.699, 0),
					},
					LeftHip = { rot = Vector3.new(57.17, 0, 3.57) },
				},
			},
			{
				time = 0.333,
				pose = {
					Root = {
						rot = Vector3.new(-15.14, 15.75, -2.24),
						pos = Vector3.new(0.015, -0.538, 0.178),
					},
					Neck = { rot = Vector3.new(7.72, -11.77, 0) },
					RightShoulder = { rot = Vector3.new(49.56, 0, -18.37) },
					LeftShoulder = { rot = Vector3.new(71.67, 0, 63.51) },
					RightHip = { rot = Vector3.new(-2.42, 0, 16.7), pos = Vector3.new(0, 0.599, 0) },
					LeftHip = { rot = Vector3.new(53.17, 0, 2.32) },
				},
			},
			{
				time = 0.367,
				pose = {
					Root = {
						rot = Vector3.new(-11.75, 15.25, -0.76),
						pos = Vector3.new(0.005, -0.493, 0.14),
					},
					Neck = { rot = Vector3.new(4.87, -11.48, 0) },
					RightShoulder = { rot = Vector3.new(82.13, 0, -9.96) },
					LeftShoulder = { rot = Vector3.new(84.4, 0, 68.51) },
					RightHip = {
						rot = Vector3.new(-6.99, 0, 13.95),
						pos = Vector3.new(0, 0.501, 0),
					},
					LeftHip = { rot = Vector3.new(45.54, 0, -0.49), pos = Vector3.new(0, 0.093, 0) },
				},
			},
			{
				time = 0.39,
				pose = {
					Root = { rot = Vector3.new(-10, 15, 0), pos = Vector3.new(0, -0.48, 0.12) },
					Neck = { rot = Vector3.new(4.02, -11.43, 0) },
					RightShoulder = { rot = Vector3.new(101.45, 0, -6.24) },
					LeftShoulder = { rot = Vector3.new(92.13, 0, 68.9) },
					RightHip = { rot = Vector3.new(-9.5, 0, 12.49), pos = Vector3.new(0, 0.459, 0) },
					LeftHip = { rot = Vector3.new(41.68, 0, -2.06), pos = Vector3.new(0, 0.149, 0) },
				},
			},
			{
				time = 0.433,
				pose = {
					Root = {
						rot = Vector3.new(-9.83, 14.98, 0.07),
						pos = Vector3.new(0, -0.479, 0.118),
					},
					Neck = { rot = Vector3.new(6.51, -11.79, 0) },
					RightShoulder = { rot = Vector3.new(102.64, 0, -6.06) },
					LeftShoulder = { rot = Vector3.new(92.13, 0, 68.9) },
					RightHip = {
						rot = Vector3.new(-9.75, 0, 12.34),
						pos = Vector3.new(0, 0.455, 0),
					},
					LeftHip = { rot = Vector3.new(41.31, 0, -2.22), pos = Vector3.new(0, 0.155, 0) },
				},
			},
			{
				time = 0.45,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-10, 15, 0), pos = Vector3.new(0, -0.48, 0.12) },
					Neck = { rot = Vector3.new(7.6, -11.94, 0) },
					RightShoulder = { rot = Vector3.new(101.51, 0, -6.23) },
					LeftShoulder = { rot = Vector3.new(92.13, 0, 68.9) },
					RightHip = {
						rot = Vector3.new(-9.51, 0, 12.48),
						pos = Vector3.new(0, 0.459, 0),
					},
					LeftHip = { rot = Vector3.new(41.66, 0, -2.07), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.467,
				pose = {
					Root = {
						rot = Vector3.new(-7.62, 15.35, 0.34),
						pos = Vector3.new(0, -0.464, 0.169),
					},
					Neck = { rot = Vector3.new(4.2, -12.07, 0) },
					RightShoulder = { rot = Vector3.new(101.32, 0, -5.78) },
					LeftShoulder = { rot = Vector3.new(92.13, 0, 68.9) },
					RightHip = {
						rot = Vector3.new(-11.4, 0, 11.54),
						pos = Vector3.new(0, 0.448, 0),
					},
					LeftHip = { rot = Vector3.new(39.96, 0, -2.6), pos = Vector3.new(0, 0.141, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(4.63, 17.1, 2.05),
						pos = Vector3.new(0, -0.38, 0.426),
					},
					Neck = { rot = Vector3.new(-15.94, -12.22, 0) },
					RightShoulder = { rot = Vector3.new(100.03, 0, -3.52) },
					LeftShoulder = { rot = Vector3.new(95.69, 0, 48.17) },
					RightHip = {
						rot = Vector3.new(-24.47, 0, 5.64),
						pos = Vector3.new(0, 0.393, 0),
					},
					LeftHip = { rot = Vector3.new(30.66, 0, -6.15), pos = Vector3.new(0, 0.086, 0) },
				},
			},
			{
				time = 0.53,
				pose = {
					Root = { rot = Vector3.new(12, 18, 3), pos = Vector3.new(0, -0.32, 0.6) },
					Neck = { rot = Vector3.new(-23.08, -11.86, 0) },
					RightShoulder = { rot = Vector3.new(98.2, 0, -2.36) },
					LeftShoulder = { rot = Vector3.new(92.99, 0, 38.11) },
					RightHip = {
						rot = Vector3.new(-36.61, 0, 1.07),
						pos = Vector3.new(0, 0.215, 0),
					},
					LeftHip = { rot = Vector3.new(24.92, 0, -8.87), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.567,
				pose = {
					Root = {
						rot = Vector3.new(11.06, 17.75, 2.61),
						pos = Vector3.new(0, -0.329, 0.64),
					},
					Neck = { rot = Vector3.new(-17.06, -10.21, 0) },
					RightShoulder = { rot = Vector3.new(94.82, 0, -2.62) },
					LeftShoulder = { rot = Vector3.new(81.04, 0, 35.2) },
					RightHip = { rot = Vector3.new(-41.72, 0, 0.29) },
					LeftHip = { rot = Vector3.new(27.35, 0, -7.72) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(7.52, 17.24, 1.82),
						pos = Vector3.new(0, -0.325, 0.636),
					},
					Neck = { rot = Vector3.new(-4.53, -9.17, 0) },
					RightShoulder = { rot = Vector3.new(91.04, 0, -3.2) },
					LeftShoulder = { rot = Vector3.new(66.66, 0, 35.29) },
					RightHip = {
						rot = Vector3.new(-36.88, 0, 2.53),
						pos = Vector3.new(0, 0.024, 0),
					},
					LeftHip = { rot = Vector3.new(31.31, 0, -5.22) },
				},
			},
			{
				time = 0.633,
				pose = {
					Root = {
						rot = Vector3.new(3, 16.31, 0.91),
						pos = Vector3.new(0, -0.311, 0.607),
					},
					Neck = { rot = Vector3.new(3.41, -8.52, 0) },
					RightShoulder = { rot = Vector3.new(87.84, 0, -4.46) },
					LeftShoulder = { rot = Vector3.new(54.51, 0, 32.57) },
					RightHip = { rot = Vector3.new(-30.43, 0, 5.6), pos = Vector3.new(0, 0.095, 0) },
					LeftHip = { rot = Vector3.new(30.38, 0, -2.26), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.667,
				pose = {
					Root = {
						rot = Vector3.new(-0.94, 14.8, 0.17),
						pos = Vector3.new(0, -0.307, 0.567),
					},
					Neck = { rot = Vector3.new(8.24, -7.08, 0) },
					RightShoulder = { rot = Vector3.new(86.31, 0, -6.74) },
					LeftShoulder = { rot = Vector3.new(39.08, 0, 25.48) },
					RightHip = {
						rot = Vector3.new(-25.22, 0, 8.33),
						pos = Vector3.new(0, 0.149, 0),
					},
					LeftHip = { rot = Vector3.new(25.38, 0, -0.08), pos = Vector3.new(0, 0.253, 0) },
				},
			},
			{
				time = 0.68,
				pose = {
					Root = { rot = Vector3.new(-2, 14, 0), pos = Vector3.new(0, -0.3, 0.55) },
					Neck = { rot = Vector3.new(8.89, -6.2, 0) },
					RightShoulder = { rot = Vector3.new(86.41, 0, -8.03) },
					LeftShoulder = { rot = Vector3.new(37.88, 0, 25.35) },
					RightHip = {
						rot = Vector3.new(-23.82, 0, 9.13),
						pos = Vector3.new(0, 0.156, 0),
					},
					LeftHip = { rot = Vector3.new(23, 0, 0.42), pos = Vector3.new(0, 0.255, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = {
						rot = Vector3.new(-3.2, 12.5, -0.15),
						pos = Vector3.new(0, -0.284, 0.521),
					},
					Neck = { rot = Vector3.new(8.95, -4.44, 0) },
					RightShoulder = { rot = Vector3.new(87.5, 0, -10.65) },
					LeftShoulder = { rot = Vector3.new(42.09, 0, 25.85) },
					RightHip = {
						rot = Vector3.new(-22.27, 0, 10.1),
						pos = Vector3.new(0, 0.153, 0),
					},
					LeftHip = { rot = Vector3.new(20, 0, 0.76), pos = Vector3.new(0, 0.223, 0) },
				},
			},
			{
				time = 0.733,
				pose = {
					Root = {
						rot = Vector3.new(-4.86, 9.29, -0.23),
						pos = Vector3.new(0, -0.249, 0.456),
					},
					Neck = { rot = Vector3.new(8.36, -0.63, 0) },
					RightShoulder = { rot = Vector3.new(91.34, 0, -16.9) },
					LeftShoulder = { rot = Vector3.new(58.78, 0, 34.05) },
					RightHip = {
						rot = Vector3.new(-20.24, 0, 11.47),
						pos = Vector3.new(0, 0.128, 0),
					},
					LeftHip = { rot = Vector3.new(18.31, 0, 0.16), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.767,
				pose = {
					Root = {
						rot = Vector3.new(-6.15, 5.57, -0.18),
						pos = Vector3.new(0, -0.207, 0.379),
					},
					Neck = { rot = Vector3.new(7.83, 3.44, 0) },
					RightShoulder = { rot = Vector3.new(96.72, 0, -24.39) },
					LeftShoulder = { rot = Vector3.new(75.44, 0, 37.05) },
					RightHip = {
						rot = Vector3.new(-16.79, 0, 11.43),
						pos = Vector3.new(0, 0.175, 0),
					},
					LeftHip = { rot = Vector3.new(16.86, 0, -1.07), pos = Vector3.new(0, 0.169, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-7.12, 1.84, -0.07),
						pos = Vector3.new(0, -0.164, 0.301),
					},
					Neck = { rot = Vector3.new(7.23, 6.82, 0) },
					RightShoulder = { rot = Vector3.new(102.26, 0, -31.31) },
					LeftShoulder = { rot = Vector3.new(93.08, 0, 38.6) },
					RightHip = { rot = Vector3.new(-9.83, 0, 8.24), pos = Vector3.new(0, 0.277, 0) },
					LeftHip = { rot = Vector3.new(14.96, 0, -2.28), pos = Vector3.new(0, 0.154, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = { rot = Vector3.new(-8, -2, 0), pos = Vector3.new(0, -0.12, 0.22) },
					Neck = { rot = Vector3.new(6.79, 9.25, 0) },
					RightShoulder = { rot = Vector3.new(107.09, 0, -36.73) },
					LeftShoulder = { rot = Vector3.new(109.04, 0, 38.41) },
					RightHip = { rot = Vector3.new(-1.09, 0, 2.64), pos = Vector3.new(0, 0.237, 0) },
					LeftHip = { rot = Vector3.new(12.81, 0, -3.3), pos = Vector3.new(0, 0.133, 0) },
				},
			},
			{
				time = 0.867,
				pose = {
					Root = {
						rot = Vector3.new(-8.35, -4.25, 0),
						pos = Vector3.new(0, -0.094, 0.172),
					},
					Neck = { rot = Vector3.new(6.66, 10.01, 0) },
					RightShoulder = { rot = Vector3.new(108.82, 0, -38.21) },
					LeftShoulder = { rot = Vector3.new(112.59, 0, 38.04) },
					RightHip = { rot = Vector3.new(2.47, 0, -0.08), pos = Vector3.new(0, 0.133, 0) },
					LeftHip = { rot = Vector3.new(10.59, 0, -3.28), pos = Vector3.new(0, 0.158, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = { rot = Vector3.new(-8.44, -7.07, 0), pos = Vector3.new(0, -0.06, 0.11) },
					Neck = { rot = Vector3.new(6.38, 10.72, 0) },
					RightShoulder = { rot = Vector3.new(110.15, 0, -38.54) },
					LeftShoulder = { rot = Vector3.new(114.79, 0, 37.61) },
					RightHip = { rot = Vector3.new(2.29, 0, -0.49), pos = Vector3.new(0, 0.069, 0) },
					LeftHip = { rot = Vector3.new(6.51, 0, -2.2), pos = Vector3.new(0, 0.165, 0) },
				},
			},
			{
				time = 0.933,
				pose = {
					Root = { rot = Vector3.new(-8.3, -9.55, 0), pos = Vector3.new(0, -0.03, 0.055) },
					Neck = { rot = Vector3.new(6.1, 11.07, 0) },
					RightShoulder = { rot = Vector3.new(110.78, 0, -37.9) },
					LeftShoulder = { rot = Vector3.new(115.41, 0, 37.28) },
					RightHip = { rot = Vector3.new(1.27, 0, -0.33), pos = Vector3.new(0, 0.034, 0) },
					LeftHip = { rot = Vector3.new(2.82, 0, -0.77), pos = Vector3.new(0, 0.084, 0) },
				},
			},
			{
				time = 0.967,
				pose = {
					Root = {
						rot = Vector3.new(-8.1, -11.33, 0),
						pos = Vector3.new(0, -0.008, 0.015),
					},
					Neck = { rot = Vector3.new(5.96, 10.81, 0) },
					RightShoulder = { rot = Vector3.new(110.99, 0, -36.97) },
					LeftShoulder = { rot = Vector3.new(115.23, 0, 37.07) },
					RightHip = { rot = Vector3.new(0.39, 0, -0.11), pos = Vector3.new(0, 0.01, 0) },
					LeftHip = { rot = Vector3.new(0.7, 0, -0.1), pos = Vector3.new(0, 0.012, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
		},
	},
	Rift_Glove = {
		length = 0.8,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
			{
				time = 0.033,
				pose = {
					Root = {
						rot = Vector3.new(-7.68, -8.35, -0.21),
						pos = Vector3.new(-0.007, -0.019, 0.022),
					},
					Neck = { rot = Vector3.new(5.93, 6.05, 0) },
					RightShoulder = { rot = Vector3.new(110.52, 0, -36.16) },
					LeftShoulder = { rot = Vector3.new(88.82, 0, 42.77) },
					RightHip = { rot = Vector3.new(-0.8, 0, 0.47), pos = Vector3.new(0, 0.029, 0) },
					LeftHip = { rot = Vector3.new(0.99, 0, 0.54), pos = Vector3.new(0, 0.015, 0) },
				},
			},
			{
				time = 0.05,
				pose = {
					Root = {
						rot = Vector3.new(-7.33, -4.24, -0.44),
						pos = Vector3.new(-0.016, -0.042, 0.046),
					},
					Neck = { rot = Vector3.new(5.81, 1.19, 0) },
					RightShoulder = { rot = Vector3.new(109.97, 0, -35.77) },
					LeftShoulder = { rot = Vector3.new(73.26, 0, 38.69) },
					RightHip = { rot = Vector3.new(-1.76, 0, 1.07), pos = Vector3.new(0, 0.076, 0) },
					LeftHip = { rot = Vector3.new(2.12, 0, 1.22), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.067,
				pose = {
					Root = {
						rot = Vector3.new(-6.89, 0.99, -0.74),
						pos = Vector3.new(-0.026, -0.07, 0.077),
					},
					Neck = { rot = Vector3.new(5.63, -5.32, 0) },
					RightShoulder = { rot = Vector3.new(109.27, 0, -35.28) },
					LeftShoulder = { rot = Vector3.new(58.74, 0, 23.19) },
					RightHip = { rot = Vector3.new(-3.05, 0, 2.25), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(3.51, 0, 2.2), pos = Vector3.new(0, 0.047, 0) },
				},
			},
			{
				time = 0.083,
				pose = {
					Root = {
						rot = Vector3.new(-6.39, 7.02, -1.08),
						pos = Vector3.new(-0.038, -0.102, 0.112),
					},
					Neck = { rot = Vector3.new(5.43, -11.32, 0) },
					RightShoulder = { rot = Vector3.new(108.46, 0, -34.71) },
					LeftShoulder = { rot = Vector3.new(44.8, 0, 6.43) },
					RightHip = { rot = Vector3.new(-4.64, 0, 3.75), pos = Vector3.new(0, 0.242, 0) },
					LeftHip = { rot = Vector3.new(5.06, 0, 3.49), pos = Vector3.new(0, 0.063, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-5.87, 13.51, -1.44),
						pos = Vector3.new(-0.05, -0.138, 0.149),
					},
					Neck = { rot = Vector3.new(5.25, -17.3, 0) },
					RightShoulder = { rot = Vector3.new(107.57, 0, -34.1) },
					LeftShoulder = { rot = Vector3.new(32.4, 0, -0.49) },
					RightHip = { rot = Vector3.new(-6.51, 0, 5.28), pos = Vector3.new(0, 0.298, 0) },
					LeftHip = { rot = Vector3.new(6.64, 0, 5.06), pos = Vector3.new(0, 0.077, 0) },
				},
			},
			{
				time = 0.133,
				pose = {
					Root = {
						rot = Vector3.new(-4.88, 26.79, -2.18),
						pos = Vector3.new(-0.075, -0.211, 0.223),
					},
					Neck = { rot = Vector3.new(5.03, -29.42, 0) },
					RightShoulder = { rot = Vector3.new(105.72, 0, -32.86) },
					LeftShoulder = { rot = Vector3.new(6.61, 0, -0.17) },
					RightHip = {
						rot = Vector3.new(-10.87, 0, 7.51),
						pos = Vector3.new(0, 0.304, 0),
					},
					LeftHip = { rot = Vector3.new(9.56, 0, 8.81), pos = Vector3.new(0, 0.093, 0) },
				},
			},
			{
				time = 0.167,
				pose = {
					Root = {
						rot = Vector3.new(-4.16, 38.4, -2.81),
						pos = Vector3.new(-0.095, -0.278, 0.283),
					},
					Neck = { rot = Vector3.new(5.08, -40.01, 0) },
					RightShoulder = { rot = Vector3.new(103.99, 0, -31.8) },
					LeftShoulder = { rot = Vector3.new(-20.68, 0, 8.7) },
					RightHip = {
						rot = Vector3.new(-14.72, 0, 7.35),
						pos = Vector3.new(0, 0.284, 0),
					},
					LeftHip = { rot = Vector3.new(11.71, 0, 12.64), pos = Vector3.new(0, 0.095, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(-4, 42, -3), pos = Vector3.new(-0.1, -0.3, 0.3) },
					Neck = { rot = Vector3.new(5.18, -43.33, 0) },
					RightShoulder = { rot = Vector3.new(103.39, 0, -31.48) },
					LeftShoulder = { rot = Vector3.new(-27.53, 0, 11.83) },
					RightHip = { rot = Vector3.new(-15.8, 0, 6.87), pos = Vector3.new(0, 0.296, 0) },
					LeftHip = { rot = Vector3.new(12.31, 0, 13.92), pos = Vector3.new(0, 0.094, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-4.1, 46.86, -3.19),
						pos = Vector3.new(-0.101, -0.324, 0.316),
					},
					Neck = { rot = Vector3.new(5.33, -47.97, 0) },
					RightShoulder = { rot = Vector3.new(104.02, 0, -31.54) },
					LeftShoulder = { rot = Vector3.new(-31.47, 0, 13.91) },
					RightHip = {
						rot = Vector3.new(-16.91, 0, 6.11),
						pos = Vector3.new(0, 0.307, 0),
					},
					LeftHip = { rot = Vector3.new(13.35, 0, 15.68), pos = Vector3.new(0, 0.085, 0) },
				},
			},
			{
				time = 0.22,
				pose = {
					Root = {
						rot = Vector3.new(-4.75, 49.4, -3.2),
						pos = Vector3.new(-0.094, -0.341, 0.307),
					},
					Neck = { rot = Vector3.new(5.77, -50.69, 0) },
					RightShoulder = { rot = Vector3.new(104.61, 0, -31.91) },
					LeftShoulder = { rot = Vector3.new(-31.82, 0, 14.44) },
					RightHip = { rot = Vector3.new(-17.1, 0, 5.65), pos = Vector3.new(0, 0.319, 0) },
					LeftHip = { rot = Vector3.new(16.72, 0, 18.59), pos = Vector3.new(0, 0.132, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = { rot = Vector3.new(-6, 46, -3), pos = Vector3.new(-0.08, -0.36, 0.25) },
					Neck = { rot = Vector3.new(7.1, -43.88, 0) },
					RightShoulder = { rot = Vector3.new(100.8, 0, -31.6) },
					LeftShoulder = { rot = Vector3.new(-28.45, 0, 12.17) },
					RightHip = {
						rot = Vector3.new(-15.82, 0, 6.04),
						pos = Vector3.new(0, 0.346, 0),
					},
					LeftHip = { rot = Vector3.new(23.99, 0, 22.11), pos = Vector3.new(0, 0.168, 0) },
				},
			},
			{
				time = 0.267,
				pose = {
					Root = {
						rot = Vector3.new(-8.77, 30.8, -2.35),
						pos = Vector3.new(-0.05, -0.396, 0.083),
					},
					Neck = { rot = Vector3.new(10.59, -18.49, 0) },
					RightShoulder = { rot = Vector3.new(76.52, 0, -27.48) },
					LeftShoulder = { rot = Vector3.new(-2.92, 0, -4.67) },
					RightHip = { rot = Vector3.new(-11.47, 0, 7.4), pos = Vector3.new(0, 0.398, 0) },
					LeftHip = { rot = Vector3.new(37.3, 0, 20.15), pos = Vector3.new(0, 0.179, 0) },
				},
			},
			{
				time = 0.283,
				pose = {
					Root = {
						rot = Vector3.new(-10.95, 17.88, -1.81),
						pos = Vector3.new(-0.027, -0.421, -0.052),
					},
					Neck = { rot = Vector3.new(13.15, -7.22, 0) },
					RightShoulder = { rot = Vector3.new(60.41, 0, -22.27) },
					LeftShoulder = { rot = Vector3.new(16, 0, -12.97) },
					RightHip = { rot = Vector3.new(-7.83, 0, 7.84), pos = Vector3.new(0, 0.417, 0) },
					LeftHip = { rot = Vector3.new(43.59, 0, 13.24), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-13.17, 4.33, -1.25),
						pos = Vector3.new(-0.002, -0.447, -0.192),
					},
					Neck = { rot = Vector3.new(15.58, 4.58, 0) },
					RightShoulder = { rot = Vector3.new(45.29, 0, -13.74) },
					LeftShoulder = { rot = Vector3.new(37.68, 0, -18.04) },
					RightHip = { rot = Vector3.new(-4.1, 0, 7.66), pos = Vector3.new(0, 0.416, 0) },
					LeftHip = { rot = Vector3.new(45.57, 0, 3.28), pos = Vector3.new(0, 0.235, 0) },
				},
			},
			{
				time = 0.317,
				pose = {
					Root = {
						rot = Vector3.new(-15.21, -8.34, -0.73),
						pos = Vector3.new(0.02, -0.469, -0.321),
					},
					Neck = { rot = Vector3.new(17.53, 15.62, 0) },
					RightShoulder = { rot = Vector3.new(29.8, 0, -5.93) },
					LeftShoulder = { rot = Vector3.new(61.03, 0, -18.82) },
					RightHip = { rot = Vector3.new(-0.73, 0, 6.94), pos = Vector3.new(0, 0.397, 0) },
					LeftHip = { rot = Vector3.new(43.29, 0, -7.1), pos = Vector3.new(0, 0.322, 0) },
				},
			},
			{
				time = 0.333,
				pose = {
					Root = {
						rot = Vector3.new(-16.84, -18.64, -0.3),
						pos = Vector3.new(0.037, -0.487, -0.426),
					},
					Neck = { rot = Vector3.new(18.61, 24.59, 0) },
					RightShoulder = { rot = Vector3.new(12.09, 0, -3.43) },
					LeftShoulder = { rot = Vector3.new(83.7, 0, -15.07) },
					RightHip = { rot = Vector3.new(1.91, 0, 5.99), pos = Vector3.new(0, 0.371, 0) },
					LeftHip = {
						rot = Vector3.new(37.35, 0, -14.84),
						pos = Vector3.new(0, 0.467, 0),
					},
				},
			},
			{
				time = 0.36,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-18, -26, 0), pos = Vector3.new(0.05, -0.5, -0.5) },
					Neck = { rot = Vector3.new(17.98, 31.04, 0) },
					RightShoulder = { rot = Vector3.new(-10.71, 0, -5.27) },
					LeftShoulder = { rot = Vector3.new(113.98, 0, -2.16) },
					RightHip = { rot = Vector3.new(3.75, 0, 5.12), pos = Vector3.new(0, 0.346, 0) },
					LeftHip = {
						rot = Vector3.new(31.53, 0, -19.33),
						pos = Vector3.new(0, 0.604, 0),
					},
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-17.11, -25.48, 0),
						pos = Vector3.new(0.051, -0.5, -0.486),
					},
					Neck = { rot = Vector3.new(13.36, 26.87, 0) },
					RightShoulder = { rot = Vector3.new(-12.42, 0, -5.83) },
					LeftShoulder = { rot = Vector3.new(114.51, 0, -2.17) },
					RightHip = { rot = Vector3.new(2.84, 0, 5.47), pos = Vector3.new(0, 0.356, 0) },
					LeftHip = {
						rot = Vector3.new(31.21, 0, -18.85),
						pos = Vector3.new(0, 0.592, 0),
					},
				},
			},
			{
				time = 0.433,
				pose = {
					Root = {
						rot = Vector3.new(-15.58, -24.25, 0),
						pos = Vector3.new(0.052, -0.493, -0.459),
					},
					Neck = { rot = Vector3.new(9.84, 18.75, 0) },
					RightShoulder = { rot = Vector3.new(-13.65, 0, -6.27) },
					LeftShoulder = { rot = Vector3.new(114.96, 0, -1.39) },
					RightHip = { rot = Vector3.new(1.3, 0, 6), pos = Vector3.new(0, 0.368, 0) },
					LeftHip = {
						rot = Vector3.new(31.08, 0, -17.88),
						pos = Vector3.new(0, 0.559, 0),
					},
				},
			},
			{
				time = 0.47,
				pose = {
					Root = { rot = Vector3.new(-14, -22, 0), pos = Vector3.new(0.05, -0.47, -0.42) },
					Neck = { rot = Vector3.new(8.02, 15.78, 0) },
					RightShoulder = { rot = Vector3.new(-10.79, 0, -5.27) },
					LeftShoulder = { rot = Vector3.new(114.65, 0, 1.75) },
					RightHip = { rot = Vector3.new(-0.25, 0, 6.41), pos = Vector3.new(0, 0.366, 0) },
					LeftHip = {
						rot = Vector3.new(31.93, 0, -16.47),
						pos = Vector3.new(0, 0.494, 0),
					},
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-12.96, -19.19, 0),
						pos = Vector3.new(0.046, -0.438, -0.384),
					},
					Neck = { rot = Vector3.new(7.69, 12.91, 0) },
					RightShoulder = { rot = Vector3.new(10.06, 0, 2.66) },
					LeftShoulder = { rot = Vector3.new(113.35, 0, 7.04) },
					RightHip = { rot = Vector3.new(-1.36, 0, 6.54), pos = Vector3.new(0, 0.348, 0) },
					LeftHip = {
						rot = Vector3.new(33.72, 0, -14.85),
						pos = Vector3.new(0, 0.412, 0),
					},
				},
			},
			{
				time = 0.517,
				pose = {
					Root = {
						rot = Vector3.new(-12.37, -17.26, 0),
						pos = Vector3.new(0.043, -0.417, -0.361),
					},
					Neck = { rot = Vector3.new(7.6, 11.1, 0) },
					RightShoulder = { rot = Vector3.new(23.41, 0, -0.23) },
					LeftShoulder = { rot = Vector3.new(112.33, 0, 10.91) },
					RightHip = { rot = Vector3.new(-1.58, 0, 6.16), pos = Vector3.new(0, 0.372, 0) },
					LeftHip = { rot = Vector3.new(34.97, 0, -13.7), pos = Vector3.new(0, 0.356, 0) },
				},
			},
			{
				time = 0.533,
				pose = {
					Root = {
						rot = Vector3.new(-11.78, -15.21, 0),
						pos = Vector3.new(0.039, -0.394, -0.338),
					},
					Neck = { rot = Vector3.new(7.49, 9.32, 0) },
					RightShoulder = { rot = Vector3.new(35.62, 0, -12.59) },
					LeftShoulder = { rot = Vector3.new(111.19, 0, 15.18) },
					RightHip = { rot = Vector3.new(-0.73, 0, 5.09), pos = Vector3.new(0, 0.414, 0) },
					LeftHip = {
						rot = Vector3.new(36.31, 0, -12.45),
						pos = Vector3.new(0, 0.296, 0),
					},
				},
			},
			{
				time = 0.55,
				pose = {
					Root = {
						rot = Vector3.new(-11.2, -13.12, 0),
						pos = Vector3.new(0.036, -0.37, -0.313),
					},
					Neck = { rot = Vector3.new(7.34, 7.67, 0) },
					RightShoulder = { rot = Vector3.new(47.05, 0, -23.67) },
					LeftShoulder = { rot = Vector3.new(110.02, 0, 19.66) },
					RightHip = { rot = Vector3.new(1.05, 0, 3.65), pos = Vector3.new(0, 0.441, 0) },
					LeftHip = { rot = Vector3.new(37.7, 0, -11.12), pos = Vector3.new(0, 0.231, 0) },
				},
			},
			{
				time = 0.567,
				pose = {
					Root = {
						rot = Vector3.new(-10.64, -11.11, 0),
						pos = Vector3.new(0.032, -0.345, -0.289),
					},
					Neck = { rot = Vector3.new(7.23, 6.35, 0) },
					RightShoulder = { rot = Vector3.new(59.17, 0, -29.03) },
					LeftShoulder = { rot = Vector3.new(108.89, 0, 24.07) },
					RightHip = { rot = Vector3.new(3.47, 0, 2.17), pos = Vector3.new(0, 0.433, 0) },
					LeftHip = { rot = Vector3.new(39.08, 0, -9.81), pos = Vector3.new(0, 0.164, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-9.67, -7.74, 0),
						pos = Vector3.new(0.025, -0.294, -0.24),
					},
					Neck = { rot = Vector3.new(7.11, 4.85, 0) },
					RightShoulder = { rot = Vector3.new(84.97, 0, -34.36) },
					LeftShoulder = { rot = Vector3.new(107.12, 0, 31.67) },
					RightHip = { rot = Vector3.new(8.31, 0, 0.09), pos = Vector3.new(0, 0.315, 0) },
					LeftHip = { rot = Vector3.new(41.56, 0, -7.5), pos = Vector3.new(0, 0.035, 0) },
				},
			},
			{
				time = 0.63,
				pose = {
					Root = { rot = Vector3.new(-9, -6, 0), pos = Vector3.new(0.02, -0.25, -0.2) },
					Neck = { rot = Vector3.new(7.05, 4.98, 0) },
					RightShoulder = { rot = Vector3.new(107.67, 0, -37.35) },
					LeftShoulder = { rot = Vector3.new(106.51, 0, 36.15) },
					RightHip = { rot = Vector3.new(9.67, 0, -0.07), pos = Vector3.new(0, 0.231, 0) },
					LeftHip = { rot = Vector3.new(36.42, 0, -5.48), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.667,
				pose = {
					Root = {
						rot = Vector3.new(-8.47, -6.03, 0),
						pos = Vector3.new(0.014, -0.188, -0.147),
					},
					Neck = { rot = Vector3.new(6.9, 6.78, 0) },
					RightShoulder = { rot = Vector3.new(111.68, 0, -37.36) },
					LeftShoulder = { rot = Vector3.new(107.53, 0, 38.52) },
					RightHip = {
						rot = Vector3.new(10.73, 0, -0.02),
						pos = Vector3.new(0, 0.169, 0),
					},
					LeftHip = { rot = Vector3.new(20.47, 0, -3.23), pos = Vector3.new(0, 0.296, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = {
						rot = Vector3.new(-8.19, -7.48, 0),
						pos = Vector3.new(0.009, -0.123, -0.095),
					},
					Neck = { rot = Vector3.new(6.64, 8.75, 0) },
					RightShoulder = { rot = Vector3.new(112.74, 0, -37.14) },
					LeftShoulder = { rot = Vector3.new(109.64, 0, 38.92) },
					RightHip = {
						rot = Vector3.new(10.27, 0, -0.25),
						pos = Vector3.new(0, 0.133, 0),
					},
					LeftHip = { rot = Vector3.new(6.57, 0, -1.27), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.733,
				pose = {
					Root = {
						rot = Vector3.new(-8.05, -9.47, 0),
						pos = Vector3.new(0.004, -0.063, -0.048),
					},
					Neck = { rot = Vector3.new(6.34, 10.1, 0) },
					RightShoulder = { rot = Vector3.new(112.39, 0, -36.86) },
					LeftShoulder = { rot = Vector3.new(112.1, 0, 38.34) },
					RightHip = { rot = Vector3.new(3.65, 0, -0.21), pos = Vector3.new(0, 0.109, 0) },
					LeftHip = { rot = Vector3.new(-0.63, 0, 0.09), pos = Vector3.new(0, 0.063, 0) },
				},
			},
			{
				time = 0.767,
				pose = {
					Root = {
						rot = Vector3.new(-8, -11.24, 0),
						pos = Vector3.new(0.001, -0.018, -0.013),
					},
					Neck = { rot = Vector3.new(6.09, 10.6, 0) },
					RightShoulder = { rot = Vector3.new(111.5, 0, -36.61) },
					LeftShoulder = { rot = Vector3.new(114.15, 0, 37.46) },
					RightHip = { rot = Vector3.new(-0.55, 0, 0.04), pos = Vector3.new(0, 0.018, 0) },
					LeftHip = { rot = Vector3.new(-0.26, 0, 0.06), pos = Vector3.new(0, 0.015, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
		},
	},
	Rift_Portal = {
		length = 1.1,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
			{
				time = 0.033,
				pose = {
					Root = {
						rot = Vector3.new(-7.43, -7.06, 0),
						pos = Vector3.new(0.012, -0.018, 0.008),
					},
					Neck = { rot = Vector3.new(5.28, 4.26, 0) },
					RightShoulder = { rot = Vector3.new(106.91, 0, -27.94) },
					LeftShoulder = { rot = Vector3.new(87.51, 0, 35.95) },
					RightHip = {
						rot = Vector3.new(-1.95, 0, -0.31),
						pos = Vector3.new(0, 0.017, 0),
					},
					LeftHip = { rot = Vector3.new(0.49, 0, -0.2), pos = Vector3.new(0, 0.02, 0) },
				},
			},
			{
				time = 0.067,
				pose = {
					Root = {
						rot = Vector3.new(-6.12, 4.24, 0),
						pos = Vector3.new(0.039, -0.059, 0.028),
					},
					Neck = { rot = Vector3.new(3.51, -9.48, 0) },
					RightShoulder = { rot = Vector3.new(101.13, 0, -15.21) },
					LeftShoulder = { rot = Vector3.new(59.59, 0, 30.97) },
					RightHip = {
						rot = Vector3.new(-6.18, 0, -1.86),
						pos = Vector3.new(0, 0.038, 0),
					},
					LeftHip = { rot = Vector3.new(1.49, 0, -0.75), pos = Vector3.new(0, 0.091, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-4.68, 16.45, 0),
						pos = Vector3.new(0.068, -0.102, 0.049),
					},
					Neck = { rot = Vector3.new(1.63, -21.81, 0) },
					RightShoulder = { rot = Vector3.new(95.05, 0, -3.63) },
					LeftShoulder = { rot = Vector3.new(35.61, 0, 22.89) },
					RightHip = {
						rot = Vector3.new(-8.51, 0, -4.32),
						pos = Vector3.new(0, 0.089, 0),
					},
					LeftHip = { rot = Vector3.new(1.61, 0, -1.94), pos = Vector3.new(0, 0.203, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-4, 22, 0), pos = Vector3.new(0.08, -0.12, 0.06) },
					Neck = { rot = Vector3.new(0.93, -27.28, 0) },
					RightShoulder = { rot = Vector3.new(93.17, 0, 1.75) },
					LeftShoulder = { rot = Vector3.new(18.49, 0, 12.55) },
					RightHip = {
						rot = Vector3.new(-5.86, 0, -4.35),
						pos = Vector3.new(0, 0.169, 0),
					},
					LeftHip = { rot = Vector3.new(1.5, 0, -2.84), pos = Vector3.new(0, 0.223, 0) },
				},
			},
			{
				time = 0.133,
				pose = {
					Root = {
						rot = Vector3.new(-3.65, 24.72, 0),
						pos = Vector3.new(0.085, -0.128, 0.066),
					},
					Neck = { rot = Vector3.new(0.71, -29.83, 0) },
					RightShoulder = { rot = Vector3.new(93.35, 0, 4.31) },
					LeftShoulder = { rot = Vector3.new(12.56, 0, 12.4) },
					RightHip = {
						rot = Vector3.new(-3.07, 0, -3.52),
						pos = Vector3.new(0, 0.212, 0),
					},
					LeftHip = { rot = Vector3.new(1.4, 0, -3.38), pos = Vector3.new(0, 0.212, 0) },
				},
			},
			{
				time = 0.167,
				pose = {
					Root = {
						rot = Vector3.new(-2.88, 30.19, 0),
						pos = Vector3.new(0.094, -0.14, 0.081),
					},
					Neck = { rot = Vector3.new(0.55, -34.4, 0) },
					RightShoulder = { rot = Vector3.new(96.06, 0, 9.65) },
					LeftShoulder = { rot = Vector3.new(-1.32, 0, 12.23) },
					RightHip = { rot = Vector3.new(3.82, 0, -0.05), pos = Vector3.new(0, 0.226, 0) },
					LeftHip = { rot = Vector3.new(1.73, 0, -4.29), pos = Vector3.new(0, 0.156, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-2.28, 34.12, 0),
						pos = Vector3.new(0.098, -0.147, 0.094),
					},
					Neck = { rot = Vector3.new(0.5, -35.49, 0) },
					RightShoulder = { rot = Vector3.new(100.04, 0, 13.64) },
					LeftShoulder = { rot = Vector3.new(-13.16, 0, 12.19) },
					RightHip = { rot = Vector3.new(6.32, 0, 2.17), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(2.64, 0, -4.51), pos = Vector3.new(0, 0.164, 0) },
				},
			},
			{
				time = 0.22,
				pose = {
					Root = { rot = Vector3.new(-2, 36, 0), pos = Vector3.new(0.1, -0.15, 0.1) },
					Neck = { rot = Vector3.new(0.38, -36.15, 0) },
					RightShoulder = { rot = Vector3.new(101.83, 0, 15.48) },
					LeftShoulder = { rot = Vector3.new(-18.42, 0, 12.17) },
					RightHip = { rot = Vector3.new(5.64, 0, 2.18), pos = Vector3.new(0, 0.173, 0) },
					LeftHip = { rot = Vector3.new(3.09, 0, -4.6), pos = Vector3.new(0, 0.168, 0) },
				},
			},
			{
				time = 0.233,
				pose = {
					Root = {
						rot = Vector3.new(-1.9, 36.71, 0),
						pos = Vector3.new(0.101, -0.152, 0.102),
					},
					Neck = { rot = Vector3.new(0.24, -36.25, 0) },
					RightShoulder = { rot = Vector3.new(102.33, 0, 16.15) },
					LeftShoulder = { rot = Vector3.new(-20.15, 0, 12.15) },
					RightHip = { rot = Vector3.new(5.38, 0, 2.18), pos = Vector3.new(0, 0.175, 0) },
					LeftHip = { rot = Vector3.new(3.27, 0, -4.63), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.267,
				pose = {
					Root = {
						rot = Vector3.new(-1.97, 36.2, 0),
						pos = Vector3.new(0.1, -0.15, 0.101),
					},
					Neck = { rot = Vector3.new(-0.1, -34.34, 0) },
					RightShoulder = { rot = Vector3.new(101.98, 0, 15.68) },
					LeftShoulder = { rot = Vector3.new(-18.93, 0, 12.16) },
					RightHip = { rot = Vector3.new(5.56, 0, 2.18), pos = Vector3.new(0, 0.174, 0) },
					LeftHip = { rot = Vector3.new(3.14, 0, -4.61), pos = Vector3.new(0, 0.169, 0) },
				},
			},
			{
				time = 0.28,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-2, 36, 0), pos = Vector3.new(0.1, -0.15, 0.1) },
					Neck = { rot = Vector3.new(-0.07, -33.5, 0) },
					RightShoulder = { rot = Vector3.new(101.83, 0, 15.49) },
					LeftShoulder = { rot = Vector3.new(-18.44, 0, 12.17) },
					RightHip = { rot = Vector3.new(5.64, 0, 2.18), pos = Vector3.new(0, 0.173, 0) },
					LeftHip = { rot = Vector3.new(3.09, 0, -4.6), pos = Vector3.new(0, 0.168, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-0.01, 36.93, 0.52),
						pos = Vector3.new(0.108, -0.139, 0.127),
					},
					Neck = { rot = Vector3.new(-2.93, -32.91, 0) },
					RightShoulder = { rot = Vector3.new(103.99, 0, 16.57) },
					LeftShoulder = { rot = Vector3.new(-17.44, 0, 12.06) },
					RightHip = { rot = Vector3.new(3.91, 0, 0.12), pos = Vector3.new(0, 0.131, 0) },
					LeftHip = { rot = Vector3.new(1.9, 0, -6.67), pos = Vector3.new(0, 0.189, 0) },
				},
			},
			{
				time = 0.34,
				pose = {
					Root = { rot = Vector3.new(5, 38, 2), pos = Vector3.new(0.13, -0.12, 0.2) },
					Neck = { rot = Vector3.new(-10.12, -31.11, 0) },
					RightShoulder = { rot = Vector3.new(108.27, 0, 17.16) },
					LeftShoulder = { rot = Vector3.new(-15.83, 0, 11.87) },
					RightHip = {
						rot = Vector3.new(-0.05, 0, -5.72),
						pos = Vector3.new(0, 0.015, 0),
					},
					LeftHip = {
						rot = Vector3.new(-1.25, 0, -12.18),
						pos = Vector3.new(0, 0.248, 0),
					},
				},
			},
			{
				time = 0.367,
				pose = {
					Root = {
						rot = Vector3.new(2.31, 34.18, 1.64),
						pos = Vector3.new(0.12, -0.15, 0.172),
					},
					Neck = { rot = Vector3.new(-4.13, -24.7, 0) },
					RightShoulder = { rot = Vector3.new(103.12, 0, 11.55) },
					LeftShoulder = { rot = Vector3.new(-20.16, 0, 12.22) },
					RightHip = { rot = Vector3.new(3.2, 0, -3.14), pos = Vector3.new(0, 0.088, 0) },
					LeftHip = { rot = Vector3.new(-0.48, 0, -9.65), pos = Vector3.new(0, 0.244, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-3.49, 27.45, 0.67),
						pos = Vector3.new(0.098, -0.206, 0.108),
					},
					Neck = { rot = Vector3.new(9.78, -13.65, 0) },
					RightShoulder = { rot = Vector3.new(94.39, 0, 1.21) },
					LeftShoulder = { rot = Vector3.new(-27.56, 0, 16.71) },
					RightHip = { rot = Vector3.new(10, 0, 1.31), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(2.22, 0, -4.71), pos = Vector3.new(0, 0.227, 0) },
				},
			},
			{
				time = 0.43,
				pose = {
					Root = { rot = Vector3.new(-8, 22, 0), pos = Vector3.new(0.08, -0.25, 0.06) },
					Neck = { rot = Vector3.new(17.09, -7.58, 0) },
					RightShoulder = { rot = Vector3.new(87.18, 0, -7.3) },
					LeftShoulder = { rot = Vector3.new(-29.5, 0, 17.19) },
					RightHip = { rot = Vector3.new(15.64, 0, 3.41), pos = Vector3.new(0, 0.278, 0) },
					LeftHip = { rot = Vector3.new(4.78, 0, -1.65), pos = Vector3.new(0, 0.222, 0) },
				},
			},
			{
				time = 0.467,
				pose = {
					Root = {
						rot = Vector3.new(-11.54, 16.51, -0.14),
						pos = Vector3.new(0.063, -0.29, 0.033),
					},
					Neck = { rot = Vector3.new(19.29, -4.07, 0) },
					RightShoulder = { rot = Vector3.new(76.39, 0, -17.03) },
					LeftShoulder = { rot = Vector3.new(-17.75, 0, 12.81) },
					RightHip = { rot = Vector3.new(20.86, 0, 3.52), pos = Vector3.new(0, 0.307, 0) },
					LeftHip = { rot = Vector3.new(6.9, 0, -0.27), pos = Vector3.new(0, 0.237, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-13.61, 12.76, -0.04),
						pos = Vector3.new(0.052, -0.315, 0.022),
					},
					Neck = { rot = Vector3.new(19.29, -2.61, 0) },
					RightShoulder = { rot = Vector3.new(66.94, 0, -24.45) },
					LeftShoulder = { rot = Vector3.new(-3.35, 0, 12.26) },
					RightHip = { rot = Vector3.new(24.32, 0, 2.8), pos = Vector3.new(0, 0.309, 0) },
					LeftHip = { rot = Vector3.new(8.18, 0, 0), pos = Vector3.new(0, 0.257, 0) },
				},
			},
			{
				time = 0.52,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-14, 12, 0), pos = Vector3.new(0.05, -0.32, 0.02) },
					Neck = { rot = Vector3.new(18.57, -3.46, 0) },
					RightShoulder = { rot = Vector3.new(64.81, 0, -26) },
					LeftShoulder = { rot = Vector3.new(-0.01, 0, 12.13) },
					RightHip = { rot = Vector3.new(25.02, 0, 2.58), pos = Vector3.new(0, 0.308, 0) },
					LeftHip = { rot = Vector3.new(8.42, 0, 0), pos = Vector3.new(0, 0.262, 0) },
				},
			},
			{
				time = 0.533,
				pose = {
					Root = {
						rot = Vector3.new(-13.91, 11.81, 0),
						pos = Vector3.new(0.049, -0.318, 0.012),
					},
					Neck = { rot = Vector3.new(17.56, -4.46, 0) },
					RightShoulder = { rot = Vector3.new(63.2, 0, -23.96) },
					LeftShoulder = { rot = Vector3.new(0.63, 0, 12.11) },
					RightHip = { rot = Vector3.new(24.76, 0, 2.47), pos = Vector3.new(0, 0.305, 0) },
					LeftHip = { rot = Vector3.new(8.05, 0, -0.06), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.567,
				pose = {
					Root = {
						rot = Vector3.new(-13.08, 9.96, 0),
						pos = Vector3.new(0.039, -0.295, -0.066),
					},
					Neck = { rot = Vector3.new(13.99, -4.26, 0) },
					RightShoulder = { rot = Vector3.new(49.75, 0, -8.56) },
					LeftShoulder = { rot = Vector3.new(6.56, 0, 11.9) },
					RightHip = { rot = Vector3.new(22.09, 0, 1.43), pos = Vector3.new(0, 0.282, 0) },
					LeftHip = { rot = Vector3.new(4.63, 0, -0.54), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-11.8, 6.99, 0),
						pos = Vector3.new(0.023, -0.259, -0.203),
					},
					Neck = { rot = Vector3.new(10.36, -0.58, 0) },
					RightShoulder = { rot = Vector3.new(35.2, 0, -0.56) },
					LeftShoulder = { rot = Vector3.new(15.4, 0, 11.6) },
					RightHip = { rot = Vector3.new(17.42, 0, 0.09), pos = Vector3.new(0, 0.245, 0) },
					LeftHip = { rot = Vector3.new(6.97, 0, 0.07), pos = Vector3.new(0, 0.377, 0) },
				},
			},
			{
				time = 0.633,
				pose = {
					Root = {
						rot = Vector3.new(-10.58, 3.89, 0),
						pos = Vector3.new(0.008, -0.222, -0.368),
					},
					Neck = { rot = Vector3.new(7.63, 2.75, 0) },
					RightShoulder = { rot = Vector3.new(20.21, 0, -5.43) },
					LeftShoulder = { rot = Vector3.new(22.65, 0, 10.05) },
					RightHip = {
						rot = Vector3.new(11.95, 0, -0.83),
						pos = Vector3.new(0, 0.205, 0),
					},
					LeftHip = { rot = Vector3.new(16.61, 0, 0.84), pos = Vector3.new(0, 0.406, 0) },
				},
			},
			{
				time = 0.647,
				pose = {
					Root = {
						rot = Vector3.new(-10.23, 2.85, 0),
						pos = Vector3.new(0.003, -0.209, -0.435),
					},
					Neck = { rot = Vector3.new(6.95, 3.48, 0) },
					RightShoulder = { rot = Vector3.new(15.77, 0, -8.05) },
					LeftShoulder = { rot = Vector3.new(24.15, 0, 9.47) },
					RightHip = { rot = Vector3.new(9.84, 0, -1.03), pos = Vector3.new(0, 0.191, 0) },
					LeftHip = { rot = Vector3.new(21.36, 0, 0.92), pos = Vector3.new(0, 0.347, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = { rot = Vector3.new(-10, 2, 0), pos = Vector3.new(0, -0.2, -0.5) },
					Neck = { rot = Vector3.new(6.6, 3.77, 0) },
					RightShoulder = { rot = Vector3.new(13.5, 0, -9.59) },
					LeftShoulder = { rot = Vector3.new(24.44, 0, 9.04) },
					RightHip = { rot = Vector3.new(7.9, 0, -1.15), pos = Vector3.new(0, 0.178, 0) },
					LeftHip = { rot = Vector3.new(25.99, 0, 0.87), pos = Vector3.new(0, 0.253, 0) },
				},
			},
			{
				time = 0.68,
				pose = {
					Root = {
						rot = Vector3.new(-9.91, 0.96, 0),
						pos = Vector3.new(-0.003, -0.19, -0.617),
					},
					Neck = { rot = Vector3.new(6.64, 3.61, 0) },
					RightShoulder = { rot = Vector3.new(13.37, 0, -10.28) },
					LeftShoulder = { rot = Vector3.new(21.65, 0, 8.6) },
					RightHip = { rot = Vector3.new(7.4, 0, -1.02), pos = Vector3.new(0, 0.246, 0) },
					LeftHip = { rot = Vector3.new(30.37, 0, 0.56), pos = Vector3.new(0, 0.107, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = {
						rot = Vector3.new(-10.05, 0.01, 0),
						pos = Vector3.new(-0.003, -0.182, -0.765),
					},
					Neck = { rot = Vector3.new(7.06, 3.13, 0) },
					RightShoulder = { rot = Vector3.new(15.14, 0, -10.49) },
					LeftShoulder = { rot = Vector3.new(15.35, 0, 8.37) },
					RightHip = {
						rot = Vector3.new(10.78, 0, -0.59),
						pos = Vector3.new(0, 0.344, 0),
					},
					LeftHip = { rot = Vector3.new(29.02, 0, 0.1), pos = Vector3.new(0, 0.058, 0) },
				},
			},
			{
				time = 0.717,
				pose = {
					Root = {
						rot = Vector3.new(-10.28, -0.68, 0),
						pos = Vector3.new(-0.003, -0.177, -0.894),
					},
					Neck = { rot = Vector3.new(7.54, 2.65, 0) },
					RightShoulder = { rot = Vector3.new(17.47, 0, -10.43) },
					LeftShoulder = { rot = Vector3.new(8.6, 0, 8.42) },
					RightHip = {
						rot = Vector3.new(15.61, 0, -0.22),
						pos = Vector3.new(0, 0.374, 0),
					},
					LeftHip = { rot = Vector3.new(25.06, 0, -0.2), pos = Vector3.new(0, 0.099, 0) },
				},
			},
			{
				time = 0.733,
				pose = {
					Root = {
						rot = Vector3.new(-10.54, -1.25, 0),
						pos = Vector3.new(-0.002, -0.174, -1.017),
					},
					Neck = { rot = Vector3.new(8, 2.2, 0) },
					RightShoulder = { rot = Vector3.new(20.08, 0, -10.25) },
					LeftShoulder = { rot = Vector3.new(1.66, 0, 8.68) },
					RightHip = { rot = Vector3.new(21.46, 0, 0.07), pos = Vector3.new(0, 0.325, 0) },
					LeftHip = { rot = Vector3.new(21.54, 0, -0.4), pos = Vector3.new(0, 0.127, 0) },
				},
			},
			{
				time = 0.767,
				pose = {
					Root = {
						rot = Vector3.new(-10.95, -1.93, 0),
						pos = Vector3.new(0, -0.17, -1.182),
					},
					Neck = { rot = Vector3.new(8.51, 1.27, 0) },
					RightShoulder = { rot = Vector3.new(24.14, 0, -9.87) },
					LeftShoulder = { rot = Vector3.new(-8.02, 0, 9.36) },
					RightHip = { rot = Vector3.new(31.77, 0, 0.33), pos = Vector3.new(0, 0.066, 0) },
					LeftHip = { rot = Vector3.new(17.04, 0, -0.57), pos = Vector3.new(0, 0.151, 0) },
				},
			},
			{
				time = 0.78,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-11, -2, 0), pos = Vector3.new(0, -0.17, -1.2) },
					Neck = { rot = Vector3.new(8.47, 0.91, 0) },
					RightShoulder = { rot = Vector3.new(24.62, 0, -9.82) },
					LeftShoulder = { rot = Vector3.new(-9.09, 0, 9.46) },
					RightHip = { rot = Vector3.new(33.25, 0, 0.34), pos = Vector3.new(0, 0.002, 0) },
					LeftHip = { rot = Vector3.new(16.56, 0, -0.58), pos = Vector3.new(0, 0.153, 0) },
				},
			},
			{
				time = 0.784,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-16, -6, -2), pos = Vector3.new(0, -0.5, 0.05) },
					Neck = { rot = Vector3.new(-0.68, 9.12, 0) },
					RightShoulder = { rot = Vector3.new(37.36, 0, 2.03) },
					LeftShoulder = { rot = Vector3.new(31.86, 0, -4.5) },
					RightHip = { rot = Vector3.new(16.03, 0, 4.25), pos = Vector3.new(0, 0.515, 0) },
					LeftHip = { rot = Vector3.new(29.66, 0, -3.65), pos = Vector3.new(0, 0.446, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-16.46, -6.17, -1.8),
						pos = Vector3.new(0, -0.513, 0.051),
					},
					Neck = { rot = Vector3.new(-0.05, 9.15, 0.09) },
					RightShoulder = { rot = Vector3.new(35.59, 0, 1.7) },
					LeftShoulder = { rot = Vector3.new(30.52, 0, -4.05) },
					RightHip = { rot = Vector3.new(16.52, 0, 3.91), pos = Vector3.new(0, 0.523, 0) },
					LeftHip = { rot = Vector3.new(30.1, 0, -4.03), pos = Vector3.new(0, 0.464, 0) },
				},
			},
			{
				time = 0.833,
				pose = {
					Root = {
						rot = Vector3.new(-18.63, -7.19, -0.69),
						pos = Vector3.new(0, -0.574, 0.053),
					},
					Neck = { rot = Vector3.new(3.98, 11.12, 0.36) },
					RightShoulder = { rot = Vector3.new(27.37, 0, -1.17) },
					LeftShoulder = { rot = Vector3.new(23.8, 0, -0.44) },
					RightHip = { rot = Vector3.new(19.14, 0, 2), pos = Vector3.new(0, 0.55, 0) },
					LeftHip = { rot = Vector3.new(31.7, 0, -6.05), pos = Vector3.new(0, 0.558, 0) },
				},
			},
			{
				time = 0.86,
				pose = {
					Root = { rot = Vector3.new(-19, -8, 0), pos = Vector3.new(0, -0.58, 0.05) },
					Neck = { rot = Vector3.new(3.51, 11.02, 0) },
					RightShoulder = { rot = Vector3.new(26.57, 0, -4.72) },
					LeftShoulder = { rot = Vector3.new(23.2, 0, 3.71) },
					RightHip = { rot = Vector3.new(19.78, 0, 0.88), pos = Vector3.new(0, 0.536, 0) },
					LeftHip = { rot = Vector3.new(31.56, 0, -7.25), pos = Vector3.new(0, 0.586, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(-15.42, -8.8, 0.17),
						pos = Vector3.new(0, -0.47, 0.033),
					},
					Neck = { rot = Vector3.new(1.7, 13.5, -2.33) },
					RightShoulder = { rot = Vector3.new(52.96, 0, -15.11) },
					LeftShoulder = { rot = Vector3.new(51.91, 0, 15.98) },
					RightHip = { rot = Vector3.new(15.99, 0, 0.98), pos = Vector3.new(0, 0.432, 0) },
					LeftHip = { rot = Vector3.new(27.27, 0, -7.33), pos = Vector3.new(0, 0.485, 0) },
				},
			},
			{
				time = 0.933,
				pose = {
					Root = {
						rot = Vector3.new(-11.25, -9.38, 0.09),
						pos = Vector3.new(0, -0.341, 0.014),
					},
					Neck = { rot = Vector3.new(0.22, 15.46, -4.71) },
					RightShoulder = { rot = Vector3.new(77, 0, -25.01) },
					LeftShoulder = { rot = Vector3.new(75.52, 0, 26.86) },
					RightHip = { rot = Vector3.new(10.66, 0, 1.66), pos = Vector3.new(0, 0.339, 0) },
					LeftHip = { rot = Vector3.new(22.04, 0, -6.76), pos = Vector3.new(0, 0.359, 0) },
				},
			},
			{
				time = 0.97,
				pose = {
					Root = { rot = Vector3.new(-8, -10, 0), pos = Vector3.new(0, -0.22, 0) },
					Neck = { rot = Vector3.new(1.09, 16.47, -6) },
					RightShoulder = { rot = Vector3.new(101.23, 0, -33.76) },
					LeftShoulder = { rot = Vector3.new(102.9, 0, 37.04) },
					RightHip = { rot = Vector3.new(3.57, 0, 1.64), pos = Vector3.new(0, 0.299, 0) },
					LeftHip = { rot = Vector3.new(17.64, 0, -6.18), pos = Vector3.new(0, 0.242, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = {
						rot = Vector3.new(-7.19, -10.57, 0),
						pos = Vector3.new(0, -0.147, -0.004),
					},
					Neck = { rot = Vector3.new(3.03, 15.62, -5.19) },
					RightShoulder = { rot = Vector3.new(106.89, 0, -35.41) },
					LeftShoulder = { rot = Vector3.new(108.75, 0, 37.91) },
					RightHip = { rot = Vector3.new(-0.21, 0, 0.96), pos = Vector3.new(0, 0.217, 0) },
					LeftHip = { rot = Vector3.new(14.49, 0, -5.49), pos = Vector3.new(0, 0.207, 0) },
				},
			},
			{
				time = 1.033,
				pose = {
					Root = {
						rot = Vector3.new(-7.24, -11.24, 0),
						pos = Vector3.new(0, -0.074, -0.003),
					},
					Neck = { rot = Vector3.new(4.92, 13.5, -3.12) },
					RightShoulder = { rot = Vector3.new(109.92, 0, -36.22) },
					LeftShoulder = { rot = Vector3.new(112.61, 0, 37.8) },
					RightHip = { rot = Vector3.new(-1.6, 0, 0.31), pos = Vector3.new(0, 0.083, 0) },
					LeftHip = { rot = Vector3.new(6.55, 0, -2.72), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 1.067,
				pose = {
					Root = {
						rot = Vector3.new(-7.71, -11.78, 0),
						pos = Vector3.new(0, -0.021, -0.001),
					},
					Neck = { rot = Vector3.new(5.88, 11.24, -0.98) },
					RightShoulder = { rot = Vector3.new(110.92, 0, -36.48) },
					LeftShoulder = { rot = Vector3.new(114.5, 0, 37.3) },
					RightHip = { rot = Vector3.new(-0.59, 0, 0.11), pos = Vector3.new(0, 0.022, 0) },
					LeftHip = { rot = Vector3.new(0.33, 0, -0.22), pos = Vector3.new(0, 0.041, 0) },
				},
			},
			{
				time = 1.1,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
		},
	},
	Rift_Swarm = {
		length = 0.9,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
			{
				time = 0.033,
				pose = {
					Root = {
						rot = Vector3.new(-6.47, -11.03, 0),
						pos = Vector3.new(-0.001, -0.006, 0.017),
					},
					Neck = { rot = Vector3.new(3.9, 9.08, 0) },
					RightShoulder = { rot = Vector3.new(119.62, 0, -29.94) },
					LeftShoulder = { rot = Vector3.new(83.88, 0, 44.44) },
					RightHip = { rot = Vector3.new(-2.01, 0, 0.36), pos = Vector3.new(0, 0.014, 0) },
					LeftHip = { rot = Vector3.new(-1.56, 0, 0.38), pos = Vector3.new(0, 0.002, 0) },
				},
			},
			{
				time = 0.05,
				pose = {
					Root = {
						rot = Vector3.new(-4.86, -10.03, 0),
						pos = Vector3.new(-0.002, -0.013, 0.035),
					},
					Neck = { rot = Vector3.new(1.52, 8.05, 0) },
					RightShoulder = { rot = Vector3.new(127.26, 0, -23.53) },
					LeftShoulder = { rot = Vector3.new(66.56, 0, 32.8) },
					RightHip = { rot = Vector3.new(-4.14, 0, 0.68), pos = Vector3.new(0, 0.027, 0) },
					LeftHip = { rot = Vector3.new(-3.21, 0, 0.71), pos = Vector3.new(0, 0.005, 0) },
				},
			},
			{
				time = 0.067,
				pose = {
					Root = {
						rot = Vector3.new(-2.94, -8.88, 0),
						pos = Vector3.new(-0.002, -0.022, 0.056),
					},
					Neck = { rot = Vector3.new(-1.42, 6.79, 0) },
					RightShoulder = { rot = Vector3.new(134.44, 0, -17.5) },
					LeftShoulder = { rot = Vector3.new(49.49, 0, 8.28) },
					RightHip = { rot = Vector3.new(-6.66, 0, 0.96), pos = Vector3.new(0, 0.04, 0) },
					LeftHip = { rot = Vector3.new(-5.2, 0, 1.02), pos = Vector3.new(0, 0.01, 0) },
				},
			},
			{
				time = 0.083,
				pose = {
					Root = {
						rot = Vector3.new(-0.94, -7.73, 0),
						pos = Vector3.new(-0.003, -0.032, 0.077),
					},
					Neck = { rot = Vector3.new(-4.54, 5.53, 0) },
					RightShoulder = { rot = Vector3.new(140.34, 0, -12.51) },
					LeftShoulder = { rot = Vector3.new(34.54, 0, -2.44) },
					RightHip = { rot = Vector3.new(-9.3, 0, 1.16), pos = Vector3.new(0, 0.052, 0) },
					LeftHip = { rot = Vector3.new(-7.31, 0, 1.26), pos = Vector3.new(0, 0.016, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(0.95, -6.73, 0),
						pos = Vector3.new(-0.003, -0.043, 0.097),
					},
					Neck = { rot = Vector3.new(-7.29, 4.58, 0) },
					RightShoulder = { rot = Vector3.new(147.14, 0, -7.08) },
					LeftShoulder = { rot = Vector3.new(19.03, 0, -3.27) },
					RightHip = {
						rot = Vector3.new(-11.79, 0, 1.26),
						pos = Vector3.new(0, 0.063, 0),
					},
					LeftHip = { rot = Vector3.new(-9.33, 0, 1.4), pos = Vector3.new(0, 0.023, 0) },
				},
			},
			{
				time = 0.117,
				pose = {
					Root = {
						rot = Vector3.new(2.54, -6.01, 0),
						pos = Vector3.new(-0.003, -0.055, 0.112),
					},
					Neck = { rot = Vector3.new(-9.4, 4.08, 0) },
					RightShoulder = { rot = Vector3.new(154.51, 0, -1.6) },
					LeftShoulder = { rot = Vector3.new(3.89, 0, 0.43) },
					RightHip = { rot = Vector3.new(-13.86, 0, 1.3), pos = Vector3.new(0, 0.073, 0) },
					LeftHip = { rot = Vector3.new(-11.08, 0, 1.48), pos = Vector3.new(0, 0.032, 0) },
				},
			},
			{
				time = 0.133,
				pose = {
					Root = {
						rot = Vector3.new(3.62, -5.72, 0),
						pos = Vector3.new(-0.002, -0.068, 0.12),
					},
					Neck = { rot = Vector3.new(-10.55, 4.2, 0) },
					RightShoulder = { rot = Vector3.new(161.08, 0, 2.97) },
					LeftShoulder = { rot = Vector3.new(-13.8, 0, 10.86) },
					RightHip = {
						rot = Vector3.new(-15.26, 0, 1.32),
						pos = Vector3.new(0, 0.083, 0),
					},
					LeftHip = { rot = Vector3.new(-12.36, 0, 1.52), pos = Vector3.new(0, 0.041, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(4, -6, 0), pos = Vector3.new(0, -0.08, 0.12) },
					Neck = { rot = Vector3.new(-10.46, 5.1, 0) },
					RightShoulder = { rot = Vector3.new(165.05, 0, 5.83) },
					LeftShoulder = { rot = Vector3.new(-26.57, 0, 15.67) },
					RightHip = { rot = Vector3.new(-15.73, 0, 1.4), pos = Vector3.new(0, 0.095, 0) },
					LeftHip = { rot = Vector3.new(-12.98, 0, 1.59), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.167,
				pose = {
					Root = {
						rot = Vector3.new(3.7, -6.9, 0),
						pos = Vector3.new(0.003, -0.093, 0.11),
					},
					Neck = { rot = Vector3.new(-9.22, 6.79, 0) },
					RightShoulder = { rot = Vector3.new(166.9, 0, 7.57) },
					LeftShoulder = { rot = Vector3.new(-18.22, 0, 12.23) },
					RightHip = { rot = Vector3.new(-15.3, 0, 1.53), pos = Vector3.new(0, 0.111, 0) },
					LeftHip = { rot = Vector3.new(-13.02, 0, 1.68), pos = Vector3.new(0, 0.061, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(1.89, -10.01, 0),
						pos = Vector3.new(0.012, -0.127, 0.073),
					},
					Neck = { rot = Vector3.new(-4.99, 11.69, 0) },
					RightShoulder = { rot = Vector3.new(169.4, 0, 10.66) },
					LeftShoulder = { rot = Vector3.new(4.51, 0, 4.99) },
					RightHip = {
						rot = Vector3.new(-12.88, 0, 1.82),
						pos = Vector3.new(0, 0.151, 0),
					},
					LeftHip = { rot = Vector3.new(-10.27, 0, 1.37), pos = Vector3.new(0, 0.161, 0) },
				},
			},
			{
				time = 0.233,
				pose = {
					Root = {
						rot = Vector3.new(-0.97, -14.2, 0),
						pos = Vector3.new(0.023, -0.164, 0.02),
					},
					Neck = { rot = Vector3.new(-0.09, 17.16, 0) },
					RightShoulder = { rot = Vector3.new(170.67, 0, 13.3) },
					LeftShoulder = { rot = Vector3.new(24.57, 0, -2.39) },
					RightHip = { rot = Vector3.new(-8.89, 0, 2.86), pos = Vector3.new(0, 0.244, 0) },
					LeftHip = { rot = Vector3.new(-0.33, 0, -1.77), pos = Vector3.new(0, 0.37, 0) },
				},
			},
			{
				time = 0.267,
				pose = {
					Root = {
						rot = Vector3.new(-4.17, -18.61, 0),
						pos = Vector3.new(0.034, -0.201, -0.037),
					},
					Neck = { rot = Vector3.new(4.4, 21.9, 0) },
					RightShoulder = { rot = Vector3.new(171.05, 0, 15.47) },
					LeftShoulder = { rot = Vector3.new(45.99, 0, -7.21) },
					RightHip = { rot = Vector3.new(-4.09, 0, 4.5), pos = Vector3.new(0, 0.292, 0) },
					LeftHip = { rot = Vector3.new(11.25, 0, -7.5), pos = Vector3.new(0, 0.432, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-7, -22.38, 0),
						pos = Vector3.new(0.044, -0.23, -0.086),
					},
					Neck = { rot = Vector3.new(7.65, 25.04, 0) },
					RightShoulder = { rot = Vector3.new(170.89, 0, 17.06) },
					LeftShoulder = { rot = Vector3.new(68.85, 0, -8.73) },
					RightHip = { rot = Vector3.new(0.36, 0, 5.31), pos = Vector3.new(0, 0.248, 0) },
					LeftHip = {
						rot = Vector3.new(19.97, 0, -13.45),
						pos = Vector3.new(0, 0.331, 0),
					},
				},
			},
			{
				time = 0.333,
				pose = {
					Root = {
						rot = Vector3.new(-8.75, -24.67, 0),
						pos = Vector3.new(0.049, -0.248, -0.116),
					},
					Neck = { rot = Vector3.new(8.77, 25.77, 0) },
					RightShoulder = { rot = Vector3.new(170.6, 0, 17.94) },
					LeftShoulder = { rot = Vector3.new(96.22, 0, -5.66) },
					RightHip = { rot = Vector3.new(2.78, 0, 4.85), pos = Vector3.new(0, 0.219, 0) },
					LeftHip = { rot = Vector3.new(21.9, 0, -15.91), pos = Vector3.new(0, 0.303, 0) },
				},
			},
			{
				time = 0.35,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-9, -25, 0), pos = Vector3.new(0.05, -0.25, -0.12) },
					Neck = { rot = Vector3.new(8.28, 25, 0) },
					RightShoulder = { rot = Vector3.new(170.54, 0, 18.06) },
					LeftShoulder = { rot = Vector3.new(102.42, 0, -4.23) },
					RightHip = { rot = Vector3.new(3.09, 0, 4.71), pos = Vector3.new(0, 0.218, 0) },
					LeftHip = {
						rot = Vector3.new(21.91, 0, -16.14),
						pos = Vector3.new(0, 0.309, 0),
					},
				},
			},
			{
				time = 0.367,
				pose = {
					Root = {
						rot = Vector3.new(-9.11, -24.81, 0),
						pos = Vector3.new(0.05, -0.251, -0.121),
					},
					Neck = { rot = Vector3.new(7.4, 23.7, 0) },
					RightShoulder = { rot = Vector3.new(167.44, 0, 15.73) },
					LeftShoulder = { rot = Vector3.new(102.53, 0, -4.03) },
					RightHip = { rot = Vector3.new(3.14, 0, 4.67), pos = Vector3.new(0, 0.218, 0) },
					LeftHip = { rot = Vector3.new(22.12, 0, -16.12), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-9.86, -23.59, 0),
						pos = Vector3.new(0.05, -0.259, -0.128),
					},
					Neck = { rot = Vector3.new(6.04, 20.96, 0) },
					RightShoulder = { rot = Vector3.new(154.02, 0, 3.08) },
					LeftShoulder = { rot = Vector3.new(103.07, 0, -2.76) },
					RightHip = { rot = Vector3.new(3.48, 0, 4.41), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = {
						rot = Vector3.new(23.51, 0, -15.94),
						pos = Vector3.new(0, 0.312, 0),
					},
				},
			},
			{
				time = 0.433,
				pose = {
					Root = {
						rot = Vector3.new(-10.95, -21.81, 0),
						pos = Vector3.new(0.05, -0.269, -0.139),
					},
					Neck = { rot = Vector3.new(5.66, 18.91, 0) },
					RightShoulder = { rot = Vector3.new(145.22, 0, -8.96) },
					LeftShoulder = { rot = Vector3.new(103.82, 0, -0.9) },
					RightHip = { rot = Vector3.new(3.97, 0, 4.09), pos = Vector3.new(0, 0.223, 0) },
					LeftHip = {
						rot = Vector3.new(25.53, 0, -15.58),
						pos = Vector3.new(0, 0.314, 0),
					},
				},
			},
			{
				time = 0.47,
				pose = {
					Root = { rot = Vector3.new(-12, -20, 0), pos = Vector3.new(0.05, -0.28, -0.15) },
					Neck = { rot = Vector3.new(5.39, 17.67, 0) },
					RightShoulder = { rot = Vector3.new(135.03, 0, -20.78) },
					LeftShoulder = { rot = Vector3.new(104.51, 0, 0.97) },
					RightHip = { rot = Vector3.new(4.42, 0, 3.83), pos = Vector3.new(0, 0.227, 0) },
					LeftHip = {
						rot = Vector3.new(27.52, 0, -15.11),
						pos = Vector3.new(0, 0.313, 0),
					},
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-12.78, -18.87, 0),
						pos = Vector3.new(0.051, -0.29, -0.162),
					},
					Neck = { rot = Vector3.new(5.59, 17.08, 0) },
					RightShoulder = { rot = Vector3.new(119.21, 0, -24.39) },
					LeftShoulder = { rot = Vector3.new(104.86, 0, 1.62) },
					RightHip = { rot = Vector3.new(4.7, 0, 3.67), pos = Vector3.new(0, 0.232, 0) },
					LeftHip = {
						rot = Vector3.new(28.75, 0, -14.79),
						pos = Vector3.new(0, 0.316, 0),
					},
				},
			},
			{
				time = 0.533,
				pose = {
					Root = {
						rot = Vector3.new(-13.64, -17.68, 0),
						pos = Vector3.new(0.053, -0.302, -0.177),
					},
					Neck = { rot = Vector3.new(6.31, 16.23, 0) },
					RightShoulder = { rot = Vector3.new(99.83, 0, -26) },
					LeftShoulder = { rot = Vector3.new(105.18, 0, 2.01) },
					RightHip = { rot = Vector3.new(4.98, 0, 3.5), pos = Vector3.new(0, 0.238, 0) },
					LeftHip = {
						rot = Vector3.new(30.01, 0, -14.42),
						pos = Vector3.new(0, 0.322, 0),
					},
				},
			},
			{
				time = 0.567,
				pose = {
					Root = {
						rot = Vector3.new(-14.06, -16.49, 0),
						pos = Vector3.new(0.052, -0.304, -0.183),
					},
					Neck = { rot = Vector3.new(6.74, 14.98, 0) },
					RightShoulder = { rot = Vector3.new(77.39, 0, -27.6) },
					LeftShoulder = { rot = Vector3.new(105.44, 0, 3.64) },
					RightHip = { rot = Vector3.new(5, 0, 3.51), pos = Vector3.new(0, 0.238, 0) },
					LeftHip = {
						rot = Vector3.new(31.06, 0, -13.89),
						pos = Vector3.new(0, 0.313, 0),
					},
				},
			},
			{
				time = 0.58,
				pose = {
					Root = { rot = Vector3.new(-14, -16, 0), pos = Vector3.new(0.05, -0.3, -0.18) },
					Neck = { rot = Vector3.new(6.58, 14.46, 0) },
					RightShoulder = { rot = Vector3.new(74.06, 0, -28.18) },
					LeftShoulder = { rot = Vector3.new(105.54, 0, 5.02) },
					RightHip = { rot = Vector3.new(4.89, 0, 3.6), pos = Vector3.new(0, 0.236, 0) },
					LeftHip = {
						rot = Vector3.new(31.39, 0, -13.59),
						pos = Vector3.new(0, 0.302, 0),
					},
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-13.66, -15.2, 0),
						pos = Vector3.new(0.045, -0.288, -0.17),
					},
					Neck = { rot = Vector3.new(6.07, 13.55, 0) },
					RightShoulder = { rot = Vector3.new(74.98, 0, -29.35) },
					LeftShoulder = { rot = Vector3.new(105.63, 0, 8.03) },
					RightHip = { rot = Vector3.new(4.56, 0, 3.82), pos = Vector3.new(0, 0.229, 0) },
					LeftHip = { rot = Vector3.new(31.8, 0, -13.04), pos = Vector3.new(0, 0.277, 0) },
				},
			},
			{
				time = 0.633,
				pose = {
					Root = {
						rot = Vector3.new(-12.66, -13.72, 0),
						pos = Vector3.new(0.035, -0.261, -0.144),
					},
					Neck = { rot = Vector3.new(5.02, 11.76, 0) },
					RightShoulder = { rot = Vector3.new(80.29, 0, -31.68) },
					LeftShoulder = { rot = Vector3.new(105.62, 0, 14.85) },
					RightHip = { rot = Vector3.new(3.69, 0, 4.35), pos = Vector3.new(0, 0.214, 0) },
					LeftHip = {
						rot = Vector3.new(32.34, 0, -11.87),
						pos = Vector3.new(0, 0.223, 0),
					},
				},
			},
			{
				time = 0.667,
				pose = {
					Root = {
						rot = Vector3.new(-11.39, -12.22, 0),
						pos = Vector3.new(0.022, -0.227, -0.112),
					},
					Neck = { rot = Vector3.new(4.21, 9.99, 0) },
					RightShoulder = { rot = Vector3.new(88.66, 0, -34.01) },
					LeftShoulder = { rot = Vector3.new(105.59, 0, 22.78) },
					RightHip = { rot = Vector3.new(2.6, 0, 4.93), pos = Vector3.new(0, 0.194, 0) },
					LeftHip = { rot = Vector3.new(32.37, 0, -10.54), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = {
						rot = Vector3.new(-10.12, -10.94, 0),
						pos = Vector3.new(0.01, -0.191, -0.08),
					},
					Neck = { rot = Vector3.new(3.8, 8.69, 0) },
					RightShoulder = { rot = Vector3.new(97.53, 0, -35.77) },
					LeftShoulder = { rot = Vector3.new(105.75, 0, 30.13) },
					RightHip = { rot = Vector3.new(1.54, 0, 5.45), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(25.44, 0, -7.6), pos = Vector3.new(0, 0.264, 0) },
				},
			},
			{
				time = 0.74,
				pose = {
					Root = { rot = Vector3.new(-9, -10, 0), pos = Vector3.new(0, -0.15, -0.05) },
					Neck = { rot = Vector3.new(3.93, 8.02, 0) },
					RightShoulder = { rot = Vector3.new(105.04, 0, -36.91) },
					LeftShoulder = { rot = Vector3.new(106.5, 0, 36.14) },
					RightHip = { rot = Vector3.new(0.5, 0, 5.44), pos = Vector3.new(0, 0.161, 0) },
					LeftHip = { rot = Vector3.new(11.97, 0, -3.28), pos = Vector3.new(0, 0.304, 0) },
				},
			},
			{
				time = 0.767,
				pose = {
					Root = {
						rot = Vector3.new(-8.58, -9.92, 0),
						pos = Vector3.new(-0.003, -0.121, -0.036),
					},
					Neck = { rot = Vector3.new(4.35, 8.23, 0) },
					RightShoulder = { rot = Vector3.new(107.6, 0, -37.21) },
					LeftShoulder = { rot = Vector3.new(107.67, 0, 37.99) },
					RightHip = { rot = Vector3.new(-0.19, 0, 4.06), pos = Vector3.new(0, 0.172, 0) },
					LeftHip = { rot = Vector3.new(4.17, 0, -1), pos = Vector3.new(0, 0.208, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-8.24, -10.34, 0),
						pos = Vector3.new(-0.004, -0.081, -0.021),
					},
					Neck = { rot = Vector3.new(4.95, 8.95, 0) },
					RightShoulder = { rot = Vector3.new(109.58, 0, -37.18) },
					LeftShoulder = { rot = Vector3.new(109.87, 0, 38.67) },
					RightHip = { rot = Vector3.new(-0.65, 0, 1.74), pos = Vector3.new(0, 0.128, 0) },
					LeftHip = { rot = Vector3.new(-0.12, 0, 0.21), pos = Vector3.new(0, 0.076, 0) },
				},
			},
			{
				time = 0.833,
				pose = {
					Root = {
						rot = Vector3.new(-8.07, -11.04, 0),
						pos = Vector3.new(-0.003, -0.041, -0.01),
					},
					Neck = { rot = Vector3.new(5.45, 9.68, 0) },
					RightShoulder = { rot = Vector3.new(110.58, 0, -36.93) },
					LeftShoulder = { rot = Vector3.new(112.27, 0, 38.25) },
					RightHip = { rot = Vector3.new(-0.54, 0, 0.19), pos = Vector3.new(0, 0.045, 0) },
					LeftHip = { rot = Vector3.new(-0.09, 0, 0.14), pos = Vector3.new(0, 0.039, 0) },
				},
			},
			{
				time = 0.867,
				pose = {
					Root = {
						rot = Vector3.new(-8.01, -11.71, 0),
						pos = Vector3.new(-0.001, -0.012, -0.003),
					},
					Neck = { rot = Vector3.new(5.83, 10.1, 0) },
					RightShoulder = { rot = Vector3.new(110.95, 0, -36.64) },
					LeftShoulder = { rot = Vector3.new(114.21, 0, 37.44) },
					RightHip = { rot = Vector3.new(-0.16, 0, 0.04), pos = Vector3.new(0, 0.012, 0) },
					LeftHip = { rot = Vector3.new(-0.04, 0, 0.05), pos = Vector3.new(0, 0.011, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
		},
	},
	Rift_Slam = {
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
				},
			},
			{
				time = 0.033,
				pose = {
					Root = {
						rot = Vector3.new(-8.69, -12.13, 0),
						pos = Vector3.new(0, -0.043, 0.01),
					},
					Neck = { rot = Vector3.new(6.76, 10.03, 0) },
					RightShoulder = { rot = Vector3.new(103.26, 0, -35.83) },
					LeftShoulder = { rot = Vector3.new(103.43, 0, 35.72) },
					RightHip = { rot = Vector3.new(1.15, 0, -0.24), pos = Vector3.new(0, 0.04, 0) },
					LeftHip = { rot = Vector3.new(1.06, 0, -0.23), pos = Vector3.new(0, 0.047, 0) },
				},
			},
			{
				time = 0.067,
				pose = {
					Root = {
						rot = Vector3.new(-10.41, -12.46, 0),
						pos = Vector3.new(0, -0.15, 0.035),
					},
					Neck = { rot = Vector3.new(8.82, 10.14, 0) },
					RightShoulder = { rot = Vector3.new(86.46, 0, -33.34) },
					LeftShoulder = { rot = Vector3.new(85.08, 0, 32.3) },
					RightHip = { rot = Vector3.new(3.85, 0, -0.83), pos = Vector3.new(0, 0.141, 0) },
					LeftHip = { rot = Vector3.new(3.56, 0, -0.81), pos = Vector3.new(0, 0.164, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-12.56, -12.91, 0),
						pos = Vector3.new(0, -0.291, 0.068),
					},
					Neck = { rot = Vector3.new(11.37, 10.29, 0) },
					RightShoulder = { rot = Vector3.new(71.23, 0, -29.95) },
					LeftShoulder = { rot = Vector3.new(70.7, 0, 28.55) },
					RightHip = { rot = Vector3.new(7.03, 0, -1.55), pos = Vector3.new(0, 0.271, 0) },
					LeftHip = { rot = Vector3.new(6.45, 0, -1.53), pos = Vector3.new(0, 0.316, 0) },
				},
			},
			{
				time = 0.133,
				pose = {
					Root = {
						rot = Vector3.new(-14.58, -13.37, 0),
						pos = Vector3.new(0, -0.433, 0.102),
					},
					Neck = { rot = Vector3.new(13.36, 10.39, 0) },
					RightShoulder = { rot = Vector3.new(59.21, 0, -26.47) },
					LeftShoulder = { rot = Vector3.new(56.68, 0, 23.74) },
					RightHip = { rot = Vector3.new(9.82, 0, -2.23), pos = Vector3.new(0, 0.403, 0) },
					LeftHip = { rot = Vector3.new(8.88, 0, -2.18), pos = Vector3.new(0, 0.47, 0) },
				},
			},
			{
				time = 0.167,
				pose = {
					Root = {
						rot = Vector3.new(-15.92, -13.77, 0),
						pos = Vector3.new(0, -0.547, 0.132),
					},
					Neck = { rot = Vector3.new(14.06, 10.42, 0) },
					RightShoulder = { rot = Vector3.new(45.44, 0, -21.97) },
					LeftShoulder = { rot = Vector3.new(39.16, 0, 18.89) },
					RightHip = { rot = Vector3.new(11.56, 0, -2.7), pos = Vector3.new(0, 0.511, 0) },
					LeftHip = { rot = Vector3.new(10.33, 0, -2.63), pos = Vector3.new(0, 0.593, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-16, -14, 0), pos = Vector3.new(0, -0.6, 0.15) },
					Neck = { rot = Vector3.new(12.8, 10.34, 0) },
					RightShoulder = { rot = Vector3.new(36.17, 0, -18.66) },
					LeftShoulder = { rot = Vector3.new(29.08, 0, 14.74) },
					RightHip = {
						rot = Vector3.new(11.79, 0, -2.79),
						pos = Vector3.new(0, 0.565, 0),
					},
					LeftHip = { rot = Vector3.new(10.42, 0, -2.71), pos = Vector3.new(0, 0.65, 0) },
				},
			},
			{
				time = 0.233,
				pose = {
					Root = {
						rot = Vector3.new(-10.73, -13.69, 0),
						pos = Vector3.new(0, -0.434, 0.129),
					},
					Neck = { rot = Vector3.new(2.95, 9.98, 0) },
					RightShoulder = { rot = Vector3.new(26.4, 0, -15.57) },
					LeftShoulder = { rot = Vector3.new(60.71, 0, 17.74) },
					RightHip = { rot = Vector3.new(5.76, 0, -1.3), pos = Vector3.new(0, 0.427, 0) },
					LeftHip = { rot = Vector3.new(4.82, 0, -1.27), pos = Vector3.new(0, 0.462, 0) },
				},
			},
			{
				time = 0.27,
				pose = {
					Root = { rot = Vector3.new(-2, -13, 0), pos = Vector3.new(0, -0.1, 0.08) },
					Neck = { rot = Vector3.new(-11.88, 9.44, 0) },
					RightShoulder = { rot = Vector3.new(16.21, 0, -12.3) },
					LeftShoulder = { rot = Vector3.new(95.61, 0, 21.27) },
					RightHip = { rot = Vector3.new(-6.28, 0, 1.5), pos = Vector3.new(0, 0.131, 0) },
					LeftHip = { rot = Vector3.new(-6.92, 0, 1.53), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(3.62, -12.55, 0),
						pos = Vector3.new(0, 0.085, 0.047),
					},
					Neck = { rot = Vector3.new(-16.93, 9.39, 0) },
					RightShoulder = { rot = Vector3.new(46.59, 0, 6.06) },
					LeftShoulder = { rot = Vector3.new(133.03, 0, 24.14) },
					RightHip = { rot = Vector3.new(-15.63, 0, 3.73), pos = Vector3.new(0, 0.07, 0) },
					LeftHip = { rot = Vector3.new(-13.8, 0, 3) },
				},
			},
			{
				time = 0.34,
				pose = {
					Root = { rot = Vector3.new(8, -12, 0), pos = Vector3.new(0, 0.362, 0) },
					Neck = { rot = Vector3.new(-18.08, 9.39, 0) },
					RightShoulder = { rot = Vector3.new(103.75, 0, 21.85) },
					LeftShoulder = { rot = Vector3.new(183.66, 0, 26.01) },
					RightHip = {
						rot = Vector3.new(-25.05, 0, 6.37),
						pos = Vector3.new(0, 0.008, 0),
					},
					LeftHip = { rot = Vector3.new(-12.94, 0, 2.91) },
				},
			},
			{
				time = 0.353,
				pose = {
					Root = {
						rot = Vector3.new(7.84, -11.85, 0),
						pos = Vector3.new(0, 0.432, -0.015),
					},
					Neck = { rot = Vector3.new(-16.67, 9.23, 0) },
					RightShoulder = { rot = Vector3.new(107.86, 0, 23.08) },
					LeftShoulder = { rot = Vector3.new(183.24, 0, 25.55) },
					RightHip = { rot = Vector3.new(-25.98, 0, 6.91) },
					LeftHip = { rot = Vector3.new(-9.2, 0, 2.22), pos = Vector3.new(0, 0.019, 0) },
				},
			},
			{
				time = 0.367,
				pose = {
					Root = {
						rot = Vector3.new(7.34, -11.71, 0),
						pos = Vector3.new(0, 0.475, -0.031),
					},
					Neck = { rot = Vector3.new(-14.85, 9.02, 0) },
					RightShoulder = { rot = Vector3.new(110.69, 0, 24.24) },
					LeftShoulder = { rot = Vector3.new(181.29, 0, 25.09) },
					RightHip = { rot = Vector3.new(-26.43, 0, 7.36) },
					LeftHip = { rot = Vector3.new(-4.68, 0, 1.36), pos = Vector3.new(0, 0.045, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(4.54, -11.38, 0),
						pos = Vector3.new(0, 0.509, -0.068),
					},
					Neck = { rot = Vector3.new(-9.13, 8.39, 0) },
					RightShoulder = { rot = Vector3.new(113.59, 0, 27.59) },
					LeftShoulder = { rot = Vector3.new(172.01, 0, 23.86) },
					RightHip = { rot = Vector3.new(-25.26, 0, 8.23) },
					LeftHip = { rot = Vector3.new(9.27, 0, -1.23), pos = Vector3.new(0, 0.037, 0) },
				},
			},
			{
				time = 0.44,
				pose = {
					Root = { rot = Vector3.new(-2, -11, 0), pos = Vector3.new(0, 0.266, -0.12) },
					Neck = { rot = Vector3.new(-0.1, 7.57, 0) },
					RightShoulder = { rot = Vector3.new(108.47, 0, 33.22) },
					LeftShoulder = { rot = Vector3.new(156.85, 0, 22.2) },
					RightHip = {
						rot = Vector3.new(-19.67, 0, 8.34),
						pos = Vector3.new(0, 0.073, 0),
					},
					LeftHip = { rot = Vector3.new(30.62, 0, -4.88) },
				},
			},
			{
				time = 0.467,
				pose = {
					Root = {
						rot = Vector3.new(-10.25, -10.71, 0),
						pos = Vector3.new(0, -0.109, -0.169),
					},
					Neck = { rot = Vector3.new(11.47, 6.96, 0) },
					RightShoulder = { rot = Vector3.new(73.35, 0, 36.5) },
					LeftShoulder = { rot = Vector3.new(136.34, 0, 20.71) },
					RightHip = { rot = Vector3.new(-11.5, 0, 7.47), pos = Vector3.new(0, 0.249, 0) },
					LeftHip = { rot = Vector3.new(49.8, 0, -7.44) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-23.91, -10.31, 0),
						pos = Vector3.new(0, -0.838, -0.24),
					},
					Neck = { rot = Vector3.new(26.03, 6.12, 0) },
					RightShoulder = { rot = Vector3.new(32.52, 0, 25.08) },
					LeftShoulder = { rot = Vector3.new(109.49, 0, 18.44) },
					RightHip = { rot = Vector3.new(-1.71, 0, 6.19), pos = Vector3.new(0, 0.668, 0) },
					LeftHip = { rot = Vector3.new(74.39, 0, -9.04), pos = Vector3.new(0, 0.201, 0) },
				},
			},
			{
				time = 0.517,
				pose = {
					Root = {
						rot = Vector3.new(-30.01, -10.15, 0),
						pos = Vector3.new(0, -1.17, -0.271),
					},
					Neck = { rot = Vector3.new(32.6, 5.8, 0) },
					RightShoulder = { rot = Vector3.new(19.17, 0, 15.8) },
					LeftShoulder = { rot = Vector3.new(96.28, 0, 17.27) },
					RightHip = { rot = Vector3.new(0.68, 0, 5.86), pos = Vector3.new(0, 0.874, 0) },
					LeftHip = { rot = Vector3.new(76.22, 0, -8.87), pos = Vector3.new(0, 0.598, 0) },
				},
			},
			{
				time = 0.533,
				pose = {
					Root = {
						rot = Vector3.new(-34.34, -10.04, 0),
						pos = Vector3.new(0, -1.408, -0.292),
					},
					Neck = { rot = Vector3.new(37.27, 5.63, 0) },
					RightShoulder = { rot = Vector3.new(6.27, 0, 2.52) },
					LeftShoulder = { rot = Vector3.new(79.59, 0, 15.89) },
					RightHip = { rot = Vector3.new(1.04, 0, 5.79), pos = Vector3.new(0, 1.053, 0) },
					LeftHip = { rot = Vector3.new(71.26, 0, -8.24), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.542,
				pose = {
					Root = {
						rot = Vector3.new(-35.56, -10.01, 0),
						pos = Vector3.new(0, -1.476, -0.298),
					},
					Neck = { rot = Vector3.new(38.58, 5.61, 0) },
					RightShoulder = { rot = Vector3.new(1.76, 0, -3.11) },
					LeftShoulder = { rot = Vector3.new(72.84, 0, 15.39) },
					RightHip = { rot = Vector3.new(0.99, 0, 5.79), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(73.56, 0, -7.87), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.55,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-36, -10, 0), pos = Vector3.new(0, -1.5, -0.3) },
					Neck = { rot = Vector3.new(39.04, 5.65, 0) },
					RightShoulder = { rot = Vector3.new(0.01, 0, -5.43) },
					LeftShoulder = { rot = Vector3.new(70.09, 0, 15.2) },
					RightHip = { rot = Vector3.new(0.96, 0, 5.72), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(74.42, 0, -7.73), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.558,
				pose = {
					Root = {
						rot = Vector3.new(-36.11, -9.97, 0),
						pos = Vector3.new(0, -1.5, -0.299),
					},
					Neck = { rot = Vector3.new(39.25, 5.66, 0) },
					RightShoulder = { rot = Vector3.new(-0.02, 0, -5.47) },
					LeftShoulder = { rot = Vector3.new(70.2, 0, 15.23) },
					RightHip = { rot = Vector3.new(1.05, 0, 5.7), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(74.56, 0, -7.71), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.567,
				pose = {
					Root = {
						rot = Vector3.new(-36.38, -9.89, 0),
						pos = Vector3.new(0, -1.502, -0.298),
					},
					Neck = { rot = Vector3.new(39.67, 5.59, 0) },
					RightShoulder = { rot = Vector3.new(-0.08, 0, -5.55) },
					LeftShoulder = { rot = Vector3.new(70.49, 0, 15.33) },
					RightHip = { rot = Vector3.new(1.3, 0, 5.65), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(74.91, 0, -7.64), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.575,
				pose = {
					Root = {
						rot = Vector3.new(-36.77, -9.77, 0),
						pos = Vector3.new(0, -1.503, -0.296),
					},
					Neck = { rot = Vector3.new(38.56, 5.45, 0) },
					RightShoulder = { rot = Vector3.new(-0.14, 0, -5.67) },
					LeftShoulder = { rot = Vector3.new(70.89, 0, 15.47) },
					RightHip = { rot = Vector3.new(1.65, 0, 5.58), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(75.4, 0, -7.55), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.583,
				pose = {
					Root = {
						rot = Vector3.new(-37.19, -9.62, 0),
						pos = Vector3.new(0, -1.504, -0.293),
					},
					Neck = { rot = Vector3.new(37.77, 5.26, 0) },
					RightShoulder = { rot = Vector3.new(-0.21, 0, -5.81) },
					LeftShoulder = { rot = Vector3.new(71.35, 0, 15.63) },
					RightHip = { rot = Vector3.new(2.04, 0, 5.5), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(75.95, 0, -7.44), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.592,
				pose = {
					Root = {
						rot = Vector3.new(-37.6, -9.46, 0),
						pos = Vector3.new(0, -1.505, -0.29),
					},
					Neck = { rot = Vector3.new(37.16, 5.05, 0) },
					RightShoulder = { rot = Vector3.new(-0.25, 0, -5.95) },
					LeftShoulder = { rot = Vector3.new(71.79, 0, 15.81) },
					RightHip = { rot = Vector3.new(2.42, 0, 5.43), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(76.47, 0, -7.31), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-37.93, -9.31, 0),
						pos = Vector3.new(0, -1.505, -0.287),
					},
					Neck = { rot = Vector3.new(36.66, 4.83, 0) },
					RightShoulder = { rot = Vector3.new(-0.26, 0, -6.1) },
					LeftShoulder = { rot = Vector3.new(72.15, 0, 15.98) },
					RightHip = { rot = Vector3.new(2.74, 0, 5.37), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(76.9, 0, -7.19), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.61,
				pose = {
					Root = {
						rot = Vector3.new(-38.12, -9.13, 0),
						pos = Vector3.new(0, -1.504, -0.283),
					},
					Neck = { rot = Vector3.new(36.05, 4.58, 0) },
					RightShoulder = { rot = Vector3.new(-0.18, 0, -6.24) },
					LeftShoulder = { rot = Vector3.new(72.4, 0, 16.16) },
					RightHip = { rot = Vector3.new(2.97, 0, 5.33), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(77.17, 0, -7.07), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.62,
				pose = {
					Root = { rot = Vector3.new(-38, -9, 0), pos = Vector3.new(0, -1.5, -0.28) },
					Neck = { rot = Vector3.new(35.25, 4.37, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, -6.34) },
					LeftShoulder = { rot = Vector3.new(72.33, 0, 16.28) },
					RightHip = { rot = Vector3.new(2.94, 0, 5.34), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(77.06, 0, -6.98), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.627,
				pose = {
					Root = {
						rot = Vector3.new(-37.78, -8.93, 0),
						pos = Vector3.new(0, -1.498, -0.278),
					},
					Neck = { rot = Vector3.new(34.51, 4.27, 0) },
					RightShoulder = { rot = Vector3.new(0.12, 0, -6.4) },
					LeftShoulder = { rot = Vector3.new(72.09, 0, 16.31) },
					RightHip = { rot = Vector3.new(2.79, 0, 5.37), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(76.82, 0, -6.94), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.633,
				pose = {
					Root = {
						rot = Vector3.new(-37.53, -8.87, 0),
						pos = Vector3.new(0, -1.497, -0.277),
					},
					Neck = { rot = Vector3.new(33.53, 4.19, 0) },
					RightShoulder = { rot = Vector3.new(0.17, 0, -6.48) },
					LeftShoulder = { rot = Vector3.new(71.74, 0, 16.3) },
					RightHip = { rot = Vector3.new(2.57, 0, 5.4), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(76.58, 0, -6.89), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.642,
				pose = {
					Root = {
						rot = Vector3.new(-37.17, -8.8, 0),
						pos = Vector3.new(0, -1.498, -0.276),
					},
					Neck = { rot = Vector3.new(32.05, 4.12, 0) },
					RightShoulder = { rot = Vector3.new(0.15, 0, -6.62) },
					LeftShoulder = { rot = Vector3.new(71.16, 0, 16.24) },
					RightHip = { rot = Vector3.new(2.23, 0, 5.44), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(76.27, 0, -6.82), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.65,
				pose = {
					Root = {
						rot = Vector3.new(-36.78, -8.73, 0),
						pos = Vector3.new(0, -1.5, -0.275),
					},
					Neck = { rot = Vector3.new(30.36, 4.06, 0) },
					RightShoulder = { rot = Vector3.new(0.07, 0, -6.77) },
					LeftShoulder = { rot = Vector3.new(70.47, 0, 16.15) },
					RightHip = { rot = Vector3.new(1.82, 0, 5.48), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(75.94, 0, -6.74), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.658,
				pose = {
					Root = {
						rot = Vector3.new(-36.34, -8.67, 0),
						pos = Vector3.new(0, -1.503, -0.274),
					},
					Neck = { rot = Vector3.new(28.5, 4.02, 0) },
					RightShoulder = { rot = Vector3.new(-0.04, 0, -6.93) },
					LeftShoulder = { rot = Vector3.new(69.68, 0, 16.03) },
					RightHip = { rot = Vector3.new(1.36, 0, 5.54), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(75.58, 0, -6.67), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.667,
				pose = {
					Root = {
						rot = Vector3.new(-35.87, -8.61, 0),
						pos = Vector3.new(0, -1.506, -0.273),
					},
					Neck = { rot = Vector3.new(26.59, 3.98, 0) },
					RightShoulder = { rot = Vector3.new(-0.13, 0, -7.09) },
					LeftShoulder = { rot = Vector3.new(68.87, 0, 15.91) },
					RightHip = { rot = Vector3.new(0.87, 0, 5.59), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(75.16, 0, -6.59), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.675,
				pose = {
					Root = {
						rot = Vector3.new(-35.35, -8.55, 0),
						pos = Vector3.new(0, -1.508, -0.272),
					},
					Neck = { rot = Vector3.new(24.68, 3.94, 0) },
					RightShoulder = { rot = Vector3.new(-0.18, 0, -7.23) },
					LeftShoulder = { rot = Vector3.new(68.04, 0, 15.8) },
					RightHip = { rot = Vector3.new(0.36, 0, 5.65), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(74.7, 0, -6.52), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.683,
				pose = {
					Root = {
						rot = Vector3.new(-34.8, -8.49, 0),
						pos = Vector3.new(0, -1.508, -0.271),
					},
					Neck = { rot = Vector3.new(22.82, 3.9, 0) },
					RightShoulder = { rot = Vector3.new(-0.15, 0, -7.35) },
					LeftShoulder = { rot = Vector3.new(67.23, 0, 15.7) },
					RightHip = { rot = Vector3.new(-0.16, 0, 5.72), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(74.16, 0, -6.46), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.692,
				pose = {
					Root = {
						rot = Vector3.new(-34.21, -8.43, 0),
						pos = Vector3.new(0, -1.506, -0.27),
					},
					Neck = { rot = Vector3.new(21.08, 3.84, 0) },
					RightShoulder = { rot = Vector3.new(-0.02, 0, -7.44) },
					LeftShoulder = { rot = Vector3.new(66.49, 0, 15.64) },
					RightHip = { rot = Vector3.new(-0.66, 0, 5.79), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(73.54, 0, -6.42), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = {
						rot = Vector3.new(-33.57, -8.37, 0),
						pos = Vector3.new(0, -1.5, -0.268),
					},
					Neck = { rot = Vector3.new(19.4, 3.79, 0) },
					RightShoulder = { rot = Vector3.new(0.27, 0, -7.48) },
					LeftShoulder = { rot = Vector3.new(65.83, 0, 15.63) },
					RightHip = { rot = Vector3.new(-1.15, 0, 5.87), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(72.83, 0, -6.39), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.71,
				pose = {
					Root = {
						rot = Vector3.new(-32.76, -8.29, 0),
						pos = Vector3.new(0, -1.487, -0.265),
					},
					Neck = { rot = Vector3.new(17.49, 3.73, 0) },
					RightShoulder = { rot = Vector3.new(0.84, 0, -7.45) },
					LeftShoulder = { rot = Vector3.new(65.22, 0, 15.7) },
					RightHip = { rot = Vector3.new(-1.67, 0, 5.96), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(71.84, 0, -6.37), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-31.89, -8.21, 0),
						pos = Vector3.new(0, -1.467, -0.261),
					},
					Neck = { rot = Vector3.new(15.73, 3.69, 0) },
					RightShoulder = { rot = Vector3.new(1.73, 0, -7.32) },
					LeftShoulder = { rot = Vector3.new(64.86, 0, 15.89) },
					RightHip = { rot = Vector3.new(-2.11, 0, 6.07), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(70.69, 0, -6.39), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.74,
				pose = {
					Root = { rot = Vector3.new(-30, -8, 0), pos = Vector3.new(0, -1.4, -0.25) },
					Neck = { rot = Vector3.new(12.85, 3.68, 0) },
					RightShoulder = { rot = Vector3.new(4.75, 0, -6.71) },
					LeftShoulder = { rot = Vector3.new(65.1, 0, 16.7) },
					RightHip = { rot = Vector3.new(-2.71, 0, 6.24), pos = Vector3.new(0, 1.079, 0) },
					LeftHip = { rot = Vector3.new(70.95, 0, -6.39), pos = Vector3.new(0, 0.981, 0) },
				},
			},
			{
				time = 0.767,
				pose = {
					Root = {
						rot = Vector3.new(-26.89, -7.54, 0),
						pos = Vector3.new(0, -1.245, -0.228),
					},
					Neck = { rot = Vector3.new(9.96, 3.71, 0) },
					RightShoulder = { rot = Vector3.new(20.29, 0, -1.06) },
					LeftShoulder = { rot = Vector3.new(69.73, 0, 19.85) },
					RightHip = { rot = Vector3.new(-3.32, 0, 6.28), pos = Vector3.new(0, 0.964, 0) },
					LeftHip = { rot = Vector3.new(61.7, 0, -5.52), pos = Vector3.new(0, 1.013, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(-22.2, -6.76, 0),
						pos = Vector3.new(0, -0.979, -0.192),
					},
					Neck = { rot = Vector3.new(7.08, 3.85, 0) },
					RightShoulder = { rot = Vector3.new(44.68, 0, -6.29) },
					LeftShoulder = { rot = Vector3.new(79.76, 0, 25.78) },
					RightHip = { rot = Vector3.new(-4.57, 0, 6.35), pos = Vector3.new(0, 0.753, 0) },
					LeftHip = { rot = Vector3.new(39.33, 0, -3.42), pos = Vector3.new(0, 1.085, 0) },
				},
			},
			{
				time = 0.833,
				pose = {
					Root = {
						rot = Vector3.new(-17.39, -6.08, 0),
						pos = Vector3.new(0, -0.688, -0.152),
					},
					Neck = { rot = Vector3.new(5.27, 4.34, 0) },
					RightShoulder = { rot = Vector3.new(66.53, 0, -27.87) },
					LeftShoulder = { rot = Vector3.new(88.83, 0, 31.18) },
					RightHip = { rot = Vector3.new(-6.65, 0, 6.49), pos = Vector3.new(0, 0.509, 0) },
					LeftHip = { rot = Vector3.new(18.64, 0, -1.42), pos = Vector3.new(0, 0.831, 0) },
				},
			},
			{
				time = 0.867,
				pose = {
					Root = {
						rot = Vector3.new(-13.26, -5.87, 0),
						pos = Vector3.new(0, -0.43, -0.113),
					},
					Neck = { rot = Vector3.new(4.6, 5.3, 0) },
					RightShoulder = { rot = Vector3.new(92.37, 0, -35.23) },
					LeftShoulder = { rot = Vector3.new(98.09, 0, 36.16) },
					RightHip = { rot = Vector3.new(-8.23, 0, 5.86), pos = Vector3.new(0, 0.352, 0) },
					LeftHip = { rot = Vector3.new(4.68, 0, -0.21), pos = Vector3.new(0, 0.443, 0) },
				},
			},
			{
				time = 0.88,
				pose = {
					Root = { rot = Vector3.new(-12, -6, 0), pos = Vector3.new(0, -0.35, -0.1) },
					Neck = { rot = Vector3.new(4.56, 5.79, 0) },
					RightShoulder = { rot = Vector3.new(99.07, 0, -35.97) },
					LeftShoulder = { rot = Vector3.new(100.88, 0, 37.21) },
					RightHip = { rot = Vector3.new(-7.92, 0, 5.06), pos = Vector3.new(0, 0.327, 0) },
					LeftHip = { rot = Vector3.new(2.59, 0, -0.03), pos = Vector3.new(0, 0.334, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(-10.53, -6.66, 0),
						pos = Vector3.new(0, -0.249, -0.079),
					},
					Neck = { rot = Vector3.new(4.67, 6.81, 0) },
					RightShoulder = { rot = Vector3.new(103.54, 0, -36.49) },
					LeftShoulder = { rot = Vector3.new(104.32, 0, 37.87) },
					RightHip = { rot = Vector3.new(-6.37, 0, 3.55), pos = Vector3.new(0, 0.286, 0) },
					LeftHip = { rot = Vector3.new(1.57, 0, 0.04), pos = Vector3.new(0, 0.237, 0) },
				},
			},
			{
				time = 0.933,
				pose = {
					Root = {
						rot = Vector3.new(-8.94, -8.75, 0),
						pos = Vector3.new(0, -0.116, -0.043),
					},
					Neck = { rot = Vector3.new(5.14, 8.9, 0) },
					RightShoulder = { rot = Vector3.new(108.22, 0, -36.73) },
					LeftShoulder = { rot = Vector3.new(109.6, 0, 37.93) },
					RightHip = { rot = Vector3.new(-2.54, 0, 1.02), pos = Vector3.new(0, 0.151, 0) },
					LeftHip = { rot = Vector3.new(0.5, 0, 0.07), pos = Vector3.new(0, 0.109, 0) },
				},
			},
			{
				time = 0.967,
				pose = {
					Root = {
						rot = Vector3.new(-8.19, -10.97, 0),
						pos = Vector3.new(0, -0.03, -0.012),
					},
					Neck = { rot = Vector3.new(5.58, 10.34, 0) },
					RightShoulder = { rot = Vector3.new(110.43, 0, -36.61) },
					LeftShoulder = { rot = Vector3.new(113.49, 0, 37.37) },
					RightHip = { rot = Vector3.new(-0.44, 0, 0.03), pos = Vector3.new(0, 0.028, 0) },
					LeftHip = { rot = Vector3.new(0.06, 0, 0.04), pos = Vector3.new(0, 0.028, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
		},
	},
	Rift_Awaken = {
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
				},
			},
			{
				time = 0.033,
				pose = {
					Root = {
						rot = Vector3.new(-9.62, -11.43, -0.05),
						pos = Vector3.new(0, -0.034, 0.008),
					},
					Neck = { rot = Vector3.new(4.48, 9.16, 0) },
					RightShoulder = { rot = Vector3.new(109.18, 0, -37.52) },
					LeftShoulder = { rot = Vector3.new(112, 0, 37.9) },
					RightHip = { rot = Vector3.new(2.3, 0, -0.42), pos = Vector3.new(0, 0.029, 0) },
					LeftHip = { rot = Vector3.new(2.55, 0, -0.41), pos = Vector3.new(0, 0.041, 0) },
				},
			},
			{
				time = 0.067,
				pose = {
					Root = {
						rot = Vector3.new(-13.51, -9.99, -0.16),
						pos = Vector3.new(0, -0.119, 0.028),
					},
					Neck = { rot = Vector3.new(1.12, 6.92, 0) },
					RightShoulder = { rot = Vector3.new(104.17, 0, -39.95) },
					LeftShoulder = { rot = Vector3.new(104.16, 0, 39.99) },
					RightHip = { rot = Vector3.new(7.69, 0, -1.12), pos = Vector3.new(0, 0.108, 0) },
					LeftHip = { rot = Vector3.new(8.55, 0, -1.18), pos = Vector3.new(0, 0.133, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-18.19, -8.08, -0.25),
						pos = Vector3.new(0, -0.226, 0.053),
					},
					Neck = { rot = Vector3.new(-3.31, 4.09, 0) },
					RightShoulder = { rot = Vector3.new(96.71, 0, -42.59) },
					LeftShoulder = { rot = Vector3.new(93.71, 0, 42.17) },
					RightHip = { rot = Vector3.new(15, 0, 0.96), pos = Vector3.new(0, 0.306, 0) },
					LeftHip = { rot = Vector3.new(15.47, 0, -1.67), pos = Vector3.new(0, 0.235, 0) },
				},
			},
			{
				time = 0.133,
				pose = {
					Root = {
						rot = Vector3.new(-22.22, -6.1, -0.26),
						pos = Vector3.new(0, -0.326, 0.078),
					},
					Neck = { rot = Vector3.new(-8.65, 1.65, 0) },
					RightShoulder = { rot = Vector3.new(87.72, 0, -43.72) },
					LeftShoulder = { rot = Vector3.new(83.9, 0, 43.14) },
					RightHip = { rot = Vector3.new(22.4, 0, 5.5), pos = Vector3.new(0, 0.458, 0) },
					LeftHip = { rot = Vector3.new(22.74, 0, -3.92), pos = Vector3.new(0, 0.413, 0) },
				},
			},
			{
				time = 0.167,
				pose = {
					Root = {
						rot = Vector3.new(-24.15, -4.47, -0.11),
						pos = Vector3.new(0, -0.39, 0.096),
					},
					Neck = { rot = Vector3.new(-13.99, 0.37, 0) },
					RightShoulder = { rot = Vector3.new(78.34, 0, -43.82) },
					LeftShoulder = { rot = Vector3.new(77.94, 0, 43.54) },
					RightHip = { rot = Vector3.new(28, 0, 10.1), pos = Vector3.new(0, 0.452, 0) },
					LeftHip = { rot = Vector3.new(30.35, 0, -8.6), pos = Vector3.new(0, 0.541, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(-24, -4, 0), pos = Vector3.new(0, -0.4, 0.1) },
					Neck = { rot = Vector3.new(-15.88, 0.35, 0) },
					RightShoulder = { rot = Vector3.new(74.76, 0, -43.49) },
					LeftShoulder = { rot = Vector3.new(77.2, 0, 43.63) },
					RightHip = {
						rot = Vector3.new(28.99, 0, 11.37),
						pos = Vector3.new(0, 0.417, 0),
					},
					LeftHip = {
						rot = Vector3.new(33.01, 0, -10.67),
						pos = Vector3.new(0, 0.538, 0),
					},
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-22.72, -3.41, 0.26),
						pos = Vector3.new(0, -0.398, 0.103),
					},
					Neck = { rot = Vector3.new(-18.58, 0.75, 0) },
					RightShoulder = { rot = Vector3.new(67.89, 0, -40.96) },
					LeftShoulder = { rot = Vector3.new(81.74, 0, 43.65) },
					RightHip = {
						rot = Vector3.new(28.19, 0, 12.16),
						pos = Vector3.new(0, 0.375, 0),
					},
					LeftHip = { rot = Vector3.new(36, 0, -13.54), pos = Vector3.new(0, 0.476, 0) },
				},
			},
			{
				time = 0.233,
				pose = {
					Root = {
						rot = Vector3.new(-18.5, -2.49, 0.9),
						pos = Vector3.new(0, -0.368, 0.103),
					},
					Neck = { rot = Vector3.new(-22.81, 2.06, 0) },
					RightShoulder = { rot = Vector3.new(55.58, 0, -30.14) },
					LeftShoulder = { rot = Vector3.new(101.28, 0, 42.48) },
					RightHip = {
						rot = Vector3.new(22.45, 0, 12.01),
						pos = Vector3.new(0, 0.362, 0),
					},
					LeftHip = {
						rot = Vector3.new(36.12, 0, -16.45),
						pos = Vector3.new(0, 0.333, 0),
					},
				},
			},
			{
				time = 0.267,
				pose = {
					Root = {
						rot = Vector3.new(-12.58, -1.67, 1.69),
						pos = Vector3.new(0, -0.313, 0.099),
					},
					Neck = { rot = Vector3.new(-25.75, 3.72, 0) },
					RightShoulder = { rot = Vector3.new(41.33, 0, -19.06) },
					LeftShoulder = { rot = Vector3.new(118, 0, 38.73) },
					RightHip = {
						rot = Vector3.new(14.54, 0, 11.45),
						pos = Vector3.new(0, 0.321, 0),
					},
					LeftHip = { rot = Vector3.new(28.91, 0, -16.91), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-6.09, -0.98, 2.52),
						pos = Vector3.new(0, -0.248, 0.094),
					},
					Neck = { rot = Vector3.new(-27.04, 5.61, 0) },
					RightShoulder = { rot = Vector3.new(28.97, 0, -8.61) },
					LeftShoulder = { rot = Vector3.new(137.11, 0, 34.18) },
					RightHip = { rot = Vector3.new(5.7, 0, 10.56), pos = Vector3.new(0, 0.259, 0) },
					LeftHip = {
						rot = Vector3.new(20.39, 0, -17.64),
						pos = Vector3.new(0, 0.287, 0),
					},
				},
			},
			{
				time = 0.333,
				pose = {
					Root = {
						rot = Vector3.new(-0.11, -0.46, 3.26),
						pos = Vector3.new(0, -0.186, 0.087),
					},
					Neck = { rot = Vector3.new(-26.78, 7.46, 0) },
					RightShoulder = { rot = Vector3.new(16.2, 0, 1.12) },
					LeftShoulder = { rot = Vector3.new(146.59, 0, 28.24) },
					RightHip = { rot = Vector3.new(-2.75, 0, 9.56), pos = Vector3.new(0, 0.186, 0) },
					LeftHip = {
						rot = Vector3.new(12.23, 0, -18.54),
						pos = Vector3.new(0, 0.257, 0),
					},
				},
			},
			{
				time = 0.367,
				pose = {
					Root = {
						rot = Vector3.new(4.3, -0.12, 3.8),
						pos = Vector3.new(0, -0.139, 0.082),
					},
					Neck = { rot = Vector3.new(-25.11, 8.93, 0) },
					RightShoulder = { rot = Vector3.new(-2.56, 0, 12.02) },
					LeftShoulder = { rot = Vector3.new(163.56, 0, 20.28) },
					RightHip = { rot = Vector3.new(-9.23, 0, 8.76), pos = Vector3.new(0, 0.122, 0) },
					LeftHip = { rot = Vector3.new(6.02, 0, -19.3), pos = Vector3.new(0, 0.228, 0) },
				},
			},
			{
				time = 0.4,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(6, 0, 4), pos = Vector3.new(0, -0.12, 0.08) },
					Neck = { rot = Vector3.new(-22.21, 9.68, 0) },
					RightShoulder = { rot = Vector3.new(-14.88, 0, 16.87) },
					LeftShoulder = { rot = Vector3.new(173.02, 0, 15.68) },
					RightHip = {
						rot = Vector3.new(-11.82, 0, 8.43),
						pos = Vector3.new(0, 0.094, 0),
					},
					LeftHip = { rot = Vector3.new(3.55, 0, -19.62), pos = Vector3.new(0, 0.215, 0) },
				},
			},
			{
				time = 0.433,
				pose = {
					Root = { rot = Vector3.new(6.51, 0, -0.01), pos = Vector3.new(0, -0.11, 0.08) },
					Neck = { rot = Vector3.new(-20.67, 10.46, 0) },
					RightShoulder = { rot = Vector3.new(-17.47, 0, 21.34) },
					LeftShoulder = { rot = Vector3.new(171.15, 0, 11.47) },
					RightHip = {
						rot = Vector3.new(-12.52, 0, 14.03),
						pos = Vector3.new(0, 0.155, 0),
					},
					LeftHip = { rot = Vector3.new(2.76, 0, -14.04), pos = Vector3.new(0, 0.139, 0) },
				},
			},
			{
				time = 0.46,
				pose = {
					Root = { rot = Vector3.new(7, 0, -3), pos = Vector3.new(0, -0.1, 0.08) },
					Neck = { rot = Vector3.new(-20.75, 9.99, 0) },
					RightShoulder = { rot = Vector3.new(-19.58, 0, 24.56) },
					LeftShoulder = { rot = Vector3.new(169.77, 0, 8.16) },
					RightHip = {
						rot = Vector3.new(-13.28, 0, 18.15),
						pos = Vector3.new(0, 0.194, 0),
					},
					LeftHip = { rot = Vector3.new(2.05, 0, -9.74), pos = Vector3.new(0, 0.075, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(7.04, 0, 1.41), pos = Vector3.new(0, -0.099, 0.08) },
					Neck = { rot = Vector3.new(-20.46, 4.96, 0) },
					RightShoulder = { rot = Vector3.new(-16.51, 0, 19.28) },
					LeftShoulder = { rot = Vector3.new(172.3, 0, 11.74) },
					RightHip = {
						rot = Vector3.new(-13.31, 0, 12.09),
						pos = Vector3.new(0, 0.117, 0),
					},
					LeftHip = { rot = Vector3.new(1.99, 0, -16.01), pos = Vector3.new(0, 0.153, 0) },
				},
			},
			{
				time = 0.52,
				pose = {
					Root = { rot = Vector3.new(7, 0, 3), pos = Vector3.new(0, -0.1, 0.08) },
					Neck = { rot = Vector3.new(-20.09, 2, 0) },
					RightShoulder = { rot = Vector3.new(-15.49, 0, 17.37) },
					LeftShoulder = { rot = Vector3.new(173.17, 0, 13.14) },
					RightHip = {
						rot = Vector3.new(-13.29, 0, 9.84),
						pos = Vector3.new(0, 0.089, 0),
					},
					LeftHip = { rot = Vector3.new(2.05, 0, -18.26), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.533,
				pose = {
					Root = { rot = Vector3.new(6.98, 0, 2.38), pos = Vector3.new(0, -0.1, 0.08) },
					Neck = { rot = Vector3.new(-20.02, 0.1, 0) },
					RightShoulder = { rot = Vector3.new(-15.9, 0, 18.1) },
					LeftShoulder = { rot = Vector3.new(172.84, 0, 12.67) },
					RightHip = { rot = Vector3.new(-13.25, 0, 10.7), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(2.06, 0, -17.4), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.567,
				pose = {
					Root = { rot = Vector3.new(6.92, 0, -1.76), pos = Vector3.new(0, -0.1, 0.078) },
					Neck = { rot = Vector3.new(-20.08, -4.66, 0) },
					RightShoulder = { rot = Vector3.new(-18.78, 0, 23.06) },
					LeftShoulder = { rot = Vector3.new(170.52, 0, 9.32) },
					RightHip = {
						rot = Vector3.new(-13.19, 0, 16.45),
						pos = Vector3.new(0, 0.173, 0),
					},
					LeftHip = { rot = Vector3.new(2.11, 0, -11.53), pos = Vector3.new(0, 0.098, 0) },
				},
			},
			{
				time = 0.58,
				pose = {
					Root = { rot = Vector3.new(7, 0, -3), pos = Vector3.new(0, -0.1, 0.08) },
					Neck = { rot = Vector3.new(-19.99, -6, 0) },
					RightShoulder = { rot = Vector3.new(-19.59, 0, 24.56) },
					LeftShoulder = { rot = Vector3.new(169.77, 0, 8.16) },
					RightHip = {
						rot = Vector3.new(-13.29, 0, 18.16),
						pos = Vector3.new(0, 0.194, 0),
					},
					LeftHip = { rot = Vector3.new(2.05, 0, -9.74), pos = Vector3.new(0, 0.075, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(7.99, 0, -3.39),
						pos = Vector3.new(0, -0.093, 0.093),
					},
					Neck = { rot = Vector3.new(-20.18, -6.58, 0) },
					RightShoulder = { rot = Vector3.new(-19.69, 0, 24.03) },
					LeftShoulder = { rot = Vector3.new(169.86, 0, 8.55) },
					RightHip = {
						rot = Vector3.new(-14.36, 0, 18.7),
						pos = Vector3.new(0, 0.191, 0),
					},
					LeftHip = { rot = Vector3.new(0.98, 0, -9.15), pos = Vector3.new(0, 0.059, 0) },
				},
			},
			{
				time = 0.62,
				pose = {
					Root = { rot = Vector3.new(8, 0, -3), pos = Vector3.new(0, -0.1, 0.1) },
					Neck = { rot = Vector3.new(-18.67, -6, 0) },
					RightShoulder = { rot = Vector3.new(-18.1, 0, 24.86) },
					LeftShoulder = { rot = Vector3.new(169.28, 0, 6.51) },
					RightHip = {
						rot = Vector3.new(-14.15, 0, 18.16),
						pos = Vector3.new(0, 0.192, 0),
					},
					LeftHip = { rot = Vector3.new(1.17, 0, -9.72), pos = Vector3.new(0, 0.073, 0) },
				},
			},
			{
				time = 0.633,
				pose = {
					Root = {
						rot = Vector3.new(6.59, 0, -2.72),
						pos = Vector3.new(0, -0.122, 0.092),
					},
					Neck = { rot = Vector3.new(-15.82, -5.45, 0) },
					RightShoulder = { rot = Vector3.new(-15.62, 0, 28.36) },
					LeftShoulder = { rot = Vector3.new(167.09, 0, 0.35) },
					RightHip = {
						rot = Vector3.new(-12.28, 0, 17.77),
						pos = Vector3.new(0, 0.214, 0),
					},
					LeftHip = { rot = Vector3.new(3.03, 0, -10.16), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.667,
				pose = {
					Root = { rot = Vector3.new(1.6, 0, -1.78), pos = Vector3.new(0, -0.198, 0.062) },
					Neck = { rot = Vector3.new(-5.88, -3.56, 0) },
					RightShoulder = { rot = Vector3.new(-4.18, 0, 40.1) },
					LeftShoulder = { rot = Vector3.new(157.79, 0, -20.45) },
					RightHip = {
						rot = Vector3.new(-6.05, 0, 16.44),
						pos = Vector3.new(0, 0.283, 0),
					},
					LeftHip = { rot = Vector3.new(9.29, 0, -11.59), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = {
						rot = Vector3.new(-3.76, 0, -0.78),
						pos = Vector3.new(0, -0.278, 0.027),
					},
					Neck = { rot = Vector3.new(3.21, -1.56, 0) },
					RightShoulder = { rot = Vector3.new(18.04, 0, 50.06) },
					LeftShoulder = { rot = Vector3.new(142.54, 0, -38.66) },
					RightHip = { rot = Vector3.new(0.16, 0, 15.07), pos = Vector3.new(0, 0.347, 0) },
					LeftHip = { rot = Vector3.new(15.61, 0, -13.01), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.733,
				pose = {
					Root = {
						rot = Vector3.new(-7.44, 0, -0.1),
						pos = Vector3.new(0, -0.332, 0.004),
					},
					Neck = { rot = Vector3.new(6.72, -0.21, 0) },
					RightShoulder = { rot = Vector3.new(62.88, 0, 53.64) },
					LeftShoulder = { rot = Vector3.new(95.26, 0, -52.88) },
					RightHip = { rot = Vector3.new(4.18, 0, 14.17), pos = Vector3.new(0, 0.387, 0) },
					LeftHip = { rot = Vector3.new(19.72, 0, -13.9), pos = Vector3.new(0, 0.339, 0) },
				},
			},
			{
				time = 0.75,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, -0.34, 0) },
					Neck = { rot = Vector3.new(6.04, 0, 0) },
					RightShoulder = { rot = Vector3.new(73.01, 0, 52.95) },
					LeftShoulder = { rot = Vector3.new(73.92, 0, -52.95) },
					RightHip = { rot = Vector3.new(4.79, 0, 14.04), pos = Vector3.new(0, 0.392, 0) },
					LeftHip = {
						rot = Vector3.new(20.35, 0, -14.04),
						pos = Vector3.new(0, 0.347, 0),
					},
				},
			},
			{
				time = 0.767,
				pose = {
					Root = { rot = Vector3.new(-7.81, 0.1, 0), pos = Vector3.new(0, -0.339, 0) },
					Neck = { rot = Vector3.new(4.5, -0.14, 0) },
					RightShoulder = { rot = Vector3.new(71.45, 0, 52.93) },
					LeftShoulder = { rot = Vector3.new(71.4, 0, -52.92) },
					RightHip = { rot = Vector3.new(4.5, 0, 14.04), pos = Vector3.new(0, 0.392, 0) },
					LeftHip = { rot = Vector3.new(20.16, 0, -14), pos = Vector3.new(0, 0.347, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = { rot = Vector3.new(-6.7, 0.6, 0), pos = Vector3.new(0, -0.331, 0) },
					Neck = { rot = Vector3.new(2.41, -0.79, 0) },
					RightShoulder = { rot = Vector3.new(61.5, 0, 51.99) },
					LeftShoulder = { rot = Vector3.new(61.15, 0, -51.91) },
					RightHip = { rot = Vector3.new(2.86, 0, 14.07), pos = Vector3.new(0, 0.385, 0) },
					LeftHip = { rot = Vector3.new(18.96, 0, -13.84), pos = Vector3.new(0, 0.34, 0) },
				},
			},
			{
				time = 0.833,
				pose = {
					Root = { rot = Vector3.new(-5.44, 0.73, 0), pos = Vector3.new(0, -0.31, 0) },
					Neck = { rot = Vector3.new(2.34, -0.92, 0) },
					RightShoulder = { rot = Vector3.new(54.14, 0, 48.97) },
					LeftShoulder = { rot = Vector3.new(53.78, 0, -48.86) },
					RightHip = { rot = Vector3.new(1.21, 0, 14.05), pos = Vector3.new(0, 0.364, 0) },
					LeftHip = {
						rot = Vector3.new(17.41, 0, -13.82),
						pos = Vector3.new(0, 0.322, 0),
					},
				},
			},
			{
				time = 0.86,
				pose = {
					Root = { rot = Vector3.new(-5, 0, 0), pos = Vector3.new(0, -0.28, 0) },
					Neck = { rot = Vector3.new(3.11, 0.19, 0) },
					RightShoulder = { rot = Vector3.new(56.28, 0, 45.13) },
					LeftShoulder = { rot = Vector3.new(56.27, 0, -45.13) },
					RightHip = { rot = Vector3.new(0.18, 0, 12.8), pos = Vector3.new(0, 0.375, 0) },
					LeftHip = {
						rot = Vector3.new(16.51, 0, -14.04),
						pos = Vector3.new(0, 0.297, 0),
					},
				},
			},
			{
				time = 0.88,
				pose = {
					Root = { rot = Vector3.new(-5.17, -1.37, 0), pos = Vector3.new(0, -0.245, 0) },
					Neck = { rot = Vector3.new(3.9, 1.96, 0) },
					RightShoulder = { rot = Vector3.new(70.08, 0, 37.46) },
					LeftShoulder = { rot = Vector3.new(71.15, 0, -37.68) },
					RightHip = { rot = Vector3.new(-0.99, 0, 9.8), pos = Vector3.new(0, 0.384, 0) },
					LeftHip = {
						rot = Vector3.new(16.13, 0, -14.42),
						pos = Vector3.new(0, 0.267, 0),
					},
				},
			},
			{
				time = 0.9,
				pose = {
					Root = { rot = Vector3.new(-5.59, -3.36, 0), pos = Vector3.new(0, -0.197, 0) },
					Neck = { rot = Vector3.new(4.74, 4.29, 0) },
					RightShoulder = { rot = Vector3.new(83.94, 0, 24.48) },
					LeftShoulder = { rot = Vector3.new(86.07, 0, -24.73) },
					RightHip = { rot = Vector3.new(-2.15, 0, 6.11), pos = Vector3.new(0, 0.336, 0) },
					LeftHip = {
						rot = Vector3.new(13.84, 0, -13.41),
						pos = Vector3.new(0, 0.276, 0),
					},
				},
			},
			{
				time = 0.933,
				pose = {
					Root = { rot = Vector3.new(-6.61, -7.22, 0), pos = Vector3.new(0, -0.107, 0) },
					Neck = { rot = Vector3.new(5.81, 8.11, 0) },
					RightShoulder = { rot = Vector3.new(95.14, 0, 4.46) },
					LeftShoulder = { rot = Vector3.new(98.06, 0, -4.51) },
					RightHip = { rot = Vector3.new(-3.01, 0, 1.11), pos = Vector3.new(0, 0.148, 0) },
					LeftHip = { rot = Vector3.new(6.04, 0, -7.15), pos = Vector3.new(0, 0.247, 0) },
				},
			},
			{
				time = 0.967,
				pose = {
					Root = { rot = Vector3.new(-7.57, -10.58, 0), pos = Vector3.new(0, -0.032, 0) },
					Neck = { rot = Vector3.new(6.24, 10.4, 0) },
					RightShoulder = { rot = Vector3.new(103.7, 0, -17.35) },
					LeftShoulder = { rot = Vector3.new(107.19, 0, 17.58) },
					RightHip = { rot = Vector3.new(-1.1, 0, 0.13), pos = Vector3.new(0, 0.034, 0) },
					LeftHip = { rot = Vector3.new(0.31, 0, -0.72), pos = Vector3.new(0, 0.061, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
		},
	},
	Rift_ClonePunch = {
		length = 0.4,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
			{
				time = 0.017,
				pose = {
					Root = {
						rot = Vector3.new(-7.62, -15.01, 0),
						pos = Vector3.new(0.013, -0.035, 0.025),
					},
					Neck = { rot = Vector3.new(5.79, 13.07, 0) },
					RightShoulder = { rot = Vector3.new(105.58, 0, -25.63) },
					LeftShoulder = { rot = Vector3.new(113.94, 0, 37.55) },
					RightHip = { rot = Vector3.new(0.66, 0, -0.38), pos = Vector3.new(0, 0.035, 0) },
					LeftHip = { rot = Vector3.new(-0.83, 0, -0.35), pos = Vector3.new(0, 0.043, 0) },
				},
			},
			{
				time = 0.033,
				pose = {
					Root = {
						rot = Vector3.new(-7.01, -19.77, 0),
						pos = Vector3.new(0.037, -0.105, 0.063),
					},
					Neck = { rot = Vector3.new(5.43, 18.61, 0) },
					RightShoulder = { rot = Vector3.new(98.72, 0, -10.92) },
					LeftShoulder = { rot = Vector3.new(110.83, 0, 38.22) },
					RightHip = { rot = Vector3.new(1.55, 0, -1.1), pos = Vector3.new(0, 0.106, 0) },
					LeftHip = { rot = Vector3.new(1.44, 0, -2.7), pos = Vector3.new(0, 0.234, 0) },
				},
			},
			{
				time = 0.05,
				pose = {
					Root = { rot = Vector3.new(-7, -20, 0), pos = Vector3.new(0.05, -0.16, 0.06) },
					Neck = { rot = Vector3.new(5.6, 19.22, 0) },
					RightShoulder = { rot = Vector3.new(93.2, 0, -0.06) },
					LeftShoulder = { rot = Vector3.new(105.66, 0, 37.56) },
					RightHip = { rot = Vector3.new(1.77, 0, -1.06), pos = Vector3.new(0, 0.189, 0) },
					LeftHip = { rot = Vector3.new(8.84, 0, -6.82), pos = Vector3.new(0, 0.385, 0) },
				},
			},
			{
				time = 0.067,
				pose = {
					Root = {
						rot = Vector3.new(-7.96, -13.01, 0),
						pos = Vector3.new(0.044, -0.185, -0.01),
					},
					Neck = { rot = Vector3.new(6.84, 10.5, 0) },
					RightShoulder = { rot = Vector3.new(95.44, 0, -7) },
					LeftShoulder = { rot = Vector3.new(96.14, 0, 33.28) },
					RightHip = { rot = Vector3.new(0.56, 0, 0.06), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(20.01, 0, -8.39), pos = Vector3.new(0, 0.324, 0) },
				},
			},
			{
				time = 0.083,
				pose = {
					Root = {
						rot = Vector3.new(-9.41, -2.46, 0),
						pos = Vector3.new(0.029, -0.201, -0.113),
					},
					Neck = { rot = Vector3.new(8.91, -4.77, 0) },
					RightShoulder = { rot = Vector3.new(99.57, 0, -18.77) },
					LeftShoulder = { rot = Vector3.new(84.92, 0, 26.95) },
					RightHip = { rot = Vector3.new(-1.86, 0, 1.29), pos = Vector3.new(0, 0.218, 0) },
					LeftHip = { rot = Vector3.new(30.4, 0, -4.9), pos = Vector3.new(0, 0.116, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-10.87, 8.49, 0),
						pos = Vector3.new(0.013, -0.212, -0.218),
					},
					Neck = { rot = Vector3.new(11.26, -15.74, 0) },
					RightShoulder = { rot = Vector3.new(103.35, 0, -29.08) },
					LeftShoulder = { rot = Vector3.new(73.61, 0, 20.16) },
					RightHip = { rot = Vector3.new(-4.94, 0, 1.78), pos = Vector3.new(0, 0.167, 0) },
					LeftHip = { rot = Vector3.new(34.53, 0, 1.36) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-12, 18, 0), pos = Vector3.new(0, -0.281, -0.3) },
					Neck = { rot = Vector3.new(12.92, -24.19, 0) },
					RightShoulder = { rot = Vector3.new(106.69, 0, -39.37) },
					LeftShoulder = { rot = Vector3.new(63.47, 0, 14.19) },
					RightHip = { rot = Vector3.new(-8.55, 0, 0.97), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(36.09, 0, 6.85) },
				},
			},
			{
				time = 0.133,
				pose = {
					Root = {
						rot = Vector3.new(-12.2, 21.36, 0),
						pos = Vector3.new(-0.003, -0.306, -0.318),
					},
					Neck = { rot = Vector3.new(12.74, -27.19, 0) },
					RightShoulder = { rot = Vector3.new(106.31, 0, -42.79) },
					LeftShoulder = { rot = Vector3.new(62.28, 0, 14.09) },
					RightHip = { rot = Vector3.new(-9.84, 0, 0.39), pos = Vector3.new(0, 0.189, 0) },
					LeftHip = { rot = Vector3.new(36.52, 0, 8.74) },
				},
			},
			{
				time = 0.167,
				pose = {
					Root = {
						rot = Vector3.new(-11.78, 25.38, 0),
						pos = Vector3.new(-0.003, -0.367, -0.299),
					},
					Neck = { rot = Vector3.new(9.86, -30.64, 0) },
					RightShoulder = { rot = Vector3.new(102.52, 0, -47) },
					LeftShoulder = { rot = Vector3.new(63.38, 0, 16.84) },
					RightHip = {
						rot = Vector3.new(-11.3, 0, -0.53),
						pos = Vector3.new(0, 0.236, 0),
					},
					LeftHip = { rot = Vector3.new(37.51, 0, 11.12) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-11, 24, 0), pos = Vector3.new(0, -0.365, -0.25) },
					Neck = { rot = Vector3.new(7.23, -22.19, 0) },
					RightShoulder = { rot = Vector3.new(99.47, 0, -48.38) },
					LeftShoulder = { rot = Vector3.new(68.64, 0, 21.24) },
					RightHip = { rot = Vector3.new(-10.6, 0, -0.2), pos = Vector3.new(0, 0.253, 0) },
					LeftHip = { rot = Vector3.new(37.68, 0, 10.4) },
				},
			},
			{
				time = 0.233,
				pose = {
					Root = {
						rot = Vector3.new(-10.35, 16.96, 0),
						pos = Vector3.new(0, -0.307, -0.197),
					},
					Neck = { rot = Vector3.new(6.26, -7.96, 0) },
					RightShoulder = { rot = Vector3.new(100.47, 0, -45.92) },
					LeftShoulder = { rot = Vector3.new(79.21, 0, 26.86) },
					RightHip = { rot = Vector3.new(-7.85, 0, 1.24), pos = Vector3.new(0, 0.235, 0) },
					LeftHip = { rot = Vector3.new(36.76, 0, 6.54) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-9.98, 11.86, 0),
						pos = Vector3.new(0, -0.223, -0.165),
					},
					Neck = { rot = Vector3.new(5.93, -0.02, 0) },
					RightShoulder = { rot = Vector3.new(101.61, 0, -43.69) },
					LeftShoulder = { rot = Vector3.new(86.4, 0, 30.16) },
					RightHip = { rot = Vector3.new(-5.62, 0, 2.04), pos = Vector3.new(0, 0.174, 0) },
					LeftHip = { rot = Vector3.new(34.77, 0, 3.58) },
				},
			},
			{
				time = 0.267,
				pose = {
					Root = {
						rot = Vector3.new(-9.62, 6.57, 0),
						pos = Vector3.new(0, -0.158, -0.133),
					},
					Neck = { rot = Vector3.new(5.63, 4.86, 0) },
					RightShoulder = { rot = Vector3.new(102.86, 0, -40.56) },
					LeftShoulder = { rot = Vector3.new(93.72, 0, 33.15) },
					RightHip = { rot = Vector3.new(-3.4, 0, 2.57), pos = Vector3.new(0, 0.126, 0) },
					LeftHip = { rot = Vector3.new(28.41, 0, 0.73), pos = Vector3.new(0, 0.089, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(-9, -2, 0), pos = Vector3.new(0, -0.12, -0.08) },
					Neck = { rot = Vector3.new(5.23, 11.65, 0) },
					RightShoulder = { rot = Vector3.new(105.06, 0, -35) },
					LeftShoulder = { rot = Vector3.new(105.03, 0, 36.91) },
					RightHip = { rot = Vector3.new(-0.56, 0, 2.55), pos = Vector3.new(0, 0.125, 0) },
					LeftHip = { rot = Vector3.new(11.42, 0, -1.2), pos = Vector3.new(0, 0.224, 0) },
				},
			},
			{
				time = 0.333,
				pose = {
					Root = {
						rot = Vector3.new(-8.52, -7.25, 0),
						pos = Vector3.new(0, -0.073, -0.041),
					},
					Neck = { rot = Vector3.new(5.31, 14.21, 0) },
					RightShoulder = { rot = Vector3.new(107.36, 0, -34.22) },
					LeftShoulder = { rot = Vector3.new(110.93, 0, 37.81) },
					RightHip = { rot = Vector3.new(-0.28, 0, 1.28), pos = Vector3.new(0, 0.113, 0) },
					LeftHip = { rot = Vector3.new(0.87, 0, 0.05), pos = Vector3.new(0, 0.078, 0) },
				},
			},
			{
				time = 0.367,
				pose = {
					Root = {
						rot = Vector3.new(-8.15, -10.74, 0),
						pos = Vector3.new(0, -0.023, -0.011),
					},
					Neck = { rot = Vector3.new(5.63, 12.65, 0) },
					RightShoulder = { rot = Vector3.new(109.82, 0, -35.52) },
					LeftShoulder = { rot = Vector3.new(114.05, 0, 37.41) },
					RightHip = { rot = Vector3.new(-0.35, 0, 0.16), pos = Vector3.new(0, 0.034, 0) },
					LeftHip = { rot = Vector3.new(0.11, 0, 0.04), pos = Vector3.new(0, 0.021, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
		},
	},
	Rift_FinisherPortalCut = {
		length = 4.6,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
			{
				time = 0.025,
				pose = {
					Root = {
						rot = Vector3.new(-8.52, -12.22, 0),
						pos = Vector3.new(0, -0.031, 0.007),
					},
					Neck = { rot = Vector3.new(4.27, 10.17, 0) },
					RightShoulder = { rot = Vector3.new(91.68, 0, -35.35) },
					LeftShoulder = { rot = Vector3.new(110.07, 0, 35.34) },
					RightHip = { rot = Vector3.new(0.9, 0, -0.19), pos = Vector3.new(0, 0.03, 0) },
					LeftHip = { rot = Vector3.new(0.76, 0, -0.18), pos = Vector3.new(0, 0.034, 0) },
				},
			},
			{
				time = 0.05,
				pose = {
					Root = {
						rot = Vector3.new(-9.81, -12.78, 0),
						pos = Vector3.new(0, -0.109, 0.026),
					},
					Neck = { rot = Vector3.new(0, 10.61, 0) },
					RightShoulder = { rot = Vector3.new(68.84, 0, -32.21) },
					LeftShoulder = { rot = Vector3.new(99.55, 0, 31.31) },
					RightHip = { rot = Vector3.new(3.04, 0, 0.13), pos = Vector3.new(0, 0.154, 0) },
					LeftHip = { rot = Vector3.new(2.63, 0, -0.64), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.075,
				pose = {
					Root = { rot = Vector3.new(-11.5, -13.5, 0), pos = Vector3.new(0, -0.21, 0.05) },
					Neck = { rot = Vector3.new(-5.49, 11.22, 0) },
					RightShoulder = { rot = Vector3.new(48.64, 0, -24.63) },
					LeftShoulder = { rot = Vector3.new(89.68, 0, 27.02) },
					RightHip = { rot = Vector3.new(5.97, 0, 1.99), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(7.23, 0, -2.63), pos = Vector3.new(0, 0.314, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-13.18, -14.22, 0),
						pos = Vector3.new(0, -0.311, 0.074),
					},
					Neck = { rot = Vector3.new(-11.02, 11.81, 0) },
					RightShoulder = { rot = Vector3.new(29.28, 0, -7.34) },
					LeftShoulder = { rot = Vector3.new(80.03, 0, 22.47) },
					RightHip = { rot = Vector3.new(9.27, 0, 4.36), pos = Vector3.new(0, 0.434, 0) },
					LeftHip = { rot = Vector3.new(14.97, 0, -6.57), pos = Vector3.new(0, 0.505, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = {
						rot = Vector3.new(-14.48, -14.78, 0),
						pos = Vector3.new(0, -0.389, 0.093),
					},
					Neck = { rot = Vector3.new(-15.4, 12.21, 0) },
					RightShoulder = { rot = Vector3.new(7.25, 0, -1.05) },
					LeftShoulder = { rot = Vector3.new(70.18, 0, 17.67) },
					RightHip = { rot = Vector3.new(12.34, 0, 6.28), pos = Vector3.new(0, 0.434, 0) },
					LeftHip = {
						rot = Vector3.new(23.28, 0, -10.87),
						pos = Vector3.new(0, 0.555, 0),
					},
				},
			},
			{
				time = 0.15,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-14.99, -15, 0), pos = Vector3.new(0, -0.42, 0.1) },
					Neck = { rot = Vector3.new(-17.35, 12.28, 0) },
					RightShoulder = { rot = Vector3.new(-10.25, 0, -8.27) },
					LeftShoulder = { rot = Vector3.new(65.68, 0, 15.47) },
					RightHip = { rot = Vector3.new(13.89, 0, 7.02), pos = Vector3.new(0, 0.39, 0) },
					LeftHip = { rot = Vector3.new(29.07, 0, -13.7), pos = Vector3.new(0, 0.477, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-14.42, -15.16, 0.1),
						pos = Vector3.new(0, -0.416, 0.103),
					},
					Neck = { rot = Vector3.new(-17.33, 12.13, 0) },
					RightShoulder = { rot = Vector3.new(-10.55, 0, -8.33) },
					LeftShoulder = { rot = Vector3.new(66.03, 0, 15.34) },
					RightHip = { rot = Vector3.new(13.34, 0, 7.02), pos = Vector3.new(0, 0.388, 0) },
					LeftHip = {
						rot = Vector3.new(29.06, 0, -14.06),
						pos = Vector3.new(0, 0.451, 0),
					},
				},
			},
			{
				time = 0.25,
				pose = {
					Root = {
						rot = Vector3.new(-12.91, -15.6, 0.37),
						pos = Vector3.new(0, -0.407, 0.11),
					},
					Neck = { rot = Vector3.new(-15.85, 12.37, 0) },
					RightShoulder = { rot = Vector3.new(-11.2, 0, -8.43) },
					LeftShoulder = { rot = Vector3.new(67.04, 0, 15.01) },
					RightHip = { rot = Vector3.new(11.85, 0, 7.02), pos = Vector3.new(0, 0.383, 0) },
					LeftHip = {
						rot = Vector3.new(27.19, 0, -14.18),
						pos = Vector3.new(0, 0.449, 0),
					},
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-10.69, -16.25, 0.74),
						pos = Vector3.new(0, -0.394, 0.12),
					},
					Neck = { rot = Vector3.new(-13.42, 12.71, 0) },
					RightShoulder = { rot = Vector3.new(-12.16, 0, -8.55) },
					LeftShoulder = { rot = Vector3.new(68.55, 0, 14.52) },
					RightHip = { rot = Vector3.new(9.66, 0, 7.1), pos = Vector3.new(0, 0.376, 0) },
					LeftHip = { rot = Vector3.new(24.45, 0, -14.3), pos = Vector3.new(0, 0.443, 0) },
				},
			},
			{
				time = 0.35,
				pose = {
					Root = {
						rot = Vector3.new(-8.02, -17.02, 1.16),
						pos = Vector3.new(0, -0.378, 0.132),
					},
					Neck = { rot = Vector3.new(-10.41, 13.1, 0) },
					RightShoulder = { rot = Vector3.new(-13.31, 0, -8.68) },
					LeftShoulder = { rot = Vector3.new(70.43, 0, 13.91) },
					RightHip = { rot = Vector3.new(7.03, 0, 7.31), pos = Vector3.new(0, 0.368, 0) },
					LeftHip = {
						rot = Vector3.new(21.15, 0, -14.32),
						pos = Vector3.new(0, 0.434, 0),
					},
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-5.16, -17.86, 1.55),
						pos = Vector3.new(0, -0.361, 0.145),
					},
					Neck = { rot = Vector3.new(-7.15, 13.48, 0) },
					RightShoulder = { rot = Vector3.new(-14.55, 0, -8.78) },
					LeftShoulder = { rot = Vector3.new(72.53, 0, 13.24) },
					RightHip = { rot = Vector3.new(4.22, 0, 7.69), pos = Vector3.new(0, 0.361, 0) },
					LeftHip = { rot = Vector3.new(17.6, 0, -14.19), pos = Vector3.new(0, 0.421, 0) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = {
						rot = Vector3.new(-2.36, -18.68, 1.87),
						pos = Vector3.new(0, -0.344, 0.159),
					},
					Neck = { rot = Vector3.new(-3.96, 13.83, 0) },
					RightShoulder = { rot = Vector3.new(-15.75, 0, -8.82) },
					LeftShoulder = { rot = Vector3.new(74.71, 0, 12.56) },
					RightHip = { rot = Vector3.new(1.48, 0, 8.25), pos = Vector3.new(0, 0.355, 0) },
					LeftHip = {
						rot = Vector3.new(14.12, 0, -13.87),
						pos = Vector3.new(0, 0.404, 0),
					},
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(0.13, -19.42, 2.04),
						pos = Vector3.new(0, -0.33, 0.17),
					},
					Neck = { rot = Vector3.new(-1.18, 14.13, 0) },
					RightShoulder = { rot = Vector3.new(-16.82, 0, -8.77) },
					LeftShoulder = { rot = Vector3.new(76.82, 0, 11.92) },
					RightHip = { rot = Vector3.new(-0.94, 0, 8.97), pos = Vector3.new(0, 0.353, 0) },
					LeftHip = {
						rot = Vector3.new(11.02, 0, -13.35),
						pos = Vector3.new(0, 0.384, 0),
					},
				},
			},
			{
				time = 0.55,
				pose = {
					Root = { rot = Vector3.new(2.06, -20, 2), pos = Vector3.new(0, -0.319, 0.18) },
					Neck = { rot = Vector3.new(0.86, 14.34, 0) },
					RightShoulder = { rot = Vector3.new(-17.65, 0, -8.61) },
					LeftShoulder = { rot = Vector3.new(78.73, 0, 11.35) },
					RightHip = { rot = Vector3.new(-2.79, 0, 9.79), pos = Vector3.new(0, 0.354, 0) },
					LeftHip = { rot = Vector3.new(8.62, 0, -12.68), pos = Vector3.new(0, 0.365, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(3.31, -20.41, 1.47),
						pos = Vector3.new(0, -0.312, 0.187),
					},
					Neck = { rot = Vector3.new(1.53, 14.52, 0) },
					RightShoulder = { rot = Vector3.new(-18.17, 0, -8.08) },
					LeftShoulder = { rot = Vector3.new(80.58, 0, 10.79) },
					RightHip = {
						rot = Vector3.new(-3.95, 0, 11.01),
						pos = Vector3.new(0, 0.364, 0),
					},
					LeftHip = { rot = Vector3.new(7.06, 0, -11.55), pos = Vector3.new(0, 0.343, 0) },
				},
			},
			{
				time = 0.65,
				pose = {
					Root = {
						rot = Vector3.new(4.05, -20.71, 0.43),
						pos = Vector3.new(0, -0.308, 0.192),
					},
					Neck = { rot = Vector3.new(0.81, 14.74, 0) },
					RightShoulder = { rot = Vector3.new(-18.46, 0, -7.18) },
					LeftShoulder = { rot = Vector3.new(82.57, 0, 10.18) },
					RightHip = {
						rot = Vector3.new(-4.59, 0, 12.67),
						pos = Vector3.new(0, 0.384, 0),
					},
					LeftHip = { rot = Vector3.new(6.14, 0, -9.92), pos = Vector3.new(0, 0.316, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = {
						rot = Vector3.new(4.45, -20.89, -0.75),
						pos = Vector3.new(0, -0.306, 0.195),
					},
					Neck = { rot = Vector3.new(-0.55, 14.94, 0) },
					RightShoulder = { rot = Vector3.new(-18.6, 0, -6.19) },
					LeftShoulder = { rot = Vector3.new(84.64, 0, 9.6) },
					RightHip = { rot = Vector3.new(-4.9, 0, 14.36), pos = Vector3.new(0, 0.405, 0) },
					LeftHip = { rot = Vector3.new(5.67, 0, -8.22), pos = Vector3.new(0, 0.291, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(4.67, -20.99, -1.69),
						pos = Vector3.new(0, -0.306, 0.198),
					},
					Neck = { rot = Vector3.new(-1.8, 15.04, 0) },
					RightShoulder = { rot = Vector3.new(-18.68, 0, -5.42) },
					LeftShoulder = { rot = Vector3.new(86.71, 0, 9.13) },
					RightHip = {
						rot = Vector3.new(-5.04, 0, 15.65),
						pos = Vector3.new(0, 0.422, 0),
					},
					LeftHip = { rot = Vector3.new(5.45, 0, -6.87), pos = Vector3.new(0, 0.271, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = { rot = Vector3.new(4.78, -21, -2), pos = Vector3.new(0, -0.305, 0.2) },
					Neck = { rot = Vector3.new(-2.18, 15.04, 0) },
					RightShoulder = { rot = Vector3.new(-18.74, 0, -5.18) },
					LeftShoulder = { rot = Vector3.new(87.91, 0, 8.93) },
					RightHip = {
						rot = Vector3.new(-5.13, 0, 16.08),
						pos = Vector3.new(0, 0.428, 0),
					},
					LeftHip = { rot = Vector3.new(5.35, 0, -6.42), pos = Vector3.new(0, 0.264, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = {
						rot = Vector3.new(4.76, -20.93, -1.93),
						pos = Vector3.new(0, -0.305, 0.201),
					},
					Neck = { rot = Vector3.new(-2.06, 14.91, 0) },
					RightShoulder = { rot = Vector3.new(-18.74, 0, -5.28) },
					LeftShoulder = { rot = Vector3.new(88.8, 0, 8.89) },
					RightHip = {
						rot = Vector3.new(-5.11, 0, 15.96),
						pos = Vector3.new(0, 0.426, 0),
					},
					LeftHip = { rot = Vector3.new(5.44, 0, -6.53), pos = Vector3.new(0, 0.265, 0) },
				},
			},
			{
				time = 0.85,
				pose = {
					Root = {
						rot = Vector3.new(4.12, -20.38, -0.82),
						pos = Vector3.new(0, -0.307, 0.201),
					},
					Neck = { rot = Vector3.new(-0.55, 14.08, 0) },
					RightShoulder = { rot = Vector3.new(-18.56, 0, -6.39) },
					LeftShoulder = { rot = Vector3.new(91.26, 0, 9.14) },
					RightHip = { rot = Vector3.new(-4.6, 0, 14.21), pos = Vector3.new(0, 0.405, 0) },
					LeftHip = { rot = Vector3.new(6.44, 0, -8.26), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.9,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(3.61, -20, 0), pos = Vector3.new(0, -0.31, 0.2) },
					Neck = { rot = Vector3.new(0.36, 13.69, 0) },
					RightShoulder = { rot = Vector3.new(-18.41, 0, -7.2) },
					LeftShoulder = { rot = Vector3.new(92.52, 0, 9.37) },
					RightHip = { rot = Vector3.new(-4.17, 0, 12.9), pos = Vector3.new(0, 0.39, 0) },
					LeftHip = { rot = Vector3.new(7.21, 0, -9.55), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.95,
				pose = {
					Root = {
						rot = Vector3.new(1.96, -10.91, 0),
						pos = Vector3.new(0.011, -0.303, 0.192),
					},
					Neck = { rot = Vector3.new(1.89, 4.1, 0) },
					RightShoulder = { rot = Vector3.new(9.47, 0, -4.24) },
					LeftShoulder = { rot = Vector3.new(93.9, 0, 17.93) },
					RightHip = {
						rot = Vector3.new(-6.51, 0, 11.25),
						pos = Vector3.new(0, 0.361, 0),
					},
					LeftHip = { rot = Vector3.new(12.77, 0, -8.79), pos = Vector3.new(0, 0.283, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = {
						rot = Vector3.new(-1.08, 6.21, 0),
						pos = Vector3.new(0.031, -0.288, 0.178),
					},
					Neck = { rot = Vector3.new(5.09, -8.54, 0) },
					RightShoulder = { rot = Vector3.new(41.52, 0, -14.96) },
					LeftShoulder = { rot = Vector3.new(96.65, 0, 34.49) },
					RightHip = {
						rot = Vector3.new(-10.06, 0, 8.05),
						pos = Vector3.new(0, 0.301, 0),
					},
					LeftHip = { rot = Vector3.new(23.25, 0, -4.22), pos = Vector3.new(0, 0.168, 0) },
				},
			},
			{
				time = 1.03,
				pose = {
					Root = {
						rot = Vector3.new(-2.45, 14, 0),
						pos = Vector3.new(0.04, -0.281, 0.17),
					},
					Neck = { rot = Vector3.new(6, -13.32, 0) },
					RightShoulder = { rot = Vector3.new(56.31, 0, -21.84) },
					LeftShoulder = { rot = Vector3.new(98, 0, 41.68) },
					RightHip = {
						rot = Vector3.new(-11.37, 0, 6.63),
						pos = Vector3.new(0, 0.274, 0),
					},
					LeftHip = { rot = Vector3.new(27.95, 0, -0.81), pos = Vector3.new(0, 0.085, 0) },
				},
			},
			{
				time = 1.05,
				pose = {
					Root = {
						rot = Vector3.new(-3.03, 17.31, 0),
						pos = Vector3.new(0.044, -0.278, 0.166),
					},
					Neck = { rot = Vector3.new(6.16, -15.53, 0) },
					RightShoulder = { rot = Vector3.new(61.26, 0, -21.39) },
					LeftShoulder = { rot = Vector3.new(98.62, 0, 43.72) },
					RightHip = {
						rot = Vector3.new(-11.91, 0, 6.05),
						pos = Vector3.new(0, 0.262, 0),
					},
					LeftHip = { rot = Vector3.new(29.9, 0, 0.88), pos = Vector3.new(0, 0.044, 0) },
				},
			},
			{
				time = 1.1,
				pose = {
					Root = {
						rot = Vector3.new(-4.02, 23.05, 0),
						pos = Vector3.new(0.049, -0.296, 0.155),
					},
					Neck = { rot = Vector3.new(6.42, -17.21, 0) },
					RightShoulder = { rot = Vector3.new(69.9, 0, -15.22) },
					LeftShoulder = { rot = Vector3.new(99.86, 0, 46.55) },
					RightHip = {
						rot = Vector3.new(-12.94, 0, 5.02),
						pos = Vector3.new(0, 0.263, 0),
					},
					LeftHip = { rot = Vector3.new(32.9, 0, 4.01) },
				},
			},
			{
				time = 1.15,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-4.29, 25, 0),
						pos = Vector3.new(0.05, -0.312, 0.15),
					},
					Neck = { rot = Vector3.new(6.38, -16.08, 0) },
					RightShoulder = { rot = Vector3.new(73.17, 0, -10.58) },
					LeftShoulder = { rot = Vector3.new(100.39, 0, 47.51) },
					RightHip = {
						rot = Vector3.new(-13.42, 0, 4.62),
						pos = Vector3.new(0, 0.271, 0),
					},
					LeftHip = { rot = Vector3.new(33.65, 0, 5.06) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-4.14, 24.99, 0.01),
						pos = Vector3.new(0.05, -0.309, 0.15),
					},
					Neck = { rot = Vector3.new(5.93, -14.32, 0.38) },
					RightShoulder = { rot = Vector3.new(73.15, 0, -10.58) },
					LeftShoulder = { rot = Vector3.new(100.35, 0, 47.52) },
					RightHip = {
						rot = Vector3.new(-13.61, 0, 4.53),
						pos = Vector3.new(0, 0.266, 0),
					},
					LeftHip = { rot = Vector3.new(33.42, 0, 4.98) },
				},
			},
			{
				time = 1.25,
				pose = {
					Root = {
						rot = Vector3.new(-3.92, 24.98, 0.02),
						pos = Vector3.new(0.05, -0.304, 0.15),
					},
					Neck = { rot = Vector3.new(5.63, -14.53, 1.39) },
					RightShoulder = { rot = Vector3.new(73.07, 0, -10.6) },
					LeftShoulder = { rot = Vector3.new(100.26, 0, 47.51) },
					RightHip = { rot = Vector3.new(-13.87, 0, 4.4), pos = Vector3.new(0, 0.259, 0) },
					LeftHip = { rot = Vector3.new(33.08, 0, 4.83) },
				},
			},
			{
				time = 1.3,
				pose = {
					Root = {
						rot = Vector3.new(-3.64, 24.96, 0.04),
						pos = Vector3.new(0.05, -0.298, 0.15),
					},
					Neck = { rot = Vector3.new(5.23, -15.12, 2.84) },
					RightShoulder = { rot = Vector3.new(72.94, 0, -10.62) },
					LeftShoulder = { rot = Vector3.new(100.12, 0, 47.51) },
					RightHip = { rot = Vector3.new(-14.2, 0, 4.23), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(32.65, 0, 4.65) },
				},
			},
			{
				time = 1.35,
				pose = {
					Root = {
						rot = Vector3.new(-3.34, 24.94, 0.06),
						pos = Vector3.new(0.049, -0.291, 0.151),
					},
					Neck = { rot = Vector3.new(4.73, -15.87, 4.54) },
					RightShoulder = { rot = Vector3.new(72.77, 0, -10.65) },
					LeftShoulder = { rot = Vector3.new(99.95, 0, 47.51) },
					RightHip = { rot = Vector3.new(-14.57, 0, 4.05), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(32.18, 0, 4.45) },
				},
			},
			{
				time = 1.4,
				pose = {
					Root = {
						rot = Vector3.new(-3.02, 24.92, 0.08),
						pos = Vector3.new(0.049, -0.285, 0.151),
					},
					Neck = { rot = Vector3.new(4.18, -16.71, 6.29) },
					RightShoulder = { rot = Vector3.new(72.59, 0, -10.68) },
					LeftShoulder = { rot = Vector3.new(99.75, 0, 47.51) },
					RightHip = { rot = Vector3.new(-14.96, 0, 3.86), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(31.69, 0, 4.25) },
				},
			},
			{
				time = 1.45,
				pose = {
					Root = {
						rot = Vector3.new(-2.72, 24.92, 0.08),
						pos = Vector3.new(0.049, -0.279, 0.151),
					},
					Neck = { rot = Vector3.new(3.58, -17.6, 7.91) },
					RightShoulder = { rot = Vector3.new(72.39, 0, -10.7) },
					LeftShoulder = { rot = Vector3.new(99.54, 0, 47.52) },
					RightHip = { rot = Vector3.new(-15.34, 0, 3.69), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(31.22, 0, 4.07) },
				},
			},
			{
				time = 1.5,
				pose = {
					Root = {
						rot = Vector3.new(-2.44, 24.92, 0.08),
						pos = Vector3.new(0.049, -0.274, 0.151),
					},
					Neck = { rot = Vector3.new(2.99, -18.49, 9.19) },
					RightShoulder = { rot = Vector3.new(72.19, 0, -10.71) },
					LeftShoulder = { rot = Vector3.new(99.34, 0, 47.52) },
					RightHip = { rot = Vector3.new(-15.7, 0, 3.54), pos = Vector3.new(0, 0.212, 0) },
					LeftHip = { rot = Vector3.new(30.8, 0, 3.93) },
				},
			},
			{
				time = 1.55,
				pose = {
					Root = {
						rot = Vector3.new(-2.22, 24.95, 0.05),
						pos = Vector3.new(0.05, -0.27, 0.15),
					},
					Neck = { rot = Vector3.new(2.41, -19.32, 9.95) },
					RightShoulder = { rot = Vector3.new(72, 0, -10.7) },
					LeftShoulder = { rot = Vector3.new(99.15, 0, 47.54) },
					RightHip = {
						rot = Vector3.new(-15.99, 0, 3.44),
						pos = Vector3.new(0, 0.206, 0),
					},
					LeftHip = { rot = Vector3.new(30.47, 0, 3.84) },
				},
			},
			{
				time = 1.6,
				pose = {
					Root = {
						rot = Vector3.new(-2.07, 25, 0),
						pos = Vector3.new(0.05, -0.268, 0.15),
					},
					Neck = { rot = Vector3.new(1.88, -20.04, 10) },
					RightShoulder = { rot = Vector3.new(71.83, 0, -10.66) },
					LeftShoulder = { rot = Vector3.new(98.98, 0, 47.56) },
					RightHip = {
						rot = Vector3.new(-16.21, 0, 3.38),
						pos = Vector3.new(0, 0.203, 0),
					},
					LeftHip = { rot = Vector3.new(30.25, 0, 3.82) },
				},
			},
			{
				time = 1.65,
				pose = {
					Root = {
						rot = Vector3.new(-1.96, 25.1, -0.1),
						pos = Vector3.new(0.051, -0.268, 0.149),
					},
					Neck = { rot = Vector3.new(1.3, -20.72, 8.98) },
					RightShoulder = { rot = Vector3.new(71.64, 0, -10.58) },
					LeftShoulder = { rot = Vector3.new(98.8, 0, 47.59) },
					RightHip = { rot = Vector3.new(-16.4, 0, 3.39), pos = Vector3.new(0, 0.202, 0) },
					LeftHip = { rot = Vector3.new(30.1, 0, 3.9) },
				},
			},
			{
				time = 1.7,
				pose = {
					Root = {
						rot = Vector3.new(-1.86, 25.26, -0.26),
						pos = Vector3.new(0.053, -0.269, 0.147),
					},
					Neck = { rot = Vector3.new(0.6, -21.43, 6.92) },
					RightShoulder = { rot = Vector3.new(71.41, 0, -10.45) },
					LeftShoulder = { rot = Vector3.new(98.58, 0, 47.65) },
					RightHip = { rot = Vector3.new(-16.6, 0, 3.45), pos = Vector3.new(0, 0.204, 0) },
					LeftHip = { rot = Vector3.new(29.99, 0, 4.08) },
				},
			},
			{
				time = 1.75,
				pose = {
					Root = {
						rot = Vector3.new(-1.81, 25.45, -0.45),
						pos = Vector3.new(0.055, -0.273, 0.145),
					},
					Neck = { rot = Vector3.new(-0.13, -22.11, 4.19) },
					RightShoulder = { rot = Vector3.new(71.17, 0, -10.28) },
					LeftShoulder = { rot = Vector3.new(98.35, 0, 47.71) },
					RightHip = {
						rot = Vector3.new(-16.74, 0, 3.55),
						pos = Vector3.new(0, 0.209, 0),
					},
					LeftHip = { rot = Vector3.new(29.96, 0, 4.33) },
				},
			},
			{
				time = 1.8,
				pose = {
					Root = {
						rot = Vector3.new(-1.83, 25.65, -0.65),
						pos = Vector3.new(0.057, -0.277, 0.143),
					},
					Neck = { rot = Vector3.new(-0.81, -22.73, 1.16) },
					RightShoulder = { rot = Vector3.new(70.94, 0, -10.11) },
					LeftShoulder = { rot = Vector3.new(98.15, 0, 47.77) },
					RightHip = {
						rot = Vector3.new(-16.81, 0, 3.69),
						pos = Vector3.new(0, 0.215, 0),
					},
					LeftHip = { rot = Vector3.new(30.03, 0, 4.62) },
				},
			},
			{
				time = 1.85,
				pose = {
					Root = {
						rot = Vector3.new(-1.93, 25.83, -0.83),
						pos = Vector3.new(0.058, -0.283, 0.142),
					},
					Neck = { rot = Vector3.new(-1.39, -23.28, -1.79) },
					RightShoulder = { rot = Vector3.new(70.77, 0, -9.96) },
					LeftShoulder = { rot = Vector3.new(97.99, 0, 47.83) },
					RightHip = {
						rot = Vector3.new(-16.76, 0, 3.86),
						pos = Vector3.new(0, 0.224, 0),
					},
					LeftHip = { rot = Vector3.new(30.22, 0, 4.92) },
				},
			},
			{
				time = 1.9,
				pose = {
					Root = {
						rot = Vector3.new(-2.12, 25.95, -0.95),
						pos = Vector3.new(0.06, -0.289, 0.14),
					},
					Neck = { rot = Vector3.new(-1.81, -23.73, -4.3) },
					RightShoulder = { rot = Vector3.new(70.69, 0, -9.84) },
					LeftShoulder = { rot = Vector3.new(97.93, 0, 47.87) },
					RightHip = {
						rot = Vector3.new(-16.57, 0, 4.05),
						pos = Vector3.new(0, 0.234, 0),
					},
					LeftHip = { rot = Vector3.new(30.54, 0, 5.21) },
				},
			},
			{
				time = 1.95,
				pose = {
					Root = {
						rot = Vector3.new(-2.42, 26, -1),
						pos = Vector3.new(0.06, -0.296, 0.14),
					},
					Neck = { rot = Vector3.new(-2, -24.06, -6) },
					RightShoulder = { rot = Vector3.new(70.73, 0, -9.79) },
					LeftShoulder = { rot = Vector3.new(97.98, 0, 47.88) },
					RightHip = {
						rot = Vector3.new(-16.21, 0, 4.25),
						pos = Vector3.new(0, 0.245, 0),
					},
					LeftHip = { rot = Vector3.new(31.01, 0, 5.45) },
				},
			},
			{
				time = 2,
				pose = {
					Root = {
						rot = Vector3.new(-2.94, 25.9, -0.9),
						pos = Vector3.new(0.059, -0.304, 0.141),
					},
					Neck = { rot = Vector3.new(-1.72, -24.15, -6.54) },
					RightShoulder = { rot = Vector3.new(71.06, 0, -9.87) },
					LeftShoulder = { rot = Vector3.new(98.3, 0, 47.84) },
					RightHip = {
						rot = Vector3.new(-15.51, 0, 4.48),
						pos = Vector3.new(0, 0.258, 0),
					},
					LeftHip = { rot = Vector3.new(31.78, 0, 5.6) },
				},
			},
			{
				time = 2.05,
				pose = {
					Root = {
						rot = Vector3.new(-3.66, 25.65, -0.65),
						pos = Vector3.new(0.056, -0.313, 0.144),
					},
					Neck = { rot = Vector3.new(-1, -24.04, -6.14) },
					RightShoulder = { rot = Vector3.new(71.67, 0, -10.06) },
					LeftShoulder = { rot = Vector3.new(98.91, 0, 47.75) },
					RightHip = {
						rot = Vector3.new(-14.51, 0, 4.72),
						pos = Vector3.new(0, 0.273, 0),
					},
					LeftHip = { rot = Vector3.new(32.84, 0, 5.65) },
				},
			},
			{
				time = 2.1,
				pose = {
					Root = {
						rot = Vector3.new(-4.4, 25.35, -0.35),
						pos = Vector3.new(0.054, -0.322, 0.146),
					},
					Neck = { rot = Vector3.new(-0.27, -23.9, -5.26) },
					RightShoulder = { rot = Vector3.new(72.37, 0, -10.29) },
					LeftShoulder = { rot = Vector3.new(99.6, 0, 47.65) },
					RightHip = {
						rot = Vector3.new(-13.46, 0, 4.92),
						pos = Vector3.new(0, 0.286, 0),
					},
					LeftHip = { rot = Vector3.new(33.91, 0, 5.64) },
				},
			},
			{
				time = 2.15,
				pose = {
					Root = {
						rot = Vector3.new(-4.97, 25.1, -0.1),
						pos = Vector3.new(0.051, -0.328, 0.149),
					},
					Neck = { rot = Vector3.new(0.22, -23.82, -4.39) },
					RightShoulder = { rot = Vector3.new(72.94, 0, -10.48) },
					LeftShoulder = { rot = Vector3.new(100.16, 0, 47.56) },
					RightHip = {
						rot = Vector3.new(-12.65, 0, 5.06),
						pos = Vector3.new(0, 0.296, 0),
					},
					LeftHip = { rot = Vector3.new(34.74, 0, 5.6) },
				},
			},
			{
				time = 2.2,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-5.19, 25, 0),
						pos = Vector3.new(0.05, -0.331, 0.15),
					},
					Neck = { rot = Vector3.new(0.23, -23.88, -4) },
					RightShoulder = { rot = Vector3.new(73.18, 0, -10.57) },
					LeftShoulder = { rot = Vector3.new(100.39, 0, 47.52) },
					RightHip = { rot = Vector3.new(-12.34, 0, 5.1), pos = Vector3.new(0, 0.299, 0) },
					LeftHip = { rot = Vector3.new(35.06, 0, 5.57) },
				},
			},
			{
				time = 2.25,
				pose = {
					Root = {
						rot = Vector3.new(-5.14, 25, 0),
						pos = Vector3.new(0.05, -0.329, 0.15),
					},
					Neck = { rot = Vector3.new(0.54, -22.95, -2.96) },
					RightShoulder = { rot = Vector3.new(75.68, 0, -9.65) },
					LeftShoulder = { rot = Vector3.new(100.39, 0, 47.52) },
					RightHip = { rot = Vector3.new(-12.4, 0, 5.07), pos = Vector3.new(0, 0.298, 0) },
					LeftHip = { rot = Vector3.new(34.98, 0, 5.54) },
				},
			},
			{
				time = 2.3,
				pose = {
					Root = {
						rot = Vector3.new(-5.01, 25, 0),
						pos = Vector3.new(0.05, -0.327, 0.15),
					},
					Neck = { rot = Vector3.new(1.48, -21.04, -1.04) },
					RightShoulder = { rot = Vector3.new(80.36, 0, -7.98) },
					LeftShoulder = { rot = Vector3.new(100.39, 0, 47.52) },
					RightHip = {
						rot = Vector3.new(-12.55, 0, 5.01),
						pos = Vector3.new(0, 0.294, 0),
					},
					LeftHip = { rot = Vector3.new(34.78, 0, 5.47) },
				},
			},
			{
				time = 2.35,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-4.82, 25, 0),
						pos = Vector3.new(0.05, -0.323, 0.15),
					},
					Neck = { rot = Vector3.new(2, -20, 0) },
					RightShoulder = { rot = Vector3.new(82.91, 0, -7.11) },
					LeftShoulder = { rot = Vector3.new(100.39, 0, 47.52) },
					RightHip = { rot = Vector3.new(-12.78, 0, 4.9), pos = Vector3.new(0, 0.288, 0) },
					LeftHip = { rot = Vector3.new(34.48, 0, 5.36) },
				},
			},
			{
				time = 2.4,
				pose = {
					Root = {
						rot = Vector3.new(-2.7, 25, 0),
						pos = Vector3.new(0.058, -0.305, 0.189),
					},
					Neck = { rot = Vector3.new(-0.47, -19.69, 0) },
					RightShoulder = { rot = Vector3.new(87.53, 0, -6.63) },
					LeftShoulder = { rot = Vector3.new(82.34, 0, 40.83) },
					RightHip = { rot = Vector3.new(-14.29, 0, 3.99), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(32.55, 0, 4.44) },
				},
			},
			{
				time = 2.45,
				pose = {
					Root = {
						rot = Vector3.new(1.7, 25, 0),
						pos = Vector3.new(0.075, -0.272, 0.275),
					},
					Neck = { rot = Vector3.new(-5.42, -19, 0) },
					RightShoulder = { rot = Vector3.new(98.15, 0, -5.8) },
					LeftShoulder = { rot = Vector3.new(65.29, 0, 27.45) },
					RightHip = {
						rot = Vector3.new(-17.44, 0, 2.09),
						pos = Vector3.new(0, 0.204, 0),
					},
					LeftHip = { rot = Vector3.new(28.66, 0, 2.47) },
				},
			},
			{
				time = 2.5,
				pose = {
					Root = {
						rot = Vector3.new(6.13, 25, 0),
						pos = Vector3.new(0.092, -0.262, 0.361),
					},
					Neck = { rot = Vector3.new(-8.57, -18.31, 0) },
					RightShoulder = { rot = Vector3.new(108.84, 0, -5.4) },
					LeftShoulder = { rot = Vector3.new(49.51, 0, 13.33) },
					RightHip = {
						rot = Vector3.new(-21.41, 0, -0.12),
						pos = Vector3.new(0, 0.192, 0),
					},
					LeftHip = { rot = Vector3.new(25.01, 0, 0.54) },
				},
			},
			{
				time = 2.525,
				pose = {
					Root = {
						rot = Vector3.new(7.63, 25, 0),
						pos = Vector3.new(0.098, -0.249, 0.389),
					},
					Neck = { rot = Vector3.new(-8.91, -18.09, 0) },
					RightShoulder = { rot = Vector3.new(112.27, 0, -5.36) },
					LeftShoulder = { rot = Vector3.new(39.7, 0, 4.88) },
					RightHip = {
						rot = Vector3.new(-24.95, 0, -1.73),
						pos = Vector3.new(0, 0.19, 0),
					},
					LeftHip = { rot = Vector3.new(23.62, 0, -0.19) },
				},
			},
			{
				time = 2.55,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(8.29, 25, 0), pos = Vector3.new(0.1, -0.168, 0.4) },
					Neck = { rot = Vector3.new(-8.18, -18, 0) },
					RightShoulder = { rot = Vector3.new(113.55, 0, -5.36) },
					LeftShoulder = { rot = Vector3.new(34.71, 0, 0.9) },
					RightHip = {
						rot = Vector3.new(-29.21, 0, -3.46),
						pos = Vector3.new(0, 0.054, 0),
					},
					LeftHip = { rot = Vector3.new(22.01, 0, -0.92) },
				},
			},
			{
				time = 2.575,
				pose = {
					Root = {
						rot = Vector3.new(8.33, 24.94, 0),
						pos = Vector3.new(0.1, -0.2, 0.399),
					},
					Neck = { rot = Vector3.new(-6.74, -17.89, -0.01) },
					RightShoulder = { rot = Vector3.new(112.16, 0, -4.92) },
					LeftShoulder = { rot = Vector3.new(34.48, 0, 0.9) },
					RightHip = { rot = Vector3.new(-32.17, 0, -4.5) },
					LeftHip = { rot = Vector3.new(20.69, 0, -1.47), pos = Vector3.new(0, 0.092, 0) },
				},
			},
			{
				time = 2.6,
				pose = {
					Root = {
						rot = Vector3.new(8.17, 24.76, 0),
						pos = Vector3.new(0.099, -0.273, 0.398),
					},
					Neck = { rot = Vector3.new(-5.21, -17.59, -0.02) },
					RightShoulder = { rot = Vector3.new(108.45, 0, -3.79) },
					LeftShoulder = { rot = Vector3.new(33.86, 0, 0.95) },
					RightHip = { rot = Vector3.new(-33.29, 0, -4.82) },
					LeftHip = { rot = Vector3.new(19.31, 0, -2.06), pos = Vector3.new(0, 0.178, 0) },
				},
			},
			{
				time = 2.65,
				pose = {
					Root = {
						rot = Vector3.new(7.35, 24.08, 0),
						pos = Vector3.new(0.095, -0.239, 0.391),
					},
					Neck = { rot = Vector3.new(-2.38, -16.52, -0.07) },
					RightShoulder = { rot = Vector3.new(97.01, 0, -0.78) },
					LeftShoulder = { rot = Vector3.new(31.58, 0, 1.16) },
					RightHip = { rot = Vector3.new(-31.92, 0, -3.92) },
					LeftHip = { rot = Vector3.new(18.09, 0, -2.59), pos = Vector3.new(0, 0.093, 0) },
				},
			},
			{
				time = 2.7,
				pose = {
					Root = {
						rot = Vector3.new(5.98, 23.07, 0),
						pos = Vector3.new(0.09, -0.216, 0.381),
					},
					Neck = { rot = Vector3.new(1.01, -15.16, -0.13) },
					RightShoulder = { rot = Vector3.new(85.61, 0, 1.5) },
					LeftShoulder = { rot = Vector3.new(28.16, 0, 1.54) },
					RightHip = { rot = Vector3.new(-30.03, 0, -2.71) },
					LeftHip = { rot = Vector3.new(19.27, 0, -2.15), pos = Vector3.new(0, 0.065, 0) },
				},
			},
			{
				time = 2.75,
				pose = {
					Root = {
						rot = Vector3.new(4.19, 21.82, 0),
						pos = Vector3.new(0.084, -0.189, 0.368),
					},
					Neck = { rot = Vector3.new(4.75, -13.64, -0.2) },
					RightShoulder = { rot = Vector3.new(75.94, 0, 2.83) },
					LeftShoulder = { rot = Vector3.new(23.95, 0, 2.1) },
					RightHip = { rot = Vector3.new(-27.53, 0, -1.22) },
					LeftHip = { rot = Vector3.new(20.93, 0, -1.62), pos = Vector3.new(0, 0.028, 0) },
				},
			},
			{
				time = 2.8,
				pose = {
					Root = {
						rot = Vector3.new(2.14, 20.4, 0),
						pos = Vector3.new(0.077, -0.171, 0.354),
					},
					Neck = { rot = Vector3.new(8.45, -12.06, -0.25) },
					RightShoulder = { rot = Vector3.new(65.89, 0, 3.61) },
					LeftShoulder = { rot = Vector3.new(19.34, 0, 2.83) },
					RightHip = {
						rot = Vector3.new(-24.57, 0, 0.42),
						pos = Vector3.new(0, 0.014, 0),
					},
					LeftHip = { rot = Vector3.new(22.96, 0, -1.07) },
				},
			},
			{
				time = 2.85,
				pose = {
					Root = {
						rot = Vector3.new(-0.02, 18.93, 0),
						pos = Vector3.new(0.07, -0.187, 0.339),
					},
					Neck = { rot = Vector3.new(11.73, -10.5, -0.27) },
					RightShoulder = { rot = Vector3.new(56.02, 0, 3.77) },
					LeftShoulder = { rot = Vector3.new(14.76, 0, 3.69) },
					RightHip = { rot = Vector3.new(-21.4, 0, 2.07), pos = Vector3.new(0, 0.065, 0) },
					LeftHip = { rot = Vector3.new(25.24, 0, -0.59), pos = Vector3.new(0, 0.001, 0) },
				},
			},
			{
				time = 2.9,
				pose = {
					Root = {
						rot = Vector3.new(-2.11, 17.47, 0),
						pos = Vector3.new(0.062, -0.204, 0.325),
					},
					Neck = { rot = Vector3.new(14.2, -9.08, -0.24) },
					RightShoulder = { rot = Vector3.new(44.95, 0, 3.34) },
					LeftShoulder = { rot = Vector3.new(10.61, 0, 4.61) },
					RightHip = { rot = Vector3.new(-18.39, 0, 3.54), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(27.43, 0, -0.26), pos = Vector3.new(0, 0.006, 0) },
				},
			},
			{
				time = 2.95,
				pose = {
					Root = {
						rot = Vector3.new(-3.98, 16.13, 0),
						pos = Vector3.new(0.056, -0.221, 0.311),
					},
					Neck = { rot = Vector3.new(15.48, -7.87, -0.16) },
					RightShoulder = { rot = Vector3.new(33.61, 0, 2.12) },
					LeftShoulder = { rot = Vector3.new(7.25, 0, 5.48) },
					RightHip = {
						rot = Vector3.new(-15.75, 0, 4.74),
						pos = Vector3.new(0, 0.148, 0),
					},
					LeftHip = { rot = Vector3.new(29.35, 0, -0.08), pos = Vector3.new(0, 0.014, 0) },
				},
			},
			{
				time = 3,
				pose = {
					Root = { rot = Vector3.new(-5.44, 15, 0), pos = Vector3.new(0.05, -0.236, 0.3) },
					Neck = { rot = Vector3.new(15.17, -6.99, 0) },
					RightShoulder = { rot = Vector3.new(26.59, 0, 0.75) },
					LeftShoulder = { rot = Vector3.new(4.98, 0, 6.21) },
					RightHip = { rot = Vector3.new(-13.7, 0, 5.63), pos = Vector3.new(0, 0.178, 0) },
					LeftHip = { rot = Vector3.new(30.79, 0, -0.06), pos = Vector3.new(0, 0.024, 0) },
				},
			},
			{
				time = 3.05,
				pose = {
					Root = {
						rot = Vector3.new(-6.6, 13.99, 0),
						pos = Vector3.new(0.045, -0.25, 0.29),
					},
					Neck = { rot = Vector3.new(13.53, -6.25, 0.28) },
					RightShoulder = { rot = Vector3.new(23.36, 0, -0.33) },
					LeftShoulder = { rot = Vector3.new(3.54, 0, 6.84) },
					RightHip = { rot = Vector3.new(-12.1, 0, 6.31), pos = Vector3.new(0, 0.201, 0) },
					LeftHip = { rot = Vector3.new(31.82, 0, -0.14), pos = Vector3.new(0, 0.036, 0) },
				},
			},
			{
				time = 3.1,
				pose = {
					Root = {
						rot = Vector3.new(-7.63, 12.98, 0),
						pos = Vector3.new(0.04, -0.263, 0.28),
					},
					Neck = { rot = Vector3.new(11.19, -5.42, 0.69) },
					RightShoulder = { rot = Vector3.new(20.57, 0, -1.43) },
					LeftShoulder = { rot = Vector3.new(2.47, 0, 7.47) },
					RightHip = { rot = Vector3.new(-10.68, 0, 6.9), pos = Vector3.new(0, 0.222, 0) },
					LeftHip = { rot = Vector3.new(32.64, 0, -0.29), pos = Vector3.new(0, 0.051, 0) },
				},
			},
			{
				time = 3.15,
				pose = {
					Root = {
						rot = Vector3.new(-8.54, 11.97, 0),
						pos = Vector3.new(0.035, -0.276, 0.269),
					},
					Neck = { rot = Vector3.new(8.16, -4.62, 1.19) },
					RightShoulder = { rot = Vector3.new(18.14, 0, -2.53) },
					LeftShoulder = { rot = Vector3.new(1.69, 0, 8.08) },
					RightHip = { rot = Vector3.new(-9.42, 0, 7.42), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(33.25, 0, -0.51), pos = Vector3.new(0, 0.067, 0) },
				},
			},
			{
				time = 3.2,
				pose = {
					Root = {
						rot = Vector3.new(-9.34, 10.97, 0),
						pos = Vector3.new(0.03, -0.288, 0.259),
					},
					Neck = { rot = Vector3.new(4.58, -3.86, 1.74) },
					RightShoulder = { rot = Vector3.new(16.02, 0, -3.62) },
					LeftShoulder = { rot = Vector3.new(1.16, 0, 8.67) },
					RightHip = { rot = Vector3.new(-8.32, 0, 7.86), pos = Vector3.new(0, 0.256, 0) },
					LeftHip = { rot = Vector3.new(33.67, 0, -0.78), pos = Vector3.new(0, 0.084, 0) },
				},
			},
			{
				time = 3.25,
				pose = {
					Root = {
						rot = Vector3.new(-10.02, 9.99, 0),
						pos = Vector3.new(0.025, -0.298, 0.249),
					},
					Neck = { rot = Vector3.new(0.61, -3.14, 2.32) },
					RightShoulder = { rot = Vector3.new(14.16, 0, -4.69) },
					LeftShoulder = { rot = Vector3.new(0.82, 0, 9.25) },
					RightHip = { rot = Vector3.new(-7.37, 0, 8.24), pos = Vector3.new(0, 0.269, 0) },
					LeftHip = { rot = Vector3.new(33.92, 0, -1.09), pos = Vector3.new(0, 0.102, 0) },
				},
			},
			{
				time = 3.3,
				pose = {
					Root = {
						rot = Vector3.new(-10.59, 9.04, 0),
						pos = Vector3.new(0.02, -0.307, 0.24),
					},
					Neck = { rot = Vector3.new(-3.56, -2.45, 2.87) },
					RightShoulder = { rot = Vector3.new(12.52, 0, -5.72) },
					LeftShoulder = { rot = Vector3.new(0.62, 0, 9.81) },
					RightHip = { rot = Vector3.new(-6.56, 0, 8.56), pos = Vector3.new(0, 0.279, 0) },
					LeftHip = { rot = Vector3.new(34.03, 0, -1.42), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 3.35,
				pose = {
					Root = {
						rot = Vector3.new(-11.07, 8.13, 0),
						pos = Vector3.new(0.015, -0.315, 0.23),
					},
					Neck = { rot = Vector3.new(-7.77, -1.79, 3.36) },
					RightShoulder = { rot = Vector3.new(11.05, 0, -6.72) },
					LeftShoulder = { rot = Vector3.new(0.51, 0, 10.34) },
					RightHip = { rot = Vector3.new(-5.86, 0, 8.84), pos = Vector3.new(0, 0.288, 0) },
					LeftHip = { rot = Vector3.new(34.02, 0, -1.75), pos = Vector3.new(0, 0.136, 0) },
				},
			},
			{
				time = 3.4,
				pose = {
					Root = {
						rot = Vector3.new(-11.48, 7.26, 0),
						pos = Vector3.new(0.011, -0.321, 0.222),
					},
					Neck = { rot = Vector3.new(-11.86, -1.17, 3.76) },
					RightShoulder = { rot = Vector3.new(9.72, 0, -7.66) },
					LeftShoulder = { rot = Vector3.new(0.45, 0, 10.83) },
					RightHip = { rot = Vector3.new(-5.26, 0, 9.08), pos = Vector3.new(0, 0.294, 0) },
					LeftHip = { rot = Vector3.new(33.93, 0, -2.09), pos = Vector3.new(0, 0.151, 0) },
				},
			},
			{
				time = 3.45,
				pose = {
					Root = {
						rot = Vector3.new(-11.82, 6.44, 0),
						pos = Vector3.new(0.007, -0.325, 0.214),
					},
					Neck = { rot = Vector3.new(-15.66, -0.58, 4.03) },
					RightShoulder = { rot = Vector3.new(8.51, 0, -8.54) },
					LeftShoulder = { rot = Vector3.new(0.37, 0, 11.3) },
					RightHip = { rot = Vector3.new(-4.72, 0, 9.29), pos = Vector3.new(0, 0.299, 0) },
					LeftHip = { rot = Vector3.new(33.81, 0, -2.41), pos = Vector3.new(0, 0.165, 0) },
				},
			},
			{
				time = 3.5,
				pose = {
					Root = {
						rot = Vector3.new(-12.13, 5.69, 0),
						pos = Vector3.new(0.003, -0.328, 0.206),
					},
					Neck = { rot = Vector3.new(-19, -0.02, 4.12) },
					RightShoulder = { rot = Vector3.new(7.4, 0, -9.34) },
					LeftShoulder = { rot = Vector3.new(0.24, 0, 11.56) },
					RightHip = { rot = Vector3.new(-4.22, 0, 9.47), pos = Vector3.new(0, 0.302, 0) },
					LeftHip = { rot = Vector3.new(33.69, 0, -2.71), pos = Vector3.new(0, 0.177, 0) },
				},
			},
			{
				time = 3.55,
				pose = {
					Root = { rot = Vector3.new(-12.44, 5, 0), pos = Vector3.new(0, -0.331, 0.2) },
					Neck = { rot = Vector3.new(-21.71, 0.52, 4) },
					RightShoulder = { rot = Vector3.new(6.34, 0, -10.06) },
					LeftShoulder = { rot = Vector3.new(0, 0, 11.62) },
					RightHip = { rot = Vector3.new(-3.73, 0, 9.63), pos = Vector3.new(0, 0.305, 0) },
					LeftHip = { rot = Vector3.new(33.62, 0, -2.98), pos = Vector3.new(0, 0.186, 0) },
				},
			},
			{
				time = 3.6,
				pose = {
					Root = {
						rot = Vector3.new(-12.69, 4.48, 0),
						pos = Vector3.new(-0.002, -0.332, 0.196),
					},
					Neck = { rot = Vector3.new(-23.66, 0.96, 3.24) },
					RightShoulder = { rot = Vector3.new(5.74, 0, -10.52) },
					LeftShoulder = { rot = Vector3.new(-0.24, 0, 11.65) },
					RightHip = { rot = Vector3.new(-3.31, 0, 9.73), pos = Vector3.new(0, 0.306, 0) },
					LeftHip = { rot = Vector3.new(33.62, 0, -3.2), pos = Vector3.new(0, 0.192, 0) },
				},
			},
			{
				time = 3.65,
				pose = {
					Root = {
						rot = Vector3.new(-12.84, 4.17, 0),
						pos = Vector3.new(-0.003, -0.332, 0.195),
					},
					Neck = { rot = Vector3.new(-24.93, 1.29, 1.72) },
					RightShoulder = { rot = Vector3.new(5.81, 0, -10.65) },
					LeftShoulder = { rot = Vector3.new(-0.35, 0, 11.66) },
					RightHip = { rot = Vector3.new(-3.01, 0, 9.78), pos = Vector3.new(0, 0.306, 0) },
					LeftHip = { rot = Vector3.new(33.67, 0, -3.34), pos = Vector3.new(0, 0.195, 0) },
				},
			},
			{
				time = 3.7,
				pose = {
					Root = {
						rot = Vector3.new(-12.91, 4.01, 0),
						pos = Vector3.new(-0.002, -0.331, 0.196),
					},
					Neck = { rot = Vector3.new(-25.63, 1.57, -0.18) },
					RightShoulder = { rot = Vector3.new(6.31, 0, -10.56) },
					LeftShoulder = { rot = Vector3.new(-0.39, 0, 11.65) },
					RightHip = { rot = Vector3.new(-2.82, 0, 9.79), pos = Vector3.new(0, 0.306, 0) },
					LeftHip = { rot = Vector3.new(33.74, 0, -3.43), pos = Vector3.new(0, 0.194, 0) },
				},
			},
			{
				time = 3.75,
				pose = {
					Root = {
						rot = Vector3.new(-12.92, 3.97, 0),
						pos = Vector3.new(-0.001, -0.329, 0.197),
					},
					Neck = { rot = Vector3.new(-25.92, 1.79, -2.03) },
					RightShoulder = { rot = Vector3.new(6.98, 0, -10.36) },
					LeftShoulder = { rot = Vector3.new(-0.37, 0, 11.64) },
					RightHip = { rot = Vector3.new(-2.72, 0, 9.77), pos = Vector3.new(0, 0.305, 0) },
					LeftHip = { rot = Vector3.new(33.82, 0, -3.47), pos = Vector3.new(0, 0.192, 0) },
				},
			},
			{
				time = 3.8,
				pose = {
					Root = {
						rot = Vector3.new(-12.9, 3.98, 0),
						pos = Vector3.new(0, -0.328, 0.199),
					},
					Neck = { rot = Vector3.new(-25.98, 1.93, -3.44) },
					RightShoulder = { rot = Vector3.new(7.56, 0, -10.17) },
					LeftShoulder = { rot = Vector3.new(-0.34, 0, 11.62) },
					RightHip = { rot = Vector3.new(-2.7, 0, 9.74), pos = Vector3.new(0, 0.303, 0) },
					LeftHip = { rot = Vector3.new(33.86, 0, -3.49), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 3.85,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-12.86, 4, 0), pos = Vector3.new(0, -0.327, 0.2) },
					Neck = { rot = Vector3.new(-25.98, 1.99, -4) },
					RightShoulder = { rot = Vector3.new(7.82, 0, -10.08) },
					LeftShoulder = { rot = Vector3.new(-0.32, 0, 11.62) },
					RightHip = { rot = Vector3.new(-2.73, 0, 9.73), pos = Vector3.new(0, 0.302, 0) },
					LeftHip = { rot = Vector3.new(33.84, 0, -3.49), pos = Vector3.new(0, 0.188, 0) },
				},
			},
			{
				time = 3.9,
				pose = {
					Root = {
						rot = Vector3.new(-12.62, 3.83, 0),
						pos = Vector3.new(0, -0.32, 0.198),
					},
					Neck = { rot = Vector3.new(-25.13, 2.09, -3.89) },
					RightShoulder = { rot = Vector3.new(13.54, 0, -7.47) },
					LeftShoulder = { rot = Vector3.new(5.7, 0, 7.62) },
					RightHip = { rot = Vector3.new(-3, 0, 9.72), pos = Vector3.new(0, 0.295, 0) },
					LeftHip = { rot = Vector3.new(33.39, 0, -3.61), pos = Vector3.new(0, 0.186, 0) },
				},
			},
			{
				time = 3.95,
				pose = {
					Root = {
						rot = Vector3.new(-12.04, 3.36, 0),
						pos = Vector3.new(0, -0.304, 0.192),
					},
					Neck = { rot = Vector3.new(-22.74, 2.31, -3.59) },
					RightShoulder = { rot = Vector3.new(26.35, 0, -3.39) },
					LeftShoulder = { rot = Vector3.new(19.54, 0, 0.04) },
					RightHip = { rot = Vector3.new(-3.64, 0, 9.69), pos = Vector3.new(0, 0.277, 0) },
					LeftHip = { rot = Vector3.new(32.26, 0, -3.91), pos = Vector3.new(0, 0.182, 0) },
				},
			},
			{
				time = 4,
				pose = {
					Root = {
						rot = Vector3.new(-11.23, 2.64, 0),
						pos = Vector3.new(0, -0.281, 0.183),
					},
					Neck = { rot = Vector3.new(-19.05, 2.55, -3.14) },
					RightShoulder = { rot = Vector3.new(38.93, 0, -3.18) },
					LeftShoulder = { rot = Vector3.new(33.43, 0, -1.9) },
					RightHip = { rot = Vector3.new(-4.57, 0, 9.68), pos = Vector3.new(0, 0.252, 0) },
					LeftHip = { rot = Vector3.new(30.6, 0, -4.35), pos = Vector3.new(0, 0.176, 0) },
				},
			},
			{
				time = 4.05,
				pose = {
					Root = {
						rot = Vector3.new(-10.25, 1.72, 0),
						pos = Vector3.new(0, -0.252, 0.171),
					},
					Neck = { rot = Vector3.new(-14.46, 2.79, -2.6) },
					RightShoulder = { rot = Vector3.new(49.45, 0, -10.16) },
					LeftShoulder = { rot = Vector3.new(45.19, 0, 6.89) },
					RightHip = { rot = Vector3.new(-5.7, 0, 9.7), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(28.59, 0, -4.85), pos = Vector3.new(0, 0.167, 0) },
				},
			},
			{
				time = 4.1,
				pose = {
					Root = { rot = Vector3.new(-9.2, 0.65, 0), pos = Vector3.new(0, -0.22, 0.158) },
					Neck = { rot = Vector3.new(-9.37, 3.05, -2) },
					RightShoulder = { rot = Vector3.new(60.12, 0, -21.1) },
					LeftShoulder = { rot = Vector3.new(57.03, 0, 21.73) },
					RightHip = { rot = Vector3.new(-6.93, 0, 9.79), pos = Vector3.new(0, 0.186, 0) },
					LeftHip = { rot = Vector3.new(26.36, 0, -5.38), pos = Vector3.new(0, 0.155, 0) },
				},
			},
			{
				time = 4.15,
				pose = {
					Root = {
						rot = Vector3.new(-8.16, -0.5, 0),
						pos = Vector3.new(0, -0.186, 0.144),
					},
					Neck = { rot = Vector3.new(-4.2, 3.34, -1.39) },
					RightShoulder = { rot = Vector3.new(70.37, 0, -29.55) },
					LeftShoulder = { rot = Vector3.new(68.21, 0, 32.64) },
					RightHip = { rot = Vector3.new(-8.17, 0, 9.94), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(24.08, 0, -5.87), pos = Vector3.new(0, 0.141, 0) },
				},
			},
			{
				time = 4.2,
				pose = {
					Root = {
						rot = Vector3.new(-7.22, -1.7, 0),
						pos = Vector3.new(0, -0.154, 0.129),
					},
					Neck = { rot = Vector3.new(0.66, 3.66, -0.83) },
					RightShoulder = { rot = Vector3.new(82.14, 0, -33.52) },
					LeftShoulder = { rot = Vector3.new(81.16, 0, 36.67) },
					RightHip = { rot = Vector3.new(-8.21, 0, 8.55), pos = Vector3.new(0, 0.201, 0) },
					LeftHip = { rot = Vector3.new(21.91, 0, -6.31), pos = Vector3.new(0, 0.126, 0) },
				},
			},
			{
				time = 4.25,
				pose = {
					Root = {
						rot = Vector3.new(-6.46, -2.88, 0),
						pos = Vector3.new(0, -0.124, 0.114),
					},
					Neck = { rot = Vector3.new(4.78, 4.04, -0.35) },
					RightShoulder = { rot = Vector3.new(94.98, 0, -35.23) },
					LeftShoulder = { rot = Vector3.new(95.49, 0, 37.34) },
					RightHip = { rot = Vector3.new(-6.37, 0, 5.16), pos = Vector3.new(0, 0.244, 0) },
					LeftHip = { rot = Vector3.new(20, 0, -6.68), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 4.3,
				pose = {
					Root = { rot = Vector3.new(-5.98, -4, 0), pos = Vector3.new(0, -0.1, 0.1) },
					Neck = { rot = Vector3.new(7.77, 4.46, 0) },
					RightShoulder = { rot = Vector3.new(103.47, 0, -35.72) },
					LeftShoulder = { rot = Vector3.new(105.04, 0, 36.92) },
					RightHip = { rot = Vector3.new(-3.98, 0, 1.62), pos = Vector3.new(0, 0.183, 0) },
					LeftHip = { rot = Vector3.new(15.65, 0, -5.87), pos = Vector3.new(0, 0.173, 0) },
				},
			},
			{
				time = 4.35,
				pose = {
					Root = {
						rot = Vector3.new(-5.91, -5.33, 0),
						pos = Vector3.new(0, -0.077, 0.083),
					},
					Neck = { rot = Vector3.new(9.27, 5.29, 0.19) },
					RightShoulder = { rot = Vector3.new(107.06, 0, -36.08) },
					LeftShoulder = { rot = Vector3.new(109.2, 0, 36.98) },
					RightHip = { rot = Vector3.new(-2.63, 0, 0), pos = Vector3.new(0, 0.089, 0) },
					LeftHip = { rot = Vector3.new(8.78, 0, -3.59), pos = Vector3.new(0, 0.211, 0) },
				},
			},
			{
				time = 4.4,
				pose = {
					Root = {
						rot = Vector3.new(-6.23, -7.02, 0),
						pos = Vector3.new(0, -0.055, 0.062),
					},
					Neck = { rot = Vector3.new(9.46, 6.58, 0.24) },
					RightShoulder = { rot = Vector3.new(109.26, 0, -36.29) },
					LeftShoulder = { rot = Vector3.new(111.94, 0, 36.98) },
					RightHip = { rot = Vector3.new(-2.28, 0, 0.07), pos = Vector3.new(0, 0.065, 0) },
					LeftHip = { rot = Vector3.new(2.61, 0, -1.07), pos = Vector3.new(0, 0.133, 0) },
				},
			},
			{
				time = 4.45,
				pose = {
					Root = { rot = Vector3.new(-6.75, -8.8, 0), pos = Vector3.new(0, -0.034, 0.04) },
					Neck = { rot = Vector3.new(8.74, 7.92, 0.2) },
					RightShoulder = { rot = Vector3.new(110.45, 0, -36.41) },
					LeftShoulder = { rot = Vector3.new(113.63, 0, 36.98) },
					RightHip = { rot = Vector3.new(-1.62, 0, 0.1), pos = Vector3.new(0, 0.042, 0) },
					LeftHip = { rot = Vector3.new(-0.04, 0, 0.15), pos = Vector3.new(0, 0.035, 0) },
				},
			},
			{
				time = 4.5,
				pose = {
					Root = {
						rot = Vector3.new(-7.34, -10.4, 0),
						pos = Vector3.new(0, -0.016, 0.02),
					},
					Neck = { rot = Vector3.new(7.6, 9.07, 0.12) },
					RightShoulder = { rot = Vector3.new(110.95, 0, -36.47) },
					LeftShoulder = { rot = Vector3.new(114.55, 0, 36.98) },
					RightHip = { rot = Vector3.new(-0.87, 0, 0.08), pos = Vector3.new(0, 0.021, 0) },
					LeftHip = { rot = Vector3.new(-0.09, 0, 0.1), pos = Vector3.new(0, 0.017, 0) },
				},
			},
			{
				time = 4.55,
				pose = {
					Root = {
						rot = Vector3.new(-7.81, -11.56, 0),
						pos = Vector3.new(0, -0.004, 0.006),
					},
					Neck = { rot = Vector3.new(6.53, 9.84, 0.04) },
					RightShoulder = { rot = Vector3.new(111.04, 0, -36.49) },
					LeftShoulder = { rot = Vector3.new(114.93, 0, 36.99) },
					RightHip = { rot = Vector3.new(-0.25, 0, 0.03), pos = Vector3.new(0, 0.006, 0) },
					LeftHip = { rot = Vector3.new(-0.05, 0, 0.04), pos = Vector3.new(0, 0.005, 0) },
				},
			},
			{
				time = 4.6,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
		},
	},
	Rift_FinisherPortalCutVictim = {
		length = 4.6,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-55, 0, -8), pos = Vector3.new(0, -1.6, 0.4) },
					Neck = { rot = Vector3.new(30, 0, 10) },
					RightShoulder = { rot = Vector3.new(-30, 0, 30) },
					LeftShoulder = { rot = Vector3.new(-25, 0, -25) },
					RightHip = { rot = Vector3.new(118.9, 0, 2.1) },
					LeftHip = { rot = Vector3.new(57.1, 0, 4.2), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-51.69, -0.04, -7.68),
						pos = Vector3.new(0, -1.571, 0.397),
					},
					Neck = { rot = Vector3.new(30.358, 0, 10.282) },
					RightShoulder = { rot = Vector3.new(-29.135, 0, 29.336) },
					LeftShoulder = { rot = Vector3.new(-24.235, 0, -24.447) },
					RightHip = { rot = Vector3.new(116.7, 0, 1.8) },
					LeftHip = { rot = Vector3.new(54, 0, 4.1), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-48.4, 0, -7.46), pos = Vector3.new(0, -1.49, 0.39) },
					Neck = { rot = Vector3.new(31.299, 0, 10.977) },
					RightShoulder = { rot = Vector3.new(-26.841, 0, 27.631) },
					LeftShoulder = { rot = Vector3.new(-22.113, 0, -22.986) },
					RightHip = { rot = Vector3.new(112.1, 0, 1.7) },
					LeftHip = { rot = Vector3.new(50.6, 0, 3.9), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-45.13, 0.06, -7.28),
						pos = Vector3.new(0, -1.372, 0.379),
					},
					Neck = { rot = Vector3.new(32.624, 0, 11.856) },
					RightShoulder = { rot = Vector3.new(-23.446, 0, 25.255) },
					LeftShoulder = { rot = Vector3.new(-19.009, 0, -20.984) },
					RightHip = { rot = Vector3.new(65, 0, 2.5), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(47.2, 0, 3.5), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-41.85, 0.12, -7.07),
						pos = Vector3.new(0, -1.228, 0.365),
					},
					Neck = { rot = Vector3.new(34.134, 0, 12.693) },
					RightShoulder = { rot = Vector3.new(-19.321, 0, 22.461) },
					LeftShoulder = { rot = Vector3.new(-15.491, 0, -18.764) },
					RightHip = { rot = Vector3.new(57.9, 0, 3.8), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(43.6, 0, 3.1), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-38.54, 0.15, -6.75),
						pos = Vector3.new(0, -1.07, 0.348),
					},
					Neck = { rot = Vector3.new(35.63, 0, 13.259) },
					RightShoulder = { rot = Vector3.new(-15.058, 0, 19.482) },
					LeftShoulder = { rot = Vector3.new(-12.124, 0, -16.517) },
					RightHip = { rot = Vector3.new(51, 0, 5.1), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(42.1, 0, 3.2), pos = Vector3.new(0, 0.988, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-35.18, 0.13, -6.25),
						pos = Vector3.new(0, -0.912, 0.33),
					},
					Neck = { rot = Vector3.new(36.912, 0, 13.328) },
					RightShoulder = { rot = Vector3.new(-11.376, 0, 16.691) },
					LeftShoulder = { rot = Vector3.new(-9.229, 0, -14.375) },
					RightHip = { rot = Vector3.new(45.7, 0, 6), pos = Vector3.new(0, 1.048, 0) },
					LeftHip = { rot = Vector3.new(41.9, 0, 3.7), pos = Vector3.new(0, 0.78, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-31.75, 0.06, -5.5),
						pos = Vector3.new(0, -0.765, 0.31),
					},
					Neck = { rot = Vector3.new(37.782, 0, 12.671) },
					RightShoulder = { rot = Vector3.new(-8.808, 0, 14.612) },
					LeftShoulder = { rot = Vector3.new(-6.901, 0, -12.602) },
					RightHip = { rot = Vector3.new(44.5, 0, 6.1), pos = Vector3.new(0, 0.801, 0) },
					LeftHip = { rot = Vector3.new(40.3, 0, 3.8), pos = Vector3.new(0, 0.61, 0) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = { rot = Vector3.new(-30, 0, -5), pos = Vector3.new(0, -0.7, 0.3) },
					Neck = { rot = Vector3.new(38, 0, 12) },
					RightShoulder = { rot = Vector3.new(-8, 0, 14) },
					LeftShoulder = { rot = Vector3.new(-6, 0, -12) },
					RightHip = { rot = Vector3.new(43.7, 0, 5.9), pos = Vector3.new(0, 0.689, 0) },
					LeftHip = { rot = Vector3.new(39, 0, 3.5), pos = Vector3.new(0, 0.546, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-28.23, -0.07, -4.41),
						pos = Vector3.new(0, -0.634, 0.289),
					},
					Neck = { rot = Vector3.new(38.065, 0, 10.972) },
					RightShoulder = { rot = Vector3.new(-7.393, 0, 13.659) },
					LeftShoulder = { rot = Vector3.new(-5.239, 0, -11.62) },
					RightHip = { rot = Vector3.new(42.3, 0, 5.5), pos = Vector3.new(0, 0.611, 0) },
					LeftHip = { rot = Vector3.new(37.5, 0, 3.1), pos = Vector3.new(0, 0.488, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-24.66, -0.21, -3.02),
						pos = Vector3.new(0, -0.483, 0.26),
					},
					Neck = { rot = Vector3.new(37.84, 0, 7.76) },
					RightShoulder = { rot = Vector3.new(-6.143, 0, 13.402) },
					LeftShoulder = { rot = Vector3.new(-4.138, 0, -11.49) },
					RightHip = { rot = Vector3.new(38.4, 0, 4.4), pos = Vector3.new(0, 0.461, 0) },
					LeftHip = { rot = Vector3.new(34.3, 0, 2), pos = Vector3.new(0, 0.378, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-21.15, -0.31, -1.46),
						pos = Vector3.new(0, -0.317, 0.226),
					},
					Neck = { rot = Vector3.new(37.259, 0, 3.481) },
					RightShoulder = { rot = Vector3.new(-4.774, 0, 13.102) },
					LeftShoulder = { rot = Vector3.new(-4.324, 0, -12.024) },
					RightHip = { rot = Vector3.new(33.7, 0, 2.6), pos = Vector3.new(0, 0.32, 0) },
					LeftHip = { rot = Vector3.new(31.1, 0, 0.6), pos = Vector3.new(0, 0.274, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-17.79, -0.34, 0.13),
						pos = Vector3.new(0, -0.15, 0.19),
					},
					Neck = { rot = Vector3.new(36.465, 0, -1.295) },
					RightShoulder = { rot = Vector3.new(-4.187, 0, 12.299) },
					LeftShoulder = { rot = Vector3.new(-6.098, 0, -12.455) },
					RightHip = { rot = Vector3.new(28.5, 0, 0.5), pos = Vector3.new(0, 0.191, 0) },
					LeftHip = { rot = Vector3.new(27.8, 0, -1.1), pos = Vector3.new(0, 0.182, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-14.68, -0.31, 1.61),
						pos = Vector3.new(0, 0.004, 0.156),
					},
					Neck = { rot = Vector3.new(35.6, 0, -6) },
					RightShoulder = { rot = Vector3.new(-5.495, 0, 11.334) },
					LeftShoulder = { rot = Vector3.new(-8.412, 0, -11.993) },
					RightHip = { rot = Vector3.new(23.2, 0, -1.8), pos = Vector3.new(0, 0.076, 0) },
					LeftHip = { rot = Vector3.new(24.5, 0, -2.8), pos = Vector3.new(0, 0.105, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(-11.95, -0.22, 2.85),
						pos = Vector3.new(0, 0.132, 0.127),
					},
					Neck = { rot = Vector3.new(34.806, 0, -10.065) },
					RightShoulder = { rot = Vector3.new(-8.63, 0, 11.135) },
					LeftShoulder = { rot = Vector3.new(-9.395, 0, -10.63) },
					RightHip = { rot = Vector3.new(18, 0, -3.8) },
					LeftHip = { rot = Vector3.new(21.4, 0, -4.4), pos = Vector3.new(0, 0.046, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(-9.69, -0.11, 3.69),
						pos = Vector3.new(0, 0.218, 0.107),
					},
					Neck = { rot = Vector3.new(34.225, 0, -12.921) },
					RightShoulder = { rot = Vector3.new(-11.874, 0, 12.33) },
					LeftShoulder = { rot = Vector3.new(-7.889, 0, -9.295) },
					RightHip = { rot = Vector3.new(13.3, 0, -4.8) },
					LeftHip = { rot = Vector3.new(18.7, 0, -5.4) },
				},
			},
			{
				time = 0.9,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-8, 0, 4), pos = Vector3.new(0, 0.25, 0.1) },
					Neck = { rot = Vector3.new(34, 0, -14) },
					RightShoulder = { rot = Vector3.new(-12.945, 0, 14.444) },
					LeftShoulder = { rot = Vector3.new(-4.628, 0, -9.115) },
					RightHip = { rot = Vector3.new(10.4, 0, -5.1) },
					LeftHip = { rot = Vector3.new(16.3, 0, -5.9) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = { rot = Vector3.new(-6.95, 0.07, 3.7), pos = Vector3.new(0, 0.252, 0.1) },
					Neck = { rot = Vector3.new(34.203, -0.054, -13.173) },
					RightShoulder = { rot = Vector3.new(-11.43, 0, 16.182) },
					LeftShoulder = { rot = Vector3.new(-2.176, 0, -10.326) },
					RightHip = { rot = Vector3.new(8.8, 0, -4.8) },
					LeftHip = { rot = Vector3.new(14.7, 0, -5.5) },
				},
			},
			{
				time = 1.02,
				pose = {
					Root = {
						rot = Vector3.new(-6.43, 0.11, 2.91),
						pos = Vector3.new(0, 0.256, 0.102),
					},
					Neck = { rot = Vector3.new(34.67, -0.188, -10.954) },
					RightShoulder = { rot = Vector3.new(-8.827, 0, 16.594) },
					LeftShoulder = { rot = Vector3.new(-2.378, 0, -12.137) },
					RightHip = { rot = Vector3.new(8.1, 0, -3.7) },
					LeftHip = { rot = Vector3.new(13.9, 0, -4.4) },
				},
			},
			{
				time = 1.08,
				pose = {
					Root = {
						rot = Vector3.new(-6.29, 0.11, 1.78),
						pos = Vector3.new(0, 0.262, 0.103),
					},
					Neck = { rot = Vector3.new(35.188, -0.355, -7.738) },
					RightShoulder = { rot = Vector3.new(-6.809, 0, 15.568) },
					LeftShoulder = { rot = Vector3.new(-5.025, 0, -13.47) },
					RightHip = { rot = Vector3.new(8, 0, -2.2) },
					LeftHip = { rot = Vector3.new(13.7, 0, -2.9) },
				},
			},
			{
				time = 1.14,
				pose = {
					Root = {
						rot = Vector3.new(-6.39, 0.09, 0.49),
						pos = Vector3.new(0, 0.269, 0.104),
					},
					Neck = { rot = Vector3.new(35.543, -0.513, -3.918) },
					RightShoulder = { rot = Vector3.new(-6.497, 0, 13.787) },
					LeftShoulder = { rot = Vector3.new(-8.658, 0, -13.674) },
					RightHip = { rot = Vector3.new(8.2, 0, -0.5) },
					LeftHip = { rot = Vector3.new(13.7, 0, -1.2) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-6.59, 0.08, -0.8),
						pos = Vector3.new(0, 0.277, 0.105),
					},
					Neck = { rot = Vector3.new(35.522, -0.617, 0.112) },
					RightShoulder = { rot = Vector3.new(-7.859, 0, 12.173) },
					LeftShoulder = { rot = Vector3.new(-11.577, 0, -12.819) },
					RightHip = { rot = Vector3.new(8.6, 0, 1.3) },
					LeftHip = { rot = Vector3.new(13.9, 0, 0.4) },
				},
			},
			{
				time = 1.26,
				pose = {
					Root = {
						rot = Vector3.new(-6.72, 0.06, -1.93),
						pos = Vector3.new(0, 0.285, 0.105),
					},
					Neck = { rot = Vector3.new(34.912, -0.622, 3.957) },
					RightShoulder = { rot = Vector3.new(-9.992, 0, 11.372) },
					LeftShoulder = { rot = Vector3.new(-12.647, 0, -11.454) },
					RightHip = { rot = Vector3.new(8.8, 0, 2.9) },
					LeftHip = { rot = Vector3.new(14, 0, 1.8) },
				},
			},
			{
				time = 1.32,
				pose = {
					Root = {
						rot = Vector3.new(-6.66, 0.04, -2.73),
						pos = Vector3.new(0, 0.293, 0.104),
					},
					Neck = { rot = Vector3.new(33.5, -0.484, 7.224) },
					RightShoulder = { rot = Vector3.new(-11.783, 0, 11.623) },
					LeftShoulder = { rot = Vector3.new(-11.432, 0, -10.204) },
					RightHip = { rot = Vector3.new(8.7, 0, 4.1) },
					LeftHip = { rot = Vector3.new(13.9, 0, 2.8) },
				},
			},
			{
				time = 1.38,
				pose = {
					Root = {
						rot = Vector3.new(-6.24, 0.01, -3.04),
						pos = Vector3.new(0, 0.298, 0.101),
					},
					Neck = { rot = Vector3.new(31.072, -0.158, 9.519) },
					RightShoulder = { rot = Vector3.new(-12.25, 0, 12.94) },
					LeftShoulder = { rot = Vector3.new(-7.854, 0, -9.583) },
					RightHip = { rot = Vector3.new(8, 0, 4.5) },
					LeftHip = { rot = Vector3.new(13.1, 0, 3.2) },
				},
			},
			{
				time = 1.4,
				pose = {
					Root = { rot = Vector3.new(-6, 0, -3), pos = Vector3.new(0, 0.3, 0.1) },
					Neck = { rot = Vector3.new(30, 0, 10) },
					RightShoulder = { rot = Vector3.new(-11.945, 0, 13.605) },
					LeftShoulder = { rot = Vector3.new(-6.145, 0, -9.602) },
					RightHip = { rot = Vector3.new(7.6, 0, 4.5) },
					LeftHip = { rot = Vector3.new(12.8, 0, 3.1) },
				},
			},
			{
				time = 1.44,
				pose = {
					Root = {
						rot = Vector3.new(-5.35, -0.02, -2.71),
						pos = Vector3.new(0, 0.302, 0.093),
					},
					Neck = { rot = Vector3.new(25.187, 0.922, 9.57) },
					RightShoulder = { rot = Vector3.new(-9.217, 0, 15.651) },
					LeftShoulder = { rot = Vector3.new(0.126, 0, -10.33) },
					RightHip = { rot = Vector3.new(6.4, 0, 4.1) },
					LeftHip = { rot = Vector3.new(11.6, 0, 2.8) },
				},
			},
			{
				time = 1.5,
				pose = {
					Root = {
						rot = Vector3.new(-4.11, -0.03, -1.85),
						pos = Vector3.new(0, 0.302, 0.075),
					},
					Neck = { rot = Vector3.new(12.11, 3.522, 5.885) },
					RightShoulder = { rot = Vector3.new(1.325, 0, 20.793) },
					LeftShoulder = { rot = Vector3.new(16.355, 0, -14.024) },
					RightHip = { rot = Vector3.new(4.1, 0, 2.9) },
					LeftHip = { rot = Vector3.new(9.4, 0, 1.7) },
				},
			},
			{
				time = 1.56,
				pose = {
					Root = {
						rot = Vector3.new(-2.78, -0.02, -0.74),
						pos = Vector3.new(0, 0.3, 0.057),
					},
					Neck = { rot = Vector3.new(-1.046, 5.746, 1.562) },
					RightShoulder = { rot = Vector3.new(17.511, 0, 25.356) },
					LeftShoulder = { rot = Vector3.new(30.911, 0, -20.774) },
					RightHip = { rot = Vector3.new(1.5, 0, 1.3) },
					LeftHip = { rot = Vector3.new(7, 0, 0.3) },
				},
			},
			{
				time = 1.6,
				pose = {
					Root = { rot = Vector3.new(-2, 0, 0), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-6, 6, 0) },
					RightShoulder = { rot = Vector3.new(27.275, 0, 25.726) },
					LeftShoulder = { rot = Vector3.new(33.526, 0, -25.066) },
					RightHip = { rot = Vector3.new(0.2, 0, 0.3) },
					LeftHip = { rot = Vector3.new(5.7, 0, -0.7) },
				},
			},
			{
				time = 1.62,
				pose = {
					Root = {
						rot = Vector3.new(-1.67, 0.01, 0.34),
						pos = Vector3.new(0, 0.3, 0.049),
					},
					Neck = { rot = Vector3.new(-7.138, 5.7, -0.281) },
					RightShoulder = { rot = Vector3.new(30.881, 0, 24.991) },
					LeftShoulder = { rot = Vector3.new(32.5, 0, -26.597) },
					RightHip = { rot = Vector3.new(-0.3, 0, -0.1) },
					LeftHip = { rot = Vector3.new(5.2, 0, -1.1) },
				},
			},
			{
				time = 1.68,
				pose = {
					Root = { rot = Vector3.new(-0.9, 0.04, 1.23), pos = Vector3.new(0, 0.3, 0.046) },
					Neck = { rot = Vector3.new(-9.539, 4.238, -0.832) },
					RightShoulder = { rot = Vector3.new(37.934, 0, 20.799) },
					LeftShoulder = { rot = Vector3.new(25.894, 0, -28.732) },
					RightHip = { rot = Vector3.new(-1.6, 0, -1.3) },
					LeftHip = { rot = Vector3.new(4, 0, -2.3) },
				},
			},
			{
				time = 1.74,
				pose = {
					Root = {
						rot = Vector3.new(-0.44, 0.06, 1.93),
						pos = Vector3.new(0, 0.3, 0.045),
					},
					Neck = { rot = Vector3.new(-10.693, 2.15, -1.022) },
					RightShoulder = { rot = Vector3.new(37.51, 0, 15.691) },
					LeftShoulder = { rot = Vector3.new(17.835, 0, -26.397) },
					RightHip = { rot = Vector3.new(-2.3, 0, -2.2) },
					LeftHip = { rot = Vector3.new(3.3, 0, -3.3) },
				},
			},
			{
				time = 1.8,
				pose = {
					Root = {
						rot = Vector3.new(-0.19, 0.06, 2.45),
						pos = Vector3.new(0, 0.3, 0.045),
					},
					Neck = { rot = Vector3.new(-10.947, -0.286, -0.95) },
					RightShoulder = { rot = Vector3.new(30.361, 0, 12.88) },
					LeftShoulder = { rot = Vector3.new(13.778, 0, -20.498) },
					RightHip = { rot = Vector3.new(-2.6, 0, -2.9) },
					LeftHip = { rot = Vector3.new(2.9, 0, -4) },
				},
			},
			{
				time = 1.86,
				pose = {
					Root = { rot = Vector3.new(-0.1, 0.05, 2.8), pos = Vector3.new(0, 0.3, 0.046) },
					Neck = { rot = Vector3.new(-10.648, -2.79, -0.713) },
					RightShoulder = { rot = Vector3.new(21.017, 0, 14.62) },
					LeftShoulder = { rot = Vector3.new(17.103, 0, -14.067) },
					RightHip = { rot = Vector3.new(-2.7, 0, -3.4) },
					LeftHip = { rot = Vector3.new(2.8, 0, -4.5) },
				},
			},
			{
				time = 1.92,
				pose = {
					Root = {
						rot = Vector3.new(-0.09, 0.04, 3.01),
						pos = Vector3.new(0, 0.3, 0.048),
					},
					Neck = { rot = Vector3.new(-10.143, -5.083, -0.411) },
					RightShoulder = { rot = Vector3.new(15.621, 0, 20.693) },
					LeftShoulder = { rot = Vector3.new(26.898, 0, -10.775) },
					RightHip = { rot = Vector3.new(-2.7, 0, -3.6) },
					LeftHip = { rot = Vector3.new(2.9, 0, -4.8) },
				},
			},
			{
				time = 1.98,
				pose = {
					Root = {
						rot = Vector3.new(-0.09, 0.02, 3.07),
						pos = Vector3.new(0, 0.3, 0.049),
					},
					Neck = { rot = Vector3.new(-9.78, -6.887, -0.141) },
					RightShoulder = { rot = Vector3.new(18.35, 0, 28.322) },
					LeftShoulder = { rot = Vector3.new(38.272, 0, -12.796) },
					RightHip = { rot = Vector3.new(-2.7, 0, -3.7) },
					LeftHip = { rot = Vector3.new(2.9, 0, -4.9) },
				},
			},
			{
				time = 2.04,
				pose = {
					Root = { rot = Vector3.new(-0.02, 0, 3.02), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-9.907, -7.922, -0.003) },
					RightShoulder = { rot = Vector3.new(28.725, 0, 33.78) },
					LeftShoulder = { rot = Vector3.new(45.371, 0, -19.407) },
					RightHip = { rot = Vector3.new(-2.7, 0, -3.6) },
					LeftHip = { rot = Vector3.new(2.8, 0, -4.8) },
				},
			},
			{
				time = 2.05,
				pose = {
					Root = { rot = Vector3.new(0, 0, 3), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-10, -8, 0) },
					RightShoulder = { rot = Vector3.new(30.891, 0, 34.278) },
					LeftShoulder = { rot = Vector3.new(45.864, 0, -20.75) },
					RightHip = { rot = Vector3.new(-2.8, 0, -3.6) },
					LeftHip = { rot = Vector3.new(2.8, 0, -4.8) },
				},
			},
			{
				time = 2.1,
				pose = {
					Root = { rot = Vector3.new(0.17, -0.01, 2.86), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-10.594, -8.032, 0) },
					RightShoulder = { rot = Vector3.new(41.675, 0, 34.789) },
					LeftShoulder = { rot = Vector3.new(45.06, 0, -27.414) },
					RightHip = { rot = Vector3.new(-3, 0, -3.4) },
					LeftHip = { rot = Vector3.new(2.5, 0, -4.6) },
				},
			},
			{
				time = 2.16,
				pose = {
					Root = { rot = Vector3.new(0.5, -0.01, 2.61), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-11.448, -7.431, 0) },
					RightShoulder = { rot = Vector3.new(50.42, 0, 32.176) },
					LeftShoulder = { rot = Vector3.new(39.224, 0, -32.955) },
					RightHip = { rot = Vector3.new(-3.5, 0, -3.1) },
					LeftHip = { rot = Vector3.new(2, 0, -4.2) },
				},
			},
			{
				time = 2.22,
				pose = {
					Root = { rot = Vector3.new(0.93, 0, 2.28), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-12.389, -6.322, 0) },
					RightShoulder = { rot = Vector3.new(51.922, 0, 29.304) },
					LeftShoulder = { rot = Vector3.new(33.84, 0, -34.506) },
					RightHip = { rot = Vector3.new(-4.1, 0, -2.7) },
					LeftHip = { rot = Vector3.new(1.4, 0, -3.8) },
				},
			},
			{
				time = 2.28,
				pose = {
					Root = { rot = Vector3.new(1.43, 0, 1.9), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-13.347, -4.903, 0) },
					RightShoulder = { rot = Vector3.new(48.664, 0, 29.156) },
					LeftShoulder = { rot = Vector3.new(33.555, 0, -33.779) },
					RightHip = { rot = Vector3.new(-4.9, 0, -2.2) },
					LeftHip = { rot = Vector3.new(0.6, 0, -3.2) },
				},
			},
			{
				time = 2.34,
				pose = {
					Root = { rot = Vector3.new(1.99, 0.01, 1.48), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-14.252, -3.371, 0) },
					RightShoulder = { rot = Vector3.new(45.569, 0, 32.098) },
					LeftShoulder = { rot = Vector3.new(38.374, 0, -33.601) },
					RightHip = { rot = Vector3.new(-5.7, 0, -1.6) },
					LeftHip = { rot = Vector3.new(-0.2, 0, -2.7) },
				},
			},
			{
				time = 2.4,
				pose = {
					Root = { rot = Vector3.new(2.58, 0.01, 1.05), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-15.036, -1.927, 0) },
					RightShoulder = { rot = Vector3.new(45.611, 0, 36.115) },
					LeftShoulder = { rot = Vector3.new(44.623, 0, -35.331) },
					RightHip = { rot = Vector3.new(-6.6, 0, -1) },
					LeftHip = { rot = Vector3.new(-1.1, 0, -2.1) },
				},
			},
			{
				time = 2.46,
				pose = {
					Root = { rot = Vector3.new(3.17, 0.01, 0.61), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-15.627, -0.768, 0) },
					RightShoulder = { rot = Vector3.new(47.939, 0, 38.941) },
					LeftShoulder = { rot = Vector3.new(48.701, 0, -38.021) },
					RightHip = { rot = Vector3.new(-7.5, 0, -0.4) },
					LeftHip = { rot = Vector3.new(-2, 0, -1.5) },
				},
			},
			{
				time = 2.52,
				pose = {
					Root = { rot = Vector3.new(3.73, 0, 0.2), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-15.956, -0.094, 0) },
					RightShoulder = { rot = Vector3.new(49.782, 0, 39.932) },
					LeftShoulder = { rot = Vector3.new(49.938, 0, -39.787) },
					RightHip = { rot = Vector3.new(-8.3, 0, 0.1) },
					LeftHip = { rot = Vector3.new(-2.8, 0, -0.9) },
				},
			},
			{
				time = 2.55,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(4, 0, 0), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-8.7, 0, 0.4) },
					LeftHip = { rot = Vector3.new(-3.2, 0, -0.7) },
				},
			},
			{
				time = 2.58,
				pose = {
					Root = { rot = Vector3.new(4.25, 0, -0.19), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-9.1, 0, 0.6) },
					LeftHip = { rot = Vector3.new(-3.5, 0, 0) },
				},
			},
			{
				time = 2.64,
				pose = {
					Root = {
						rot = Vector3.new(4.71, -0.01, -0.52),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-9.8, 0, 1.1) },
					LeftHip = { rot = Vector3.new(-4.2, 0, 0) },
				},
			},
			{
				time = 2.7,
				pose = {
					Root = {
						rot = Vector3.new(5.11, -0.02, -0.82),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-10.4, 0, 1.5) },
					LeftHip = { rot = Vector3.new(-4.8, 0, 0.4) },
				},
			},
			{
				time = 2.76,
				pose = {
					Root = {
						rot = Vector3.new(5.46, -0.03, -1.08),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-10.9, 0, 1.9) },
					LeftHip = { rot = Vector3.new(-5.3, 0, 0.8) },
				},
			},
			{
				time = 2.82,
				pose = {
					Root = { rot = Vector3.new(5.76, -0.05, -1.3), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-11.4, 0, 2.2) },
					LeftHip = { rot = Vector3.new(-5.8, 0, 1.1) },
				},
			},
			{
				time = 2.88,
				pose = {
					Root = {
						rot = Vector3.new(6.01, -0.06, -1.48),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-11.8, 0, 2.4) },
					LeftHip = { rot = Vector3.new(-6.1, 0, 1.3) },
				},
			},
			{
				time = 2.94,
				pose = {
					Root = {
						rot = Vector3.new(6.21, -0.06, -1.63),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-12.1, 0, 2.6) },
					LeftHip = { rot = Vector3.new(-6.4, 0, 1.5) },
				},
			},
			{
				time = 3,
				pose = {
					Root = {
						rot = Vector3.new(6.37, -0.07, -1.75),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-12.3, 0, 2.8) },
					LeftHip = { rot = Vector3.new(-6.6, 0, 1.6) },
				},
			},
			{
				time = 3.06,
				pose = {
					Root = {
						rot = Vector3.new(6.49, -0.08, -1.83),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-12.5, 0, 2.9) },
					LeftHip = { rot = Vector3.new(-6.8, 0, 1.7) },
				},
			},
			{
				time = 3.12,
				pose = {
					Root = {
						rot = Vector3.new(6.57, -0.08, -1.89),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-12.6, 0, 3) },
					LeftHip = { rot = Vector3.new(-6.9, 0, 1.8) },
				},
			},
			{
				time = 3.18,
				pose = {
					Root = {
						rot = Vector3.new(6.61, -0.08, -1.93),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-12.7, 0, 3) },
					LeftHip = { rot = Vector3.new(-7, 0, 1.9) },
				},
			},
			{
				time = 3.24,
				pose = {
					Root = {
						rot = Vector3.new(6.63, -0.08, -1.93),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-12.7, 0, 3) },
					LeftHip = { rot = Vector3.new(-7, 0, 1.9) },
				},
			},
			{
				time = 3.3,
				pose = {
					Root = {
						rot = Vector3.new(6.61, -0.08, -1.92),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-12.7, 0, 3) },
					LeftHip = { rot = Vector3.new(-7, 0, 1.9) },
				},
			},
			{
				time = 3.36,
				pose = {
					Root = {
						rot = Vector3.new(6.56, -0.08, -1.89),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-12.6, 0, 3) },
					LeftHip = { rot = Vector3.new(-6.9, 0, 1.8) },
				},
			},
			{
				time = 3.42,
				pose = {
					Root = {
						rot = Vector3.new(6.49, -0.08, -1.84),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-12.5, 0, 2.9) },
					LeftHip = { rot = Vector3.new(-6.8, 0, 1.8) },
				},
			},
			{
				time = 3.48,
				pose = {
					Root = { rot = Vector3.new(6.4, -0.07, -1.77), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-12.4, 0, 2.8) },
					LeftHip = { rot = Vector3.new(-6.7, 0, 1.7) },
				},
			},
			{
				time = 3.54,
				pose = {
					Root = {
						rot = Vector3.new(6.29, -0.07, -1.69),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-12.2, 0, 2.7) },
					LeftHip = { rot = Vector3.new(-6.5, 0, 1.6) },
				},
			},
			{
				time = 3.6,
				pose = {
					Root = {
						rot = Vector3.new(6.16, -0.06, -1.59),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-12, 0, 2.6) },
					LeftHip = { rot = Vector3.new(-6.3, 0, 1.4) },
				},
			},
			{
				time = 3.66,
				pose = {
					Root = {
						rot = Vector3.new(6.02, -0.06, -1.49),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-11.8, 0, 2.4) },
					LeftHip = { rot = Vector3.new(-6.1, 0, 1.3) },
				},
			},
			{
				time = 3.72,
				pose = {
					Root = {
						rot = Vector3.new(5.86, -0.05, -1.37),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-11.5, 0, 2.3) },
					LeftHip = { rot = Vector3.new(-5.9, 0, 1.1) },
				},
			},
			{
				time = 3.78,
				pose = {
					Root = { rot = Vector3.new(5.7, -0.04, -1.25), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-11.3, 0, 2.1) },
					LeftHip = { rot = Vector3.new(-5.7, 0, 1) },
				},
			},
			{
				time = 3.84,
				pose = {
					Root = {
						rot = Vector3.new(5.53, -0.04, -1.13),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-11, 0, 1.9) },
					LeftHip = { rot = Vector3.new(-5.4, 0, 0.8) },
				},
			},
			{
				time = 3.9,
				pose = {
					Root = { rot = Vector3.new(5.36, -0.03, -1), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-10.8, 0, 1.8) },
					LeftHip = { rot = Vector3.new(-5.2, 0, 0.7) },
				},
			},
			{
				time = 3.96,
				pose = {
					Root = {
						rot = Vector3.new(5.19, -0.03, -0.88),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-10.5, 0, 1.6) },
					LeftHip = { rot = Vector3.new(-4.9, 0, 0.5) },
				},
			},
			{
				time = 4.02,
				pose = {
					Root = {
						rot = Vector3.new(5.02, -0.02, -0.75),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-10.3, 0, 1.4) },
					LeftHip = { rot = Vector3.new(-4.7, 0, 0.3) },
				},
			},
			{
				time = 4.08,
				pose = {
					Root = {
						rot = Vector3.new(4.85, -0.02, -0.63),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-10, 0, 1.3) },
					LeftHip = { rot = Vector3.new(-4.4, 0, 0.2) },
				},
			},
			{
				time = 4.14,
				pose = {
					Root = {
						rot = Vector3.new(4.69, -0.01, -0.51),
						pos = Vector3.new(0, 0.3, 0.05),
					},
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-9.8, 0, 1.1) },
					LeftHip = { rot = Vector3.new(-4.2, 0, 0) },
				},
			},
			{
				time = 4.2,
				pose = {
					Root = { rot = Vector3.new(4.54, -0.01, -0.4), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-9.5, 0, 0.9) },
					LeftHip = { rot = Vector3.new(-4, 0, -0.1) },
				},
			},
			{
				time = 4.26,
				pose = {
					Root = { rot = Vector3.new(4.41, -0.01, -0.3), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-9.3, 0, 0.8) },
					LeftHip = { rot = Vector3.new(-3.8, 0, 0) },
				},
			},
			{
				time = 4.32,
				pose = {
					Root = { rot = Vector3.new(4.29, 0, -0.21), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-9.2, 0, 0.7) },
					LeftHip = { rot = Vector3.new(-3.6, 0, -0.4) },
				},
			},
			{
				time = 4.38,
				pose = {
					Root = { rot = Vector3.new(4.18, 0, -0.13), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-9, 0, 0.6) },
					LeftHip = { rot = Vector3.new(-3.4, 0, -0.5) },
				},
			},
			{
				time = 4.44,
				pose = {
					Root = { rot = Vector3.new(4.1, 0, -0.07), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-8.9, 0, 0.5) },
					LeftHip = { rot = Vector3.new(-3.3, 0, -0.6) },
				},
			},
			{
				time = 4.5,
				pose = {
					Root = { rot = Vector3.new(4.04, 0, -0.03), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-8.8, 0, 0.4) },
					LeftHip = { rot = Vector3.new(-3.2, 0, -0.6) },
				},
			},
			{
				time = 4.56,
				pose = {
					Root = { rot = Vector3.new(4.01, 0, 0), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-8.7, 0, 0.4) },
					LeftHip = { rot = Vector3.new(-3.2, 0, -0.7) },
				},
			},
			{
				time = 4.6,
				pose = {
					Root = { rot = Vector3.new(4, 0, 0), pos = Vector3.new(0, 0.3, 0.05) },
					Neck = { rot = Vector3.new(-16, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, 40) },
					LeftShoulder = { rot = Vector3.new(50, 0, -40) },
					RightHip = { rot = Vector3.new(-8.7, 0, 0.4) },
					LeftHip = { rot = Vector3.new(-3.2, 0, -0.7) },
				},
			},
		},
	},
}

return table.freeze(clips)
