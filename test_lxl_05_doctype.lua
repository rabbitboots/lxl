-- Test: DOCTYPE tags; 'standalone'; PEReferences; Unexpanded References


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
self:registerJob("DOCTYPE", function(self)
	-- [====[
	do
		local str = [=[
<!DOCTYPE root>
<root>blah</root>
]=]

		self:print(3, "[+] Minimum DOCTYPE)")
		self:print(4, str)
		local tree = lxl.toTable(str)
		local root = tree:getRoot()
		local doctype = tree:getDocType()
		self:print(4, pretty.print(doctype))
		self:isEqual(tree:getDocType().name, "root")
	end
	--]====]


	-- [====[
	do
		local str = "<!DOCTYPE foo SYSTEM 'syslit'><r/>"
		print("[+] DOCTYPE with SYSTEM Declaration: " .. str)
		local tree = lxl.toTable(str)
		self:print(4, pretty.print(tree.children[1]))
		self:isEqual(tree.children[1].external_id.type, "SYSTEM")
		self:isEqual(tree.children[1].external_id.system_literal, "syslit")
	end
	--]====]


	-- [====[
	do
		local str = "<!DOCTYPE foo PUBLIC 'publit' 'syslit'><r/>"
		print("[+] DOCTYPE with PUBLIC Declaration: " .. str)
		local tree = lxl.toTable(str)
		self:print(4, pretty.print(tree.children[1]))
		self:isEqual(tree.children[1].external_id.type, "PUBLIC")
		self:isEqual(tree.children[1].external_id.pub_id_literal, "publit")
		self:isEqual(tree.children[1].external_id.system_literal, "syslit")
	end
	--]====]


	-- NOTE: Non-Validating Processors don't need to compare the DOCTYPE name with the root element name.


	-- [====[
	self:expectLuaError("invalid internal subset", lxl.toTable, [=[
<!DOCTYPE r [ zoop ] >
<r></r>]=])
	--]====]


	-- [====[
	do
		local str = [=[
<!--before-->
<!DOCTYPE foo [
<!ENTITY non 'sense'>
<?proc1 one?>
<!ELEMENT e ANY>
<!--two-->
]>
<foo>
<?proc2 in document?>
</foo>
<!-- after -->
]=]

		self:print(3, "[+] Comments and PIs before, after, and embedded into the DTD internal subset")
		self:print(4, str)
		local tree = lxl.toTable(str)

		self:isEqual(tree.children[1].id, "comment")
		self:isEqual(tree.children[1].text, "before")

		self:isEqual(tree.children[2].id, "doctype")
		self:isEqual(tree.children[2].name, "foo")

		self:isEqual(tree.children[2].children[1].id, "pi")
		self:isEqual(tree.children[2].children[1].name, "proc1")
		self:isEqual(tree.children[2].children[1].text, "one")

		self:isEqual(tree.children[2].children[2].id, "comment")
		self:isEqual(tree.children[2].children[2].text, "two")

		self:isEqual(tree.children[3].id, "element")
		self:isEqual(tree.children[3].name, "foo")

		self:isEqual(tree.children[3].children[1].id, "cdata")
		self:isEqual(tree.children[3].children[1].text, "\n")

		self:isEqual(tree.children[3].children[2].id, "pi")
		self:isEqual(tree.children[3].children[2].name, "proc2")
		self:isEqual(tree.children[3].children[2].text, "in document")

		self:isEqual(tree.children[3].children[3].id, "cdata")
		self:isEqual(tree.children[3].children[3].text, "\n")

		self:isEqual(tree.children[4].id, "comment")
		self:isEqual(tree.children[4].text, " after ")
	end
	--]====]


	-- [====[
	do
		local str = [=[
<!DOCTYPE r [
<!ELEMENT foobar EMPTY>
<!ATTLIST foo aname NOTATION (foo | bar) #IMPLIED>
] >
<r></r>
]=]

		self:print(3, "[+] DOCTYPE, !ELEMENT, !ATTLIST")
		self:print(4, str)
		local tree = lxl.toTable(str)

		-- The default attribs table looks like this:
		--[=====[
		attr_defaults = {
			foo = {
				aname = {
					keyword = "#IMPLIED",
					type = { { "NOTATION", "(", "foo", "|", "bar", ")" } }
				}
			}
		}
		--]=====]

		self:isType(tree.attr_defaults, "table")
		self:isType(tree.attr_defaults["foo"], "table")
		self:isType(tree.attr_defaults["foo"]["aname"], "table")
		self:isEqual(tree.attr_defaults["foo"]["aname"].keyword, "#IMPLIED")

		-- For our purposes (Attribute-Value normalization), we only care if the
		-- attribute default type is the string "CDATA" or not.
		self:isNotEqual(tree.attr_defaults["foo"]["aname"].type, "CDATA")
	end
	--]====]


	-- [====[
	do
		local str = [=[
<!DOCTYPE r [
<!ELEMENT foobar EMPTY>
<!ATTLIST foo aname CDATA #REQUIRED>
<!ENTITY foo 'bar'>
<!ENTITY % baz 'bop'>
<!NOTATION foobar SYSTEM 'system_literal'>
<?somepi foo ?>
<!-- comment -->
]>
<r></r>
]=]

		self:print(3, "[+] All of 'markupdecl' in DOCTYPE")
		self:print(4, str)
		local tree = lxl.toTable(str)

		self:isEqual(tree.children[1].id, "doctype")
		self:isEqual(tree.children[1].name, "r")

		-- (!ELEMENT is parsed, but not included.)

		-- !ATTLIST
		self:isType(tree.attr_defaults["foo"], "table")
		self:isType(tree.attr_defaults["foo"]["aname"], "table")
		self:isEqual(tree.attr_defaults["foo"]["aname"].keyword, "#REQUIRED")
		self:isEqual(tree.attr_defaults["foo"]["aname"].type, "CDATA")

		-- !ENTITY
		self:isEqual(tree.g_entities["foo"], "bar")

		-- !ENTITY %
		self:isEqual(tree.p_entities["baz"], "bop")

		-- (!NOTATION is parsed, but not included.)

		-- Processing Instruction
		self:isEqual(tree.children[1].children[1].id, "pi")
		self:isEqual(tree.children[1].children[1].name, "somepi")
		self:isEqual(tree.children[1].children[1].text, "foo ")

		-- Comment
		self:isEqual(tree.children[1].children[2].id, "comment")
		self:isEqual(tree.children[1].children[2].text, " comment ")
	end
	--]====]


	-- [====[
	do
		local str = [=[
<!DOCTYPE r [

<!-- contentspec: EMPTY -->
<!ELEMENT e1 EMPTY>

<!-- contentspec: ANY -->
<!ELEMENT e2 ANY>

<!-- contentspec: Mixed -->
<!ELEMENT e3 (#PCDATA | foobar | bazbop)*>

<!-- contentspec: Children (choice) -->
<!ELEMENT e4 (foo | bar)>

<!-- contentspec: Children (choice with qty mark) -->
<!ELEMENT e5 (foo | bar)*>

<!-- contentspec: Children (seq) -->
<!ELEMENT e6 (foo, bar)>

<!-- contentspec: Children (seq with qty mark) -->
<!ELEMENT e7 (foo, bar)?>

<!-- cp ("content particle") variations -->
<!ELEMENT e8 (foo?, bar*, baz+)>
<!ELEMENT e9 (foo?|bar*|baz+)>

<!-- nested seq -->
<!ELEMENT e10 (foo, (bar | baz), (bop, zoop))>


<!-- contentspect: various 'Mixed' -->
<!ELEMENT e3 ( #PCDATA | foobar )*>
<!ELEMENT e3 ( #PCDATA | foobar | bazbop )*>
<!ELEMENT e3 ( #PCDATA )*>
<!ELEMENT e3 (#PCDATA)*>
<!ELEMENT e3 (#PCDATA)>
]>
<r></r>
]=]

		self:print(3, "[+] !ELEMENT variations")
		self:print(4, str)
		local tree = lxl.toTable(str)

		-- NOTE: None of these make it into the final tree. The test is considered a pass
		-- if lxl.toTable() completes without raising an error.
	end
	--]====]


	-- [====[
	self:expectLuaError("empty element declaration", lxl.toTable, [=[
<!DOCTYPE r [
<!ELEMENT>
]>
<r></r>
]=])
	--]====]


	-- [====[
	self:expectLuaError("choice missing final part", lxl.toTable, [=[
<!DOCTYPE r [
<!ELEMENT foobar (foo | )>
]>
<r></r>
]=])
	--]====]


	-- [====[
	self:expectLuaError("missing parentheses around PCDATA", lxl.toTable, [=[
<!DOCTYPE r [
<!ELEMENT e #PCDATA>
]>
<r></r>
]=])
	--]====]


	-- [====[
	self:expectLuaError("PCDATA missing last choice", lxl.toTable, [=[
<!DOCTYPE r [
<!ELEMENT e (#PCDATA | )*>
]>
<r></r>
]=])
	--]====]

end
)
--]===]


-- [===[
self:registerJob("DOCTYPE: Attribute Declarations", function(self)
	-- [====[
	do
		local str = [=[
<!DOCTYPE r [
<!ATTLIST f1>
<!ATTLIST f2 aname CDATA #REQUIRED>
<!ATTLIST f3 aname CDATA #IMPLIED>
<!ATTLIST f4 aname CDATA #FIXED 'foo'>
<!ATTLIST f5 aname CDATA "foo">
<!ATTLIST f6 aname ID #REQUIRED>
<!ATTLIST f7 aname IDREF #REQUIRED>
<!ATTLIST f8 aname IDREFS #REQUIRED>
<!ATTLIST f9 aname ENTITY #REQUIRED>
<!ATTLIST f10 aname ENTITIES #REQUIRED>
<!ATTLIST f11 aname NMTOKEN #REQUIRED>
<!ATTLIST f12 aname NMTOKENS #REQUIRED>
<!ATTLIST f13 aname NOTATION (foo | bar) #IMPLIED>
<!ATTLIST f13 aname (foo | bar) #IMPLIED>
<!ATTLIST f14
	a1 CDATA #IMPLIED
	a2 CDATA #REQUIRED
	a3 CDATA #FIXED 'foo'
	a4 CDATA 'bar'
>
]>
<r/>
]=]

		self:print(3, "[+] Various !ATTLIST declarations")
		self:print(4, str)
		local tree = lxl.toTable(str)
	end
	--]====]


	-- [====[
	self:expectLuaError("missing Attribute Type in list (1)", lxl.toTable, [=[<!DOCTYPE r [<!ATTLIST foo CDATA #REQUIRED>]><r/>]=])
	self:expectLuaError("missing Attribute Type in list (2)", lxl.toTable, [=[<!DOCTYPE r [<!ATTLIST foo CDATA #IMPLIED>]><r/>]=])
	self:expectLuaError("missing Attribute Type in list (3)", lxl.toTable, [=[<!DOCTYPE r [<!ATTLIST foo CDATA #FIXED 'bar'>]><r/>]=])
	--]====]


	-- [====[
	self:expectLuaError("bad attribute type", lxl.toTable, [=[<!DOCTYPE r [<!ATTLIST foo CDADA #REQUIRED>]><r/>]=])
	--]====]

	-- [====[
	self:expectLuaError("empty notation section", lxl.toTable, [=[<!DOCTYPE r [<!ATTLIST foo NOTATION () #REQUIRED>]><r/>]=])
	--]====]
end)
--]===]


-- [===[
self:registerJob("DOCTYPE: PEReferences", function(self)
	-- [====[
	do
		local str = [=[
<?xml version="1.0" standalone="no"?>
<!DOCTYPE r [
<!ENTITY % p '<!ENTITY foo "bar">'>
%p;
<!ENTITY zip "zop">
]>
<r>&zip;</r>
]=]

		self:print(3, "[+] Skipping PEReference causes 'unexpanded entity' object creation")
		self:print(4, str)
		local tree = lxl.toTable(str)
		print(pretty.print(tree.children[2].children[1]))
		self:isEqual(tree.children[2].children[1].id, "unexp")
		self:isEqual(tree.children[2].children[1].name, "zip")
	end
	--]====]


	-- [====[
	do
		local str = [=[
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE r [
<!ENTITY % p '<!ENTITY foo "bar">'>
%p;
<!ENTITY zip "zop">
]>
<r>&zip;</r>
]=]

		self:print(3, "[+] standalone='yes' forces the XML Processor to read declarations after PEReference")
		self:print(4, str)
		local tree = lxl.toTable(str)
		print(pretty.print(tree.children[2].children[1]))
		self:isEqual(tree.children[2].children[1].id, "cdata")
		self:isEqual(tree.children[2].children[1].text, "zop")
	end
	--]====]


	-- [====[
	do
		local str = [=[
<?xml version="1.0"?>
<!DOCTYPE r [
<!ENTITY % p '<!ENTITY foo "bar">'>
%p;
]>
<r>&zip;</r>
]=]

		self:print(3, "[+] standalone='no' or undefined: undeclared entities are permitted *if* we chose to ignore at least one PEReference")
		local tree = lxl.toTable(str)
		self:isEqual(tree.children[2].children[1].id, "unexp")
		self:isEqual(tree.children[2].children[1].name, "zip")
	end
	--]====]


	-- [====[
	self:expectLuaError("standalone='yes': no undeclared entities are allowed", lxl.toTable, [=[
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE r [
<!ENTITY % p '<!ENTITY foo "bar">'>
%p;
]>
<r>&zip;</r>
]=])
	--]====]


	-- [====[
	self:expectLuaError("bad PEReference Name (1)", lxl.toTable, [=[
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE r [
%bad~name;
]>
<r/>
]=])
	--]====]


	-- [====[
	self:expectLuaError("bad PEReference Name (2)", lxl.toTable, [=[
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE r [
%;
]>
<r/>
]=])
	--]====]
end)
--]===]


-- [===[
self:registerJob("DOCTYPE: PEReferences", function(self)
	-- [====[
	do
		local str = [=[
<!DOCTYPE r [

<!-- GEDecl -->
<!ENTITY g1 'bar'>
<!ENTITY g2 SYSTEM 'bar'>
<!ENTITY g3 SYSTEM 'bar' NDATA baz>
<!ENTITY g4 PUBLIC 'bar' 'baz'>
<!ENTITY g5 PUBLIC 'bar' 'baz' NDATA bop>

<!-- PEDecl -->
<!ENTITY % p1 'bar'>
<!ENTITY % p2 SYSTEM 'bar'>
<!ENTITY % p3 PUBLIC 'bar' 'baz'>
]>
<r/>
]=]

		self:print(3, "[+] Various !ENTITY declarations")
		self:print(4, str)
		local tree = lxl.toTable(str)
	end
	--]====]

	-- [====[
	self:expectLuaError("unclosed tag", lxl.toTable, [=[<!DOCTYPE r [ <!ENTITY ]><r></r>]=])
	self:expectLuaError("missing name", lxl.toTable, [=[<!DOCTYPE r [ <!ENTITY 'bar']><r></r>]=])
	self:expectLuaError("invalid NDATA in PEDecl", lxl.toTable, [=[<!DOCTYPE r [ <!ENTITY % foo PUBLIC 'bar' 'baz' NDATA bop>]><r></r>]=])
	--]====]

end)
--]===]


-- [===[
self:registerJob("DOCTYPE: ExternalID syntax", function(self)
	-- [====[
	do
		local str = [=[
<!DOCTYPE r [
<!ENTITY f1 SYSTEM 'single-quotes'>
<!ENTITY f2 SYSTEM "double-quotes">
<!ENTITY f3 PUBLIC 'foobar' 'bazbop'>
<!ENTITY f4 PUBLIC 'foobar' 'bazbop' NDATA zop>
]>
<r/>]=]

		self:print(3, "[+] Various ExternalID values")
		self:print(4, str)
		local tree = lxl.toTable(str)
		print(pretty.print(tree))
		print(inspect(tree.g_entities))
		self:isEqual(tree.g_entities["f1"].id, "entity_def")
	end
	--]====]

	-- [====[
		self:expectLuaError("missing SYSTEM's SystemLiteral", lxl.toTable, [=[
<!DOCTYPE r [
<!ENTITY f1 SYSTEM >
]>
<r/>
]=])
	--]====]


	-- [====[
		self:expectLuaError("missing quote", lxl.toTable, [=[
<!DOCTYPE r [
<!ENTITY f1 SYSTEM 'foobar >
]>
<r/>
]=])
	--]====]


	-- [====[
		self:expectLuaError("missing PUBLIC's PubidLiteral", lxl.toTable, [=[
<!DOCTYPE r [
<!ENTITY f1 PUBLIC >
]>
<r/>
]=])
	--]====]


	-- [====[
		self:expectLuaError("missing PUBLIC's SystemLiteral", lxl.toTable, [=[
<!DOCTYPE r [
<!ENTITY f1 PUBLIC 'foobar'>
]>
<r/>
]=])
	--]====]
end)
--]===]


-- [===[
self:registerJob("DOCTYPE: <!NOTATION>", function(self)
	-- [====[
	do
		local str = [=[
<!DOCTYPE r [
<!NOTATION foobar SYSTEM 'system_literal'>
<!NOTATION foobar PUBLIC 'pubid-literal' 'system_literal'>
<!NOTATION foobar PUBLIC 'pubid-literal'>
]>
<r/>
]=]

		self:print(3, "various <!NOTATION> declarations")
		self:print(4, str)
		local tree = lxl.toTable(str)
		-- There is nothing to check, as Notation Declarations are parsed, but not attached
		-- to the output. If we have reached this point, then the test is considered
		-- successful.
	end
	--]====]


	-- [====[
	self:expectLuaError("Incorrect opening word", lxl.toTable, [=[<!DOCTYPE r [<!NATOTION foobar SYSTEM 'system_literal'>]></r>]=])
	self:expectLuaError("Bad Name", lxl.toTable, [=[<!DOCTYPE r [<!NOTATION foo~bar SYSTEM 'system_literal'>]></r>]=])
	self:expectLuaError("Incomplete declaration 1", lxl.toTable, [=[<!DOCTYPE r [<!NOTATION>]></r>]=])
	self:expectLuaError("Incomplete declaration 2", lxl.toTable, [=[<!DOCTYPE r [<!NOTATION >]></r>]=])
	self:expectLuaError("Incomplete declaration 3", lxl.toTable, [=[<!DOCTYPE r [<!NOTATION name>]></r>]=])
	self:expectLuaError("Incomplete declaration 4", lxl.toTable, [=[<!DOCTYPE r [<!NOTATION name SYSTEM>]></r>]=])
	self:expectLuaError("Incomplete declaration 5", lxl.toTable, [=[<!DOCTYPE r [<!NOTATION name SYSTEM >]></r>]=])
	self:expectLuaError("Incomplete declaration 6", lxl.toTable, [=[<!DOCTYPE r [<!NOTATION name PUBLIC>]></r>]=])
	self:expectLuaError("Incomplete declaration 7", lxl.toTable, [=[<!DOCTYPE r [<!NOTATION name PUBLIC >]></r>]=])
	--]====]
end)
--]===]


-- [===[
self:registerJob("DOCTYPE: PubidLiteral syntax", function(self)
	-- [====[
	do
		local str = [=[<!DOCTYPE r [<!ENTITY foobar PUBLIC 'abc' 'def'>]><r/>]=]

		self:print(3, "good PutidLiteral syntax")
		self:print(4, str)
		local tree = lxl.toTable(str)
		print(pretty.print(tree))
		self:isEqual(tree.g_entities["foobar"].id, "entity_def")
		self:isEqual(tree.g_entities["foobar"].value.id, "external_id")
		self:isEqual(tree.g_entities["foobar"].value.type, "PUBLIC")
		self:isEqual(tree.g_entities["foobar"].value.pub_id_literal, "abc")
		self:isEqual(tree.g_entities["foobar"].value.system_literal, "def")
	end
	--]====]


	-- [====[
	self:expectLuaError("wrong opening literal", lxl.toTable,     [=[ <!DOCTYPE r [ <!NOTATION n public 'abc' 'def'> ] > <r/> ]=])
	self:expectLuaError("invalid PubidLiteral", lxl.toTable,      [=[ <!DOCTYPE r [ <!NOTATION n PUBLIC 'a~b' 'def'> ] > <r/> ]=])
	self:expectLuaError("PubidLiteral bad quoting", lxl.toTable,  [=[ <!DOCTYPE r [ <!NOTATION n PUBLIC "abc' 'def'> ] > <r/> ]=])
	self:expectLuaError("SystemLiteral bad quoting", lxl.toTable, [=[ <!DOCTYPE r [ <!NOTATION n PUBLIC "abc" 'def"> ] > <r/> ]=])

	self:expectLuaReturn("Empty PubidLiteral", lxl.toTable,        [=[ <!DOCTYPE r [ <!NOTATION n PUBLIC "" 'def'>    ] > <r/> ]=])
	self:expectLuaReturn("Empty SystemLiteral", lxl.toTable,       [=[ <!DOCTYPE r [ <!NOTATION n PUBLIC 'abc' "">       ] > <r/> ]=])

	do
		-- #x20 | #xD | #xA | [a-zA-Z0-9] | [-'()+,./:=?;!*#@$_%]
		local str = "<!NOTATION n PUBLIC \"\32\13\10abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-'()+,./:=?;!*#@$_%\" \"syslit\">"
		self:expectLuaReturn("PubidLiteral: every permitted character", lxl.toTable, "<!DOCTYPE r [" .. str .. "]><r/>")
	end
	--]====]
end)
--]===]


-- [===[
self:registerJob("DOCTYPE: some additional <!ENTITY> syntax tests", function(self)
-- [9] EntityValue ::= '"' ([^%&"] | PEReference | Reference)* '"'
--                     | "'" ([^%&'] | PEReference | Reference)* "'"
	-- [=[
	print("sym.EntityValue")
	do
		local str =[=[
<!DOCTYPE r [
<!ENTITY e "&lt;XY&amp;Z&gt;">
]>
<r>&e;</r>
]=]

		self:print(3, "References in EntityValues should be bypassed")
		self:print(4, str)
		local tree = lxl.toTable(str)
		print(pretty.print(tree))
		self:isEqual(tree.g_entities["e"], "&lt;XY&amp;Z&gt;")
		self:isEqual(tree.children[2].children[1].text, "<")
		self:isEqual(tree.children[2].children[2].text, "XY")
		self:isEqual(tree.children[2].children[3].text, "&")
		self:isEqual(tree.children[2].children[4].text, "Z")
		self:isEqual(tree.children[2].children[5].text, ">")
		self:isNil(tree.children[2].children[6])
	end
	--]=]


	-- [====[
	self:expectLuaReturn("single quotes", lxl.toTable, "<!DOCTYPE r [<!ENTITY e 'a'>]><r/>")
	self:expectLuaReturn("double quotes", lxl.toTable, "<!DOCTYPE r [<!ENTITY e \"a\">]><r/>")
	self:expectLuaReturn("no content between quotes", lxl.toTable, "<!DOCTYPE r [<!ENTITY e \"\">]><r/>")
	self:expectLuaReturn("angle brackets are OK in EntityValues", lxl.toTable, "<!DOCTYPE r [<!ENTITY e '<>< ><  ><   ><  >< ><>'>]><r/>")
	self:expectLuaError("Broken Reference", lxl.toTable, "<!DOCTYPE r [<!ENTITY r 'XY&f00fZ'>]><r/>")
	self:expectLuaError("Broken PEReference", lxl.toTable, "<!DOCTYPE r [<!ENTITY r '%'>]><r/>")
	self:expectLuaError("PEReferences in markupdecl in the internal DTD are not allowed", lxl.toTable, "<!DOCTYPE r [<!ENTITY r 'foo%bar;'>]><r/>")
	--]====]
end)


self:runJobs()
