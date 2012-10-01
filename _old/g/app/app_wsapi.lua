#!/bin/wsapi.cgi

-- gazolin app wsapi handler for cgi or fastcgi launchers.
-- DOES: error handling, error logging, module reloading between requests, output buffering.

-- NOTE: if the code here crashes before hitting invalidate_modules(), you'll have to restart
-- the web server to have it reload this file from disk again.

module(..., g.package.seelua)

__OUTPUT_ERRORS = true

local app_logfile = '/var/log/httpd.gtest.app.log'

local function invalidate_modules()
	-- invalidate all loaded modules for the next request, incl. this one
	for k,_ in pairs(package.loaded) do
		package.loaded[k] = nil
	end
end

function run(wsapi_env)

	local app_env = {
		status_code = 200,
		headers = { ['Content-type'] = 'text/html', },
		finalizers = {},
		output_buffer = {},
    }

	local function out(s)
		s = tostring(s)
		if s ~= '' then
			table.insert(app_env.output_buffer, s)
		end
    end

	app_env.out = out

	local function log_error(ok, err)
		if not ok then
			if __OUTPUT_ERRORS then
				out(err)
			end
			local f = io.open(app_logfile, 'a')
			if f then
				f:write('['..os.date()..'] '..err..'\n')
				f:close()
			end
		end
		return ok, err
	end

    local function app_run()
		--for k,v in pairs(_G) do table.insert(app_env.output_buffer, k..' ('..type(v)..')\n') end
        --table.insert(app_env.output_buffer, '...........\n')
		require 'g.app'
		_G['g'].app.run(app_env)
    end

    ok, err = log_error(xpcall(app_run, debug.traceback))
	if not ok then
		for _,f in ipairs(app_env.finalizers) do
			log_error(xpcall(f(err), debug.traceback)) then
		end
		app_env.status = 500
		app_env.headers = { ['Content-type'] = 'text/html' }
		app_env.output_buffer = { '<html><head></head><body><b>Internal Server Error</b></body></html>' }
    end

	local function yield_output_buffer()
		for _,s in ipairs(app_env.output_buffer) do
			coroutine.yield(s)
		end
	end

    return app_env.status_code, app_env.headers, coroutine.wrap(yield_output_buffer)
end

