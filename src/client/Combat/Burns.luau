--!strict
-- Burns (client): draws a body's burns and its fire, from the attributes
-- the server writes (Shared/Util/BurnCode, Server/Systems/Combat/Burns).
-- Every burn source looks the same way: Dr. Rift's ray, acid and flasks,
-- the Pyromaniac's fire, anything that calls the server's startBurning.
--
--   Burns.watch(model)   a fighter, a clone or a corpse copy
--
-- THE SKIN: each burnt face of a body part gets tiled textures, one per
-- stage reached (Config.Injuries.BURNS: 1 redness, 2 blisters and peeling
-- skin, 3 leathery eschar, 4 charred and cracked), each fading in over its
-- first 0.4 degree as the burn deepens. The four stages come from one depth
-- map, so the char sits inside the eschar, inside the blisters, inside the
-- redness. Over a shirt / pants the "cloth" set: singed, charred cloth with
-- burnt-through holes (the burnt skin in them), then burnt into the skin.
-- Acid: its own set (yellow-brown stain, eroded slough, brown-black
-- eschar). A laser / ray leaves a spot where it went in (a charred crater,
-- a white cooked ring, peeled red skin round it).
-- THE FIRE ("BurnLit"): on each part in flames, flames (a flipbook, licking
-- up from the part's surface), thick dark smoke rising, embers; one
-- flickering light on the body (shadows on). Acid instead: fizz, pale
-- vapour, drops falling. Out ("BurnSmoke"): the charred parts smoulder, thin
-- grey smoke and a few embers, then nothing.
--
-- Budget: the textures are built once per face and stage (at most 4 + 2
-- spots on a face) and only reused after; the emitters once per part; no
-- instance is made or dropped while it burns (only when a new face gets a
-- stage). One Heartbeat for every burning body; the textures update 15
-- times a second, the light every frame.
--
-- Everything is named "BurnFx..." (RiftPortal's clone copies skip it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BurnCode = require(ReplicatedStorage.Shared.Util.BurnCode)
local Config = require(ReplicatedStorage.Shared.Config)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Burns = {}

local NAME = "BurnFx"
local TILE = 2 -- studs per texture tile (512 px)
local SPOT_TILE = 2.6 -- a spot's tile: bigger than a face, one spot shows
local FADE_BAND = 0.4 -- a stage fades in over its first 0.4 degree
local SHOW_UP = 1.4 -- degrees / s the drawn burn catches up
local SHOW_DOWN = 2.5 -- and goes (healed)
local TEXTURE_STEP = 1 / 15
local CRY_INTERVAL = 2.5

local FIRE_LIGHT = Color3.fromRGB(255, 136, 56)

-- Fallback particle pictures (Roblox's own) while BURNS.flame/... are 0.
local BUILTIN_FLAME = "rbxasset://textures/particles/fire_main.dds"
local BUILTIN_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local BUILTIN_EMBER = "rbxasset://textures/particles/sparkles_main.dds"

local IMAGES = Config.Injuries.BURNS
local LEGACY = Config.Injuries.BURN_IMAGES

type Set = "skin" | "cloth" | "acid"

type Look = {
	image: string,
	opacity: number, -- the most it shows
	tile: number,
	tint: Color3?,
}

local function asset(id: number): string
	return `rbxassetid://{id}`
end

-- The picture for a stage of a set (the new one, else the old one).
local function lookFor(set: Set, stage: number): Look?
	local ids: { number } = if set == "acid"
		then IMAGES.acid
		elseif set == "cloth" then IMAGES.cloth
		else IMAGES.skin
	local id = ids[stage]
	if id and id ~= 0 then
		return { image = asset(id), opacity = 1, tile = TILE, tint = nil }
	end
	if set == "acid" then
		local old = LEGACY.acid[stage]
		return if old and old ~= 0
			then { image = asset(old), opacity = 0.9, tile = 2.4, tint = nil }
			else nil
	end
	if stage == 1 then
		-- (a soft red blush from the old halo)
		return if LEGACY.halo ~= 0
			then {
				image = asset(LEGACY.halo),
				opacity = 0.45,
				tile = 1.4,
				tint = Color3.fromRGB(196, 72, 60),
			}
			else nil
	end
	local old = LEGACY.fire[stage - 1]
	return if old and old ~= 0
		then { image = asset(old), opacity = 0.95, tile = 2.4, tint = nil }
		else nil
end

-- The spot's picture and tile size (its burn fills the middle 40 % of a
-- tile bigger than the face: one spot shows). Not uploaded: no spot, the
-- face's own burn shows where it went in (the old pictures are tiles).
local function spotImage(): (string?, number)
	if IMAGES.spot ~= 0 then
		return asset(IMAGES.spot), SPOT_TILE
	end
	return nil, SPOT_TILE
end

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

type FaceLook = {
	layers: { [number]: Texture }, -- by stage
	spots: { [number]: Texture }, -- by spot index
	set: Set?,
	offsetU: number,
	offsetV: number,
}

type Fx = {
	flame: ParticleEmitter?,
	smoke: ParticleEmitter?,
	embers: ParticleEmitter?,
	fizz: ParticleEmitter?,
	vapour: ParticleEmitter?,
	drips: ParticleEmitter?,
}

type PartLook = {
	name: string,
	part: BasePart,
	burn: BurnCode.PartBurn?, -- what the server says
	shown: { number }, -- 6 degrees drawn now
	spotShown: { number },
	faces: { [number]: FaceLook },
	fx: Fx,
	level: number, -- flames: 0 (out) .. 3
	acid: boolean,
	hidden: boolean, -- (the part is invisible: no burn textures on it)
	gone: boolean, -- (a burst head: no flames either)
}

type Session = {
	model: Model,
	parts: { [string]: PartLook },
	lit: { [string]: number },
	smokeUntil: number,
	smoking: boolean, -- (its smoke still on: one more pass turns it off)
	light: PointLight?,
	seed: number,
	animating: boolean,
	burning: boolean,
	own: boolean,
	connections: { RBXScriptConnection },
}

local sessions: { [Model]: Session } = {}
local nextCry: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local heartbeat: RBXScriptConnection? = nil
local textureClock = 0

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function fade(stage: number, degree: number): number
	return smoothstep((degree - (stage - 1)) / FADE_BAND)
end

-- Same small numbers on every client (a texture's offset on a face).
local function hash(text: string): number
	local h = 2166136261
	for index = 1, #text do
		h = bit32.bxor(h, string.byte(text, index))
		h = (h * 16777619) % 4294967296
	end
	return h
end

local function isClothed(model: Model, partName: string): boolean
	if partName == "Head" then
		return false
	end
	local shirt = model:FindFirstChildOfClass("Shirt")
	local pants = model:FindFirstChildOfClass("Pants")
	local hasShirt = shirt ~= nil and shirt.ShirtTemplate ~= ""
	local hasPants = pants ~= nil and pants.PantsTemplate ~= ""
	if partName == "Torso" then
		return hasShirt or hasPants
	elseif partName == "Right Arm" or partName == "Left Arm" then
		return hasShirt
	end
	return hasPants
end

-- Bare skin: redness and blisters read darker on darker skin.
local function skinTint(part: BasePart): Color3
	local c = part.Color
	local luminance = 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
	local k = math.clamp(luminance * 1.5, 0.45, 1)
	return Color3.new(k, k, k)
end

------------------------------------------------------------------------------
-- Textures
------------------------------------------------------------------------------

-- The width (along u) of a face, in studs.
local function faceWidth(part: BasePart, face: number): number
	return math.abs(BurnCode.RIGHT[face]:Dot(part.Size))
end

local function faceHeight(part: BasePart, face: number): number
	return math.abs(BurnCode.DOWN[face]:Dot(part.Size))
end

local function faceOf(look: PartLook, face: number, seed: number): FaceLook
	local current = look.faces[face]
	if current then
		return current
	end
	local h = hash(`{look.name}{face}{seed}`)
	local created: FaceLook = {
		layers = {},
		spots = {},
		set = nil,
		offsetU = (h % 1000) / 1000 * TILE,
		offsetV = (math.floor(h / 1000) % 1000) / 1000 * TILE,
	}
	look.faces[face] = created
	return created
end

local function newTexture(part: BasePart, face: number, zIndex: number): Texture
	local texture = Instance.new("Texture")
	texture.Name = NAME
	texture.Face = BurnCode.FACES[face]
	texture.ZIndex = zIndex
	texture.Transparency = 1
	texture.Parent = part
	return texture
end

-- One stage on one face: built the first time it shows, then only its
-- transparency changes.
local function setLayer(
	look: PartLook,
	faceLook: FaceLook,
	face: number,
	set: Set,
	stage: number,
	amount: number,
	tint: Color3
)
	local texture = faceLook.layers[stage]
	if amount <= 0.001 then
		if texture then
			texture.Transparency = 1
		end
		return
	end
	local info = lookFor(set, stage)
	if info == nil then
		if texture then
			texture.Transparency = 1
		end
		return
	end
	if not texture then
		texture = newTexture(look.part, face, stage)
		faceLook.layers[stage] = texture
	end
	if not texture then
		return
	end
	if texture.Texture ~= info.image then
		texture.Texture = info.image
		texture.StudsPerTileU = info.tile
		texture.StudsPerTileV = info.tile
		texture.OffsetStudsU = faceLook.offsetU
		texture.OffsetStudsV = faceLook.offsetV
	end
	local color = info.tint or (if set == "skin" and stage <= 2 then tint else Color3.new(1, 1, 1))
	if texture.Color3 ~= color then
		texture.Color3 = color
	end
	texture.Transparency = 1 - amount * info.opacity
end

local function setSpot(
	look: PartLook,
	faceLook: FaceLook,
	face: number,
	index: number,
	spot: BurnCode.Spot?,
	amount: number
)
	local texture = faceLook.spots[index]
	local image, tile = spotImage()
	if spot == nil or image == nil or amount <= 0.001 then
		if texture then
			texture.Transparency = 1
		end
		return
	end
	if not texture then
		texture = newTexture(look.part, face, 8 + index)
		faceLook.spots[index] = texture
	end
	if not texture then
		return
	end
	texture.Texture = image
	texture.StudsPerTileU = tile
	texture.StudsPerTileV = tile
	-- (the tile's middle on the spot)
	texture.OffsetStudsU = spot.u * faceWidth(look.part, face) - tile / 2
	texture.OffsetStudsV = spot.v * faceHeight(look.part, face) - tile / 2
	texture.Transparency = 1 - amount
end

-- Invisible (a burst head, a part replaced by its cut copy): no burn
-- textures (a Texture still draws on an invisible part, over the cut copy
-- and its hole). Gone (invisible with no "Gashes" folder: a burst head):
-- no flames either; a cut part's flames go on (its copy still burns).
local function isHidden(part: BasePart): boolean
	return part.Transparency > 0.9
end

local function isGone(part: BasePart): boolean
	return isHidden(part) and part:FindFirstChild("Gashes") == nil
end

local function drawPart(session: Session, look: PartLook)
	local burn = look.burn
	local hidden = isHidden(look.part)
	look.hidden = hidden
	look.gone = isGone(look.part)
	local set: Set = if burn and burn.kind == "Acid"
		then "acid"
		elseif isClothed(session.model, look.name) then "cloth"
		else "skin"
	local stages = if set == "acid" then 3 else 4
	local tint = skinTint(look.part)
	for face = 1, 6 do
		local degree = if hidden then 0 else look.shown[face]
		local existing = look.faces[face]
		if degree <= 0.001 and existing == nil then
			continue
		end
		local faceLook = faceOf(look, face, session.seed)
		if faceLook.set ~= set then
			-- (the set changed: acid then fire on it; the old stages go)
			for _, texture in faceLook.layers do
				texture.Transparency = 1
				texture.Texture = ""
			end
			faceLook.set = set
		end
		for stage = 1, 4 do
			local amount = if stage <= stages then fade(stage, degree) else 0
			setLayer(look, faceLook, face, set, stage, amount, tint)
		end
	end
	-- Spots (a laser / ray).
	local spots = if burn then burn.spots else {}
	for index = 1, BurnCode.MAX_SPOTS do
		local spot = spots[index]
		local shown = if hidden then 0 else (look.spotShown[index] or 0)
		if spot then
			local faceLook = faceOf(look, spot.face, session.seed)
			-- (a spot that moved to another face: the old one hides)
			for face, other in look.faces do
				if face ~= spot.face and other.spots[index] then
					other.spots[index].Transparency = 1
				end
			end
			setSpot(look, faceLook, spot.face, index, spot, smoothstep(shown / 2.2))
		else
			for _, other in look.faces do
				if other.spots[index] then
					other.spots[index].Transparency = 1
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- Fire, smoke, acid
------------------------------------------------------------------------------

local function image(id: number, fallback: string): string
	return if id ~= 0 then asset(id) else fallback
end

local FLAME_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 232, 178)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 168, 64)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(226, 92, 26)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 34, 16)),
})
local FLAME_ALPHA = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.08, 0.2),
	NumberSequenceKeypoint.new(0.65, 0.45),
	NumberSequenceKeypoint.new(1, 1),
})
-- Thick soot over a fire; thin grey over a smouldering body.
local SMOKE_FIRE = ColorSequence.new(Color3.fromRGB(26, 23, 21), Color3.fromRGB(74, 70, 66))
local SMOKE_SMOULDER = ColorSequence.new(Color3.fromRGB(96, 92, 88), Color3.fromRGB(140, 136, 132))
local SMOKE_ALPHA_FIRE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.12, 0.35),
	NumberSequenceKeypoint.new(1, 1),
})
local SMOKE_ALPHA_SMOULDER = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0.72),
	NumberSequenceKeypoint.new(1, 1),
})

