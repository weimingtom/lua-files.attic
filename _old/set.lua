--[=[
	Sets, a trivial implementation using just table keys.
	these sets can hold any value except the nil value.
	elements of a set can be associated with any one single value except the nil value.

	new(...) -> set
	wrap(t) -> set
	collect(a[,i,j]) -> set
	isset(t) -> true if t's metatable has __type == 'set'

	add(set,e[,v = true]) -> set		set[e]=v
	remove(set,e) -> set				set[e]=nil
	member(set,e) -> boolean			set[e]~=nil
	card(set) -> n
	next(set,e) -> next_e,v				next(set,e)
	elements(set) -> next,e -> e,v		pairs(set)
	list(set,comp_func) -> {e1,e2,...}

	union(s,t) -> news					s + t
	intersection(s,t) -> news			s * t
	difference(s,t) -> news				s - t
	symmetric_difference(s,t) -> news	s / t

	subset(s,t) -> boolean				s <= t
	strict_subset(s,t) -> boolean		s < t
	equal(s,t) -> boolean				s == t

]=]

local setmetatable,getmetatable,pairs,ipairs,type,select,next,table=
	  setmetatable,getmetatable,pairs,ipairs,type,select,next,table

local _G=_G
local M={}
setfenv(1,M)

set_meta = {__type = 'set'}

function wrap(t)
	return setmetatable(t,set_meta)
end

function new(...)
	local news=wrap({})
	for i=1,select('#',...) do
		if select(i,...)~=nil then
			add(news,select(i,...))
		end
	end
	return news
end

--if i and j are both nil, a is defined by ipairs(), otherwise it is defined by the i,j bounds.
function collect(a,i,j)
	local news=set()
	if not i and not j then
		for i,v in ipairs(a) do
			add(news,v)
		end
	else
		for k=i,j do
			if a[k] ~= nil then
				add(news,a[k])
			end
		end
	end
	return news
end

function isset(t)
	return getmetatable(t).__type == 'set'
end

function add(s,e,v)
	s[e]=v or true
	return s
end

function remove(s,e)
	s[e]=nil
	return s
end

function member(s,e)
	return s[e]~=nil
end

function card(s)
	local i = 0
	for _ in pairs(s) do
		i=i+1
	end
	return i
end

next = next
elements = pairs

function list(s,compf)
	local t = {}
	for k,v in pairs(s) do
		table.insert(t,k)
	end
	table.sort(t,compf)
	return t
end

function union(s,t)
	local news=new()
	for e,v in elements(s) do
		add(news,e,v)
	end
	for e,v in elements(t) do
		add(news,e,v)
	end
	return news
end

function intersection(s,t)
	local news=new()
	for e,v in elements(s) do
		if member(t,e) then
			add(news,e,v)
		end
	end
	return news
end

function difference(s,t)
	local news=new()
	for e,v in elements(s) do
		if not member(t,e) then
			add(news,e,v)
		end
	end
	return news
end

function symmetric_difference(s,t)
	local news=new()
	for e,v in elements(s) do
		if not member(t,e) then
			add(news,e,v)
		end
	end
	for e,v in elements(t) do
		if not member(s,e) then
			add(news,e,v)
		end
	end
	return news
end

-- s <= t
function subset(s,t)
	for e in elements(s) do
		if not member(t,e) then
			return false
		end
	end
	return true
end

-- s < t
function strict_subset(s,t)
	return card(t) > card(s) and subset(s,t)
end

function equal(s,t)
	return card(s) == card(t) and subset(s,t)
end

set_meta.__add = union
set_meta.__sub = difference
set_meta.__mul = intersection
set_meta.__div = symmetric_difference
set_meta.__le = subset
set_meta.__lt = strict_subset
set_meta.__eq = equal

set_meta.__add = union
set_meta.__sub = difference
set_meta.__mul = intersection
set_meta.__div = symmetric_difference
set_meta.__le = subset
set_meta.__lt = strict_subset
set_meta.__eq = equal

if _G.__UNITTESTING then
	local assert,print=_G.assert,_G.print

	assert(new()==new())
	assert(card(new())==0)
	assert(card(new(1,2,3))==3)
	assert(add(new(),1)==remove(new(1,2),2))
	assert(new(1)~=new(1,2))
	assert(new(1,2,3)+new(2,3,4)==new(1,2,3,4))
	assert(new(1,2,3)-new(2,3,'a')==new(1))
	assert(new(1,2,3,'a','b')*new(2,3,'a','c')==new('a',3,2))
	assert(new(1,2,3,4)/new(1,2,3,5)==new(4,5))
	assert(new(1,2,3)<=new(1,2,3))
	assert(new(1,2)<=new(1,2,3))
	assert(new(1,2)<new(1,2,3))
	local s2=new('a',1,2,3); local s=new(); for e,v in pairs(s2) do add(s,e,v) end; assert(s==new('a',1,2,3))
	assert(wrap{a=1,b=2,'a','b'}==new(1,2,'a','b'))
	assert(new(_G.unpack(list(new(1,2,3,4))))==new(1,2,3,4))
end

return M


