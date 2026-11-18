--!strict
-- The look of the whole interface, in one place.
--
-- Direction: quiet and minimal, like a shipped game menu (a plain list
-- of words, no boxes). The fight is the show; the interface stays small
-- and out of the way.
--
-- Rules:
--   • black / white / grey. One red (Accent), used SMALL: a thin bar
--     next to the selected item, a short mark on the main button. Never a
--     big red block;
--   • lists are plain text: dim grey = not picked, white + red bar =
--     picked, white = under the mouse. No plates, no numbers, no slashes;
--   • buttons are small: outlined (main action) or text only;
--   • one font (Builder Sans) in 3 sizes: 20 titles, 13 text, 11 small.
--     Normal letter spacing. Captions only where a column needs a name;
--   • thin lines only (1 px), few of them; see-through backdrops so the
--     game still shows;
--   • anything you can click is a REAL button (UI/Button), never hand-made;
--   • the top bar panels (Controllers/MenuController, UI/Panel): one
--     black see-through plate (PANEL_TRANSPARENCY), no border, bold white
--     titles, grids of slightly lighter cards (Card / CardHi); what you
--     wear = thin gold outline (Gold), what you picked = white outline;
--   • blood red (Blood*) still means danger / you are hurt on the HUD;
--   • the middle of the screen belongs to the fight.
--
-- Helpers:
--   Theme.make(className, props, children)   build an instance from a table
--   Theme.text(props)                        a TextLabel with the defaults
--   Theme.track(text, kind)                  kept for old calls: returns text as is
--   Theme.sentence("IN A DUEL")              "In a duel"
--   Theme.gradient(rotation, { {0, 0.4}, {1, 1} })   a transparency gradient
--   Theme.keyCap("M1")                       an outlined key ("M1", "ESC"...)
--   Theme.tween(instance, seconds, props, style?, direction?)
--   (buttons: UI/Button.new / Button.badge, never hand-made)
--
-- Phones and small windows (layouts are drawn for 1280 × 720 and up):
--   Theme.scaleFor(viewport, minScale)       the UIScale a block should use
--   Theme.autoScale(frame, minScale?)        adds a UIScale that follows the screen
--   Theme.onViewportChanged(callback)        callback(viewport) now and on every resize
--   Theme.isTouch()                          a touch screen with no mouse (phone, tablet)
--   Theme.topInset(side, viewport)           height of Roblox's top bar on that side (0 if free)

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = {}

