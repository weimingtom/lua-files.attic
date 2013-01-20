local ffi = require'ffi'
require'openvg_h'

local C = ffi.load'libAmanithVG'
local M = setmetatable({C = C}, {__index = C})

function M.vgGetString(...)
	return ffi.string(C.vgGetString(...))
end

if not ... then
setmetatable(_G, {__index = M})
print("Vendor: ", vgGetString(VG_VENDOR));
print("Renderer: ", vgGetString(VG_RENDERER));
print("Version: ", vgGetString(VG_VERSION));
print("Extensions: ", vgGetString(VG_EXTENSIONS));
end

return M
