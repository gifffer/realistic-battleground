--!strict
-- Look of the whole interface (colors, fonts, sizes) + a small helper to
-- build UI from code.
--
-- Change a color here → it changes everywhere. Text shown to players is in
-- English (game rule).
--
-- Theme.make("Frame", { Size = ..., BackgroundColor3 = ... }, { children })
-- creates an instance, sets its properties and parents the children to it.
-- Same thing as building it by hand in Studio, but versioned in Git.

local Theme = {}

Theme.Colors = table.freeze({
	Background = Color3.fromRGB(16, 17, 20),
	Panel = Color3.fromRGB(28, 30, 35),
	PanelLight = Color3.fromRGB(44, 47, 54),
	Accent = Color3.fromRGB(230, 170, 60), -- warm "street light" orange
	Text = Color3.fromRGB(235, 235, 235),
	TextDim = Color3.fromRGB(150, 152, 160),
	Health = Color3.fromRGB(200, 45, 45),
	Stamina = Color3.fromRGB(225, 190, 70),
	Exhausted = Color3.fromRGB(150, 85, 40),
	On = Color3.fromRGB(70, 160, 90),
	Off = Color3.fromRGB(90, 92, 100),
})

Theme.Fonts = table.freeze({
	Title = Enum.Font.GothamBlack,
	Bold = Enum.Font.GothamBold,
	Regular = Enum.Font.Gotham,
})

Theme.CORNER = UDim.new(0, 6)

-- Creates `className`, applies `props`, parents `children` to it.
-- Returns `any` so callers can cast it: `Theme.make("Frame", {...}) :: Frame`.
function Theme.make(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className) :: any
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

-- Rounded corners, used on almost every panel.
function Theme.corner(radius: UDim?): Instance
	return Theme.make("UICorner", { CornerRadius = radius or Theme.CORNER })
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

return table.freeze(Theme)
