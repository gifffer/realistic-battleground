--!strict
-- SoundLayers: plays a layered sound (Shared/SoundCues): every layer is its
-- own Shared/Sounds entry (its volume = its mix level), started `at`
-- seconds after the cue. A layer with no id yet is silent (no error).
--
--   SoundLayers.play(cue, model)            on a character (3D, its root)
--   SoundLayers.playAt(cue, position, part?) at a point (or following a part)
--   SoundLayers.loopOn(cue, part, volume?)  a looped cue on a part (3D):
--                                           returns a handle to fade / stop it

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SoundCues = require(ReplicatedStorage.Shared.SoundCues)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local SoundLayers = {}

local MAX_DISTANCE = 120 -- studs: a fire is heard from further than a punch

export type Loop = {
	setVolume: (scale: number) -> (),
	stop: (fade: number?) -> (),
}

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

function SoundLayers.play(name: string, model: Model)
	local cue = cueOf(name)
	if cue == nil then
		return
	end
	for _, layer in cue.layers do
		later(layer.at, function()
			if model.Parent then
				SoundController.play(layer.sound, model)
			end
		end)
	end
end

function SoundLayers.playAt(name: string, position: Vector3, part: BasePart?)
	local cue = cueOf(name)
	if cue == nil then
		return
	end
	for _, layer in cue.layers do
		later(layer.at, function()
			if part == nil or part.Parent then
				SoundController.playAt(layer.sound, position, MAX_DISTANCE, part)
			end
		end)
	end
end

-- (the first id of a looped layer: a loop is one file)
local function firstId(name: string): number?
	local info = Sounds[name]
	if info == nil or #info.ids == 0 then
		return nil
	end
	return info.ids[1]
end

function SoundLayers.loopOn(name: string, part: BasePart, volume: number?): Loop
	local scale = volume or 1
	local playing: { { sound: Sound, base: number } } = {}
	local stopped = false
	local cue = cueOf(name)
	if cue then
		for _, layer in cue.layers do
			local id = firstId(layer.sound)
			local info = Sounds[layer.sound]
			if id and info then
				local sound = Instance.new("Sound")
				sound.Name = layer.sound
				sound.SoundId = `rbxassetid://{id}`
				sound.Looped = true
				sound.Volume = info.volume * scale
				sound.PlaybackSpeed = info.pitch
				sound.RollOffMode = Enum.RollOffMode.InverseTapered
				sound.RollOffMinDistance = 8
				sound.RollOffMaxDistance = MAX_DISTANCE
				sound.Parent = part
				table.insert(playing, { sound = sound, base = info.volume })
				later(layer.at, function()
					if not stopped and sound.Parent then
						-- (each layer from its own point: they never phase together)
						sound.TimePosition = math.random() * 2
						sound:Play()
					end
				end)
			end
		end
	end
	local handle: Loop = {
		setVolume = function(newScale: number)
			scale = newScale
			for _, entry in playing do
				entry.sound.Volume = entry.base * scale
			end
		end,
		stop = function(fade: number?)
			if stopped then
				return
			end
			stopped = true
			local time = fade or 0.6
			for _, entry in playing do
				local sound = entry.sound
				if sound.Parent then
					TweenService:Create(sound, TweenInfo.new(time), { Volume = 0 }):Play()
					Debris:AddItem(sound, time + 0.1)
				end
			end
		end,
	}
	return handle
end

return table.freeze(SoundLayers)
