--!strict
-- Case: the BX-7 courier cases (server side). Every case that exists is a record here.
--
-- A case is either HELD (in a player's left hand) or on the GROUND (in the city, or lying in a
-- lab: then `labOwner` is set and only that player may take it). What is inside a case is the
-- Ledger's business (cores in cradles); this module only knows where the case itself is.
--
--   Get one        the lab rack, "Take case" (Lab calls Case.issue). One case in hand at a time;
--                  at most MAX_ISSUED_LIVE cases lying in your own lab. Taking a new case first
--                  takes back (destroys) YOUR empty cases left on the ground in the city. In the
--                  whole server at most worldCap() cases (≥ MaxPlayers × MAX_ISSUED_LIVE); when it
--                  is reached, the oldest empty city case is taken back first.
--   Carry          character attribute Carrying = "Case" (every client draws the case in the
--                  left hand, CaseController); speed ×SPEED_MULT, sprint stamina drain
--                  ×STAMINA_DRAIN_MULT, no mantle (Movement). Kit moves / Awakening / finishers
--                  are refused by Combat while Carrying is set.
--   Set down (G)   Remotes.CaseAction("SetDown"): upright on the floor in front of you.
--   KO / death     it falls out: lying flat, lid ajar DROP_LID_ANGLE°, a sliver of the cold
--                  interior light (the SAME empty or full). Anyone can pick it up. (A knockout
--                  only drops it when a PLAYER dealt it: a dummy / NPC knockout does not.)
--   Leave          in the city: it stays where you stand (or last stood on the floor). In your
--                  lab: its cores go back to your stash and the case is gone.
--                  "In your lab" is decided by POSITION (the lab's box, Case.setLabResolver),
--                  never by the InLab attribute alone.
--   Pick up        the "Pick up" prompt on a ground case (E, hold PICKUP_HOLD s).
--   Abandoned      an EMPTY case nobody comes near (DESPAWN_CLEAR_RADIUS) for EMPTY_DESPAWN_TIME
--                  seconds goes away. A case WITH cores in the city nobody comes near for
--                  ABANDON_TIME seconds: each core goes back to the stash of the player who made
--                  it if he is online and has room (else it waits); then the empty case goes.
--   Saves          the cores in cases lying in your lab (and in the case you hold INSIDE your
--                  lab) are saved with your stash (Lab, through Case.onLabCoresChanged): a
--                  server crash or shutdown does not lose them. A case held in the city is lost
--                  with its cores if the server stops (by design).
--
-- NEVER REPLICATED: what is in a case. A ground case only shows the attributes CaseId (an
-- opaque name, not a core id), LidAngle and LabOwner. The grades go to the HOLDER only
-- (ContrabandEvent "CaseState"): a thief learns them when he picks it up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CaseModel = require(ReplicatedStorage.Shared.Contraband.CaseModel)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Combat = require(script.Parent.Parent.Combat)
local Knockout = require(script.Parent.Parent.Knockout)
local Movement = require(script.Parent.Parent.Movement)
local PlayerData = require(script.Parent.Parent.PlayerData)
local RateLimiter = require(script.Parent.Parent.Parent.Util.RateLimiter)
local Guard = require(script.Parent.Guard)
local Heat = require(script.Parent.Heat)
local Ledger = require(script.Parent.Ledger)
local TripLog = require(script.Parent.TripLog)

local C = Config.Case

export type Where = "Held" | "Ground"
export type DropReason = "KO" | "Death" | "Leave"

export type CaseRecord = {
	id: string,
	tier: string,
	cradles: number,
	where: Where,
	holder: Player?,
	model: Model?,
	labOwner: number?, -- set while it lies in that player's lab
	issuedTo: number, -- userId of the player who took it from his rack
	droppedAt: number, -- os.clock() it reached the ground
	lastNearAt: number, -- os.clock() someone was last near it (empty case clean-up)
}

local Case = {}

local MODEL_TAG = "ContrabandCase"
local DESPAWN_CHECK_EVERY = 5 -- seconds
local SOLD_PRUNE_EVERY = 60 -- seconds

local records: { [string]: CaseRecord } = {}
local heldBy: { [Player]: CaseRecord } = {}
local lastValid: { [Player]: Vector3 } = {} -- last spot the player stood on a floor
local lastSetDownAt: { [Player]: number } = {}
local caseCounter = 0
local labResolver: ((Player, Vector3) -> boolean)? = nil
local labCoresCallbacks: { (Player) -> () } = {}
local heldCallbacks: { (Player) -> () } = {}
local actionLimiter = RateLimiter.new(4, 2)
local casesFolder: Folder? = nil

local function folder(): Folder
	if casesFolder == nil or casesFolder.Parent == nil then
		casesFolder = Guard.worldFolder("ContrabandCases")
	end
	return casesFolder :: Folder
end

local function newCaseId(): string
	caseCounter += 1
	return `K{math.random(1000, 9999)}{caseCounter}`
end

local function count(predicate: (CaseRecord) -> boolean): number
	local total = 0
	for _, record in records do
		if predicate(record) then
			total += 1
		end
	end
	return total
end

-- Most cases the whole server may hold: never less than every player keeping his allowed ones.
local function worldCap(): number
	return math.max(C.MAX_WORLD, Players.MaxPlayers * C.MAX_ISSUED_LIVE + 8)
end

-- Apartments tells us how to know if a position is inside a player's own lab.
function Case.setLabResolver(resolver: (Player, Vector3) -> boolean)
	labResolver = resolver
end

local function inOwnLabAt(player: Player, position: Vector3?): boolean
	if position == nil or labResolver == nil then
		return false
	end
	return (labResolver :: (Player, Vector3) -> boolean)(player, position)
end

-- `callback(owner)` when the cores kept in `owner`'s lab outside the bench changed (a loaded
-- case set down / picked up / dropped in his lab, cores given back): Lab saves the stash again.
function Case.onLabCoresChanged(callback: (Player) -> ())
	table.insert(labCoresCallbacks, callback)
