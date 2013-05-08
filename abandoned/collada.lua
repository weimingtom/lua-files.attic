--collada reader: reads a small subset of mesh and lambert effects. tested with sketchup exports.
--collada format looks bloated and too generic. I have to look at the Sketchup C++ SDK see if it's any better.
local xmllpeg = require'xmllpeg'
local glue = require'glue'

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

local function load(file)
	local t = {tag = '', attrs = {}, children = {}, tags = {}}
	local byid = {}
	local function resolve(url) return byid[url:sub(2)] end

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
		end_tag = function(s)
			if t.attrs.id then
				byid[t.attrs.id] = t
			end
			t = t.parent
		end,
	}:match(glue.readfile(file))

	local function numbers(s, t)
		t = t or {}
		for s in s:gmatch'([^%s]+)' do
			t[#t+1] = tonumber(s)
		end
		return t
	end

	local objects = {} --{type = {t = o}}
	local function getter(type, cons)
		return function(t)
			local ot = objects[type] or {}; objects[type] = ot
			local o = ot[t]
			if not o then
				o = {}
				cons(t,o)
				ot[t] = o
			end
			return o
		end
	end

	local source = getter('source', function(t,s)
		numbers(t.tags.float_array.cdata, s)
	end)

	local vertex = getter('vertex', function(t,v)
		for input in children(t,'input') do
			if input.attrs.semantic == 'POSITION' then
				v.points = source(resolve(input.attrs.source))
			elseif input.attrs.semantic == 'NORMAL' then
				v.normals = source(resolve(input.attrs.source))
			end
		end
	end)

	local geometry = getter('geometry', function(t,g)
		local tri = t.tags.mesh.tags.triangles
		for input in children(tri, 'input') do
			if input.attrs.semantic == 'VERTEX' then
				local v = vertex(resolve(input.attrs.source))
				g.points = v.points
				g.normals = v.normals
			elseif input.attrs.semantic == 'TEXCOORD' then
				g.texcoords = source(resolve(input.attrs.source))
			end
		end
		g.indices = numbers(tri.tags.p.cdata)
	end)

	local effect = getter('effect', function(t,e)
		local params = {}
		for p in children(t.tags.profile_COMMON, 'newparam') do
			params[p.attrs.sid] = p
		end
		local technique = t.tags.profile_COMMON.tags.technique.tags
		if technique.lambert then
			local function color_or_texture(dt)
				local e = {}
				if dt.texture then
					local t = params[dt.texture.attrs.texture] -->sampler2D
					t = params[t.tags.sampler2D.tags.source.cdata] -->surface
					t = byid[t.tags.surface.tags.init_from.cdata] -->image
					t = t.tags.init_from.cdata
					e.texture = t
					e.textcoord = dt.texture.attrs.textcoord
				elseif dt.color then
					e.color = numbers(dt.color.cdata)
				end
				return e
			end
			local lt = technique.lambert.tags
			e.diffuse = color_or_texture(lt.diffuse.tags)
			e.transparent = color_or_texture(lt.transparent.tags)
			e.transparent_opaque = lt.transparent.attrs.opaque
			e.transparency = tonumber(lt.transparency.tags.float.cdata)
		end
	end)

	local material = getter('material', function(t,m)
		m.effect = effect(resolve(t.tags.instance_effect.attrs.url))
	end)

	local function instance_geometry(t)
		local ig = {}
		local g = geometry(resolve(t.attrs.url))
		local im = t.tags.bind_material.tags.technique_common.tags.instance_material
		ig.material = material(resolve(im.attrs.target))
		glue.update(ig, g)
		return ig
	end

	local scene = getter('scene', function(t,s)
		s.objects = {}
		for node in children(t, 'node') do
			for ig in children(node, 'instance_geometry') do
				ects[#s.objects+1] = instance_geometry(ig)
			end
		end
	end)

	return scene(resolve(t.tags.COLLADA.tags.scene.tags.instance_visual_scene.attrs.url))
end

if not ... then

local t = load'_collada/cube.dae'
local pp = require'pp'
pp.pp(t)

end

return {
	load = load,
}

