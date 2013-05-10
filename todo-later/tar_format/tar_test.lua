local tar = require'tar'

local function readsize_function(file)
	local f = assert(io.open(file, 'rb'))
	return function(size)
		local s = f:read(size)
		if not s or #s < size then
			f:close()
		else
			return s
		end
	end
end

local n = 0
tar.parse(readsize_function'media/tar/test1.tar',
	function(header, content)
		n = n + 1
		pp(n, header, content)
		if n == 1 then
			assert(header.name == 'dir1/')
			assert(header.typeflag == 'directory')
			assert(header.mode == tonumber('755', 8))
			assert(header.size == 0)
		end
		if n == 2 then
			assert(header.name == 'dir1/file1.txt')
			assert(header.typeflag == 'file')
			assert(header.mode == tonumber('644', 8))
			assert(content == 'file1 contents\n')
		end
		if n == 3 then
			assert(header.name == 'dir1/file2.txt')
			assert(header.typeflag == 'file')
			assert(header.mode == tonumber('644', 8))
			assert(content == 'file2 contents\n')
		end
	end)
