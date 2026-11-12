--!strict
-- Destruction: heavy moves smash the map (the Bull's charge through a wall,
-- the Sentinel landing from the sky...), and it grows back a little later.
--
-- What breaks: Shared/Util/Breakable (walls, crates, pillars; never the
-- floor, a fighter, or anything marked "Unbreakable").
--   • A plain block wall is first cut into pieces (PIECE studs) so only the
--     part around the impact goes: a hole, not the whole wall.
--   • Broken parts are hidden (no collision), not destroyed: the original
--     comes back RESTORE_AFTER seconds after the last hit on it (when nobody
--     stands inside it). Its pieces go then.
-- Every client throws the debris (Remotes.WallBroken, Client KitVFX).
--
--   Destruction.blast(centre, radius, push, attacker)
--       break what's within `radius` studs of `centre`; `push` = the
--       direction × strength the debris fly (studs/s); `attacker`: the
--       fighter (his feet tell where the floor is; never his own body).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Breakable = require(ReplicatedStorage.Shared.Util.Breakable)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Destruction = {}

local RESTORE_AFTER = 25 -- seconds after the last hit on it
local MAX_PER_BLAST = 120 -- parts broken at once, at most
local MAX_PIECES = 240 -- pieces one part is cut into, at most

type Saved = { transparency: number, canCollide: boolean, canQuery: boolean, canTouch: boolean }
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

local function hide(part: BasePart): Saved
	local saved = {
		transparency = part.Transparency,
		canCollide = part.CanCollide,
		canQuery = part.CanQuery,
		canTouch = part.CanTouch,
	}
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part:SetAttribute("Broken", true)
	return saved
end

-- Cuts the wall `part` into blocks along its two big sides (the thin one
-- kept whole). The original is hidden; the pieces take its place.
local function cutUp(part: Part, entry: Broken): Folder
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
				local piece = Instance.new("Part")
				piece.Name = "Piece"
				piece.Anchored = true
				piece.Size = cell
				piece.CFrame = part.CFrame
					* CFrame.new(
						(ix - 0.5) * cell.X - size.X / 2,
						(iy - 0.5) * cell.Y - size.Y / 2,
						(iz - 0.5) * cell.Z - size.Z / 2
					)
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
	return pieces
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

local function debrisOf(part: BasePart): Debris
	return { cframe = part.CFrame, size = part.Size, color = part.Color, material = part.Material }
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
	local feetY = if root and root:IsA("BasePart") then root.Position.Y - 3 else centre.Y - 3
	overlap.FilterDescendantsInstances = CollectionService:GetTagged(Config.Combat.TAG)
	local now = os.clock()
	local thrown: { Debris } = {}
	local function smash(part: BasePart)
		if #thrown >= MAX_PER_BLAST then
			return
		end
		local original = pieceOf[part]
		if original then
			-- a piece of an already cut wall: it goes for good
			record(original, now)
			table.insert(thrown, debrisOf(part))
			pieceOf[part] = nil
			part:Destroy()
			return
		end
		local how = Breakable.check(part, feetY)
		if how == nil then
			return
		end
		local entry = record(part, now)
		if how == "whole" then
			table.insert(thrown, debrisOf(part))
			return
		end
		-- cut up, then only the pieces within reach go
		local pieces = cutUp(part :: Part, entry)
		entry.pieces = pieces
		for _, child in pieces:GetChildren() do
			local piece = child :: BasePart
			local nearest = piece.CFrame:PointToObjectSpace(centre)
			local half = piece.Size / 2
			local clamped = Vector3.new(
				math.clamp(nearest.X, -half.X, half.X),
				math.clamp(nearest.Y, -half.Y, half.Y),
				math.clamp(nearest.Z, -half.Z, half.Z)
			)
			if (nearest - clamped).Magnitude <= radius * 0.85 and #thrown < MAX_PER_BLAST then
				table.insert(thrown, debrisOf(piece))
				pieceOf[piece] = nil
				piece:Destroy()
			end
		end
	end
	for _, part in workspace:GetPartBoundsInRadius(centre, radius, overlap) do
		if part.Parent ~= nil then
			smash(part)
		end
	end
	if #thrown > 0 then
		Remotes.WallBroken:FireAllClients(thrown, centre, push)
	end
	return #thrown > 0
end

-- Is a fighter standing inside `part`? (don't trap them in it)
local function occupied(part: BasePart): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged(Config.Combat.TAG)
	return #workspace:GetPartBoundsInBox(part.CFrame, part.Size, params) > 0
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
	part:SetAttribute("Broken", nil)
end

function Destruction.start()
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
