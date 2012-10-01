--[=[
	table of operators.

	op[symbol]
	op.name

	isfarg(v)
	farg(v)

]=]

local math=
	  math

local iscallable=require('test').iscallable

local _G,M=_G,{}
setfenv(1,M)

op = {
	-- binary operators
	mod	= math.fmod,
	pow	= math.pow,
	add	= function(n,m) return n + m end,
	sub	= function(n,m) return n - m end,
	mul	= function(n,m) return n * m end,
	div	= function(n,m) return n / m end,
	gt	= function(n,m) return n > m end,
	lt	= function(n,m) return n < m end,
	eq	= function(n,m) return n == m end,
	le	= function(n,m) return n <= m end,
	ge	= function(n,m) return n >= m end,
	ne	= function(n,m) return n ~= m end,
	-- unnary operators
	neg	= function(x) return not x end,
	len	= function(x) return #x end,
	inc	= function(n) return n+1 end,
	dec	= function(n) return n-1 end,
	double = function(n) return n^2 end,
	-- ternary operators
	cond = function(cond, e1, e2) if cond then return e1 else return e2 end end, -- no short-circuiting!
	-- returning two values
	divmod = math.modf,
}

op['%'] = op.mod
op['^'] = op.pow
op['+'] = op.add
op['-'] = op.sub
op['*'] = op.mul
op['/'] = op.div
op['>'] = op.gt
op['<'] = op.lt
op['==']= op.eq
op['<=']= op.le
op['>=']= op.ge
op['~=']= op.ne
op['not']=op.neg
op['#'] = op.len
op['++']= op.inc
op['--']= op.dec
op['^2']= op.double

function isfarg(v) return iscallable(v) or op[v] ~= nil end
function farg(v) if iscallable(v) then return v else return op[v] end end

if _G.__UNITTESTING then
	-- TODO
end

return M

