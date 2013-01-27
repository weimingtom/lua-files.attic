local ffi = require'ffi'
local M = require'cairo'
require'openvg_h'

ffi.cdef[[
typedef struct _cairo_vg_context cairo_vg_context_t;
 cairo_status_t
cairo_vg_context_status (cairo_vg_context_t *context);
 void
cairo_vg_context_destroy (cairo_vg_context_t *context);
 cairo_surface_t *
cairo_vg_surface_create (cairo_vg_context_t *context,
    cairo_content_t content, int width, int height);
 cairo_surface_t *
cairo_vg_surface_create_for_image (cairo_vg_context_t *context,
       VGImage image,
       VGImageFormat format,
       int width, int height);
 VGImage
cairo_vg_surface_get_image (cairo_surface_t *abstract_surface);
 VGImageFormat
cairo_vg_surface_get_format (cairo_surface_t *abstract_surface);
 int
cairo_vg_surface_get_height (cairo_surface_t *abstract_surface);
 int
cairo_vg_surface_get_width (cairo_surface_t *abstract_surface);
]]

ffi.metatype('cairo_vg_context_t', {__gc = M.cairo_vg_context_destroy, __index = {
	status = M.cairo_vg_context_status,
	free = M.cairo_vg_context_destroy,
	create_surface = M.cairo_vg_surface_create,
	create_surface_for_image = M.cairo_vg_surface_create_for_image,
}})

