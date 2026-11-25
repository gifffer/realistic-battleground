--!strict
-- Apartments: the lab doors in the city and the private labs behind them.
--
-- THE DOORS (Shared/Contraband/Sites): three existing wooden doors of the city. At start (once
-- the city is built) each one is:
--   • made Unbreakable (the door, its kick plate / handle, and the jambs, transom, threshold,
--     fanlight around it): heavy moves never open a way in;
--   • turned into a locked CityDoor (group "Lab_<id>", hinge on its real edge, opening INTO the
--     building): it never opens when someone walks by, only for a moment (CityDoors.pulse) when
--     someone goes in or comes out;
--   • given an invisible "Enter" prompt (LabDoorPrompt) on the street side.
-- A door whose parts are not found (the city changed) is skipped with a warning.
--
-- THE LABS: with Config.Lab.ANY_DOOR every door opens YOUR lab (one per player, built from
-- parts by LabBuilder the first time you go in, destroyed when you leave the server). A lab
-- takes the lowest free slot of the row far from the city. Since the apartment rework the "lab"
-- is a whole run-down flat with the lab hidden in its back bedroom: the prompts never say
-- "lab" (the city door says "Enter" + the address, the flat's front door says "Leave").
--   Enter    alive, standing, idle, not extracting / selling / in a duel / in a cutscene, not
--            hit in the last NO_ENTRY_AFTER_HIT s and not in combat (CombatUntil: the ATTACKER
--            too) ("Not while fighting."). Carrying a case is fine. All of it is checked again
--            right before the teleport (streaming the lab in can take a moment).
--            → the door opens a moment, you appear at the lab's Spawn; player attributes
--            InLab = true and ZoneLook = "Lab" (ZoneLookController blends the lab look).
--   Leave    the "Leave" prompt on the lab's door: back out of the door you came in by.
--   Respawn  (died in the lab) InLab / ZoneLook are cleared; the lab stays.
--   Intruder once a second, any OTHER player found inside a lab's box is sent to a city spawn
--            (a cheater's client can move his own character anywhere; the prompts in a lab and
--            the cases lying there check the owner anyway).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sites = require(ReplicatedStorage.Shared.Contraband.Sites)
local CityDoors = require(script.Parent.Parent.CityDoors)
local Combat = require(script.Parent.Parent.Combat)
local Duels = require(script.Parent.Parent.Duels)
local Knockout = require(script.Parent.Parent.Knockout)
local Case = require(script.Parent.Case)
local Guard = require(script.Parent.Guard)
local LabBuilder = require(script.Parent.LabBuilder)
local TripLog = require(script.Parent.TripLog)

local L = Config.Lab

local DOOR_TAG = "CityDoor"
local FRAME_NAMES: { [string]: boolean } =
	{ Jamb = true, Transom = true, Threshold = true, Fanlight = true }
local LEAF_SEARCH = 1 -- studs: a "Door" part this close to the listed centre is the leaf
local FRAME_SEARCH = 4 -- studs: frame parts this close to a leaf are made Unbreakable

export type LabInfo = {
	owner: Player,
	slot: number,
	model: Model,
	enteredFrom: string?, -- the door site id used to come in
}

local Apartments = {}

local labs: { [Player]: LabInfo } = {}
local usedSlots: { [number]: Player } = {}
local readyDoors: { [string]: boolean } = {} -- site id → its door was set up
local moving: { [Player]: boolean } = {} -- a teleport in / out is under way
local builtCallbacks: { (Player, Model) -> () } = {}
local enteredCallbacks: { (Player, boolean) -> () } = {}

------------------------------------------------------------------------------
-- Reading the labs
------------------------------------------------------------------------------

-- Is the player inside his own lab right now (attribute + really in its box)?
function Apartments.isInOwnLab(player: Player): boolean
	local info = labs[player]
	if info == nil or player:GetAttribute("InLab") ~= true then
		return false
	end
	local _, root = Guard.body(player)
	return root ~= nil and LabBuilder.contains(info.slot, root.Position, 1)
end

-- A named part of the player's lab ("VatCore", "BenchAnchor"...), or nil.
function Apartments.labPart(player: Player, name: string): BasePart?
	local info = labs[player]
	local part = if info then info.model:FindFirstChild(name) else nil
	return if part and part:IsA("BasePart") then part else nil
end

-- `callback(player, model)` right after a lab is built (Lab adds its prompts).
function Apartments.onLabBuilt(callback: (Player, Model) -> ())
	table.insert(builtCallbacks, callback)
end

-- `callback(player, inLab)` after the player went in (true) or came out (false) of his lab.
function Apartments.onMoved(callback: (Player, boolean) -> ())
	table.insert(enteredCallbacks, callback)
end

local function fireMoved(player: Player, inLab: boolean)
	for _, callback in enteredCallbacks do
		task.spawn(callback, player, inLab)
	end
end

------------------------------------------------------------------------------
-- Labs
------------------------------------------------------------------------------

local function getOrBuildLab(player: Player): LabInfo
	local info = labs[player]
	if info and info.model.Parent ~= nil then
		return info
	end
	-- (a lab model that vanished is rebuilt in the SAME slot: no slot leaks)
	local slot = if info then info.slot else 1
	while info == nil do
		local user: Player? = usedSlots[slot]
		if user == nil or user == player then
			break
		end
		slot += 1
	end
	usedSlots[slot] = player
	local model = LabBuilder.build(slot, player.UserId)
	model.Parent = Guard.worldFolder("Labs")
	info = { owner = player, slot = slot, model = model, enteredFrom = nil }
	labs[player] = info
	local leave = model:FindFirstChild("ExitDoor")
	if leave and leave:IsA("BasePart") then
		local prompt = Guard.makePrompt(
			leave,
			"LeavePrompt",
			"Leave",
			"Front door",
			L.ENTER_HOLD,
			L.PROMPT_DISTANCE,
			false
		)
		prompt.Triggered:Connect(function(who: Player)
			Apartments.leave(who, prompt)
		end)
	end
	for _, callback in builtCallbacks do
		local ok: boolean, problem: any = pcall(callback, player, model)
		if not ok then
			warn(`[Contraband] lab built callback failed: {problem}`)
		end
	end
	return info :: LabInfo
end

-- Seconds between the door starting to open and the teleport (≈ 85 % open).
local DOOR_OPEN_WAIT = 0.21

local function clearZone(player: Player)
	player:SetAttribute("InLab", nil)
	player:SetAttribute("ZoneLook", nil)
end

-- Moves the character to `cframe` after asking Roblox to stream the area in (no fall into the
-- void when StreamingEnabled is on) and letting the door open (DOOR_OPEN_WAIT). Returns false
-- if the body is gone meanwhile, or if `stillOk` (checked AFTER the waits) says no.
local function teleport(player: Player, cframe: CFrame, stillOk: (() -> boolean)?): boolean
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, 3)
	end)
	-- The door has just started to swing (CityDoors.pulse: 0.35 s, Quad Out): the body goes
	-- through once it is mostly open, not while it is still shut; the player's screen fades
	-- around the cut meanwhile (ZoneLookController, "DoorCut").
	Guard.send(player, "DoorCut", {})
	task.wait(DOOR_OPEN_WAIT)
	local character, root = Guard.body(player)
	if character == nil or root == nil then
		return false
	end
	if stillOk and not stillOk() then
		return false
	end
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(cframe)
	Case.noteTeleport(player, cframe.Position)
	return true
