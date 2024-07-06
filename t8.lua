-- Test: xmlObject API


local PATH = ... and (...):match("(.-)[^%.]+$") or ""


require(PATH .. "test.lib.strict")


local errTest = require(PATH .. "test.lib.err_test")
local inspect = require(PATH .. "test.lib.inspect.inspect")
local pretty = require(PATH .. "test_pretty")
local utf8Conv = require(PATH .. "xml_lib.utf8_conv")
local utf8Tools = require(PATH .. "xml_lib.utf8_tools")


local struct = require(PATH .. "xml_struct")
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
self:registerFunction("xml.newXMLObject()", xml.newXMLObject)
self:registerJob("xml.newXMLObject", function(self)
	--[====[
	do
		self:print(3, "[+] new xmlObject creation")
		local o = xml.newXMLObject()
		self:isEqual(o.id, "xml_object")
	end
	--]====]
end)


self:registerJob("XML Declaration methods", function(self)
	-- [====[
	do
		self:print(3, "[+] getXMLVersion(), setXMLVersion()")
		local o = xml.newXMLObject()

		self:isNil(o:getXMLVersion())
		o:setXMLVersion("1.0")
		self:isEqual(o:getXMLVersion(), "1.0")

		-- We're required by the spec to accept any version string that follows the
		-- pattern '1.[0-9]+'.
		o:setXMLVersion("1.0123456789")
		self:isEqual(o:getXMLVersion(), "1.0123456789")

		-- unset the version string
		o:setXMLVersion()
		self:isNil(o:getXMLVersion())

		self:expectLuaError("unsupported version", o.setXMLVersion, o, "2.0")
		self:expectLuaError("setXMLVersion() arg #1 bad type", o.setXMLVersion, o, {})
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] getXMLEncoding(), setXMLEncoding()")
		local o = xml.newXMLObject()

		self:isNil(o:getXMLEncoding())
		o:setXMLEncoding("UTF-8")
		self:isEqual(o:getXMLEncoding(), "UTF-8")
		o:setXMLEncoding("UTF-16")
		self:isEqual(o:getXMLEncoding(), "UTF-16")

		-- unset the encoding string
		o:setXMLEncoding()
		self:isNil(o:getXMLEncoding())

		self:expectLuaError("unsupported encoding", o.setXMLEncoding, o, "UTF-192")
		self:expectLuaError("setXMLEncoding() arg #1 bad type", o.setXMLEncoding, o, {})
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] getXMLStandalone(), setXMLStandalone()")
		local o = xml.newXMLObject()

		self:isNil(o:getXMLStandalone())
		o:setXMLStandalone("yes")
		self:isEqual(o:getXMLStandalone(), "yes")
		o:setXMLStandalone("no")
		self:isEqual(o:getXMLStandalone(), "no")

		-- unset the standalone string
		o:setXMLStandalone()
		self:isNil(o:getXMLStandalone())

		self:expectLuaError("invalid standalone value", o.setXMLStandalone, o, "maybe")
		self:expectLuaError("setXMLStandalone() arg #1 bad type", o.setXMLStandalone, o, {})
	end
	--]====]
end
)
--]===]


-- [===[
self:registerJob("Comment nodes", function(self)
	-- [====[
	do
		self:print(3, "[+] newComment")
		local o = xml.newXMLObject()
		local c = o:newComment("foo")
		self:isEqual(o.children[1], c)
		self:isEqual(c.id, "comment")
		self:isEqual(c.text, "foo")

		self:print(3, "[+] test 'i' children index")
		local c1 = o:newComment("first", 1)
		local c2 = o:newComment("second", 2)
		self:isEqual(o.children[1], c1)
		self:isEqual(o.children[2], c2)
		self:isEqual(o.children[3], c)

		self:expectLuaError("newComment() arg #1 invalid XML characters", o.newComment, o, "ab\0cd")
		self:expectLuaError("'i' out of bounds", o.newComment, o, "xyz", 99)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] getText / setText")
		local o = xml.newXMLObject()
		local c = o:newComment("foo")
		self:isEqual(c:getText(), "foo")
		c:setText("bar")
		self:isEqual(c:getText(), "bar")

		self:expectLuaError("setText() arg #1 bad type", c.setText, c, {})
		self:expectLuaError("setText() arg #1 invalid XML characters", c.setText, c, "ab\0cd")
		self:expectLuaError("setText() no embedded '--' substrings", c.setText, c, "uh--oh")
		self:expectLuaError("setText() can't end on '-'", c.setText, c, "-~woop~-")
		self:expectLuaError("setText() comments don't nest", c.setText, c, "...<!--comment-->...")
	end
	--]====]
end
)
--]===]


