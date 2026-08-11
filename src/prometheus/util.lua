-- util.lua
-- Part of the Prometheus Obfuscator
-- Fixed version - no bit32 dependency

local logger = require("logger")

local MAX_UNPACK_COUNT = 195

-- ============================================================
-- Base52 character set
-- ============================================================

local encryption_chars = {}

for i = 97, 122 do
	table.insert(encryption_chars, string.char(i))
end

for i = 65, 90 do
	table.insert(encryption_chars, string.char(i))
end

local encryption_chars_count = #encryption_chars
local char_to_index = {}

for i, c in ipairs(encryption_chars) do
	char_to_index[c] = i - 1
end

-- ============================================================
-- Bit operations
-- ============================================================

local function band(a, b)
	a = math.floor(a)
	b = math.floor(b)

	local result = 0
	local bit = 1

	while a > 0 and b > 0 do
		if a % 2 == 1 and b % 2 == 1 then
			result = result + bit
		end

		a = math.floor(a / 2)
		b = math.floor(b / 2)
		bit = bit * 2
	end

	return result
end

local function bor(a, b)
	a = math.floor(a)
	b = math.floor(b)

	local result = 0
	local bit = 1

	while a > 0 or b > 0 do
		if a % 2 == 1 or b % 2 == 1 then
			result = result + bit
		end

		a = math.floor(a / 2)
		b = math.floor(b / 2)
		bit = bit * 2
	end

	return result
end

local function bxor(a, b)
	a = math.floor(a)
	b = math.floor(b)

	local result = 0
	local bit = 1

	while a > 0 or b > 0 do
		if a % 2 ~= b % 2 then
			result = result + bit
		end

		a = math.floor(a / 2)
		b = math.floor(b / 2)
		bit = bit * 2
	end

	return result
end

local function lshift(a, n)
	return a * (2 ^ n)
end

local function rshift(a, n)
	return math.floor(a / (2 ^ n))
end

-- ============================================================
-- Table operations
-- ============================================================

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

-- ============================================================
-- String operations
-- ============================================================

-- 1 byte -> 2 Base52 characters
-- reversible

