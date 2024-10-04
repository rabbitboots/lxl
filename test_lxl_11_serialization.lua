-- Test: serializing xmlObjects


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
self:registerFunction("xml.toString()", xml.toString)


-- [===[
self:registerFunction("xml.newXMLObject", xml.newXMLObject)
self:registerJob("parser:toString()", function(self)
	-- [====[
	do
		self:print(3, "[+] Basic test")
		local o = xml.newXMLObject()
		local e = o:newElement("r")

		local p = xml.newParser()
		local str = p:toString(o)

		local o2 = xml.toTable(str)
		print(str)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] Nested elements")
		local o = xml.newXMLObject()
		local e = o:newElement("a")
		local e2 = e:newElement("b")
		local e3 = e2:newElement("c")

		local p = xml.newParser()
		local str = p:toString(o)

		local o2 = xml.toTable(str)
		print(str)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] Attributes")
		local o = xml.newXMLObject()
		local e = o:newElement("a")
		e:setAttribute("foo", "bar")
		e:setAttribute("baz", "bop")

		local p = xml.newParser()
		local str = p:toString(o)

		local o2 = xml.toTable(str)
		print(str)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] Attributes with escaped characters")
		local o = xml.newXMLObject()
		local e = o:newElement("a")
		e:setAttribute("foo", "a<b>c")
		e:setAttribute("baz", "d'e")
		e:setAttribute("baz2", "f\"g")
		e:setAttribute("baz3", "h'\"i")
		print(pretty.print(e))

		local p = xml.newParser()
		local str = p:toString(o)

		local o2 = xml.toTable(str)
		print(str)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] Comments and PIs, before, within and after the root element")
		local o = xml.newXMLObject()
		local p1 = o:newProcessingInstruction("abc", "before")
		local c1= o:newComment("def")
		local e = o:newElement("a")
		local p2 = e:newProcessingInstruction("ghi", "within")
		local c2= e:newComment("jkl")
		local p3 = o:newProcessingInstruction("jkl", "after")
		local c3= o:newComment("mnopqrstuvwxyz")
		print(pretty.print(e))

		local p = xml.newParser()
		local str = p:toString(o)

		local o2 = xml.toTable(str)
		print(str)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[-] Processing Instruction corruption")
		local o = xml.newXMLObject()
		local p1 = o:newProcessingInstruction("pi", "foo")

		-- corrupt the PI name
		p1.name = "."
		print(pretty.print(o))

		local p = xml.newParser()

		self:expectLuaError("invalid PI target", p.toString, p, o)

		-- corrupt the PI text
		p1.name = "pi"
		p1.text = "...?>..."

		self:expectLuaError("invalid PI text", p.toString, p, o)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[-] Comment corruption")
		local o = xml.newXMLObject()
		local comment = o:newComment("foobar")

		-- corrupt the comment text
		comment.text = "foo--bar"
		print(pretty.print(o))

		local p = xml.newParser()

		self:expectLuaError("invalid comment text", p.toString, p, o)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] CharacterData + CDATA Sections")
		local o = xml.newXMLObject()
		local e = o:newElement("a")
		local c1 = e:newCharacterData("abc")
		local c2 = e:newCharacterData("def", true)
		local c3 = e:newCharacterData("ghi")

		print(pretty.print(e))

		local p = xml.newParser()
		local str = p:toString(o)

		local o2 = xml.toTable(str)
		print(str)
		print(pretty.print(o2))
	end
	--]====]


	-- [====[
	do
		self:print(3, "[-] Invalid CharData")
		local o = xml.newXMLObject()
		local e = o:newElement("a")
		local c1 = e:newCharacterData("abc")

		-- Corrupt the CharData node
		c1.text = "xyz\0"

		print(pretty.print(e))

		local p = xml.newParser()
		self:expectLuaError("invalid CharData", p.toString, p, o)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] Handling of ']]>' in CDATA Sections")
		local o = xml.newXMLObject()
		local e = o:newElement("a")
		local c1 = e:newCharacterData("abc")
		local c2 = e:newCharacterData("def]]>ghi", true)
		local c3 = e:newCharacterData("jkl")

		print(pretty.print(e))

		local p = xml.newParser()
		local str = p:toString(o)

		local o2 = xml.toTable(str)
		print(str)
	end
	--]====]


	-- [====[
	do
		self:print(3, "[+] indenting")
		local o = xml.newXMLObject()

		local e = o:newElement("r")
		local e1 = e:newElement("a")

		local p = xml.newParser()
		local str = p:toString(o)

		self:isEqual(str, [=[
<?xml version="1.0" encoding="UTF-8"?>
<r>
 <a/>
</r>]=])
	end
	--]====]
end)


self:runJobs()
