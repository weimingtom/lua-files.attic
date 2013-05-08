--image sources for cairo scene graph using cairo's built-in png support.
--this was used before I made the libpng binding.
local SG = require'sg_cairo'
local ffi = require'ffi'
local cairo = require'cairo'

local function string_reader(data)
	local i = 1
	return function(_, buf, sz)
		if sz < 1 or #data < i then return cairo.CAIRO_STATUS_READ_ERROR end
		local s = data:sub(i, i+sz-1)
		if #s ~= sz then return cairo.CAIRO_STATUS_READ_ERROR end
		ffi.copy(buf, s, sz)
		i = i + sz
		return cairo.CAIRO_STATUS_SUCCESS
	end
end

function SG:set_image_source(e)
	local surface = self:cache_get(e.file)
	if not surface then
		if e.file.path then
			surface = cairo.cairo_image_surface_create_from_png(e.file.path)
		elseif e.file.string then
			local read_cb = ffi.cast('cairo_read_func_t', string_reader(e.file.string))
			surface = cairo.cairo_image_surface_create_from_png_stream(read_cb, nil)
			read_cb:free()
		else
			self:error('image: path or string expected')
			return
		end
		if surface:status() ~= 0 then
			self:error(surface:status_string())
			return
		end
		e.file.w = cairo.cairo_image_surface_get_width(surface)
		e.file.h = cairo.cairo_image_surface_get_height(surface)
		self:cache_set(e.file, surface)
	end
	self.cr:set_source_surface(surface, 0, 0)
	local pat = self.cr:get_source()
	pat:set_filter(self.pattern_filters[e.filter or self.defaults.image_pattern_filter])
	pat:set_extend(self.pattern_extends[e.extend or self.defaults.image_pattern_extend])
end