local function escape(str)
	local result = {}

	for i = 1, #str do
		local byte = string.byte(str, i)

		local high = math.floor(byte / encryption_chars_count)
		local low = byte % encryption_chars_count

		result[#result + 1] =
			encryption_chars[high + 1]

		result[#result + 1] =
			encryption_chars[low + 1]
	end

	return table.concat(result)
end

local function unescape(str)
	local result = {}

	if #str % 2 ~= 0 then
		error("Invalid escaped string length")
	end

	for i = 1, #str, 2 do
		local c1 = string.sub(str, i, i)
		local c2 = string.sub(str, i + 1, i + 1)

		local high = char_to_index[c1]
		local low = char_to_index[c2]

		if high == nil or low == nil then
			error("Invalid escaped character")
		end

		local byte =
			high * encryption_chars_count + low

		if byte > 255 then
			error("Invalid escaped byte")
		end

		result[#result + 1] =
			string.char(byte)
	end

	return table.concat(result)
end

local function chararray(str)
	local tb = {}

	for i = 1, #str do
		tb[#tb + 1] =
			str:sub(i, i)
	end

	return tb
end

-- ============================================================
-- UTF-8
-- ============================================================

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
		local c2 = 128 + suffix

		cp = (cp - suffix) / 64

		return string_char(
			240 + cp,
			c2,
			c3,
			c4
		)
	end
end

-- ============================================================
-- Shuffle
-- ============================================================

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
		t[i] =
			string.sub(str, i, i)
	end

	for i = len, 2, -1 do
		local j = math.random(i)

		t[i], t[j] =
			t[j], t[i]
	end

	return table.concat(t)
end

-- ============================================================
-- Double
-- ============================================================

local function readDouble(bytes)
	local sign = 1

	local mantissa =
		bytes[2] % 2^4

	for i = 3, 8 do
		mantissa =
			mantissa * 256 + bytes[i]
	end

	if bytes[1] > 127 then
		sign = -1
	end

	local exponent =
		(bytes[1] % 128) * 2^4
		+ math.floor(bytes[2] / 2^4)

	if exponent == 0 then
		return 0
	end

	mantissa =
		(mantissa / (2^52) + 1)
		* sign

	return mantissa *
		(2 ^ (exponent - 1023))
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

	local exponent =
		math.floor(
			math.log(anum, 2)
		) + 1

	local mantissa =
		anum / (2 ^ exponent)

	exponent = exponent - 1

	mantissa =
		mantissa * 2 - 1

	local sign =
		num < 0 and 128 or 0

	exponent =
		exponent + 1023

	bytes[1] =
		sign +
		math.floor(exponent / 16)

	mantissa =
		mantissa * 16

	local currentmantissa =
		math.floor(mantissa)

	mantissa =
		mantissa - currentmantissa

	bytes[2] =
		(exponent % 16) * 16
		+ currentmantissa

	for i = 3, 8 do
		mantissa =
			mantissa * 256

		currentmantissa =
			math.floor(mantissa)

		mantissa =
			mantissa - currentmantissa

		bytes[i] =
			currentmantissa
	end

	return bytes
end

-- ============================================================
-- U16
-- ============================================================

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
		band(u16, 255)

	local upper =
		rshift(u16, 8)

	return {
		lower,
		upper
	}
end

local function readU16(arr)
	return bor(
		arr[1],
		lshift(arr[2], 8)
	)
end

-- ============================================================
-- U24
-- ============================================================

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
			band(
				rshift(u24, 8 * i),
				255
			)
	end

	return arr
end

local function readU24(arr)
	local val = 0

	for i = 0, 2 do
		val =
			bor(
				val,
				lshift(
					arr[i + 1],
					8 * i
				)
			)
	end

	return val
end

-- ============================================================
-- U32
-- ============================================================

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
			band(
				rshift(
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
			bor(
				val,
				lshift(
					arr[i + 1],
					8 * i
				)
			)
	end

	return val
end

-- ============================================================
-- Bytes -> String
-- ============================================================

local function bytesToString(arr)
	local length =
		arr.n or #arr

	if length == 0 then
		return ""
	end

	if length < MAX_UNPACK_COUNT then
		return string.char(
			table.unpack(
				arr,
				1,
				length
			)
		)
	end

	local parts = {}

	local full_chunks =
		math.floor(
			length / MAX_UNPACK_COUNT
		)

	local overflow =
		length % MAX_UNPACK_COUNT

	for i = 1, full_chunks do
		local start_index =
			(i - 1) *
			MAX_UNPACK_COUNT + 1

		local end_index =
			i * MAX_UNPACK_COUNT

		parts[#parts + 1] =
			string.char(
				table.unpack(
					arr,
					start_index,
					end_index
				)
			)
	end

	if overflow > 0 then
		local start_index =
			length - overflow + 1

		parts[#parts + 1] =
			string.char(
				table.unpack(
					arr,
					start_index,
					length
				)
			)
	end

	return table.concat(parts)
end

-- ============================================================
-- Number helpers
-- ============================================================

local function isNaN(n)
	return type(n) == "number"
		and n ~= n
end

local function isInt(n)
	return type(n) == "number"
		and math.floor(n) == n
end

local function isU32(n)
	return isInt(n)
		and n >= 0
		and n <= 4294967295
end

local function toBits(num)
	local t = {}

	num = math.floor(num)

	while num > 0 do
		local rest =
			num % 2

		t[#t + 1] =
			rest

		num =
			math.floor(
				num / 2
			)
	end

	return t
end

-- ============================================================
-- Readonly
-- ============================================================

local function readonly(obj)
	if not newproxy then
		error(
			"readonly() requires Lua 5.1 newproxy support"
		)
	end

	local r =
		newproxy(true)

	local mt =
		getmetatable(r)

	mt.__index = obj

	mt.__newindex = function()
		error(
			"attempt to modify readonly object"
		)
	end

	return r
end

-- ============================================================
-- Export
-- ============================================================

return {

	-- Table
	lookupify = lookupify,
	unlookupify = unlookupify,
	keys = keys,
	shuffle = shuffle,

	-- String
	escape = escape,
	unescape = unescape,
	chararray = chararray,
	shuffle_string = shuffle_string,
	utf8char = utf8char,

	-- Number
	readDouble = readDouble,
	writeDouble = writeDouble,

	readU16 = readU16,
	writeU16 = writeU16,

	readU24 = readU24,
	writeU24 = writeU24,

	readU32 = readU32,
	writeU32 = writeU32,

	-- Bit
	band = band,
	bor = bor,
	bxor = bxor,
	lshift = lshift,
	rshift = rshift,

	-- Utility
	isNaN = isNaN,
	isU32 = isU32,
	isInt = isInt,
	toBits = toBits,
	bytesToString = bytesToString,
	readonly = readonly,
}
