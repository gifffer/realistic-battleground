--!strict
-- RainController: the rain you SEE in the world during the Rain weather event (and the
-- thunderstorm, its heavier version).
--
-- The server (Server/Systems/Weather) starts and ends the event; WeatherController turns its
-- Workspace attributes into the rain's strength (0 → 1, with the same ramp in and out as the
-- server's sky, so it starts, ends and lasts exactly like the event, even for a late joiner)
-- and the slanted fall of the drops (wind + gusts). This controller only draws, on THIS
-- screen, and owns nothing but its own instances (in the camera):
--
--   NEAR  3 x 3 cells of 14 studs around the camera, each split in 2 x 2 emitters of 7 studs
--         (finer roofs): few, wide, long streaks (a drop is a clear bead with a bright glint,
--         stretched along its fall like motion blur).
--   MID   a ring of 24 cells of 42 studs, out to ~105 studs: thinner, denser, fainter streaks.
--   FAR   rain curtains at ~150 studs (Beams with a falling sheet of streaks, a fixed ring that
--         follows the camera smoothly), plus the haze
--         the server adds to the sky: the distance turns grey, so it never looks like a filter
--         stuck on the screen.
--   GROUND splashes (a small crown of droplets) on hard ground around you, tiny ripple rings
--         on flat wet ground, and a thin drifting mist at ground level.
--
-- The cells sit on a fixed WORLD grid (they jump by whole cells as you move): the drops
-- already falling stay where they are, nothing slides with the camera.
--
-- No rain inside: each cell knows how high the first roof below it is (a few rays straight
-- down, cached for a few seconds, then cast again: streamed-in or broken buildings are seen)
-- and its drops die right there. Near cells take the highest roof they cover (never a drop
-- under an awning); mid cells take the middle value (rain over the roofs of a block, on the
-- street beside it).
--
-- Quality (Settings → Graphics quality): low (1-3), medium (4-7), high (8-10). "Automatic"
-- cannot be read by a game: it starts medium and steps down / up with the frame rate. Phones
-- and tablets are at most medium. Every emitter stays under Roblox's 400 drops/s.
-- The park (always sunny) and duels have no rain.
-- Pictures: Config.Weather.RAIN_IMAGES (assets/rain/, guide docs/RAIN_FR.md); until they are
-- uploaded, built-in Roblox textures stand in and the far curtains are skipped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local ParkAtmosphereController = require(script.Parent.ParkAtmosphereController)
local WeatherController = require(script.Parent.WeatherController)

local W = Config.Weather
local R = W.RAIN
local IMAGES = W.RAIN_IMAGES

local RainController = {}

local player = Players.LocalPlayer
local random = Random.new()

-- Built-in Roblox textures (always there): the fallbacks while our pictures are not uploaded.
local SPARKS = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local RING = "rbxasset://textures/particles/explosion01_shockwave_main.dds"

local function image(id: number): string?
	return if id > 0 then "rbxassetid://" .. tostring(id) else nil
end

local DROP_IMAGE = image(IMAGES.drop)
local SPLASH_IMAGE = image(IMAGES.splash)
local RIPPLE_IMAGE = image(IMAGES.ripple)
local SHEET_IMAGE = image(IMAGES.sheet)

------------------------------------------------------------------------------
-- Tuning
------------------------------------------------------------------------------

-- Clear water lit by the street: a cold grey that takes the lamps' light.
local DROP_COLOR = Color3.fromRGB(176, 186, 198)
local DROP_LIGHT_INFLUENCE = 0.75
local DROP_LIGHT_EMISSION = 0.12
local NEAR_TRANSPARENCY = 0.4
local MID_TRANSPARENCY = 0.55
-- Roblox's cap per emitter.
local MAX_RATE = 400

