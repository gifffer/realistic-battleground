--!strict
-- RiftBurn: someone burning ("Burning" attribute: "Acid" / "Fire", set by
-- the server while Dr. Rift's acid, ray or explosive flask burns them).
--
--   RiftBurn.watch(model)
--
-- FIRE: real flames licking up the body. On every body part two layers of
-- flame (a small bright core close to the skin, a bigger orange tongue
-- around it, both flickering), embers floating up, thin black smoke rising
-- above the shoulders and the head, a faint pale haze over them (the heat
-- shimmer, faked), and an orange light that flickers on everything around.
-- The skin goes dark (the torso most, the legs least) and the burn spreads
-- over the body (clothes included): mottled black / purple-brown char,
-- lighter blistered and peeled patches, glossy, soot around. When it stops:
-- the flames die down, the body smoulders (grey smoke) for 2 s.
--
-- ACID: the skin corroding. Clusters of pale yellow-green foam bubbles grow
-- and pop in a little puff on the skin (always somewhere new), it froths
-- and fizzes, caustic vapour rises, the skin turns a little raw and is
-- eaten where the acid hit: raw red-brown flesh with a darker crusty
-- margin, wet, running down in streaks; drops of acid fall from the body
-- and fizz on the floor.
--
-- The burn marks are pictures (Config.Injuries.BURN_IMAGES, made by
-- tools/burns/make_burns.py) on the burnt parts' faces, growing while it
-- burns. Without their ids: simpler patches (overlapping ovals). Either
-- way they STAY when the burn ends, like the other wounds, until the body
-- is healed (a kill, a new round: health jumps back up), dies and
-- respawns, or leaves. Burnt again: the same marks, and a few more.
--
-- The marks and bubbles are built only when they show, a few parts a
-- frame for everybody (an explosion setting many fighters on fire at once
-- doesn't hitch).
--
-- The skin colour: the body parts are tinted, and the pieces drawn over
-- them that wear the skin colour (Gashes' "Skin", "Core", "*_Lip", Wounds'
-- "Swelling", the gore's skin: any piece under the part of its colour),
-- from their real colour, saved first. The real colour comes back exactly
-- once the tint has faded. It is also kept as an attribute on the part
-- ("RiftBurnSkin"), so a copy of a burning body (a clone) can get it back
-- and other effects can read the real skin. A choked head (BouncerFx turns
-- it red) is left alone while it is choked.
--
-- Everything the burn adds is in a "RiftBurn" folder in the model (the
-- patches, bubbles), "RiftBurnScar" once it ended, or named "RiftBurn..."
-- under its parts (particles, light, the pictures' surfaces); the effects
-- are removed when it ends or the model dies, the marks when it is healed,
-- leaves the game or is destroyed. One Heartbeat drives every burning model
-- (and stops when nobody burns).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

-- A burnt fighter cries out (Shared/Sounds "BurnCry"), at most this often.
local CRY_INTERVAL = 2.5
local nextCry: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local HeadBlast = require(script.Parent.HeadBlast)

local RiftBurn = {}
local P = require(script.Parent.RiftParts)
local ACID = P.ACID
local ACID_DARK = P.ACID_DARK
local emitter = P.emitter
local ghost = P.ghost
local stick = P.stick
local floorUnder = P.floorUnder

local random = Random.new()

------------------------------------------------------------------------------
-- Look
------------------------------------------------------------------------------

-- Fire colours: white-yellow at the root of a flame, orange, then dark red
-- where it dies; soot and char.
local FLAME_WHITE = Color3.fromRGB(255, 244, 200)
local FLAME_YELLOW = Color3.fromRGB(255, 196, 84)
local FLAME_ORANGE = Color3.fromRGB(255, 118, 30)
local FLAME_RED = Color3.fromRGB(170, 40, 10)
local EMBER = Color3.fromRGB(255, 150, 50)
local SOOT = Color3.fromRGB(38, 35, 32)
local SMOKE_GREY = Color3.fromRGB(84, 80, 76)
local CHAR = Color3.fromRGB(26, 16, 16) -- burnt black
local CHAR_PURPLE = Color3.fromRGB(54, 32, 36) -- the purple-brown of a deep burn
local SCORCH = Color3.fromRGB(84, 52, 38) -- singed brown edge
local SHEEN = Color3.fromRGB(150, 116, 112) -- peeled, wet, glossy skin
local GLOW = Color3.fromRGB(255, 92, 20) -- a glowing speck in the char
local FIRE_LIGHT = Color3.fromRGB(255, 128, 48)

-- Acid colours.
local FOAM = Color3.fromRGB(204, 236, 96)
local FROTH = Color3.fromRGB(226, 240, 168)
local VAPOUR = Color3.fromRGB(186, 212, 116)
local RAW = Color3.fromRGB(156, 56, 44) -- eaten skin: raw red flesh
local RAW_DEEP = Color3.fromRGB(110, 38, 30) -- deeper, red-brown
local CRUST = Color3.fromRGB(84, 30, 20) -- the dark crusty margin
local SLOUGH = Color3.fromRGB(204, 158, 128) -- pale dead skin

-- The burn pictures' halo: soot around fire, inflamed skin around acid.
local HALO_FIRE = Color3.fromRGB(70, 46, 36)
local HALO_ACID = Color3.fromRGB(150, 84, 70)

-- What the whole skin shifts toward (how far: CHAR_MAX / RAW_MAX; less
-- with the pictures, which show the burn themselves).
local SKIN_CHAR = Color3.fromRGB(40, 28, 22)
local SKIN_RAW = Color3.fromRGB(184, 96, 80)
local CHAR_MAX = 0.55
local RAW_MAX = 0.38
local CHAR_MAX_PICTURES = 0.28
local RAW_MAX_PICTURES = 0.2
-- How fast (share of the full tint per second): on while it burns, off
-- after (slower: the char stays a while).
local CHAR_ON = 0.32
local CHAR_OFF = 0.11
local RAW_ON = 0.3
local RAW_OFF = 0.12

local HEAL_FADE = 1.2 -- seconds the marks take to go when healed
local SMOULDER = 2 -- seconds of smoke once the fire is out
local MARK_SPREAD = 2.2 -- the patches appear one by one over this time
-- A heal (a kill, a new round) gives back at least this much health at
-- once, or all of it (a knocked out fighter getting up gets less).
local HEAL_JUMP = 30

local HEAD_RADIUS = 0.6 -- the classic head: a rounded cylinder this wide
local HEAD_HALF = 0.32 -- and this high (half), where patches can go

local BODY = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

-- How much of the burn each part gets (flame rates, patches, bubbles).
local SHARE: { [string]: number } = {
	Torso = 1,
	Head = 0.55,
	["Right Arm"] = 0.5,
	["Left Arm"] = 0.5,
	["Right Leg"] = 0.3,
	["Left Leg"] = 0.3,
}
local MARKS: { [string]: number } = {
	Torso = 4,
	Head = 2,
	["Right Arm"] = 2,
	["Left Arm"] = 2,
	["Right Leg"] = 1,
	["Left Leg"] = 1,
}
-- Foam clusters (three bubbles each) per part.
local BUBBLES: { [string]: number } = {
	Torso = 3,
	Head = 1,
	["Right Arm"] = 2,
	["Left Arm"] = 2,
	["Right Leg"] = 1,
	["Left Leg"] = 1,
}

-- The patches and bubbles are built when they first show, at most this many
-- parts a frame for everybody (an explosion sets many fighters on fire at
-- once: no hitch).
local BUILD_PER_FRAME = 20
-- At most this many patches / pictures of one kind of burn on a body (burnt
-- again and again: the old marks come back, new ones join them only up to
-- this).
local MAX_MARKS = 40
local MAX_PICTURES = 110
local CLUSTER = 3 -- bubbles in a foam cluster

-- How hard each part's skin is tinted (the torso, in the middle of the
-- flames, the most; the legs, under them, the least).
local function tintWeight(name: string): number
	return 0.4 + 0.6 * (SHARE[name] or 0.3)
end

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

-- One blob of a patch, planned first (built when the patch shows): its size
-- (share of the patch), place on the skin (dx, dy: share of its size),
-- stretch and turn, look, and how far it stands out of the skin.
type LayerPlan = {
	scale: number,
	dx: number,
	dy: number,
	stretch: number,
	spin: number,
	color: Color3,
	material: Enum.Material,
	alpha: number, -- its transparency
	lift: number,
	glow: boolean, -- a glowing speck (cools down to char when it ends)
}

-- A built blob.
type Layer = { part: BasePart, mesh: SpecialMesh, alpha: number }

-- A patch on the skin (char or acid blotch): grows from a dot when it shows.
type Mark = {
	base: BasePart,
	offset: CFrame, -- its centre on the skin (base space, Z out)
	fit: number, -- its radius
	thick: number,
	wet: boolean,
	plans: { LayerPlan },
	layers: { Layer }, -- (empty until it shows)
	showAt: number, -- (os.clock)
	startedAt: number, -- when it really showed (building can wait a frame)
	grow: number, -- seconds to full size
	shown: boolean,
	done: boolean,
}

-- A burn picture on a face of a body part (BURN_IMAGES): grows from a
-- small dot to its full size while it burns (acid: from its top, running
-- down).
type Picture = {
	base: BasePart,
	face: Enum.NormalId, -- (on the head: the outer face of a small plate)
	plate: CFrame?, -- the head: where the plate goes (head space, Z out)
	at: Vector2, -- its centre (studs from the face's top left corner)
	size: Vector2, -- full size, studs
	image: number,
	color: Color3,
	alpha: number, -- its transparency in the end
	rotation: number,
	drip: boolean, -- grows downward from its top (acid running)
	layer: number, -- (ZIndex: halos under the burns)
	showAt: number, -- (os.clock)
	startedAt: number,
	grow: number, -- seconds to full size
	label: ImageLabel?, -- (built when it shows)
	run: Frame?, -- acid: the frame that uncovers it from its top (grows down)
	shown: boolean,
	done: boolean,
}

-- A foam cluster (a few bubbles together): grows on the skin, pops, comes
-- back somewhere else.
type Bubble = {
	base: BasePart,
	parts: { BasePart },
	meshes: { SpecialMesh },
	welds: { Weld },
	lags: { number }, -- each bubble starts swelling a little later
	at: CFrame, -- the cluster's centre (base space)
	born: number,
	life: number, -- seconds growing before it pops
	popAt: number,
	nextAt: number,
}

-- A flickering particle layer: its normal rate, and a noise seed.
type Flicker = { emitter: ParticleEmitter, rate: number, seed: number, speed: number }

-- One burn of one kind on one model (a new one when the kind changes).
type Session = {
	model: Model,
	kind: string,
	folder: Folder,
	emitters: { Instance }, -- particles (and their attachments)
	flickers: { Flicker },
	headEmitters: { ParticleEmitter }, -- on the head (gone if it bursts)
	viewEmitters: { ParticleEmitter }, -- hidden in our own first person
	light: PointLight?,
	marks: { Mark },
	glows: { BasePart }, -- the glowing specks in the char
	pictures: { Picture },
	surfaces: { Instance }, -- the pictures' SurfaceGuis (and head plates)
	bubbles: { Bubble },
	pop: ParticleEmitter?, -- the fizz of a bubble popping (moved to it)
	popPoint: Attachment?,
	nextDrip: number,
	seed: number,
	headGone: boolean, -- the head burst (HeadBlast): nothing left on it
	healedAt: number?, -- healed while it burns: what showed before goes when it ends
}

-- The marks of an ended burn, staying on the body until it is healed
-- (taken back if the same burn starts again).
type Scar = {
	model: Model,
	kind: string,
	folder: Folder,
	marks: { Mark },
	glows: { BasePart },
	pictures: { Picture },
	surfaces: { Instance },
	tweens: { Tween },
	token: number, -- changes when taken back (the delayed steps then skip)
}

-- The skin tint of a model: its real colours and how far it is charred /
-- raw (0..1 of CHAR_MAX / RAW_MAX), and where each is going.
type Tint = {
	originals: { [BasePart]: Color3 },
	weights: { [BasePart]: number },
	written: { [BasePart]: Color3 }, -- the last colour put on each part
	copies: { [BasePart]: { BasePart } }, -- skin pieces drawn over each part
	scanned: number, -- when the copies were last looked for
	char: number,
	raw: number,
	charGoal: number,
	rawGoal: number,
	applied: number, -- last time the colours were written
	headFreeUntil: number, -- the head is someone else's until then (choked)
}

local sessions: { [Model]: Session } = {}
local tints: { [Model]: Tint } = {}
-- The marks of ended burns, still on the body.
local scars: { [Folder]: Scar } = {}
local heartbeat: RBXScriptConnection? = nil
-- Parts that may still be built this frame (BUILD_PER_FRAME).
local budget = BUILD_PER_FRAME

local ORIGINAL_ATTRIBUTE = "RiftBurnSkin"

-- The burn pictures (Config.Injuries.BURN_IMAGES), if uploaded.
local IMAGES = Config.Injuries.BURN_IMAGES
local function imagesOf(kind: string): { number }
	return if kind == "Fire" then IMAGES.fire else IMAGES.acid
end
local function hasPictures(kind: string): boolean
	for _, id in imagesOf(kind) do
		if id ~= 0 then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------------
-- Skin tint
------------------------------------------------------------------------------

-- Two colours the same (to a hair: Color3 values go through 8 bits).
local function sameColor(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 0.006
		and math.abs(a.G - b.G) < 0.006
		and math.abs(a.B - b.B) < 0.006
end

-- The pieces drawn over a body part that wear its skin colour: Gashes'
-- copies of the skin ("Skin", "Core", "*_Lip"), Wounds' "Swelling", and
-- the skin pieces of the gore (WaistCut, ArmRip, HeadBlast: they take the
-- part's colour when they are made, the real one or the tinted one).
local function findCopies(part: BasePart, original: Color3, written: Color3?): { BasePart }
	local found = {}
	for _, piece in part:GetDescendants() do
		if not piece:IsA("BasePart") or string.sub(piece.Name, 1, 8) == "RiftBurn" then
			continue
		end
		local name = piece.Name
		local color = piece.Color
		if
			name == "Skin"
			or name == "Core"
			or name == "Swelling"
			or string.sub(name, -4) == "_Lip"
			or sameColor(color, original)
			or (written ~= nil and sameColor(color, written))
		then
			table.insert(found, piece)
		end
	end
	return found
end

local function rescan(tint: Tint)
	for part, original in tint.originals do
		tint.copies[part] = findCopies(part, original, tint.written[part])
	end
end

-- The head is being choked (BouncerFx turns it red, then back over 4 s):
-- leave it alone meanwhile.
local function headIsBusy(model: Model, tint: Tint, now: number): boolean
	if model:GetAttribute("Held") ~= nil then
		tint.headFreeUntil = now + 4.3
		return true
	end
	return now < tint.headFreeUntil
end

local function paint(tint: Tint, part: BasePart, color: Color3)
	part.Color = color
	tint.written[part] = color
	local copies = tint.copies[part]
	if copies then
		for _, piece in copies do
			if piece.Parent then
				piece.Color = color
			end
		end
	end
end

local function applyTint(model: Model, tint: Tint, now: number)
	local headBusy = headIsBusy(model, tint, now)
	local charPictures = hasPictures("Fire")
	local rawPictures = hasPictures("Acid")
	for part, original in tint.originals do
		if part.Parent == nil or (headBusy and part.Name == "Head") then
			continue
		end
		local weight = tint.weights[part] or 1
		local char = tint.char * (if charPictures then CHAR_MAX_PICTURES else CHAR_MAX) * weight
		local raw = tint.raw * (if rawPictures then RAW_MAX_PICTURES else RAW_MAX) * weight
		paint(tint, part, original:Lerp(SKIN_RAW, raw):Lerp(SKIN_CHAR, char))
	end
end

-- Back to the real colours, exactly.
local function restoreTint(model: Model)
	local tint = tints[model]
	tints[model] = nil
	if tint == nil then
		return
	end
	rescan(tint) -- (pieces made since the last look)
	for part, original in tint.originals do
		paint(tint, part, original)
		part:SetAttribute(ORIGINAL_ATTRIBUTE, nil)
	end
end

local BODY_COLORS: { [string]: string } = {
	Head = "HeadColor3",
	Torso = "TorsoColor3",
	["Right Arm"] = "RightArmColor3",
	["Left Arm"] = "LeftArmColor3",
	["Right Leg"] = "RightLegColor3",
	["Left Leg"] = "LeftLegColor3",
}

local function tintOf(model: Model): Tint
	local tint = tints[model]
	if tint then
		return tint
	end
	local held = model:GetAttribute("Held") ~= nil
	local colors = model:FindFirstChildOfClass("BodyColors")
	local originals: { [BasePart]: Color3 } = {}
	local weights: { [BasePart]: number } = {}
	for _, name in BODY do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			-- (a copy of a body that was tinted: its saved real colour; a
			-- choked head is red now: its real colour is in BodyColors)
			local saved = part:GetAttribute(ORIGINAL_ATTRIBUTE)
			local original = part.Color
			if typeof(saved) == "Color3" then
				original = saved
			elseif held and name == "Head" and colors then
				original = (colors :: any)[BODY_COLORS[name]] :: Color3
			end
			originals[part] = original
			weights[part] = tintWeight(name)
			-- (before any tint: the others can read the real colour here)
			part:SetAttribute(ORIGINAL_ATTRIBUTE, original)
		end
	end
	local created: Tint = {
		originals = originals,
		weights = weights,
		written = {},
		copies = {},
		scanned = os.clock(),
		char = 0,
		raw = 0,
		charGoal = 0,
		rawGoal = 0,
		applied = 0,
		headFreeUntil = 0,
	}
	rescan(created)
	tints[model] = created
	return created
end

------------------------------------------------------------------------------
-- Points on the skin
------------------------------------------------------------------------------

-- A frame on the skin at `position` (part space) facing out along `normal`
-- (its Z), turned by `spin` around it.
local function frameOn(position: Vector3, normal: Vector3, spin: number): CFrame
	return CFrame.fromMatrix(position, Vector3.new(0, 1, 0):Cross(normal), Vector3.yAxis)
		* CFrame.Angles(0, 0, spin)
end

-- A random spot on the sides of a body part (not its top or bottom, hidden
-- by the body) with room for something `radius` wide: its frame (part
-- space, Z out of the skin) and the radius that fits. `low`: the lower half
-- (where drops form). `upright`: not turned (its Y up the part: acid runs
-- down it).
local function skinSpot(
	part: BasePart,
	radius: number,
	low: boolean?,
	upright: boolean?
): (CFrame, number)
	local spin = if upright then 0 else random:NextNumber(0, math.pi * 2)
	if part.Name == "Head" then
		local fit = math.min(radius, 0.22)
		local angle = random:NextNumber(0, math.pi * 2)
		local top = HEAD_HALF - fit * 0.5
		local height = random:NextNumber(-top, if low then 0 else top)
		local normal = Vector3.new(math.sin(angle), 0, math.cos(angle))
		return frameOn(normal * HEAD_RADIUS + Vector3.new(0, height, 0), normal, spin), fit
	end
	local size = part.Size
	-- Front / back (width X) or the sides (width Z), by their area.
	local frontArea = size.X * size.Y
	local sideArea = size.Z * size.Y
	local onFront = random:NextNumber(0, frontArea + sideArea) < frontArea
	local sign = if random:NextNumber() < 0.5 then -1 else 1
	local across = if onFront then Vector3.xAxis else Vector3.zAxis
	local normal = if onFront then Vector3.zAxis * sign else Vector3.xAxis * sign
	local halfWidth = (if onFront then size.X else size.Z) * 0.5
	local halfDepth = (if onFront then size.Z else size.X) * 0.5
	local halfHeight = size.Y * 0.5
	local fit = math.min(radius, halfWidth * 0.9, halfHeight * 0.9)
	local roomX = math.max(halfWidth - fit, 0)
	local roomY = math.max(halfHeight - fit, 0)
	local x = random:NextNumber(-roomX, roomX)
	local y = random:NextNumber(-roomY, if low then 0 else roomY)
	return frameOn(normal * halfDepth + across * x + Vector3.yAxis * y, normal, spin), fit
end

-- An ellipsoid stuck on the skin (a patch layer, a bubble): a part shown as
-- a sphere stretched to its size, welded on.
local function blob(
	name: string,
	base: BasePart,
	offset: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number,
	parent: Instance
): (BasePart, SpecialMesh, Weld)
	local part = ghost(name, size, color, material)
	part.Transparency = transparency
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(0.05, 0.05, 1)
	mesh.Parent = part
	stick(base, part, offset, parent)
	local weld = part:FindFirstChildOfClass("Weld") :: Weld
	return part, mesh, weld
end

------------------------------------------------------------------------------
-- Patches (char / acid blotches)
------------------------------------------------------------------------------

-- The patches of a burn, each with its moment to show (spread over the
-- first seconds: the char creeps over the body). Only planned here: the
-- parts are built when a patch shows (stepMarks). `share`: of the usual
-- count (a burn starting again adds only a few).
local function addMarks(session: Session, ownHead: boolean, share: number)
	local now = os.clock()
	local isFire = session.kind == "Fire"
	for _, name in BODY do
		local base = session.model:FindFirstChild(name)
		if not (base and base:IsA("BasePart")) or (name == "Head" and ownHead) then
			continue
		end
		local wanted = (MARKS[name] or 0) * share
		local count = math.floor(wanted) + (if random:NextNumber() < wanted % 1 then 1 else 0)
		for index = 1, count do
			if #session.marks >= MAX_MARKS then
				return
			end
			local radius = if name == "Torso"
				then random:NextNumber(0.28, 0.55)
				else random:NextNumber(0.22, 0.42)
			local offset, fit = skinSpot(base, radius, false, not isFire)
			local plans: { LayerPlan } = {}
			-- One blob of the patch (a patch is a few of them overlapping: a
			-- ragged shape, never rings). `stretch` / `spin`: given, or at
			-- random.
			local function layer(
				scale: number,
				dx: number,
				dy: number,
				color: Color3,
				material: Enum.Material,
				alpha: number,
				lift: number,
				glow: boolean?,
				stretch: number?,
				spin: number?
			)
				table.insert(plans, {
					scale = scale,
					dx = dx,
					dy = dy,
					stretch = stretch or random:NextNumber(0.5, 1),
					spin = spin or random:NextNumber(0, math.pi * 2),
					color = color,
					material = material,
					alpha = alpha,
					lift = lift,
					glow = glow == true,
				})
			end
			local function jitter(): number
				return random:NextNumber(-0.32, 0.32)
			end
			if isFire then
				-- Like a deep burn: a singed brown halo (two blobs), mottled
				-- char inside (black and purple-brown clumps), maybe a pale
				-- glossy patch where the skin peeled, maybe a glowing speck.
				layer(0.95, jitter() * 0.3, jitter() * 0.3, SCORCH, Enum.Material.Sand, 0.5, 0)
				layer(0.75, jitter(), jitter(), SCORCH, Enum.Material.Sand, 0.4, 0.004)
				local coreX, coreY = 0, 0
				for clump = 1, random:NextInteger(2, 3) do
					coreX, coreY = jitter(), jitter()
					layer(
						random:NextNumber(0.3, 0.55),
						coreX,
						coreY,
						if clump == 2 then CHAR_PURPLE else CHAR,
						Enum.Material.Slate,
						random:NextNumber(0.05, 0.25),
						0.02 + clump * 0.006
					)
				end
				if random:NextNumber() < 0.45 then
					layer(
						random:NextNumber(0.14, 0.24),
						jitter(),
						jitter(),
						SHEEN,
						Enum.Material.SmoothPlastic,
						0.2,
						0.05
					)
				end
				if random:NextNumber() < 0.45 then
					layer(
						random:NextNumber(0.08, 0.16),
						coreX,
						coreY,
						GLOW,
						Enum.Material.Neon,
						0.15,
						0.055,
						true
					)
				end
			else
				-- Eaten skin: a dark crusty margin, raw red-brown flesh in it,
				-- runs going down from it (the acid flowed), maybe a pale bit
				-- of dead skin.
				layer(
					0.95,
					jitter() * 0.3,
					jitter() * 0.3,
					CRUST,
					Enum.Material.SmoothPlastic,
					0.3,
					0
				)
				for _ = 1, random:NextInteger(1, 2) do
					layer(
						random:NextNumber(0.5, 0.75),
						jitter() * 0.6,
						jitter() * 0.6,
						if random:NextNumber() < 0.5 then RAW else RAW_DEEP,
						Enum.Material.SmoothPlastic,
						0.05,
						0.02
					)
				end
				for _ = 1, random:NextInteger(1, 2) do
					local x = jitter() * 1.4
					local long = random:NextNumber(0.7, 1.2)
					layer(
						random:NextNumber(0.18, 0.28),
						x,
						-long * 0.9,
						RAW_DEEP,
						Enum.Material.SmoothPlastic,
						0.1,
						0.015,
						false,
						long / 0.25,
						0
					)
				end
				if random:NextNumber() < 0.4 then
					layer(
						random:NextNumber(0.12, 0.22),
						jitter(),
						jitter(),
						SLOUGH,
						Enum.Material.SmoothPlastic,
						0.15,
						0.04
					)
				end
			end
			local first = share >= 1 and name == "Torso" and index == 1
			table.insert(session.marks, {
				base = base,
				offset = offset,
				fit = fit,
				thick = if name == "Head" then 0.1 else 0.07,
				wet = not isFire,
				plans = plans,
				layers = {},
				showAt = now + (if first then 0 else random:NextNumber(0, MARK_SPREAD)),
				startedAt = 0,
				grow = random:NextNumber(0.7, 1.3),
				shown = false,
				done = false,
			})
		end
	end
end

-- The parts of a patch, now (a dot, growing in stepMarks).
local function buildMark(session: Session, mark: Mark)
	for _, plan in mark.plans do
		local width = mark.fit * 2 * plan.scale
		local size = Vector3.new(width, width * plan.stretch, mark.thick + plan.lift)
		-- (the bulge of the ellipsoid pokes a hair out of the skin)
		local at = mark.offset
			* CFrame.new(plan.dx * mark.fit, plan.dy * mark.fit, mark.thick * 0.18)
			* CFrame.Angles(0, 0, plan.spin)
		local part, mesh = blob(
			"RiftBurnMark",
			mark.base,
			at,
			size,
			plan.color,
			plan.material,
			plan.alpha,
			session.folder
		)
		part.Reflectance = if mark.wet then 0.14 else 0 -- (acid: wet)
		table.insert(mark.layers, { part = part, mesh = mesh, alpha = plan.alpha })
		if plan.glow then
			table.insert(session.glows, part)
		end
	end
end

local function stepMarks(session: Session, now: number)
	for _, mark in session.marks do
		if mark.done or now < mark.showAt then
			continue
		end
		if not mark.shown then
			-- (no room left this frame: next frame)
			if budget < #mark.plans or mark.base.Parent == nil then
				continue
			end
			budget -= #mark.plans
			buildMark(session, mark)
			mark.shown = true
			mark.startedAt = now
		end
		local t = math.min((now - mark.startedAt) / mark.grow, 1)
		local eased = 1 - (1 - t) * (1 - t) -- quick, then slower
		local scale = 0.15 + 0.85 * eased
		for _, item in mark.layers do
			item.mesh.Scale = Vector3.new(scale, scale, 1)
		end
		mark.done = t >= 1
	end
end

------------------------------------------------------------------------------
-- Burn pictures (BURN_IMAGES)
------------------------------------------------------------------------------

local PIXELS = 160 -- pixels per stud on the pictures' surfaces (sharp up close)
local SIDES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local HEAD_PICTURE = 0.32 -- studs: a picture on the round head (a small flat plate)
-- When the fire reaches each part (seconds, then up to FIRE_SPREAD more):
-- from the torso outward, the legs last.
local REACH: { [string]: number } = {
	Torso = 0,
	Head = 0.6,
	["Right Arm"] = 0.4,
	["Left Arm"] = 0.4,
	["Right Leg"] = 1.1,
	["Left Leg"] = 1.1,
}
local FIRE_SPREAD = 1.8
-- How much of each part's length the fire burns, at least (a band along
-- it, the rest of it up to the whole part).
local BAND: { [string]: number } = {
	Torso = 0.6,
	["Right Arm"] = 0.55,
	["Left Arm"] = 0.55,
	["Right Leg"] = 0.5,
	["Left Leg"] = 0.5,
}
local FIRE_CELL = 1.2 -- studs: the fire's pictures, one about every this much
-- Where acid lands besides the torso (picked by weight).
local SPLASHED =
	{ "Right Arm", "Left Arm", "Right Arm", "Left Arm", "Head", "Right Leg", "Left Leg" }

-- Width and height (studs) of a side face of a block part.
local function faceSize(part: BasePart, face: Enum.NormalId): Vector2
	local size = part.Size
	if face == Enum.NormalId.Left or face == Enum.NormalId.Right then
		return Vector2.new(size.Z, size.Y)
	end
	return Vector2.new(size.X, size.Y)
end

-- Plans the pictures of a burn: only where and when, they are built when
-- they show (stepPictures). Fire burns a band along every part, from the
-- torso outward: the same height on all four sides of a part (where a
-- picture goes past the edge of a side, the next side is burnt there too),
-- big overlapping pictures making one dark area, a soft soot halo around
-- it. Acid eats where it landed (the torso and a limb or two) and runs
-- down, with a few smaller splashes elsewhere. `share`: of the usual
-- amount (a burn starting again adds only a few).
local function addPictures(session: Session, ownHead: boolean, share: number)
	local images: { number } = {}
	for _, id in imagesOf(session.kind) do
		if id ~= 0 then
			table.insert(images, id)
		end
	end
	if #images == 0 then
		return
	end
	local now = os.clock()
	local isFire = session.kind == "Fire"
	-- One picture, planned (none past MAX_PICTURES).
	local function picture(
		base: BasePart,
		face: Enum.NormalId,
		plate: CFrame?,
		at: Vector2,
		size: Vector2,
		drip: boolean,
		delay: number,
		grow: number,
		image: number,
		color: Color3,
		alpha: number,
		layer: number
	)
		if #session.pictures >= MAX_PICTURES then
			return
		end
		-- (fire: kept along the limb, either way up; acid: upright, it runs)
		local flip = if drip or random:NextNumber() < 0.5 then 0 else 180
		table.insert(session.pictures, {
			base = base,
			face = face,
			-- (on the head: the halo's plate under the burn's, a hair apart)
			plate = if plate then plate * CFrame.new(0, 0, 0.0015 * layer) else nil,
			at = if plate then size * 0.5 else at, -- (a plate: in its middle)
			size = size,
			image = image,
			color = color,
			alpha = alpha,
			rotation = flip + random:NextNumber(-8, 8),
			drip = drip,
			layer = layer,
			showAt = now + delay,
			startedAt = 0,
			grow = grow,
			label = nil,
			run = nil,
			shown = false,
			done = false,
		})
	end
	local function burn(
		base: BasePart,
		face: Enum.NormalId,
		plate: CFrame?,
		at: Vector2,
		size: Vector2,
		drip: boolean,
		delay: number,
		grow: number
	)
		local shade = random:NextNumber(0.88, 1)
		picture(
			base,
			face,
			plate,
			at,
			size,
			drip,
			delay,
			grow,
			images[random:NextInteger(1, #images)],
			Color3.new(shade, shade, shade),
			random:NextNumber(0, 0.08),
			random:NextInteger(2, 4)
		)
	end
	-- The soft halo under a burn (soot or redness), a little bigger.
	local function halo(
		base: BasePart,
		face: Enum.NormalId,
		plate: CFrame?,
		at: Vector2,
		size: Vector2,
		drip: boolean,
		delay: number,
		grow: number
	)
		if IMAGES.halo ~= 0 then
			picture(
				base,
				face,
				plate,
				at,
				size,
				drip,
				delay,
				grow,
				IMAGES.halo,
				if isFire then HALO_FIRE else HALO_ACID,
				if isFire then 0.45 else 0.62,
				1
			)
		end
	end
	-- One burn with its halo (acid, the head).
	local function add(
		base: BasePart,
		face: Enum.NormalId,
		plate: CFrame?,
		at: Vector2,
		size: Vector2,
		drip: boolean,
		delay: number,
		grow: number
	)
		halo(base, face, plate, at, size * 1.35, drip, delay, grow)
		burn(base, face, plate, at, size, drip, delay, grow)
	end
	-- On the round head: a small plate standing on it, just outside the skin
	-- (a flat plate touching a round head at its middle: its edges a hair
	-- off it; not our own head: in the way of the camera in first person).
	local function onHead(head: BasePart, delay: number, grow: number)
		if ownHead then
			return
		end
		local frame = skinSpot(head, HEAD_PICTURE * 0.5, false, true)
		-- (the plate is as big as its halo, the burn in its middle)
		local plate = frame * CFrame.new(0, 0, 0.003)
		local wide = HEAD_PICTURE * (if IMAGES.halo ~= 0 then 1.35 else 1)
		local middle = Vector2.new(wide, wide) * 0.5
		halo(
			head,
			Enum.NormalId.Back,
			plate,
			middle,
			Vector2.new(wide, wide),
			not isFire,
			delay,
			grow
		)
		burn(
			head,
			Enum.NormalId.Back,
			plate,
			middle,
			Vector2.new(HEAD_PICTURE, HEAD_PICTURE),
			not isFire,
			delay,
			grow
		)
	end
	local function partNamed(name: string): BasePart?
		local part = session.model:FindFirstChild(name)
		return if part and part:IsA("BasePart") then part else nil
	end

	if isFire then
		-- Every part the first time; burnt again, one or two of them more.
		local names: { string } = {}
		if share >= 1 then
			names = table.clone(BODY)
		else
			for _ = 1, random:NextInteger(1, 2) do
				table.insert(names, BODY[random:NextInteger(1, #BODY)])
			end
		end
		for _, name in names do
			local base = partNamed(name)
			if base == nil then
				continue
			end
			local reach = (REACH[name] or 1) + random:NextNumber(0, FIRE_SPREAD * 0.4)
			if name == "Head" then
				for _ = 1, if share >= 1 then 3 else 1 do
					onHead(
						base,
						reach + random:NextNumber(0, FIRE_SPREAD * 0.6),
						random:NextNumber(2, 3)
					)
				end
				continue
			end
			-- The band: the same on its four sides.
			local height = base.Size.Y
			local least = if share >= 1 then BAND[name] or 0.5 else 0.35
			local length = height * random:NextNumber(least, if share >= 1 then 1 else 0.6)
			local top = random:NextNumber(0, height - length)
			for _, face in SIDES do
				local room = faceSize(base, face)
				local columns = math.max(1, math.round(room.X))
				local rows = math.max(1, math.ceil(length / FIRE_CELL))
				local cell = Vector2.new(room.X / columns, length / rows)
				local delay = reach + random:NextNumber(0, FIRE_SPREAD * 0.6)
				-- (its ends a little ragged: not the same height on every side)
				local middle =
					Vector2.new(room.X * 0.5, top + length * 0.5 + random:NextNumber(-0.1, 0.1))
				halo(
					base,
					face,
					nil,
					middle,
					Vector2.new(room.X * 1.7, length * 1.35 + 0.4),
					false,
					delay,
					random:NextNumber(2.4, 3.4)
				)
				for column = 1, columns do
					for row = 1, rows do
						-- Big (they overlap into one burn and go past the
						-- edges of the side), longer than wide (along the
						-- limb), not quite in a grid.
						local width = cell.X * random:NextNumber(1.75, 2)
						local size = Vector2.new(
							width,
							math.max(
								cell.Y * random:NextNumber(1.8, 2.2),
								width * random:NextNumber(1.1, 1.3)
							)
						)
						local at = Vector2.new(
							cell.X * (column - 0.5) + random:NextNumber(-0.12, 0.12) * cell.X,
							top + cell.Y * (row - 0.5) + random:NextNumber(-0.18, 0.18) * cell.Y
						)
						burn(
							base,
							face,
							nil,
							at,
							size,
							false,
							delay + random:NextNumber(0, 0.5),
							random:NextNumber(2.2, 3.5)
						)
					end
				end
			end
		end
		return
	end

	-- Acid: where it landed, running down.
	local hit: { string } = {}
	if share >= 1 then
		table.insert(hit, "Torso")
		for _ = 1, random:NextInteger(1, 2) do
			table.insert(hit, SPLASHED[random:NextInteger(1, #SPLASHED)])
		end
	else
		table.insert(hit, SPLASHED[random:NextInteger(1, #SPLASHED)])
	end
	for index, name in hit do
		local base = partNamed(name)
		if base == nil then
			continue
		end
		local delay = if index == 1 then 0 else random:NextNumber(0, 0.6)
		if name == "Head" then
			onHead(base, delay, random:NextNumber(2.5, 4))
			continue
		end
		for faceIndex = 1, random:NextInteger(1, 2) do
			local face = SIDES[random:NextInteger(1, #SIDES)]
			local room = faceSize(base, face)
			local s = random:NextNumber(1.1, 1.6)
			local size = Vector2.new(s, s * random:NextNumber(1.3, 1.7))
			local top = room.Y * random:NextNumber(0.02, 0.3)
			add(
				base,
				face,
				nil,
				Vector2.new(room.X * random:NextNumber(0.35, 0.65), top + size.Y * 0.5),
				size,
				true,
				delay + (faceIndex - 1) * random:NextNumber(0.2, 0.6),
				random:NextNumber(2.5, 4)
			)
		end
	end
	-- Smaller splashes, here and there.
	for _ = 1, math.max(1, math.floor(random:NextInteger(2, 4) * share)) do
		local name = BODY[random:NextInteger(1, #BODY)]
		local base = partNamed(name)
		if base == nil then
			continue
		end
		if name == "Head" then
			onHead(base, random:NextNumber(0.2, 1.5), random:NextNumber(2, 3))
			continue
		end
		local face = SIDES[random:NextInteger(1, #SIDES)]
		local room = faceSize(base, face)
		local s = random:NextNumber(0.45, 0.7)
		local size = Vector2.new(s, s * random:NextNumber(1.2, 1.6))
		add(
			base,
			face,
			nil,
			Vector2.new(
				room.X * random:NextNumber(0.25, 0.75),
				room.Y * random:NextNumber(0.15, 0.6)
			),
			size,
			true,
			random:NextNumber(0.2, 1.5),
			random:NextNumber(1.5, 2.5)
		)
	end
end

-- Shows a SurfaceGui only while its part does (our own limbs in first
-- person: a picture ignores LocalTransparencyModifier; a limb hidden and
-- replaced by its copy with a hole while a glass cut is open, Gashes: the
-- burn would cover the hole).
local function followPart(gui: SurfaceGui, part: BasePart)
	local function follow()
		gui.Enabled = part.LocalTransparencyModifier < 0.99 and part.Transparency < 0.99
	end
	local link = part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(follow)
	local hidden = part:GetPropertyChangedSignal("Transparency"):Connect(follow)
	gui.Destroying:Once(function()
		link:Disconnect()
		hidden:Disconnect()
	end)
	follow()
end

local function newSurface(name: string, face: Enum.NormalId, layer: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS
	gui.LightInfluence = 1 -- (lit like the skin)
	gui.ZOffset = layer
	gui.MaxDistance = 250
	return gui
end

-- Where a picture goes: the clipping frame on its face of the part (one
-- SurfaceGui per face and kind, made once), or on the head a small plate
-- of its own (under the head: hidden with it if it bursts).
local function holderOf(session: Session, picture: Picture): GuiObject
	local base = picture.base
	local plate = picture.plate
	if plate then
		local piece = ghost(
			"RiftBurnPlate",
			Vector3.new(picture.size.X, picture.size.Y, 0.01),
			CHAR,
			Enum.Material.SmoothPlastic
		)
		piece.Transparency = 1
		stick(base, piece, plate, base)
		table.insert(session.surfaces, piece)
		local gui = newSurface("RiftBurnSurface", picture.face, 1)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundTransparency = 1
		frame.Parent = gui
		gui.Parent = piece
		return frame
	end
	local name = `RiftBurn{session.kind}{picture.face.Name}`
	local found = base:FindFirstChild(name)
	local clip = if found then found:FindFirstChild("Clip") else nil
	if clip and clip:IsA("Frame") then
		return clip
	end
	local gui = newSurface(name, picture.face, if session.kind == "Fire" then 2 else 3)
	local frame = Instance.new("Frame")
	frame.Name = "Clip"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.ClipsDescendants = true -- (a burn crossing the edge goes on the next side)
	frame.Parent = gui
	followPart(gui, base)
	gui.Parent = base
	table.insert(session.surfaces, gui)
	return frame
end

-- A picture's size `t` (0..1) of the way through its growth: a dot
-- spreading fast then slowly. Acid runs down: the whole picture is there,
-- uncovered from its top by a frame growing down steadily (stretching it
-- would squash it).
local RUN_WIDTH = 1.15 -- (the frame a little wider: the picture is turned a little)
local function pictureSize(picture: Picture, t: number): UDim2
	if picture.drip then
		-- (the frame uncovering it: all its width, more and more of its length)
		return UDim2.fromOffset(
			picture.size.X * RUN_WIDTH * PIXELS,
			picture.size.Y * (0.15 + 0.85 * t) * PIXELS
		)
	end
	local eased = 1 - (1 - t) * (1 - t)
	return UDim2.fromOffset(
		picture.size.X * (0.2 + 0.8 * eased) * PIXELS,
		picture.size.Y * (0.2 + 0.8 * eased) * PIXELS
	)
end

-- What grows: the picture, or (acid) the frame uncovering it.
local function grower(picture: Picture): GuiObject?
	return if picture.run then picture.run else picture.label
end

local function buildPicture(session: Session, picture: Picture)
	local label = Instance.new("ImageLabel")
	label.Name = "Burn"
	label.BackgroundTransparency = 1
	label.Image = `rbxassetid://{picture.image}`
	label.ImageColor3 = picture.color
	label.ImageTransparency = 1
	label.Rotation = picture.rotation
	label.ZIndex = picture.layer
	local holder = holderOf(session, picture)
	if picture.drip then
		-- Acid: at its full size in a frame hanging from its top, growing
		-- down (clipping it).
		local run = Instance.new("Frame")
		run.Name = "Run"
		run.BackgroundTransparency = 1
		run.ClipsDescendants = true
		run.ZIndex = picture.layer
		run.AnchorPoint = Vector2.new(0.5, 0)
		run.Position =
			UDim2.fromOffset(picture.at.X * PIXELS, (picture.at.Y - picture.size.Y * 0.5) * PIXELS)
		run.Size = pictureSize(picture, 0)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.new(0.5, 0, 0, picture.size.Y * 0.5 * PIXELS)
		label.Size = UDim2.fromOffset(picture.size.X * PIXELS, picture.size.Y * PIXELS)
		label.Parent = run
		run.Parent = holder
		picture.run = run
	else
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromOffset(picture.at.X * PIXELS, picture.at.Y * PIXELS)
		label.Size = pictureSize(picture, 0)
		label.Parent = holder
	end
	picture.label = label
end

local function stepPictures(session: Session, now: number)
	for _, picture in session.pictures do
		if picture.done or now < picture.showAt then
			continue
		end
		if not picture.shown then
			local cost = if picture.plate then 2 else 1
			if budget < cost or picture.base.Parent == nil then
				continue
			end
			budget -= cost
			buildPicture(session, picture)
			picture.shown = true
			picture.startedAt = now
		end
		local label = picture.label
		local growing = grower(picture)
		if label == nil or growing == nil then
			picture.done = true
			continue
		end
		local t = math.min((now - picture.startedAt) / picture.grow, 1)
		growing.Size = pictureSize(picture, t)
		label.ImageTransparency = 1 - (1 - picture.alpha) * math.min(t * 3, 1)
		picture.done = t >= 1
	end
end

------------------------------------------------------------------------------
-- Acid foam and drops
------------------------------------------------------------------------------

-- The cluster somewhere new on its part: a bubble and two smaller ones
-- against it, tiny, growing.
local function placeBubble(bubble: Bubble, now: number)
	local offset, fit = skinSpot(bubble.base, 0.16)
	local main = math.min(fit, random:NextNumber(0.07, 0.14)) * 2
	bubble.at = offset
	local turn = random:NextNumber(0, math.pi * 2)
	for index, part in bubble.parts do
		local size = if index == 1 then main else main * random:NextNumber(0.45, 0.7)
		local x, y = 0, 0
		if index > 1 then
			-- (round it, touching it)
			local angle = turn + (index - 2) * random:NextNumber(1.6, 2.6)
			local reach = (main + size) * 0.42
			x, y = math.cos(angle) * reach, math.sin(angle) * reach
		end
		-- (half sunk in the skin, like foam sitting on it)
		bubble.welds[index].C0 = offset * CFrame.new(x, y, size * 0.15)
		part.Size = Vector3.new(size, size, size)
		part.Transparency = random:NextNumber(0.35, 0.55)
		bubble.meshes[index].Scale = Vector3.new(0.1, 0.1, 0.1)
		bubble.lags[index] = if index == 1 then 0 else random:NextNumber(0, 0.35)
	end
	bubble.born = now
	bubble.life = random:NextNumber(0.4, 1)
	bubble.popAt = now + bubble.life
	bubble.nextAt = math.huge
end

-- The clusters, planned (their parts are built the first time they show).
local function addBubbles(session: Session, ownHead: boolean)
	local now = os.clock()
	for _, name in BODY do
		local base = session.model:FindFirstChild(name)
		if not (base and base:IsA("BasePart")) or (name == "Head" and ownHead) then
			continue
		end
		for _ = 1, BUBBLES[name] or 0 do
			table.insert(session.bubbles, {
				base = base,
				parts = {},
				meshes = {},
				welds = {},
				lags = {},
				at = CFrame.identity,
				born = now,
				life = 1,
				popAt = math.huge,
				nextAt = now + random:NextNumber(0, 0.7), -- (not all at once)
			})
		end
	end
end

local function buildBubble(session: Session, bubble: Bubble)
	for _ = 1, CLUSTER do
		local part, mesh, weld = blob(
			"RiftBurnBubble",
			bubble.base,
			CFrame.identity,
			Vector3.new(0.2, 0.2, 0.2),
			FROTH,
			Enum.Material.SmoothPlastic,
			1,
			session.folder
		)
		part.Reflectance = 0.5 -- (a wet film catching the light)
		table.insert(bubble.parts, part)
		table.insert(bubble.meshes, mesh)
		table.insert(bubble.welds, weld)
		table.insert(bubble.lags, 0)
	end
end

-- A bubble pops: a little puff of froth and spatter where it was.
local function popAt(session: Session, bubble: Bubble)
	local point = session.popPoint
	local pop = session.pop
	if point == nil or pop == nil or bubble.base.Parent == nil then
		return
	end
	point.WorldPosition = (bubble.base.CFrame * bubble.at * CFrame.new(0, 0, 0.05)).Position
	pop:Emit(random:NextInteger(2, 3))
end

local function stepBubbles(session: Session, now: number)
	for _, bubble in session.bubbles do
		local parts = bubble.parts
		if #parts == 0 then
			if now < bubble.nextAt or budget < CLUSTER or bubble.base.Parent == nil then
				continue
			end
			budget -= CLUSTER
			buildBubble(session, bubble)
		end
		if parts[1].Parent == nil then
			continue -- (its head burst)
		elseif now >= bubble.nextAt then
			placeBubble(bubble, now)
		elseif now < bubble.popAt then
			-- Swelling (fast at first, then slowly, with a slight wobble).
			local t = (now - bubble.born) / bubble.life
			for index, mesh in bubble.meshes do
				local lag = bubble.lags[index]
				local own = math.clamp((t - lag) / (1 - lag), 0, 1)
				local k = 0.1 + 0.9 * math.sqrt(own)
				local wobble = 1 + 0.07 * math.sin(now * 23 + index * 2.1 + bubble.life * 40)
				mesh.Scale = Vector3.new(k * wobble, k / wobble, k)
			end
		elseif bubble.nextAt == math.huge then
			-- Pop: gone in a puff, a moment of bare skin, then a new one.
			for _, part in parts do
				part.Transparency = 1
			end
			popAt(session, bubble)
			bubble.nextAt = now + random:NextNumber(0.05, 0.35)
		end
	end
end

-- A drop of acid running off the body, falling, fizzing on the floor.
local function drip(session: Session)
	local names = { "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg", "Torso" }
	local base = session.model:FindFirstChild(names[random:NextInteger(1, #names)])
	if not (base and base:IsA("BasePart")) then
		return
	end
	local offset = skinSpot(base, 0.05, true)
	local start = (base.CFrame * offset * CFrame.new(0, 0, 0.06)).Position
	local hit = floorUnder(start)
	local floor = if hit then hit.Position else start - Vector3.new(0, 6, 0)
	local height = math.max(start.Y - floor.Y, 0.05)
	local fall = math.sqrt(2 * height / math.max(workspace.Gravity, 1))

	local drop =
		ghost("RiftBurnDrop", Vector3.new(0.08, 0.15, 0.08), ACID, Enum.Material.SmoothPlastic)
	drop.Reflectance = 0.35
	drop.Transparency = 0.1
	drop.Anchored = true
	local shape = Instance.new("SpecialMesh")
	shape.MeshType = Enum.MeshType.Sphere
	shape.Parent = drop
	drop.CFrame = CFrame.new(start)
	drop.Parent = workspace
	-- Free fall: accelerating (Quad In is the shape of a fall).
	TweenService:Create(
		drop,
		TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(floor + Vector3.new(0, 0.05, 0)) }
	):Play()
	Debris:AddItem(drop, fall + 0.02)
	if hit == nil then
		return
	end
	task.delay(fall, function()
		-- The splash: a small spreading stain that fades, a fizz of green
		-- specks and a puff of vapour.
		local stain = P.disc("RiftBurnStain", ACID_DARK, 0.3)
		stain.Material = Enum.Material.SmoothPlastic
		stain.Reflectance = 0.2
		local width = random:NextNumber(0.25, 0.45)
		stain.Size = Vector3.new(width * 0.4, width * 0.4, 0.03)
		stain.CFrame = CFrame.lookAt(hit.Position, hit.Position + hit.Normal)
			* CFrame.new(0, 0, 0.02)
		stain.Parent = workspace
		TweenService:Create(
			stain,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(width, width * random:NextNumber(0.7, 1), 0.03) }
		):Play()
		task.delay(0.6, function()
			if stain.Parent then
				P.fade(stain, 1.2, { Color = Color3.fromRGB(60, 70, 30) })
			end
		end)
		Debris:AddItem(stain, 2.2)
		local point = P.attachmentAt(hit.Position + hit.Normal * 0.05)
		local fizz = emitter(point, {
			Name = "RiftBurnFloorFizz",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(ACID, ACID_DARK),
			LightEmission = 0.4,
			Size = NumberSequence.new(0.07, 0.01),
			Transparency = NumberSequence.new(0.1, 1),
			Lifetime = NumberRange.new(0.15, 0.4),
			Speed = NumberRange.new(1, 2.5),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, -8, 0),
			EmissionDirection = Enum.NormalId.Top,
		})
		fizz:Emit(random:NextInteger(4, 7))
		local puff = emitter(point, {
			Name = "RiftBurnFloorVapour",
			Color = ColorSequence.new(VAPOUR),
			Size = NumberSequence.new(0.2, 0.9),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.7),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(0.4, 1),
			SpreadAngle = Vector2.new(20, 20),
			Acceleration = Vector3.new(0, 1.5, 0),
			EmissionDirection = Enum.NormalId.Top,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-30, 30),
		})
		puff:Emit(1)
		Debris:AddItem(point, 1.3)
	end)
end

------------------------------------------------------------------------------
-- Particles
------------------------------------------------------------------------------

-- What flames come from on the head: the classic head is drawn smaller
-- than its part (2 x 1 x 1), a hidden part its real size instead.
local function headHost(session: Session, head: BasePart): BasePart
	local host = ghost(
		"RiftBurnHeadHost",
		Vector3.new(1.1, 1.05, 1.1),
		FLAME_ORANGE,
		Enum.Material.SmoothPlastic
	)
	host.Transparency = 1
	stick(head, host, CFrame.identity, session.folder)
	return host
end

local function addEmitter(
	session: Session,
	parent: Instance,
	props: { [string]: any },
	flicker: number?,
	isHead: boolean,
	inView: boolean? -- (true: hidden in our own first person, head or not)
)
	local particles = emitter(parent, props)
	table.insert(session.emitters, particles)
	if flicker then
		table.insert(session.flickers, {
			emitter = particles,
			rate = particles.Rate,
			seed = random:NextNumber(0, 100),
			speed = flicker,
		})
	end
	if isHead then
		table.insert(session.headEmitters, particles)
	end
	if inView then
		table.insert(session.viewEmitters, particles)
	end
	return particles
end

local function lightFire(session: Session, ownHead: boolean)
	local model = session.model
	for _, name in BODY do
		local part = model:FindFirstChild(name)
		if not (part and part:IsA("BasePart")) then
			continue
		end
		local share = SHARE[name] or 0.3
		local isHead = name == "Head"
		local host = if isHead then headHost(session, part) else part
		-- Bright core: short tongues close to the skin, white-yellow.
		local core = addEmitter(session, host, {
			Name = "RiftBurnCore",
			Texture = "rbxasset://textures/particles/fire_main.dds",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, FLAME_WHITE),
				ColorSequenceKeypoint.new(0.35, FLAME_YELLOW),
				ColorSequenceKeypoint.new(1, FLAME_ORANGE),
			}),
			LightEmission = 1,
			LightInfluence = 0,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(0.3, 0.55),
				NumberSequenceKeypoint.new(1, 0.1),
			}),
			Squash = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 0.6), -- (stretched up: a tongue)
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(0.15, 0.1),
				NumberSequenceKeypoint.new(0.7, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.22, 0.42),
			Speed = NumberRange.new(0.8, 2),
			SpreadAngle = Vector2.new(15, 15),
			Acceleration = Vector3.new(0, 9, 0),
			Drag = 1.5,
			Rotation = NumberRange.new(-20, 20),
			RotSpeed = NumberRange.new(-60, 60),
			EmissionDirection = Enum.NormalId.Top,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ZOffset = 0.35,
			Rate = 44 * share,
		}, 9, isHead, ownHead and isHead)
		-- Orange outer flames: bigger, longer, licking higher, going dark red.
		local outer = addEmitter(session, host, {
			Name = "RiftBurnFlames",
			Texture = "rbxasset://textures/particles/fire_main.dds",
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, FLAME_YELLOW),
				ColorSequenceKeypoint.new(0.4, FLAME_ORANGE),
				ColorSequenceKeypoint.new(1, FLAME_RED),
			}),
			LightEmission = 0.75,
			LightInfluence = 0,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(0.35, 0.95),
				NumberSequenceKeypoint.new(1, 0.35),
			}),
			Squash = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 0.8),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.7),
				NumberSequenceKeypoint.new(0.2, 0.3),
				NumberSequenceKeypoint.new(0.75, 0.65),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.4, 0.75),
			Speed = NumberRange.new(1, 2.6),
			SpreadAngle = Vector2.new(22, 22),
			Acceleration = Vector3.new(0, 7, 0),
			Drag = 1,
			Rotation = NumberRange.new(-25, 25),
			RotSpeed = NumberRange.new(-45, 45),
			EmissionDirection = Enum.NormalId.Top,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ZOffset = 0.25,
			Rate = 30 * share,
		}, 5, isHead, ownHead and isHead)
		-- (it catches all at once: a first burst)
		core:Emit(math.ceil(10 * share))
		outer:Emit(math.ceil(8 * share))
		-- Embers floating up from the burning clothes.
		if name ~= "Right Leg" and name ~= "Left Leg" then
			addEmitter(session, host, {
				Name = "RiftBurnEmbers",
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(FLAME_YELLOW, EMBER),
				LightEmission = 1,
				LightInfluence = 0,
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.09),
					NumberSequenceKeypoint.new(1, 0.02),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.7, 0.2),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(1, 2),
				Speed = NumberRange.new(1.5, 3.5),
				SpreadAngle = Vector2.new(35, 35),
				Acceleration = Vector3.new(0, 2.5, 0),
				Drag = 1.2,
				EmissionDirection = Enum.NormalId.Top,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				Rate = 9 * share,
			}, 3, isHead, ownHead and isHead)
		end
		-- Thin black smoke rising above the shoulders and the head, and a
		-- faint pale haze through it (the air trembling over the fire).
		-- (our own: both rise through the camera in first person, hidden
		-- then)
		if name == "Torso" or isHead then
			local top = Instance.new("Attachment")
			top.Name = "RiftBurnTop"
			top.Position = Vector3.new(0, if isHead then 0.6 else 0.9, 0)
			top.Parent = host
			table.insert(session.emitters, top) -- (cleaned with them)
			addEmitter(session, top, {
				Name = "RiftBurnSmoke",
				Color = ColorSequence.new(SOOT, SMOKE_GREY),
				LightInfluence = 1,
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.4),
					NumberSequenceKeypoint.new(1, 2.6),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.12, 0.64),
					NumberSequenceKeypoint.new(0.6, 0.82),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(1.4, 2.4),
				Speed = NumberRange.new(2, 3.5),
				SpreadAngle = Vector2.new(12, 12),
				Acceleration = Vector3.new(0.4, 2, 0),
				Drag = 0.6,
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-40, 40),
				EmissionDirection = Enum.NormalId.Top,
				Rate = if isHead then 5 else 8,
			}, nil, isHead, ownHead)
			addEmitter(session, top, {
				Name = "RiftBurnHaze",
				Color = ColorSequence.new(Color3.fromRGB(220, 214, 206)),
				LightInfluence = 1,
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.8),
					NumberSequenceKeypoint.new(1, 2.2),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.3, 0.9),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(0.5, 0.9),
				Speed = NumberRange.new(3, 5),
				SpreadAngle = Vector2.new(18, 18),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-90, 90),
				EmissionDirection = Enum.NormalId.Top,
				Rate = 7,
			}, nil, isHead, ownHead)
		end
	end
	local torso = model:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		local light = Instance.new("PointLight")
		light.Name = "RiftBurnLight"
		light.Color = FIRE_LIGHT
		light.Brightness = 2.4
		light.Range = 11
		light.Shadows = false
		light.Parent = torso
		session.light = light
	end
