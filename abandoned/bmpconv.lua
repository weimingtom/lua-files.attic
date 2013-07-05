--pixel format upsampling, resampling and downsampling for luajit.
--supports all conversions between packed 8 bit-per-channel gray and rgb pixel formats, and cmyk to all.
--supports different input/output scanline orientations, namely top-down and bottom-up, and different strides.
--TODO: 16bit rgb (565,4444,5551)? bw-1? alpha-1,4,8? linear-rgb? premultiplied-alpha? xyz? cie?
--TODO: create a thread pool and pipe up conversions to multiple threads, splitting the work on bitmap segments.

--bitmap conversion functions. they should be able to run in lanes, so don't drag any upvalues with them!

local function dstride(src, dst)
	local dj, dstride = 0, dst.stride
	if src.orientation ~= dst.orientation then
		dj = (src.h - 1) * dstride --first pixel of the last row
		dstride = -dstride --...and stepping backwards
	end
	return dj, dstride
end

local function eachrow(convert_pixel)
	return function(src, dst, h1, h2)
		local ffi = require'ffi' --for lanes
		local dj, dstride = dstride(src, dst)
		local pixelsize = #src.pixel
		local rowsize = src.w * pixelsize
		local src_data = ffi.cast('uint8_t*', src.data) --ensure byte type (also src.data is a number when in lanes)
		local dst_data = ffi.cast('uint8_t*', dst.data)
		for sj = h1 * src.stride, h2 * src.stride, src.stride do
			convert_pixel(dst_data, dj, src_data, sj, rowsize)
			dj = dj + dstride
		end
	end
end

local copy_rows = eachrow(function(d, i, s, j, rowsize)
	local ffi = require'ffi' --for lanes
	ffi.copy(d+i, s+j, rowsize)
end)

local function eachpixel(convert_pixel)
	return function(src, dst, h1, h2)
		local ffi = require'ffi' --for lanes
		local dj, dstride = dstride(src, dst)
		local pixelsize = #src.pixel
		local dpixelsize = #dst.pixel
		local src_data = ffi.cast('uint8_t*', src.data)
		local dst_data = ffi.cast('uint8_t*', dst.data)
		for sj = h1 * src.stride, h2 * src.stride, src.stride do
			for i = 0, src.w - 1 do
				convert_pixel(dst_data, dj + i * dpixelsize, src_data, sj + i * pixelsize)
			end
			dj = dj + dstride
		end
	end
end

--pixel conversion functions. these should also be able to run in lanes.

local matrix = {
	g = {},
	ga = {}, ag = {},
	rgb = {}, bgr = {},
	rgba = {}, bgra = {}, argb = {}, abgr = {},
	rgbx = {}, bgrx = {}, xrgb = {}, xbgr = {},
	cmyk = {},
}

matrix.ga.ag = eachpixel(function(d, i, s, j) d[i], d[i+1] = s[j+1], s[j] end)
matrix.ag.ga = matrix.ga.ag

matrix.bgr.rgb = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2] = s[j+2], s[j+1], s[j] end)
matrix.rgb.bgr = matrix.bgr.rgb

matrix.rgba.abgr = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j+3], s[j+2], s[j+1], s[j+0] end)
matrix.bgra.argb = matrix.rgba.abgr
matrix.argb.bgra = matrix.rgba.abgr
matrix.abgr.rgba = matrix.rgba.abgr
matrix.argb.rgba = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j+1], s[j+2], s[j+3], s[j+0] end)
matrix.abgr.bgra = matrix.argb.rgba
matrix.rgba.argb = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j+3], s[j+0], s[j+1], s[j+2] end)
matrix.bgra.abgr = matrix.rgba.argb
matrix.rgba.bgra = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j+2], s[j+1], s[j+0], s[j+3] end)
matrix.bgra.rgba = matrix.rgba.bgra
matrix.argb.abgr = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j+0], s[j+3], s[j+2], s[j+1] end)
matrix.abgr.argb = matrix.argb.abgr

matrix.rgbx.xbgr = matrix.rgba.abgr
matrix.bgrx.xrgb = matrix.rgba.abgr
matrix.xrgb.bgrx = matrix.rgba.abgr
matrix.xbgr.rgbx = matrix.rgba.abgr
matrix.xrgb.rgbx = matrix.argb.rgba
matrix.xbgr.bgrx = matrix.argb.rgba
matrix.rgbx.xrgb = matrix.rgba.argb
matrix.bgrx.xbgr = matrix.rgba.argb
matrix.rgbx.bgrx = matrix.rgba.bgra
matrix.bgrx.rgbx = matrix.rgba.bgra
matrix.xrgb.xbgr = matrix.argb.abgr
matrix.xbgr.xrgb = matrix.argb.abgr

