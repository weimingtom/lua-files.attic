--svgarc from rsvg (I decided on the implementation from AGG)

local function arc_segment(write, cpx, cpy, xc, yc, th0, th1, rx, ry, x_axis_rotation)
    local f = x_axis_rotation * math.pi / 180
    local sinf = math.sin(f)
    local cosf = math.cos(f)

    local th_half = 0.5 * (th1 - th0)
    local t = (8.0 / 3.0) * sin (th_half * 0.5) * sin (th_half * 0.5) / sin (th_half)
    local x1 = rx*(cos (th0) - t * sin (th0))
    local y1 = ry*(sin (th0) + t * cos (th0))
    local x3 = rx*cos (th1)
    local y3 = ry*sin (th1)
    local x2 = x3 + rx*(t * sin (th1))
    local y2 = y3 + ry*(-t * cos (th1))

	 local x1, y1, x2, y2, x3, y3, x4, y4 =
				cpx, cpy,
				xc + cosf*x1 - sinf*y1,
				yc + sinf*x1 + cosf*y1,
				xc + cosf*x2 - sinf*y2,
				yc + sinf*x2 + cosf*y2,
				xc + cosf*x3 - sinf*y3,
				yc + sinf*x3 + cosf*y3
    write('curve', x1, y1, x2, y2, x3, y3, x4, y4)
	 return x4, y4
end

local DBL_EPSILON = 1e-7

--see http://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes
local function elliptical_arc(x1, y1, rx, ry, x_axis_rotation, large_arc_flag, sweep_flag, x2, y2)
	if x1 == x2 and y1 == y2 then return end

	-- X-axis
	local f = x_axis_rotation * math.pi / 180.0
	local sinf = math.sin(f)
	local cosf = math.cos(f)

	-- Check the radius against floading point underflow.
	--See http://bugs.debian.org/508443
	if math.abs(rx) < DBL_EPSILON or math.abs(ry) < DBL_EPSILON then
		write('line', x, y)
		return
	end

	if rx < 0 then rx = -rx end
	if ry < 0 then ry = -ry end

	local k1 = (x1 - x2)/2
	local k2 = (y1 - y2)/2

	local x1_ = cosf * k1 + sinf * k2
	local y1_ = -sinf * k1 + cosf * k2

	local gamma = (x1_*x1_)/(rx*rx) + (y1_*y1_)/(ry*ry)
	if gamma > 1 then
	  rx = rx * math.sqrt(gamma)
	  ry = ry * math.sqrt(gamma)
	end

	-- Compute the center
	k1 = rx*rx*y1_*y1_ + ry*ry*x1_*x1_
	if k1 == 0 then return end

	k1 = sqrt(fabs((rx*rx*ry*ry)/k1 - 1))
	if sweep_flag == large_arc_flag then
	  k1 = -k1
	end

	local cx_ = k1*rx*y1_/ry
	local cy_ = -k1*ry*x1_/rx

	local cx = cosf*cx_ - sinf*cy_ + (x1+x2)/2
	local cy = sinf*cx_ + cosf*cy_ + (y1+y2)/2

	-- Compute start angle

	k1 = (x1_ - cx_)/rx
	k2 = (y1_ - cy_)/ry
	local k3 = (-x1_ - cx_)/rx
	local k4 = (-y1_ - cy_)/ry

	local k5 = sqrt(fabs(k1*k1 + k2*k2))
	if k5 == 0 then return end

	k5 = k1/k5
	if k5 < -1 then k5 = -1 elseif k5 > 1 then k5 = 1 end
	local theta1 = math.acos(k5)
	if k2 < 0 then theta1 = -theta1 end

	-- Compute delta_theta
	k5 = math.sqrt(math.abs((k1*k1 + k2*k2)*(k3*k3 + k4*k4)))
	if k5 == 0 then return end

	k5 = (k1*k3 + k2*k4)/k5
	if k5 < -1 then k5 = -1 elseif k5 > 1 then k5 = 1 end
	local delta_theta = acos(k5)
	if k1*k4 - k3*k2 < 0 then delta_theta = -delta_theta end

	if sweep_flag and delta_theta < 0 then
	  delta_theta = delta_theta + math.pi*2
	elseif not sweep_flag and delta_theta > 0 then
	  delta_theta = delta_theta - math.pi*2
	end

	-- Now draw the arc
	local n = math.ceil(math.abs(delta_theta / (math.pi * 0.5 + 0.001)))

	local cpx, cpy = x1, y1
	for i=1,n do
	  cpx, cpy = arc_segment(write, cpx, cpy, cx, cy,
									theta1 + (i - 1) * delta_theta / n_segs,
									theta1 + i * delta_theta / n_segs,
									rx, ry, x_axis_rotation)
	end
end

