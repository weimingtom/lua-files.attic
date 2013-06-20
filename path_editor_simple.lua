--2d path editing
local glue = require'glue'
local path_state = require'path'

local function control_points(path, write, target_index, px, py)
	local point_count = 0
	local function pt(x, y)
		point_count = point_count + 1
		write(point_count, x, y)
	end
	local function at(offset)
		return point_count + offset == target_index
	end
	local cpx, cpy, spx, spy
	local dcpx, dcpy = 0, 0
	local function process(i, rs, s, ...)
		local rel = rs:match'^rel_'
		if s == 'move' or s == 'line' then
			local x2, y2 = ...
			if rel then
				x2, y2 = x2 - dcpx, y2 - dcpy
				dcpx, dcpy = 0, 0
			end
			if at(1) then
				dcpx, dcpy = px - x2, py - y2
				x2, y2 = px, py
			end
			path[i+1] = x2 - (rel and cpx or 0)
			path[i+2] = y2 - (rel and cpy or 0)
			pt(x2, y2)
		elseif s == 'hline' then
			local x2, y2 = ..., cpy
			if rel then
				x2, y2 = x2 - dcpx, y2
				dcpx, dcpy = 0, 0
			end
			if at(1) then
				py = cpy
				dcpx, dcpy = px - x2, py - y2
				x2, y2 = px, py
			end
			path[i+1] = x2 - (rel and cpx or 0)
			pt(x2, y2)
		elseif s == 'vline' then
			local x2, y2 = cpx, ...
			if rel then
				x2, y2 = x2, y2 - dcpy
				dcpx, dcpy = 0, 0
			end
			if at(1) then
				px = cpx
				dcpx, dcpy = px - x2, py - y2
				x2, y2 = px, py
			end
			path[i+1] = y2 - (rel and cpy or 0)
			pt(x2, y2)
		elseif s == 'close' then

		end
		cpx, cpy, spx, spy = path_state.next_cp(cpx, cpy, spx, spy, path_state.abs_cmd(cpx, cpy, path_state.cmd(path, i)))
	end
	for i,s in path_state.commands(path) do
		process(i, s, path_state.abs_cmd(cpx, cpy, path_state.cmd(path, i)))
	end
end

if not ... then require'path_cairo_demo' end

return control_points

