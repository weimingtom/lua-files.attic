--[[
	nil filters for use in string expressions mostly.

	reqs(s)			''->nil
	opts(s)			nil->''
	reqt(t)			{}->nil
	optt(t, first_val=nil, first_key=1)		nil->{first_key=first_val}
	reqbe(a,as)		a~=as->nil
	reqnbe(a,as)	a==as->nil

]]

local pkg={}

function pkg.req(x)
	if type(x)=='string' then
		return reqs(x)
	elseif type(x)=='table' then
		return reqt(x)
	elseif type(x)=='number' then
		return reqn(x)
	else
		assert(false, 'unsupported type '..type(x))
	end
end

function pkg.reqs(s)
	if s == '' then return nil else return s end
end

function pkg.opts(s)
	if s == nil then return '' else return s end
end

function pkg.reqt(t)
	if not next(t) then return nil else return t end
end

-- opt(t, first_val = nil, first_key = 1)
function pkg.optt(t, val, key)
	if t == nil then
		if key ~= nil then
			return {[key]=val}
		else
			return {val}
		end
	else
		return t
	end
end

function pkg.reqbe(a,as)
	if a ~= as then
		return nil
	else
		return a
	end
end

function pkg.reqnbe(val, var)
	if val == var then
		return nil
	else
		return val
	end
end

--TODO: null-aware concat
function pkg.concatif(...)

end

// this is useful for expressing optional syntax, like concat_opt(', [', req_s($optional_syntax), ']')
function concat_opt() {
    $args = func_get_args();
    if (!in_array(null, $args, true))
        return implode('', $args);
    else
        return '';
}

