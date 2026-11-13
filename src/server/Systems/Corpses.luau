--!strict
-- Corpses: the body of a player killed by a finisher stays where it fell
-- for Config.Knockout.FINISHER_BODY_TIME seconds after the killing blow,
-- although the player respawns sooner (RESPAWN_TIME) and Roblox removes
-- their old body then. (Training dummies are not players: they keep their
-- own time, see TrainingDummies.)
--
-- How: when Roblox removes the body (respawn, leaving the game), a COPY of
-- it takes its place in workspace.Corpses for the time left:
--   • every part anchored where it lies: a frozen body, no physics (a body
--     cut in two keeps its pieces where they fell), with no collisions, no
--     touches and no queries (out of the hitboxes, raycasts and beams);
--   • its attributes kept (HeadBlown, ArmTorn, Gash_*, Incinerated,
--     Bisected...): every client draws its wounds again, as for a body
--     seen later (Client: Config.Combat.CORPSE_TAG watchers);
--   • not a fighter: its tags are replaced by Config.Combat.CORPSE_TAG
--     (no Config.Combat.TAG) and no system registers it;
--   • its Humanoid kept (R6 shirts / pants need one to show) but inert,
--     with no name or health bar; scripts, prompts, sounds... removed.
-- With deferred signals, Roblox may have already taken the body apart when
-- we hear that it is removed: a copy is made just before the respawn, and
-- replaced by a fresh one if the body is still whole when it is removed.
--
--   Corpses.track(model)   a player's body was just finished off (Knockout)
--   Corpses.onCopy(fn)     fn(copy, original) once a copy is in the game
--                          (Combat: the bone of a torn arm, still takeable)

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Corpse = require(ReplicatedStorage.Shared.Util.Corpse)

local Corpses = {}

local FOLDER_NAME = "Corpses"
local SNAPSHOT_LEAD = 0.4 -- seconds before the respawn: the ready copy
local MIN_TIME_LEFT = 0.5 -- less than this left: no copy at all

type Entry = {
	model: Model,
	killedAt: number, -- workspace:GetServerTimeNow()
	snapshot: Model?, -- ready copy, not in the game yet
	connections: { RBXScriptConnection },
	done: boolean,
}

local entries: { [Model]: Entry } = {}
local folder: Folder? = nil
local copyCallbacks: { (copy: Model, original: Model) -> () } = {}

local function corpseFolder(): Folder
	local current = folder
	if current and current.Parent == workspace then
		return current
	end
	local found = workspace:FindFirstChild(FOLDER_NAME)
	if found and found:IsA("Folder") then
		folder = found
		return found
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = workspace
	folder = created
	return created
end

