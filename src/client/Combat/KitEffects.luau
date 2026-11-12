--!strict
-- KitEffects: what kit moves LOOK and SOUND like, on this client.
-- (Purely visual: the server already decided everything.)
--
--   • Props: the bottle in the right hand during Bottle Smash, the broken
--     bottle neck during Broken Bottle. Built from a few parts, welded to
--     the hand for the length of the move, then removed.
--   • Glass: the bottle bursts into shards on the victim's head.
--   • Blood: a fighter with the "Bleeding" attribute drips from the wound,
--     and the drops leave small dark stains on the floor that fade away.
--   • Street Fury: an awakened fighter breathes heavy vapour and carries a
--     faint dark-red glow (nothing flashy: it's a street fight).
--   • Sounds per move (Shared/Sounds: Headbutt, Tackle, KickLow...).
--
-- Used by CombatEffectsController (everybody's moves and hits) and
-- KitController (our own moves, played the instant we press the key).
--
--   KitEffects.onAction(model, animation)    a move started on `model`
--   KitEffects.stopAction(model)             our move was refused: undo it
--   KitEffects.onHit(victim, attacker, moveId, zone)   a move landed
--   KitEffects.isHeavy(moveId)               big reaction (HitHeavy) for it?
--   KitEffects.grabOf(animation)             the grab a hold clip belongs to
--   KitEffects.keepsPose(moveId, victim)     no reaction clip (grabs, holds)
--   KitEffects.watch(model)                  bleeding / fury visuals

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Gash = require(ReplicatedStorage.Shared.Util.Gash)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local KitVFX = require(script.Parent.KitVFX)
local Blood = require(script.Parent.Blood)

local KitEffects = {}

-- Colours (dark, desaturated: realistic, not neon).
local GLASS_COLOR = Color3.fromRGB(74, 92, 58) -- green-brown beer bottle
local GLASS_SHINE = Color3.fromRGB(150, 172, 128) -- thin bits: lighter, they catch the light
local LABEL_COLOR = Color3.fromRGB(150, 128, 92) -- the paper label
local BLOOD_COLOR = Color3.fromRGB(92, 12, 10)
local FURY_LIGHT = Color3.fromRGB(150, 36, 28)

-- Bleeding: one drop this often (seconds), stains on the floor live this long.
local DRIP_INTERVAL = 0.22
local STAIN_LIFETIME = 30
-- Never more than this many stains in the world (16 players bleeding...).
local MAX_STAINS = 60

------------------------------------------------------------------------------
-- Moves by animation name (built from the kits' data)
------------------------------------------------------------------------------

local moveByAnimation: { [string]: Kits.MoveDef } = {}
local moveById: { [string]: Kits.MoveDef } = {}
-- The clips of the grabs' holds (both fighters'), with their grab.
local grabByClip: { [string]: Kits.GrabDef } = {}
-- The Awakenings' activation clips.
local awakenClips: { [string]: boolean } = {}
for _, kit in Kits.list() do
	local lists = { kit.moves }
	local awakening = kit.awakening
	if awakening then
		table.insert(lists, awakening.moves)
		awakenClips[awakening.animation] = true
	end
	for _, list in lists do
		for _, move in list do
			moveByAnimation[move.animation] = moveByAnimation[move.animation] or move
			moveById[move.id] = move
			local grab = move.grab
			if grab then
				grabByClip[grab.animation] = grab
				grabByClip[grab.victimAnimation] = grab
			end
		end
	end
end

-- Moves whose hit throws the head / body hard (HitHeavy reaction).
local HEAVY_MOVES = table.freeze({
	BottleSmash = true,
	Headbutt = true,
	DoubleHeadbutt = true,
	BrokenBottle = true,
	KickCombo = true,
	TackleSlam_FollowUp = true,
	Uppercut = true,
	UppercutPlus = true,
	KnockoutCombo = true,
	Slip_Counter = true,
	SlipPlus_Counter = true,
	Haymaker = true,
	Skyfall = true,
	GoreCharge = true,
	HornHook = true,
	Shove = true,
	HammerFist = true,
	DoubleHammer = true,
	-- (a grab's hits are its move id + "_Hold", see Server/Combat/Grab)
	BodySlam_Hold = true,
	Powerbomb_Hold = true,
	ThrowOut_Hold = true,
	BoneThrow = true, -- (a bone thrown into them, Shared/Weapons)
})
-- Moves with their own victim reaction (instead of the usual one by zone).
local REACTIONS: { [string]: string } = {
	LiverShot = "HitLiver",
}
-- Sound when the move LANDS ("" = none).
local HIT_SOUNDS: { [string]: string } = {
	BottleSmash = "BottleBreak",
	Headbutt = "Headbutt",
	DoubleHeadbutt = "Headbutt",
	Tackle = "Tackle",
	TackleSlam = "Tackle",
	TackleSlam_FollowUp = "HeavyHit",
	DirtyKick = "KickLow",
	KickCombo = "KickLow",
	BrokenBottle = "Hit",
	Uppercut = "HeavyHit",
	UppercutPlus = "HeavyHit",
	KnockoutCombo = "HeavyHit",
	SlipPlus_Counter = "HeavyHit",
	HeatVision = "", -- (no sound: the skin just chars where it touches)
	ThunderClap = "HeavyHit",
	Skyfall = "HeavyHit",
	Haymaker = "HeavyHit",
	GoreCharge = "Tackle",
	HornHook = "HeavyHit",
	Stampede = "KickLow",
	BullToss = "Tackle",
	Shove = "BodyShot",
	HammerFist = "HeavyHit",
	DoubleHammer = "HeavyHit",
	-- Grabs: the hands closing, then what the hold does.
	Chokehold = "Grab",
	SleeperHold = "Grab",
	BodySlam = "Grab",
	Powerbomb = "Grab",
	ThrowOut = "Grab",
	Chokehold_Hold = "Choke",
	SleeperHold_Hold = "Choke",
	BodySlam_Hold = "BodySlam",
	Powerbomb_Hold = "BodySlam",
	ThrowOut_Hold = "Tackle",
}
-- Sound when the move STARTS (the swing; "" = none).
local START_SOUNDS: { [string]: string } = {
	Brawler_Bottle = "HeavySwing",
	Brawler_BrokenBottle = "Slash",
	Brawler_Headbutt = "Swing",
	Brawler_DoubleHeadbutt = "Swing",
	Brawler_Tackle = "Dash",
	Brawler_DirtyKick = "Swing",
	Brawler_KickCombo = "Swing",
	Brawler_Awaken = "Awaken",
	Boxer_JabRush = "Swing",
	Boxer_JabRushPlus = "Swing",
	Boxer_Uppercut = "HeavySwing",
	Boxer_Slip = "Dash",
	Boxer_SlipCounter = "Swing",
	Boxer_LiverShot = "Swing",
	Boxer_KnockoutCombo = "HeavySwing",
	Boxer_Awaken = "Awaken",
	-- (the Sentinel and Bull moves play their own sounds at the right
	-- moment: KitVFX)
	Sentinel_HeatVision = "",
	Sentinel_ThunderClap = "",
	Sentinel_Skyfall = "",
	Sentinel_Haymaker = "",
	Bull_GoreCharge = "",
	Bull_HornHook = "HeavySwing",
	Bull_Stampede = "",
	Bull_Toss = "",
	Bouncer_Shove = "HeavySwing",
	Bouncer_Grab = "Swing",
	Bouncer_HammerFist = "HeavySwing",
	Bouncer_DoubleHammer = "HeavySwing",
	Bouncer_Awaken = "Awaken",
}

-- (a hold's clips are silent: the catch and its hits make the sounds)
function KitEffects.isMoveAnimation(animation: string): boolean
	return moveByAnimation[animation] ~= nil
		or START_SOUNDS[animation] ~= nil
		or grabByClip[animation] ~= nil
end

-- The grab whose hold plays this clip (on either fighter), or nil.
function KitEffects.grabOf(animation: string): Kits.GrabDef?
	return grabByClip[animation]
end

-- Is this an Awakening's activation clip (any kit)?
function KitEffects.isAwakening(animation: string): boolean
	return awakenClips[animation] == true
end

-- A hit that must not play a reaction clip on the victim: a grab's catch
-- (its hold clip comes right after) or anything landing on a held fighter
-- (its hold clip is playing).
function KitEffects.keepsPose(moveId: string?, victim: Model): boolean
	if victim:GetAttribute("Held") ~= nil then
		return true
	end
	local move = if moveId then moveById[moveId] else nil
	return move ~= nil and move.grab ~= nil
end

function KitEffects.isHeavy(moveId: string): boolean
	return HEAVY_MOVES[moveId] == true
end

-- The victim reaction clip of a move, or nil for the usual one.
function KitEffects.reactionFor(moveId: string): string?
	return REACTIONS[moveId]
end

------------------------------------------------------------------------------
-- Props
------------------------------------------------------------------------------

-- The prop currently in each fighter's hand.
local props: { [Model]: Model } = {}

local function glassPart(name: string, size: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder -- a cylinder's axis is its X
	part.Size = size
	part.Material = Enum.Material.Glass
	part.Color = GLASS_COLOR
	part.Transparency = 0.25
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- A bottle model held by its neck. Its pivot = the grip, its length goes
-- along -Y (out of the fist, along the arm). `broken` = only the jagged neck.
local function buildBottle(broken: boolean): Model
	local model = Instance.new("Model")
	model.Name = if broken then "BrokenBottle" else "Bottle"
	-- Turn a cylinder (axis X) so its axis goes along Y.
	local alongY = CFrame.Angles(0, 0, math.rad(90))

	local neck = glassPart("Neck", Vector3.new(0.45, 0.16, 0.16), model)
	neck.CFrame = CFrame.new(0, -0.18, 0) * alongY
	local shoulder = glassPart("Shoulder", Vector3.new(0.16, 0.24, 0.24), model)
	shoulder.CFrame = CFrame.new(0, -0.45, 0) * alongY
	if broken then
		-- Jagged edge: a few thin shards around the broken shoulder.
		for index = 0, 4 do
			local shard = Instance.new("WedgePart")
			shard.Name = "Shard"
			shard.Size = Vector3.new(0.05, 0.22 + (index % 2) * 0.12, 0.1)
			shard.Material = Enum.Material.Glass
			shard.Color = GLASS_COLOR
			shard.Transparency = 0.2
			shard.CanCollide = false
			shard.CanQuery = false
			shard.CanTouch = false
			shard.Massless = true
			local angle = index * (math.pi * 2 / 5)
			shard.CFrame = CFrame.Angles(0, angle, 0)
				* CFrame.new(0, -0.6, 0.11)
				* CFrame.Angles(math.rad(180), 0, 0)
			shard.Parent = model
		end
	else
		local body = glassPart("Body", Vector3.new(0.7, 0.34, 0.34), model)
		body.CFrame = CFrame.new(0, -0.9, 0) * alongY
		local label = glassPart("Label", Vector3.new(0.3, 0.35, 0.35), model)
		label.Material = Enum.Material.SmoothPlastic
		label.Color = LABEL_COLOR
		label.Transparency = 0
		label.CFrame = CFrame.new(0, -0.92, 0) * alongY
	end
	model.WorldPivot = CFrame.new()
	return model
end

local function removeProp(model: Model)
	local prop = props[model]
	if prop then
		props[model] = nil
		prop:Destroy()
	end
end

-- A wooden baseball bat held by its handle (finisher). Same layout as the
-- bottle: pivot = the grip, its length along -Y.
local BAT_WOOD = Color3.fromRGB(168, 118, 70)
local BAT_TILT = 32 -- degrees
local function buildBat(): Model
	local model = Instance.new("Model")
	model.Name = "Bat"
	local alongY = CFrame.Angles(0, 0, math.rad(90))
	local function piece(
		name: string,
		length: number,
		diameter: number,
		center: number,
		color: Color3,
		material: Enum.Material
	)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(length, diameter, diameter)
		part.Material = material
		part.Color = color
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = CFrame.new(0, -center, 0) * alongY
		part.Parent = model
	end
	-- A big bat, ~4.2 studs (the finisher's poses were solved with these
	-- lengths: the barrel lands on the head, both hands on the handle).
	-- (a long handle: room for both fists, the left one under the right)
	piece("Knob", 0.1, 0.3, -0.92, BAT_WOOD, Enum.Material.Wood)
	piece("Grip", 1.7, 0.17, -0.02, Color3.fromRGB(28, 28, 30), Enum.Material.Fabric) -- tape
	piece("Handle", 0.55, 0.19, 1.05, BAT_WOOD, Enum.Material.Wood)
	piece("Taper", 0.65, 0.28, 1.62, BAT_WOOD, Enum.Material.Wood)
	piece("Barrel", 1.3, 0.42, 2.6, BAT_WOOD, Enum.Material.Wood)
	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(0.42, 0.42, 0.42)
	tip.Material = Enum.Material.Wood
	tip.Color = BAT_WOOD
	tip.CanCollide = false
	tip.CanQuery = false
	tip.CanTouch = false
	tip.Massless = true
	tip.CFrame = CFrame.new(0, -3.25, 0)
	tip.Parent = model
	model.WorldPivot = CFrame.new()
	return model
end

-- Puts the prop in `model`'s right hand for `duration` seconds.
local function holdProp(model: Model, kind: string, duration: number)
	removeProp(model)
	local arm = model:FindFirstChild("Right Arm")
	if arm == nil or not arm:IsA("BasePart") then
		return
	end
	local prop = if kind == "Bat" then buildBat() else buildBottle(kind == "BrokenBottle")
	-- The grip is at the bottom of the arm (the fist), the bottle sticks out.
	-- The bat leans back across the fist, so both hands can hold it (the
	-- finisher's poses were solved with this angle: BAT_TILT).
	local grip = arm.CFrame
		* CFrame.new(0, -0.85, 0)
		* CFrame.Angles(0, 0, if kind == "Bat" then math.rad(BAT_TILT) else 0)
	prop:PivotTo(grip)
	for _, part in prop:GetChildren() do
		if part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = arm
			weld.Part1 = part
			weld.Parent = part
		end
	end
	prop.Parent = model
	props[model] = prop
	task.delay(duration, function()
		if props[model] == prop then
			removeProp(model)
		end
	end)
end

------------------------------------------------------------------------------
-- Glass and blood
------------------------------------------------------------------------------

-- Small pieces that fly from `position` and fall (debris, never collide
-- with players).
local function burst(
	position: Vector3,
	count: number,
	color: Color3,
	material: Enum.Material,
	size: number,
	speed: number,
	lifetime: number,
	seeded: Random?
)
	-- `seeded`: same random numbers on every client (pieces land the same).
	local random = seeded or Random.new()
	for _ = 1, count do
		local piece = Instance.new("Part")
		piece.Name = "Debris"
		piece.Size = Vector3.new(
			size * random:NextNumber(0.5, 1.2),
			size * random:NextNumber(0.2, 0.5),
			size * random:NextNumber(0.5, 1.2)
		)
		piece.Material = material
		piece.Color = color
		piece.Transparency = if material == Enum.Material.Glass then 0.3 else 0
		piece.Reflectance = if material == Enum.Material.Glass then 0.3 else 0 -- glass glints
		piece.CanCollide = true
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CollisionGroup = "Default"
		piece.CFrame = CFrame.new(position)
			* CFrame.Angles(random:NextNumber(0, 6.3), random:NextNumber(0, 6.3), 0)
		local direction = random:NextUnitVector()
		piece.AssemblyLinearVelocity = Vector3.new(
			direction.X,
			math.abs(direction.Y) + 0.4,
			direction.Z
		) * speed * random:NextNumber(0.5, 1)
		piece.AssemblyAngularVelocity = random:NextUnitVector() * 20
		piece.Parent = workspace
		Debris:AddItem(piece, lifetime)
	end
end

local stains: { BasePart } = {}

-- A flat dark stain where a drop lands, fading out slowly.
local function stain(position: Vector3, size: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- Through every fighter (the bleeding one first of all): only the floor.
	params.FilterDescendantsInstances = CollectionService:GetTagged(Config.Combat.TAG)
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position, Vector3.new(0, -12, 0), params)
	if
		hit == nil
		or hit.Instance.Parent and hit.Instance.Parent:FindFirstChildOfClass("Humanoid")
	then
		return
	end
	local mark = Instance.new("Part")
	mark.Name = "BloodStain"
	mark.Shape = Enum.PartType.Cylinder
	mark.Size = Vector3.new(0.02, size, size)
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanQuery = false
	mark.CanTouch = false
	mark.CastShadow = false
	mark.Material = Enum.Material.SmoothPlastic
	mark.Color = BLOOD_COLOR
	mark.Transparency = 0.15
	-- Lay the disc flat on the surface it hit.
	mark.CFrame = CFrame.lookAt(hit.Position + hit.Normal * 0.02, hit.Position + hit.Normal * 2)
		* CFrame.Angles(0, math.rad(90), 0)
	mark.Parent = workspace
	table.insert(stains, mark)
	if #stains > MAX_STAINS then
		local oldest = table.remove(stains, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	task.delay(STAIN_LIFETIME * 0.6, function()
		if mark.Parent then
			local fade = game:GetService("TweenService")
				:Create(mark, TweenInfo.new(STAIN_LIFETIME * 0.4), { Transparency = 1 })
			fade:Play()
			fade.Completed:Connect(function()
				local index = table.find(stains, mark)
				if index then
					table.remove(stains, index)
				end
				mark:Destroy()
			end)
		end
	end)
end

-- One drop of blood falling from the wound: a glass cut (Gash_*), else the
-- part that was hit ("BleedPart"), else the head.
local function dripStart(model: Model, random: Random): (Vector3?, BasePart?)
	-- The part that bleeds (set by the server), else any cut part.
	local bleedPart = model:GetAttribute("BleedPart")
	local wanted = if typeof(bleedPart) == "string" then bleedPart else nil
	local spots: { { part: BasePart, point: Vector3 } } = {}
	local function collect(onlyWanted: boolean)
		for name, value in model:GetAttributes() do
			local key = string.match(name, "^" .. Gash.PREFIX .. "(%a+)_%d+$")
				or string.match(name, "^" .. Gash.SHARD_PREFIX .. "(%a+)_%d+$")
			local partName = if key then Gash.PART_OF[key] else nil
			local cut = Gash.decode(value)
			if cut and cut.kind == "Burn" then
				cut = nil -- (a burn doesn't bleed: cauterized)
			end
			local shard = if cut then nil else Gash.decodeShard(value)
			local point = if cut then cut.point elseif shard then shard.point else nil
			local part = if partName then model:FindFirstChild(partName) else nil
			if
				point
				and part
				and part:IsA("BasePart")
				and (not onlyWanted or partName == wanted)
			then
				table.insert(spots, { part = part, point = point })
			end
		end
	end
	collect(true)
	if #spots == 0 and wanted == nil then
		collect(false)
	end
	if #spots > 0 then
		local spot = spots[random:NextInteger(1, #spots)]
		-- just under the wound, a little out of the skin
		local outward = Vector3.new(spot.point.X, 0, spot.point.Z)
		outward = if outward.Magnitude > 1e-3 then outward.Unit else Vector3.new(0, 0, -1)
		local at = spot.point + outward * 0.06 + Vector3.new(0, -0.08, 0)
		return (spot.part.CFrame * CFrame.new(at)).Position, spot.part
	end
	local part = model:FindFirstChild(wanted or "Head")
	if part == nil or not part:IsA("BasePart") then
		return nil, nil
	end
	local depth = if part.Name == "Head" then 0.8 else part.Size.Z / 2 + 0.06
	local y = if part.Name == "Head" then -0.2 else random:NextNumber(-0.5, 0.5)
	return (part.CFrame * CFrame.new(random:NextNumber(-0.3, 0.3), y, -depth)).Position, part
end

local function drip(model: Model)
	local random = Random.new()
	local start, part = dripStart(model, random)
	if start == nil or part == nil then
		return
	end
	-- (a real drop: it falls, stretches, splashes where it lands)
	Blood.drop(start, part.AssemblyLinearVelocity * 0.5, random:NextNumber(0.05, 0.1))
end

------------------------------------------------------------------------------
-- Watched fighters: bleeding drips and Street Fury
------------------------------------------------------------------------------

type Watched = {
	model: Model,
	nextDrip: number,
	fury: { Instance }?, -- the Street Fury visuals while awakened
}

local watched: { [Model]: Watched } = {}

local function setFury(entry: Watched, on: boolean)
	if on == (entry.fury ~= nil) then
		return
	end
	if not on then
		for _, instance in entry.fury :: { Instance } do
			instance:Destroy()
		end
		entry.fury = nil
		return
	end
	local torso = entry.model:FindFirstChild("Torso")
	local head = entry.model:FindFirstChild("Head")
	if torso == nil or head == nil then
		return
	end
	-- A faint dark-red glow on the body.
	local light = Instance.new("PointLight")
	light.Name = "FuryGlow"
	light.Color = FURY_LIGHT
	light.Brightness = 0.9
	light.Range = 7
	light.Shadows = false
	light.Parent = torso
	-- Heavy breath: short puffs of vapour in front of the mouth.
	local mouth = Instance.new("Attachment")
	mouth.Name = "FuryBreath"
	mouth.Position = Vector3.new(0, -0.2, -0.6)
	mouth.Parent = head
	local breath = Instance.new("ParticleEmitter")
	breath.Name = "Breath"
	breath.Texture = "rbxasset://textures/particles/smoke_main.dds"
	breath.Color = ColorSequence.new(Color3.fromRGB(200, 196, 190))
	breath.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	breath.Size = NumberSequence.new(0.2, 0.9)
	breath.Lifetime = NumberRange.new(0.5, 0.8)
	breath.Rate = 3
	breath.Speed = NumberRange.new(1.5, 2.5)
	breath.SpreadAngle = Vector2.new(12, 12)
	breath.EmissionDirection = Enum.NormalId.Front
	breath.LightInfluence = 1
	breath.Parent = mouth
	local created: { Instance } = { light, mouth }
	entry.fury = created
end

-- A finisher with a kill effect (Shop): "Dust" or "Glass" at `position`.
-- ("Impact" is the screen part, done by CombatEffectsController.)
function KitEffects.killEffect(effect: string, position: Vector3)
	if effect == "Dust" then
		burst(position, 12, Color3.fromRGB(150, 140, 124), Enum.Material.Sand, 0.18, 10, 1.4)
	elseif effect == "Glass" then
		burst(position + Vector3.new(0, 1, 0), 18, GLASS_COLOR, Enum.Material.Glass, 0.16, 18, 2.5)
	end
end

function KitEffects.watch(model: Model)
	if watched[model] then
		return
	end
	local entry: Watched = { model = model, nextDrip = 0, fury = nil }
	watched[model] = entry
	model:GetAttributeChangedSignal("Awakened"):Connect(function()
		setFury(entry, model:GetAttribute("Awakened") == true)
	end)
	setFury(entry, model:GetAttribute("Awakened") == true)
	-- The server cuts a move when its fighter is stunned / knocked down /
	-- out: its effects (heat vision beam, landing...) stop with it.
	for _, attribute in { "Stunned", "KnockedOut", "Ragdolled" } do
		model:GetAttributeChangedSignal(attribute):Connect(function()
			if model:GetAttribute(attribute) == true then
				KitVFX.stop(model)
			end
		end)
	end
	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			watched[model] = nil
			removeProp(model)
		end
	end)
end

RunService.Heartbeat:Connect(function()
	local time = os.clock()
	for model, entry in watched do
		if model:GetAttribute("Bleeding") == true and time >= entry.nextDrip then
			entry.nextDrip = time + DRIP_INTERVAL * Random.new():NextNumber(0.7, 1.4)
			drip(model)
		end
	end
end)

------------------------------------------------------------------------------
-- Moves starting and landing
------------------------------------------------------------------------------

-- A move started on `model` (animation name from Remotes.CombatAction, or
-- our own key press): prop in hand and the swing sound.
-- (each move started on a model gets a number: its later swings are
-- skipped if it was cut short, or replaced by another move)
local swingToken: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

function KitEffects.onAction(model: Model, animation: string, silent: boolean?)
	local move = moveByAnimation[animation]
	local prop = if move then move.prop else nil
	if move and prop then
		holdProp(model, prop, move.duration)
	end
	local token = (swingToken[model] or 0) + 1
	swingToken[model] = token
	KitVFX.onAction(model, animation, move)
	local sound = START_SOUNDS[animation]
	if sound and sound ~= "" and not silent then
		SoundController.play(sound, model)
		-- A flurry (jab rush, kick combo...): every blow whooshes, not just
		-- the first one.
		if move and #move.hits > 1 then
			local first = move.hits[1].at
			for index = 2, #move.hits do
				local at = move.hits[index].at
				task.delay(math.max(0, at - first), function()
					if swingToken[model] == token and model.Parent then
						SoundController.play(sound, model)
					end
				end)
			end
		end
	end
end

-- The finisher's bat in `model`'s hand for `duration` seconds.
function KitEffects.showBat(model: Model, duration: number)
	holdProp(model, "Bat", duration)
end

-- Our move was refused by the server: take the prop back.
function KitEffects.stopAction(model: Model)
	swingToken[model] = (swingToken[model] or 0) + 1 -- (no more swings of it)
	KitVFX.stop(model)
	removeProp(model)
end

-- A move landed on `victim` (Remotes.CombatEvent "Hit" with a moveId).
function KitEffects.onHit(victim: Model, attacker: Model, moveId: string, zone: string)
	local hitSound = HIT_SOUNDS[moveId] or "Hit"
	if hitSound ~= "" then
		SoundController.play(hitSound, victim)
	end
	KitVFX.onHit(victim, attacker, moveId)
	-- Where it landed (the bottle goes where it's aimed: head or torso).
	local struck = victim:FindFirstChild(if zone == "Head" then "Head" else "Torso")
	local headPosition = if struck and struck:IsA("BasePart") then struck.Position else nil
	local move = moveById[moveId]
	local breaks = false
	if move then
		for _, hit in move.hits do
			if hit.breaksProp then
				breaks = true
			end
		end
	end
	if breaks then
		-- The bottle bursts on the head: shards everywhere, only the neck
		-- stays in the hand for the rest of the move.
		local prop = props[attacker]
		if prop then
			for _, part in prop:GetChildren() do
				if part.Name ~= "Neck" then
					part:Destroy()
				end
			end
		end
		if headPosition then
			-- Big pieces, then a spray of small glittering bits that stay on
			-- the floor a while.
			burst(headPosition, 12, GLASS_COLOR, Enum.Material.Glass, 0.16, 16, 4)
			burst(headPosition, 22, GLASS_SHINE, Enum.Material.Glass, 0.06, 20, 6)
		end
	end
	if zone == "Legs" then
		local leg = victim:FindFirstChild("Right Leg")
		if leg and leg:IsA("BasePart") then
			burst(leg.Position, 3, Color3.fromRGB(90, 84, 76), Enum.Material.Sand, 0.12, 5, 0.8)
		end
	end
end

------------------------------------------------------------------------------
-- Blood and torn skin (decided by the server, see Remotes.CombatEvent)
------------------------------------------------------------------------------

-- Raw flesh under torn skin: wet, dark red.
local FLESH_COLOR = Color3.fromRGB(128, 26, 28)
-- Never more than this many pieces of skin lying around (16 players...).
local MAX_SKIN_PIECES = 40
local SKIN_PIECE_LIFETIME = 20
local skinPieces = 0

-- The point of `part` facing `attacker` (where the blow landed).
local function impactPoint(part: BasePart, attacker: Model): (Vector3, Vector3)
	local toward = attacker:GetPivot().Position - part.Position
	local flat = Vector3.new(toward.X, 0, toward.Z)
	local direction = if flat.Magnitude > 1e-3 then flat.Unit else part.CFrame.LookVector
	return part.Position + direction * 0.5, direction
end

-- A hit that draws blood (Blood): drops and strings of it thrown out of
-- the wound away from the blow (a little back at the attacker too), the
-- wound itself bloody, the attacker's fist bloody, the drops splashing
-- where they land (floor, walls, bodies). `amount`: 1 a punch, more for
-- heavy blows (2-3).
function KitEffects.bloodSpray(victim: Model, attacker: Model, zone: string, amount: number?)
	local partName = if zone == "Head"
		then "Head"
		elseif zone == "Legs" then "Right Leg"
		else "Torso"
	local part = victim:FindFirstChild(partName)
	if part == nil or not part:IsA("BasePart") then
		return
	end
	local _, toward = impactPoint(part, attacker)
	local much = (amount or 1) * (if zone == "Head" then 1.25 else 1)
	-- The wound, on the real skin facing the blow (the classic head is
	-- round, 0.6 across; its part is a wider box).
	local point: Vector3
	local normal = toward
	if part.Name == "Head" then
		point = part.Position + toward * 0.62
	else
		local only = RaycastParams.new()
		only.FilterType = Enum.RaycastFilterType.Include
		only.FilterDescendantsInstances = { part }
		local hit = workspace:Raycast(part.Position + toward * 4, -toward * 4, only)
		point = if hit then hit.Position else part.Position + toward * 0.5
		normal = if hit then hit.Normal else toward
		-- the side of the torso / the inner side of a leg is hidden (under
		-- the arm, against the other leg): the front or back face instead,
		-- at its edge on the blow's side
		local right = part.CFrame.RightVector
		if math.abs(normal:Dot(right)) > 0.9 then
			local look = part.CFrame.LookVector
			local facing = if toward:Dot(look) >= 0 then 1 else -1
			local l = part.CFrame:PointToObjectSpace(point)
			local half = part.Size / 2
			point = part.CFrame
				* Vector3.new(
					math.sign(l.X) * (half.X - 0.15),
					math.clamp(l.Y, -half.Y + 0.15, half.Y - 0.15),
					-facing * half.Z
				)
			normal = look * facing
		end
	end
	local random = Random.new()
	local side = toward:Cross(Vector3.yAxis)
	local out = point + normal * 0.08 -- (just outside the skin, not inside the body)
	-- most of it thrown back out of the struck skin, up and fanned sideways
	Blood.spray(
		out,
		normal + side * random:NextNumber(-1, 1) + Vector3.new(0, 0.6, 0),
		much * 0.8,
		victim
	)
	-- some carried along the blow, along the skin
	Blood.spray(
		out,
		side * (if random:NextNumber() < 0.5 then 1 else -1) - toward * 0.3 + Vector3.new(0, 0.4, 0),
		much * 0.35,
		victim,
		true
	)
	-- the wound itself: blood on the skin / clothes there
	Blood.splat(point, normal, 0.22 + 0.06 * much, Vector3.new(0, -3, 0), part)
	-- the fist (or foot) that did it, bloody: its end, if it's close
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, name in { "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		local limb = attacker:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			local tip = (limb.CFrame * CFrame.new(0, -limb.Size.Y / 2, 0)).Position
			local distance = (tip - point).Magnitude
			if distance < bestDistance then
				best, bestDistance = limb, distance
			end
		end
	end
	if best and bestDistance < 3 and random:NextNumber() < 0.6 then
		-- (a fist: its end; a foot: its front, above the sole)
		local isLeg = best.Name == "Right Leg" or best.Name == "Left Leg"
		local tip = if isLeg
			then (best.CFrame * CFrame.new(0, -best.Size.Y / 2 + 0.3, -best.Size.Z / 2)).Position
			else (best.CFrame * CFrame.new(0, -best.Size.Y / 2, 0)).Position
		local face = if isLeg then best.CFrame.LookVector else -best.CFrame.UpVector
		Blood.splat(tip, face, 0.16 + 0.04 * much, Vector3.zero, best)
	end
end

-- Glass cutting the skin (face, torso or leg, from `zone`): a spray of blood
-- and, sometimes, a tiny shred of skin flicked off by the glass. `seed`
-- comes from the server: every client shows exactly the same thing. The cut
-- that stays is drawn by Gashes (the "Gash_<Part>_<n>" attributes).
function KitEffects.skinTear(victim: Model, attacker: Model, seed: number, zone: string?)
	local partName = "Head"
	if zone == "Torso" then
		partName = "Torso"
	elseif zone == "Legs" then
		-- the leg closest to the attacker
		local left = victim:FindFirstChild("Left Leg")
		local right = victim:FindFirstChild("Right Leg")
		local from = attacker:GetPivot().Position
		partName = "Right Leg"
		if left and right and left:IsA("BasePart") and right:IsA("BasePart") then
			if (left.Position - from).Magnitude < (right.Position - from).Magnitude then
				partName = "Left Leg"
			end
		end
	end
	local head = victim:FindFirstChild(partName) -- the torn part
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local random = Random.new(seed)
	local point, toward = impactPoint(head, attacker)
	local away = -toward
	local skin = head.Color

	local count = random:NextInteger(0, 2) -- glass cuts; it rarely rips skin away
	for index = 1, count do
		if skinPieces >= MAX_SKIN_PIECES then
			break
		end
		-- Thin, irregular flaps: skin on some, the flesh under it on others.
		local piece = Instance.new("Part")
		piece.Name = "TornSkin"
		piece.Size = Vector3.new(
			random:NextNumber(0.05, 0.1),
			random:NextNumber(0.015, 0.025),
			random:NextNumber(0.04, 0.08)
		)
		piece.Material = Enum.Material.SmoothPlastic
		local isFlesh = index % 2 == 0
		piece.Color = if isFlesh then FLESH_COLOR else skin
		piece.Reflectance = if isFlesh then 0.12 else 0 -- wet
		piece.CanCollide = true
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CollisionGroup = "Default"
		piece.CFrame = CFrame.new(point + random:NextUnitVector() * 0.15)
			* CFrame.Angles(random:NextNumber(0, 6.3), random:NextNumber(0, 6.3), 0)
		-- Ripped off by the blow: away from the attacker, up, spread out.
		local spread = random:NextUnitVector() * 0.6
		local direction = (away + Vector3.new(0, random:NextNumber(0.5, 1.1), 0) + spread).Unit
		piece.AssemblyLinearVelocity = direction * random:NextNumber(5, 9)
		piece.AssemblyAngularVelocity = random:NextUnitVector() * 25
		piece.Parent = workspace
		skinPieces += 1
		task.delay(SKIN_PIECE_LIFETIME, function()
			skinPieces -= 1
			piece:Destroy()
		end)
	end

	-- Bleeding from the fresh cut (same drops on every client).
	burst(point, 9, BLOOD_COLOR, Enum.Material.SmoothPlastic, 0.1, 9, 1.4, random)
	stain(point + away * 0.8, 1.3)
	stain(point + away * 1.6 + Vector3.new(random:NextNumber(-0.4, 0.4), 0, 0), 0.7)
end

return table.freeze(KitEffects)
