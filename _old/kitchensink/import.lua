local LUAJIT2_ENV = {
	'coroutine', 'assert', 'tostring', 'tonumber', 'io', 'rawget', 'xpcall',
	'ipairs', 'print', 'pcall', 'gcinfo', 'module', 'setfenv', 'rawset',
	'jit',  'bit', 'package', 'error', 'debug', 'loadfile', 'rawequal', 'load',
	'unpack', 'pairs', 'table', 'require', '_VERSION', 'newproxy',
	'collectgarbage', 'dofile', 'next', 'math', 'loadstring', 'os', '_G',
	'select', 'string', 'type', 'getmetatable', 'getfenv', 'setmetatable',
}

local P_meta = {__index = LUAJIT2_ENV}

function import(modules, env)
	local env = env or getfenv(2)

	local function findmodule(name)
		return ('%s.lua'):format(name)
	end

	local function loadonce(name)
		--load the module file
		local chunk = loadfile(findmodule(name))
		--setup module's environment
		local M = {} --module's export table
		local P = {} --module's private/import table
		M._P = P
		M._M = M
		setmetatable(P, {
			__index = LUA_ENV,
			__newindex = function(t,k,v) M[k]=v P[k]=v end,
		})
		setfenv(chunk, P)
		--run module/collect exports/cleanup
		chunk(name)
		setmetatable(P, P_meta) --release the collecting metatable and closure
		return M
	end

	for name in modules:gsplit'[,; ]' do
		--load module
		name = name:trim()
		local M = loadonce(name)
		--import module
		for part in m:gsplit'%.' do
			env[part] = {_PARENT = env}
			env = part
		end
	end
end

if not ... then
	--import'os,re,sys'
	--import'os/*,re,sys'
end
