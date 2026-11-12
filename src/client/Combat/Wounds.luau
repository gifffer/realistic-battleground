--!strict
-- Wounds: the bruises where a fighter took blows ("Bruise_<Part>_<n>"
-- attributes from the server, see Shared/Util/Bruise), drawn the same on
-- every client. Also starts Gashes (glass cuts) and GlassShards.
--
-- What a real bruise looks like, and how it is drawn:
--   • blood under the skin: a soft, uneven patch, darker in the middle,
--     fading out at the edges - a few flat layers on the skin, each one
--     wider and more see-through, plus a couple of blotches off-centre;
--   • its colour changes: red / pink right after the blow, purple within
--     tens of seconds, then blue-purple (a fight is short: no yellow-green);
--   • hit again on the same spot (level 1..4): bigger, darker, and on the
--     face it SWELLS (a lump under the bruise: puffy cheek, swollen eye,
--     lump on the brow); a hard one splits the skin over the brow or cheek
--     (a small cut with a run of blood);
--   • under clothes (a shirt / pants), you don't see the body's bruises.
-- Welded to the part (they follow the animations); under a "Wounds" folder
-- (Gashes hides those over a cut, HeadBlast those of a burst head).
--
--   Wounds.watch(model)   start drawing this fighter's bruises

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Bruise = require(ReplicatedStorage.Shared.Util.Bruise)
local Gash = require(ReplicatedStorage.Shared.Util.Gash)
local Gashes = require(script.Parent.Gashes)
local GlassShards = require(script.Parent.GlassShards)

local Wounds = {}

-- Colours over time (seconds since the blow).
local FRESH = Color3.fromRGB(168, 52, 60) -- red: blood just out of the vessels
local PURPLE = Color3.fromRGB(98, 36, 74)
local BLUE = Color3.fromRGB(62, 42, 92)
local TO_PURPLE = 18 -- seconds
local TO_BLUE = 70
local CUT = Color3.fromRGB(104, 12, 12)
local BLOOD = Color3.fromRGB(86, 8, 8)

-- Size of a level-1 bruise, studs (it grows with its level).
local BASE_SIZE: { [string]: number } = {
	Head = 0.22,
	Torso = 0.4,
}
local LIMB_SIZE = 0.34

-- The skin of a body part at `p` (part space): where, and which way is out.
local function onSkin(part: BasePart, p: Vector3): (Vector3, Vector3)
	if part.Name == "Head" then
		-- The round classic head (radius 0.6, straight from -0.3 to 0.3).
		local flat = Vector3.new(p.X, 0, p.Z)
		local out = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
		local y = math.clamp(p.Y, -0.36, 0.36)
		local over = math.max(0, math.abs(y) - 0.3)
		local radius = 0.3 + math.sqrt(math.max(0, 0.09 - over * over))
		return out * radius + Vector3.new(0, y, 0), out
	end
	-- A block: the side face the point is on.
	local half = part.Size / 2
	local x, z = p.X / half.X, p.Z / half.Z
	if math.abs(x) > math.abs(z) then
		local out = Vector3.new(math.sign(x), 0, 0)
		return Vector3.new(math.sign(x) * half.X, p.Y, math.clamp(p.Z, -half.Z * 0.8, half.Z * 0.8)),
			out
	end
	local out = Vector3.new(0, 0, if z >= 0 then 1 else -1)
	return Vector3.new(math.clamp(p.X, -half.X * 0.85, half.X * 0.85), p.Y, out.Z * half.Z), out
end

local function newPart(name: string, shape: Enum.PartType, size: Vector3, color: Color3): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Shape = shape
	piece.Size = size
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.Massless = true
	return piece
end

local function attach(piece: BasePart, part: BasePart, offset: CFrame, folder: Instance)
	piece.CFrame = part.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = folder
end

-- The bruise's colour `age` seconds after the blow, and the tweens that
-- carry it on (purple, then blue).
local function colourAt(age: number): Color3
	if age < TO_PURPLE then
		return FRESH:Lerp(PURPLE, age / TO_PURPLE)
	elseif age < TO_BLUE then
		return PURPLE:Lerp(BLUE, (age - TO_PURPLE) / (TO_BLUE - TO_PURPLE))
	end
	return BLUE
end

local function ageing(piece: BasePart, age: number, dark: number)
	local function shade(c: Color3): Color3
		return Color3.new(c.R * dark, c.G * dark, c.B * dark)
	end
	piece.Color = shade(colourAt(age))
	if age < TO_PURPLE then
		local toPurple =
			TweenService:Create(piece, TweenInfo.new(TO_PURPLE - age), { Color = shade(PURPLE) })
		toPurple:Play()
		toPurple.Completed:Once(function()
			if piece.Parent then
				TweenService
					:Create(piece, TweenInfo.new(TO_BLUE - TO_PURPLE), { Color = shade(BLUE) })
					:Play()
			end
		end)
	elseif age < TO_BLUE then
		TweenService:Create(piece, TweenInfo.new(TO_BLUE - age), { Color = shade(BLUE) }):Play()
	end
end