end

local function labCoresChanged(owner: Player?)
	if owner == nil or owner.Parent == nil then
		return
	end
	for _, callback in labCoresCallbacks do
		local ok: boolean, problem: any = pcall(callback, owner)
		if not ok then
			warn(`[Contraband] lab cores callback failed: {problem}`)
		end
	end
end

-- `callback(player)` after the player took a case in hand or let it go (Lab: bench prompts).
function Case.onHeldChanged(callback: (Player) -> ())
	table.insert(heldCallbacks, callback)
end

local function heldChanged(player: Player)
	if player.Parent == nil then
		return
	end
	for _, callback in heldCallbacks do
		task.spawn(callback, player)
	end
end

-- A teleport (lab in / out) just moved the player: that spot is his new "last safe spot".
function Case.noteTeleport(player: Player, position: Vector3)
	if heldBy[player] then
		lastValid[player] = position
	end
end

------------------------------------------------------------------------------
-- State for the holder
------------------------------------------------------------------------------

-- Sends "CaseState" (the case he holds: tier, cradles, grades) to the player.
function Case.pushState(player: Player)
	local record = heldBy[player]
	local payload: Types.CaseStatePayload = if record
		then {
			holding = true,
			tier = record.tier,
			cradles = record.cradles,
			grades = Ledger.caseGrades(record.id),
		}
		else { holding = false, tier = "", cradles = 0, grades = {} }
	Guard.sendCaseState(player, payload)
end

function Case.held(player: Player): CaseRecord?
	return heldBy[player]
end

-- Starts / stops the trip log: a trip runs while the player holds a case WITH cores outside
-- a lab. Call it after anything that may change that (pickup, load, sale, lab exit...).
function Case.refreshTrip(player: Player)
	local record = heldBy[player]
	local loaded = record ~= nil and Ledger.caseCount(record.id) > 0
	if loaded and player:GetAttribute("InLab") ~= true then
		TripLog.begin(player)
	else
		TripLog.stop(player)
	end
end

