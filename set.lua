--[=[
	sets, a trivial implementation using just table keys.
	these sets can hold any value except the nil value.
	elements of a set can be associated with any one single value except the nil value.

	set(...) -> s
	wrap(t) -> wrapped t
	collect(a[,i,j]) -> s
	add(e,s,v) -> s						so:add(e,v)				s[e]=v (something diff. than nil)
	remove(e,s) -> s					so:remove(e)			s[e]=nil
	member(e,s) -> boolean				so:has(e)				s[e]~=nil
	card(s) -> n						so:card()				#s
	next(s,e) -> e,v					so:next(e)				next()
	elements(s) -> iter -> e,v			so:elements(s)			pairs(s) or just s

	union(s,t) -> news					s + t
	intersection(s,t) -> news			s * t
	difference(s,t) -> news				s - t
	symmetric_difference(s,t) -> news	s / t

	subset(s,t) -> boolean				s <= t
	strict_subset(s,t) -> boolean		s < t
	equal(s,t) -> boolean				s == t

	unpack(s) -> ...					so:unpack()

	set_class:new(s) -> so

]=]

local setmetatable,getmetatable,pairs,ipairs,type,select,rawset,rawget,lua_next=
	  setmetatable,getmetatable,pairs,ipairs,type,select,rawset,rawget,next

local _G=_G
local M={}
setfenv(1,M)

local setmt={}

function wrap(t)
	return setmetatable(t,setmt)
end

function set(...)
	local news=wrap({})
	for i=1,select('#',...) do
		if select(i,...)~=nil then
			add(select(i,...),news)
		end
	end
	return news
end

--if i and j are both nil, a is defined by ipairs(), otherwise it is defined by the i,j bounds.
function collect(a,i,j)
	local news=set()
	if not i and not j then
		for i,v in ipairs(a) do
			add(v,news)
		end
	else
		for k=i,j do
			if a[k] ~= nil then
				add(a[k],news)
			end
		end
	end
	return news
end

function add(e,s,v)
	s[e]=v or true
	return s
end

function remove(e,s)
	s[e]=nil
	return s
end

function member(e,s)
	return s[e]~=nil
end

function card(s)
	return #s
end

function next(s,k)
	return lua_next(s,k)
end

function elements(s)
	return next,s
end

function union(s,t)
	local news=set()
	for e in elements(s) do
		add(e,news)
	end
	for e in elements(t) do
		add(e,news)
	end
	return news
end

function intersection(s,t)
	local news=set()
	for e in elements(s) do
		if member(e,t) then
			add(e,news)
		end
	end
	return news
end

function difference(s,t)
	local news=set()
	for e in elements(s) do
		if not member(e,t) then
			add(e,news)
		end
	end
	return news
end

function symmetric_difference(s,t)
	local news=set()
	for e in elements(s) do
		if not member(e,t) then
			add(e,news)
		end
	end
	for e in elements(t) do
		if not member(e,s) then
			add(e,news)
		end
	end
	return news
end

-- s <= t
function subset(s,t)
	for e in elements(s) do
		if not member(e,t) then
			return false
		end
	end
	return true
end

-- s < t
function strict_subset(s,t)
	return card(t)>card(s) and subset(s,t)
end

function equal(s,t)
	return card(s)==card(t) and subset(s,t)
end

-- you might argue that it doesn't make sense to unpack a set...
function unpack(s)
	local k
	local function helper(...)
		k=next(s,k)
		if k ~= nil then
			return helper(k,...)
		else
			return ...
		end
	end
	return helper()
end

setmt.__add = union
setmt.__sub = difference
setmt.__mul = intersection
setmt.__div = symmetric_difference
setmt.__le = subset
setmt.__lt = strict_subset
setmt.__eq = equal
setmt.__call = function(s,_,k) return next(s,k) end -- iterate the set object directly

local set_class={
	new = function(o,s)
		newo={ s=s or set() }
		-- copy all metmethods as they are not inherited.
		for k,v in pairs(o) do
			if type(k)=='string' and k:sub(1,2)=='__' then
				newo[k]=o[k]
			end
		end
		newo.__index = o --inherit other fields from o
		return setmetatable(newo,newo)
	end,

	add = function(o,e) add(e,o.s); return o end,
	remove = function(o,e) remove(e,o.s); return o end,
	has = function(o,e) return member(e,o.s) end,
	card = function(o) return card(o.s) end,
	next = function(o,k) return next(o.s,k) end,
	elements = function(o) return elements(o.s) end,

	union = function(o,t) return o:new(union(o.s,t.s)) end,
	intersection = function(o,t) return o:new(intersection(o.s,t.s)) end,
	difference = function(o,t) return o:new(difference(o.s,t.s)) end,
	symmetric_difference = function(o,t) return o:new(symmetric_difference(o.s,t.s)) end,

	subset = function(o,t) return subset(o.s,t.s) end,
	strict_subset = function(o,t) return strict_subset(o.s,t.s) end,
	equal = function(o,t) return equal(o.s,t.s) end,

	unpack = function(o) return unpack(o.s) end,

	__call = function(o,_,k) return o:next(k) end, -- calling it iterates, not constructs
}

set_class.__add = set_class.union
set_class.__sub = set_class.difference
set_class.__mul = set_class.intersection
set_class.__div = set_class.symmetric_difference
set_class.__le = set_class.subset
set_class.__lt = set_class.strict_subset
set_class.__eq = set_class.equal


function import(env)
	env=env or getfenv()
	env.set=set
	env.set_class=set_class
end

if _G.__UNITTESTING then
	local assert,print=_G.assert,_G.print

	assert(set()==set())
	assert(card(set())==0)
	assert(card(set(1,2,3))==3)
	assert(add(1,set())==remove(2,set(1,2)))
	assert(set(1)~=set(1,2))
	assert(set(1,2,3)+set(2,3,4)==set(1,2,3,4))
	assert(set(1,2,3)-set(2,3,'a')==set(1))
	assert(set(1,2,3,'a','b')*set(2,3,'a','c')==set('a',3,2))
	assert(set(1,2,3,4)/set(1,2,3,5)==set(4,5))
	assert(set(1,2,3)<=set(1,2,3))
	assert(set(1,2)<=set(1,2,3))
	assert(set(1,2)<set(1,2,3))
	local s=set() for i in set('a',1,2,3) do add(i,s) end assert(s==set('a',1,2,3))
	assert(wrap{a=1,b=2,'a','b'}==set(1,2,'a','b'))
	assert(set(unpack(set(1,2,3,4)))==set(1,2,3,4))
	--set class tests
	local s1=set_class:new(set(1,2))
	local s2=set_class:new(set('a','b'))
	assert(s1:add(3)==s2:remove('a'):remove('b')+(s1))

end

return M


