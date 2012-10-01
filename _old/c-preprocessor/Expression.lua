local luaerror = error

pos = 1
count = 0
precedence = {}

local pattern = "^ *%s"
function __init(self, object)
	self = oo.rawnew(self, object)

	if not self.operands and self.values then
		local operands = {}
		for kind, spec in pairs(self.values) do
			operands[kind] = pattern:format(spec)
		end
		self.operands = operands
	end

	if not self.format and self.operators then
		local opformat = {}
		for name, spec in pairs(self.operators) do
			local format = {}
			local pos = 1
			while pos <= #spec do
				if spec:find("^ ", pos) then
					format[#format+1] = true
					pos = pos + 1
				else
					local keyword = spec:match("^[^ ]+", pos)
					format[#format+1] = keyword
					pos = pos + #keyword
				end
			end
			opformat[name] = format
		end
		self.format = opformat
	end

	self.values = self.values or {}

	return self
end

function push(self, kind, value)
	self[#self+1] = kind
	if kind == true then
		self.count = self.count + 1
		self.values[self.count] = value
	end
end

function pop(self)
	local kind = self[#self]
	self[#self] = nil
	local value
	if kind == true then
		value = self.values[self.count]
		self.count = self.count - 1
	end
	return kind, value
end

function get(self, count)
	local nvals = 0
	for _=1, count do
		if self[#self] == true then
			nvals = nvals + 1
		end
		self[#self] = nil
	end
	self.count = self.count - nvals
	return unpack(self.values, self.count + 1, self.count + nvals)
end

local errmsg = "%s at position %d"
function error(self, msg)
	return luaerror(errmsg:format(msg, self.pos))
end

function done(self)
	return (self.text:match("^%s*$", self.pos))
end

function token(self, token)
	local pos = select(2, self.text:find("^%s*[^%s]", self.pos))
	if pos and (self.text:find(token, pos, true) == pos) then
		self.pos = pos + #token
		return true
	end
end

function match(self, pattern)
	local first, last, value = self.text:find(pattern, self.pos)
	if first then
		self.pos = last + 1
		return value
	end
end

function operator(self, name, level, start)
	local format = self.format[name]
	for index, kind in ipairs(format) do
		local parsed = self[start + index]
		if parsed then
			if parsed ~= kind then
				return false
			end
		else
			if kind == true then
				if not self:parse(level + 1, #self) then
					return false
				end
			else
				if self:token(kind) then
					self:push(kind)
				else
					return false
				end
			end
		end
	end
	self:push(true, self[name](self, self:get(#format)))
	return true
end

function value(self)
	if self:token("(") then
		local start = #self
		if not self:parse(1, start) then
			self:error("value expected")
		elseif #self ~= start + 1 or self[#self] ~= true then
			self:error("incomplete expression")
		elseif not self:token(")") then
			self:error("')' expected")
		end
		return true
	else
		for kind, pattern in pairs(self.operands) do
			local value = self:match(pattern)
			if value then
				self:push(true, self[kind](self, value))
				return true
			end
		end
		return false
	end
end

function parse(self, level, start)
	if not self:done() then
		local ops = self.precedence[level]
		if ops then
			local i = 1
			while ops[i] do
				local op = ops[i]
				if self:operator(ops[i], level, start) then
					i = 1
				else
					i = i + 1
				end
			end
			if #self == start then
				return self:parse(level + 1, start)
			elseif self[start + 1] == true then
				return true
			end
		else
			return self:value()
		end
	end
end

function evaluate(self, text, pos)
	if text then
		self.text = text
		self.pos = pos
	end
	if not self:parse(1, 0) then
		self:error("parsing failed")
	elseif not self:done() then
		self:error("malformed expression")
	elseif #self ~= 1 or self[1] ~= true then
		self:error("incomplete expression")
	end
	return self:get(1)
end
