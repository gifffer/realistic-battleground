--!strict
-- Ambience: the light of the city, on a cycle (step 11).
--
--   LATE AFTERNOON  warm, low sun, long shadows        (6 min)
--   DUSK            the light falls, lamps come on     (1 min 30)
--   NIGHT           wet streets, orange lamps, neons   (6 min)
--   DAWN            back to the afternoon              (1 min 30)
--
-- Done on the server: Lighting changes replicate, so everyone shares the
-- same moment. At night the lamps ("CityLamp"), neon signs ("CityNeon")
-- and puddles ("CityPuddle") built by Server/Systems/City light up / show.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Ambience = {}

local DAY_TIME = 360
local NIGHT_TIME = 360
local TRANSITION = 90

type Look = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	ExposureCompensation: number,
}

local AFTERNOON: Look = {
	ClockTime = 17.2,
	Brightness = 2.6,
	Ambient = Color3.fromRGB(70, 60, 52),
	OutdoorAmbient = Color3.fromRGB(150, 128, 108),
	ExposureCompensation = 0,
}
local NIGHT: Look = {
	ClockTime = 21.8,
	Brightness = 0.8,
	Ambient = Color3.fromRGB(26, 28, 38),
	OutdoorAmbient = Color3.fromRGB(46, 52, 72),
	ExposureCompensation = 0.25,
}

local atmosphere: Atmosphere
local grade: ColorCorrectionEffect
local bloom: BloomEffect

local function setupEffects()
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "AmbienceGrade"
	grade.Parent = Lighting
	bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 22
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
end

-- Moves the whole look to `day` (true) or `night` over `seconds`.
local function goTo(day: boolean, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local look = if day then AFTERNOON else NIGHT
	TweenService:Create(Lighting, info, look :: any):Play()
	TweenService:Create(atmosphere, info, {
		Density = if day then 0.28 else 0.38,
		Haze = if day then 1.2 else 2.2,
		Color = if day then Color3.fromRGB(214, 170, 130) else Color3.fromRGB(70, 84, 120),
		Decay = if day then Color3.fromRGB(150, 100, 70) else Color3.fromRGB(40, 46, 70),
		Glare = if day then 0.4 else 0,
	}):Play()
	TweenService:Create(grade, info, {
		TintColor = if day then Color3.fromRGB(255, 236, 214) else Color3.fromRGB(214, 224, 255),
		Saturation = if day then 0.05 else -0.1,
		Contrast = if day then 0.05 else 0.1,
	}):Play()
	-- Lamps, neons, wet puddles: on halfway through the dusk, off at dawn.
	task.delay(seconds / 2, function()
		for _, head in CollectionService:GetTagged("CityLamp") do
			local light = head:FindFirstChild("Light")
			if light and light:IsA("SpotLight") then
				light.Brightness = if day then 0 else 2.4
			end
			if head:IsA("BasePart") then
				head.Transparency = if day then 0.35 else 0
			end
		end
		for _, sign in CollectionService:GetTagged("CityNeon") do
			local light = sign:FindFirstChild("Light")
			if light and light:IsA("PointLight") then
				light.Brightness = if day then 0 else 1.6
			end
			if sign:IsA("BasePart") then
				sign.Transparency = if day then 0.4 else 0
			end
		end
		for _, water in CollectionService:GetTagged("CityPuddle") do
			if water:IsA("BasePart") then
				water.Transparency = if day then 1 else 0.15
				water.Reflectance = if day then 0 else 0.55
			end
		end
	end)
end

function Ambience.start()
	setupEffects()
	-- Start in the afternoon right away.
	for key, value in AFTERNOON do
		(Lighting :: any)[key] = value
	end
	goTo(true, 0.1)
	task.spawn(function()
		while true do
			task.wait(DAY_TIME)
			goTo(false, TRANSITION)
			task.wait(TRANSITION + NIGHT_TIME)
			goTo(true, TRANSITION)
			task.wait(TRANSITION)
		end
	end)
end

return Ambience
