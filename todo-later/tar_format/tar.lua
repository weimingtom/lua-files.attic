--tar parsing and formatting module. parsing part adapted from luarocks. written by Cosmin Apreutesei.
--file format here: http://en.wikipedia.org/wiki/Tar_(computing)

local glue = require'glue'

local typeflags = {
	file       = '0',
	link       = '1',
	symlink    = '2', -- 'reserved' in POSIX, 'symlink' in GNU
	character  = '3',
	block      = '4',
	directory  = '5',
	fifo       = '6',
	contiguous = '7', -- 'reserved' in POSIX, 'contiguous' in GNU
	global_ex_header    = 'g',
	next_file_ex_header = 'x',
	long_name           = 'L',
	long_linkname       = 'K',
}

local typeflag_names = glue.index(typeflags)
typeflag_names['\0'] = 'file'

-- parsing

local function nullterm(s) --null terminated non-empty string
	return s:match('^[^%z]+')
end

local function octal_tonumber(s)
	return s and tonumber(s, 8)
end

local function checksum(block)
	local sum = 256
	for i = 1,148 do
		sum = sum + block:byte(i)
	end
	for i = 157,500 do
		sum = sum + block:byte(i)
	end
	return sum
end

local function zero_filled(block)
	for i=1,#block do
		if block:byte(i) ~= 0 then
			return false
		end
	end
	return true
end

local function parse_header_block(block)
	local header = {}
	header.name     = nullterm(block:sub(1,100))
	header.mode     = octal_tonumber(nullterm(block:sub(101,108)))
	header.uid      = octal_tonumber(nullterm(block:sub(109,116)))
	header.gid      = octal_tonumber(nullterm(block:sub(117,124)))
	header.size     = octal_tonumber(nullterm(block:sub(125,136)))
	header.mtime    = octal_tonumber(nullterm(block:sub(137,148)))
	header.checksum = octal_tonumber(nullterm(block:sub(149,156)))
	local typeflag  = block:sub(157,157)
	header.type     = typeflag_names[typeflag] or typeflag
	header.linkname = nullterm(block:sub(158,257))
	header.magic    = nullterm(block:sub(258,263))
	header.version  = block:sub(264,265)
	header.uname    = nullterm(block:sub(266,297))
	header.gname    = nullterm(block:sub(298,329))
	header.devmajor = octal_tonumber(nullterm(block:sub(330,337)))
	header.devminor = octal_tonumber(nullterm(block:sub(338,345)))
	header.prefix   = nullterm(block:sub(346,500))
	assert(header.magic == 'ustar' or header.magic == 'ustar ', 'invalid header magic')
	assert(header.version == '00' or header.version == ' \0', 'unknown version')
	assert(checksum(block) == header.checksum, 'invalid header checksum')
	return header
end

local blocksize = 512

local function padding_size(filesize)
	return math.ceil(filesize / blocksize) * blocksize - filesize
end

local function read_data_blocks(header, readsize, skipsize)
	local data = readsize(header.size)
	skipsize(padding_size(header.size))
	return data
end

local function skip_data_blocks(header, skipsize)
	skipsize(header.size + padding_size(header.size))
end

local function read_header_blocks(readsize, skipsize)
	local long_name, long_linkname
	while true do
		local block = readsize(blocksize)
		if zero_filled(block) then return end

		local header = parse_header_block(block)

		if header.typeflag == 'long_name' then
			long_name = nullterm(read_data_blocks(header, readsize, skipsize))
		elseif header.typeflag == 'long_linkname' then
			long_linkname = nullterm(read_data_blocks(header, readsize, skipsize))
		else
			if long_name then
				header.name = long_name
			end
			if long_linkname then
				header.linkname = long_linkname
			end
			return header
		end
	end
end

local function data_blocks_reader(header, readsize, skipsize, readtosize)
	local read = readtosize(header.size)
	return function()
		local s = read()
		if not s then
			skipsize(padding_size(header.size))
		end
		return s
	end
end

-- formatting ------------------------------------------------------------------------------------------------------------

local ffi = require'ffi'

