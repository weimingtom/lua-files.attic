
function DEFINE(s)
	for d,v in s:gmatch'#define%s+(.-)%s+(.-)%s*\n' do
		_G[d] = tonumber(v) or _G[v]
	end
end

