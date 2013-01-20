require'unit'
test({parseresponseline'HTTP/1.1 404 Not Found'}, {'1.1', '404', 'Not Found'})
test({parseresponseline'HTTP/1.1 404'}, {'1.1', '404', ''})
test(parseheadername' some-HEADER-Even \n\r\t invalid ', 'some_header_even_invalid')
test(parseheadervalue'\n\rsome\tHEADER\tValue \n\r\t', 'some HEADER Value')
--[[
local readline = ('multivalue: \r5 \r\nmultivalue: 2\t ,\n 7 \r\nmultivalue: 1\r\n\r\n'):gmatch('(.-)\r\n')
test(readheaders(readline), {multivalue = {'5','2','7', '1'}})
local readline = ('multiline: 5\r\n\t,2,\r\n 7,\n1\r\n\r\n'):gmatch('(.-)\r\n')
test(readheaders(readline, {}), {multiline = {'5','2','7','1'}})
local readline = ('empty:\r\n'):gmatch('(.-)\r\n')
test(readheaders(readline, {}), {empty = {''}})
local readline = ('twiceempty:\r\ntwiceempty:\r\n'):gmatch('(.-)\r\n')
test(readheaders(readline, {}), {twiceempty = {'',''}})
]]
--format
test(formatrequestline('post', '/dude?wazup'), 'POST /dude?wazup HTTP/1.1\r\n')
test(foldheadervalues{'  a ','   b'}, 'a,b')
test(formatheaders({multiple = {'  c  ', 'b', '  a'}}, true),
					'Multiple: c,b,a\r\n\r\n')
test(formatheaders
	{CONTENT_LENGTH='  100  ', connection=' Close ', Host='www.dude.com\n'},
	'Connection: Close\r\nContent-Length: 100\r\nHost: www.dude.com\r\n\r\n')

------------------------------------------------------------------------------

local function connect(host, port, loop)
	local skt,err = loop.connect(host, port)
	if skt == nil then return nil,err end
	return sktloop.wrap(skt, loop)
end


local function adjustproxy(reqt)
	local proxy = reqt.proxy
	if proxy then
		proxy = url.parse(proxy)
		return proxy.host, proxy.port or 3128
	else
		return reqt.host, reqt.port
	end
end

local default = { port = 80, path = '/', scheme = 'http' }

local function adjustrequest(reqt)
	-- parse url if provided
	local nreqt = reqt.url and url.parse(reqt.url, default) or {}
	-- explicit components override url
	for k,v in pairs(reqt) do nreqt[k] = v end
	assert(nreqt.host, 'invalid host "' .. tostring(nreqt.host) .. '"')
	-- compute uri if user hasn't overriden
	nreqt.uri = reqt.uri or adjusturi(nreqt)
	-- ajust host and port if there is a proxy
	nreqt.host, nreqt.port = adjustproxy(nreqt)
	-- adjust headers in request
	nreqt.headers = adjustheaders(nreqt)
	return nreqt
end


local function sendrequest(reqt)
	sendrequestline()
	sendheaders()
	sendbody()
end

local function test()
	local loop = sktloop.newloop()
	loop.newthread(getpage, {url='http://google.com', body='hello'}, say, nil, loop)
	loop.loop()
end

