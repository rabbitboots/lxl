-- Test: General Entity References; Character References


local PATH = ... and (...):match("(.-)[^%.]+$") or ""


require(PATH .. "test.lib.strict")


local errTest = require(PATH .. "test.lib.err_test")
local inspect = require(PATH .. "test.lib.inspect.inspect")
local pretty = require(PATH .. "test_pretty")
local utf8Tools = require(PATH .. "xml_lib.utf8_tools")
local xml = require(PATH .. "xml")


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


self:registerFunction("xml.toTable()", xml.toTable)


-- [===[
self:registerJob("General Entity References (&foo;) in content", function(self)

	-- [====[
	do
		local str = [=[
<!DOCTYPE root [
<!ENTITY one "that's the one.">
]>
<root>where? oh, &one;</root>]=]

		self:print(3, "[+] custom General Entity")
		self:print(4, str)
		local tree = xml.toTable(str)
		self:print(4, pretty.print(tree))
		self:isEqual(tree.children[2].children[1].text, "where? oh, ")
		self:isEqual(tree.children[2].children[2].text, "that's the one.")
	end
	-- ]====]


	-- [====[
	do
		local str = [=[
<!DOCTYPE root [
<!ENTITY one "that makes &two;.">
<!ENTITY two "two of us">
]>
<root>where? oh, &one;</root>]=]

		self:print(3, "[+] nested General Entity References (1)")
		self:print(4, str)
		local tree = xml.toTable(str)
		self:print(4, pretty.print(tree))
		self:isEqual(tree.children[2].children[1].text, "where? oh, ")
		self:isEqual(tree.children[2].children[2].text, "that makes ")
		self:isEqual(tree.children[2].children[3].text, "two of us")
	end
	--]====]

	-- [====[
	do
		local str = [=[
<!DOCTYPE root [
<!ENTITY primary "check the &secondary; path">
<!ENTITY secondary "auxiliary">
]>
<root>he told me to tell you to &primary;.</root>]=]

		self:print(3, "[+] nested General Entity References (2)")
		self:print(4, str)
		local tree = xml.toTable(str)
		self:isEqual(tree.children[2].children[1].text, "he told me to tell you to ")
		self:isEqual(tree.children[2].children[2].text, "check the ")
		self:isEqual(tree.children[2].children[3].text, "auxiliary")
		self:isEqual(tree.children[2].children[4].text, " path")
	end
	--]====]


	-- [====[
	do
		local str = [=[
<?xml version="1.0"?>
<!DOCTYPE x [
 <!ENTITY y "y">
 <!ENTITY z "&y;&y;">
]>
<x>&z;</x>]=]

		self:print(3, "[+] nested General Entity References (3).")
		self:print(4, str)
		local tree = xml.toTable(str)
		self:isEqual(tree.children[2].children[1].text, "y")
		self:isEqual(tree.children[2].children[2].text, "y")
	end
	--]====]


	-- [====[
	self:expectLuaError("disallowed recursion (direct) in a General Entity", xml.toTable, [=[
<!DOCTYPE root [
<!ENTITY alpha "it's an &alpha;.">
]>
<root>&alpha;</root>]=])
	--]====]


	-- [====[
	self:expectLuaError("undeclared custom General Entity", xml.toTable, [=[<root>&alpha;</root>]=])
	--]====]


	-- [====[
	self:expectLuaError("disallowed recursion (indirect) in a General Entity", xml.toTable, [=[
<!DOCTYPE root [
<!ENTITY a1 "Ask &a2; about this.">
<!ENTITY a2 "Ask &a1; about that.">
]>
<root>Oh? &a1;</root>]=])
	--]====]


	-- [====[
	self:expectLuaError("unbalanced content within General Entity", xml.toTable, [=[
<!DOCTYPE root [
<!ENTITY dr "drink</p>">
]>
<root>
	<p>pass the fizzy &dr;
</root>]=])
	--]====]


	-- [====[
	do
		self:print(3, "[+] test every valid predefined entity declaration.")

		-- See: §4.6 Predefined Entities
		-- https://www.w3.org/TR/REC-xml/#sec-predefined-ent

		-- The following code builds small XML documents with every possible valid predefined entity declaration.

		local xml_pd_base1 = [[<!DOCTYPE root [<!ENTITY XX "YY">]><root>&XX;</root>]]
		local xml_pd_base2 = [[<!DOCTYPE root [<!ENTITY XX 'YY'>]><root>&XX;</root>]] -- (single-quotes version)

		local _pd = {
			lt = {"&#38;#60;", "&#x26;#60;", "&#38;#x3c;", "&#x26;#x3c;"},
			gt = {">", "&#62;", "&#38;#62;", "&#x3e;", "&#38;#x3e;", "&#x26;#x3e;"},
			amp = {"&#38;#38;", "&#x26;#38;", "&#38;#x26;", "&#x26;#x26;"},
			apos = {"'", "&#39;", "&#38;#39;", "&#x27;", "&#38;#x27;", "&#x26;#x27;"},
			quot = {"\"", "&#34;", "&#38;#34;", "&#x22;", "&#38;#x22;", "&#x26;#x22;"}
		}

		for k, pd in pairs(_pd) do
			for j, str in ipairs(pd) do
				--print("*", k, j, str)
				local xml_pd = str:find("\"") and xml_pd_base2 or xml_pd_base1
				xml_pd = xml_pd:gsub("XX", k):gsub("YY", str)
				print(xml_pd)
				local xml_obj = xml.toTable(xml_pd)
				-- We don't need to check the resulting values, since predefined general entities
				-- have their own codepath that runs before the custom entity path is considered.
			end
		end
	end
	--]====]


	-- [====[
	do
		self:print(3, "[-] test some invalid predefined entity declarations.")

		self:expectLuaError("bad amp declaration", xml.toTable, [[
<!DOCTYPE root [<!ENTITY amp "&#38;">]><root>&amp;</root>]])

		self:expectLuaError("bad amp declaration (2)", xml.toTable, [[
<!DOCTYPE root [<!ENTITY amp "&">]><root>&amp;</root>]])

		self:expectLuaError("bad amp declaration (3)", xml.toTable, [[
<!DOCTYPE root [<!ENTITY amp "a">]><root>&amp;</root>]])

		self:expectLuaError("bad gt declaration", xml.toTable, [[
<!DOCTYPE root [<!ENTITY gt "Weee!">]><root>&gt;</root>]])
	end
	--]====]


	do
		self:expectLuaError("unparsed entities cannot be dereferenced (&;) (Content)", xml.toTable, [=[
<!DOCTYPE r [
<!ENTITY fodorz SYSTEM "https://www.example.com/" NDATA pretend_thing>
]>
<r>...&fodorz;...</r>]=])
	end
end
)
--]===]


