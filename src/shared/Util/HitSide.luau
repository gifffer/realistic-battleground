--!strict
-- HitSide: which side of the victim the attacker is on ("Front", "Back",
-- "Left" or "Right"), seen from the VICTIM.
--
-- Used by the server (sent with every hit in Remotes.CombatEvent, so every
-- client plays the same reaction) and by the attacker's own client (to
-- react at the exact moment the fist lands, see CombatEffectsController).
--
-- How: we express the attacker's position in the victim's own space
-- (CFrame:PointToObjectSpace). There, -Z is in front of the victim, +X is
-- on its right. The biggest of the two distances wins: 4 sectors of 90°.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local HitSide = {}

function HitSide.compute(victimCFrame: CFrame, attackerPosition: Vector3): Types.HitSide
	local offset = victimCFrame:PointToObjectSpace(attackerPosition)
	-- Same spot (or straight above): treat as a frontal hit.
	if math.abs(offset.X) < 1e-3 and math.abs(offset.Z) < 1e-3 then
		return "Front"
	end
	local side: Types.HitSide
	if math.abs(offset.Z) >= math.abs(offset.X) then
		side = if offset.Z < 0 then "Front" else "Back"
	else
		side = if offset.X > 0 then "Right" else "Left"
	end
	return side
end

local VALID: { [string]: boolean } = { Front = true, Back = true, Left = true, Right = true }

-- For values received over the network: true if `value` is a real side.
function HitSide.isValid(value: unknown): boolean
	return typeof(value) == "string" and VALID[value] == true
end

return table.freeze(HitSide)
