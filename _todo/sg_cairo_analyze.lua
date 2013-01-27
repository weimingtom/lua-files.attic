--cairo scene graph analyzer
local ffi = require'ffi'
local cairo = require'cairo'
local glue = require'glue'

local transform_fields = {
	'absolute', 'matrix', 'x', 'y', 'cx', 'cy', 'angle', 'scale', 'sx', 'sy', 'skew_x', 'skew_y', 'transforms',
}

local function contains_keys(t, keys)
	for i=1,#keys do
		if t[keys[i]] ~= nil then return true end
	end
end

local function transformed(e)
	return contains_keys(e, transform_fields)
end

local function new_matrix(...)
	return ffi.new('cairo_matrix_t', ...)
end

local function transform(mt, e)
	if e.absolute then mt:init_identity() end
	if e.matrix then mt:safe_transform(new_matrix(unpack(e.matrix))) end
	if e.x or e.y then mt:translate(e.x or 0, e.y or 0) end
	if e.cx or e.cy then mt:translate(e.cx or 0, e.cy or 0) end
	if e.angle then mt:rotate(math.rad(e.angle)) end
	if e.scale then mt:scale(e.scale, e.scale) end
	if e.sx or e.sy then mt:scale(e.sx or 1, e.sy or 1) end
	if e.cx or e.cy then mt:translate(-(e.cx or 0), -(e.cy or 0)) end
	if e.skew_x or e.skew_y then mt:skew(math.rad(e.skew_x or 0), math.rad(e.skew_y or 0)) end
	if e.transforms then
		for _,t in ipairs(e.transforms) do
			local op = t[1]
			if op == 'matrix' then
				mt:safe_transform(new_matrix(unpack(t, 2)))
			elseif op == 'translate' then
				mt:translate(t[2], t[3] or 0)
			elseif op == 'rotate' then
				local cx, cy = t[3], t[4]
				if cx or cy then mt:translate(cx or 0, cy or 0) end
				mt:rotate(math.rad(t[2]))
				if cx or cy then mt:translate(-(cx or 0), -(cy or 0)) end
			elseif op == 'scale' then
				local cx, cy = t[4], t[5]
				if cx or cy then mt:translate(cx or 0, cy or 0) end
				mt:scale(t[2], t[3] or t[2])
				if cx or cy then mt:translate(-(cx or 0), -(cy or 0)) end
			elseif op == 'skew' then
				mt:skew(math.rad(t[2]), math.rad(t[3]))
			end
		end
	end
end

local function compute_matrices(e, f)
	local mt = new_matrix()
	mt:init_identity()
	local function analyze(e)
		if not e or e.hidden then return end
		transform(mt, e)
		f(e, mt)
		if e.type == 'group' then
			local cmt = mt:copy()
			for _,ce in ipairs(e) do
				analyze(ce)
				mt:init_matrix(cmt)
			end
		elseif e.type == 'shape' then
			local cmt = mt:copy()
			analyze(e.fill)
			mt:init_matrix(cmt)
			analyze(e.stroke)
			mt:init_matrix(cmt)
		end
	end
	analyze(e)
end

local function create_context()
	local rect = ffi.new('cairo_rectangle_t', 0, 0, 1, 1)
	local surface = cairo.cairo_recording_surface_create(cairo.CAIRO_CONTENT_COLOR_ALPHA, rect)
	local cr = surface:create_context()
	surface:destroy() --cr still has a reference to it
	return cr
end

local function set_font(cr, e)
	--
end

local function draw_round_rect(cr, x1, y1, w, h, r)
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

local function draw_elliptical_arc(cr, x1, y1, rx, ry, rotation, large, sweep, x3, y3) --from cairosvg/path.py
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