local function newEmitter(part: BasePart, props: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = NAME
	emitter.Enabled = false
	emitter.Rate = 0
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = part
	return emitter
end

local function scaleOf(part: BasePart): number
	return math.clamp((part.Size.X + part.Size.Z) / 3, 0.6, 1.3)
end

local function flameOf(look: PartLook): ParticleEmitter
	local current = look.fx.flame
	if current then
		return current
	end
	local s = scaleOf(look.part)
	local flipbook = IMAGES.flame ~= 0
	local emitter = newEmitter(look.part, {
		Texture = image(IMAGES.flame, BUILTIN_FLAME),
		Color = FLAME_COLOR,
		Transparency = FLAME_ALPHA,
		LightEmission = 0.85,
		LightInfluence = 0,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55 * s),
			NumberSequenceKeypoint.new(0.35, 1.0 * s),
			NumberSequenceKeypoint.new(1, 0.35 * s),
		}),
		Lifetime = NumberRange.new(0.45, 0.85),
		Speed = NumberRange.new(1.2, 2.6),
		Acceleration = Vector3.new(0, 6, 0),
		SpreadAngle = Vector2.new(12, 12),
		Rotation = NumberRange.new(-15, 15),
		RotSpeed = NumberRange.new(-35, 35),
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ZOffset = 0.25,
		LockedToPart = false,
	})
	if flipbook then
		emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		emitter.Squash = NumberSequence.new(-0.3) -- (taller tongues)
	end
	look.fx.flame = emitter
	return emitter
