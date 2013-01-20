--http protocol: formatting
local glue = require'glue'
local uri = require'uri'
local b64 = require'libb64'

local function request_line(method, uri, version)
	return string.format('%s %s %s\r\n', method:upper(), uri, version)
end

local function response_line(status, message, version)
	return string.format('HTTP/%s %d %s\r\n', version or '1.1', status, message)
end

local function sorted_pairs(t)
	local tk = glue.keys(t)
	table.sort(tk)
	local i = 0
	return function()
		i = i + 1
		return tk[i], t[tk[i]]
	end
end

local ci = string.lower
local base64 = b64.encode_string

local function int(v)
	glue.assert(math.floor(v) == v, 'integer expected')
	return tostring(v)
end

--{v1,v2,...} -> v1,v2,...
local function list(t, format)
	format = format or glue.pass
	local dt = {}
	for i,v in ipairs(t) do
		dt[#dt+1] = format(v)
	end
	return table.concat(dt, ',')
end

local function cilist(s)
	return format_list(s, string.lower)
end

--{k1=v1,...} -> k1=v1,...
local function kv_list(kvt)
	local t = {}
	for k,v in sorted_pairs(kvt) do
		if v then
			t[#t+1] = v == true and k or string.format('%s=%s', k, v)
		end
	end
	return table.concat(t, ',')
end

--{name,k1=v1,...} -> name[; k1=v1 ...]
local function params(known)
	return function(s)
	end
end

--{from=,to=,size=} -> bytes=<from>-<to>
local function request_range(v)
end

--{from=,to=,total=,size=} -> bytes <from>-<to>/<total>
local function response_range(v)
end


local function cookies(cookies)
end

local nofold_headers = { --headers that it isn't safe to send them folded
	set_cookie = true,
	cookie = true,
	www_authenticate = true,
}

local formatters = {
	--general header fields
	cache_control = kv_list, --no_cache
	connection = ci,
	content_length = int,
	content_md5 = base64,
	content_type = params{charset = ci}, --text/html; charset=iso-8859-1
	date = date,
	pragma = nil, --cilist?
	trailer = headernames,
	transfer_encoding = cilist,
	upgrade = nil, --http/2.0, shttp/1.3, irc/6.9, rta/x11
	via = nil, --1.0 fred, 1.1 nowhere.com (apache/1.1)
	warning = nil, --list of '(%d%d%d) (.-) (.-) ?(.*)' --code agent text[ date]
	--standard request headers
	accept = cilist, --paramslist?
	accept_charset = cilist,
	accept_encoding = cilist,
	accept_language = cilist,
	authorization = ci, --basic <password>
	cookie = kv, --TODO: kv';',
	expect = cilist, --100-continue
	from = nil, --user@example.com
	host = nil,
	if_match = nil, --<etag>
	if_modified_since = date,
	if_none_match = nil, --etag
	if_range = nil, --etag
	if_unmodified_since	= date,
	max_forwards = int,
	proxy_authorization = nil, --basic <password>
	range = request_range, --bytes=500_999
	referer = nil, --it's an url but why parse it
	te = cilist, --"trailers, deflate"
	user_agent = nil, --mozilla/5.0 (compatible; msie 9.0; windows nt 6.1; wow64; trident/5.0)
	--non-standard request headers
	x_requested_with = ci,--xmlhttprequest
	dnt = function(v) return v[#v]=='1' end, --means "do not track"
	x_forwarded_for = nil, --client1, proxy1, proxy2
	--standard response headers
	accept_ranges = ci, --"bytes"
	age = int, --seconds
	allow = cilist, --method
	content_disposition = params{filename = nil}, --attachment; ...
	content_encoding = ci,
	content_language = cilist,
	content_location = url,
	content_range = response_range, --bytes 0-500/1250
	etag = nil,
	expires = date,
	last_modified = date,
	link = nil, --?
	location = url,
	p3p = nil,
	proxy_authenticate = ci, --basic
	refresh = params{url = url}, --seconds; ... (not standard but supported)
	retry_after = int, --seconds
	server = nil,
	set_cookie = cookies,
	strict_transport_security = nil, --eg. max_age=16070400; includesubdomains
	vary = headernames,
	www_authenticate = ci,
	--non-standard response headers
	x_Forwarded_proto = ci, --https|http
	x_powered_by = nil, --PHP/5.2.1
}

local function header_name(s)
	return s:gsub('_', '-'):gsub('([a-zA-Z])([a-zA-Z]*)',
		function(c,s) return c:upper() .. s:lower() end)
end

local function headers(headers)
	for k,v in sorted_pairs(headers) do
		local v = formatters[k] and formatters[k](v) or v
		t[#t+1] = string.format('%s: %s', header_name(k), v)
	end
	return table.concat(t, 'r\n') .. '\r\n'
end

local function body_chunk(s)
	return string.format('%x\r\n%s\r\n', #s, s)
end

return {
	reqwest_line = request_line,
	response_line = response_line,
	headers = headers,
	body_chunk = body_chunk,
}

