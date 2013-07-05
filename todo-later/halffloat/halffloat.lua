--halffloat binding
local ffi = require'ffi'
local C = ffi.load'halffloat'

ffi.cdef[[
void halffloat_init();
uint16_t halffloat_compress(float value);
float halffloat_decompress(uint16_t value);
]]

C.halffloat_init()

if not ... then require'halffloat_test' end

return {
	compress = C.halffloat_compress,
	decompress = C.halffloat_decompress,
}
