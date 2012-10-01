local xmllpeg = require'xmllpeg'
local glue = require'glue'

local i=0
local function print1(...) print(('  '):rep(i).. ...) i=i+1 end
local function print2(...) i=i-1 print(('  '):rep(i)..'/'.. ...) end
local function printt(...) print(('  '):rep(i).. table.concat({...})) end
local function printa(k,v) printt(k,'=',v) end
local function printc(s)
	s = s:gsub('[\n\r]+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
	if s == '' then return end
	printt('"',s,'"')
end

xmllpeg.P{
	cdata = printc,
	attr = printa,
	start_tag = print1,
	end_tag = print2,
	end_start_tag = printt,
}:match(glue.readfile'media/collada/cube.dae')

