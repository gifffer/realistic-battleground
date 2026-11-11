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
local Push = require(ReplicatedStorage.Shared.Util.Push)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local AimController = require(script.Parent.AimController)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local CombatEffectsController = require(script.Parent.CombatEffectsController)
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
			if instance:GetAttribute("KnockedOut") == true and torso and torso:IsA("BasePart") then
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

local function tryAttack()
	local character, _, root = getCharacterParts()
	local time = os.clock()
	if
		character == nil
		or root == nil
		or blocking
		or isStunned(character)
		or isBusyMoving()
		or time < nextAttackAt
	then
		return
	end

	-- Opponent down in front of us: finish them (the server confirms).
	if findFinishTarget(root) then
		combo = 0
		nextAttackAt = time + K.FINISH_DURATION
		lastAttackAt = time
		CharacterAnimationController.playAction(character, "Finisher")
		SoundController.play("HeavySwing", character)
		Remotes.Attack:FireServer(AimController.getZone())
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
	local zone: Types.HitZone = AimController.getZone()
	Remotes.Attack:FireServer(zone)
	-- Our fist reaches its target HIT_DELAY later (the punch's impact frame):
	-- show the victim's reaction at that exact moment, without waiting for
	-- the server's answer (visual only, the server still decides the hit).
	task.delay(C.HIT_DELAY, function()
		CombatEffectsController.predictHit(isFinisher, zone)
	end)
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
	if blocking or isStunned(character) or isBusyMoving() or time < nextDashAt then
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
