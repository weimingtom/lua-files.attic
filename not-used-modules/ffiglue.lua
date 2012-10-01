local ffi = require'ffi'

local M = {}

ffi.cdef[[
typedef struct FILE_ FILE;
size_t fread (void *ptr, size_t size, size_t count, FILE * stream);
]]

function M.readfile(file, mode)
	local f, err = io.open(file, mode == 't' and 'r' or 'rb')
	if not f then return nil,err end
	local sz = ffi.C.fread()
end

return M

