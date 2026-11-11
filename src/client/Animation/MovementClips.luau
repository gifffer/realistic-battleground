--!strict
-- Movement animations, made IN CODE (no Animation Editor, nothing to publish).
--
-- Each clip is a list of keyframes. A keyframe gives, for some joints, a
-- rotation (degrees) and optionally a position offset (studs), both in the
-- PARENT part's space (Root = relative to HumanoidRootPart, the others =
-- relative to the Torso):
--   • rot.X > 0 swings an arm / leg FORWARD, and tilts the torso / head BACK.
--   • rot.Y turns left/right, rot.Z tilts sideways.
--   • Root.pos moves the whole body (e.g. Y = -0.6 → 0.6 stud lower).
--   • pos on a leg slides it up into the torso: that's how we fake a bent
--     knee on R6 (which has no knees).
-- Joints not listed in a clip keep Roblox's own animation (walk, idle...).
--
-- The poses were checked with a side/front preview of the R6 rig: feet stay
-- on the ground, nothing sinks into it. To tweak one: change the numbers,
-- Rojo syncs, press Play.

local R6Pose = require(script.Parent.R6Pose)

local clips: { [string]: R6Pose.Clip } = {
	-- Tactical crouch: torso leaning forward, knees bent (legs pushed up into the
	-- torso: R6 has no knees), left foot ahead, guard up. Slow breathing.
	CrouchIdle = {
		length = 2.4,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-24, 0, 0), pos = Vector3.new(0, -0.95, 0) },
					Neck = { rot = Vector3.new(20.4, 0, 0) },
					RightShoulder = { rot = Vector3.new(52, 0, -25) },
					LeftShoulder = { rot = Vector3.new(60, 0, 28) },
					RightHip = { rot = Vector3.new(10, 0, 6), pos = Vector3.new(0, 1.11, 0) },
					LeftHip = { rot = Vector3.new(42, 0, -6), pos = Vector3.new(0, 1.1, 0) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = { rot = Vector3.new(-22, 0, 0), pos = Vector3.new(0, -0.9, 0) },
					Neck = { rot = Vector3.new(19, 0, 0) },
					RightShoulder = { rot = Vector3.new(55, 0, -24) },
					LeftShoulder = { rot = Vector3.new(63, 0, 27) },
					RightHip = { rot = Vector3.new(10, 0, 6), pos = Vector3.new(0, 1.06, 0) },
					LeftHip = { rot = Vector3.new(42, 0, -6), pos = Vector3.new(0, 1.04, 0) },
				},
			},
		},
	},

	-- Tactical crouched walk: legs alternate, the swinging foot lifts off the
	-- ground, torso steady and leaning forward, slight shoulder turn.
	-- Length = one full cycle (2 steps) at Config.Character.CROUCH_SPEED;
	-- it plays faster / slower with the real speed.
	CrouchWalk = {
		length = 0.8,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-24, -4, 0), pos = Vector3.new(0, -0.9, 0) },
					Neck = { rot = Vector3.new(20.4, 4, 0) },
					RightShoulder = { rot = Vector3.new(54, 0, -25) },
					LeftShoulder = { rot = Vector3.new(56, 0, 28) },
					RightHip = { rot = Vector3.new(2, 0, 6), pos = Vector3.new(0, 1.02, 0) },
					LeftHip = { rot = Vector3.new(56, 0, -6), pos = Vector3.new(0, 0.94, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-24, 0, 0), pos = Vector3.new(0, -0.82, 0) },
					Neck = { rot = Vector3.new(20.4, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, -25) },
					LeftShoulder = { rot = Vector3.new(60, 0, 28) },
					RightHip = { rot = Vector3.new(34, 0, 6), pos = Vector3.new(0, 1.41, 0) },
					LeftHip = { rot = Vector3.new(28, 0, -6), pos = Vector3.new(0, 0.94, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = { rot = Vector3.new(-24, 4, 0), pos = Vector3.new(0, -0.9, 0) },
					Neck = { rot = Vector3.new(20.4, -4, 0) },
					RightShoulder = { rot = Vector3.new(46, 0, -25) },
					LeftShoulder = { rot = Vector3.new(64, 0, 28) },
					RightHip = { rot = Vector3.new(56, 0, 6), pos = Vector3.new(0, 0.94, 0) },
					LeftHip = { rot = Vector3.new(2, 0, -6), pos = Vector3.new(0, 1.02, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = { rot = Vector3.new(-24, 0, 0), pos = Vector3.new(0, -0.82, 0) },
					Neck = { rot = Vector3.new(20.4, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, -25) },
					LeftShoulder = { rot = Vector3.new(60, 0, 28) },
					RightHip = { rot = Vector3.new(28, 0, 6), pos = Vector3.new(0, 0.94, 0) },
					LeftHip = { rot = Vector3.new(34, 0, -6), pos = Vector3.new(0, 1.41, 0) },
				},
			},
		},
	},

	-- Baseball slide: torso leaning back and turned, right leg straight ahead on
	-- the ground, left knee up, left hand planted behind, right arm forward.
	Slide = {
		length = 0.5,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(35, 22, -6), pos = Vector3.new(0, -1.72, 0) },
					Neck = { rot = Vector3.new(-24.5, -17.6, 0) },
					RightShoulder = { rot = Vector3.new(70, 0, -15) },
					LeftShoulder = { rot = Vector3.new(-65.5, 0, -28) },
					RightHip = { rot = Vector3.new(57, 0, 6), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(-10, 0, -10), pos = Vector3.new(0, 1.53, -0.9) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = { rot = Vector3.new(32, 20, -5), pos = Vector3.new(0, -1.68, 0) },
					Neck = { rot = Vector3.new(-22.4, -16, 0) },
					RightShoulder = { rot = Vector3.new(76, 0, -15) },
					LeftShoulder = { rot = Vector3.new(-64.6, 0, -28) },
					RightHip = { rot = Vector3.new(60, 0, 6), pos = Vector3.new(0, 0.04, 0) },
					LeftHip = { rot = Vector3.new(-7, 0, -10), pos = Vector3.new(0, 1.49, -0.9) },
				},
			},
		},
	},

	-- Mantle (high ledge). Times are 0 → 1: the clip is stretched to the real
	-- duration of the climb. Must match the phases in ParkourController:
	-- 0 reach → 0.22 catch the ledge and hang → 0.36 legs swing → 0.62 pulled up,
	-- knee on the ledge → 0.82 step up → 1 standing.
	Climb = {
		length = 1,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(20, 0, 0) },
					RightShoulder = { rot = Vector3.new(142, 0, -6) },
					LeftShoulder = { rot = Vector3.new(142, 0, 6) },
					RightHip = { rot = Vector3.new(10, 0, 0) },
					LeftHip = { rot = Vector3.new(-8, 0, 0) },
				},
			},
			{
				time = 0.22,
				pose = {
					Root = { rot = Vector3.new(5, 0, 0) },
					Neck = { rot = Vector3.new(26, 0, 0) },
					RightShoulder = { rot = Vector3.new(138, 0, -4) },
					LeftShoulder = { rot = Vector3.new(138, 0, 4) },
					RightHip = { rot = Vector3.new(-16, 0, 3) },
					LeftHip = { rot = Vector3.new(-10, 0, -3) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = { rot = Vector3.new(-5, 0, 0) },
					Neck = { rot = Vector3.new(22, 0, 0) },
					RightShoulder = { rot = Vector3.new(136, 0, -4) },
					LeftShoulder = { rot = Vector3.new(136, 0, 4) },
					RightHip = { rot = Vector3.new(16, 0, 3) },
					LeftHip = { rot = Vector3.new(8, 0, -3) },
				},
			},
			{
				time = 0.62,
				pose = {
					Root = { rot = Vector3.new(-22, 0, 0) },
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(64, 0, 6) },
					LeftShoulder = { rot = Vector3.new(64, 0, -6) },
					RightHip = { rot = Vector3.new(84, 0, 4), pos = Vector3.new(0, 0.5, -0.3) },
					LeftHip = { rot = Vector3.new(-8, 0, 0) },
				},
			},
			{
				time = 0.82,
				pose = {
					Root = { rot = Vector3.new(-32, 0, 0) },
					Neck = { rot = Vector3.new(20, 0, 0) },
					RightShoulder = { rot = Vector3.new(28, 0, -8) },
					LeftShoulder = { rot = Vector3.new(34, 0, 8) },
					RightHip = { rot = Vector3.new(58, 0, 4), pos = Vector3.new(0, 0.3, -0.2) },
					LeftHip = { rot = Vector3.new(28, 0, -4), pos = Vector3.new(0, 0.4, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = { rot = Vector3.new(-5, 0, 0) },
					Neck = { rot = Vector3.new(3, 0, 0) },
					RightShoulder = { rot = Vector3.new(6, 0, 0) },
					LeftShoulder = { rot = Vector3.new(6, 0, 0) },
					RightHip = { rot = Vector3.new(3, 0, 0) },
					LeftHip = { rot = Vector3.new(-3, 0, 0) },
				},
			},
		},
	},

	-- Vault (low obstacle), times 0 → 1: left hand planted on top, body rolls
	-- over it with both legs swung to the right, lands running.
	Vault = {
		length = 1,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-15, 0, 0) },
					Neck = { rot = Vector3.new(10, 0, 0) },
					RightShoulder = { rot = Vector3.new(-25, 0, 8) },
					LeftShoulder = { rot = Vector3.new(78, 0, 10) },
					RightHip = { rot = Vector3.new(32, 0, 0) },
					LeftHip = { rot = Vector3.new(-25, 0, 0) },
				},
			},
			{
				time = 0.38,
				pose = {
					Root = { rot = Vector3.new(-18, 18, 30) },
					Neck = { rot = Vector3.new(10, -14, -20) },
					RightShoulder = { rot = Vector3.new(25, 0, 62) },
					LeftShoulder = { rot = Vector3.new(20, 0, -22) },
					RightHip = { rot = Vector3.new(78, 0, 34), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(62, 0, 22), pos = Vector3.new(0, 0.3, 0) },
				},
			},
			{
				time = 0.72,
				pose = {
					Root = { rot = Vector3.new(-12, 8, 10) },
					Neck = { rot = Vector3.new(8, -6, -8) },
					RightShoulder = { rot = Vector3.new(42, 0, 14) },
					LeftShoulder = { rot = Vector3.new(-28, 0, -10) },
					RightHip = { rot = Vector3.new(48, 0, 8) },
					LeftHip = { rot = Vector3.new(12, 0, 4) },
				},
			},
			{
				time = 1,
				pose = {
					Root = { rot = Vector3.new(-10, 0, 0) },
					Neck = { rot = Vector3.new(6, 0, 0) },
					RightShoulder = { rot = Vector3.new(-20, 0, 0) },
					LeftShoulder = { rot = Vector3.new(30, 0, 0) },
					RightHip = { rot = Vector3.new(-16, 0, 0) },
					LeftHip = { rot = Vector3.new(22, 0, 0) },
				},
			},
		},
	},

	-- ADDED on top of Roblox's run animation: lean into the sprint.
	-- Its weight follows the speed (see CharacterAnimationController).
	SprintLean = {
		length = 1,
		looped = true,
		additive = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-11, 0, 0) },
					Neck = { rot = Vector3.new(7, 0, 0) },
				},
			},
		},
	},
	-- BEGIN injuries (generated by add_injury_clips.py)
	-- LIMPING WALK (legs injured): short, quick step on the hurt right leg, the body
	-- drops and tilts away from it; long step on the good left leg. Authored for 12
	-- studs/s (the game scales it with the real speed).
	LimpWalk = {
		length = 1.1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-7, 2.5, -2), pos = Vector3.new(-0.12, -0.01, 0) },
					Neck = { rot = Vector3.new(4.85, -1.75, 1.1) },
					RightShoulder = { rot = Vector3.new(4.5, 0, 7.5) },
					LeftShoulder = { rot = Vector3.new(-17, 0, -3) },
					RightHip = { rot = Vector3.new(-3, 0, 13), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(17.52, 0, 6.97), pos = Vector3.new(0, -0.01, 0) },
				},
			},
			{
				time = 0.1,
				pose = {
					Root = { rot = Vector3.new(-6, 1, -3), pos = Vector3.new(-0.12, 0.03, 0) },
					Neck = { rot = Vector3.new(3.3, -0.7, 1.65) },
					RightShoulder = { rot = Vector3.new(0, 0, 7) },
					LeftShoulder = { rot = Vector3.new(-4, 0, -3) },
					RightHip = { rot = Vector3.new(8, 0, 15), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(7.3, 0, 7.6), pos = Vector3.new(0, -0.09, 0) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(-6, -3, -1), pos = Vector3.new(-0.03, -0.03, 0) },
					Neck = { rot = Vector3.new(4.3, 2.1, 0.55) },
					RightShoulder = { rot = Vector3.new(-8, 0, 7) },
					LeftShoulder = { rot = Vector3.new(22, 0, -4) },
					RightHip = { rot = Vector3.new(20, 0, 7), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(-10.03, 0, 2.23), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 0.41,
				pose = {
					Root = {
						rot = Vector3.new(-6.68, -4.36, 0.36),
						pos = Vector3.new(0.02, -0.05, 0),
					},
					Neck = { rot = Vector3.new(4.67, 3.05, -0.2) },
					RightShoulder = { rot = Vector3.new(-9.36, 0, 8.36) },
					LeftShoulder = { rot = Vector3.new(27.43, 0, -4) },
					RightHip = { rot = Vector3.new(32.46, 0, -1.54), pos = Vector3.new(0, 0.11, 0) },
					LeftHip = { rot = Vector3.new(-18.02, 0, -0.27), pos = Vector3.new(0, 0.09, 0) },
				},
			},
			{
				time = 0.46,
				pose = {
					Root = { rot = Vector3.new(-7, -5, 1), pos = Vector3.new(0.04, -0.06, 0) },
					Neck = { rot = Vector3.new(4.85, 3.5, -0.55) },
					RightShoulder = { rot = Vector3.new(-10, 0, 9) },
					LeftShoulder = { rot = Vector3.new(30, 0, -4) },
					RightHip = { rot = Vector3.new(28.88, 0, -3.1), pos = Vector3.new(0, 0.07, 0) },
					LeftHip = { rot = Vector3.new(-21.87, 0, -1.3), pos = Vector3.new(0, 0.07, 0) },
				},
			},
			{
				time = 0.59,
				pose = {
					Root = { rot = Vector3.new(-16, -2, 13), pos = Vector3.new(-0.06, -0.4, -0.04) },
					Neck = { rot = Vector3.new(0.8, 1.4, -9.15) },
					RightShoulder = { rot = Vector3.new(-2, 0, 24) },
					LeftShoulder = { rot = Vector3.new(16, 0, -6) },
					RightHip = {
						rot = Vector3.new(28.77, 0, -13.52),
						pos = Vector3.new(0, 0.18, 0),
					},
					LeftHip = { rot = Vector3.new(8, 0, -11), pos = Vector3.new(0, 1.05, 0) },
				},
			},
			{
				time = 0.78,
				pose = {
					Root = {
						rot = Vector3.new(-11.36, 2.64, 6.04),
						pos = Vector3.new(-0.07, -0.21, -0.01),
					},
					Neck = { rot = Vector3.new(2.89, -1.84, -3.78) },
					RightShoulder = { rot = Vector3.new(7.27, 0, 14.73) },
					LeftShoulder = { rot = Vector3.new(-18, 0, -5.23) },
					RightHip = { rot = Vector3.new(6.15, 0, -4.21), pos = Vector3.new(0, 0.16, 0) },
					LeftHip = { rot = Vector3.new(50.89, 0, -2.84), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.83,
				pose = {
					Root = { rot = Vector3.new(-10, 4, 4), pos = Vector3.new(-0.08, -0.16, 0) },
					Neck = { rot = Vector3.new(3.5, -2.8, -2.2) },
					RightShoulder = { rot = Vector3.new(10, 0, 12) },
					LeftShoulder = { rot = Vector3.new(-28, 0, -5) },
					RightHip = { rot = Vector3.new(-0.2, 0, -1.56), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(44.49, 0, -0.13), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 1,
				pose = {
					Root = { rot = Vector3.new(-8, 4, -1), pos = Vector3.new(-0.13, -0.05, 0) },
					Neck = { rot = Vector3.new(6.4, -2.8, 0.55) },
					RightShoulder = { rot = Vector3.new(9, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-30, 0, -3) },
					RightHip = { rot = Vector3.new(-14, 0, 11), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(27.74, 0, 6.35), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 1.1,
				pose = {
					Root = { rot = Vector3.new(-7, 2.5, -2), pos = Vector3.new(-0.12, -0.01, 0) },
					Neck = { rot = Vector3.new(4.85, -1.75, 1.1) },
					RightShoulder = { rot = Vector3.new(4.5, 0, 7.5) },
					LeftShoulder = { rot = Vector3.new(-17, 0, -3) },
					RightHip = { rot = Vector3.new(-3, 0, 13), pos = Vector3.new(0, 0.4, 0) },
					LeftHip = { rot = Vector3.new(17.52, 0, 6.97), pos = Vector3.new(0, -0.01, 0) },
				},
			},
		},
	},
	-- LIMPING, STANDING: weight on the good left leg, right foot barely touching.
	LimpIdle = {
		length = 2.4,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = {
						rot = Vector3.new(-14.15, 7, 9.88),
						pos = Vector3.new(-0.43, -0.18, -0.01),
					},
					Neck = { rot = Vector3.new(-7.6, -5, -6.6) },
					RightShoulder = {
						rot = Vector3.new(19.39, 0, -9.28),
						pos = Vector3.new(0, 0.03, 0),
					},
					LeftShoulder = {
						rot = Vector3.new(7.6, 0, -12.3),
						pos = Vector3.new(0, 0.03, 0),
					},
					RightHip = {
						rot = Vector3.new(29.47, -17, 5.46),
						pos = Vector3.new(0, 0.27, 0),
					},
					LeftHip = { rot = Vector3.new(16.41, -3, -7.13), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.4,
				pose = {
					Root = {
						rot = Vector3.new(-11.8, 7.6, 9.62),
						pos = Vector3.new(-0.42, -0.14, -0.03),
					},
					Neck = { rot = Vector3.new(-7.7, -5.36, -6.2) },
					RightShoulder = {
						rot = Vector3.new(17.7, 0, -9.8),
						pos = Vector3.new(0, 0.05, 0),
					},
					LeftShoulder = {
						rot = Vector3.new(8.2, 0, -12.6),
						pos = Vector3.new(0, 0.05, 0),
					},
					RightHip = { rot = Vector3.new(25.67, -17.6, 5), pos = Vector3.new(0, 0.23, 0) },
					LeftHip = {
						rot = Vector3.new(13.13, -3.6, -7.57),
						pos = Vector3.new(0, 0.26, 0),
					},
				},
			},
			{
				time = 0.95,
				pose = {
					Root = {
						rot = Vector3.new(-14.82, 6.2, 9.5),
						pos = Vector3.new(-0.42, -0.2, 0),
					},
					Neck = { rot = Vector3.new(-4.15, -4.52, -6) },
					RightShoulder = {
						rot = Vector3.new(20.5, 0, -9.19),
						pos = Vector3.new(0, 0, 0),
					},
					LeftShoulder = { rot = Vector3.new(6.1, 0, -9.15), pos = Vector3.new(0, 0, 0) },
					RightHip = {
						rot = Vector3.new(31.19, -16.2, 5.58),
						pos = Vector3.new(0, 0.28, 0),
					},
					LeftHip = {
						rot = Vector3.new(17.3, -2.2, -6.84),
						pos = Vector3.new(0, 0.32, 0),
					},
				},
			},
			{
				time = 1.25,
				pose = {
					Root = {
						rot = Vector3.new(-11.27, 5.65, 6.12),
						pos = Vector3.new(-0.27, -0.15, -0.02),
					},
					Neck = { rot = Vector3.new(-3.4, -3.65, -3.75) },
					RightShoulder = {
						rot = Vector3.new(18.84, 0, -10.52),
						pos = Vector3.new(0, 0.03, 0),
					},
					LeftShoulder = {
						rot = Vector3.new(5.3, 0, -8.4),
						pos = Vector3.new(0, 0.03, 0),
					},
					RightHip = {
						rot = Vector3.new(27.41, -15.65, 4),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = {
						rot = Vector3.new(12.48, -1.65, -7.57),
						pos = Vector3.new(0, 0.27, 0),
					},
				},
			},
			{
				time = 1.5,
				pose = {
					Root = {
						rot = Vector3.new(-8.03, 4.4, 2),
						pos = Vector3.new(-0.08, -0.11, -0.03),
					},
					Neck = { rot = Vector3.new(-1.55, -2.24, -1) },
					RightShoulder = {
						rot = Vector3.new(17.58, 0, -11.7),
						pos = Vector3.new(0, 0.04, 0),
					},
					LeftShoulder = {
						rot = Vector3.new(3.7, 0, -6.55),
						pos = Vector3.new(0, 0.04, 0),
					},
					RightHip = {
						rot = Vector3.new(24.25, -14.4, 2.78),
						pos = Vector3.new(0, 0.14, 0),
					},
					LeftHip = {
						rot = Vector3.new(7.74, -0.4, -7.89),
						pos = Vector3.new(0, 0.23, 0),
					},
				},
			},
			{
				time = 1.62,
				pose = {
					Root = {
						rot = Vector3.new(-12.48, 4.9, 4.88),
						pos = Vector3.new(-0.18, -0.18, -0.01),
					},
					Neck = { rot = Vector3.new(-9.95, -2.78, -4.2) },
					RightShoulder = {
						rot = Vector3.new(19.48, 0, -10.93),
						pos = Vector3.new(0, 0.04, 0),
					},
					LeftShoulder = {
						rot = Vector3.new(6.5, 0, -13.85),
						pos = Vector3.new(0, 0.04, 0),
					},
					RightHip = {
						rot = Vector3.new(30.01, -14.9, 2.83),
						pos = Vector3.new(0, 0.21, 0),
					},
					LeftHip = {
						rot = Vector3.new(14.06, -0.9, -8.32),
						pos = Vector3.new(0, 0.31, 0),
					},
				},
			},
			{
				time = 1.8,
				pose = {
					Root = {
						rot = Vector3.new(-20.78, 7.36, 12.9),
						pos = Vector3.new(-0.51, -0.29, 0.02),
					},
					Neck = { rot = Vector3.new(-19.2, -5.36, -10.6) },
					RightShoulder = {
						rot = Vector3.new(21.69, 0, -7.27),
						pos = Vector3.new(0, 0.01, 0),
					},
					LeftShoulder = {
						rot = Vector3.new(10.88, 0, -22.2),
						pos = Vector3.new(0, 0.01, 0),
					},
					RightHip = {
						rot = Vector3.new(37.14, -17.36, 7.1),
						pos = Vector3.new(0, 0.37, 0),
					},
					LeftHip = {
						rot = Vector3.new(24.99, -3.36, -6.21),
						pos = Vector3.new(0, 0.44, 0),
					},
				},
			},
			{
				time = 2,
				pose = {
					Root = {
						rot = Vector3.new(-16.5, 6.4, 10.12),
						pos = Vector3.new(-0.43, -0.23, 0.01),
					},
					Neck = { rot = Vector3.new(-7.5, -4.64, -7) },
					RightShoulder = { rot = Vector3.new(21.08, 0, -8.76) },
					LeftShoulder = { rot = Vector3.new(7, 0, -12) },
					RightHip = {
						rot = Vector3.new(33.27, -16.4, 5.92),
						pos = Vector3.new(0, 0.31, 0),
					},
					LeftHip = {
						rot = Vector3.new(19.69, -2.4, -6.69),
						pos = Vector3.new(0, 0.36, 0),
					},
				},
			},
			{
				time = 2.4,
				pose = {
					Root = {
						rot = Vector3.new(-14.15, 7, 9.88),
						pos = Vector3.new(-0.43, -0.18, -0.01),
					},
					Neck = { rot = Vector3.new(-7.6, -5, -6.6) },
					RightShoulder = {
						rot = Vector3.new(19.39, 0, -9.28),
						pos = Vector3.new(0, 0.03, 0),
					},
					LeftShoulder = {
						rot = Vector3.new(7.6, 0, -12.3),
						pos = Vector3.new(0, 0.03, 0),
					},
					RightHip = {
						rot = Vector3.new(29.47, -17, 5.46),
						pos = Vector3.new(0, 0.27, 0),
					},
					LeftHip = { rot = Vector3.new(16.41, -3, -7.13), pos = Vector3.new(0, 0.31, 0) },
				},
			},
		},
	},
	-- END injuries
}

return table.freeze(clips)
