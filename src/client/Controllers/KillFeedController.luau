--!strict
-- KillFeedController: the list of eliminations in the top-right corner.
--
--   "Killer  FINISHED  Victim"
--   "Victim  FLED  (Killer gets the kill)"
--   "Victim  DIED"
--
-- One line per Remotes.KillFeed message from the server. The newest line
-- is on top; each one fades out after Config.Knockout.FEED_TIME seconds,
-- and there are never more than FEED_LINES lines.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer
local K = Config.Knockout

local LINE_HEIGHT = 26
local VERB_COLOR = Color3.fromRGB(235, 60, 60)
local YOU_COLOR = Theme.Colors.Accent

local KillFeedController = {}

local list: Frame
local order = 0 -- newest line gets the smallest LayoutOrder (on top)

-- Rich text helpers: a name (yours in the accent color) and a verb in red.
local function escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function colorize(text: string, color: Color3): string
	return `<font color="#{color:ToHex()}">{escape(text)}</font>`
end

local function name(text: string): string
	if text == player.DisplayName then
		return colorize(text, YOU_COLOR)
	end
	return escape(text)
end

local function lineText(kind: Types.KillFeedKind, victim: string, killer: string?): string
	if kind == "Finished" and killer then
		return `{name(killer)}  {colorize("FINISHED", VERB_COLOR)}  {name(victim)}`
	elseif kind == "Fled" then
		local credit = if killer then `  ({name(killer)} gets the kill)` else ""
		return `{name(victim)}  {colorize("FLED", VERB_COLOR)}{credit}`
	elseif killer then
		return `{name(killer)}  {colorize("ELIMINATED", VERB_COLOR)}  {name(victim)}`
	end
	return `{name(victim)}  {colorize("DIED", VERB_COLOR)}`
end

local function addLine(kind: unknown, victim: unknown, killer: unknown)
	if typeof(kind) ~= "string" or typeof(victim) ~= "string" then
		return
	end
	local killerName = if typeof(killer) == "string" then killer else nil
	order -= 1
	local label = Theme.make("TextLabel", {
		Name = "Line",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, LINE_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.35,
		Font = Theme.Fonts.Bold,
		TextSize = 15,
		TextColor3 = Theme.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		RichText = true,
		Text = lineText(kind :: Types.KillFeedKind, victim, killerName),
		Parent = list,
	}, { Theme.corner(UDim.new(0, 4)), Theme.padding(5) }) :: TextLabel

	-- Too many lines: remove the oldest.
	local lines: { TextLabel } = {}
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(lines, child)
		end
	end
	table.sort(lines, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = K.FEED_LINES + 1, #lines do
		lines[index]:Destroy()
	end

	task.delay(K.FEED_TIME, function()
		if label.Parent == nil then
			return
		end
		local fade = TweenService:Create(
			label,
			TweenInfo.new(0.6),
			{ TextTransparency = 1, BackgroundTransparency = 1 }
		)
		fade.Completed:Connect(function()
			label:Destroy()
		end)
		fade:Play()
	end)
end

function KillFeedController.start()
	local gui = Theme.make("ScreenGui", {
		Name = "KillFeed",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		Parent = player:WaitForChild("PlayerGui"),
	}, {
		Theme.make("Frame", {
			Name = "List",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 16),
			Size = UDim2.fromOffset(420, K.FEED_LINES * (LINE_HEIGHT + 4)),
			BackgroundTransparency = 1,
		}, {
			Theme.make("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 4),
			}),
		}),
	})
	list = gui.List
	Remotes.KillFeed.OnClientEvent:Connect(addLine)
end

return KillFeedController
