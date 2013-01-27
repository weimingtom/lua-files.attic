--ffi/proxy: make a ffi lib object return nil on missing symbols instead of breaking.

local function accesssym(lib, symbol) return lib[symbol] end
local function checksym(lib, symbol)
	local ok,v = pcall(accesssym, lib, symbol)
	if ok then return v else return nil,v end
end

local function proxy(lib)
	local t = {}
	return setmetatable(t, {
		__index = function(t,k)
			local v = checksym(lib, k)
			t[k] = v
			return v
		end
	})
end

return {
	proxy = proxy,
	checksym = checksym,
}
