-- Test: XML Namespaces (from the parser)


local PATH = ... and (...):match("(.-)[^%.]+$") or ""


require(PATH .. "test.strict")


local errTest = require(PATH .. "test.err_test")
local inspect = require(PATH .. "test.inspect")
local lxl = require(PATH .. "lxl")
local namespace = require(PATH .. "lxl_namespace")
local pretty = require(PATH .. "test_pretty")
local pUTF8 = require(PATH .. "pile_utf8")
local pUTF8Conv = require(PATH .. "pile_utf8_conv")
local struct = require(PATH .. "lxl_struct")


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


-- [===[
self:registerJob("(parser) Namespaced Element Names", function(self)
	-- [====[
	do
		local str = [=[
<n1:root xmlns:n1="foo/bar"></n1:root>
]=]

		self:print(3, "[+] Element: getNamespaceAttribute()")
		self:print(4, str)
		local parser = lxl.newParser()
		parser:setNamespaceMode("1.0")
		local o = parser:toTable(str)

		self:isEqual(o.children[1].name, "n1:root")

		print(pretty.print(o))
		--print(inspect(o))

		local ns_uri = o.children[1]:getNamespace()

		self:isEqual(ns_uri, "foo/bar")
	end
	--]====]
end)
--]===]


-- [===[
self:registerJob("(parser) Default Namespace", function(self)
	-- [====[
	do
		local str = [=[
<root xmlns="x/y/z"><a><b xmlns=""/></a></root>
]=]

		self:print(3, "[+] Default Namespace")
		self:print(4, str)
		local parser = lxl.newParser()
		parser:setNamespaceMode("1.0")
		local o = parser:toTable(str)

		print(pretty.print(o))
		--print(inspect(o))

		local ns_uri
		ns_uri = o.children[1]:getNamespace()
		self:isEqual(ns_uri, "x/y/z")

		-- Descendants inherit the default namespace...
		ns_uri = o.children[1].children[1]:getNamespace()

		self:isEqual(ns_uri, "x/y/z")

		-- ...unless it is undeclared with an empty string.
		ns_uri = o.children[1].children[1].children[1]:getNamespace()

		self:isEqual(ns_uri, nil)
	end
	--]====]
end)
--]===]


-- [===[
self:registerJob("(parser) Namespace 1.1: undeclaring prefixed namespaces", function(self)
	-- [====[
	do
		local str = [=[
<root xmlns:n1="x/y/z"><a xmlns:n1=""><n1:b/></a></root>
]=]

		self:print(3, "[+] NS 1.1 undeclaring")
		self:print(4, str)
		local parser = lxl.newParser()
		parser:setNamespaceMode("1.1")
		local o = parser:toTable(str)

		print(pretty.print(o))
		--print(inspect(o))

		self:isEqual(o.children[1].children[1].children[1]:getNamespace(), nil)
	end
	--]====]
end)
--]===]



-- [===[
self:registerJob("(parser) Namespaced Attributes in Elements", function(self)
	-- [====[
	do
		local str = [=[
<root xmlns:n1="foo/bar"><e n1:ping="pong"></e></root>
]=]
		self:print(3, "[+] Element: getNamespaceAttribute()")
		self:print(4, str)

		local parser = lxl.newParser()
		parser:setNamespaceMode("1.0")
		local e = parser:toTable(str)

		print(pretty.print(e.children[1].children[1]))
		self:isEqual(e.children[1].children[1]:getNamespaceAttribute("foo/bar", "ping"), "pong")
	end
	--]====]
end
)
--]===]


-- [===[
self:registerJob("(parser) Test Namespace state errors", function(self)
	-- [====[
	do
		self:print(3, "[+] Namespace state errors")
		local parser = lxl.newParser()
		parser:setNamespaceMode("1.0")

		-- err_ns_empty_ns_uri (1.0 only)
		self:expectLuaError(
			"cannot undeclare prefixed namespaces in NS 1.0", parser.toTable, parser,
			[=[<r xmlns:n1=""/>]=]
		)

		-- err_ns_empty_prefix
		self:expectLuaError(
			"empty prefix (':bar')", parser.toTable, parser,
			[=[<r :n1="zyp"/>]=]
		)

		-- err_ns_empty_local
		self:expectLuaError(
			"empty local name ('foo:')", parser.toTable, parser,
			[=[<r foo:="zyp"/>]=]
		)

		-- err_ns_colon_local
		self:expectLuaError(
			"too many colons in QName ('foo:bar:baz')", parser.toTable, parser,
			[=[<r foo:bar:baz="zyp"/>]=]
		)

		-- err_ns_undef_ns
		self:expectLuaError(
			"undefined URI", parser.toTable, parser,
			[=[<r foo:bar="zyp"/>]=]
		)

		-- err_ns_dupe_attr
		self:expectLuaError(
			"duplicate namespaced attributes", parser.toTable, parser,
			[=[<r xmlns:a="x/y/z" xmlns:b="x/y/z" a:foo="zyp" b:foo="zop"/>]=]
		)

		-- err_ns_bad_xml_pre
		self:expectLuaError("bad declaration for the prefix 'xml'", parser.toTable, parser,
			[=[<r xmlns:xml="a/b/c"/>]=]
		)

		-- err_ns_invalid_xmlns_pre
		self:expectLuaError("cannot declare a binding for the prefix 'xmlns'", parser.toTable, parser,
			[=[<r xmlns:xmlns="a/b/c"/>]=]
		)

		-- err_ns_predef_def
		self:expectLuaError("cannot set the default namespace to 'xml'", parser.toTable, parser,
			[=[<r xmlns="http://www.w3.org/XML/1998/namespace"/>]=]
		)
		self:expectLuaError("cannot set the default namespace to 'xmlns'", parser.toTable, parser,
			[=[<r xmlns="http://www.w3.org/2000/xmlns/"/>]=]
		)

		-- err_ns_invalid_colon
		self:expectLuaError(
			"colon in a PI target)", parser.toTable, parser,
			[=[<r><?pi:not allowed?></r>]=]
		)
		self:expectLuaError(
			"colon in a Notation declaration name)", parser.toTable, parser,
			[=[<!DOCTYPE r [<!NOTATION foo:bar SYSTEM 'system_literal'>]><r/>]=]
		)
		self:expectLuaError(
			"colon in a Entity name)", parser.toTable, parser,
			[=[<!DOCTYPE r [<!ENTITY foo:bar "woop">]><r/>]=]
		)

		-- err_ns_elem_xmlns
		self:expectLuaError("cannot prefix element names with 'xmlns')", parser.toTable, parser,
			[=[<xmlns:r/>]=]
		)

		-- err_ns_bad_xml_bind
		self:expectLuaError("cannot bind 'http://www.w3.org/XML/1998/namespace' to prefixes other than 'xml'", parser.toTable, parser,
			[=[<r xmlns:foo="http://www.w3.org/XML/1998/namespace"/>]=]
		)

		-- err_ns_bad_xmlns_bind
		self:expectLuaError("cannot bind 'http://www.w3.org/2000/xmlns/' to prefixes other than 'xmlns'", parser.toTable, parser,
			[=[<r xmlns:foo="http://www.w3.org/2000/xmlns/"/>]=]
		)
	end
	--]====]
end
)
--]===]


self:runJobs()
