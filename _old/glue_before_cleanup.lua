--docs: http://code.google.com/p/lua-library-assessment/wiki/Glue
--[==[
TODO:
	- '%s: {name} $%(price)7.2d' % {'night vision', price=34.52, name='gogles'}
	- trim(pattern not charset) find a fast impl.
	- format('format',a,b,...) instead of %  ??
	- expand('format',t) or % ??

keywords for syntax highlighting:
	concat sort index keys update extend min max sum string.gsplit string.trim string.escape \
	string.starts string.ends collect yield resume cowrap argerror argcheck assert ipcall \
	pass

tables:
	index(t) -> dt                   flip keys with values
	keys(t) -> dt                    list of keys
	update(dt,t1,...) -> dt          merge tables

lists:
	concat(t[,sep]) -> s             table.concat
	extend(dt,t1,...) -> dt          concatenate lists
	pluck(t,key) -> dt               extract values from a list of objects
	sort(t[,cmp]) -> t               table.sort and returns the table
	min(t[,cmp]|a,b...) -> x         smallest element
	max(t[,cmp]|a,b,...) -> x        largest element
	sum(t[,key]) -> x                sum of elements

strings:
	s % value|{values} -> s          string.format sugar
	s:gsplit(pat[,plain])
		-> iter<s[,captures]>         split by a pattern
	s:trim([charset])                remove any paddings
	s:escape([mode]) -> pat          escape magic pattern characters
	s:starts(prefix) -> prefix       check a prefix
	s:ends(suffix) -> suffix         check a suffix

assertions:
	assert(v[,error,...])            assert with formatting the error message
	argerror(i,error,...)                  raise an invalid argument error
	argcheck(i,arg,checker[,error,...])    typecheck an argument

types:
	toint(n) -> n                    integer validation
	toint32(n) -> n                  int32 validation

iterators:
	collect([i,]iter) -> t           collect iterated values into a list
	ipcall(iter) -> iter<ok,...>     iterator pcall
	lookahead(iter) -> iter          iterator lookahead pattern

coroutines:
	yield(...) -> ...                coroutine.yield
	cowrap(f) -> f                   coroutine.wrap

closures:
	pass(...) -> ...                 identity function
	memoize(f) -> g                  single-value memoization

metatables:
	inherit(t,parent1,...) -> t      setup inheritance (single or multiple)
	parents(t) -> parent1,...        inspect direct inheritance

varargs:
	pack(...) -> t                   lua5.2 table.pack

]==]

assert(os.setlocale() == 'C', 'oh my, locale not C')

if not ... then require'unit' end

--leveling off some lua stuff

local _unpack = unpack or table.unpack
unpack = function(t,i,j)
	argcheck(1,t,'table')
	return _unpack(t,i,j or t.n)
end
pack = table.pack or function(...) return {n=select('#',...),...},... end

--assertions

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

function assert(v,err,...)
	if v then return v,err,... end
	err = err ~= nil and argcheck(2,err,'string') or 'assertion failed!'
	if select('#',...) > 0 then err = err:format(...) end
	error(err, 2)
end

if not ... then
test(select(2,pcall(assert,false,'bad %s','dog')), 'bad dog')
test(select(2,pcall(assert,false,'bad dog %s')), 'bad dog %s')
test({pcall(assert,1,2,3)}, {true,1,2,3})
end

--tables

function index(t)
	argcheck(1,t,'table')
	local dt={} for k,v in pairs(t) do dt[v]=k end
	return dt
end

