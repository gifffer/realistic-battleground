--!strict
-- ShopFrontController: the shops you can walk into in the city.
--
-- The city builder (Server/Systems/City) puts a counter in the clothes shop
-- and one in the emote shop: a BasePart named "ShopCounter" with the
-- attribute ShopCategory ("Outfit" or "Emote") and a child ProximityPrompt
-- (ActionText "BROWSE CLOTHES" / "BROWSE EMOTES", ObjectText = the shop's
-- name, hold time 0). This controller:
--
--   1. Opens the menu on the SHOP section with the right category selected
--      when you use a counter (ShopMenuController.openAt). The SHOP entry of
--      the menu still works as before: the counters are just a shortcut.
--   2. Hides the counters' prompts while you can't use them: in a duel,
--      dead, knocked out, or while the menu is already open.
--   3. Draws the prompt in the game's own style instead of Roblox's grey
--      bubble (ProximityPrompt.Style = Custom):
--
--         HOLLOW THREADS                (the shop's name, small)
--         [E] ── BROWSE CLOTHES         (key cap, hairline, action)
--
--   4. Dresses the mannequins of the clothes shop in the shop's outfits
--      (only on this screen, nothing is sent to the server).
--
-- Mannequins (optional, nothing breaks if there are none): a Model named
-- "Mannequin" inside Workspace > City, or any Model tagged "Mannequin"
-- (CollectionService), with the attribute OutfitId = an Outfit id of
-- Shared/Cosmetics (e.g. "OutfitOlive"). Each BasePart of the model takes:
--   • the outfit's TOP colour if its name contains "Torso", "Chest" or "Top",
--   • the TROUSERS colour if it contains "Leg", "Foot", "Hip", "Pelvis",
--     "Trousers" or "Pants",
--   • or the side named by its attribute MannequinPart ("Top" | "Trousers"),
--     which wins over the name.
-- Arms and heads keep their colour (like a player wearing an outfit).
--
-- The server never trusts any of this: buying and equipping go through the
-- shop's remotes exactly like from the menu.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Theme = require(script.Parent.Parent.UI.Theme)
local MenuController = require(script.Parent.MenuController)
local ShopMenuController = require(script.Parent.ShopMenuController)

local player = Players.LocalPlayer
local C = Theme.Colors

-- Name of the folder the city is built in (Server/Systems/City).
local CITY_FOLDER = "City"
-- Tag a hand-made mannequin can carry instead of being named "Mannequin".
local MANNEQUIN_TAG = "Mannequin"

-- The custom prompt (a BillboardGui above the counter).
local PROMPT_SIZE = Vector2.new(240, 48) -- pixels
local PROMPT_HEIGHT = 1.4 -- studs above the top of the counter
local FADE_IN = 0.15
local FADE_OUT = 0.1

local ShopFrontController = {}

-- Every shop prompt we know about (key = the prompt, value = true).
local shopPrompts: { [ProximityPrompt]: boolean } = {}
-- The billboard drawn for each prompt currently shown.
local billboards: { [ProximityPrompt]: BillboardGui } = {}
-- Where the billboards live (a folder in PlayerGui, kept across respawns).
local promptGui: ScreenGui
-- Connections of the current character (cleared on respawn).
local characterConnections: { RBXScriptConnection } = {}

------------------------------------------------------------------------------
-- Which prompts are shop prompts
------------------------------------------------------------------------------

-- The category of the shop this prompt belongs to, or nil if it is not a
-- shop counter's prompt (or the attribute holds something unknown).
local function shopCategory(prompt: ProximityPrompt): Cosmetics.Category?
	local parent = prompt.Parent
	if parent == nil then
		return nil
	end
	local value = parent:GetAttribute("ShopCategory")
	if typeof(value) ~= "string" or table.find(Cosmetics.CATEGORIES, value) == nil then
		return nil
	end
	return value :: Cosmetics.Category
end

------------------------------------------------------------------------------
-- When the prompts are allowed
------------------------------------------------------------------------------

-- True when the player should NOT see the shop prompts right now.
local function isBlocked(): boolean
	-- The menu is open (maybe on the shop already): no prompt over it.
	if MenuController.getOpen() ~= nil then
		return true
	end
	-- In a duel: the server sets "InDuel" on the Player and "DuelId" on the
	-- character (see Server/Systems/Duels).
	if player:GetAttribute("InDuel") == true then
		return true
	end
	local character = player.Character
	if character == nil then
		return true
	end
	if character:GetAttribute("DuelId") ~= nil or character:GetAttribute("KnockedOut") == true then
		return true
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid == nil or humanoid.Health <= 0
end

-- Turns every shop prompt on or off for this player only (a property changed
-- on the client is not sent to the server, other players are not affected).
-- A disabled prompt fires PromptHidden, which removes its billboard.
local function refreshPrompts()
	local enabled = not isBlocked()
	for prompt in shopPrompts do
		if prompt.Enabled ~= enabled then
			prompt.Enabled = enabled
		end
	end
end

-- Remembers a shop prompt and gives it our own look.
local function trackPrompt(prompt: ProximityPrompt)
	if shopPrompts[prompt] or shopCategory(prompt) == nil then
		return
	end
	shopPrompts[prompt] = true
	-- "Custom": Roblox draws nothing, we draw the billboard in PromptShown.
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Enabled = not isBlocked()
	-- Forget it when it leaves the game (e.g. streamed out or rebuilt).
	prompt.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			shopPrompts[prompt] = nil
		end
	end)
