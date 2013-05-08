--grammar stolen from here: https://gist.github.com/2222960
--I use expat now.

local lpeg = require'lpeg'
local V, R, S, P, Cg, Cb = lpeg.V, lpeg.R, lpeg.S, lpeg.P, lpeg.Cg, lpeg.Cb
local setfenv = setfenv

local function XMLP(t)
	local function capture(name)
		return function(...)
			if t[name] then t[name](...) end
			return ...
		end
	end

	local grammar = { "document" }
	setfenv(1, grammar)

	-- S ::= (#x20 | #x9 | #xD | #xA)+
	SS = (S " \t\r\n")^1
	SSopt = SS ^ -1

	-- NameStartChar ::= ":" | [A-Z] | "_" | [a-z]
	NameStartChar = S ":_" + R ("az", "AZ")

	-- NameChar ::= NameStartChar | "-" | "." | [0-9]
	NameChar = NameStartChar + S "-." + R "09"

	-- Name ::= NameStartChar (NameChar)*
	Name = NameStartChar * NameChar^0

	-- Names ::= Name (#x20 Name)*
	Names = Name * (" " * Name)^0

	-- Nmtoken ::= (NameChar)+
	Nmtoken = NameChar^1

	-- Nmtokens ::= Nmtoken (#x20 Nmtoken)*
	Nmtokens = Nmtoken * (" " * Nmtoken)^0

	-- CharRef ::= '&#' [0-9]+ ';'
	--           | '&#x' [0-9a-fA-F]+ ';'
	CharRef = ("&#"  * (R "09")^1 * ";")
			  + ("&#x" * (R ("09", "af", "AF"))^1 * ";")

	-- EntityRef   ::= '&' Name ';'
	-- PEReference ::= '%' Name ';'
	-- Reference   ::= EntityRef | CharRef
	--
	EntityRef   = "&" * Name * ";"
	PEReference = "%" * Name * ";"
	Reference   = EntityRef + CharRef

	-- EntityValue ::= '"' ([^%&"] | PEReference | Reference)* '"'
	--               | "'" ([^%&'] | PEReference | Reference)* "'"
	EntityValue = ('"' * ((1 - S '%&"') + PEReference + Reference)^0 * '"')
					+ ("'" * ((1 - S "%&'") + PEReference + Reference)^0 * "'")

	-- AttValue ::= '"' ([^<&"] | Reference)* '"'
	--            | "'" ([^<&'] | Reference)* "'"
	AttValue = ('"' * Cg(((1 - S '<&"') + Reference)^0) * '"')
				+ ("'" * Cg(((1 - S "<&'") + Reference)^0) * "'")

	-- SystemLiteral ::= ('"' [^"]* '"') | ("'" [^']* "'")
	SystemLiteral = ('"' * (1 - P '"')^0 * '"')
					  + ("'" * (1 - P "'")^0 * "'")

	-- PubidChar ::= #x20 | #xD | #xA | [a-zA-Z0-9] | [-'()+,./:=?;!*#@$_%]
	PubidChar = S " \r\n-'()+,./:=?;!*#@$_%" + R ("az", "AZ", "09")

	-- PubidLiteral ::= '"' PubidChar* '"' | "'" (PubidChar - "'")* "'"
	PubidLiteral = ('"' * PubidChar^0 * '"')
					 + ("'" * (PubidChar - "'")^0 * "'")

	-- CharData ::= [^<&]* - ([^<&]* ']]>' [^<&]*)
	CharData = (1 - (S "<&" + "]]>"))^0  / capture'cdata'

	-- Comment ::= '<!--' ((Char - '-') | ('-' (Char - '-')))* '-->'
	Comment = "<!--"
			  * ((1 - S "-") + ("-" * (1 - S "-")))^0
			  * "-->"

	-- PITarget ::= Name - (('X' | 'x') ('M' | 'm') ('L' | 'l'))
	PITarget = Name - (S "xX" * S "mM" * S "lL")

	-- PI ::= '<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>'
	PI = "<?"
		* PITarget
		* (SS * (1 - P "?>")^1)^0
		* "?>"

	-- CDSect  ::= CDStart CData CDEnd
	-- CDStart ::= '<![CDATA['
	-- CData   ::= (Char* - (Char* ']]>' Char*))
	-- CDEnd   ::= ']]>'
	CData  = (1 - P "]]>")^0
	CDSect = "<![CDATA[" * CData * "]]>"

	-- prolog ::= XMLDecl Misc* (doctypedecl Misc*)?
	prolog = (V "XMLDecl") ^ -1
			 * (V "Misc")^0
			 * (V "doctypedecl" * (V "Misc")^0) ^ -1

	-- Eq ::= S? '=' S?
	Eq = SSopt * "=" * SSopt

	-- SDDecl ::= S 'standalone' Eq (("'" ('yes' | 'no') "'") | ('"' ('yes' | 'no') '"'))
	SDDecl = SS
			 * "standalone"
			 * Eq
			 * ( ("'" * (P "yes" + "no") * "'")
				+ ('"' * (P "yes" + "no") * '"')
				)

	-- XMLDecl ::= '<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'
	XMLDecl = "<?xml"
			  * V "VersionInfo"
			  * (V "EncodingDecl") ^ -1
			  * SDDecl ^ -1
			  * SSopt
			  * "?>"

	-- VersionNum ::= '1.0' | '1.1'
	VersionNum = P "1.0"
				  + P "1.1"

	-- VersionInfo ::= S 'version' Eq ("'" VersionNum "'" | '"' VersionNum '"')
	VersionInfo = SS
					* "version"
					* Eq
					* ( ("'" * VersionNum * "'")
					  + ('"' * VersionNum * '"')
					  )

	-- Misc ::= Comment | PI | S
	Misc = Comment + PI + SS

	-- doctypedecl ::= '<!DOCTYPE' S Name (S ExternalID)? S? ('[' intSubset ']' S?)? '>'
	doctypedecl = "<!DOCTYPE"
					* SS
					* Name
					* (SS * V "ExternalID") ^ -1
					* SSopt
					* ( "["
					  * V "intSubset"
					  * "]"
					  * SSopt
					  ) ^ -1
					* ">"

	BOM = P'\xef\xbb\xbf'
			+ P'\xfe\xff'
			+ P'\xff\xfe'
			+ P'\x00\x00\xfe\xff'
			+ P'\xff\xfe\x00\x00'

	-- document ::= ( prolog element Misc* )
	document = BOM^-1 * prolog * V "element" * Misc^0

	-- DeclSep ::= PEReference | S
	DeclSep = PEReference + SS

	-- choice ::= '(' S? cp ( S? '|' S? cp )+ S? ')'
	-- seq    ::= '(' S? cp ( S? ',' S? cp )* S? ')'
	choice = "(" * SSopt * V "cp" * (SSopt * "|" * SSopt * V "cp")^1 * SSopt * ")"
	seq    = "(" * SSopt * V "cp" * (SSopt * "," * SSopt * V "cp")^0 * SSopt * ")"

	-- cp ::= (Name | choice | seq) ('?' | '*' | '+')?
	cp = (Name + choice + seq) * (S "?*+") ^ -1

	-- children ::= (choice | seq) ('?' | '*' | '+')?
	children = (choice + seq) * (S "?*+") ^ -1

	-- Mixed ::= '(' S? '#PCDATA' (S? '|' S? Name)* S? ')*' | '(' S? '#PCDATA' S? ')'
	Mixed = "(" * SSopt * "#PCDATA" * (SSopt * "|" * SSopt * Name)^0 * SSopt * ")*"
			+ "(" * SSopt * "#PCDATA" * SSopt * ")"

	-- contentspec ::= 'EMPTY' | 'ANY' | Mixed | children
	contentspec = P "EMPTY" + P "ANY" + Mixed + children

	-- elementdecl ::= '<!ELEMENT' S Name S contentspec S? '>'
	elementdecl = "<!ELEMENT" * SS * Name * SS * contentspec * SSopt * ">"

	-- EnumeratedType ::= NotationType | Enumeration
	-- NotationType   ::= 'NOTATION' S '(' S? Name (S? '|' S? Name)* S? ')'
	-- Enumeration    ::= '(' S? Nmtoken (S? '|' S? Nmtoken)* S? ')'
	-- AttType        ::= StringType | TokenizedType | EnumeratedType
	-- StringType     ::= 'CDATA'
	-- TokenizedTyp e ::= 'ID' | 'IDREF' | 'IDREFS' | 'ENTITY' | 'ENTITIES'
	--                  | 'NMTOKEN' | 'NMTOKENS'
	--
	NotationType = "NOTATION" * SS * "(" * SSopt * Name * (SSopt * "|" * SSopt * Name)^0 * SSopt * ")"
	Enumeration = "(" * SSopt * Nmtoken * (SSopt * "|" * SSopt * Nmtoken)^0 * SSopt * ")"
	AttType = P "CDATA"
			  + P "ID"
			  + P "IDREF"
			  + P "IDREFS"
			  + P "ENTITY"
			  + P "ENTITIES"
			  + P "NMTOKEN"
			  + P "NMTOKENS"
			  + NotationType
			  + Enumeration

	-- DefaultDecl ::= '#REQUIRED' | '#IMPLIED' | (('#FIXED' S)? AttValue)
	DefaultDecl = P "#REQUIRED"
					+ P "#IMPLIED"
					+ (((P "#FIXED" * SS) ^ -1) * AttValue)

	-- AttDef ::= S Name S AttType S DefaultDecl
	AttDef = SS * Name * SS * AttType * SS * DefaultDecl

	-- AttlistDecl ::= '<!ATTLIST' S Name AttDef* S? '>'
	AttlistDecl = "<!ATTLIST" * SS * Name * AttDef^0 * SSopt * ">"

	-- ExternalID ::= 'SYSTEM' S SystemLiteral
	--              | 'PUBLIC' S PubidLiteral S SystemLiteral
	--
	ExternalID = "SYSTEM" * SS * SystemLiteral
				  + "PUBLIC" * SS * PubidLiteral * SS * SystemLiteral

	-- NDataDecl ::= S 'NDATA' S Name
	NDataDecl = SS * "NDATA" * SS * Name

	-- EntityDecl ::= GEDecl | PEDecl
	-- GEDecl     ::= '<!ENTITY' S Name S EntityDef S? '>'
	-- PEDecl     ::= '<!ENTITY' S '%' S Name S PEDef S? '>'
	-- EntityDef  ::= EntityValue | (ExternalID NDataDecl?)
	-- PEDef      ::= EntityValue | ExternalID
	--
	PEDef      = EntityValue + ExternalID
	EntityDef  = EntityValue + (ExternalID * NDataDecl ^ -1)
	GEDecl     = "<!ENTITY" * SS * Name * SS * EntityDef * SSopt * ">"
	PEDecl     = "<!ENTITY" * SS * "%" * SS * Name * SS * PEDef * SSopt * ">"
	EntityDecl = GEDecl + PEDecl

	-- PublicID ::= 'PUBLIC' S PubidLiteral
	PublicID = "PUBLIC" * SS * PubidLiteral

	-- NotationDecl ::= '<!NOTATION' S Name S (ExternalID | PublicID) S? '>'
	NotationDecl = "<!NOTATION" * SS * Name * SS * (ExternalID + PublicID) * SSopt * ">"

	-- markupdecl ::= elementdecl | AttlistDecl | EntityDecl | NotationDecl | PI | Comment
	markupdecl = elementdecl
				  + AttlistDecl
				  + EntityDecl
				  + NotationDecl
				  + PI
				  + Comment

	-- conditionalSect    ::= includeSect | ignoreSect
	-- includeSect        ::= '<![' S? 'INCLUDE' S? '[' extSubsetDecl ']]>'
	-- ignoreSect         ::= '<![' S? 'IGNORE' S? '[' ignoreSectContents* ']]>'
	-- ignoreSectContents ::= Ignore ('<![' ignoreSectContents ']]>' Ignore)*
	-- Ignore             ::= Char* - (Char* ('<![' | ']]>') Char*)
	--
	Ignore = (1 - (P "<![" + P "]]>"))
	ignoreSectContents = Ignore * ("<![" * V "ignoreSectContents" * "]]" * Ignore)^0
	conditionalSect = ("<![" * SSopt * "INCLUDE" * SSopt * "[" * V "extSubsetDecl" * "]]>")
						 + ("<![" * SSopt * "IGNORE"  * SSopt * "[" * ignoreSectContents^0 * "]]>")

	-- intSubset ::= (markupdecl | DeclSep)*
	intSubset = (markupdecl + DeclSep)^0

	-- extSubsetDecl ::= (markupdecl | conditionalSect | DeclSep)*
	extSubsetDecl = (markupdecl + conditionalSect + DeclSep)^0

	-- EncName ::= [A-Za-z] ([A-Za-z0-9._] | '-')*
	EncName = R ("AZ", "az") * ((R ("AZ", "az", "09") + S "._") + "-")^0

	-- EncodingDecl ::= S 'encoding' Eq ('"' EncName '"' | "'" EncName "'" )
	EncodingDecl = SS
					 * "encoding"
					 * Eq
					 * ( '"' * EncName * '"'
						+ "'" * EncName * "'"
						)

	-- TextDecl ::= '<?xml' VersionInfo? EncodingDecl S? '?>'
	TextDecl = "<?xml"
				* VersionInfo ^ -1
				* EncodingDecl
				* SSopt
				* "?>"

	-- extSubset ::= TextDecl? extSubsetDecl
	extSubset = TextDecl ^ -1
				 * extSubsetDecl

	-- Attribute ::= Name Eq AttValue
	Attribute = Cg(Name) * Eq * AttValue / capture'attr'

	-- STag ::= '<' Name (S Attribute)* S? '>'
	STag = "<" * Cg(Name, 'name') * (Cb'name' / capture'start_tag') * (SS * Attribute)^0 * SSopt * ">"
					* (Cb'name' / capture'end_start_tag')

	-- ETag ::= '</' Name S? '>'
	ETag = "</" * (Name / capture'end_tag') * SSopt * ">"

	-- EmptyElemTag ::= '<' Name (S Attribute)* S? '/>'
	EmptyElemTag = "<" * Cg(Name, 'name') * (Cb'name' / capture'start_tag')
								* (SS * Attribute)^0 * SSopt * "/>"
								* (Cb'name' / capture'end_start_tag')
								* (Cb'name' / capture'end_tag')

	-- elementdecl ::= EmptyElemTag | STag content ETag
	element = EmptyElemTag
			  + (STag * V "content" * ETag)

	--  content ::= CharData? ((element | Reference | CDSect | PI | Comment) CharData?)*
	content = CharData ^ -1
			  * ( ( element
					+ Reference
					+ CDSect
					+ PI
					+ Comment
					)
				 * CharData ^ -1
				 ) ^ 0

	return P (grammar)
end

if not ... then require'xmllpeg_test' end

return {
	P = XMLP
}

