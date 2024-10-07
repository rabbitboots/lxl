local PATH = ... and (...):match("(.-)[^%.]+$") or ""


require(PATH .. "test.strict")


local errTest = require(PATH .. "test.err_test")
local inspect = require(PATH .. "test.inspect")
local pretty = require(PATH .. "test_pretty")
local pUTF8 = require(PATH .. "pile_utf8")
local pUTF8Conv = require(PATH .. "pile_utf8_conv")
local shared = require(PATH .. "lxl_shared")
local lxl = require(PATH .. "lxl")


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


-- lxl.newParser(): nothing to test


-- [===[
self:registerJob("xmlParser:setNamespaceMode(), getNamespaceMode()", function(self)
	-- [====[
	local p = lxl.newParser()
	self:expectLuaError("arg #1 bad input", p.setNamespaceMode, p, "foobar")
	p:setNamespaceMode("1.1")
	self:isEqual(p:getNamespaceMode(), "1.1")
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setCollectComments(), getCollectComments()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setCollectComments()
	self:isEvalFalse(p:getCollectComments())
	local o = p:toTable([=[<!--foo--><r/>]=])
	self:isEqual(o.children[1].id, "element")
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setCollectProcessingInstructions(), getCollectProcessingInstructions()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setCollectProcessingInstructions()
	self:isEvalFalse(p:getCollectProcessingInstructions())
	local o = p:toTable([=[<?pi foo?><r/>]=])
	self:isEqual(o.children[1].id, "element")
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setNormalizeLineEndings(), getNormalizeLineEndings()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setNormalizeLineEndings()
	self:isEvalFalse(p:getNormalizeLineEndings())
	local o = p:toTable("<r>.\r\n.</r>")
	self:isEqual(o.children[1].children[1].id, "cdata")
	self:isEqual(o.children[1].children[1].text, ".\r\n.")
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setCheckEncodingMismatch(), getCheckEncodingMismatch()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setCheckEncodingMismatch()
	self:isEvalFalse(p:setCheckEncodingMismatch())
	local o = p:toTable([=[<?xml version="1.0" encoding="UTF-3000"?><r/>]=])
	self:isEqual(o.encoding, "UTF-3000")
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setMaxEntityBytes(), getMaxEntityBytes()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setMaxEntityBytes(0)
	self:isEqual(p:getMaxEntityBytes(), 0)
	self:expectLuaError("trip the max entity bytes setting", p.toTable, p, [=[
<!DOCTYPE r [
<!ENTITY foo "barbarbar">
]>
<r>&foo;</r>]=])
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setRejectDoctype(), getRejectDoctype()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setRejectDoctype(true)
	self:isEqual(p:getRejectDoctype(), true)
	self:expectLuaError("trip the 'reject doctype' setting", p.toTable, p, [=[<!DOCTYPE r><r/>]=])
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setRejectInternalSubset(), getRejectInternalSubset()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setRejectInternalSubset(true)
	self:isEqual(p:getRejectInternalSubset(), true)
	self:expectLuaError("trip the 'reject internal subset' setting", p.toTable, p, [=[<!DOCTYPE r [<!ENTITY f "b">]><r/>]=])
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setCopyDocType(), getCopyDocType()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setCopyDocType(true)
	self:isEqual(p:getCopyDocType(), true)
	local o = p:toTable([=[<!DOCTYPE r [<!ENTITY foo "bar">]><r/>]=])

	self:isEqual(o.doctype_str, [=[<!DOCTYPE r [<!ENTITY foo "bar">]>]=])
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setRejectUnexpandedEntities(), getRejectUnexpandedEntities()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setRejectUnexpandedEntities(true)
	self:isEqual(p:getRejectUnexpandedEntities(), true)

	self:expectLuaError("test 'reject unexpanded references' setting", p.toTable, p, [=[
<!DOCTYPE r [
<!ENTITY % pe "zoop">
%pe;
]>
<r>&undeclared;</r>]=])
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setWarnDuplicateEntityDeclarations(), getWarnDuplicateEntityDeclarations()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setWarnDuplicateEntityDeclarations(true)
	self:isEqual(p:getWarnDuplicateEntityDeclarations(), true)

	local o = p:toTable([=[
<!DOCTYPE r [
<!ENTITY fo "a">
<!ENTITY fo "b">
<!ENTITY % pe "c">
<!ENTITY % pe "d">
%pe;
]>
<r/>]=])
	--]====]
end
)
--]===]



