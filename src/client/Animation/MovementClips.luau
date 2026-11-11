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
	-- One knee down (right), left shin upright, torso low, fists up. Slow breathing.
	-- R6 has no knees: the "bent" look comes from MOVING the legs up into the
	-- torso (pos), not only rotating them.
	CrouchIdle = {
		length = 2.6,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-16, 0, 0), pos = Vector3.new(0, -1.35, 0) },
					Neck = { rot = Vector3.new(12, 0, 0) },
					RightShoulder = { rot = Vector3.new(58, 0, -32) },
					LeftShoulder = { rot = Vector3.new(72, 0, 32) },
					RightHip = { rot = Vector3.new(-66, 0, 5), pos = Vector3.new(0, 0.07, 0.1) },
					LeftHip = { rot = Vector3.new(16, 0, -5), pos = Vector3.new(0, 1.7, -0.9) },
				},
			},
			{
				time = 1.3,
				pose = {
					Root = { rot = Vector3.new(-14, 0, 0), pos = Vector3.new(0, -1.3, 0) },
					Neck = { rot = Vector3.new(10, 0, 0) },
					RightShoulder = { rot = Vector3.new(61, 0, -30) },
					LeftShoulder = { rot = Vector3.new(75, 0, 30) },
					RightHip = { rot = Vector3.new(-66, 0, 5), pos = Vector3.new(0, 0.1, 0.1) },
					LeftHip = { rot = Vector3.new(16, 0, -5), pos = Vector3.new(0, 1.63, -0.9) },
				},
			},
		},
	},

	-- Crouched walk: legs alternate; the swinging leg is tucked under the body.
	-- Length = one full cycle (2 steps) at Config.Character.CROUCH_SPEED;
	-- it plays faster / slower with the real speed.
	CrouchWalk = {
		length = 1,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-16, 0, 0), pos = Vector3.new(0, -1.35, 0) },
					Neck = { rot = Vector3.new(12, 0, 0) },
					RightShoulder = { rot = Vector3.new(58, 0, -32) },
					LeftShoulder = { rot = Vector3.new(72, 0, 32) },
					RightHip = { rot = Vector3.new(-66, 0, 5), pos = Vector3.new(0, 0.07, 0.1) },
					LeftHip = { rot = Vector3.new(16, 0, -5), pos = Vector3.new(0, 1.7, -0.9) },
				},
			},
			{
				time = 0.12,
				pose = {
					Root = { rot = Vector3.new(-17, -2, 0), pos = Vector3.new(0, -1.25, 0) },
					Neck = { rot = Vector3.new(12.5, 0, 0) },
					RightShoulder = { rot = Vector3.new(62, 0, -32) },
					LeftShoulder = { rot = Vector3.new(66, 0, 32) },
					RightHip = { rot = Vector3.new(-28, 0, 5), pos = Vector3.new(0, 1.09, -0.05) },
					LeftHip = { rot = Vector3.new(-4.5, 0, -5), pos = Vector3.new(0, 1.55, -0.55) },
				},
			},
			{
				time = 0.25,
				pose = {
					Root = { rot = Vector3.new(-18, -4, 0), pos = Vector3.new(0, -1.15, 0) },
					Neck = { rot = Vector3.new(13, 0, 0) },
					RightShoulder = { rot = Vector3.new(66, 0, -32) },
					LeftShoulder = { rot = Vector3.new(60, 0, 32) },
					RightHip = { rot = Vector3.new(10, 0, 5), pos = Vector3.new(0, 1.6, -0.2) },
					LeftHip = { rot = Vector3.new(-25, 0, -5), pos = Vector3.new(0, 1.08, -0.2) },
				},
			},
			{
				time = 0.38,
				pose = {
					Root = { rot = Vector3.new(-17, -2, 0), pos = Vector3.new(0, -1.25, 0) },
					Neck = { rot = Vector3.new(12.5, 0, 0) },
					RightShoulder = { rot = Vector3.new(69, 0, -32) },
					LeftShoulder = { rot = Vector3.new(59, 0, 32) },
					RightHip = { rot = Vector3.new(13, 0, 5), pos = Vector3.new(0, 1.65, -0.55) },
					LeftHip = { rot = Vector3.new(-45.5, 0, -5), pos = Vector3.new(0, 0.66, -0.05) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-16, 0, 0), pos = Vector3.new(0, -1.35, 0) },
					Neck = { rot = Vector3.new(12, 0, 0) },
					RightShoulder = { rot = Vector3.new(72, 0, -32) },
					LeftShoulder = { rot = Vector3.new(58, 0, 32) },
					RightHip = { rot = Vector3.new(16, 0, 5), pos = Vector3.new(0, 1.7, -0.9) },
					LeftHip = { rot = Vector3.new(-66, 0, -5), pos = Vector3.new(0, 0.07, 0.1) },
				},
			},
			{
				time = 0.62,
				pose = {
					Root = { rot = Vector3.new(-17, 2, 0), pos = Vector3.new(0, -1.25, 0) },
					Neck = { rot = Vector3.new(12.5, 0, 0) },
					RightShoulder = { rot = Vector3.new(66, 0, -32) },
					LeftShoulder = { rot = Vector3.new(62, 0, 32) },
					RightHip = { rot = Vector3.new(-4.5, 0, 5), pos = Vector3.new(0, 1.55, -0.55) },
					LeftHip = { rot = Vector3.new(-28, 0, -5), pos = Vector3.new(0, 1.09, -0.05) },
				},
			},
			{
				time = 0.75,
				pose = {
					Root = { rot = Vector3.new(-18, 4, 0), pos = Vector3.new(0, -1.15, 0) },
					Neck = { rot = Vector3.new(13, 0, 0) },
					RightShoulder = { rot = Vector3.new(60, 0, -32) },
					LeftShoulder = { rot = Vector3.new(66, 0, 32) },
					RightHip = { rot = Vector3.new(-25, 0, 5), pos = Vector3.new(0, 1.08, -0.2) },
					LeftHip = { rot = Vector3.new(10, 0, -5), pos = Vector3.new(0, 1.6, -0.2) },
				},
			},
			{
				time = 0.88,
				pose = {
					Root = { rot = Vector3.new(-17, 2, 0), pos = Vector3.new(0, -1.25, 0) },
					Neck = { rot = Vector3.new(12.5, 0, 0) },
					RightShoulder = { rot = Vector3.new(59, 0, -32) },
					LeftShoulder = { rot = Vector3.new(69, 0, 32) },
					RightHip = { rot = Vector3.new(-45.5, 0, 5), pos = Vector3.new(0, 0.66, -0.05) },
					LeftHip = { rot = Vector3.new(13, 0, -5), pos = Vector3.new(0, 1.65, -0.55) },
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
}

return table.freeze(clips)
