--!strict
-- Skin: the front of the patient's torso, in layers you can cut: skin,
-- yellow fat, red muscle, then the dark cavity with the organs. Each layer
-- is a 32 x 32 grid of cells drawn as a few merged tiles (the same idea as
-- Combat/Gashes, kept apart so this folder can be deleted alone).
--
-- Torso space: front = -Z (up on the table), the front face spans x and y
-- from -1 to 1. Layers (z): skin -0.50..-0.46, fat ..-0.43, muscle ..-0.40.
--
--   Skin.new(torso, parent, skinColor) -> State
--   Skin.onFront(state, origin, direction) -> Vector2?   where a ray meets the front
--   Skin.cut(state, a, b, stroke) -> { Vector2 }        cells cut along a..b (one depth per stroke)
--   Skin.deepen(state, at) -> { Vector2 }               cut deeper right there
--   Skin.spread(state, at, amount) -> boolean           pull the edges apart near `at`
--   Skin.nearCut(state, at, cells) -> boolean
--   Skin.depthAt(state, at) -> number                   0 intact .. 3 open
--   Skin.update(state)                                  rebuilds what changed
--   Skin.toWorld(state, at, z?) -> Vector3

local Make = require(script.Parent.Make)

local Skin = {}

local N = 32
local CELL = 2 / N
local MAX_OPEN = 11 -- cells: how far the edges can be pulled apart
local GAPE_DELAY = 0.4 -- a fresh cut opens a little by itself after this

local FAT = Color3.fromRGB(222, 188, 98)
local MUSCLE = Color3.fromRGB(112, 14, 14)
local MUSCLE_CUT = Color3.fromRGB(70, 6, 8)
local RAW_EDGE = Color3.fromRGB(176, 52, 46)

type Grid = { { number } }
type Mask = { { boolean } }

export type State = {
	frame: CFrame,
	folder: Model,
	skinColor: Color3,
	depth: Grid, -- 0 intact .. 3 cut through the muscle
	open: Grid, -- how far its edges are pulled apart (cells)
	cutAt: Grid,
	stroke: Grid, -- the last stroke that cut it deeper
	tiles: { [string]: { BasePart } },
	sides: { [number]: BasePart }, -- the torso's right (1) and left (-1) sides
	dirty: boolean,
	builtAt: number,
}

local function grid(value: number): Grid
	local g: Grid = {}
	for i = 1, N do
		local column = table.create(N, value)
		g[i] = column
	end
	return g
end

local function mask(): Mask
	local m: Mask = {}
	for i = 1, N do
		m[i] = table.create(N, false)
	end
	return m
end

-- Cell (i, j) of a point of the front (j: rows from the top, +y).
local function cellOf(at: Vector2): (number, number)
	return math.clamp(math.floor((at.X + 1) / CELL) + 1, 1, N),
		math.clamp(math.floor((1 - at.Y) / CELL) + 1, 1, N)
end

local function centreOf(i: number, j: number): Vector2
	return Vector2.new(-1 + (i - 0.5) * CELL, 1 - (j - 0.5) * CELL)
end

-- Greedy cover of the kept cells by rectangles (few tiles).
type Rect = { i: number, j: number, w: number, h: number }
local function rectangles(keep: Mask): { Rect }
	local used = mask()
	local out: { Rect } = {}
	for j = 1, N do
		for i = 1, N do
			if keep[i][j] and not used[i][j] then
				local w = 1
				while i + w <= N and keep[i + w][j] and not used[i + w][j] do
					w += 1
				end
				local h = 1
				local grow = true
				while grow and j + h <= N do
					for k = i, i + w - 1 do
						if not keep[k][j + h] or used[k][j + h] then
							grow = false
							break
						end
					end
					if grow then
						h += 1
					end
				end
				for a = i, i + w - 1 do
					for b = j, j + h - 1 do
						used[a][b] = true
					end
				end
				table.insert(out, { i = i, j = j, w = w, h = h })
			end
		end
	end
	return out
end

-- Marks the cells within `radius` cells of (i, j).
local function stamp(m: Mask, i: number, j: number, radius: number)
	local r = math.floor(radius + 0.5)
	local limit = radius * radius + 0.3
	for a = math.max(1, i - r), math.min(N, i + r) do
		for b = math.max(1, j - r), math.min(N, j + r) do
			local da, db = a - i, b - j
			if da * da + db * db <= limit then
				m[a][b] = true
			end
		end
	end
end

local function grow(m: Mask, radius: number): Mask
	local out = mask()
	for i = 1, N do
		for j = 1, N do
			if m[i][j] then
				stamp(out, i, j, radius)
			end
		end
	end
	return out
end

-- A cell next to a hole (a raw edge).
local function nextTo(hole: Mask, i: number, j: number): boolean
	return (i > 1 and hole[i - 1][j])
		or (i < N and hole[i + 1][j])
		or (j > 1 and hole[i][j - 1])
		or (j < N and hole[i][j + 1])
end