end

local function pourAcid(session: Session, ownHead: boolean)
	local model = session.model
	for _, name in BODY do
		local part = model:FindFirstChild(name)
		if not (part and part:IsA("BasePart")) then
			continue
		end
		local share = SHARE[name] or 0.3
		local isHead = name == "Head"
		local host = if isHead then headHost(session, part) else part
		-- Froth: pale foam crawling over the skin.
		addEmitter(session, host, {
			Name = "RiftBurnFroth",
			Color = ColorSequence.new(FROTH, FOAM),
			LightInfluence = 1,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.12),
				NumberSequenceKeypoint.new(0.5, 0.3),
				NumberSequenceKeypoint.new(1, 0.22),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(0.3, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.35, 0.7),
			Speed = NumberRange.new(0.05, 0.3),
			Rotation = NumberRange.new(0, 360),
			EmissionDirection = Enum.NormalId.Top,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ZOffset = 0.1,
			Rate = 32 * share,
		}, 6, isHead, ownHead and isHead)
		-- Fizz: tiny green spatters jumping off and falling.
		addEmitter(session, host, {
			Name = "RiftBurnFizz",
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(ACID, ACID_DARK),
			LightEmission = 0.35,
			Size = NumberSequence.new(0.08, 0.015),
			Transparency = NumberSequence.new(0.05, 1),
			Lifetime = NumberRange.new(0.2, 0.45),
			Speed = NumberRange.new(1.2, 3),
			SpreadAngle = Vector2.new(70, 70),
			Acceleration = Vector3.new(0, -10, 0),
			EmissionDirection = Enum.NormalId.Top,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Rate = 24 * share,
		}, 8, isHead, ownHead and isHead)
		-- Caustic vapour: pale yellow-green, rising and spreading.
		addEmitter(session, host, {
			Name = "RiftBurnVapour",
			Color = ColorSequence.new(VAPOUR, Color3.fromRGB(150, 160, 120)),
			LightInfluence = 1,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(1, 2),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0.62),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(0.6, 1.4),
			SpreadAngle = Vector2.new(25, 25),
			Acceleration = Vector3.new(0, 2.2, 0),
			Drag = 0.5,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-30, 30),
			EmissionDirection = Enum.NormalId.Top,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Rate = 10 * share,
		}, 2, isHead, ownHead and isHead)
	end
	-- The fizz of the bubbles popping (one emitter, moved to each pop).
	local point = Instance.new("Attachment")
	point.Name = "RiftBurnPopPoint"
	point.Parent = workspace.Terrain
	table.insert(session.emitters, point)
	session.popPoint = point
	session.pop = addEmitter(session, point, {
		Name = "RiftBurnPop",
		Color = ColorSequence.new(FROTH, FOAM),
		LightInfluence = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.06),
			NumberSequenceKeypoint.new(1, 0.22),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.2, 0.4),
		Speed = NumberRange.new(0.6, 1.6),
		SpreadAngle = Vector2.new(60, 60),
		Acceleration = Vector3.new(0, -3, 0),
		Rotation = NumberRange.new(0, 360),
	}, nil, false)
	addBubbles(session, ownHead)