-- The cores kept in `player`'s lab outside the bench, as the save keeps them: the cases lying
-- in his lab, and the case he holds while he is in his lab.
function Case.labStash(player: Player): { Ledger.StashCore }
	local list: { Ledger.StashCore } = {}
	local userId = player.UserId
	local ids: { string } = {}
	for id, record in records do
		if record.where == "Ground" and record.labOwner == userId then
			table.insert(ids, id)
		end
	end
	local held = heldBy[player]
	if held and player:GetAttribute("InLab") == true then
		table.insert(ids, held.id)
	end
	table.sort(ids)
	for _, id in ids do
		for _, core in Ledger.caseStash(id) do
			table.insert(list, core)
		end
	end
	return list
end

-- The first free cradle of a case lying in `owner`'s lab: (caseId, slot), or nil.
function Case.freeCradleInLab(owner: number): (string?, number?)
	local ids: { string } = {}
	for id, record in records do
		if record.where == "Ground" and record.labOwner == owner then
			table.insert(ids, id)
		end
	end
	table.sort(ids) -- (always the same case first)
	for _, id in ids do
		local slot = Ledger.freeSlot(id)
		if slot then
			return id, slot
		end
	end
	return nil, nil
end

------------------------------------------------------------------------------
-- Holding
------------------------------------------------------------------------------

local function applyCarry(player: Player, on: boolean, cradles: number?)
	local character = player.Character
	if character then
		-- (CaseCradles first: every client builds the held case with the right foam; it only
		-- tells the tier, never what is inside)
		character:SetAttribute("CaseCradles", if on then cradles else nil)
		character:SetAttribute("Carrying", if on then "Case" else nil)
		if not on then
			character:SetAttribute("CaseOpen", nil)
		end
	end
	Movement.setSpeedModifier(player, "Case", if on then C.SPEED_MULT else nil)
	Movement.setStaminaDrainModifier(player, "Case", if on then C.STAMINA_DRAIN_MULT else nil)
	Movement.setClimbLock(player, "Case", on)
end

local function destroyModel(record: CaseRecord)
	local model = record.model
	record.model = nil
	if model then
		model:Destroy()
	end
end

-- Puts the case in the player's hand (from the rack or the ground).
local function hold(player: Player, record: CaseRecord)
	destroyModel(record)
	record.where = "Held"
	record.holder = player
	record.labOwner = nil
	heldBy[player] = record
	applyCarry(player, true, record.cradles)
	Case.pushState(player)
	Case.refreshTrip(player)
	heldChanged(player)
end

-- Takes the case out of the player's hand (it goes to the ground or away: the caller decides).
local function release(player: Player): CaseRecord?
	local record = heldBy[player]
	if record == nil then
		return nil
	end
	heldBy[player] = nil
	record.holder = nil
	applyCarry(player, false)
	TripLog.stop(player)
	Case.pushState(player)
	heldChanged(player)
	return record
end

-- Removes a case for good (its cores must be gone already: Ledger refuses otherwise).
local function forget(record: CaseRecord): boolean
	if not Ledger.removeCase(record.id) then
		return false
	end
	destroyModel(record)
	records[record.id] = nil
	return true
end

------------------------------------------------------------------------------
-- The ground
------------------------------------------------------------------------------

local function groundParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { folder() }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local npcs = workspace:FindFirstChild("City")
	local npcFolder = if npcs then npcs:FindFirstChild("Npcs") else nil
	if npcFolder then
		table.insert(exclude, npcFolder)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	return params
end

-- The floor under `position` (looking from a little above it), or nil.
local function floorBelow(position: Vector3, depth: number): Vector3?
	local hit = workspace:Raycast(
		position + Vector3.new(0, 1.5, 0),
		Vector3.new(0, -depth, 0),
		groundParams()
	)
	return if hit then hit.Position else nil
end