-- What each graphics tier draws (shares of Config.Weather.RAIN).
type Tier = {
	near: number,
	mid: number,
	splash: number,
	ripples: boolean,
	curtains: number,
	mist: boolean,
}
local TIERS: { Tier } = {
	{ near = 0.6, mid = 0.3, splash = 0.35, ripples = false, curtains = 4, mist = false },
	{ near = 0.85, mid = 0.6, splash = 0.65, ripples = true, curtains = 6, mist = true },
	{ near = 1, mid = 1, splash = 1, ripples = true, curtains = 10, mist = true },
}

-- Rays: at most this many a frame (roofs and ground are cached, so after the first seconds
-- almost none are cast).
local RAYS_PER_FRAME = 48
local SKY_Y = 320 -- rays start here (above the tallest roof)
local RAY_LENGTH = 420
local MAX_CACHED = 30000
-- A known point is cast again after this (a building streamed in, a roof broken); "nothing
-- here" is kept a shorter time.
local SURFACE_TTL = 15
local EMPTY_TTL = 3
-- The camera moved this far in one frame (respawn, teleport): forget the whole map.
local CAMERA_JUMP = 200
-- Parts narrower than this (both ways) are not roofs: the rays go through them.
local SMALL_PROP = 4
-- See-through parts (invisible boxes, small props) a ray may pass before it gives up.
local MAX_PASSES = 6
-- Cells check their roofs again this often (seconds; cached points cost no ray).
local REMEASURE_EVERY = 2
-- The fall a drop is tuned for (camera on the street): a longer fall (camera on a roof) gets
-- a lower rate, so the drops alive stay within the budget.
local BASE_FALL = R.TOP + 5
-- A near cell stops its rain at the highest surface at least this far above its lowest one (a
-- car roof does not count, an awning or a ceiling does).
local ROOF_ABOVE = 7
-- Cells are moved and re-aimed this often (seconds).
local PLACE_EVERY = 1 / 20
-- Splashes: at most this many a frame.
local MAX_SPLASHES_PER_FRAME = 6
-- Curtains: re-placed when the camera moved this far, this tall.
local CURTAIN_MOVE = 25
local CURTAIN_HEIGHT = 150
local CURTAIN_WIDTH = 70
-- Ground mist: puffs per second at full rain, the square it covers.
local MIST_RATE = 3
local MIST_AREA = 90

-- Materials that soak the drops up (no splash crown, no ripple).
local SOFT: { [Enum.Material]: boolean } = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Sand] = true,
	[Enum.Material.Fabric] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Mud] = true,
	[Enum.Material.Snow] = true,
}

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

type Cell = {
	part: Part,
	emitter: ParticleEmitter,
	near: boolean,
	size: number,
	offsetX: number,
	offsetZ: number,
	stopY: number?, -- where the drops die (the first roof or the ground), nil = not known yet
	dirty: boolean,
}

type Surface = {
	y: number,
	soft: boolean,
	flat: boolean,
	time: number, -- os.clock() of the ray
	empty: boolean, -- nothing below (off the map, not streamed in)
}

type Curtain = {
	beam: Beam,
	top: Attachment,
	bottom: Attachment,
	jitter: number, -- fixed angle and distance offsets (no jump when the ring moves)
	spread: number,
	groundY: number?,
	targetY: number?,
}

local folder: Folder
local cells: { Cell } = {}
local groundHost: Part
local groundPoint: Attachment
local splashEmitter: ParticleEmitter
local rippleEmitter: ParticleEmitter
local mistBox: Part
local mistEmitter: ParticleEmitter
local curtainHost: Part
local curtains: { Curtain } = {}

local anchorX: number? = nil
local anchorZ: number? = nil
local curtainCenter: Vector3? = nil
local curtainLevel = -1 -- the transparency step last applied to the curtains
local curtainShown = 0 -- how many curtains were placed
local nextPlace = 0
local nextRemeasure = 0
local lastCamera: Vector3? = nil
local splashBudget = 0
local active = false

-- Height map: the first surface the rain meets at each (whole-stud) point.
local surfaces: { [number]: Surface } = {}
local surfaceCount = 0
local raysLeft = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local nextFilterRefresh = 0