end

------------------------------------------------------------------------------
-- Start / stop
------------------------------------------------------------------------------

local function stopHeartbeatIfIdle()
	if next(sessions) == nil and next(tints) == nil and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local step: (number) -> ()

local function ensureHeartbeat()
	if heartbeat == nil then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
end

-- Stops what is still moving on a scar (taken back, healed, or wiped).
local function haltScar(scar: Scar)
	scar.token += 1
	for _, tween in scar.tweens do
		tween:Cancel()
	end
	table.clear(scar.tweens)
end

-- Removes the pictures' surfaces (and head plates) of a burn.
local function removeSurfaces(surfaces: { Instance })
	for _, item in surfaces do
		item:Destroy()
	end
	table.clear(surfaces)
end

-- Everything of a model's burn gone now (destroyed, out of the game).
local function wipe(model: Model)
	local session = sessions[model]
	sessions[model] = nil
	if session then
		for _, item in session.emitters do
			item:Destroy()
		end
		if session.light then
			session.light:Destroy()
		end
		removeSurfaces(session.surfaces)
		session.folder:Destroy()
	end
	for folder, scar in scars do
		if scar.model == model then
			scars[folder] = nil
			haltScar(scar)
			removeSurfaces(scar.surfaces)
			folder:Destroy()
		end
	end
	restoreTint(model)
	stopHeartbeatIfIdle()