-- A drop point inside the train lane is moved sideways onto the walkway (the train stays deadly,
-- but it does not grind the case under it).
local function avoidTrainLane(position: Vector3): Vector3
	local city = workspace:FindFirstChild("City")
	if city == nil then
		return position
	end
	local a = city:GetAttribute("TrainA")
	local b = city:GetAttribute("TrainB")
	local width = city:GetAttribute("TrainLaneWidth")
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" or typeof(width) ~= "number" then
		return position
	end
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = flat.Magnitude
	if length < 1 then
		return position
	end
	local along = flat / length
	local offset = Vector3.new(position.X - a.X, 0, position.Z - a.Z)
	local alongDistance = offset:Dot(along)
	local sideways = offset - along * alongDistance
	local railY = a.Y + (b.Y - a.Y) * math.clamp(alongDistance / length, 0, 1)
	if sideways.Magnitude >= width / 2 or math.abs(position.Y - railY) >= 6 then
		return position
	end
	local side = if sideways.Magnitude > 0.01
		then sideways.Unit
		else along:Cross(Vector3.yAxis).Unit
	local moved = Vector3.new(a.X, position.Y, a.Z)
		+ along * alongDistance
		+ side * (width / 2 + 2.5)
	return Vector3.new(moved.X, position.Y, moved.Z)
end

-- Builds the ground model of a case at `cframe` with the "Pick up" prompt.
local function placeModel(record: CaseRecord, cframe: CFrame, lidAngle: number, physics: boolean)
	destroyModel(record)
	local model =
		CaseModel.build({ lidAngle = lidAngle, interior = true, cradles = record.cradles })
	model.Name = "Case"
	model:SetAttribute("CaseId", record.id)
	model:SetAttribute("LidAngle", lidAngle)
	model:SetAttribute("LabOwner", record.labOwner)
	model:SetAttribute("Unbreakable", true)
	model:PivotTo(cframe)
	local hitbox = model.PrimaryPart
	-- (the visual parts are welded to the Hitbox: only the Hitbox is ever anchored)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
	if hitbox then
		hitbox.Anchored = not physics
		local prompt = Guard.makePrompt(
			hitbox,
			"PickupPrompt",
			"Pick up",
			"Case",
			C.PICKUP_HOLD,
			C.PICKUP_DISTANCE,
			true
		)
		local caseId = record.id
		prompt.Triggered:Connect(function(player: Player)
			Case.pickUp(player, caseId, prompt)
		end)
	end
	model:AddTag(MODEL_TAG)
	model.Parent = folder()
	record.model = model
	if physics and hitbox then
		-- The server owns it while it falls (no player can fling it), anchored once settled.
		pcall(function()
			hitbox:SetNetworkOwner(nil)
		end)
		local spin = math.random() * math.pi * 2
		hitbox.AssemblyLinearVelocity =
			Vector3.new(math.cos(spin) * C.DROP_FLING, 4, math.sin(spin) * C.DROP_FLING)
		local start = cframe.Position
		task.delay(C.SETTLE_TIME, function()
			if record.model ~= model or hitbox.Parent == nil then
				return
			end
			-- Put it back where it was dropped if it fell through something, rolled far, fell
			-- off a ledge, or rolled onto the train lane (it must stay reachable).
			local now = hitbox.Position
			local rolled = Vector3.new(now.X - start.X, 0, now.Z - start.Z).Magnitude
			if
				now ~= now
				or now.Y < start.Y - C.SETTLE_MAX_FALL
				or rolled > C.SETTLE_MAX_ROLL
				or avoidTrainLane(now) ~= now
			then
				model:PivotTo(cframe)
			end
			hitbox.AssemblyLinearVelocity = Vector3.zero
			hitbox.AssemblyAngularVelocity = Vector3.zero
			hitbox.Anchored = true
		end)
	end
end

-- Puts a case on the ground near `position`.
--   upright: standing on its feet, facing `facing` (set down / disconnect);
--   else lying flat, lid up, ajar DROP_LID_ANGLE (knockout / death), with a little fling.
local function toGround(
	record: CaseRecord,
	position: Vector3,
	facing: Vector3,
	upright: boolean,
	labOwner: number?
)
	record.where = "Ground"
	record.holder = nil
	record.labOwner = labOwner
	record.droppedAt = os.clock()
	record.lastNearAt = os.clock()
	local spot = if labOwner then position else avoidTrainLane(position)
	local floor = floorBelow(spot, 30)
	local flatFacing = Vector3.new(facing.X, 0, facing.Z)
	if flatFacing.Magnitude < 0.01 then
		flatFacing = Vector3.new(0, 0, -1)
	end
	flatFacing = flatFacing.Unit
	local groundY = if floor then floor.Y else spot.Y - 2.9
	local cframe: CFrame
	if upright then
		local centre = Vector3.new(spot.X, groundY + C.SIZE.Y / 2 + 0.02, spot.Z)
		cframe = CFrame.lookAt(centre, centre + flatFacing)
	else
		local centre = Vector3.new(spot.X, groundY + C.SIZE.Z / 2 + 0.3, spot.Z)
		-- local Z (the lid side) points up: X along `facing`, Y = up × X
		local up = Vector3.yAxis
		cframe = CFrame.fromMatrix(centre, flatFacing, up:Cross(flatFacing))
	end
	placeModel(record, cframe, if upright then 0 else C.DROP_LID_ANGLE, not upright)