matrix.rgbx.abgr = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = 0xff, s[j+2], s[j+1], s[j+0] end)
matrix.bgrx.argb = matrix.rgbx.abgr
matrix.xrgb.bgra = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j+3], s[j+2], s[j+1], 0xff end)
matrix.xbgr.rgba = matrix.xrgb.bgra
matrix.xrgb.rgba = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j+1], s[j+2], s[j+3], 0xff end)
matrix.xbgr.bgra = matrix.xrgb.rgba
matrix.rgbx.argb = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = 0xff, s[j+0], s[j+1], s[j+2] end)
matrix.bgrx.abgr = matrix.rgbx.argb
matrix.rgbx.bgra = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j+2], s[j+1], s[j+0], 0xff end)
matrix.bgrx.rgba = matrix.rgbx.bgra
matrix.xrgb.abgr = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = 0xff, s[j+3], s[j+2], s[j+1] end)
matrix.xbgr.argb = matrix.xrgb.abgr

matrix.g.ag = eachpixel(function(d, i, s, j) d[i+1], d[i+0] = s[j], 0xff end)
matrix.g.ga = eachpixel(function(d, i, s, j) d[i+0], d[i+1] = s[j], 0xff end)

matrix.g.rgb = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2] = s[j], s[j], s[j] end)
matrix.g.bgr = matrix.g.rgb

matrix.g.argb = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = 0xff, s[j], s[j], s[j] end)
matrix.g.abgr = matrix.g.argb
matrix.g.rgba = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j], s[j], s[j], 0xff end)
matrix.g.bgra = matrix.g.rgba

matrix.ga.rgba = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j+0], s[j+0], s[j+0], s[j+1] end)
matrix.ga.bgra = matrix.ga.rgba
matrix.ga.argb = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j+1], s[j+0], s[j+0], s[j+0] end)
matrix.ga.abgr = matrix.ga.argb
matrix.ag.rgba = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j+1], s[j+1], s[j+1], s[j+0] end)
matrix.ag.bgra = matrix.ag.rgba
matrix.ag.argb = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j+0], s[j+1], s[j+1], s[j+1] end)
matrix.ag.abgr = matrix.ag.argb

matrix.rgb.argb = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = 0xff, s[j], s[j+1], s[j+2] end)
matrix.bgr.abgr = matrix.rgb.argb
matrix.rgb.rgba = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j], s[j+1], s[j+2], 0xff end)
matrix.bgr.bgra = matrix.rgb.rgba
matrix.rgb.abgr = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = 0xff, s[j+2], s[j+1], s[j] end)
matrix.bgr.argb = matrix.rgb.abgr
matrix.rgb.bgra = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2], d[i+3] = s[j+2], s[j+1], s[j], 0xff end)
matrix.bgr.rgba = matrix.rgb.bgra

local function rgb2g(r,g,b) return 0.2126 * r + 0.7152 * g + 0.0722 * b end --photometric/digital ITU-R formula

matrix.rgb.g = eachpixel(function(d, i, s, j) d[i] = rgb2g(s[j+0], s[j+1], s[j+2]) end)
matrix.bgr.g = eachpixel(function(d, i, s, j) d[i] = rgb2g(s[j+2], s[j+1], s[j+0]) end)

matrix.rgba.rgb = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2] = s[j+0], s[j+1], s[j+2] end)
matrix.bgra.bgr = matrix.rgba.rgb
matrix.argb.rgb = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2] = s[j+1], s[j+2], s[j+3] end)
matrix.abgr.bgr = matrix.argb.rgb
matrix.rgba.bgr = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2] = s[j+2], s[j+1], s[j+0] end)
matrix.bgra.rgb = matrix.rgba.bgr
matrix.argb.bgr = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2] = s[j+3], s[j+2], s[j+1] end)
matrix.abgr.rgb = matrix.argb.bgr

