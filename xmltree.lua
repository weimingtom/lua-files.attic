--parse xml to a tree of nodes: {tag =, attrs = {<k>=v}, children = {node1,...}, tags = {<tag> = node})
local xmllpeg = require'xmllpeg'

local function parse(s, handlers)
	local root = {tag = 'root', attrs = {}, children = {}, tags = {}}
	local t = root
	xmllpeg.P{
		cdata = function(s)
			t.cdata = s
		end,
		attr = function(k, v)
			t.attrs[k] = v
		end,
		start_tag = function(s)
			t = {tag = s, attrs = {}, children = {}, tags = {}, parent = t}
			local ct = t.parent.children
			ct[#ct+1] = t
			t.parent.tags[t.tag] = t
		end,
		end_start_tag = function(s)
			if handlers and handlers.start_tag then handlers.start_tag(t) end
		end,
		end_tag = function(s)
			if handlers and handlers.end_tag then handlers.end_tag(t) end
			t = t.parent
		end,
	}:match(s)
	return root, byid
end

local function children(t,tag)
	local i=1
	return function()
		local v
		repeat
			v = t.children[i]
			i = i + 1
		until not v or v.tag == tag
		return v
	end
end

return {
	parse = parse,
	children = children,
}

