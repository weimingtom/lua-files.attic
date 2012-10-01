--[=[
	basic utilities, so basic they don't deserve their own separate modules, like it or not.

	printf(...)
	eprintf(...)
	ipairs(a,i,j)

	id(...) -> ...
	compose(g,f) -> g(f(...))(...)
	chain(f,g,...,h) -> f();g();...;h()
	after(f,g) -> f(...);g()(...)

]=]

local select,type=
	  select,type

local op=require('test').op

local _G,M=_G,{}
setfenv(1,M)

function printf(...)
	return print(string.format(...))
end

function eprintf(...)
   io.stderr:write(string.format(...))
end

-- extend ipairs for ranged iteration
-- for plain 'for', better use for n=i,j as this iterator makes garbage.
function ipairs(a,i,j)
	local step=i < j and 1 or -1
	local start=i < j and i or j
	return function(_,n)
		n=n and n+step or start
		if n < i or n > j then return nil end
		return n,a[n]
	end
end

function id(...)
	return ...
end

-- compose(g,f) -> g(f)
function compose(g,f)
	return function(...) return g(f(...)) end
end

-- like compose(g,f) but returns what f returns, not what g returns
function after(f,g)
	local function passer(...)
		g(...)
		return ...
	end
	return function(...)
		return passer(f(...))
	end
end

function import()
	--
end

if _G.__UNITTESTING then
	--
end

return M

