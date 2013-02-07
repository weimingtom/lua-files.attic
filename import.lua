
local function fileexists(path)
	local f = io.open(path, 'r')
	if f then f:close() end
	return f ~= nil
end

local function loadmodule(name)
	local dsep, psep, msub = package.config:match('^(.-)\n(.-)\n(.-)\n')
	for path in package.path:gsub(msub, (name:gsub('%.', dsep))):gmatch('([^'..psep..']+)') do
		if fileexists(path) then
			return assert(loadfile(path))
		end
	end
	error(string.format('module %s not found', name), 2)
end

local import

local function mkmodule(chunk, name, _G)
	name = name or 'main'
	local _M = {} --module's public env.
	local _Pmt = {}
	local _P = setmetatable({}, _Pmt) --module's private env.
	_P.import = import
	_P._P = _P
	_P._M = _M
	_Pmt.__index = _G
	_Pmt.__newindex = function(t,k,v) --write to both private and public env.
		rawset(_P,k,v)
		_M[k] = v
	end
	setfenv(chunk, _P)
	package.loaded[name] = _M
	return _M
end

function import(name, _D, _G)
	_D = _D or getfenv(2) --dest. env.
	_G = _G or getfenv(2)._G
	local _M = package.loaded[name]
	if not _M then
		local chunk = loadmodule(name)
		_M = mkmodule(chunk, name, _G)
		_M = chunk(name) or _M
	end
	for k,v in pairs(_M) do rawset(_D,k,v) end
	return _D
end

local function module(name, _G)
	_G = _G or getfenv(2)._G
	return mkmodule(2, name, _G)
end

if not ... then require'import_test' end

return {
	import = import,
	module = module,
}
