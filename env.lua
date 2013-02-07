--[[
	messing with function environments (since we've got them).

	sandbox(f,env) -> f()
	trace(f) -> f() -> env,ret

]]

local getfenv,setfenv,setmetatable=
	  getfenv,setfenv,setmetatable

local finalize = require('error').finalize

local _G,M=_G,{}
setfenv(1,M)

-- returns a wrapper of f() that calls f() in the environment env.
-- TODO: clear the environments of all the call stack for complete sandboxing?
function sandbox(f,env)
	local fenv = getfenv(f)
	local function wrapper(...)
		setfenv(f,env)
		return f(...)
	end
	return finalize(wrapper,function() setfenv(f,fenv) end)
end

-- trace(f) -> g(args) -> ret = f(args) -> env,ret
-- returns a wrapper of f() that calls f() in a new environment that falls back to
-- its initial environment. after f executes, its initial environment is restored.
-- TODO: provide a way to get the env. if f breaks?
function trace(f)
	local fenv = getfenv(f)
	local newfenv = setmetatable({},{__index = function() return fenv end,})
	local function wrapper(...)
		setfenv(f,newfenv)
		return newfenv,f(...)
	end

	return finalize(wrapper,function() setfenv(f,fenv) end)
end

if _G.__UNITTESTING then
	local type,assert=_G.type,_G.assert

	local f=function() assert(sandbox==nil) end
	local g=function() assert(sandbox~=nil) end
	local fenv=getfenv(f)
	sandbox(f,{})()
	sandbox(g,M)()
	assert(getfenv(f)==fenv)

	local f=function() assert(sandbox~=nil) sandbox=1 end
	local e=trace(f)()
	assert(type(sandbox)=='function')
	assert(e.sandbox==1)

end

return M

