--!strict
-- Wounds: the bruises where a fighter took blows ("Bruise_<Part>_<n>"
-- attributes from the server, see Shared/Util/Bruise), drawn the same on
-- every client. Also starts Gashes (glass cuts) and GlassShards.
--
-- What a real bruise looks like, and how it is drawn:
--   • blood under the skin: a soft, mottled patch with a blotchy outline
--     (never a circle), darker where the blood pooled deeper, broken up
--     and paler toward its edge, a faint blue-purple tint at the rim, and
--     pinpoint dots of bleeding (petechiae) in it - many small see-through
--     ovals overlapping on the skin;
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
local Config = require(ReplicatedStorage.Shared.Config)
local Gash = require(ReplicatedStorage.Shared.Util.Gash)
local Gashes = require(script.Parent.Gashes)
local BloodAge = require(script.Parent.BloodAge)
local GlassShards = require(script.Parent.GlassShards)

local Wounds = {}

-- Colours over time (seconds since the blow).
local FRESH = Color3.fromRGB(168, 52, 60) -- red: blood just out of the vessels
local PURPLE = Color3.fromRGB(98, 36, 74)
local BLUE = Color3.fromRGB(62, 42, 92)
local TO_PURPLE = 18 -- seconds
local TO_BLUE = 70
local CUT = Color3.fromRGB(104, 12, 12)
local PETECHIA = Color3.fromRGB(96, 8, 18) -- pinpoint bleeding under the skin
local RIM = Color3.fromRGB(78, 62, 118) -- the blue-purple tint at a bruise's edge
local BLOOD = Config.Blood.PALETTE.VENOUS