-- One bruise, built in `folder` on `part`.
local function draw(part: BasePart, key: string, data: Bruise.Data, folder: Instance)
	local random = Random.new(data.seed)
	local level = data.level
	local head = key == "Head"
	local size = (BASE_SIZE[key] or LIMB_SIZE) * (0.7 + 0.25 * level)
	local at, out = onSkin(part, data.point)
	local up = if math.abs(out.Y) < 0.9 then Vector3.new(0, 1, 0) else Vector3.new(0, 0, 1)
	-- (a cylinder's axis is its X: along `out`, lying flat on the skin)
	local base = CFrame.fromMatrix(at, out, up:Cross(out))
	local age = workspace:GetServerTimeNow() - data.born

	-- Swelling: a lump of skin under it (the face swells; the body a little).
	local lift = 0.008
	if (head and level >= 2) or level >= 3 then
		local thick = (if head then 0.045 else 0.025) * (level - 1)
		-- (an ellipsoid: a block shown as a sphere stretched to its size)
		local lump = newPart(
			"Swelling",
			Enum.PartType.Block,
			Vector3.new(thick * 2, size * 0.95, size * 0.8),
			part.Color
		)
		local shape = Instance.new("SpecialMesh")
		shape.MeshType = Enum.MeshType.Sphere
		shape.Parent = lump
		attach(lump, part, base * CFrame.new(0, 0, 0), folder)
		lift += thick * 0.95
	end

	-- The patch: wide and pale at the edge, small and dark in the middle,
	-- plus blotches off-centre (an uneven shape).
	local strength = 0.06 * (level - 1)
	local layers = {
		{ scale = 1.3, squash = 0.85, transparency = 0.88, dark = 1.1 },
		{ scale = 1.0, squash = 0.8, transparency = 0.74, dark = 1 },
		{ scale = 0.72, squash = 0.78, transparency = 0.58, dark = 0.9 },
		{ scale = 0.45, squash = 0.75, transparency = 0.42, dark = 0.75 },
	}
	for index, layer in layers do
		local roll = random:NextNumber(0, math.pi)
		local nudgeY, nudgeZ =
			random:NextNumber(-0.06, 0.06) * size, random:NextNumber(-0.06, 0.06) * size
		local piece = newPart(
			"Bruise",
			Enum.PartType.Cylinder,
			Vector3.new(0.01, size * layer.scale, size * layer.scale * layer.squash),
			FRESH
		)
		piece.Transparency = math.max(0.15, layer.transparency - strength)
		ageing(piece, age, layer.dark)
		attach(
			piece,
			part,
			base * CFrame.new(lift + index * 0.0025, nudgeY, nudgeZ) * CFrame.Angles(roll, 0, 0),
			folder
		)
	end
	for _ = 1, 2 + level do
		local offset = Vector3.new(
			0,
			random:NextNumber(-0.32, 0.32) * size,
			random:NextNumber(-0.32, 0.32) * size
		)
		local blot = random:NextNumber(0.22, 0.38) * size
		local piece = newPart(
			"Blotch",
			Enum.PartType.Cylinder,
			Vector3.new(0.01, blot, blot * random:NextNumber(0.6, 0.9)),
			FRESH
		)
		piece.Transparency = math.max(0.2, 0.6 - strength)
		ageing(piece, age, 0.85)
		attach(
			piece,
			part,
			base
				* CFrame.new(lift + 0.012, offset.Y, offset.Z)
				* CFrame.Angles(random:NextNumber(0, math.pi), 0, 0),
			folder
		)
	end

	-- A hard blow on the face splits the skin: a short cut, a run of blood.
	if head and level >= 3 then
		local cut =
			newPart("Split", Enum.PartType.Block, Vector3.new(0.012, 0.022, size * 0.3), CUT)
		cut.Reflectance = 0.1
		attach(
			cut,
			part,
			base
				* CFrame.new(lift + 0.02, size * 0.12, 0)
				* CFrame.Angles(random:NextNumber(-0.4, 0.4), 0, 0),
			folder
		)
		local run = newPart(
			"Blood",
			Enum.PartType.Block,
			Vector3.new(0.01, 0.16 + 0.04 * level, 0.022),
			BLOOD
		)
		run.Reflectance = 0.1
		attach(
			run,
			part,
			base
				* CFrame.new(
					lift + 0.018,
					size * 0.12 - (0.08 + 0.02 * level),
					random:NextNumber(-0.04, 0.04)
				),
			folder
		)
	end
end

-- Does clothing cover this part (no bruise seen through a shirt / pants)?
local function covered(model: Model, partName: string): boolean
	if partName == "Head" then
		return false
	end
	local wearsShirt = model:FindFirstChildOfClass("Shirt") ~= nil
	local wearsPants = model:FindFirstChildOfClass("Pants") ~= nil
	if partName == "Torso" or partName == "Left Arm" or partName == "Right Arm" then
		return wearsShirt
	end
	return wearsPants
end

local function refresh(model: Model, partName: string)
	local key = Gash.KEY_OF[partName]
	local part = model:FindFirstChild(partName)
	if key == nil or part == nil or not part:IsA("BasePart") then
		return
	end
	local folder = part:FindFirstChild("Wounds")
	if folder then
		folder:Destroy()
	end
	if covered(model, partName) then
		return
	end
	local created = Instance.new("Folder")
	created.Name = "Wounds"
	for index = 1, Bruise.MAX_PER_PART do
		local data = Bruise.decode(model:GetAttribute(Bruise.attribute(key, index)))
		if data then
			draw(part, key, data, created)
		end
	end
	if #created:GetChildren() == 0 then
		created:Destroy()
		return
	end
	created.Parent = part
end

function Wounds.watch(model: Model)
	Gashes.watch(model) -- glass cuts, drawn for real
	GlassShards.watch(model) -- bits of glass stuck in the skin
	model.AttributeChanged:Connect(function(name: string)
		if Bruise.isAttribute(name) then
			local key = string.match(name, "^" .. Bruise.PREFIX .. "(%a+)_%d+$")
			local partName = if key then Gash.PART_OF[key] else nil
			if partName then
				refresh(model, partName)
			end
		end
	end)
	-- (clothes put on / off: seen or not)
	model.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Clothing") then
			for partName in Gash.KEY_OF do
				refresh(model, partName)
			end
		end
	end)
	for partName in Gash.KEY_OF do
		refresh(model, partName)
	end
end

return table.freeze(Wounds)
