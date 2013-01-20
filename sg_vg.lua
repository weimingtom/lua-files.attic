--scene graph for openvg: renders a 2D scene graph using the openvg API.
--some modules are loaded on-demand: look for require() in the code.
local ffi = require'ffi'
local vg = require'openvg'
local glue = require'glue'
local BaseSG = require'sg_base'

local SG = glue.update({}, BaseSG)

function SG:new(surface, cache)
	local o = BaseSG.new(self, cache)
	--
	return o
end

function SG:free()
	BaseSG.free(self)
end

function SG:render()
	self:errors_flush()
end

if not ... then
local winapi = require'winapi'
local gl = require'winapi.gl21'
require'winapi.windowclass'
require'winapi.wglpanel'
require'winapi.messageloop'
local main = winapi.Window{autoquit = true, visible = false}
local panel = winapi.WGLPanel{parent = main, anchors = {left = true, top = true, right = true, bottom = true}}
function panel:on_resize(w, h)
	vg.vgPrivSurfaceResizeMZT(windowSurface, w, h)
end
function panel:set_viewport()
	local w, h = self.client_w, self.client_h
	gl.glViewport(0, 0, w, h)
	gl.glMatrixMode(gl.GL_PROJECTION)
	gl.glLoadIdentity()
	gl.glFrustum(-1, 1, -1, 1, 1, 100) --so fov is 90 deg
	gl.glScaled(1, w/h, 1)
end
function panel:on_render()
	gl.glEnable(gl.GL_BLEND)
	gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_SRC_ALPHA)
	gl.glDisable(gl.GL_DEPTH_TEST)
	gl.glDisable(gl.GL_CULL_FACE)
	gl.glDisable(gl.GL_LIGHTING)
	gl.glMatrixMode(gl.GL_MODELVIEW)
	gl.glLoadIdentity()
	gl.glTranslated(0,0,-1)
end
panel.w = main.client_w
panel.h = main.client_h
main:show()
os.exit(winapi.MessageLoop())
end

return SG
