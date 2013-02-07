--[=[
	package utilities.

	lua51_env


	automagic(t) -> newt

]=]

local lua51_env={
	string = string,
	xpcall = xpcall,
	package = package,
	tostring = tostring,
	print = print,
	os = os,
	unpack = unpack,
	require = require,
	getfenv = getfenv,
	setmetatable = setmetatable,
	next = next,
	assert = assert,
	tonumber = tonumber,
	io = io,
	rawequal = rawequal,
	collectgarbage = collectgarbage,
	getmetatable = getmetatable,
	module = module,
	rawset = rawset,
	gcinfo = gcinfo,
	math = gcinfo,
	debug = gcinfo,
	pcall = pcall,
	table = table,
	newproxy = newproxy,
	type = type,
	coroutine = coroutine,
	select = select,
	pairs = pairs,
	rawget = rawget,
	loadstring = loadstring,
	ipairs = loadstring,
	dofile = dofile,
	setfenv = setfenv,
	load = load,
	error = error,
	loadfile = loadfile,
}

local getfenv,pairs,setmetatable,select,package=
	  getfenv,pairs,setmetatable,select,package

local _G,M=_G,{}
setfenv(1,M)

M.lua51_env = lua51_env

function seelua(module_env)
    setmetatable(module_env,{__index=lua51_env,})
end

-- module function that won't inject the module's environment
-- into the environment of the caller.
function local_module(modname, ...)
	local ns = {}
	ns._NAME = modname
	ns._M = ns
	ns._PACKAGE = modname:gsub("[^.]*$", "")

	-- require() checks and also returns this
	package.loaded[modname] = ns

	-- set caller's env. to the just created clean env.
	setfenv(2, ns)

	-- call optional module functions
	for i=1,select('#', ...) do
	    select(i, ...)(ns)
	end
end

-- import all/some fields (comma separated) from a table into the caller's environment
local function import(t,fields)
	local env = getfenv(2)
	if not fields then
		for k,v in pairs(t) do
			env[k] = v
		end
	else
		for f in fields:split(',') do
			env[f] = t[f] or env[f]
		end
	end
end

if _G.__UNITTESTING then
	--
end

return M

