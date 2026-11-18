--!strict
-- BloodAge: how every mark of blood ages, in ONE place (client-side).
--
-- Real blood changes after it lands: glossy bright red at first, dark red a
-- few seconds later, then it thickens (a dark ring forms at its edge: it
-- clots), turns matte and finally a brown-black crust. Thin films go faster
-- than thick pools, and blood soaks into rough ground (concrete, asphalt,
-- wood) and dries there sooner than on smooth metal or plastic.
--
-- Instead of 2 tweens + a timer + Debris per piece (what the old code did),
-- every mark is a small "record" in one list, and ONE Heartbeat updates a few
-- of them each frame, in turn (round-robin): each mark is refreshed several
-- times a second, plenty for something that dries over a minute.
--
-- It also keeps the CAPS (Config.Blood.CAPS, scaled by the graphics quality):
-- past the cap of its kind, the oldest mark fades out in 0.3 s. Pools and
-- finisher marks are "pinned": the small spatter goes first.
--
--   BloodAge.add(record)          start ageing a mark (see Record below)
--   BloodAge.layer(instance, shade, alpha, rim?)  one painted piece of a mark
--   BloodAge.touch(record)        fresh blood fed into it again (wet again)
--   BloodAge.releaseOwner(model)  a body is gone: its marks go too
--   BloodAge.scale()              0.4 / 0.7 / 1: the quality (caps × this)
--   BloodAge.mix(a, b, t)         blends two colours the way light does
--   BloodAge.ageColor(start, profile, t)   the colour of blood `t` s old
--   BloodAge.night()              0 (day) → 1 (night): at night blood shows by
--                                 its sheen (darker colour, stronger gloss)

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local BloodAge = {}

local PALETTE = Config.Blood.PALETTE
BloodAge.PALETTE = PALETTE
local CAPS = Config.Blood.CAPS

export type Profile = {
	fresh: number,
	clot: number,
	dry: number,
	life: number,
	gloss: number,
	glossEnd: number,
}

