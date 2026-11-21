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
--         front of the hip, lid up, and opens (CaseController moves the case itself);
--       - "shield": while blocking, the arm comes up across the chest and the case stands
--         in front of it, lid face out (a heavy aluminium case is the best guard there is).
--     The case always stays in the ARM's space with its handle in the fist (PRESENT_TURN /
--     SHIELD_TURN are its turn in the fist, solved offline for those shoulder angles with
--     the R6 joint math: the case lies flat / stands up in front, clear of the body).
--   • "CasePickUp": the same crouch, the hand closing on the handle at PICK_UP_CONTACT.
--   • SET_DOWN_CONTACT / PICK_UP_CONTACT: the clips' "markers" (seconds): the instant the
--     hand reaches the floor. CaseController lets go of / takes the case exactly then.

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
-- The case's turn in the fist then (arm space, rotation only): it lies flat in front of the
-- left hip (centre ≈ torso (-0.96, -0.68, -1.67)), lid up, handle toward the body, so the
-- lid opens away from the player and the camera behind him looks inside.
CarryClips.PRESENT_TURN = CFrame.fromMatrix(
	Vector3.zero,
	Vector3.new(-0.9397, 0.342, 0),
	Vector3.new(0.2198, 0.604, 0.766)
)
-- Blocking with the case (degrees): the arm comes up forward and across the chest...
CarryClips.SHIELD_SHOULDER = Vector3.new(85, 0, 30)
-- ...and the case stands in front of the chest (centre ≈ torso (-0.69, -0.3, -1.55)), its
-- lid face out, handle up in the fist.
CarryClips.SHIELD_TURN = CFrame.fromMatrix(
	Vector3.zero,
	Vector3.new(-0.866, 0.5, 0),
	Vector3.new(0.0436, 0.0755, -0.9962)
)
-- Shield blend (seconds): up fast (a guard), down slower.
CarryClips.SHIELD_IN = 0.12
CarryClips.SHIELD_OUT = 0.2
-- The hand on the floor (seconds into CaseSetDown / CasePickUp).
CarryClips.SET_DOWN_CONTACT = 0.26
CarryClips.PICK_UP_CONTACT = 0.24

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
-- shifted grip, `present` 0..1 toward the selling pose, `shield` 0..1 toward the block.
function CarryClips.holdShoulder(
	swing: number,
	gripShift: number,
	present: number,
	shield: number?
): CFrame
	local up = shield or 0
	local hold = CarryClips.HOLD_SHOULDER:Lerp(CarryClips.GRIP_SHIFT_SHOULDER, gripShift)
		+ Vector3.new(swing, 0, 0)
	local raised = math.max(present, up)
	local drop = Vector3.new(0, -CarryClips.SHOULDER_DROP * (1 - raised), 0)
	local angle = hold:Lerp(CarryClips.PRESENT_SHOULDER, present)
		:Lerp(CarryClips.SHIELD_SHOULDER, up)
	return CFrame.new(drop) * angles(angle)
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

-- Picking it up: the same crouch, a touch slower on the way up (the weight comes with it).
CarryClips.CasePickUp = {
	length = 0.55,
	looped = false,
	keyframes = {
		{ time = 0, pose = STAND },
		{ time = 0.2, pose = CROUCH, tangent = "flat" },
		{ time = 0.28, pose = CROUCH, tangent = "flat" },
		{ time = 0.55, pose = STAND },
	},
} :: R6Pose.Clip

return CarryClips
