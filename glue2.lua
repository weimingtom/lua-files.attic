--docs: http://code.google.com/p/lua-library-assessment/wiki/Glue
--[==[
tables:
	add(t[,i],e)						table.insert
	remove(t[,i])						table.remove
	cat(t[,sep]) -> s					table.concat
	sort(t[,cmp]) -> t				table.sort but returns the table
	index(t) -> dt						{v1=k1,v2=k2,...}
	keys(t) -> dt						{k1,k2,...}
	update(dt,...) -> dt				{t1k1=t1v1,t1k2=t1v2...,tnk1=tnv1,...,tnkn=tnvn}
	extend(dt,...) -> dt				{t1[1],t1[2],...,t2[1],t2[2],...,tn[#tn]}

	slice(t[,i[,j[,step]]) -> dt	{v[i],v[i+1*step],v[i+2*step]...,v[j]}
	zip(keys, values) -> t			{keys[1]=values[1],keys[2]=values[2],...}
	min(t|a,b...) -> x				math.min(t[1],t[2],...,t[#t])
	max(t|a,b,...) -> x				math.max(t[1],t[2],...,t[#t])
	sum(t) -> x							t[1]+t[2]+...+t[#t]
	scan(t,e) -> i						first i where t[i] == e
	count(t[,maxcount]) -> n		count elements of t optionally upto maxcount

	filter(f,t) -> newt; f(v) -> rv | nil
	map(f,t); f(k,v) -> rk,rv | nil

table/lesser candidates:
	last(t) -> t[#t]        avoids cacophony of t[#t]
	sortedpairs(t,[cmp]) -> iter(k,v) with sorted keys   --uses table.sort
	sorted(t,[comp]) -> newt                             --useless? maybe just make sort return t and use dt = sort(extend({},t))

string:
	s % t -> s:format(t[1],...); s % v -> s:format(v) --in tight code use (''):format() to avoid table creation
	s:gsplit'pat' -> s[,sep-captures]
	s:split'sep' ->
	s:trim([charset])

	s:asciitrim()
	s:asciilower()
	s:asciiupper()
	u'text |0D|0A text' -> 'text \r\n text' --superseded in lua5.2 by \xhh; note that \ddd escapes work in 5.1

math:
	abs(x) -> y					math.abs
	random(m[,n]) -> x		math.random
	floor(x)	-> y				math.floor
	ceil(x) -> y				math.ceil
	divmod(x,y) -> q,r

coroutines:
	yield(...) -> ...			coroutine.yield
	resume(co,...) -> ...	coroutine.resume
	cowrap(f) -> f				like coroutine.wrap but propagates errors

iterators:
	collect([i,]iter->v1,v2,...) -> {vi,...}

varargs:
	pack(...) -> t with t.n

type checking:
	callable(x) -> b			x is a function or has a __call metamethod
	indexable(x) -> b			x is a table or has a __index metamethod

type conversion:
	str(x) -> s					tostring
	num(v[,base]) -> x		tonumber
	chr(...) -> s				string.byte

sets:
	diff(t1, t2) -> dt
	comm(t1, t2) -> dt

error handling:
	assert(v[,message[,format_args...]])
	ipcall(iter->a,b,...) -> iter->ok,a,b,...

closures:
	identity(...) -> ...
	compose(f,g) -> h; h(...) -> f(g(...))
	bind1(f,v) -> g; g(...) -> f(v,...)
	bind2(f,v) -> g; g(...) -> f(...,v,select(2,...))

compiler:
	eval(s[,env])

process:


	-----------------------------------------------
	not needed				/			how you can do it

	s:char(i)							s:sub(i,i)
	s:head(i)							s:sub(1,i)
	s:tail(i)							s:sub(-i)
	s:chars()							s:gmatch'.'
	s:ichars()							s:gmatch'()(.)'
	s:charlist()						collect(s:gmatch'.')
	s:startswith(prefix)				s:find'^prefix'
	s:startswith(prefix)				s:sub(1, #prefix) == prefix
	s:startswith(prefix)				s:find(prefix,1,true)==1
	s:endswith(suffix)				s:find'suffix$'
	s:endswith(suffix)				s:sub(-#suffix) == suffix
	s:lines()							s:gmatch'([^\n])*\n'
	s:ilines()							s:gmatch'()([^\n])*\n'
	s:lineslist()						collect(s:gmatch'([^\n])*\n')
	last(t)								t[#t]
	add(t,e)								t[#t+1] = e
	pack(...)							{...} or {n=select('#',...),...}

	-----------------------------------------------
	name choice/alternatives

	add			ins push append
	pop			remove del delete
	collect		iunpack
	scan			list.index
	random(t)	list.random
	cat			join concat
	count			size
	index			invert

	-----------------------------------------------
	problem domains

	- structured data processing (scanning, filtering, accumulating)
	- string data processing (matching, parsing, formatting, accumulating)
	- process abstraction (generators and iterators)
	- process abstraction (closure wrappers, state objects)

]==]

--helpers

local function adjust_ij(n,i,j) --adjust i,j per string.sub popular semantics
	i = i or 1
	j = j or -1
	if i <= 0 then i = n + i + 1 end
	if j <= 0 then j = n + j + 1 end
	return i,j
end

--tables

function slice(t,i,j,step)
	i,j = adjust_ij(#t,i,j)
	local dt = {}
	for k=i,j,step or 1 do dt[#dt+1] = t[k] end
	return dt
end

if not ... then
	test(slice({[0]='x','a','b','c','d'},2), {'b','c','d'})
	test(slice({[0]='x','a','b','c','d'},2,2), {'b'})
	test(slice({[0]='x','a','b','c','d'},2,1), {})
	test(slice({[0]='x','a','b','c','d'},-1), {'d'})
	test(slice({[0]='x','a','b','c','d'},-2), {'c','d'})
	test(slice({[0]='x','a','b','c','d'},0), {}) --string.sub would return the whole thing here
end

function filter(f,t)
	local dt = {}
	for i=1,#t do add(dt, f(t[i])) end
	return dt
end

if not ... then test(filter(string.lower, {'A','B','C'}), {'a','b','c'}) end

function map(f,t)
	local dt = {}
	for k,v in pairs(t) do
		k,v = f(k,v)
		if k ~= nil then dt[k]=v end
	end
	return dt
end

if not ... then test(map(function(k,v) return v:upper(), k:lower() end, {A='x',B='y',C='z',['5']='7'}), {X='a',Y='b',Z='c',['7']='5'}) end

local function zip(keys, values)
	local dt = {}
	for i=1,#keys do dt[keys[i]] = values[i] end
	return dt
end

if not ... then test(zip({'a','b'}, {5,7,9}), {a=5,b=7}) end

local function scan(t,v)
	for i=1,#t do
		if t[i] == v then return true end
	end
	return false
end

if not ... then test(scan(5, {5,6,8}), true) test(scan(2, {5,6,8}), false) end

function diff(t, xt)
	local dt = {}
	for k in pairs(t) do
		if xt[k] == nil then
			dt[k] = t[k]
		end
	end
	return dt
end

if not ... then test(diff({a=1,b=2,c=3,1,2,3}, {c=7,1,1}),{a=1,b=2,[3]=3}) end

--type handling

function type(x) return getmetatable(x).__type or type(x) end

--strings

function string.asciitrim(s)
	return s:trim('\r\n\t ')
end

if not ... then test((' \n \r \r\n    trim-it   \t \n'):asciitrim(), 'trim-it') end

local ASCII_LOCALE = os.setlocale(nil) == 'C'

if ASCII_LOCALE then
	string.asciilower = string.lower
else
	local dist = ('A'):byte() - ('a'):byte()
	local function replace(c) return string.char(c:byte() - dist) end
	function string.asciilower(s)
		return (s:gsub('[A-Z]', replace))
	end
end

if not ... then test(('AZXjjCGHm'):asciilower(), 'azxjjcghm') end

if ASCII_LOCALE then
	string.asciiupper = string.upper
else
	local dist = ('a'):byte() - ('A'):byte()
	local function replace(c) return string.char(c:byte() - dist) end
	function string.asciiupper(s)
		return (s:gsub('[a-z]', replace))
	end
end

if not ... then test(('AZXjjCGHm'):asciiupper(), 'AZXJJCGHM') end

--functions

function compose(f1, f2)
	 return function(...) return f1(f2(...)) end
end

function bind(f, e)
	 return function(...) return f(e,...) end
end

function memoize(f) --only one-arg funcs; f(nil) and f(x) -> nil are not memoized
	local t = {}
	return function(x)
		if x ~= nil and t[x] ~= nil then return t[x] end
		return f(x)
	end
end

--varargs

function pack(...)
	return {n=select('#',...),...}
end

--junk

function findany(s,patlist)
	for i=1,#patlist do
		if s:find(patlist[i]) then return i,patlist[i] end
	end
end

function substract(t, keys)
	for i=1,#keys do t[keys[i]] = nil end
	return t
end

function sortedpairs(t,...)
	local tkeys = sort(keys(t))
	local i = 0
	return function()
		i=i+1
		return tkeys[i], t[tkeys[i]]
	end
end

function last(t) return t[#t] end

if not ... then test(last({1,6,2}), 2) end