-- [===[
self:registerJob("Processing Instruction nodes", function(self)
	-- [====[
	do
		self:print(3, "[+] newProcessingInstruction")
		local o = xml.newXMLObject()
		local p = o:newProcessingInstruction("targ", "inst")
		self:isEqual(o.children[1], p)
		self:isEqual(p.id, "pi")
		self:isEqual(p.name, "targ")
		self:isEqual(p.text, "inst")

		self:print(3, "[+] test 'i' children index")
		local p1 = o:newProcessingInstruction("targ", "first", 1)
		local p2 = o:newProcessingInstruction("targ", "second", 2)
		self:isEqual(o.children[1], p1)
		self:isEqual(o.children[2], p2)
		self:isEqual(o.children[3], p)

		self:expectLuaError("arg #1 bad type", o.newProcessingInstruction, o, {}, "xyz")
		self:expectLuaError("arg #1 invalid PITarget", o.newProcessingInstruction, o, "xMl", "xyz")
		self:expectLuaError("arg #1 PITarget invalid XML characters", o.newProcessingInstruction, o, "x\0l", "xyz")
		self:expectLuaError("arg #2 bad type", o.newProcessingInstruction, o, "a", {})
		self:expectLuaError("arg #2 invalid XML characters", o.newProcessingInstruction, o, "ab\0\1\2c", {})
		self:expectLuaError("arg #3 bad type", o.newProcessingInstruction, o, "a", "b", {})

		self:expectLuaError("'i' out of bounds", o.newProcessingInstruction, o, "targ", "xyz", 99)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] getPITarget / setPITarget")
		local o = xml.newXMLObject()
		local p = o:newProcessingInstruction("targ", "inst")

		self:isEqual(p:getTarget(), "targ")
		p:setTarget("zoop")
		self:isEqual(p:getTarget(), "zoop")

		self:expectLuaError("arg #1 bad type", p.setTarget, p, {})
		self:expectLuaError("arg #1 empty XML Name", p.setTarget, p, "")
		self:expectLuaError("arg #1 invalid chars", p.setTarget, p, "\0\1\2")
		self:expectLuaError("arg #1 reserved name ('[Xx][Mm][Ll]')", p.setTarget, p, "xml")
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] getText / setText")
		local o = xml.newXMLObject()
		local p = o:newProcessingInstruction("targ", "inst")

		self:isEqual(p:getText(), "inst")
		p:setText("whoa")
		self:isEqual(p:getText(), "whoa")
		p:setText("")
		self:isEqual(p:getText(), "")

		self:expectLuaError("arg #1 bad type", p.setText, p, {})
		self:expectLuaError("arg #1 invalid chars", p.setText, p, "\0\1\2")
		self:expectLuaError("arg #1 cannot contain the substring '?>'", p.setText, p, "...?>...")
		--]]
	end
	--]====]
end
)
--]===]