end

-- Fighting right now? (hit lately, in combat as the victim OR the attacker, not idle)
local function isFighting(player: Player): boolean
	local character = player.Character
	if character == nil then
		return true
	end
	if os.clock() - Knockout.lastHitAt(character) < L.NO_ENTRY_AFTER_HIT then
		return true
	end
	local combatUntil = player:GetAttribute("CombatUntil")
	if typeof(combatUntil) == "number" and combatUntil > workspace:GetServerTimeNow() then
		return true
	end
	return not Combat.isIdle(character)
end

-- The ground under a site's exit point, standing there facing the street.
local function exitCFrame(site: Sites.DoorSite): CFrame
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local from = site.exitAt + Vector3.new(0, 6, 0)
	local hit = workspace:Raycast(from, Vector3.new(0, -20, 0), params)
	local feet = if hit then hit.Position else site.exitAt - Vector3.new(0, 1.5, 0)
	local position = feet + Vector3.new(0, 3.1, 0)
	return CFrame.lookAt(position, position + site.outward)
end

------------------------------------------------------------------------------
-- Enter / leave
------------------------------------------------------------------------------

local function commonChecks(player: Player, prompt: ProximityPrompt): boolean
	if moving[player] or not Guard.promptAllowed(player, prompt) then
		return false
	end
	local character = player.Character
	if character == nil or character:GetAttribute("CaseOpen") == true then
		return false
	end
	return not Duels.isInDuel(player)
end

