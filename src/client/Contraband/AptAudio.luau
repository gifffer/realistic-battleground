--!strict
-- AptAudio: the SOUND of the flat (Flat 4B) and its hidden lab, on this screen only.
--
-- Used by Controllers/ApartmentAmbienceController, which tells it where the player is.
-- Every slot name comes from Shared/Sounds.luau (ids, volumes, trims): change a sound there,
-- not here (docs/SOUNDS_LAB_FR.md).
--
-- WHAT IT DOES
--   • Two 2D "beds" (AptEntranceTone: the building's low rumble, AptCorridorTone: the city
--     night through the walls). Each room has its own mix of the two (ROOM_MIX below);
--     changing rooms crossfades them in 0.8 s.
--   • 3D loops on invisible host parts (fridge hums, the tube buzz, the vat, the pumps...):
--     you hear them louder when close, from the right direction. Each loop starts at a
--     random point of its file, so two fridges never hum in sync.
--   • 3D one-shots at a point (doors, drips, creaks, the spark...).
--   • WALL MUFFLING: every 3D sound belongs to a room (its "zone"). Heard from ANOTHER room,
--     an equalizer cuts its highs (like a sound through a wall). The lab heard from the
--     corridor while the lab door is wide open is only a little muffled.
--   • REVERB: SoundService.AmbientReverb follows the room (a bathroom rings, a bedroom is
--     dry). The value found on arrival is put back when you leave.
--   • While you extract (attribute Extracting): the beds drop to 60 % and the tube buzz to
--     70 %, so the extraction cues sit on top.
--
-- API
--   AptAudio.start()                       starts the beds (silent until setRoom)
--   AptAudio.stop()                        stops and removes everything, puts the reverb back
--   AptAudio.setRoom(room)                 the listener's room ("Entry", "Lab"... or nil)
--   AptAudio.room()                        the last room given (nil before the first)
--   AptAudio.setLabDoorOpen(open)          true = the lab door is open past 60°
--   AptAudio.setExtracting(on)             the extraction mix
--   AptAudio.addLoop(key, host, options)   a 3D loop on `host` (see LoopOptions)
--   AptAudio.setLoopScale(key, scale)      × its volume (the flicker of a light...)
--   AptAudio.playAt(slot, where, zone, minDistance, maxDistance, volumeScale?, pitchScale?)
--   AptAudio.play2D(slot, volumeScale?)    a 2D one-shot (the reveal drone)
--   AptAudio.randomReady(slot, gap)        false if `slot` played less than `gap` s ago
--   AptAudio.update(deltaTime)             every frame while in the flat (fades, muffling)

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

local AptAudio = {}

------------------------------------------------------------------------------
-- Tuning
------------------------------------------------------------------------------

