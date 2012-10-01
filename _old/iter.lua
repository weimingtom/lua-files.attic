--[[
	Iterator utilities
	unwinding an iterator results in an array of tuples.

	map(f,iter) -> newiter
	filter(f,iter) -> newiter
	go(iter)
	wrap(iter) -> newiter()

]]

local _G,M=_G,{}
setfenv(1,M)

function map(f,iter,...)
	return function(...) return f(iter(...)) end,...
end

local function filter_helper(f,...)
	if f(...) then return ... else return nil end
end

function filter(f,iter,...)
	return function(...) return filter_helper(f,iter(...)) end,...
end

function go(...)
	for _ in ... do end
end

-- returns a self-contained iterator that doesn't need state and var to run.
-- the iterator may not be reusable if the state mutates (most iterators don't suffer from this though).
function wrap(iter,state,var)
	local ivar=var
	local finished=false
	local function setvar(...)
		var=...
		if var==nil then
			finished=true
		end
		return ...
	end
	return function()
		if finished then
			var=ivar -- begin another iteration on the same state
		end
		return setvar(iter(state,var))
	end
end

if _G.__UNITTESTING then
	local assert=_G.assert

end

return M

