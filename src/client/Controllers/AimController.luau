--!strict
-- AimController: where you aim — the opponent's head, torso or legs.
--
-- The centre of the screen (where the crosshair is) decides:
--   • a ray goes from the camera through the crosshair; if it touches an
--     opponent, the body part it touches gives the zone (head = "Head",
--     torso / arms = "Torso", legs = "Legs");
--   • if it touches nothing, the camera's angle decides: looking up = head,
--     looking down = legs, straight = torso.
-- CombatController sends that zone with each M1. The SERVER doesn't trust it:
-- it only applies it if that body part is really inside the punch's hitbox.
--
-- Also draws the crosshair (a small dot in the middle of the screen) while
-- the mouse is locked: white normally, RED on an opponent's head.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

-- How far the aim ray looks (studs): a bit more than a punch's reach.
local AIM_DISTANCE = 40
-- Camera angle fallback (LookVector.Y): above → head, below → legs.
local LOOK_UP = 0.12
local LOOK_DOWN = -0.35
-- Body part name (R6) → zone.
local PART_ZONES: { [string]: Types.HitZone } = {
	Head = "Head",
	Torso = "Torso",
	HumanoidRootPart = "Torso",
	["Right Arm"] = "Torso",
	["Left Arm"] = "Torso",
	["Right Leg"] = "Legs",
	["Left Leg"] = "Legs",
}
local CROSSHAIR_COLORS: { [string]: Color3 } = {
	None = Color3.fromRGB(240, 240, 240),
	Head = Color3.fromRGB(235, 60, 60),
	Torso = Color3.fromRGB(255, 255, 255),
	Legs = Color3.fromRGB(240, 200, 80),
}

local AimController = {}

local currentZone: Types.HitZone = "Torso"
local onOpponent = false
local crosshair: Frame? = nil
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- Is this part a body part of a fighter (player or training dummy)?
local function fighterPart(part: Instance): Types.HitZone?
	local model = part:FindFirstAncestorOfClass("Model")
	if model == nil or model == player.Character then
		return nil
	end
	if not CollectionService:HasTag(model, Config.Combat.TAG) then
		return nil
	end
	return PART_ZONES[part.Name]
end

local function updateAim()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	-- Where the crosshair is: the centre when the mouse is locked, the mouse otherwise.
	local screenPoint = if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		then camera.ViewportSize / 2
		else UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)

	rayParams.FilterDescendantsInstances = { player.Character :: any }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, rayParams)
	local zone = if hit then fighterPart(hit.Instance) else nil
	onOpponent = zone ~= nil
	if zone == nil then
		local lookY = camera.CFrame.LookVector.Y
		zone = if lookY > LOOK_UP then "Head" elseif lookY < LOOK_DOWN then "Legs" else "Torso"
	end
	currentZone = zone :: Types.HitZone

	local dot = crosshair
	if dot then
		dot.Visible = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		dot.BackgroundColor3 = if onOpponent
			then CROSSHAIR_COLORS[currentZone]
			else CROSSHAIR_COLORS.None
	end
end

-- The zone aimed at right now.
function AimController.getZone(): Types.HitZone
	return currentZone
end

function AimController.start()
	local gui = Theme.make("ScreenGui", {
		Name = "Crosshair",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	}, {
		Theme.make("Frame", {
			Name = "Dot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(5, 5),
			BackgroundColor3 = CROSSHAIR_COLORS.None,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Visible = false,
		}, {
			Theme.corner(UDim.new(1, 0)),
			Theme.make(
				"UIStroke",
				{ Color = Color3.new(0, 0, 0), Transparency = 0.4, Thickness = 1 }
			),
		}),
	})
	crosshair = gui.Dot
	RunService.RenderStepped:Connect(updateAim)
end

return AimController
