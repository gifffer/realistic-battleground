--!strict
-- Vfx/Impact: whole impact stacks, built from Vfx/Layers in the frame order
-- of the references (F0 = the contact frame, 60 fps):
--
--   F-2  (our own heavy blows) the screen dims          ← HitFx beats
--   F0   flash (pops, 1-2 fr) + light + streaks + sparks + air ring
--        + hit-stop on both fighters + camera kick / FOV punch / shake
--   F+1  specks (moisture) fly out
--   F+2  the 2nd ring (Heavy), the dust puff off the clothes
--   F+3  the warm 2nd flash (Last / the killing hit)
--   F+6  blood (CombatEffectsController delays it: HitFx.bloodDelay)
--   …    floor dust settles (~0.8 s), debris stays (5-10 s)
--
--   Impact.hit(args)                    one tier's stack (Vfx/Tiers)
--   Impact.groundSlam(point, tier, opts) a body / fist into the floor
--   Impact.knockoutOverlay(args)        the "last hit looks different" layers
--   Impact.awakening(model, style, at?) a kit's Awakening beat
--   Impact.landing(victim, strength)    dust + crack where a thrown body lands / hits a wall
--   Impact.contactPoint(victim, attacker, limb?, zone?) → point, dir
--   Impact.hitstop(attacker, victim, seconds, dir?)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Camera = require(script.Parent.Camera)
local Floor = require(script.Parent.Floor)
local Layers = require(script.Parent.Layers)
local Limb = require(script.Parent.Limb)
local Palette = require(script.Parent.Palette)
local Pool = require(script.Parent.Pool)
local Quality = require(script.Parent.Quality)
local Tiers = require(script.Parent.Tiers)
local Types = require(script.Parent.Types)
local CharacterAnimationController =
	require(script.Parent.Parent.Parent.Controllers.CharacterAnimationController)

local Config = require(ReplicatedStorage.Shared.Config)

type ImpactArgs = Types.ImpactArgs
type Tier = Types.Tier

local Impact = {}

local player = Players.LocalPlayer
local random = Random.new()

local FLOOR_REACH = 4 -- floor dust only if the floor is this close under the hit

local function basePart(model: Model?, name: string): BasePart?
	if model == nil then
		return nil
	end
	local part = model:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

local function unitOr(v: Vector3, fallback: Vector3): Vector3
	return if v.Magnitude > 1e-4 then v.Unit else fallback
end

------------------------------------------------------------------------------
-- Hit-stop
------------------------------------------------------------------------------

-- Freezes both fighters' clips on the same frame for `seconds`, and makes
-- the victim shake along `dir` meanwhile (fighting-game hit shake).
function Impact.hitstop(
	attacker: Model?,
	victim: Model?,
	seconds: number,
	dir: Vector3?,
	jitter: number?
)
	if attacker then
		CharacterAnimationController.hitStop(attacker, seconds)
	end
	if victim then
		local shake = if dir
				and jitter
				and jitter > 0
			then unitOr(dir, Vector3.zAxis) * jitter
			else nil
		CharacterAnimationController.hitStop(victim, seconds, shake)
	end
end

------------------------------------------------------------------------------
-- Camera side of an impact (fighters get the push-in; spectators a shake)
------------------------------------------------------------------------------

local function cameraFor(def: Types.TierDef, args: ImpactArgs, scale: number)
	local involvement = Camera.involves(args.attacker, args.victim)
	if involvement <= 0 then
		return
	end
	local character = player.Character
	local amAttacker = args.attacker ~= nil and args.attacker == character
	-- (a blocked hit never shakes the attacker)
	if args.tier == "Blocked" and amAttacker then
		return
	end
	Camera.trauma(def.trauma * involvement * scale)
	if involvement < 1 then
		return
	end
	if def.fov > 0 then
		Camera.fovPunch(def.fov * scale)
	end
	if def.kick > 0 then
		-- Attacker: the view is pushed along the blow. Victim: thrown back
		-- the way the fist pushes (also `dir`).
		Camera.kick(args.dir, def.kick * scale)
	end
	if def.dim > 0 then
		Camera.dim(def.dim)
	end
