
module(..., package.seeall)

function url_decode(str)
	str = string.gsub(str, "+", " ")
	str = string.gsub(str, "%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
	str = string.gsub(str, "\r\n", "\n")
	return str
end

function url_encode(str)
	if (str)
		str = string.gsub (str, "\n", "\r\n")
		str = string.gsub (str, "([^%w ])", function (c) return string.format ("%%%02X", string.byte(c)) end)
		str = string.gsub (str, " ", "+")
	end
	return str
end

function is_email_address(email)
	return email:match("[A-Za-z0-9%.%%%+%-]+@[A-Za-z0-9%.%%%+%-]+%.%w%w%w?%w?"))
end

local function parse(s)
	return
		scheme,
		host,
		port,
		path,
		query,
		args,
		params
	}
end

local function parse_path(p)

end

local function parse_query(q)

end

local function as_string(url)
	return url.scheme..'://'..url.host..':'..url.port..url.path..'?'..url.query..''
end

	local cache = {}

	local mt
	mt = {
		get_as_string = function(t, cache)
			local s = t.scheme..'://'..t.host..
			cache.as_string = s
			return s
		end
		set_as_string = function(t, v, cache)
			t.
		end
	}

	local t = {}
	setmetatable(t, {
		__index = function(t, k)
			if not cache[k] then
				cache[k] = mtg[k](t, cache)
			end
			return cache[k]
		end,

		__newindex = function(t, k, v)
			cache[k] = nil

			mts[k](t, v, cache)
		end
	})

	return t
end

