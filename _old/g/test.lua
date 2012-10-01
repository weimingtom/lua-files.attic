--[=[
	common test functions and operators.

	isint(n), isn(n), ist(t), isf(f), iss(s), snil(v), isntnil(v),
	isempty(s|t), isntempty(s|t), iscallable(v), isnumeric(v),
	isalpha(s), islower(s), isupper(s), isdigit(s), isspace(s),

	between(n,low,high,strict)
	either(a,b)
	both_or_none(a,b)
	coalesce(...)
	case(var[,v1,r1,...,vn,rn][,elsevar])

]=]

local type,select,next,math=
	  type,select,next,math

local _G,M=_G,{}
setfenv(1,M)

function is(f,v) return function(x) return f(x)==v end end
function isnot(f,v) return function(x) return f(x)~=v end end

isn = is(type,'number')
ist = is(type, 'table')
isf = is(type, 'function')
iss = is(type, 'string')

function isnil(v) return v == nil end
function isempty(v) return (type(v)=='string' and v=='') or (type(v)=='table' and next(v)==nil) end
function iscallable(v)
	return type(v)=='function' or (getmetatable(v)~=nil and type(getmetatable(v).__call)=='function')
end

isnumeric = isnot(tonumber, nil)

function is_not_nil(v) return v ~= nil end
function is_not_empty(v) return v ~= '' end

-- numbers
function isint(n) return type(n)=='number' and n%1==0 end
function isnatural(n) return isint(n) and n >= 0 end
function isindex(n) return isint(n) and n >= 1 end
function ispoz(n) return type(n)=='number' and n >= 0 end
function isneg(n) return type(n)=='number' and n < 0 end

-- strings
function isalpha(s) return s:find('%a')~=nil end
function islower(s) return s:find('%l')~=nil end
function isupper(s) return s:find('%u')~=nil end
function isdigit(s) return s:find('%d')~=nil end
function isspace(s) return s:find('%s')~=nil end

--[[
-- name = '[a,b)', a ::= a number, 'inf', '-inf'
function range(spec,a,b)
	spec = spec:trim()
	local lpar, rpar = spec[1], spec[#name]
	assert(lpar=='(' or lpar=='[')
	assert(rpar==')' or rpar==']')
	local lspec, rspec = unpack(spec:sub(2,-2):split(','))
	lspec = case(lspec,'-inf',nil,'a',a,tonumber(lspec))

	if name == '(a,b)' then
		return function(x) return type(x) == 'number' and x > a and x < b end
	elseif name == '(a,b]' then
		return function(x) return type(x) == 'number' and x > a and x <= b end
	elseif name == '[a,b)' then
		return function(x) return type(x) == 'number' and x >= a and x < b end
	elseif name == '[a,b]' then
		return function(x) return type(x) == 'number' and x >= a and x <= b end
	elseif name == '(inf,inf)' then
		return function(x) return type(x) == 'number' end
	elseif name == '[a,inf)' then
		return function(x) return type(x) == 'number' and x >= a end
	elseif name == '(a,inf)' then
		return function(x) return type(x) == 'number' and x > a end
  elseif name == '(-inf,a]' then
    return function(x) return type(x) == 'number' and x <= a end
  elseif name == '(-inf,a)' then
    return function(x) return type(x) == 'number' and x < a end
  elseif name == '[0,inf)' then
    return function(x) return type(x) == 'number' and x >= 0 end
  elseif name == '(0,inf)' then
    return function(x) return type(x) == 'number' and x > 0 end
  elseif name == '(-inf,0]' then
    return function(x) return type(x) == 'number' and x <= 0 end
  elseif name == '(-inf,0)' then
    return function(x) return type(x) == 'number' and x < 0 end
  elseif ex(name:match('^([%[%(])(%d+%.?%d*),(%d+%.?%d*)([%]%)])$')) then
    local left, a, b, right = ex[1], tonumber(ex[2]), tonumber(ex[3]), ex[4]
    if left == '(' and right == ')' then
      return function(x) return type(x) == 'number' and x > a and x < b end
    elseif left == '(' and right == ']' then
      return function(x) return type(x) == 'number' and x > a and x <= b end
    elseif left == '[' and right == ')' then
      return function(x) return type(x) == 'number' and x >= a and x < b end
    elseif left == '[' and right == ']' then
      return function(x) return type(x) == 'number' and x >= a and x <= b end
    else assert(false)
    end
  else
    error('invalid arg ' .. name, 2)
  end
end

function inrange(v,r)

end

-- strict means not touching the boundaries, like in math class
function between(n,low,high,strict)
	strict=strict or false
	if strict then
		return n > low and n < high
	else
		return n >= low and n <= high
	end
end

-- xor sounded so base2
-- instead of true, returns either a or b
function either(a,b)
	if not a ~= not b then
		return a or b
	else
		return false
	end
end

-- you're a literate programmer now
function both_or_none(a,b)
	return not a == not b
end

function coalesce(...)
	local n=select('#',...)
	for i=1,n do
		if select(i,...)~=nil then
			return select(i,...)
		end
	end
	if n>0 then return nil end
end

-- sure, you could say {v1=r1,v2=r2}[var] or elsevar, but this allows for nil values everywhere.
function case(var,...)
	local n=select('#',...)
	for i=1,n,2 do
		if var==select(i,...) then
			return select(i+1,...)
		end
	end
	return n%2==1 and select(n,...) or nil
end

function import(env)
	env=env or _G.getfenv()
end

if _G.__UNITTESTING then
	local assert=_G.assert

	assert(isint(5))
	assert(isn(1.1e1))
	assert(iss(''))
	assert(ist({}))
	assert(isnil(nil))
	assert(isntnil(not nil))
	assert(isempty('')) assert(isempty({}))
	assert(isntempty(' ')) assert(isntempty({false}))

	assert(between(1,1,1))
	assert(between(1,0.999999,1.0000001,true))
	assert(between('n','a','z'))

	assert(either(true,false))
	assert(both_or_none(true,true))
	assert(both_or_none(false,true)==false)
	assert(coalesce(nil,nil,5,6,nil)==5)
	assert(coalesce()==nil)
end
]]

return M


