local fn = {
	copy = function(t1, i) return t1[i] end,
	add = function(t1, i, t2, j) return t1[i] + t2[j] end,
	sub = function(t1, i, t2, j) return t1[i] - t2[j] end,
	reflect = function(t1, xi, t2, ci) return 2 * t2[ci] - t1[xi] end,
}

--a linker lets you create dependencies between variables so that when one variable
--is updated, dependent variables are updated too with the result of a custom function.
local function linker()
	local deps = {}
	local function link(t1, k1, t2, k2, f, ...)
		deps[t1] = deps[t1] or {}
		deps[t1][k1] = deps[t1][k1] or {}
		deps[t1][k1][t2] = deps[t1][k1][t2] or {}
		deps[t1][k1][t2][k2] = {f, ...}
	end
	local function update(t, k, v, touched)
		touched = touched or {}
		touched[t] = touched[t] or {}
		if touched[t][k] then return end
		t[k] = v
		touched[t][k] = true
		local dt = deps[t] and deps[t][k]
		if not dt then return end
		for t2, dt in pairs(dt) do
			for k2, dep in pairs(dt) do
				update(t2, k2, dep[1](unpack(dep, 2)), touched)
			end
		end
	end
	return {
		link = link,
		update = update,
	}
end

do
	local e = linker()
	local t1 = {a=1, x = 5}
	local t2 = {b=0, y = 7}
	e.link(t1, 'a', t2, 'b', fn.add, t1, 'x', t2, 'y')
	e.update(t1, 'a', 3)
	print(t2.b)
end

local glue = require'glue'

local e = linker()
local points = {}
local function point(x,y)
	glue.append(points,x,y)
	return #points-1, #points
end
local dv = {}
local function update(k,v)
	dv[1] = v - points[k]
	e.update(points,k,v)
end

local path = {'move', 5, 5}
local i = 1
local c1x, c1y = i+1, i+2
local p1x, p1y = point(path[c1x], path[c1y])

e.link(points, p1x, path, c1x, function() return points[p1x] end)
e.link(points, p1x, path, c1y, fn.copy, points, p1y)

update(p1x, 7)
print(path[c1x])
