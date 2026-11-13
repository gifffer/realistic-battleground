--!strict
-- TrainPath: where the city's train is at a given moment, worked out from a few numbers.
-- Used by the server (hits: Server/Systems/Train) and by every client (drawing:
-- Client/Controllers/TrainController), so both always agree.
--
-- The track: a straight line between TrainA and TrainB (attributes of Workspace > City,
-- given by the city data). Both points are on the rail top, each one inside a tunnel portal
-- in the ring wall at an end of the viaduct.
--
-- A pass (attributes of Workspace > City, set by the server):
--   TrainWarnAt     server time the warning starts (signals blink, horn, rumble)
--   TrainPassStart  server time the locomotive's NOSE passes its start point (TrainA or
--                   TrainB: 40 studs deep in the tunnel, so it comes out ~0.6 s later)
--   TrainDir        1 = from A to B, -1 = from B to A
--   TrainSpeed      studs per second
--   TrainLength     studs, from the nose to the back of the last car
-- "Server time" = workspace:GetServerTimeNow() (the same clock on the server and clients).
--
-- Along the track, distances are measured from the portal the train comes OUT of:
--   nose(t) = speed × (t − passStart)          (negative = still in the tunnel)
--   the train covers [nose − length, nose]
--   the pass is over when the back of the train reaches the other portal:
--   passEnd = passStart + (trackLength + length) / speed

local TrainPath = {}

export type Track = {
	a: Vector3,
	b: Vector3,
	laneWidth: number,
}

export type Pass = {
	warnAt: number,
	start: number,
	dir: number,
	speed: number,
	length: number,
}

-- Where the train runs: the portal it comes out of, the unit direction it goes in, the
-- track's length and the flat unit vector to the train's right.
export type Frame = {
	origin: Vector3,
	axis: Vector3,
	trackLength: number,
	right: Vector3,
}

-- The track from the city's attributes, or nil if the city has no train.
function TrainPath.readTrack(city: Instance): Track?
	local a = city:GetAttribute("TrainA")
	local b = city:GetAttribute("TrainB")
	local width = city:GetAttribute("TrainLaneWidth")
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" or (b - a).Magnitude < 10 then
		return nil
	end
	return { a = a, b = b, laneWidth = if typeof(width) == "number" then width else 10 }
end

-- The current (or last) pass from the city's attributes, or nil if there was none yet.
function TrainPath.readPass(city: Instance): Pass?
	local warnAt = city:GetAttribute("TrainWarnAt")
	local start = city:GetAttribute("TrainPassStart")
	local dir = city:GetAttribute("TrainDir")
	local speed = city:GetAttribute("TrainSpeed")
	local length = city:GetAttribute("TrainLength")
	if
		typeof(warnAt) ~= "number"
		or typeof(start) ~= "number"
		or typeof(dir) ~= "number"
		or typeof(speed) ~= "number"
		or typeof(length) ~= "number"
		or speed <= 0
	then
		return nil
	end
	return {
		warnAt = warnAt,
		start = start,
		dir = if dir < 0 then -1 else 1,
		speed = speed,
		length = length,
	}
end

function TrainPath.frame(track: Track, dir: number): Frame
	local origin = if dir < 0 then track.b else track.a
	local target = if dir < 0 then track.a else track.b
	local axis = (target - origin).Unit
	local flat = Vector3.new(axis.X, 0, axis.Z)
	local right = if flat.Magnitude > 1e-3 then flat.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
	return { origin = origin, axis = axis, trackLength = (target - origin).Magnitude, right = right }
end

-- Distance of the nose from the portal it came out of, at server time `time`.
function TrainPath.nose(pass: Pass, time: number): number
	return pass.speed * (time - pass.start)
end

-- Server time the back of the train goes into the far portal.
function TrainPath.passEnd(track: Track, pass: Pass): number
	return pass.start + ((track.b - track.a).Magnitude + pass.length) / pass.speed
end

return TrainPath
