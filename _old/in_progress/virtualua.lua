--[[
	make the standard Lua 5.1 more virtualizable.

	- unpack() accepts any indexable object
	- next() honor __next
	- pairs() honors __pairs, and it's otherwise implemented in tems of next()
	- table.sort() accepts any callable object
	- type() honors __type which can be either a string or a function
	- tonumber() honors __tonumber

]]

local unpack = unpack
local pairs = pairs
local ipairs = ipairs
local type = type
local getmetatable = getmetatable

module(...)

local lua_type = type

local applicable_prims = {
	__call = 'function', __index = 'table', __newindex = 'table',
	__tostring = 'string', __tonumber = 'number'
	__add = 'number', __sub = 'number',
}

function applicable(x,mm)
	if applicable_prims[mm] == lua_type(x) then
		return true
	else
		local mt = getmetatable(x)
		return mt and mt[mm] or false
	end
end

function can_call(x) return applicable(x,'__call') end
function can_index(x) return applicable(x,'__index') end

--respect __type
function type(x)
	local mt = getmetatable(x)
	return mt and (can_call(mt.__type) and mt.__type() or mt.__type) or lua_type(x)
end

--work with any indexable object
function unpack(t,i,j)
	i = i or 1
	j = j or #t
	assert(applicable(t,'__index'), 'unpack(): arg#1 indexable object expected')
end

--respect __next
function next(t)

end

--respect __pairs
function pairs(t)

end

--make a table that respects __len and __gc in its metatable
--caveats: setmetatable() would stil not work on this table, and you can only share the metatable
--with another T table.
function T(t)
	--
end

--work with any callable object
function table.sort(t,f)

end





