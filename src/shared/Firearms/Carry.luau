--!strict
-- Carry: builds the Torso-space frame where a gun rides when it is not drawn
-- (FirearmDef.carry.cf). GunModel puts the gun's HolsterMount / BackMount marker on
-- it (marker LookVector = the muzzle direction, UpVector = the top of the gun).
--
--   Carry.hip(position)                      pistol: muzzle down, top of the slide forward
--   Carry.back(position, angle, topInward)   long guns slung across the back: the muzzle
--                                            `angle` degrees from straight up, toward the
--                                            left shoulder when positive; top of the gun
--                                            against the back when topInward (the mag /
--                                            pouch faces out)

local Carry = {}

function Carry.hip(position: Vector3): CFrame
	-- look = -Y (muzzle down), up = -Z (the slide's top faces forward), right = +X
	return CFrame.fromMatrix(position, Vector3.xAxis, -Vector3.zAxis)
end

function Carry.back(position: Vector3, angle: number, topInward: boolean): CFrame
	local a = math.rad(angle)
	local look = Vector3.new(-math.sin(a), math.cos(a), 0)
	local up = if topInward then -Vector3.zAxis else Vector3.zAxis
	local right = up:Cross(-look)
	return CFrame.fromMatrix(position, right, up)
end

return table.freeze(Carry)
