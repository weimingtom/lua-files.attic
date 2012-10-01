
module ...

function new_from_fcgid(wsapi_env)

	local req = wsapi.request.new(wsapi_env, {delay_post = true})

    'range_position' => null,                   // partial request
    'range_length' => null,                     // partial request; can be null meaning EOF;
    // browser info
    'referer' => null,                          // for statistics and keywords (better use google analytics for that?)
    'user_agent' => null,                       // eg. for selecting browser-compatible html and css
    // user/browser requirements/preferences
    'accepted_media_types' => null,             // ordered array of accepted types (eg. choose best, raise error or ignore)
    'accepted_charsets' => null,                // ordered array of accepted charsets (eg. translate all text to user's requirements)
    'accepted_encodings' => null,               // ordered array of accepted encodings (eg. choose compression filter)
    'accepted_languages' => null,               // ordered array of accepted languages (eg. pick the language if not specifically requested)
    // request for cache validation (only those that could be of interest to an origin server!)
    'if_etags_match' => null,                   // array; 'If-Match' for validation against 'Etag'
    'if_no_etags_match' => null,                // array; 'If-None-Match' for validation against 'Etag'
    'if_modified_since' => null,                // 'If-Modified-Since' for valiation against 'Last-Modified'; converted to local time timestamp;
    'if_not_modified_since' => null,            // 'If-Unmodified-Since' for valiation against 'Last-Modified'; converted to local time timestamp;
    'if_range' => null,                         // boolean; comes with 'if_etags_match' or 'if_not_modified_since'; header 'If-Range'
                                                    // - means: "give entire reply without Range, if etags don't match or if modified"
    'max_age' => null                           // in seconds; header 'Cache-Control: max-age' for validation against request-time - last-modified-time
    // TODO: Expect

	local t = {
		-- server
		server_address = wsapi_env.SERVER_ADDR,
		server_port = wsapi_env.SERVER_PORT,
		-- connection
		https = wsapi_env.HTTPS == 'on',		-- ssl connection (url['scheme'] would be 'https')
		remote_address = wsapi_env.REMOTE_ADDR,
		-- request
		method = wsapi_env.REQUEST_METHOD,		-- GET, HEAD, POST, OPTIONS (not PUT, TRACE, DELETE, CONNECT)
		protocol = wsapi_env.SERVER_PROTOCOL,	-- should be either 'HTTP/1.0' or 'HTTP/1.1'
		url = {									-- complete, decoded URL object
			scheme = wsapi_env.HTTPS == 'on' and 'https' or 'http',
			host = wsapi_env.HTTP_HOST or wsapi_env.SERVER_NAME or wsapi_env.SERVER_ADDR,
			port = wsapi_env.SERVER_PORT,
			path = wsapi_env.SCRIPT_URL, 		-- part of uri until ?
			query = wsapi_env.QUERY_STRING,
		},
		args = 				-- array of exploded path members
		query = wsapi_env.QUERY_STRING, -- part of uri after ?
		params = req.GET, -- decoded query encoded as application/x-www-form-urlencoded
		raw_headers = nil, -- 2nd+ line of raw_request
		headers = { -- decoded headers
			host_name = wsapi_env.HTTP_HOST,	-- header 'Host'; HTTP/1.1 only (but Lynx sends it with HTTP/1.0)
			host_port = wsapi_env.HTTP_HOST,	-- header 'Host'; HTTP/1.1 only (but Lynx sends it with HTTP/1.0)
		},
		cookies = req.cookies, 					-- header 'Cookie'; the array of decoded cookies received for this URL
		raw_content = nil, -- optional post data after headers
		form = nil, -- the array of decoded POST vars
		params = nil,
		--[[
		-- unreliable/unnecessary
		request_uri = wsapi_env.REQUEST_URI,
		remote_port = wsapi_env.REMOTE_PORT,
		server_name = wsapi_env.SERVER_NAME,
		server_admin = wsapi_env.SERVER_ADMIN,
		server_software = wsapi_env.SERVER_SOFTWARE,
		document_root = wsapi_env.DOCUMENT_ROOT,
		script_filename = wsapi_env.SCRIPT_FILENAME,
		gateway_interface = wsapi_env.GATEWAY_INTERFACE,
		script_url = wsapi_env.SCRIPT_URL,
		script_name = wsapi_env.SCRIPT_NAME,
		--]]
	}

	setmetatable(t, {
		__index = function(t, k)
			if k == 'params' then
				req:parsepostdata()
				t.params = req.params
				return t.params
			elseif k == 'POST' then
				t.POST = req.POST
				return t.POST
			end
		end
	})

	-- get possible headers


	5.HTTP_USER_AGENT=Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/525.19 (KHTML, like Gecko) Chrome/1.0.154.65 Safari/525.19
