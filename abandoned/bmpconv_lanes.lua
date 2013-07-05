
local function split_range(x1, x2, n) --split a numeric range in N equal ranges
	--
end

local function split_work(src, dst, operation, threads) --split operation to multiple lanes
	threads = math.min(threads, src.h)
	local lanes = require'lanes'.configure()

	local src_data = src.data
	local dst_data = dst.data
	src.data = tonumber(ffi.cast('uint32_t', ffi.cast('void*', src.data))) --pointers can only reach lanes as numbers
	dst.data = tonumber(ffi.cast('uint32_t', ffi.cast('void*', dst.data)))

	local linda = lanes.linda()
	local op_thread = lanes.gen(operation)
	local tt = {}
	local next_range = split_range(0, src.h-1, threads)
	for i=1,threads do
		local h1, h2 = next_range()
		tt[#tt+1] = op_thread(src, dst, h1, h2) --each thread will work on a separate section of the buffer
	end
	for _,thread in ipairs(tt) do --TODO: wait for threads
		local _ = thread[1]
	end

	src.data = src_data
	dst.data = dst_data
end

local MIN_SIZE_PER_THREAD = 1024 * 1024 --1MB/thread to make it worth to create one


--function convert() ...

	--[[
	if opt and opt.threads and opt.threads > 1 then
		local threads = math.min(opt.threads, math.floor(src.size / MIN_SIZE_PER_THREAD))
		and src.h > opt.threads
		and src.size > MIN_SIZE_PER_THREAD * 2 --it's worth the overhead of creating threads
	then
		split_work(src, dst, operation, math.min(opt.threads - 1))
	else
	]]

