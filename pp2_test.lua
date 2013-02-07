require'pp2'
require'unit'

local t = {
	1,2,'a','b','12','34',true,false,-1/0,1/0,0/0,5/6,
	a=1,b=2,[0]='1',[false]=1,[true]=2,[1/0]='a',[-1/0]='b',['']=1,
	x={y={z={a={b={}}}}},
	--coroutine.create(function() end),
	--io.stdin,
}
local cyclic1 = {}; cyclic1.cycle = cyclic1
local cyclic2 = {}; cyclic2[cyclic2] = 'cycle'
local cyclic3 = {}; cyclic3.cycle1 = {cycle2 = {cycle3 = cyclic3}}
local cyclic4 = {}; cyclic4[{[{[cyclic4] = 'cycle3'}] = 'cycle2'}] = 'cycle1'
local cyclic5 = {}; cyclic5[cyclic5] = cyclic5
local cyclic6 = {{cyclic1}}

local t = {
	cyclic3,
	{
		--tree indent
		a={b={c={d={e={f={}}}}}},
		[{[{[{[{[{[{}]='f'}]='e'}]='d'}]='c'}]='b'}]='a',
		{},
	},
	{
		--compact indent, maxcount = 1
		a={'a1',a2={'a21',a22={'a221', 'a222','a223'},'a23'},'a3'},
		b=1,
		c={'aaa\nxxx\n\nyyy','bbb\n\nyyy\nxxx','ccc','ddd','eee'},
	},
	{
		--sort pairs: same key repr., dif. values
		[{a=1,b=2}] = {'b','a'},
		[{a=1,b=2}] = {'b','a'},
	},
	{
		--sort pairs: dif. key repr., same values
		[{a=1,b=2}] = 'a',
		[{a=0,b=2}] = 'a',
	},
	{
		--sort pairs: type order
		'c','b','a',[true]='x',[false]='x',['a']='x',['b']='x',
		['a/a']='x',['a/b']='x',
	},
	{
		--implicit keys and sorted pairs
		[-1]=-1,[0]=0,'a','b',[4]=4,
		a=1,b=2,
	},
	--cycles
	cyclic1, cyclic2, cyclic3, cyclic4, cyclic5, cyclic6,
}
for _,t in ipairs(t) do
	local opt = {maxdepth=10}
	s = pformat(t, opt)
	print(s)
	--print(pformat(loadstring('return '..s)(), opt))
end

--[=[
test(tostr(write_string,'\1 0',"'"),[['\001 0']])
test(tostr(write_string,'\0010',"'"),[['\0010']])
test(tostr(write_string,'\n\r\t\0\255\\\'',"'"),[['\n\r\t\000\255\\\'']])
test(tostrl(write_string_split,'\n\r\t\0\255\\\'',"'"),
										{[['\n\r'..]],[['\t\000\255\\\'']]})
test(tostrl(write_string_split,'abc\n\r\nxyz',"'"),{"'abc\\n\\r\\n'..","'xyz'"})
test(tostrl(write_string_split,'abc\rxyz\n',"'"),{"'abc\\r'..","'xyz\\n'"})
test(tostrl(write_string_split,'abc\r',"'"),{"'abc\\r'"})
test(tostrl(write_string_split,'abc',"'"),{"'abc'"})
test(tostrl(write_string_split,'',"'"),{"''"})
test(tostrl(write_string_split,'\n\r',"'"),{"'\\n\\r'"})

test(tostr(write_number,0/0),'0/0')
test(tostr(write_number,1/0),'1/0')
test(tostr(write_number,-1/0),'-1/0')
test(tostr(write_number,-5e10),'-50000000000')
test(tostr(write_number,5/6),'0.83333333333333337')


test(is_identifier'nil',false)
test(is_identifier'true',false)
test(is_identifier'goto',false)
test(is_identifier'IamWeasel',true)
test(is_identifier'i R baboon',false)
test(is_identifier'9i',false)
test(is_identifier'_9',true)
test(is_identifier'_',true)

test(formatenum(('abc,xyz,'):gmatch'(.-),',', '),{'abc, xyz'})
test(formatenum(('abc,xyz,'):gmatch'(.-),',', ',2),{'abc, xyz'})
test(formatenum(('abc,xyz,'):gmatch'(.-),',', ',1),{'abc, ','xyz'})
test(formatenum(('abc,xyz,'):gmatch'(.-),',', ',nil,1),{'abc, ','xyz'})
test(formatenum(('abcxy,123,'):gmatch'(.-),',', ',nil,5),{'abcxy, ','123'})
test(formatenum(('a,b,12345,d,e,'):gmatch'(.-),',', ',nil,6),{'a, b, ','12345, ','d, e'})
test(formatenum(('a,'):gmatch'(.-),',', ',1,1),{'a'})
test(formatenum(('a,'):gmatch'(.-),',', ',1,1),{'a'})

test(tostrl(write_key,'id'),{'id'})
test(tostrl(write_key,'true'),{"['true']"})
test(tostrl(write_key,'non-id'),{"['non-id']"})
test(tostrl(write_key,123),{'[123]'})
test(tostrl(write_key,false),{'[false]'})
]=]
