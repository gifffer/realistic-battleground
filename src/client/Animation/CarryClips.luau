--!strict
-- CarryClips: how a fighter carries the BX-7 case in the LEFT hand (BRIEFCASE §4, PLAN §7.6).
-- Poses are R6Pose poses: degrees, in the parent part's space. For the left arm,
-- rot.X > 0 = the arm swings forward, rot.Z < 0 = the arm moves away from the body.
--
-- Two kinds of things here:
--   • "CaseSetDown": a normal one-shot action clip (0.5 s) that
--     CharacterAnimationController.playAction can play: a quick crouch (the ALS crouch pose),
--     the hand goes down to the floor and comes back up.
--   • The HOLD: not a clip but a few pose functions, used every frame by CaseController
--     through CharacterAnimationController.setHoldPose (an overlay on the Left Shoulder and a
--     small torso tilt, on top of everything else the body does):
--       - the arm hangs straight, 7° out (the case clears the leg), and swings only a little
--         with the steps (±6° walking, ±12° sprinting) instead of the normal arm swing;
--       - the torso leans 1.5° AWAY from the case (a heavy bag in one hand: the trunk
--         counters it) and the loaded shoulder drops 0.06 stud;
--       - every 6–10 s a small grip shift (0.4 s to a slightly different hold and back);
--       - "present": while selling, the arm comes up and forward so the case lies flat in
--         front of the hip, lid up, and opens (CaseController moves the case itself).

local R6Pose = require(script.Parent.R6Pose)

local CarryClips = {}

-- The hold (degrees).
CarryClips.HOLD_SHOULDER = Vector3.new(0, 0, -7)
CarryClips.GRIP_SHIFT_SHOULDER = Vector3.new(4, 0, -9)
-- Torso roll (degrees): negative = away from the case (to the right).
CarryClips.ROOT_ROLL = -1.5
-- The loaded (left) shoulder drops this much (studs).
CarryClips.SHOULDER_DROP = 0.06
-- Arm swing with the steps (degrees, each way): walking, sprinting.
CarryClips.SWING_WALK = 6
CarryClips.SWING_SPRINT = 12
-- Grip shift: every GRIP_EVERY_MIN..MAX seconds, GRIP_BLEND seconds there and back.
CarryClips.GRIP_EVERY_MIN = 6
CarryClips.GRIP_EVERY_MAX = 10
CarryClips.GRIP_BLEND = 0.4
-- Selling: the arm brought up and forward (the case lies flat in front of the hip).
CarryClips.PRESENT_SHOULDER = Vector3.new(40, 0, 20)
-- Where the case is then, in the TORSO's space: centre in front of the left hip, lid up,
-- handle toward the body (so the lid opens away from the player and the camera behind him
-- looks inside).
CarryClips.PRESENT_CASE =
	CFrame.fromMatrix(Vector3.new(-0.8, -0.85, -1.75), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1))

-- Locomotion (Animation/Locomotion) puts the LEFT foot down at phase 7/16 and the right one
-- half a cycle later (15/16). The left arm is most forward when the RIGHT foot is.
local RIGHT_PLANT = 15 / 16

local function angles(rot: Vector3): CFrame
	return CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
end

-- Forward / back swing of the carrying arm (degrees) for the locomotion's phase (0..1),
-- step amplitude (0 standing .. 1 full steps) and sprint weight (0..1).
function CarryClips.armSwing(phase: number, amplitude: number, sprint: number): number
	local size = CarryClips.SWING_WALK + (CarryClips.SWING_SPRINT - CarryClips.SWING_WALK) * sprint
	return size * amplitude * math.cos(2 * math.pi * (phase - RIGHT_PLANT))
end

-- The Left Shoulder's hold pose: `swing` degrees forward, `gripShift` 0..1 toward the
-- shifted grip, `present` 0..1 toward the selling pose.
function CarryClips.holdShoulder(swing: number, gripShift: number, present: number): CFrame
	local hold = CarryClips.HOLD_SHOULDER:Lerp(CarryClips.GRIP_SHIFT_SHOULDER, gripShift)
		+ Vector3.new(swing, 0, 0)
	local drop = Vector3.new(0, -CarryClips.SHOULDER_DROP * (1 - present), 0)
	return CFrame.new(drop) * angles(hold:Lerp(CarryClips.PRESENT_SHOULDER, present))
end

-- The torso's small tilt away from the case (added on top of the Root joint's pose).
function CarryClips.rootTilt(present: number): CFrame
	return CFrame.Angles(0, 0, math.rad(CarryClips.ROOT_ROLL * (1 - present)))
end

-- The set-down clip, from the ALS crouch pose (ALSClips.Crouch): the torso sinks into the
-- legs (Root down, hips up by the same amount: R6 legs have no knees) and leans forward;
-- the left arm stays vertical (−20° against the lean) to put the case on the floor.
local CROUCH: { [string]: R6Pose.JointPose } = {
	Root = { rot = Vector3.new(-21.65, 0, -2), pos = Vector3.new(0, -1.1, -0.1) },
	Neck = { rot = Vector3.new(18.5, 0, 0) },
	RightShoulder = { rot = Vector3.new(25, 0, 3) },
	LeftShoulder = { rot = Vector3.new(-20, 0, -4) },
	RightHip = { rot = Vector3.new(-6.87, 0, -3.69), pos = Vector3.new(0, 1.11, 0) },
	LeftHip = { rot = Vector3.new(27.27, 0, -3.26), pos = Vector3.new(0, 1.2, 0) },
}
local STAND: { [string]: R6Pose.JointPose } = {
	Root = { rot = Vector3.zero, pos = Vector3.zero },
	Neck = { rot = Vector3.zero },
	RightShoulder = { rot = Vector3.zero },
	LeftShoulder = { rot = CarryClips.HOLD_SHOULDER },
	RightHip = { rot = Vector3.zero, pos = Vector3.zero },
	LeftHip = { rot = Vector3.zero, pos = Vector3.zero },
}

CarryClips.CaseSetDown = {
	length = 0.5,
	looped = false,
	keyframes = {
		{ time = 0, pose = STAND },
		{ time = 0.22, pose = CROUCH, tangent = "flat" },
		{ time = 0.3, pose = CROUCH, tangent = "flat" },
		{ time = 0.5, pose = STAND },
	},
} :: R6Pose.Clip

return CarryClips
