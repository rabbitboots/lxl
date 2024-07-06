-- Test: encoding; XML Declaration


local PATH = ... and (...):match("(.-)[^%.]+$") or ""


require(PATH .. "test.lib.strict")


local errTest = require(PATH .. "test.lib.err_test")
local inspect = require(PATH .. "test.lib.inspect.inspect")
local pretty = require(PATH .. "test_pretty")
local utf8Conv = require(PATH .. "xml_lib.utf8_conv")
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
self:registerJob("Encoding (prohibited code points, normalizing line endings)", function(self)

	self:expectLuaError("contains prohibited code points (null byte)", xml.toTable, "<r>\0</r>")
	self:expectLuaError("contains prohibited code points (U+001F)", xml.toTable, "<r>\31</r>")
	self:expectLuaError("contains prohibited code points (surrogate)", xml.toTable, "<r>\237\160\128</r>")

	do
		local tree = self:expectLuaReturn("normalize line endings (1, \\r\\n -> \\n)", xml.toTable, "<r>\r\n</r>")
		self:isEqual(tree.children[1].children[1].text, "\n")
	end

	do
		local tree = self:expectLuaReturn("normalize line endings (2, \\r -> \\n)", xml.toTable, "<r>\r</r>")
		self:isEqual(tree.children[1].children[1].text, "\n")
	end

	do
		local tree = self:expectLuaReturn("normalize line endings (3, \\r\\r\\n -> \\n\\n)", xml.toTable, "<r>\r\r\n</r>")
		self:isEqual(tree.children[1].children[1].text, "\n\n")
	end

	do
		local tree = self:expectLuaReturn("normalize line endings (4, \\n\\r -> \\n\\n)", xml.toTable, "<r>\n\r</r>")
		self:isEqual(tree.children[1].children[1].text, "\n\n")
	end
end
)
--]===]


-- [===[
self:registerJob("XML Declaration", function(self)

	do
		local tree = self:expectLuaReturn("Minimum XML Declaration", xml.toTable, [=[<?xml version="1.0"?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.version, "1.0")
	end


	do
		self:expectLuaError("Bad version (for XML 1.0, must be 1.n+)", xml.toTable, [=[<?xml version="2.0"?><r></r>]=])
	end


	do
		local tree = self:expectLuaReturn("standalone 'yes' (single-quotes)", xml.toTable, [=[<?xml version="1.0" standalone='yes'?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.standalone, "yes")
	end


	do
		local tree = self:expectLuaReturn('standalone "yes" (double-quotes)', xml.toTable, [=[<?xml version="1.0" standalone="yes"?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.standalone, "yes")
	end


	do
		local tree = self:expectLuaReturn("standalone 'no' (single-quotes)", xml.toTable, [=[<?xml version="1.0" standalone='no'?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.standalone, "no")
	end


	do
		local tree = self:expectLuaReturn('standalone "no" (double-quotes)', xml.toTable, [=[<?xml version="1.0" standalone="no"?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.standalone, "no")
	end


	do
		self:expectLuaError("bad standalone", xml.toTable, [=[<?xml version="1.0" standalone="yeah"><r></r>]=])
	end


	do
		self:expectLuaError("must be at the start of the string", xml.toTable, [=[ <?xml version="1.0"><r></r>]=])
	end


	do
		local tree = self:expectLuaReturn("encoding 'UTF-8'", xml.toTable, [=[<?xml version="1.0" encoding='UTF-8'?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.encoding, "UTF-8")
	end


	do
		local tree = self:expectLuaReturn('encoding "UTF-8"', xml.toTable, [=[<?xml version="1.0" encoding="UTF-8"?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.encoding, "UTF-8")
	end


	do
		-- FFFE == UTF-16 little endian byte order mark
		local str = hex(0xff, 0xfe) .. utf8Conv.utf8_utf16([=[<?xml version="1.0" encoding="UTF-16"?><r></r>]=])
		local tree = self:expectLuaReturn('encoding "UTF-16" (little endian)', xml.toTable, str)
		print(pretty.print(tree))
		self:isEqual(tree.encoding, "UTF-16")
	end


	do
		-- FEFF == UTF-16 big endian byte order mark
		local str = hex(0xfe, 0xff) .. utf8Conv.utf8_utf16([=[<?xml version="1.0" encoding="UTF-16"?><r></r>]=], true)
		local tree = self:expectLuaReturn('encoding "UTF-16" (big endian)', xml.toTable, str)
		print(pretty.print(tree))
		self:isEqual(tree.encoding, "UTF-16")
	end


	do
		local str = "<?xml version='1.0' encoding='UTF-16'?>"
		local parser = xml.newParser()
		parser:setCheckEncodingMismatch(true)
		self:expectLuaError("mismatch between string encoding and XML decl encoding", parser.toTable, parser, str)
	end


	do
		local str = "<?xml encoding='UTF-8' standalone='yes' version='1.0'?>"
		self:expectLuaError("bad order of declarations", xml.toTable, str)
	end

	do
		self:expectLuaError("bad encoding value", xml.toTable, [=[<?xml version="1.0" encoding="UTF-16384"><r></r>]=])
	end

	do
		local tree = self:expectLuaReturn("full XML Declaration, spaces between '='", xml.toTable, [=[<?xml version = "1.0" encoding = "UTF-8" standalone = "no"?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.version, "1.0")
		self:isEqual(tree.encoding, "UTF-8")
		self:isEqual(tree.standalone, "no")
	end
end
)


-- [===[
self:registerJob("prolog", function(self)

	do
		local tree = self:expectLuaReturn("empty prolog", xml.toTable, [=[<r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree:getDocType(), nil)
	end


	do
		local tree = self:expectLuaReturn("XMLDecl", xml.toTable, [=[<?xml version="1.0" encoding="UTF-8" standalone="no"?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.version, "1.0")
		self:isEqual(tree.encoding, "UTF-8")
		self:isEqual(tree.standalone, "no")
	end


	do
		local tree = self:expectLuaReturn("comment", xml.toTable, [=[<!--foo--><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.children[1].id, "comment")
		self:isEqual(tree.children[1].text, "foo")
	end


	do
		local tree = self:expectLuaReturn("doctype", xml.toTable, [=[<!DOCTYPE r><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.children[1].id, "doctype")
		self:isEqual(tree.children[1].name, "r")
	end


	self:expectLuaError("invalid prolog", xml.toTable, [=[dung<r></r>]=])
end
)
--]===]


self:runJobs()