-- [===[
self:registerJob("General Entity References (&foo;) in attribute values", function(self)
	do
		local str = [=[
<!DOCTYPE r [
<!ENTITY fodorz SYSTEM "https://www.example.com/" NDATA pretend_thing>
]>
<r a="&fodorz;"></r>]=]
		self:expectLuaError("unparsed entities cannot be dereferenced (&;) (AttValue)", xml.toTable, str)
	end
end
)
--]===]


-- [===[
self:registerJob("Character References (&#N;, &#xN;)", function(self)
	self:expectLuaError("invalid Character Reference (dec) (content)", xml.toTable, [=[<r>&#;</r>]=])
	self:expectLuaError("invalid Character Reference (dec) (content)", xml.toTable, [=[<r>&#0;</r>]=])
	self:expectLuaError("invalid Character Reference (dec) (content)", xml.toTable, [=[<r>&#999999999999;</r>]=])
	self:expectLuaError("invalid Character Reference (dec) (content)", xml.toTable, [=[<r>&#-1;</r>]=])
	self:expectLuaError("invalid Character Reference (dec) (content)", xml.toTable, [=[<r>&#woop;</r>]=])
	self:expectLuaError("invalid Character Reference (dec) (content)", xml.toTable, [=[<r>&#x;</r>]=])
	self:expectLuaError("invalid Character Reference (hex) (content)", xml.toTable, [=[<r>&#x0;</r>]=])
	self:expectLuaError("invalid Character Reference (hex) (content)", xml.toTable, [=[<r>&#xfffffffffffff;</r>]=])
	self:expectLuaError("invalid Character Reference (hex) (content)", xml.toTable, [=[<r>&#x-1;</r>]=])
	self:expectLuaError("invalid Character Reference (hex) (content)", xml.toTable, [=[<r>&#xwoop;</r>]=])

	self:expectLuaError("invalid Character Reference (dec) (AttValue)", xml.toTable, [=[<r a="&#;"></r>]=])
	self:expectLuaError("invalid Character Reference (dec) (AttValue)", xml.toTable, [=[<r a="&#0;"></r>]=])
	self:expectLuaError("invalid Character Reference (dec) (AttValue)", xml.toTable, [=[<r a="&#999999999999;"></r>]=])
	self:expectLuaError("invalid Character Reference (dec) (AttValue)", xml.toTable, [=[<r a="&#-1;"></r>]=])
	self:expectLuaError("invalid Character Reference (dec) (AttValue)", xml.toTable, [=[<r a="&#woop;"></r>]=])
	self:expectLuaError("invalid Character Reference (hex) (AttValue)", xml.toTable, [=[<r a="&#x;"></r>]=])
	self:expectLuaError("invalid Character Reference (hex) (AttValue)", xml.toTable, [=[<r a="&#x0;"></r>]=])
	self:expectLuaError("invalid Character Reference (hex) (AttValue)", xml.toTable, [=[<r a="&#xfffffffffffff;"></r>]=])
	self:expectLuaError("invalid Character Reference (hex) (AttValue)", xml.toTable, [=[<r a="&#x-1;"></r>]=])
	self:expectLuaError("invalid Character Reference (hex) (AttValue)", xml.toTable, [=[<r a="&#xwoop;"></r>]=])


	-- [====[
	do
		local str = [=[<r>&#65;&#66;&#67;&#68;&#69;&#x61;&#x62;&#x63;&#x64;&#x65;</r>]=]

		self:print(3, "[+] valid character references (in Content).")
		self:print(4, str)
		local tree = xml.toTable(str)
		self:isEqual(tree.children[1].children[1].text, "A")
		self:isEqual(tree.children[1].children[2].text, "B")
		self:isEqual(tree.children[1].children[3].text, "C")
		self:isEqual(tree.children[1].children[4].text, "D")
		self:isEqual(tree.children[1].children[5].text, "E")

		self:isEqual(tree.children[1].children[6].text, "a")
		self:isEqual(tree.children[1].children[7].text, "b")
		self:isEqual(tree.children[1].children[8].text, "c")
		self:isEqual(tree.children[1].children[9].text, "d")
		self:isEqual(tree.children[1].children[10].text, "e")
	end
	--]====]


	-- [====[
	do
		local str = [=[<r a="&#65;&#66;&#67;&#68;&#69;&#x61;&#x62;&#x63;&#x64;&#x65;"></r>]=]

		self:print(3, "[+] valid character references (in AttValue).")
		self:print(4, str)
		local tree = xml.toTable(str)
		self:isEqual(tree.children[1].attr["a"], "ABCDEabcde")
	end
	--]====]
end
)
--]===]


self:runJobs()
