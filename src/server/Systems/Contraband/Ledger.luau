--!strict
-- Ledger: the ONE place that knows where every bio-core is. Server only, never replicated.
--
-- PURE module: no Instance, no service, no yield. It can be tested anywhere (Studio command bar,
-- a Lune script) with Ledger.selfTest().
--
-- Every bio-core has:
--   id        "c<salt>_<n>": made here, for THIS server session only. Never sent to a client,
--             never saved (the stash is saved without ids, see stashOf / loadStash).
--   grade     "A" | "B" | "C", score (0..100), madeAt (os.time), maker (userId)
--   location  one of:
--               { kind = "Bench", owner = userId }            in that player's lab stash
--               { kind = "Case", caseId = ..., slot = n }     in a cradle of a case (WHERE the case
--                                                             is - held, on the ground, in a lab -
--                                                             is Case.luau's business)
--               { kind = "Sold", by = userId, at = os.clock } sold to the buyer (kept 10 min)
--
-- Rules (checked by Ledger.verify):
--   • each core is in exactly ONE place; a case slot holds at most one core;
--   • a slot number is between 1 and the case's cradle count;
--   • a bench holds at most `stashMax` cores (only a player leaving with cores in his lab may
--     go over it, for the final save: see `allowOverflow`);
--   • a sold core never moves again.
-- Every change is synchronous and checks "is it really where you say it is?" first (`from`),
-- so two remote calls can never both move the same core: no duplication possible.

export type CoreGrade = "A" | "B" | "C"

export type Location = {
	kind: "Bench" | "Case" | "Sold",
	owner: number?, -- Bench
	caseId: string?, -- Case
	slot: number?, -- Case
	by: number?, -- Sold
	at: number?, -- Sold (os.clock)
}

export type Core = {
	id: string,
	grade: CoreGrade,
	score: number,
	madeAt: number,
	maker: number,
	location: Location,
}

-- What the save keeps for a core on the bench (= Types.StashCore).
export type StashCore = { grade: CoreGrade, score: number, madeAt: number }

type CaseInfo = { cradles: number, slots: { [number]: string } }

local Ledger = {}

local SOLD_KEEP = 600 -- seconds a sold core is remembered (then forgotten)

local cores: { [string]: Core } = {}
local cases: { [string]: CaseInfo } = {}
local benches: { [number]: { string } } = {} -- owner → ids, in order
local overflowing: { [number]: boolean } = {} -- owners allowed over stashMax (leaving / old save)
local stashMax = 8
local salt = tostring(math.random(100000, 999999))
local counter = 0

------------------------------------------------------------------------------
-- Locations
------------------------------------------------------------------------------

function Ledger.bench(owner: number): Location
	return { kind = "Bench", owner = owner }
end

function Ledger.inCase(caseId: string, slot: number): Location
	return { kind = "Case", caseId = caseId, slot = slot }
end

local function sameLocation(a: Location, b: Location): boolean
	if a.kind ~= b.kind then
		return false
	end
	if a.kind == "Bench" then
		return a.owner == b.owner
	elseif a.kind == "Case" then
		return a.caseId == b.caseId and a.slot == b.slot
	end
	return a.by == b.by and a.at == b.at
end

local function isWholeNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0
end

local function copyLocation(location: Location): Location
	return {
		kind = location.kind,
		owner = location.owner,
		caseId = location.caseId,
		slot = location.slot,
		by = location.by,
		at = location.at,
	}
end

-- Is `location` an empty, valid place for one more core?
local function isFree(location: Location, allowOverflow: boolean): boolean
	if location.kind == "Bench" then
		local owner = location.owner
		if not isWholeNumber(owner) then
			return false
		end
		local list = benches[owner :: number]
		local count = if list then #list else 0
		return allowOverflow or count < stashMax
	elseif location.kind == "Case" then
		local caseId, slot = location.caseId, location.slot
		if typeof(caseId) ~= "string" or not isWholeNumber(slot) then
			return false
		end
		local info = cases[caseId :: string]
		local index = slot :: number
		return info ~= nil and index >= 1 and index <= info.cradles and info.slots[index] == nil
	end
	return false -- (nothing is ever created or moved straight into "Sold": use Ledger.sell)
end

-- Puts core `id` at `location` (the place must be free: checked by the caller).
local function place(id: string, location: Location, allowOverflow: boolean)
	if location.kind == "Bench" then
		local owner = location.owner :: number
		local list = benches[owner]
		if list == nil then
			list = {}
			benches[owner] = list
		end
		table.insert(list, id)
		if #list > stashMax and allowOverflow then
			overflowing[owner] = true
		end
	elseif location.kind == "Case" then
		local info = cases[location.caseId :: string]
		info.slots[location.slot :: number] = id
	end
end

-- Takes core `id` out of `location` (where it is now).
local function unplace(id: string, location: Location)
	if location.kind == "Bench" then
		local list = benches[location.owner :: number]
		local index = if list then table.find(list, id) else nil
		if list and index then
			table.remove(list, index)
		end
	elseif location.kind == "Case" then
		local info = cases[location.caseId :: string]
		if info and info.slots[location.slot :: number] == id then
			info.slots[location.slot :: number] = nil
		end
	end
end

------------------------------------------------------------------------------
-- Settings and cases
------------------------------------------------------------------------------

-- How many cores a bench holds (Config.Lab.STASH_MAX; set once at start).
function Ledger.configure(maxOnBench: number)
	stashMax = math.max(0, math.floor(maxOnBench))
end

function Ledger.stashMax(): number
	return stashMax
end

-- A new case exists (Case.luau): it has `cradles` slots. False if the id is taken.
function Ledger.registerCase(caseId: string, cradles: number): boolean
	if cases[caseId] ~= nil or not isWholeNumber(cradles) or cradles < 1 then
		return false
	end
	cases[caseId] = { cradles = cradles, slots = {} }
	return true
end

-- The case is gone. Only allowed when it is EMPTY (move or sell its cores first).
function Ledger.removeCase(caseId: string): boolean
	local info = cases[caseId]
	if info == nil then
		return true
	end
	if next(info.slots) ~= nil then
		return false
	end
	cases[caseId] = nil
	return true
end

------------------------------------------------------------------------------
-- Cores
------------------------------------------------------------------------------

-- Makes a new core at `location` (which must be free). Returns its id, or nil.
function Ledger.create(
	maker: number,
	grade: CoreGrade,
	score: number,
	madeAt: number,
	location: Location,
	allowOverflow: boolean?
): string?
	if grade ~= "A" and grade ~= "B" and grade ~= "C" then
		return nil
	end
	if not isFree(location, allowOverflow == true) then
		return nil
	end
	counter += 1
	local id = `c{salt}_{counter}`
	local stored = copyLocation(location)
	cores[id] = {
		id = id,
		grade = grade,
		score = if score == score then math.clamp(score, 0, 100) else 0,
		madeAt = madeAt,
		maker = maker,
		location = stored,
	}
	place(id, stored, allowOverflow == true)
	return id
end

-- Moves core `id` from `from` to `to`. Refused (false, nothing changes) unless the core is
-- really at `from` and `to` is free. `allowOverflow`: a bench may go over stashMax (only for
-- the clean-up when a player leaves).
function Ledger.move(id: string, from: Location, to: Location, allowOverflow: boolean?): boolean
	local core = cores[id]
	if core == nil or core.location.kind == "Sold" then
		return false
	end
	if not sameLocation(core.location, from) or sameLocation(from, to) then
		return false
	end
	if not isFree(to, allowOverflow == true) then
		return false
	end
	unplace(id, core.location)
	local stored = copyLocation(to)
	core.location = stored
	place(id, stored, allowOverflow == true)
	return true
end

-- A frozen copy of a core, or nil.
function Ledger.get(id: string): Core?
	local core = cores[id]
	if core == nil then
		return nil
	end
	return table.freeze({
		id = core.id,
		grade = core.grade,
		score = core.score,
		madeAt = core.madeAt,
		maker = core.maker,
		location = table.freeze(copyLocation(core.location)),
	})
end

------------------------------------------------------------------------------
-- Reading a case / a bench
------------------------------------------------------------------------------

-- slot → core id of a case (a copy; empty slots are missing). Empty table for an unknown case.
function Ledger.caseSlots(caseId: string): { [number]: string }
	local info = cases[caseId]
	return if info then table.clone(info.slots) else {}
end

function Ledger.caseCradles(caseId: string): number
	local info = cases[caseId]
	return if info then info.cradles else 0
end

-- How many cores are in a case.
function Ledger.caseCount(caseId: string): number
	local info = cases[caseId]
	local count = 0
	if info then
		for _ in info.slots do
			count += 1
		end
	end
	return count
end

-- The grades in a case, in slot order (for the holder's HUD: grades only, never ids).
function Ledger.caseGrades(caseId: string): { CoreGrade }
	local grades: { CoreGrade } = {}
	local info = cases[caseId]
	if info then
		for slot = 1, info.cradles do
			local id = info.slots[slot]
			local core = if id then cores[id] else nil
			if core then
				table.insert(grades, core.grade)
			end
		end
	end
	return grades
end

-- The cores in a case as the save keeps them (no ids), in slot order.
function Ledger.caseStash(caseId: string): { StashCore }
	local list: { StashCore } = {}
	local info = cases[caseId]
	if info then
		for slot = 1, info.cradles do
			local id = info.slots[slot]
			local core = if id then cores[id] else nil
			if core then
				table.insert(list, { grade = core.grade, score = core.score, madeAt = core.madeAt })
			end
		end
	end
	return list
end

-- The first empty slot of a case, or nil.
function Ledger.freeSlot(caseId: string): number?
	local info = cases[caseId]
	if info then
		for slot = 1, info.cradles do
			if info.slots[slot] == nil then
				return slot
			end
		end
	end
	return nil
end

-- The ids on a player's bench, in order (a copy).
function Ledger.benchIds(owner: number): { string }
	local list = benches[owner]
	return if list then table.clone(list) else {}
end

function Ledger.benchCount(owner: number): number
	local list = benches[owner]
	return if list then #list else 0
end

-- The grades on a player's bench, in order (for LabState: grades only, never ids).
function Ledger.benchGrades(owner: number): { CoreGrade }
	local grades: { CoreGrade } = {}
	local list = benches[owner]
	if list then
		for _, id in list do
			table.insert(grades, cores[id].grade)
		end
	end
	return grades
end

------------------------------------------------------------------------------
-- Saves
------------------------------------------------------------------------------

-- The bench of `owner` as the save keeps it (no ids).
function Ledger.stashOf(owner: number): { StashCore }
	local stash: { StashCore } = {}
	local list = benches[owner]
	if list then
		for _, id in list do
			local core = cores[id]
			table.insert(stash, { grade = core.grade, score = core.score, madeAt = core.madeAt })
		end
	end
	return stash
end

-- A player's save was loaded: their stash cores get fresh ids, on their bench. Entries that
-- are not valid cores are skipped. A save over stashMax (cores that were in cases in the lab)
-- is kept, but never more than `keepMax` cores (the rest is dropped: the save cannot grow).
-- Returns how many cores were loaded.
function Ledger.loadStash(owner: number, list: { any }, keepMax: number?): number
	if benches[owner] ~= nil and #benches[owner] > 0 then
		return 0 -- (already loaded: never twice, that would duplicate)
	end
	local loaded = 0
	local limit = if keepMax and keepMax >= 0 then math.floor(keepMax) else math.huge
	for _, entry in list do
		if loaded >= limit then
			break
		end
		if typeof(entry) ~= "table" then
			continue
		end
		local grade = entry.grade
		local score = entry.score
		local madeAt = entry.madeAt
		if grade ~= "A" and grade ~= "B" and grade ~= "C" then
			continue
		end
		local id = Ledger.create(
			owner,
			grade,
			if typeof(score) == "number" then score else 0,
			if typeof(madeAt) == "number" then madeAt else 0,
			Ledger.bench(owner),
			true
		)
		if id then
			loaded += 1
		end
	end
	return loaded
end

-- The player left and was saved: forget the cores on their bench.
function Ledger.forgetOwner(owner: number)
	local list = benches[owner]
	if list then
		for _, id in list do
			cores[id] = nil
		end
	end
	benches[owner] = nil
	overflowing[owner] = nil
end

------------------------------------------------------------------------------
-- Selling
------------------------------------------------------------------------------

-- Sells EVERY core of a case: checks all of them first, then marks them all Sold.
-- Returns their grades (slot order), or nil if the case is unknown or empty.
function Ledger.sell(caseId: string, seller: number, at: number): { CoreGrade }?
	local info = cases[caseId]
	if info == nil then
		return nil
	end
	local ids: { string } = {}
	for slot = 1, info.cradles do
		local id = info.slots[slot]
		if id then
			local core = cores[id]
			if core == nil or core.location.kind ~= "Case" or core.location.caseId ~= caseId then
				return nil -- (should never happen: refuse the whole sale)
			end
			table.insert(ids, id)
		end
	end
	if #ids == 0 then
		return nil
	end
	local grades: { CoreGrade } = {}
	for _, id in ids do
		local core = cores[id]
		unplace(id, core.location)
		core.location = { kind = "Sold", by = seller, at = at }
		table.insert(grades, core.grade)
	end
	return grades
end

-- Forgets sold cores older than SOLD_KEEP seconds (`now` = os.clock()).
function Ledger.pruneSold(now: number)
	for id, core in cores do
		local at = core.location.at
		if core.location.kind == "Sold" and at and now - at > SOLD_KEEP then
			cores[id] = nil
		end
	end
end

------------------------------------------------------------------------------
-- Checks
------------------------------------------------------------------------------

-- Checks every rule at the top. Returns (true, nil) or (false, the first broken rule).
function Ledger.verify(): (boolean, string?)
	local seen: { [string]: string } = {} -- id → where it was listed
	for owner, list in benches do
		if #list > stashMax and not overflowing[owner] then
			return false, `bench {owner} holds {#list} > {stashMax}`
		end
		for _, id in list do
			if seen[id] then
				return false, `{id} listed twice ({seen[id]}, bench {owner})`
			end
			seen[id] = `bench {owner}`
			local core = cores[id]
			if core == nil then
				return false, `{id} on bench {owner} does not exist`
			end
			if core.location.kind ~= "Bench" or core.location.owner ~= owner then
				return false, `{id} on bench {owner} but its location says {core.location.kind}`
			end
		end
	end
	for caseId, info in cases do
		for slot, id in info.slots do
			if slot < 1 or slot > info.cradles or slot % 1 ~= 0 then
				return false, `case {caseId} has a bad slot {slot}`
			end
			if seen[id] then
				return false, `{id} listed twice ({seen[id]}, case {caseId})`
			end
			seen[id] = `case {caseId}`
			local core = cores[id]
			if core == nil then
				return false, `{id} in case {caseId} does not exist`
			end
			local location = core.location
			if location.kind ~= "Case" or location.caseId ~= caseId or location.slot ~= slot then
				return false, `{id} in case {caseId}/{slot} but its location disagrees`
			end
		end
	end
	for id, core in cores do
		if core.location.kind ~= "Sold" and seen[id] == nil then
			return false, `{id} ({core.location.kind}) is in no list`
		end
		if core.location.kind == "Sold" and seen[id] ~= nil then
			return false, `{id} is sold but still listed in {seen[id]}`
		end
	end
	return true, nil
end

-- Random sequences of actions on a SEPARATE, empty ledger state, checking every rule after
-- each step, plus attempts that must be refused (double sale, wrong `from`, full slot...).
-- The real state is put back afterwards. Returns (true, nil) or (false, what went wrong).
function Ledger.selfTest(seed: number?, steps: number?): (boolean, string?)
	-- Keep the real state aside.
	local realCores, realCases, realBenches, realOverflowing, realMax =
		cores, cases, benches, overflowing, stashMax
	cores, cases, benches, overflowing = {}, {}, {}, {}
	stashMax = 4

	-- A tiny random generator of our own (the same sequence for the same seed, anywhere).
	local state = math.floor(seed or 1) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local function nextNumber(): number
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
	local function nextInteger(low: number, high: number): number
		return math.min(high, low + math.floor(nextNumber() * (high - low + 1)))
	end
	local random = { NextNumber = nextNumber, NextInteger = nextInteger }
	local owners = { 101, 202, 303 }
	local caseIds: { string } = {}
	local problem: string? = nil
	local grades: { CoreGrade } = { "A", "B", "C" }

	local function fail(message: string)
		if problem == nil then
			problem = message
		end
	end

	local function anyCoreId(): string?
		local ids: { string } = {}
		for id in cores do
			table.insert(ids, id)
		end
		table.sort(ids)
		return if #ids > 0 then ids[random.NextInteger(1, #ids)] else nil
	end

	local function randomLocation(): Location
		if #caseIds > 0 and random.NextNumber() < 0.5 then
			local caseId = caseIds[random.NextInteger(1, #caseIds)]
			return Ledger.inCase(caseId, random.NextInteger(0, 4))
		end
		return Ledger.bench(owners[random.NextInteger(1, #owners)])
	end

	for step = 1, steps or 2000 do
		local roll = random.NextNumber()
		if roll < 0.08 then
			local caseId = `case{step}`
			if Ledger.registerCase(caseId, random.NextInteger(2, 3)) then
				table.insert(caseIds, caseId)
			end
			if Ledger.registerCase(caseId, 2) then
				fail("a case id was registered twice")
			end
		elseif roll < 0.35 then
			local location = randomLocation()
			local before = if location.kind == "Bench"
				then Ledger.benchCount(location.owner :: number)
				else -1
			local id = Ledger.create(
				owners[1],
				grades[random.NextInteger(1, 3)],
				random.NextNumber() * 100,
				0,
				location
			)
			if id and location.kind == "Bench" and before >= stashMax then
				fail("a core was created on a full bench")
			end
		elseif roll < 0.7 then
			local id = anyCoreId()
			if id then
				local core = cores[id]
				local to = randomLocation()
				local wrongFrom = Ledger.bench(999)
				if core.location.kind ~= "Bench" or core.location.owner ~= 999 then
					if Ledger.move(id, wrongFrom, to) then
						fail("a move from the wrong place was accepted")
					end
				end
				local wasSold = core.location.kind == "Sold"
				local moved = Ledger.move(id, core.location, to)
				if wasSold and moved then
					fail("a sold core moved")
				end
			end
		elseif roll < 0.8 then
			if #caseIds > 0 then
				local caseId = caseIds[random.NextInteger(1, #caseIds)]
				local count = Ledger.caseCount(caseId)
				local sold = Ledger.sell(caseId, owners[2], step)
				if count > 0 and (sold == nil or #sold ~= count) then
					fail("a sale lost or added cores")
				end
				if Ledger.sell(caseId, owners[2], step) ~= nil then
					fail("the same case was sold twice")
				end
			end
		elseif roll < 0.86 then
			local owner = owners[random.NextInteger(1, #owners)]
			local stash = Ledger.stashOf(owner)
			Ledger.forgetOwner(owner)
			if Ledger.benchCount(owner) ~= 0 then
				fail("forgetOwner left cores on the bench")
			end
			Ledger.loadStash(owner, stash)
			if Ledger.benchCount(owner) ~= #stash then
				fail("a stash did not reload whole")
			end
			if Ledger.loadStash(owner, stash) ~= 0 and #stash > 0 then
				fail("a stash was loaded twice")
			end
		elseif roll < 0.92 then
			if #caseIds > 0 then
				local index = random.NextInteger(1, #caseIds)
				local caseId = caseIds[index]
				local empty = Ledger.caseCount(caseId) == 0
				if Ledger.removeCase(caseId) ~= empty then
					fail("removeCase did not match the case being empty")
				end
				if empty then
					table.remove(caseIds, index)
				end
			end
		else
			Ledger.pruneSold(step + SOLD_KEEP)
		end
		local ok, why = Ledger.verify()
		if not ok then
			fail(`step {step}: {why}`)
		end
		if problem then
			break
		end
	end

	-- Put the real state back (the id counter keeps going: ids are never reused).
	cores, cases, benches, overflowing, stashMax =
		realCores, realCases, realBenches, realOverflowing, realMax
	return problem == nil, problem
end

return Ledger
