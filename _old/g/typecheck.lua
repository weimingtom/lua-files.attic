--[=[
	typechecking of values, with facilities for checking functions' arguments and return values.
	when disabled, function typechecking incurs no runtime overhead on the function.

	value typechecking:
		- type

	function typechecking:
		f = typecheck(func-type-spec)(f)

		- typechecking individual args and/or return values
			- extendable checker table
			- parametrized checkers (use lua functions)
				- numeric intervals (open/closed)
				- string enums
				- string min/max length
			- constants
			- multiple options ('|' operator)
			- fixed argnum (optionally check for numerically too few/too many args)
			- one vararg to be found in any position (head, middle, or tail)
				- min/max number of args
				- fixed type-spec for all args to comply to
			-
		- function overloading: routing based on call signature
		- optional parameters in tail order
			- built-in for non-nil args and when real argnum doesn't matter (arg. adjustment rules)
		- default values
			- built-in for non-nil args (arg = arg or default)
		- optional parameters in specified order with fixed argnum
		- named parameters


	- order of optionals
	- | operator checking all possible signatures
	-

	typecheck(tc.number,tc.string,tc.enum(''),)(f)

	x = typecheck('t|t,[t=d,[t=d]],t->(t,t)|(t,t,t)')(
		function(a,b,c)
			return x
		end
	)

]=]

local type=
	  type

local test=require('test')

local iscallable,isfarg,op=test.iscallable,test.isfarg,test.op

local _G,M=_G,{}
setfenv(1,M)

function farg(f)
	if iscallable(f) then
		return f
	elseif isfarg(f) then
		return op[f]
	end

	if type(f)=='function' then
		return f
	else
		local mt=getmetatable(f)
		if mt ~= nil and mt.__call ~= nil then
			return f
		elseif test.op[f] ~= nil then
			return op[f]
		end
	end
	error('function, callable object, or operator string expected, got '..type(f))
end

function checker(tester, msg, ...)
	return function(v) assert(tester(v), string.format(msg, ...))
end

int = checker(isint, 'integer expected, got %s', type)

local function int(n)
	return test.isint(n) and n or
		error('integer expected, got '..(type(n)=='number' and 'real number '..n or type(n)))
end

local function n(n)
	return test.isn(n) and n or
		error('number expected, got '..type(n))
end

local function gen_check_interval(i,j,parens)
	parens=parens or '[]'
	assert(i<=j, 'invalid interval '..parens[1]..i..','..j..parens[2])
	assert(parens[1]=='[' or parens[1]=='(', 'expected [ or (, got '..parens[1])
	assert(parens[2]==']' or parens[2]==')', 'expected ] or ), got '..parens[2])
	return
		function(p)
			local ok = type(p)=='number' and
						(not i or p>i or (parens[1]=='[' and p>=i)) or
						(not j or p<j or (parens[2]==']' and p<=j))
			return ok, ok or 'number in interval '..parens[1]..i..','..j..parens[2]..' expected, got '..
								(type(p)=='number' and 'number '..p or type(p))
		end
end

local function gen_check_values(...)
	local args=vararg.pack(...)
	return function(p)
		for i,v in array.values(args) do
			if p~=v then
				return false, 'value '..v..' expected, got '..type(p)
			end
		end
		return true
	end
end

typecheck('number, number, interval[0,inf) -> integer')(
	--
)

typecheck(tc.or(tc.number, tc.string), tc.interval(0,nil,'[)'), '->', tc.integer)(
	--
)

M.checkers = {
	anything	= function(p) return true end,
	values		= gen_check_values,
	number		= function(p) return type(p)=='number', 'number expected, got '..type(p) end,
	integer		= check_integer,
	interval	= gen_check_interval,
	string		= function(p) return type(p)=='string', 'string expected, got '..type(p) end,
	table		= function(p) return type(p)=='table', 'table expected, got '..type(p) end,
	boolean		= function(p) return type(p)=='boolean', 'boolean expected, got '..type(p) end,
	thread		= function(p) return type(p)=='thread', 'thread expected, got '..type(p) end,
	userdata	= function(p) return type(p)=='userdata', 'userdata expected, got '..type(p) end,
	['nil']		= function(p) return p==nil, 'nil expected, got '..type(p) end,
}

assert(tc.interval(0,nil)(p))

function M.assert(checker)
	return function
end

local function compile_type_spec(...)

	return arg_types,ret_types
end

local function check_types(types,...)

end

-- features:

local function typecheck(...)
	local arg_types,ret_types=compile_type_spec(...)
	return function(f)
		return function(...)
			return check_types(ret_types,f(check_types(arg_types,...)))
		end
	end
end

local function notypecheck()
	return function(f) return f end
end

function overload({})

if _G.__UNITTESTING then
	--TODO:
end

typecheck = _G.__TYPECHECKING and typecheck or notypecheck

return M

