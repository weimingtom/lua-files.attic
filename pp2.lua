local pf = require'pformat'
require'glue' --memoize, s % v

local function opt(t) local dt={} for i=1,#t do dt[t[i]]=t[i] end return dt end
local opt_argcheck = {
	--mode
	mode = {opt{'identity', 'copy'}, 'identity'},
	minsize = {'number', 0},
	--exception handling
	maxdepth = {'number', 100},
	cycles = {opt{'skip', 'abort', 'replace'}, 'replace'},
	cycle_value = {'string', '--cycle--'},
	unserializable = {opt{'skip', 'abort', 'replace'}, 'replace'},
	unserializable_value = {'string', '--unserializable--'},
	--string formatting
	quote = {opt{'"', "'"}, "'"},
	split_lines = {'boolean', true},
	--table formatting
	sorted = {'boolean', true},
	space = {'string', '  '},
	tab = {'string', '   '},
	end_comma = {'boolean', false},
	indent = {opt{'inline', 'tree', 'compact'}, 'inline'},
	maxcount = {'number', 2},
	maxline = {'number', 20},
	--hooks
	filter = {'function', pass},
}


local cons_writer = function(name, ...)
	if pf.is_identifier(name) then
		write(name)
	else
		write'_ENV['; wwrapper(name); write']'
	end
	local n = select('#',...)
	local parens = n ~= 1 or (type(...) ~= 'string' and type(...) ~= 'table')
	if parens then write'(' end
	if n > 0 then write_value(...) end
	for i=2,n do
		write','; write_value(select(i,...))
	end
	if parens then write')' end
end


local pformat_recursive --forward decl.

