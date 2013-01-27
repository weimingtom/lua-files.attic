local ffi = require'ffi'

local M = {}

ffi.cdef[[
typedef struct FILE_ FILE;
size_t fread (void *ptr, size_t size, size_t count, FILE * stream);
]]

local function readfile(file, mode)
	local f, err = io.open(file, mode == 't' and 'r' or 'rb')
	if not f then return nil,err end
	local sz = ffi.C.fread()
end

local function protected(type, base, offset, size) --from luajit ml (not tested)
	type = ffi.typeof(type)
	local bound = (size + 0ULL) / ffi.sizeof(type)
	local tptr = ffi.typeof("$ *", type)
	local wrap = ffi.metatype(ffi.typeof("struct { $ _ptr; }", tptr), {
		__index = function(w, idx)
			assert(idx < bound)
			return w._ptr[idx]
		end,
		__newindex = function(w, idx, val)
			assert(idx < bound)
			w._ptr[idx] = val
		end,
	})
	return wrap(ffi.cast(tptr, ffi.cast("uint8_t *", base) + offset))
end

return {
	readfile = readfile,
	protected = protected,
}

