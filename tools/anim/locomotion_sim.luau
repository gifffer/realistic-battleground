-- Runs the REAL Animation/Locomotion code outside Studio (Lune) through a
-- scripted course (start, walk, turns, strafes, reversals, sprint, stops) and
-- prints the largest joint motion per frame of each part: the fluidity check.
-- From the repo root:  lune run tools/anim/locomotion_sim.luau [/tmp/out]
-- (writes out.csv: amplitude, phase, direction, lean, steps per frame; and
-- out.json: every frame's pose, to render with Blender)
local process = require("@lune/process")
local h = require("./lune_harness")
local fs = require("@lune/fs")
local CFrame, Vector3 = h.roblox.CFrame, h.roblox.Vector3
local Locomotion = h.load("client/Animation/Locomotion")

local FPS = 60
local dt = 1 / FPS
local root = { CFrame = CFrame.new(0, 3, 0), AssemblyLinearVelocity = Vector3.zero }
local state = Locomotion.new()
state.idleTime = 0
local yaw, targetYaw = 0, 0
local vel = Vector3.zero
local events = {}
-- scenario: {time, desired world velocity function, target yaw (deg) or nil = face move (autorotate), label}
local function dirFromYaw(y, fwd, right)
	local f = Vector3.new(-math.sin(y), 0, -math.cos(y))
	local r = Vector3.new(math.cos(y), 0, -math.sin(y))
	return f * fwd + r * right
end
local SEG = {
	{ 0, "idle", 0, 0, nil },
	{ 0.6, "walk fwd", 10, 0, nil },
	{ 2.6, "turn 90 right (autorotate)", 10, 0, -90 },
	{ 3.6, "shoulder: strafe right", 0, 10, nil },
	{ 4.6, "shoulder: strafe left (reversal)", 0, -10, nil },
	{ 5.6, "shoulder: backpedal", -10, 0, nil },
	{ 6.6, "shoulder: forward", 10, 0, nil },
	{ 7.2, "sprint", 22, 0, nil },
	{ 8.8, "stop from sprint", 0, 0, nil },
	{ 9.8, "walk", 10, 0, nil },
	{ 10.8, "W->S reversal", -10, 0, nil },
	{ 11.6, "stop", 0, 0, nil },
	{ 12.4, "turn 180 standing (camera)", 0, 0, 90 },
	{ 13.4, "slow walk (blocking)", 4, 0, nil },
	{ 14.6, "crouch walk", 8, 0, nil, true },
	{ 15.8, "crouch strafe left", 0, -8, nil, true },
	{ 16.8, "crouch stop", 0, 0, nil, true },
	{ 17.6, "end", 0, 0, nil },
}
local out = {}
local prev = {}
local maxStep = {}
local pose = {}
local seg = 1
local lines = { "t,seg,amp,phase,speed,sprint,angle,lag,pitch,roll,step,maxdeg" }
local t = 0
while t < 17.6 do
	while SEG[seg + 1] and t >= SEG[seg + 1][1] do
		seg += 1
		local s = SEG[seg]
		if s[5] then
			targetYaw = math.rad(s[5])
		end
	end
	local s = SEG[seg]
	-- root yaw: turns at ~2300 deg/s toward target (AutoRotate / camera)
	local d = (targetYaw - yaw)
	local maxTurn = math.rad(2300) * dt
	yaw += math.clamp(d, -maxTurn, maxTurn)
	-- velocity: relative to the (root) facing at segment start for shoulder segs
	local desired = dirFromYaw(yaw, s[3], s[4])
	-- humanoid acceleration: reaches target in ~0.1 s
	local diff = desired - vel
	local acc = 120 * dt
	if diff.Magnitude > acc then
		diff = diff.Unit * acc
	end
	vel += diff
	local pos = root.CFrame.Position + vel * dt
	root.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	root.AssemblyLinearVelocity = vel
	Locomotion.update(state, root, true, false, s[6] == true, dt)
	Locomotion.sample(state, pose)
	-- lag on the root, like the controller
	pose.Root = CFrame.Angles(0, yaw + state.lag, 0) * pose.Root
	local worst = 0
	for joint, cf in pose do
		if prev[joint] then
			local _, angle = (prev[joint]:Inverse() * cf):ToAxisAngle()
			angle = math.deg(angle)
			if angle > 180 then angle = 360 - angle end
			worst = math.max(worst, angle)
			if angle > (maxStep[s[2]] or 0) then
				maxStep[s[2]] = angle
			end
		end
		prev[joint] = cf
	end
	local stepText = ""
	for _, st in state.steps do
		stepText ..= st.foot .. (if st.scuff then "*" else "") .. " "
	end
	table.insert(lines, string.format("%.3f,%s,%.3f,%.3f,%.2f,%.2f,%.1f,%.1f,%.2f,%.2f,%s,%.1f", t, s[2], state.amp, state.phase, state.speed, state.sprint, math.deg(state.angle), math.deg(state.lag), state.pitch, state.roll, stepText, worst))
	-- export pose for rendering
	local row = { t = t, yaw = yaw, x = pos.X, z = pos.Z }
	for joint, cf in pose do
		row[joint] = { cf:GetComponents() }
	end
	table.insert(out, row)
	t += dt
end
fs.writeFile((process.args[1] or "/tmp/locomotion") .. ".csv", table.concat(lines, "\n"))
local serde = require("@lune/serde")
fs.writeFile((process.args[1] or "/tmp/locomotion") .. ".json", serde.encode("json", out))
for _, s in SEG do
	if maxStep[s[2]] then
		print(string.format("%-34s max %.1f deg/frame @60fps (= %.1f @30)", s[2], maxStep[s[2]], maxStep[s[2]] * 2))
	end
end
