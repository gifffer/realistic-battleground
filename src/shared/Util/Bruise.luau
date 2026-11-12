--!strict
-- Bruise: a bruise where a blow landed (punches, kicks, the bat...), as the
-- server stores it and every client draws it (Client/Combat/Wounds).
--
--   "Bruise_<Part>_<n>" = "<x>|<y>|<z>|<level>|<born>|<seed>"
-- <Part>  "Head" / "Torso" / "LeftLeg" / "RightLeg" / "LeftArm" / "RightArm"
-- x y z   where on the part (studs, part space, on the skin; the head: its
--         round shape, radius 0.6)
-- level   1..4: hit again on the same spot it grows, darkens, swells
-- born    server time it appeared (workspace:GetServerTimeNow()): its
--         colour changes with time (red, then purple, then blue)
-- seed    for its shape (the same on every client)

local Bruise = {}

export type Data = {
	point: Vector3,
	level: number,
	born: number,
	seed: number,
}

Bruise.PREFIX = "Bruise_"
Bruise.MAX_PER_PART = 4
Bruise.MAX_LEVEL = 4

function Bruise.attribute(key: string, index: number): string
	return `{Bruise.PREFIX}{key}_{index}`
end

local function round(x: number): string
	return string.format("%.3f", x)
end

function Bruise.encode(data: Data): string
	local p = data.point
	return table.concat({
		round(p.X),
		round(p.Y),
		round(p.Z),
		string.format("%d", data.level),
		string.format("%.1f", data.born),
		string.format("%d", data.seed),
	}, "|")
end

-- nil if the text isn't a valid bruise (never trust it blindly).
function Bruise.decode(text: unknown): Data?
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
		level = math.clamp(math.floor(numbers[4]), 1, Bruise.MAX_LEVEL),
		born = numbers[5],
		seed = numbers[6],
	}
end

function Bruise.isAttribute(name: string): boolean
	return string.sub(name, 1, #Bruise.PREFIX) == Bruise.PREFIX
end

return table.freeze(Bruise)
