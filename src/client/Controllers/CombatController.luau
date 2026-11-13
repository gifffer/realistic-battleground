--!strict
-- CombatController: fighting inputs (M1, block, dash).
--
--   Left click (hold)  → M1 combo         → Remotes.Attack
--   F (hold)           → block / parry    → Remotes.SetBlocking
--   Q                  → dash             → moves now + Remotes.Dash
--
-- The client NEVER decides a hit, damage or a stun: it only asks. To feel
-- instant it mirrors the server's timing rules (so it doesn't send requests
-- the server would refuse) and plays the animations and sounds right away.
-- No fighting during a slide / climb / vault (same rule as the server).
--
-- Dash: the character is moved by this client (Roblox lets each client
-- simulate its own character). The server checks the cooldown/stamina and
-- grants the dodge frames.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Push = require(ReplicatedStorage.Shared.Util.Push)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SafeZone = require(ReplicatedStorage.Shared.Util.SafeZone)
local Weapons = require(ReplicatedStorage.Shared.Weapons)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local AimController = require(script.Parent.AimController)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local KnockoutController = require(script.Parent.KnockoutController)
local ParkourController = require(script.Parent.ParkourController)
local SoundController = require(script.Parent.SoundController)

local C = Config.Combat
local K = Config.Knockout
local player = Players.LocalPlayer

local CombatController = {}

local attackHeld = false
local blockHeld = false -- F is pressed
local blocking = false -- we asked the server to block
local blockRequestedAt = 0
-- If the server still says "not blocking" this long after we asked, it
-- refused (or ended the block): we stop showing a block.
local BLOCK_CONFIRM_TIME = 0.3

