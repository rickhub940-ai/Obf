-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- util.lua
-- This file Provides some utility functions

local logger = require("logger")
local bit = require("prometheus.bit")  -- ใช้ bit.numberlua
local bit32 = bit.bit32  -- ใช้ bit32 compat mode

local MAX_UNPACK_COUNT = 195

-- Base64 encoding table
local base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- =========================================================
-- BASE64 ENCODE
-- =========================================================

local function base64_encode(str)
	local result = ""
	local i = 1
	while i <= #str do
		local b1 = string.byte(str, i)
		local b2 = string.byte(str, i + 1) or 0
		local b3 = string.byte(str, i + 2) or 0
		
		local enc1 = bit32.rshift(b1, 2)
		local enc2 = bit32.bor(bit32.lshift(bit32.band(b1, 3), 4), bit32.rshift(b2, 4))
		local enc3 = bit32.bor(bit32.lshift(bit32.band(b2, 15), 2), bit32.rshift(b3, 6))
		local enc4 = bit32.band(b3, 63)
		
		result = result .. base64_chars:sub(enc1 + 1, enc1 + 1)
		result = result .. base64_chars:sub(enc2 + 1, enc2 + 1)
		
		if i + 1 <= #str then
			result = result .. base64_chars:sub(enc3 + 1, enc3 + 1)
		else
			result = result .. "="
		end
		
		if i + 2 <= #str then
			result = result .. base64_chars:sub(enc4 + 1, enc4 + 1)
		else
			result = result .. "="
		end
		
		i = i + 3
	end
	return result
end

-- =========================================================
-- BASE64 DECODE (ไม่ error คืนค่าว่าง)
-- =========================================================

local function base64_decode(str)
	if type(str) ~= "string" then
		return ""
	end
	
	local clean = str:gsub("=", "")
	
	local bytes = {}
	for i = 1, #clean do
		local char = clean:sub(i, i)
		local pos = base64_chars:find(char)
		if not pos then
			return ""
		end
		bytes[i] = pos - 1
	end
	
	if #bytes % 4 ~= 0 then
		return ""
	end
	
	local result = {}
	local i = 1
	while i <= #bytes do
		local a = bytes[i] or 0
		local b = bytes[i + 1] or 0
		local c = bytes[i + 2] or 0
		local d = bytes[i + 3] or 0
		
		local n1 = a * 4 + bit32.rshift(b, 4)
		local n2 = bit32.bor(bit32.lshift(bit32.band(b, 15), 4), bit32.rshift(c, 2))
		local n3 = bit32.bor(bit32.lshift(bit32.band(c, 3), 6), d)
		
		table.insert(result, string.char(n1))
		if i + 2 <= #bytes then
			table.insert(result, string.char(n2))
		end
		if i + 3 <= #bytes then
			table.insert(result, string.char(n3))
		end
		
		i = i + 4
	end
	
	return table.concat(result)
end

-- ... ฟังก์ชันอื่นๆ เหมือนเดิม ...

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

	-- Base64
	base64_encode = base64_encode,
	base64_decode = base64_decode,

	-- Number
	readDouble = readDouble,
	writeDouble = writeDouble,
	readU16 = readU16,
	writeU16 = writeU16,
	readU24 = readU24,
	writeU24 = writeU24,
	readU32 = readU32,
	writeU32 = writeU32,

	-- Bit (ใช้ของ bit.numberlua)
	band = bit32.band,
	bor = bit32.bor,
	bxor = bit32.bxor,
	lshift = bit32.lshift,
	rshift = bit32.rshift,

	-- Utility
	isNaN = isNaN,
	isU32 = isU32,
	isInt = isInt,
	toBits = toBits,
	bytesToString = bytesToString,
	readonly = readonly,
}
