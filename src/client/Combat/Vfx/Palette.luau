--!strict
-- Vfx/Palette: every colour and texture of the combat VFX, in one place.
--
-- The look is REAL light and matter: a hot warm-white flash and its light,
-- sweat / moisture specks, air, dust, debris. No neon, no pastel magic.
-- Blood is NEVER drawn here: its colours stay in Combat/Blood (Blood.PALETTE).

local Palette = {}

-- Contact flash
Palette.FlashCore = Color3.fromRGB(255, 247, 235) -- hot white
Palette.FlashWarm = Color3.fromRGB(255, 225, 190) -- the killing hit's 2nd flash
Palette.GuardWarm = Color3.fromRGB(255, 214, 150) -- a blow on the guard
Palette.Light = Color3.fromRGB(255, 236, 214) -- the contact point light

-- Sparks on bodies = moisture thrown off the skin (white → grey)
Palette.Moisture = ColorSequence.new(Color3.fromRGB(255, 250, 240), Color3.fromRGB(205, 200, 190))
Palette.Speck = Color3.fromRGB(215, 215, 210)
-- Warm sparks: metal, stone, glass only
Palette.SparkWarm = ColorSequence.new(Color3.fromRGB(255, 220, 160), Color3.fromRGB(255, 140, 60))
Palette.GlassGlint = Color3.fromRGB(235, 245, 235)
Palette.Beer = Color3.fromRGB(176, 132, 52)

-- Air and dust
Palette.Air = Color3.fromRGB(225, 220, 210) -- pressure rings
Palette.Trail = Color3.fromRGB(235, 232, 225) -- swing trails, speed lines
Palette.Streak = Color3.fromRGB(245, 242, 235)
Palette.Pressure = Color3.fromRGB(25, 22, 20) -- the dark ring of lines (KO)
Palette.DustLight = Color3.fromRGB(150, 145, 138)
Palette.DustDark = Color3.fromRGB(110, 106, 100)
Palette.DustBase = Color3.fromRGB(120, 112, 100) -- floor colours are pulled toward this
Palette.Crack = Color3.fromRGB(28, 26, 24)
Palette.Ghost = Color3.fromRGB(200, 200, 200) -- smear / afterimage tint

-- Dr. Rift's accents only (his gadget green stays in his own modules)
Palette.RiftTint = Color3.fromRGB(200, 255, 215)

-- Textures. Built-in Roblox textures: they work with no upload.
-- (Custom ones can be uploaded later: put the "rbxassetid://..." here and
-- every layer picks it up. tools: TECHNIQUES §17.)
local BUILT_IN = "rbxasset://textures/particles/"
Palette.TEXTURES = table.freeze({
	flash = BUILT_IN .. "explosion01_core_main.dds",
	spark = BUILT_IN .. "fire_sparks_main.dds",
	smoke = BUILT_IN .. "smoke_main.dds",
	ring = BUILT_IN .. "explosion01_shockwave_main.dds",
	-- No texture: the beams / trails are plain tapered lines.
	streak = "",
	trail = "",
	crack = "", -- a crack decal; empty = drawn with thin dark parts
})

return table.freeze(Palette)
