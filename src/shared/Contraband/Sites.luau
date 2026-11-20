--!strict
-- Sites: where the contraband prototype lives in the CURRENT city (Marrow District).
-- Plain data, shared (no secrets in it: anyone can see a door in the street anyway).
--
-- LAB DOORS: three existing wooden doors of the city lead to the players' private labs
-- (Server/Systems/Contraband/Apartments). With Config.Lab.ANY_DOOR, every one of them opens
-- YOUR lab. For each door:
--   leaves    the door leaf parts named "Door" (their centre, found within 1 stud) and the Z of
--             their hinge line (the leaf's vertical edge on the hinge side). The hinge X is the
--             leaf's own X (the doors face ±X).
--   outward   the direction of the street (a door opens the OTHER way, into the building)
--   promptAt  where the invisible "Enter" prompt part goes (in front of the door, street side)
--   exitAt    where a player comes out (the ground under it is found with a raycast)
-- The positions come from the city data (citygen); check them in Studio if the city changes.
-- A door whose parts are not found is skipped with one warning (the others still work).
--
-- BUYER: the back of the refrigerated van in the Yard (the van's rear face is at x 35.05,
-- z 21.3 .. 28.7). The buyer NPC stands at npcAt, facing -X (the street); the "Sell" prompt
-- is at promptAt.

export type DoorLeaf = { position: Vector3, hingeZ: number }

export type DoorSite = {
	id: string,
	label: string, -- the prompt's ObjectText
	leaves: { DoorLeaf },
	outward: Vector3,
	promptAt: Vector3,
	exitAt: Vector3,
}

export type BuyerSite = {
	label: string,
	npcAt: CFrame, -- the floor point between the NPC's feet, LookVector = where it faces
	promptAt: Vector3,
	vanRearX: number, -- x of the van's rear face
	vanZMin: number,
	vanZMax: number,
	groundY: number, -- top of the ground there
}

local Sites = {}

Sites.DOORS = table.freeze({
	table.freeze({
		id = "Calloway",
		label = "Calloway Tenements",
		leaves = table.freeze({
			table.freeze({ position = Vector3.new(-28.0, 5.6, -108.15), hingeZ = -106.9 }),
			table.freeze({ position = Vector3.new(-28.0, 5.6, -110.65), hingeZ = -111.9 }),
		}),
		outward = Vector3.new(1, 0, 0),
		promptAt = Vector3.new(-25.4, 4.6, -109.45),
		exitAt = Vector3.new(-22.5, 4.6, -109.45),
	}),
	table.freeze({
		id = "Doyle",
		label = "Doyle Alley 7",
		leaves = table.freeze({
			table.freeze({ position = Vector3.new(-90.0, 4.9, 19.0), hingeZ = 21.0 }),
		}),
		outward = Vector3.new(1, 0, 0),
		promptAt = Vector3.new(-88.0, 4.5, 19.0),
		exitAt = Vector3.new(-86.0, 4.5, 19.0),
	}),
	table.freeze({
		id = "Lot9",
		label = "Lot 9 Rear",
		leaves = table.freeze({
			table.freeze({ position = Vector3.new(108.0, 4.9, -118.6), hingeZ = -120.6 }),
		}),
		outward = Vector3.new(-1, 0, 0),
		promptAt = Vector3.new(106.0, 4.5, -118.6),
		exitAt = Vector3.new(104.0, 4.5, -118.6),
	}),
}) :: { DoorSite }

Sites.BUYER = table.freeze({
	label = "Night Intake",
	npcAt = CFrame.lookAt(Vector3.new(33.2, 1.2, 25.0), Vector3.new(32.2, 1.2, 25.0)),
	promptAt = Vector3.new(33.2, 4.2, 25.0),
	vanRearX = 35.05,
	vanZMin = 21.3,
	vanZMax = 28.7,
	groundY = 1.2,
}) :: BuyerSite

-- The door site with this id, or nil.
function Sites.door(id: string): DoorSite?
	for _, site in Sites.DOORS do
		if site.id == id then
			return site
		end
	end
	return nil
end

-- The CityDoors group name of a lab door ("Lab_Calloway"...).
function Sites.doorGroup(id: string): string
	return `Lab_{id}`
end

return table.freeze(Sites)
