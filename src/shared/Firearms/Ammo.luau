--!strict
-- Ammo: the round counting of a carried gun, as pure functions of (def, state), so
-- the server (truth) and the shooter's client (prediction) count exactly alike, and
-- Lune tests can run it (tools/anim/firearms_test.luau).
--
--   Ammo.new(def)                      a full gun: feed full, chambered (closed bolt), reserve
--   Ammo.canFire(def, s)               -> boolean, reason?
--   Ammo.fire(def, s)                  one shot's worth (call only when canFire)
--   Ammo.reloadPlan(def, s)            -> the timeline to play for a reload ("ReloadTactical",
--                                         "ReloadEmpty", "ReloadInsert", "Charge", "PortLoad",
--                                         "Shells", "Reload", "ReloadResume") or nil
--   Ammo.cyclePlan(def, s)             -> "Cycle" when a bolt-action needs its bolt worked
--   Ammo.applyEvent(def, s, name)      a timeline event happened (mag_drop, mag_insert,
--                                         slide_release, shell_insert, belt_lay...): the
--                                         physical step it stands for
--   Ammo.loaded(def, s)                rounds ready to shoot (feed + chamber)
--
-- A cancelled action never rolls back a physical step that happened (a dropped mag
-- stays dropped): the next plan starts from what the state is.

local Types = require(script.Parent.Types)

type Def = Types.FirearmDef
type State = Types.AmmoState

local Ammo = {}

local function isBolt(def: Def): boolean
	return def.modes[1] == "Bolt"
end

function Ammo.new(def: Def): State
	return {
		mag = def.capacity,
		chambered = def.closedBolt,
		reserve = def.startReserve,
		boltOpen = false,
		needsCycle = false,
		coverOpen = false,
	}
end

function Ammo.loaded(def: Def, s: State): number
	return (s.mag or 0) + (if def.closedBolt and s.chambered then 1 else 0)
end

function Ammo.canFire(def: Def, s: State): (boolean, string?)
	if s.coverOpen then
		return false, "cover"
	end
	if def.closedBolt then
		if s.needsCycle then
			return false, "cycle"
		end
		if not s.chambered then
			return false, "empty"
		end
		return true, nil
	end
	-- open bolt (LMG): straight from the belt, the bolt must be back
	if s.needsCycle then
		return false, "cycle"
	end
	if s.mag == nil or (s.mag :: number) <= 0 then
		return false, "empty"
	end
	return true, nil
end

function Ammo.fire(def: Def, s: State)
	if def.closedBolt then
		s.chambered = false
		if isBolt(def) then
			s.needsCycle = true -- the spent case stays until the bolt is worked
			return
		end
		local mag = s.mag
		if mag and mag > 0 then
			s.mag = mag - 1
			s.chambered = true
		elseif def.lockBack then
			s.boltOpen = true
		end
		return
	end
	local mag = (s.mag or 0) - 1
	s.mag = math.max(mag, 0)
	if mag <= 0 then
		s.needsCycle = true -- the bolt rode home on the empty belt: charge it
	end
end

local function take(def: Def, s: State): number
	local n = math.min(def.capacity, s.reserve)
	s.reserve -= n
	return n
end

local function chamber(s: State)
	if not s.chambered then
		local mag = s.mag
		if mag and mag > 0 then
			s.mag = mag - 1
			s.chambered = true
		end
	end
	s.boltOpen = false
end

function Ammo.applyEvent(def: Def, s: State, name: string)
	if name == "mag_drop" or name == "pouch_drop" then
		s.mag = nil -- its rounds are gone with it
	elseif name == "mag_insert" then
		if s.mag == nil then
			s.mag = take(def, s)
		end
	elseif name == "belt_lay" then
		if s.mag == nil then
			s.mag = take(def, s)
		end
	elseif name == "slide_release" or name == "bolt_release_press" then
		chamber(s)
	elseif name == "charge_release" then
		if def.closedBolt then
			chamber(s)
		else
			s.needsCycle = false -- the open bolt is held back, ready
		end
	elseif name == "case_eject" then
		s.needsCycle = false
		s.chambered = false
	elseif name == "bolt_forward" then
		if not s.needsCycle then
			chamber(s)
		end
	elseif name == "port_load" then
		if s.reserve > 0 and not s.chambered then
			s.reserve -= 1
			s.chambered = true
		end
	elseif name == "shell_insert" then
		local mag = s.mag or 0
		if mag < def.capacity and s.reserve > 0 then
			s.mag = mag + 1
			s.reserve -= 1
		end
	elseif name == "cover_open" then
		s.coverOpen = true
	elseif name == "cover_close" then
		s.coverOpen = false
	end
end

function Ammo.cyclePlan(def: Def, s: State): string?
	if isBolt(def) and s.needsCycle then
		return "Cycle"
	end
	if isBolt(def) and not s.chambered and (s.mag or 0) > 0 then
		return "Cycle"
	end
	return nil
end

function Ammo.reloadPlan(def: Def, s: State): string?
	local mag = s.mag
	if def.feed == "Tube" then
		if s.reserve <= 0 then
			return nil
		end
		if not s.chambered and (s.boltOpen or (mag or 0) == 0) then
			return "PortLoad"
		end
		if (mag or 0) < def.capacity then
			return "Shells"
		end
		return nil
	end
	if def.feed == "Belt" then
		if s.coverOpen and mag == nil then
			return if s.reserve > 0 then "ReloadResume" else nil
		end
		if s.reserve <= 0 then
			return if s.needsCycle and (mag or 0) > 0 then "Charge" else nil
		end
		if mag == def.capacity and not s.needsCycle then
			return nil
		end
		return "Reload"
	end
	-- magazine
	if mag == nil then
		return if s.reserve > 0 then "ReloadInsert" else nil
	end
	if def.closedBolt and not s.chambered and mag > 0 and (mag >= def.capacity or s.reserve <= 0) then
		return if isBolt(def) then "Cycle" else "Charge" -- a full mag in, nothing chambered
	end
	if s.reserve <= 0 or (mag >= def.capacity and (s.chambered or not def.closedBolt)) then
		return nil
	end
	return if s.chambered then "ReloadTactical" else "ReloadEmpty"
end

return table.freeze(Ammo)
