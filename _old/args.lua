

--format: [arg<delim>][<delim>arg]arg<delim>arg[<delim>arg[<delim>arg]]
function args(format, s)
	for s in s:gmatch('(%b%[%])') do
		print(s)
	end
end

for s1,s2,s3 in ('aa[x[xa][xb[xba]]]xx[y][z]'):gmatch('([^%[]*)(%b[])([^%[]*)') do print(s1,s2,s3) end
--for s in ('x[a]b'):gmatch('(%b[])') do print(s) end

--[[
if not ... then
	require'unit'
	authority = '[user[:pass]@]host'
	query = 'var[=val][&<query>]'
	segment = 'segment[;params]'
	path = '<segment>[/<path>]'
	uri = '[scheme:]((//<authority>[/<path>])|<path>)[?<query>][#fragment]'
	ptest(args(uri, ''), {})
	ptest(args(uri, ':'), {scheme=''})
	ptest(args(uri, 's:'), {scheme='s'})
	ptest(args(uri, '//'), {host=''})
	ptest(args(uri, '//:'), {host=':'})
	ptest(args(uri, '//@'), {user='',host=''})
	ptest(args(uri, '//:@'), {user='',pass='',host=''})
	ptest(args(uri, '//h'), {host='h'})
	ptest(args(uri, '//u@h'), {user='u',host='h'})
	ptest(args(uri, '//u:@h'), {user='u',pass='',host='h'})
	ptest(args(uri, '//:p@h'), {user='',pass='p',host='h'})
	ptest(args(uri, '/'), {path='/'})
	ptest(args(uri, ':/'), {scheme='',path='/'})
	ptest(args(uri, 's:'), {scheme='s',path=''})
	ptest(args(uri, ':relative/path'), {scheme='',path='relative/path'})
	ptest(args(uri, '://:@?#'), {scheme='',user='',pass='',host='',path='',query='',fragment=''})
	ptest(args(uri, '://:@/?#'), {scheme='',user='',pass='',host='',path='/',query='',fragment=''})
	ptest(args(uri, 's://u:p@h/p?q#f'), {scheme='s',user='u',pass='p',host='h',path='p',query='q',fragment='f'})
	ptest(args(uri, 'http://user:pass@host/a/b?query#fragment'),
					{scheme='http',user='user',pass='pass',host='host',path='a/b',query='query',fragment='fragment'})
end
]]
