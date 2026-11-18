-- Loads the repo's Luau modules in Lune with Roblox datatypes and a fake
-- require / game (enough for pure modules such as Animation/Locomotion).
-- Run from the repo root.
-- Loads repo modules in Lune with Roblox datatypes and a fake require.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local process = require("@lune/process")
local REPO = process.cwd .. "/src/"
local cache = {}

local function node(path)
	return setmetatable({ __path = path }, {
		__index = function(self, key)
			if key == "Parent" then
				local parent = string.match(path, "^(.*)/[^/]+$") or ""
				return node(parent)
			end
			return node(path .. "/" .. key)
		end,
	})
end

local env
local function load(path)
	if cache[path] then
		return cache[path]
	end
	local file = REPO .. path .. ".luau"
	if not fs.isFile(file) then
		file = REPO .. path .. "/init.luau"
	end
	local source = fs.readFile(file)
	local chunk = luau.load(luau.compile(source), {
		debugName = path,
		environment = (function()
			local e = { script = node(path) }
			for k, v in env do
				e[k] = v
			end
			return e
		end)(),
	})
	local result = chunk()
	cache[path] = result
	return result
end

local game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return node("shared"):__dummy()
		end
		return {}
	end,
}
-- ReplicatedStorage.Shared.X -> shared/X
local replicated = setmetatable({}, {
	__index = function(_, key)
		if key == "Shared" then
			return node("shared")
		end
		return node(key)
	end,
})
game.GetService = function(_, name)
	if name == "ReplicatedStorage" then
		return replicated
	end
	return setmetatable({}, { __index = function() return function() end end })
end

env = ({
	game = game,
	require = function(target)
		if type(target) == "table" and target.__path then
			return load(target.__path)
		end
		return require(target)
	end,
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	UDim2 = roblox.UDim2,
	UDim = roblox.UDim,
	BrickColor = roblox.BrickColor,
	Instance = roblox.Instance,
})
for k, v in { math = math, table = table, string = string, os = os, pairs = pairs, ipairs = ipairs, next = next, type = type, typeof = typeof, setmetatable = setmetatable, getmetatable = getmetatable, print = print, warn = print, error = error, assert = assert, tostring = tostring, tonumber = tonumber, select = select, pcall = pcall, rawget = rawget, rawset = rawset, unpack = table.unpack, bit32 = bit32, utf8 = utf8, coroutine = coroutine, task = task, vector = vector, buffer = buffer } do
	env[k] = v
end

return { load = load, roblox = roblox }