-- Size of a level-1 bruise, studs (it grows with its level).
local BASE_SIZE: { [string]: number } = {
	Head = 0.18,
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

-- The bruise pictures (Config.Injuries.BRUISE_IMAGES), if uploaded.
local IMAGES = Config.Injuries.BRUISE_IMAGES
local function hasImages(): boolean
	return IMAGES.blobs[1] ~= 0
end

-- The same colour change as `ageing`, on a picture's tint.
local function ageingImage(image: ImageLabel, age: number, dark: number)
	local function shade(c: Color3): Color3
		return Color3.new(c.R * dark, c.G * dark, c.B * dark)
	end
	image.ImageColor3 = shade(colourAt(age))
	if age < TO_PURPLE then
		local toPurple = TweenService:Create(
			image,
			TweenInfo.new(TO_PURPLE - age),
			{ ImageColor3 = shade(PURPLE) }
		)
		toPurple:Play()
		toPurple.Completed:Once(function()
			if image.Parent then
				TweenService
					:Create(
						image,
						TweenInfo.new(TO_BLUE - TO_PURPLE),
						{ ImageColor3 = shade(BLUE) }
					)
					:Play()
			end
		end)
	elseif age < TO_BLUE then
		TweenService:Create(image, TweenInfo.new(TO_BLUE - age), { ImageColor3 = shade(BLUE) })
			:Play()
	end
end

-- A soft picture of bruise lying on the skin at `at` (part space), facing
-- `out`, `size` studs across, turned `rotation` degrees: a see-through
-- plate with the picture on its outer face (lit like the skin). `fixed`: a
-- colour that doesn't age.
local function picture(
	part: BasePart,
	folder: Instance,
	at: Vector3,
	out: Vector3,
	upAxis: Vector3,
	size: number,
	imageId: number,
	transparency: number,
	dark: number,
	age: number,
	rotation: number,
	layer: number,
	fixed: Color3?
)
	local plate = newPart("Bruise", Enum.PartType.Block, Vector3.new(0.004, size, size), FRESH)
	plate.Transparency = 1
	attach(plate, part, CFrame.fromMatrix(at, out, upAxis), folder)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right -- (the plate's X: out of the skin)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 600
	gui.LightInfluence = 1
	gui.ZOffset = layer
	gui.Parent = plate
	local image = Instance.new("ImageLabel")
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.Image = `rbxassetid://{imageId}`
	image.ImageTransparency = transparency
	image.Rotation = rotation
	if fixed then
		image.ImageColor3 = fixed
	else
		ageingImage(image, age, dark)
	end
	image.Parent = gui
	-- (a picture ignores LocalTransparencyModifier: hidden with your own
	-- limb in first person)
	local function follow()
		gui.Enabled = part.LocalTransparencyModifier < 0.99
	end
	local link = part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(follow)
	plate.Destroying:Once(function()
		link:Disconnect()
	end)
	follow()
end

-- A small flat oval of bruise lying on the skin at `at` (part space),
-- facing `out` (a flattened sphere mesh: soft, a true oval). `fixed`: a
-- colour that doesn't change with the bruise's age.
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
	roll: number,
	fixed: Color3?
)
	local up = Vector3.new(0, 1, 0)
	local y = (up - out * up:Dot(out))
	y = if y.Magnitude > 1e-3 then y.Unit else Vector3.new(0, 0, 1)
	local piece = newPart(
		"Bruise",
		Enum.PartType.Block,
		Vector3.new(0.008, diameter, diameter * squash),
		FRESH
	)
	local oval = Instance.new("SpecialMesh")
	oval.MeshType = Enum.MeshType.Sphere
	oval.Parent = piece
	piece.Transparency = transparency
	if fixed then
		piece.Color = fixed
	else
		ageing(piece, age, dark)
	end
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
	if head then
		-- (on the straight band of the round head, so it all fits on it)
		local reach = math.min(0.3, size * 0.5 * 1.3)
		local y = math.clamp(at.Y, -0.3 + reach * 0.5, 0.3 - reach * 0.5)
		at = out * 0.6 + Vector3.new(0, y, 0)
	end
	-- The skin's axes there: Y up it, Z across it (`out` is X).
	local upAxis = Vector3.new(0, 1, 0)
	local across = out:Cross(upAxis)
	across = if across.Magnitude > 1e-3 then across.Unit else Vector3.new(1, 0, 0)

	-- Swelling: a lump of skin under it (the face swells; the body a little).
	local thick = 0
	if (head and level >= 2) or level >= 3 then
		-- (a slight puffiness, not a ball: it barely stands out)
		thick = (if head then 0.018 else 0.012) * (level - 1)
	end
	local center = at -- (where the lump goes: the bruise's real centre)

	-- Where a point (du across, dv up, from the bruise's centre) is on the
	-- skin, and which way is out: around the round head's curve (and over
	-- the lump); on a flat face, on it (kept inside its edges).
	local place: (du: number, dv: number, lift: number) -> (Vector3, Vector3)
	if head then
		local angle0 = math.atan2(at.X, at.Z)
		place = function(du: number, dv: number, lift: number): (Vector3, Vector3)
			local angle = angle0 + du / 0.6
			local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
			local y = math.clamp(at.Y + dv, -0.36, 0.36)
			local over = math.max(0, math.abs(y) - 0.3)
			local radius = 0.3 + math.sqrt(math.max(0, 0.09 - over * over))
			-- (on the lump: higher toward its middle)
			local rise = 0
			if thick > 0 then
				local e = (du / (size * 0.275)) ^ 2 + (dv / (size * 0.4)) ^ 2
				rise = thick * math.sqrt(math.max(0, 1 - e))
			end
			-- (tilted with the head's curve on its rounded top / bottom)
			local tilt = if over > 0
				then Vector3.new(0, math.sign(y) * over / 0.3, 0)
				else Vector3.zero
			return dir * (radius + rise + lift) + Vector3.new(0, y, 0), (dir + tilt).Unit
		end
	else
		local half = part.Size / 2
		local wide = math.abs((half * across):Dot(across))
		-- (its widest: the wobbling outline reaches 0.8 × size, an oval's
		-- half more: 1.06 × size from its centre - all kept on the face)
		local room = math.min(wide, half.Y) - 0.03
		size = math.min(size, room / 1.06)
		local reach = size * 1.06
		local roomAcross = math.max(0, wide - 0.03 - reach)
		local roomUp = math.max(0, half.Y - 0.03 - reach)
		local u = math.clamp(at:Dot(across), -roomAcross, roomAcross)
		local v = math.clamp(at.Y, -roomUp, roomUp)
		local face = out * math.abs((half * out):Dot(out))
		center = face + across * u + upAxis * v
		place = function(du: number, dv: number, lift: number): (Vector3, Vector3)
			-- (never past the face's edges)
			local a = math.clamp(u + du, -wide + 0.03, wide - 0.03)
			local b = math.clamp(v + dv, -half.Y + 0.03, half.Y - 0.03)
			local e = (du / (size * 0.275)) ^ 2 + (dv / (size * 0.4)) ^ 2
			local rise = thick * 0.95 * math.sqrt(math.max(0, 1 - e))
			return face + across * a + upAxis * b + out * (lift + rise), out
		end
	end

	-- Swelling: a lump of skin under it (the face swells; the body a little;
	-- a slight puffiness, not a ball). An ellipsoid: a block shown as a
	-- sphere stretched to its size.
	if thick > 0 then
		local lump = newPart(
			"Swelling",
			Enum.PartType.Block,
			Vector3.new(thick * 2, size * 0.8, size * 0.55),
			part.Color
		)
		local shape = Instance.new("SpecialMesh")
		shape.MeshType = Enum.MeshType.Sphere
		shape.Parent = lump
		attach(lump, part, CFrame.fromMatrix(center, out, upAxis), folder)
	end

	-- Without the pictures: many small soft ovals overlapping.
	local function drawOvals()
		-- Its outline isn't a circle: the radius wobbles around it (a few
		-- waves), so every bruise has its own blotchy shape.
		local waves: { { amplitude: number, phase: number, k: number } } = {}
		for k = 2, 5 do
			table.insert(waves, {
				amplitude = random:NextNumber(0.05, 0.22) / (k * 0.5),
				phase = random:NextNumber(0, math.pi * 2),
				k = k,
			})
		end
		local stretch = random:NextNumber(0.75, 1.1) -- (a little taller or wider)
		local function edgeAt(theta: number): number
			local r = 1
			for _, wave in waves do
				r += wave.amplitude * math.cos(wave.k * theta + wave.phase)
			end
			return size * 0.5 * math.max(0.55, r)
		end

		-- Blood under the skin: many small soft ovals overlapping, see-through,
		-- so it's mottled and darker where they pile up (the middle), paler and
		-- broken up toward its uneven edge.
		local count = 16 + 5 * level
		for index = 1, count do
			local theta = random:NextNumber(0, math.pi * 2)
			local limit = edgeAt(theta)
			local r = limit * random:NextNumber() ^ 0.9 * 0.85
			local du, dv = r * math.cos(theta), r * math.sin(theta) * stretch
			local edge = r / limit
			local pos, o = place(du, dv, 0.006 + index * 0.00025)
			spot(
				part,
				folder,
				pos,
				o,
				size * random:NextNumber(0.38, 0.6) * (1.05 - 0.25 * edge),
				random:NextNumber(0.6, 0.95),
				math.clamp(
					0.72 + 0.24 * edge - strength + random:NextNumber(-0.04, 0.04),
					0.55,
					0.95
				),
				0.75 + 0.4 * edge + random:NextNumber(-0.08, 0.08),
				age,
				random:NextNumber(0, math.pi),
				nil
			)
		end
		-- Where the blood pooled deeper: a few darker patches near the middle.
		for index = 1, 1 + level do
			local theta = random:NextNumber(0, math.pi * 2)
			local r = edgeAt(theta) * random:NextNumber(0, 0.45)
			local pos, o =
				place(r * math.cos(theta), r * math.sin(theta) * stretch, 0.0165 + index * 0.0003)
			spot(
				part,
				folder,
				pos,
				o,
				size * random:NextNumber(0.18, 0.3),
				random:NextNumber(0.6, 0.9),
				math.clamp(0.42 - strength, 0.2, 0.6),
				0.62,
				age,
				random:NextNumber(0, math.pi),
				nil
			)
		end
		-- Pinpoint bleeding (petechiae): tiny dark-red dots scattered in it.
		for index = 1, 4 + 2 * level do
			local theta = random:NextNumber(0, math.pi * 2)
			local r = edgeAt(theta) * random:NextNumber(0.15, 0.95)
			local pos, o =
				place(r * math.cos(theta), r * math.sin(theta) * stretch, 0.019 + index * 0.0002)
			local d = random:NextNumber(0.012, 0.028)
			spot(
				part,
				folder,
				pos,
				o,
				d,
				random:NextNumber(0.7, 1),
				random:NextNumber(0.15, 0.4),
				1,
				age,
				0,
				PETECHIA
			)
		end
		-- A faint tint at the rim: blue-purple where the blood is spreading.
		for index = 1, 3 do
			local theta = random:NextNumber(0, math.pi * 2)
			local r = edgeAt(theta) * random:NextNumber(0.8, 1.02)
			local pos, o =
				place(r * math.cos(theta), r * math.sin(theta) * stretch, 0.004 + index * 0.0002)
			spot(
				part,
				folder,
				pos,
				o,
				size * random:NextNumber(0.25, 0.4),
				random:NextNumber(0.5, 0.8),
				0.86,
				1,
				age,
				random:NextNumber(0, math.pi),
				RIM
			)
		end
	end

	-- With the pictures: a few soft, mottled pictures layered on the skin
	-- (a faint wider halo, the bruise, a darker clump, pinpoint bleeding).
	if hasImages() then
		local blobs = IMAGES.blobs
		local function blobId(): number
			local id = blobs[random:NextInteger(1, #blobs)]
			return if id ~= 0 then id else blobs[1]
		end
		local raise = 0.006 -- (place() already lifts over the swelling)
		local function at2(du: number, dv: number, lift: number): (Vector3, Vector3)
			return place(du, dv, raise + lift)
		end
		-- (a flat picture on the round head: kept small enough to follow it)
		local most = if head then 0.42 else 10
		if IMAGES.rim ~= 0 then
			local p, o = at2(0, 0, 0.001)
			picture(
				part,
				folder,
				p,
				o,
				upAxis,
				math.min(size * 1.7, most * 1.15),
				IMAGES.rim,
				0.55 + 0.1 * random:NextNumber(),
				1.25,
				age,
				random:NextNumber(0, 360),
				1,
				nil
			)
		end
		local p, o = at2(0, 0, 0.002)
		picture(
			part,
			folder,
			p,
			o,
			upAxis,
			math.min(size * 1.25, most),
			blobId(),
			math.clamp(0.12 - strength, 0, 0.3),
			1,
			age,
			random:NextNumber(0, 360),
			2,
			nil
		)
		for index = 1, math.max(1, level - 1) do
			local du = random:NextNumber(-0.18, 0.18) * size
			local dv = random:NextNumber(-0.18, 0.18) * size
			local q, n = at2(du, dv, 0.003 + index * 0.0005)
			picture(
				part,
				folder,
				q,
				n,
				upAxis,
				math.min(size * random:NextNumber(0.55, 0.75), most * 0.7),
				blobId(),
				0.35,
				0.65,
				age,
				random:NextNumber(0, 360),
				2 + index,
				nil
			)
		end
		if IMAGES.petechiae ~= 0 then
			local q, n = at2(0, 0, 0.006)
			picture(
				part,
				folder,
				q,
				n,
				upAxis,
				math.min(size * 1.0, most * 0.9),
				IMAGES.petechiae,
				0.15,
				1,
				age,
				random:NextNumber(0, 360),
				8,
				PETECHIA
			)
		end
	else
		drawOvals()
	end

	-- A hard blow on the face splits the skin: a short cut across it, a run
	-- of blood down from it.
	if head and level >= 3 then
		local skin = at + out * (thick + 0.026) -- (above every layer of the bruise)
		local frame = CFrame.fromMatrix(skin + upAxis * size * 0.12, out, upAxis)
		local cut =
			newPart("Split", Enum.PartType.Block, Vector3.new(0.012, 0.022, size * 0.3), CUT)
		cut.Reflectance = 0.1
		attach(cut, part, frame * CFrame.Angles(random:NextNumber(-0.4, 0.4), 0, 0), folder)
		local length = 0.16 + 0.04 * level
		local run = newPart("Blood", Enum.PartType.Block, Vector3.new(0.01, length, 0.022), BLOOD)
		run.Reflectance = 0.1
		-- (tapered like real blood running, not a straight band)
		local spindle = Instance.new("SpecialMesh")
		spindle.MeshType = Enum.MeshType.Sphere
		spindle.Parent = run
		attach(
			run,
			part,
			frame * CFrame.new(0.002, -length / 2, random:NextNumber(-0.04, 0.04)),
			folder
		)
		BloodAge.track(run, "wound", Config.Blood.PALETTE.ARTERIAL)
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
			for _, image in piece:GetDescendants() do
				if image:IsA("ImageLabel") then
					TweenService:Create(image, TweenInfo.new(FADE_OUT), { ImageTransparency = 1 })
						:Play()
				end
			end
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