-- Quality.
local savedLevel = 0
local autoTier = 2
local fpsFrames = 0
local fpsTime = 0
local fpsGoodWindows = 0

------------------------------------------------------------------------------
-- Quality
------------------------------------------------------------------------------

local function readQuality()
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	savedLevel = if ok then level.Value else 0
end

local function currentTier(): Tier
	local index = if savedLevel == 0
		then autoTier
		elseif savedLevel <= 3 then 1
		elseif savedLevel <= 7 then 2
		else 3
	-- (a phone or a tablet: at most medium)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		index = math.min(index, 2)
	end
	return TIERS[index]
end

-- "Automatic" quality: every 4 s of rain, step down under 42 fps, step up after 12 s above 57.
local function measureFps(dt: number)
	if savedLevel ~= 0 then
		return
	end
	fpsFrames += 1
	fpsTime += dt
	if fpsTime < 4 then
		return
	end
	local fps = fpsFrames / fpsTime
	fpsFrames, fpsTime = 0, 0
	if fps < 42 and autoTier > 1 then
		autoTier -= 1
		fpsGoodWindows = 0
	elseif fps > 57 then
		fpsGoodWindows += 1
		if fpsGoodWindows >= 3 and autoTier < 3 then
			autoTier += 1
			fpsGoodWindows = 0
		end
	else
		fpsGoodWindows = 0
	end
end

------------------------------------------------------------------------------
-- Height map (where the rain lands)
------------------------------------------------------------------------------

-- Only our own instances and the characters: a short list (see-through parts are not
-- listed, the rays restart just under them).
local function refreshFilter()
	local list: { Instance } = { folder }
	local camera = workspace.CurrentCamera
	if camera then
		table.insert(list, camera)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	rayParams.FilterDescendantsInstances = list
end

local function surfaceKey(x: number, z: number): number
	return (x + 8192) * 16384 + (z + 8192)
end

local function remember(key: number, surface: Surface)
	if surfaces[key] == nil then
		if surfaceCount >= MAX_CACHED then
			table.clear(surfaces)
			surfaceCount = 0
		end
		surfaceCount += 1
	end
	surfaces[key] = surface
end

-- The first surface the rain meets at whole-stud point (x, z), or nil when it is not known
-- (out of rays this frame, nothing there, or not streamed in yet). Old points are cast again;
-- while out of rays, the old value is used.
local function surfaceAt(x: number, z: number): Surface?
	local key = surfaceKey(x, z)
	local known = surfaces[key]
	local now = os.clock()
	if known then
		local ttl = if known.empty then EMPTY_TTL else SURFACE_TTL
		if now - known.time < ttl or raysLeft <= 0 then
			return if known.empty then nil else known
		end
	end
	local fallback = if known and not known.empty then known else nil
	local fromY = SKY_Y
	local bottomY = SKY_Y - RAY_LENGTH
	for _ = 1, MAX_PASSES do
		if raysLeft <= 0 or fromY <= bottomY then
			return fallback
		end
		raysLeft -= 1
		local hit = workspace:Raycast(
			Vector3.new(x, fromY, z),
			Vector3.new(0, bottomY - fromY, 0),
			rayParams
		)
		if hit == nil then
			remember(key, { y = 0, soft = false, flat = false, time = now, empty = true })
			return nil
		end
		local part = hit.Instance
		-- an invisible box, or a small prop (a lamp head, a sign, a bin): look through it (a
		-- cell would otherwise stop its rain at a lamp's height). The next ray starts just
		-- under the hit, so it does not see that part again: nothing is added to the filter.
		local puddle = part:HasTag("CityPuddle")
		local invisible = part:IsA("BasePart") and part.Transparency > 0.95
		local small = part:IsA("BasePart") and part.Size.X < SMALL_PROP and part.Size.Z < SMALL_PROP
		if (invisible or small) and not puddle and not part:IsA("Terrain") then
			fromY = hit.Position.Y - 0.02
			continue
		end
		local surface: Surface = {
			y = hit.Position.Y,
			soft = SOFT[hit.Material] == true,
			flat = hit.Normal.Y > 0.7,
			time = now,
			empty = false,
		}
		-- a character (an NPC) is not part of the city: used, not kept
		local model = part:FindFirstAncestorWhichIsA("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			return surface
		end
		remember(key, surface)
		return surface
	end
	return fallback
end

-- Forgets every known point (respawn, teleport, a new rain event).
local function forgetMap()
	table.clear(surfaces)
	surfaceCount = 0
	for _, cell in cells do
		cell.dirty = true
	end
	for _, curtain in curtains do
		curtain.targetY = nil
	end
end

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

-- An invisible, anchored part nothing touches or hits.
local function hostPart(name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder
	return part
end

-- A size that varies per particle: min..max, the same all its life.
local function sizeRange(range: NumberRange): NumberSequence
	local middle = (range.Min + range.Max) / 2
	local spread = (range.Max - range.Min) / 2
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, middle, spread),
		NumberSequenceKeypoint.new(1, middle, spread),
	})
