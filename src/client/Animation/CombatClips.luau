--!strict
-- Combat animations, made IN CODE (same system as MovementClips: read the
-- explanation at the top of that file).
--
-- Who plays them: CharacterAnimationController, on EVERY fighter (players
-- and training dummies), on every client.
--   • M1 / dashes: your own instantly (CombatController), the others when
--     the server tells everyone (Remotes.CombatAction).
--   • Guard / Block / Stunned: loops that follow the fighter's state.
--   • Reactions (HitJab, HitCross, HitHook, HitHeavy, HitBack, HitBody*,
--     BlockHit, Parry, GuardBreak): Remotes.CombatEvent. The reaction played
--     depends on WHERE the hit lands (head / body) and from WHICH SIDE of the
--     victim (front / back / left / right): see CombatEffectsController.
--   • Reactions start with a "contact" keyframe close to the pose the
--     victim was in: at the moment of impact the body takes the hit
--     (folds around it) before being thrown, it never moves out of the way.
--
-- How they were made: each clip was authored and reviewed against rendered
-- filmstrips of the R6 rig (side / back / front views, 30 and 60 images per
-- second) using the same spline as the game, checking anticipation, weight
-- shift, follow-through, that the head stays on target and that the feet
-- stay on the ground.
--
-- Timing that must not change:
--   • the M1 impact keyframe is at 0.15 s = Config.Combat.HIT_DELAY (when
--     the server checks the hitbox);
--   • every punch starts and ends in the Guard pose, so combos chain.
-- `tangent = "flat"` on a keyframe = the motion stops there (see R6Pose).

local R6Pose = require(script.Parent.R6Pose)

