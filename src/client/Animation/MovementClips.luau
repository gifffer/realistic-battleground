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

	-- Locomotion: standing, walking (4 directions) and running, after the
	-- movement the player chose (reference videos 15 and 17:
	-- docs/references/video17.md). Generated by tools/anim/locomotion_clips.py
	-- (edit the tables there, not here). Played by Animation/Locomotion:
	--   • Walk / WalkBack / WalkLeft / WalkRight / Run are PHASE clips: length
	--     1 = one full cycle (two steps), 16 keys, all on ONE shared phase that
	--     advances with the distance walked (never restarted), with their
	--     foot contacts at the same keys, so they blend into each other (and
	--     walk into run) without the legs scissoring.
	--   • Idle is the pose every one of them fades to when slowing down (the
	--     steps get smaller, then stop), so standing / walking never jump.
	--   Walk       a punchy heel-flick power-walk: each leg flicks back and out,
	--              the same-side arm punches forward across the chest while the
	--              other swings back behind; 2 keys up, a short dwell, a return
	--              that slows into the passing; the arms lead the legs by a key
	--              and keep moving through the passing; torso twist, bob, head
	--              kept steady.
	--   WalkBack   guard backpedal: both arms locked up and out in front, the
	--              front knee lifted, the body rocking side to side.
	--   WalkLeft   side-hop: the lead leg kicks out to hip height on each hop,
	--              one arm crosses behind the back while the other flings out.
	--   WalkRight  the same, mirrored.
	--   Run        the walk's shape, bigger: arms +-70, trailing leg nearly
	--              horizontal, torso pitched forward, strong bob.
	-- Feet computed on the floor (the body is lifted where a leg's corner
	-- would sink).
	-- BEGIN generated locomotion (tools/anim/locomotion_clips.py)
	Idle = {
		length = 3.6,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-2, 0, 0) },
					Neck = { rot = Vector3.new(2, 0, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 8) },
					LeftShoulder = { rot = Vector3.new(0, 0, -8) },
					RightHip = { rot = Vector3.new(0, 0, 3) },
					LeftHip = { rot = Vector3.new(0, 0, -3) },
				},
			},
			{
				time = 1.8,
				pose = {
					Root = { rot = Vector3.new(-2.6, 0, 0), pos = Vector3.new(0, 0.012, 0) },
					Neck = { rot = Vector3.new(2.8, 0, 0) },
					RightShoulder = { rot = Vector3.new(1, 0, 9) },
					LeftShoulder = { rot = Vector3.new(1, 0, -9) },
					RightHip = { rot = Vector3.new(0, 0, 3) },
					LeftHip = { rot = Vector3.new(0, 0, -3) },
				},
			},
		},
	},
	Walk = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(-12, 0, 12) },
					LeftShoulder = { rot = Vector3.new(5, 0, -10) },
					RightHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.036, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.036, 0) },
				},
			},
			{
				time = 0.062,
				pose = {
					Root = { rot = Vector3.new(-6, -3, -1), pos = Vector3.new(0, 0.03, 0) },
					Neck = { rot = Vector3.new(4, 1.8, 0.6) },
					RightShoulder = { rot = Vector3.new(-40, 0, 2) },
					LeftShoulder = { rot = Vector3.new(30, -5, 0) },
					RightHip = { rot = Vector3.new(6, 0, 0) },
					LeftHip = { rot = Vector3.new(-5, 0, -2), pos = Vector3.new(0, 0.055, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = { rot = Vector3.new(-7, -7, -2), pos = Vector3.new(0, 0.07, 0) },
					Neck = { rot = Vector3.new(4.5, 4.2, 1.2) },
					RightShoulder = { rot = Vector3.new(-58, 0, -12) },
					LeftShoulder = { rot = Vector3.new(65, -15, 15) },
					RightHip = { rot = Vector3.new(10, 0, 0) },
					LeftHip = { rot = Vector3.new(-35, 0, -10), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.188,
				pose = {
					Root = { rot = Vector3.new(-8, -10, -3), pos = Vector3.new(0, 0.08, 0) },
					Neck = { rot = Vector3.new(5, 6, 1.8) },
					RightShoulder = { rot = Vector3.new(-62, 0, -18) },
					LeftShoulder = { rot = Vector3.new(80, -20, 25) },
					RightHip = { rot = Vector3.new(12, 0, 0) },
					LeftHip = { rot = Vector3.new(-70, 0, -16), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = { rot = Vector3.new(-8, -10, -3), pos = Vector3.new(0, 0.07, 0) },
					Neck = { rot = Vector3.new(5, 6, 1.8) },
					RightShoulder = { rot = Vector3.new(-60, 0, -16) },
					LeftShoulder = { rot = Vector3.new(82, -20, 25) },
					RightHip = { rot = Vector3.new(10, 0, 0) },
					LeftHip = { rot = Vector3.new(-75, 0, -18), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.312,
				pose = {
					Root = { rot = Vector3.new(-7, -8, -2.5), pos = Vector3.new(0, 0.03, 0) },
					Neck = { rot = Vector3.new(4.5, 4.8, 1.5) },
					RightShoulder = { rot = Vector3.new(-45, 0, -5) },
					LeftShoulder = { rot = Vector3.new(75, -18, 20) },
					RightHip = { rot = Vector3.new(6, 0, 0) },
					LeftHip = { rot = Vector3.new(-70, 0, -16), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = { rot = Vector3.new(-6, -4, -1.5), pos = Vector3.new(0, -0.03, 0) },
					Neck = { rot = Vector3.new(4, 2.4, 0.9) },
					RightShoulder = { rot = Vector3.new(-22, 0, 6) },
					LeftShoulder = { rot = Vector3.new(50, -10, 5) },
					RightHip = { rot = Vector3.new(3, 0, 0), pos = Vector3.new(0, 0.066, 0) },
					LeftHip = { rot = Vector3.new(-40, 0, -10), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.438,
				pose = {
					Root = { rot = Vector3.new(-6, -1, -0.5), pos = Vector3.new(0, -0.04, 0) },
					Neck = { rot = Vector3.new(4, 0.6, 0.3) },
					RightShoulder = { rot = Vector3.new(-5, 0, 11) },
					LeftShoulder = { rot = Vector3.new(18, -3, -8) },
					RightHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.083, 0) },
					LeftHip = { rot = Vector3.new(-4, 0, -3), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(5, 0, 10) },
					LeftShoulder = { rot = Vector3.new(-12, 0, -12) },
					RightHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.036, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.036, 0) },
				},
			},
			{
				time = 0.562,
				pose = {
					Root = { rot = Vector3.new(-6, 3, 1), pos = Vector3.new(0, 0.03, 0) },
					Neck = { rot = Vector3.new(4, -1.8, -0.6) },
					RightShoulder = { rot = Vector3.new(30, 5, 0) },
					LeftShoulder = { rot = Vector3.new(-40, 0, -2) },
					RightHip = { rot = Vector3.new(-5, 0, 2), pos = Vector3.new(0, 0.055, 0) },
					LeftHip = { rot = Vector3.new(6, 0, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = { rot = Vector3.new(-7, 7, 2), pos = Vector3.new(0, 0.07, 0) },
					Neck = { rot = Vector3.new(4.5, -4.2, -1.2) },
					RightShoulder = { rot = Vector3.new(65, 15, -15) },
					LeftShoulder = { rot = Vector3.new(-58, 0, 12) },
					RightHip = { rot = Vector3.new(-35, 0, 10), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0) },
				},
			},
			{
				time = 0.688,
				pose = {
					Root = { rot = Vector3.new(-8, 10, 3), pos = Vector3.new(0, 0.08, 0) },
					Neck = { rot = Vector3.new(5, -6, -1.8) },
					RightShoulder = { rot = Vector3.new(80, 20, -25) },
					LeftShoulder = { rot = Vector3.new(-62, 0, 18) },
					RightHip = { rot = Vector3.new(-70, 0, 16), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(12, 0, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = { rot = Vector3.new(-8, 10, 3), pos = Vector3.new(0, 0.07, 0) },
					Neck = { rot = Vector3.new(5, -6, -1.8) },
					RightShoulder = { rot = Vector3.new(82, 20, -25) },
					LeftShoulder = { rot = Vector3.new(-60, 0, 16) },
					RightHip = { rot = Vector3.new(-75, 0, 18), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(10, 0, 0) },
				},
			},
			{
				time = 0.812,
				pose = {
					Root = { rot = Vector3.new(-7, 8, 2.5), pos = Vector3.new(0, 0.03, 0) },
					Neck = { rot = Vector3.new(4.5, -4.8, -1.5) },
					RightShoulder = { rot = Vector3.new(75, 18, -20) },
					LeftShoulder = { rot = Vector3.new(-45, 0, 5) },
					RightHip = { rot = Vector3.new(-70, 0, 16), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(6, 0, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = { rot = Vector3.new(-6, 4, 1.5), pos = Vector3.new(0, -0.03, 0) },
					Neck = { rot = Vector3.new(4, -2.4, -0.9) },
					RightShoulder = { rot = Vector3.new(50, 10, -5) },
					LeftShoulder = { rot = Vector3.new(-22, 0, -6) },
					RightHip = { rot = Vector3.new(-40, 0, 10), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(3, 0, 0), pos = Vector3.new(0, 0.066, 0) },
				},
			},
			{
				time = 0.938,
				pose = {
					Root = { rot = Vector3.new(-6, 1, 0.5), pos = Vector3.new(0, -0.04, 0) },
					Neck = { rot = Vector3.new(4, -0.6, -0.3) },
					RightShoulder = { rot = Vector3.new(18, 3, 8) },
					LeftShoulder = { rot = Vector3.new(-5, 0, -11) },
					RightHip = { rot = Vector3.new(-4, 0, 3), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.083, 0) },
				},
			},
		},
	},
	WalkBack = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(3, 0, 0), pos = Vector3.new(0, -0.11, 0) },
					Neck = { rot = Vector3.new(-2, 0, 0) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(-45, 0, 0) },
					LeftHip = { rot = Vector3.new(50, 0, 0), pos = Vector3.new(0, 0.35, 0) },
				},
			},
			{
				time = 0.062,
				pose = {
					Root = { rot = Vector3.new(3, 1, 2), pos = Vector3.new(0, -0.1, 0) },
					Neck = { rot = Vector3.new(-2, -0.6, -1.2) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(-44, 0, 0) },
					LeftHip = { rot = Vector3.new(48, 0, 0), pos = Vector3.new(0, 0.34, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = { rot = Vector3.new(3, 1.5, 4), pos = Vector3.new(0, -0.08, 0) },
					Neck = { rot = Vector3.new(-2, -0.9, -2.4) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(-42, 0, 0) },
					LeftHip = { rot = Vector3.new(45, 0, 0), pos = Vector3.new(0, 0.32, 0) },
				},
			},
			{
				time = 0.188,
				pose = {
					Root = { rot = Vector3.new(3, 2, 5), pos = Vector3.new(0, 0.02, 0) },
					Neck = { rot = Vector3.new(-2, -1.2, -3) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(-30, 0, 0) },
					LeftHip = { rot = Vector3.new(33, 0, 0), pos = Vector3.new(0, 0.27, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = { rot = Vector3.new(3, 2, 6), pos = Vector3.new(0, 0.1, 0) },
					Neck = { rot = Vector3.new(-2, -1.2, -3.6) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(-15, 0, 0) },
					LeftHip = { rot = Vector3.new(20, 0, 0), pos = Vector3.new(0, 0.21, 0) },
				},
			},
			{
				time = 0.312,
				pose = {
					Root = { rot = Vector3.new(3, 1.5, 6), pos = Vector3.new(0, 0.07, 0) },
					Neck = { rot = Vector3.new(-2, -0.9, -3.6) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = { rot = Vector3.new(3, 1, 4), pos = Vector3.new(0, 0.02, 0) },
					Neck = { rot = Vector3.new(-2, -0.6, -2.4) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(20, 0, 0), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(-25, 0, 0), pos = Vector3.new(0, 0.084, 0) },
				},
			},
			{
				time = 0.438,
				pose = {
					Root = { rot = Vector3.new(3, 0.5, 2), pos = Vector3.new(0, -0.06, 0) },
					Neck = { rot = Vector3.new(-2, -0.3, -1.2) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(35, 0, 0), pos = Vector3.new(0, 0.25, 0) },
					LeftHip = { rot = Vector3.new(-37, 0, 0), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(3, 0, 0), pos = Vector3.new(0, -0.11, 0) },
					Neck = { rot = Vector3.new(-2, 0, 0) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(50, 0, 0), pos = Vector3.new(0, 0.35, 0) },
					LeftHip = { rot = Vector3.new(-45, 0, 0) },
				},
			},
			{
				time = 0.562,
				pose = {
					Root = { rot = Vector3.new(3, -1, -2), pos = Vector3.new(0, -0.1, 0) },
					Neck = { rot = Vector3.new(-2, 0.6, 1.2) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(48, 0, 0), pos = Vector3.new(0, 0.34, 0) },
					LeftHip = { rot = Vector3.new(-44, 0, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = { rot = Vector3.new(3, -1.5, -4), pos = Vector3.new(0, -0.08, 0) },
					Neck = { rot = Vector3.new(-2, 0.9, 2.4) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(45, 0, 0), pos = Vector3.new(0, 0.32, 0) },
					LeftHip = { rot = Vector3.new(-42, 0, 0) },
				},
			},
			{
				time = 0.688,
				pose = {
					Root = { rot = Vector3.new(3, -2, -5), pos = Vector3.new(0, 0.02, 0) },
					Neck = { rot = Vector3.new(-2, 1.2, 3) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(33, 0, 0), pos = Vector3.new(0, 0.27, 0) },
					LeftHip = { rot = Vector3.new(-30, 0, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = { rot = Vector3.new(3, -2, -6), pos = Vector3.new(0, 0.1, 0) },
					Neck = { rot = Vector3.new(-2, 1.2, 3.6) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(20, 0, 0), pos = Vector3.new(0, 0.21, 0) },
					LeftHip = { rot = Vector3.new(-15, 0, 0) },
				},
			},
			{
				time = 0.812,
				pose = {
					Root = { rot = Vector3.new(3, -1.5, -6), pos = Vector3.new(0, 0.07, 0) },
					Neck = { rot = Vector3.new(-2, 0.9, 3.6) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.14, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = { rot = Vector3.new(3, -1, -4), pos = Vector3.new(0, 0.02, 0) },
					Neck = { rot = Vector3.new(-2, 0.6, 2.4) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(-25, 0, 0), pos = Vector3.new(0, 0.084, 0) },
					LeftHip = { rot = Vector3.new(20, 0, 0), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.938,
				pose = {
					Root = { rot = Vector3.new(3, -0.5, -2), pos = Vector3.new(0, -0.06, 0) },
					Neck = { rot = Vector3.new(-2, 0.3, 1.2) },
					RightShoulder = { rot = Vector3.new(88, 0, 40) },
					LeftShoulder = { rot = Vector3.new(88, 0, -40) },
					RightHip = { rot = Vector3.new(-37, 0, 0), pos = Vector3.new(0, 0.03, 0) },
					LeftHip = { rot = Vector3.new(35, 0, 0), pos = Vector3.new(0, 0.25, 0) },
				},
			},
		},
	},
	WalkLeft = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, -0.12, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(-5, 0, 15) },
					LeftShoulder = { rot = Vector3.new(0, 0, -8) },
					RightHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -5), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.062,
				pose = {
					Root = { rot = Vector3.new(0, 3, -2), pos = Vector3.new(0, 0.04, 0) },
					Neck = { rot = Vector3.new(0, -1.8, 1.2) },
					RightShoulder = { rot = Vector3.new(5, 0, 38) },
					LeftShoulder = { rot = Vector3.new(-15, 0, 2) },
					RightHip = { rot = Vector3.new(0, 0, 6), pos = Vector3.new(0, 0.059, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -20), pos = Vector3.new(0, 0.154, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = { rot = Vector3.new(0, 5, -4), pos = Vector3.new(0, 0.14, 0) },
					Neck = { rot = Vector3.new(0, -3, 2.4) },
					RightShoulder = { rot = Vector3.new(8, 0, 52) },
					LeftShoulder = { rot = Vector3.new(-30, 0, 10) },
					RightHip = { rot = Vector3.new(0, 0, 12), pos = Vector3.new(0, 0.047, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -45), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.188,
				pose = {
					Root = { rot = Vector3.new(0, 8, -5), pos = Vector3.new(0, 0.1, 0) },
					Neck = { rot = Vector3.new(0, -4.8, 3) },
					RightShoulder = { rot = Vector3.new(10, 0, 62) },
					LeftShoulder = { rot = Vector3.new(-55, 0, 30) },
					RightHip = { rot = Vector3.new(0, 0, 4) },
					LeftHip = { rot = Vector3.new(0, 0, -80), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = { rot = Vector3.new(0, 8, -5), pos = Vector3.new(0, 0.07, 0) },
					Neck = { rot = Vector3.new(0, -4.8, 3) },
					RightShoulder = { rot = Vector3.new(10, 0, 65) },
					LeftShoulder = { rot = Vector3.new(-60, 0, 35) },
					RightHip = { rot = Vector3.new(0, 0, 2), pos = Vector3.new(0, 0.011, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -85), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.312,
				pose = {
					Root = { rot = Vector3.new(0, 8, -5), pos = Vector3.new(0, 0.03, 0) },
					Neck = { rot = Vector3.new(0, -4.8, 3) },
					RightShoulder = { rot = Vector3.new(10, 0, 62) },
					LeftShoulder = { rot = Vector3.new(-60, 0, 35) },
					RightHip = { rot = Vector3.new(0, 0, 2), pos = Vector3.new(0, 0.051, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -83), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = { rot = Vector3.new(0, 6, -4), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(0, -3.6, 2.4) },
					RightShoulder = { rot = Vector3.new(6, 0, 48) },
					LeftShoulder = { rot = Vector3.new(-50, 0, 28) },
					RightHip = { rot = Vector3.new(0, 0, 2), pos = Vector3.new(0, 0.116, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -62), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.438,
				pose = {
					Root = { rot = Vector3.new(0, 1, -1), pos = Vector3.new(0, -0.13, 0) },
					Neck = { rot = Vector3.new(0, -0.6, 0.6) },
					RightShoulder = { rot = Vector3.new(2, 0, 25) },
					LeftShoulder = { rot = Vector3.new(-28, 0, 8) },
					RightHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.147, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -25), pos = Vector3.new(0, 0.348, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, -0.12, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-5, 0, -15) },
					RightHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.13, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -5), pos = Vector3.new(0, 0.2, 0) },
				},
			},
			{
				time = 0.562,
				pose = {
					Root = { rot = Vector3.new(0, -3, -2), pos = Vector3.new(0, 0.04, 0) },
					Neck = { rot = Vector3.new(0, 1.8, 1.2) },
					RightShoulder = { rot = Vector3.new(-15, 0, -2) },
					LeftShoulder = { rot = Vector3.new(5, 0, -38) },
					RightHip = { rot = Vector3.new(0, 0, 6), pos = Vector3.new(0, 0.059, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -20), pos = Vector3.new(0, 0.154, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = { rot = Vector3.new(0, -5, -4), pos = Vector3.new(0, 0.14, 0) },
					Neck = { rot = Vector3.new(0, 3, 2.4) },
					RightShoulder = { rot = Vector3.new(-30, 0, -10) },
					LeftShoulder = { rot = Vector3.new(8, 0, -52) },
					RightHip = { rot = Vector3.new(0, 0, 12), pos = Vector3.new(0, 0.047, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -45), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.688,
				pose = {
					Root = { rot = Vector3.new(0, -8, -5), pos = Vector3.new(0, 0.1, 0) },
					Neck = { rot = Vector3.new(0, 4.8, 3) },
					RightShoulder = { rot = Vector3.new(-55, 0, -30) },
					LeftShoulder = { rot = Vector3.new(10, 0, -62) },
					RightHip = { rot = Vector3.new(0, 0, 4) },
					LeftHip = { rot = Vector3.new(0, 0, -80), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = { rot = Vector3.new(0, -8, -5), pos = Vector3.new(0, 0.07, 0) },
					Neck = { rot = Vector3.new(0, 4.8, 3) },
					RightShoulder = { rot = Vector3.new(-60, 0, -35) },
					LeftShoulder = { rot = Vector3.new(10, 0, -65) },
					RightHip = { rot = Vector3.new(0, 0, 2), pos = Vector3.new(0, 0.011, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -85), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.812,
				pose = {
					Root = { rot = Vector3.new(0, -8, -5), pos = Vector3.new(0, 0.03, 0) },
					Neck = { rot = Vector3.new(0, 4.8, 3) },
					RightShoulder = { rot = Vector3.new(-60, 0, -35) },
					LeftShoulder = { rot = Vector3.new(10, 0, -62) },
					RightHip = { rot = Vector3.new(0, 0, 2), pos = Vector3.new(0, 0.051, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -83), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = { rot = Vector3.new(0, -6, -4), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(0, 3.6, 2.4) },
					RightShoulder = { rot = Vector3.new(-50, 0, -28) },
					LeftShoulder = { rot = Vector3.new(6, 0, -48) },
					RightHip = { rot = Vector3.new(0, 0, 2), pos = Vector3.new(0, 0.116, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -62), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.938,
				pose = {
					Root = { rot = Vector3.new(0, -1, -1), pos = Vector3.new(0, -0.13, 0) },
					Neck = { rot = Vector3.new(0, 0.6, 0.6) },
					RightShoulder = { rot = Vector3.new(-28, 0, -8) },
					LeftShoulder = { rot = Vector3.new(2, 0, -25) },
					RightHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.147, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -25), pos = Vector3.new(0, 0.348, 0) },
				},
			},
		},
	},
	WalkRight = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, -0.12, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(0, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-5, 0, -15) },
					RightHip = { rot = Vector3.new(0, 0, 5), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.062,
				pose = {
					Root = { rot = Vector3.new(0, -3, 2), pos = Vector3.new(0, 0.04, 0) },
					Neck = { rot = Vector3.new(0, 1.8, -1.2) },
					RightShoulder = { rot = Vector3.new(-15, 0, -2) },
					LeftShoulder = { rot = Vector3.new(5, 0, -38) },
					RightHip = { rot = Vector3.new(0, 0, 20), pos = Vector3.new(0, 0.154, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -6), pos = Vector3.new(0, 0.059, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = { rot = Vector3.new(0, -5, 4), pos = Vector3.new(0, 0.14, 0) },
					Neck = { rot = Vector3.new(0, 3, -2.4) },
					RightShoulder = { rot = Vector3.new(-30, 0, -10) },
					LeftShoulder = { rot = Vector3.new(8, 0, -52) },
					RightHip = { rot = Vector3.new(0, 0, 45), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -12), pos = Vector3.new(0, 0.047, 0) },
				},
			},
			{
				time = 0.188,
				pose = {
					Root = { rot = Vector3.new(0, -8, 5), pos = Vector3.new(0, 0.1, 0) },
					Neck = { rot = Vector3.new(0, 4.8, -3) },
					RightShoulder = { rot = Vector3.new(-55, 0, -30) },
					LeftShoulder = { rot = Vector3.new(10, 0, -62) },
					RightHip = { rot = Vector3.new(0, 0, 80), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -4) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = { rot = Vector3.new(0, -8, 5), pos = Vector3.new(0, 0.07, 0) },
					Neck = { rot = Vector3.new(0, 4.8, -3) },
					RightShoulder = { rot = Vector3.new(-60, 0, -35) },
					LeftShoulder = { rot = Vector3.new(10, 0, -65) },
					RightHip = { rot = Vector3.new(0, 0, 85), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -2), pos = Vector3.new(0, 0.011, 0) },
				},
			},
			{
				time = 0.312,
				pose = {
					Root = { rot = Vector3.new(0, -8, 5), pos = Vector3.new(0, 0.03, 0) },
					Neck = { rot = Vector3.new(0, 4.8, -3) },
					RightShoulder = { rot = Vector3.new(-60, 0, -35) },
					LeftShoulder = { rot = Vector3.new(10, 0, -62) },
					RightHip = { rot = Vector3.new(0, 0, 83), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -2), pos = Vector3.new(0, 0.051, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = { rot = Vector3.new(0, -6, 4), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(0, 3.6, -2.4) },
					RightShoulder = { rot = Vector3.new(-50, 0, -28) },
					LeftShoulder = { rot = Vector3.new(6, 0, -48) },
					RightHip = { rot = Vector3.new(0, 0, 62), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -2), pos = Vector3.new(0, 0.116, 0) },
				},
			},
			{
				time = 0.438,
				pose = {
					Root = { rot = Vector3.new(0, -1, 1), pos = Vector3.new(0, -0.13, 0) },
					Neck = { rot = Vector3.new(0, 0.6, -0.6) },
					RightShoulder = { rot = Vector3.new(-28, 0, -8) },
					LeftShoulder = { rot = Vector3.new(2, 0, -25) },
					RightHip = { rot = Vector3.new(0, 0, 25), pos = Vector3.new(0, 0.348, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.147, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, -0.12, 0) },
					Neck = { rot = Vector3.new(0, 0, 0) },
					RightShoulder = { rot = Vector3.new(-5, 0, 15) },
					LeftShoulder = { rot = Vector3.new(0, 0, -8) },
					RightHip = { rot = Vector3.new(0, 0, 5), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.13, 0) },
				},
			},
			{
				time = 0.562,
				pose = {
					Root = { rot = Vector3.new(0, 3, 2), pos = Vector3.new(0, 0.04, 0) },
					Neck = { rot = Vector3.new(0, -1.8, -1.2) },
					RightShoulder = { rot = Vector3.new(5, 0, 38) },
					LeftShoulder = { rot = Vector3.new(-15, 0, 2) },
					RightHip = { rot = Vector3.new(0, 0, 20), pos = Vector3.new(0, 0.154, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -6), pos = Vector3.new(0, 0.059, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = { rot = Vector3.new(0, 5, 4), pos = Vector3.new(0, 0.14, 0) },
					Neck = { rot = Vector3.new(0, -3, -2.4) },
					RightShoulder = { rot = Vector3.new(8, 0, 52) },
					LeftShoulder = { rot = Vector3.new(-30, 0, 10) },
					RightHip = { rot = Vector3.new(0, 0, 45), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -12), pos = Vector3.new(0, 0.047, 0) },
				},
			},
			{
				time = 0.688,
				pose = {
					Root = { rot = Vector3.new(0, 8, 5), pos = Vector3.new(0, 0.1, 0) },
					Neck = { rot = Vector3.new(0, -4.8, -3) },
					RightShoulder = { rot = Vector3.new(10, 0, 62) },
					LeftShoulder = { rot = Vector3.new(-55, 0, 30) },
					RightHip = { rot = Vector3.new(0, 0, 80), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -4) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = { rot = Vector3.new(0, 8, 5), pos = Vector3.new(0, 0.07, 0) },
					Neck = { rot = Vector3.new(0, -4.8, -3) },
					RightShoulder = { rot = Vector3.new(10, 0, 65) },
					LeftShoulder = { rot = Vector3.new(-60, 0, 35) },
					RightHip = { rot = Vector3.new(0, 0, 85), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -2), pos = Vector3.new(0, 0.011, 0) },
				},
			},
			{
				time = 0.812,
				pose = {
					Root = { rot = Vector3.new(0, 8, 5), pos = Vector3.new(0, 0.03, 0) },
					Neck = { rot = Vector3.new(0, -4.8, -3) },
					RightShoulder = { rot = Vector3.new(10, 0, 62) },
					LeftShoulder = { rot = Vector3.new(-60, 0, 35) },
					RightHip = { rot = Vector3.new(0, 0, 83), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -2), pos = Vector3.new(0, 0.051, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = { rot = Vector3.new(0, 6, 4), pos = Vector3.new(0, -0.05, 0) },
					Neck = { rot = Vector3.new(0, -3.6, -2.4) },
					RightShoulder = { rot = Vector3.new(6, 0, 48) },
					LeftShoulder = { rot = Vector3.new(-50, 0, 28) },
					RightHip = { rot = Vector3.new(0, 0, 62), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(0, 0, -2), pos = Vector3.new(0, 0.116, 0) },
				},
			},
			{
				time = 0.938,
				pose = {
					Root = { rot = Vector3.new(0, 1, 1), pos = Vector3.new(0, -0.13, 0) },
					Neck = { rot = Vector3.new(0, -0.6, -0.6) },
					RightShoulder = { rot = Vector3.new(2, 0, 25) },
					LeftShoulder = { rot = Vector3.new(-28, 0, 8) },
					RightHip = { rot = Vector3.new(0, 0, 25), pos = Vector3.new(0, 0.348, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.147, 0) },
				},
			},
		},
	},
	Run = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, -0.1, 0) },
					Neck = { rot = Vector3.new(6, 0, 0) },
					RightShoulder = { rot = Vector3.new(-20, 0, 10) },
					LeftShoulder = { rot = Vector3.new(5, 0, -10) },
					RightHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.142, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.142, 0) },
				},
			},
			{
				time = 0.062,
				pose = {
					Root = { rot = Vector3.new(-9, -2, -0.5), pos = Vector3.new(0, -0.02, 0) },
					Neck = { rot = Vector3.new(6, 1.2, 0.3) },
					RightShoulder = { rot = Vector3.new(-45, 0, 8) },
					LeftShoulder = { rot = Vector3.new(35, 0, -6) },
					RightHip = { rot = Vector3.new(12, 0, 0), pos = Vector3.new(0, 0.035, 0) },
					LeftHip = { rot = Vector3.new(-15, 0, 0), pos = Vector3.new(0, 0.039, 0) },
				},
			},
			{
				time = 0.125,
				pose = {
					Root = { rot = Vector3.new(-11, -4.5, -1.2), pos = Vector3.new(0, 0.08, 0) },
					Neck = { rot = Vector3.new(7, 2.7, 0.72) },
					RightShoulder = { rot = Vector3.new(-65, 0, 4) },
					LeftShoulder = { rot = Vector3.new(60, 0, 4) },
					RightHip = { rot = Vector3.new(28, 0, 0), pos = Vector3.new(0, 0.04, 0) },
					LeftHip = { rot = Vector3.new(-50, 0, 0), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.188,
				pose = {
					Root = { rot = Vector3.new(-12, -6, -2), pos = Vector3.new(0, 0.13, 0) },
					Neck = { rot = Vector3.new(7, 3.6, 1.2) },
					RightShoulder = { rot = Vector3.new(-70, 0, 0) },
					LeftShoulder = { rot = Vector3.new(70, 0, 10) },
					RightHip = { rot = Vector3.new(35, 0, 0), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(-78, 0, 0), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = { rot = Vector3.new(-12, -6, -2), pos = Vector3.new(0, 0.12, 0) },
					Neck = { rot = Vector3.new(7, 3.6, 1.2) },
					RightShoulder = { rot = Vector3.new(-68, 0, 0) },
					LeftShoulder = { rot = Vector3.new(70, 0, 10) },
					RightHip = { rot = Vector3.new(35, 0, 0), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(-78, 0, 0), pos = Vector3.new(0, 0.15, 0) },
				},
			},
			{
				time = 0.312,
				pose = {
					Root = { rot = Vector3.new(-11, -5, -1.5), pos = Vector3.new(0, 0.06, 0) },
					Neck = { rot = Vector3.new(7, 3, 0.9) },
					RightShoulder = { rot = Vector3.new(-55, 0, 3) },
					LeftShoulder = { rot = Vector3.new(58, 0, 4) },
					RightHip = { rot = Vector3.new(28, 0, 0), pos = Vector3.new(0, 0.04, 0) },
					LeftHip = { rot = Vector3.new(-65, 0, 0), pos = Vector3.new(0, 0.12, 0) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = { rot = Vector3.new(-9, -3, -1), pos = Vector3.new(0, -0.03, 0) },
					Neck = { rot = Vector3.new(6, 1.8, 0.6) },
					RightShoulder = { rot = Vector3.new(-30, 0, 8) },
					LeftShoulder = { rot = Vector3.new(35, 0, -6) },
					RightHip = { rot = Vector3.new(15, 0, 0), pos = Vector3.new(0, 0.069, 0) },
					LeftHip = { rot = Vector3.new(-35, 0, 0), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 0.438,
				pose = {
					Root = { rot = Vector3.new(-8, -1, -0.3), pos = Vector3.new(0, -0.1, 0) },
					Neck = { rot = Vector3.new(6, 0.6, 0.18) },
					RightShoulder = { rot = Vector3.new(-8, 0, 10) },
					LeftShoulder = { rot = Vector3.new(5, 0, -10) },
					RightHip = { rot = Vector3.new(5, 0, 0), pos = Vector3.new(0, 0.118, 0) },
					LeftHip = { rot = Vector3.new(-5, 0, 0), pos = Vector3.new(0, 0.153, 0) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0), pos = Vector3.new(0, -0.1, 0) },
					Neck = { rot = Vector3.new(6, 0, 0) },
					RightShoulder = { rot = Vector3.new(5, 0, 10) },
					LeftShoulder = { rot = Vector3.new(-20, 0, -10) },
					RightHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.142, 0) },
					LeftHip = { rot = Vector3.new(0, 0, 0), pos = Vector3.new(0, 0.142, 0) },
				},
			},
			{
				time = 0.562,
				pose = {
					Root = { rot = Vector3.new(-9, 2, 0.5), pos = Vector3.new(0, -0.02, 0) },
					Neck = { rot = Vector3.new(6, -1.2, -0.3) },
					RightShoulder = { rot = Vector3.new(35, 0, 6) },
					LeftShoulder = { rot = Vector3.new(-45, 0, -8) },
					RightHip = { rot = Vector3.new(-15, 0, 0), pos = Vector3.new(0, 0.039, 0) },
					LeftHip = { rot = Vector3.new(12, 0, 0), pos = Vector3.new(0, 0.035, 0) },
				},
			},
			{
				time = 0.625,
				pose = {
					Root = { rot = Vector3.new(-11, 4.5, 1.2), pos = Vector3.new(0, 0.08, 0) },
					Neck = { rot = Vector3.new(7, -2.7, -0.72) },
					RightShoulder = { rot = Vector3.new(60, 0, -4) },
					LeftShoulder = { rot = Vector3.new(-65, 0, -4) },
					RightHip = { rot = Vector3.new(-50, 0, 0), pos = Vector3.new(0, 0.1, 0) },
					LeftHip = { rot = Vector3.new(28, 0, 0), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.688,
				pose = {
					Root = { rot = Vector3.new(-12, 6, 2), pos = Vector3.new(0, 0.13, 0) },
					Neck = { rot = Vector3.new(7, -3.6, -1.2) },
					RightShoulder = { rot = Vector3.new(70, 0, -10) },
					LeftShoulder = { rot = Vector3.new(-70, 0, 0) },
					RightHip = { rot = Vector3.new(-78, 0, 0), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(35, 0, 0), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = { rot = Vector3.new(-12, 6, 2), pos = Vector3.new(0, 0.12, 0) },
					Neck = { rot = Vector3.new(7, -3.6, -1.2) },
					RightShoulder = { rot = Vector3.new(70, 0, -10) },
					LeftShoulder = { rot = Vector3.new(-68, 0, 0) },
					RightHip = { rot = Vector3.new(-78, 0, 0), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(35, 0, 0), pos = Vector3.new(0, 0.05, 0) },
				},
			},
			{
				time = 0.812,
				pose = {
					Root = { rot = Vector3.new(-11, 5, 1.5), pos = Vector3.new(0, 0.06, 0) },
					Neck = { rot = Vector3.new(7, -3, -0.9) },
					RightShoulder = { rot = Vector3.new(58, 0, -4) },
					LeftShoulder = { rot = Vector3.new(-55, 0, -3) },
					RightHip = { rot = Vector3.new(-65, 0, 0), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(28, 0, 0), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 0.875,
				pose = {
					Root = { rot = Vector3.new(-9, 3, 1), pos = Vector3.new(0, -0.03, 0) },
					Neck = { rot = Vector3.new(6, -1.8, -0.6) },
					RightShoulder = { rot = Vector3.new(35, 0, 6) },
					LeftShoulder = { rot = Vector3.new(-30, 0, -8) },
					RightHip = { rot = Vector3.new(-35, 0, 0), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(15, 0, 0), pos = Vector3.new(0, 0.069, 0) },
				},
			},
			{
				time = 0.938,
				pose = {
					Root = { rot = Vector3.new(-8, 1, 0.3), pos = Vector3.new(0, -0.1, 0) },
					Neck = { rot = Vector3.new(6, -0.6, -0.18) },
					RightShoulder = { rot = Vector3.new(5, 0, 10) },
					LeftShoulder = { rot = Vector3.new(-8, 0, -10) },
					RightHip = { rot = Vector3.new(-5, 0, 0), pos = Vector3.new(0, 0.153, 0) },
					LeftHip = { rot = Vector3.new(5, 0, 0), pos = Vector3.new(0, 0.118, 0) },
				},
			},
		},
	},
	-- END generated locomotion

	-- BullRun: the Bull's sprint (Kit "Bull"), replaces Run. Bent far over,
	-- head down so the horns go first, arms low and wide pumping like
	-- pistons, long stomping strides with a heavy bob: he's going to smash
	-- through whatever is in front. (Authored with filmstrips; feet checked
	-- on the ground at contact.)
	BullRun = {
		length = 0.6,
		looped = true,
		keyframes = {
			{
				time = 0.0,
				pose = {
					Root = { rot = Vector3.new(-41, -12, 0), pos = Vector3.new(0, -0.42, 0) },
					Neck = { rot = Vector3.new(6, 10, 0) },
					RightShoulder = { rot = Vector3.new(-65, 0, 26) },
					LeftShoulder = { rot = Vector3.new(35, 0, -26) },
					RightHip = { rot = Vector3.new(92, 0, 4), pos = Vector3.new(0, 0, -0.25) },
					LeftHip = { rot = Vector3.new(-4, 0, -4), pos = Vector3.new(0, 0, 0.25) },
				},
			},
			{
				time = 0.075,
				pose = {
					Root = { rot = Vector3.new(-44, -8.49, 3.54), pos = Vector3.new(0, -0.3, 0) },
					Neck = { rot = Vector3.new(6, 7.07, -2.12) },
					RightShoulder = { rot = Vector3.new(-50.4, 0, 26) },
					LeftShoulder = { rot = Vector3.new(20.4, 0, -26) },
					RightHip = {
						rot = Vector3.new(77.9, 0, 4),
						pos = Vector3.new(0, 0.0566, -0.177),
					},
					LeftHip = {
						rot = Vector3.new(10.1, 0, -4),
						pos = Vector3.new(0, -0.0566, 0.177),
					},
				},
			},
			{
				time = 0.15,
				pose = {
					Root = { rot = Vector3.new(-47, 0, 5), pos = Vector3.new(0, -0.18, 0) },
					Neck = { rot = Vector3.new(6, 0, -3) },
					RightShoulder = { rot = Vector3.new(-15, 0, 26) },
					LeftShoulder = { rot = Vector3.new(-15, 0, -26) },
					RightHip = { rot = Vector3.new(44, 0, 4), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(44, 0, -4), pos = Vector3.new(0, -0.08, 0) },
				},
			},
			{
				time = 0.225,
				pose = {
					Root = { rot = Vector3.new(-44, 8.49, 3.54), pos = Vector3.new(0, -0.3, 0) },
					Neck = { rot = Vector3.new(6, -7.07, -2.12) },
					RightShoulder = { rot = Vector3.new(20.4, 0, 26) },
					LeftShoulder = { rot = Vector3.new(-50.4, 0, -26) },
					RightHip = {
						rot = Vector3.new(10.1, 0, 4),
						pos = Vector3.new(0, 0.0566, 0.177),
					},
					LeftHip = {
						rot = Vector3.new(77.9, 0, -4),
						pos = Vector3.new(0, -0.0566, -0.177),
					},
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(-41, 12, 0), pos = Vector3.new(0, -0.42, 0) },
					Neck = { rot = Vector3.new(6, -10, 0) },
					RightShoulder = { rot = Vector3.new(35, 0, 26) },
					LeftShoulder = { rot = Vector3.new(-65, 0, -26) },
					RightHip = { rot = Vector3.new(-4, 0, 4), pos = Vector3.new(0, 0, 0.25) },
					LeftHip = { rot = Vector3.new(92, 0, -4), pos = Vector3.new(0, 0, -0.25) },
				},
			},
			{
				time = 0.375,
				pose = {
					Root = { rot = Vector3.new(-44, 8.49, -3.54), pos = Vector3.new(0, -0.3, 0) },
					Neck = { rot = Vector3.new(6, -7.07, 2.12) },
					RightShoulder = { rot = Vector3.new(20.4, 0, 26) },
					LeftShoulder = { rot = Vector3.new(-50.4, 0, -26) },
					RightHip = {
						rot = Vector3.new(10.1, 0, 4),
						pos = Vector3.new(0, -0.0566, 0.177),
					},
					LeftHip = {
						rot = Vector3.new(77.9, 0, -4),
						pos = Vector3.new(0, 0.0566, -0.177),
					},
				},
			},
			{
				time = 0.45,
				pose = {
					Root = { rot = Vector3.new(-47, 0, -5), pos = Vector3.new(0, -0.18, 0) },
					Neck = { rot = Vector3.new(6, 0, 3) },
					RightShoulder = { rot = Vector3.new(-15, 0, 26) },
					LeftShoulder = { rot = Vector3.new(-15, 0, -26) },
					RightHip = { rot = Vector3.new(44, 0, 4), pos = Vector3.new(0, -0.08, 0) },
					LeftHip = { rot = Vector3.new(44, 0, -4), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.525,
				pose = {
					Root = { rot = Vector3.new(-44, -8.49, -3.54), pos = Vector3.new(0, -0.3, 0) },
					Neck = { rot = Vector3.new(6, 7.07, 2.12) },
					RightShoulder = { rot = Vector3.new(-50.4, 0, 26) },
					LeftShoulder = { rot = Vector3.new(20.4, 0, -26) },
					RightHip = {
						rot = Vector3.new(77.9, 0, 4),
						pos = Vector3.new(0, -0.0566, -0.177),
					},
					LeftHip = {
						rot = Vector3.new(10.1, 0, -4),
						pos = Vector3.new(0, 0.0566, 0.177),
					},
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
	-- BEGIN injuries (poses solved for the ground with an R6 preview script)
	-- LIMPING WALK (one leg injured): an antalgic gait. The hurt (right) foot
	-- lands flat and carefully and bears weight only briefly (trunk leaning over
	-- it to unload the hip), then the body drops onto the good leg, which
	-- carries it most of the cycle. The hurt leg swings through stiff (little
	-- knee bend), with a hip hike and a little outward arc. Arms swing little.
	-- Feet computed on the ground with an R6 preview. Authored for
	-- WALK_SPEED x Injuries.LIMP_SPEED (the game scales it with the real
	-- speed). LimpWalkLeft is this clip mirrored.
	LimpWalk = {
		length = 0.8,
		looped = true,
		keyframes = {
			{
				time = 0, -- hurt foot lands flat, carefully
				pose = {
					Root = { rot = Vector3.new(-8, -2, -1), pos = Vector3.new(0.04, 0.01, 0) },
					Neck = { rot = Vector3.new(4.6, 1.6, 0.7) },
					RightShoulder = { rot = Vector3.new(6, 0, 7) },
					LeftShoulder = { rot = Vector3.new(8, 0, -5) },
					RightHip = { rot = Vector3.new(17, 0, 2), pos = Vector3.new(0, 0.06, 0) },
					LeftHip = { rot = Vector3.new(-17, 0, 0) },
				},
			},
			{
				time = 0.048, -- weight goes onto it, trunk over it
				pose = {
					Root = {
						rot = Vector3.new(-10, -1.5, -3),
						pos = Vector3.new(0.11, -0.04, -0.02),
					},
					Neck = { rot = Vector3.new(5.8, 1.2, 2.1) },
					RightShoulder = { rot = Vector3.new(9, 0, 10) },
					LeftShoulder = { rot = Vector3.new(5, 0, -5) },
					RightHip = { rot = Vector3.new(11, 0, 2), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(-20, 0, 0) },
				},
			},
			{
				time = 0.096, -- good foot leaves: short single support
				pose = {
					Root = {
						rot = Vector3.new(-10, -0.5, -5),
						pos = Vector3.new(0.19, 0.01, -0.05),
					},
					Neck = { rot = Vector3.new(5.8, 0.4, 3.5) },
					RightShoulder = { rot = Vector3.new(10, 0, 12) },
					LeftShoulder = { rot = Vector3.new(0, 0, -5) },
					RightHip = { rot = Vector3.new(6, 0, 2), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(-19, 0, -1), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.176, -- good leg rushes through (knee bent)
				pose = {
					Root = { rot = Vector3.new(-10, 0.5, -6), pos = Vector3.new(0.22, 0.02, -0.07) },
					Neck = { rot = Vector3.new(5.8, -0.4, 4.2) },
					RightShoulder = { rot = Vector3.new(8, 0, 12) },
					LeftShoulder = { rot = Vector3.new(-6, 0, -5) },
					RightHip = { rot = Vector3.new(-1, 0, 2), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(6, 0, -2), pos = Vector3.new(0, 0.31, 0) },
				},
			},
			{
				time = 0.256, -- reaching
				pose = {
					Root = { rot = Vector3.new(-9, 1.5, -4), pos = Vector3.new(0.15, 0.04, -0.08) },
					Neck = { rot = Vector3.new(5.2, -1.2, 2.8) },
					RightShoulder = { rot = Vector3.new(4, 0, 10) },
					LeftShoulder = { rot = Vector3.new(-10, 0, -5) },
					RightHip = { rot = Vector3.new(-8, 0, 2), pos = Vector3.new(0, 0.08, 0) },
					LeftHip = { rot = Vector3.new(20, 0, -1), pos = Vector3.new(0, 0.08, 0) },
				},
			},
			{
				time = 0.304, -- good foot lands (short step)
				pose = {
					Root = { rot = Vector3.new(-8, 2, -1), pos = Vector3.new(0.02, 0.05, -0.06) },
					Neck = { rot = Vector3.new(4.6, -1.6, 0.7) },
					RightShoulder = { rot = Vector3.new(2, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-10, 0, -5) },
					RightHip = { rot = Vector3.new(-11, 0, 2), pos = Vector3.new(0, 0.03, 0) },
					LeftHip = { rot = Vector3.new(21, 0, 0) },
				},
			},
			{
				time = 0.344, -- falls onto it: the dip
				pose = {
					Root = { rot = Vector3.new(-9, 2, 3), pos = Vector3.new(-0.13, -0.07, -0.03) },
					Neck = { rot = Vector3.new(1.2, -1.6, -2.1) },
					RightShoulder = { rot = Vector3.new(2, 0, 8) },
					LeftShoulder = { rot = Vector3.new(-8, 0, -5) },
					RightHip = { rot = Vector3.new(-14, 0, 2), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(15, 0, 0), pos = Vector3.new(0, 0.14, 0) },
				},
			},
			{
				time = 0.384, -- hurt foot off: hip hike
				pose = {
					Root = { rot = Vector3.new(-8, 1.5, 5), pos = Vector3.new(-0.21, -0.01, 0) },
					Neck = { rot = Vector3.new(4.6, -1.2, -3.5) },
					RightShoulder = { rot = Vector3.new(2, 0, 7) },
					LeftShoulder = { rot = Vector3.new(-5, 0, -5) },
					RightHip = { rot = Vector3.new(-14, 0, 4), pos = Vector3.new(0, 0.15, 0) },
					LeftHip = { rot = Vector3.new(11, 0, 0), pos = Vector3.new(0, 0.1, 0) },
				},
			},
			{
				time = 0.496, -- stiff swing, out to the side
				pose = {
					Root = { rot = Vector3.new(-7, 0.5, 6), pos = Vector3.new(-0.24, 0.09, 0.03) },
					Neck = { rot = Vector3.new(4, -0.4, -4.2) },
					RightShoulder = { rot = Vector3.new(3, 0, 7) },
					LeftShoulder = { rot = Vector3.new(1, 0, -5) },
					RightHip = { rot = Vector3.new(-4, 0, 8), pos = Vector3.new(0, 0.2, 0) },
					LeftHip = { rot = Vector3.new(3, 0, 0), pos = Vector3.new(0, 0.02, 0) },
				},
			},
			{
				time = 0.608, -- highest point
				pose = {
					Root = { rot = Vector3.new(-7, -0.5, 5), pos = Vector3.new(-0.22, 0.13, 0.04) },
					Neck = { rot = Vector3.new(4, 0.4, -3.5) },
					RightShoulder = { rot = Vector3.new(5, 0, 7) },
					LeftShoulder = { rot = Vector3.new(5, 0, -5) },
					RightHip = { rot = Vector3.new(6, 0, 8), pos = Vector3.new(0, 0.12, 0) },
					LeftHip = { rot = Vector3.new(-6, 0, 0) },
				},
			},
			{
				time = 0.712, -- hurt leg reaches, slowly
				pose = {
					Root = { rot = Vector3.new(-7, -1.5, 3), pos = Vector3.new(-0.12, 0.09, 0.03) },
					Neck = { rot = Vector3.new(4, 1.2, -2.1) },
					RightShoulder = { rot = Vector3.new(6, 0, 7) },
					LeftShoulder = { rot = Vector3.new(7, 0, -5) },
					RightHip = { rot = Vector3.new(14, 0, 4), pos = Vector3.new(0, 0.05, 0) },
					LeftHip = { rot = Vector3.new(-13, 0, 0) },
				},
			},
		},
	},
	-- LIMPING, STANDING: weight on the good (left) leg, pelvis over it; the
	-- hurt foot rests lightly on the ground a little forward, knee soft. The
	-- right hand holds the hurt thigh. Now and then the weight tests the hurt
	-- leg, then goes back. LimpIdleLeft is this clip mirrored.
	LimpIdle = {
		length = 4,
		looped = true,
		keyframes = {
			{
				time = 0, -- weight on the good leg
				pose = {
					Root = { rot = Vector3.new(-8, 3, -1.5), pos = Vector3.new(-0.31, -0.06, 0) },
					Neck = { rot = Vector3.new(4.6, -2.4, 1.05) },
					RightShoulder = { rot = Vector3.new(16, -12, -5) },
					LeftShoulder = { rot = Vector3.new(3, 0, -4) },
					RightHip = { rot = Vector3.new(18.53, -8, 15.13), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(8.68, 5, 3.76), pos = Vector3.new(0, 0.02, 0) },
				},
			},
			{
				time = 1, -- breathe in
				pose = {
					Root = { rot = Vector3.new(-6.5, 3, -1.5), pos = Vector3.new(-0.31, -0.04, 0) },
					Neck = { rot = Vector3.new(3.7, -2.4, 1.05) },
					RightShoulder = { rot = Vector3.new(15, -12, -5) },
					LeftShoulder = { rot = Vector3.new(2, 0, -4) },
					RightHip = {
						rot = Vector3.new(16.55, -8, 15.06),
						pos = Vector3.new(0, 0.28, 0),
					},
					LeftHip = { rot = Vector3.new(6.53, 5, 3.67) },
				},
			},
			{
				time = 2, -- breathe out
				pose = {
					Root = { rot = Vector3.new(-8.5, 3, -1.5), pos = Vector3.new(-0.32, -0.07, 0) },
					Neck = { rot = Vector3.new(4.9, -2.4, 1.05) },
					RightShoulder = { rot = Vector3.new(16, -12, -5) },
					LeftShoulder = { rot = Vector3.new(3, 0, -4) },
					RightHip = {
						rot = Vector3.new(19.19, -8, 15.43),
						pos = Vector3.new(0, 0.31, 0),
					},
					LeftHip = { rot = Vector3.new(9.34, 5, 4.07), pos = Vector3.new(0, 0.03, 0) },
				},
			},
			{
				time = 2.48, -- tests the hurt leg...
				pose = {
					Root = { rot = Vector3.new(-8, 2, -2.5), pos = Vector3.new(-0.18, -0.08, 0) },
					Neck = { rot = Vector3.new(4.6, -1.6, 1.75) },
					RightShoulder = { rot = Vector3.new(17, -12, -5) },
					LeftShoulder = { rot = Vector3.new(2, 0, -5) },
					RightHip = { rot = Vector3.new(18.82, -8, 12.27), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(8.63, 5, 1.04), pos = Vector3.new(0, 0.06, 0) },
				},
			},
			{
				time = 2.76, -- ...it hurts: wince
				pose = {
					Root = { rot = Vector3.new(-10, 1, -4), pos = Vector3.new(-0.05, -0.11, 0) },
					Neck = { rot = Vector3.new(-0.2, 3.2, 2.8) },
					RightShoulder = { rot = Vector3.new(21, -12, -6) },
					LeftShoulder = { rot = Vector3.new(4, 0, -8) },
					RightHip = { rot = Vector3.new(21.82, -8, 10.32), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(11.09, 5, -0.66), pos = Vector3.new(0, 0.11, 0) },
				},
			},
			{
				time = 3.08, -- back onto the good leg
				pose = {
					Root = { rot = Vector3.new(-8, 3.5, -0.5), pos = Vector3.new(-0.37, -0.06, 0) },
					Neck = { rot = Vector3.new(4.6, -2.8, 0.35) },
					RightShoulder = { rot = Vector3.new(16, -12, -5) },
					LeftShoulder = { rot = Vector3.new(3, 0, -5) },
					RightHip = { rot = Vector3.new(18.21, -8, 15.59), pos = Vector3.new(0, 0.3, 0) },
					LeftHip = { rot = Vector3.new(8.64, 5, 4.04), pos = Vector3.new(0, 0.04, 0) },
				},
			},
			{
				time = 3.52,
				pose = {
					Root = { rot = Vector3.new(-7.5, 3, -1.5), pos = Vector3.new(-0.3, -0.05, 0) },
					Neck = { rot = Vector3.new(4.3, -2.4, 1.05) },
					RightShoulder = { rot = Vector3.new(16, -12, -5) },
					LeftShoulder = { rot = Vector3.new(3, 0, -4) },
					RightHip = {
						rot = Vector3.new(17.87, -8, 14.83),
						pos = Vector3.new(0, 0.29, 0),
					},
					LeftHip = { rot = Vector3.new(8.02, 5, 3.44), pos = Vector3.new(0, 0.01, 0) },
				},
			},
		},
	},
	-- END injuries
}

-- The same clip for the other side: right and left swapped (a mirror
-- across the body's middle: X angles kept, Y / Z angles and X offsets flipped).
local MIRRORED_JOINT: { [string]: string } = {
	RightShoulder = "LeftShoulder",
	LeftShoulder = "RightShoulder",
	RightHip = "LeftHip",
	LeftHip = "RightHip",
}
local function mirror(clip: R6Pose.Clip): R6Pose.Clip
	local keyframes: { R6Pose.Keyframe } = {}
	for _, keyframe in clip.keyframes do
		local pose: { [string]: R6Pose.JointPose } = {}
		for joint, jointPose in keyframe.pose do
			local rot, pos = jointPose.rot, jointPose.pos
			pose[MIRRORED_JOINT[joint] or joint] = {
				rot = Vector3.new(rot.X, -rot.Y, -rot.Z),
				pos = if pos then Vector3.new(-pos.X, pos.Y, pos.Z) else nil,
			}
		end
		table.insert(keyframes, { time = keyframe.time, pose = pose, tangent = keyframe.tangent })
	end
	return {
		length = clip.length,
		looped = clip.looped,
		additive = clip.additive,
		keyframes = keyframes,
	}
end

-- The limp clips are written for a hurt RIGHT leg; these are for the left.
clips.LimpWalkLeft = mirror(clips.LimpWalk)
clips.LimpIdleLeft = mirror(clips.LimpIdle)

return table.freeze(clips)
