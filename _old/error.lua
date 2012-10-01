--[[
	Error handling patterns

	continue(ok,err) -> either re-raise the error pcall returned or continue
	finalize(f,finf) -> newf()
	protect(f,finf) -> newf()
	try(f,catchf)

]]

local pcall,error=
	  pcall,error

local _G,M=_G,{}
setfenv(1,M)

--usage: try(function() ... end, function(e) ... error(e) end)
function try(f, catch_f)
	local ok,err = pcall(f)
	if not ok then
		catch_f(err)
	end
end

-- eg. continue(after(pcall,finf)(f,args))
function continue(ok,...)
	return not ok and error(...,0) or ...
end

-- note: the finalizer doesn't run protected: if it breaks, the result of f is lost
function finalize(f,finf)
	local function helper(...)
		finf(...)
		return ...
	end
	return function(...)
		return continue(helper(pcall(f,...)))
	end
end

local function protect_helper(finf,ok,...)
	if finf ~= nil then
		finf(ok,...)
	end
	if ok then return ... else return nil,... end
end

-- stops error propagation, returning nil,errmsg instead. also calls a finalizer, if given.
function protect(f,finf)
	return function(...)
		return protect_helper(finf,pcall(f,...))
	end
end

if _G.__UNITTESTING then
	local assert=_G.assert

	ret,err=protect(finalize(function(a,b) error('err') end, function(ok,...) assert(not ok) end))(1,2)
	assert(ret==nil)
	assert(#err>0)

	local finalized
	ret,err=protect(function()
		ok,ret=pcall(function() error('err') end)
		continue(ok,ret)
	end,
	function(ok,...)
		finalized=true
		assert(not ok)
	end
	)()
	assert(finalized)
	assert(ret==nil)
	assert(#err>0)
end

return M