function keys(t)
	argcheck(1,t,'table')
	local dt={} for k in pairs(t) do dt[#dt+1]=k end
	return dt
end

function update(dt,...)
	for i=1,select('#',...) do
		local t=select(i,...)
		if t ~= nil then
			for k,v in pairs(t) do dt[k]=v end
		end
	end
	return dt
end

function merge(dt,...)
	for i=1,select('#',...) do
		local t=select(i,...)
		if t ~= nil then
			for k,v in pairs(t) do
				if dt[k] == nil then dt[k]=v end
			end
		end
	end
	return dt
end

--lists

concat = table.concat

function extend(dt,...)
	argcheck(1,dt,'table')
	for j=1,select('#',...) do
		local t=select(j,...)
		if t ~= nil then
			argcheck(j+1,t,'table')
			for i=1,#t do dt[#dt+1]=t[i] end
		end
	end
	return dt
end

function pluck(t,key)
	argcheck(1,t,'table')
	argcheck(2,key)
	local dt={}
	for i=1,#t do dt[#dt+1]=t[i][key] end
	return dt
end

function sort(t,...)
	local ok,err = pcall(table.sort,t,...)
	if not ok then error(err,2) end
	return t
end

function sum(t,key)
	argcheck(1,t,'table')
	local n=0
	if type(key)=='string' then
		for i=1,#t do n=n+(t[i][key] or 0) end
	elseif key then
		for i=1,#t do n=n+(key(t[i]) or 0) end
	else
		for i=1,#t do n=n+(t[i] or 0) end
	end
	return n
end

function min(t,...)
	if select('#',...) == 0 or type(...) == 'function' then
		argcheck(1,t,'table')
		local n=t[1]
		if ... then
			for i=2,#t do if t[i] ~= nil and (...)(t[i], n) then n=t[i] end end
		else
			for i=2,#t do if t[i] ~= nil and t[i] < n then n=t[i] end end
		end
		return n
	else
		local n=t
		for i=1,select('#',...) do
			if select(i,...) ~= nil and select(i,...) < n then n=select(i,...) end
		end
		return n
	end
end

function max(t,...)
	if select('#',...) == 0 or type(...) == 'function' then
		argcheck(1,t,'table')
		local n=t[1]
		if ... then
			for i=2,#t do if t[i] ~= nil and (...)(n, t[i]) then n=t[i] end end
		else
			for i=2,#t do if t[i] ~= nil and n < t[i] then n=t[i] end end
		end
		return n
	else
		local n=t
		for i=1,select('#',...) do
			if select(i,...) ~= nil and n < select(i,...) then n=select(i,...) end
		end
		return n
	end
end

if not ... then
test(index{a=5,b=7,c=3}, {[5]='a',[7]='b',[3]='c'})
test(sort(keys{apple=15,banana=23}), {'apple','banana'})
test(update({a=1,b=2,c=3}, {d='add',b='overwrite'}, {b='over2'}), {a=1,b='over2',c=3,d='add'})
test(extend({5,6,8}, {1,2}, {'b','x'}), {5,6,8,1,2,'b','x'})
test(min{5,2,11,3}, 2)
test(min(5,2,11,3), 2)
test(min(5,nil,3), 3)
test(max{5,2,11,3}, 11)
test(max(5,2,11,3), 11)
test(max(5,nil,3), 5)
test(sum{1,10,100,1000}, 1111)
test(sum({{count=5},{count=8},{count=2}},'count'), 15)
end

function reverse(t)
	argcheck(1,t,'table')
	for i=1,math.floor(#t/2) do
		t[#t-i+1],t[i]=t[i],t[#t-i+1]
	end
	return t
end

if not ... then
test(reverse{1,2,3},{3,2,1})
test(reverse{1,2,3,4},{4,3,2,1})
end

--strings

local function expand(s,t)
	return (s:gsub('%$([%w_]+)', t))
end

getmetatable('').__mod = function(s,v)
	if type(v) == 'table' then
		return s:format(unpack(v))
	else
		return s:format(v)
	end
end

function string.gsplit(s, sep, start, plain)
	argcheck(1,s,'string')
	argcheck(2,sep,'string')
	start = start ~= nil and argcheck(3,'number',start) or 1
	plain = plain ~= nil and argcheck(4,plain,'boolean') or false
	local done = false
	local function pass(i, j, ...)
		if i then
			local seg = s:sub(start, i - 1)
			start = j + 1
			return seg, ...
		else
			done = true
			return s:sub(start)
		end
	end
	return function()
		if done then return end
		if sep == '' then done = true return s end
		return pass(s:find(sep, start, plain))
	end
end

if not ... then
local function test1(s,sep,expect)
	local t={} for c in s:gsplit(sep) do t[#t+1]=c end
	assert(#t == #expect)
	for i=1,#t do assert(t[i] == expect[i]) end
	test(t, expect)
end
test1('','',{''})
test1('','asdf',{''})
test1('asdf','',{'asdf'})
test1('', ',', {''})
test1(',', ',', {'',''})
test1('a', ',', {'a'})
test1('a,b', ',', {'a','b'})
test1('a,b,', ',', {'a','b',''})
test1(',a,b', ',', {'','a','b'})
test1(',a,b,', ',', {'','a','b',''})
test1(',a,,b,', ',', {'','a','','b',''})
test1('a,,b', ',', {'a','','b'})
test1('asd  ,   fgh  ,;  qwe, rty.   ,jkl', '%s*[,.;]%s*', {'asd','fgh','','qwe','rty','','jkl'})
test1('Spam eggs spam spam and ham', 'spam', {'Spam eggs ',' ',' and ham'})
t = {} for s,n in ('a 12,b 15x,c 20'):gsplit'%s*(%d*),' do t[#t+1]={s,n} end
test(t, {{'a','12'},{'b 15x',''},{'c 20',nil}})
--TODO: use case with () capture
end

function string.trim(s,charset)
	argcheck(1,s,'string')
	charset = charset ~= nil and argcheck(2,charset,'string') or '%s'
	local from = s:match('^['..charset..']*()')
	return from > #s and '' or s:match('.*[^'..charset..']', from)
end

if not ... then test((',  a , x  ,, d ,'):trim'%s,', 'a , x  ,, d') end

local function format_ci_pat(c)
	return string.format('[%s%s]', c:lower(), c:upper())
end
function string.escape(s,mode)
	argcheck(1,s,'string')
	if mode == '*i' then s = s:gsub('[%a]', format_ci_pat) end
	return (s:gsub('%%','%%%%'):gsub('%z','%%z')
				:gsub('([%^%$%(%)%.%[%]%*%+%-%?])', '%%%1'))
end

P = string.escape
PI = function(s) return s:escape'*i' end

if not ... then
test(('^{(.-)}$'):escape(), '%^{%(%.%-%)}%$')
test(('%\0%'):escape(), '%%%z%%')
end

function string.starts(s,prefix)
	argcheck(1,s,'string')
	argcheck(2,prefix,'string')
	return s:find(prefix, 1, true) == 1
end

function string.ends(s,suffix)
	argcheck(1,s,'string')
	argcheck(2,suffix,'string')
	return #suffix==0 or s:find(suffix, 1, true) == #s - #suffix + 1
end

if not ... then
test(('abc'):starts'x',false)
test(('abc'):starts'',true)
test(('abc'):starts'ab',true)
test(('abc'):starts'abc',true)
test(('abc'):starts'abcd',false)
test(('abc'):ends'x',false)
test(('abc'):ends'',true)
test(('abc'):ends'bc',true)
test(('abc'):ends'abc',true)
test(('abc'):ends'abcd',false)
end

--type checking

function callable(f)
	return (type(f) == 'function' or
				(getmetatable(f) and getmetatable(f).__call)) and f or nil
end

function isint(v)
	return type(v) == 'number' and v == math.floor(v)
end

function toint(v,bits) --without bits infinites are included
	argcheck(1,v,'number')
	bits = bits and bits-1
	return v == math.floor(v) and (not bits or
				(v >= -2^bits and v <= 2^bits-1 and v)) and v or nil
end

if not ... then
test(toint(-5),-5)
test(toint(1/0),1/0)
test(toint(-1/0),-1/0)
test(toint(0/0),nil)
test(toint(0/0,32),nil)
test(toint(1/0,32),nil)
test(toint(-1/0,32),nil)
end

--iterators

local function collectn(i,f,s,v)
	local function selectat(i,...)
		return ...,select(i,...)
	end
	local t = {}
	repeat
		v,t[#t+1] = selectat(i,f(s,v))
	until v == nil
	return t
end
local function collect1(f,s,v)
	local t = {}
	repeat
		v = f(s,v)
		t[#t+1] = v
	until v == nil
	return t
end
function collect(...)
	if type(...) == 'number' then
		argcheck(2,select(2,...),'function')
		return collectn(...)
	else
		argcheck(1,...,'function')
		return collect1(...)
	end
end

if not ... then
	test(collect(('abc'):gmatch('.')), {'a','b','c'})
	test(collect(2,ipairs{5,7,2}), {5,7,2})
end

--errors

function ipcall(f,s,v)
	argcheck(1,f,'function')
	local function pass(ok,v1,...)
		v = v1
		return v and ok,v,...
	end
	return function()
		return pass(pcall(f,v))
	end
end

if not ... then
	local i = 0
	local function testiter()
		i = i + 1
		if i % 2 == 0 then error('even',0) end
		if i > 3 then return end
		return i,i^2
	end
	t = {}
	for ok,v1,v2 in ipcall(testiter) do
		t[#t+1] = {ok,v1,v2}
	end
	test(t, {{true,1,1}, {false,'even'}, {true,3,9}, {false,'even'}})
end

--coroutines

yield = coroutine.yield
cowrap = coroutine.wrap

--closures

function pass(...) return ... end

function memoize(f)
	local t = {}
	return function(x)
		if t[x] == nil then t[x] = f(x) end
		return t[x]
	end
end

--compiler

function eval(s,...)
	return assert(loadstring('return '..s))(...)
end

--metatables

function metamethod(t,name)
	local t = getmetatable(t)
	return t and t[name]
end

local function index_parents(t,k)
	local parents = getmetatable(t).__parents
	for i=1,#parents do
		if parents[i][k] ~= nil then
			return parents[i][k]
		end
	end
end

local function setmeta(t,__index,__parents)
	local meta = getmetatable(t)
	if not meta then
		if not __index and not __parents then return end
		meta = {}
		setmetatable(t, meta)
	end
	meta.__index = __index
	meta.__parents = __parents
	return t
end

function inherit(t,...)
	local n=select('#',...)
	if n==0 then argerror(2,'parent expected') end
	if n==1 then return setmeta(t,...,nil) end
	local parents={}
	for i=1,n do
		parents[#parents+1]=select(i,...) --ignore nils
	end
	if #parents < 2 then return setmeta(t,parents[1],nil) end
	setmeta(t,index_parents,parents)
	return t
end

local function parents_recursive(t,...)
	local meta = getmetatable(t)
	if meta then
		if meta.__parents then return unpack(meta.__parents) end
		return meta.__index
	end
end

function parents(t)
	local i, parents
	return function()
		if not i then
			local meta = getmetatable(t)
			if meta then
				parents = meta.__parents
				if parents then
					i = 2
					return parents[1]
				elseif meta.__index then
					t = meta.__index
					return t
				end
			end
		else
			if parents[i] then
				i = i + 1
				return parents[i]
			end
		end
	end
end


--- good junk, see if you can find good use cases:

--http://lua-users.org/lists/lua-l/2011-11/msg01026.html
local function tinsertlist(dt, i, t)
	local oldtlen, delta = #dt, i - 1
	for ti = #dt + 1, #dt + #t do dt[ti] = false end -- preallocate (avoid holes)
	for ti = oldtlen, i, -1 do dt[ti + #t] = dt[ti] end -- shift
	for ti = 1, #t do dt[ti + delta] = t[ti] end -- fill
end

