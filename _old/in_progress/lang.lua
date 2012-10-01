--[[
	language extensions (we shouldn't do this).
	to be require'd before require'ing any other packages that need the overloaded
	functionality, since they usually make local copies of those functions upon load.

	there's no point in packaging those as they are only effective as
	global overrides (that's why they're called language extensions).

	pairs()		-> allow __pairs metamethod; defines rawpairs()
	ipairs()	-> allow __ipairs metamethod; defines rawipairs()
	type()		-> allow __type metamethod; defines rawtype()

]]

rawpairs, rawipairs, rawtype = pairs, ipairs, type

--metalua/base.lua
function pairs(x,...)
	assert(type(x)=='table', 'pairs() expects a table')
	local mt=getmetatable(x)
	if mt then
		local mtp=mt.__pairs
		if mtp then return mtp(x,...) end
	end
	return rawpairs(x)
end

--metalua/base.lua
function ipairs(x,...)
	assert(type(x)=='table', 'ipairs() expects a table')
	local mt=getmetatable(x)
	if mt then
		local mti=mt.__ipairs
		if mti then return mti(x,...) end
	end
	return rawipairs(x)
end

--metalua/base.lua (was commented)
function type(x)
	local mt = getmetatable(x)
	if mt then
		local mtt = mt.__type
		if mtt then return mtt end
	end
	return rawtype(x)
end

if _G.__UNITTESTING then
	-- TODO
end