function Apartments.enter(player: Player, site: Sites.DoorSite, prompt: ProximityPrompt)
	if not commonChecks(player, prompt) or player:GetAttribute("InLab") == true then
		return
	end
	if isFighting(player) then
		Guard.notice(player, "Not while fighting.")
		return
	end
	local info = getOrBuildLab(player)
	local spawn = info.model:FindFirstChild("Spawn")
	if spawn == nil or not spawn:IsA("BasePart") then
		return
	end
	moving[player] = true
	info.enteredFrom = site.id
	CityDoors.pulse(Sites.doorGroup(site.id), L.DOOR_PULSE)
	TripLog.stop(player) -- (no trip inside a lab)
	task.spawn(function()
		local ok = teleport(player, spawn.CFrame, function()
			-- (the same checks again: he may have been hit, grabbed or knocked out meanwhile)
			local character = player.Character
			return Guard.canAct(player)
				and not isFighting(player)
				and not Duels.isInDuel(player)
				and character ~= nil
				and character:GetAttribute("CaseOpen") ~= true
		end)
		moving[player] = nil
		if ok and player.Parent ~= nil then
			player:SetAttribute("InLab", true)
			player:SetAttribute("ZoneLook", "Lab")
			Guard.debug(`{player.Name} entered his lab (slot {info.slot}) by {site.id}`)
			fireMoved(player, true)
		end
	end)
end

