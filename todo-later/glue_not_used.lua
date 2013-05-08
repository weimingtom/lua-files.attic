require'unit'

local glue = {}

function glue.pluck(t,key)
	local dt={}
	for i=1,#t do dt[#dt+1]=t[i][key] end
	return dt
end

function glue.min(t,cmp)
	local n=t[1]
	if cmp then
		for i=2,#t do if cmp(t[i], n) then n=t[i] end end
	else
		for i=2,#t do if t[i] < n then n=t[i] end end
	end
	return n
end

test(glue.min{5,2,11,3}, 2)

function glue.max(t,cmp)
	local n=t[1]
	if cmp then
		for i=2,#t do if cmp(n, t[i]) then n=t[i] end end
	else
		for i=2,#t do if n < t[i] then n=t[i] end end
	end
	return n
end

test(glue.max{5,2,11,3}, 11)

function glue.sum(t,key)
	local n=0
	if key then
		for i=1,#t do n=n+(t[i][key] or 0) end
	else
		for i=1,#t do n=n+(t[i] or 0) end
	end
	return n
end

test(glue.sum{1,10,100,1000}, 1111)
test(glue.sum({{count=5},{count=8},{count=2}},'count'), 15)

function glue.reverse(t)
	for i=1,#t/2 do
		t[#t-i+1],t[i]=t[i],t[#t-i+1]
	end
	return t
end

test(glue.reverse{1,2,3},{3,2,1})
test(glue.reverse{1,2,3,4},{4,3,2,1})


function glue.coalesce(...)
	local n=select('#',...)
	for i=1,n do
		if select(i,...)~=nil then
			return select(i,...)
		end
	end
	if n>0 then return nil end
end

function glue.caps(s)
	return (s:gsub("(%a)([%w]*)",function(l,ls) return upper(l)..ls end))
end

-- removes duplicates from an already sorted array
function glue.unique(a,eqf)
	local newa={}
	for i,v in ipairs(a) do
		if not eqf and v ~= a[i+1] or eqf and not eqf(v,a[i+1]) then
			newa[#newa+1]=v
		end
	end
	return newa
end

function glue.exec(cmd)
	local f,err = io.popen(cmd)
	if not f then return nil,err end
	local s = f:read("*a")
	f:close()
	return s
end

function glue.fit_in_box(w, h, box_w, box_h)
	if w / h > box_w / box_h then
		return box_w, box_w * h / w
	else
		return box_h * w / h, box_h
	end
end

function glue.lookahead(f, s, v1, v2, v3, v4)
	v1, v2, v3, v4 = f(s, v1, v2, v3, v4)
	return function()
		if v1 == nil then return nil end
		local nv1, nv2, nv3, nv4 = f(s, v1, v2, v3, v4)
		local lv1, lv2, lv3, lv4 = v1, v2, v3, v4
		v1, v2, v3, v4 = nv1, nv2, nv3, nv4
		return lv1, nv1, lv2, nv2, lv3, nv3, lv4, nv4
	end
end

local f = glue.lookahead(ipairs{'a','b','c'})
test({f()},{1,2,'a','b'})
test({f()},{2,3,'b','c'})
test({f()},{3,nil,'c',nil})

local f = glue.lookahead(ipairs{'a'})
test({f()},{1,nil,'a',nil})

local f = glue.lookahead(ipairs{})
test({f()},{})

--[[
#sidebar GlueSidebar
==`lookahead(iterator<v1,v2,...>) -> iterator<v1,nextv1,v2,nextv2>`==

*Wraps an iterator so that each iteration has access to the values of the next iteration.*
  * on the last iteration the values of the next iteration are all nil.
  * in the current implementation, only up to 4 iteration values are captured.

*Examples*

{{{
TODO
}}}

*See also:* [tee].
]]

local function _tee(n,f,s,v)
	if n==1 then return f,s,v end
	local b1,bn=1,0
	local buf={} --{[b1]={v1,v2,...},[b1+1]=...,[bn]=...}
	local nt={} --{n1,n2,...}
	local ft={}
	for i=1,n do
		ft[i] = function()
			if nt[i] > bn then
				bn=bn+1
				buf[bn], v = {f(s,v)}
			end
			local vt = buf[nt[i]]
			local m = nt[1] for j=1,n do if nt[j] < m then m = nt[j] end end
			for j=b1,m-1 do buf[j]=nil end --clear the buffer trail
			b1 = m
			nt[i]=nt[i]+1
			return unpack(vt)
		end
		nt[i]=1
	end
	return unpack(ft)
end
function tee(...)
	if type(...) == 'number' then
		argcheck(2,select(2,...),'function')
		return _tee(...)
	else
		return _tee(2,...)
	end
end

local i1,i2 = tee(pairs{'a','b','c'})
test({i1()},{1,'a'})
test({i1()},{2,'b'})
test({i1()},{3,'c'})
test({i2()},{1,'a'})
test({i2()},{2,'b'})
test({i2()},{3,'c'})

local i1,i2 = tee(2,pairs{'a','b','c'})
test({i1()},{1,'a'})
test({i2()},{1,'a'})
test({i1()},{2,'b'})
test({i2()},{2,'b'})
test({i1()},{3,'c'})
test({i2()},{3,'c'})

--[[
#sidebar GlueSidebar
==`tee([n,]iterator) -> iter1,...,iterN`==

*Return n independent iterators from one iterator.*
  * once the iterator has been split, you can't iterate the original iterator anymore.
  * iterated values are buffered for as much as iterators get out of sync.
  * `n` defaults to 2; passing 1 returns the initial iterator.
  * the name `tee` comes from the unix [http://en.wikipedia.org/wiki/Tee_(command) tee] command.

*Examples*

{{{
TODO
}}}

*See also:* [lookahead].
]]

local sb_meta = {
	add = function(o,s)
		argcheck(2,s,'string')
		o.string = nil
		if s == '' then return end
		o[#o+1] = s
		o.len = o.len + #s
	end,
	get = function(o)
		if o.string then return o.string end
		o.string = concat(o)
		return o.string
	end,
	clear = function(o)
		o.len = 0
		o.string = nil
		for i=#o,1,-1 do o[i] = nil end
	end,
	reset = function(o,s)
		local rs = o:get()
		o:clear()
		if s ~= nil then o:add(s) end
		return rs
	end,
	__call = function(o,s)
		if s ~= nil then
			argcheck(1,s,'string')
			o:add(s)
		else
			return o:get()
		end
	end
}
sb_meta.__index = sb_meta
function stringbuffer()
	return setmetatable({len=0}, sb_meta)
end

if not ... then
buf=stringbuffer(); buf''; buf'abc'; buf'xyz'; buf''
test(buf(),'abcxyz')
test(buf.len,#'abcxyz')
test(#buf,2)
end

--[[
#sidebar GlueSidebar
==`stringbuffer() -> buf`==

*String buffer pattern for efficient string concatenation.*

{{{
buf = stringbuffer()

buf'tachycardia'
buf'toxoplasmosis'
buf'thyrotoxicosis'

print(buf())

> tachycardiatoxoplasmosisthyrotoxicosis

}}}

*`buf(s)`*<br>
*`buf:add(s)`*<br>
Add a string to the buffer. The short form can be used in situations when a consumer function is expected.

*`buf() -> s`*<br>
*`buf:get() -> s`*<br>
Get the contents of the buffer (that is, the concatenation of all the pieces).

*`buf:clear()`*<br>
Clear up the buffer for reuse. Recreating the buffer has the same effect but you might have other references to it that you don't want to reassign.

*`buf:reset([s]) -> s`*<br>
Return the buffer contents and clear the buffer, optionally adding a string to it if provided.

*`buf.len -> n`*<br>
The length of the buffer (the sum of the lengths of the pieces).

*Hint:* The buffer pieces are stored in the array part of the buffer object which you can iterate with `ipairs`, concatenate with `concat` (in case you want to concatenate with a separator), and you can use `#buf` to get the number of pieces.
]]

function writebuffer(write, flushsize)
	local buf = {}
	local size = 0
	return function(s) --writing a nil or false flushes the buffer
		if s then
			buf[#buf+1] = s
			size = size + #s
		end
		if not s or size > flushsize then
			write(concat(buf))
			buf = {}
			size = 0
		end
	end
end

function values(t)
	local i=0
	return function()
		i=i+1
		return t[i]
	end
end

assert(glue.collect(values{1,2,3}),{1,2,3})

local function deepequal(a, b)
	if a == b then return true end
	if type(a) ~= 'table' or type(b) ~= 'table' then return false end
	if getmetatable(a) and getmetatable(b)	and
		getmetatable(a).__eq == getmetatable(b).__eq then return false end
	for k,v in pairs(a) do
		if not deepequal(v, b[k]) then return false end
	end
	for k,v in pairs(b) do
		if not deepequal(v, a[k]) then return false end
	end
	return true
end

if not ... then
local k1={k=5,h=7}
local k2={1,2}
assert(deepequal({[k1]={x=1,y=2},a={1,2},[k2]='a'},
					  {[k1]={x=1,y=2},a={1,2},[k2]='a'}),true)
end


function allpairs(t)
	local inarray = true
	local n = 0
	local k,v
	local function iter()
		if inarray then
			if t[n+1] then
				n = n+1
				return n,t[n],true
			else
				inarray = false
				return iter()
			end
		else
			while true do
				k,v=next(t,k)
				if k == nil then break end
				if not (type(k) == 'number' and k%1 == 0
							and k >= 1 and k <= n) then --skip array indices
					return k,v,false
				end
			end
		end
	end
	return iter
end


