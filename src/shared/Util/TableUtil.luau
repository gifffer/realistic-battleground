--!strict
-- Small table helpers.

local TableUtil = {}

-- Copies a table and every table inside it. Use it when you need an
-- independent copy (changing the copy never changes the original).
function TableUtil.deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value :: any do
		copy[key] = TableUtil.deepCopy(item)
	end
	return copy :: any
end

return table.freeze(TableUtil)
