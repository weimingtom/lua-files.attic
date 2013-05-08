--[[
	NOTE: I don't use this scheme anymore. Instead I use locals and return a table of them at the end.

	Packaging module.
	Idea stolen and adapted from http://lua-users.org/wiki/ModuleDefinition, take #4.

	lua51_env -> lua 5.1 clean environment table
	new([globals_t = lua51_env]) -> init_f; function to pass to module() as discussed below.
	import(module_table | module_name) -> import a module's members into the caller's environment.

	Calling module(...,init_f) changes environment in which module() is called to an Y-valve kinda table which:
		- reads from table P, which in turn inherits table globals,
		- writes to both P and M,
	where M is the module's public interface table, and P is the module's private environment table.

	With this simple trick we get:
		- table globals gets inherited in the environment of all modules, so just add any hard
		dependencies im this public table.
		- no access to the real global environment, so no worry about module() polluting it (*)
		- any assignment of a global variable goes into module's public interface table.
	(*) A side effect is that require('foo.bar') doesn't get you foo.bar in the environment, which
	is a good thing (it's how module() should behave anyway).

	LIMITATIONS:
	- the module's environment is not directly reflexive anymore (can't use pairs() on it).
	- at 4 tables and a closure per module this is kinda bloated.

]]

local M = {}

M._VERSION = '0.1'

M.lua51_env = {
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

function M.new(globals_t)
	globals_t = globals_t or lua51_env
	local P_meta = {__index = globals_t}
	return function(M)
		local P = setmetatable({},P_meta)
		local M_env = setmetatable({},{__index=P, __newindex=function(t,k,v) M[k]=v; P[k]=v; end})
		setfenv(3, M_env)
		--import any module's public members (_M, _NAME, etc.) into the private namespace
		for k,v in pairs(M) do
			P[k] = v
		end
	end
end

function M.import(M)
	if type(M) == 'string' then
		M = require(M)
	end
	local env = getfenv(2)
	for k,v in pairs(M) do
		env[k]=v
	end
end

return M