-- How much of each bed plays in each room (× the slot's own volume), and the reverb there.
local ROOM_MIX: { [string]: { entrance: number, corridor: number, reverb: Enum.ReverbType } } = {
	Entry = { entrance = 1, corridor = 0.3, reverb = Enum.ReverbType.Hallway },
	Living = { entrance = 0.8, corridor = 0.7, reverb = Enum.ReverbType.LivingRoom },
	Corridor = { entrance = 0.5, corridor = 1, reverb = Enum.ReverbType.CarpettedHallway },
	Bath = { entrance = 0.4, corridor = 0.6, reverb = Enum.ReverbType.Bathroom },
	Bed2 = { entrance = 0.5, corridor = 0.7, reverb = Enum.ReverbType.Room },
	-- (in the lab: the low rumble only; try PaddedCell for the plastic tent in playtest)
	Lab = { entrance = 0.4, corridor = 0, reverb = Enum.ReverbType.Room },
}
-- Seconds of the bed crossfade when the room changes.
local BED_FADE = 0.8
-- The corridor bed is the street THROUGH the walls: always muffled (dB).
local STREET_HIGH = -10
local STREET_MID = -3
-- Muffling of a sound heard from another room (dB), and of the lab through its open door.
local WALL_HIGH = -18
local WALL_MID = -6
local OPEN_DOOR_HIGH = -8
-- How fast the muffling follows (dB per second: 18 dB in 0.5 s).
local MUFFLE_SPEED = 36
-- While extracting: × the beds and × the tube buzz.
local EXTRACT_BEDS = 0.6
local EXTRACT_BUZZ = 0.7
-- 3D loops fade in over this long when they start (no click).
local LOOP_FADE_IN = 1.2

------------------------------------------------------------------------------
-- State
------------------------------------------------------------------------------

export type LoopOptions = {
	slot: string, -- Shared/Sounds slot (a looped one)
	zone: string, -- the room it is in ("Neighbour" never matches: always muffled)
	minDistance: number, -- full volume this close (studs)
	maxDistance: number, -- silent beyond this (studs)
	volume: number?, -- × the slot volume (default 1)
	pitch: number?, -- × the slot pitch (default 1)
}

type Loop = {
	sound: Sound,
	eq: EqualizerSoundEffect,
	zone: string,
	slot: string,
	baseVolume: number,
	scale: number,
	age: number,
}

type Fade = { from: number, to: number, startedAt: number }

local random = Random.new()
local running = false
local clock = 0 -- seconds since start (our own timeline for the fades)
local room: string? = nil
local labDoorOpen = false
local extracting = false
local extractMix = 1 -- (smoothed 1 → EXTRACT_BEDS)
local entranceBed: Sound? = nil
local corridorBed: Sound? = nil
local entranceFade: Fade = { from = 0, to = 0, startedAt = 0 }
local corridorFade: Fade = { from = 0, to = 0, startedAt = 0 }
local loops: { [string]: Loop } = {}
local lastPlayed: { [string]: number } = {} -- slot → last id (never the same twice in a row)
local lastPlayedAt: { [string]: number } = {} -- slot → os.clock() of its last play
local savedReverb: Enum.ReverbType? = nil

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function info(slot: string): Sounds.SoundInfo?
	local found = Sounds[slot]
	if found == nil then
		warn(`[AptAudio] unknown sound "{slot}" (see Shared/Sounds.luau)`)
		return nil
	end
	if #found.ids == 0 then
		return nil -- (no id yet: silent)
	end
	return found
end

-- A random id of the slot, never the same twice in a row.
local function pickId(slot: string, ids: { number }): number
	local id = ids[random:NextInteger(1, #ids)]
	if #ids > 1 and id == lastPlayed[slot] then
		id = ids[(table.find(ids, id) :: number) % #ids + 1]
	end
	lastPlayed[slot] = id
	return id
end

-- Sine in-out, the curve of every fade here.
local function ease(alpha: number): number
	return 0.5 - math.cos(math.clamp(alpha, 0, 1) * math.pi) * 0.5
end

local function fadeValue(fade: Fade): number
	return fade.from + (fade.to - fade.from) * ease((clock - fade.startedAt) / BED_FADE)
end

local function fadeTo(fade: Fade, target: number)
	if math.abs(fade.to - target) < 1e-4 then
		return
	end
	fade.from = fadeValue(fade)
	fade.to = target
	fade.startedAt = clock
end

-- The equalizer gains (high, mid) for a sound of `zone` heard from the current room.
local function muffleFor(zone: string): (number, number)
	if room ~= nil and zone == room then
		return 0, 0
	end
	if zone == "Lab" and room == "Corridor" and labDoorOpen then
		return OPEN_DOOR_HIGH, 0
	end
	return WALL_HIGH, WALL_MID
end

local function approach(current: number, target: number, step: number): number
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

local function newEq(parent: Instance, high: number, mid: number): EqualizerSoundEffect
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name = "Wall"
	eq.HighGain = high
	eq.MidGain = mid
	eq.LowGain = 0
	eq.Parent = parent
	return eq
end

-- A sound with a `length` (Shared/Sounds): faded out over `fadeOut`, then stopped.
local function cutShort(sound: Sound, length: number?, fade: number?)
	if length == nil then
		return
	end
	local time = fade or 0.15
	local steps = math.max(6, math.ceil(time / 0.03))
	task.delay(math.max(0, length - time * 0.5), function()
		if sound.Parent == nil then
			return
		end
		local start = sound.Volume
		for step = 1, steps do
			sound.Volume = start * (1 - step / steps) ^ 2
			task.wait(time / steps)
		end
		sound:Stop()
		sound:Destroy()
	end)
end

------------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------------

function AptAudio.start()
	if running then
		return
	end
	running = true
	clock = 0
	room = nil
	extractMix = 1
	entranceFade = { from = 0, to = 0, startedAt = 0 }
	corridorFade = { from = 0, to = 0, startedAt = 0 }
	savedReverb = SoundService.AmbientReverb

	local entrance = info("AptEntranceTone")
	if entrance then
		local sound = Instance.new("Sound")
		sound.Name = "AptEntranceTone"
		sound.SoundId = `rbxassetid://{entrance.ids[1]}`
		sound.Looped = true
		sound.Volume = 0
		sound.PlaybackSpeed = entrance.pitch
		sound.Parent = SoundService
		sound:Play()
		entranceBed = sound
	end
	local street = info("AptCorridorTone")
	if street then
		local sound = Instance.new("Sound")
		sound.Name = "AptCorridorTone"
		sound.SoundId = `rbxassetid://{street.ids[1]}`
		sound.Looped = true
		sound.Volume = 0
		sound.PlaybackSpeed = street.pitch
		newEq(sound, STREET_HIGH, STREET_MID)
		sound.Parent = SoundService
		sound:Play()
		corridorBed = sound
	end
end

function AptAudio.stop()
	if not running then
		return
	end
	running = false
	if entranceBed then
		entranceBed:Destroy()
	end
	if corridorBed then
		corridorBed:Destroy()
	end
	entranceBed = nil
	corridorBed = nil
	for _, loop in loops do
		loop.sound:Destroy()
	end
	table.clear(loops)
	if savedReverb then
		SoundService.AmbientReverb = savedReverb
	end
	savedReverb = nil
	room = nil
end

-- The listener's room: beds crossfade, reverb switches. nil (a doorway, outside the boxes)
-- keeps the last room's mix.
function AptAudio.setRoom(newRoom: string?)
	if newRoom == nil or newRoom == room or not running then
		return
	end
	room = newRoom
	local mix = ROOM_MIX[newRoom]
	if mix then
		fadeTo(entranceFade, mix.entrance)
		fadeTo(corridorFade, mix.corridor)
		SoundService.AmbientReverb = mix.reverb
	end
end

function AptAudio.room(): string?
	return room
end

function AptAudio.setLabDoorOpen(open: boolean)
	labDoorOpen = open
end

function AptAudio.setExtracting(on: boolean)
	extracting = on
end

-- A 3D loop on `host`, remembered under `key` (adding the same key again does nothing).
function AptAudio.addLoop(key: string, host: BasePart, options: LoopOptions)
	if not running or loops[key] then
		return
	end
	local slot = info(options.slot)
	if slot == nil then
		return
	end
	local id = pickId(options.slot, slot.ids)
	local trim = if slot.trims then slot.trims[id] else nil
	local gain = (if trim then trim.gain else nil) or 1
	local sound = Instance.new("Sound")
	sound.Name = `Apt_{key}`
	sound.SoundId = `rbxassetid://{id}`
	sound.Looped = true
	sound.Volume = 0
	sound.PlaybackSpeed = slot.pitch * (options.pitch or 1)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = options.minDistance
	sound.RollOffMaxDistance = options.maxDistance
	local high, mid = muffleFor(options.zone)
	local eq = newEq(sound, high, mid)
	sound.Parent = host
	-- (start at a random point of the file, once its length is known)
	local function seek()
		if sound.TimeLength > 1 then
			sound.TimePosition = random:NextNumber(0, sound.TimeLength - 0.5)
		end
	end
	if sound.IsLoaded then
		seek()
	else
		sound.Loaded:Once(seek)
	end
	sound:Play()
	loops[key] = {
		sound = sound,
		eq = eq,
		zone = options.zone,
		slot = options.slot,
		baseVolume = slot.volume * gain * (options.volume or 1),
		scale = 1,
		age = 0,
	}
end

function AptAudio.setLoopScale(key: string, scale: number)
	local loop = loops[key]
	if loop then
		loop.scale = scale
	end
end

-- A 3D one-shot at a part (it follows the part) or at a point. Returns the Sound (or nil).
function AptAudio.playAt(
	slotName: string,
	where: BasePart | Vector3,
	zone: string,
	minDistance: number,
	maxDistance: number,
	volumeScale: number?,
	pitchScale: number?
): Sound?
	if not running then
		return nil
	end
	local slot = info(slotName)
	if slot == nil then
		return nil
	end
	local id = pickId(slotName, slot.ids)
	local trim = if slot.trims then slot.trims[id] else nil
	local start = (if trim then trim.start else nil) or slot.start or 0
	local gain = (if trim then trim.gain else nil) or 1
	local sound = Instance.new("Sound")
	sound.Name = slotName
	sound.SoundId = `rbxassetid://{id}`
	sound.Volume = math.min(slot.volume * gain * (volumeScale or 1), 10)
	sound.PlaybackSpeed = slot.pitch
		* (pitchScale or 1)
		* (1 + random:NextNumber(-slot.pitchVariation, slot.pitchVariation))
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = minDistance
	sound.RollOffMaxDistance = maxDistance
	local high, mid = muffleFor(zone)
	newEq(sound, high, mid)
	local holder: Instance
	if typeof(where) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.Name = slotName .. "_At"
		attachment.WorldPosition = where
		attachment.Parent = workspace.Terrain
		holder = attachment
		Debris:AddItem(attachment, (slot.length or 6) + 4)
	else
		holder = where
	end
	sound.Parent = holder
	sound.TimePosition = start
	sound:Play()
	lastPlayedAt[slotName] = os.clock()
	cutShort(sound, slot.length, slot.fadeOut)
	Debris:AddItem(sound, (slot.length or 6) + 3)
	return sound
end

function AptAudio.play2D(slotName: string, volumeScale: number?): Sound?
	if not running then
		return nil
	end
	local slot = info(slotName)
	if slot == nil then
		return nil
	end
	local id = pickId(slotName, slot.ids)
	local trim = if slot.trims then slot.trims[id] else nil
	local start = (if trim then trim.start else nil) or slot.start or 0
	local gain = (if trim then trim.gain else nil) or 1
	local sound = Instance.new("Sound")
	sound.Name = slotName
	sound.SoundId = `rbxassetid://{id}`
	sound.Volume = math.min(slot.volume * gain * (volumeScale or 1), 10)
	sound.PlaybackSpeed = slot.pitch
	sound.Parent = SoundService
	sound.TimePosition = start
	sound:Play()
	lastPlayedAt[slotName] = os.clock()
	cutShort(sound, slot.length, slot.fadeOut)
	Debris:AddItem(sound, (slot.length or 12) + 3)
	return sound
end

-- For the random ambience one-shots: false if `slot` played less than `gap` seconds ago.
function AptAudio.randomReady(slotName: string, gap: number): boolean
	local at = lastPlayedAt[slotName]
	return at == nil or os.clock() - at >= gap
end

function AptAudio.update(deltaTime: number)
	if not running then
		return
	end
	clock += deltaTime
	extractMix = approach(extractMix, if extracting then EXTRACT_BEDS else 1, deltaTime / BED_FADE)

	-- the beds
	local entrance = entranceBed
	if entrance then
		entrance.Volume = Sounds.AptEntranceTone.volume * fadeValue(entranceFade) * extractMix
	end
	local street = corridorBed
	if street then
		street.Volume = Sounds.AptCorridorTone.volume * fadeValue(corridorFade) * extractMix
	end

	-- the 3D loops: fade-in, flicker scale, extraction mix, wall muffling
	local buzzMix = 1 - (1 - EXTRACT_BUZZ) * (1 - extractMix) / (1 - EXTRACT_BEDS)
	local step = MUFFLE_SPEED * deltaTime
	for _, loop in loops do
		loop.age += deltaTime
		local fadeIn = ease(loop.age / LOOP_FADE_IN)
		local mix = if loop.slot == "LabFluoBuzz" then buzzMix else 1
		loop.sound.Volume = math.min(loop.baseVolume * loop.scale * mix * fadeIn, 10)
		local high, mid = muffleFor(loop.zone)
		loop.eq.HighGain = approach(loop.eq.HighGain, high, step)
		loop.eq.MidGain = approach(loop.eq.MidGain, mid, step)
	end
end

return AptAudio
