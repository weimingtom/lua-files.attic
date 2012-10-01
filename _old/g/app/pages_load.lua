#!/bin/luajit
--[[


]]

require "luafilesystem"

path = '/work.gazolin-site/pages/?.lua'
loaded = {}
pages_env = nil

local function get_env(force_load)
	if force_load or not env then
		local global_env = _G
		pages_env = {}

		setfenv(0, pages_env)
		pages_env = loadfile('pages_env.lua')
		setfenv(0, global_env)
	end
	return pages_env
end

-- caches pages
-- runs pages in prepared sandbox environment
function pages.run(page_name, force_load, force_load_env)
	if force or not pages.loaded[page_name] then

		local page_file = string.gsub(pages.path, '?', page_name
		if


		local page = loadfile(string.gsub(pages.path, '?', page_name)
		setfenv(page, pages.get_env(force_load_env))
		pages.loaded[page_name] = page
	end
	pages.loaded[page_name]()
end