end

local function play(scar: Scar, instance: Instance, info: TweenInfo, goal: { [string]: any })
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	table.insert(scar.tweens, tween)
end

-- The body is healed (a kill, a new round): its burn marks fade away
-- (still burning: those already there go when it ends).
local function heal(model: Model)
	local burning = sessions[model]
	if burning then
		burning.healedAt = os.clock()
	end
	for folder, scar in scars do
		if scar.model ~= model then
			continue
		end
		scars[folder] = nil
		haltScar(scar)
		local fade = TweenInfo.new(HEAL_FADE, Enum.EasingStyle.Sine)
		for _, mark in scar.marks do
			for _, item in mark.layers do
				if item.part.Parent then
					play(scar, item.part, fade, { Transparency = 1 })
				end
			end
		end
		for _, picture in scar.pictures do
			local label = picture.label
			if label and label.Parent then
				play(scar, label, fade, { ImageTransparency = 1 })
			end
		end
		local surfaces = scar.surfaces
		for _, item in surfaces do
			item.Name = "RiftBurnHealed" -- (a new burn meanwhile makes its own)
		end
		task.delay(HEAL_FADE, function()
			removeSurfaces(surfaces)
			folder:Destroy()
		end)
	end
end

-- The burn ends: the effects die out, the skin goes back (slowly, in the
-- Heartbeat); the marks stay (a scar).
local function stopBurning(model: Model)
	local session = sessions[model]
	sessions[model] = nil
	local tint = tints[model]
	if tint then
		tint.charGoal = 0
		tint.rawGoal = 0
	end
	if session == nil then
		return
	end
	local isFire = session.kind == "Fire"
	-- The flames die down (their rate falls), they don't just stop.
	local dieDown = TweenInfo.new(if isFire then 0.6 else 0.35, Enum.EasingStyle.Quad)
	for _, item in session.emitters do
		if item:IsA("ParticleEmitter") and item.Enabled and item.Rate > 0 then
			TweenService:Create(item, dieDown, { Rate = 0 }):Play()
		end
		Debris:AddItem(item, 2.6)
	end
	local light = session.light
	if light then
		TweenService
			:Create(light, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Brightness = 0, Range = 4 })
			:Play()
		Debris:AddItem(light, 1)
	end
	-- Bubbles pop at once.
	for _, bubble in session.bubbles do
		for _, part in bubble.parts do
			part:Destroy()
		end
	end
	-- Smouldering: grey smoke off the body for a while, thinning out.
	if isFire then
		for _, name in { "Torso", "Head", "Right Arm", "Left Arm" } do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				local smoke = emitter(part, {
					Name = "RiftBurnSmoulder",
					Color = ColorSequence.new(SMOKE_GREY, Color3.fromRGB(120, 116, 110)),
					LightInfluence = 1,
					Size = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.3),
						NumberSequenceKeypoint.new(1, 1.8),
					}),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.2, 0.6),
						NumberSequenceKeypoint.new(1, 1),
					}),
					Lifetime = NumberRange.new(1.2, 2),
					Speed = NumberRange.new(0.5, 1.2),
					SpreadAngle = Vector2.new(15, 15),
					Acceleration = Vector3.new(0, 1.8, 0),
					Rotation = NumberRange.new(0, 360),
					RotSpeed = NumberRange.new(-25, 25),
					EmissionDirection = Enum.NormalId.Top,
					ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
					Rate = (SHARE[name] or 0.5) * 12,
				})
				TweenService
					:Create(smoke, TweenInfo.new(SMOULDER, Enum.EasingStyle.Linear), { Rate = 0 })
					:Play()
				Debris:AddItem(smoke, SMOULDER + 2.1)
			end
		end
	end
	-- The marks stay. Those not shown yet never will (the burn didn't get
	-- there); those still growing end their growth (not frozen half-grown).
	local folder = session.folder
	local scar: Scar = {
		model = model,
		kind = session.kind,
		folder = folder,
		marks = {},
		glows = session.glows,
		pictures = {},
		surfaces = session.surfaces,
		tweens = {},
		token = 0,
	}
	local now = os.clock()
	local finish = TweenInfo.new(0.6, Enum.EasingStyle.Quad)
	-- Healed while it burnt: what was there then fades away now.
	local healedAt = session.healedAt or -math.huge
	local fade = TweenInfo.new(HEAL_FADE, Enum.EasingStyle.Sine)
	for _, mark in session.marks do
		if not mark.shown then
			continue
		end
		if mark.startedAt <= healedAt then
			for _, item in mark.layers do
				TweenService:Create(item.part, fade, { Transparency = 1 }):Play()
				Debris:AddItem(item.part, HEAL_FADE)
			end
			continue
		end
		if not mark.done then
			local left = (1 - math.min((now - mark.startedAt) / mark.grow, 1)) * mark.grow
			for _, item in mark.layers do
				play(
					scar,
					item.mesh,
					TweenInfo.new(math.max(left, 0.05), Enum.EasingStyle.Quad),
					{ Scale = Vector3.one }
				)
			end
			mark.done = true
		end
		table.insert(scar.marks, mark)
	end
	for _, picture in session.pictures do
		local label = picture.label
		if not picture.shown or label == nil then
			continue
		end
		if picture.startedAt <= healedAt then
			TweenService:Create(label, fade, { ImageTransparency = 1 }):Play()
			Debris:AddItem(grower(picture) or label, HEAL_FADE)
			continue
		end
		if not picture.done then
			play(scar, label, finish, { ImageTransparency = picture.alpha })
			local growing = grower(picture)
			if growing then
				play(scar, growing, finish, { Size = pictureSize(picture, 1) })
			end
			picture.done = true
		end
		table.insert(scar.pictures, picture)
	end
	-- The glowing specks cool down to black char.
	local token = scar.token
	for _, speck in session.glows do
		local cool = random:NextNumber(0.8, 2)
		play(scar, speck, TweenInfo.new(cool, Enum.EasingStyle.Quad), { Color = CHAR })
		task.delay(cool, function()
			if scar.token == token and speck.Parent then
				speck.Material = Enum.Material.Slate
			end
		end)
	end
	folder.Name = "RiftBurnScar"
	scars[folder] = scar
	stopHeartbeatIfIdle()
