--!strict
-- Vfx/Moves/Cinematics: the impact layers of the finisher cinematics
-- (PLAN §2.7). Owner: K2 of the VFX overhaul.
--
-- A finisher is a timeline of named moments (Shared/Finishers) played by
-- Controllers/CinematicController, which also owns the camera then (its
-- own push-in, flash frames and shakes). So everything here is called
-- with `camera = false` and no hit-stop: only what is IN the scene (the
-- flash, the light, sparks, the air ring, dust, a crack). The gore stays
-- the gore modules' (HeadBlast, LiverRip, ArmRip...).
--
--   Cinematics.swing(attacker, limb, seconds)   a swing's trail (+ a glint on a prop)
--   Cinematics.strike(attacker, victim, partName, tier)  a blow landing on a part
--   Cinematics.stomp(victim)                    a foot driven onto a lying body
--   Cinematics.pop(victim, partName)            a joint coming out (a dull crack)
--
-- No clip or move specs here (cinematics aren't combat events), only these
-- helpers; Vfx/Moves/init reads the empty `clips` / `moves`.

local Floor = require(script.Parent.Parent.Floor)
local Impact = require(script.Parent.Parent.Impact)
local Layers = require(script.Parent.Parent.Layers)
local Limb = require(script.Parent.Parent.Limb)
local Palette = require(script.Parent.Parent.Palette)
local Pool = require(script.Parent.Parent.Pool)
local Types = require(script.Parent.Parent.Types)

local clips: { [string]: Types.ClipSpec } = {}
local moves: { [string]: Types.MoveSpec } = {}

local Cinematics = { clips = clips, moves = moves }

local function basePart(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

-- The swing of a blow that lands `seconds` later: the limb's (or the
-- held prop's) air trail until just after, and a 1-frame glint on a prop
-- the frame before contact.
function Cinematics.swing(attacker: Model, limb: Types.Limb, seconds: number)
	Limb.trailWindow(attacker, limb, 0, seconds + 0.04, {
		life = if limb == "Prop" then 0.14 else 0.12,
		arc = limb == "Prop",
	})
	if limb == "Prop" then
		Pool.after(math.max(0, seconds - 1 / 60), function()
			Limb.glint(attacker, "Prop")
		end)
	end
end

-- A blow landing on the victim's `partName` ("Torso", "Head"), from the
-- attacker's side: the tier's stack in the scene (the cinematic has its
-- own camera and hit-stop). `blood`: the gore draws its own drops.
function Cinematics.strike(
	attacker: Model,
	victim: Model,
	partName: string,
	tier: Types.Tier,
	blood: boolean?
)
	local part = basePart(victim, partName)
	local from = basePart(attacker, "Torso")
	if part == nil or from == nil then
		return
	end
	local along = part.Position - from.Position
	if along.Magnitude < 0.1 then
		return
	end
	along = along.Unit
	Impact.hit({
		point = part.Position - along * 0.55,
		dir = along,
		tier = tier,
		victim = victim,
		camera = false,
		hitstop = false,
		floor = false,
		blood = blood,
	})
end

-- A boot driven onto a body lying on the floor (ARM RIP's stomp): dust
-- pushed out from under it, a short crack.
function Cinematics.stomp(victim: Model)
	local torso = basePart(victim, "Torso")
	if torso == nil then
		return
	end
	local floor = Floor.at(torso.Position, 4)
	if floor == nil then
		return
	end
	Layers.dustRing(floor.position, {
		puffs = 6,
		speed = 9,
		size = 0.8,
		color = Floor.dustColor(floor),
	})
	Layers.crack(floor.position, floor.normal, 2)
end

-- A joint torn out of its socket: a tiny 1-frame flash (no light show),
-- a few dark specks. Nothing else: the scream and the blood are the beat.
function Cinematics.pop(victim: Model, partName: string)
	local part = basePart(victim, partName)
	if part == nil then
		return
	end
	local shoulder = (part.CFrame * CFrame.new(0, part.Size.Y / 2 - 0.2, 0)).Position
	local out = part.CFrame.RightVector
	Layers.contactFlash(shoulder, 1, { frames = 1, spikes = 4, dir = out })
	Layers.specks(shoulder, out, 5, { color = Palette.DustDark })
end

return Cinematics
