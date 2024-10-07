-- Test: encoding; XML Declaration


local PATH = ... and (...):match("(.-)[^%.]+$") or ""


require(PATH .. "test.strict")


local errTest = require(PATH .. "test.err_test")
local inspect = require(PATH .. "test.inspect")
local lxl = require(PATH .. "lxl")
local pretty = require(PATH .. "test_pretty")
local pUTF8 = require(PATH .. "pile_utf8")
local pUTF8Conv = require(PATH .. "pile_utf8_conv")


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
self:registerJob("Encoding (prohibited code points, normalizing line endings)", function(self)

	self:expectLuaError("contains prohibited code points (null byte)", lxl.toTable, "<r>\0</r>")
	self:expectLuaError("contains prohibited code points (U+001F)", lxl.toTable, "<r>\31</r>")
	self:expectLuaError("contains prohibited code points (surrogate)", lxl.toTable, "<r>\237\160\128</r>")

	do
		local tree = self:expectLuaReturn("normalize line endings (1, \\r\\n -> \\n)", lxl.toTable, "<r>\r\n</r>")
		self:isEqual(tree.children[1].children[1].text, "\n")
	end

	do
		local tree = self:expectLuaReturn("normalize line endings (2, \\r -> \\n)", lxl.toTable, "<r>\r</r>")
		self:isEqual(tree.children[1].children[1].text, "\n")
	end

	do
		local tree = self:expectLuaReturn("normalize line endings (3, \\r\\r\\n -> \\n\\n)", lxl.toTable, "<r>\r\r\n</r>")
		self:isEqual(tree.children[1].children[1].text, "\n\n")
	end

	do
		local tree = self:expectLuaReturn("normalize line endings (4, \\n\\r -> \\n\\n)", lxl.toTable, "<r>\n\r</r>")
		self:isEqual(tree.children[1].children[1].text, "\n\n")
	end
end
)
--]===]


-- [===[
self:registerJob("XML Declaration", function(self)

	do
		local tree = self:expectLuaReturn("Minimum XML Declaration", lxl.toTable, [=[<?xml version="1.0"?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.version, "1.0")
	end


	do
		self:expectLuaError("Bad version (for XML 1.0, must be 1.n+)", lxl.toTable, [=[<?xml version="2.0"?><r></r>]=])
	end


	do
		local tree = self:expectLuaReturn("standalone 'yes' (single-quotes)", lxl.toTable, [=[<?xml version="1.0" standalone='yes'?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.standalone, "yes")
	end


	do
		local tree = self:expectLuaReturn('standalone "yes" (double-quotes)', lxl.toTable, [=[<?xml version="1.0" standalone="yes"?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.standalone, "yes")
	end


	do
		local tree = self:expectLuaReturn("standalone 'no' (single-quotes)", lxl.toTable, [=[<?xml version="1.0" standalone='no'?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.standalone, "no")
	end


	do
		local tree = self:expectLuaReturn('standalone "no" (double-quotes)', lxl.toTable, [=[<?xml version="1.0" standalone="no"?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.standalone, "no")
	end


	do
		self:expectLuaError("bad standalone", lxl.toTable, [=[<?xml version="1.0" standalone="yeah"><r></r>]=])
	end


	do
		self:expectLuaError("must be at the start of the string", lxl.toTable, [=[ <?xml version="1.0"><r></r>]=])
	end


	do
		local tree = self:expectLuaReturn("encoding 'UTF-8'", lxl.toTable, [=[<?xml version="1.0" encoding='UTF-8'?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.encoding, "UTF-8")
	end


	do
		local tree = self:expectLuaReturn('encoding "UTF-8"', lxl.toTable, [=[<?xml version="1.0" encoding="UTF-8"?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.encoding, "UTF-8")
	end


	do
		-- FFFE == UTF-16 little endian byte order mark
		local str = hex(0xff, 0xfe) .. pUTF8Conv.utf8_utf16([=[<?xml version="1.0" encoding="UTF-16"?><r></r>]=])
		local tree = self:expectLuaReturn('encoding "UTF-16" (little endian)', lxl.toTable, str)
		print(pretty.print(tree))
		self:isEqual(tree.encoding, "UTF-16")
	end


	do
		-- FEFF == UTF-16 big endian byte order mark
		local str = hex(0xfe, 0xff) .. pUTF8Conv.utf8_utf16([=[<?xml version="1.0" encoding="UTF-16"?><r></r>]=], true)
		local tree = self:expectLuaReturn('encoding "UTF-16" (big endian)', lxl.toTable, str)
		print(pretty.print(tree))
		self:isEqual(tree.encoding, "UTF-16")
	end


	do
		local str = "<?xml version='1.0' encoding='UTF-16'?>"
		local parser = lxl.newParser()
		parser:setCheckEncodingMismatch(true)
		self:expectLuaError("mismatch between string encoding and XML decl encoding", parser.toTable, parser, str)
	end


	do
		local str = "<?xml encoding='UTF-8' standalone='yes' version='1.0'?>"
		self:expectLuaError("bad order of declarations", lxl.toTable, str)
	end

	do
		self:expectLuaError("bad encoding value", lxl.toTable, [=[<?xml version="1.0" encoding="UTF-16384"><r></r>]=])
	end

	do
		local tree = self:expectLuaReturn("full XML Declaration, spaces between '='", lxl.toTable, [=[<?xml version = "1.0" encoding = "UTF-8" standalone = "no"?><r></r>]=])
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
		local tree = self:expectLuaReturn("empty prolog", lxl.toTable, [=[<r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree:getDocType(), nil)
	end


	do
		local tree = self:expectLuaReturn("XMLDecl", lxl.toTable, [=[<?xml version="1.0" encoding="UTF-8" standalone="no"?><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.version, "1.0")
		self:isEqual(tree.encoding, "UTF-8")
		self:isEqual(tree.standalone, "no")
	end


	do
		local tree = self:expectLuaReturn("comment", lxl.toTable, [=[<!--foo--><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.children[1].id, "comment")
		self:isEqual(tree.children[1].text, "foo")
	end


	do
		local tree = self:expectLuaReturn("doctype", lxl.toTable, [=[<!DOCTYPE r><r></r>]=])
		print(pretty.print(tree))
		self:isEqual(tree.children[1].id, "doctype")
		self:isEqual(tree.children[1].name, "r")
	end


	self:expectLuaError("invalid prolog", lxl.toTable, [=[dung<r></r>]=])
end
)
--]===]


-- [===[
self:registerJob("Parser:setCheckCharacters()", function(self)

	--[[
	You can try disabling this feature if LXL is too slow and you are 100% confident
	that the incoming XML is correctly encoded, with no code points that are forbidden
	by the spec.
	--]]

	do
		self:print(4, "[+] forbidden code points are is silently accepted as part of the text content")
		local s = "<r>foo\0bar</r>"
		local p = lxl.newParser()
		p:setCheckCharacters(false)
		local o = p:toTable(s)

		-- NOTE: The console output is cut off in 5.1 due to null.
		self:isEqual(o.children[1].children[1].text, "foo\0bar")

		-- Test the getter while we're at it.
		p:setCheckCharacters(true)
		self:isEqual(p:getCheckCharacters(), true)
	end
end
)
--]===]


self:runJobs()