-- Mirror of the server's combo timing (only used to avoid useless requests
-- and to pick the right animation).
local combo = 0
local lastAttackAt = -math.huge
local nextAttackAt = 0
local nextDashAt = 0
-- When we last PREDICTED a finisher (to reconcile with the server's choice).
local predictedFinisherAt = -math.huge
-- A cinematic finisher asked for: the time we wait for the server's answer.
local CINEMATIC_WAIT = 0.4
-- Number of our last M1 (see tryAttack).
local attackSeq = 0

-- One of our M1 just started (not the KO finisher). CombatEffectsController
-- listens to it to show the hit the instant our fist lands. (A signal, not a
-- direct call: CombatEffectsController already requires this module, and two
-- modules can't require each other.)
export type AttackInfo = {
	strong: boolean, -- the 4th hit of the combo
	aim: Vector3?, -- AimController.getAimDirection(), sent to the server
	id: number, -- this M1's number, echoed back in Remotes.CombatEvent
}
local attackStarted = Signal.new() :: Signal.Signal<AttackInfo>
-- The server answers within this long (else it's an old action).
local RECONCILE_WINDOW = 0.6

local function getCharacterParts(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	-- Knocked out: can't do anything until we get up.
	if character:GetAttribute("KnockedOut") == true then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function isStunned(character: Model): boolean
	return character:GetAttribute("Stunned") == true
end

-- Sliding, climbing or vaulting: hands and legs are busy.
local function isBusyMoving(): boolean
	local state = ParkourController.getVisualState()
	return state == "Slide" or state == "Climb" or state == "Vault"
end

-- A knocked-out opponent we can finish: close, in front (same rule as the
-- server's Knockout.findFinishTarget; the server decides for real).
local function findFinishTarget(root: BasePart): Model?
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	for _, instance in CollectionService:GetTagged(C.TAG) do
		if instance:IsA("Model") and instance ~= player.Character then
			local torso = instance:FindFirstChild("Torso")
			local available = instance:GetAttribute("KnockedOut") == true
				and instance:GetAttribute("BeingFinished") ~= true
			if
				available
				and torso
				and torso:IsA("BasePart")
				and not SafeZone.contains(torso.Position) -- (nobody is finished in the park)
			then
				local offset = torso.Position - root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local distance = flat.Magnitude
				local inFront = distance < 1.5 or flat.Unit:Dot(forward) > 0.35
				if distance <= K.FINISH_RANGE and inFront and math.abs(offset.Y) < 6 then
					return instance
				end
			end
		end
	end
	return nil
end

-- Our kit's finisher (the Street Brawler stomps, others kneel and strike).
local function myFinisher(character: Model): Kits.FinisherDef
	local kitId = character:GetAttribute("Kit")
	return Kits.finisher(if typeof(kitId) == "string" then kitId else nil)
end

-- In a cinematic finisher (ours, or we're its victim): no input counts.
local function inCinematic(character: Model): boolean
	return character:GetAttribute("InCinematic") == true
end

local function tryAttack()
	local character, _, root = getCharacterParts()
	local time = os.clock()
	if
		character == nil
		or root == nil
		or blocking
		or isStunned(character)
		or inCinematic(character)
		or isBusyMoving()
		or time < nextAttackAt
		or SafeZone.contains(root.Position) -- the park is a safe zone (the server refuses too)
	then
		return
	end

	-- Opponent down in front of us: finish them (the server confirms).
	if findFinishTarget(root) then
		local finisher = myFinisher(character)
		combo = 0
		lastAttackAt = time
		if finisher.cinematic then
			-- A cutscene: nothing predicted, it starts when the server says so
			-- (CinematicController holds our attacks for its length).
			nextAttackAt = time + CINEMATIC_WAIT
		else
			predictedFinisherAt = time
			nextAttackAt = time + finisher.duration
			CharacterAnimationController.playAction(character, finisher.animation)
			SoundController.play("HeavySwing", character)
		end
		KnockoutController.onFinishStarted()
		Remotes.Attack:FireServer(AimController.getAimDirection())
		return
	end

	-- Holding something to throw (Shared/Weapons): the click throws it.
	local weapon = Weapons.get(character:GetAttribute("Weapon"))
	if weapon then
		combo = 0
		lastAttackAt = time
		nextAttackAt = time + weapon.recovery
		CharacterAnimationController.playAction(character, "Bone_Throw")
		SoundController.play("HeavySwing", character)
		Remotes.ThrowWeapon:FireServer(AimController.getAimDirection())
		return
	end

	if time - lastAttackAt > C.COMBO_RESET then
		combo = 0
	end
	combo = combo % #C.M1_DAMAGE + 1
	local isFinisher = combo == #C.M1_DAMAGE
	lastAttackAt = time
	nextAttackAt = time + (if isFinisher then C.FINISHER_RECOVERY else C.M1_INTERVAL)

	CharacterAnimationController.playAction(character, `Brawler_M1_{combo}`)
	SoundController.play(if isFinisher then "HeavySwing" else "Swing", character)
	-- Each M1 gets a number, sent to the server and echoed back with its
	-- result, so our prediction below is matched with THIS punch only.
	attackSeq += 1
	local seq = attackSeq
	local aim = AimController.getAimDirection()
	Remotes.Attack:FireServer(aim, seq)
	attackStarted.fire({ strong = isFinisher, aim = aim, id = seq })
end

local function setBlocking(value: boolean)
	if blocking == value then
		return
	end
	if value then
		local character = getCharacterParts()
		-- Same rule as the server: no block in the middle of an attack.
		if
			character == nil
			or isStunned(character)
			or inCinematic(character)
			or isBusyMoving()
			or os.clock() < lastAttackAt + C.M1_INTERVAL
		then
			return
		end
		blockRequestedAt = os.clock()
	end
	blocking = value
	CharacterAnimationController.setPredictedBlock(value)
	Remotes.SetBlocking:FireServer(value)
end

-- Which way to dash: where the player is walking, or backwards if standing still.
-- Returns the direction and the animation name.
local function getDashDirection(humanoid: Humanoid, root: BasePart): (Vector3, string)
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local move = humanoid.MoveDirection
	if move.Magnitude < 0.1 then
		return -forward, "DashBack"
	end
	local direction = Vector3.new(move.X, 0, move.Z).Unit
	local right = forward:Cross(Vector3.yAxis)
	local along, side = direction:Dot(forward), direction:Dot(right)
	if math.abs(along) >= math.abs(side) then
		return direction, if along > 0 then "DashForward" else "DashBack"
	end
	return direction, if side > 0 then "DashRight" else "DashLeft"
end

local function tryDash()
	local character, humanoid, root = getCharacterParts()
	local time = os.clock()
	if character == nil or humanoid == nil or root == nil then
		return
	end
	if
		blocking
		or isStunned(character)
		or inCinematic(character)
		or isBusyMoving()
		or time < nextDashAt
	then
		return
	end
	local stamina = player:GetAttribute("Stamina")
	if typeof(stamina) ~= "number" or stamina < C.DASH_STAMINA_COST then
		return
	end

	nextDashAt = time + C.DASH_COOLDOWN
	local direction, animation = getDashDirection(humanoid, root)
	Push.apply(root, direction * (C.DASH_DISTANCE / C.DASH_TIME), C.DASH_TIME)
	CharacterAnimationController.playAction(character, animation)
	SoundController.play("Dash", character)
	Remotes.Dash:FireServer(animation)
end

-- The server tells everyone what we really did (Remotes.CombatAction). We
-- normally predicted it already; this fixes the rare case where the server
-- chose differently (the KO'd target was just taken / got up, or we didn't
-- see it yet). Called by CombatEffectsController for OUR character.
function CombatController.onServerAction(action: string)
	local character = player.Character
	if character == nil then
		return
	end
	local time = os.clock()
	local predictedFinisher = time - predictedFinisherAt <= RECONCILE_WINDOW
	local finisher = myFinisher(character)
	if action == finisher.animation and not predictedFinisher then
		-- The server finished someone we didn't see as finishable: show it.
		CharacterAnimationController.playAction(character, finisher.animation)
		combo = 0
		nextAttackAt = math.max(nextAttackAt, time + finisher.duration)
	elseif string.sub(action, 1, 11) == "Brawler_M1_" and predictedFinisher then
		-- We predicted a finisher but the server threw a normal punch.
		predictedFinisherAt = -math.huge
		CharacterAnimationController.playAction(character, action)
		combo = tonumber(string.sub(action, 12)) or 1
		nextAttackAt = lastAttackAt + C.M1_INTERVAL
	elseif string.sub(action, 1, 11) == "Brawler_M1_" then
		-- Follow the server's count of the combo (a punch it refused would
		-- otherwise put us one ahead: our "4th" being its 3rd...).
		local serverCombo = tonumber(string.sub(action, 12))
		if serverCombo and serverCombo ~= combo then
			combo = serverCombo
			local pause = if serverCombo == #C.M1_DAMAGE then C.FINISHER_RECOVERY else C.M1_INTERVAL
			nextAttackAt = math.max(nextAttackAt, lastAttackAt + pause)
		end
	end
end

-- For KitController (keys 1–4): can we start a move right now? Same rules
-- as an M1 (not blocking, not stunned, not sliding, not mid-attack).
function CombatController.canStartMove(): boolean
	local character, _, root = getCharacterParts()
	return character ~= nil
		and root ~= nil
		and not SafeZone.contains(root.Position) -- the park: no fighting
		and not blocking
		and not isStunned(character)
		and not inCinematic(character)
		and not isBusyMoving()
		and os.clock() >= nextAttackAt
end

-- A move started (KitController): no M1 / other move until it's over, and
-- the next M1 starts a new combo.
function CombatController.holdAttacks(seconds: number)
	local time = os.clock()
	nextAttackAt = math.max(nextAttackAt, time + seconds)
	lastAttackAt = time
	combo = 0
end

-- Our move was refused by the server: we can attack again right away.
function CombatController.releaseAttacks()
	nextAttackAt = os.clock()
end

-- One of OUR kit moves just landed on someone (CombatEffectsController
-- tells us; KitController listens, e.g. to brake a tackle on contact).
local moveLanded = Signal.new() :: Signal.Signal<string>
function CombatController.notifyMoveLanded(moveId: string)
	moveLanded.fire(moveId)
end
function CombatController.onMoveLanded(callback: (string) -> ()): Signal.Connection
	return moveLanded.connect(callback)
end

-- Calls `callback` each time one of our M1 starts (see AttackInfo).
function CombatController.onAttackStarted(callback: (AttackInfo) -> ()): Signal.Connection
	return attackStarted.connect(callback)
end

function CombatController.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return -- clicking a button, typing in chat...
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			attackHeld = true
			tryAttack()
		elseif input.KeyCode == Config.Controls.BLOCK then
			blockHeld = true
			setBlocking(true)
		elseif input.KeyCode == Config.Controls.DASH then
			tryDash()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			attackHeld = false
		elseif input.KeyCode == Config.Controls.BLOCK then
			blockHeld = false
			setBlocking(false)
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		attackHeld = false
		blockHeld = false
		setBlocking(false)
	end)

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		-- The server ended (guard break, stun) or refused our block: follow it.
		if
			blocking
			and character
			and character:GetAttribute("Blocking") ~= true
			and os.clock() - blockRequestedAt > BLOCK_CONFIRM_TIME
		then
			blocking = false
			CharacterAnimationController.setPredictedBlock(false)
		end
		-- Still holding F: block again as soon as it's allowed.
		if blockHeld and not blocking then
			setBlocking(true)
		end
		-- Holding the button keeps attacking (tryAttack waits for the timing).
		if attackHeld then
			tryAttack()
		end
	end)

	-- New life: forget the previous fight.
	player.CharacterAdded:Connect(function()
		blocking = false
		CharacterAnimationController.setPredictedBlock(false)
		combo = 0
		nextAttackAt = 0
		nextDashAt = 0
	end)
end

return CombatController
