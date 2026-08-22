-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- util.lua
-- Utility functions
-- Extended Custom Base64 support for ConstantArray

local logger = require("logger")
local bit32 = require("prometheus.bit").bit32

local MAX_UNPACK_COUNT = 195

------------------------------------------------------------
-- TABLE
------------------------------------------------------------

local function lookupify(tb)
    local tb2 = {}

    for _, v in ipairs(tb) do
        tb2[v] = true
    end

    return tb2
end

local function unlookupify(tb)
    local tb2 = {}

    for v in pairs(tb) do
        table.insert(tb2, v)
    end

    return tb2
end

local function keys(tb)
    local keyset = {}
    local n = 0

    for k in pairs(tb) do
        n = n + 1
        keyset[n] = k
    end

    return keyset
end

------------------------------------------------------------
-- STRING
------------------------------------------------------------

local function escape(str)
    return str:gsub(".", function(char)

        if char:match("[^ -~\n\t\a\b\v\r\"']") then
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
        tb[#tb + 1] = str:sub(i, i)
    end

    return tb
end

------------------------------------------------------------
-- SHUFFLE
------------------------------------------------------------

local function shuffle(tb)
    for i = #tb, 2, -1 do
        local j = math.random(i)

        tb[i], tb[j] = tb[j], tb[i]
    end

    return tb
end

local function shuffle_string(str)
    local t = {}

    for i = 1, #str do
        t[i] = str:sub(i, i)
    end

    shuffle(t)

    return table.concat(t)
end

------------------------------------------------------------
-- UTF8
------------------------------------------------------------

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
        local c2 = 128 + suffix

        cp = (cp - suffix) / 64

        return string_char(
            240 + cp,
            128 + suffix,
            c3,
            c4
        )
    end
end

------------------------------------------------------------
-- DOUBLE
------------------------------------------------------------

local function readDouble(bytes)
    local sign = 1
    local mantissa = bytes[2] % 2^4

    for i = 3, 8 do
        mantissa = mantissa * 256 + bytes[i]
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
        (math.ldexp(mantissa, -52) + 1) * sign

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
        sign + math.floor(exponent / 2^4)

    mantissa = mantissa * 2^4

    local currentmantissa =
        math.floor(mantissa)

    mantissa =
        mantissa - currentmantissa

    bytes[2] =
        (exponent % 2^4) * 2^4
        + currentmantissa

    for i = 3, 8 do
        mantissa = mantissa * 2^8

        currentmantissa =
            math.floor(mantissa)

        mantissa =
            mantissa - currentmantissa

        bytes[i] = currentmantissa
    end

    return bytes
end

------------------------------------------------------------
-- INTEGER
------------------------------------------------------------

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
                bit32.rshift(u24, 8 * i),
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
                bit32.rshift(u32, 8 * i),
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

------------------------------------------------------------
-- BYTES
------------------------------------------------------------

local function bytesToString(arr)
    local length = arr.n or #arr

    if length < MAX_UNPACK_COUNT then
        return string.char(table.unpack(arr))
    end

    local str = ""
    local overflow =
        length % MAX_UNPACK_COUNT

    for i = 1, (length - overflow) / MAX_UNPACK_COUNT do

        str = str ..
            string.char(
                table.unpack(
                    arr,
                    (i - 1) * MAX_UNPACK_COUNT + 1,
                    i * MAX_UNPACK_COUNT
                )
            )
    end

    if overflow > 0 then
        str = str ..
            string.char(
                table.unpack(
                    arr,
                    length - overflow + 1,
                    length
                )
            )
    end

    return str
end

------------------------------------------------------------
-- NUMBER
------------------------------------------------------------

local function isNaN(n)
    return type(n) == "number" and n ~= n
end

local function isInt(n)
    return math.floor(n) == n
end

local function isU32(n)
    return
        n >= 0
        and n <= 4294967295
        and isInt(n)
end

local function toBits(num)
    local t = {}

    while num > 0 do
        local rest = math.fmod(num, 2)

        t[#t + 1] = rest

        num = (num - rest) / 2
    end

    return t
end

------------------------------------------------------------
-- READONLY
------------------------------------------------------------

local function readonly(obj)
    local r = newproxy(true)

    getmetatable(r).__index = obj

    return r
end

------------------------------------------------------------
-- CUSTOM BASE64
------------------------------------------------------------

local B64C =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

------------------------------------------------------------
-- Characters that cannot be used in alphabet
------------------------------------------------------------

local RESERVED_B64_CHARS = {
    ["="] = true,
    ["\""] = true,
    ["'"] = true,
    ["\\"] = true
}

local function isSafeB64Char(c)
    if type(c) ~= "string" or #c ~= 1 then
        return false
    end

    if RESERVED_B64_CHARS[c] then
        return false
    end

    local byte = string.byte(c)

    return byte >= 0x21 and byte <= 0x7E
end

------------------------------------------------------------
-- Build noisy alphabet
--
-- Always EXACTLY 64 unique characters.
-- Noise symbols replace some normal Base64 characters.
------------------------------------------------------------

local function buildNoisyAlphabet(noiseSymbols)

    noiseSymbols = noiseSymbols or {
        "#",
        "@",
        "*",
        "!",
        "?",
        "^",
        "$",
        "%",
        "&",
        "~",
        "|",
        ":",
        ";",
        "<",
        ">",
        "+"
    }

    local chars = {}

    for i = 1, #B64C do
        chars[i] =
            B64C:sub(i, i)
    end

    local candidates = {}
    local used = {}

    for i = 1, #chars do
        used[chars[i]] = true
    end

    for _, symbol in ipairs(noiseSymbols) do

        if isSafeB64Char(symbol)
        and not used[symbol] then

            used[symbol] = true

            candidates[#candidates + 1] =
                symbol
        end
    end

    --------------------------------------------------------
    -- Replace a percentage of normal Base64 characters
    --------------------------------------------------------

    shuffle(candidates)

    local replaceCount =
        math.min(
            #candidates,
            math.floor(#chars * 0.20)
        )

    local positions = {}

    for i = 1, #chars do
        positions[#positions + 1] = i
    end

    shuffle(positions)

    for i = 1, replaceCount do

        local pos = positions[i]

        chars[pos] =
            candidates[i]
    end

    --------------------------------------------------------
    -- Shuffle entire alphabet
    --------------------------------------------------------

    shuffle(chars)

    return table.concat(chars)
end

------------------------------------------------------------
-- Validate alphabet
------------------------------------------------------------

local function validateB64Alphabet(alphabet)

    if type(alphabet) ~= "string" then
        return false
    end

    if #alphabet ~= 64 then
        return false
    end

    local used = {}

    for i = 1, #alphabet do

        local c =
            alphabet:sub(i, i)

        if not isSafeB64Char(c) then
            return false
        end

        if used[c] then
            return false
        end

        used[c] = true
    end

    return true
end

------------------------------------------------------------
-- Create lookup
------------------------------------------------------------

local function createB64Lookup(alphabet)

    alphabet = alphabet or B64C

    if not validateB64Alphabet(alphabet) then
        error(
            "Invalid Base64 alphabet: expected 64 unique safe characters"
        )
    end

    local lookup = {}

    for i = 1, 64 do

        local char =
            alphabet:sub(i, i)

        lookup[char] = i - 1
    end

    return lookup
end

------------------------------------------------------------
-- Encode
------------------------------------------------------------

local function b64encode(data, alphabet)

    alphabet = alphabet or B64C

    if not validateB64Alphabet(alphabet) then
        error("Invalid Base64 alphabet")
    end

    return (
        data:gsub(".", function(x)

            local r = ""
            local b = x:byte()

            for i = 8, 1, -1 do

                r = r ..
                    (
                        b % 2^i
                        - b % 2^(i - 1) > 0
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
                    c =
                        c + 2^(6 - i)
                end
            end

            return alphabet:sub(
                c + 1,
                c + 1
            )
        end
    )
    ..
    ({
        "",
        "==",
        "="
    })[#data % 3 + 1]
end

------------------------------------------------------------
-- Decode
------------------------------------------------------------

local function b64decode(data, alphabet)

    alphabet = alphabet or B64C

    if not validateB64Alphabet(alphabet) then
        error("Invalid Base64 alphabet")
    end

    local lookup =
        createB64Lookup(alphabet)

    local result = {}

    local value = 0
    local count = 0

    for i = 1, #data do

        local char =
            data:sub(i, i)

        if char == "=" then
            break
        end

        local code =
            lookup[char]

        if code ~= nil then

            value =
                value * 64 + code

            count =
                count + 1

            if count == 4 then

                local c1 =
                    math.floor(value / 65536) % 256

                local c2 =
                    math.floor(value / 256) % 256

                local c3 =
                    value % 256

                result[#result + 1] =
                    string.char(
                        c1,
                        c2,
                        c3
                    )

                value = 0
                count = 0
            end
        end
    end

    --------------------------------------------------------
    -- Decode remaining 2/3 Base64 characters
    --------------------------------------------------------

    if count == 2 then

        value = value * 64

        local c1 =
            math.floor(value / 4096) % 256

        result[#result + 1] =
            string.char(c1)

    elseif count == 3 then

        value = value * 64

        local c1 =
            math.floor(value / 65536) % 256

        local c2 =
            math.floor(value / 256) % 256

        result[#result + 1] =
            string.char(
                c1,
                c2
            )
    end

    return table.concat(result)
end

------------------------------------------------------------
-- RETURN
------------------------------------------------------------

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

    bytesToString = bytesToString,

    isNaN = isNaN,
    isU32 = isU32,
    isInt = isInt,

    utf8char = utf8char,
    toBits = toBits,

    readonly = readonly,

    --------------------------------------------------------
    -- Base64 API
    --------------------------------------------------------

    B64C = B64C,

    buildNoisyAlphabet = buildNoisyAlphabet,
    validateB64Alphabet = validateB64Alphabet,
    createB64Lookup = createB64Lookup,

    b64encode = b64encode,
    b64decode = b64decode
}