local function clearTiles(state: State, layer: string)
	local list = state.tiles[layer]
	if list then
		for _, part in list do
			part:Destroy()
		end
	end
	state.tiles[layer] = {}
end

-- Tiles for `keep` at depth z0..z1 (torso space, front -Z).
local function buildLayer(
	state: State,
	layer: string,
	keep: Mask,
	z0: number,
	z1: number,
	color: Color3,
	ramp: string,
	shine: number
)
	clearTiles(state, layer)
	local list = state.tiles[layer]
	for _, rect in rectangles(keep) do
		local x = -1 + (rect.i - 1 + rect.w / 2) * CELL
		local y = 1 - (rect.j - 1 + rect.h / 2) * CELL
		local part = Make.part({
			Name = "Skin" .. layer,
			Size = Vector3.new(rect.w * CELL, rect.h * CELL, z1 - z0),
			CFrame = state.frame * CFrame.new(x, y, (z0 + z1) / 2),
			Color = color,
			Reflectance = shine,
			Ramp = ramp,
			Parent = state.folder,
		})
		part:SetAttribute("SkinLayer", layer)
		table.insert(list, part)
	end
end

local function rebuild(state: State)
	local skinHole, fatHole, muscleHole = mask(), mask(), mask()
	for i = 1, N do
		for j = 1, N do
			local depth = state.depth[i][j]
			if depth >= 1 then
				local open = state.open[i][j]
				stamp(skinHole, i, j, open)
				if depth >= 2 then
					stamp(fatHole, i, j, math.max(0, open - 1.2))
				end
				if depth >= 3 then
					stamp(muscleHole, i, j, math.max(0, open - 2.4))
				end
			end
		end
	end
	-- skin: its raw edge apart (pink-red, a little raised)
	local skin, rim = mask(), mask()
	for i = 1, N do
		for j = 1, N do
			if not skinHole[i][j] then
				if nextTo(skinHole, i, j) then
					rim[i][j] = true
				else
					skin[i][j] = true
				end
			end
		end
	end
	-- fat and muscle: only where they can be seen (under a hole, a bit wider)
	local seenFat = grow(skinHole, 2)
	local seenMuscle = grow(fatHole, 2)
	local fat, muscle, muscleEdge = mask(), mask(), mask()
	for i = 1, N do
		for j = 1, N do
			fat[i][j] = seenFat[i][j] and not fatHole[i][j]
			if seenMuscle[i][j] and not muscleHole[i][j] then
				if nextTo(muscleHole, i, j) then
					muscleEdge[i][j] = true
				else
					muscle[i][j] = true
				end
			end
		end
	end
	buildLayer(state, "Skin", skin, -0.5, -0.46, state.skinColor, "skin", 0.02)
	buildLayer(state, "Rim", rim, -0.512, -0.455, RAW_EDGE, "raw", 0.15)
	buildLayer(state, "Fat", fat, -0.46, -0.43, FAT, "fat", 0.1)
	buildLayer(state, "Muscle", muscle, -0.43, -0.4, MUSCLE, "muscle", 0.14)
	buildLayer(state, "MuscleEdge", muscleEdge, -0.435, -0.4, MUSCLE_CUT, "muscle", 0.18)
	state.dirty = false
	state.builtAt = os.clock()
end

-- The five other faces of the torso: plain skin, never cut.
local function closedFaces(state: State)
	local faces = {
		{ Vector3.new(0, 0, 0.48), Vector3.new(2, 2, 0.04) },
		{ Vector3.new(0.98, 0, 0), Vector3.new(0.04, 2, 1) },
		{ Vector3.new(-0.98, 0, 0), Vector3.new(0.04, 2, 1) },
		{ Vector3.new(0, 0.98, 0), Vector3.new(2, 0.04, 1) },
		{ Vector3.new(0, -0.98, 0), Vector3.new(2, 0.04, 1) },
	}
	for index, face in faces do
		local part = Make.part({
			Name = "SkinSide",
			Size = face[2],
			CFrame = state.frame * CFrame.new(face[1]),
			Color = state.skinColor,
			Reflectance = 0.02,
			Ramp = "skin",
			Parent = state.folder,
		})
		if index == 2 then
			state.sides[1] = part
		elseif index == 3 then
			state.sides[-1] = part
		end
	end
end

function Skin.new(torso: CFrame, parent: Instance, skinColor: Color3): State
	local folder = Instance.new("Model")
	folder.Name = "Skin"
	folder.Parent = parent
	local state: State = {
		frame = torso,
		folder = folder,
		skinColor = skinColor,
		depth = grid(0),
		open = grid(0),
		cutAt = grid(0),
		stroke = grid(0),
		tiles = {},
		sides = {},
		dirty = true,
		builtAt = 0,
	}
	closedFaces(state)
	rebuild(state)
	return state
end

function Skin.toWorld(state: State, at: Vector2, z: number?): Vector3
	return state.frame:PointToWorldSpace(Vector3.new(at.X, at.Y, z or -0.5))
