local logger = require("logger")
local bit32 = require("prometheus.bit").bit32

local MAX_UNPACK_COUNT = 195

local function lookupify(tb)
	local r = {}
	for _, v in ipairs(tb) do
		r[v] = true
	end
	return r
end

local function unlookupify(tb)
	local r = {}
	for v in pairs(tb) do
		r[#r + 1] = v
	end
	return r
end

local function escape(str)
	return str:gsub(".", function(c)
		if c:match("[^ -~\n\t\a\b\v\r\"\']") then
			return string.format("\\%03d", string.byte(c))
		end

		if c == "\\" then return "\\\\" end
		if c == "\n" then return "\\n" end
		if c == "\r" then return "\\r" end
		if c == "\t" then return "\\t" end
		if c == "\a" then return "\\a" end
		if c == "\b" then return "\\b" end
		if c == "\v" then return "\\v" end
		if c == "\"" then return "\\\"" end
		if c == "'" then return "\\'" end

		return c
	end)
end

local function chararray(str)
	local r = {}

	for i = 1, #str do
		r[i] = str:sub(i, i)
	end

	return r
end

local function keys(tb)
	local r = {}
	local n = 0

	for k in pairs(tb) do
		n = n + 1
		r[n] = k
	end

	return r
end

local utf8char

do
	local char = string.char

	function utf8char(cp)
		if cp < 128 then
			return char(cp)
		end

		local s = cp % 64
		local c4 = 128 + s
		cp = (cp - s) / 64

		if cp < 32 then
			return char(192 + cp, c4)
		end

		s = cp % 64
		local c3 = 128 + s
		cp = (cp - s) / 64

		if cp < 16 then
			return char(224 + cp, c3, c4)
		end

		s = cp % 64
		local c2 = 128 + s
		cp = (cp - s) / 64

		return char(240 + cp, c2, c3, c4)
	end
end

local function shuffle(tb)
	for i = #tb, 2, -1 do
		local j = math.random(i)

		tb[i], tb[j] =
			tb[j], tb[i]
	end

	return tb
end

local function shuffle_string(str)
	local t = {}

	for i = 1, #str do
		t[i] = str:sub(i, i)
	end

	for i = 1, #t do
		local j = math.random(i, #t)

		t[i], t[j] =
			t[j], t[i]
	end

	return table.concat(t)
end

local function readDouble(bytes)
	local sign = 1
	local mantissa = bytes[2] % 16

	for i = 3, 8 do
		mantissa =
			mantissa * 256 + bytes[i]
	end

	if bytes[1] > 127 then
		sign = -1
	end

	local exponent =
		(bytes[1] % 128) * 16 +
		math.floor(bytes[2] / 16)

	if exponent == 0 then
		return 0
	end

	mantissa =
		(math.ldexp(mantissa, -52) + 1)
		* sign

	return math.ldexp(
		mantissa,
		exponent - 1023
	)
end

local function writeDouble(num)
	local bytes =
		{0,0,0,0,0,0,0,0}

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
		sign + math.floor(exponent / 16)

	mantissa = mantissa * 16

	local cur = math.floor(mantissa)

	mantissa =
		mantissa - cur

	bytes[2] =
		(exponent % 16) * 16 + cur

	for i = 3, 8 do
		mantissa = mantissa * 256

		cur = math.floor(mantissa)

		mantissa =
			mantissa - cur

		bytes[i] = cur
	end

	return bytes
end

local function writeU16(n)
	if n < 0 or n > 65535 then
		logger:error(
			string.format(
				"u16 out of bounds: %d",
				n
			)
		)
	end

	return {
		bit32.band(n, 255),
		bit32.rshift(n, 8)
	}
end

local function readU16(a)
	return bit32.bor(
		a[1],
		bit32.lshift(a[2], 8)
	)
end

local function writeU24(n)
	if n < 0 or n > 16777215 then
		logger:error(
			string.format(
				"u24 out of bounds: %d",
				n
			)
		)
	end

	local r = {}

	for i = 0, 2 do
		r[i + 1] =
			bit32.band(
				bit32.rshift(n, 8 * i),
				255
			)
	end

	return r
end

local function readU24(a)
	local n = 0

	for i = 0, 2 do
		n = bit32.bor(
			n,
			bit32.lshift(
				a[i + 1],
				8 * i
			)
		)
	end

	return n
end

local function writeU32(n)
	if n < 0 or n > 4294967295 then
		logger:error(
			string.format(
				"u32 out of bounds: %d",
				n
			)
		)
	end

	local r = {}

	for i = 0, 3 do
		r[i + 1] =
			bit32.band(
				bit32.rshift(n, 8 * i),
				255
			)
	end

	return r
end

local function readU32(a)
	local n = 0

	for i = 0, 3 do
		n = bit32.bor(
			n,
			bit32.lshift(
				a[i + 1],
				8 * i
			)
		)
	end

	return n
end

local function bytesToString(a)
	local len = a.n or #a

	if len < MAX_UNPACK_COUNT then
		return string.char(
			table.unpack(a)
		)
	end

	local r = ""
	local over =
		len % MAX_UNPACK_COUNT

	for i = 1,
		(#a - over) / MAX_UNPACK_COUNT
	do
		r = r .. string.char(
			table.unpack(
				a,
				(i - 1) *
					MAX_UNPACK_COUNT + 1,
				i * MAX_UNPACK_COUNT
			)
		)
	end

	if over > 0 then
		r = r .. string.char(
			table.unpack(
				a,
				len - over + 1,
				len
			)
		)
	end

	return r
end

local function isNaN(n)
	return type(n) == "number"
		and n ~= n
end

local function isInt(n)
	return math.floor(n) == n
end

local function isU32(n)
	return n >= 0
		and n <= 4294967295
		and isInt(n)
end

local function toBits(n)
	local r = {}

	while n > 0 do
		local x =
			math.fmod(n, 2)

		r[#r + 1] = x
		n = (n - x) / 2
	end

	return r
end

local function readonly(obj)
	local r = newproxy(true)

	getmetatable(r).__index = obj

	return r
end

-- 64-character alphabet
-- Includes special characters.
local B64C =
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ" ..
	"abcdefghijklmnopqrstuvwxyz" ..
	"0123456789@#$%^&*"

local function b64encode(data)
	return (
		(
			data:gsub(".", function(x)
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
			end)
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
						c = c + 2^(6 - i)
					end
				end

				return B64C:sub(
					c + 1,
					c + 1
				)
			end
		)
		.. ({ "", "==", "=" })[
			#data % 3 + 1
		]
	)
end

local function b64decode(data)
	data = data:gsub(
		"[^" .. B64C .. "=]",
		""
	)

	return (
		data:gsub(".", function(x)
			if x == "=" then
				return ""
			end

			local r = ""

			local f =
				B64C:find(
					x,
					1,
					true
				) - 1

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
		end)
		:gsub(
			"%d%d%d?%d?%d?%d?%d?%d?",
			function(x)
				if #x ~= 8 then
					return ""
				end

				local c = 0

				for i = 1, 8 do
					if x:sub(i, i) == "1" then
						c = c + 2^(8 - i)
					end
				end

				return string.char(c)
			end
		)
	)
end

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

	B64C = B64C,
	b64encode = b64encode,
	b64decode = b64decode,
}
