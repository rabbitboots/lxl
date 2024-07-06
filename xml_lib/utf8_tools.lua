-- utf8Tools v1.3.0
-- https://github.com/rabbitboots/utf8_tools


--[[
MIT License

Copyright (c) 2022 - 2024 RBTS

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]


local utf8Tools = {}


utf8Tools.options = {
	check_surrogates = true
}


utf8Tools.lang = {
	arg_bad_int = "argument #$1: expected integer",
	arg_bad_int_range = "argument #$1: expected integer in range ($2-$3)",
	arg_bad_type = "argument #$1: bad type (expected $2, got $3)",
	arg_start_end_oob = "start index is greater than end index",
	byte_nil = "byte #$1 is nil",
	byte_cont_oob = "continuation byte #$1 ($2) is out of range (0x80 - 0xbf)",
	cp_oob = "code point is out of bounds",
	err_iter_codes = "index $1: $2",
	err_surrogate = "invalid code point (in surrogate range)",
	len_mismatch = "$1-byte length mismatch. Got: $2, must be in this range: $3 - $4",
	len_unknown = "unknown UTF-8 byte length marker",
	str_i_oob = "string index is out of bounds",
	trailing_1st = "trailing byte (2nd, 3rd or 4th) receieved as 1st",
	var_i_err = "argument $1: $2"
}
local lang = utf8Tools.lang


local interp -- v v02
do
	local v, c = {}, function(t) for k in pairs(t) do t[k] = nil end end
	interp = function(s, ...)
		c(v)
		for i = 1, select("#", ...) do
			v[tostring(i)] = tostring(select(i, ...))
		end
		local r = tostring(s):gsub("%$(%d+)", v):gsub("%$;", "$")
		c(v)
		return r
	end
end
utf8Tools._interp = interp


local function HEX(n) return ("0x%x"):format(n) end


-- Verifies code point length against allowed UTF-8 byte ranges (1, 2, 3, 4).
local min_max = {{0x0, 0x7f}, {0x80, 0x7ff}, {0x800, 0xffff}, {0x10000, 0x10ffff}}


function utf8Tools._argType(n, v, e)
	if type(v) ~= e then
		error(interp(lang.arg_bad_type, n, e, type(v)), 2)
	end
end
local _argType = utf8Tools._argType


local function _argInt(n, v)
	if type(v) ~= "number" or math.floor(v) ~= v then
		error(interp(lang.arg_bad_int, n), 2)
	end
end

local function _argIntRange(n, v, min, max)
	if type(v) ~= "number" or math.floor(v) ~= v or v < min or v > max then
		error(interp(lang.arg_bad_int_range, n, min, max), 2)
	end
end


local function _length(b)
	-- Byte length marker. Returns number on success, string on failure
	return b < 0x80 and 1
	or b >= 0xc0 and b < 0xe0 and 2
	or b >= 0xe0 and b < 0xf0 and 3
	or b >= 0xf0 and b < 0xf8 and 4
	or b >= 0x80 and b < 0xbf and "trailing_1st"
	or "len_unknown"
end


local function _cont(b, pos)
	-- Checks bytes 2-4 in a multi-byte code point
	-- Do not call on the first byte
	if not b then
		return true, interp(lang.byte_nil, pos)

	-- Verify "following" byte mark
	elseif b < 0x80 or b >= 0xc0 then
		return true, interp(lang.byte_cont_oob, pos, HEX(b))
	end
end


local function _checkCode(c, len)
	if utf8Tools.options.check_surrogates then
		if c >= 0xd800 and c <= 0xdfff then
			return true, lang.err_surrogate
		end
	end

	if c < 0 or c > 0x10ffff then
		return true, lang.cp_oob
	end

	-- Look for too-long or too-short values based on the byte count.
	-- (Only applicable if known to have originated from a UTF-8 sequence.)
	if len then
		local range = min_max[len]
		if c < range[1] or c > range[2] then
			return true, interp(lang.len_mismatch, len, HEX(c), HEX(range[1]), HEX(range[2]))
		end
	end
end


local function _codeFromStr(s, i)
	local b1, b2, b3, b4 = s:byte(i, i + 3)
	local len = _length(b1)
	if type(len) == "string" then
		return nil, lang[len] or "?"
	end

	local c, err, msg
	if len == 1 then
		c = b1

	elseif len == 2 then
		err, msg = _cont(b2, 2, 2) if err then return nil, msg end
		c = (b1 - 0xc0) * 0x40 + (b2 - 0x80)

	elseif len == 3 then
		err, msg = _cont(b2, 2, 3) if err then return nil, msg end
		err, msg = _cont(b3, 3, 3) if err then return nil, msg end
		c = (b1 - 0xe0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80)

	elseif len == 4 then
		err, msg = _cont(b2, 2, 4) if err then return nil, msg end
		err, msg = _cont(b3, 3, 4) if err then return nil, msg end
		err, msg = _cont(b4, 4, 4) if err then return nil, msg end
		c = (b1 - 0xf0) * 0x40000 + (b2 - 0x80) * 0x1000 + (b3 - 0x80) * 0x40 + (b4 - 0x80)
	end

	err, msg = _checkCode(c, len)
	if err then
		return nil, msg
	end

	return c, len
end


function utf8Tools.check(s, i, j)
	_argType(1, s, "string")
	i = i or (#s > 0 and 1 or 0)
	j = j or #s

	local n = 0

	if #s == 0 and i == 0 and j == 0 then
		return n
	end

	_argIntRange(2, i, 1, #s)
	_argIntRange(3, j, 1, #s)
	if i > j then error(lang.arg_start_end_oob) end

	while i <= j do
		local c, len = _codeFromStr(s, i)
		if not c then
			return nil, len, i -- len: error string
		end
		i = i + len
		n = n + 1
	end

	return n
end


function utf8Tools.scrub(s, repl)
	_argType(1, s, "string")
	_argType(2, repl, "string")

	local t, i = {}, 1

	while i <= #s do
		local j, _, bad_i = utf8Tools.check(s, i)
		if not j then
			t[#t + 1] = s:sub(i, bad_i - 1)
			t[#t + 1] = repl
			i = utf8Tools.step(s, bad_i)
		else
			t[#t + 1] = s:sub(i)
			break
		end
	end

	return table.concat(t)
end


function utf8Tools.codeFromString(s, i)
	_argType(1, s, "string")
	i = i == nil and 1 or i
	_argInt(2, i, "number")
	if i < 1 or i > #s then error(interp(lang.str_i_oob)) end

	local c, len = _codeFromStr(s, i)

	if not c then
		return nil, len -- error string
	end

	return c, s:sub(i, i + len - 1)
end


function utf8Tools.stringFromCode(c)
	_argInt(1, c)

	local err, msg = _checkCode(c, nil)
	if err then
		return nil, msg

	elseif c < 0x80 then
		return string.char(c)

	elseif c < 0x800 then
		return string.char(
			0xc0 + math.floor(c / 0x40),
			0x80 + (c % 0x40)
		)

	elseif c < 0x10000 then
		return string.char(
			0xe0 + math.floor(c / 0x1000),
			0x80 + math.floor( (c % 0x1000) / 0x40),
			0x80 + (c % 0x40)
		)

	elseif c <= 0x10ffff then
		return string.char(
			0xf0 + math.floor(c / 0x40000),
			0x80 + math.floor((c % 0x40000) / 0x1000),
			0x80 + math.floor((c % 0x1000) / 0x40),
			0x80 + (c % 0x40)
		)
	end
end


function utf8Tools.step(s, i)
	_argType(1, s, "string")
	_argIntRange(2, i, 0, #s)

	while i < #s do
		i = i + 1
		if type(_length(s:byte(i))) == "number" then
			return i
		end
	end
end


function utf8Tools.stepBack(s, i)
	_argType(1, s, "string")
	_argIntRange(2, i, 1, #s + 1)

	while i > 1 do
		i = i - 1
		if type(_length(s:byte(i))) == "number" then
			return i
		end
	end
end


local function _codes(s, i)
	if i > #s then
		return
	end
	local c, s2 = utf8Tools.codeFromString(s, i)
	if not c then
		error(interp(lang.err_iter_codes, i, s2))
	end
	return i + #s2, c, s2
end


function utf8Tools.codes(s)
	_argType(1, s, "string")

	return _codes, s, 1
end


function utf8Tools.concatCodes(...)
	local t = {...}
	for i = 1, #t do
		local s, err = utf8Tools.stringFromCode(t[i])
		if not s then
			error(interp(lang.var_i_err, i, err))
		end
		t[i] = s
	end
	return table.concat(t)
end


return utf8Tools