end

------------------------------------------------------------------------------
-- One hit
------------------------------------------------------------------------------

local function skipped(args: ImpactArgs, layer: string): boolean
	local skip = args.skip
	return skip ~= nil and skip[layer] == true
end

-- The whole stack of `args.tier`, in frame order (see the header).
function Impact.hit(args: ImpactArgs)
	local def = Tiers.get(args.tier)
	local material = args.material or (if args.tier == "Blocked" then "Guard" else "Body")
	local scale = args.scale or 1
	local point = args.point
	local dir = unitOr(args.dir, Vector3.zAxis)
	local detail = Quality.detail(point)

	-- Hit-stop and camera happen even when the point is off-screen.
	if args.hitstop ~= false and (args.attacker or args.victim) then
		Impact.hitstop(args.attacker, args.victim, def.hitstop, dir, def.jitter)
	end
	if args.camera ~= false then
		cameraFor(def, args, scale)
	end
	if detail == "None" then
		return
	end

	-- F0: the flash and its light (always, even far away / over the cap).
	local warm = def.warm or material == "Guard" or material == "Glass"
	local flashColor = if material == "Rift"
		then Palette.FlashCore:Lerp(Palette.RiftTint, 0.5)
		elseif warm then Palette.GuardWarm
		else Palette.FlashCore
	if not skipped(args, "flash") then
		Layers.contactFlash(point - dir * 0.15, def.flash * scale, {
			frames = def.flashFrames,
			spikes = if args.tier == "Blocked" then 4 else 6,
			dir = dir,
			color = flashColor,
		})
	end
	if not skipped(args, "light") then
		-- (pushed toward the attacker: it lights the victim's face / chest)
		Layers.light(point - dir * 0.3, def.light, def.range * scale, {
			fade = def.fade,
			color = if warm then Palette.GuardWarm else Palette.Light,
		})
	end
	if detail ~= "Full" or not Quality.takeImpact() then
		return
	end

	-- F0: streaks out the far side, sparks.
	if def.streaks > 0 and material ~= "Palm" and not skipped(args, "streaks") then
		if material == "Slash" then
			-- one long thin streak along the cut (sideways)
			Layers.streaks(
				point,
				Layers.perpendicular(dir),
				1,
				4 * scale,
				{ width = 0.08, frames = 3 }
			)
		else
			local back: Vector3? = nil
			if def.armStreak and args.attacker then
				local root = basePart(args.attacker, "HumanoidRootPart")
				if root then
					back = unitOr(root.Position + Vector3.yAxis * 0.8 - point, -dir)
				end
			end
			Layers.streaks(point, dir, def.streaks, (3 + def.streaks * 0.5) * scale, {
				width = if def.heavySparks then 0.18 else 0.12,
				frames = if def.heavySparks then 3 else 2,
				backAlong = back,
			})
		end
	end
	if def.sparks > 0 and material ~= "Palm" and not skipped(args, "sparks") then
		local palette: Layers.SparkPalette = if material == "Guard" or material == "Glass"
			then "Warm"
			elseif material == "Rift" then "Rift"
			else "Body"
		Layers.sparkBurst(point, dir, {
			count = math.floor(def.sparks * math.sqrt(scale) + 0.5),
			heavy = def.heavySparks,
			palette = palette,
			spread = if material == "Guard" then 85 else 65,
		})
		if material == "Glass" then
			Layers.sparkBurst(point, dir, { count = 8, palette = "Glass", spread = 80 })
		end
	end

	-- F0 → F+12: the air ring(s), facing the blow.
	if def.rings > 0 and material ~= "Slash" and not skipped(args, "ring") then
		local facing = args.ringFacing or dir
		local size = def.ringSize * scale * (if material == "Palm" then 1.4 else 1)
		Layers.shockRing(point + dir * 0.3, facing, {
			from = size * 0.18,
			to = size,
			life = if def.heavySparks then 0.25 else 0.18,
		})
		if def.rings > 1 then
			Layers.shockRing(point + dir * 0.8, facing, {
				from = size * 0.25,
				to = size * 1.3,
				life = 0.25,
				delayFrames = 2,
				alpha = 0.4,
			})
		end
	end
	if def.torsoRing and args.victim and not skipped(args, "ring") then
		local torso = basePart(args.victim, "Torso")
		if torso then
			Layers.shockRing(
				torso.Position,
				Vector3.yAxis,
				{ from = 1.2, to = 4 * scale, life = 0.28, delayFrames = 1, alpha = 0.45 }
			)
		end
	end

	-- F+1: specks; F+2: the puff off the clothes.
	local specks = def.specks
	if args.blood then
		specks = math.floor(specks / 2)
	end
	if material == "Bone" then
		Layers.chips(point, 4, Color3.fromRGB(235, 228, 210))
	end
	if specks > 0 and not skipped(args, "specks") then
		Layers.specks(point, dir, specks)
	end
	if
		def.puff > 0
		and material ~= "Glass"
		and material ~= "Guard"
		and not skipped(args, "puff")
	then
		local count = if material == "Palm" then 4 else (if def.heavySparks then 3 else 2)
		Layers.puff(point, dir, def.puff * scale * (if material == "Palm" then 1.5 else 1), count)
	end

	-- F+3: the warm second flash (Last).
	if def.secondFlash and not skipped(args, "flash") then
		Pool.afterFrames(3, function()
			Layers.contactFlash(point + dir * 0.2, def.flash * 0.8 * scale, {
				frames = 1,
				spikes = 0,
				color = Palette.FlashWarm,
			})
		end)
	end

	-- Floor dust ring (Heavy+, a floor near under the hit).
	local wantFloor = if args.floor ~= nil then args.floor else def.floor
	if wantFloor and def.floorPuffs > 0 and not skipped(args, "floor") then
		local under = if args.victim then basePart(args.victim, "HumanoidRootPart") else nil
		local from = if under then under.Position else point
		local floor = Floor.at(from, FLOOR_REACH)
		if floor then
			Layers.dustRing(floor.position, {
				puffs = def.floorPuffs,
				speed = def.floorSpeed,
				size = 0.8 * scale,
				color = Floor.dustColor(floor),
				groundRing = args.tier == "Last" or args.tier == "Slam",
			})
		end
	end
end

------------------------------------------------------------------------------
-- Slams, knockouts, landings, awakenings
------------------------------------------------------------------------------

export type SlamOpts = {
	attacker: Model?,
	victim: Model?,
	debris: number?,
	crack: number?,
	camera: boolean?,
	scale: number?,
}

-- A body / fist driven into the floor at `point`: a flash AT the floor, a
-- flat ground ring, dust shot out along the floor, debris with weight and
-- a crack that stays.
function Impact.groundSlam(point: Vector3, tier: Tier, opts: SlamOpts?)
	local o: SlamOpts = opts or {}
	local def = Tiers.get(tier)
	local scale = o.scale or 1
	local floor = Floor.at(point, 4)
	local at = if floor then floor.position else point
	local normal = if floor then floor.normal else Vector3.yAxis
	local dust = Floor.dustColor(floor)
	if o.attacker or o.victim then
		Impact.hitstop(o.attacker, o.victim, def.hitstop, -normal, def.jitter)
	end
	if o.camera ~= false then
		local involvement = Camera.involves(o.attacker, o.victim)
		if involvement > 0 then
			Camera.trauma(def.trauma * involvement * scale)
			if involvement >= 1 then
				Camera.fovPunch(def.fov * scale)
				Camera.kick(-normal, def.kick * scale)
				if def.dim > 0 then
					Camera.dim(def.dim)
				end
			end
		else
			Camera.trauma(def.trauma * 0.5 * scale, at, 50)
		end
	end
	local detail = Quality.detail(at)
	if detail == "None" then
		return
	end
	Layers.contactFlash(
		at + normal * 0.3,
		def.flash * scale,
		{ frames = def.flashFrames, dir = normal }
	)
	Layers.light(at + normal * 0.8, def.light, def.range * scale, { fade = def.fade })
	if detail ~= "Full" or not Quality.takeImpact() then
		return
	end
	Layers.shockRing(
		at + normal * 0.12,
		normal,
		{ from = 1 * scale, to = def.ringSize * scale, life = 0.3, alpha = 0.4, color = dust }
	)
	Layers.dustRing(
		at,
		{ puffs = def.floorPuffs, speed = def.floorSpeed, size = 1 * scale, color = dust }
	)
	Layers.chips(at + normal * 0.2, def.sparks, dust)
	Layers.puff(at + normal * 0.5, normal, def.puff * scale, 2, { color = dust })
	local debris = o.debris or 0
	if debris > 0 then
		Layers.debris(at, debris)
	end
	local crack = o.crack or 0
	if crack > 0 then
		Layers.crack(at, normal, crack * scale)
	end
end

-- The killing hit looks different: a warm 2nd flash at F+3, the dark ring
-- of pressure lines, a horizontal ring around the torso, a stronger
-- light, more sparks, floor dust; for the fighters a KO impact frame, a
-- deeper push-in and kick, and a longer hit-stop. Call it 2-3 frames after
-- the hit (HitFx does it when a hit knocks out).
function Impact.knockoutOverlay(args: ImpactArgs)
	local ko = Tiers.KNOCKOUT
	local point = args.point
	local dir = unitOr(args.dir, Vector3.zAxis)
	if args.hitstop ~= false and (args.attacker or args.victim) then
		Impact.hitstop(args.attacker, args.victim, ko.hitstop * 0.6, dir, 0.08)
	end
	if args.camera ~= false then
		local involvement = Camera.involves(args.attacker, args.victim)
		if involvement > 0 then
			Camera.trauma(ko.trauma * involvement)
		end
		if involvement >= 1 then
			Camera.impactFrame("KO")
			Camera.fovPunch(ko.fov)
			Camera.kick(dir, ko.kick)
		end
	end
	local detail = Quality.detail(point)
	-- skip.flash: a knockout by something that doesn't STRIKE (a choke's
	-- squeeze, a beam): no flash, sparks or rings in the scene, only the
	-- fighters' impact frame / push-in / hit-stop above.
	if detail == "None" or skipped(args, "flash") then
		return
	end
	Layers.contactFlash(
		point + dir * 0.2,
		ko.flash,
		{ frames = 1, spikes = 5, color = Palette.FlashWarm, dir = dir }
	)
	Layers.light(point - dir * 0.3, ko.light, ko.range, { fade = 0.16, color = Palette.FlashWarm })
	if detail ~= "Full" then
		return
	end
	Layers.pressureLines(point, dir, 3.2)
	Layers.sparkBurst(point, dir, { count = ko.sparks, heavy = true })
	local torso = basePart(args.victim, "Torso")
	Layers.shockRing(if torso then torso.Position else point, Vector3.yAxis, {
		from = ko.ringFrom,
		to = ko.ringTo,
		life = 0.3,
		alpha = 0.4,
	})
	local root = basePart(args.victim, "HumanoidRootPart")
	local floor = Floor.at(if root then root.Position else point, FLOOR_REACH)
	if floor then
		Layers.dustRing(
			floor.position,
			{ puffs = 8, speed = 16, size = 0.9, color = Floor.dustColor(floor), groundRing = true }
		)
	end
