--nanojpeg binding, see: http://keyj.emphy.de/nanojpeg/
--I modified nanojpeg and made a new binding for it.
local ffi = require'ffi'
local glue = require'glue'
local C = ffi.load'nanojpeg'

ffi.cdef[[

void njInit(void);
int njDecode(const void* jpeg, const int size);
int njGetWidth(void);
int njGetHeight(void);
int njIsColor(void);
unsigned char* njGetImage(void);
int njGetImageSize(void);
void njDone(void);
]]

local error_messages = {
	'Not a JPEG file',
	'Unsupported format',
	'Out of memory',
	'Internal error',
	'Syntax error',
}

local function load_(data, sz)
	return glue.fcall(function(finally)
		C.njInit()
		finally(C.njDone)
		local res = C.njDecode(data, sz)
		assert(res == 0, error_messages[res])
		local w = C.njGetWidth()
		local h = C.njGetHeight()
		local iscolor = C.njIsColor() == 1
		local pixel_format = iscolor and 'rgb' or 'g'
		local rowsize = w * (iscolor and 3 or 1)
		local sz = C.njGetImageSize()
		local tmpdata = C.njGetImage() --pointer to RGB888[] or G8[]
		local data = ffi.new('uint8_t[?]', sz)
		ffi.copy(data, tmpdata, sz)
		return {
			w = w, h = h,
			data = data,
			size = sz,
			format = {
				pixel = pixel_format,
				rows = 'top_down',
				rowsize = rowsize,
			},
		}
	end)
end

local function load(t)
	if t.string then
		return load_(t.string, #t.string)
	elseif t.cdata then
		return load_(t.cdata, t.size)
	elseif t.path then
		local data = assert(glue.readfile(t.path))
		return load_(data, #data)
	else
		error'unspecified data source: path, string or cdata expected'
	end
end

if not ... then require'nanojpeg_test' end

return {
	load = load,
	C = C,
}

