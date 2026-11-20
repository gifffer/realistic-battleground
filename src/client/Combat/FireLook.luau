--!strict
-- FireLook: the layers every flame in the game is made of (Client/Combat/
-- Burns: burning bodies; Client/Combat/PyroFx: the Pyromaniac). Textures
-- in assets/fire (tools/pyro/make_fire.py), ids in Config.Injuries.FIRE.
-- An id still 0 = Roblox's own particle stands in, flipbook off, tinted
-- like the old look.
--
--   FireLook.layer(kind, parent, scale, name?)   one layer, Rate 0 (the
--       caller sets Rate or calls Emit):
--     "body"     a few big looping flame clusters (the fire's mass)
--     "tongue"   one-shot tongues licking up off it
--     "glow"     the hot core hugging the fuel (additive)
--     "smoke"    dark soot lit warm from below, greying as it thins
--     "ember"    floating embers and flakes
--     "spark"    fast thin sparks (a strike, an impact)
--     "fireball" a rolling fireball that turns to soot
--     "ground"   a burning film lying flat on the floor
--   FireLook.bodySize(scale, peak)   the body layer's size curve
--   FireLook.has(sheet) / FireLook.image(sheet)
--   FireLook.quality()     1, 0.75 or 0.5 (the Roblox graphics level)
--   FireLook.gust(t, seed) 0..1, how hard a fire breathes right now
--   FireLook.preload()

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local FireLook = {}

export type Sheet =
	"flameLoop"
	| "flameTongue"
	| "fireball"
	| "groundFire"
	| "smoke"
	| "ember"
	| "glow"
	| "flameStrip"
	| "scorch"
export type Kind = "body" | "tongue" | "glow" | "smoke" | "ember" | "spark" | "fireball" | "ground"

local IDS = Config.Injuries.FIRE

local BUILTIN_FIRE = "rbxasset://textures/particles/fire_main.dds"
local BUILTIN_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local BUILTIN_SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function numbers(points: { { number } }): NumberSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function colors(points: { { any } }): ColorSequence
	local keys = {}
	for _, p in points do
		table.insert(keys, ColorSequenceKeypoint.new(p[1] :: number, p[2] :: Color3))
	end
	return ColorSequence.new(keys)
end

FireLook.numbers = numbers
FireLook.colors = colors

------------------------------------------------------------------------------
-- Sheets
------------------------------------------------------------------------------

function FireLook.has(sheet: Sheet): boolean
	return ((IDS :: any)[sheet] or 0) ~= 0
end

function FireLook.image(sheet: Sheet): string?
	local id = (IDS :: any)[sheet] or 0
	return if id ~= 0 then `rbxassetid://{id}` else nil
end

type Flipbook = {
	layout: Enum.ParticleFlipbookLayout,
	mode: Enum.ParticleFlipbookMode,
	fps: NumberRange?,
	random: boolean,
}

local FLIPBOOKS: { [string]: Flipbook } = {
	flameLoop = {
		layout = Enum.ParticleFlipbookLayout.Grid8x8,
		mode = Enum.ParticleFlipbookMode.Loop,
		fps = NumberRange.new(20, 28),
		random = true,
	},
	flameTongue = {
		layout = Enum.ParticleFlipbookLayout.Grid4x4,
		mode = Enum.ParticleFlipbookMode.OneShot,
		fps = nil,
		random = false,
	},
	fireball = {
		layout = Enum.ParticleFlipbookLayout.Grid8x8,
		mode = Enum.ParticleFlipbookMode.OneShot,
		fps = nil,
		random = false,
	},
	groundFire = {
		layout = Enum.ParticleFlipbookLayout.Grid4x4,
		mode = Enum.ParticleFlipbookMode.Loop,
		fps = NumberRange.new(9, 13),
		random = true,
	},
	-- (a still frame picked at random per particle: four different puffs)
	smoke = {
		layout = Enum.ParticleFlipbookLayout.Grid2x2,
		mode = Enum.ParticleFlipbookMode.Loop,
		fps = NumberRange.new(0, 0),
		random = true,
	},
	ember = {
		layout = Enum.ParticleFlipbookLayout.Grid2x2,
		mode = Enum.ParticleFlipbookMode.Loop,
		fps = NumberRange.new(0, 0),
		random = true,
	},
}

local FALLBACKS: { [string]: string } = {
	flameLoop = BUILTIN_FIRE,
	flameTongue = BUILTIN_FIRE,
	fireball = BUILTIN_FIRE,
	groundFire = BUILTIN_FIRE,
	smoke = BUILTIN_SMOKE,
	ember = BUILTIN_SPARK,
	glow = BUILTIN_FIRE,
}

-- The first burn pictures (Config.Injuries.BURNS: a grey 4 x 4 one-shot
-- flame tongue, a puff, an ember), better than Roblox's own while ours
-- are not uploaded.
local LEGACY = Config.Injuries.BURNS
local LEGACY_OF: { [string]: number } = {
	flameLoop = LEGACY.flame,
	flameTongue = LEGACY.flame,
	smoke = LEGACY.smoke,
	ember = LEGACY.ember,
}

-- The texture (and flipbook) on an emitter. True if it is ours (colours
-- baked in); false = a grey or built-in stand-in (to be coloured).
local function dress(emitter: ParticleEmitter, sheet: Sheet): boolean
	local image = FireLook.image(sheet)
	if image then
		emitter.Texture = image
		local book = FLIPBOOKS[sheet]
		if book then
			emitter.FlipbookLayout = book.layout
			emitter.FlipbookMode = book.mode
			if book.fps then
				emitter.FlipbookFramerate = book.fps
			end
			emitter.FlipbookStartRandom = book.random
		end
		return true
	end
	local legacy = LEGACY_OF[sheet] or 0
	if legacy ~= 0 then
		emitter.Texture = `rbxassetid://{legacy}`
		if sheet == "flameLoop" or sheet == "flameTongue" then
			emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
			emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		end
		return false
	end
	emitter.Texture = FALLBACKS[sheet] or BUILTIN_FIRE
	return false
end

------------------------------------------------------------------------------
-- Colours (the textures carry their own colours: these only warm them and
-- darken them as a particle cools; the fallbacks need the full colour)
------------------------------------------------------------------------------

local FLAME_TINT = colors({
	{ 0, rgb(255, 255, 255) },
	{ 0.55, rgb(255, 232, 208) },
	{ 1, rgb(196, 112, 80) },
})
local FLAME_FALLBACK = colors({
	{ 0, rgb(255, 232, 178) },
	{ 0.25, rgb(255, 168, 64) },
	{ 0.6, rgb(226, 92, 26) },
	{ 1, rgb(110, 34, 16) },
})
local FIREBALL_FALLBACK = colors({
	{ 0, rgb(255, 226, 160) },
	{ 0.25, rgb(255, 146, 44) },
	{ 0.6, rgb(196, 58, 14) },
	{ 1, rgb(26, 23, 21) },
})
-- Soot: warm where the flames light it from below, near black, grey thin.
local SMOKE_FIRE = colors({
	{ 0, rgb(112, 64, 36) },
	{ 0.2, rgb(30, 26, 23) },
	{ 1, rgb(80, 75, 70) },
})
local EMBER_TINT = colors({
	{ 0, rgb(255, 244, 214) },
	{ 0.4, rgb(255, 170, 96) },
	{ 1, rgb(190, 54, 24) },
})

FireLook.SMOKE_FIRE = SMOKE_FIRE
FireLook.SMOKE_THIN = colors({ { 0, rgb(98, 94, 90) }, { 1, rgb(142, 138, 134) } })
FireLook.LIGHT = rgb(255, 140, 60)

function FireLook.bodySize(scale: number, peak: number): NumberSequence
	return numbers({ { 0, 0.5 * scale }, { 0.3, peak * scale }, { 1, 0.55 * scale } })
end

------------------------------------------------------------------------------
-- Layers
------------------------------------------------------------------------------

local function base(name: string?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name or "Fire"
	e.Rate = 0
	e.LightInfluence = 0
	e.EmissionDirection = Enum.NormalId.Top
	return e
end

function FireLook.layer(kind: Kind, parent: Instance, scale: number, name: string?): ParticleEmitter
	local e = base(name)
	if kind == "body" then
		local ours = dress(e, "flameLoop")
		e.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		e.Color = if ours then FLAME_TINT else FLAME_FALLBACK
		e.LightEmission = if ours then 0.6 else 0.8
		e.Brightness = if ours then 1.6 else 1
		e.Size = FireLook.bodySize(scale, 1)
		e.Transparency = numbers({ { 0, 1 }, { 0.08, 0.2 }, { 0.6, 0.35 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(0.5, 0.8)
		e.Speed = NumberRange.new(0.3 * scale, 0.8 * scale)
		e.Acceleration = Vector3.new(0, 2.5 * scale, 0)
		e.Drag = 2
		e.SpreadAngle = Vector2.new(8, 8)
		e.Rotation = NumberRange.new(-10, 10)
		e.RotSpeed = NumberRange.new(-20, 20)
		e.ZOffset = 0.3
	elseif kind == "tongue" then
		local ours = dress(e, "flameTongue")
		e.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		e.Color = if ours then FLAME_TINT else FLAME_FALLBACK
		e.LightEmission = if ours then 0.8 else 0.85
		e.Brightness = if ours then 2 else 1
		e.Size = numbers({ { 0, 0.7 * scale }, { 1, 1.1 * scale } })
		e.Transparency = numbers({ { 0, 0.15 }, { 0.7, 0.3 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(0.35, 0.6)
		e.Speed = NumberRange.new(2 * scale, 3.5 * scale)
		e.Acceleration = Vector3.new(0, 9 * scale, 0)
		e.Drag = 1
		e.SpreadAngle = Vector2.new(10, 10)
		e.Rotation = NumberRange.new(-8, 8)
		e.ZOffset = 0.35
	elseif kind == "glow" then
		local ours = dress(e, "glow")
		e.Color = ColorSequence.new(rgb(255, 190, 110))
		e.LightEmission = 1
		e.Brightness = if ours then 2.5 else 1
		e.Size = NumberSequence.new(1.1 * scale)
		e.Transparency = numbers({ { 0, if ours then 0.7 else 0.85 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(0.15, 0.25)
		e.Speed = NumberRange.new(0, 0)
		e.LockedToPart = true
		e.ZOffset = 0.4
	elseif kind == "smoke" then
		dress(e, "smoke")
		e.Color = SMOKE_FIRE
		e.LightEmission = 0
		e.LightInfluence = 1
		e.Size = numbers({ { 0, 1.2 * scale }, { 1, 6 * scale } })
		e.Transparency = numbers({ { 0, 1 }, { 0.15, 0.45 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(2.5, 3.5)
		e.Speed = NumberRange.new(2, 3.5)
		e.Acceleration = Vector3.new(0, 2, 0)
		e.Drag = 0.8
		e.SpreadAngle = Vector2.new(12, 12)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-20, 20)
		e.ZOffset = -0.5
	elseif kind == "ember" then
		dress(e, "ember")
		e.Color = EMBER_TINT
		e.LightEmission = 1
		e.Brightness = 3
		e.Size = numbers({ { 0, 0.09 * scale }, { 1, 0.03 * scale } })
		e.Transparency = numbers({ { 0, 0 }, { 0.75, 0.2 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(1, 2.2)
		e.Speed = NumberRange.new(3, 6)
		e.Acceleration = Vector3.new(0, 4, 0)
		e.Drag = 1.2
		e.SpreadAngle = Vector2.new(40, 40)
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.ZOffset = 0.45
	elseif kind == "spark" then
		dress(e, "ember")
		e.Color = EMBER_TINT
		e.LightEmission = 1
		e.Brightness = 4
		e.Size = numbers({ { 0, 0.06 * scale }, { 1, 0.01 } })
		e.Lifetime = NumberRange.new(0.12, 0.25)
		e.Speed = NumberRange.new(4 * scale, 8 * scale)
		e.Acceleration = Vector3.new(0, -30, 0)
		e.SpreadAngle = Vector2.new(35, 35)
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.ZOffset = 0.5
	elseif kind == "fireball" then
		local ours = dress(e, "fireball")
		e.Color = if ours then ColorSequence.new(rgb(255, 255, 255)) else FIREBALL_FALLBACK
		e.LightEmission = if ours then 0.45 else 0.75
		e.Brightness = if ours then 1.6 else 1
		e.Size = numbers({ { 0, 0.9 * scale }, { 1, 1.45 * scale } })
		e.Transparency = if ours
			then numbers({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } })
			else numbers({ { 0, 0.05 }, { 0.7, 0.35 }, { 1, 1 } })
		e.Lifetime = if ours then NumberRange.new(0.9, 1.3) else NumberRange.new(0.45, 0.8)
		e.Speed = NumberRange.new(1, 3)
		e.Acceleration = Vector3.new(0, 6, 0)
		e.Drag = 3
		e.SpreadAngle = Vector2.new(60, 60)
		e.Rotation = if ours then NumberRange.new(-25, 25) else NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-15, 15)
		e.ZOffset = 0.2
	elseif kind == "ground" then
		local ours = dress(e, "groundFire")
		e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		e.Color = if ours then FLAME_TINT else FLAME_FALLBACK
		e.LightEmission = if ours then 0.8 else 0.6
		e.Brightness = if ours then 1.5 else 1
		e.Size = numbers({ { 0, 0.85 * scale }, { 1, 1.05 * scale } })
		e.Transparency = if ours
			then numbers({ { 0, 1 }, { 0.25, 0.3 }, { 0.75, 0.35 }, { 1, 1 } })
			else numbers({ { 0, 1 }, { 0.3, 0.6 }, { 0.7, 0.65 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Speed = NumberRange.new(0.01, 0.01)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-6, 6)
		e.ZOffset = 0.05
	end
	e.Parent = parent
	return e
end

------------------------------------------------------------------------------
-- Quality, breathing, preload
------------------------------------------------------------------------------

local qualityValue = 1
local qualityAt = -math.huge

-- The Roblox graphics level (Esc > Settings): low halves the particles and
-- drops the core glow, medium keeps three quarters. Read every 4 s.
function FireLook.quality(): number
	local now = os.clock()
	if now - qualityAt < 4 then
		return qualityValue
	end
	qualityAt = now
	local ok, level = pcall(function(): number
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	local value = if not ok or level == 0
		then 0.75
		elseif level <= 3 then 0.5
		elseif level <= 6 then 0.75
		else 1
	-- (a phone or a tablet: at most medium)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		value = math.min(value, 0.75)
	end
	qualityValue = value
	return value
end

-- Two speeds of smooth noise: a fire swells and drops, never steady.
function FireLook.gust(t: number, seed: number): number
	local n = math.noise(t * 1.3, seed, 0.37) + 0.5 * math.noise(t * 3.1, seed + 7.1, 0.61)
	return math.clamp(0.5 + n, 0, 1)
end

local preloaded = false
function FireLook.preload()
	if preloaded then
		return
	end
	preloaded = true
	local list = {}
	for _, sheet: Sheet in
		{
			"flameLoop",
			"flameTongue",
			"fireball",
			"groundFire",
			"smoke",
			"ember",
			"glow",
			"flameStrip",
			"scorch",
		} :: { Sheet }
	do
		local image = FireLook.image(sheet)
		if image then
			table.insert(list, image)
		end
	end
	if #list > 0 then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(list)
			end)
		end)
	end
end

return FireLook