end

export type AwakeningStyle = "Street" | "Boxer" | "Bouncer"

-- A kit's Awakening beat (the moment the power "turns on"): the world
-- loses its colour for an instant, a short warm pop, dust pushed out along
-- the floor; and per style: Street = a breath of steam, Boxer = a tiny
-- pop between the gloves + sweat mist off the shoulders, Bouncer = a stomp
-- (crack, chips, a bigger dust ring). `beat` = where the pop is (default:
-- the chest).
function Impact.awakening(model: Model, style: AwakeningStyle, beat: Vector3?)
	local root = basePart(model, "HumanoidRootPart")
	local torso = basePart(model, "Torso")
	if root == nil then
		return
	end
	local camera = workspace.CurrentCamera
	local near = camera ~= nil and (camera.CFrame.Position - root.Position).Magnitude < 60
	local own = model == player.Character
	if near then
		Camera.desaturate(if own then 0.55 else 0.35, 0.2, 0.7)
		Camera.trauma(if own then 0.55 else 0.3, root.Position, 60)
	end
	if own then
		Camera.fovPunch(5)
	end
	local at = beat
		or (if torso then (torso.CFrame * CFrame.new(0, 0.2, -0.8)).Position else root.Position)
	if Quality.detail(at) == "None" then
		return
	end
	local look = root.CFrame.LookVector
	Layers.contactFlash(
		at,
		if style == "Boxer" then 1 else 1.6,
		{ frames = 2, color = Palette.FlashWarm, dir = look }
	)
	Layers.light(at, 9, 16, { fade = 0.3, color = Palette.FlashWarm })
	local floor = Floor.at(root.Position, 5)
	if floor then
		local dust = Floor.dustColor(floor)
		local stomp = style == "Bouncer"
		Layers.dustRing(floor.position, {
			puffs = if stomp then 14 else 10,
			speed = if stomp then 22 else 14,
			size = if stomp then 1.2 else 0.9,
			color = dust,
			groundRing = true,
		})
		if stomp then
			Layers.crack(floor.position, floor.normal, 5)
			Layers.chips(floor.position + Vector3.yAxis * 0.3, 14, dust)
			Layers.debris(
				floor.position,
				3,
				{ size = NumberRange.new(0.2, 0.45), up = NumberRange.new(14, 22) }
			)
		end
	end
	if style == "Street" then
		Layers.breath(model, { size = 0.5, count = 3 })
	elseif style == "Boxer" and torso then
		-- sweat mist off both shoulders
		for _, side in { -1, 1 } do
			local shoulder = (torso.CFrame * CFrame.new(side * 1, 1, 0)).Position
			Layers.specks(
				shoulder,
				Vector3.new(0, -1, 0) + torso.CFrame.RightVector * side,
				6,
				{ delayFrames = 0 }
			)
			Layers.puff(
				shoulder,
				Vector3.yAxis,
				0.6,
				1,
				{ color = Color3.fromRGB(215, 215, 212), delayFrames = 1, life = 0.8 }
			)
		end
	end
