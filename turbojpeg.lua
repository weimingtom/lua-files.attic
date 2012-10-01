local glue = require'glue'
local ffi = require'ffi'
local bit = require'bit'
require'turbojpeg_h'
local C = ffi.load'libjpeg-62'
local M = glue.inherit({}, C)

M.tjMCUWidth = {8, 16, 16, 8, 8}
M.tjMCUHeight = {8, 8, 16, 8, 16}
M.tjRedOffset = {0, 2, 0, 2, 3, 1, 0, 0, 2, 3, 1}
M.tjGreenOffset = {1, 1, 1, 1, 2, 2, 0, 1, 1, 2, 2}
M.tjBlueOffset = {2, 0, 2, 0, 1, 3, 0, 2, 0, 1, 3}
M.tjPixelSize = {3, 3, 4, 4, 4, 4, 1, 4, 4, 4, 4}

function M.TJPAD(width) return bit.band(width+3,bit.bnot(3)) end
function M.TJSCALED(dimension, scalingFactor)
	return (dimension + scalingFactor.denom - 1) / scalingFactor.denom
end

function M.GetErrorStr()
	return ffi.string(C.tjGetErrorStr())
end

local function checkh(h)
	if h ~= nil then return h end
	error(string.format('TurboJPEG Error: %s', GetErrorStr()), 2)
end

function M.InitCompress()
	return checkh(C.tjInitCompress())
end

function M.InitDecompress()
	return checkh(C.tjInitDecompress())
end

if not ... then
local d = M.InitDecompress()
end

return M