matrix.rgba.ga = eachpixel(function(d, i, s, j) d[i+0], d[i+1] = rgb2g(s[j+0], s[j+1], s[j+2]), s[j+3] end)
matrix.rgba.ag = eachpixel(function(d, i, s, j) d[i+1], d[i+0] = rgb2g(s[j+0], s[j+1], s[j+2]), s[j+3] end)
matrix.bgra.ga = eachpixel(function(d, i, s, j) d[i+0], d[i+1] = rgb2g(s[j+2], s[j+1], s[j+0]), s[j+3] end)
matrix.bgra.ag = eachpixel(function(d, i, s, j) d[i+1], d[i+0] = rgb2g(s[j+2], s[j+1], s[j+0]), s[j+3] end)
matrix.argb.ga = eachpixel(function(d, i, s, j) d[i+0], d[i+1] = rgb2g(s[j+1], s[j+2], s[j+3]), s[j+0] end)
matrix.argb.ag = eachpixel(function(d, i, s, j) d[i+1], d[i+0] = rgb2g(s[j+1], s[j+2], s[j+3]), s[j+0] end)
matrix.abgr.ga = eachpixel(function(d, i, s, j) d[i+0], d[i+1] = rgb2g(s[j+3], s[j+2], s[j+1]), s[j+0] end)
matrix.abgr.ag = eachpixel(function(d, i, s, j) d[i+1], d[i+0] = rgb2g(s[j+3], s[j+2], s[j+1]), s[j+0] end)

matrix.rgbx.ga = eachpixel(function(d, i, s, j) d[i+0], d[i+1] = rgb2g(s[j+0], s[j+1], s[j+2]), 0xff end)
matrix.rgbx.ag = eachpixel(function(d, i, s, j) d[i+1], d[i+0] = rgb2g(s[j+0], s[j+1], s[j+2]), 0xff end)
matrix.bgrx.ga = eachpixel(function(d, i, s, j) d[i+0], d[i+1] = rgb2g(s[j+2], s[j+1], s[j+0]), 0xff end)
matrix.bgrx.ag = eachpixel(function(d, i, s, j) d[i+1], d[i+0] = rgb2g(s[j+2], s[j+1], s[j+0]), 0xff end)
matrix.xrgb.ga = eachpixel(function(d, i, s, j) d[i+0], d[i+1] = rgb2g(s[j+1], s[j+2], s[j+3]), 0xff end)
matrix.xrgb.ag = eachpixel(function(d, i, s, j) d[i+1], d[i+0] = rgb2g(s[j+1], s[j+2], s[j+3]), 0xff end)
matrix.xbgr.ga = eachpixel(function(d, i, s, j) d[i+0], d[i+1] = rgb2g(s[j+3], s[j+2], s[j+1]), 0xff end)
matrix.xbgr.ag = eachpixel(function(d, i, s, j) d[i+1], d[i+0] = rgb2g(s[j+3], s[j+2], s[j+1]), 0xff end)

matrix.rgba.g = eachpixel(function(d, i, s, j) d[i] = rgb2g(s[j+0], s[j+1], s[j+2]) end)
matrix.bgra.g = eachpixel(function(d, i, s, j) d[i] = rgb2g(s[j+2], s[j+1], s[j+0]) end)
matrix.argb.g = eachpixel(function(d, i, s, j) d[i] = rgb2g(s[j+1], s[j+2], s[j+3]) end)
matrix.abgr.g = eachpixel(function(d, i, s, j) d[i] = rgb2g(s[j+3], s[j+2], s[j+1]) end)

matrix.rgb.ga = eachpixel(function(d, i, s, j) d[i+0], d[i+1] = rgb2g(s[j+0], s[j+1], s[j+2]), 0xff end)
matrix.rgb.ag = eachpixel(function(d, i, s, j) d[i+1], d[i+0] = rgb2g(s[j+0], s[j+1], s[j+2]), 0xff end)
matrix.bgr.ga = eachpixel(function(d, i, s, j) d[i+0], d[i+1] = rgb2g(s[j+2], s[j+1], s[j+0]), 0xff end)
matrix.bgr.ag = eachpixel(function(d, i, s, j) d[i+1], d[i+0] = rgb2g(s[j+2], s[j+1], s[j+0]), 0xff end)

matrix.ga.g = eachpixel(function(d, i, s, j) d[i] = s[j+0] end)
matrix.ag.g = eachpixel(function(d, i, s, j) d[i] = s[j+1] end)

matrix.ga.rgb = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2] = s[j+0], s[j+0], s[j+0] end)
matrix.ga.bgr = matrix.ga.rgb
matrix.ag.rgb = eachpixel(function(d, i, s, j) d[i], d[i+1], d[i+2] = s[j+1], s[j+1], s[j+1] end)
matrix.ag.bgr = matrix.ag.rgb

