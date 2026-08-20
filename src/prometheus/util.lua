-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- util.lua

local logger = require("logger")
local bit32  = require("prometheus.bit").bit32

local MAX_UNPACK_COUNT = 195
local unpack_ = table.unpack or unpack

--------------------------------------------------
-- Table utilities
--------------------------------------------------

local function lookupify(tb)
	local tb2 = {}

	for _, v in ipairs(tb) do
		tb2[v] = true
	end

	return tb2
end

local function unlookupify(tb)
	local tb2 = {}

	for v, _ in pairs(tb) do
		table.insert(tb2, v)
	end

	return tb2
end

local function keys(tb)
	local keyset = {}
	local n = 0

	for k, _ in pairs(tb) do
		n = n + 1
		keyset[n] = k
	end

	return keyset
end

--------------------------------------------------
-- String utilities
--------------------------------------------------

local function escape(str)
	return str:gsub(".", function(char)
		if char:match("[^ -~\n\t\a\b\v\r\"\']") then
			return string.format("\\%03d", string.byte(char))
		end

		if char == "\\" then
			return "\\\\"
		elseif char == "\n" then
			return "\\n"
		elseif char == "\r" then
			return "\\r"
		elseif char == "\t" then
			return "\\t"
		elseif char == "\a" then
			return "\\a"
		elseif char == "\b" then
			return "\\b"
		elseif char == "\v" then
			return "\\v"
		elseif char == "\"" then
			return "\\\""
		elseif char == "'" then
			return "\\'"
		end

		return char
	end)
end

local function chararray(str)
	local tb = {}

	for i = 1, #str do
		table.insert(tb, str:sub(i, i))
	end

	return tb
end

--------------------------------------------------
-- UTF-8
--------------------------------------------------

local utf8char

do
	local string_char = string.char

	function utf8char(cp)
		if cp < 128 then
			return string_char(cp)
		end

		local suffix = cp % 64
		local c4 = 128 + suffix

		cp = (cp - suffix) / 64

		if cp < 32 then
			return string_char(
				192 + cp,
				c4
			)
		end

		suffix = cp % 64
		local c3 = 128 + suffix

		cp = (cp - suffix) / 64

		if cp < 16 then
			return string_char(
				224 + cp,
				c3,
				c4
			)
		end

		suffix = cp % 64

		return string_char(
			240 + cp,
			128 + suffix,
			c3,
			c4
		)
	end
end

--------------------------------------------------
-- Shuffle
--------------------------------------------------

local function shuffle(tb)
	for i = #tb, 2, -1 do
		local j = math.random(i)

		tb[i], tb[j] =
			tb[j], tb[i]
	end

	return tb
end

local function shuffle_string(str)
	local len = #str
	local t = {}

	for i = 1, len do
		t[i] = str:sub(i, i)
	end

	for i = len, 2, -1 do
		local j = math.random(i)

		t[i], t[j] =
			t[j], t[i]
	end

	return table.concat(t)
end

--------------------------------------------------
-- Double
--------------------------------------------------

local function readDouble(bytes)
	local sign = 1
	local mantissa = bytes[2] % 2^4

	for i = 3, 8 do
		mantissa =
			mantissa * 256 +
			bytes[i]
	end

	if bytes[1] > 127 then
		sign = -1
	end

	local exponent =
		(bytes[1] % 128) * 2^4 +
		math.floor(bytes[2] / 2^4)

	if exponent == 0 then
		return 0
	end

	mantissa =
		(math.ldexp(mantissa, -52) + 1) *
		sign

	return math.ldexp(
		mantissa,
		exponent - 1023
	)
end

