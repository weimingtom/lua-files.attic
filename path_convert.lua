--converting commands in 2d paths.

local edit = require'path_edit'
local insert, remove, update = edit.insert, edit.remove, edit.update

local point = require'path_point'
local line = require'path_line'

local convert = setmetatable({},{__index = function(t,k) t[k] = {}; return t[k] end}) --autotable

function convert.line.hline(path, i, cpx, cpy, spx, spy, bx, by)
	path[i] = 'hline'
	remove(path, i+2) --remove y
end

function convert.hline.line(path, i, cpx, cpy, spx, spy, bx, by)
	path[i] = 'line'
	insert(path, i+2, cpy) --add y
end

function convert.line.vline(path, i, cpx, cpy, spx, spy, bx, by)
	path[i] = 'vline'
	remove(path, i+1) --remove x
end

function convert.vline.line(path, i, cpx, cpy, spx, spy, bx, by)
	path[i] = 'line'
	insert(path, i+1, cpx) --add x
end

function convert.line.curve(path, i, cpx, cpy, spx, spy, bx, by)
	path[i] = 'curve'
	--elasticize: add control points at 1/3 and 2/3 of the line
	local x2, y2 = select(3, line.split(1/3, cpx, cpy, path[i+1], path[i+2]))
	local x3, y3 = select(3, line.split(2/3, cpx, cpy, path[i+1], path[i+2]))
	insert(path, i+1, x2, y2, x3, y3)
end

function convert.curve.line(path, i, cpx, cpy, spx, spy, bx, by)
	path[i] = 'line'
	remove(path, i+1, 4) --flatten: remove control points, leave the endpoint
end

function convert.symm_curve.curve(path, i, cpx, cpy, spx, spy, bx, by)
	local x2, y2 = point.reflect_point(bx or cpx, by or cpy, cpx, cpy)
	path[i] = 'curve'
	insert(path, i+1, x2, y2) --store the reflected control point
end

function convert.curve.symm_curve(path, i, cpx, cpy, spx, spy, bx, by)
	path[i] = 'symm_curve'
	remove(path, i+1, 2) --remove the first control point (TODO: correct the prev. curve's 2nd cp angle too)
end

function convert.smooth_curve.curve(path, i, cpx, cpy, spx, spy, bx, by)
	local x2, y2 = point.reflect_point_distance(bx or cpx, by or cpy, cpx, cpy, path[i+1])
	path[i] = 'curve'
	insert(path, i+1, x2, y2) --store the reflected control point
end

function convert.curve.smooth_curve(path, i, cpx, cpy, spx, spy, bx, by)
	path[i] = 'smooth_curve'
	path[i+1] = point.distance(cpx, cpy, path[i+1], path[i+2]) --preserve the distance, store over x2
	remove(path, i+2, 1) --remove y2
end

local path_state = require'path_state'

local function convert_commands(path, query)
	local cpx, cpy, spx, spy, bx, by, qx, qy
	for i,s in path_state.commands(path) do
		local cmd = query(path, i, s)
		if cmd then
			local convert = convert[s][cmd]
			convert(path, i, cpx, cpy, spx, spy, bx, by, qx, qy)
		end
		cpx, cpy, spx, spy, bx, by, qx, qy = path_state.next_state(path, i, cpx, cpy, spx, spy, bx, by, qx, qy)
	end
end

local function convert_command(path, i, cmd)
	convert_commands(path, function(path, i_, s) return i_==i and cmd or nil end)
end

return convert_commands
