--!strict
-- Panel: the pieces the top bar windows are made of.
--
--   Panel.tabs(parent, { "REWARDS", "CHALLENGES" })
--       small rounded dark tabs in a row; the open one is lighter grey
--       with white text (like Roblox's own tabs). Returns { set(index), get(), setBadge(index, n),
--       bind(callback) } (callback(index) on every change).
--   Panel.card({ parent, size, name, sub, tag, number, onActivated })
--       a square card: art in the middle (card.art), the name in bold
--       white under it, a small grey line under that, a type tag top
--       right, a number top left. card.setSelected / setEquipped / setDim.
--   Panel.grid(parent, cell, gap, position, size)
--       a scrolling frame that lays cards out in rows.
--   Panel.figure(parent, { pose, top, bottom })
--       a posed R6 silhouette in a ViewportFrame (kits, outfits, emotes).
--   Panel.bar(parent, props)
--       a thin progress bar: returns (track, fill).
--
-- Look: Roblox's dark theme (docs/UI_ROBLOX_STYLE.md). One near-black
-- plate, no borders, rounded dark grey cards, white bold names, grey small
-- caps. What you wear: a thin gold outline. What you picked: a lighter card
-- with a thin white outline. Never a big red block.

local TextService = game:GetService("TextService")

local Theme = require(script.Parent.Theme)

local C = Theme.Colors

local Panel = {}

------------------------------------------------------------------------------
-- Tabs
------------------------------------------------------------------------------

export type Tabs = {
	frame: Frame,
	set: (index: number) -> (),
	get: () -> number,
	setBadge: (index: number, count: number) -> (),
	bind: (callback: (index: number) -> ()) -> (),
}

local TAB_HEIGHT = 28
Panel.TAB_HEIGHT = TAB_HEIGHT

