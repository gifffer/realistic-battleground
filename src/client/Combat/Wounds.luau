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

-- A small flat disc of bruise lying on the skin at `at` (part space),
-- facing `out`.
local function spot(
	part: BasePart,
	folder: Instance,
	at: Vector3,
	out: Vector3,
	diameter: number,
	squash: number,
	transparency: number,
	dark: number,
	age: number,
	roll: number
)
	local up = Vector3.new(0, 1, 0)
	local y = (up - out * up:Dot(out))
	y = if y.Magnitude > 1e-3 then y.Unit else Vector3.new(0, 0, 1)
	local piece = newPart(
		"Bruise",
		Enum.PartType.Cylinder,
		Vector3.new(0.01, diameter, diameter * squash),
		FRESH
	)
	piece.Transparency = transparency
	ageing(piece, age, dark)
	attach(piece, part, CFrame.fromMatrix(at, out, y) * CFrame.Angles(roll, 0, 0), folder)
end

-- One bruise, built in `folder` on `part`.
local function draw(part: BasePart, key: string, data: Bruise.Data, folder: Instance)
	local random = Random.new(data.seed)
	local level = data.level
	local head = key == "Head"
	local size = (BASE_SIZE[key] or LIMB_SIZE) * (0.7 + 0.25 * level)
	local age = workspace:GetServerTimeNow() - data.born
	local strength = 0.06 * (level - 1)
	local at, out = onSkin(part, data.point)
	-- The skin's axes there: Y up it, Z across it (`out` is X).
	local upAxis = Vector3.new(0, 1, 0)
	local across = out:Cross(upAxis)
	across = if across.Magnitude > 1e-3 then across.Unit else Vector3.new(1, 0, 0)

	-- Swelling: a lump of skin under it (the face swells; the body a little).
	local thick = 0
	if (head and level >= 2) or level >= 3 then
		thick = (if head then 0.045 else 0.025) * (level - 1)
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
		attach(lump, part, CFrame.fromMatrix(at, out, upAxis), folder)
	end

	if head then
		-- The round head: many small discs, each lying on the curve (and on
		-- the lump), thick in the middle and sparse at the edge.
		local angle0 = math.atan2(at.X, at.Z)
		local count = 14 + 4 * level
		for index = 1, count do
			local r = math.sqrt(random:NextNumber()) * size * 0.62 -- (denser in the middle)
			local t = random:NextNumber(0, math.pi * 2)
			local du, dv = r * math.cos(t), r * math.sin(t) * 0.85
			local angle = angle0 + du / 0.6
			local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
			local y = math.clamp(at.Y + dv, -0.36, 0.36)
			local over = math.max(0, math.abs(y) - 0.3)
			local radius = 0.3 + math.sqrt(math.max(0, 0.09 - over * over))
			-- (on the lump: higher toward its middle)
			local rise = 0
			if thick > 0 then
				local e = (du / (size * 0.475)) ^ 2 + (dv / (size * 0.4)) ^ 2
				rise = thick * math.sqrt(math.max(0, 1 - e))
			end
			local edge = r / (size * 0.62)
			local diameter = size * random:NextNumber(0.2, 0.34) * (1.15 - 0.5 * edge)
			spot(
				part,
				folder,
				dir * (radius + rise + 0.006 + index * 0.0004) + Vector3.new(0, y, 0),
				dir,
				diameter,
				random:NextNumber(0.65, 0.95),
				math.clamp(
					0.35 + 0.5 * edge - strength + random:NextNumber(-0.05, 0.05),
					0.15,
					0.92
				),
				0.75 + 0.35 * edge,
				age,
				random:NextNumber(0, math.pi)
			)
		end
	else
		-- A flat face: wide pale layers to a small dark middle, blotches
		-- off-centre; all kept on the face (not hanging off its edge).
		local reach = size * 0.65 + size * 0.32 * 0.4
		local half = part.Size / 2
		local roomAcross = math.abs((half * across):Dot(across)) - reach
		local roomUp = half.Y - reach
		if roomAcross < 0 or roomUp < 0 then
			local fit = math.min(math.abs((half * across):Dot(across)), half.Y) / (0.65 + 0.128)
			size = math.min(size, fit)
			reach = size * 0.778
			roomAcross = math.max(0, math.abs((half * across):Dot(across)) - reach)
			roomUp = math.max(0, half.Y - reach)
		end
		local u = math.clamp(at:Dot(across), -roomAcross, roomAcross)
		local v = math.clamp(at.Y, -roomUp, roomUp)
		local center = out * math.abs((half * out):Dot(out)) + across * u + upAxis * v
		local layers = {
			{ scale = 1.3, squash = 0.85, transparency = 0.88, dark = 1.1 },
			{ scale = 1.0, squash = 0.8, transparency = 0.74, dark = 1 },
			{ scale = 0.72, squash = 0.78, transparency = 0.58, dark = 0.9 },
			{ scale = 0.45, squash = 0.75, transparency = 0.42, dark = 0.75 },
		}
		local lift = 0.008 + thick * 0.95
		for index, layer in layers do
			local nudge = across * random:NextNumber(-0.06, 0.06) * size
				+ upAxis * random:NextNumber(-0.06, 0.06) * size
			spot(
				part,
				folder,
				center + out * (lift + index * 0.0025) + nudge,
				out,
				size * layer.scale,
				layer.squash,
				math.max(0.15, layer.transparency - strength),
				layer.dark,
				age,
				random:NextNumber(0, math.pi)
			)
		end
		for _ = 1, 2 + level do
			local offset = across * random:NextNumber(-0.32, 0.32) * size
				+ upAxis * random:NextNumber(-0.32, 0.32) * size
			spot(
				part,
				folder,
				center + out * (lift + 0.012) + offset,
				out,
				random:NextNumber(0.22, 0.38) * size,
				random:NextNumber(0.6, 0.9),
				math.max(0.2, 0.6 - strength),
				0.85,
				age,
				random:NextNumber(0, math.pi)
			)
		end
	end

	-- A hard blow on the face splits the skin: a short cut across it, a run
	-- of blood down from it.
	if head and level >= 3 then
		local skin = at + out * (thick * 0.9 + 0.012)
		local frame = CFrame.fromMatrix(skin + upAxis * size * 0.12, out, upAxis)
		local cut =
			newPart("Split", Enum.PartType.Block, Vector3.new(0.012, 0.022, size * 0.3), CUT)
		cut.Reflectance = 0.1
		attach(cut, part, frame * CFrame.Angles(random:NextNumber(-0.4, 0.4), 0, 0), folder)
		local length = 0.16 + 0.04 * level
		local run = newPart("Blood", Enum.PartType.Block, Vector3.new(0.01, length, 0.022), BLOOD)
		run.Reflectance = 0.1
		attach(
			run,
			part,
			frame * CFrame.new(0.002, -length / 2, random:NextNumber(-0.04, 0.04)),
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

local FADE_OUT = 1.2 -- seconds a healed (or changed) bruise takes to go

-- Fades out (then removes) the parts of bruise `index` on `part`.
local function fadeOut(folder: Instance, index: number)
	for _, piece in folder:GetChildren() do
		if piece:IsA("BasePart") and piece:GetAttribute("BruiseIndex") == index then
			piece:SetAttribute("BruiseIndex", nil)
			TweenService:Create(piece, TweenInfo.new(FADE_OUT), { Transparency = 1 }):Play()
			task.delay(FADE_OUT, function()
				piece:Destroy()
			end)
		end
	end
end

-- Draws again only the bruises that changed: a new or grown one appears,
-- a healed one fades away (the others stay as they are).
local function refresh(model: Model, partName: string)
	local key = Gash.KEY_OF[partName]
	local part = model:FindFirstChild(partName)
	if key == nil or part == nil or not part:IsA("BasePart") then
		return
	end
	local hidden = covered(model, partName)
	local folder: Instance = part:FindFirstChild("Wounds")
		or (function(): Instance
			local created = Instance.new("Folder")
			created.Name = "Wounds"
			created.Parent = part
			return created
		end)()
	-- What each bruise looked like when drawn: kept on its pieces
	-- ("BruiseIndex", "BruiseText"), so nothing else has to remember it.
	local before: { [number]: string } = {}
	for _, piece in folder:GetChildren() do
		local index, text = piece:GetAttribute("BruiseIndex"), piece:GetAttribute("BruiseText")
		if typeof(index) == "number" and typeof(text) == "string" then
			before[index] = text
		end
	end
	for index = 1, Bruise.MAX_PER_PART do
		local value = model:GetAttribute(Bruise.attribute(key, index))
		local data = if hidden then nil else Bruise.decode(value)
		local text = if data then value :: string else nil
		if text ~= before[index] then
			fadeOut(folder, index)
			if data then
				-- (built aside, then moved in: Gashes hides marks over a cut
				-- as they are added to "Wounds")
				local fresh = Instance.new("Folder")
				draw(part, key, data, fresh)
				for _, piece in fresh:GetChildren() do
					piece:SetAttribute("BruiseIndex", index)
					piece:SetAttribute("BruiseText", text)
					piece.Parent = folder
				end
				fresh:Destroy()
			end
		end
	end
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
