--result of `cpp cairo-script.h` from cairo 1.12.3
local ffi = require'ffi'
require'cairo_h'
ffi.cdef[[
typedef enum {
    CAIRO_SCRIPT_MODE_ASCII,
    CAIRO_SCRIPT_MODE_BINARY
} cairo_script_mode_t;
 cairo_device_t *
cairo_script_create (const char *filename);
 cairo_device_t *
cairo_script_create_for_stream (cairo_write_func_t write_func,
    void *closure);
 void
cairo_script_write_comment (cairo_device_t *script,
       const char *comment,
       int len);
 void
cairo_script_set_mode (cairo_device_t *script,
         cairo_script_mode_t mode);
 cairo_script_mode_t
cairo_script_get_mode (cairo_device_t *script);
 cairo_surface_t *
cairo_script_surface_create (cairo_device_t *script,
        cairo_content_t content,
        double width,
        double height);
 cairo_surface_t *
cairo_script_surface_create_for_target (cairo_device_t *script,
     cairo_surface_t *target);
 cairo_status_t
cairo_script_from_recording_surface (cairo_device_t *script,
         cairo_surface_t *recording_surface);
]]
