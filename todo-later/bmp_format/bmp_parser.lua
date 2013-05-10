--bmp file parser.

--parse a 16-bit WORD from the binary string
local function word(s, offset)
	local lo = s:byte(offset)
	local hi = s:byte(offset + 1)
	return hi*256 + lo
end

--parse a 32-bit DWORD from the binary string
local function dword(s, offset)
	local lo = word(s, offset)
	local hi = word(s, offset + 2)
	return hi*65536 + lo
end

local function parse_header(block) --34 bytes needed
	-- BITMAPFILEHEADER (14 bytes long)
	assert(word(header, 1) == 0x4D42, 'not a BMP file')
	local bits_offset = word(header, offset + 10)
	-- BITMAPINFOHEADER
	offset = 15 -- start from the 15-th byte
	local width       = dword(header, offset + 4)
	local height      = dword(header, offset + 8)
	local bpp         =  word(header, offset + 14) --1, 2, 4, 8, 16, 24, 32
	local compression = dword(header, offset + 16) --0 = none, 1 = RLE-8, 2 = RLE-4, 3 = Huffman, 4 = JPEG/RLE-24, 5 = PNG
end

-- Parse the bits of an open BMP file
parse = function(file, bits, chunk, r, g, b)
	r = r or {}
	g = g or {}
	b = b or {}
	local bpp = bits/8
	local bytes = file:read(chunk*bpp) -- todo: "*a"
	if bytes == nil then
		-- end of file
		file:close()
		return
	end
	for i = 0, chunk - 1 do
		local o = i*bpp
		insert(r, byte(bytes, o + 3))
		insert(g, byte(bytes, o + 2))
		insert(b, byte(bytes, o + 1))
	end
	return r, g, b
end
