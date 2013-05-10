--[[
#summary URI parser and formatter

v1.0 | [http://code.google.com/p/lua-files/source/browse/uri.lua code] | [http://code.google.com/p/lua-files/source/browse/uri_test.lua test]

==`local uri = require'uri'`==

URI parsing and formatting implemented in Lua.

==`uri.format(t) -> s`==

Format a URI from a table containing the fields: `scheme`, `user`, `pass`, `host`, `port`,
`path` or `segments`, `query` or `args`, and `fragment`.

If the field `segments` is present, it will be used instead of `path`. It must be a list of strings representing the
path segments, with the advantage that each segment can contain slashes which will be properly encoded.

If the field `args` is present, it will be used instead of `query`. It must be a table containing string keys pointing
to string values, with the advantage that both the keys and the values can contain the characters `&`, `=`, `?`, `#`
which will be properly encoded.

==`uri.parse(s) -> t`==

Parse a URI of the form `[scheme:](([//[user[:pass]@]host[:port][/path])|path)[?query][#fragment]` into its components.

  * the fields `segments` and `args` are present too, and have the same meaning as for `uri.format` above.
  * `uri.format` can format paths with segments that can contain slashes; these are properly decoded into
  the `segments` list.
  * `uri.format` can format queries with keys and values that can contain reserved characters;
  these are properly decoded into the `args` table.

==`uri.escape(s[,reserved][,unreserved]) -> s`==

Escape all characters except the URI spec `unreserved` and `sub-delims` characters, and the characters in
the unreserved list, plus the characters in the reserved list, if any.

==`uri.unescape(s) -> s`==

Unescape escaped characters in the URI.

]]


--[[
NOTE: luasocket.url is fine, except:
	- doesn't encode/decode query args; that's not standard, ok, but I should be able to do it myself,
		- specifying different escaping characters for key and value, etc. for url.encode().
	- see how browsers send params (;) as query (?) args - that's the way to interpret params.
	- escapes too much - I wanna see cleaner URIs.
	- none of those are show stoppers so I'm not sure if I'll ever fix them.

TODO: absolute path from base path + relative path (RFC 2396)
TODO: absolute uri from base uri + relative path + args override
TODO: add authority and userinfo fields like luasocket.url?
TODO: add params for each path segments? for the whole path? browsers change params to query params.
TODO: expose format_path, format_query, parse_path, parse_query and provide alternative ways of formatting and parsing them:
  - "var[]=v1&var[]=v2&var[k]=v3" => {var={v1,v2,[k]=v3}} - make an array only when you see [], otherwise throw an error.
  - "var=v1&var=v2" => {var={v1,v2}} - make an array when you see duplicate values.
]]

local glue = require'glue'

--formatting

--escape all characters except `unreserved`, `sub-delims` and the characters
--in the unreserved list, plus the characters in the reserved list
local function esc(c)
	return ('%%%02x'):format(c:byte())
end
local function escape(s, reserved, unreserved)
	s = s:gsub('[^A-Za-z0-9%-%._~!%$&\'%(%)%*%+,;=' .. (unreserved or '').. ']', esc)
	if reserved and reserved ~= '' then
		s = s:gsub('[' .. reserved .. ']', esc)
	end
	return s
end

local function format_args(t)
	local dt = {}
	for k,v in glue.sortedpairs(t) do --order is not significant
		k = k:gsub(' ', '+')
		v = v:gsub(' ', '+')
		dt[#dt+1] = escape(k, '&=') .. '=' .. escape(v, '&')
	end
	return table.concat(dt, '&')
end

local function format_segments(t)
	local dt = {}
	for i=1,#t do
		dt[#dt+1] = escape(t[i], '/')
	end
	return table.concat(dt, '/')
end

--args override query; segments override path
local function format(t)
	local scheme = (t.scheme and escape(t.scheme) .. ':' or '')
	local pass = t.pass and ':' .. escape(t.pass) or ''
	local user = t.user and escape(t.user) .. pass .. '@' or ''
	local port = t.port and ':' .. escape(t.port) or ''
	local host = t.host and '//' .. user .. escape(t.host) .. port or ''
	local path = t.segments and format_segments(t.segments) or
						t.path and escape(t.path, '', '/') or ''
	local query = t.args and '?' .. format_args(t.args) or
						t.query and '?' .. escape((t.query:gsub(' ', '+'))) or ''
	local fragment = t.fragment and '#' .. escape(t.fragment) or ''
	return scheme .. host .. path .. query .. fragment
end

--parsing

local function unescape(s)
	return (s:gsub('%%(%x%x)', function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

--[segment[/segment...]]
local function parse_path(s)
	local t = {}
	for s in glue.gsplit(s, '/') do
		t[#t+1] = unescape(s)
	end
	return t
end

--var[=[val]]&|;...
--argument order is not retained neither are the values of duplicate keys
local function parse_query(s)
	local t = {}
	for s in glue.gsplit(s, '[&;]+') do
		local k,v = s:match'^([^=]*)=?(.*)$'
		k = unescape(k:gsub('+', ' '))
		v = unescape(v:gsub('+', ' '))
		if k ~= '' or v ~= '' then
			t[k] = v
		end
	end
	return t
end

--[scheme:](([//[user[:pass]@]host[:port][/path])|path)[?query][#fragment]
local function parse(s, t)
	t = t or {}
	s = s:gsub('#(.*)', function(s) t.fragment = unescape(s) return '' end)
	s = s:gsub('%?(.*)', function(s)
		t.query = unescape(s) --convenience field: unusable if args names/values contain & or =
		t.args = parse_query(s)
		return ''
	end)
	s = s:gsub('^([a-zA-Z%+%-%.]*):', function(s) t.scheme = unescape(s) return '' end)
	s = s:gsub('^//([^/]*)', function(s) t.host = unescape(s) return '' end)
	if t.host then
		t.host = t.host:gsub('^(.-)@', function(s) t.user = unescape(s) return '' end)
		t.host = t.host:gsub(':(.*)', function(s) t.port = unescape(s) return '' end)
		if t.user then
			t.user = t.user:gsub(':(.*)', function(s) t.pass = unescape(s) return '' end)
		end
	end
	if s ~= '' then
		t.segments = parse_path(s)
		t.path = unescape(s) --convenience field: unusable if path segments contain /
	end
	return t
end

--[[TODO:
https://github.com/fire/luasocket/blob/master/src/url.lua
--build a path from a base path and a relative path
local function absolute_path(base_path, relative_path)
    if string.sub(relative_path, 1, 1) == "/" then return relative_path end
    local path = string.gsub(base_path, "[^/]*$", "")
    path = path .. relative_path
    path = string.gsub(path, "([^/]*%./)", function (s)
        if s ~= "./" then return s else return "" end
    end)
    path = string.gsub(path, "/%.$", "/")
    local reduced
    while reduced ~= path do
        reduced = path
        path = string.gsub(reduced, "([^/]*/%.%./)", function (s)
            if s ~= "../../" then return "" else return s end
        end)
    end
    path = string.gsub(reduced, "([^/]*/%.%.)$", function (s)
        if s ~= "../.." then return "" else return s end
    end)
    return path
end

--build an absolute URL from a base and a relative URL according to RFC 2396
local function absolute(base_url, relative_url)
	if type(base_url) == 'table' then
		base_parsed = base_url
		base_url = build(base_parsed)
	else
		base_parsed = parse(base_url)
	end
	local relative_parsed = parse(relative_url)
   if not base_parsed then return relative_url
   elseif not relative_parsed then return base_url
   elseif relative_parsed.scheme then return relative_url
   else
        relative_parsed.scheme = base_parsed.scheme
        if not relative_parsed.authority then
            relative_parsed.authority = base_parsed.authority
            if not relative_parsed.path then
                relative_parsed.path = base_parsed.path
                if not relative_parsed.params then
                    relative_parsed.params = base_parsed.params
                    if not relative_parsed.query then
                        relative_parsed.query = base_parsed.query
                    end
                end
            else
                relative_parsed.path = absolute_path(base_parsed.path or "",
                    relative_parsed.path)
            end
        end
        return build(relative_parsed)
    end
end
]]

if not ... then require 'uri_test' end

return {
	escape = escape,
	format = format,
	unescape = unescape,
	parse = parse,
}
