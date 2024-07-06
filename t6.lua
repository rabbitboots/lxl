-- Test: Comments, Processing Instructions


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
self:registerJob("Comments", function(self)
	-- [====[
	do
		local str = "<r><!----></r>"

		self:print(3, "[+] Minimum Comment)")
		self:print(4, str)
		local tree = xml.toTable(str)
		local root = tree:getRoot()
		local comment = root.children[1]
		print(pretty.print(root))
		self:isEqual(comment.text, "")
	end
	--]====]

	-- [====[
	do
		local str = "<r><!-- Hello World! --></r>"

		self:print(3, "[+] Comment)")
		self:print(4, str)
		local tree = xml.toTable(str)
		local root = tree:getRoot()
		local comment = root.children[1]
		print(pretty.print(root))
		self:isEqual(comment.text, " Hello World! ")
	end
	--]====]


	-- [====[
	self:expectLuaError("no embedded '--' substrings in comments", xml.toTable, "<r><!-- uh--oh --></r>")
	self:expectLuaError("comment can't end with '--->'", xml.toTable, "<r><!-- oh my ---></r>")
	self:expectLuaError("unclosed comment", xml.toTable, "<r><!-- oops - -></r>")
	--]====]
end
)
--]===]


-- [===[
self:registerJob("Processing Instructions", function(self)
	-- [====[
	do
		local str = [=[
<?pi?>
<r></r>
]=]

		self:print(3, "[+] Minimum PI")
		self:print(4, str)
		local tree = xml.toTable(str)
		local pi = tree.children[1]
		self:isEqual(pi.name, "pi")
		self:isEqual(pi.text, "")
	end
	--]====]


	-- [====[
	do
		local str = [=[
<?pi foobar?>
<r></r>
]=]

		self:print(3, "[+] PI")
		self:print(4, str)
		local tree = xml.toTable(str)
		local pi = tree.children[1]
		self:isEqual(pi.name, "pi")
		self:isEqual(pi.text, "foobar")
	end
	--]====]


	-- [====[
	self:expectLuaError("improperly closed PI", xml.toTable, [=[<?pi foobar><r></r>]=])
	self:expectLuaError("cut off at first '?>'", xml.toTable, [=[<?foobar abc?>def?><r></r>]=])
	self:expectLuaError("no PITarget", xml.toTable, [=[<??><r></r>]=])
	self:expectLuaError("PITarget starts with reserved pattern 'XML'", xml.toTable, [=[ <?xMlreserved uh oh! ?><r></r>]=])
	-- ^ The leading space prevents the PI from being read as an XML Declaration.
	--]====]
end
)
--]===]


self:runJobs()
