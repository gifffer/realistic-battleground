--!strict
-- FaultyLightController: tired, aging lights (the alleys' wall lights, a bare bulb...).
--
-- A light part opts in with the attribute Faulty = a number 0..1 (how bad it is) and the tag
-- "CityFaulty" (Server/Systems/Ambience adds the tag by itself to every part of the city that
-- has the attribute, so the city data only needs the attribute). Its light is the child named
-- "Light" (or else its first Light child). While that light is ON, this controller lays on top:
--   • a slow, small, irregular DRIFT of the intensity (two layers of smooth noise, a few %);
--   • now and then a short DIP (the bulb sags to 30-65 % for a quarter of a second to a second,
--     then crawls back) or a very brief CUT-OUT (off for 50 to 140 ms, sometimes twice in a
--     row, then back a little dim and warming up). A few per minute, never two seconds in a
--     row: no strobing;
--   • rarely a longer BROWN-OUT: a slow sag over 2 to 4 s.
-- The bulb part's glow (its Color) follows the light.
--
-- Everything on/off stays the SERVER's business (Ambience: day / night, power cuts, Dead...):
-- while the light is disabled this controller touches nothing. It only scales what the server
-- set, with the same trick as ParkAtmosphereController: a value that differs from what we wrote
-- last frame was changed by the server (a power-restore warm-up tween, a lamp switched off...)
-- and becomes the new base. When a light goes off, out of range or loses its Faulty
-- attribute, the server's values are written back.
--
-- Same picture for every player: the noise is a pure function of the server's clock
-- (workspace:GetServerTimeNow()) and of a seed made from the part's position (or its
-- attribute FaultySeed, an integer). No network traffic, no thread per light: one Heartbeat
-- loop for all of them, only for those near the camera (StreamingEnabled already drops the far
-- ones).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local FaultyLightController = {}

local TAG = "CityFaulty"
-- Lights farther than this from the camera are left alone (studs).
local RANGE = 260
-- Length of a slot of the event timeline (s): at most one dip / cut-out per slot.
local EVENT_SLOT = 1
-- Events per minute at Faulty = 0 (+) and the extra at Faulty = 1.
local EVENTS_MIN = 0.8
local EVENTS_EXTRA = 5.2
-- Brown-outs: one slot of BROWN_SLOT seconds has this chance (× Faulty) of a slow sag.
local BROWN_SLOT = 15
local BROWN_CHANCE = 0.3
-- Drift amplitude at Faulty = 1 (share of the brightness).
local DRIFT_SLOW = 0.1
local DRIFT_FAST = 0.045
-- The glow of the bulb part when the light is fully cut (share of its colour).
local GLOW_FLOOR = 0.18

------------------------------------------------------------------------------
-- Deterministic noise (integer hash: the same on every computer)
------------------------------------------------------------------------------

local TWO32 = 4294967296

-- a * b modulo 2^32, exact with doubles (both < 2^32).
local function mul32(a: number, b: number): number
	local low, high = a % 65536, a // 65536
	return (low * b + ((high * b) % 65536) * 65536) % TWO32
end

-- 0..1 from a seed, a channel and an integer slot (a murmur3-style finaliser).
local function hash(seed: number, channel: number, slot: number): number
	local h = bit32.bxor(seed, mul32(slot % TWO32, 0x9E3779B1), mul32(channel, 0x632BE5AB))
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xC2B2AE35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h / TWO32
end

-- Smooth value noise in -1..1 (`t` in "cells").
local function smoothNoise(seed: number, channel: number, t: number): number
	local cell = math.floor(t)
	local f = t - cell
	f = f * f * (3 - 2 * f)
	local a = hash(seed, channel, cell)
	local b = hash(seed, channel, cell + 1)
	return (a + (b - a) * f) * 2 - 1
end

-- Brightness factor (1 = untouched) of the dip / cut-out drawn in event slot `slot`, at
-- `local` seconds after that slot started.
local function eventFactor(seed: number, chance: number, slot: number, at: number): number
	if hash(seed, 1, slot) >= chance then
		return 1
	end
	-- Never two slots in a row: no strobing.
	if hash(seed, 1, slot - 1) < chance then
		return 1
	end
	local kind = hash(seed, 2, slot)
	local r1, r2, r3 = hash(seed, 3, slot), hash(seed, 4, slot), hash(seed, 5, slot)
	if kind < 0.55 then
		-- DIP: a fast sag, a hold with a little wobble, a slower crawl back.
		local depth = 0.35 + 0.35 * r1
		local hold = 0.15 + 0.5 * r2
		local start = r3 * (EVENT_SLOT - hold - 0.05) * 0.6
		local t = at - start
		if t < 0 then
			return 1
		end
		local low = 1 - depth
		if t < 0.05 then
			return 1 - depth * (t / 0.05)
		elseif t < 0.05 + hold then
			return low + 0.06 * math.sin(t * 37 + r1 * 6)
		end
		local back = (t - 0.05 - hold) / 0.35
		if back >= 1 then
			return 1
		end
		return low + (1 - low) * back * back
	end
	-- CUT-OUT: off for 50 to 140 ms (sometimes a second, shorter one), then back dim and
	-- warming up over 0.3 s.
	local off1 = 0.05 + 0.09 * r1
	local double = r2 < 0.35
	local gap = 0.08 + 0.12 * r3
	local off2 = if double then 0.04 + 0.05 * r2 / 0.35 else 0
	local start = r3 * 0.25
	local t = at - start
	if t < 0 then
		return 1
	end
	if t < off1 then
		return 0
	end
	t -= off1
	if double then
		if t < gap then
			return 0.8 + 0.2 * (t / gap)
		end
		t -= gap
		if t < off2 then
			return 0
		end
		t -= off2
	end
	if t < 0.3 then
		return 0.8 + 0.2 * (t / 0.3)
	end
	return 1
