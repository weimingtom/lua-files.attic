local ffi = require'ffi'
local M = require'cairo'
require'stdio'

ffi.cdef[[
typedef struct _cairo_script_interpreter cairo_script_interpreter_t;
typedef void
(*csi_destroy_func_t) (void *closure,
         void *ptr);
typedef cairo_surface_t *
(*csi_surface_create_func_t) (void *closure,
         cairo_content_t content,
         double width,
         double height,
         long uid);
typedef cairo_t *
(*csi_context_create_func_t) (void *closure,
         cairo_surface_t *surface);
typedef void
(*csi_show_page_func_t) (void *closure,
    cairo_t *cr);
typedef void
(*csi_copy_page_func_t) (void *closure,
    cairo_t *cr);
typedef struct _cairo_script_interpreter_hooks {
    void *closure;
    csi_surface_create_func_t surface_create;
    csi_destroy_func_t surface_destroy;
    csi_context_create_func_t context_create;
    csi_destroy_func_t context_destroy;
    csi_show_page_func_t show_page;
    csi_copy_page_func_t copy_page;
} cairo_script_interpreter_hooks_t;
 cairo_script_interpreter_t *
cairo_script_interpreter_create (void);
 void
cairo_script_interpreter_install_hooks (cairo_script_interpreter_t *ctx,
     const cairo_script_interpreter_hooks_t *hooks);
 cairo_status_t
cairo_script_interpreter_run (cairo_script_interpreter_t *ctx,
         const char *filename);
 cairo_status_t
cairo_script_interpreter_feed_stream (cairo_script_interpreter_t *ctx,
          FILE *stream);
 cairo_status_t
cairo_script_interpreter_feed_string (cairo_script_interpreter_t *ctx,
          const char *line,
          int len);
 unsigned int
cairo_script_interpreter_get_line_number (cairo_script_interpreter_t *ctx);
 cairo_script_interpreter_t *
cairo_script_interpreter_reference (cairo_script_interpreter_t *ctx);
 cairo_status_t
cairo_script_interpreter_finish (cairo_script_interpreter_t *ctx);
 cairo_status_t
cairo_script_interpreter_destroy (cairo_script_interpreter_t *ctx);
 cairo_status_t
cairo_script_interpreter_translate_stream (FILE *stream,
                                    cairo_write_func_t write_func,
        void *closure);
]]

ffi.metatype('cairo_script_interpreter_t', {__gc = M.cairo_script_interpreter_destroy, __index = {
	install_hooks = M.cairo_script_interpreter_install_hooks,
	run = M.cairo_script_interpreter_run,
	feed_stream = M.cairo_script_interpreter_feed_stream,
	feed_string = M.cairo_script_interpreter_feed_string,
	get_line_number = M.cairo_script_interpreter_get_line_number,
	reference = M.cairo_script_interpreter_reference,
	finish = M.cairo_script_interpreter_finish,
	free = M.cairo_script_interpreter_destroy,
	translate_stream = M.cairo_script_interpreter_translate_stream,
}})
