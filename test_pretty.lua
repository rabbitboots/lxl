-- This is not a test, but rather a pretty-printer for other test files.
-- For unrecognized tables, it falls back to inspect().


local PATH = ... and (...):match("(.-)[^%.]+$") or ""


local pretty = {}


local inspect = require(PATH .. "test.lib.inspect.inspect")


local shared = require(PATH .. "xml_shared")


local function _print(t, ...)
	for i = 1, select("#", ...) do
		t[#t + 1] = select(i, ...)
		if i < select("#", ...) then
			t[#t + 1] = "\t"
		end
	end
	t[#t + 1] = "\n"
end


local function _write(t, ...)
	for i = 1, select("#", ...) do
		t[#t + 1] = select(i, ...)
	end
end


local function _ind(t, l)
	if l > 0 then
		t[#t + 1] = string.rep("  ", l)
	end
end


function pretty.print(self, _t, _indent)
	_t = _t or {}
	_indent = _indent or 0

	if type(self) == "table" and pretty[self.id] then
		pretty[self.id](self, _t, _indent)
	else
		_ind(_t, _indent); _print(_t, inspect(self))
	end

	return table.concat(_t)
end


pretty.xml_object = function(self, _t, _indent)
	_ind(_t, _indent); _print(_t, "> XML Tree Object")
	if self.version then
		_ind(_t, _indent); _print(_t, "  Version: " .. self.version)
	end
	if self.encoding then
		_ind(_t, _indent); _print(_t, "  Encoding: " .. self.encoding)
	end
	if self.standalone then
		_ind(_t, _indent); _print(_t, "  Standalone: " .. self.standalone)
	end

	if next(self.g_entities) then
		_ind(_t, _indent); _print(_t, "  General Entities:")
		local order = shared.orderedKeys(self.g_entities)
		for i, k in ipairs(order) do
			local ent = self.g_entities[k]
			if type(ent) == "string" then
				_ind(_t, _indent); _print(_t, "    " .. k .. ": " .. ent)
			else
				_ind(_t, _indent); _write(_t, "    " .. k .. ": " .. ent.value.type .. " ")
				if ent.value.type == "PUBLIC" then
					_write(_t, ent.value.pub_id_literal .. " / ")
				end
				_write(_t, ent.value.system_literal)
				if ent.n_data_decl then
					_write(_t, "; NDATA: " .. ent.n_data_decl.name)
				end
			end
			_print(_t, "")
		end
	end

	if next(self.p_entities) then
		_ind(_t, _indent); _print(_t, "  Parameter Entities:")
		local order = shared.orderedKeys(self.p_entities)
		for i, k in ipairs(order) do
			local ent = self.p_entities[k]
			if type(ent) == "string" then
				_ind(_t, _indent); _print(_t, "    " .. k .. ": " .. ent)
			else
				_ind(_t, _indent); _write(_t, "    " .. k .. ": " .. ent.value.type .. " ")
				if ent.value.type == "PUBLIC" then
					_write(_t, ent.value.pub_id_literal .. " ; ")
				end
				_write(_t, ent.value.system_literal)
			end
			_print(_t, "")
		end
	end

	if #self.children > 0 then
		_ind(_t, _indent); _print(_t, "  Children:")
		for i, child in ipairs(self.children) do
			pretty.print(child, _t, _indent + 1)
		end
	end
end


pretty.doctype = function(self, _t, _indent)
	_ind(_t, _indent); _print(_t, "> Document Type Declaration")
	_ind(_t, _indent); _print(_t, "  DOCTYPE Name: " .. self.name)

	local external_id = self.external_id
	if external_id then
		_ind(_t, _indent); _print(_t, "  External ID:")
		_ind(_t, _indent); _print(_t, "    Type: " .. external_id.type)
		if external_id.type == "PUBLIC" then
			_ind(_t, _indent); _print(_t, "    Public Literal: " .. external_id.pub_id_literal)
		end
		_ind(_t, _indent); _print(_t, "    System Literal: " .. external_id.system_literal)
	end

	-- General Entities / Parameter Entities are printed as part of in xml_object.

	-- Besides Entities, we only parse Comments and PIS in the DTD Internal Subset.
	if #self.children > 0 then
		_ind(_t, _indent); _print(_t, "  Children:")
		for i, child in ipairs(self.children) do
			pretty.print(child, _t, _indent + 1)
		end
	end
end


pretty.element = function(self, _t, _indent)
	_ind(_t, _indent); _print(_t, "> Element: <" .. self.name .. ">")

	if next(self.attr) then
		_ind(_t, _indent); _print(_t, "  Attributes: ")
		local order = self:getStableAttributesOrder()
		for j, name in ipairs(order) do
			local value = self.attr[name]
			_ind(_t, _indent); _print(_t, "    " .. name .. " = |" .. value .. "|")
		end
	end
	if #self.children > 0 then
		_ind(_t, _indent); _print(_t, "  Children:")
		for i, child in ipairs(self.children) do
			pretty.print(child, _t, _indent + 1)
		end
	end
end


pretty.cdata = function(self, _t, _indent)
	if #self.text == 0 then
		_ind(_t, _indent); _print(_t, "> CharacterData (Empty)")

	elseif not self.text:find("[^\32\r\n\t]") then
		_ind(_t, _indent); _print(_t, "> CharacterData (Whitespace)")

	else
		_ind(_t, _indent); _print(_t, "> CharacterData" .. (self.cd_sect and " (CDSect)" or ""))
		_ind(_t, _indent); _print(_t, "  Text: |" .. self.text .. "|")
	end
end


pretty.pi = function(self, _t, _indent)
	_ind(_t, _indent); _print(_t, "> Processing Instruction")
	_ind(_t, _indent); _print(_t, "  Name: |" .. self.name .. "|")
	_ind(_t, _indent); _print(_t, "  Text: |" .. self.text .. "|")
end


pretty.comment = function(self, _t, _indent)
	_ind(_t, _indent); _print(_t, "> Comment")
	_ind(_t, _indent); _print(_t, "  Text: |" .. self.text .. "|")
end


pretty.unexp = function(self, _t, _indent)
	_ind(_t, _indent); _print(_t, "> Unexpanded Entity")
	_ind(_t, _indent); _print(_t, "  Name: |" .. self.name .. "|")
end


return pretty