end

-- Fades in just after birth (no drop pops into the sky), out as it reaches the ground.
local function dropFade(base: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.06, base),
		NumberSequenceKeypoint.new(0.9, base),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function makeCell(near: boolean, offsetX: number, offsetZ: number, size: number): Cell
	local part = hostPart(if near then "NearRain" else "MidRain", Vector3.new(size, 0.2, size))
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Drops"
	emitter.Texture = DROP_IMAGE or SPARKS
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.EmissionDirection = Enum.NormalId.Bottom
	-- along the fall, stretched by a NEGATIVE squash (Roblox's guide for VelocityParallel)
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Squash = NumberSequence.new(R.STRETCH)
	emitter.Size = sizeRange(if near then R.NEAR_SIZE else R.MID_SIZE)
	emitter.Transparency = dropFade(if near then NEAR_TRANSPARENCY else MID_TRANSPARENCY)
	emitter.Color = ColorSequence.new(DROP_COLOR)
	emitter.LightInfluence = DROP_LIGHT_INFLUENCE
	emitter.LightEmission = DROP_LIGHT_EMISSION
	emitter.Speed = NumberRange.new(R.FALL_SPEED)
	emitter.SpreadAngle = Vector2.new(1, 1)
	emitter.Lifetime = NumberRange.new(0.5)
	emitter.Rate = 0
	emitter.Parent = part
	return {
		part = part,
		emitter = emitter,
		near = near,
		size = size,
		offsetX = offsetX,
		offsetZ = offsetZ,
		stopY = nil,
		dirty = true,
	}
end

local function buildCells()
	-- near first: they get their roofs before the mid ones. Each near cell is 2 x 2 emitters
	-- (a roof edge only dries half a cell, never the street right around you).
	local half = R.NEAR_CELL / 2
	for i = -1, 1 do
		for j = -1, 1 do
			for _, a in { -0.5, 0.5 } do
				for _, b in { -0.5, 0.5 } do
					local x = i * R.NEAR_CELL + a * half
					local z = j * R.NEAR_CELL + b * half
					table.insert(cells, makeCell(true, x, z, half))
				end
			end
		end
	end
	-- the mid ring is centred on the middle near cell (its middle cell IS the near cells)
	local step = R.MID_CELL
	for i = -2, 2 do
		for j = -2, 2 do
			if i ~= 0 or j ~= 0 then
				table.insert(cells, makeCell(false, i * step, j * step, step))
			end
		end
	end
end

local function buildGround()
	groundHost = hostPart("RainGround", Vector3.one)
	groundHost.CFrame = CFrame.new()
	groundPoint = Instance.new("Attachment")
	groundPoint.Name = "Hit"
	groundPoint.Parent = groundHost

	-- the splash crown (a 4 x 4 flipbook), or bouncing specks without the picture
	splashEmitter = Instance.new("ParticleEmitter")
	splashEmitter.Name = "Splash"
	splashEmitter.Rate = 0
	splashEmitter.Color = ColorSequence.new(Color3.fromRGB(190, 200, 212))
	splashEmitter.LightInfluence = 0.8
	splashEmitter.LightEmission = 0.15
	splashEmitter.EmissionDirection = Enum.NormalId.Top
	if SPLASH_IMAGE then
		splashEmitter.Texture = SPLASH_IMAGE
		splashEmitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		splashEmitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		splashEmitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		splashEmitter.Speed = NumberRange.new(0)
		splashEmitter.Lifetime = NumberRange.new(0.3, 0.36)
		splashEmitter.Size = sizeRange(NumberRange.new(0.7, 1.2))
		splashEmitter.Transparency = NumberSequence.new(0.15, 0.45)
	else
		splashEmitter.Texture = SPARKS
		splashEmitter.Speed = NumberRange.new(3, 6)
		splashEmitter.SpreadAngle = Vector2.new(60, 60)
		splashEmitter.Acceleration = Vector3.new(0, -45, 0)
		splashEmitter.Lifetime = NumberRange.new(0.15, 0.25)
		splashEmitter.Size = NumberSequence.new(0.14, 0)
		splashEmitter.Transparency = NumberSequence.new(0.35)
	end
	splashEmitter.Parent = groundPoint

	-- a ripple ring lying flat on the wet ground (moving up very slowly, drawn across that)
	rippleEmitter = Instance.new("ParticleEmitter")
	rippleEmitter.Name = "Ripple"
	rippleEmitter.Rate = 0
	rippleEmitter.EmissionDirection = Enum.NormalId.Top
	rippleEmitter.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	rippleEmitter.Speed = NumberRange.new(0.01)
	rippleEmitter.Color = ColorSequence.new(Color3.fromRGB(200, 210, 220))
	rippleEmitter.LightInfluence = 1
	rippleEmitter.LightEmission = 0.1
	rippleEmitter.ZOffset = 0.05
	if RIPPLE_IMAGE then
		rippleEmitter.Texture = RIPPLE_IMAGE
		rippleEmitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		rippleEmitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		rippleEmitter.Lifetime = NumberRange.new(0.55, 0.7)
		rippleEmitter.Size = sizeRange(NumberRange.new(0.8, 1.6))
		rippleEmitter.Transparency = NumberSequence.new(0.35)
	else
		rippleEmitter.Texture = RING
		rippleEmitter.Lifetime = NumberRange.new(0.4, 0.6)
		rippleEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 0.9),
		})
		rippleEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	rippleEmitter.Parent = groundPoint

	-- a thin mist of spray drifting at ground level
	mistBox = hostPart("RainMist", Vector3.new(MIST_AREA, 1, MIST_AREA))
	mistEmitter = Instance.new("ParticleEmitter")
	mistEmitter.Name = "Mist"
	mistEmitter.Texture = SMOKE
	mistEmitter.Shape = Enum.ParticleEmitterShape.Box
	mistEmitter.EmissionDirection = Enum.NormalId.Top
	mistEmitter.Rate = 0
	mistEmitter.Lifetime = NumberRange.new(3, 5)
	mistEmitter.Speed = NumberRange.new(0.3, 1)
	mistEmitter.Rotation = NumberRange.new(0, 360)
	mistEmitter.RotSpeed = NumberRange.new(-10, 10)
	mistEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 6),
		NumberSequenceKeypoint.new(1, 10),
	})
	mistEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.92),
		NumberSequenceKeypoint.new(0.7, 0.92),
		NumberSequenceKeypoint.new(1, 1),
	})
	mistEmitter.Color = ColorSequence.new(Color3.fromRGB(176, 186, 196))
	mistEmitter.LightInfluence = 1
	mistEmitter.Parent = mistBox
