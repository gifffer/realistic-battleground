--!strict
-- KitEffects: what kit moves LOOK and SOUND like, on this client.
-- (Purely visual: the server already decided everything.)
--
--   • Props: the bottle in the right hand during Bottle Smash, the broken
--     bottle neck during Broken Bottle. Built from a few parts, welded to
--     the hand for the length of the move, then removed.
--   • Glass: the bottle bursts into shards on the victim's head.
--   • Blood: a fighter with the "Bleeding" attribute drips from the head,
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
--   KitEffects.watch(model)                  bleeding / fury visuals

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local KitEffects = {}

-- Colours (dark, desaturated: realistic, not neon).
local GLASS_COLOR = Color3.fromRGB(74, 92, 58) -- green-brown beer bottle
local LABEL_COLOR = Color3.fromRGB(150, 128, 92) -- the paper label
local BLOOD_COLOR = Color3.fromRGB(92, 12, 10)
local FURY_LIGHT = Color3.fromRGB(150, 36, 28)

-- Bleeding: one drop this often (seconds), stains on the floor live this long.
local DRIP_INTERVAL = 0.22
local STAIN_LIFETIME = 9
-- Never more than this many stains in the world (16 players bleeding...).
local MAX_STAINS = 60

------------------------------------------------------------------------------
-- Moves by animation name (built from the kits' data)
------------------------------------------------------------------------------

local moveByAnimation: { [string]: Kits.MoveDef } = {}
local moveById: { [string]: Kits.MoveDef } = {}
for _, kit in Kits.list() do
	local lists = { kit.moves }
	local awakening = kit.awakening
	if awakening then
		table.insert(lists, awakening.moves)
	end
	for _, list in lists do
		for _, move in list do
			moveByAnimation[move.animation] = moveByAnimation[move.animation] or move
			moveById[move.id] = move
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
})
-- Moves with their own victim reaction (instead of the usual one by zone).
local REACTIONS: { [string]: string } = {
	LiverShot = "HitLiver",
}
-- Sound when the move LANDS.
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
}
-- Sound when the move STARTS (the swing).
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
}

function KitEffects.isMoveAnimation(animation: string): boolean
	return moveByAnimation[animation] ~= nil or START_SOUNDS[animation] ~= nil
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

-- Puts the prop in `model`'s right hand for `duration` seconds.
local function holdProp(model: Model, kind: string, duration: number)
	removeProp(model)
	local arm = model:FindFirstChild("Right Arm")
	if arm == nil or not arm:IsA("BasePart") then
		return
	end
	local prop = buildBottle(kind == "BrokenBottle")
	-- The grip is at the bottom of the arm (the fist), the bottle sticks out.
	local grip = arm.CFrame * CFrame.new(0, -0.85, 0)
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
	lifetime: number
)
	local random = Random.new()
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

-- One drop of blood falling from the head.
local function drip(model: Model)
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local random = Random.new()
	local start = (head.CFrame * CFrame.new(random:NextNumber(-0.3, 0.3), -0.2, -0.8)).Position
	local drop = Instance.new("Part")
	drop.Name = "BloodDrop"
	drop.Shape = Enum.PartType.Ball
	drop.Size = Vector3.new(0.09, 0.09, 0.09)
	drop.Material = Enum.Material.SmoothPlastic
	drop.Color = BLOOD_COLOR
	drop.CanCollide = false
	drop.CanQuery = false
	drop.CanTouch = false
	drop.CastShadow = false
	drop.Position = start
	drop.AssemblyLinearVelocity = head.AssemblyLinearVelocity * 0.5
	drop.Parent = workspace
	Debris:AddItem(drop, 0.8)
	-- Where it will land: stain the floor a moment later.
	task.delay(0.35, function()
		stain(start, random:NextNumber(0.25, 0.55))
	end)
end

-- A spray of blood from a cut (broken bottle).
local function spray(position: Vector3)
	burst(position, 6, BLOOD_COLOR, Enum.Material.SmoothPlastic, 0.1, 9, 1.2)
	stain(position, 0.9)
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
function KitEffects.onAction(model: Model, animation: string)
	local move = moveByAnimation[animation]
	local prop = if move then move.prop else nil
	if move and prop then
		holdProp(model, prop, move.duration)
	end
	local sound = START_SOUNDS[animation]
	if sound then
		SoundController.play(sound, model)
	end
end

-- Our move was refused by the server: take the prop back.
function KitEffects.stopAction(model: Model)
	removeProp(model)
end

-- A move landed on `victim` (Remotes.CombatEvent "Hit" with a moveId).
function KitEffects.onHit(victim: Model, attacker: Model, moveId: string, zone: string)
	SoundController.play(HIT_SOUNDS[moveId] or "Hit", victim)
	local head = victim:FindFirstChild("Head")
	local headPosition = if head and head:IsA("BasePart") then head.Position else nil
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
			burst(headPosition, 14, GLASS_COLOR, Enum.Material.Glass, 0.16, 16, 2.5)
		end
	end
	if moveId == "BrokenBottle" and headPosition then
		spray(headPosition)
	end
	if zone == "Legs" then
		local leg = victim:FindFirstChild("Right Leg")
		if leg and leg:IsA("BasePart") then
			burst(leg.Position, 3, Color3.fromRGB(90, 84, 76), Enum.Material.Sand, 0.12, 5, 0.8)
		end
	end
end

return table.freeze(KitEffects)
