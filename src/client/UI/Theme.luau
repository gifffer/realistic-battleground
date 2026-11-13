--!strict
-- The look of the whole interface, in one place.
--
-- Direction "editorial / film" (think Sifu, The Last of Us), with BOLD,
-- tight type (heavy condensed caps, bold titles): almost no
-- boxes. Off-white type and 1–2 px hairlines on soft dark gradients, SQUARE
-- corners everywhere, one desaturated blood red used ONLY for danger.
-- Text shown to players is in English (game rule).
--
-- Rules that keep it from looking like a template:
--   • no UICorner, no pills, no filled buttons, no drop-shadowed boxes;
--   • no Gotham fonts, nothing above 40 px, no exclamation marks;
--   • no saturated colour: blood red means "danger / you are hurt";
--   • nothing centred that doesn't need to be: the middle of the screen
--     belongs to the fight.
--
-- Helpers:
--   Theme.make(className, props, children)   build an instance from a table
--   Theme.text(props)                        a TextLabel with the defaults
--   Theme.track("HEALTH", "three")           wide letter-spacing (see below)
--   Theme.gradient(rotation, { {0, 0.4}, {1, 1} })   a transparency gradient
--   Theme.keyCap("M1")                       an outlined key ("M1", "ESC"...)
--   Theme.tween(instance, seconds, props, style?, direction?)
--
-- Phones and small windows (layouts are drawn for 1280 × 720 and up):
--   Theme.scaleFor(viewport, minScale)       the UIScale a block should use
--   Theme.autoScale(frame, minScale?)        adds a UIScale that follows the screen
--   Theme.onViewportChanged(callback)        callback(viewport) now and on every resize
--   Theme.isTouch()                          a touch screen with no mouse (phone, tablet)

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = {}

Theme.Colors = table.freeze({
	Ink = Color3.fromHex("#ECE8E1"), -- main text, bars, hairlines (warm off-white)
	InkHi = Color3.fromHex("#FFFFFF"), -- the local player's own name only
	Ink2 = Color3.fromHex("#A9A49B"), -- secondary labels, stamina
	InkVerb = Color3.fromHex("#C9C4BA"), -- kill feed verbs
	Ink3 = Color3.fromHex("#6E6A64"), -- tertiary labels (on dark only), disabled
	Scrim = Color3.fromHex("#0B0B0C"), -- every dark gradient, bars, key caps
	Blood = Color3.fromHex("#9E2B25"), -- danger fills (exhausted stamina)
	BloodHi = Color3.fromHex("#B8423A"), -- danger text / lines (low HP, damage, head aim)
	BloodDeep = Color3.fromHex("#6E1814"), -- knock-out edge vignette
})

local FAMILY = {
	Condensed = "rbxasset://fonts/families/RobotoCondensed.json",
	Mono = "rbxasset://fonts/families/RobotoMono.json",
	Oswald = "rbxasset://fonts/families/Oswald.json",
	Roboto = "rbxasset://fonts/families/Roboto.json",
}

-- Weights: between the first thin look (too serious) and full bold (not
-- serious enough): semi-bold labels, medium titles, a little spacing. The names stay the same so every screen follows: e.g.
-- "NumberLight" is now a bold number too.
Theme.Fonts = table.freeze({
	Label = Font.new(FAMILY.Condensed, Enum.FontWeight.SemiBold), -- caps labels, names
	LabelBold = Font.new(FAMILY.Condensed, Enum.FontWeight.Bold), -- feedback words
	LabelRegular = Font.new(FAMILY.Condensed, Enum.FontWeight.Medium), -- kill feed verbs
	Number = Font.new(FAMILY.Mono, Enum.FontWeight.Medium), -- tabular numbers
	NumberLight = Font.new(FAMILY.Mono, Enum.FontWeight.Medium), -- the big HP number
	NumberMedium = Font.new(FAMILY.Mono, Enum.FontWeight.SemiBold), -- key caps
	Display = Font.new(FAMILY.Oswald, Enum.FontWeight.Medium), -- titles
	Body = Font.new(FAMILY.Roboto, Enum.FontWeight.Regular), -- sentences
})

-- Every text a bit bigger than its layout asks (bold, tight text reads
-- better slightly larger). Applied by Theme.text and Theme.keyCap.
Theme.TEXT_SCALE = 1.06

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

-- Letter-spacing. Roblox has no letter-spacing property, so we put a
-- narrow Unicode space between every letter. The look is now TIGHT and
-- punchy: only a hair space for small caps labels, nothing for titles.
--   "three" / "four" = small labels (a hair apart)
--   "thin" / "en"    = titles (letters as drawn)
local TRACK_SPACES: { [string]: string } = {
	thin = "\u{200A}",
	four = "\u{2009}",
	three = "\u{2009}",
	en = "\u{200A}",
}

function Theme.track(text: string, kind: string): string
	local space = TRACK_SPACES[kind]
	if space == nil then
		space = TRACK_SPACES.three
	end
	if space == "" then
		return text
	end
	local out = {}
	for _, code in utf8.codes(text) do
		local char = utf8.char(code)
		table.insert(out, if char == " " then " " else char)
	end
	return table.concat(out, space)
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
		Size = UDim2.fromOffset(0, 20),
		BackgroundColor3 = Theme.Colors.Scrim,
		BackgroundTransparency = 0.65,
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
			PaddingLeft = UDim.new(0, 7),
			PaddingRight = UDim.new(0, 7),
		}),
		Theme.make("UIStroke", {
			Name = "Outline",
			Thickness = 1,
			Color = Theme.Colors.Ink,
			Transparency = 0.25,
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

local function currentViewport(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else LARGE
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

return table.freeze(Theme)