end

local function buildCurtains()
	if SHEET_IMAGE == nil then
		return -- (no picture: the haze alone does the distance)
	end
	curtainHost = hostPart("RainCurtains", Vector3.one)
	curtainHost.CFrame = CFrame.new()
	for index = 1, R.CURTAINS do
		local top = Instance.new("Attachment")
		top.Name = "Top" .. index
		top.Parent = curtainHost
		local bottom = Instance.new("Attachment")
		bottom.Name = "Bottom" .. index
		bottom.Parent = curtainHost
		local beam = Instance.new("Beam")
		beam.Name = "Curtain" .. index
		-- the sheet's streaks run along the beam, from the top attachment down
		beam.Attachment0 = top
		beam.Attachment1 = bottom
		beam.Texture = SHEET_IMAGE
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 40
		beam.TextureSpeed = R.CURTAIN_SPEED
		beam.FaceCamera = true
		beam.Width0 = CURTAIN_WIDTH
		beam.Width1 = CURTAIN_WIDTH
		beam.Segments = 1
		beam.LightInfluence = 1
		beam.LightEmission = 0.08
		beam.Color = ColorSequence.new(Color3.fromRGB(185, 195, 208))
		beam.Transparency = NumberSequence.new(1)
		beam.Enabled = false
		beam.Parent = curtainHost
		table.insert(curtains, {
			beam = beam,
			top = top,
			bottom = bottom,
			jitter = random:NextNumber(-0.04, 0.04),
			spread = random:NextNumber(0.85, 1.15),
			groundY = nil,
			targetY = nil,
		})
	end