end

------------------------------------------------------------------------------
-- Landings
------------------------------------------------------------------------------

local landing: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local MAX_LANDINGS = 8
local landingCount = 0

-- Watches a knocked-down / launched body (up to 2.5 s): the first time it
-- hits the floor hard → dust ring (+ a crack if `strength` ≥ 1); the first
-- time it flies into a wall → a crack + chips on the wall. Once each.
-- `strength` ≈ 0.5 (a stagger) .. 1.5 (a powerbomb).
function Impact.landing(victim: Model, strength: number)
	if landing[victim] or landingCount >= MAX_LANDINGS then
		return
	end
	local root = basePart(victim, "HumanoidRootPart")
	if root == nil or Quality.detail(root.Position) == "None" then
		return
	end
	landing[victim] = true
	landingCount += 1
	local elapsed = 0
	local wasFalling = false
	local floorDone, wallDone = false, false
	local function finish()
		landing[victim] = nil
		landingCount -= 1
	end
	Pool.step(function(dt)
		elapsed += dt
		if elapsed > 2.5 or root.Parent == nil or (floorDone and wallDone) then
			finish()
			return false
		end
		local velocity = root.AssemblyLinearVelocity
		-- The wall: flying sideways fast into something.
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		if not wallDone and flat.Magnitude > 22 then
			local hit = Floor.ray(root.Position, flat.Unit * 2.4)
			if hit and math.abs(hit.normal.Y) < 0.5 then
				wallDone = true
				Layers.crack(hit.position, hit.normal, 2.5 * strength)
				Layers.chips(hit.position + hit.normal * 0.2, 8, Floor.dustColor(hit))
				Layers.puff(
					hit.position + hit.normal * 0.4,
					hit.normal,
					1.2,
					2,
					{ color = Floor.dustColor(hit), delayFrames = 0 }
				)
				Camera.trauma(0.5 * strength * Camera.involves(victim), hit.position, 40)
			end
		end
		-- The floor: was falling, now (nearly) stopped, floor right there.
		if velocity.Y < -10 then
			wasFalling = true
		elseif not floorDone and wasFalling and velocity.Y > -3 and elapsed > 0.1 then
			local floor = Floor.at(root.Position, 3.5)
			if floor then
				floorDone = true
				local dust = Floor.dustColor(floor)
				Layers.dustRing(floor.position, {
					puffs = math.floor(6 + 4 * strength),
					speed = 10 * strength + 4,
					size = 0.9,
					color = dust,
					groundRing = strength >= 1,
				})
				Layers.chips(floor.position + Vector3.yAxis * 0.2, math.floor(4 * strength), dust)
				if strength >= 1 then
					Layers.crack(floor.position, floor.normal, 2.5 * strength)
				end
				Camera.trauma(0.35 * strength * Camera.involves(victim), floor.position, 40)
			end
		end
		return true
	end)