local function writeDouble(num)
	local bytes = {
		0, 0, 0, 0,
		0, 0, 0, 0
	}

	if num == 0 then
		return bytes
	end

	local anum = math.abs(num)

	local mantissa, exponent =
		math.frexp(anum)

	exponent = exponent - 1
	mantissa = mantissa * 2 - 1

	local sign =
		num ~= anum and 128 or 0

	exponent = exponent + 1023

	bytes[1] =
		sign +
		math.floor(exponent / 2^4)

	mantissa = mantissa * 2^4

	local currentmantissa =
		math.floor(mantissa)

	mantissa =
		mantissa - currentmantissa

	bytes[2] =
		(exponent % 2^4) * 2^4 +
		currentmantissa

	for i = 3, 8 do
		mantissa =
			mantissa * 2^8

		currentmantissa =
			math.floor(mantissa)

		mantissa =
			mantissa - currentmantissa

		bytes[i] = currentmantissa
	end

	return bytes
end

--------------------------------------------------
-- U16
--------------------------------------------------

local function writeU16(u16)
	if u16 < 0 or u16 > 65535 then
		logger:error(
			string.format(
				"u16 out of bounds: %d",
				u16
			)
		)
	end

	local lower =
		bit32.band(u16, 255)

	local upper =
		bit32.rshift(u16, 8)

	return {
		lower,
		upper
	}
end

local function readU16(arr)
	return bit32.bor(
		arr[1],
		bit32.lshift(arr[2], 8)
	)
end

--------------------------------------------------
-- U24
--------------------------------------------------

local function writeU24(u24)
	if u24 < 0 or u24 > 16777215 then
		logger:error(
			string.format(
				"u24 out of bounds: %d",
				u24
			)
		)
	end

	local arr = {}

	for i = 0, 2 do
		arr[i + 1] =
			bit32.band(
				bit32.rshift(
					u24,
					8 * i
				),
				255
			)
	end

	return arr
end

local function readU24(arr)
	local val = 0

	for i = 0, 2 do
		val =
			bit32.bor(
				val,
				bit32.lshift(
					arr[i + 1],
					8 * i
				)
			)
	end

	return val
end

--------------------------------------------------
-- U32
--------------------------------------------------

local function writeU32(u32)
	if u32 < 0 or u32 > 4294967295 then
		logger:error(
			string.format(
				"u32 out of bounds: %d",
				u32
			)
		)
	end

	local arr = {}

	for i = 0, 3 do
		arr[i + 1] =
			bit32.band(
				bit32.rshift(
					u32,
					8 * i
				),
				255
			)
	end

	return arr
end

local function readU32(arr)
	local val = 0

	for i = 0, 3 do
		val =
			bit32.bor(
				val,
				bit32.lshift(
					arr[i + 1],
					8 * i
				)
			)
	end

	return val
end

--------------------------------------------------
-- Bytes -> String
--------------------------------------------------

