--[=[
	Binary, ascii/latin1 and locale-dependent string manipulation

	remember that all programs start in the standard "C" locale regardless
	of the current locale set in the host OS.

	first(s,n)
	last(s,n)

	starts(s,with)
	ends(s,with)
	pos(s,what[,starting])

	split(s,sep[,n]) -> {s1,s2,...,sn}
	slices(s,sep) -> iterator() -> i,slice
	lines(s) -> iter

	join(t,[sep[,i[,j]]])

	trim(s)
	ltrim(s)
	rtrim(s)

	caps(s)
	hex(s)

	TODO: bin2hex, hex2bin

]=]--

local
	type,pairs,ipairs,table,string,math =
	type,pairs,ipairs,table,string,math

local _G,M=_G,{}
setfenv(1,M)

function first(s,n)
	return s:sub(1,n)
end

function last(s,n)
	return s:sub(-n)
end

function starts(s,with)
	return s:sub(1,#with)==with
end

function ends(s,with)
	return s:sub(-#with)==with
end

join = table.concat

-- returns a reusable, stateful iterator
function slices(s,sep)
	sep=sep or ''
	local n,next_pos=0,1
	return function()
		if not next_pos then
			n,next_pos=0,1 --ready for another iteration
			return nil
		end
		n=n+1
		local i,j = next_pos,sep ~= '' and s:find(sep,next_pos,true) or nil
		if j == nil then
			next_pos=nil
			return n,s:sub(i)
		else
			next_pos=j+#sep
			return n,s:sub(i,j-1)
		end
	end
end

function split(s,sep,n)
	if not sep or sep == '' then
		return {s}
	end
	n=n or math.huge
	local t,c,p1,p2 = {},1,1
	while true do
		p2 = s:find(sep,p1,true)
		if p2 and c < n then
			t[#t+1] = s:sub(p1,p2-1)
			p1 = p2+#sep
			c = c+1
		else
			t[#t+1] = s:sub(p1)
			return t
		end
	end
end

-- removes spaces and newlines
-- source: http://lua-users.org/lists/lua-l/2009-12/msg00904.html
-- more: http://lua-users.org/wiki/StringTrim
function trim(s)
  local from = s:find("%S")
  return from and s:match(".*%S", from) or ""
end

-- removes spaces and newlines
function ltrim(s)
	return (s:gsub('^%s*',''))
end

-- removes spaces and newlines
--TODO: do it with gsub!
function rtrim(s)
	local n = #s
	while n > 0 and s:find("^%s", n) do n = n - 1 end
	return s:sub(1,n)
end

-- iterator for each line of s, ignoring empty lines
function lines(s)
	return s:gmatch("[^\r\n]+")
end

function caps(s)
	return (s:gsub("(%w)([%w]*)",function(l,ls) return upper(l)..ls end))
end

-- what can be a table; it will return the first of the "whats" that is found.
function pos(s,what,starting)
	if type(what)=='table' then
		local found=nil
		for k,v in pairs(what) do
			found=s:find(v,starting,true)
			if found then break end
		end
		return found
	else
		return s:find(what,starting,true)
	end
end

--source: http://snippets.luacode.org/?p=snippets/String_to_Hex_String_68
function hex(s,spacer)
	return (s:gsub('(.)',
		function (c)
			return ('%02X%s'):format(c:byte(), spacer or '')
        end))
end

function inject()
	string.first = first
	string.last = last
	string.starts = starts
	string.ends = ends
	string.pos = pos
	string.split = split
	string.slices = slices
	string.lines = lines
	string.trim = trim
	string.ltrim = ltrim
	string.rtrim = rtrim
	string.caps = caps
	string.hex = hex
end

inject()

if _G.__UNITTESTING then
	local function assert_equal(a,b)
		if a ~= b then _G.error(a..'=='..b,2) end
	end
	assert_equal(trim(""), "")
	assert_equal(trim("   "), "")
	assert_equal(trim("12"), "12")
	assert_equal(trim(" 12 "), "12")
	assert_equal(trim("  1 2  "), "1 2")
	assert_equal(trim("\r\n\t\f 1\r\n\t\f\ "), "1")

	assert_equal(ltrim(""), "")
	assert_equal(ltrim("   "), "")
	assert_equal(ltrim("12"), "12")
	assert_equal(ltrim(" 12 "), "12 ")
	assert_equal(ltrim("  1 2  "), "1 2  ")
	assert_equal(ltrim("\r\n\t\f 1\r\n\t\f\ "), "1\r\n\t\f ")

	assert_equal(rtrim(""), "")
	assert_equal(rtrim("   "), "")
	assert_equal(rtrim("12"), "12")
	assert_equal(rtrim(" 12 "), " 12")
	assert_equal(rtrim("  1 2  "), "  1 2")
	assert_equal(rtrim("\r\n\t\f 1\r\n\t\f\ "), "\r\n\t\f\ 1")

	local function acc(...)
		local a={}
		for i,v in ... do
			a[#a+1]=v
		end
		return a
	end
	local s = ',,,,'; assert_equal(s, join(acc(slices(s,',')), ','))
	local s = ',,,,'; assert_equal(s, join(acc(slices(s,',,')), ',,'))
	assert_equal(#acc(slices('abcd')),1)
	assert_equal(#acc(slices('a,b,c,d',',')),4)
	assert_equal(acc(slices(''))[1],'')

	local s = ',,,,'; assert_equal(s, join(split(s,','), ','))
	local s = ',,,,'; assert_equal(s, join(split(s,',,'), ',,'))
	assert_equal(#split('abcd'),1)
	assert_equal(#split('a,b,c,d',','),4)
	assert_equal(split('')[1],'')

	assert_equal(pos('abcd','c',2), 3)
	assert_equal(pos('abcd',{'x','y'}), nil)
	assert_equal(pos('abcdxabcdyz',{'x','y'}), 5)

	assert_equal(hex('\0\255\1\128\127'),'00FF01807F')
end

return M