end

------------------------------------------------------------------------------
-- The custom prompt (billboard)
------------------------------------------------------------------------------

-- The word shown in the key cap for this kind of input.
local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		-- "ButtonX" → "X"
		return (string.gsub(prompt.GamepadKeyCode.Name, "^Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

-- Fades a billboard out, then removes it.
local function removeBillboard(prompt: ProximityPrompt)
	local billboard: BillboardGui? = billboards[prompt]
	if billboard == nil then
		return
	end
	billboards[prompt] = nil
	local group = billboard:FindFirstChild("Group")
	if group and group:IsA("CanvasGroup") then
		Theme.tween(group, FADE_OUT, { GroupTransparency = 1 })
	end
	task.delay(FADE_OUT, function()
		billboard:Destroy()
	end)
end

-- Builds the billboard for `prompt` (called by PromptShown).
local function showBillboard(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	removeBillboard(prompt) -- (never two for one prompt)

	-- What the billboard floats above: the counter part, or an attachment.
	local adornee = prompt.Parent
	local height = PROMPT_HEIGHT
	if adornee and adornee:IsA("BasePart") then
		height += adornee.Size.Y / 2
	elseif not (adornee and adornee:IsA("Attachment")) then
		return
	end

	-- Touch screens and mouse clicks need a button: a Custom prompt only
	-- listens to its key by itself.
	local clickable = inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt

	local billboard = Theme.make("BillboardGui", {
		Name = "ShopPrompt",
		Adornee = adornee,
		Size = UDim2.fromOffset(PROMPT_SIZE.X, PROMPT_SIZE.Y),
		StudsOffsetWorldSpace = Vector3.new(0, height, 0),
		AlwaysOnTop = true,
		LightInfluence = 0, -- same brightness at night (readable in the dark)
		ResetOnSpawn = false,
		Active = clickable,
		Parent = promptGui,
	}) :: BillboardGui

	-- Everything inside fades as one.
	local group = Theme.make("CanvasGroup", {
		Name = "Group",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = billboard,
	}, {
		-- A soft dark wash behind the text, fading to the right (no box).
		Theme.make("Frame", {
			Name = "Wash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.Scrim,
		}, { Theme.gradient(0, { { 0, 0.3 }, { 0.6, 0.55 }, { 1, 1 } }) }),
		-- The shop's name, small, above.
		Theme.text({
			Name = "Shop",
			Position = UDim2.fromOffset(10, 5),
			Size = UDim2.new(1, -20, 0, 11),
			TextSize = 9,
			TextColor3 = C.Ink2,
			Text = Theme.track(string.upper(prompt.ObjectText), "three"),
		}),
		-- The key, a hairline, the action: "[E] ── BROWSE CLOTHES".
		Theme.make("Frame", {
			Name = "Row",
			Position = UDim2.fromOffset(10, 21),
			Size = UDim2.new(1, -20, 0, 20),
			BackgroundTransparency = 1,
		}, {
			Theme.make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			Theme.keyCap(keyText(prompt, inputType), { LayoutOrder = 1 }),
			Theme.make("Frame", {
				Name = "Line",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(16, 1),
				BackgroundColor3 = C.Ink,
				BackgroundTransparency = 0.15,
			}),
			Theme.text({
				Name = "Action",
				LayoutOrder = 3,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 20),
				TextSize = 12,
				Text = Theme.track(string.upper(prompt.ActionText), "four"),
			}),
		}),
	}) :: CanvasGroup

	if clickable then
		-- An invisible button over everything: a tap / click "presses" the
		-- prompt (hold time 0, so begin + end = triggered).
		local button = Theme.make("TextButton", {
			Name = "Press",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Parent = group,
		}) :: TextButton
		button.Activated:Connect(function()
			prompt:InputHoldBegin()
			prompt:InputHoldEnd()
		end)
	end

	billboards[prompt] = billboard
	Theme.tween(group, FADE_IN, { GroupTransparency = 0 })
end

------------------------------------------------------------------------------
-- Mannequins (clothes shop)
------------------------------------------------------------------------------

local TOP_WORDS = { "Torso", "Chest", "Top" }
local TROUSER_WORDS = { "Leg", "Foot", "Hip", "Pelvis", "Trousers", "Pants" }

local function nameHasAny(name: string, words: { string }): boolean
	for _, word in words do
		if string.find(name, word, 1, true) then
			return true
		end
	end
	return false
end

-- Which side of the outfit a mannequin part shows: "Top", "Trousers" or nil.
local function partSide(part: BasePart): string?
	local side = part:GetAttribute("MannequinPart")
	if side == "Top" or side == "Trousers" then
		return side
	end
	-- (Test the legs first: "LeftUpperLeg" must not be read as a top.)
	if nameHasAny(part.Name, TROUSER_WORDS) then
		return "Trousers"
	elseif nameHasAny(part.Name, TOP_WORDS) then
		return "Top"
	end
	return nil
end

-- Paints one part of a mannequin in its outfit (if it is a top/trouser part).
local function paintPart(part: BasePart, item: Cosmetics.Item)
	local side = partSide(part)
	if side == "Top" and item.top then
		part.Color = item.top
	elseif side == "Trousers" and item.trousers then
		part.Color = item.trousers
	end
end

-- The outfit a mannequin wears (nil if its OutfitId is missing or not an outfit).
local function mannequinOutfit(model: Model): Cosmetics.Item?
	local outfitId = model:GetAttribute("OutfitId")
	local item = Cosmetics.get(if typeof(outfitId) == "string" then outfitId else nil)
	if item == nil or item.category ~= "Outfit" then
		return nil
	end
	return item
end

local function paintMannequin(model: Model)
	local item = mannequinOutfit(model)
	if item == nil then
		return
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			paintPart(descendant, item)
		end
	end
end

local dressed: { [Model]: boolean } = {} -- mannequins already set up

local function setupMannequin(model: Model)
	if dressed[model] then
		return
	end
	dressed[model] = true
	paintMannequin(model)
	-- Parts that arrive later (streaming) and a changed outfit are painted too.
	-- These connections die with the model.
	model.DescendantAdded:Connect(function(descendant)
		local item = mannequinOutfit(model)
		if item and descendant:IsA("BasePart") then
			paintPart(descendant, item)
		end
	end)
	model:GetAttributeChangedSignal("OutfitId"):Connect(function()
		paintMannequin(model)
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			dressed[model] = nil
		end
	end)
end

------------------------------------------------------------------------------
-- Watching the city
------------------------------------------------------------------------------

-- Looks at one instance of the city: a shop prompt or a mannequin.
local function inspect(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		trackPrompt(instance)
	elseif instance:IsA("Model") and instance.Name == "Mannequin" then
		setupMannequin(instance)
	elseif instance.Name == "ShopCounter" then
		-- The counter itself can get its ShopCategory after its prompt was
		-- added: look at its prompts again when the attribute arrives.
		instance:GetAttributeChangedSignal("ShopCategory"):Connect(function()
			for _, child in instance:GetChildren() do
				if child:IsA("ProximityPrompt") then
					trackPrompt(child)
				end
			end
		end)
	end
end

-- The city folder exists (or just arrived): look at what is there, then at
-- everything the builder adds (it builds a few hundred parts at a time).
local function watchCity(city: Instance)
	city.DescendantAdded:Connect(inspect)
	for _, descendant in city:GetDescendants() do
		inspect(descendant)
	end
end

------------------------------------------------------------------------------
-- Player state
------------------------------------------------------------------------------

local function onCharacterAdded(character: Model)
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)

	local function watchHumanoid(humanoid: Humanoid)
		table.insert(characterConnections, humanoid.HealthChanged:Connect(refreshPrompts))
		table.insert(characterConnections, humanoid.Died:Connect(refreshPrompts))
	end

	table.insert(
		characterConnections,
		character:GetAttributeChangedSignal("KnockedOut"):Connect(refreshPrompts)
	)
	table.insert(
		characterConnections,
		character:GetAttributeChangedSignal("DuelId"):Connect(refreshPrompts)
	)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		watchHumanoid(humanoid)
	else
		-- The Humanoid can arrive a moment after the model.
		table.insert(
			characterConnections,
			character.ChildAdded:Connect(function(child)
				if child:IsA("Humanoid") then
					watchHumanoid(child)
					refreshPrompts()
				end
			end)
		)
	end
	refreshPrompts()
end

------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------

function ShopFrontController.init()
	-- A ScreenGui that only holds the prompt billboards (a BillboardGui in
	-- PlayerGui still draws in the world, above its Adornee).
	promptGui = Theme.make("ScreenGui", {
		Name = "ShopPrompts",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
end

function ShopFrontController.start()
	-- Using a counter: open the shop on its category.
	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredBy)
		if triggeredBy ~= player then
			return
		end
		local category: Cosmetics.Category? = shopCategory(prompt)
		if category == nil or isBlocked() then
			return
		end
		ShopMenuController.openAt(category)
	end)

	-- Our own look for the shop prompts (other prompts are left alone).
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if shopCategory(prompt) == nil then
			return
		end
		if not shopPrompts[prompt] then
			-- Missed while watching the city (e.g. placed elsewhere): take it now.
			trackPrompt(prompt)
		end
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			showBillboard(prompt, inputType)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		removeBillboard(prompt)
	end)

	-- The menu opening / closing hides / shows the prompts.
	MenuController.onOpenChanged(function()
		refreshPrompts()
	end)
	-- Entering / leaving a duel.
	player:GetAttributeChangedSignal("InDuel"):Connect(refreshPrompts)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end

	-- Mannequins tagged by hand (anywhere in the world).
	CollectionService:GetInstanceAddedSignal(MANNEQUIN_TAG):Connect(function(instance)
		if instance:IsA("Model") then
			setupMannequin(instance)
		end
	end)
	for _, instance in CollectionService:GetTagged(MANNEQUIN_TAG) do
		if instance:IsA("Model") then
			setupMannequin(instance)
		end
	end

	-- The city is built by the server after the game starts: wait for its folder.
	local city = workspace:FindFirstChild(CITY_FOLDER)
	if city then
		watchCity(city)
	else
		local connection: RBXScriptConnection
		connection = workspace.ChildAdded:Connect(function(child)
			if child.Name == CITY_FOLDER then
				connection:Disconnect()
				watchCity(child)
			end
		end)
	end
end

return ShopFrontController
