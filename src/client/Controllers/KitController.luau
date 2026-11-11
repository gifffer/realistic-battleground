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
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kits = require(ReplicatedStorage.Shared.Kits)
local Push = require(ReplicatedStorage.Shared.Util.Push)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local AimController = require(script.Parent.AimController)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local CombatController = require(script.Parent.CombatController)
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

-- Charge: push our character forward during the charge window.
local function startCharge(move: Kits.MoveDef, root: BasePart)
	local charge = move.charge
	if charge == nil then
		return
	end
	chargeToken += 1
	local token = chargeToken
	task.delay(charge.from, function()
		if chargeToken ~= token or root.Parent == nil then
			return
		end
		local look = root.CFrame.LookVector
		local forward = Vector3.new(look.X, 0, look.Z).Unit
		Push.apply(root, forward * charge.speed, charge.to - charge.from)
	end)
end

-- Stops the charge: a short brake instead of an instant stop.
local function brake()
	chargeToken += 1
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local velocity = root.AssemblyLinearVelocity
		Push.apply(root, Vector3.new(velocity.X, 0, velocity.Z) * 0.15, KC.CHARGE_BRAKE_TIME)
	end
end

local function tryMove(slot: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character == nil or root == nil or not root:IsA("BasePart") then
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
	startCharge(move, root)
	Remotes.UseMove:FireServer(slot, AimController.getAimDirection())
end

-- Uses the move on `slot` (a key, or a click on the move bar).
function KitController.use(slot: number)
	tryMove(slot)
end

-- Calls `callback(slot)` when a press is refused (cooldown / low stamina).
function KitController.onDenied(callback: (number) -> ()): Signal.Connection
	return denied.connect(callback)
end

local function tryAwaken()
	local character = player.Character
	if character == nil or isAwakened(character) then
		return
	end
	local fury = character:GetAttribute("Fury")
	if typeof(fury) ~= "number" or fury < KC.FURY_MAX then
		return
	end
	-- Not predicted: the server plays the activation for everyone (us too).
	Remotes.Awaken:FireServer()
end

-- The server refused our move: undo what we showed.
local function onMoveRefused(_slot: unknown)
	local character = player.Character
	if character == nil then
		return
	end
	brake()
	CharacterAnimationController.stopAction(character)
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
		chargeToken += 1
	end)
end

return KitController
