-- Test: namespace feature testing (from a synthetic xmlObject)


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
self:registerJob("(xmlObject) Namespaced Element Names", function(self)
	-- [====[
	do
		self:print(3, "[+] Element: getNamespace()")

		-- We aren't required by the XML Namespace spec to verify that the URIs are valid.
		local n1_uri = "foo/bar"

		local o = lxl.newXMLObject()
		o:setNamespaceMode("1.0")

		-- This method is namespace-unaware.
		local e = o:newElement("n1:foo")

		local value
		-- As we have not bound 'n1' to the namespace yet, we get nil.
		value = e:getNamespace()
		self:isNil(value)

		e:setAttribute("xmlns:n1", n1_uri)

		value = e:getNamespace()
		self:isEqual(value, n1_uri)

		-- Remove the binding
		e:setAttribute("xmlns:n1", nil)

		value = e:getNamespace()
		self:isNil()
	end
	--]====]
end)


-- [===[
self:registerJob("(xmlObject) Element:findNS()", function(self)
	-- [====[
	do
		self:print(3, "[+] Element:findNS()")

		local n1_uri = "sneak/snack"
		local n2_uri = "beep/boop"

		local o = lxl.newXMLObject()
		o:setNamespaceMode("1.0")

		local e = o:newElement("root")
		local e1 = e:newElement("baz")

		local e2 = e:newElement("n1:baz")
		e2:setAttribute("xmlns:n1", n1_uri)

		local e3 = e:newElement("n2:baz")
		e3:setAttribute("xmlns:n2", n2_uri)

		local e4 = e:newElement("bop")

		local child = e:findNS(n2_uri, "baz")
		self:isEqual(child, e3)

		self:expectLuaError("arg #1 bad type", e.findNS, e, {}, "prefix", "local")
		self:expectLuaError("arg #2 bad type", e.findNS, e, "ns", {}, "local")
		self:expectLuaError("arg #3 bad type", e.findNS, e, "ns", "prefix", {})
	end
	--]====]
end
)
--]===]


-- [===[
self:registerJob("(xmlObject) Namespaced Attributes in Elements", function(self)
	-- [====[
	do
		self:print(3, "[+] Element:getNamespaceAttribute()")

		local n1_uri = "o/h"

		local o = lxl.newXMLObject()
		o:setNamespaceMode("1.0")

		local e = o:newElement("root")

		-- Nothing assigned yet.
		self:isEqual(e:getNamespaceAttribute(n1_uri, "foo"), nil)

		-- Set prefix binding
		e:setAttribute("xmlns:prefix", n1_uri)

		-- Write a QName'd Attribute
		e:setAttribute("prefix:foo", "123", n1_uri)

		self:isEqual(e:getNamespaceAttribute(n1_uri, "foo"), "123")


		self:expectLuaError("arg #1 bad type", e.setAttribute, e, {}, "uri")
		self:expectLuaError("arg #2 bad type", e.setAttribute, e, "key", {})
	end
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlObject:checkNamespaceState()", function(self)
	-- [====[
	do
		local o = lxl.newXMLObject()
		o:setNamespaceMode("1.0")
		local e = o:newElement(":root")

		self:expectLuaError("missing prefix", o.checkNamespaceState, o)
	end
	--]====]


	-- [====[
	do
		local o = lxl.newXMLObject()
		o:setNamespaceMode("1.0")
		local e = o:newElement("foo:")

		self:expectLuaError("missing local name", o.checkNamespaceState, o)
	end
	--]====]


	-- [====[
	do
		local o = lxl.newXMLObject()
		o:setNamespaceMode("1.0")
		local e = o:newElement(":")

		self:expectLuaError("no prefix, no local name", o.checkNamespaceState, o)
	end
	--]====]


	-- [====[
	do
		local o = lxl.newXMLObject()
		o:setNamespaceMode("1.0")
		local e = o:newElement("foo:root")

		self:expectLuaError("element name: prefix with no namespace binding", o.checkNamespaceState, o)
	end
	--]====]

	-- [====[
	do
		local o = lxl.newXMLObject()
		o:setNamespaceMode("1.0")
		local e = o:newElement("root")
		e:setAttribute("foo:bar", "baz")

		self:expectLuaError("attribute name: prefix with no namespace binding", o.checkNamespaceState, o)
	end
	--]====]


	-- [====[
	do
		local o = lxl.newXMLObject()
		o:setNamespaceMode("1.0")
		local e = o:newElement("root")
		e:setAttribute("xmlns:a", "foo")
		e:setAttribute("xmlns:b", "foo")
		e:setAttribute("a:zing", "1")
		e:setAttribute("b:zing", "2")

		self:expectLuaError("two attributes have the same URI + local name", o.checkNamespaceState, o)
	end
	--]====]


	-- [====[
	do
		local o = lxl.newXMLObject()
		local e = o:newElement("root")
		e:setAttribute("xmlns:a", "foo")
		local e2 = e:newElement("foo")
		e2:setAttribute("xmlns:a", "")

		o:setNamespaceMode("1.1")
		self:expectLuaReturn("Namespace 1.1 allowed undeclaring of prefixed namespaces", o.checkNamespaceState, o)

		o:setNamespaceMode("1.0")
		self:expectLuaError("Namespace 1.0 prohibited undeclaring of prefixed namespaces", o.checkNamespaceState, o)
	end
	--]====]
end
)
--]===]


self:runJobs()
