-- pickler.lua v0.2
-- Simple pickle library based on Roberto's struct library at
--    http://www.inf.puc-rio.br/~roberto/struct
-- All Lua types but thread and userdata are supported. Function pickling is
-- based on string.dump/loadstring, and so closures are not an (easy) option.
-- Table with references to other tables are ok (including cyclic references).
-- Thanks to Thomas Lauer for his many suggestions.
-- This code is in public domain.

require "struct"
local pack = struct.pack
local unpack = struct.unpack
local size = struct.size

local type = type
local dump = string.dump
local loadstring = loadstring
local setmetatable = setmetatable
local pairs = pairs
local concat = table.concat
local error = error
local assert = assert
local fopen = io.open
local wrap = coroutine.wrap
local yield = coroutine.yield
local format = string.format

local function taddress(t) -- table address: simple hash
  return tostring(t):sub(10)
end
local function toversion(h) -- hex to version string
  return format("%.1f", format("%x", h) / 10)
end
local function fromversion(v) -- version string to hex
  return tonumber(v * 10, 16)
end

module(...)

_VERSION = "0.2"
_BUFSIZE = 2^13 -- 8 kB
local SIGNATURE = pack("Bc3", 0x1b, "LPK") -- <esc>LPK

-- from lua.h
local TNIL = 0
local TBOOLEAN = 1
local TNUMBER = 3
local TSTRING = 4
local TTABLE = 5
local TFUNCTION = 6
-- extra
local TREF = 253
local TGUARD = 254
local TBLOCK = 255

-- keep references to tables
local ref = setmetatable({}, {__mode = "v"})


-- main routines: pickle and unpickle

pickle = function(o)
  local t = type(o)
  if t == "nil" then
    return pack("B", TNIL)
  elseif t == "boolean" then
    return pack("BB", TBOOLEAN, o and 1 or 0)
  elseif t == "number" then
    return pack("Bd", TNUMBER, o)
  elseif t == "string" then
    return pack("BLc0", TSTRING, #o, o)
  elseif t == "table" then
    local a = taddress(o)
    if ref[a] == nil then -- not interned?
      ref[a] = o
      local p = {} -- hold packs
      p[1] = pack("B", TTABLE) -- type
      p[2] = pack("Bc0", #a, a) -- ref key
      for k, v in pairs(o) do
        p[#p + 1] = pickle(k)
        p[#p + 1] = pickle(v)
      end
      p[#p + 1] = pack("B", TGUARD) -- table end
      return concat(p)
    end
    return pack("BBc0", TREF, #a, a)
  elseif t == "function" then
    local f = dump(o)
    return pack("BLc0", TFUNCTION, #f, f)
  else
    error("type not supported: " .. t)
  end
end

unpickle = function(o, start)
  local p = start or 1
  local t, p = unpack("B", o, p)
  if t == TNIL then
    return nil, p
  elseif t == TBOOLEAN then
    return unpack("B", o, p) == 1, p + size"B"
  elseif t == TNUMBER then
    return unpack("d", o, p)
  elseif t == TSTRING then
    return unpack("Lc0", o, p)
  elseif t == TTABLE then
    local a, p = unpack("Bc0", o, p)
    -- intern table
    local r = {}
    ref[taddress(r)] = r
    ref[a] = r
    local k, v
    while (unpack("B", o, p)) ~= TGUARD do
      k, p = unpickle(o, p)
      v, p = unpickle(o, p)
      r[k] = v
    end
    p = p + size"B" -- after TGUARD
    return r, p
  elseif t == TFUNCTION then
    local u, p = unpack("Lc0", o, p)
    return loadstring(u), p
  else -- TREF
    local a, p = unpack("Bc0", o, p)
    assert(ref[a] ~= nil, "table not interned")
    return ref[a], p
  end
end


-- pickler file object

local write = function(fp, o)
  local f = fp.handle
  local p = pickle(o)
  f:write(pack("BL", TBLOCK, #p))
  f:write(p)
end

local objects = function(fp)
  local f = fp.handle
  return wrap(function()
    local s, p = "", 1
    while true do
      local fs = f:read(_BUFSIZE)
      if fs == nil then break end -- EOF?
      s = s .. fs
      while p <= #s do -- any object left?
        -- read block size
        if p + size"BL" - 1> #s then break end -- buffer underflow?
        local c, l, o = unpack("BL", s, p)
        assert(c == TBLOCK, "file format error")
        -- read block
        if o + l - 1 > #s then break end -- buffer underflow?
        o, p = unpickle(s, o)
        yield(o)
      end
      s, p = s:sub(p), 1 -- reset buffer and position
      if _BUFSIZE == "*a" then break end -- parse only once
    end
  end)
end

local close = function(fp)
  fp.handle:close()
end

local fp_index = {write=write, objects=objects, close=close}
open = function(fname, mode)
  local mode = mode or "r"
  local version = _VERSION
  assert(mode == "r" or mode == "w", "unknown option: `" .. mode .. "'")
  local f = assert(fopen(fname, mode .. "b"),
      "cannot open file: `" .. fname .. "'")
  if mode == "r" then -- read
    local s = f:read(#SIGNATURE)
    assert(s == SIGNATURE, "wrong file format")
    version = toversion(unpack("B", f:read(size"B")))
  else -- write
    f:write(SIGNATURE)
    f:write(pack("B", fromversion(version)))
  end
  return setmetatable({handle=f, mode=mode, version=version},
      {__index = fp_index})
end
