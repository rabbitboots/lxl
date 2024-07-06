-- The README example.
local xml = require("xml")

local xml_obj = xml.toTable([=[
<foobar>
 <elem1 a1="Hello" a2="World">Some text.</elem1>
 <empty/>
</foobar>
]=]
)

xml_obj:pruneNodes("comment", "pi")
xml_obj:mergeCharacterData()
xml_obj:pruneSpace()

local root = xml_obj:getRoot()

local e1 = root:find("element", "elem1")

if e1 then
	for k, v in pairs(e1.attr) do
		print(k, v)
	end
end
-- Output (the order may vary):
--[[
a1	Hello
a2	World
--]]


print(xml.toString(xml_obj))
-- Output:
--[[
<?xml version="1.0" encoding="UTF-8"?>
<foobar>
 <elem1 a1="Hello" a2="World">Some text.</elem1>
 <empty/>
</foobar>
--]]
