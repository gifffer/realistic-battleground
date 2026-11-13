--!strict
-- AimRule: is an M1's aim direction acceptable? ONE rule for the server
-- (which only trusts a valid aim) and the attacker's client (which predicts
-- the server's answer, see Client/Combat/HitPrediction).
--
-- Valid = a real Vector3 (no NaN / infinity), long enough to have a
-- direction, pointing roughly where the character faces
-- (Config.Combat.MIN_AIM_FACING). Returns the unit direction, or nil
-- (= no aim: the punch counts as aimed at the torso).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local AimRule = {}

function AimRule.validate(aim: unknown, facing: Vector3): Vector3?
	if typeof(aim) ~= "Vector3" then
		return nil
	end
	-- NaN is the only value not equal to itself.
	local finite = aim.X == aim.X and aim.Y == aim.Y and aim.Z == aim.Z and aim.Magnitude < math.huge
	if not finite or aim.Magnitude <= 0.1 then
		return nil
	end
	local unit = aim.Unit
	local flatAim = Vector3.new(unit.X, 0, unit.Z)
	local flatLook = Vector3.new(facing.X, 0, facing.Z)
	if flatAim.Magnitude < 1e-3 or flatLook.Magnitude < 1e-3 then
		return nil
	end
	if flatAim.Unit:Dot(flatLook.Unit) < Config.Combat.MIN_AIM_FACING then
		return nil
	end
	return unit
end

return table.freeze(AimRule)