end

-- The same burn again: take its marks back (they are where the body
-- burnt; a whole new set somewhere else would pile up).
local function takeBack(model: Model, kind: string): Scar?
	for folder, scar in scars do
		if scar.model == model and scar.kind == kind then
			scars[folder] = nil
			haltScar(scar)
			if folder.Parent ~= model then
				removeSurfaces(scar.surfaces)
				folder:Destroy()
				return nil
			end
			return scar
		end
	end
	return nil
end

local function startBurning(model: Model, kind: string)
	local current = sessions[model]
	if current and current.kind == kind then
		return
	end
	stopBurning(model)
	if kind ~= "Fire" and kind ~= "Acid" then
		return
	end
	local back = takeBack(model, kind)
	local folder: Folder
	if back then
		folder = back.folder
	else
		folder = Instance.new("Folder")
		folder.Parent = model
	end
	folder.Name = "RiftBurn"
	local session: Session = {
		model = model,
		kind = kind,
		folder = folder,
		emitters = {},
		flickers = {},
		headEmitters = {},
		viewEmitters = {},
		light = nil,
		marks = {},
		glows = {},
		pictures = {},
		surfaces = if back then back.surfaces else {},
		bubbles = {},
		pop = nil,
		popPoint = nil,
		nextDrip = os.clock() + 0.2,
		seed = random:NextNumber(0, 1000),
		headGone = false,
		healedAt = nil,
	}
	-- Our own head: no patches or bubbles on it (they'd block the camera in
	-- first person); its flames hide in first person (Heartbeat).
	local ownHead = model == Players.LocalPlayer.Character
	sessions[model] = session
	local share = 1
	if back then
		-- The old marks are back as they were (finished growing), the
		-- specks glow again; a few new ones join them.
		share = 0.35
		for _, mark in back.marks do
			local gone = #mark.layers == 0 or mark.layers[1].part.Parent == nil
			if mark.base.Parent == nil or gone then
				continue -- (its head burst)
			end
			for _, item in mark.layers do
				item.part.Transparency = item.alpha
				item.mesh.Scale = Vector3.one
			end
			table.insert(session.marks, mark)
		end
		for _, picture in back.pictures do
			local label = picture.label
			local growing = grower(picture)
			if label and growing and label.Parent and picture.base.Parent then
				growing.Size = pictureSize(picture, 1)
				label.ImageTransparency = picture.alpha
				table.insert(session.pictures, picture)
			end
		end
		for _, speck in back.glows do
			if speck.Parent then
				speck.Color = GLOW
				speck.Material = Enum.Material.Neon
				table.insert(session.glows, speck)
			end
		end
	end
	if hasPictures(kind) then
		addPictures(session, ownHead, share)
	else
		addMarks(session, ownHead, share)
	end
	if kind == "Fire" then
		lightFire(session, ownHead)
	else
		pourAcid(session, ownHead)
	end
	local tint = tintOf(model)
	if kind == "Fire" then
		tint.charGoal = 1
		tint.rawGoal = 0
	else
		tint.rawGoal = 1
		tint.charGoal = 0
	end
	ensureHeartbeat()
	SoundController.play(if kind == "Fire" then "Burn" else "AcidSizzle", model)
	-- The one burning reacts (a cry of pain), not more than every few seconds.
	local now = os.clock()
	if now >= (nextCry[model] or 0) then
		nextCry[model] = now + CRY_INTERVAL
		SoundController.play("BurnCry", model)
	end
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

