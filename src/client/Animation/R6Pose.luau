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
	-- How the motion goes through this keyframe:
	--   "smooth" (default): it passes THROUGH without stopping (fluid motion),
	--   "flat": it comes to rest on it (a hold, or a hard stop).
	-- The first and last keyframes of a non-looped clip are always "flat".
	tangent: ("smooth" | "flat")?,
}

export type Clip = {
	length: number, -- seconds
	looped: boolean,
	-- true = added ON TOP of Roblox's animation (e.g. a lean while running)
	-- instead of replacing it.
	additive: boolean?,
	keyframes: { Keyframe },
}

-- One joint of a clip, ready for fast sampling (done once per clip):
-- value and speed ("tangent") of its rotation and position at every keyframe.
type Track = {
	rot: { Vector3 },
	pos: { Vector3 },
	rotTangent: { Vector3 }, -- degrees per second
	posTangent: { Vector3 }, -- studs per second
}

type Compiled = {
	times: { number },
	joints: { string }, -- every joint used by the clip
	tracks: { [string]: Track },
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

-- Interpolation: a cubic "Hermite" spline through the keyframes.
--
-- Plain blending between two poses makes the body slow down and stop at
-- EVERY keyframe (robotic). A spline also knows the SPEED at each keyframe,
-- so the motion flows through them like a real movement.
--
-- Speed at a "smooth" keyframe = slope between its two neighbours
-- (value after − value before) / (time after − time before).
-- Speed at a "flat" keyframe = 0.
local function computeTangents(
	values: { Vector3 },
	times: { number },
	keyframes: { Keyframe },
	clip: Clip
): { Vector3 }
	local count = #values
	local tangents = table.create(count, Vector3.zero)
	for index = 1, count do
		local isEnd = not clip.looped and (index == 1 or index == count)
		if keyframes[index].tangent == "flat" or isEnd or count < 2 then
			continue
		end
		-- Neighbours; a looped clip wraps around (the key before the first
		-- one is the last one, one clip-length earlier).
		local before, beforeTime = index - 1, 0
		local after, afterTime = index + 1, 0
		if before < 1 then
			before, beforeTime = count, -clip.length
		end
		if after > count then
			after, afterTime = 1, clip.length
		end
		local span = (times[after] + afterTime) - (times[before] + beforeTime)
		if span > 0 then
			tangents[index] = (values[after] - values[before]) / span
		end
	end
	return tangents
end

local function compile(clip: Clip): Compiled
	local cached = compiledCache[clip]
	if cached then
		return cached
	end
	local keyframes = clip.keyframes
	local compiled: Compiled = { times = {}, joints = {}, tracks = {} }
	for _, keyframe in keyframes do
		table.insert(compiled.times, keyframe.time)
		for joint in keyframe.pose do
			if compiled.tracks[joint] == nil then
				compiled.tracks[joint] = { rot = {}, pos = {}, rotTangent = {}, posTangent = {} }
				table.insert(compiled.joints, joint)
			end
		end
	end
	for _, joint in compiled.joints do
		local track = compiled.tracks[joint]
		for index, keyframe in keyframes do
			-- A joint missing from a keyframe is at rest there (zero).
			local jointPose = keyframe.pose[joint]
			track.rot[index] = if jointPose then jointPose.rot else Vector3.zero
			track.pos[index] = if jointPose and jointPose.pos then jointPose.pos else Vector3.zero
		end
		track.rotTangent = computeTangents(track.rot, compiled.times, keyframes, clip)
		track.posTangent = computeTangents(track.pos, compiled.times, keyframes, clip)
	end
	compiledCache[clip] = compiled
	return compiled
end

local function toCFrame(rot: Vector3, pos: Vector3): CFrame
	return CFrame.new(pos) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
end

-- The pose of `clip` at `time` (seconds), written into `out` (reused every
-- frame to avoid creating tables): joint name → CFrame in parent space.
-- Looped clips wrap around; others hold their first / last keyframe.
function R6Pose.sample(clip: Clip, time: number, out: { [string]: CFrame })
	table.clear(out)
	local compiled = compile(clip)
	local times = compiled.times
	local count = #times
	if count == 0 then
		return
	end

	local looped = clip.looped
	local length = clip.length
	local t = if looped then time % length else math.clamp(time, 0, length)

	-- The two keyframes around `t`: `from` and `to`, with their times.
	-- (For a looped clip, after the last key we head back to the first one.)
	local from = count
	for index = 1, count do
		if times[index] > t then
			from = index - 1
			break
		end
	end
	local to = from + 1
	local fromTime, toTime
	if from < 1 then
		if looped then
			from, to = count, 1
			fromTime, toTime = times[count] - length, times[1]
		else
			from, to = 1, 1 -- before the first keyframe: hold it
			fromTime, toTime = 0, 0
		end
	elseif from >= count then
		if looped then
			from, to = count, 1
			fromTime, toTime = times[count], times[1] + length
		else
			from, to = count, count -- after the last keyframe: hold it
			fromTime, toTime = 0, 0
		end
	else
		fromTime, toTime = times[from], times[to]
	end

	local span = toTime - fromTime
	local u = if span > 0 then math.clamp((t - fromTime) / span, 0, 1) else 0
	-- Hermite basis: how much of each value / tangent at this point.
	local u2, u3 = u * u, u * u * u
	local h00 = 2 * u3 - 3 * u2 + 1
	local h10 = (u3 - 2 * u2 + u) * span
	local h01 = -2 * u3 + 3 * u2
	local h11 = (u3 - u2) * span

	for _, joint in compiled.joints do
		local track = compiled.tracks[joint]
		local rot = track.rot[from] * h00
			+ track.rotTangent[from] * h10
			+ track.rot[to] * h01
			+ track.rotTangent[to] * h11
		local pos = track.pos[from] * h00
			+ track.posTangent[from] * h10
			+ track.pos[to] * h01
			+ track.posTangent[to] * h11
		out[joint] = toCFrame(rot, pos)
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