local function draw_path(cr, path)
	cr:new_path() --no current point after this
	if type(path[1]) ~= 'string' then
		error'path must start with a command'
		return
	end
	local i = 1
	local s
	local function get(n)
		for j=1,n do
			if type(path[i+j-1]) ~= 'number' then
				error(string.format('path: invalid %s arg# %d at index %d: %s, number expected)',
											s, j, i, type(path[i+j-1]), i))
				return
			end
		end
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
		elseif s == 'arc' then
			local cx, cy, r, a1, a2 = get(5)
			cr:arc(cx, cy, r, math.rad(a1), math.rad(a2))
		elseif s == 'negative_arc' then
			local cx, cy, r, a1, a2 = get(5)
			cr:arc_negative(cx, cy, r, math.rad(a1), math.rad(a2))
		elseif s == 'rel_arc' then
			local cx, cy, r, a1, a2 = get(5)
			local cpx, cpy = cr:get_current_point()
			cr:arc(cpx+cx, cpy+cy, r, math.rad(a1), math.rad(a2))
		elseif s == 'rel_negative_arc' then
			local cx, cy, r, a1, a2 = get(5)
			local cpx, cpy = cr:get_current_point()
			cr:arc_negative(cpx+cx, cpy+cy, r, math.rad(a1), math.rad(a2))
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
			local font,x,y,s = path[i], path[i+1], path[i+2], path[i+3]; i=i+4
			set_font(font)
			cr:move_to(x,y)
			cr:text_path(s)
		else
			error('unknown path command %s', s)
			return
		end

		if s ~= 'curve' and s ~= 'rel_curve' and s ~= 'smooth_curve' and s ~= 'rel_smooth_curve' then
			bx, by = nil
		end
		if s ~= 'quad_curve' and s ~= 'rel_quad_curve' and s ~= 'smooth_quad_curve' and s ~= 'rel_smooth_quad_curve' then
			qx, qy = nil
		end
	end
end

local function compute_paths(e, cr)
	local paths = setmetatable({}, {__mode = 'k'}) --{path_t = path}
	local function analyze(e)
		if not e or e.hidden then return end
		if e.type == 'group' then
			for _,e in ipairs(e) do
				analyze(e)
			end
		elseif e.type == 'shape' then
			if not paths[e.path] then
				draw_path(cr, e.path)
				paths[e.path] = cr:copy_path_flat()
			end
			analyze(e.fill)
			analyze(e.stroke)
		end
	end
	analyze(e)
	return paths
end

local function path_state()
	local current_path
	local function set_path(path)
		if current_path == path then return end
		cr:new_path()
		cr:append_path(path)
		current_path = path
	end
	return set_path, current_path
end


local function wireframe(e, matrices, paths, cr)

	local set_path = path_state()

	local function analyze(e)
		if not matrices[e] then return end
		if e.type == 'group' then
			for _,e in ipairs(e) do
				analyze(e)
			end
		elseif e.type == 'shape' then
			cr:set_matrix(matrices[e])
			set_path(paths[e.path])
			if e.fill then
				--TODO: cr:set_fill_rule(e.fill_rule)
				cr:save()
				cr:clip()
				analyze(e.fill)
				cr:restore()
			end
			if e.stroke then --we can't hit test individual stroke components, only the stroke element itself
				cr:set_line_width(e.line_width or 1)
				--TODO: set cap, join, miter_limit, dashes.
				set_path(paths[e.path])
				cr:stroke()
			end
		elseif e.type == 'color' then
			if cr:in_clip(x, y) then elements[#elements+1] = true end
		elseif e.type == 'gradient' then
			--TODO: if extend is none, compute the real bounds
			if cr:in_clip(x, y) then elements[#elements+1] = true end
		elseif e.tpye == 'image' then --compute based on the extend parameter
			--TODO: if extend is none, compute the real bounds
			if cr:in_clip(x, y) then elements[#elements+1] = true end
		end
	end

	cr:set_source_rgba(1,1,1,1)
	analyze(e)
end

local scene = {
	type = 'group', x = 100, y = 100,
	{type = 'color', 0,0,0,1},
	{type = 'group', x = 200, cx = 300, cy = 300, angle = -15, scale = .5, skew_x = 0,
		{type = 'shape', path = {'rect', 0, 0, 100, 100}, fill = {type = 'color', 1,1,1,1}},
		{type = 'shape', y = 210, path = {'rect', 0, 0, 100, 100}, line_width = 50, stroke = {type = 'color', 1,1,1,1}},
		{type = 'image', angle = -30, y = 360, x = 100, file = {path = 'media/jpeg/testorig.jpg'}},
	},
}

local matrices = compute_matrices(scene)
local cr = create_context()
local paths = compute_paths(scene, matrices, cr)
pp(hit_test(100, 100, scene, matrices, paths, cr))
cr:free()

local player = require'cairopanel_player'

function player:on_render(cr)
	wireframe(scene, matrices, paths, cr)
end
player:play()


