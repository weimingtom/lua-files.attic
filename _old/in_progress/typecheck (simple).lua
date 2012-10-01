--[[
	Typechecking module. This is generic, so can be used for functions other than fbclient's.
	Idea stolen and adapted from http://lua-users.org/wiki/LuaTypeChecking.

	USAGE:
	Set the global variable __NOTYPECHECK to true before loading any fbclient modules to disable
	typechecking without inducing any runtime overhead on function calls.

]]

local _G = getfenv()

module(...,require'fbclient.init')

function typecheck_wrap(f,tc_funcs,fname)
	return function(...)
		for i,tc_func in ipairs(tc_funcs) do
			local arg = select(i,...)
			local ok,s = tc_func(arg)
			if not ok then
				error(string.format('%s() arg#%d %s expected, got %s',fname or 'lambda',i,s,type(arg)), 2)
			end
		end
		return f(...)
	end
end

local function notypecheck_wrap(f) return f end

types.int(i,1)
types.string(s,2)
types.fbapi(fbapi,3)


function typecheck(...)
	if _G.__NOTYPECHECK then
		return notypecheck_wrap
	else
		local typespec = {...}
		return function(f)
			return typecheck_wrap(f,typespec)
		end
	end
end

local function notypecheck_def_wrap(env,fname) env[fname] = f end

function def(fname,...)
	local env = getfenv(2)
	local f = select(select('#',...),...)
	if _G.__NOTYPECHECK then
		return notypecheck_def_wrap(env,fname)
	else
		env[fname] = function(f)
			return typecheck_wrap(f,typespec,fname)
		end
	end
end

def('f',tc_fbapi,tc_int,tc_string)(
	function(fbapi,i,s)

	end
)

define(tc_fbapi,tc_sv)(
	function(fbapi,sv,bh)

	end
)

