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
--   • The HitBodyFront/Back/Left/Right reactions start with a "contact"
--     keyframe close to the pose the victim was in: at the moment of impact
--     the body takes the hit (folds around it) before being thrown, it never
--     moves out of the way. Their feet were checked to stay on the ground.
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
	-- Guard held for a few seconds after a punch or a hit, like a boxer's: rear fist
	-- in front of the chin, lead fist in front of the cheekbone, both about a stud in
	-- front of the face and a stud apart (never crossed). R6 arms have no elbows, so
	-- the hand position is what matters (checked by computing where the fists end up).
	-- Torso turned, slow weight shift and breathing.
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
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-9.5, -9, 1.5), pos = Vector3.new(0, -0.04, 0) },
					Neck = { rot = Vector3.new(7, 7, 0) },
					RightShoulder = { rot = Vector3.new(113.5, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(113.5, 0, 37) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = { rot = Vector3.new(-7.5, -12, 0) },
					Neck = { rot = Vector3.new(5.5, 10, 0) },
					RightShoulder = { rot = Vector3.new(110, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(117, 0, 37) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = { rot = Vector3.new(-9.5, -15, -1.5), pos = Vector3.new(0, -0.04, 0) },
					Neck = { rot = Vector3.new(7, 13, 0) },
					RightShoulder = { rot = Vector3.new(109, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(117.5, 0, 37) },
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
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.04,
				pose = {
					Root = { rot = Vector3.new(-5, -7, -1.5), pos = Vector3.new(0.03, -0.05, 0.07) },
					Neck = { rot = Vector3.new(4, 6, 0.5) },
					RightShoulder = { rot = Vector3.new(112.4, 0, -37.8) },
					LeftShoulder = { rot = Vector3.new(111.1, 0, 40.2) },
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
					RightShoulder = { rot = Vector3.new(115.2, 0, -40.3) },
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
					RightShoulder = { rot = Vector3.new(116.6, 0, -41.6) },
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
					RightShoulder = { rot = Vector3.new(116.6, 0, -41.6) },
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
					RightShoulder = { rot = Vector3.new(116.6, 0, -41.6) },
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
					RightShoulder = { rot = Vector3.new(113.8, 0, -39) },
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
					RightShoulder = { rot = Vector3.new(110.4, 0, -35.8) },
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
					RightShoulder = { rot = Vector3.new(111.5, 0, -36.9) },
					LeftShoulder = { rot = Vector3.new(114.7, 0, 36.8) },
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
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
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
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(-6, -22, -3), pos = Vector3.new(0.06, -0.09, 0.09) },
					Neck = { rot = Vector3.new(5, 18, 2) },
					RightShoulder = { rot = Vector3.new(115.5, 0, -42) },
					LeftShoulder = { rot = Vector3.new(115, 0, 32.2) },
					RightHip = { rot = Vector3.new(-0.3, -7, 2.7), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(-5.4, 4, 3.3), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.09,
				pose = {
					Root = { rot = Vector3.new(-10, 4, 1), pos = Vector3.new(0.02, -0.15, -0.1) },
					Neck = { rot = Vector3.new(7, -2, 0) },
					RightShoulder = { rot = Vector3.new(126.6, 0, -32.2) },
					LeftShoulder = { rot = Vector3.new(120.9, 0, 46.6) },
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
					LeftShoulder = { rot = Vector3.new(132.9, 0, 58) },
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
					LeftShoulder = { rot = Vector3.new(137.7, 0, 61.5) },
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
					LeftShoulder = { rot = Vector3.new(138.2, 0, 61.3) },
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
					LeftShoulder = { rot = Vector3.new(130.5, 0, 56.8) },
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
					LeftShoulder = { rot = Vector3.new(119.5, 0, 45.7) },
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
					LeftShoulder = { rot = Vector3.new(113.5, 0, 34.9) },
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
					RightShoulder = { rot = Vector3.new(110.9, 0, -36.3) },
					LeftShoulder = { rot = Vector3.new(115.9, 0, 37.9) },
					RightHip = { rot = Vector3.new(-0.1, 0, -0.6), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(0.6, 0, -0.6), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.5,
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
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.04,
				pose = {
					Root = { rot = Vector3.new(-10, -2, 4), pos = Vector3.new(-0.04, -0.18, 0.02) },
					Neck = { rot = Vector3.new(6, 1, -3) },
					RightShoulder = { rot = Vector3.new(112.6, 0, -34) },
					LeftShoulder = { rot = Vector3.new(128.7, 0, 30.1) },
					RightHip = { rot = Vector3.new(-1.4, -4, -4.8), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(5.7, -4, -4.2), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.09,
				pose = {
					Root = { rot = Vector3.new(-11, 4, 8), pos = Vector3.new(-0.06, -0.26, -0.02) },
					Neck = { rot = Vector3.new(7, -6, -6) },
					RightShoulder = { rot = Vector3.new(116.3, 0, -28.5) },
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
					RightShoulder = { rot = Vector3.new(115.6, 0, -43.7) },
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
					RightShoulder = { rot = Vector3.new(123.4, 0, -58.3) },
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
					RightShoulder = { rot = Vector3.new(127.6, 0, -63.2) },
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
					RightShoulder = { rot = Vector3.new(119.1, 0, -54) },
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
					RightShoulder = { rot = Vector3.new(111.5, 0, -37.8) },
					LeftShoulder = { rot = Vector3.new(116.3, 0, 37.1) },
					RightHip = { rot = Vector3.new(0.6, 1, 0.1), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-1.7, 4, 0.6), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.38,
				pose = {
					Root = { rot = Vector3.new(-7, -7, 0.5), pos = Vector3.new(0, 0.02, 0.03) },
					Neck = { rot = Vector3.new(5.5, 7, 0) },
					RightShoulder = { rot = Vector3.new(111.1, 0, -36.1) },
					LeftShoulder = { rot = Vector3.new(114.4, 0, 36.1) },
					RightHip = { rot = Vector3.new(-2.3, -1, -0.7), pos = Vector3.new(0, 0.02, 0) },
					LeftHip = { rot = Vector3.new(1, -2, -0.6), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.44,
				pose = {
					Root = { rot = Vector3.new(-8.3, -13, 0), pos = Vector3.new(0, -0.01, -0.01) },
					Neck = { rot = Vector3.new(6.2, 10.8, 0) },
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115.4, 0, 37.2) },
					RightHip = { rot = Vector3.new(0.2, 0, 0), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(-0.4, 0, 0), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.5,
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
					RightShoulder = { rot = Vector3.new(111, 0, -36.5) },
					LeftShoulder = { rot = Vector3.new(115, 0, 37) },
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
					LeftShoulder = { rot = Vector3.new(104.8, 0, 33.8) },
					RightHip = { rot = Vector3.new(-10.6, -8, 14.7), pos = Vector3.new(0, 0.38, 0) },
					LeftHip = { rot = Vector3.new(-23.6, 4, 17), pos = Vector3.new(0, -0.09, 0) },
				},
			},
			{
				time = 0.09,
				pose = {
					Root = { rot = Vector3.new(9, -31, -11), pos = Vector3.new(0.18, -0.12, 0.22) },
					Neck = { rot = Vector3.new(-5, 25, 8) },
					RightShoulder = { rot = Vector3.new(149.9, 0, -25.5) },
					LeftShoulder = { rot = Vector3.new(100.9, 0, 34.2) },
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
					LeftShoulder = { rot = Vector3.new(128.9, 0, 51.5) },
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
					LeftShoulder = { rot = Vector3.new(141.8, 0, 58.8) },
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
					LeftShoulder = { rot = Vector3.new(148.4, 0, 61.7) },
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
					LeftShoulder = { rot = Vector3.new(147.5, 0, 59.8) },
					RightHip = { rot = Vector3.new(-8, 24, -19.7), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(16.2, -18, 5.4), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = { rot = Vector3.new(-14, 28, 4), pos = Vector3.new(-0.12, -0.24, -0.38) },
					Neck = { rot = Vector3.new(10, -24, -3) },
					RightShoulder = { rot = Vector3.new(144, 0, -29.6) },
					LeftShoulder = { rot = Vector3.new(137.7, 0, 56.9) },
					RightHip = { rot = Vector3.new(-9.6, 16, -9), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(11.4, -12, 2), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.47,
				pose = {
					Root = { rot = Vector3.new(-11, 2, 1), pos = Vector3.new(-0.02, -0.08, -0.14) },
					Neck = { rot = Vector3.new(7, -2, 0) },
					RightShoulder = { rot = Vector3.new(114.9, 0, -37.4) },
					LeftShoulder = { rot = Vector3.new(120.3, 0, 45.6) },
					RightHip = { rot = Vector3.new(-2.5, 5, -1.4), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(5.8, -3, -0.1), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 0.59,
				pose = {
					Root = { rot = Vector3.new(-5, -18, -1.5), pos = Vector3.new(0.03, 0.02, 0.06) },
					Neck = { rot = Vector3.new(4, 15, 1) },
					RightShoulder = { rot = Vector3.new(112.1, 0, -37.8) },
					LeftShoulder = { rot = Vector3.new(113.6, 0, 34.4) },
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
					RightShoulder = { rot = Vector3.new(110.9, 0, -36.3) },
					LeftShoulder = { rot = Vector3.new(116.2, 0, 37.7) },
					RightHip = { rot = Vector3.new(-0.1, 0, -0.6), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(0.6, 0, -0.6), pos = Vector3.new(0, 0.1, 0) },
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

	-- Block: fists raised side by side in front of the face (about a stud in
	-- front of it, not crossed), chin down. Upper body only: the legs keep
	-- walking. Looped while the "Blocking" attribute is true.
	Block = {
		length = 1.2,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0) },
					Neck = { rot = Vector3.new(-8, 0, 0) },
					RightShoulder = { rot = Vector3.new(132.5, 0, -40) },
					LeftShoulder = { rot = Vector3.new(132.5, 0, 39.5) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(-8, 0, 0) },
					RightShoulder = { rot = Vector3.new(132.5, 0, -40) },
					LeftShoulder = { rot = Vector3.new(132.5, 0, 39.5) },
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
					RightShoulder = { rot = Vector3.new(132.5, 0, -40) },
					LeftShoulder = { rot = Vector3.new(132.5, 0, 39.5) },
				},
			},
			{
				time = 0.04,
				pose = {
					Root = { rot = Vector3.new(-4, -3, 0), pos = Vector3.new(0, 0, 0.08) },
					Neck = { rot = Vector3.new(-2, 2, 0) },
					RightShoulder = { rot = Vector3.new(141, 0, -49.2) },
					LeftShoulder = { rot = Vector3.new(143.5, 0, 53) },
				},
			},
			{
				time = 0.07,
				pose = {
					Root = { rot = Vector3.new(2, -6, -1), pos = Vector3.new(0.02, 0, 0.21) },
					Neck = { rot = Vector3.new(-10, 5, 2) },
					RightShoulder = { rot = Vector3.new(138.6, 0, -52.9) },
					LeftShoulder = { rot = Vector3.new(140.4, 0, 54.8) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(4, -6, -2), pos = Vector3.new(0.03, 0, 0.3) },
					Neck = { rot = Vector3.new(-18, 6, 2) },
					RightShoulder = { rot = Vector3.new(131, 0, -49.2) },
					LeftShoulder = { rot = Vector3.new(132.3, 0, 49.4) },
				},
			},
			{
				time = 0.17,
				pose = {
					Root = { rot = Vector3.new(-3, -2, -1), pos = Vector3.new(0.02, 0, 0.19) },
					Neck = { rot = Vector3.new(-14, 2, 1) },
					RightShoulder = { rot = Vector3.new(128, 0, -44.4) },
					LeftShoulder = { rot = Vector3.new(127.5, 0, 44.8) },
				},
			},
			{
				time = 0.23,
				pose = {
					Root = { rot = Vector3.new(-12, 1, 0), pos = Vector3.new(0, 0, 0.04) },
					Neck = { rot = Vector3.new(-6, -1, 0) },
					RightShoulder = { rot = Vector3.new(132.3, 0, -39.1) },
					LeftShoulder = { rot = Vector3.new(129, 0, 40.8) },
				},
			},
			{
				time = 0.28,
				pose = {
					Root = { rot = Vector3.new(-10, 0, 0) },
					Neck = { rot = Vector3.new(-7, 0, 0) },
					RightShoulder = { rot = Vector3.new(135.6, 0, -40.3) },
					LeftShoulder = { rot = Vector3.new(132.8, 0, 39.1) },
				},
			},
			{
				time = 0.32,
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0) },
					Neck = { rot = Vector3.new(-8, 0, 0) },
					RightShoulder = { rot = Vector3.new(132.5, 0, -40) },
					LeftShoulder = { rot = Vector3.new(132.5, 0, 39.5) },
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
					RightShoulder = { rot = Vector3.new(132.5, 0, -40) },
					LeftShoulder = { rot = Vector3.new(132.5, 0, 39.5) },
				},
			},
			{
				time = 0.08,
				pose = {
					Root = { rot = Vector3.new(-4, -16, 0) },
					Neck = { rot = Vector3.new(0, 14, 0) },
					RightShoulder = { rot = Vector3.new(132.1, 0, -7.6) },
					LeftShoulder = { rot = Vector3.new(97.2, 0, 39.8) },
				},
			},
			{
				time = 0.26,
				pose = {
					Root = { rot = Vector3.new(-4, -16, 0) },
					Neck = { rot = Vector3.new(0, 14, 0) },
					RightShoulder = { rot = Vector3.new(132.1, 0, -7.6) },
					LeftShoulder = { rot = Vector3.new(97.2, 0, 39.8) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(92, 0, -36) },
					LeftShoulder = { rot = Vector3.new(97.2, 0, 39.8) },
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
					RightShoulder = { rot = Vector3.new(132.5, 0, -40) },
					LeftShoulder = { rot = Vector3.new(132.5, 0, 39.5) },
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

	-- Took a punch to the body: the torso folds forward, the head drops late, the arms
	-- cover the belly. Upper body only.
	HitBody = {
		length = 0.5,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-7, -4, 1), pos = Vector3.new(0, 0, 0.03) },
					Neck = { rot = Vector3.new(6, 4, 0) },
					RightShoulder = { rot = Vector3.new(80, 0, -46) },
					LeftShoulder = { rot = Vector3.new(76, 0, 36) },
				},
			},
			{
				time = 0.04,
				pose = {
					Root = { rot = Vector3.new(-15, -3, 3), pos = Vector3.new(0, 0, 0.1) },
					Neck = { rot = Vector3.new(14, 2, -1) },
					RightShoulder = { rot = Vector3.new(70, 0, -46) },
					LeftShoulder = { rot = Vector3.new(66, 0, 40) },
				},
			},
			{
				time = 0.07,
				pose = {
					Root = { rot = Vector3.new(-23, -5, 7), pos = Vector3.new(0, 0, 0.17) },
					Neck = { rot = Vector3.new(-4, 3, 0) },
					RightShoulder = { rot = Vector3.new(60, 0, -44) },
					LeftShoulder = { rot = Vector3.new(55, 0, 40) },
				},
			},
			{
				time = 0.14,
				pose = {
					Root = { rot = Vector3.new(-21, -4, 8), pos = Vector3.new(0, 0, 0.21) },
					Neck = { rot = Vector3.new(-44, 3, 3) },
					RightShoulder = { rot = Vector3.new(56, 0, -42) },
					LeftShoulder = { rot = Vector3.new(49, 0, 38) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-16, -1, 7), pos = Vector3.new(0, 0, 0.2) },
					Neck = { rot = Vector3.new(-50, 1, 5) },
					RightShoulder = { rot = Vector3.new(54, 0, -40) },
					LeftShoulder = { rot = Vector3.new(47, 0, 37) },
				},
			},
			{
				time = 0.27,
				pose = {
					Root = { rot = Vector3.new(-21, 1, 7), pos = Vector3.new(0, 0, 0.17) },
					Neck = { rot = Vector3.new(-38, -1, 6) },
					RightShoulder = { rot = Vector3.new(52, 0, -37) },
					LeftShoulder = { rot = Vector3.new(45, 0, 34) },
				},
			},
			{
				time = 0.34,
				pose = {
					Root = { rot = Vector3.new(-10, 1, 5), pos = Vector3.new(0, 0, 0.11) },
					Neck = { rot = Vector3.new(-18, 0, 4) },
					RightShoulder = { rot = Vector3.new(32, 0, -18) },
					LeftShoulder = { rot = Vector3.new(27, 0, 15) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(-12, 0, 5), pos = Vector3.new(0, 0, 0.05) },
					Neck = { rot = Vector3.new(-21, 0, 6) },
					RightShoulder = { rot = Vector3.new(15, 0, 0) },
					LeftShoulder = { rot = Vector3.new(12, 0, -2) },
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

	-- Finishing a knocked-out opponent: drop on one knee, fist raised, hammer blow to
	-- the ground at 0.45 s = Config.Knockout.FINISH_IMPACT, then stand back up into the guard.
	Finisher = {
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
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = { rot = Vector3.new(-1, -24, 0), pos = Vector3.new(0, 0.06, -0.22) },
					Neck = { rot = Vector3.new(2, 18, 0) },
					RightShoulder = { rot = Vector3.new(124.3, 0, -31.4) },
					LeftShoulder = { rot = Vector3.new(117.9, 0, 35.2) },
					RightHip = { rot = Vector3.new(-12.2, 0, 6.4), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(4.8, 0, -5.1), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-4, -26, 3), pos = Vector3.new(0.05, -0.4, -0.63) },
					Neck = { rot = Vector3.new(10, 22, 0) },
					RightShoulder = { rot = Vector3.new(183.9, 0, -10.2) },
					LeftShoulder = { rot = Vector3.new(112.8, 0, 33.2) },
					RightHip = { rot = Vector3.new(-18.9, 0, 5.6), pos = Vector3.new(0, 0.49, 0) },
					LeftHip = { rot = Vector3.new(13, 0, -14.5), pos = Vector3.new(0, 0.67, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(6, -22, 5), pos = Vector3.new(0.1, -0.55, -0.68) },
					Neck = { rot = Vector3.new(14, 18, 0) },
					RightShoulder = { rot = Vector3.new(181.2, 0, 2.7) },
					LeftShoulder = { rot = Vector3.new(144.5, 0, 32.2) },
					RightHip = { rot = Vector3.new(-32.7, 0, 5.6), pos = Vector3.new(0, 0.62, 0) },
					LeftHip = { rot = Vector3.new(4.3, 0, -13), pos = Vector3.new(0, 0.8, 0) },
				},
			},
			{
				time = 0.38,
				pose = {
					Root = { rot = Vector3.new(-34, 2, 2), pos = Vector3.new(0, -0.98, -0.79) },
					Neck = { rot = Vector3.new(24, 8, 0) },
					RightShoulder = { rot = Vector3.new(176, 0, 10) },
					LeftShoulder = { rot = Vector3.new(146.8, 0, 34.3) },
					RightHip = { rot = Vector3.new(-2.6, 0, -2.2), pos = Vector3.new(0, 0.85, 0) },
					LeftHip = { rot = Vector3.new(49.8, 0, -1.1), pos = Vector3.new(0, 1.07, 0) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = { rot = Vector3.new(-55, 14, -3), pos = Vector3.new(0, -1.15, -0.85) },
					Neck = { rot = Vector3.new(34, -14, 0) },
					RightShoulder = { rot = Vector3.new(99.4, 0, -18.7) },
					LeftShoulder = { rot = Vector3.new(154.7, 0, 37.5) },
					RightHip = { rot = Vector3.new(7.8, 0, 5.2), pos = Vector3.new(0, 1.18, 0) },
					LeftHip = { rot = Vector3.new(71.5, 0, 11.9), pos = Vector3.new(0, 1.02, 0) },
				},
			},
			{
				time = 0.54,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-58, 16, -4), pos = Vector3.new(0, -1.25, -0.86) },
					Neck = { rot = Vector3.new(36, -16, 0) },
					RightShoulder = { rot = Vector3.new(100.1, 0, -19.3) },
					LeftShoulder = { rot = Vector3.new(153.9, 0, 37.7) },
					RightHip = { rot = Vector3.new(6.5, 0, 5.9), pos = Vector3.new(0, 1.29, 0) },
					LeftHip = { rot = Vector3.new(70.6, 0, 13.5), pos = Vector3.new(0, 1.16, 0) },
				},
			},
			{
				time = 0.66,
				pose = {
					Root = { rot = Vector3.new(-46, 8, -2), pos = Vector3.new(0, -1.18, -0.85) },
					Neck = { rot = Vector3.new(28, -8, 0) },
					RightShoulder = { rot = Vector3.new(161, 0, -41.7) },
					LeftShoulder = { rot = Vector3.new(151.8, 0, 36.1) },
					RightHip = { rot = Vector3.new(2.1, 0, 1.8), pos = Vector3.new(0, 1.13, 0) },
					LeftHip = { rot = Vector3.new(57.6, 0, 5.9), pos = Vector3.new(0, 1.2, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = { rot = Vector3.new(-22, -4, 0), pos = Vector3.new(0, -0.5, -0.7) },
					Neck = { rot = Vector3.new(14, 8, 0) },
					RightShoulder = { rot = Vector3.new(138.5, 0, -37) },
					LeftShoulder = { rot = Vector3.new(117.6, 0, 37.2) },
					RightHip = { rot = Vector3.new(-5.9, 0, 0.4), pos = Vector3.new(0, 0.47, 0) },
					LeftHip = { rot = Vector3.new(44.2, 0, -4.3), pos = Vector3.new(0, 0.64, 0) },
				},
			},
			{
				time = 0.92,
				pose = {
					Root = { rot = Vector3.new(-3, -15, 0), pos = Vector3.new(0, 0.02, -0.3) },
					Neck = { rot = Vector3.new(4, 11, 0) },
					RightShoulder = { rot = Vector3.new(116.7, 0, -39.9) },
					LeftShoulder = { rot = Vector3.new(117.7, 0, 38.2) },
					RightHip = { rot = Vector3.new(-14.9, 0, 4.2), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-2, 0, 0), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 1.01,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-9, -11, 0), pos = Vector3.new(0, -0.06, -0.04) },
					Neck = { rot = Vector3.new(7, 10, 0) },
					RightShoulder = { rot = Vector3.new(111.2, 0, -35.9) },
					LeftShoulder = { rot = Vector3.new(114.3, 0, 36.6) },
					RightHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 1.1,
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

	-- Getting back up after a knock-out (played when the ragdoll ends): from one knee,
	-- a failed push, then up with an off-balance step, ending dazed.
	GetUp = {
		length = 0.9,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-47, 12, 19), pos = Vector3.new(-0.28, -1.38, 1.33) },
					Neck = { rot = Vector3.new(-30, -6, 0) },
					RightShoulder = { rot = Vector3.new(89.4, 0, -30.5) },
					LeftShoulder = { rot = Vector3.new(66.2, 0, 23.8) },
					RightHip = { rot = Vector3.new(34.4, 0, 15.3), pos = Vector3.new(0, 1.83, 0) },
					LeftHip = { rot = Vector3.new(-22, 0, -3), pos = Vector3.new(0, 0.54, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-32, 10, 9), pos = Vector3.new(-0.15, -0.94, 1.24) },
					Neck = { rot = Vector3.new(-24, -4, 2) },
					RightShoulder = { rot = Vector3.new(55.2, 0, -31.5) },
					LeftShoulder = { rot = Vector3.new(40.8, 0, 22.9) },
					RightHip = { rot = Vector3.new(37.9, 0, 11.1), pos = Vector3.new(0, 1.15, 0) },
					LeftHip = { rot = Vector3.new(-36.3, 0, 2.9), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 0.23,
				pose = {
					Root = { rot = Vector3.new(-50, 9, 24), pos = Vector3.new(-0.32, -1.44, 1.36) },
					Neck = { rot = Vector3.new(-42, 6, 4) },
					RightShoulder = { rot = Vector3.new(94.7, 0, -28.3) },
					LeftShoulder = { rot = Vector3.new(88.1, 0, 30.2) },
					RightHip = { rot = Vector3.new(35, 0, 14.3), pos = Vector3.new(0, 1.9, 0) },
					LeftHip = { rot = Vector3.new(-19.3, 0, -5.4), pos = Vector3.new(0, 0.65, 0) },
				},
			},
			{
				time = 0.32,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-52, 9, 19), pos = Vector3.new(-0.24, -1.41, 1.32) },
					Neck = { rot = Vector3.new(-34, 0, 0) },
					RightShoulder = { rot = Vector3.new(100.1, 0, -31.1) },
					LeftShoulder = { rot = Vector3.new(78.3, 0, 19.3) },
					RightHip = { rot = Vector3.new(36.6, 0, 13.9), pos = Vector3.new(0, 1.95, 0) },
					LeftHip = { rot = Vector3.new(-16.3, 0, -2.5), pos = Vector3.new(0, 0.55, 0) },
				},
			},
			{
				time = 0.43,
				pose = {
					Root = { rot = Vector3.new(-30, -4, -5), pos = Vector3.new(0.1, -0.7, 0.75) },
					Neck = { rot = Vector3.new(-36, 4, -2) },
					RightShoulder = { rot = Vector3.new(14, 0, 14) },
					LeftShoulder = { rot = Vector3.new(30, 0, -22) },
					RightHip = { rot = Vector3.new(35.4, 0, 6.3), pos = Vector3.new(0, 0.82, 0) },
					LeftHip = { rot = Vector3.new(-20.9, 0, 12.7), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = { rot = Vector3.new(-17, -9, -10), pos = Vector3.new(0.32, -0.26, 0.3) },
					Neck = { rot = Vector3.new(-32, 8, -7) },
					RightShoulder = { rot = Vector3.new(24, 0, 26) },
					LeftShoulder = { rot = Vector3.new(26, 0, -20) },
					RightHip = { rot = Vector3.new(12.8, 0, 8.8), pos = Vector3.new(0, 0.41, 0) },
					LeftHip = { rot = Vector3.new(-6, 0, 2.7), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.64,
				pose = {
					Root = { rot = Vector3.new(-20, -2, 9), pos = Vector3.new(-0.1, -0.31, 0.1) },
					Neck = { rot = Vector3.new(-28, 2, 9) },
					RightShoulder = { rot = Vector3.new(16, 0, 12) },
					LeftShoulder = { rot = Vector3.new(14, 0, -12) },
					RightHip = { rot = Vector3.new(9.3, 0, -1.8), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(7.4, 0, -1.2), pos = Vector3.new(0, 0.47, 0) },
				},
			},
			{
				time = 0.76,
				pose = {
					Root = { rot = Vector3.new(-11, 1, 3), pos = Vector3.new(0.02, -0.04, 0.02) },
					Neck = { rot = Vector3.new(-6, -3, 4) },
					RightShoulder = { rot = Vector3.new(12, 0, 8) },
					LeftShoulder = { rot = Vector3.new(9, 0, -8) },
					RightHip = { rot = Vector3.new(-4.6, 0, 2.3), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(-4.8, 0, 2.4), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = { rot = Vector3.new(-15, 0, 6), pos = Vector3.new(0, -0.03, 0.01) },
					Neck = { rot = Vector3.new(-26, 1, 7) },
					RightShoulder = { rot = Vector3.new(9, 0, 5) },
					LeftShoulder = { rot = Vector3.new(8, 0, -5) },
					RightHip = { rot = Vector3.new(1.4, 0, -1.3), pos = Vector3.new(0, 0.03, 0) },
					LeftHip = { rot = Vector3.new(0.8, 0, -1), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.9,
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
					RightShoulder = { rot = Vector3.new(99.7, 0, -41) },
					LeftShoulder = { rot = Vector3.new(97.3, 0, 33.8) },
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
					RightShoulder = { rot = Vector3.new(106.5, 0, -27.6) },
					LeftShoulder = { rot = Vector3.new(101.2, 0, 23.8) },
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
					RightShoulder = { rot = Vector3.new(104.9, 0, -38.3) },
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
	-- BEGIN Street Brawler kit (generated by add_kit_clips.py)
	-- BOTTLE SMASH (key 1): bottle pulled from the hip, raised over the right
	-- shoulder, smashed down on the head with the whole body. Impact 0.32 s.
	Brawler_Bottle = {
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
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = { rot = Vector3.new(-12, -32, -6), pos = Vector3.new(0.1, -0.14, 0.06) },
					Neck = { rot = Vector3.new(8, 28, 4) },
					RightShoulder = { rot = Vector3.new(-13.06, 0, 17.53) },
					LeftShoulder = { rot = Vector3.new(142.25, 0, 42.17) },
					RightHip = { rot = Vector3.new(6.8, -8, 2.5), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(0.1, -4, 3.5), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(3, -36, -3), pos = Vector3.new(0.16, -0.12, 0.2) },
					Neck = { rot = Vector3.new(-3, 31, 2) },
					RightShoulder = { rot = Vector3.new(100, 0, 52) },
					LeftShoulder = { rot = Vector3.new(131.7, 0, 33.6) },
					RightHip = { rot = Vector3.new(-6.7, -10, 7.5), pos = Vector3.new(0, 0.29, 0) },
					LeftHip = { rot = Vector3.new(-14.3, -6, 7.2), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.25,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(12, -30, 4), pos = Vector3.new(0.2, -0.06, 0.32) },
					Neck = { rot = Vector3.new(-11, 26, -2) },
					RightShoulder = { rot = Vector3.new(186, 0, 10) },
					LeftShoulder = { rot = Vector3.new(122.4, 0, 34.3) },
					RightHip = { rot = Vector3.new(-18.6, -10, 1.6), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(-16.3, -6, -4.6), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.28,
				pose = {
					Root = { rot = Vector3.new(-9, 4, 1), pos = Vector3.new(0.06, -0.22, -0.4) },
					Neck = { rot = Vector3.new(5, -3, 0) },
					RightShoulder = { rot = Vector3.new(200, 0, 6) },
					LeftShoulder = { rot = Vector3.new(130.2, 0, 53.3) },
					RightHip = { rot = Vector3.new(-16.3, 3, -2.8), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(18.3, -9, -2.3), pos = Vector3.new(0, 0.38, 0) },
				},
			},
			{
				time = 0.32,
				pose = {
					Root = { rot = Vector3.new(-19, 24, 6), pos = Vector3.new(-0.04, -0.3, -0.74) },
					Neck = { rot = Vector3.new(16, -20, -3) },
					RightShoulder = { rot = Vector3.new(140.6, 0, -17.1) },
					LeftShoulder = { rot = Vector3.new(135.5, 0, 63.7) },
					RightHip = {
						rot = Vector3.new(-13.5, 10, -12.5),
						pos = Vector3.new(0, 0.17, 0),
					},
					LeftHip = { rot = Vector3.new(29.8, -11, 3.1), pos = Vector3.new(0, 0.32, 0) },
				},
			},
			{
				time = 0.35,
				pose = {
					Root = { rot = Vector3.new(-25, 30, 7), pos = Vector3.new(-0.08, -0.38, -0.88) },
					Neck = { rot = Vector3.new(21, -26, -5) },
					RightShoulder = { rot = Vector3.new(149.1, 0, -25.9) },
					LeftShoulder = { rot = Vector3.new(137.8, 0, 67.4) },
					RightHip = { rot = Vector3.new(-9.3, 12, -12.4), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(34.4, -12, 7.5), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.44,
				pose = {
					Root = { rot = Vector3.new(-30, 36, 8), pos = Vector3.new(-0.12, -0.44, -1) },
					Neck = { rot = Vector3.new(24, -30, -5) },
					RightShoulder = { rot = Vector3.new(40, 0, -58) },
					LeftShoulder = { rot = Vector3.new(138.2, 0, 70.1) },
					RightHip = { rot = Vector3.new(-4.1, 14, -9.8), pos = Vector3.new(0, 0.37, 0) },
					LeftHip = { rot = Vector3.new(38.4, -14, 11.8), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.53,
				pose = {
					Root = { rot = Vector3.new(-21, 16, 2), pos = Vector3.new(-0.08, -0.32, -0.76) },
					Neck = { rot = Vector3.new(14, -6, -9) },
					RightShoulder = { rot = Vector3.new(52, 0, 58) },
					LeftShoulder = { rot = Vector3.new(133.1, 0, 61.6) },
					RightHip = { rot = Vector3.new(-1.5, 10, -1.4), pos = Vector3.new(0, 0.37, 0) },
					LeftHip = { rot = Vector3.new(29.7, -10, 5.6), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.64,
				pose = {
					Root = { rot = Vector3.new(-12, 3, 1), pos = Vector3.new(0, -0.16, -0.26) },
					Neck = { rot = Vector3.new(8, -4, 2) },
					RightShoulder = { rot = Vector3.new(138, 0, -18) },
					LeftShoulder = { rot = Vector3.new(120, 0, 38) },
					RightHip = { rot = Vector3.new(-0.6, 3, -1.8), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(13.4, -3, -1), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.77,
				pose = {
					Root = { rot = Vector3.new(-5, -17, -2), pos = Vector3.new(0.03, 0.02, 0.06) },
					Neck = { rot = Vector3.new(4, 14, 1) },
					RightShoulder = { rot = Vector3.new(123.83, 0, -45.61) },
					LeftShoulder = { rot = Vector3.new(121.83, 0, 36.58) },
					RightHip = { rot = Vector3.new(-2.1, -1, 3), pos = Vector3.new(0, 0.07, 0) },
					LeftHip = { rot = Vector3.new(-3.6, 1, 2.7), pos = Vector3.new(0, 0.02, 0) },
				},
			},
			{
				time = 0.9,
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
	-- HEADBUTT (key 2): hands to the collar, pull back, head snaps forward and
	-- down with the whole upper body. Impact 0.22 s.
	Brawler_Headbutt = {
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
				time = 0.07,
				pose = {
					Root = { rot = Vector3.new(-5, -8, 1), pos = Vector3.new(0.02, -0.03, -0.16) },
					Neck = { rot = Vector3.new(8, 6, 1) },
					RightShoulder = { rot = Vector3.new(97.78, 0, -21.32) },
					LeftShoulder = { rot = Vector3.new(108.35, 0, 15.31) },
					RightHip = {
						rot = Vector3.new(-11.3, -3, -0.75),
						pos = Vector3.new(0, 0.09, 0),
					},
					LeftHip = { rot = Vector3.new(-6.67, 0, -0.9), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.14,
				pose = {
					Root = { rot = Vector3.new(16, -14, 3), pos = Vector3.new(0.03, 0.03, 0.19) },
					Neck = { rot = Vector3.new(29, 11, 2) },
					RightShoulder = { rot = Vector3.new(80.35, 0, -42.93) },
					LeftShoulder = { rot = Vector3.new(82.36, 0, 18.09) },
					RightHip = {
						rot = Vector3.new(-29.58, -4, 2.07),
						pos = Vector3.new(0, 0.05, 0),
					},
					LeftHip = { rot = Vector3.new(-25.88, 0, 1.69), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 0.19,
				pose = {
					Root = { rot = Vector3.new(-9, -3, 0), pos = Vector3.new(0, -0.07, -0.6) },
					Neck = { rot = Vector3.new(16, 1, 0) },
					RightShoulder = { rot = Vector3.new(112, 0, -30.7) },
					LeftShoulder = { rot = Vector3.new(113.4, 0, 26.2) },
					RightHip = {
						rot = Vector3.new(-13.24, -4, 0.31),
						pos = Vector3.new(0, 0.18, 0),
					},
					LeftHip = { rot = Vector3.new(6.36, 0, 0.82), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.22,
				pose = {
					Root = { rot = Vector3.new(-22, 5, -1), pos = Vector3.new(0, -0.12, -1.15) },
					Neck = { rot = Vector3.new(-18, -4, 0) },
					RightShoulder = { rot = Vector3.new(122.7, 0, -25.8) },
					LeftShoulder = { rot = Vector3.new(120.2, 0, 32.4) },
					RightHip = { rot = Vector3.new(-5.07, -5, 0.8), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(20.2, 0, 4.27), pos = Vector3.new(0, 0.01, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = { rot = Vector3.new(-24.5, 7, -1.5), pos = Vector3.new(0, -0.15, -1.2) },
					Neck = { rot = Vector3.new(-21, -6, 0) },
					RightShoulder = { rot = Vector3.new(114.5, 0, -29.5) },
					LeftShoulder = { rot = Vector3.new(111.6, 0, 38.6) },
					RightHip = { rot = Vector3.new(-3.36, -5, 1.61), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(23.22, 0, 5.94), pos = Vector3.new(0, -0.01, 0) },
				},
			},
			{
				time = 0.31,
				pose = {
					Root = { rot = Vector3.new(-10, 2, 3), pos = Vector3.new(0, -0.13, -0.88) },
					Neck = { rot = Vector3.new(12, 12, 7) },
					RightShoulder = { rot = Vector3.new(82, 0, -30) },
					LeftShoulder = { rot = Vector3.new(86, 0, 28) },
					RightHip = {
						rot = Vector3.new(-15.12, -4, -5.05),
						pos = Vector3.new(0, 0.09, 0),
					},
					LeftHip = { rot = Vector3.new(8.25, 0, -2.79), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.39,
				pose = {
					Root = { rot = Vector3.new(-5, 7, -4), pos = Vector3.new(0, -0.08, -0.5) },
					Neck = { rot = Vector3.new(5, 32, 13) },
					RightShoulder = { rot = Vector3.new(106, 0, -42) },
					LeftShoulder = { rot = Vector3.new(108, 0, 36) },
					RightHip = {
						rot = Vector3.new(-12.71, -2, 3.81),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = { rot = Vector3.new(-0.5, 0, 6.37), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.46,
				pose = {
					Root = { rot = Vector3.new(-7, -11, 4), pos = Vector3.new(0, -0.06, -0.18) },
					Neck = { rot = Vector3.new(8, -22, -12) },
					RightShoulder = { rot = Vector3.new(118.98, 0, -45.98) },
					LeftShoulder = { rot = Vector3.new(116.99, 0, 34) },
					RightHip = { rot = Vector3.new(-3.62, 0, -5.06), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(-4.45, 0, -4.72), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.53,
				pose = {
					Root = { rot = Vector3.new(-9, -14, -1.5), pos = Vector3.new(0, -0.05, 0.02) },
					Neck = { rot = Vector3.new(6, 15, 5) },
					RightShoulder = { rot = Vector3.new(123.79, 0, -47.06) },
					LeftShoulder = { rot = Vector3.new(121.62, 0, 35.81) },
					RightHip = { rot = Vector3.new(2.13, 0, 1.76), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(0.97, 0, 1.81), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = { rot = Vector3.new(-8.5, -11, 0.5), pos = Vector3.new(0, -0.03, 0) },
					Neck = { rot = Vector3.new(7, 7, -1) },
					RightShoulder = { rot = Vector3.new(118.86, 0, -41.99) },
					LeftShoulder = { rot = Vector3.new(119.67, 0, 38.02) },
					RightHip = { rot = Vector3.new(0.23, 0, -0.84), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(0.58, 0, -0.79), pos = Vector3.new(0, 0.11, 0) },
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
	-- TACKLE (key 3): low shoulder charge, torso almost flat, arms wrapping.
	-- Charge 0.10 to 0.55 s (the server checks contact meanwhile).
	Brawler_Tackle = {
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
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(-15, -25, 3), pos = Vector3.new(0, -0.36, 0.1) },
					Neck = { rot = Vector3.new(12.8, 20, -2) },
					RightShoulder = { rot = Vector3.new(21.66, 0, -1.99) },
					LeftShoulder = { rot = Vector3.new(23.07, 0, -21.98) },
					RightHip = { rot = Vector3.new(11.51, 0, -8.12), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(6.28, 0, -7.78), pos = Vector3.new(0, 0.55, 0) },
				},
			},
			{
				time = 0.11,
				pose = {
					Root = { rot = Vector3.new(-41, -18, 4), pos = Vector3.new(0, -0.64, -0.25) },
					Neck = { rot = Vector3.new(47.5, 15, -3) },
					RightShoulder = { rot = Vector3.new(76.08, 0, 0.39) },
					LeftShoulder = { rot = Vector3.new(91.87, 0, -30.06) },
					RightHip = { rot = Vector3.new(8.34, 0, -7.23), pos = Vector3.new(0, 0.44, 0) },
					LeftHip = { rot = Vector3.new(36.61, 0, -15.11), pos = Vector3.new(0, 0.9, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(-56, -17, 3), pos = Vector3.new(0, -0.98, -0.4) },
					Neck = { rot = Vector3.new(63.7, 14, -3) },
					RightShoulder = { rot = Vector3.new(123, 0, 10.6) },
					LeftShoulder = { rot = Vector3.new(173.2, 0, -28.9) },
					RightHip = { rot = Vector3.new(30.28, 0, -9.75), pos = Vector3.new(0, 1.63, 0) },
					LeftHip = { rot = Vector3.new(18.82, 0, -8.54), pos = Vector3.new(0, 1.27, 0) },
				},
			},
			{
				time = 0.27,
				pose = {
					Root = { rot = Vector3.new(-59, -11, -2), pos = Vector3.new(0, -0.82, -0.44) },
					Neck = { rot = Vector3.new(63.7, 9, 2) },
					RightShoulder = { rot = Vector3.new(130.3, 0, 2.9) },
					LeftShoulder = { rot = Vector3.new(161.6, 0, -24.7) },
					RightHip = { rot = Vector3.new(58.94, 0, -8.34), pos = Vector3.new(0, 1, 0) },
					LeftHip = { rot = Vector3.new(9.3, 0, 0.84), pos = Vector3.new(0, 0.37, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = { rot = Vector3.new(-57, -18, 4), pos = Vector3.new(0, -1, -0.46) },
					Neck = { rot = Vector3.new(64.3, 14, -3) },
					RightShoulder = { rot = Vector3.new(128.9, 0, -8.4) },
					LeftShoulder = { rot = Vector3.new(156.9, 0, -11.3) },
					RightHip = {
						rot = Vector3.new(34.19, 0, -13.36),
						pos = Vector3.new(0, 0.67, 0),
					},
					LeftHip = { rot = Vector3.new(16.8, 0, -7.06), pos = Vector3.new(0, 1.9, 0) },
				},
			},
			{
				time = 0.46,
				pose = {
					Root = { rot = Vector3.new(-63, -12, -1), pos = Vector3.new(0, -0.84, -0.5) },
					Neck = { rot = Vector3.new(67.2, 10, 1) },
					RightShoulder = { rot = Vector3.new(135, 0, -22.2) },
					LeftShoulder = { rot = Vector3.new(148.4, 0, 7.8) },
					RightHip = { rot = Vector3.new(19.66, 0, -2.74), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(39.64, 0, -7.46), pos = Vector3.new(0, 1.77, 0) },
				},
			},
			{
				time = 0.55,
				pose = {
					Root = { rot = Vector3.new(-51, -16, 2), pos = Vector3.new(0, -0.96, -0.55) },
					Neck = { rot = Vector3.new(56.6, 13, -2) },
					RightShoulder = { rot = Vector3.new(126.1, 0, -59.5) },
					LeftShoulder = { rot = Vector3.new(124.5, 0, 33.2) },
					RightHip = { rot = Vector3.new(12.05, 0, -5.45), pos = Vector3.new(0, 0.6, 0) },
					LeftHip = { rot = Vector3.new(36.53, 0, -11.37), pos = Vector3.new(0, 1.41, 0) },
				},
			},
			{
				time = 0.64,
				pose = {
					Root = { rot = Vector3.new(-26, -17, 2), pos = Vector3.new(0, -0.5, -0.46) },
					Neck = { rot = Vector3.new(28.3, 13, 0) },
					RightShoulder = { rot = Vector3.new(100, 0, -46) },
					LeftShoulder = { rot = Vector3.new(106, 0, 36) },
					RightHip = { rot = Vector3.new(5.02, 0, -3.58), pos = Vector3.new(0, 0.58, 0) },
					LeftHip = { rot = Vector3.new(25.66, 0, -10.18), pos = Vector3.new(0, 0.64, 0) },
				},
			},
			{
				time = 0.73,
				pose = {
					Root = { rot = Vector3.new(1, -9, -2), pos = Vector3.new(0, -0.2, -0.12) },
					Neck = { rot = Vector3.new(-1.3, 8, 1) },
					RightShoulder = { rot = Vector3.new(129.77, 0, -48.35) },
					LeftShoulder = { rot = Vector3.new(127.05, 0, 39.76) },
					RightHip = { rot = Vector3.new(-17.17, 0, 5.15), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(-8.91, 0, 4.15), pos = Vector3.new(0, 0.33, 0) },
				},
			},
			{
				time = 0.82,
				pose = {
					Root = { rot = Vector3.new(-9, -14, 0.5), pos = Vector3.new(0, -0.07, -0.03) },
					Neck = { rot = Vector3.new(7, 11.5, -0.5) },
					RightShoulder = { rot = Vector3.new(114.71, 0, -39.29) },
					LeftShoulder = { rot = Vector3.new(116.86, 0, 36.72) },
					RightHip = { rot = Vector3.new(0.64, 0, -0.77), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-0.53, 0, -0.69), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.9,
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
	-- DIRTY KICK (key 4): short mean kick to the shin. Impact 0.20 s.
	Brawler_DirtyKick = {
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
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-14, -26, -4),
						pos = Vector3.new(-0.05, -0.15, -0.06),
					},
					Neck = { rot = Vector3.new(11, 22, 4) },
					RightShoulder = { rot = Vector3.new(121.36, 0, -44.19) },
					LeftShoulder = { rot = Vector3.new(120.87, 0, 38.42) },
					RightHip = { rot = Vector3.new(8.56, 0, 4.83), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(1.99, 0, 4.89), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(4, 0, 9), pos = Vector3.new(-0.18, -0.12, -0.1) },
					Neck = { rot = Vector3.new(-5, 0, -8) },
					RightShoulder = { rot = Vector3.new(119.97, 0, -28.59) },
					LeftShoulder = { rot = Vector3.new(120.76, 0, 44.81) },
					RightHip = { rot = Vector3.new(0.22, 0, 14.73), pos = Vector3.new(0, 0.84, 0) },
					LeftHip = { rot = Vector3.new(-16.7, -4, -6.49), pos = Vector3.new(0, 0.32, 0) },
				},
			},
			{
				time = 0.16,
				pose = {
					Root = { rot = Vector3.new(16, 16, 13), pos = Vector3.new(-0.3, -0.08, -0.2) },
					Neck = { rot = Vector3.new(-15, -13, -13) },
					RightShoulder = { rot = Vector3.new(104, 0, 4) },
					LeftShoulder = { rot = Vector3.new(112.1, 0, 55.4) },
					RightHip = { rot = Vector3.new(7.66, 0, 14.84), pos = Vector3.new(0, 0.75, 0) },
					LeftHip = {
						rot = Vector3.new(-34.38, -8, -16.24),
						pos = Vector3.new(0, 0.38, 0),
					},
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(23, 28, 14), pos = Vector3.new(-0.38, -0.02, -0.26) },
					Neck = { rot = Vector3.new(-23, -24, -15) },
					RightShoulder = { rot = Vector3.new(92, 0, 22) },
					LeftShoulder = { rot = Vector3.new(107.8, 0, 62.8) },
					RightHip = { rot = Vector3.new(20.94, 0, 8.03), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = {
						rot = Vector3.new(-45.41, -10, -25.65),
						pos = Vector3.new(0, 0.38, 0),
					},
				},
			},
			{
				time = 0.24,
				pose = {
					Root = { rot = Vector3.new(24, 31, 13), pos = Vector3.new(-0.38, -0.05, -0.28) },
					Neck = { rot = Vector3.new(-24, -27, -14) },
					RightShoulder = { rot = Vector3.new(90, 0, 24) },
					LeftShoulder = { rot = Vector3.new(107.4, 0, 64.4) },
					RightHip = { rot = Vector3.new(16.69, 0, -4.18) },
					LeftHip = {
						rot = Vector3.new(-45.66, -10, -26.89),
						pos = Vector3.new(0, 0.43, 0),
					},
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(7, 9, 6), pos = Vector3.new(-0.2, -0.12, -0.2) },
					Neck = { rot = Vector3.new(-7, -7, -6) },
					RightShoulder = { rot = Vector3.new(120, 0, -32) },
					LeftShoulder = { rot = Vector3.new(118.6, 0, 48.3) },
					RightHip = { rot = Vector3.new(7.46, 0, 0.14), pos = Vector3.new(0, 0.62, 0) },
					LeftHip = { rot = Vector3.new(-21.83, -6, -5.4), pos = Vector3.new(0, 0.29, 0) },
				},
			},
			{
				time = 0.37,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-15, -8, -2),
						pos = Vector3.new(-0.04, -0.24, -0.14),
					},
					Neck = { rot = Vector3.new(11, 6, 2) },
					RightShoulder = { rot = Vector3.new(129.65, 0, -48.75) },
					LeftShoulder = { rot = Vector3.new(126.8, 0, 38.98) },
					RightHip = { rot = Vector3.new(3.28, 0, 3.2), pos = Vector3.new(0, 0.33, 0) },
					LeftHip = { rot = Vector3.new(5.91, -2, 3.32), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.46,
				pose = {
					Root = { rot = Vector3.new(-7, -14, 0.8), pos = Vector3.new(0, -0.03, -0.04) },
					Neck = { rot = Vector3.new(5, 12, -1) },
					RightShoulder = { rot = Vector3.new(123.5, 0, -45.42) },
					LeftShoulder = { rot = Vector3.new(122.09, 0, 38.03) },
					RightHip = { rot = Vector3.new(-2.36, 0, -0.47), pos = Vector3.new(0, 0.07, 0) },
					LeftHip = { rot = Vector3.new(-3.47, 0, -0.41), pos = Vector3.new(0, 0.12, 0) },
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
	-- STREET FURY activation (G): neck cracks, shoulders roll, a lower, wider guard.
	Brawler_Awaken = {
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
				time = 0.07,
				pose = {
					Root = { rot = Vector3.new(-3, -12, 0), pos = Vector3.new(0, 0.03, 0.02) },
					Neck = { rot = Vector3.new(14, 10, 0) },
					RightShoulder = {
						rot = Vector3.new(117.28, 0, -22.52),
						pos = Vector3.new(0, 0.06, 0.03),
					},
					LeftShoulder = {
						rot = Vector3.new(117.95, 0, 21.51),
						pos = Vector3.new(0, 0.06, 0.03),
					},
					RightHip = {
						rot = Vector3.new(-4.89, -0.04, 1.04),
						pos = Vector3.new(0.01, 0.03, 0.07),
					},
					LeftHip = {
						rot = Vector3.new(-4.89, -0.04, 1.04),
						pos = Vector3.new(0.01, 0.02, 0.07),
					},
				},
			},
			{
				time = 0.21,
				pose = {
					Root = { rot = Vector3.new(-17, -6, -3), pos = Vector3.new(0.02, -0.1, -0.02) },
					Neck = { rot = Vector3.new(-30, 4, 10) },
					RightShoulder = {
						rot = Vector3.new(10, 0, 10),
						pos = Vector3.new(0, -0.05, -0.06),
					},
					LeftShoulder = {
						rot = Vector3.new(14, 0, -10),
						pos = Vector3.new(0, -0.05, -0.06),
					},
					RightHip = {
						rot = Vector3.new(9.15, -5.6, 2.04),
						pos = Vector3.new(0.01, 0.16, 0.01),
					},
					LeftHip = {
						rot = Vector3.new(9.15, -5.6, 2.04),
						pos = Vector3.new(0.02, 0.15, -0.19),
					},
				},
			},
			{
				time = 0.29,
				pose = {
					Root = { rot = Vector3.new(-16, -4, 5), pos = Vector3.new(-0.03, -0.11, -0.02) },
					Neck = { rot = Vector3.new(-24, -6, -37) },
					RightShoulder = {
						rot = Vector3.new(17, 0, 3),
						pos = Vector3.new(0, -0.04, -0.05),
					},
					LeftShoulder = {
						rot = Vector3.new(24, 0, -9),
						pos = Vector3.new(0, -0.03, -0.05),
					},
					RightHip = {
						rot = Vector3.new(7.17, -8.69, -5.57),
						pos = Vector3.new(-0.07, 0.03, 0.06),
					},
					LeftHip = {
						rot = Vector3.new(7.17, -8.69, -5.57),
						pos = Vector3.new(-0.03, 0.29, -0.21),
					},
				},
			},
			{
				time = 0.34,
				pose = {
					Root = { rot = Vector3.new(-16, -5, 3), pos = Vector3.new(-0.02, -0.11, -0.02) },
					Neck = { rot = Vector3.new(-23, -4, -29) },
					RightShoulder = {
						rot = Vector3.new(14, 0, 6),
						pos = Vector3.new(0, -0.04, -0.05),
					},
					LeftShoulder = {
						rot = Vector3.new(18, 0, -7),
						pos = Vector3.new(0, -0.04, -0.05),
					},
					RightHip = {
						rot = Vector3.new(7.51, -7.45, -3.7),
						pos = Vector3.new(-0.04, 0.07, 0.04),
					},
					LeftHip = {
						rot = Vector3.new(7.51, -7.45, -3.7),
						pos = Vector3.new(-0.02, 0.26, -0.19),
					},
				},
			},
			{
				time = 0.46,
				pose = {
					Root = { rot = Vector3.new(-15, -8, -6), pos = Vector3.new(0.05, -0.11, -0.02) },
					Neck = { rot = Vector3.new(-14, 10, 43) },
					RightShoulder = {
						rot = Vector3.new(22, 0, 9),
						pos = Vector3.new(0, -0.03, -0.05),
					},
					LeftShoulder = {
						rot = Vector3.new(14, 0, -4),
						pos = Vector3.new(0, -0.04, -0.05),
					},
					RightHip = {
						rot = Vector3.new(7.25, -3.32, 4.99),
						pos = Vector3.new(0.03, 0.22, 0.01),
					},
					LeftHip = {
						rot = Vector3.new(7.25, -3.32, 4.99),
						pos = Vector3.new(0.04, 0.09, -0.12),
					},
				},
			},
			{
				time = 0.53,
				pose = {
					Root = { rot = Vector3.new(-14, -8, -2), pos = Vector3.new(0.01, -0.09, -0.02) },
					Neck = { rot = Vector3.new(-12, 7, 30) },
					RightShoulder = {
						rot = Vector3.new(24, 0, 4),
						pos = Vector3.new(0, 0.12, -0.13),
					},
					LeftShoulder = {
						rot = Vector3.new(24, 0, -4),
						pos = Vector3.new(0, 0.12, -0.13),
					},
					RightHip = {
						rot = Vector3.new(6.02, -3.84, 1.16),
						pos = Vector3.new(0.01, 0.14, 0.02),
					},
					LeftHip = {
						rot = Vector3.new(6.02, -3.84, 1.16),
						pos = Vector3.new(0.02, 0.14, -0.11),
					},
				},
			},
			{
				time = 0.62,
				pose = {
					Root = { rot = Vector3.new(-1, -8, 0), pos = Vector3.new(0, 0.03, 0.02) },
					Neck = { rot = Vector3.new(-2, 3, 3) },
					RightShoulder = {
						rot = Vector3.new(-6, 0, 12),
						pos = Vector3.new(0, 0.27, 0.12),
					},
					LeftShoulder = {
						rot = Vector3.new(-4, 0, -12),
						pos = Vector3.new(0, 0.27, 0.12),
					},
					RightHip = {
						rot = Vector3.new(-6.86, -4.06, 0.97),
						pos = Vector3.new(0.01, 0.04, 0.17),
					},
					LeftHip = {
						rot = Vector3.new(-6.86, -4.06, 0.97),
						pos = Vector3.new(0.02, 0.02, 0.03),
					},
				},
			},
			{
				time = 0.72,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-15, -9, 0), pos = Vector3.new(0, -0.13, -0.03) },
					Neck = { rot = Vector3.new(-8, 6, 0) },
					RightShoulder = {
						rot = Vector3.new(132.3, 0, -58.8),
						pos = Vector3.new(0, 0, 0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(131.8, 0, 47.2),
						pos = Vector3.new(0, 0, 0.08),
					},
					RightHip = {
						rot = Vector3.new(6.86, -3.07, -1.09),
						pos = Vector3.new(-0.01, 0.14, 0),
					},
					LeftHip = {
						rot = Vector3.new(6.86, -3.07, -1.09),
						pos = Vector3.new(-0.01, 0.22, -0.09),
					},
				},
			},
			{
				time = 0.8,
				pose = {
					Root = { rot = Vector3.new(-28, -13, 0), pos = Vector3.new(0, -0.38, -0.12) },
					Neck = { rot = Vector3.new(20, 10, -2) },
					RightShoulder = {
						rot = Vector3.new(146, 0, -44),
						pos = Vector3.new(0, -0.05, -0.05),
					},
					LeftShoulder = {
						rot = Vector3.new(145, 0, 36),
						pos = Vector3.new(0, -0.05, -0.05),
					},
					RightHip = {
						rot = Vector3.new(19.55, 0.24, -4.41),
						pos = Vector3.new(-0.01, 0.3, -0.07),
					},
					LeftHip = {
						rot = Vector3.new(19.55, 0.24, -4.41),
						pos = Vector3.new(0, 0.47, 0),
					},
				},
			},
			{
				time = 0.9,
				pose = {
					Root = { rot = Vector3.new(-20, -9, 0), pos = Vector3.new(0, -0.27, -0.06) },
					Neck = { rot = Vector3.new(12, 7, 0) },
					RightShoulder = {
						rot = Vector3.new(138.5, 0, -41),
						pos = Vector3.new(0, -0.01, -0.02),
					},
					LeftShoulder = {
						rot = Vector3.new(138, 0, 32.5),
						pos = Vector3.new(0, -0.01, -0.02),
					},
					RightHip = {
						rot = Vector3.new(11.75, -3.19, -1.87),
						pos = Vector3.new(-0.01, 0.25, 0),
					},
					LeftHip = {
						rot = Vector3.new(11.75, -3.19, -1.87),
						pos = Vector3.new(0, 0.36, -0.08),
					},
				},
			},
			{
				time = 1,
				pose = {
					Root = { rot = Vector3.new(-22, -10, 0), pos = Vector3.new(0, -0.3, -0.08) },
					Neck = { rot = Vector3.new(14, 8, 0) },
					RightShoulder = { rot = Vector3.new(140.8, 0, -41.6) },
					LeftShoulder = { rot = Vector3.new(139.9, 0, 33.3) },
					RightHip = {
						rot = Vector3.new(13.7, -2.29, -2.41),
						pos = Vector3.new(-0.01, 0.26, -0.01),
					},
					LeftHip = {
						rot = Vector3.new(13.7, -2.29, -2.41),
						pos = Vector3.new(0, 0.39, -0.06),
					},
				},
			},
		},
	},
	-- BROKEN BOTTLE (Street Fury, key 1): forehand slash 0.20 s, backhand 0.45 s.
	Brawler_BrokenBottle = {
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
				time = 0.09,
				pose = {
					Root = { rot = Vector3.new(-3, -38, -7), pos = Vector3.new(0.15, -0.13, 0.12) },
					Neck = { rot = Vector3.new(2, 31, 6) },
					RightShoulder = { rot = Vector3.new(155.04, 0, 26.49) },
					LeftShoulder = { rot = Vector3.new(107.13, 0, -0.62) },
					RightHip = {
						rot = Vector3.new(2.43, 18.12, 7.18),
						pos = Vector3.new(0, 0.27, 0),
					},
					LeftHip = {
						rot = Vector3.new(-21.76, 17.49, 11.89),
						pos = Vector3.new(0, 0.1, 0),
					},
				},
			},
			{
				time = 0.15,
				pose = {
					Root = {
						rot = Vector3.new(-12, -10, -1),
						pos = Vector3.new(0.05, -0.24, -0.08),
					},
					Neck = { rot = Vector3.new(6, 8, 1) },
					RightShoulder = { rot = Vector3.new(153.7, 0, 26) },
					LeftShoulder = { rot = Vector3.new(137.3, 0, 36.3) },
					RightHip = {
						rot = Vector3.new(2.86, 5.94, -0.49),
						pos = Vector3.new(0, 0.26, 0),
					},
					LeftHip = {
						rot = Vector3.new(3.02, -3.89, -0.34),
						pos = Vector3.new(0, 0.3, 0),
					},
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-21, 27, 7), pos = Vector3.new(-0.1, -0.36, -0.24) },
					Neck = { rot = Vector3.new(12, -22, -4) },
					RightShoulder = { rot = Vector3.new(133.4, 0, -18) },
					LeftShoulder = { rot = Vector3.new(149.1, 0, 59.8) },
					RightHip = {
						rot = Vector3.new(-10.5, -16.84, -7.3),
						pos = Vector3.new(0, 0.37, 0),
					},
					LeftHip = {
						rot = Vector3.new(26.28, -35.14, 3.96),
						pos = Vector3.new(0, 0.36, 0),
					},
				},
			},
			{
				time = 0.26,
				pose = {
					Root = { rot = Vector3.new(-23, 44, 9), pos = Vector3.new(-0.13, -0.4, -0.25) },
					Neck = { rot = Vector3.new(14, -35, -5) },
					RightShoulder = { rot = Vector3.new(95.7, 0, -29) },
					LeftShoulder = { rot = Vector3.new(158.9, 0, 57.6) },
					RightHip = {
						rot = Vector3.new(-21.23, -26.78, -11.97),
						pos = Vector3.new(0, 0.4, 0),
					},
					LeftHip = {
						rot = Vector3.new(38.08, -46.96, 13.87),
						pos = Vector3.new(0, 0.41, 0),
					},
				},
			},
			{
				time = 0.35,
				pose = {
					Root = { rot = Vector3.new(-15, 56, 8), pos = Vector3.new(-0.1, -0.43, -0.16) },
					Neck = { rot = Vector3.new(9, -47, -7) },
					RightShoulder = { rot = Vector3.new(92.6, 0, -79.2) },
					LeftShoulder = { rot = Vector3.new(150.2, 0, 58.9) },
					RightHip = {
						rot = Vector3.new(-38.52, -30.78, -22.81),
						pos = Vector3.new(0, 0.34, 0),
					},
					LeftHip = {
						rot = Vector3.new(39.08, -57.56, 17.26),
						pos = Vector3.new(0, 0.56, 0),
					},
				},
			},
			{
				time = 0.41,
				pose = {
					Root = { rot = Vector3.new(-17, 36, 5), pos = Vector3.new(-0.07, -0.41, -0.22) },
					Neck = { rot = Vector3.new(10, -28, -4) },
					RightShoulder = { rot = Vector3.new(101, 0, -84.6) },
					LeftShoulder = { rot = Vector3.new(149.5, 0, 56) },
					RightHip = {
						rot = Vector3.new(-22.17, -25.79, -10.82),
						pos = Vector3.new(0, 0.43, 0),
					},
					LeftHip = {
						rot = Vector3.new(27.43, -42.47, 7.85),
						pos = Vector3.new(0, 0.43, 0),
					},
				},
			},
			{
				time = 0.45,
				pose = {
					Root = { rot = Vector3.new(-20, 14, 2), pos = Vector3.new(-0.04, -0.38, -0.31) },
					Neck = { rot = Vector3.new(11, -8, -2) },
					RightShoulder = { rot = Vector3.new(132.8, 0, -26.9) },
					LeftShoulder = { rot = Vector3.new(152.4, 0, 52.3) },
					RightHip = {
						rot = Vector3.new(-8.57, -18.93, -2.88),
						pos = Vector3.new(0, 0.46, 0),
					},
					LeftHip = {
						rot = Vector3.new(19.32, -25.84, 3.04),
						pos = Vector3.new(0, 0.3, 0),
					},
				},
			},
			{
				time = 0.52,
				pose = {
					Root = { rot = Vector3.new(-10, -24, -5), pos = Vector3.new(0.08, -0.27, -0.1) },
					Neck = { rot = Vector3.new(6, 19, 3) },
					RightShoulder = { rot = Vector3.new(135.4, 0, 8.9) },
					LeftShoulder = { rot = Vector3.new(136.1, 0, 24.6) },
					RightHip = {
						rot = Vector3.new(2.11, 8.15, 4.73),
						pos = Vector3.new(0, 0.37, 0),
					},
					LeftHip = { rot = Vector3.new(-8.26, 6.72, 5.75), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.64,
				pose = {
					Root = { rot = Vector3.new(-6, -30, -5), pos = Vector3.new(0.12, -0.18, 0.04) },
					Neck = { rot = Vector3.new(5, 24, 3) },
					RightShoulder = { rot = Vector3.new(130.4, 0, 32.1) },
					LeftShoulder = { rot = Vector3.new(130.1, 0, 14) },
					RightHip = {
						rot = Vector3.new(2.7, 12.05, 4.24),
						pos = Vector3.new(0, 0.26, 0),
					},
					LeftHip = {
						rot = Vector3.new(-13.28, 11.87, 6.42),
						pos = Vector3.new(0, 0.2, 0),
					},
				},
			},
			{
				time = 0.8,
				pose = {
					Root = { rot = Vector3.new(-5, -7, 1), pos = Vector3.new(0, -0.03, 0.03) },
					Neck = { rot = Vector3.new(4, 6, 0) },
					RightShoulder = { rot = Vector3.new(124.97, 0, -45.59) },
					LeftShoulder = { rot = Vector3.new(122.86, 0, 35.91) },
					RightHip = {
						rot = Vector3.new(-6.41, -4.78, -1.09),
						pos = Vector3.new(0, 0.08, 0),
					},
					LeftHip = { rot = Vector3.new(-1.4, -5, -0.88), pos = Vector3.new(0, 0.1, 0) },
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
	-- DOUBLE HEADBUTT (Street Fury, key 2): collar grab, headbutts at 0.22 and 0.52 s.
	Brawler_DoubleHeadbutt = {
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
				time = 0.12,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(10, -17, -3), pos = Vector3.new(0.06, -0.02, 0.1) },
					Neck = { rot = Vector3.new(16, 12, 2) },
					RightShoulder = { rot = Vector3.new(87.71, 0, -41.92) },
					LeftShoulder = { rot = Vector3.new(87.88, 0, 7.88) },
					RightHip = { rot = Vector3.new(-22.04, -4, 8.4), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = { rot = Vector3.new(-25.77, 0, 9.2), pos = Vector3.new(0, -0.01, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(-21.5, 0, 1), pos = Vector3.new(0.03, -0.06, -0.28) },
					Neck = { rot = Vector3.new(16, 0, 0) },
					RightShoulder = { rot = Vector3.new(124.2, 0, -27.8) },
					LeftShoulder = { rot = Vector3.new(125.1, 0, 28.3) },
					RightHip = { rot = Vector3.new(6.69, -4, -3.69), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(30.56, 0, -3.43), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.22,
				pose = {
					Root = {
						rot = Vector3.new(-27.5, 8, 2),
						pos = Vector3.new(-0.02, -0.15, -1.06),
					},
					Neck = { rot = Vector3.new(-8, -6, 0) },
					RightShoulder = { rot = Vector3.new(141.1, 0, -22.5) },
					LeftShoulder = { rot = Vector3.new(138.3, 0, 37.3) },
					RightHip = {
						rot = Vector3.new(-10.36, -6, -2.75),
						pos = Vector3.new(0, -0.04, 0),
					},
					LeftHip = { rot = Vector3.new(21.88, 0, 2.87), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.26,
				pose = {
					Root = {
						rot = Vector3.new(-28.1, 9, 2.5),
						pos = Vector3.new(-0.03, -0.18, -1.14),
					},
					Neck = { rot = Vector3.new(-18, -6, 0) },
					RightShoulder = { rot = Vector3.new(141.4, 0, -21.9) },
					LeftShoulder = { rot = Vector3.new(138, 0, 39.5) },
					RightHip = {
						rot = Vector3.new(-14.52, -6, -6.49),
						pos = Vector3.new(0, -0.04, 0),
					},
					LeftHip = { rot = Vector3.new(19.61, 0, 0.35), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.38,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(25, -12, -6), pos = Vector3.new(0.08, -0.03, -0.3) },
					Neck = { rot = Vector3.new(34, 12, 5) },
					RightShoulder = { rot = Vector3.new(81.1, 0, -41.7) },
					LeftShoulder = { rot = Vector3.new(76.8, 0, 15.5) },
					RightHip = {
						rot = Vector3.new(-57.12, -6, 13.55),
						pos = Vector3.new(0, 0.18, 0),
					},
					LeftHip = { rot = Vector3.new(-35.37, 0, 7.59), pos = Vector3.new(0, -0.01, 0) },
				},
			},
			{
				time = 0.47,
				pose = {
					Root = {
						rot = Vector3.new(-17.5, -6, -1),
						pos = Vector3.new(0.08, -0.05, -0.32),
					},
					Neck = { rot = Vector3.new(26, 6, 0) },
					RightShoulder = { rot = Vector3.new(120.8, 0, -35.5) },
					LeftShoulder = { rot = Vector3.new(122.6, 0, 21.1) },
					RightHip = { rot = Vector3.new(0.49, -6, -1.1), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(31.44, 0, -3.14), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.52,
				pose = {
					Root = { rot = Vector3.new(-30.1, 4, 8), pos = Vector3.new(-0.1, -0.32, -1.06) },
					Neck = { rot = Vector3.new(-4, -12, -4) },
					RightShoulder = { rot = Vector3.new(144.6, 0, -15.5) },
					LeftShoulder = { rot = Vector3.new(146.1, 0, 42.1) },
					RightHip = {
						rot = Vector3.new(-10.25, -8, -9.28),
						pos = Vector3.new(0, 0.01, 0),
					},
					LeftHip = { rot = Vector3.new(30.88, 0, -2.83), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.58,
				pose = {
					Root = {
						rot = Vector3.new(-32.1, 10, 9),
						pos = Vector3.new(-0.12, -0.34, -1.08),
					},
					Neck = { rot = Vector3.new(-16, -12, -4) },
					RightShoulder = { rot = Vector3.new(145.6, 0, -10.5) },
					LeftShoulder = { rot = Vector3.new(143.9, 0, 47.1) },
					RightHip = {
						rot = Vector3.new(-11.08, -8, -12.46),
						pos = Vector3.new(0, -0.05, 0),
					},
					LeftHip = { rot = Vector3.new(33.49, 0, -1.66), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.69,
				pose = {
					Root = { rot = Vector3.new(-7, -2, -2), pos = Vector3.new(0, -0.2, -1) },
					Neck = { rot = Vector3.new(-2, 4, 0) },
					RightShoulder = { rot = Vector3.new(104.5, 0, -29.4) },
					LeftShoulder = { rot = Vector3.new(104.1, 0, 24.5) },
					RightHip = {
						rot = Vector3.new(-36.28, -4, 4.12),
						pos = Vector3.new(0, 0.11, 0),
					},
					LeftHip = { rot = Vector3.new(0.35, 0, 3.03), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = { rot = Vector3.new(-11, -15, 1), pos = Vector3.new(0, -0.06, -0.16) },
					Neck = { rot = Vector3.new(3, 13, -2) },
					RightShoulder = { rot = Vector3.new(128.24, 0, -47.98) },
					LeftShoulder = { rot = Vector3.new(125.75, 0, 39.73) },
					RightHip = { rot = Vector3.new(-0.02, 0, -0.67), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(2.63, 0, -1.55), pos = Vector3.new(0, 0.29, 0) },
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
	-- KICK COMBO (Street Fury, key 4): shin kick 0.20 s, high kick to the face 0.50 s.
	Brawler_KickCombo = {
		length = 0.95,
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
				time = 0.06,
				pose = {
					Root = {
						rot = Vector3.new(-12.41, -21.95, 2.77),
						pos = Vector3.new(-0.1, -0.15, -0.04),
					},
					Neck = { rot = Vector3.new(0.6, 18.3, 0) },
					RightShoulder = { rot = Vector3.new(122.44, 0, -45.54) },
					LeftShoulder = { rot = Vector3.new(120.35, 0, 39.37) },
					RightHip = {
						rot = Vector3.new(10.51, -8.61, -0.51),
						pos = Vector3.new(0, 0.2, 0),
					},
					LeftHip = {
						rot = Vector3.new(1.24, 4.72, -1.76),
						pos = Vector3.new(0, 0.33, 0),
					},
				},
			},
			{
				time = 0.14,
				pose = {
					Root = {
						rot = Vector3.new(4.07, -2.07, 6.03),
						pos = Vector3.new(-0.08, -0.08, -0.06),
					},
					Neck = { rot = Vector3.new(-18.1, -0.6, 0) },
					RightShoulder = { rot = Vector3.new(117.45, 0, -39.62) },
					LeftShoulder = { rot = Vector3.new(131.69, 0, 39.97) },
					RightHip = {
						rot = Vector3.new(55, 0, 38),
						pos = Vector3.new(-0.46, 0.34, 0.48),
					},
					LeftHip = {
						rot = Vector3.new(-16.09, -3.13, -4.66),
						pos = Vector3.new(0, 0.23, 0),
					},
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(12.49, 18.44, 13.67),
						pos = Vector3.new(-0.06, -0.07, -0.09),
					},
					Neck = { rot = Vector3.new(-33.5, -17.6, 0) },
					RightShoulder = { rot = Vector3.new(98, 0, -26) },
					LeftShoulder = { rot = Vector3.new(134, 0, 40) },
					RightHip = { rot = Vector3.new(50.5, 0, -0.16) },
					LeftHip = {
						rot = Vector3.new(-25.1, -9.56, -23.63),
						pos = Vector3.new(0, 0.45, 0),
					},
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(16.49, 27.66, 11.84),
						pos = Vector3.new(-0.05, -0.06, -0.09),
					},
					Neck = { rot = Vector3.new(-40.1, -24.2, 0) },
					RightShoulder = { rot = Vector3.new(92, 0, -22) },
					LeftShoulder = { rot = Vector3.new(134, 0, 41) },
					RightHip = { rot = Vector3.new(43.1, 0, -0.57) },
					LeftHip = {
						rot = Vector3.new(-28.8, -14.84, -27.61),
						pos = Vector3.new(0, 0.48, 0),
					},
				},
			},
			{
				time = 0.43,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(24.87, 5.29, 21.18),
						pos = Vector3.new(0, 0.1, 0.06),
					},
					Neck = { rot = Vector3.new(-38.2, -0.2, 0) },
					RightShoulder = { rot = Vector3.new(49.8, 0, -60.9) },
					LeftShoulder = { rot = Vector3.new(138, 0, 42) },
					RightHip = { rot = Vector3.new(75, 0, 85), pos = Vector3.new(-0.9, 0.02, 0.08) },
					LeftHip = {
						rot = Vector3.new(-37.21, 24.68, -28.48),
						pos = Vector3.new(0, 0.39, 0),
					},
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(34.95, 19.16, 32.69),
						pos = Vector3.new(0.01, 0.23, 0.14),
					},
					Neck = { rot = Vector3.new(-50.6, -1.8, 0) },
					RightShoulder = { rot = Vector3.new(35.7, 0, -81.6) },
					LeftShoulder = { rot = Vector3.new(140, 0, 44) },
					RightHip = { rot = Vector3.new(76.52, 0, 3.99) },
					LeftHip = {
						rot = Vector3.new(-35.61, 36.33, -56.29),
						pos = Vector3.new(0, 0.42, 0),
					},
				},
			},
			{
				time = 0.56,
				pose = {
					Root = {
						rot = Vector3.new(33.03, 39.17, 22.42),
						pos = Vector3.new(0, 0.22, 0.15),
					},
					Neck = { rot = Vector3.new(-58.3, -19.8, 0) },
					RightShoulder = { rot = Vector3.new(12, 0, -75.8) },
					LeftShoulder = { rot = Vector3.new(138, 0, 46) },
					RightHip = { rot = Vector3.new(102.88, 0, 7.49) },
					LeftHip = {
						rot = Vector3.new(-29.59, 14.76, -55.84),
						pos = Vector3.new(0, 0.51, 0),
					},
				},
			},
			{
				time = 0.7,
				pose = {
					Root = {
						rot = Vector3.new(5.36, 23.91, 4.47),
						pos = Vector3.new(0, -0.1, 0.02),
					},
					Neck = { rot = Vector3.new(-20.2, -24.6, 0) },
					RightShoulder = { rot = Vector3.new(100, 0, -60) },
					LeftShoulder = { rot = Vector3.new(132, 0, 40) },
					RightHip = { rot = Vector3.new(42, 0, 8), pos = Vector3.new(-0.09, 0.46, 0.41) },
					LeftHip = {
						rot = Vector3.new(-8.81, 2.44, -10.44),
						pos = Vector3.new(0, 0.32, 0),
					},
				},
			},
			{
				time = 0.79,
				pose = {
					Root = {
						rot = Vector3.new(-15.73, -17.85, -1.85),
						pos = Vector3.new(0.02, -0.25, -0.06),
					},
					Neck = { rot = Vector3.new(6.9, 19, 0) },
					RightShoulder = { rot = Vector3.new(128.24, 0, -48.98) },
					LeftShoulder = { rot = Vector3.new(124.75, 0, 40.73) },
					RightHip = {
						rot = Vector3.new(4.52, -25.49, -2.09),
						pos = Vector3.new(0, 0.36, 0),
					},
					LeftHip = {
						rot = Vector3.new(2.69, 11.13, 0.95),
						pos = Vector3.new(0, 0.33, 0),
					},
				},
			},
			{
				time = 0.87,
				pose = {
					Root = {
						rot = Vector3.new(-6.66, -10.43, 0.75),
						pos = Vector3.new(0, -0.04, 0.02),
					},
					Neck = { rot = Vector3.new(-2.3, 10.1, 0) },
					RightShoulder = { rot = Vector3.new(114.71, 0, -38.69) },
					LeftShoulder = { rot = Vector3.new(117.06, 0, 36.52) },
					RightHip = {
						rot = Vector3.new(-10.68, -30.48, -2.74),
						pos = Vector3.new(0, 0.2, 0),
					},
					LeftHip = {
						rot = Vector3.new(-1.23, -0.83, -1.16),
						pos = Vector3.new(0, 0.14, 0),
					},
				},
			},
			{
				time = 0.95,
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
	-- Victim reaction: kicked in the shin, the leg buckles, then dazed.
	HitLeg = {
		length = 0.5,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-3, 2, 3), pos = Vector3.new(-0.03, -0.04, 0.02) },
					Neck = { rot = Vector3.new(8, -3, -4) },
					RightShoulder = { rot = Vector3.new(96, 0, -30) },
					LeftShoulder = { rot = Vector3.new(92, 0, 22) },
					RightHip = { rot = Vector3.new(3.2, 0, -0.6), pos = Vector3.new(0, 0.03, 0) },
					LeftHip = { rot = Vector3.new(-4.9, 0, 4.6), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(-8, 7, 10), pos = Vector3.new(-0.08, -0.2, 0.06) },
					Neck = { rot = Vector3.new(18, -7, -16) },
					RightShoulder = { rot = Vector3.new(104, 0, -6) },
					LeftShoulder = { rot = Vector3.new(66, 0, -24) },
					RightHip = { rot = Vector3.new(9.7, 0, -7.7), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(-4.2, 0, 4.4), pos = Vector3.new(0, 0.62, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-16, 9, 18), pos = Vector3.new(-0.17, -0.46, 0.04) },
					Neck = { rot = Vector3.new(-4, 4, -18) },
					RightShoulder = { rot = Vector3.new(134, 0, 24) },
					LeftShoulder = { rot = Vector3.new(42, 0, -58) },
					RightHip = { rot = Vector3.new(17.7, 0, -12.4), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(3.3, 0, -5), pos = Vector3.new(0, 0.73, 0) },
				},
			},
			{
				time = 0.17,
				pose = {
					Root = { rot = Vector3.new(-25, 7, 23), pos = Vector3.new(-0.24, -0.68, 0.02) },
					Neck = { rot = Vector3.new(-34, 15, -10) },
					RightShoulder = { rot = Vector3.new(150, 0, 52) },
					LeftShoulder = { rot = Vector3.new(34, 0, -60) },
					RightHip = { rot = Vector3.new(26.9, 0, -12.9), pos = Vector3.new(0, 0.37, 0) },
					LeftHip = { rot = Vector3.new(10, 0, -5), pos = Vector3.new(0, 0.99, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = { rot = Vector3.new(-20, 2, 13), pos = Vector3.new(-0.13, -0.46, 0) },
					Neck = { rot = Vector3.new(-26, 8, 4) },
					RightShoulder = { rot = Vector3.new(68, 0, 50) },
					LeftShoulder = { rot = Vector3.new(24, 0, -30) },
					RightHip = { rot = Vector3.new(24.4, 0, -8.5), pos = Vector3.new(0, 0.28, 0) },
					LeftHip = { rot = Vector3.new(7.2, 0, -0.6), pos = Vector3.new(0, 0.66, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(-10, -5, -8), pos = Vector3.new(0.07, -0.2, 0) },
					Neck = { rot = Vector3.new(-8, -7, 14) },
					RightShoulder = { rot = Vector3.new(30, 0, 40) },
					LeftShoulder = { rot = Vector3.new(26, 0, -6) },
					RightHip = { rot = Vector3.new(13.5, 0, 10.2), pos = Vector3.new(0, 0.39, 0) },
					LeftHip = { rot = Vector3.new(0.5, 0, 16.4), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.37,
				pose = {
					Root = { rot = Vector3.new(-18, -2, 10), pos = Vector3.new(-0.1, -0.3, 0) },
					Neck = { rot = Vector3.new(-30, 1, 6) },
					RightShoulder = { rot = Vector3.new(6, 0, 18) },
					LeftShoulder = { rot = Vector3.new(22, 0, -8) },
					RightHip = { rot = Vector3.new(24.6, 0, -8), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(14.7, 0, -4.6), pos = Vector3.new(0, 0.46, 0) },
				},
			},
			{
				time = 0.43,
				pose = {
					Root = { rot = Vector3.new(-12, 0, 4), pos = Vector3.new(-0.03, -0.08, 0) },
					Neck = { rot = Vector3.new(-17, 1, 4) },
					RightShoulder = { rot = Vector3.new(14, 0, 7) },
					LeftShoulder = { rot = Vector3.new(12, 0, -7) },
					RightHip = { rot = Vector3.new(16.4, 0, -2), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(8.6, 0, 0.9), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 5) },
					Neck = { rot = Vector3.new(-22, 0, 6) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
					RightHip = { rot = Vector3.new(20.1, 0, -4.4), pos = Vector3.new(0, -0.07, 0) },
					LeftHip = { rot = Vector3.new(12.1, 0, -1.6), pos = Vector3.new(0, 0.07, 0) },
				},
			},
		},
	},
	-- END Street Brawler kit
	-- BEGIN injuries (generated by add_injury_clips.py)
	-- LOW HEALTH, out of a fight: hunched, left arm holding the right ribs, heavy
	-- breathing. Upper body only (the legs keep walking).
	HurtIdle = {
		length = 2,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-17.2, -2, -1.98),
						pos = Vector3.new(0.03, 0.05, -0.11),
					},
					Neck = { rot = Vector3.new(-23.3, 1.7, -0.41) },
					RightShoulder = {
						rot = Vector3.new(16.45, 1.5, 3.36),
						pos = Vector3.new(0, 0.02, -0.1),
					},
					LeftShoulder = {
						rot = Vector3.new(46.12, 6, 73.5),
						pos = Vector3.new(0, 0.02, -0.08),
					},
				},
			},
			{
				time = 0.08,
				pose = {
					Root = {
						rot = Vector3.new(-16.5, -1.75, -1.82),
						pos = Vector3.new(0.02, 0.06, -0.08),
					},
					Neck = { rot = Vector3.new(-23.72, 1.5, -0.26) },
					RightShoulder = {
						rot = Vector3.new(15.58, 1.5, 3.66),
						pos = Vector3.new(0, 0.05, -0.09),
					},
					LeftShoulder = {
						rot = Vector3.new(45.58, 5.72, 73.01),
						pos = Vector3.new(0, 0.04, -0.07),
					},
				},
			},
			{
				time = 0.29,
				pose = {
					Root = {
						rot = Vector3.new(-12.2, -1, -1.1),
						pos = Vector3.new(-0.02, 0.12, 0.14),
					},
					Neck = { rot = Vector3.new(-16.3, 0.9, -0.25) },
					RightShoulder = {
						rot = Vector3.new(10.75, 1.5, 5.7),
						pos = Vector3.new(0, 0.21, -0.05),
					},
					LeftShoulder = {
						rot = Vector3.new(42.4, 4, 70),
						pos = Vector3.new(0, 0.18, -0.04),
					},
				},
			},
			{
				time = 0.5,
				pose = {
					Root = {
						rot = Vector3.new(-13.3, -1.5, -0.62),
						pos = Vector3.new(-0.05, 0.1, 0.08),
					},
					Neck = { rot = Vector3.new(-10, 1.3, -0.34) },
					RightShoulder = {
						rot = Vector3.new(15.01, 1.5, 4.68),
						pos = Vector3.new(0, 0.17, -0.06),
					},
					LeftShoulder = {
						rot = Vector3.new(44.02, 4.44, 70.77),
						pos = Vector3.new(0, 0.14, -0.05),
					},
				},
			},
			{
				time = 0.88,
				pose = {
					Root = {
						rot = Vector3.new(-17.5, -3.25, 0.1),
						pos = Vector3.new(-0.08, 0.04, -0.13),
					},
					Neck = { rot = Vector3.new(-22.6, 2.7, 1.1) },
					RightShoulder = {
						rot = Vector3.new(18.88, 1.5, 1.62),
						pos = Vector3.new(0, 0.01, -0.1),
					},
					LeftShoulder = {
						rot = Vector3.new(46.9, 6.12, 73.71),
						pos = Vector3.new(0, 0.01, -0.08),
					},
				},
			},
			{
				time = 1.08,
				pose = {
					Root = {
						rot = Vector3.new(-16.3, -4.5, -0.22),
						pos = Vector3.new(-0.07, 0.06, -0.07),
					},
					Neck = { rot = Vector3.new(-24.7, 3.7, 1.01) },
					RightShoulder = {
						rot = Vector3.new(15.01, 1.5, 2.58),
						pos = Vector3.new(0, 0.05, -0.09),
					},
					LeftShoulder = {
						rot = Vector3.new(45.34, 5.64, 72.87),
						pos = Vector3.new(0, 0.05, -0.07),
					},
				},
			},
			{
				time = 1.27,
				pose = {
					Root = {
						rot = Vector3.new(-13.7, -5.5, -1.18),
						pos = Vector3.new(-0.02, 0.1, 0.07),
					},
					Neck = { rot = Vector3.new(-17.7, 4.5, -0.21) },
					RightShoulder = {
						rot = Vector3.new(11.88, 1.5, 4.86),
						pos = Vector3.new(0, 0.15, -0.07),
					},
					LeftShoulder = {
						rot = Vector3.new(43.36, 4.6, 71.05),
						pos = Vector3.new(0, 0.13, -0.05),
					},
				},
			},
			{
				time = 1.47,
				pose = {
					Root = {
						rot = Vector3.new(-15.1, -4.75, -2.14),
						pos = Vector3.new(0.03, 0.08, 0),
					},
					Neck = { rot = Vector3.new(-13.5, 3.9, -1.23) },
					RightShoulder = {
						rot = Vector3.new(15.87, 1.5, 4.74),
						pos = Vector3.new(0, 0.1, -0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(45.04, 5.16, 72.03),
						pos = Vector3.new(0, 0.09, -0.06),
					},
				},
			},
			{
				time = 1.9,
				pose = {
					Root = {
						rot = Vector3.new(-18.07, -2.31, -2.18),
						pos = Vector3.new(0.04, 0.04, -0.16),
					},
					Neck = { rot = Vector3.new(-22.78, 1.95, -0.6) },
					RightShoulder = {
						rot = Vector3.new(17.54, 1.5, 2.98),
						pos = Vector3.new(0, -0.01, -0.11),
					},
					LeftShoulder = {
						rot = Vector3.new(46.79, 6.35, 74.11),
						pos = Vector3.new(0, -0.01, -0.09),
					},
				},
			},
			{
				time = 2,
				pose = {
					Root = {
						rot = Vector3.new(-17.2, -2, -1.98),
						pos = Vector3.new(0.03, 0.05, -0.11),
					},
					Neck = { rot = Vector3.new(-23.3, 1.7, -0.41) },
					RightShoulder = {
						rot = Vector3.new(16.45, 1.5, 3.36),
						pos = Vector3.new(0, 0.02, -0.1),
					},
					LeftShoulder = {
						rot = Vector3.new(46.12, 6, 73.5),
						pos = Vector3.new(0, 0.02, -0.08),
					},
				},
			},
		},
	},
	-- LOW HEALTH, in a fight: the guard, but tired (fists lower, elbows wider,
	-- head down, heavy breathing, unsteady). Replaces Guard. Upper body only.
	HurtGuard = {
		length = 1.6,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-12, -10, 0), pos = Vector3.new(0, 0.07, 0) },
					Neck = { rot = Vector3.new(4, 8, 0), pos = Vector3.new(0, -0.08, -0.08) },
					RightShoulder = {
						rot = Vector3.new(101.5, 0, -34),
						pos = Vector3.new(0, 0.03, -0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(106, 0, 30),
						pos = Vector3.new(0, 0.03, -0.08),
					},
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-9, -10.8, 1.02), pos = Vector3.new(-0.02, 0.09, 0) },
					Neck = {
						rot = Vector3.new(2.5, 8.6, -0.66),
						pos = Vector3.new(0, -0.02, -0.08),
					},
					RightShoulder = {
						rot = Vector3.new(99.5, 0, -34),
						pos = Vector3.new(0, 0.17, -0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(104, 0, 30.5),
						pos = Vector3.new(0, 0.17, -0.08),
					},
				},
			},
			{
				time = 0.38,
				pose = {
					Root = {
						rot = Vector3.new(-11.7, -12.8, 2.72),
						pos = Vector3.new(-0.05, 0.07, 0),
					},
					Neck = {
						rot = Vector3.new(3.62, 10.1, -1.76),
						pos = Vector3.new(0, -0.07, -0.08),
					},
					RightShoulder = {
						rot = Vector3.new(99.8, 0, -33.55),
						pos = Vector3.new(0, 0.04, -0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(105.8, 0, 30.05),
						pos = Vector3.new(0, 0.04, -0.08),
					},
				},
			},
			{
				time = 0.62,
				pose = {
					Root = { rot = Vector3.new(-15, -11.6, 3.4), pos = Vector3.new(-0.06, 0.06, 0) },
					Neck = {
						rot = Vector3.new(4.83, 9.2, -2.2),
						pos = Vector3.new(0, -0.14, -0.08),
					},
					RightShoulder = {
						rot = Vector3.new(99, 0, -32.65),
						pos = Vector3.new(0, -0.11, -0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(108, 0, 29.5),
						pos = Vector3.new(0, -0.11, -0.08),
					},
				},
			},
			{
				time = 0.86,
				pose = {
					Root = {
						rot = Vector3.new(-9.3, -8.6, 1.53),
						pos = Vector3.new(-0.03, 0.08, 0),
					},
					Neck = {
						rot = Vector3.new(1.45, 6.95, -0.99),
						pos = Vector3.new(0, -0.03, -0.08),
					},
					RightShoulder = {
						rot = Vector3.new(91.7, 0, -31.6),
						pos = Vector3.new(0, 0.16, -0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(104.2, 0, 30.45),
						pos = Vector3.new(0, 0.16, -0.08),
					},
				},
			},
			{
				time = 1.1,
				pose = {
					Root = {
						rot = Vector3.new(-12.3, -6.6, -1.87),
						pos = Vector3.new(0.03, 0.07, 0),
					},
					Neck = {
						rot = Vector3.new(2.65, 5.45, 1.21),
						pos = Vector3.new(0, -0.09, -0.08),
					},
					RightShoulder = {
						rot = Vector3.new(91.7, 0, -31),
						pos = Vector3.new(0, 0.02, -0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(106.2, 0, 29.95),
						pos = Vector3.new(0, 0.02, -0.08),
					},
				},
			},
			{
				time = 1.25,
				pose = {
					Root = {
						rot = Vector3.new(-11.15, -6, -3.23),
						pos = Vector3.new(0.06, 0.06, 0),
					},
					Neck = { rot = Vector3.new(3.7, 5, 2.09), pos = Vector3.new(0, -0.11, -0.08) },
					RightShoulder = {
						rot = Vector3.new(105.1, 0, -34.75),
						pos = Vector3.new(0, -0.01, -0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(107.1, 0, 29.73),
						pos = Vector3.new(0, -0.01, -0.08),
					},
				},
			},
			{
				time = 1.48,
				pose = {
					Root = { rot = Vector3.new(-15, -9.2, -1.02), pos = Vector3.new(0.02, 0.06, 0) },
					Neck = { rot = Vector3.new(5.5, 7.4, 0.66), pos = Vector3.new(0, -0.14, -0.08) },
					RightShoulder = {
						rot = Vector3.new(103.5, 0, -34),
						pos = Vector3.new(0, -0.11, -0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(108, 0, 29.5),
						pos = Vector3.new(0, -0.11, -0.08),
					},
				},
			},
			{
				time = 1.6,
				pose = {
					Root = { rot = Vector3.new(-12, -10, 0), pos = Vector3.new(0, 0.07, 0) },
					Neck = { rot = Vector3.new(4, 8, 0), pos = Vector3.new(0, -0.08, -0.08) },
					RightShoulder = {
						rot = Vector3.new(101.5, 0, -34),
						pos = Vector3.new(0, 0.03, -0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(106, 0, 30),
						pos = Vector3.new(0, 0.03, -0.08),
					},
				},
			},
		},
	},
	-- END injuries
	-- BEGIN Boxer kit (generated by add_boxer_clips.py)
	-- JAB RUSH (Boxer, key 1): four snapping left jabs while stepping in.
	-- Impacts 0.12, 0.27, 0.42, 0.57 s.
	Boxer_JabRush = {
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
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.05,
				pose = {
					Root = { rot = Vector3.new(-6, -6, 1.5), pos = Vector3.new(0.02, -0.07, 0.06) },
					Neck = { rot = Vector3.new(5, 5, -1) },
					RightShoulder = { rot = Vector3.new(113, 0, -38.5) },
					LeftShoulder = { rot = Vector3.new(117, 0, 39) },
					RightHip = {
						rot = Vector3.new(-4.19, -3.3, -2.7),
						pos = Vector3.new(0, 0.08, 0),
					},
					LeftHip = {
						rot = Vector3.new(0.53, -3.3, -2.45),
						pos = Vector3.new(0, 0.14, 0),
					},
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-12, -34, -8), pos = Vector3.new(0.2, -0.13, -0.27) },
					Neck = { rot = Vector3.new(1, 30, -7) },
					RightShoulder = { rot = Vector3.new(113, 0, -38.5) },
					LeftShoulder = {
						rot = Vector3.new(121.6, 0, -12.2),
						pos = Vector3.new(0, 0.05, -0.2),
					},
					RightHip = {
						rot = Vector3.new(1.46, 12.1, 6.82),
						pos = Vector3.new(0, 0.25, 0),
					},
					LeftHip = { rot = Vector3.new(-13.6, 12.1, 7.8), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.19,
				pose = {
					Root = { rot = Vector3.new(-9, -15, -2), pos = Vector3.new(0.07, -0.06, -0.2) },
					Neck = { rot = Vector3.new(5, 13, -2) },
					RightShoulder = { rot = Vector3.new(113, 0, -38.5) },
					LeftShoulder = { rot = Vector3.new(119, 0, 36) },
					RightHip = {
						rot = Vector3.new(-1.48, 1.65, 1.48),
						pos = Vector3.new(0, 0.13, 0),
					},
					LeftHip = {
						rot = Vector3.new(-2.86, 1.65, 1.26),
						pos = Vector3.new(0, 0.11, 0),
					},
				},
			},
			{
				time = 0.27,
				pose = {
					Root = {
						rot = Vector3.new(-12, -37, -8.5),
						pos = Vector3.new(0.22, -0.14, -0.4),
					},
					Neck = { rot = Vector3.new(0, 33, -8) },
					RightShoulder = { rot = Vector3.new(113, 0, -38.5) },
					LeftShoulder = {
						rot = Vector3.new(127.1, 0, -16.1),
						pos = Vector3.new(0, 0.05, -0.24),
					},
					RightHip = {
						rot = Vector3.new(0.67, 13.75, 7.69),
						pos = Vector3.new(0, 0.27, 0),
					},
					LeftHip = {
						rot = Vector3.new(-16.32, 13.75, 8.88),
						pos = Vector3.new(0, 0.13, 0),
					},
				},
			},
			{
				time = 0.35,
				pose = {
					Root = { rot = Vector3.new(-9, -14, -2), pos = Vector3.new(0.06, -0.07, -0.32) },
					Neck = { rot = Vector3.new(5, 12, -1) },
					RightShoulder = { rot = Vector3.new(113, 0, -38.5) },
					LeftShoulder = { rot = Vector3.new(118, 0, 37) },
					RightHip = { rot = Vector3.new(-2.07, 1.1, 1.8), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(-2.42, 1.1, 1.5), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = {
						rot = Vector3.new(-12, -32, -7),
						pos = Vector3.new(0.19, -0.11, -0.48),
					},
					Neck = { rot = Vector3.new(2, 28, -6) },
					RightShoulder = { rot = Vector3.new(113, 0, -38.5) },
					LeftShoulder = {
						rot = Vector3.new(121.4, 0, -8.5),
						pos = Vector3.new(0, 0.05, -0.18),
					},
					RightHip = { rot = Vector3.new(1.15, 11, 5.83), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-11.14, 11, 5.89), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.49,
				pose = {
					Root = { rot = Vector3.new(-9, -17, -2), pos = Vector3.new(0.08, -0.06, -0.43) },
					Neck = { rot = Vector3.new(4, 15, -2) },
					RightShoulder = { rot = Vector3.new(113, 0, -38.5) },
					LeftShoulder = { rot = Vector3.new(120, 0, 35) },
					RightHip = {
						rot = Vector3.new(-1.1, 2.75, 1.34),
						pos = Vector3.new(0, 0.12, 0),
					},
					LeftHip = {
						rot = Vector3.new(-3.83, 2.75, 1.09),
						pos = Vector3.new(0, 0.12, 0),
					},
				},
			},
			{
				time = 0.57,
				pose = {
					Root = {
						rot = Vector3.new(-14, -41, -10),
						pos = Vector3.new(0.25, -0.25, -0.7),
					},
					Neck = { rot = Vector3.new(-1, 37, -9) },
					RightShoulder = { rot = Vector3.new(113, 0, -38.5) },
					LeftShoulder = {
						rot = Vector3.new(140.6, 0, -18.6),
						pos = Vector3.new(0, 0.04, -0.2),
					},
					RightHip = {
						rot = Vector3.new(0.94, 15.95, 8.81),
						pos = Vector3.new(0, 0.39, 0),
					},
					LeftHip = {
						rot = Vector3.new(-18.49, 15.95, 10.18),
						pos = Vector3.new(0, 0.23, 0),
					},
				},
			},
			{
				time = 0.65,
				pose = {
					Root = { rot = Vector3.new(-6.5, -10, 1), pos = Vector3.new(0, -0.02, -0.26) },
					Neck = { rot = Vector3.new(5, 8, -1) },
					RightShoulder = { rot = Vector3.new(113, 0, -38.5) },
					LeftShoulder = { rot = Vector3.new(117.5, 0, 38.5) },
					RightHip = { rot = Vector3.new(-9.06, -1.1, 0), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = {
						rot = Vector3.new(5.15, -1.1, -2.24),
						pos = Vector3.new(0, 0.16, 0),
					},
				},
			},
			{
				time = 0.7,
				pose = {
					Root = {
						rot = Vector3.new(-8.6, -12.8, -0.3),
						pos = Vector3.new(0, -0.04, -0.03),
					},
					Neck = { rot = Vector3.new(6.4, 10.6, 0.2) },
					RightShoulder = { rot = Vector3.new(111.6, 0, -37) },
					LeftShoulder = { rot = Vector3.new(115.6, 0, 37.3) },
					RightHip = { rot = Vector3.new(-0.4, 0, 0.58), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(0.19, 0, 0.35), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 0.75,
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
	-- JAB FLURRY (Knockout Mode, key 1): six punches, the 5th a right cross.
	-- Impacts 0.10, 0.22, 0.34, 0.46, 0.58, 0.72 s.
	Boxer_JabRushPlus = {
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
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = {
						rot = Vector3.new(-11, -31, -5),
						pos = Vector3.new(0.15, -0.12, -0.22),
					},
					Neck = { rot = Vector3.new(8, 25, -7) },
					RightShoulder = {
						rot = Vector3.new(117.6, 0, -57.8),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					LeftShoulder = {
						rot = Vector3.new(131, 0, 6.7),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					RightHip = {
						rot = Vector3.new(2.84, 11.4, 3.48),
						pos = Vector3.new(0, 0.19, 0),
					},
					LeftHip = { rot = Vector3.new(-8.3, 13.3, 2.9), pos = Vector3.new(0, 0.19, 0) },
				},
			},
			{
				time = 0.16,
				pose = {
					Root = { rot = Vector3.new(-9, -14, -1.5), pos = Vector3.new(0.06, -0.1, -0.2) },
					Neck = { rot = Vector3.new(6, 11, -2.5) },
					RightShoulder = { rot = Vector3.new(110.8, 0, -40.2) },
					LeftShoulder = { rot = Vector3.new(117.1, 0, 36.8) },
					RightHip = { rot = Vector3.new(-0.45, 1.2, 0.67), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(0.03, 1.4, 0.16), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.22,
				pose = {
					Root = {
						rot = Vector3.new(-12, -34, -5.5),
						pos = Vector3.new(0.17, -0.15, -0.38),
					},
					Neck = { rot = Vector3.new(9, 28, -7) },
					RightShoulder = {
						rot = Vector3.new(118.7, 0, -59.6),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					LeftShoulder = {
						rot = Vector3.new(132.8, 0, 4.6),
						pos = Vector3.new(0, -0.04, -0.34),
					},
					RightHip = {
						rot = Vector3.new(3.53, 13.2, 3.46),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = {
						rot = Vector3.new(-9.26, 15.4, 2.77),
						pos = Vector3.new(0, 0.23, 0),
					},
				},
			},
			{
				time = 0.28,
				pose = {
					Root = {
						rot = Vector3.new(-9.5, -13, -1.5),
						pos = Vector3.new(0.06, -0.12, -0.34),
					},
					Neck = { rot = Vector3.new(6.5, 10, -2.5) },
					RightShoulder = { rot = Vector3.new(111.2, 0, -39.5) },
					LeftShoulder = { rot = Vector3.new(117.4, 0, 37.5) },
					RightHip = {
						rot = Vector3.new(-0.51, 0.6, 0.57),
						pos = Vector3.new(0, 0.22, 0),
					},
					LeftHip = { rot = Vector3.new(1.67, 0.7, -0.13), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.34,
				pose = {
					Root = {
						rot = Vector3.new(-12.5, -35, -5),
						pos = Vector3.new(0.18, -0.16, -0.5),
					},
					Neck = { rot = Vector3.new(9, 29, -8) },
					RightShoulder = {
						rot = Vector3.new(118.3, 0, -60.4),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					LeftShoulder = {
						rot = Vector3.new(140.2, 0, 3.5),
						pos = Vector3.new(0, -0.04, -0.36),
					},
					RightHip = {
						rot = Vector3.new(4.88, 13.8, 1.88),
						pos = Vector3.new(0, 0.19, 0),
					},
					LeftHip = {
						rot = Vector3.new(-9.15, 16.1, 1.57),
						pos = Vector3.new(0, 0.27, 0),
					},
				},
			},
			{
				time = 0.39,
				pose = {
					Root = {
						rot = Vector3.new(-10, -16, -2),
						pos = Vector3.new(0.07, -0.14, -0.46),
					},
					Neck = { rot = Vector3.new(7, 13, -3) },
					RightShoulder = {
						rot = Vector3.new(112.8, 0, -42.6),
						pos = Vector3.new(0, -0.01, -0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(117.2, 0, 34.5),
						pos = Vector3.new(0, -0.01, 0.08),
					},
					RightHip = { rot = Vector3.new(0.56, 2.4, 0.98), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(0.7, 2.8, -0.01), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.46,
				pose = {
					Root = {
						rot = Vector3.new(-12, -37, -5),
						pos = Vector3.new(0.17, -0.18, -0.56),
					},
					Neck = { rot = Vector3.new(9, 31, -7) },
					RightShoulder = {
						rot = Vector3.new(115.3, 0, -58.8),
						pos = Vector3.new(0, -0.01, -0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(140, 0, 2.4),
						pos = Vector3.new(0, -0.05, -0.38),
					},
					RightHip = { rot = Vector3.new(5.93, 15, 1.7), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = {
						rot = Vector3.new(-10.47, 17.5, 2.2),
						pos = Vector3.new(0, 0.29, 0),
					},
				},
			},
			{
				time = 0.58,
				pose = {
					Root = { rot = Vector3.new(-15, 10, 3), pos = Vector3.new(-0.04, -0.24, -0.72) },
					Neck = { rot = Vector3.new(9, -4, 2) },
					RightShoulder = {
						rot = Vector3.new(139.3, 0, -39.9),
						pos = Vector3.new(0, -0.04, -0.36),
					},
					LeftShoulder = { rot = Vector3.new(145, 0, 60) },
					RightHip = {
						rot = Vector3.new(-6.01, -13.2, -3.77),
						pos = Vector3.new(0, 0.32, 0),
					},
					LeftHip = {
						rot = Vector3.new(15.33, -15.4, -0.32),
						pos = Vector3.new(0, 0.23, 0),
					},
				},
			},
			{
				time = 0.72,
				pose = {
					Root = {
						rot = Vector3.new(-12, -32, -5),
						pos = Vector3.new(0.15, -0.18, -0.66),
					},
					Neck = { rot = Vector3.new(8, 26, -7) },
					RightShoulder = {
						rot = Vector3.new(117.6, 0, -58.5),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					LeftShoulder = {
						rot = Vector3.new(138.7, 0, 10.9),
						pos = Vector3.new(0, -0.04, -0.36),
					},
					RightHip = { rot = Vector3.new(3.11, 12, 3.34), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(-7.81, 14, 2.31), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = { rot = Vector3.new(-5, -8, 0.5), pos = Vector3.new(0.02, 0.02, -0.3) },
					Neck = { rot = Vector3.new(5, 7, 0) },
					RightShoulder = { rot = Vector3.new(111.3, 0, -37.2) },
					LeftShoulder = { rot = Vector3.new(114.8, 0, 39.5) },
					RightHip = {
						rot = Vector3.new(-9.18, -2.4, -0.3),
						pos = Vector3.new(0, 0.11, 0),
					},
					LeftHip = {
						rot = Vector3.new(-2.98, -2.8, -0.61),
						pos = Vector3.new(0, 0.11, 0),
					},
				},
			},
			{
				time = 0.9,
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
	-- UPPERCUT (Boxer, key 2): dip, then explode up through the legs. Impact 0.25 s.
	Boxer_Uppercut = {
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
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.07,
				pose = {
					Root = {
						rot = Vector3.new(-11, -20, -6),
						pos = Vector3.new(0.06, -0.16, -0.02),
					},
					Neck = { rot = Vector3.new(9, 16, 5) },
					RightShoulder = { rot = Vector3.new(103.7, 0, -49.2) },
					LeftShoulder = {
						rot = Vector3.new(116.4, 0, 31.8),
						pos = Vector3.new(0, -0.01, 0.08),
					},
					RightHip = { rot = Vector3.new(4.79, 4.8, 5.54), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(-2.38, 5.6, 6.13), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(-16, -30, -11), pos = Vector3.new(0.12, -0.4, 0.02) },
					Neck = { rot = Vector3.new(14, 24, 9) },
					RightShoulder = { rot = Vector3.new(75.9, 0, -60) },
					LeftShoulder = {
						rot = Vector3.new(119.7, 0, 25.5),
						pos = Vector3.new(0, -0.02, 0.16),
					},
					RightHip = {
						rot = Vector3.new(12.4, 10.8, 5.52),
						pos = Vector3.new(0, 0.48, 0),
					},
					LeftHip = {
						rot = Vector3.new(-4.01, 12.6, 7.99),
						pos = Vector3.new(0, 0.39, 0),
					},
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-20, 2, -3), pos = Vector3.new(0.05, -0.3, -0.14) },
					Neck = { rot = Vector3.new(14, -2, 3) },
					RightShoulder = {
						rot = Vector3.new(97.5, 0, -43.4),
						pos = Vector3.new(0, -0.02, -0.2),
					},
					LeftShoulder = {
						rot = Vector3.new(128.6, 0, 48.4),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					RightHip = {
						rot = Vector3.new(8.09, -8.4, 2.39),
						pos = Vector3.new(0, 0.43, 0),
					},
					LeftHip = {
						rot = Vector3.new(18.01, -9.8, 3.69),
						pos = Vector3.new(0, 0.21, 0),
					},
				},
			},
			{
				time = 0.25,
				pose = {
					Root = { rot = Vector3.new(-22, 30, 0), pos = Vector3.new(-0.04, -0.22, -0.22) },
					Neck = { rot = Vector3.new(17, -24, 0) },
					RightShoulder = {
						rot = Vector3.new(153.4, 0, -22.7),
						pos = Vector3.new(0, -0.03, -0.25),
					},
					LeftShoulder = {
						rot = Vector3.new(132.4, 0, 62.5),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					RightHip = {
						rot = Vector3.new(-0.34, -25.2, 4.43),
						pos = Vector3.new(0, 0.52, 0),
					},
					LeftHip = {
						rot = Vector3.new(35.83, -29.4, 14.73),
						pos = Vector3.new(0, 0.07, 0),
					},
				},
			},
			{
				time = 0.32,
				pose = {
					Root = { rot = Vector3.new(-7, 30, 8), pos = Vector3.new(-0.05, 0.03, -0.1) },
					Neck = { rot = Vector3.new(6, -24, -7) },
					RightShoulder = {
						rot = Vector3.new(151.3, 0, -12.7),
						pos = Vector3.new(0, -0.01, -0.1),
					},
					LeftShoulder = {
						rot = Vector3.new(123.2, 0, 64.8),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					RightHip = {
						rot = Vector3.new(-22.03, -25.2, -15.88),
						pos = Vector3.new(0, 0.02, 0),
					},
					LeftHip = {
						rot = Vector3.new(7.76, -29.4, -8.19),
						pos = Vector3.new(0, 0.15, 0),
					},
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(-8, 10, 3), pos = Vector3.new(0, -0.06, -0.1) },
					Neck = { rot = Vector3.new(6, -8, -2) },
					RightShoulder = { rot = Vector3.new(125.4, 0, -19.3) },
					LeftShoulder = {
						rot = Vector3.new(121.5, 0, 54.2),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					RightHip = {
						rot = Vector3.new(-7.24, -13.2, -5.42),
						pos = Vector3.new(0, 0.12, 0),
					},
					LeftHip = {
						rot = Vector3.new(5.07, -15.4, -3.47),
						pos = Vector3.new(0, 0.12, 0),
					},
				},
			},
			{
				time = 0.53,
				pose = {
					Root = {
						rot = Vector3.new(-9, -16, -1.5),
						pos = Vector3.new(0.02, -0.1, -0.03),
					},
					Neck = { rot = Vector3.new(7, 13, 1) },
					RightShoulder = { rot = Vector3.new(116, 0, -40.4) },
					LeftShoulder = { rot = Vector3.new(116, 0, 34.7) },
					RightHip = { rot = Vector3.new(4.28, 2.4, 0.74), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(-2.16, 2.8, 1.68), pos = Vector3.new(0, 0.16, 0) },
				},
			},
			{
				time = 0.64,
				pose = {
					Root = { rot = Vector3.new(-8, -11, 0.4), pos = Vector3.new(0, -0.02, 0) },
					Neck = { rot = Vector3.new(6, 9.5, 0) },
					RightShoulder = { rot = Vector3.new(112, 0, -35.4) },
					LeftShoulder = { rot = Vector3.new(114.9, 0, 37.4) },
					RightHip = {
						rot = Vector3.new(-0.63, -0.6, -0.54),
						pos = Vector3.new(0, 0.05, 0),
					},
					LeftHip = {
						rot = Vector3.new(0.09, -0.7, -0.52),
						pos = Vector3.new(0, 0.09, 0),
					},
				},
			},
			{
				time = 0.75,
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
	-- SLIP (Boxer, key 3): head and torso slip to the right, coiled, back to guard.
	Boxer_Slip = {
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
				time = 0.04,
				pose = {
					Root = { rot = Vector3.new(-10, -9, -5), pos = Vector3.new(0.1, -0.07, 0) },
					Neck = { rot = Vector3.new(7.2, 7, 2.8) },
					RightShoulder = { rot = Vector3.new(113.7, 0, -33.9) },
					LeftShoulder = {
						rot = Vector3.new(117, 0, 40),
						pos = Vector3.new(0, -0.01, -0.08),
					},
					RightHip = { rot = Vector3.new(0.9, -1.8, 3.91), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(3.41, -2.1, 4.11), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.08,
				pose = {
					Root = { rot = Vector3.new(-15, 1, -17), pos = Vector3.new(0.4, -0.33, 0.04) },
					Neck = { rot = Vector3.new(10.2, -3, 9.4) },
					RightShoulder = {
						rot = Vector3.new(119.3, 0, -26.7),
						pos = Vector3.new(0, -0.02, 0.16),
					},
					LeftShoulder = {
						rot = Vector3.new(125.5, 0, 51.7),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					RightHip = {
						rot = Vector3.new(4.47, -7.8, 9.33),
						pos = Vector3.new(0, 0.64, 0),
					},
					LeftHip = {
						rot = Vector3.new(18.17, -9.1, 12.91),
						pos = Vector3.new(0, 0.03, 0),
					},
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(-13, -1, -14), pos = Vector3.new(0.34, -0.27, 0.03) },
					Neck = { rot = Vector3.new(9, -1, 7.7) },
					RightShoulder = {
						rot = Vector3.new(117.4, 0, -28.1),
						pos = Vector3.new(0, -0.02, 0.16),
					},
					LeftShoulder = {
						rot = Vector3.new(122.4, 0, 49.3),
						pos = Vector3.new(0, -0.03, -0.24),
					},
					RightHip = {
						rot = Vector3.new(2.27, -6.6, 7.85),
						pos = Vector3.new(0, 0.53, 0),
					},
					LeftHip = {
						rot = Vector3.new(13.03, -7.7, 10.22),
						pos = Vector3.new(0, 0.05, 0),
					},
				},
			},
			{
				time = 0.3,
				pose = {
					Root = {
						rot = Vector3.new(-14, 3, -15.5),
						pos = Vector3.new(0.37, -0.31, 0.04),
					},
					Neck = { rot = Vector3.new(9.6, -5, 8.5) },
					RightShoulder = {
						rot = Vector3.new(117.8, 0, -25),
						pos = Vector3.new(0, -0.03, 0.24),
					},
					LeftShoulder = {
						rot = Vector3.new(125, 0, 53.2),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					RightHip = { rot = Vector3.new(3, -9, 8.6), pos = Vector3.new(0, 0.61, 0) },
					LeftHip = {
						rot = Vector3.new(18.21, -10.5, 12.25),
						pos = Vector3.new(0, 0.04, 0),
					},
				},
			},
			{
				time = 0.45,
				pose = {
					Root = {
						rot = Vector3.new(-14.5, 4, -16),
						pos = Vector3.new(0.38, -0.33, 0.04),
					},
					Neck = { rot = Vector3.new(9.9, -6, 8.8) },
					RightShoulder = {
						rot = Vector3.new(118.3, 0, -24.3),
						pos = Vector3.new(0, -0.03, 0.24),
					},
					LeftShoulder = {
						rot = Vector3.new(125.2, 0, 53.8),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					RightHip = {
						rot = Vector3.new(3.38, -9.6, 8.82),
						pos = Vector3.new(0, 0.64, 0),
					},
					LeftHip = {
						rot = Vector3.new(19.75, -11.2, 12.79),
						pos = Vector3.new(0, 0.05, 0),
					},
				},
			},
			{
				time = 0.49,
				pose = {
					Root = {
						rot = Vector3.new(-11.5, -6, -7.5),
						pos = Vector3.new(0.17, -0.15, 0.02),
					},
					Neck = { rot = Vector3.new(8.1, 4, 4.1) },
					RightShoulder = {
						rot = Vector3.new(114.5, 0, -30.8),
						pos = Vector3.new(0, -0.01, 0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(119.1, 0, 43.1),
						pos = Vector3.new(0, -0.02, -0.16),
					},
					RightHip = {
						rot = Vector3.new(2.06, -3.6, 4.94),
						pos = Vector3.new(0, 0.29, 0),
					},
					LeftHip = { rot = Vector3.new(7.41, -4.2, 5.52), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 0.54,
				pose = {
					Root = { rot = Vector3.new(-6.5, -16, 3), pos = Vector3.new(-0.05, -0.02, 0) },
					Neck = { rot = Vector3.new(5.1, 14, -1.7) },
					RightShoulder = {
						rot = Vector3.new(110.5, 0, -40.7),
						pos = Vector3.new(0, -0.01, -0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(114, 0, 33.4),
						pos = Vector3.new(0, -0.01, 0.08),
					},
					RightHip = {
						rot = Vector3.new(-0.24, 2.4, -2.45),
						pos = Vector3.new(0, 0.01, 0),
					},
					LeftHip = {
						rot = Vector3.new(-3.68, 2.8, -2.16),
						pos = Vector3.new(0, 0.15, 0),
					},
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
	-- Counter after a successful slip: left hook uncoiling from the slip. Impact 0.18 s.
	Boxer_SlipCounter = {
		length = 0.55,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-14, 3, -15.5),
						pos = Vector3.new(0.37, -0.31, 0.04),
					},
					Neck = { rot = Vector3.new(9.6, -5, 8.5) },
					RightShoulder = {
						rot = Vector3.new(117.8, 0, -25),
						pos = Vector3.new(0, -0.03, 0.24),
					},
					LeftShoulder = {
						rot = Vector3.new(125, 0, 53.2),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					RightHip = { rot = Vector3.new(3, -9, 8.6), pos = Vector3.new(0, 0.61, 0) },
					LeftHip = {
						rot = Vector3.new(18.21, -10.5, 12.25),
						pos = Vector3.new(0, 0.04, 0),
					},
				},
			},
			{
				time = 0.05,
				pose = {
					Root = {
						rot = Vector3.new(-14.5, 7, -16.5),
						pos = Vector3.new(0.38, -0.34, 0.05),
					},
					Neck = { rot = Vector3.new(9.9, -7.1, 9.1) },
					RightShoulder = {
						rot = Vector3.new(118.6, 0, -23.5),
						pos = Vector3.new(0, -0.03, 0.24),
					},
					LeftShoulder = { rot = Vector3.new(123.9, 0, 32.4) },
					RightHip = {
						rot = Vector3.new(3.31, -11.4, 9.46),
						pos = Vector3.new(0, 0.67, 0),
					},
					LeftHip = {
						rot = Vector3.new(22.78, -13.3, 14.24),
						pos = Vector3.new(0, 0.06, 0),
					},
				},
			},
			{
				time = 0.11,
				pose = {
					Root = {
						rot = Vector3.new(-12, -13, -5),
						pos = Vector3.new(0.18, -0.23, -0.05),
					},
					Neck = { rot = Vector3.new(8.4, 10.9, 2.8) },
					RightShoulder = { rot = Vector3.new(115.4, 0, -38.2) },
					LeftShoulder = { rot = Vector3.new(131.9, 0, 1.3) },
					RightHip = { rot = Vector3.new(2.06, 0.6, 1.11), pos = Vector3.new(0, 0.31, 0) },
					LeftHip = { rot = Vector3.new(1.05, 0.7, 1.16), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(-13, -33, 1), pos = Vector3.new(0.05, -0.17, -0.1) },
					Neck = { rot = Vector3.new(9, 28.9, -0.6) },
					RightShoulder = {
						rot = Vector3.new(120.9, 0, -55.7),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					LeftShoulder = {
						rot = Vector3.new(147.8, 0, -0.8),
						pos = Vector3.new(0, -0.01, -0.12),
					},
					RightHip = {
						rot = Vector3.new(12.37, 12.6, -6.23),
						pos = Vector3.new(0, 0.04, 0),
					},
					LeftHip = {
						rot = Vector3.new(-6.61, 14.7, -2.62),
						pos = Vector3.new(0, 0.34, 0),
					},
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(-13.5, -42, 4), pos = Vector3.new(0, -0.15, -0.13) },
					Neck = { rot = Vector3.new(9.3, 37, -2.2) },
					RightShoulder = {
						rot = Vector3.new(120.6, 0, -61.4),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					LeftShoulder = {
						rot = Vector3.new(139.6, 0, 17),
						pos = Vector3.new(0, -0.03, -0.22),
					},
					RightHip = {
						rot = Vector3.new(18.88, 18, -11.62),
						pos = Vector3.new(0, -0.03, 0),
					},
					LeftHip = { rot = Vector3.new(-8.87, 21, -4.26), pos = Vector3.new(0, 0.39, 0) },
				},
			},
			{
				time = 0.23,
				pose = {
					Root = {
						rot = Vector3.new(-12, -44, 3.5),
						pos = Vector3.new(-0.02, -0.14, -0.12),
					},
					Neck = { rot = Vector3.new(8.4, 38.8, -1.9) },
					RightShoulder = {
						rot = Vector3.new(120, 0, -62.7),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					LeftShoulder = {
						rot = Vector3.new(127.5, 0, 39.9),
						pos = Vector3.new(0, -0.02, -0.15),
					},
					RightHip = {
						rot = Vector3.new(17.74, 19.2, -9.44),
						pos = Vector3.new(0, 0.01, 0),
					},
					LeftHip = {
						rot = Vector3.new(-11.56, 22.4, -1.51),
						pos = Vector3.new(0, 0.36, 0),
					},
				},
			},
			{
				time = 0.31,
				pose = {
					Root = { rot = Vector3.new(-9.5, -27, 2), pos = Vector3.new(0, -0.08, -0.06) },
					Neck = { rot = Vector3.new(6.9, 23.5, -1.1) },
					RightShoulder = {
						rot = Vector3.new(116.6, 0, -51.1),
						pos = Vector3.new(0, -0.03, -0.24),
					},
					LeftShoulder = {
						rot = Vector3.new(114.9, 0, 25.5),
						pos = Vector3.new(0, -0.03, 0.24),
					},
					RightHip = { rot = Vector3.new(6.83, 9, -3.78), pos = Vector3.new(0, 0.01, 0) },
					LeftHip = {
						rot = Vector3.new(-6.36, 10.5, -1.86),
						pos = Vector3.new(0, 0.24, 0),
					},
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-7, -7, -1), pos = Vector3.new(0, 0, 0.01) },
					Neck = { rot = Vector3.new(5.4, 5.5, 0.6) },
					RightShoulder = {
						rot = Vector3.new(111.5, 0, -33.9),
						pos = Vector3.new(0, -0.01, 0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(115.6, 0, 41.2),
						pos = Vector3.new(0, -0.01, -0.08),
					},
					RightHip = { rot = Vector3.new(-3.34, -3, 1.56), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(0.84, -3.5, 1.74), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.47,
				pose = {
					Root = { rot = Vector3.new(-8.3, -13.5, 0.3), pos = Vector3.new(0, -0.02, 0) },
					Neck = { rot = Vector3.new(6.2, 11.3, -0.2) },
					RightShoulder = { rot = Vector3.new(111, 0, -37.5) },
					LeftShoulder = { rot = Vector3.new(115.4, 0, 36) },
					RightHip = { rot = Vector3.new(0.82, 0.9, -0.5), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(-0.56, 1, -0.45), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.55,
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
	-- LIVER SHOT (Boxer, key 4): level change, left hook to the body. Impact 0.28 s.
	Boxer_LiverShot = {
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
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(-9, -7, -3), pos = Vector3.new(0.06, -0.08, 0) },
					Neck = { rot = Vector3.new(6.5, 5.8, 1.8) },
					RightShoulder = { rot = Vector3.new(113.5, 0, -36.7) },
					LeftShoulder = { rot = Vector3.new(116.3, 0, 36.2) },
					RightHip = { rot = Vector3.new(-1.19, -3, 2.38), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(5.3, -3.5, -0.6), pos = Vector3.new(0, 0.23, 0) },
				},
			},
			{
				time = 0.13,
				pose = {
					Root = { rot = Vector3.new(-13, -3, 8), pos = Vector3.new(-0.2, -0.32, -0.22) },
					Neck = { rot = Vector3.new(8.5, 2.4, -4.8) },
					RightShoulder = {
						rot = Vector3.new(111.9, 0, -33.9),
						pos = Vector3.new(0, -0.01, 0.08),
					},
					LeftShoulder = { rot = Vector3.new(113.9, 0, 46.3) },
					RightHip = {
						rot = Vector3.new(-4.28, -5.4, -6.6),
						pos = Vector3.new(0, 0.27, 0),
					},
					LeftHip = {
						rot = Vector3.new(9.86, -6.3, -13.04),
						pos = Vector3.new(0, 0.54, 0),
					},
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-18, 6, 13), pos = Vector3.new(-0.28, -0.6, -0.24) },
					Neck = { rot = Vector3.new(11, -5.3, -7.8) },
					RightShoulder = {
						rot = Vector3.new(111.8, 0, -27.6),
						pos = Vector3.new(0, -0.03, 0.24),
					},
					LeftShoulder = { rot = Vector3.new(94, 0, 16) },
					RightHip = {
						rot = Vector3.new(-5.1, -10.8, -11.67),
						pos = Vector3.new(0, 0.49, 0),
					},
					LeftHip = {
						rot = Vector3.new(16.05, -12.6, -13.08),
						pos = Vector3.new(0, 0.81, 0),
					},
				},
			},
			{
				time = 0.24,
				pose = {
					Root = {
						rot = Vector3.new(-20, -18, 12),
						pos = Vector3.new(-0.24, -0.58, -0.32),
					},
					Neck = { rot = Vector3.new(12, 15.1, -7.2) },
					RightShoulder = {
						rot = Vector3.new(122.9, 0, -51.4),
						pos = Vector3.new(0, -0.03, -0.24),
					},
					LeftShoulder = { rot = Vector3.new(93, 0, 24) },
					RightHip = {
						rot = Vector3.new(11.35, 3.6, -14.16),
						pos = Vector3.new(0, 0.31, 0),
					},
					LeftHip = {
						rot = Vector3.new(8.65, 4.2, -17.74),
						pos = Vector3.new(0, 0.95, 0),
					},
				},
			},
			{
				time = 0.28,
				pose = {
					Root = {
						rot = Vector3.new(-21, -40, 8),
						pos = Vector3.new(-0.18, -0.54, -0.36),
					},
					Neck = { rot = Vector3.new(12.5, 33.8, -4.8) },
					RightShoulder = {
						rot = Vector3.new(130.3, 0, -65.6),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					LeftShoulder = { rot = Vector3.new(109.1, 0, 39) },
					RightHip = {
						rot = Vector3.new(25.33, 16.8, -17.49),
						pos = Vector3.new(0, 0.18, 0),
					},
					LeftHip = { rot = Vector3.new(0, 19.6, -16.32), pos = Vector3.new(0, 0.95, 0) },
				},
			},
			{
				time = 0.34,
				pose = {
					Root = {
						rot = Vector3.new(-19, -49, 5),
						pos = Vector3.new(-0.12, -0.48, -0.32),
					},
					Neck = { rot = Vector3.new(11.5, 41.5, -3) },
					RightShoulder = {
						rot = Vector3.new(131.2, 0, -70.2),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					LeftShoulder = { rot = Vector3.new(109, 0, 39.6) },
					RightHip = {
						rot = Vector3.new(26.83, 22.2, -16.93),
						pos = Vector3.new(0, 0.22, 0),
					},
					LeftHip = {
						rot = Vector3.new(-6.38, 25.9, -13.04),
						pos = Vector3.new(0, 0.86, 0),
					},
				},
			},
			{
				time = 0.43,
				pose = {
					Root = { rot = Vector3.new(-14, -28, 2), pos = Vector3.new(-0.1, -0.26, -0.18) },
					Neck = { rot = Vector3.new(9, 23.6, -1.2) },
					RightShoulder = {
						rot = Vector3.new(123.1, 0, -56.9),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					LeftShoulder = { rot = Vector3.new(136, 0, 40.5) },
					RightHip = {
						rot = Vector3.new(11.17, 9.6, -4.37),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = {
						rot = Vector3.new(-0.66, 11.2, -6.32),
						pos = Vector3.new(0, 0.58, 0),
					},
				},
			},
			{
				time = 0.56,
				pose = {
					Root = { rot = Vector3.new(-7, -6, 1.5), pos = Vector3.new(0.02, -0.08, -0.04) },
					Neck = { rot = Vector3.new(5.5, 4.9, -0.9) },
					RightShoulder = {
						rot = Vector3.new(110.8, 0, -35.6),
						pos = Vector3.new(0, -0.01, 0.08),
					},
					LeftShoulder = { rot = Vector3.new(117.6, 0, 41.4) },
					RightHip = {
						rot = Vector3.new(-5.82, -3.6, -2.52),
						pos = Vector3.new(0, 0.1, 0),
					},
					LeftHip = {
						rot = Vector3.new(-0.76, -4.2, -2.28),
						pos = Vector3.new(0, 0.16, 0),
					},
				},
			},
			{
				time = 0.68,
				pose = {
					Root = { rot = Vector3.new(-8.4, -13, -0.4), pos = Vector3.new(0, -0.02, 0) },
					Neck = { rot = Vector3.new(6.2, 10.8, 0.2) },
					RightShoulder = { rot = Vector3.new(111.2, 0, -37) },
					LeftShoulder = { rot = Vector3.new(115.5, 0, 37.3) },
					RightHip = { rot = Vector3.new(0.76, 0.6, 0.51), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(-0.25, 0.7, 0.54), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.8,
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
	-- KNOCKOUT MODE activation (G): bounces, touches gloves, locks into a tight guard.
	Boxer_Awaken = {
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
				time = 0.09,
				pose = {
					Root = { rot = Vector3.new(-11, -15, -4), pos = Vector3.new(0.1, -0.34, 0) },
					Neck = { rot = Vector3.new(4, 12, 3) },
					RightShoulder = {
						rot = Vector3.new(111.9, -0.1, -38.6),
						pos = Vector3.new(0.01, -0.06, 0.05),
					},
					LeftShoulder = {
						rot = Vector3.new(114.3, -0.3, 37.3),
						pos = Vector3.new(0, -0.09, 0.09),
					},
					RightHip = { rot = Vector3.new(2.76, 1.8, 1.8), pos = Vector3.new(0, 0.41, 0) },
					LeftHip = { rot = Vector3.new(0.02, 2.1, 1.9), pos = Vector3.new(0, 0.37, 0) },
				},
			},
			{
				time = 0.17,
				pose = {
					Root = { rot = Vector3.new(-5, -11, 1), pos = Vector3.new(0, 0.12, 0) },
					Neck = { rot = Vector3.new(7, 9, -1) },
					RightShoulder = {
						rot = Vector3.new(113.7, 0, -40),
						pos = Vector3.new(0.1, -0.02, 0.06),
					},
					LeftShoulder = {
						rot = Vector3.new(119.2, 0, 39.9),
						pos = Vector3.new(0, -0.01, 0.02),
					},
					RightHip = {
						rot = Vector3.new(-4.67, -0.6, -0.72),
						pos = Vector3.new(0, 0.02, 0),
					},
					LeftHip = {
						rot = Vector3.new(-3.87, -0.7, -0.69),
						pos = Vector3.new(0, 0.07, 0),
					},
				},
			},
			{
				time = 0.26,
				pose = {
					Root = {
						rot = Vector3.new(-12, -9, 4.5),
						pos = Vector3.new(-0.11, -0.38, -0.02),
					},
					Neck = { rot = Vector3.new(3, 7, -3) },
					RightShoulder = {
						rot = Vector3.new(108.4, 0, -37.6),
						pos = Vector3.new(0.04, -0.12, 0.12),
					},
					LeftShoulder = {
						rot = Vector3.new(112.9, 0, 41.8),
						pos = Vector3.new(0.01, -0.06, 0.01),
					},
					RightHip = {
						rot = Vector3.new(1.98, -1.8, -3.21),
						pos = Vector3.new(0, 0.36, 0),
					},
					LeftHip = {
						rot = Vector3.new(4.25, -2.1, -2.93),
						pos = Vector3.new(0, 0.52, 0),
					},
				},
			},
			{
				time = 0.34,
				pose = {
					Root = {
						rot = Vector3.new(-9, -6, 0.5),
						pos = Vector3.new(-0.02, -0.08, -0.04),
					},
					Neck = { rot = Vector3.new(2, 5, 0) },
					RightShoulder = { rot = Vector3.new(116, 0, -46) },
					LeftShoulder = { rot = Vector3.new(118, 0, 45) },
					RightHip = {
						rot = Vector3.new(-2.69, -3.6, -0.22),
						pos = Vector3.new(0, 0.14, 0),
					},
					LeftHip = {
						rot = Vector3.new(2.34, -4.2, -0.01),
						pos = Vector3.new(0, 0.14, 0),
					},
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-12, -3, 0), pos = Vector3.new(0, -0.07, -0.07) },
					Neck = { rot = Vector3.new(-6, 2, 0) },
					RightShoulder = { rot = Vector3.new(122, 0, -53) },
					LeftShoulder = { rot = Vector3.new(124, 0, 52) },
					RightHip = {
						rot = Vector3.new(-0.43, -5.4, -0.41),
						pos = Vector3.new(0, 0.12, 0),
					},
					LeftHip = { rot = Vector3.new(7.25, -6.3, 0.08), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.46,
				pose = {
					Root = { rot = Vector3.new(-13.5, -3.5, 0), pos = Vector3.new(0, -0.1, -0.08) },
					Neck = { rot = Vector3.new(-10, 2, 0) },
					RightShoulder = { rot = Vector3.new(120, 0, -55) },
					LeftShoulder = { rot = Vector3.new(122, 0, 54) },
					RightHip = {
						rot = Vector3.new(1.4, -5.1, -0.52),
						pos = Vector3.new(0, 0.15, 0),
					},
					LeftHip = {
						rot = Vector3.new(8.69, -5.9, -0.08),
						pos = Vector3.new(0, 0.12, 0),
					},
				},
			},
			{
				time = 0.56,
				pose = {
					Root = { rot = Vector3.new(0, -10, 0), pos = Vector3.new(0, 0.1, 0.05) },
					Neck = { rot = Vector3.new(11, 9, 0) },
					RightShoulder = {
						rot = Vector3.new(114.2, 0, -35),
						pos = Vector3.new(0.03, 0.21, 0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(119.7, 0, 38.2),
						pos = Vector3.new(-0.02, 0.21, 0.04),
					},
					RightHip = {
						rot = Vector3.new(-11.09, -1.2, 1.81),
						pos = Vector3.new(0, -0.01, 0),
					},
					LeftHip = {
						rot = Vector3.new(-9.63, -1.4, 1.86),
						pos = Vector3.new(0, -0.05, 0),
					},
				},
			},
			{
				time = 0.65,
				pose = {
					Root = { rot = Vector3.new(-19, -14, 2), pos = Vector3.new(0.03, -0.24, -0.06) },
					Neck = { rot = Vector3.new(-8, 12, -2) },
					RightShoulder = {
						rot = Vector3.new(105.2, 0, -39.2),
						pos = Vector3.new(0, -0.28, 0.08),
					},
					LeftShoulder = {
						rot = Vector3.new(111.1, 0, 36.7),
						pos = Vector3.new(0, -0.27, 0.09),
					},
					RightHip = {
						rot = Vector3.new(13.53, 1.2, -6.77),
						pos = Vector3.new(0, 0.11, 0),
					},
					LeftHip = { rot = Vector3.new(10.5, 1.4, -6.28), pos = Vector3.new(0, 0.37, 0) },
				},
			},
			{
				time = 0.76,
				pose = {
					Root = {
						rot = Vector3.new(-15.5, -12.5, 0.5),
						pos = Vector3.new(0.01, -0.21, -0.03),
					},
					Neck = { rot = Vector3.new(-3, 10.5, -0.5) },
					RightShoulder = {
						rot = Vector3.new(108.9, 0.1, -37.4),
						pos = Vector3.new(0, -0.16, 0.11),
					},
					LeftShoulder = {
						rot = Vector3.new(114.6, 0, 40.2),
						pos = Vector3.new(-0.04, -0.17, 0.06),
					},
					RightHip = {
						rot = Vector3.new(8.78, 0.3, -2.87),
						pos = Vector3.new(0, 0.17, 0),
					},
					LeftHip = { rot = Vector3.new(7.78, 0.3, -2.73), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.88,
				pose = {
					Root = { rot = Vector3.new(-7.5, -12, 0), pos = Vector3.new(0, 0.03, 0) },
					Neck = { rot = Vector3.new(7, 10, 0) },
					RightShoulder = {
						rot = Vector3.new(117.5, 0, -36.9),
						pos = Vector3.new(0.01, -0.01, 0.07),
					},
					LeftShoulder = {
						rot = Vector3.new(122.6, 0, 39.2),
						pos = Vector3.new(0, -0.02, 0.02),
					},
					RightHip = { rot = Vector3.new(-0.77, 0, 0.16), pos = Vector3.new(0, 0.01, 0) },
					LeftHip = { rot = Vector3.new(-0.89, 0, 0.19), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = { rot = Vector3.new(-8, -12, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = {
						rot = Vector3.new(115.6, 0, -35.9),
						pos = Vector3.new(-0.02, -0.03, 0.07),
					},
					LeftShoulder = {
						rot = Vector3.new(119.5, 0, 39.4),
						pos = Vector3.new(-0.01, -0.01, 0.03),
					},
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},
	-- KNOCKOUT COMBO (Knockout Mode, key 4): body hook, right hook, left hook,
	-- huge right uppercut. Impacts 0.20, 0.50, 0.85, 1.25 s.
	Boxer_KnockoutCombo = {
		length = 1.6,
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
				time = 0.11,
				pose = {
					Root = { rot = Vector3.new(-17, 4, 11), pos = Vector3.new(-0.22, -0.46, -0.18) },
					Neck = { rot = Vector3.new(10.5, -3.6, -6.6) },
					RightShoulder = {
						rot = Vector3.new(112.5, 0, -29.1),
						pos = Vector3.new(0, -0.02, 0.16),
					},
					LeftShoulder = { rot = Vector3.new(85, 0, 30) },
					RightHip = {
						rot = Vector3.new(-3.91, -9.6, -9.32),
						pos = Vector3.new(0, 0.38, 0),
					},
					LeftHip = {
						rot = Vector3.new(15.81, -11.2, -11.67),
						pos = Vector3.new(0, 0.64, 0),
					},
				},
			},
			{
				time = 0.2,
				pose = {
					Root = {
						rot = Vector3.new(-21, -40, 7),
						pos = Vector3.new(-0.16, -0.52, -0.32),
					},
					Neck = { rot = Vector3.new(12.5, 33.8, -4.2) },
					RightShoulder = {
						rot = Vector3.new(129.8, 0, -65.9),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					LeftShoulder = {
						rot = Vector3.new(111.4, 0, 37.5),
						pos = Vector3.new(0, -0.02, -0.15),
					},
					RightHip = {
						rot = Vector3.new(25.39, 16.8, -16.51),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = {
						rot = Vector3.new(0.22, 19.6, -13.93),
						pos = Vector3.new(0, 0.89, 0),
					},
				},
			},
			{
				time = 0.38,
				pose = {
					Root = { rot = Vector3.new(-12, -50, -6), pos = Vector3.new(0.08, -0.3, -0.12) },
					Neck = { rot = Vector3.new(8, 42.3, 3.6) },
					RightShoulder = { rot = Vector3.new(129.8, 0, -45.3) },
					LeftShoulder = { rot = Vector3.new(114, 0, 19.3) },
					RightHip = {
						rot = Vector3.new(13.68, 22.8, -2.34),
						pos = Vector3.new(0, 0.34, 0),
					},
					LeftHip = {
						rot = Vector3.new(-18.28, 26.6, 1.47),
						pos = Vector3.new(0, 0.48, 0),
					},
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-13, 18, 5), pos = Vector3.new(-0.08, -0.24, -0.24) },
					Neck = { rot = Vector3.new(8.5, -15.5, -3) },
					RightShoulder = {
						rot = Vector3.new(130.3, 0, -26.1),
						pos = Vector3.new(0, -0.02, -0.2),
					},
					LeftShoulder = {
						rot = Vector3.new(127.4, 0, 62.6),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					RightHip = {
						rot = Vector3.new(-14.37, -18, -10.25),
						pos = Vector3.new(0, 0.23, 0),
					},
					LeftHip = {
						rot = Vector3.new(16.77, -21, -6.03),
						pos = Vector3.new(0, 0.38, 0),
					},
				},
			},
			{
				time = 0.71,
				pose = {
					Root = { rot = Vector3.new(-14, 32, 8), pos = Vector3.new(-0.16, -0.3, -0.14) },
					Neck = { rot = Vector3.new(9, -27.4, -4.8) },
					RightShoulder = { rot = Vector3.new(121.9, 0, -30.6) },
					LeftShoulder = { rot = Vector3.new(139.4, 0, 39.8) },
					RightHip = {
						rot = Vector3.new(-20.96, -26.4, -13.82),
						pos = Vector3.new(0, 0.31, 0),
					},
					LeftHip = {
						rot = Vector3.new(25.76, -30.8, -0.56),
						pos = Vector3.new(0, 0.47, 0),
					},
				},
			},
			{
				time = 0.85,
				pose = {
					Root = { rot = Vector3.new(-13, -40, -4), pos = Vector3.new(0.02, -0.24, -0.2) },
					Neck = { rot = Vector3.new(8.5, 33.8, 2.4) },
					RightShoulder = {
						rot = Vector3.new(128.2, 0, -66.3),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					LeftShoulder = {
						rot = Vector3.new(137.4, 0, 15.3),
						pos = Vector3.new(0, -0.02, -0.2),
					},
					RightHip = {
						rot = Vector3.new(11.67, 16.8, -1.51),
						pos = Vector3.new(0, 0.22, 0),
					},
					LeftHip = {
						rot = Vector3.new(-10.39, 19.6, -1.81),
						pos = Vector3.new(0, 0.38, 0),
					},
				},
			},
			{
				time = 1.07,
				pose = {
					Root = { rot = Vector3.new(-19, -34, -14), pos = Vector3.new(0.16, -0.7, 0.04) },
					Neck = { rot = Vector3.new(11.5, 28.7, 8.4) },
					RightShoulder = { rot = Vector3.new(91.7, 0, -72.3) },
					LeftShoulder = { rot = Vector3.new(125.7, 0, 31.1) },
					RightHip = {
						rot = Vector3.new(15.89, 13.2, 0.43),
						pos = Vector3.new(0, 0.79, 0),
					},
					LeftHip = {
						rot = Vector3.new(-1.45, 15.4, -1.89),
						pos = Vector3.new(0, 0.84, 0),
					},
				},
			},
			{
				time = 1.25,
				pose = {
					Root = { rot = Vector3.new(-9, 16, 8), pos = Vector3.new(-0.04, -0.04, -0.2) },
					Neck = { rot = Vector3.new(6.5, -13.8, -4.8) },
					RightShoulder = {
						rot = Vector3.new(116.4, 0, -26.6),
						pos = Vector3.new(0, -0.02, -0.15),
					},
					LeftShoulder = {
						rot = Vector3.new(125.4, 0, 60.8),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					RightHip = {
						rot = Vector3.new(-11.69, -16.8, -14.53),
						pos = Vector3.new(0, 0.05, 0),
					},
					LeftHip = {
						rot = Vector3.new(10.58, -19.6, -13.48),
						pos = Vector3.new(0, 0.3, 0),
					},
				},
			},
			{
				time = 1.38,
				pose = {
					Root = { rot = Vector3.new(0, 20, 8), pos = Vector3.new(-0.04, -0.03, -0.14) },
					Neck = { rot = Vector3.new(2, -17.2, -4.8) },
					RightShoulder = { rot = Vector3.new(138.5, 0, -24.5) },
					LeftShoulder = {
						rot = Vector3.new(121.3, 0, 64.1),
						pos = Vector3.new(0, -0.04, -0.32),
					},
					RightHip = {
						rot = Vector3.new(-26.45, -19.2, -18.97),
						pos = Vector3.new(0, -0.04, 0),
					},
					LeftHip = {
						rot = Vector3.new(0.29, -22.4, -16.66),
						pos = Vector3.new(0, 0.34, 0),
					},
				},
			},
			{
				time = 1.52,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-12, -6, 2), pos = Vector3.new(0, -0.12, -0.06) },
					Neck = { rot = Vector3.new(-8, 4.9, -1.2) },
					RightShoulder = {
						rot = Vector3.new(96.6, 0, -32.2),
						pos = Vector3.new(0, -0.02, 0.16),
					},
					LeftShoulder = {
						rot = Vector3.new(100.7, 0, 43.9),
						pos = Vector3.new(0, -0.01, 0.08),
					},
					RightHip = {
						rot = Vector3.new(1.99, -3.6, -4.36),
						pos = Vector3.new(0, 0.1, 0),
					},
					LeftHip = {
						rot = Vector3.new(7.91, -4.2, -5.57),
						pos = Vector3.new(0, 0.22, 0),
					},
				},
			},
			{
				time = 1.6,
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
	-- Victim reaction: liver shot. Folds sideways, arms to the stomach, knees buckle.
	HitLiver = {
		length = 0.9,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-4, 2, 2), pos = Vector3.new(-0.03, -0.03, 0) },
					Neck = { rot = Vector3.new(6, 4, 0) },
					RightShoulder = { rot = Vector3.new(100, 0, -28) },
					LeftShoulder = { rot = Vector3.new(104, 0, 30) },
					RightHip = { rot = Vector3.new(6, 0, -1.3), pos = Vector3.new(0, 0.02, 0) },
					LeftHip = { rot = Vector3.new(5.8, 0, -3), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(-9, 10, 10), pos = Vector3.new(-0.15, -0.05, 0.04) },
					Neck = { rot = Vector3.new(14, -7, -6) },
					RightShoulder = { rot = Vector3.new(62, 0, -30) },
					LeftShoulder = { rot = Vector3.new(98, 0, 26) },
					RightHip = { rot = Vector3.new(11.8, 0, -7.6), pos = Vector3.new(0, -0.08, 0) },
					LeftHip = { rot = Vector3.new(15.1, 0, -8.4), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(-20, -1, -8), pos = Vector3.new(-0.03, -0.24, 0.05) },
					Neck = { rot = Vector3.new(-8, -2, 8) },
					RightShoulder = { rot = Vector3.new(40, 0, -34) },
					LeftShoulder = { rot = Vector3.new(68, 0, 52) },
					RightHip = { rot = Vector3.new(28.5, 0, 10.5), pos = Vector3.new(0, 0.43, 0) },
					LeftHip = { rot = Vector3.new(29.4, 0, 9.6), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 0.27,
				pose = {
					Root = { rot = Vector3.new(-40, -11, -23), pos = Vector3.new(0.15, -0.7, 0.15) },
					Neck = { rot = Vector3.new(-40, 6, 12) },
					RightShoulder = { rot = Vector3.new(34, 0, -40) },
					LeftShoulder = { rot = Vector3.new(44, 0, 74) },
					RightHip = { rot = Vector3.new(50.1, 0, 4.9), pos = Vector3.new(0, 0.91, 0) },
					LeftHip = { rot = Vector3.new(45.2, 0, 7), pos = Vector3.new(0, 0.48, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-34, -8, -19), pos = Vector3.new(0.12, -0.62, 0.13) },
					Neck = { rot = Vector3.new(-47, 3, 9) },
					RightShoulder = { rot = Vector3.new(38, 0, -36) },
					LeftShoulder = { rot = Vector3.new(48, 0, 70) },
					RightHip = { rot = Vector3.new(44.3, 0, 7.8), pos = Vector3.new(0, 0.84, 0) },
					LeftHip = { rot = Vector3.new(41.9, 0, 8.8), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.52,
				pose = {
					Root = {
						rot = Vector3.new(-37, -11, -21),
						pos = Vector3.new(0.14, -0.67, 0.15),
					},
					Neck = { rot = Vector3.new(-39, 8, 14) },
					RightShoulder = { rot = Vector3.new(32, 0, -41) },
					LeftShoulder = { rot = Vector3.new(42, 0, 75) },
					RightHip = { rot = Vector3.new(47.5, 0, 5.1), pos = Vector3.new(0, 0.87, 0) },
					LeftHip = { rot = Vector3.new(42.4, 0, 6.8), pos = Vector3.new(0, 0.48, 0) },
				},
			},
			{
				time = 0.64,
				pose = {
					Root = { rot = Vector3.new(-24, -5, -10), pos = Vector3.new(0.07, -0.4, 0.08) },
					Neck = { rot = Vector3.new(-30, 2, 8) },
					RightShoulder = { rot = Vector3.new(28, 0, -24) },
					LeftShoulder = { rot = Vector3.new(34, 0, 44) },
					RightHip = { rot = Vector3.new(34.1, 0, 6.7), pos = Vector3.new(0, 0.54, 0) },
					LeftHip = { rot = Vector3.new(31.9, 0, 5.9), pos = Vector3.new(0, 0.28, 0) },
				},
			},
			{
				time = 0.77,
				pose = {
					Root = { rot = Vector3.new(-11, 1, 6), pos = Vector3.new(-0.01, -0.05, -0.02) },
					Neck = { rot = Vector3.new(-14, -1, 4) },
					RightShoulder = { rot = Vector3.new(16, 0, 2) },
					LeftShoulder = { rot = Vector3.new(14, 0, -2) },
					RightHip = { rot = Vector3.new(16.5, 0, -7.7), pos = Vector3.new(0, -0.04, 0) },
					LeftHip = { rot = Vector3.new(14.7, 0, -8.9), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.9,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 5) },
					Neck = { rot = Vector3.new(-22, 0, 6) },
					RightShoulder = { rot = Vector3.new(10, 0, 6) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
					RightHip = { rot = Vector3.new(22.1, 0, -6.6), pos = Vector3.new(0, -0.07, 0) },
					LeftHip = { rot = Vector3.new(19.6, 0, -8.1), pos = Vector3.new(0, 0.15, 0) },
				},
			},
		},
	},
	-- END Boxer kit
	-- BEGIN finishers
	-- Cinematic finishers (Shared/Finishers). Authored with a pose tool that
	-- solves the hits: the bat's barrel lands on the head of a body lying 3.1
	-- studs ahead (impact 1.7 s, the left hand on the handle), each punch's
	-- fist lands on the held victim 2.2 studs ahead (body shots 0.7 / 0.95 s,
	-- hooks 1.25 / 1.55 s, cross 1.85 s, uppercut 2.42 s), and the feet stay
	-- on the ground (the hips were solved for it).
	-- Street Brawler: the bat pulled from behind the back straight into a
	-- golf swing, the barrel round one tilted circle: a big, slow coil up
	-- over his right shoulder (weight on the right foot, body turned far
	-- back), a short hold, an explosive downswing low across the head from
	-- his right to his left (the barrel through it at 1.7 s), a long
	-- follow-through to a high finish, body turned to the target, weight on
	-- the left foot; then back on the shoulder.
	Brawler_FinisherBat = {
		length = 3.3,
		looped = false,
		keyframes = {
			{
				time = 0.0,
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
					Root = { rot = Vector3.new(-4, 28, 0) },
					Neck = { rot = Vector3.new(0, 18, 0) },
					RightShoulder = { rot = Vector3.new(-45, 0, 12) },
					LeftShoulder = { rot = Vector3.new(25, 0, 12) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = { rot = Vector3.new(-2, 22, 0) },
					Neck = { rot = Vector3.new(-4, 14, 0) },
					RightShoulder = { rot = Vector3.new(-30, 0, -14) },
					LeftShoulder = { rot = Vector3.new(20, 0, 10) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.55,
				pose = {
					Root = { rot = Vector3.new(-18, -43.5, 0), pos = Vector3.new(0.117, -0.314, -0.1) },
					Neck = { rot = Vector3.new(-27, 26.1, 0) },
					RightShoulder = { rot = Vector3.new(83.8, -1.93, -53) },
					LeftShoulder = { rot = Vector3.new(178, -27.7, 110) },
					RightHip = { rot = Vector3.new(14, 0, -10), pos = Vector3.new(0, 0.283, 0) },
					LeftHip = { rot = Vector3.new(-7, 0, -4), pos = Vector3.new(0, 0.283, 0) },
				},
			},
			{
				time = 0.85,
				pose = {
					Root = { rot = Vector3.new(-16, -63.8, 0), pos = Vector3.new(0.192, -0.226, -0.1) },
					Neck = { rot = Vector3.new(-22.5, 38.2, 0) },
					RightShoulder = { rot = Vector3.new(106, -1.43, -4.71) },
					LeftShoulder = { rot = Vector3.new(180, -23.7, 102) },
					RightHip = { rot = Vector3.new(8, 0, -7), pos = Vector3.new(0, 0.204, 0) },
					LeftHip = { rot = Vector3.new(-13, 0, -4), pos = Vector3.new(0, 0.204, 0) },
				},
			},
			{
				time = 1.15,
				pose = {
					Root = { rot = Vector3.new(-14, -79.5, 0), pos = Vector3.new(0.25, -0.158, -0.1) },
					Neck = { rot = Vector3.new(-19, 47.7, 0) },
					RightShoulder = { rot = Vector3.new(140, -1.22, 8.67) },
					LeftShoulder = { rot = Vector3.new(182, -14.1, 94.6) },
					RightHip = { rot = Vector3.new(8, 0, -10), pos = Vector3.new(0, 0.142, 0) },
					LeftHip = { rot = Vector3.new(-19, 0, -7), pos = Vector3.new(0, 0.142, 0) },
				},
			},
			{
				time = 1.4,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-13, -87.6, 0), pos = Vector3.new(0.25, -0.123, -0.1) },
					Neck = { rot = Vector3.new(-17.2, 52.6, 0) },
					RightShoulder = { rot = Vector3.new(163, -0.356, 12.6) },
					LeftShoulder = { rot = Vector3.new(183, -7.18, 90.6) },
					RightHip = { rot = Vector3.new(8, 0, -7), pos = Vector3.new(0, 0.111, 0) },
					LeftHip = { rot = Vector3.new(-22, 0, -7), pos = Vector3.new(0, 0.111, 0) },
				},
			},
			{
				time = 1.53,
				pose = {
					Root = { rot = Vector3.new(-17, -66, 0), pos = Vector3.new(0.2, -0.217, -0.1) },
					Neck = { rot = Vector3.new(-22, 39.6, 0) },
					RightShoulder = { rot = Vector3.new(112, -1.6, -1.02) },
					LeftShoulder = { rot = Vector3.new(156, -15.4, 92.5) },
					RightHip = { rot = Vector3.new(11, 0, -13), pos = Vector3.new(0, 0.195, 0) },
					LeftHip = { rot = Vector3.new(-16, 0, -7), pos = Vector3.new(0, 0.195, 0) },
				},
			},
			{
				time = 1.62,
				pose = {
					Root = { rot = Vector3.new(-22, -36.8, 0), pos = Vector3.new(0.0917, -0.343, -0.1) },
					Neck = { rot = Vector3.new(-28.5, 22.1, 0) },
					RightShoulder = { rot = Vector3.new(82.5, -1.89, -39.1) },
					LeftShoulder = { rot = Vector3.new(135, -23.2, 91.6) },
					RightHip = { rot = Vector3.new(17, 0, -10), pos = Vector3.new(0, 0.309, 0) },
					LeftHip = { rot = Vector3.new(-4, 0, -7), pos = Vector3.new(0, 0.309, 0) },
				},
			},
			{
				time = 1.7,
				pose = {
					Root = { rot = Vector3.new(-24, -12, 0), pos = Vector3.new(0, -0.45, -0.1) },
					Neck = { rot = Vector3.new(-34, 7.2, 0) },
					RightShoulder = { rot = Vector3.new(77.2, -5.29, -53.2) },
					LeftShoulder = { rot = Vector3.new(151, -26.2, 98.6) },
					RightHip = { rot = Vector3.new(29, 0, -4), pos = Vector3.new(0, 0.405, 0) },
					LeftHip = { rot = Vector3.new(11, 0, -4), pos = Vector3.new(0, 0.405, 0) },
				},
			},
			{
				time = 1.75,
				pose = {
					Root = { rot = Vector3.new(-22, 26.8, 0), pos = Vector3.new(-0.0833, -0.353, -0.1) },
					Neck = { rot = Vector3.new(-29, -16.1, 0) },
					RightShoulder = { rot = Vector3.new(65.7, -27.3, -58.8) },
					LeftShoulder = { rot = Vector3.new(126, -17.2, 85.6) },
					RightHip = { rot = Vector3.new(2, 0, 5), pos = Vector3.new(0, 0.318, 0) },
					LeftHip = { rot = Vector3.new(26, 0, 11), pos = Vector3.new(0, 0.318, 0) },
				},
			},
			{
				time = 1.82,
				pose = {
					Root = { rot = Vector3.new(-16, 61.5, 0), pos = Vector3.new(-0.183, -0.236, -0.1) },
					Neck = { rot = Vector3.new(-23, -36.9, 0) },
					RightShoulder = { rot = Vector3.new(-10.1, -40.8, -138) },
					LeftShoulder = { rot = Vector3.new(169, -20.2, 88.9) },
					RightHip = { rot = Vector3.new(-13, 0, 5), pos = Vector3.new(0, 0.212, 0) },
					LeftHip = { rot = Vector3.new(11, 0, 11), pos = Vector3.new(0, 0.212, 0) },
				},
			},
			{
				time = 1.95,
				pose = {
					Root = { rot = Vector3.new(-9, 82.4, 0), pos = Vector3.new(-0.25, -0.119, -0.1) },
					Neck = { rot = Vector3.new(-17, -49.5, 0) },
					RightShoulder = { rot = Vector3.new(45.3, -30.2, -148) },
					LeftShoulder = { rot = Vector3.new(155, 19.5, 87.9) },
					RightHip = { rot = Vector3.new(-19, 0, 5), pos = Vector3.new(0, 0.108, 0) },
					LeftHip = { rot = Vector3.new(8, 0, 5), pos = Vector3.new(0, 0.108, 0) },
				},
			},
			{
				time = 2.15,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-5, 88.4, 0), pos = Vector3.new(-0.25, -0.1, -0.1) },
					Neck = { rot = Vector3.new(-14, -53, 0) },
					RightShoulder = { rot = Vector3.new(72.5, -22.4, -151) },
					LeftShoulder = { rot = Vector3.new(176, 23.9, 93.3) },
					RightHip = { rot = Vector3.new(-22, 0, 11), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(8, 0, -1), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 2.45,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-5, 88.4, 0), pos = Vector3.new(-0.25, -0.1, -0.1) },
					Neck = { rot = Vector3.new(-14, -53, 0) },
					RightShoulder = { rot = Vector3.new(72.5, -22.4, -151) },
					LeftShoulder = { rot = Vector3.new(176, 23.9, 93.3) },
					RightHip = { rot = Vector3.new(-22, 0, 11), pos = Vector3.new(0, 0.09, 0) },
					LeftHip = { rot = Vector3.new(8, 0, -1), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 2.85,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(0, -12, 0) },
					Neck = { rot = Vector3.new(-24, -16, 6) },
					RightShoulder = { rot = Vector3.new(156, 0, -22) },
					LeftShoulder = { rot = Vector3.new(12, 0, 10) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 3.05,
				pose = {
					Root = { rot = Vector3.new(-5, -12, 0) },
					Neck = { rot = Vector3.new(0, 6, 0) },
					RightShoulder = { rot = Vector3.new(100, 0, -34) },
					LeftShoulder = { rot = Vector3.new(90, 0, 30) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 3.3,
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
	-- Boxer: hauls them up by the collar, two hooks to the body, right hook,
	-- left hook, cross; then a left hook into their right side under the
	-- ribs: the hand goes in, tears the liver out, he holds it out at arm's
	-- length and looks at it, then opens his hand: it drops to the floor.
	Boxer_FinisherCombo = {
		length = 4.1,
		looped = false,
		keyframes = {
			{
				time = 0.0,
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
				time = 0.25,
				pose = {
					Root = { rot = Vector3.new(-10, 10, 0), pos = Vector3.new(0, -0.05, -0.15) },
					Neck = { rot = Vector3.new(4, -6, 0) },
					RightShoulder = { rot = Vector3.new(60, 0, -30) },
					LeftShoulder = { rot = Vector3.new(112, 0, 62) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.45,
				pose = {
					Root = { rot = Vector3.new(-6, 14, 0), pos = Vector3.new(0, -0.1, -0.05) },
					Neck = { rot = Vector3.new(2, -8, 0) },
					RightShoulder = { rot = Vector3.new(40, 0, 10) },
					LeftShoulder = { rot = Vector3.new(112, 0, 62) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.62,
				pose = {
					Root = { rot = Vector3.new(-14, 30, 0), pos = Vector3.new(0, -0.25, -0.1) },
					Neck = { rot = Vector3.new(6, -20, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 0) },
					LeftShoulder = { rot = Vector3.new(132, 0, 72) },
					RightHip = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.7,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-18, -24, 0), pos = Vector3.new(0, -0.3, -0.18) },
					Neck = { rot = Vector3.new(8, 18, 0) },
					RightShoulder = { rot = Vector3.new(86, 0, -56) },
					LeftShoulder = { rot = Vector3.new(95, 0, 30) },
					RightHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.84,
				pose = {
					Root = { rot = Vector3.new(-14, 28, 0), pos = Vector3.new(0, -0.25, -0.1) },
					Neck = { rot = Vector3.new(6, -18, 0) },
					RightShoulder = { rot = Vector3.new(-6, 0, -18) },
					LeftShoulder = { rot = Vector3.new(95, 0, 30) },
					RightHip = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(8, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.95,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-18, -24, 0), pos = Vector3.new(0, -0.3, -0.18) },
					Neck = { rot = Vector3.new(8, 18, 0) },
					RightShoulder = { rot = Vector3.new(84, 0, -58) },
					LeftShoulder = { rot = Vector3.new(95, 0, 30) },
					RightHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 1.12,
				pose = {
					Root = { rot = Vector3.new(-6, 32, 0), pos = Vector3.new(0, -0.1, -0.05) },
					Neck = { rot = Vector3.new(2, -22, 0) },
					RightShoulder = { rot = Vector3.new(198, 0, -2) },
					LeftShoulder = { rot = Vector3.new(110, 0, 38) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 1.25,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-10, -30, 0), pos = Vector3.new(0, -0.12, -0.2) },
					Neck = { rot = Vector3.new(4, 26, 0) },
					RightShoulder = { rot = Vector3.new(138, 0, -52) },
					LeftShoulder = { rot = Vector3.new(110, 0, 38) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 1.42,
				pose = {
					Root = { rot = Vector3.new(-8, -32, 0), pos = Vector3.new(0, -0.1, -0.1) },
					Neck = { rot = Vector3.new(4, 24, 0) },
					RightShoulder = { rot = Vector3.new(110, 0, -38) },
					LeftShoulder = { rot = Vector3.new(198, 0, 6) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 1.55,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-10, 30, 0), pos = Vector3.new(0, -0.12, -0.2) },
					Neck = { rot = Vector3.new(4, -24, 0) },
					RightShoulder = { rot = Vector3.new(110, 0, -38) },
					LeftShoulder = { rot = Vector3.new(138, 0, 52) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 1.72,
				pose = {
					Root = { rot = Vector3.new(-8, 10, 0), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(6, -6, 0) },
					RightShoulder = { rot = Vector3.new(156, 0, -20) },
					LeftShoulder = { rot = Vector3.new(112, 0, 38) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 1.85,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-14, -22, 0), pos = Vector3.new(0, -0.1, -0.3) },
					Neck = { rot = Vector3.new(8, 18, 0) },
					RightShoulder = { rot = Vector3.new(146, 0, -58) },
					LeftShoulder = { rot = Vector3.new(112, 0, 38) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(14, 0, 0), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 2.05,
				pose = {
					Root = { rot = Vector3.new(-14, -34, 0), pos = Vector3.new(0, -0.38, -0.1) },
					Neck = { rot = Vector3.new(12, 20, 0) },
					RightShoulder = { rot = Vector3.new(108, 0, -36) },
					LeftShoulder = { rot = Vector3.new(-20, 40, -10) },
					RightHip = { rot = Vector3.new(32, 0, -16) },
					LeftHip = { rot = Vector3.new(-18, 0, 10) },
				},
			},
			{
				time = 2.25,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-38.8, 21.4, 0),
						pos = Vector3.new(0, -0.694, -0.975),
					},
					Neck = { rot = Vector3.new(20, -18, 0) },
					RightShoulder = { rot = Vector3.new(100, 0, -30) },
					LeftShoulder = { rot = Vector3.new(50.4, 48.5, 75.1) },
					RightHip = { rot = Vector3.new(-6, 0, -2) },
					LeftHip = { rot = Vector3.new(4, 0, 0) },
				},
			},
			{
				time = 2.42,
				tangent = "flat",
				pose = {
					Root = {
						rot = Vector3.new(-38.8, 16.1, 0),
						pos = Vector3.new(0, -0.721, -0.999),
					},
					Neck = { rot = Vector3.new(24, -20, 0) },
					RightShoulder = { rot = Vector3.new(96, 0, -28) },
					LeftShoulder = { rot = Vector3.new(51, 55.9, 75.3) },
					RightHip = { rot = Vector3.new(-6, 0, -2) },
					LeftHip = { rot = Vector3.new(2, 0, 0) },
				},
			},
			{
				time = 2.62,
				pose = {
					Root = { rot = Vector3.new(-4, -16, 0), pos = Vector3.new(0, -0.2, 0.15) },
					Neck = { rot = Vector3.new(8, 14, 0) },
					RightShoulder = { rot = Vector3.new(90, 0, -24) },
					LeftShoulder = { rot = Vector3.new(61, 40, -8) },
					RightHip = { rot = Vector3.new(24, 0, -6) },
					LeftHip = { rot = Vector3.new(-18, 0, 6) },
				},
			},
			{
				time = 2.95,
				pose = {
					Root = { rot = Vector3.new(-2, 14, 0), pos = Vector3.new(0, -0.05, 0.05) },
					Neck = { rot = Vector3.new(14, 30, 0) },
					RightShoulder = { rot = Vector3.new(20, 0, -10) },
					LeftShoulder = { rot = Vector3.new(96, 0, 18) },
					RightHip = { rot = Vector3.new(-8, 0, -2) },
					LeftHip = { rot = Vector3.new(10, 0, 2) },
				},
			},
			{
				time = 3.45,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(0, 16, 0), pos = Vector3.new(0, -0.05, 0.05) },
					Neck = { rot = Vector3.new(12, 34, 0) },
					RightShoulder = { rot = Vector3.new(18, 0, -10) },
					LeftShoulder = { rot = Vector3.new(98, 0, 18) },
					RightHip = { rot = Vector3.new(-10, 0, -2) },
					LeftHip = { rot = Vector3.new(10, 0, 2) },
				},
			},
			{
				time = 3.7,
				pose = {
					Root = { rot = Vector3.new(-2, 14, 0), pos = Vector3.new(0, -0.05, 0.05) },
					Neck = { rot = Vector3.new(18, 26, 0) },
					RightShoulder = { rot = Vector3.new(18, 0, -10) },
					LeftShoulder = { rot = Vector3.new(94, 0, 16) },
					RightHip = { rot = Vector3.new(-8, 0, -2) },
					LeftHip = { rot = Vector3.new(10, 0, 2) },
				},
			},
			{
				time = 4.1,
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
	-- The Boxer finisher's victim, held up (in its own space, facing the
	-- Boxer): dangling, folding on the body shots, head snapped by each
	-- punch; its right hand comes up to clutch him, it folds over the arm that
	-- goes into its side, a jerk when the
	-- liver is torn out (the server ragdolls it then).
	Boxer_FinisherVictim = {
		length = 2.8,
		looped = false,
		keyframes = {
			{
				time = 0.0,
				pose = {
					Root = { rot = Vector3.new(-22, 0, 10), pos = Vector3.new(0, -0.8, 0.25) },
					Neck = { rot = Vector3.new(-42, 0, 12) },
					RightShoulder = { rot = Vector3.new(4, 0, 6) },
					LeftShoulder = { rot = Vector3.new(6, 0, -8) },
					RightHip = { rot = Vector3.new(30, 0, -8), pos = Vector3.new(0, 0.9, 0) },
					LeftHip = { rot = Vector3.new(34, 0, -8), pos = Vector3.new(0, 0.9, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-12, 0, 6), pos = Vector3.new(0, -0.3, 0.1) },
					Neck = { rot = Vector3.new(-38, 0, 10) },
					RightShoulder = { rot = Vector3.new(6, 0, 4) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
					RightHip = { rot = Vector3.new(18, 0, -6), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(20, 0, -8), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = { rot = Vector3.new(-10, 0, 4), pos = Vector3.new(0, -0.25, 0.1) },
					Neck = { rot = Vector3.new(-24, 0, 6) },
					RightShoulder = { rot = Vector3.new(8, 0, 6) },
					LeftShoulder = { rot = Vector3.new(8, 0, -8) },
					RightHip = { rot = Vector3.new(16, 0, -4), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(22, 0, -4), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 0.74,
				pose = {
					Root = { rot = Vector3.new(-30, 8, -10), pos = Vector3.new(0, -0.4, 0.25) },
					Neck = { rot = Vector3.new(-10, 0, 0) },
					RightShoulder = { rot = Vector3.new(30, 0, -4) },
					LeftShoulder = { rot = Vector3.new(36, 0, 10) },
					RightHip = { rot = Vector3.new(52, 0, 16), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(40, 0, 14), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 0.88,
				pose = {
					Root = { rot = Vector3.new(-12, 0, 6), pos = Vector3.new(0, -0.3, 0.1) },
					Neck = { rot = Vector3.new(-38, 0, 10) },
					RightShoulder = { rot = Vector3.new(6, 0, 4) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
					RightHip = { rot = Vector3.new(18, 0, -6), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(20, 0, -8), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.99,
				pose = {
					Root = { rot = Vector3.new(-34, 10, -12), pos = Vector3.new(0, -0.45, 0.28) },
					Neck = { rot = Vector3.new(-8, 0, 0) },
					RightShoulder = { rot = Vector3.new(34, 0, -4) },
					LeftShoulder = { rot = Vector3.new(40, 0, 12) },
					RightHip = { rot = Vector3.new(58, 0, 18), pos = Vector3.new(0, 0.45, 0) },
					LeftHip = { rot = Vector3.new(46, 0, 16), pos = Vector3.new(0, 0.45, 0) },
				},
			},
			{
				time = 1.15,
				pose = {
					Root = { rot = Vector3.new(-12, 0, 6), pos = Vector3.new(0, -0.3, 0.1) },
					Neck = { rot = Vector3.new(-38, 0, 10) },
					RightShoulder = { rot = Vector3.new(6, 0, 4) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
					RightHip = { rot = Vector3.new(18, 0, -6), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(20, 0, -8), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 1.29,
				pose = {
					Root = { rot = Vector3.new(-12, -24, 12), pos = Vector3.new(0.1, -0.25, 0.1) },
					Neck = { rot = Vector3.new(6, -48, 26) },
					RightShoulder = { rot = Vector3.new(10, 0, 24) },
					LeftShoulder = { rot = Vector3.new(20, 0, -30) },
					RightHip = { rot = Vector3.new(14, 0, -22), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(-16, 0, -14), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 1.45,
				pose = {
					Root = { rot = Vector3.new(-12, 0, 6), pos = Vector3.new(0, -0.3, 0.1) },
					Neck = { rot = Vector3.new(-38, 0, 10) },
					RightShoulder = { rot = Vector3.new(6, 0, 4) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
					RightHip = { rot = Vector3.new(18, 0, -6), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(20, 0, -8), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 1.59,
				pose = {
					Root = { rot = Vector3.new(-12, 24, -12), pos = Vector3.new(-0.1, -0.25, 0.1) },
					Neck = { rot = Vector3.new(6, 48, -26) },
					RightShoulder = { rot = Vector3.new(20, 0, 30) },
					LeftShoulder = { rot = Vector3.new(10, 0, -24) },
					RightHip = { rot = Vector3.new(-16, 0, 14), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(14, 0, 22), pos = Vector3.new(0, 0.25, 0) },
				},
			},
			{
				time = 1.74,
				pose = {
					Root = { rot = Vector3.new(-12, 0, 6), pos = Vector3.new(0, -0.3, 0.1) },
					Neck = { rot = Vector3.new(-38, 0, 10) },
					RightShoulder = { rot = Vector3.new(6, 0, 4) },
					LeftShoulder = { rot = Vector3.new(8, 0, -6) },
					RightHip = { rot = Vector3.new(18, 0, -6), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(20, 0, -8), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 1.89,
				pose = {
					Root = { rot = Vector3.new(14, 0, 0), pos = Vector3.new(0, -0.2, 0.25) },
					Neck = { rot = Vector3.new(34, 0, 0) },
					RightShoulder = { rot = Vector3.new(16, 0, 16) },
					LeftShoulder = { rot = Vector3.new(16, 0, -16) },
					RightHip = { rot = Vector3.new(-12, 0, 0), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(-12, 0, 0), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 2.15,
				pose = {
					Root = { rot = Vector3.new(-16, 0, 10), pos = Vector3.new(0, -0.4, 0.15) },
					Neck = { rot = Vector3.new(-30, 0, 12) },
					RightShoulder = { rot = Vector3.new(120, 0, 16) },
					LeftShoulder = { rot = Vector3.new(8, 0, -8) },
					RightHip = { rot = Vector3.new(24, 0, -10), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(38, 0, -12), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 2.28,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-34, 14, 12), pos = Vector3.new(0.1, -0.5, 0.3) },
					Neck = { rot = Vector3.new(-18, 10, 0) },
					RightShoulder = { rot = Vector3.new(135, 0, 18) },
					LeftShoulder = { rot = Vector3.new(40, 0, 24) },
					RightHip = { rot = Vector3.new(44, 0, -2), pos = Vector3.new(0, 0.5, 0) },
					LeftHip = { rot = Vector3.new(42, 0, -6), pos = Vector3.new(0, 0.5, 0) },
				},
			},
			{
				time = 2.42,
				pose = {
					Root = { rot = Vector3.new(-38, 16, 14), pos = Vector3.new(0.1, -0.55, 0.32) },
					Neck = { rot = Vector3.new(-8, 14, 0) },
					RightShoulder = { rot = Vector3.new(140, 0, 20) },
					LeftShoulder = { rot = Vector3.new(46, 0, 26) },
					RightHip = { rot = Vector3.new(48, 0, -2), pos = Vector3.new(0, 0.55, 0) },
					LeftHip = { rot = Vector3.new(44, 0, -6), pos = Vector3.new(0, 0.55, 0) },
				},
			},
			{
				time = 2.62,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-10, -6, -6), pos = Vector3.new(0, -0.35, 0.2) },
					Neck = { rot = Vector3.new(40, -10, 0) },
					RightShoulder = { rot = Vector3.new(70, 0, 40) },
					LeftShoulder = { rot = Vector3.new(24, 0, -30) },
					RightHip = { rot = Vector3.new(24, 0, 4), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(16, 0, 6), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 2.8,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-10, -6, -6), pos = Vector3.new(0, -0.35, 0.2) },
					Neck = { rot = Vector3.new(40, -10, 0) },
					RightShoulder = { rot = Vector3.new(70, 0, 40) },
					LeftShoulder = { rot = Vector3.new(24, 0, -30) },
					RightHip = { rot = Vector3.new(24, 0, 4), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(16, 0, 6), pos = Vector3.new(0, 0.35, 0) },
				},
			},
		},
	},
	-- Under the Street Brawler's bat (Shared/Finishers "Bat"): laid out on
	-- its back, it lifts its head and reaches out a hand, pleading, then
	-- turns its face away as the bat comes down. Root at rest: the server
	-- lays the body flat.
	Brawler_FinisherBatVictim = {
		length = 2.0,
		looped = false,
		keyframes = {
			{
				time = 0.0,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(6, 0, 0) },
					RightShoulder = { rot = Vector3.new(4, 0, 12) },
					LeftShoulder = { rot = Vector3.new(2, 0, -12) },
					RightHip = { rot = Vector3.new(0, 0, 5) },
					LeftHip = { rot = Vector3.new(0, 0, -5) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(22, 4, 0) },
					RightShoulder = { rot = Vector3.new(118, 0, 12) },
					LeftShoulder = { rot = Vector3.new(18, 0, -16) },
					RightHip = { rot = Vector3.new(0, 0, 5) },
					LeftHip = { rot = Vector3.new(0, 0, -5) },
				},
			},
			{
				time = 0.8,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(26, -4, 0) },
					RightShoulder = { rot = Vector3.new(130, 0, 4) },
					LeftShoulder = { rot = Vector3.new(22, 0, -14) },
					RightHip = { rot = Vector3.new(0, 0, 5) },
					LeftHip = { rot = Vector3.new(0, 0, -5) },
				},
			},
			{
				time = 1.0,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(24, 6, 0) },
					RightShoulder = { rot = Vector3.new(116, 0, 16) },
					LeftShoulder = { rot = Vector3.new(20, 0, -16) },
					RightHip = { rot = Vector3.new(0, 0, 5) },
					LeftHip = { rot = Vector3.new(0, 0, -5) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(26, 0, 0) },
					RightShoulder = { rot = Vector3.new(128, 0, 6) },
					LeftShoulder = { rot = Vector3.new(22, 0, -14) },
					RightHip = { rot = Vector3.new(0, 0, 5) },
					LeftHip = { rot = Vector3.new(0, 0, -5) },
				},
			},
			{
				time = 1.42,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(-4, 34, 0) },
					RightShoulder = { rot = Vector3.new(36, 0, 24) },
					LeftShoulder = { rot = Vector3.new(10, 0, -22) },
					RightHip = { rot = Vector3.new(0, 0, 5) },
					LeftHip = { rot = Vector3.new(0, 0, -5) },
				},
			},
			{
				time = 2.0,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(-4, 34, 0) },
					RightShoulder = { rot = Vector3.new(36, 0, 24) },
					LeftShoulder = { rot = Vector3.new(10, 0, -22) },
					RightHip = { rot = Vector3.new(0, 0, 5) },
					LeftHip = { rot = Vector3.new(0, 0, -5) },
				},
			},
		},
	},
	-- END finishers
	-- BEGIN emotes (generated)
	-- EMOTE (shop): come here. Chin up, beckons twice, a slow shrug.
	Emote_ComeHere = {
		length = 2,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 0) },
					LeftShoulder = { rot = Vector3.new(0, 0, 0) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(3, 2, 2.5), pos = Vector3.new(-0.04, -0.06, 0.08) },
					Neck = { rot = Vector3.new(6, -1, -2) },
					RightShoulder = { rot = Vector3.new(30, 0, 2), pos = Vector3.new(0, 0.02, 0) },
					LeftShoulder = { rot = Vector3.new(-5, 0, -5) },
					RightHip = {
						rot = Vector3.new(-3.25, -1.86, -2.65),
						pos = Vector3.new(0, 0.01, 0),
					},
					LeftHip = {
						rot = Vector3.new(-1.22, -1.95, -2.54),
						pos = Vector3.new(0, 0.12, 0),
					},
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(6, 3, 4), pos = Vector3.new(-0.07, -0.12, 0.15) },
					Neck = { rot = Vector3.new(14, -2, -3) },
					RightShoulder = {
						rot = Vector3.new(76, -8, 16),
						pos = Vector3.new(0, 0.04, -0.1),
					},
					LeftShoulder = { rot = Vector3.new(-9, 0, -9) },
					RightHip = {
						rot = Vector3.new(-6.14, -2.56, -4.09),
						pos = Vector3.new(0, 0.04, 0),
					},
					LeftHip = {
						rot = Vector3.new(-3.06, -2.79, -3.82),
						pos = Vector3.new(0, 0.21, 0),
					},
				},
			},
			{
				time = 0.56,
				pose = {
					Root = { rot = Vector3.new(7, 9, 4), pos = Vector3.new(-0.07, -0.12, 0.17) },
					Neck = { rot = Vector3.new(17, -7, -3) },
					RightShoulder = {
						rot = Vector3.new(120, -8, -8),
						pos = Vector3.new(0, 0.1, 0.14),
					},
					LeftShoulder = { rot = Vector3.new(-9, 0, -9) },
					RightHip = {
						rot = Vector3.new(-10.62, -8.14, -4.98),
						pos = Vector3.new(0, 0.05, 0),
					},
					LeftHip = {
						rot = Vector3.new(-1.44, -8.92, -4.09),
						pos = Vector3.new(0, 0.24, 0),
					},
				},
			},
			{
				time = 0.74,
				pose = {
					Root = { rot = Vector3.new(6, 2, 4), pos = Vector3.new(-0.07, -0.13, 0.15) },
					Neck = { rot = Vector3.new(15, -1, -4) },
					RightShoulder = {
						rot = Vector3.new(72, -8, 20),
						pos = Vector3.new(0, 0.03, -0.12),
					},
					LeftShoulder = { rot = Vector3.new(-8, 0, -9) },
					RightHip = {
						rot = Vector3.new(-5.49, -1.61, -3.96),
						pos = Vector3.new(0, 0.06, 0),
					},
					LeftHip = {
						rot = Vector3.new(-3.44, -1.76, -3.75),
						pos = Vector3.new(0, 0.22, 0),
					},
				},
			},
			{
				time = 0.94,
				pose = {
					Root = { rot = Vector3.new(9, 11, 5), pos = Vector3.new(-0.08, -0.14, 0.19) },
					Neck = { rot = Vector3.new(20, -9, -4) },
					RightShoulder = {
						rot = Vector3.new(132, -8, -12),
						pos = Vector3.new(0, 0.13, 0.17),
					},
					LeftShoulder = { rot = Vector3.new(-10, 0, -10) },
					RightHip = {
						rot = Vector3.new(-14.34, -9.49, -6.89),
						pos = Vector3.new(0, 0.05, 0),
					},
					LeftHip = {
						rot = Vector3.new(-3.06, -10.77, -5.57),
						pos = Vector3.new(0, 0.29, 0),
					},
				},
			},
			{
				time = 1.08,
				pose = {
					Root = { rot = Vector3.new(8, 10, 5), pos = Vector3.new(-0.08, -0.14, 0.18) },
					Neck = { rot = Vector3.new(19, -8, -2) },
					RightShoulder = {
						rot = Vector3.new(124, -8, -8),
						pos = Vector3.new(0, 0.11, 0.15),
					},
					LeftShoulder = { rot = Vector3.new(-9, 0, -10) },
					RightHip = {
						rot = Vector3.new(-12.54, -8.74, -6.48),
						pos = Vector3.new(0, 0.05, 0),
					},
					LeftHip = {
						rot = Vector3.new(-2.32, -9.83, -5.34),
						pos = Vector3.new(0, 0.28, 0),
					},
				},
			},
			{
				time = 1.28,
				pose = {
					Root = { rot = Vector3.new(4, 5, 1), pos = Vector3.new(-0.03, -0.08, 0.08) },
					Neck = { rot = Vector3.new(10, -4, 5) },
					RightShoulder = { rot = Vector3.new(24, 0, 26), pos = Vector3.new(0, 0.1, 0) },
					LeftShoulder = { rot = Vector3.new(18, 0, -24), pos = Vector3.new(0, 0.08, 0) },
					RightHip = {
						rot = Vector3.new(-6.15, -4.86, -1.01),
						pos = Vector3.new(0, 0.08, 0),
					},
					LeftHip = {
						rot = Vector3.new(-1.13, -4.98, -0.78),
						pos = Vector3.new(0, 0.12, 0),
					},
				},
			},
			{
				time = 1.44,
				pose = {
					Root = { rot = Vector3.new(3, 4, -1), pos = Vector3.new(0, -0.04, 0.04) },
					Neck = { rot = Vector3.new(8, -3, 13) },
					RightShoulder = {
						rot = Vector3.new(18, 0, 32),
						pos = Vector3.new(0, 0.25, 0.02),
					},
					LeftShoulder = {
						rot = Vector3.new(14, 0, -30),
						pos = Vector3.new(0, 0.24, 0.02),
					},
					RightHip = {
						rot = Vector3.new(-5.16, -4.07, 1.17),
						pos = Vector3.new(0, 0.08, 0),
					},
					LeftHip = {
						rot = Vector3.new(-1.17, -4.02, 1.32),
						pos = Vector3.new(0, 0.04, 0),
					},
				},
			},
			{
				time = 1.56,
				pose = {
					Root = { rot = Vector3.new(3, 3, -2), pos = Vector3.new(0, -0.03, 0.04) },
					Neck = { rot = Vector3.new(9, -2, 16) },
					RightShoulder = {
						rot = Vector3.new(17, 0, 30),
						pos = Vector3.new(0, 0.28, 0.02),
					},
					LeftShoulder = {
						rot = Vector3.new(13, 0, -28),
						pos = Vector3.new(0, 0.27, 0.02),
					},
					RightHip = {
						rot = Vector3.new(-4.61, -3.15, 2.71),
						pos = Vector3.new(0, 0.09, 0),
					},
					LeftHip = {
						rot = Vector3.new(-1.63, -3.06, 2.85),
						pos = Vector3.new(0, 0.01, 0),
					},
				},
			},
			{
				time = 1.74,
				pose = {
					Root = { rot = Vector3.new(-1, 2, 0), pos = Vector3.new(0, -0.07, 0.01) },
					Neck = { rot = Vector3.new(-2, -1, 3) },
					RightShoulder = { rot = Vector3.new(5, 0, 5), pos = Vector3.new(0, -0.03, 0) },
					LeftShoulder = { rot = Vector3.new(3, 0, -5), pos = Vector3.new(0, -0.03, 0) },
					RightHip = { rot = Vector3.new(0.75, -2, 0.04), pos = Vector3.new(0, 0.07, 0) },
					LeftHip = { rot = Vector3.new(2.75, -2, 0.08), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 2,
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
	-- EMOTE (shop): cracks the knuckles, rolls the neck, shakes the hands out.
	Emote_KnuckleCrack = {
		length = 2.2,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 0) },
					LeftShoulder = { rot = Vector3.new(0, 0, 0) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(3, -3, 0), pos = Vector3.new(0, 0.03, 0) },
					Neck = { rot = Vector3.new(-10, 0, 0) },
					RightShoulder = { rot = Vector3.new(55, 0, -12), pos = Vector3.new(0, 0.07, 0) },
					LeftShoulder = { rot = Vector3.new(58, 0, 10), pos = Vector3.new(0, 0.07, 0) },
					RightHip = { rot = Vector3.new(-3, 3, 0.16), pos = Vector3.new(0, -0.03, 0) },
					LeftHip = { rot = Vector3.new(-3, 3, 0.16), pos = Vector3.new(0, -0.03, 0.11) },
				},
			},
			{
				time = 0.34,
				pose = {
					Root = { rot = Vector3.new(-5, -9, 0), pos = Vector3.new(0, -0.02, 0.03) },
					Neck = { rot = Vector3.new(-26, 6, 0) },
					RightShoulder = {
						rot = Vector3.new(101.2, 0, -49.9),
						pos = Vector3.new(0, 0.06, 0.06),
					},
					LeftShoulder = {
						rot = Vector3.new(105.4, 0, 22.6),
						pos = Vector3.new(0, 0.06, -0.04),
					},
					RightHip = {
						rot = Vector3.new(5.06, 8.97, -0.79),
						pos = Vector3.new(-0.03, 0.03, -0.27),
					},
					LeftHip = {
						rot = Vector3.new(5.06, 8.97, -0.79),
						pos = Vector3.new(-0.01, 0.03, 0.04),
					},
				},
			},
			{
				time = 0.42,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-13, 16, 2), pos = Vector3.new(0.03, -0.16, -0.06) },
					Neck = { rot = Vector3.new(-42, -9, 3) },
					RightShoulder = {
						rot = Vector3.new(108.6, 0, -45.7),
						pos = Vector3.new(0, 0.2, -0.2),
					},
					LeftShoulder = {
						rot = Vector3.new(111.9, 0, 34.1),
						pos = Vector3.new(0, 0.15, -0.18),
					},
					RightHip = {
						rot = Vector3.new(12.95, -16.04, 1.67),
						pos = Vector3.new(-0.06, 0.14, 0.14),
					},
					LeftHip = {
						rot = Vector3.new(12.95, -16.04, 1.67),
						pos = Vector3.new(0.02, 0.2, -0.41),
					},
				},
			},
			{
				time = 0.52,
				pose = {
					Root = { rot = Vector3.new(-5, -7, 0), pos = Vector3.new(0, -0.02, 0.03) },
					Neck = { rot = Vector3.new(-24, 4, 0) },
					RightShoulder = {
						rot = Vector3.new(101.5, 0, -47),
						pos = Vector3.new(0, 0.05, 0.06),
					},
					LeftShoulder = {
						rot = Vector3.new(105.4, 0, 25.2),
						pos = Vector3.new(0, 0.05, -0.03),
					},
					RightHip = {
						rot = Vector3.new(5.04, 6.97, -0.61),
						pos = Vector3.new(-0.02, 0.03, -0.24),
					},
					LeftHip = {
						rot = Vector3.new(5.04, 6.97, -0.61),
						pos = Vector3.new(-0.01, 0.03, 0.01),
					},
				},
			},
			{
				time = 0.6,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-15, 20, 3), pos = Vector3.new(0.04, -0.2, -0.07) },
					Neck = { rot = Vector3.new(-46, -11, 4) },
					RightShoulder = {
						rot = Vector3.new(110.6, 0, -45.5),
						pos = Vector3.new(0, 0.24, -0.24),
					},
					LeftShoulder = {
						rot = Vector3.new(114.5, 0, 35),
						pos = Vector3.new(0, 0.17, -0.2),
					},
					RightHip = {
						rot = Vector3.new(14.88, -20.09, 2.31),
						pos = Vector3.new(-0.09, 0.16, 0.2),
					},
					LeftHip = {
						rot = Vector3.new(14.88, -20.09, 2.31),
						pos = Vector3.new(0.03, 0.26, -0.49),
					},
				},
			},
			{
				time = 0.95,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-3, 3, -2), pos = Vector3.new(0, -0.04, 0) },
					Neck = { rot = Vector3.new(-22, -6, -34) },
					RightShoulder = { rot = Vector3.new(8, 0, -3), pos = Vector3.new(0, 0.06, 0) },
					LeftShoulder = { rot = Vector3.new(6, 0, 3), pos = Vector3.new(0, -0.05, 0) },
					RightHip = {
						rot = Vector3.new(3.11, -2.89, 2.16),
						pos = Vector3.new(0.03, 0.08, 0),
					},
					LeftHip = {
						rot = Vector3.new(3.11, -2.89, 2.16),
						pos = Vector3.new(0.04, 0.01, -0.1),
					},
				},
			},
			{
				time = 1.35,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-3, -3, 2), pos = Vector3.new(0, -0.04, 0) },
					Neck = { rot = Vector3.new(-22, 6, 36) },
					RightShoulder = { rot = Vector3.new(6, 0, -3), pos = Vector3.new(0, -0.05, 0) },
					LeftShoulder = { rot = Vector3.new(8, 0, 3), pos = Vector3.new(0, 0.06, 0) },
					RightHip = {
						rot = Vector3.new(3.11, 2.89, -2.16),
						pos = Vector3.new(-0.04, 0.01, -0.1),
					},
					LeftHip = {
						rot = Vector3.new(3.11, 2.89, -2.16),
						pos = Vector3.new(-0.03, 0.08, 0),
					},
				},
			},
			{
				time = 1.55,
				pose = {
					Root = { rot = Vector3.new(0, -5, -3), pos = Vector3.new(0.04, -0.03, 0) },
					Neck = { rot = Vector3.new(6, -3, -3) },
					RightShoulder = { rot = Vector3.new(32, 0, 26), pos = Vector3.new(0, 0.09, 0) },
					LeftShoulder = { rot = Vector3.new(-18, 0, -8), pos = Vector3.new(0, -0.02, 0) },
					RightHip = {
						rot = Vector3.new(-0.26, 4.99, 3.01),
						pos = Vector3.new(0.01, 0.08, -0.08),
					},
					LeftHip = {
						rot = Vector3.new(-0.26, 4.99, 3.01),
						pos = Vector3.new(0.02, -0.02, 0.09),
					},
				},
			},
			{
				time = 1.68,
				pose = {
					Root = { rot = Vector3.new(0, 5, 3), pos = Vector3.new(-0.04, -0.06, 0) },
					Neck = { rot = Vector3.new(5, 3, 3) },
					RightShoulder = { rot = Vector3.new(-16, 0, 8), pos = Vector3.new(0, -0.02, 0) },
					LeftShoulder = { rot = Vector3.new(30, 0, -24), pos = Vector3.new(0, 0.09, 0) },
					RightHip = {
						rot = Vector3.new(-0.26, -4.99, -3.01),
						pos = Vector3.new(-0.01, 0.01, 0.09),
					},
					LeftHip = {
						rot = Vector3.new(-0.26, -4.99, -3.01),
						pos = Vector3.new(0, 0.11, -0.08),
					},
				},
			},
			{
				time = 1.81,
				pose = {
					Root = { rot = Vector3.new(0, -2, -1), pos = Vector3.new(0.02, -0.02, 0) },
					Neck = { rot = Vector3.new(4, -1, -1) },
					RightShoulder = { rot = Vector3.new(16, 0, 14), pos = Vector3.new(0, 0.04, 0) },
					LeftShoulder = { rot = Vector3.new(-8, 0, -6) },
					RightHip = { rot = Vector3.new(-0.03, 2, 1), pos = Vector3.new(0, 0.04, -0.03) },
					LeftHip = { rot = Vector3.new(-0.03, 2, 1), pos = Vector3.new(0, 0, 0.04) },
				},
			},
			{
				time = 2.2,
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
	-- EMOTE (shop): shrug, "is that all?".
	Emote_Shrug = {
		length = 1.6,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 0) },
					LeftShoulder = { rot = Vector3.new(0, 0, 0) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.11,
				pose = {
					Root = {
						rot = Vector3.new(-2.5, -1.5, -3),
						pos = Vector3.new(-0.11, -0.09, -0.02),
					},
					Neck = { rot = Vector3.new(-4, 1, 1) },
					RightShoulder = { rot = Vector3.new(4, 0, -5) },
					LeftShoulder = { rot = Vector3.new(4, 0, 5) },
					RightHip = {
						rot = Vector3.new(3.58, 1.69, 7.23),
						pos = Vector3.new(0, 0.22, 0),
					},
					LeftHip = { rot = Vector3.new(2.2, 1.62, 7.54), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = { rot = Vector3.new(1, 3, -1.5), pos = Vector3.new(-0.08, -0.05, 0.08) },
					Neck = { rot = Vector3.new(1, -2, -1) },
					RightShoulder = {
						rot = Vector3.new(12, -12, 16),
						pos = Vector3.new(0, 0.07, 0),
					},
					LeftShoulder = { rot = Vector3.new(9, 10, -13), pos = Vector3.new(0, 0.05, 0) },
					RightHip = {
						rot = Vector3.new(-9.83, -3.21, 4.35),
						pos = Vector3.new(0, 0.34, 0),
					},
					LeftHip = { rot = Vector3.new(2.5, -2.93, 4.6), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = { rot = Vector3.new(5, 7, 1.5), pos = Vector3.new(0.04, -0.12, 0.22) },
					Neck = { rot = Vector3.new(6, -4, 6) },
					RightShoulder = {
						rot = Vector3.new(28, -26, 27),
						pos = Vector3.new(0, 0.16, 0),
					},
					LeftShoulder = { rot = Vector3.new(24, 24, -22), pos = Vector3.new(0, 0.13, 0) },
					RightHip = {
						rot = Vector3.new(-16.8, 5.49, -4.25),
						pos = Vector3.new(0, 0.14, 0),
					},
					LeftHip = {
						rot = Vector3.new(2.53, -7.06, -3.11),
						pos = Vector3.new(0, 0.23, 0),
					},
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(7, 9, 3), pos = Vector3.new(0.06, -0.05, 0.25) },
					Neck = { rot = Vector3.new(11, -6, 12) },
					RightShoulder = {
						rot = Vector3.new(38, -37, 37),
						pos = Vector3.new(0, 0.27, 0.02),
					},
					LeftShoulder = {
						rot = Vector3.new(32, 33, -29),
						pos = Vector3.new(0, 0.23, 0.02),
					},
					RightHip = {
						rot = Vector3.new(-19.93, 4.27, -7.95),
						pos = Vector3.new(0, 0.02, 0),
					},
					LeftHip = {
						rot = Vector3.new(0.98, -9.06, -6.06),
						pos = Vector3.new(0, 0.22, 0),
					},
				},
			},
			{
				time = 0.66,
				pose = {
					Root = { rot = Vector3.new(6, 8, 3.5), pos = Vector3.new(0.06, -0.08, 0.24) },
					Neck = { rot = Vector3.new(9, 6, 14) },
					RightShoulder = {
						rot = Vector3.new(35, -39, 39),
						pos = Vector3.new(0, 0.21, 0.02),
					},
					LeftShoulder = {
						rot = Vector3.new(30, 36, -32),
						pos = Vector3.new(0, 0.18, 0.02),
					},
					RightHip = {
						rot = Vector3.new(-18.05, 5.23, -8.14),
						pos = Vector3.new(0, 0.05, 0),
					},
					LeftHip = {
						rot = Vector3.new(1.69, -8.11, -6.55),
						pos = Vector3.new(0, 0.25, 0),
					},
				},
			},
			{
				time = 0.83,
				pose = {
					Root = {
						rot = Vector3.new(6.5, 8.5, 3.5),
						pos = Vector3.new(0.06, -0.07, 0.24),
					},
					Neck = { rot = Vector3.new(12, -5, 16) },
					RightShoulder = {
						rot = Vector3.new(34, -40, 38),
						pos = Vector3.new(0, 0.19, 0.02),
					},
					LeftShoulder = {
						rot = Vector3.new(29, 37, -32),
						pos = Vector3.new(0, 0.16, 0.02),
					},
					RightHip = {
						rot = Vector3.new(-19.1, 4.84, -8.41),
						pos = Vector3.new(0, 0.04, 0),
					},
					LeftHip = {
						rot = Vector3.new(1.16, -8.58, -6.66),
						pos = Vector3.new(0, 0.25, 0),
					},
				},
			},
			{
				time = 0.99,
				pose = {
					Root = { rot = Vector3.new(-1, 4, -1), pos = Vector3.new(-0.08, -0.14, 0.12) },
					Neck = { rot = Vector3.new(-2, -3, 5) },
					RightShoulder = { rot = Vector3.new(4, -8, 8), pos = Vector3.new(0, -0.05, 0) },
					LeftShoulder = { rot = Vector3.new(3, 8, -7), pos = Vector3.new(0, -0.04, 0) },
					RightHip = {
						rot = Vector3.new(-11.06, 5.67, 3.92),
						pos = Vector3.new(0, 0.25, 0),
					},
					LeftHip = {
						rot = Vector3.new(7.05, -3.84, 4.13),
						pos = Vector3.new(0, 0.16, 0),
					},
				},
			},
			{
				time = 1.14,
				pose = {
					Root = { rot = Vector3.new(-1, 2, -2.5), pos = Vector3.new(-0.1, -0.07, 0.04) },
					Neck = { rot = Vector3.new(-2, -1, 2) },
					RightShoulder = { rot = Vector3.new(-4, -2, 3) },
					LeftShoulder = { rot = Vector3.new(-3, 2, -3) },
					RightHip = {
						rot = Vector3.new(-4.09, 1.81, 6.59),
						pos = Vector3.new(0, 0.35, 0),
					},
					LeftHip = {
						rot = Vector3.new(3.78, -1.83, 6.68),
						pos = Vector3.new(0, 0.04, 0),
					},
				},
			},
			{
				time = 1.28,
				pose = {
					Root = { rot = Vector3.new(-1.5, 0, 0.5), pos = Vector3.new(0, -0.08, -0.01) },
					Neck = { rot = Vector3.new(-3, 0, -1) },
					RightShoulder = { rot = Vector3.new(3, 0, -2) },
					LeftShoulder = { rot = Vector3.new(2, 0, 2) },
					RightHip = {
						rot = Vector3.new(1.9, -0.02, -0.73),
						pos = Vector3.new(0, 0.07, 0),
					},
					LeftHip = { rot = Vector3.new(1.9, -0.02, -0.73), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 1.42,
				pose = {
					Root = { rot = Vector3.new(0.8, 0, 0), pos = Vector3.new(0, 0, 0.01) },
					Neck = { rot = Vector3.new(1, 0, 0) },
					RightShoulder = { rot = Vector3.new(-1, 0, 1) },
					LeftShoulder = { rot = Vector3.new(-1, 0, -1) },
					RightHip = { rot = Vector3.new(-0.91, 0, 0), pos = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(-0.91, 0, 0), pos = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 1.6,
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
	-- EMOTE (shop): two pounds on the chest, then "what?".
	Emote_Flex = {
		length = 2,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 0) },
					LeftShoulder = { rot = Vector3.new(0, 0, 0) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.24,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(6, -12, -2), pos = Vector3.new(0.02, -0.03, 0.04) },
					Neck = { rot = Vector3.new(8, 8, 1) },
					RightShoulder = {
						rot = Vector3.new(130, 0, 26),
						pos = Vector3.new(0, 0.1, 0.04),
					},
					LeftShoulder = { rot = Vector3.new(-10, 0, -16) },
					RightHip = {
						rot = Vector3.new(-2.31, 11.92, 3.36),
						pos = Vector3.new(0, 0.13, 0),
					},
					LeftHip = {
						rot = Vector3.new(-14.5, 11.15, 4.62),
						pos = Vector3.new(0, 0.02, 0),
					},
				},
			},
			{
				time = 0.34,
				pose = {
					Root = { rot = Vector3.new(-3, 10, 2), pos = Vector3.new(0.01, -0.09, -0.03) },
					Neck = { rot = Vector3.new(-4, -4, -1) },
					RightShoulder = {
						rot = Vector3.new(101, 0, -62),
						pos = Vector3.new(0, 0.03, -0.02),
					},
					LeftShoulder = { rot = Vector3.new(-12, 0, -18) },
					RightHip = {
						rot = Vector3.new(-2.08, -9.93, -3.05),
						pos = Vector3.new(0, 0.1, 0),
					},
					LeftHip = { rot = Vector3.new(8, -10.18, -2.11), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.38,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-5, 13, 2), pos = Vector3.new(0, -0.11, -0.04) },
					Neck = { rot = Vector3.new(-6, -10, -2) },
					RightShoulder = {
						rot = Vector3.new(98, 0, -74),
						pos = Vector3.new(0, 0, -0.04),
					},
					LeftShoulder = { rot = Vector3.new(-13, 0, -19) },
					RightHip = {
						rot = Vector3.new(-1.17, -12.97, -2.31),
						pos = Vector3.new(0, 0.13, 0),
					},
					LeftHip = {
						rot = Vector3.new(12.02, -13.12, -0.75),
						pos = Vector3.new(0, 0.2, 0),
					},
				},
			},
			{
				time = 0.6,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(8, -14, -2), pos = Vector3.new(0.02, -0.05, 0.06) },
					Neck = { rot = Vector3.new(9, 9, 1) },
					RightShoulder = {
						rot = Vector3.new(138, 0, 30),
						pos = Vector3.new(0, 0.14, 0.06),
					},
					LeftShoulder = { rot = Vector3.new(-10, 0, -16) },
					RightHip = {
						rot = Vector3.new(-3.7, 13.86, 3.94),
						pos = Vector3.new(0, 0.16, 0),
					},
					LeftHip = {
						rot = Vector3.new(-18.03, 12.75, 5.65),
						pos = Vector3.new(0, 0.03, 0),
					},
				},
			},
			{
				time = 0.7,
				pose = {
					Root = { rot = Vector3.new(-5, 12, 2), pos = Vector3.new(0.01, -0.12, -0.03) },
					Neck = { rot = Vector3.new(-5, -5, -2) },
					RightShoulder = {
						rot = Vector3.new(101, 0, -63),
						pos = Vector3.new(0, 0.03, -0.02),
					},
					LeftShoulder = { rot = Vector3.new(-13, 0, -19) },
					RightHip = {
						rot = Vector3.new(-0.34, -12, -2.52),
						pos = Vector3.new(0, 0.14, 0),
					},
					LeftHip = {
						rot = Vector3.new(11.78, -12.15, -1.18),
						pos = Vector3.new(0, 0.21, 0),
					},
				},
			},
			{
				time = 0.73,
				tangent = "flat",
				pose = {
					Root = { rot = Vector3.new(-8, 16, 3), pos = Vector3.new(0, -0.16, -0.05) },
					Neck = { rot = Vector3.new(-8, -12, -3) },
					RightShoulder = {
						rot = Vector3.new(98, 0, -75),
						pos = Vector3.new(0, 0, -0.05),
					},
					LeftShoulder = { rot = Vector3.new(-14, 0, -20) },
					RightHip = {
						rot = Vector3.new(0.65, -16.05, -2.73),
						pos = Vector3.new(0, 0.18, 0),
					},
					LeftHip = {
						rot = Vector3.new(17.04, -16.16, -0.34),
						pos = Vector3.new(0, 0.26, 0),
					},
				},
			},
			{
				time = 0.88,
				pose = {
					Root = { rot = Vector3.new(10, 4, 2), pos = Vector3.new(0, -0.09, 0.12) },
					Neck = { rot = Vector3.new(8, -3, -1) },
					RightShoulder = {
						rot = Vector3.new(100, 0, -58),
						pos = Vector3.new(0, 0.04, -0.02),
					},
					LeftShoulder = { rot = Vector3.new(-8, 0, -14) },
					RightHip = {
						rot = Vector3.new(-13.3, -3.43, -3.72),
						pos = Vector3.new(0, 0.05, 0),
					},
					LeftHip = {
						rot = Vector3.new(-9.23, -3.63, -3.55),
						pos = Vector3.new(0, 0.15, 0),
					},
				},
			},
			{
				time = 1.1,
				pose = {
					Root = { rot = Vector3.new(-3, 2, 0), pos = Vector3.new(0, -0.05, -0.02) },
					Neck = { rot = Vector3.new(16, -2, 3) },
					RightShoulder = { rot = Vector3.new(30, 0, 42), pos = Vector3.new(0, 0.13, 0) },
					LeftShoulder = { rot = Vector3.new(28, 0, -40), pos = Vector3.new(0, 0.13, 0) },
					RightHip = { rot = Vector3.new(2.85, -2, 0.12), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = {
						rot = Vector3.new(4.83, -1.99, 0.15),
						pos = Vector3.new(0, 0.06, 0),
					},
				},
			},
			{
				time = 1.36,
				pose = {
					Root = { rot = Vector3.new(-4, 0, -2), pos = Vector3.new(0, -0.04, -0.03) },
					Neck = { rot = Vector3.new(21, 3, 9) },
					RightShoulder = { rot = Vector3.new(35, 0, 50), pos = Vector3.new(0, 0.17, 0) },
					LeftShoulder = { rot = Vector3.new(32, 0, -47), pos = Vector3.new(0, 0.16, 0) },
					RightHip = { rot = Vector3.new(5.01, 0.17, 2.91), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(5.05, 0.18, 2.97), pos = Vector3.new(0, 0.01, 0) },
				},
			},
			{
				time = 1.62,
				pose = {
					Root = { rot = Vector3.new(1, 1, 0), pos = Vector3.new(0, -0.09, 0.01) },
					Neck = { rot = Vector3.new(-10, 0, 2) },
					RightShoulder = { rot = Vector3.new(-7, 0, 5), pos = Vector3.new(0, -0.03, 0) },
					LeftShoulder = { rot = Vector3.new(-6, 0, -5), pos = Vector3.new(0, -0.03, 0) },
					RightHip = { rot = Vector3.new(-1.67, -1, -0.02), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-0.67, -1, -0.02), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 2,
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
	-- END emotes
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
