-- Test: XML basics; Names; CData; CDSect


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
self:registerJob("XML basics", function(self)

	-- [====[
	do
		local tree = self:expectLuaReturn("empty root", lxl.toTable, "<r></r>")
		self:print(4, pretty.print(tree))
	end
	--]====]


	-- [====[
	do
		local tree = self:expectLuaReturn("empty root with empty tag", lxl.toTable, "<r/>")
		self:print(4, pretty.print(tree))
	end
	--]====]


	-- [====[
	self:expectLuaError("element tag name mismatch", lxl.toTable, "<r></s>")
	--]====]


	-- [====[
	self:expectLuaError("Character Data after root element", lxl.toTable, "<test><foo></foo></test> asdf")
	self:expectLuaError("multiple elements at top level", lxl.toTable, "<r1/><r2/>")
	self:expectLuaReturn("Trailing whitespace is OK", lxl.toTable, "<test><foo></foo></test>    ")
	--]====]

	-- [====[
	do
		local tree = self:expectLuaReturn("attributes", lxl.toTable, [=[<r a="x" b='y' c="z" empty=''></r>]=])
		self:print(4, pretty.print(tree))
	end
	--]====]


	-- [====[
	self:expectLuaError("duplicate attribute keys", lxl.toTable, [=[<r a="x" b="y" b="z"></r>]=])
	--]====]


	-- [====[
	self:expectLuaError("attribute value quote mismatch", lxl.toTable, [=[<r a='x"></r>]=])
	self:expectLuaError("attribute value prohibited '<' literal", lxl.toTable, [=[<r a="<<<"></r>]=])
	self:expectLuaError("attribute missing '='", lxl.toTable, [=[<r a="<<<"></r>]=])
	--]====]


	-- [====[
	do
		self:print(3, "[+] CharacterData node")
		local str = "<r>foobar</r>"
		self:print(4, str)

		local tree = lxl.toTable(str)
		local root = tree:getRoot()

		self:isEqual(root.children[1].id, "cdata")
		self:isEqual(root.children[1].text, "foobar")
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] CharacterData node with CDATA Section escaping")
		local str = [=[<r>"It's <![CDATA[an <odd>]]> thing to do."</r>]=]
		self:print(4, str)

		local tree = lxl.toTable(str)
		local root = tree:getRoot()

		self:isEqual(root.children[1].id, "cdata")
		self:isEqual(root.children[1].cd_sect, false)
		self:isEqual(root.children[1].text, "\"It's ")

		self:isEqual(root.children[2].id, "cdata")
		self:isEqual(root.children[2].cd_sect, true)
		self:isEqual(root.children[2].text, "an <odd>")

		self:isEqual(root.children[3].id, "cdata")
		self:isEqual(root.children[3].cd_sect, false)
		self:isEqual(root.children[3].text, " thing to do.\"")
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] empty CDATA Section")
		local str = [=[<r><![CDATA[]]></r>]=]
		self:print(4, str)

		local tree = lxl.toTable(str)
		self:isEqual(tree.children[1].children[1].cd_sect, true)
		self:isEqual(tree.children[1].children[1].text, "")
	end
	--]====]


	-- [====[
	self:expectLuaError("CDATA Sections cannot be nested", lxl.toTable, [=[<r><![CDATA[ <![CDATA[ No! ]]> ]]></r>]=])
	--]====]


	-- [====[
	do
		self:print(3, "[+] predefined entities (in content)")
		local str = "<r>&lt;&gt;&amp;&apos;&quot;</r>"
		self:print(4, str)

		local tree = lxl.toTable(str)
		local root = tree:getRoot()

		print(pretty.print(tree))
		self:isEqual(root.children[1].text, "<")
		self:isEqual(root.children[2].text, ">")
		self:isEqual(root.children[3].text, "&")
		self:isEqual(root.children[4].text, "'")
		self:isEqual(root.children[5].text, "\"")
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] predefined entities (in attribute values)")
		local str = [[<r lt="&lt;">...</r>]]
		self:print(4, str)

		local tree = lxl.toTable(str)
		local root = tree:getRoot()

		print(inspect(root.attr))
		self:isEqual(root.attr["lt"], "<")
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] nested elements")
		local str = [[<a><b></b></a>]]

		local tree = lxl.toTable(str)
		local root = tree:getRoot()

		self:isEqual(root.name, "a")
		self:isEqual(root.children[1].name, "b")
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] comment, PI, minimum DOCTYPE")
		local str = [[<!DOCTYPE r><r><!--comment!--><?pi PI!?></r>]]

		self:print(4, str)

		local tree = lxl.toTable(str)
		local root = tree:getRoot()

		print(pretty.print(tree.children[2]))
		--print(inspect(tree))
		self:isEqual(tree.children[1].name, "r") -- DocType node
		self:isEqual(tree.children[2].name, "r")
		self:isEqual(tree.children[2].children[1].id, "comment")
		self:isEqual(tree.children[2].children[1].text, "comment!")
		self:isEqual(tree.children[2].children[2].id, "pi")
		self:isEqual(tree.children[2].children[2].text, "PI!")
	end
	--]====]
end
)
--]===]


-- [===[
self:registerJob("XML Names (Elements)", function(self)
	-- [====[
	self:expectLuaError("missing names: in Element Start Tag", lxl.toTable, [=[<>zoop</r>]=])
	self:expectLuaError("missing names: in Element End Tag", lxl.toTable, [=[<r>zoop</>]=])
	self:expectLuaError("invalid name start char", lxl.toTable, [=[<.>zoop</.>]=])
	self:expectLuaError("invalid name char", lxl.toTable, [=[<r#>zoop</r#>]=])
	--]====]


	-- [====[
	do
		local tree = self:expectLuaReturn("Multi-byte code point", lxl.toTable, [=[<偐></偐>]=])
		self:isEqual(tree.children[1].name, "偐")
	end
	--]====]


	-- [====[
	do
		local tree = self:expectLuaReturn("dot (0xb7)", lxl.toTable, [=[<o_·></o_·>]=])
		self:isEqual(tree.children[1].name, "o_·")
	end
	--]====]
end
)
--]===]


-- [===[
self:registerJob("XML Names (Attributes)", function(self)
	-- [====[
	self:expectLuaError("missing name", lxl.toTable, [=[<r ="foo"></r>]=])
	self:expectLuaError("invalid name start char", lxl.toTable, [=[<r .="foo">zoop</r>]=])
	self:expectLuaError("invalid name char", lxl.toTable, [=[<r #="foo">zoop</r>]=])
	--]====]


	-- [====[
	do
		local tree = self:expectLuaReturn("Multi-byte code point", lxl.toTable, [=[<r a="偐"></r>]=])
		self:isEqual(tree.children[1].attr["a"], "偐")
	end
	--]====]


	-- [====[
	do
		local tree = self:expectLuaReturn("dot (0xb7)", lxl.toTable, [=[<r o_·="foo"></r>]=])
		self:isEqual(tree.children[1].attr["o_·"], "foo")
	end
	--]====]
end
)
--]===]


self:runJobs()
