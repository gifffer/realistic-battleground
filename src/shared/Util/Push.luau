--!strict
-- Pushes a character horizontally for a short time (dash, knockback).
--
-- Uses a LinearVelocity constraint in "Plane" mode: it forces the speed on
-- the ground plane (X/Z) but leaves Y free, so gravity and jumps still work.
-- The constraint deletes itself after `duration`.
--
-- Who must call it: whoever SIMULATES the character's physics.
--   • Your own character is simulated by your client → the client calls it
--     for the dash.
--   • The server can call it on any character: the constraint replicates to
--     the client that simulates it (used for knockback).

local Debris = game:GetService("Debris")

local Push = {}

-- `velocity`: studs per second, only X and Z are used.
function Push.apply(root: BasePart, velocity: Vector3, duration: number)
	local attachment = Instance.new("Attachment")
	attachment.Name = "PushAttachment"

	local constraint = Instance.new("LinearVelocity")
	constraint.Name = "Push"
	constraint.Attachment0 = attachment
	constraint.RelativeTo = Enum.ActuatorRelativeTo.World
	constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	constraint.PrimaryTangentAxis = Vector3.xAxis
	constraint.SecondaryTangentAxis = Vector3.zAxis
	constraint.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	constraint.MaxForce = 1e6
	constraint.Parent = attachment

	attachment.Parent = root
	Debris:AddItem(attachment, duration)
end

return table.freeze(Push)