end

------------------------------------------------------------------------------
-- Every frame
------------------------------------------------------------------------------

-- Finds where the drops of a cell die. Returns false while some of its rays are still to cast.
local function measureCell(cell: Cell, centerX: number, centerZ: number): boolean
	local third = cell.size / 3
	local heights: { number } = {}
	for i = -1, 1 do
		for j = -1, 1 do
			local x = math.round(centerX + i * third)
			local z = math.round(centerZ + j * third)
			local surface = surfaceAt(x, z)
			if surface then
				table.insert(heights, surface.y)
			elseif raysLeft <= 0 then
				return false
			end
			-- (nil with rays left: nothing below, off the map; not counted)
		end
	end
	cell.dirty = false
	if #heights == 0 then
		cell.stopY = nil
		return true
	end
	table.sort(heights)
	-- near: the highest roof (no drop under an awning); mid: the middle value
	local stop = heights[(#heights + 1) // 2]
	if cell.near then
		stop = heights[1]
		for _, height in heights do
			if height - heights[1] >= ROOF_ABOVE then
				stop = height
			end
		end
	end
	cell.stopY = stop
	return true
end

-- Moves the cells to the camera's grid square, aims them along the fall, sets their rates.
local function placeCells(cameraPosition: Vector3, intensity: number, heavy: number, tier: Tier)
	local ax = math.round(cameraPosition.X / R.NEAR_CELL) * R.NEAR_CELL
	local az = math.round(cameraPosition.Z / R.NEAR_CELL) * R.NEAR_CELL
	if ax ~= anchorX or az ~= anchorZ then
		anchorX, anchorZ = ax, az
		for _, cell in cells do
			cell.dirty = true
			cell.stopY = nil -- (its old roof was somewhere else)
		end
	end
	local fall = WeatherController.fallDirection()
	local up = -fall
	local right = Vector3.zAxis:Cross(up).Unit
	local fallY = math.max(-fall.Y, 0.2)
	local verticalSpeed = R.FALL_SPEED * fallY
	local topY = cameraPosition.Y + R.TOP
	for _, cell in cells do
		local centerX, centerZ = ax + cell.offsetX, az + cell.offsetZ
		-- (a re-check out of rays keeps the roof it had)
		if cell.dirty and not measureCell(cell, centerX, centerZ) and cell.stopY == nil then
			cell.emitter.Rate = 0 -- (its roofs are not known yet: no new drops this frame)
			continue
		end
		local stop = cell.stopY
		if stop == nil or stop > topY - 2 then
			cell.emitter.Rate = 0
			continue
		end
		local height = topY - stop
		-- born up-wind, so the slanted drops land on the cell
		local land = Vector3.new(centerX, stop, centerZ)
		local origin = land + up * (height / fallY)
		cell.part.CFrame = CFrame.fromMatrix(origin, right, up)
		local lifetime = height / verticalSpeed
		if math.abs(cell.emitter.Lifetime.Min - lifetime) > 0.01 then
			cell.emitter.Lifetime = NumberRange.new(lifetime)
		end
		local rate = if cell.near then R.NEAR_RATE / 4 * tier.near else R.MID_RATE * tier.mid
		-- a longer fall keeps drops alive longer: fewer of them, the same count on screen
		rate *= math.min(1, BASE_FALL / height)
		cell.emitter.Rate = math.min(MAX_RATE, rate * intensity * heavy)
	end
end

-- The far curtains: a fixed ring around the camera that follows it smoothly (each curtain
-- keeps its own angle and distance), leaning with the wind, fading with the rain. Their
-- ground is looked up again when the camera moved a little, and eased in (no jump).
local function placeCurtains(cameraPosition: Vector3, intensity: number, heavy: number, tier: Tier)
	if #curtains == 0 then
		return
	end
	local shown = math.min(tier.curtains, #curtains)
	local center = curtainCenter
	local moved = center == nil
		or (cameraPosition - center).Magnitude > CURTAIN_MOVE
		or shown ~= curtainShown
	if moved then
		curtainCenter = cameraPosition
		curtainShown = shown
	end
	local fall = WeatherController.fallDirection()
	local fallY = math.max(-fall.Y, 0.2)
	local lean = Vector3.new(fall.X, 0, fall.Z) / fallY * CURTAIN_HEIGHT
	for index, curtain in curtains do
		local on = index <= shown
		curtain.beam.Enabled = on
		if not on then
			continue
		end
		local angle = (index / shown + curtain.jitter) * math.pi * 2
		local distance = R.CURTAIN_RADIUS * curtain.spread
		local x = cameraPosition.X + math.cos(angle) * distance
		local z = cameraPosition.Z + math.sin(angle) * distance
		if moved or curtain.targetY == nil then
			local surface = surfaceAt(math.round(x), math.round(z))
			curtain.targetY = if surface
				then math.min(surface.y, cameraPosition.Y)
				else curtain.targetY or cameraPosition.Y - 10
		end
		local target = curtain.targetY or cameraPosition.Y - 10
		local previous = curtain.groundY
		local groundY: number = if previous then previous + (target - previous) * 0.1 else target
		curtain.groundY = groundY
		curtain.bottom.WorldPosition = Vector3.new(x, groundY - 2, z)
		curtain.top.WorldPosition = curtain.bottom.WorldPosition
			+ Vector3.new(0, CURTAIN_HEIGHT, 0)
			- lean
	end
	-- (the transparency in 20 steps: no new NumberSequence every frame)
	local level = math.floor(math.clamp(intensity * heavy, 0, 1.4) * 20 + 0.5)
	if level ~= curtainLevel then
		curtainLevel = level
		local base = 1 - 0.3 * level / 20
		local fade = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, base),
			NumberSequenceKeypoint.new(0.85, base),
			NumberSequenceKeypoint.new(1, 1),
		})
		for _, curtain in curtains do
			curtain.beam.Transparency = fade
		end
	end