-- Still a whole body (Roblox's Destroy empties it: nothing to copy then).
local function isWhole(model: Model): boolean
	return model:FindFirstChild("Torso") ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- No longer a fighter (a client reading them sees a plain dead body).
local FIGHTER_ATTRIBUTES = { "KnockedOut", "KOEndsAt", "BeingFinished", "Protected", "InCinematic" }
local function clearFighterAttributes(copy: Model)
	for _, name in FIGHTER_ATTRIBUTES do
		copy:SetAttribute(name, nil)
	end
end

-- Makes `copy` a frozen, inert body (see the header).
local function freeze(copy: Model)
	for _, tag in copy:GetTags() do
		copy:RemoveTag(tag)
	end
	copy:AddTag(Config.Combat.CORPSE_TAG)
	-- (whole, or not at all: the wounds are drawn on all its parts)
	copy.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- A joint or constraint to something outside the copy (an arm held in
	-- the killer's fist...) would tie the killer to it: removed.
	local function outside(item: Instance?): boolean
		return item ~= nil and not item:IsDescendantOf(copy)
	end
	local removed: { Instance } = {}
	for _, item in copy:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
		elseif item:IsA("JointInstance") then
			if outside(item.Part0) or outside(item.Part1) then
				table.insert(removed, item)
			end
		elseif item:IsA("WeldConstraint") or item:IsA("NoCollisionConstraint") then
			if outside(item.Part0) or outside(item.Part1) then
				table.insert(removed, item)
			end
		elseif item:IsA("Constraint") then
			if outside(item.Attachment0) or outside(item.Attachment1) then
				table.insert(removed, item)
			end
		elseif
			item:IsA("LuaSourceContainer")
			or item:IsA("ProximityPrompt")
			or item:IsA("ClickDetector")
			or item:IsA("ForceField")
			or item:IsA("Sound")
		then
			table.insert(removed, item)
		end
	end
	for _, item in removed do
		item:Destroy()
	end

	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.EvaluateStateMachine = false
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.NameDisplayDistance = 0
		humanoid.HealthDisplayDistance = 0
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	clearFighterAttributes(copy)
end

-- A frozen copy of `model` (nil if it can't be copied).
local function copyOf(model: Model): Model?
	local ok, result = pcall(function(): Model?
		local archivable = model.Archivable
		model.Archivable = true -- (a player's character isn't, by default)
		local copy: Model? = model:Clone()
		model.Archivable = archivable
		if copy == nil then
			return nil
		end
		freeze(copy)
		return copy
	end)
	if not ok then
		warn("[Corpses] could not copy a body:", result)
		return nil
	end
	return result
end

local function close(entry: Entry)
	if entry.done then
		return
	end
	entry.done = true
	for _, connection in entry.connections do
		connection:Disconnect()
	end
	table.clear(entry.connections)
	if entries[entry.model] == entry then
		entries[entry.model] = nil
	end
	local snapshot = entry.snapshot
	entry.snapshot = nil
	if snapshot then
		snapshot:Destroy()
	end
end

-- The body is being removed: its copy takes its place for the time left.
local function release(entry: Entry)
	if entry.done then
		return
	end
	local left = entry.killedAt + Config.Knockout.FINISHER_BODY_TIME - workspace:GetServerTimeNow()
	local corpse: Model? = nil
	if left >= MIN_TIME_LEFT then
		-- fresh if we can (exact pose, latest wounds), else the ready one
		if isWhole(entry.model) then
			corpse = copyOf(entry.model)
		end
		local snapshot = entry.snapshot
		if corpse == nil and snapshot then
			entry.snapshot = nil
			-- (a wound added since: the attributes outlive the body's Destroy)
			for name, value in entry.model:GetAttributes() do
				snapshot:SetAttribute(name, value)
			end
			clearFighterAttributes(snapshot)
			corpse = snapshot
		end
	end
	close(entry)
	if corpse then
		corpse.Parent = corpseFolder()
		Debris:AddItem(corpse, left)
		for _, callback in copyCallbacks do
			task.spawn(callback, corpse, entry.model)
		end
	end
end

-- `callback(copy, original)` each time a copy takes a body's place (it is
-- in the game then; the original is being removed).
function Corpses.onCopy(callback: (copy: Model, original: Model) -> ())
	table.insert(copyCallbacks, callback)
end

function Corpses.track(model: Model)
	local player = Players:GetPlayerFromCharacter(model)
	if player == nil or entries[model] then
		return
	end
	local killedAt = workspace:GetServerTimeNow()
	model:SetAttribute(Corpse.ATTRIBUTE, killedAt)
	local entry: Entry = {
		model = model,
		killedAt = killedAt,
		snapshot = nil,
		connections = {},
		done = false,
	}
	entries[model] = entry
	local function onRemoved()
		release(entry)
	end
	table.insert(
		entry.connections,
		player.CharacterRemoving:Connect(function(character: Model)
			if character == model then
				onRemoved()
			end
		end)
	)
	table.insert(entry.connections, model.Destroying:Connect(onRemoved))
	table.insert(
		entry.connections,
		model.AncestryChanged:Connect(function()
			if model.Parent == nil then
				onRemoved()
			end
		end)
	)
	-- the ready copy, just before Roblox respawns them
	task.delay(math.max(0, Players.RespawnTime - SNAPSHOT_LEAD), function()
		if entry.done or entry.snapshot or not isWhole(model) or model.Parent == nil then
			return
		end
		entry.snapshot = copyOf(model)
	end)
	-- never removed (no respawn?): it lies there itself, nothing to keep
	task.delay(Config.Knockout.FINISHER_BODY_TIME + 1, function()
		close(entry)
	end)
end

function Corpses.init()
	corpseFolder()
end

return Corpses
