--!strict
-- HeavyGore: the gore of the very strong hits, as the server stores it and
-- every client draws it (Client/Combat/HeavyGore, Client/Combat/Gashes).
-- Rare: only in a fight, a heavy blow that ends a big combo on someone
-- (Config.HeavyGore). Never from a finisher.
--
-- Attributes on the fighter's model (each value = a seed, the same details
-- on every client):
--   "LimbTorn_<Limb>"   that limb torn off (RightArm / LeftArm / RightLeg /
--                       LeftLeg): the open socket drawn on the torso
--   "Fracture_<Limb>"   an open fracture: the broken bone out of a torn hole
--                       in the forearm / the shin (the limb's "Break" insert)
-- They stay until death (a kill's healing leaves them: Server/Combat).
-- The torn limb itself leaves the body: it lies in workspace.TornLimbs, in a
-- model of its own tagged HeavyGore.TAG (its "Limb" attribute = the limb,
-- "Seed", "TornAt" = server time): the clients draw its torn end on it.

local HeavyGore = {}

HeavyGore.TORN_PREFIX = "LimbTorn_"
HeavyGore.FRACTURE_PREFIX = "Fracture_"
HeavyGore.TAG = "TornLimb"
HeavyGore.FOLDER = "TornLimbs"

export type Limb = {
	part: string, -- the R6 part
	joint: string, -- its Motor6D in the torso
	arm: boolean,
	stump: string, -- the gore kit's piece left on the torso (GoreShapes)
	limbEnd: string, -- ...and on the limb's torn end
	fracture: string, -- the wound kit's insert of its open fracture (WoundShapes)
	-- where that insert sits (limb space, on its front face): it is made for
	-- exactly that spot (tools/wounds/fracture.py BREAK_AT, the left limbs
	-- mirrored)
	breakAt: Vector3,
}

local LIMBS: { [string]: Limb } = {
	RightArm = {
		part = "Right Arm",
		joint = "Right Shoulder",
		arm = true,
		stump = "ShoulderR",
		limbEnd = "ArmEndR",
		fracture = "BreakArm",
		breakAt = Vector3.new(0.06, -0.3, -0.5),
	},
	LeftArm = {
		part = "Left Arm",
		joint = "Left Shoulder",
		arm = true,
		stump = "ShoulderL",
		limbEnd = "ArmEndL",
		fracture = "BreakArmL",
		breakAt = Vector3.new(-0.06, -0.3, -0.5),
	},
	RightLeg = {
		part = "Right Leg",
		joint = "Right Hip",
		arm = false,
		stump = "Hip",
		limbEnd = "LegEnd",
		fracture = "BreakLeg",
		breakAt = Vector3.new(-0.1, -0.35, -0.5),
	},
	LeftLeg = {
		part = "Left Leg",
		joint = "Left Hip",
		arm = false,
		stump = "HipL",
		limbEnd = "LegEndL",
		fracture = "BreakLegL",
		breakAt = Vector3.new(0.1, -0.35, -0.5),
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

-- An open fracture in a leg of `model` (they limp: it never heals).
function HeavyGore.hasLegFracture(model: Model): boolean
	return model:GetAttribute(HeavyGore.FRACTURE_PREFIX .. "RightLeg") ~= nil
		or model:GetAttribute(HeavyGore.FRACTURE_PREFIX .. "LeftLeg") ~= nil
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