-- [===[
self:registerJob("Element nodes", function(self)
	-- [====[
	do
		self:print(3, "[+] newElement")
		local o = xml.newXMLObject()
		local e = o:newElement("elem")
		self:isEqual(e.id, "element")
		self:isEqual(e.name, "elem")
		self:isEqual(#e.children, 0)

		self:print(3, "[+] test 'i' children index")
		local e1 = o:newElement("ele2", 1)
		local e2 = o:newElement("ele3", 2)
		self:isEqual(o.children[1], e1)
		self:isEqual(o.children[2], e2)
		self:isEqual(o.children[3], e)

		self:expectLuaError("arg #1 bad type", o.newElement, e, {})
		self:expectLuaError("arg #1 empty Name", o.newElement, e, "")
		self:expectLuaError("arg #1 invalid XML characters", o.newElement, e, "\2\3\4")
		self:expectLuaError("arg #2 bad type", o.newElement, e, {})
		self:expectLuaError("arg #2 out of range", o.newElement, e, "foo", 99)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] getName() / setName() (without namespacing)")
		local o = xml.newXMLObject()
		local e = o:newElement("elem")
		self:isEqual(e:getName(), "elem")
		e:setName("foo")
		self:isEqual(e:getName(), "foo")

		self:expectLuaError("arg #1 bad type", e.setName, e, {})
		self:expectLuaError("arg #1 empty XML Name", e.setName, e, "")
		self:expectLuaError("arg #1 invalid XML Characters", e.setName, e, "\1\2\3")
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] getAttribute() / setAttribute() (without namespacing)")
		local o = xml.newXMLObject()
		local e = o:newElement("elem")
		e:setAttribute("akey", "aval")
		self:isEqual(e.attr["akey"], "aval")
		self:isEqual(e:getAttribute("akey"), "aval")
		e:setAttribute("akey", "")
		self:isEqual(e.attr["akey"], "")
		e:setAttribute("akey")
		self:isNil(e:getAttribute("akey"))

		self:expectLuaError("setAttribute arg #1 bad type", e.setAttribute, e, {})
		self:expectLuaError("setAttribute arg #1 empty XML Name", e.setAttribute, e, "")
		self:expectLuaError("setAttribute arg #1 invalid XML Characters", e.setAttribute, e, "\0\1\2")
		self:expectLuaError("setAttribute arg #2 bad type", e.setAttribute, e, "a", {})
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] getStableAttributesOrder() (without namespacing)")
		local o = xml.newXMLObject()
		local e = o:newElement("elem")
		e:setAttribute("g", "")
		e:setAttribute("a", "")
		e:setAttribute("e", "")
		e:setAttribute("f", "")
		e:setAttribute("d", "")
		e:setAttribute("c", "")
		e:setAttribute("b", "")

		local order = e:getStableAttributesOrder()
		self:isEqual(order[1], "a")
		self:isEqual(order[2], "b")
		self:isEqual(order[3], "c")
		self:isEqual(order[4], "d")
		self:isEqual(order[5], "e")
		self:isEqual(order[6], "f")
		self:isEqual(order[7], "g")
	end
	--]====]

	-- The following methods are the same as those attached to xmlObject:
	-- Element:newComment()
	-- Element:newProcessingInstruction()
	-- Element:newElement()
end
)
--]===]


-- [===[
self:registerJob("CharacterData nodes", function(self)
	-- [====[
	do
		self:print(3, "[+] element:newCharacterData()")
		local o = xml.newXMLObject()
		local e = o:newElement("root")
		local c = e:newCharacterData("chums")
		self:isEqual(c.text, "chums")
		self:isEqual(c.cd_sect, false)

		self:print(3, "[+] test 'i' children index")
		local c1 = e:newCharacterData("cha2", nil, 1)
		local c2 = e:newCharacterData("cha3", nil, 2)
		self:isEqual(e.children[1], c1)
		self:isEqual(e.children[2], c2)
		self:isEqual(e.children[3], c)

		--(self, text, cd_sect, i)
		self:print(3, "[+] CharData with CDATA Section flag set")
		local cd = e:newCharacterData("foobar", true, 1)
		self:isEqual(e.children[1].text, "foobar")
		self:isEqual(e.children[1].cd_sect, true)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] Element getText() / setText()")
		local o = xml.newXMLObject()
		local e = o:newElement("root")
		local c = e:newCharacterData("zot")
		self:isEqual(c:getText(), "zot")
		c:setText("")
		self:isEqual(c:getText(), "")

		self:expectLuaError("arg #1 bad type", c.setText, c, {})
		self:expectLuaError("arg #1 invalid XML characters", c.setText, c, "\1\2\3")
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] Element getCDSect() / setCDSect()")
		local o = xml.newXMLObject()
		local e = o:newElement("root")
		local c = e:newCharacterData("zot")
		c:setCDSect(true)
		self:isEqual(c.cd_sect, true)
		c:setCDSect()
		self:isEqual(c.cd_sect, false)
	end
	--]====]
end
)
--]===]


