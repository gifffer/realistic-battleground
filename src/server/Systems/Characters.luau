--!strict
-- Characters: prepares every character when it spawns.
--
--   • Sets health from Config.
--   • Turns OFF passive regeneration (game design: a kill heals, time doesn't;
--     only a slow regen up to 25 HP out of combat, see Combat + Config.Injuries).
--     Roblox puts a script named "Health" in every character that heals 1 %
--     of max health per second; we delete it as soon as the character spawns.
--   • Checks the avatar is R6. The game is built for R6 (6 body parts:
--     simpler animations, ragdoll and hit zones). R6 is NOT forced by code:
--     it is a setting of the place (see docs/SETUP_FR.md, "Avatar R6").
--     If it's wrong, we print a clear warning instead of failing silently.
--   • Gives every fighter the CLASSIC R6 head (their face and skin colour
--     stay): the glass cuts are drawn on an exact copy of that head (see
--     Client/Combat/Gashes), so it must be the same for everyone.
--   • Removes R6 body packages (CharacterMesh): the classic blocky body.
--   • Keeps only the accessories worn on the head (hair, hats, glasses /
--     face accessories) that aren't too big, without collisions: big or
--     body accessories get in the way of the fights (and of the cuts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Characters = {}

local HEAD_SCALE = Vector3.new(1.25, 1.25, 1.25) -- the classic head mesh on a 2x1x1 head
-- Accessories that are kept (the rest is removed).
local KEPT_ACCESSORIES: { [Enum.AccessoryType]: boolean } = {
	[Enum.AccessoryType.Hat] = true,
	[Enum.AccessoryType.Hair] = true,
	[Enum.AccessoryType.Face] = true, -- glasses, masks on the upper face...
	[Enum.AccessoryType.Eyebrow] = true,
	[Enum.AccessoryType.Eyelash] = true,
}
-- Old accessories have no type: kept if they hang on the head.
local HEAD_ATTACHMENTS: { [string]: boolean } = {
	HatAttachment = true,
	HairAttachment = true,
	FaceFrontAttachment = true,
	FaceCenterAttachment = true,
}
local MAX_ACCESSORY_SIDE = 3 -- studs: the biggest side of its handle
local MAX_ACCESSORY_VOLUME = 6 -- cubic studs

-- The classic head: a Head part with ONE SpecialMesh, of type Head.
local function makeClassicHead(head: BasePart, preferred: SpecialMesh?)
	if head:IsA("MeshPart") then
		return -- (not an R6 head: left alone)
	end
	local mesh: SpecialMesh? = preferred
	for _, child in head:GetChildren() do
		if child:IsA("SpecialMesh") then
			if mesh == nil then
				mesh = child
			elseif child ~= mesh then
				child:Destroy() -- a second mesh (an avatar head added later)
			end
		end
	end
	local classic: SpecialMesh
	if mesh then
		classic = mesh
	else
		classic = Instance.new("SpecialMesh")
		classic.Parent = head
	end
	if classic.MeshType ~= Enum.MeshType.Head then
		classic.MeshType = Enum.MeshType.Head
	end
	if classic.MeshId ~= "" then
		classic.MeshId = ""
	end
	if classic.TextureId ~= "" then
		classic.TextureId = ""
	end
	if classic.Scale ~= HEAD_SCALE then
		classic.Scale = HEAD_SCALE
	end
	if classic.Offset ~= Vector3.zero then
		classic.Offset = Vector3.zero
	end
end

-- Keeps the head classic, even if the avatar loader changes it afterwards.
-- (The connections die with the character.)
local function watchHead(head: BasePart)
	makeClassicHead(head)
	local function watchMesh(mesh: SpecialMesh)
		for _, property in { "MeshType", "MeshId", "Scale" } do
			mesh:GetPropertyChangedSignal(property):Connect(function()
				if mesh.Parent == head then
					makeClassicHead(head, mesh)
				end
			end)
		end
	end
	for _, child in head:GetChildren() do
		if child:IsA("SpecialMesh") then
			watchMesh(child)
		end
	end
	head.ChildAdded:Connect(function(child: Instance)
		if child:IsA("SpecialMesh") then
			makeClassicHead(head, child)
			watchMesh(child)
		end
	end)
end

local function isKeptAccessory(accessory: Accoutrement): boolean
	local handle = accessory:FindFirstChild("Handle")
	if handle == nil or not handle:IsA("BasePart") then
		return false
	end
	-- (Best effort for old hats whose handle is a Part with a mesh in it:
	-- their real size can't be read here, only the handle's.)
	local size = handle.Size
	if math.max(size.X, size.Y, size.Z) > MAX_ACCESSORY_SIDE then
		return false
	end
	if size.X * size.Y * size.Z > MAX_ACCESSORY_VOLUME then
		return false
	end
	if accessory:IsA("Accessory") and KEPT_ACCESSORIES[accessory.AccessoryType] then
		return true
	end
	if accessory:IsA("Accessory") and accessory.AccessoryType ~= Enum.AccessoryType.Unknown then
		return false -- a body accessory (back, waist, shoulders, clothing...)
	end
	for _, child in handle:GetChildren() do
		if child:IsA("Attachment") and HEAD_ATTACHMENTS[child.Name] then
			return true
		end
	end
	return false
end

local function checkAccessory(child: Instance)
	-- R6 body packages reshape the torso / limbs: everyone keeps the classic
	-- blocky body (the glass cuts redraw it exactly, see Gashes).
	if child:IsA("CharacterMesh") then
		child:Destroy()
		return
	end
	if not child:IsA("Accoutrement") then
		return
	end
	if not isKeptAccessory(child) then
		child:Destroy()
		return
	end
	-- Kept: it never collides (a hit ray that meets it counts as a head
	-- hit: see Combat's aimZone, so it stays queryable).
	local handle = child:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		handle.CanCollide = false
		handle.CanTouch = false
		handle.Massless = true
	end
end

-- The avatar loads a moment after the character appears: checked now and
-- each time something is added.
local function cleanAppearance(character: Model)
	for _, child in character:GetChildren() do
		checkAccessory(child)
	end
	character.ChildAdded:Connect(function(child: Instance)
		checkAccessory(child)
		if child.Name == "Head" and child:IsA("BasePart") then
			watchHead(child) -- (a head replaced by the avatar loader)
		end
	end)
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		watchHead(head)
	end
end

local warnedAboutRig = false

-- Deletes Roblox's regeneration script, now or if it shows up a bit later.
local function removeRegeneration(character: Model)
	local function check(child: Instance)
		if child.Name == "Health" and child:IsA("Script") then
			child:Destroy()
		end
	end
	for _, child in character:GetChildren() do
		check(child)
	end
	-- The connection dies with the character (Destroy on respawn), no leak.
	character.ChildAdded:Connect(check)
end

local function onCharacterAdded(character: Model)
	removeRegeneration(character)
	cleanAppearance(character)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end

	if humanoid.RigType ~= Enum.HumanoidRigType.R6 and not warnedAboutRig then
		warnedAboutRig = true
		warn(
			"[Characters] Avatars are not R6. Set Avatar Type to R6 in Studio "
				.. "(see docs/SETUP_FR.md, 'Avatar R6'), then publish the place."
		)
	end

	humanoid.MaxHealth = Config.Character.MAX_HEALTH
	humanoid.Health = Config.Character.MAX_HEALTH
	humanoid.WalkSpeed = Config.Character.WALK_SPEED
end

local function onPlayerAdded(player: Player)
	-- Roblox's built-in "Shift lock" uses Shift, which is our sprint key.
	-- Our CameraController already locks the mouse, so turn Roblox's one off.
	-- (Also set in default.project.json; done here too in case it isn't synced.)
	player.DevEnableMouseLock = false

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

function Characters.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Players who joined before this script ran (happens in Studio).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return Characters
