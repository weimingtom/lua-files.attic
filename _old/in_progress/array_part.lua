--[[
	array-part functions, i.e. functions that work only with the array part
	of tables that starts at index 1 and ends at the first nil, as defined by ipairs().

	the array length is undefined if there are any other values right of the nil sentinel,
	which makes some operations O(n).

	len(a)
	reverse_ipairs(a)
	collect(a,ipairs)
	seq(i,j)

	map(f,a[,newa])
	copy(a[,newa]) -> newa,count			map(function.id,a[,newa])
	map_over(f,a)
	filter(f,a)
	foldr(f,acc,a)
	reduce(f,a)
	sort_over(a[,cmpf])
	sort(a[,cmpf])
	unique(t[,eqf])

]]

local
	developing,	ipairs, error,	lua_sort,	print	=
	developing,	ipairs, error,	table.sort,	print

local _G,M=_G,{}
setfenv(1,M)

-- warning: O(n)
function len(a)
	-- due to undefined #a for sparse arrays, we have to find the smallest
	-- non-nil index ourseleves by means of table traversal.
	n=0
	while a[n+1] ~= nil do
		n=n+1
	end
	return n
end

--TODO: make this stateless!
-- warning: O(n)
function reverse_ipairs(a)
	return function(_,i)
		i=i and i-1 or len(a)
		if i==0 then return nil end
		return i,a[i]
	end
end

-- filter iterator generator
function filter(f,a)
	local iter,=ipairs(a)
	return function(i) end, 1, true

	local newa={}
	for i,v in ipairs(a) do
		if f(v) then
			newa[#newa+1]=v
		end
	end
	return newa
end

-- breaking the array by returning nil results in error
-- map(f,a,a) maps in place
function map(f,a,newa)
	newa = newa or {}
	local fv
	for i,v in ipairs(a) do
		fv=f(v)
		if fv == nil then
			error('array break')
		end
		newa[i]=fv
	end
	return newa
end

function copy(a)
	local n,newa=0,{}
	for i,v in ipairs(a) do
		newa[i]=v
		n=n+1
	end
	return newa,n
end

-- filter to new array
function filter(f,a)
	local newa={}
	for i,v in ipairs(a) do
		if f(v) then
			newa[#newa+1]=v
		end
	end
	return newa
end

function foldr(f,a,acc)
	for i,v in ipairs(a) do
		acc=f(acc,v)
	end
	return acc
end

function reduce(f,a)
	if a[1] == nil then
		return nil
	end
	local acc,i=a[1],2
	while a[i] ~= nil do
		acc=f(acc,a[i])
		i=i+1
	end
	return acc
end

-- table.sort doesn't return
function sort_over(a,cmpf)
	lua_sort(a,cmpf)
	return a
end

-- like table.sort but returns a new table
function sort(a,cmpf)
	return sort_over(copy(a),cmpf)
end

-- removes duplicates from an already sorted array
function unique(a,eqf)
	newa={}
	for i,v=ipairs(a)
		if not eqf and v ~= a[i+1] or eqf and not eqf(v,a[i+1]) then
			newa[#newa+1]=v
		end
	end
	return newa
end

if _G.__DEVELOPING then
	--for i,v in reverse_ipairs({[-1]=1,'a','b','c', nil, 'd'}) do print(i,v) end

	local t={'c',y='a','b'}
	table.sort(t)
	for i,v in ipairs(t) do print(i,v) end
end

return M

