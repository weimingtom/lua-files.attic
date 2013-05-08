--svgarc parametrization from cairosvg (I decided on the implementation from AGG)
local arc = require'path_arc'.arc

local function rotate(x, y, angle) --from cairosvg/helpers.py, for elliptical_arc
	return
		x * math.cos(angle) - y * math.sin(angle),
		y * math.cos(angle) + x * math.sin(angle)
end

local function point_angle(cx, cy, px, py) --from cairosvg/helpers.py, for elliptical_arc
    return math.atan2(py - cy, px - cx)
end

--from cairosvg/path.py
function svgarc(write, x1, y1, rx, ry, rotation, large, sweep, x3, y3)
	if x1 == x3 and y1 == y3 then return x1, y1 end
	rx, ry = abs(rx), abs(ry)
	rotation = fmod(rotation, 2 * pi)
	large = large ~= 0 and 1 or 0
	sweep = sweep ~= 0 and 1 or 0
	if rx==0 or ry==0 then
		write('line', x1, y1, x3, y3)
		return
	end
	x3 = x3 - x1
   y3 = y3 - y1
	local radii_ratio = ry/rx
	--cancel the rotation of the second point
	local xe, ye = rotate(x3, y3, -rotation)
	ye = ye / radii_ratio
	-- find the angle between the second point and the x axis
	local angle = point_angle(0, 0, xe, ye)
	-- put the second point onto the x axis
	xe = (xe^2 + ye^2)^.5
	ye = 0
	rx = max(rx, xe / 2) --update the x radius if it is too small
	-- find one circle centre
	local xc = xe / 2
	local yc = (rx^2 - xc^2)^.5
	-- choose between the two circles according to flags
	if large + sweep ~= 1 then yc = -yc end
	-- put the second point and the center back to their positions
	xe, ye = rotate(xe, 0, angle)
	xc, yc = rotate(xc, yc, angle)
	-- find the drawing angles
	local angle1 = point_angle(xc, yc, 0, 0)
	local angle2 = point_angle(xc, yc, xe, ye)

	-- draw the arc
	local mt = affine:new()
	mt:translate(x1, y1)
	mt:rotate(rotation)
	mt:scale(1, radii_ratio)
	local function twrite(cmd, ...)
		if cmd == 'line' or cmd == 'move' then
			write(cmd, mt:transform_point(...))
		elseif cmd == 'curve' then
			local x2,y2 = mt:transform_point(...)
			local x3,y3 = mt:transform_point(select(3,...))
			local x4,y4 = mt:transform_point(select(5,...))
			write(cmd, x2, y2, x3, y3, x4, y4)
		elseif cmd == 'close' then
			write(cmd)
		end
	end
	local start_angle, sweep_angle

	--TODO: this doesn't work right!
	if sweep == 1 then
		start_angle, sweep_angle = angle1, angle2 - angle1
	else
		start_angle, sweep_angle = angle2, angle1 - angle2
	end

	return arc(twrite, xc, yc, rx, rx, start_angle, sweep_angle)
end