end

------------------------------------------------------------------------------
-- Public actions
------------------------------------------------------------------------------

-- A new empty case in the player's hand (lab rack). Returns it, or nil (with a notice).
function Case.issue(player: Player): CaseRecord?
	if heldBy[player] then
		Guard.notice(player, "You already carry a case.")
		return nil
	end
	local userId = player.UserId
	-- Only the cases in YOUR lab count (a case someone stole, or one you left in the city, never
	-- locks you out).
	if
		count(function(record)
			return record.where == "Ground" and record.labOwner == userId
		end) >= C.MAX_ISSUED_LIVE
	then
		Guard.notice(player, "Your lab already holds enough cases.")
		return nil
	end
	-- The rack takes back your EMPTY cases left in the city.
	for _, record in table.clone(records) do
		if
			record.issuedTo == userId
			and record.where == "Ground"
			and record.labOwner == nil
			and Ledger.caseCount(record.id) == 0
		then
			forget(record)
		end
	end
	-- Server full: the oldest empty case lying in the city goes first.
	if count(function()
		return true
	end) >= worldCap() then
		local oldest: CaseRecord? = nil
		for _, record in records do
			if
				record.where == "Ground"
				and record.labOwner == nil
				and Ledger.caseCount(record.id) == 0
				and (oldest == nil or record.droppedAt < (oldest :: CaseRecord).droppedAt)
			then
				oldest = record
			end
		end
		if oldest == nil or not forget(oldest) then
			Guard.notice(player, "No case available right now.")
			return nil
		end
	end
	local data = PlayerData.getData(player)
	local tier = if data then data.contraband.caseTier else "Courier"
	local cradles = C.CRADLES[tier]
	if typeof(cradles) ~= "number" then
		tier, cradles = "Courier", C.CRADLES.Courier
	end
	local id = newCaseId()
	if not Ledger.registerCase(id, cradles) then
		return nil
	end
	local record: CaseRecord = {
		id = id,
		tier = tier,
		cradles = cradles,
		where = "Held",
		holder = player,
		model = nil,
		labOwner = nil,
		issuedTo = userId,
		droppedAt = 0,
		lastNearAt = os.clock(),
	}
	records[id] = record
	hold(player, record)
	return record
end

-- G: puts the held case down, upright, in front of the player. Returns true if done.
function Case.setDown(player: Player): boolean
	local record = heldBy[player]
	if record == nil or not Guard.canAct(player) then
		return false
	end
	local character, root, humanoid = Guard.body(player)
	if character == nil or root == nil or humanoid == nil then
		return false
	end
	if
		character:GetAttribute("CaseOpen") == true
		or humanoid.FloorMaterial == Enum.Material.Air
	then
		return false
	end
	local now = os.clock()
	if now - (lastSetDownAt[player] or -math.huge) < C.SETDOWN_COOLDOWN then
		return false
	end
	lastSetDownAt[player] = now
	-- 2 studs in front, unless something is in the way (then at the feet).
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local spot = root.Position + look * 2
	local blocked = workspace:Raycast(root.Position, look * 2.6, groundParams())
	if blocked then
		spot = root.Position
	end
	-- (in the lab only if the spot really is inside his lab: never the InLab attribute alone)
	local inLab = inOwnLabAt(player, spot) and inOwnLabAt(player, root.Position)
	release(player)
	toGround(record, spot, -look, true, if inLab then player.UserId else nil)
	if inLab and Ledger.caseCount(record.id) > 0 then
		labCoresChanged(player)
	end
	return true
end

