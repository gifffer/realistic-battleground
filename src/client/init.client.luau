--!strict
-- Realistic Battleground client entry point. Loads every module in Controllers:
-- init() all of them, then start() all of them.

local Controllers = script:FindFirstChild("Controllers")

local loaded: { [string]: any } = {}
if Controllers then
	for _, child in Controllers:GetChildren() do
		if child:IsA("ModuleScript") then
			loaded[child.Name] = require(child) :: any
		end
	end
end

for _, controller in loaded do
	if typeof(controller.init) == "function" then
		controller.init()
	end
end

for _, controller in loaded do
	if typeof(controller.start) == "function" then
		task.spawn(controller.start)
	end
end

local Config = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
) :: any
print(`[{Config.GAME_TITLE} {Config.VERSION}] client started`)
