--!strict
-- Combat animations, made IN CODE (same system as MovementClips: read the
-- explanation at the top of that file).
--
-- Who plays them: CharacterAnimationController, on EVERY fighter (players
-- and training dummies), on every client.
--   • M1 / dashes: your own instantly (CombatController), the others when
--     the server tells everyone (Remotes.CombatAction).
--   • Block / Stunned: loops that follow the fighter's attributes.
--   • Reactions (hit, block hit, parry, guard break): Remotes.CombatEvent.
--
-- The punches were aimed with a solver so the fist reaches straight ahead
-- at shoulder height, and every pose was checked in a rig preview (feet on
-- the ground). Timing matters: the M1 impact keyframe is at 0.15 s, which
-- must stay equal to Config.Combat.HIT_DELAY.

local R6Pose = require(script.Parent.R6Pose)

local clips: { [string]: R6Pose.Clip } = {
	-- Left jab. Impact at 0.15 s = Config.Combat.HIT_DELAY (when the server checks the hitbox).
	Brawler_M1_1 = {
		length = 0.4,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(92, 0, -36) },
					LeftShoulder = { rot = Vector3.new(100, 0, 40) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.07,
				pose = {
					Root = { rot = Vector3.new(-6, -8, 0) },
					Neck = { rot = Vector3.new(4, 8, 0) },
					RightShoulder = { rot = Vector3.new(94, 0, -40) },
					LeftShoulder = { rot = Vector3.new(72, 0, 30) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(-12, -22, 0), pos = Vector3.new(0, -0.2, -0.45) },
					Neck = { rot = Vector3.new(8, 20, 0) },
					RightShoulder = { rot = Vector3.new(96, 0, -42) },
					LeftShoulder = { rot = Vector3.new(108.9, 0, 33.3) },
					RightHip = { rot = Vector3.new(-14, 0, 5), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(34, 0, -5), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = { rot = Vector3.new(-12, -22, 0), pos = Vector3.new(0, -0.2, -0.45) },
					Neck = { rot = Vector3.new(8, 20, 0) },
					RightShoulder = { rot = Vector3.new(96, 0, -42) },
					LeftShoulder = { rot = Vector3.new(108.9, 0, 33.3) },
					RightHip = { rot = Vector3.new(-14, 0, 5), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(34, 0, -5), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(92, 0, -36) },
					LeftShoulder = { rot = Vector3.new(100, 0, 40) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Right cross: hips and shoulders turn into the punch.
	Brawler_M1_2 = {
		length = 0.4,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(92, 0, -36) },
					LeftShoulder = { rot = Vector3.new(100, 0, 40) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.07,
				pose = {
					Root = { rot = Vector3.new(-8, -14, 0) },
					Neck = { rot = Vector3.new(6, 12, 0) },
					RightShoulder = { rot = Vector3.new(72, 0, -18) },
					LeftShoulder = { rot = Vector3.new(104, 0, 44) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(-16, 30, 0), pos = Vector3.new(0, -0.25, -0.45) },
					Neck = { rot = Vector3.new(10, -26, 0) },
					RightShoulder = { rot = Vector3.new(116.2, 0, -25.1) },
					LeftShoulder = { rot = Vector3.new(104, 0, 46) },
					RightHip = { rot = Vector3.new(-22, 0, 5), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(30, 0, -5), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = { rot = Vector3.new(-16, 30, 0), pos = Vector3.new(0, -0.25, -0.45) },
					Neck = { rot = Vector3.new(10, -26, 0) },
					RightShoulder = { rot = Vector3.new(116.2, 0, -25.1) },
					LeftShoulder = { rot = Vector3.new(104, 0, 46) },
					RightHip = { rot = Vector3.new(-22, 0, 5), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(30, 0, -5), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(92, 0, -36) },
					LeftShoulder = { rot = Vector3.new(100, 0, 40) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Left hook: the arm swings in from the side, the torso whips around.
	Brawler_M1_3 = {
		length = 0.4,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(92, 0, -36) },
					LeftShoulder = { rot = Vector3.new(100, 0, 40) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.07,
				pose = {
					Root = { rot = Vector3.new(-6, 12, -3) },
					Neck = { rot = Vector3.new(4, -10, 2) },
					RightShoulder = { rot = Vector3.new(96, 0, -42) },
					LeftShoulder = { rot = Vector3.new(86, 0, -38) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(-10, -36, 5), pos = Vector3.new(0, -0.2, -0.45) },
					Neck = { rot = Vector3.new(6, 30, -4) },
					RightShoulder = { rot = Vector3.new(96, 0, -42) },
					LeftShoulder = { rot = Vector3.new(112.1, 0, 36.4) },
					RightHip = { rot = Vector3.new(-18, 0, 5), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(26, 0, -5), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.24,
				pose = {
					Root = { rot = Vector3.new(-10, -36, 5), pos = Vector3.new(0, -0.2, -0.45) },
					Neck = { rot = Vector3.new(6, 30, -4) },
					RightShoulder = { rot = Vector3.new(96, 0, -42) },
					LeftShoulder = { rot = Vector3.new(112.1, 0, 36.4) },
					RightHip = { rot = Vector3.new(-18, 0, 5), pos = Vector3.new(0, 0.19, 0) },
					LeftHip = { rot = Vector3.new(26, 0, -5), pos = Vector3.new(0, 0.42, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(92, 0, -36) },
					LeftShoulder = { rot = Vector3.new(100, 0, 40) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Overhand (combo finisher): lean back, arm raised, then a lunging punch
	-- that drops on the opponent. Longer recovery (Config.Combat.FINISHER_RECOVERY).
	Brawler_M1_4 = {
		length = 0.7,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(92, 0, -36) },
					LeftShoulder = { rot = Vector3.new(100, 0, 40) },
					RightHip = { rot = Vector3.new(0, 0, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0) },
				},
			},
			{
				time = 0.09,
				pose = {
					Root = { rot = Vector3.new(8, -22, 0), pos = Vector3.new(0, -0.2, 0.2) },
					Neck = { rot = Vector3.new(-4, 18, 0) },
					RightShoulder = { rot = Vector3.new(165, 0, -15) },
					LeftShoulder = { rot = Vector3.new(85, 0, 32) },
					RightHip = { rot = Vector3.new(-22, 0, 5), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(22, 0, -5), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(-26, 32, 0), pos = Vector3.new(0, -0.45, -0.7) },
					Neck = { rot = Vector3.new(18, -26, 0) },
					RightShoulder = { rot = Vector3.new(127, 0, -26.5) },
					LeftShoulder = { rot = Vector3.new(35, 0, 30) },
					RightHip = { rot = Vector3.new(-20, 0, 5), pos = Vector3.new(0, 0.42, 0) },
					LeftHip = { rot = Vector3.new(48, 0, -5), pos = Vector3.new(0, 0.38, 0) },
				},
			},
			{
				time = 0.34,
				pose = {
					Root = { rot = Vector3.new(-26, 32, 0), pos = Vector3.new(0, -0.45, -0.7) },
					Neck = { rot = Vector3.new(18, -26, 0) },
					RightShoulder = { rot = Vector3.new(127, 0, -26.5) },
					LeftShoulder = { rot = Vector3.new(35, 0, 30) },
					RightHip = { rot = Vector3.new(-20, 0, 5), pos = Vector3.new(0, 0.42, 0) },
					LeftHip = { rot = Vector3.new(48, 0, -5), pos = Vector3.new(0, 0.38, 0) },
				},
			},
			{
				time = 0.7,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(92, 0, -36) },
					LeftShoulder = { rot = Vector3.new(100, 0, 40) },
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

	-- A hit lands on the guard: pushed back, guard holds.
	BlockHit = {
		length = 0.3,
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
				time = 0.06,
				pose = {
					Root = { rot = Vector3.new(2, 0, 0), pos = Vector3.new(0, 0, 0.35) },
					Neck = { rot = Vector3.new(2, 0, 0) },
					RightShoulder = { rot = Vector3.new(138, 0, -60.7) },
					LeftShoulder = { rot = Vector3.new(130.3, 0, 61) },
				},
			},
			{
				time = 0.3,
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

	-- Hit from the front: head and torso snap back.
	HitFront = {
		length = 0.42,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(16, 0, -4), pos = Vector3.new(0, 0, 0.3) },
					Neck = { rot = Vector3.new(24, 0, 0) },
					RightShoulder = { rot = Vector3.new(28, 0, 18) },
					LeftShoulder = { rot = Vector3.new(22, 0, -18) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = { rot = Vector3.new(16, 0, -4), pos = Vector3.new(0, 0, 0.3) },
					Neck = { rot = Vector3.new(24, 0, 0) },
					RightShoulder = { rot = Vector3.new(28, 0, 18) },
					LeftShoulder = { rot = Vector3.new(22, 0, -18) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 0) },
					LeftShoulder = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Hit from behind: thrown forward.
	HitBack = {
		length = 0.42,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-18, 0, 3), pos = Vector3.new(0, 0, -0.3) },
					Neck = { rot = Vector3.new(-20, 0, 0) },
					RightShoulder = { rot = Vector3.new(-24, 0, 10) },
					LeftShoulder = { rot = Vector3.new(-20, 0, -10) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = { rot = Vector3.new(-18, 0, 3), pos = Vector3.new(0, 0, -0.3) },
					Neck = { rot = Vector3.new(-20, 0, 0) },
					RightShoulder = { rot = Vector3.new(-24, 0, 10) },
					LeftShoulder = { rot = Vector3.new(-20, 0, -10) },
				},
			},
			{
				time = 0.42,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 0) },
					LeftShoulder = { rot = Vector3.new(0, 0, 0) },
				},
			},
		},
	},

	-- Dash forward: low, leaning in, arms back. Length = Config.Combat.DASH_TIME + recovery.
	DashForward = {
		length = 0.38,
		looped = false,
		keyframes = {
			{
				time = 0,
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
				time = 0.38,
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

	-- Dash back: leaning away, guard up. Length = Config.Combat.DASH_TIME + recovery.
	DashBack = {
		length = 0.38,
		looped = false,
		keyframes = {
			{
				time = 0,
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
				time = 0.38,
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

	-- Side dash: body leans into the direction, legs apart. Length = Config.Combat.DASH_TIME + recovery.
	DashLeft = {
		length = 0.38,
		looped = false,
		keyframes = {
			{
				time = 0,
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
				time = 0.38,
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

	-- Side dash (mirror of DashLeft). Length = Config.Combat.DASH_TIME + recovery.
	DashRight = {
		length = 0.38,
		looped = false,
		keyframes = {
			{
				time = 0,
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
				time = 0.38,
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

return table.freeze(clips)
