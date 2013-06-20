--path global time -------------------------------------------------------------------------------------------------------

local is_timed = glue.index{'close', 'line', 'hline', 'vline', 'curve', 'symm_curve', 'smooth_curve', 'quad_curve',
									'quad_curve_3p', 'symm_quad_curve', 'smooth_quad_curve', 'carc', 'arc', 'elliptic_arc',
									'line_arc', 'line_elliptic_arc', 'arc_3p', 'svgarc'}

local t = {}
for k in pairs(is_timed) do
	t['rel_'..k] = true
end
glue.update(is_timed, t)

local function global_time(i, t, path)
	local count = 0
	local n --the number of the command at index i, relative to count.
	for ci,s in commands(path) do
		count = count + (is_timed[s] and 1 or 0)
		if ci == i then n = count end
	end
	assert(n, 'invalid command index')
	return (n - 1 + t)/count
end

local function local_time(t, path)
	t = math.min(math.max(t, 0), 1)
	local count = 0
	for _,s in commands(path) do
		count = count + (is_timed[s] and 1 or 0)
	end
	if count == 0 then return end --path has no timed commands: any t is invalid.
	local n, t = math.modf(count * t)
	n = n + 1
	if n > count then
		n, t = count, 1
	end
	local count = 0
	for i,s in commands(path) do
		count = count + (is_timed[s] and 1 or 0)
		if count == n then
			return i, t
		end
	end
	--the time range 0..1 covers the timed commands continuously, so a command must always be found.
	assert(false)
end

