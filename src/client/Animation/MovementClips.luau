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
-- Joints not listed in a clip keep Roblox's own animation (walk, idle...).
--
-- The poses were checked with a side/front preview of the R6 rig: feet stay
-- on the ground, nothing sinks into it. To tweak one: change the numbers,
-- Rojo syncs, press Play.

local R6Pose = require(script.Parent.R6Pose)

local clips: { [string]: R6Pose.Clip } = {
	-- Low guard stance (lead foot = left), slow breathing.
	CrouchIdle = {
		length = 2.4,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-18, 0, 0), pos = Vector3.new(0, -0.6, 0) },
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(55, 0, -35) },
					LeftShoulder = { rot = Vector3.new(65, 0, 35) },
					RightHip = { rot = Vector3.new(-43.1, 0, 6) },
					LeftHip = { rot = Vector3.new(79.1, 0, -6) },
				},
			},
			{
				time = 1.2,
				pose = {
					Root = { rot = Vector3.new(-16, 0, 0), pos = Vector3.new(0, -0.54, 0) },
					Neck = { rot = Vector3.new(12, 0, 0) },
					RightShoulder = { rot = Vector3.new(58, 0, -33) },
					LeftShoulder = { rot = Vector3.new(68, 0, 33) },
					RightHip = { rot = Vector3.new(-43.1, 0, 6) },
					LeftHip = { rot = Vector3.new(79.1, 0, -6) },
				},
			},
		},
	},

	-- Crouched shuffle: the front foot steps, the back foot catches up.
	-- R6 legs have no knees: crossing them would sink a foot into the ground,
	-- so the stance is kept (checked: no foot ever goes under the ground).
	-- Length = one cycle at Config.Character.CROUCH_SPEED; plays faster/slower with the real speed.
	CrouchWalk = {
		length = 0.9,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-18, 0, 0), pos = Vector3.new(0, -0.6, 0) },
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(55, 0, -35) },
					LeftShoulder = { rot = Vector3.new(65, 0, 35) },
					RightHip = { rot = Vector3.new(-43.1, 0, 6) },
					LeftHip = { rot = Vector3.new(79.1, 0, -6) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(-18, -5, 0), pos = Vector3.new(0, -0.6, 0) },
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(50, 0, -35) },
					LeftShoulder = { rot = Vector3.new(72, 0, 35) },
					RightHip = { rot = Vector3.new(-43.1, 0, 6) },
					LeftHip = { rot = Vector3.new(94, 0, -6) },
				},
			},
			{
				time = 0.6,
				pose = {
					Root = { rot = Vector3.new(-18, 3, 0), pos = Vector3.new(0, -0.41, 0) },
					Neck = { rot = Vector3.new(14, 0, 0) },
					RightShoulder = { rot = Vector3.new(60, 0, -35) },
					LeftShoulder = { rot = Vector3.new(60, 0, 35) },
					RightHip = { rot = Vector3.new(-36, 0, 6) },
					LeftHip = { rot = Vector3.new(79.1, 0, -6) },
				},
			},
		},
	},

	-- Leaning back, legs forward along the ground, trailing hand near the
	-- ground, lead arm up for balance, eyes looking ahead.
	Slide = {
		length = 0.6,
		looped = true,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(50, 0, 6), pos = Vector3.new(0, -1.6, 0) },
					Neck = { rot = Vector3.new(-40, 0, 0) },
					RightShoulder = { rot = Vector3.new(-100, 0, 25) },
					LeftShoulder = { rot = Vector3.new(80, 0, 25) },
					RightHip = { rot = Vector3.new(32.1, 0, 8) },
					LeftHip = { rot = Vector3.new(36, -10, -14) },
				},
			},
			{
				time = 0.3,
				pose = {
					Root = { rot = Vector3.new(48, 0, 5), pos = Vector3.new(0, -1.5, 0) },
					Neck = { rot = Vector3.new(-38, 0, 0) },
					RightShoulder = { rot = Vector3.new(-100, 0, 25) },
					LeftShoulder = { rot = Vector3.new(84, 0, 22) },
					RightHip = { rot = Vector3.new(32.1, 0, 8) },
					LeftHip = { rot = Vector3.new(36, -10, -14) },
				},
			},
		},
	},

	-- 0.5 s, same as Config.Climb.DURATION: reach → pull (knee up) → push → stand.
	Climb = {
		length = 0.5,
		looped = false,
		keyframes = {
			{
				time = 0,
				pose = {
					Root = { rot = Vector3.new(-8, 0, 0) },
					Neck = { rot = Vector3.new(18, 0, 0) },
					RightShoulder = { rot = Vector3.new(165, 0, -8) },
					LeftShoulder = { rot = Vector3.new(160, 0, 8) },
					RightHip = { rot = Vector3.new(12, 0, 0) },
					LeftHip = { rot = Vector3.new(-12, 0, 0) },
				},
			},
			{
				time = 0.18,
				pose = {
					Root = { rot = Vector3.new(-28, 0, 0) },
					Neck = { rot = Vector3.new(20, 0, 0) },
					RightShoulder = { rot = Vector3.new(105, 0, -12) },
					LeftShoulder = { rot = Vector3.new(110, 0, 12) },
					RightHip = { rot = Vector3.new(80, 0, 4) },
					LeftHip = { rot = Vector3.new(-18, 0, 0) },
				},
			},
			{
				time = 0.34,
				pose = {
					Root = { rot = Vector3.new(-32, 0, 0) },
					Neck = { rot = Vector3.new(22, 0, 0) },
					RightShoulder = { rot = Vector3.new(35, 0, -15) },
					LeftShoulder = { rot = Vector3.new(40, 0, 15) },
					RightHip = { rot = Vector3.new(40, 0, 4) },
					LeftHip = { rot = Vector3.new(55, 0, -4) },
				},
			},
			{
				time = 0.5,
				pose = {
					Root = { rot = Vector3.new(-6, 0, 0) },
					Neck = { rot = Vector3.new(4, 0, 0) },
					RightShoulder = { rot = Vector3.new(8, 0, 0) },
					LeftShoulder = { rot = Vector3.new(8, 0, 0) },
					RightHip = { rot = Vector3.new(4, 0, 0) },
					LeftHip = { rot = Vector3.new(-4, 0, 0) },
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
