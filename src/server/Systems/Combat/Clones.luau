--!strict
-- Clones: Dr. Rift's Awakening. Copies of him step out of portals and fight
-- with him for as long as it lasts. SERVER-AUTHORITATIVE.
--
-- A clone is a real fighter (Combat.register, no player, the "Rift" kit:
-- clients dress and animate it like anyone). Its state's `owner` = him:
--   • it never hits him or his other clones, they never hit it (resolveHit);
--   • what it deals counts as his (the KO, the Fury), × the Awakening's
--     `clones.damage`;
--   • ONE hit that lands on it and it's gone, back through a portal
--     (Clones.dispel, from resolveHit).
-- It walks to the closest enemy near him and punches (M1s). RIFT SWARM
-- (Gadgets.swarm) sends all of them through portals onto one fighter.
-- They leave when the Awakening ends, when he dies / leaves, or at a duel
-- round reset.
--
--   Clones.summon(owner, def)        the Awakening started
--   Clones.swarm(owner, victim, moveId, hits)
--   Clones.dispel(clone)             it was hit
--   Clones.dismissAll(ownerModel)    gone, all of them
--   Clones.damageScale(attacker)     × for its hits (1 if not a clone)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Knockout = require(script.Parent.Parent.Knockout)
local MapBounds = require(script.Parent.MapBounds)
local State = require(script.Parent.State)

type CombatState = State.CombatState
type HitSpec = State.HitSpec

export type Context = {
	register: (model: Model, player: Player?) -> (),
	setKit: (model: Model, kitId: string) -> (),
	getState: (model: Model) -> CombatState?,
	allStates: () -> { [Model]: CombatState },
	tryAttack: (model: Model) -> boolean,
	now: () -> number,
	isAlive: (state: CombatState) -> boolean,
	isAwakened: (state: CombatState) -> boolean,
	isStunned: (state: CombatState) -> boolean,
	isBusy: (state: CombatState) -> boolean,
	resolveHit: (attacker: CombatState, victim: CombatState, spec: HitSpec) -> boolean,
	specFor: (hit: Kits.HitDef, zone: Types.HitZone, moveId: string) -> HitSpec,
}

local Clones = {}

local THINK = 0.15 -- seconds between two decisions of a clone
local SEEK_RANGE = 45 -- studs from him: enemies further away are left alone
local LEASH = 30 -- a clone further than this from him with nothing to do comes back
local PUNCH_RANGE = 4.2
local OUT_TIME = 0.45 -- the portal swallowing it, then it's gone

local ctx: Context? = nil

function Clones.bind(context: Context)
	ctx = context
end

local function context(): Context
	assert(ctx, "[Clones] Combat.start() must call Clones.bind() first")
	return ctx
end

type Clone = {
	model: Model,
	state: CombatState,
	owner: CombatState,
	busyUntil: number, -- a swarm moves it by itself until then
	gone: boolean,
	slot: number, -- 1, 2...: its place by his side
}

local byOwner: { [Model]: { Clone } } = {}
local byModel: { [Model]: Clone } = {}

local function fx(kind: string, data: { [string]: any })
	Remotes.RiftFx:FireAllClients(kind, data)
end

local function face(root: BasePart, target: Vector3)
	local flat = Vector3.new(target.X, root.Position.Y, target.Z)
	if (flat - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, flat)
	end
end

