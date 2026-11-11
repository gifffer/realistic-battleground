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

	-- Walk (replaces Roblox's). The 4 main frames of a walk, for each step:
	--   CONTACT  legs apart, both feet on the ground;
	--   DOWN     the torso's weight pushes the legs down (lowest point);
	--   PASS     the free leg passes under the body, foot lifted;
	--   UP       the body rises, the supporting leg is straight (highest point).
	-- Then the same for the other leg. The up/down gives the head its wave. Arms
	-- hang and swing opposite to the legs, the shoulders turn with them. R6 legs
	-- have no knee: the leg mostly rotates; a small shortening fakes the bend
	-- under the weight and lifts the passing foot. Feet computed on the ground.
	Walk = {
		length = 1.0,
		looped = true,
		keyframes = {
			{
				time = 0, -- right leg: CONTACT (front, heel down)
				pose = {
					Root = { rot = Vector3.new(-3, -4, 0), pos = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(2, 3.2, 0) },
					RightShoulder = { rot = Vector3.new(-18, 0, 4) },
					LeftShoulder = { rot = Vector3.new(26, 0, -4) },
					RightHip = { rot = Vector3.new(27, 0, 0) },
					LeftHip = { rot = Vector3.new(-21, 0, 0) },
				},
			},
			{
				time = 0.0625,
				pose = {
					Root = { rot = Vector3.new(-3, -3.7, -0.77), pos = Vector3.new(0, -0.07, 0) },
					Neck = { rot = Vector3.new(2, 2.96, 0.54) },
					RightShoulder = { rot = Vector3.new(-16.33, 0, 4) },
					LeftShoulder = { rot = Vector3.new(24.33, 0, -4) },
					RightHip = { rot = Vector3.new(19.5, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-18, 0, 0), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.125, -- right leg: DOWN (the torso's weight bends it)
				pose = {
					Root = { rot = Vector3.new(-3, -2.83, -1.41), pos = Vector3.new(0, -0.14, 0) },
					Neck = { rot = Vector3.new(2, 2.26, 0.99) },
					RightShoulder = { rot = Vector3.new(-11.56, 0, 4) },
					LeftShoulder = { rot = Vector3.new(19.56, 0, -4) },
					RightHip = { rot = Vector3.new(12, 0, 0), pos = Vector3.new(0, 0.18, 0) },
					LeftHip = { rot = Vector3.new(-15, 0, 0), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.1875,
				pose = {
					Root = { rot = Vector3.new(-3, -1.53, -1.85), pos = Vector3.new(0, -0.1, 0) },
					Neck = { rot = Vector3.new(2, 1.22, 1.29) },
					RightShoulder = { rot = Vector3.new(-4.42, 0, 4) },
					LeftShoulder = { rot = Vector3.new(12.42, 0, -4) },
					RightHip = { rot = Vector3.new(7.5, 0, 0), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.25, -- right leg: PASS (under the body)
				pose = {
					Root = { rot = Vector3.new(-3, 0, -2), pos = Vector3.new(0, -0.06, 0) },
					Neck = { rot = Vector3.new(2, 0, 1.4) },
					RightShoulder = { rot = Vector3.new(4, 0, 4) },
					LeftShoulder = { rot = Vector3.new(4, 0, -4) },
					RightHip = { rot = Vector3.new(3, 0, 0), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(-1, 0, 0), pos = Vector3.new(0, 0.34, 0) },
				},
			},
			{
				time = 0.3125,
				pose = {
					Root = { rot = Vector3.new(-3, 1.53, -1.85), pos = Vector3.new(0, -0.01, 0) },
					Neck = { rot = Vector3.new(2, -1.22, 1.29) },
					RightShoulder = { rot = Vector3.new(12.42, 0, 4) },
					LeftShoulder = { rot = Vector3.new(-4.42, 0, -4) },
					RightHip = { rot = Vector3.new(-1, 0, 0), pos = Vector3.new(0, 0.04, 0) },
					LeftHip = { rot = Vector3.new(9, 0, 0), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.375, -- right leg: UP (straight, pushing up)
				pose = {
					Root = { rot = Vector3.new(-3, 2.83, -1.41), pos = Vector3.new(0, 0.04, 0) },
					Neck = { rot = Vector3.new(2, -2.26, 0.99) },
					RightShoulder = { rot = Vector3.new(19.56, 0, 4) },
					LeftShoulder = { rot = Vector3.new(-11.56, 0, -4) },
					RightHip = { rot = Vector3.new(-5, 0, 0) },
					LeftHip = { rot = Vector3.new(19, 0, 0), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.4375,
				pose = {
					Root = { rot = Vector3.new(-3, 3.7, -0.77), pos = Vector3.new(0, 0.02, 0) },
					Neck = { rot = Vector3.new(2, -2.96, 0.54) },
					RightShoulder = { rot = Vector3.new(24.33, 0, 4) },
					LeftShoulder = { rot = Vector3.new(-16.33, 0, -4) },
					RightHip = { rot = Vector3.new(-13, 0, 0), pos = Vector3.new(0, 0.02, 0) },
					LeftHip = { rot = Vector3.new(23, 0, 0), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.5, -- right leg: CONTACT (behind, other heel lands)
				pose = {
					Root = { rot = Vector3.new(-3, 4, 0), pos = Vector3.new(0, 0, 0) },
					Neck = { rot = Vector3.new(2, -3.2, 0) },
					RightShoulder = { rot = Vector3.new(26, 0, 4) },
					LeftShoulder = { rot = Vector3.new(-18, 0, -4) },
					RightHip = { rot = Vector3.new(-21, 0, 0) },
					LeftHip = { rot = Vector3.new(27, 0, 0) },
				},
			},
			{
				time = 0.5625,
				pose = {
					Root = { rot = Vector3.new(-3, 3.7, 0.77), pos = Vector3.new(0, -0.07, 0) },
					Neck = { rot = Vector3.new(2, -2.96, -0.54) },
					RightShoulder = { rot = Vector3.new(24.33, 0, 4) },
					LeftShoulder = { rot = Vector3.new(-16.33, 0, -4) },
					RightHip = { rot = Vector3.new(-18, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(19.5, 0, 0), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.625, -- right leg: DOWN (heel leaves the ground)
				pose = {
					Root = { rot = Vector3.new(-3, 2.83, 1.41), pos = Vector3.new(0, -0.14, 0) },
					Neck = { rot = Vector3.new(2, -2.26, -0.99) },
					RightShoulder = { rot = Vector3.new(19.56, 0, 4) },
					LeftShoulder = { rot = Vector3.new(-11.56, 0, -4) },
					RightHip = { rot = Vector3.new(-15, 0, 0), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(12, 0, 0), pos = Vector3.new(0, 0.18, 0) },
				},
			},
			{
				time = 0.6875,
				pose = {
					Root = { rot = Vector3.new(-3, 1.53, 1.85), pos = Vector3.new(0, -0.1, 0) },
					Neck = { rot = Vector3.new(2, -1.22, -1.29) },
					RightShoulder = { rot = Vector3.new(12.42, 0, 4) },
					LeftShoulder = { rot = Vector3.new(-4.42, 0, -4) },
					RightHip = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(7.5, 0, 0), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.75, -- right leg: PASS (swinging under the body, lifted)
				pose = {
					Root = { rot = Vector3.new(-3, 0, 2), pos = Vector3.new(0, -0.06, 0) },
					Neck = { rot = Vector3.new(2, 0, -1.4) },
					RightShoulder = { rot = Vector3.new(4, 0, 4) },
					LeftShoulder = { rot = Vector3.new(4, 0, -4) },
					RightHip = { rot = Vector3.new(-1, 0, 0), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(3, 0, 0), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 0.8125,
				pose = {
					Root = { rot = Vector3.new(-3, -1.53, 1.85), pos = Vector3.new(0, -0.01, 0) },
					Neck = { rot = Vector3.new(2, 1.22, -1.29) },
					RightShoulder = { rot = Vector3.new(-4.42, 0, 4) },
					LeftShoulder = { rot = Vector3.new(12.42, 0, -4) },
					RightHip = { rot = Vector3.new(9, 0, 0), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-1, 0, 0), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.875, -- right leg: UP (reaching forward)
				pose = {
					Root = { rot = Vector3.new(-3, -2.83, 1.41), pos = Vector3.new(0, 0.04, 0) },
					Neck = { rot = Vector3.new(2, 2.26, -0.99) },
					RightShoulder = { rot = Vector3.new(-11.56, 0, 4) },
					LeftShoulder = { rot = Vector3.new(19.56, 0, -4) },
					RightHip = { rot = Vector3.new(19, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(-5, 0, 0) },
				},
			},
			{
				time = 0.9375,
				pose = {
					Root = { rot = Vector3.new(-3, -3.7, 0.77), pos = Vector3.new(0, 0.02, 0) },
					Neck = { rot = Vector3.new(2, 2.96, -0.54) },
					RightShoulder = { rot = Vector3.new(-16.33, 0, 4) },
					LeftShoulder = { rot = Vector3.new(24.33, 0, -4) },
					RightHip = { rot = Vector3.new(23, 0, 0), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(-13, 0, 0), pos = Vector3.new(0, 0.02, 0) },
				},
			},
		},
	},

	-- Run (replaces Roblox's, when sprinting). The same 4 frames as the walk
	-- tutorial for each step, EXAGGERATED so it reads well:
	--   CONTACT  the leg lands far in front;
	--   DOWN     the weight crushes the body down (big bend, heel kicked up behind);
	--   PASS     the free knee comes through high under the body;
	--   UP       push-off: the body flies (both feet up), knee high in front.
	-- Big shoulder turn, very wide arm swing held out from the body, head steady.
	-- Feet computed on the ground.
	Run = {
		length = 0.64,
		looped = true,
		keyframes = {
			{
				time = 0, -- right leg: CONTACT (far in front)
				pose = {
					Root = { rot = Vector3.new(-12, -14, 0), pos = Vector3.new(0, -0.21, 0) },
					Neck = { rot = Vector3.new(9, 11, 0) },
					RightShoulder = { rot = Vector3.new(-38, 0, 8) },
					LeftShoulder = { rot = Vector3.new(82, 0, -8) },
					RightHip = { rot = Vector3.new(52, 0, 0) },
					LeftHip = { rot = Vector3.new(-40, 0, 0), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 0.04,
				pose = {
					Root = { rot = Vector3.new(-12, -12.93, -1.15), pos = Vector3.new(0, -0.25, 0) },
					Neck = { rot = Vector3.new(9, 10.16, 0.77) },
					RightShoulder = { rot = Vector3.new(-33.43, 0, 8) },
					LeftShoulder = { rot = Vector3.new(77.43, 0, -8) },
					RightHip = { rot = Vector3.new(38, 0, 0), pos = Vector3.new(0, 0.22, 0) },
					LeftHip = { rot = Vector3.new(-38, 0, 0), pos = Vector3.new(0, 0.26, 0) },
				},
			},
			{
				time = 0.08, -- right leg: DOWN (heavy: the weight bends it a lot)
				pose = {
					Root = { rot = Vector3.new(-12, -9.9, -2.12), pos = Vector3.new(0, -0.3, 0) },
					Neck = { rot = Vector3.new(9, 7.78, 1.41) },
					RightShoulder = { rot = Vector3.new(-20.43, 0, 8) },
					LeftShoulder = { rot = Vector3.new(64.43, 0, -8) },
					RightHip = { rot = Vector3.new(24, 0, 0), pos = Vector3.new(0, 0.32, 0) },
					LeftHip = { rot = Vector3.new(-36, 0, 0), pos = Vector3.new(0, 0.46, 0) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-12, -5.36, -2.77), pos = Vector3.new(0, -0.18, 0) },
					Neck = { rot = Vector3.new(9, 4.21, 1.85) },
					RightShoulder = { rot = Vector3.new(-0.96, 0, 8) },
					LeftShoulder = { rot = Vector3.new(44.96, 0, -8) },
					RightHip = { rot = Vector3.new(14, 0, 0), pos = Vector3.new(0, 0.17, 0) },
					LeftHip = { rot = Vector3.new(-4, 0, 0), pos = Vector3.new(0, 0.48, 0) },
				},
			},
			{
				time = 0.16, -- right leg: PASS (under the body, straightening)
				pose = {
					Root = { rot = Vector3.new(-12, 0, -3), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(9, 0, 2) },
					RightShoulder = { rot = Vector3.new(22, 0, 8) },
					LeftShoulder = { rot = Vector3.new(22, 0, -8) },
					RightHip = { rot = Vector3.new(4, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(28, 0, 0), pos = Vector3.new(0, 0.5, 0) },
				},
			},
			{
				time = 0.2,
				pose = {
					Root = { rot = Vector3.new(-12, 5.36, -2.77), pos = Vector3.new(0, 0.01, 0) },
					Neck = { rot = Vector3.new(9, -4.21, 1.85) },
					RightShoulder = { rot = Vector3.new(44.96, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-0.96, 0, -8) },
					RightHip = { rot = Vector3.new(-10, 0, 0), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(48, 0, 0), pos = Vector3.new(0, 0.37, 0) },
				},
			},
			{
				time = 0.24, -- right leg: UP (push-off, body flies)
				pose = {
					Root = { rot = Vector3.new(-12, 9.9, -2.12), pos = Vector3.new(0, 0.08, 0) },
					Neck = { rot = Vector3.new(9, -7.78, 1.41) },
					RightShoulder = { rot = Vector3.new(64.43, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-20.43, 0, -8) },
					RightHip = { rot = Vector3.new(-24, 0, 0) },
					LeftHip = { rot = Vector3.new(68, 0, 0), pos = Vector3.new(0, 0.24, 0) },
				},
			},
			{
				time = 0.28,
				pose = {
					Root = { rot = Vector3.new(-12, 12.93, -1.15), pos = Vector3.new(0, -0.06, 0) },
					Neck = { rot = Vector3.new(9, -10.16, 0.77) },
					RightShoulder = { rot = Vector3.new(77.43, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-33.43, 0, -8) },
					RightHip = { rot = Vector3.new(-32, 0, 0), pos = Vector3.new(0, -0.05, 0) },
					LeftHip = { rot = Vector3.new(60, 0, 0), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.32, -- right leg: CONTACT (behind, other foot lands)
				pose = {
					Root = { rot = Vector3.new(-12, 14, 0), pos = Vector3.new(0, -0.21, 0) },
					Neck = { rot = Vector3.new(9, -11, 0) },
					RightShoulder = { rot = Vector3.new(82, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-38, 0, -8) },
					RightHip = { rot = Vector3.new(-40, 0, 0), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(52, 0, 0) },
				},
			},
			{
				time = 0.36,
				pose = {
					Root = { rot = Vector3.new(-12, 12.93, 1.15), pos = Vector3.new(0, -0.25, 0) },
					Neck = { rot = Vector3.new(9, -10.16, -0.77) },
					RightShoulder = { rot = Vector3.new(77.43, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-33.43, 0, -8) },
					RightHip = { rot = Vector3.new(-38, 0, 0), pos = Vector3.new(0, 0.26, 0) },
					LeftHip = { rot = Vector3.new(38, 0, 0), pos = Vector3.new(0, 0.22, 0) },
				},
			},
			{
				time = 0.4, -- right leg: DOWN (heel kicked up behind)
				pose = {
					Root = { rot = Vector3.new(-12, 9.9, 2.12), pos = Vector3.new(0, -0.3, 0) },
					Neck = { rot = Vector3.new(9, -7.78, -1.41) },
					RightShoulder = { rot = Vector3.new(64.43, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-20.43, 0, -8) },
					RightHip = { rot = Vector3.new(-36, 0, 0), pos = Vector3.new(0, 0.46, 0) },
					LeftHip = { rot = Vector3.new(24, 0, 0), pos = Vector3.new(0, 0.32, 0) },
				},
			},
			{
				time = 0.44,
				pose = {
					Root = { rot = Vector3.new(-12, 5.36, 2.77), pos = Vector3.new(0, -0.18, 0) },
					Neck = { rot = Vector3.new(9, -4.21, -1.85) },
					RightShoulder = { rot = Vector3.new(44.96, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-0.96, 0, -8) },
					RightHip = { rot = Vector3.new(-4, 0, 0), pos = Vector3.new(0, 0.48, 0) },
					LeftHip = { rot = Vector3.new(14, 0, 0), pos = Vector3.new(0, 0.17, 0) },
				},
			},
			{
				time = 0.48, -- right leg: PASS (knee comes through high)
				pose = {
					Root = { rot = Vector3.new(-12, 0, 3), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(9, 0, -2) },
					RightShoulder = { rot = Vector3.new(22, 0, 8) },
					LeftShoulder = { rot = Vector3.new(22, 0, -8) },
					RightHip = { rot = Vector3.new(28, 0, 0), pos = Vector3.new(0, 0.5, 0) },
					LeftHip = { rot = Vector3.new(4, 0, 0), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.52,
				pose = {
					Root = { rot = Vector3.new(-12, -5.36, 2.77), pos = Vector3.new(0, 0.01, 0) },
					Neck = { rot = Vector3.new(9, 4.21, -1.85) },
					RightShoulder = { rot = Vector3.new(-0.96, 0, 8) },
					LeftShoulder = { rot = Vector3.new(44.96, 0, -8) },
					RightHip = { rot = Vector3.new(48, 0, 0), pos = Vector3.new(0, 0.37, 0) },
					LeftHip = { rot = Vector3.new(-10, 0, 0), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.56, -- right leg: UP (knee high in front, flying)
				pose = {
					Root = { rot = Vector3.new(-12, -9.9, 2.12), pos = Vector3.new(0, 0.08, 0) },
					Neck = { rot = Vector3.new(9, 7.78, -1.41) },
					RightShoulder = { rot = Vector3.new(-20.43, 0, 8) },
					LeftShoulder = { rot = Vector3.new(64.43, 0, -8) },
					RightHip = { rot = Vector3.new(68, 0, 0), pos = Vector3.new(0, 0.24, 0) },
					LeftHip = { rot = Vector3.new(-24, 0, 0) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = { rot = Vector3.new(-12, -12.93, 1.15), pos = Vector3.new(0, -0.06, 0) },
					Neck = { rot = Vector3.new(9, 10.16, -0.77) },
					RightShoulder = { rot = Vector3.new(-33.43, 0, 8) },
					LeftShoulder = { rot = Vector3.new(77.43, 0, -8) },
					RightHip = { rot = Vector3.new(60, 0, 0), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(-32, 0, 0), pos = Vector3.new(0, -0.05, 0) },
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
}

return table.freeze(clips)
