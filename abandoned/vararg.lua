--[[
	vararg vocabulary, really just select() showoffs.

	first(n,...) -> arg1,...,argn
	last(n,...) -> arg(#-n+1),...,lastarg
	count(...) -> n
	slice(i,j|nil,...) -> argi,...,argj
	insert(arg,n|nil,...)
	append(arg,...)
	remove(n|nil,...)

	pack(...) -> argt
	unpack(argt) -> ...
	packfrom(n,...) -> arg1,...,argn-1,pack(argn,...,lastarg)
	packslice(i,j|nil,...) -> arg1,...,argn-1,pack(argn,...,lastarg)
	insertpack(argt,n|nil,...)
	appendpack(argt,...)
	packequals(argt,...)

	each(...) -> iterator() -> i,arg

	bind(f,n,args) -> g(arg1...argn-1,...) -> f(arg1...argn-1,args,...)
	bind1(f,args) -> g(...) -> f(args,...)
	bind2(f,args) -> g(arg1,...) -> (arg1,args,...)

]]

local select,lua_unpack,lua_max=
	  select,unpack,math.max

local _G,M=_G,{}
setfenv(1,M)

-- not a tail-call ;(
function first(n,...)
	if n>0 then
		return ...,first(n-1,select(2,...))
	end
end

function last(n,...)
	return select(select('#',...)-n+1,...)
end

function count(...)
	return select('#',...)
end

function slice(i,j,...)
	if j==nil then
		return select(i,...)
	end
	if i<=j then
		return select(i,...),first(j-i,select(i+1,...))
	end
end

-- works with n>argnum+1
-- sure, we can use tables, but where is the fun in that?
-- not a tail-call ;(
function insert(v,n,...)
	n=n or select('#',...)+1
	if n==1 then
		return v,...
	else
		return ...,insert(v,n-1,select(2,...))
	end
end

function append(v,...)
	return insert(v,nil,...)
end

-- n=nil pops the last arg.; n>argnum returns all args.
-- not a tail-call ;(
function remove(n,...)
	n=n or select('#',...)
	if n>select('#',...) then return ... end
	if n==1 then
		return select(2,...)
	else
		return ...,remove(n-1,select(2,...))
	end
end

function pack(...)
	return {n=select('#',...),...}
end

-- restores trailing nils if the array was made with pack()
-- NOTE: lua's unpack() is also a plain function not a language construct,
-- so you can't unpack in the middle of an arg. list i.e. 1,2,unpack({3,4}),5==1,2,3,5
function unpack(a,i,j)
	return lua_unpack(a, i or 1, j or a.n)
end

function packfrom(n,...)
	if n==1 then
		return pack(...)
	else
		local rest={n=select('#',...)-n+1,select(n,...)}
		return append(rest,first(n-1,...))
	end
end

function packslice(i,j,...)
	-- TODO: implement this
end

local function next_arg(s,i)
	i=i and i+1 or 1
	if i > s.n then
		return nil
	end
	return i,s[i]
end

-- in a plain 'for' is better to just use select() because this iterator makes garbage.
function each(...)
	return next_arg,pack(...)
end

-- n=nil appends; works with n>argnum+1.
-- O(n*args.n), could be O(n) with a temp. table and no recursion
function insertpack(args,n,...)
	if args.n==0 then return ... end
	n=n or select('#',...)+1
	if n<=0 then n=lua_max(select('#',...)+n+2,1) end

	local function consume(i,...)
		if i==1 then
			return insert(args[i],n,...)
		else
			return consume(i-1,insert(args[i],n,...))
		end
	end
	return consume(args.n,...)
end

function appendpack(argt,...)
	return insertpack(argt,nil,...)
end

function packequals(argt,...)
	if select('#',...) ~= argt.n then return false end
	for i=1,select('#',...) do
		if argt[i]~=select(i,...) then
			return false
		end
	end
	return true
end

-- can bind from the tail given a negative n
-- makes more garbage because vararg can't be an upvalue ;(
function bind(f,n,...)
	local args=pack(...)
	return function(...)
		return f(insertpack(args,n,...))
	end
end

function bind1(f,v) return function(...) return v,... end end
function bind2(f,v) return function(arg1,...) return arg1,v,... end end

if _G.__UNITTESTING then
	local assert=_G.assert

	local a,b,c,d,e=first(2,1,2,3,4); assert(a==1) assert(b==2) assert(c==nil) assert(d==nil) assert(e==nil)
	local a,b,c=last(2,1,2,3,4,5); assert(a==4) assert(b==5) assert(c==nil)
	local a,b,c=slice(3,4,1,2,3,4,5); assert(a==3) assert(b==4) assert(c==nil)
	local a,b,c,d,e=insert('a',3,1,2,3) assert(c=='a') assert(d==3) assert(e==nil)
	local a,b,c,d=insert('a',3,1) assert(a==1) assert(b==nil) assert(c=='a') assert(d==nil)
	local a,b,c=remove(1,1,2,3) assert(a==2) assert(b==3) assert(c==nil)
	local a,b,c=remove(2,1,2,3) assert(a==1) assert(b==3) assert(c==nil)
	local a,b,c=remove(3,1,2,3) assert(a==1) assert(b==2) assert(c==nil)

	local a,b,rest=packfrom(3,'a','b',1,2,3) assert(a=='a') assert(b=='b') assert(#rest==3)
	assert(packequals(pack(1,'a','b',2,3,4,5),insertpack(pack('a','b'),2,1,2,3,4,5)))
	assert(packequals(pack(1,2,3,4,'a','b',5),insertpack(pack('a','b'),-2,1,2,3,4,5)))

	local iter,s=each(nil,1,nil,2,nil,nil)
	local n=0 for i,v in iter,s do n=n+(v or 0)	end assert(n==3)
	local n=0 for i,v in iter,s do n=n+(v or 0) end assert(n==3)

	local f=function(a,b,c) return a,b,c end
	assert(packequals(pack(1,2,3), bind1(f,1)(2,3)))
	assert(packequals(pack(1,2,3), bind2(f,2)(1,3)))
	assert(packequals(pack(1,2,3), bind(f,3,3)(1,2)))
	assert(packequals(pack(1,2,3), bind(f,-1,3)(1,2)))
	assert(packequals(pack(2,3,1), bind(f,-2,2,3)(1)))

end

return M