local function approach(value: number, goal: number, up: number, down: number, dt: number): number
	if value < goal then
		return math.min(value + up * dt, goal)
	end
	return math.max(value - down * dt, goal)
end

-- The head burst while it burns: its patches, bubbles and flames go.
local function dropHead(session: Session)
	session.headGone = true
	local onHead: { [ParticleEmitter]: boolean } = {}
	for _, item in session.headEmitters do
		item.Enabled = false
		onHead[item] = true
	end
	table.clear(session.headEmitters)
	for index = #session.viewEmitters, 1, -1 do
		if onHead[session.viewEmitters[index]] then
			table.remove(session.viewEmitters, index)
		end
	end
	for _, mark in session.marks do
		if mark.base.Name == "Head" then
			mark.done = true
			for _, item in mark.layers do
				item.part:Destroy()
			end
		end
	end
	for _, picture in session.pictures do
		if picture.base.Name == "Head" then
			picture.done = true -- (never built if it wasn't yet)
			picture.shown = true
			local label = picture.label
			local plate = if label then label:FindFirstAncestorWhichIsA("BasePart") else nil
			if plate and plate ~= picture.base then
				plate:Destroy()
			end
		end
	end
	for _, bubble in session.bubbles do
		if bubble.base.Name == "Head" then
			bubble.nextAt = math.huge -- (never built if it wasn't yet)
			bubble.popAt = 0
			for _, part in bubble.parts do
				part:Destroy()
			end
		end
	end
end

step = function(_dt: number)
	local now = os.clock()
	budget = BUILD_PER_FRAME
	for model, session in sessions do
		if not session.headGone and HeadBlast.isBlown(model) then
			dropHead(session)
		end
		if session.kind == "Fire" then
			-- Flicker: each layer's rate wanders (smooth noise), the light
			-- throbs and jumps with it.
			for _, flicker in session.flickers do
				local n = math.noise(now * flicker.speed, flicker.seed)
				flicker.emitter.Rate = flicker.rate * math.max(0.75 + n * 1.4, 0.15)
			end
			local light = session.light
			if light then
				local slow = math.noise(now * 3, session.seed)
				local fast = math.noise(now * 13, session.seed + 7.7)
				light.Brightness = math.max(2.4 + slow * 2.2 + fast * 1.2, 0.6)
				light.Range = 10.5 + slow * 2.5
			end
		else
			stepBubbles(session, now)
			if now >= session.nextDrip then
				session.nextDrip = now + random:NextNumber(0.12, 0.32)
				drip(session)
			end
		end
		stepMarks(session, now)
		stepPictures(session, now)
		-- Our own first person: the flames / fumes around the head would
		-- fill the view.
		if #session.viewEmitters > 0 and model == Players.LocalPlayer.Character then
			local head = model:FindFirstChild("Head")
			local hidden = head ~= nil
				and head:IsA("BasePart")
				and head.LocalTransparencyModifier > 0.5
			for _, item in session.viewEmitters do
				item.Enabled = not hidden
			end
		end
	end
	-- The skin tints, ten times a second (slow changes: no visible steps).
	for model, tint in tints do
		local elapsed = now - tint.applied
		if elapsed < 0.1 then
			continue
		end
		tint.applied = now
		elapsed = math.min(elapsed, 0.5)
		tint.char = approach(tint.char, tint.charGoal, CHAR_ON, CHAR_OFF, elapsed)
		tint.raw = approach(tint.raw, tint.rawGoal, RAW_ON, RAW_OFF, elapsed)
		-- (new skin pieces: a cut, gore; looked for once a second)
		if now - tint.scanned >= 1 then
			tint.scanned = now
			rescan(tint)
		end
		local faded = tint.char <= 0 and tint.raw <= 0 and tint.charGoal <= 0 and tint.rawGoal <= 0
		if faded and not headIsBusy(model, tint, now) then
			restoreTint(model)
		elseif not faded then
			applyTint(model, tint, now)
		end
	end
	stopHeartbeatIfIdle()
end

------------------------------------------------------------------------------
-- Watching a model
------------------------------------------------------------------------------

local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- A copy of a burning body (a clone): its effects and its tint were copied
-- too; take them off (it burns again only if its own attribute says so).
local function scrubCopy(model: Model)
	for _, item in model:GetDescendants() do
		if string.sub(item.Name, 1, 8) == "RiftBurn" and item ~= model then
			if item:IsA("BasePart") and item:GetAttribute(ORIGINAL_ATTRIBUTE) ~= nil then
				continue -- (a body part: only its colour)
			end
			item:Destroy()
		end
	end
	for _, name in BODY do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local saved = part:GetAttribute(ORIGINAL_ATTRIBUTE)
			if typeof(saved) == "Color3" then
				-- (its skin pieces wear the tinted colour it had)
				for _, piece in findCopies(part, saved, part.Color) do
					piece.Color = saved
				end
				part.Color = saved
				part:SetAttribute(ORIGINAL_ATTRIBUTE, nil)
			end
		end
	end
end

function RiftBurn.watch(model: Model)
	if watched[model] then
		return
	end
	watched[model] = true
	scrubCopy(model)
	local function refresh()
		if not model:IsDescendantOf(game) then
			return
		end
		local kind = model:GetAttribute("Burning")
		local body = model:FindFirstChildOfClass("Humanoid")
		local alive = body == nil or body.Health > 0
		if typeof(kind) == "string" and alive then
			startBurning(model, kind)
		else
			stopBurning(model)
		end
	end
	local changed = model:GetAttributeChangedSignal("Burning"):Connect(refresh)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local died: RBXScriptConnection? = if humanoid
		then humanoid.Died:Connect(function()
			stopBurning(model)
		end)
		else nil
	-- Healed (a kill, a new round): the server gives health back at once
	-- (the slow regeneration never does that). The burn marks go, like
	-- the bruises and cuts. (Checked again a moment later: a new round
	-- also puts the fire out, maybe just after.)
	local healed: RBXScriptConnection? = nil
	if humanoid then
		local last = humanoid.Health
		healed = humanoid.HealthChanged:Connect(function(health: number)
			local gained = health - last
			last = health
			local full = health >= humanoid.MaxHealth - 0.01
			if health > 0 and gained > 0 and (gained >= HEAL_JUMP or full) then
				heal(model)
				task.delay(0.5, heal, model)
			end
		end)
	end
	local moved: RBXScriptConnection
	moved = model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(game) then
			wipe(model)
		else
			refresh() -- (back in the game: streaming)
		end
	end)
	model.Destroying:Once(function()
		changed:Disconnect()
		moved:Disconnect()
		if died then
			died:Disconnect()
		end
		if healed then
			healed:Disconnect()
		end
		watched[model] = nil
		wipe(model)
	end)
	refresh()
end

return RiftBurn