local function inv_cmyk2rgb(c, m, y, k) return c * k / 255, m * k / 255, y * k / 255 end --from webkit

matrix.cmyk.rgb  = eachpixel(function(d, i, s, j) d[i+0], d[i+1], d[i+2] = inv_cmyk2rgb(s[j], s[j+1], s[j+2], s[j+3]) end)
matrix.cmyk.bgr  = eachpixel(function(d, i, s, j) d[i+2], d[i+1], d[i+0] = inv_cmyk2rgb(s[j], s[j+1], s[j+2], s[j+3]) end)
matrix.cmyk.rgba = eachpixel(function(d, i, s, j) d[i+0], d[i+1], d[i+2] = inv_cmyk2rgb(s[j], s[j+1], s[j+2], s[j+3]); d[i+3] = 0xff end)
matrix.cmyk.bgra = eachpixel(function(d, i, s, j) d[i+2], d[i+1], d[i+0] = inv_cmyk2rgb(s[j], s[j+1], s[j+2], s[j+3]); d[i+3] = 0xff end)
matrix.cmyk.argb = eachpixel(function(d, i, s, j) d[i+1], d[i+2], d[i+3] = inv_cmyk2rgb(s[j], s[j+1], s[j+2], s[j+3]); d[i+0] = 0xff end)
matrix.cmyk.abgr = eachpixel(function(d, i, s, j) d[i+3], d[i+2], d[i+1] = inv_cmyk2rgb(s[j], s[j+1], s[j+2], s[j+3]); d[i+0] = 0xff end)
matrix.cmyk.g = eachpixel(function(d, i, s, j) d[i] = rgb2g(inv_cmyk2rgb(s[j], s[j+1], s[j+2], s[j+3])) end)
matrix.cmyk.ga = eachpixel(function(d, i, s, j) d[i+0], d[i+1] = rgb2g(inv_cmyk2rgb(s[j], s[j+1], s[j+2], s[j+3])), 0xff end)
matrix.cmyk.ag = eachpixel(function(d, i, s, j) d[i+1], d[i+0] = rgb2g(inv_cmyk2rgb(s[j], s[j+1], s[j+2], s[j+3])), 0xff end)

--conversions to rgbx are the same as conversions to rgba
for src,t in pairs(matrix) do
	local dt = {}
	for dst,f in pairs(t) do
		if dst == 'rgba' or dst == 'bgra' or dst == 'argb' or dst == 'abgr' then
			dt[dst:gsub('a', 'x')] = f
		end
	end
	for dst,f in pairs(dt) do
		t[dst] = f
	end
end

--conversions from rgbx to formats without an alpha channel are the same as conversions from rgba
for src,t in pairs(matrix) do
	local dt = {}
	if src == 'rgba' or src == 'bgra' or src == 'argb' or src == 'abgr' then
		for dst,f in pairs(t) do
			'rgba' or dst == 'bgra' or dst == 'argb' or dst == 'abgr'

			if dst == 'rgba' or dst == 'bgra' or dst == 'argb' or dst == 'abgr' then
				dt[dst:gsub('a', 'x')] = f
			end
		end
	for dst,f in pairs(dt) do
		t[dst] = f
	end
end

--conversions from rgbx to formats with an alpha channel must set 0xff in the alpha channel

matrix.rgbx.g = eachpixel(function(d, i, s, j) end)
matrix.rgbx.ga

--frontend

local ffi = require'ffi'
local bit = require'bit'

local function pad_stride(stride) --increase stride to the next number divisible by 4
	return bit.band(stride + 3, bit.bnot(3))
end

local function supported(src, dst)
	return src == dst or (matrix[src] and matrix[src][dst] and true or false)
end

