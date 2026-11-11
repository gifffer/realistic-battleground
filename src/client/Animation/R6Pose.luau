--!strict
-- R6Pose: the math behind our code-made animations.
--
-- An R6 character is 6 parts held together by 6 Motor6D joints:
--   Root (HumanoidRootPart → Torso), Neck, Right/Left Shoulder, Right/Left Hip.
-- Each frame, Roblox's Animator writes Motor6D.Transform (the joint's current
-- rotation). We write our own Transform right after it to pose the body.
--
-- Poses are written in a human-friendly way (see MovementClips): degrees,
-- in the PARENT part's space. Roblox's joints have their own, rotated axes
-- (Motor6D.C0), so toTransform() converts:   T = C0rot⁻¹ · pose · C0rot

export type JointPose = {
	rot: Vector3, -- degrees (X, Y, Z), applied like CFrame.Angles
	pos: Vector3?, -- studs, optional
}

export type Keyframe = {
	time: number, -- seconds from the start of the clip
	pose: { [string]: JointPose }, -- joint name (see JOINTS) → pose
}

export type Clip = {
	length: number, -- seconds
	looped: boolean,
	-- true = added ON TOP of Roblox's animation (e.g. a lean while running)
	-- instead of replacing it.
	additive: boolean?,
	keyframes: { Keyframe },
}

-- A clip turned into ready-to-use CFrames (done once per clip).
type Compiled = {
	times: { number },
	frames: { { [string]: CFrame } },
	joints: { string }, -- every joint used by the clip
}

local R6Pose = {}

-- Our joint names → (part that holds the Motor6D, Motor6D name) in an R6 character.
local JOINTS: { [string]: { string } } = {
	Root = { "HumanoidRootPart", "RootJoint" },
	Neck = { "Torso", "Neck" },
	RightShoulder = { "Torso", "Right Shoulder" },
	LeftShoulder = { "Torso", "Left Shoulder" },
	RightHip = { "Torso", "Right Hip" },
	LeftHip = { "Torso", "Left Hip" },
}
R6Pose.JOINTS = table.freeze(JOINTS)

local compiledCache: { [Clip]: Compiled } = setmetatable({}, { __mode = "k" }) :: any

local function toLocalCFrame(jointPose: JointPose): CFrame
	local r = jointPose.rot
	local offset = jointPose.pos or Vector3.zero
	return CFrame.new(offset) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
end

local function compile(clip: Clip): Compiled
	local cached = compiledCache[clip]
	if cached then
		return cached
	end
	local compiled: Compiled = { times = {}, frames = {}, joints = {} }
	local seen: { [string]: boolean } = {}
	for _, keyframe in clip.keyframes do
		local frame: { [string]: CFrame } = {}
		for joint, jointPose in keyframe.pose do
			frame[joint] = toLocalCFrame(jointPose)
			if not seen[joint] then
				seen[joint] = true
				table.insert(compiled.joints, joint)
			end
		end
		table.insert(compiled.times, keyframe.time)
		table.insert(compiled.frames, frame)
	end
	compiledCache[clip] = compiled
	return compiled
end

-- "Smoothstep": slow in, slow out. Makes keyframe transitions organic.
local function ease(alpha: number): number
	return alpha * alpha * (3 - 2 * alpha)
end

-- The pose of `clip` at `time` (seconds), written into `out` (reused every
-- frame to avoid creating tables): joint name → CFrame in parent space.
-- Looped clips wrap around; others hold their last keyframe.
function R6Pose.sample(clip: Clip, time: number, out: { [string]: CFrame })
	table.clear(out)
	local compiled = compile(clip)
	local times, frames = compiled.times, compiled.frames
	local count = #times
	if count == 0 then
		return
	end

	local t = if clip.looped then time % clip.length else math.clamp(time, 0, clip.length)

	-- Find the two keyframes around `t`. After the last one, a looped clip
	-- blends back to the first (at time = length).
	local fromIndex = count
	for i = 1, count do
		if times[i] > t then
			fromIndex = i - 1
			break
		end
	end

	local fromFrame, toFrame, fromTime, toTime
	if fromIndex == 0 then
		-- Before the first keyframe: hold it.
		fromFrame, toFrame, fromTime, toTime = frames[1], frames[1], 0, 1
	elseif fromIndex == count then
		if clip.looped and count > 1 then
			fromFrame, toFrame = frames[count], frames[1]
			fromTime, toTime = times[count], clip.length + times[1]
		else
			fromFrame, toFrame, fromTime, toTime = frames[count], frames[count], 0, 1
		end
	else
		fromFrame, toFrame = frames[fromIndex], frames[fromIndex + 1]
		fromTime, toTime = times[fromIndex], times[fromIndex + 1]
	end

	local span = toTime - fromTime
	local alpha = if span > 0 then ease(math.clamp((t - fromTime) / span, 0, 1)) else 0

	for _, joint in compiled.joints do
		local a = fromFrame[joint] or CFrame.identity
		local b = toFrame[joint] or CFrame.identity
		out[joint] = a:Lerp(b, alpha)
	end
end

-- Converts a pose (parent space) into the value to write in motor.Transform.
function R6Pose.toTransform(motor: Motor6D, localCFrame: CFrame): CFrame
	local axes = motor.C0.Rotation
	return axes:Inverse() * localCFrame * axes
end

-- The 6 Motor6D of an R6 character, or nil if one is missing (not R6,
-- still loading, or broken by a ragdoll).
function R6Pose.findMotors(character: Model): { [string]: Motor6D }?
	local motors: { [string]: Motor6D } = {}
	for joint, path in JOINTS do
		local part = character:FindFirstChild(path[1])
		local motor = part and part:FindFirstChild(path[2])
		if motor == nil or not motor:IsA("Motor6D") then
			return nil
		end
		motors[joint] = motor
	end
	return motors
end

return R6Pose
