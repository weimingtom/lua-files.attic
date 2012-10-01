--pretty printing with identity preserving
require'pp2'

local function count_refs(t, minsize, refcounts, parents)
	refcounts = refcounts or {}
	parents = parents or {}
	if type(t) == 'table' or (type(t) == 'string' and #t >= minsize) then
		refcounts[t] = (refcounts[t] or 0) + 1
		if type(t) == 'table' then
			if parents[t] then return end --prevent cycles
			parents[t] = true
			for k,v in pairs(t) do
				count_refs(k, minsize, refcounts, parents)
				count_refs(v, minsize, refcounts, parents)
			end
			parents[t] = nil
		end
	end
	return refcounts
end

local function find_(t, minsize)
	local refcounts = countrefs(t, minsize)
	local ident_i, ident_t = {}, {}
	local i = 1
	for t,count in pairs(refcounts) do
		if count > 1 then
			ident_i[t] = i
			ident_t[i] = t
			i = i + 1
		end
	end
	write'local _='; write_table(ident_t)
end

local function write_identities(t, minsize)
	local refcounts = countrefs(t, minsize)
	local ident_i, ident_t = {}, {}
	local i = 1
	for t,count in pairs(refcounts) do
		if count > 1 then
			ident_i[t] = i
			ident_t[i] = t
			i = i + 1
		end
	end
	write'local _='; write_table(ident_t)
end

local _={
	{},
	{},
	{}, --root
}
return _[3]

local function pwrite(v)
	if pf.is_serializable(v) then
		pf.pwrite(v, write, quote)
	elseif type(v) == 'table' then
		local identities = find_identities(v)
		for k,i
	end
end

local t={}; t.a=t
pwrite(t)