local clips: { [string]: R6Pose.Clip } = {
	-- High guard held for a few seconds after a punch or a hit: fists in front of the
	-- face (left one slightly further out), torso turned, slow weight shift and breathing.
	-- Upper body only (the legs keep walking).
	-- Its first keyframe is the pose every punch starts from and returns to.
	Guard = {
		length = 1.6,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(130.5, 0, -50.1) },
					LeftShoulder = { rot = Vector3.new(126, 0, 37.9) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-9.5, -9, 1.5), pos = Vector3.new(0, -0.04, 0) },
					Neck = { rot = Vector3.new(7, 7, 0) },
					RightShoulder = { rot = Vector3.new(133, 0, -50.1) },
					LeftShoulder = { rot = Vector3.new(124.5, 0, 37.9) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = { rot = Vector3.new(-7.5, -12, 0) },
					Neck = { rot = Vector3.new(5.5, 10, 0) },
					RightShoulder = { rot = Vector3.new(129.5, 0, -50.1) },
					LeftShoulder = { rot = Vector3.new(128, 0, 37.9) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = { rot = Vector3.new(-9.5, -15, -1.5), pos = Vector3.new(0, -0.04, 0) },
					Neck = { rot = Vector3.new(7, 13, 0) },
					RightShoulder = { rot = Vector3.new(128.5, 0, -50.1) },
					LeftShoulder = { rot = Vector3.new(128.5, 0, 37.9) },
				},
			},
		},
	},

	-- Left jab (combo hit 1): the lead hand snaps out from the guard and back.
	-- Impact at 0.15 s = Config.Combat.HIT_DELAY.
	Brawler_M1_1 = {
		length = 0.5,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(130.5, 0, -50.1) },
					LeftShoulder = { rot = Vector3.new(126, 0, 37.9) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.04,
				pose = {
					Root = { rot = Vector3.new(-5, -7, -1.5), pos = Vector3.new(0.03, -0.05, 0.07) },
					Neck = { rot = Vector3.new(4, 6, 0.5) },
					RightShoulder = { rot = Vector3.new(131.5, 0, -51.1) },
					LeftShoulder = { rot = Vector3.new(120, 0, 40.9) },
					RightHip = {
						rot = Vector3.new(-4.61, -2.5, 1.57),
						pos = Vector3.new(0, 0.14, 0),
					},
					LeftHip = {
						rot = Vector3.new(-0.89, -2.5, 1.74),
						pos = Vector3.new(0, 0.07, 0),
					},
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-10, -24, 1.5),
						pos = Vector3.new(-0.06, -0.1, -0.17),
					},
					Neck = { rot = Vector3.new(6, 17, -1) },
					RightShoulder = { rot = Vector3.new(133.5, 0, -53.1) },
					LeftShoulder = {
						rot = Vector3.new(132.47, 0, 32.9),
						pos = Vector3.new(0, 0, -0.04),
					},
					RightHip = { rot = Vector3.new(2.8, 6, 0.07), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(-2.72, 6, -1.11), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = {
						rot = Vector3.new(-14, -36, 2.5),
						pos = Vector3.new(-0.1, -0.17, -0.38),
					},
					Neck = { rot = Vector3.new(8.5, 31, -2) },
					RightShoulder = { rot = Vector3.new(134.5, 0, -54.1) },
					LeftShoulder = {
						rot = Vector3.new(138.2, 0, 25.8),
						pos = Vector3.new(0, -0.03, -0.25),
					},
					RightHip = { rot = Vector3.new(7.45, 12, -0.52), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(-2.81, 12, -3.43), pos = Vector3.new(0, 0.44, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = {
						rot = Vector3.new(-15, -35, 3),
						pos = Vector3.new(-0.12, -0.21, -0.46),
					},
					Neck = { rot = Vector3.new(9.5, 30, -2.5) },
					RightShoulder = { rot = Vector3.new(134.5, 0, -54.1) },
					LeftShoulder = {
						rot = Vector3.new(130.4, 0, 19.6),
						pos = Vector3.new(0, -0.05, -0.45),
					},
					RightHip = {
						rot = Vector3.new(5.82, 11.5, 0.34),
						pos = Vector3.new(0, 0.17, 0),
					},
					LeftHip = {
						rot = Vector3.new(-0.96, 11.5, -4.66),
						pos = Vector3.new(0, 0.45, 0),
					},
				},
			},
			{
				time = 0.23,
				pose = {
					Root = {
						rot = Vector3.new(-15.5, -32, 3),
						pos = Vector3.new(-0.13, -0.24, -0.51),
					},
					Neck = { rot = Vector3.new(10, 27.5, -2.5) },
					RightShoulder = { rot = Vector3.new(134.5, 0, -54.1) },
					LeftShoulder = {
						rot = Vector3.new(129, 0, 20.1),
						pos = Vector3.new(0, -0.05, -0.45),
					},
					RightHip = { rot = Vector3.new(4.31, 10, 0.96), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-0.14, 10, -4.19), pos = Vector3.new(0, 0.46, 0) },
				},
			},
			{
				time = 0.29,
				pose = {
					Root = {
						rot = Vector3.new(-11, -19, 2.5),
						pos = Vector3.new(-0.09, -0.17, -0.3),
					},
					Neck = { rot = Vector3.new(7, 15, -2) },
					RightShoulder = { rot = Vector3.new(132.5, 0, -52.1) },
					LeftShoulder = {
						rot = Vector3.new(133.79, 0, 39.2),
						pos = Vector3.new(0, -0.03, -0.29),
					},
					RightHip = { rot = Vector3.new(-1.77, 3.5, 0.6), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(4.24, 3.5, -4.34), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.35,
				pose = {
					Root = { rot = Vector3.new(-6, -9, -0.8), pos = Vector3.new(0, -0.05, 0.03) },
					Neck = { rot = Vector3.new(4.5, 7, 0.5) },
					RightShoulder = { rot = Vector3.new(129.5, 0, -49.1) },
					LeftShoulder = {
						rot = Vector3.new(124.47, 0, 38.2),
						pos = Vector3.new(0, -0.01, -0.12),
					},
					RightHip = {
						rot = Vector3.new(-3.49, -1.5, 1.51),
						pos = Vector3.new(0, 0.13, 0),
					},
					LeftHip = { rot = Vector3.new(0.9, -1.5, 1.21), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-8.7, -13.2, 0.3),
						pos = Vector3.new(-0.01, -0.03, -0.01),
					},
					Neck = { rot = Vector3.new(6.3, 10.8, 0) },
					RightShoulder = { rot = Vector3.new(130.9, 0, -50.4) },
					LeftShoulder = { rot = Vector3.new(125.6, 0, 37.7) },
					RightHip = {
						rot = Vector3.new(0.85, 0.6, -0.24),
						pos = Vector3.new(0, 0.06, 0),
					},
					LeftHip = { rot = Vector3.new(-0.5, 0.6, -0.12), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(130.5, 0, -50.1) },
					LeftShoulder = { rot = Vector3.new(126, 0, 37.9) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Right cross (combo hit 2): rear hip and shoulder drive through, weight onto the lead leg.
	Brawler_M1_2 = {
		length = 0.5,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(130.5, 0, -50.1) },
					LeftShoulder = { rot = Vector3.new(126, 0, 37.9) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(-6, -22, -3), pos = Vector3.new(0.06, -0.09, 0.09) },
					Neck = { rot = Vector3.new(5, 18, 2) },
					RightShoulder = { rot = Vector3.new(132.6, 0, -53.9) },
					LeftShoulder = { rot = Vector3.new(125.2, 0, 33) },
					RightHip = { rot = Vector3.new(-0.3, -7, 2.7), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(-5.4, 4, 3.3), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.09,
				pose = {
					Root = { rot = Vector3.new(-10, 4, 1), pos = Vector3.new(0.02, -0.15, -0.1) },
					Neck = { rot = Vector3.new(7, -2, 0) },
					RightShoulder = { rot = Vector3.new(139.1, 0, -40.9) },
					LeftShoulder = { rot = Vector3.new(130.3, 0, 47.4) },
					RightHip = { rot = Vector3.new(-2.4, 6, -2.6), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(5.6, -3, -1.3), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-13, 30, 3), pos = Vector3.new(-0.03, -0.2, -0.25) },
					Neck = { rot = Vector3.new(9, -24, -1) },
					RightShoulder = {
						rot = Vector3.new(138.08, 0, -19.2),
						pos = Vector3.new(0, -0.03, -0.23),
					},
					LeftShoulder = { rot = Vector3.new(140, 0, 58.6) },
					RightHip = { rot = Vector3.new(-4.5, 15, -7.7), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(14.3, -11, 2.3), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(-14, 40, 4), pos = Vector3.new(-0.06, -0.22, -0.34) },
					Neck = { rot = Vector3.new(10, -33, -3) },
					RightShoulder = {
						rot = Vector3.new(124.6, 0, 1.7),
						pos = Vector3.new(0, -0.05, -0.45),
					},
					LeftShoulder = { rot = Vector3.new(144, 0, 62) },
					RightHip = { rot = Vector3.new(-4.8, 19, -11.4), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(16.1, -15, 3.8), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = { rot = Vector3.new(-15, 39, 5), pos = Vector3.new(-0.08, -0.25, -0.46) },
					Neck = { rot = Vector3.new(11, -32, -3) },
					RightShoulder = {
						rot = Vector3.new(124, 0, 2.1),
						pos = Vector3.new(0, -0.05, -0.45),
					},
					LeftShoulder = { rot = Vector3.new(144.5, 0, 61.8) },
					RightHip = { rot = Vector3.new(-5.7, 20, -13.8), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(13.8, -16, 1.6), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.29,
				pose = {
					Root = { rot = Vector3.new(-12, 25, 3), pos = Vector3.new(-0.05, -0.18, -0.26) },
					Neck = { rot = Vector3.new(9, -21, -2) },
					RightShoulder = {
						rot = Vector3.new(129.34, 0, -18.5),
						pos = Vector3.new(0, -0.03, -0.3),
					},
					LeftShoulder = { rot = Vector3.new(137.9, 0, 57.4) },
					RightHip = { rot = Vector3.new(-5, 14, -6.6), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(12, -11, 1.3), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.34,
				pose = {
					Root = { rot = Vector3.new(-9, 2, 0), pos = Vector3.new(-0.01, -0.1, -0.1) },
					Neck = { rot = Vector3.new(6, -1, 0) },
					RightShoulder = {
						rot = Vector3.new(130.63, 0, -50),
						pos = Vector3.new(0, -0.01, -0.13),
					},
					LeftShoulder = { rot = Vector3.new(129.1, 0, 46.5) },
					RightHip = { rot = Vector3.new(-3.2, 5, -0.2), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(4, -4, 1), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-5, -17, -1.5), pos = Vector3.new(0.03, 0.01, 0.04) },
					Neck = { rot = Vector3.new(4, 14, 1) },
					RightShoulder = {
						rot = Vector3.new(130.38, 0, -51),
						pos = Vector3.new(0, 0, -0.03),
					},
					LeftShoulder = { rot = Vector3.new(124, 0, 35.8) },
					RightHip = { rot = Vector3.new(-2.9, -3, 2.3), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(-5.6, 2, 2.5), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = {
						rot = Vector3.new(-8.6, -10.5, 0.4),
						pos = Vector3.new(0, -0.03, -0.01),
					},
					Neck = { rot = Vector3.new(6.4, 8.8, 0) },
					RightShoulder = { rot = Vector3.new(130, 0, -49.6) },
					LeftShoulder = { rot = Vector3.new(126.7, 0, 38.8) },
					RightHip = { rot = Vector3.new(-0.1, 0, -0.6), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(0.6, 0, -0.6), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(130.5, 0, -50.1) },
					LeftShoulder = { rot = Vector3.new(126, 0, 37.9) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Left hook (combo hit 3): the arm winds out and whips across while the torso turns.
	Brawler_M1_3 = {
		length = 0.5,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(130.5, 0, -50.1) },
					LeftShoulder = { rot = Vector3.new(126, 0, 37.9) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.04,
				pose = {
					Root = { rot = Vector3.new(-10, -2, 4), pos = Vector3.new(-0.04, -0.18, 0.02) },
					Neck = { rot = Vector3.new(6, 1, -3) },
					RightShoulder = { rot = Vector3.new(131.2, 0, -47) },
					LeftShoulder = { rot = Vector3.new(135.9, 0, 30.7) },
					RightHip = { rot = Vector3.new(-1.4, -4, -4.8), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(5.7, -4, -4.2), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.09,
				pose = {
					Root = { rot = Vector3.new(-11, 4, 8), pos = Vector3.new(-0.06, -0.26, -0.02) },
					Neck = { rot = Vector3.new(7, -6, -6) },
					RightShoulder = { rot = Vector3.new(132.9, 0, -40.1) },
					LeftShoulder = { rot = Vector3.new(161.9, 0, -10.1) },
					RightHip = { rot = Vector3.new(-4.9, -6, -9.8), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(6.9, -8, -8.2), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-13, -26, 3), pos = Vector3.new(-0.1, -0.24, -0.04) },
					Neck = { rot = Vector3.new(8, 18, -2) },
					RightShoulder = { rot = Vector3.new(133.3, 0, -56) },
					LeftShoulder = { rot = Vector3.new(174.9, 0, -15.3) },
					RightHip = { rot = Vector3.new(10.5, 4, -4.2), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(1.2, 10, -2.5), pos = Vector3.new(0, 0.43, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = {
						rot = Vector3.new(-14, -49, -2),
						pos = Vector3.new(-0.12, -0.22, -0.06),
					},
					Neck = { rot = Vector3.new(9, 37, 2) },
					RightShoulder = { rot = Vector3.new(137.5, 0, -68.1) },
					LeftShoulder = { rot = Vector3.new(130.2, 0, 0) },
					RightHip = { rot = Vector3.new(16.7, 6, -2), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(-4.9, 14, 4), pos = Vector3.new(0, 0.39, 0) },
				},
			},
			{
				time = 0.19,
				pose = {
					Root = {
						rot = Vector3.new(-15, -57, -4),
						pos = Vector3.new(-0.12, -0.21, -0.08),
					},
					Neck = { rot = Vector3.new(10, 43, 3) },
					RightShoulder = { rot = Vector3.new(140.4, 0, -72.1) },
					LeftShoulder = { rot = Vector3.new(123.7, 0, 32.1) },
					RightHip = { rot = Vector3.new(18.7, 7, -2.1), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(-8, 18, 6.4), pos = Vector3.new(0, 0.37, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-12, -41, -2),
						pos = Vector3.new(-0.08, -0.16, -0.04),
					},
					Neck = { rot = Vector3.new(8, 30, 2) },
					RightShoulder = { rot = Vector3.new(134.4, 0, -64.7) },
					LeftShoulder = { rot = Vector3.new(118, 0, 30) },
					RightHip = { rot = Vector3.new(12.6, 5, 0.2), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(-4.4, 13, 4), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.31,
				pose = {
					Root = { rot = Vector3.new(-9, -16, 0), pos = Vector3.new(0, -0.06, -0.06) },
					Neck = { rot = Vector3.new(6, 13, 0) },
					RightShoulder = { rot = Vector3.new(130.7, 0, -51.2) },
					LeftShoulder = { rot = Vector3.new(127, 0, 38) },
					RightHip = { rot = Vector3.new(0.6, 1, 0.1), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-1.7, 4, 0.6), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.38,
				pose = {
					Root = { rot = Vector3.new(-7, -7, 0.5), pos = Vector3.new(0, 0.02, 0.03) },
					Neck = { rot = Vector3.new(5.5, 7, 0) },
					RightShoulder = { rot = Vector3.new(130.5, 0, -49.6) },
					LeftShoulder = { rot = Vector3.new(125, 0, 37) },
					RightHip = { rot = Vector3.new(-2.3, -1, -0.7), pos = Vector3.new(0, 0.02, 0) },
					LeftHip = { rot = Vector3.new(1, -2, -0.6), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.44,
				pose = {
					Root = { rot = Vector3.new(-8.3, -13, 0), pos = Vector3.new(0, -0.01, -0.01) },
					Neck = { rot = Vector3.new(6.2, 10.8, 0) },
					RightShoulder = { rot = Vector3.new(130.5, 0, -50.1) },
					LeftShoulder = { rot = Vector3.new(126.3, 0, 38.1) },
					RightHip = { rot = Vector3.new(0.2, 0, 0), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(-0.4, 0, 0), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(130.5, 0, -50.1) },
					LeftShoulder = { rot = Vector3.new(126, 0, 37.9) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Overhand right (combo FINISHER): leans back, dives in, heavy follow-through and recovery.
	-- Longer than the others: see Config.Combat.FINISHER_RECOVERY.
	Brawler_M1_4 = {
		length = 0.85,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(130.5, 0, -50.1) },
					LeftShoulder = { rot = Vector3.new(126, 0, 37.9) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.04,
				pose = {
					Root = { rot = Vector3.new(5, -27, -9), pos = Vector3.new(0.13, -0.08, 0.15) },
					Neck = { rot = Vector3.new(-2, 21, 6) },
					RightShoulder = { rot = Vector3.new(152, 0, -18) },
					LeftShoulder = { rot = Vector3.new(113.8, 0, 34.5) },
					RightHip = { rot = Vector3.new(-10.6, -8, 14.7), pos = Vector3.new(0, 0.38, 0) },
					LeftHip = { rot = Vector3.new(-23.6, 4, 17), pos = Vector3.new(0, -0.09, 0) },
				},
			},
			{
				time = 0.09,
				pose = {
					Root = { rot = Vector3.new(9, -31, -11), pos = Vector3.new(0.18, -0.12, 0.22) },
					Neck = { rot = Vector3.new(-5, 25, 8) },
					RightShoulder = { rot = Vector3.new(151.8, 0, -26.8) },
					LeftShoulder = { rot = Vector3.new(109.2, 0, 34.9) },
					RightHip = {
						rot = Vector3.new(-12.3, -12, 18.2),
						pos = Vector3.new(0, 0.47, 0),
					},
					LeftHip = { rot = Vector3.new(-30.7, 4, 21.6), pos = Vector3.new(0, -0.16, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-11, 14, 2), pos = Vector3.new(0.02, -0.2, -0.3) },
					Neck = { rot = Vector3.new(5, -12, -2) },
					RightShoulder = { rot = Vector3.new(174.1, 0, -14.1) },
					LeftShoulder = { rot = Vector3.new(137.1, 0, 52.2) },
					RightHip = { rot = Vector3.new(-8.9, 10, -6.6), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(5.1, -6, -2.4), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(-16, 38, 6), pos = Vector3.new(-0.14, -0.3, -0.52) },
					Neck = { rot = Vector3.new(6, -32, -4) },
					RightShoulder = { rot = Vector3.new(135.3, 0, -8) },
					LeftShoulder = { rot = Vector3.new(148, 0, 59.3) },
					RightHip = { rot = Vector3.new(-9.1, 22, -17.2), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(12.6, -16, 1.2), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-20, 52, 8), pos = Vector3.new(-0.2, -0.36, -0.6) },
					Neck = { rot = Vector3.new(8, -42, -6) },
					RightShoulder = { rot = Vector3.new(103.1, 0, -28.7) },
					LeftShoulder = { rot = Vector3.new(153.9, 0, 62.1) },
					RightHip = { rot = Vector3.new(-5.9, 26, -24.5), pos = Vector3.new(0, 0.07, 0) },
					LeftHip = { rot = Vector3.new(16.7, -20, 5.2), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.27,
				pose = {
					Root = { rot = Vector3.new(-19, 47, 7), pos = Vector3.new(-0.2, -0.34, -0.56) },
					Neck = { rot = Vector3.new(8, -38, -5) },
					RightShoulder = { rot = Vector3.new(91.2, 0, -48.2) },
					LeftShoulder = { rot = Vector3.new(153, 0, 60.3) },
					RightHip = { rot = Vector3.new(-8, 24, -19.7), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(16.2, -18, 5.4), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = { rot = Vector3.new(-14, 28, 4), pos = Vector3.new(-0.12, -0.24, -0.38) },
					Neck = { rot = Vector3.new(10, -24, -3) },
					RightShoulder = { rot = Vector3.new(149.4, 0, -33.4) },
					LeftShoulder = { rot = Vector3.new(144.5, 0, 57.5) },
					RightHip = { rot = Vector3.new(-9.6, 16, -9), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(11.4, -12, 2), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.47,
				pose = {
					Root = { rot = Vector3.new(-11, 2, 1), pos = Vector3.new(-0.02, -0.08, -0.14) },
					Neck = { rot = Vector3.new(7, -2, 0) },
					RightShoulder = { rot = Vector3.new(133, 0, -50) },
					LeftShoulder = { rot = Vector3.new(129.8, 0, 46.4) },
					RightHip = { rot = Vector3.new(-2.5, 5, -1.4), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(5.8, -3, -0.1), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 0.59,
				pose = {
					Root = { rot = Vector3.new(-5, -18, -1.5), pos = Vector3.new(0.03, 0.02, 0.06) },
					Neck = { rot = Vector3.new(4, 15, 1) },
					RightShoulder = { rot = Vector3.new(131, 0, -51) },
					LeftShoulder = { rot = Vector3.new(124.1, 0, 35.3) },
					RightHip = { rot = Vector3.new(-2.1, -3, 2.2), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(-5.2, 2, 2.4), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.71,
				pose = {
					Root = {
						rot = Vector3.new(-8.8, -10.5, 0.4),
						pos = Vector3.new(0, -0.03, -0.02),
					},
					Neck = { rot = Vector3.new(6.4, 8.8, 0) },
					RightShoulder = { rot = Vector3.new(130, 0, -49.6) },
					LeftShoulder = { rot = Vector3.new(127, 0, 38.6) },
					RightHip = { rot = Vector3.new(-0.1, 0, -0.6), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(0.6, 0, -0.6), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.85,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(130.5, 0, -50.1) },
					LeftShoulder = { rot = Vector3.new(126, 0, 37.9) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Guard: forearms crossed in front of the face, chin down. Upper body only:
	-- the legs keep walking. Looped while the "Blocking" attribute is true.
	Block = {
		length = 1.2,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0) },
					Neck = { rot = Vector3.new(-8, 0, 0) },
					RightShoulder = { rot = Vector3.new(150, 0, -60.7) },
					LeftShoulder = { rot = Vector3.new(142.3, 0, 61) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(-8, 0, 0) },
					RightShoulder = { rot = Vector3.new(150, 0, -60.7) },
					LeftShoulder = { rot = Vector3.new(142.3, 0, 61) },
				},
			},
		},
	},

	-- A punch lands on the guard: driven back, absorbs, springs back. Starts and ends in the Block pose.
	BlockHit = {
		length = 0.32,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0) },
					Neck = { rot = Vector3.new(-8, 0, 0) },
					RightShoulder = { rot = Vector3.new(150, 0, -60.7) },
					LeftShoulder = { rot = Vector3.new(142.3, 0, 61) },
				},
			},
			{
				time = 0.04,
				pose = {
					Root = { rot = Vector3.new(-4, -3, 0), pos = Vector3.new(0, 0, 0.08) },
					Neck = { rot = Vector3.new(-2, 2, 0) },
					RightShoulder = { rot = Vector3.new(155, 0, -65.7) },
					LeftShoulder = { rot = Vector3.new(150.3, 0, 68) },
				},
			},
			{
				time = 0.07,
				pose = {
					Root = { rot = Vector3.new(2, -6, -1), pos = Vector3.new(0.02, 0, 0.21) },
					Neck = { rot = Vector3.new(-10, 5, 2) },
					RightShoulder = { rot = Vector3.new(152, 0, -68.7) },
					LeftShoulder = { rot = Vector3.new(147.3, 0, 70) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(4, -6, -2), pos = Vector3.new(0.03, 0, 0.3) },
					Neck = { rot = Vector3.new(-18, 6, 2) },
					RightShoulder = { rot = Vector3.new(145, 0, -65.7) },
					LeftShoulder = { rot = Vector3.new(140.3, 0, 67) },
				},
			},
			{
				time = 0.17,
				pose = {
					Root = { rot = Vector3.new(-3, -2, -1), pos = Vector3.new(0.02, 0, 0.19) },
					Neck = { rot = Vector3.new(-14, 2, 1) },
					RightShoulder = { rot = Vector3.new(141, 0, -59.7) },
					LeftShoulder = { rot = Vector3.new(135.3, 0, 62) },
				},
			},
			{
				time = 0.23,
				pose = {
					Root = { rot = Vector3.new(-12, 1, 0), pos = Vector3.new(0, 0, 0.04) },
					Neck = { rot = Vector3.new(-6, -1, 0) },
					RightShoulder = { rot = Vector3.new(148, 0, -57.7) },
					LeftShoulder = { rot = Vector3.new(137.3, 0, 59) },
				},
			},
			{
				time = 0.28,
				pose = {
					Root = { rot = Vector3.new(-10, 0, 0) },
					Neck = { rot = Vector3.new(-7, 0, 0) },
					RightShoulder = { rot = Vector3.new(152, 0, -59.7) },
					LeftShoulder = { rot = Vector3.new(142.3, 0, 60) },
				},
			},
			{
				time = 0.32,
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0) },
					Neck = { rot = Vector3.new(-8, 0, 0) },
					RightShoulder = { rot = Vector3.new(150, 0, -60.7) },
					LeftShoulder = { rot = Vector3.new(142.3, 0, 61) },
				},
			},
		},
	},

	-- Perfect block: the right arm sweeps the punch away.
	Parry = {
		length = 0.45,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0) },
					Neck = { rot = Vector3.new(-8, 0, 0) },
					RightShoulder = { rot = Vector3.new(150, 0, -60.7) },
					LeftShoulder = { rot = Vector3.new(142.3, 0, 61) },
				},
			},
			{
				time = 0.08,
				pose = {
					Root = { rot = Vector3.new(-4, -16, 0) },
					Neck = { rot = Vector3.new(0, 14, 0) },
					RightShoulder = { rot = Vector3.new(132.1, 0, -7.6) },
					LeftShoulder = { rot = Vector3.new(100, 0, 40) },
				},
			},
			{
				time = 0.26,
				pose = {
					Root = { rot = Vector3.new(-4, -16, 0) },
					Neck = { rot = Vector3.new(0, 14, 0) },
					RightShoulder = { rot = Vector3.new(132.1, 0, -7.6) },
					LeftShoulder = { rot = Vector3.new(100, 0, 40) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(92, 0, -36) },
					LeftShoulder = { rot = Vector3.new(100, 0, 40) },
				},
			},
		},
	},

	-- Guard broken: arms thrown open, head snaps back, then staggers.
	GuardBreak = {
		length = 0.8,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0) },
					Neck = { rot = Vector3.new(-8, 0, 0) },
					RightShoulder = { rot = Vector3.new(150, 0, -60.7) },
					LeftShoulder = { rot = Vector3.new(142.3, 0, 61) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(18, 0, 0) },
					Neck = { rot = Vector3.new(22, 0, 0) },
					RightShoulder = { rot = Vector3.new(150, 0, 38) },
					LeftShoulder = { rot = Vector3.new(150, 0, -38) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(-20, 0, 6) },
					Neck = { rot = Vector3.new(-16, 0, 4) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(14, 0, -8) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = { rot = Vector3.new(-20, 0, 6) },
					Neck = { rot = Vector3.new(-16, 0, 4) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(14, 0, -8) },
				},
			},
		},
	},

	-- Dazed: head down, arms loose, swaying. Upper body only (legs keep walking).
	-- Looped while the "Stunned" attribute is true.
	Stunned = {
		length = 1.4,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 5) },
					Neck = { rot = Vector3.new(-22, 0, 6) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = { rot = Vector3.new(-12, 0, -5) },
					Neck = { rot = Vector3.new(-18, 0, -6) },
					RightShoulder = { rot = Vector3.new(6, 0, 4) },
					LeftShoulder = { rot = Vector3.new(12, 0, -4) },
				},
			},
		},
	},

	-- Took a jab in the face: the head snaps back first, the torso follows, then it settles dazed.
	-- Upper body only (the legs keep walking). Ends in the Stunned pose.
	HitJab = {
		length = 0.5,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(4, 1, 0), pos = Vector3.new(0, 0, 0.06) },
					Neck = { rot = Vector3.new(22, 3, 0) },
					RightShoulder = { rot = Vector3.new(34, 0, 5) },
					LeftShoulder = { rot = Vector3.new(30, 0, -4) },
				},
			},
			{
				time = 0.03,
				pose = {
					Root = { rot = Vector3.new(7, 2, -1), pos = Vector3.new(0.01, 0, 0.13) },
					Neck = { rot = Vector3.new(40, 5, -3) },
					RightShoulder = { rot = Vector3.new(42, 0, 10) },
					LeftShoulder = { rot = Vector3.new(35, 0, -9) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(12, 3, -2), pos = Vector3.new(0.02, 0, 0.22) },
					Neck = { rot = Vector3.new(46, 6, -5) },
					RightShoulder = { rot = Vector3.new(56, 0, 18) },
					LeftShoulder = { rot = Vector3.new(44, 0, -14) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = { rot = Vector3.new(17, 4, -3), pos = Vector3.new(0.04, 0, 0.31) },
					Neck = { rot = Vector3.new(36, 5, -5) },
					RightShoulder = { rot = Vector3.new(64, 0, 23) },
					LeftShoulder = { rot = Vector3.new(56, 0, -20) },
				},
			},
			{
				time = 0.14,
				pose = {
					Root = { rot = Vector3.new(14, 3, -3), pos = Vector3.new(0.06, 0, 0.38) },
					Neck = { rot = Vector3.new(10, 2, -2) },
					RightShoulder = { rot = Vector3.new(44, 0, 22) },
					LeftShoulder = { rot = Vector3.new(52, 0, -24) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(2, 0, 0), pos = Vector3.new(0.07, 0, 0.4) },
					Neck = { rot = Vector3.new(-22, -2, 3) },
					RightShoulder = { rot = Vector3.new(12, 0, 14) },
					LeftShoulder = { rot = Vector3.new(24, 0, -18) },
				},
			},
			{
				time = 0.26,
				pose = {
					Root = { rot = Vector3.new(-15, -4, 3), pos = Vector3.new(0.06, 0, 0.33) },
					Neck = { rot = Vector3.new(-34, -4, 7) },
					RightShoulder = { rot = Vector3.new(-12, 0, 9) },
					LeftShoulder = { rot = Vector3.new(-4, 0, -13) },
				},
			},
			{
				time = 0.34,
				pose = {
					Root = { rot = Vector3.new(-19, -3, 5), pos = Vector3.new(0.04, 0, 0.21) },
					Neck = { rot = Vector3.new(-16, -2, 3) },
					RightShoulder = { rot = Vector3.new(-8, 0, 5) },
					LeftShoulder = { rot = Vector3.new(-14, 0, -8) },
				},
			},
			{
				time = 0.41,
				pose = {
					Root = { rot = Vector3.new(-7, 2, 3), pos = Vector3.new(0.01, 0, 0.08) },
					Neck = { rot = Vector3.new(-8, 3, 2) },
					RightShoulder = { rot = Vector3.new(15, 0, 8) },
					LeftShoulder = { rot = Vector3.new(4, 0, -5) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 5) },
					Neck = { rot = Vector3.new(-22, 0, 6) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
				},
			},
		},
	},

	-- Took a right cross: head and torso thrown toward the victim's right, a real stagger.
	HitCross = {
		length = 0.5,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(2, -4, -1), pos = Vector3.new(0.04, 0, 0.05) },
					Neck = { rot = Vector3.new(10, -22, -8) },
					RightShoulder = { rot = Vector3.new(36, 0, 2) },
					LeftShoulder = { rot = Vector3.new(34, 0, -8) },
				},
			},
			{
				time = 0.03,
				pose = {
					Root = { rot = Vector3.new(4, -8, -1), pos = Vector3.new(0.09, 0, 0.11) },
					Neck = { rot = Vector3.new(16, -42, -17) },
					RightShoulder = { rot = Vector3.new(40, 0, 4) },
					LeftShoulder = { rot = Vector3.new(44, 0, -16) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(7, -12, -1), pos = Vector3.new(0.16, 0, 0.19) },
					Neck = { rot = Vector3.new(19, -52, -24) },
					RightShoulder = { rot = Vector3.new(42, 0, 7) },
					LeftShoulder = { rot = Vector3.new(56, 0, -26) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = { rot = Vector3.new(11, -19, 0), pos = Vector3.new(0.28, 0, 0.31) },
					Neck = { rot = Vector3.new(16, -44, -26) },
					RightShoulder = { rot = Vector3.new(28, 0, 13) },
					LeftShoulder = { rot = Vector3.new(74, 0, -40) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(13, -24, 1), pos = Vector3.new(0.4, 0, 0.44) },
					Neck = { rot = Vector3.new(7, -22, -17) },
					RightShoulder = { rot = Vector3.new(4, 0, 21) },
					LeftShoulder = { rot = Vector3.new(64, 0, -44) },
				},
			},
			{
				time = 0.23,
				pose = {
					Root = { rot = Vector3.new(8, -17, 0), pos = Vector3.new(0.45, 0, 0.5) },
					Neck = { rot = Vector3.new(-13, -2, -3) },
					RightShoulder = { rot = Vector3.new(-13, 0, 22) },
					LeftShoulder = { rot = Vector3.new(32, 0, -30) },
				},
			},
			{
				time = 0.29,
				pose = {
					Root = { rot = Vector3.new(-9, -5, 1), pos = Vector3.new(0.4, 0, 0.45) },
					Neck = { rot = Vector3.new(-30, 13, 10) },
					RightShoulder = { rot = Vector3.new(-6, 0, 14) },
					LeftShoulder = { rot = Vector3.new(4, 0, -14) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = { rot = Vector3.new(-19, 5, 5), pos = Vector3.new(0.26, 0, 0.3) },
					Neck = { rot = Vector3.new(-26, 9, 12) },
					RightShoulder = { rot = Vector3.new(10, 0, 7) },
					LeftShoulder = { rot = Vector3.new(-10, 0, -6) },
				},
			},
			{
				time = 0.43,
				pose = {
					Root = { rot = Vector3.new(-10, 3, 3), pos = Vector3.new(0.1, 0, 0.12) },
					Neck = { rot = Vector3.new(-12, 2, 4) },
					RightShoulder = { rot = Vector3.new(18, 0, 6) },
					LeftShoulder = { rot = Vector3.new(2, 0, -4) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 5) },
					Neck = { rot = Vector3.new(-22, 0, 6) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
				},
			},
		},
	},

	-- Took a left hook: the head whips toward the victim's left, the upper body is carried sideways.
	HitHook = {
		length = 0.5,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(0, 4, 2), pos = Vector3.new(-0.06, 0, 0.02) },
					Neck = { rot = Vector3.new(0, 22, 13) },
					RightShoulder = { rot = Vector3.new(30, 0, 8) },
					LeftShoulder = { rot = Vector3.new(34, 0, -2) },
				},
			},
			{
				time = 0.03,
				pose = {
					Root = { rot = Vector3.new(0, 8, 3), pos = Vector3.new(-0.14, 0, 0.05) },
					Neck = { rot = Vector3.new(-3, 40, 26) },
					RightShoulder = { rot = Vector3.new(40, 0, 17) },
					LeftShoulder = { rot = Vector3.new(38, 0, -3) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(1, 12, 5), pos = Vector3.new(-0.24, 0, 0.08) },
					Neck = { rot = Vector3.new(-5, 50, 35) },
					RightShoulder = { rot = Vector3.new(52, 0, 27) },
					LeftShoulder = { rot = Vector3.new(38, 0, -5) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = { rot = Vector3.new(1, 18, 6), pos = Vector3.new(-0.4, 0, 0.14) },
					Neck = { rot = Vector3.new(-6, 44, 36) },
					RightShoulder = { rot = Vector3.new(66, 0, 38) },
					LeftShoulder = { rot = Vector3.new(24, 0, -9) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(0, 23, 7), pos = Vector3.new(-0.54, 0, 0.2) },
					Neck = { rot = Vector3.new(-4, 22, 22) },
					RightShoulder = { rot = Vector3.new(46, 0, 42) },
					LeftShoulder = { rot = Vector3.new(2, 0, -18) },
				},
			},
			{
				time = 0.21,
				pose = {
					Root = { rot = Vector3.new(0, 15, 5), pos = Vector3.new(-0.6, 0, 0.24) },
					Neck = { rot = Vector3.new(-10, -1, -3) },
					RightShoulder = { rot = Vector3.new(18, 0, 30) },
					LeftShoulder = { rot = Vector3.new(-10, 0, -22) },
				},
			},
			{
				time = 0.28,
				pose = {
					Root = { rot = Vector3.new(-8, 3, -2), pos = Vector3.new(-0.49, 0, 0.22) },
					Neck = { rot = Vector3.new(-24, -14, -14) },
					RightShoulder = { rot = Vector3.new(2, 0, 16) },
					LeftShoulder = { rot = Vector3.new(-2, 0, -16) },
				},
			},
			{
				time = 0.35,
				pose = {
					Root = { rot = Vector3.new(-18, -4, -4), pos = Vector3.new(-0.3, 0, 0.16) },
					Neck = { rot = Vector3.new(-27, -9, -8) },
					RightShoulder = { rot = Vector3.new(-6, 0, 8) },
					LeftShoulder = { rot = Vector3.new(12, 0, -9) },
				},
			},
			{
				time = 0.43,
				pose = {
					Root = { rot = Vector3.new(-9, -1, 0), pos = Vector3.new(-0.11, 0, 0.07) },
					Neck = { rot = Vector3.new(-12, -2, 0) },
					RightShoulder = { rot = Vector3.new(10, 0, 5) },
					LeftShoulder = { rot = Vector3.new(16, 0, -7) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 5) },
					Neck = { rot = Vector3.new(-22, 0, 6) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
				},
			},
		},
	},

	-- Took the finisher: smashed down and back, knees buckle, staggers, catches itself.
	-- Whole body (the legs are animated).
	HitHeavy = {
		length = 0.85,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(6, -5, -3), pos = Vector3.new(0.03, -0.08, 0.05) },
					Neck = { rot = Vector3.new(16, -18, -10) },
					RightShoulder = { rot = Vector3.new(38, 0, 8) },
					LeftShoulder = { rot = Vector3.new(44, 0, -10) },
					RightHip = { rot = Vector3.new(-10, 0, 5), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(2, 0, 1), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(14, -12, -6), pos = Vector3.new(0.09, -0.3, 0.17) },
					Neck = { rot = Vector3.new(26, -46, -26) },
					RightShoulder = { rot = Vector3.new(48, 0, 13) },
					LeftShoulder = { rot = Vector3.new(58, 0, -17) },
					RightHip = { rot = Vector3.new(-24, 0, 9), pos = Vector3.new(0, 0.49, 0) },
					LeftHip = { rot = Vector3.new(2, 0, 3), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = { rot = Vector3.new(24, -19, -9), pos = Vector3.new(0.16, -0.56, 0.33) },
					Neck = { rot = Vector3.new(14, -40, -28) },
					RightShoulder = { rot = Vector3.new(74, 0, 28) },
					LeftShoulder = { rot = Vector3.new(86, 0, -32) },
					RightHip = { rot = Vector3.new(-42, 0, 13), pos = Vector3.new(0, 0.87, 0) },
					LeftHip = { rot = Vector3.new(2, 0, 5), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.16,
				pose = {
					Root = { rot = Vector3.new(29, -22, -11), pos = Vector3.new(0.22, -0.8, 0.49) },
					Neck = { rot = Vector3.new(-8, -26, -20) },
					RightShoulder = { rot = Vector3.new(98, 0, 48) },
					LeftShoulder = { rot = Vector3.new(112, 0, -50) },
					RightHip = { rot = Vector3.new(-55, 0, 16), pos = Vector3.new(0, 1.19, 0) },
					LeftHip = { rot = Vector3.new(3, 0, 6), pos = Vector3.new(0, 0.54, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = { rot = Vector3.new(18, -18, -8), pos = Vector3.new(0.26, -0.98, 0.62) },
					Neck = { rot = Vector3.new(-26, -8, -10) },
					RightShoulder = { rot = Vector3.new(52, 0, 60) },
					LeftShoulder = { rot = Vector3.new(122, 0, -62) },
					RightHip = { rot = Vector3.new(-50, 0, 14), pos = Vector3.new(0, 1.19, 0) },
					LeftHip = { rot = Vector3.new(16, 0, 2), pos = Vector3.new(0, 0.95, 0) },
				},
			},
			{
				time = 0.33,
				pose = {
					Root = { rot = Vector3.new(-6, -8, -2), pos = Vector3.new(0.26, -0.92, 0.66) },
					Neck = { rot = Vector3.new(-34, 6, 2) },
					RightShoulder = { rot = Vector3.new(-16, 0, 32) },
					LeftShoulder = { rot = Vector3.new(46, 0, -44) },
					RightHip = { rot = Vector3.new(-28, 0, 8), pos = Vector3.new(0, 0.96, 0) },
					LeftHip = { rot = Vector3.new(28, 0, -3), pos = Vector3.new(0, 1, 0) },
				},
			},
			{
				time = 0.43,
				pose = {
					Root = { rot = Vector3.new(-22, 2, 5), pos = Vector3.new(0.2, -0.68, 0.6) },
					Neck = { rot = Vector3.new(-24, 10, 8) },
					RightShoulder = { rot = Vector3.new(-34, 0, 16) },
					LeftShoulder = { rot = Vector3.new(-24, 0, -20) },
					RightHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.85, 0) },
					LeftHip = { rot = Vector3.new(30, 0, -9), pos = Vector3.new(0, 0.87, 0) },
				},
			},
			{
				time = 0.52,
				pose = {
					Root = { rot = Vector3.new(-10, 6, 7), pos = Vector3.new(0.1, -0.42, 0.46) },
					Neck = { rot = Vector3.new(-2, 4, 8) },
					RightShoulder = { rot = Vector3.new(-6, 0, 12) },
					LeftShoulder = { rot = Vector3.new(-28, 0, -10) },
					RightHip = { rot = Vector3.new(-2, 0, -3), pos = Vector3.new(0, 0.41, 0) },
					LeftHip = { rot = Vector3.new(22, 0, -10), pos = Vector3.new(0, 0.64, 0) },
				},
			},
			{
				time = 0.61,
				pose = {
					Root = { rot = Vector3.new(10, 3, -4), pos = Vector3.new(-0.04, -0.22, 0.4) },
					Neck = { rot = Vector3.new(13, -8, -8) },
					RightShoulder = { rot = Vector3.new(36, 0, 10) },
					LeftShoulder = { rot = Vector3.new(14, 0, -18) },
					RightHip = { rot = Vector3.new(-19, 0, 6), pos = Vector3.new(0, 0.36, 0) },
					LeftHip = { rot = Vector3.new(3, 0, -1), pos = Vector3.new(0, 0.41, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = { rot = Vector3.new(3, -3, -2), pos = Vector3.new(-0.06, -0.13, 0.26) },
					Neck = { rot = Vector3.new(3, -8, -3) },
					RightShoulder = { rot = Vector3.new(34, 0, 12) },
					LeftShoulder = { rot = Vector3.new(30, 0, -9) },
					RightHip = { rot = Vector3.new(-8, 0, 3), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-6, 0, 0), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = { rot = Vector3.new(-8, -1, 2), pos = Vector3.new(-0.03, -0.05, 0.09) },
					Neck = { rot = Vector3.new(-13, -3, 3) },
					RightShoulder = { rot = Vector3.new(20, 0, 9) },
					LeftShoulder = { rot = Vector3.new(20, 0, -7) },
					RightHip = { rot = Vector3.new(5, 0, -1), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(6, 0, -1), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.85,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 5) },
					Neck = { rot = Vector3.new(-22, 0, 6) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Hit from behind: thrown forward, the head lags then snaps, stumbling.
	HitBack = {
		length = 0.5,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-6, 2, 1), pos = Vector3.new(0, 0, -0.07) },
					Neck = { rot = Vector3.new(12, -1, 0) },
					RightShoulder = { rot = Vector3.new(-10, 0, 10) },
					LeftShoulder = { rot = Vector3.new(-6, 0, -10) },
				},
			},
			{
				time = 0.04,
				pose = {
					Root = { rot = Vector3.new(-13, 6, 2), pos = Vector3.new(-0.02, 0, -0.22) },
					Neck = { rot = Vector3.new(27, -5, -2) },
					RightShoulder = { rot = Vector3.new(-30, 0, 17) },
					LeftShoulder = { rot = Vector3.new(-20, 0, -13) },
				},
			},
			{
				time = 0.09,
				pose = {
					Root = { rot = Vector3.new(-19, 10, 3), pos = Vector3.new(-0.05, 0, -0.4) },
					Neck = { rot = Vector3.new(13, -8, -4) },
					RightShoulder = { rot = Vector3.new(-50, 0, 22) },
					LeftShoulder = { rot = Vector3.new(-36, 0, -18) },
				},
			},
			{
				time = 0.14,
				pose = {
					Root = { rot = Vector3.new(-20, 9, 3), pos = Vector3.new(-0.07, 0, -0.54) },
					Neck = { rot = Vector3.new(-24, -5, 2) },
					RightShoulder = { rot = Vector3.new(-44, 0, 20) },
					LeftShoulder = { rot = Vector3.new(-46, 0, -21) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-15, 3, 4), pos = Vector3.new(-0.05, 0, -0.62) },
					Neck = { rot = Vector3.new(-38, 3, 6) },
					RightShoulder = { rot = Vector3.new(6, 0, 11) },
					LeftShoulder = { rot = Vector3.new(-22, 0, -15) },
				},
			},
			{
				time = 0.27,
				pose = {
					Root = { rot = Vector3.new(-6, -5, 3), pos = Vector3.new(0.03, 0, -0.54) },
					Neck = { rot = Vector3.new(-24, 6, 5) },
					RightShoulder = { rot = Vector3.new(64, 0, 2) },
					LeftShoulder = { rot = Vector3.new(28, 0, -9) },
				},
			},
			{
				time = 0.34,
				pose = {
					Root = { rot = Vector3.new(-3, -7, 0), pos = Vector3.new(0.07, 0, -0.34) },
					Neck = { rot = Vector3.new(-7, 4, 1) },
					RightShoulder = { rot = Vector3.new(48, 0, 9) },
					LeftShoulder = { rot = Vector3.new(58, 0, -3) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(-10, -3, 3), pos = Vector3.new(0.03, 0, -0.14) },
					Neck = { rot = Vector3.new(-12, 0, 4) },
					RightShoulder = { rot = Vector3.new(22, 0, 9) },
					LeftShoulder = { rot = Vector3.new(30, 0, -6) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 5) },
					Neck = { rot = Vector3.new(-22, 0, 6) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
				},
			},
		},
	},

	-- Body shot from the front: the torso folds AROUND the fist (it absorbs the hit instead
	-- of moving out of its way), arms drop to cover the stomach, then dazed. The hips follow
	-- the fold so the feet stay under the body. Ends in the Stunned pose.
	HitBodyFront = {
		length = 0.5,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-12, -6, 0), pos = Vector3.new(0, -0.03, 0.04) },
					Neck = { rot = Vector3.new(-4, 6, 0) },
					RightShoulder = { rot = Vector3.new(104, 0, -44) },
					LeftShoulder = { rot = Vector3.new(100, 0, 34) },
					RightHip = { rot = Vector3.new(10, 0, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0) },
				},
			},
			{
				time = 0.05,
				pose = {
					Root = { rot = Vector3.new(-20, -3, 1), pos = Vector3.new(0, -0.07, 0.13) },
					Neck = { rot = Vector3.new(-14, 3, 0) },
					RightShoulder = { rot = Vector3.new(74, 0, -38) },
					LeftShoulder = { rot = Vector3.new(70, 0, 30) },
					RightHip = { rot = Vector3.new(17, 0, 0) },
					LeftHip = { rot = Vector3.new(15, 0, 0) },
				},
			},
			{
				time = 0.11,
				pose = {
					Root = { rot = Vector3.new(-26, 0, 2), pos = Vector3.new(0, -0.1, 0.22) },
					Neck = { rot = Vector3.new(-24, 0, 2) },
					RightShoulder = { rot = Vector3.new(48, 0, -30) },
					LeftShoulder = { rot = Vector3.new(44, 0, 26) },
					RightHip = { rot = Vector3.new(23, 0, 0), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(20, 0, 0), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 0.2,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-25, 2, 3), pos = Vector3.new(0, -0.1, 0.25) },
					Neck = { rot = Vector3.new(-28, 2, 3) },
					RightShoulder = { rot = Vector3.new(40, 0, -24) },
					LeftShoulder = { rot = Vector3.new(38, 0, 22) },
					RightHip = { rot = Vector3.new(22, 0, 0), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(19, 0, 0), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(-21, 1, 4), pos = Vector3.new(0, -0.06, 0.17) },
					Neck = { rot = Vector3.new(-27, 1, 5) },
					RightShoulder = { rot = Vector3.new(28, 0, -10) },
					LeftShoulder = { rot = Vector3.new(26, 0, 8) },
					RightHip = { rot = Vector3.new(14, 0, 0), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(12, 0, 0), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-17, 0, 5), pos = Vector3.new(0, -0.02, 0.07) },
					Neck = { rot = Vector3.new(-24, 0, 6) },
					RightShoulder = { rot = Vector3.new(16, 0, 2) },
					LeftShoulder = { rot = Vector3.new(14, 0, -3) },
					RightHip = { rot = Vector3.new(6, 0, 0) },
					LeftHip = { rot = Vector3.new(5, 0, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 5) },
					Neck = { rot = Vector3.new(-22, 0, 6) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Kidney shot from behind: the back arches, chest and head thrown, the body stumbles
	-- forward. Upper body only. Ends in the Stunned pose.
	HitBodyBack = {
		length = 0.5,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(3, 4, 0), pos = Vector3.new(0, -0.03, -0.03) },
					Neck = { rot = Vector3.new(10, 2, 0) },
					RightShoulder = { rot = Vector3.new(110, 0, -30) },
					LeftShoulder = { rot = Vector3.new(104, 0, 24) },
					RightHip = { rot = Vector3.new(-2.7, 0, 0) },
					LeftHip = { rot = Vector3.new(-2.7, 0, 0) },
				},
			},
			{
				time = 0.05,
				pose = {
					Root = { rot = Vector3.new(10, 6, -2), pos = Vector3.new(0, -0.04, -0.1) },
					Neck = { rot = Vector3.new(24, 4, -2) },
					RightShoulder = { rot = Vector3.new(70, 0, -4) },
					LeftShoulder = { rot = Vector3.new(62, 0, 2) },
					RightHip = { rot = Vector3.new(-9, 0, 0), pos = Vector3.new(0, 0.02, 0) },
					LeftHip = { rot = Vector3.new(-9, 0, 0) },
				},
			},
			{
				time = 0.11,
				pose = {
					Root = { rot = Vector3.new(14, 6, -3), pos = Vector3.new(0, -0.05, -0.18) },
					Neck = { rot = Vector3.new(20, 2, -3) },
					RightShoulder = { rot = Vector3.new(38, 0, 12) },
					LeftShoulder = { rot = Vector3.new(32, 0, -12) },
					RightHip = { rot = Vector3.new(-12.6, 0, 0), pos = Vector3.new(0, 0.03, 0) },
					LeftHip = { rot = Vector3.new(-12.6, 0, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(6, 2, -1), pos = Vector3.new(0, -0.03, -0.21) },
					Neck = { rot = Vector3.new(-4, 0, 2) },
					RightShoulder = { rot = Vector3.new(24, 0, 13) },
					LeftShoulder = { rot = Vector3.new(20, 0, -13) },
					RightHip = { rot = Vector3.new(-5.4, 0, 0), pos = Vector3.new(0, 0.01, 0) },
					LeftHip = { rot = Vector3.new(-5.4, 0, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(-7, 0, 3), pos = Vector3.new(0, -0.04, -0.15) },
					Neck = { rot = Vector3.new(-18, 0, 5) },
					RightShoulder = { rot = Vector3.new(14, 0, 9) },
					LeftShoulder = { rot = Vector3.new(12, 0, -9) },
					RightHip = { rot = Vector3.new(6.3, 0, 0) },
					LeftHip = { rot = Vector3.new(6.3, 0, 0), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-12, 0, 4), pos = Vector3.new(0, -0.05, -0.06) },
					Neck = { rot = Vector3.new(-22, 0, 6) },
					RightShoulder = { rot = Vector3.new(12, 0, 7) },
					LeftShoulder = { rot = Vector3.new(10, 0, -7) },
					RightHip = { rot = Vector3.new(10.8, 0, 0) },
					LeftHip = { rot = Vector3.new(10.8, 0, 0), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 5) },
					Neck = { rot = Vector3.new(-22, 0, 6) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Rib shot on the victim's LEFT side: the torso crunches over the impact while the
	-- body is shoved to the right, the left elbow drops to cover the ribs.
	-- HitBodyRight is the same clip mirrored (built at the bottom of this file).
	HitBodyLeft = {
		length = 0.5,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-4, 2, 6), pos = Vector3.new(0.04, -0.09, 0) },
					Neck = { rot = Vector3.new(2, 4, 6) },
					RightShoulder = { rot = Vector3.new(116, 0, -46) },
					LeftShoulder = { rot = Vector3.new(84, 0, 30) },
					RightHip = { rot = Vector3.new(0, 0, -5) },
					LeftHip = { rot = Vector3.new(0, 0, -5), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.05,
				pose = {
					Root = { rot = Vector3.new(-8, 4, 11), pos = Vector3.new(0.14, -0.18, 0.02) },
					Neck = { rot = Vector3.new(-2, 6, 12) },
					RightShoulder = { rot = Vector3.new(96, 0, -40) },
					LeftShoulder = { rot = Vector3.new(50, 0, 26) },
					RightHip = { rot = Vector3.new(0, 0, -10) },
					LeftHip = { rot = Vector3.new(0, 0, -10), pos = Vector3.new(0, 0.36, 0) },
				},
			},
			{
				time = 0.11,
				pose = {
					Root = { rot = Vector3.new(-12, 5, 15), pos = Vector3.new(0.24, -0.26, 0.04) },
					Neck = { rot = Vector3.new(-8, 6, 16) },
					RightShoulder = { rot = Vector3.new(78, 0, -32) },
					LeftShoulder = { rot = Vector3.new(32, 0, 22) },
					RightHip = { rot = Vector3.new(0, 0, -14) },
					LeftHip = { rot = Vector3.new(0, 0, -14), pos = Vector3.new(0, 0.5, 0) },
				},
			},
			{
				time = 0.2,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-13, 4, 14), pos = Vector3.new(0.27, -0.24, 0.05) },
					Neck = { rot = Vector3.new(-14, 4, 14) },
					RightShoulder = { rot = Vector3.new(60, 0, -20) },
					LeftShoulder = { rot = Vector3.new(26, 0, 18) },
					RightHip = { rot = Vector3.new(0, 0, -13) },
					LeftHip = { rot = Vector3.new(0, 0, -13), pos = Vector3.new(0, 0.46, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(-14, 2, 11), pos = Vector3.new(0.2, -0.17, 0.04) },
					Neck = { rot = Vector3.new(-18, 2, 10) },
					RightShoulder = { rot = Vector3.new(36, 0, -6) },
					LeftShoulder = { rot = Vector3.new(20, 0, 8) },
					RightHip = { rot = Vector3.new(0, 0, -9) },
					LeftHip = { rot = Vector3.new(0, 0, -9), pos = Vector3.new(0, 0.34, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-14, 1, 7), pos = Vector3.new(0.08, -0.06, 0.02) },
					Neck = { rot = Vector3.new(-21, 0, 7) },
					RightShoulder = { rot = Vector3.new(18, 0, 2) },
					LeftShoulder = { rot = Vector3.new(12, 0, -3) },
					RightHip = { rot = Vector3.new(0, 0, -3) },
					LeftHip = { rot = Vector3.new(0, 0, -3), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 5) },
					Neck = { rot = Vector3.new(-22, 0, 6) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Dash forward: low, leaning in, arms back. Config.Combat.DASH_TIME (0.25 s) of travel, then recovery.
	DashForward = {
		length = 0.42,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-15.4, 0, 0), pos = Vector3.new(0, -0.14, 0) },
					Neck = { rot = Vector3.new(12.1, 0, 0) },
					RightShoulder = { rot = Vector3.new(-22, 0, 4.4) },
					LeftShoulder = { rot = Vector3.new(-20.9, 0, -4.4) },
					RightHip = { rot = Vector3.new(-9.9, 0, 2.75), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(16.5, 0, -2.75), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.07,
				pose = {
					Root = { rot = Vector3.new(-28, 0, 0), pos = Vector3.new(0, -0.25, 0) },
					Neck = { rot = Vector3.new(22, 0, 0) },
					RightShoulder = { rot = Vector3.new(-40, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-38, 0, -8) },
					RightHip = { rot = Vector3.new(-18, 0, 5), pos = Vector3.new(0, -0.07, 0) },
					LeftHip = { rot = Vector3.new(30, 0, -5), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.22,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-28, 0, 0), pos = Vector3.new(0, -0.25, 0) },
					Neck = { rot = Vector3.new(22, 0, 0) },
					RightShoulder = { rot = Vector3.new(-40, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-38, 0, -8) },
					RightHip = { rot = Vector3.new(-18, 0, 5), pos = Vector3.new(0, -0.07, 0) },
					LeftHip = { rot = Vector3.new(30, 0, -5), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.32,
				pose = {
					Root = { rot = Vector3.new(-12.6, 0, 0), pos = Vector3.new(0, -0.11, 0) },
					Neck = { rot = Vector3.new(9.9, 0, 0) },
					RightShoulder = { rot = Vector3.new(-18, 0, 3.6) },
					LeftShoulder = { rot = Vector3.new(-17.1, 0, -3.6) },
					RightHip = { rot = Vector3.new(-8.1, 0, 2.25), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(13.5, 0, -2.25), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 0) },
					LeftShoulder = { rot = Vector3.new(0, 0, 0) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Dash back: leaning away, guard up. Config.Combat.DASH_TIME (0.25 s) of travel, then recovery.
	DashBack = {
		length = 0.42,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(6.6, 0, 0), pos = Vector3.new(0, -0.11, 0) },
					Neck = { rot = Vector3.new(-3.3, 0, 0) },
					RightShoulder = { rot = Vector3.new(44, 0, -17.6) },
					LeftShoulder = { rot = Vector3.new(48.4, 0, 18.7) },
					RightHip = { rot = Vector3.new(-4.4, 0, 2.75), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(16.5, 0, -2.75), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.07,
				pose = {
					Root = { rot = Vector3.new(12, 0, 0), pos = Vector3.new(0, -0.2, 0) },
					Neck = { rot = Vector3.new(-6, 0, 0) },
					RightShoulder = { rot = Vector3.new(80, 0, -32) },
					LeftShoulder = { rot = Vector3.new(88, 0, 34) },
					RightHip = { rot = Vector3.new(-8, 0, 5), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(30, 0, -5), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 0.22,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(12, 0, 0), pos = Vector3.new(0, -0.2, 0) },
					Neck = { rot = Vector3.new(-6, 0, 0) },
					RightShoulder = { rot = Vector3.new(80, 0, -32) },
					LeftShoulder = { rot = Vector3.new(88, 0, 34) },
					RightHip = { rot = Vector3.new(-8, 0, 5), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(30, 0, -5), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 0.32,
				pose = {
					Root = { rot = Vector3.new(5.4, 0, 0), pos = Vector3.new(0, -0.09, 0) },
					Neck = { rot = Vector3.new(-2.7, 0, 0) },
					RightShoulder = { rot = Vector3.new(36, 0, -14.4) },
					LeftShoulder = { rot = Vector3.new(39.6, 0, 15.3) },
					RightHip = { rot = Vector3.new(-3.6, 0, 2.25), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(13.5, 0, -2.25), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 0) },
					LeftShoulder = { rot = Vector3.new(0, 0, 0) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Side dash: body leans into the direction, legs apart. Config.Combat.DASH_TIME (0.25 s) of travel, then recovery.
	DashLeft = {
		length = 0.42,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-3.3, 0, 8.8), pos = Vector3.new(0, -0.11, 0) },
					Neck = { rot = Vector3.new(0, 0, -6.6) },
					RightShoulder = { rot = Vector3.new(46.2, 0, -16.5) },
					LeftShoulder = { rot = Vector3.new(22, 0, -16.5) },
					RightHip = { rot = Vector3.new(0, 0, 5.5), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -16.5), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.07,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 16), pos = Vector3.new(0, -0.2, 0) },
					Neck = { rot = Vector3.new(0, 0, -12) },
					RightShoulder = { rot = Vector3.new(84, 0, -30) },
					LeftShoulder = { rot = Vector3.new(40, 0, -30) },
					RightHip = { rot = Vector3.new(0, 0, 10), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -30), pos = Vector3.new(0, 0.68, 0) },
				},
			},
			{
				time = 0.22,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-6, 0, 16), pos = Vector3.new(0, -0.2, 0) },
					Neck = { rot = Vector3.new(0, 0, -12) },
					RightShoulder = { rot = Vector3.new(84, 0, -30) },
					LeftShoulder = { rot = Vector3.new(40, 0, -30) },
					RightHip = { rot = Vector3.new(0, 0, 10), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -30), pos = Vector3.new(0, 0.68, 0) },
				},
			},
			{
				time = 0.32,
				pose = {
					Root = { rot = Vector3.new(-2.7, 0, 7.2), pos = Vector3.new(0, -0.09, 0) },
					Neck = { rot = Vector3.new(0, 0, -5.4) },
					RightShoulder = { rot = Vector3.new(37.8, 0, -13.5) },
					LeftShoulder = { rot = Vector3.new(18, 0, -13.5) },
					RightHip = { rot = Vector3.new(0, 0, 4.5), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -13.5), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 0) },
					LeftShoulder = { rot = Vector3.new(0, 0, 0) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Side dash (mirror of DashLeft). Config.Combat.DASH_TIME (0.25 s) of travel, then recovery.
	DashRight = {
		length = 0.42,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-3.3, 0, -8.8), pos = Vector3.new(0, -0.11, 0) },
					Neck = { rot = Vector3.new(0, 0, 6.6) },
					RightShoulder = { rot = Vector3.new(22, 0, 16.5) },
					LeftShoulder = { rot = Vector3.new(46.2, 0, 16.5) },
					RightHip = { rot = Vector3.new(0, 0, 16.5), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -5.5), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.07,
				pose = {
					Root = { rot = Vector3.new(-6, 0, -16), pos = Vector3.new(0, -0.2, 0) },
					Neck = { rot = Vector3.new(0, 0, 12) },
					RightShoulder = { rot = Vector3.new(40, 0, 30) },
					LeftShoulder = { rot = Vector3.new(84, 0, 30) },
					RightHip = { rot = Vector3.new(0, 0, 30), pos = Vector3.new(0, 0.68, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -10), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.22,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-6, 0, -16), pos = Vector3.new(0, -0.2, 0) },
					Neck = { rot = Vector3.new(0, 0, 12) },
					RightShoulder = { rot = Vector3.new(40, 0, 30) },
					LeftShoulder = { rot = Vector3.new(84, 0, 30) },
					RightHip = { rot = Vector3.new(0, 0, 30), pos = Vector3.new(0, 0.68, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -10), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.32,
				pose = {
					Root = { rot = Vector3.new(-2.7, 0, -7.2), pos = Vector3.new(0, -0.09, 0) },
					Neck = { rot = Vector3.new(0, 0, 5.4) },
					RightShoulder = { rot = Vector3.new(18, 0, 13.5) },
					LeftShoulder = { rot = Vector3.new(37.8, 0, 13.5) },
					RightHip = { rot = Vector3.new(0, 0, 13.5), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -4.5), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 0) },
					LeftShoulder = { rot = Vector3.new(0, 0, 0) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},
}