end

-- Splashes and ripples where drops land around the camera (more in front of you).
local function splashes(dt: number, camera: Camera, intensity: number, heavy: number, tier: Tier)
	splashBudget = math.min(splashBudget + R.SPLASHES * tier.splash * intensity * heavy * dt, 12)
	local position = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local count = 0
	while splashBudget >= 1 and count < MAX_SPLASHES_PER_FRAME do
		splashBudget -= 1
		count += 1
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = R.SPLASH_RADIUS * math.sqrt(random:NextNumber())
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		-- (behind you and not close: mirror it to the front, where it is seen)
		if distance > 8 and offset:Dot(look) < 0 then
			offset = -offset
		end
		local x = position.X + offset.X
		local z = position.Z + offset.Z
		local surface = surfaceAt(math.round(x), math.round(z))
		if surface == nil or surface.soft then
			continue
		end
		if surface.y > position.Y + 30 or surface.y < position.Y - 60 then
			continue
		end
		groundPoint.WorldPosition = Vector3.new(x, surface.y + 0.3, z)
		splashEmitter:Emit(if SPLASH_IMAGE then 1 else 2)
		if tier.ripples and surface.flat and random:NextNumber() < 0.45 then
			groundPoint.WorldPosition = Vector3.new(x, surface.y + 0.06, z)
			rippleEmitter:Emit(1)
		end
	end
