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
-- THE FIRE ("BurnLit"), layered (Combat/FireLook) on each part in flames:
-- a few big looping flame clusters born inside the part (the fire's mass),
-- tongues licking up off it, a hot core glow, embers. Per body: ONE smoke
-- column and ONE flickering light (shadows on), on a "heart" that follows
-- the middle of the flames and wanders a little. The fire breathes (a gust
-- value scales the flames and the light together), flares up now and then
-- (a lick of tongues, the light pops), catches in a fraction of a second
-- and dies down over about a second (a last puff of smoke). Acid instead:
-- fizz, pale vapour, drops falling. Out ("BurnSmoke"): the charred parts
-- smoulder, thin grey smoke and a few embers, then nothing.
--
-- Budget: the textures are built once per face and stage (at most 4 + 2
-- spots on a face) and only reused after; the emitters once per part; no
-- instance is made or dropped while it burns (only when a new face gets a
-- stage). About 17 flame quads per fully lit part. One Heartbeat for every
-- burning body; the textures and emitter rates update 15 times a second,
-- the light every frame. The Roblox graphics level scales the rates.
--
-- Everything is named "BurnFx..." (RiftPortal's clone copies skip it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BurnCode = require(ReplicatedStorage.Shared.Util.BurnCode)
local Config = require(ReplicatedStorage.Shared.Config)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local FireLook = require(script.Parent.FireLook)

local Burns = {}

local NAME = "BurnFx"
local TILE = 2 -- studs per texture tile (512 px)
local SPOT_TILE = 2.6 -- a spot's tile: bigger than a face, one spot shows
local FADE_BAND = 0.4 -- a stage fades in over its first 0.4 degree
local SHOW_UP = 1.4 -- degrees / s the drawn burn catches up
local SHOW_DOWN = 2.5 -- and goes (healed)
local TEXTURE_STEP = 1 / 15
local CRY_INTERVAL = 2.5

local FIRE_LIGHT = FireLook.LIGHT
local CATCH_SPEED = 6 -- levels / s a part's fire grows (catching)
local DIE_SPEED = 2.5 -- and dies down (out)

local random = Random.new()

-- Fallback particle pictures (Roblox's own) for the acid.
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
	body: ParticleEmitter?,
	tongues: ParticleEmitter?,
	glow: ParticleEmitter?,
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
	heat: number, -- the level drawn (eases toward it)
	band: number, -- the body flames' size step (1..3)
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
	heart: Attachment?, -- (the light and the smoke: the middle of the fire)
	smoke: ParticleEmitter?,
	smokeMode: string,
	centre: Vector3, -- the heart's place (Torso space)
	heat: number, -- every part's heat, summed
	gust: number, -- 0..1, how hard the fire breathes now
	pop: number, -- the light pops until then (a flare-up, catching)
	nextFlare: number,
	puff: number, -- parts just gone out: a last puff of smoke
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

local function bodyPart(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

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

-- Thick soot over a fire; thin grey over a smouldering body.
local SMOKE_ALPHA_FIRE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.15, 0.45),
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

-- A fire layer born inside the part (Box volume), going up.
local function partLayer(look: PartLook, kind: FireLook.Kind): ParticleEmitter
	local e = FireLook.layer(kind, look.part, scaleOf(look.part), NAME)
	e.Enabled = false
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	return e
end

-- The fire on one part: the body (a few big looping flame clusters), the
-- tongues licking off it, the hot core glow, embers.
local function fireOf(
	look: PartLook
): (ParticleEmitter, ParticleEmitter, ParticleEmitter, ParticleEmitter)
	local fx = look.fx
	local body, tongues, glow, embers = fx.body, fx.tongues, fx.glow, fx.embers
	if body and tongues and glow and embers then
		return body, tongues, glow, embers
	end
	local newBody = partLayer(look, "body")
	local newTongues = partLayer(look, "tongue")
	local newGlow = partLayer(look, "glow")
	local newEmbers = partLayer(look, "ember")
	newEmbers.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	fx.body, fx.tongues, fx.glow, fx.embers = newBody, newTongues, newGlow, newEmbers
	return newBody, newTongues, newGlow, newEmbers
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
	if rate <= 0.01 then
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

-- The emitters of one part from what burns there now (15 times a second).
-- `heat` eases toward the level: the fire catches in a fraction of a second
-- (with a burst of tongues), and dies down over about a second.
local function driveFx(
	session: Session,
	look: PartLook,
	smouldering: boolean,
	firstPerson: boolean,
	dt: number,
	quality: number
)
	local target = if look.gone or look.acid then 0 else look.level
	local was = look.heat
	if target > was then
		look.heat = math.min(target, was + CATCH_SPEED * dt)
	else
		look.heat = math.max(target, was - DIE_SPEED * dt)
	end
	local heat = look.heat
	local head = look.name == "Head"
	local hideFlames = head and firstPerson
	if heat > 0 then
		local s = scaleOf(look.part)
		local body, tongues, glow, embers = fireOf(look)
		local g = 0.8 + 0.4 * session.gust
		local flames = if hideFlames then 0 else quality * g
		-- (bigger flame clusters at a higher level)
		local band = math.clamp(math.round(heat), 1, 3)
		if look.band ~= band then
			look.band = band
			body.Size = FireLook.bodySize(s, 1.6 + 0.45 * band)
		end
		setRate(body, (2.5 + 2.2 * heat) * s * flames)
		setRate(tongues, (1.5 + 3 * heat) * s * flames)
		setRate(glow, if quality >= 0.75 and not hideFlames then 5 * heat else 0)
		setRate(embers, (0.4 + 0.6 * heat) * quality)
		if was <= 0 and not hideFlames then
			-- catching: a lick of tongues at once
			tongues:Emit(4)
			session.pop = os.clock() + 0.15
		end
	else
		local fx = look.fx
		setRate(fx.body, 0)
		setRate(fx.tongues, 0)
		setRate(fx.glow, 0)
		if was > 0 then
			session.puff += 1 -- (out: a last puff of smoke)
		end
		local charred = not look.gone and maxDegree(look) >= 3.5
		setRate(fx.embers, if smouldering and charred and not hideFlames then 0.5 * quality else 0)
	end
	if look.level > 0 and look.acid then
		local fizz, vapour, drips = acidOf(look)
		setRate(fizz, 10 + 8 * look.level)
		setRate(vapour, 1.5 + look.level)
		setRate(drips, 1 + look.level)
	else
		setRate(look.fx.fizz, 0)
		setRate(look.fx.vapour, 0)
		setRate(look.fx.drips, 0)
	end
end

-- One heart per body: an attachment on the Torso that follows the middle
-- of what burns, holding the fire's light and its smoke (one column per
-- body, not per part: much less overdraw).
local function heartOf(session: Session): Attachment?
	local current = session.heart
	if current and current.Parent then
		return current
	end
	local torso = bodyPart(session.model, "Torso")
	if torso == nil then
		return nil
	end
	local heart = Instance.new("Attachment")
	heart.Name = NAME
	heart.Parent = torso
	local light = Instance.new("PointLight")
	light.Name = NAME
	light.Color = FIRE_LIGHT
	light.Shadows = true
	light.Range = 10
	light.Brightness = 0
	light.Enabled = false
	light.Parent = heart
	local smoke = FireLook.layer("smoke", heart, 1, NAME)
	smoke.Enabled = false
	session.heart, session.light, session.smoke = heart, light, smoke
	return heart
end

-- The heart's place, the smoke and the flare-ups (15 times a second).
local function driveHeart(session: Session, smouldering: boolean, quality: number)
	local total, weight = 0, 0
	local sum = Vector3.zero
	local charredSum, charredCount = Vector3.zero, 0
	local torso = bodyPart(session.model, "Torso")
	for _, look in session.parts do
		if look.part.Parent == nil then
			continue
		end
		local heat = look.heat
		local offset = if torso
			then torso.CFrame:PointToObjectSpace(look.part.Position)
			else Vector3.zero
		if heat > 0 then
			total += heat
			weight += heat
			sum += offset * heat
		elseif smouldering and not look.gone and maxDegree(look) >= 2 then
			charredSum += offset
			charredCount += 1
		end
	end
	session.heat = total
	local needed = total > 0 or (smouldering and charredCount > 0) or session.puff > 0
	if not needed and session.heart == nil then
		return
	end
	local heart = heartOf(session)
	local smoke = session.smoke
	if heart == nil or smoke == nil then
		return
	end
	if weight > 0 then
		session.centre = sum / weight + Vector3.new(0, 0.3, 0)
	elseif charredCount > 0 then
		session.centre = charredSum / charredCount
	end
	if total > 0 then
		if session.smokeMode ~= "fire" then
			session.smokeMode = "fire"
			smoke.Color = FireLook.SMOKE_FIRE
			smoke.Transparency = SMOKE_ALPHA_FIRE
		end
		setRate(smoke, math.min(1.5 + 0.6 * total, 9) * quality)
	elseif smouldering and charredCount > 0 then
		if session.smokeMode ~= "smoulder" then
			session.smokeMode = "smoulder"
			smoke.Color = FireLook.SMOKE_THIN
			smoke.Transparency = SMOKE_ALPHA_SMOULDER
		end
		setRate(smoke, (1 + 0.25 * charredCount) * quality)
	else
		setRate(smoke, 0)
	end
	if session.puff > 0 then
		smoke:Emit(math.min(session.puff * 2, 5))
		session.puff = 0
	end
	-- Flare-ups: now and then one lit part licks up higher, the light pops.
	local now = os.clock()
	if total > 0 and now >= session.nextFlare then
		session.nextFlare = now + random:NextNumber(0.6, 1.5)
		local lit = {}
		for _, look in session.parts do
			if look.heat > 0.5 and look.fx.tongues and not look.hidden then
				table.insert(lit, look)
			end
		end
		if #lit > 0 then
			local look = lit[random:NextInteger(1, #lit)]
			local tongues = look.fx.tongues :: ParticleEmitter
			tongues:Emit(random:NextInteger(2, 3))
			session.pop = now + 0.12
		end
	end
end

------------------------------------------------------------------------------
-- Reading the attributes
------------------------------------------------------------------------------

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
		heat = 0,
		band = 0,
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
		for _, emitter in { fx.body, fx.tongues, fx.glow, fx.embers, fx.fizz, fx.vapour, fx.drips } do
			if emitter then
				emitter:Destroy()
			end
		end
	end
	if session.heart then
		session.heart:Destroy()
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
		local busy = session.burning
			or smouldering
			or session.smoking
			or session.animating
			or session.heat > 0
			or session.puff > 0
		if not busy then
			continue
		end
		any = true
		-- Every frame: the fire breathes (gust), the light flickers on two
		-- noise speeds with it and wanders round the middle of the flames
		-- (shadows and highlights crawl), popping on a flare-up.
		local heart = session.heart
		if heart then
			local seed = session.seed
			session.gust = FireLook.gust(now, seed)
			heart.Position = session.centre
				+ Vector3.new(
						math.noise(now * 2.3, seed, 1.1),
						0.6 * math.noise(now * 2.9, seed, 2.3),
						math.noise(now * 2.1, seed, 3.7)
					)
					* 0.6
			local light = session.light
			local total = session.heat
			if light and total > 0 then
				local n = math.noise(now * 7.3, seed) * 0.6 + math.noise(now * 19.1, seed + 3) * 0.4
				local pop = if now < session.pop then 1.4 else 1
				light.Enabled = true
				light.Brightness = math.clamp(0.9 + total * 0.18, 1, 2.6)
					* math.min(total, 1)
					* (0.75 + 0.5 * session.gust)
					* (1 + 0.35 * n)
					* pop
				light.Range = math.clamp(7 + total * 0.9, 8, 16)
					* (0.9 + 0.15 * session.gust)
					* (1 + 0.06 * n)
			elseif light and light.Enabled then
				light.Enabled = false
			end
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
		local quality = FireLook.quality()
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
			driveFx(session, look, smouldering, firstPerson, textureDt, quality)
		end
		driveHeart(session, smouldering, quality)
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
		heart = nil,
		smoke = nil,
		smokeMode = "",
		centre = Vector3.zero,
		heat = 0,
		gust = 0.5,
		pop = 0,
		nextFlare = 0,
		puff = 0,
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
