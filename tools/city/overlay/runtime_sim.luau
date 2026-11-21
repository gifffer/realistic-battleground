--!nocheck
-- runtime_sim: runs the REAL loadData / mergeAlleys / applyOverlay code of
-- src/server/Systems/City/init.luau under Lune (outside Roblox), to check that the game applies
-- the CityOverlay exactly like tools/city/overlay/apply.py (selftest.py --luau drives it).
--
--   lune run tools/city/overlay/runtime_sim.luau <city dir> <overlay json or ""> <out json>
--
-- The functions are cut out of init.luau by their names (no copy to keep in step); HttpService,
-- script:FindFirstChild and require are stubbed with the data files.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local cityDir, overlayPath, outPath = process.args[1], process.args[2], process.args[3]
local source = fs.readFile(cityDir .. "/init.luau")

-- the text from the line that starts with `first` to the line before the one starting with `stop`
local function cut(first: string, stop: string): string
	local a = string.find(source, "\n" .. first, 1, true)
	assert(a, "not found: " .. first)
	local b = string.find(source, "\n" .. stop, a + 1, true)
	assert(b, "not found: " .. stop)
	return string.sub(source, a + 1, b)
end

local function longString(text: string): string
	return string.match(text, "%[==%[(.*)%]==%]")
end

local modules = {}
for _, name in fs.readDir(cityDir) do
	local stem = string.match(name, "^(.-)%.luau$")
	if stem and (string.match(stem, "^CityData%d+$") or string.match(stem, "^AlleyData%d+$")) then
		modules[stem] = longString(fs.readFile(cityDir .. "/" .. name))
	end
end
if overlayPath ~= "" then
	modules["CityOverlay1"] = fs.readFile(overlayPath)
else
	for _, name in fs.readDir(cityDir) do
		local stem = string.match(name, "^(CityOverlay%d+)%.luau$")
		if stem then
			modules[stem] = longString(fs.readFile(cityDir .. "/" .. name))
		end
	end
end

local env = {
	HttpService = {
		JSONDecode = function(_, text)
			return serde.decode("json", text)
		end,
	},
	script = {
		FindFirstChild = function(_, name)
			local text = modules[name]
			if text == nil then
				return nil
			end
			return {
				text = text,
				IsA = function()
					return true
				end,
			}
		end,
	},
	require = function(module)
		return module.text
	end,
	Vector3 = roblox.Vector3,
}
setmetatable(env, { __index = _G })

local chunk = table.concat({
	cut("local COL = {", "-- Bits of the FLAGS column."),
	cut("local function loadData", "-- Merging another data set"),
	cut("local function remapList", "-- THE ALLEYS:"),
	cut("local function mergeAlleys", "-- THE CITY OVERLAY:"),
	cut("local OVERLAY_TOLERANCE", "local function hasBit"),
	"local data = loadData()\nmergeAlleys(data)\napplyOverlay(data)\nreturn data\n",
}, "\n")
-- (the type annotations are fine for Lune's Luau)
local data = luau.load(chunk, { debugName = "City/init.luau (cut)", environment = env })()

local skip = {}
for index in data.skip or {} do
	table.insert(skip, index - 1)
end
table.sort(skip)
fs.writeFile(outPath, serde.encode("json", { parts = data.parts, extras = data.extras, skip = skip }))
print(`runtime_sim: {#data.parts} rows, {#skip} skipped`)
