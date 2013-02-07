--this is the cairo-driven path generation code, that was written
--before the current pure-Lua path simplification code. abandoned feb 07, 2013.

function draw_round_rect(cr, x1, y1, w, h, r)
	local x2, y2 = x1+w, y1+h
	cr:new_sub_path()
	cr:arc(x1+r, y1+r, r, -math.pi, -math.pi/2)
	cr:arc(x2-r, y1+r, r, -math.pi/2, 0)
	cr:arc(x2-r, y2-r, r, 0, math.pi/2)
	cr:arc(x1+r, y2-r, r, math.pi/2, math.pi)
	cr:close_path()
end

local function rotate(x, y, angle) --from cairosvg/helpers.py, for elliptical_arc
	return
		x * math.cos(angle) - y * math.sin(angle),
		y * math.cos(angle) + x * math.sin(angle)
end

local function point_angle(cx, cy, px, py) --from cairosvg/helpers.py, for elliptical_arc
    return math.atan2(py - cy, px - cx)
end

function draw_elliptical_arc(cr, x1, y1, rx, ry, rotation, large, sweep, x3, y3) --from cairosvg/path.py
	if x1 == x3 and y1 == y3 then return end
	rx, ry, rotation, large, sweep = math.abs(rx), math.abs(ry), math.fmod(rotation, 2*math.pi),
												large ~= 0 and 1 or 0,
												sweep ~= 0 and 1 or 0
	if rx==0 or ry==0 then
		cr:line_to(x3, y3)
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
	rx = math.max(rx, xe / 2) --update the x radius if it is too small
	-- find one circle centre
	local xc = xe / 2
	local yc = (rx^2 - xc^2)^.5
	-- choose between the two circles according to flags
	if large + sweep ~= 1 then yc = -yc end
	-- define the arc sweep
	local arc = sweep == 1 and cr.arc or cr.arc_negative
	-- put the second point and the center back to their positions
	xe, ye = rotate(xe, 0, angle)
	xc, yc = rotate(xc, yc, angle)
	-- find the drawing angles
	local angle1 = point_angle(xc, yc, 0, 0)
	local angle2 = point_angle(xc, yc, xe, ye)
	-- draw the arc
	local mt = cr:get_matrix()
	cr:translate(x1, y1)
	cr:rotate(rotation)
	cr:scale(1, radii_ratio)
	arc(cr, xc, yc, rx, angle1, angle2)
	cr:set_matrix(mt)
end

local function opposite_point(x, y, cx, cy)
	return 2*cx-(x or cx), 2*cy-(y or cy)
end

