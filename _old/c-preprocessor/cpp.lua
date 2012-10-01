--C preprocessor for extracting constants
--objective: preprocess C headers for extracting constants to use with ffi
--spec: http://gcc.gnu.org/onlinedocs/cpp/

function normalize(s)
	s = s:gsub('\r\n', '\n') --normalize newlines (dos2unix)
	s = s:gsub('\r', '\n') --normalize newlines (mac2unix)
	s = s:gsub('[^\n]$', '%1\n') --normalize eof
	s = s:gsub('\\[ \t]*\n', '') --compress lines ending in \
	--TODO: when removing comments, skip over string constants!
	s = s:gsub('/%*[^%*]*%*/', ' ') --strip block comments
	s = s:gsub('//[^\n]\n', '\n') --strip line comments
	return s
end

function expand(name, s, macros, expanded, parents)
	if expanded[name] then return end
	if s:match'^%(' then --function macro
		--TODO: expand function macros
		assert(false, 'function macro expansion not implemented')
	else --object macro expression
		for k,s in tokenize(s) do
			if s == '(' then

		end
	end
end

function eval(s, macros, expanded)
	assert(false, '#if evaluation not implemented')
end

function process(s)
	s = normalize(s)
	--collect macros
	local macros = {} --{name = unexpanded_value}
	local expanded = {} --{name = expanded_value}
	local ifs = {} --if/else states
	local states = {} --if/else states
	for d,s in s:gmatch'%s*#%s*([%a_][%w_]+)([^\n]*)\n' do
		s = s:trim()
		if #ifs == 0 or ifs[#ifs] then
			if d == 'include' then
				--TODO: include file
				error('#include not implemented', 2)
			end

			if d == 'error' then
				error('#error: %s' % s, 2)
			end

			local name, rest
			if d == 'define' or d == 'undef' or d == 'ifdef' or d == 'ifndef' then
				name, rest = s:match'^([%a_][%w_]+)(.*)'
				rest = rest:trim()
				assert(name, '#%s: invalid name', d)
				assert(name ~= '', '#%s: missing name', d)
			end

				macros[n] = s
			elseif d == 'undef'

			elseif

				if d == 'define' then
				elseif d == 'undef' then
					macros[n] = nil
				else
					ifs[#ifs+1] =
						(d == 'ifdef' and macros[n] ~= nil) or
						(d == 'ifndef' and macros[n] == nil) or
						(d == 'if' and eval(s, macros, expanded) ~= 0)
					states[#states+1] = 'if'
				end
			end
		end
		if d == 'elif' then
			assert(states[#states] ~= 'else', 'unexpected #elif after #else')
			if ifs[#ifs] then
				states[#states] = 'skip'
				ifs[#ifs] = false
			end --elif mutual exclusion
			if states[#states] ~= 'skip' then
				ifs[#ifs] = eval(s, macros, expanded) ~= 0
			end
		elseif d == 'else' then
			assert(states[#states] ~= 'else', 'unexpected #else after #else')
			assert(#ifs > 0, 'unexpected #else')
			if states[#states] ~= 'skip' then
				ifs[#ifs] = not ifs[#ifs]
			end
			states[#states] = 'else'
		elseif d == 'endif' then
			assert(#ifs > 0, 'unexpected #endif')
			ifs[#ifs] = nil
		end
	end
	assert(#ifs == 0, '#endif missing')
	--expand macros
	for k,v in pairs(macros) do
		expand(k, v, macros, expanded)
	end
	return expanded
end

if not ... then

process[[


]]

end
