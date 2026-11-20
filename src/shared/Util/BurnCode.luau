--!strict
-- BurnCode: how a body's burns are stored, as the server writes them
-- (Server/Systems/Combat/Burns) and every client draws them
-- (Client/Combat/Burns). Attributes on the model, so a body seen later,
-- a late joiner and a corpse copy (Config.Combat.CORPSE_TAG) all show the
-- same burns.
--
--   "Burn_<code>" = "<K><6 faces>[|<spot>...]"   one per burnt body part
--     <code>  T Torso, H Head, RA / LA the arms, RL / LL the legs
--     <K>     "F" fire (also a laser / ray), "A" acid
--     faces   6 letters, one per face (FACES order), "a".."q" = degree
--             0..4 in quarter steps: 1 redness, 2 blisters and peeling,
--             3 leathery eschar, 4 charred
--     spot    "<face 1-6><u a-z><v a-z><degree a-q>": one focused burn (a
--             laser / ray) at (u, v) on that face (0..1 from its top left,
--             as the face's texture sees it), at most MAX_SPOTS
--   "BurnLit"   = "T3,RA1"  the parts burning right now and how hard
--               (1-3): flames on fire parts, fizz on acid parts
--   "BurnSmoke" = server time (GetServerTimeNow) until which the body
--               smoulders (smoke, a few embers) after the fire is out

local BurnCode = {}

BurnCode.PREFIX = "Burn_"
BurnCode.LIT = "BurnLit"
BurnCode.SMOKE = "BurnSmoke"
BurnCode.MAX_SPOTS = 2
BurnCode.MAX_DEGREE = 4

-- Body part name <-> code (attribute names can't have spaces).
BurnCode.PARTS = table.freeze({ "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" })
BurnCode.CODE_OF = table.freeze({
	Torso = "T",
	Head = "H",
	["Right Arm"] = "RA",
	["Left Arm"] = "LA",
	["Right Leg"] = "RL",
	["Left Leg"] = "LL",
} :: { [string]: string })
BurnCode.PART_OF = table.freeze({
	T = "Torso",
	H = "Head",
	RA = "Right Arm",
	LA = "Left Arm",
	RL = "Right Leg",
	LL = "Left Leg",
} :: { [string]: string })

-- Face order (index 1..6) and each face's outward normal in part space.
BurnCode.FACES = table.freeze({
	Enum.NormalId.Right,
	Enum.NormalId.Left,
	Enum.NormalId.Top,
	Enum.NormalId.Bottom,
	Enum.NormalId.Back,
	Enum.NormalId.Front,
})
BurnCode.NORMALS = table.freeze({
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
})
-- How a face's texture lies on it: its "right" and "down" in part space
-- (u grows along right, v along down, from the face's top left).
BurnCode.RIGHT = table.freeze({
	Vector3.new(0, 0, -1),
	Vector3.new(0, 0, 1),
	Vector3.new(1, 0, 0),
	Vector3.new(1, 0, 0),
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
})
BurnCode.DOWN = table.freeze({
	Vector3.new(0, -1, 0),
	Vector3.new(0, -1, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
	Vector3.new(0, -1, 0),
	Vector3.new(0, -1, 0),
})

export type Kind = "Fire" | "Acid"
export type Spot = { face: number, u: number, v: number, degree: number }
export type PartBurn = {
	kind: Kind,
	faces: { number }, -- 6 degrees, 0..4
	spots: { Spot },
}

local A = string.byte("a")

local function degreeChar(degree: number): string
	return string.char(A + math.clamp(math.floor(degree * 4 + 0.5), 0, 16))
end

local function charDegree(text: string, at: number): number
	local byte = string.byte(text, at)
	if byte == nil then
		return 0
	end
	return math.clamp(byte - A, 0, 16) / 4
end

local function unitChar(value: number): string
	return string.char(A + math.clamp(math.floor(value * 25 + 0.5), 0, 25))
end

local function charUnit(text: string, at: number): number
	local byte = string.byte(text, at)
	if byte == nil then
		return 0.5
	end
	return math.clamp(byte - A, 0, 25) / 25
end

function BurnCode.attribute(partName: string): string?
	local code = BurnCode.CODE_OF[partName]
	return if code then BurnCode.PREFIX .. code else nil
end

function BurnCode.isAttribute(name: string): boolean
	return string.sub(name, 1, #BurnCode.PREFIX) == BurnCode.PREFIX
		or name == BurnCode.LIT
		or name == BurnCode.SMOKE
end

-- Degrees rounded to what the string can hold (a quarter).
function BurnCode.quantize(degree: number): number
	return math.clamp(math.floor(degree * 4 + 0.5), 0, 16) / 4
end

function BurnCode.encode(burn: PartBurn): string
	local out = { if burn.kind == "Acid" then "A" else "F" }
	for index = 1, 6 do
		table.insert(out, degreeChar(burn.faces[index] or 0))
	end
	for index, spot in burn.spots do
		if index > BurnCode.MAX_SPOTS then
			break
		end
		table.insert(out, "|")
		table.insert(out, tostring(math.clamp(spot.face, 1, 6)))
		table.insert(out, unitChar(spot.u))
		table.insert(out, unitChar(spot.v))
		table.insert(out, degreeChar(spot.degree))
	end
	return table.concat(out)
end

function BurnCode.decode(value: unknown): PartBurn?
	if typeof(value) ~= "string" or #value < 7 then
		return nil
	end
	local text = value :: string
	local kind: Kind = if string.sub(text, 1, 1) == "A" then "Acid" else "Fire"
	local faces = table.create(6, 0)
	for index = 1, 6 do
		faces[index] = charDegree(text, index + 1)
	end
	local spots: { Spot } = {}
	local at = 8
	while string.sub(text, at, at) == "|" and #spots < BurnCode.MAX_SPOTS do
		local face = tonumber(string.sub(text, at + 1, at + 1))
		if face == nil then
			break
		end
		table.insert(spots, {
			face = math.clamp(face, 1, 6),
			u = charUnit(text, at + 2),
			v = charUnit(text, at + 3),
			degree = charDegree(text, at + 4),
		})
		at += 5
	end
	return { kind = kind, faces = faces, spots = spots }
end

-- "T3,RA1" <-> { T = 3, RA = 1 } (part codes -> 1..3).
function BurnCode.encodeLit(lit: { [string]: number }): string?
	local out = {}
	for _, partName in BurnCode.PARTS do
		local code = BurnCode.CODE_OF[partName]
		local level = lit[code]
		if level and level > 0 then
			table.insert(out, code .. tostring(math.clamp(level, 1, 3)))
		end
	end
	return if #out > 0 then table.concat(out, ",") else nil
end

function BurnCode.decodeLit(value: unknown): { [string]: number }
	local out: { [string]: number } = {}
	if typeof(value) ~= "string" then
		return out
	end
	for code, level in string.gmatch(value :: string, "(%u+)(%d)") do
		if BurnCode.PART_OF[code] then
			out[code] = tonumber(level) or 1
		end
	end
	return out
end

-- Where a point (part space) lands on a face, as (u, v) 0..1 from the
-- face's top left (the face's own texture coordinates).
function BurnCode.faceUV(size: Vector3, face: number, point: Vector3): (number, number)
	local right = BurnCode.RIGHT[face]
	local down = BurnCode.DOWN[face]
	local width = math.abs(right:Dot(size))
	local height = math.abs(down:Dot(size))
	local u = (point:Dot(right) + width / 2) / math.max(width, 1e-3)
	local v = (point:Dot(down) + height / 2) / math.max(height, 1e-3)
	return math.clamp(u, 0, 1), math.clamp(v, 0, 1)
end

-- The face of a box facing a direction (part space) best.
function BurnCode.faceToward(direction: Vector3): number
	local best, bestDot = 6, -math.huge
	for index, normal in BurnCode.NORMALS do
		local dot = normal:Dot(direction)
		if dot > bestDot then
			best, bestDot = index, dot
		end
	end
	return best
end

return table.freeze(BurnCode)