local function write_string(block, offset1, offset2, s)
	if not s or #s == 0 then return end
	assert(#s <= offset2 - offset1 + 1, 'string too long')
	ffi.copy(block + offset - 1, s, #s)
end

local function write_octal(block, offset1, offset2, n)
	local s = n and string.format('%o', n) or ''
	write_string(block, offset1, offset2, s)
end

local function block_checksum(block)
	local sum = 256
	for i = 1,148 do
		sum = sum + block[i-1]
	end
	for i = 157,500 do
		sum = sum + block[i-1]
	end
	return sum
end

local function write_header_block(header, block, write)
	ffi.fill(block, blocksize)
	write_string( block,   1, 100, t.name)
	write_octal(  block, 101, 108, t.mode)
	write_octal(  block, 109, 116, t.gid)
	write_octal(  block, 125, 136, t.size or 0)
	write_octal(  block, 137, 148, t.mtime)
	write_string( block, 157, 157, typeflags[t.type or 'file'] or t.type)
	write_string( block, 158, 257, t.linkname)
	write_string( block, 258, 263, 'ustar')
	write_string( block, 264, 265, '00')
	write_string( block, 266, 297, t.uname)
	write_string( block, 298, 329, t.gname)
	write_octal(  block, 330, 337, t.devmajor)
	write_octal(  block, 338, 345, t.devminor)
	write_string( block, 346, 500, t.prefix)
	write_octal(  block, 149, 156, block_checksum(block))
	write(block, blocksize)
end

local function write_block_padding(filesize, block, write)
	local size = padding_size(filesize)
	ffi.fill(block, size)
	write(block, size)
end

local function write_data_blocks_reader(read, block, write)
	local filesize = 0
	for data, size in read() do
		write(data, size)
		filesize = filesize + (size or #data)
	end
	write_block_padding(filesize, block, write)
end

local function write_data_blocks_string(s, block, write)
	write(s)
	write_block_padding(#s, block, write)
end

local function write_header_blocks(header, block, write)
	if header.name and #header.name > 100 or
		header.linkname and #header.linkname > 100
	then
		header = glue.update({}, header)
	end

	if #header.name > 100 then
		write_header_block({type = 'long_name', size = #header.name}, block, write)
		write_data_blocks_string(header.name, block, write)
		header.name = nil
	end

	if #header.linkname > 100 then
		write_header_block({type = 'long_linkname', size = #header.linkname}, block, write)
		write_data_blocks_string(header.linkname, block, write)
		header.linkname = nil
	end

	write_header_block(header, block, write)
end

local function write_file_blocks(header, file_data, block, write)
	write_header_blocks(header, block, write)
	if type(file_data) == 'string' then
		write_data_blocks_string(file_data, block, write)
	else
		write_data_blocks_reader(file_data, block, write)
	end
end

local function write_trailer_blocks(block, write)
	ffi.fill(block, blocksize)
	write(block, blocksize)
	write(block, blocksize)
end

local function writer(write)
	local block = ffi.new('uint8_t[?]', blocksize)
	local o = {}
	function (header, file_data)
		if header then
			write_file_blocks(header, file_data, block, write)
		else
			write_trailer_blocks(block, write)
		end
	end
	return o
end

local function file_writer(filename)
	local f = io.open(filename 'wb')
	writer(write)
end

-- file interface --------------------------------------------------------------------------------------------------------

local function open(filename, mode)
	mode = mode or 'r'
	assert(mode == 'r' or mode == 'w' or mode == 'a', 'invalid mode')
	local file = assert(io.open(filename, (mode == 'a' and 'r+' or mode)..'b'))

	--reader api

	local function readsize(size)
		local s = file:read(size)
		assert(#s == size, 'eof')
		return s
	end

	local function skipsize(size)
		file:seek(size)
	end

	local maxsize

	local function readtosize(size)
		maxsize = maxsize or 1024 * 1024 * 10 --read 10 MB at a time
		assert(maxsize > 0, 'invalid maxsize')
		return function()
			if size == 0 then return end
			local s = assert(file:read(math.min(size, maxsize)), 'eof')
			size = size - #s
			return s
		end
	end

	--writer api

	local function write(data, sz)
		if type(data) ~= 'string' then
			data = ffi.string(data, sz)
		end
		file:write(data)
	end

	--reading interface

	local header, eof

	local function next_entry()
		if eof then return end
		if header then
			skip_data_blocks(header, skipsize)
		end
		header = read_header_blocks(readsize, skipsize)
		if not header then eof = true end
		return header
	end

	local function rewind()
		header, eof = nil
		file:seek('set')
	end

	local function read_data()
		assert(header, 'eof')
		local data = read_data_blocks(header, readsize, skipsize)
		header = nil
		return data
	end

	local function data_reader(maxsize_)
		maxsize = maxsize_
		local reader = data_blocks_reader(header, readsize, skipsize, readtosize)
		header = nil
		return reader
	end

	--writing interface

	local block = ffi.new('uint8_t[?]', blocksize)

	local need_trailer

	local function close()
		if need_trailer then
			write_trailer_blocks(block, write)
		end
		file:close()
	end

	local function add_file(header)
		while next_entry() do end
		write_header_blocks(header, block, write)
	end

	local function write_data(data)
		write_file_blocks(header, data, block, write)
	end

	return {
		close = close,
		next = next_entry,
		rewind = rewind,
		read = read_data,
		reader = data_reader,
		write = write_data,
		add = add_file,
	}
end


if not ... then require'tar_test' end

return {
	parse = parse,
}
