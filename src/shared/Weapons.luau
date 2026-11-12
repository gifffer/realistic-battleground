--!strict
-- Weapons picked up in the world. They change the M1 (left click): harder
-- blows, more blood, and they break after a few hits that land. Kit moves
-- (keys 1-4) stay the same. Held in the right hand; dropped (gone) when you
-- are knocked out or die.
--
--   "Bone"   the upper arm bone, taken out of an arm the Bouncer tore off
--            (Shared/Finishers "ArmRip"): a short, heavy club.
--
-- Read by the server (Combat: damage, blood, wear) and the clients (the prop
-- in the hand, the swings: Client/Animation/BouncerClips "Weapon_Swing*").

export type WeaponDef = {
	id: string,
	name: string, -- shown on the pickup prompt (English)
	damageMultiplier: number, -- an M1 deals this much more
	durability: number, -- hits that land before it breaks
	-- Chance (0-1) a blow draws visible blood, per zone it lands on.
	bloodChance: { [string]: number },
}

local Weapons = {}

local registry: { [string]: WeaponDef } = {
	Bone = {
		id = "Bone",
		name = "BONE",
		damageMultiplier = 1.5,
		durability = 6,
		bloodChance = { Head = 0.65, Torso = 0.25, Legs = 0.1 },
	},
}

function Weapons.get(id: unknown): WeaponDef?
	return if typeof(id) == "string" then registry[id] else nil
end

return table.freeze(Weapons)
