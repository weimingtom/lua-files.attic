--demo on how an arc made of a single bezier segment looks at different sweeps.
local player = require'cairo_player'

--get a bezier representation of an arc of sweep a < 90° bisected by the x-axis.
--math from http://www.tinaja.com/glib/bezcirc2.pdf (typo: x3=x1 should be x3=x0)
local function small_arc_to_curve(a)
	local x0 = math.cos(a/2)
	local y0 = math.sin(a/2)
	local x1 = (4-x0)/3
	local y1 = (1-x0) * (3-x0) / (3*y0)
	local x2 = x1
	local y2 = -y1
	local x3 = x0
	local y3 = -y0
	return x0, y0, x1, y1, x2, y2, x3, y3
end

local i = 0
function player:on_render(cr)
	i = i+1

	cr:identity_matrix()
	cr:set_source_rgb(0,0,0)
	cr:paint()

	cr:translate(100, 200)
	cr:scale(100, 100)
	cr:rotate(math.rad(-45))

	local a = math.rad(i % 90 + 1)
	local x0, y0, x1, y1, x2, y2, x3, y3 = small_arc_to_curve(a)
	cr:move_to(x0, y0)
	cr:curve_to(x1, y1, x2, y2, x3, y3)
	cr:line_to(0, 0)
	cr:line_to(x0, y0)
	cr:set_source_rgb(1,1,1)
	cr:set_line_width(1/100)
	cr:stroke()
end

player:play()
