--!strict
-- Destruction: heavy moves smash the map (the Bull's charge through a wall,
-- the Sentinel landing from the sky...), and it grows back a little later.
--
-- What breaks: Shared/Util/Breakable (walls, crates, pillars; never the
-- floor, a step, the part the attacker stands on, a fighter, or anything
-- marked "Unbreakable").
--   • A plain block wall is cut into pieces (PIECE studs) the first time it
--     is hit: only the pieces in reach go (they're never even created), the
--     rest of the wall stays as pieces: a hole, not the whole wall.
--   • Broken parts are hidden (no collision, their decals / lights /
--     prompts off), not destroyed: the original comes back RESTORE_AFTER
--     seconds after the last hit on it (when nobody stands inside it), and
--     its pieces go then.
-- Every client throws the debris (Remotes.WallBroken, Client KitVFX). The
-- debris collide with the map but not with fighters (collision groups).
--
--   Destruction.blast(centre, radius, push, attacker)
--       break what's within `radius` studs of `centre`; `push` = the
--       direction × strength the debris fly (studs/s); `attacker`: the
--       fighter (his feet tell where the floor is; never his own body).

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Breakable = require(ReplicatedStorage.Shared.Util.Breakable)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Destruction = {}

local RESTORE_AFTER = 25 -- seconds after the last hit on it
local MAX_PER_BLAST = 120 -- parts broken at once, at most
local MAX_PIECES = 240 -- pieces one part is cut into, at most
local MAX_CUT_PER_BLAST = 3 -- walls cut up by one blast, at most

-- Collision groups: client debris (KitVFX uses the same name) bounce on
-- the map but go through fighters.
local DEBRIS_GROUP = "Debris"
local FIGHTER_GROUP = "Fighters"
local DEAD_GROUP = "DeadBodies"
-- (also the torn limbs lying around: Combat/HeavyGore)
Destruction.DEAD_GROUP = DEAD_GROUP

type Toggle = { instance: Instance, property: string, value: any }
type Saved = {
	transparency: number,
	canCollide: boolean,
	canQuery: boolean,
	canTouch: boolean,
	toggles: { Toggle },
}
type Broken = {
	part: BasePart,
	saved: Saved,
	pieces: Folder?, -- its pieces, if it was cut up
	lastHit: number,
}

local broken: { [BasePart]: Broken } = {}
-- piece → the original it was cut from
local pieceOf: { [BasePart]: BasePart } = {}

local folder = Instance.new("Folder")
folder.Name = "Destruction"
folder.Parent = workspace

-- What hides with a broken part (and comes back with it).
local function toggle(saved: Saved, instance: Instance, property: string, value: any)
	table.insert(
		saved.toggles,
		{ instance = instance, property = property, value = (instance :: any)[property] }
	);
	(instance :: any)[property] = value
end

local function hide(part: BasePart): Saved
	local saved: Saved = {
		transparency = part.Transparency,
		canCollide = part.CanCollide,
		canQuery = part.CanQuery,
		canTouch = part.CanTouch,
		toggles = {},
	}
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part:SetAttribute("Broken", true)
	for _, child in part:GetDescendants() do
		if child:IsA("Decal") then
			toggle(saved, child, "Transparency", 1)
		elseif
			child:IsA("SurfaceGui")
			or child:IsA("BillboardGui")
			or child:IsA("Light")
			or child:IsA("ParticleEmitter")
			or child:IsA("Beam")
			or child:IsA("Trail")
			or child:IsA("ProximityPrompt")
			or child:IsA("Fire")
			or child:IsA("Smoke")
			or child:IsA("Sparkles")
		then
			toggle(saved, child, "Enabled", false)
		end
	end
	return saved
end

local function record(part: BasePart, now: number): Broken
	local entry = broken[part]
	if entry == nil then
		entry = { part = part, saved = hide(part), pieces = nil, lastHit = now }
		broken[part] = entry
	end
	entry.lastHit = now
	return entry
end

type Debris = { cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material }

-- How far `point` is from the box (`cframe`, `size`) (0 inside).
local function distanceTo(cframe: CFrame, size: Vector3, point: Vector3): number
	local p = cframe:PointToObjectSpace(point)
	local h = size / 2
	local q = Vector3.new(
		math.clamp(p.X, -h.X, h.X),
		math.clamp(p.Y, -h.Y, h.Y),
		math.clamp(p.Z, -h.Z, h.Z)
	)
	return (p - q).Magnitude
end

type Blast = {
	centre: Vector3,
	reach: number,
	feetY: number,
	thrown: { Debris },
	now: number,
}

-- Cuts the wall `part` into blocks along its big sides (a thin side kept
-- whole). The blocks in reach of the blast are thrown (never created);
-- the others take the wall's place. The original is hidden.
local function cutUp(part: Part, entry: Broken, blast: Blast)
	local pieces = Instance.new("Folder")
	pieces.Name = `{part.Name}_Pieces`
	local size = part.Size
	local thin = math.min(size.X, size.Y, size.Z)
	local step = Breakable.PIECE
	local function cells(length: number): number
		if length <= thin + 1e-3 and thin < step then
			return 1
		end
		return math.max(1, math.ceil(length / step))
	end
	local nx, ny, nz = cells(size.X), cells(size.Y), cells(size.Z)
	-- (a big block: bigger pieces, never more than MAX_PIECES)
	while nx * ny * nz > MAX_PIECES do
		step *= 1.25
		nx, ny, nz = cells(size.X), cells(size.Y), cells(size.Z)
	end
	local cell = Vector3.new(size.X / nx, size.Y / ny, size.Z / nz)
	for ix = 1, nx do
		for iy = 1, ny do
			for iz = 1, nz do
				local cframe = part.CFrame
					* CFrame.new(
						(ix - 0.5) * cell.X - size.X / 2,
						(iy - 0.5) * cell.Y - size.Y / 2,
						(iz - 0.5) * cell.Z - size.Z / 2
					)
				local inReach = distanceTo(cframe, cell, blast.centre) <= blast.reach
					and not Breakable.ground(cframe, cell, blast.feetY)
					and #blast.thrown < MAX_PER_BLAST
				if inReach then
					table.insert(blast.thrown, {
						cframe = cframe,
						size = cell,
						color = part.Color,
						material = part.Material,
					})
					continue
				end
				local piece = Instance.new("Part")
				piece.Name = "Piece"
				piece.Anchored = true
				piece.Size = cell
				piece.CFrame = cframe
				piece.Color = part.Color
				piece.Material = part.Material
				piece.MaterialVariant = part.MaterialVariant
				piece.Reflectance = part.Reflectance
				piece.Transparency = entry.saved.transparency
				piece.CastShadow = part.CastShadow
				piece.CanCollide = entry.saved.canCollide
				piece.CanQuery = entry.saved.canQuery
				piece.CanTouch = entry.saved.canTouch
				piece.CollisionGroup = part.CollisionGroup
				piece.TopSurface = Enum.SurfaceType.Smooth
				piece.BottomSurface = Enum.SurfaceType.Smooth
				piece.Parent = pieces
				pieceOf[piece] = part
			end
		end
	end
	pieces.Parent = folder
	entry.pieces = pieces
end

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.RespectCanCollide = true

function Destruction.blast(
	centre: Vector3,
	radius: number,
	push: Vector3,
	attacker: Model?
): boolean
	local root = attacker and attacker:FindFirstChild("HumanoidRootPart")
	local fighters = CollectionService:GetTagged(Config.Combat.TAG)
	local feetY = centre.Y - 3
	local under: BasePart? = nil
	if root and root:IsA("BasePart") then
		feetY = root.Position.Y - 3
		under = Breakable.support(root, fighters)
	end
	overlap.FilterDescendantsInstances = fighters
	local blast: Blast =
		{ centre = centre, reach = radius * 0.85, feetY = feetY, thrown = {}, now = os.clock() }
	local cut = 0
	local function smash(part: BasePart)
		if part == under or #blast.thrown >= MAX_PER_BLAST then
			return -- (never what he stands on)
		end
		local original = pieceOf[part]
		if original then
			-- a piece of an already cut wall: it goes for good
			if
				distanceTo(part.CFrame, part.Size, centre) > blast.reach
				or Breakable.ground(part.CFrame, part.Size, feetY)
			then
				return
			end
			record(original, blast.now)
			table.insert(blast.thrown, {
				cframe = part.CFrame,
				size = part.Size,
				color = part.Color,
				material = part.Material,
			})
			pieceOf[part] = nil
			part:Destroy()
			return
		end
		local how = Breakable.check(part, feetY)
		if how == nil then
			return
		end
		-- (the radius query works on bounding boxes: check the real shape)
		if
			distanceTo(part.CFrame, part.Size, centre)
			> (if how == "pieces" then blast.reach else radius)
		then
			return
		end
		if how == "whole" then
			record(part, blast.now)
			table.insert(blast.thrown, {
				cframe = part.CFrame,
				size = part.Size,
				color = part.Color,
				material = part.Material,
			})
			return
		end
		if cut >= MAX_CUT_PER_BLAST then
			return
		end
		cut += 1
		cutUp(part :: Part, record(part, blast.now), blast)
	end
	for _, part in workspace:GetPartBoundsInRadius(centre, radius, overlap) do
		if part.Parent ~= nil then
			smash(part)
		end
	end
	if #blast.thrown > 0 then
		Remotes.WallBroken:FireAllClients(blast.thrown, centre, push)
	end
	return #blast.thrown > 0
end

-- Is a fighter standing inside `part`? (don't trap them in it)
local occupiedParams = OverlapParams.new()
occupiedParams.FilterType = Enum.RaycastFilterType.Include
local function occupied(part: BasePart): boolean
	occupiedParams.FilterDescendantsInstances = CollectionService:GetTagged(Config.Combat.TAG)
	return #workspace:GetPartBoundsInBox(part.CFrame, part.Size, occupiedParams) > 0
end

local function restore(entry: Broken)
	local part = entry.part
	broken[part] = nil
	if entry.pieces then
		for _, piece in entry.pieces:GetChildren() do
			if piece:IsA("BasePart") then
				pieceOf[piece] = nil
			end
		end
		entry.pieces:Destroy()
	end
	if part.Parent == nil then
		return
	end
	part.Transparency = entry.saved.transparency
	part.CanCollide = entry.saved.canCollide
	part.CanQuery = entry.saved.canQuery
	part.CanTouch = entry.saved.canTouch
	for _, saved in entry.saved.toggles do
		if saved.instance.Parent ~= nil then
			(saved.instance :: any)[saved.property] = saved.value
		end
	end
	part:SetAttribute("Broken", nil)
end

-- Fighters in their collision group (debris go through them).
local function intoFighterGroup(model: Instance)
	local function set(descendant: Instance)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = FIGHTER_GROUP
		end
	end
	for _, descendant in model:GetDescendants() do
		set(descendant)
	end
	local added = model.DescendantAdded:Connect(set)
	-- Dead: the body no longer touches the living (standing / crouching on a
	-- ragdoll flung them), only the map.
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			added:Disconnect()
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.CollisionGroup = DEAD_GROUP
				end
			end
		end)
	end
end

function Destruction.init()
	PhysicsService:RegisterCollisionGroup(DEBRIS_GROUP)
	PhysicsService:RegisterCollisionGroup(FIGHTER_GROUP)
	PhysicsService:CollisionGroupSetCollidable(DEBRIS_GROUP, FIGHTER_GROUP, false)
	PhysicsService:RegisterCollisionGroup(DEAD_GROUP)
	PhysicsService:CollisionGroupSetCollidable(DEAD_GROUP, FIGHTER_GROUP, false)
end

function Destruction.start()
	local tag = Config.Combat.TAG
	CollectionService:GetInstanceAddedSignal(tag):Connect(intoFighterGroup)
	for _, model in CollectionService:GetTagged(tag) do
		intoFighterGroup(model)
	end
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextCheck then
			return
		end
		nextCheck = now + 1
		for _, entry in broken do
			if now - entry.lastHit >= RESTORE_AFTER then
				if occupied(entry.part) then
					entry.lastHit = now - RESTORE_AFTER + 1 -- (try again in a second)
				else
					restore(entry)
				end
			end
		end
	end)
end

return Destruction
