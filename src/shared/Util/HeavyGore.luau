--!strict
-- HeavyGore: the gore of the very strong hits, as the server stores it and
-- every client draws it (Client/Combat/HeavyGore). Rare: only a heavy blow
-- that knocks out, and the finishers (Config.HeavyGore).
--
-- Attributes on the fighter's model (each value = a seed, the same details
-- on every client):
--   "LimbTorn_<Limb>"   that limb torn off (RightArm / LeftArm / RightLeg /
--                       LeftLeg): the open socket drawn on the torso
--   "Fracture_<Limb>"   an open fracture: bone out of the forearm / shin
--   "TeethOut"          teeth knocked out (they fly out when it is set)
--   "JawBroken"         the jaw broken: the mouth torn open, crooked
-- The torn limb itself leaves the body: it lies in workspace.TornLimbs, in a
-- model of its own tagged HeavyGore.TAG (its "Limb" attribute = the limb,
-- "Seed", "TornAt" = server time): the clients draw its torn end on it.

local HeavyGore = {}

HeavyGore.TORN_PREFIX = "LimbTorn_"
HeavyGore.FRACTURE_PREFIX = "Fracture_"
HeavyGore.TEETH = "TeethOut"
HeavyGore.JAW = "JawBroken"
HeavyGore.TAG = "TornLimb"
HeavyGore.FOLDER = "TornLimbs"

export type Limb = {
	part: string, -- the R6 part
	joint: string, -- its Motor6D in the torso
	arm: boolean,
	stump: string, -- the gore kit's piece left on the torso (GoreShapes)
	limbEnd: string, -- ...and on the limb's torn end
	fracture: string, -- an open fracture in it
}

local LIMBS: { [string]: Limb } = {
	RightArm = {
		part = "Right Arm",
		joint = "Right Shoulder",
		arm = true,
		stump = "Shoulder",
		limbEnd = "ArmEnd",
		fracture = "ForearmBreak",
	},
	LeftArm = {
		part = "Left Arm",
		joint = "Left Shoulder",
		arm = true,
		stump = "ShoulderL",
		limbEnd = "ArmEndL",
		fracture = "ForearmBreak",
	},
	RightLeg = {
		part = "Right Leg",
		joint = "Right Hip",
		arm = false,
		stump = "Hip",
		limbEnd = "LegEnd",
		fracture = "ShinBreak",
	},
	LeftLeg = {
		part = "Left Leg",
		joint = "Left Hip",
		arm = false,
		stump = "HipL",
		limbEnd = "LegEndL",
		fracture = "ShinBreak",
	},
}
for _, limb in LIMBS do
	table.freeze(limb)
end
HeavyGore.LIMBS = table.freeze(LIMBS)
-- (a fixed order: the same choice on every run for the same random numbers)
HeavyGore.KEYS = table.freeze({ "RightArm", "LeftArm", "RightLeg", "LeftLeg" })

function HeavyGore.tornAttribute(key: string): string
	return HeavyGore.TORN_PREFIX .. key
end

function HeavyGore.fractureAttribute(key: string): string
	return HeavyGore.FRACTURE_PREFIX .. key
end

-- "LimbTorn_RightArm" -> ("Torn", "RightArm"); nil for any other attribute.
function HeavyGore.parse(name: string): (string?, string?)
	local key = string.match(name, "^" .. HeavyGore.TORN_PREFIX .. "(%a+)$")
	if key and LIMBS[key] then
		return "Torn", key
	end
	key = string.match(name, "^" .. HeavyGore.FRACTURE_PREFIX .. "(%a+)$")
	if key and LIMBS[key] then
		return "Fracture", key
	end
	return nil, nil
end

return table.freeze(HeavyGore)
