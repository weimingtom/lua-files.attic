--deep tables

function nodes(t)
	local path = {}
	return function()
		for k,v in pairs(t) do
			if type(k) == 'table' then
			--
			end
		end
	end
end
