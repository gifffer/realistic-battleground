--!strict
-- Things picked up in the world and THROWN (one use). Held in the right hand
-- ("Weapon" attribute); a left click throws it instead of punching. It flies
-- in an arc (the server simulates it: what it hits counts) and breaks in two
-- on whatever it hits first: someone, a wall, the floor. Dropped (and broken
-- at your feet) when you are knocked out or die.
--
--   "Bone"   the upper arm bone, pulled out of an arm the Bouncer tore off
--            (Shared/Finishers "ArmRip").
--
-- Read by the server (Combat: the throw, the hit) and the clients (the bone in
-- the hand and in the air, the throw clip "Bone_Throw", the two halves).

export type WeaponDef = {
	id: string,
	name: string, -- shown on the pickup prompt (English)
	damage: number, -- a direct hit
	stun: number, -- seconds, on a direct hit
	speed: number, -- studs/s when it leaves the hand
	lift: number, -- studs/s up added to the aim (an arc)
	gravity: number, -- studs/s² pulling it down in flight
	release: number, -- seconds into the throw clip when it leaves the hand
	recovery: number, -- seconds before he can attack again
	lifetime: number, -- seconds in the air at most (then it breaks there)
	-- Chance (0-1) a hit draws visible blood, per zone.
	bloodChance: { [string]: number },
}

local Weapons = {}

local registry: { [string]: WeaponDef } = {
	Bone = {
		id = "Bone",
		name = "BONE",
		damage = 16,
		stun = 0.8,
		speed = 95,
		lift = 6,
		gravity = 60,
		release = 0.24,
		recovery = 0.7,
		lifetime = 3,
		bloodChance = { Head = 0.8, Torso = 0.35, Legs = 0.15 },
	},
}

function Weapons.get(id: unknown): WeaponDef?
	return if typeof(id) == "string" then registry[id] else nil
end

return table.freeze(Weapons)
