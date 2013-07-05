--from https://github.com/numpy/numpy/blob/master/numpy/core/tests/test_half.py (BSD license)
local halffloat = require'halffloat'

--Confirms a small number of known half values
local function test_half_values()
	local floats = {
		1.0, -1.0,
		2.0, -2.0,
		0.0999755859375, 0.333251953125, -- 1/10, 1/3
		65504, -65504,           -- Maximum magnitude
		2^-14, -2^-14, -- Minimum normal
		2^-24, -2^-24, -- Minimum subnormal
		0, -1/1e1000,  -- Signed zeros
		1/0, -1/0,
	}
	local bins = {
		0x3c00, 0xbc00,
		0x4000, 0xc000,
		0x2e66, 0x3555,
		0x7bff, 0xfbff,
		0x0400, 0x8400,
		0x0001, 0x8001,
		0x0000, 0x8000,
		0x7c00, 0xfc00,
	}
	for i=1,#floats do
		local c = halffloat.compress(floats[i])
		assert(bins[i] == c)
	end
end

--Checks that rounding when converting to half is correct
local function test_half_rounding()
	local floats = {2.0^-25 + 2.0^-35,  -- Rounds to minimum subnormal
				 2.0^-25,       -- Underflows to zero (nearest even mode)
				 2.0^-26,       -- Underflows to zero
				 1.0+2.0^-11 + 2.0^-16, -- rounds to 1.0+2^(-10)
				 1.0+2.0^-11,   -- rounds to 1.0 (nearest even mode)
				 1.0+2.0^-12,   -- rounds to 1.0
				 65519,          -- rounds to 65504
				 65520}         -- rounds to inf
	local rounded = {2.0^-24,
                   0.0,
                   0.0,
                   1.0+2.0^(-10),
                   1.0,
                   1.0,
                   65504,
                   1/0}
	for i=1,#floats do
		local c = halffloat.compress(floats[i])
		local c = halffloat.decompress(c)
		print(i, floats[i], rounded[i], c)
		assert(rounded[i] == c)
	end
end

test_half_values()
test_half_rounding()