-- [===[
self:registerFunction("struct.newUnexpandedReference()", struct.newUnexpandedReference)
self:registerJob("Unexpanded Entity nodes", function(self)
	-- These are only spawned by the parser in special circumstances involving
	-- a DTD internal subset. (Check the README for more details.)

	-- [====[
	do
		self:print(3, "[+] struct.newUnexpandedReference")
		local o = xml.newXMLObject()
		local e = o:newElement("root")
		local r = struct.newUnexpandedReference(e, "ref")
		self:isEqual(r.id, "unexp")
		self:isEqual(r.name, "ref")

		self:print(3, "[+] test 'i' children index")
		local r1 = struct.newUnexpandedReference(e, "ref", 1)
		local r2 = struct.newUnexpandedReference(e, "ref", 2)
		self:isEqual(e.children[1], r1)
		self:isEqual(e.children[2], r2)
		self:isEqual(e.children[3], r)

		self:expectLuaError("arg #1 bad type", struct.newUnexpandedReference, e, {})
		self:expectLuaError("arg #1 empty Name", struct.newUnexpandedReference, e, "")
		self:expectLuaError("arg #1 invalid XML characters", struct.newUnexpandedReference, e, "\2\3\4")
		self:expectLuaError("arg #2 bad type", struct.newUnexpandedReference, e, {})
		self:expectLuaError("arg #2 out of range", struct.newUnexpandedReference, e, "foo", 99)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] getName / setName")
		local o = xml.newXMLObject()
		local e = o:newElement("root")
		local r = struct.newUnexpandedReference(e, "ref")

		self:isEqual(r:getName(), "ref")
		r:setName("zoop")
		self:isEqual(r:getName(), "zoop")

		self:expectLuaError("arg #1 bad type", r.setName, r, {})
		self:expectLuaError("arg #1 empty XML Name", r.setName, r, "")
		self:expectLuaError("arg #1 invalid chars", r.setName, r, "\0\1\2")
	end
	--]====]

end
)
--]===]


