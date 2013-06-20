--path length at time t ---------------------------------------------------------------------------

local tlen = {}

local function length_at(global_t, path, mt)
	local total = 0
	local function write(len)
		total = total + len
	end
	local target_index, local_t = local_time(global_t, path)
	local function tlen_processor(write, mt, i, s, ...)
		if i > target_index then return end --TODO: find a way to end the iteration conditionally.
		if not is_timed[s] then return end --untimed commands don't have a timed length.
		if not tlen[s] then return false end --signal decoder to recurse.
		local t = i == target_index and local_t or 1
		return tlen[s](t, write, mt, ...)
	end
	decode_recursive(tlen_processor, write, path, mt)
	return total
end

function tlen.line(t, mt, x1, y1, x2, y2)
	if mt then
		x1, y1 = mt(x1, y1)
		x2, y2 = mt(x2, y2)
	end
	return line_len(t, x1, y1, x2, y2)
end

tlen.close = tlen.line

function tlen.curve(t, mt, x1, y1, x2, y2, x3, y3, x4, y4)
	if mt then
		x1, y1 = mt(x1, y1)
		x2, y2 = mt(x2, y2)
		x3, y3 = mt(x3, y3)
		x4, y4 = mt(x4, y4)
	end
	return curve_len(t, x1, y1, x2, y2, x3, y3, x4, y4)
end

function tlen.quad_curve(t, mt, x1, y1, x2, y2, x3, y3)
	if mt then
		x1, y1 = mt(x1, y1)
		x2, y2 = mt(x2, y2)
		x3, y3 = mt(x3, y3)
	end
	return quad_curve_len(t, x1, y1, x2, y2, x3, y3)
end

function tlen.carc(t, mt, cpx, cpy, connect, cx, cy, rx, ry, start_angle, sweep_angle, rotation, x2, y2)
	local where = 1
	local len = 0
	if connect then
		where, t = math.modf(t * 2)
		if where > 1 then where, t = 1, 1 end
		len = tlen.line(t, mt, cpx, cpy, x1, y1)
	end
	if where > 0 then --t hits the arc
		if mt or rx ~= ry or rotation ~= 0 then
			return false
		else
			return len + arc_len(t, cx, cy, rx, start_angle, sweep_angle)
		end
	end
end
]]

--path point --------------------------------------------------------------------------------------

--[[
local point_functions = {
	line       = require'path_line'.point,
	quad_curve = require'path_bezier2'.point,
	curve      = require'path_bezier3'.point,
}

local point_functions_no_trans = glue.update({
	arc        = require'path_arc'.point,
	arc_3p     = require'path_arc_3p'.point,
}, point_functions)

local function point(t, path)
	local i,t = local_time(t, path)

	local function write(i, s, ...)
		point_functions[s](...)
	end
	decode(write, path)
end

]]



	if i == 1 then
		--print(path.length_at(0, p, mt))
		--print(path.length_at(0.5, p, mt))
		--print(path.length_at(1, p, mt))
	end

	--[[
	if i <= 100 then
		local li = i/100
		local tlen = path.length_at(li, p, mt)
		--print(li, tlen)
	end
	]]

