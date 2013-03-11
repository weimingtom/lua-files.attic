--this snipped used to compute quad bezier length using a closed form solution
--but I use gauss quadrature now.

--total length of quad bezier curve.
--closed-form solution from http://segfaultlabs.com/docs/quadratic-bezier-curve-length.
--TODO: analyze it for out-of-bounds cases: currently it just returns the length of the chord between the endpoints.
local function total_length(x1, y1, x2, y2, x3, y3)
	local ax = x1 - 2*x2 + x3
	local ay = y1 - 2*y2 + y3
	local bx = 2*x2 - 2*x1
	local by = 2*y2 - 2*y1
	local A = 4*(ax*ax + ay*ay)
	local B = 4*(ax*bx + ay*by)
	local C = bx^2 + by^2
	local Sabc = 2*sqrt(A+B+C)
	local A2 = sqrt(A)
	local A32 = 2*A*A2
	local C2 = 2*sqrt(C)
	local BA = B/A2
	local L = (A32*Sabc + A2*B*(Sabc - C2) + (4*C*A - B^2)*log((2*A2 + BA + Sabc) / (BA+C2))) / (4*A32)
	return L ~= L and distance(x1, y1, x3, y3) or L
end

--length of quad bezier curve at parameter t using closed form solution.
local function length(t, x1, y1, x2, y2, x3, y3)
	return total_length(split(t, x1, y1, x2, y2, x3, y3))
end