local function convert(src, fmt, opt)

	--see if there's anything to convert. if not, return the source image.
	if src.pixel == fmt.pixel
		and src.stride == fmt.stride
		and src.orientation == fmt.orientation
	then
		return src
	end

	local dst = {}
	for k,v in pairs(src) do dst[k] = v end --all image info gets copied; TODO: deepcopy
	dst.pixel = fmt.pixel
	dst.stride = fmt.stride
	dst.orientation = fmt.orientation

	--check consistency of the input
	--NOTE: we support unknown pixel formats as long as #pixel == pixel size in bytes
	assert(src.size == src.h * src.stride)
	assert(src.stride >= src.w * #src.pixel)
	assert(fmt.stride >= src.w * #fmt.pixel)
	assert(src.orientation == 'top_down' or src.orientation == 'bottom_up')
	assert(fmt.orientation == 'top_down' or fmt.orientation == 'bottom_up')
	assert(supported(src.pixel, fmt.pixel))

	--see if there's a dest. buffer, or we can overwrite src. or we need to alloc. one
	if opt and opt.data then
		assert(opt.size >= src.h * fmt.stride)
		dst.size = opt.size
		dst.data = opt.data
	elseif (opt and opt.force_copy)
		or src.stride ~= fmt.stride --diff. buffer size
		or src.orientation ~= fmt.orientation --needs flippin'
		or #fmt.pixel > #src.pixel --bigger pixel, even if same row size
	then
		dst.size = src.h * fmt.stride
		dst.data = ffi.new('uint8_t[?]', dst.size)
	end

	--see if we need a pixel conversion or just flipping and/or changing stride
	local operation = src.pixel == fmt.pixel and copy_rows or matrix[src.pixel][fmt.pixel]

	--print(src.pixel, fmt.pixel, src.h, src.w * src.h * #src.pixel, ffi.sizeof(dst.data))
	operation(src, dst, 0, src.h - 1)

	--end
	return dst
end

local preferred_formats = {
	g = {'ga', 'ag', 'rgb', 'bgr', 'rgba', 'bgra', 'argb', 'abgr'},
	ga = {'ag', 'rgba', 'bgra', 'argb', 'abgr', 'rgb', 'bgr', 'g'},
	ag = {'ga', 'rgba', 'bgra', 'argb', 'abgr', 'rgb', 'bgr', 'g'},
	rgb = {'bgr', 'rgba', 'bgra', 'argb', 'abgr', 'g', 'ga', 'ag'},
	bgr = {'rgb', 'rgba', 'bgra', 'argb', 'abgr', 'g', 'ga', 'ag'},
	rgba = {'bgra', 'argb', 'abgr', 'rgb', 'bgr', 'ga', 'ag', 'g'},
	bgra = {'rgba', 'argb', 'abgr', 'rgb', 'bgr', 'ga', 'ag', 'g'},
	argb = {'rgba', 'bgra', 'abgr', 'rgb', 'bgr', 'ga', 'ag', 'g'},
	abgr = {'rgba', 'bgra', 'argb', 'rgb', 'bgr', 'ga', 'ag', 'g'},
	cmyk = {'rgb', 'bgr', 'rgba', 'bgra', 'argb', 'abgr', 'g', 'ga', 'ag'},
}

--given current orientation of an image and an accept table, choose the best accepted orientation.
local function best_orientation(orientation, accept)
	return
		(not accept or (accept.top_down == nil and accept.bottom_up == nil)) and orientation --no preference, keep it
		or accept[orientation] and orientation --same as source, keep it
		or accept.top_down and 'top_down'
		or accept.bottom_up and 'bottom_up'
		or error('invalid orientation')
end

local function best_format(src, accept)
	local fmt = {}
	assert(src.stride)
	fmt.stride = accept and accept.padded and pad_stride(src.stride) or src.stride
	assert(src.orientation == 'top_down' or src.orientation == 'bottom_up')
	fmt.orientation = best_orientation(src.orientation, accept)
	assert(src.pixel)
	if not accept or accept[src.pixel] then --source pixel format accepted, keep it, even if unknown
		fmt.pixel = src.pixel
		return fmt
	elseif preferred_formats[src.pixel] then --known source pixel format, find best destination format
		for _,pixel in ipairs(preferred_formats[src.pixel]) do
			if accept[pixel] and matrix[src.pixel][pixel] then --we must have an implementation for it
				fmt.pixel = pixel
				fmt.stride = src.w * #pixel
				if accept.padded then
					fmt.stride = pad_stride(fmt.stride)
				end
				return fmt
			end
		end
	end
end

local function convert_best(src, accept, opt)
	local fmt = best_format(src, accept)

	if not fmt then
		local t = {}; for k,v in pairs(accept) do t[#t+1] = v ~= false and k or nil end
		error(string.format('cannot convert from (%s, %s) to (%s)',
									src.pixel, src.orientation, table.concat(t, ', ')))
	end

	return convert(src, fmt, opt)
end

if not ... then require'bmpconv_test' end

return {
	pad_stride = pad_stride,
	convert = convert,
	best_format = best_format,
	convert_best = convert_best,
	supported = supported,
	preferred_formats = preferred_formats,
	matrix = matrix,
}

