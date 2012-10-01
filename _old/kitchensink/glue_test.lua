
require'glue'
require'unit'

local function check(...)
	local ok,err = pcall(argcheck,...)
	return err
end
test(check(1,{},'table'),{})
local opts = {a=34,b=56, c=12, d='x', e=false}
test(check(1,'a',opts),34)
test(check(1,'aaaaaaaaaaaaaaaa',opts),34)
test(check(1,'aaaaaaaaaaaaaaaaa',opts),34)

local function f(t,x)
	argcheck(1,t,'table')
	x = argcheck(2,x,tonumber,'number expected, got %s',type(x))
end
test(pcall(f,{},'123'),true)
local ok,err = pcall(f)
test(ok,false)
testmatch(err,'bad argument #1 to .- %(table expected, got nil%)')
local ok,err = pcall(f,{},'xx')
test(ok,false)
testmatch(err,'bad argument #2 to .- %(number expected, got string%)')
local function somefunc() argerror(2,'somerr') end
local ok,err = pcall(function() somefunc() end)
test(ok,false)
testmatch(err,'bad argument #2 to .- %(somerr%)')