local function pwrite(v, opt, parents, depth, size, write, writeline)
	local comma = ','..opt.space
	local equals = opt.space..'='..opt.space

	local write1 = write
	function write(s)
		size = size + #s
		write1(s)
	end

	local writeline1 = writeline
	function writeline()
		writeline1()
		size = 0
	end

	local indent = size
	local function indentinline(count)
		if opt.indent == 'inline' and (not count or opt.maxcount
												and count % opt.maxcount == 0) then
			writeline(); write((' '):rep(indent))
		end
	end
	local function indenttree()
		if opt.indent == 'tree' then
			writeline(); write(opt.tab:rep(depth))
		end
	end

	local function write_string(s)
		write(opt.quote); write(pf.format_string(s, opt.quote)); write(opt.quote)
	end
	if opt.split_lines then
		local write_str = write_string
		function write_string(s) --override
			local init = 1
			for splitpoint in s:gmatch'[\n\r]+()[^\n\r]' do
				write_str(s:sub(init, splitpoint-1))
				write'..'; indenttree(); indentinline()
				init = splitpoint
			end
			write_str(init > 1 and s:sub(init) or s)
		end
	end

	local write_value --forward decl.

	--[[
	local identities
	if opt.mode == 'identity' then
		local ids = find_identities(v, opt.minsize)
		if next(ids) then
			write'local _'; write(equals); write'{'
			for t, id in pairs(ids) do
				--write_value(
			end
			write'}'
		end
		identities = ids
	end

	local function write_identity(v)
		write'_['; write(tostring(v)); write']'
	end
	]]

	local function write_pair(k, v, first, count)
		--skip identities (will asign them later)
		--handle cycles
		if parents and (parents[k] or parents[v]) then
			if opt.cycles == 'abort' then
				error("cycle detected at level %d (key '%s', value '%s')" %
						{depth, tostring(k), tostring(v)}, depth * 2 + 3)
			elseif opt.cycles == 'skip' then
				return false
			elseif opt.cycles == 'replace' then
				if parents[k] then k = opt.cycle_value end
				if parents[v] then v = opt.cycle_value end
			end
		end
		--write ,v or ,k=v or ,[k]=v
		if not first then write(comma); indentinline(count) end
		indenttree()
		if k ~= nil then --a nil key signals an implicit key
			if pf.is_identifier(k) then
				write(k)
			else
				write'['; write_value(k); write']'
			end
			write(equals)
		end
		write_value(v)
		return true
	end

	local repr --memoized pformat_recursive for comparing tables
	local function write_table(t)
		write'{'; local start_indent = size
		depth = depth + 1
		if opt.maxdepth and depth > opt.maxdepth then
			error('maximum depth %d reached' % opt.maxdepth, depth + 2)
		end
		if parents then parents[t] = true end
		--state
		local first = true --to skip the comma before the first element
		local maxn --to exclude the array part later when iterating with pairs()
		local count = 0 --element count so we know when to insert a new line
		--write the array part first
		for k,v in ipairs(t) do
			maxn = k
			if opt.filter and not opt.filter(k, v, parents) then break end
			indent = start_indent
			if not write_pair(nil, v, first, count) then break end
			count = count + 1
			first = false
		end
		--write the other keys
		if not opt.sorted then
			for k,v in pairs(t) do
				if not (maxn and type(k) == 'number' and k == math.floor(k) and k >= 1 and k <= maxn)
					and (not opt.filter or opt.filter(k, v, parents))
					and write_pair(k, v, first, count)
				then
					count = count + 1
					first = false
				end
			end
		else
			local keylist = {}
			for k,v in pairs(t) do
				if not (maxn and type(k) == 'number' and k == math.floor(k) and k >= 1 and k <= maxn)
					and (not opt.filter or opt.filter(k, v, parents))
				then
					keylist[#keylist+1] = k
				end
			end
			table.sort(keylist, function(a, b)
				if type(a) ~= type(b) then
					return type(a) < type(b) --bool,numbers,strings,tables,threads,userdata
				elseif type(a) == 'boolean' then
					return b --false,true
				elseif type(a) == 'table' then
					repr = repr or memoize(function(v)
						return pformat_recursive(v, opt, parents, depth, size)
					end)
					if repr(a) == repr(b) then --compare by string representations
						return repr(t[a]) < repr(t[b]) --keys equal, compare values
					else
						return repr(a) < repr(b)
					end
				elseif pf.is_identifier(a) ~= pf.is_identifier(b) then
					return pf.is_identifier(a) --identifier,non-identifier
				else
					return a < b --number,string
				end
			end)
			for _,k in ipairs(keylist) do
				indent = start_indent
				if write_pair(k, t[k], first, count) then
					count = count + 1
					first = false
				end
			end
		end
		--close up
		if not first and opt.end_comma then write(comma) end
		if parents then parents[t] = nil end
		depth = depth - 1
		if not first then indenttree() end
		write'}'
	end

	function write_value(v) --forward decl. so no local
		--[[
		if identities and identities[v] then
			write_identity(identities[v])
		else
		]]
		if getmetatable(v) and getmetatable(v).__pp then
			getmetatable(v).__pp(v, write_value)
		elseif v == nil or type(v) == 'boolean' then
			write(tostring(v))
		elseif type(v) == 'number' then
			write(pf.format_number(v))
		elseif type(v) == 'string' then
			write_string(v)
		elseif type(v) == 'table' then
			write_table(v)
		else
			error('unknown type %s' % type(v), depth + 2)
		end
	end

	write_value(v)
end

function pformat_recursive(v, opt, parents, depth, size) --forward decl. as local
	local lines, buf = {}, {}
	local function write(s)
		buf[#buf+1] = s
	end
	local function writeline()
		lines[#lines+1] = concat(buf)
		buf = {}
	end
	pwrite(v, opt, parents, depth, size, write, writeline)
	if #buf then lines[#lines+1] = table.concat(buf) end
	return table.concat(lines, '\n')
end

function pformat(v, opt)
	opt = optionscheck(2, opt, opt_argcheck)
	return pformat_recursive(v, opt, opt.cycles and {}, 0, 0)
end

function pprint(v)
	print(pformat(v))
end

if not ... then require'pp2_test' end

return {
	pwrite = pwrite,
	pformat = pformat,
}
