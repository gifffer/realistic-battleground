--!strict
-- LensRain: water on the camera "lens" while you stand in the rain (used by WeatherFxController).
--
-- Roblox cannot bend the picture behind a GUI (no refraction), so every drop is a PICTURE of a
-- real water drop (made by tools/raindrops/make_raindrop_textures.py, uploaded by you, ids in
-- Config.Weather.SCREEN_RAIN_IMAGES). While those ids are 0, this module draws NOTHING.
--
-- What it does, like real rain on a camera:
--   • a drop LANDS (it pops in, a bit small, and grows to its size in 0.12 s);
--   • most drops STAY where they are and slowly grow (they gather the fine spray);
--   • two drops that touch MERGE into a bigger one (a "merged" picture);
--   • a drop that got big enough RUNS DOWN: slowly, then faster, wandering a little, with
--     a short wet trail above it (the "streak" picture), and leaves the screen;
--   • in heavy rain a fine MIST of tiny droplets and a faint wet smear fade in at the edges;
--   • under a roof / indoors everything DRIES in a few seconds; in the park or a duel it is
--     wiped at once.
-- Never much in the middle of the screen (the fight is there), at most MAX_DROPS drops.
--
-- Cheap: every label is made once (a pool), nothing is created while playing; each frame
-- only the drops that move or fade are touched.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local IMAGES = Config.Weather.SCREEN_RAIN_IMAGES

local LensRain = {}

local random = Random.new()

------------------------------------------------------------------------------
-- Tuning (sizes and speeds are shares of the SCREEN HEIGHT, so it looks the same on a
-- phone and on a big monitor)
------------------------------------------------------------------------------

local MAX_DROPS = 25
local MAX_TRAILS = 6 -- running drops with a trail at once
-- New drops per second at full rain / in a thunderstorm ("a little" rain on the lens).
local SPAWN_RATE_RAIN = 0.3
local SPAWN_RATE_STORM = 0.8
-- Below this rain level, no new drop lands (a light drizzle does not reach the lens).
local SPAWN_MIN_RAIN = 0.3
-- Size of a new drop (its width).
local SIZE_NEW = NumberRange.new(0.02, 0.048)
-- A drop this big starts to run down; none grows past SIZE_CAP.
local SIZE_RUN = 0.064
local SIZE_CAP = 0.1
-- A still drop grows by this share of its size per second in full rain.
local GROW_PER_SECOND = 0.015
-- Chance per second that a still drop older than 3 s runs down anyway (a gust, a bump).
local EARLY_RUN_CHANCE = 0.02
local LAND_TIME = 0.12
-- Seconds a drop takes to dry once you are under cover (each drop its own).
local DRY_TIME = NumberRange.new(2, 4)
-- Merging and growing are checked this often (not every frame).
local CHECK_EVERY = 0.25
-- Running: acceleration and top speed.
local RUN_ACCEL = 0.45
local RUN_MAX_SPEED = 0.9
-- How visible a drop is at most: its ImageTransparency (picked for each drop).
local TRANSPARENCY = NumberRange.new(0.1, 0.3)
-- The mist and the wet smear: how fast they come (per second, up to 1) and dry.
local MIST_IN = 0.06
local MIST_OUT = 0.35
-- Their strongest look (ImageTransparency at full rain).
local MIST_TRANSPARENCY = 0.3
local MIST2_TRANSPARENCY = 0.45
local WET_TRANSPARENCY = 0.4

-- The streak picture's layout (see the tool): 128 x 512, the drop's centre at y 450, the
-- drop 88 px wide.
local STREAK_W = 128
local STREAK_H = 512
local STREAK_DROP_Y = 450
local STREAK_DROP_W = 88
-- The trail shown above a running drop: at first this much (source pixels), then longer
-- as it runs.
local TRAIL_START = 40
-- A running drop that left the screen: its trail fades out this fast (per second) instead of
-- vanishing at once.
local EXIT_FADE_RATE = 2.5

------------------------------------------------------------------------------
-- Pictures
------------------------------------------------------------------------------

local function urls(ids: { number }): { string }
	local out = {}
	for _, id in ids do
		if id ~= 0 then
			table.insert(out, `rbxassetid://{id}`)
		end
	end
	return out
end

local dropImages = urls(IMAGES.drops)
local mergedImages = urls(IMAGES.merged)
local streakImages = urls(IMAGES.streaks)
local mistImages = urls(IMAGES.mist)
local wetImage = if IMAGES.wet ~= 0 then `rbxassetid://{IMAGES.wet}` else nil

