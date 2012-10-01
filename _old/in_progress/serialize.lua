

local pkg={}

-- change a compiled string into a function
function pkg.undump(str)
   if str:strmatch '^\027LuaQ' or str:strmatch '^#![^\n]+\n\027LuaQ' then
      local f = (lua_loadstring or loadstring)(str)
      return f
   else
      error "Not a chunk dump"
   end
end

function pkg.eval (s)
  return loadstring ("return " .. s)()
end