end

------------------------------------------------------------------------------
-- Where a blow lands
------------------------------------------------------------------------------

local ZONE_PART: { [string]: string } = { Head = "Head", Torso = "Torso", Legs = "Right Leg" }

-- The struck part's surface toward the striking limb (or the attacker's
-- chest): the contact point, and the strike direction (attacker → victim).
-- `zone`: "Head" | "Torso" | "Legs" | "Guard" (the forearm on guard).
function Impact.contactPoint(
	victim: Model,
	attacker: Model,
	limb: Types.Limb?,
	zone: string?
): (Vector3, Vector3)
	local partName = ZONE_PART[zone or "Torso"] or "Torso"
	local part = basePart(victim, partName)
		or basePart(victim, "Torso")
		or basePart(victim, "HumanoidRootPart")
	local attackerRoot = basePart(attacker, "HumanoidRootPart")
	local from: Vector3? = if limb then Limb.tip(attacker, limb) else nil
	if from == nil and attackerRoot then
		from = attackerRoot.Position
			+ Vector3.yAxis
				* (if zone == "Head" then 1.5 elseif zone == "Legs" then -1.5 else 0.5)
	end
	if part == nil then
		local pivot = victim:GetPivot().Position
		return pivot, unitOr(pivot - (from or pivot - Vector3.zAxis), Vector3.zAxis)
	end
	if (zone == "Legs" or zone == "Guard") and from then
		-- the leg nearer the kick / the guarding forearm nearer the blow
		local first = basePart(victim, if zone == "Legs" then "Right Leg" else "Right Arm")
		local second = basePart(victim, if zone == "Legs" then "Left Leg" else "Left Arm")
		if first and second then
			part = if (second.Position - from).Magnitude < (first.Position - from).Magnitude
				then second
				else first
		end
	end
	local center = part.Position
	local origin = from or (center - victim:GetPivot().LookVector * 2)
	local dir = unitOr(
		center - origin,
		if attackerRoot then attackerRoot.CFrame.LookVector else Vector3.zAxis
	)
	-- Closest point of the part's box to the striking limb.
	local half = part.Size / 2
	local localPoint = part.CFrame:PointToObjectSpace(origin)
	local clamped = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)
	local point = part.CFrame:PointToWorldSpace(clamped)
	if (point - origin).Magnitude < 0.05 then
		-- the limb is inside the part already: use the surface toward the attacker
		point = center - dir * math.min(half.X, half.Z)
	end
	-- (a hair outside the surface, so the flash isn't hidden in the body)
	return point - dir * 0.1, dir
end

-- `point` moved by up to `amount` studs at random (repeated hits on one
-- spot never draw exactly the same).
Impact.jitter = function(point: Vector3, amount: number): Vector3
	return point
		+ Vector3.new(
				random:NextNumber(-1, 1),
				random:NextNumber(-1, 1),
				random:NextNumber(-1, 1)
			)
			* amount
end

-- (Config is read so the default hit delay is shared with the specs)
Impact.HIT_DELAY = Config.Combat.HIT_DELAY

return Impact
