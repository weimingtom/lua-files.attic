--[=[
	binary, ascii/latin1 and locale-dependent string manipulation.

	remember that all programs start in the standard "C" locale regardless
	of the current locale set in the host OS.

	first(s,n), last(s,n)

	starts(s,with), ends(s,with)
	pos(s,what[,starting])

	split_iter(s,sep) -> iter
	split(s,sep) -> {}
	lines(s) -> iter

	join(t,[sep[,i[,j]]])

	trim(s), ltrim(s), rtrim(s)
	caps(s)

	TODO: bin2hex, hex2bin

]=]--

local
	type,pairs,ipairs,error,lua_concat=
	type,pairs,ipairs,error,table.concat

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

-- returns a reusable, stateful iterator
function split_iter(s,sep)
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

function split(s,sep)
	if sep == '' then return {s} end
	local i,j,t=1,nil,{}
	while true do
		j=s:find(sep,i,true)
		t[#t+1] = s:sub(i,j and j-1)
		if not j then break end
		i=j+#sep
	end
	return t
end

join = lua_concat

-- removes spaces and newlines
function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- removes spaces and newlines
function ltrim(s)
	return (s:gsub("^%s*", ""))
end

-- removes spaces and newlines
--TODO: do it with gsub!
function rtrim(s)
	local n = #s
	while n > 0 and s:find("^%s", n) do n = n - 1 end
	return s:sub(1,n)
end

-- iterator for each line of s, ignoring empty lines (unix and windows compatible)
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

function import()
	local function fname(o)
		for k,v in pairs(M) do
			if v==o then return k end
		end
	end

	for i,v in ipairs({starts,ends,split,trim,ltrim,rtrim,lines,caps,pos}) do
		string[fname(v)]=v
	end
end

if _G.__UNITTESTING then
	local function assert_equal(a,b)
		if a ~= b then error(a..'=='..b,2) end
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

	local function acc(iter) local a={}; for i,v in iter do a[#a+1]=v end return a end
	local s = ',,,,'; assert_equal(s, join(acc(split(s,',')), ','))
	local s = ',,,,'; assert_equal(s, join(acc(split(s,',,')), ',,'))
	assert_equal(#acc(split('abcd')),1)
	assert_equal(#acc(split('a,b,c,d',',')),4)
	assert_equal(acc(split(''))[1],'')

	assert_equal(pos('abcd','c',2), 3)
	assert_equal(pos('abcd',{'x','y'}), nil)
	assert_equal(pos('abcdxabcdyz',{'x','y'}), 5)
end

return M

