--wide character string object (idea; not used).
setfenv(1, require'winapi.namespace')
require'winapi.ffi'
require'winapi.glue'
require'winapi.wtypes'

ffi.cdef[[
typedef struct {
	UINT  size;
	WCHAR s[?];
} WCS;

size_t wcslen(const wchar_t *str);

int MultiByteToWideChar(
	  UINT     CodePage,
	  DWORD    dwFlags,
	  LPCSTR   lpMultiByteStr,
	  int      cbMultiByte,
	  LPWSTR   lpWideCharStr,
	  int      cchWideChar);

int WideCharToMultiByte(
	  UINT     CodePage,
	  DWORD    dwFlags,
	  LPCWSTR  lpWideCharStr,
	  int      cchWideChar,
	  LPSTR    lpMultiByteStr,
	  int      cbMultiByte,
	  LPCSTR   lpDefaultChar,
	  LPBOOL   lpUsedDefaultChar);
]]

CP_INSTALLED      = 0x00000001  -- installed code page ids
CP_SUPPORTED      = 0x00000002  -- supported code page ids
CP_ACP            = 0           -- default to ANSI code page
CP_OEMCP          = 1           -- default to OEM  code page
CP_MACCP          = 2           -- default to MAC  code page
CP_THREAD_ACP     = 3           -- current thread's ANSI code page
CP_SYMBOL         = 42          -- SYMBOL translations
CP_UTF7           = 65000       -- UTF-7 translation
CP_UTF8           = 65001       -- UTF-8 translation

MB_PRECOMPOSED            = 0x00000001  -- use precomposed chars
MB_COMPOSITE              = 0x00000002  -- use composite chars
MB_USEGLYPHCHARS          = 0x00000004  -- use glyph chars, not ctrl chars
MB_ERR_INVALID_CHARS      = 0x00000008  -- error for invalid chars

ERROR_INSUFFICIENT_BUFFER = 122

WCS, WCS_MT = {}, {}
WCS_MT.__index = WCS
setmetatable(WCS, WCS) --for __call
setmetatable(WCS_MT, WCS) --for __index and __len

local WCS_ctype = ffi.typeof'WCS'
local PWCHAR_ctype = ffi.typeof'WCHAR*'

function WCS:__call(arg, arg2, arg3)
	local wcs, sz
	if type(arg) == 'string' then --transform it from utf8 to wide char
		local CP, MB = arg2 and flags(arg2) or CP_UTF8, flags(arg3)
		sz = #arg + 1 --assume 1 byte per character + null terminator
		wcs = WCS_ctype(sz)
		sz = ffi.C.MultiByteToWideChar(CP, MB, arg, #arg + 1, wcs.s, sz)
		if sz == 0 then
			if GetLastError() ~= ERROR_INSUFFICIENT_BUFFER then checknz(0) end
			sz = checknz(ffi.C.MultiByteToWideChar(CP, MB, arg, #arg + 1, nil, 0))
			wcs = WCS_ctype(sz)
			sz = checknz(ffi.C.MultiByteToWideChar(CP, MB, arg, #arg + 1, wcs.s, sz))
		end
		wcs.size = sz-1
	elseif type(arg) == 'number' then --make it a receiving buffer
		wcs = WCS_ctype(arg + 1)
		wcs.size = arg
	elseif ffi.istype(PWCHAR_ctype, arg) then --encapsulate it
		sz = (arg2 or ffi.C.wcslen(arg)) + 1 --if n not given, assume it's null terminated
		wcs = WCS_ctype(sz)
		ffi.copy(wcs.s, arg, sz * 2)
		wcs.size = sz-1
	elseif ffi.istype(WCS_ctype, arg) then
		wcs = arg
	else
		error('arg#1 string, number, WCS or WCHAR* expected, got %s' % type(arg), 2)
	end
	return wcs
end

function WCS_MT:__len()
	return self.size
end

function WCS:findsize()
	self.size = ffi.C.wcslen(self.s)
end

WC_COMPOSITECHECK         = 0x00000200  -- convert composite to precomposed
WC_DISCARDNS              = 0x00000010  -- discard non-spacing chars
WC_SEPCHARS               = 0x00000020  -- generate separate chars
WC_DEFAULTCHAR            = 0x00000040  -- replace w/ default char
WC_NO_BEST_FIT_CHARS      = 0x00000400  -- do not use best fit chars

local MBS_ctype = ffi.typeof'CHAR[?]'

function WCS:mbs(CP, WC, dc, udc)
	CP = CP or CP_UTF8
	WC = flags(WC)
	local sz = self.size + 1 --assume 1 byte per character + null termination
	local buf = MBS_ctype(sz)
	sz = ffi.C.WideCharToMultiByte(CP, WC, self.s, self.size + 1, buf, sz, dc, udc)
	if sz == 0 then
		if GetLastError() ~= ERROR_INSUFFICIENT_BUFFER then checknz(0) end
		sz = checknz(ffi.C.WideCharToMultiByte(CP, WC, self.s, self.size + 1, nil, 0, dc, udc))
		buf = MBS_ctype(sz)
		sz = checknz(ffi.C.WideCharToMultiByte(CP, WC, self.s, self.size + 1, buf, sz, dc, udc))
	end
	return ffi.string(buf, sz-1)
end

--ffi says WCS table must be fully defined before associating the metatable!
ffi.metatype('WCS', WCS_MT)


if not ... then

--a Lua string is assumed utf-8 and converted to wcs
local w = WCS'hello'
assert(w.size == #'hello')
assert(#w == w.size)
assert(ffi.string(w.s, (w.size+1)*2) == 'h\0e\0l\0l\0o\0\0\0')
assert(ffi.C.wcslen(w.s) == #'hello')
assert(w:mbs() == 'hello')

--a WCS is passing through the same
assert(ffi.cast('WCS*', WCS(w)) == ffi.cast('WCS*', w))

--a pchar's contents is copied over in new WCS
local w2 = WCS(ffi.cast('WCHAR*', w.s))
assert(#w2 == #'hello')
assert(w2:mbs() == 'hello')

--passing a number allocates a new WCS buffer of that size
w = WCS(5)
assert(#w == 5)
w:findsize() --after the buffer is filled, call this to find the contents size
assert(#w == 0)

end