-- [===[
self:registerJob("xmlParser:setWriteXMLDeclaration(), getWriteXMLDeclaration()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setWriteXMLDeclaration(false)
	self:isEqual(p:getWriteXMLDeclaration(), false)

	local o = lxl.newXMLObject()
	o:newElement("root")
	local s = p:toString(o)
	self:isEqual(s, [=[<root/>]=])
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setWriteDocType(), getWriteDocType()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setWriteDocType(true)
	self:isEqual(p:getWriteDocType(), true)
	local o = lxl.newXMLObject()
	o.doctype_str = [=[
<!DOCTYPE root [
<!ENTITY foo "bar">
]>]=]

	o:newElement("root")
	local s = p:toString(o)
	self:isEqual(s, [=[
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE root [
<!ENTITY foo "bar">
]>
<root/>]=])
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setWritePretty(), getWritePretty()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setWritePretty(false)
	self:isEvalFalse(p:getWritePretty())
	local o = lxl.newXMLObject()
	local e1 = o:newElement("root")
	local e2 = e1:newElement("a")
	local e3 = e2:newElement("b")
	local e4 = e3:newElement("c")
	local e5 = e4:newElement("d")
	local s = p:toString(o)
	self:isEqual(s, [=[<?xml version="1.0" encoding="UTF-8"?><root><a><b><c><d/></c></b></a></root>]=])
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setWriteBigEndian(), getWriteBigEndian()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setWriteXMLDeclaration(false)
	p:setWriteBigEndian(true)
	self:isEqual(p:getWriteBigEndian(), true)
	local o = lxl.newXMLObject()
	o:setXMLEncoding("UTF-16")
	local e1 = o:newElement("root")
	local s = p:toString(o)
	local comparison, c_i, c_err = shared.bom_utf16_be .. pUTF8Conv.utf8_utf16([=[<root/>]=], true)
	if not comparison then error(c_err) end
	self:isEqual(s, comparison)
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:setWriteIndent(), getWriteIndent()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setWriteXMLDeclaration(false)
	p:setWriteIndent("\t", 2)
	local ch, qty = p:getWriteIndent()
	self:isEqual(ch, "\t")
	self:isEqual(qty, 2)
	local o = lxl.newXMLObject()
	local e1 = o:newElement("root")
	local e2 = e1:newElement("a")
	local s = p:toString(o)
	self:isEqual(s, "<root>\n\t\t<a/>\n</root>")
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:toTable()", function(self)
	-- [====[
	local p = lxl.newParser()
	local o = p:toTable([=[<root>foobar</root>]=])
	self:isEqual(o.children[1].id, "element")
	self:isEqual(o.children[1].name, "root")
	self:isEqual(o.children[1].children[1].id, "cdata")
	self:isEqual(o.children[1].children[1].text, "foobar")


	self:expectLuaError("arg #1 bad type", p.toTable, p, {})
	self:expectLuaError("arg #1 bad input", p.toTable, p, "zyp")
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xmlParser:toString()", function(self)
	-- [====[
	local p = lxl.newParser()
	p:setWriteXMLDeclaration(false)
	local o = lxl.newXMLObject()
	local e = o:newElement("root")
	local e2 = e:newCharacterData("foobar")
	local s = p:toString(o)
	self:isEqual(s, "<root>foobar</root>")


	self:expectLuaError("arg #1 bad type", p.toString, p, false)
	self:expectLuaError("arg #1 bad input", p.toString, p, {})
	--]====]
end
)
--]===]


-- [===[
self:registerJob("xml.toTable()", function(self)
	-- [====[
	local o = lxl.toTable([=[<root>foobar</root>]=])
	self:isEqual(o.children[1].id, "element")
	self:isEqual(o.children[1].name, "root")
	self:isEqual(o.children[1].children[1].id, "cdata")
	self:isEqual(o.children[1].children[1].text, "foobar")


	self:expectLuaError("arg #1 bad type", lxl.toTable, {})
	self:expectLuaError("arg #1 bad input", lxl.toTable, "zyp")
	--]====]
end
)
--]===]


-- [===[
self:registerJob("lxl.toString()", function(self)
	-- [====[
	local o = lxl.newXMLObject()
	local e = o:newElement("root")
	local e2 = e:newCharacterData("foobar")
	local s = lxl.toString(o)
	self:isEqual(s, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>foobar</root>")

	self:expectLuaError("arg #1 bad type", lxl.toString, false)
	self:expectLuaError("arg #1 bad input", lxl.toString, {})
	--]====]
end
)
--]===]


-- lxl.newXMLObject() -- nothing to test.


-- [===[
self:registerJob("lxl.load()", function(self)
	-- [====[
	self:expectLuaError("arg #1 bad type", lxl.load, {})
	self:expectLuaError("arg #1 non-existent file", lxl.load, "not-a-real-file.ex-em-el")

	local o = lxl.load("test_lxl.xml")
	o:pruneSpace()
	self:isEqual(o.children[1].id, "element")
	self:isEqual(o.children[1].name, "house")
	self:isEqual(o.children[1].children[1].id, "element")
	self:isEqual(o.children[1].children[1].name, "room")
	self:isEqual(o.children[1].children[1].children[1].id, "cdata")
	self:isEqual(o.children[1].children[1].children[1].text, "Entry way")

	self:isEqual(o.children[1].children[2].id, "element")
	self:isEqual(o.children[1].children[2].name, "room")
	self:isEqual(o.children[1].children[2].children[1].id, "cdata")
	self:isEqual(o.children[1].children[2].children[1].text, "Kitchen")

	self:isEqual(o.children[1].children[3].id, "element")
	self:isEqual(o.children[1].children[3].name, "room")
	self:isEqual(o.children[1].children[3].children[1].id, "cdata")
	self:isEqual(o.children[1].children[3].children[1].text, "Living room")

	self:isEqual(o.children[1].children[4].id, "element")
	self:isEqual(o.children[1].children[4].name, "room")
	self:isEqual(o.children[1].children[4].children[1].id, "cdata")
	self:isEqual(o.children[1].children[4].children[1].text, "Bathroom")

	self:isEqual(o.children[1].children[5].id, "element")
	self:isEqual(o.children[1].children[5].name, "room")
	self:isEqual(o.children[1].children[5].children[1].id, "cdata")
	self:isEqual(o.children[1].children[5].children[1].text, "Bedroom")
	--]====]
end
)
--]===]


self:runJobs()