end

local function stopAll()
	for _, cell in cells do
		cell.emitter.Rate = 0
	end
	mistEmitter.Rate = 0
	for _, curtain in curtains do
		curtain.beam.Enabled = false
		curtain.groundY = nil
		curtain.targetY = nil
	end
	curtainCenter = nil
	curtainLevel = -1
	curtainShown = 0
	splashBudget = 0
	active = false
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local rain, storm, _, indoors = WeatherController.rainState()
	-- the park is always sunny, a duel is an arena: no rain there
	local intensity = rain * (1 - ParkAtmosphereController.blend())
	if player:GetAttribute("InDuel") == true then
		intensity = 0
	end
	if intensity <= 0.001 then
		if active then
			stopAll()
		end
		return
	end
	active = true
	if folder.Parent ~= camera then
		folder.Parent = camera -- (the camera was replaced)
	end
	measureFps(dt)
	raysLeft = RAYS_PER_FRAME
	local now = os.clock()
	if now >= nextFilterRefresh then
		nextFilterRefresh = now + 2
		refreshFilter()
	end

	local tier = currentTier()
	local heavy = if storm then W.STORM_RAIN_MULT else 1
	local position = camera.CFrame.Position
	-- a respawn or a teleport: what we knew may be from before the buildings streamed in
	local last = lastCamera
	if last and (position - last).Magnitude > CAMERA_JUMP then
		forgetMap()
	end
	lastCamera = position
	if now >= nextRemeasure then
		nextRemeasure = now + REMEASURE_EVERY
		for _, cell in cells do
			cell.dirty = true -- (keeps its roof until the new one is known)
		end
	end
	if now >= nextPlace then
		nextPlace = now + PLACE_EVERY
		placeCells(position, intensity, heavy, tier)
		placeCurtains(position, intensity, heavy, tier)
		local under = surfaceAt(math.round(position.X), math.round(position.Z))
		local floorY = if under and under.y <= position.Y then under.y else position.Y - 5
		mistBox.CFrame = CFrame.new(position.X, floorY + 0.5, position.Z)
		mistEmitter.Rate = if tier.mist and not indoors then MIST_RATE * intensity * heavy else 0
	end
	splashes(dt, camera, intensity, heavy, tier)
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function RainController.start()
	folder = Instance.new("Folder")
	folder.Name = "RainField"
	folder.Parent = workspace.CurrentCamera
	buildCells()
	buildGround()
	buildCurtains()
	refreshFilter()
	readQuality()
	pcall(function()
		UserSettings()
			:GetService("UserGameSettings")
			:GetPropertyChangedSignal("SavedQualityLevel")
			:Connect(readQuality)
	end)
	-- a new rain event: forget the old height map (doors, props may have moved)
	workspace:GetAttributeChangedSignal("Weather"):Connect(function()
		if workspace:GetAttribute("Weather") == "Rain" then
			forgetMap()
			refreshFilter()
		end
	end)
	-- a respawn: the city around the new spot may only now be streaming in
	player.CharacterAdded:Connect(function()
		forgetMap()
		refreshFilter()
	end)
	RunService.Heartbeat:Connect(update)
end

return RainController
