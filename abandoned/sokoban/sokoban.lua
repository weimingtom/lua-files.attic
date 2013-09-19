local player = require'cairo_player'
local glue = require'glue'
local levels = require'levels'

--utils

local function level_tiles(n)
	return coroutine.wrap(function()
		local s = assert(levels[n], 'invalid level')
		local y = 1
		for s in s:gmatch'([^\r\n]*)\r?\n' do
			for x = 1, #s do
				local c = s:sub(x, x)
				coroutine.yield(x, y, c)
			end
			y = y + 1
		end
	end)
end

--game logic

local level, sizex, sizey, tiles, crate_count, boxes, pl, moves, undo_stack, redo_stack, changed

local function load_level(wanted_level)
	level = math.min(math.max(wanted_level, 1), #levels)
	changed = false
	sizex, sizey = 0, 0 --level size in tiles
	crate_count = 0
	tiles = {}      --tiles[x][y] = 'O'
	boxes = {}      --boxes[x][y] = '#' or '*'
	pl = {}         --pl.x, pl.y
	moves = 0
	undo_stack = {}
	redo_stack = {}
	local place_count = 0
	for x, y, c in level_tiles(level) do
		sizex = math.max(x, sizex)
		sizey = math.max(y, sizey)
		if c == 'O' or c == 'X' then
			place_count = place_count + 1
		elseif c == '#' then
			crate_count = crate_count + 1
		end
		tiles[x] = tiles[x] or {}
		boxes[x] = boxes[x] or {}
		if c == 'x' or c == 'X' then
			assert(not pl.x, 'invalid level data')
			pl.x, pl.y = x, y
		end
		if c == 'O' or c == 'X' then
			tiles[x][y] = c
		end
		if c == '*' or c == '#' then
			boxes[x][y] = c
		end
	end
	assert(pl.x, 'invalid level data')
	assert(crate_count == place_count, 'invalid level data')
	changed = true
end

local push_state, moved --fwd. decl.

local function move_delta(dx, dy)
	local x = pl.x + dx
	local y = pl.y + dy
	if not boxes[x][y] then --move freely over space
		push_state()
		pl.x, pl.y = x, y
		moved()
	elseif boxes[x][y] == '#' then --push a crate, if there's space behind it
		local x2 = dx ~= 0 and x + dx or x
		local y2 = dy ~= 0 and y + dy or y
		if not boxes[x2][y2] then
			push_state()
			pl.x, pl.y = x, y
			boxes[x][y] = nil
			boxes[x2][y2] = '#'
			moved()
		end
	end
end

local function move(dir)
	if dir == 'down' then
		move_delta(0, 1)
	elseif dir == 'up' then
		move_delta(0, -1)
	elseif dir == 'left' then
		move_delta(-1, 0)
	elseif dir == 'right' then
		move_delta(1, 0)
	end
end

local function crates_remaining()
	local count = crate_count
	for x = 1, sizex do
		for y = 1, sizey do
			if tiles[x][y] == 'O' and boxes[x][y] == '#' then
				count = count - 1
			end
		end
	end
	return count
end

local function iter_tiles()
	return coroutine.wrap(function()
		for x = 1, sizex do
			for y = 1, sizey do
				coroutine.yield(x, y, tiles[x][y], boxes[x][y])
			end
		end
		coroutine.yield(pl.x, pl.y, nil, 'x')
	end)
end

--state management -------------------------------------------------------------------------------------------------------

local function pack_crates()
	local t = {}
	for x = 1, sizex do
		for y = 1, sizey do
			if boxes[x][y] == '#' then
				t[#t+1] = x
				t[#t+1] = y
			end
		end
	end
	return t
end

local function unpack_crates(t)
	for x = 1, sizex do
		for y = 1, sizey do
			if boxes[x][y] == '#' then
				boxes[x][y] = nil
			end
		end
	end
	for i=1,#t,2 do
		local x, y = t[i], t[i+1]
		boxes[x][y] = '#'
	end
end

local function get_state()
	return {crates = pack_crates(), x = pl.x, y = pl.y}
end

local function set_state(state)
	unpack_crates(state.crates)
	pl.x, pl.y = state.x, state.y
	changed = true
end

function push_state()
	table.insert(undo_stack, get_state())
	redo_stack = {}
end

function moved()
	changed = true
	moves = moves + 1
end

local function undo()
	if #undo_stack == 0 then return end
	table.insert(redo_stack, get_state())
	set_state(table.remove(undo_stack))
	moved()
end

local function redo()
	if #redo_stack == 0 then return end
	table.insert(undo_stack, get_state())
	set_state(table.remove(redo_stack))
	moved()
end

--load/save --------------------------------------------------------------------------------------------------------------

local filename = 'gamefile.lua'
local gamefile = {level = 1}

local function load_gamefile()
	if glue.fileexists(filename) then
		gamefile = loadfile(filename)()
	end
end

local function format_crates(crates)
	local t = {}
	for i=1,#crates,2 do
		t[#t+1] = crates[i] .. ',' .. crates[i+1]
	end
	return string.format('{%s}', table.concat(t, ', '))
end

local function format_stack(stack)
	local t = {}
	for i,state in ipairs(stack) do
		t[i] = string.format('{x = %d, y = %d, crates = %s}', state.x, state.y, format_crates(state.crates))
	end
	return string.format('%s', table.concat(t, ',\n   '))
end

local function format_level(i, level)
	return string.format(
		'[%d] = {\n' ..
		'  x = %d, y = %d, moves = %d, crates = %s,\n  undo_stack = {\n   %s\n  },\n  redo_stack = {\n   %s\n  }\n' ..
		'}',
		i, level.x, level.y, level.moves,
		format_crates(level.crates),
		format_stack(level.undo_stack),
		format_stack(level.redo_stack))
end

local function format_gamefile()
	local t = {}
	for i,level in ipairs(gamefile) do
		t[#t+1] = format_level(i, level)
	end
	return string.format(
		'return {\n' ..
		' level = %d,\n' ..
		' dark = %s,\n' ..
		' %s\n' ..
		'}', gamefile.level, tostring(gamefile.dark), table.concat(t, ',\n '))
end

local function save_gamefile()
	glue.writefile(filename, format_gamefile())
end

local function get_playing_state(state)
	state.moves = moves
	state.undo_stack = undo_stack
	state.redo_stack = redo_stack
end

local function set_playing_state(state)
	moves = state.moves
	undo_stack = state.undo_stack
	redo_stack = state.redo_stack
end

local function load_game()
	local state = gamefile[level]
	if not state then return end
	set_state(state)
	set_playing_state(state)
end

local function save()
	if not changed then return end
	gamefile.level = level
	local state = get_state()
	get_playing_state(state)
	gamefile[level] = state

	save_gamefile()
	changed = false
end

--view & controller ------------------------------------------------------------------------------------------------------

local Z = 50 --box size in pixels

function player:draw_tile(x, y, tile, box)
	x = (x - 1) * Z
	y = (y - 1) * Z
	if tile == 'O' then
		self:rect(x + 2, y + 2, Z - 4, Z - 4, 'faint_bg', 'hot_fg')
	end
	if box == '*' then
		self:rect(x, y, Z, Z, nil, 'normal_fg')
	elseif box == 'x' then
		self:circle(x + Z / 2, y + Z / 4, Z / 8, nil, 'normal_fg')
		self:line(x, y, x + Z, y + Z, 'normal_fg')
		self:line(x + Z, y, x, y + Z, 'normal_fg')
	elseif box == '#' then
		self:rect(x + 8, y + 8, Z - 16, Z - 16, 'normal_fg')
	end
end

function player:on_render(cr)

	--game logic

	if self.ctrl and (self.key == 'left' or self.key == 'right') then
		load_level(level + (self.key == 'left' and -1 or 1))
		load_game()
	elseif self.ctrl and self.key == 'N' then
		load_level(level)
	elseif self.key == 'down' or self.key == 'up' or self.key == 'left' or self.key == 'right' then
		move(self.key)
	elseif self.ctrl and self.key == 'Z' then
		undo()
	elseif self.ctrl and self.key == 'Y' then
		redo()
	end

	--draw game

	self.show_magnifier = false
	self.cr:translate(0.5, 0.5)

	--GUI
	local dark = self:togglebutton{id = 'dark', x = 10, y = 10, w = 120, h = 26,
											text = gamefile.dark and 'lights on' or 'lights off', selected = gamefile.dark}
	self.theme = self.themes[dark and 'dark' or 'light']
	if dark ~= gamefile.dark then
		gamefile.dark = dark
		changed = true
	end

	--help & stats
	local crates_remaining = crates_remaining()

	self:label{x = 10, y = 60, font_face = 'Fixedsys', text =
		string.format('level: %d\n', level) ..
		string.format('crates left: %d\n', crates_remaining) ..
		string.format('moves: %d\n\n', moves) ..
		'keys: \n' ..
		'  move: arrow keys\n' ..
		'  last level: ctrl+left\n' ..
		'  next level: ctrl+right\n' ..
		'  undo: ctrl+Z\n' ..
		'  redo: ctrl+Y\n' ..
		'  restart level: ctrl+N\n'
	}

	if crates_remaining == 0 then
		self:label{x = 40, y = 300, font_face = 'Fixedsys', font_size = 32, color = '#ff0000', text = 'COMPLETED'}
	end

	--tiles
	self.cr:translate((self.w - sizex * Z) / 2, (self.h - sizey * Z) / 2)
	self:rect(0, 0, sizex * Z, sizey * Z, nil, 'faint_bg')
	for x, y, tile, box in iter_tiles() do
		self:draw_tile(x, y, tile, box)
	end

	--save game if changed
	save()

end

--init

load_gamefile()
load_level(gamefile.level)
load_game()

--game loop

player:play()

