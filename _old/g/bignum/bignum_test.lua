
package.path = [[..\lua\?.lua;]]..package.path

local Bignum = (require 'fbclient.bignum').Bignum

local function asserteq(x,y)
	assert(x==y,('%s ~= %s'):format(tostring(x),tostring(y)))
end

local n = Bignum(1e15-1)
asserteq(tostring(n),('9'):rep(15))

local n = Bignum(1e15)
asserteq(tostring(n),'1'..('0'):rep(15))

