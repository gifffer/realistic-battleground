--!strict
-- KitController: the kit keys.
--
--   1 2 3 4  → the 4 moves of our kit         → Remotes.UseMove(slot, aim)
--   G        → Awakening, when the gauge is full → Remotes.Awaken
--
-- Like the M1, the client never decides anything: it checks the same rules
-- as the server (so it doesn't send requests that would be refused) and
-- plays the move the instant the key is pressed, so it feels instant. If
-- the server still refuses (Remotes.MoveRefused), the move is undone.
--
-- What the HUD reads to show the move bar (all set by the server on our
-- character): "Kit" (kit id), "CD_<moveId>" (server time when a move is
-- ready again), "Fury" (gauge), "Awakened" / "AwakenedUntil".
--
-- Tackle: like the dash, our own client moves our character (Push) during
-- the charge; the server only decides who gets hit. On contact we brake.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Push = require(ReplicatedStorage.Shared.Util.Push)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local AimController = require(script.Parent.AimController)
local CameraController = require(script.Parent.CameraController)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local CombatController = require(script.Parent.CombatController)
local SoundController = require(script.Parent.SoundController)
local KitEffects = require(script.Parent.Parent.Combat.KitEffects)

local KC = Config.Kits
local player = Players.LocalPlayer

local KitController = {}

-- A key press the rules refused (cooldown, low stamina): the HUD shows it.
local denied = Signal.new() :: Signal.Signal<number>

-- Ids of the moves that are charges (tackles), from every kit's data.
local CHARGE_MOVES: { [string]: boolean } = {}
for _, kit in Kits.list() do
	local awakening = kit.awakening
	for _, list in { kit.moves, if awakening then awakening.moves else {} } do
		for _, move in list do
			if move.charge then
				CHARGE_MOVES[move.id] = true
			end
		end
	end
end

-- Our last move request (to match a refusal with it).
local requestSeq = 0
local pending: { id: number, animation: string }? = nil

-- +1 cancels the charge push of the move in progress (refused / landed).
local chargeToken = 0

-- Our kit and whether we are awakened, from our character's attributes.
local function currentKit(character: Model): Kits.KitDef?
	local id = character:GetAttribute("Kit")
	return Kits.get(if typeof(id) == "string" then id else nil)
end

local function isAwakened(character: Model): boolean
	return character:GetAttribute("Awakened") == true
end

-- Seconds of Street Fury left, from the server's end time (the "Awakened"
-- attribute only changes a moment AFTER the end, it lags).
local function awakenedLeft(character: Model): number
	local untilTime = character:GetAttribute("AwakenedUntil")
	if not isAwakened(character) or typeof(untilTime) ~= "number" then
		return 0
	end
	return untilTime - workspace:GetServerTimeNow()
end

-- The move on `slot` right now (the Awakening version while awakened).
function KitController.getMove(slot: number): Kits.MoveDef?
	local character = player.Character
	if character == nil then
		return nil
	end
	local kit = currentKit(character)
	return if kit then Kits.move(kit, slot, isAwakened(character)) else nil
end

-- Seconds before `move` can be used again (0 = ready).
function KitController.cooldownLeft(character: Model, move: Kits.MoveDef): number
	local readyAt = character:GetAttribute(`CD_{move.id}`)
	if typeof(readyAt) ~= "number" then
		return 0
	end
	return math.max(0, readyAt - workspace:GetServerTimeNow())
end

-- Our charge in progress: until when its push runs (0 = no charge).
local chargeUntil = 0

-- Stops the charge: a short brake instead of an instant stop. Does nothing
-- if we aren't charging (so it never cancels a knockback the server gave us).
local function brake()
	chargeToken += 1
	if os.clock() >= chargeUntil then
		return
	end
	chargeUntil = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local velocity = root.AssemblyLinearVelocity
		Push.apply(root, Vector3.new(velocity.X, 0, velocity.Z) * 0.15, KC.CHARGE_BRAKE_TIME)
	end
end

-- The server stops a move when we get stunned, knocked down or knocked out:
-- the charge must stop too, or we'd keep sliding forward.
local function chargeInterrupted(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid == nil
		or humanoid.Health <= 0
		or character:GetAttribute("Stunned") == true
		or character:GetAttribute("Ragdolled") == true
		or character:GetAttribute("KnockedOut") == true
end

-- Charge: push our character forward during the charge window.
local function startCharge(move: Kits.MoveDef, character: Model, root: BasePart)
	local charge = move.charge
	if charge == nil then
		return
	end
	chargeToken += 1
	local token = chargeToken
	local startedAt = os.clock()
	chargeUntil = startedAt + charge.to
	local pushing = false
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startedAt
		if chargeToken ~= token or elapsed > charge.to or root.Parent == nil then
			if connection then
				connection:Disconnect()
			end
			return
		end
		if chargeInterrupted(character) then
			brake()
			return
		end
		if not pushing and elapsed >= charge.from then
			pushing = true
			local look = root.CFrame.LookVector
			local forward = Vector3.new(look.X, 0, look.Z).Unit
			Push.apply(root, forward * charge.speed, charge.to - elapsed)
		end
	end)
end