-- A white circle with a dark number (a count to look at), like Roblox's
-- own notification badge. Hidden at 0.
function Panel.badge(parent: Instance, position: UDim2, size: number): (Frame, TextLabel)
	local circle = Theme.make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.InkHi,
		Visible = false,
		ZIndex = 5,
		Parent = parent,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Theme.make("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		}),
	}) :: Frame
	local label = Theme.text({
		Name = "Count",
		Size = UDim2.new(1, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Theme.Fonts.Display,
		TextSize = math.floor(size * 0.65),
		TextColor3 = C.CardHi,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 6,
		Parent = circle,
	}) :: TextLabel
	return circle, label
end

function Panel.tabs(parent: Instance, labels: { string }): Tabs
	local listeners: { (index: number) -> () } = {}
	local function onPick(index: number)
		for _, listener in listeners do
			listener(index)
		end
	end
	local frame = Theme.make("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Theme.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	}) :: Frame
	local current = 1
	type Tab = { button: TextButton, label: TextLabel, badge: Frame, count: TextLabel }
	local tabs: { Tab } = {}
	local function paint()
		for index, tab in tabs do
			local open = index == current
			tab.label.TextColor3 = if open then C.InkHi else C.Muted
			tab.button.BackgroundColor3 = if open then C.CardHi else C.Surface
			tab.button.BackgroundTransparency = if open then 0 else Theme.SURFACE_TRANSPARENCY
		end
	end
	for index, text in labels do
		local width =
			TextService:GetTextSize(text, 13, Enum.Font.BuilderSansBold, Vector2.new(1000, 100)).X
		local button = Theme.make("TextButton", {
			Name = `Tab{index}`,
			LayoutOrder = index,
			Size = UDim2.fromOffset(math.max(120, width + 48), TAB_HEIGHT),
			BackgroundColor3 = C.Surface,
			BackgroundTransparency = Theme.SURFACE_TRANSPARENCY,
			AutoButtonColor = false,
			Text = "",
			Parent = frame,
		}, {
			Theme.make("UICorner", { CornerRadius = UDim.new(0, Theme.RADIUS) }),
		}) :: TextButton
		local label = Theme.text({
			Name = "Label",
			Size = UDim2.fromScale(1, 1),
			FontFace = Theme.Fonts.LabelBold,
			TextSize = 13,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = text,
			Parent = button,
		}) :: TextLabel
		local badge, count = Panel.badge(button, UDim2.new(1, -2, 0, 2), 18)
		local tab: Tab = { button = button, label = label, badge = badge, count = count }
		table.insert(tabs, tab)
		button.MouseEnter:Connect(function()
			-- (no hover on touch: MouseLeave often never comes)
			if index ~= current and not Theme.isTouch() then
				label.TextColor3 = C.InkHi
				button.BackgroundColor3 = C.Card
				button.BackgroundTransparency = 0
			end
		end)
		button.MouseLeave:Connect(paint)
		button.Activated:Connect(function()
			if index == current then
				return
			end
			current = index
			paint()
			onPick(index)
		end)
	end
	paint()
	return {
		frame = frame,
		set = function(index: number)
			if tabs[index] and index ~= current then
				current = index
				paint()
				onPick(index)
			end
		end,
		get = function(): number
			return current
		end,
		setBadge = function(index: number, count: number)
			local tab = tabs[index]
			if tab then
				tab.badge.Visible = count > 0
				tab.count.Text = tostring(count)
			end
		end,
		bind = function(callback: (index: number) -> ())
			table.insert(listeners, callback)
		end,
	}
end

------------------------------------------------------------------------------
-- Cards
------------------------------------------------------------------------------

export type CardOptions = {
	parent: Instance,
	name: string,
	sub: string?,
	tag: string?,
	number: string?,
	size: Vector2?, -- (in a grid the grid sets it)
	layoutOrder: number?,
	onActivated: (() -> ())?,
}

export type Card = {
	instance: TextButton,
	art: Frame, -- the middle: an icon, a figure, a word...
	setName: (text: string) -> (),
	setSub: (text: string, color: Color3?) -> (),
	setTag: (text: string) -> (),
	setNumber: (text: string, color: Color3?) -> (),
	setSelected: (selected: boolean) -> (),
	setEquipped: (equipped: boolean) -> (),
	setDim: (dim: boolean) -> (),
}

local NAME_H = 16
local SUB_H = 12
local FOOT = 8 + NAME_H + SUB_H + 2 -- room under the art
local HEAD = 18 -- room above the art (number, tag)

function Panel.card(options: CardOptions): Card
	local size = options.size or Vector2.new(112, 140)
	local instance = Theme.make("TextButton", {
		Name = options.name,
		Size = UDim2.fromOffset(size.X, size.Y),
		LayoutOrder = options.layoutOrder or 0,
		BackgroundColor3 = C.Card,
		AutoButtonColor = false,
		ClipsDescendants = true,
		Text = "",
		Parent = options.parent,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(0, Theme.RADIUS) }),
	}) :: TextButton
	local stroke = Theme.make("UIStroke", {
		Thickness = 1,
		Color = C.InkHi,
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = instance,
	}) :: UIStroke
	local art = Theme.make("Frame", {
		Name = "Art",
		Position = UDim2.fromOffset(0, HEAD),
		Size = UDim2.new(1, 0, 1, -(HEAD + FOOT)),
		BackgroundTransparency = 1,
		Parent = instance,
	}) :: Frame
	local number = Theme.text({
		Name = "Number",
		Position = UDim2.fromOffset(7, 4),
		Size = UDim2.fromOffset(30, 14),
		FontFace = Theme.Fonts.Display,
		TextSize = 13,
		TextColor3 = C.InkHi,
		TextStrokeTransparency = 1,
		Text = options.number or "",
		ZIndex = 2,
		Parent = instance,
	}) :: TextLabel
	local tag = Theme.text({
		Name = "Tag",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -7, 0, 5),
		Size = UDim2.new(1, -40, 0, 12),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 10,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = options.tag or "",
		ZIndex = 2,
		Parent = instance,
	}) :: TextLabel
	local name = Theme.text({
		Name = "Name",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, -(6 + SUB_H)),
		Size = UDim2.new(1, -8, 0, NAME_H),
		FontFace = Theme.Fonts.Display,
		TextSize = 13,
		TextColor3 = C.InkHi,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = options.name,
		ZIndex = 2,
		Parent = instance,
	}) :: TextLabel
	local sub = Theme.text({
		Name = "Sub",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, -5),
		Size = UDim2.new(1, -8, 0, SUB_H),
		FontFace = Theme.Fonts.LabelBold,
		TextSize = 10,
		TextColor3 = C.Ink2,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = string.upper(options.sub or ""),
		ZIndex = 2,
		Parent = instance,
	}) :: TextLabel

	local selected = false
	local equipped = false
	local hovered = false
	local function paint()
		instance.BackgroundColor3 = if selected or hovered then C.CardHi else C.Card
		if selected then
			stroke.Color = C.InkHi
			stroke.Transparency = 0.2
		elseif equipped then
			stroke.Color = C.Gold
			stroke.Transparency = 0.25
		else
			stroke.Transparency = 1
		end
	end
	instance.MouseEnter:Connect(function()
		if Theme.isTouch() then
			return -- (MouseLeave often never comes on touch)
		end
		hovered = true
		paint()
	end)
	instance.MouseLeave:Connect(function()
		hovered = false
		paint()
	end)
	instance.SelectionGained:Connect(function()
		hovered = true
		paint()
	end)
	instance.SelectionLost:Connect(function()
		hovered = false
		paint()
	end)
	if options.onActivated then
		instance.Activated:Connect(options.onActivated)
	end
	paint()

	return {
		instance = instance,
		art = art,
		setName = function(text: string)
			name.Text = text
		end,
		setSub = function(text: string, color: Color3?)
			sub.Text = string.upper(text)
			sub.TextColor3 = color or C.Ink2
		end,
		setTag = function(text: string)
			tag.Text = text
		end,
		setNumber = function(text: string, color: Color3?)
			number.Text = text
			number.TextColor3 = color or C.InkHi
		end,
		setSelected = function(value: boolean)
			selected = value
			paint()
		end,
		setEquipped = function(value: boolean)
			equipped = value
			paint()
		end,
		setDim = function(dim: boolean)
			name.TextColor3 = if dim then C.Ink2 else C.InkHi
			art.BackgroundTransparency = 1
			for _, child in art:GetDescendants() do
				if child:IsA("ViewportFrame") then
					child.ImageTransparency = if dim then 0.55 else 0
				end
			end
		end,
	}
