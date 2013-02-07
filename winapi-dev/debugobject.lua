setfenv(1, require'winapi')
require'winapi.object'
require'winapi.vobject'

--object tostring

Object.__tostring_properties = Object.__properties

function string.pad(s,n) return s..(' '):rep(n-#s) end

local function pformat(vt,indent)
	indent = indent or 0
	local kt = sort(keys(vt))
	local t={}
	for i,k in ipairs(kt) do
		local v = vt[k]
		if type(v) == 'table' and k ~= '__meta' and (not getmetatable(v) or not getmetatable(v).__tostring) then
			v = pformat(v, indent + 3)
			v = v ~= '' and '\n'..v or v
			t[#t+1] = '%s%s%s' % {(' '):rep(indent), tostring(k), v}
		else
			v = tostring(v) --TODO: indent multiline string
			t[#t+1] = '%s%s: %s' % {(' '):rep(indent), tostring(k):pad(26-indent), v}
		end
	end
	return concat(t,'\n')
end

function Object:__tostring()
	local t = {}
	for k in self:__tostring_properties() do
		t[tostring(k)] = self[k] --we don't expand keys, we tostring() them
	end
	return pformat(t)
end

Object.__meta.__tostring = Object.__tostring

--vobject tostring

function VObject:__tostring_properties()
	return pairs(update(collect(self:__properties()), collect(self:__vproperties())))
end