-- [===[
self:registerJob("Pruning and Merging", function(self)

	-- [====[
	do
		self:print(3, "[+] xmlObject:pruneNodes()")
		-- Make this tree: <!--one--><!--two--><root>foo<!--woo-->bar</root><!--three-->
		local o = xml.newXMLObject()
		o:newComment("one")
		o:newComment("two")
		local e = o:newElement("root")
		e:newCharacterData("foo")
		e:newComment("woo")
		e:newCharacterData("bar")
		o:newComment("three")
		o:newProcessingInstruction("oooo", "OOOO")

		--print(pretty.print(o))
		-- Verify the node tree
		self:isEqual(o.children[1].id, "comment")
		self:isEqual(o.children[1].text, "one")
		self:isEqual(o.children[2].id, "comment")
		self:isEqual(o.children[2].text, "two")
		self:isEqual(o.children[3].id, "element")
		self:isEqual(o.children[3].name, "root")
		self:isEqual(o.children[3].children[1].id, "cdata")
		self:isEqual(o.children[3].children[1].text, "foo")
		self:isEqual(o.children[3].children[2].id, "comment")
		self:isEqual(o.children[3].children[2].text, "woo")
		self:isEqual(o.children[3].children[3].id, "cdata")
		self:isEqual(o.children[3].children[3].text, "bar")
		self:isEqual(o.children[4].id, "comment")
		self:isEqual(o.children[4].text, "three")
		self:isEqual(o.children[5].id, "pi")
		self:isEqual(o.children[5].name, "oooo")
		self:isEqual(o.children[5].text, "OOOO")

		o:pruneNodes("comment")

		--print(pretty.print(o))
		-- Check the results.
		self:isEqual(o.children[1].id, "element")
		self:isEqual(o.children[1].name, "root")
		self:isEqual(o.children[1].children[1].id, "cdata")
		self:isEqual(o.children[1].children[1].text, "foo")
		self:isEqual(o.children[1].children[2].id, "cdata")
		self:isEqual(o.children[1].children[2].text, "bar")
		self:isEqual(o.children[2].id, "pi")
		self:isEqual(o.children[2].name, "oooo")
		self:isEqual(o.children[2].text, "OOOO")

		o:pruneNodes("pi")

		self:isNil(o.children[2])


		self:expectLuaError("varargs bad type", o.pruneNodes, o, {})
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] xmlObject:mergeCharacterData()")
		-- Make this tree, where every content word + trailing whitespace is a separate CDATA entity:
		-- <root>One two three four <em>five six</em>seven eight <?pi?> nine ten.</root>
		local o = xml.newXMLObject()
		local e = o:newElement("root")
		e:newCharacterData("one ")
		e:newCharacterData("two ")
		e:newCharacterData("three ")
		e:newCharacterData("four ")
		local e2 = e:newElement("em")
		e2:newCharacterData("five ")
		e2:newCharacterData("six ")
		e:newCharacterData("seven ")
		e:newCharacterData("eight ")
		e:newCharacterData("nine ")
		e:newCharacterData("ten.")

		--print(pretty.print(o))
		-- Verify the node tree
		self:isEqual(o.children[1].id, "element")
		self:isEqual(o.children[1].name, "root")
		self:isEqual(o.children[1].children[1].id, "cdata")
		self:isEqual(o.children[1].children[1].text, "one ")
		self:isEqual(o.children[1].children[2].id, "cdata")
		self:isEqual(o.children[1].children[2].text, "two ")
		self:isEqual(o.children[1].children[3].id, "cdata")
		self:isEqual(o.children[1].children[3].text, "three ")
		self:isEqual(o.children[1].children[4].id, "cdata")
		self:isEqual(o.children[1].children[4].text, "four ")
		self:isEqual(o.children[1].children[5].id, "element")
		self:isEqual(o.children[1].children[5].name, "em")
		self:isEqual(o.children[1].children[5].children[1].id, "cdata")
		self:isEqual(o.children[1].children[5].children[1].text, "five ")
		self:isEqual(o.children[1].children[5].children[2].id, "cdata")
		self:isEqual(o.children[1].children[5].children[2].text, "six ")
		self:isEqual(o.children[1].children[6].id, "cdata")
		self:isEqual(o.children[1].children[6].text, "seven ")
		self:isEqual(o.children[1].children[7].id, "cdata")
		self:isEqual(o.children[1].children[7].text, "eight ")
		self:isEqual(o.children[1].children[8].id, "cdata")
		self:isEqual(o.children[1].children[8].text, "nine ")
		self:isEqual(o.children[1].children[9].id, "cdata")
		self:isEqual(o.children[1].children[9].text, "ten.")

		o:mergeCharacterData()

		--print(pretty.print(o))
		-- Check the results.
		self:isEqual(o.children[1].id, "element")
		self:isEqual(o.children[1].name, "root")
		self:isEqual(o.children[1].children[1].id, "cdata")
		self:isEqual(o.children[1].children[1].text, "one two three four ")
		self:isEqual(o.children[1].children[2].id, "element")
		self:isEqual(o.children[1].children[2].name, "em")
		self:isEqual(o.children[1].children[2].children[1].id, "cdata")
		self:isEqual(o.children[1].children[2].children[1].text, "five six ")
		self:isEqual(o.children[1].children[3].id, "cdata")
		self:isEqual(o.children[1].children[3].text, "seven eight nine ten.")
		--]]
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] xmlObject:pruneSpace() (without xml:space)")
		-- Make this tree:
		-- <root>  <a>\t<b>\n\n<c>    x    </c></b></a>   </root>
		-- It should be converted to:
		-- <root><a><b><c>    x    </c></b></a></root>

		local o = xml.newXMLObject()
		local e = o:newElement("root")
		e:newCharacterData("  ")
		local a = e:newElement("a")
		a:newCharacterData("\t")
		local b = a:newElement("b")
		b:newCharacterData("\n\n")
		local c = b:newElement("c")
		c:newCharacterData("    x    ")
		e:newCharacterData("   ")

		print(pretty.print(o))
		-- Verify the node tree
		self:isEqual(o.children[1].id, "element")
		self:isEqual(o.children[1].name, "root")
		self:isEqual(o.children[1].children[1].id, "cdata")
		self:isEqual(o.children[1].children[1].text, "  ")
		self:isEqual(o.children[1].children[2].id, "element")
		self:isEqual(o.children[1].children[2].name, "a")

		self:isEqual(o.children[1].children[2].children[1].id, "cdata")
		self:isEqual(o.children[1].children[2].children[1].text, "\t")

		self:isEqual(o.children[1].children[2].children[2].id, "element")
		self:isEqual(o.children[1].children[2].children[2].name, "b")

		self:isEqual(o.children[1].children[2].children[2].children[1].id, "cdata")
		self:isEqual(o.children[1].children[2].children[2].children[1].text, "\n\n")

		self:isEqual(o.children[1].children[2].children[2].children[2].id, "element")
		self:isEqual(o.children[1].children[2].children[2].children[2].name, "c")

		self:isEqual(o.children[1].children[2].children[2].children[2].children[1].id, "cdata")
		self:isEqual(o.children[1].children[2].children[2].children[2].children[1].text, "    x    ")

		self:isEqual(o.children[1].children[3].id, "cdata")
		self:isEqual(o.children[1].children[3].text, "   ")

		o:pruneSpace()

		-- <root><a><b><c>    x    </c></b></a></root>
		print(pretty.print(o))
		-- Check the results.
		self:isEqual(o.children[1].id, "element")
		self:isEqual(o.children[1].name, "root")
		self:isEqual(o.children[1].children[1].id, "element")
		self:isEqual(o.children[1].children[1].name, "a")
		self:isEqual(o.children[1].children[1].children[1].id, "element")
		self:isEqual(o.children[1].children[1].children[1].name, "b")
		self:isEqual(o.children[1].children[1].children[1].children[1].id, "element")
		self:isEqual(o.children[1].children[1].children[1].children[1].name, "c")
		self:isEqual(o.children[1].children[1].children[1].children[1].children[1].id, "cdata")
		self:isEqual(o.children[1].children[1].children[1].children[1].children[1].text, "    x    ")
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] xmlObject:pruneSpace() (with xml:space)")
		-- Make this tree:
		-- <root> <a xml:space="preserve">  <b>   </b</a>    </root>
		-- It should be converted to:
		-- <root><a xml:space="preserve">  <b>   </b></a></root>

		local o = xml.newXMLObject()
		local e = o:newElement("root")
		e:newCharacterData(" ")
		local a = e:newElement("a")
		a:setAttribute("xml:space", "preserve")
		a:newCharacterData("  ")
		local b = a:newElement("b")
		b:newCharacterData("   ")
		e:newCharacterData("    ")

		print(pretty.print(o))
		-- Verify the node tree
		self:isEqual(o.children[1].id, "element")
		self:isEqual(o.children[1].name, "root")
		self:isEqual(o.children[1].children[1].id, "cdata")
		self:isEqual(o.children[1].children[1].text, " ")
		self:isEqual(o.children[1].children[2].id, "element")
		self:isEqual(o.children[1].children[2].name, "a")

		self:isEqual(o.children[1].children[2].children[1].id, "cdata")
		self:isEqual(o.children[1].children[2].children[1].text, "  ")

		self:isEqual(o.children[1].children[2].children[2].id, "element")
		self:isEqual(o.children[1].children[2].children[2].name, "b")

		self:isEqual(o.children[1].children[2].children[2].children[1].id, "cdata")
		self:isEqual(o.children[1].children[2].children[2].children[1].text, "   ")

		self:isEqual(o.children[1].children[3].id, "cdata")
		self:isEqual(o.children[1].children[3].text, "    ")

		o:pruneSpace(true)

		-- <root><a xml:space="preserve">  <b>   </b></a></root>
		print(pretty.print(o))

		-- Check the results.
		self:isEqual(o.children[1].id, "element")
		self:isEqual(o.children[1].name, "root")

		self:isEqual(o.children[1].children[1].id, "element")
		self:isEqual(o.children[1].children[1].name, "a")

		self:isEqual(o.children[1].children[1].children[1].id, "cdata")
		self:isEqual(o.children[1].children[1].children[1].text, "  ")

		self:isEqual(o.children[1].children[1].children[2].id, "element")
		self:isEqual(o.children[1].children[1].children[2].name, "b")

		self:isEqual(o.children[1].children[1].children[2].children[1].id, "cdata")
		self:isEqual(o.children[1].children[1].children[2].children[1].text, "   ")

		self:isNil(o.children[1].children[2])
	end
	--]====]