end

-- A scrolling frame that lays its children out in rows of `cell`.
function Panel.grid(
	parent: Instance,
	cell: Vector2,
	gap: number,
	position: UDim2,
	size: UDim2
): ScrollingFrame
	local grid = Theme.make("ScrollingFrame", {
		Name = "Grid",
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Ink,
		ScrollBarImageTransparency = 0.5,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Parent = parent,
	}, {
		Theme.make("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(gap, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Theme.make("UIPadding", {
			PaddingTop = UDim.new(0, 1),
			PaddingLeft = UDim.new(0, 1),
		}),
	}) :: ScrollingFrame
	return grid
end

-- A thin progress bar (track + fill). `props` sets the track (Position, Size...).
function Panel.bar(parent: Instance, props: { [string]: any }): (Frame, Frame)
	local base: { [string]: any } = {
		Name = "Bar",
		BackgroundColor3 = C.CardHi,
		Parent = parent,
	}
	for key, value in props do
		base[key] = value
	end
	local track = Theme.make("Frame", base, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}) :: Frame
	local fill = Theme.make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Progress,
		Parent = track,
	}, {
		Theme.make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}) :: Frame
	return track, fill
end

------------------------------------------------------------------------------
-- Figure (an R6 silhouette)
------------------------------------------------------------------------------

-- Angles in degrees: arms and legs swing forward (+x) and out (+z).
export type Pose = {
	leftArm: Vector2?, -- (forward, out)
	rightArm: Vector2?,
	leftLeg: Vector2?,
	rightLeg: Vector2?,
	turn: number?, -- the whole body, around the vertical
}

export type FigureOptions = {
	pose: Pose?,
	top: Color3?, -- torso and arms
	bottom: Color3?, -- legs
	skin: Color3?, -- head
}

local SILHOUETTE = Color3.fromHex("#151515")

local function limb(
	model: Instance,
	name: string,
	size: Vector3,
	pivot: CFrame,
	angles: Vector2?,
	side: number,
	color: Color3
)
	local forward = if angles then math.rad(angles.X) else 0
	local out = if angles then math.rad(angles.Y) * side else 0
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.Size = size
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.CFrame = pivot * CFrame.Angles(forward, 0, out) * CFrame.new(0, -size.Y / 2 + 0.5, 0)
	piece.Parent = model
end

local function buildFigure(model: Model, options: FigureOptions)
	model:ClearAllChildren()
	local pose: Pose = options.pose or {}
	local top = options.top or SILHOUETTE
	local bottom = options.bottom or SILHOUETTE
	local skin = options.skin or SILHOUETTE
	local root = CFrame.Angles(0, math.rad(pose.turn or 0), 0)
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Anchored = true
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = top
	torso.Material = Enum.Material.SmoothPlastic
	torso.CFrame = root
	torso.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = true
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.25, 1.25, 1.25)
	head.Color = skin
	head.Material = Enum.Material.SmoothPlastic
	head.CFrame = root * CFrame.new(0, 1.6, 0)
	head.Parent = model
	-- (shoulders 0.5 under the torso's top; hips at its bottom)
	limb(
		model,
		"LeftArm",
		Vector3.new(1, 2, 1),
		root * CFrame.new(-1.5, 0.5, 0),
		pose.leftArm,
		-1,
		top
	)
	limb(
		model,
		"RightArm",
		Vector3.new(1, 2, 1),
		root * CFrame.new(1.5, 0.5, 0),
		pose.rightArm,
		1,
		top
	)
	limb(
		model,
		"LeftLeg",
		Vector3.new(1, 2, 1),
		root * CFrame.new(-0.5, -1.5, 0),
		pose.leftLeg,
		-1,
		bottom
	)
	limb(
		model,
		"RightLeg",
		Vector3.new(1, 2, 1),
		root * CFrame.new(0.5, -1.5, 0),
		pose.rightLeg,
		1,
		bottom
	)
end

export type Figure = {
	instance: ViewportFrame,
	set: (options: FigureOptions) -> (),
}

function Panel.figure(parent: Instance, options: FigureOptions): Figure
	local viewport = Theme.make("ViewportFrame", {
		Name = "Figure",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 150, 150),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.6, -1, 0.8),
		Parent = parent,
	}) :: ViewportFrame
	local model = Instance.new("Model")
	model.Name = "Fighter"
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	-- Seen from the front, a little from the side and above.
	camera.CFrame = CFrame.lookAt(Vector3.new(-3.6, 1.4, -11.5), Vector3.new(0, 0, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	buildFigure(model, options)
	return {
		instance = viewport,
		set = function(newOptions: FigureOptions)
			buildFigure(model, newOptions)
		end,
	}
end

return table.freeze(Panel)
