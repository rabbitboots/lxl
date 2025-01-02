-- Test: Attributes in Elements


local PATH = ... and (...):match("(.-)[^%.]+$") or ""


require(PATH .. "test.strict")


local errTest = require(PATH .. "test.err_test")
local inspect = require(PATH .. "test.inspect")
local lxl = require(PATH .. "lxl")
local pretty = require(PATH .. "test_pretty")
local pUTF8 = require(PATH .. "pile_utf8")


local hex = string.char


local cli_verbosity
for i = 0, #arg do
	if arg[i] == "--verbosity" then
		cli_verbosity = tonumber(arg[i + 1])
		if not cli_verbosity then
			error("invalid verbosity value")
		end
	end
end


local self = errTest.new("xmlParser", cli_verbosity)


self:registerFunction("lxl.toTable()", lxl.toTable)


-- [===[
self:registerJob("Attribute Value Normalization", function(self)
	do
		local str = "<r a='\na b c\t'></r>"

		self:print(3, "[+] normalize whitespace (turn line feed, carriage return and h-tab into space)")
		self:print(4, str)
		local tree = lxl.toTable(str)
		self:print(4, pretty.print(tree))
		self:isEqual(tree.children[1].attr["a"], " a b c ")
	end
end
)
--]===]


--[========[
(Notes on ATTLIST)

AttlistDecl ::= '<!ATTLIST' S Name AttDef* S? '>'
	AttDef ::= S Name S AttType S DefaultDecl
		AttType ::= StringType | TokenizedType | EnumeratedType
			StringType ::= 'CDATA'
			TokenizedType ::= 'ID' |
				| 'IDREF'
				| 'IDREFS'
				| 'ENTITY'
				| 'ENTITIES'
				| 'NMTOKEN'
				| 'NMTOKENS'
			EnumeratedType ::= NotationType | Enumeration
				NotationType ::= 'NOTATION' S '(' S? Name (S? '|' S? Name)* S? ')'
				Enumeration ::= '(' S? Nmtoken (S? '|' S? Nmtoken)* S? ')'
		DefaultDecl	   ::=   	'#REQUIRED' | '#IMPLIED'
								| (('#FIXED' S)? AttValue)

local str = [=[
<!DOCTYPE root [
<!ATTLIST foo
	cdata    CDATA    #REQUIRED
	id       ID       #IMPLIED
	idref    IDREF    #FIXED 'foobar'
	entity   ENTITY   'foobar'
	entities ENTITIES #IMPLIED
	nmtoken  NMTOKEN  #IMPLIED
	nmtokens NMTOKENS #IMPLIED
	notation NOTATION (name1 | name2)
	enum              (nktoken1 | nmtoken2)
	>
]>
--]========]


-- [===[
self:registerJob("Attribute-List Declarations", function(self)

	-- [====[
	do
		local str = [=[
<!DOCTYPE root [
	<!ATTLIST root
		yer_name CDATA 'zoop'
	>
]>
<root></root>
]=]

		self:print(3, "[+] Apply a default value for an attribute (yer_name -> 'zoop')")
		self:print(4, str)
		local tree = lxl.toTable(str)
		local root = tree:getRoot()
		self:isEqual(tree.attr_defaults["root"]["yer_name"].default, "zoop")
		self:isEqual(tree.attr_defaults["root"]["yer_name"].type, "CDATA")
		self:isEqual(root.attr["yer_name"], "zoop")

	end
	--]====]


	-- [====[
	do
		local str = [=[
<!DOCTYPE root [
<!ATTLIST root
	yah_nom CDATA #FIXED 'zap'
>
]>
<root yah_nom="boop "></root>
]=]
		self:print(3, "[+] Ignore #FIXED default values for attributes that are already populated")
		self:print(4, str)
		local tree = lxl.toTable(str)
		local root = tree:getRoot()
		--self:print(4, pretty.print(tree))
		self:print(4, "attr_defaults: " .. inspect(tree.attr_defaults))
		self:print(4, "root attributes: " .. inspect(root.attr))
		self:isEqual(root.attr["yah_nom"], "boop ")
	end
	--]====]


	-- [====[
	do
		local str = [=[
<!DOCTYPE root [
<!ATTLIST root
	foo NMTOKEN #IMPLIED
>
]>
<root foo=" a  b  c "></root>
]=]

		self:print(3, "[+] Test non-CDATA attribute value normalization (delete leading and trailing; merge runs into one character)")
		self:print(4, str)
		local tree = lxl.toTable(str)
		local root = tree:getRoot()
		self:print(4, "attr_defaults: " .. inspect(tree.attr_defaults))
		self:print(4, "root attributes: " .. inspect(root.attr))
		self:isEqual(root.attr["foo"], "a b c")
	end
	--]====]


	-- [====[
	do
		-- §4.1 Character and Entity References
		-- Well-formedness constraint: Entity Declared
		-- "The declaration of a general entity MUST precede any reference to it which appears in a default value in an attribute-list declaration."
		local str = [=[
<!DOCTYPE root [
<!ATTLIST root
	foo NMTOKEN #FIXED 'foo&bar;'
>
<!ENTITY bar "...">
]>
<root></root>
]=]
		self:expectLuaError("general entity must be declared before being referenced in an attribute-list.", lxl.toTable, str)
	end
	--]====]


	-- [====[
	do
		local str = [=[
<!DOCTYPE root [
<!ENTITY bar "...">
<!ATTLIST root
	zyp NMTOKEN #FIXED 'foo&bar;'
>
]>
<root></root>
]=]

		self:print(3, "[+] Entity reference within default attribute value")
		self:print(4, str)
		local tree = lxl.toTable(str)
		local root = tree:getRoot()
		self:print(4, "attr_defaults: " .. inspect(tree.attr_defaults))
		self:print(4, "root attributes: " .. inspect(root.attr))
		self:isEqual(root.attr["zyp"], "foo...")
	end
	--]====]
end)


self:runJobs()