end

local function smokeOf(look: PartLook): ParticleEmitter
	local current = look.fx.smoke
	if current then
		return current
	end
	local s = scaleOf(look.part)
	local emitter = newEmitter(look.part, {
		Texture = image(IMAGES.smoke, BUILTIN_SMOKE),
		Color = SMOKE_FIRE,
		Transparency = SMOKE_ALPHA_FIRE,
		LightEmission = 0,
		LightInfluence = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7 * s),
			NumberSequenceKeypoint.new(1, 4.2 * s),
		}),
		Lifetime = NumberRange.new(2.2, 3.6),
		Speed = NumberRange.new(2, 3.4),
		Acceleration = Vector3.new(0, 2.2, 0),
		Drag = 0.7,
		SpreadAngle = Vector2.new(14, 14),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-25, 25),
		EmissionDirection = Enum.NormalId.Top,
		ZOffset = -0.4,
	})
	look.fx.smoke = emitter
	return emitter
end

local function embersOf(look: PartLook): ParticleEmitter
	local current = look.fx.embers
	if current then
		return current
	end
	local emitter = newEmitter(look.part, {
		Texture = image(IMAGES.ember, BUILTIN_EMBER),
		Color = ColorSequence.new(Color3.fromRGB(255, 196, 96), Color3.fromRGB(255, 86, 20)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(1, 0.02),
		}),
		Lifetime = NumberRange.new(1.2, 2.4),
		Speed = NumberRange.new(2, 5),
		Acceleration = Vector3.new(0, 3, 0),
		Drag = 0.8,
		SpreadAngle = Vector2.new(35, 35),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ZOffset = 0.4,
	})
	look.fx.embers = emitter
	return emitter
