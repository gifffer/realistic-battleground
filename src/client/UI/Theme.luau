--!strict
-- The look of the whole interface, in one place.
--
-- Direction "editorial / film" (think Sifu, The Last of Us): almost no
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

local TweenService = game:GetService("TweenService")

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

Theme.Fonts = table.freeze({
	Label = Font.new(FAMILY.Condensed, Enum.FontWeight.Medium), -- caps labels, names
	LabelBold = Font.new(FAMILY.Condensed, Enum.FontWeight.Bold), -- feedback words
	LabelRegular = Font.new(FAMILY.Condensed, Enum.FontWeight.Regular), -- kill feed verbs
	Number = Font.new(FAMILY.Mono, Enum.FontWeight.Regular), -- tabular numbers
	NumberLight = Font.new(FAMILY.Mono, Enum.FontWeight.Light), -- the big HP number
	NumberMedium = Font.new(FAMILY.Mono, Enum.FontWeight.Medium), -- key caps
	Display = Font.new(FAMILY.Oswald, Enum.FontWeight.Light), -- titles
	Body = Font.new(FAMILY.Roboto, Enum.FontWeight.Regular), -- sentences
})

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
	for key, value in props do
		defaults[key] = value
	end
	return Theme.make(props.ClassName or "TextLabel", defaults, children)
end

-- Letter-spacing. Roblox has no letter-spacing property and the wide
-- tracking is the whole look, so we put a narrow Unicode space between
-- every letter (a word space becomes three of them).
--   "three" = wide (small caps labels)   "four" = medium
--   "thin"  = light (big titles)          "en"   = very wide (KO title)
local TRACK_SPACES: { [string]: string } = {
	thin = "\u{2009}",
	four = "\u{2005}",
	three = "\u{2004}",
	en = "\u{2002}",
}

function Theme.track(text: string, kind: string): string
	local space = TRACK_SPACES[kind] or TRACK_SPACES.three
	local out = {}
	for _, code in utf8.codes(text) do
		local char = utf8.char(code)
		table.insert(out, if char == " " then space .. space .. space else char)
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
		Text = text,
	}
	if props then
		for key, value in props do
			base[key] = value
		end
	end
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

return table.freeze(Theme)
