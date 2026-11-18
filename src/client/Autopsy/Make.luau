--!strict
-- Make: tiny helpers to build the autopsy scene out of parts.
--
--   Make.part(props)          an anchored part (props: any Part property)
--   Make.rod(a, b, d, props)  a cylinder from a to b, d thick
--   Make.plastic(cf, size)    a sheet of clear plastic (seen through)
--
-- Attributes read by the pixel screen (PixelWorker):
--   PixRamp = "steel" / "plastic" / "skin"...   which colour ramp to use
--   PixEllipsoid = Vector3                      its real shape is this ellipsoid
--                                               (half sizes), not its box

local Make = {}

export type Props = { [string]: any }

function Make.part(props: Props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	part.CanTouch = false
	local parent: Instance? = nil
	for key, value in props do
		if key == "Parent" then
			parent = value
		elseif key == "Ramp" then
			part:SetAttribute("PixRamp", value)
		else
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- A cylinder from `a` to `b`, `thickness` across.
function Make.rod(a: Vector3, b: Vector3, thickness: number, props: Props): Part
	local length = (b - a).Magnitude
	local frame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	local all: Props = table.clone(props)
	all.Shape = Enum.PartType.Cylinder
	all.Size = Vector3.new(length, thickness, thickness)
	all.CFrame = frame
	return Make.part(all)
end

local PLASTIC = Color3.fromRGB(200, 218, 228)

-- A sheet of clear plastic: a few thin strips, each turned a little (folds).
function Make.plastic(
	frame: CFrame,
	size: Vector2,
	parent: Instance,
	random: Random,
	strip: number?
)
	local width = strip or 0.55
	local count = math.max(1, math.floor(size.X / width + 0.5))
	local step = size.X / count
	for index = 1, count do
		local x = -size.X / 2 + (index - 0.5) * step
		local turn = math.rad(random:NextNumber(-5, 5))
		local push = random:NextNumber(-0.06, 0.06)
		Make.part({
			Name = "Plastic",
			Size = Vector3.new(step * 1.08, size.Y * random:NextNumber(0.96, 1), 0.04),
			CFrame = frame * CFrame.new(x, 0, push) * CFrame.Angles(0, turn, 0),
			Color = PLASTIC,
			Transparency = random:NextNumber(0.5, 0.62),
			Reflectance = 0.3,
			CanCollide = false,
			CastShadow = false,
			Ramp = "plastic",
			Parent = parent,
		})
	end
end

Make.PLASTIC = PLASTIC

return Make