6.HTTP_ACCEPT_ENCODING=gzip,deflate,bzip2,sdch
7.HTTP_ACCEPT=text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5
8.HTTP_CACHE_CONTROL=max-age=0
9.HTTP_ACCEPT_LANGUAGE=en-US,en,ro-RO,ro
10.HTTP_ACCEPT_CHARSET=ISO-8859-1,*,utf-8
11.HTTP_HOST=gtest.local
12.HTTP_CONNECTION=Keep-Alive


	return t
end


function request($var) {
	assert(array_key_exists($var, $GLOBALS['http_request']));
    return $GLOBALS['http_request'][$var];
}

function request_url($piece = null) {
	return cond($piece, $GLOBALS['http_request']['url'][$piece], $GLOBALS['http_request']['url']);
}

function request_path() {
    return $GLOBALS['http_request']['url']['path'];
}

function request_arg($index) {
	return $GLOBALS['http_request']['args'][$index];
}

function request_arg_count() {
	return count($GLOBALS['http_request']['args']);
}

function request_query() {
    return $GLOBALS['http_request']['url']['query'];
}

function request_param($var) {
    return $GLOBALS['http_request']['params'][$var];
}

function toggle_param($param_name) {
	return request_param($param_name) ? null : true;
}

function request_params($param_delta) {
	return array_filter(array_merge($GLOBALS['http_request']['params'], $param_delta), 'is_not_null');
}

function request_cookie($var) {
    return $GLOBALS['http_request']['cookies'][$var];
}

function request_form($var) {
    return $GLOBALS['http_request']['form'][$var];
}

function request_accept_content_type($ctype) {
    $at = request('accepted_content_types');
    if (count($at) == 0 || in_array('*', $at) || in_array('*/*', $at))
        return true;
    else {
        $ctype = explode('/', $ctype);
        foreach($at as $t) {
            $t = explode('/', $t);
            if (($t[0] == '*' || $ctype[0] == $t[0]) && ($t[1] == '*' || $ctype[1] == $t[1]))
                return true;
        }
    }
}

function request_accept_charset($charset) {
    $ac = request('accepted_charsets');
    return (count($ac) == 0 || in_array('*', $ac) || in_array($charset, $ac, true));
}

function request_accept_encoding($enc) {
    $ae = request('accepted_encodings');
    return (in_array('*', $ae) || in_array($enc, $ae, true));
}

function request_accept_language($lang) {
    $al = request('accepted_languages');
    return (in_array('*', $al) || in_array($lang, $al, true));
}

// get x out of <x; q=n>; this is a map-filter function
function http_parse_accept($s) {
	$r = explode_f(';', trim($s), 'req_trim_s');
    if (count($r) > 0)
        return $r[0];
}

// get x out of <[W/]"x">
function http_parse_etag($s) {
    $r = trim($s);
    if (substr($r, 0, 2) == 'W/')
        return substr($r, 3, strlen($r) - 4);
    else
        return substr($r, 1, strlen($r) - 2);
}

// this is a map-filter function
function http_parse_max_age($s) {
    $r = strstr(trim($s), 'max-age=');
    if ($r)
        return substr($r, strlen('max-age='), 2) + 0;
}

// TODO: order the array by q= (default q is 1)
// TODO: does q=0 mean not accepted at all?
function http_explode_qtag_list($s) {
    return explode_f(',', $s, 'http_parse_accept');
}