-- Mirror image of a clip (left ↔ right), so one side is authored and the
-- other is built from it. In the parent part's space, mirroring across the
-- body's middle plane keeps rot.X, flips rot.Y, rot.Z and pos.X, and swaps
-- the left and right joints. Built once, when the game loads.
local MIRRORED_JOINT: { [string]: string } = {
	Root = "Root",
	Neck = "Neck",
	RightShoulder = "LeftShoulder",
	LeftShoulder = "RightShoulder",
	RightHip = "LeftHip",
	LeftHip = "RightHip",
}

local function mirror(clip: R6Pose.Clip): R6Pose.Clip
	local keyframes = {}
	for _, keyframe in clip.keyframes do
		local pose = {}
		for joint, jointPose in keyframe.pose do
			local rot = jointPose.rot
			local pos = jointPose.pos
			pose[MIRRORED_JOINT[joint]] = {
				rot = Vector3.new(rot.X, -rot.Y, -rot.Z),
				pos = if pos then Vector3.new(-pos.X, pos.Y, pos.Z) else nil,
			}
		end
		table.insert(keyframes, { time = keyframe.time, tangent = keyframe.tangent, pose = pose })
	end
	return { length = clip.length, looped = clip.looped, keyframes = keyframes }
end

-- Rib shot on the victim's RIGHT side = the left one, mirrored.
clips.HitBodyRight = mirror(clips.HitBodyLeft)

return table.freeze(clips)
