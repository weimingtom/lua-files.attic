--[[
logging:
	printf(format,...)

i/o:
	exists(filename) -> filename
	file(filename[, mode]) -> s
	save(filename, s[, mode])

]]

function printf(...)
	local function pass(...) io.write(string.format(...)) end
	local status, result = pcall(pass,...)
	if not status then error(result,2) end
end


--exists 'readme' or exists 'readme.txt' or exists 'readme.md'
function exists(filename)
	local f = io.open(filename)
	if not f then return nil end
	f:close()
	return filename
end

function file(filename, mode)
	local f,err = io.open(filename, 'r'..(mode or ''))
	if not f then return nil,err end
	local res,err = f:read('*a')
	f:close()
	if not res then return nil,err end
	return res
end

function save(filename, s, mode)
	local f = assert(io.open(filename, 'w'..(mode or '')))
	local ok,err = f:write(s)
	f:close()
	assert(ok,err)
end

if not ... then
	save('temp567', 'stuff')
	test(file('temp567'), 'stuff')
	test({file('temp567123')}, {nil,'Not found'})
	assert(os.remove('temp567'))
end

function exec(cmd)
	local f,err = io.popen(cmd)
	if not f then return nil,err end
	local s = f:read("*a")
	f:close()
	return s
end

function io.pipelines(cmd)
	local f,err = io.popen(cmd)
	return f and function()
		local s = f:read('*l')
		if not s then p:close() end
		return s
	end,err
end

function die(code,...)
	if type(code) == 'number' then
		io.stderr:write(string.format(...))
		os.exit(code)
	else
		io.stderr:write(string.format(code,...))
		os.exit(-1)
	end
end