-- The case falls out of the player's hand (knockout, death, leaving the game).
function Case.drop(player: Player, reason: DropReason)
	local record = heldBy[player]
	if record == nil then
		return
	end
	local _, root, humanoid = Guard.body(player)
	local character = player.Character
	local anyRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local position: Vector3? = if root
		then root.Position
		elseif anyRoot and anyRoot:IsA("BasePart") then anyRoot.Position
		else nil
	if position ~= nil and position ~= position then
		position = nil -- (NaN)
	end
	if reason == "Leave" then
		-- Where he stands now if that is a floor, else the last spot he stood on one.
		local standing = root ~= nil
			and humanoid ~= nil
			and humanoid.FloorMaterial ~= Enum.Material.Air
		if not standing then
			position = lastValid[player] or position
		end
	elseif position == nil then
		position = lastValid[player]
	end
	local inLab = inOwnLabAt(player, position)
	release(player)
	Heat.record(player, "drops")
	if reason ~= "Leave" then
		PlayerData.update(player, function(data)
			data.contraband.log.casesLost += 1
		end)
	end
	if position == nil then
		-- (no body and no known spot: a case WITH cores cannot just vanish; keep it at a city spawn)
		local spawn = Knockout.pickSpawn(player)
		position = if spawn then spawn.Position + Vector3.new(0, 3, 0) else Vector3.new(0, 10, 0)
	end
	local facing = if root then root.CFrame.LookVector else Vector3.new(0, 0, -1)
	toGround(
		record,
		position :: Vector3,
		facing,
		reason == "Leave",
		if inLab then player.UserId else nil
	)
	if inLab then
		labCoresChanged(player)
	end
	Guard.debug(`{player.Name} dropped case {record.id} ({reason})`)
end

-- The "Pick up" prompt of a ground case.
function Case.pickUp(player: Player, caseId: string, prompt: ProximityPrompt?): boolean
	if prompt and not Guard.promptAllowed(player, prompt) then
		return false
	end
	if not Guard.canAct(player) or heldBy[player] then
		return false
	end
	local record = records[caseId]
	if record == nil or record.where ~= "Ground" or record.model == nil then
		return false
	end
	local character = player.Character
	if character and character:GetAttribute("CaseOpen") == true then
		return false
	end
	if record.labOwner ~= nil and record.labOwner ~= player.UserId then
		return false
	end
	local model = record.model :: Model
	if not Guard.near(player, model:GetPivot().Position, C.SERVER_DISTANCE) then
		return false
	end
	local fromLab = record.labOwner ~= nil
	hold(player, record)
	Heat.record(player, if record.issuedTo == player.UserId then "pickupsOwn" else "pickupsOthers")
	if fromLab and Ledger.caseCount(record.id) > 0 then
		labCoresChanged(player)
	end
	return true
end

-- The player leaves the game (Contraband/init, BEFORE the lab and the stash are saved):
--   • a held case in the city stays on the ground where he last stood; in his lab, its cores go
--     to his stash and the case goes away;
--   • the cases lying in his lab: same (cores to the stash, case gone).
function Case.onLeaving(player: Player)
	local userId = player.UserId
	local record = heldBy[player]
	if record then
		local _, root = Guard.body(player)
		local here = if root then root.Position else lastValid[player]
		-- (no position known at all: the attribute is all we have)
		local inLab = if here
			then inOwnLabAt(player, here)
			else player:GetAttribute("InLab") == true
		if inLab then
			release(player)
			record.labOwner = userId
			record.where = "Ground"
		else
			Case.drop(player, "Leave")
		end
	end
	for _, other in table.clone(records) do
		if other.where == "Ground" and other.labOwner == userId then
			for slot, coreId in Ledger.caseSlots(other.id) do
				if
					not Ledger.move(
						coreId,
						Ledger.inCase(other.id, slot),
						Ledger.bench(userId),
						true
					)
				then
					warn(`[Contraband] could not move core of case {other.id} to the stash`)
				end
			end
			forget(other)
		end
	end
	heldBy[player] = nil
	lastValid[player] = nil
	lastSetDownAt[player] = nil
end

------------------------------------------------------------------------------
-- Loops and events
------------------------------------------------------------------------------

