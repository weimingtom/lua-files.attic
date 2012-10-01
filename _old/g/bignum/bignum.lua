--[[
	Bignum library.
	Stolen and adapted from http://lua-users.org/wiki/HammingNumbers.
	Stores numbers as an array of digits of the largest multiple-of-10 base that a Lua number can accomodate.

	setbase(decimal_digits)
	setscale(decimal_digits)

	Bignum(n,[scale]) -> a_Bignum; the fractional part of n is rounded and truncated to scale
	Bignum(s,[scale]) -> a_Bignum; format of s: [<sign>][<int>][.<frac>][e<exp>]; frac is truncated to scale

	xtype(a_Bignum) -> 'Lua bignum'
	tostring(a_Bignum) -> decimal representation

	Supported operations: + - * / % ^ -x == < <=

	NOTES:
	- all operations that work with a Bignum work with a Lua number too.
	- if operands have different scales, the result has the largest scale.

]]

local meta = {__type == 'Lua bignum'}
local digits
local base
local scale_digits
local scale

local function setbase(d)
	digits = d
	base = 10^d
end

local function setscale(d)
	scale_digits = d
	scale = 10^d
end

setbase(15) --default is the max decimal digits the native Lua number can hold
setscale(0) --support only with integers by default

function meta:__add(other)
	do
		local n = tonumber(other)
		if n then other = Bignum(n) end
	end

	local result = {}
	if self.n < other.n then self, other = other, self end
	local n, m = self.n, other.n
	local diff = n - m
	local carry = 0
	local result = {}
	for i = m, 1, -1 do
		local tmp = self[i + diff] + other[i] + carry
		if tmp < base then
			carry = 0
		else
			tmp = tmp - base
			carry = 1
		end
		result[i + diff] = tmp
	end
	for i = diff, 1, -1 do
		local tmp = self[i] + carry
		if tmp < base then
			carry = 0
		else
			tmp = tmp - base
			carry = 1
		end
		result[i] = tmp
	end
	if carry > 0 then
		n = n + 1
		for i = n, 2, -1 do
			result[i] = result[i - 1]
		end
		result[1] = carry
	end
	result.n = n
	return setmetatable(result, meta)
end

function meta:__lt(other)
	do
		local n = tonumber(other)
		if n then other = Bignum(n) end
	end

	if self.n ~= other.n then return self.n < other.n end
	for i = 1, self.n do
		if self[i] ~= other[i] then return self[i] < other[i] end
	end
end

function meta:__eq(other)
	if self.n == other.n then
		for i = 1, self.n do
			if self[i] ~= other[i] then return false end
		end
		return true
	end
end

--TODO: multiply by a Bignum
function meta:__mul(k)
	do
		local n = tonumber(k)
		if n then other = Bignum(n) end
	end

	-- If the base where a multiple of all possible multipliers, then
	-- we could figure out the length of the result directly from the
	-- first "digit". On the other hand, printing the numbers would be
	-- difficult. So we accept the occasional overflow.
	local offset = 0
	if self[1] * k >= base then offset = 1 end
	local carry = 0
	local result = {}
	local n = self.n
	for i = n, 1, -1 do
		local tmp = self[i] * k + carry
		local digit = tmp % base
		carry = (tmp - digit) / base
		result[offset + i] = digit
	end
	if carry ~= 0 then
		n = n + 1
		if offset == 0 then
			for i = n, 2, -1 do
				result[i] = result[i - 1]
			end
		end
		result[1] = carry
	end
	result.n = n
	return setmetatable(result, meta)
end

--TODO: divide by a Bignum
function meta:__div(k)
	do
		local n = tonumber(k)
		if n then other = Bignum(n) end
	end

end

do
	local fmt = '%0'..digits..'.0f'
	function meta:__tostring()
		local t = {}
		t[1] = ('%.0f'):format(self[1])
		for i = 2, self.n do
			t[i] = fmt:format(self[i])
		end
		return table.concat(t)
	end
end

local function Bignum(k, scale_digits)
	scale_digits = scale_digits or 0
	local scale = 10^scale_digits
	if type(k) == 'number' then
		local int, frac = math.modf(k)
		frac = math.floor(frac * scale)
		if frac == 0 then


		return Bignum(int, scale_digits) * scale_digits + frac

		if k < base then
			return setmetatable({k, n = 1}, meta)
		else
			local n,r = math.floor(k/base)
			local r = k % base
			local t = { n = n}
			for i=1, n do
				t[i] =
			end
		end
	elseif type(k) == 'string' then
		local s,n,p,e = k:match('^(%-?)0*(%d*)%.(%d*)e?(%d-)0*$')
		assert(#p <= precision_digits,'number out of precision')
		n = n..p

		local n = math.floor(#k / digits) + 1
		local c = #k % digits
		local t = {}
		for i = #k, 1, -digits do
			t[#t+1] = tonumber(k:sub(math.max(1, i - digits + 1), i))
		end
		return setmetatable(t, meta)
	end
end

return {
	meta = meta,
	setbase = setbase,
	setscale = setscale,
	Bignum = Bignum
}

