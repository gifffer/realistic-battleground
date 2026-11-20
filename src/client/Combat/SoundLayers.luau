--!strict
-- SoundLayers: plays a layered sound (Shared/SoundCues): every layer is its
-- own Shared/Sounds entry (its volume = its mix level), started `at`
-- seconds after the cue. A layer with no id yet is silent (no error).
--
--   SoundLayers.play(cue, model)            on a character (3D, its root)
--   SoundLayers.playAt(cue, position, part?) at a point (or following a part)
--   SoundLayers.loopOn(cue, part, volume?, fadeIn?)
--                                           a looped cue on a part (3D): returns
--                                           a handle to change its volume / stop it
--   SoundLayers.ignitionHeard(model)        a Pyro cue just voiced this body
--                                           catching fire (Burns stays quiet)
--
-- Every sound goes through one mix group ("PyroFx": a gentle compressor and a
-- little less top end), so the glass, the fireball, the pool and the screams
-- landing together stay clear instead of piling up.
--
-- Loops: each body / pool picks one of the layer's ids, starts it at a random
-- point of the file and fades it in. Near the end of the file a second copy
-- starts at the top and the two cross-fade, so the seam is never heard.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundCues = require(ReplicatedStorage.Shared.SoundCues)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local SoundLayers = {}

local MAX_DISTANCE = 120 -- studs: a fire is heard from further than a punch
local CROSSFADE = 1.5 -- seconds: one turn of a loop into the next
local STEP = 0.1 -- seconds between two volume updates of a fading loop

export type Loop = {
	setVolume: (scale: number) -> (),
	stop: (fade: number?) -> (),
}

local random = Random.new()
local nextVariant: { [string]: number } = {}