function SG:draw_path(path)
	local cr = self.cr
	cr:new_path() --no current point after this
	assert(type(path[1]) == 'string' , 'path must start with a command')
	local i = 1
	local s
	local function get(n)
		i = i + n
		return unpack(path, i-n, i-1)
	end
	local bx, by --last cubic bezier control point
	local qx, qy --last quad bezier control point
	while i <= #path do
		if type(path[i]) == 'string' then --see if command changed
			s = path[i]; i = i + 1
		end
		if s == 'move' then
			cr:move_to(get(2))
		elseif s == 'rel_move' then
			cr:rel_move_to(get(2))
		elseif s == 'line' then
			cr:line_to(get(2))
		elseif s == 'rel_line' then
			cr:rel_line_to(get(2))
		elseif s == 'hline' then
			local cpx,cpy = cr:get_current_point()
			cr:line_to(get(1), cpy)
		elseif s == 'rel_hline' then
			cr:rel_line_to(get(1), 0)
		elseif s == 'vline' then
			local cpx,cpy = cr:get_current_point()
			cr:line_to(cpx, get(1))
		elseif s == 'rel_vline' then
			cr:rel_line_to(0, get(1))
		elseif s == 'curve' then
			local x1,y1,x2,y2,x3,y3 = get(6)
			cr:curve_to(x1,y1,x2,y2,x3,y3)
			bx,by = x2,y2
		elseif s == 'rel_curve' then
			local x1,y1,x2,y2,x3,y3 = get(6)
			local cpx,cpy = cr:get_current_point()
			cr:rel_curve_to(x1,y1,x2,y2,x3,y3)
			bx,by = cpx+x2, cpy+y2
		elseif s == 'smooth_curve' then
			local x2,y2,x3,y3 = get(4)
			local x1,y1 = opposite_point(bx, by, cr:get_current_point())
			cr:curve_to(x1,y1,x2,y2,x3,y3)
			bx,by = x2,y2
		elseif s == 'rel_smooth_curve' then
			local x2,y2,x3,y3 = get(4)
			local cpx, cpy = cr:get_current_point()
			local x1, y1 = opposite_point(bx, by, cpx, cpy)
			cr:rel_curve_to(x1-cpx,y1-cpy,x2,y2,x3,y3)
			bx,by = cpx+x2, cpy+y2
		elseif s == 'quad_curve' then
			local x1,y1,x2,y2 = get(4)
			cr:quad_curve_to(x1,y1,x2,y2)
			qx,qy = x1,y1
		elseif s == 'rel_quad_curve' then
			local x1,y1,x2,y2 = get(4)
			local cpx,cpy = cr:get_current_point()
			cr:rel_quad_curve_to(x1,y1,x2,y2)
			qx,qy = cpx+x1, cpy+y1
		elseif s == 'smooth_quad_curve' then
			local x2,y2 = get(2)
			local x1,y1 = opposite_point(qx, qy, cr:get_current_point())
			cr:quad_curve_to(x1,y1,x2,y2)
			qx,qy = x1,y1
		elseif s == 'rel_smooth_quad_curve' then
			local x2,y2 = get(2)
			local cpx, cpy = cr:get_current_point()
			local x1,y1 = opposite_point(qx, qy, cpx, cpy)
			cr:rel_quad_curve_to(x1-cpx,y1-cpy,x2,y2)
			qx,qy = x1,y1
		elseif s == 'elliptical_arc' then
			local cpx, cpy = cr:get_current_point()
			local rx, ry, rotation, large, sweep, x3, y3 = get(7)
			draw_elliptical_arc(cr, cpx, cpy, rx, ry, math.rad(rotation), large, sweep, x3, y3)
		elseif s == 'rel_elliptical_arc' then
			local cpx, cpy = cr:get_current_point()
			local rx, ry, rotation, large, sweep, x3, y3 = get(7)
			draw_elliptical_arc(cr, cpx, cpy, rx, ry, math.rad(rotation), large, sweep, cpx+x3, cpy+y3)
		elseif s == 'close' then
			cr:close_path()
		elseif s == 'break' then --only useful for drawing a standalone arc
			cr:new_sub_path() --no current point after this
		elseif s == 'arc' or s == 'rel_arc' then
			local cpx, cpy = cr:get_current_point()
			local cx, cy, r, a1, a2 = get(5)
			local arc = a2 < 0 and cr.arc_negative or cr.arc
			if s == 'rel_arc' then
				cx = cpx + cx
				cy = cpx + cy
			end
			arc(cr, cx, cy, r, math.rad(a1), math.rad(math.max(math.min(a1 + a2, 360), -360)))
		elseif s == 'ellipse' then
			local cx, cy, rx, ry = get(4)
			local mt = cr:get_matrix()
			cr:translate(cx, cy)
			cr:scale(rx/ry, 1)
			cr:translate(-cx, -cy)
			cr:new_sub_path()
			cr:arc(cx, cy, ry, 0, 2*math.pi)
			cr:set_matrix(mt)
			cr:close_path()
		elseif s == 'circle' then
			local cx, cy, r = get(3)
			cr:new_sub_path()
			cr:arc(cx, cy, r, 0, 2*math.pi)
			cr:close_path()
		elseif s == 'rect' then
			cr:rectangle(get(4))
		elseif s == 'round_rect' then
			draw_round_rect(cr, get(5))
		elseif s == 'text' then
			local font,s = get(2)
			self:set_font(font)
			cr:text_path(s)
		else
			error('unknown path command %s', s)
		end

		if s ~= 'curve' and s ~= 'rel_curve' and s ~= 'smooth_curve' and s ~= 'rel_smooth_curve' then
			bx, by = nil
		end
		if s ~= 'quad_curve' and s ~= 'rel_quad_curve' and s ~= 'smooth_quad_curve' and s ~= 'rel_smooth_quad_curve' then
			qx, qy = nil
		end
	end
end
