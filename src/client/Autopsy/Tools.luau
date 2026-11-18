--!strict
-- Tools: the 3D tools that follow the mouse during the operation (a
-- scalpel, a gloved hand, rib shears). Seen in both views, the pixel one
-- included (they are parts in the scene).
--
--   Tools.build(parent) -> Tools
--   Tools.show(tools, name, at, camera, pressing)   name: "Scalpel" / "Hands" / "Shears" / nil

local Make = require(script.Parent.Make)

local Tools = {}

export type Tools = {
	folder: Folder,
	models: { [string]: Model },
	shown: string?,
}

local STEEL = Color3.fromRGB(200, 205, 210)
local GLOVE = Color3.fromRGB(60, 95, 170)
local UP = Vector3.new(0, 1, 0)

local function add(model: Model, props: Make.Props): Part
	props.CanCollide = false
	props.CastShadow = true
	props.Parent = model
	return Make.part(props)
end

-- Local frames: the tip at the origin, the handle along +Y.
local function scalpel(): Model
	local model = Instance.new("Model")
	model.Name = "Scalpel"
	local blade = add(model, {
		Name = "Blade",
		Size = Vector3.new(0.025, 0.32, 0.09),
		CFrame = CFrame.new(0, 0.16, 0.02),
		Material = Enum.Material.Metal,
		Color = STEEL,
		Reflectance = 0.4,
		Ramp = "steel",
	})
	model.PrimaryPart = blade
	blade.PivotOffset = blade.CFrame:Inverse() -- (the pivot: the tip)
	add(model, {
		Name = "Handle",
		Size = Vector3.new(0.05, 0.8, 0.1),
		CFrame = CFrame.new(0, 0.72, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(150, 155, 160),
		Reflectance = 0.25,
		Ramp = "steel",
	})
	return model
end

local function hand(): Model
	local model = Instance.new("Model")
	model.Name = "Hands"
	-- (palm down, fingers toward -Z, the tips at the origin)
	local palm = add(model, {
		Name = "Palm",
		Size = Vector3.new(0.5, 0.16, 0.5),
		CFrame = CFrame.new(0, 0.12, 0.55),
		Color = GLOVE,
		Reflectance = 0.15,
		Ramp = "glove",
	})
	model.PrimaryPart = palm
	palm.PivotOffset = palm.CFrame:Inverse() -- (the pivot: the tip)
	for index = 1, 4 do
		local x = -0.18 + (index - 1) * 0.12
		add(model, {
			Name = "Finger",
			Size = Vector3.new(0.1, 0.09, 0.32),
			CFrame = CFrame.new(x, 0.06, 0.16) * CFrame.Angles(math.rad(-12), 0, 0),
			Color = GLOVE,
			Reflectance = 0.15,
			Ramp = "glove",
		})
	end
	add(model, {
		Name = "Thumb",
		Size = Vector3.new(0.1, 0.09, 0.28),
		CFrame = CFrame.new(-0.3, 0.08, 0.45) * CFrame.Angles(0, math.rad(-35), 0),
		Color = GLOVE,
		Reflectance = 0.15,
		Ramp = "glove",
	})
	add(model, {
		Name = "Wrist",
		Size = Vector3.new(0.42, 0.3, 0.6),
		CFrame = CFrame.new(0, 0.2, 1.05),
		Color = Color3.fromRGB(45, 70, 130),
		Ramp = "glove",
	})
	return model
end

local function shears(): Model
	local model = Instance.new("Model")
	model.Name = "Shears"
	local hinge = add(model, {
		Name = "Hinge",
		Size = Vector3.new(0.08, 0.08, 0.08),
		CFrame = CFrame.new(0, 0.35, 0),
		Material = Enum.Material.Metal,
		Color = STEEL,
		Ramp = "steel",
	})
	model.PrimaryPart = hinge
	hinge.PivotOffset = hinge.CFrame:Inverse() -- (the pivot: the tip)
	for _, side in { -1, 1 } do
		add(model, {
			Name = "Blade",
			Size = Vector3.new(0.04, 0.4, 0.07),
			CFrame = CFrame.new(side * 0.03, 0.18, 0) * CFrame.Angles(0, 0, math.rad(side * 6)),
			Material = Enum.Material.Metal,
			Color = STEEL,
			Reflectance = 0.35,
			Ramp = "steel",
		})
		add(model, {
			Name = "Grip",
			Size = Vector3.new(0.07, 0.6, 0.09),
			CFrame = CFrame.new(side * 0.12, 0.65, 0) * CFrame.Angles(0, 0, math.rad(-side * 12)),
			Color = Color3.fromRGB(170, 30, 30),
			Ramp = "rubber",
		})
	end
	return model
end

function Tools.build(parent: Instance): Tools
	local folder = Instance.new("Folder")
	folder.Name = "Tools"
	folder.Parent = parent
	return {
		folder = folder,
		models = { Scalpel = scalpel(), Hands = hand(), Shears = shears() },
		shown = nil,
	}
end

-- Puts the tool `name` at `at` (where the mouse points), leaning toward the
-- camera; the others hidden.
function Tools.show(tools: Tools, name: string?, at: Vector3, camera: CFrame, pressing: boolean)
	if tools.shown ~= name then
		for key, model in tools.models do
			model.Parent = if key == name then tools.folder else nil
		end
		tools.shown = name
	end
	if name == nil then
		return
	end
	local model = tools.models[name]
	local toCamera = camera.Position - at
	local flat = Vector3.new(toCamera.X, 0, toCamera.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, 1)
	local side = flat:Cross(UP)
	if name == "Hands" then
		local lift = if pressing then 0.02 else 0.12
		model:PivotTo(CFrame.lookAt(at + UP * lift, at + UP * lift - flat))
		return
	end
	local lean = if name == "Scalpel" then 0.75 else 0.55
	local handle = (UP + flat * lean + side * 0.25).Unit
	local tip = at + UP * (if pressing then 0 else 0.05)
	model:PivotTo(CFrame.lookAt(tip, tip + handle) * CFrame.Angles(-math.pi / 2, 0, 0))
end

return Tools