-- Cues that already sound like a body catching fire (a whoosh and a sizzle,
-- or a fireball): Burns skips its own catch-fire sound and cry under them.
local IGNITION_CUES = {
	FireImpact = true,
	BodyIgnite = true,
	GlobSplat = true, -- (its fireball, FuelIgnite, follows 0.06 s later)
	FuelIgnite = true,
}
local IGNITION_WINDOW = 0.5 -- seconds a cue covers a body catching fire
local IGNITION_REACH = 10 -- studs round a blast (a napalm glob's whole splash)
local ignitedAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local blasts: { { position: Vector3, at: number } } = {}

local function noteIgnition(name: string, model: Model?, position: Vector3?)
	if not IGNITION_CUES[name] then
		return
	end
	local now = os.clock()
	if model then
		ignitedAt[model] = now
	elseif position then
		for index = #blasts, 1, -1 do
			if now - blasts[index].at > IGNITION_WINDOW then
				table.remove(blasts, index)
			end
		end
		table.insert(blasts, { position = position, at = now })
	end
end

function SoundLayers.ignitionHeard(model: Model): boolean
	local now = os.clock()
	local at = ignitedAt[model]
	if at and now - at <= IGNITION_WINDOW then
		return true
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		for _, blast in blasts do
			if
				now - blast.at <= IGNITION_WINDOW
				and (root.Position - blast.position).Magnitude <= IGNITION_REACH
			then
				return true
			end
		end
	end
	return false
end

local group: SoundGroup? = nil
local function mixGroup(): SoundGroup
	local current = group
	if current and current.Parent then
		return current
	end
	local made = Instance.new("SoundGroup")
	made.Name = "PyroFx"
	made.Volume = 1
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Threshold = -18
	compressor.Ratio = 3
	compressor.Attack = 0.005
	compressor.Release = 0.15
	compressor.Parent = made
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = 0
	eq.MidGain = 0
	eq.HighGain = -2.5
	eq.Parent = made
	made.Parent = SoundService
	group = made
	return made
end

local function cueOf(name: string): SoundCues.Cue?
	local cue = SoundCues[name]
	if cue == nil then
		warn(`[SoundLayers] unknown cue "{name}" (see Shared/SoundCues.luau)`)
	end
	return cue
end

local function later(at: number, fn: () -> ())
	if at <= 0 then
		fn()
	else
		task.delay(at, fn)
	end
end

local function grouped(sound: Sound?)
	if sound then
		sound.SoundGroup = mixGroup()
	end
end

function SoundLayers.play(name: string, model: Model)
	local cue = cueOf(name)
	if cue == nil then
		return
	end
	noteIgnition(name, model, nil)
	for _, layer in cue.layers do
		later(layer.at, function()
			if model.Parent then
				grouped(SoundController.play(layer.sound, model))
			end
		end)
	end
end

function SoundLayers.playAt(name: string, position: Vector3, part: BasePart?)
	local cue = cueOf(name)
	if cue == nil then
		return
	end
	local owner = if part then part:FindFirstAncestorOfClass("Model") else nil
	noteIgnition(name, owner, if owner then nil else position)
	for _, layer in cue.layers do
		later(layer.at, function()
			if part == nil or part.Parent then
				grouped(SoundController.playAt(layer.sound, position, MAX_DISTANCE, part))
			end
		end)
	end
end

------------------------------------------------------------------------------
-- Loops
------------------------------------------------------------------------------

-- One layer of a loop: the copy playing now (and, while cross-fading, the
-- next one), at `base` x the loop's scale.
type Voice = {
	id: number,
	base: number,
	pitch: number,
	current: Sound?,
	incoming: Sound?,
	mix: number, -- 0..1: how far the cross-fade into `incoming` is
}

-- The layer's ids in turn (two bodies burning side by side never play the
-- same file).
local function variantOf(name: string, ids: { number }): number
	local index = (nextVariant[name] or random:NextInteger(0, #ids - 1)) % #ids + 1
	nextVariant[name] = index
	return ids[index]
end

local function newCopy(voice: Voice, part: BasePart, name: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = `rbxassetid://{voice.id}`
	sound.Looped = true -- (a safety net: the cross-fade normally comes first)
	sound.Volume = 0
	sound.PlaybackSpeed = voice.pitch
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = MAX_DISTANCE
	sound.SoundGroup = mixGroup()
	sound.Parent = part
	return sound
end

-- Seconds of a loaded file (0 while it isn't loaded: waits up to 5 s).
local function lengthOf(sound: Sound): number
	local waited = 0
	while sound.TimeLength <= 0 and waited < 5 and sound.Parent do
		waited += task.wait(0.1)
	end
	return sound.TimeLength
end

function SoundLayers.loopOn(name: string, part: BasePart, volume: number?, fadeIn: number?): Loop
	local scale = volume or 1
	local level = 0 -- the fade-in / fade-out, 0..1
	local stopped = false
	local voices: { Voice } = {}
	local cue = cueOf(name)
	if cue then
		for _, layer in cue.layers do
			local info = Sounds[layer.sound]
			if info and #info.ids > 0 then
				local id = variantOf(layer.sound, info.ids)
				local trim = if info.trims then info.trims[id] else nil
				local gain = (if trim then trim.gain else nil) or 1
				local voice: Voice = {
					id = id,
					base = info.volume * gain,
					pitch = info.pitch,
					current = nil,
					incoming = nil,
					mix = 0,
				}
				table.insert(voices, voice)
				later(layer.at, function()
					if stopped or part.Parent == nil then
						return
					end
					local sound = newCopy(voice, part, layer.sound)
					voice.current = sound
					sound:Play()
					-- (from a random point: two pools never breathe together)
					task.spawn(function()
						local length = lengthOf(sound)
						if length > CROSSFADE * 3 and sound.Parent then
							sound.TimePosition = random:NextNumber(0, length - CROSSFADE * 2)
						end
					end)
				end)
			end
		end
	end

	local function apply()
		for _, voice in voices do
			local target = math.min(voice.base * scale * level, 10)
			if voice.current then
				voice.current.Volume = target * math.cos(voice.mix * math.pi / 2)
			end
			if voice.incoming then
				voice.incoming.Volume = target * math.sin(voice.mix * math.pi / 2)
			end
		end
	end

	-- The loop's own clock: the fade-in, then each layer's cross-fade into a
	-- fresh copy before its file ends (equal power: no dip in the middle).
	local rise = math.max(fadeIn or 0.3, 0.01)
	task.spawn(function()
		while not stopped and part.Parent do
			level = math.min(1, level + STEP / rise)
			for _, voice in voices do
				local current = voice.current
				if current == nil or not current.IsLoaded or current.TimeLength <= 0 then
					continue
				end
				local left = (current.TimeLength - current.TimePosition)
					/ math.max(voice.pitch, 0.01)
				if voice.incoming == nil and left <= CROSSFADE + STEP then
					local fresh = newCopy(voice, part, current.Name)
					fresh:Play()
					voice.incoming = fresh
					voice.mix = 0
				elseif voice.incoming then
					voice.mix = math.min(1, voice.mix + STEP / CROSSFADE)
					if voice.mix >= 1 then
						current:Destroy()
						voice.current = voice.incoming
						voice.incoming = nil
						voice.mix = 0
					end
				end
			end
			apply()
			task.wait(STEP)
		end
	end)

	local handle: Loop = {
		setVolume = function(newScale: number)
			scale = newScale
			apply()
		end,
		stop = function(fade: number?)
			if stopped then
				return
			end
			stopped = true
			local time = math.max(fade or 0.6, 0.05)
			task.spawn(function()
				local from = level
				local t = 0
				while t < time do
					t += task.wait(STEP * 0.5)
					level = from * (1 - math.min(1, t / time)) ^ 2
					apply()
				end
				for _, voice in voices do
					for _, sound in { voice.current, voice.incoming } do
						if sound then
							Debris:AddItem(sound, 0.05)
						end
					end
				end
			end)
		end,
	}
	return handle
end

return table.freeze(SoundLayers)