function Apartments.leave(player: Player, prompt: ProximityPrompt)
	local info = labs[player]
	if info == nil or prompt.Parent == nil or not prompt:IsDescendantOf(info.model) then
		return -- (only the owner's own lab door)
	end
	if not commonChecks(player, prompt) then
		return
	end
	local site = Sites.door(info.enteredFrom or "") or Sites.DOORS[1]
	moving[player] = true
	CityDoors.pulse(Sites.doorGroup(site.id), L.DOOR_PULSE)
	local target = exitCFrame(site)
	task.spawn(function()
		local ok = teleport(player, target)
		moving[player] = nil
		if ok and player.Parent ~= nil then
			clearZone(player)
			-- a new trip from the door if he carries a loaded case
			TripLog.stop(player)
			Case.refreshTrip(player)
			if TripLog.isActive(player) then
				TripLog.restart(player, target.Position)
			end
			fireMoved(player, false)
		end
	end)
end

------------------------------------------------------------------------------
-- Doors in the city
------------------------------------------------------------------------------

-- Every BasePart of the city by name (one pass over the city).
local function partsByName(city: Instance): { [string]: { BasePart } }
	local found: { [string]: { BasePart } } = {}
	for _, descendant in city:GetDescendants() do
		if descendant:IsA("BasePart") then
			local name = descendant.Name
			if name == "Door" or FRAME_NAMES[name] then
				local list = found[name]
				if list == nil then
					list = {}
					found[name] = list
				end
				table.insert(list, descendant)
			end
		end
	end
	return found
end

local function closest(list: { BasePart }?, position: Vector3, within: number): BasePart?
	local best: BasePart? = nil
	local bestDistance = within
	if list == nil then
		return nil
	end
	for _, part in list do
		local distance = (part.Position - position).Magnitude
		if distance <= bestDistance then
			best, bestDistance = part, distance
		end
	end
	return best
end

-- The swing (±90°) that moves the leaf's free end AWAY from the street.
local function openAngleFor(leaf: BasePart, hingeZ: number, outward: Vector3): number
	local freeEnd = Vector3.new(0, 0, (leaf.Position.Z - hingeZ) * 2)
	for _, angle in { 90, -90 } do
		local turned = CFrame.Angles(0, math.rad(angle), 0) * freeEnd
		if turned:Dot(outward) < 0 then
			return angle
		end
	end
	return 90
end

-- A small cold strip light over a lab door (so it can be found at night): a dark hood on the
-- wall just above the leaves, a thin cold neon line under it. Found by a ray from the street
-- onto the wall (no wall found: no light).
local function markDoor(site: Sites.DoorSite, leaves: { BasePart })
	local centre = Vector3.zero
	local top = -math.huge
	local width = 0
	for _, leaf in leaves do
		centre += leaf.Position
		top = math.max(top, leaf.Position.Y + leaf.Size.Y / 2)
		width += math.max(leaf.Size.X, leaf.Size.Z)
	end
	centre /= #leaves
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, leaf in leaves do
		table.insert(ignore, leaf)
	end
	params.FilterDescendantsInstances = ignore
	local at = Vector3.new(centre.X, top + 0.5, centre.Z)
	local hit = workspace:Raycast(at + site.outward * 4, -site.outward * 6, params)
	if hit == nil then
		return
	end
	local folder = Guard.worldFolder("ContrabandSites")
	local along = site.outward:Cross(Vector3.yAxis).Unit
	local face = hit.Position
	local length = math.clamp(width * 0.8, 1.2, 3)
	local function piece(
		name: string,
		size: Vector3,
		position: Vector3,
		color: Color3,
		neon: boolean
	)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = CFrame.fromMatrix(position, along, Vector3.yAxis)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = if neon then Enum.Material.Neon else Enum.Material.Metal
		part.Color = color
		part:SetAttribute("Unbreakable", true)
		part.Parent = folder
		return part
	end
	piece(
		`LabDoorHood_{site.id}`,
		Vector3.new(length, 0.14, 0.4),
		face + site.outward * 0.2,
		Color3.fromRGB(40, 42, 44),
		false
	)
	local strip = piece(
		`LabDoorStrip_{site.id}`,
		Vector3.new(length - 0.2, 0.04, 0.06),
		face + site.outward * 0.3 - Vector3.new(0, 0.09, 0),
		Color3.fromRGB(170, 215, 235),
		true
	)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Brightness = 0.8
	light.Range = 7
	light.Angle = 90
	light.Color = Color3.fromRGB(170, 215, 235)
	light.Shadows = false
	light.Parent = strip
end

local function setUpDoor(site: Sites.DoorSite, byName: { [string]: { BasePart } }): boolean
	local leaves: { BasePart } = {}
	for _, leafInfo in site.leaves do
		local leaf = closest(byName.Door, leafInfo.position, LEAF_SEARCH)
		if leaf == nil then
			warn(
				`[Contraband] lab door {site.id}: no "Door" part near {leafInfo.position}; door skipped`
			)
			return false
		end
		table.insert(leaves, leaf)
	end
	local group = Sites.doorGroup(site.id)
	for index, leaf in leaves do
		local hingeZ = site.leaves[index].hingeZ
		local angle = openAngleFor(leaf, hingeZ, site.outward)
		local parts: { BasePart } = { leaf }
		for _, child in leaf:GetDescendants() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
		for _, part in parts do
			part:SetAttribute("Unbreakable", true)
			if part:HasTag(DOOR_TAG) then
				-- (already a city door of another group: keep its group, but lock it so it
				-- never opens by itself; the teleport works without the swing)
				part:SetAttribute("Locked", true)
				continue
			end
			-- attributes FIRST: CityDoors reads them when the tag is added
			part:SetAttribute("DoorGroup", group)
			part:SetAttribute("HingeX", leaf.Position.X)
			part:SetAttribute("HingeZ", hingeZ)
			part:SetAttribute("OpenAngle", angle)
			part:SetAttribute("Locked", true)
			CollectionService:AddTag(part, DOOR_TAG)
		end
		for name in FRAME_NAMES do
			local frameParts = byName[name]
			if frameParts == nil then
				continue
			end
			for _, part in frameParts do
				if (part.Position - leaf.Position).Magnitude <= FRAME_SEARCH then
					part:SetAttribute("Unbreakable", true)
				end
			end
		end
	end
	markDoor(site, leaves)
	local promptPart = Guard.marker(
		`LabDoor_{site.id}`,
		CFrame.new(site.promptAt),
		Guard.worldFolder("ContrabandSites")
	)
	promptPart:SetAttribute("Unbreakable", true)
	local prompt = Guard.makePrompt(
		promptPart,
		"LabDoorPrompt",
		"Enter",
		site.label,
		L.ENTER_HOLD,
		L.ENTER_DISTANCE,
		false
	)
	prompt.Triggered:Connect(function(player: Player)
		Apartments.enter(player, site, prompt)
	end)
	return true
end

local function setUpDoors()
	local city = Guard.waitForCity(180)
	if city == nil then
		warn("[Contraband] no city: the lab doors are not set up")
		return
	end
	local byName = partsByName(city)
	for _, site in Sites.DOORS do
		if setUpDoor(site, byName) then
			readyDoors[site.id] = true
		end
	end
end

------------------------------------------------------------------------------
-- Intruders, respawns, leaving
------------------------------------------------------------------------------

local function checkIntruders()
	for owner, info in labs do
		for _, other in Players:GetPlayers() do
			if other == owner or moving[other] then
				continue
			end
			local character = other.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if
				root
				and root:IsA("BasePart")
				and LabBuilder.contains(info.slot, root.Position, 4)
			then
				warn(
					`[Contraband] {other.Name} was inside {owner.Name}'s lab: sent back to the city`
				)
				local spawn = Knockout.pickSpawn(other)
				if spawn and character then
					character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
				end
				clearZone(other)
			end
		end
	end
end

-- The player leaves the server (Contraband/init, AFTER the cases and the stash are handled).
function Apartments.onLeaving(player: Player)
	local info = labs[player]
	labs[player] = nil
	moving[player] = nil
	if info then
		if usedSlots[info.slot] == player then
			usedSlots[info.slot] = nil
		end
		info.model:Destroy()
	end
end

function Apartments.start()
	-- (Case decides "dropped / set down in the lab" by position, never by the attribute alone)
	Case.setLabResolver(function(player: Player, position: Vector3): boolean
		local info = labs[player]
		return info ~= nil and LabBuilder.contains(info.slot, position, 1)
	end)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			if not moving[player] then
				clearZone(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	task.spawn(setUpDoors)
	while true do
		task.wait(L.INTRUDER_CHECK)
		checkIntruders()
	end
end

return Apartments