end

local function acidOf(look: PartLook): (ParticleEmitter, ParticleEmitter, ParticleEmitter)
	local fx = look.fx
	local fizz = fx.fizz
	local vapour = fx.vapour
	local drips = fx.drips
	if fizz and vapour and drips then
		return fizz, vapour, drips
	end
	local s = scaleOf(look.part)
	local newFizz = newEmitter(look.part, {
		Texture = BUILTIN_EMBER,
		Color = ColorSequence.new(Color3.fromRGB(226, 232, 168), Color3.fromRGB(200, 190, 120)),
		Transparency = NumberSequence.new(0.35, 1),
		LightEmission = 0.1,
		LightInfluence = 1,
		Size = NumberSequence.new(0.05, 0.12),
		Lifetime = NumberRange.new(0.3, 0.7),
		Speed = NumberRange.new(0.3, 0.9),
		SpreadAngle = Vector2.new(60, 60),
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ZOffset = 0.2,
	})
	local newVapour = newEmitter(look.part, {
		Texture = image(IMAGES.smoke, BUILTIN_SMOKE),
		Color = ColorSequence.new(Color3.fromRGB(206, 204, 170), Color3.fromRGB(180, 182, 160)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		}),
		LightEmission = 0,
		LightInfluence = 1,
		Size = NumberSequence.new(0.5 * s, 2.2 * s),
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(0.8, 1.6),
		Acceleration = Vector3.new(0, 1.5, 0),
		Drag = 1,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		EmissionDirection = Enum.NormalId.Top,
	})
	local newDrips = newEmitter(look.part, {
		Texture = BUILTIN_EMBER,
		Color = ColorSequence.new(Color3.fromRGB(176, 150, 70)),
		Transparency = NumberSequence.new(0.1, 0.4),
		LightEmission = 0,
		LightInfluence = 1,
		Size = NumberSequence.new(0.07),
		Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(0, 0.5),
		Acceleration = Vector3.new(0, -40, 0),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Bottom,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	fx.fizz, fx.vapour, fx.drips = newFizz, newVapour, newDrips
	return newFizz, newVapour, newDrips
end

local function setRate(emitter: ParticleEmitter?, rate: number)
	if emitter == nil then
		return
	end
	if rate <= 0 then
		if emitter.Enabled then
			emitter.Enabled = false
		end
		return
	end
	emitter.Rate = rate
	if not emitter.Enabled then
		emitter.Enabled = true
	end
end

local function maxDegree(look: PartLook): number
	local top = 0
	for face = 1, 6 do
		top = math.max(top, look.shown[face])
	end
	return top
end

-- The emitters of one part from what burns there now.
local function driveFx(look: PartLook, smouldering: boolean, firstPerson: boolean)
	local level = if look.gone then 0 else look.level
	local quality = 1
	local fire = level > 0 and not look.acid
	local acid = level > 0 and look.acid
	local head = look.name == "Head"
	local hideFlames = head and firstPerson
	if fire then
		local s = scaleOf(look.part)
		setRate(flameOf(look), if hideFlames then 0 else (8 + 9 * level) * s * quality)
		local smoke = smokeOf(look)
		smoke.Color = SMOKE_FIRE
		smoke.Transparency = SMOKE_ALPHA_FIRE
		setRate(smoke, if hideFlames then 0 else (1.5 + 1.5 * level) * quality)
		setRate(embersOf(look), (1 + 1.5 * level) * quality)
	else
		setRate(look.fx.flame, 0)
		local charred = not look.gone and maxDegree(look) >= 2
		if smouldering and charred and not hideFlames then
			local smoke = smokeOf(look)
			smoke.Color = SMOKE_SMOULDER
			smoke.Transparency = SMOKE_ALPHA_SMOULDER
			setRate(smoke, 1.2 * quality)
			setRate(embersOf(look), if maxDegree(look) >= 3.5 then 0.6 else 0)
		else
			setRate(look.fx.smoke, 0)
			setRate(look.fx.embers, 0)
		end
	end
	if acid then
		local fizz, vapour, drips = acidOf(look)
		setRate(fizz, 10 + 8 * level)
		setRate(vapour, 1.5 + level)
		setRate(drips, 1 + level)
	else
		setRate(look.fx.fizz, 0)
		setRate(look.fx.vapour, 0)
		setRate(look.fx.drips, 0)
	end
end

------------------------------------------------------------------------------
-- Reading the attributes
------------------------------------------------------------------------------

local function bodyPart(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

local function ensureHeartbeat()
	if heartbeat == nil then
		heartbeat = RunService.Heartbeat:Connect(function(dt: number)
			Burns._step(dt)
		end)
	end
end

local function lookOf(session: Session, partName: string): PartLook?
	local look = session.parts[partName]
	local part = bodyPart(session.model, partName)
	if part == nil then
		return nil
	end
	if look and look.part == part then
		return look
	end
	local created: PartLook = {
		name = partName,
		part = part,
		burn = nil,
		shown = table.create(6, 0),
		spotShown = table.create(BurnCode.MAX_SPOTS, 0),
		faces = {},
		fx = {},
		level = 0,
		acid = false,
		hidden = false,
		gone = false,
	}
	session.parts[partName] = created
	-- (the part goes invisible later, a burn long settled: a burst head, a
	-- cut opened, on a corpse too: hide its textures then)
	table.insert(
		session.connections,
		part:GetPropertyChangedSignal("Transparency"):Connect(function()
			if isHidden(part) ~= created.hidden or isGone(part) ~= created.gone then
				session.animating = true
				ensureHeartbeat()
			end
		end)
	)
	return created
end

local function readPart(session: Session, partName: string, instant: boolean)
	local attribute = BurnCode.attribute(partName)
	if attribute == nil then
		return
	end
	local burn = BurnCode.decode(session.model:GetAttribute(attribute))
	local look = lookOf(session, partName)
	if look == nil then
		return
	end
	look.burn = burn
	if instant then
		for face = 1, 6 do
			look.shown[face] = if burn then burn.faces[face] else 0
		end
		for index = 1, BurnCode.MAX_SPOTS do
			local spot = if burn then burn.spots[index] else nil
			look.spotShown[index] = if spot then spot.degree else 0
		end
		drawPart(session, look)
	end
	session.animating = true
	ensureHeartbeat()
end

local function readLit(session: Session)
	local model = session.model
	local lit = BurnCode.decodeLit(model:GetAttribute(BurnCode.LIT))
	local wasBurning = session.burning
	local anyFire, anyAcid = false, false
	for _, partName in BurnCode.PARTS do
		local code = BurnCode.CODE_OF[partName]
		local level = lit[code] or 0
		local look = session.parts[partName]
			or (if level > 0 then lookOf(session, partName) else nil)
		if look then
			look.level = level
			look.acid = look.burn ~= nil and (look.burn :: BurnCode.PartBurn).kind == "Acid"
			if level > 0 then
				if look.acid then
					anyAcid = true
				else
					anyFire = true
				end
			end
		end
	end
	session.lit = lit
	session.burning = anyFire or anyAcid
	-- The light: one per body on fire.
	if anyFire then
		local light = session.light
		local torso = bodyPart(model, "Torso")
		if light == nil and torso then
			local created = Instance.new("PointLight")
			created.Name = NAME
			created.Color = FIRE_LIGHT
			created.Shadows = true
			created.Range = 10
			created.Brightness = 0
			created.Parent = torso
			session.light = created
		end
	elseif session.light then
		session.light.Enabled = false
	end
	if session.light and anyFire then
		session.light.Enabled = true
	end
	-- Catching fire: the sound, a cry (a living body, not too often).
	if session.burning and not wasBurning then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local alive = humanoid ~= nil
			and humanoid.Health > 0
			and not model:HasTag(Config.Combat.CORPSE_TAG)
		if alive then
			SoundController.play(if anyFire then "Burn" else "AcidSizzle", model)
			local now = os.clock()
			if now >= (nextCry[model] or 0) then
				nextCry[model] = now + CRY_INTERVAL
				SoundController.play("BurnCry", model)
			end
		end
	end
	session.animating = true
	ensureHeartbeat()
end

local function readSmoke(session: Session)
	local value = session.model:GetAttribute(BurnCode.SMOKE)
	local serverUntil = if typeof(value) == "number" then value else 0
	-- (server time -> our clock)
	session.smokeUntil = os.clock() + math.max(0, serverUntil - workspace:GetServerTimeNow())
	session.animating = true
	ensureHeartbeat()
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

local function wipe(session: Session)
	for _, connection in session.connections do
		connection:Disconnect()
	end
	for _, look in session.parts do
		for _, faceLook in look.faces do
			for _, texture in faceLook.layers do
				texture:Destroy()
			end
			for _, texture in faceLook.spots do
				texture:Destroy()
			end
		end
		local fx = look.fx
		for _, emitter in { fx.flame, fx.smoke, fx.embers, fx.fizz, fx.vapour, fx.drips } do
			if emitter then
				emitter:Destroy()
			end
		end
	end
	if session.light then
		session.light:Destroy()
	end
	sessions[session.model] = nil
end

local function approach(value: number, goal: number, dt: number): number
	if value < goal then
		return math.min(goal, value + SHOW_UP * dt)
	end
	return math.max(goal, value - SHOW_DOWN * dt)
end

function Burns._step(dt: number)
	local now = os.clock()
	textureClock += dt
	local textures = textureClock >= TEXTURE_STEP
	local textureDt = textureClock
	if textures then
		textureClock = 0
	end
	local camera = workspace.CurrentCamera
	local any = false
	for model, session in sessions do
		local smouldering = now < session.smokeUntil
		local busy = session.burning or smouldering or session.smoking or session.animating
		if not busy then
			continue
		end
		any = true
		-- The light flickers (smooth noise, two speeds), every frame.
		local light = session.light
		if light and light.Enabled then
			local n = math.noise(now * 7.3, session.seed) * 0.6
				+ math.noise(now * 19.1, session.seed + 3) * 0.4
			local total = 0
			for _, level in session.lit do
				total += level
			end
			light.Brightness = math.clamp(0.9 + total * 0.18, 1, 2.6) * (1 + 0.45 * n)
			light.Range = math.clamp(7 + total * 0.9, 8, 16) * (1 + 0.08 * n)
		end
		if not textures then
			continue
		end
		local firstPerson = false
		if session.own and camera then
			local head = bodyPart(model, "Head")
			firstPerson = head ~= nil and (camera.CFrame.Position - head.Position).Magnitude < 1.6
		end
		local moving = false
		for _, look in session.parts do
			if look.part.Parent == nil then
				continue
			end
			local burn = look.burn
			local changed = isHidden(look.part) ~= look.hidden or isGone(look.part) ~= look.gone
			for face = 1, 6 do
				local goal = if burn then burn.faces[face] else 0
				local value = look.shown[face]
				if value ~= goal then
					look.shown[face] = approach(value, goal, textureDt)
					changed = true
				end
			end
			for index = 1, BurnCode.MAX_SPOTS do
				local spot = if burn then burn.spots[index] else nil
				local goal = if spot then spot.degree else 0
				local value = look.spotShown[index]
				if value ~= goal then
					look.spotShown[index] = approach(value, goal, textureDt)
					changed = true
				end
			end
			if changed then
				moving = true
				drawPart(session, look)
			end
			driveFx(look, smouldering, firstPerson)
		end
		session.animating = moving
		session.smoking = smouldering
	end
	if not any and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

------------------------------------------------------------------------------
-- Watching a model
------------------------------------------------------------------------------

-- A copy of a body (a clone) made on this client carries our instances:
-- they go, it draws its own.
local function scrubCopy(model: Model)
	for _, item in model:GetDescendants() do
		if item.Name == NAME then
			item:Destroy()
		end
	end
end

function Burns.watch(model: Model)
	if sessions[model] then
		return
	end
	scrubCopy(model)
	local session: Session = {
		model = model,
		parts = {},
		lit = {},
		smokeUntil = 0,
		smoking = false,
		light = nil,
		seed = hash(model.Name) % 997,
		animating = false,
		burning = false,
		own = model == Players.LocalPlayer.Character,
		connections = {},
	}
	sessions[model] = session
	local function readAll(instant: boolean)
		for _, partName in BurnCode.PARTS do
			readPart(session, partName, instant)
		end
		readLit(session)
		readSmoke(session)
	end
	table.insert(
		session.connections,
		model.AttributeChanged:Connect(function(name: string)
			if string.sub(name, 1, #BurnCode.PREFIX) == BurnCode.PREFIX then
				local partName = BurnCode.PART_OF[string.sub(name, #BurnCode.PREFIX + 1)]
				if partName then
					readPart(session, partName, false)
				end
			elseif name == BurnCode.LIT then
				readLit(session)
			elseif name == BurnCode.SMOKE then
				readSmoke(session)
			end
		end)
	)
	-- Streamed out and back in, a body part replaced: read it all again.
	table.insert(
		session.connections,
		model.ChildAdded:Connect(function(child: Instance)
			if child:IsA("BasePart") and BurnCode.CODE_OF[child.Name] then
				readAll(true)
			end
		end)
	)
	table.insert(
		session.connections,
		model.AncestryChanged:Connect(function()
			if model:IsDescendantOf(game) then
				readAll(true)
			end
		end)
	)
	model.Destroying:Once(function()
		if sessions[model] == session then
			wipe(session)
		end
	end)
	readAll(true)
end

return Burns
