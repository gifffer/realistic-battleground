--!strict
-- AnimationController: plays animations on YOUR character, by name.
--
--   AnimationController.play("Brawler_M1_1")
--   AnimationController.play("Block", { looped = true })
--   AnimationController.stop("Block")
--
-- IDs come from Shared/Animations.luau. An ID of 0 = not made yet: play()
-- simply does nothing, so the game works before the animations exist.
--
-- Why on the client? Animations played by a client on its own character are
-- replicated to everyone by Roblox automatically, and they start instantly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Shared.Animations)

local player = Players.LocalPlayer

export type PlayOptions = {
	looped: boolean?,
	fadeTime: number?, -- seconds to blend in (default 0.1)
}

local AnimationController = {}

local animator: Animator? = nil
-- Loaded tracks of the current character (reset on respawn).
local tracks: { [string]: AnimationTrack } = {}

local function getTrack(name: string): AnimationTrack?
	local cached = tracks[name]
	if cached then
		return cached
	end
	local id = Animations[name]
	if id == nil then
		warn(`[AnimationController] unknown animation "{name}" (see Shared/Animations.luau)`)
		return nil
	end
	if id == 0 or animator == nil then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = `rbxassetid://{id}`
	local track = (animator :: Animator):LoadAnimation(animation)
	tracks[name] = track
	return track
end

function AnimationController.play(name: string, options: PlayOptions?): AnimationTrack?
	local track = getTrack(name)
	if track == nil then
		return nil
	end
	track.Looped = if options and options.looped then true else false
	track:Play(if options and options.fadeTime then options.fadeTime else 0.1)
	return track
end

function AnimationController.stop(name: string, fadeTime: number?)
	local track = tracks[name]
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0.15)
	end
end

local function onCharacterAdded(character: Model)
	table.clear(tracks)
	animator = nil
	local humanoid = character:WaitForChild("Humanoid", 10)
	local found = humanoid and humanoid:WaitForChild("Animator", 10)
	if found and found:IsA("Animator") then
		animator = found
	end
end

function AnimationController.start()
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

return AnimationController