end

-- Where a ray meets the front face (torso space x, y), or nil.
function Skin.onFront(state: State, origin: Vector3, direction: Vector3): Vector2?
	local o = state.frame:PointToObjectSpace(origin)
	local d = state.frame:VectorToObjectSpace(direction)
	if math.abs(d.Z) < 1e-4 then
		return nil
	end
	local t = (-0.5 - o.Z) / d.Z
	if t <= 0 then
		return nil
	end
	local p = o + d * t
	if math.abs(p.X) > 0.97 or math.abs(p.Y) > 0.97 then
		return nil
	end
	return Vector2.new(p.X, p.Y)
end

-- One cell one depth deeper (once per stroke); true if it was.
local function deeper(state: State, i: number, j: number, stroke: number, now: number): boolean
	if state.stroke[i][j] == stroke or state.depth[i][j] >= 3 then
		return false
	end
	state.stroke[i][j] = stroke
	if state.depth[i][j] == 0 then
		state.cutAt[i][j] = now
	end
	state.depth[i][j] += 1
	state.dirty = true
	return true
end

-- Cuts along a..b: every cell whose middle is close to the segment goes one
-- layer deeper (once per stroke). Returns the cells cut (their middles).
function Skin.cut(state: State, a: Vector2, b: Vector2, stroke: number): { Vector2 }
	local out: { Vector2 } = {}
	local now = os.clock()
	local ab = b - a
	local length2 = ab:Dot(ab)
	local i0, j0 = cellOf(Vector2.new(math.min(a.X, b.X) - 0.08, math.max(a.Y, b.Y) + 0.08))
	local i1, j1 = cellOf(Vector2.new(math.max(a.X, b.X) + 0.08, math.min(a.Y, b.Y) - 0.08))
	for i = i0, i1 do
		for j = j0, j1 do
			local c = centreOf(i, j)
			local t = if length2 > 1e-8 then math.clamp((c - a):Dot(ab) / length2, 0, 1) else 0
			if (a + ab * t - c).Magnitude <= 0.04 and deeper(state, i, j, stroke, now) then
				table.insert(out, c)
			end
		end
	end
	return out
end

-- Holding the blade still: the cells right there go one layer deeper.
function Skin.deepen(state: State, at: Vector2): { Vector2 }
	local out: { Vector2 } = {}
	local i, j = cellOf(at)
	local stroke = -math.floor(os.clock() * 1000) -- (a stroke of its own)
	for a = math.max(1, i - 1), math.min(N, i + 1) do
		for b = math.max(1, j - 1), math.min(N, j + 1) do
			if state.depth[a][b] >= 1 and deeper(state, a, b, stroke, os.clock()) then
				table.insert(out, centreOf(a, b))
			end
		end
	end
	return out
end

-- How deep the cut is there (0 intact .. 3 open to the cavity).
function Skin.depthAt(state: State, at: Vector2): number
	local i, j = cellOf(at)
	return state.depth[i][j]
end

function Skin.nearCut(state: State, at: Vector2, cells: number): boolean
	local i, j = cellOf(at)
	local r = math.ceil(cells)
	for a = math.max(1, i - r), math.min(N, i + r) do
		for b = math.max(1, j - r), math.min(N, j + r) do
			if state.depth[a][b] >= 1 then
				return true
			end
		end
	end
	return false
end

-- Pulls the edges of the cut apart near `at` by `amount` cells.
function Skin.spread(state: State, at: Vector2, amount: number): boolean
	local i, j = cellOf(at)
	local reach = 7
	local changed = false
	for a = math.max(1, i - reach), math.min(N, i + reach) do
		for b = math.max(1, j - reach), math.min(N, j + reach) do
			if state.depth[a][b] >= 1 then
				local d = math.sqrt((a - i) ^ 2 + (b - j) ^ 2)
				local k = 1 - d / (reach + 1)
				if k > 0 then
					local open = math.min(MAX_OPEN, math.max(state.open[a][b], 1) + amount * k)
					if open > state.open[a][b] + 0.01 then
						state.open[a][b] = open
						changed = true
					end
				end
			end
		end
	end
	if changed then
		state.dirty = true
	end
	return changed
end

-- How much of the front is open (0..1).
function Skin.openness(state: State): number
	local count = 0
	for i = 1, N do
		for j = 1, N do
			if state.depth[i][j] >= 3 then
				count += state.open[i][j]
			end
		end
	end
	return math.min(1, count / (N * 8))
end

function Skin.update(state: State)
	local now = os.clock()
	for i = 1, N do
		local depths, opens, cuts = state.depth[i], state.open[i], state.cutAt[i]
		for j = 1, N do
			if depths[j] >= 1 and opens[j] < 1 and now - cuts[j] > GAPE_DELAY then
				opens[j] = 1
				state.dirty = true
			end
		end
	end
	if state.dirty and now - state.builtAt > 0.06 then
		rebuild(state)
	end
end

return Skin
