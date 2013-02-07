--[[

iterators:
	lookahead(iter<v1,v2,...>)
		-> iter<v1,nextv1,v2,nextv2,...>    iterator lookahead
	tee([n,]iter) -> iter1,...,itern        multiply an iterator

]]

require'glue'

if not ... then require'unit' end

function lookahead(f, s, v1, v2, v3, v4)
	v1, v2, v3, v4 = f(s, v1, v2, v3, v4)
	return function()
		if v1 == nil then return nil end
		local nv1, nv2, nv3, nv4 = f(s, v1, v2, v3, v4)
		local lv1, lv2, lv3, lv4 = v1, v2, v3, v4
		v1, v2, v3, v4 = nv1, nv2, nv3, nv4
		return lv1, nv1, lv2, nv2, lv3, nv3, lv4, nv4
	end
end

if not ... then
	local f = lookahead(ipairs{'a','b','c'})
	test({f()},{1,2,'a','b'})
	test({f()},{2,3,'b','c'})
	test({f()},{3,nil,'c',nil})

	local f = lookahead(ipairs{'a'})
	test({f()},{1,nil,'a',nil})

	local f = lookahead(ipairs{})
	test({f()},{})
end

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
				buf[bn], v = pack(f(s,v))
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
		argcheck(1,...,'function')
		return _tee(2,...)
	end
end

if not ... then
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
end

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

if not ... then assert(collect(values{1,2,3}),{1,2,3}) end

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


