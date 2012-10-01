--[[

	pages environment

]]

require 'wsapi.request'
require 'wsapi.reply'

local
	print = print

module(...)

reply = {
	-- status fields
	status_code,
	status_message,
		reply_line,
	-- headers
	set_cookies,
		headers,
	-- content
	raw_content
}

function reply.push(s)
	print(s)
end

local function expect_number(q)
	return q
end

function query(q)
	return {
		expect_number = expect_number
	}
end