Theme.Colors = table.freeze({
	Ink = Color3.fromHex("#E6E6E6"), -- main text, bars, hairlines (off-white)
	InkHi = Color3.fromHex("#FFFFFF"), -- selected / hovered text, own name
	Ink2 = Color3.fromHex("#9A9A9A"), -- secondary text, unselected list items
	InkVerb = Color3.fromHex("#BDBDBD"), -- kill feed verbs
	Ink3 = Color3.fromHex("#646464"), -- tertiary labels (on dark only), disabled
	Scrim = Color3.fromHex("#0A0A0A"), -- every dark backdrop, bars, key caps
	Plate = Color3.fromHex("#1A1A1A"), -- rare flat fills (bars' empty part)
	PlateHi = Color3.fromHex("#2C2C2C"), -- that fill under the mouse
	Blood = Color3.fromHex("#9E2B25"), -- danger fills (exhausted stamina)
	BloodHi = Color3.fromHex("#C23A31"), -- danger text / lines (low HP, damage, head aim)
	BloodDeep = Color3.fromHex("#6E1814"), -- knock-out edge vignette
	Accent = Color3.fromHex("#D8423A"), -- THE accent (small: selection bar, main button mark)
	AccentHi = Color3.fromHex("#EE5A50"), -- accent under the mouse
	AccentDeep = Color3.fromHex("#A3302A"), -- accent while pressed
	-- Panels (top bar windows): see-through black plates, slightly lighter cards.
	Card = Color3.fromHex("#1E1E1E"), -- a card in a grid
	CardHi = Color3.fromHex("#343434"), -- the selected card / a card under the mouse
	Gold = Color3.fromHex("#E2B84E"), -- what you wear / have equipped (thin outline, small text)
	Progress = Color3.fromHex("#8CC79A"), -- XP and quest bars
	Pill = Color3.fromHex("#121215"), -- the top bar buttons (like Roblox's own)
})

-- How see-through the panels' black plate is (0 = solid).
Theme.PANEL_TRANSPARENCY = 0.35

-- Corner radius of buttons and cards (pixels): none, hard edges.
Theme.RADIUS = 0

-- One family, three weights. The names stay the same so every screen
-- follows (they used to be different faces).
local FAMILY = "rbxasset://fonts/families/BuilderSans.json"

Theme.Fonts = table.freeze({
	Label = Font.new(FAMILY, Enum.FontWeight.Medium), -- labels, names
	LabelBold = Font.new(FAMILY, Enum.FontWeight.SemiBold), -- buttons, feedback words
	LabelRegular = Font.new(FAMILY, Enum.FontWeight.Regular), -- kill feed verbs
	Number = Font.new(FAMILY, Enum.FontWeight.Medium), -- numbers
	NumberLight = Font.new(FAMILY, Enum.FontWeight.SemiBold), -- the big HP number
	NumberMedium = Font.new(FAMILY, Enum.FontWeight.Medium), -- key caps
	Display = Font.new(FAMILY, Enum.FontWeight.Bold), -- titles
	Body = Font.new(FAMILY, Enum.FontWeight.Regular), -- sentences
})

-- The three text sizes of the menus (titles, text, small).
Theme.TITLE = 20
Theme.TEXT = 13
Theme.SMALL = 11

-- Multiplier on every text size (kept at 1: the sizes are what they say).
Theme.TEXT_SCALE = 1

-- Soft shadow behind text drawn over the 3D world (never a hard outline).
Theme.STROKE_TRANSPARENCY = 0.8

-- Standard animation timings (quick and quiet: nothing bounces).
Theme.FAST = 0.12
Theme.NORMAL = 0.2

------------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------------

-- Creates `className`, applies `props`, parents `children` to it.
-- Returns `any` so callers can cast it: `Theme.make("Frame", {...}) :: Frame`.
function Theme.make(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className) :: any
	if instance:IsA("GuiObject") then
		instance.BorderSizePixel = 0
	end
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	-- Parent last: Roblox recommends it (faster, no half-built UI on screen).
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- A TextLabel with the house defaults: transparent, no wrapping, off-white,
-- condensed font, soft shadow. Any property can be overridden in `props`.
function Theme.text(props: { [string]: any }, children: { Instance }?): any
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Label,
		TextSize = 11,
		TextColor3 = Theme.Colors.Ink,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = Theme.STROKE_TRANSPARENCY,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		RichText = false,
	}
	-- `ClassName` picks the class (e.g. "TextButton"); it is not a property
	-- we can set (read-only), so it is kept out of the copied props.
	local className = props.ClassName or "TextLabel"
	for key, value in props do
		if key ~= "ClassName" then
			defaults[key] = value
		end
	end
	defaults.TextSize = math.floor(defaults.TextSize * Theme.TEXT_SCALE + 0.5)
	return Theme.make(className, defaults, children)
end

-- Letter-spacing used to go here (spaces between letters). The look now
-- uses normal spacing everywhere, so this returns the text as it is; the
-- old calls stay valid.
function Theme.track(text: string, _kind: string): string
	return text
end

-- "IN A DUEL" → "In a duel": status words written in caps, shown as a
-- plain sentence (only the first letter stays a capital).
function Theme.sentence(text: string): string
	return string.upper(string.sub(text, 1, 1)) .. string.lower(string.sub(text, 2))
end

-- A UIGradient that only changes transparency. `points` = { {time, transparency}, ... }
-- with times from 0 to 1. Rotation 0 = left → right, 90 = top → bottom.
function Theme.gradient(rotation: number, points: { { number } }): any
	local keypoints = {}
	for _, point in points do
		table.insert(keypoints, NumberSequenceKeypoint.new(point[1], point[2]))
	end
	return Theme.make("UIGradient", {
		Rotation = rotation,
		Transparency = NumberSequence.new(keypoints),
	})
end

-- An outlined key cap, sized to its text: "M1", "ESC", "LEFT CTRL".
function Theme.keyCap(text: string, props: { [string]: any }?): any
	local base: { [string]: any } = {
		Name = "KeyCap",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		BackgroundColor3 = Theme.Colors.Scrim,
		BackgroundTransparency = 0.75,
		FontFace = Theme.Fonts.NumberMedium,
		TextSize = 10,
		TextColor3 = Theme.Colors.Ink,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = text,
	}
	if props then
		for key, value in props do
			base[key] = value
		end
	end
	base.TextSize = math.floor(base.TextSize * Theme.TEXT_SCALE + 0.5)
	return Theme.make("TextLabel", base, {
		Theme.make("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
		Theme.make("UIStroke", {
			Name = "Outline",
			Thickness = 1,
			Color = Theme.Colors.Ink,
			Transparency = 0.6,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
end

-- Inner margin of a frame, in pixels.
function Theme.padding(pixels: number): Instance
	local offset = UDim.new(0, pixels)
	return Theme.make("UIPadding", {
		PaddingTop = offset,
		PaddingBottom = offset,
		PaddingLeft = offset,
		PaddingRight = offset,
	})
end

-- Plays a tween and returns it. Default easing: Quad Out.
function Theme.tween(
	instance: Instance,
	seconds: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(
			seconds,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out
		),
		props
	)
	tween:Play()
	return tween
end

------------------------------------------------------------------------------
-- Screen size
------------------------------------------------------------------------------

-- Every layout was drawn at 1280 × 720 or more. Smaller (a phone, a small
-- window): shrink, never under `minScale` (text must stay readable). Bigger
-- than 1920 × 1080 (1440p, 4K): grow a little, at most ×1.35. Between the
-- two: ×1, exactly as drawn.
local SMALL = Vector2.new(1280, 720)
local LARGE = Vector2.new(1920, 1080)
local MAX_SCALE = 1.35

function Theme.scaleFor(viewport: Vector2, minScale: number): number
	local small = math.min(viewport.X / SMALL.X, viewport.Y / SMALL.Y)
	if small < 1 then
		return math.max(small, minScale)
	end
	return math.clamp(math.min(viewport.X / LARGE.X, viewport.Y / LARGE.Y), 1, MAX_SCALE)
end

-- One listener on the camera for every block that follows the screen size.
local viewportListeners: { (Vector2) -> () } = {}
local watchedCamera: Camera? = nil
local cameraConnection: RBXScriptConnection? = nil

-- The screen size. An empty full-screen ScreenGui measures it: the
-- camera's ViewportSize can read 1 x 1 for a while (a camera swapped in
-- before it is drawn), which shrank and pushed the whole UI off screen.
local probe: ScreenGui? = nil
local function screenProbe(): ScreenGui?
	if probe then
		return probe
	end
	local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local made = Instance.new("ScreenGui")
	made.Name = "ScreenProbe"
	made.IgnoreGuiInset = true
	made.ResetOnSpawn = false
	made.Parent = playerGui
	probe = made
	return made
end

local function currentViewport(): Vector2
	local gui = screenProbe()
	if gui and gui.AbsoluteSize.X > 2 and gui.AbsoluteSize.Y > 2 then
		return gui.AbsoluteSize
	end
	local camera = workspace.CurrentCamera
	if camera and camera.ViewportSize.X > 2 and camera.ViewportSize.Y > 2 then
		return camera.ViewportSize
	end
	return LARGE
end

-- The screen size in pixels (see currentViewport).
function Theme.viewport(): Vector2
	return currentViewport()
end

local function notifyViewport()
	local viewport = currentViewport()
	for _, listener in table.clone(viewportListeners) do
		listener(viewport)
	end
end

local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera == watchedCamera then
		return
	end
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	watchedCamera = camera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(notifyViewport)
	end
	notifyViewport()
end

local cameraWatched = false

-- Calls `callback(viewport)` now and after every resize. Returns the
-- function that stops it.
function Theme.onViewportChanged(callback: (Vector2) -> ()): () -> ()
	if not cameraWatched then
		cameraWatched = true
		workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
		-- Roblox's top bar changed (shown, hidden, new buttons): refit too.
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(notifyViewport)
		local gui = screenProbe()
		if gui then
			gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(notifyViewport)
		end
		watchCamera()
	end
	table.insert(viewportListeners, callback)
	callback(currentViewport())
	return function()
		local index = table.find(viewportListeners, callback)
		if index then
			table.remove(viewportListeners, index)
		end
	end
end

-- Adds a UIScale to `frame` that follows the screen size (see scaleFor).
-- The frame shrinks / grows around its AnchorPoint, so a block anchored to
-- a corner stays in its corner. Stops by itself when the frame is destroyed.
function Theme.autoScale(frame: GuiObject, minScale: number?): UIScale
	local scale = Theme.make("UIScale", { Name = "AutoScale", Parent = frame }) :: UIScale
	local floor = minScale or 0.7
	local stop = Theme.onViewportChanged(function(viewport)
		scale.Scale = Theme.scaleFor(viewport, floor)
	end)
	frame.Destroying:Once(stop)
	return scale
end

-- Screen pixels (AbsolutePosition, AbsoluteSize, TextBounds: measured after
-- every UIScale above `instance`) back to the layout's own pixels (what
-- Size / Position offsets use inside it).
function Theme.unscaled(instance: Instance, pixels: number): number
	local scale = 1
	local current: Instance? = instance
	while current do
		local uiScale = current:FindFirstChildOfClass("UIScale")
		if uiScale then
			scale *= uiScale.Scale
		end
		current = current.Parent
	end
	return if scale > 0 then pixels / scale else pixels
end

-- A touch screen with no mouse: a phone or a tablet (the move bar becomes
-- buttons, blocks move away from the on-screen jump button).
function Theme.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- Screen pixels taken by Roblox's top bar (menu, chat, backpack... about
-- 36-58 px high) at the top of the `side` edge, 0 when that side is free.
-- For ScreenGuis with IgnoreGuiInset = true: a block anchored to the top
-- keeps its top under this, or the buttons take its taps / hide it.
-- (TopbarInset is the FREE part of the bar: the buttons are left of
-- Min.X and right of Max.X.)
function Theme.topInset(side: "left" | "right", viewport: Vector2): number
	local free = GuiService.TopbarInset
	if free.Height <= 0 then
		-- Not reported (bar hidden or an old client): the classic inset.
		local topLeft = GuiService:GetGuiInset()
		return topLeft.Y
	end
	local covered = if side == "left" then free.Min.X > 1 else free.Max.X < viewport.X - 1
	return if covered then free.Max.Y else 0
end

return table.freeze(Theme)
