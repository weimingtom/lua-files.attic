--[[
	table functions, i.e. functions that work for generic maps.

	map(f|val,t[,overt])
	clear(t)
	copy(t[,overt])

	keys(t)

	index(t)
	mapped(f,t)
	filter(f,t)
	filtered(f,t)
	interlace_keys(t)
	select(keys,t)

	COLLECT
		copy_array_part(t) = collect(ipairs(t))
	FOLDR
		card(t) = foldr(function.inc,0,t)
	MAP

		index(t) = collect(keys(t)) -- WRONG!!
		collect(pairs(t)) -- no meaning
		acckeys(ipairs(t)) -> seq

		function eq_keys(keys, a, b)


]]

local _G,M=_G,{}
setfenv(1,M)

local function map_iter(state)
	state.next=next(state.t)
	return f(state.next)
end

function pkg.map(f,t,i,j)
	return map_iter,{t=t,f=f,i=i,j=j},(next(t))
end

function pkg.map_(f,t,overt)
	overt = overt or {}
	if type(f)=='function' then
		for k,v in pairs(t) do
			overt[k]=f(v)
		end
	else
		for k,v in pairs(t) do
			overt[t]=f
		end
	end
	return overt
end

function pkg.copy(t,overt)
	return pkg.map(func.id,t,overt)
end

function pkg.clear(t)
	return pkg.map(nil,t,t)
end

local function next_key(t,k)
	k = next(t,k)
	return k,k
end

-- iterator of keys
function pkg.keys(t)
	return next_key,t
end

---------------------------------
function pairsByKeys (t, f)
      local a = {}
      for n in pairs(t) do table.insert(a, n) end
      table.sort(a, f)
      local i = 0      -- iterator variable
      local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
      end
      return iter
    end

-- infuse_keys({a=1,b=2,5}) -> {a,1,b,2,3,5}
function interlace_keys(t)
	tt = {}
	for k,v in pairs(t) do
		tt[#tt+1] = k
		tt[#tt+1] = v
	end
end

function select(keys, t)
	--...
end

-- @func map: Map a function over an iterator
--   @param f: function
--   @param i: iterator
--   @param ...: iterator's arguments
-- @returns
--   @param t: result table
function _G.map (f, i, ...)
  local t = {}
  for e in i (...) do
    local r = f (e)
    if r then
      table.insert (t, r)
    end
  end
  return t
end

-- @func filter: Filter an iterator with a predicate
--   @param p: predicate
--   @param i: iterator
--   @param ...:
-- @returns
--   @param t: result table containing elements e for which p (e)
function _G.filter (p, i, ...)
  local t = {}
  for e in i (...) do
    if p (e) then
      table.insert (t, e)
    end
  end
  return t
end

-- @func fold: Fold a function into an iterator leftwards
--   @param f: function
--   @param d: element to place in left-most position
--   @param i: iterator
--   @param ...:
-- @returns
--   @param r: result
function _G.foldl (f, i, ...)
  local r = d
  for e in i (...) do
    r = f (r, e)
  end
  return r
end

-- Function forms of operators
_G.op = {
  ["+"] = function (...)
            return list.foldr (function (a, b)
                                 return a + b
                               end,
                               0, {...})
          end,
  ["-"] = function (...)
            return list.foldr (function (a, b)
                                 return a - b
                               end,
                               0, {...})
          end,
  ["*"] = function (...)
            return list.foldr (function (a, b)
                                 return a * b
                               end,
                               1, {...})
          end,
  ["/"] = function (a, b)
            return a / b
          end,
  ["and"] = function (...)
              return list.foldl (function (a, b)
                                   return a and b
                                 end, true, {...})
            end,
  ["or"] = function (...)
             return list.foldl (function (a, b)
                                  return a or b
                                end,
                                false, {...})
           end,
  ["not"] = function (x)
              return not x
            end,
  ["=="] = function (x, ...)
             for _, v in ipairs ({...}) do
               if v ~= x then
                 return false
               end
             end
             return true
           end,
  ["~="] = function (...)
             local t = {}
             for _, v in ipairs ({...}) do
               if t[v] then
                 return false
               end
               t[v] = true
             end
             return true
           end,
}


return M

