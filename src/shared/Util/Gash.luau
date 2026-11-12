--!strict
-- Gash: one cut in a fighter's skin (glass), as the server stores it and
-- every client draws it (Client/Combat/Gashes).
--
-- Stored as a string attribute on the fighter's model:
--   "Gash_<Part>_<n>" = "<kind>|<size>|<x>|<y>|<z>|<angle>|<seed>"
--   e.g. "Gash_Head_1" = "Slash|M|0.31|0.12|-0.52|-30|81234"
-- <Part>  "Head" / "Torso" / "LeftLeg" / "RightLeg" (/ "LeftArm" / "RightArm")
-- <kind>  "Lac" = laceration (a bottle smashed on them), "Slash" = a cut
--         from a broken bottle, "Tear" = torn open by a hand (the Boxer's
--         finisher: the liver torn out, only "L", torso only), "Burn" =
--         burnt through by the Sentinel's heat vision (the skin gone, charred
--         at the edge, what's under it shows: the skull on the head, cooked
--         muscle on the body; no bleeding: cauterized)
-- <size>  "S" / "M" / "L" (grows when the same spot is hit again)
-- x y z   where on the part (studs, in the part's space; the head: its
--         round visible shape, radius ~0.6)
-- angle   turn of the cut on the skin, degrees
-- seed    for the little random details (same on every client)

local Gash = {}

export type Kind = "Lac" | "Slash" | "Tear" | "Burn"
export type Size = "S" | "M" | "L"
export type Data = {
	kind: Kind,
	size: Size,
	point: Vector3,
	angle: number,
	seed: number,
}

Gash.PREFIX = "Gash_"
Gash.MAX_PER_PART = 3
Gash.SIZES = table.freeze({ "S", "M", "L" })

-- R6 part name <-> the name used in the attributes.
Gash.KEY_OF = table.freeze({
	Head = "Head",
	Torso = "Torso",
	["Left Leg"] = "LeftLeg",
	["Right Leg"] = "RightLeg",
	["Left Arm"] = "LeftArm",
	["Right Arm"] = "RightArm",
} :: { [string]: string })
local partOf: { [string]: string } = {}
for partName, key in Gash.KEY_OF do
	partOf[key] = partName
end
Gash.PART_OF = table.freeze(partOf)

function Gash.attribute(key: string, index: number): string
	return `{Gash.PREFIX}{key}_{index}`
end

local function round(x: number): string
	return string.format("%.3f", x)
end

function Gash.encode(data: Data): string
	local p = data.point
	return table.concat({
		data.kind,
		data.size,
		round(p.X),
		round(p.Y),
		round(p.Z),
		string.format("%d", math.round(data.angle)),
		string.format("%d", data.seed),
	}, "|")
end

-- nil if the text isn't a valid gash (never trust it blindly).
function Gash.decode(text: unknown): Data?
	if typeof(text) ~= "string" then
		return nil
	end
	local fields = string.split(text, "|")
	if #fields ~= 7 then
		return nil
	end
	local kind, size = fields[1], fields[2]
	if kind ~= "Lac" and kind ~= "Slash" and kind ~= "Tear" and kind ~= "Burn" then
		return nil
	end
	if size ~= "S" and size ~= "M" and size ~= "L" then
		return nil
	end
	local x, y, z = tonumber(fields[3]), tonumber(fields[4]), tonumber(fields[5])
	local angle, seed = tonumber(fields[6]), tonumber(fields[7])
	if x == nil or y == nil or z == nil or angle == nil or seed == nil then
		return nil
	end
	return {
		kind = kind :: Kind,
		size = size :: Size,
		point = Vector3.new(x, y, z),
		angle = angle,
		seed = seed,
	}
end

------------------------------------------------------------------------------
-- Glass shards stuck in the skin (a bottle bursting on someone leaves bits
-- of glass in them, often without a real cut):
--   "Shard_<Part>_<n>" = "<x>|<y>|<z>|<yaw>|<tilt>|<seed>"
-- x y z  where on the part (studs, part space, on the skin: like a gash)
-- yaw    turn around the skin's normal, degrees; tilt: lean, degrees
export type Shard = { point: Vector3, yaw: number, tilt: number, seed: number }

Gash.SHARD_PREFIX = "Shard_"
Gash.MAX_SHARDS_PER_PART = 6

function Gash.shardAttribute(key: string, index: number): string
	return `{Gash.SHARD_PREFIX}{key}_{index}`
end

function Gash.encodeShard(shard: Shard): string
	local p = shard.point
	return table.concat({
		round(p.X),
		round(p.Y),
		round(p.Z),
		string.format("%d", math.round(shard.yaw)),
		string.format("%d", math.round(shard.tilt)),
		string.format("%d", shard.seed),
	}, "|")
end

function Gash.decodeShard(text: unknown): Shard?
	if typeof(text) ~= "string" then
		return nil
	end
	local fields = string.split(text, "|")
	if #fields ~= 6 then
		return nil
	end
	local numbers = {}
	for index, field in fields do
		local value = tonumber(field)
		if value == nil then
			return nil
		end
		numbers[index] = value
	end
	return {
		point = Vector3.new(numbers[1], numbers[2], numbers[3]),
		yaw = numbers[4],
		tilt = numbers[5],
		seed = numbers[6],
	}
end

-- Is this attribute name a cut or a shard (cleared together)?
function Gash.isInjuryAttribute(name: string): boolean
	return string.sub(name, 1, #Gash.PREFIX) == Gash.PREFIX
		or string.sub(name, 1, #Gash.SHARD_PREFIX) == Gash.SHARD_PREFIX
end

-- "S" -> "M" -> "L" -> "L"
function Gash.bigger(size: Size): Size
	return if size == "S" then "M" else "L"
end

return table.freeze(Gash)
