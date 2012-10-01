--[[
	math extensions.

	floor(n,p)
	round(n,p)
	interpolate(x,x0,x1,y0,y1)

]]


local _G,M=_G,{}

local lua_floor = math.floor

-- extend floor to take the number of decimal places
function floor(n,p)
  local e = 10^(p or 0)
  return lua_floor(n*e)/e
end

-- round a number to p decimal places
function round(n,p)
  local e = 10^(p or 0)
  return lua_floor(n*e+0.5)/e
end

-- linear interpolation
function interpolate(x,x0,x1,y0,y1)
	return y0 + (x-x0) * ((y1-y0) / (x1 - x0))
end

if _G.__UNITTESTING then
	-- unittesting
end

return M

