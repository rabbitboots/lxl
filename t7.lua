-- Test: XML Bomb mitigations (string expansion macro attacks)


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
self:registerJob("(Small) XML Bomb", function(self)
	-- Just to demonstrate what happens.

	local ok, tree, root

	local str_thousand_laughs = [=[
<!DOCTYPE zyp [
<!ENTITY foo "bar">
<!ENTITY foo1 "&foo;&foo;&foo;&foo;&foo;">
<!ENTITY foo2 "&foo1;&foo1;&foo1;&foo1;&foo1;">
<!ENTITY foo3 "&foo2;&foo2;&foo2;&foo2;&foo2;">
]>
<zyp>&foo3;</zyp>]=]

	self:print(3, "[+] expand three levels deep to 376 characters")
	self:print(4, str_thousand_laughs)
	local tree = xml.toTable(str_thousand_laughs)
	local root = tree:getRoot()
	self:print(4, root.children[1])
end
)
--]===]


-- [===[
-- https://en.wikipedia.org/wiki/Billion_laughs_attack
self:registerJob("Mitigation against XML Bombs", function(self)
	local xml_bomb = [=[
<?xml version="1.0"?>
<!DOCTYPE lolz [
 <!ENTITY lol "lol">
 <!ENTITY lol1 "&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;">
 <!ENTITY lol2 "&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;&lol1;">
 <!ENTITY lol3 "&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;&lol2;">
 <!ENTITY lol4 "&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;&lol3;">
 <!ENTITY lol5 "&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;&lol4;">
 <!ENTITY lol6 "&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;&lol5;">
 <!ENTITY lol7 "&lol6;&lol6;&lol6;&lol6;&lol6;&lol6;&lol6;&lol6;&lol6;&lol6;">
 <!ENTITY lol8 "&lol7;&lol7;&lol7;&lol7;&lol7;&lol7;&lol7;&lol7;&lol7;&lol7;">
 <!ENTITY lol9 "&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;&lol8;">
]>
<lolz>&lol9;</lolz>]=]

	local parser = xml.newParser()
	parser:setMaxEntityBytes(32768)
	local ok, tree = self:expectLuaError("Stop Billion Laughs Attack after 32 KiB of replacement text", parser.toTable, parser, xml_bomb)
	--local tree = parser:toTable(xml_bomb)
	--print(inspect(tree))
end
)
--]===]

self:runJobs()
