require'strict'
require'python'

sites = {
	us = 'amazon.com',
	uk = 'amazon.co.uk',
	de = 'amazon.de',
	fr = 'amazon.fr',
	ca = 'amazon.ca',
	jp = 'amazon.co.jp',
	it = 'amazon.it',
	es = 'amazon.es',
}

amazon_seller_ids = {
	us = 'ATVPDKIKX0DER',
	uk = 'A3P5ROKL5A1OLE',
	de = 'A3JWKAKR8XB7XF',
	fr = 'A1X6FK5RDHNB96',
	ca = 'A3DWYIK6Y9EEQB',
	jp = 'AN1VRQENFRJN5',
	it = 'APJ6JRA9NG5V4',
	es = 'A1AT7YVPFBWXBL',
}

function geturl(country, asin, condition)
	return ('http://www.%s/gp/offer-listing/%s/?condition=%s'):format(sites[country], asin, condition)
end

local conditions_lang = {
	[u'New'] = 'new',
	[u'Used-Acceptable'] = 'used-acceptable',
	[u'Used-Good'] = 'used-good',
	[u'Used-VeryGood'] = 'used-verygood',
	[u'Used-LikeNew'] = 'used-likenew',
	[u'Refurbished'] = 'refurbished',
	[u'collectible'] = 'collectible',
	[u'Collectible-Acceptable'] = 'collectible-acceptable',
	[u'Collectible-LikeNew'] = 'collectible-likenew',
	[u'Collectible-VeryGood'] = 'collectible-verygood',
	[u'Collectible-Good'] = 'collectible-good',
	[u'Neu'] = 'new',
	[u'Gebraucht-Akzeptabel'] = 'used-acceptable',
	[u'Gebraucht-Gut'] = 'used-good',
	[u'Gebraucht-Sehrgut'] = 'used-verygood',
	[u'Gebraucht-Wieneu'] = 'used-likenew',
	[u'Sammlerst|fcck-Wieneu'] = 'collectible-likenew',
	[u'Sammlerst|fcck-Gut'] = 'collectible-good',
	[u'Sammlerst|fcck-Sehrgut'] = 'collectible-verygood',
	[u'Sammlerst|fcck-Akzeptabel'] = 'collectible-acceptable',
	[u'B-Ware&amp;2.Wahl'] = 'refurbished',
	[u'Neuf'] = 'new',
	[u'D\'occasion-Acceptable'] = 'used-acceptable',
	[u'D\'occasion-Bon'] = 'used-good',
	[u'D\'occasion-Tr|e8sbon'] = 'used-verygood',
	[u'D\'occasion-Commeneuf'] = 'used-likenew',
	[u'Decollection-Commeneuf'] = 'collectible-likenew',
	[u'Decollection-Bon'] = 'collectible-good',
	[u'Decollection-Tr|e8sbon'] = 'collectible-verygood',
	[u'Decollection-Acceptable'] = 'collectible-acceptable',
	[u'Reconditionn|e9'] = 'refurbished',
	[u'|90V|95i'] = 'new',
	[u'|92|86|8c|c3|95i-|89|c2'] = 'used-acceptable',
	[u'|92|86|8c|c3|95i-|82|d9|82|da|90V|95i'] = 'used-likenew',
	[u'|92|86|8c|c3|95i-|97|c7|82|a2'] = 'used-food',
	[u'|92|86|8c|c3|95i-|94|f1|8f|ed|82|c9|97|c7|82|a2'] = 'used-verygood',
	[u'|83R|83|8c|83N|83^|81[|8f|a4|95i-|97|c7|82|a2'] = 'collectible-good',
	[u'|83R|83|8c|83N|83^|81[|8f|a4|95i-|89|c2'] = 'collectible-acceptable',
	[u'|83R|83|8c|83N|83^|81[|8f|a4|95i-|82|d9|82|da|90V|95i'] = 'collectible-likenew',
	[u'|83R|83|8c|83N|83^|81[|8f|a4|95i-|94|f1|8f|ed|82|c9|97|c7|82|a2'] = 'collectible-verygood',
	[u'Nuovo'] = 'new',
	[u'Usato-Comenuovo'] = 'used-likenew',
	[u'Usato-Ottimecondizioni'] = 'used-verygood',
	[u'Usato-Buonecondizioni'] = 'used-good',
	[u'Usato-Condizioniaccettabili'] = 'used-acceptable',
	[u'Dacollezione-Comenuovo'] = 'collectible-likenew',
	[u'Dacollezione-Ottimecondizioni'] = 'collectible-verygood',
	[u'Dacollezione-Buonecondizioni'] = 'collectible-good',
	[u'Dacollezione-Condizioniaccettabili'] = 'collectible-acceptable',
	[u'Ricondizionato-Rimessoanuovo'] = 'refurbished',
	[u'Nuevo'] = 'new',
	[u'De2|aamano-Comonuevo'] = 'used-likenew',
	[u'De2|aamano-Muybueno'] = 'used-verygood',
	[u'De2|aamano-Bueno'] = 'used-good',
	[u'De2|aamano-Aceptable'] = 'used-acceptable',
	[u'Decoleccionista-Comonuevo'] = 'collectible-likenew',
	[u'Decoleccionista-Muybueno'] = 'collectible-verygood',
	[u'Decoleccionista-Bueno'] = 'collectible-good',
	[u'Decoleccionista-Aceptable'] = 'collectible-acceptable',
}