-- Leap (skyfall): our own client throws our character up and forward.
local function startLeap(move: Kits.MoveDef, character: Model, root: BasePart)
	local leap = move.leap
	if leap == nil then
		return
	end
	chargeToken += 1
	local token = chargeToken
	task.delay(leap.at, function()
		if chargeToken ~= token or root.Parent == nil or chargeInterrupted(character) then
			return
		end
		local look = root.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z)
		forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.new(0, 0, -1)
		root.AssemblyLinearVelocity = forward * leap.forward + Vector3.new(0, leap.up, 0)
		Push.apply(root, forward * leap.forward, leap.time)
	end)
end

-- Beam (heat vision): the beam goes the way we faced when it started, so
-- our character stops turning with the camera until it ends.
local beamToken = 0
local function holdForBeam(move: Kits.MoveDef)
	local beam = move.beam
	if beam == nil then
		return
	end
	beamToken += 1
	local token = beamToken
	CameraController.holdRotation("beam", true)
	task.delay(beam.to, function()
		if beamToken == token then
			CameraController.holdRotation("beam", false)
		end
	end)
end

local function tryMove(slot: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	-- Street Fury about to end: we can't know which version the server will
	-- use, so wait a moment instead of guessing wrong.
	local left = awakenedLeft(character)
	if isAwakened(character) and left < 0.2 then
		return
	end
	local move = KitController.getMove(slot)
	if move == nil or not CombatController.canStartMove() then
		return
	end
	local stamina = player:GetAttribute("Stamina")
	if
		KitController.cooldownLeft(character, move) > 0
		or (typeof(stamina) == "number" and stamina < move.stamina)
	then
		denied.fire(slot)
		return
	end

	CombatController.holdAttacks(move.duration)
	CharacterAnimationController.playAction(character, move.animation)
	KitEffects.onAction(character, move.animation)
	startCharge(move, character, root)
	startLeap(move, character, root)
	holdForBeam(move)
	-- Each request gets a number: a refusal names it (see onMoveRefused).
	requestSeq += 1
	pending = { id = requestSeq, animation = move.animation }
	Remotes.UseMove:FireServer(slot, AimController.getAimDirection(), requestSeq)
end

-- Uses the move on `slot` (a key, or a click on the move bar).
function KitController.use(slot: number)
	tryMove(slot)
end

-- Calls `callback(slot)` when a press is refused (cooldown / low stamina).
function KitController.onDenied(callback: (number) -> ()): Signal.Connection
	return denied.connect(callback)
end

-- After pressing G we wait this long (s) for the server to confirm (the
-- "Awakened" attribute): no second roar meanwhile, and no roar left playing
-- if it refused. About a round trip with a good margin.
local AWAKEN_CONFIRM_TIME = 0.6
local awakenPendingUntil = 0

local function tryAwaken()
	local character = player.Character
	if character == nil or isAwakened(character) then
		return
	end
	local fury = character:GetAttribute("Fury")
	if typeof(fury) ~= "number" or fury < KC.FURY_MAX then
		return
	end
	-- Same rules as the server (not blocking, stunned, busy, between two
	-- attacks): otherwise it would refuse, and G must not roar for nothing.
	if not CombatController.canStartMove() then
		return
	end
	-- Already asked (waiting for the server's answer): one roar per press only.
	if os.clock() < awakenPendingUntil then
		return
	end
	awakenPendingUntil = os.clock() + AWAKEN_CONFIRM_TIME
	-- The roar starts THE MOMENT G is pressed (for us). The server confirms and
	-- plays the activation for everyone else (and the animation for us too).
	local roar = SoundController.play("Awaken", character)
	Remotes.Awaken:FireServer()
	-- The server refused after all (a stun that hadn't reached us yet...):
	-- no Street Fury, so take the roar back.
	task.delay(AWAKEN_CONFIRM_TIME, function()
		if roar and character:GetAttribute("Awakened") ~= true then
			roar:Stop()
			roar:Destroy()
		end
	end)
end

-- The server refused our move: undo what we showed. Only if it's the move
-- still playing (a late refusal must not cancel a newer, accepted one).
local function onMoveRefused(_slot: unknown, requestId: unknown)
	local character = player.Character
	local current = pending
	if character == nil or current == nil or requestId ~= current.id then
		return
	end
	pending = nil
	brake()
	beamToken += 1
	CameraController.holdRotation("beam", false)
	CharacterAnimationController.stopAction(character, current.animation)
	KitEffects.stopAction(character)
	CombatController.releaseAttacks()
end

function KitController.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return -- typing in chat...
		end
		local slot = table.find(KC.MOVE_KEYS, input.KeyCode)
		if slot then
			tryMove(slot)
		elseif input.KeyCode == KC.AWAKEN_KEY then
			tryAwaken()
		end
	end)
	Remotes.MoveRefused.OnClientEvent:Connect(onMoveRefused)
	-- Our tackle hit someone: stop rushing past them.
	CombatController.onMoveLanded(function(moveId)
		if CHARGE_MOVES[moveId] then
			brake()
		end
	end)
	player.CharacterAdded:Connect(function()
		awakenPendingUntil = 0
		chargeToken += 1
		chargeUntil = 0
		pending = nil
	end)
end

return KitController