local function onCaseAction(player: Player, action: any)
	if not actionLimiter.allow(player) or typeof(action) ~= "string" then
		return
	end
	if action == "SetDown" then
		Case.setDown(player)
	end
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			if heldBy[player] and player.Character == character then
				Case.drop(player, "Death")
			end
		end)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function(character)
		if heldBy[player] and player.Parent ~= nil then
			-- Removed while still alive (a reset, or leaving the game before PlayerRemoving
			-- ran): the case is put down where he last stood, like a disconnect. Dead: it falls.
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local alive = humanoid ~= nil and humanoid.Health > 0
			Case.drop(player, if alive then "Leave" else "Death")
		end
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end

-- Every LAST_POSITION_EVERY s: the last spot each holder stood on a floor.
local function trackPositions()
	while true do
		task.wait(C.LAST_POSITION_EVERY)
		for player in heldBy do
			local _, root, humanoid = Guard.body(player)
			if root and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
				lastValid[player] = root.Position
			end
		end
	end
end

-- A loaded case abandoned in the city: each core goes back to the stash of its maker if he is
-- online and has room (the others stay in the case; tried again later).
local function returnCores(record: CaseRecord)
	local changed: { [Player]: boolean } = {}
	for slot, coreId in Ledger.caseSlots(record.id) do
		local core = Ledger.get(coreId)
		local maker = if core then Players:GetPlayerByUserId(core.maker) else nil
		if
			maker
			and PlayerData.isLoaded(maker)
			and Ledger.move(coreId, Ledger.inCase(record.id, slot), Ledger.bench(maker.UserId))
		then
			changed[maker] = true
		end
	end
	for maker in changed do
		labCoresChanged(maker)
		Guard.notice(maker, "An abandoned case was recovered: cores back on your bench.")
	end
end

-- Every second: carry time (Heat). Every DESPAWN_CHECK_EVERY s: empty cases nobody is near.
local function housekeeping()
	local sinceDespawn, sincePrune = 0, 0
	while true do
		task.wait(1)
		for player in heldBy do
			Heat.record(player, "carrySeconds")
		end
		sinceDespawn += 1
		sincePrune += 1
		if sincePrune >= SOLD_PRUNE_EVERY then
			sincePrune = 0
			Ledger.pruneSold(os.clock())
		end
		if sinceDespawn < DESPAWN_CHECK_EVERY then
			continue
		end
		sinceDespawn = 0
		local roots: { Vector3 } = {}
		for _, player in Players:GetPlayers() do
			local _, root = Guard.body(player)
			if root then
				table.insert(roots, root.Position)
			end
		end
		local now = os.clock()
		for _, record in table.clone(records) do
			local model = record.model
			if record.where ~= "Ground" or record.labOwner ~= nil or model == nil then
				continue
			end
			local position = model:GetPivot().Position
			for _, rootPosition in roots do
				if (rootPosition - position).Magnitude <= C.DESPAWN_CLEAR_RADIUS then
					record.lastNearAt = now
					break
				end
			end
			if Ledger.caseCount(record.id) > 0 then
				-- (a case with cores stays a long time: no police yet)
				if now - record.lastNearAt >= C.ABANDON_TIME then
					returnCores(record)
				end
				continue
			end
			if now - record.lastNearAt >= C.EMPTY_DESPAWN_TIME then
				forget(record)
			end
		end
	end
end

function Case.init()
	Ledger.configure(Config.Lab.STASH_MAX)
end

function Case.start()
	Remotes.CaseAction.OnServerEvent:Connect(onCaseAction)
	Knockout.onKnockedOut(function(info)
		local victim = info.victimPlayer
		-- (only a knockout dealt by a PLAYER knocks the case out of the hand)
		if
			victim
			and info.attackerPlayer ~= nil
			and heldBy[victim]
			and victim.Character == info.victim
		then
			Case.drop(victim, "KO")
		end
	end)
	Combat.onDamaged(function(info)
		local victim = Players:GetPlayerFromCharacter(info.victim)
		if victim and heldBy[victim] then
			Heat.record(victim, "hitsWhileCarrying")
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	task.spawn(trackPositions)
	housekeeping()
end

return Case