end
)
--]===]


-- [===[
self:registerJob("DocType node", function(self)
	-- [====[
	do
		self:print(3, "[+] struct.newDocType()")
		local o = xml.newXMLObject()
		table.insert(o, struct.newDocType(o, "root"))
		self:isEqual(o.children[1].id, "doctype")
		self:isEqual(o.children[1].name, "root")

		self:expectLuaError("arg #1 bad type", struct.newDocType, {children={}}, {})
		self:expectLuaError("arg #1 empty XML Name", struct.newDocType, {children={}}, "")
		self:expectLuaError("arg #1 invalid XML characters", struct.newDocType, {children={}}, "\1\2\3")

		-- An xmlObject tree should have at most one DocType node. If present, it must appear
		-- before the root element. We're not going to check either condition here, nor in
		-- the node creation function, since one could easily shift the child references around
		-- after creating the nodes.

		-- The xmlObject table doesn't have a method to create DocTypes. Except for testing,
		-- there's almost no reason to create this node manually; you should only see them
		-- from xmlObjects that were created by the parser. That said, you can write out a
		-- pre-written DOCTYPE string using 'xml_object.doctype_str' and
		-- 'xml_object:setCopyDocType()'.


	end
	--]====]
end
)
--]===]


-- [===[
self:registerJob("getRoot() and getDocType()", function(self)
	-- [====[
	do
		self:print(3, "[+] getRoot(), getDocType()")
		local o = xml.newXMLObject()
		-- You can call getDocType() without one having been provisioned.
		self:isNil(o:getDocType())
		table.insert(o, struct.newDocType(o, "root"))
		self:isEqual(o:getDocType().id, "doctype")
		self:isEqual(o:getDocType().name, "root")

		-- It's an error to call getRoot() without a root element set.
		-- if the xmlObject contains multiple elements as direct descendants
		-- (which is an invalid state), then only the first element in the
		-- list will be returned.
		self:expectLuaError("no document root", o.getRoot, o)
		o:newElement("root")
		local root = o:getRoot()
		self:isEqual(root.id, "element")
		self:isEqual(root.name, "root")
	end
	--]====]
end
)
--]===]


