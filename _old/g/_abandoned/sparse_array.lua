--[[
	sparse array functions, i.e. functions that consider an array to be any known range
	of integer keys in a table, which allows for "storing" nil values in arrays.

	ranges(t)

]]

local select=select

local _G,M=_G,{}
setfenv(1,M)

-- discover and return (in a table, not array!) all ranges of integer keys in table t
function ranges(t)
	local ranges={}
	-- test if n is in range, expand all ranges that have n just 1 element outside them,
	-- and merge the eventual two ranges which n just made overlap.
	-- this algo makes most garbage when the iterated keys are most scrambled.
	local function in_range(n)
		local found,ori,i,j=false
		for ri,r in pairs(ranges) do
			i,j=r[1],r[2]
			if n >= i-1 and n <= j+1 then --n is in range or just 1 element outside
				found = true
				if n < i then -- n is just 1 element left-outside of range
					if ori then -- n already expanded another range (to the right, the only possibilty)
						r[1] = ranges[ori][1] -- swallow the other range
						ranges[ori] = nil -- and kill it
						break -- only one welding is logically possible
					else
						r[1]=n -- expand this range to the left
						ori=ri -- signal the expansion
					end
				elseif n > j then -- ...same with the other side
					if ori then
						r[2] = ranges[ori][2]
						ranges[ori] = nil
						break
					else
						r[2]=n
						ori=ri
					end
				end
			end
		end
		return found
	end

	for k in pairs(t) do
		if type(k)=='number' and k%1==0 then
			if not in_range(k) then
				ranges[#ranges+1]={k,k}
			end
		end
	end
	return ranges
end

if _G.__DEVELOPING then
	--
end

return M

