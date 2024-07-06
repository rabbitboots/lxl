-- Auxiliary encoding functions for utf8Tools.
-- https://github.com/rabbitboots/utf8_tools
-- License: MIT


local PATH = ... and (...):match("(.-)[^%.]+$") or ""


local utf8Conv = {}


local utf8Tools = require(PATH .. "utf8_tools")


utf8Conv.lang = {
	err_l1_unsup_cp = "unsupported code point",
	err_u16_no_space1 = "not enough space to decode a 16-bit value",
	err_u16_no_space2 = "not enough space to decode a second 16-bit value",
	err_u16_b1_oob = "first 16-byte value is out of range",
	err_u16_b2_oob = "second 16-byte value is out of range",
	err_u8_decode = "UTF-8 decoding error: $1"
}
local lang = utf8Conv.lang


local interp, _argType = utf8Tools._interp, utf8Tools._argType


function utf8Conv.latin1_utf8(s)
	_argType(1, s, "string")

	local t = {}
	for i = 1, #s do
		t[#t + 1] = utf8Tools.stringFromCode(s:sub(i, i):byte())
	end

	return table.concat(t)
end


function utf8Conv.utf8_latin1(s, unmapped)
	_argType(1, s, "string")
	-- don't assert `unmapped`

	if s == "" then return "" end

	local t, i = {}, 1
	while i do
		local c, err = utf8Tools.codeFromString(s, i)
		if not c then
			return nil, err, i

		elseif c >= 255 then
			if type(unmapped) == "string" then
				t[#t + 1] = unmapped
			else
				return nil, lang.err_l1_unsup_cp, i
			end

		else
			t[#t + 1] = string.char(c)
		end
		i = utf8Tools.step(s, i)
	end

	return table.concat(t)
end


local function combine16Bit(s, i, big_en)
	local b1, b2 = s:byte(i), s:byte(i + 1)

	if big_en then
		b1 = b1 * 0x100
	else
		b2 = b2 * 0x100
	end

	return b1 + b2
end


function utf8Conv.utf16_utf8(s, big_en)
	_argType(1, s, "string")

	local t, i = {}, 1
	while i <= #s do
		if i == #s then
			return nil, lang.err_u16_no_space1, i
		end

		local w1 = combine16Bit(s, i, big_en)

		if w1 < 0xd800 or w1 > 0xdfff then
			t[#t + 1] = utf8Tools.stringFromCode(w1)
			i = i + 2

		elseif w1 > 0xdbff then
			return nil, lang.err_u16_b1_oob, i

		else
			i = i + 2
			if i > #s - 1 then
				return nil, lang.err_u16_no_space2, i
			end

			local w2 = combine16Bit(s, i, big_en)

			if not (w2 >= 0xdc00 and w2 <= 0xdfff) then
				return nil, lang.err_u16_b2_oob, i
			end

			t[#t + 1] = utf8Tools.stringFromCode(((w1 % 0x400) * 0x400) + (w2 % 0x400) + 0x10000)
			i = i + 2
		end
	end

	return table.concat(t)
end


local function split16Bit(v, big_en)
	if big_en then
		return math.floor(v / 0x100), v % 0x100
	else
		return v % 0x100, math.floor(v / 0x100)
	end
end


function utf8Conv.utf8_utf16(s, big_en)
	_argType(1, s, "string")

	if s == "" then return "" end

	local t, i = {}, 1
	while i do
		local c, err = utf8Tools.codeFromString(s, i)
		if not c then
			return nil, interp(lang.err_u8_decode, err), i
		end

		local  v1, v2
		if c < 0x10000 then
			v1, v2 = split16Bit(c, big_en)
			t[#t + 1] = string.char(v1, v2)
		else
			c = c - 0x10000
			local w1 = 0xd800 + math.floor(c / 0x400)
			local w2 = 0xdc00 + (c % 0x400)

			v1, v2 = split16Bit(w1, big_en)
			t[#t + 1] = string.char(v1, v2)

			v1, v2 = split16Bit(w2, big_en)
			t[#t + 1] = string.char(v1, v2)
		end

		i = utf8Tools.step(s, i)
	end

	return table.concat(t)
end


return utf8Conv
