--!strict
-- Spring: critically damped springs, set by their "half-life" (seconds for
-- half of the remaining distance to be covered). They follow a target
-- smoothly, without overshooting it and without a jump in speed: what makes a
-- lean, a turn or a fade feel physical instead of linear / robotic.
-- (Exact solution of the spring for any frame time, so a lag spike can't make
-- it explode. After Daniel Holden, "Spring-It-On".)

local Spring = {}

local LN2 = 0.69314718056

-- One step of a critically damped spring for a number: returns the new
-- value and speed.
function Spring.step(
	value: number,
	speed: number,
	target: number,
	halflife: number,
	dt: number
): (number, number)
	local y = 2 * LN2 / math.max(halflife, 1e-5)
	local j0 = value - target
	local j1 = speed + j0 * y
	local decay = math.exp(-y * dt)
	return decay * (j0 + j1 * dt) + target, decay * (speed - j1 * y * dt)
end

-- The same, for a Vector3 (each axis on its own).
function Spring.step3(
	value: Vector3,
	speed: Vector3,
	target: Vector3,
	halflife: number,
	dt: number
): (Vector3, Vector3)
	local y = 2 * LN2 / math.max(halflife, 1e-5)
	local j0 = value - target
	local j1 = speed + j0 * y
	local decay = math.exp(-y * dt)
	return (j0 + j1 * dt) * decay + target, (speed - j1 * (y * dt)) * decay
end

-- How much of a gap is left after `dt` when it decays with this half-life
-- (for a plain smooth follow: value += (target - value) * (1 - Spring.keep(...))).
function Spring.keep(halflife: number, dt: number): number
	return math.exp(-LN2 * dt / math.max(halflife, 1e-5))
end

return Spring
