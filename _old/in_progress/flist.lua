--[=[
	simple-linked lists implemented with closures.
	lst denotes a cons object. can hold nils just fine.

	cons(car,cdr) -> lst
	car(lst) -> car							lst:car()			or lst.car?
	cdr(lst) -> cdr							lst:cdr()			or lst.cdr?
	set(newlst,lst) -> lst					lst:set(newlst)
	setcar(newcar,lst) -> lst				lst:setcar(newcar)
	setcdr(newcdr,lst) -> lst				lst:setcdr(newcdr)

	list(...) -> cons(arg1, cons(arg2, ... , cons(argn-1, argn) ... ))
	collect(t[,i,j]) -> cons(t[i], cons(t[i+1], ... , cons(t[j-1], t[j]) ... ))
	pairs(lst) -> iter(),lst,nil -> cons	lst:pairs()
	unpack(lst) -> ...						lst:unpack()

	map(f,lst) -> newlst					lst:map(f)
	setf(f,lst) -> lst						lst:setf(f)
	filter(f,lst) -> newlst					lst:filter(f)
	foldr(f,acc,lst) -> n					lst:foldr(f,acc)
	reduce(f,lst) -> n						lst:reduce(f)
	compare(lst1,lst2) -> boolean			lst:compare(lst2)	lst1==lst2? renounce at obj. identity?
	count(lst) -> n							lst:count()

	TODO:
	multimap(f,...) -> lst
	multifilter(f,...) -> lst

]=]

local select=select

local _G,M=_G,{}
setfenv(1,M)

-- TODO: a cdr can only be a cons or nil, but how to enforce that?
-- a table with __call and a signature in its metatable would solve it, plus we could add methods!
function cons(car,cdr)
	return function(m,...)
		if select('#',...)>0 then
			car,cdr=...
		end
		return m and m(car,cdr)
	end
end

local function getcar(car,cdr) return car end
local function getcdr(car,cdr) return cdr end

function car(lst) return lst and lst(getcar) end
function cdr(lst) return lst and lst(getcdr) end

function set(newlst,lst)
	if lst then lst(nil,newlst(getcar),newlst(getcdr)) end
	return lst
end
function setcar(newcar,lst)
	if lst then lst(nil,newcar,lst(getcdr)) end
	return lst
end
function setcdr(newcdr,lst)
	if lst then lst(nil,lst(getcar),newcdr) end
	return lst
end

function list(...)
	if select('#',...)==0 then
		return nil
	else
		return cons(select(1,...),list(select(2,...)))
	end
end

-- TODO: not a call tail!
local function collect_ipairs(t,i,...)
	return t[i] ~= nil and cons(t[i],collect_ipairs(t,i+1)) or nil
end

-- use this instead of list(unpack(t)) which is slower and length-limited.
-- TODO: not a call tail!
function collect(t,...)
	if not i and not j then
		return collect_ipairs(t,1,...)
	else
		return i<=j and cons(t[i],collect(t,i+1,j)) or nil
	end
end

local function pairs_iter(lst,lcons)
	if lcons then return cdr(lcons) else return lst end
end

-- maybe the name sucks, but conses() or each() sucks even more...
function pairs(lst)
	return pairs_iter,lst,nil
end

function unpack(lst)
	if lst ~= nil then
		return car(lst),unpack(cdr(lst))
	end
end

-- TODO: not a call tail!
function map(f,lst)
	if lst==nil then
		return nil
	else
		return cons(f(car(lst)),map(f,cdr(lst)))
	end
end

-- same as iter.go(iter.map(bind(setcar,f),flist.pairs(lst)))
function setf(f,lst)
	if lst==nil then
		return nil
	else
		setcar(f(car(lst)),lst)
		if cdr(lst)==nil then
			return nil
		else
			return setf(f,cdr(lst)) --tail call
		end
	end
end

-- TODO: not a call tail!
function filter(f,lst)
	if lst==nil then
		return nil
	elseif f(car(lst)) then
		return cons(car(lst), filter(f, cdr(lst)))
	end
end

function foldr(f,acc,lst)
	if lst==nil then
		return acc
	else
		return foldr(f,f(acc,car(lst)),cdr(lst))
	end
end

function reduce(f,lst)
	return foldr(f,car(lst),cdr(lst))
end

function compare(lst1,lst2)
	if (lst1==nil and lst2==nil) or car(lst1)==car(lst2) then
		return true
	else
		return compare(cdr(lst1),cdr(lst2))
	end
end

function count(lst)
	local n,c=0,lst
	while c ~= nil do
		n=n+1
		c=cdr(c)
	end
	return n
end

flist_class={
	new(o,lst) = function
		newo={lst=lst, __index=o}
		-- TODO
		return setmetatable(newo,newo)
	end,
	-- TODO: all the methods...
}

if _G.__UNITTESTING then
	local assert=_G.assert

	function assert123(lst)
		assert(car(lst)==1)
		assert(car(cdr(lst))==2)
		assert(car(cdr(cdr(lst)))==3)
		assert(car(cdr(cdr(cdr(lst))))==nil)
	end
	local lst=list(1,2,3)
	assert123(lst)

	lst=cons(1,cons(2,cons(3)))
	assert123(lst)

	lst=cons(1,list(2,3))
	assert123(lst)

	lst=list()
	assert(car(lst)==nil)
	assert(cdr(lst)==nil)

	lst=list(1)
	assert(car(lst)==1)
	assert(cdr(lst)==nil)

	assert(compare(list(1,2,3),collect{1,2,3}))
	assert(compare(list(nil,nil,nil),collect({},-5,-3)))

	assert(compare(map(function(x) return x^2 end,list(1,2,3,4)), list(1,4,9,16)))
	assert(count(list(1,2,3))==3)
	assert(count(list())==0)

end

return M

