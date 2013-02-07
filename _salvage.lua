function coalesce(...)
	local n=select('#',...)
	for i=1,n do
		if select(i,...)~=nil then
			return select(i,...)
		end
	end
	if n>0 then return nil end
end

function caps(s)
	return (s:gsub("(%a)([%w]*)",function(l,ls) return upper(l)..ls end))
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

function exec(cmd)
	local f,err = io.popen(cmd)
	if not f then return nil,err end
	local s = f:read("*a")
	f:close()
	return s
end

function fit_in_box(w, h, box_w, box_h)
	if w / h > box_w / box_h
		return box_w, box_w * h / w
	else
		return box_h * w / h, box_h
	end
end