local function parse_cond(s)
	local cond = s:match'class="condition".->(.-)<'
	if cond then
		cond = conditions_lang[cond:gsub('%s', '')]
		if cond then return cond:split'%-' end
	end
end

local function parse_seller(s, country)
	local function normal()
		return s:match'class="sellerHeader".->.-seller=(.-)".-><b>(.-)</b>'
	end
	local function logo()
		return s:match'class="sellerInformation".-<a .- href=".-/shops/(.-)/.-alt="(.-)"'
	end
	local function amazon()
		if s:match'class="sellerInformation".-alt="Amazon.-"' then
			return amazon_seller_ids[country], sites[country], true
		end
	end
	local function amazonpref() --amazon preferred seller: same seller id as amazon, but different name
		local name = s:match'class="sellerInformation".-<a.->.-<b>(.-)</b>'
		if name then
			return amazon_seller_ids[country], name, true
		end
	end
	--just launched seller with logo and no alt attribute set on the img tag so no merchant name
   local function justlaunchedlogo()
		return s:match'class="sellerInformation".-<a .- href=".-seller=(.-)["&]', nil
	end
	for try in vals{normal,logo,amazon,amazonpref,justlaunchedlogo} do
		local id, name, is_amazon = try()
		if id then return id, name, is_amazon or false end
	end
end

local function parse_offer(s, country)
	local o = {}
	o.price = s:match'class="price".->.-(%d*[.,]%d*).-</span>'
	o.price_not_displayed = s:match'<span.->Price%s+not%s+displayed' and true
	o.shipping_price = s:match'class="price_shipping".->.-(%d*[.,]%d*).-</span>'
	o.shipping_not_available = s:match'class="word_shipping".->[^<]*unavailable' and true
	o.supersaver = s:match'target="SuperSaverShipping"' and true
	o.condition, o.subcondition = parse_cond(s, country)
	o.merchant_id, o.merchant_name, o.is_amazon = parse_seller(s, country)
	if not o.is_amazon then
		o.fba = s:findany{
			'class="popover2".->.-Fulfillment%s+by%s+Amazon',
			'class="popover2".->.-Fulfilled%s+by%s+Amazon',
			'class="popover2".->.-Versand%s+durch%s+Amazon.de',
			'class="popover2".->.-Spedito%s+da%s+Amazon',
		} and true
		o.marketplace_seller = bool('class="sellerHeader".->.-marketPlaceSeller=(%d)')
		o.comments = s:match'class="comments".->%s*(.-)%s*<'
		o.featured = false
   else
		o.featured = true
	end
	o.availability_note = s:match'class="availability".->%s*(.-)%s*<'
   o.expedited_shipping = o.availability_note:lower():findany{
		u'expedited shipping available.',
		u'expedited delivery available.',
		u'expressversand verf|fcgbar',
		u'exp|e9dition express disponible.',
		u'spedizione express disponibile.',
		u'env|edo urgente disponible.',
	} and true
   o.availability_time = s:match'<span%s+.-id%s*=%s*"shippingMessage_.-".->.-<b%s*>%s*(.-)%s*</b>'
	o. = s:match'class=\"availability\"[^>]*>(.*?)</div>'

	o.rating_percent, o.total_rating = s:match(u'OLPSellerRating.->.-(%d*)%s*%%.-%(%s*([%d.,|a0]*).-%)')


	return o
end

function parse(s, country, asin, condition)
	local res = {}
	--get number of offers from each tab
	for cond in vals{'new', 'used', 'refurbished', 'collectible'} do
		res[cond] = s:match('<td%s+id="'..cond..'".-<span%s+.-class="numberreturned".->[^%d<]*(%d+)')
		res[cond] = res[cond] and tonumber(res[cond])
	end
	--get page count from the page numbers below
	do
		local t = {}
		for v in s:gmatch('class="pagenumberon".->[^%d<]*(%d+)') do t[#t+1]=tonumber(v) end
		for v in s:gmatch('class="pagenumberoff".->[^%d<]*(%d+)') do t[#t+1]=tonumber(v) end
		res.pages = max(t)
	end
	--get offers
	res.offers = {}
	for ss in s:gmatch'<tbody%s+class="result".->(.-)</tbody>' do
		res.offers[#res.offers+1] = parse_offer(ss, country)
	end
	return res
end

function test_parse()
	require'httpclient'
	local requests = {
		{'us', '059035342X', 'used', 'harry potter penny book, tons of pages on used'},
		{'us', 'B004RTL1YY', 'new', 'tv with featured merchants'},
		{'us', 'B003KK6542', 'used', 'kindle book, redirects to descr. page'},
	}

	for _, req in ipairs(requests) do
		if req[2] ~= '059035342X' then break end
		local url = geturl(unpack(req))
		print(req[4], req[1])
		local s = assert(io.open('potter_used.htm', 'r')):read('*a')
		--s = getpage(url)
		--assert(io.open('potter_used2.htm', 'w')):write(s2)
		pp(parse(s, unpack(req)))
	end
end

if not ... then test_parse() end