local function pick(list: { string }): string
	return list[random:NextInteger(1, #list)]
end

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

type Drop = {
	label: ImageLabel,
	active: boolean,
	state: string, -- "land", "still" or "run"
	x: number, -- centre, in pixels
	y: number,
	size: number, -- width, in pixels
	visible: number, -- 0 → 1 (1 = shown at its `base` transparency)
	base: number,
	born: number,
	drying: boolean,
	dryRate: number,
	speed: number, -- running: pixels per second
	ran: number, -- running: pixels travelled
	phase: number, -- running: its wander
	trail: ImageLabel?,
}

local gui: ScreenGui? = nil
local drops: { Drop } = {}
local freeTrails: { ImageLabel } = {}
local activeCount = 0
local mistLabels: { ImageLabel } = {}
local wetLabel: ImageLabel? = nil
local mistLevel = 0
local spawnDebt = 0
local nextCheck = 0

-- True once the drop pictures are uploaded (Config ids not 0).
function LensRain.available(): boolean
	return #dropImages > 0
end

local function label(name: string, zIndex: number, parent: Instance): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.ScaleType = Enum.ScaleType.Fit
	image.ResampleMode = Enum.ResamplerMode.Default
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.ImageTransparency = 1
	image.Visible = false
	image.ZIndex = zIndex
	image.Parent = parent
	return image
end

local function sheet(name: string, image: string, zIndex: number, parent: Instance): ImageLabel
	local full = label(name, zIndex, parent)
	full.Image = image
	-- the whole screen, stretched (the pictures are 2:1, close to a 16:9 screen)
	full.ScaleType = Enum.ScaleType.Stretch
	full.Position = UDim2.fromScale(0.5, 0.5)
	full.Size = UDim2.fromScale(1, 1)
	return full
end

-- Makes the screen layer and every label once. Does nothing while the pictures are not
-- uploaded.
function LensRain.build(playerGui: Instance)
	if not LensRain.available() or gui ~= nil then
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "RainOnLens"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = -2 -- under the HUD (0) and the low-health vignette (-1)
	screen.Parent = playerGui
	gui = screen
	local preload: { Instance } = {}
	-- (mist and smear under the drops)
	for index, image in mistImages do
		local mist = sheet(`Mist{index}`, image, 1, screen)
		table.insert(mistLabels, mist)
		table.insert(preload, mist)
	end
	if wetImage then
		wetLabel = sheet("WetGlass", wetImage, 1, screen)
		table.insert(preload, wetLabel :: ImageLabel)
	end
	for index = 1, MAX_DROPS do
		table.insert(drops, {
			label = label(`Drop{index}`, 3, screen),
			active = false,
			state = "still",
			x = 0,
			y = 0,
			size = 0,
			visible = 0,
			base = 0.2,
			born = 0,
			drying = false,
			dryRate = 0.3,
			speed = 0,
			ran = 0,
			phase = 0,
			trail = nil,
		})
	end
	if #streakImages > 0 then
		for index = 1, MAX_TRAILS do
			local trail = label(`Trail{index}`, 2, screen)
			trail.ScaleType = Enum.ScaleType.Stretch
			table.insert(freeTrails, trail)
		end
	end
	-- (download every picture now, so the first drop doesn't pop in late)
	local all: { string } = {}
	for _, list in { dropImages, mergedImages, streakImages } do
		for _, image in list do
			table.insert(all, image)
		end
	end
	for _, image in all do
		local holder = Instance.new("ImageLabel")
		holder.Image = image
		table.insert(preload, holder)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(preload)
		end)
	end)
end

------------------------------------------------------------------------------
-- Drops
------------------------------------------------------------------------------

local function screenSize(): Vector2
	return if gui then gui.AbsoluteSize else Vector2.new(1920, 1080)
end

-- How much a point may get a drop: 0 in the middle of the screen, 1 near the edges.
local function edgeWeight(x: number, y: number): number
	local dx = (x - 0.5) / 0.5
	local dy = (y - 0.5) / 0.5
	local distance = math.sqrt(dx * dx * 0.9 + dy * dy * 0.6)
	return math.clamp((distance - 0.35) / 0.45, 0.03, 1)
end

-- A point on the screen (shares), likelier near the edges, almost never in the middle.
local function landingPoint(): (number, number)
	local x, y = 0.5, 0.1
	for _ = 1, 8 do
		x = random:NextNumber(0.03, 0.97)
		y = random:NextNumber(0.03, 0.9)
		if random:NextNumber() < edgeWeight(x, y) then
			break
		end
	end
	return x, y
end

local function draw(drop: Drop)
	local image = drop.label
	image.Position = UDim2.fromOffset(drop.x, drop.y)
	image.Size = UDim2.fromOffset(drop.size, drop.size)
	image.ImageTransparency = 1 - (1 - drop.base) * drop.visible
end

local function releaseTrail(drop: Drop)
	local trail = drop.trail
	if trail then
		trail.Visible = false
		table.insert(freeTrails, trail)
		drop.trail = nil
	end
end

local function free(drop: Drop)
	drop.active = false
	drop.label.Visible = false
	releaseTrail(drop)
	activeCount -= 1
end

local function spawnDrop(height: number, width: number)
	if activeCount >= MAX_DROPS then
		return
	end
	local drop: Drop? = nil
	for _, candidate in drops do
		if not candidate.active then
			drop = candidate
			break
		end
	end
	if drop == nil then
		return
	end
	local x, y = landingPoint()
	drop.active = true
	drop.state = "land"
	drop.x = x * width
	drop.y = y * height
	drop.size = random:NextNumber(SIZE_NEW.Min, SIZE_NEW.Max) * height
	drop.visible = 0
	drop.base = random:NextNumber(TRANSPARENCY.Min, TRANSPARENCY.Max)
	drop.born = os.clock()
	drop.drying = false
	drop.dryRate = 1 / random:NextNumber(DRY_TIME.Min, DRY_TIME.Max)
	drop.speed = 0
	drop.ran = 0
	drop.phase = random:NextNumber(0, math.pi * 2)
	local image = drop.label
	image.Image = pick(dropImages)
	-- (a small tilt only: the highlight of the picture stays top-left, like the light)
	image.Rotation = random:NextNumber(-18, 18)
	image.Visible = true
	activeCount += 1
	draw(drop)
end

local function startRunning(drop: Drop, height: number)
	drop.state = "run"
	drop.speed = 0.03 * height
	drop.ran = 0
	local trail = table.remove(freeTrails)
	if trail then
		trail.Image = pick(streakImages)
		trail.Rotation = 0
		trail.Visible = true
		drop.trail = trail
	end
	drop.label.Rotation = random:NextNumber(-4, 4)
end

-- The running drop's trail: the bottom part of the streak picture (its drop over ours),
-- longer as the drop runs. While the trail fades in, the round drop fades out.
local function drawTrail(drop: Drop)
	local trail = drop.trail
	if trail == nil then
		return
	end
	local width = drop.size * STREAK_W / STREAK_DROP_W
	local below = STREAK_H - STREAK_DROP_Y
	local shown = math.clamp(below + TRAIL_START + drop.ran * STREAK_W / width, 0, STREAK_H)
	trail.ImageRectOffset = Vector2.new(0, STREAK_H - shown)
	trail.ImageRectSize = Vector2.new(STREAK_W, shown)
	trail.Size = UDim2.fromOffset(width, shown * width / STREAK_W)
	trail.AnchorPoint = Vector2.new(0.5, (shown - below) / shown)
	trail.Position = UDim2.fromOffset(drop.x, drop.y)
	trail.ImageTransparency = 1 - (1 - drop.base * 0.6) * drop.visible
end

-- Puts a drop (and its trail, if it runs) on the screen as it is now.
local function render(drop: Drop)
	draw(drop)
	if drop.trail then
		-- (the round drop fades out as the streak's own drop takes its place)
		local cross = math.clamp(drop.ran / (0.4 * drop.size), 0, 1)
		drop.label.ImageTransparency = 1 - (1 - drop.base) * drop.visible * (1 - cross)
		drawTrail(drop)
	end
end

-- Four times a second: still drops grow; a big drop starts to run.
local function check(rain: number, height: number)
	local grow = 1 + GROW_PER_SECOND * CHECK_EVERY * rain
	local now = os.clock()
	for _, drop in drops do
		if not drop.active or drop.state ~= "still" or drop.drying then
			continue
		end
		if rain > 0 then
			drop.size = math.min(drop.size * grow, SIZE_CAP * height)
			draw(drop)
		end
		local early = now - drop.born > 3 and random:NextNumber() < EARLY_RUN_CHANCE * CHECK_EVERY
		if drop.size >= SIZE_RUN * height or early then
			startRunning(drop, height)
		end
	end
end

-- Every frame (a running drop moves fast: checked less often, it would jump over the drops in
-- its way): two drops that touch become one.
local function merge(height: number)
	for i = 1, MAX_DROPS do
		local a = drops[i]
		if not a.active or a.state == "land" then
			continue
		end
		for j = i + 1, MAX_DROPS do
			local b = drops[j]
			if not b.active or b.state == "land" or not a.active then
				continue
			end
			local dx, dy = a.x - b.x, a.y - b.y
			local reach = (a.size + b.size) * 0.4
			if dx * dx + dy * dy > reach * reach then
				continue
			end
			-- the bigger one (or the running one) keeps going; the volumes add up
			local keep, gone = a, b
			if b.state == "run" and a.state ~= "run" or (b.size > a.size and a.state ~= "run") then
				keep, gone = b, a
			end
			local total = keep.size ^ 3 + gone.size ^ 3
			if keep.state ~= "run" then
				local wa, wb = keep.size ^ 3 / total, gone.size ^ 3 / total
				keep.x = keep.x * wa + gone.x * wb
				keep.y = keep.y * wa + gone.y * wb
				if #mergedImages > 0 then
					keep.label.Image = pick(mergedImages)
				end
			end
			keep.size = math.min(total ^ (1 / 3) * 1.08, SIZE_CAP * height)
			keep.visible = math.max(keep.visible, gone.visible)
			keep.drying = keep.drying and gone.drying
			free(gone)
			render(keep)
		end
	end
end

-- Everything off at once (the park, a duel).
local function wipe()
	for _, drop in drops do
		if drop.active then
			free(drop)
		end
	end
	mistLevel = 0
	for _, mist in mistLabels do
		mist.Visible = false
	end
	if wetLabel then
		wetLabel.Visible = false
	end
end

local function drawMist()
	local shown = mistLevel > 0.002
	for index, mist in mistLabels do
		-- (the second, denser sheet only in heavy rain)
		local level = if index == 1 then mistLevel else math.clamp(mistLevel * 2 - 1, 0, 1)
		local strongest = if index == 1 then MIST_TRANSPARENCY else MIST2_TRANSPARENCY
		mist.Visible = shown and level > 0.002
		mist.ImageTransparency = 1 - (1 - strongest) * level
	end
	if wetLabel then
		wetLabel.Visible = shown
		wetLabel.ImageTransparency = 1 - (1 - WET_TRANSPARENCY) * mistLevel
	end
end

-- Every frame. `rain` = the rain falling on the lens (0 → 1; 0 under a roof or indoors: what
-- is there dries), `storm` = a thunderstorm, `clear` = wipe everything at once (park, duel).
function LensRain.step(dt: number, rain: number, storm: boolean, clear: boolean)
	if gui == nil then
		return
	end
	if clear then
		if activeCount > 0 or mistLevel > 0 then
			wipe()
		end
		spawnDebt = 0
		return
	end
	local size = screenSize()
	local width, height = size.X, size.Y
	if height < 1 then
		return
	end
	local now = os.clock()

	-- new drops
	if rain >= SPAWN_MIN_RAIN then
		spawnDebt += dt * rain * (if storm then SPAWN_RATE_STORM else SPAWN_RATE_RAIN)
		while spawnDebt >= 1 do
			spawnDebt -= 1
			spawnDrop(height, width)
		end
	else
		spawnDebt = 0
	end

	-- the drops that move or fade
	if activeCount > 0 then
		local dry = rain <= 0.02
		for _, drop in drops do
			if not drop.active then
				continue
			end
			local changed = false
			if dry and not drop.drying then
				drop.drying = true
			end
			if drop.state == "land" then
				local t = math.min((now - drop.born) / LAND_TIME, 1)
				local ease = 1 - (1 - t) * (1 - t)
				drop.visible = ease
				drop.label.Size =
					UDim2.fromOffset(drop.size * (0.6 + 0.4 * ease), drop.size * (0.6 + 0.4 * ease))
				drop.label.ImageTransparency = 1 - (1 - drop.base) * drop.visible
				if t >= 1 then
					drop.state = "still"
					changed = true
				end
			elseif drop.state == "run" then
				local scale = math.clamp(drop.size / (SIZE_RUN * height), 0.6, 1.4)
				drop.speed =
					math.min(drop.speed + RUN_ACCEL * height * scale * dt, RUN_MAX_SPEED * height)
				local step = drop.speed * dt
				drop.y += step
				drop.ran += step
				-- a little wander from side to side (water finds its way)
				drop.x += math.sin(drop.ran / height * 18 + drop.phase) * step * 0.12
				changed = true
				if drop.y - drop.size > height then
					-- off the screen: without a trail it is gone; its trail fades out quickly
					if drop.trail == nil or drop.y - drop.size > height * 3 then
						free(drop)
						continue
					end
					drop.drying = true
					drop.dryRate = math.max(drop.dryRate, EXIT_FADE_RATE)
				end
			end
			if drop.drying then
				drop.visible -= drop.dryRate * dt
				drop.size *= 1 - 0.08 * dt -- (it shrinks a little as it dries)
				changed = true
				if drop.visible <= 0 then
					free(drop)
					continue
				end
			end
			if changed and drop.state ~= "land" then
				render(drop)
			end
		end
		if now >= nextCheck then
			nextCheck = now + CHECK_EVERY
			check(rain, height)
		end
		merge(height)
	end

	-- the mist and the wet smear: they come slowly in heavy rain, and dry quickly
	local target = math.clamp((rain - 0.4) / 0.6, 0, 1) * (if storm then 1 else 0.6)
	if target ~= mistLevel then
		local rate = if target > mistLevel then MIST_IN else MIST_OUT
		mistLevel = if target > mistLevel
			then math.min(mistLevel + rate * dt, target)
			else math.max(mistLevel - rate * dt, target)
		drawMist()
	end
end

return LensRain
