
local function test(mul, shift, div, max)
	return true
end

local function find(div, max)
	if div == 1 then return 1, 0 end
	for s=0,63 do
		if div == s * 2 then
			return 1, s
		end
	end
	for shift=1,62 do
		for mul = 2,1000 do
			if bit.rshift(x * mul, shift)
			x/3 == x*6/2

		--[[
		if bit.lshift(1, shift) > div then
			local mul = math.floor(bit.lshift(1, shift) / div) + 1
			local found = true
			for i=max,1,-1 do
				print(div, mul, shift, math.floor(i / div), bit.rshift(i * mul, shift))
				if math.floor(i / div) ~= bit.rshift(i * mul, shift) then
					found = false
					break
				end
			end
			if found then return mul, shift end
		end
		]]
	end
end

for i=3,3 do
	local mul, shift = find(i, 1000000)
	print(i, mul, shift, 100 / i, bit.rshift(100 * mul, shift))
end

--[[
local function FindMulShift(max, div)
local mul, shift
	max = Math.Abs(max);
	div = Math.Abs(div);

	bool found = false;
	mul = -1;
	shift = -1;

	// zero divider error
	if (div == 0) return false;

	// this division would always return 0 from 0..max
	if (max < div)
	{
		mul = 0;
		shift = 0;
		return true;
	}

	// catch powers of 2
	for (int s = 0; s <= 63; s++)
	{
		if (div == (1L << s))
		{
			 mul = 1;
			 shift = s;
			 return true;
		}
	}

	// start searching for a valid mul/shift pair
	for (shift = 1; shift <= 62; shift++)
	{
		// shift factor is at least 2log(div), skip others
		if ((1L << shift) <= div) continue;

		// we calculate a candidate for mul
		mul = (1L << shift) / div + 1;

		// assume it is a good one
		found = true;

		// test if it works for the range 0 .. max
		// Note: takes too much time for large values of max.
		if (max < 1000000)
		{
			 for (long i = max; i >=1; i--)       // testing large values first fails faster
			 {
				  if ((i / div) != ((i * mul) >> shift))
				  {
						found = false;
						break;
				  }
			 }
		}
		else
		{
			 // very fast test, no mathematical proof yet but it seems to work well
			 // test highest number-pair for which the division must 'jump' correctly
			 // test max, to be sure;
			 long t = (max/div +1) * div;
			 if ((((t-1) / div) != (((t-1) * mul) >> shift)) ||
				  ((t / div) != ((t * mul) >> shift)) ||
				  ((max / div) != ((max * mul) >> shift))
				 )
			 {
				  found = false;
			 }
		}

		// are we ready?
		if (found)
		{
			 break;
		}
	}
	return found;
end
]]