local function bytesToString(arr)
	if not arr then
		return ""
	end

	local length =
		arr.n or #arr

	if length == 0 then
		return ""
	end

	if length < MAX_UNPACK_COUNT then
		return string.char(
			unpack_(arr, 1, length)
		)
	end

	local parts = {}

	local start = 1

	while start <= length do
		local finish =
			math.min(
				start + MAX_UNPACK_COUNT - 1,
				length
			)

		parts[#parts + 1] =
			string.char(
				unpack_(
					arr,
					start,
					finish
				)
			)

		start = finish + 1
	end

	return table.concat(parts)
end

--------------------------------------------------
-- Number checks
--------------------------------------------------

local function isNaN(n)
	return type(n) == "number"
		and n ~= n
end

local function isInt(n)
	return type(n) == "number"
		and math.floor(n) == n
end

local function isU32(n)
	return type(n) == "number"
		and n >= 0
		and n <= 4294967295
		and isInt(n)
end

--------------------------------------------------
-- Number -> bits
--------------------------------------------------

local function toBits(num)
	local t = {}

	while num > 0 do
		local rest =
			math.fmod(num, 2)

		t[#t + 1] = rest

		num =
			(num - rest) / 2
	end

	return t
end

--------------------------------------------------
-- Readonly
--------------------------------------------------

local function readonly(obj)
	local r = newproxy(true)

	getmetatable(r).__index = obj

	return r
end

--------------------------------------------------
-- Lightweight Math Expressions
--
-- Used by NumbersToExpressions.lua
--------------------------------------------------

local function mathExpression(num)
	if type(num) ~= "number" then
		return tostring(num)
	end

	if num ~= num then
		return tostring(num)
	end

	if num == 0 then
		return "0"
	end

	-- เลือก expression แบบเบา ๆ
	local mode = math.random(1, 4)

	------------------------------------------------
	-- Addition
	------------------------------------------------

	if mode == 1 then
		local a =
			math.random(1, 50)

		local b =
			num - a

		return "(" ..
			tostring(a) ..
			"+" ..
			tostring(b) ..
			")"
	end

	------------------------------------------------
	-- Subtraction
	------------------------------------------------

	if mode == 2 then
		local b =
			math.random(1, 50)

		local a =
			num + b

		return "(" ..
			tostring(a) ..
			"-" ..
			tostring(b) ..
			")"
	end

	------------------------------------------------
	-- Multiplication
	------------------------------------------------

	if mode == 3 then
		if num % 2 == 0 then
			local b = 2
			local a = num / b

			return "(" ..
				tostring(a) ..
				"*" ..
				tostring(b) ..
				")"
		end
	end

	------------------------------------------------
	-- Fallback
	------------------------------------------------

	local b =
		math.random(2, 9)

	local a =
		num + b

	return "(" ..
		tostring(a) ..
		"-" ..
		tostring(b) ..
		")"
end

--------------------------------------------------
-- Base64
--------------------------------------------------

local B64C =
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ" ..
	"abcdefghijklmnopqrstuvwxyz" ..
	"0123456789+/"

local function b64encode(data)
	return (
		(
			data:gsub(
				".",
				function(x)
					local r = ""
					local b = x:byte()

					for i = 8, 1, -1 do
						r = r ..
							(
								b % 2^i -
								b % 2^(i - 1) > 0
								and "1"
								or "0"
							)
					end

					return r
				end
			)
			.. "0000"
		):gsub(
			"%d%d%d?%d?%d?%d?",
			function(x)
				if #x < 6 then
					return ""
				end

				local c = 0

				for i = 1, 6 do
					if x:sub(i, i) == "1" then
						c =
							c +
							2^(6 - i)
					end
				end

				return B64C:sub(
					c + 1,
					c + 1
				)
			end
		)
		.. ({
			"",
			"==",
			"="
		})[#data % 3 + 1]
	)
end

local function b64decode(data)
	data =
		string.gsub(
			data,
			"[^" .. B64C .. "=]",
			""
		)

	return (
		data:gsub(
			".",
			function(x)
				if x == "=" then
					return ""
				end

				local r = ""

				local f =
					(B64C:find(
						x,
						1,
						true
					) - 1)

				for i = 6, 1, -1 do
					r = r ..
						(
							f % 2^i -
							f % 2^(i - 1) > 0
							and "1"
							or "0"
						)
				end

				return r
			end
		):gsub(
			"%d%d%d?%d?%d?%d?%d?%d?",
			function(x)
				if #x ~= 8 then
					return ""
				end

				local c = 0

				for i = 1, 8 do
					if x:sub(i, i) == "1" then
						c =
							c +
							2^(8 - i)
					end
				end

				return string.char(c)
			end
		)
	)
end

--------------------------------------------------
-- Export
--------------------------------------------------

return {
	lookupify = lookupify,
	unlookupify = unlookupify,

	escape = escape,
	chararray = chararray,
	keys = keys,

	shuffle = shuffle,
	shuffle_string = shuffle_string,

	readDouble = readDouble,
	writeDouble = writeDouble,

	readU16 = readU16,
	writeU16 = writeU16,

	readU24 = readU24,
	writeU24 = writeU24,

	readU32 = readU32,
	writeU32 = writeU32,

	isNaN = isNaN,
	isU32 = isU32,
	isInt = isInt,

	utf8char = utf8char,

	toBits = toBits,

	bytesToString = bytesToString,

	readonly = readonly,

	-- Math
	mathExpression = mathExpression,

	-- Base64
	B64C = B64C,
	b64encode = b64encode,
	b64decode = b64decode
}
