--!strict
-- Dr. Rift's clips (Shared/Kits/Rift). R6Pose format, see R6Pose / CombatClips.
-- Merged into CombatClips (the end of that file).
--
-- Authored as whole-body keys (the torso placed, feet planted, hands put on
-- targets: the gun aimed along the arm, the glove's palm thrust at a point)
-- and solved, then checked on rendered frames from real camera angles (a
-- Blender rig with the same spline as the game). Sampled densely (a key
-- every 0.06 s plus the authored ones). The timings below must stay in sync
-- with the kit data (Shared/Kits/Rift) and Shared/Finishers:
--
--   • Rift_Flask / Rift_FlaskBomb: the flask leaves his right hand at 0.34 /
--     0.36 s (FlaskDef.release), a sidearm lob.
--   • Rift_RayGun: fires at 0.32 s, one-handed, side-on; the kick after.
--   • Rift_MegaRay: both hands, braced; fires at 0.45 s, the recoil a step back.
--   • Rift_Glove: the metal palm thrust out at 0.36 s.
--   • Rift_Portal: far shot 0.28 s, near shot (down in front) 0.52 s, steps
--     in at 0.78 s.
--   • Rift_Swarm: points the glove at them at 0.35 s.
--   • Rift_Slam: hop, down on one knee, the glove into the floor at 0.55 s.
--   • Rift_Awaken: 1.0 s (Config.Kits.AWAKEN_TIME): the glove raised, then
--     both arms flung out.
--   • Rift_ClonePunch: a clone's hook, landing at 0.12 s.
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-6.18, -11.32, -0.78),
						pos = Vector3.new(0.026, -0.048, 0.045),
					},
					Neck = { rot = Vector3.new(7.558, 11.604, 0) },
					RightShoulder = { rot = Vector3.new(34.9, 0, -25.1) },
					LeftShoulder = { rot = Vector3.new(103, 0, 31.3) },
					RightHip = { rot = Vector3.new(4.1, 0, 4.5), pos = Vector3.new(0, 0.213, 0) },
					LeftHip = { rot = Vector3.new(17.3, 0, -5.3), pos = Vector3.new(0, 0.201, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-4.14, -14.96, -1.07),
						pos = Vector3.new(0.05, -0.1, 0.1),
					},
					Neck = { rot = Vector3.new(8, 15, 0) },
					RightShoulder = { rot = Vector3.new(9, 0, -17) },
					LeftShoulder = { rot = Vector3.new(94.1, 0, 20.4) },
					RightHip = { rot = Vector3.new(1.3, 0, 7.5), pos = Vector3.new(0, 0.144, 0) },
					LeftHip = { rot = Vector3.new(18.8, 0, -8.4), pos = Vector3.new(0, 0.081, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-2.4, -20.09, -0.88),
						pos = Vector3.new(0.061, -0.123, 0.139),
					},
					Neck = { rot = Vector3.new(7.326, 18.465, 0) },
					RightShoulder = { rot = Vector3.new(10, 0, -16.4) },
					LeftShoulder = { rot = Vector3.new(94.4, 0, 12.2) },
					RightHip = { rot = Vector3.new(1.6, 0, 7.3), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(15, 0, -10), pos = Vector3.new(0, 0.127, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(4.14, -38.39, 2.02),
						pos = Vector3.new(0.098, -0.199, 0.294),
					},
					Neck = { rot = Vector3.new(3.542, 33.418, 0) },
					RightShoulder = { rot = Vector3.new(16.6, 0, 38.8) },
					LeftShoulder = { rot = Vector3.new(108.5, 0, -30.4) },
					RightHip = { rot = Vector3.new(3.5, 0, 3.8), pos = Vector3.new(0, 0.219, 0) },
					LeftHip = { rot = Vector3.new(1.9, 0, -15.3), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.22,
				pose = {
					Root = {
						rot = Vector3.new(5.22, -39.88, 3.35),
						pos = Vector3.new(0.1, -0.25, 0.3),
					},
					Neck = { rot = Vector3.new(2, 35, 0) },
					RightShoulder = { rot = Vector3.new(373.9, 0, 83.3) },
					LeftShoulder = { rot = Vector3.new(122.3, 0, -35.3) },
					RightHip = { rot = Vector3.new(3.1, 0, 2.7), pos = Vector3.new(0, 0.254, 0) },
					LeftHip = { rot = Vector3.new(0.2, 0, -16.3), pos = Vector3.new(0, 0.302, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(3.15, -34, 2.75),
						pos = Vector3.new(0.083, -0.278, 0.226),
					},
					Neck = { rot = Vector3.new(2.181, 28.9, 0) },
					RightShoulder = { rot = Vector3.new(25.3, 0, 88.1) },
					LeftShoulder = { rot = Vector3.new(122.6, 0, -28.2) },
					RightHip = { rot = Vector3.new(1.3, 0, 4), pos = Vector3.new(0, 0.345, 0) },
					LeftHip = { rot = Vector3.new(4.8, 0, -15.9), pos = Vector3.new(0, 0.426, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-7.26, 0.88, 2.55),
						pos = Vector3.new(-0.015, -0.372, -0.198),
					},
					Neck = { rot = Vector3.new(4.889, -7.037, 0) },
					RightShoulder = { rot = Vector3.new(114.7, 0, -19.7) },
					LeftShoulder = { rot = Vector3.new(-58.6, 0, -31.6) },
					RightHip = { rot = Vector3.new(-15.9, 0, 2.9), pos = Vector3.new(0, 0.291, 0) },
					LeftHip = { rot = Vector3.new(30.7, 0, -4.9), pos = Vector3.new(0, 0.413, 0) },
				},
			},
			{
				time = 0.34,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-15.38, 24.21, 6.44),
						pos = Vector3.new(-0.05, -0.4, -0.35),
					},
					Neck = { rot = Vector3.new(6, -20, 0) },
					RightShoulder = { rot = Vector3.new(122.3, 0, 2.4) },
					LeftShoulder = { rot = Vector3.new(-18.5, 0, -31.9) },
					RightHip = { rot = Vector3.new(-19.3, 0, -7.9) },
					LeftHip = { rot = Vector3.new(48.2, 0, 8) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-19.25, 31.92, 9.12),
						pos = Vector3.new(-0.053, -0.404, -0.356),
					},
					Neck = { rot = Vector3.new(6.172, -20.237, 0) },
					RightShoulder = { rot = Vector3.new(129.3, 0, 10.1) },
					LeftShoulder = { rot = Vector3.new(13.4, 0, -33.6) },
					RightHip = { rot = Vector3.new(-16.7, 0, -11.1) },
					LeftHip = { rot = Vector3.new(51.6, 0, 12) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-25.9, 39.78, 14.57),
						pos = Vector3.new(-0.078, -0.439, -0.414),
					},
					Neck = { rot = Vector3.new(8, -22.379, 0) },
					RightShoulder = { rot = Vector3.new(126.2, 0, -12.2) },
					LeftShoulder = { rot = Vector3.new(26.2, 0, -25.9) },
					RightHip = { rot = Vector3.new(-13.2, 0, -15.2) },
					LeftHip = { rot = Vector3.new(55.3, 0, 16) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-23.13, 33.7, 12.6),
						pos = Vector3.new(-0.1, -0.458, -0.456),
					},
					Neck = { rot = Vector3.new(9.828, -22.97, 0) },
					RightShoulder = { rot = Vector3.new(103.4, 0, -58.6) },
					LeftShoulder = { rot = Vector3.new(-7.4, 0, -21.4) },
					RightHip = { rot = Vector3.new(-15.9, 0, -13.7) },
					LeftHip = { rot = Vector3.new(53.7, 0, 12.6) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-20.96, 30.26, 10.93),
						pos = Vector3.new(-0.1, -0.45, -0.45),
					},
					Neck = { rot = Vector3.new(10, -22, 0) },
					RightShoulder = { rot = Vector3.new(99.7, 0, -62.2) },
					LeftShoulder = { rot = Vector3.new(-16.5, 0, -18.2) },
					RightHip = { rot = Vector3.new(-17.3, 0, -12) },
					LeftHip = { rot = Vector3.new(52.1, 0, 10.8) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-16.09, 22.86, 7.11),
						pos = Vector3.new(-0.078, -0.396, -0.384),
					},
					Neck = { rot = Vector3.new(9.233, -16.802, 0) },
					RightShoulder = { rot = Vector3.new(99.5, 0, -59.3) },
					LeftShoulder = { rot = Vector3.new(-4.4, 0, 6.3) },
					RightHip = { rot = Vector3.new(-17.7, 0, -7.6), pos = Vector3.new(0, 0.097, 0) },
					LeftHip = { rot = Vector3.new(43.7, 0, 6.4), pos = Vector3.new(0, 0.193, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-9.85, 11.35, 2.25),
						pos = Vector3.new(-0.02, -0.262, -0.219),
					},
					Neck = { rot = Vector3.new(6.825, -4.879, 0) },
					RightShoulder = { rot = Vector3.new(106, 0, -33.1) },
					LeftShoulder = { rot = Vector3.new(109.3, 0, 48.9) },
					RightHip = { rot = Vector3.new(-8.2, 0, -0.5), pos = Vector3.new(0, 0.244, 0) },
					LeftHip = { rot = Vector3.new(29.5, 0, 0.2), pos = Vector3.new(0, 0.238, 0) },
				},
			},
			{
				time = 0.63,
				pose = {
					Root = {
						rot = Vector3.new(-8.04, 5.94, 0.84),
						pos = Vector3.new(0, -0.2, -0.15),
					},
					Neck = { rot = Vector3.new(6, 0, 0) },
					RightShoulder = { rot = Vector3.new(104, 0, -28.8) },
					LeftShoulder = { rot = Vector3.new(108.2, 0, 42.8) },
					RightHip = { rot = Vector3.new(-4.7, 0, 1.3), pos = Vector3.new(0, 0.153, 0) },
					LeftHip = { rot = Vector3.new(26.4, 0, -1.4), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-7.37, 1.08, 0.22),
						pos = Vector3.new(0.007, -0.138, -0.096),
					},
					Neck = { rot = Vector3.new(5.73, 3.723, 0) },
					RightShoulder = { rot = Vector3.new(101.8, 0, -33.4) },
					LeftShoulder = { rot = Vector3.new(106.5, 0, 38) },
					RightHip = { rot = Vector3.new(-1.6, 0, 1.9), pos = Vector3.new(0, 0.188, 0) },
					LeftHip = { rot = Vector3.new(22.8, 0, -2.5), pos = Vector3.new(0, 0.205, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-7.78, -7.64, 0.09),
						pos = Vector3.new(0.002, -0.021, -0.013),
					},
					Neck = { rot = Vector3.new(5.91, 9.157, 0) },
					RightShoulder = { rot = Vector3.new(108.7, 0, -36.8) },
					LeftShoulder = { rot = Vector3.new(113.1, 0, 36.3) },
					RightHip = { rot = Vector3.new(8.9, 0, -0.8), pos = Vector3.new(0, 0.062, 0) },
					LeftHip = { rot = Vector3.new(13.6, 0, -2.6), pos = Vector3.new(0, 0.16, 0) },
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-6.1, -11.64, -0.75),
						pos = Vector3.new(0.026, -0.05, 0.047),
					},
					Neck = { rot = Vector3.new(7.536, 11.74, 0) },
					RightShoulder = { rot = Vector3.new(35.1, 0, -25.1) },
					LeftShoulder = { rot = Vector3.new(103.1, 0, 31.2) },
					RightHip = { rot = Vector3.new(4.2, 0, 4.4), pos = Vector3.new(0, 0.215, 0) },
					LeftHip = { rot = Vector3.new(17.1, 0, -5.4), pos = Vector3.new(0, 0.205, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-4.14, -14.96, -1.07),
						pos = Vector3.new(0.05, -0.1, 0.1),
					},
					Neck = { rot = Vector3.new(8, 15, 0) },
					RightShoulder = { rot = Vector3.new(9, 0, -17) },
					LeftShoulder = { rot = Vector3.new(94.1, 0, 20.4) },
					RightHip = { rot = Vector3.new(1.3, 0, 7.5), pos = Vector3.new(0, 0.144, 0) },
					LeftHip = { rot = Vector3.new(18.8, 0, -8.4), pos = Vector3.new(0, 0.081, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-2.56, -19.53, -0.95),
						pos = Vector3.new(0.06, -0.121, 0.134),
					},
					Neck = { rot = Vector3.new(7.442, 17.968, 0) },
					RightShoulder = { rot = Vector3.new(10.2, 0, -16.8) },
					LeftShoulder = { rot = Vector3.new(94.2, 0, 13.3) },
					RightHip = { rot = Vector3.new(1.5, 0, 7.4), pos = Vector3.new(0, 0.169, 0) },
					LeftHip = { rot = Vector3.new(16.3, 0, -9.5) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(3.61, -37.22, 1.47),
						pos = Vector3.new(0.094, -0.184, 0.274),
					},
					Neck = { rot = Vector3.new(4.267, 31.296, 0) },
					RightShoulder = { rot = Vector3.new(15.5, 0, 15.8) },
					LeftShoulder = { rot = Vector3.new(103.5, 0, -26) },
					RightHip = { rot = Vector3.new(3.3, 0, 4.7), pos = Vector3.new(0, 0.213, 0) },
					LeftHip = { rot = Vector3.new(2.6, 0, -14.5), pos = Vector3.new(0, 0.222, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(5.22, -39.88, 3.35),
						pos = Vector3.new(0.1, -0.25, 0.3),
					},
					Neck = { rot = Vector3.new(2, 35, 0) },
					RightShoulder = { rot = Vector3.new(373.9, 0, 83.3) },
					LeftShoulder = { rot = Vector3.new(122.3, 0, -35.3) },
					RightHip = { rot = Vector3.new(3.1, 0, 2.7), pos = Vector3.new(0, 0.254, 0) },
					LeftHip = { rot = Vector3.new(0.2, 0, -16.3), pos = Vector3.new(0, 0.302, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-3.85, -11.13, 1.89),
						pos = Vector3.new(0.019, -0.342, -0.051),
					},
					Neck = { rot = Vector3.new(3.885, 5.481, 0) },
					RightShoulder = { rot = Vector3.new(120.3, 0, -19.6) },
					LeftShoulder = { rot = Vector3.new(129.7, 0, -31.2) },
					RightHip = { rot = Vector3.new(-9.4, 0, 5.6), pos = Vector3.new(0, 0.398, 0) },
					LeftHip = { rot = Vector3.new(22.2, 0, -10.2), pos = Vector3.new(0, 0.505, 0) },
				},
			},
			{
				time = 0.36,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-15.38, 24.21, 6.44),
						pos = Vector3.new(-0.05, -0.4, -0.35),
					},
					Neck = { rot = Vector3.new(6, -20, 0) },
					RightShoulder = { rot = Vector3.new(122.3, 0, 2.4) },
					LeftShoulder = { rot = Vector3.new(-18.5, 0, -31.9) },
					RightHip = { rot = Vector3.new(-19.3, 0, -7.9) },
					LeftHip = { rot = Vector3.new(48.2, 0, 8) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-24.09, 38.44, 12.98),
						pos = Vector3.new(-0.068, -0.425, -0.39),
					},
					Neck = { rot = Vector3.new(7.266, -21.512, 0) },
					RightShoulder = { rot = Vector3.new(130.8, 0, 2.5) },
					LeftShoulder = { rot = Vector3.new(28.4, 0, -27.5) },
					RightHip = { rot = Vector3.new(-14, 0, -14.2) },
					LeftHip = { rot = Vector3.new(54.4, 0, 15.4) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-24.18, 35.94, 13.34),
						pos = Vector3.new(-0.096, -0.456, -0.448),
					},
					Neck = { rot = Vector3.new(9.375, -23.094, 0) },
					RightShoulder = { rot = Vector3.new(109.1, 0, -49.4) },
					LeftShoulder = { rot = Vector3.new(1.8, 0, -23.7) },
					RightHip = { rot = Vector3.new(-15.2, 0, -14.3) },
					LeftHip = { rot = Vector3.new(54.3, 0, 13.9) },
				},
			},
			{
				time = 0.52,
				pose = {
					Root = {
						rot = Vector3.new(-20.96, 30.26, 10.93),
						pos = Vector3.new(-0.1, -0.45, -0.45),
					},
					Neck = { rot = Vector3.new(10, -22, 0) },
					RightShoulder = { rot = Vector3.new(99.7, 0, -62.2) },
					LeftShoulder = { rot = Vector3.new(-16.5, 0, -18.2) },
					RightHip = { rot = Vector3.new(-17.3, 0, -12) },
					LeftHip = { rot = Vector3.new(52.1, 0, 10.8) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-19.01, 27.24, 9.43),
						pos = Vector3.new(-0.094, -0.433, -0.431),
					},
					Neck = { rot = Vector3.new(9.859, -20.348, 0) },
					RightShoulder = { rot = Vector3.new(98.7, 0, -62.3) },
					LeftShoulder = { rot = Vector3.new(-19.4, 0, -13.9) },
					RightHip = { rot = Vector3.new(-18.7, 0, -10.8) },
					LeftHip = { rot = Vector3.new(50.7, 0, 9.5), pos = Vector3.new(0, 0.022, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-13.12, 18.16, 4.86),
						pos = Vector3.new(-0.054, -0.345, -0.32),
					},
					Neck = { rot = Vector3.new(8.286, -12.036, 0) },
					RightShoulder = { rot = Vector3.new(102.5, 0, -50.7) },
					LeftShoulder = { rot = Vector3.new(86.2, 0, 57.8) },
					RightHip = { rot = Vector3.new(-14.3, 0, -4.2), pos = Vector3.new(0, 0.216, 0) },
					LeftHip = { rot = Vector3.new(36.7, 0, 3.3), pos = Vector3.new(0, 0.284, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-8.83, 8.99, 1.49),
						pos = Vector3.new(-0.009, -0.234, -0.186),
					},
					Neck = { rot = Vector3.new(6.391, -2.559, 0) },
					RightShoulder = { rot = Vector3.new(105.9, 0, -28.9) },
					LeftShoulder = { rot = Vector3.new(109.6, 0, 46) },
					RightHip = { rot = Vector3.new(-6.4, 0, 0.4), pos = Vector3.new(0, 0.213, 0) },
					LeftHip = { rot = Vector3.new(27.5, 0, -0.6), pos = Vector3.new(0, 0.184, 0) },
				},
			},
			{
				time = 0.68,
				pose = {
					Root = {
						rot = Vector3.new(-8.04, 5.94, 0.84),
						pos = Vector3.new(0, -0.2, -0.15),
					},
					Neck = { rot = Vector3.new(6, 0, 0) },
					RightShoulder = { rot = Vector3.new(104, 0, -28.8) },
					LeftShoulder = { rot = Vector3.new(108.2, 0, 42.8) },
					RightHip = { rot = Vector3.new(-4.7, 0, 1.3), pos = Vector3.new(0, 0.153, 0) },
					LeftHip = { rot = Vector3.new(26.4, 0, -1.4), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-7.52, -0.08, 0.25),
						pos = Vector3.new(0.006, -0.12, -0.083),
					},
					Neck = { rot = Vector3.new(5.746, 4.624, 0) },
					RightShoulder = { rot = Vector3.new(102.5, 0, -34.4) },
					LeftShoulder = { rot = Vector3.new(107.3, 0, 37.3) },
					RightHip = { rot = Vector3.new(0.1, 0, 1.6), pos = Vector3.new(0, 0.188, 0) },
					LeftHip = { rot = Vector3.new(21.5, 0, -2.6), pos = Vector3.new(0, 0.232, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(-7.92, -9.02, 0.1),
						pos = Vector3.new(0.001, -0.01, -0.007),
					},
					Neck = { rot = Vector3.new(5.96, 9.577, 0) },
					RightShoulder = { rot = Vector3.new(109.9, 0, -36.7) },
					LeftShoulder = { rot = Vector3.new(114.1, 0, 36.6) },
					RightHip = { rot = Vector3.new(10.4, 0, -1.4), pos = Vector3.new(0, 0.022, 0) },
					LeftHip = { rot = Vector3.new(12.6, 0, -2.6), pos = Vector3.new(0, 0.117, 0) },
				},
			},
			{
				time = 0.8,
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-6.5, 22.31, 2.71),
						pos = Vector3.new(0.066, -0.066, 0.044),
					},
					Neck = { rot = Vector3.new(5.231, -11.654, 0) },
					RightShoulder = { rot = Vector3.new(76.6, 0, -20.9) },
					LeftShoulder = { rot = Vector3.new(90.7, 0, 37.3) },
					RightHip = { rot = Vector3.new(-5.2, 0, -5.2), pos = Vector3.new(0, 0.147, 0) },
					LeftHip = { rot = Vector3.new(27.4, 0, 4.6), pos = Vector3.new(0, 0.092, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-6.21, 49.83, 4.75),
						pos = Vector3.new(0.15, -0.15, 0.1),
					},
					Neck = { rot = Vector3.new(4, -40, 0) },
					RightShoulder = { rot = Vector3.new(-7.7, 0, 6.1) },
					LeftShoulder = { rot = Vector3.new(53.4, 0, 29.9) },
					RightHip = { rot = Vector3.new(-13.8, 0, -15.3) },
					LeftHip = { rot = Vector3.new(33.4, 0, 16) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-5.51, 56.18, 4.69),
						pos = Vector3.new(0.161, -0.161, 0.108),
					},
					Neck = { rot = Vector3.new(2.911, -47.519, 0) },
					RightShoulder = { rot = Vector3.new(14.6, 0, 34.2) },
					LeftShoulder = { rot = Vector3.new(52.7, 0, 26.4) },
					RightHip = { rot = Vector3.new(-14.6, 0, -17.2) },
					LeftHip = { rot = Vector3.new(31.8, 0, 18.3) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-5.61, 51.23, 4.4),
						pos = Vector3.new(0.151, -0.151, 0.101),
					},
					Neck = { rot = Vector3.new(2.073, -48.103, 0) },
					RightShoulder = { rot = Vector3.new(91.4, 0, 33) },
					LeftShoulder = { rot = Vector3.new(43.5, 0, 14.4) },
					RightHip = { rot = Vector3.new(-14.5, 0, -15.7) },
					LeftHip = { rot = Vector3.new(32.6, 0, 16.5) },
				},
			},
			{
				time = 0.26,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-6.21, 49.83, 4.75),
						pos = Vector3.new(0.15, -0.15, 0.1),
					},
					Neck = { rot = Vector3.new(2, -48, 0) },
					RightShoulder = { rot = Vector3.new(95.1, 0, 30.2) },
					LeftShoulder = { rot = Vector3.new(42.1, 0, 12.6) },
					RightHip = { rot = Vector3.new(-13.8, 0, -15.3) },
					LeftHip = { rot = Vector3.new(33.4, 0, 16) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-7.36, 49.52, 5.61),
						pos = Vector3.new(0.15, -0.15, 0.1),
					},
					Neck = { rot = Vector3.new(2, -48, 0) },
					RightShoulder = { rot = Vector3.new(95.9, 0, 30) },
					LeftShoulder = { rot = Vector3.new(42.4, 0, 12.4) },
					RightHip = { rot = Vector3.new(-12.7, 0, -15.3) },
					LeftHip = { rot = Vector3.new(34.5, 0, 15.8) },
				},
			},
			{
				time = 0.32,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-6.21, 49.83, 4.75),
						pos = Vector3.new(0.15, -0.15, 0.1),
					},
					Neck = { rot = Vector3.new(2, -48, 0) },
					RightShoulder = { rot = Vector3.new(95.1, 0, 30.2) },
					LeftShoulder = { rot = Vector3.new(42.1, 0, 12.6) },
					RightHip = { rot = Vector3.new(-13.8, 0, -15.3) },
					LeftHip = { rot = Vector3.new(33.4, 0, 16) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(1.44, 49.68, -1.11),
						pos = Vector3.new(0.175, -0.125, 0.175),
					},
					Neck = { rot = Vector3.new(-2, -46.848, 0) },
					RightShoulder = { rot = Vector3.new(106.7, 0, 28.1) },
					LeftShoulder = { rot = Vector3.new(40.4, 0, 14.9) },
					RightHip = { rot = Vector3.new(-19.1, 0, -13.9) },
					LeftHip = { rot = Vector3.new(27.8, 0, 16.6) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(9.29, 49.63, -7.1),
						pos = Vector3.new(0.2, -0.1, 0.25),
					},
					Neck = { rot = Vector3.new(-6, -45, 0) },
					RightShoulder = { rot = Vector3.new(117, 0, 24.6) },
					LeftShoulder = { rot = Vector3.new(38.7, 0, 17.2) },
					RightHip = { rot = Vector3.new(-24.5, 0, -12.7) },
					LeftHip = { rot = Vector3.new(21.8, 0, 17.3) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(10.88, 50.54, -8.33),
						pos = Vector3.new(0.199, -0.103, 0.245),
					},
					Neck = { rot = Vector3.new(-5.704, -44.658, 0) },
					RightShoulder = { rot = Vector3.new(114.6, 0, 26.3) },
					LeftShoulder = { rot = Vector3.new(38.8, 0, 18) },
					RightHip = { rot = Vector3.new(-25.9, 0, -13) },
					LeftHip = { rot = Vector3.new(20.3, 0, 17.6) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(6.11, 54.78, -4.63),
						pos = Vector3.new(0.186, -0.134, 0.184),
					},
					Neck = { rot = Vector3.new(-2.397, -45.295, 0) },
					RightShoulder = { rot = Vector3.new(92.9, 0, 35.5) },
					LeftShoulder = { rot = Vector3.new(44.3, 0, 22.1) },
					RightHip = { rot = Vector3.new(-22.4, 0, -15.6) },
					LeftHip = { rot = Vector3.new(23.8, 0, 18.4) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-5.01, 51.79, 3.97),
						pos = Vector3.new(0.156, -0.152, 0.109),
					},
					Neck = { rot = Vector3.new(1.55, -41.639, 0) },
					RightShoulder = { rot = Vector3.new(75.7, 0, 30.4) },
					LeftShoulder = { rot = Vector3.new(46.3, 0, 21.6) },
					RightHip = { rot = Vector3.new(-14.8, 0, -15.8) },
					LeftHip = { rot = Vector3.new(32.2, 0, 16.7) },
				},
			},
			{
				time = 0.55,
				pose = {
					Root = {
						rot = Vector3.new(-6.21, 49.83, 4.75),
						pos = Vector3.new(0.15, -0.15, 0.1),
					},
					Neck = { rot = Vector3.new(2, -40, 0) },
					RightShoulder = { rot = Vector3.new(76.9, 0, 27.9) },
					LeftShoulder = { rot = Vector3.new(45.1, 0, 20.2) },
					RightHip = { rot = Vector3.new(-13.8, 0, -15.3) },
					LeftHip = { rot = Vector3.new(33.4, 0, 16) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-7.98, 33.46, 4.65),
						pos = Vector3.new(0.096, -0.104, 0.056),
					},
					Neck = { rot = Vector3.new(3.926, -22.963, 0) },
					RightShoulder = { rot = Vector3.new(89.9, 0, -2.1) },
					LeftShoulder = { rot = Vector3.new(57.4, 0, 22.6) },
					RightHip = { rot = Vector3.new(-8.8, 0, -10.1), pos = Vector3.new(0, 0.065, 0) },
					LeftHip = { rot = Vector3.new(34.9, 0, 9.7) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-7.46, 5.98, 1.74),
						pos = Vector3.new(0.021, -0.024, 0.011),
					},
					Neck = { rot = Vector3.new(5.611, 2.664, 0) },
					RightShoulder = { rot = Vector3.new(105.1, 0, -33.3) },
					LeftShoulder = { rot = Vector3.new(108.7, 0, 37.9) },
					RightHip = { rot = Vector3.new(4.1, 0, -2.1), pos = Vector3.new(0, 0.119, 0) },
					LeftHip = { rot = Vector3.new(18.3, 0, -0.9), pos = Vector3.new(0, 0.154, 0) },
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-10.42, -4.22, 0.6),
						pos = Vector3.new(0, -0.088, 0.047),
					},
					Neck = { rot = Vector3.new(8.004, 6.554, 0) },
					RightShoulder = { rot = Vector3.new(91.8, 0, -35.2) },
					LeftShoulder = { rot = Vector3.new(96.5, 0, 48.2) },
					RightHip = { rot = Vector3.new(9.2, 0, 2.3), pos = Vector3.new(0, 0.317, 0) },
					LeftHip = { rot = Vector3.new(20.6, 0, -5.3), pos = Vector3.new(0, 0.291, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-12.91, 3.53, 1.54),
						pos = Vector3.new(0, -0.265, 0.138),
					},
					Neck = { rot = Vector3.new(11.786, -0.448, 0) },
					RightShoulder = { rot = Vector3.new(53.4, 0, -23.1) },
					LeftShoulder = { rot = Vector3.new(60.2, 0, 63) },
					RightHip = { rot = Vector3.new(3, 0, 8.8), pos = Vector3.new(0, 0.501, 0) },
					LeftHip = { rot = Vector3.new(36.1, 0, -8.1), pos = Vector3.new(0, 0.337, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(-14.21, 9.7, 2.44), pos = Vector3.new(0, -0.4, 0.2) },
					Neck = { rot = Vector3.new(14, -6, 0) },
					RightShoulder = { rot = Vector3.new(36.6, 0, -12.9) },
					LeftShoulder = { rot = Vector3.new(46.7, 0, 68.7) },
					RightHip = { rot = Vector3.new(-0.5, 0, 11.2), pos = Vector3.new(0, 0.375, 0) },
					LeftHip = { rot = Vector3.new(50, 0, -6.9) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-13.36, 13.21, 2.8),
						pos = Vector3.new(0, -0.446, 0.201),
					},
					Neck = { rot = Vector3.new(12.859, -8.411, 0) },
					RightShoulder = { rot = Vector3.new(50.6, 0, -8.6) },
					LeftShoulder = { rot = Vector3.new(55.8, 0, 73.5) },
					RightHip = { rot = Vector3.new(-3.5, 0, 10.4), pos = Vector3.new(0, 0.408, 0) },
					LeftHip = { rot = Vector3.new(49.1, 0, -5), pos = Vector3.new(0, 0.063, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-11.48, 14.59, 2.7),
						pos = Vector3.new(0, -0.455, 0.175),
					},
					Neck = { rot = Vector3.new(10.213, -9.603, 0) },
					RightShoulder = { rot = Vector3.new(82.9, 0, -5.3) },
					LeftShoulder = { rot = Vector3.new(75.9, 0, 76.8) },
					RightHip = { rot = Vector3.new(-7.3, 0, 9.6), pos = Vector3.new(0, 0.398, 0) },
					LeftHip = { rot = Vector3.new(45.6, 0, -4.6), pos = Vector3.new(0, 0.113, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-10.29, 14.8, 2.62),
						pos = Vector3.new(0, -0.451, 0.152),
					},
					Neck = { rot = Vector3.new(8.177, -9.983, 0) },
					RightShoulder = { rot = Vector3.new(99.8, 0, -5.8) },
					LeftShoulder = { rot = Vector3.new(270.4, 0, 140.4) },
					RightHip = { rot = Vector3.new(-9.4, 0, 9.2), pos = Vector3.new(0, 0.38, 0) },
					LeftHip = { rot = Vector3.new(42.9, 0, -4.9), pos = Vector3.new(0, 0.146, 0) },
				},
			},
			{
				time = 0.38,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-10.35, 14.77, 2.66),
						pos = Vector3.new(0, -0.45, 0.15),
					},
					Neck = { rot = Vector3.new(8, -10, 0) },
					RightShoulder = { rot = Vector3.new(101.1, 0, -5.9) },
					LeftShoulder = { rot = Vector3.new(91.6, 0, 76.3) },
					RightHip = { rot = Vector3.new(-9.4, 0, 9.1), pos = Vector3.new(0, 0.378, 0) },
					LeftHip = { rot = Vector3.new(42.9, 0, -5), pos = Vector3.new(0, 0.146, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-10.92, 14.73, 2.82),
						pos = Vector3.new(0, -0.45, 0.15),
					},
					Neck = { rot = Vector3.new(8, -10, 0) },
					RightShoulder = { rot = Vector3.new(101.6, 0, -5.8) },
					LeftShoulder = { rot = Vector3.new(92.2, 0, 76.4) },
					RightHip = { rot = Vector3.new(-8.7, 0, 9.1), pos = Vector3.new(0, 0.379, 0) },
					LeftHip = { rot = Vector3.new(43.8, 0, -5), pos = Vector3.new(0, 0.139, 0) },
				},
			},
			{
				time = 0.45,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-10.35, 14.77, 2.66),
						pos = Vector3.new(0, -0.45, 0.15),
					},
					Neck = { rot = Vector3.new(8, -10, 0) },
					RightShoulder = { rot = Vector3.new(101.1, 0, -5.9) },
					LeftShoulder = { rot = Vector3.new(91.6, 0, 76.3) },
					RightHip = { rot = Vector3.new(-9.4, 0, 9.1), pos = Vector3.new(0, 0.378, 0) },
					LeftHip = { rot = Vector3.new(42.9, 0, -5), pos = Vector3.new(0, 0.146, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-7.79, 14.85, 2),
						pos = Vector3.new(0, -0.442, 0.188),
					},
					Neck = { rot = Vector3.new(6.388, -10.052, 0) },
					RightShoulder = { rot = Vector3.new(100.1, 0, -6) },
					LeftShoulder = { rot = Vector3.new(91.6, 0, 73.6) },
					RightHip = { rot = Vector3.new(-13.4, 0, 9), pos = Vector3.new(0, 0.459, 0) },
					LeftHip = { rot = Vector3.new(39.1, 0, -4.9), pos = Vector3.new(0, 0.232, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(0.84, 14.93, -0.22),
						pos = Vector3.new(0, -0.397, 0.395),
					},
					Neck = { rot = Vector3.new(-2.134, -10.234, 0) },
					RightShoulder = { rot = Vector3.new(100.6, 0, -6.2) },
					LeftShoulder = { rot = Vector3.new(94.7, 0, 54.1) },
					RightHip = { rot = Vector3.new(-26, 0, 8.6), pos = Vector3.new(0, 0.42, 0) },
					LeftHip = { rot = Vector3.new(28.5, 0, -4.6), pos = Vector3.new(0, 0.271, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(8.28, 14.85, -2.14),
						pos = Vector3.new(0, -0.35, 0.55),
					},
					Neck = { rot = Vector3.new(-8, -10, 0) },
					RightShoulder = { rot = Vector3.new(98.4, 0, -6.4) },
					LeftShoulder = { rot = Vector3.new(93, 0, 36) },
					RightHip = { rot = Vector3.new(-37.4, 0, 8.4), pos = Vector3.new(0, 0.128, 0) },
					LeftHip = { rot = Vector3.new(19.4, 0, -4.2), pos = Vector3.new(0, 0.145, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(9.21, 14.99, -2.42),
						pos = Vector3.new(0, -0.325, 0.56),
					},
					Neck = { rot = Vector3.new(-6.569, -9.522, 0) },
					RightShoulder = { rot = Vector3.new(90.4, 0, -6) },
					LeftShoulder = { rot = Vector3.new(86.4, 0, 39.1) },
					RightHip = { rot = Vector3.new(-36, 0, 7.8), pos = Vector3.new(0, 0.235, 0) },
					LeftHip = { rot = Vector3.new(18.1, 0, -3.1), pos = Vector3.new(0, 0.117, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(5.1, 14.65, -1.39),
						pos = Vector3.new(0, -0.306, 0.522),
					},
					Neck = { rot = Vector3.new(-2.493, -8.948, 0) },
					RightShoulder = { rot = Vector3.new(80.8, 0, -6.4) },
					LeftShoulder = { rot = Vector3.new(80.8, 0, 44.3) },
					RightHip = { rot = Vector3.new(-27.2, 0, 6.6), pos = Vector3.new(0, 0.321, 0) },
					LeftHip = { rot = Vector3.new(22.2, 0, -1.4), pos = Vector3.new(0, 0.092, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(-0.79, 12.68, 0.04),
						pos = Vector3.new(0, -0.279, 0.454),
					},
					Neck = { rot = Vector3.new(1.953, -7.623, 0) },
					RightShoulder = { rot = Vector3.new(74.3, 0, -8.9) },
					LeftShoulder = { rot = Vector3.new(78.3, 0, 46.9) },
					RightHip = { rot = Vector3.new(-17.2, 0, 5.7), pos = Vector3.new(0, 0.289, 0) },
					LeftHip = { rot = Vector3.new(27.6, 0, -0.8), pos = Vector3.new(0, 0.069, 0) },
				},
			},
			{
				time = 0.82,
				pose = {
					Root = { rot = Vector3.new(-4.06, 9.98, 0.7), pos = Vector3.new(0, -0.25, 0.4) },
					Neck = { rot = Vector3.new(4, -6, 0) },
					RightShoulder = { rot = Vector3.new(73.7, 0, -11.9) },
					LeftShoulder = { rot = Vector3.new(78.4, 0, 46.3) },
					RightHip = { rot = Vector3.new(-12.4, 0, 5.7), pos = Vector3.new(0, 0.205, 0) },
					LeftHip = { rot = Vector3.new(29.8, 0, -1.9), pos = Vector3.new(0, 0.063, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(-5.18, 8.13, 0.86),
						pos = Vector3.new(0, -0.228, 0.365),
					},
					Neck = { rot = Vector3.new(4.622, -4.661, 0) },
					RightShoulder = { rot = Vector3.new(75.1, 0, -14.6) },
					LeftShoulder = { rot = Vector3.new(79.5, 0, 45.2) },
					RightHip = { rot = Vector3.new(-10.5, 0, 5.8), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(29.4, 0, -2.8), pos = Vector3.new(0, 0.103, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(-6.84, 1.14, 0.77),
						pos = Vector3.new(0, -0.124, 0.199),
					},
					Neck = { rot = Vector3.new(5.698, 1.907, 0) },
					RightShoulder = { rot = Vector3.new(87.2, 0, -28) },
					LeftShoulder = { rot = Vector3.new(91.2, 0, 41) },
					RightHip = { rot = Vector3.new(-2, 0, 3.9), pos = Vector3.new(0, 0.413, 0) },
					LeftHip = { rot = Vector3.new(21.9, 0, -3.9), pos = Vector3.new(0, 0.183, 0) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = {
						rot = Vector3.new(-7.38, -6.86, 0.33),
						pos = Vector3.new(0, -0.026, 0.041),
					},
					Neck = { rot = Vector3.new(5.99, 8.326, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -36) },
					LeftShoulder = { rot = Vector3.new(110.1, 0, 37.7) },
					RightHip = { rot = Vector3.new(7.5, 0, -0.2), pos = Vector3.new(0, 0.199, 0) },
					LeftHip = { rot = Vector3.new(13.5, 0, -2.9), pos = Vector3.new(0, 0.105, 0) },
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-6.89, 9.99, 2.23),
						pos = Vector3.new(-0.028, -0.072, 0.096),
					},
					Neck = { rot = Vector3.new(6.222, -2.037, 0) },
					RightShoulder = { rot = Vector3.new(106, 0, -31.7) },
					LeftShoulder = { rot = Vector3.new(106, 0, 35.2) },
					RightHip = { rot = Vector3.new(3.6, 0, 0.1), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(20.2, 0, 0.2), pos = Vector3.new(0, 0.114, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-6.59, 32, 4.33),
						pos = Vector3.new(-0.078, -0.222, 0.259),
					},
					Neck = { rot = Vector3.new(6.889, -24.074, 0) },
					RightShoulder = { rot = Vector3.new(98.1, 0, 5.3) },
					LeftShoulder = { rot = Vector3.new(50, 0, -2.3) },
					RightHip = { rot = Vector3.new(-7, 0, 0.1), pos = Vector3.new(0, 0.299, 0) },
					LeftHip = { rot = Vector3.new(32.5, 0, 10.2) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-7.81, 39.74, 5.01),
						pos = Vector3.new(-0.1, -0.35, 0.3),
					},
					Neck = { rot = Vector3.new(8, -35, 0) },
					RightShoulder = { rot = Vector3.new(-71.4, 0, 91.2) },
					LeftShoulder = { rot = Vector3.new(24.5, 0, -14.2) },
					RightHip = { rot = Vector3.new(-11.2, 0, -0.5), pos = Vector3.new(0, 0.253, 0) },
					LeftHip = { rot = Vector3.new(36.2, 0, 15.1) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-10.35, 24.2, 2.45),
						pos = Vector3.new(-0.057, -0.426, 0.056),
					},
					Neck = { rot = Vector3.new(10.148, -20, 0) },
					RightShoulder = { rot = Vector3.new(79.6, 0, 52) },
					LeftShoulder = { rot = Vector3.new(53.1, 0, 18.3) },
					RightHip = { rot = Vector3.new(-11.2, 0, 1.7), pos = Vector3.new(0, 0.427, 0) },
					LeftHip = { rot = Vector3.new(40.1, 0, 10.9), pos = Vector3.new(0, 0.278, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-14.62, -2.62, -2.58),
						pos = Vector3.new(0.013, -0.48, -0.311),
					},
					Neck = { rot = Vector3.new(12.741, 6.111, 0) },
					RightShoulder = { rot = Vector3.new(-34.2, 0, -3.1) },
					LeftShoulder = { rot = Vector3.new(100.7, 0, 20.3) },
					RightHip = { rot = Vector3.new(-11, 0, 10.1), pos = Vector3.new(0, 0.45, 0) },
					LeftHip = { rot = Vector3.new(38, 0, -1.2), pos = Vector3.new(0, 0.549, 0) },
				},
			},
			{
				time = 0.36,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-19.72, -23.7, -8.2),
						pos = Vector3.new(0.05, -0.5, -0.5),
					},
					Neck = { rot = Vector3.new(14, 20, 0) },
					RightShoulder = { rot = Vector3.new(-22.1, 0, 10.9) },
					LeftShoulder = { rot = Vector3.new(112.1, 0, -3.4) },
					RightHip = { rot = Vector3.new(-3.1, 0, 19.7), pos = Vector3.new(0, 0.384, 0) },
					LeftHip = { rot = Vector3.new(34.9, 0, -10.2), pos = Vector3.new(0, 0.44, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-20.51, -27.59, -9.2),
						pos = Vector3.new(0.053, -0.503, -0.491),
					},
					Neck = { rot = Vector3.new(13.31, 19.724, 0) },
					RightShoulder = { rot = Vector3.new(-14.8, 0, 13.4) },
					LeftShoulder = { rot = Vector3.new(116.3, 0, -9.1) },
					RightHip = { rot = Vector3.new(-0.4, 0, 20.5), pos = Vector3.new(0, 0.403, 0) },
					LeftHip = { rot = Vector3.new(33.1, 0, -11.8), pos = Vector3.new(0, 0.476, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-17.19, -21.11, -6.35),
						pos = Vector3.new(0.05, -0.48, -0.45),
					},
					Neck = { rot = Vector3.new(12, 18, 0) },
					RightShoulder = { rot = Vector3.new(-23.5, 0, 7.9) },
					LeftShoulder = { rot = Vector3.new(113.6, 0, -0.2) },
					RightHip = { rot = Vector3.new(-5.9, 0, 17.8), pos = Vector3.new(0, 0.364, 0) },
					LeftHip = { rot = Vector3.new(35.4, 0, -10), pos = Vector3.new(0, 0.396, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-13.2, -13.54, -3.61),
						pos = Vector3.new(0.034, -0.413, -0.372),
					},
					Neck = { rot = Vector3.new(10.594, 13.701, 0) },
					RightShoulder = { rot = Vector3.new(-9.6, 0, -9.7) },
					LeftShoulder = { rot = Vector3.new(108.5, 0, 11.5) },
					RightHip = { rot = Vector3.new(-9.4, 0, 12.3), pos = Vector3.new(0, 0.463, 0) },
					LeftHip = { rot = Vector3.new(31.8, 0, -6.7), pos = Vector3.new(0, 0.501, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-9.82, -7.96, -1.75),
						pos = Vector3.new(0.013, -0.326, -0.276),
					},
					Neck = { rot = Vector3.new(9.087, 8.625, 0) },
					RightShoulder = { rot = Vector3.new(95, 0, -44.7) },
					LeftShoulder = { rot = Vector3.new(105.3, 0, 23.9) },
					RightHip = { rot = Vector3.new(-6.6, 0, 6.7), pos = Vector3.new(0, 0.417, 0) },
					LeftHip = { rot = Vector3.new(25.3, 0, -4.4), pos = Vector3.new(0, 0.426, 0) },
				},
			},
			{
				time = 0.65,
				pose = {
					Root = {
						rot = Vector3.new(-8.04, -5.94, -0.84),
						pos = Vector3.new(0, -0.25, -0.2),
					},
					Neck = { rot = Vector3.new(8, 6, 0) },
					RightShoulder = { rot = Vector3.new(101.1, 0, -40.7) },
					LeftShoulder = { rot = Vector3.new(101.3, 0, 29.7) },
					RightHip = { rot = Vector3.new(-4.1, 0, 4.5), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(23.6, 0, -4.2), pos = Vector3.new(0, 0.199, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-7.85, -5.91, -0.72),
						pos = Vector3.new(-0.001, -0.234, -0.185),
					},
					Neck = { rot = Vector3.new(7.811, 5.833, 0) },
					RightShoulder = { rot = Vector3.new(100.1, 0, -40.2) },
					LeftShoulder = { rot = Vector3.new(100.4, 0, 29.7) },
					RightHip = { rot = Vector3.new(-3.9, 0, 4.3), pos = Vector3.new(0, 0.239, 0) },
					LeftHip = { rot = Vector3.new(23.4, 0, -4.3), pos = Vector3.new(0, 0.229, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-7.59, -7.76, -0.29),
						pos = Vector3.new(-0.003, -0.108, -0.082),
					},
					Neck = { rot = Vector3.new(6.727, 7.303, 0) },
					RightShoulder = { rot = Vector3.new(102.2, 0, -38.4) },
					LeftShoulder = { rot = Vector3.new(105, 0, 32.6) },
					RightHip = { rot = Vector3.new(2.8, 0, 1.8), pos = Vector3.new(0, 0.212, 0) },
					LeftHip = { rot = Vector3.new(17.7, 0, -3.6), pos = Vector3.new(0, 0.317, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(-7.96, -11.08, -0.09),
						pos = Vector3.new(0, -0.009, -0.006),
					},
					Neck = { rot = Vector3.new(6.054, 9.748, 0) },
					RightShoulder = { rot = Vector3.new(110.1, 0, -36.8) },
					LeftShoulder = { rot = Vector3.new(114.1, 0, 36.6) },
					RightHip = { rot = Vector3.new(11, 0, -1.6), pos = Vector3.new(0, 0.015, 0) },
					LeftHip = { rot = Vector3.new(11.9, 0, -2.6), pos = Vector3.new(0, 0.117, 0) },
				},
			},
			{
				time = 0.8,
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-5.04, 10.53, 1.14),
						pos = Vector3.new(0.034, -0.051, 0.034),
					},
					Neck = { rot = Vector3.new(4.741, -3.539, 0) },
					RightShoulder = { rot = Vector3.new(104.3, 0, -26.1) },
					LeftShoulder = { rot = Vector3.new(93.5, 0, 35.1) },
					RightHip = { rot = Vector3.new(-2, 0, -1.6), pos = Vector3.new(0, 0.158, 0) },
					LeftHip = { rot = Vector3.new(18.8, 0, 0.6), pos = Vector3.new(0, 0.139, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-2.69, 30.67, 1.32),
						pos = Vector3.new(0.089, -0.134, 0.089),
					},
					Neck = { rot = Vector3.new(2.536, -25.58, 0) },
					RightShoulder = { rot = Vector3.new(97.9, 0, 7.4) },
					LeftShoulder = { rot = Vector3.new(31, 0, 8.2) },
					RightHip = { rot = Vector3.new(-14.5, 0, -7.6), pos = Vector3.new(0, 0.03, 0) },
					LeftHip = { rot = Vector3.new(28.1, 0, 8) },
				},
			},
			{
				time = 0.14,
				pose = {
					Root = {
						rot = Vector3.new(-2.44, 34.98, 1.4),
						pos = Vector3.new(0.1, -0.15, 0.1),
					},
					Neck = { rot = Vector3.new(2, -30, 0) },
					RightShoulder = { rot = Vector3.new(97.8, 0, 14.9) },
					LeftShoulder = { rot = Vector3.new(31.6, 0, 8.2) },
					RightHip = { rot = Vector3.new(-15.4, 0, -8.9) },
					LeftHip = { rot = Vector3.new(28.2, 0, 9.1) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-3.11, 38.59, 1.97),
						pos = Vector3.new(0.107, -0.161, 0.107),
					},
					Neck = { rot = Vector3.new(1.166, -33.458, 0) },
					RightShoulder = { rot = Vector3.new(100, 0, 19.7) },
					LeftShoulder = { rot = Vector3.new(36.7, 0, 10.4) },
					RightHip = { rot = Vector3.new(-14.8, 0, -10.1) },
					LeftHip = { rot = Vector3.new(29.4, 0, 10.3) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-4.12, 36.66, 2.43),
						pos = Vector3.new(0.103, -0.154, 0.103),
					},
					Neck = { rot = Vector3.new(0.222, -32.828, 0) },
					RightShoulder = { rot = Vector3.new(102.6, 0, 17.2) },
					LeftShoulder = { rot = Vector3.new(34.6, 0, 9.2) },
					RightHip = { rot = Vector3.new(-13.5, 0, -9.4) },
					LeftHip = { rot = Vector3.new(30.3, 0, 9.6) },
				},
			},
			{
				time = 0.28,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-2.44, 34.98, 1.4),
						pos = Vector3.new(0.1, -0.15, 0.1),
					},
					Neck = { rot = Vector3.new(0, -32, 0) },
					RightShoulder = { rot = Vector3.new(101.2, 0, 14.7) },
					LeftShoulder = { rot = Vector3.new(31.6, 0, 8.2) },
					RightHip = { rot = Vector3.new(-15.4, 0, -8.9) },
					LeftHip = { rot = Vector3.new(28.2, 0, 9.1) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-0.46, 35, 0.3),
						pos = Vector3.new(0.104, -0.143, 0.113),
					},
					Neck = { rot = Vector3.new(-0.844, -32.062, 0) },
					RightShoulder = { rot = Vector3.new(101.4, 0, 14.4) },
					LeftShoulder = { rot = Vector3.new(31.3, 0, 8.7) },
					RightHip = { rot = Vector3.new(-17.4, 0, -8.7) },
					LeftHip = { rot = Vector3.new(26.1, 0, 9.2) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(4.88, 34.9, -2.8),
						pos = Vector3.new(0.12, -0.12, 0.18),
					},
					Neck = { rot = Vector3.new(-4, -30, 0) },
					RightShoulder = { rot = Vector3.new(108, 0, 13) },
					LeftShoulder = { rot = Vector3.new(31.4, 0, 11) },
					RightHip = { rot = Vector3.new(-21.9, 0, -7.7) },
					LeftHip = { rot = Vector3.new(21.1, 0, 9.6) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(0.23, 28.07, -0.98),
						pos = Vector3.new(0.093, -0.192, 0.134),
					},
					Neck = { rot = Vector3.new(3.062, -20.695, 0) },
					RightShoulder = { rot = Vector3.new(92.9, 0, 1.9) },
					LeftShoulder = { rot = Vector3.new(27.9, 0, 9.9) },
					RightHip = { rot = Vector3.new(-17.1, 0, -5.3), pos = Vector3.new(0, 0.058, 0) },
					LeftHip = { rot = Vector3.new(25.7, 0, 8.6) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-8.31, 16.8, 1.61),
						pos = Vector3.new(0.059, -0.277, 0.069),
					},
					Neck = { rot = Vector3.new(11.625, -10.688, 0) },
					RightShoulder = { rot = Vector3.new(67, 0, -20) },
					LeftShoulder = { rot = Vector3.new(17, 0, 10.8) },
					RightHip = { rot = Vector3.new(-5.4, 0, -2), pos = Vector3.new(0, 0.203, 0) },
					LeftHip = { rot = Vector3.new(35.2, 0, 5.2) },
				},
			},
			{
				time = 0.52,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-12.18, 9.78, 2.1),
						pos = Vector3.new(0.05, -0.3, 0.05),
					},
					Neck = { rot = Vector3.new(14, -8, 0) },
					RightShoulder = { rot = Vector3.new(63, 0, -28.2) },
					LeftShoulder = { rot = Vector3.new(3.9, 0, 11.5) },
					RightHip = { rot = Vector3.new(1, 0, -1), pos = Vector3.new(0, 0.237, 0) },
					LeftHip = { rot = Vector3.new(38.4, 0, 1.8), pos = Vector3.new(0, 0.055, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-12.95, 7.09, 1.99),
						pos = Vector3.new(0.048, -0.297, 0.044),
					},
					Neck = { rot = Vector3.new(13.695, -7.708, 0) },
					RightShoulder = { rot = Vector3.new(63.3, 0, -29.8) },
					LeftShoulder = { rot = Vector3.new(0.6, 0, 11) },
					RightHip = { rot = Vector3.new(2.7, 0, -0.7), pos = Vector3.new(0, 0.279, 0) },
					LeftHip = { rot = Vector3.new(38.7, 0, 0.5), pos = Vector3.new(0, 0.134, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-11.71, 2.21, 1.12),
						pos = Vector3.new(0.028, -0.259, -0.04),
					},
					Neck = { rot = Vector3.new(10.353, -4.471, 0) },
					RightShoulder = { rot = Vector3.new(48.7, 0, -24.5) },
					LeftShoulder = { rot = Vector3.new(12.3, 0, 4.9) },
					RightHip = { rot = Vector3.new(3.7, 0, 0.7), pos = Vector3.new(0, 0.331, 0) },
					LeftHip = { rot = Vector3.new(39, 0, -0.7), pos = Vector3.new(0, 0.188, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-8.65, 0.33, 0.22),
						pos = Vector3.new(0.004, -0.211, -0.22),
					},
					Neck = { rot = Vector3.new(6.614, -0.704, 0) },
					RightShoulder = { rot = Vector3.new(17.4, 0, -7.9) },
					LeftShoulder = { rot = Vector3.new(17.1, 0, 0.1) },
					RightHip = { rot = Vector3.new(-0.5, 0, 2.4), pos = Vector3.new(0, 0.234, 0) },
					LeftHip = { rot = Vector3.new(35.6, 0, -0.2), pos = Vector3.new(0, 0.046, 0) },
				},
			},
			{
				time = 0.68,
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, -0.2, -0.3) },
					Neck = { rot = Vector3.new(6, 0, 0) },
					RightShoulder = { rot = Vector3.new(9.9, 0, -5.9) },
					LeftShoulder = { rot = Vector3.new(10.9, 0, -0.1) },
					RightHip = { rot = Vector3.new(-3, 0, 2.8), pos = Vector3.new(0, 0.177, 0) },
					LeftHip = { rot = Vector3.new(32.9, 0, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-7.87, -0.54, -0.23),
						pos = Vector3.new(-0.004, -0.185, -0.544),
					},
					Neck = { rot = Vector3.new(5.869, 0.569, 0) },
					RightShoulder = { rot = Vector3.new(4.8, 0, -6.5) },
					LeftShoulder = { rot = Vector3.new(2.4, 0, 2.2) },
					RightHip = { rot = Vector3.new(-6.9, 0, 3.1), pos = Vector3.new(0, 0.386, 0) },
					LeftHip = { rot = Vector3.new(27.3, 0, 0.2), pos = Vector3.new(0, 0.264, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(-9.32, -0.9, -0.24),
						pos = Vector3.new(-0.003, -0.17, -1.033),
					},
					Neck = { rot = Vector3.new(6.972, 0.465, 0) },
					RightShoulder = { rot = Vector3.new(9.6, 0, -9.5) },
					LeftShoulder = { rot = Vector3.new(11.5, 0, 6.8) },
					RightHip = { rot = Vector3.new(-5.1, 0, 2.5), pos = Vector3.new(0, 0.5, 0) },
					LeftHip = { rot = Vector3.new(26.3, 0, 0), pos = Vector3.new(0, 0.385, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(-10.27, -0.42, -0.06),
						pos = Vector3.new(0, -0.156, -1.376),
					},
					Neck = { rot = Vector3.new(7.995, 0.046, 0) },
					RightShoulder = { rot = Vector3.new(16.5, 0, -12.2) },
					LeftShoulder = { rot = Vector3.new(24.2, 0, 10.5) },
					RightHip = { rot = Vector3.new(-0.5, 0, 1.6), pos = Vector3.new(0, 0.253, 0) },
					LeftHip = { rot = Vector3.new(29, 0, -0.1), pos = Vector3.new(0, 0.146, 0) },
				},
			},
			{
				time = 0.86,
				pose = {
					Root = { rot = Vector3.new(-10, 0, 0), pos = Vector3.new(0, -0.15, -1.4) },
					Neck = { rot = Vector3.new(8, 0, 0) },
					RightShoulder = { rot = Vector3.new(16.8, 0, -12.4) },
					LeftShoulder = { rot = Vector3.new(26, 0, 11.1) },
					RightHip = { rot = Vector3.new(0.1, 0, 1.4), pos = Vector3.new(0, 0.118, 0) },
					LeftHip = { rot = Vector3.new(29.6, 0, 0), pos = Vector3.new(0, 0.019, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(-8.3, 1.11, 0.05),
						pos = Vector3.new(0, -0.139, -1.203),
					},
					Neck = { rot = Vector3.new(7.147, -0.34, 0) },
					RightShoulder = { rot = Vector3.new(13.7, 0, -13.2) },
					LeftShoulder = { rot = Vector3.new(24, 0, 12.9) },
					RightHip = { rot = Vector3.new(-3.8, 0, 1.6), pos = Vector3.new(0, 0.376, 0) },
					LeftHip = { rot = Vector3.new(23.8, 0, -0.2), pos = Vector3.new(0, 0.413, 0) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = {
						rot = Vector3.new(-4.96, 1.73, -0.02),
						pos = Vector3.new(0, -0.12, -0.554),
					},
					Neck = { rot = Vector3.new(4.912, -0.85, 0) },
					RightShoulder = { rot = Vector3.new(11.3, 0, -16.7) },
					LeftShoulder = { rot = Vector3.new(18.7, 0, 17.4) },
					RightHip = { rot = Vector3.new(-7, 0, 2.4), pos = Vector3.new(0, 0.369, 0) },
					LeftHip = { rot = Vector3.new(15.5, 0, -1.8), pos = Vector3.new(0, 0.449, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = { rot = Vector3.new(-4, 0, 0), pos = Vector3.new(0, -0.1, -0.2) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(22.4, 0, -18.4) },
					LeftShoulder = { rot = Vector3.new(24.8, 0, 18.4) },
					RightHip = { rot = Vector3.new(-2.7, 0, 2.8), pos = Vector3.new(0, 0.106, 0) },
					LeftHip = { rot = Vector3.new(17.3, 0, -2.8), pos = Vector3.new(0, 0.066, 0) },
				},
			},
			{
				time = 1.02,
				pose = {
					Root = {
						rot = Vector3.new(-4.31, -1.82, 0.05),
						pos = Vector3.new(0, -0.082, -0.105),
					},
					Neck = { rot = Vector3.new(4.101, 1.573, 0) },
					RightShoulder = { rot = Vector3.new(40.2, 0, -22.7) },
					LeftShoulder = { rot = Vector3.new(41.2, 0, 21.6) },
					RightHip = { rot = Vector3.new(1, 0, 2.5), pos = Vector3.new(0, 0.094, 0) },
					LeftHip = { rot = Vector3.new(18.3, 0, -3.2), pos = Vector3.new(0, 0.152, 0) },
				},
			},
			{
				time = 1.08,
				pose = {
					Root = {
						rot = Vector3.new(-7.07, -9.46, 0.08),
						pos = Vector3.new(0, -0.008, -0.002),
					},
					Neck = { rot = Vector3.new(5.765, 9.093, 0) },
					RightShoulder = { rot = Vector3.new(106.6, 0, -36.4) },
					LeftShoulder = { rot = Vector3.new(111.4, 0, 36.6) },
					RightHip = { rot = Vector3.new(9.9, 0, -1.1) },
					LeftHip = { rot = Vector3.new(11.8, 0, -2.6), pos = Vector3.new(0, 0.132, 0) },
				},
			},
			{
				time = 1.1,
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-4.21, -10.65, 0.14),
						pos = Vector3.new(-0.002, -0.027, 0.039),
					},
					Neck = { rot = Vector3.new(2.48, 8.885, 0) },
					RightShoulder = { rot = Vector3.new(115.5, 0, -27.8) },
					LeftShoulder = { rot = Vector3.new(132.8, 0, 34.5) },
					RightHip = { rot = Vector3.new(7.2, 0, -1.3) },
					LeftHip = { rot = Vector3.new(7.4, 0, -1.8), pos = Vector3.new(0, 0.045, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-0.82, -9.66, 0.13),
						pos = Vector3.new(-0.003, -0.079, 0.095),
					},
					Neck = { rot = Vector3.new(-2.96, 7.659, 0) },
					RightShoulder = { rot = Vector3.new(205.3, 0, 39.9) },
					LeftShoulder = { rot = Vector3.new(190.9, 0, 12) },
					RightHip = { rot = Vector3.new(3.5, 0, -0.5), pos = Vector3.new(0, 0.07, 0) },
					LeftHip = { rot = Vector3.new(4.3, 0, -1), pos = Vector3.new(0, 0.086, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(0, -10, 0), pos = Vector3.new(0, -0.1, 0.1) },
					Neck = { rot = Vector3.new(-4, 8, 0) },
					RightShoulder = { rot = Vector3.new(51.3, 0, 106) },
					LeftShoulder = { rot = Vector3.new(201, 0, 7.6) },
					RightHip = { rot = Vector3.new(2.5, 0, -0.2), pos = Vector3.new(0, 0.096, 0) },
					LeftHip = { rot = Vector3.new(3.1, 0, -0.8), pos = Vector3.new(0, 0.104, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-0.06, -11.19, -0.25),
						pos = Vector3.new(0.006, -0.118, 0.082),
					},
					Neck = { rot = Vector3.new(-3.393, 9.348, 0) },
					RightShoulder = { rot = Vector3.new(217.2, 0, 37.9) },
					LeftShoulder = { rot = Vector3.new(195.2, 0, 6.4) },
					RightHip = { rot = Vector3.new(1.6, 0, 0.5), pos = Vector3.new(0, 0.202, 0) },
					LeftHip = { rot = Vector3.new(3.6, 0, -1), pos = Vector3.new(0, 0.241, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-2.28, -15.45, -1.12),
						pos = Vector3.new(0.025, -0.158, 0.007),
					},
					Neck = { rot = Vector3.new(0.252, 13.881, 0) },
					RightShoulder = { rot = Vector3.new(166.2, 0, 27) },
					LeftShoulder = { rot = Vector3.new(138, 0, -0.4) },
					RightHip = { rot = Vector3.new(-0.6, 0, 4), pos = Vector3.new(0, 0.361, 0) },
					LeftHip = { rot = Vector3.new(10.2, 0, -3.9), pos = Vector3.new(0, 0.423, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-5.94, -20.76, -2.47),
						pos = Vector3.new(0.044, -0.19, -0.071),
					},
					Neck = { rot = Vector3.new(4.438, 18.393, 0) },
					RightShoulder = { rot = Vector3.new(147.5, 0, 8.7) },
					LeftShoulder = { rot = Vector3.new(103.3, 0, -1.3) },
					RightHip = { rot = Vector3.new(-0.9, 0, 8.4), pos = Vector3.new(0, 0.352, 0) },
					LeftHip = { rot = Vector3.new(18.4, 0, -8.7), pos = Vector3.new(0, 0.371, 0) },
				},
			},
			{
				time = 0.35,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-8.81, -24.74, -3.71),
						pos = Vector3.new(0.05, -0.2, -0.1),
					},
					Neck = { rot = Vector3.new(6, 20, 0) },
					RightShoulder = { rot = Vector3.new(144.2, 0, 1.9) },
					LeftShoulder = { rot = Vector3.new(100.2, 0, -4.8) },
					RightHip = { rot = Vector3.new(2.2, 0, 10.2), pos = Vector3.new(0, 0.239, 0) },
					LeftHip = { rot = Vector3.new(22.6, 0, -11.4), pos = Vector3.new(0, 0.185, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-9.26, -25.4, -3.93),
						pos = Vector3.new(0.05, -0.2, -0.1),
					},
					Neck = { rot = Vector3.new(6.003, 20.015, 0) },
					RightShoulder = { rot = Vector3.new(144, 0, 1.1) },
					LeftShoulder = { rot = Vector3.new(100.7, 0, -5.7) },
					RightHip = { rot = Vector3.new(3, 0, 10.3), pos = Vector3.new(0, 0.239, 0) },
					LeftHip = { rot = Vector3.new(22.8, 0, -11.7), pos = Vector3.new(0, 0.188, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-10.77, -28.09, -4.77),
						pos = Vector3.new(0.052, -0.202, -0.102),
					},
					Neck = { rot = Vector3.new(6.086, 20.516, 0) },
					RightShoulder = { rot = Vector3.new(145.2, 0, -10.6) },
					LeftShoulder = { rot = Vector3.new(102.1, 0, -9.6) },
					RightHip = { rot = Vector3.new(5.6, 0, 10.2), pos = Vector3.new(0, 0.239, 0) },
					LeftHip = { rot = Vector3.new(22.9, 0, -12.5), pos = Vector3.new(0, 0.201, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-10.55, -28.29, -4.73),
						pos = Vector3.new(0.054, -0.204, -0.104),
					},
					Neck = { rot = Vector3.new(6.16, 20.959, 0) },
					RightShoulder = { rot = Vector3.new(147.4, 0, -21.3) },
					LeftShoulder = { rot = Vector3.new(101.3, 0, -9.9) },
					RightHip = { rot = Vector3.new(5.3, 0, 10.3), pos = Vector3.new(0, 0.242, 0) },
					LeftHip = { rot = Vector3.new(24.8, 0, -12.4) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-9.12, -25.53, -3.91),
						pos = Vector3.new(0.051, -0.201, -0.101),
					},
					Neck = { rot = Vector3.new(6.049, 20.293, 0) },
					RightShoulder = { rot = Vector3.new(148, 0, -24.3) },
					LeftShoulder = { rot = Vector3.new(99.2, 0, -6) },
					RightHip = { rot = Vector3.new(2.8, 0, 10.3), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(22.5, 0, -11.7), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.55,
				pose = {
					Root = {
						rot = Vector3.new(-8.81, -24.74, -3.71),
						pos = Vector3.new(0.05, -0.2, -0.1),
					},
					Neck = { rot = Vector3.new(6, 20, 0) },
					RightShoulder = { rot = Vector3.new(148.1, 0, -23.9) },
					LeftShoulder = { rot = Vector3.new(98.9, 0, -4.9) },
					RightHip = { rot = Vector3.new(2.2, 0, 10.2), pos = Vector3.new(0, 0.239, 0) },
					LeftHip = { rot = Vector3.new(22.6, 0, -11.4), pos = Vector3.new(0, 0.185, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-7.23, -19.62, -2.66),
						pos = Vector3.new(0.038, -0.192, -0.089),
					},
					Neck = { rot = Vector3.new(5.448, 16.985, 0) },
					RightShoulder = { rot = Vector3.new(140.8, 0, -24.7) },
					LeftShoulder = { rot = Vector3.new(97, 0, 2.3) },
					RightHip = { rot = Vector3.new(-0.3, 0, 8.9), pos = Vector3.new(0, 0.227, 0) },
					LeftHip = { rot = Vector3.new(22.3, 0, -9.3), pos = Vector3.new(0, 0.162, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-5.68, -12.72, -1.51),
						pos = Vector3.new(0.016, -0.177, -0.07),
					},
					Neck = { rot = Vector3.new(4.497, 11.703, 0) },
					RightShoulder = { rot = Vector3.new(115.6, 0, -30.1) },
					LeftShoulder = { rot = Vector3.new(94.6, 0, 12.8) },
					RightHip = { rot = Vector3.new(-1.6, 0, 6.1), pos = Vector3.new(0, 0.203, 0) },
					LeftHip = { rot = Vector3.new(20.7, 0, -6.3), pos = Vector3.new(0, 0.142, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-5.05, -7.97, -0.7),
						pos = Vector3.new(0, -0.15, -0.05),
					},
					Neck = { rot = Vector3.new(4, 8, 0) },
					RightShoulder = { rot = Vector3.new(97.4, 0, -30.9) },
					LeftShoulder = { rot = Vector3.new(92.5, 0, 20.2) },
					RightHip = { rot = Vector3.new(-1.8, 0, 4.3), pos = Vector3.new(0, 0.164, 0) },
					LeftHip = { rot = Vector3.new(20.4, 0, -4.8), pos = Vector3.new(0, 0.109, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(-5.59, -7.54, -0.28),
						pos = Vector3.new(-0.004, -0.096, -0.029),
					},
					Neck = { rot = Vector3.new(4.519, 7.757, 0) },
					RightShoulder = { rot = Vector3.new(99.9, 0, -32.2) },
					LeftShoulder = { rot = Vector3.new(98.4, 0, 26.4) },
					RightHip = { rot = Vector3.new(1.1, 0, 2.6), pos = Vector3.new(0, 0.184, 0) },
					LeftHip = { rot = Vector3.new(18, 0, -4.1), pos = Vector3.new(0, 0.235, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(-6.79, -9.77, -0.12),
						pos = Vector3.new(-0.002, -0.031, -0.009),
					},
					Neck = { rot = Vector3.new(5.481, 9.101, 0) },
					RightShoulder = { rot = Vector3.new(107, 0, -35.6) },
					LeftShoulder = { rot = Vector3.new(109.8, 0, 33.7) },
					RightHip = { rot = Vector3.new(7.4, 0, -0.1), pos = Vector3.new(0, 0.096, 0) },
					LeftHip = { rot = Vector3.new(13, 0, -3), pos = Vector3.new(0, 0.201, 0) },
				},
			},
			{
				time = 0.9,
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-10.05, -13.15, -1.17),
						pos = Vector3.new(0, -0.102, 0.032),
					},
					Neck = { rot = Vector3.new(7.284, 10.07, 0) },
					RightShoulder = { rot = Vector3.new(106.8, 0, -34.7) },
					LeftShoulder = { rot = Vector3.new(131.6, 0, 36.3) },
					RightHip = { rot = Vector3.new(14.4, 0, 0), pos = Vector3.new(0, 0.153, 0) },
					LeftHip = { rot = Vector3.new(14.8, 0, -3.4), pos = Vector3.new(0, 0.119, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-12.52, -14.33, -2.5),
						pos = Vector3.new(0, -0.295, 0.097),
					},
					Neck = { rot = Vector3.new(9.552, 10.16, 0) },
					RightShoulder = { rot = Vector3.new(96.4, 0, -22) },
					LeftShoulder = { rot = Vector3.new(197.5, 0, 20.8) },
					RightHip = { rot = Vector3.new(16.6, 0, 3.2), pos = Vector3.new(0, 0.387, 0) },
					LeftHip = { rot = Vector3.new(18.9, 0, -5.8), pos = Vector3.new(0, 0.313, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-11.87, -14.86, -2.92),
						pos = Vector3.new(0, -0.409, 0.146),
					},
					Neck = { rot = Vector3.new(10.428, 10.09, 0) },
					RightShoulder = { rot = Vector3.new(65.9, 0, 36) },
					LeftShoulder = { rot = Vector3.new(220.8, 0, 11.5) },
					RightHip = { rot = Vector3.new(15.5, 0, 5.7), pos = Vector3.new(0, 0.462, 0) },
					LeftHip = { rot = Vector3.new(18.8, 0, -7.6), pos = Vector3.new(0, 0.431, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-10.35, -14.77, -2.66),
						pos = Vector3.new(0, -0.4, 0.15),
					},
					Neck = { rot = Vector3.new(10, 10, 0) },
					RightShoulder = { rot = Vector3.new(50.5, 0, 40) },
					LeftShoulder = { rot = Vector3.new(40.4, 0, -153.9) },
					RightHip = { rot = Vector3.new(13.8, 0, 6.1), pos = Vector3.new(0, 0.428, 0) },
					LeftHip = { rot = Vector3.new(17.2, 0, -7.5), pos = Vector3.new(0, 0.423, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-5.15, -14.05, -1.53),
						pos = Vector3.new(0, -0.215, 0.136),
					},
					Neck = { rot = Vector3.new(6.364, 9.648, 0) },
					RightShoulder = { rot = Vector3.new(33.1, 0, 29.8) },
					LeftShoulder = { rot = Vector3.new(30.4, 0, -153.7) },
					RightHip = { rot = Vector3.new(6.4, 0, 6.2), pos = Vector3.new(0, 0.352, 0) },
					LeftHip = { rot = Vector3.new(10.6, 0, -6.5), pos = Vector3.new(0, 0.352, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(3.6, -11.96, 0.45),
						pos = Vector3.new(0, 0.272, 0.078),
					},
					Neck = { rot = Vector3.new(-2.612, 8.823, 0) },
					RightShoulder = { rot = Vector3.new(10.8, 0, 25.6) },
					LeftShoulder = { rot = Vector3.new(183.2, 0, 14) },
					RightHip = { rot = Vector3.new(-9.3, 0, 5.5), pos = Vector3.new(0, 0.168, 0) },
					LeftHip = { rot = Vector3.new(-2.8, 0, -4.2), pos = Vector3.new(0, 0.233, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = { rot = Vector3.new(6.09, -9.94, 1.06), pos = Vector3.new(0, 0.45, 0) },
					Neck = { rot = Vector3.new(-6, 8, 0) },
					RightShoulder = { rot = Vector3.new(-6, 0, 32.7) },
					LeftShoulder = { rot = Vector3.new(171.4, 0, 17.8) },
					RightHip = { rot = Vector3.new(-16.8, 0, 4.5), pos = Vector3.new(0, 0.143, 0) },
					LeftHip = { rot = Vector3.new(-8.3, 0, -3.1), pos = Vector3.new(0, 0.268, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-3.11, -9.18, -0.46),
						pos = Vector3.new(0, -0.099, -0.107),
					},
					Neck = { rot = Vector3.new(3.475, 7.207, 0) },
					RightShoulder = { rot = Vector3.new(118.1, 0, 95.9) },
					LeftShoulder = { rot = Vector3.new(163.2, 0, 20.2) },
					RightHip = { rot = Vector3.new(-10.9, 0, 6.1), pos = Vector3.new(0, 0.537, 0) },
					LeftHip = { rot = Vector3.new(6.6, 0, -3.6), pos = Vector3.new(0, 0.657, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-18.92, -8.82, -3.11),
						pos = Vector3.new(0, -0.952, -0.229),
					},
					Neck = { rot = Vector3.new(18.393, 6.428, 0) },
					RightShoulder = { rot = Vector3.new(255.9, 0, 26.3) },
					LeftShoulder = { rot = Vector3.new(65.5, 0, 23.3) },
					RightHip = { rot = Vector3.new(-5.9, 0, 9.1), pos = Vector3.new(0, 1.005, 0) },
					LeftHip = { rot = Vector3.new(29.2, 0, -4.5), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(-33.61, -8.26, -5.5),
						pos = Vector3.new(0, -1.486, -0.298),
					},
					Neck = { rot = Vector3.new(27.753, 6.01, 0) },
					RightShoulder = { rot = Vector3.new(260.9, 0, 14.8) },
					LeftShoulder = { rot = Vector3.new(65.4, 0, 21.8) },
					RightHip = { rot = Vector3.new(-1.7, 0, 10.9), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(51.5, 0, -4.2), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.55,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-35.41, -8.18, -5.78),
						pos = Vector3.new(0, -1.5, -0.3),
					},
					Neck = { rot = Vector3.new(28, 6, 0) },
					RightShoulder = { rot = Vector3.new(-97.5, 0, 14.2) },
					LeftShoulder = { rot = Vector3.new(66.8, 0, 21.8) },
					RightHip = { rot = Vector3.new(-0.2, 0, 11), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(53.4, 0, -4.3), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(-40.5, -8.03, -6.49),
						pos = Vector3.new(0, -1.509, -0.298),
					},
					Neck = { rot = Vector3.new(26.402, 5.688, 0) },
					RightShoulder = { rot = Vector3.new(266.5, 0, 11.9) },
					LeftShoulder = { rot = Vector3.new(71.7, 0, 21.3) },
					RightHip = { rot = Vector3.new(4.6, 0, 11), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(58.4, 0, -4.5), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(-39.42, -8.13, -6.11),
						pos = Vector3.new(0, -1.507, -0.287),
					},
					Neck = { rot = Vector3.new(21.665, 4.851, 0) },
					RightShoulder = { rot = Vector3.new(263.5, 0, 9.1) },
					LeftShoulder = { rot = Vector3.new(71.4, 0, 20.8) },
					RightHip = { rot = Vector3.new(3.9, 0, 10.7), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(57.8, 0, -4.7), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-32.82, -7.75, -4.7),
						pos = Vector3.new(0, -1.433, -0.265),
					},
					Neck = { rot = Vector3.new(16.213, 4.121, 0) },
					RightShoulder = { rot = Vector3.new(-101.3, 0, 8.5) },
					LeftShoulder = { rot = Vector3.new(65.6, 0, 20.9) },
					RightHip = { rot = Vector3.new(-1, 0, 10.2), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(51.8, 0, -4.8), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = {
						rot = Vector3.new(-28.23, -7.06, -3.77),
						pos = Vector3.new(0, -1.35, -0.25),
					},
					Neck = { rot = Vector3.new(14, 4, 0) },
					RightShoulder = { rot = Vector3.new(258.7, 0, 10.1) },
					LeftShoulder = { rot = Vector3.new(61.1, 0, 21.4) },
					RightHip = { rot = Vector3.new(-4.1, 0, 9.9), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(47.4, 0, -4.7), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(-23.25, -5.96, -2.84),
						pos = Vector3.new(0, -1.201, -0.228),
					},
					Neck = { rot = Vector3.new(12.115, 4.093, 0) },
					RightShoulder = { rot = Vector3.new(-111.5, 0, 10.3) },
					LeftShoulder = { rot = Vector3.new(59.1, 0, 22.8) },
					RightHip = { rot = Vector3.new(-6.9, 0, 8.8), pos = Vector3.new(0, 1.1, 0) },
					LeftHip = { rot = Vector3.new(41.8, 0, -4.2), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(-13.84, -3.72, -1.38),
						pos = Vector3.new(0, -0.737, -0.166),
					},
					Neck = { rot = Vector3.new(8.602, 4.778, 0) },
					RightShoulder = { rot = Vector3.new(133.6, 0, -32) },
					LeftShoulder = { rot = Vector3.new(79.2, 0, 29.2) },
					RightHip = { rot = Vector3.new(-3.5, 0, 5.6), pos = Vector3.new(0, 0.889, 0) },
					LeftHip = { rot = Vector3.new(28.2, 0, -3.3), pos = Vector3.new(0, 0.857, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(-8.02, -3.96, -0.56),
						pos = Vector3.new(0, -0.3, -0.1),
					},
					Neck = { rot = Vector3.new(6, 6, 0) },
					RightShoulder = { rot = Vector3.new(103.6, 0, -37.7) },
					LeftShoulder = { rot = Vector3.new(104.1, 0, 31.3) },
					RightHip = { rot = Vector3.new(0.6, 0, 3.6), pos = Vector3.new(0, 0.304, 0) },
					LeftHip = { rot = Vector3.new(21.1, 0, -3.6), pos = Vector3.new(0, 0.268, 0) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = {
						rot = Vector3.new(-7.55, -8.41, -0.17),
						pos = Vector3.new(0, -0.054, -0.026),
					},
					Neck = { rot = Vector3.new(5.693, 8.822, 0) },
					RightShoulder = { rot = Vector3.new(104.8, 0, -37.8) },
					LeftShoulder = { rot = Vector3.new(108.4, 0, 34.6) },
					RightHip = { rot = Vector3.new(7.7, 0, 0.3), pos = Vector3.new(0, 0.04, 0) },
					LeftHip = { rot = Vector3.new(14.2, 0, -3), pos = Vector3.new(0, 0.204, 0) },
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-6.98, -8.05, -0.17),
						pos = Vector3.new(0, -0.031, 0.008),
					},
					Neck = { rot = Vector3.new(7.536, 7.84, 0) },
					RightShoulder = { rot = Vector3.new(102.2, 0, -32.3) },
					LeftShoulder = { rot = Vector3.new(127.4, 0, 32.1) },
					RightHip = { rot = Vector3.new(8.9, 0, 2.2), pos = Vector3.new(0, 0.178, 0) },
					LeftHip = { rot = Vector3.new(11.7, 0, -4.7), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-6, -4, -0.49), pos = Vector3.new(0, -0.094, 0.026) },
					Neck = { rot = Vector3.new(10.128, 3.52, 0) },
					RightShoulder = { rot = Vector3.new(76.2, 0, -14.7) },
					LeftShoulder = { rot = Vector3.new(155.1, 0, 16.9) },
					RightHip = { rot = Vector3.new(5.7, 0, 9.4), pos = Vector3.new(0, 0.316, 0) },
					LeftHip = { rot = Vector3.new(14.4, 0, -9.6), pos = Vector3.new(0, 0.308, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-4.62, -0.75, -0.29),
						pos = Vector3.new(0, -0.144, 0.045),
					},
					Neck = { rot = Vector3.new(10.752, 0.28, 0) },
					RightShoulder = { rot = Vector3.new(46.2, 0, 5.6) },
					LeftShoulder = { rot = Vector3.new(169.2, 0, 7.9) },
					RightHip = { rot = Vector3.new(2.4, 0, 14), pos = Vector3.new(0, 0.261, 0) },
					LeftHip = { rot = Vector3.new(16.9, 0, -13.5), pos = Vector3.new(0, 0.212, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-4, 0, 0), pos = Vector3.new(0, -0.15, 0.05) },
					Neck = { rot = Vector3.new(10, 0, 0) },
					RightShoulder = { rot = Vector3.new(42.5, 0, 7.3) },
					LeftShoulder = { rot = Vector3.new(169, 0, 7.8) },
					RightHip = { rot = Vector3.new(1.4, 0, 14), pos = Vector3.new(0, 0.207, 0) },
					LeftHip = { rot = Vector3.new(16.9, 0, -14), pos = Vector3.new(0, 0.158, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-2.47, 0.91, 0.99),
						pos = Vector3.new(0, -0.146, 0.06),
					},
					Neck = { rot = Vector3.new(6.574, 0.686, 0) },
					RightShoulder = { rot = Vector3.new(37.3, 0, 8.7) },
					LeftShoulder = { rot = Vector3.new(167, 0, 10.2) },
					RightHip = { rot = Vector3.new(-0.9, 0, 12.6), pos = Vector3.new(0, 0.186, 0) },
					LeftHip = { rot = Vector3.new(15.4, 0, -15.2), pos = Vector3.new(0, 0.171, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(0.36, 1.17, 2.96),
						pos = Vector3.new(0, -0.119, 0.076),
					},
					Neck = { rot = Vector3.new(-1.776, 3.52, 0) },
					RightShoulder = { rot = Vector3.new(22.4, 0, 12.4) },
					LeftShoulder = { rot = Vector3.new(166.3, 0, 15.3) },
					RightHip = { rot = Vector3.new(-4.5, 0, 9.8), pos = Vector3.new(0, 0.122, 0) },
					LeftHip = { rot = Vector3.new(12, 0, -17.9), pos = Vector3.new(0, 0.183, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(3.53, 0.74, 4.59),
						pos = Vector3.new(0, -0.082, 0.09),
					},
					Neck = { rot = Vector3.new(-10.832, 7.045, 0) },
					RightShoulder = { rot = Vector3.new(5, 0, 15.5) },
					LeftShoulder = { rot = Vector3.new(165.8, 0, 19.7) },
					RightHip = { rot = Vector3.new(-8.7, 0, 7.2) },
					LeftHip = { rot = Vector3.new(7.6, 0, -20.4), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(6.62, 0.18, 4.79),
						pos = Vector3.new(0, -0.054, 0.099),
					},
					Neck = { rot = Vector3.new(-17.056, 9.603, 0) },
					RightShoulder = { rot = Vector3.new(-7, 0, 18) },
					LeftShoulder = { rot = Vector3.new(164.2, 0, 21.3) },
					RightHip = { rot = Vector3.new(-12.6, 0, 7.1) },
					LeftHip = { rot = Vector3.new(3.3, 0, -21.4) },
				},
			},
			{
				time = 0.45,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(8, 0, 4), pos = Vector3.new(0, -0.05, 0.1) },
					Neck = { rot = Vector3.new(-18, 10, 0) },
					RightShoulder = { rot = Vector3.new(-9.1, 0, 19.4) },
					LeftShoulder = { rot = Vector3.new(162.8, 0, 20.5) },
					RightHip = { rot = Vector3.new(-14.5, 0, 8.3) },
					LeftHip = { rot = Vector3.new(1, 0, -19.8), pos = Vector3.new(0, 0.144, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(9.17, -0.07, 2.5),
						pos = Vector3.new(0, -0.046, 0.102),
					},
					Neck = { rot = Vector3.new(-18.288, 8.496, 0) },
					RightShoulder = { rot = Vector3.new(-9.6, 0, 21.2) },
					LeftShoulder = { rot = Vector3.new(161, 0, 18.5) },
					RightHip = { rot = Vector3.new(-16.3, 0, 10.4) },
					LeftHip = { rot = Vector3.new(-0.7, 0, -17.6), pos = Vector3.new(0, 0.116, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(10.17, -0.06, -1.4),
						pos = Vector3.new(0, -0.032, 0.107),
					},
					Neck = { rot = Vector3.new(-19.296, 0.352, 0) },
					RightShoulder = { rot = Vector3.new(-11.1, 0, 25.7) },
					LeftShoulder = { rot = Vector3.new(158.1, 0, 12.3) },
					RightHip = { rot = Vector3.new(-18.1, 0, 16.1) },
					LeftHip = { rot = Vector3.new(-2.1, 0, -12) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = { rot = Vector3.new(8, 0, -4), pos = Vector3.new(0, -0.05, 0.1) },
					Neck = { rot = Vector3.new(-18, -6, 0) },
					RightShoulder = { rot = Vector3.new(-12.9, 0, 30) },
					LeftShoulder = { rot = Vector3.new(159.9, 0, 8.2) },
					RightHip = { rot = Vector3.new(-14.4, 0, 19.6), pos = Vector3.new(0, 0.157, 0) },
					LeftHip = { rot = Vector3.new(1, 0, -8.2) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(2.05, -0.11, -3.26),
						pos = Vector3.new(0, -0.156, 0.058),
					},
					Neck = { rot = Vector3.new(-10.368, -4.608, 0) },
					RightShoulder = { rot = Vector3.new(199.4, 0, 85.8) },
					LeftShoulder = { rot = Vector3.new(162.3, 0, -11.3) },
					RightHip = { rot = Vector3.new(-6.8, 0, 18.5), pos = Vector3.new(0, 0.265, 0) },
					LeftHip = { rot = Vector3.new(8.5, 0, -9.5), pos = Vector3.new(0, 0.123, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-4.19, -0.21, -0.94),
						pos = Vector3.new(0, -0.278, 0.009),
					},
					Neck = { rot = Vector3.new(-1.584, -0.784, 0) },
					RightShoulder = { rot = Vector3.new(120.2, 0, 58) },
					LeftShoulder = { rot = Vector3.new(140.7, 0, -52.8) },
					RightHip = { rot = Vector3.new(0.3, 0, 15.3), pos = Vector3.new(0, 0.349, 0) },
					LeftHip = { rot = Vector3.new(15.6, 0, -12.9), pos = Vector3.new(0, 0.281, 0) },
				},
			},
			{
				time = 0.75,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0), pos = Vector3.new(0, -0.3, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(126.2, 0, 57.4) },
					LeftShoulder = { rot = Vector3.new(126.2, 0, -57.4) },
					RightHip = { rot = Vector3.new(2.3, 0, 14), pos = Vector3.new(0, 0.354, 0) },
					LeftHip = { rot = Vector3.new(17.8, 0, -14), pos = Vector3.new(0, 0.314, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = { rot = Vector3.new(-6.4, 0.52, 0.44), pos = Vector3.new(0, -0.3, 0) },
					Neck = { rot = Vector3.new(0.143, -0.213, 0) },
					RightShoulder = { rot = Vector3.new(122, 0, 58.6) },
					LeftShoulder = { rot = Vector3.new(123.2, 0, -56.3) },
					RightHip = { rot = Vector3.new(2.6, 0, 13.5), pos = Vector3.new(0, 0.346, 0) },
					LeftHip = { rot = Vector3.new(18.6, 0, -14.4), pos = Vector3.new(0, 0.317, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = { rot = Vector3.new(-4.82, 1.17, 0.28), pos = Vector3.new(0, -0.284, 0) },
					Neck = { rot = Vector3.new(1.088, -0.767, 0) },
					RightShoulder = { rot = Vector3.new(98.3, 0, 57.5) },
					LeftShoulder = { rot = Vector3.new(99.4, 0, -53.6) },
					RightHip = { rot = Vector3.new(0.2, 0, 13.7), pos = Vector3.new(0, 0.333, 0) },
					LeftHip = { rot = Vector3.new(16.8, 0, -14.1), pos = Vector3.new(0, 0.301, 0) },
				},
			},
			{
				time = 0.88,
				pose = {
					Root = { rot = Vector3.new(-4, 0, 0), pos = Vector3.new(0, -0.25, 0) },
					Neck = { rot = Vector3.new(2, 0, 0) },
					RightShoulder = { rot = Vector3.new(88, 0, 54.2) },
					LeftShoulder = { rot = Vector3.new(88, 0, -54.2) },
					RightHip = { rot = Vector3.new(-0.2, 0, 14), pos = Vector3.new(0, 0.304, 0) },
					LeftHip = { rot = Vector3.new(15.2, 0, -14), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = {
						rot = Vector3.new(-4.17, -1.38, -0.03),
						pos = Vector3.new(0, -0.215, 0),
					},
					Neck = { rot = Vector3.new(2.63, 1.296, 0) },
					RightShoulder = { rot = Vector3.new(269.5, 0, 95.4) },
					LeftShoulder = { rot = Vector3.new(90, 0, -52.2) },
					RightHip = { rot = Vector3.new(0.8, 0, 13), pos = Vector3.new(0, 0.359, 0) },
					LeftHip = { rot = Vector3.new(14.1, 0, -13.3), pos = Vector3.new(0, 0.343, 0) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = { rot = Vector3.new(-6.34, -7.6, 0.06), pos = Vector3.new(0, -0.054, 0) },
					Neck = { rot = Vector3.new(5.176, 7.763, 0) },
					RightShoulder = { rot = Vector3.new(105.6, 0, -18.3) },
					LeftShoulder = { rot = Vector3.new(112, 0, 17.1) },
					RightHip = { rot = Vector3.new(7.5, 0, 2.8), pos = Vector3.new(0, 0.215, 0) },
					LeftHip = { rot = Vector3.new(10.8, 0, -5.4), pos = Vector3.new(0, 0.261, 0) },
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(-6.62, 24.85, 2.79), pos = Vector3.new(0, -0.15, 0) },
					Neck = { rot = Vector3.new(6, -15, 0) },
					RightShoulder = { rot = Vector3.new(-108.8, 0, 23.1) },
					LeftShoulder = { rot = Vector3.new(111.3, 0, 54.2) },
					RightHip = { rot = Vector3.new(-0.1, 0, -2.6), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(17.6, 0, 2.6), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.12,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-13.79, -29.28, -6.84),
						pos = Vector3.new(0, -0.2, -0.3),
					},
					Neck = { rot = Vector3.new(10, 25, 0) },
					RightShoulder = { rot = Vector3.new(120.7, 0, -67.2) },
					LeftShoulder = { rot = Vector3.new(156.9, 0, 27.5) },
					RightHip = { rot = Vector3.new(7.9, 0, 10.4), pos = Vector3.new(0, 0.235, 0) },
					LeftHip = { rot = Vector3.new(20.3, 0, -7.6), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-19.63, -49.53, -14),
						pos = Vector3.new(0, -0.211, -0.266),
					},
					Neck = { rot = Vector3.new(9.214, 25.804, 0) },
					RightShoulder = { rot = Vector3.new(315.2, 0, -128.4) },
					LeftShoulder = { rot = Vector3.new(199, 0, 17.5) },
					RightHip = { rot = Vector3.new(18.7, 0, 9.6), pos = Vector3.new(0, 0.219, 0) },
					LeftHip = { rot = Vector3.new(13.4, 0, -9.8), pos = Vector3.new(0, 0.266, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-12.15, -34.39, -6.93),
						pos = Vector3.new(0, -0.2, -0.2),
					},
					Neck = { rot = Vector3.new(8, 25, 0) },
					RightShoulder = { rot = Vector3.new(124, 0, -89.1) },
					LeftShoulder = { rot = Vector3.new(153.1, 0, 17.6) },
					RightHip = { rot = Vector3.new(9.6, 0, 9.5), pos = Vector3.new(0, 0.243, 0) },
					LeftHip = { rot = Vector3.new(17.9, 0, -9.5), pos = Vector3.new(0, 0.224, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-9.17, -22.59, -3.32),
						pos = Vector3.new(0, -0.12, -0.112),
					},
					Neck = { rot = Vector3.new(7.032, 18.998, 0) },
					RightShoulder = { rot = Vector3.new(111.1, 0, -70.5) },
					LeftShoulder = { rot = Vector3.new(121, 0, 30.7) },
					RightHip = { rot = Vector3.new(7, 0, 5), pos = Vector3.new(0, 0.246, 0) },
					LeftHip = { rot = Vector3.new(17, 0, -6.1), pos = Vector3.new(0, 0.364, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-8.45, -16.52, -1.32),
						pos = Vector3.new(0, -0.026, -0.023),
					},
					Neck = { rot = Vector3.new(6.205, 11.942, 0) },
					RightShoulder = { rot = Vector3.new(110.2, 0, -44.4) },
					LeftShoulder = { rot = Vector3.new(115.1, 0, 36.2) },
					RightHip = { rot = Vector3.new(11.4, 0, -0.4), pos = Vector3.new(0, 0.079, 0) },
					LeftHip = { rot = Vector3.new(12.1, 0, -2.9), pos = Vector3.new(0, 0.222, 0) },
				},
			},
			{
				time = 0.4,
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
					RightHip = { rot = Vector3.new(11.8, 0, -1.9) },
					LeftHip = { rot = Vector3.new(11.4, 0, -2.7), pos = Vector3.new(0, 0.025, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-10.91, -13.21, -1.59),
						pos = Vector3.new(0, -0.133, 0.03),
					},
					Neck = { rot = Vector3.new(9.572, 9.948, 0) },
					RightShoulder = { rot = Vector3.new(90.7, 0, -32.6) },
					LeftShoulder = { rot = Vector3.new(92.3, 0, 31.9) },
					RightHip = { rot = Vector3.new(12.5, 0, 3.2), pos = Vector3.new(0, 0.312, 0) },
					LeftHip = { rot = Vector3.new(18, 0, -4.6), pos = Vector3.new(0, 0.296, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-13.63, -14.25, -3.15),
						pos = Vector3.new(0, -0.348, 0.083),
					},
					Neck = { rot = Vector3.new(15.03, 9.93, 0) },
					RightShoulder = { rot = Vector3.new(32.2, 0, -8.5) },
					LeftShoulder = { rot = Vector3.new(66.6, 0, 19.6) },
					RightHip = { rot = Vector3.new(12, 0, 10.4), pos = Vector3.new(0, 0.497, 0) },
					LeftHip = { rot = Vector3.new(26.9, 0, -8.6), pos = Vector3.new(0, 0.423, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = {
						rot = Vector3.new(-14.47, -14.54, -3.71),
						pos = Vector3.new(0, -0.4, 0.1),
					},
					Neck = { rot = Vector3.new(16, 10, 0) },
					RightShoulder = { rot = Vector3.new(21.7, 0, -3.5) },
					LeftShoulder = { rot = Vector3.new(64.1, 0, 17.1) },
					RightHip = { rot = Vector3.new(13.1, 0, 11.9), pos = Vector3.new(0, 0.443, 0) },
					LeftHip = { rot = Vector3.new(29.6, 0, -9.3), pos = Vector3.new(0, 0.36, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = {
						rot = Vector3.new(-14.78, -14.63, -4.03),
						pos = Vector3.new(0, -0.413, 0.111),
					},
					Neck = { rot = Vector3.new(15.759, 10.114, 0) },
					RightShoulder = { rot = Vector3.new(23.1, 0, -3.3) },
					LeftShoulder = { rot = Vector3.new(65.2, 0, 16.9) },
					RightHip = { rot = Vector3.new(13.7, 0, 12.1), pos = Vector3.new(0, 0.46, 0) },
					LeftHip = { rot = Vector3.new(30.2, 0, -9.2), pos = Vector3.new(0, 0.366, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-13.9, -14.36, -4.01),
						pos = Vector3.new(0, -0.419, 0.13),
					},
					Neck = { rot = Vector3.new(14.589, 10.371, 0) },
					RightShoulder = { rot = Vector3.new(23.1, 0, -3.1) },
					LeftShoulder = { rot = Vector3.new(68.5, 0, 17) },
					RightHip = { rot = Vector3.new(13, 0, 12.3), pos = Vector3.new(0, 0.473, 0) },
					LeftHip = { rot = Vector3.new(29.8, 0, -8.9), pos = Vector3.new(0, 0.365, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-11.47, -13.91, -3.36),
						pos = Vector3.new(0, -0.405, 0.148),
					},
					Neck = { rot = Vector3.new(12.74, 10.658, 0) },
					RightShoulder = { rot = Vector3.new(21.1, 0, -3.3) },
					LeftShoulder = { rot = Vector3.new(72.5, 0, 17.4) },
					RightHip = { rot = Vector3.new(10.4, 0, 12.3), pos = Vector3.new(0, 0.464, 0) },
					LeftHip = { rot = Vector3.new(27.5, 0, -8.8), pos = Vector3.new(0, 0.354, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = {
						rot = Vector3.new(-8.02, -13.69, -2.35),
						pos = Vector3.new(0, -0.379, 0.164),
					},
					Neck = { rot = Vector3.new(10.495, 10.968, 0) },
					RightShoulder = { rot = Vector3.new(18.4, 0, -3.8) },
					LeftShoulder = { rot = Vector3.new(76.3, 0, 17.7) },
					RightHip = { rot = Vector3.new(6.5, 0, 12), pos = Vector3.new(0, 0.44, 0) },
					LeftHip = { rot = Vector3.new(23.8, 0, -9), pos = Vector3.new(0, 0.341, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-4.06, -14.17, -1.17),
						pos = Vector3.new(0, -0.348, 0.178),
					},
					Neck = { rot = Vector3.new(8.139, 11.291, 0) },
					RightShoulder = { rot = Vector3.new(16.5, 0, -4.7) },
					LeftShoulder = { rot = Vector3.new(79, 0, 17.3) },
					RightHip = { rot = Vector3.new(2.2, 0, 11.6), pos = Vector3.new(0, 0.408, 0) },
					LeftHip = { rot = Vector3.new(18.9, 0, -9.5), pos = Vector3.new(0, 0.329, 0) },
				},
			},
			{
				time = 0.48,
				pose = {
					Root = {
						rot = Vector3.new(-0.02, -15.83, 0.04),
						pos = Vector3.new(0, -0.32, 0.189),
					},
					Neck = { rot = Vector3.new(5.954, 11.62, 0) },
					RightShoulder = { rot = Vector3.new(16.3, 0, -5.8) },
					LeftShoulder = { rot = Vector3.new(79.8, 0, 15.6) },
					RightHip = { rot = Vector3.new(-1.8, 0, 11.3), pos = Vector3.new(0, 0.377, 0) },
					LeftHip = { rot = Vector3.new(13.3, 0, -10.2), pos = Vector3.new(0, 0.323, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = {
						rot = Vector3.new(3.7, -19.19, 1.26),
						pos = Vector3.new(0, -0.302, 0.199),
					},
					Neck = { rot = Vector3.new(4.224, 11.946, 0) },
					RightShoulder = { rot = Vector3.new(19, 0, -7.5) },
					LeftShoulder = { rot = Vector3.new(78.1, 0, 12.2) },
					RightHip = { rot = Vector3.new(-4.7, 0, 11.2), pos = Vector3.new(0, 0.359, 0) },
					LeftHip = { rot = Vector3.new(7.4, 0, -11.1), pos = Vector3.new(0, 0.323, 0) },
				},
			},
			{
				time = 0.55,
				pose = {
					Root = {
						rot = Vector3.new(4.26, -19.95, 1.45),
						pos = Vector3.new(0, -0.3, 0.2),
					},
					Neck = { rot = Vector3.new(4, 12, 0) },
					RightShoulder = { rot = Vector3.new(19.7, 0, -7.9) },
					LeftShoulder = { rot = Vector3.new(77.5, 0, 11.4) },
					RightHip = { rot = Vector3.new(-5, 0, 11.3), pos = Vector3.new(0, 0.357, 0) },
					LeftHip = { rot = Vector3.new(6.4, 0, -11.2), pos = Vector3.new(0, 0.324, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = {
						rot = Vector3.new(6.75, -24.54, 2.44),
						pos = Vector3.new(0, -0.295, 0.205),
					},
					Neck = { rot = Vector3.new(2.995, 12.307, 0) },
					RightShoulder = { rot = Vector3.new(24.3, 0, -10.3) },
					LeftShoulder = { rot = Vector3.new(75.4, 0, 6.3) },
					RightHip = { rot = Vector3.new(-5.6, 0, 11.6), pos = Vector3.new(0, 0.357, 0) },
					LeftHip = { rot = Vector3.new(1.6, 0, -11.6), pos = Vector3.new(0, 0.326, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = {
						rot = Vector3.new(8.98, -30.54, 3.54),
						pos = Vector3.new(0, -0.293, 0.207),
					},
					Neck = { rot = Vector3.new(1.96, 12.744, 0) },
					RightShoulder = { rot = Vector3.new(29.7, 0, -13.5) },
					LeftShoulder = { rot = Vector3.new(75.3, 0, -1) },
					RightHip = { rot = Vector3.new(-5, 0, 12.1), pos = Vector3.new(0, 0.362, 0) },
					LeftHip = { rot = Vector3.new(-3.3, 0, -11.6), pos = Vector3.new(0, 0.323, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(10.14, -35.14, 4.26),
						pos = Vector3.new(0, -0.294, 0.206),
					},
					Neck = { rot = Vector3.new(1.126, 13.197, 0) },
					RightShoulder = { rot = Vector3.new(33.5, 0, -16.1) },
					LeftShoulder = { rot = Vector3.new(78.1, 0, -7.4) },
					RightHip = { rot = Vector3.new(-3.8, 0, 12.3), pos = Vector3.new(0, 0.367, 0) },
					LeftHip = { rot = Vector3.new(-6.2, 0, -11.4), pos = Vector3.new(0, 0.319, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(9.76, -36.31, 4.12),
						pos = Vector3.new(0, -0.296, 0.204),
					},
					Neck = { rot = Vector3.new(0.511, 13.6, 0) },
					RightShoulder = { rot = Vector3.new(34.6, 0, -16.8) },
					LeftShoulder = { rot = Vector3.new(83.4, 0, -9.6) },
					RightHip = { rot = Vector3.new(-2.8, 0, 12.3), pos = Vector3.new(0, 0.369, 0) },
					LeftHip = { rot = Vector3.new(-6.3, 0, -11.3), pos = Vector3.new(0, 0.32, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = {
						rot = Vector3.new(7.65, -31.96, 2.96),
						pos = Vector3.new(0, -0.299, 0.201),
					},
					Neck = { rot = Vector3.new(0.131, 13.889, 0) },
					RightShoulder = { rot = Vector3.new(31.6, 0, -14.1) },
					LeftShoulder = { rot = Vector3.new(89.1, 0, -4.3) },
					RightHip = { rot = Vector3.new(-3, 0, 12.1), pos = Vector3.new(0, 0.369, 0) },
					LeftHip = { rot = Vector3.new(-2.4, 0, -11.6), pos = Vector3.new(0, 0.331, 0) },
				},
			},
			{
				time = 0.9,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(4.26, -19.95, 1.45),
						pos = Vector3.new(0, -0.3, 0.2),
					},
					Neck = { rot = Vector3.new(0, 14, 0) },
					RightShoulder = { rot = Vector3.new(19.7, 0, -7.9) },
					LeftShoulder = { rot = Vector3.new(92.9, 0, 9.7) },
					RightHip = { rot = Vector3.new(-5, 0, 11.3), pos = Vector3.new(0, 0.357, 0) },
					LeftHip = { rot = Vector3.new(6.4, 0, -11.2), pos = Vector3.new(0, 0.324, 0) },
				},
			},
			{
				time = 0.96,
				pose = {
					Root = {
						rot = Vector3.new(0.35, -0.22, 0.76),
						pos = Vector3.new(0.015, -0.285, 0.185),
					},
					Neck = { rot = Vector3.new(1.062, 7.165, 0) },
					RightShoulder = { rot = Vector3.new(15.8, 0, -2.5) },
					LeftShoulder = { rot = Vector3.new(96, 0, 30.4) },
					RightHip = { rot = Vector3.new(-9.2, 0, 8.5), pos = Vector3.new(0, 0.302, 0) },
					LeftHip = { rot = Vector3.new(19, 0, -7.2), pos = Vector3.new(0, 0.226, 0) },
				},
			},
			{
				time = 1.02,
				pose = {
					Root = {
						rot = Vector3.new(-3.18, 18.88, 1.38),
						pos = Vector3.new(0.041, -0.259, 0.159),
					},
					Neck = { rot = Vector3.new(3.123, -5.354, 0) },
					RightShoulder = { rot = Vector3.new(21.9, 0, 14.5) },
					LeftShoulder = { rot = Vector3.new(99.2, 0, 47.2) },
					RightHip = { rot = Vector3.new(-12.5, 0, 3.9), pos = Vector3.new(0, 0.209, 0) },
					LeftHip = { rot = Vector3.new(30.2, 0, -0.1), pos = Vector3.new(0, 0.041, 0) },
				},
			},
			{
				time = 1.05,
				pose = {
					Root = {
						rot = Vector3.new(-4.41, 24.93, 1.86),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(4, -10, 0) },
					RightShoulder = { rot = Vector3.new(16, 0, 20.3) },
					LeftShoulder = { rot = Vector3.new(100, 0, 51.5) },
					RightHip = { rot = Vector3.new(-13.2, 0, 2.2), pos = Vector3.new(0, 0.175, 0) },
					LeftHip = { rot = Vector3.new(33.1, 0, 2.5) },
				},
			},
			{
				time = 1.08,
				pose = {
					Root = {
						rot = Vector3.new(-4.94, 27.39, 2.11),
						pos = Vector3.new(0.053, -0.247, 0.147),
					},
					Neck = { rot = Vector3.new(4.785, -12.51, 0) },
					RightShoulder = { rot = Vector3.new(35.8, 0, 14.1) },
					LeftShoulder = { rot = Vector3.new(100.3, 0, 53.1) },
					RightHip = { rot = Vector3.new(-13.5, 0, 1.5), pos = Vector3.new(0, 0.162, 0) },
					LeftHip = { rot = Vector3.new(34, 0, 3.5) },
				},
			},
			{
				time = 1.14,
				pose = {
					Root = {
						rot = Vector3.new(-4.54, 25.55, 1.92),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(5.966, -13.989, 0) },
					RightShoulder = { rot = Vector3.new(72.1, 0, -9.8) },
					LeftShoulder = { rot = Vector3.new(100.1, 0, 51.9) },
					RightHip = { rot = Vector3.new(-13.3, 0, 2.1), pos = Vector3.new(0, 0.173, 0) },
					LeftHip = { rot = Vector3.new(33.3, 0, 2.8) },
				},
			},
			{
				time = 1.15,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-4.41, 24.93, 1.86),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(6, -14, 0) },
					RightShoulder = { rot = Vector3.new(72.7, 0, -10.9) },
					LeftShoulder = { rot = Vector3.new(100, 0, 51.5) },
					RightHip = { rot = Vector3.new(-13.2, 0, 2.2), pos = Vector3.new(0, 0.175, 0) },
					LeftHip = { rot = Vector3.new(33.1, 0, 2.5) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = {
						rot = Vector3.new(-3.93, 22.49, 1.66),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(5.891, -14.159, 0.165) },
					RightShoulder = { rot = Vector3.new(72.9, 0, -13.4) },
					LeftShoulder = { rot = Vector3.new(99.7, 0, 49.9) },
					RightHip = { rot = Vector3.new(-13, 0, 2.8), pos = Vector3.new(0, 0.184, 0) },
					LeftHip = { rot = Vector3.new(32.1, 0, 1.4) },
				},
			},
			{
				time = 1.26,
				pose = {
					Root = {
						rot = Vector3.new(-3.65, 20.83, 1.55),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(5.516, -14.707, 0.716) },
					RightShoulder = { rot = Vector3.new(73.1, 0, -15.1) },
					LeftShoulder = { rot = Vector3.new(99.5, 0, 48.8) },
					RightHip = { rot = Vector3.new(-12.8, 0, 3.2), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(31.3, 0, 0.5), pos = Vector3.new(0, 0.014, 0) },
				},
			},
			{
				time = 1.32,
				pose = {
					Root = {
						rot = Vector3.new(-3.61, 20.3, 1.54),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(4.947, -15.541, 1.51) },
					RightShoulder = { rot = Vector3.new(73.2, 0, -15.6) },
					LeftShoulder = { rot = Vector3.new(99.5, 0, 48.4) },
					RightHip = { rot = Vector3.new(-12.6, 0, 3.3), pos = Vector3.new(0, 0.192, 0) },
					LeftHip = { rot = Vector3.new(31.1, 0, 0.3), pos = Vector3.new(0, 0.02, 0) },
				},
			},
			{
				time = 1.38,
				pose = {
					Root = {
						rot = Vector3.new(-3.73, 20.64, 1.58),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(4.262, -16.553, 2.395) },
					RightShoulder = { rot = Vector3.new(73.2, 0, -15.3) },
					LeftShoulder = { rot = Vector3.new(99.6, 0, 48.7) },
					RightHip = { rot = Vector3.new(-12.6, 0, 3.2), pos = Vector3.new(0, 0.191, 0) },
					LeftHip = { rot = Vector3.new(31.4, 0, 0.4), pos = Vector3.new(0, 0.015, 0) },
				},
			},
			{
				time = 1.44,
				pose = {
					Root = {
						rot = Vector3.new(-3.94, 21.57, 1.66),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(3.537, -17.631, 3.222) },
					RightShoulder = { rot = Vector3.new(73.1, 0, -14.3) },
					LeftShoulder = { rot = Vector3.new(99.8, 0, 49.3) },
					RightHip = { rot = Vector3.new(-12.7, 0, 3), pos = Vector3.new(0, 0.188, 0) },
					LeftHip = { rot = Vector3.new(32, 0, 0.9), pos = Vector3.new(0, 0.003, 0) },
				},
			},
			{
				time = 1.5,
				pose = {
					Root = {
						rot = Vector3.new(-4.17, 22.83, 1.76),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(2.85, -18.667, 3.841) },
					RightShoulder = { rot = Vector3.new(73, 0, -13.1) },
					LeftShoulder = { rot = Vector3.new(99.9, 0, 50.2) },
					RightHip = { rot = Vector3.new(-12.8, 0, 2.7), pos = Vector3.new(0, 0.183, 0) },
					LeftHip = { rot = Vector3.new(32.5, 0, 1.5) },
				},
			},
			{
				time = 1.56,
				pose = {
					Root = {
						rot = Vector3.new(-4.36, 24.15, 1.84),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(2.279, -19.55, 4.101) },
					RightShoulder = { rot = Vector3.new(72.9, 0, -11.7) },
					LeftShoulder = { rot = Vector3.new(100, 0, 51) },
					RightHip = { rot = Vector3.new(-13, 0, 2.4), pos = Vector3.new(0, 0.178, 0) },
					LeftHip = { rot = Vector3.new(32.9, 0, 2.1) },
				},
			},
			{
				time = 1.6,
				pose = {
					Root = {
						rot = Vector3.new(-4.41, 24.93, 1.86),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(2, -20, 4) },
					RightShoulder = { rot = Vector3.new(72.7, 0, -10.9) },
					LeftShoulder = { rot = Vector3.new(100, 0, 51.5) },
					RightHip = { rot = Vector3.new(-13.2, 0, 2.2), pos = Vector3.new(0, 0.175, 0) },
					LeftHip = { rot = Vector3.new(33.1, 0, 2.5) },
				},
			},
			{
				time = 1.62,
				pose = {
					Root = {
						rot = Vector3.new(-4.41, 25.27, 1.86),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(1.887, -20.191, 3.861) },
					RightShoulder = { rot = Vector3.new(72.6, 0, -10.5) },
					LeftShoulder = { rot = Vector3.new(100, 0, 51.7) },
					RightHip = { rot = Vector3.new(-13.4, 0, 2.1), pos = Vector3.new(0, 0.174, 0) },
					LeftHip = { rot = Vector3.new(33.1, 0, 2.6) },
				},
			},
			{
				time = 1.68,
				pose = {
					Root = {
						rot = Vector3.new(-4.31, 26.03, 1.82),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(1.559, -20.767, 3.171) },
					RightShoulder = { rot = Vector3.new(72.3, 0, -9.8) },
					LeftShoulder = { rot = Vector3.new(99.9, 0, 52.2) },
					RightHip = { rot = Vector3.new(-13.7, 0, 1.9), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(33.1, 0, 3) },
				},
			},
			{
				time = 1.74,
				pose = {
					Root = {
						rot = Vector3.new(-4.08, 26.47, 1.73),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(1.254, -21.335, 2.151) },
					RightShoulder = { rot = Vector3.new(72, 0, -9.3) },
					LeftShoulder = { rot = Vector3.new(99.6, 0, 52.4) },
					RightHip = { rot = Vector3.new(-14.2, 0, 1.8), pos = Vector3.new(0, 0.167, 0) },
					LeftHip = { rot = Vector3.new(32.9, 0, 3.2) },
				},
			},
			{
				time = 1.8,
				pose = {
					Root = {
						rot = Vector3.new(-3.8, 26.65, 1.61),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(0.974, -21.884, 0.899) },
					RightShoulder = { rot = Vector3.new(71.7, 0, -9.2) },
					LeftShoulder = { rot = Vector3.new(99.3, 0, 52.5) },
					RightHip = { rot = Vector3.new(-14.6, 0, 1.8), pos = Vector3.new(0, 0.165, 0) },
					LeftHip = { rot = Vector3.new(32.5, 0, 3.3) },
				},
			},
			{
				time = 1.86,
				pose = {
					Root = {
						rot = Vector3.new(-3.52, 26.61, 1.48),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(0.722, -22.398, -0.483) },
					RightShoulder = { rot = Vector3.new(71.5, 0, -9.2) },
					LeftShoulder = { rot = Vector3.new(99.1, 0, 52.4) },
					RightHip = { rot = Vector3.new(-14.9, 0, 1.8), pos = Vector3.new(0, 0.165, 0) },
					LeftHip = { rot = Vector3.new(32.2, 0, 3.3) },
				},
			},
			{
				time = 1.92,
				pose = {
					Root = {
						rot = Vector3.new(-3.28, 26.41, 1.38),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(0.502, -22.863, -1.897) },
					RightShoulder = { rot = Vector3.new(71.4, 0, -9.5) },
					LeftShoulder = { rot = Vector3.new(98.9, 0, 52.3) },
					RightHip = { rot = Vector3.new(-15.2, 0, 1.8), pos = Vector3.new(0, 0.165, 0) },
					LeftHip = { rot = Vector3.new(31.8, 0, 3.2) },
				},
			},
			{
				time = 1.98,
				pose = {
					Root = {
						rot = Vector3.new(-3.15, 26.11, 1.33),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(0.318, -23.268, -3.245) },
					RightShoulder = { rot = Vector3.new(71.4, 0, -9.8) },
					LeftShoulder = { rot = Vector3.new(98.8, 0, 52.1) },
					RightHip = { rot = Vector3.new(-15.3, 0, 1.9), pos = Vector3.new(0, 0.166, 0) },
					LeftHip = { rot = Vector3.new(31.6, 0, 3.1) },
				},
			},
			{
				time = 2.04,
				pose = {
					Root = {
						rot = Vector3.new(-3.18, 25.75, 1.34),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(0.172, -23.596, -4.425) },
					RightShoulder = { rot = Vector3.new(71.5, 0, -10.1) },
					LeftShoulder = { rot = Vector3.new(98.8, 0, 51.8) },
					RightHip = { rot = Vector3.new(-15.1, 0, 2), pos = Vector3.new(0, 0.167, 0) },
					LeftHip = { rot = Vector3.new(31.6, 0, 2.9) },
				},
			},
			{
				time = 2.1,
				pose = {
					Root = {
						rot = Vector3.new(-3.41, 25.39, 1.44),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(0.069, -23.836, -5.339) },
					RightShoulder = { rot = Vector3.new(71.8, 0, -10.5) },
					LeftShoulder = { rot = Vector3.new(99, 0, 51.6) },
					RightHip = { rot = Vector3.new(-14.7, 0, 2.1), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(31.9, 0, 2.7) },
				},
			},
			{
				time = 2.16,
				pose = {
					Root = {
						rot = Vector3.new(-3.91, 25.09, 1.65),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(0.011, -23.973, -5.887) },
					RightShoulder = { rot = Vector3.new(72.3, 0, -10.8) },
					LeftShoulder = { rot = Vector3.new(99.5, 0, 51.6) },
					RightHip = { rot = Vector3.new(-13.9, 0, 2.2), pos = Vector3.new(0, 0.173, 0) },
					LeftHip = { rot = Vector3.new(32.5, 0, 2.6) },
				},
			},
			{
				time = 2.2,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-4.41, 24.93, 1.86),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(0, -24, -6) },
					RightShoulder = { rot = Vector3.new(72.7, 0, -10.9) },
					LeftShoulder = { rot = Vector3.new(100, 0, 51.5) },
					RightHip = { rot = Vector3.new(-13.2, 0, 2.2), pos = Vector3.new(0, 0.175, 0) },
					LeftHip = { rot = Vector3.new(33.1, 0, 2.5) },
				},
			},
			{
				time = 2.22,
				pose = {
					Root = {
						rot = Vector3.new(-4.71, 24.88, 1.99),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(0.097, -23.806, -5.708) },
					RightShoulder = { rot = Vector3.new(73.4, 0, -10.8) },
					LeftShoulder = { rot = Vector3.new(100.3, 0, 51.5) },
					RightHip = { rot = Vector3.new(-12.8, 0, 2.2), pos = Vector3.new(0, 0.176, 0) },
					LeftHip = { rot = Vector3.new(33.5, 0, 2.4) },
				},
			},
			{
				time = 2.28,
				pose = {
					Root = {
						rot = Vector3.new(-5.38, 24.81, 2.27),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(1.1, -21.8, -2.7) },
					RightShoulder = { rot = Vector3.new(78.8, 0, -8.9) },
					LeftShoulder = { rot = Vector3.new(101, 0, 51.6) },
					RightHip = { rot = Vector3.new(-12, 0, 2.2), pos = Vector3.new(0, 0.178, 0) },
					LeftHip = { rot = Vector3.new(34.3, 0, 2.4) },
				},
			},
			{
				time = 2.34,
				pose = {
					Root = {
						rot = Vector3.new(-4.74, 24.9, 2),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(1.975, -20.051, -0.076) },
					RightShoulder = { rot = Vector3.new(82.4, 0, -7.2) },
					LeftShoulder = { rot = Vector3.new(100.3, 0, 51.6) },
					RightHip = { rot = Vector3.new(-12.8, 0, 2.2), pos = Vector3.new(0, 0.176, 0) },
					LeftHip = { rot = Vector3.new(33.5, 0, 2.5) },
				},
			},
			{
				time = 2.35,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-4.41, 24.93, 1.86),
						pos = Vector3.new(0.05, -0.25, 0.15),
					},
					Neck = { rot = Vector3.new(2, -20, 0) },
					RightShoulder = { rot = Vector3.new(82.3, 0, -7.2) },
					LeftShoulder = { rot = Vector3.new(100, 0, 51.5) },
					RightHip = { rot = Vector3.new(-13.2, 0, 2.2), pos = Vector3.new(0, 0.175, 0) },
					LeftHip = { rot = Vector3.new(33.1, 0, 2.5) },
				},
			},
			{
				time = 2.4,
				pose = {
					Root = {
						rot = Vector3.new(-1.79, 25.12, 0.76),
						pos = Vector3.new(0.058, -0.234, 0.189),
					},
					Neck = { rot = Vector3.new(0.75, -19.688, 0) },
					RightShoulder = { rot = Vector3.new(86.3, 0, -6.7) },
					LeftShoulder = { rot = Vector3.new(95.5, 0, 46.7) },
					RightHip = { rot = Vector3.new(-17.1, 0, 1.8), pos = Vector3.new(0, 0.228, 0) },
					LeftHip = { rot = Vector3.new(29.8, 0, 2.5) },
				},
			},
			{
				time = 2.46,
				pose = {
					Root = {
						rot = Vector3.new(2.68, 25.22, -1.13),
						pos = Vector3.new(0.079, -0.193, 0.294),
					},
					Neck = { rot = Vector3.new(-2.598, -18.851, 0) },
					RightShoulder = { rot = Vector3.new(101.2, 0, -6.2) },
					LeftShoulder = { rot = Vector3.new(86.5, 0, 33.7) },
					RightHip = { rot = Vector3.new(-23.8, 0, 0.7), pos = Vector3.new(0, 0.181, 0) },
					LeftHip = { rot = Vector3.new(24.1, 0, 2.1) },
				},
			},
			{
				time = 2.52,
				pose = {
					Root = {
						rot = Vector3.new(7.1, 25, -3),
						pos = Vector3.new(0.097, -0.156, 0.385),
					},
					Neck = { rot = Vector3.new(-5.514, -18.121, 0) },
					RightShoulder = { rot = Vector3.new(113.4, 0, -7) },
					LeftShoulder = { rot = Vector3.new(78.9, 0, 22.6) },
					RightHip = { rot = Vector3.new(-31, 0, 0), pos = Vector3.new(0, 0.025, 0) },
					LeftHip = { rot = Vector3.new(18.4, 0, 1.7) },
				},
			},
			{
				time = 2.55,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(8.81, 24.74, -3.71),
						pos = Vector3.new(0.1, -0.15, 0.4),
					},
					Neck = { rot = Vector3.new(-6, -18, 0) },
					RightShoulder = { rot = Vector3.new(114.1, 0, -7.4) },
					LeftShoulder = { rot = Vector3.new(76.9, 0, 20.7) },
					RightHip = { rot = Vector3.new(-32.9, 0, 0) },
					LeftHip = { rot = Vector3.new(16.1, 0, 1.6) },
				},
			},
			{
				time = 2.58,
				pose = {
					Root = {
						rot = Vector3.new(9.97, 24.4, -4.19),
						pos = Vector3.new(0.1, -0.151, 0.399),
					},
					Neck = { rot = Vector3.new(-5.767, -17.899, 0) },
					RightShoulder = { rot = Vector3.new(112.6, 0, -7.5) },
					LeftShoulder = { rot = Vector3.new(75.5, 0, 20.4) },
					RightHip = { rot = Vector3.new(-34.4, 0, 0.2) },
					LeftHip = { rot = Vector3.new(14.5, 0, 1.6) },
				},
			},
			{
				time = 2.64,
				pose = {
					Root = {
						rot = Vector3.new(10.72, 23.52, -4.46),
						pos = Vector3.new(0.096, -0.159, 0.392),
					},
					Neck = { rot = Vector3.new(-4.081, -17.167, 0) },
					RightShoulder = { rot = Vector3.new(109.6, 0, -6.4) },
					LeftShoulder = { rot = Vector3.new(72.1, 0, 19.8) },
					RightHip = { rot = Vector3.new(-35.6, 0, 0.7) },
					LeftHip = { rot = Vector3.new(13.1, 0, 1.5) },
				},
			},
			{
				time = 2.7,
				pose = {
					Root = {
						rot = Vector3.new(9.75, 22.45, -4.01),
						pos = Vector3.new(0.09, -0.172, 0.379),
					},
					Neck = { rot = Vector3.new(-1.15, -15.887, 0) },
					RightShoulder = { rot = Vector3.new(105.8, 0, -3.4) },
					LeftShoulder = { rot = Vector3.new(68, 0, 18.9) },
					RightHip = { rot = Vector3.new(-34.7, 0, 1.1) },
					LeftHip = { rot = Vector3.new(13.8, 0, 1.3) },
				},
			},
			{
				time = 2.76,
				pose = {
					Root = {
						rot = Vector3.new(7.48, 21.2, -3.08),
						pos = Vector3.new(0.082, -0.189, 0.363),
					},
					Neck = { rot = Vector3.new(2.564, -14.252, 0) },
					RightShoulder = { rot = Vector3.new(99.1, 0, 2.7) },
					LeftShoulder = { rot = Vector3.new(63, 0, 18) },
					RightHip = { rot = Vector3.new(-32.2, 0, 1.5) },
					LeftHip = { rot = Vector3.new(16.2, 0, 0.9), pos = Vector3.new(0, 0.01, 0) },
				},
			},
			{
				time = 2.82,
				pose = {
					Root = {
						rot = Vector3.new(4.35, 19.78, -1.88),
						pos = Vector3.new(0.073, -0.207, 0.346),
					},
					Neck = { rot = Vector3.new(6.597, -12.453, 0) },
					RightShoulder = { rot = Vector3.new(85.5, 0, 12.6) },
					LeftShoulder = { rot = Vector3.new(57.4, 0, 17.1) },
					RightHip = { rot = Vector3.new(-27.6, 0, 2.3), pos = Vector3.new(0, 0.059, 0) },
					LeftHip = { rot = Vector3.new(19.6, 0, 0.3), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 2.88,
				pose = {
					Root = {
						rot = Vector3.new(0.77, 18.21, -0.59),
						pos = Vector3.new(0.064, -0.225, 0.328),
					},
					Neck = { rot = Vector3.new(10.489, -10.683, 0) },
					RightShoulder = { rot = Vector3.new(62.7, 0, 22) },
					LeftShoulder = { rot = Vector3.new(52.2, 0, 16.3) },
					RightHip = { rot = Vector3.new(-22.6, 0, 2.9), pos = Vector3.new(0, 0.106, 0) },
					LeftHip = { rot = Vector3.new(23.5, 0, -0.4), pos = Vector3.new(0, 0.048, 0) },
				},
			},
			{
				time = 2.94,
				pose = {
					Root = {
						rot = Vector3.new(-2.87, 16.56, 0.61),
						pos = Vector3.new(0.056, -0.24, 0.312),
					},
					Neck = { rot = Vector3.new(13.777, -9.135, 0) },
					RightShoulder = { rot = Vector3.new(42.6, 0, 24.7) },
					LeftShoulder = { rot = Vector3.new(48.5, 0, 15.5) },
					RightHip = { rot = Vector3.new(-17.5, 0, 3.3), pos = Vector3.new(0, 0.142, 0) },
					LeftHip = { rot = Vector3.new(27.7, 0, -1.1), pos = Vector3.new(0, 0.059, 0) },
				},
			},
			{
				time = 3,
				pose = {
					Root = {
						rot = Vector3.new(-6.21, 14.92, 1.6),
						pos = Vector3.new(0.05, -0.25, 0.3),
					},
					Neck = { rot = Vector3.new(16, -8, 0) },
					RightShoulder = { rot = Vector3.new(37.5, 0, 24.3) },
					LeftShoulder = { rot = Vector3.new(47.7, 0, 14.5) },
					RightHip = { rot = Vector3.new(-12.7, 0, 3.7), pos = Vector3.new(0, 0.166, 0) },
					LeftHip = { rot = Vector3.new(31.6, 0, -2), pos = Vector3.new(0, 0.063, 0) },
				},
			},
			{
				time = 3.06,
				pose = {
					Root = {
						rot = Vector3.new(-8.96, 13.37, 2.31),
						pos = Vector3.new(0.045, -0.257, 0.29),
					},
					Neck = { rot = Vector3.new(17.475, -7.132, 0) },
					RightShoulder = { rot = Vector3.new(39.9, 0, 23.5) },
					LeftShoulder = { rot = Vector3.new(48.2, 0, 13.4) },
					RightHip = { rot = Vector3.new(-8.7, 0, 4), pos = Vector3.new(0, 0.206, 0) },
					LeftHip = { rot = Vector3.new(34.8, 0, -2.7), pos = Vector3.new(0, 0.063, 0) },
				},
			},
			{
				time = 3.12,
				pose = {
					Root = {
						rot = Vector3.new(-11.12, 11.96, 2.77),
						pos = Vector3.new(0.04, -0.263, 0.28),
					},
					Neck = { rot = Vector3.new(18.827, -6.266, 0) },
					RightShoulder = { rot = Vector3.new(40.1, 0, 21.6) },
					LeftShoulder = { rot = Vector3.new(47.8, 0, 12.5) },
					RightHip = { rot = Vector3.new(-5.4, 0, 4.1), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(37.2, 0, -3.3), pos = Vector3.new(0, 0.065, 0) },
				},
			},
			{
				time = 3.18,
				pose = {
					Root = {
						rot = Vector3.new(-12.75, 10.69, 3.02),
						pos = Vector3.new(0.035, -0.269, 0.27),
					},
					Neck = { rot = Vector3.new(20.059, -5.41, 0) },
					RightShoulder = { rot = Vector3.new(38.9, 0, 18.9) },
					LeftShoulder = { rot = Vector3.new(46.6, 0, 11.8) },
					RightHip = { rot = Vector3.new(-2.7, 0, 4.2), pos = Vector3.new(0, 0.271, 0) },
					LeftHip = { rot = Vector3.new(38.9, 0, -3.6), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 3.24,
				pose = {
					Root = {
						rot = Vector3.new(-13.91, 9.58, 3.11),
						pos = Vector3.new(0.03, -0.275, 0.26),
					},
					Neck = { rot = Vector3.new(21.171, -4.579, 0) },
					RightShoulder = { rot = Vector3.new(36.7, 0, 15.6) },
					LeftShoulder = { rot = Vector3.new(44.6, 0, 11.4) },
					RightHip = { rot = Vector3.new(-0.5, 0, 4.2), pos = Vector3.new(0, 0.298, 0) },
					LeftHip = { rot = Vector3.new(39.8, 0, -3.8), pos = Vector3.new(0, 0.078, 0) },
				},
			},
			{
				time = 3.3,
				pose = {
					Root = {
						rot = Vector3.new(-14.64, 8.61, 3.07),
						pos = Vector3.new(0.025, -0.28, 0.25),
					},
					Neck = { rot = Vector3.new(22.164, -3.781, 0) },
					RightShoulder = { rot = Vector3.new(33.9, 0, 12) },
					LeftShoulder = { rot = Vector3.new(42.1, 0, 11.2) },
					RightHip = { rot = Vector3.new(1.2, 0, 4.2), pos = Vector3.new(0, 0.32, 0) },
					LeftHip = { rot = Vector3.new(40.2, 0, -3.9), pos = Vector3.new(0, 0.088, 0) },
				},
			},
			{
				time = 3.36,
				pose = {
					Root = {
						rot = Vector3.new(-14.99, 7.78, 2.94),
						pos = Vector3.new(0.02, -0.284, 0.24),
					},
					Neck = { rot = Vector3.new(23.04, -3.03, 0) },
					RightShoulder = { rot = Vector3.new(30.8, 0, 8.3) },
					LeftShoulder = { rot = Vector3.new(39.2, 0, 11.3) },
					RightHip = { rot = Vector3.new(2.4, 0, 4.2), pos = Vector3.new(0, 0.336, 0) },
					LeftHip = { rot = Vector3.new(40, 0, -3.8), pos = Vector3.new(0, 0.099, 0) },
				},
			},
			{
				time = 3.42,
				pose = {
					Root = {
						rot = Vector3.new(-15.01, 7.07, 2.73),
						pos = Vector3.new(0.016, -0.288, 0.231),
					},
					Neck = { rot = Vector3.new(23.801, -2.336, 0) },
					RightShoulder = { rot = Vector3.new(27.9, 0, 4.8) },
					LeftShoulder = { rot = Vector3.new(36.1, 0, 11.5) },
					RightHip = { rot = Vector3.new(3.2, 0, 4.2), pos = Vector3.new(0, 0.347, 0) },
					LeftHip = { rot = Vector3.new(39.4, 0, -3.6), pos = Vector3.new(0, 0.111, 0) },
				},
			},
			{
				time = 3.48,
				pose = {
					Root = {
						rot = Vector3.new(-14.74, 6.49, 2.48),
						pos = Vector3.new(0.011, -0.292, 0.223),
					},
					Neck = { rot = Vector3.new(24.446, -1.71, 0) },
					RightShoulder = { rot = Vector3.new(25.1, 0, 1.7) },
					LeftShoulder = { rot = Vector3.new(33.1, 0, 12) },
					RightHip = { rot = Vector3.new(3.7, 0, 4.2), pos = Vector3.new(0, 0.353, 0) },
					LeftHip = { rot = Vector3.new(38.5, 0, -3.2), pos = Vector3.new(0, 0.124, 0) },
				},
			},
			{
				time = 3.54,
				pose = {
					Root = {
						rot = Vector3.new(-14.22, 6.01, 2.18),
						pos = Vector3.new(0.008, -0.294, 0.216),
					},
					Neck = { rot = Vector3.new(24.978, -1.164, 0) },
					RightShoulder = { rot = Vector3.new(22.7, 0, -0.9) },
					LeftShoulder = { rot = Vector3.new(30.2, 0, 12.4) },
					RightHip = { rot = Vector3.new(3.8, 0, 4.1), pos = Vector3.new(0, 0.352, 0) },
					LeftHip = { rot = Vector3.new(37.3, 0, -2.9), pos = Vector3.new(0, 0.135, 0) },
				},
			},
			{
				time = 3.6,
				pose = {
					Root = {
						rot = Vector3.new(-13.48, 5.63, 1.87),
						pos = Vector3.new(0.005, -0.297, 0.21),
					},
					Neck = { rot = Vector3.new(25.398, -0.71, 0) },
					RightShoulder = { rot = Vector3.new(20.5, 0, -3) },
					LeftShoulder = { rot = Vector3.new(27.6, 0, 12.9) },
					RightHip = { rot = Vector3.new(3.5, 0, 4.2), pos = Vector3.new(0, 0.346, 0) },
					LeftHip = { rot = Vector3.new(35.8, 0, -2.5), pos = Vector3.new(0, 0.147, 0) },
				},
			},
			{
				time = 3.66,
				pose = {
					Root = {
						rot = Vector3.new(-12.58, 5.33, 1.55),
						pos = Vector3.new(0.002, -0.298, 0.205),
					},
					Neck = { rot = Vector3.new(25.706, -0.358, 0) },
					RightShoulder = { rot = Vector3.new(18.7, 0, -4.5) },
					LeftShoulder = { rot = Vector3.new(25.3, 0, 13.4) },
					RightHip = { rot = Vector3.new(3, 0, 4.3), pos = Vector3.new(0, 0.335, 0) },
					LeftHip = { rot = Vector3.new(34.2, 0, -2.1), pos = Vector3.new(0, 0.156, 0) },
				},
			},
			{
				time = 3.72,
				pose = {
					Root = {
						rot = Vector3.new(-11.55, 5.11, 1.25),
						pos = Vector3.new(0.001, -0.299, 0.202),
					},
					Neck = { rot = Vector3.new(25.904, -0.12, 0) },
					RightShoulder = { rot = Vector3.new(17.3, 0, -5.5) },
					LeftShoulder = { rot = Vector3.new(23.5, 0, 13.8) },
					RightHip = { rot = Vector3.new(2.1, 0, 4.4), pos = Vector3.new(0, 0.319, 0) },
					LeftHip = { rot = Vector3.new(32.5, 0, -1.9), pos = Vector3.new(0, 0.166, 0) },
				},
			},
			{
				time = 3.78,
				pose = {
					Root = {
						rot = Vector3.new(-10.42, 4.96, 0.96),
						pos = Vector3.new(0, -0.3, 0.2),
					},
					Neck = { rot = Vector3.new(25.994, -0.008, 0) },
					RightShoulder = { rot = Vector3.new(16.3, 0, -5.9) },
					LeftShoulder = { rot = Vector3.new(22.1, 0, 14) },
					RightHip = { rot = Vector3.new(0.9, 0, 4.5), pos = Vector3.new(0, 0.302, 0) },
					LeftHip = { rot = Vector3.new(30.7, 0, -1.6), pos = Vector3.new(0, 0.175, 0) },
				},
			},
			{
				time = 3.8,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-10.04, 4.92, 0.87),
						pos = Vector3.new(0, -0.3, 0.2),
					},
					Neck = { rot = Vector3.new(26, 0, 0) },
					RightShoulder = { rot = Vector3.new(16.2, 0, -5.9) },
					LeftShoulder = { rot = Vector3.new(21.8, 0, 14) },
					RightHip = { rot = Vector3.new(0.5, 0, 4.6), pos = Vector3.new(0, 0.295, 0) },
					LeftHip = { rot = Vector3.new(30.2, 0, -1.5), pos = Vector3.new(0, 0.177, 0) },
				},
			},
			{
				time = 3.84,
				pose = {
					Root = {
						rot = Vector3.new(-9.25, 4.87, 0.7),
						pos = Vector3.new(0, -0.297, 0.199),
					},
					Neck = { rot = Vector3.new(25.783, -0.037, 0) },
					RightShoulder = { rot = Vector3.new(16.9, 0, -6) },
					LeftShoulder = { rot = Vector3.new(22.4, 0, 14.3) },
					RightHip = { rot = Vector3.new(-0.6, 0, 4.7), pos = Vector3.new(0, 0.322, 0) },
					LeftHip = { rot = Vector3.new(28.9, 0, -1.5), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 3.9,
				pose = {
					Root = {
						rot = Vector3.new(-8.08, 4.79, 0.49),
						pos = Vector3.new(0, -0.285, 0.194),
					},
					Neck = { rot = Vector3.new(24.736, -0.2, 0) },
					RightShoulder = { rot = Vector3.new(21.4, 0, -6.6) },
					LeftShoulder = { rot = Vector3.new(27.1, 0, 15.6) },
					RightHip = { rot = Vector3.new(-1.6, 0, 4.7), pos = Vector3.new(0, 0.351, 0) },
					LeftHip = { rot = Vector3.new(26.8, 0, -1.4), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 3.96,
				pose = {
					Root = {
						rot = Vector3.new(-6.96, 4.66, 0.3),
						pos = Vector3.new(0, -0.265, 0.185),
					},
					Neck = { rot = Vector3.new(23.004, -0.435, 0) },
					RightShoulder = { rot = Vector3.new(29.7, 0, -8) },
					LeftShoulder = { rot = Vector3.new(35.8, 0, 17.7) },
					RightHip = { rot = Vector3.new(-2.1, 0, 4.5), pos = Vector3.new(0, 0.365, 0) },
					LeftHip = { rot = Vector3.new(24.5, 0, -1.4), pos = Vector3.new(0, 0.174, 0) },
				},
			},
			{
				time = 4.02,
				pose = {
					Root = {
						rot = Vector3.new(-5.93, 4.42, 0.15),
						pos = Vector3.new(0, -0.238, 0.173),
					},
					Neck = { rot = Vector3.new(20.788, -0.678, 0) },
					RightShoulder = { rot = Vector3.new(40.8, 0, -10.4) },
					LeftShoulder = { rot = Vector3.new(47.1, 0, 20.4) },
					RightHip = { rot = Vector3.new(-2.2, 0, 4.2), pos = Vector3.new(0, 0.358, 0) },
					LeftHip = { rot = Vector3.new(22.2, 0, -1.4), pos = Vector3.new(0, 0.162, 0) },
				},
			},
			{
				time = 4.08,
				pose = {
					Root = {
						rot = Vector3.new(-5.06, 4.01, 0.05),
						pos = Vector3.new(0, -0.208, 0.158),
					},
					Neck = { rot = Vector3.new(18.292, -0.862, 0) },
					RightShoulder = { rot = Vector3.new(52.7, 0, -13.6) },
					LeftShoulder = { rot = Vector3.new(58.8, 0, 22.8) },
					RightHip = { rot = Vector3.new(-2, 0, 3.8), pos = Vector3.new(0, 0.331, 0) },
					LeftHip = { rot = Vector3.new(19.9, 0, -1.6), pos = Vector3.new(0, 0.148, 0) },
				},
			},
			{
				time = 4.14,
				pose = {
					Root = {
						rot = Vector3.new(-4.39, 3.36, -0.02),
						pos = Vector3.new(0, -0.176, 0.143),
					},
					Neck = { rot = Vector3.new(15.716, -0.925, 0) },
					RightShoulder = { rot = Vector3.new(62.7, 0, -17) },
					LeftShoulder = { rot = Vector3.new(68.5, 0, 24.4) },
					RightHip = { rot = Vector3.new(-1.6, 0, 3.5), pos = Vector3.new(0, 0.286, 0) },
					LeftHip = { rot = Vector3.new(17.8, 0, -1.8), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 4.2,
				pose = {
					Root = {
						rot = Vector3.new(-3.98, 2.42, -0.04),
						pos = Vector3.new(0, -0.145, 0.126),
					},
					Neck = { rot = Vector3.new(13.264, -0.8, 0) },
					RightShoulder = { rot = Vector3.new(69.6, 0, -19.9) },
					LeftShoulder = { rot = Vector3.new(75.1, 0, 24.9) },
					RightHip = { rot = Vector3.new(-1, 0, 3.2), pos = Vector3.new(0, 0.227, 0) },
					LeftHip = { rot = Vector3.new(16.1, 0, -2.1), pos = Vector3.new(0, 0.113, 0) },
				},
			},
			{
				time = 4.26,
				pose = {
					Root = {
						rot = Vector3.new(-3.88, 1.11, -0.03),
						pos = Vector3.new(0, -0.116, 0.11),
					},
					Neck = { rot = Vector3.new(11.137, -0.423, 0) },
					RightShoulder = { rot = Vector3.new(73.1, 0, -22.2) },
					LeftShoulder = { rot = Vector3.new(78.3, 0, 24.4) },
					RightHip = { rot = Vector3.new(-0.4, 0, 2.9), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(14.9, 0, -2.5), pos = Vector3.new(0, 0.096, 0) },
				},
			},
			{
				time = 4.3,
				pose = {
					Root = { rot = Vector3.new(-4, 0, 0), pos = Vector3.new(0, -0.1, 0.1) },
					Neck = { rot = Vector3.new(10, 0, 0) },
					RightShoulder = { rot = Vector3.new(73.5, 0, -23.4) },
					LeftShoulder = { rot = Vector3.new(78.3, 0, 23.6) },
					RightHip = { rot = Vector3.new(0.1, 0, 2.8), pos = Vector3.new(0, 0.115, 0) },
					LeftHip = { rot = Vector3.new(14.4, 0, -2.8), pos = Vector3.new(0, 0.087, 0) },
				},
			},
			{
				time = 4.32,
				pose = {
					Root = {
						rot = Vector3.new(-4.12, -0.63, 0.02),
						pos = Vector3.new(0, -0.092, 0.094),
					},
					Neck = { rot = Vector3.new(9.513, 0.345, 0) },
					RightShoulder = { rot = Vector3.new(73.8, 0, -24.3) },
					LeftShoulder = { rot = Vector3.new(78.5, 0, 23.3) },
					RightHip = { rot = Vector3.new(0.4, 0, 2.8), pos = Vector3.new(0, 0.107, 0) },
					LeftHip = { rot = Vector3.new(14.1, 0, -3), pos = Vector3.new(0, 0.083, 0) },
				},
			},
			{
				time = 4.38,
				pose = {
					Root = {
						rot = Vector3.new(-4.71, -2.78, 0.07),
						pos = Vector3.new(0, -0.066, 0.072),
					},
					Neck = { rot = Vector3.new(8.223, 2.292, 0) },
					RightShoulder = { rot = Vector3.new(80.6, 0, -28.6) },
					LeftShoulder = { rot = Vector3.new(85.1, 0, 25.3) },
					RightHip = { rot = Vector3.new(2.2, 0, 2.2), pos = Vector3.new(0, 0.075, 0) },
					LeftHip = { rot = Vector3.new(13.3, 0, -3.1), pos = Vector3.new(0, 0.067, 0) },
				},
			},
			{
				time = 4.44,
				pose = {
					Root = {
						rot = Vector3.new(-5.53, -5.21, 0.1),
						pos = Vector3.new(0, -0.04, 0.045),
					},
					Neck = { rot = Vector3.new(7.204, 4.999, 0) },
					RightShoulder = { rot = Vector3.new(92, 0, -33.2) },
					LeftShoulder = { rot = Vector3.new(97.2, 0, 30) },
					RightHip = { rot = Vector3.new(5, 0, 0), pos = Vector3.new(0, 0.029, 0) },
					LeftHip = { rot = Vector3.new(12.6, 0, -2.6) },
				},
			},
			{
				time = 4.5,
				pose = {
					Root = {
						rot = Vector3.new(-6.47, -7.78, 0.1),
						pos = Vector3.new(0, -0.018, 0.02),
					},
					Neck = { rot = Vector3.new(6.481, 7.685, 0) },
					RightShoulder = { rot = Vector3.new(102.8, 0, -35.8) },
					LeftShoulder = { rot = Vector3.new(108, 0, 34.2) },
					RightHip = { rot = Vector3.new(7.9, 0, -0.3) },
					LeftHip = { rot = Vector3.new(11.8, 0, -2.4) },
				},
			},
			{
				time = 4.56,
				pose = {
					Root = {
						rot = Vector3.new(-7.42, -10.36, 0.05),
						pos = Vector3.new(0, -0.003, 0.004),
					},
					Neck = { rot = Vector3.new(6.079, 9.572, 0) },
					RightShoulder = { rot = Vector3.new(109.6, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(113.9, 0, 36.5) },
					RightHip = { rot = Vector3.new(10.5, 0, -1.4) },
					LeftHip = { rot = Vector3.new(11.3, 0, -2.5), pos = Vector3.new(0, 0.023, 0) },
				},
			},
			{
				time = 4.6,
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