-- One painted piece of a mark: a Decal (its Color3 tints the picture) or a
-- Part (a plain shape, the fallback without pictures).
--   shade  > 0 darker (thick blood), < 0 lighter (a thin film)
--   alpha  its own transparency when fresh
--   rim    the dark clotting ring: invisible at first, it appears as it clots
--   shiny  (a Part) it gets the wet Reflectance itself
export type Layer = {
	inst: Instance,
	isDecal: boolean,
	shade: number,
	alpha: number,
	rim: boolean,
	shiny: boolean,
	shineMax: number, -- (its Reflectance at most: more turns it pink)
	shineScale: number,
	-- (true: its Transparency belongs to its own module - a wound part that
	-- fades out with its bruise - ageing only changes its colour and sheen)
	keepAlpha: boolean?,
	-- (v2, all optional)
	color: Color3?, -- a fixed tint (it doesn't age: the pale serum ring)
	showFrom: number?, -- invisible until this age (s), then fades in...
	showFull: number?, -- ...fully shown (its `alpha`) at this age
	gel: number?, -- darker by this much once clotted (a pool's thick middle)
}

export type Record = {
	layers: { Layer },
	anchor: Instance, -- the carrier: when it is gone (destroyed with a body), so is the mark
	gloss: BasePart?, -- a wet shiny film over it (pools)
	glossAlpha: number,
	start: Color3, -- its colour at t = 0
	dryColor: Color3?, -- (cloth: dries toward this instead of the palette)
	born: number,
	profile: Profile,
	speed: number, -- > 1: dries faster (rough, porous ground)
	soakIn: number, -- added transparency (soaked into the ground)
	life: number,
	category: string, -- "stain" (floor / walls), "body", "foot", "wound" (no cap)
	owner: Model?,
	pinned: boolean, -- (pools, finisher marks: evicted last)
	fadeStart: number?, -- being removed (past a cap): fades in 0.3 s
	weight: number?, -- how much of the cap it takes (a mark of many plain shapes: more)
	dead: boolean,
	release: ((Record) -> ())?, -- gives its pieces back (else they are destroyed)
	-- (filled in by BloodAge itself)
	counted: boolean?, -- still counts in its kind's cap (not fading out)
	nextPaint: number?, -- (an old, dry mark is repainted less often)
	-- (v2) called at each paint with its age `t` (s): a pool's wet film
	-- shrinking toward its middle as it dries
	reshape: ((Record, number) -> ())?,
}

------------------------------------------------------------------------------
-- Colours (blended in linear light: the darkening doesn't go muddy too soon)
------------------------------------------------------------------------------

function BloodAge.mix(a: Color3, b: Color3, t: number): Color3
	t = math.clamp(t, 0, 1)
	local r = a.R * a.R + (b.R * b.R - a.R * a.R) * t
	local g = a.G * a.G + (b.G * b.G - a.G * a.G) * t
	local bl = a.B * a.B + (b.B * b.B - a.B * a.B) * t
	return Color3.new(math.sqrt(r), math.sqrt(g), math.sqrt(bl))
end
local mix = BloodAge.mix

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The colour of blood that started as `start`, `t` seconds old.
function BloodAge.ageColor(start: Color3, profile: Profile, t: number): Color3
	if t < profile.fresh then
		return mix(start, PALETTE.VENOUS, smooth(t / profile.fresh))
	end
	if t < profile.clot then
		return mix(
			PALETTE.VENOUS,
			PALETTE.CLOTTED,
			(t - profile.fresh) / (profile.clot - profile.fresh)
		)
	end
	if t < profile.dry then
		local u = (t - profile.clot) / math.max(profile.dry - profile.clot, 1e-3)
		return if u < 0.5
			then mix(PALETTE.CLOTTED, PALETTE.DRYING, u * 2)
			else mix(PALETTE.DRYING, PALETTE.DRY, u * 2 - 1)
	end
	local span = if profile.life == math.huge then 240 else math.max(profile.life - profile.dry, 1)
	return mix(PALETTE.DRY, PALETTE.OLD, (t - profile.dry) / span)
end

-- (thick blood: near black; a thin film: lighter, a little more orange)
local function shaded(color: Color3, shade: number): Color3
	if shade > 0 then
		return mix(color, PALETTE.GLOSS, shade)
	elseif shade < 0 then
		local light = Color3.new(math.min(1, color.R * 1.45), color.G * 1.5, color.B * 1.35)
		return mix(color, light, -shade)
	end
	return color
end

------------------------------------------------------------------------------
-- Quality: the caps follow the player's graphics setting
------------------------------------------------------------------------------

local qualityScale = 1
local nextQualityCheck = 0
local nightAmount = 0 -- 0 day → 1 night (read every 5 s)

-- Night: before 6:30 or after 18:30 (half an hour to fade between the two).
local function readNight(): number
	local clock = Lighting.ClockTime
	local past = math.max(6.5 - clock, clock - 18.5) -- (> 0: night, < 0: day)
	return math.clamp(past / 0.5 + 1, 0, 1)
end

function BloodAge.night(): number
	return nightAmount
end

local function readQuality(): number
	local wanted = Config.Blood.QUALITY
	if wanted == "Low" then
		return 0.4
	elseif wanted == "Medium" then
		return 0.7
	elseif wanted == "High" then
		return 1
	end
	-- "Auto": the graphics slider (1-10) the player chose in Roblox's menu
	local ok, level = pcall(function(): number
		local settings = UserSettings():GetService("UserGameSettings")
		return settings.SavedQualityLevel.Value
	end)
	if not ok or level == 0 then
		return 0.7 -- ("Automatic": somewhere in the middle)
	elseif level <= 3 then
		return 0.4
	elseif level <= 7 then
		return 0.7
	end
	return 1
end

function BloodAge.scale(): number
	return qualityScale
end

-- A cap of Config.Blood.CAPS, at this client's quality.
function BloodAge.cap(name: string): number
	local value = (CAPS :: any)[name]
	return math.max(
		1,
		math.floor((if typeof(value) == "number" then value else 100) * qualityScale)
	)
end

------------------------------------------------------------------------------
-- Records
------------------------------------------------------------------------------

local all: { Record } = {}
local cursor = 1
local byCategory: { [string]: { Record } } = {}
local byOwner: { [Model]: { Record } } = {}
-- How much of its cap each kind takes now (kept up to date as marks come and
-- go: no need to count the whole list for every new mark).
local liveWeight: { [string]: number } = {}

local CATEGORY_CAP: { [string]: string } = {
	stain = "STAINS",
	body = "BODY",
	foot = "FOOTPRINTS",
}

function BloodAge.layer(inst: Instance, shade: number, alpha: number, rim: boolean?): Layer
	return {
		inst = inst,
		isDecal = inst:IsA("Decal"),
		shade = shade,
		alpha = alpha,
		rim = rim == true,
		shiny = false,
		shineMax = 0.12,
		shineScale = 0.5,
	}
end

local function destroyPieces(record: Record)
	for _, layer in record.layers do
		layer.inst:Destroy()
	end
	if record.gloss then
		record.gloss:Destroy()
	end
	record.anchor:Destroy()
end

-- It stops counting in its cap (it fades out, or it's gone).
local function uncount(record: Record)
	if record.counted then
		record.counted = false
		liveWeight[record.category] = (liveWeight[record.category] or 0) - (record.weight or 1)
	end
end

local function removeFrom(list: { Record }?, record: Record)
	if list then
		local index = table.find(list, record)
		if index then
			table.remove(list, index)
		end
	end
end

-- Gone for good: off its lists, its pieces given back.
local function finish(record: Record)
	if record.dead then
		return
	end
	record.dead = true
	uncount(record)
	removeFrom(byCategory[record.category], record)
	local owner = record.owner
	if owner then
		local list = byOwner[owner]
		removeFrom(list, record)
		if list and #list == 0 then
			byOwner[owner] = nil
		end
	end
	if record.anchor.Parent == nil and record.release == nil then
		return -- (already destroyed with what it was on)
	end
	local release = record.release
	if release then
		release(record)
	else
		destroyPieces(record)
	end
end

local function startFade(record: Record)
	record.fadeStart = os.clock()
	record.nextPaint = 0 -- (repainted every pass while it fades)
	uncount(record)
end

-- The oldest of `list` that may go (not pinned, if possible) fades out.
-- false: nothing left to remove.
local function evictOldest(list: { Record }): boolean
	local fallback: Record? = nil
	for index = 1, math.min(#list, 128) do
		local record = list[index]
		if record.fadeStart == nil and not record.dead then
			if not record.pinned then
				startFade(record)
				return true
			end
			fallback = fallback or record
		end
	end
	if fallback then
		startFade(fallback)
		return true
	end
	return false
end

-- How much of its cap a (short) list takes: the marks not fading out.
local function countLive(list: { Record }): number
	local count = 0
	for _, record in list do
		if record.fadeStart == nil and not record.dead then
			count += record.weight or 1
		end
	end
	return count
end

-- Past `cap`: the oldest go (a few at most per new mark).
local function trimCategory(list: { Record }, category: string, cap: number)
	local tries = 0
	while (liveWeight[category] or 0) > cap and tries < 8 do
		if not evictOldest(list) then
			break
		end
		tries += 1
	end
end

local function trimOwner(list: { Record }, cap: number)
	local tries = 0
	while countLive(list) > cap and tries < 6 do
		if not evictOldest(list) then
			break
		end
		tries += 1
	end
end

function BloodAge.add(record: Record)
	table.insert(all, record)
	local list = byCategory[record.category]
	if list == nil then
		list = {}
		byCategory[record.category] = list
	end
	table.insert(list, record)
	record.counted = true
	liveWeight[record.category] = (liveWeight[record.category] or 0) + (record.weight or 1)
	local capName = CATEGORY_CAP[record.category]
	if capName then
		-- (weighted: a mark of many plain shapes takes more of the cap)
		trimCategory(list, record.category, BloodAge.cap(capName))
	end
	local owner = record.owner
	if owner then
		local mine = byOwner[owner]
		if mine == nil then
			mine = {}
			byOwner[owner] = mine
		end
		table.insert(mine, record)
		if record.category == "body" then
			trimOwner(mine, BloodAge.cap("BODY_PER_CHARACTER"))
		end
	end
end

-- A plain Part of blood (a wound's blood, a trickle under a shard) that
-- should age too: darkening, losing its shine. Not counted in the caps; it
-- goes when the part is destroyed.
-- `shade` > 0: thick blood (darker than the palette's colour of its age).
function BloodAge.track(part: BasePart, profileName: string, start: Color3?, shade: number?): Record
	local profile = (Config.Blood.PROFILES :: any)[profileName] or Config.Blood.PROFILES.wound
	local layer = BloodAge.layer(part, shade or 0, part.Transparency)
	layer.keepAlpha = true
	layer.shiny = true
	layer.shineMax = profile.gloss
	layer.shineScale = 1
	local record: Record = {
		layers = { layer },
		anchor = part,
		gloss = nil,
		glossAlpha = 1,
		start = start or part.Color,
		dryColor = nil,
		born = os.clock(),
		profile = profile,
		speed = 1,
		soakIn = 0,
		life = math.huge,
		category = "wound",
		owner = nil,
		pinned = true,
		fadeStart = nil,
		dead = false,
		release = nil,
	}
	BloodAge.add(record)
	return record
end

-- Fresh blood fed into it again (a pool still being fed): wet and red again.
function BloodAge.touch(record: Record)
	local now = os.clock()
	local wetAge = record.profile.fresh * 0.5 / record.speed
	if now - record.born > wetAge then
		record.born = now - wetAge
	end
	record.nextPaint = 0
end

-- How wet it still is (1 just landed → 0 dry): footprints take wet blood only.
function BloodAge.wetness(record: Record): number
	local t = (os.clock() - record.born) * record.speed
	return 1 - smooth(t / record.profile.dry)
end

-- Removes it now (no fade).
function BloodAge.remove(record: Record)
	finish(record)
end

-- A body is gone (removed, respawned): every mark ON it goes.
function BloodAge.releaseOwner(model: Model)
	local list = byOwner[model]
	if list == nil then
		return
	end
	byOwner[model] = nil
	for _, record in table.clone(list) do
		if record.category ~= "stain" and record.category ~= "foot" then
			record.owner = nil
			finish(record)
		end
	end
end

-- Paints one record for its age.
local function paint(record: Record, now: number)
	local profile = record.profile
	local real = now - record.born
	local t = real * record.speed
	-- end of its life: fades out the last 15 % (or 0.3 s when evicted)
	local fade = 0
	if record.fadeStart then
		fade = math.clamp((now - record.fadeStart) / 0.3, 0, 1)
	elseif record.life < math.huge then
		fade = math.clamp((real - record.life * 0.85) / (record.life * 0.15), 0, 1)
	end
	if fade >= 1 then
		finish(record)
		return
	end
	local dryColor = record.dryColor
	local color = if dryColor
		then mix(record.start, dryColor, smooth(t / profile.dry))
		else BloodAge.ageColor(record.start, profile, t)
	local wet = 1 - smooth(t / math.max(profile.glossEnd, 1e-3))
	local shine = profile.gloss * wet
	local night = nightAmount
	if night > 0 then
		-- (at night fresh blood looks nearly black and shows by its sheen)
		color =
			mix(color, PALETTE.GLOSS, 0.15 * night * (1 - smooth(t / math.max(profile.clot, 1))))
		shine = math.min(shine * (1 + 0.4 * night), 0.35)
	end
	local rimIn = smooth((t - profile.clot * 0.4) / math.max(profile.clot * 0.6, 1e-3))
	local clotted = smooth((t - profile.clot) / math.max(profile.dry - profile.clot, 1e-3))
	local reshape = record.reshape
	if reshape then
		reshape(record, t)
	end
	for _, layer in record.layers do
		local inst = layer.inst
		local alpha = layer.alpha + record.soakIn
		if layer.rim then
			alpha = 1 - (1 - alpha) * rimIn
		end
		local showFrom = layer.showFrom
		if showFrom then
			-- (appears late: invisible before `showFrom`, its alpha at `showFull`)
			local full = layer.showFull or (showFrom + 1)
			alpha = 1 - (1 - alpha) * smooth((t - showFrom) / math.max(full - showFrom, 1e-3))
		end
		alpha = alpha + (1 - alpha) * fade
		local shade = layer.shade + (layer.gel or 0) * clotted
		local c = layer.color or shaded(color, shade)
		if layer.isDecal then
			local decal = inst :: Decal
			decal.Color3 = c
			decal.Transparency = alpha
		else
			local part = inst :: BasePart
			part.Color = c
			if not layer.keepAlpha then
				part.Transparency = alpha
			end
			if layer.shiny then
				-- (a plain shape: a little sheen of its own; more turns it pink)
				part.Reflectance = math.min(layer.shineMax, shine * layer.shineScale)
			end
		end
	end
	local gloss = record.gloss
	if gloss then
		local glossAlpha = record.glossAlpha + (1 - record.glossAlpha) * (1 - wet)
		glossAlpha = math.max(0, glossAlpha - 0.1 * night * wet) -- (stronger at night)
		gloss.Transparency = glossAlpha + (1 - glossAlpha) * fade
		gloss.Reflectance = shine
	end
end
BloodAge.paint = function(record: Record)
	paint(record, os.clock())
end

-- How soon it needs painting again: every pass while it changes quickly
-- (fresh, clotting, fading out), less and less often once it's dry (its
-- colour then creeps over minutes; repainting hundreds of dry marks every
-- frame would cost for nothing).
local function repaintDelay(record: Record, now: number): number
	if record.fadeStart then
		return 0
	end
	local real = now - record.born
	if record.life < math.huge and real > record.life * 0.85 - 1 then
		return 0 -- (fading out at the end of its life)
	end
	local t = real * record.speed
	local profile = record.profile
	if t < profile.clot then
		return 0
	elseif t < profile.dry then
		return 0.3
	end
	return 1.5
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now >= nextQualityCheck then
		nextQualityCheck = now + 5
		qualityScale = readQuality()
		nightAmount = readNight()
	end
	debug.profilebegin("BloodAge")
	-- (looks at up to 4 × AGE_PER_FRAME marks, paints at most AGE_PER_FRAME)
	local visits = math.min(#all, CAPS.AGE_PER_FRAME * 4)
	local paints = CAPS.AGE_PER_FRAME
	while visits > 0 and paints > 0 and #all > 0 do
		if cursor > #all then
			cursor = 1
		end
		local record = all[cursor]
		if not record.dead and record.anchor.Parent == nil then
			-- (destroyed with what it was on: the body, a moving part)
			finish(record)
		end
		if not record.dead and now >= (record.nextPaint or 0) then
			paint(record, now)
			paints -= 1
			if not record.dead then
				record.nextPaint = now + repaintDelay(record, now)
			end
		end
		if record.dead then
			-- (swap with the last: no gap in the list)
			all[cursor] = all[#all]
			all[#all] = nil
		else
			cursor += 1
		end
		visits -= 1
	end
	debug.profileend()
end)

return table.freeze(BloodAge)
