-- util.lua
local logger = require("logger")

-- แก้บรรทัดนี้
local bit = require("prometheus.bit")
local bit32 = bit.bit32

local MAX_UNPACK_COUNT = 195

-- ============================================================
-- BASE64 (เพิ่มเข้าไป)
-- ============================================================

local base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64_encode(str)
    local result = ""
    for i = 1, #str, 3 do
        local b1 = string.byte(str, i) or 0
        local b2 = string.byte(str, i + 1) or 0
        local b3 = string.byte(str, i + 2) or 0

        local n1 = math.floor(b1 / 4)
        local n2 = (b1 % 4) * 16 + math.floor(b2 / 16)
        local n3 = (b2 % 16) * 4 + math.floor(b3 / 64)
        local n4 = b3 % 64

        result = result .. base64_chars:sub(n1 + 1, n1 + 1)
        result = result .. base64_chars:sub(n2 + 1, n2 + 1)
        result = result .. (i + 1 <= #str and base64_chars:sub(n3 + 1, n3 + 1) or "=")
        result = result .. (i + 2 <= #str and base64_chars:sub(n4 + 1, n4 + 1) or "=")
    end
    return result
end

local function base64_decode(str)
    if type(str) ~= "string" then return "" end

    local clean = str:gsub("=", "")
    local bytes = {}

    for i = 1, #clean do
        local char = clean:sub(i, i)
        local pos = base64_chars:find(char)
        if not pos then return "" end
        bytes[i] = pos - 1
    end

    if #bytes % 4 ~= 0 then return "" end

    local result = {}
    for i = 1, #bytes, 4 do
        local a = bytes[i] or 0
        local b = bytes[i + 1] or 0
        local c = bytes[i + 2] or 0
        local d = bytes[i + 3] or 0

        local n1 = a * 4 + math.floor(b / 16)
        local n2 = (b % 16) * 16 + math.floor(c / 4)
        local n3 = (c % 4) * 64 + d

        table.insert(result, string.char(n1))
        if i + 2 <= #bytes then table.insert(result, string.char(n2)) end
        if i + 3 <= #bytes then table.insert(result, string.char(n3)) end
    end

    return table.concat(result)
end

-- ============================================================
-- UTILITY FUNCTIONS (ของเดิม)
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

local function escape(str)
    return str:gsub(".", function(char)
        if char:match("[^ %-~\n\t\a\b\v\r\"\']") then
            return string.format("\\%03d", string.byte(char))
        end
        if char == "\\" then
            return "\\\\"
        end
        if char == "\n" then
            return "\\n"
        end
        if char == "\r" then
            return "\\r"
        end
        if char == "\t" then
            return "\\t"
        end
        if char == "\a" then
            return "\\a"
        end
        if char == "\b" then
            return "\\b"
        end
        if char == "\v" then
            return "\\v"
        end
        if char == "\"" then
            return "\\\""
        end
        if char == "\'" then
            return "\\\'"
        end
        return char
    end)
end

local function chararray(str)
    local tb = {}
    for i = 1, str:len() do
        table.insert(tb, str:sub(i, i))
    end
    return tb
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
            return string_char(192 + cp, c4)
        end
        suffix = cp % 64
        local c3 = 128 + suffix
        cp = (cp - suffix) / 64
        if cp < 16 then
            return string_char(224 + cp, c3, c4)
        end
        suffix = cp % 64
        cp = (cp - suffix) / 64
        return string_char(240 + cp, 128 + suffix, c3, c4)
    end
end

local function shuffle(tb)
    for i = #tb, 2, -1 do
        local j = math.random(i)
        tb[i], tb[j] = tb[j], tb[i]
    end
    return tb
end

local function shuffle_string(str)
    local len = #str
    local t = {}
    for i = 1, len do
        t[i] = string.sub(str, i, i)
    end
    for i = 1, len do
        local j = math.random(i, len)
        t[i], t[j] = t[j], t[i]
    end
    return table.concat(t)
end

-- ============================================================
-- NUMBER FUNCTIONS (ของเดิม)
-- ============================================================

local function readDouble(bytes)
    local sign = 1
    local mantissa = bytes[2] % 2^4
    for i = 3, 8 do
        mantissa = mantissa * 256 + bytes[i]
    end
    if bytes[1] > 127 then sign = -1 end
    local exponent = (bytes[1] % 128) * 2^4 + math.floor(bytes[2] / 2^4)

    if exponent == 0 then
        return 0
    end
    mantissa = (math.ldexp(mantissa, -52) + 1) * sign
    return math.ldexp(mantissa, exponent - 1023)
end

local function writeDouble(num)
    local bytes = {0, 0, 0, 0, 0, 0, 0, 0}
    if num == 0 then
        return bytes
    end
    local anum = math.abs(num)

    local mantissa, exponent = math.frexp(anum)
    exponent = exponent - 1
    mantissa = mantissa * 2 - 1
    local sign = num ~= anum and 128 or 0
    exponent = exponent + 1023

    bytes[1] = sign + math.floor(exponent / 2^4)
    mantissa = mantissa * 2^4
    local currentmantissa = math.floor(mantissa)
    mantissa = mantissa - currentmantissa
    bytes[2] = (exponent % 2^4) * 2^4 + currentmantissa
    for i = 3, 8 do
        mantissa = mantissa * 2^8
        currentmantissa = math.floor(mantissa)
        mantissa = mantissa - currentmantissa
        bytes[i] = currentmantissa
    end
    return bytes
end

local function writeU16(u16)
    if u16 < 0 or u16 > 65535 then
        logger:error(string.format("u16 out of bounds: %d", u16))
    end
    local lower = bit32.band(u16, 255)
    local upper = bit32.rshift(u16, 8)
    return {lower, upper}
end

local function readU16(arr)
    return bit32.bor(arr[1], bit32.lshift(arr[2], 8))
end

local function writeU24(u24)
    if u24 < 0 or u24 > 16777215 then
        logger:error(string.format("u24 out of bounds: %d", u24))
    end
    local arr = {}
    for i = 0, 2 do
        arr[i + 1] = bit32.band(bit32.rshift(u24, 8 * i), 255)
    end
    return arr
end

local function readU24(arr)
    local val = 0
    for i = 0, 2 do
        val = bit32.bor(val, bit32.lshift(arr[i + 1], 8 * i))
    end
    return val
end

local function writeU32(u32)
    if u32 < 0 or u32 > 4294967295 then
        logger:error(string.format("u32 out of bounds: %d", u32))
    end
    local arr = {}
    for i = 0, 3 do
        arr[i + 1] = bit32.band(bit32.rshift(u32, 8 * i), 255)
    end
    return arr
end

local function readU32(arr)
    local val = 0
    for i = 0, 3 do
        val = bit32.bor(val, bit32.lshift(arr[i + 1], 8 * i))
    end
    return val
end

local function bytesToString(arr)
    local lenght = arr.n or #arr

    if lenght < MAX_UNPACK_COUNT then
        return string.char(table.unpack(arr))
    end

    local str = ""
    local overflow = lenght % MAX_UNPACK_COUNT

    for i = 1, (#arr - overflow) / MAX_UNPACK_COUNT do
        str = str .. string.char(table.unpack(arr, (i - 1) * MAX_UNPACK_COUNT + 1, i * MAX_UNPACK_COUNT))
    end

    return str .. (overflow > 0 and string.char(table.unpack(arr, lenght - overflow + 1, lenght)) or "")
end

local function isNaN(n)
    return type(n) == "number" and n ~= n
end

local function isInt(n)
    return math.floor(n) == n
end

local function isU32(n)
    return n >= 0 and n <= 4294967295 and isInt(n)
end

local function toBits(num)
    local t = {}
    local rest
    while num > 0 do
        rest = math.fmod(num, 2)
        t[#t + 1] = rest
        num = (num - rest) / 2
    end
    return t
end

local function readonly(obj)
    local r = newproxy(true)
    getmetatable(r).__index = obj
    return r
end

-- ============================================================
-- RETURN
-- ============================================================

return {
    -- Table
    lookupify = lookupify,
    unlookupify = unlookupify,
    keys = keys,
    shuffle = shuffle,

    -- String
    escape = escape,
    chararray = chararray,
    shuffle_string = shuffle_string,
    utf8char = utf8char,

    -- Base64 (เพิ่ม)
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

    -- Bit
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