end

-- The whole brightness factor of a light at server time `now`.
local function faultFactor(seed: number, faulty: number, now: number): number
	-- Drift: slow and small, two layers.
	local drift = DRIFT_SLOW * faulty * smoothNoise(seed, 10, now / 2.3)
		+ DRIFT_FAST * faulty * smoothNoise(seed, 11, now / 0.55)
	local factor = 1 + drift
	-- Dips / cut-outs (this slot and the one before: an event can spill over).
	local chance = (EVENTS_MIN + EVENTS_EXTRA * faulty) / 60 * EVENT_SLOT
	local slot = math.floor(now / EVENT_SLOT)
	local at = now - slot * EVENT_SLOT
	factor *= math.min(
		eventFactor(seed, chance, slot, at),
		eventFactor(seed, chance, slot - 1, at + EVENT_SLOT)
	)
	-- Brown-out: a slow sine-shaped sag of 25 to 45 % over 2 to 4 s.
	local brownSlot = math.floor(now / BROWN_SLOT)
	if hash(seed, 20, brownSlot) < BROWN_CHANCE * faulty then
		local length = 2 + 2 * hash(seed, 21, brownSlot)
		local start = hash(seed, 22, brownSlot) * (BROWN_SLOT - length)
		local t = now - brownSlot * BROWN_SLOT - start
		if t > 0 and t < length then
			local depth = 0.25 + 0.2 * hash(seed, 23, brownSlot)
			factor *= 1 - depth * math.sin(math.pi * t / length)
		end
	end
	return math.max(0, factor)
end

------------------------------------------------------------------------------
-- The lights
------------------------------------------------------------------------------

type Entry = {
	part: BasePart,
	seed: number,
	-- Server values (the base) and what we wrote last, nil while we are not touching it.
	baseBrightness: number?,
	wroteBrightness: number?,
	baseColor: Color3?,
	wroteColor: Color3?,
}

local entries: { [BasePart]: Entry } = {}

local function lightOf(part: BasePart): Light?
	local named = part:FindFirstChild("Light")
	if named and named:IsA("Light") then
		return named
	end
	return part:FindFirstChildOfClass("PointLight")
		or part:FindFirstChildOfClass("SpotLight")
		or part:FindFirstChildOfClass("SurfaceLight")
end

local function seedOf(part: BasePart): number
	local given = part:GetAttribute("FaultySeed")
	if typeof(given) == "number" then
		return math.floor(math.abs(given)) % TWO32
	end
	-- (positions rounded to whole studs: the same on every computer)
	local p = part.Position
	local x = math.floor(p.X + 0.5) % 65536
	local y = math.floor(p.Y + 0.5) % 65536
	local z = math.floor(p.Z + 0.5) % 65536
	return bit32.bxor(mul32(x, 73856093), mul32(y, 19349663), mul32(z, 83492791))
end

-- Writes the server's values back where we left ours, and forgets them.
local function release(entry: Entry)
	local light = lightOf(entry.part)
	if light and entry.baseBrightness and light.Brightness == entry.wroteBrightness then
		light.Brightness = entry.baseBrightness
	end
	if entry.baseColor and entry.part.Color == entry.wroteColor then
		entry.part.Color = entry.baseColor
	end
	entry.baseBrightness, entry.wroteBrightness = nil, nil
	entry.baseColor, entry.wroteColor = nil, nil
end

local function add(instance: Instance)
	if instance:IsA("BasePart") and entries[instance] == nil then
		entries[instance] = { part = instance, seed = seedOf(instance) }
	end
end

local function remove(instance: Instance)
	local entry = entries[instance :: BasePart]
	if entry then
		release(entry)
		entries[instance :: BasePart] = nil
	end
end

local function updateOne(entry: Entry, now: number, cameraPosition: Vector3)
	local part = entry.part
	local faulty = part:GetAttribute("Faulty")
	local amount = if typeof(faulty) == "number" then math.clamp(faulty, 0, 1) else 0.5
	local light = lightOf(part)
	-- On? (the server's decision) A part without a light: on while it is Neon.
	local on = if light then light.Enabled else part.Material == Enum.Material.Neon
	if
		amount <= 0
		or not on
		or part.Parent == nil
		or (part.Position - cameraPosition).Magnitude > RANGE
	then
		if entry.baseBrightness or entry.baseColor then
			release(entry)
		end
		return
	end
	local factor = faultFactor(entry.seed, amount, now)
	if light then
		local current = light.Brightness
		if entry.wroteBrightness == nil or current ~= entry.wroteBrightness then
			entry.baseBrightness = current
		end
		local value = (entry.baseBrightness :: number) * factor
		if current ~= value then
			light.Brightness = value
		end
		entry.wroteBrightness = light.Brightness
	end
	local color = part.Color
	if entry.wroteColor == nil or color ~= entry.wroteColor then
		entry.baseColor = color
	end
	local base = entry.baseColor :: Color3
	local glow = GLOW_FLOOR + (1 - GLOW_FLOOR) * math.min(factor, 1)
	local value = Color3.new(base.R * glow, base.G * glow, base.B * glow)
	if color ~= value then
		part.Color = value
	end
	entry.wroteColor = part.Color
end

local function update()
	if next(entries) == nil then
		return
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local now = workspace:GetServerTimeNow()
	local cameraPosition = camera.CFrame.Position
	for _, entry in entries do
		updateOne(entry, now, cameraPosition)
	end
end

function FaultyLightController.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	RunService.Heartbeat:Connect(update)
end

return FaultyLightController
