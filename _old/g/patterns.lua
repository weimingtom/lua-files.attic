--[=[

	ex = storex()
	ex(arg1,...,argn) -> ex[n]==argn

]=]

local _G,M=_G,{}
setfenv(1,M)

-- LIMIT: 1-result func (trivial to enhance)
-- LIMIT: 1-param func (non-trivial)
-- LIMIT: nil result is not memoized (the function might take long to return nil)
-- WARNING: don't mutate arguments between calls
function memoize(f,cache)
	cache=cache or {}
	return function(arg)
		local result=cache[arg]
		if result==nil then
			result=f(arg)
			cache[arg]=result
		end
		return result
	end
end

--stored expressions pattern
--http://lua-users.org/wiki/StatementsInExpressions
do
  local function call(self, ...)
    self.__index = {n = select('#', ...), ...}
    return ...
  end
  function storex()
	local self = {__call = call}
	return setmetatable(self,self)
  end
end

-- automagic tables
-- http://lua-users.org/wiki/AutomagicTables
do
	local auto, assign

	function auto(tab,key)
		return setmetatable({}, {
			__index = auto,
            __newindex = assign,
			parent = tab,
			key = key
		})
	end

	local meta = {__index = auto}

	function assign(tab, key, val)
		if val ~= nil or force then
			local oldmt = getmetatable(tab)
			oldmt.parent[oldmt.key] = tab
			setmetatable(tab, meta)
			tab[key] = val
		end
	end

	function automagic(t, force)
		return setmetatable(t or {}, meta)
	end
end

return M

