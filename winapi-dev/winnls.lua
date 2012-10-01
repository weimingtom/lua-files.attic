setfenv(1, require'winapi.core')
require'winapi.winbase'

ffi.cdef[[
size_t wcslen(const wchar_t *str);

int WideCharToMultiByte(
	  UINT     CodePage,
	  DWORD    dwFlags,
	  LPCWSTR  lpWideCharStr,
	  int      cchWideChar,
	  LPSTR    lpMultiByteStr,
	  int      cbMultiByte,
	  LPCSTR   lpDefaultChar,
	  LPBOOL   lpUsedDefaultChar);

int MultiByteToWideChar(
	  UINT     CodePage,
	  DWORD    dwFlags,
	  LPCSTR   lpMultiByteStr,
	  int      cbMultiByte,
	  LPWSTR   lpWideCharStr,
	  int      cchWideChar);
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

WC_COMPOSITECHECK         = 0x00000200  -- convert composite to precomposed
WC_DISCARDNS              = 0x00000010  -- discard non-spacing chars
WC_SEPCHARS               = 0x00000020  -- generate separate chars
WC_DEFAULTCHAR            = 0x00000040  -- replace w/ default char
WC_NO_BEST_FIT_CHARS      = 0x00000400  -- do not use best fit chars

ERROR_INSUFFICIENT_BUFFER = 122

--if ws is a wchar[] sz is inferred but if it's a wchar* it's not!
function WideCharToMultiByte(ws, CP, WC, wssize, dc, udc)
	CP = CP or CP_UTF8
	WC = flags(WC)
	local sz = wssize
					or (ffi.istype('WCHAR[?]', ws)
						and math.ceil(ffi.sizeof(ws) / 2)) --assume 1 byte per character
					or (ffi.istype('WCHAR*', ws) and ffi.C.wcslen(ws)) --assume 1 byte per character
	local buf = ffi.new('CHAR[?]', sz)
	sz = ffi.C.WideCharToMultiByte(CP, WC, ws, wssize or -1, buf, sz, dc, udc)
	if sz == 0 then
		if GetLastError() ~= ERROR_INSUFFICIENT_BUFFER then checknz(0) end
		sz = checknz(ffi.C.WideCharToMultiByte(CP, WC, ws, wssize or -1, nil, 0, dc, udc))
		buf = ffi.new('CHAR[?]', sz)
		sz = checknz(ffi.C.WideCharToMultiByte(CP, WC, ws, wssize or -1, buf, sz, dc, udc))
	end
	return ffi.string(buf, wssize and sz or sz-1)
end

--returns a null-terminated wcs and its size minus the null-terminator.
--ffi.sizeof(ws)-2 also works in case you want to loose the size.
function MultiByteToWideChar(s, CP, MB)
	CP = CP or CP_UTF8
	MB = flags(MB)
	local sz = #s + 1 --assume 1 byte per character + null terminator
	local buf = ffi.new('WCHAR[?]', sz)
	sz = ffi.C.MultiByteToWideChar(CP, MB, s, #s + 1, buf, sz)
	if sz == 0 then
		if GetLastError() ~= ERROR_INSUFFICIENT_BUFFER then checknz(0) end
		sz = checknz(ffi.C.MultiByteToWideChar(CP, MB, s, #s + 1, nil, 0))
		buf = ffi.new('WCHAR[?]', sz)
		sz = checknz(ffi.C.MultiByteToWideChar(CP, MB, s, #s + 1, buf, sz))
	end
	return buf, sz-1
end

--showcase

if not ... then
local buf, sz = MultiByteToWideChar('hello!')
print(ffi.string(ffi.cast('char*', buf), sz*2))
local s = WideCharToMultiByte(ffi.cast('WCHAR*',buf))
print(s, sz, #s)
end