// TODO: assert syntax past apache
function init_request() {

    // server variables outside of request data:
        // REQUEST_TIME, REMOTE_ADDR, HTTPS
    // server variables and what part of the message are they extracted from:
        // REQUEST_METHOD, SERVER_PROTOCOL, REQUEST_URI -- request line
        // SERVER_NAME, SERVER_PORT -- 'Host' header
    // php predecoded variables
        // $_POST, $_COOKIE -- request line, 'Cookie' header, request body

    $h = apache_request_headers();
    $r = &$GLOBALS['http_request'];

    $r['request_time'] = $_SERVER['REQUEST_TIME'];
    $r['remote_addr'] = $_SERVER['REMOTE_ADDR'];

    $r['protocol'] = strtoupper($_SERVER['SERVER_PROTOCOL']);
    $r['method'] = strtoupper($_SERVER['REQUEST_METHOD']);
    $r['https'] = isset($_SERVER['HTTPS']);

    // TODO: test those with HTTP/1.0 (what does apache use instead of the Host header?)
    $r['server_name'] = url_decode_host($_SERVER['SERVER_NAME']);
    $r['server_port'] = (int)$_SERVER['SERVER_PORT'];

    $pathquery = explode('?', $_SERVER['REQUEST_URI'], 2);
    $r['url'] = array(
        'scheme' => $r['https'] ? 'https' : 'http',
        'host' => $r['server_name'],
        'port' => $r['server_port'],
        'path' => url_decode_path(substr($pathquery[0], 1)),
        'query' => count($pathquery) > 1 ? url_decode_query($pathquery[1]) : null,
        'fragment' => null
    );

    $r['args'] = explode('/', $r['url']['path']);
    $r['params'] = http_decode_params($r['url']['query']);

    // TODO: check the way cookies and form data are decoded by PHP
    $r['cookies'] = $_COOKIE;

    $r['form'] = $_POST;

    $r['referer'] = req_key('Referer', $h);
    $r['user_agent'] = req_key('User-Agent', $h);

    if (array_key_exists('Accept', $h))
        $r['accepted_media_types'] = http_explode_qtag_list($h['Accept']);
    if (array_key_exists('Accept-Charset', $h))
        $r['accepted_charsets'] = http_explode_qtag_list($h['Accept-Charset']);
    if (array_key_exists('Accept-Encoding', $h))
        $r['accepted_encodings'] = http_explode_qtag_list($h['Accept-Encoding']);
    if (array_key_exists('Accept-Language', $h))
        $r['accepted_languages'] = http_explode_qtag_list($h['Accept-Language']);

    if (array_key_exists('Range', $h)) {
        $r = explode('-', substr($h['Range'], strlen('bytes=')), 2);
        $r['range_position'] = $r[0];
        $r['range_length'] = count($r) == 1 ? null : $r[1] - $r[0] + 1;
    }

    $r['etag'] = req_key('ETag', $h);

    if (array_key_exists('If-Match', $h))
        $r['if_etags_match'] = explode_f(',', $h['If-Match'], 'http_parse_etag');

    if (array_key_exists('If-None-Match', $h))
        $r['if_no_etags_match'] = explode_f(',', $h['If-None-Match'], 'http_parse_etag');

    if (array_key_exists('If-Modified-Since', $h))
        $r['if_modified_since'] = http_decode_timestamp($h['If-Modified-Since']);

    if (array_key_exists('If-Unmodified-Since', $h))
        $r['if_not_modified_since'] = http_decode_timestamp($h['If-Unmodified-Since']);

    if (array_key_exists('If-Range', $h)) {
        $c = $h['If-Range'];
        // is this an ETag, or a HTTP date?
        if ($c[0] == '"' || substr($c, 0, 2) == 'W/')
            $r['if_etags_match'] = http_parse_etag($c);
        else
            $r['if_not_modified_since'] = http_decode_timestamp($c[0]);
        $r['if_range'] = true;
    }

    if (array_key_exists('Cache-Control', $h)) {
        $cc = explode_f(',', $h['Cache-Control'], 'http_parse_max_age');
        if (count($cc) > 0)
            $r['max_age'] = $cc[0];
    }

}

// form a relative URL derived from the request URL. relative and absolute paths are allowed.
function href($rel_path = null, $params = null, $fragment = null) {
	return concat(
		opt_s(url_encode_path(coalesce($rel_path, '/'.request_path()))),
		concat_opt('?', url_encode_query(is_null($params) ?
							request_query() : http_encode_params($params))),
		concat_opt('#', url_encode_fragment($fragment))
	);
}

// form a full URL derived from the request URL. only absolute paths are allowed, i.e.
// starting with '/'.
// ATTN: if scheme is set and port isn't, then port is not set to current request's port,
// it is set to null instead!
function full_href($path = null, $params = null, $https = null, $host = null,
					$port = null, $fragment = null) {
	assert(is_null($path) || substr($path, 0, 1) == '/');
	return url_format(array(
		'scheme' => is_null($https) ? request_url('scheme') : ($https ? 'https' : 'http'),
		'host' => coalesce($host, request_url('host')),
		'port' => cond(!is_null($scheme) && is_null($port), null, coalesce($port, request_url('port'))),
		'path' => cond(is_null($path), request_path(), substr($path, 1)),
		'query' => is_null($params) ? request_query() : http_encode_params($params),
		'fragment' => $fragment
	));
}

