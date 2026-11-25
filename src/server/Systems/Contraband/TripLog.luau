--!strict
-- TripLog: the anti-teleport check of a delivery.
--
-- A "trip" starts when a player holds a case WITH bio-cores outside a lab (he picked it up, or
-- walked out of his lab with it). Every Config.Market.TRIP_CHECK_EVERY seconds the server notes
-- where his HumanoidRootPart is. At the sale (Market) the trip is refused when:
--   • two checkpoints in a row are more than TRIP_MAX_JUMP studs apart (a teleport), or
--   • the trip lasted at least MIN_TRIP_TIME seconds and the straight line from its start to
--     the buyer, divided by its duration, is faster than TRIP_MAX_AVG_SPEED (a speed hack).
-- A refused sale only says "Try again." to the player, warns in the server log and counts a
-- Heat "tripFlags". Nobody is ever banned by it (a false alarm costs a few seconds, no more).
-- Server teleports (going out of the lab) restart the trip at the exit (TripLog.restart).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Guard = require(script.Parent.Guard)

local M = Config.Market

local MIN_TRIP_TIME = 6 -- seconds: shorter trips are not checked for average speed

type Trip = {
	startPosition: Vector3,
	startedAt: number, -- os.clock()
	lastPosition: Vector3,
	biggestJump: number, -- studs between two checkpoints
	checkpoints: number,
}

local TripLog = {}

local trips: { [Player]: Trip } = {}

local function rootPosition(player: Player): Vector3?
	local _, root = Guard.body(player)
	return if root then root.Position else nil
end

-- Starts a trip for the player from where he stands (or `from`). Does nothing if one is going.
function TripLog.begin(player: Player, from: Vector3?)
	if trips[player] then
		return
	end
	local position = from or rootPosition(player)
	if position == nil then
		return
	end
	trips[player] = {
		startPosition = position,
		startedAt = os.clock(),
		lastPosition = position,
		biggestJump = 0,
		checkpoints = 0,
	}
end

function TripLog.stop(player: Player)
	trips[player] = nil
end

-- The server moved the player (lab exit): a new trip from `position`.
function TripLog.restart(player: Player, position: Vector3)
	trips[player] = nil
	TripLog.begin(player, position)
end

function TripLog.isActive(player: Player): boolean
	return trips[player] ~= nil
end

-- One checkpoint (the root position now).
local function checkpoint(player: Player, trip: Trip)
	local position = rootPosition(player)
	if position == nil then
		return
	end
	local jump = (position - trip.lastPosition).Magnitude
	if jump > trip.biggestJump then
		trip.biggestJump = jump
	end
	trip.lastPosition = position
	trip.checkpoints += 1
end

-- Is this trip clean enough to sell at `position`? Returns (true, nil) or (false, why) where
-- `why` is for the server log only.
function TripLog.check(player: Player, position: Vector3): (boolean, string?)
	local trip = trips[player]
	if trip == nil then
		-- (a case with cores held in the city always has a trip; none = held since the
		-- server moved him, nothing suspicious to check)
		return true, nil
	end
	checkpoint(player, trip)
	if trip.biggestJump > M.TRIP_MAX_JUMP then
		return false, `jump of {math.floor(trip.biggestJump)} studs between two checkpoints`
	end
	local elapsed = os.clock() - trip.startedAt
	local straight = (position - trip.startPosition).Magnitude
	if elapsed >= MIN_TRIP_TIME and straight / elapsed > M.TRIP_MAX_AVG_SPEED then
		return false,
			`average {math.floor(straight / elapsed)} studs/s over {math.floor(elapsed)} s`
	end
	if elapsed < MIN_TRIP_TIME and straight > M.TRIP_MAX_AVG_SPEED * MIN_TRIP_TIME then
		return false, `{math.floor(straight)} studs in {math.floor(elapsed * 10) / 10} s`
	end
	return true, nil
end

-- Lifecycle (called by Contraband/init): the checkpoint loop.
function TripLog.start()
	while true do
		task.wait(M.TRIP_CHECK_EVERY)
		for player, trip in trips do
			if player.Parent == nil then
				trips[player] = nil
			else
				checkpoint(player, trip)
			end
		end
	end
end

function TripLog.forget(player: Player)
	trips[player] = nil
end

return TripLog