-- [===[
self:registerJob("Node traversal functions", function(self)
	-- [====[
	do
		self:print(3, "[+] next(), prev()")

		local o = xml.newXMLObject()
		local c = o:newComment("foo")
		local e = o:newElement("root")
		local p = o:newProcessingInstruction("zip", "zap")

		local obj = c
		obj = obj:next()
		self:isEqual(obj, e)

		obj = obj:next()
		self:isEqual(obj, p)

		obj = obj:next()
		self:isNil(obj)

		obj = p
		obj = obj:prev()
		self:isEqual(obj, e)

		obj = obj:prev()
		self:isEqual(obj, c)

		obj = obj:prev()
		self:isNil(obj)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] descend(), ascend()")

		local o = xml.newXMLObject()
		local a = o:newElement("a")
		local b = a:newElement("b")
		local c = b:newElement("c")

		local obj = a
		obj = obj:descend()
		self:isEqual(obj, b)

		obj = obj:descend()
		self:isEqual(obj, c)

		obj = obj:descend()
		self:isNil(obj)

		obj = c
		obj = obj:ascend()
		self:isEqual(obj, b)

		obj = obj:ascend()
		self:isEqual(obj, a)

		obj = obj:ascend()
		self:isEqual(obj, o)

		obj = obj:ascend()
		self:isNil(obj)
	end
	--]====]

	-- [====[
	do
		self:print(3, "[+] top()")

		local o = xml.newXMLObject()
		local a = o:newElement("a")
		local b = a:newElement("b")
		local c = b:newElement("c")

		local obj = c
		obj = obj:top()
		self:isEqual(obj, o)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] path()")

		--[[
		<r>
			<a>
				<a1/> <a2/> <a3/>
			</a>
			<b>
				<b1/> <b2/> <b3/>
			</b>
			<c>
				<c1/> <c2/> <c3/>
			</c>
		</r>
		--]]
		local o = xml.newXMLObject()
		local r = o:newElement("r")
		local a = r:newElement("a")
		local a1 = a:newElement("a1")
		local a2 = a:newElement("a2")
		local a3 = a:newElement("a3")
		local b = r:newElement("b")
		local b1 = b:newElement("b1")
		local b2 = b:newElement("b2")
		local b3 = b:newElement("b3")
		local c = r:newElement("c")
		local c1 = c:newElement("c1")
		local c2 = c:newElement("c2")
		local c3 = c:newElement("c3")

		self:expectLuaError("arg #1 bad type", o.path, o, false)

		local obj

		self:print(3, "[+] path(): select xmlObject ('/')")
		obj = c3
		obj = obj:path("/")
		self:isEqual(obj, o)

		self:print(3, "[+] path(): absolute path ('/r/a')")
		obj = c3
		self:isEqual(obj:path("/r"), r)
		self:isEqual(obj:path("/r/a/a2"), a2)

		self:print(3, "[+] path(): relative path")
		obj = b
		self:isEqual(obj:path("b2"), b2)
		self:isEqual(obj:path(".."), r)
		self:isEqual(obj:path("../a/a3"), a3)
		self:isEqual(obj:path("../a/../b/../c/../a/../b/b2"), b2)

		self:print(3, "[-] attempt to ascend the xmlObject root")
		obj = a3
		self:isNil(obj:path("../../../../../.."))

		self:print(3, "[-] invalid path")
		obj = a3
		self:expectLuaError("invalid path", obj.path, obj, "/////")

	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] find()")

		local o = xml.newXMLObject()
		local r = o:newElement("r")
		local a = r:newElement("a") -- 1
		local b = r:newElement("b") -- 2
		local c = r:newElement("c") -- 3
		local c2 = r:newElement("c") -- 4
		local c3 = r:newElement("c") -- 5
		local pi = r:newProcessingInstruction("pyp", "foo") -- 6

		self:expectLuaError("arg #1 bad type", o.find, o, false, "element")
		self:expectLuaError("arg #2 bad type", o.find, o, "foo", false)
		self:expectLuaError("arg #3 bad type", o.find, o, "foo", "element", {})

		--_find(self, id, name, i)

		self:print(3, "[+] various find() calls")
		self:isEqual(o:find("element", "r"), r)
		self:isEqual(r:find("element", "c"), c)
		self:isEqual(r:find("element", "c", 3), c)
		self:isEqual(r:find("element", "c", 4), c2)
		self:isEqual(r:find("element", "c", 5), c3)
		self:isEqual(r:find("pi", "pyp"), pi)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] destroy()")

		local o = xml.newXMLObject()
		local r = o:newElement("r")
		local a = r:newElement("a") -- 1
		local b = r:newElement("b") -- 2
		local c = r:newElement("c") -- 3
		local c2 = r:newElement("c") -- 4
		local c3 = r:newElement("c") -- 5
		local pi = r:newProcessingInstruction("pyp", "foo") -- 6

		o:destroy()

		self:isNil(next(o))
		self:isNil(getmetatable(o))
	end
	--]====]

end
)
--]===]


-- [===[
self:registerJob("xml:lang lookup (without namespacing)", function(self)
	-- [====[
	do
		self:print(3, "[+] xml:lang attribute")

		local o = xml.newXMLObject()
		local e = o:newElement("one")
		local e2 = e:newElement("two")
		e2:setAttribute("xml:lang", "en-CA")
		local e3 = e2:newElement("three")
		local e4 = e3:newElement("four")
		e4:setAttribute("xml:lang", "")
		local e5 = e4:newElement("five")

		self:isEqual(e:getXMLSpecialAttribute("lang"), nil)
		self:isEqual(e2:getXMLSpecialAttribute("lang"), "en-CA")
		self:isEqual(e3:getXMLSpecialAttribute("lang"), "en-CA")
		self:isEqual(e4:getXMLSpecialAttribute("lang"), "")
		self:isEqual(e5:getXMLSpecialAttribute("lang"), "")

		-- No language is set at a given scope if the return value is nil or an empty string.
	end
	--]====]
end
)
--]===]


self:runJobs()
