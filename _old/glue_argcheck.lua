local function _argerror(n,level,...)
	local fname = debug and debug.getinfo(level,'n').name or '?'
	n = type(n) == 'number' and string.format('#%d', n) or string.format("'%s'", n)
	error(string.format("bad argument %s to '%s'", n, fname) ..
			(... and string.format(' (%s)', string.format(...)) or ''), level+1)
end

function argerror(n,...)
	_argerror(n, 3, ...)
end

local function _argcheck(n,v,valid,...)
	if type(valid) == 'string' then
		if type(v) == 'nil' and select('#',...) > 0 then
			v = ...
		elseif type(v) ~= valid then
			_argerror(n, 3, '%s expected, got %s', valid, type(v))
		end
	elseif type(valid) == 'function' then
		v = valid(v)
		if v == nil then _argerror(n, 3, ...) end
	elseif type(valid) == 'table' then
		if v == nil and select('#',...) > 0 then
			v = ...
		elseif valid[v] == nil then
			local expected = keys(valid)
			for i=1,#expected do expected[i] = "'%s'" % tostring(expected[i]) end
			sort(expected)
			expected = table.concat(expected, ' or ', 1, math.min(#expected, 3)) ..
									(#expected > 3 and ' or ...' or '')
			local got = (type(v) == 'string' and (#v > 16 and
								string.format("'%s[...]'", v:sub(1, 16))
								or string.format("'%s'", v)))
							or (type(v) == 'number' or type(v) == 'boolean'
								or v == 'nil' and tostring(v))
							or type(v)
			_argerror(n, 3, '%s expected, got %s', expected, got)
		end
		v = valid[v]
	elseif type(valid) == 'boolean' then
		if not valid then
			_argerror(n, 3, ...)
		end
	elseif valid == nil then
		if v == nil then
			_argerror(n, 3, 'value expected, got nil')
		end
	end
	return v
end

function argcheck(n,v,valid,...)
	return _argcheck(n,v,valid,...)
end

function optionscheck(n, t, def)
	_argcheck(n, t, 'table', nil)
	local args = {}
	for k,v in pairs(def) do
		local v = t and t[k]
		args[k] = _argcheck(string.format('#%s.%s', n, k), v, unpack(def[k]))
	end
	return args
end