-- A copy of his body: his avatar, his colours and clothes.
local function build(owner: CombatState): Model?
	local humanoid = owner.humanoid
	local ok, description = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	local model: Model? = nil
	if ok and description then
		local built, result = pcall(function()
			return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
		end)
		if built then
			model = result
		end
	end
	if model == nil then
		local plain = Instance.new("HumanoidDescription")
		local fine, result = pcall(function()
			return Players:CreateHumanoidModelFromDescription(plain, Enum.HumanoidRigType.R6)
		end)
		if not fine then
			return nil
		end
		model = result
	end
	local clone = model :: Model
	-- (his outfit colours / clothes as they are now)
	for _, item in owner.model:GetChildren() do
		if item:IsA("BodyColors") or item:IsA("Shirt") or item:IsA("Pants") then
			local existing = clone:FindFirstChildOfClass(item.ClassName)
			if existing then
				existing:Destroy()
			end
			local copy = (item :: Instance):Clone()
			copy.Parent = clone
		end
	end
	for _, partName in { "Head", "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		local mine = owner.model:FindFirstChild(partName)
		local theirs = clone:FindFirstChild(partName)
		if mine and mine:IsA("BasePart") and theirs and theirs:IsA("BasePart") then
			theirs.Color = mine.Color
		end
	end
	clone.Name = "Rift Clone"
	local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid") :: Humanoid
	cloneHumanoid.DisplayName = "Rift Clone"
	cloneHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	cloneHumanoid.MaxHealth = Config.Character.MAX_HEALTH
	cloneHumanoid.Health = Config.Character.MAX_HEALTH
	cloneHumanoid.WalkSpeed = 18
	return clone
end

-- Its way out: a portal swallows it.
local function remove(clone: Clone)
	if clone.gone then
		return
	end
	clone.gone = true
	-- (its blow that was winding up doesn't land any more)
	clone.state.attackToken += 1
	clone.state.stunnedUntil = math.huge
	byModel[clone.model] = nil
	local list = byOwner[clone.owner.model]
	if list then
		local index = table.find(list, clone)
		if index then
			table.remove(list, index)
		end
	end
	local model = clone.model
	if model.Parent then
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = true
			fx("CloneOut", { clone = model, at = root.CFrame })
		end
		model:SetAttribute("CloneLeaving", true)
	end
	task.delay(OUT_TIME, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

-- The closest enemy near him (not one of his, standing, same fight).
local function nearestEnemy(clone: Clone): CombatState?
	local c = context()
	local best: CombatState? = nil
	local bestDistance = math.huge
	local from = clone.state.root.Position
	for _, other in c.allStates() do
		if
			(other.owner or other) ~= clone.owner
			and c.isAlive(other)
			and not Knockout.isKnockedOut(other.model)
			and other.model:GetAttribute("DuelId") == clone.owner.model:GetAttribute("DuelId")
			and (other.root.Position - clone.owner.root.Position).Magnitude <= SEEK_RANGE
		then
			local distance = (other.root.Position - from).Magnitude
			if distance < bestDistance then
				best = other
				bestDistance = distance
			end
		end
	end
	return best
end

-- A free spot by `around` (a ring of tries), or nil.
local function spotNear(
	owner: CombatState,
	around: CFrame,
	distance: number,
	index: number
): CFrame?
	for try = 0, 7 do
		local angle = math.rad(index * 137 + try * 45)
		local offset = Vector3.new(math.sin(angle) * distance, 0, math.cos(angle) * distance)
		local position = around.Position + offset
		if MapBounds.allows(owner.model, position) then
			return CFrame.lookAt(position, Vector3.new(around.X, position.Y, around.Z))
		end
	end
	return nil
end

local function think(clone: Clone)
	local c = context()
	local state = clone.state
	local humanoid = state.humanoid
	if c.now() < clone.busyUntil or c.isStunned(state) or c.isBusy(state) then
		return
	end
	local enemy = nearestEnemy(clone)
	if enemy then
		local offset = enemy.root.Position - state.root.Position
		if offset.Magnitude <= PUNCH_RANGE then
			humanoid:MoveTo(state.root.Position)
			face(state.root, enemy.root.Position)
			c.tryAttack(clone.model)
		else
			humanoid:MoveTo(enemy.root.Position - offset.Unit * 2.5)
		end
	else
		-- Nothing to do: back to his side.
		local side = if clone.slot % 2 == 1 then -1 else 1
		local home = clone.owner.root.CFrame * CFrame.new(side * (2 + clone.slot), 0, 2)
		if (state.root.Position - clone.owner.root.Position).Magnitude > 6 then
			humanoid:MoveTo(home.Position)
		end
		if (state.root.Position - clone.owner.root.Position).Magnitude > LEASH then
			-- (only somewhere it may stand: not in a wall, not out of the room)
			local spot = if MapBounds.allows(clone.owner.model, home.Position)
				then home
				else spotNear(clone.owner, clone.owner.root.CFrame, 4, clone.slot)
			if spot then
				state.model:PivotTo(spot)
			end
		end
	end
end

-- One clone out of a portal at `at` (standing).
local function spawnOne(owner: CombatState, at: CFrame, slot: number): Clone?
	local c = context()
	local model = build(owner)
	if model == nil then
		return nil
	end
	-- (built while the avatar loaded: still wanted? never more than `count`)
	local kit = Kits.get(owner.kitId)
	local def = if kit and kit.awakening then kit.awakening.clones else nil
	local existing = byOwner[owner.model]
	if
		def == nil
		or (existing and #existing >= def.count)
		or not c.isAlive(owner)
		or not c.isAwakened(owner)
	then
		model:Destroy()
		return nil
	end
	model:PivotTo(at)
	local duel = owner.model:GetAttribute("DuelId")
	if duel ~= nil then
		model:SetAttribute("DuelId", duel)
	end
	model:SetAttribute("RiftClone", true)
	model.Parent = workspace
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and root:CanSetNetworkOwnership() then
		root:SetNetworkOwner(nil)
	end
	c.register(model, nil)
	c.setKit(model, "Rift")
	local state = c.getState(model)
	if state == nil then
		model:Destroy()
		return nil
	end
	state.owner = owner
	local clone: Clone =
		{ model = model, state = state, owner = owner, busyUntil = 0, gone = false, slot = slot }
	byModel[model] = clone
	local list = byOwner[owner.model] or {}
	byOwner[owner.model] = list
	table.insert(list, clone)
	fx("CloneIn", { clone = model, at = at })
	task.spawn(function()
		while not clone.gone and model.Parent and state.humanoid.Health > 0 do
			if
				not c.isAlive(owner)
				or not c.isAwakened(owner)
				or Knockout.isKnockedOut(owner.model)
			then
				break
			end
			think(clone)
			task.wait(THINK)
		end
		remove(clone)
	end)
	return clone
end

function Clones.summon(owner: CombatState, def: Kits.ClonesDef)
	Clones.dismissAll(owner.model)
	for index = 1, def.count do
		local side = if index % 2 == 1 then -1 else 1
		local at = owner.root.CFrame * CFrame.new(side * (2.6 + index), 0, 1.5)
		local place = if MapBounds.allows(owner.model, at.Position)
			then at
			else spotNear(owner, owner.root.CFrame, 4, index)
		if place then
			-- (a moment after the activation: out of the portals he opens)
			task.delay(0.35 + index * 0.15, function()
				if context().isAwakened(owner) and context().isAlive(owner) then
					spawnOne(owner, place, index)
				end
			end)
		end
	end
end

-- RIFT SWARM: every clone (a new one for each that was dispelled) through a
-- portal around `victim`, each landing `hits`.
function Clones.swarm(
	owner: CombatState,
	victim: CombatState,
	moveId: string,
	hits: { Kits.HitDef }
)
	local c = context()
	local kit = Kits.get(owner.kitId)
	local def = if kit and kit.awakening then kit.awakening.clones else nil
	if def == nil then
		return
	end
	local list = byOwner[owner.model] or {}
	local ready: { Clone } = table.clone(list)
	for index, clone in ready do
		local spot = spotNear(owner, victim.root.CFrame, 3, index)
		if spot then
			clone.busyUntil = c.now() + 1.4
			fx("CloneOut", { clone = clone.model, at = clone.state.root.CFrame, keep = true })
			task.delay(0.2, function()
				if not clone.gone and clone.model.Parent then
					clone.model:PivotTo(spot)
					fx("CloneIn", { clone = clone.model, at = spot })
				end
			end)
		end
	end
	-- Dispelled ones come back for it.
	for index = #ready + 1, def.count do
		local spot = spotNear(owner, victim.root.CFrame, 3, index)
		if spot then
			local made = spawnOne(owner, spot, index)
			if made then
				made.busyUntil = c.now() + 1.4
				table.insert(ready, made)
			end
		end
	end
	-- Their blows: each clone, at each hit's time (counted from arriving).
	for _, clone in ready do
		-- (a clone stunned meanwhile - parried - stops its blows)
		clone.state.attackToken += 1
		local token = clone.state.attackToken
		for _, hit in hits do
			task.delay(0.25 + hit.at, function()
				if
					clone.gone
					or clone.state.attackToken ~= token
					or c.isStunned(clone.state)
					or not c.isAlive(clone.state)
					or not c.isAlive(victim)
				then
					return
				end
				if Knockout.isKnockedOut(victim.model) then
					return
				end
				if (victim.root.Position - clone.state.root.Position).Magnitude > 7 then
					return -- they got away
				end
				face(clone.state.root, victim.root.Position)
				Remotes.CombatAction:FireAllClients(clone.model, "Rift_ClonePunch")
				local zone: Types.HitZone = hit.zone or "Torso"
				local spec = c.specFor(hit, zone, moveId)
				c.resolveHit(clone.state, victim, spec)
			end)
		end
	end
end

function Clones.dispel(clone: CombatState)
	local entry = byModel[clone.model]
	if entry then
		remove(entry)
	end
end

function Clones.dismissAll(ownerModel: Model)
	local list = byOwner[ownerModel]
	if list == nil then
		return
	end
	byOwner[ownerModel] = nil
	for _, clone in table.clone(list) do
		remove(clone)
	end
end

-- Damage × for a hit dealt by `attacker` (its owner's Awakening setting).
function Clones.damageScale(attacker: CombatState): number
	local owner = attacker.owner
	if owner == nil then
		return 1
	end
	local kit = Kits.get(owner.kitId)
	local def = if kit and kit.awakening then kit.awakening.clones else nil
	return if def then def.damage else 0.5
end

-- Is this model one of the clones (the KO / finisher code skips them)?
function Clones.isClone(model: Model): boolean
	return byModel[model] ~= nil or model:GetAttribute("RiftClone") == true
end

-- (owner gone from the game: his clones too)
Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	if character then
		Clones.dismissAll(character)
	end
end)
-- (a frame-cheap sweep: owners whose model left)
RunService.Heartbeat:Connect(function()
	for ownerModel in byOwner do
		if ownerModel.Parent == nil then
			Clones.dismissAll(ownerModel)
		end
	end
end)

return table.freeze(Clones)
